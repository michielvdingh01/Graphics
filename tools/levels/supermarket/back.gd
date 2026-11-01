extends "res://tools/levels/supermarket/plan.gd"
## Behind the shop: the stockroom with its racks, the electrical room with the
## mains of the store, the loading doors and the yard in front of them.

const SMALL := DETAIL | NO_COLLIDE
## The wall that shuts off the south end of the stockroom, and the door in it.
const ROOM_WALL := 28.0
const ROOM_DOOR := Vector2(70.0, 72.8)
## The racks: their middles on z, how far they reach on x.
const RACK_Z: Array[float] = [-39.0, -32.0, -25.0, -18.0, -11.0]
const RACK_X := Vector2(68.5, 83.0)


func _describe() -> void:
	_stockroom()
	_electrical_room()
	_yard()


func _stockroom() -> void:
	for x: float in [72.0, 80.0]:
		for z: float in [-34.0, -18.0, -2.0, 14.0]:
			tube(Vector3(x, 4.6, z), false, true, false, 12.0)
			_on_the_mains()
	for z in RACK_Z:
		_rack(z)
	shop_board("employees", Vector3(BACK - 0.14, 3.0, 3.0), Vector3.LEFT, 2.8, NAN, false)
	shop_board("employees", Vector3(BACK - 0.14, 3.0, -34.5), Vector3.LEFT, 2.8, NAN, false)
	shop_board("receiving", Vector3(REAR - 0.2, 4.0, -8.0), Vector3.LEFT, 3.6, NAN, false)
	# What was delivered and not yet put away.
	pallet_of(Vector2(72.0, 9.0), 0.0, "shipper", 2, 3, 3)
	pallet_of(Vector2(76.0, -3.0), 90.0, "shipper_cold", 2, 3, 2)
	pallet_of(Vector2(80.0, 8.0), 0.0, "shipper_fragile", 2, 2, 3)
	pallet_of(Vector2(72.0, 1.0), 0.0, "fizz_12", 3, 3, 7)
	pallet_of(Vector2(79.0, 15.0), 0.0, "spring_case", 2, 3, 5)
	pallet_of(Vector2(74.5, 21.0), 0.0, "shipper", 2, 3, 4)
	pallet_of(Vector2(81.0, 22.0), 90.0, "dogfood", 2, 2, 3)
	# Crates and boxes that came in with the last lorry.
	crates(Vector3(83.0, 0, -4.0), 3)
	crates(Vector3(84.0, 0, 12.0), 2)
	crates(Vector3(69.0, 0, 20.0), 3)
	place("hand_truck", Vector3(70.0, 0, 6.0), 40.0)
	flashlight_at(Vector3(84.6, 1.0, -30.0))
	place("WetFloorSign_01", Vector3(68.0, 0, 3.0), 10.0)


## A rack of pallets three high along x.
func _rack(z: float) -> void:
	var long := RACK_X.y - RACK_X.x
	var middle := (RACK_X.x + RACK_X.y) * 0.5
	_collide_box(Transform3D(Basis(), Vector3(middle, 2.2, z)), Vector3(long, 4.4, 1.3), "metal")
	var levels: Array[float] = [0.1, 1.6, 3.1]
	for y in levels:
		for s: float in [-0.62, 0.62]:
			box("steel_yellow", Vector3(middle, y + 0.05, z + s), Vector3(long, 0.1, 0.06), Vector3.ZERO, SMALL)
	var x := RACK_X.x
	while x <= RACK_X.y + 0.01:
		for s: float in [-0.62, 0.62]:
			box("machine_blue", Vector3(x, 2.2, z + s), Vector3(0.08, 4.4, 0.08), Vector3.ZERO, SMALL)
		x += 2.8
	var bay := RACK_X.x + 1.4
	var which := 0
	var kinds: Array[String] = ["shipper", "shipper_cold", "shipper_fragile", "fizz_12", "spring_case", "tp"]
	while bay < RACK_X.y:
		for y in levels:
			_pallet_on_rack(Vector3(bay, y + 0.1, z), kinds[which % kinds.size()])
			which += 1
		bay += 2.8
	goods_face(Vector3(middle, 2.2, z), Vector3(long, 4.4, 1.34))


func _pallet_on_rack(at: Vector3, id: String) -> void:
	box("shop_wood", at + Vector3.UP * 0.07, Vector3(1.2, 0.14, 1.0), Vector3.ZERO, SMALL)
	var size: Vector3 = CATALOG.product(id).size
	var across := int(1.1 / size.x)
	var deep := int(1.0 / size.z)
	var high := mini(int(1.0 / size.y), 3)
	for i in across:
		for j in deep:
			var under := -1
			for k in high:
				var spot := at + Vector3((i - (across - 1) * 0.5) * size.x, 0.14 + size.y * (k + 0.5), (j - (deep - 1) * 0.5) * size.z)
				under = stock(id, spot, 0.0, 0, 0.8, under)


