#!/usr/bin/env python3
"""Pictures the jeep, the lorry, the tank and the motorcycle in the dunes, each
from the front, from behind, close by and from the driver's seat, and puts
them on one sheet: a row for each vehicle.

    tools/vehicle_sheet.py                       this checkout alone
    tools/vehicle_sheet.py --before=<checkout>   a row from that checkout above
                                                 each row of this one
    tools/vehicle_sheet.py --compose             the sheet again from the
                                                 pictures of last time
    tools/vehicle_sheet.py --name=<name>         the sheet's name (vehicles)

The pictures are taken by tools/vehicle_sheet.gd in the game itself, on the
GPU (tools/godot.sh takes its slot for that); a checkout given with --before
gets this checkout's tools/vehicle_sheet.gd put into it first, so both are
pictured the same way. The sheet lands in benchmark/sheets/<name>.jpg, the
pictures in benchmark/results/vehicle_sheet/. Needs ImageMagick.
"""
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
VEHICLES = ["jeep", "truck", "tank", "motorcycle"]
VIEWS = ["front", "rear", "close", "seat"]
TILE = "800x500"


def take(checkout, shots):
    """Has the game of `checkout` picture every vehicle into `shots`."""
    os.makedirs(shots, exist_ok=True)
    if os.path.realpath(checkout) != ROOT:
        shutil.copy(os.path.join(ROOT, "tools", "vehicle_sheet.gd"), os.path.join(checkout, "tools", "vehicle_sheet.gd"))
    subprocess.run([os.path.join(checkout, "tools", "godot.sh"), "--", "--direct=res://tools/vehicle_sheet.gd", "--shots=" + shots], check=True, timeout=900)


def row(shots, vehicle, label, out):
    """The pictures of one vehicle side by side, with `label` over the first."""
    tiles = []
    for view in VIEWS:
        path = os.path.join(shots, "%s_%s.png" % (vehicle, view))
        tiles.append(path if os.path.isfile(path) else "xc:#202020")
    subprocess.run(["magick"] + [arg for tile in tiles for arg in ["(", tile, "-resize", TILE + "^", "-gravity", "center", "-extent", TILE, ")"]]
                   + ["+append", "-gravity", "northwest", "-font", FONT, "-pointsize", "30", "-fill", "white", "-stroke", "black", "-strokewidth", "1",
                      "-annotate", "+16+12", label, out], check=True)


def main():
    args = sys.argv[1:]
    before = next((arg.split("=", 1)[1] for arg in args if arg.startswith("--before=")), "")
    name = next((arg.split("=", 1)[1] for arg in args if arg.startswith("--name=")), "vehicles")
    results = os.path.join(ROOT, "benchmark", "results", "vehicle_sheet")
    now = os.path.join(results, "now")
    then = os.path.join(results, "before")
    if "--compose" not in args:
        if before:
            take(os.path.abspath(before), then)
        take(ROOT, now)
    rows = []
    for vehicle in VEHICLES:
        if before:
            rows.append(os.path.join(results, "row_%s_before.png" % vehicle))
            row(then, vehicle, "%s: before" % vehicle, rows[-1])
        rows.append(os.path.join(results, "row_%s.png" % vehicle))
        row(now, vehicle, "%s: now" % vehicle if before else vehicle, rows[-1])
    sheet = os.path.join(ROOT, "benchmark", "sheets", name + ".jpg")
    subprocess.run(["magick"] + rows + ["-append", "-quality", "86", sheet], check=True)
    print(sheet)


if __name__ == "__main__":
    main()
