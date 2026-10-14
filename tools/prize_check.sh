#!/bin/sh
# Checks a prize the way the game shows it, without a window: that its model
# can be read, how big it is, what of it takes the colour of a team, and how
# it sits at home, carried and down. Exits non-zero if the game cannot show it.
#
#     tools/prize_check.sh rubber_duck            a prize of this machine or of the table
#     tools/prize_check.sh <folder>               a prize folder anywhere else
#
# It reads the prizes of whoever plays here and writes nothing.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [ -d "$1" ]; then
	folder=$(cd "$1" && pwd)
	set -- "--prizes=$(dirname "$folder")" "$(basename "$folder")"
fi
cd "$(dirname "$0")/.." || exit 1
log=$(mktemp -t prize_check)
"$GODOT" --headless --path . --script res://tools/prize_check.gd -- "$@" > "$log" 2>&1
code=$?
grep -v "RID allocations\|Leaked instance\|^ *at: \|resources still in use\|ObjectDB instances leaked\|^Godot Engine\|^$" "$log"
rm -f "$log"
exit $code
