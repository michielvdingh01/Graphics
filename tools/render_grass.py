"""Renders the sheaves of grass that the cards of a clump show: real blades,
modelled one by one and lit by an even sky, so that each lies in the shade
of its neighbours, with a picture of which way every blade faces to go with
it. Run by tools/render_grass.sh, in Blender and without a window:

    blender -b --factory-startup --python tools/render_grass.py -- <kind> <colour.png> <normal.png>

A picture is four sheaves side by side, each a quarter of its width and
twice as high as it is wide. A sheaf rises from the middle of the bottom of
its quarter and stays inside it, so that a card can show one quarter and
nothing of the next. The kinds:

    marram   long stiff blades, grey-green with bleached tips: a tall
             sheaf, one in flower, one of last year's straw, a short one
    sedge    the low dry grass of the grey dune: fine blades a hand high,
             in four small tufts

Nothing here is scanned. What it has over a drawing is the light: blades
that turn, fold along their rib and stand in front of one another.
"""
import math
import random
import sys

import bpy
import numpy as np

KIND, COLOUR, NORMAL = sys.argv[sys.argv.index("--") + 1:][:3]

# What one quarter of the picture shows, in metres, and how many dots high
# the picture is: it is twice as wide.
CELL_WIDE = 0.55
CELL_HIGH = 1.10
DOTS = 1024

GREEN = (0.12, 0.165, 0.08)
BLUE_GREEN = (0.10, 0.155, 0.095)
YELLOW_GREEN = (0.19, 0.215, 0.07)
STRAW = (0.42, 0.33, 0.15)
PALE = (0.50, 0.44, 0.26)
GREY_STRAW = (0.30, 0.26, 0.17)
SHEATH = (0.36, 0.30, 0.16)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


class Sheaf:
    """The blades of one quarter, as one mesh in the making."""

    def __init__(self, cell, seed):
        self.rng = random.Random(seed)
        self.middle = (cell - 1.5) * CELL_WIDE
        self.points = []
        self.faces = []
        self.colours = []

    def blade(self, length, width, tip_at, colour_of, steps=14, droop=0.0, fold=0.3):
        """One blade from the foot of the sheaf to `tip_at` metres left or
        right of it, `length` long along its curve. `colour_of(t)` is its
        colour from foot (0) to tip (1)."""
        rng = self.rng
        x = self.middle + max(-0.08, min(0.08, rng.gauss(0.0, 0.035))) + tip_at * 0.12
        y = rng.uniform(-0.09, 0.09)
        z = -0.01
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
        # A blade that would lean into the next quarter is left out.
        if max(abs(point[0] - self.middle) for point in self.points[first:]) > CELL_WIDE * 0.5 - 0.012:
            del self.points[first:]
            del self.colours[first:]
            del self.faces[faces:]

    def plume(self, height, lean):
        """A stalk with the spike of marram in flower at its top."""
        rng = self.rng
        self.blade(height, 0.0035, lean, lambda t: mix(SHEATH, PALE, t), fold=0.5)
        foot = self.points[-2]
        long = rng.uniform(0.12, 0.17)
        thick = rng.uniform(0.008, 0.011)
        tone = mix(PALE, STRAW, rng.random() * 0.6)
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


def marram(sheaf, cell):
    rng = sheaf.rng
    if cell == 0:
        # Tall and in leaf.
        for i in range(170):
            sheaf.blade(rng.uniform(0.6, 1.06), rng.uniform(0.006, 0.009), spread(rng, 0.2), live(rng) if rng.random() < 0.8 else dead(rng), droop=rng.uniform(0.0, 0.14))
        for i in range(110):
            sheaf.blade(rng.uniform(0.22, 0.55), rng.uniform(0.0055, 0.008), spread(rng, 0.2), dead(rng) if rng.random() < 0.5 else live(rng, 0.6), droop=0.12)
    elif cell == 1:
        # In flower: fewer blades, and spikes over them.
        for i in range(130):
            sheaf.blade(rng.uniform(0.5, 0.9), rng.uniform(0.006, 0.0085), spread(rng, 0.2), live(rng, 0.5) if rng.random() < 0.7 else dead(rng), droop=rng.uniform(0.0, 0.16))
        for i in range(90):
            sheaf.blade(rng.uniform(0.2, 0.5), rng.uniform(0.0055, 0.008), spread(rng, 0.2), dead(rng) if rng.random() < 0.6 else live(rng, 0.6), droop=0.12)
        for lean in (-0.15, -0.09, -0.03, 0.02, 0.08, 0.14):
            sheaf.plume(rng.uniform(0.82, 0.96), lean + rng.uniform(-0.02, 0.02))
    elif cell == 2:
        # Last year's: straw, shorter, some of it broken down.
        for i in range(210):
            sheaf.blade(rng.uniform(0.3, 0.85), rng.uniform(0.0055, 0.0085), spread(rng, 0.22), dead(rng) if rng.random() < 0.85 else live(rng, 0.8), droop=rng.uniform(0.0, 0.4))
    else:
        # Short and thick: the heart of a clump, or a young one.
        for i in range(260):
            sheaf.blade(rng.uniform(0.25, 0.68), rng.uniform(0.0055, 0.0085), spread(rng, 0.22), live(rng, 0.45) if rng.random() < 0.72 else dead(rng), droop=rng.uniform(0.0, 0.22))


def sedge(sheaf, cell):
    rng = sheaf.rng
    # Tufts a hand high, three or four to a quarter, finer than marram.
    feet = [(-0.085, 0.16), (0.0, 0.24), (0.09, 0.14)] if cell % 2 == 0 else [(-0.1, 0.12), (-0.03, 0.2), (0.05, 0.26), (0.105, 0.13)]
    middle = sheaf.middle
    for foot, high in feet:
        sheaf.middle = middle + foot
        withered = 0.35 + 0.15 * cell
        for i in range(rng.randint(16, 26)):
            sheaf.blade(high * rng.uniform(0.45, 1.1), rng.uniform(0.0022, 0.0034), spread(rng, 0.045), dead(rng) if rng.random() < withered else live(rng, 0.9), steps=8, droop=rng.uniform(0.0, 0.5))
    sheaf.middle = middle


def build():
    sheaves = []
    for cell in range(4):
        sheaf = Sheaf(cell, {"marram": 11, "sedge": 23}[KIND] * 100 + cell)
        globals()[KIND](sheaf, cell)
        mesh = bpy.data.meshes.new("sheaf%d" % cell)
        mesh.from_pydata(sheaf.points, [], sheaf.faces)
        tint = mesh.color_attributes.new("tint", "FLOAT_COLOR", "POINT")
        tint.data.foreach_set("color", np.array([c + (1.0,) for c in sheaf.colours], dtype=np.float32).ravel())
        for face in mesh.polygons:
            face.use_smooth = True
        obj = bpy.data.objects.new("sheaf%d" % cell, mesh)
        bpy.context.scene.collection.objects.link(obj)
        sheaves.append(obj)
    return sheaves


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
    sheaves = build()
    blade = blade_material()
    for obj in sheaves:
        obj.data.materials.append(blade)

    camera = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
    scene.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = CELL_WIDE * 4.0
    camera.location = (0.0, -3.0, CELL_HIGH * 0.5)
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
    scene.render.resolution_x = DOTS * 2
    scene.render.resolution_y = DOTS
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
