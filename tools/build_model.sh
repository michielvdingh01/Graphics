#!/bin/sh
# Regenerates the models in scenes/models/ from tools/models/<name>.gd
# (weapons, enemies; all of them when no name is given).
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
if [ -n "$1" ]; then set -- "tools/models/$1.gd"; else set -- tools/models/*.gd; fi
for script in "$@"; do
	"$GODOT" --headless --path . --script "$script" 2>&1 |
		grep -v "RID allocations\|Leaked instance\|^ *at: \|resources still in use\|ObjectDB instances leaked"
done
