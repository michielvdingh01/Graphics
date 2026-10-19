"""Renders the small green of the Alps, the plants that are drawn round the
eye (scripts/meadow.gd): the grass of the meadows in three kinds, and what
grows between it. Run with tools/gen_plants.sh [sheet], which hands this to
Blender:

    blender -b --factory-startup --python tools/gen_plants.py -- [sheet ...]

Nothing here is scanned or drawn: every blade is grown, as in
tools/render_grass.py, and lit by an even sky, so that each lies in the shade
of the ones round it. A sheet is a picture of cells, each cell one plant or
one clump seen from the side, its foot in the middle of the bottom of the
cell; a card in the game shows one cell. Next to <sheet>.png comes
<sheet>_n.png, which way every dot of it faces (red to the right, green up,
blue towards whoever looks), and <sheet>.json, where on the sheet every cell
is and how many metres it shows.

The sheets, as assets/manifest.json lists them (source "rendered",
generator this file):

    alps_meadow   the grass of the meadows in the middle of October, twelve
                  cells and four for afar:
                    mown    the aftermath of a meadow mown for the last time
                            in September, a hand high: fine blades, clover,
                            ribwort, the tips of some gone the colour of straw
                    top     the same from above, for a card that lies in it
                    long    the grass nobody cut, along ditches, fences, the
                            walls of barns and the edge of the wood: knee
                            high, gone to seed, much of it straw and lodged
                    wet     the litter meadows of the Moos: tussocks of
                            sedge, soft rush, and purple moor grass gone gold
                    far     each of the three as a band, for a card that
                            stands for many tufts at once

Cycles on the processor, on four threads: the video card is Godot's.
"""

import json
import math
import os
import random
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
MANIFEST = os.path.join(HERE, "..", "assets", "manifest.json")
OUT_DIR = os.path.join(HERE, "..", "assets", "foliage")
IMPORT = '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=2\ncompress/high_quality=true\ncompress/normal_map=%d\nmipmaps/generate=true\nprocess/fix_alpha_border=true\ndetect_3d/compress_to=0\n'

# Colours, as Blender has them (linear).
RYE = (0.065, 0.15, 0.035)
MEADOW = (0.1, 0.19, 0.05)
BLUE_GREEN = (0.07, 0.13, 0.07)
YELLOW_GREEN = (0.2, 0.24, 0.06)
SHEATH = (0.3, 0.27, 0.13)
STRAW = (0.38, 0.29, 0.13)
PALE = (0.47, 0.4, 0.24)
GREY_STRAW = (0.3, 0.26, 0.17)
DECAYED = (0.15, 0.11, 0.065)
CLOVER = (0.055, 0.14, 0.04)
PLANTAIN = (0.07, 0.13, 0.04)
TAWNY = (0.46, 0.25, 0.075)
GOLD = (0.55, 0.36, 0.1)
RUSH = (0.045, 0.09, 0.025)
RUSH_DEAD = (0.24, 0.17, 0.08)
SEDGE = (0.09, 0.14, 0.075)
SEDGE_AUTUMN = (0.34, 0.25, 0.09)
PANICLE = (0.22, 0.13, 0.12)
SPIKE_BROWN = (0.09, 0.06, 0.035)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def darker(c, by):
    return tuple(v * (1.0 - by) for v in c)


