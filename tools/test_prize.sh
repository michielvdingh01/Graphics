#!/bin/sh
# Runs the headless test of what two teams fight over: every prize of
# assets/prizes.json is stood in the factory, touched, taken, carried,
# dropped and sent home. Exits non-zero when a check fails.
#
# The game is played for it, so it gets a home of its own: the save and the
# settings of whoever plays on this machine are not read and not written.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
mkdir -p .godot/prize_home
HOME="$PWD/.godot/prize_home" exec "$GODOT" --headless --path . --script res://tools/test_prize.gd -- --play "$@"
