"""Makes a practice scan out of a rigged model, to test the scan route against.

    blender -b --python tools/characters/mock_scan.py -- <rigged model> <folder>

There is no real scan of a friend to try the scan route on, and with a real
one there would be nothing to compare the result to. So this takes a person
whose skeleton and colours are known and does to it what a phone does to a
person: it throws the skeleton away, photographs the light of a room into the
texture, rebuilds the surface as a few hundred thousand lumpy triangles under
a UV layout of scraps, leaves holes where a camera cannot look (under the
soles, the chin, the arms, between the legs), adds the floor it stood on and
some stray bits, and saves it turned and shifted as scan.usdz, scan.obj and
scan.glb. scan_unlit.glb is the same statue with the colours as they really
are, to measure how much of the light the scan route takes out again.
"""

import argparse
import math
import os
import pathlib
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(pathlib.Path(__file__).parent))

import bmesh  # noqa: E402
import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import humanoid  # noqa: E402
import prepare  # noqa: E402

SIDE = 2048


def bake(body: bpy.types.Object, name: str, folder: str, lit: bool) -> bpy.types.Image:
    image = bpy.data.images.new(name, SIDE, SIDE, alpha=False)
    for slot in body.material_slots:
        nodes = slot.material.node_tree.nodes
        target = nodes.get("target") or nodes.new("ShaderNodeTexImage")
        target.name = "target"
        target.image = image
        for node in nodes:
            node.select = node == target
        nodes.active = target
    with bpy.context.temp_override(active_object=body, object=body, selected_objects=[body]):
        bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR", "DIRECT", "INDIRECT"} if lit else {"COLOR"}, margin=6, use_clear=True)
    image.filepath_raw = os.path.join(folder, name + ".png")
    image.file_format = "PNG"
    image.save()
    return image


