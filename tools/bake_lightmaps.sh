#!/bin/sh
# Bakes the lightmaps of the factory scene (or the scene given as argument).
# Runs the editor for the duration of the bake, since baking needs the GPU.
# A level that is cut into zones has a lightmap per zone; a second argument
# names the zones to bake, separated by commas, instead of all of them:
#   tools/bake_lightmaps.sh res://scenes/factory.tscn annex
BAKE_LIGHTMAPS="${1:-res://scenes/factory.tscn}" BAKE_ZONES="$2" exec "$(dirname "$0")/godot.sh" --editor
