extends Node
## The sandbox: one fight in one zone of a level, fought over and over, to
## find out what something is like to play. It is opened from the title
## screen, or with --sandbox=<experiment> on the command line, optionally
## followed by a colon and the number of the variant to start with.
##
## assets/sandbox.json lists the experiments. One names a level and a zone of
## it, which is the arena; who stands at the posts of that zone ("squad", or
## else whoever the level has there); and its variants, each a theme the way
## scripts/enemy_themes.gd reads one: {"name": "the whole room", "like":
## "panic_clowns", "tuning": {"panic_radius": 30.0}}. So what is to be
## compared has to be an exported variable of scripts/enemy.gd.
##
## A round is that fight with one of the variants. The player starts where
## the game would bring them to the zone, as good as new, and the fight begins
## as it does there: by walking in or by shooting. T starts the round again,
## Q and E do so with the variant before and the one after, and F and X say
## whether the round was any good. The pause menu has the rest (see
## Screen.PAUSE in menu.gd): the switches below, an enemy more where the
## player looks, and the level loaded again, which is what brings back a
## barrel that went off.
##
## Nothing of it is saved: what the game had saved is set aside for as long
## as the sandbox is open. What is kept is one line for every round in
## user://sandbox.jsonl: which variant, how it went and what was said of it.

signal changed

const THEMES := preload("res://scripts/enemy_themes.gd")
const FILE := "res://assets/sandbox.json"
const LOG := "user://sandbox.jsonl"
## How fast the game runs in slow motion.
const SLOW := 0.3
## Seconds between two looks at the ammunition that never runs out.
const TOP_UP := 0.5
## How far ahead of the player an enemy can be put.
const REACH := 40.0
## Metres between enemies that share a post.
const SHOULDER := 1.2
const ROLES: Array[String] = ["grunt", "rusher", "heavy"]

## True while the game is the sandbox.
var active := false
## Every experiment there is, by id, as the file has it.
var experiments := {}
## The experiment that is open, the variant that is played and the number of
## the round.
var id := ""
var variant := 0
var rounds := 0
## The theme the enemies of this round are cast from.
var theme := ""
## How the round ended: "" while it is going on, else "cleared" or "died".
var result := ""
## What was said of the round: "", "good" or "bad".
var verdict := ""

## Nothing hurts the player.
var unhurt := false:
	set(value):
		unhurt = value
		_apply()
## The ammunition never runs out. Magazines still do.
var endless := false:
	set(value):
		endless = value
		_apply()
var slow := false:
	set(value):
		slow = value
		_apply()
## The enemies stand as they stood when this was switched on.
var still := false:
	set(value):
		still = value
		_apply()

var _game: Node3D
var _zone: RefCounted
## Where the player starts a round.
var _pose := Transform3D()
## The posts of the zone: [kind, where] for each.
var _posts: Array = []
var _log := LOG
## What the round has come to: seconds of fighting and damage taken, and the
## shots and hits the run stood at when it began.
var _seconds := 0.0
var _hurt := 0.0
var _shots := 0.0
var _hits := 0.0
## True once the round that is going on or just over has its line in the log,
## and the variant it is played with: step() has moved on by then.
var _written := true
var _played := 0
var _top_up := 0.0
var _layer := CanvasLayer.new()
var _status := Label.new()
var _keys := Label.new()
var _outcome := Label.new()


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE)) if FileAccess.file_exists(FILE) else null
	var listed: Variant = parsed.get("experiments") if parsed is Dictionary else null
	if listed is Dictionary:
		for key: String in listed:
			var spec: Variant = listed[key]
			if spec is Dictionary and spec.get("variants") is Array and not spec.variants.is_empty() and ResourceLoader.exists(str(spec.get("level"))):
				experiments[key] = spec
			else:
				push_warning("%s: the experiment %s names no level or no variants" % [FILE, key])
	if SelfTest.active:
		# A test keeps a log of its own, and starts with none.
		_log = SelfTest.own_file("sandbox.jsonl")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_log))
	_build()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sandbox="):
			var asked := arg.get_slice("=", 1)
			open(asked.get_slice(":", 0), asked.get_slice(":", 1).to_int())


## Opens an experiment and goes to its level. False if there is none by that name.
func open(experiment: String, with_variant := 0) -> bool:
	if not experiments.has(experiment):
		push_warning("No experiment called '%s'; there is %s." % [experiment, ", ".join(experiments.keys())])
		return false
	close()
	active = true
	id = experiment
	rounds = 0
	Save.set_aside(true)
	var variants: Array = experiments[id].variants
	for i in variants.size():
		THEMES.define(_theme(i), variants[i])
	variant = clampi(with_variant, 0, variants.size() - 1)
	# As the game starts its first level is still on its way in: that one
	# sends the player on if it is the wrong one, see arrive().
	var scene := get_tree().current_scene
	if scene and scene.is_node_ready():
		Loading.go(experiments[id].level)
	return true


