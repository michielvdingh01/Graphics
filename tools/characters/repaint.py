"""Paints a look on a character that has been through the route before and
leaves the rest of it as it is: --route=repaint.

    tools/import_character.sh assets/characters/soldier_01/soldier_01.glb soldier_01_desert --route=repaint --look=desert

The source is a character's own GLB, for when what it was made from is not
at hand, or when nothing but the paint should differ. Sending such a file
through the whole route again thins nothing and finds every bone, but it
packs the layout of the texture a second time and resamples all three
textures to fit: on soldier_01 that took a quarter of the sharpness out of
the colour and three tenths out of the normal map, and gave the mesh 86 more
vertices. Here Blender only reads the model, so that the look knows where on
the body every texel lies. The textures the look changed are put back into a
copy of the file, which for a uniform is the colour; the mesh, the skeleton,
the skin, the layout and the other textures stay what they were, byte for
byte. A look that adds to the mesh, such as a clown's nose, is not for this.
"""

import json
import os
import pathlib
import struct
import sys
import tempfile

import bpy
import numpy as np

import atlas
import looks


def unpack(path: str) -> tuple:
    """A GLB as its description and the bytes of each of its buffer views."""
    data = pathlib.Path(path).read_bytes()
    if data[:4] != b"glTF":
        sys.exit("import_character: --route=repaint takes a .glb file, which %s is not" % path)
    length = struct.unpack_from("<I", data, 12)[0]
    document = json.loads(data[20:20 + length])
    start = 20 + length + 8
    binary = data[start:start + struct.unpack_from("<I", data, start - 8)[0]]
    if len(document.get("buffers", [])) != 1 or "uri" in document["buffers"][0]:
        sys.exit("import_character: --route=repaint takes a .glb that holds everything itself")
    views = [binary[view.get("byteOffset", 0):view.get("byteOffset", 0) + view["byteLength"]] for view in document["bufferViews"]]
    return document, views


def pack(path: str, document: dict, views: list) -> None:
    """Writes a GLB with these bytes for its buffer views, one after the other."""
    binary = bytearray()
    for view, content in zip(document["bufferViews"], views):
        binary += b"\0" * (-len(binary) % 4)
        view["byteOffset"] = len(binary)
        view["byteLength"] = len(content)
        binary += content
    binary += b"\0" * (-len(binary) % 4)
    document["buffers"][0]["byteLength"] = len(binary)
    text = json.dumps(document, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    header = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(text) + 8 + len(binary))
    pathlib.Path(path).write_bytes(header + struct.pack("<I4s", len(text), b"JSON") + text + struct.pack("<I4s", len(binary), b"BIN\0") + bytes(binary))


def image_of(document: dict, slot: str) -> int:
    """Which image all the materials use for their colour, their normals or
    their roughness; it stops when they have none or do not agree."""
    found = set()
    for material in document.get("materials", []):
        texture = material.get(slot) or material.get("pbrMetallicRoughness", {}).get(slot)
        found.add(document["textures"][texture["index"]]["source"] if texture else -1)
    if len(found) != 1 or -1 in found:
        sys.exit("import_character: --route=repaint needs a character whose materials share one set of textures, as the route makes them")
    return found.pop()


