#!/bin/sh
# Tests scripts/updater.gd the way it runs for a friend: on an exported app, with
# the real export template, against a server here. A small project stands in for
# the game, tools/updater_test, built twice with another number. No window.
# Everything lands in the user folder of that project and in a temporary folder.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT=24580
NAME="Graphics FPS update test"
USER_DIR="$HOME/Library/Application Support/Godot/app_userdata/$NAME"
WORK=$(mktemp -d)
FAILED=0

check() {
	if [ "$2" = "$3" ]; then
		echo "ok    $1"
	else
		echo "FAIL  $1: wanted [$3], got [$2]"
		FAILED=1
	fi
}

# Exports the project as build $1 to $WORK/$1.zip.
export_build() {
	printf '{"build": %s}\n' "$1" >"$WORK/src/build.json"
	"$GODOT" --headless --path "$WORK/src" --export-release macOS "$WORK/$1.zip" >>"$WORK/export.log" 2>&1
	[ -f "$WORK/$1.zip" ] || { echo "The export failed, see $WORK/export.log"; exit 1; }
}

# Puts build $1 in the folder the server serves, in parts of 16 MB.
serve_build() {
	rm -f "$WORK/www/"*
	(cd "$WORK/www" && split -b 16m "../$1.zip" part-)
	list=""
	for part in "$WORK/www/"part-*; do
		name=$(basename "$part")
		sum=$(shasum -a 256 "$part" | cut -d' ' -f1)
		list="$list${list:+, }{\"url\": \"http://127.0.0.1:$PORT/$name\", \"size\": $(stat -f %z "$part"), \"sha256\": \"$sum\"}"
	done
	printf '{"build": %s, "size": %s, "parts": [%s]}\n' "$1" "$(stat -f %z "$WORK/$1.zip")" "$list" >"$WORK/www/update.json"
}

# Starts the installed game with the arguments given and waits for what it says
# in $WORK/run.log, which may come from the app it hands over to.
run() {
	rm -f "$WORK/run.log"
	"$WORK/installed/$NAME.app/Contents/MacOS/$NAME" --headless -- "--update-url=${URL:-http://127.0.0.1:$PORT/update.json}" "--log=$WORK/run.log" "$@" >/dev/null 2>&1
	waited=0
	while [ ! -s "$WORK/run.log" ] && [ "$waited" -lt 240 ]; do
		sleep 0.25
		waited=$((waited + 1))
	done
	said=$(cat "$WORK/run.log" 2>/dev/null)
}

cleanup() {
	kill "$SERVER" 2>/dev/null
	rm -rf "$WORK" "$USER_DIR"
}
trap cleanup EXIT

mkdir -p "$WORK/src" "$WORK/www"
cp "$ROOT"/tools/updater_test/* "$WORK/src/"
# A part that hangs takes a second here instead of half a minute.
sed 's/^const STALLED := .*/const STALLED := 1.0/' "$ROOT/scripts/updater.gd" >"$WORK/src/updater.gd"
"$GODOT" --headless --path "$WORK/src" --import >>"$WORK/export.log" 2>&1
export_build 1000
export_build 2000
ditto -x -k "$WORK/1000.zip" "$WORK/installed"
rm -rf "$USER_DIR"
python3 "$ROOT/tools/updater_test/serve.py" "$WORK/www" "$PORT" &
SERVER=$!
sleep 1

serve_build 1000
run
check "nothing newer: it stays and fetches nothing" "$said" "build=1000 state=IDLE"
check "and has no update folder" "$(ls "$USER_DIR/update" 2>/dev/null | wc -l | tr -d ' ')" "0"

URL=http://127.0.0.1:1/update.json
run
unset URL
check "no network: it plays on" "$said" "build=1000 state=IDLE"

serve_build 2000
run
check "a newer build is fetched and made ready" "$said" "build=1000 state=READY"
check "the app is there, whole" "$(codesign --verify --deep --strict "$USER_DIR/update/2000/app/$NAME.app" 2>&1)" ""
check "the parts are gone" "$(ls "$USER_DIR/update/2000" | tr -d '\n')" "app"
run
check "the next start hands over to it" "$said" "build=2000 state=IDLE"
sleep 1
check "and it got to a frame" "$(ls "$USER_DIR/update" | tr -d '\n')" "2000"

rm -rf "$USER_DIR/update"
run --restart
sleep 1
for wait in 1 2 3 4 5 6 7 8; do
	said=$(cat "$WORK/run.log")
	[ "$said" = "build=2000 state=IDLE" ] && break
	sleep 1
done
check "Restart to update hands over at once" "$said" "build=2000 state=IDLE"

rm -rf "$USER_DIR/update"
first=$(ls "$WORK/www" | grep part- | head -1)
echo "$first" >"$WORK/www/hang"
run
check "a part that hangs is fetched again" "$said" "build=1000 state=READY"
rm -f "$WORK/www/hang"

rm -rf "$USER_DIR/update"
last=$(ls "$WORK/www" | grep part- | tail -1)
cp "$WORK/www/$last" "$WORK/good"
printf 'x' | dd of="$WORK/www/$last" bs=1 seek=1000 conv=notrunc 2>/dev/null
rm -f "$WORK/www/requests.log"
run
check "a part that stays wrong: no update" "$said" "build=1000 state=FAILED"
check "and no app" "$(ls "$USER_DIR/update/2000/app" 2>/dev/null | wc -l | tr -d ' ')" "0"
cp "$WORK/good" "$WORK/www/$last"
rm -f "$WORK/www/requests.log"
run
check "the next start finishes it" "$said" "build=1000 state=READY"
check "fetching only the part that was wrong" "$(grep -c part- "$WORK/www/requests.log")" "1"

: >"$USER_DIR/update/trying-2000"
rm -f "$WORK/www/requests.log"
run
check "an update that never got to a frame is dropped" "$said" "build=1000 state=IDLE"
check "and removed" "$(ls "$USER_DIR/update" | tr -d '\n')" "trying-2000"
check "and not fetched again" "$(grep -c part- "$WORK/www/requests.log")" "0"

[ "$FAILED" = 0 ] && echo "The updater holds." || exit 1
