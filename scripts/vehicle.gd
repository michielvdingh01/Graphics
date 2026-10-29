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
## In a game with others the host says who sits where, and how worn it is;
## the machine whose player drives it runs it and tells the others how it
## stands. See "Over the network" below.

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
const RIDER := preload("res://scripts/rider.gd")
## The layer of the level, on which a vehicle is as well: a shot stops on
## it, a wheel stands on it and people walk into it. Its own layer says it
## is a vehicle, and is one that a blast reaches.
const WORLD := 1
const VEHICLE := 1 << 6
## What breaks or flattens as a vehicle drives into it, and the layer that
## is on: see _crush() and tools/kit/field.gd.
const CRUSHABLE := &"crushable"
const BREAKABLE := 32
## Whoever can be run over: players, robots and the two sides of a match.
const PEOPLE := 2 | 4 | (1 << 8) | (1 << 9)
const GRAVITY := 9.8
## Seconds it has to lie still with nobody in it before it is frozen, and the
## speed in m/s under which it counts as still.
const SETTLES := 1.5
const STILL := 0.12
## How much further than its sides the navmesh keeps off a vehicle, in
## metres: as far as somebody who walks it is wide.
const NAV_ROOM := 0.5
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
## A fence it runs into is heard as one: wire that rattles or wood that
## splinters, never softer than this in dB, and the thump of the vehicle 6 dB
## under it. What it touched this many seconds before a bump counts. A
## fence is what the kit builds it of: a box of metal or wood thinner than
## FENCE_THIN metres.
const FENCE_LEAST := -6.0
const FENCE_TOUCHED := 0.15
const FENCE_THIN := 0.25
const FENCES := {"metal": &"fence_crash", "wood": &"fence_crash_wood"}
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
## the front of the mantlet, where nothing of the turret is in the way.
const SIGHT_AT := Vector3(-0.32, 0.3, -0.75)
## Seconds between two puffs of smoke from an engine that is hit.
const PUFF := 0.12
## What a misfire is: how long the engine gives nothing, and how long it
## runs between two at the least and the most, in seconds.
const MISFIRE := 0.16
const MISFIRES := Vector2(0.6, 2.4)
## From how fast, in m/s, the extra weight no longer leans with the body,
## and over how much more it stops doing so: see _drive().
const LEAN_FROM := 6.0
const LEAN_SPAN := 8.0
## How far ahead of the axle and behind it a wheel that leads feels for the
## ground, as a share of its radius: see Wheel.leads.
const TYRE_EDGE := 0.8

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
## Seconds a wreck of it lies in a match before a new one stands where it
## stood.
var comes_back_after := COMES_BACK
## The machine that runs it, as Net numbers them: that of whoever drives it,
## or the host. See runs_here().
var run_by := 1

## The level whose vehicles have been rehearsed, see looks().
static var _rehearsed := {}

var _wheels: Array[Wheel] = []
var _model: Node3D
var _turret: Node3D
var _gun: Node3D
var _muzzle: Node3D
var _steering_wheel: Node3D
var _rests := {}
## What turns with the wheels: [the part, how it is at rest, its wheels].
var _axles: Array[Array] = []
## Colliders that turn with the turret or the gun, with where they are in
## the frame of what they turn with.
var _turning_shapes: Array[Array] = []
## The box around everything that is in the way, in its own coordinates.
var _hull := AABB()
var _drive_radius := 0.5
var _driven := 0
## How many wheels carry it on flat ground: those that are no guide.
var _bearing := 1
var _steer := 0.0
var _starting := 0.0
var _shifting := 0.0
var _shift_to := 1
var _still_for := 0.0
var _over_for := 0.0
var _last_velocity := Vector3.ZERO
var _bumped := 0.0
## The fence it last touched, as a sound of FENCES, where and when.
var _fence := &""
var _fence_at := Vector3.ZERO
var _fence_when := -1.0
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
## The player of this machine at the wheel, as the view from behind shows it.
var _rider: Node3D
var _pristine: Node
var _braked_hard := false
var _turret_moving := 0.0
## How it stood on the machine that runs it, as that one told it, with when:
## [seconds, state], see _how_it_stands().
var _reports: Array[Array] = []
var _since_report := 0.0


