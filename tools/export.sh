#!/bin/sh
# Builds the game for friends to download: build/GraphicsFPS-windows.zip and
# build/GraphicsFPS-macos.zip, each with tools/LEESMIJ.txt in it. The presets
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
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
rm -rf build/windows build/macos build/GraphicsFPS-windows.zip build/GraphicsFPS-macos.zip
mkdir -p build/windows build/macos

"$GODOT" --headless --path . --export-release "Windows" build/windows/GraphicsFPS.exe >build/export_windows.log 2>&1
if [ ! -f build/windows/GraphicsFPS.pck ]; then
	echo "The Windows export failed, see build/export_windows.log"
	exit 1
fi
cp tools/LEESMIJ.txt build/windows/
(cd build/windows && zip -q ../GraphicsFPS-windows.zip GraphicsFPS.exe GraphicsFPS.pck LEESMIJ.txt) || exit 1

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
"$GODOT" --headless --path build/src --export-release "macOS" "$PWD/build/macos/GraphicsFPS.zip" >build/export_macos.log 2>&1
if [ ! -f build/macos/GraphicsFPS.zip ]; then
	echo "The macOS export failed, see build/export_macos.log"
	exit 1
fi
cp tools/LEESMIJ.txt build/macos/
(cd build/macos && zip -q GraphicsFPS.zip LEESMIJ.txt && mv GraphicsFPS.zip ../GraphicsFPS-macos.zip) || exit 1

ls -lh build/GraphicsFPS-windows.zip build/GraphicsFPS-macos.zip
