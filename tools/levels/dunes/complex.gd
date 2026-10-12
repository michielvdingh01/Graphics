extends "res://tools/levels/dunes/plan.gd"
## The last leg of the way: the wire in front of the wall, the yard inside
## the gate, and round the back of the main building, past where the current
## and the fuel come in, to its back door. That door is the way out, and
## where the next level begins.

## The foot of everything that is built here: well under the ground, so that
## nothing shows daylight where the ground dips.
const FOOT := 4.4
## How wide the way in behind the back door is, and how far it goes back.
const WAY_IN := Vector2(4.8, 9.0)


func _describe() -> void:
	_perimeter()
	_wire_belts()
	_inner_yard()
	_main_building()
	_behind()


## A stretch of the wall round the complex from `from` to `to` (x and z),
## which lie on one line from west to east or from north to south: concrete
## with a pier every eight metres and a coping, and over it three strands of
## barbed wire.
func _wall_run(from: Vector2, to: Vector2, wire := true) -> void:
	var length := from.distance_to(to)
	var along_x := is_equal_approx(from.y, to.y)
	var middle := (from + to) * 0.5
	var top := YARD_Y + WALL_HIGH
	box("concrete", Vector3(middle.x, (top + FOOT) * 0.5, middle.y), Vector3(length if along_x else 0.4, top - FOOT, 0.4 if along_x else length), Vector3.ZERO, DETAIL)
	box("concrete", Vector3(middle.x, top + 0.06, middle.y), Vector3(length if along_x else 0.62, 0.12, 0.62 if along_x else length), Vector3.ZERO, SLIGHT)
	var way := (to - from) / length
	var piers := maxi(1, roundi(length / 8.0))
	var before := Vector3.INF
	for i in piers + 1:
		var at := from + way * length * i / piers
		box("concrete", Vector3(at.x, (top + FOOT) * 0.5, at.y), Vector3(0.6, top - FOOT, 0.6), Vector3.ZERO, SLIGHT)
		if not wire:
			continue
		var head := Vector3(at.x, top + 0.6, at.y)
		box("dark_steel", head - Vector3.UP * 0.26, Vector3(0.05, 0.6, 0.05), Vector3.ZERO, SLIGHT)
		if before != Vector3.INF:
			for strand in 3:
				beam("dark_steel", before - Vector3.UP * strand * 0.17, head - Vector3.UP * strand * 0.17, 0.012, SLIGHT)
		before = head