## A wheel, or the stretch of a track over one road wheel: where it hangs
## and how the ground under it is.
class Wheel:
	var part := ""
	var at := Vector3.ZERO
	var radius := 0.4
	var steers := false
	var drives := true
	var side := 1.0
	## In the first or the last row, or under a track: the ground ahead of
	## it or behind it is felt at the edge of the tyre, see _ground_under().
	var leads := false
	## It hangs clear of flat ground and carries nothing there, as the idler
	## and the sprocket of a track do; it only takes the vehicle up the face
	## of a dune or over a ledge.
	var guide := false
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
	var rows := _wheels.map(func(w: Wheel) -> float: return w.at.z)
	for w in _wheels:
		# Under a track the ground is felt along the whole of its length.
		w.leads = data.tracked or is_equal_approx(w.at.z, rows.min()) or is_equal_approx(w.at.z, rows.max())
		w.guide = w.at.y - w.radius > 0.05
	_bearing = maxi(_wheels.filter(func(w: Wheel) -> bool: return not w.guide).size(), 1)
	for part: String in ["Turret", "Gun", "Steering"]:
		var node := _model.find_child(part, true, false) as Node3D
		if node:
			_rests[node] = node.transform
	_turret = _model.find_child("Turret", true, false)
	_gun = _model.find_child("Gun", true, false)
	_muzzle = _model.find_child("Muzzle", true, false)
	_steering_wheel = _model.find_child("Steering", true, false)
	var on := {}
	for wheel in _wheels:
		if not on.has(wheel.part):
			on[wheel.part] = []
		on[wheel.part].append(wheel)
	for part: String in on:
		var node := _model.find_child(part, true, false) as Node3D
		if node:
			_axles.append([node, node.transform, on[part]])
	_make_hull()
	_keep_off_navmesh()
	# What it breaks or flattens as it drives into it, a barrier or a coil
	# of wire, does not stop it: see _crush().
	for body in get_tree().get_nodes_in_group(CRUSHABLE):
		if body is PhysicsBody3D:
			add_collision_exception_with(body)
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
	Net.changed.connect(_on_net_changed)
	if not _rehearsed.has(get_tree().current_scene):
		_rehearsed = {get_tree().current_scene: true}
		Fx.rehearse.call_deferred(looks())
	_rest()
	_last_velocity = Vector3.ZERO


## What a vehicle shows of itself only once it is used, for Fx.rehearse():
## the soldier at the wheel and the shell of a gun. Drawn for the first time
## in the middle of play, each made the renderer stop to make what it needs.
static func looks() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = RIDER.looks()
	found.append(SHELL.glow())
	return found


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
			if box.has("points"):
				var outline := ConvexPolygonShape3D.new()
				outline.points = box.points
				shape.shape = outline
			else:
				var cube := BoxShape3D.new()
				cube.size = box.size
				shape.shape = cube
				shape.position = box.at
			shape.set_meta(&"surface", "metal")
			if box.part != "":
				shape.set_meta(&"turns_with", box.part)
			add_child(shape)
	for child in get_children():
		if not child is CollisionShape3D or child.has_meta(&"turns_with"):
			continue
		var shape: Shape3D = (child as CollisionShape3D).shape
		var box := AABB()
		if shape is BoxShape3D:
			box = AABB(child.position - (shape as BoxShape3D).size * 0.5, (shape as BoxShape3D).size)
		elif shape is ConvexPolygonShape3D:
			var points := (shape as ConvexPolygonShape3D).points
			box = AABB(points[0], Vector3.ZERO)
			for point in points:
				box = box.expand(point)
			box.position += child.position
		else:
			continue
		_hull = box if _hull.size == Vector3.ZERO else _hull.merge(box)


## The navmesh is baked from the level as it loads, and a body that moves is
## no part of it: where a vehicle stands is cut out of it, as a parked one
## was. Where it goes later the robots and the bots walk round it as they
## would round anything else they bump into.
func _keep_off_navmesh() -> void:
	var obstacle := NavigationObstacle3D.new()
	obstacle.name = "Obstacle"
	obstacle.top_level = true
	var corners := PackedVector3Array()
	var room := _hull.grow(NAV_ROOM)
	for corner: Vector2 in [Vector2(room.position.x, room.position.z), Vector2(room.end.x, room.position.z), Vector2(room.end.x, room.end.z), Vector2(room.position.x, room.end.z)]:
		var at := global_basis * Vector3(corner.x, 0.0, corner.y)
		corners.append(Vector3(at.x, 0.0, at.z))
	obstacle.vertices = corners
	obstacle.height = _hull.end.y + 0.5
	obstacle.affect_navigation_mesh = true
	obstacle.carve_navigation_mesh = true
	obstacle.avoidance_enabled = false
	add_child(obstacle)
	obstacle.global_transform = Transform3D(Basis(), global_position + Vector3.DOWN * 0.5)


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
	_hand_over()
	if runs_here():
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
	_hand_over()
	left.emit(body, seat)


