extends CharacterBody3D

signal health_changed(health: float, max_health: float)
## `direction` is the world-space direction from the player towards the attacker.
signal damaged(direction: Vector3)
signal died
signal respawned

const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.0
const CROUCH_SPEED := 2.6
const ADS_SPEED_FACTOR := 0.7
const SLIDE_SPEED := 12.5
const SLIDE_TIME := 0.85
const SLIDE_COOLDOWN := 0.5
const JUMP_VELOCITY := 4.8
const GROUND_ACCEL := 60.0
const AIR_ACCEL := 12.0
const MOUSE_SENSITIVITY := 0.002
const MAX_PITCH := deg_to_rad(89.0)

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.2
const STAND_EYE := 1.6
const CROUCH_EYE := 1.05
const BASE_FOV := 80.0
const SPRINT_FOV := 5.0

const MAX_HEALTH := 100.0
const REGEN_DELAY := 5.0
const REGEN_RATE := 14.0
const RESPAWN_DELAY := 2.5

var health := MAX_HEALTH
var dead := false
var crouched := false
var sliding := false
var speed_h := 0.0
## 0..1, eased. The weapon uses it to drop into the sprint pose and to block firing.
var sprint_t := 0.0
## Camera bob offset (x, y) in metres.
var bob := Vector2.ZERO

var _height := STAND_HEIGHT
var _slide_t := 0.0
var _slide_cd := 0.0
var _slide_dir := Vector3.ZERO
var _bob_phase := 0.0
var _roll := 0.0
var _land_dip := 0.0
var _was_airborne := false
var _fall_speed := 0.0
var _regen_t := 0.0
var _death_t := 0.0
var _spawn_transform: Transform3D

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapons: WeaponManager = $Head/Camera3D/WeaponManager
@onready var collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_spawn_transform = global_transform
	# The capsule is edited at runtime when crouching, so it must not be shared.
	collision.shape = collision.shape.duplicate()
	camera.fov = BASE_FOV
	health_changed.emit.call_deferred(health, MAX_HEALTH)


func _unhandled_input(event: InputEvent) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and captured and not dead:
		# Look slower while zoomed so aiming stays precise at any FOV.
		var scale := MOUSE_SENSITIVITY * (camera.fov / BASE_FOV)
		rotate_y(-event.relative.x * scale)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * scale, -MAX_PITCH, MAX_PITCH)
		weapons.add_look(event.relative)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and not captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func take_damage(amount: float, from_position: Vector3) -> void:
	if dead:
		return
	health = maxf(health - amount, 0.0)
	_regen_t = REGEN_DELAY
	var toward := from_position - global_position
	toward.y = 0.0
	damaged.emit(toward.normalized())
	health_changed.emit(health, MAX_HEALTH)
	Sfx.play("player_hurt", -2.0)
	if health <= 0.0:
		_die()


func _die() -> void:
	dead = true
	sliding = false
	_death_t = 0.0
	velocity = Vector3.ZERO
	died.emit()


func _respawn() -> void:
	dead = false
	health = MAX_HEALTH
	global_transform = _spawn_transform
	head.rotation = Vector3.ZERO
	crouched = false
	weapons.reset_loadout()
	health_changed.emit(health, MAX_HEALTH)
	respawned.emit()


func _physics_process(delta: float) -> void:
	if dead:
		_death_t += delta
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		if _death_t >= RESPAWN_DELAY:
			_respawn()
		return

	_slide_cd = maxf(_slide_cd - delta, 0.0)
	var on_floor := is_on_floor()
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var firing := captured and (Input.is_action_pressed("fire") or Input.is_action_pressed("ads"))

	_update_crouch(on_floor, input, firing)

	if not on_floor:
		velocity += get_gravity() * delta
		_fall_speed = -velocity.y
	elif Input.is_action_just_pressed("jump") and _can_stand():
		velocity.y = JUMP_VELOCITY
		sliding = false
		crouched = false

	var sprinting := (
		Input.is_action_pressed("sprint")
		and input.y < -0.1
		and not crouched
		and not sliding
		and not firing
		and not weapons.is_reloading()
	)

	if sliding:
		_slide_t -= delta
		var k := clampf(_slide_t / SLIDE_TIME, 0.0, 1.0)
		var slide_speed := lerpf(CROUCH_SPEED, SLIDE_SPEED, k)
		velocity.x = _slide_dir.x * slide_speed
		velocity.z = _slide_dir.z * slide_speed
		if _slide_t <= 0.0 or not on_floor:
			sliding = false
			_slide_cd = SLIDE_COOLDOWN
	else:
		var speed := WALK_SPEED
		if crouched:
			speed = CROUCH_SPEED
		elif sprinting:
			speed = SPRINT_SPEED
		if weapons.ads_t > 0.0:
			speed *= lerpf(1.0, ADS_SPEED_FACTOR, weapons.ads_t)
		var target := direction * speed
		var accel := GROUND_ACCEL if on_floor else AIR_ACCEL
		velocity.x = move_toward(velocity.x, target.x, accel * delta)
		velocity.z = move_toward(velocity.z, target.z, accel * delta)

	move_and_slide()
	speed_h = Vector2(velocity.x, velocity.z).length()
	sprint_t = move_toward(sprint_t, 1.0 if sprinting else 0.0, delta * 6.0)
	if is_on_floor() and _was_airborne:
		_on_land()
	_was_airborne = not is_on_floor()

	if is_on_floor() and _regen_t <= 0.0 and health < MAX_HEALTH:
		health = minf(health + REGEN_RATE * delta, MAX_HEALTH)
		health_changed.emit(health, MAX_HEALTH)
	_regen_t = maxf(_regen_t - delta, 0.0)


