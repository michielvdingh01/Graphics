extends Node
## Keeps a game handed out as an installer up to date from the releases on
## GitHub, see tools/release.sh. Only an exported Mac build does this, and only
## one that has a number, which tools/export.sh gives it in res://build.json. A
## game run from a checkout leaves all of this alone.
##
## An update is the whole app, as a zip in parts of a few hundred MB that are
## checked one at a time, so that a bad connection costs one part and not the
## whole download. Godot's release templates refuse --main-pack, so a new pack
## next to the old app cannot be run. It is unpacked in user://update and what
## was installed is never touched: macOS guards what it quarantined, and the
## app may be running from the disk image or from a translocated copy. What was
## installed stays as the way in. It starts, finds a newer app in user://update,
## opens that and is gone before it has loaded anything else, which is why this
## has to be the first autoload.
##
## Whether an update works only shows by running it. A newer app that was
## opened and never got to its first frame leaves trying-<build> behind, and
## is then neither opened nor fetched again. Otherwise a bad release could be
## cured neither by the next release, which it would not get to fetch, nor by
## installing again, since user://update would still win. The app in the Dock
## may also be clicked while the update is playing: open then only brings the
## game to the front, which is why getting the focus clears it too.

signal changed

enum State { IDLE, CHECKING, FETCHING, UNPACKING, READY, FAILED }

const MANIFEST := "https://github.com/michielvdingh01/Graphics/releases/latest/download/update-macos.json"
const FOLDER := "user://update/"
## How many times one part is fetched before the update gives up until the
## next start.
const TRIES := 4
## Seconds without a single byte before a part is fetched again.
const STALLED := 30.0
## Bytes at a time when the parts are joined.
const CHUNK := 1 << 23
## The room an update needs while it is on its way, as a share of its download:
## the zip and what is unpacked from it.
const ROOM := 3.0

## The number of this build, the time it was made as yyyymmddhhmm. 0 for a game
## run from a checkout: see Net._hello.
var build := 0
var state := State.IDLE
var _active := false
var _url := MANIFEST
## Why the last attempt failed.
var _problem := ""
var _http: HTTPRequest
## Bytes of the parts that are in, and of all of them.
var _done := 0
var _total := 0
var _bytes := 0
var _quiet := 0.0
var _percent := 0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("macos") or not FileAccess.file_exists("res://build.json"):
		return
	build = int(JSON.parse_string(FileAccess.get_file_as_string("res://build.json")).build)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--update-url="):
			_url = arg.trim_prefix("--update-url=")
	# The tests run an exported game without a window as well.
	_active = _url != MANIFEST or DisplayServer.get_name() != "headless"
	if _active:
		_open_newest()


func _ready() -> void:
	set_process(false)
	if not _active:
		return
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.download_chunk_size = 1 << 20
	add_child(_http)
	await get_tree().process_frame
	DirAccess.remove_absolute(_trial(build))
	_check()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and _active:
		DirAccess.remove_absolute(_trial(build))


## What the menu says about it, on one line.
func line() -> String:
	if not _active:
		return ""
	match state:
		State.CHECKING:
			return "Checking for updates"
		State.FETCHING:
			return "Downloading update  ·  %d%%  ·  %d of %d MB" % [_percent, (_done + _bytes) >> 20, _total >> 20]
		State.UNPACKING:
			return "Installing update"
		State.READY:
			return "Update ready"
		State.FAILED:
			return "Update failed, trying again next start  ·  %s" % _problem
	var stamp := str(build)
	return "Version %s-%s-%s %s:%s" % [stamp.left(4), stamp.substr(4, 2), stamp.substr(6, 2), stamp.substr(8, 2), stamp.substr(10, 2)]


## Leaves this game for the update that was fetched.
func restart() -> void:
	_open_newest()


func _process(delta: float) -> void:
	var bytes := _http.get_downloaded_bytes()
	_quiet = 0.0 if bytes != _bytes else _quiet + delta
	_bytes = bytes
	var percent := int(100.0 * (_done + _bytes) / maxf(_total, 1.0))
	if percent != _percent:
		_percent = percent
		changed.emit()
	if _quiet > STALLED:
		_quiet = 0.0
		_http.cancel_request()
		_http.request_completed.emit(HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray())


