"""The scan route of tools/import_character.sh: from a statue to a character.

A scan from a phone is a few hundred thousand triangles with holes where the
camera could not look, a scrap of floor, no skeleton, and a texture with the
light of the room baked into it. This turns that into the same thing the
rigged route delivers:

1. tidy: stand it upright in metres, cut the floor away and drop loose bits;
2. shell: close the holes and rebuild the surface watertight;
3. landmarks.py finds the joints, and a skeleton of the humanoid profile is
   built on them;
4. the shell is thinned to the triangle budget and unwrapped, and colour and
   normals are carried over from the scan itself, so the detail survives as a
   normal map;
5. delight.py takes the room's light out of the colour;
6. Blender's automatic weights hang the skin on the skeleton.
"""

import math
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

import humanoid
import landmarks

UP = Vector((0.0, 0.0, 1.0))


def coordinates(mesh: bpy.types.Mesh) -> np.ndarray:
    co = np.empty(len(mesh.vertices) * 3, dtype=np.float32)
    mesh.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def apply(obj: bpy.types.Object, kind: str, **settings) -> None:
    modifier = obj.modifiers.new(kind, kind)
    for key, value in settings.items():
        setattr(modifier, key, value)
    with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj]):
        bpy.ops.object.modifier_apply(modifier=modifier.name)


def upright(obj: bpy.types.Object, height: float) -> float:
    """Stands the scan up along z, in metres. Returns the scale it applied."""
    co = coordinates(obj.data)
    extent = co.max(axis=0) - co.min(axis=0)
    tall = int(np.argmax(extent))
    if tall != 2:
        # The file's up axis was not the person's: lay the longest axis along z.
        turn = Matrix.Rotation(math.radians(90.0), 4, "X" if tall == 1 else "Y")
        obj.data.transform(turn)
        co = coordinates(obj.data)
    # Head up: of the two ends, the one where the figure is two islands is the feet.
    low, high = co[:, 2].min(), co[:, 2].max()
    span = high - low
    cell = landmarks.CELL * span
    feet_down = len(landmarks.islands(co[co[:, 2] < low + 0.12 * span][:, :2], cell)) >= len(landmarks.islands(co[co[:, 2] > high - 0.12 * span][:, :2], cell))
    if not feet_down:
        obj.data.transform(Matrix.Rotation(math.radians(180.0), 4, "X"))
        co = coordinates(obj.data)
        low = co[:, 2].min()
    if height > 0.0:
        scale = float(height / span)
    else:
        scale = next((unit for unit in (1.0, 0.01, 0.001, 0.0254, 100.0) if 0.9 <= span * unit <= 2.6), 0.0)
        if scale == 0.0:
            sys.exit("import_character: the scan is %.3g units tall, which is no person in any unit; pass --height=1.8" % span)
    middle = (co[:, :2].min(axis=0) + co[:, :2].max(axis=0)) / 2
    obj.data.transform(Matrix.Scale(scale, 4) @ Matrix.Translation((-float(middle[0]), -float(middle[1]), -float(low))))
    return scale


