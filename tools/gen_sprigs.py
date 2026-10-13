"""Renders the sprigs of what grows tall on the dunes: bough ends of pine and
sprays of sea buckthorn, as textures with holes for the cards a crown is made
of. Run with tools/gen_sprigs.sh [name], which hands this to Blender:

    blender -b --factory-startup --python tools/gen_sprigs.py -- [name ...] [--out <folder>]

A sprig is not drawn but grown: a twig that puts on a length every year and
forks where one year ends and the next begins, with needles standing off
what is at most a few years old. It is then pictured from three sides, from
above, from beside and from in front, with the sky's light on it from every
side and nothing else, so that what lies deep in it is dark and what sticks
out is light, and nothing says where the sun stood. The three pictures of one
sprig are what three cards through each other show of it, see
tools/models/trees.gd.

Every entry of assets/manifest.json with source "rendered" and this file as
its generator is one sheet of such pictures: assets/foliage/<id>.png, and
next to it <id>.json, which says for every picture where on the sheet it is,
how large what it shows is in metres, and where on it the twig begins.

Cycles on the CPU, on a few threads: the GPU is Godot's.
"""

import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
MANIFEST = os.path.join(HERE, "..", "assets", "manifest.json")
OUT_DIR = os.path.join(HERE, "..", "assets", "foliage")
GOLDEN = 2.39996
# What Godot's importer is told of a sheet: compressed for the video card and
# with mipmaps, as tools/gen_foliage.gd tells it of what is drawn.
IMPORT = '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=2\ncompress/high_quality=true\nmipmaps/generate=true\nprocess/fix_alpha_border=true\ndetect_3d/compress_to=0\n'


class Sprig:
    """What a sprig is made of while it grows: corners, the triangles
    between them and a colour a corner."""

    def __init__(self, seed):
        self.rng = np.random.default_rng(seed)
        self.corners = []
        self.triangles = []
        self.colours = []
        self.count = 0

    def add(self, corners, triangles, colours):
        corners = np.asarray(corners, dtype=np.float64).reshape(-1, 3)
        colours = np.asarray(colours, dtype=np.float64)
        if colours.ndim == 1:
            colours = np.tile(colours, (len(corners), 1))
        self.corners.append(corners)
        self.triangles.append(np.asarray(triangles, dtype=np.int64).reshape(-1, 3) + self.count)
        self.colours.append(colours)
        self.count += len(corners)

    def arrays(self):
        return np.concatenate(self.corners), np.concatenate(self.triangles), np.concatenate(self.colours)


def unit(v):
    v = np.asarray(v, dtype=np.float64)
    return v / max(np.linalg.norm(v), 1e-9)


def across(direction):
    """Two directions square to `direction` and to each other."""
    ref = np.array([0.0, 1.0, 0.0]) if abs(direction[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
    side = unit(np.cross(direction, ref))
    return side, np.cross(direction, side)


def turned(direction, axis, angle):
    """`direction` turned about `axis` (Rodrigues)."""
    axis = unit(axis)
    return direction * math.cos(angle) + np.cross(axis, direction) * math.sin(angle) + axis * np.dot(axis, direction) * (1.0 - math.cos(angle))


def tube(sprig, points, radii, colour, sides=5, shade=None):
    """Wood through `points`, `radii[i]` thick at each."""
    rings = []
    for i, point in enumerate(points):
        heading = unit(points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)])
        side, up = across(heading)
        ring = [point + (side * math.cos(a) + up * math.sin(a)) * radii[i] for a in np.linspace(0.0, math.tau, sides, endpoint=False)]
        rings.append(ring)
    corners = np.array(rings).reshape(-1, 3)
    triangles = []
    for i in range(len(points) - 1):
        for s in range(sides):
            a = i * sides + s
            b = i * sides + (s + 1) % sides
            triangles += [[a, b, b + sides], [a, b + sides, a + sides]]
    colours = np.tile(np.asarray(colour), (len(corners), 1))
    if shade is not None:
        colours = colours * np.repeat(np.asarray(shade), sides)[:, None]
    sprig.add(corners, triangles, colours)