class Plant:
    """What one cell shows, as one mesh in the making. The cell is `wide`
    by `high` metres, its foot at the origin, x to the right and z up; the
    camera looks along +y. `foot` is how far from the middle a blade may
    stand at the bottom, as a share of the width: the card is cut to a
    trapezium, a half for one that is not."""

    def __init__(self, wide, high, seed, foot=0.3, plan=False):
        self.rng = random.Random(seed)
        self.wide = wide
        self.high = high
        self.foot = foot
        # Seen from above, a cell is a square on the ground.
        self.plan = plan
        self.middle = 0.0
        self.points = []
        self.faces = []
        self.colours = []

    def inside(self, point):
        if self.plan:
            return abs(point[0]) < self.wide * 0.5 - 0.006 and abs(point[1]) < self.wide * 0.5 - 0.006
        up = point[2] / self.high
        if up > 0.985 or up < -0.05:
            return False
        reach = self.foot + (0.5 - self.foot) * min(1.0, max(up, 0.0) * 2.5)
        return abs(point[0]) < reach * self.wide - 0.006

    def _keep(self, first, faces):
        if all(self.inside(point) for point in self.points[first:]):
            return True
        del self.points[first:]
        del self.colours[first:]
        del self.faces[faces:]
        return False

    def blade(self, length, width, tip_at, colour_of, steps=12, droop=0.0, fold=0.3, spread=0.035, depth=0.09, taper=0.45, lie=0.0):
        """One blade from near the foot to `tip_at` metres left or right of
        it, `length` long along its curve. `colour_of(t)` is its colour from
        foot (0) to tip (1). `droop` bends it over further, `lie` lays it
        towards the ground as a blade that has lodged. True if it came to
        stand inside the cell; its last corners are then its tip."""
        rng = self.rng
        x = self.middle + max(-2.3 * spread, min(2.3 * spread, rng.gauss(0.0, spread))) + tip_at * 0.12
        y = rng.uniform(-depth, depth)
        z = -0.01
        slant = rng.uniform(-0.05, 0.05) + tip_at * 0.25 / length
        bend = 2.0 * (tip_at / length - math.sin(slant)) + droop * (1.0 if tip_at >= 0 else -1.0)
        nod = rng.uniform(-0.25, 0.25) + lie * (1.0 if rng.random() < 0.5 else -1.0)
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
            wide = width * (1.0 if t < taper else max(0.0, 1.0 - ((t - taper) / (1.0 - taper)) ** 1.6)) * (0.6 + 0.4 * min(1.0, t * 6.0))
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
        return self._keep(first, faces)

    def tip(self):
        """Where the blade added last ends, and which way it went there."""
        end = self.points[-2]
        before = self.points[-5]
        way = tuple(end[i] - before[i] for i in range(3))
        size = math.sqrt(sum(v * v for v in way)) or 1.0
        return end, tuple(v / size for v in way)

    def stem(self, points, radius, colour, sides=4):
        """A round stem through `points`, thinning to the top."""
        first = len(self.points)
        faces = len(self.faces)
        for i, point in enumerate(points):
            ahead = points[min(i + 1, len(points) - 1)]
            behind = points[max(i - 1, 0)]
            way = np.array(ahead) - np.array(behind)
            way /= max(np.linalg.norm(way), 1e-9)
            ref = np.array([0.0, 1.0, 0.0]) if abs(way[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
            side = np.cross(way, ref)
            side /= np.linalg.norm(side)
            up = np.cross(way, side)
            r = radius * (1.0 - 0.6 * i / max(1, len(points) - 1))
            for s in range(sides):
                a = math.tau * s / sides
                self.points.append(tuple(np.array(point) + (side * math.cos(a) + up * math.sin(a)) * r))
                self.colours.append(colour(i / max(1, len(points) - 1)) if callable(colour) else colour)
            if i:
                for s in range(sides):
                    a = first + (i - 1) * sides + s
                    b = first + (i - 1) * sides + (s + 1) % sides
                    self.faces.append((a, b, b + sides, a + sides))
        return self._keep(first, faces)

    def blob(self, at, size, colour, long=1.0, way=(0.0, 0.0, 1.0), sides=5):
        """A small spindle, a spikelet or a seed, `size` across and `long`
        times that along `way`."""
        way = np.array(way, dtype=float)
        way /= max(np.linalg.norm(way), 1e-9)
        ref = np.array([0.0, 1.0, 0.0]) if abs(way[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
        side = np.cross(way, ref)
        side /= np.linalg.norm(side)
        up = np.cross(way, side)
        centre = np.array(at)
        first = len(self.points)
        faces = len(self.faces)
        self.points.append(tuple(centre - way * size * long * 0.5))
        self.colours.append(darker(colour, 0.2))
        for s in range(sides):
            a = math.tau * s / sides
            self.points.append(tuple(centre + (side * math.cos(a) + up * math.sin(a)) * size * 0.5))
            self.colours.append(colour)
        self.points.append(tuple(centre + way * size * long * 0.5))
        self.colours.append(mix(colour, PALE, 0.2))
        for s in range(sides):
            a = first + 1 + s
            b = first + 1 + (s + 1) % sides
            self.faces.append((first, b, a))
            self.faces.append((a, b, first + sides + 1))
        return self._keep(first, faces)

    def leaf(self, at, way, length, width, colour, curl=0.2, steps=6):
        """A flat leaf from `at` along `way` (leaning out of the ground), as
        wide as `width` in its middle: clover, ribwort, a seedling."""
        way = np.array(way, dtype=float)
        way /= max(np.linalg.norm(way), 1e-9)
        ref = np.array([0.0, 0.0, 1.0]) if abs(way[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
        side = np.cross(way, ref)
        side /= np.linalg.norm(side)
        first = len(self.points)
        faces = len(self.faces)
        point = np.array(at, dtype=float)
        for step in range(steps + 1):
            t = step / steps
            w = width * math.sin(math.pi * min(1.0, 0.08 + t * 0.95)) ** 0.8
            heading = way + np.array([0.0, 0.0, -curl * t])
            heading /= np.linalg.norm(heading)
            if step:
                point = point + heading * length / steps
            for across in (-0.5, 0.0, 0.5):
                lift = abs(across) * w * 0.25
                self.points.append(tuple(point + side * w * across + np.array([0.0, 0.0, lift])))
                self.colours.append(mix(darker(colour, 0.15), colour, t) if across == 0.0 else colour)
            if step:
                row = first + step * 3
                self.faces.append((row - 3, row - 2, row + 1, row))
                self.faces.append((row - 2, row - 1, row + 2, row + 1))
        return self._keep(first, faces)


def live(rng, green=RYE, yellow=0.3, tip_from=(0.55, 1.05)):
    """The colour along a living blade: a pale sheath, green, and maybe a
    tip that has bleached."""
    colour = mix(mix(green, BLUE_GREEN, rng.random() * 0.5), YELLOW_GREEN, rng.random() * yellow)
    colour = darker(colour, rng.random() * 0.2)
    tip = rng.uniform(*tip_from)
    return lambda t: mix(mix(SHEATH, colour, min(1.0, t * 6.0)), STRAW, max(0.0, (t - tip) / (1.02 - tip)) if tip < 1.0 else 0.0)


def dead(rng, grey=0.6):
    """The colour of a blade that has dried: straw, paler or greyer."""
    straw = mix(mix(STRAW, PALE, rng.random()), GREY_STRAW, rng.random() * grey)
    return lambda t: mix(straw, darker(straw, 0.35), 0.4 * (1.0 - t))


def spread(rng, reach):
    return rng.uniform(-1.0, 1.0) * reach * (0.35 + 0.65 * rng.random() ** 0.6)


# --- The meadow -------------------------------------------------------------


def sward(plant, blades, high, reach, colour, droop=(0.0, 0.7), width=(0.0025, 0.0045), steps=8, clumps=1):
    """The fine grass of a meadow, blades of a hand high or so, from feet
    gathered in `clumps` round domes over the cell: thick in the middle of
    each and lower and thinner to its rim, so that a card has no edge."""
    rng = plant.rng
    half = plant.wide * reach
    for _ in range(blades):
        if clumps == 1:
            centre, sigma = 0.0, half * 0.42
        else:
            centre = (rng.randrange(clumps) - (clumps - 1) * 0.5) * half * 2.0 / clumps
            sigma = half / clumps * 0.75
        x = max(-half, min(half, rng.gauss(centre, sigma)))
        out = (x - centre) / (sigma * 2.4)
        dome = max(0.25, 1.0 - 0.35 * out * out) * (1.0 - 0.7 * (x / half) ** 4)
        plant.middle = x
        plant.blade(high * dome * rng.uniform(0.35, 1.0), rng.uniform(*width), spread(rng, 0.06) + out * 0.03, colour(rng), steps=steps, droop=rng.uniform(*droop), spread=0.01, depth=0.12)
    plant.middle = 0.0


def clover(plant, count, reach):
    """White clover: three round leaflets on a stalk, held level a few
    centimetres up; one or two going yellow."""
    rng = plant.rng
    for _ in range(count):
        x = rng.uniform(-1.0, 1.0) * plant.wide * reach
        y = rng.uniform(-0.1, 0.1)
        high = rng.uniform(0.03, 0.09)
        colour = mix(CLOVER, YELLOW_GREEN, rng.random() * 0.3) if rng.random() < 0.85 else mix(YELLOW_GREEN, STRAW, 0.5)
        plant.stem([(x, y, -0.01), (x + rng.uniform(-0.01, 0.01), y, high * 0.6), (x + rng.uniform(-0.015, 0.015), y, high)], 0.0012, SHEATH, sides=3)
        turn = rng.uniform(0.0, math.tau)
        for leaflet in range(3):
            a = turn + leaflet * math.tau / 3.0
            way = (math.cos(a), math.sin(a), rng.uniform(-0.15, 0.35))
            plant.leaf((x, y, high), way, rng.uniform(0.011, 0.016), rng.uniform(0.011, 0.015), colour, curl=0.1, steps=4)


def ribwort(plant, count, reach, colour=PLANTAIN):
    """Ribwort plantain and dandelion: a rosette of long leaves lying out of
    one foot, and the odd stalk with a dark head on it."""
    rng = plant.rng
    for _ in range(count):
        x = rng.uniform(-1.0, 1.0) * plant.wide * reach
        y = rng.uniform(-0.08, 0.08)
        for _ in range(rng.randint(5, 8)):
            a = rng.uniform(0.0, math.tau)
            way = (math.cos(a), math.sin(a), rng.uniform(0.6, 1.6))
            tone = mix(colour, YELLOW_GREEN, rng.random() * 0.4) if rng.random() < 0.8 else mix(colour, STRAW, 0.6)
            plant.leaf((x, y, 0.0), way, rng.uniform(0.07, 0.15), rng.uniform(0.012, 0.022), tone, curl=0.6, steps=6)
        for _ in range(rng.randint(0, 2)):
            high = rng.uniform(0.12, 0.26)
            lean = rng.uniform(-0.04, 0.04)
            top = (x + lean, y, high)
            if plant.stem([(x, y, 0.0), (x + lean * 0.5, y, high * 0.5), top], 0.0011, SHEATH, sides=3):
                plant.blob(top, 0.007, SPIKE_BROWN, long=2.6)


def patch(plant, blades, high, colour, width=(0.0025, 0.0045), steps=8, droop=(0.0, 0.7)):
    """The fine grass of a meadow over a round patch of ground, for a picture
    from above: thick in the middle and thinner to the rim."""
    rng = plant.rng
    rim = plant.wide * 0.46
    for _ in range(blades):
        r = rim * math.sqrt(rng.random()) ** 1.3
        a = rng.uniform(0.0, math.tau)
        x = r * math.cos(a)
        y = r * math.sin(a)
        dome = 1.0 - 0.5 * (r / rim) ** 2
        plant.middle = 0.0
        first = len(plant.points)
        faces = len(plant.faces)
        if not plant.blade(high * dome * rng.uniform(0.35, 1.0), rng.uniform(*width), spread(rng, 0.05), colour(rng), steps=steps, droop=rng.uniform(*droop), spread=0.004, depth=0.0):
            continue
        # Grown at the middle of the cell: moved to its own spot on the
        # patch, and turned to lean any way.
        turn = rng.uniform(0.0, math.tau)
        c, n = math.cos(turn), math.sin(turn)
        for i in range(first, len(plant.points)):
            px, py, pz = plant.points[i]
            plant.points[i] = (x + px * c - py * n, y + px * n + py * c, pz)
        plant._keep(first, faces)
    plant.middle = 0.0


def top(plant, cell):
    """The mown meadow from above, for a card that lies in the grass: thicker
    than a tuft from the side, as from above one sees through more of it."""
    green = lambda r: live(r, RYE if r.random() < 0.6 else MEADOW, 0.25, (0.85, 1.7))
    arched = (0.3, 1.4)
    wide = (0.003, 0.006)
    if cell == 0:
        patch(plant, 3400, 0.17, green, width=wide, droop=arched)
    elif cell == 1:
        patch(plant, 2600, 0.15, green, width=wide, droop=arched)
        clover(plant, 70, 0.44)
    elif cell == 2:
        patch(plant, 2400, 0.15, lambda r: live(r, MEADOW, 0.8, (0.35, 0.9)) if r.random() < 0.7 else dead(r), width=wide, droop=arched)
        patch(plant, 500, 0.2, dead, width=wide, droop=(0.8, 1.8))
    else:
        patch(plant, 2500, 0.15, green, width=wide, droop=arched)
        ribwort(plant, 5, 0.35)


def mown(plant, cell):
    """The aftermath, a hand high and even: blades that stand rather than
    arch, in a few low clumps side by side, so that cards over each other make
    one sward and not a heap of tufts."""
    green = lambda r: live(r, RYE if r.random() < 0.6 else MEADOW, 0.25, (0.85, 1.7))
    stand = (0.0, 0.35)
    if cell == 0:
        # Thick and green, the odd tip gone pale.
        sward(plant, 1000, 0.15, 0.44, green, droop=stand, clumps=3)
        sward(plant, 120, 0.2, 0.36, lambda r: live(r, MEADOW, 0.4, (0.6, 1.2)), droop=stand, clumps=2)
    elif cell == 1:
        # Grass and white clover under it.
        sward(plant, 760, 0.14, 0.44, green, droop=stand, clumps=3)
        clover(plant, 26, 0.4)
    elif cell == 2:
        # Some of it gone yellow, with dead blades lying in it.
        sward(plant, 620, 0.14, 0.44, lambda r: live(r, MEADOW, 0.7, (0.45, 1.1)) if r.random() < 0.65 else dead(r), droop=stand, clumps=3)
        sward(plant, 120, 0.16, 0.42, dead, droop=(0.8, 1.6), clumps=2)
    else:
        # Ribwort and dandelion leaves, and a few stalks of ribwort in seed.
        sward(plant, 700, 0.14, 0.44, green, droop=stand, clumps=3)
        ribwort(plant, 3, 0.3)


def panicle(plant, top, way, length, colour, branches=7, spikelet=0.0045, droop=0.4):
    """A loose panicle as oat grass and Yorkshire fog have it: a main axis
    with whorls of fine branches, a spikelet at the end of each."""
    rng = plant.rng
    way = np.array(way, dtype=float)
    way /= max(np.linalg.norm(way), 1e-9)
    axis = [np.array(top)]
    for i in range(1, 6):
        axis.append(axis[-1] + (way + np.array([0.0, 0.0, -droop * 0.1 * i])) * length / 5.0)
    plant.stem([tuple(p) for p in axis], 0.0008, colour, sides=3)
    for b in range(branches):
        t = (b + 0.5) / branches
        foot = axis[0] + (axis[-1] - axis[0]) * t
        a = rng.uniform(0.0, math.tau)
        out = np.array([math.cos(a), math.sin(a) * 0.6, 0.0])
        long = length * 0.45 * (1.0 - t * 0.6)
        end = foot + out * long + way * long * 0.6 + np.array([0.0, 0.0, -droop * long * 0.5])
        if plant.stem([tuple(foot), tuple((foot + end) * 0.5 + way * 0.004), tuple(end)], 0.0005, colour, sides=3):
            for s in range(rng.randint(1, 3)):
                at = foot + (end - foot) * (1.0 - s * 0.22)
                plant.blob(tuple(at), spikelet * rng.uniform(0.8, 1.2), mix(darker(colour, 0.15), PALE, rng.random() * 0.3), long=3.2, way=tuple(end - foot + way * long))


def cocksfoot(plant, top, way, colour):
    """Cocksfoot in seed: clusters of spikelets packed at the ends of a few
    stiff branches, one-sided."""
    rng = plant.rng
    way = np.array(way, dtype=float)
    way /= max(np.linalg.norm(way), 1e-9)
    for b in range(rng.randint(3, 5)):
        foot = np.array(top) + way * b * 0.012
        side = 1.0 if b % 2 else -1.0
        long = rng.uniform(0.015, 0.05) * (1.0 - b * 0.15)
        end = foot + np.array([side * long, rng.uniform(-0.01, 0.01), long * 0.4])
        plant.stem([tuple(foot), tuple(end)], 0.0007, colour, sides=3)
        for _ in range(rng.randint(5, 9)):
            at = end + np.array([rng.gauss(0, 0.005), rng.gauss(0, 0.005), rng.gauss(0, 0.006)])
            plant.blob(tuple(at), 0.0045, mix(darker(colour, 0.2), PANICLE, rng.random() * 0.3), long=2.2, way=(side * 0.5, 0.0, 1.0))


def timothy(plant, top, way, colour):
    """A spike of timothy: a dense cylinder a few centimetres long."""
    rng = plant.rng
    way = np.array(way, dtype=float)
    way /= max(np.linalg.norm(way), 1e-9)
    long = rng.uniform(0.05, 0.1)
    rings = 9
    for i in range(rings):
        at = np.array(top) + way * long * (i + 0.5) / rings
        for s in range(3):
            a = math.tau * s / 3.0 + i
            plant.blob(tuple(at + np.array([math.cos(a), math.sin(a), 0.0]) * 0.002), 0.0045, mix(colour, GREY_STRAW, rng.random() * 0.4), long=1.4, way=tuple(way))


def seed_stalk(plant, height, lean, colour, head):
    """A flowering stalk of last summer, dry, with its head."""
    if not plant.blade(height, 0.0028, lean, colour, steps=12, fold=0.5, spread=0.03, taper=0.9):
        return
    top, way = plant.tip()
    head(top, way)


def long_grass(plant, cell):
    rng = plant.rng
    w = plant.wide

    def stalks(count, high, heads):
        for _ in range(count):
            plant.middle = rng.uniform(-0.16, 0.16) * w
            head = rng.choice(heads)
            straw = dead(rng, 0.4)
            seed_stalk(plant, high * rng.uniform(0.7, 1.0), spread(rng, 0.12), straw, lambda top, way, h=head, s=straw: h(top, way, s(1.0)))
        plant.middle = 0.0

    loose = lambda top, way, c: panicle(plant, top, way, rng.uniform(0.07, 0.13), c, droop=0.6)
    fog = lambda top, way, c: panicle(plant, top, way, rng.uniform(0.05, 0.09), mix(c, PANICLE, 0.5), branches=9, spikelet=0.004, droop=0.2)
    foot = lambda top, way, c: cocksfoot(plant, top, way, c)
    spike = lambda top, way, c: timothy(plant, top, way, c)
    if cell == 0:
        # Green below, straw above, gone to seed.
        sward(plant, 340, 0.36, 0.32, lambda r: live(r, MEADOW, 0.5, (0.45, 0.9)) if r.random() < 0.6 else dead(r), droop=(0.2, 1.0), width=(0.003, 0.006), steps=10)
        sward(plant, 160, 0.55, 0.26, dead, droop=(0.4, 1.4), width=(0.003, 0.005), steps=12)
        stalks(26, 0.8, [loose, fog, foot])
    elif cell == 1:
        # Lodged: most of it straw, beaten down by rain.
        sward(plant, 300, 0.45, 0.36, lambda r: dead(r) if r.random() < 0.75 else live(r, MEADOW, 0.8, (0.3, 0.7)), droop=(0.8, 2.0), width=(0.003, 0.006), steps=12)
        for _ in range(60):
            plant.middle = rng.uniform(-0.2, 0.2) * w
            plant.blade(rng.uniform(0.3, 0.6), 0.0035, spread(rng, 0.25), dead(rng), steps=12, droop=rng.uniform(0.8, 1.8), lie=rng.uniform(0.4, 1.0))
        plant.middle = 0.0
        stalks(12, 0.6, [loose, foot])
    elif cell == 2:
        # A tussock of cocksfoot, greener, its heads clustered.
        sward(plant, 300, 0.48, 0.24, lambda r: live(r, BLUE_GREEN, 0.4, (0.6, 1.1)) if r.random() < 0.7 else dead(r), droop=(0.3, 1.2), width=(0.005, 0.009), steps=12)
        sward(plant, 120, 0.25, 0.36, lambda r: live(r, MEADOW, 0.5), droop=(0.2, 0.8))
        stalks(18, 0.85, [foot, foot, loose])
    else:
        # Thinner, timothy spikes standing over it.
        sward(plant, 260, 0.32, 0.34, lambda r: live(r, MEADOW, 0.6, (0.4, 0.9)) if r.random() < 0.55 else dead(r), droop=(0.2, 1.0), width=(0.003, 0.005), steps=10)
        stalks(22, 0.85, [spike, spike, fog])


def sedge(plant, high, blades, colour, spikes):
    """A tussock of sedge: stiff, keeled blades arching out of one foot, and
    three-cornered stalks with dark spikes."""
    rng = plant.rng
    for _ in range(blades):
        out = rng.uniform(-1.0, 1.0)
        out = math.copysign(abs(out) ** 0.8, out)
        long = high * rng.uniform(0.55, 1.0) * (1.0 - 0.3 * abs(out))
        plant.blade(long, rng.uniform(0.004, 0.0075), out * 0.45 * long, colour(rng), steps=12, droop=abs(out) * rng.uniform(0.3, 1.1), fold=0.6, spread=0.025)
    for _ in range(spikes):
        if plant.blade(high * rng.uniform(0.8, 1.1), 0.0022, spread(rng, 0.08), lambda t: mix(SEDGE, SEDGE_AUTUMN, t), steps=10, fold=0.2, spread=0.02, taper=0.95):
            top, way = plant.tip()
            for s in range(rng.randint(2, 4)):
                at = np.array(top) - np.array(way) * s * 0.025
                plant.blob(tuple(at), 0.006, SPIKE_BROWN, long=4.0, way=way)


def rush(plant, stems, high):
    """Soft rush: a dense clump of round, dark green stems, a brown tuft of
    flowers sticking out of one side near the top; the old stems gone tawny
    and bent."""
    rng = plant.rng
    for _ in range(stems):
        x = rng.gauss(0.0, 0.03)
        y = rng.gauss(0.0, 0.03)
        lean = rng.uniform(-0.3, 0.3)
        long = high * rng.uniform(0.6, 1.0)
        old = rng.random() < 0.25
        bend = rng.uniform(0.0, 0.4) + (0.6 if old else 0.0)
        points = []
        for i in range(7):
            t = i / 6
            points.append((x + math.sin(lean + bend * t * t) * long * t, y, math.cos(lean * 0.5 + bend * t * t * 0.8) * long * t))
        colour = (lambda t: mix(RUSH_DEAD, PALE, t * 0.4)) if old else (lambda t: mix(darker(RUSH, 0.1), mix(RUSH, YELLOW_GREEN, 0.2), t) if t < 0.92 else mix(RUSH, STRAW, 0.8))
        if plant.stem(points, 0.0018, colour, sides=4) and not old and rng.random() < 0.5:
            at = np.array(points[4]) + np.array([0.004 * (1 if lean > 0 else -1), 0.0, 0.0])
            for _ in range(rng.randint(5, 9)):
                plant.blob(tuple(at + np.array([rng.gauss(0, 0.006), rng.gauss(0, 0.004), rng.gauss(0, 0.01)])), 0.004, mix(RUSH_DEAD, SPIKE_BROWN, rng.random()), long=1.6)


def moor_grass(plant, blades, stalks, high):
    """Purple moor grass in October: leaves and stalks gone gold and tawny,
    the stalks long and bare, a narrow dark panicle at the top."""
    rng = plant.rng
    autumn = lambda r: (lambda t, c=mix(mix(TAWNY, GOLD, r.random()), STRAW, r.random() * 0.4): mix(darker(c, 0.3), c, min(1.0, t * 3.0)))
    for _ in range(blades):
        out = rng.uniform(-1.0, 1.0)
        long = high * 0.5 * rng.uniform(0.5, 1.0)
        plant.blade(long, rng.uniform(0.003, 0.0055), out * 0.4 * long, autumn(rng), steps=10, droop=abs(out) * rng.uniform(0.4, 1.4), spread=0.03)
    for _ in range(stalks):
        tone = mix(GOLD, PALE, rng.random() * 0.5)
        if plant.blade(high * rng.uniform(0.75, 1.0), 0.0018, spread(rng, 0.14), lambda t, c=tone: c, steps=12, fold=0.2, spread=0.03, taper=0.95):
            top, way = plant.tip()
            panicle(plant, top, way, rng.uniform(0.06, 0.12), PANICLE, branches=6, spikelet=0.0045, droop=0.05)


def wet(plant, cell):
    rng = plant.rng
    autumn_sedge = lambda r: (lambda t, c=mix(SEDGE, SEDGE_AUTUMN, r.random() ** 1.5): mix(darker(c, 0.25), c, min(1.0, t * 4.0)))
    if cell == 0:
        sedge(plant, 0.62, 360, autumn_sedge, 10)
    elif cell == 1:
        rush(plant, 170, 0.8)
        sward(plant, 80, 0.25, 0.3, lambda r: dead(r) if r.random() < 0.5 else live(r, BLUE_GREEN, 0.4), droop=(0.4, 1.4))
    elif cell == 2:
        moor_grass(plant, 260, 30, 0.85)
    else:
        # Mixed: sedge, a little moor grass and dead stalks.
        sedge(plant, 0.5, 200, autumn_sedge, 6)
        plant.middle = 0.08
        moor_grass(plant, 90, 10, 0.75)
        plant.middle = -0.1
        rush(plant, 40, 0.65)
        plant.middle = 0.0


def far(plant, cell):
    """A band of each kind, denser and with thicker blades than up close:
    from afar a card stands for many tufts, and thin blades would fall out
    of it where the picture is made smaller. It is clumps side by side,
    thinning out to its two ends, so that cards that overlap do not show
    where one ends."""
    rng = plant.rng
    if cell == 0:
        sward(plant, 1300, 0.21, 0.48, lambda r: live(r, RYE if r.random() < 0.6 else MEADOW, 0.3, (0.85, 1.6)), width=(0.006, 0.01), steps=6, clumps=5)
    elif cell == 1:
        sward(plant, 700, 0.42, 0.46, lambda r: live(r, MEADOW, 0.5, (0.45, 0.9)) if r.random() < 0.5 else dead(r), droop=(0.2, 1.2), width=(0.007, 0.012), steps=8, clumps=4)
        sward(plant, 300, 0.58, 0.4, dead, droop=(0.4, 1.2), width=(0.006, 0.01), steps=8, clumps=3)
    elif cell == 2:
        for i in range(4):
            plant.middle = (i - 1.5) * plant.wide * 0.21
            sedge(plant, 0.5 * (1.0 - 0.25 * abs(i - 1.5) / 1.5), 130, lambda r: (lambda t, c=mix(SEDGE, SEDGE_AUTUMN, r.random()): c), 0)
        plant.middle = 0.0
        sward(plant, 220, 0.5, 0.42, lambda r: (lambda t, c=mix(TAWNY, GOLD, r.random()): c), droop=(0.3, 1.0), width=(0.006, 0.01), clumps=4)
    else:
        # Sparse, trampled: a few short blades and bare ground between.
        sward(plant, 420, 0.12, 0.48, lambda r: live(r, MEADOW, 0.6, (0.4, 1.0)) if r.random() < 0.7 else dead(r), width=(0.006, 0.01), steps=6, droop=(0.3, 1.2), clumps=6)


# --- Flowers and herbs ------------------------------------------------------

LILAC = (0.46, 0.25, 0.6)
LILAC_PALE = (0.62, 0.48, 0.72)
TUBE = (0.7, 0.66, 0.62)
KNAPWEED = (0.33, 0.06, 0.32)
BRACT = (0.16, 0.1, 0.05)
YARROW = (0.75, 0.73, 0.66)
YARROW_OLD = (0.42, 0.36, 0.26)
STEM = (0.09, 0.13, 0.04)
PAPPUS = (0.8, 0.8, 0.78)


def crocus_flower(plant, x, y, high, open_, lean, colour):
    """One autumn crocus: a white tube out of the bare ground and a goblet
    of six tepals on it, pale lilac; no leaf, which comes in spring."""
    rng = plant.rng
    bend = rng.uniform(-0.25, 0.25)
    points = []
    for i in range(6):
        t = i / 5
        points.append((x + math.sin(lean + bend * t) * high * t, y, math.cos(lean + bend * t) * high * t))
    if not plant.stem(points, 0.0028, lambda t: mix(TUBE, mix(TUBE, colour, 0.4), t), sides=5):
        return
    top = np.array(points[-1])
    way = top - np.array(points[-2])
    way /= np.linalg.norm(way)
    turn = rng.uniform(0.0, math.tau)
    for k in range(6):
        a = turn + k * math.tau / 6
        out = np.array([math.cos(a), math.sin(a), 0.0])
        tepal = way * 1.0 + out * open_
        tone = mix(colour, LILAC_PALE, rng.random() * 0.4) if k % 2 else darker(colour, rng.random() * 0.15)
        plant.leaf(tuple(top - way * 0.004), tuple(tepal), rng.uniform(0.035, 0.05), rng.uniform(0.012, 0.017), tone, curl=-0.15 * open_, steps=5)


def crocus(plant, cell):
    rng = plant.rng
    counts = (1, 3, 2, 4)[cell]
    for i in range(counts):
        x = (i - (counts - 1) * 0.5) * 0.025 + rng.gauss(0.0, 0.006)
        flopped = cell == 3 and i == 0
        crocus_flower(plant, x, rng.uniform(-0.02, 0.02), rng.uniform(0.05, 0.1), rng.uniform(0.2, 0.55), rng.uniform(-0.2, 0.2) + (1.1 if flopped else 0.0), mix(LILAC, LILAC_PALE, rng.random() * 0.5))


def knapweed_head(plant, top, gone):
    rng = plant.rng
    plant.blob(top, 0.011, BRACT, long=1.1, sides=7)
    if gone:
        # Gone over: a brown brush of old florets.
        for _ in range(14):
            a = rng.uniform(0.0, math.tau)
            out = np.array([math.cos(a) * 0.4, math.sin(a) * 0.4, 1.0])
            plant.stem([tuple(np.array(top)), tuple(np.array(top) + out * 0.009)], 0.0008, mix(BRACT, STRAW, 0.5), sides=3)
        return
    for _ in range(26):
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(0.0, 1.0)
        out = np.array([math.cos(a) * r, math.sin(a) * r, 0.6 + 0.4 * (1.0 - r)])
        end = np.array(top) + np.array([0, 0, 0.004]) + out * rng.uniform(0.01, 0.016)
        plant.stem([tuple(np.array(top) + np.array([0, 0, 0.004])), tuple(end)], 0.0009, mix(KNAPWEED, (0.5, 0.12, 0.45), rng.random()), sides=3)


def knapweed(plant, cell):
    """Brown knapweed: a branched stem, narrow leaves, heads of purple
    florets on brown bracts, by October half of them gone over."""
    rng = plant.rng
    for stalk in range(2 + cell):
        x = rng.gauss(0.0, 0.03)
        high = rng.uniform(0.3, 0.48)
        lean = rng.uniform(-0.15, 0.15)
        points = [(x + math.sin(lean) * high * i / 6, rng.uniform(-0.01, 0.01), high * i / 6) for i in range(7)]
        if not plant.stem(points, 0.0018, lambda t: mix(STEM, BRACT, t * 0.5), sides=4):
            continue
        for i in range(2, 6):
            side = 1.0 if i % 2 else -1.0
            plant.leaf(points[i], (side, rng.uniform(-0.3, 0.3), 1.2), rng.uniform(0.04, 0.07), rng.uniform(0.006, 0.01), mix(STEM, STRAW, rng.random() * 0.5), curl=0.4, steps=4)
        top = np.array(points[-1])
        knapweed_head(plant, tuple(top), rng.random() < 0.45)
        for b in range(rng.randint(1, 3)):
            foot = np.array(points[3 + b])
            end = foot + np.array([rng.uniform(-0.07, 0.07), rng.uniform(-0.02, 0.02), rng.uniform(0.06, 0.12)])
            if plant.stem([tuple(foot), tuple((foot + end) * 0.5 + np.array([0, 0, 0.01])), tuple(end)], 0.0012, STEM, sides=3):
                knapweed_head(plant, tuple(end), rng.random() < 0.5)


def yarrow(plant, cell):
    """Yarrow: stiff stems with feathery leaves and a flat head of small
    white flowers, gone brownish by October."""
    rng = plant.rng
    for stalk in range(2 + cell):
        x = rng.gauss(0.0, 0.035)
        high = rng.uniform(0.22, 0.42)
        lean = rng.uniform(-0.12, 0.12)
        points = [(x + math.sin(lean) * high * i / 6, rng.uniform(-0.01, 0.01), high * i / 6) for i in range(7)]
        if not plant.stem(points, 0.0016, STEM, sides=4):
            continue
        for i in range(1, 5):
            side = 1.0 if i % 2 else -1.0
            way = np.array([side, rng.uniform(-0.3, 0.3), 0.9])
            foot = np.array(points[i])
            # A feathery leaf: a midrib with fine pinnae.
            end = foot + way / np.linalg.norm(way) * rng.uniform(0.04, 0.07)
            plant.stem([tuple(foot), tuple(end)], 0.0007, STEM, sides=3)
            for k in range(7):
                at = foot + (end - foot) * (k + 1) / 8
                for sgn in (-1.0, 1.0):
                    plant.stem([tuple(at), tuple(at + np.array([0, sgn * 0.006, 0.004]))], 0.0005, mix(STEM, BLUE_GREEN, 0.5), sides=3)
        top = np.array(points[-1])
        old = rng.random() < 0.4
        for _ in range(rng.randint(22, 36)):
            a = rng.uniform(0.0, math.tau)
            r = math.sqrt(rng.random()) * 0.03
            end = top + np.array([math.cos(a) * r, math.sin(a) * r, 0.012 - r * 0.25])
            plant.stem([tuple(top), tuple(end)], 0.0005, STEM, sides=3)
            plant.blob(tuple(end + np.array([0, 0, 0.002])), 0.0042, mix(YARROW, YARROW_OLD, rng.random() * (0.9 if old else 0.25)), long=0.7, sides=5)


def puff(plant, cell):
    """Dandelion clocks: a hollow stalk and a ball of seeds, each with its
    tuft of white hairs."""
    rng = plant.rng
    for i in range(1 + cell % 2):
        x = (i - 0.5 * (cell % 2)) * 0.05 + rng.gauss(0.0, 0.01)
        high = rng.uniform(0.12, 0.22)
        lean = rng.uniform(-0.15, 0.15)
        points = [(x + math.sin(lean) * high * k / 5, 0.0, high * k / 5) for k in range(6)]
        if not plant.stem(points, 0.0016, lambda t: mix((0.3, 0.32, 0.18), (0.22, 0.2, 0.12), t), sides=5):
            continue
        centre = np.array(points[-1])
        torn = cell >= 2
        for k in range(160):
            z = rng.uniform(-1.0, 1.0)
            a = rng.uniform(0.0, math.tau)
            out = np.array([math.sqrt(1 - z * z) * math.cos(a), math.sqrt(1 - z * z) * math.sin(a), z])
            if torn and out[0] > 0.2:
                continue
            end = centre + out * 0.019
            plant.stem([tuple(centre), tuple(end)], 0.00025, (0.55, 0.52, 0.45), sides=3)
            plant.blob(tuple(end), 0.0045, PAPPUS, long=0.25, way=tuple(out), sides=6)


# --- The floor of the wood ----------------------------------------------------

BILBERRY_RED = (0.42, 0.04, 0.025)
BILBERRY_ORANGE = (0.55, 0.17, 0.02)
BILBERRY_YELLOW = (0.5, 0.33, 0.04)
BILBERRY_GREEN = (0.08, 0.17, 0.03)
BILBERRY_STEM = (0.07, 0.14, 0.04)
BERRY = (0.025, 0.03, 0.07)
SPRUCE_GREEN = (0.03, 0.07, 0.025)


def bilberry(plant, cell):
    """Bilberry in October: green angular stems branching upward, the leaves
    red and orange and yellow, a few still green, the odd berry left."""
    rng = plant.rng
    palette = [BILBERRY_RED, BILBERRY_ORANGE, BILBERRY_YELLOW, BILBERRY_GREEN]
    weights = [(0.5, 0.3, 0.1, 0.1), (0.2, 0.45, 0.25, 0.1), (0.1, 0.25, 0.45, 0.2), (0.3, 0.3, 0.15, 0.25)][cell]

    def leaf_colour():
        r = rng.random()
        for colour, w in zip(palette, weights):
            if r < w:
                return mix(colour, darker(colour, 0.3), rng.random() * 0.6)
            r -= w
        return palette[-1]

    def branch(foot, way, length, depth):
        steps = 4
        points = [np.array(foot)]
        heading = np.array(way, dtype=float)
        for k in range(steps):
            heading = heading + np.array([rng.gauss(0, 0.25), rng.gauss(0, 0.15), 0.15])
            heading /= np.linalg.norm(heading)
            points.append(points[-1] + heading * length / steps)
        if not plant.stem([tuple(p) for p in points], 0.0016 * (1.0 - depth * 0.3), BILBERRY_STEM, sides=4):
            return
        for k in range(1, steps + 1):
            for _ in range(2):
                a = rng.uniform(0.0, math.tau)
                plant.leaf(tuple(points[k]), (math.cos(a), math.sin(a), rng.uniform(0.2, 0.9)), rng.uniform(0.014, 0.024), rng.uniform(0.009, 0.014), leaf_colour(), curl=0.3, steps=4)
            if depth < 2 and rng.random() < 0.55:
                a = rng.uniform(0.0, math.tau)
                branch(points[k], (math.cos(a) * 0.8, math.sin(a) * 0.5, 0.7), length * 0.55, depth + 1)
        if rng.random() < 0.15:
            plant.blob(tuple(points[-1] + np.array([0, 0, -0.006])), 0.008, BERRY, long=1.0, sides=7)

    for _ in range(9 + cell * 2):
        x = rng.gauss(0.0, 0.07)
        y = rng.gauss(0.0, 0.06)
        branch((x, y, -0.005), (rng.uniform(-0.4, 0.4), rng.uniform(-0.2, 0.2), 1.0), rng.uniform(0.12, 0.3), 0)


def seedling(plant, cell):
    """A spruce seedling of a few years: a leader and whorls of shoots, each
    a brush of short needles."""
    rng = plant.rng
    high = (0.14, 0.24, 0.34, 0.45)[cell]
    whorls = 2 + cell
    lean = rng.uniform(-0.08, 0.08)

    def shoot(foot, way, length):
        way = np.array(way, dtype=float)
        way /= np.linalg.norm(way)
        end = np.array(foot) + way * length
        plant.stem([tuple(foot), tuple(end)], 0.0012, (0.2, 0.14, 0.08), sides=3)
        for k in range(int(length / 0.004)):
            at = np.array(foot) + way * length * (k + 0.5) / int(length / 0.004)
            a = rng.uniform(0.0, math.tau)
            out = np.array([math.cos(a), math.sin(a), 0.6]) + way * 0.8
            out /= np.linalg.norm(out)
            plant.stem([tuple(at), tuple(at + out * rng.uniform(0.01, 0.016))], 0.0006, mix(SPRUCE_GREEN, (0.07, 0.12, 0.05), rng.random()), sides=3)

    shoot((0.0, 0.0, -0.005), (lean, 0.0, 1.0), high)
    for w in range(whorls):
        z = high * (0.25 + 0.6 * w / max(1, whorls - 1))
        reach = (high - z) * 0.55 + 0.03
        turn = rng.uniform(0.0, math.tau)
        for k in range(4):
            a = turn + k * math.tau / 4
            shoot((lean * z, 0.0, z), (math.cos(a), math.sin(a), 0.25), reach)


class Model:
    """A cell made of a model from Poly Haven instead of a grown plant: the
    objects of `nodes` in its file, standing at the origin, their colour
    turned towards `autumn` by so much, and `scatter` copies of them strewn
    over a cushion of that radius if it is set."""

    def __init__(self, path, nodes, autumn=None, amount=0.0, scatter=0, radius=0.2, scale=1.0):
        self.path = path
        self.nodes = nodes
        self.autumn = autumn
        self.amount = amount
        self.scatter = scatter
        self.radius = radius
        self.scale = scale

    def place(self, scene, seed):
        rng = random.Random(seed)
        bpy.ops.import_scene.gltf(filepath=os.path.join(HERE, "..", self.path))
        kept = [o for o in scene.objects if o.type == "MESH" and any(o.name.startswith(n) for n in self.nodes)]
        for o in list(scene.objects):
            if o.type == "MESH" and o not in kept:
                bpy.data.objects.remove(o)
        for o in kept:
            o.parent = None
            if self.autumn:
                for slot in o.material_slots:
                    recolour(slot.material, self.autumn, self.amount)
        if self.scatter:
            # A cushion: the sprigs strewn over a dome, thick in the middle.
            sources = kept
            for k in range(self.scatter):
                src = rng.choice(sources)
                r = self.radius * math.sqrt(rng.random())
                a = rng.uniform(0.0, math.tau)
                copy = bpy.data.objects.new(src.name + "_%d" % k, src.data)
                scene.collection.objects.link(copy)
                lift = (1.0 - (r / self.radius) ** 2) * self.radius * 0.35
                copy.location = (r * math.cos(a), r * math.sin(a), lift - 0.01)
                copy.rotation_euler = (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), rng.uniform(0.0, math.tau))
                s = self.scale * rng.uniform(0.8, 1.3)
                copy.scale = (s, s, s)
            for o in kept:
                bpy.data.objects.remove(o)
        else:
            for o in kept:
                o.location = (0.0, 0.0, 0.0)
                o.scale = tuple(v * self.scale for v in o.scale)
        bpy.context.view_layer.update()
        corners = []
        for o in scene.objects:
            if o.type == "MESH":
                corners += [o.matrix_world @ v.co for v in o.data.vertices]
        return np.array([tuple(c) for c in corners])


def recolour(material, target, amount):
    """The colour of a model's material turned towards `target`, keeping how
    light and dark it is: green leaves gone gold or brown."""
    if material is None or material.get("recoloured"):
        return
    material["recoloured"] = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None or not bsdf.inputs["Base Color"].links:
        return
    source = bsdf.inputs["Base Color"].links[0].from_socket
    grey = nodes.new("ShaderNodeRGBToBW")
    links.new(source, grey.inputs[0])
    tint = nodes.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    tint.blend_type = "MULTIPLY"
    tint.inputs["Factor"].default_value = 1.0
    links.new(grey.outputs[0], tint.inputs[6])
    tint.inputs[7].default_value = tuple(v * 2.6 for v in target) + (1.0,)
    blend = nodes.new("ShaderNodeMix")
    blend.data_type = "RGBA"
    blend.inputs["Factor"].default_value = amount
    links.new(source, blend.inputs[6])
    links.new(tint.outputs[2], blend.inputs[7])
    links.new(blend.outputs[2], bsdf.inputs["Base Color"])


def facing_with_holes(material, plan):
    """facing_material(), with the holes of a model's own material."""
    facing = facing_material(plan)
    if material is None:
        return facing
    bsdf = next((n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None or not bsdf.inputs["Alpha"].links:
        return facing
    alpha_from = bsdf.inputs["Alpha"].links[0].from_node
    nodes = facing.node_tree.nodes
    links = facing.node_tree.links
    image = nodes.new("ShaderNodeTexImage")
    image.image = alpha_from.image
    uv = nodes.new("ShaderNodeTexCoord")
    links.new(uv.outputs["UV"], image.inputs["Vector"])
    out = next(n for n in nodes if n.type == "OUTPUT_MATERIAL")
    glow = next(n for n in nodes if n.type == "EMISSION")
    clear = nodes.new("ShaderNodeBsdfTransparent")
    both = nodes.new("ShaderNodeMixShader")
    links.new(image.outputs["Alpha"], both.inputs[0])
    links.new(clear.outputs[0], both.inputs[1])
    links.new(glow.outputs[0], both.inputs[2])
    links.new(both.outputs[0], out.inputs["Surface"])
    return facing


FERN = "assets/models/fern_02/fern_02_1k.gltf"
SORREL = "assets/models/shrub_sorrel_01/shrub_sorrel_01_2k.gltf"
NETTLE = "assets/models/nettle_plant/nettle_plant_2k.gltf"
DANDELION = "assets/models/dandelion_01/dandelion_01_2k.gltf"
MOSS = "assets/models/moss_01/moss_01_2k.gltf"


# Every sheet: how large it is, and its cells, each where it lies on the
# sheet in dots (x, y, wide, high), how many metres wide it shows (its
# height follows), what grows in it, which of its kind, `foot` as in Plant,
# and whether it is seen from above.
SHEETS = {
    "meadow": {
        "size": (2048, 2560),
        "cells": (
            [("mown%d" % i, (i * 512, 0, 512, 256), 0.6144, mown, i, 0.5, False) for i in range(4)]
            + [("top%d" % i, (i * 512, 256, 512, 512), 0.6144, top, i, 0.5, True) for i in range(4)]
            + [("long%d" % i, (i * 512, 768, 512, 768), 0.6144, long_grass, i, 0.32, False) for i in range(4)]
            + [("wet%d" % i, (i * 512, 1536, 512, 768), 0.6144, wet, i, 0.3, False) for i in range(4)]
            + [("far%d" % i, (i * 512, 2304, 512, 256), 1.2288, far, i, 0.5, False) for i in range(4)]
        ),
    },
    "herbs": {
        "size": (2048, 1536),
        "cells": (
            [("crocus%d" % i, (i * 256, 0, 256, 256), 0.2, crocus, i, 0.5, False) for i in range(4)]
            + [("puff%d" % i, (1024 + i * 256, 0, 256, 256), 0.26, puff, i, 0.5, False) for i in range(4)]
            + [("knapweed%d" % i, (i * 512, 256, 512, 512), 0.56, knapweed, i, 0.5, False) for i in range(2)]
            + [("yarrow%d" % i, (1024 + i * 512, 256, 512, 512), 0.5, yarrow, i, 0.5, False) for i in range(2)]
            + [("nettle%d" % i, (i * 512, 768, 512, 512), (0.95, 0.95, 0.7, 0.7)[i], Model(NETTLE, [("nettle_plant_tall_a", "nettle_plant_tall_b", "nettle_plant_medium_a", "nettle_plant_medium_b")[i]], scale=(4.2, 4.6, 5.0, 5.4)[i], autumn=(0.3, 0.26, 0.08), amount=(0.0, 0.25, 0.1, 0.45)[i]), i, 0.5, False) for i in range(4)]
            + [("dandelion%d" % i, (i * 512, 1280, 512, 256), 0.3, Model(DANDELION, ["dandelion_01_" + "abce"[i]], autumn=(0.3, 0.24, 0.06), amount=0.15 * i), i, 0.5, False) for i in range(4)]
        ),
    },
    "floor": {
        "size": (2048, 2048),
        "cells": (
            [("bilberry%d" % i, (i * 512, 0, 512, 512), 0.5, bilberry, i, 0.5, False) for i in range(4)]
            + [("fern%d" % i, (i * 512, 512, 512, 512), (1.0, 0.9, 0.62, 0.62)[i], Model(FERN, ["fern_02_" + "bcad"[i]], autumn=((0.42, 0.3, 0.07), (0.36, 0.2, 0.06), (0.4, 0.33, 0.1), (0.25, 0.15, 0.06))[i], amount=(0.75, 0.9, 0.45, 0.95)[i]), i, 0.5, False) for i in range(4)]
            + [("seedling%d" % i, (i * 512, 1024, 512, 512), 0.5, seedling, i, 0.5, False) for i in range(4)]
            + [("moss%d" % i, (i * 512, 1536, 512, 256), 0.44, Model(MOSS, ["moss_01"], scatter=900 + 300 * i, radius=0.17 + 0.03 * i), i, 0.5, False) for i in range(2)]
            + [("sorrel%d" % i, (1024 + i * 512, 1536, 512, 256), 0.32, Model(SORREL, ["shrub_sorrel_01"], scatter=40 + 20 * i, radius=0.11 + 0.02 * i), i, 0.5, False) for i in range(2)]
            + [("moss_top%d" % i, (i * 256, 1792, 256, 256), 0.44, Model(MOSS, ["moss_01"], scatter=900 + 300 * i, radius=0.17 + 0.03 * i), i, 0.5, True) for i in range(2)]
            + [("sorrel_top%d" % i, (512 + i * 256, 1792, 256, 256), 0.32, Model(SORREL, ["shrub_sorrel_01"], scatter=40 + 20 * i, radius=0.11 + 0.02 * i), i, 0.5, True) for i in range(2)]
        ),
    },
}


def blade_material():
    material = bpy.data.materials.new("blade")
    if material.node_tree is None:
        material.use_nodes = True
    nodes = material.node_tree.nodes
    bsdf = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")
    tint = nodes.new("ShaderNodeVertexColor")
    tint.layer_name = "tint"
    material.node_tree.links.new(tint.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    return material


def facing_material(plan=False):
    """Which way a surface faces, as a colour, for a card that is looked at
    from the front: red to the right, green up, blue towards whoever looks.
    Seen from above, up on the picture is north (+y) and whoever looks is up
    (+z)."""
    material = bpy.data.materials.new("facing")
    if material.node_tree is None:
        material.use_nodes = True
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
    if plan:
        links.new(apart.outputs["Y"], together.inputs["Y"])
        links.new(apart.outputs["Z"], together.inputs["Z"])
    else:
        links.new(apart.outputs["Z"], together.inputs["Y"])
        links.new(apart.outputs["Y"], away.inputs[0])
        links.new(away.outputs[0], together.inputs["Z"])
    links.new(together.outputs[0], half.inputs[0])
    links.new(half.outputs[0], glow.inputs["Color"])
    links.new(glow.outputs[0], out.inputs["Surface"])
    return material


def set_scene(samples):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 3
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 4
    scene.render.film_transparent = True
    scene.render.filter_size = 1.2
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = bpy.data.worlds.new("sky")
    if world.node_tree is None:
        world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (1, 1, 1, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    scene.world = world
    return scene


def read_png(path):
    image = bpy.data.images.load(path)
    width, height = image.size
    dots = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(dots)
    bpy.data.images.remove(image)
    return dots.reshape(height, width, 4)[::-1].copy()


def write_png(path, dots, plain=False):
    height, width = dots.shape[:2]
    image = bpy.data.images.new("sheet", width, height, alpha=True, is_data=plain)
    image.alpha_mode = "STRAIGHT"
    image.pixels.foreach_set(dots[::-1].astype(np.float32).ravel())
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)


def render_cell(name, rect, wide, grow, which, foot, plan, seed, scratch, samples):
    """One cell, its colour and which way it faces, as two arrays of dots."""
    width, height = rect[2], rect[3]
    high = wide * height / width
    scene = set_scene(samples)
    if isinstance(grow, Model):
        corners = grow.place(scene, seed)
        print("%s: %d corners, %.3f by %.3f by %.3f m" % (name, len(corners), *np.ptp(corners, axis=0)))
    else:
        plant = Plant(wide, 0.5 if plan else high, seed, foot, plan)
        grow(plant, which)
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(plant.points, [], plant.faces)
        tint = mesh.color_attributes.new("tint", "FLOAT_COLOR", "POINT")
        tint.data.foreach_set("color", np.array([c + (1.0,) for c in plant.colours], dtype=np.float32).ravel())
        for face in mesh.polygons:
            face.use_smooth = True
        mesh.materials.append(blade_material())
        thing = bpy.data.objects.new(name, mesh)
        scene.collection.objects.link(thing)
        print("%s: %d corners, %d faces, %.3f by %.3f m" % (name, len(plant.points), len(plant.faces), wide, high))
    camera = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
    scene.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = max(wide, high)
    if plan:
        camera.location = (0.0, 0.0, 3.0)
        camera.rotation_euler = (0.0, 0.0, 0.0)
    else:
        camera.location = (0.0, -3.0, high * 0.5)
        camera.rotation_euler = (math.pi * 0.5, 0.0, 0.0)
    scene.camera = camera
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    colour_path = os.path.join(scratch, name + ".png")
    scene.render.filepath = colour_path
    bpy.ops.render.render(write_still=True)
    colour = read_png(colour_path)
    if isinstance(grow, Model):
        # A model keeps its holes: each of its materials gets a facing one
        # with the same.
        for thing in scene.objects:
            if thing.type == "MESH":
                for slot in thing.material_slots:
                    slot.material = facing_with_holes(slot.material, plan)
    else:
        bpy.context.view_layer.material_override = facing_material(plan)
    scene.view_settings.view_transform = "Raw"
    scene.cycles.samples = max(8, samples // 2)
    facing_path = os.path.join(scratch, name + "_n.png")
    scene.render.filepath = facing_path
    bpy.ops.render.render(write_still=True)
    facing = read_png(facing_path)
    return colour, facing, high


def render_sheet(asset, out_dir, scratch):
    spec = SHEETS[asset["sheet"]]
    width, height = spec["size"]
    colour = np.zeros((height, width, 4), dtype=np.float32)
    facing = np.zeros((height, width, 4), dtype=np.float32)
    facing[:, :, :3] = (0.5, 0.5, 1.0)
    table = {}
    only = asset.get("only")
    previous = None
    if only and os.path.exists(os.path.join(out_dir, asset["id"] + ".png")):
        previous = (read_png(os.path.join(out_dir, asset["id"] + ".png")), read_png(os.path.join(out_dir, asset["id"] + "_n.png")))
        colour, facing = previous
    for index, (name, rect, wide, grow, which, foot, plan) in enumerate(spec["cells"]):
        x, y, w, h = rect
        high = wide * h / w
        if not only or name in only:
            dots, faces, high = render_cell(name, rect, wide, grow, which, foot, plan, asset.get("seed", 1) * 1000 + index * 31, scratch, asset.get("samples", 48))
            colour[y:y + h, x:x + w] = dots
            # Where nothing is, the card faces whoever looks.
            faces[:, :, :3] = np.where(dots[:, :, 3:4] > 0.0, faces[:, :, :3], np.array([0.5, 0.5, 1.0]))
            faces[:, :, 3] = 1.0
            facing[y:y + h, x:x + w] = faces
        table[name] = {"rect": [x, y, w, h], "uv": [x / width, y / height, (x + w) / width, (y + h) / height], "size": [round(wide, 4), round(high, 4)]}
    # What is half there is there: thin blades fall away where the card is
    # cut to its picture.
    colour[:, :, 3] = np.clip(colour[:, :, 3] * asset.get("solid", 1.25), 0.0, 1.0)
    facing[:, :, 3] = 1.0
    write_png(os.path.join(out_dir, asset["id"] + ".png"), colour)
    write_png(os.path.join(out_dir, asset["id"] + "_n.png"), facing, plain=True)
    with open(os.path.join(out_dir, asset["id"] + ".json"), "w") as file:
        json.dump({"size": [width, height], "cells": table}, file, indent="\t")
        file.write("\n")
    for suffix, normal in (("", 0), ("_n", 1)):
        settings = os.path.join(out_dir, asset["id"] + suffix + ".png.import")
        if not os.path.exists(settings):
            with open(settings, "w") as file:
                file.write(IMPORT % normal)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = None
    if "--only" in args:
        only = args[args.index("--only") + 1].split(",")
        args = [arg for i, arg in enumerate(args) if arg != "--only" and args[i - 1] != "--only"]
    scratch = os.environ.get("PLANTS_KEEP", os.path.join(bpy.app.tempdir, "plants"))
    os.makedirs(scratch, exist_ok=True)
    with open(MANIFEST) as file:
        manifest = json.load(file)
    for asset in manifest["assets"]:
        if asset.get("source") != "rendered" or not asset.get("generator", "").endswith("gen_plants.py"):
            continue
        if args and asset["id"] not in args:
            continue
        if only:
            asset = dict(asset, only=only)
        # To try something out: PLANTS_OUT=<folder> PLANTS_SAMPLES=8.
        if "PLANTS_SAMPLES" in os.environ:
            asset = dict(asset, samples=int(os.environ["PLANTS_SAMPLES"]))
        out_dir = os.environ.get("PLANTS_OUT", OUT_DIR)
        os.makedirs(out_dir, exist_ok=True)
        render_sheet(asset, out_dir, scratch)
        print(asset["id"])


main()
