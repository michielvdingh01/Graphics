extends RigidBody3D
## Something with an engine that can be driven: a field car, a lorry, a tank.
## What kind it is, is its model (tools/models/vehicles.gd) and its numbers
## (vehicles/<kind>.tres, see scripts/vehicle_data.gd). This is how any of
## them drives, wears down and sounds, so that a new vehicle for a new level
## is a model and a file, and a level stands it with vehicle() in
## tools/kit/field.gd.
##
## It stands on its wheels: from where each hangs a ray goes down to the
## ground, with a spring and a damper on it, and the tyre where it touches
## holds sideways and pushes along as far as its grip goes. The engine turns
## them through a gearbox that shifts by itself. A vehicle on tracks turns
## by driving them apart, on the spot if it stands still. It drives as a
## vehicle in a game does, not as one in a simulator: a little extra weight
## keeps it on the ground, a bar between the springs keeps it from rolling
## over in a bend, and if it does go over it rights itself after a while.
##
## Whoever gets in sits in a seat of the model (enter()); who sits in that
## of the driver drives it with the keys of walking: W gas, S brake and back,
## A and D steer, Space the hand brake. E gets in and out, Q moves on to the
## next seat, C changes the view (see scripts/vehicle_view.gd). In a tank the
## driver lays the gun with the mouse and fires it with the button; whoever
## else rides has their own weapons.
##
## It wears down. A shot from a gun takes off a share of what it does to a
## person, a shell, a rocket or a blast takes off the lot, and so does a
## crash, as much as it was hard. Below DAMAGED the engine is hit: it
## smokes, misfires and pulls less. Below BURNING it is alight and burns
## down by itself, and at nothing it goes up, with whoever is still in it.
## What is left is a wreck; in a match a new one stands where the first one
## stood, a while later.
##
## Standing still with nobody in it, it is frozen and costs nothing; whatever
## gets in, hits it or runs into it wakes it.
##
## For now it is driven on one machine: in a game with others nobody gets in.

## A vehicle has been got into or out of: `seat` is the number of the seat.
signal entered(body: Node3D, seat: int)
signal left(body: Node3D, seat: int)
## It changed up or down; `to` is the gear, -1 being reverse.
signal shifted(to: int)
signal went_up

## How the engine is: running as it should, hit, alight, or gone.
enum Condition { SOUND, DAMAGED, BURNING, WRECKED }

const DATA := "res://vehicles/%s.tres"
const VIEW := preload("res://scripts/vehicle_view.gd")
const SOUND := preload("res://scripts/vehicle_sound.gd")
const SHELL := preload("res://scripts/shell.gd")
## The layer of the level, on which a vehicle is as well: a shot stops on
## it, a wheel stands on it and people walk into it. Its own layer says it
## is a vehicle, and is one that a blast reaches.
const WORLD := 1
const VEHICLE := 1 << 6
## Whoever can be run over: players, robots and the two sides of a match.
const PEOPLE := 2 | 4 | (1 << 8) | (1 << 9)
const GRAVITY := 9.8
## Seconds it has to lie still with nobody in it before it is frozen, and the
## speed in m/s under which it counts as still.
const SETTLES := 1.5
const STILL := 0.12
## How far from a seat, in metres, somebody can still get into it.
const REACH := 2.4
## Seconds it lies on its side or its roof, nearly still, before it rights
## itself, and how hard it does, in turns a second it would reach.
const RIGHTS_AFTER := 2.0
const RIGHTING := 2.5
## A change of speed in one step, in m/s, that is heard as a bump against
## something, and the seconds after one before the next is heard.
const BUMP := 1.6
const BUMP_GAP := 0.25
## Seconds after somebody has been run over before the same body can be run
## over again.
const RUN_OVER_AGAIN := 0.8
## A wheeled vehicle turns no faster than this in radians a second unless
## its hand brake is on: it can be thrown into a slide, not spun like a top.
const YAW_LIMIT := 2.0
## How fast in m/s a field car is thrown by a blast at its heart; anything
## heavier less so.
const THROWN := 5.0
## Seconds a wreck lies in a match before a new one stands where it stood.
const COMES_BACK := 45.0
## Seconds a wreck burns.
const WRECK_BURNS := 30.0
## Where the sight of the gun is, in the frame of the gun: to its left over
## the mantlet.
const SIGHT_AT := Vector3(-0.55, 0.38, 0.25)
## What of it burns away, by the name of its material.
const BURNS_AWAY: Array[String] = ["glass", "canvas", "camo_net", "field_marks", "sandbag"]
## Seconds between two puffs of smoke from an engine that is hit.
const PUFF := 0.09
## What a misfire is: how long the engine gives nothing, and how long it
## runs between two at the least and the most, in seconds.
const MISFIRE := 0.16
const MISFIRES := Vector2(0.6, 2.4)

## What kind of vehicle it is: the name of its model and its file.
@export var kind := "jeep"
## How far its turret is turned to its right, in degrees, as it stands.
@export var turret_deg := 0.0

var data: VehicleData
var health := 0.0
var condition := Condition.SOUND
var engine_on := false
## How fast the engine turns, and in which gear it is: 1 and up forward, -1
## reverse.
var rpm := 0.0
var gear := 1
## How fast it goes along its nose, in m/s; backwards below nought.
var speed := 0.0
## What the driver asks of it, each 0 to 1, and the steering, -1 full left
## to 1 full right, and the hand brake.
var ask_forward := 0.0
var ask_back := 0.0
var steering := 0.0
var hand_brake := false
## What that comes to: gas and brake, 0 to 1.
var gas := 0.0
var braking := 0.0
## The seats as the model has them (see _layout in
## tools/models/vehicles.gd), and who sits in each, null for nobody.
var seats: Array = []
var occupants: Array[Node3D] = []
## Where the turret is turned, in radians about its Y from straight ahead,
## and how far the gun is lifted; and the way, in the world, the driver
## wants it to point.
var turret_yaw := 0.0
var gun_pitch := 0.0
var aim := Vector3.ZERO
## How far the gun is loaded, 0 just fired and 1 ready.
var loaded := 1.0
## Who last hurt it, as scripts/match.gd numbers those who play: whoever
## destroys it has the kills of those in it.
var last_hurt_by := 0
## Where it stood when the level began.
var spawn := Transform3D()
## Drives itself without anybody in the seat: for the tests, who set
## ask_forward and the rest themselves.
var autopilot := false

