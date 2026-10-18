extends SceneTree
## The headless test of what can be driven (scripts/vehicle.gd), see
## tools/test_vehicles.sh. On a floor of its own, with a wall to drive into
## and somebody to run over, the player gets into each kind of vehicle and
## drives it with the keys, as somebody playing would: it starts, pulls away,
## shifts up, steers, brakes, reverses and lets the player out. The tank turns
## on the spot and fires. Then they are worn down to a wreck. Last the dunes
## are loaded, where every vehicle has to stand on its wheels.
##
##   tools/test_vehicles.sh             all of it
##   tools/test_vehicles.sh --only=jeep one part: jeep, truck, tank, wear, dunes

const LIMIT := 420.0
## Loaded once the game runs, not as this is read: the autoloads they name
## are not there yet then.
const PLAYER := "res://scenes/player.tscn"
const VEHICLE := "res://scripts/vehicle.gd"
const DUNES := "res://scenes/dunes.tscn"
## Where the wall stands, along +Z from the start, and how long the floor is.
const WALL_AT := 160.0
const FLOOR := 400.0

var passed := 0
var failed := 0
var player: CharacterBody3D
var world: Node3D
var _shifts := 0
var _vehicle_script: GDScript


func _initialize() -> void:
	create_timer(LIMIT, true, false, true).timeout.connect(
		func() -> void:
			print("VEHICLE TEST FAILED (timed out)")
			quit(1)
	)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_vehicle_script = load(VEHICLE)
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
	for part: String in ["jeep", "truck", "tank", "wear", "run_over", "dunes"]:
		if only == "" or only == part:
			print("-- ", part)
			await call("_" + part)
	print("%d of %d checks passed" % [passed, passed + failed])
	var bad := failed > 0 or passed == 0
	print("VEHICLE TEST FAILED" if bad else "VEHICLE TEST PASSED")
	quit(1 if bad else 0)


func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("  ok      " if ok else "  FAILED  ", title)


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func seconds(time: float) -> void:
	await frames(int(time * Engine.physics_ticks_per_second))


## A floor of FLOOR metres, a wall across it at WALL_AT, the player, and a
## vehicle of `kind` at the start, its nose along +Z.
func _yard(kind: String) -> RigidBody3D:
	if world:
		world.queue_free()
		await process_frame
	Input.action_release("move_forward")
	Input.action_release("move_back")
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")
	world = Node3D.new()
	world.name = "Yard"
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(FLOOR, 1.0, FLOOR)
	floor_shape.shape = slab
	floor_shape.position = Vector3(0, -0.5, FLOOR * 0.5 - 20.0)
	floor_body.add_child(floor_shape)
	var wall := CollisionShape3D.new()
	var block := BoxShape3D.new()
	block.size = Vector3(40.0, 4.0, 2.0)
	wall.shape = block
	wall.position = Vector3(0, 2.0, WALL_AT)
	floor_body.add_child(wall)
	world.add_child(floor_body)
	player = (load(PLAYER) as PackedScene).instantiate()
	world.add_child(player)
	player.force_control = true
	player.global_position = Vector3(-3.0, 0.0, 0.0)
	var vehicle: RigidBody3D = RigidBody3D.new()
	vehicle.set_script(_vehicle_script)
	vehicle.set("kind", kind)
	vehicle.name = kind.to_pascal_case()
	# The nose of a model is along -Z: turned round, it looks down the floor.
	vehicle.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.05, 0))
	world.add_child(vehicle)
	_shifts = 0
	vehicle.shifted.connect(func(to: int) -> void:
		if to > 1:
			_shifts += 1)
	await seconds(1.5)
	return vehicle


func _hold(action: String, time: float) -> void:
	Input.action_press(action)
	await seconds(time)
	Input.action_release(action)


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


