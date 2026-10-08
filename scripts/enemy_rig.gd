extends Node3D
## Shows an enemy. It poses a model built by tools/models/enemies.gd, walks
## its legs to match how the body moves, raises and fires its weapon arm,
## flinches when it is hit and falls apart when it dies. What the enemy does
## is decided in enemy.gd; this script only makes it visible.

const GLOW := preload("res://materials/robot_glow.tres")
## Seconds the pieces of a destroyed robot lie about.
const DEBRIS_TIME := 7.0
const GLOW_IDLE := 3.0
const GLOW_CHARGED := 14.0

var _joints := {}
var _rest := {}
var _meshes: Array[MeshInstance3D] = []
var _glow_mat: StandardMaterial3D
## Length of one step, and whether it fights with blades instead of a gun.
var _stride := 0.8
var _melee := false
var _bulk := 1.0
var _phase := 0.0
var _moving := 0.0
## 0 with the weapon lowered, 1 with it on the target.
var _raised := 0.0
var _aiming := false
var _target := Vector3.ZERO
var _pitch := 0.0
var _toe_in := 0.0
var _recoil := 0.0
var _flinch := Vector3.ZERO
var _flash := 0.0
var _charging := false
var _charge := 0.0
var _spin := 0.0
var _spin_speed := 0.0
var _time := randf() * 10.0


func _ready() -> void:
	for node: Node3D in find_children("*", "Node3D"):
		_joints[node.name] = node
		_rest[node.name] = node.transform
		if node is MeshInstance3D:
			_meshes.append(node)
	_stride = get_meta("stride", 0.8)
	_melee = get_meta("melee", false)
	_bulk = get_meta("bulk", 1.0)
	_glow_mat = GLOW.duplicate()
	for mesh in _meshes:
		if mesh.name.begins_with("Glow"):
			mesh.material_override = _glow_mat
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pose(0.0)


## Colour of everything that glows on the robot.
func set_glow(color: Color) -> void:
	_glow_mat.emission = color
	_glow_mat.albedo_color = color * 0.08


## Brings the weapon to bear on a point; lower() lets it hang again.
func aim(target: Vector3) -> void:
	_aiming = true
	_target = target


func lower() -> void:
	_aiming = false


## The moment before an attack: everything that glows flares up.
func charge(on: bool) -> void:
	_charging = on


## A shot, or a strike of the blades.
func fire() -> void:
	_recoil = 1.0
	_spin_speed = 30.0


## Where its shots leave.
func muzzle() -> Vector3:
	return (_joints["Muzzle"] as Node3D).global_position


## A hit that came in along `direction`.
func hit(direction: Vector3) -> void:
	_flinch = (global_basis.inverse() * direction).limit_length(1.0)
	_flash = 1.0


## Falls apart: every part becomes a loose piece, knocked the way of `push`.
func collapse(push: Vector3) -> void:
	set_process(false)
	_glow_mat.emission_energy_multiplier = 0.0
	var scene := get_tree().current_scene
	var body := get_parent() as CharacterBody3D
	var carried := body.velocity if body else Vector3.ZERO
	var middle := global_position + Vector3.UP * 1.0
	var placed := {}
	for mesh in _meshes:
		placed[mesh] = mesh.global_transform
	for mesh in _meshes:
		mesh.set_instance_shader_parameter("flash", 0.0)
		var box := mesh.get_aabb()
		var shape := BoxShape3D.new()
		shape.size = box.size.max(Vector3.ONE * 0.05)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = box.get_center()
		var piece := RigidBody3D.new()
		# Pieces lie on the level and are in nobody's way.
		piece.collision_layer = 0
		piece.collision_mask = 1
		piece.mass = maxf(box.get_volume() * 400.0, 0.5)
		piece.add_child(collider)
		scene.add_child(piece)
		piece.global_transform = placed[mesh]
		mesh.get_parent().remove_child(mesh)
		piece.add_child(mesh)
		mesh.transform = Transform3D()
		var out: Vector3 = (placed[mesh] as Transform3D) * box.get_center() - middle
		piece.linear_velocity = carried + push * randf_range(0.5, 1.2) + out * randf_range(1.0, 2.5) + Vector3.UP * randf_range(0.5, 2.0)
		piece.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
		var tween := piece.create_tween()
		tween.tween_interval(DEBRIS_TIME - 1.0 + randf())
		tween.tween_property(mesh, "scale", Vector3.ONE * 0.01, 0.6)
		tween.tween_callback(piece.queue_free)
	Fx.sparks(middle, Vector3.UP, Color(4.0, 2.2, 0.8), 24)


func _process(delta: float) -> void:
	_pose(delta)


