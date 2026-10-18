#!/bin/sh
# How each kind of vehicle gets over the long dunes of the dunes level: see
# tools/vehicle_ridges.gd. Headless; a fixed step makes it run as fast as
# the machine can, about a minute a kind.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
mkdir -p .godot/vehicles_home
HOME="$PWD/.godot/vehicles_home" exec "$GODOT" --headless --fixed-fps 120 --path . --script res://tools/vehicle_ridges.gd -- --play "$@" 2>&1 |
	grep -v "RID allocations\|Leaked instance\|^ *at: \|resources still in use\|ObjectDB instances leaked\|^Godot Engine\|^$"
