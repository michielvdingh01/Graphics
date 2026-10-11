#!/bin/sh
# Says what a level costs to load and to hold in memory:
#   tools/level_cost.sh [level]      the factory, when none is named
# Needs the GPU, so it runs without a window through tools/godot.sh. See
# tools/level_cost.gd for how to read what it says.
"$(dirname "$0")/godot.sh" --script res://tools/level_cost.gd -- "$@" 2>&1 |
	grep -v "RID allocations\|Leaked instance\|^ *at: \|resources still in use\|ObjectDB instances\|PagedAllocator\|RIDs of type\|^Godot Engine\|^Metal \|^$"
