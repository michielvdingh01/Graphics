#!/bin/sh
# Renders the sheaves of grass listed in assets/manifest.json (source "rendered"), in Blender on the
# processor and without a window, and imports them: all of them, or only those named. A minute.
BLENDER="${BLENDER:-/opt/homebrew/bin/blender}"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
python3 - "$@" <<'PY' | while read -r id kind; do
import json, sys
for asset in json.load(open("assets/manifest.json"))["assets"]:
    if asset.get("source") == "rendered" and (len(sys.argv) == 1 or asset["id"] in sys.argv[1:]):
        print(asset["id"], asset["kind"])
PY
	"$BLENDER" -b --factory-startup --python tools/render_grass.py -- "$kind" "assets/foliage/$id.png" "assets/foliage/${id}_n.png" | grep -E "Saved|Error" || exit 1
	for file in "assets/foliage/$id.png" "assets/foliage/${id}_n.png"; do
		[ -f "$file.import" ] && continue
		normal=0
		[ "$file" = "assets/foliage/${id}_n.png" ] && normal=1
		printf '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=2\ncompress/high_quality=true\ncompress/normal_map=%s\nmipmaps/generate=true\nprocess/fix_alpha_border=true\ndetect_3d/compress_to=0\n' "$normal" > "$file.import"
	done
	echo "$id"
done
exec "$GODOT" --headless --path . --import
