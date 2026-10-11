#!/usr/bin/env python3
"""From a model file to a character in the project, in one go.

    tools/import_character.sh <file> <id> [options]

1. Blender (prepare.py) cleans the model up, thins it to 20 thousand triangles,
   brings its textures down to one 1K set, names its skeleton after Godot's
   humanoid profile, or fits one when it has none, and writes
   assets/characters/<id>/<id>.glb.
2. Godot imports that with the retarget switched on and lightmap UVs off.
3. check.gd holds the result against the contract with the rig.
4. sheet.gd renders the contact sheet to assets/characters/sheets/<id>.jpg.
5. The character gets its line in assets/characters/manifest.json.

Where it came from goes in the manifest: --source, --url, --license, --author,
and for a generated model --prompt and --model. --placeholder="why" marks a
character that stands in for something better, and --wanted="..." describes
that something, as a prompt for whatever is going to make it. Everything else
is passed on to prepare.py; the ones that matter:

    --height=1.8        scale to this many metres (default: guess the unit)
    --scale=1.1         after that, make it this much bigger
    --wide=1.1          and this much broader without making it taller
    --yaw=180           turn it by hand instead of guessing the front
    --triangles=20000   the budget
    --drop=REGEX        objects and materials to leave out, besides weapons
    --keep-weapons      keep what looks like a weapon by its name
    --bones=map.json    profile bone -> source bone, when guessing fails
    --route=scan        treat it as a statue even though it has a skeleton
    --look=zombie       paint it up as a zombie or a clown
    --no-delight        scan: leave the light that is baked into the texture
    --baggy             scan: the legs are in one garment down to the knees
    --keep=DIR          leave the Blender scene and the textures there
    --report=FILE       leave what Blender measured there, joints and all
    --no-manifest       a try-out: do not put it in the manifest
    --no-sheet          skip the contact sheet

Blender runs without a window (blender -b). Set BLENDER or GODOT when they are
not where Homebrew and /Applications put them.
"""
import argparse
import datetime
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
HERE = pathlib.Path(__file__).resolve().parent
CHARACTERS = ROOT / "assets/characters"
MANIFEST = CHARACTERS / "manifest.json"
BLENDER = os.environ.get("BLENDER") or shutil.which("blender") or "/Applications/Blender.app/Contents/MacOS/Blender"
GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
NOISE = re.compile(r"RID allocations|Leaked instance|^ *at: |resources still in use|ObjectDB instances leaked|PagedAllocator|^\s*$")

# What a character is imported with. The retarget renames the skeleton to
# GeneralSkeleton and turns its rest pose into the profile's T-pose; the feet
# are left out of that, because a foot that is made to lie along the profile's
# flat foot bone stands on its heel. A character moves, so a lightmap is no use.
IMPORT = """[remap]

importer="scene"
type="PackedScene"
%s
[deps]

source_file="res://assets/characters/{id}/{id}.glb"

[params]

meshes/ensure_tangents=true
meshes/generate_lods=true
meshes/create_shadow_meshes=true
meshes/light_baking=0
skins/use_named_skins=true
animation/import=false
_subresources={{
"nodes": {{
"PATH:Armature/Skeleton3D": {{
"retarget/bone_map": Resource("res://assets/characters/humanoid_bone_map.tres"),
"retarget/rest_fixer/fix_silhouette/enable": true,
"retarget/rest_fixer/fix_silhouette/filter": [&"LeftFoot", &"RightFoot", &"LeftToes", &"RightToes"]
}}
}}
}}
gltf/embedded_image_handling=2
"""


def run(command: list, what: str) -> str:
    """Runs one step and returns what it printed; stops with its output when it fails."""
    done = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, stdin=subprocess.DEVNULL)
    lines = [line for line in done.stdout.splitlines() if not NOISE.search(line)]
    if done.returncode != 0:
        tail = [line for line in lines if "import_character:" in line or "check:" in line or "sheet:" in line]
        if not tail or any("Traceback" in line for line in lines):
            tail = lines[-25:]
        sys.exit("import_character: %s failed\n%s" % (what, "\n".join(tail)))
    return "\n".join(lines)


def fact(output: str, prefix: str) -> dict:
    line = next((line for line in output.splitlines() if line.startswith(prefix)), None)
    return json.loads(line[len(prefix):]) if line else {}


