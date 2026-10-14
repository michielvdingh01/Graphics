#!/usr/bin/env python3
"""Draws the plan of the canals from above, from what describes it and what
was built from it: the water, the quays, the blocks, the bridges and the
steps from tools/levels/canals/plan.gd, the round, the fights and the
checkpoints from scenes/levels/canals_level.tscn. Beside it, at the same
scale and turned the same way, the town as the map has it, when the map is
there (tools/fetch_map.py): where the level is drawn after.

    tools/canals_sheet.py            benchmark/sheets/canals_plan.png

Build the level first (tools/build_level.sh canals). It needs rsvg-convert:
ImageMagick's own SVG renderer drops dashes and turned text.
"""
import json
import math
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEVEL = os.path.join(ROOT, "tools/levels/canals")
MAP = os.path.join(ROOT, "assets/maps/.source/amsterdam_spiegel_vijzel")
OUT = os.path.join(ROOT, "benchmark/sheets/canals_plan.png")
S = 2.6  # pixels to a metre
M = 40
TOP = M + 70  # where the drawings begin, under their titles
## The map is drawn at two thirds, as the lengths of the level are, over the
## same stretch of town: from these u and v of the frame of the map.
SHRINK = 2.0 / 3.0
MAP_FROM = (-125.0, -100.0)
MAP_SIZE = (330.0, 720.0)


def constants(*files):
    """The constants of GDScript files, worked out in Python: numbers, lists,
    and what is reckoned from those."""
    found = {"Vector3": lambda x, y, z: (x, y, z), "Rect2": lambda x, y, w, h: (x, y, w, h), "lerpf": lambda a, b, t: a + (b - a) * t}
    for name in files:
        text = open(os.path.join(LEVEL, name)).read()
        lines = text.split("\n")
        i = 0
        while i < len(lines):
            match = re.match(r"const (\w+)(?:\s*:\s*[^=]+)?\s*:?=\s*(.*)$", lines[i])
            i += 1
            if not match:
                continue
            body = match.group(2)
            while body.count("[") + body.count("{") + body.count("(") > body.count("]") + body.count("}") + body.count(")"):
                body += lines[i]
                i += 1
            try:
                found[match.group(1)] = eval(body.replace("true", "True").replace("false", "False"), {"__builtins__": {}}, found)
            except Exception:
                pass
    return found


def route():
    """Start, fights with their enemies, checkpoints and the exit, from the
    built level: (kind, x, z, extra)."""
    text = open(os.path.join(ROOT, "scenes/levels/canals_level.tscn")).read()
    nodes = re.findall(r'\[node name="([^"]+)" type="(\w+)" parent="([^"]*)"[^\n]*\]\n((?:[^\[\n].*\n)*)', text)
    origin = {}
    out = []
    for name, kind, parent, body in nodes:
        xf = re.search(r"transform = Transform3D\(([^)]*)\)", body)
        pos = re.search(r"position = Vector3\(([^)]*)\)", body)
        at = [float(n) for n in xf.group(1).split(",")][9:12] if xf else [float(n) for n in pos.group(1).split(",")] if pos else [0.0, 0.0, 0.0]
        if parent == "Route":
            origin[name] = at
            if kind == "Area3D":
                out.append((name.rstrip("0123456789").replace("Zone", "zone").replace("Checkpoint", "checkpoint").replace("Exit", "exit")[:10].split("_")[0], at[0], at[2], name))
            elif name == "Start":
                out.append(("start", at[0], at[2], name))
        elif parent.startswith("Route/") and kind == "Marker3D" and name != "Respawn":
            base = origin[parent.split("/")[1]]
            out.append(("enemy", base[0] + at[0], base[2] + at[2], parent.split("/")[1]))
    return out