func _perimeter() -> void:
	_wall_run(Vector2(WALL_WEST, WALL_Z), Vector2(GATE_X - 3.4, WALL_Z))
	_wall_run(Vector2(GATE_X + 3.4, WALL_Z), Vector2(WALL_EAST, WALL_Z))
	_wall_run(Vector2(WALL_WEST, WALL_NORTH), Vector2(WALL_WEST, WALL_Z))
	_wall_run(Vector2(WALL_WEST, WALL_NORTH), Vector2(WALL_EAST, WALL_NORTH))
	_wall_run(Vector2(WALL_EAST, WALL_NORTH), Vector2(WALL_EAST, WALL_Z))
	_wall_run(Vector2(BLOCK_EAST, BLOCK_NORTH), Vector2(WALL_EAST, BLOCK_NORTH), false)
	# The gate: two posts, and its leaves standing open into the yard.
	for side: float in [-1.0, 1.0]:
		var hinge := Vector3(GATE_X + side * 3.4, YARD_Y, WALL_Z)
		box("concrete", hinge + Vector3.UP * 2.6, Vector3(0.9, 5.2 + (YARD_Y - FOOT) * 0.0, 0.9), Vector3.ZERO, DETAIL)
		var swung := Vector3(-side * 0.2, 0, -0.98).normalized()
		var leaf := Transform3D(Basis(Vector3.UP, atan2(-swung.z, swung.x)), hinge + Vector3(-side * 0.5, 1.75, -0.5) + swung * 1.5)
		_box("door", leaf, Vector3(3.0, 3.4, 0.08), DETAIL)
		for bar: float in [-1.2, 0.0, 1.2]:
			_local_box("dark_steel", leaf, Vector3(bar, 0, 0.06), Vector3(0.08, 3.4, 0.05), SLIGHT)
	label("GATE 2", Vector3(GATE_X + 7.2, YARD_Y + 2.7, WALL_Z + 0.21), Vector3.BACK, 0.55)
	for x: float in [30.0, 52.0, 96.0, 124.0, 150.0]:
		wall_decal(_pick("leak"), Vector3(x + _decal_rng.randf_range(-2, 2), YARD_Y + 2.4, WALL_Z + 0.21), Vector3.BACK, 2.2, 3.6)
		wall_decal("grime", Vector3(x, YARD_Y + 0.7, WALL_Z + 0.22), Vector3.BACK, 11.0, 1.5)
	# What stops a lorry before the gate, and who stands by it.
	barrier_pole(Vector2(65.4, 61.6), 0.0, 6.4)
	sentry_box(Vector2(74.2, 60.4), 0.0)
	sign_post(Vector2(62.2, 66.5), 0.0, "HALT", 0.3, "paper")
	# The guardroom, just inside.
	box("brick", Vector3(79.0, YARD_Y + 1.5, 51.6), Vector3(6.0, 3.0, 5.0), Vector3.ZERO, DETAIL)
	box("concrete", Vector3(79.0, YARD_Y + 3.1, 51.6), Vector3(6.6, 0.22, 5.6), Vector3.ZERO, SLIGHT)
	box("door", Vector3(75.97, YARD_Y + 1.0, 51.0), Vector3(0.06, 2.0, 0.9), Vector3.ZERO, SLIGHT)
	box("scope_glass", Vector3(79.0, YARD_Y + 1.7, 49.07), Vector3(2.4, 0.9, 0.06), Vector3.ZERO, SLIGHT)
	wall_decal("grime", Vector3(79.0, YARD_Y + 0.6, 49.08), Vector3.FORWARD, 5.6, 1.2)


func _wire_belts() -> void:
	# Two belts of wire across the ground before the wall, each with a gap
	# where the track goes through; whoever comes, comes up the track.
	for run: Array in [[82.0, [24.0, 34.0, 45.0]], [82.0, [59.0, 72.0, 85.0, 98.0, 111.0, 122.0]], [71.0, [24.0, 36.0, 48.0, 54.0]], [71.0, [64.0, 76.0, 88.0, 100.0, 112.0, 122.0]]]:
		var ends: Array = run[1]
		for i in ends.size() - 1:
			wire_coil(Vector2(ends[i], run[0] + _clutter_rng.randf_range(-0.6, 0.6)), Vector2(ends[i + 1], run[0] + _clutter_rng.randf_range(-0.6, 0.6)))
	sign_post(Vector2(38.0, 86.0), 0.0, "MINES", 0.24, "paper")
	sign_post(Vector2(90.0, 86.0), 0.0, "KEEP OUT", 0.24, "paper")
	sign_post(Vector2(112.0, 75.0), 0.0, "MINES", 0.24, "paper")
	pillbox(Vector2(40.0, 65.5), 0.0)
	pillbox(Vector2(98.0, 65.5), 0.0)
	_put("tree_stump_01", 61.5, 88.5, 30)
	_put("tree_stump_01", 84.0, 89.5, 200)
	_put("tree_stump_01", 31.0, 89.0, 110)
	drop("dry_branches_medium_01", ground(72, 87, 0.02), 60)
	drop("dry_branches_medium_01", ground(104, 86.5, 0.02), 150)
	thicket([Vector2(19.4, 58.0), Vector2(19.8, 76.0), Vector2(20.4, 94.0)])
	thicket([Vector2(124.5, 58.0), Vector2(126.0, 76.0), Vector2(125.0, 93.0)])