def main() -> None:
    source, folder = sys.argv[sys.argv.index("--") + 1:][:2]
    os.makedirs(folder, exist_ok=True)
    args = argparse.Namespace(source=source, drop="", keep_weapons=False, route="auto", id="scan", height=0.0, scale=1.0, yaw=None)
    prepare.load(source)
    body, armature, _ = prepare.gather(args)
    mapping = humanoid.guess(armature, {group.name for group in body.vertex_groups})
    bones = armature.data.bones
    across = bones[mapping["LeftUpperLeg"]].head_local - bones[mapping["RightUpperLeg"]].head_local
    prepare.settle(body, armature, args, across.cross(Vector((0.0, 0.0, 1.0))).normalized(), mapping["Hips"])
    bpy.data.objects.remove(armature, do_unlink=True)
    body.vertex_groups.clear()

    # Hair drawn on see-through cards is nothing a scan would come back with.
    import atlas
    cards = [atlas.Source(slot.material).alpha is not None for slot in body.material_slots]
    mesh = bmesh.new()
    mesh.from_mesh(body.data)
    bmesh.ops.delete(mesh, geom=[face for face in mesh.faces if cards[face.material_index]], context="FACES")
    bmesh.ops.triangulate(mesh, faces=mesh.faces)
    mesh.to_mesh(body.data)
    mesh.free()

    # The scraps of UV layout a photogrammetry program makes.
    for slot in body.material_slots:
        nodes, links = slot.material.node_tree.nodes, slot.material.node_tree.links
        old = nodes.new("ShaderNodeUVMap")
        old.uv_map = "UVMap"
        # The FBX importer makes these people of metal; a camera sees cloth and skin.
        next(node for node in nodes if node.type == "BSDF_PRINCIPLED").inputs["Metallic"].default_value = 0.0
        for node in nodes:
            if node.type == "TEX_IMAGE":
                links.new(old.outputs[0], node.inputs[0])
    layer = body.data.uv_layers.new(name="scan")
    body.data.uv_layers.active = layer
    layer.active_render = True
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(50.0), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")

    # The room: light from everywhere, a window to one side and above.
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = False
    world = bpy.data.worlds.new("room")
    if world.node_tree is None:
        world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.85, 0.9, 1.0, 1.0)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.7
    scene.world = world
    window = bpy.data.objects.new("window", bpy.data.lights.new("window", "SUN"))
    window.data.energy = 2.2
    window.data.angle = math.radians(35.0)
    window.data.color = (1.0, 0.93, 0.82)
    window.rotation_euler = (math.radians(52.0), 0.0, math.radians(-40.0))
    scene.collection.objects.link(window)
    ground = bpy.data.meshes.new("ground")
    ground.from_pydata([(-6, -6, 0), (6, -6, 0), (6, 6, 0), (-6, 6, 0)], [], [(0, 1, 2, 3)])
    under = bpy.data.objects.new("ground", ground)
    scene.collection.objects.link(under)

    seen = bake(body, "scan_lit", folder, True)
    real = bake(body, "scan_unlit", folder, False)
    bpy.data.objects.remove(under, do_unlink=True)
    bpy.data.objects.remove(window, do_unlink=True)

    body.data.uv_layers.remove(body.data.uv_layers["UVMap"])
    body.data.uv_layers[0].name = "UVMap"
    body.data.materials.clear()
    material = bpy.data.materials.new("scan")
    texture = material.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = seen
    shader = next(node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    material.node_tree.links.new(texture.outputs[0], shader.inputs["Base Color"])
    body.data.materials.append(material)
    body.data.polygons.foreach_set("material_index", [0] * len(body.data.polygons))

    # A few hundred thousand lumpy triangles.
    prepare.modify(body, "SUBSURF", levels=3, subdivision_type="CATMULL_CLARK")
    noise = bpy.data.textures.new("lumps", "CLOUDS")
    noise.noise_scale = 0.012
    prepare.modify(body, "DISPLACE", texture=noise, strength=0.003, mid_level=0.5)
    prepare.modify(body, "TRIANGULATE")

    # Where a camera cannot look there is no surface: whatever faces down, and
    # a few patches that just did not come out.
    random = np.random.default_rng(11)
    mesh = bmesh.new()
    mesh.from_mesh(body.data)
    mesh.faces.ensure_lookup_table()
    gone = {face for face in mesh.faces if face.normal.z < -0.8}
    trunk = [face for face in mesh.faces if 0.95 < face.calc_center_median().z < 1.45]
    for index in random.choice(len(trunk), 4, replace=False):
        centre = trunk[index].calc_center_median()
        gone |= {face for face in mesh.faces if (face.calc_center_median() - centre).length < 0.028}
    holes = len(gone)
    bmesh.ops.delete(mesh, geom=list(gone), context="FACES")
    # The floor it stood on, in the same mesh, and bits that float beside it.
    material_floor = bpy.data.materials.new("floor")
    next(node for node in material_floor.node_tree.nodes if node.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.42, 0.4, 0.37, 1.0)
    body.data.materials.append(material_floor)
    before = set(mesh.faces)
    bmesh.ops.create_circle(mesh, cap_ends=True, cap_tris=True, segments=96, radius=0.75, matrix=Matrix.Translation((0.05, -0.08, 0.004)))
    for _ in range(5):
        spot = Vector((random.uniform(-0.6, 0.6), random.uniform(-0.6, 0.6), random.uniform(0.05, 1.6)))
        if abs(spot.x) < 0.3:
            spot.x += 0.5
        bmesh.ops.create_icosphere(mesh, subdivisions=2, radius=random.uniform(0.015, 0.04), matrix=Matrix.Translation(spot))
    for face in set(mesh.faces) - before:
        face.material_index = 1
    bmesh.ops.triangulate(mesh, faces=mesh.faces)
    mesh.to_mesh(body.data)
    mesh.free()

    # A scan knows nothing of where the origin is or which way is forward.
    body.data.transform(Matrix.Translation((0.37, -0.21, 0.02)) @ Matrix.Rotation(math.radians(137.0), 4, "Z"))
    body.data.update()
    for obj in bpy.context.scene.objects:
        obj.select_set(obj == body)
    count = prepare.triangles(body.data)
    bpy.ops.export_scene.gltf(filepath=os.path.join(folder, "scan.glb"), export_format="GLB", use_selection=True, export_yup=True)
    bpy.ops.wm.obj_export(filepath=os.path.join(folder, "scan.obj"), export_selected_objects=True, path_mode="COPY")
    bpy.ops.wm.usd_export(filepath=os.path.join(folder, "scan.usdz"), selected_objects_only=True, export_materials=True)
    texture.image = real
    bpy.ops.export_scene.gltf(filepath=os.path.join(folder, "scan_unlit.glb"), export_format="GLB", use_selection=True, export_yup=True)
    print("mock_scan: %d triangles, %d faces left out as holes, in %s" % (count, holes, folder))


if __name__ == "__main__":
    main()
