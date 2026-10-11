#!/bin/sh
# Runs a command while it holds the GPU slot: tools/gpu_slot.sh command [arguments]
#
# One Godot at a time draws on this laptop. Two at once halve each other's
# frame rates, so that nothing measured means anything, and a lightmap bake
# next to another Godot has hung both, and every Godot started after them.
# Several checkouts of this project are worked in at the same time, so
# whatever needs the GPU takes this slot first and waits while another has it.
# tools/godot.sh does that for every run it starts, and tools/bake_lightmaps.py
# for the whole of a bake.
#
# The slot is a lock on one file that every checkout shares. It is held for as
# long as the command runs, with anything it started, and is free the moment
# those are gone, however they went. The file says who has it. A command that
# is started while the slot is already held for it (GPU_SLOT_HELD) runs at
# once, which is how a series keeps the slot from its first run to its last:
#   tools/gpu_slot.sh sh -c 'tools/benchmark.sh --quick; ../base/tools/benchmark.sh --quick'
#
# The slot knows nothing of a Godot that was not started through it: the
# editor, the game that is played from it, a checkout from before there was a
# slot. Look with ps for those.
#
#   GPU_SLOT        the file, when it is not the usual one
#   GPU_SLOT_WAIT   seconds to wait for the slot before giving up, 1800 by default
if [ $# -eq 0 ]; then
	echo "usage: tools/gpu_slot.sh command [arguments]" >&2
	exit 64
fi
if [ -n "$GPU_SLOT_HELD" ]; then
	exec "$@"
fi
SLOT="${GPU_SLOT:-$HOME/Library/Application Support/Godot/gpu-slot}"
WAIT="${GPU_SLOT_WAIT:-1800}"
mkdir -p "$(dirname "$SLOT")"
# The lock is on this descriptor, which the command inherits.
if ! exec 9>>"$SLOT"; then
	echo "The GPU slot $SLOT cannot be opened: not started." >&2
	exit 73
fi
if ! lockf -s -t 0 9; then
	echo "Waiting for the GPU slot, which has: $(cat "$SLOT")" >&2
	if ! lockf -s -t "$WAIT" 9; then
		echo "Gave up after $WAIT s of waiting for the GPU slot, which has: $(cat "$SLOT")" >&2
		exit 75
	fi
fi
# Who has it, for whoever waits: the command without the path to it.
all="$*"
printf 'pid %s since %s, from %s: %.200s\n' "$$" "$(date '+%H:%M:%S')" "$(cd "$(dirname "$0")/.." && pwd)" "${1##*/}${all#"$1"}" >"$SLOT"
export GPU_SLOT_HELD=1
exec "$@"