def run(args) -> dict:
    if not args.look:
        sys.exit("import_character: --route=repaint paints a look on; pass --look=")
    if args.height or args.scale != 1.0 or args.wide != 1.0 or args.yaw is not None or args.drop or args.bones:
        sys.exit("import_character: --route=repaint changes the paint and nothing else; leave out the options that would change the model")
    document, views = unpack(args.source)
    images = {kind: image_of(document, slot) for kind, slot in (("color", "baseColorTexture"), ("normal", "normalTexture"), ("orm", "metallicRoughnessTexture"))}

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=args.source, merge_vertices=True)
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    bodies = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and any(modifier.type == "ARMATURE" for modifier in obj.modifiers)]
    if len(armatures) != 1 or len(bodies) != 1 or not bodies[0].material_slots:
        sys.exit("import_character: --route=repaint is for a character that has been through the route: one mesh on one skeleton")
    body, armature = bodies[0], armatures[0]

    # The textures as they are, in the layout as it is.
    source = atlas.Source(body.material_slots[0].material)
    if None in (source.color, source.normal, source.roughness, source.metallic) or source.color[0].size[0] != source.color[0].size[1]:
        sys.exit("import_character: --route=repaint needs the three square textures the route gives a character")
    textures = atlas.Atlas(source.color[0].size[0])
    textures.cutout = source.alpha is not None
    textures.color[:] = atlas.pixels(source.color[0])
    textures.normal[:] = atlas.pixels(source.normal[0])[:, :, :3]
    packed = atlas.pixels(source.roughness[0])
    textures.rough[:] = packed[:, :, "RGB".index(source.roughness[1])]
    textures.metal[:] = packed[:, :, "RGB".index(source.metallic[1])]
    textures.locate(body.data)
    before = {"normal": textures.normal.copy(), "rough": textures.rough.copy(), "metal": textures.metal.copy()}
    vertices = len(body.data.vertices)

    note = looks.apply(args.look, body, armature, textures, args.seed)
    if len(body.data.vertices) != vertices:
        sys.exit("import_character: the look %s adds to the mesh, which --route=repaint leaves as it is" % args.look)

    def differs(kind: str) -> bool:
        return float(np.abs(getattr(textures, kind) - before[kind]).max()) > 0.002

    # Around the islands: the few texels a lookup next to an edge reaches, as
    # the route does it, and for the colour all the rest as well, so that
    # from far off nothing of the old colours is mixed in.
    covered = textures.covered()
    reached = atlas.dilate(covered.astype(np.float32)[:, :, None], covered, 8)[:, :, 0] > 0
    folder = os.path.abspath(args.keep) if args.keep else tempfile.mkdtemp(prefix="character_")
    os.makedirs(folder, exist_ok=True)
    name = args.id or "character"
    painted = {}
    colour = atlas.flood(atlas.dilate(textures.color, covered, 8), reached)
    if not textures.cutout:
        colour[:, :, 3] = 1.0
    painted["color"] = atlas._save(name + "_color", colour, folder, "PNG" if textures.cutout else "JPEG", True)
    if differs("normal"):
        normal = np.ones((textures.side, textures.side, 4), dtype=np.float32)
        normal[:, :, :3] = atlas.dilate(textures.normal, covered, 8)
        painted["normal"] = atlas._save(name + "_normal", normal, folder, "PNG", False)
    if differs("rough") or differs("metal"):
        packed = packed.copy()
        packed[:, :, 1:3] = atlas.dilate(np.stack([textures.rough, textures.metal], axis=-1), covered, 8)
        packed[:, :, 3] = 1.0
        painted["orm"] = atlas._save(name + "_orm", packed, folder, "JPEG", False)
    for kind, image in painted.items():
        views[document["images"][images[kind]]["bufferView"]] = pathlib.Path(image.filepath_raw).read_bytes()
        document["images"][images[kind]]["mimeType"] = "image/png" if image.file_format == "PNG" else "image/jpeg"

    # Inside the file everything is called after the character.
    old = pathlib.Path(args.source).stem
    for kind in ("nodes", "meshes", "materials", "images"):
        for item in document.get(kind, []):
            if item.get("name", "") == old or item.get("name", "").startswith(old + "_"):
                item["name"] = name + item["name"][len(old):]
    pack(args.target, document, views)

    triangles = sum(document["accessors"][primitive["indices"]]["count"] // 3 for mesh in document["meshes"] for primitive in mesh["primitives"])
    told = {kind: "the source's, painted over" if kind in painted else "the source's" for kind in ("color", "normal", "orm")}
    return {
        "route": "repaint",
        "look": note,
        "source_triangles": triangles,
        "triangles": triangles,
        "vertices": sum(document["accessors"][primitive["attributes"]["POSITION"]]["count"] for mesh in document["meshes"] for primitive in mesh["primitives"]),
        "bones": len(document["skins"][0]["joints"]),
        "textures": {"color": told["color"], "normal": told["normal"], "roughness": told["orm"], "size": textures.side, "cutout": textures.cutout},
        "bytes": os.path.getsize(args.target),
        "blender": bpy.app.version_string,
    }
