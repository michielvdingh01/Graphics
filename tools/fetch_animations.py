#!/usr/bin/env python3
"""Downloads the animation sources listed in assets/animations/manifest.json.

Each source is a zip that can be had without an account; the files the
manifest names are taken out of it into assets/animations/ and checked
against the checksum the manifest lists. Files that already exist are
skipped. Import them afterwards (godot --headless --path . --import) and run
tools/build_moves.sh.
"""
import hashlib
import io
import json
import pathlib
import urllib.request
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
FOLDER = ROOT / "assets/animations"
HEADERS = {"User-Agent": "GraphicsFPS-asset-fetch/0.1"}


def main() -> None:
    manifest = json.loads((FOLDER / "manifest.json").read_text())
    for source in manifest["sources"]:
        missing = [entry for entry in source["files"] if not (FOLDER / entry["file"]).exists()]
        if not missing:
            continue
        print(source["name"])
        request = urllib.request.Request(source["url"], headers=HEADERS)
        with urllib.request.urlopen(request) as response:
            archive = zipfile.ZipFile(io.BytesIO(response.read()))
        for entry in missing:
            data = archive.read(entry["member"])
            if hashlib.sha256(data).hexdigest() != entry["sha256"]:
                raise SystemExit(f"checksum mismatch for {entry['member']}")
            (FOLDER / entry["file"]).write_bytes(data)
            print(f"  {entry['file']}  {len(data) / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
