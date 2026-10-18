extends Node
## The eye of whoever looks, under an open sky: it is used to the light it
## has been in. Whoever steps out of a wood into the sun is blinded for a
## moment, and whoever walks in out of the sun sees little under the trees
## until his eyes have come round.
##
## It does not measure the picture. A level on land knows where its shade
## lies (scripts/land.gd), and the light at the eye is read off that: how
## much of the ground around whoever looks lies in the sun, and how much of
## the ground he looks out over. The eye follows that light slowly, and the
## picture is over- or underexposed by as much as the eye is behind.
##
## An eye that has caught up changes nothing: whoever stands still sees the
## level exactly as it is without this node, and so does a benchmark, which
## is set down at a spot and not walked there. It can only be judged in
## motion. Stands in the scene of a level; without its script line there the
## level is as it was.

## The most the picture is overexposed for an eye that comes out of the
## shade into the sun, and underexposed the other way round, in stops. It
## gets there only out of full shade into full sun, or back: see STEEP.
@export var glare := 1.0
@export var gloom := 0.6
## How long the eye takes over most of the way, in seconds: quickly to the
## light and slowly to the dark, as an eye does.
@export var glare_time := 1.8
@export var gloom_time := 3.0

const LAND := preload("res://scripts/land.gd")
## The ground that counts as where whoever looks stands: rings of spots
## around him, this far out, in metres. A single crown overhead is not a
## wood; the light is that of the ground a few paces around.
const AROUND: Array[float] = [3.0, 6.5]
## The ground he looks out over lies this far ahead of him, in a patch this
## far across.
const AHEAD: Array[float] = [9.0, 17.0, 26.0]
const PATCH := 4.0
## What he looks at counts for this share of the light at his eye.
const LOOKED_AT := 0.45
## The light at the eye does not jump when a foot crosses the edge of a
## shadow: it gets there in about this long, in seconds.
const SETTLE := 0.3
## An eye this little behind sees no difference: the light under trees is
## never quite the same from one step to the next.
const UNNOTICED := 0.06
## How fast the picture goes off as the eye falls behind, in stops for all
## of the way from shade to sun, before it levels off at `glare` or `gloom`.
const STEEP := 3.0
## Further than this in one frame is not walked: the eye was set down there
## and is used to it at once.
const JUMP := 4.0
## Closer than this to what it follows, the eye has caught up.
const CAUGHT_UP := 0.004

var _land: Node
var _world: Environment
var _exposure := 1.0
var _glow := 1.0
## The light at the eye, 0 in the shade and 1 in the sun, and the light the
## eye is used to.
var _light := 1.0
var _used_to := 1.0
var _was := Vector3.INF
## Where around a spot the ground is looked at, see _lit().
var _ring: PackedVector2Array = [Vector2.ZERO]


func _ready() -> void:
	_land = LAND.of(get_tree())
	_world = get_viewport().find_world_3d().environment
	if _land == null or _world == null:
		set_process(false)
		return
	# The environment belongs to the scene of the level and outlives one
	# loading of it: what it was made with is kept beside it.
	if not _world.has_meta(&"eyes"):
		_world.set_meta(&"eyes", Vector2(_world.tonemap_exposure, _world.glow_intensity))
	var made: Vector2 = _world.get_meta(&"eyes")
	_exposure = made.x
	_glow = made.y
	for i in 6:
		_ring.append(Vector2.from_angle(TAU * i / 6.0))


func _exit_tree() -> void:
	if _world:
		_world.tonemap_exposure = _exposure
		_world.glow_intensity = _glow


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var eye := camera.global_position
	var falls := _falls_on(camera)
	if eye.distance_to(_was) > JUMP:
		_light = falls
		_used_to = falls
	_was = eye
	_light = _towards(_light, falls, delta / SETTLE)
	_used_to = _towards(_used_to, _light, delta / (glare_time if _light > _used_to else gloom_time))
	var behind := _light - _used_to
	var far := maxf(absf(behind) - UNNOTICED, 0.0) / (1.0 - UNNOTICED)
	var most := glare if behind > 0.0 else -gloom
	var stops := most * (1.0 - exp(-far * STEEP / maxf(absf(most), 0.01)))
	_world.tonemap_exposure = _exposure * pow(2.0, stops)
	# Light the eye is not ready for blooms.
	_world.glow_intensity = _glow * pow(2.0, maxf(stops, 0.0))


## `from` on its way to `to`, `share` of a time constant later.
func _towards(from: float, to: float, share: float) -> float:
	var next := lerpf(to, from, exp(-share))
	return to if absf(next - to) < CAUGHT_UP else next


## The light that falls on the eye behind `camera`, 0 to 1: the sun on the
## ground where it is, and on the ground it looks out over.
func _falls_on(camera: Camera3D) -> float:
	var eye := camera.global_position
	var here := _lit(eye, AROUND[0]) * 0.5 + _lit(eye, AROUND[1]) * 0.5
	var ahead := -camera.global_basis.z
	var flat := Vector3(ahead.x, 0.0, ahead.z)
	if flat.length_squared() < 0.01:
		return here
	flat = flat.normalized()
	var out := 0.0
	for far in AHEAD:
		out += _lit(eye + flat * far, PATCH)
	return lerpf(here, out / AHEAD.size(), LOOKED_AT)


## How much of the ground within `reach` of `at` lies in the sun, 0 to 1. By
## night, how well it is lit by the moon and the lamps (scripts/land.gd),
## leaving out what stands between a lamp and the ground: the eye takes in
## the light of a place, not of each spot in it.
func _lit(at: Vector3, reach: float) -> float:
	var sum := 0.0
	var night: bool = _land.by_night()
	for spot in _ring:
		var on := at + Vector3(spot.x, 0.0, spot.y) * reach
		sum += _land.light_at(on, false) if night else (0.0 if _land.shaded(on) else 1.0)
	return sum / _ring.size()