## Who drives, if anybody.
func driver() -> Node3D:
	if occupants.is_empty() or not is_instance_valid(occupants[0]):
		return null
	return occupants[0]


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
	if _is_mine(body):
		_view = VIEW.new()
		_view.name = "View"
		add_child(_view)
		_view.setup(self, body)
	# Whoever drives is seen at the wheel: the player of this machine while
	# its view is from behind, somebody else's always.
	if seats[0].exposed:
		_rider = RIDER.new()
		_rider.name = "Rider"
		add_child(_rider)
		_rider.position = seats[0].at
		if not _rider.setup(body, "drive"):
			_rider.queue_free()
			_rider = null


func _leave_the_wheel(_body: Node3D) -> void:
	ask_forward = 0.0
	ask_back = 0.0
	steering = 0.0
	if is_instance_valid(_view):
		_view.close()
	_view = null
	if is_instance_valid(_rider):
		_rider.queue_free()
	_rider = null
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


## Somebody came or went. Whoever came is told by the host who sits where,
## how worn it is and how it stands; whoever went is out of it.
func _on_net_changed() -> void:
	for i in occupants.size():
		if occupants[i] != null and not is_instance_valid(occupants[i]):
			occupants[i] = null
	_hand_over()
	if not Net.active or not Net.is_host():
		return
	for i in occupants.size():
		if occupants[i] != null:
			Net.tell(self, &"_seated", [_peer_of(occupants[i]), i])
	Net.tell(self, &"_wore", [health, condition])
	Net.vehicle_state(self, _how_it_stands())


## Lets it move: it is frozen while it stands still with nobody in it.
func wake() -> void:
	freeze = false
	_still_for = 0.0
	set_physics_process(true)
	set_process(true)


## Frozen where it stands: as long as nothing has happened to it, it neither
## thinks nor is heard.
func _rest() -> void:
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if condition == Condition.SOUND and not engine_on:
		set_physics_process(false)
		set_process(false)
		_sound.hush()


func _settle(delta: float) -> void:
	if driver() != null or autopilot or _starting > 0.0 or linear_velocity.length() > STILL or angular_velocity.length() > STILL:
		_still_for = 0.0
		return
	_still_for += delta
	if _still_for > SETTLES and condition != Condition.BURNING:
		_rest()


# --- Driving -------------------------------------------------------------------------


func _physics_process(delta: float) -> void:
	_clock += delta
	if not runs_here():
		# Another machine runs it: it is where that one says, and burns and
		# smokes as it should here.
		_follow()
		if condition == Condition.WRECKED:
			_lie_as_wreck(delta)
		else:
			_wear(delta)
		return
	if condition == Condition.WRECKED:
		_lie_as_wreck(delta)
		_report(delta)
		return
	_wear(delta)
	_controls()
	_run_engine(delta)
	_lay_gun_toward(delta)
	if not freeze:
		_drive(delta)
		_crashes(delta)
		_crush()
		_run_over_people(delta)
		_settle(delta)
	_carry_occupants()
	_report(delta)


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
		if wheels > data.shift_up * data.max_rpm and gear < data.gears.size() and _pulls_in(gear + 1):
			_shift(gear + 1)
		elif gear > 1 and wheels < data.shift_down * data.max_rpm and _wheel_rpm(_ratio(gear - 1)) < data.shift_up * data.max_rpm * 0.9:
			_shift(gear - 1)


## Whether gear `which` would still pull it up the slope it is on. Up a
## steep one it keeps to the gear it is in: a shift is a moment without
## power, in which it would roll back to where the lower gear was needed.
func _pulls_in(which: int) -> bool:
	var climb := mass * GRAVITY * maxf(-global_basis.z.normalized().y, 0.0)
	if climb <= 0.0:
		return true
	var at := maxf(_wheel_rpm(_ratio(which)), data.idle_rpm)
	return data.torque * _curve(at) * _ratio(which) * data.efficiency / _drive_radius > climb * 1.2


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
	var force := data.torque * _curve(rpm) * gas * _ratio(gear) * data.efficiency / _drive_radius * power * _converted()
	return force if gear > 0 else -force


