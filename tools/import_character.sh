#!/bin/sh
# Turns a humanoid model into a character the rig can animate:
#   tools/import_character.sh <file> <id> [options]
# The file is an FBX, GLB, glTF, OBJ, USDZ or USD; with a skeleton, or a statue
# without one, such as a scan. The character lands in assets/characters/<id>/,
# its contact sheet in assets/characters/sheets/ and a line about it in
# assets/characters/manifest.json. Run it without arguments for the options.
exec python3 "$(dirname "$0")/characters/import_character.py" "$@"
