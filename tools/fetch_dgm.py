#!/usr/bin/env python3
"""Fetches the heights of the land of Tyrol from the laser scans of the Land
Tirol (the "Gelände Tirol" WCS, CC BY 4.0 AT: Land Tirol, data.tirol.gv.at)
for the maps of assets/manifest.json that have source "tirol_wcs", and lays
them out as the level reads them: a grid in metres from the middle of the
Ehrwald basin (x to the east, z to the south, as tools/levels/alps/dem.gd has
it), stored as a PNG in the terrarium encoding of the AWS tiles (height =
r * 256 + g + b / 256 - 32768), so that a centimetre and a half is the finest
step and Godot reads it as any picture.

    tools/fetch_dgm.py [id ...]

The scans lie in the grid of the Austrian land survey, Gauss-Krüger west on
the Bessel ellipsoid (EPSG:31254); the level's metres are worked out from the
latitude and longitude of the middle of the basin. Every spot of the level's
grid is turned into that survey grid and read there between its four nearest
heights. What the scans leave out (beyond the border of Tyrol) is written as
nought, which dem.gd takes for "not here".

Plain Python: no GDAL, no numpy.
"""
import hashlib
import json
import math
import pathlib
import struct
import sys
import urllib.request
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
WCS = "https://gis.tirol.gv.at/arcgis/services/Service_Public/terrain/MapServer/WCSServer"
HEADERS = {"User-Agent": "GraphicsFPS-map-fetch/0.1"}
# The middle of the Moos, as tools/levels/alps/dem.gd has it.
LAT = 47.405
LON = 10.905
# The most dots the service gives in one piece each way.
PIECE = 3000


# --- From latitude and longitude to the Austrian survey grid -----------------

WGS84 = (6378137.0, 1.0 / 298.257223563)
BESSEL = (6377397.155, 1.0 / 299.1528128)
# MGI to WGS 84 as PROJ has it for EPSG:31254 (+towgs84, position vector
# rotation): metres, seconds of arc and parts per million. Going the other
# way the signs turn. Read as a coordinate frame rotation instead, the land
# came out 35 m off the AWS tiles; as this, within two metres of them.
HELMERT = (577.326, 90.129, 463.919, 5.137, 1.474, 5.297, 2.4232)


def _cartesian(lat, lon, h, ellipsoid):
    a, f = ellipsoid
    e2 = f * (2.0 - f)
    p, l = math.radians(lat), math.radians(lon)
    n = a / math.sqrt(1.0 - e2 * math.sin(p) ** 2)
    return ((n + h) * math.cos(p) * math.cos(l), (n + h) * math.cos(p) * math.sin(l), (n * (1.0 - e2) + h) * math.sin(p))


def _geodetic(x, y, z, ellipsoid):
    a, f = ellipsoid
    e2 = f * (2.0 - f)
    lon = math.atan2(y, x)
    p = math.hypot(x, y)
    lat = math.atan2(z, p * (1.0 - e2))
    for _ in range(6):
        n = a / math.sqrt(1.0 - e2 * math.sin(lat) ** 2)
        lat = math.atan2(z + e2 * n * math.sin(lat), p)
    return math.degrees(lat), math.degrees(lon)


def _to_mgi(lat, lon):
    x, y, z = _cartesian(lat, lon, 1000.0, WGS84)
    tx, ty, tz, rx, ry, rz, s = HELMERT
    # The inverse of MGI -> WGS 84, near enough: every term with its sign
    # turned (the rotations are a few seconds).
    k = 1.0 - s * 1e-6
    rx, ry, rz = (math.radians(v / 3600.0) for v in (rx, ry, rz))
    x, y, z = x - tx, y - ty, z - tz
    x2 = k * (x + rz * y - ry * z)
    y2 = k * (-rz * x + y + rx * z)
    z2 = k * (ry * x - rx * y + z)
    return _geodetic(x2, y2, z2, BESSEL)


