#!/bin/sh
# Regenerates the procedural decal textures listed in assets/manifest.json and imports them.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && "$GODOT" --headless --path . --script tools/gen_decals.gd && exec "$GODOT" --headless --path . --import