## What the torque converter makes of the torque: as much as `data.stall`
## times it while the wheels turn far slower than the engine, as they do
## pulling away or crawling up a dune; once they turn with it, the torque
## itself.
func _converted() -> float:
	if rpm <= 0.0:
		return 1.0
	return lerpf(data.stall, 1.0, clampf(_wheel_rpm(_ratio(gear)) / rpm / 0.85, 0.0, 1.0))


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
	var share := mass / _bearing
	var weight := (1.0 + data.weight) * GRAVITY
	var stiff := share * pow(TAU * data.spring_hz, 2.0)
	var damper := 2.0 * data.damping * sqrt(stiff * share)
	# The extra weight that keeps it on its wheels presses it into the ground
	# under it, not down the hill: going up it would otherwise pull it back
	# as if it weighed half as much again. Fast, it presses square to its
	# length and straight down across it: leaning in a bend, it would push
	# it over.
	var into := Vector3.DOWN
	if _touching() > 0:
		var level := -(Vector3.UP - ahead * ahead.y).normalized()
		into = (-up).lerp(level, clampf((absf(speed) - LEAN_FROM) / LEAN_SPAN, 0.0, 1.0)).normalized()
	apply_central_force(into * data.weight * GRAVITY * mass)
	# The air, which only matters at speed.
	apply_central_force(-linear_velocity * linear_velocity.length() * data.drag)
	var turn := deg_to_rad(data.steer_deg) * lerpf(1.0, data.steer_at_speed, clampf(absf(speed) / data.top_speed, 0.0, 1.0))
	var steer_to := 0.0 if data.tracked else steering * turn
	_steer = move_toward(_steer, steer_to, deg_to_rad(data.steer_deg) / data.steer_time * delta)
	for wheel in _wheels:
		var hit := _ground_under(wheel, space, xf, up, ahead)
		wheel.was_pressed = wheel.pressed
		wheel.touching = not hit.is_empty()
		if not wheel.touching:
			wheel.pressed = 0.0
			wheel.load = 0.0
			continue
		wheel.point = hit.position
		wheel.normal = hit.normal
		wheel.pressed = hit.pressed
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
		if wheel.guide:
			wheel.load = maxf(stiff * wheel.pressed + damper * rate, 0.0)
		else:
			wheel.load = maxf(share * weight + stiff * (wheel.pressed - data.travel) + damper * rate + bar, 0.0)
		apply_force(up * wheel.load, wheel.point - xf.origin)
	# The tyres or the tracks. A track pulls with all of its engine wherever
	# it lies on the ground, round the idler and the sprocket as well; a
	# wheel in the air spins its share away.
	var push := _push()
	var touching := _touching()
	var pulling := _driven
	if data.tracked:
		pulling = _wheels.filter(func(w: Wheel) -> bool: return w.touching and (w.drives or w.guide)).size()
	for wheel in _wheels:
		if not wheel.touching and wheel.guide:
			# The track turns it.
			wheel.spin = speed / wheel.radius
			continue
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
		if (wheel.drives or (data.tracked and wheel.guide)) and pulling > 0:
			long_force += push / pulling
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
	if data.steady > 0.0:
		# Held upright across its length, against the ground its wheels are
		# on: a spring round its long axis, damped, as a rider holds it.
		var ground := Vector3.ZERO
		for wheel in _wheels:
			if wheel.touching:
				ground += wheel.normal
		var lean := ahead.dot(up.cross(ground.normalized()))
		var rolling_by := angular_velocity.dot(ahead)
		var spring := TAU * data.steady
		apply_torque(ahead * heft.z * (lean * spring * spring - rolling_by * 1.6 * spring))
	if data.tracked:
		# The tracks driven apart turn it: as fast as asked at a standstill,
		# less so at speed, and the other way round going backwards, as a
		# car does.
		var rate := deg_to_rad(lerpf(data.turn_rate, data.turn_at_speed, clampf(absf(speed) / data.top_speed, 0.0, 1.0)))
		var wanted := -steering * rate * (-1.0 if speed < -0.5 else 1.0) if engine_on else 0.0
		var power := 0.5 if condition != Condition.SOUND else 1.0
		apply_torque(up * (wanted - yaw) * heft.y * 5.0 * power * float(mini(touching, _bearing)) / _bearing)
	elif absf(yaw) > YAW_LIMIT and not hand_brake:
		apply_torque(-up * signf(yaw) * (absf(yaw) - YAW_LIMIT) * heft.y * 8.0)
	# It rights itself if it lies on its side or its roof.
	if up.y < 0.35 and linear_velocity.length() < 2.5:
		_over_for += delta
	else:
		_over_for = 0.0


