#!/bin/sh
# Rebuilds the shooter's glove, scenes/models/glove.scn and glove.res: Blender
# shapes it and gives it its bones (tools/models/hands.py), Godot makes of that
# what the weapons use (tools/build_hands.gd). Only this needs Blender;
# tools/build_model.sh weapons works with what it leaves behind.
# With --sheet=<folder> Blender also renders the hand in a few poses, on the CPU.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
BLENDER="${BLENDER:-blender}"
cd "$(dirname "$0")/.." || exit 1
work="$(mktemp -d)" || exit 1
trap 'rm -rf "$work"' EXIT
sheet=""
for arg in "$@"; do
	case "$arg" in --sheet=*) sheet="--sheet ${arg#--sheet=}" ;; esac
done
# shellcheck disable=SC2086
"$BLENDER" -b --factory-startup --python tools/models/hands.py -- "$work/glove.glb" $sheet 2>&1 |
	grep "^[A-Z][a-z]*: [0-9]* vertices\|Error\|Traceback\|^  File\|^wrote" || exit 1
[ -f "$work/glove.glb" ] || exit 1
"$GODOT" --headless --path . --script tools/build_hands.gd -- "$work/glove.glb" 2>&1 |
	grep -v "RID allocations\|Leaked instance\|^ *at: \|resources still in use\|ObjectDB instances leaked"