## The room with the mains of the store, shut off from the stockroom by a wall
## with a door in it, and with a door of its own to the yard.
func _electrical_room() -> void:
	wall("shop_white", true, ROOM_WALL, 0.2, BACK, REAR, 0.0, DECK, [[ROOM_DOOR.x, ROOM_DOOR.y, 0.0, 2.4]])
	shop_board("electrical", Vector3((ROOM_DOOR.x + ROOM_DOOR.y) * 0.5, 2.85, ROOM_WALL - 0.12), Vector3.FORWARD, 2.6, NAN, false)
	# The mains of the store along the south wall.
	var at := Vector3(76.0, 0, SOUTH_WALL - 0.7)
	switchboard(Vector3(at.x, 0, at.z), 180.0, 7)
	var mains := StaticBody3D.new()
	mains.name = "Mains"
	mains.set_script(load("res://scripts/mains.gd"))
	mains.collision_layer = 33
	mains.collision_mask = 0
	mains.position = Vector3(at.x, 1.2, at.z + 0.1)
	_add(mains, _root)
	var shape := CollisionShape3D.new()
	var size := BoxShape3D.new()
	size.size = Vector3(5.6, 2.4, 0.9)
	shape.shape = size
	_add(shape, mains)
	# The rest of what hangs there: big cables up to the deck.
	for x: float in [73.0, 74.5, 76.0, 77.5, 79.0]:
		rod("dark_steel", Vector3(x, 2.1, SOUTH_WALL - 0.7), Vector3(x, DECK - 0.4, SOUTH_WALL - 0.7), 0.06, SMALL, 8)
	box("dark_steel", Vector3(76.0, DECK - 0.6, SOUTH_WALL - 0.7), Vector3(7.0, 0.3, 0.4), Vector3.ZERO, SMALL)
	place("korean_fire_extinguisher_01", Vector3(68.0, 0, SOUTH_WALL - 0.5), 0.0)
	place("metal_toolbox", Vector3(82.0, 0, SOUTH_WALL - 0.8), 30.0)
	flashlight_at(Vector3(82.0, 0.75, SOUTH_WALL - 1.4))
	tube(Vector3(76.0, 4.6, 36.0), true, true, true, 12.0)
	_on_the_mains()


## The lamp that was hung last goes out with the mains.
func _on_the_mains() -> void:
	_lights.get_child(_lights.get_child_count() - 1).add_to_group(&"mains", true)


## A long box on wheels that is nobody's in particular.
func _trailer(at: Vector2, yaw_deg: float) -> void:
	var frame := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), Vector3(at.x, 0, at.y))
	_local_box("shop_white", frame, Vector3(0, 2.5, 0), Vector3(2.6, 2.8, 13.0), DETAIL)
	_local_box("dark_steel", frame, Vector3(0, 1.0, 0), Vector3(2.0, 0.24, 12.6), SMALL)
	_local_box("shop_blue", frame, Vector3(1.31, 2.2, 0), Vector3(0.02, 0.5, 12.4), SMALL)
	_local_box("shop_blue", frame, Vector3(-1.31, 2.2, 0), Vector3(0.02, 0.5, 12.4), SMALL)
	for z: float in [4.2, 5.6]:
		for x: float in [-1.0, 1.0]:
			var wheel := frame * Vector3(x, 0.52, z)
			cylinder("rubber", wheel - frame.basis.x * x * 0.2, 0.52, 0.4, SMALL, Vector3(0, deg_to_rad(yaw_deg), 90.0 * x), -1.0, 14)
	for x: float in [-1.0, 1.0]:
		_local_box("dark_steel", frame, Vector3(x, 0.45, -3.5), Vector3(0.1, 0.9, 0.1), SMALL)


func _yard() -> void:
	# Trailers backed up to the two doors that are shut, the third door open.
	container("container_blue", Vector3(REAR + 8.0, 0, DOCK_DOORS[0]), true)
	container("container_grey", Vector3(REAR + 8.0, 0, DOCK_DOORS[2]), true)
	for z: float in [DOCK_DOORS[0], DOCK_DOORS[2]]:
		box("dark_steel", Vector3(REAR + 0.2, 1.8, z), Vector3(0.1, 3.6, 3.6), Vector3.ZERO, DETAIL)
	for z: float in [24.0, 28.0]:
		box("shop_steel", Vector3(REAR + 2.5, 1.0, z), Vector3(5.0, 2.0, 3.0), Vector3.ZERO, DETAIL)
	for z: float in [-36.0, -40.0]:
		place("metal_trash_can", Vector3(REAR + 1.5, 0, z), 0.0)
	# A trailer waiting to be unloaded, and the dumpsters against the wall.
	_trailer(Vector2(112.0, 16.0), 12.0)
	_trailer(Vector2(116.0, -30.0), -8.0)
	for z: float in [14.0, 17.2]:
		box("container_green", Vector3(REAR + 1.4, 0.8, z), Vector3(2.0, 1.6, 2.8), Vector3.ZERO, DETAIL)
		box("dark_steel", Vector3(REAR + 1.4, 1.62, z), Vector3(2.1, 0.06, 2.9), Vector3.ZERO, SMALL)
	crates(Vector3(REAR + 7.0, 0, -2.0), 3)
	for x: float in [100.0, 120.0]:
		for z: float in [-30.0, 22.0]:
			barrel(Vector3(x, 0, z + 3.0))
	pallet(Vector3(REAR + 5.0, 0, 36.0), 15.0, 5)
	pallet(Vector3(REAR + 6.5, 0, 38.0), 70.0, 3)
