"""The parts route of tools/import_character.sh: a figure built of loose pieces.

Some low-poly characters have no skeleton and no skin: a head, a trunk, two
arms and two legs, each a mesh of its own that is moved as a whole (Kenney's
blocky characters are six boxes). This gives such a figure the skeleton of the
humanoid profile, with the joints read off the pieces, hangs every piece on
its bone, and cuts the arms and legs through at the elbow and the knee so that
they can bend there.
"""

import re

import bmesh
import bpy
import numpy as np
from mathutils import Vector

import humanoid

KINDS = (("head", r"head"), ("trunk", r"torso|body|chest|trunk"), ("arm", r"arm"), ("leg", r"leg"))


def sort(meshes: list):
    """Which piece is which, by its name; None when this is no figure of pieces."""
    found = {}
    for obj in meshes:
        side, key = humanoid.parse(obj.name)
        kind = next((kind for kind, pattern in KINDS if re.search(pattern, key)), None)
        if kind is None:
            return None
        found.setdefault(kind + side, []).append(obj)
    wanted = ("head", "trunk", "armL", "armR", "legL", "legR")
    if any(len(found.get(name, [])) != 1 for name in wanted) or len(found) != len(wanted):
        return None
    return {name: found[name][0] for name in wanted}


def box(obj: bpy.types.Object) -> tuple:
    co = np.array([vertex.co for vertex in obj.data.vertices])
    return co.min(axis=0), co.max(axis=0)


def limb(obj: bpy.types.Object, towards: np.ndarray) -> tuple:
    """The two ends of an arm or a leg: the one nearest the trunk first."""
    low, high = box(obj)
    centre = (low + high) / 2
    axis = int(np.argmax(high - low))
    a, b = centre.copy(), centre.copy()
    a[axis], b[axis] = low[axis], high[axis]
    return (a, b) if np.linalg.norm(a - towards) < np.linalg.norm(b - towards) else (b, a)


def bind(obj: bpy.types.Object, bone: str, lower: str = "", at=None, along=None) -> None:
    """Hangs a piece on one bone, or on two with a cut between them."""
    if lower:
        mesh = bmesh.new()
        mesh.from_mesh(obj.data)
        bmesh.ops.bisect_plane(mesh, geom=mesh.verts[:] + mesh.edges[:] + mesh.faces[:], plane_co=Vector(at), plane_no=Vector(along))
        bmesh.ops.triangulate(mesh, faces=mesh.faces)
        mesh.to_mesh(obj.data)
        mesh.free()
    obj.vertex_groups.clear()
    upper_group = obj.vertex_groups.new(name=bone)
    lower_group = obj.vertex_groups.new(name=lower) if lower else None
    for vertex in obj.data.vertices:
        past = float((np.array(vertex.co) - at) @ along) if lower else -1.0
        if past > 1e-5:
            lower_group.add([vertex.index], 1.0, "REPLACE")
        elif lower and past > -1e-5:
            # On the cut: half to each, so the joint closes when it bends.
            upper_group.add([vertex.index], 0.5, "REPLACE")
            lower_group.add([vertex.index], 0.5, "REPLACE")
        else:
            upper_group.add([vertex.index], 1.0, "REPLACE")


def rig(pieces: dict) -> tuple:
    """Returns the joined mesh and an armature for a figure of loose pieces.
    The pieces are in the world already; the figure looks down -Y."""
    low, high = box(pieces["trunk"])
    centre = (low + high) / 2
    tall = high[2] - low[2]
    head_low, head_high = box(pieces["head"])
    height = float(head_high[2])
    forward = np.array([0.0, -1.0, 0.0])
    joints = {
        "Hips": (centre[0], centre[1], low[2] + 0.12 * tall),
        "Spine": (centre[0], centre[1], low[2] + 0.34 * tall),
        "Chest": (centre[0], centre[1], low[2] + 0.56 * tall),
        "UpperChest": (centre[0], centre[1], low[2] + 0.76 * tall),
        "Neck": (centre[0], centre[1], high[2] - 0.02 * tall),
        "Head": ((head_low[0] + head_high[0]) / 2, (head_low[1] + head_high[1]) / 2, max(head_low[2], high[2]) + 0.02 * tall),
    }
    bind(pieces["trunk"], "Spine")
    bind(pieces["head"], "Head")
    top = np.array([centre[0], centre[1], high[2]])
    bottom = np.array([centre[0], centre[1], low[2]])
    for side, word in (("L", "Left"), ("R", "Right")):
        near, far = limb(pieces["arm" + side], top)
        along = (far - near) / np.linalg.norm(far - near)
        joints[word + "UpperArm"] = tuple(near + (far - near) * 0.1)
        joints[word + "Shoulder"] = tuple(top + (np.array(joints[word + "UpperArm"]) - top) * 0.4)
        joints[word + "LowerArm"] = tuple(near + (far - near) * 0.5)
        joints[word + "Hand"] = tuple(near + (far - near) * 0.84)
        bind(pieces["arm" + side], word + "UpperArm", word + "LowerArm", np.array(joints[word + "LowerArm"]), along)
        near, far = limb(pieces["leg" + side], bottom)
        along = (far - near) / np.linalg.norm(far - near)
        joints[word + "UpperLeg"] = tuple(near + (far - near) * 0.04)
        joints[word + "LowerLeg"] = tuple(near + (far - near) * 0.5)
        joints[word + "Foot"] = tuple(near + (far - near) * 0.9)
        leg_low, leg_high = box(pieces["leg" + side])
        joints[word + "Toes"] = tuple(far + forward * 0.45 * (leg_high[1] - leg_low[1]) + np.array([0.0, 0.0, 0.02 * tall]))
        bind(pieces["leg" + side], word + "UpperLeg", word + "LowerLeg", np.array(joints[word + "LowerLeg"]), along)

    meshes = list(pieces.values())
    for obj in meshes:
        layers = obj.data.uv_layers
        if layers:
            layers[0].name = "UVMap"
    body = meshes[0]
    with bpy.context.temp_override(active_object=body, selected_editable_objects=meshes):
        bpy.ops.object.join()
    import scan
    armature = scan.skeleton({name: tuple(float(value) for value in at) for name, at in joints.items()}, height)
    return body, armature