def plan_svg(c, x0):
    """The plan, its west edge at x0 pixels."""
    X = lambda x: x0 + x * S
    Y = lambda z: TOP + 12 * S + z * S
    out = []
    rect = lambda a, b, c2, d, fill, extra="": out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" %s/>' % (X(a), Y(b), (c2 - a) * S, (d - b) * S, fill, extra))
    W, H = c["EAST_END"], c["SOUTH_END"]
    rect(0, 0, W, H, "#dcd5c6")
    for lines in (c["HEREN"], c["KEIZERS"], c["PRINSEN"], c["LIJNBAAN"]):
        rect(0, lines[1], W, lines[2], "#8fb4cf")
    g = c["SPIEGELGRACHT"]
    rect(g[1], c["PRINSEN"][2], g[2], c["LIJNBAAN"][1], "#8fb4cf")
    for block in c["BLOCKS"].values():
        rect(block[0], block[1], block[0] + block[2], block[1] + block[3], "#4a443d")
    rect(0, -12, c["VIJZELSTRAAT"][0], 0, "#4a443d")
    rect(c["VIJZELSTRAAT"][1], -12, W, 0, "#4a443d")
    rect(0, H, W, H + 12, "#4a443d")
    for lines, crossings in ((c["HEREN"], c["HEREN_CROSSINGS"]), (c["KEIZERS"], c["KEIZERS_CROSSINGS"]), (c["PRINSEN"], c["PRINSEN_CROSSINGS"])):
        for x, wide, _ in crossings:
            rect(x - wide / 2, lines[1] - 1, x + wide / 2, lines[2] + 1, "#b9a98a")
    rect(g[1] - 1, c["PRINSEN"][2] + 0.3, g[2] + 1, c["PRINSEN"][3] - 0.3, "#b9a98a")
    rect(g[1] - 1, c["LIJNBAAN"][0] + 0.3, g[2] + 1, c["LIJNBAAN"][1] - 0.3, "#b9a98a")
    rect(c["START_X"] - 4, c["LIJNBAAN"][1] - 1, c["START_X"] + 4, c["LIJNBAAN"][2] + 1, "#b9a98a")
    rect(c["VIJZELGRACHT"][0], c["LIJNBAAN"][1] - 1, c["VIJZELGRACHT"][1], c["LIJNBAAN"][2] + 1, "#b9a98a")
    metro = c["METRO"]
    rect(metro[0] - 4, metro[2], metro[0] + 4, metro[2] + 8, "#7a8f6a")
    fights = {}
    for kind, x, z, name in route():
        if kind == "enemy":
            fights.setdefault(name, []).append((x, z))
            out.append('<circle cx="%.1f" cy="%.1f" r="2.6" fill="#c2281e"/>' % (X(x), Y(z)))
        elif kind == "checkpoint":
            out.append('<rect x="%.1f" y="%.1f" width="11" height="11" fill="#f0b400" stroke="#333" transform="rotate(45 %.1f %.1f)"/>' % (X(x) - 5.5, Y(z) - 5.5, X(x), Y(z)))
        elif kind == "start":
            out.append('<circle cx="%.1f" cy="%.1f" r="8" fill="#1f8a3b" stroke="#fff" stroke-width="2"/>' % (X(x), Y(z)))
    for n, (name, spots) in enumerate(fights.items()):
        cx = sum(p[0] for p in spots) / len(spots)
        cz = sum(p[1] for p in spots) / len(spots)
        out.append('<text x="%.1f" y="%.1f" font-size="12" font-weight="bold" fill="#8a1a12" text-anchor="middle">%d</text>' % (X(cx), Y(cz) - 6, len(spots)))
    names = [("Herengracht", W / 2, (c["HEREN"][1] + c["HEREN"][2]) / 2, 0), ("Keizersgracht", W / 2, (c["KEIZERS"][1] + c["KEIZERS"][2]) / 2, 0),
             ("Prinsengracht", W / 2, (c["PRINSEN"][1] + c["PRINSEN"][2]) / 2, 0), ("Lijnbaansgracht", W / 2, (c["LIJNBAAN"][1] + c["LIJNBAAN"][2]) / 2, 0),
             ("Kerkstraat", W / 2, sum(c["KERK"]) / 2, 0), ("Weteringdwarsstraat", W / 2 + 10, sum(c["DWARS"]) / 2, 0),
             ("Nieuwe Spiegelstraat", c["SPIEGEL_X"], (c["HEREN"][3] + c["KEIZERS"][0]) / 2, -90), ("Spiegelgracht", c["SPIEGEL_X"], (c["PRINSEN"][3] + c["LIJNBAAN"][0]) / 2, -90),
             ("Vijzelstraat", c["VIJZEL_X"], (c["HEREN"][3] + c["KEIZERS"][0]) / 2, -90), ("Vijzelgracht", c["VIJZEL_X"] - 9, (c["PRINSEN"][3] + c["LIJNBAAN"][0]) / 2, -90)]
    for text, x, z, turn in names:
        out.append('<text x="%.1f" y="%.1f" font-size="12" font-weight="bold" fill="#14324d" text-anchor="middle" transform="rotate(%d %.1f %.1f)">%s</text>' % (X(x), Y(z) + 4, turn, X(x), Y(z), text))
    out.append('<text x="%.1f" y="%d" font-size="17" font-weight="bold" fill="#111">Het level</text>' % (x0, M + 18))
    out.append('<text x="%.1f" y="%d" font-size="12" fill="#333">rood: vijand, met het aantal per gevecht; geel: checkpoint; groen: start</text>' % (x0, M + 36))
    return out, X(W), Y(H + 12)


