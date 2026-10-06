extends Node
## Fixed-camera benchmark. Run with: tools/benchmark.sh [--quality=low|balanced|ultra]
##
## Visits every Marker3D in the "benchmark_view" group, measures frame times and
## saves a screenshot per view plus results.json to benchmark/results/<timestamp>/.
## Views with the meta flag `fx` also fire a steady stream of combat effects (tracers, decals,
## sparks), so the budget covers a firefight and not just an empty level.
##
## Optional arguments, mostly for quick checks on slow machines:
##   --frames=N  --warmup=N  --resolution=WxH  --views=Overview,Combat

const RESOLUTION := Vector2i(1920, 1080)
const FX_INTERVAL_FRAMES := 4
const FX_PER_BURST := 3

## True when running with --benchmark. Gameplay code uses it to freeze enemies and skip spawning.
var active := false

var _warmup_frames := 120
var _measure_frames := 600
var _resolution := RESOLUTION
var _only_views: PackedStringArray = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not "--benchmark" in args:
		return
	active = true
	for arg in args:
		if arg.begins_with("--frames="):
			_measure_frames = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--warmup="):
			_warmup_frames = int(arg.trim_prefix("--warmup="))
		elif arg.begins_with("--views="):
			_only_views = arg.trim_prefix("--views=").split(",")
		elif arg.begins_with("--resolution="):
			var parts := arg.trim_prefix("--resolution=").split("x")
			if parts.size() == 2:
				_resolution = Vector2i(int(parts[0]), int(parts[1]))
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# Render at a fixed resolution regardless of the window size macOS gives us.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_window().content_scale_size = _resolution
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for player: Node3D in tree.get_nodes_in_group("player"):
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.visible = false
	for hud in tree.get_nodes_in_group("hud"):
		hud.visible = false

	var camera := Camera3D.new()
	camera.fov = 80.0
	add_child(camera)
	camera.make_current()

	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var out_dir := ProjectSettings.globalize_path("res://benchmark/results/" + stamp)
	DirAccess.make_dir_recursive_absolute(out_dir)

	var views := []
	for view: Node3D in tree.get_nodes_in_group("benchmark_view"):
		if not _only_views.is_empty() and not view.name in _only_views:
			continue
		camera.global_transform = view.global_transform
		var fire_fx := view.get_meta("fx", false) as bool
		for i in _warmup_frames:
			await tree.process_frame
			_maybe_fx(camera, fire_fx, i)

		var frame_ms := PackedFloat64Array()
		var last := Time.get_ticks_usec()
		for i in _measure_frames:
			await tree.process_frame
			_maybe_fx(camera, fire_fx, i)
			var now := Time.get_ticks_usec()
			frame_ms.append((now - last) / 1000.0)
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
		"quality": Graphics.preset_name,
		"resolution": [get_viewport().size.x, get_viewport().size.y],
		"views": views,
	}
	var file := FileAccess.open(out_dir.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("Saved to ", out_dir)
	tree.quit()


func _maybe_fx(camera: Camera3D, enabled: bool, frame: int) -> void:
	if not enabled or frame % FX_INTERVAL_FRAMES != 0:
		return
	var space := camera.get_world_3d().direct_space_state
	Effects.test_burst(space, camera.global_position, -camera.global_basis.z, FX_PER_BURST)