def tidy(obj: bpy.types.Object) -> dict:
    """Cuts away the floor the person stood on and whatever floats loose."""
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    bmesh.ops.remove_doubles(mesh, verts=mesh.verts, dist=1e-5)
    faces = len(mesh.faces)
    # The floor is the lowest level with a lot of surface looking up: more than
    # two shoe soles' worth.
    flat = [face for face in mesh.faces if face.normal.z > 0.9]
    floor = None
    if flat:
        z = np.array([face.calc_center_median().z for face in flat])
        area = np.array([face.calc_area() for face in flat])
        edges = np.arange(z.min(), min(z.min() + 0.25, z.max()) + 0.01, 0.01)
        if len(edges) > 1:
            surface, _ = np.histogram(z, bins=edges, weights=area)
            if surface.max() > 0.08:
                floor = float(edges[int(np.argmax(surface))] + 0.013)
    cut = 0
    if floor is not None:
        gone = [face for face in mesh.faces if face.calc_center_median().z < floor]
        cut = len(gone)
        bmesh.ops.delete(mesh, geom=gone, context="FACES")
    # Keep the biggest piece and whatever is a real part of the person next to it.
    mesh.faces.ensure_lookup_table()
    seen = set()
    pieces = []
    for face in mesh.faces:
        if face.index in seen:
            continue
        piece = [face]
        seen.add(face.index)
        stack = [face]
        while stack:
            for edge in stack.pop().edges:
                for other in edge.link_faces:
                    if other.index not in seen:
                        seen.add(other.index)
                        piece.append(other)
                        stack.append(other)
        pieces.append(piece)
    sizes = [sum(face.calc_area() for face in piece) for piece in pieces]
    biggest = max(sizes)
    loose = [face for piece, size in zip(pieces, sizes) if size < 0.02 * biggest for face in piece]
    bmesh.ops.delete(mesh, geom=loose, context="FACES")
    bmesh.ops.delete(mesh, geom=[vertex for vertex in mesh.verts if not vertex.link_faces], context="VERTS")
    bmesh.ops.triangulate(mesh, faces=mesh.faces)
    mesh.to_mesh(obj.data)
    mesh.free()
    obj.data.update()
    low = float(coordinates(obj.data)[:, 2].min())
    obj.data.transform(Matrix.Translation((0.0, 0.0, -low)))
    return {"floor_faces": cut, "loose_faces": len(loose), "pieces": len(pieces), "faces": faces}