def needles(sprig, feet, ways, lengths, width, colours, droop):
    """A needle from each of `feet` along `ways`: three-sided, tapering to a
    point, and bent a little towards `droop`."""
    count = len(feet)
    ref = np.where(np.abs(ways[:, 1:2]) < 0.9, np.array([[0.0, 1.0, 0.0]]), np.array([[1.0, 0.0, 0.0]]))
    side = np.cross(ways, ref)
    side /= np.linalg.norm(side, axis=1, keepdims=True)
    up = np.cross(ways, side)
    spin = sprig.rng.uniform(0.0, math.tau, count)
    middle = feet + ways * (lengths * 0.55)[:, None] + droop * (lengths * 0.05)[:, None]
    tip = feet + ways * lengths[:, None] + droop * (lengths * 0.16)[:, None]
    corners = np.zeros((count, 7, 3))
    for k in range(3):
        angle = spin + k * math.tau / 3.0
        out = side * np.cos(angle)[:, None] + up * np.sin(angle)[:, None]
        corners[:, k] = feet + out * width * 0.5
        corners[:, 3 + k] = middle + out * width * 0.42
    corners[:, 6] = tip
    one = np.array([[0, 1, 4], [0, 4, 3], [1, 2, 5], [1, 5, 4], [2, 0, 3], [2, 3, 5], [3, 4, 6], [4, 5, 6], [5, 3, 6]])
    triangles = (one[None, :, :] + (np.arange(count) * 7)[:, None, None]).reshape(-1, 3)
    # Paler towards the tip, as a needle is.
    tint = np.ones((count, 7, 1))
    tint[:, 3:6] = 1.08
    tint[:, 6] = 1.18
    sprig.add(corners.reshape(-1, 3), triangles, (colours[:, None, :] * tint).reshape(-1, 3))


def leaves(sprig, feet, ways, lengths, width, colours):
    """A narrow leaf from each of `feet` along `ways`: flat, widest half-way
    and pointed at both ends."""
    count = len(feet)
    ref = np.where(np.abs(ways[:, 1:2]) < 0.9, np.array([[0.0, 1.0, 0.0]]), np.array([[1.0, 0.0, 0.0]]))
    side = np.cross(ways, ref)
    side /= np.linalg.norm(side, axis=1, keepdims=True)
    up = np.cross(ways, side)
    spin = sprig.rng.uniform(0.0, math.tau, count)
    flat = side * np.cos(spin)[:, None] + up * np.sin(spin)[:, None]
    corners = np.zeros((count, 4, 3))
    corners[:, 0] = feet
    corners[:, 1] = feet + ways * (lengths * 0.5)[:, None] + flat * width * 0.5
    corners[:, 2] = feet + ways * lengths[:, None]
    corners[:, 3] = feet + ways * (lengths * 0.5)[:, None] - flat * width * 0.5
    one = np.array([[0, 1, 2], [0, 2, 3]])
    triangles = (one[None, :, :] + (np.arange(count) * 4)[:, None, None]).reshape(-1, 3)
    sprig.add(corners.reshape(-1, 3), triangles, np.repeat(colours, 4, axis=0))


def berries(sprig, kind, start, way, length, thick):
    """Berries packed round the wood from `start` along `way`, as sea
    buckthorn carries them below its leaves."""
    rng = sprig.rng
    count = int(length / kind["berry_pitch"])
    if count == 0:
        return
    side, up = across(way)
    size = kind["berry"]
    turn = rng.uniform(0.0, math.tau, count)
    out = side[None, :] * np.cos(turn)[:, None] + up[None, :] * np.sin(turn)[:, None]
    middles = start[None, :] + way[None, :] * (rng.uniform(0.0, 1.0, count) * length)[:, None] + out * (thick + size * rng.uniform(0.6, 1.4, count))[:, None]
    points = np.array([[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]], dtype=np.float64) * size
    corners = (middles[:, None, :] + points[None, :, :]).reshape(-1, 3)
    one = np.array([[0, 2, 4], [2, 1, 4], [1, 3, 4], [3, 0, 4], [2, 0, 5], [1, 2, 5], [3, 1, 5], [0, 3, 5]])
    triangles = (one[None, :, :] + (np.arange(count) * 6)[:, None, None]).reshape(-1, 3)
    colours = np.array(kind["berry_colour"])[None, :] * rng.uniform(0.75, 1.2, (count, 1)) * np.array([[1.0, 1.0, 1.0]])
    colours[:, 1] *= rng.uniform(0.8, 1.35, count)
    sprig.add(corners, triangles, np.repeat(colours, 6, axis=0))


