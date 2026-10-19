#!/bin/sh
# Runs the test of playing together: the game twice on this machine, without
# a window, one hosting and one joining it. Exits non-zero when a check on
# either side fails. Arguments go to the host, e.g. --enemies=soldiers.
# With --ride first the two ride a motorcycle in the Alps instead, the guest
# in its sidecar (build the Alps first: tools/build_level.sh alps).
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
host_role=host
join_role=join
if [ "$1" = "--ride" ]; then
	shift
	host_role=host_ride
	join_role=join_ride
fi
log=$(mktemp -t nettest)
"$GODOT" --headless --path . -- --nettest=$host_role "$@" >"$log" 2>&1 &
host=$!
"$GODOT" --headless --path . -- --nettest=$join_role
joined=$?
wait "$host"
hosted=$?
cat "$log"
rm -f "$log"
[ "$joined" -eq 0 ] && [ "$hosted" -eq 0 ]