## Where `wheel` meets the ground, as a hit of a ray with how far that
## presses its spring in, or empty if it hangs free. Under the axle, and for
## a wheel that leads also at the front and the back of the tyre: a slope
## that rises before it, the face of a dune, is met there first, and the
## wheel rides up onto it instead of the body running into it.
func _ground_under(wheel: Wheel, space: PhysicsDirectSpaceState3D, xf: Transform3D, up: Vector3, ahead: Vector3) -> Dictionary:
	var top := xf * (wheel.at + Vector3.UP * data.travel)
	var best := {}
	for edge: float in ([0.0, -TYRE_EDGE, TYRE_EDGE] if wheel.leads else [0.0]):
		# How far above the bottom of the tyre its surface is, that far along.
		var lift := wheel.radius * (1.0 - sqrt(1.0 - edge * edge))
		var from := top + ahead * edge * wheel.radius
		var reach := 2.0 * data.travel + wheel.radius - lift
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - up * reach, WORLD, [get_rid()]))
		if hit.is_empty():
			continue
		hit.pressed = clampf(reach - from.distance_to(hit.position), 0.0, 2.0 * data.travel)
		if best.is_empty() or hit.pressed > best.pressed:
			best = hit
	return best


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
	_touch_fences(state)


## Notes a fence among what it touches this step, for _crashes() to hear.
func _touch_fences(state: PhysicsDirectBodyState3D) -> void:
	for i in state.get_contact_count():
		var body := state.get_contact_collider_object(i) as CollisionObject3D
		if body == null or body.get_shape_owners().is_empty():
			continue
		var owner := body.shape_owner_get_owner(body.shape_find_owner(state.get_contact_collider_shape(i))) as CollisionShape3D
		if owner == null or not owner.shape is BoxShape3D:
			continue
		var size := (owner.shape as BoxShape3D).size
		var sound: StringName = FENCES.get(owner.get_meta(&"surface", ""), &"")
		if sound != &"" and minf(size.x, size.z) < FENCE_THIN:
			_fence = sound
			_fence_at = state.get_contact_collider_position(i)
			_fence_when = _clock


## A bump: what it ran into is heard, and hurts it if it was hard. What it
## ran into that can break, it breaks.
func _crashes(delta: float) -> void:
	_bumped -= delta
	var change := (linear_velocity - _last_velocity).length()
	_last_velocity = linear_velocity
	if change > BUMP and _bumped <= 0.0:
		_bumped = BUMP_GAP
		var db := clampf(-14.0 + change * 1.6, -14.0, 6.0)
		if _clock - _fence_when < FENCE_TOUCHED and Sfx.has(_fence):
			Sfx.play_at(_fence, _fence_at, maxf(db, FENCE_LEAST) + 2.0)
			db -= 6.0
		_play(data.crash_sound, _hull.get_center(), db)
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


## A barrier it drives into snaps off, a coil of wire it drives over lies
## flat: it goes through, a little slower for it.
func _crush() -> void:
	if linear_velocity.length() < 0.5:
		return
	var box := BoxShape3D.new()
	box.size = _hull.size + Vector3(0.2, 0.0, 0.2)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = global_transform * Transform3D(Basis(), _hull.get_center())
	query.transform.origin += linear_velocity * 0.05
	query.collision_mask = BREAKABLE
	var skip: Array[RID] = [get_rid()]
	query.exclude = skip
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 8):
		var body: Object = hit.collider
		if body is Node and (body as Node).is_in_group(CRUSHABLE) and body.has_method("run_into"):
			linear_velocity *= float(body.run_into(self, linear_velocity.length(), linear_velocity, mass))