def pine_shoot(sprig, kind, start, way, length, age, vigour):
    """One year's length of a pine twig from `start` along `way`, grown `age`
    years ago: its wood, and its needles if it still has them."""
    rng = sprig.rng
    end = start + way * length
    thick = kind["twig"] * (1.0 + 0.55 * age) * (0.7 + 0.3 * vigour)
    wood = np.array(kind["wood_young"]) if age == 0 else np.array(kind["wood_old"])
    tube(sprig, [start, end], [thick, thick * 0.85], wood * rng.uniform(0.85, 1.1), 5)
    if "berry" in kind and age >= 1 and rng.uniform() < kind["berried"]:
        berries(sprig, kind, start, way, length, thick)
    if age >= kind["keeps"]:
        return end
    # Pairs of needles round the twig, on a spiral.
    pitch = kind["pitch"] * (1.0 + 0.45 * age)
    pairs = max(int(length / pitch), 3)
    along = (np.arange(pairs) + rng.uniform(0.0, 1.0, pairs)) / pairs
    # The first of a year's length is bare: scales, no needles.
    along = 0.12 + along * 0.88 if age == 0 else along
    side, up = across(way)
    turn = np.arange(pairs) * GOLDEN + rng.uniform(-0.4, 0.4, pairs) + rng.uniform(0.0, math.tau)
    out = side[None, :] * np.cos(turn)[:, None] + up[None, :] * np.sin(turn)[:, None]
    # Young needles lie forward along the twig, old ones stand off it.
    forward = np.radians(rng.normal(kind["stand"][min(age, 2)], 7.0, pairs))
    feet = start[None, :] + way[None, :] * (along * length)[:, None] + out * thick
    for one in range(2):
        open_ = forward + np.radians(rng.normal(0.0, 6.0, pairs)) + (0.12 if one else -0.12)
        skew = out * np.cos(0.25 * (one * 2 - 1)) + np.cross(way, out) * np.sin(0.25 * (one * 2 - 1))
        ways = way[None, :] * np.cos(open_)[:, None] + skew * np.sin(open_)[:, None]
        ways /= np.linalg.norm(ways, axis=1, keepdims=True)
        lengths = kind["needle"] * rng.uniform(0.78, 1.12, pairs) * (0.85 + 0.15 * vigour) * (0.72 if age == 0 and kind["candle"] else 1.0)
        fresh = np.array(kind["green"][min(age, 2)])
        colours = fresh[None, :] * rng.uniform(0.8, 1.2, (pairs, 1)) * (1.0 + rng.uniform(-0.08, 0.08, (pairs, 3)))
        # Now and then a pair that has died and not yet dropped.
        dead = rng.uniform(0.0, 1.0, pairs) < kind["dead"] * (age + 0.2)
        colours[dead] = np.array(kind["dead_colour"]) * rng.uniform(0.8, 1.2, (int(dead.sum()), 1))
        if kind.get("leaf"):
            # Some show the silver of their underside.
            turned_ = rng.uniform(0.0, 1.0, pairs) < 0.3
            colours[turned_] = colours[turned_] * 0.6 + np.array(kind["silver"]) * 0.4
            leaves(sprig, feet, ways, lengths, kind["width"], colours)
        else:
            needles(sprig, feet, ways, lengths, kind["width"], colours, np.array([0.0, -1.0, 0.0]))
    return end


def bud(sprig, kind, at, way):
    """The bud a twig ends in."""
    points = [at, at + way * kind["bud"] * 0.5, at + way * kind["bud"]]
    tube(sprig, points, [kind["twig"] * 1.5, kind["twig"] * 1.3, kind["twig"] * 0.2], kind["bud_colour"], 5)


def cone(sprig, kind, at, way):
    """A cone, hanging back along the twig it grew on."""
    rng = sprig.rng
    size = kind["cone"] * rng.uniform(0.8, 1.15)
    profile = [(0.0, 0.25), (0.15, 0.75), (0.4, 1.0), (0.7, 0.8), (0.9, 0.45), (1.0, 0.08)]
    points = [at + way * size * t for t, _ in profile]
    radii = [size * 0.3 * r for _, r in profile]
    shade = [0.8, 1.0, 0.85, 1.05, 0.8, 1.0]
    tube(sprig, points, radii, np.array(kind["cone_colour"]) * rng.uniform(0.85, 1.15), 7, shade)


