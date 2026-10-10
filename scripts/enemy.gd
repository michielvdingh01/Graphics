extends CharacterBody3D
## Enemy AI: paths to the player over the navmesh, strafes once it has a clear
## shot and attacks in telegraphed bursts. The grunt, rusher and heavy are this
## same script with different exported tuning and a different model; how the
## model moves is up to its rig. That is enemy_rig.gd for a robot, and
## humanoid_rig.gd when the theme of the enemies (see enemy_themes.gd) has a
## character for this role.

signal died(enemy: Node3D)

const ACCEL := 22.0
const TURN_SPEED := 8.0
const SIGHT_RANGE := 45.0
const ALERT_RADIUS := 14.0
const LOS_MASK := 0b011  # world + player
const RIG := preload("res://scripts/enemy_rig.gd")
const HUMANOID := preload("res://scripts/humanoid_rig.gd")
const THEMES := preload("res://scripts/enemy_themes.gd")
## Seconds a dead enemy stays around as a node; its pieces look after themselves.
const LINGER := 6.0
## What a role that fights hand to hand gets when its theme says no more than
## that it does: it has to come close, and it strikes once.
const MELEE := {"preferred_range": 1.4, "attack_range": 2.0, "burst_shots": 1}
## Which way an enemy walks in a pose for a screenshot, see preview().
const PREVIEW_MOVES := {2.0: Vector3.FORWARD, 5.0: Vector3.RIGHT * 0.5, 6.0: Vector3.LEFT * 0.5, 7.0: Vector3.BACK * 0.5}
## A character is slighter than a robot: its collider is this many times its
## height across at most, and never wider than the one in the scene.
const GIRTH := 0.19

enum Attack { COOLDOWN, TELEGRAPH, BURST }

## Which of the three it is: "grunt", "rusher" or "heavy". A theme casts a
## character for each.
@export var role := "grunt"
## What it looks like as a robot: a scene from tools/models/enemies.gd.
@export var model: PackedScene
## Tuning for one enemy type; the variants in scenes/ override these.
@export var max_health := 100.0
@export var speed := 4.2
## Strafes inside this distance, closes in outside it.
@export var preferred_range := 11.0
@export var attack_range := 26.0
## Strikes at arm's length instead of shooting.
@export var melee := false
@export var damage := 7.0
@export var burst_shots := 3
@export var shot_interval := 0.14
@export var spread_deg := 2.5
@export var telegraph_time := 0.45
## Shortest and longest pause between attacks.
@export var cooldown := Vector2(1.2, 2.2)
## Height above the feet of the eyes, and of where headshots start.
@export var eye_height := 1.5
@export var head_start := 1.36
@export var visor_color := Color(1.0, 0.15, 0.1)
## Length of the flame at its muzzle, in metres.
@export var flash_size := 0.26
## How tall a character stands next to the way it was made. A robot is built
## to size.
@export var size := 1.0

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
var _last_hit := Vector3.FORWARD
var _rig: Node3D

@onready var agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	var cast := THEMES.cast(Settings.enemy_theme, role)
	var tuned := _tune(cast.get("tuning", {}))
	health = max_health
	_player = get_tree().get_first_node_in_group("player")
	if not (cast and _embody(cast, tuned)):
		_rig = model.instantiate()
		_rig.name = "Model"
		_rig.set_script(RIG)
		add_child(_rig)
	_rig.set_glow(visor_color)
	_los_timer = randf() * 0.15


## Takes over what a theme says is different about this role: exported
## variables by name. Returns the names it set.
func _tune(tuning: Dictionary) -> Array:
	var tuned := []
	if tuning.is_empty():
		return tuned
	var exported := []
	for property: Dictionary in (get_script() as Script).get_script_property_list():
		if property.usage & PROPERTY_USAGE_EDITOR:
			exported.append(property.name)
	for key: String in tuning:
		if not exported.has(key):
			continue
		var value: Variant = tuning[key]
		var now: Variant = get(key)
		var fits := typeof(value) == typeof(now)
		match typeof(now):
			TYPE_INT, TYPE_FLOAT:
				fits = typeof(value) in [TYPE_INT, TYPE_FLOAT]
			TYPE_VECTOR2:
				# A span of two numbers, as JSON writes it.
				fits = value is Array and value.size() == 2
				if fits:
					value = Vector2(value[0], value[1])
			TYPE_COLOR:
				fits = value is String
			TYPE_BOOL:
				pass
			_:
				fits = false
		if fits:
			set(key, type_convert(value, typeof(now)))
			tuned.append(key)
	if melee and tuned.has("melee"):
		for key: String in MELEE:
			if not tuned.has(key):
				set(key, MELEE[key])
	return tuned


## Becomes the character a theme cast for it. False if that cannot be shown.
func _embody(cast: Dictionary, tuned: Array) -> bool:
	var rig := HUMANOID.new()
	rig.name = "Model"
	cast.merge({"melee": melee, "windup": telegraph_time, "size": size})
	if not rig.setup(cast):
		rig.free()
		return false
	add_child(rig)
	_rig = rig
	# It is shot at where it is seen: the collider takes its height, and the
	# eyes and the head are where the character has them.
	var fit: Dictionary = rig.fit
	var collider: CollisionShape3D = $CollisionShape3D
	var capsule: CapsuleShape3D = collider.shape.duplicate()
	capsule.radius = minf(capsule.radius, fit.height * GIRTH)
	capsule.height = maxf(fit.height, capsule.radius * 2.0)
	collider.shape = capsule
	collider.position.y = capsule.height * 0.5
	if not tuned.has("eye_height"):
		eye_height = fit.eyes
	if not tuned.has("head_start"):
		head_start = fit.head
	if not tuned.has("flash_size"):
		flash_size = rig.flash_size
	return true


