"""The workshop for prizes made on this machine: what a script in this folder,
or one written for a single prize, builds a prize with in Blender.

    tools/make_prize.sh tools/prizes/rubber_duck.py [<folder>]

runs the script without a window and then checks the prize in the game
(tools/prize_check.sh). The script itself runs as

    blender -b --factory-startup --python <script> -- [<folder>]

A script builds in metres, with Blender's Z up and the front of the prize
towards -Y (in the game that is Y up and the front towards +Z), and ends with
save(). That puts the prize where the game looks for it, in a folder of its
own under user://prizes/ of this machine, or in <folder> when one is given:

- model.glb: the prize, standing on z = 0 and centred over the origin;
- prize.json: its name, how a sentence speaks of it, what it stands on and,
  where the script says so, how it sits (see scripts/prize.gd);
- preview.png: the prize next to a figure 1.8 m tall, rendered on the CPU,
  so it can be looked at while the GPU is somebody else's;
- build.py: a copy of the script that made it.

What takes the colour of a team is made with team=True: in the game its
material makes way for that of a team. A shape is made as a distance field
(Field: balls, rods and blocks that flow into one another, for anything
round and soft) or out of turned profiles, boxes and tubes (for anything
made by hand).
"""

import datetime
import json
import math
import os
import shutil
import sys

import bpy
import numpy as np
import openvdb
from mathutils import Matrix, Vector

# The folder of the game's user:// on a Mac, where it looks for made prizes.
USER = os.path.expanduser("~/Library/Application Support/Godot/app_userdata/Graphics FPS")
# What a prize may cost, in triangles, before save() says it is too many: the
# flag and the banana are some 2 000 each.
TRIANGLES = 6000
# What the stands of the game are called, for save(stand=...).
STANDS = ("football_stand", "banana_stand", "flag_stand")
TEAM_MATERIALS = ("team_paint", "team_ribbon", "team_leather")
# The colour team parts have in the preview: that of one side in the game.
PREVIEW_TEAM = (0.1, 0.34, 0.85)

_materials = {}
_team_count = 0


def start():
    """An empty scene to build in."""
    global _team_count
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _materials.clear()
    _team_count = 0


# --- Materials -----------------------------------------------------------------


def _linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def paint(name, colour, roughness=0.5, metallic=0.0):
    """A material of one colour, given as it looks on a screen (sRGB, 0 to 1)."""
    if name in _materials:
        return _materials[name]
    material = bpy.data.materials.new(name)
    rgb = tuple(_linear(c) for c in colour)
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = rgb + (1.0,)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    material.diffuse_color = rgb + (1.0,)
    _materials[name] = material
    return material


# --- Shapes as distance fields -------------------------------------------------


