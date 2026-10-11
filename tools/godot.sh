#!/bin/sh
# Starts Godot on this project for the other tools: tools/godot.sh [godot arguments]
#
# Runs without a window, so a benchmark or a bake never takes the focus away
# from whatever else is being worked on. This is the mode the editor uses to
# embed a running game: it renders on the GPU like a normal run, but opens no
# window and shows no Dock icon. Set GODOT_WINDOW=1 to get a normal window.
#
# Either way it draws, and one Godot at a time does that: the run takes the GPU
# slot first and waits for as long as a run from another checkout has it, see
# tools/gpu_slot.sh. What it waits for is said on stderr.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
if [ -n "$GODOT_WINDOW" ]; then
	exec tools/gpu_slot.sh "$GODOT" --path . "$@"
fi

# Embedded mode reports to a debugger and crashes without one, so --debug hands
# it the local one; --ignore-error-breaks and the empty stdin keep that one from
# stopping at a prompt on a script error. A run nobody is watching should not
# make sound either, hence the dummy audio driver.
#
# The embedded display server prints a line whenever something tries to resize
# its window, which the editor does all the time. The descriptor shuffle drops
# those lines and still exits with Godot's own status.
exec 3>&1
status=$({
	{
		tools/gpu_slot.sh "$GODOT" --embedded --debug --ignore-error-breaks --audio-driver Dummy --path . "$@" </dev/null 3>&- 4>&-
		echo $? >&4
	} | grep --line-buffered -v "^Embedded window can't be resized\.$" >&3 4>&-
} 4>&1)
exit "$status"
