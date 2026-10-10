#!/usr/bin/env python3
"""Bakes the lightmaps of a level, and only those that need it.

    tools/bake_lightmaps.sh [scene]                 what changed since it was last baked
    tools/bake_lightmaps.sh [scene] boiler,passage  those zones, whatever their state
    tools/bake_lightmaps.sh [scene] --all           every zone
    tools/bake_lightmaps.sh [scene] --list          say what needs a bake, and bake nothing
    tools/bake_lightmaps.sh [scene] --mark          take the lightmaps there are for up to date

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
        # Lit by the probes, or glass: not part of a bake.
        if node["kind"] == "MeshInstance3D" and ("gi_mode = 2" in node["lines"] or "gi_mode = 0" in node["lines"]):
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


def main():
    args = sys.argv[1:]
    flags = {a for a in args if a.startswith("--")}
    unknown = flags - {"--all", "--list", "--mark"}
    if unknown:
        sys.exit("Unknown option %s. Run it with --list, --all, --mark or the names of zones." % ", ".join(sorted(unknown)))
    args = [a for a in args if not a.startswith("--")]
    scene = "res://scenes/factory.tscn"
    if args and args[0].endswith(".tscn"):
        scene = args.pop(0)
    asked = [name for a in args for name in a.split(",") if name]
    name = os.path.basename(scene)[:-5]
    played_path = scene.replace("res://", "")
    level_path = "scenes/levels/%s_level.tscn" % name
    if not os.path.exists(os.path.join(ROOT, level_path)):
        sys.exit("%s has no level in scenes/levels/: nothing here knows what its bake looks at." % scene)
    level, played = Scene(read(level_path)), Scene(read(played_path))

    # What there is to bake: the zones that have a LightmapGI, or the level whole.
    units = {}
    for path, node in level.nodes.items():
        if 'groups=["level_zone"]' in node["head"] and path + "/LightmapGI" in level.nodes:
            zone = next(re.match(r'metadata/zone = "([^"]*)"', line).group(1) for line in node["lines"] if line.startswith("metadata/zone = "))
            units[zone] = {"node": path, "files": "scenes/%s_%s" % (name, zone)}
    zoned = bool(units)
    if not zoned:
        units["level"] = {"node": ".", "files": "scenes/%s" % name}
    for unit in units.values():
        unit["now"] = signature(level, played, unit["node"])

    record_path = os.path.join(ROOT, "scenes/%s_bakes.json" % name)
    record = json.load(open(record_path)) if os.path.exists(record_path) else {}

    def stale(zone):
        unit = units[zone]
        if not all(os.path.exists(os.path.join(ROOT, unit["files"] + ext)) for ext in (".lmbake", ".exr")):
            return "has no lightmap yet"
        if zone not in record:
            return "has a lightmap, but nothing says what it was baked from"
        return "" if record[zone] == unit["now"] else "changed since it was last baked"

    def save():
        with open(record_path, "w") as out:
            json.dump({zone: record[zone] for zone in sorted(record) if zone in units}, out, indent="\t")
            out.write("\n")

    for zone in asked:
        if zone not in units:
            sys.exit("%s has no zone called %s. There are: %s." % (name, zone, ", ".join(units)))
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
    for zone in wanted:
        print("%s %s: %s" % (name, zone, stale(zone) or "up to date, baked all the same"))
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
