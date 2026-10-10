"""Turns whatever skeleton a model came with into Godot's humanoid profile.

Godot can only share animations between characters whose bones carry the names
of SkeletonProfileHumanoid. This finds those bones in a source skeleton by name
and by where they sit in the hierarchy, renames them, hands the weights of every
other bone (twist bones, face bones, helpers) to the nearest bone that stays,
and adds the profile bones the source did not have, so that every character
ends up with the same list and an animation moves them all alike.
"""

import json
import pathlib
import re

import bpy
from mathutils import Vector

PROFILE = json.loads(pathlib.Path(__file__).with_name("humanoid_profile.json").read_text())["bones"]
ORDER = [bone["name"] for bone in PROFILE]
PARENT = {bone["name"]: bone["parent"] for bone in PROFILE}
REQUIRED = [bone["name"] for bone in PROFILE if bone["required"]]
# Godot looks along +Z with +Y up; in Blender that is -Y with +Z up.
REFERENCE = {bone["name"]: Vector((bone["position"][0], -bone["position"][2], bone["position"][1])) for bone in PROFILE}

SPINE = ("Spine", "Chest", "UpperChest")
FINGERS = ("Thumb", "Index", "Middle", "Ring", "Little")
SEGMENTS = {"Thumb": ("Metacarpal", "Proximal", "Distal")}
OTHER_SEGMENTS = ("Proximal", "Intermediate", "Distal")

_PREFIX = re.compile(r"^(mixamorig\d*|bip0*\d*|valvebiped|def|org|cc_base|rig|jnt|joint|bn|b)(?=[\s:._\-]|$)", re.I)
_HELPER = re.compile(r"(^|[^a-z])(ik|pole|target|ctrl|control|twist|roll|helper|nub|end)([^a-z]|$)", re.I)
_HAND = {"hand", "wrist", "fist", "palm"}
_FOOT = {"foot", "ankle"}
_HIPS = {"hips", "hip", "pelvis"}
_TOES = {"toe", "toes", "toebase", "ball", "toe0", "toes0"}
_JAW = {"jaw", "mjaw", "chin"}
_FINGER_NAMES = {"thumb": "Thumb", "index": "Index", "pointer": "Index", "middle": "Middle", "mid": "Middle", "ring": "Ring", "pinky": "Little", "pinkie": "Little", "little": "Little"}


def parse(name: str) -> tuple:
    """'Bip01 L UpperArm', 'mixamorig:LeftArm' and 'upperarm_l' -> ('L', 'upperarm')."""
    name = name.split("|")[-1].split(":")[-1]
    name = _PREFIX.sub("", name.strip())
    parts = [part.lower() for part in re.findall(r"[A-Z]+(?![a-z])|[A-Z]?[a-z]+|\d+", name)]
    side = ""
    rest = []
    for part in parts:
        if part in ("l", "left") and not side:
            side = "L"
        elif part in ("r", "right") and not side:
            side = "R"
        else:
            rest.append(part)
    return side, "".join(rest)