func _open_newest() -> void:
	var newest := 0
	if DirAccess.dir_exists_absolute(FOLDER):
		for folder in DirAccess.get_directories_at(FOLDER):
			if folder.to_int() > newest and DirAccess.dir_exists_absolute(_app(folder.to_int())):
				newest = folder.to_int()
	if newest <= build:
		return
	if FileAccess.file_exists(_trial(newest)):
		_remove(FOLDER + str(newest))
		return
	FileAccess.open(_trial(newest), FileAccess.WRITE)
	var args := PackedStringArray([ProjectSettings.globalize_path(_app(newest)), "--args"])
	if DisplayServer.get_name() == "headless":
		args.append("--headless")
	var told := OS.get_cmdline_user_args()
	if not told.is_empty():
		args.append("--")
		args.append_array(told)
	# Through open and not OS.create_process: that waits on the main thread for
	# an answer that comes on the main thread, and calls it a failure.
	if OS.execute("/usr/bin/open", args) == 0:
		OS.kill(OS.get_process_id())
	DirAccess.remove_absolute(_trial(newest))


func _app(number: int) -> String:
	return "%s%d/app/%s.app" % [FOLDER, number, ProjectSettings.get_setting("application/config/name")]


func _trial(number: int) -> String:
	return "%strying-%d" % [FOLDER, number]


func _set_state(new: State) -> void:
	state = new
	changed.emit()


func _fail(problem: String) -> void:
	_problem = problem
	set_process(false)
	_set_state(State.FAILED)


func _check() -> void:
	_set_state(State.CHECKING)
	_http.request(_url)
	var result: Array = await _http.request_completed
	var manifest: Variant = null
	if result[0] == HTTPRequest.RESULT_SUCCESS and result[1] == 200:
		manifest = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	# Nobody needs telling that a game without a network did not look.
	if not (manifest is Dictionary):
		_set_state(State.IDLE)
		return
	var newest := int(manifest.build)
	var wanted := newest > build and not FileAccess.file_exists(_trial(newest))
	_tidy(newest if wanted else build)
	if wanted:
		_fetch(newest, manifest.parts, int(manifest.size))
	else:
		_set_state(State.IDLE)


## Removes what older builds and broken-off downloads left behind.
func _tidy(keep: int) -> void:
	if not DirAccess.dir_exists_absolute(FOLDER):
		return
	for folder in DirAccess.get_directories_at(FOLDER):
		if folder.to_int() != keep and folder.to_int() != build:
			_remove(FOLDER + folder)


func _remove(path: String) -> void:
	OS.execute("/bin/rm", ["-rf", ProjectSettings.globalize_path(path)])


func _fetch(number: int, parts: Array, size: int) -> void:
	var folder := "%s%d/" % [FOLDER, number]
	DirAccess.make_dir_recursive_absolute(folder)
	if DirAccess.open(folder).get_space_left() < size * ROOM:
		_fail("%d MB of disk space needed" % int(size * ROOM / 1048576.0))
		return
	_total = size
	_set_state(State.FETCHING)
	set_process(true)
	for index in parts.size():
		if not await _fetch_part(parts[index], "%s%d.part" % [folder, index]):
			_fail("no connection")
			return
		_done += int(parts[index].size)
		_bytes = 0
	set_process(false)
	_set_state(State.UNPACKING)
	if await _in_thread(_unpack.bind(folder, parts.size())):
		_set_state(State.READY)
	else:
		_fail("could not unpack it")


## True once the part is there and is what it should be. A part left by a
## download that was broken off is not fetched again.
func _fetch_part(part: Dictionary, path: String) -> bool:
	for attempt in TRIES:
		if await _in_thread(_sha256.bind(path)) == part.sha256:
			return true
		_http.download_file = path
		_http.request(part.url)
		await _http.request_completed
		_bytes = 0
	return await _in_thread(_sha256.bind(path)) == part.sha256


func _sha256(path: String) -> String:
	return FileAccess.get_sha256(path)


func _in_thread(work: Callable) -> Variant:
	var thread := Thread.new()
	thread.start(work)
	while thread.is_alive():
		await get_tree().process_frame
	return thread.wait_to_finish()


## Joins the parts and unpacks the zip. The app gets its name last, so that one
## that is only half there is never opened.
func _unpack(folder: String, parts: int) -> bool:
	var zip := folder + "game.zip"
	var joined := FileAccess.open(zip, FileAccess.WRITE)
	if joined == null:
		return false
	for index in parts:
		var path := "%s%d.part" % [folder, index]
		var part := FileAccess.open(path, FileAccess.READ)
		while part.get_position() < part.get_length():
			if not joined.store_buffer(part.get_buffer(CHUNK)):
				return false
		part.close()
		DirAccess.remove_absolute(path)
	joined.close()
	var unpacked := folder + "unpacked"
	_remove(unpacked)
	var code := OS.execute("/usr/bin/ditto", ["-x", "-k", ProjectSettings.globalize_path(zip), ProjectSettings.globalize_path(unpacked)])
	DirAccess.remove_absolute(zip)
	return code == 0 and DirAccess.rename_absolute(unpacked, folder + "app") == OK
