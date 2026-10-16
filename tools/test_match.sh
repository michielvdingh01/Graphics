#!/bin/sh
# Runs the headless test of a match: bots play one to the end; exits non-zero
# when a check fails. With --pack=<name> --only-bots it only has bots play a
# match with that pack and counts the kills by weapon (--arena=<level>,
# --seconds=<seconds> of match).
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && exec "$GODOT" --headless --path . -- --matchtest "$@"
