#!/bin/sh
# Runs the fixed-camera benchmark and writes screenshots + results.json to benchmark/results/.
# Pass --quick to only grab the screenshots.
exec "$(dirname "$0")/godot.sh" -- --benchmark "$@"
