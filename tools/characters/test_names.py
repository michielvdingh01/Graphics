"""Checks that humanoid.py recognises the bones of skeletons it has not met.

    blender -b --python tools/characters/test_names.py

The cast so far all comes with the bone names of 3ds Max. This builds bare
skeletons named the way Mixamo, Unreal, Blender's Rigify and Quaternius name
theirs, twist and steering bones included, and prints which bone of each was
taken for which bone of the profile. It tests the names only: no model with
these skeletons has been through the import route yet.
"""

import pathlib
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(pathlib.Path(__file__).parent))

import bpy  # noqa: E402

import humanoid  # noqa: E402

def chain(prefix, names, parent):
    out = []
    for n in names:
        out.append((prefix + n, parent)); parent = prefix + n
    return out

def mixamo():
    p = "mixamorig:"
    rows = [(p + "Hips", None)] + chain(p, ["Spine", "Spine1", "Spine2", "Neck", "Head", "HeadTop_End"], p + "Hips")
    for side in ("Left", "Right"):
        rows += chain(p, [side + "Shoulder", side + "Arm", side + "ForeArm", side + "Hand"], p + "Spine2")
        for f in ("Thumb", "Index", "Middle", "Ring", "Pinky"):
            rows += chain(p, [side + "Hand" + f + str(i) for i in (1, 2, 3, 4)], p + side + "Hand")
        rows += chain(p, [side + "UpLeg", side + "Leg", side + "Foot", side + "ToeBase", side + "Toe_End"], p + "Hips")
    return rows

def unreal():
    rows = [("root", None), ("pelvis", "root"), ("ik_hand_root", "root"), ("ik_hand_l", "ik_hand_root"), ("ik_hand_r", "ik_hand_root"), ("ik_foot_root", "root"), ("ik_foot_l", "ik_foot_root"), ("ik_foot_r", "ik_foot_root")]
    rows += chain("", ["spine_01", "spine_02", "spine_03", "spine_04", "spine_05", "neck_01", "neck_02", "head"], "pelvis")
    for s in ("l", "r"):
        rows += chain("", ["clavicle_" + s, "upperarm_" + s, "lowerarm_" + s, "hand_" + s], "spine_05")
        rows += [("upperarm_twist_01_" + s, "upperarm_" + s), ("lowerarm_twist_01_" + s, "lowerarm_" + s)]
        for f in ("thumb", "index", "middle", "ring", "pinky"):
            names = ["%s_0%d_%s" % (f, i, s) for i in (1, 2, 3)]
            if f != "thumb": names = ["%s_metacarpal_%s" % (f, s)] + names
            rows += chain("", names, "hand_" + s)
        rows += chain("", ["thigh_" + s, "calf_" + s, "foot_" + s, "ball_" + s], "pelvis")
        rows += [("thigh_twist_01_" + s, "thigh_" + s), ("calf_twist_01_" + s, "calf_" + s)]
    return rows

def blender():
    rows = [("spine", None)] + chain("", ["spine.001", "spine.002", "spine.003", "spine.004", "spine.005", "spine.006"], "spine")
    for s in ("L", "R"):
        rows += chain("", ["shoulder." + s, "upper_arm." + s, "forearm." + s, "hand." + s], "spine.003")
        for f in ("thumb", "f_index", "f_middle", "f_ring", "f_pinky"):
            rows += chain("", ["%s.0%d.%s" % (f, i, s) for i in (1, 2, 3)], "hand." + s)
        rows += chain("", ["thigh." + s, "shin." + s, "foot." + s, "toe." + s], "spine")
    return rows

def quaternius():
    rows = [("Root", None), ("Hips", "Root"), ("Abdomen", "Hips"), ("Torso", "Abdomen"), ("Neck", "Torso"), ("Head", "Neck")]
    for s in ("L", "R"):
        rows += chain("", ["Shoulder." + s, "UpperArm." + s, "LowerArm." + s, "Fist." + s], "Torso")
        rows += chain("", ["UpperLeg." + s, "LowerLeg." + s, "Foot." + s], "Hips")
    return rows

for label, rows in (("mixamo", mixamo()), ("unreal", unreal()), ("blender", blender()), ("quaternius", quaternius())):
    data = bpy.data.armatures.new(label); obj = bpy.data.objects.new(label, data); bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj; bpy.ops.object.mode_set(mode="EDIT")
    for i, (name, parent) in enumerate(rows):
        b = data.edit_bones.new(name); b.head = (i * 0.01, 0, i * 0.02); b.tail = (i * 0.01, 0, i * 0.02 + 0.05)
        if parent: b.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    try:
        m = humanoid.guess(obj, {name for name, _ in rows if "ik_" not in name})
        missing = [n for n in humanoid.ORDER if n not in m and n != "Root"]
        print("names: %-10s mapped %d of %d; body: %s" % (label, len(m), len(humanoid.ORDER) - 1, {k: m.get(k) for k in ("Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes", "LeftThumbMetacarpal", "LeftIndexProximal", "LeftIndexDistal", "LeftLittleDistal")}))
        print("names:            not in this skeleton:", ", ".join(missing))
    except Exception as e:
        print("names: %-10s FAILED: %s" % (label, e))