def pine_axis(sprig, kind, start, way, age, vigour, flat):
    """A twig that began `age` years ago: a length for every year since, and
    where one year ends and the next begins the twigs that forked off there,
    each as old as the wood beyond it. It turns towards the light as it goes.
    `flat` is the plane a bough spreads in: its side twigs keep near it."""
    rng = sprig.rng
    at = np.array(start, dtype=np.float64)
    way = unit(way)
    if vigour < kind["dies"]:
        return
    for year in range(age - 1, -1, -1):
        length = kind["year"] * vigour * rng.uniform(0.75, 1.25) * (1.0 if year > 0 else kind["last"])
        # Up towards the light, and a little off to one side: no twig is straight.
        way = unit(way + np.array([0.0, kind["upturn"], 0.0]) * rng.uniform(0.5, 1.5) + rng.normal(0.0, kind["wander"], 3))
        at = pine_shoot(sprig, kind, at, way, length, year, vigour)
        if year == 0:
            bud(sprig, kind, at, way)
            break
        # The whorl: the twigs that left here when this length was done.
        forks = rng.choice(kind["forks"], p=kind["fork_odds"])
        if vigour < 0.6:
            forks = min(forks, 1)
        first = rng.uniform(0.0, math.tau)
        side, up = across(way)
        for fork in range(forks):
            turn = first + fork * math.tau / max(forks, 1) + rng.uniform(-0.5, 0.5)
            out = side * math.cos(turn) + up * math.sin(turn)
            # Flattened into the plane of the bough, more or less.
            out = unit(out - flat * np.dot(out, flat) * kind["flatten"])
            lean = math.radians(rng.uniform(*kind["fork_angle"]))
            off = unit(way * math.cos(lean) + out * math.sin(lean))
            pine_axis(sprig, kind, at, off, year, vigour * rng.uniform(*kind["fork_vigour"]), flat)
        if year >= 2 and rng.uniform() < kind["cones"]:
            hang = unit(-way * 0.6 + np.array([0.0, -0.5, 0.0]) + rng.normal(0.0, 0.4, 3))
            cone(sprig, kind, at, hang)


# What a kind of sprig is like. Lengths in metres, colours linear.
KINDS = {
    # Scots pine: short blue-green needles in dense brushes on short twigs.
    "scots": {
        "grow": "pine",
        "year": 0.08, "last": 0.9, "twig": 0.0022, "needle": 0.055, "width": 0.0024, "pitch": 0.003,
        "keeps": 3, "stand": [36.0, 54.0, 68.0], "candle": False,
        "green": [[0.11, 0.22, 0.1], [0.07, 0.155, 0.09], [0.05, 0.115, 0.075]],
        "dead": 0.012, "dead_colour": [0.3, 0.19, 0.08],
        "wood_young": [0.2, 0.19, 0.1], "wood_old": [0.16, 0.11, 0.07],
        "bud": 0.008, "bud_colour": [0.3, 0.17, 0.09],
        "cone": 0.045, "cone_colour": [0.24, 0.18, 0.13], "cones": 0.06,
        "upturn": 0.1, "wander": 0.09, "flatten": 0.72,
        "forks": [1, 2, 3], "fork_odds": [0.15, 0.5, 0.35], "fork_angle": (38.0, 62.0), "fork_vigour": (0.62, 0.88),
        # Below this a twig stands in the shade of the others and has died.
        "dies": 0.3,
    },
}
# The same pine as a spray: a twig with a few brushes on it that stand well
# apart, for a card that is seen from close by and has to show what is
# behind it.
KINDS["spray"] = dict(KINDS["scots"])
KINDS["spray"].update({
    "year": 0.12, "needle": 0.072, "pitch": 0.0026, "stand": [40.0, 56.0, 68.0],
    "fork_odds": [0.55, 0.38, 0.07], "fork_angle": (24.0, 44.0), "fork_vigour": (0.7, 0.95),
    "upturn": 0.08, "flatten": 0.8, "dies": 0.4, "cones": 0.12,
})


# The same pine for a whole bough end, which is pictured small: three
# millimetres to the dot, where a needle is two across. Dense brushes of thin
# needles close up into balls there, and a ball with a ragged edge is a leaf.
# So its tufts are open: fewer needles and thicker ones, which a dot can
# hold, on the wood of the last two years only, with the bare twig showing
# behind them and the tips of the needles standing out of the tuft one by one.
KINDS["tuft"] = dict(KINDS["scots"])
KINDS["tuft"].update({
    "year": 0.105, "needle": 0.074, "width": 0.0046, "pitch": 0.0062, "keeps": 2,
    "stand": [34.0, 60.0, 72.0], "fork_odds": [0.3, 0.48, 0.22], "fork_angle": (30.0, 54.0), "fork_vigour": (0.66, 0.92),
    "upturn": 0.09, "flatten": 0.78, "dies": 0.38, "cones": 0.1,
    "green": [[0.115, 0.225, 0.1], [0.07, 0.155, 0.088], [0.05, 0.115, 0.075]],
})


