#!/bin/sh
# Runs the headless test of the effects that are added to a level as it
# loads: windows that break, the splash in a puddle, fire that spreads, the
# daylight at the exit and the smoke of an explosion. Exits non-zero when a
# check fails. Every script in tools/effects/ is one part of it;
# --only=<name> runs that part alone.
#
# The game is played for it, so it gets a home of its own: the save and the
# settings of whoever plays on this machine are not read and not written.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
mkdir -p .godot/effects_home
HOME="$PWD/.godot/effects_home" exec "$GODOT" --headless --path . --script res://tools/test_effects.gd -- --play "$@"
