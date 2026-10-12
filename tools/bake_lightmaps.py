#!/usr/bin/env python3
"""Bakes the lightmaps of a level, and only those that need it.

    tools/bake_lightmaps.sh [scene]                 what changed since it was last baked
    tools/bake_lightmaps.sh [scene] boiler,passage  those zones, whatever their state
    tools/bake_lightmaps.sh [scene] --all           every zone
    tools/bake_lightmaps.sh [scene] --list          say what needs a bake, and bake nothing
    tools/bake_lightmaps.sh [scene] --mark          take the lightmaps there are for up to date
    tools/bake_lightmaps.sh [scene] --anyway        bake although another Godot is using the GPU

The scene is the one that is played, res://scenes/factory.tscn when none is
given. A level that is cut into zones has a lightmap for each; any other has
one for the whole of it.

Whether a lightmap is up to date is read off what its bake looks at: the
lightmapped meshes of the zone (the files themselves), its lights, the models
placed in it, the panels that shut its doorways, the settings of its
LightmapGI, and from the scene that is played the sun and the sky. Of all that
a signature is made, and the signature a zone had when it was last baked is
kept in scenes/<level>_bakes.json, next to the lightmaps and committed with
them. Decals, reflection probes, dust and whatever is lit by the probes do not
count: a bake does not look at them.

What this cannot see: a material or a texture that changed, or a model that
was imported anew. After that, bake with --all.

A bake wants the GPU to itself. Next to another Godot that draws, the game
being played or a benchmark of somebody else's, both have hung, and so has
every Godot started after them until the laptop was restarted or the stuck
one was gone. So a bake takes the GPU slot of tools/gpu_slot.sh before it
looks at anything and keeps it until it is done: runs from other checkouts
wait for it, and it waits for theirs. A Godot that draws without the slot,
the editor or the game played from it, is still in the way: this refuses to
bake while there is one, unless told to with --anyway.
"""
import hashlib
import json
import os
import re
import subprocess
import sys

from scene_text import Scene

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# What a bake looks at, by the type of the node. A node without a type is
# something inside a placed model that the level changed, and counts as well.
BAKED = {"MeshInstance3D", "OmniLight3D", "SpotLight3D", "DirectionalLight3D", "LightmapGI", ""}
# Of the sky, a bake takes its light; fog, glow and the like are not its concern.
SKY = ("background_", "sky", "ambient_light_")
SUN_NOT = ("shadow_", "directional_shadow_", "light_volumetric_fog")


def read(path):
    return open(os.path.join(ROOT, path)).read()


def signature(level, played, zone):
    """What the bake of `zone` looks at, as one hash; `zone` is the path of its
    node in the level, or "." for a level that is baked whole."""
    seen = hashlib.sha1()

    def add(text):
        seen.update(text.encode())
        seen.update(b"\n")
        # A mesh the builder wrote is a file of its own: its contents count.
        for path in re.findall(r'Ext\("res://(scenes/levels/[^"]+\.res)"\)', text):
            seen.update(open(os.path.join(ROOT, path), "rb").read())

    for path in level.below(zone):
        node = level.nodes[path]
        if node["kind"] not in BAKED and not node["instance"]:
            continue
        # Lit by the probes, or glass: not part of a bake. That goes for a mesh
        # of the builder's and for one inside a placed model alike.
        if node["kind"] in ("MeshInstance3D", "") and ("gi_mode = 2" in node["lines"] or "gi_mode = 0" in node["lines"]):
            continue
        add(node["head"])
        for line in node["lines"]:
            if not line.startswith(("light_data = ", "metadata/")):
                add(line)
    for path, node in played.nodes.items():
        if node["kind"] == "DirectionalLight3D":
            add(node["head"])
            for line in node["lines"]:
                if not line.startswith(SUN_NOT):
                    add(line)
        elif node["kind"] == "WorldEnvironment":
            for raw in node["raw"]:
                found = re.match(r'environment = SubResource\("([^"]+)"\)', raw)
                if found:
                    for line in played.sub[found.group(1)][1:]:
                        if line.startswith(SKY):
                            add(played.follow(line))
        elif node["kind"] == "LightmapGI" and zone == ".":
            for line in node["lines"]:
                if not line.startswith("light_data = "):
                    add(line)
    return seen.hexdigest()


