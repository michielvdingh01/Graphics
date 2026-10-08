extends Node
## Fixed-camera benchmark. Run with: tools/benchmark.sh
##
## Visits every Marker3D in the "benchmark_view" group, measures frame times and
## saves a screenshot per view plus results.json to benchmark/results/<timestamp>/.

const WARMUP_FRAMES := 120
const MEASURE_FRAMES := 600
const RESOLUTION := Vector2i(1920, 1080)

## True for a benchmark run; gameplay systems check this and stay out of the way.
var active := false


func _ready() -> void:
	active = "--benchmark" in OS.get_cmdline_user_args()
	if active:
		_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# Render at a fixed resolution regardless of the window size macOS gives us.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_window().content_scale_size = RESOLUTION
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
		for i in WARMUP_FRAMES:
			await tree.process_frame

		var frame_ms := PackedFloat64Array()
		var last := Time.get_ticks_usec()
		for i in MEASURE_FRAMES:
			await tree.process_frame
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
		"resolution": [get_viewport().size.x, get_viewport().size.y],
		"views": views,
	}
	var file := FileAccess.open(out_dir.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("Saved to ", out_dir)
	tree.quit()
