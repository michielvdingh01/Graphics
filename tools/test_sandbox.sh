#!/bin/sh
# Runs the headless test of the sandbox; exits non-zero when a check fails.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && exec "$GODOT" --headless --path . -- --sandboxtest --sandbox=panic_spread "$@"
