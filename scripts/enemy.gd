class_name Enemy
extends CharacterBody3D
## Placeholder soldier: notices the player, navigates to a firing position, telegraphs, then
## fires a short hitscan burst. The visual is built procedurally and lives on visual layer 2 so
## bullet-hole decals never project onto it.

signal died(enemy: Enemy)

enum State { IDLE, CHASE, WINDUP, BURST, COOLDOWN, DEAD }

const MAX_HEALTH := 100.0
const MOVE_SPEED := 3.6
const ACCEL := 14.0
const SIGHT_RANGE := 38.0
const FIRE_RANGE := 24.0
const PREFERRED_RANGE := 11.0
const WINDUP_TIME := 0.6
const BURST_SHOTS := 2
const BURST_GAP := 0.2
const SHOT_DAMAGE := 9.0
const EYE_HEIGHT := 1.55
const VISUAL_LAYER := 2
## World (1) + player (2).
const SIGHT_MASK := 1 | 2

## Hits above this height (relative to the enemy origin) count as headshots.
var head_height := 1.42
var health := MAX_HEALTH
var frozen := false
var state := State.IDLE

var _player: Node3D
var _alerted := false
var _state_t := 0.0
var _burst_left := 0
var _repath_t := 0.0
var _strafe_dir := 1.0
var _strafe_t := 0.0
var _stagger := 0.0
var _walk_phase := 0.0
var _hurt_cooldown := 0.0
var _rng := RandomNumberGenerator.new()
var _visual: Node3D
var _body_mat: StandardMaterial3D
var _visor_mat: StandardMaterial3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D

@onready var _nav: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	_rng.randomize()
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_build_visual()
	_nav.path_desired_distance = 0.6
	_nav.target_desired_distance = 1.0
	_strafe_dir = 1.0 if _rng.randf() < 0.5 else -1.0


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_hurt_cooldown = maxf(_hurt_cooldown - delta, 0.0)
	_state_t += delta
	if not is_on_floor():
		velocity += get_gravity() * delta

	if frozen or not is_instance_valid(_player):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	var sees := _has_line_of_sight(dist)
	if not _alerted and sees and dist < SIGHT_RANGE:
		_alert()

	var move_dir := Vector3.ZERO
	var speed := MOVE_SPEED
	if _stagger > 0.0:
		_stagger -= delta
		speed = 0.0
	else:
		match state:
			State.IDLE:
				speed = 0.0
			State.CHASE:
				move_dir = _chase_direction(delta, dist, sees)
				if sees and dist < FIRE_RANGE and _state_t > 0.8:
					_enter(State.WINDUP)
					Sfx.play_at("enemy_windup", global_position + Vector3.UP * 1.5, -4.0)
			State.WINDUP:
				speed = 0.0
				_face(to_player, delta, 9.0)
				_visor_mat.emission_energy_multiplier = lerpf(1.5, 9.0, _state_t / WINDUP_TIME)
				if _state_t >= WINDUP_TIME:
					_burst_left = BURST_SHOTS
					_enter(State.BURST)
					_fire(sees)
			State.BURST:
				speed = 0.0
				_face(to_player, delta, 9.0)
				if _state_t >= BURST_GAP:
					if _burst_left > 0:
						_state_t = 0.0
						_fire(sees)
					else:
						_enter(State.COOLDOWN)
						_visor_mat.emission_energy_multiplier = 1.5
			State.COOLDOWN:
				# Keep moving a little between bursts so enemies are not sitting ducks.
				move_dir = _strafe_direction(delta, to_player) * 0.7
				speed = MOVE_SPEED * 0.6
				_face(to_player, delta, 6.0)
				if _state_t >= _rng.randf_range(1.0, 1.8):
					_enter(State.CHASE)

	var target := move_dir * speed
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)
	move_and_slide()

	if move_dir.length() > 0.1 and state == State.CHASE:
		_face(move_dir, delta, 8.0)
	_animate_walk(delta)


func take_damage(amount: float, point: Vector3, direction: Vector3, headshot: bool) -> bool:
	if state == State.DEAD:
		return false
	health -= amount
	_alert()
	if health <= 0.0:
		_die(direction)
		return true
	_stagger = 0.12
	velocity += Vector3(direction.x, 0.0, direction.z).normalized() * 1.5
	_flash_hit()
	if _hurt_cooldown <= 0.0:
		_hurt_cooldown = 0.25
		Sfx.play_at("enemy_hurt", point, -2.0, 1.15 if headshot else 1.0)
	return false


func _alert() -> void:
	if _alerted:
		return
	_alerted = true
	if state == State.IDLE:
		_enter(State.CHASE)


func _enter(next: State) -> void:
	state = next
	_state_t = 0.0


