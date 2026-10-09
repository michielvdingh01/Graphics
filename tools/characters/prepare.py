"""The Blender half of tools/import_character.sh: from a model file to a GLB
that meets the character contract (one mesh of at most 20 thousand triangles,
metres, feet on the origin, facing +Z, a skeleton with the bone names of
Godot's humanoid profile, one 1K texture set, no animations, no weapon).

    blender -b --python tools/characters/prepare.py -- <file> <out.glb> [options]

A model that has a skeleton keeps it; a statue without one, such as a scan,
goes through scan.py, which cleans it up, fits a skeleton and skins it.
"""

import argparse
import json
import math
import os
import pathlib
import re
import sys
import tempfile

sys.dont_write_bytecode = True

import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import atlas  # noqa: E402
import humanoid  # noqa: E402

WEAPONS = r"weapon|pistol|rifle|gun|knife|sword|blade|grenade|rocket|launcher|bayonet"


def options() -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog="import_character")
    parser.add_argument("source")
    parser.add_argument("target")
    parser.add_argument("--id", default="")
    parser.add_argument("--triangles", type=int, default=20000)
    parser.add_argument("--height", type=float, default=0.0, help="scale to this many metres")
    parser.add_argument("--scale", type=float, default=1.0, help="after that, scale by this much")
    parser.add_argument("--yaw", type=float, default=None, help="degrees to turn instead of guessing the front")
    parser.add_argument("--drop", default="", help="regex of objects and materials to leave out, besides weapons")
    parser.add_argument("--keep-weapons", action="store_true")
    parser.add_argument("--bones", default="", help="JSON file mapping profile bone names to source bone names")
    parser.add_argument("--route", choices=("auto", "rigged", "scan"), default="auto")
    parser.add_argument("--look", default="", help="zombie or clown: paint the character up as one")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--no-delight", action="store_true", help="scan: leave the light that is baked into the texture")
    parser.add_argument("--flip-normal-y", action="store_true", help="the source's normal maps are DirectX style")
    parser.add_argument("--keep", default="", help="folder to leave the Blender scene and the textures in, to look at afterwards")
    parser.add_argument("--report", default="")
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1:])


def load(path: str) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kind = pathlib.Path(path).suffix.lower()
    atlas.LEGACY = kind in (".fbx", ".obj")
    if kind == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path, use_anim=False)
    elif kind in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path, merge_vertices=True)
    elif kind == ".obj":
        bpy.ops.wm.obj_import(filepath=path)
    elif kind in (".usdz", ".usd", ".usda", ".usdc"):
        bpy.ops.wm.usd_import(filepath=path)
    elif kind == ".ply":
        bpy.ops.wm.ply_import(filepath=path)
    elif kind == ".stl":
        bpy.ops.wm.stl_import(filepath=path)
    elif kind == ".blend":
        bpy.ops.wm.open_mainfile(filepath=path)
    else:
        sys.exit("import_character: cannot read %s files (FBX, GLB, glTF, OBJ, USDZ, USD, PLY, STL, blend)" % kind)


def freeze(obj: bpy.types.Object) -> None:
    """Moves an object's place, turn and size into its data, so that it sits
    in the world without a transform of its own."""
    matrix = obj.matrix_world.copy()
    obj.parent = None
    obj.data.transform(matrix)
    obj.matrix_world = Matrix.Identity(4)


