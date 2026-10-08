#!/usr/bin/env python3
"""Downloads the Poly Haven assets listed in assets/manifest.json.

Textures land in assets/textures/<id>/ as diff, nor_gl and arm (AO, roughness,
metallic) JPGs; HDRIs land in assets/hdri/. Files that already exist are skipped.
"""
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


def download(url: str, target: pathlib.Path) -> None:
    if target.exists():
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    data = get(url)
    target.write_bytes(data)
    print(f"  {target.relative_to(ROOT)}  {len(data) / 1e6:.1f} MB")


def main() -> None:
    manifest = json.loads((ROOT / "assets/manifest.json").read_text())
    for asset in manifest["assets"]:
        if asset["source"] != "polyhaven":
            continue
        name, res = asset["id"], asset["resolution"]
        print(name)
        files = json.loads(get(API + name))
        if asset["type"] == "texture":
            for key, suffix in TEXTURE_MAPS.items():
                url = files[key][res]["jpg"]["url"]
                download(url, ROOT / "assets/textures" / name / f"{name}_{suffix}.jpg")
        elif asset["type"] == "hdri":
            url = files["hdri"][res]["hdr"]["url"]
            download(url, ROOT / "assets/hdri" / f"{name}.hdr")


if __name__ == "__main__":
    main()
