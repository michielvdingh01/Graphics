#!/bin/sh
# Runs the test of playing together: the game twice on this machine, without
# a window, one hosting and one joining it. Exits non-zero when a check on
# either side fails. Arguments go to the host, e.g. --enemies=soldiers.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
log=$(mktemp -t nettest)
"$GODOT" --headless --path . -- --nettest=host "$@" >"$log" 2>&1 &
host=$!
"$GODOT" --headless --path . -- --nettest=join
joined=$?
wait "$host"
hosted=$?
cat "$log"
rm -f "$log"
[ "$joined" -eq 0 ] && [ "$hosted" -eq 0 ]
