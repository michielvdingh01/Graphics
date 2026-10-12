#!/bin/sh
# Draws the foliage, nets and wire listed in assets/manifest.json (source "drawn") and imports them:
# all of them, or only those named.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && "$GODOT" --headless --path . --script tools/gen_foliage.gd -- "$@" && exec "$GODOT" --headless --path . --import