def units_of(scene):
    """What there is to bake in the level that `scene` plays, and how it
    stands: the name of the level, whether it is cut into zones, and by zone
    {node, files, now, stale}. `stale` says why a zone needs a bake, and is
    empty for one that is up to date. A level that is baked whole is one
    zone, called "level". The last thing returned is what is on record."""
    name = os.path.basename(scene)[:-5]
    level_path = "scenes/levels/%s_level.tscn" % name
    if not os.path.exists(os.path.join(ROOT, level_path)):
        sys.exit("%s has no level in scenes/levels/: nothing here knows what its bake looks at." % scene)
    level, played = Scene(read(level_path)), Scene(read(scene.replace("res://", "")))
    # The zones that have a LightmapGI, or the level whole.
    units = {}
    for path, node in level.nodes.items():
        if 'groups=["level_zone"]' in node["head"] and path + "/LightmapGI" in level.nodes:
            zone = next(re.match(r'metadata/zone = "([^"]*)"', line).group(1) for line in node["lines"] if line.startswith("metadata/zone = "))
            units[zone] = {"node": path, "files": "scenes/%s_%s" % (name, zone)}
    zoned = bool(units)
    if not zoned:
        units["level"] = {"node": ".", "files": "scenes/%s" % name}
    # A level under an open sky has no LightmapGI anywhere: it is lit by its
    # sun and its sky as they are, and has nothing that a bake could go stale.
    unbaked = not zoned and not any(node["kind"] == "LightmapGI" for node in list(level.nodes.values()) + list(played.nodes.values()))
    record_path = os.path.join(ROOT, "scenes/%s_bakes.json" % name)
    record = json.load(open(record_path)) if os.path.exists(record_path) else {}
    for zone, unit in units.items():
        unit["now"] = signature(level, played, unit["node"])
        if unbaked:
            unit["stale"] = ""
            unit["unbaked"] = True
        elif not all(os.path.exists(os.path.join(ROOT, unit["files"] + ext)) for ext in (".lmbake", ".exr")):
            unit["stale"] = "has no lightmap yet"
        elif zone not in record:
            unit["stale"] = "has a lightmap, but nothing says what it was baked from"
        else:
            unit["stale"] = "" if record[zone] == unit["now"] else "changed since it was last baked"
    return name, zoned, units, record


def drawing_godots():
    """The other Godots on this laptop that use the GPU: (pid, how it was started)."""
    found = []
    # By the name of the program that runs, not by its command line: a run of
    # another checkout that waits for the GPU slot is a shell with Godot's path
    # among its arguments, and draws nothing yet.
    for line in subprocess.run(["ps", "-axo", "pid=,ucomm=,args="], capture_output=True, text=True).stdout.splitlines():
        pid, program, started = (line.split(None, 2) + ["", ""])[:3]
        if program in ("Godot", "(Godot)") and "--headless" not in started:
            found.append((pid, started[:90]))
    return found


def main():
    args = sys.argv[1:]
    flags = {a for a in args if a.startswith("--")}
    unknown = flags - {"--all", "--list", "--mark", "--anyway"}
    if unknown:
        sys.exit("Unknown option %s. Run it with --list, --all, --mark, --anyway or the names of zones." % ", ".join(sorted(unknown)))
    args = [a for a in args if not a.startswith("--")]
    scene = "res://scenes/factory.tscn"
    if args and args[0].endswith(".tscn"):
        scene = args.pop(0)
    asked = [name for a in args for name in a.split(",") if name]
    name, zoned, units, record = units_of(scene)

    def stale(zone):
        return units[zone]["stale"]

    def save():
        with open(os.path.join(ROOT, "scenes/%s_bakes.json" % name), "w") as out:
            json.dump({zone: record[zone] for zone in sorted(record) if zone in units}, out, indent="\t")
            out.write("\n")

    for zone in asked:
        if zone not in units:
            sys.exit("%s has no zone called %s. There are: %s." % (name, zone, ", ".join(units)))
    if any(unit.get("unbaked") for unit in units.values()):
        print("%s has no lightmap: it is lit by its sun and its sky as they are. Nothing to bake." % name)
        return 0
    if "--mark" in flags:
        for zone in asked or units:
            record[zone] = units[zone]["now"]
        save()
        print("%s: took the lightmap of %s for up to date." % (name, ", ".join(asked or units)))
        return 0
    if "--list" in flags:
        for zone in units:
            print("%s %s: %s" % (name, zone, stale(zone) or "up to date"))
        return 0

    wanted = asked or [zone for zone in units if "--all" in flags or stale(zone)]
    if not wanted:
        print("%s: nothing to bake, every lightmap is up to date." % name)
        return 0
    if not os.environ.get("GPU_SLOT_HELD"):
        # From here on with the GPU slot, for as long as the bake lasts: the
        # same once more, started by what takes the slot.
        slot = os.path.join(ROOT, "tools/gpu_slot.sh")
        os.execv(slot, [slot, sys.executable, os.path.abspath(__file__)] + sys.argv[1:])
    for zone in wanted:
        print("%s %s: %s" % (name, zone, stale(zone) or "up to date, baked all the same"))
    others = drawing_godots()
    if others and "--anyway" not in flags:
        print("Not baking: another Godot is using the GPU, and a bake next to one has hung both.")
        for pid, started in others:
            print("  %s  %s" % (pid, started))
        print("Bake when it is gone, or pass --anyway.")
        return 2
    env = dict(os.environ, BAKE_LIGHTMAPS=scene, BAKE_ZONES=",".join(wanted) if zoned else "")
    done = subprocess.run([os.path.join(ROOT, "tools/godot.sh"), "--editor"], env=env)
    if done.returncode != 0:
        print("The bake did not finish: nothing is taken for baked.")
        return done.returncode
    for zone in wanted:
        record[zone] = units[zone]["now"]
    save()
    return 0


if __name__ == "__main__":
    sys.exit(main())
