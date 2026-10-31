extends CanvasLayer
## The screen a level loads behind: over black its name, a bar for how far
## along it is and a ring that turns, from the moment it is asked for until
## it can be played. Whatever starts a level does so with go() or again(),
## not with SceneTree.change_scene_to_file(), which did all of it in a single
## frame: from the title screen the dunes stood still for six seconds.
##
## The level that is left goes as it did with change_scene_to_file(): out of
## the tree at once, freed at the end of the frame. What it was loaded from
## is kept until the next one is loaded: what the two have in common, and
## all of it when the same level comes again after a death, is then not read
## again. The files are read on the loader's threads
## (ResourceLoader.load_threaded_request), and with them what the level
## loads by name as it comes in, see _alongside_of(). Building the level,
## its first frame and the navmesh still hold the main thread, and nothing
## turns then; before each of them a frame is on the screen that says what
## it waits for.
##
## It goes once the level has baked its navmesh and been drawn without
## anything new to make ready, while the HUD brings the picture up out of
## black (hud.gd, _lift_curtain()). Until then the menu takes no input.

## How long the screen takes to go, and how long it waits at most for the
## navmesh of a level that has come in, and for a frame of it that has
## nothing new in it.
const FADE := 0.35
const BAKE_WAIT := 3.0
const SETTLE_FRAMES := 8
## How long it waits at most for a match to begin once the level is baked.
const MATCH_WAIT := 10.0
## Where the bar is once the files are read, once the level is built and once
## its ways are found: roughly how the time goes in the dunes.
const READ := 0.6
const BUILT := 0.8
const FOUND := 0.95
## How the files of the level count against what is read alongside them.
const LEVEL_SHARE := 2.0
## How fast the bar catches up with how far along it is, and the ring turns.
const CATCH_UP := 8.0
const TURNS := 0.8
const MARGIN := 96
const RING := 13.0
const THEMES := preload("res://scripts/enemy_themes.gd")
## A level made with vehicles loads the riders by name as it comes in, and a
## match the soldiers of the puppets and what they carry, see _alongside_of().
const VEHICLE := "res://scripts/vehicle.gd"
const RIDER := "res://scripts/rider.gd"
const PUPPET := "res://scripts/puppet.gd"
const ARMORY := "res://scripts/armory.gd"


## Turns as long as it is drawn.
class Ring extends Control:
	var turn := 0.0

	func _draw() -> void:
		draw_arc(size * 0.5, RING, turn, turn + TAU * 0.7, 32, Menu.ACCENT, 3.0, true)


## The level that is being loaded, and the paths read alongside it.
var _scene := ""
var _alongside: Array[String] = []
## What the level that is in was loaded from, and what was read alongside
## it, until the next one is loaded.
var _level: PackedScene
var _kept: Array[Resource] = []
## Every path asked of the loader and not yet taken back from it.
var _requested := {}
## Which go() is under way: one that came later takes over from it.
var _run := 0
var _busy := false
## A level handed to the tree that has not come in yet, and whether the one
## asked for is in: asked for again then, it is loaded again.
var _switching := false
var _in := false
## How far along it is, and how far the bar shows it.
var _target := 0.0
var _shown := 0.0
var _fading: Tween

var _screen := Control.new()
var _name := Label.new()
var _note := Label.new()
var _bar := ColorRect.new()
var _step := Label.new()
var _percent := Label.new()
var _ring := Ring.new()


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


## True from the moment a level is asked for until it can be played.
func busy() -> bool:
	return _busy


## Leaves the level that is loaded for `scene`, behind this screen. `title`
## is what it says instead of the name of the level.
func go(scene: String, title := "") -> void:
	if _busy and scene == _scene and not _in:
		# It is on its way already.
		return
	if not ResourceLoader.exists(scene):
		# As change_scene_to_file() did: the level that is in stays.
		push_error("There is no level at %s" % scene)
		return
	_run += 1
	_scene = scene
	_busy = true
	_in = false
	get_viewport().gui_disable_input = true
	_open(title if title else Menu.level_name(scene))
	_load(_run)


## Loads the level that is loaded again, from the start: after a death, to
## have it behind the title screen, or for a match that is played again.
func again(title := "") -> void:
	var scene := get_tree().current_scene
	go(scene.scene_file_path if scene else _scene, title)