func _inner_yard() -> void:
	cover_over("earth", Rect2(WALL_WEST, WALL_NORTH, BLOCK_WEST - WALL_WEST, WALL_Z - WALL_NORTH), 0.85)
	nissen_hut(Vector2(38.0, 20.0), 0.0, 14.0)
	nissen_hut(Vector2(38.0, 34.0), 0.0, 14.0)
	# A flagstaff between the huts and the gate.
	cylinder("galvanised", Vector3(58.0, YARD_Y, 28.0), 0.06, 9.0, SLIGHT, Vector3.ZERO, 0.035, 8)
	_sheet(CANVAS, [Vector3(58.05, YARD_Y + 7.6, 28.0), Vector3(59.9, YARD_Y + 7.45, 28.25), Vector3(59.9, YARD_Y + 8.65, 28.25), Vector3(58.05, YARD_Y + 8.8, 28.0)], 0.0, 3, 1)
	# The shed along the north wall, open to the yard, and what stands in it.
	var roof_y := YARD_Y + 4.4
	box("roof", Vector3(103.0, roof_y, 15.0), Vector3(52.0, 0.12, 14.0), Vector3(3, 0, 0), SLIGHT)
	for x: float in [78.0, 90.5, 103.0, 115.5, 128.0]:
		box("steel", Vector3(x, YARD_Y + 2.0, 21.6), Vector3(0.2, 4.6, 0.2), Vector3.ZERO, DETAIL)
		beam("steel", Vector3(x, roof_y - 0.5, 21.6), Vector3(x, roof_y + 0.25, 8.4), 0.14, SLIGHT)
	casts_shade(Vector3(103.0, roof_y, 15.0), Vector3(27.0, 0.7, 8.0))
	vehicle("jeep", Vector2(84.0, 15.5), 0.0)
	vehicle("jeep", Vector2(89.6, 15.2), 5.0)
	vehicle("truck", Vector2(99.5, 15.2), 0.0)
	vehicle("truck", Vector2(107.0, 15.0), -2.0)
	vehicle("tank", Vector2(120.0, 15.4), 0.0)
	vehicle("tank_b", Vector2(104.0, 41.0), -90.0)
	crates(Vector3(62.0, YARD_Y, 46.0), 5)
	crates(Vector3(65.4, YARD_Y, 47.6), 3)
	pallet(Vector3(60.0, YARD_Y, 49.4), 20.0, 4)
	crates(Vector3(134.0, YARD_Y, 46.0), 4)
	for at: Vector3 in [Vector3(131.0, YARD_Y, 23.4), Vector3(131.8, YARD_Y, 23.0), Vector3(131.5, YARD_Y, 24.2)]:
		barrel(at)
	fuel(Vector3(142.0, YARD_Y, 9.4))
	fuel(Vector3(142.8, YARD_Y, 9.8))
	tyres(Vector3(76.6, YARD_Y, 9.4), 4)
	watch_tower(Vector2(25.0, 49.0), 7.0)
	watch_tower(Vector2(314.5, 13.0), 7.0, 90.0)
	# Stores in rows down the middle, between the huts and the shed.
	nissen_hut(Vector2(38.0, 47.0), 0.0, 14.0)
	container("container_green", Vector3(118.0, YARD_Y, 48.0), true)
	container("container_grey", Vector3(125.0, YARD_Y, 48.4), true)
	for row in 3:
		crates(Vector3(72.0 + row * 9.0, YARD_Y, 31.0), 4 - row % 2)
		pallet(Vector3(75.2 + row * 9.0, YARD_Y, 31.6), 10.0 * row, 3 + row)
	bags(Vector3(92.0, YARD_Y, 36.0), 20.0, 4, 2)
	tyres(Vector3(112.0, YARD_Y, 29.0), 4)
	tyres(Vector3(113.1, YARD_Y, 29.5), 3)
	vehicle("jeep", Vector2(146.0, 46.0), -95.0)
	vehicle("truck", Vector2(136.0, 12.0), 3.0)
	sandbag_post(Vector2(69.0, 44.0), 0.0, 4.4, 2.4)
	for at: Vector3 in [Vector3(57.0, YARD_Y, 12.0), Vector3(57.9, YARD_Y, 12.4), Vector3(57.3, YARD_Y, 13.2), Vector3(58.4, YARD_Y, 13.4)]:
		barrel(at)
	probe("Yard", Vector3(97.0, YARD_Y + 4.0, 31.0), Vector3(156, 10, 49), Vector3.ZERO)


