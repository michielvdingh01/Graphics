#!/bin/sh
# Runs the headless test of a match: bots play one to the end; exits non-zero
# when a check fails.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && exec "$GODOT" --headless --path . -- --matchtest "$@"
