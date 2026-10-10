extends Node
## Fixed-camera benchmark. Run with: tools/benchmark.sh
##
## Visits every Marker3D in the "benchmark_view" group, measures frame times and
## saves a screenshot per view plus results.json to benchmark/results/<timestamp>/.
##
## Options: --quick, --res=2560x1440, --scene=res://scenes/depot.tscn, and the
## --quality=, --upscaler= and --scale= switches documented in settings.gd.
## --profile also switches each effect off in turn and reports what it costs;
## --off=ssil,glow leaves those effects off for the whole run, to compare
## screenshots with and without them. _profile_targets() lists the names.
## --at=x,y,z,yaw,pitch looks from that point instead of the fixed views, to
## inspect one corner of a level; several poses are separated by semicolons.
## --weapon=3 puts that weapon of the loadout in view as the player holds it,
## --weapon=3,1 as it looks aimed down the sights and --weapon=3,0,0.4 as it
## looks 40% of the way through reloading. --spawn=path@x,y,z,yaw
## stands a scene in the level at that spot, a model or an enemy, without
## letting it run; several are separated by semicolons, a fifth number scales
## it and a sixth poses an enemy: 1 aiming, 2 in mid-stride, 3 shot to pieces,
## 4 firing.
## Poses 5, 6 and 7 are mid-stride to its right, to its left and backwards, 8
## is the moment before it attacks and 9 the moment it is hit. --enemies=<theme>
## chooses who the enemies are, see scripts/enemy_themes.gd. --animate keeps
## what was spawned moving on the spot, to measure what it costs to show.
## --shoot=0.02 fires a shot along the view and shows it that many seconds
## later: the flash of the weapon in view, the tracer and what the bullet does
## to whatever it hits. --shoot=0.3,6,4 fires six shots within four degrees.
## --hold=0.5 shows what went off when the run began, such as that robot
## falling apart, that many seconds on. --blast=x,y,z sets off an explosion at
## that spot when the run begins, to look at with --hold; a fourth number is
## its size and a fifth the width in metres of the fire it leaves.
## --ignite=x,y,z holes whatever in the level can explode nearest to that
## point, there, and leaves it burning; --detonate=x,y,z sets it off. All of
## this is for looking at a model or an effect, not for measuring. --firefight=12
## is for measuring: it keeps firing that many shots a second along every
## view, six degrees wide, to show what the effects cost while they are all
## going off. --barrage=1 does the same with an explosion and its fire that
## many times a second, nine metres ahead of every view.
## --only=zones,dust limits --profile to those effects, to measure one thing
## several times over instead of everything once.
## --warmup=0 starts measuring a view that many frames after the camera got
## there instead of after 120. With 0 the slowest frame of a view includes
## whatever arriving there cost, such as the zones that had to be switched on.
## --show=Lamp makes a node of that name visible that a level keeps hidden
## until the game switches it on, such as the lamp over an exit; several are
## separated by commas.
## --posted stands the robots of the level's route at their posts, switched
## off, as the player finds them: to see a view as it is in the game, or to
## measure what it costs that they stand there.
## --exit shows the way out of the level as it is once every zone is cleared:
## the lamp over it on and its door rolled up.
## --awake=x,y,z is for measuring a fight: it stands the player at that spot,
## unseen and beyond hurting, and switches on every robot of the route at
## once. They come for the player from wherever they are posted, take cover
## and shoot. Give it a --warmup of a few hundred frames, so that they have
## arrived, and compare with --posted, where the same robots stand still.
## --snap=3 is for looking at the game itself instead of at a level: without
## --benchmark, and with --play to skip the title screen, it lets the game run
## as it is played, saves one screenshot after that many seconds and quits.
## --at stands the player at that pose first, and each --eval="..." runs a
## line of script one second in, with Menu, Save, game and player to call:
## --eval="Menu.show_end(12)" shows the end screen. The save file is left alone.

const DEFAULT_RESOLUTION := Vector2i(1920, 1080)
const PROFILE_FRAMES := 150
const SETTLE_FRAMES := 20
## Seconds to wait for a window that is not being drawn before giving up.
const COVERED_TIMEOUT := 60.0

## True for a benchmark run; gameplay systems check this and stay out of the way.
var active := false
## True for a --snap run, which plays the game but keeps no progress.
var snapping := false