def solid(obj: bpy.types.Object, height: float) -> tuple:
    """Fills the figure in on a grid and returns a blocky mesh of the body,
    and how it was told what is inside.

    A scan is one skin with holes in it where the camera could not look. A
    generated model is clothes: a skin that stands open at the cuffs and the
    trouser legs, with hands, shoes and loose layers inside. A mesh repair
    patches the first and returns the second as the thin shell it is. On a
    grid neither matters: what is inside is decided cell by cell."""
    size = height / 320.0
    co = coordinates(obj.data).astype(np.float64)
    corners = np.empty(len(obj.data.loops), dtype=np.int32)
    obj.data.loops.foreach_get("vertex_index", corners)
    a, b, c = co[corners[0::3]], co[corners[1::3]], co[corners[2::3]]
    # Enough points on every triangle that no cell the surface crosses is missed.
    area = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
    random = np.random.default_rng(5)
    which = np.repeat(np.arange(len(a)), np.ceil(area / (0.2 * size * size)).astype(np.int64))
    u, v = random.random(len(which)), random.random(len(which))
    over = u + v > 1.0
    u[over], v[over] = 1.0 - u[over], 1.0 - v[over]
    points = np.concatenate([co, a[which] + (b - a)[which] * u[:, None] + (c - a)[which] * v[:, None]])
    low = points.min(axis=0) - 6.0 * size
    cells = np.floor((points - low) / size).astype(np.int64)
    shape = tuple(int(extent) for extent in cells.max(axis=0) + 7)
    wall = np.zeros(shape, dtype=bool)
    wall[cells[:, 0], cells[:, 1], cells[:, 2]] = True
    thin = int(wall.sum())

    def grow(grid: np.ndarray) -> np.ndarray:
        out = grid.copy()
        out[1:] |= grid[:-1]
        out[:-1] |= grid[1:]
        out[:, 1:] |= grid[:, :-1]
        out[:, :-1] |= grid[:, 1:]
        out[:, :, 1:] |= grid[:, :, :-1]
        out[:, :, :-1] |= grid[:, :, 1:]
        return out

    # First the exact way: whatever cannot be reached from outside is body.
    # The wall is made one cell thicker for it, so that nothing slips through
    # between two cells that only touch at a corner, and the body one cell
    # thinner afterwards.
    free = ~grow(wall)
    outside = np.zeros(shape, dtype=bool)
    outside[0], outside[-1], outside[:, 0], outside[:, -1], outside[:, :, 0], outside[:, :, -1] = True, True, True, True, True, True
    outside &= free
    while True:
        before = int(outside.sum())
        for axis in range(3):
            moved, open_ = np.moveaxis(outside, axis, 0), np.moveaxis(free, axis, 0)
            for index in range(1, shape[axis]):
                moved[index] |= moved[index - 1] & open_[index]
            for index in range(shape[axis] - 2, -1, -1):
                moved[index] |= moved[index + 1] & open_[index]
        if int(outside.sum()) == before:
            break
    body = ~grow(outside)
    how = "what cannot be reached from outside"
    if int(body.sum()) < 1.6 * thin:
        # The outside leaks in, through a hole or up a trouser leg. Then a cell
        # is inside when it is shut in: when nearly every way it looks, along
        # the axes and the diagonals between them, there is surface. From
        # inside a sleeve the only way out is down the sleeve; from between an
        # arm and the body it is forward, back, and every slant between.
        shut = np.zeros(shape, dtype=np.uint8)
        ways = 0
        for axis in range(3):
            for flip in (False, True):
                view = np.flip(wall, axis) if flip else wall
                seen = np.logical_or.accumulate(view, axis=axis)
                shut += np.flip(seen, axis) if flip else seen
                ways += 1
        reach = int(0.6 / size)
        for first in range(3):
            for second in range(first + 1, 3):
                for step_first in (1, -1):
                    for step_second in (1, -1):
                        step = [0, 0, 0]
                        step[first], step[second] = step_first, step_second
                        carried = wall
                        seen = np.zeros(shape, dtype=bool)
                        for _ in range(reach):
                            moved = np.zeros(shape, dtype=bool)
                            source = tuple(slice(max(-move, 0), shape[axis] - max(move, 0)) for axis, move in enumerate(step))
                            target = tuple(slice(max(move, 0), shape[axis] - max(-move, 0)) for axis, move in enumerate(step))
                            moved[target] = carried[source]
                            carried = moved
                            seen |= carried
                        shut += seen
                        ways += 1
        body = wall | (shut >= ways - 3)
        how = "what is shut in on nearly all sides"

    # The faces between a cell of body and a cell of air.
    quads = []
    for axis in range(3):
        others = [other for other in range(3) if other != axis]
        for sign in (1, -1):
            beyond = np.roll(body, -sign, axis=axis)
            at = np.argwhere(body & ~beyond).astype(np.float64)
            at[:, axis] += 1.0 if sign > 0 else 0.0
            ring = [(0, 0), (1, 0), (1, 1), (0, 1)] if sign > 0 else [(0, 0), (0, 1), (1, 1), (1, 0)]
            if axis == 1:
                ring = [(second, first) for first, second in ring]
            corner = np.repeat(at[:, None, :], 4, axis=1)
            for index, (first, second) in enumerate(ring):
                corner[:, index, others[0]] += first
                corner[:, index, others[1]] += second
            quads.append(corner)
    quads = np.concatenate(quads).reshape(-1, 3) * size + low
    mesh = bpy.data.meshes.new("solid")
    count = len(quads) // 4
    mesh.vertices.add(len(quads))
    mesh.vertices.foreach_set("co", quads.astype(np.float32).ravel())
    mesh.loops.add(len(quads))
    mesh.loops.foreach_set("vertex_index", np.arange(len(quads), dtype=np.int32))
    mesh.polygons.add(count)
    mesh.polygons.foreach_set("loop_start", np.arange(count, dtype=np.int32) * 4)
    mesh.polygons.foreach_set("loop_total", np.full(count, 4, dtype=np.int32))
    mesh.update()
    welded = bmesh.new()
    welded.from_mesh(mesh)
    bmesh.ops.remove_doubles(welded, verts=welded.verts, dist=size * 0.01)
    welded.to_mesh(mesh)
    welded.free()
    return mesh, how


