#!/bin/sh
# Runs the headless test of what can be driven: see tools/test_vehicles.gd.
# Exits non-zero when a check fails. --only=<part> runs one part of it: jeep,
# truck, tank, hills, wear, run_over, bail, dunes, gate or match.
#
# The game is played for it, so it gets a home of its own: the save and the
# settings of whoever plays on this machine are not read and not written.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
mkdir -p .godot/vehicles_home
HOME="$PWD/.godot/vehicles_home" exec "$GODOT" --headless --path . --script res://tools/test_vehicles.gd -- --play "$@"