var _resolution := DEFAULT_RESOLUTION
var _scene := ""
var _profile := false
var _animate := false
var _off := PackedStringArray()
var _at := PackedStringArray()
var _spawn := PackedStringArray()
var _weapon := PackedFloat64Array()
var _shoot := PackedFloat64Array()
var _hold := -1.0
var _blast := PackedFloat64Array()
var _ignite := PackedFloat64Array()
var _detonate := PackedFloat64Array()
var _firefight := 0.0
var _fire_due := 0.0
var _barrage := 0.0
var _blast_due := 0.0
var _eye: Camera3D
var _random := RandomNumberGenerator.new()
var _warmup_frames := 120
var _measure_frames := 600
var _snap := -1.0
var _only := PackedStringArray()
var _show := PackedStringArray()
var _eval := PackedStringArray()
var _posted := false
var _exit := false
var _awake := PackedFloat64Array()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	active = "--benchmark" in args
	# --quick only needs the screenshots, for iterating on the look of a scene.
	if "--quick" in args:
		_warmup_frames = 90
		_measure_frames = 30
	_profile = "--profile" in args
	_posted = "--posted" in args
	_exit = "--exit" in args
	_animate = "--animate" in args
	for arg in args:
		if arg.begins_with("--res="):
			var parts := arg.get_slice("=", 1).split("x")
			_resolution = Vector2i(parts[0].to_int(), parts[1].to_int())
		elif arg.begins_with("--scene="):
			_scene = arg.get_slice("=", 1)
		elif arg.begins_with("--off="):
			_off = arg.get_slice("=", 1).split(",")
		elif arg.begins_with("--at="):
			_at = arg.get_slice("=", 1).split(";")
		elif arg.begins_with("--spawn="):
			_spawn = arg.get_slice("=", 1).split(";")
		elif arg.begins_with("--weapon="):
			_weapon = arg.get_slice("=", 1).split_floats(",")
		elif arg.begins_with("--shoot="):
			_shoot = arg.get_slice("=", 1).split_floats(",")
		elif arg.begins_with("--hold="):
			_hold = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--blast="):
			_blast = arg.get_slice("=", 1).split_floats(",")
		elif arg.begins_with("--ignite="):
			_ignite = arg.get_slice("=", 1).split_floats(",")
		elif arg.begins_with("--detonate="):
			_detonate = arg.get_slice("=", 1).split_floats(",")
		elif arg.begins_with("--firefight="):
			_firefight = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--barrage="):
			_barrage = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--only="):
			_only = arg.get_slice("=", 1).split(",")
		elif arg.begins_with("--warmup="):
			_warmup_frames = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--show="):
			_show = arg.get_slice("=", 1).split(",")
		elif arg.begins_with("--awake="):
			_awake = arg.get_slice("=", 1).split_floats(",")
		elif arg.begins_with("--snap="):
			_snap = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--eval="):
			_eval.append(arg.trim_prefix("--eval="))
	snapping = not active and _snap >= 0.0
	if snapping:
		_snapshot.call_deferred()
	if active:
		_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	if _scene:
		tree.change_scene_to_file(_scene)
		await tree.scene_changed

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# Render at a fixed resolution regardless of the window size macOS gives us.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_window().content_scale_size = _resolution
	# macOS stops presenting frames to a covered window, which stalls the run.
	get_window().always_on_top = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var player: Node3D = tree.get_first_node_in_group("player")
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.visible = not _weapon.is_empty()
	# An effect is looked at with its clock stopped at the age that was asked for.
	Fx.held = _hold >= 0.0 or not _shoot.is_empty()
	for entry in _spawn:
		var numbers := entry.get_slice("@", 1).split_floats(",")
		var node: Node3D = (load(entry.get_slice("@", 0)) as PackedScene).instantiate()
		node.process_mode = Node.PROCESS_MODE_DISABLED
		tree.current_scene.add_child(node)
		node.position = Vector3(numbers[0], numbers[1], numbers[2])
		node.rotation_degrees.y = numbers[3]
		if numbers.size() > 4:
			node.scale = Vector3.ONE * numbers[4]
		if numbers.size() > 5 and node.has_method("preview"):
			node.preview(numbers[5])
		if _animate:
			node.process_mode = Node.PROCESS_MODE_INHERIT
			node.set_physics_process(false)
	if (_posted or not _awake.is_empty()) and tree.current_scene.has_method("post_robots"):
		tree.current_scene.post_robots()
	if _awake.size() >= 3 and player and tree.current_scene.has_method("post_robots"):
		# The player is there to be found and shot at, and does nothing.
		player.process_mode = Node.PROCESS_MODE_INHERIT
		player.global_position = Vector3(_awake[0], _awake[1], _awake[2])
		player.health = 1e9
		for zone: RefCounted in tree.current_scene.zones:
			tree.current_scene._start(zone)
	if _exit and tree.current_scene.has_method("_open_exit"):
		tree.current_scene._open_exit(false)
	if not _blast.is_empty():
		# It reads the floor off the colliders, which a level has a frame late.
		await tree.physics_frame
		await tree.physics_frame
		var at := Vector3(_blast[0], _blast[1], _blast[2])
		Fx.explosion(at, _blast[3] if _blast.size() > 3 else 1.0)
		if _blast.size() > 4:
			Fx.fire(Vector3(at.x, Fx.floor_below(at), at.z), _blast[4], 8.0)
	for numbers in [_ignite, _detonate]:
		if numbers.is_empty():
			continue
		await tree.physics_frame
		await tree.physics_frame
		var at := Vector3(numbers[0], numbers[1], numbers[2])
		var nearest: Node3D = null
		for explosive: Node3D in tree.get_nodes_in_group("explosive"):
			if nearest == null or explosive.global_position.distance_to(at) < nearest.global_position.distance_to(at):
				nearest = explosive
		# Whatever is alight would go off before the picture is taken, with
		# the clock of its effects standing still.
		for explosive: Node3D in tree.get_nodes_in_group("explosive"):
			explosive.process_mode = Node.PROCESS_MODE_DISABLED
		if numbers == _detonate:
			nearest.explode()
		else:
			nearest.take_damage(nearest.health, at, Vector3.DOWN)
	if _hold >= 0.0:
		Fx.advance(_hold)
	for node_name in _show:
		for node in tree.current_scene.find_children(node_name, "Node3D", true, false):
			node.visible = true
	# What is seen through a telescopic sight is drawn by the HUD.
	var aimed := _weapon.size() > 1 and _weapon[1] >= 1.0
	for hud in tree.get_nodes_in_group("hud"):
		hud.visible = aimed

	var targets := _profile_targets()
	for effect in _off:
		if not targets.has(effect):
			push_error("Unknown effect '%s'; choose from %s" % [effect, ", ".join(targets.keys())])
			tree.quit(1)
			return
		for target: Array in targets[effect]:
			target[0].set(target[1], false)

	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()

	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var out_dir := ProjectSettings.globalize_path("res://benchmark/results/" + stamp)
	DirAccess.make_dir_recursive_absolute(out_dir)

	var markers := tree.get_nodes_in_group("benchmark_view")
	if not _at.is_empty():
		markers.clear()
		for pose in _at:
			var numbers := pose.split_floats(",")
			var marker := Marker3D.new()
			marker.name = "Shot%d" % (markers.size() + 1)
			add_child(marker)
			marker.position = Vector3(numbers[0], numbers[1], numbers[2])
			marker.rotation_degrees = Vector3(numbers[4], numbers[3], 0.0)
			markers.append(marker)

	var views := []
	for view: Node3D in markers:
		camera.global_transform = view.global_transform
		_eye = camera
		if player and not _weapon.is_empty():
			# Look through the player's own eyes, so the weapon sits where it would.
			player.rotation = Vector3(0, view.global_rotation.y, 0)
			player.head.rotation.x = view.global_rotation.x
			player.global_position += view.global_position - player.camera.global_position
			player.camera.make_current()
			_eye = player.camera
			player.weapons.preview(int(_weapon[0]), _weapon[1] if _weapon.size() > 1 else 0.0, _weapon[2] if _weapon.size() > 2 else 0.0)
		if not _shoot.is_empty():
			# The level has to have its colliders before a shot can land on it.
			await tree.physics_frame
			await tree.physics_frame
			Fx.clear()
			_random.seed = 5
			_fire(_eye, int(_shoot[1]) if _shoot.size() > 1 else 1, _shoot[2] if _shoot.size() > 2 else 0.0)
			if not _weapon.is_empty():
				player.weapons.smoke(1.0)
			Fx.advance(_shoot[0])
		for i in _warmup_frames:
			await tree.process_frame

		var frame_ms: PackedFloat64Array = await _measure(_measure_frames, view.name)

		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join(view.name + ".png"))

		frame_ms.sort()
		var total := 0.0
		for ms in frame_ms:
			total += ms
		var avg_ms := total / frame_ms.size()
		var p99_ms := frame_ms[int(frame_ms.size() * 0.99)]
		var result := {
			"view": view.name,
			"avg_fps": snappedf(1000.0 / avg_ms, 0.1),
			"low_1pct_fps": snappedf(1000.0 / p99_ms, 0.1),
			"avg_ms": snappedf(avg_ms, 0.01),
			# The one slowest frame: a hitch, such as an effect seen for the first time.
			"worst_ms": snappedf(frame_ms[-1], 0.01),
			"draw_calls": RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
			),
			"primitives": RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
			),
		}
		print("%-12s %7.1f fps avg  %7.1f fps 1%% low  %6.1f ms worst frame" % [view.name, result.avg_fps, result.low_1pct_fps, result.worst_ms])
		if _profile:
			result["cost_ms"] = await _profile_view(view.name)
		views.append(result)

	if _profile:
		_print_profile(views)

	var commit := []
	OS.execute("git", ["rev-parse", "--short", "HEAD"], commit)
	var report := {
		"timestamp": stamp,
		"commit": commit[0].strip_edges() if commit else "",
		"godot": Engine.get_version_info().string,
		"gpu": RenderingServer.get_video_adapter_name(),
		# "embedded" for a run without a window, see tools/godot.sh.
		"display": DisplayServer.get_name(),
		"scene": tree.current_scene.scene_file_path,
		"resolution": [_resolution.x, _resolution.y],
		"settings": Settings.summary(),
		"enemies": Settings.enemy_theme,
		"off": _off,
		"views": views,
	}
	var file := FileAccess.open(out_dir.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("Saved to ", out_dir)
	tree.quit()


## Lets the game run for a moment and saves what is on screen then.
func _snapshot() -> void:
	var tree := get_tree()
	await tree.process_frame
	if _scene:
		tree.change_scene_to_file(_scene)
		await tree.scene_changed
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_window().content_scale_size = _resolution
	var player: Node3D = tree.get_first_node_in_group("player")
	if not _at.is_empty():
		var numbers := _at[0].split_floats(",")
		player.global_position = Vector3(numbers[0], numbers[1], numbers[2])
		player.rotation_degrees = Vector3(0.0, numbers[3], 0.0)
		player.head.rotation_degrees.x = numbers[4]
	await tree.create_timer(minf(1.0, _snap), true, false, true).timeout
	for line in _eval:
		var expression := Expression.new()
		if expression.parse(line, ["Menu", "Save", "game", "player"]) != OK:
			push_error("--eval: %s" % expression.get_error_text())
			continue
		expression.execute([Menu, Save, tree.current_scene, player], self)
	await tree.create_timer(maxf(_snap - 1.0, 0.05), true, false, true).timeout
	await RenderingServer.frame_post_draw
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var out_dir := ProjectSettings.globalize_path("res://benchmark/results/" + stamp)
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("snap.png"))
	print("Saved to ", out_dir)
	tree.quit()