def shell(obj: bpy.types.Object, name: str) -> bpy.types.Object:
    """A watertight copy of the scan: holes closed, one surface, no insides."""
    copy = obj.copy()
    copy.data = obj.data.copy()
    copy.name = copy.data.name = name
    bpy.context.scene.collection.objects.link(copy)
    mesh = bmesh.new()
    mesh.from_mesh(copy.data)
    copy["open_edges"] = sum(1 for edge in mesh.edges if edge.is_boundary)
    mesh.free()
    for layer in list(copy.data.uv_layers):
        copy.data.uv_layers.remove(layer)
    copy.data.materials.clear()
    height = float(coordinates(copy.data)[:, 2].max())
    copy.data, copy["closed_by"] = solid(copy, height)
    # A rebuild through a volume takes the steps off the blocks and leaves an
    # even surface; smoothing takes off what is left of them. The detail that
    # goes with them comes back as a normal map of the scan itself.
    apply(copy, "REMESH", mode="VOXEL", voxel_size=height / 320.0, adaptivity=0.0, use_smooth_shade=True)
    apply(copy, "SMOOTH", factor=0.5, iterations=8)
    # A pocket of air that was shut in becomes a loose bubble: keep the body.
    whole = bmesh.new()
    whole.from_mesh(copy.data)
    whole.verts.ensure_lookup_table()
    seen = set()
    pieces = []
    for vertex in whole.verts:
        if vertex.index in seen:
            continue
        piece = [vertex]
        seen.add(vertex.index)
        stack = [vertex]
        while stack:
            for edge in stack.pop().link_edges:
                for near in edge.verts:
                    if near.index not in seen:
                        seen.add(near.index)
                        piece.append(near)
                        stack.append(near)
        pieces.append(piece)
    biggest = max(pieces, key=len)
    bmesh.ops.delete(whole, geom=[vertex for piece in pieces if piece is not biggest for vertex in piece], context="VERTS")
    whole.to_mesh(copy.data)
    whole.free()
    return copy


def occlusion(obj: bpy.types.Object, rays: int = 48, reach: float = 0.45) -> np.ndarray:
    """How open each vertex is to its surroundings: 1 in the open, less in a fold."""
    from mathutils.bvhtree import BVHTree
    tree = BVHTree.FromObject(obj, bpy.context.evaluated_depsgraph_get())
    co = coordinates(obj.data)
    normal = np.empty(len(obj.data.vertices) * 3, dtype=np.float32)
    obj.data.vertex_normals.foreach_get("vector", normal)
    normal = normal.reshape(-1, 3)
    random = np.random.default_rng(3)
    # The same bundle of directions for every vertex, turned to its normal.
    u, v = random.random(rays), random.random(rays)
    radius, angle = np.sqrt(u), 2 * np.pi * v
    bundle = np.stack([radius * np.cos(angle), radius * np.sin(angle), np.sqrt(1 - u)], axis=1)
    helper = np.where(np.abs(normal[:, 2:3]) < 0.9, np.array([[0.0, 0.0, 1.0]]), np.array([[1.0, 0.0, 0.0]]))
    tangent = np.cross(helper, normal)
    tangent /= np.linalg.norm(tangent, axis=1, keepdims=True)
    other = np.cross(normal, tangent)
    start = (co + normal * 0.004).tolist()
    cast = tree.ray_cast
    result = np.ones(len(co), dtype=np.float32)
    for index in range(len(co)):
        directions = (bundle[:, 0:1] * tangent[index] + bundle[:, 1:2] * other[index] + bundle[:, 2:3] * normal[index]).tolist()
        origin = start[index]
        hits = 0
        for direction in directions:
            if cast(origin, direction, reach)[0] is not None:
                hits += 1
        result[index] = 1.0 - hits / rays
    return result


