#!/bin/sh
# Builds every character in assets/characters/manifest.json again from its source:
#   tools/characters/build_cast.sh [id ...]
# Without ids it builds them all. The people come from Microsoft's Rocketbox
# library (MIT) and the blocky ones from Kenney (CC0); both are fetched to
# assets/characters/.source/, which is not in git. A zombie or a clown is a
# Rocketbox civilian painted up by --look and is marked as a placeholder, with
# what should replace it; one clown is generated from a description. This
# file is the recipe: change a line and run it for that id.
BLENDER="${BLENDER:-blender}"
cd "$(dirname "$0")/../.." || exit 1
SOURCE=assets/characters/.source
ROCKETBOX=https://github.com/microsoft/Microsoft-Rocketbox
KENNEY=https://kenney.nl/assets/blocky-characters
KENNEY_ZIP=https://kenney.nl/media/pages/assets/blocky-characters/8369c0cf30-1749547469/kenney_blocky-characters_20.zip
failed=""

wanted() {
	case " $only " in "  " | *" $1 "*) return 0 ;; esac
	return 1
}

# id, Rocketbox avatar, then options for tools/import_character.sh
person() {
	id=$1 avatar=$2
	shift 2
	wanted "$id" || return 0
	file=$(python3 tools/characters/fetch_rocketbox.py "$avatar") || exit 1
	tools/import_character.sh "$file" "$id" --source="Microsoft Rocketbox, $avatar" --url="$ROCKETBOX" --license=MIT --author=Microsoft "$@" || failed="$failed $id"
}

# The same, but taken through a practice scan first: what a scanned friend goes through.
scanned() {
	id=$1 avatar=$2
	shift 2
	wanted "$id" || return 0
	file=$(python3 tools/characters/fetch_rocketbox.py "$avatar") || exit 1
	"$BLENDER" -b --factory-startup --python tools/characters/mock_scan.py -- "$file" "$SOURCE/mock_$avatar" 2>&1 | grep -E "^mock_scan|Error"
	tools/import_character.sh "$SOURCE/mock_$avatar/scan.usdz" "$id" --source="practice scan (tools/characters/mock_scan.py) of Microsoft Rocketbox, $avatar" \
		--url="$ROCKETBOX" --license=MIT --author=Microsoft "$@" || failed="$failed $id"
}

# id, letter of Kenney's blocky character, then options
blocky() {
	id=$1 letter=$2
	shift 2
	wanted "$id" || return 0
	if [ ! -d "$SOURCE/kenney/blocky" ]; then
		mkdir -p "$SOURCE/kenney/blocky" && curl -sL "$KENNEY_ZIP" -o "$SOURCE/kenney/blocky.zip" && unzip -q -o "$SOURCE/kenney/blocky.zip" -d "$SOURCE/kenney/blocky" || exit 1
	fi
	tools/import_character.sh "$SOURCE/kenney/blocky/Models/GLB format/character-$letter.glb" "$id" --source="Kenney Blocky Characters 2.0, character-$letter" \
		--url="$KENNEY" --license=CC0 --author=Kenney "$@" || failed="$failed $id"
}

# id, seed, prompt, then options: a character that is made from a description.
# The picture and the model are kept, because making them again takes a
# day's ration of GPU time (see tools/characters/generate.py).
generated() {
	id=$1 seed=$2 prompt=$3
	shift 3
	wanted "$id" || return 0
	file="$SOURCE/generated/$id/$id.glb"
	if [ ! -f "$file" ]; then
		python3 tools/characters/generate.py "$id" "$prompt" --seed="$seed" >/dev/null || exit 1
	fi
	tools/import_character.sh "$file" "$id" --height=1.8 --source="generated from a description" --prompt="$prompt" \
		--model="FLUX.1-schnell (seed $seed) for the picture, TRELLIS.2-4B at 1024 for the model, both as demos on Hugging Face" \
		--license="generated here; FLUX.1-schnell is Apache-2.0 and TRELLIS.2 is MIT, neither claims what it makes" "$@" || failed="$failed $id"
}

only="$*"
ZOMBIE="an everyday civilian, painted pale and bloody by --look=zombie"
CLOWN="a civilian painted up by --look=clown: the costume is paint on everyday clothes, the nose a ball"
BLOCKY="a cartoon figure of six boxes: there to compare a stylised cast with a realistic one, not to stay"

# Soldiers: as they come, no placeholders.
person soldier_01 Military_Male_01
person soldier_02 Military_Male_04
person soldier_03 Military_Female_01
person soldier_04 Military_Male_02
person soldier_05 Military_Male_03 --scale=1.08 --wide=1.08

person zombie_01 Male_Adult_06 --look=zombie --seed=1 --placeholder="$ZOMBIE" \
	--wanted="photorealistic zombie, a man in his thirties in a torn red henley and jeans, grey mottled skin, sunken eyes, dried blood around the mouth, A-pose, game character, 20k triangles, PBR textures"
person zombie_02 Female_Adult_08 --look=zombie --seed=2 --placeholder="$ZOMBIE" \
	--wanted="photorealistic zombie, a woman in a torn grey t-shirt and jeans, matted hair, grey mottled skin, one arm bitten open, A-pose, game character, 20k triangles, PBR textures"