def gather(args: argparse.Namespace) -> tuple:
    """Strips the scene down to the meshes of the character and its armature."""
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    found = sum(triangles(obj.data) for obj in bpy.context.scene.objects if obj.type == "MESH")
    drop = re.compile("|".join(part for part in (args.drop, "" if args.keep_weapons else WEAPONS) if part) or r"$^", re.I)
    dropped = []
    meshes = []
    armatures = []
    for obj in list(bpy.context.scene.objects):
        obj.animation_data_clear()
        if obj.type == "ARMATURE":
            armatures.append(obj)
        elif obj.type == "MESH" and len(obj.data.polygons) > 0 and not drop.search(obj.name):
            meshes.append(obj)
        elif obj.type == "MESH" and len(obj.data.polygons) > 0:
            dropped.append(obj.name)
    if not meshes:
        sys.exit("import_character: no mesh in %s" % args.source)

    armature = max(armatures, key=lambda obj: len(obj.data.bones), default=None)
    skinned = []
    for obj in meshes:
        bound = any(modifier.type == "ARMATURE" and modifier.object == armature for modifier in obj.modifiers)
        if armature is not None and obj.parent == armature and obj.parent_type == "BONE":
            # A helmet or a pouch hung on one bone: weigh it to that bone.
            group = obj.vertex_groups.new(name=obj.parent_bone)
            group.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
            bound = True
        if bound:
            skinned.append(obj)
    rigged = args.route == "rigged" or (args.route == "auto" and len(skinned) > 0)
    if rigged and not skinned:
        sys.exit("import_character: --route=rigged, but no mesh is bound to a skeleton")
    if rigged:
        meshes = skinned
    else:
        armature = None

    for obj in meshes:
        if obj.data.shape_keys is not None:
            obj.shape_key_clear()
        for modifier in list(obj.modifiers):
            obj.modifiers.remove(modifier)
        if obj.data.users > 1:
            obj.data = obj.data.copy()
        freeze(obj)
        layers = obj.data.uv_layers
        if layers:
            keep = layers.active or layers[0]
            for layer in [layer for layer in layers if layer != keep]:
                layers.remove(layer)
            layers[0].name = "UVMap"
        # Faces by material: a knife that is part of the body's one mesh.
        slots = [bool(slot.material and drop.search(slot.material.name)) for slot in obj.material_slots]
        if any(slots):
            dropped += [slot.material.name for slot, gone in zip(obj.material_slots, slots) if gone]
            import bmesh
            mesh = bmesh.new()
            mesh.from_mesh(obj.data)
            bmesh.ops.delete(mesh, geom=[face for face in mesh.faces if slots[face.material_index]], context="FACES")
            mesh.to_mesh(obj.data)
            mesh.free()
    if armature is not None:
        freeze(armature)

    keep = set(meshes) | ({armature} if armature else set())
    for obj in list(bpy.context.scene.objects):
        if obj not in keep:
            bpy.data.objects.remove(obj, do_unlink=True)
    body = meshes[0]
    if len(meshes) > 1:
        with bpy.context.temp_override(active_object=body, selected_editable_objects=meshes):
            bpy.ops.object.join()
    body.name = body.data.name = args.id or "character"
    return body, armature, {"source_triangles": found, "dropped": dropped}


def triangles(mesh: bpy.types.Mesh) -> int:
    return sum(len(polygon.vertices) - 2 for polygon in mesh.polygons)


def modify(obj: bpy.types.Object, kind: str, **settings) -> None:
    modifier = obj.modifiers.new(kind, kind)
    for key, value in settings.items():
        setattr(modifier, key, value)
    with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj]):
        bpy.ops.object.modifier_apply(modifier=modifier.name)


def thin(obj: bpy.types.Object, budget: int) -> None:
    """Triangulates, and collapses edges until the mesh is within the budget."""
    modify(obj, "TRIANGULATE", quad_method="FIXED", min_vertices=4)
    for _ in range(6):
        count = triangles(obj.data)
        if count <= budget:
            return
        modify(obj, "DECIMATE", decimate_type="COLLAPSE", ratio=budget / count * 0.985, use_collapse_triangulate=True)


