extends CharacterBody3D

signal health_changed(health: float, max_health: float)
signal damaged(amount: float)
## The player was hit for `amount`, and from where: `bearing` points from the
## player towards whoever or whatever did it, level with the floor and one
## long, in the axes of the world. It is zero for a hit that came from no side
## in particular: a fire underfoot, a blast overhead.
signal hit_from(amount: float, bearing: Vector3)
## Back on the floor after a fall. `hardness` is 0 for a step down and 1 for a
## fall that makes the knees give as far as they go.
signal landed(hardness: float)
signal died
signal revived

const SPRING := preload("res://scripts/spring.gd")
const VEHICLE := preload("res://scripts/vehicle.gd")

const WALK_SPEED := 5.0
const SPRINT_SPEED := 7.2
const CROUCH_SPEED := 2.8
## A jump is short and snappy: 0.9 m high and back on the floor in two thirds
## of a second. The player falls faster than the world's gravity for that.
const JUMP_VELOCITY := 5.4
const GRAVITY_SCALE := 1.65
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
## The most that shots widen the field of view, in degrees, and how fast that
## goes again, per second: most of it within a tenth of a second.
const FOV_PUNCH_MAX := 1.5
const FOV_PUNCH_FADE := 25.0
const MOUSE_SENSITIVITY := 0.002
## Radians per second at full stick deflection.
const STICK_SPEED := 3.6
const MAX_PITCH := deg_to_rad(89.0)
const RECOIL_SNAP := 30.0
const RECOIL_RETURN := 7.0
## Metres of floor from one footfall to the next.
const STEP_DISTANCE := 2.4
## Metres of sand from one print of a boot to the next, which is a real
## pace and not the footfall that is heard, and how far to either side of
## the way walked the left and the right boot come down.
const PRINT_DISTANCE := 0.74
const PRINT_STANCE := 0.1
## Head bob at walking speed: how far the eye rises and falls with every step
## and sways towards the foot that carries the weight, in metres, and how far
## the head rolls with that sway and nods with the step, in radians. Small on
## purpose: it is there to be felt, not seen.
const BOB_HEIGHT := 0.014
const BOB_SWAY := 0.006
const BOB_ROLL := 0.0035
const BOB_NOD := 0.002
## How much more there is of it at a sprint than at a walk, and how fast it
## comes and goes, per second, so that it never starts or stops with a jolt.
const BOB_SPRINT := 1.6
const BOB_FADE := 8.0
## The share of its rise and sway that is left over the sights. Its roll and
## its nod go altogether there, so that the sights hold still.
const BOB_AIMED := 0.2
## Landing, the knees give: the fall speed in m/s that is taken without, the
## metres the eye dips for every m/s over that, the most it dips, and the
## seconds after touching down at which it is lowest.
const LAND_SPARE := 2.0
const LAND_DIP := 0.025
const LAND_DIP_MAX := 0.16
const LAND_TIME := 0.07
## Being hit knocks the head aside: by this many radians for a hit of HIT_FULL
## damage or more and by less for less, see hit_weight(), furthest after
## HIT_TIME seconds. It rolls away from the side the hit came from, and by no
## less than HIT_ROLL of that, so that a hit from the front or the back rolls
## it as well; of those, HIT_NOD also throws the head back or forward. Over
## the sights HIT_AIMED of it all is left.
const HIT_KICK := 0.017
const HIT_FULL := 40.0
const HIT_TIME := 0.06
const HIT_ROLL := 0.5
const HIT_NOD := 0.5
const HIT_AIMED := 0.5
## A hit of this much damage or more rattles the view as well, by this much,
## see shake().
const HARD_HIT := 20.0
const HIT_TRAUMA := 0.3
## How fast the view settles after an explosion, per second, and how far it
## is thrown about at worst: turned, in radians, moved, in metres, and widened,
## in degrees of the field of view.
const SHAKE_DECAY := 1.3
const SHAKE_ANGLE := 0.055
const SHAKE_SHIFT := 0.015
const SHAKE_FOV := 2.0

const MAX_HEALTH := 100.0
## Health comes back by itself after this long without a hit, but only up to
## what the difficulty allows (Settings.rules().regen_to): the rest has to be
## picked up off the floor, see heal().
const REGEN_DELAY := 4.0
const REGEN_RATE := 20.0

var health := MAX_HEALTH
var dead := false
## Nothing hurts it: for watching a fight from the inside, see sandbox.gd.
var invulnerable := false
## The side it is on in a match (scripts/match.gd), -1 outside of one.
var team := -1
## Lets the self-test drive the player without a captured mouse.
var force_control := false
## The vehicle the player sits in (scripts/vehicle.gd), and in which seat:
## the first is the driver's.
var riding: Node3D
var seat := -1