var _wheels: Array[Wheel] = []
var _model: Node3D
var _turret: Node3D
var _gun: Node3D
var _muzzle: Node3D
var _steering_wheel: Node3D
var _rests := {}
## Colliders that turn with the turret or the gun, with where they are in
## the frame of what they turn with.
var _turning_shapes: Array[Array] = []
## The box around everything that is in the way, in its own coordinates.
var _hull := AABB()
var _drive_radius := 0.5
var _driven := 0
var _steer := 0.0
var _starting := 0.0
var _shifting := 0.0
var _shift_to := 1
var _still_for := 0.0
var _over_for := 0.0
var _last_velocity := Vector3.ZERO
var _bumped := 0.0
var _run_over := {}
var _misfire := 0.0
var _misfire_in := 1.0
var _puff := 0.0
var _flames: Node3D
var _fire: Dictionary = {}
var _burns_for := 0.0
var _comes_back := 0.0
var _clock := 0.0
var _sound: Node3D
var _view: Node3D
var _pristine: Node
var _braked_hard := false
var _turret_moving := 0.0


## A wheel, or the stretch of a track over one road wheel: where it hangs
## and how the ground under it is.
class Wheel:
	var part := ""
	var at := Vector3.ZERO
	var radius := 0.4
	var steers := false
	var drives := true
	var side := 1.0
	## How far its spring is pressed in, in metres, now and a step ago.
	var pressed := 0.0
	var was_pressed := 0.0
	var touching := false
	var point := Vector3.ZERO
	var normal := Vector3.UP
	## What the ground pushes up on it with, in newtons.
	var load := 0.0
	## How fast it turns about its axle, in radians a second, and how far it
	## has turned.
	var spin := 0.0
	var turned := 0.0
	## It turns faster than it rolls, or is locked while it rolls: a skid.
	var slip := 0.0
	var surface := ""


func _ready() -> void:
	# What stands in the level is kept as it is, for a new one to take its
	# place once this one is a wreck.
	_pristine = duplicate()
	# Whoever made it may have handed it numbers of its own: tools/hear_drive.gd.
	if data == null:
		data = load(DATA % kind)
	add_to_group("vehicle")
	health = data.health
	spawn = global_transform
	mass = data.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = data.center_of_mass
	collision_layer = WORLD | VEHICLE
	collision_mask = WORLD | 8
	continuous_cd = true
	# The air and the ground slow it down, see _drive(); the damping every
	# body has besides would hold it back by a thousand newtons and more.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.3
	contact_monitor = true
	max_contacts_reported = 6
	var skin := PhysicsMaterial.new()
	skin.friction = 0.5
	skin.bounce = 0.05
	physics_material_override = skin
	_model = get_node_or_null("Model")
	if _model == null:
		_model = data.model.instantiate()
		_model.name = "Model"
		add_child(_model)
	seats = _model.get_meta(&"seats", [])
	occupants.resize(seats.size())
	for wheel: Dictionary in _model.get_meta(&"wheels", []):
		var w := Wheel.new()
		w.part = wheel.part
		w.at = wheel.at
		w.radius = wheel.radius
		w.steers = wheel.steers
		w.drives = wheel.drives
		w.side = wheel.side
		w.pressed = data.travel
		w.was_pressed = data.travel
		_wheels.append(w)
		if w.drives:
			_driven += 1
			_drive_radius += w.radius
	_drive_radius = (_drive_radius - 0.5) / maxf(_driven, 1)
	for part: String in ["Turret", "Gun", "Steering"]:
		var node := _model.find_child(part, true, false) as Node3D
		if node:
			_rests[node] = node.transform
	_turret = _model.find_child("Turret", true, false)
	_gun = _model.find_child("Gun", true, false)
	_muzzle = _model.find_child("Muzzle", true, false)
	_steering_wheel = _model.find_child("Steering", true, false)
	for wheel in _wheels:
		var node := _model.find_child(wheel.part, true, false) as Node3D
		if node and not _rests.has(node):
			_rests[node] = node.transform
	_make_hull()
	# What the level put on the turret goes round with it.
	for child in get_children():
		if child.has_meta(&"on_turret") and _turret:
			child.reparent(_turret)
	turret_yaw = -deg_to_rad(turret_deg)
	_lay_gun()
	_remember_turning_shapes()
	aim = _gun_direction()
	_sound = SOUND.new()
	_sound.name = "Sound"
	add_child(_sound)
	_sound.setup(self)
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	_last_velocity = Vector3.ZERO


## The colliders: the boxes the model says are in the way, unless the level
## gave it its own.
func _make_hull() -> void:
	var made := false
	for child in get_children():
		if child is CollisionShape3D:
			made = true
	if not made:
		for box: Dictionary in _model.get_meta(&"hull", []):
			var shape := CollisionShape3D.new()
			var cube := BoxShape3D.new()
			cube.size = box.size
			shape.shape = cube
			shape.position = box.at
			shape.set_meta(&"surface", "metal")
			if box.part != "":
				shape.set_meta(&"turns_with", box.part)
			add_child(shape)
	for child in get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
			var size: Vector3 = ((child as CollisionShape3D).shape as BoxShape3D).size
			var box := AABB(child.position - size * 0.5, size)
			if not child.has_meta(&"turns_with"):
				_hull = box if _hull.size == Vector3.ZERO else _hull.merge(box)


func _remember_turning_shapes() -> void:
	for child in get_children():
		if child is CollisionShape3D and child.has_meta(&"turns_with"):
			var with: Node3D = _gun if child.get_meta(&"turns_with") == "Gun" else _turret
			if with:
				_turning_shapes.append([child, with.global_transform.affine_inverse() * (child as Node3D).global_transform, with])


# --- Who is in it --------------------------------------------------------------------


## The vehicle and the seat that `body` would get into from where it stands:
## {vehicle, seat}, empty if there is none within reach. The driver's seat
## goes first if it is free, then the nearest free one.
static func within_reach(body: Node3D) -> Dictionary:
	var best := {}
	var nearest := INF
	for vehicle: Node in body.get_tree().get_nodes_in_group("vehicle"):
		if not vehicle.can_take(body):
			continue
		var seat: int = vehicle.free_seat_near(body.global_position)
		if seat < 0:
			continue
		var distance: float = vehicle.reach_of(body.global_position)
		if distance < nearest:
			nearest = distance
			best = {"vehicle": vehicle, "seat": seat}
	return best