## Whoever stands in its way as it comes at speed is run down.
func _run_over_people(_delta: float) -> void:
	# Untyped: whoever was run down may since have been taken away, and a
	# freed object put in a typed variable is a script error.
	for body: Variant in _run_over.keys():
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
		if is_instance_valid(body) and body is CollisionObject3D:
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
			Match.hit(who, body, harm, at, away, Match.RUN_OVER)
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
			_hand_over()
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
	loaded = minf(loaded + delta / data.reload_time, 1.0)
	# Nobody lays it, and it stays as it is on the hull.
	if aim == Vector3.ZERO or condition == Condition.WRECKED or (driver() == null and not autopilot):
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
	if _turret_moving > 0.0 or absf(gun_pitch - lift) > 0.0 or not freeze:
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
	Net.vehicle_did(self, &"_fired_here", [from.origin + way * 0.3, way * data.shell_speed + linear_velocity])
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
	# How worn it is, is the host's to say: what happens to it elsewhere,
	# a crash where a guest drives it, is told to the host.
	if Net.is_guest():
		Net.ask(self, &"worn_by", [amount])
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
	Net.tell(self, &"_wore", [health, condition], now == condition)


## The engine of one that is hit misfires; one that is alight burns down.
func _wear(delta: float) -> void:
	_misfire = maxf(_misfire - delta, 0.0)
	if condition == Condition.SOUND:
		return
	_puff -= delta
	var engine := global_transform * data.engine_at
	if _puff <= 0.0:
		_puff = PUFF * (0.6 if condition == Condition.BURNING else 1.0)
		Fx.engine_smoke(engine, (Vector3.UP * 2.0 - linear_velocity * 0.15).normalized(), 1.0 if condition == Condition.BURNING else 0.0)
	if engine_on:
		_misfire_in -= delta
		if _misfire_in <= 0.0:
			_misfire = MISFIRE
			_misfire_in = randf_range(MISFIRES.x, MISFIRES.y) * (0.5 if condition == Condition.BURNING else 1.0)
			_sound.misfire()
	if condition == Condition.BURNING:
		_feed_fire()
		if not Net.is_guest():
			_hurt(data.health * data.burn_rate * delta, engine)


func _catch_fire() -> void:
	var at := global_transform * Transform3D(Basis(), data.engine_at - Vector3.UP * 0.3)
	_flames = Fx.blaze(at, Vector3(0.9, 0.5, 0.9), 600.0)
	if not Net.is_guest():
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
		_comes_back = comes_back_after
	Net.tell(self, &"_went_up_here", [])
	went_up.emit()


## Everything of it black and burnt: the paint gone, and what was not steel
## charred as black as the rest.
func _char() -> void:
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.045, 0.04, 0.037)
	black.roughness = 1.0
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(i)
			var stem := material.resource_path.get_file().get_basename() if material else ""
			if material is ShaderMaterial and (material as ShaderMaterial).shader.resource_path.contains("field_paint"):
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
		if wheel.guide:
			continue
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


func _lie_as_wreck(delta: float) -> void:
	_burns_for = maxf(_burns_for - delta, 0.0)
	if is_instance_valid(_flames):
		_feed_fire()
	if _comes_back > 0.0:
		_comes_back -= delta
		if _comes_back <= 0.0 and not Net.is_guest():
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
	Net.show(self, &"_back_again", [])


## A new one in the place of the wreck, on every machine: it takes the name
## the first had, so that the machines still mean the same vehicle by it.
func _back_again() -> void:
	if _pristine == null:
		return
	var fresh: Node3D = _pristine
	_pristine = null
	var parent := get_parent()
	var own_name := name
	name = String(own_name) + "Wreck"
	fresh.name = own_name
	parent.add_child(fresh)
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
	if is_instance_valid(_rider):
		_rider.visible = not _is_mine(driver()) or (is_instance_valid(_view) and not _view.first_person)
	_sound.listen(delta)