## Leaves the sandbox: the switches go off and what was saved is back. Where
## the player goes from here is up to whoever closed it.
func close() -> void:
	if not active:
		return
	_write()
	unhurt = false
	endless = false
	slow = false
	still = false
	active = false
	_game = null
	_zone = null
	_layer.visible = false
	Save.set_aside(false)


## A level has loaded while the sandbox is open: it becomes the arena, or the
## player is sent on to the level that has it.
func arrive(game: Node3D) -> void:
	var spec: Dictionary = experiments[id]
	if game.scene_file_path != spec.level:
		Loading.go.call_deferred(spec.level)
		return
	_game = game
	_zone = null
	for zone: RefCounted in game.zones:
		if zone.id == spec.get("zone") or _zone == null:
			_zone = zone
	if _zone == null:
		push_warning("%s has no zones to fight in" % spec.level)
		_game = null
		return
	# The way in is the way the game brings the player to this zone.
	_pose = game.start
	for checkpoint: RefCounted in game.checkpoints:
		if checkpoint.order < _zone.order:
			_pose = checkpoint.pose
	# The rest of the route is done with, and there is no way on or out.
	for zone: RefCounted in game.zones:
		zone.started = zone != _zone
		zone.cleared = zone != _zone
	game.checkpoints.clear()
	game.exit = null
	_posts.clear()
	for spawn in _zone.area.get_children():
		if spawn.is_in_group("enemy_spawn"):
			_posts.append([spawn.get_meta(&"kind"), (spawn as Node3D).global_position])
	game.player.died.connect(_finish.bind("died"))
	game.player.damaged.connect(func(amount: float) -> void: _hurt += amount)
	_layer.visible = true
	_begin()


## Starts the round again, with the same variant.
func restart() -> void:
	if _game:
		_begin()


## Starts a round with the variant `by` places further on.
func step(by: int) -> void:
	variant = posmod(variant + by, variants())
	restart()


## Loads the level again and starts a round in it: everything in it is as it
## was, which a round started again does not do for what was blown up.
func reload() -> void:
	if _game:
		_write()
		_game = null
		Loading.again()


## Says of the round that it was good, or that it was not.
func judge(good: bool) -> void:
	if _game:
		verdict = "good" if good else "bad"
		_show()


## Stands one more enemy where the player looks. False if that is nowhere.
func put(kind: String) -> bool:
	if _game == null:
		return false
	var camera: Camera3D = _game.player.camera
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * REACH, 1)
	var hit := _game.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	# On the floor nearest to that, a step this way from a wall.
	var at: Vector3 = hit.position + hit.normal * 0.6
	at = NavigationServer3D.map_get_closest_point(_game.get_world_3d().navigation_map, at)
	_game.post(_zone, kind, at, _game.player.global_position)
	_apply()
	return true


## How many variants the experiment has, and what the one that is played is
## called: "B of 3: the whole room".
func variants() -> int:
	return experiments[id].variants.size() if active else 0


func variant_name() -> String:
	return "%s of %d: %s" % [char(65 + variant), variants(), str(experiments[id].variants[variant].get("name", ""))]


func title(experiment := "") -> String:
	if experiment == "":
		experiment = id
	return str(experiments[experiment].get("title", experiment.capitalize()))


func _theme(index: int) -> String:
	return "sandbox %s %d" % [id, index]


## A round: the zone as it was before its fight, with the variant's enemies
## at its posts, and the player at the way in as a level starts.
func _begin() -> void:
	_write()
	rounds += 1
	_played = variant
	theme = _theme(variant)
	result = ""
	verdict = ""
	_seconds = 0.0
	_hurt = 0.0
	_shots = Save.stats.shots
	_hits = Save.stats.hits
	_written = false
	_game.reset(_zone)
	Fx.clear()
	Blast.clear()
	var squad: Array = experiments[id].get("squad", [])
	for i in squad.size() if squad else _posts.size():
		var post: Array = _posts[i % _posts.size()]
		# More of them than posts: the rest stand next to one that is taken.
		@warning_ignore("integer_division")
		var beside := Vector3(SHOULDER * (i / _posts.size()), 0, 0).rotated(Vector3.UP, i * 2.4)
		_game.post(_zone, squad[i] if squad else post[0], post[1] + beside, _pose.origin)
	_game.player.revive(_pose)
	_game.player.weapons.restock()
	_apply()
	_show()


