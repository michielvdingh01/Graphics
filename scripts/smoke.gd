extends Node
## The clouds of smoke there are, and what they hide. A cloud is drawn by
## shaders/smoke_cloud.gdshader, which follows from its age alone; what goes
## for the eye goes here for those who look along a line. See blocks().
##
## Every machine lets its own copy of a smoke grenade make its own cloud, and
## they lie where they lie on that machine. Only the host asks what they hide:
## that is where enemies and bots do their looking.

## How far out a cloud comes at its fullest in metres, how high that is as a
## share of it, and how quickly it gets there per second. The shader is told.
const RADIUS := 4.0
const HIGH := 0.8
const GROWS := 1.1
## How large it starts, as a share of its fullest: SEED in the shader.
const SEED := 0.1
## Metres per second the whole cloud rises: RISE in the shader.
const RISE := 0.06
## Seconds it lasts, of which it spends the last THINS going.
const LASTS := 20.0
const THINS := 6.0
## How much of it has to be left for it to hide anything.
const HIDES := 0.6
## How many metres of it a line has to go through to be cut: its very edge is
## thin.
const THROUGH := 1.2

## A cloud: `at` the middle of its foot, `born` on the clock of the effects
## and `look` what draws it, which is how to know that it is still there.
var _clouds: Array[Dictionary] = []


## A cloud that starts to grow out of `at`.
func billow(at: Vector3) -> void:
	_forget()
	_clouds.append({"at": at, "born": Fx.time, "look": Fx.smoke_cloud(at, {
		&"life": LASTS, &"thins": THINS, &"radius": RADIUS, &"high": HIGH, &"grows": GROWS,
	})})


## How many clouds are up.
func count() -> int:
	_forget()
	return _clouds.size()


## True if smoke stands between `from` and `to`, or around either of them:
## whoever stands in a cloud is not seen, not from close by either, and sees
## nobody.
func blocks(from: Vector3, to: Vector3) -> bool:
	for cloud in _clouds:
		var age: float = Fx.time - float(cloud.born)
		if not is_instance_valid(cloud.look) or 1.0 - smoothstep(LASTS - THINS, LASTS, age) < HIDES:
			continue
		# Squashed so that the cloud is a ball, one across.
		var out := RADIUS * lerpf(SEED, 1.0, 1.0 - exp(-GROWS * age))
		var middle: Vector3 = cloud.at + Vector3.UP * RISE * age
		var squash := Vector3(1.0, 1.0 / HIGH, 1.0) / out
		var start := (from - middle) * squash
		var end := (to - middle) * squash
		if start.length_squared() < 1.0 or end.length_squared() < 1.0:
			return true
		var way := end - start
		var along := clampf(-start.dot(way) / maxf(way.length_squared(), 0.0001), 0.0, 1.0)
		var off := (start + way * along).length_squared()
		if off < 1.0 and sqrt(1.0 - off) * 2.0 * out >= THROUGH:
			return true
	return false


## Cleared up with the rest of the effects, or gone with the level or by age.
func _forget() -> void:
	_clouds = _clouds.filter(func(cloud: Dictionary) -> bool: return is_instance_valid(cloud.look))