## What every wheeled vehicle has to do, and how fast it does it: `top` is
## the least it reaches flat out in ten seconds, in m/s.
func _drive_wheels(vehicle: RigidBody3D, title: String, top: float) -> void:
	var data: VehicleData = vehicle.data
	check(vehicle.freeze, "%s: standing still with nobody in it, it is frozen" % title)
	check(absf(vehicle.global_position.y - 0.05) < 0.25, "%s: it stands on its wheels at the height of its model (%.2f m)" % [title, vehicle.global_position.y])
	check(_vehicle_script.within_reach(player).get("vehicle") == vehicle, "%s: the player beside it can get in" % title)
	await _press("use")
	check(player.riding == vehicle and player.seat == 0, "%s: E puts the player in the driver's seat" % title)
	check(vehicle.view() != null and vehicle.view().camera.current, "%s: the driver sees through the vehicle's camera" % title)
	check(not vehicle.freeze, "%s: getting in wakes it" % title)
	await seconds(data.start_time + 0.3)
	check(vehicle.engine_on, "%s: the engine has started after %.1f s" % [title, data.start_time])
	var idle: float = vehicle.rpm
	check(absf(idle - data.idle_rpm) < data.idle_rpm * 0.2, "%s: it idles at %d rpm" % [title, idle])
	var start: Vector3 = vehicle.global_position
	Input.action_press("move_forward")
	await seconds(3.0)
	var after_three: float = vehicle.speed
	for i in 7:
		await seconds(1.0)
		if OS.get_environment("DEBUG_VEHICLE") != "":
			print("    t+%d speed %.1f gear %d rpm %d push %.0f gas %.2f brake %.2f touching %d" % [i, vehicle.speed, vehicle.gear, vehicle.rpm, vehicle._push(), vehicle.gas, vehicle.braking, vehicle._touching()])
	var flat_out: float = vehicle.speed
	check(after_three > 4.0, "%s: in three seconds it does %.1f km/h" % [title, after_three * 3.6])
	check(flat_out > top, "%s: in ten it does %.1f km/h" % [title, flat_out * 3.6])
	check(_shifts >= 2, "%s: it shifted up %d times" % [title, _shifts])
	check(vehicle.rpm <= data.max_rpm * 1.05 and vehicle.rpm > data.idle_rpm, "%s: the engine turns at %d rpm, within what it can" % [title, vehicle.rpm])
	var drift := absf(vehicle.global_position.x - start.x)
	check(drift < 2.0, "%s: straight ahead it keeps straight (%.2f m off)" % [title, drift])
	# Steering right, it turns right: looking down the floor along +Z, its
	# nose goes towards -X, and it turns the way the clock does from above.
	var heading: float = vehicle.global_rotation.y
	Input.action_press("move_right")
	await seconds(1.0)
	Input.action_release("move_right")
	var turned := angle_difference(heading, vehicle.global_rotation.y)
	check(turned < -0.15, "%s: steering right turns it right (%.2f rad)" % [title, turned])
	check(absf(vehicle.global_basis.y.y) > 0.9, "%s: it stays on its wheels through the bend" % title)
	Input.action_press("move_left")
	await seconds(1.0)
	Input.action_release("move_left")
	Input.action_release("move_forward")
	# Braking.
	var fast: float = vehicle.speed
	var from: Vector3 = vehicle.global_position
	Input.action_press("move_back")
	var waited := 0.0
	while vehicle.speed > 0.3 and waited < 8.0:
		await frames(6)
		waited += 6.0 / Engine.physics_ticks_per_second
	Input.action_release("move_back")
	var stopping: float = from.distance_to(vehicle.global_position)
	check(waited < 8.0, "%s: from %.0f km/h it stops in %.1f s and %.1f m" % [title, fast * 3.6, waited, stopping])
	await seconds(0.5)
	Input.action_press("move_back")
	await seconds(2.0)
	check(vehicle.gear == -1 and vehicle.speed < -1.0, "%s: holding S at a standstill it backs (%.1f km/h)" % [title, vehicle.speed * 3.6])
	Input.action_release("move_back")
	await seconds(1.5)
	await _press("use")
	check(player.riding == null and player.camera.current, "%s: E lets the player out, back in their own eyes" % title)
	var beside: float = player.global_position.distance_to(vehicle.global_position)
	check(beside < 4.0 and player.global_position.y > -0.2 and player.global_position.y < 0.6, "%s: they stand beside it on the floor (%.1f m away)" % [title, beside])
	await seconds(0.3)
	check(not vehicle.engine_on, "%s: the engine stops once the driver is out" % title)
	await seconds(3.0)
	check(vehicle.freeze, "%s: and it is frozen again once it stands still" % title)


func _jeep() -> void:
	var jeep := await _yard("jeep")
	await _drive_wheels(jeep, "jeep", 18.0)
	# Into the wall at speed.
	player.global_position = jeep.global_position + jeep.global_basis.x * 1.6
	await _press("use")
	await seconds(1.5)
	var health: float = jeep.health
	Input.action_press("move_forward")
	var waited := 0.0
	while jeep.global_position.z < WALL_AT - 4.0 and waited < 25.0:
		await frames(12)
		waited += 0.1
	await seconds(1.0)
	Input.action_release("move_forward")
	check(jeep.health < health, "jeep: driven into a wall it is hurt (%d of %d left)" % [jeep.health, jeep.data.health])
	check(player.riding == jeep, "jeep: and whoever drives is still in it")
	# Passengers.
	await _press("vehicle_seat")
	check(player.seat == 1 and player.weapons.visible, "jeep: Q moves on to the next seat, where the weapons are out")
	check(jeep.driver() == null, "jeep: and then nobody drives")
	await _press("use")


