#!/bin/sh
# Runs the headless test of the enemies that are people; exits non-zero when a
# check fails. It uses the mannequins unless --enemies=<theme> names another.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && exec "$GODOT" --headless --path . -- --humanoidtest --enemies=mannequin "$@"
