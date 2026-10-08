#!/bin/sh
# Bakes the lightmaps of the factory scene (or the scene given as argument).
# Runs the editor for the duration of the bake, since baking needs the GPU.
BAKE_LIGHTMAPS="${1:-res://scenes/factory.tscn}" exec "$(dirname "$0")/godot.sh" --editor