def guess(armature: bpy.types.Object, weighted: set) -> dict:
    """Maps profile bone names to the names of the armature's bones."""
    bones = armature.data.bones
    parsed = {bone.name: parse(bone.name) for bone in bones}

    def carries(bone) -> bool:
        return bone.name in weighted or any(child.name in weighted for child in bone.children_recursive)

    def pick(keys: set, side: str, among=None):
        found = [bone for bone in (among or bones) if parsed[bone.name][1] in keys and parsed[bone.name][0] == side]
        # A rig often has a second hand or foot to steer the first with; the
        # one that the mesh hangs on is the one to keep.
        found.sort(key=lambda bone: (not carries(bone), bool(_HELPER.search(bone.name)), len(bone.parent_recursive)))
        return found[0] if found else None

    mapping = {}
    head = pick({"head"}, "")
    if head is None:
        # Some rigs number the whole spine through to the skull. Then the head
        # is where the bones end that go up from where the arms branch off.
        hands = [pick(_HAND, side) for side in "LR"]
        if None in hands:
            raise ValueError("no bone named like a head or like hands among: %s" % ", ".join(sorted(bones.keys())[:40]))
        arms = [{bone.name for bone in [hand] + hand.parent_recursive} for hand in hands]
        head = next(bone for bone in hands[0].parent_recursive if bone.name in arms[1])
        while True:
            up = [child for child in head.children if child.name not in arms[0] and child.name not in arms[1] and carries(child)]
            if len(up) != 1:
                break
            head = up[0]
    spine_path = [head] + head.parent_recursive
    on_spine = {bone.name for bone in spine_path}

    hips = next((bone for bone in reversed(spine_path) if parsed[bone.name][1] in _HIPS), None)
    feet = {side: pick(_FOOT, side) for side in "LR"}
    legs = {}
    for side, foot in feet.items():
        if foot is None:
            raise ValueError("no %s foot among the bones" % ("left" if side == "L" else "right"))
        chain = []
        bone = foot.parent
        while bone is not None and bone.name not in on_spine:
            chain.append(bone)
            bone = bone.parent
        if len(chain) < 2:
            raise ValueError("the leg above %s has fewer than two bones" % foot.name)
        legs[side] = chain
    if hips is None:
        # Nothing is called hips or pelvis: it is the last bone the legs and
        # the head share.
        above = [bone.name for bone in legs["L"][-1].parent_recursive]
        hips = next(bone for bone in spine_path if bone.name in above)
    mapping["Hips"] = hips.name

    between = spine_path[1:spine_path.index(hips)][::-1]  # from the hips up
    necks = [bone for bone in between if parsed[bone.name][1].startswith("neck")]
    if not necks and len(between) >= 4:
        necks = [between[-1]]
    if necks:
        mapping["Neck"] = necks[0].name
    spine = [bone for bone in between if bone not in necks]
    if not spine:
        raise ValueError("no spine between %s and %s" % (hips.name, head.name))
    if len(spine) <= 3:
        chosen = spine
    else:
        chosen = [spine[0], spine[(len(spine) - 1) // 2], spine[-1]]
    for name, bone in zip(SPINE, chosen):
        mapping[name] = bone.name
    mapping["Head"] = head.name

    for side, word in (("L", "Left"), ("R", "Right")):
        foot = feet[side]
        chain = legs[side]
        named = next((bone for bone in chain if re.search(r"thigh|upleg|upperleg|legupper", parsed[bone.name][1])), None)
        mapping[word + "UpperLeg"] = (named or chain[-1]).name
        mapping[word + "LowerLeg"] = chain[0].name
        mapping[word + "Foot"] = foot.name
        toes = pick(_TOES, side, foot.children_recursive) or (foot.children[0] if len(foot.children) == 1 else None)
        if toes is not None:
            mapping[word + "Toes"] = toes.name

        hand = pick(_HAND, side)
        if hand is None:
            raise ValueError("no %s hand among the bones" % word.lower())
        chain = []
        bone = hand.parent
        while bone is not None and bone.name not in on_spine:
            chain.append(bone)
            bone = bone.parent
        if len(chain) < 2:
            raise ValueError("the arm above %s has fewer than two bones" % hand.name)
        mapping[word + "Hand"] = hand.name
        mapping[word + "LowerArm"] = chain[0].name
        if len(chain) == 2:
            mapping[word + "UpperArm"] = chain[1].name
        else:
            mapping[word + "Shoulder"] = chain[-1].name
            named = next((bone for bone in chain[1:-1] if re.search(r"upperarm|uparm|armupper|^arm$", parsed[bone.name][1])), None)
            mapping[word + "UpperArm"] = (named or chain[-2]).name

        for finger in hand.children:
            if not carries(finger):
                continue
            key = parsed[finger.name][1]
            which = next((value for word_, value in _FINGER_NAMES.items() if word_ in key), None)
            if which is None:
                # 3ds Max numbers them from the thumb: Finger0, Finger1...
                number = re.fullmatch(r"(?:finger|digit)(\d)\d?", key)
                if number is None or int(number.group(1)) > 4:
                    continue
                which = FINGERS[int(number.group(1))]
            chain = [finger]
            while len(chain[-1].children) == 1:
                chain.append(chain[-1].children[0])
            if which != "Thumb" and "carpal" in key:
                chain = chain[1:]
            for segment, bone in zip(SEGMENTS.get(which, OTHER_SEGMENTS), chain):
                mapping[word + which + segment] = bone.name

        eye = pick({"eye"}, side, head.children_recursive)
        if eye is not None:
            mapping[word + "Eye"] = eye.name
    jaw = pick(_JAW, "", head.children_recursive)
    if jaw is not None:
        mapping["Jaw"] = jaw.name

    missing = [name for name in REQUIRED if name not in mapping and not name.endswith("Shoulder")]
    if missing:
        raise ValueError("could not find: %s" % ", ".join(missing))
    return mapping


def conform(armature: bpy.types.Object, meshes: list, mapping: dict, forward: Vector) -> dict:
    """Rebuilds the armature as the profile's skeleton and moves the weights along."""
    source_of = {source: name for name, source in mapping.items()}
    bones = armature.data.bones

    # Every bone that goes hands its weights to the first bone above it that stays.
    heir = {}
    for bone in bones:
        at = bone
        while at is not None and at.name not in source_of:
            at = at.parent
        heir[bone.name] = source_of[at.name] if at is not None else "Hips"

    unweighted = 0
    for mesh in meshes:
        names = [group.name for group in mesh.vertex_groups]
        weights = []
        for vertex in mesh.data.vertices:
            sums = {}
            for element in vertex.groups:
                target = heir.get(names[element.group])
                if target is not None and element.weight > 0.0:
                    sums[target] = sums.get(target, 0.0) + element.weight
            # Godot skins with four bones per vertex.
            top = sorted(sums.items(), key=lambda item: -item[1])[:4]
            total = sum(weight for _, weight in top)
            if total <= 0.0:
                unweighted += 1
                top, total = [("Hips", 1.0)], 1.0
            weights.append([(target, weight / total) for target, weight in top])
        mesh.vertex_groups.clear()
        groups = {}
        for index, entries in enumerate(weights):
            for target, weight in entries:
                if target not in groups:
                    groups[target] = mesh.vertex_groups.new(name=target)
                groups[target].add([index], weight, "REPLACE")

    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    edit = armature.data.edit_bones
    for bone in list(edit):
        bone.use_connect = False
        bone.name = "source:" + bone.name
    for name, source in mapping.items():
        edit["source:" + source].name = name
    for bone in list(edit):
        if bone.name.startswith("source:"):
            edit.remove(bone)

    height = max((mesh.matrix_world @ vertex.co).z for mesh in meshes for vertex in mesh.data.vertices)
    added = complete(edit, forward, height)
    bpy.ops.object.mode_set(mode="OBJECT")
    return {"added": added, "unweighted": unweighted}


def complete(edit, forward: Vector, height: float) -> list:
    """Adds the profile bones an armature in edit mode does not have yet, and
    hangs every bone on the parent the profile gives it."""
    added = []
    for name in ORDER:
        if name in edit:
            continue
        added.append(name)
        bone = edit.new(name)
        bone.head = _place(name, edit, forward, height)
        bone.tail = bone.head + Vector((0.0, 0.0, 0.03))
        bone.use_deform = name != "Root"
    for name in ORDER:
        edit[name].use_connect = False
        edit[name].parent = edit[PARENT[name]] if PARENT[name] else None
    # Blender throws a bone without length away when it leaves edit mode, and
    # weighs a skin by where each bone points.
    for name in ORDER:
        bone = edit[name]
        children = [child.name for child in bone.children]
        toward = None
        if name in _TOWARD:
            toward = edit[_TOWARD[name]].head
        elif len(children) == 1:
            toward = edit[children[0]].head
        elif name.endswith("Hand"):
            toward = bone.head + (bone.head - bone.parent.head).normalized() * (0.105 * height)
        elif name == "Head":
            toward = Vector((bone.head.x, bone.head.y, max(height * 0.985, bone.head.z + 0.05 * height)))
        elif bone.parent is not None:
            toward = bone.head + (bone.head - bone.parent.head) * 0.4
        if toward is None or (toward - bone.head).length < 0.005 * height:
            toward = bone.head + Vector((0.0, 0.0, 0.03 * height))
        bone.tail = toward
        bone.roll = 0.0
    return added


_TOWARD = {"Root": "Hips", "Hips": "Spine", "Spine": "Chest", "Chest": "UpperChest", "UpperChest": "Neck", "Neck": "Head"}


def _place(name: str, edit, forward: Vector, height: float) -> Vector:
    """Where a bone the source did not have belongs, given the ones it did have."""
    up = Vector((0.0, 0.0, 1.0))
    if name == "Root":
        return Vector((0.0, 0.0, 0.0))
    parent = edit[PARENT[name]].head
    if name in SPINE or name == "Neck":
        # Spread what is missing evenly up to the next bone that is there.
        chain = ("Spine", "Chest", "UpperChest", "Neck", "Head")
        after = chain.index(name)
        upto = next(index for index in range(after, len(chain)) if chain[index] in edit)
        return parent.lerp(edit[chain[upto]].head, 1.0 / (upto - after + 1))
    if name.endswith("Shoulder"):
        arm = edit[name.replace("Shoulder", "UpperArm")].head
        return Vector((arm.x * 0.35, arm.y, arm.z))
    if name.endswith("Toes"):
        foot = edit[name.replace("Toes", "Foot")].head
        return Vector((foot.x, foot.y, 0.0)) + forward * (0.075 * height) + up * (0.01 * height)
    if name.endswith("Eye"):
        side = 1.0 if name.startswith("Left") else -1.0
        return parent + Vector((side * 0.018 * height, 0.0, 0.055 * height)) + forward * (0.048 * height)
    if name == "Jaw":
        return parent + up * (0.017 * height) + forward * (0.01 * height)
    # Fingers: the profile's own layout, laid along the hand and scaled to the forearm.
    word = "Left" if name.startswith("Left") else "Right"
    hand = edit[word + "Hand"].head
    lower = edit[word + "LowerArm"].head
    along = (hand - lower).normalized()
    scale = (hand - lower).length / 0.25
    across = (forward - along * forward.dot(along)).normalized()
    offset = REFERENCE[name] - REFERENCE[word + "Hand"]
    return hand + along * (abs(offset.x) * scale) + across * (-offset.y * scale)