## The wheels turn as fast as they roll, the front ones steer, and each hangs
## as far down as its spring lets it; the steering wheel turns with them.
func _turn_wheels(delta: float) -> void:
	for wheel in _wheels:
		wheel.turned = fposmod(wheel.turned - wheel.spin * delta, TAU)
	for axle: Array in _axles:
		var node: Node3D = axle[0]
		var on: Array = axle[2]
		var drop := 0.0
		var tilt := 0.0
		for wheel: Wheel in on:
			if not wheel.guide:
				drop += (wheel.pressed - data.travel) if wheel.touching else -data.travel
		drop /= on.size()
		if on.size() == 2:
			# An axle with a wheel either side: it tilts as one side rises.
			var left: Wheel = on[0] if on[0].side < 0.0 else on[1]
			var right: Wheel = on[1] if on[0].side < 0.0 else on[0]
			tilt = atan2((right.pressed if right.touching else 0.0) - (left.pressed if left.touching else 0.0), absf(right.at.x - left.at.x))
		var steer := Basis(Vector3.UP, -_steer) if (on[0] as Wheel).steers else Basis()
		var rest: Transform3D = axle[1]
		node.transform = Transform3D(rest.basis * steer * Basis(Vector3.FORWARD, tilt) * Basis(Vector3.RIGHT, (on[0] as Wheel).turned), rest.origin + Vector3.UP * drop * 0.8)
	if _steering_wheel:
		_steering_wheel.transform = (_rests[_steering_wheel] as Transform3D) * Transform3D(Basis(Vector3.UP, _steer * data.steering_turns), Vector3.ZERO)


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


## The box around what of it is in the way, in its own coordinates.
func hull() -> AABB:
	return _hull


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


# --- Over the network ------------------------------------------------------------------
# In a game with others the host says who sits where: a machine asks it for
# its own player (request_seat(), request_leave()), and it tells every
# machine (_seated(), _unseated()). It says how worn a vehicle is as well
# (_wore()), and that it went up. The machine whose player drives it runs it,
# as it runs that player, and tells the others thirty times a second how it
# stands (Net.vehicle_state()); there it follows what it is told, a moment
# behind, as a puppet follows its player. With nobody at the wheel the host
# runs it.

## Seconds between two reports of how it stands, and how far behind them
## what is shown of a vehicle another machine runs lies.
const REPORT := 1.0 / 30.0
const BEHIND := 0.1
## Seconds past the last report it carries on the way it was going.
const COASTS := 0.25


## True if this machine runs it: alone, or as the machine of its driver, or
## as the host when nobody drives it.
func runs_here() -> bool:
	return not Net.active or run_by == Net.id()


## Asks for the player of this machine, `body`, to get into `seat`, or the
## best free one.
func request_seat(body: Node3D, seat := -1) -> void:
	if seat < 0:
		seat = free_seat_near(body.global_position)
	if seat < 0:
		return
	if Net.active:
		Net.ask(self, &"seat_asked", [Net.id(), seat])
	else:
		enter(body, seat)


## Asks for the player of this machine to get out. It gets out here at once;
## the others hear it from the host.
func request_leave(body: Node3D) -> void:
	if not occupants.has(body):
		return
	leave(body)
	if Net.active:
		Net.ask(self, &"seat_left_asked", [Net.id()])


## On the host: `player` would like to sit in `seat`. Everybody is told so
## if it is free.
func seat_asked(player: int, seat: int) -> void:
	var body := Net.body(player)
	if body == null or seat < 0 or seat >= seats.size() or condition == Condition.WRECKED or occupants[seat] != null:
		return
	if body.get(&"dead") == true:
		return
	Net.show(self, &"_seated", [player, seat])


## On the host: `player` got out.
func seat_left_asked(player: int) -> void:
	Net.show(self, &"_unseated", [player])


## On the host: something that happened where another machine runs it, a
## crash, wore it down by `amount`.
func worn_by(amount: float) -> void:
	_hurt(amount, global_position)


func _seated(player: int, seat: int) -> void:
	var body := Net.body(player)
	if body:
		enter(body, seat)


func _unseated(player: int) -> void:
	var body := Net.body(player)
	if body:
		leave(body)


## How worn it is, as the host says. A machine where it was not yet alight
## sees it catch fire.
func _wore(left: float, now: int) -> void:
	health = left
	if now > condition and now != Condition.WRECKED:
		condition = now as Condition
		if now == Condition.BURNING:
			_catch_fire()


## It went up on the host: here it is a burning wreck too, and whoever was
## in it is out. What that did to them, and the blast, the host says.
func _went_up_here() -> void:
	if condition == Condition.WRECKED:
		return
	health = 0.0
	condition = Condition.WRECKED
	engine_on = false
	_starting = 0.0
	for body in occupants.duplicate():
		if body:
			leave(body)
	if Sfx.has(data.explode_sound):
		Sfx.play_at(data.explode_sound, global_transform * _hull.get_center(), 8.0)
	_char()
	if _flames == null:
		_flames = Fx.blaze(global_transform, _hull.size, WRECK_BURNS)
	_burns_for = WRECK_BURNS
	if is_instance_valid(_view):
		_view.close()
	_view = null
	went_up.emit()


