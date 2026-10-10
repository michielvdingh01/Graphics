"""Measures how well landmarks.py finds the joints, on people whose joints are known.

    blender -b --python tools/characters/calibrate.py -- <rigged model> [more]

Each model is taken through the rigged route to get its real joints, then
turned into a statue (its skeleton thrown away, its surface rebuilt the way
the scan route does it) and handed to landmarks.fit. Prints how far each
fitted joint is from the real one, and what value each proportion in
landmarks.py would have needed to be to hit it exactly: the averages of those
over the Rocketbox library are the constants in that file.
"""

import argparse
import pathlib
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(pathlib.Path(__file__).parent))

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402

import humanoid  # noqa: E402
import landmarks  # noqa: E402
import prepare  # noqa: E402
import scan  # noqa: E402

JOINTS = ("Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
          "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes", "RightUpperArm", "RightLowerArm", "RightHand", "RightUpperLeg", "RightLowerLeg", "RightFoot")


def measure(path: str) -> tuple:
    args = argparse.Namespace(source=path, drop="", keep_weapons=False, route="auto", id="statue", height=0.0, scale=1.0, wide=1.0, yaw=None)
    prepare.load(path)
    body, armature, _ = prepare.gather(args)
    mapping = humanoid.guess(armature, {group.name for group in body.vertex_groups})
    bones = armature.data.bones
    across = bones[mapping["LeftUpperLeg"]].head_local - bones[mapping["RightUpperLeg"]].head_local
    prepare.settle(body, armature, args, across.cross(Vector((0.0, 0.0, 1.0))).normalized(), mapping["Hips"])
    humanoid.conform(armature, [body], mapping, Vector((0.0, -1.0, 0.0)))
    truth = {bone.name: np.array(bone.head_local) for bone in armature.data.bones}
    # Hair that is drawn on see-through cards is not something a scan would have.
    statue = scan.shell(body, "shell")
    measures = {}
    fitted = landmarks.fit(scan.coordinates(statue.data), measures)
    return truth, {name: np.array(at) for name, at in fitted.items()}, measures


def main() -> None:
    files = sys.argv[sys.argv.index("--") + 1:]
    errors = {name: [] for name in JOINTS}
    signed = {}
    ideal = {}
    for path in files:
        name = pathlib.Path(path).stem
        try:
            truth, fitted, m = measure(path)
        except landmarks.PoseError as error:
            print("%-22s FAILED: %s" % (name, error))
            continue
        height = m["height"]
        off = {joint: float(np.linalg.norm(fitted[joint] - truth[joint])) * 100.0 for joint in JOINTS}
        for joint in JOINTS:
            errors[joint].append(off[joint])
            signed.setdefault(joint, []).append((fitted[joint] - truth[joint]) * 100.0)
        print("%-22s %.2f m  mean %.1f cm  worst %s %.1f cm" % (name, height, np.mean(list(off.values())), max(off, key=off.get), max(off.values())))

        def add(key: str, value: float) -> None:
            ideal.setdefault(key, []).append(float(value))

        z_base = truth["Neck"][2]
        add("NECK", z_base / height)
        add("NECK_DOWN", (m["neck"] - z_base) / height)
        add("HEAD", (truth["Head"][2] - z_base) / height)
        add("HIP", truth["Hips"][2] / height)
        for index, joint in enumerate(("Spine", "Chest", "UpperChest")):
            add("SPINE%d" % index, (truth[joint][2] - truth["Hips"][2]) / (z_base - truth["Hips"][2]))
        add("ANKLE", truth["LeftFoot"][2] / height)
        add("KNEE", (truth["LeftLowerLeg"][2] - truth["LeftFoot"][2]) / (truth["LeftUpperLeg"][2] - truth["LeftFoot"][2]))
        for word, sign in (("Left", 1.0), ("Right", -1.0)):
            side = m[word]
            shoulder = truth[word + "UpperArm"]
            add("SHOULDER", shoulder[2] / height)
            add("SHOULDER_PIT", (shoulder[2] - m["pit"]) / height)
            add("SHOULDER_WIDE", (shoulder[0] - m["middle"]) * sign / height)
            add("SHOULDER_IN", (side["edge"] - shoulder[0]) * sign / height)
            add("SHOULDER_BACK", (shoulder[1] - m["shoulder_y"]) / height)
            add("CLAVICLE", (truth[word + "Shoulder"][0] - m["middle"]) / (shoulder[0] - m["middle"]))
            add("ELBOW", (shoulder[2] - truth[word + "LowerArm"][2]) / (shoulder[2] - side["tip"][2]))
            add("WRIST", (shoulder[2] - truth[word + "Hand"][2]) / (shoulder[2] - side["tip"][2]))
            add("HIP_OUT", (truth[word + "UpperLeg"][0] - m["middle"]) / (side["leg_x"] - m["middle"]))
            add("TOE", (truth[word + "Toes"][1] - side["ankle_y"]) / (side["toe_tip"] - side["ankle_y"]))
    print()
    for joint in JOINTS:
        if errors[joint]:
            print("%-16s mean %4.1f cm  worst %4.1f cm  off on average by x %+.1f y %+.1f z %+.1f" % ((joint, np.mean(errors[joint]), np.max(errors[joint])) + tuple(np.mean(signed[joint], axis=0))))
    everything = [value for values in errors.values() for value in values]
    if everything:
        print("%-16s mean %4.1f cm  worst %4.1f cm  (%d people)" % ("all joints", np.mean(everything), np.max(everything), len(errors["Hips"])))
    print()
    for key in sorted(ideal):
        print("%-18s %.3f  (spread %.3f, from %.3f to %.3f, now %s)" % (key, np.mean(ideal[key]), np.std(ideal[key]), min(ideal[key]), max(ideal[key]), getattr(landmarks, key, landmarks.SPINE[int(key[-1])] if key.startswith("SPINE") else "-")))


if __name__ == "__main__":
    main()