func _process(delta: float) -> void:
	# What a level that was left behind asked for is taken back once it is
	# there, so that the loader lets go of it.
	for path: String in _requested.keys():
		if path != _scene and not _alongside.has(path) and ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			ResourceLoader.load_threaded_get(path)
			_requested.erase(path)
	if not _screen.visible:
		return
	_ring.turn = wrapf(_ring.turn + delta * TAU * TURNS, 0.0, TAU)
	_ring.queue_redraw()
	_fill(maxf(_shown, lerpf(_shown, _target, 1.0 - exp(-delta * CATCH_UP))))


func _load(run: int) -> void:
	var tree := get_tree()
	if _switching:
		# A level handed over before this one was asked for comes in first.
		await tree.scene_changed
		if run != _run:
			return
	var leaving := tree.current_scene
	if leaving:
		tree.root.remove_child(leaving)
		leaving.queue_free()
	_alongside = _alongside_of(_scene)
	if _threaded():
		for path: String in [_scene] + _alongside:
			# Without sub-threads: with them an exported game hung for good in
			# the dunes, four times out of four, where a run from a checkout
			# did not.
			if not _requested.has(path) and ResourceLoader.load_threaded_request(path, "", false) == OK:
				_requested[path] = true
	_say("Loading", 0.0)
	var level: PackedScene
	while true:
		var status := _read()
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			level = _take(_scene)
			break
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			push_error("Could not load %s" % _scene)
			_fail()
			return
		await tree.process_frame
		if run != _run:
			return
	_requested.erase(_scene)
	_level = level
	_kept.clear()
	for path in _alongside:
		var resource := _take(path)
		_requested.erase(path)
		if resource:
			_kept.append(resource)
	_alongside.clear()
	_say("Building the level", READ)
	# On the screen before the main thread is held for it.
	await _drawn()
	if run != _run:
		return
	_switching = true
	tree.change_scene_to_packed(level)
	await tree.scene_changed
	_switching = false
	if run != _run:
		return
	_in = true
	var game := tree.current_scene
	var waited := 0.0
	if game.has_signal(&"baked") and not game.get(&"is_baked"):
		# The navmesh is baked a frame or two after the level is in, in one
		# frame, after the frame the level is first drawn in.
		_say("Finding the way", BUILT)
		while not game.get(&"is_baked") and waited < BAKE_WAIT:
			await tree.process_frame
			if run != _run:
				return
			if not is_instance_valid(game):
				# Something else has had another level come in, as the
				# selftest does: that is not this screen's to wait for.
				break
			waited += get_process_delta_time()
	if Match.active and not Net.is_guest():
		# A match begins a moment later: the arena is read from the navmesh,
		# in the dunes in one frame of a second, and everybody is stood in it.
		_say("Setting up the match", FOUND)
		waited = 0.0
		while Match.active and Match.state == Match.State.LOADING and waited < MATCH_WAIT:
			await tree.process_frame
			if run != _run:
				return
			waited += get_process_delta_time()
	_say("Getting the picture ready", FOUND)
	# Whatever is drawn for the first time is made ready under this screen:
	# it goes after a frame that made nothing new, see Fx.rehearse().
	var made := -1
	for i in SETTLE_FRAMES:
		await _drawn()
		if run != _run:
			return
		var now := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW)
		if now == made:
			break
		made = now
	_close()


## Until the frame that is being made is on the screen. Without one, as in
## the tests, there is no frame drawn to wait for: until the next frame.
func _drawn() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw


## Whether the files are read on the loader's threads. Without a screen, as
## in the tests, the renderer is a stand-in that cannot make meshes on other
## threads: there they are read on the main thread, all at once, as before.
func _threaded() -> bool:
	return DisplayServer.get_name() != "headless"


## What was read from `path`, or null if it could not be.
func _take(path: String) -> Resource:
	if _threaded():
		return ResourceLoader.load_threaded_get(path)
	return ResourceLoader.load(path)


## The share of what is asked for that is read, as the bar shows it, and
## whether it is all there or something could not be read.
func _read() -> ResourceLoader.ThreadLoadStatus:
	if not _threaded():
		return ResourceLoader.THREAD_LOAD_LOADED
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(_scene, progress)
	var done: float = LEVEL_SHARE * (progress[0] if progress else 0.0)
	for path in _alongside:
		var part := []
		var each := ResourceLoader.load_threaded_get_status(path, part)
		# What is missing is left out: a level is not held up by an enemy.
		if each == ResourceLoader.THREAD_LOAD_IN_PROGRESS and status == ResourceLoader.THREAD_LOAD_LOADED:
			status = each
		done += (part[0] if part else 1.0) / _alongside.size()
	_target = READ * done / (LEVEL_SHARE + (1.0 if _alongside else 0.0))
	return status


