extends Node3D
## A shell from the gun of a tank on its way (see fire() in
## scripts/vehicle.gd): fast, falling a little over a long way, glowing at its
## tail so that it can be followed. What it hits square is hurt by the hit,
## and everything round it by the blast of scripts/blast.gd it goes off in,
## bigger than a rocket's. It hurts the one who fired it like anybody else.

## Seconds before it goes off wherever it is.
const LIFE := 4.0
## Of the world's gravity, what pulls it down: a shell drops over hundreds of
## metres, not tens.
const DROP := 0.35
const HIT_MASK := 0b100101  # world + enemy + breakable

## Metres a second, the way it flies.
var velocity := Vector3.ZERO
## What a hit square does, the reach and damage of its blast, and how big
## that looks.
var direct := 250.0
var radius := 6.5
var damage := 150.0
var size := 1.7
## Who fired it, as scripts/match.gd numbers those who play, and their body;
## and the vehicle it left, which it does not hit on its way out.
var thrower := 0
var shooter: CollisionObject3D
var skip := RID()

var _age := 0.0
static var _ball: SphereMesh


func _ready() -> void:
	add_child(glow())
	if velocity != Vector3.ZERO:
		look_at(global_position + velocity)


## What it is drawn with: a glow drawn out along the way it flies, of one
## mesh and one material for every shell. Also for Fx.rehearse(), see
## looks() in scripts/vehicle.gd.
static func glow() -> MeshInstance3D:
	if _ball == null:
		_ball = SphereMesh.new()
		_ball.radius = 0.06
		_ball.height = 0.12
		_ball.radial_segments = 8
		_ball.rings = 4
		var hot := StandardMaterial3D.new()
		hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hot.albedo_color = Color(1.0, 0.8, 0.5)
		hot.emission_enabled = true
		hot.emission = Color(1.0, 0.55, 0.2)
		hot.emission_energy_multiplier = 6.0
		_ball.material = hot
	var shine := MeshInstance3D.new()
	shine.mesh = _ball
	shine.scale = Vector3(1.0, 1.0, 6.0)
	shine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return shine


func _physics_process(delta: float) -> void:
	_age += delta
	velocity += Vector3.DOWN * 9.8 * DROP * delta
	var from := global_position
	var to := from + velocity * delta
	var mask := HIT_MASK | (Match.foes_of(shooter) if Match.active and shooter else 0)
	var exclude: Array[RID] = []
	if skip.is_valid():
		exclude.append(skip)
	if shooter:
		exclude.append(shooter.get_rid())
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, mask, exclude))
	if hit:
		_go_off(hit.position - velocity.normalized() * 0.2, hit.collider)
		return
	if _age >= LIFE:
		_go_off(from, null)
		return
	global_position = to
	look_at(to + velocity)


func _go_off(at: Vector3, struck: Object) -> void:
	var direction := velocity.normalized()
	if struck and struck.has_method("take_damage"):
		if Match.active and shooter:
			Match.hit(shooter, struck, direct, at, direction, Match.BLAST)
		else:
			if struck.has_method("struck_by"):
				struck.struck_by(thrower)
			Net.damage(struck, direct, at, direction)
	Blast.explode(at, radius, damage, size, null, thrower)
	queue_free()
