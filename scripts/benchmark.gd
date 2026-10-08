extends Node
## Fixed-camera benchmark. Run with: tools/benchmark.sh
##
## Visits every Marker3D in the "benchmark_view" group, measures frame times and
## saves a screenshot per view plus results.json to benchmark/results/<timestamp>/.
##
## Options: --quick, --res=2560x1440, --scene=res://scenes/depot.tscn, and the
## --quality=, --upscaler= and --scale= switches documented in settings.gd.

const DEFAULT_RESOLUTION := Vector2i(1920, 1080)

## True for a benchmark run; gameplay systems check this and stay out of the way.
var active := false

var _resolution := DEFAULT_RESOLUTION
var _scene := ""
var _warmup_frames := 120
var _measure_frames := 600


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	active = "--benchmark" in args
	# --quick only needs the screenshots, for iterating on the look of a scene.
	if "--quick" in args:
		_warmup_frames = 90
		_measure_frames = 30
	for arg in args:
		if arg.begins_with("--res="):
			var parts := arg.get_slice("=", 1).split("x")
			_resolution = Vector2i(parts[0].to_int(), parts[1].to_int())
		elif arg.begins_with("--scene="):
			_scene = arg.get_slice("=", 1)
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

	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()

	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var out_dir := ProjectSettings.globalize_path("res://benchmark/results/" + stamp)
	DirAccess.make_dir_recursive_absolute(out_dir)

	var views := []
	for view: Node3D in tree.get_nodes_in_group("benchmark_view"):
		camera.global_transform = view.global_transform
		for i in _warmup_frames:
			await tree.process_frame

		var frame_ms := PackedFloat64Array()
		var last := Time.get_ticks_usec()
		var drawn := Engine.get_frames_drawn()
		var covered := false
		while frame_ms.size() < _measure_frames:
			await tree.process_frame
			var now := Time.get_ticks_usec()
			# macOS does not draw a covered window. The main loop then idles at
			# a fixed rate that would pass for an excellent frame time, so only
			# an unbroken run of drawn frames counts.
			if Engine.get_frames_drawn() == drawn:
				if not covered:
					print("%s: window is not being drawn, waiting to start over" % view.name)
				covered = true
				frame_ms.clear()
			else:
				covered = false
				frame_ms.append((now - last) / 1000.0)
			drawn = Engine.get_frames_drawn()
			last = now

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
		views.append(result)
		print("%-12s %7.1f fps avg  %7.1f fps 1%% low" % [view.name, result.avg_fps, result.low_1pct_fps])

	var commit := []
	OS.execute("git", ["rev-parse", "--short", "HEAD"], commit)
	var report := {
		"timestamp": stamp,
		"commit": commit[0].strip_edges() if commit else "",
		"godot": Engine.get_version_info().string,
		"gpu": RenderingServer.get_video_adapter_name(),
		"scene": tree.current_scene.scene_file_path,
		"resolution": [_resolution.x, _resolution.y],
		"settings": Settings.summary(),
		"views": views,
	}
	var file := FileAccess.open(out_dir.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("Saved to ", out_dir)
	tree.quit()