## True if `body` may get in at all.
func can_take(body: Node3D) -> bool:
	if condition == Condition.WRECKED or body in occupants:
		return false
	# Over the wire the others would not see it move: not yet.
	if Net.active and Net.players.size() > 1:
		return false
	return reach_of(body.global_position) < REACH


## How far `at` is from the vehicle: from the box around it, on the ground.
func reach_of(at: Vector3) -> float:
	var local := global_transform.affine_inverse() * at
	var flat := AABB(Vector3(_hull.position.x, -1.0, _hull.position.z), Vector3(_hull.size.x, _hull.end.y + 3.0, _hull.size.z))
	if flat.has_point(local):
		return 0.0
	var nearest := local.clamp(flat.position, flat.end)
	return Vector2(local.x - nearest.x, local.z - nearest.z).length()


## The free seat to get into from `at`: the driver's if it is free, else the
## one nearest to it. -1 if all are taken.
func free_seat_near(at: Vector3) -> int:
	if seats.is_empty():
		return -1
	if occupants[0] == null:
		return 0
	var best := -1
	var nearest := INF
	for i in seats.size():
		if occupants[i] != null:
			continue
		var distance := seat_frame(i).origin.distance_to(at)
		if distance < nearest:
			nearest = distance
			best = i
	return best


## The next free seat after `seat`, round the vehicle, or `seat` itself.
func next_seat(seat: int) -> int:
	for step in range(1, seats.size()):
		var other := (seat + step) % seats.size()
		if occupants[other] == null:
			return other
	return seat


## Puts `body` in seat `seat`, or the best free one. The number of the seat,
## -1 if it could not get in.
func enter(body: Node3D, seat := -1) -> int:
	if seat < 0:
		seat = free_seat_near(body.global_position)
	if seat < 0 or occupants[seat] != null or condition == Condition.WRECKED:
		return -1
	var was := occupants.find(body)
	if was >= 0:
		occupants[was] = null
	occupants[seat] = body
	add_collision_exception_with(body)
	if body is PhysicsBody3D:
		(body as PhysicsBody3D).add_collision_exception_with(self)
	if body.has_method("sit"):
		body.sit(self, seat)
	if was < 0:
		_play(data.door_sound, seat_frame_local(seat).origin, -2.0)
	if seat == 0:
		_take_the_wheel(body)
	elif was == 0:
		_leave_the_wheel(body)
	wake()
	entered.emit(body, seat)
	return seat


## Lets `body` out on the side of its seat, or wherever there is room.
func leave(body: Node3D) -> void:
	var seat := occupants.find(body)
	if seat < 0:
		return
	occupants[seat] = null
	if seat == 0:
		_leave_the_wheel(body)
	var out := _way_out(seat, body)
	remove_collision_exception_with(body)
	if body is PhysicsBody3D:
		(body as PhysicsBody3D).remove_collision_exception_with(self)
	if body.has_method("stand"):
		body.stand(out, linear_velocity * 0.5)
	_play(data.door_sound, seat_frame_local(seat).origin, -2.0)
	left.emit(body, seat)


## Who drives, if anybody.
func driver() -> Node3D:
	return occupants[0] if not occupants.is_empty() else null


func seat_of(body: Node3D) -> int:
	return occupants.find(body)


## Where seat `seat` is in the world, looking where the vehicle looks.
func seat_frame(seat: int) -> Transform3D:
	var at: Vector3 = seats[seat].at
	if seats[seat].turret and _turret:
		return _turret.global_transform * (_rests[_turret] as Transform3D).affine_inverse() * Transform3D(Basis(), at)
	return global_transform * Transform3D(Basis(), at)


func seat_frame_local(seat: int) -> Transform3D:
	return global_transform.affine_inverse() * seat_frame(seat)


## Where the eyes of whoever sits in seat `seat` are, in the world.
func eye_frame(seat: int) -> Transform3D:
	var at: Vector3 = seats[seat].eye
	if seats[seat].turret and _turret:
		return _turret.global_transform * (_rests[_turret] as Transform3D).affine_inverse() * Transform3D(Basis(), at)
	return global_transform * Transform3D(Basis(), at)


## True if a shot can reach whoever sits in seat `seat`.
func exposed(seat: int) -> bool:
	return seats[seat].exposed


func _take_the_wheel(body: Node3D) -> void:
	if not engine_on and _starting <= 0.0 and condition != Condition.WRECKED:
		_starting = data.start_time
		_play(data.start_sound, data.engine_at, 0.0)
	if body.is_in_group("player"):
		_view = VIEW.new()
		_view.name = "View"
		add_child(_view)
		_view.setup(self, body)


func _leave_the_wheel(_body: Node3D) -> void:
	ask_forward = 0.0
	ask_back = 0.0
	steering = 0.0
	if is_instance_valid(_view):
		_view.close()
	_view = null
	if engine_on or _starting > 0.0:
		_stop_engine()


func _stop_engine() -> void:
	var was := engine_on
	engine_on = false
	_starting = 0.0
	if was:
		_play(data.stop_sound, data.engine_at, -2.0)


## Where `body` gets out of seat `seat`: on its side if there is room for
## somebody to stand, else on the other side, behind or on top of it.
func _way_out(seat: int, body: Node3D) -> Transform3D:
	var out: Vector3 = seats[seat].out
	var tries: Array[Vector3] = [out, Vector3(-out.x, out.y, out.z), Vector3(0, 0, _hull.end.z + 1.0), Vector3(0, 0, _hull.position.z - 1.0), Vector3(0, _hull.end.y + 0.1, _hull.get_center().z)]
	var space := get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = WORLD
	query.exclude = [get_rid(), (body as CollisionObject3D).get_rid()] if body is CollisionObject3D else [get_rid()]
	var facing := Basis(Vector3.UP, global_rotation.y)
	for spot in tries:
		var at := global_transform * spot
		# Down onto the ground, from no higher than the vehicle.
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.5, at + Vector3.DOWN * 4.0, WORLD, [get_rid()]))
		if down:
			at = down.position
		query.transform = Transform3D(Basis(), at + Vector3.UP * 0.95)
		if space.intersect_shape(query, 1).is_empty():
			return Transform3D(facing, at)
	return Transform3D(facing, global_transform * Vector3(0, _hull.end.y + 0.1, 0))


# --- Waking and resting -------------------------------------------------------------


## Lets it move: it is frozen while it stands still with nobody in it.
func wake() -> void:
	freeze = false
	_still_for = 0.0


