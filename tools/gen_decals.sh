#!/bin/sh
# Regenerates the procedural decals and masks listed in assets/manifest.json and imports them:
# all of them, or only those named.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && "$GODOT" --headless --path . --script tools/gen_decals.gd -- "$@" && exec "$GODOT" --headless --path . --import
