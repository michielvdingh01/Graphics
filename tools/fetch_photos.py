#!/usr/bin/env python3
"""Fetches the aerial photographs of the Land Tirol (the orthophoto WMS,
CC BY 4.0 AT: Land Tirol, data.tirol.gv.at) for the maps of
assets/manifest.json that have source "tirol_wms", and lays them out as the
level reads them: a picture in metres from the middle of the Ehrwald basin
(x to the east, z to the south, as tools/levels/alps/dem.gd has it), a dot
every `cell` metres, as a JPEG.

    tools/fetch_photos.py [id ...]

The level does not paint with them: they were flown in summer at about noon,
with the shadows that go with it. It reads from them what covers the ground,
wood, meadow, rock, scree, firn (tools/levels/alps/vista.gd).

The photographs lie in the grid of the Austrian land survey (EPSG:31254), as
the heights do; tools/fetch_dgm.py turns the level's metres into it. Needs
ImageMagick (magick) to read and write the pictures.
"""
import hashlib
import json
import math
import pathlib
import subprocess
import sys
import tempfile
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import fetch_dgm  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
WMS = "https://gis.tirol.gv.at/arcgis/services/Service_Public/orthofoto/MapServer/WMSServer"
LAYER = "Image_Aktuell_RGB"
# The most dots the service gives in one picture each way.
PIECE = 4000


def _get(url):
    cache = ROOT / ".cache/photos" / (hashlib.md5(url.encode()).hexdigest() + ".jpg")
    if cache.exists():
        return cache.read_bytes()
    with urllib.request.urlopen(urllib.request.Request(url, headers=fetch_dgm.HEADERS), timeout=300) as response:
        data = response.read()
    if not data.startswith(b"\xff\xd8"):
        raise SystemExit("no JPEG in the answer to %s:\n%s" % (url, data[:600]))
    cache.parent.mkdir(parents=True, exist_ok=True)
    cache.write_bytes(data)
    return data


def _rgb(jpeg, folder):
    """The dots of a JPEG: (width, height, bytes, three a dot)."""
    source = pathlib.Path(folder) / "in.jpg"
    source.write_bytes(jpeg)
    size = subprocess.run(["magick", "identify", "-format", "%w %h", str(source)], capture_output=True, text=True, check=True).stdout.split()
    raw = pathlib.Path(folder) / "in.rgb"
    subprocess.run(["magick", str(source), "-depth", "8", "rgb:" + str(raw)], check=True)
    return int(size[0]), int(size[1]), raw.read_bytes()


def lay_out(entry):
    x0, z0, x1, z1 = entry["rect"]
    cell = entry["cell"]
    columns, rows = int(round((x1 - x0) / cell)) + 1, int(round((z1 - z0) / cell)) + 1
    corners = [fetch_dgm.level_to_survey(x, z) for x in (x0, x1) for z in (z0, z1)]
    margin = 4.0 * cell
    east0 = math.floor(min(c[0] for c in corners) - margin)
    east1 = math.ceil(max(c[0] for c in corners) + margin)
    north0 = math.floor(min(c[1] for c in corners) - margin)
    north1 = math.ceil(max(c[1] for c in corners) + margin)
    wide = int(math.ceil((east1 - east0) / cell))
    high = int(math.ceil((north1 - north0) / cell))
    east1, north0 = east0 + wide * cell, north1 - high * cell
    if wide > PIECE or high > PIECE:
        raise SystemExit(f"{entry['id']}: {wide} x {high} dots is more than one picture of the service")
    url = (f"{WMS}?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap&LAYERS={LAYER}&STYLES=&SRS=EPSG:31254"
           f"&BBOX={east0},{north0},{east1},{north1}&WIDTH={wide}&HEIGHT={high}&FORMAT=image/jpeg")
    jpeg = _get(url)
    print(f"{entry['id']}: survey grid E {east0}..{east1}, N {north0}..{north1}, {wide} x {high} dots, {len(jpeg) / 1e6:.1f} MB")
    with tempfile.TemporaryDirectory() as folder:
        w, h, dots = _rgb(jpeg, folder)
        if (w, h) != (wide, high):
            raise SystemExit(f"asked for {wide} x {high} dots, got {w} x {h}")
        # Where the level's grid lies in the picture, worked out every `step`
        # dots and in between linearly.
        step = max(1, int(round(50.0 / cell)))
        knots_c, knots_r = columns // step + 2, rows // step + 2
        knots = [fetch_dgm.level_to_survey(x0 + min(c * step, columns - 1) * cell, z0 + min(r * step, rows - 1) * cell)
                 for r in range(knots_r) for c in range(knots_c)]
        out = bytearray(columns * rows * 3)
        for r in range(rows):
            kr, tr = divmod(r, step)
            tr /= step
            for c in range(columns):
                kc, tc = divmod(c, step)
                tc /= step
                a, b = knots[kr * knots_c + kc], knots[kr * knots_c + kc + 1]
                d, e = knots[(kr + 1) * knots_c + kc], knots[(kr + 1) * knots_c + kc + 1]
                east = (a[0] * (1 - tc) + b[0] * tc) * (1 - tr) + (d[0] * (1 - tc) + e[0] * tc) * tr
                north = (a[1] * (1 - tc) + b[1] * tc) * (1 - tr) + (d[1] * (1 - tc) + e[1] * tc) * tr
                u = (east - east0) / cell - 0.5
                v = (north1 - north) / cell - 0.5
                iu, iv = int(math.floor(u)), int(math.floor(v))
                fu, fv = u - iu, v - iv
                iu, iv = max(0, min(w - 2, iu)), max(0, min(h - 2, iv))
                i00 = (iv * w + iu) * 3
                i01 = i00 + 3
                i10 = i00 + w * 3
                i11 = i10 + 3
                o = (r * columns + c) * 3
                for k in range(3):
                    out[o + k] = int(round((dots[i00 + k] * (1 - fu) + dots[i01 + k] * fu) * (1 - fv) + (dots[i10 + k] * (1 - fu) + dots[i11 + k] * fu) * fv))
        raw = pathlib.Path(folder) / "out.rgb"
        raw.write_bytes(bytes(out))
        target = ROOT / entry["folder"] / entry["file"]
        target.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["magick", "-size", f"{columns}x{rows}", "-depth", "8", "rgb:" + str(raw), "-quality", "92", str(target)], check=True)
    print(f"  {target.relative_to(ROOT)}: {columns} x {rows}, {target.stat().st_size / 1e6:.1f} MB")


def main():
    manifest = json.loads((ROOT / "assets/manifest.json").read_text())
    wanted = set(sys.argv[1:])
    for entry in manifest["maps"]:
        if entry.get("source") == "tirol_wms" and (not wanted or entry["id"] in wanted):
            lay_out(entry)


if __name__ == "__main__":
    main()