## The gun was fired where another machine runs it: here the shell flies and
## the gun flashes, and does nothing, for the machine that fired it has the
## host see to what it hits.
func _fired_here(from: Vector3, going: Vector3) -> void:
	var shell: Node3D = SHELL.new()
	shell.velocity = going
	shell.harmless = true
	shell.skip = get_rid()
	get_tree().current_scene.add_child(shell)
	shell.global_position = from
	if _muzzle:
		Fx.muzzle_flash(_muzzle, Transform3D(), 2.2, 4, Color(1.0, 0.6, 0.25), 6.0)
	Fx.gun_smoke(from, going.normalized(), 1.0)
	if Sfx.has(data.cannon_sound):
		Sfx.play_at(data.cannon_sound, from, 6.0)
	loaded = 0.0


## The machine that runs it now: that of its driver, or the host. Here it
## runs as a body of its own, or follows what it is told.
func _hand_over() -> void:
	var who := driver()
	var now := _peer_of(who) if who else 1
	if now == run_by:
		return
	run_by = now
	_reports.clear()
	if runs_here():
		# It goes on from how it went where it was followed: that is no crash.
		_last_velocity = linear_velocity
		_bumped = 0.5
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		wake()
	else:
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true
		set_physics_process(true)
		set_process(true)


## The machine that `body` is the player of: the one of a puppet is the
## machine it stands for (scripts/puppet.gd).
func _peer_of(body: Variant) -> int:
	if not is_instance_valid(body):
		return 1
	if _is_mine(body):
		return Net.id()
	var id: Variant = (body as Object).get(&"id")
	return id if id is int and id > 0 else 1


## True for the player of this machine. A puppet is in the group "player"
## too, for the enemies' sake.
func _is_mine(body: Variant) -> bool:
	return is_instance_valid(body) and (body as Object).has_method("has_control")


## How it stands, for the others: where and how it is turned, how fast it
## goes and turns, its steering, its engine and its gun.
func _how_it_stands() -> Array:
	return [global_position, global_basis.get_rotation_quaternion(), linear_velocity, angular_velocity, _steer, rpm, gear, gas, braking, engine_on, speed, turret_yaw, gun_pitch]


func _report(delta: float) -> void:
	if not Net.active or Net.present.size() < 2:
		return
	_since_report += delta
	if _since_report < REPORT:
		return
	_since_report = 0.0
	Net.vehicle_state(self, _how_it_stands())


## How it stands on the machine that runs it, as that one tells: what a
## machine that does not run it follows.
func net_state(from: int, state: Array) -> void:
	if from != run_by or runs_here() or state.size() < 13:
		return
	_reports.append([Time.get_ticks_msec() * 0.001, state])
	if _reports.size() > 10:
		_reports.pop_front()
	set_physics_process(true)
	set_process(true)


## Where it is told it is, between the two reports the moment to show lies
## between, or past the last as it was going.
func _follow() -> void:
	if _reports.is_empty():
		_carry_occupants()
		return
	var now := Time.get_ticks_msec() * 0.001 - BEHIND
	var i := _reports.size() - 1
	while i > 0 and _reports[i][0] > now:
		i -= 1
	var from: Array = _reports[i][1]
	var at: Vector3 = from[0]
	var turned: Quaternion = from[1]
	if i + 1 < _reports.size():
		var to: Array = _reports[i + 1][1]
		var between := clampf(inverse_lerp(_reports[i][0], _reports[i + 1][0], now), 0.0, 1.0)
		at = at.lerp(to[0], between)
		turned = turned.slerp(to[1], between)
	else:
		at += (from[2] as Vector3) * clampf(now - _reports[i][0], 0.0, COASTS)
	global_transform = Transform3D(Basis(turned), at)
	linear_velocity = from[2]
	angular_velocity = from[3]
	_last_velocity = linear_velocity
	_steer = from[4]
	rpm = from[5]
	gear = from[6]
	gas = from[7]
	braking = from[8]
	engine_on = from[9]
	speed = from[10]
	turret_yaw = from[11]
	gun_pitch = from[12]
	_lay_gun()
	for wheel in _wheels:
		wheel.spin = speed / maxf(wheel.radius, 0.1)
		wheel.touching = true
	_carry_occupants()
