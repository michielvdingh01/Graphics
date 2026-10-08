extends CharacterBody3D
## Simple ranged enemy: paths to the player over the navmesh, strafes once it
## has a clear shot and fires telegraphed bursts.

signal died(enemy: Node3D)

const SPEED := 4.2
const ACCEL := 22.0
const TURN_SPEED := 8.0
const EYE_HEIGHT := 1.5
const HEAD_START := 1.36
const SIGHT_RANGE := 45.0
const ATTACK_RANGE := 26.0
const PREFERRED_RANGE := 11.0
const ALERT_RADIUS := 14.0

const TELEGRAPH_TIME := 0.45
const BURST_SHOTS := 3
const SHOT_INTERVAL := 0.14
const DAMAGE := 7.0
const SPREAD_DEG := 2.5
const LOS_MASK := 0b011  # world + player

enum Attack { COOLDOWN, TELEGRAPH, BURST }

@export var max_health := 100.0

var health := 0.0
var dead := false

var _player: CharacterBody3D
var _alerted := false
var _has_los := false
var _los_timer := 0.0
var _repath_timer := 0.0
var _strafe_dir := 1.0
var _strafe_timer := 0.0
var _attack := Attack.COOLDOWN
var _attack_timer := 1.0
var _shots_left := 0
var _body_mat: StandardMaterial3D
var _visor_mat: StandardMaterial3D

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var visor: MeshInstance3D = $Visor
@onready var gun: Node3D = $Gun


func _ready() -> void:
	health = max_health
	_player = get_tree().get_first_node_in_group("player")
	_body_mat = $Body.mesh.surface_get_material(0).duplicate()
	$Body.material_override = _body_mat
	$Head.material_override = _body_mat
	_visor_mat = visor.mesh.surface_get_material(0).duplicate()
	visor.material_override = _visor_mat
	_los_timer = randf() * 0.15


func is_headshot(hit_position: Vector3) -> bool:
	return hit_position.y - global_position.y > HEAD_START


func alert() -> void:
	if _alerted or dead:
		return
	_alerted = true
	_attack_timer = randf_range(0.4, 1.2)
	Sfx.play_at(&"enemy_alert", global_position)
	for other in get_tree().get_nodes_in_group("enemy"):
		if other.global_position.distance_to(global_position) < ALERT_RADIUS:
			other.alert()


func take_damage(amount: float, hit_position: Vector3, direction: Vector3) -> bool:
	if dead:
		return false
	health -= amount
	alert()
	Fx.sparks(hit_position, -direction, Color(4.0, 1.5, 0.4), 6)
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(1.0, 0.5, 0.3)
	_body_mat.emission_energy_multiplier = 2.0
	create_tween().tween_property(_body_mat, "emission_energy_multiplier", 0.0, 0.15)
	if health <= 0.0:
		_die()
	return dead


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var desired := Vector3.ZERO

	if not dead and is_instance_valid(_player) and not _player.dead:
		var eye := global_position + Vector3.UP * EYE_HEIGHT
		var target: Vector3 = _player.head.global_position - Vector3.UP * 0.25
		var distance := eye.distance_to(target)

		_los_timer -= delta
		if _los_timer <= 0.0:
			_los_timer = 0.15
			_has_los = distance < SIGHT_RANGE and _ray_hits_player(eye, target)
		if _has_los:
			alert()

		if _alerted:
			var face := target - eye
			if not _has_los or distance > PREFERRED_RANGE:
				desired = _chase(delta)
				if not _has_los and desired.length_squared() > 0.01:
					face = desired
			else:
				desired = _strafe(delta)
			_turn_towards(face, delta)
			_update_attack(delta, eye, target, distance)

	velocity.x = move_toward(velocity.x, desired.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, desired.z, ACCEL * delta)
	move_and_slide()


func _chase(delta: float) -> Vector3:
	# The navmesh is baked a moment after the level loads.
	if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) == 0:
		return Vector3.ZERO
	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = 0.3
		agent.target_position = _player.global_position
	if agent.is_navigation_finished():
		return Vector3.ZERO
	var step := agent.get_next_path_position() - global_position
	step.y = 0.0
	return step.normalized() * SPEED


func _strafe(delta: float) -> Vector3:
	_strafe_timer -= delta
	if _strafe_timer <= 0.0 or is_on_wall():
		_strafe_timer = randf_range(0.8, 2.2)
		_strafe_dir = -_strafe_dir if is_on_wall() else [-1.0, 0.0, 1.0].pick_random()
	return global_basis.x * _strafe_dir * SPEED * 0.5


func _turn_towards(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	var yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-TURN_SPEED * delta))


func _update_attack(delta: float, eye: Vector3, target: Vector3, distance: float) -> void:
	_attack_timer -= delta
	match _attack:
		Attack.COOLDOWN:
			if _attack_timer <= 0.0 and _has_los and distance < ATTACK_RANGE:
				_attack = Attack.TELEGRAPH
				_attack_timer = TELEGRAPH_TIME
				_visor_mat.emission_energy_multiplier = 12.0
		Attack.TELEGRAPH:
			if not _has_los:
				_end_attack(0.5)
			elif _attack_timer <= 0.0:
				_attack = Attack.BURST
				_shots_left = BURST_SHOTS
		Attack.BURST:
			if _attack_timer <= 0.0:
				_shoot(eye, target)
				_shots_left -= 1
				_attack_timer = SHOT_INTERVAL
				if _shots_left <= 0:
					_end_attack(randf_range(1.2, 2.2))


func _end_attack(cooldown: float) -> void:
	_attack = Attack.COOLDOWN
	_attack_timer = cooldown
	_visor_mat.emission_energy_multiplier = 3.0


func _shoot(eye: Vector3, target: Vector3) -> void:
	# A fast-moving player is harder to hit, which rewards sprinting and sliding.
	var spread := tan(deg_to_rad(SPREAD_DEG + _player.velocity.length() * 0.45))
	var aim := Basis.looking_at(target - eye)
	var angle := randf() * TAU
	var radius := sqrt(randf()) * spread
	var direction := (aim * Vector3(cos(angle) * radius, sin(angle) * radius, -1.0)).normalized()
	var end := eye + direction * 100.0
	var query := PhysicsRayQueryParameters3D.create(eye, end, LOS_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		end = hit.position
		if hit.collider == _player:
			_player.take_damage(DAMAGE, end, direction)
		else:
			Fx.impact(end, hit.normal)
	Fx.tracer(gun.global_position - global_basis.z * 0.3, end, Color(4.0, 0.6, 0.4))
	Sfx.play_at(&"enemy_shot", global_position)


func _ray_hits_player(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, LOS_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == _player


func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 1
	remove_from_group("enemy")
	_visor_mat.emission_energy_multiplier = 0.0
	Sfx.play_at(&"enemy_death", global_position)
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(self, "rotation:x", PI * 0.5, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(4.0)
	tween.tween_property(self, "position:y", position.y - 1.0, 1.0)
	tween.tween_callback(queue_free)
