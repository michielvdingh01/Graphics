#!/bin/sh
# Headless gameplay smoke test (simulated time). Exits non-zero when a check fails.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
# A fresh clone has no class cache yet; importing once makes class_name types resolve.
"$GODOT" --headless --path . --import >/dev/null 2>&1
exec "$GODOT" --headless --path . --fixed-fps 60 res://tools/smoke_test.tscn
