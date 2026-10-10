#!/bin/sh
# Rebuilds assets/animations/moves.res, the moves of the humanoid enemies, from
# the sources and the list of moves in assets/animations/manifest.json.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
"$GODOT" --headless --path . --script tools/build_moves.gd 2>&1 |
	grep -v "RID allocations\|Leaked instance\|^ *at: \|resources still in use\|ObjectDB instances leaked\|Pages in use exist"
