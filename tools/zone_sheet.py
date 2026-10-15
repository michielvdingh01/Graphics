#!/usr/bin/env python3
"""Looks a level over zone by zone: one sheet with pictures of every zone, and
a table of what each zone has and costs.

    tools/zone_sheet.py [level]            pictures, sheet and table (needs the GPU)
    tools/zone_sheet.py [level] --check    only what can be said without pictures
    tools/zone_sheet.py depot --posted     any other option goes to the benchmark

The level is the factory when none is named. The pictures are taken from
where the level builder decided a zone is best looked at from (the views it
writes on every zone, see _find_views() in tools/level_builder.gd), at the
resolution the frame budget is set for: 1440p with FSR 2 at 67%. The sheet
lands next to them in benchmark/results/<time>/zones.jpg, with under every
picture what that view costs. It needs ImageMagick for the sheet.

What a zone is held to:
  - a reflection probe, a lamp that is on and a lightmap that is up to date;
  - something on its walls or its floor: at least one decal;
  - no more lamps that cast a shadow in sight, its own and those of the
    zones it sees, than the shadow atlas has room for in its largest size:
    SLOTS of them, two for a lamp that shines all round and one for a
    spotlight. With more, lamps take each other's place in the atlas frame
    after frame, and every shadow is drawn anew each time: from the door of
    the stores of the works that was 2800 draw calls and 4.7 million
    triangles a frame, with the atlas as Godot hands it out;
  - from every view no more than DRAWS draw calls and TRIANGLES triangles,
    and no fewer than FPS frames a second.
The frame rate is measured over thirty frames with whatever else the laptop
is doing, so it says more about a view that is far off than about one that
is close; a view that falls short is measured a second time. Draw calls and triangles come out the same every time. Their
limits are a margin above the heaviest view of the factory, which holds 73
frames a second with 1650 draw calls and 3.2 million triangles: out of the
locker room, through the corridor, into the hall. Exits with 1 when a zone
falls short.
"""
import json
import os
import re
import subprocess
import sys

import host
from bake_lightmaps import units_of
from scene_text import Scene

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DRAWS = 2000
TRIANGLES = 4_000_000
FPS = 60.0
# Three quarters of the atlas are cut into sixteen, see project.godot.
SLOTS = 48
BUDGET = ["--res=2560x1440", "--upscaler=fsr2", "--scale=0.67"]
FONT = host.FONT