## What a level loads by name as it comes in, which is read here on the
## loader's threads instead of in the middle of building it: whom the
## enemies of the theme that is set can be, with what they carry; in a match
## instead the soldiers of the puppets in both uniforms, with whatever of the
## armory they may carry (puppet.gd); and in a level with vehicles the two
## soldiers who ride them (vehicle.gd hands them to Fx.rehearse()). In the
## dunes with soldiers that was 1.6 s of the 2 s it took to build, and 2 of
## the 3 s a match took to begin. A level that has to wait for something
## else it loads by name, as it comes in, gets that added here.
func _alongside_of(scene: String) -> Array[String]:
	var found: Array[String] = []
	if Match.active:
		var puppet: Script = load(PUPPET)
		for number in range(1, puppet.CHARACTERS + 1):
			found.append_array([puppet.CHARACTER % [number, number], puppet.SECOND % [number, number]])
		for weapon: Resource in load(ARMORY).all():
			found.append(THEMES.MODELS + weapon.resource_path.get_file().get_basename() + "_held.scn")
	else:
		found.append_array(THEMES.scenes(Settings.enemy_theme))
	if _made_with(scene, VEHICLE):
		var rider: Script = load(RIDER)
		found.append_array([rider.SOLDIER, rider.SECOND])
	var paths: Array[String] = []
	for path in found:
		if not paths.has(path) and ResourceLoader.exists(path):
			paths.append(path)
	return paths


## Whether `scene`, or a scene in it two deep, is made with `path`.
func _made_with(scene: String, path: String) -> bool:
	var scenes := [scene]
	for depth in 3:
		var inside := []
		for each: String in scenes:
			for dependency: String in ResourceLoader.get_dependencies(each):
				var file := dependency.get_slice("::", 2) if dependency.contains("::") else dependency
				if file == path:
					return true
				if file.get_extension() in ["tscn", "scn"]:
					inside.append(file)
		scenes = inside
	return false


## The level could not be loaded, and the one that was left is gone: the
## game starts again from the level it starts with.
func _fail() -> void:
	_requested.erase(_scene)
	_alongside.clear()
	var first: String = ProjectSettings.get_setting("application/run/main_scene")
	_close()
	if _scene != first:
		go(first)


# --- The screen ------------------------------------------------------------------


func _build() -> void:
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.visible = false
	add_child(_screen)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(black)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE)
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	for side in ["left", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	_screen.add_child(margin)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = Menu.COLUMN_WIDTH
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	_name.add_theme_font_size_override("font_size", 56)
	column.add_child(_name)
	_note.add_theme_font_size_override("font_size", 24)
	_note.modulate.a = 0.8
	column.add_child(_note)
	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	column.add_child(gap)

	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.12)
	track.custom_minimum_size.y = 6
	column.add_child(track)
	_bar.color = Menu.ACCENT
	_bar.size = Vector2(0.0, 6.0)
	track.add_child(_bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	_ring.custom_minimum_size = Vector2.ONE * (RING + 3.0) * 2.0
	row.add_child(_ring)
	for label in [_step, _percent]:
		label.add_theme_font_size_override("font_size", 22)
		label.modulate.a = 0.8
		row.add_child(label)
	_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


## Puts the screen up for a level, at the start of the bar, or keeps it up as
## it is for one that comes instead of the one it was up for.
func _open(title: String) -> void:
	_name.text = title.to_upper()
	var carries_on: bool = not Net.active and not Match.active and not Sandbox.active and Save.checkpoint.get("level", "") == _scene
	_note.text = str(Save.checkpoint.get("title", "")) if carries_on else ""
	_note.visible = _note.text != ""
	if _screen.visible and _screen.modulate.a == 1.0:
		return
	if _fading:
		_fading.kill()
	_screen.modulate.a = 1.0
	_screen.visible = true
	_target = 0.0
	_fill(0.0)


## What it waits for now, and how far along it is once that has begun: the
## bar is there at once, since the frame that says so may be the last one
## for a while.
func _say(step: String, along: float) -> void:
	_step.text = step
	_target = maxf(_target, along)
	_fill(_target)


func _fill(along: float) -> void:
	_shown = along
	_bar.size.x = (_bar.get_parent() as Control).size.x * along
	_percent.text = "%d%%" % floori(along * 100.0)


## The level can be played: the screen goes, and the menu takes input again.
func _close() -> void:
	_busy = false
	get_viewport().gui_disable_input = false
	_target = 1.0
	_fill(1.0)
	_fading = create_tween()
	_fading.tween_property(_screen, "modulate:a", 0.0, FADE)
	_fading.tween_callback(func() -> void: _screen.visible = false)
