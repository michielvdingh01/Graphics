extends RefCounted
## A weight on a spring: pushed, it swings out and comes back to rest by
## itself. The view and the weapon in it use one for everything that gives and
## recovers: knees on landing, a head that is hit, a weapon that kicks.
##
## A step is the exact motion of the spring over that time and no estimate of
## it, so that a push looks the same at 45 frames a second as at 120, and a
## step of no time at all changes nothing.

## Where the weight is, away from rest, and how fast it moves, per second. In
## whatever unit it was pushed in; the three axes swing apart from each other.
var at := Vector3.ZERO
var speed := Vector3.ZERO

## How stiff it is, in radians per second, and how much of its swing it
## loses: 1 comes back without passing rest, less than that swings through.
var _rate := 1.0
var _damping := 1.0
## The speed a push has to give it, for each unit it should swing out.
var _push := 1.0


## `peak_time` is how many seconds after a push it is furthest out. With a
## `damping` of 1 it then creeps back to rest; with 0.6 it passes rest by a
## tenth of how far out it was before it settles.
func _init(peak_time: float, damping := 1.0) -> void:
	_damping = clampf(damping, 0.05, 1.0)
	if _damping < 1.0:
		var slip := sqrt(1.0 - _damping * _damping)
		_rate = acos(_damping) / (peak_time * slip)
		_push = _rate * exp(_damping * acos(_damping) / slip)
	else:
		_rate = 1.0 / peak_time
		_push = _rate * exp(1.0)


## Pushes it so that, from rest, it swings out as far as `peak`.
func push(peak: Vector3) -> void:
	speed += peak * _push


## Moves it on by `delta` seconds.
func step(delta: float) -> void:
	if _damping < 1.0:
		var slip := _rate * sqrt(1.0 - _damping * _damping)
		var fade := exp(-_damping * _rate * delta)
		var swing := cos(slip * delta)
		var turn := sin(slip * delta) / slip
		var pull := _damping * _rate
		var was := at
		at = (was * swing + (speed + was * pull) * turn) * fade
		speed = (speed * swing - (speed * pull + was * (_rate * _rate)) * turn) * fade
	else:
		var fade := exp(-_rate * delta)
		var drift := (speed + at * _rate) * delta
		at = (at + drift) * fade
		speed = (speed - drift * _rate) * fade


## Puts it at rest, there and then.
func settle() -> void:
	at = Vector3.ZERO
	speed = Vector3.ZERO