class Field:
    """How far every point of a block of space is from a surface, negative
    inside it. The block runs from `low` to `high` (metres) in steps of
    `step` metres; 1 cm is enough for a prize."""

    def __init__(self, low, high, step=0.01):
        self.low = np.array(low, dtype=np.float64)
        self.step = step
        self.shape = tuple(int(math.ceil((h - l) / step)) + 1 for l, h in zip(low, high))
        self.d = np.full(self.shape, 1.0, dtype=np.float32)

    def _points(self):
        axes = [(self.low[i] + np.arange(self.shape[i]) * self.step).astype(np.float32) for i in range(3)]
        return axes[0][:, None, None], axes[1][None, :, None], axes[2][None, None, :]

    def add(self, distance, flow=0.0):
        """Joins a shape, given as a function of points to distances, flowing
        into what is there over `flow` metres."""
        self.d = _merged(self.d, distance(self._points()).astype(np.float32), flow)

    def carve(self, distance, flow=0.0):
        """Takes a shape away, rounded off along the cut over `flow` metres."""
        self.d = -_merged(-self.d, distance(self._points()).astype(np.float32), flow)

    def keep(self, distance, flow=0.0):
        """Keeps only what lies inside a shape as well."""
        self.d = -_merged(-self.d, -distance(self._points()).astype(np.float32), flow)

    def ball(self, centre, radii, flow=0.0):
        """A ball, or an egg if `radii` is three numbers."""
        self.add(lambda p: egg(p, centre, radii), flow)

    def rod(self, a, b, ra, rb=None, flow=0.0):
        """A rod from `a` to `b` with rounded ends, `ra` thick at one end and `rb` at the other."""
        self.add(lambda p: round_cone(p, a, b, ra, ra if rb is None else rb), flow)

    def block(self, centre, size, corner=0.01, flow=0.0):
        """A box with rounded corners, as long, deep and high as `size`."""
        self.add(lambda p: block(p, centre, size, corner), flow)

    def torus(self, centre, axis, radius, thickness, flow=0.0):
        """A ring round `axis` through `centre`, `radius` to the middle of its
        rim and `thickness` across that rim."""
        self.add(lambda p: torus(p, centre, axis, radius, thickness * 0.5), flow)

    def sample(self, points):
        """The distance at each of `points` (n by 3), between the steps of the block."""
        at = (points - self.low) / self.step
        base = np.clip(np.floor(at).astype(int), 0, np.array(self.shape) - 2)
        t = (at - base).astype(np.float32)
        total = np.zeros(len(points), dtype=np.float32)
        for dx in (0, 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    share = (t[:, 0] if dx else 1 - t[:, 0]) * (t[:, 1] if dy else 1 - t[:, 1]) * (t[:, 2] if dz else 1 - t[:, 2])
                    total += share * self.d[base[:, 0] + dx, base[:, 1] + dy, base[:, 2] + dz]
        return total

    def outwards(self, points):
        """Which way the surface faces at each of `points`."""
        normals = np.zeros((len(points), 3), dtype=np.float32)
        for axis in range(3):
            shift = np.zeros(3)
            shift[axis] = self.step
            normals[:, axis] = self.sample(points + shift) - self.sample(points - shift)
        return normals / np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-9)

    def surface(self):
        """The surface as points and faces of three and four corners."""
        band = 3.0 * self.step
        grid = openvdb.FloatGrid(band)
        grid.copyFromArray(np.clip(self.d, -band, band))
        grid.transform = openvdb.createLinearTransform(voxelSize=self.step)
        grid.gridClass = openvdb.GridClass.LEVEL_SET
        points, triangles, quads = grid.convertToPolygons(isovalue=0.0, adaptivity=0.0)
        return points.astype(np.float64) + self.low, triangles, quads


def _merged(a, b, flow):
    if flow <= 0.0:
        return np.minimum(a, b)
    h = np.maximum(flow - np.abs(a - b), 0.0) / flow
    return np.minimum(a, b) - h * h * flow * 0.25


def egg(p, centre, radii):
    radii = [radii] * 3 if np.isscalar(radii) else radii
    qx, qy, qz = (p[0] - centre[0]) / radii[0], (p[1] - centre[1]) / radii[1], (p[2] - centre[2]) / radii[2]
    k0 = np.sqrt(qx * qx + qy * qy + qz * qz)
    k1 = np.sqrt((qx / radii[0]) ** 2 + (qy / radii[1]) ** 2 + (qz / radii[2]) ** 2)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def round_cone(p, a, b, ra, rb):
    a, b = np.array(a, dtype=np.float64), np.array(b, dtype=np.float64)
    ba = b - a
    l2 = float(ba.dot(ba))
    rr = ra - rb
    a2 = l2 - rr * rr
    il2 = 1.0 / l2
    px, py, pz = p[0] - a[0], p[1] - a[1], p[2] - a[2]
    y = px * ba[0] + py * ba[1] + pz * ba[2]
    z = y - l2
    qx, qy, qz = px * l2 - ba[0] * y, py * l2 - ba[1] * y, pz * l2 - ba[2] * y
    x2 = qx * qx + qy * qy + qz * qz
    y2 = y * y * l2
    z2 = z * z * l2
    k = np.sign(rr) * rr * rr * x2
    return np.where(
        np.sign(z) * a2 * z2 > k, np.sqrt(x2 + z2) * il2 - rb,
        np.where(np.sign(y) * a2 * y2 < k, np.sqrt(x2 + y2) * il2 - ra, (np.sqrt(np.maximum(x2 * a2 * il2, 0.0)) + y * rr) * il2 - ra))


