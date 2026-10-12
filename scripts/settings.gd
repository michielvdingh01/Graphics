extends Node
## User settings: stored in user://settings.cfg and applied to the window,
## the viewport and the environment of whatever level is loaded.
##
## Benchmark and self-test runs ignore the saved file so results stay
## comparable; a benchmark takes --quality=, --upscaler= and --scale= on the
## command line instead. They draw at the full size of the window unless told
## otherwise; --scale=auto gives a benchmark the scale a player starts with.
## --undo= has a benchmark do something the way it was done before, see UNDO.

signal changed

const PATH := "user://settings.cfg"
const QUALITY_NAMES: Array[String] = ["Low", "Medium", "High", "Ultra"]
## Index matches Viewport.Scaling3DMode. The menu leaves MetalFX Temporal out:
## at half scale it hands a level of this game back as blocks of two by two
## pixels, where FSR 2 builds up a sharp image. It does work in an empty scene,
## and a benchmark can still ask for it. See PLAN.md.
const UPSCALER_NAMES: Array[String] = ["Bilinear", "FSR 1", "FSR 2", "MetalFX Spatial", "MetalFX Temporal"]
const UPSCALER_ARGS: Array[String] = ["bilinear", "fsr1", "fsr2", "metalfx", "metalfx_temporal"]
const KEYS: Array[String] = [
	"quality", "upscaler", "auto_scale", "render_scale", "vsync", "fullscreen", "show_fps",
	"fov", "view_motion", "mouse_sensitivity", "stick_sensitivity", "invert_y", "volume", "music",
	"enemy_theme", "difficulty",
]
const DIFFICULTY_NAMES: Array[String] = ["Easy", "Normal", "Hard"]
## What a difficulty changes, and nothing else does:
## - attackers: how many enemies may be shooting at the same moment;
## - rest: seconds after an attack before the next enemy gets its turn;
## - plates: the share of the robot grunts that carry a plate on their arm;
## - flankers: how many of a group go round the player;
## - damage: what an enemy's hit does, next to what its scene says;
## - warning: how long an attack is announced, next to what its scene says;
## - regen_to: the health that comes back by itself; the rest has to be found;
## - drops: how much there is to find, next to Normal.
const RULES: Array[Dictionary] = [
	{"attackers": 1, "rest": 1.2, "plates": 0.3, "flankers": 1, "damage": 0.6, "warning": 1.3, "regen_to": 50.0, "drops": 1.4},
	{"attackers": 2, "rest": 1.0, "plates": 0.5, "flankers": 1, "damage": 1.0, "warning": 1.0, "regen_to": 35.0, "drops": 1.0},
	{"attackers": 3, "rest": 0.5, "plates": 0.75, "flankers": 2, "damage": 1.35, "warning": 0.8, "regen_to": 25.0, "drops": 0.75},
]
const THEMES := preload("res://scripts/enemy_themes.gd")

