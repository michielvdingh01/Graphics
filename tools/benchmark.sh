#!/bin/sh
# Runs the fixed-camera benchmark and writes screenshots + results.json to benchmark/results/.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && exec "$GODOT" --path . -- --benchmark