# Sea buckthorn: crooked grey twigs that fork every way, narrow grey-green
# leaves with a silver underside, and in autumn orange berries packed round
# the wood of last year and the year before.
KINDS["buckthorn"] = {
    "grow": "pine", "leaf": True,
    "year": 0.1, "last": 1.0, "twig": 0.0024, "needle": 0.05, "width": 0.0075, "pitch": 0.006,
    "keeps": 2, "stand": [42.0, 58.0, 66.0], "candle": False,
    "green": [[0.2, 0.27, 0.15], [0.15, 0.21, 0.13], [0.13, 0.18, 0.12]], "silver": [0.42, 0.46, 0.38],
    "dead": 0.02, "dead_colour": [0.3, 0.24, 0.1],
    "wood_young": [0.2, 0.17, 0.12], "wood_old": [0.13, 0.11, 0.09],
    "bud": 0.012, "bud_colour": [0.16, 0.13, 0.1],
    "cone": 0.0, "cone_colour": [0.0, 0.0, 0.0], "cones": 0.0,
    "berry": 0.0042, "berry_pitch": 0.0022, "berry_colour": [0.78, 0.27, 0.025], "berried": 0.7,
    "upturn": 0.06, "wander": 0.16, "flatten": 0.25,
    "forks": [1, 2, 3], "fork_odds": [0.3, 0.45, 0.25], "fork_angle": (34.0, 72.0), "fork_vigour": (0.6, 0.9),
    "dies": 0.3,
}
KINDS["buckthorn_spray"] = dict(KINDS["buckthorn"])
KINDS["buckthorn_spray"].update({"fork_odds": [0.55, 0.38, 0.07], "fork_angle": (28.0, 52.0), "dies": 0.4, "flatten": 0.5})


def grow(kind_name, seed, age, vigour):
    """One sprig of a kind: its twig begins at the origin and grows along +X,
    with +Y up. Returns its corners, triangles and colours."""
    kind = KINDS[kind_name]
    sprig = Sprig(seed)
    if kind["grow"] == "pine":
        pine_axis(sprig, kind, np.zeros(3), np.array([1.0, 0.12, 0.0]), age, vigour, np.array([0.0, 1.0, 0.0]))
    return sprig.arrays()