# Per quality level: [SSAO, SSIL, SSR, volumetric fog, MSAA, soft shadow
# quality of the sun, soft shadow quality of the lamps, chromatic aberration]
#
# Ultra is held to 60 frames a second on the full screen of a 16 inch MacBook
# Pro, drawn at half scale, where it ran at 44 to 52. It kept its MSAA, the
# soft shadows of the sun and its chromatic aberration, though that is made
# another way (see apply()), and gave up three things. What each of them
# cost there and how little of the picture it changed is in PLAN.md, and
# UNDO puts any of them back for a run.
# - SSIL is on no level any more: next to baked lightmaps it is all but
#   invisible, and it took 1.4 to 1.8 ms of a frame.
# - The shadow of a lamp is looked up for every pixel within its range, with
#   sixteen samples at the highest quality and eight below it, and a pixel is
#   in the range of several lamps: that step took 1.0 to 2.3 ms. The sun
#   keeps the highest, which costs nothing that can be measured.
# - The sun shadow atlas of 8192, see SUN_ATLAS.
const QUALITY := [
	[false, false, false, false, Viewport.MSAA_DISABLED, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW, false],
	[true, false, false, true, Viewport.MSAA_DISABLED, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW, false],
	[true, false, true, true, Viewport.MSAA_2X, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, false],
	[true, false, true, true, Viewport.MSAA_4X, RenderingServer.SHADOW_QUALITY_SOFT_HIGH, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, true],
]
## The size of the sun's shadow atlas, on every quality level. The sun of a
## level is baked: its light and its shadow on walls, floors and containers
## are in the lightmaps, and the shadow map that is drawn every frame only
## falls on what has no lightmap: models, robots, the weapon, and the ground
## outside a level that is cut into zones. At 8192, as Ultra had it, that map
## took 2.1 to 3.1 ms of a frame; at 4096, as Medium and High had it, 0.3 ms
## more than at this size. Inside a level, with the soldiers at their posts,
## pictures at the three sizes differ no more than two pictures at one size;
## outside, the edge of a building's shadow on the ground moves a few pixels.
const SUN_ATLAS := 2048
## The same for a level under an open sky, where the shadow of the sun is all
## the shade there is: twice the size. At 8192 a wood of pines cost nine
## frames a second on Ultra at 3456 by 2160, see "De duinen" in PLAN.md.
const SUN_ATLAS_OPEN := 4096
## What it was per quality level, for UNDO.
const SUN_ATLAS_BEFORE: Array[int] = [2048, 4096, 4096, 8192]
## What a benchmark can do the way it was done before, to measure what a change
## is worth or to take a picture of what it changed: --undo=ssil,lamp_filter
## and so on, or --undo=all.
## - ssil: SSIL on, on Ultra;
## - lamp_filter: the shadows of the lamps filtered like those of the sun,
##   on Ultra;
## - sun_atlas: the sun shadow atlas the size it was, see SUN_ATLAS_BEFORE;
## - fringe: the chromatic aberration done by the lens pass, on every pixel
##   of the window and with its own grain, see scripts/lens_fringe.gd;
## - glow: the glow enlarged with a bicubic filter, and
## - ssao: SSAO at medium quality, as project.godot had them: it now asks for
##   a linear filter and low quality, 0.2 ms each and nothing to be seen;
## - lamps: every lamp lights whatever is in its range, see scripts/zones.gd;
## - occlusion: what a wall hides is drawn all the same, see scripts/zones.gd.
const UNDO: Array[String] = ["ssil", "lamp_filter", "sun_atlas", "fringe", "glow", "ssao", "lamps", "occlusion"]
const LENS := preload("res://shaders/post.gdshader")
const LENS_ABERRATION := preload("res://shaders/post_aberration.gdshader")
const FRINGE := preload("res://scripts/lens_fringe.gd")
const ENV_TOGGLES: Array[String] = ["ssao_enabled", "ssil_enabled", "ssr_enabled", "volumetric_fog_enabled"]
## What the 3D scene is drawn at when the render scale sets itself: the pixels
## of 1920 × 1080, whatever the size of the window. The screen of a 16 inch
## MacBook Pro has 3.6 times as many: drawing them all, the factory ran at 17
## fps on Ultra, against 48 to 59 at this size.
const AUTO_PIXELS := 1920.0 * 1080.0
## The render scale goes from MIN_SCALE to 1 in steps of SCALE_STEP.
const MIN_SCALE := 0.5
const SCALE_STEP := 0.05
## The most `view_motion` goes up to.
const MAX_VIEW_MOTION := 1.5

## Index into QUALITY_NAMES.
var quality := 2
var upscaler := Viewport.SCALING_3D_MODE_BILINEAR
## Lets the render scale follow the size of the window, see scale_for().
var auto_scale := false
## Fraction of the output resolution the 3D scene is rendered at. With
## `auto_scale` on it is what the window asked for, and setting it is no use.
var render_scale := 1.0
var vsync := true
var fullscreen := false
var show_fps := true
var fov := 80.0
## How much the view moves by itself: 1 as the game was made, 0 for a camera
## that holds perfectly still. It scales whatever moves the picture without the
## player's doing: the bob of a walk, the lean into a strafe or a slide, the
## dip of a landing, the widening of the view at a sprint, a slide, a shot or
## a blast, the rattle of an explosion and the knock of a hit. This is the
## accessibility setting that shooters offer against motion sickness, which is
## why it goes all the way down to nothing. It leaves alone what is part of
## playing: recoil of the aim, the zoom of the sights, the height of the eye,
## and everything the HUD draws. The weapon in view keeps a third of its own
## motion at zero: held dead still it looks broken, and it moves no more of
## the picture than itself.
var view_motion := 1.0
var mouse_sensitivity := 1.0
var stick_sensitivity := 1.0
var invert_y := false
var volume := 0.8
## How loud the music is next to everything else.
var music := 0.7
## 0 Easy, 1 Normal, 2 Hard: see RULES.
var difficulty := 1
## Who the enemies are: a theme from enemy_themes.gd, robots unless chosen
## otherwise here or with --enemies=<theme> on the command line. It holds for
## the enemies that spawn from then on.
var enemy_theme := THEMES.ROBOTS
## The themes to choose from, and their names as the menu shows them.
var enemy_themes: Array[String] = THEMES.names()
var enemy_names: Array[String] = []
## The same setting as an index into `enemy_themes`, for the menu.
var enemies: int:
	get:
		return maxi(enemy_themes.find(enemy_theme), 0)
	set(value):
		enemy_theme = enemy_themes[clampi(value, 0, enemy_themes.size() - 1)]