var _crouched := false
var _sliding := false
var _slide_cooldown := 0.0
var _eye_height := STAND_EYE
## How far the knees have given after a landing, in metres, on its y.
var _land := SPRING.new(LAND_TIME)
var _tilt := 0.0
var _fall_speed := 0.0
var _was_on_floor := true
## See stride() and bob_weight().
var _stride := 0.0
var _bob_weight := 0.0
## How far has been walked since the last print in the sand, and whether the
## next one is of the left boot.
var _since_print := 0.0
var _left_next := false
var _since_damage := 0.0
var _recoil_target := Vector3.ZERO
var _recoil := Vector3.ZERO
## A click of the left stick keeps sprinting until the stick is let go.
var _sprint_latched := false
var _trauma := 0.0
var _shake_time := 0.0
## Where somebody who rides but does not drive looks, from the way the
## vehicle looks; and the layer the player was on before getting in, for a
## seat where no shot reaches.
var _seat_yaw := 0.0
var _layer := 0
## How a hit has knocked the head aside: pitch on its x and roll on its z.
var _knock := SPRING.new(HIT_TIME)
## The field of view without what a shot or a blast adds to it for a moment,
## and what shots add to it, in degrees.
var _fov := 80.0
var _fov_punch := 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapons: Node3D = $Head/Camera3D/Weapons
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var capsule: CapsuleShape3D = collision.shape


func _ready() -> void:
	# The shape would be that of the scene, and stay as small as whoever died
	# in the last level left it: the next would stand in the floor.
	collision.shape = capsule.duplicate()
	capsule = collision.shape
	_fov = camera.fov
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
		not riding
		and (Input.is_action_pressed("sprint") or _sprint_latched)
		and Input.get_axis("move_forward", "move_back") < 0.0
		and not _crouched
		and not weapons.blocks_sprint()
	)


## Where the player is in their stride: a whole number at every footfall and
## one more for every step, back at 0 after 2. From 0 to 1 the right foot
## carries the weight, from 1 to 2 the left. The bob of the view, that of the
## weapon and the sound of a step all go by this one number, which is what
## makes the view dip on the sound.
func stride() -> float:
	return _stride


## How much of a walk there is to show: 0 standing still, in the air, sliding
## or dead, 1 at walking speed and BOB_SPRINT at a sprint. It gets there over
## a few tenths of a second, so that what goes by it never snaps.
func bob_weight() -> float:
	return _bob_weight


## Kicks the camera by the given angles in radians; it settles back by itself.
func add_recoil(pitch: float, yaw: float) -> void:
	_recoil_target += Vector3(pitch, yaw, yaw * 0.5)


## Widens the field of view by `degrees` for a moment, as a shot does: the
## jolt of it, without moving the aim.
func punch_fov(degrees: float) -> void:
	_fov_punch = minf(_fov_punch + degrees, FOV_PUNCH_MAX)


## Rattles the view: 1 is an explosion at arm's length. It settles by itself.
func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


## How hard a hit of `amount` damage lands: 1 for HIT_FULL or more, and for
## less the square root of its share of that, so that a quarter of the damage
## still lands half as hard. A grunt's shot is a sixth of HIT_FULL: going by
## the damage alone it would move the view by less than anybody can see.
func hit_weight(amount: float) -> float:
	return sqrt(clampf(amount / HIT_FULL, 0.0, 1.0))


## True if a shot that landed at `at` is one to the head: in a match the
## player is shot at like anybody else.
func is_headshot(at: Vector3) -> bool:
	return at.y - global_position.y > _eye_height - 0.24


## Mends the player by `amount`. False if there was nothing to mend.
func heal(amount: float) -> bool:
	if dead or health >= MAX_HEALTH:
		return false
	health = minf(health + amount, MAX_HEALTH)
	health_changed.emit(health, MAX_HEALTH)
	return true


## `direction` is the way whatever hit was travelling: from whoever fired it
## towards the player.
func take_damage(amount: float, _position := Vector3.ZERO, direction := Vector3.ZERO) -> bool:
	if dead or invulnerable:
		return false
	health = maxf(health - amount, 0.0)
	_since_damage = 0.0
	var bearing := _bearing(direction)
	_knock_head(amount, bearing)
	Sfx.play(&"hurt", -4.0)
	damaged.emit(amount)
	hit_from.emit(amount, bearing)
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0.0:
		if riding:
			riding.request_leave(self)
		dead = true
		_set_crouched(true)
		died.emit()
	return dead


