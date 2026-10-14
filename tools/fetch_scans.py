#!/usr/bin/env python3
"""Fetches the scans that tools/gen_sprigs.py renders from: the entries of
assets/manifest.json with type "scan". They land in assets/scans/<id>/, which
Godot does not import and git does not keep: what the game uses of them is
what is rendered from them.

    tools/fetch_scans.py          says what would be fetched, and how much it is
    tools/fetch_scans.py --go     fetches it

An entry lists what is wanted of an asset of Poly Haven: "maps", a
resolution and the maps at it, each as its name on the site and the format
("twig_diff.jpg"), and "model", a resolution to fetch the glTF with its
buffer and textures at. Files that are there are skipped, and every file is
checked against the checksum Poly Haven lists.
"""
import hashlib
import json
import pathlib
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
API = "https://api.polyhaven.com/files/"
HEADERS = {"User-Agent": "GraphicsFPS-asset-fetch/0.1"}
OUT = ROOT / "assets/scans"


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS)) as response:
        return response.read()


def wanted(asset):
    """The files an entry asks for: (where it lands, what the site says of it)."""
    files = json.loads(get(API + asset["id"]))
    folder = OUT / asset["id"]
    for resolution, maps in asset.get("maps", {}).items():
        for name in maps:
            stem, kind = name.rsplit(".", 1)
            yield folder / ("%s_%s_%s.%s" % (asset["id"], stem, resolution, kind)), files[stem][resolution][kind]
    if "model" in asset:
        resolution = asset["model"]
        gltf = files["gltf"][resolution]["gltf"]
        yield folder / ("%s_%s.gltf" % (asset["id"], resolution)), gltf
        for path, entry in gltf["include"].items():
            target = (folder / path).resolve()
            if not target.is_relative_to(folder.resolve()):
                raise SystemExit("%s: refusing to write outside its folder: %s" % (asset["id"], path))
            yield target, entry


def main():
    go = "--go" in sys.argv
    manifest = json.loads((ROOT / "assets/manifest.json").read_text())
    total = 0
    for asset in manifest["assets"]:
        if asset.get("type") != "scan" or asset.get("source") != "polyhaven":
            continue
        for target, entry in wanted(asset):
            total += entry["size"]
            if target.exists():
                continue
            if not go:
                print("  %-70s %6.2f MB" % (target.relative_to(ROOT), entry["size"] / 1e6))
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            data = get(entry["url"])
            if hashlib.md5(data).hexdigest() != entry["md5"]:
                raise SystemExit("checksum mismatch for %s" % entry["url"])
            target.write_bytes(data)
            print("  %-70s %6.2f MB" % (target.relative_to(ROOT), len(data) / 1e6))
    print("%.1f MB in all" % (total / 1e6))


if __name__ == "__main__":
    main()
