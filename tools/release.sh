#!/bin/sh
# Makes a new version of the game for friends with a Mac, and puts it on GitHub.
# Whoever has the game gets it the next time they start it, see
# scripts/updater.gd; a push alone reaches nobody.
#
#   tools/release.sh            builds build/release: the installer
#                               GraphicsFPS.dmg, the same app as a zip in parts
#                               and update-macos.json, which says what they are
#   tools/release.sh --publish  puts build/release on GitHub as the latest
#
# The two are apart so that the installer can be tried first. The release stays
# a draft until every file is up: a game that looks at the latest release in
# the meantime still finds the last whole one. It needs no commit on GitHub.
#
# Run this in a checkout that has every level: the files of the Alps are not in
# git, so a fresh worktree lacks them, see the check below.
REPO=michielvdingh01/Graphics
# Godot checks one part at a time, and GitHub takes nothing above 2 GiB.
PART_MB=256
cd "$(dirname "$0")/.." || exit 1
OUT=build/release

if [ "$1" = "--publish" ]; then
	manifest="$OUT/update-macos.json"
	if [ ! -f "$manifest" ]; then
		echo "Nothing to publish: run tools/release.sh first"
		exit 1
	fi
	build=$(sed -E 's/^.*"build": ([0-9]+).*$/\1/' "$manifest")
	tag="build-$build"
	gh release create "$tag" "$OUT"/* -R "$REPO" --draft --title "Graphics FPS $build" \
		--notes "Installer: GraphicsFPS.dmg. The game updates itself from here. Built from commit $(git rev-parse --short HEAD)." || exit 1
	gh release edit "$tag" -R "$REPO" --draft=false --latest || exit 1
	echo "Installer: https://github.com/$REPO/releases/latest/download/GraphicsFPS.dmg"
	exit 0
fi

if [ ! -f scenes/levels/alps_level.tscn ]; then
	echo "This checkout has no Alps: scenes/levels has files that are not in git"
	exit 1
fi
tools/export.sh macos || exit 1
build=$(sed -E 's/[^0-9]//g' build/src/build.json)

rm -rf "$OUT" build/stage
mkdir -p "$OUT" build/stage
ditto -x -k build/GraphicsFPS-macos.zip build/stage || exit 1
if ! codesign --verify --deep --strict "build/stage/Graphics FPS.app"; then
	echo "The app's signature does not hold"
	exit 1
fi
ln -s /Applications build/stage/Applications
hdiutil create -quiet -volname "Graphics FPS" -srcfolder build/stage -format ULFO -ov "$OUT/GraphicsFPS.dmg" || exit 1
rm -rf build/stage

(cd "$OUT" && split -b "${PART_MB}m" ../GraphicsFPS-macos.zip "update-$build-") || exit 1
list=""
for part in "$OUT"/update-"$build"-*; do
	name=$(basename "$part")
	sum=$(shasum -a 256 "$part" | cut -d' ' -f1)
	url="https://github.com/$REPO/releases/download/build-$build/$name"
	list="$list${list:+, }{\"url\": \"$url\", \"size\": $(stat -f %z "$part"), \"sha256\": \"$sum\"}"
done
printf '{"build": %s, "size": %s, "parts": [%s]}\n' "$build" "$(stat -f %z build/GraphicsFPS-macos.zip)" "$list" >"$OUT/update-macos.json"

ls -lh "$OUT"