func _settle(delta: float) -> void:
	if driver() != null or autopilot or _starting > 0.0 or linear_velocity.length() > STILL or angular_velocity.length() > STILL:
		_still_for = 0.0
		return
	_still_for += delta
	if _still_for > SETTLES and condition != Condition.BURNING:
		freeze = true
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO


# --- Driving -------------------------------------------------------------------------


func _physics_process(delta: float) -> void:
	_clock += delta
	if condition == Condition.WRECKED:
		_lie_as_wreck(delta)
		return
	_wear(delta)
	_controls()
	_run_engine(delta)
	_lay_gun_toward(delta)
	if not freeze:
		_drive(delta)
		_crashes(delta)
		_run_over_people(delta)
		_settle(delta)
	_carry_occupants()


## What the driver asks of it, if the driver is the player on this machine.
func _controls() -> void:
	var who := driver()
	if autopilot:
		pass
	elif who == null or condition == Condition.WRECKED:
		ask_forward = 0.0
		ask_back = 0.0
		steering = 0.0
		hand_brake = who == null
	elif who.is_in_group("player"):
		var control: bool = who.has_control()
		ask_forward = Input.get_action_strength("move_forward") if control else 0.0
		ask_back = Input.get_action_strength("move_back") if control else 0.0
		steering = Input.get_axis("move_left", "move_right") if control else 0.0
		hand_brake = control and Input.is_action_pressed("jump")
	# Forward or back: what gas means depends on which way it goes. Under
	# walking pace it puts it in reverse or forward as it is asked; faster,
	# asking the other way is braking.
	gas = 0.0
	braking = 0.0
	if not engine_on:
		braking = maxf(ask_forward, ask_back)
		return
	if gear > 0:
		if ask_back > 0.0 and speed < 1.0:
			_select(-1)
		elif ask_back > 0.0:
			braking = ask_back
		gas = ask_forward
	if gear < 0:
		if ask_forward > 0.0 and speed > -1.0:
			_select(1)
			gas = ask_forward
		elif ask_forward > 0.0:
			braking = ask_forward
		else:
			gas = ask_back
	if (speed > data.top_speed and gear > 0) or (speed < -data.reverse_speed and gear < 0):
		gas = 0.0
	if ask_forward == 0.0 and ask_back == 0.0 and absf(speed) < 0.6:
		# Nobody's foot on anything at a standstill: it stays where it is.
		braking = 1.0


## Puts it in reverse or in first, straight away and without a sound.
func _select(to: int) -> void:
	if gear != to:
		gear = to
		_shifting = 0.0


## The engine: starting, how fast it turns and in which gear, and when it
## shifts.
func _run_engine(delta: float) -> void:
	if _starting > 0.0:
		_starting -= delta
		rpm = move_toward(rpm, data.idle_rpm * 0.7, data.idle_rpm * delta * 2.0)
		if _starting <= 0.0:
			engine_on = condition != Condition.WRECKED
		return
	if not engine_on:
		rpm = move_toward(rpm, 0.0, data.idle_rpm * delta * 1.5)
		return
	if _shifting > 0.0:
		_shifting -= delta
		if _shifting <= 0.0:
			gear = _shift_to
	var ratio := _ratio(gear)
	var wheels := _wheel_rpm(ratio)
	# Pulling away the clutch slips: the engine revs to where it pulls, and
	# the wheels catch up. Shifting, it falls to where the next gear has it.
	var target := maxf(wheels, data.idle_rpm)
	if _shifting > 0.0:
		target = maxf(_wheel_rpm(_ratio(_shift_to)), data.idle_rpm)
	elif wheels < data.idle_rpm * 1.6:
		target = maxf(target, lerpf(data.idle_rpm, data.max_rpm * 0.5, gas))
	# Off the ground the wheels are free and the engine runs away with them.
	if _touching() == 0:
		target = lerpf(data.idle_rpm, data.max_rpm, gas)
	var follow := 9.0 if target > rpm else 5.0
	rpm = minf(lerpf(rpm, target, 1.0 - exp(-follow * delta)), data.max_rpm * 1.03)
	if gear > 0 and _shifting <= 0.0 and _touching() > 0:
		if wheels > data.shift_up * data.max_rpm and gear < data.gears.size():
			_shift(gear + 1)
		elif gear > 1 and wheels < data.shift_down * data.max_rpm and _wheel_rpm(_ratio(gear - 1)) < data.shift_up * data.max_rpm * 0.9:
			_shift(gear - 1)


func _shift(to: int) -> void:
	_shifting = data.shift_time
	_shift_to = to
	_play(data.shift_sound, data.engine_at, -6.0)
	shifted.emit(to)


## The ratio from the engine to the wheels in gear `which`.
func _ratio(which: int) -> float:
	if which < 0:
		return data.reverse * data.final_drive
	if which == 0 or which > data.gears.size():
		return 0.0
	return data.gears[which - 1] * data.final_drive


## How fast the engine turns if it turns with the wheels through `ratio`.
func _wheel_rpm(ratio: float) -> float:
	return absf(speed) / _drive_radius * ratio * 60.0 / TAU


## What the engine gives at `at` rpm, as a share of its most.
func _curve(at: float) -> float:
	if at <= data.peak_rpm:
		return lerpf(0.65, 1.0, clampf((at - data.idle_rpm) / maxf(data.peak_rpm - data.idle_rpm, 1.0), 0.0, 1.0))
	if at >= data.max_rpm:
		return 0.0
	return lerpf(1.0, 0.72, (at - data.peak_rpm) / (data.max_rpm - data.peak_rpm))


## What the engine pushes it along with, in newtons, at the wheels.
func _push() -> float:
	if not engine_on or _shifting > 0.0 or _misfire > 0.0:
		return 0.0
	var power := 0.55 if condition == Condition.DAMAGED else (0.35 if condition == Condition.BURNING else 1.0)
	var force := data.torque * _curve(rpm) * gas * _ratio(gear) * data.efficiency / _drive_radius * power
	return force if gear > 0 else -force


func _touching() -> int:
	var count := 0
	for wheel in _wheels:
		if wheel.touching:
			count += 1
	return count


