#!/bin/sh
# Regenerates the factory level geometry in scenes/levels/ from tools/build_level.gd.
# Lightmaps have to be rebaked afterwards with tools/bake_lightmaps.sh.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && exec "$GODOT" --headless --path . --script tools/build_level.gd
