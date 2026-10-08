#!/bin/sh
# Regenerates a level's geometry in scenes/levels/ from tools/levels/<name>.gd
# (factory when no name is given).
# Lightmaps have to be rebaked afterwards with tools/bake_lightmaps.sh.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && exec "$GODOT" --headless --path . --script "tools/levels/${1:-factory}.gd"