func _process(delta: float) -> void:
	if _eye == null:
		return
	_fire_due += delta * _firefight
	while _fire_due >= 1.0:
		_fire_due -= 1.0
		_fire(_eye, 1, 6.0)
	_blast_due += delta * _barrage
	while _blast_due >= 1.0:
		_blast_due -= 1.0
		var ahead := _eye.global_position - (_eye.global_basis.z * Vector3(1, 0, 1)).normalized() * 9.0
		var ground := Vector3(ahead.x, Fx.floor_below(ahead, 20.0), ahead.z)
		Fx.explosion(ground + Vector3.UP * 0.45)
		Fx.fire(ground, 1.2, 3.0)


## Fires `count` shots along the view of `eye`, within `spread_deg` of it:
## only what there is to see of them.
func _fire(eye: Camera3D, count: int, spread_deg: float) -> void:
	var from := eye.global_position
	var muzzle := from + eye.global_basis * Vector3(0.15, -0.12, -0.8)
	if not _weapon.is_empty():
		var weapons: Node3D = eye.get_node("Weapons")
		weapons.flash()
		muzzle = weapons.muzzle_position()
	var spread := tan(deg_to_rad(spread_deg))
	for i in count:
		var angle := _random.randf() * TAU
		var radius := sqrt(_random.randf()) * spread
		var direction := (eye.global_basis * Vector3(cos(angle) * radius, sin(angle) * radius, -1.0)).normalized()
		var end := from + direction * 200.0
		var hit := eye.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, end, 0b101))
		if hit:
			end = hit.position
			if hit.collider.has_method("take_damage"):
				Fx.robot_hit(end, direction)
			else:
				Fx.impact(hit, direction)
		Fx.tracer(muzzle, end)


