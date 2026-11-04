#!/bin/sh
# Runs the headless test of the Unmuted match (scripts/unmuted_test.gd); exits
# non-zero when a check fails.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && exec "$GODOT" --headless --path . -- --unmutedtest "$@"