def unwrap(obj: bpy.types.Object, neck: float) -> None:
    """Gives the thinned shell a UV layout of its own, the head sharper than the rest."""
    mesh = obj.data
    for layer in list(mesh.uv_layers):
        mesh.uv_layers.remove(layer)
    mesh.uv_layers.new(name="UVMap")
    # Edit mode takes every selected mesh along, and the scan must keep its own layout.
    for other in bpy.context.scene.objects:
        other.select_set(other == obj)
    bpy.context.view_layer.objects.active = obj
    centre = np.array([polygon.center.z for polygon in mesh.polygons])
    head = centre > neck
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_mode(type="FACE")
    for part in (head, ~head):
        bpy.ops.mesh.select_all(action="DESELECT")
        bpy.ops.object.mode_set(mode="OBJECT")
        mesh.polygons.foreach_set("select", part.tolist())
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.0, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")

    # Each part now fills the square on its own: bring them to one scale, the
    # head that much bigger, and set them side by side for the packer.
    layer = mesh.uv_layers.active.data
    uv = np.empty(len(layer) * 2, dtype=np.float64)
    layer.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    area = np.array([polygon.area for polygon in mesh.polygons])
    corners = np.array([polygon.loop_start for polygon in mesh.polygons])[:, None] + np.arange(3)[None, :]
    own = uv[corners]
    flat = 0.5 * np.abs((own[:, 1, 0] - own[:, 0, 0]) * (own[:, 2, 1] - own[:, 0, 1]) - (own[:, 2, 0] - own[:, 0, 0]) * (own[:, 1, 1] - own[:, 0, 1]))
    import atlas
    for index, (part, boost) in enumerate(((head, atlas.HEAD_BOOST), (~head, 1.0))):
        if not part.any() or flat[part].sum() <= 0.0:
            continue
        scale = boost * math.sqrt(area[part].sum() / flat[part].sum())
        uv[corners[part]] = uv[corners[part]] * scale + np.array([index * 50.0, 0.0])
    layer.foreach_set("uv", uv.astype(np.float32).ravel())
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, margin_method="FRACTION", margin=0.004, shape_method="CONCAVE")
    bpy.ops.object.mode_set(mode="OBJECT")