## Frame times in milliseconds of an unbroken run of drawn frames.
func _measure(frames: int, label: String) -> PackedFloat64Array:
	var frame_ms := PackedFloat64Array()
	var last := Time.get_ticks_usec()
	var drawn := Engine.get_frames_drawn()
	var covered := false
	var covered_since := 0
	while frame_ms.size() < frames:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		# macOS does not draw a covered window. The main loop then idles at
		# a fixed rate that would pass for an excellent frame time, so only
		# an unbroken run of drawn frames counts.
		if Engine.get_frames_drawn() == drawn:
			if not covered:
				print("%s: window is not being drawn, waiting to start over" % label)
				covered_since = now
			covered = true
			frame_ms.clear()
			if (now - covered_since) / 1e6 > COVERED_TIMEOUT:
				push_error("%s: window was not drawn for %d seconds; bring it to the front and run again" % [label, COVERED_TIMEOUT])
				get_tree().quit(1)
				# The tree only quits at the end of the frame.
				covered_since = now
		else:
			covered = false
			frame_ms.append((now - last) / 1000.0)
		drawn = Engine.get_frames_drawn()
		last = now
	return frame_ms


## Label -> the boolean properties that switch that part of the frame off.
func _profile_targets() -> Dictionary:
	var scene := get_tree().current_scene
	var environment := get_viewport().find_world_3d().environment
	var targets := {"sun_shadow": [], "lamp_shadows": []}
	for effect: String in ["ssao", "ssil", "ssr", "volumetric_fog", "glow"]:
		targets[effect] = [[environment, effect + "_enabled"]]
	for light: Light3D in scene.find_children("*", "Light3D", true, false):
		var label := "sun_shadow" if light is DirectionalLight3D else "lamp_shadows"
		targets[label].append([light, "shadow_enabled"])
	# The parts of a level the builder keeps apart, the dust in the air and the lens pass.
	for part: String in ["Props", "Decals", "Glass", "Dust", "Post"]:
		var node := scene.find_child(part, true, false)
		if node:
			targets[part.to_lower()] = [[node, "visible"]]
	# In a level that is cut into zones, every zone has such parts of its own,
	# and "zones" is drawing only the zones in sight: off draws all of them.
	var level := scene.get_node_or_null("Level")
	if level and "culling" in level:
		targets["zones"] = [[level, "culling"]]
		for part: String in ["Props", "Decals", "Glass", "Dust"]:
			targets[part.to_lower()] = []
			for node in level.find_children(part, "Node3D", true, false):
				targets[part.to_lower()].append([node, "visible"])
	return targets