## The main building: a block of concrete, ribbed, with two bands of dark
## windows high up and what it listens with on its roof. Its back, the north
## face, has the door.
func _main_building() -> void:
	var top := YARD_Y + BLOCK_HIGH
	var south := WALL_Z - 0.2
	var front := BLOCK_NORTH + 0.5
	var mid_y := (top + FOOT) * 0.5
	var high := top - FOOT
	var way_west := BACK_DOOR_X - WAY_IN.x * 0.5
	var way_east := BACK_DOOR_X + WAY_IN.x * 0.5
	var way_back := front + WAY_IN.y
	var lintel := YARD_Y + 3.9
	# The block itself, around the way in behind the back door.
	box("concrete", Vector3((BLOCK_WEST + way_west) * 0.5, mid_y, (front + south) * 0.5), Vector3(way_west - BLOCK_WEST, high, south - front), Vector3.ZERO, DETAIL)
	box("concrete", Vector3((way_east + BLOCK_EAST) * 0.5, mid_y, (front + south) * 0.5), Vector3(BLOCK_EAST - way_east, high, south - front), Vector3.ZERO, DETAIL)
	box("concrete", Vector3(BACK_DOOR_X, mid_y, (way_back + south) * 0.5), Vector3(WAY_IN.x, high, south - way_back), Vector3.ZERO, DETAIL)
	box("concrete", Vector3(BACK_DOOR_X, (lintel + top) * 0.5, (front + way_back) * 0.5), Vector3(WAY_IN.x, top - lintel, WAY_IN.y), Vector3.ZERO, DETAIL)
	box("floor", Vector3(BACK_DOOR_X, YARD_Y - 0.04, (BLOCK_NORTH + way_back) * 0.5), Vector3(WAY_IN.x, 0.1, way_back - BLOCK_NORTH), Vector3.ZERO, SLIGHT)
	# Its back wall, with the doorway in it.
	var face := BLOCK_NORTH + 0.25
	box("concrete", Vector3((BLOCK_WEST + BACK_DOOR_X - 2.0) * 0.5, mid_y, face), Vector3(BACK_DOOR_X - 2.0 - BLOCK_WEST, high, 0.5), Vector3.ZERO, DETAIL)
	box("concrete", Vector3((BACK_DOOR_X + 2.0 + BLOCK_EAST) * 0.5, mid_y, face), Vector3(BLOCK_EAST - BACK_DOOR_X - 2.0, high, 0.5), Vector3.ZERO, DETAIL)
	box("concrete", Vector3(BACK_DOOR_X, (YARD_Y + 3.82 + top) * 0.5, face), Vector3(4.0, top - YARD_Y - 3.82, 0.5), Vector3.ZERO, DETAIL)
	roller_door(Vector3(BACK_DOOR_X, YARD_Y + 1.7, face + 0.01), Vector3.FORWARD, Vector2(4.0, 3.4), true)
	tube(Vector3(BACK_DOOR_X, lintel - 0.16, front + 5.5), false, true, false, 5.0)
	crates(Vector3(BACK_DOOR_X - 1.1, YARD_Y, way_back - 1.3), 3)
	pallet(Vector3(BACK_DOOR_X + 1.3, YARD_Y, way_back - 1.2), 8.0, 3)
	# A canopy over the door, what it says, and posts to keep a lorry off it.
	box("roof", Vector3(BACK_DOOR_X, YARD_Y + 4.35, BLOCK_NORTH - 1.4), Vector3(6.6, 0.1, 2.8), Vector3(-5, 0, 0), SLIGHT)
	for x: float in [-3.0, 3.0]:
		beam("steel", Vector3(BACK_DOOR_X + x, YARD_Y + 4.25, BLOCK_NORTH - 2.7), Vector3(BACK_DOOR_X + x, YARD_Y + 5.3, BLOCK_NORTH), 0.07, SLIGHT)
		cylinder("steel_yellow", Vector3(BACK_DOOR_X + x * 0.9, YARD_Y, BLOCK_NORTH - 1.0), 0.09, 1.0, DETAIL)
	label("LOADING", Vector3(BACK_DOOR_X, YARD_Y + 4.95, BLOCK_NORTH - 0.01), Vector3.FORWARD, 0.42, Color(0.1, 0.1, 0.1))
	label("BLOCK C", Vector3(212.0, YARD_Y + 8.8, BLOCK_NORTH - 0.01), Vector3.FORWARD, 1.7, Color(0.12, 0.12, 0.12))
	# Ribs up its long faces and its west end, with the windows between
	# them, and stains under those.
	var bays := 15
	for i in bays + 1:
		var x := lerpf(BLOCK_WEST, BLOCK_EAST, float(i) / bays)
		box("concrete", Vector3(x, mid_y, BLOCK_NORTH - 0.16), Vector3(0.8, high, 0.34), Vector3.ZERO, SLIGHT)
		box("concrete", Vector3(x, (top + YARD_Y + WALL_HIGH) * 0.5, WALL_Z + 0.1), Vector3(0.8, top - YARD_Y - WALL_HIGH, 0.5), Vector3.ZERO, SLIGHT)
		if i == bays:
			continue
		var middle := x + (BLOCK_EAST - BLOCK_WEST) / bays * 0.5
		for row: float in [6.6, 11.0]:
			if absf(middle - BACK_DOOR_X) > 5.0 or row > 8.0:
				box("scope_glass", Vector3(middle, YARD_Y + row, BLOCK_NORTH - 0.02), Vector3(6.2, 1.5, 0.06), Vector3.ZERO, SLIGHT)
			box("scope_glass", Vector3(middle, YARD_Y + row, WALL_Z - 0.17), Vector3(6.2, 1.5, 0.06), Vector3.ZERO, SLIGHT)
		if i % 2 == 0:
			wall_decal(_pick("leak"), Vector3(middle + _decal_rng.randf_range(-2, 2), YARD_Y + 3.9, BLOCK_NORTH - 0.01), Vector3.FORWARD, 2.4, 4.4)
		wall_decal("grime", Vector3(middle, YARD_Y + 0.8, BLOCK_NORTH - 0.01), Vector3.FORWARD, 8.4, 1.6)
	for z: float in [34.0, 42.0, 50.0]:
		box("concrete", Vector3(BLOCK_WEST - 0.16, mid_y, z - 4.0), Vector3(0.34, high, 0.8), Vector3.ZERO, SLIGHT)
		for row: float in [6.6, 11.0]:
			box("scope_glass", Vector3(BLOCK_WEST - 0.02, YARD_Y + row, z), Vector3(0.06, 1.5, 6.0), Vector3.ZERO, SLIGHT)
		wall_decal("grime", Vector3(BLOCK_WEST - 0.01, YARD_Y + 0.8, z - 2.0), Vector3.LEFT, 8.0, 1.6)
	box("concrete", Vector3((BLOCK_WEST + BLOCK_EAST) * 0.5, top + 0.3, (BLOCK_NORTH + south) * 0.5), Vector3(BLOCK_EAST - BLOCK_WEST + 1.0, 0.6, south - BLOCK_NORTH + 1.0), Vector3.ZERO, SLIGHT)
	# On the roof: the dish on its tower, a mast, a plant room and its fans.
	lattice_mast(Vector3(252.0, top + 0.6, 42.0), 8.0, 1.4)
	revolve("galvanised", Transform3D(Basis(Vector3(1, 0, 0.3).normalized(), deg_to_rad(52.0)), Vector3(252.0, top + 9.6, 42.0)), PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.2, 0.09), Vector2(2.4, 0.36), Vector2(3.4, 0.72), Vector2(4.2, 1.1), Vector2(4.3, 1.1),
		Vector2(3.4, 0.62), Vector2(2.4, 0.26), Vector2(1.2, -0.02), Vector2(0.0, -0.12),
	]), SLIGHT, 24)
	rod("dark_steel", Vector3(252.0, top + 9.6, 42.0), Vector3(252.0, top + 9.6, 42.0) + Basis(Vector3(1, 0, 0.3).normalized(), deg_to_rad(52.0)) * Vector3.UP * 3.0, 0.05, SLIGHT, 6)
	lattice_mast(Vector3(196.0, top + 0.6, 40.0), 13.0, 0.6)
	box("concrete", Vector3(281.0, top + 2.1, 42.0), Vector3(11.0, 3.0, 8.0), Vector3.ZERO, SLIGHT)
	for x: float in [214.0, 222.0, 268.0]:
		box("galvanised", Vector3(x, top + 1.3, 44.0), Vector3(3.2, 1.4, 2.2), Vector3.ZERO, SLIGHT)


