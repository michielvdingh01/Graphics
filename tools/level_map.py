#!/usr/bin/env python3
"""Draws a level from above, as it was built: what stands on the floor, the
zones and the route with its robots. For looking a layout over without the
GPU, before anything is baked.

    tools/level_map.py [level]        the factory, when none is named

The drawing lands in benchmark/results/<level>_map.png (it needs ImageMagick
to make a picture of it; the .svg next to it is the same drawing). North is
up, a square of the grid is five metres.

What is drawn is every collider of the level, by how high it reaches: black
for what stands taller than a person, such as a wall or a rack, grey for
what a robot can shoot over, and nothing for floors and ceilings. Blue
outlines are the zones, red dots the robots at their posts, the green dot is
where the player starts and the green box the way out.
"""
import math
import os
import re
import subprocess
import sys

import host
from scene_text import Scene

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCALE = 22.0  # pixels to a metre
FONT = host.FONT


def numbers(text):
    return [float(n) for n in re.findall(r"-?\d+(?:\.\d+)?(?:e-?\d+)?", text)]


def transform(lines):
    """The transform on a node, as (x axis, y axis, z axis, origin); the
    identity when it has none."""
    for line in lines:
        if line.startswith("transform = Transform3D("):
            n = numbers(line[len("transform = Transform3D("):])
            # Godot writes the basis by rows.
            return ((n[0], n[3], n[6]), (n[1], n[4], n[7]), (n[2], n[5], n[8]), (n[9], n[10], n[11]))
    return ((1, 0, 0), (0, 1, 0), (0, 0, 1), (0, 0, 0))


def position(lines):
    for line in lines:
        if line.startswith("position = Vector3("):
            return tuple(numbers(line))
    return transform(lines)[3]


