#!/bin/sh
# Tests the scan route of tools/import_character.sh on a practice scan:
#   tools/characters/test_scan.sh [rigged model]
# Takes a model with a skeleton (a Rocketbox adult when none is given), has
# mock_scan.py turn it into a statue the way a phone would, takes that through
# the scan route as scan_test and the model itself through the rigged route as
# scan_test_original, and prints how the two compare: joints and colours.
# Look at assets/characters/sheets/scan_test.jpg and scan_test_original.jpg
# side by side afterwards. Neither goes into the manifest or into git.
BLENDER="${BLENDER:-blender}"
cd "$(dirname "$0")/../.." || exit 1
model="${1:-$(python3 tools/characters/fetch_rocketbox.py Male_Adult_06)}" || exit 1
work=assets/characters/.source/mock
mkdir -p "$work"
quiet() { grep -E "^(mock_scan|compare|import_character: [a-z])|Error|Traceback"; }

"$BLENDER" -b --factory-startup --python tools/characters/mock_scan.py -- "$model" "$work" 2>&1 | quiet
tools/import_character.sh "$model" scan_test_original --no-manifest --report="$work/original.json" || exit 1
tools/import_character.sh "$work/scan.usdz" scan_test --no-manifest --report="$work/scan.json" --keep="$work/delit" || exit 1
# The same statue as OBJ and as GLB has to come out the same.
for kind in obj glb; do
	"$BLENDER" -b --factory-startup --python tools/characters/prepare.py -- "$work/scan.$kind" "$work/as_$kind.glb" --id "as_$kind" 2>&1 |
		sed -n 's/^import_character: {.*"height": \([0-9.]*\).*"triangles": \([0-9]*\), "vertices".*/compare: scan.'"$kind"' gives \2 triangles, \1 m tall/p'
done
# For the colours: the scan as it is, the scan with its light removed, and
# the same statue wearing the model's real colours.
for run in "lit scan.glb --no-delight" "delit scan.glb" "truth scan_unlit.glb --no-delight"; do
	set -- $run
	"$BLENDER" -b --factory-startup --python tools/characters/prepare.py -- "$work/$2" "$work/$1.glb" --id "$1" --keep "$work/$1" $3 2>&1 | grep -E "Error|Traceback"
done
"$BLENDER" -b --factory-startup --python tools/characters/compare_scan.py -- "$work" 2>&1 | quiet