def settle(body: bpy.types.Object, armature, args: argparse.Namespace, forward: Vector, hips: str = "") -> dict:
    """Metres, feet on the origin, looking down -Y (which Godot reads as +Z)."""
    low, high = bounds(body)
    height = high.z - low.z
    if args.height > 0.0:
        scale = args.height / height
    elif 0.9 <= height <= 2.6:
        scale = 1.0
    else:
        # A person of a metre and three quarters, in centimetres, millimetres or inches.
        scale = next((unit for unit in (0.01, 0.001, 0.0254, 100.0) if 0.9 <= height * unit <= 2.6), 0.0)
        if scale == 0.0:
            sys.exit("import_character: the model is %.3g units tall, which is no person in any unit; pass --height=1.8" % height)
    scale *= args.scale
    yaw = math.radians(args.yaw) if args.yaw is not None else math.atan2(-forward.x, -forward.y)
    turn = Matrix.Rotation(yaw, 4, "Z") @ Matrix.Scale(scale, 4)
    centre = turn @ Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    if hips:
        middle = turn @ armature.data.bones[hips].head_local
        centre.x, centre.y = middle.x, middle.y
    matrix = Matrix.Translation(-centre) @ turn
    body.data.transform(matrix)
    if armature is not None:
        armature.data.transform(matrix)
    body.data.update()
    low, high = bounds(body)
    return {"height": round(high.z, 3), "scaled": round(scale, 5), "turned": round(math.degrees(yaw), 1)}


def bounds(obj: bpy.types.Object) -> tuple:
    co = np.empty(len(obj.data.vertices) * 3, dtype=np.float32)
    obj.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    return Vector(co.min(axis=0)), Vector(co.max(axis=0))


def soften(body: bpy.types.Object) -> None:
    """Makes see-through cards, which is to say hair, look like the one mass
    they stand for. Every card gets the normals of a ball around their middle:
    each lit by its own flat face, they come out as light and dark planks. And
    every card gets a second face looking the other way with those same
    normals, instead of a material that shows both sides: seen from behind, a
    card that the engine has to turn around picks up a grey sheen."""
    mesh = body.data
    if len(mesh.materials) < 2:
        return
    import bmesh
    both = bmesh.new()
    both.from_mesh(mesh)
    cards = [face for face in both.faces if face.material_index == 1]
    copies = bmesh.ops.duplicate(both, geom=cards)
    bmesh.ops.reverse_faces(both, faces=[item for item in copies["geom"] if isinstance(item, bmesh.types.BMFace)])
    both.to_mesh(mesh)
    both.free()
    slot = np.empty(len(mesh.polygons), dtype=np.int32)
    mesh.polygons.foreach_get("material_index", slot)
    start = np.empty(len(mesh.polygons), dtype=np.int32)
    mesh.polygons.foreach_get("loop_start", start)
    corners = (start[slot == 1][:, None] + np.arange(3)[None, :]).ravel()
    vertex = np.empty(len(mesh.loops), dtype=np.int32)
    mesh.loops.foreach_get("vertex_index", vertex)
    co = np.empty(len(mesh.vertices) * 3, dtype=np.float32)
    mesh.vertices.foreach_get("co", co)
    at = co.reshape(-1, 3)[vertex[corners]]
    normals = np.empty(len(mesh.loops) * 3, dtype=np.float32)
    mesh.corner_normals.foreach_get("vector", normals)
    normals = normals.reshape(-1, 3)
    outward = at - at.mean(axis=0)
    normals[corners] = outward / np.maximum(np.linalg.norm(outward, axis=1, keepdims=True), 1e-6)
    mesh.normals_split_custom_set(normals.tolist())


def export(body: bpy.types.Object, armature: bpy.types.Object, target: str) -> None:
    armature.name = "Armature"
    armature.data.name = "Armature"
    body.parent = armature
    body.matrix_parent_inverse = Matrix.Identity(4)
    for modifier in list(body.modifiers):
        body.modifiers.remove(modifier)
    # Vertex colours would be multiplied into the texture, and cost eight floats a vertex.
    for attribute in list(body.data.color_attributes):
        body.data.color_attributes.remove(attribute)
    modifier = body.modifiers.new("Armature", "ARMATURE")
    modifier.object = armature
    for obj in bpy.context.scene.objects:
        obj.select_set(obj in (body, armature))
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(
        filepath=target, export_format="GLB", use_selection=True, export_yup=True,
        export_animations=False, export_skins=True, export_morph=False, export_all_influences=False,
        export_def_bones=False, export_rest_position_armature=True, export_leaf_bone=False,
        export_normals=True, export_tangents=False, export_texcoords=True, export_materials="EXPORT",
        export_image_format="AUTO", export_cameras=False, export_lights=False, export_extras=False,
    )


