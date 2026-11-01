#!/bin/sh
# Runs the headless test of the supermarket: what breaks, the mains, the
# flashlight, the carts and the SUVs. Exits non-zero when a check fails.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && exec "$GODOT" --headless --path . -- --shoptest "$@"