func _process(delta: float) -> void:
	_update_body_height(delta)
	_update_camera(delta)


func _update_crouch(on_floor: bool, input: Vector2, firing: bool) -> void:
	var wants_crouch := Input.is_action_pressed("crouch")
	if Input.is_action_just_pressed("crouch") and on_floor and not sliding and _slide_cd <= 0.0:
		var flat_speed := Vector2(velocity.x, velocity.z).length()
		# Crouching at a run turns into a slide, but not while shooting or standing still.
		if flat_speed > WALK_SPEED + 0.8 and input.y < -0.1 and not firing:
			sliding = true
			_slide_t = SLIDE_TIME
			_slide_dir = Vector3(velocity.x, 0.0, velocity.z).normalized()
			Sfx.play("slide", -8.0)
	if wants_crouch:
		crouched = true
	elif crouched and not sliding and _can_stand():
		crouched = false
	if sliding and not wants_crouch and _slide_t < SLIDE_TIME * 0.6:
		sliding = false
		_slide_cd = SLIDE_COOLDOWN


func _can_stand() -> bool:
	if _height >= STAND_HEIGHT - 0.01:
		return true
	return not test_move(global_transform, Vector3.UP * (STAND_HEIGHT - _height))


func _update_body_height(delta: float) -> void:
	var target := CROUCH_HEIGHT if (crouched or sliding) else STAND_HEIGHT
	_height = move_toward(_height, target, 7.0 * delta)
	var capsule := collision.shape as CapsuleShape3D
	capsule.height = _height
	collision.position.y = _height * 0.5
	var eye := lerpf(CROUCH_EYE, STAND_EYE, (_height - CROUCH_HEIGHT) / (STAND_HEIGHT - CROUCH_HEIGHT))
	head.position.y = lerpf(head.position.y, eye if not dead else 0.35, 1.0 - exp(-18.0 * delta))


func _update_camera(delta: float) -> void:
	var on_floor := is_on_floor()
	var ads_s := smoothstep(0.0, 1.0, weapons.ads_t)

	# Head bob: one cycle per two steps, scaled by speed and damped while aiming.
	var stride := speed_h if (on_floor and not sliding) else 0.0
	var previous_phase := _bob_phase
	_bob_phase += stride * delta * 1.55
	var bob_amount := clampf(stride / SPRINT_SPEED, 0.0, 1.0) * (1.0 - ads_s * 0.8)
	bob = Vector2(cos(_bob_phase * 0.5) * 0.018, absf(sin(_bob_phase)) * 0.03 - 0.015) * bob_amount
	if stride > 1.0 and floorf(_bob_phase / PI) != floorf(previous_phase / PI):
		Sfx.play("step", -16.0 + stride, 0.9 + stride * 0.03)

	_land_dip = lerpf(_land_dip, 0.0, 1.0 - exp(-9.0 * delta))

	var input_x := Input.get_axis("move_left", "move_right")
	var slide_roll := 3.5 if sliding else 0.0
	var target_roll := deg_to_rad(-input_x * 1.3 * (1.0 - ads_s) - slide_roll)
	if dead:
		target_roll = deg_to_rad(65.0)
	_roll = lerpf(_roll, target_roll, 1.0 - exp(-10.0 * delta))

	var recoil := weapons.recoil_offset
	camera.rotation = Vector3(recoil.x, recoil.y, _roll)
	camera.position = Vector3(bob.x, bob.y - _land_dip, 0.0)

	var hip_fov := BASE_FOV + SPRINT_FOV * sprint_t + (2.0 if sliding else 0.0)
	camera.fov = lerpf(hip_fov, weapons.current.ads_fov, ads_s)


func _on_land() -> void:
	var impact := _fall_speed
	_fall_speed = 0.0
	if impact > 3.0:
		_land_dip = clampf(impact * 0.012, 0.0, 0.14)
		Sfx.play("land", -10.0 + minf(impact, 10.0))
