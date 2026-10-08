#!/bin/sh
# Bakes the lightmaps of the factory scene (or the scene given as argument).
# Opens the editor for the duration of the bake, since baking needs the GPU.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && BAKE_LIGHTMAPS="${1:-res://scenes/factory.tscn}" exec "$GODOT" --path . --editor
