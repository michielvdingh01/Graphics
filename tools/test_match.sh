#!/bin/sh
# Runs the headless test of a match: bots play one to the end; exits non-zero
# when a check fails. With --pack=<name> --only-bots it only has bots play a
# match with that pack and counts the kills by weapon (--arena=<level>,
# --seconds=<seconds> of match). With --sides it plays one team deathmatch to
# the end with the player doing nothing, or with --stand-in a bot in their
# place, and says how it ended (--difficulty=<0 to 2>, --arena=, --pack=,
# --size=).
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && exec "$GODOT" --headless --path . -- --matchtest "$@"