## Back on its feet at `pose`, as good as new: for a game with others, where
## a death is not the end of the level.
func revive(pose: Transform3D) -> void:
	if riding:
		riding.request_leave(self)
	dead = false
	health = MAX_HEALTH
	_since_damage = 0.0
	_trauma = 0.0
	_fov_punch = 0.0
	_knock.settle()
	_land.settle()
	velocity = Vector3.ZERO
	global_position = pose.origin
	rotation = Vector3(0.0, pose.basis.get_euler().y, 0.0)
	head.rotation.x = 0.0
	_set_crouched(false)
	health_changed.emit(health, MAX_HEALTH)
	revived.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and has_control():
		_look(event.relative * MOUSE_SENSITIVITY * Settings.mouse_sensitivity)
	elif event is InputEventJoypadButton and event.is_action_pressed("sprint"):
		_sprint_latched = true
	elif event.is_action_pressed("use") and has_control():
		# In a game with others the host says who sits where: see
		# request_seat() in scripts/vehicle.gd.
		if riding:
			riding.bail(self)
		else:
			var near := VEHICLE.within_reach(self)
			if near:
				near.vehicle.request_seat(self, near.seat)
	elif event.is_action_pressed("vehicle_seat") and has_control() and riding:
		riding.request_seat(self, riding.next_seat(seat))


## What `body` would get into if it pressed the key now: see
## within_reach() in scripts/vehicle.gd.
func vehicle_in_reach() -> Dictionary:
	return {} if riding or dead else VEHICLE.within_reach(self)


## Into seat `which` of `vehicle`; scripts/vehicle.gd calls this once it has
## room. Whoever drives sees through the camera of the vehicle and puts the
## weapons away, unless it is a car that is driven with one hand (see
## VehicleData.driver_fires): then they stay in hand, out of sight, and fire
## where the middle of that view is. Whoever rides keeps them and their own
## eyes. Where no shot reaches a seat, none reaches the player in it.
func sit(vehicle: Node3D, which: int) -> void:
	if riding == null:
		_layer = collision_layer
	riding = vehicle
	seat = which
	velocity = Vector3.ZERO
	_sliding = false
	_seat_yaw = 0.0
	collision_layer = _layer if vehicle.exposed(which) else 0
	var drives := which == 0
	weapons.lower()
	weapons.visible = not drives
	weapons.process_mode = Node.PROCESS_MODE_DISABLED if drives and not vehicle.data.driver_fires else Node.PROCESS_MODE_INHERIT
	ride(Transform3D())


## Out of the vehicle, standing at `pose`, going at `going`.
func stand(pose: Transform3D, going: Vector3) -> void:
	riding = null
	seat = -1
	collision_layer = _layer
	weapons.visible = true
	weapons.process_mode = Node.PROCESS_MODE_INHERIT
	global_position = pose.origin
	rotation = Vector3(0.0, pose.basis.get_euler().y, 0.0)
	velocity = going
	_was_on_floor = false
	if not camera.current and not dead:
		camera.make_current()


## Where the vehicle carries the player: the eyes where the eyes of its seat
## are, looking where the vehicle looks and as far round from there as the
## player has turned. Whoever drives and fires looks where the view of the
## vehicle is, see fires_from_the_wheel().
func ride(_frame: Transform3D) -> void:
	if riding == null:
		return
	var eye: Transform3D = riding.eye_frame(seat)
	if fires_from_the_wheel():
		var way: Vector3 = riding.view().aim_point() - eye.origin
		if way.length() > 1.0:
			_seat_yaw = angle_difference(eye.basis.get_euler().y, atan2(-way.x, -way.z))
			head.rotation.x = clampf(atan2(way.y, Vector2(way.x, way.z).length()), -MAX_PITCH, MAX_PITCH)
	var facing: float = eye.basis.get_euler().y + _seat_yaw
	rotation = Vector3(0.0, facing, 0.0)
	global_position = eye.origin - Vector3.UP * _eye_height


## True while the player drives a vehicle with their own weapon in hand.
func fires_from_the_wheel() -> bool:
	return riding != null and seat == 0 and riding.data.driver_fires and riding.view() != null


## How far the last shots have thrown the aim up and aside, in radians: for
## a view that is not the player's own, see scripts/vehicle_view.gd.
func kick() -> Vector3:
	return _recoil


