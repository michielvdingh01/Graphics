extends Node
## A cloud in front of the sun: now and then the light of a level under an
## open sky slowly weakens, stays weak for a while and comes back. The sky
## over the dunes is one of sun and cloud, and a day like that is never lit
## the same for a minute on end.
##
## It turns down the sun and, a little, the light of the sky, and nothing
## else: no shader knows of it, and the shadow of the cloud does not travel
## over the land. Under a cloud the shadows of the sun are faint, the land
## is flat and cooler, and what stood out against it does so less.
##
## A benchmark has none, so that a picture from a standpoint is the same
## picture every time; --cloud=0.7 holds one in front of the sun for all of a
## run, that much of a full one, to look at. Stands in the scene of a level,
## beside its "Sun", or by night its "Moon"; without its script line there
## the sun never dims.
##
## With `drifting` on, the clouds are a field that the wind moves over the
## land instead, and their shadows travel: shaders that include
## shaders/cloud_shadow.gdshaderinc show them further off, and the sun is
## turned down while one is over the eye. A benchmark has the field where it
## lies when the level loads, which is the same every time.

## What is left of the sun and of the light of the sky under a full cloud.
@export var sun_left := 0.3
@export var sky_left := 0.84
## How long the sun is out between two clouds, and how long a cloud takes to
## pass, in seconds: the least and the most.
@export var between := Vector2(45.0, 110.0)
@export var passing := Vector2(14.0, 34.0)
## What the sun is tinted towards under a cloud: its warmth goes first.
@export var veiled := Color(0.93, 0.95, 1.0)
## Clouds as a field that drifts over the land, and the way and speed it
## drifts, in metres a second (x east, y south).
@export var drifting := false
@export var wind := Vector2(5.6, -2.2)

## How long the edge of a cloud takes to cross the sun, in seconds: the
## least and the most.
const EDGE := Vector2(4.0, 8.0)
## One cloud in three is thin, and takes this share of what a full one does.
const THIN := 0.55

var _sun: DirectionalLight3D
var _world: Environment
var _energy := 1.0
var _colour := Color.WHITE
var _sky := 1.0
var _dice := RandomNumberGenerator.new()
## Seconds since the level loaded, and the cloud that is next or passing:
## when its edge reaches the sun, when it has passed, how long its edges
## take and how thick it is.
var _clock := 0.0
var _from := 0.0
var _until := 0.0
var _coming := 5.0
var _going := 5.0
var _thick := 1.0
## Not negative: a cloud that stays where it is, for a picture.
var _held := -1.0
## The field of a drifting sky, as the shaders read it, and how far it has
## drifted.
var _field: Image
var _drift := Vector2.ZERO


func _ready() -> void:
	_sun = get_parent().get_node_or_null("Sun") as DirectionalLight3D
	if _sun == null:
		_sun = get_parent().get_node_or_null("Moon") as DirectionalLight3D
	_world = get_viewport().find_world_3d().environment
	if _sun == null or _world == null:
		set_process(false)
		return
	_energy = _sun.light_energy
	_colour = _sun.light_color
	# The environment outlives one loading of the level, see scripts/eyes.gd.
	if not _world.has_meta(&"cloudless"):
		_world.set_meta(&"cloudless", _world.ambient_light_energy)
	_sky = _world.get_meta(&"cloudless")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cloud="):
			_held = clampf(arg.trim_prefix("--cloud=").to_float(), 0.0, 1.0)
	if _held >= 0.0:
		_cover(_held)
		set_process(false)
	elif drifting:
		_field = (load("res://assets/noise/alps_fbm.png") as Texture2D).get_image()
		_field.decompress()
		RenderingServer.global_shader_parameter_set(&"cloud_shade", 1.0 - sun_left)
		RenderingServer.global_shader_parameter_set(&"cloud_drift", _drift)
	elif Benchmark.active:
		set_process(false)
	else:
		_dice.seed = 1947
		_next(0.0)


func _exit_tree() -> void:
	if _world:
		_world.ambient_light_energy = _sky
	if drifting:
		# The next level has no drifting clouds unless it says so.
		RenderingServer.global_shader_parameter_set(&"cloud_shade", 0.0)
		RenderingServer.global_shader_parameter_set(&"cloud_here", 0.0)


func _process(delta: float) -> void:
	if drifting:
		_drift_on(delta)
		return
	_clock += delta
	if _clock > _until:
		_next(_clock)
	var over := smoothstep(_from, _from + _coming, _clock) * (1.0 - smoothstep(_until - _going, _until, _clock))
	# A cloud is not of one thickness: the light under it wavers.
	var wavers := 1.0 - 0.14 * (0.5 + 0.5 * sin(_clock * 0.61 + _from)) * (0.5 + 0.5 * sin(_clock * 0.23))
	_cover(over * _thick * wavers)


## Moves the field on with the wind, and turns the sun down by as much cloud
## as is over the eye.
func _drift_on(delta: float) -> void:
	if not Benchmark.active:
		_drift += wind * delta
		RenderingServer.global_shader_parameter_set(&"cloud_drift", _drift)
	var eye := get_viewport().get_camera_3d()
	if eye == null:
		return
	var here := over(Vector2(eye.global_position.x, eye.global_position.z))
	RenderingServer.global_shader_parameter_set(&"cloud_here", here)
	_cover(here)


## How much of a full cloud is over the ground at `at`: the same reading as
## cloud_over() in shaders/cloud_shadow.gdshaderinc.
func over(at: Vector2) -> float:
	# In dots of the picture, whose middles lie half a dot in, as a texture
	# is read on the GPU.
	var q := (at - _drift) / (800.0 * 64.0) * Vector2(_field.get_size()) - Vector2(0.5, 0.5)
	var x0 := floori(q.x)
	var y0 := floori(q.y)
	var u := q.x - x0
	var v := q.y - y0
	var w := _field.get_width()
	var h := _field.get_height()
	var a := _field.get_pixel(posmod(x0, w), posmod(y0, h)).r
	var b := _field.get_pixel(posmod(x0 + 1, w), posmod(y0, h)).r
	var c := _field.get_pixel(posmod(x0, w), posmod(y0 + 1, h)).r
	var d := _field.get_pixel(posmod(x0 + 1, w), posmod(y0 + 1, h)).r
	var n := 0.468 + (lerpf(lerpf(a, b, u), lerpf(c, d, u), v) - 0.497) * 0.94
	return smoothstep(0.5, 0.6, n)


## Lets the next cloud come, after the one that had passed at `now`.
func _next(now: float) -> void:
	_from = now + _dice.randf_range(between.x, between.y)
	_coming = _dice.randf_range(EDGE.x, EDGE.y)
	_going = _dice.randf_range(EDGE.x, EDGE.y)
	_until = _from + maxf(_dice.randf_range(passing.x, passing.y), _coming + _going)
	_thick = THIN if _dice.randf() < 0.34 else 1.0


## Puts `share` of a full cloud in front of the sun.
func _cover(share: float) -> void:
	_sun.light_energy = _energy * lerpf(1.0, sun_left, share)
	_sun.light_color = _colour.lerp(_colour * veiled, share)
	_world.ambient_light_energy = _sky * lerpf(1.0, sky_left, share)