def _gauss_kruger(lat, lon, meridian=10.0 + 20.0 / 60.0, false_north=-5000000.0):
    """Transverse Mercator on the Bessel ellipsoid, scale one on the
    meridian: the series of the Krüger, to the sixth power."""
    a, f = BESSEL
    n = f / (2.0 - f)
    big_a = a / (1.0 + n) * (1.0 + n * n / 4.0 + n ** 4 / 64.0)
    alpha = (n / 2.0 - 2.0 * n * n / 3.0 + 5.0 * n ** 3 / 16.0,
             13.0 * n * n / 48.0 - 3.0 * n ** 3 / 5.0,
             61.0 * n ** 3 / 240.0)
    p = math.radians(lat)
    l = math.radians(lon - meridian)
    e = math.sqrt(f * (2.0 - f))
    t = math.sinh(math.atanh(math.sin(p)) - e * math.atanh(e * math.sin(p)))
    xi = math.atan2(t, math.cos(l))
    eta = math.atanh(math.sin(l) / math.sqrt(1.0 + t * t))
    north, east = xi, eta
    for j, aj in enumerate(alpha, start=1):
        north += aj * math.sin(2 * j * xi) * math.cosh(2 * j * eta)
        east += aj * math.cos(2 * j * xi) * math.sinh(2 * j * eta)
    return big_a * east, big_a * north + false_north


def survey(lat, lon):
    """(easting, northing) of EPSG:31254 for a WGS 84 latitude and longitude."""
    return _gauss_kruger(*_to_mgi(lat, lon))


def _degrees_per_metre():
    phi = math.radians(LAT)
    north = 111132.954 - 559.822 * math.cos(2.0 * phi) + 1.175 * math.cos(4.0 * phi)
    east = 111412.84 * math.cos(phi) - 93.5 * math.cos(3.0 * phi)
    return north, east


def level_to_survey(x, z):
    north, east = _degrees_per_metre()
    return survey(LAT - z / north, LON + x / east)


# --- Fetching ---------------------------------------------------------------

def _tiff(data):
    """The heights of an uncompressed float32 TIFF, in strips or tiles:
    (width, height, list of floats, row by row)."""
    order = "<" if data[:2] == b"II" else ">"
    first = struct.unpack_from(order + "I", data, 4)[0]
    count = struct.unpack_from(order + "H", data, first)[0]
    tags = {}
    sizes = {1: 1, 2: 1, 3: 2, 4: 4, 5: 8, 11: 4, 12: 8, 16: 8}
    codes = {1: "B", 2: "c", 3: "H", 4: "I", 11: "f", 12: "d", 16: "Q"}
    for i in range(count):
        tag, kind, n, value = struct.unpack_from(order + "HHII", data, first + 2 + i * 12)
        if kind not in codes:
            continue
        size = sizes[kind] * n
        at = first + 2 + i * 12 + 8 if size <= 4 else value
        tags[tag] = struct.unpack_from(order + codes[kind] * n, data, at)
    width, height = tags[256][0], tags[257][0]
    if tags.get(259, (1,))[0] != 1 or tags.get(339, (1,))[0] != 3 or tags[258][0] != 32:
        raise SystemExit("expected an uncompressed float32 TIFF, got tags %s" % {k: tags[k] for k in (258, 259, 339) if k in tags})
    out = [0.0] * (width * height)
    if 322 in tags:
        tw, th = tags[322][0], tags[323][0]
        across = (width + tw - 1) // tw
        for t, offset in enumerate(tags[324]):
            x0, y0 = (t % across) * tw, (t // across) * th
            tile = struct.unpack_from(order + "%df" % (tw * th), data, offset)
            for y in range(min(th, height - y0)):
                row = (y0 + y) * width + x0
                n = min(tw, width - x0)
                out[row:row + n] = tile[y * tw:y * tw + n]
    else:
        rows = tags.get(278, (height,))[0]
        y = 0
        for offset in tags[273]:
            n = min(rows, height - y) * width
            out[y * width:y * width + n] = struct.unpack_from(order + "%df" % n, data, offset)
            y += rows
    return width, height, out


def _get_piece(coverage, e0, n0, e1, n1, cell, native):
    """One piece of the survey grid, every `cell` metres: (width, height,
    heights, bytes fetched). The service (ArcGIS) takes its scale factor as
    how many of its own dots go into one: 2 for a metre from half metres,
    the other way round from what WCS 2.0 says."""
    url = (f"{WCS}?service=WCS&version=2.0.1&request=GetCoverage&coverageId={coverage}"
           f"&format=image/tiff&subset=y({n0:.2f},{n1:.2f})&subset=x({e0:.2f},{e1:.2f})")
    if cell != native:
        url += f"&scalefactor={cell / native:g}"
    # What was fetched once is kept, so that laying it out again costs nothing.
    cache = ROOT / ".cache/dgm" / (hashlib.md5(url.encode()).hexdigest() + ".bin")
    if cache.exists():
        data = cache.read_bytes()
    else:
        with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=300) as response:
            data = response.read()
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_bytes(data)
    start = data.find(b"II*\x00")
    if start < 0:
        start = data.find(b"MM\x00*")
    if start < 0:
        raise SystemExit("no TIFF in the answer to %s:\n%s" % (url, data[:600]))
    return _tiff(data[start:]) + (len(data),)


