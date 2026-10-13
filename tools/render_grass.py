"""Renders the grass that the cards of a clump show: real blades, modelled
one by one and lit by an even sky, so that each lies in the shade of its
neighbours, with a picture of which way every blade faces to go with it. Run
by tools/render_grass.sh, in Blender and without a window:

    blender -b --factory-startup --python tools/render_grass.py -- <kind> <colour.png> <normal.png>

A picture holds four plants, each in a cell of its own. A plant rises from
the middle of the bottom of its cell and stays inside it, so that a card can
show one cell and nothing of the next. The kinds:

    marram   a tussock seen from the side, long stiff blades that fan out
             of one foot and arch over, grey-green with bleached tips. Two
             cells by two, each 1.2 m square: one in leaf, one in flower,
             one of last year's straw, and a short thick one. A blade stays
             inside the trapezium the card is cut to: as wide as the cell
             at the top, less than half of it at the foot.
    sedge    the fine grass that grows low, a hand or two high: four cells
             side by side, each 0.55 m wide and twice as high, with a few
             tufts in each, the later ones withered and in seed

Nothing here is scanned. What it has over a drawing is the light: blades
that turn, fold along their rib and stand in front of one another.
"""
import math
import random
import sys

import bpy
import numpy as np

KIND, COLOUR, NORMAL = sys.argv[sys.argv.index("--") + 1:][:3]

# How the cells of each kind lie: how many side by side and over each other,
# what one shows in metres, how many dots it is wide and high, and how far
# from its middle a blade may come at its foot, as a share of its width (a
# half for a cell that is not cut to a trapezium).
LAYOUTS = {
    "marram": {"across": 2, "down": 2, "wide": 1.2, "high": 1.2, "dots": (1024, 1024), "foot": 0.22},
    "sedge": {"across": 4, "down": 1, "wide": 0.55, "high": 1.1, "dots": (512, 1024), "foot": 0.5},
}
LAYOUT = LAYOUTS[KIND]

GREEN = (0.10, 0.15, 0.07)
BLUE_GREEN = (0.09, 0.14, 0.085)
YELLOW_GREEN = (0.19, 0.215, 0.07)
STRAW = (0.36, 0.28, 0.125)
PALE = (0.42, 0.36, 0.2)
GREY_STRAW = (0.30, 0.26, 0.17)
SHEATH = (0.36, 0.30, 0.16)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


