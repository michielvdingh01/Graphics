#!/usr/bin/env python3
"""Pictures every prize of assets/prizes.json and puts them on one sheet: a
row for each, with the prize at home in the colour of either side, on the
back of a soldier from the front, from his left and from behind, and dropped
on the floor beside its stand.

    tools/prize_sheet.py                 all of them
    tools/prize_sheet.py banana          that one alone
    tools/prize_sheet.py --run           the soldier in mid-stride instead of standing
    tools/prize_sheet.py --compose       the sheet again from the pictures of last time

The sheet lands in assets/prizes/sheets/prizes.jpg (prizes_<name>.jpg for one
alone, and with _run after it for the soldier in mid-stride). The pictures are taken in the hall of the factory by
tools/benchmark.sh, three runs to a prize, so it needs the GPU, which the
benchmark takes its slot for, and ImageMagick. It does not start while
somebody plays the game on this machine; --anyway starts it all the same.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"
RESOLUTION = (2560, 1440)
# Where in the hall the pictures are taken: a patch of floor the evening sun
# falls on, with room around it.
SPOT = (1.6, -1.5)
# What a column shows, and the piece of its picture that goes on the sheet:
# width, height and how far below the middle of the picture its middle lies.
COLUMNS = [
    ("at home, for either side", (1560, 980, -70)),
    ("carried: from the front", (600, 980, -100)),
    ("from his left", (600, 980, -100)),
    ("from behind", (600, 980, -100)),
    ("dropped", (1130, 980, -30)),
]
ROW_HEIGHT = 520


def played():
    """True while a Godot runs that no tool started without a window: the game, played."""
    listed = subprocess.run(["ps", "-axo", "args"], capture_output=True, text=True).stdout.splitlines()
    for line in listed:
        if "Godot.app/Contents/MacOS/Godot" not in line or "--headless" in line or "--audio-driver Dummy" in line:
            continue
        if "--path" in line or "--editor-pid" in line:
            return True
    return False


def shoot(spawns, views):
    """Has the benchmark stand those in the hall and look at them: the pictures, in order."""
    command = [os.path.join(ROOT, "tools/benchmark.sh"), "--quick", "--res=%dx%d" % RESOLUTION, "--spawn=" + ";".join(spawns), "--at=" + ";".join(views)]
    done = subprocess.run(command, capture_output=True, text=True)
    saved = re.search(r"Saved to (.+)", done.stdout)
    if done.returncode != 0 or not saved:
        print(done.stdout[-2000:] + done.stderr[-2000:])
        sys.exit("The benchmark did not finish.")
    folder = saved.group(1).strip()
    shots = json.load(open(os.path.join(folder, "results.json")))["views"]
    return [os.path.join(folder, shot["view"] + ".png") for shot in shots]


def main():
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    options = [a for a in sys.argv[1:] if a.startswith("--")]
    table = json.load(open(os.path.join(ROOT, "assets/prizes.json")))["prizes"]
    order = list(table)
    for name in names:
        if name not in table:
            sys.exit("There is no prize called %s; there is %s." % (name, ", ".join(order)))
    if played() and "--anyway" not in options:
        sys.exit("Somebody is playing the game on this machine, and a picture next to that halves both. Later, or with --anyway.")
    stance = 3 if "--run" in options else 2
    x, z = SPOT
    folder = os.path.join(ROOT, "assets/prizes/sheets")
    os.makedirs(folder, exist_ok=True)
    scratch = os.path.join(ROOT, "benchmark/results/prize_sheet")
    os.makedirs(scratch, exist_ok=True)
    rows = []
    kept = os.path.join(scratch, "pictures.json")
    taken = json.load(open(kept)) if os.path.exists(kept) else {}
    for name in names or order:
        index = order.index(name)
        own, other = (1, 2) if index % 2 == 0 else (2, 1)
        pose = lambda what, side: "%d.%d%d" % (what, index, side)
        # At home, one of each side, seen from where both the cloth of a flag
        # and the length of a banana show.
        if "--compose" in options:
            if name not in taken:
                sys.exit("There are no pictures of %s from last time." % name)
            pictures = taken[name]
        else:
            pictures = shoot(
                ["res://scenes/prize.tscn@%g,0,%g,0,1,%s" % (x, z - 0.8, pose(1, own)), "res://scenes/prize.tscn@%g,0,%g,0,1,%s" % (x, z + 0.8, pose(1, other))],
                ["%g,1.3,%g,44,-10" % (x + 2.1, z + 2.4)])
        # On a soldier who looks along -X, with the stand he took it from
        # behind his left shoulder and out of the way of all three looks.
            pictures += shoot(
                ["res://scenes/prize.tscn@%g,0,%g,90,1,%s" % (x - 1.2, z + 1.6, pose(stance, own))],
                ["%g,1.35,%g,-73,-3" % (x - 3.05, z + 0.9), "%g,1.35,%g,0,-3" % (x, z + 3.2), "%g,1.35,%g,90,-3" % (x + 3.2, z)])
            # Dropped, beside the stand it belongs on.
            pictures += shoot(
                ["res://scenes/prize.tscn@%g,0,%g,0,1,%s" % (x - 1.2, z - 0.3, pose(4, own))],
                ["%g,1.3,%g,42,-12" % (x + 2.1, z + 2.4)])
            taken[name] = pictures
            json.dump(taken, open(kept, "w"))
        cells = []
        for column, picture in enumerate(pictures):
            wide, high, below = COLUMNS[column][1]
            cell = os.path.join(scratch, "%s_%d.png" % (name, column))
            subprocess.run(["magick", picture, "-gravity", "center", "-crop", "%dx%d+0%+d" % (wide, high, below), "+repage", "-resize", "x%d" % ROW_HEIGHT, cell], check=True)
            cells.append(cell)
        row = os.path.join(scratch, "%s_row.png" % name)
        command = ["magick"]
        for cell in cells:
            command += ["(", cell, "-bordercolor", "#1c1c1c", "-border", "5x5", ")"]
        command += ["+append", "-background", "#1c1c1c", "-gravity", "north", "-splice", "0x50", "-font", FONT, "-fill", "#dddddd", "-pointsize", "30",
            "-gravity", "northwest", "-annotate", "+14+8", table[name].get("name", name), row]
        subprocess.run(command, check=True)
        rows.append(row)
        print("%s: %d pictures" % (name, len(pictures)))
    # A line over the columns saying what each is, at the width it has on the sheet.
    header = os.path.join(scratch, "header.png")
    command = ["magick"]
    for title, (wide, high, _below) in COLUMNS:
        width = round(wide * ROW_HEIGHT / high) + 10
        command += ["(", "-size", "%dx44" % width, "xc:#1c1c1c", "-font", FONT, "-fill", "#aaaaaa", "-pointsize", "24", "-gravity", "center", "-annotate", "+0+2", title, ")"]
    command += ["+append", header]
    subprocess.run(command, check=True)
    sheet = os.path.join(folder, "prizes%s%s.jpg" % ("".join("_" + name for name in names), "_run" if stance == 3 else ""))
    subprocess.run(["magick", header] + rows + ["-background", "#1c1c1c", "-gravity", "west", "-append", "-quality", "88", sheet], check=True)
    print(sheet)


if __name__ == "__main__":
    main()