def fetch(coverage, east0, north0, east1, north1, cell, native):
    """The heights of the survey grid between (east0, north0) and (east1,
    north1) every `cell` metres, from the north-west corner row by row,
    fetched in pieces: (columns, rows, heights)."""
    columns = int(round((east1 - east0) / cell))
    rows = int(round((north1 - north0) / cell))
    heights = [0.0] * (columns * rows)
    # First a piece of twenty dots each way: if the service gives another
    # size, the large pieces would be wrong too, and might be many times
    # larger than asked for.
    w, h, _, _ = _get_piece(coverage, east0, north1 - 20 * cell, east0 + 20 * cell, north1, cell, native)
    if abs(w - 20) > 1 or abs(h - 20) > 1:
        raise SystemExit(f"{coverage}: asked for 20 x 20 dots of {cell} m, got {w} x {h}; not fetching the rest")
    for r0 in range(0, rows, PIECE):
        for c0 in range(0, columns, PIECE):
            nc, nr = min(PIECE, columns - c0), min(PIECE, rows - r0)
            e0, e1 = east0 + c0 * cell, east0 + (c0 + nc) * cell
            n1 = north1 - r0 * cell
            n0 = n1 - nr * cell
            w, h, piece, size = _get_piece(coverage, e0, n0, e1, n1, cell, native)
            print(f"  {coverage} piece {c0},{r0}: {w} x {h} dots, {size / 1e6:.1f} MB")
            if abs(w - nc) > 1 or abs(h - nr) > 1:
                raise SystemExit(f"{coverage}: asked for {nc} x {nr} dots, got {w} x {h}")
            for y in range(min(h, nr)):
                row = (r0 + y) * columns + c0
                n = min(w, nc)
                heights[row:row + n] = piece[y * w:y * w + n]
    return columns, rows, heights


def _png(path, width, height, rgb):
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)
    raw = bytearray()
    stride = width * 3
    for y in range(height):
        raw.append(0)
        raw += rgb[y * stride:(y + 1) * stride]
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