## What this run does the way it was done before: names from UNDO.
var _undone: Array[String] = []
## The chromatic aberration as it hangs on the environment of a level.
var _fringe_effect: CompositorEffect


func _ready() -> void:
	for theme in enemy_themes:
		enemy_names.append(theme.capitalize())
	if Benchmark.active:
		_read_args()
	elif not SelfTest.active:
		auto_scale = true
		upscaler = default_upscaler()
		_load()
	get_window().size_changed.connect(_fit_window)
	# The command line decides for this run, whatever was saved.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--enemies="):
			enemy_theme = arg.get_slice("=", 1)
	if not enemy_themes.has(enemy_theme):
		push_warning("No enemies called '%s'; choose from %s. They will be robots." % [enemy_theme, ", ".join(enemy_themes)])
		enemy_theme = THEMES.ROBOTS
	apply()


## Whether this run does `what`, one of UNDO, the way it was done before.
func undone(what: String) -> bool:
	return what in _undone


## What the difficulty that is set comes down to: see RULES.
func rules() -> Dictionary:
	return RULES[clampi(difficulty, 0, RULES.size() - 1)]


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


## The upscaler a player starts with: the cheapest that sharpens what it
## enlarges, which on Apple hardware is MetalFX's. At 3456 × 2160 and half
## scale it gave 63 to 67 fps where FSR 2 gave 45 to 47.
func default_upscaler() -> Viewport.Scaling3DMode:
	return Viewport.SCALING_3D_MODE_METALFX_SPATIAL if OS.get_name() == "macOS" else Viewport.SCALING_3D_MODE_FSR


## The render scale that draws the 3D scene at AUTO_PIXELS or just under it in
## a window of `size` pixels, counted in steps the way the slider counts them.
func scale_for(size: Vector2i) -> float:
	var scale := sqrt(AUTO_PIXELS / maxf(size.x * size.y, 1.0))
	return clampf(MIN_SCALE + floorf((scale - MIN_SCALE) / SCALE_STEP + 0.001) * SCALE_STEP, MIN_SCALE, 1.0)


## The size in pixels that a render scale of 1 draws the 3D scene at.
func output_size() -> Vector2i:
	var window := get_window()
	# Stretched as a viewport, which a benchmark does to draw at a size of its
	# choosing, a window draws at the size of its content and not at its own.
	if window.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT:
		return Vector2i(window.get_visible_rect().size)
	return window.size


