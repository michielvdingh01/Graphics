#!/bin/sh
# Bakes the lightmaps of the factory scene (or the scene given as argument),
# and only those that changed since they were last baked. Runs the editor for
# the duration of the bake, since baking needs the GPU.
#   tools/bake_lightmaps.sh                                    what needs it, in the factory
#   tools/bake_lightmaps.sh res://scenes/depot.tscn            the same for the depot
#   tools/bake_lightmaps.sh res://scenes/factory.tscn annex    that zone, whatever its state
#   tools/bake_lightmaps.sh --list                             say what needs a bake
# See tools/bake_lightmaps.py for the rest, and for what "changed" means.
exec python3 "$(dirname "$0")/bake_lightmaps.py" "$@"
