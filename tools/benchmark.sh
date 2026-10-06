#!/bin/sh
# Runs the fixed-camera benchmark and writes screenshots + results.json to benchmark/results/.
# Extra arguments are passed on, e.g. tools/benchmark.sh --quality=ultra --views=Combat
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
# A fresh clone has no class cache yet; importing once makes class_name types resolve.
"$GODOT" --headless --path . --import >/dev/null 2>&1
exec "$GODOT" --path . -- --benchmark "$@"
