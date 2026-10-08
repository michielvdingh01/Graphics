extends CharacterBody3D

signal health_changed(health: float, max_health: float)
signal damaged(amount: float)
signal died

const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.0
const CROUCH_SPEED := 2.8
const JUMP_VELOCITY := 4.8
const GROUND_ACCEL := 60.0
const AIR_ACCEL := 12.0

const SLIDE_BOOST_SPEED := 11.0
const SLIDE_FRICTION := 7.0
const SLIDE_SLOPE_ACCEL := 20.0
const SLIDE_MIN_ENTER_SPEED := 6.5
const SLIDE_END_SPEED := 3.5
const SLIDE_COOLDOWN := 0.5

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.1
const STAND_EYE := 1.6
const CROUCH_EYE := 0.95
const SLIDE_EYE := 0.8

const SPRINT_FOV_KICK := 5.0
const SLIDE_FOV_KICK := 9.0
const MOUSE_SENSITIVITY := 0.002
## Radians per second at full stick deflection.
const STICK_SPEED := 3.6
const MAX_PITCH := deg_to_rad(89.0)
const RECOIL_SNAP := 30.0
const RECOIL_RETURN := 7.0
const STEP_DISTANCE := 2.4

const MAX_HEALTH := 100.0
const REGEN_DELAY := 4.0
const REGEN_RATE := 20.0

var health := MAX_HEALTH
var dead := false
## Lets the self-test drive the player without a captured mouse.
var force_control := false

var _crouched := false
var _sliding := false
var _slide_cooldown := 0.0
var _eye_height := STAND_EYE
var _land_dip := 0.0
var _tilt := 0.0
var _fall_speed := 0.0
var _was_on_floor := true
var _step_distance := 0.0
var _since_damage := 0.0
var _recoil_target := Vector3.ZERO
var _recoil := Vector3.ZERO
## A click of the left stick keeps sprinting until the stick is let go.
var _sprint_latched := false

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapons: Node3D = $Head/Camera3D/Weapons
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var capsule: CapsuleShape3D = collision.shape


func _ready() -> void:
	if not Menu.is_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func has_control() -> bool:
	return not dead and (force_control or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)


func is_sliding() -> bool:
	return _sliding


func is_crouched() -> bool:
	return _crouched


func is_sprinting() -> bool:
	return (
		(Input.is_action_pressed("sprint") or _sprint_latched)
		and Input.get_axis("move_forward", "move_back") < 0.0
		and not _crouched
		and not weapons.blocks_sprint()
	)


## Kicks the camera by the given angles in radians; it settles back by itself.
func add_recoil(pitch: float, yaw: float) -> void:
	_recoil_target += Vector3(pitch, yaw, yaw * 0.5)


func take_damage(amount: float, _position := Vector3.ZERO, _direction := Vector3.ZERO) -> bool:
	if dead:
		return false
	health = maxf(health - amount, 0.0)
	_since_damage = 0.0
	add_recoil(randf_range(-0.01, 0.02), randf_range(-0.015, 0.015))
	Sfx.play(&"hurt", -4.0)
	damaged.emit(amount)
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0.0:
		dead = true
		_set_crouched(true)
		died.emit()
	return dead


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and has_control():
		_look(event.relative * MOUSE_SENSITIVITY * Settings.mouse_sensitivity)
	elif event is InputEventJoypadButton and event.is_action_pressed("sprint"):
		_sprint_latched = true


