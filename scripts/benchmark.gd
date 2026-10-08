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

const DEFAULT_RESOLUTION := Vector2i(1920, 1080)
const PROFILE_FRAMES := 150
const SETTLE_FRAMES := 20
## Seconds to wait for a window that is not being drawn before giving up.
const COVERED_TIMEOUT := 60.0

## True for a benchmark run; gameplay systems check this and stay out of the way.
var active := false

var _resolution := DEFAULT_RESOLUTION
var _scene := ""
var _profile := false
var _off := PackedStringArray()
var _at := PackedStringArray()
var _warmup_frames := 120
var _measure_frames := 600


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	active = "--benchmark" in args
	# --quick only needs the screenshots, for iterating on the look of a scene.
	if "--quick" in args:
		_warmup_frames = 90
		_measure_frames = 30
	_profile = "--profile" in args
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
	for player in tree.get_nodes_in_group("player"):
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.visible = false
	for hud in tree.get_nodes_in_group("hud"):
		hud.visible = false

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
			"draw_calls": RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
			),
			"primitives": RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
			),
		}
		print("%-12s %7.1f fps avg  %7.1f fps 1%% low" % [view.name, result.avg_fps, result.low_1pct_fps])
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
		"off": _off,
		"views": views,
	}
	var file := FileAccess.open(out_dir.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("Saved to ", out_dir)
	tree.quit()


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