def share_textures(path: str) -> None:
    """Makes the materials in a GLB refer to one set of textures. Blender
    writes a texture entry per material even when the image is the same, and
    Godot then keeps a copy of the image for each."""
    import struct
    data = pathlib.Path(path).read_bytes()
    length = struct.unpack_from("<I", data, 12)[0]
    document = json.loads(data[20:20 + length])
    rest = data[20 + length:]
    kept = []
    moved = {}
    for index, texture in enumerate(document.get("textures", [])):
        if texture not in kept:
            kept.append(texture)
        moved[index] = kept.index(texture)
    if len(kept) == len(moved):
        return

    def walk(value) -> None:
        if isinstance(value, dict):
            for key, inner in value.items():
                if key.endswith("Texture") and isinstance(inner, dict) and "index" in inner:
                    inner["index"] = moved[inner["index"]]
                else:
                    walk(inner)
        elif isinstance(value, list):
            for inner in value:
                walk(inner)

    walk(document.get("materials", []))
    document["textures"] = kept
    text = json.dumps(document, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    header = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(text) + len(rest))
    pathlib.Path(path).write_bytes(header + struct.pack("<I4s", len(text), b"JSON") + text + rest)


def main() -> None:
    args = options()
    load(args.source)
    body, armature, report = gather(args)

    if armature is not None:
        report["route"] = "rigged"
        names = {group.name for group in body.vertex_groups}
        try:
            mapping = json.loads(pathlib.Path(args.bones).read_text()) if args.bones else humanoid.guess(armature, names)
        except ValueError as error:
            sys.exit("import_character: cannot tell which bone is which: %s\nPass --bones=<file.json> with a map from profile names (Hips, Spine, LeftUpperArm...) to this model's bone names." % error)
        report["source_bones"] = len(armature.data.bones)
        bones = armature.data.bones
        across = bones[mapping["LeftUpperLeg"]].head_local - bones[mapping["RightUpperLeg"]].head_local
        forward = across.cross(Vector((0.0, 0.0, 1.0))).normalized()
        report.update(settle(body, armature, args, forward, mapping["Hips"]))
        report.update(humanoid.conform(armature, [body], mapping, Vector((0.0, -1.0, 0.0))))
        thin(body, args.triangles)
        textures = atlas.pack(body)
    else:
        import scan
        report["route"] = "scan"
        body, armature, textures = scan.rig(body, args, report)

    if args.flip_normal_y:
        textures.normal[:, :, 1] = 1.0 - textures.normal[:, :, 1]
    if args.look:
        import looks
        report["look"] = looks.apply(args.look, body, armature, textures, args.seed)
    textures.finish()
    folder = os.path.abspath(args.keep) if args.keep else tempfile.mkdtemp(prefix="character_")
    os.makedirs(folder, exist_ok=True)
    textures.material(body, args.id or "character", folder)
    soften(body)
    export(body, armature, args.target)
    share_textures(args.target)

    report["joints"] = {bone.name: [round(value, 4) for value in bone.head_local] for bone in armature.data.bones}
    report["triangles"] = triangles(body.data)
    report["vertices"] = len(body.data.vertices)
    report["bones"] = len(armature.data.bones)
    report["textures"] = dict(textures.notes, size=textures.side, cutout=textures.cutout)
    report["bytes"] = os.path.getsize(args.target)
    report["blender"] = bpy.app.version_string
    if args.keep:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(folder, (args.id or "character") + ".blend"))
    if args.report:
        pathlib.Path(args.report).write_text(json.dumps(report, indent="\t") + "\n")
    print("import_character: " + json.dumps(report))


if __name__ == "__main__":
    main()
