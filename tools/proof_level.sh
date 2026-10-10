#!/bin/sh
# Makes a level to measure with out of copies of one that is built and baked:
#   tools/proof_level.sh [level] [copies]     the factory five times, by default
# See tools/proof_level.gd.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && "$GODOT" --headless --path . --script tools/proof_level.gd -- "$@" 2>&1 |
	grep -v "RID allocations\|Leaked instance\|^ *at: \|resources still in use\|ObjectDB instances\|PagedAllocator\|^Godot Engine\|^$"
