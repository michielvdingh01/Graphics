#!/bin/sh
# Makes a prize from a script that builds it with tools/prizes/kit.py, and
# checks it in the game: the model, its name and how it sits, and a picture
# of it next to a figure of 1.8 m (preview.png in its folder). Neither needs
# the GPU, so this can run while the game is played.
#
#     tools/make_prize.sh tools/prizes/rubber_duck.py
#     tools/make_prize.sh <script> <folder>      somewhere else than user://prizes/
#
# The script may be anywhere: a copy of it goes with the prize, as build.py.
#
# Without a folder the prize lands where the game looks for it, and a game
# that is running has it in the list the next time "Prize" is opened.
script="$1"
[ -f "$script" ] || { echo "usage: tools/make_prize.sh <script.py> [<folder>]" >&2; exit 2; }
# Both as seen from here, before going to the project.
script="$(cd "$(dirname "$script")" && pwd)/$(basename "$script")"
shift
if [ -n "$1" ]; then
	mkdir -p "$1" && set -- "$(cd "$1" && pwd)"
fi
cd "$(dirname "$0")/.." || exit 1
log=$(mktemp -t prize)
# The script finds tools/prizes/kit.py wherever it is itself.
blender -b --factory-startup --python-expr "import sys; sys.dont_write_bytecode = True; sys.path.insert(0, '$PWD/tools/prizes')" --python "$script" -- "$@" > "$log" 2>&1
made=$?
grep -E "^PRIZE|Error|Traceback|SystemExit" "$log"
if [ $made -ne 0 ] || ! grep -q "^PRIZE " "$log"; then
	echo "Blender did not finish; the whole of what it said is in $log" >&2
	exit 1
fi
folder=$(sed -n 's/^PRIZE [^:]*: \(.*\), [0-9.]* by .*/\1/p' "$log" | tail -1)
rm -f "$log"
exec tools/prize_check.sh "$folder"
