#!/bin/sh
# Runs the headless gameplay smoke test; exits non-zero when a check fails.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && exec "$GODOT" --headless --path . -- --selftest