## Turns the view by the given yaw and pitch in radians at the base field of view.
func _look(amount: Vector2) -> void:
	# Scale with zoom so aiming down sights keeps the same on-screen feel.
	amount *= _fov / Settings.fov
	if Settings.invert_y:
		amount.y = -amount.y
	if riding and seat == 0:
		if riding.view():
			riding.view().look(amount)
		return
	if riding:
		_seat_yaw -= amount.x
	else:
		rotate_y(-amount.x)
	head.rotation.x = clampf(head.rotation.x - amount.y, -MAX_PITCH, MAX_PITCH)


func _physics_process(delta: float) -> void:
	if riding:
		# The vehicle carries the player, see ride().
		velocity = riding.linear_velocity
		ride(Transform3D())
		_mend(delta)
		return
	var on_floor := is_on_floor()
	if not on_floor:
		velocity += get_gravity() * GRAVITY_SCALE * delta
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

	if is_on_floor() and not _was_on_floor and _fall_speed < -LAND_SPARE:
		var dip := minf((-_fall_speed - LAND_SPARE) * LAND_DIP, LAND_DIP_MAX)
		_land.push(Vector3(0.0, dip, 0.0))
		landed.emit(dip / LAND_DIP_MAX)
		Sfx.play(&"land", -6.0)
	_was_on_floor = is_on_floor()
	_mend(delta)


## Health comes back by itself after a while without a hit.
func _mend(delta: float) -> void:
	_since_damage += delta
	var rules: Dictionary = Settings.rules()
	var regen_to: float = rules.regen_to
	if _since_damage > rules.get("regen_after", REGEN_DELAY) and health < regen_to:
		health = minf(health + REGEN_RATE * delta, regen_to)
		health_changed.emit(health, MAX_HEALTH)


func _process(delta: float) -> void:
	if has_control():
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		# Squared response: fine aim near the centre, full speed at the edge.
		stick *= stick.length() * STICK_SPEED * Settings.stick_sensitivity * delta
		_look(Vector2(stick.x, stick.y * 0.65))

	if riding:
		ride(Transform3D())
	var eye := STAND_EYE
	if dead:
		eye = 0.4
	elif _sliding:
		eye = SLIDE_EYE
	elif _crouched:
		eye = CROUCH_EYE
	_eye_height = lerpf(_eye_height, eye, 1.0 - exp(-12.0 * delta))
	head.position.y = _eye_height

	_recoil_target = _recoil_target.lerp(Vector3.ZERO, 1.0 - exp(-RECOIL_RETURN * delta))
	_recoil = _recoil.lerp(_recoil_target, 1.0 - exp(-RECOIL_SNAP * delta))

	# From here on the view moves by itself, on a head that stays where the
	# player holds it: that is what enemies aim at, and its pitch is what
	# others are sent. All of it goes by the one setting.
	var motion: float = Settings.view_motion
	var aim := smoothstep(0.0, 1.0, weapons.ads_blend)
	var bob := _walk(delta) * motion
	var steady := lerpf(1.0, BOB_AIMED, aim)
	var side := sin(PI * _stride)
	var lift := -cos(TAU * _stride)
	# Lean into strafes a little, and more during a slide.
	var sideways := velocity.dot(global_basis.x) if not riding else 0.0
	var tilt := (-sideways * 0.004 + (0.07 if _sliding else 0.0)) * motion + (0.5 if dead else 0.0)
	_tilt = lerpf(_tilt, tilt, 1.0 - exp(-10.0 * delta))
	_trauma = maxf(_trauma - SHAKE_DECAY * delta, 0.0)
	_shake_time += delta
	var shaken := _trauma * _trauma * motion
	var rattle := Vector3(
		sin(_shake_time * 53.0) + sin(_shake_time * 31.7 + 1.3),
		sin(_shake_time * 47.0 + 2.1) + sin(_shake_time * 27.1),
		sin(_shake_time * 41.0 + 0.7) + sin(_shake_time * 23.3 + 4.0)
	) * (shaken * SHAKE_ANGLE * 0.5)
	var jolt := Vector3(
		sin(_shake_time * 44.0 + 0.9) + sin(_shake_time * 29.3 + 2.6),
		sin(_shake_time * 50.0 + 3.3) + sin(_shake_time * 25.9 + 1.1),
		sin(_shake_time * 37.0 + 5.2) + sin(_shake_time * 21.7)
	) * (shaken * SHAKE_SHIFT * 0.5)
	_land.step(delta)
	_knock.step(delta)
	camera.position = (
		Vector3(side * BOB_SWAY, lift * BOB_HEIGHT, 0.0) * (bob * steady)
		+ Vector3.DOWN * (minf(_land.at.y, LAND_DIP_MAX) * motion)
		+ jolt
	)
	camera.rotation = (
		_recoil + Vector3(0.0, 0.0, _tilt) + rattle
		+ Vector3(lift * BOB_NOD, 0.0, -side * BOB_ROLL) * (bob * (1.0 - aim))
		+ _knock.at * motion
	)

	var fov: float = Settings.fov
	if _sliding:
		fov += SLIDE_FOV_KICK * motion
	elif is_sprinting() and velocity.length() > WALK_SPEED + 0.5:
		fov += SPRINT_FOV_KICK * motion
	fov = lerpf(fov, weapons.ads_fov(), smoothstep(0.0, 1.0, weapons.ads_blend))
	# What a shot or a blast adds comes on top of this: put through the same
	# easing, a punch that is over in a tenth of a second would never show.
	_fov = lerpf(_fov, fov, 1.0 - exp(-14.0 * delta))
	camera.fov = _fov + _fov_punch * motion + shaken * SHAKE_FOV * _fov / Settings.fov
	# It fades after it has been shown: the first frame of a punch is all of it.
	_fov_punch *= exp(-FOV_PUNCH_FADE * delta)