## Strikes a pose for a screenshot of an enemy that is not running: 1 with
## its weapon on a target straight ahead, 2 in mid-stride as well, 3 shot to
## pieces or lying dead, 4 firing at that target. 5, 6 and 7 are mid-stride
## to its right, to its left and backwards, 8 is the moment before it
## attacks and 9 the moment it is hit.
func preview(pose: float) -> void:
	if pose == 3.0:
		_die()
		return
	if PREVIEW_MOVES.has(pose):
		velocity = global_basis * PREVIEW_MOVES[pose] * speed
	var eye := global_position + Vector3.UP * eye_height
	_rig.aim(eye - global_basis.z * 8.0)
	for i in 40:
		_rig._pose(0.03)
	if pose == 4.0:
		_shoot(eye, eye - global_basis.z * 8.0)
	elif pose == 8.0:
		_rig.charge(true)
		for i in 6:
			_rig._pose(0.03)
	elif pose == 9.0:
		_rig.hit(eye - Vector3.UP * 0.25 - global_basis.z * 0.2, global_basis.z, 20.0)
		_rig._pose(0.04)


func is_headshot(hit_position: Vector3) -> bool:
	return hit_position.y - global_position.y > head_start


func alert() -> void:
	if _alerted or dead:
		return
	_alerted = true
	_attack_timer = randf_range(0.4, 1.2)
	Sfx.play_at(_rig.sounds[&"alert"], global_position)
	for other in get_tree().get_nodes_in_group("enemy"):
		if other.global_position.distance_to(global_position) < ALERT_RADIUS:
			other.alert()


func take_damage(amount: float, hit_position: Vector3, direction: Vector3) -> bool:
	if dead:
		return false
	health -= amount
	alert()
	_last_hit = direction
	_rig.hit(hit_position, direction, amount)
	if health <= 0.0:
		_die()
	return dead


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var desired := Vector3.ZERO

	if not dead and is_instance_valid(_player) and not _player.dead:
		var eye := global_position + Vector3.UP * eye_height
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
			if not _has_los or distance > preferred_range:
				desired = _chase(delta)
				if not _has_los and desired.length_squared() > 0.01:
					face = desired
			else:
				desired = _strafe(delta)
			_turn_towards(face, delta)
			_update_attack(delta, eye, target, distance)
			# The weapon is on the player for as long as there is a shot.
			if _has_los and distance < attack_range * 1.5:
				_rig.aim(target)
			else:
				_rig.lower()

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
	return step.normalized() * speed


func _strafe(delta: float) -> Vector3:
	_strafe_timer -= delta
	if _strafe_timer <= 0.0 or is_on_wall():
		_strafe_timer = randf_range(0.8, 2.2)
		_strafe_dir = -_strafe_dir if is_on_wall() else [-1.0, 0.0, 1.0].pick_random()
	return global_basis.x * _strafe_dir * speed * 0.5


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
			if _attack_timer <= 0.0 and _has_los and distance < attack_range:
				_attack = Attack.TELEGRAPH
				_attack_timer = telegraph_time
				_rig.charge(true)
		Attack.TELEGRAPH:
			if not _has_los:
				_end_attack(0.5)
			elif _attack_timer <= 0.0:
				_attack = Attack.BURST
				_shots_left = burst_shots
		Attack.BURST:
			if _attack_timer <= 0.0:
				_shoot(eye, target)
				_shots_left -= 1
				_attack_timer = shot_interval
				if _shots_left <= 0:
					_end_attack(randf_range(cooldown.x, cooldown.y))


func _end_attack(pause: float) -> void:
	_attack = Attack.COOLDOWN
	_attack_timer = pause
	_rig.charge(false)


func _shoot(eye: Vector3, target: Vector3) -> void:
	_rig.fire()
	if melee:
		if eye.distance_to(target) < attack_range + 0.6:
			_player.take_damage(damage, target, (target - eye).normalized())
		Sfx.play_at(_rig.sounds[&"melee"], global_position)
		return
	# A fast-moving player is harder to hit, which rewards sprinting and sliding.
	var spread := tan(deg_to_rad(spread_deg + _player.velocity.length() * 0.45))
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
			_player.take_damage(damage, end, direction)
		else:
			Fx.impact(hit, direction)
			# A stray shot sets off a fuel barrel as well as the player's does.
			if hit.collider.has_method("take_damage"):
				hit.collider.take_damage(damage, end, direction)
	var muzzle: Vector3 = _rig.muzzle()
	Fx.tracer(muzzle, end, _rig.tracer_tint)
	Fx.muzzle_flash(null, Transform3D(Fx.facing(end - muzzle), muzzle), flash_size, _rig.flash_prongs, _rig.flash_tint)
	Sfx.play_at(_rig.sounds[&"shot"], global_position)


func _ray_hits_player(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, LOS_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == _player


func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 1
	remove_from_group("enemy")
	Sfx.play_at(_rig.sounds[&"death"], global_position)
	died.emit(self)
	_rig.collapse(_last_hit * 3.0)
	get_tree().create_timer(LINGER, false).timeout.connect(queue_free)
