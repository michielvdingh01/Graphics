#!/bin/sh
# Runs the headless test of what scripts/sfx.gd reads from a level and does
# by itself; exits non-zero when a check fails. --zones also lists what every
# zone of every level sounds like.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && exec "$GODOT" --headless --path . --script tools/test_sound.gd -- --play "$@"
