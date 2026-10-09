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
import urllib.parse
import urllib.request

REPO = "microsoft/Microsoft-Rocketbox"
TREE = "https://api.github.com/repos/%s/git/trees/master?recursive=1" % REPO
RAW = "https://raw.githubusercontent.com/%s/master/" % REPO
ROOT = pathlib.Path(__file__).resolve().parents[2] / "assets/characters/.source/rocketbox"


def listing() -> list:
    """Every file of the library; asked once, because GitHub only answers 60
    questions an hour from someone who is not signed in."""
    cache = ROOT / "tree.json"
    if not cache.exists():
        ROOT.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(TREE) as reply:
            cache.write_bytes(reply.read())
    return json.loads(cache.read_text())["tree"]


def fetch(name: str) -> pathlib.Path:
    target = ROOT / name
    fbx = target / (name + ".fbx")
    if (target / "complete").exists():
        return fbx
    files = []
    for entry in listing():
        parts = entry["path"].split("/")
        # Assets/Avatars/<group>/<name>/Export|Textures/<file>
        if len(parts) == 6 and parts[:2] == ["Assets", "Avatars"] and parts[3] == name and parts[4] in ("Export", "Textures"):
            files.append(entry)
    if not files:
        sys.exit("fetch_rocketbox: no avatar named %s" % name)
    target.mkdir(parents=True, exist_ok=True)
    for entry in files:
        file = entry["path"].split("/")[-1]
        # The second FBX carries face bones nothing here uses.
        if file.endswith("_facial.fbx"):
            continue
        path = target / file
        if not path.exists() or path.stat().st_size != entry["size"]:
            print("  %s (%.1f MB)" % (file, entry["size"] / 1e6), file=sys.stderr)
            urllib.request.urlretrieve(RAW + urllib.parse.quote(entry["path"]), path)
    (target / "complete").touch()
    return fbx


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    for avatar in sys.argv[1:]:
        print(fetch(avatar))
