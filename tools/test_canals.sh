#!/bin/sh
# Runs the headless test of whether the canals and the test quay can be got
# through as they were last built: wading every canal, the steps out of it,
# and walking every quay, street and bridge. Exits non-zero when a check fails.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && exec "$GODOT" --headless --path . --script tools/test_canals.gd "$@"