class Plant:
    """The blades of one cell, as one mesh in the making."""

    def __init__(self, cell, seed):
        self.rng = random.Random(seed)
        # Where the foot of the cell lies: cells are counted from the top
        # left of the picture.
        self.cell_middle = (cell % LAYOUT["across"] - (LAYOUT["across"] - 1) * 0.5) * LAYOUT["wide"]
        self.ground = (LAYOUT["down"] - 1 - cell // LAYOUT["across"]) * LAYOUT["high"]
        self.middle = self.cell_middle
        self.points = []
        self.faces = []
        self.colours = []

    def inside(self, point):
        """Whether a point lies in what a card shows of this cell."""
        up = (point[2] - self.ground) / LAYOUT["high"]
        if up > 0.985:
            return False
        reach = LAYOUT["foot"] + (0.5 - LAYOUT["foot"]) * max(up, 0.0)
        return abs(point[0] - self.cell_middle) < reach * LAYOUT["wide"] - 0.012

    def blade(self, length, width, tip_at, colour_of, steps=14, droop=0.0, fold=0.3, foot=0.035):
        """One blade from the foot of the plant to `tip_at` metres left or
        right of it, `length` long along its curve. `colour_of(t)` is its
        colour from foot (0) to tip (1). True if it came to stand."""
        rng = self.rng
        x = self.middle + max(-2.3 * foot, min(2.3 * foot, rng.gauss(0.0, foot))) + tip_at * 0.12
        y = rng.uniform(-0.09, 0.09)
        z = self.ground - 0.01
        # It leaves the foot at one slant and bends on to another: the two
        # together take its tip where it should be.
        slant = rng.uniform(-0.05, 0.05) + tip_at * 0.25 / length
        bend = 2.0 * (tip_at / length - math.sin(slant)) + droop * (1.0 if tip_at >= 0 else -1.0)
        nod = rng.uniform(-0.25, 0.25)
        turn = rng.uniform(-0.8, 0.8)
        twist = rng.uniform(-1.2, 1.2)
        first = len(self.points)
        faces = len(self.faces)
        for step in range(steps + 1):
            t = step / steps
            lean = slant + bend * t * t
            if step:
                piece = length / steps
                x += math.sin(lean) * piece
                z += math.cos(lean) * math.cos(nod * t) * piece
                y += math.sin(nod * t) * piece
            wide = width * (1.0 if t < 0.45 else max(0.0, 1.0 - ((t - 0.45) / 0.55) ** 1.6)) * (0.6 + 0.4 * min(1.0, t * 6.0))
            facing = turn + twist * t
            side = (math.cos(facing) * math.cos(lean), math.sin(facing), -math.cos(facing) * math.sin(lean))
            back = (-math.sin(facing) * math.cos(lean), math.cos(facing), math.sin(facing) * math.sin(lean))
            for across in (-0.5, 0.0, 0.5):
                dent = fold * wide * (1.0 if across == 0.0 else 0.0)
                self.points.append((x + side[0] * wide * across + back[0] * dent, y + side[1] * wide * across + back[1] * dent, z + side[2] * wide * across + back[2] * dent))
                self.colours.append(colour_of(t))
            if step:
                row = first + step * 3
                self.faces.append((row - 3, row - 2, row + 1, row))
                self.faces.append((row - 2, row - 1, row + 2, row + 1))
        # A blade that would leave what the card shows is left out.
        if not all(self.inside(point) for point in self.points[first:]):
            del self.points[first:]
            del self.colours[first:]
            del self.faces[faces:]
            return False
        return True

    def plume(self, height, lean):
        """A stalk with the spike of marram in flower at its top."""
        rng = self.rng
        if not self.blade(height, 0.009, lean, lambda t: mix(SHEATH, STRAW, t), fold=0.5):
            return
        foot = self.points[-2]
        long = rng.uniform(0.12, 0.17)
        thick = rng.uniform(0.008, 0.011)
        tone = mix(STRAW, GREY_STRAW, rng.random() * 0.6)
        sides = 7
        rings = 8
        first = len(self.points)
        for ring in range(rings + 1):
            t = ring / rings
            swell = thick * math.sin(math.pi * (0.04 + 0.96 * t) ** 0.8) ** 0.4 * (1.0 + 0.18 * math.sin(t * 40.0))
            for side in range(sides):
                angle = math.tau * side / sides + ring * 0.4
                self.points.append((foot[0] + math.cos(angle) * swell + lean * 0.08 * t * long / height, foot[1] + math.sin(angle) * swell, foot[2] - 0.02 + t * long))
                self.colours.append(mix(tone, GREY_STRAW, 0.25 * (side % 2) + 0.2 * rng.random()))
            if ring:
                for side in range(sides):
                    a = first + (ring - 1) * sides + side
                    b = first + (ring - 1) * sides + (side + 1) % sides
                    self.faces.append((a, b, b + sides, a + sides))


def live(rng, yellow=0.3):
    """The colour along a living blade: a pale sheath, green, and a tip
    that has bleached."""
    green = mix(mix(GREEN, BLUE_GREEN, rng.random()), YELLOW_GREEN, rng.random() * yellow)
    green = mix(green, (0, 0, 0), rng.random() * 0.18)
    tip = rng.uniform(0.55, 1.05)
    return lambda t: mix(mix(SHEATH, green, min(1.0, t * 5.0)), STRAW, max(0.0, (t - tip) / (1.02 - tip)) if tip < 1.0 else 0.0)


def dead(rng):
    """The colour of a blade of last year."""
    straw = mix(mix(STRAW, PALE, rng.random()), GREY_STRAW, rng.random() * 0.7)
    return lambda t: mix(straw, GREY_STRAW, 0.3 * (1.0 - t))


def spread(rng, reach):
    """Where a tip ends, left or right of the foot: more of them out to the
    sides than a bell would have."""
    return rng.uniform(-1.0, 1.0) * reach * (0.35 + 0.65 * rng.random() ** 0.6)


def fan(plant, blades, lengths, widths, reach, colour, droops):
    """Blades that fan out of the foot of a tussock: the further out a tip
    ends, the more the blade arches over and the shorter it stands."""
    rng = plant.rng
    for i in range(blades):
        out = rng.uniform(-1.0, 1.0)
        out = math.copysign(abs(out) ** 0.8, out)
        long = rng.uniform(*lengths) * (1.0 - 0.25 * abs(out))
        plant.blade(long, rng.uniform(*widths), out * reach * long, colour(rng), droop=abs(out) * rng.uniform(*droops) + rng.uniform(0.0, 0.12), foot=0.05)


def marram(plant, cell):
    rng = plant.rng
    widths = (0.006, 0.009)
    if cell == 0:
        # In leaf: tall in the middle, arching over all round.
        fan(plant, 300, (0.7, 1.08), widths, 0.5, lambda r: live(r) if r.random() < 0.82 else dead(r), (0.2, 0.9))
        fan(plant, 200, (0.25, 0.6), widths, 0.75, lambda r: dead(r) if r.random() < 0.5 else live(r, 0.6), (0.3, 1.1))
    elif cell == 1:
        # In flower: spikes over the leaves.
        fan(plant, 250, (0.6, 0.98), widths, 0.5, lambda r: live(r, 0.5) if r.random() < 0.72 else dead(r), (0.2, 0.9))
        fan(plant, 180, (0.22, 0.55), widths, 0.75, lambda r: dead(r) if r.random() < 0.6 else live(r, 0.6), (0.3, 1.1))
        for lean in (-0.3, -0.19, -0.1, -0.03, 0.05, 0.13, 0.22, 0.32):
            plant.plume(rng.uniform(0.84, 1.0), lean + rng.uniform(-0.03, 0.03))
    elif cell == 2:
        # Last year's: straw, much of it broken down and lying out.
        fan(plant, 280, (0.4, 0.95), widths, 0.6, lambda r: dead(r) if r.random() < 0.85 else live(r, 0.8), (0.3, 1.3))
        fan(plant, 160, (0.2, 0.5), widths, 0.8, dead, (0.5, 1.4))
    else:
        # Short and thick: a young one, or the skirt of an old one.
        fan(plant, 420, (0.25, 0.62), widths, 0.7, lambda r: live(r, 0.45) if r.random() < 0.7 else dead(r), (0.3, 1.2))


def sedge(plant, cell):
    rng = plant.rng
    # Tufts a hand or two high, a few to a cell, finer than marram and more
    # of it withered from one cell to the next.
    feet = [(-0.15, 0.3), (0.0, 0.46), (0.16, 0.26)] if cell % 2 == 0 else [(-0.19, 0.22), (-0.07, 0.38), (0.07, 0.5), (0.19, 0.24)]
    withered = 0.25 + 0.2 * cell
    for foot, high in feet:
        for i in range(rng.randint(70, 110)):
            plant.middle = plant.cell_middle + foot + rng.gauss(0.0, 0.012)
            plant.blade(high * rng.uniform(0.4, 1.1), rng.uniform(0.0034, 0.005), spread(rng, 0.085), dead(rng) if rng.random() < withered else live(rng, 0.9), steps=9, droop=rng.uniform(0.0, 0.6))
        if cell >= 2:
            # In seed: thin stalks with a wisp at the top.
            for i in range(rng.randint(5, 9)):
                plant.middle = plant.cell_middle + foot
                plant.blade(high * rng.uniform(1.25, 1.75), 0.0032, spread(rng, 0.05), lambda t: mix(STRAW, PALE, t), steps=9, fold=0.5)
    plant.middle = plant.cell_middle


def build():
    plants = []
    for cell in range(LAYOUT["across"] * LAYOUT["down"]):
        plant = Plant(cell, {"marram": 11, "sedge": 23}[KIND] * 100 + cell)
        globals()[KIND](plant, cell)
        mesh = bpy.data.meshes.new("plant%d" % cell)
        mesh.from_pydata(plant.points, [], plant.faces)
        tint = mesh.color_attributes.new("tint", "FLOAT_COLOR", "POINT")
        tint.data.foreach_set("color", np.array([c + (1.0,) for c in plant.colours], dtype=np.float32).ravel())
        for face in mesh.polygons:
            face.use_smooth = True
        obj = bpy.data.objects.new("plant%d" % cell, mesh)
        bpy.context.scene.collection.objects.link(obj)
        plants.append(obj)
    return plants


def blade_material():
    material = bpy.data.materials.new("blade")
    nodes = material.node_tree.nodes
    bsdf = nodes["Principled BSDF"]
    tint = nodes.new("ShaderNodeVertexColor")
    tint.layer_name = "tint"
    material.node_tree.links.new(tint.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    return material


def facing_material():
    """Shows which way a surface faces as a colour, for a card that is
    looked at from the front: red to the right, green up, blue towards
    whoever looks."""
    material = bpy.data.materials.new("facing")
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    glow = nodes.new("ShaderNodeEmission")
    geometry = nodes.new("ShaderNodeNewGeometry")
    apart = nodes.new("ShaderNodeSeparateXYZ")
    together = nodes.new("ShaderNodeCombineXYZ")
    away = nodes.new("ShaderNodeMath")
    away.operation = "MULTIPLY"
    away.inputs[1].default_value = -1.0
    half = nodes.new("ShaderNodeVectorMath")
    half.operation = "MULTIPLY_ADD"
    half.inputs[1].default_value = (0.5, 0.5, 0.5)
    half.inputs[2].default_value = (0.5, 0.5, 0.5)
    links.new(geometry.outputs["Normal"], apart.inputs[0])
    links.new(apart.outputs["X"], together.inputs["X"])
    links.new(apart.outputs["Z"], together.inputs["Y"])
    links.new(apart.outputs["Y"], away.inputs[0])
    links.new(away.outputs[0], together.inputs["Z"])
    links.new(together.outputs[0], half.inputs[0])
    links.new(half.outputs[0], glow.inputs["Color"])
    links.new(glow.outputs[0], out.inputs["Surface"])
    return material


def main():
    scene = bpy.context.scene
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    plants = build()
    blade = blade_material()
    for obj in plants:
        obj.data.materials.append(blade)

    wide = LAYOUT["across"] * LAYOUT["wide"]
    high = LAYOUT["down"] * LAYOUT["high"]
    camera = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
    scene.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = max(wide, high)
    camera.location = (0.0, -3.0, high * 0.5)
    camera.rotation_euler = (math.pi * 0.5, 0.0, 0.0)
    scene.camera = camera

    world = bpy.data.worlds.new("sky")
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (1, 1, 1, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    scene.world = world

    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 64
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 3
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 4
    scene.render.resolution_x = LAYOUT["across"] * LAYOUT["dots"][0]
    scene.render.resolution_y = LAYOUT["down"] * LAYOUT["dots"][1]
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.filter_size = 1.3
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"

    scene.render.filepath = COLOUR
    bpy.ops.render.render(write_still=True)

    bpy.context.view_layer.material_override = facing_material()
    scene.view_settings.view_transform = "Raw"
    scene.cycles.samples = 32
    scene.render.filepath = NORMAL
    bpy.ops.render.render(write_still=True)


main()