def transfer(source: bpy.types.Object, low: bpy.types.Object, height: float) -> tuple:
    """Carries colour and surface detail from the scan to the thinned shell:
    for every texel of the new layout, look along the surface normal for the
    scan and take its colour and its normal there."""
    import atlas
    from mathutils.bvhtree import BVHTree
    from mathutils.kdtree import KDTree
    result = atlas.Atlas()
    result.locate(low.data)
    rows, columns = np.nonzero(result.covered())
    position = result.positions(low.data)[rows, columns]
    normal = result.normals(low.data)[rows, columns]
    count = len(rows)

    tree = BVHTree.FromObject(source, bpy.context.evaluated_depsgraph_get())
    reach = 0.022 * height
    inward = (-normal).tolist()
    outside = (position + normal * reach).tolist()
    here = position.tolist()
    face = np.full(count, -1, dtype=np.int64)
    at = np.zeros((count, 3), dtype=np.float64)
    cast, nearest = tree.ray_cast, tree.find_nearest
    for index in range(count):
        direction = inward[index]
        hit, facing, found, _ = cast(outside[index], direction, 2.0 * reach)
        if hit is None or facing[0] * direction[0] + facing[1] * direction[1] + facing[2] * direction[2] > 0.0:
            # Nothing there, or the inside of the far wall: take what is nearest.
            hit, facing, found, _ = nearest(here[index], reach)
            if hit is None:
                continue
        face[index] = found
        at[index] = hit
    hit = face >= 0

    mesh = source.data
    start = np.empty(len(mesh.polygons), dtype=np.int64)
    mesh.polygons.foreach_get("loop_start", start)
    slot = np.empty(len(mesh.polygons), dtype=np.int64)
    mesh.polygons.foreach_get("material_index", slot)
    vertex = np.empty(len(mesh.loops), dtype=np.int64)
    mesh.loops.foreach_get("vertex_index", vertex)
    co = coordinates(mesh).astype(np.float64)
    smooth = np.empty(len(mesh.vertices) * 3, dtype=np.float32)
    mesh.vertex_normals.foreach_get("vector", smooth)
    smooth = smooth.reshape(-1, 3)
    loops = start[face[hit]][:, None] + np.arange(3)[None, :]
    corner = vertex[loops]
    a, b, c = co[corner[:, 0]], co[corner[:, 1]], co[corner[:, 2]]
    v0, v1, v2 = b - a, c - a, at[hit] - a
    d00, d01, d11 = (v0 * v0).sum(1), (v0 * v1).sum(1), (v1 * v1).sum(1)
    d20, d21 = (v2 * v0).sum(1), (v2 * v1).sum(1)
    scale = np.maximum(d00 * d11 - d01 * d01, 1e-18)
    w1 = np.clip((d11 * d20 - d01 * d21) / scale, 0.0, 1.0)
    w2 = np.clip((d00 * d21 - d01 * d20) / scale, 0.0, 1.0)
    weights = np.stack([1.0 - w1 - w2, w1, w2], axis=1)

    colour = np.full((count, 3), 0.5, dtype=np.float32)
    # A scan knows nothing of how rough its surface is; a generated model does.
    rough = np.full(count, 0.78, dtype=np.float32)
    metal = np.zeros(count, dtype=np.float32)
    measured = False
    origin = "the scan's texture"
    if mesh.uv_layers.active is not None and any(slot_.material for slot_ in source.material_slots):
        layer = mesh.uv_layers.active.data
        uv = np.empty(len(layer) * 2, dtype=np.float64)
        layer.foreach_get("uv", uv)
        uv = uv.reshape(-1, 2)
        where = (uv[loops] * weights[:, :, None]).sum(axis=1)
        which = slot[face[hit]]
        taken = np.full((int(hit.sum()), 3), 0.5, dtype=np.float32)
        for index, own in enumerate(source.material_slots):
            use = which == index
            if not use.any():
                continue
            material = atlas.Source(own.material)
            if material.color is None:
                taken[use] = material.base[:3]
                continue
            image = material.color[0]
            # More than 4K of float pixels does not fit comfortably in memory, and 1K comes out.
            if max(image.size) > 4096:
                image.scale(min(image.size[0], 4096), min(image.size[1], 4096))
            taken[use] = atlas.sample(atlas.pixels(image)[:, :, :3], where[use])
            spots = np.nonzero(hit)[0][use]
            for found, target in ((material.roughness, rough), (material.metallic, metal)):
                if found is not None and found[1] in ("R", "G", "B"):
                    target[spots] = atlas.sample(atlas.pixels(found[0])[:, :, "RGB".index(found[1])][:, :, None], where[use])[:, 0]
                    measured = True
        colour[hit] = taken
    elif mesh.color_attributes:
        # A scan that carries its colour on its vertices.
        attribute = mesh.color_attributes.active_color or mesh.color_attributes[0]
        values = np.empty(len(attribute.data) * 4, dtype=np.float32)
        attribute.data.foreach_get("color_srgb", values)
        values = values.reshape(-1, 4)[:, :3]
        per = values[corner] if attribute.domain == "POINT" else values[loops]
        colour[hit] = (per * weights[:, :, None]).sum(axis=1)
        origin = "the scan's vertex colours"
    else:
        origin = "none: the scan has no colour"

    # Where the scan had a hole the new surface has nothing to copy: take the
    # colour of what is nearest on the surface around it.
    missed = np.nonzero(~hit)[0]
    if len(missed) and hit.any():
        known = np.nonzero(hit)[0]
        known = known[::max(len(known) // 150000, 1)]
        lookup = KDTree(len(known))
        for order, index in enumerate(known):
            lookup.insert(here[index], order)
        lookup.balance()
        for index in missed:
            near = [known[order] for _, order, _ in lookup.find_n(here[index], 6)]
            colour[index] = colour[near].mean(axis=0)
            rough[index] = rough[near].mean()
            metal[index] = metal[near].mean()

    # The detail of the scan as a normal map: its normal, seen from the
    # tangent frame Godot will build on the thinned mesh.
    low.data.calc_tangents()
    values = np.empty(len(low.data.loops) * 3, dtype=np.float32)
    low.data.loops.foreach_get("tangent", values)
    tangent = result.corner_attribute(values.reshape(-1, 3))[rows, columns]
    low.data.loops.foreach_get("normal", values)
    upright_ = result.corner_attribute(values.reshape(-1, 3))[rows, columns]
    sign = np.empty(len(low.data.loops), dtype=np.float32)
    low.data.loops.foreach_get("bitangent_sign", sign)
    sign = sign[result.triangles[result.face[rows, columns]][:, 0]]
    tangent /= np.maximum(np.linalg.norm(tangent, axis=1, keepdims=True), 1e-6)
    upright_ /= np.maximum(np.linalg.norm(upright_, axis=1, keepdims=True), 1e-6)
    other = np.cross(upright_, tangent) * sign[:, None]
    detail = normal.copy()
    detail[hit] = (smooth[corner] * weights[:, :, None]).sum(axis=1)
    detail /= np.maximum(np.linalg.norm(detail, axis=1, keepdims=True), 1e-6)
    # Where the new surface bridges a hole, what was found nearest is the rim
    # of the hole and faces another way: no detail there.
    astray = (detail * normal).sum(axis=1) < 0.45
    detail[astray] = normal[astray]
    local = np.stack([(detail * tangent).sum(1), (detail * other).sum(1), np.maximum((detail * upright_).sum(1), 0.05)], axis=1)
    local /= np.linalg.norm(local, axis=1, keepdims=True)
    result.normal[rows, columns] = local * 0.5 + 0.5
    result.color[rows, columns, :3] = colour
    result.rough[:] = 0.78
    result.rough[rows, columns] = rough
    result.metal[rows, columns] = metal
    result.notes.update(color=origin, normal="baked from the scan", roughness="the model's own" if measured else "one value: a scan has none",
                        texels_per_cm=round(math.sqrt(count / max(sum(polygon.area for polygon in low.data.polygons), 1e-6)) / 100.0, 2),
                        copied=round(float(hit.mean()), 3))
    return result, {"rows": rows, "columns": columns, "normal": detail, "position": position, "hit": hit}


def skeleton(joints: dict, height: float) -> bpy.types.Object:
    """An armature of the humanoid profile with its joints where landmarks.py found them."""
    data = bpy.data.armatures.new("Armature")
    armature = bpy.data.objects.new("Armature", data)
    bpy.context.scene.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    for name, at in joints.items():
        bone = data.edit_bones.new(name)
        bone.head = at
        bone.tail = Vector(at) + Vector((0.0, 0.0, 0.03))
    added = humanoid.complete(data.edit_bones, Vector((0.0, -1.0, 0.0)), height)
    for name in added:
        # A scan's hand is one lump and its face has no parts: these bones are
        # there for the animations and carry no skin.
        data.edit_bones[name].use_deform = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def skin(low: bpy.types.Object, armature: bpy.types.Object) -> str:
    """Hangs the skin on the skeleton with Blender's automatic weights."""
    for obj in bpy.context.scene.objects:
        obj.select_set(obj in (low, armature))
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    names = [group.name for group in low.vertex_groups]
    bound = sum(1 for vertex in low.data.vertices if any(element.weight > 0.0 for element in vertex.groups))
    method = "automatic weights"
    if bound < 0.99 * len(low.data.vertices):
        # The heat that spreads the weights did not get everywhere: fall back on
        # the nearest bones.
        low.vertex_groups.clear()
        bpy.ops.object.parent_set(type="ARMATURE_ENVELOPE")
        names = [group.name for group in low.vertex_groups]
        method = "envelope weights, because the automatic weights failed on %d of %d vertices" % (len(low.data.vertices) - bound, len(low.data.vertices))
    weights = []
    for vertex in low.data.vertices:
        top = sorted(((names[element.group], element.weight) for element in vertex.groups if element.weight > 0.0), key=lambda item: -item[1])[:4]
        total = sum(weight for _, weight in top)
        weights.append([(name, weight / total) for name, weight in top] if total > 0.0 else [("Hips", 1.0)])
    low.vertex_groups.clear()
    groups = {}
    for index, entries in enumerate(weights):
        for name, weight in entries:
            if name not in groups:
                groups[name] = low.vertex_groups.new(name=name)
            groups[name].add([index], weight, "REPLACE")
    return method


def rig(source: bpy.types.Object, args, report: dict) -> tuple:
    """From the scan as it was loaded to a skinned, textured character."""
    import delight
    import prepare
    report["scaled"] = round(upright(source, args.height), 5)
    report["tidied"] = tidy(source)
    if args.scale != 1.0:
        source.data.transform(Matrix.Scale(args.scale, 4))
    hull = shell(source, "shell")
    report["open_edges"] = hull["open_edges"]
    report["closed_by"] = hull["closed_by"]
    try:
        if args.yaw is not None:
            yaw = math.radians(args.yaw)
        else:
            ahead = landmarks.facing(landmarks.Slices(coordinates(hull.data)))
            yaw = math.atan2(-ahead[0], -ahead[1])
        turn = Matrix.Rotation(yaw, 4, "Z")
        source.data.transform(turn)
        hull.data.transform(turn)
        measures = {}
        joints = landmarks.fit(coordinates(hull.data), measures)
        if args.yaw is None and abs(measures["skew"]) < math.radians(25.0):
            # Feet rarely point exactly ahead. A trunk is broadest straight
            # across: turn the last few degrees by that.
            turn = Matrix.Rotation(-measures["skew"], 4, "Z")
            source.data.transform(turn)
            hull.data.transform(turn)
            joints = landmarks.fit(coordinates(hull.data))
            yaw -= measures["skew"]
    except landmarks.PoseError as error:
        sys.exit("import_character: this does not look like a person standing for a scan: %s" % error)
    # Stand it on the origin by its hips.
    shift = Matrix.Diagonal((args.wide, args.wide, 1.0, 1.0)) @ Matrix.Translation((-joints["Hips"][0], -joints["Hips"][1], 0.0))
    source.data.transform(shift)
    hull.data.transform(shift)
    joints = {name: ((at[0] - joints["Hips"][0]) * args.wide, (at[1] - joints["Hips"][1]) * args.wide, at[2]) for name, at in joints.items()}
    height = float(coordinates(hull.data)[:, 2].max())
    report.update(height=round(height, 3), turned=round(math.degrees(yaw), 1), fitted="joints from the shape (landmarks.py)")

    low = hull
    prepare.thin(low, args.triangles)
    for polygon in low.data.polygons:
        polygon.use_smooth = True
    low.name = low.data.name = args.id or "character"
    unwrap(low, joints["Neck"][2])
    source.data.update()
    textures, texels = transfer(source, low, height)
    if not args.no_delight:
        open_ = textures.attribute(low.data, occlusion(low))[texels["rows"], texels["columns"]]
        colour = textures.color[texels["rows"], texels["columns"], :3]
        colour, note = delight.remove(colour, texels["normal"], open_)
        textures.color[texels["rows"], texels["columns"], :3] = colour
        textures.notes["delight"] = note
    armature = skeleton(joints, height)
    report["skinned"] = skin(low, armature)
    bpy.data.objects.remove(source, do_unlink=True)
    return low, armature, textures