## Safe to call at any time; levels call it once their environment is in the tree.
func apply() -> void:
	var preset: Array = QUALITY[quality]
	var viewport := get_viewport()
	if auto_scale:
		render_scale = scale_for(output_size())
	viewport.scaling_3d_mode = upscaler
	viewport.scaling_3d_scale = render_scale
	# Temporal upscalers resolve edges themselves and do not combine with MSAA.
	viewport.msaa_3d = Viewport.MSAA_DISABLED if temporal_upscaling() else preset[4]
	var ultra := quality == QUALITY.size() - 1
	# Under an open sky nothing of the sun is baked: its shadow falls on the
	# whole of a level and is all the shade there is. Such a level says so on
	# its environment and gets the larger atlas, see SUN_ATLAS_OPEN.
	var world := viewport.find_world_3d().environment
	var open_sky: bool = world != null and world.get_meta(&"open_sky", false)
	RenderingServer.directional_shadow_atlas_set_size(SUN_ATLAS_BEFORE[quality] if undone("sun_atlas") else (SUN_ATLAS_OPEN if open_sky else SUN_ATLAS), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(preset[5])
	RenderingServer.positional_soft_shadow_filter_set_quality(preset[5] if ultra and undone("lamp_filter") else preset[6])
	if undone("glow"):
		RenderingServer.environment_glow_set_use_bicubic_upscale(true)
	if undone("ssao"):
		RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50.0, 300.0)

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
		if ultra and undone("ssil"):
			environment.ssil_enabled = authored["ssil_enabled"]

	# The chromatic aberration is done on the 3D scene before it is enlarged,
	# where the renderer lets a script in there; elsewhere by the lens pass,
	# on every pixel of the window.
	var early := _fringe(preset[7] and not undone("fringe"))
	for lens: CanvasItem in get_tree().get_nodes_in_group(&"lens"):
		(lens.material as ShaderMaterial).shader = LENS_ABERRATION if preset[7] and not early else LENS

	# A bus's fader comes after its effects: the slider turns the finished mix
	# down and leaves how hard the limiter works alone.
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.0)
	var music_bus := AudioServer.get_bus_index(Sfx.MUSIC)
	if music_bus > 0:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(maxf(music, 0.0001)))
		AudioServer.set_bus_mute(music_bus, music <= 0.0)
	if not Benchmark.active and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
		)
		var mode := Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
		if get_window().mode != mode:
			get_window().mode = mode
	changed.emit()


## Hangs the chromatic aberration on the environment of the level that is
## loaded (scripts/lens_fringe.gd), or takes it off. Says whether it hangs
## there now.
func _fringe(on: bool) -> bool:
	var scene := get_tree().current_scene
	if scene == null or RenderingServer.get_rendering_device() == null:
		return false
	var hung := false
	for world: WorldEnvironment in scene.find_children("*", "WorldEnvironment", true, false):
		if world.compositor == null:
			if not on:
				continue
			world.compositor = Compositor.new()
		var effects := world.compositor.compositor_effects.filter(func(effect: CompositorEffect) -> bool: return not effect is FRINGE)
		if on:
			if _fringe_effect == null:
				_fringe_effect = FRINGE.new()
			effects.append(_fringe_effect)
			hung = true
		world.compositor.compositor_effects = effects
	return hung


## The window changed size, which a render scale that sets itself goes along
## with. Nothing else is applied again: the window is in the middle of
## becoming what it was asked to be.
func _fit_window() -> void:
	if not auto_scale or is_equal_approx(render_scale, scale_for(output_size())):
		return
	render_scale = scale_for(output_size())
	get_viewport().scaling_3d_scale = render_scale
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
	difficulty = clampi(difficulty, 0, RULES.size() - 1)
	upscaler = clampi(upscaler, 0, UPSCALER_NAMES.size() - 1) as Viewport.Scaling3DMode
	render_scale = clampf(render_scale, MIN_SCALE, 1.0)
	view_motion = clampf(view_motion, 0.0, MAX_VIEW_MOTION)
	# The menu no longer offers MetalFX Temporal; FSR 2 does what it was chosen for.
	if upscaler == Viewport.SCALING_3D_MODE_METALFX_TEMPORAL:
		upscaler = Viewport.SCALING_3D_MODE_FSR2
	# A file from before the render scale set itself names an upscaler that, at
	# full scale, had nothing to do: that was no choice to hold a player to.
	if not file.has_section_key("settings", "auto_scale") and render_scale >= 1.0 and not temporal_upscaling():
		upscaler = default_upscaler()


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
			auto_scale = value == "auto"
			render_scale = clampf(value.to_float(), 0.25, 1.0)
		elif arg.begins_with("--undo="):
			for what in value.split(",", false):
				if what == "all":
					_undone.assign(UNDO)
				elif what in UNDO:
					_undone.append(what)
				else:
					# Measuring a change that was never undone would pass for
					# a change that is worth nothing.
					push_error("Nothing called '%s' to undo; choose from %s" % [what, ", ".join(UNDO)])
					get_tree().quit(1)