def torus(p, centre, axis, radius, rim):
    axis = np.array(axis, dtype=np.float64)
    axis = axis / np.linalg.norm(axis)
    dx, dy, dz = p[0] - centre[0], p[1] - centre[1], p[2] - centre[2]
    along = dx * axis[0] + dy * axis[1] + dz * axis[2]
    across = np.sqrt(np.maximum(dx * dx + dy * dy + dz * dz - along * along, 0.0))
    return np.sqrt((across - radius) ** 2 + along * along) - rim


def block(p, centre, size, corner):
    q = [np.abs(p[i] - centre[i]) - (size[i] * 0.5 - corner) for i in range(3)]
    outside = np.sqrt(np.maximum(q[0], 0.0) ** 2 + np.maximum(q[1], 0.0) ** 2 + np.maximum(q[2], 0.0) ** 2)
    return outside + np.minimum(np.maximum(q[0], np.maximum(q[1], q[2])), 0.0) - corner


def shape(field, name, material, triangles=2500, team=False):
    """The surface of a field as an object of about that many triangles,
    shaded as smoothly as the field itself is."""
    points, three, four = field.surface()
    if len(points) == 0:
        raise SystemExit("The field for %s has no surface in it: is it inside its block?" % name)
    mesh = bpy.data.meshes.new(name)
    # OpenVDB winds its faces the other way round from Blender.
    faces = [tuple(int(i) for i in face[::-1]) for face in four] + [tuple(int(i) for i in face[::-1]) for face in three]
    mesh.from_pydata([tuple(p) for p in points], [], faces)
    mesh.update()
    obj = _link(name, mesh, team)
    count = len(four) * 2 + len(three)
    if count > triangles:
        thin = obj.modifiers.new("thin", "DECIMATE")
        thin.ratio = triangles / count
        obj.data = bpy.data.meshes.new_from_object(obj.evaluated_get(bpy.context.evaluated_depsgraph_get()))
        obj.modifiers.clear()
    mesh = obj.data
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    corners = np.array([vertex.co[:] for vertex in mesh.vertices], dtype=np.float64)
    normals = field.outwards(corners)
    mesh.normals_split_custom_set_from_vertices([tuple(float(c) for c in n) for n in normals])
    mesh.materials.append(material)
    return obj


# --- Shapes made by hand -------------------------------------------------------


def lathe(name, profile, material, sides=32, centre=(0.0, 0.0), team=False, sharp=35.0):
    """A turned shape around an upright axis through `centre`: `profile` is a
    list of (radius, height) from the bottom up. A radius of 0 closes it
    there. Edges sharper than `sharp` degrees stay sharp."""
    verts, faces, rings = [], [], []
    for radius, height in profile:
        if radius <= 0.0:
            rings.append([len(verts)])
            verts.append((centre[0], centre[1], height))
            continue
        ring = []
        for i in range(sides):
            angle = 2.0 * math.pi * i / sides
            ring.append(len(verts))
            verts.append((centre[0] + radius * math.cos(angle), centre[1] + radius * math.sin(angle), height))
        rings.append(ring)
    for lower, upper in zip(rings, rings[1:]):
        if len(lower) == 1 and len(upper) == 1:
            continue
        for i in range(sides):
            j = (i + 1) % sides
            if len(lower) == 1:
                faces.append((lower[0], upper[i], upper[j]))
            elif len(upper) == 1:
                faces.append((lower[i], lower[j], upper[0]))
            else:
                faces.append((lower[i], lower[j], upper[j], upper[i]))
    return _solid(name, verts, faces, material, team, sharp)