func _pose(delta: float) -> void:
	_time += delta
	var body := get_parent() as CharacterBody3D
	var local := global_basis.inverse() * body.velocity if body else Vector3.ZERO
	var speed := Vector2(local.x, local.z).length()
	var along := -local.z / maxf(speed, 0.01)
	var across := local.x / maxf(speed, 0.01)
	_moving = lerpf(_moving, clampf(speed / 1.5, 0.0, 1.0), 1.0 - exp(-10.0 * delta))
	# One step for every stride it covers; backwards the legs run in reverse.
	_phase += delta * speed / _stride * PI * (-1.0 if along < -0.3 else 1.0)
	var reach := lerpf(0.28, 0.62, clampf(speed / 6.0, 0.0, 1.0)) * _moving

	_raised = lerpf(_raised, 1.0 if _aiming else 0.0, 1.0 - exp(-9.0 * delta))
	if _aiming:
		var shoulder: Vector3 = global_transform * (_rest["Torso"] as Transform3D).origin + Vector3.UP * 0.35
		var to := _target - shoulder
		var flat := Vector2(to.x, to.z).length()
		_pitch = lerpf(_pitch, clampf(atan2(to.y, flat), -0.7, 0.7), 1.0 - exp(-12.0 * delta))
		_toe_in = atan2(0.3 * _bulk, maxf(flat, 1.0))
	_recoil = lerpf(_recoil, 0.0, 1.0 - exp(-(7.0 if _melee else 14.0) * delta))
	_flinch = _flinch.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * delta))
	_charge = lerpf(_charge, 1.0 if _charging else 0.0, 1.0 - exp(-14.0 * delta))
	_glow_mat.emission_energy_multiplier = lerpf(GLOW_IDLE, GLOW_CHARGED, _charge) * (0.9 + 0.1 * sin(_time * 40.0) * _charge)
	if _flash > 0.0 or delta == 0.0:
		_flash = maxf(_flash - delta * 7.0, 0.0)
		for mesh in _meshes:
			mesh.set_instance_shader_parameter("flash", _flash * 1.5)

	# Legs: each swings from the hip, bends at the knee as it comes through,
	# and keeps its foot level.
	for side: float in [1.0, -1.0]:
		var leg := "R" if side > 0.0 else "L"
		var at := _phase + (0.0 if side > 0.0 else PI)
		var swing := sin(at) * reach
		var lift := maxf(0.0, cos(at)) * _moving
		var hip := 0.14 + swing * absf(along) + lift * 0.3
		var knee := -(0.28 + lift * 0.85 + maxf(0.0, -swing) * 0.35)
		_turn("Thigh" + leg, Vector3(hip, 0.0, -swing * across * 0.7 + side * 0.03))
		_turn("Shin" + leg, Vector3(knee, 0.0, 0.0))
		_turn("Foot" + leg, Vector3(-(hip + knee) * 0.85, 0.0, 0.0))

	# The body sinks a little on bent knees, bobs with every step, leans into
	# its run and twists against its legs.
	var sway := sin(_time * 1.3) * 0.012
	var hunch := -0.32 if _melee else 0.0
	var bob := -0.028 * _stride - 0.035 * _stride * (1.0 - absf(cos(_phase))) * _moving
	_turn("Hips", Vector3(-0.1 * along * _moving + hunch * 0.4, sin(_phase) * 0.07 * _moving, -0.07 * across * _moving), Vector3(0.0, bob, 0.0))
	_turn("Torso", Vector3(_pitch * 0.25 * _raised + hunch * 0.6 + sway + _flinch.z * -0.3, -sin(_phase) * 0.1 * _moving, _flinch.x * -0.3))
	_turn("Head", Vector3(_pitch * 0.5 * _raised - hunch * 0.9, -_flinch.x * 0.3, 0.0))

	var stride_r := -sin(_phase) * 0.3 * _moving
	if _melee:
		# Blades up and forward; a strike drives them out.
		for side: float in [1.0, -1.0]:
			var arm := "R" if side > 0.0 else "L"
			var strike := _recoil * (1.0 if side > 0.0 else 0.6)
			_turn("Arm" + arm, Vector3(lerpf(0.35, 0.75, _raised) + strike * 0.9 + side * stride_r, side * 0.25, side * 0.12))
			_turn("Forearm" + arm, Vector3(lerpf(0.9, 1.25, _raised) - strike * 0.8, 0.0, 0.0))
		return
	# The weapon arm comes up level with the target and kicks with every shot.
	_turn("ArmR", Vector3(lerpf(0.22 + stride_r, 1.02 + _pitch * 0.75 + _recoil * 0.05, _raised), _toe_in * _raised, 0.05))
	_turn("ForearmR", Vector3(lerpf(0.42, 0.55 + _recoil * 0.16, _raised), 0.0, 0.0))
	# The other arm swings along, or comes across in front when the weapon is up.
	_turn("ArmL", Vector3(lerpf(0.15 - stride_r, 0.75 + _pitch * 0.4, _raised), lerpf(0.0, -0.55, _raised), -0.05))
	_turn("ForearmL", Vector3(lerpf(0.35, 1.05, _raised), 0.0, 0.0))
	if _joints.has("Barrels"):
		_spin_speed = lerpf(_spin_speed, 18.0 if _charging else 0.0, 1.0 - exp(-3.0 * delta))
		_spin += _spin_speed * delta
		_turn("Barrels", Vector3(0.0, _spin, 0.0))


## Turns a joint by `angles` from how it was built, and shifts it by `shift`.
func _turn(joint: String, angles: Vector3, shift := Vector3.ZERO) -> void:
	var node: Node3D = _joints[joint]
	node.position = (_rest[joint] as Transform3D).origin + shift
	node.rotation = angles