## What a step sounds like on what the player stands on: sand has a sound of
## its own, everything else that of a boot on concrete.
func _step_sound() -> StringName:
	var down := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, global_position + Vector3.DOWN * 0.4, 1)
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(down)
	return &"footstep_sand" if floor_hit and Fx.surface_of(floor_hit) == "sand" else &"footstep"


## Leaves the print of a boot where the player walks on sand: the left and
## the right in turn, to either side of the way he goes.
func _leave_print() -> void:
	var heading := Vector3(velocity.x, 0.0, velocity.z).normalized()
	var at := global_position + heading.cross(Vector3.UP) * (-PRINT_STANCE if _left_next else PRINT_STANCE)
	_left_next = not _left_next
	var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * 0.5, 1)
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(down)
	if floor_hit and Fx.surface_of(floor_hit) == "sand":
		Fx.footprint(floor_hit.position, floor_hit.normal, heading)


## Moves the stride on by what was walked in `delta` seconds, sounds a step at
## every footfall and returns how much of a walk there is to show, see
## bob_weight(). A stride is only ever paused, never started afresh: a bob
## that began again from nothing with every first step would be a jolt.
func _walk(delta: float) -> float:
	var speed := Vector2(velocity.x, velocity.z).length()
	var walking := not dead and not _sliding and is_on_floor()
	if walking:
		var foot := floorf(_stride)
		_stride += speed * delta / STEP_DISTANCE
		if floorf(_stride) > foot:
			Sfx.play(_step_sound(), -16.0 if _crouched else -10.0)
		_stride = fposmod(_stride, 2.0)
		_since_print += speed * delta
		if _since_print >= PRINT_DISTANCE:
			_since_print = 0.0
			_leave_print()
	var weight := minf(speed / WALK_SPEED, BOB_SPRINT) if walking else 0.0
	_bob_weight = lerpf(_bob_weight, weight, 1.0 - exp(-BOB_FADE * delta))
	return _bob_weight


## Where a hit came from, given the way it was travelling: a direction level
## with the floor and one long, or zero if it came from above, from below or
## from nowhere, as a fire underfoot does.
func _bearing(direction: Vector3) -> Vector3:
	var back := -direction.normalized()
	var level := Vector3(back.x, 0.0, back.z)
	return level.normalized() if level.length() > 0.2 else Vector3.ZERO


## Knocks the head aside, away from where a hit came from: mostly a roll,
## which leaves the aim where it was, and for a hit from the front a little
## back. The roll is never less than HIT_ROLL of what a hit from the side
## gives: most shots come from where the player looks, and those would
## otherwise move the view least of all. One with no side to it, from straight
## ahead, from behind or from nowhere, rolls it either way by chance. This
## takes the place of a kick of the aim by chance, as large for a graze as for
## a blow: being hit should say from where, not spoil the next shot.
func _knock_head(amount: float, bearing: Vector3) -> void:
	var size := hit_weight(amount) * HIT_KICK * lerpf(1.0, HIT_AIMED, weapons.ads_blend)
	var from := global_basis.inverse() * bearing
	var side := signf(from.x)
	if is_zero_approx(from.x):
		side = 1.0 if randf() < 0.5 else -1.0
	_knock.push(Vector3(-from.z * HIT_NOD, 0.0, side * maxf(absf(from.x), HIT_ROLL)) * size)
	if amount >= HARD_HIT:
		shake(HIT_TRAUMA)


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
