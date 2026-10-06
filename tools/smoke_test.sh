#!/bin/sh
# Headless gameplay smoke test (simulated time). Exits non-zero when a check fails.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && exec "$GODOT" --headless --path . --fixed-fps 60 res://tools/smoke_test.tscn