def main():
    args = sys.argv[1:]
    check_only = "--check" in args
    passed_on = [a for a in args if a.startswith("--") and a != "--check"]
    names = [a for a in args if not a.startswith("--")]
    name = names[0] if names else "factory"
    scene = "res://scenes/%s.tscn" % name
    level_path = os.path.join(ROOT, "scenes/levels/%s_level.tscn" % name)
    if not os.path.exists(level_path):
        sys.exit("There is no level called %s in scenes/levels/." % name)
    level = Scene(open(level_path).read())
    _, zoned, bakes, _ = units_of(scene)

    # The zones, or the level whole, with what stands in each and its views.
    zones = {}
    for path, node in level.nodes.items():
        if zoned and 'groups=["level_zone"]' not in node["head"]:
            continue
        if not zoned and path != ".":
            continue
        zone = "level"
        views = []
        sees = []
        for line in node["lines"]:
            if line.startswith("metadata/sees = "):
                sees = re.findall(r'"([^"]*)"', line)
            found = re.match(r'metadata/zone = "([^"]*)"', line)
            if found:
                zone = found.group(1)
            found = re.match(r"metadata/views = PackedFloat32Array\((.*)\)", line)
            if found and found.group(1).strip():
                numbers = [float(n) for n in found.group(1).split(",")]
                views = [numbers[i:i + 5] for i in range(0, len(numbers), 5)]
        kinds = [level.nodes[p] for p in level.below(path)]
        # A lamp whose light is all in the lightmap is there for the bake
        # alone, see scripts/bake_only.gd: in the game it takes no place.
        shadows = [n["kind"] for n in kinds if n["kind"] in ("OmniLight3D", "SpotLight3D") and "shadow_enabled = true" in n["lines"] and "light_bake_mode = 1" not in n["lines"]]
        zones[zone] = {
            "views": views,
            "sees": sees,
            "slots": sum(2 if kind == "OmniLight3D" else 1 for kind in shadows),
            "probes": sum(1 for n in kinds if n["kind"] == "ReflectionProbe"),
            "lamps": sum(1 for n in kinds if n["kind"] in ("OmniLight3D", "SpotLight3D")),
            "decals": sum(1 for n in kinds if n["kind"] == "Decal"),
            "models": sum(1 for n in kinds if n["instance"]),
            "bake": bakes.get(zone, {}).get("stale", "has no lightmap"),
            "short": [],
        }
    if not any(zone["views"] for zone in zones.values()):
        sys.exit("The level has no views written on it: build it again with tools/build_level.sh %s." % name)

    for zone in zones.values():
        zone["in_sight"] = zone["slots"] + sum(zones[other]["slots"] for other in zone["sees"] if other in zones)
        if zone["in_sight"] > SLOTS:
            zone["short"].append("the lamps in sight want %d places in the shadow atlas, of %d" % (zone["in_sight"], SLOTS))
        if not zone["probes"]:
            zone["short"].append("no reflection probe")
        if not zone["lamps"]:
            zone["short"].append("no lamp that is on")
        if not zone["decals"]:
            zone["short"].append("no decal")
        if zone["bake"]:
            zone["short"].append("lightmap " + zone["bake"])

    shots = []
    if not check_only:
        poses = []
        for zone_name, zone in zones.items():
            for i, view in enumerate(zone["views"]):
                poses.append(",".join("%g" % n for n in view))
                shots.append({"zone": zone_name, "label": "%s %d" % (zone_name, i + 1)})
        settings = [a for a in BUDGET if not any(p.split("=")[0] == a.split("=")[0] for p in passed_on)] + passed_on

        def look(from_where):
            """Has the benchmark look from those poses: its folder, and what it measured."""
            command = ["tools/benchmark.sh", "--quick", "--scene=" + scene, "--at=" + ";".join(from_where)] + settings
            done = subprocess.run(host.command(command), cwd=ROOT, capture_output=True, text=True)
            saved = re.search(r"Saved to (.+)", done.stdout)
            if done.returncode != 0 or not saved:
                print(done.stdout[-2000:] + done.stderr[-2000:])
                sys.exit("The benchmark did not finish.")
            return saved.group(1).strip(), json.load(open(os.path.join(saved.group(1).strip(), "results.json")))["views"]

        print("Taking %d pictures of %s..." % (len(poses), name))
        folder, views = look(poses)
        for shot, view in zip(shots, views):
            shot.update(view, file=os.path.join(folder, view["view"] + ".png"))
        # A hitch of the laptop looks like a slow view: whatever fell short is
        # measured once more, and the better of the two counts.
        slow = [i for i, shot in enumerate(shots) if shot["avg_fps"] < FPS]
        if slow:
            print("Measuring %s again..." % ", ".join(shots[i]["label"] for i in slow))
            _, again = look([poses[i] for i in slow])
            for i, view in zip(slow, again):
                if view["avg_fps"] > shots[i]["avg_fps"]:
                    shots[i].update(avg_fps=view["avg_fps"], low_1pct_fps=view["low_1pct_fps"])
        for shot in shots:
            view = shot
            zone = zones[shot["zone"]]
            # The limits are those of a room without its robots: with them
            # posted, only the frame rate is held against a view.
            if view["draw_calls"] > DRAWS and "--posted" not in passed_on:
                zone["short"].append("%s: %d draw calls" % (shot["label"], view["draw_calls"]))
            if view["primitives"] > TRIANGLES and "--posted" not in passed_on:
                zone["short"].append("%s: %.1f million triangles" % (shot["label"], view["primitives"] / 1e6))
            if view["avg_fps"] < FPS:
                zone["short"].append("%s: %.0f fps" % (shot["label"], view["avg_fps"]))

    wide = max(len(zone_name) for zone_name in zones) + 2
    print("%-*s %6s %6s %7s %6s %6s  %s" % (wide, "zone", "probes", "lamps", "shadows", "decals", "models", "lightmap"))
    for zone_name, zone in zones.items():
        print("%-*s %6d %6d %7d %6d %6d  %s" % (wide, zone_name, zone["probes"], zone["lamps"], zone["in_sight"], zone["decals"], zone["models"], zone["bake"] or "up to date"))
    if shots:
        print("\n%-*s %10s %10s %8s %8s" % (wide, "view", "draw calls", "triangles", "fps", "1% low"))
        for shot in shots:
            print("%-*s %10d %10d %8.1f %8.1f" % (wide, shot["label"], shot["draw_calls"], shot["primitives"], shot["avg_fps"], shot["low_1pct_fps"]))
        sheet = os.path.join(folder, "zones.jpg")
        columns = 2 if len(shots) <= 12 else 3 if len(shots) <= 27 else 4
        width = 1920 // columns - 8
        montage = ["magick", "montage", "-font", FONT, "-background", "#1c1c1c", "-fill", "#dddddd", "-pointsize", str(30 // columns + 6)]
        for shot in shots:
            caption = "%s  ·  %d draw calls  ·  %.1f M triangles  ·  %.0f fps" % (shot["label"], shot["draw_calls"], shot["primitives"] / 1e6, shot["avg_fps"])
            montage += ["-label", caption, shot["file"]]
        montage += ["-tile", "%dx" % columns, "-geometry", "%dx%d+4+4" % (width, width * 9 // 16), "-quality", "88", sheet]
        made = subprocess.run(montage, capture_output=True, text=True)
        print("\n" + (sheet if made.returncode == 0 else "No sheet, ImageMagick said: " + made.stderr.strip()))

    short = [(zone_name, what) for zone_name, zone in zones.items() for what in zone["short"]]
    print()
    if shots and min(shots, key=lambda shot: shot["draw_calls"])["avg_fps"] < FPS:
        print("Even the lightest view fell short: something else was using the GPU. What the")
        print("frame rates say this time is how busy the laptop was; measure again when it is at rest.")
    for zone_name, what in short:
        print("%s falls short: %s" % (zone_name, what))
    if not short:
        print("Every zone has what it is held to." + (" What its views cost was not measured." if check_only else ""))
    return 1 if short else 0


if __name__ == "__main__":
    sys.exit(main())
