#!/bin/sh
# Renders the sprigs listed in assets/manifest.json (source "rendered") in Blender, on the CPU, and imports them:
# all of them, or only those named.
BLENDER="${BLENDER:-/opt/homebrew/bin/blender}"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && "$BLENDER" -b --factory-startup --python tools/gen_sprigs.py -- "$@" | grep -v "| Saved: \|^Fra:\|^Saved:\|^ Time:\|^$" && exec "$GODOT" --headless --path . --import