person zombie_03 Medical_Female_01 --look=zombie --seed=3 --placeholder="$ZOMBIE" \
	--wanted="photorealistic zombie nurse in a blood-soaked white uniform, grey skin, milky eyes, A-pose, game character, 20k triangles, PBR textures"
person zombie_04 Sports_Male_04 --look=zombie --seed=4 --placeholder="$ZOMBIE" \
	--wanted="photorealistic fast zombie, a lean runner in a torn vest and shorts, sinewy, bared teeth, fresh blood on hands and mouth, A-pose, game character, 20k triangles, PBR textures"
person zombie_05 Fire_Male_06 --look=zombie --seed=5 --scale=1.1 --wide=1.1 --placeholder="$ZOMBIE" \
	--wanted="photorealistic hulking zombie firefighter in scorched turnout gear and helmet, bloated, grey skin, A-pose, game character, 20k triangles, PBR textures"
scanned zombie_06 Male_Adult_14 --look=zombie --seed=6 --placeholder="$ZOMBIE; it went through the scan route as a scanned friend would" \
	--wanted="a scan of a real friend, taken as PLAN.md describes"

person clown_01 Male_Adult_13 --look=clown --seed=0 --placeholder="$CLOWN" \
	--wanted="photorealistic creepy clown, a balding middle-aged man in a filthy yellow polka-dot costume with a ruff, cracked white greasepaint, smeared red grin, red ball nose, tufts of orange hair, A-pose, game character, 20k triangles, PBR textures"
person clown_02 Sports_Male_03 --look=clown --seed=1 --placeholder="$CLOWN" \
	--wanted="photorealistic creepy clown with a wild green curly wig, striped purple and yellow costume, cracked greasepaint, black diamonds over the eyes, A-pose, game character, 20k triangles, PBR textures"
person clown_03 Sports_Male_02 --look=clown --seed=2 --placeholder="$CLOWN" \
	--wanted="photorealistic creepy clown, thin and quick, harlequin costume in black and white diamonds, red wig, too-wide painted grin, bare bloodied hands, A-pose, game character, 20k triangles, PBR textures"
person clown_04 Male_Adult_03 --look=clown --seed=4 --scale=1.12 --wide=1.15 --placeholder="$CLOWN" \
	--wanted="photorealistic creepy clown, huge and fat, an old man in a stained striped costume with oversized shoes, bald crown with green side tufts, greasepaint running, A-pose, game character, 20k triangles, PBR textures"

generated clown_05 2 "Full body photograph of a creepy horror clown standing still and upright, facing the camera, in a relaxed A-pose: both arms straight and hanging down at his sides, held a little away from the body, hands open and empty below hip height, legs straight and clearly apart with a gap between them, feet flat on the floor shoulder width apart. He wears a threadbare one-piece costume in faded purple and dirty green vertical stripes with a moth-eaten grey ruff, long worn brown shoes, cracked white greasepaint, black diamonds painted over the eyes, a too-wide smeared dark red grin, a red ball nose, a bald crown with matted green hair at the sides. Flat even studio lighting without shadows, plain light grey background, the whole figure in frame from head to toe, photorealistic, front view character reference for a 3D model."
generated clown_06 1 "Full body photograph of a thin, wiry, creepy horror clown standing still and upright, facing the camera, in a wide A-pose: both arms straight and held out to the sides at 45 degrees from the body, well clear of the torso with a wide gap of empty air under each arm, hands open and empty, legs straight and clearly apart with a gap between them, feet flat on the floor wider than the shoulders. He wears a tight harlequin costume of black and dirty white diamonds, a small frayed black ruff, flat black slippers, a wild mop of red hair, cracked white greasepaint, black teardrops under the eyes, a too-wide painted dark red grin, a small red ball nose, bare forearms and bloodied bare hands. Flat even studio lighting without shadows, plain light grey background, the whole figure in frame from head to toe, photorealistic, front view character reference for a 3D model."
generated clown_07 1 "Full body photograph of a huge, fat, hulking creepy horror clown standing still and upright, facing the camera, in a wide A-pose: both arms straight and held out to the sides at 45 degrees from the body, well clear of the torso with a wide gap of empty air under each arm, hands open and empty, legs straight and clearly apart with a gap between them, feet flat on the floor wider than the shoulders. He is an old man with a big belly in a filthy stained yellow one-piece costume with large red polka dots, a wide grimy white ruff, enormous oversized red shoes, a bald crown with matted orange hair at the sides, greasepaint running down a jowly face, a smeared dark red grin, a big red ball nose, thick white gloves. Flat even studio lighting without shadows, plain light grey background, the whole figure in frame from head to toe, photorealistic, front view character reference for a 3D model." --height=1.95

blocky zombie_blocky_01 l --height=1.75 --placeholder="$BLOCKY"
blocky zombie_blocky_02 o --height=1.75 --placeholder="$BLOCKY"
blocky zombie_blocky_03 l --height=1.5 --placeholder="$BLOCKY"
blocky zombie_blocky_04 o --height=2.05 --wide=1.1 --placeholder="$BLOCKY"

if [ -n "$failed" ]; then
	echo "build_cast: these did not come through:$failed"
	exit 1
fi
