extends Node
## User settings: stored in user://settings.cfg and applied to the window,
## the viewport and the environment of whatever level is loaded.
##
## Benchmark and self-test runs ignore the saved file so results stay
## comparable; a benchmark takes --quality=, --upscaler= and --scale= on the
## command line instead.

signal changed

const PATH := "user://settings.cfg"
const QUALITY_NAMES: Array[String] = ["Low", "Medium", "High", "Ultra"]
## Index matches Viewport.Scaling3DMode.
const UPSCALER_NAMES: Array[String] = ["Bilinear", "FSR 1", "FSR 2", "MetalFX Spatial", "MetalFX Temporal"]
const UPSCALER_ARGS: Array[String] = ["bilinear", "fsr1", "fsr2", "metalfx", "metalfx_temporal"]
const KEYS: Array[String] = [
	"quality", "upscaler", "render_scale", "vsync", "fullscreen", "show_fps",
	"fov", "mouse_sensitivity", "stick_sensitivity", "invert_y", "volume",
]

# Per quality level: [SSAO, SSIL, SSR, volumetric fog, MSAA, sun shadow atlas,
# soft shadow quality, chromatic aberration]
# SSIL is left to Ultra: next to baked lightmaps it is all but invisible, and
# it takes 1.25 ms of a 14 ms frame. So is the chromatic aberration of the
# lens pass, the one part of it that has to read the frame back.
const QUALITY := [
	[false, false, false, false, Viewport.MSAA_DISABLED, 2048, RenderingServer.SHADOW_QUALITY_SOFT_LOW, false],
	[true, false, false, true, Viewport.MSAA_DISABLED, 4096, RenderingServer.SHADOW_QUALITY_SOFT_LOW, false],
	[true, false, true, true, Viewport.MSAA_2X, 4096, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, false],
	[true, true, true, true, Viewport.MSAA_4X, 8192, RenderingServer.SHADOW_QUALITY_SOFT_HIGH, true],
]
const LENS := preload("res://shaders/post.gdshader")
const LENS_ABERRATION := preload("res://shaders/post_aberration.gdshader")
const ENV_TOGGLES: Array[String] = ["ssao_enabled", "ssil_enabled", "ssr_enabled", "volumetric_fog_enabled"]

## Index into QUALITY_NAMES.
var quality := 2
var upscaler := Viewport.SCALING_3D_MODE_BILINEAR
## Fraction of the output resolution the 3D scene is rendered at.
var render_scale := 1.0
var vsync := true
var fullscreen := false
var show_fps := true
var fov := 80.0
var mouse_sensitivity := 1.0
var stick_sensitivity := 1.0
var invert_y := false
var volume := 0.8


func _ready() -> void:
	if Benchmark.active:
		_read_args()
	elif not SelfTest.active:
		_load()
	apply()


## Changes one setting, applies it and saves.
func put(key: String, value: Variant) -> void:
	if get(key) == value:
		return
	set(key, value)
	apply()
	if not Benchmark.active and not SelfTest.active:
		_save()


func summary() -> Dictionary:
	return {
		"quality": QUALITY_NAMES[quality],
		"upscaler": UPSCALER_NAMES[upscaler],
		"render_scale": render_scale,
	}


## True when the upscaler in use does its own anti-aliasing over several frames.
func temporal_upscaling() -> bool:
	return upscaler in [Viewport.SCALING_3D_MODE_FSR2, Viewport.SCALING_3D_MODE_METALFX_TEMPORAL]


## Safe to call at any time; levels call it once their environment is in the tree.
func apply() -> void:
	var preset: Array = QUALITY[quality]
	var viewport := get_viewport()
	viewport.scaling_3d_mode = upscaler
	viewport.scaling_3d_scale = render_scale
	# Temporal upscalers resolve edges themselves and do not combine with MSAA.
	viewport.msaa_3d = Viewport.MSAA_DISABLED if temporal_upscaling() else preset[4]
	RenderingServer.directional_shadow_atlas_set_size(preset[5], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(preset[6])
	RenderingServer.positional_soft_shadow_filter_set_quality(preset[6])

	var environment := viewport.find_world_3d().environment
	if environment:
		# Remember what the level was authored with, so a preset only ever
		# switches off effects and never adds one the level did not ask for.
		if not environment.has_meta(&"authored"):
			var toggles := {}
			for toggle in ENV_TOGGLES:
				toggles[toggle] = environment.get(toggle)
			environment.set_meta(&"authored", toggles)
		var authored: Dictionary = environment.get_meta(&"authored")
		for i in ENV_TOGGLES.size():
			environment.set(ENV_TOGGLES[i], authored[ENV_TOGGLES[i]] and preset[i])

	for lens: CanvasItem in get_tree().get_nodes_in_group(&"lens"):
		(lens.material as ShaderMaterial).shader = LENS_ABERRATION if preset[7] else LENS

	# A bus's fader comes after its effects: the slider turns the finished mix
	# down and leaves how hard the limiter works alone.
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.0)
	if not Benchmark.active and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
		)
		var mode := Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
		if get_window().mode != mode:
			get_window().mode = mode
	changed.emit()


func _load() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	for key in KEYS:
		var value: Variant = file.get_value("settings", key, get(key))
		if typeof(value) == typeof(get(key)):
			set(key, value)
	quality = clampi(quality, 0, QUALITY.size() - 1)
	upscaler = clampi(upscaler, 0, UPSCALER_NAMES.size() - 1) as Viewport.Scaling3DMode
	render_scale = clampf(render_scale, 0.5, 1.0)


func _save() -> void:
	var file := ConfigFile.new()
	for key in KEYS:
		file.set_value("settings", key, get(key))
	file.save(PATH)


func _read_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--quality="):
			quality = clampi(value.to_int(), 0, QUALITY.size() - 1)
		elif arg.begins_with("--upscaler="):
			upscaler = UPSCALER_ARGS.find(value) as Viewport.Scaling3DMode
			if upscaler < 0:
				# Falling back to bilinear would file a native-resolution run
				# under the name of an upscaler.
				push_error("Unknown upscaler '%s'; choose from %s" % [value, ", ".join(UPSCALER_ARGS)])
				upscaler = Viewport.SCALING_3D_MODE_BILINEAR
				get_tree().quit(1)
		elif arg.begins_with("--scale="):
			render_scale = clampf(value.to_float(), 0.25, 1.0)