def bough(seed, grown, length, forks, wood=(0.2, 0.13, 0.08), apart=0.22):
    """A whole bough end, for a tree that is seen from afar: bare wood that
    forks, `length` long, with the sprigs of `grown` (what grow() returned for
    each) at its ends and along the outer part of it. It begins at the origin
    and grows along +X, with +Y up, as a sprig does. `apart` is how far from
    each other the sprigs stand along a limb."""
    out = Sprig(seed)
    rng = out.rng
    wood = np.array(wood)

    def limb(start, way, reach, thick):
        """Wood from `start` along `way`, sagging and then turning up; returns
        its points."""
        side, _ = across(way)
        bend = side * rng.normal(0.0, 0.12) * reach
        points = []
        for step in range(6):
            t = step / 5.0
            sag = np.array([0.0, -0.06 * math.sin(math.pi * t) + 0.1 * t * t, 0.0]) * reach
            points.append(start + way * reach * t + sag + bend * math.sin(math.pi * t * 0.8))
        tube(out, points, [thick * (1.0 - 0.75 * step / 5.0) for step in range(6)], wood * rng.uniform(0.85, 1.1), 6)
        return points

    def put(at, way, scale):
        """One of the sprigs with its twig at `at`, growing along `way`."""
        corners, triangles, colours = grown[rng.integers(len(grown))]
        way = unit(way)
        z = unit(np.cross(way, np.array([0.0, 1.0, 0.0])))
        y = np.cross(z, way)
        roll = rng.normal(0.0, 0.35)
        y, z = y * math.cos(roll) + z * math.sin(roll), z * math.cos(roll) - y * math.sin(roll)
        turned_ = corners[:, 0:1] * way[None, :] + corners[:, 1:2] * y[None, :] + corners[:, 2:3] * z[None, :]
        out.add(at[None, :] + turned_ * scale, triangles, colours * rng.uniform(0.9, 1.1))

    def dress(points, reach):
        """Sprigs on a limb: one at its end, and from a third of the way out
        one to either side by turns, and now and then one on top."""
        heading = unit(points[-1] - points[-2])
        put(points[-1], heading + np.array([0.0, 0.25, 0.0]), rng.uniform(0.95, 1.2))
        steps = max(int(reach * 0.66 / apart), 1)
        for step in range(steps):
            t = 0.32 + 0.64 * (step + rng.uniform(0.2, 0.8)) / steps
            at = points[0] + (points[-1] - points[0]) * t
            index = min(int(t * 5.0), 4)
            at = points[index] + (points[index + 1] - points[index]) * (t * 5.0 - index)
            along = unit(points[index + 1] - points[index])
            side, _ = across(along)
            if side[1] != 0.0:
                side = unit(np.array([side[0], 0.0, side[2]]))
            hand = 1.0 if step % 2 == 0 else -1.0
            if rng.uniform() < 0.25:
                put(at, along * 0.5 + np.array([0.0, 0.9, 0.0]) + side * rng.normal(0.0, 0.3), rng.uniform(0.8, 1.0))
            else:
                put(at, along * rng.uniform(0.5, 0.9) + side * hand + np.array([0.0, rng.uniform(0.05, 0.35), 0.0]), rng.uniform(0.85, 1.1))

    main = limb(np.zeros(3), unit(np.array([1.0, 0.06, 0.0])), length, 0.02)
    dress(main, length)
    for fork in range(forks):
        t = 0.2 + 0.62 * (fork + rng.uniform(0.2, 0.8)) / forks
        index = min(int(t * 5.0), 4)
        at = main[index] + (main[index + 1] - main[index]) * (t * 5.0 - index)
        along = unit(main[index + 1] - main[index])
        side, _ = across(along)
        side = unit(np.array([side[0], 0.0, side[2]]))
        hand = 1.0 if fork % 2 == 0 else -1.0
        lean = math.radians(rng.uniform(38.0, 58.0))
        way = unit(along * math.cos(lean) + side * hand * math.sin(lean) + np.array([0.0, rng.uniform(0.0, 0.2), 0.0]))
        reach = length * (1.0 - t) * rng.uniform(0.75, 1.0) + 0.25
        dress(limb(at, way, reach, 0.012), reach)
    return out.arrays()


# --- Picturing it ------------------------------------------------------------------

# The three sides a sprig is pictured from: what is to the right on the
# picture, what is up, and what comes towards whoever looks.
VIEWS = {
    "plan": (np.array([0.0, 0.0, 1.0]), np.array([1.0, 0.0, 0.0]), np.array([0.0, 1.0, 0.0])),
    "side": (np.array([1.0, 0.0, 0.0]), np.array([0.0, 1.0, 0.0]), np.array([0.0, 0.0, 1.0])),
    "front": (np.array([0.0, 0.0, -1.0]), np.array([0.0, 1.0, 0.0]), np.array([1.0, 0.0, 0.0])),
}


def set_scene(samples):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 3
    scene.cycles.diffuse_bounces = 2
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 4
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.world = bpy.data.worlds.new("sky")
    if scene.world.node_tree is None:
        scene.world.use_nodes = True
    back = scene.world.node_tree.nodes["Background"]
    back.inputs[0].default_value = (1.0, 1.0, 1.0, 1.0)
    back.inputs[1].default_value = 1.0
    return scene


def as_object(name, corners, triangles, colours):
    mesh = bpy.data.meshes.new(name)
    mesh.vertices.add(len(corners))
    mesh.vertices.foreach_set("co", corners.astype(np.float32).ravel())
    mesh.loops.add(len(triangles) * 3)
    mesh.loops.foreach_set("vertex_index", triangles.astype(np.int32).ravel())
    mesh.polygons.add(len(triangles))
    mesh.polygons.foreach_set("loop_start", np.arange(0, len(triangles) * 3, 3, dtype=np.int32))
    try:
        mesh.polygons.foreach_set("loop_total", np.full(len(triangles), 3, dtype=np.int32))
    except (AttributeError, TypeError, RuntimeError):
        pass
    mesh.update(calc_edges=True)
    paint = mesh.color_attributes.new("paint", "FLOAT_COLOR", "POINT")
    rgba = np.concatenate([colours, np.ones((len(colours), 1))], axis=1).astype(np.float32)
    paint.data.foreach_set("color", rgba.ravel())
    material = bpy.data.materials.new(name)
    if material.node_tree is None:
        material.use_nodes = True
    nodes = material.node_tree.nodes
    shader = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")
    shader.inputs["Roughness"].default_value = 0.7
    shader.inputs["Specular IOR Level"].default_value = 0.15
    read = nodes.new("ShaderNodeAttribute")
    read.attribute_name = "paint"
    material.node_tree.links.new(read.outputs["Color"], shader.inputs["Base Color"])
    mesh.materials.append(material)
    thing = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(thing)
    return thing


