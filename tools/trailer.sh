#!/bin/sh
# Films the takes of the trailer and cuts them: tools/trailer.sh [take ...]
#
# Every take is a run of the game on the GPU under Godot's Movie Maker, played
# by tools/trailer/director.gd: a fixed 60 frames a second whatever a frame
# costs, so nothing stutters, with the sound of the game as it was played.
# Each lands in benchmark/results/trailer/<take>.avi, with the frames at
# which its scenes begin in <take>.json and a sheet of its frames in
# <take>_sheet.jpg. tools/trailer/cut.py then cuts the takes together the
# way its list says, lays the music under them and writes
# benchmark/results/trailer/trailer.mp4 with tools/trailer/encode.swift.
#
# Named takes are filmed again; without names only those that are not there
# yet. The enemies and the bots play every take their own way, so a take
# filmed again is another take: look at its sheet, and set where the cut
# takes it from in CUT in tools/trailer/cut.py if the moment moved.
cd "$(dirname "$0")/.." || exit 1
OUT=benchmark/results/trailer
mkdir -p "$OUT"
TAKES="$*"
if [ -z "$TAKES" ]; then
	for take in $(python3 tools/trailer/cut.py --takes); do
		[ -f "$OUT/$take.avi" ] || TAKES="$TAKES $take"
	done
fi
for take in $TAKES; do
	echo "Filming $take" >&2
	rm -f "$OUT/$take.avi" "$OUT/$take.json"
	# Ultra, drawn at the full size of the picture, with what Ultra gave up
	# to keep 60 frames a second on the laptop's own screen.
	tools/godot.sh --write-movie "$OUT/$take.avi" --fixed-fps 60 --resolution 1920x1080 -- \
		--play --direct=res://tools/trailer/director.gd --take="$take" --marks="$OUT/$take.json" \
		--quality=3 --upscaler=bilinear --scale=1.0 --undo=lamp_filter,sun_atlas \
		2>&1 | grep -v -e "^WARNING: .*leaked" -e "^   at: " -e "resources still in use" -e "^Embedded"
	if [ ! -s "$OUT/$take.json" ]; then
		echo "The take $take did not finish." >&2
		exit 1
	fi
	python3 tools/trailer/cut.py --sheet "$OUT/$take.avi"
done
python3 tools/trailer/cut.py "$OUT"
