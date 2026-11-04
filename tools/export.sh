#!/bin/sh
# Builds the game for friends to download: build/GraphicsFPS-windows.zip and
# build/GraphicsFPS-macos.zip, each with tools/LEESMIJ.txt in it, or only one
# of the two with tools/export.sh windows or tools/export.sh macos. The presets
# are in export_presets.cfg. Needs the export templates of this version of
# Godot for Windows and macOS, in
# ~/Library/Application Support/Godot/export_templates/<version>/.
#
# The Mac build is made from a copy of the project, build/src. Godot only
# exports for Apple Silicon once every texture has been imported as ETC2/ASTC
# as well, although it then packs the same textures as for Windows. Switched
# on in the project itself, that has every import and every lightmap bake
# convert the textures a second time: the first export took 11 minutes where
# the one for Windows took 3. So it is switched on in the copy only. The copy
# stays, import cache and all, and the next export imports only what changed;
# delete build/src to have the room back.
#
# The first export in a checkout imports every texture again whatever was
# copied, which takes minutes and all the cores there are.
#
# tools/export.sh unmuted builds the game for Unmuted instead, both of it:
# build/WinTheICP-macos.zip and build/WinTheICP-windows.zip, with
# tools/unmuted/LEESMIJ.txt. Its presets have the feature "unmuted", which
# makes it start in Win the ICP (see Armory.unmuted_build()), and the presets
# for friends leave everything of Unmuted out. It has no number, so it never
# updates itself from the releases for friends (scripts/updater.gd).
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
platforms="${1:-windows macos}"
NAME=GraphicsFPS
WIN_PRESET="Windows"
MAC_PRESET="macOS"
README=tools/LEESMIJ.txt
NUMBERED=yes
if [ "$platforms" = unmuted ]; then
	platforms="windows macos"
	NAME=WinTheICP
	WIN_PRESET="Unmuted (Windows)"
	MAC_PRESET="Unmuted (macOS)"
	README=tools/unmuted/LEESMIJ.txt
	NUMBERED=no
fi
case " $platforms " in
*" windows "*) ;;
*" macos "*) ;;
*)
	echo "Usage: tools/export.sh [windows|macos|unmuted]"
	exit 1
	;;
esac
built=""

case " $platforms " in *" windows "*)
rm -rf build/windows "build/$NAME-windows.zip"
mkdir -p build/windows
"$GODOT" --headless --path . --export-release "$WIN_PRESET" "$PWD/build/windows/$NAME.exe" >build/export_windows.log 2>&1
if [ ! -f "build/windows/$NAME.pck" ]; then
	echo "The Windows export failed, see build/export_windows.log"
	exit 1
fi
cp "$README" build/windows/LEESMIJ.txt
(cd build/windows && zip -q "../$NAME-windows.zip" "$NAME.exe" "$NAME.pck" LEESMIJ.txt) || exit 1
built="$built build/$NAME-windows.zip"
;; esac

case " $platforms " in *" macos "*)
rm -rf build/macos "build/$NAME-macos.zip"
mkdir -p build/macos
if [ ! -d build/src ]; then
	# A clone where the disk can make one: done at once, and it takes no room
	# until something in it changes.
	mkdir build/src
	for entry in .godot *; do
		[ "$entry" = build ] || cp -cRp "$entry" build/src/ 2>/dev/null || cp -Rp "$entry" build/src/
	done
fi
# The copy follows the project, except for what Godot wrote there itself: an
# .import file only comes along when the project's is the newer of the two,
# which is when the way something is imported was changed.
rsync -a --delete --exclude /.git --exclude /.godot --exclude /build --exclude '*.import' ./ build/src/ || exit 1
rsync -au --exclude /.git --exclude /.godot --exclude /build --include '*/' --include '*.import' --exclude '*' ./ build/src/ || exit 1
if grep -q '^\[rendering\]' build/src/project.godot; then
	sed -i '' 's|^\[rendering\]$|[rendering]\
\
textures/vram_compression/import_etc2_astc=true|' build/src/project.godot
else
	printf '\n[rendering]\n\ntextures/vram_compression/import_etc2_astc=true\n' >>build/src/project.godot
fi
# The number this build goes by, see scripts/updater.gd; the build for
# Unmuted has none, and so does not update itself.
rm -f build/src/build.json
if [ "$NUMBERED" = yes ]; then
	printf '{"build": %s}\n' "$(date +%Y%m%d%H%M)" >build/src/build.json
fi
"$GODOT" --headless --path build/src --export-release "$MAC_PRESET" "$PWD/build/macos/$NAME.zip" >build/export_macos.log 2>&1
if [ ! -f "build/macos/$NAME.zip" ]; then
	echo "The macOS export failed, see build/export_macos.log"
	exit 1
fi
cp "$README" build/macos/LEESMIJ.txt
(cd build/macos && zip -q "$NAME.zip" LEESMIJ.txt && mv "$NAME.zip" "../$NAME-macos.zip") || exit 1
built="$built build/$NAME-macos.zip"
;; esac

ls -lh $built
