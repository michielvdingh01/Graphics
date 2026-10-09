#!/usr/bin/env python3
"""Fetches one avatar of the Microsoft Rocketbox library (MIT) for
tools/import_character.sh: tools/characters/fetch_rocketbox.py Military_Male_01

Downloads the FBX and its textures to assets/characters/.source/rocketbox/,
which is not in git, and prints the path of the FBX. Does nothing when the
avatar is already there.
"""
import json
import pathlib
import sys
import urllib.request

REPO = "microsoft/Microsoft-Rocketbox"
API = "https://api.github.com/repos/%s/contents/Assets/Avatars/%s/%s/%s"
ROOT = pathlib.Path(__file__).resolve().parents[2] / "assets/characters/.source/rocketbox"


def listing(group: str, name: str, folder: str) -> list:
    try:
        with urllib.request.urlopen(API % (REPO, group, name, folder)) as reply:
            return json.load(reply)
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return []
        raise


def fetch(name: str) -> pathlib.Path:
    target = ROOT / name
    fbx = target / (name + ".fbx")
    if (target / "complete").exists():
        return fbx
    for group in ("Adults", "Professions", "Children"):
        files = listing(group, name, "Export") + listing(group, name, "Textures")
        if files:
            break
    else:
        sys.exit("fetch_rocketbox: no avatar named %s" % name)
    target.mkdir(parents=True, exist_ok=True)
    for entry in files:
        # The second FBX carries face bones nothing here uses.
        if entry["name"].endswith("_facial.fbx"):
            continue
        path = target / entry["name"]
        if not path.exists() or path.stat().st_size != entry["size"]:
            print("  %s (%.1f MB)" % (entry["name"], entry["size"] / 1e6), file=sys.stderr)
            urllib.request.urlretrieve(entry["download_url"], path)
    (target / "complete").touch()
    return fbx


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    for avatar in sys.argv[1:]:
        print(fetch(avatar))