def main():
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    name = names[0] if names else "factory"
    path = os.path.join(ROOT, "scenes/levels/%s_level.tscn" % name)
    if not os.path.exists(path):
        sys.exit("There is no level called %s in scenes/levels/." % name)
    level = Scene(open(path).read())

    shapes = []  # (corners on the ground, bottom, top)
    for node_path, node in level.nodes.items():
        if node["kind"] != "CollisionShape3D" or node_path.startswith("Route/"):
            continue
        shape = next((line for line in node["lines"] if line.startswith("shape = ")), "")
        x_axis, y_axis, z_axis, origin = transform(node["lines"])
        parent = level.nodes.get(node_path.rsplit("/", 1)[0])
        if parent and parent["kind"] in ("StaticBody3D", "AnimatableBody3D"):
            base = position(parent["lines"])
            origin = tuple(origin[i] + base[i] for i in range(3))
        if "BoxShape3D" in shape:
            size = numbers(shape.split("size = Vector3(")[1]) if "size = Vector3(" in shape else [1, 1, 1]
            half = [s * 0.5 for s in size[:3]]
        elif "CylinderShape3D" in shape:
            radius = numbers(shape.split("radius = ")[1])[0] if "radius = " in shape else 0.5
            height = numbers(shape.split("height = ")[1])[0] if "height = " in shape else 2.0
            half = [radius, height * 0.5, radius]
        else:
            continue
        # How far the box reaches up and down, and its outline on the ground.
        reach = sum(abs(axis[1]) * half[i] for i, axis in enumerate((x_axis, y_axis, z_axis)))
        corners = []
        for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            corners.append((origin[0] + x_axis[0] * half[0] * sx + z_axis[0] * half[2] * sz, origin[2] + x_axis[2] * half[0] * sx + z_axis[2] * half[2] * sz))
        shapes.append((corners, origin[1] - reach, origin[1] + reach))

    zones = []
    for node_path, node in level.nodes.items():
        if 'groups=["level_zone"]' in node["head"]:
            label = next((re.match(r'metadata/zone = "([^"]*)"', l).group(1) for l in node["lines"] if l.startswith("metadata/zone")), "")
            for line in node["lines"]:
                if line.startswith("metadata/bounds"):
                    n = numbers(line.split("=", 1)[1])
                    for i in range(0, len(n) - 5, 6):
                        zones.append((label, n[i], n[i + 2], n[i + 3], n[i + 5]))
    robots, start, way_out = [], None, None
    for node_path, node in level.nodes.items():
        if not node_path.startswith("Route/"):
            continue
        parent = level.nodes.get(node_path.rsplit("/", 1)[0])
        if 'groups=["enemy_spawn"]' in node["head"]:
            base, here = position(parent["lines"]), position(node["lines"])
            kind = next((re.match(r'metadata/kind = "([^"]*)"', l).group(1) for l in node["lines"] if l.startswith("metadata/kind")), "")
            robots.append((base[0] + here[0], base[2] + here[2], kind))
        elif node_path == "Route/Start":
            start = position(node["lines"])
        elif node_path == "Route/Exit/CollisionShape3D":
            base = position(parent["lines"])
            size = numbers(next(l for l in node["lines"] if l.startswith("shape = ")).split("size = Vector3(")[1])
            way_out = (base[0] - size[0] * 0.5, base[2] - size[2] * 0.5, size[0], size[2])

    # What to draw: the zones if there are any, or else where something stands
    # that is not part of the land around the level.
    if zones:
        left = min(z[1] for z in zones) - 6
        top = min(z[2] for z in zones) - 6
        right = max(z[1] + z[3] for z in zones) + 6
        bottom = max(z[2] + z[4] for z in zones) + 6
    else:
        near = [c for corners, low, high in shapes if high > 0.3 and max(abs(corners[0][0] - corners[2][0]), abs(corners[0][1] - corners[2][1])) < 60 for c in corners]
        left, top = min(c[0] for c in near) - 3, min(c[1] for c in near) - 3
        right, bottom = max(c[0] for c in near) + 3, max(c[1] for c in near) + 3

    def px(x, z):
        return "%.1f,%.1f" % ((x - left) * SCALE, (z - top) * SCALE)

    width, height = (right - left) * SCALE, (bottom - top) * SCALE
    out = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" font-family="Arial" font-size="15">' % (width, height),
        '<rect width="100%" height="100%" fill="#f4f2ec"/>']
    for x in range(math.ceil(left / 5) * 5, int(right) + 1, 5):
        out.append('<rect x="%.1f" y="0" width="1" height="%d" fill="#d6d1c2"/>' % ((x - left) * SCALE, height))
    for z in range(math.ceil(top / 5) * 5, int(bottom) + 1, 5):
        out.append('<rect x="0" y="%.1f" width="%d" height="1" fill="#d6d1c2"/>' % ((z - top) * SCALE, width))
    # Low things first, so that a wall is drawn over what stands against it.
    for corners, low, high in sorted(shapes, key=lambda s: s[2]):
        if high < 0.25 or low > 2.2:
            continue
        colour = "#2b2b2b" if high >= 1.7 else "#9a968a"
        out.append('<polygon points="%s" fill="%s"/>' % (" ".join(px(*c) for c in corners), colour))
    for label, x, z, w, d in zones:
        out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="none" stroke="#3a6ea5" stroke-width="2" stroke-dasharray="8 5"/>' % ((x - left) * SCALE, (z - top) * SCALE, w * SCALE, d * SCALE))
        out.append('<text x="%.1f" y="%.1f" fill="#3a6ea5">%s</text>' % ((x - left) * SCALE + 8, (z - top) * SCALE + 20, label))
    if way_out:
        out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="#3c9a4c" fill-opacity="0.35" stroke="#3c9a4c"/>' % ((way_out[0] - left) * SCALE, (way_out[1] - top) * SCALE, way_out[2] * SCALE, way_out[3] * SCALE))
    for x, z, kind in robots:
        radius = {"heavy": 11, "rusher": 6}.get(kind, 8)
        out.append('<circle cx="%.1f" cy="%.1f" r="%d" fill="#c0392b"/>' % ((x - left) * SCALE, (z - top) * SCALE, radius))
    if start:
        out.append('<circle cx="%.1f" cy="%.1f" r="9" fill="#3c9a4c"/>' % ((start[0] - left) * SCALE, (start[2] - top) * SCALE))
    out.append("</svg>")

    folder = os.path.join(ROOT, "benchmark/results")
    os.makedirs(folder, exist_ok=True)
    svg = os.path.join(folder, "%s_map.svg" % name)
    open(svg, "w").write("\n".join(out))
    png = svg[:-4] + ".png"
    made = subprocess.run(["magick", "-font", FONT, svg, png], capture_output=True, text=True)
    print(png if made.returncode == 0 else svg + "\n(no picture, ImageMagick said: %s)" % made.stderr.strip())
    return 0


if __name__ == "__main__":
    sys.exit(main())