def lay_out(entry):
    """Fetches one map of the manifest and writes it as the level reads it."""
    x0, z0, x1, z1 = entry["rect"]
    cell = entry["cell"]
    columns, rows = int(round((x1 - x0) / cell)) + 1, int(round((z1 - z0) / cell)) + 1
    # Where the level's grid lies in the survey grid, worked out every
    # `step` dots and in between linearly: the turn of the one grid against
    # the other changes by less than a millimetre over that.
    step = max(1, int(round(50.0 / cell)))
    knots_c, knots_r = columns // step + 2, rows // step + 2
    knots = [level_to_survey(x0 + min(c * step, columns - 1) * cell, z0 + min(r * step, rows - 1) * cell)
             for r in range(knots_r) for c in range(knots_c)]
    margin = 4.0 * entry["fetch_cell"]
    east0 = math.floor((min(k[0] for k in knots) - margin) / entry["native"]) * entry["native"]
    east1 = math.ceil((max(k[0] for k in knots) + margin) / entry["native"]) * entry["native"]
    north0 = math.floor((min(k[1] for k in knots) - margin) / entry["native"]) * entry["native"]
    north1 = math.ceil((max(k[1] for k in knots) + margin) / entry["native"]) * entry["native"]
    fc = entry["fetch_cell"]
    east1 = east0 + math.ceil((east1 - east0) / fc) * fc
    north0 = north1 - math.ceil((north1 - north0) / fc) * fc
    print(f"{entry['id']}: survey grid E {east0:.0f}..{east1:.0f}, N {north0:.0f}..{north1:.0f}, every {fc} m")
    sw, sh, survey_heights = fetch(entry["coverage"], east0, north0, east1, north1, fc, entry["native"])
    nodata = 0
    rgb = bytearray(columns * rows * 3)
    for r in range(rows):
        kr, tr = divmod(r, step)
        tr /= step
        for c in range(columns):
            kc, tc = divmod(c, step)
            tc /= step
            a = knots[kr * knots_c + kc]
            b = knots[kr * knots_c + kc + 1]
            d = knots[(kr + 1) * knots_c + kc]
            e = knots[(kr + 1) * knots_c + kc + 1]
            east = (a[0] * (1 - tc) + b[0] * tc) * (1 - tr) + (d[0] * (1 - tc) + e[0] * tc) * tr
            north = (a[1] * (1 - tc) + b[1] * tc) * (1 - tr) + (d[1] * (1 - tc) + e[1] * tc) * tr
            # Survey dots are the middles of their squares.
            u = (east - east0) / fc - 0.5
            v = (north1 - north) / fc - 0.5
            iu, iv = int(math.floor(u)), int(math.floor(v))
            fu, fv = u - iu, v - iv
            iu, iv = max(0, min(sw - 2, iu)), max(0, min(sh - 2, iv))
            q = (survey_heights[iv * sw + iu], survey_heights[iv * sw + iu + 1],
                 survey_heights[(iv + 1) * sw + iu], survey_heights[(iv + 1) * sw + iu + 1])
            if min(q) < -1000.0 or max(q) > 9000.0:
                h = 0.0
                nodata += 1
            else:
                h = (q[0] * (1 - fu) + q[1] * fu) * (1 - fv) + (q[2] * (1 - fu) + q[3] * fu) * fv
            value = int(round((h + 32768.0) * 256.0)) if h != 0.0 else 32768 * 256
            i = (r * columns + c) * 3
            rgb[i] = value >> 16
            rgb[i + 1] = (value >> 8) & 255
            rgb[i + 2] = value & 255
    target = ROOT / entry["folder"] / entry["file"]
    target.parent.mkdir(parents=True, exist_ok=True)
    _png(target, columns, rows, rgb)
    print(f"  {target.relative_to(ROOT)}: {columns} x {rows}, {target.stat().st_size / 1e6:.1f} MB, {nodata} dots without a height")


def main():
    manifest = json.loads((ROOT / "assets/manifest.json").read_text())
    wanted = set(sys.argv[1:])
    for entry in manifest["maps"]:
        if entry.get("source") == "tirol_wcs" and (not wanted or entry["id"] in wanted):
            lay_out(entry)


if __name__ == "__main__":
    main()
