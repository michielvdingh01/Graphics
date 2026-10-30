extends RigidBody3D
## A smoke grenade on its way: it bounces and rolls like a grenade, starts to
## hiss when its fuse has burnt down, and lets go of its cloud once it lies
## still. scripts/weapons.gd throws it, scripts/smoke.gd keeps the cloud.

## Seconds from the throw to the hiss, and the longest it waits after that for
## the tin to come to rest, in m/s, before the cloud starts wherever it is.
const FUSE := 1.0
const SETTLES := 1.5
const AT_REST := 0.8
## How often a thread of smoke leaves the tin while it hisses, in seconds, and
## for how long it does that once the cloud has it hidden.
const THREAD_EVERY := 0.09
const THREADS_ON := 3.0
const HISS_DB := -6.0

## True for the copy another machine shows of a grenade its player threw. That
## one makes a cloud all the same: what a cloud hides is the host's to say,
## and each machine has to show it. See scripts/smoke.gd.
var echo := false
## Who threw it, as scripts/match.gd numbers those who play; 0 for nobody.
var thrower := 0

var _age := 0.0
var _hissing := false
var _cloud_at := -1.0
var _thread_in := 0.0


func _ready() -> void:
	body_entered.connect(_on_bounce)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age < FUSE:
		return
	if not _hissing:
		_hissing = true
		Sfx.play_on(&"smoke_hiss", self, Vector3.ZERO, HISS_DB)
	if _cloud_at < 0.0 and (linear_velocity.length() < AT_REST or _age > FUSE + SETTLES):
		_cloud_at = _age
		Smoke.billow(Vector3(global_position.x, global_position.y - 0.03, global_position.z))
	if _cloud_at < 0.0 or _age < _cloud_at + THREADS_ON:
		_thread_in -= delta
		if _thread_in <= 0.0:
			_thread_in = THREAD_EVERY
			Fx.gun_smoke(global_position + Vector3.UP * 0.07, Vector3.UP + linear_velocity * -0.1, 1.0)
	if _cloud_at >= 0.0 and _age > _cloud_at + Smoke.LASTS:
		queue_free()


func _on_bounce(_other: Node) -> void:
	# The harder it comes down, the louder; once it only rolls it is quiet.
	var speed := linear_velocity.length()
	if speed > 1.0:
		Sfx.play_at(&"bounce", global_position, clampf(remap(speed, 1.0, 10.0, -16.0, -2.0), -16.0, -2.0))