func _has_line_of_sight(dist: float) -> bool:
	if dist > SIGHT_RANGE:
		return false
	var from := global_position + Vector3.UP * EYE_HEIGHT
	var to := _player.global_position + Vector3.UP * 1.3
	var query := PhysicsRayQueryParameters3D.create(from, to, SIGHT_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == _player


func _chase_direction(delta: float, dist: float, sees: bool) -> Vector3:
	if sees and dist < PREFERRED_RANGE:
		return _strafe_direction(delta, _player.global_position - global_position) * 0.6
	_repath_t -= delta
	if _repath_t <= 0.0:
		_repath_t = 0.25 + _rng.randf() * 0.1
		_nav.target_position = _player.global_position
	if _nav.is_navigation_finished():
		return Vector3.ZERO
	var next := _nav.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	return dir.normalized()


func _strafe_direction(delta: float, to_player: Vector3) -> Vector3:
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = _rng.randf_range(0.8, 2.0)
		_strafe_dir = -_strafe_dir
	var flat := Vector3(to_player.x, 0.0, to_player.z).normalized()
	return flat.cross(Vector3.UP) * _strafe_dir


func _face(direction: Vector3, delta: float, rate: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.01:
		return
	var target_yaw := atan2(-flat.x, -flat.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-rate * delta))


func _fire(sees: bool) -> void:
	_burst_left -= 1
	var from := global_position + Vector3.UP * EYE_HEIGHT - global_basis.z * 0.5
	var chest := _player.global_position + Vector3.UP * 1.1
	var distance := from.distance_to(chest)
	# Aim error grows with distance, so close range hurts and long range is escapable.
	var error := Vector3(
		_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.6, 0.6), _rng.randf_range(-1.0, 1.0)
	) * (0.15 + distance * 0.035)
	var dir := (chest + error - from).normalized()
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 60.0, SIGHT_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = hit.position if not hit.is_empty() else from + dir * 60.0
	Effects.tracer(from, end, Color(1.0, 0.25, 0.15))
	Sfx.play_at("enemy_shot", from, -3.0)
	if hit.is_empty():
		return
	if hit.collider == _player and sees:
		_player.take_damage(SHOT_DAMAGE, global_position)
	elif not hit.collider.has_method("take_damage"):
		Effects.world_impact(hit.position, hit.normal)


func _die(_direction: Vector3) -> void:
	state = State.DEAD
	collision_layer = 0
	collision_mask = 0
	_visor_mat.emission_energy_multiplier = 0.0
	Sfx.play_at("enemy_die", global_position + Vector3.UP, 0.0)
	died.emit(self)
	# Topple backwards, then sink out of the world.
	var fall := create_tween()
	fall.tween_property(_visual, "rotation:x", deg_to_rad(88.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_interval(3.0)
	fall.tween_property(_visual, "position:y", -1.2, 1.2)
	fall.tween_callback(queue_free)


func _flash_hit() -> void:
	_body_mat.emission_energy_multiplier = 2.5
	var t := create_tween()
	t.tween_property(_body_mat, "emission_energy_multiplier", 0.0, 0.12)


func _animate_walk(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	_walk_phase += speed * delta * 2.2
	var swing := sin(_walk_phase) * 0.7 * clampf(speed / MOVE_SPEED, 0.0, 1.0)
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	_arm_l.rotation.x = -swing * 0.8
	_visual.position.y = absf(sin(_walk_phase)) * 0.03 * clampf(speed / MOVE_SPEED, 0.0, 1.0)


# --- placeholder visual --------------------------------------------------------------------

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.2, 0.24, 0.26)
	_body_mat.metallic = 0.35
	_body_mat.roughness = 0.55
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(1.0, 0.9, 0.8)
	_body_mat.emission_energy_multiplier = 0.0

	var armor := StandardMaterial3D.new()
	armor.albedo_color = Color(0.08, 0.09, 0.1)
	armor.metallic = 0.7
	armor.roughness = 0.38

	_visor_mat = StandardMaterial3D.new()
	_visor_mat.albedo_color = Color(0.05, 0.0, 0.0)
	_visor_mat.emission_enabled = true
	_visor_mat.emission = Color(1.0, 0.12, 0.08)
	_visor_mat.emission_energy_multiplier = 1.5

	_part(Vector3(0.5, 0.58, 0.28), Vector3(0, 1.12, 0), _body_mat)
	_part(Vector3(0.54, 0.3, 0.32), Vector3(0, 1.22, 0.0), armor)
	_part(Vector3(0.42, 0.22, 0.26), Vector3(0, 0.78, 0), armor)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.13
	head_mesh.height = 0.26
	head_mesh.radial_segments = 20
	head_mesh.rings = 10
	head_mesh.material = armor
	head.mesh = head_mesh
	head.position = Vector3(0, 1.55, 0)
	_register(head)
	_part(Vector3(0.2, 0.045, 0.05), Vector3(0, 1.56, -0.115), _visor_mat)

	_leg_l = _limb(Vector3(0.17, 0.78, 0.2), Vector3(-0.12, 0.78, 0), _body_mat)
	_leg_r = _limb(Vector3(0.17, 0.78, 0.2), Vector3(0.12, 0.78, 0), _body_mat)
	_arm_l = _limb(Vector3(0.13, 0.56, 0.15), Vector3(-0.34, 1.38, 0), _body_mat)
	var arm_r := _limb(Vector3(0.13, 0.56, 0.15), Vector3(0.34, 1.38, 0), _body_mat)
	arm_r.rotation.x = deg_to_rad(-80.0)
	_part(Vector3(0.06, 0.09, 0.5), Vector3(0.32, 1.2, -0.38), armor)


func _part(size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	_register(instance)
	return instance


## A box that hangs below a pivot at its top, so rotating the pivot swings it like a joint.
func _limb(size: Vector3, pivot_position: Vector3, material: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_position
	_visual.add_child(pivot)
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = Vector3(0, -size.y * 0.5, 0)
	instance.layers = VISUAL_LAYER
	pivot.add_child(instance)
	return pivot


func _register(instance: MeshInstance3D) -> void:
	instance.layers = VISUAL_LAYER
	_visual.add_child(instance)
