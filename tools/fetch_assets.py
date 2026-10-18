#!/usr/bin/env python3
"""Downloads the Poly Haven assets listed in assets/manifest.json.

Textures land in assets/textures/<id>/ as diff, nor_gl and arm (AO, roughness,
metallic) JPGs; HDRIs land in assets/hdri/; models land in assets/models/<id>/
as a glTF file with its buffer and textures. Files that already exist are
skipped, and every download is checked against the checksum Poly Haven lists.
"""
import hashlib
import json
import pathlib
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
API = "https://api.polyhaven.com/files/"
HEADERS = {"User-Agent": "GraphicsFPS-asset-fetch/0.1"}
TEXTURE_MAPS = {"Diffuse": "diff", "nor_gl": "nor_gl", "arm": "arm"}


def get(url: str) -> bytes:
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS)) as response:
        return response.read()


def download(entry: dict, target: pathlib.Path) -> None:
    if target.exists():
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    data = get(entry["url"])
    if hashlib.md5(data).hexdigest() != entry["md5"]:
        raise SystemExit(f"checksum mismatch for {entry['url']}")
    target.write_bytes(data)
    print(f"  {target.relative_to(ROOT)}  {len(data) / 1e6:.1f} MB")


def main() -> None:
    manifest = json.loads((ROOT / "assets/manifest.json").read_text())
    for asset in manifest["assets"]:
        if asset["source"] != "polyhaven" or asset["type"] not in ("texture", "hdri", "model"):
            continue
        name, res = asset["id"], asset["resolution"]
        print(name)
        files = json.loads(get(API + name))
        if asset["type"] == "texture":
            for key, suffix in TEXTURE_MAPS.items():
                download(files[key][res]["jpg"], ROOT / "assets/textures" / name / f"{name}_{suffix}.jpg")
        elif asset["type"] == "hdri":
            download(files["hdri"][res]["hdr"], ROOT / "assets/hdri" / f"{name}.hdr")
        elif asset["type"] == "model":
            # The glTF refers to its buffer and textures by relative path.
            folder = ROOT / "assets/models" / name
            gltf = files["gltf"][res]["gltf"]
            download(gltf, folder / f"{name}_{res}.gltf")
            for path, entry in gltf["include"].items():
                target = (folder / path).resolve()
                if not target.is_relative_to(folder):
                    raise SystemExit(f"{name}: refusing to write outside its folder: {path}")
                download(entry, target)


if __name__ == "__main__":
    main()