## Turns the view by the given yaw and pitch in radians at the base field of view.
func _look(amount: Vector2) -> void:
	# Scale with zoom so aiming down sights keeps the same on-screen feel.
	amount *= camera.fov / Settings.fov
	if Settings.invert_y:
		amount.y = -amount.y
	rotate_y(-amount.x)
	head.rotation.x = clampf(head.rotation.x - amount.y, -MAX_PITCH, MAX_PITCH)


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	if not on_floor:
		velocity += get_gravity() * delta
	if dead:
		velocity.x = move_toward(velocity.x, 0.0, GROUND_ACCEL * delta)
		velocity.z = move_toward(velocity.z, 0.0, GROUND_ACCEL * delta)
		move_and_slide()
		return

	var control := has_control()
	var input := Vector2.ZERO
	if control:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.y > -0.5:
		_sprint_latched = false
	# Keeps analogue stick input analogue; keys still give a unit vector.
	var direction := transform.basis * Vector3(input.x, 0.0, input.y)
	var wants_crouch := control and Input.is_action_pressed("crouch")
	var wants_jump := control and Input.is_action_just_pressed("jump")
	var speed := Vector2(velocity.x, velocity.z).length()
	_slide_cooldown -= delta

	if _sliding:
		if wants_jump and on_floor:
			velocity.y = JUMP_VELOCITY
			_end_slide()
		elif not wants_crouch or speed < SLIDE_END_SPEED:
			_end_slide()
	elif (
		on_floor
		and control
		and Input.is_action_just_pressed("crouch")
		and speed > SLIDE_MIN_ENTER_SPEED
		and _slide_cooldown <= 0.0
	):
		_start_slide()
	elif wants_jump and on_floor and _can_stand():
		velocity.y = JUMP_VELOCITY

	_set_crouched(_sliding or wants_crouch)

	if _sliding:
		if on_floor:
			var horizontal := Vector3(velocity.x, 0.0, velocity.z)
			var normal := get_floor_normal()
			horizontal += Vector3(normal.x, 0.0, normal.z) * SLIDE_SLOPE_ACCEL * delta
			horizontal = horizontal.move_toward(Vector3.ZERO, SLIDE_FRICTION * delta)
			velocity.x = horizontal.x
			velocity.z = horizontal.z
	else:
		var max_speed := WALK_SPEED
		if _crouched:
			max_speed = CROUCH_SPEED
		elif is_sprinting():
			max_speed = SPRINT_SPEED
		max_speed *= weapons.move_speed_scale()
		var target := direction * max_speed
		var accel := GROUND_ACCEL if on_floor else AIR_ACCEL
		velocity.x = move_toward(velocity.x, target.x, accel * delta)
		velocity.z = move_toward(velocity.z, target.z, accel * delta)

	_fall_speed = velocity.y
	move_and_slide()

	if is_on_floor():
		if not _was_on_floor and _fall_speed < -2.0:
			_land_dip = clampf(-_fall_speed * 0.03, 0.0, 0.3)
			Sfx.play(&"land", -6.0)
		if not _sliding:
			_step_distance += Vector2(velocity.x, velocity.z).length() * delta
			if _step_distance > STEP_DISTANCE:
				_step_distance = 0.0
				Sfx.play(&"footstep", -16.0 if _crouched else -10.0)
	_was_on_floor = is_on_floor()

	_since_damage += delta
	if _since_damage > REGEN_DELAY and health < MAX_HEALTH:
		health = minf(health + REGEN_RATE * delta, MAX_HEALTH)
		health_changed.emit(health, MAX_HEALTH)


func _process(delta: float) -> void:
	if has_control():
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		# Squared response: fine aim near the centre, full speed at the edge.
		stick *= stick.length() * STICK_SPEED * Settings.stick_sensitivity * delta
		_look(Vector2(stick.x, stick.y * 0.65))

	var eye := STAND_EYE
	if dead:
		eye = 0.4
	elif _sliding:
		eye = SLIDE_EYE
	elif _crouched:
		eye = CROUCH_EYE
	_eye_height = lerpf(_eye_height, eye, 1.0 - exp(-12.0 * delta))
	_land_dip = lerpf(_land_dip, 0.0, 1.0 - exp(-9.0 * delta))
	head.position.y = _eye_height - _land_dip

	_recoil_target = _recoil_target.lerp(Vector3.ZERO, 1.0 - exp(-RECOIL_RETURN * delta))
	_recoil = _recoil.lerp(_recoil_target, 1.0 - exp(-RECOIL_SNAP * delta))
	# Lean into strafes a little, and more during a slide.
	var sideways := velocity.dot(global_basis.x)
	var tilt := -sideways * 0.004 + (0.07 if _sliding else 0.0) + (0.5 if dead else 0.0)
	_tilt = lerpf(_tilt, tilt, 1.0 - exp(-10.0 * delta))
	camera.rotation = _recoil + Vector3(0.0, 0.0, _tilt)

	var fov: float = Settings.fov
	if _sliding:
		fov += SLIDE_FOV_KICK
	elif is_sprinting() and velocity.length() > WALK_SPEED + 0.5:
		fov += SPRINT_FOV_KICK
	fov = lerpf(fov, weapons.ads_fov(), smoothstep(0.0, 1.0, weapons.ads_blend))
	camera.fov = lerpf(camera.fov, fov, 1.0 - exp(-14.0 * delta))


func _start_slide() -> void:
	_sliding = true
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.normalized() * maxf(horizontal.length(), SLIDE_BOOST_SPEED)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	Sfx.play(&"slide", -8.0)


func _end_slide() -> void:
	_sliding = false
	_slide_cooldown = SLIDE_COOLDOWN


func _set_crouched(crouch: bool) -> void:
	if crouch == _crouched or (not crouch and not _can_stand()):
		return
	_crouched = crouch
	capsule.height = CROUCH_HEIGHT if crouch else STAND_HEIGHT
	collision.position.y = capsule.height * 0.5


func _can_stand() -> bool:
	if not _crouched:
		return true
	var shape := CapsuleShape3D.new()
	shape.radius = capsule.radius - 0.02
	shape.height = STAND_HEIGHT - 0.1
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position + Vector3.UP * (STAND_HEIGHT * 0.5 + 0.05))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