func _drive(delta: float) -> void:
	var xf := global_transform
	var up := xf.basis.y.normalized()
	var ahead := -xf.basis.z.normalized()
	speed = linear_velocity.dot(ahead)
	var space := get_world_3d().direct_space_state
	var middle := xf * center_of_mass
	var share := mass / maxf(_wheels.size(), 1)
	var weight := (1.0 + data.weight) * GRAVITY
	var stiff := share * pow(TAU * data.spring_hz, 2.0)
	var damper := 2.0 * data.damping * sqrt(stiff * share)
	apply_central_force(Vector3.DOWN * data.weight * GRAVITY * mass)
	# The air, which only matters at speed.
	apply_central_force(-linear_velocity * linear_velocity.length() * data.drag)
	var turn := deg_to_rad(data.steer_deg) * lerpf(1.0, data.steer_at_speed, clampf(absf(speed) / data.top_speed, 0.0, 1.0))
	var steer_to := 0.0 if data.tracked else steering * turn
	_steer = move_toward(_steer, steer_to, deg_to_rad(data.steer_deg) / data.steer_time * delta)
	for wheel in _wheels:
		var top := xf * (wheel.at + Vector3.UP * data.travel)
		var reach := 2.0 * data.travel + wheel.radius
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top - up * reach, WORLD, [get_rid()]))
		wheel.was_pressed = wheel.pressed
		wheel.touching = not hit.is_empty()
		if not wheel.touching:
			wheel.pressed = 0.0
			wheel.load = 0.0
			continue
		wheel.point = hit.position
		wheel.normal = hit.normal
		wheel.pressed = clampf(2.0 * data.travel - (top.distance_to(hit.position) - wheel.radius), 0.0, 2.0 * data.travel)
		if Engine.get_physics_frames() % 15 == 0:
			wheel.surface = Fx.surface_of(hit)
	# The springs, with the bar between those of an axle.
	for wheel in _wheels:
		if not wheel.touching:
			continue
		var bar := 0.0
		for other in _wheels:
			if other != wheel and absf(other.at.z - wheel.at.z) < 0.05 and other.side != wheel.side:
				bar = (wheel.pressed - other.pressed) * stiff * data.anti_roll
		var rate := (wheel.pressed - wheel.was_pressed) / delta
		wheel.load = maxf(share * weight + stiff * (wheel.pressed - data.travel) + damper * rate + bar, 0.0)
		apply_force(up * wheel.load, wheel.point - xf.origin)
	# The tyres or the tracks.
	var push := _push()
	var touching := _touching()
	for wheel in _wheels:
		if not wheel.touching:
			wheel.spin = lerpf(wheel.spin, gas * 30.0 * signf(float(gear)), 1.0 - exp(-2.0 * delta)) if wheel.drives else wheel.spin * exp(-delta)
			continue
		var heading := ahead.rotated(up, -_steer) if wheel.steers else ahead
		var along := (heading - wheel.normal * heading.dot(wheel.normal)).normalized()
		var across := along.cross(wheel.normal)
		var at := wheel.point - middle
		var velocity := linear_velocity + angular_velocity.cross(at)
		# A track does not hold against the vehicle turning, along or across:
		# that is up to the tracks being driven apart, below.
		var forward := linear_velocity.dot(along) if data.tracked else velocity.dot(along)
		var sideways := linear_velocity.dot(across) if data.tracked else velocity.dot(across)
		var grip := data.grip * _surface_grip(wheel.surface) * wheel.load
		var rear := not wheel.steers
		var holds := grip * (data.drift_grip if hand_brake and rear and not data.tracked else 1.0)
		var side_force := clampf(-sideways * share / delta * data.bite, -holds, holds)
		var long_force := 0.0
		if wheel.drives and _driven > 0:
			long_force += push / _driven
		var stop := braking * data.brake
		if hand_brake and (rear or data.tracked):
			stop = maxf(stop, 1.0)
		if stop > 0.0:
			long_force -= signf(forward) * minf(stop * grip, absf(forward) * share / delta * 0.5)
		long_force -= signf(forward) * minf(data.rolling * wheel.load, absf(forward) * share / delta * 0.5)
		var total := Vector2(long_force, side_force)
		wheel.slip = 0.0
		if total.length() > grip and grip > 0.0:
			wheel.slip = clampf(total.length() / grip - 1.0, 0.0, 1.0)
			total = total.normalized() * grip
		apply_force(along * total.x + across * total.y, wheel.point - xf.origin)
		wheel.spin = forward / wheel.radius
		if wheel.drives and absf(push) > 0.0 and wheel.slip > 0.0:
			wheel.spin += signf(push) * wheel.slip * 25.0
		elif stop >= 1.0 and wheel.slip > 0.0:
			wheel.spin = 0.0
	# Braked hard from speed, it is heard as it stops: brakes that squeal,
	# or the air let out of them.
	if braking > 0.5 and absf(speed) > 5.0:
		_braked_hard = true
	elif _braked_hard and absf(speed) < 0.8:
		_braked_hard = false
		_play(data.brake_sound, Vector3.ZERO, -4.0)
	if touching == 0:
		return
	var yaw := angular_velocity.dot(up)
	var heft := _inertia()
	if data.tracked:
		# The tracks driven apart turn it: as fast as asked at a standstill,
		# less so at speed, and the other way round going backwards, as a
		# car does.
		var rate := deg_to_rad(lerpf(data.turn_rate, data.turn_at_speed, clampf(absf(speed) / data.top_speed, 0.0, 1.0)))
		var wanted := -steering * rate * (-1.0 if speed < -0.5 else 1.0) if engine_on else 0.0
		var power := 0.5 if condition != Condition.SOUND else 1.0
		apply_torque(up * (wanted - yaw) * heft.y * 5.0 * power * float(touching) / _wheels.size())
	elif absf(yaw) > YAW_LIMIT and not hand_brake:
		apply_torque(-up * signf(yaw) * (absf(yaw) - YAW_LIMIT) * heft.y * 8.0)
	# It rights itself if it lies on its side or its roof.
	if up.y < 0.35 and linear_velocity.length() < 2.5:
		_over_for += delta
	else:
		_over_for = 0.0


## How hard it is to turn about each of its axes.
func _inertia() -> Vector3:
	var state := PhysicsServer3D.body_get_direct_state(get_rid())
	if state == null:
		return Vector3.ONE * mass
	var inverse: Vector3 = state.inverse_inertia
	return Vector3(1.0 / maxf(inverse.x, 1e-6), 1.0 / maxf(inverse.y, 1e-6), 1.0 / maxf(inverse.z, 1e-6))


