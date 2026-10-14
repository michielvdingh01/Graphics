#!/usr/bin/env python3
"""Fetches the map of a stretch of town that a level is drawn after, as listed
under "maps" in assets/manifest.json: the BGT (Basisregistratie Grootschalige
Topografie, by PDOK, CC0 1.0), with every quay, building, bridge, lamp post
and tree, and from the 3DBAG (TU Delft and 3DGI, CC BY 4.0) the heights of
every building. It lands in assets/maps/.source/<id>/, which is not in git:
what a level takes from it is written into its plan, with where it came from.

    tools/fetch_map.py [id]          every map when none is named

A file that is there already is not fetched again.
"""
import json
import pathlib
import sys
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
HEADERS = {"User-Agent": "GraphicsFPS-map-fetch/0.1", "Accept": "application/geo+json, application/json"}
BGT = "https://api.pdok.nl/kadaster/bgt/ogc/v1/collections/%s/items?"
DBAG = "https://data.3dbag.nl/api/BAG3D/wfs?"
RD = "http://www.opengis.net/def/crs/EPSG/0/28992"


def get(url: str) -> bytes:
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=180) as reply:
        return reply.read()


def fetch_bgt(entry: dict, folder: pathlib.Path) -> None:
    box = ",".join(str(n) for n in entry["bbox_wgs84"])
    for name in entry["bgt"]:
        target = folder / ("%s.geojson" % name)
        if target.exists():
            continue
        url = BGT % name + urllib.parse.urlencode({"bbox": box, "crs": RD, "limit": 1000, "f": "json"})
        features, size = [], 0
        while url:
            body = get(url)
            size += len(body)
            page = json.loads(body)
            features += page.get("features", [])
            url = next((link["href"] for link in page.get("links", []) if link.get("rel") == "next"), None)
        target.write_text(json.dumps({"type": "FeatureCollection", "crs": RD, "features": features}))
        print("  bgt %-28s %5d  %5.1f MB" % (name, len(features), size / 1e6))


def fetch_3dbag(entry: dict, folder: pathlib.Path) -> None:
    target = folder / "3dbag_lod13.geojson"
    if target.exists():
        return
    box = ",".join(str(n) for n in entry["bbox_rd"]) + ",EPSG:28992"
    features, size, start = [], 0, 0
    while True:
        body = get(DBAG + urllib.parse.urlencode({"service": "WFS", "version": "2.0.0", "request": "GetFeature", "typeNames": "BAG3D:lod13",
            "bbox": box, "outputFormat": "application/json", "count": "1000", "startIndex": str(start), "sortBy": "fid"}))
        size += len(body)
        page = json.loads(body).get("features", [])
        features += page
        start += len(page)
        if len(page) < 1000:
            break
    target.write_text(json.dumps({"type": "FeatureCollection", "crs": RD, "features": features}))
    print("  3dbag lod13 %5d  %5.1f MB" % (len(features), size / 1e6))


def main() -> None:
    manifest = json.loads((ROOT / "assets/manifest.json").read_text())
    for entry in manifest.get("maps", []):
        if len(sys.argv) > 1 and entry["id"] not in sys.argv[1:]:
            continue
        folder = ROOT / "assets/maps/.source" / entry["id"]
        folder.mkdir(parents=True, exist_ok=True)
        print(entry["id"])
        fetch_bgt(entry, folder)
        fetch_3dbag(entry, folder)


if __name__ == "__main__":
    main()