func _behind() -> void:
	cover_over("earth", Rect2(BLOCK_WEST - 6.0, WALL_NORTH, WALL_EAST - BLOCK_WEST + 6.0, BLOCK_NORTH - WALL_NORTH), 0.85)
	# Where the current comes in: two transformers under their mast, fed
	# over the wall from the powerhouse.
	var mast := Vector3(190.0, YARD_Y, 9.4)
	lattice_mast(mast, 11.5, 0.9)
	for x: float in [186.0, 194.0]:
		var bushings := transformer(Vector3(x, YARD_Y, 14.0), 0.0)
		for i in bushings.size():
			wire(bushings[i], mast + Vector3((i - 1) * 0.5 + (x - 190.0) * 0.1, 11.0, 0), 0.5)
	for i in 3:
		wire(mast + Vector3((i - 1) * 0.6, 11.2, 0), Vector3(172.0 + i * 1.2, YARD_Y + 19.0, -44.0), 3.5, 0.02)
	sign_post(Vector2(181.0, 19.0), -90.0, "DANGER HIGH VOLTAGE", 0.13, "paper")
	# Where the fuel is kept.
	vessel(Vector3(204.5, YARD_Y, 11.0), 90.0, 6.0, 1.25, ARMY)
	vessel(Vector3(204.5, YARD_Y, 15.6), 90.0, 6.0, 1.25, ARMY)
	for at: Vector3 in [Vector3(209.6, YARD_Y, 20.4), Vector3(210.4, YARD_Y, 20.9), Vector3(209.9, YARD_Y, 21.6)]:
		fuel(at)
	sign_post(Vector2(199.5, 19.4), -90.0, "NO SMOKING", 0.2, "paper")
	# What came in by the back door and is still to go in.
	container("container_green", Vector3(258.0, YARD_Y, 11.6), true)
	container("container_grey", Vector3(268.5, YARD_Y, 21.0), true)
	crates(Vector3(249.0, YARD_Y, 22.6), 4)
	crates(Vector3(275.0, YARD_Y, 11.0), 3)
	pallet(Vector3(246.4, YARD_Y, 20.4), 12.0, 4)
	pallet(Vector3(229.0, YARD_Y, 24.6), 80.0, 3)
	tyres(Vector3(286.0, YARD_Y, 24.8), 3)
	_put("portable_generator", 290.0, 21.5, 90)
	box("brick", Vector3(300.0, YARD_Y + 1.7, 14.0), Vector3(8.0, 3.4, 6.0), Vector3.ZERO, DETAIL)
	box("concrete", Vector3(300.0, YARD_Y + 3.5, 14.0), Vector3(8.6, 0.22, 6.6), Vector3.ZERO, SLIGHT)
	box("door", Vector3(295.97, YARD_Y + 1.0, 14.0), Vector3(0.06, 2.0, 0.9), Vector3.ZERO, SLIGHT)
	wall_decal("grime", Vector3(295.98, YARD_Y + 0.6, 14.0), Vector3.LEFT, 5.6, 1.2)
	probe("Behind", Vector3(248.0, YARD_Y + 4.0, 16.5), Vector3(146, 10, 20), Vector3.ZERO)