## How well tyres hold on `surface`, against dry ground.
func _surface_grip(surface: String) -> float:
	match surface:
		"sand":
			return 0.85
		"metal":
			return 0.8
		"wood":
			return 0.9
	return 1.0


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _over_for > RIGHTS_AFTER:
		var up := state.transform.basis.y.normalized()
		var axis := up.cross(Vector3.UP)
		if axis.length() < 0.01:
			axis = state.transform.basis.z
		state.angular_velocity = state.angular_velocity.lerp(axis.normalized() * RIGHTING, 0.08)
		state.linear_velocity += Vector3.UP * GRAVITY * 0.9 * state.step
	if absf(state.transform.basis.y.y) > 0.9:
		_over_for = 0.0


## A bump: what it ran into is heard, and hurts it if it was hard. What it
## ran into that can break, it breaks.
func _crashes(delta: float) -> void:
	_bumped -= delta
	var change := (linear_velocity - _last_velocity).length()
	_last_velocity = linear_velocity
	if change > BUMP and _bumped <= 0.0:
		_bumped = BUMP_GAP
		_play(data.crash_sound, _hull.get_center(), clampf(-14.0 + change * 1.6, -14.0, 6.0))
		if change > data.crash_from:
			_hurt((change - data.crash_from) * data.crash_damage, global_transform * _hull.get_center())
			for i in occupants.size():
				# A hard crash shakes whoever is in it.
				if occupants[i] and occupants[i].has_method("shake"):
					occupants[i].shake(clampf(change / 20.0, 0.1, 0.8))
	if linear_velocity.length() < 3.0:
		return
	for body in get_colliding_bodies():
		if body.is_in_group("vehicle"):
			body.wake()
		elif body.has_method("take_damage") and not _run_over.has(body):
			_run_over[body] = _clock
			body.take_damage(linear_velocity.length() * 12.0, body.global_position, linear_velocity.normalized())


## Whoever stands in its way as it comes at speed is run down.
func _run_over_people(_delta: float) -> void:
	for body: Object in _run_over.keys():
		if not is_instance_valid(body) or _clock - float(_run_over[body]) > RUN_OVER_AGAIN:
			_run_over.erase(body)
	var fast := linear_velocity.length()
	if fast < data.run_over_from:
		return
	var box := BoxShape3D.new()
	box.size = _hull.size + Vector3(0.3, 0.2, 0.3)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = global_transform * Transform3D(Basis(), _hull.get_center())
	query.transform.origin += linear_velocity * 0.06
	query.collision_mask = PEOPLE
	var skip: Array[RID] = [get_rid()]
	for body in occupants:
		if body is CollisionObject3D:
			skip.append((body as CollisionObject3D).get_rid())
	query.exclude = skip
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 8):
		var body: Object = hit.collider
		if _run_over.has(body) or not body.has_method("take_damage"):
			continue
		_run_over[body] = _clock
		var harm := remap(fast, data.run_over_from, data.run_over_kills, 25.0, 160.0)
		var at: Vector3 = (body as Node3D).global_position + Vector3.UP
		var away := (linear_velocity.normalized() + Vector3.UP * 0.35).normalized()
		var who := driver()
		if Match.active and who:
			Match.hit(who, body, harm, at, away)
		else:
			Net.damage(body, harm, at, away)
		if body.has_method("shove"):
			body.shove(away * fast * 0.7)
		elif body is CharacterBody3D:
			(body as CharacterBody3D).velocity += away * fast * 0.7
		Sfx.play_at(&"impact_flesh", at, 2.0)
		_play(data.crash_sound, _hull.get_center(), -8.0)


func _carry_occupants() -> void:
	for i in occupants.size():
		var body := occupants[i]
		if body == null:
			continue
		if not is_instance_valid(body):
			occupants[i] = null
			continue
		if body.has_method("ride"):
			body.ride(seat_frame(i))


# --- The gun -------------------------------------------------------------------------


## The way the gun points in the world.
func _gun_direction() -> Vector3:
	if _muzzle:
		return -_muzzle.global_basis.z.normalized()
	return -global_basis.z.normalized()


## Where the muzzle is, and the way it points.
func muzzle() -> Transform3D:
	return _muzzle.global_transform if _muzzle else global_transform


## Turns the turret and lifts the gun towards `aim`, as fast as they go.
func _lay_gun_toward(delta: float) -> void:
	_turret_moving = 0.0
	if not data.has_turret or _turret == null:
		return
	loaded = minf(loaded + delta / data.reload_time, 1.0) if loaded < 1.0 else 1.0
	if loaded >= 1.0 and loaded - delta / data.reload_time < 1.0:
		pass
	if aim == Vector3.ZERO or condition == Condition.WRECKED:
		return
	var local := (global_basis.inverse() * aim).normalized()
	var wanted := atan2(-local.x, -local.z)
	var before := turret_yaw
	var rate := deg_to_rad(data.turret_rate) * (0.5 if condition != Condition.SOUND else 1.0)
	turret_yaw = rotate_toward(turret_yaw, wanted, rate * delta)
	var level := Basis(Vector3.UP, turret_yaw).inverse() * local
	var lift := clampf(atan2(level.y, Vector2(level.x, level.z).length()), -deg_to_rad(data.gun_depression), deg_to_rad(data.gun_elevation))
	gun_pitch = move_toward(gun_pitch, lift, deg_to_rad(data.gun_rate) * delta)
	_turret_moving = absf(angle_difference(before, turret_yaw)) / maxf(rate * delta, 1e-6)
	_lay_gun()


func _lay_gun() -> void:
	if _turret:
		_turret.transform = (_rests[_turret] as Transform3D) * Transform3D(Basis(Vector3.UP, turret_yaw), Vector3.ZERO)
	if _gun:
		_gun.transform = (_rests[_gun] as Transform3D) * Transform3D(Basis(Vector3.RIGHT, gun_pitch), Vector3.ZERO)
	for turning: Array in _turning_shapes:
		var shape: CollisionShape3D = turning[0]
		var with: Node3D = turning[2]
		shape.transform = global_transform.affine_inverse() * with.global_transform * (turning[1] as Transform3D)


## How fast the turret turns now, as a share of how fast it can.
func turret_moving() -> float:
	return _turret_moving


