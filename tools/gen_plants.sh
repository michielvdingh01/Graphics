#!/bin/sh
# Renders the small green of the Alps listed in assets/manifest.json (generator tools/gen_plants.py)
# in Blender, on the processor and without a window, and imports it: all sheets, or those named.
# --only=mown0,wet2 renders only those cells and keeps the rest of the sheet as it was.
BLENDER="${BLENDER:-/opt/homebrew/bin/blender}"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
ONLY=""
for arg do
	shift
	case "$arg" in
	--only=*) ONLY="${arg#--only=}" ;;
	*) set -- "$@" "$arg" ;;
	esac
done
[ -n "$ONLY" ] && set -- "$@" --only "$ONLY"
"$BLENDER" -b --factory-startup --python tools/gen_plants.py -- "$@" | grep -v "| Saved: \|^Fra:\|^Saved:\|^ Time:\|^$\|Remaining:\|Sample \|Synchroniz\|Updating\|Loading\|Building\|Initializ" || exit 1
exec "$GODOT" --headless --path . --import