## What each effect costs at the current view: the average frame time with
## everything on minus the one with that effect off, measured back to back so
## that drift over the run cancels out.
func _profile_view(label: String) -> Dictionary:
	var costs := {}
	var targets := _profile_targets()
	for effect: String in targets:
		if effect in _off:
			continue
		if not _only.is_empty() and effect not in _only:
			continue
		var on_ms := await _average_ms(label)
		var before := []
		for target: Array in targets[effect]:
			before.append(target[0].get(target[1]))
			target[0].set(target[1], false)
		var off_ms := await _average_ms(label)
		for i in before.size():
			targets[effect][i][0].set(targets[effect][i][1], before[i])
		costs[effect] = snappedf(on_ms - off_ms, 0.01)
	return costs


func _average_ms(label: String) -> float:
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	var frame_ms: PackedFloat64Array = await _measure(PROFILE_FRAMES, label)
	var total := 0.0
	for ms in frame_ms:
		total += ms
	return total / frame_ms.size()


func _print_profile(views: Array) -> void:
	var header := "%-16s" % "cost in ms"
	for view: Dictionary in views:
		header += "%10s" % view.view
	print(header)
	var row := "%-16s" % "whole frame"
	for view: Dictionary in views:
		row += "%10.2f" % view.avg_ms
	print(row)
	for effect: String in views[0].cost_ms:
		row = "%-16s" % effect
		for view: Dictionary in views:
			row += "%10.2f" % view.cost_ms[effect]
		print(row)
