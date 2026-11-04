#!/bin/sh
# Builds the people of the Unmuted build from Microsoft's Rocketbox library
# (MIT), as tools/characters/build_cast.sh builds the rest of the cast:
#   tools/unmuted/build_people.sh [id ...]
# unmuted_01 to unmuted_08 are four women and four men in the look unmuted of
# tools/characters/looks.py: black trousers and a black T-shirt with the logo
# of Unmuted on the chest (assets/unmuted/logo.png, which
# tools/unmuted/stickers.py renders). icp_01 is the ICP, a man in a black suit
# in the look icp: a grin and sunglasses. The game makes him 1.3 times as big
# (scripts/icp_body.gd). Without ids it builds them all. Each lands in
# assets/characters/<id>/ with its contact sheet and its line in the manifest.
cd "$(dirname "$0")/../.." || exit 1
ROCKETBOX=https://github.com/microsoft/Microsoft-Rocketbox
only="$*"
failed=""
# Met close up, as the soldiers are.
CLOSE="--texture-size=2048 --occlusion"

person() {
	id=$1 avatar=$2
	shift 2
	case " $only " in "  " | *" $id "*) ;; *) return 0 ;; esac
	file=$(python3 tools/characters/fetch_rocketbox.py "$avatar") || exit 1
	# shellcheck disable=SC2086
	tools/import_character.sh "$file" "$id" --source="Microsoft Rocketbox, $avatar" --url="$ROCKETBOX" --license=MIT --author=Microsoft $CLOSE "$@" || failed="$failed $id"
}

person unmuted_01 Female_Adult_08 --look=unmuted
person unmuted_02 Male_Adult_09 --look=unmuted
person unmuted_03 Female_Party_02 --look=unmuted
person unmuted_04 Male_Adult_16 --look=unmuted
person unmuted_05 Female_Adult_17 --look=unmuted
person unmuted_06 Male_Adult_12 --look=unmuted
person unmuted_07 Female_Adult_03 --look=unmuted
person unmuted_08 Male_Adult_17 --look=unmuted
person icp_01 Business_Male_01 --look=icp

if [ -n "$failed" ]; then
	echo "build_people: these did not come through:$failed"
	exit 1
fi