func _truck() -> void:
	var truck := await _yard("truck")
	await _drive_wheels(truck, "truck", 14.0)


func _tank() -> void:
	var tank := await _yard("tank")
	check(absf(tank.global_position.y - 0.05) < 0.25, "tank: it stands on its tracks at the height of its model (%.2f m)" % tank.global_position.y)
	player.global_position = tank.global_position + Vector3(-2.2, 0, 0)
	await _press("use")
	check(player.riding == tank and player.seat == 0 and player.collision_layer == 0, "tank: the driver sits inside, out of reach of a shot")
	await seconds(tank.data.start_time + 0.3)
	check(tank.engine_on, "tank: the engine has started")
	# On the spot.
	var heading: float = tank.global_rotation.y
	Input.action_press("move_left")
	await seconds(2.0)
	Input.action_release("move_left")
	var turned := angle_difference(heading, tank.global_rotation.y)
	check(turned > 0.8, "tank: it turns on the spot (%.0f degrees in two seconds)" % rad_to_deg(turned))
	check(tank.global_position.distance_to(Vector3(0, tank.global_position.y, 0)) < 1.5, "tank: and stays where it was")
	Input.action_press("move_right")
	await seconds(2.0)
	Input.action_release("move_right")
	Input.action_press("move_forward")
	for i in 8:
		await seconds(1.0)
		if OS.get_environment("DEBUG_VEHICLE") != "":
			print("    t+%d speed %.1f gear %d rpm %d push %.0f yaw %.2f touching %d" % [i, tank.speed, tank.gear, tank.rpm, tank._push(), tank.angular_velocity.y, tank._touching()])
	check(tank.speed > 7.0, "tank: flat out for eight seconds it does %.0f km/h" % (tank.speed * 3.6))
	Input.action_release("move_forward")
	Input.action_press("move_back")
	await seconds(3.0)
	Input.action_release("move_back")
	await seconds(1.0)
	# The gun goes where the view is.
	var view: Node3D = tank.view()
	view.look(Vector2(-1.2, 0.0))
	await seconds(3.0)
	var wanted: Vector3 = tank.aim
	var gun: Vector3 = -tank.muzzle().basis.z
	var off := rad_to_deg(Vector2(gun.x, gun.z).angle_to(Vector2(wanted.x, wanted.z)))
	check(absf(off) < 3.0, "tank: the turret turns after the view (%.1f degrees off)" % off)
	check(tank.turret_yaw != 0.0, "tank: and is turned on the hull")
	# Fire at a dummy.
	var target := _dummy(tank.muzzle().origin - tank.muzzle().basis.z * 18.0 + Vector3.DOWN * 0.9)
	var blasts := [0]
	var counted := func(_at: Vector3) -> void: blasts[0] += 1
	autoload("Blast").exploded.connect(counted)
	Input.action_press("fire")
	await seconds(0.1)
	Input.action_release("fire")
	await seconds(1.0)
	check(blasts[0] >= 1, "tank: the gun fires a shell that goes off")
	check(target.health < 100.0, "tank: what it hits is hurt")
	check(tank.loaded < 1.0, "tank: and it has to load again")
	await seconds(tank.data.reload_time)
	check(tank.loaded >= 1.0, "tank: after %.0f s it is loaded" % tank.data.reload_time)
	autoload("Blast").exploded.disconnect(counted)
	# A rifle does next to nothing to it.
	var health: float = tank.health
	for i in 20:
		tank.take_damage(30.0, tank.global_position, Vector3.FORWARD)
	check(tank.health > health - 30.0, "tank: twenty rounds from a rifle take off %.0f of %.0f" % [health - tank.health, tank.data.health])
	await _press("use")


## Worn down by rockets: hit, alight, and gone up with somebody in it.
func _wear() -> void:
	var jeep := await _yard("jeep")
	await _press("use")
	await seconds(jeep.data.start_time + 0.3)
	jeep.take_damage(jeep.data.health * (1.0 - jeep.data.damaged) + 5.0, jeep.global_position, Vector3.FORWARD)
	check(jeep.condition == jeep.Condition.DAMAGED, "wear: hit hard, the engine is hit")
	var misfired := false
	for i in 400:
		await physics_frame
		misfired = misfired or jeep.misfiring()
	check(misfired, "wear: an engine that is hit misfires")
	jeep.take_damage(jeep.data.health * (jeep.data.damaged - jeep.data.burning) + 5.0, jeep.global_position, Vector3.FORWARD)
	check(jeep.condition == jeep.Condition.BURNING, "wear: hit harder, it is alight")
	var burning: float = jeep.health
	await seconds(2.0)
	check(jeep.health < burning, "wear: alight, it burns down by itself")
	var went_up := [false]
	jeep.went_up.connect(func() -> void: went_up[0] = true)
	player.health = 1e9
	jeep.take_damage(1000.0, jeep.global_position, Vector3.FORWARD)
	await seconds(0.5)
	check(went_up[0] and jeep.condition == jeep.Condition.WRECKED, "wear: and then it goes up")
	check(player.riding == null, "wear: whoever was in it is thrown out")
	check(player.health < 1e9, "wear: and hurt")
	check(_vehicle_script.within_reach(player).is_empty() or _vehicle_script.within_reach(player).vehicle != jeep, "wear: a wreck cannot be got into")
	await seconds(3.0)
	check(jeep.global_basis.y.y > -1.0 and jeep.global_position.y > -1.0, "wear: the wreck lies on the floor")