## Fires the gun if it is loaded. True if it did.
func fire() -> bool:
	if not data.has_turret or _muzzle == null or loaded < 1.0 or condition == Condition.WRECKED:
		return false
	loaded = 0.0
	var from := _muzzle.global_transform
	var way := -from.basis.z.normalized()
	var shell: Node3D = SHELL.new()
	shell.velocity = way * data.shell_speed + linear_velocity
	shell.shooter = driver() as CollisionObject3D
	shell.thrower = Match.number(driver()) if Match.active else 0
	shell.direct = data.shell_hit
	shell.radius = data.shell_radius
	shell.damage = data.shell_damage
	shell.size = data.shell_size
	shell.skip = get_rid()
	get_tree().current_scene.add_child(shell)
	shell.global_position = from.origin + way * 0.3
	Fx.muzzle_flash(_muzzle, Transform3D(), 2.2, 4, Color(1.0, 0.6, 0.25), 6.0)
	Fx.gun_smoke(from.origin, way, 1.0)
	Fx.gun_smoke(from.origin + way * 0.6, Vector3.UP, 1.0)
	if Sfx.has(data.cannon_sound):
		Sfx.play_at(data.cannon_sound, from.origin, 6.0)
	_bumped = BUMP_GAP
	apply_impulse(-way * mass * 0.35, from.origin - global_position)
	var who := driver()
	if who and who.has_method("shake"):
		who.shake(0.45)
	if who and Match.active:
		Match.fired(who, from.origin, 120.0)
	get_tree().create_timer(data.reload_time - 0.5).timeout.connect(func() -> void:
		if is_inside_tree() and condition != Condition.WRECKED:
			_play(data.load_sound, _hull.get_center(), -4.0))
	return true


# --- Wearing down ---------------------------------------------------------------------


## Somebody who plays had a hand in what is about to hurt it.
func struck_by(who: int) -> void:
	if who != 0:
		last_hurt_by = who


## A shot, a shell or a rocket: see heavy_hit.
func take_damage(amount: float, at := Vector3.ZERO, _direction := Vector3.ZERO) -> bool:
	if condition == Condition.WRECKED:
		return false
	var share := 1.0 if amount >= data.heavy_hit else data.bullet_share
	_hurt(amount * share, at)
	return false


## A blast: hurt by it, and thrown, the less the heavier it is. A field car
## next to a rocket goes up on two wheels; a tank rocks.
func take_blast(amount: float, at: Vector3, push: Vector3) -> void:
	wake()
	_bumped = BUMP_GAP
	var thrown := THROWN * minf(amount, 150.0) / 150.0 * pow(1200.0 / mass, 0.7)
	apply_impulse(push.normalized() * mass * thrown, at - global_position)
	if condition != Condition.WRECKED:
		_hurt(amount * data.blast_share, at)


func _hurt(amount: float, _at: Vector3) -> void:
	if amount <= 0.0 or condition == Condition.WRECKED:
		return
	health -= amount
	wake()
	var share := health / data.health
	var now := condition
	if health <= 0.0:
		_go_up()
		return
	if share < data.burning:
		now = Condition.BURNING
	elif share < data.damaged:
		now = Condition.DAMAGED
	if now > condition:
		condition = now
		if now == Condition.BURNING:
			_catch_fire()


## The engine of one that is hit misfires; one that is alight burns down.
func _wear(delta: float) -> void:
	_misfire = maxf(_misfire - delta, 0.0)
	if condition == Condition.SOUND:
		return
	_puff -= delta
	var engine := global_transform * data.engine_at
	if _puff <= 0.0:
		_puff = PUFF * (0.6 if condition == Condition.BURNING else 1.0)
		Fx.gun_smoke(engine, (Vector3.UP * 2.0 - linear_velocity * 0.15).normalized(), 1.0)
	if engine_on:
		_misfire_in -= delta
		if _misfire_in <= 0.0:
			_misfire = MISFIRE
			_misfire_in = randf_range(MISFIRES.x, MISFIRES.y) * (0.5 if condition == Condition.BURNING else 1.0)
			_sound.misfire()
	if condition == Condition.BURNING:
		_feed_fire()
		_hurt(data.health * data.burn_rate * delta, engine)


func _catch_fire() -> void:
	var at := global_transform * Transform3D(Basis(), data.engine_at - Vector3.UP * 0.3)
	_flames = Fx.blaze(at, Vector3(0.9, 0.5, 0.9), 600.0)
	_fire = Blast.kindle(at.origin, 1.2, 1.5, 600.0)


func _feed_fire() -> void:
	var at := global_transform * Transform3D(Basis(), data.engine_at - Vector3.UP * 0.3)
	var size := Vector3(0.9, 0.5, 0.9) if condition == Condition.BURNING else _hull.size * Vector3(0.9, 0.6, 0.9)
	if condition == Condition.WRECKED:
		at = global_transform * Transform3D(Basis(), Vector3(0, _hull.position.y, _hull.get_center().z))
	Fx.feed(_flames, at, size, _burns_for if condition == Condition.WRECKED else 600.0)
	if not _fire.is_empty():
		_fire.at = at.origin


## It goes up: a blast, whoever is in it does not get out alive, and what is
## left is a wreck that burns.
func _go_up() -> void:
	health = 0.0
	condition = Condition.WRECKED
	engine_on = false
	_starting = 0.0
	var middle := global_transform * _hull.get_center()
	for i in occupants.size():
		var body := occupants[i]
		if body == null:
			continue
		leave(body)
		if Match.active and Match.plays(body):
			Match.harm(Match.number(body), 1000.0, body.global_position, Vector3.UP, last_hurt_by, Match.BLAST)
		elif body.has_method("take_damage"):
			body.take_damage(1000.0, body.global_position, Vector3.UP)
	Blast.explode(middle, data.blast_radius, data.blast_damage, data.blast_size, self, last_hurt_by)
	if Sfx.has(data.explode_sound):
		Sfx.play_at(data.explode_sound, middle, 8.0)
	freeze = false
	_bumped = 1.0
	_belly()
	apply_central_impulse(Vector3.UP * mass * randf_range(3.0, 4.5))
	apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-0.4, 0.4), randf_range(-1, 1)) * _inertia() * 1.2)
	_char()
	if _flames == null:
		_flames = Fx.blaze(global_transform, _hull.size, WRECK_BURNS)
		_fire = Blast.kindle(middle, 1.6, 2.0, WRECK_BURNS)
	_burns_for = WRECK_BURNS
	if is_instance_valid(_view):
		_view.close()
	_view = null
	if Match.active:
		_comes_back = COMES_BACK
	went_up.emit()