def picture(scene, corners, view, width, height, path, margin=0.09):
    """Renders what stands in the scene from one side into `path`, as large as
    fits, and returns what the picture shows: how many metres it is wide and
    high, where on it the origin is (0 to 1 from the left and from the top)
    and how far behind the origin its middle lies."""
    right, up, back = VIEWS[view]
    x = corners @ right
    y = corners @ up
    z = corners @ back
    middle = np.array([(x.min() + x.max()) * 0.5, (y.min() + y.max()) * 0.5])
    span = max((x.max() - x.min()) / width, (y.max() - y.min()) / height) / (1.0 - 2.0 * margin)
    wide = span * width
    high = span * height
    camera = bpy.data.cameras.new(view)
    camera.type = "ORTHO"
    camera.ortho_scale = max(wide, high)
    camera.clip_start = 0.01
    camera.clip_end = 100.0
    eye = bpy.data.objects.new(view, camera)
    scene.collection.objects.link(eye)
    at = right * middle[0] + up * middle[1] + back * (z.max() + 5.0)
    # A camera looks down its own -Z with its Y up. Where it stands and how it
    # is turned are set one by one: a whole matrix handed to a camera that
    # has just been made loses where it stands.
    eye.rotation_mode = "QUATERNION"
    eye.rotation_quaternion = Matrix([[float(right[i]), float(up[i]), float(back[i])] for i in range(3)]).to_quaternion()
    eye.location = [float(v) for v in at]
    scene.camera = eye
    bpy.context.view_layer.update()
    stands = np.array(eye.matrix_world.translation)
    if not np.allclose(stands, at, atol=1e-4):
        raise RuntimeError("the camera for %s stands at %s, not at %s" % (view, stands, at))
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(eye)
    pad = margin * 0.85
    return {
        "size": [round(wide, 4), round(high, 4)],
        "anchor": [round(0.5 - middle[0] / wide, 4), round(0.5 + middle[1] / high, 4)],
        "depth": round(float((z.min() + z.max()) * 0.5), 4),
        # The part of the picture there is something on, from the left and
        # from the top: a card need be no larger.
        "box": [
            round(max(0.5 - (x.max() - x.min()) * 0.5 / wide - pad, 0.0), 4),
            round(max(0.5 - (y.max() - y.min()) * 0.5 / high - pad, 0.0), 4),
            round(min(0.5 + (x.max() - x.min()) * 0.5 / wide + pad, 1.0), 4),
            round(min(0.5 + (y.max() - y.min()) * 0.5 / high + pad, 1.0), 4),
        ],
    }


def read_png(path):
    image = bpy.data.images.load(path)
    width, height = image.size
    dots = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(dots)
    bpy.data.images.remove(image)
    # Blender counts rows from the bottom.
    return dots.reshape(height, width, 4)[::-1].copy()


def write_png(path, dots):
    height, width = dots.shape[:2]
    image = bpy.data.images.new("sheet", width, height, alpha=True)
    image.alpha_mode = "STRAIGHT"
    image.pixels.foreach_set(dots[::-1].astype(np.float32).ravel())
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)