## Somebody in the way is run down.
func _run_over() -> void:
	var jeep := await _yard("jeep")
	var victim := _dummy(Vector3(0, 0.0, 60.0))
	await _press("use")
	await seconds(jeep.data.start_time + 0.3)
	Input.action_press("move_forward")
	var waited := 0.0
	while jeep.global_position.z < 64.0 and waited < 15.0:
		await frames(12)
		waited += 0.1
	Input.action_release("move_forward")
	check(victim.health < 100.0, "run over: somebody in its way at %.0f km/h is hurt (%.0f left)" % [jeep.speed * 3.6, victim.health])
	await _press("use")


## Every vehicle of the dunes stands on its wheels, and the one under a
## sheet in the shed is part of the level.
func _dunes() -> void:
	if world:
		world.queue_free()
		world = null
	autoload("Save").clear()
	change_scene_to_file(DUNES)
	await scene_changed
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	await seconds(4.0)
	var vehicles := get_nodes_in_group("vehicle")
	check(vehicles.size() == 22, "dunes: 22 vehicles can be driven (%d)" % vehicles.size())
	var moved := 0
	var off := 0
	for vehicle: Node in vehicles:
		var from: Vector3 = vehicle.spawn.origin
		if (vehicle as Node3D).global_position.distance_to(from) > 0.4:
			moved += 1
			print("    %s moved %.2f m" % [vehicle.name, (vehicle as Node3D).global_position.distance_to(from)])
		if (vehicle as Node3D).global_basis.y.y < 0.85:
			off += 1
	check(moved == 0, "dunes: none of them moved as the level began (%d did)" % moved)
	check(off == 0, "dunes: all of them stand upright")
	var settled := vehicles.filter(func(vehicle: Node) -> bool: return vehicle.freeze)
	check(settled.size() == vehicles.size(), "dunes: all of them are frozen, and cost nothing (%d of %d)" % [settled.size(), vehicles.size()])
	var parked := current_scene.get_node("Level/Vehicles").get_children().filter(func(node: Node) -> bool: return not node.is_in_group("vehicle"))
	check(parked.size() == 1 and String(parked[0].name).begins_with("Tank"), "dunes: the tank under the sheet in the shed is parked")
	# Woken, each settles on its wheels where it stands, on sand that is not
	# flat: a tank in its pit, a lorry on the slope of the track.
	for vehicle: Node in vehicles:
		vehicle.wake()
	await seconds(3.0)
	var shifted := 0
	for vehicle: Node in vehicles:
		var from: Vector3 = vehicle.spawn.origin
		var by: float = (vehicle as Node3D).global_position.distance_to(from)
		if by > 0.75 or (vehicle as Node3D).global_basis.y.y < 0.85:
			shifted += 1
			print("    %s woken moved %.2f m, up %.2f" % [vehicle.name, by, (vehicle as Node3D).global_basis.y.y])
	check(shifted == 0, "dunes: woken, every one of them stays where it stood (%d did not)" % shifted)
	await seconds(2.0)
	settled = vehicles.filter(func(vehicle: Node) -> bool: return vehicle.freeze)
	check(settled.size() == vehicles.size(), "dunes: and freezes again (%d of %d)" % [settled.size(), vehicles.size()])
	for vehicle: Node in vehicles:
		check(not vehicle.find_children("Load*", "MeshInstance3D", false).is_empty() or vehicle.kind == "tank", "dunes: %s carries its number" % vehicle.name)


## Somebody who stands there to be hit: on the layer of a robot, with a body
## that takes damage.
func _dummy(at: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.set_script(load("res://tools/test_dummy.gd"))
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3.UP * 0.9
	body.add_child(shape)
	body.collision_layer = 4
	body.collision_mask = 1
	world.add_child(body)
	body.global_position = at
	return body


func autoload(title: String) -> Node:
	return root.get_node(title)