## Everything of it black and burnt: the paint gone, the canvas, the glass
## and what is stencilled on it burnt away.
func _char() -> void:
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.045, 0.04, 0.037)
	black.roughness = 1.0
	var gone := _gone()
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(i)
			var stem := material.resource_path.get_file().get_basename() if material else ""
			if stem in BURNS_AWAY:
				mesh.set_surface_override_material(i, gone)
			elif material is ShaderMaterial and (material as ShaderMaterial).shader.resource_path.contains("field_paint"):
				var burnt := material.duplicate() as ShaderMaterial
				burnt.set_shader_parameter(&"paint", Color(0.05, 0.045, 0.04))
				burnt.set_shader_parameter(&"rust", 0.55)
				burnt.set_shader_parameter(&"dust", 0.15)
				mesh.set_surface_override_material(i, burnt)
			else:
				mesh.set_surface_override_material(i, black)


## A wreck that lost its wheels lies on what is left of them: a box under it
## down to where the tyres were.
func _belly() -> void:
	if _wheels.is_empty():
		return
	var low := INF
	var box := AABB(_wheels[0].at, Vector3.ZERO)
	for wheel in _wheels:
		box = box.expand(wheel.at)
		low = minf(low, wheel.at.y - wheel.radius * 0.8)
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = Vector3(box.size.x + 0.3, maxf(_hull.position.y - low, 0.1), box.size.z + 0.6)
	shape.shape = cube
	shape.position = Vector3(box.get_center().x, low + cube.size.y * 0.5, box.get_center().z)
	shape.set_meta(&"surface", "metal")
	add_child(shape)


## Plays `sound` from `at` on the vehicle, if it has one.
func _play(sound: StringName, at: Vector3, db: float) -> void:
	if sound != &"" and Sfx.has(sound):
		Sfx.play_on(sound, self, at, db)


## What is drawn of what burnt away: nothing.
static func _gone() -> Material:
	var nothing := StandardMaterial3D.new()
	nothing.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nothing.albedo_color = Color(0, 0, 0, 0)
	return nothing


func _lie_as_wreck(delta: float) -> void:
	_burns_for = maxf(_burns_for - delta, 0.0)
	if is_instance_valid(_flames):
		_feed_fire()
	if _comes_back > 0.0:
		_comes_back -= delta
		if _comes_back <= 0.0:
			_come_back()


## A new one where the first stood, as long as nothing stands in the way of
## it: the wreck makes way.
func _come_back() -> void:
	var space := get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = _hull.size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = spawn * Transform3D(Basis(), _hull.get_center())
	query.collision_mask = PEOPLE | VEHICLE
	query.exclude = [get_rid()]
	if not space.intersect_shape(query, 1).is_empty():
		_comes_back = 5.0
		return
	var fresh: Node3D = _pristine
	_pristine = null
	get_parent().add_child(fresh)
	fresh.global_transform = spawn
	if is_instance_valid(_flames):
		_flames.queue_free()
	if not _fire.is_empty():
		_fire.left = 0.0
	queue_free()


# --- What is seen and heard as it goes ---------------------------------------------


func _process(delta: float) -> void:
	if condition != Condition.WRECKED:
		_turn_wheels(delta)
	_sound.listen(delta)


## The wheels turn as fast as they roll, the front ones steer, and each hangs
## as far down as its spring lets it; the steering wheel turns with them.
func _turn_wheels(delta: float) -> void:
	var axles := {}
	for wheel in _wheels:
		wheel.turned = fposmod(wheel.turned - wheel.spin * delta, TAU)
		if not axles.has(wheel.part):
			axles[wheel.part] = []
		axles[wheel.part].append(wheel)
	for part: String in axles:
		var node := _model.find_child(part, true, false) as Node3D
		if node == null or not _rests.has(node):
			continue
		var on: Array = axles[part]
		var drop := 0.0
		var tilt := 0.0
		for wheel: Wheel in on:
			drop += (wheel.pressed - data.travel) if wheel.touching else -data.travel
		drop /= on.size()
		if on.size() == 2:
			# An axle with a wheel either side: it tilts as one side rises.
			var left: Wheel = on[0] if on[0].side < 0.0 else on[1]
			var right: Wheel = on[1] if on[0].side < 0.0 else on[0]
			tilt = atan2((right.pressed if right.touching else 0.0) - (left.pressed if left.touching else 0.0), absf(right.at.x - left.at.x))
		var steer := Basis(Vector3.UP, -_steer) if (on[0] as Wheel).steers else Basis()
		var rest: Transform3D = _rests[node]
		node.transform = Transform3D(rest.basis * steer * Basis(Vector3.FORWARD, tilt) * Basis(Vector3.RIGHT, (on[0] as Wheel).turned), rest.origin + Vector3.UP * drop * 0.8)
	if _steering_wheel:
		_steering_wheel.transform = (_rests[_steering_wheel] as Transform3D) * Transform3D(Basis(Vector3.UP, _steer * 9.0), Vector3.ZERO)


## How fast its wheels go round, for the sound: the average of those that
## drive, in m/s at the tyre.
func rolling() -> float:
	return absf(speed)


## How hard it skids: 0 nothing, 1 a wheel that is locked or spins away.
func skidding() -> float:
	var most := 0.0
	for wheel in _wheels:
		if wheel.touching:
			most = maxf(most, wheel.slip)
	return most


## True while the engine starts.
func starting() -> bool:
	return _starting > 0.0


## True while it shifts.
func shifting() -> bool:
	return _shifting > 0.0


## True for a moment while the engine misfires.
func misfiring() -> bool:
	return _misfire > 0.0


## The camera of whoever drives it, if that is this machine's player.
func view() -> Node3D:
	return _view


## The middle of what of it is in the way, in its own coordinates.
func middle() -> Vector3:
	return _hull.get_center()


## Where the one who lays the gun looks from: beside it, turning and lifting
## with it.
func sight() -> Transform3D:
	if _gun:
		return _gun.global_transform * Transform3D(Basis(), SIGHT_AT)
	return eye_frame(0)


## True while it burns: alight, or a wreck that has not burnt out.
func burning() -> bool:
	return condition == Condition.BURNING or (condition == Condition.WRECKED and _burns_for > 0.0)


func _exit_tree() -> void:
	if is_instance_valid(_flames):
		_flames.queue_free()
	if not _fire.is_empty():
		_fire.left = 0.0
	if _pristine and not _pristine.is_inside_tree():
		_pristine.free()
