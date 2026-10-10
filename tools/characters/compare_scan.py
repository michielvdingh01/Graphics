"""Holds what the scan route made of the practice scan against the original.

    blender -b --python tools/characters/compare_scan.py -- <folder>

The folder is the one tools/characters/test_scan.sh fills. Compares the
joints that were fitted to the statue with the skeleton the model really had,
and the colours that came out of the de-lighting with the model's real ones.
"""

import json
import os
import sys

import bpy
import numpy as np

JOINTS = ("Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
          "RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes",
          "RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes")


def colours(folder: str, name: str) -> np.ndarray:
    image = bpy.data.images.load(os.path.join(folder, name, name + "_color.jpg"))
    data = np.empty(image.size[0] * image.size[1] * 4, dtype=np.float32)
    image.pixels.foreach_get(data)
    return data.reshape(image.size[1], image.size[0], 4)[:, :, :3]


def main() -> None:
    folder = sys.argv[sys.argv.index("--") + 1]
    real = json.load(open(os.path.join(folder, "original.json")))
    scan = json.load(open(os.path.join(folder, "scan.json")))
    print("compare: the original has %d triangles; the scan had %d and its character has %d" % (real["triangles"], scan["source_triangles"], scan["triangles"]))
    print("compare: height %.3f m against %.3f m; the scan was turned back by %.1f degrees (it was made at 137)" % (scan["height"], real["height"], -scan["turned"]))
    off = {name: float(np.linalg.norm(np.array(scan["joints"][name]) - np.array(real["joints"][name]))) * 100.0 for name in JOINTS}
    print("compare: fitted joints are %.1f cm from the real ones on average, the worst %.1f cm (%s)" % (np.mean(list(off.values())), max(off.values()), max(off, key=off.get)))
    print("compare:   " + ", ".join("%s %.1f" % (name, off[name]) for name in JOINTS))

    truth, lit, clean = colours(folder, "truth"), colours(folder, "lit"), colours(folder, "delit")
    covered = truth.max(axis=2) > 0.02
    weights = np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    for label, image in (("as scanned", lit), ("light removed", clean)):
        ratio = (image @ weights)[covered] / np.maximum((truth @ weights)[covered], 0.02)
        print("compare: colour %-14s mean error %.3f; brightness against the real colour: median %.2f, within 15%% for %.0f%% of the surface, darker than 70%% for %.0f%%" % (
            label, float(np.abs(image - truth)[covered].mean()), float(np.median(ratio)), 100.0 * float((np.abs(ratio - 1.0) < 0.15).mean()), 100.0 * float((ratio < 0.7).mean())))


if __name__ == "__main__":
    main()
