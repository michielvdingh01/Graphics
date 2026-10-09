#!/bin/sh
# Runs the headless gameplay smoke test; exits non-zero when a check fails.
# With --routes it only goes through the levels along their routes and lists
# where every robot appears, which is the part to run while building a level.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && exec "$GODOT" --headless --path . -- --selftest "$@"
