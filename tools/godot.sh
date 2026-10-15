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

# Windows has no embedded display server, so there a run gets a window.
# GODOT_OUT_OF_SIGHT hides it and moves it off the screen once the game is up
# (scripts/benchmark.gd), or the editor once it bakes (addons/bake_cli/plugin.gd);
# it goes on drawing. Until then, the first five seconds or so, it is on the
# screen, without taking the focus. A minimized window would stop drawing.
# --single-window keeps the dialogs of the editor inside its window instead of
# in the middle of the screen.
case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*)
	export GODOT_OUT_OF_SIGHT=1
	exec tools/gpu_slot.sh "$GODOT" --single-window --audio-driver Dummy --path . "$@" </dev/null
	;;
esac

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
