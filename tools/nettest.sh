#!/bin/sh
# Runs the test of playing together: the game twice on this machine, without
# a window, one hosting and one joining it. Exits non-zero when a check on
# either side fails. Arguments go to the host, e.g. --enemies=soldiers.
# With --ride first the two ride a motorcycle in the Alps instead, the guest
# in its sidecar (build the Alps first: tools/build_level.sh alps). With
# --match first it is three of them in a match: see scripts/net_test.gd, and
# with --lan after that the third finds it over this machine's network.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
host_role=host
join_role=join
if [ "$1" = "--ride" ]; then
	shift
	host_role=host_ride
	join_role=join_ride
fi
if [ "$1" = "--match" ]; then
	shift
	host_log=$(mktemp -t nettest)
	late_log=$(mktemp -t nettest)
	prizes=$(mktemp -d -t nettest)
	"$GODOT" --headless --path . -- --nettest=host_match "$@" >"$host_log" 2>&1 &
	host=$!
	"$GODOT" --headless --path . -- --nettest=late_match --prizes="$prizes" "$@" >"$late_log" 2>&1 &
	late=$!
	"$GODOT" --headless --path . -- --nettest=join_match --prizes="$prizes" "$@"
	joined=$?
	wait "$host"
	hosted=$?
	wait "$late"
	came=$?
	cat "$host_log" "$late_log"
	rm -rf "$host_log" "$late_log" "$prizes"
	[ "$joined" -eq 0 ] && [ "$hosted" -eq 0 ] && [ "$came" -eq 0 ]
	exit
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