func _route_through() -> void:
	route_zone("wire", "the wire", _ground_box(20, 57, 124, 96), [
		guard("grunt", Vector2(67.0, 60.2), Vector2(58, 78), 45.0),
		guard("grunt", Vector2(72.4, 62.4), Vector2(62, 80), 45.0),
		beat("grunt", [Vector2(106, 76.5), Vector2(66, 76.5), Vector2(32, 76.5)]),
		guard("heavy", Vector2(44.5, 69.0), Vector2(50, 88), 35.0),
		guard("rusher", Vector2(93.5, 69.0), Vector2(80, 86), 50.0),
		beat("grunt", [Vector2(58, 59.4), Vector2(28, 59.4)]),
		guard("grunt", Vector2(112.0, 63.0), Vector2(104, 84), 45.0),
	])
	_carry_on("gate", "The gate", Vector2(GATE_X, WALL_Z + 2.4), Vector2(GATE_X, WALL_Z - 8.0), 3.0)
	# The yard is held in two: the huts, the stores and the guardroom inside
	# the gate, and beyond them the vehicles in the shed and before it.
	route_zone("yard", "the yard", _ground_box(18.5, 6.5, 96, 55.6), [
		beat("grunt", [Vector2(62, 26), Vector2(95, 26), Vector2(95, 40), Vector2(62, 40)], true),
		guard("grunt", Vector2(47.5, 23.0), Vector2(66, 30), 45.0),
		guard("grunt", Vector2(48.0, 37.0), Vector2(66, 40), 45.0),
		guard("grunt", Vector2(87.0, 20.4), Vector2(86, 36), 45.0),
		guard("heavy", Vector2(56.5, 30.5), Vector2(68, 50), 35.0),
		guard("rusher", Vector2(85.0, 46.5), Vector2(72, 52), 50.0),
	])
	route_zone("park", "the vehicle park", _ground_box(96, 6.5, 162, 55.6), [
		beat("grunt", [Vector2(140, 43), Vector2(140, 25), Vector2(104, 25), Vector2(104, 34)], true),
		guard("rusher", Vector2(111.5, 36.5), Vector2(92, 44), 50.0),
		guard("heavy", Vector2(150.0, 34.0), Vector2(120, 36), 35.0),
		guard("grunt", Vector2(124.5, 20.0), Vector2(112, 32), 45.0),
		guard("grunt", Vector2(121.5, 43.4), Vector2(100, 34), 45.0),
		guard("grunt", Vector2(139.5, 16.0), Vector2(124, 28), 45.0),
	])
	_carry_on("block", "Main building", Vector2(164, 15), Vector2(182, 17), 4.5)
	route_zone("tank_farm", "the tank farm", _ground_box(170, 6.5, 216, 26.8), [
		guard("grunt", Vector2(190.0, 19.5), Vector2(172, 18), 45.0),
		beat("grunt", [Vector2(213, 22.5), Vector2(184, 23)]),
		guard("grunt", Vector2(198.5, 10.5), Vector2(188, 20), 45.0),
		guard("rusher", Vector2(211.0, 17.5), Vector2(194, 20), 50.0),
		guard("heavy", Vector2(203.5, 19.6), Vector2(184, 18), 35.0),
	])
	route_zone("back_door", "the back door", _ground_box(216, 6.5, 321.5, 26.8), [
		guard("heavy", Vector2(BACK_DOOR_X - 3.4, 22.6), Vector2(220, 18), 35.0),
		guard("heavy", Vector2(BACK_DOOR_X + 3.4, 22.6), Vector2(222, 14), 35.0),
		beat("grunt", [Vector2(300, 19), Vector2(252, 17)]),
		guard("grunt", Vector2(263.0, 16.4), Vector2(240, 18), 45.0),
		guard("rusher", Vector2(281.0, 21.0), Vector2(258, 20), 50.0),
		guard("grunt", Vector2(285.5, 13.0), Vector2(262, 17), 45.0),
	])
	# Through the door: the level ends a step inside.
	var face := BLOCK_NORTH + 0.25
	route_exit("Leave by the back door", AABB(Vector3(BACK_DOOR_X - 2.3, YARD_Y - 0.1, face + 1.2), Vector3(4.6, 3.6, 3.0)), "", Vector3(BACK_DOOR_X, YARD_Y + 5.6, BLOCK_NORTH), Vector3.FORWARD)