func _finish(how: String) -> void:
	if result == "":
		result = how
		_show()


func _physics_process(delta: float) -> void:
	if _game == null:
		return
	if result == "" and _zone.cleared:
		_finish("cleared")
	elif result == "" and _zone.started:
		_seconds += delta
	if endless:
		_top_up -= delta
		if _top_up <= 0.0:
			_top_up = TOP_UP
			_game.player.weapons.resupply()
	if still:
		_hold()


func _unhandled_input(event: InputEvent) -> void:
	if _game == null or not event is InputEventKey or not event.pressed or event.echo:
		return
	match (event as InputEventKey).physical_keycode:
		KEY_T:
			restart()
		KEY_Q:
			step(-1)
		KEY_E:
			step(1)
		KEY_F:
			judge(true)
		KEY_X:
			judge(false)
		_:
			return
	get_viewport().set_input_as_handled()


## Brings the game in line with the switches.
func _apply() -> void:
	Engine.time_scale = SLOW if slow else 1.0
	if _game:
		_game.player.invulnerable = unhurt
		_hold()
		_show()


## Stops the enemies where they are, or lets those go whose fight has begun.
func _hold() -> void:
	for robot: Variant in _zone.robots:
		if not is_instance_valid(robot) or robot.dead:
			continue
		if still:
			# It can still be shot at.
			robot.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
			robot.process_mode = Node.PROCESS_MODE_DISABLED
		elif _zone.started:
			robot.process_mode = Node.PROCESS_MODE_INHERIT


## The line of the round that is going on or just over, once.
func _write() -> void:
	if _written or _game == null:
		return
	_written = true
	var spec: Dictionary = experiments[id].variants[_played]
	var on: Array[String] = []
	for switch: String in ["unhurt", "endless", "slow", "still"]:
		if get(switch):
			on.append(switch)
	var line := {
		"at": Time.get_datetime_string_from_system(),
		"experiment": id,
		"variant": char(65 + _played),
		"name": spec.get("name", ""),
		"like": spec.get("like", ""),
		"tuning": spec.get("tuning", {}),
		"round": rounds,
		"result": result if result else "broken off",
		"seconds": snappedf(_seconds, 0.1),
		"damage": snappedf(_hurt, 0.1),
		"shots": int(Save.stats.shots - _shots),
		"hits": int(Save.stats.hits - _hits),
		"kills": _game.kills,
		"left": _zone.alive,
		"verdict": verdict,
		"with": on,
	}
	var file := FileAccess.open(_log, FileAccess.READ_WRITE if FileAccess.file_exists(_log) else FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line(JSON.stringify(line))


# --- What there is to see of it -------------------------------------------------


func _build() -> void:
	_layer.layer = 2
	_layer.visible = false
	add_child(_layer)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 24)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(column)
	# How a round went comes under where the HUD says that the player died.
	var gap := Control.new()
	gap.custom_minimum_size.y = 150
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for control: Control in [_status, _keys, gap, _outcome]:
		if control is Label:
			(control as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(control)
	_status.add_theme_font_size_override("font_size", 22)
	_keys.add_theme_font_size_override("font_size", 18)
	_keys.modulate.a = 0.6
	_outcome.add_theme_font_size_override("font_size", 30)


func _show() -> void:
	_status.text = "SANDBOX   ·   %s   ·   %s   ·   round %d" % [title(), variant_name(), rounds]
	var keys := "T  again      Q  E  other variant      F  good      X  bad      Esc  more"
	var on := PackedStringArray()
	for pair: Array in [[unhurt, "nothing hurts you"], [endless, "ammunition never runs out"], [slow, "slow motion"], [still, "enemies hold still"]]:
		if pair[0]:
			on.append(pair[1])
	_keys.text = keys + ("\n" + "   ·   ".join(on) if on else "")
	var shots: float = Save.stats.shots - _shots
	var text := ""
	match result:
		"cleared":
			text = "Cleared in %d s   ·   %d damage taken" % [roundi(_seconds), roundi(_hurt)]
			if shots > 0.0:
				text += "   ·   %d%% of %d shots hit" % [roundi(100.0 * (Save.stats.hits - _hits) / shots), int(shots)]
		"died":
			text = "Down after %d s   ·   %d of %d still standing" % [roundi(_seconds), _zone.alive, _zone.robots.size()]
	if verdict:
		text += ("\n" if text else "") + "Noted: %s" % verdict
	_outcome.text = text
	changed.emit()