def map_svg(c, x0, height):
    """The town from the map, turned so that the canals run across, with the
    bend and the axes where they are; the same scale as the plan."""
    entry = next(e for e in json.load(open(os.path.join(ROOT, "assets/manifest.json")))["maps"] if e["id"] == "amsterdam_spiegel_vijzel")
    o = entry["frame"]["origin_rd"]
    a = math.radians(entry["frame"]["canals_deg"])
    along, south = (math.cos(a), math.sin(a)), (math.sin(a), -math.cos(a))
    # The Herengracht of the map at the top, as in the plan.
    u0, v0 = MAP_FROM
    X = lambda u: x0 + (u - u0) * S * SHRINK
    Y = lambda v: TOP + (v - v0) * S * SHRINK
    def uv(p):
        return ((p[0] - o[0]) * along[0] + (p[1] - o[1]) * along[1], (p[0] - o[0]) * south[0] + (p[1] - o[1]) * south[1])
    def load(name):
        path = os.path.join(MAP, name + ".geojson")
        return json.load(open(path))["features"] if os.path.exists(path) else []
    out = ['<clipPath id="map"><rect x="%.1f" y="%d" width="%.1f" height="%.1f"/></clipPath><g clip-path="url(#map)">' % (x0, TOP, MAP_SIZE[0] * S * SHRINK, MAP_SIZE[1] * S * SHRINK)]
    def poly(f, fill, stroke="none"):
        geometry = f["geometry"]
        polys = [geometry["coordinates"]] if geometry["type"] == "Polygon" else geometry["coordinates"] if geometry["type"] == "MultiPolygon" else []
        for p in polys:
            d = "".join("M" + " L".join("%.1f,%.1f" % (X(uv(q)[0]), Y(uv(q)[1])) for q in ring) + " Z " for ring in p)
            out.append('<path d="%s" fill="%s" stroke="%s" stroke-width="0.4" fill-rule="evenodd"/>' % (d, fill, stroke))
    out.append('<rect x="%.1f" y="%d" width="%.1f" height="%.1f" fill="#f3f0e8"/>' % (x0, TOP, MAP_SIZE[0] * S * SHRINK, MAP_SIZE[1] * S * SHRINK))
    for f in load("wegdeel"):
        poly(f, "#c9c4b8" if f["properties"].get("fysiek_voorkomen") == "gesloten verharding" else "#dcd5c6")
    for f in load("begroeidterreindeel"):
        poly(f, "#bccfa8")
    for f in load("waterdeel"):
        poly(f, "#8fb4cf")
    for f in load("overbruggingsdeel"):
        poly(f, "#b9a98a", "#7d6c50")
    for f in load("pand"):
        poly(f, "#4a443d")
    for f in load("vegetatieobject_punt"):
        u, v = uv(f["geometry"]["coordinates"])
        out.append('<circle cx="%.1f" cy="%.1f" r="2" fill="#3f7d3a" fill-opacity="0.75"/>' % (X(u), Y(v)))
    for f in load("paal"):
        if f["properties"].get("plus_type") == "lichtmast":
            u, v = uv(f["geometry"]["coordinates"])
            out.append('<circle cx="%.1f" cy="%.1f" r="1.7" fill="#f0b400" stroke="#6b4e00" stroke-width="0.4"/>' % (X(u), Y(v)))
    out.append("</g>")
    out.append('<text x="%.1f" y="%d" font-size="17" font-weight="bold" fill="#111">De stad op de kaart (BGT, PDOK, CC0)</text>' % (x0, M + 18))
    out.append('<text x="%.1f" y="%d" font-size="12" fill="#333">alles op twee derde, zoals de lengtes van het level: de grachten zijn hier smaller dan echt</text>' % (x0, M + 36))
    out.append('<text x="%.1f" y="%d" font-size="12" fill="#333">geel: lichtmast, groen: boom; de bocht, de schuine assen en de Weteringbuurt zoals ze zijn</text>' % (x0, M + 52))
    return out


def main():
    c = constants("plan.gd", "lijnbaan.gd", "vijzel.gd")
    plan, right, bottom = plan_svg(c, M)
    parts = plan
    width = right + M
    if os.path.isdir(MAP):
        parts += map_svg(c, right + 60, bottom)
        width = right + 60 + MAP_SIZE[0] * S * SHRINK + M
        bottom = max(bottom, TOP + MAP_SIZE[1] * S * SHRINK)
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" font-family="Arial">' % (width, bottom + M), '<rect width="100%" height="100%" fill="#f3f0e8"/>'] + parts + ["</svg>"]
    path = OUT[:-4] + ".svg"
    open(path, "w").write("\n".join(svg))
    subprocess.run(["rsvg-convert", "-o", OUT, path], check=True)
    os.remove(path)
    print(OUT)


if __name__ == "__main__":
    main()
