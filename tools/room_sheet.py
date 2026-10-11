#!/usr/bin/env python3
"""Looks into every room of a level from the door the player comes in by, in
this checkout and in another, and puts the two side by side: one sheet of a
level before and after a change to how its rooms are built.

    tools/room_sheet.py works --before=/path/to/other/checkout
    tools/room_sheet.py works                    this checkout alone
    tools/room_sheet.py works --views=2          the first two views of every room

The views are the first that the level builder wrote on each zone of the
level in this checkout, which for a level laid out as rooms is the one from
its door (see _own_views() in tools/kit/rooms.gd). The other checkout is
looked at from the same spots, whatever views its own level has. The sheet
lands in benchmark/sheets/<level>_before_after.jpg, or <level>_rooms.jpg
without a before, with under every picture how dark it is: the share of it
that is nearly black (darker than 6% grey) and its mean brightness from 0 to
1. The same is printed as a table, darkest view first.

It needs the GPU, which each checkout takes its slot for, and ImageMagick.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"
# Darker than this counts as nearly black, as a share of white.
NEARLY_BLACK = 6


def shoot(checkout, level, poses, extra):
    """Has the benchmark of a checkout look from those poses: the pictures, in order."""
    command = [os.path.join(checkout, "tools/benchmark.sh"), "--quick", "--scene=res://scenes/%s.tscn" % level, "--at=" + ";".join(poses), "--res=1280x720"] + extra
    done = subprocess.run(command, capture_output=True, text=True)
    saved = re.search(r"Saved to (.+)", done.stdout)
    if done.returncode != 0 or not saved:
        print(done.stdout[-2000:] + done.stderr[-2000:])
        sys.exit("The benchmark of %s did not finish." % checkout)
    folder = saved.group(1).strip()
    views = json.load(open(os.path.join(folder, "results.json")))["views"]
    return [os.path.join(folder, view["view"] + ".png") for view in views]


def darkness(picture):
    """The share of a picture that is nearly black, and its mean brightness."""
    said = subprocess.run(
        ["magick", picture, "-colorspace", "Gray", "-format", "%[fx:mean] ", "-write", "info:", "-threshold", "%d%%" % NEARLY_BLACK, "-format", "%[fx:1-mean]", "info:"],
        capture_output=True, text=True, check=True,
    ).stdout.split()
    return float(said[1]), float(said[0])


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    options = dict(a[2:].split("=", 1) if "=" in a else (a[2:], "") for a in sys.argv[1:] if a.startswith("--"))
    if not args:
        sys.exit(__doc__)
    level = args[0]
    before = options.pop("before", None)
    each = int(options.pop("views", 1))
    extra = ["--%s=%s" % (key, value) if value else "--" + key for key, value in options.items()]
    path = os.path.join(ROOT, "scenes/levels/%s_level.tscn" % level)
    if not os.path.exists(path):
        sys.exit("There is no level called %s in scenes/levels/." % level)
    shots = []
    for node in open(path).read().split("\n[node ")[1:]:
        zone = re.search(r'metadata/zone = "([^"]*)"', node)
        views = re.search(r"metadata/views = PackedFloat32Array\((.*)\)", node)
        if not zone or not views or not views.group(1).strip():
            continue
        numbers = [float(n) for n in views.group(1).split(",")]
        for i in range(0, min(len(numbers), each * 5), 5):
            shots.append({"zone": zone.group(1) + (" %d" % (i // 5 + 1) if each > 1 else ""), "pose": ",".join("%g" % n for n in numbers[i:i + 5])})
    if not shots:
        sys.exit("The level has no views written on it: build it again with tools/build_level.sh %s." % level)
    poses = [shot["pose"] for shot in shots]
    sides = [("before", os.path.abspath(before))] if before else []
    sides.append(("after" if before else "", ROOT))
    for side, checkout in sides:
        print("Taking %d pictures of %s%s..." % (len(poses), level, " " + side if side else ""))
        for shot, picture in zip(shots, shoot(checkout, level, poses, extra)):
            shot[side] = picture
            shot[side + " dark"] = darkness(picture)

    folder = os.path.join(ROOT, "benchmark/sheets")
    os.makedirs(folder, exist_ok=True)
    sheet = os.path.join(folder, "%s_%s.jpg" % (level, "before_after" if before else "rooms"))
    columns = 4
    width = 1920 // columns - 8
    montage = ["magick", "montage", "-font", FONT, "-background", "#1c1c1c", "-fill", "#dddddd", "-pointsize", "15"]
    for shot in shots:
        for side, _ in sides:
            black, mean = shot[side + " dark"]
            montage += ["-label", "%s%s  ·  %d%% nearly black  ·  brightness %.2f" % (shot["zone"], "  ·  " + side.upper() if side else "", round(black * 100), mean), shot[side]]
    montage += ["-tile", "%dx" % columns, "-geometry", "%dx%d+4+4" % (width, width * 9 // 16), "-quality", "88", sheet]
    made = subprocess.run(montage, capture_output=True, text=True)
    if made.returncode != 0:
        sys.exit("No sheet, ImageMagick said: " + made.stderr.strip())

    last = sides[-1][0]
    wide = max(len(shot["zone"]) for shot in shots) + 2
    print("\n%-*s %s" % (wide, "view", "".join("%22s" % ((side or "this checkout") + ": black, mean") for side, _ in sides)))
    for shot in sorted(shots, key=lambda shot: -shot[last + " dark"][0]):
        print("%-*s %s" % (wide, shot["zone"], "".join("%16d%% %5.2f" % (round(shot[side + " dark"][0] * 100), shot[side + " dark"][1]) for side, _ in sides)))
    for side, _ in sides:
        blacks = sorted(shot[side + " dark"][0] for shot in shots)
        print("%s: nearly black is %d%% of the middle view and %d%% of the darkest; %d of %d views are more than half black" % (
            side or "this checkout", round(blacks[len(blacks) // 2] * 100), round(blacks[-1] * 100), sum(1 for b in blacks if b > 0.5), len(blacks)))
    print("\n" + sheet)
    return 0


if __name__ == "__main__":
    sys.exit(main())