def main() -> None:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("file", nargs="?")
    parser.add_argument("id", nargs="?")
    for name in ("source", "url", "license", "author", "prompt", "model", "placeholder", "wanted", "note"):
        parser.add_argument("--" + name, default="")
    parser.add_argument("--no-sheet", action="store_true")
    parser.add_argument("--no-manifest", action="store_true")
    parser.add_argument("--report", default="")
    args, rest = parser.parse_known_args()
    if not args.file or not args.id:
        sys.exit(__doc__)
    if not re.fullmatch(r"[a-z][a-z0-9_]*", args.id):
        sys.exit("import_character: an id is lower case letters, digits and underscores: %s" % args.id)
    source = pathlib.Path(args.file).resolve()
    if not source.exists():
        sys.exit("import_character: no such file: %s" % args.file)
    if not pathlib.Path(BLENDER).exists():
        sys.exit("import_character: Blender is not installed; brew install --cask blender, or set BLENDER")

    folder = CHARACTERS / args.id
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / (args.id + ".glb")
    settings = pathlib.Path(str(target) + ".import")
    # Keep the uid when a character is imported again, so scenes that refer to it still find it.
    uid = re.search(r'^uid="[^"]+"$', settings.read_text(), re.M) if settings.exists() else None

    print("%s: preparing in Blender" % args.id)
    with tempfile.TemporaryDirectory() as scratch:
        report_file = pathlib.Path(scratch) / "report.json"
        # Without the exit code Blender calls a script that fell over a success.
        run([BLENDER, "-b", "--factory-startup", "--python-exit-code", "1", "--python", str(HERE / "prepare.py"), "--",
             str(source), str(target), "--id", args.id, "--report", str(report_file)] + rest, "Blender")
        report = json.loads(report_file.read_text())
        if args.report:
            shutil.copy(report_file, args.report)
    settings.write_text(IMPORT.format(id=args.id) % ((uid.group(0) + "\n") if uid else ""))

    print("%s: importing in Godot" % args.id)
    run([GODOT, "--headless", "--path", str(ROOT), "--import"], "the Godot import")
    checked = subprocess.run([GODOT, "--headless", "--path", str(ROOT), "--script", "tools/characters/check.gd", "--", args.id],
                             cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, stdin=subprocess.DEVNULL)
    facts = fact(checked.stdout, "check: ")
    if not args.no_sheet:
        run([str(ROOT / "tools/godot.sh"), "--script", "res://tools/characters/sheet.gd", "--", args.id], "the contact sheet")

    try:
        where = str(source.relative_to(ROOT))
    except ValueError:
        # A scan of a friend lives outside the project; only its name goes on record.
        where = source.name
    entry = {
        "source": args.source or where,
        "url": args.url,
        "license": args.license or "unknown",
        "author": args.author,
        "placeholder": args.placeholder,
        "wanted": args.wanted,
        "prompt": args.prompt,
        "model": args.model,
        "note": args.note,
        "file": where,
        "options": " ".join(rest),
        "route": report.get("route"),
        "look": report.get("look", {}).get("name", ""),
        "triangles": facts.get("triangles", report.get("triangles")),
        "source_triangles": report.get("source_triangles"),
        "height": facts.get("height"),
        "eye_height": facts.get("eye_height"),
        "head_start": facts.get("head_start"),
        "megabytes": round(target.stat().st_size / 1e6, 2),
        "textures": report.get("textures"),
        "fitted": report.get("fitted"),
        "imported": datetime.date.today().isoformat(),
        "tools": "Blender %s" % report.get("blender", "?"),
    }
    if not args.no_manifest:
        manifest = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
        manifest.setdefault("themes", {})
        manifest.setdefault("characters", {})[args.id] = {key: value for key, value in entry.items() if value not in ("", None)}
        manifest["characters"] = dict(sorted(manifest["characters"].items()))
        MANIFEST.write_text(json.dumps(manifest, indent="\t", ensure_ascii=False) + "\n")

    print("%s: %s route, %s triangles (from %s), %.2f m tall, %.1f MB" % (
        args.id, entry["route"], entry["triangles"], entry["source_triangles"], entry["height"] or 0.0, entry["megabytes"]))
    if not args.license:
        print("%s: no --license given; the manifest says 'unknown'" % args.id)
    if not args.no_sheet:
        print("%s: look at assets/characters/sheets/%s.jpg" % (args.id, args.id))
    problems = facts.get("problems", ["the check did not run:\n" + checked.stdout[-800:]])
    for problem in problems:
        print("%s: BREAKS THE CONTRACT: %s" % (args.id, problem))
    if problems:
        sys.exit(1)


if __name__ == "__main__":
    main()