def bark_strip(rng, width, height, low, high):
    """Bark from foot to top, left to right, for wood that is drawn with its
    leaves: the trunk of a pine seen from afar, grey-brown plates below and
    orange from half-way up, or the stems of a bush."""
    along = np.linspace(0.0, 1.0, width)[None, :]
    up = np.clip((along - 0.38) / 0.22, 0.0, 1.0)
    up = up * up * (3.0 - 2.0 * up)
    low = np.array(low)
    high = np.array(high)
    colour = low[None, None, :] * (1.0 - up[:, :, None]) + high[None, None, :] * up[:, :, None]
    # Plates and the cracks between them: streaks along the trunk.
    streaks = rng.uniform(0.0, 1.0, (height, width // 16 + 1))
    streaks = np.repeat(streaks, 16, axis=1)[:, :width]
    cracks = np.where(streaks < 0.22, 0.6, 1.0) * (0.9 + 0.2 * rng.uniform(0.0, 1.0, (height, width)))
    strip = np.ones((height, width, 4), dtype=np.float32)
    strip[:, :, :3] = np.clip(colour * cracks[:, :, None], 0.0, 1.0)
    return strip


def render_sheet(asset, out_dir, scratch):
    """One sheet: a column for every sprig of the entry, and in it that sprig
    from above, from beside and from in front."""
    cell = asset["cell"]
    sprigs = asset["sprigs"]
    boughs = asset.get("boughs", [])
    # A sprig is about as long as it is wide, and not as high.
    rows = [("plan", cell), ("side", cell * 3 // 4), ("front", cell * 3 // 4)]
    strip = asset.get("bark", 0)
    sheet = np.zeros((sum(high for _, high in rows) + strip, cell * (len(sprigs) + len(boughs)), 4), dtype=np.float32)
    table = []
    grown = [grow(sprig["kind"], asset["seed"] + column * 101, sprig["age"], sprig.get("vigour", 1.0)) for column, sprig in enumerate(sprigs)]
    # A bough is dressed with sprigs of its own, fuller than those that are
    # pictured one by one: from afar a bough is a mass, from close by a
    # sprig has to show the sky between its twigs.
    dress = [grow(sprig["kind"], asset["seed"] + 5000 + index * 101, sprig["age"], sprig.get("vigour", 1.0)) for index, sprig in enumerate(asset.get("bough_sprigs", []))]
    for column, spec in enumerate(boughs):
        grown.append(bough(asset["seed"] + 977 + column * 131, dress if dress else grown[:len(sprigs)], spec["length"], spec["forks"], spec.get("wood", (0.2, 0.13, 0.08)), spec.get("apart", 0.22)))
    for column, (corners, triangles, colours) in enumerate(grown):
        what = "sprig" if column < len(sprigs) else "bough"
        scene = set_scene(asset.get("samples", 48))
        as_object(what, corners, triangles, colours)
        top = 0
        for view, high in rows:
            path = os.path.join(scratch, "%s_%d_%s.png" % (asset["id"], column, view))
            shows = picture(scene, corners, view, cell, high, path)
            dots = read_png(path)
            sheet[top:top + high, column * cell:(column + 1) * cell] = dots
            shows["view"] = view
            shows["what"] = what
            shows["which"] = column if what == "sprig" else column - len(sprigs)
            shows["rect"] = [column * cell, top, cell, high]
            table.append(shows)
            top += high
        print("%s, %s %d: %d triangles, %.2f m long, %.2f m wide, %.2f m high" % (asset["id"], what, column, len(triangles), corners[:, 0].max(), np.ptp(corners[:, 2]), np.ptp(corners[:, 1])))
    # What is half there is there: thin needles would otherwise fall away
    # where the card is cut to its texture.
    sheet[:, :, 3] = np.clip(sheet[:, :, 3] * asset.get("solid", 1.3), 0.0, 1.0)
    if strip:
        top = sheet.shape[0] - strip
        sheet[top:] = bark_strip(np.random.default_rng(asset["seed"]), sheet.shape[1], strip, asset.get("bark_low", (0.36, 0.29, 0.22)), asset.get("bark_high", (0.41, 0.29, 0.19)))
        table.append({"view": "bark", "rect": [0, top, sheet.shape[1], strip]})
    write_png(os.path.join(out_dir, asset["id"] + ".png"), sheet)
    with open(os.path.join(out_dir, asset["id"] + ".json"), "w") as file:
        json.dump({"size": [sheet.shape[1], sheet.shape[0]], "pictures": table}, file, indent="\t")
        file.write("\n")
    settings = os.path.join(out_dir, asset["id"] + ".png.import")
    if not os.path.exists(settings):
        with open(settings, "w") as file:
            file.write(IMPORT)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = OUT_DIR
    if "--out" in args:
        out_dir = args[args.index("--out") + 1]
        args = [arg for i, arg in enumerate(args) if arg != "--out" and args[i - 1] != "--out"]
    # The single pictures go where Blender keeps what it throws away, unless
    # somebody wants to look at them.
    scratch = os.environ.get("SPRIGS_KEEP", os.path.join(bpy.app.tempdir, "sprigs"))
    os.makedirs(scratch, exist_ok=True)
    os.makedirs(out_dir, exist_ok=True)
    with open(MANIFEST) as file:
        manifest = json.load(file)
    for asset in manifest["assets"]:
        if asset.get("source") != "rendered" or not asset.get("generator", "").endswith("gen_sprigs.py"):
            continue
        if args and asset["id"] not in args:
            continue
        render_sheet(asset, out_dir, scratch)
        print(asset["id"])


main()
