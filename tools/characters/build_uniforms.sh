#!/bin/sh
# Dresses the five soldiers in another uniform, as characters of their own,
# so that two teams of the same soldiers can be told apart:
#   tools/characters/build_uniforms.sh <uniform> [soldier ...]
# A uniform is a line of UNIFORMS in tools/characters/looks.py: desert,
# woodland, night, or one that is added there. soldier_01 to soldier_05
# become soldier_01_<uniform> to soldier_05_<uniform>, each with its contact
# sheet and its line in assets/characters/manifest.json, and the theme
# soldiers_<uniform> casts them as the theme soldiers casts the five they
# were made from: the same roles, weapons and tuning. Named soldiers
# (soldier_03) are the only ones built; the theme is written when all five
# are there. Only the contact sheets need the GPU, and they are drawn in one
# run at the end, which waits its turn for it.
#
# A soldier is repainted as it stands in assets/characters/, not built again
# from the Rocketbox files, which are 1.4 GB and need not be at hand:
# --route=repaint puts a new colour texture into a copy of its file and
# leaves the mesh, the skeleton and the other textures what they were. Build
# the uniforms again after tools/characters/build_cast.sh has built a soldier
# again. A uniform that is no longer wanted goes by hand: its five folders,
# their sheets, their lines in the manifest and its theme.
cd "$(dirname "$0")/../.." || exit 1
ROCKETBOX=https://github.com/microsoft/Microsoft-Rocketbox
uniform=$1
if [ -z "$uniform" ] || ! grep -q "^    \"$uniform\": {" tools/characters/looks.py; then
	echo "usage: tools/characters/build_uniforms.sh <uniform> [soldier ...]"
	echo "the uniforms of tools/characters/looks.py:$(sed -n 's/^    "\([a-z0-9_]*\)": {"cloth".*/ \1/p' tools/characters/looks.py | tr -d '\n')"
	exit 64
fi
shift
only="$*"
failed=""
built=""

wanted() {
	case " $only " in "  " | *" $1 "*) return 0 ;; esac
	return 1
}

# The soldier it is made from, and the Rocketbox avatar that one was made
# from: the same five as in build_cast.sh.
dressed() {
	from=$1 avatar=$2
	wanted "$from" || return 0
	if tools/import_character.sh "assets/characters/$from/$from.glb" "${from}_$uniform" --route=repaint --look="$uniform" --no-sheet \
		--source="Microsoft Rocketbox, $avatar, as imported for $from" --url="$ROCKETBOX" --license=MIT --author=Microsoft \
		--note="$from in another uniform, for the second team of a match: the look $uniform of tools/characters/looks.py dyed what it wears and carries and took the flag and the badges off its sleeves"; then
		built="$built ${from}_$uniform"
	else
		failed="$failed ${from}_$uniform"
	fi
}

dressed soldier_01 Military_Male_01
dressed soldier_02 Military_Male_04
dressed soldier_03 Military_Female_01
dressed soldier_04 Military_Male_02
dressed soldier_05 Military_Male_03

# The theme: the soldiers' own, with everybody in the new uniform.
python3 - "$uniform" <<'EOF' || failed="$failed the theme"
import json
import pathlib
import sys

uniform = sys.argv[1]
path = pathlib.Path("assets/characters/manifest.json")
manifest = json.loads(path.read_text())
themes = {}
for name, theme in manifest["themes"].items():
    if name == "soldiers_" + uniform:
        continue
    themes[name] = theme
    if name != "soldiers":
        continue
    dressed = json.loads(json.dumps(theme))
    cast = [character + "_" + uniform for role in dressed.values() for character in role["characters"]]
    missing = [character for character in cast if character not in manifest["characters"]]
    if missing:
        print("build_uniforms: no theme soldiers_%s yet, for want of %s" % (uniform, ", ".join(missing)))
        if "soldiers_" + uniform in manifest["themes"]:
            themes["soldiers_" + uniform] = manifest["themes"]["soldiers_" + uniform]
        continue
    for role in dressed.values():
        role["characters"] = [character + "_" + uniform for character in role["characters"]]
    themes["soldiers_" + uniform] = dressed
manifest["themes"] = themes
path.write_text(json.dumps(manifest, indent="\t", ensure_ascii=False) + "\n")
EOF

# The contact sheets, all in one run.
if [ -n "$built" ]; then
	# shellcheck disable=SC2086
	tools/godot.sh --script res://tools/characters/sheet.gd -- $built | grep "^sheet: " || failed="$failed the contact sheets"
fi

if [ -n "$failed" ]; then
	echo "build_uniforms: these did not come through:$failed"
	exit 1
fi
echo "build_uniforms: try them with --enemies=soldiers_$uniform, and tools/characters/uniform_sheet.py shows the uniforms side by side"