def box(name, centre, size, material, team=False):
    """A box as long (X), deep (Y) and high (Z) as `size`."""
    hx, hy, hz = (s * 0.5 for s in size)
    cx, cy, cz = centre
    verts = [(cx + x * hx, cy + y * hy, cz + z * hz) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return _solid(name, verts, faces, material, team, 30.0)


def tube(name, a, b, radius, material, sides=16, team=False, ends=True):
    """A round rod from `a` to `b`."""
    a, b = Vector(a), Vector(b)
    length = (b - a).length
    profile = [(0.0, 0.0), (radius, 0.0), (radius, length), (0.0, length)] if ends else [(radius, 0.0), (radius, length)]
    obj = lathe(name, profile, material, sides=sides, team=team)
    turn = Vector((0.0, 0.0, 1.0)).rotation_difference((b - a).normalized())
    obj.data.transform(Matrix.Translation(a) @ turn.to_matrix().to_4x4())
    return obj


def ball(name, centre, radius, material, team=False):
    """A ball, with as many sides as its size is worth."""
    sides = 24 if radius > 0.1 else 16 if radius > 0.03 else 10
    rings = sides // 2
    profile = [(0.0, -radius)] + [(radius * math.sin(math.pi * i / rings), -radius * math.cos(math.pi * i / rings)) for i in range(1, rings)] + [(0.0, radius)]
    obj = lathe(name, profile, material, sides=sides, centre=centre[:2], team=team, sharp=89.0)
    obj.data.transform(Matrix.Translation((0.0, 0.0, centre[2])))
    return obj


def ring(name, centre, radius, thickness, material, sides=32, round_sides=8, team=False):
    """A ring lying flat round an upright axis, `thickness` across."""
    verts, faces = [], []
    for i in range(sides):
        a = 2.0 * math.pi * i / sides
        for j in range(round_sides):
            b = 2.0 * math.pi * j / round_sides
            r = radius + thickness * 0.5 * math.cos(b)
            verts.append((centre[0] + r * math.cos(a), centre[1] + r * math.sin(a), centre[2] + thickness * 0.5 * math.sin(b)))
    for i in range(sides):
        for j in range(round_sides):
            i2, j2 = (i + 1) % sides, (j + 1) % round_sides
            faces.append((i * round_sides + j, i2 * round_sides + j, i2 * round_sides + j2, i * round_sides + j2))
    return _solid(name, verts, faces, material, team, 89.0)


def _solid(name, verts, faces, material, team, sharp):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.validate()
    obj = _link(name, mesh, team)
    mesh.shade_smooth()
    mesh.set_sharp_from_angle(angle=math.radians(sharp))
    mesh.materials.append(material)
    return obj


def _link(name, mesh, team):
    global _team_count
    if team:
        _team_count += 1
        name = "Team" if _team_count == 1 else "Team%d" % _team_count
    obj = bpy.data.objects.new(name.replace(".", "_"), mesh)
    obj["team"] = bool(team)
    bpy.context.collection.objects.link(obj)
    return obj


# --- Saving --------------------------------------------------------------------


def save(name, title, the, stand="football_stand", team_material="team_paint", poses=None, preview=True):
    """Writes the prize built so far into its folder (see above) and says
    what it came to. `name` is how the game knows it: small letters and
    underscores. `poses` may give "home", "down" and "carried" as in
    assets/prizes.json, wholly or only how each is turned."""
    if stand not in STANDS and not stand.endswith(".glb"):
        raise SystemExit("A stand is one of %s." % ", ".join(STANDS))
    if team_material not in TEAM_MATERIALS:
        raise SystemExit("A team material is one of %s." % ", ".join(TEAM_MATERIALS))
    parts = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not parts:
        raise SystemExit("There is nothing to save.")
    # Standing on z = 0, over the origin.
    low = Vector((math.inf,) * 3)
    high = Vector((-math.inf,) * 3)
    for obj in parts:
        for corner in obj.bound_box:
            at = obj.matrix_world @ Vector(corner)
            low = Vector(map(min, low, at))
            high = Vector(map(max, high, at))
    shift = Matrix.Translation(Vector((-(low.x + high.x) * 0.5, -(low.y + high.y) * 0.5, -low.z)))
    for obj in parts:
        obj.matrix_world = shift @ obj.matrix_world
    size = high - low
    triangles = sum(len(poly.vertices) - 2 for obj in parts for poly in obj.data.polygons)

    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    folder = os.path.abspath(args[0]) if args else os.path.join(USER, "prizes", name)
    os.makedirs(folder, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(folder, "model.glb"), export_format="GLB", export_yup=True, export_apply=True,
        use_selection=True, export_cameras=False, export_lights=False, export_animations=False)

    entry = {"name": title, "the": the, "model": "model.glb", "stand": stand, "team": team_material}
    for way, pose in (poses or {}).items():
        entry[way] = pose
    entry["made"] = datetime.date.today().isoformat()
    with open(os.path.join(folder, "prize.json"), "w") as out:
        json.dump(entry, out, indent="\t")
    script = sys.argv[sys.argv.index("--python") + 1] if "--python" in sys.argv else ""
    if script and os.path.abspath(script) != os.path.join(folder, "build.py"):
        shutil.copyfile(script, os.path.join(folder, "build.py"))
    if preview:
        _preview(parts, size, os.path.join(folder, "preview.png"))
    team = sum(1 for obj in parts if obj.get("team"))
    print("PRIZE %s: %s, %.2f by %.2f by %.2f m (across, front to back, high), %d triangles in %d parts, %d of them in the colour of a team" % (
        name, folder, size.x, size.y, size.z, triangles, len(parts), team))
    if triangles > TRIANGLES:
        print("PRIZE WARNING: more than %d triangles" % TRIANGLES)
    if max(size) < 0.4:
        print("PRIZE WARNING: under 40 cm on every side; it will be hard to see across a hall")
    if size.z > 1.5:
        print("PRIZE WARNING: over 1.5 m high; carried, it reaches far above a head")
    if not team:
        print("PRIZE WARNING: nothing of it takes the colour of a team; only its stand will")


def _preview(parts, size, path):
    """The prize from in front and a little to its left, next to a grey figure
    1.8 m tall, rendered on the CPU. Team parts are in the colour of a side."""
    scene = bpy.context.scene
    blue = paint("_preview_team", PREVIEW_TEAM, 0.5)
    for obj in parts:
        if obj.get("team"):
            obj.data.materials.clear()
            obj.data.materials.append(blue)
    grey = paint("_preview_figure", (0.55, 0.55, 0.57), 0.8)
    floor = paint("_preview_floor", (0.32, 0.31, 0.3), 0.9)
    aside = size.x * 0.5 + 0.55
    lathe("_figure", [(0.0, 0.0), (0.17, 0.0), (0.2, 0.9), (0.24, 1.35), (0.14, 1.46), (0.06, 1.5), (0.06, 1.56), (0.0, 1.56)], grey, sides=20, centre=(aside, 0.15))
    ball("_head", (aside, 0.15, 1.66), 0.13, grey)
    box("_floor", (0.0, 0.0, -0.01), (20.0, 20.0, 0.02), floor)
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 4
    scene.render.resolution_x = 900
    scene.render.resolution_y = 700
    scene.render.film_transparent = False
    # Colours as they were given, not toned down as a film would.
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("sky")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes["Background"]
    background.inputs[0].default_value = (0.55, 0.6, 0.68, 1.0)
    background.inputs[1].default_value = 0.7
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(45), math.radians(-15), math.radians(-35))
    scene.collection.objects.link(sun)
    camera = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
    camera.data.lens = 50
    scene.collection.objects.link(camera)
    scene.camera = camera
    middle = Vector((aside * 0.4, 0.0, max(size.z, 1.8) * 0.48))
    reach = max(size.x + 1.2, 2.0) * 1.35
    camera.location = middle + Vector((-0.55, -1.0, 0.28)).normalized() * reach * 1.6
    camera.rotation_euler = (middle - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)

