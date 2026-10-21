#!/bin/sh
# Makes the masks of skin and cloth for the soldiers, see parts_masks.py:
#   tools/characters/build_masks.sh [soldier_01 ...]
# A soldier in another uniform has the layout of the one it was painted from,
# and its cloth may have the colour of skin, so it gets that one's masks. The
# masks are imported as compressed textures; run Godot's import afterwards
# (godot --headless --path . --import) before the game can use them.
cd "$(dirname "$0")/../.." || exit 1
ids="$*"
[ -z "$ids" ] && ids="soldier_01 soldier_02 soldier_03 soldier_04 soldier_05"
for id in $ids; do
	dir=assets/characters/$id
	blender -b --python tools/characters/parts_masks.py -- "$dir/$id.glb" 2>&1 | grep "^parts_masks" || exit 1
	for kind in skin cloth; do
		for other in "$dir" assets/characters/${id}_*; do
			[ -f "$other/$(basename "$other").glb" ] || continue
			name=$(basename "$other")_$kind.png
			[ "$other" = "$dir" ] || cp "$dir/${id}_$kind.png" "$other/$name"
			[ -f "$other/$name.import" ] || cat > "$other/$name.import" <<EOF
[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://$other/$name"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=2
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
EOF
		done
	done
done
