extends "res://tools/levels/dunes/depot.gd"
## The last leg of the way: the wire in front of the wall, the yard inside
## the gate, and round the back of the main building, past where the current
## and the fuel come in, to its back door. That door is the way out, and
## where the next level begins.
##
## What it is all built from is in tools/levels/dunes/depot.gd; this file
## says where everything stands.

## How wide the way in behind the back door is, and how far it goes back.
const WAY_IN := Vector2(4.8, 9.0)
## Into how many bays the long faces of the main building are divided, and
## its ends.
const BLOCK_BAYS := 15
const END_BAYS := 4


func _describe() -> void:
	_perimeter()
	_wire_belts()
	_inner_yard()
	_main_building()
	_behind()
	_commit_fine()


## The wall round the complex, the gate in it and what stands by the gate.
func _perimeter() -> void:
	# The wall, its bays numbered from the gate eastwards and round. Its
	# outside is on the right of the way a stretch runs.
	var gate_east := Vector2(GATE_X + 3.4, WALL_Z)
	var gate_west := Vector2(GATE_X - 3.4, WALL_Z)
	var south_east := Vector2(WALL_EAST, WALL_Z)
	var north_east := Vector2(WALL_EAST, WALL_NORTH)
	var north_west := Vector2(WALL_WEST, WALL_NORTH)
	var south_west := Vector2(WALL_WEST, WALL_Z)
	var bay := 1
	for stretch: Array in [[gate_east, south_east], [south_east, north_east], [north_east, north_west], [north_west, south_west], [south_west, gate_west]]:
		bay = wall_run(stretch[0], stretch[1], bay, true, Vector2i(0, 0))
	wall_run(Vector2(WALL_EAST, BLOCK_NORTH), Vector2(BLOCK_EAST, BLOCK_NORTH), 1, false, Vector2i(0, 0))
	for corner: Vector2 in [south_east, north_east, north_west, south_west, Vector2(WALL_EAST, BLOCK_NORTH)]:
		corner_pier(corner)
	watch_post(north_west, Vector3(-1, 0, -1))
	watch_post(south_east, Vector3(1, 0, 1))
	# The gate: two posts, and its leaves standing open into the yard.
	for side: float in [-1.0, 1.0]:
		var hinge := Vector3(GATE_X + side * 3.4, YARD_Y, WALL_Z)
		gate_post(hinge, Vector3.BACK)
		var swung := Vector3(-side * 0.2, 0, -0.98).normalized()
		var leaf := Transform3D(Basis(Vector3.UP, atan2(-swung.z, swung.x)), hinge + Vector3(-side * 0.5, 1.75, -0.5) + swung * 1.5)
		_collide_box(leaf, Vector3(3.0, 3.4, 0.08), "metal")
		gate_leaf(leaf, Vector2(3.0, 3.4), -side)
	# What the wall says to whoever comes up the track.
	var face := WALL_Z + WALL_THICK * 0.5
	var named := Transform3D(Basis(), Vector3(bay_middle(gate_east, south_east, 2).x, YARD_Y + 2.75, face))
	fine(MID)
	painted(named * Transform3D(Basis(), Vector3(0, 0, 0.004)), Vector2(3.1, 1.0), WHITEWASH)
	stencil("GATE 2", named * Transform3D(Basis(), Vector3(0, 0, 0.007)), 0.6, STENCIL_BLACK)
	coarse()
	sign_board(Transform3D(Basis(), Vector3(bay_middle(south_west, gate_west, 11).x, YARD_Y + 2.7, face)), Vector2(3.0, 1.3), [["RESTRICTED AREA", 0.3, SIGNAL_RED], ["KEEP OUT", 0.34, STENCIL_BLACK]])
	for warned: Array in [[south_west, gate_west, 3, "KEEP OUT"], [south_west, gate_west, 7, "NO ENTRY"], [gate_east, south_east, 6, "NO ENTRY"], [gate_east, south_east, 11, "KEEP OUT"], [gate_east, south_east, 17, "NO ENTRY"]]:
		sign_board(Transform3D(Basis(), Vector3(bay_middle(warned[0], warned[1], warned[2]).x, YARD_Y + 2.5, face)), Vector2(1.7, 0.56), [[warned[3], 0.26, SIGNAL_RED]])
	# The lamps that light the wall by night, on masts inside it.
	for x: float in [40.0, 100.0, 136.0, 168.0]:
		flood_mast(Vector2(x, WALL_Z - WALL_THICK * 0.5), Vector3.FORWARD)
	for x: float in [30.0, 66.0, 150.0, 180.0, 216.0, 252.0, 288.0]:
		flood_mast(Vector2(x, WALL_NORTH + WALL_THICK * 0.5), Vector3.BACK)
	flood_mast(Vector2(WALL_WEST + WALL_THICK * 0.5, 28.0), Vector3.RIGHT)
	flood_mast(Vector2(WALL_EAST - WALL_THICK * 0.5, 17.0), Vector3.LEFT)
	# What stops a lorry before the gate, and who stands by it.
	barrier_pole(Vector2(65.4, 61.6), 0.0, 6.4)
	sentry_box(Vector2(74.2, 60.4), 0.0)
	sign_post(Vector2(62.2, 66.5), 0.0, "HALT", 0.3, "paper")
	guardroom(Vector2(79.0, 51.6), Vector3(6.0, 3.0, 5.0))
	# Where the wall meets the ground: sand the wind has laid against it on
	# the outside and along the sides the sun warms, moss in its own shade,
	# and marram that nobody pulls up.
	sand_drift(Vector2(WALL_WEST + 0.3, face), Vector2(GATE_X - 4.0, face), Vector3.BACK, 0.55, 2.6, 3)
	sand_drift(Vector2(GATE_X + 4.0, face), Vector2(WALL_EAST - 0.3, face), Vector3.BACK, 0.55, 2.6, 4)
	sand_drift(Vector2(WALL_WEST + 0.4, WALL_NORTH + 0.2), Vector2(76.4, WALL_NORTH + 0.2), Vector3.BACK, 0.3, 1.3, 11)
	sand_drift(Vector2(162.6, WALL_NORTH + 0.2), Vector2(WALL_EAST - 0.4, WALL_NORTH + 0.2), Vector3.BACK, 0.3, 1.3, 13)
	sand_drift(Vector2(WALL_WEST + 0.2, WALL_NORTH + 0.4), Vector2(WALL_WEST + 0.2, WALL_Z - 0.4), Vector3.RIGHT, 0.3, 1.2, 17)
	wall_tufts(Vector2(WALL_WEST + 0.5, face), Vector2(GATE_X - 5.0, face), Vector2(0, 1), 6.0, 1.8)
	wall_tufts(Vector2(GATE_X + 9.0, face), Vector2(BLOCK_WEST, face), Vector2(0, 1), 6.0, 1.8)
	wall_tufts(Vector2(WALL_WEST + 1.0, WALL_NORTH + 0.2), Vector2(76.0, WALL_NORTH + 0.2), Vector2(0, 1), 8.0, 1.0)
	wall_tufts(Vector2(WALL_WEST + 1.0, WALL_Z - 0.2), Vector2(GATE_X - 5.0, WALL_Z - 0.2), Vector2(0, -1), 7.0, 0.8)
	wall_tufts(Vector2(84.0, WALL_Z - 0.2), Vector2(BLOCK_WEST - 1.0, WALL_Z - 0.2), Vector2(0, -1), 7.0, 0.8)
	wall_tufts(Vector2(165.0, WALL_NORTH + 0.2), Vector2(WALL_EAST - 1.0, WALL_NORTH + 0.2), Vector2(0, 1), 9.0, 1.0)


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
	_yard_ground()
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
	# The tank in the shed is laid up under a tarpaulin: over its hull and
	# its turret, with the gun out in front.
	tarpaulin(resting(120.0, 15.4, 180.0, 2.4), [[Vector3(0, 0.85, 0), Vector3(3.0, 1.5, 6.0)], [Vector3(0, 2.0, 0.1), Vector3(2.0, 0.85, 3.0)]])
	_shed_fittings(roof_y)
	_fuel_point()
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


## What the yard is laid with: slab roads from the gate to the sheds and on
## round the main building, an apron before the shed and a hardstanding
## beyond it, and between them sand packed with gravel, rutted where lorries
## turn. And what is painted on the slabs.
func _yard_ground() -> void:
	var inside := WALL_THICK * 0.5
	yard_cover(Rect2(WALL_WEST + inside, WALL_NORTH + inside, BLOCK_WEST - WALL_WEST - inside, WALL_Z - WALL_NORTH - inside * 2.0), [
		curve([Vector2(96, 27), Vector2(98, 35), Vector2(109, 44), Vector2(128, 45.5), Vector2(146, 43), Vector2(156, 36), Vector2(158, 27)], 1.5),
		curve([Vector2(66, 41), Vector2(59, 44), Vector2(52, 42), Vector2(49, 34), Vector2(48, 27)], 1.5),
		curve([Vector2(72, 38), Vector2(80, 36), Vector2(92, 33), Vector2(96, 27)], 1.5),
	], 5, Vector4(1, 1, 0, 1))
	yard_cover(Rect2(BLOCK_WEST, WALL_NORTH + inside, WALL_EAST - BLOCK_WEST - inside, BLOCK_NORTH - WALL_NORTH - inside), [
		curve([Vector2(178, 17), Vector2(198, 18.5), Vector2(222, 16), Vector2(246, 16.5), Vector2(270, 15.5), Vector2(292, 17)], 1.5),
	], 8, Vector4(0, 1, 1, 0))
	moss_along(Vector2(WALL_WEST + 1.0, WALL_Z - inside), Vector2(BLOCK_WEST - 0.5, WALL_Z - inside), Vector2(0, -1), 1.9)
	moss_along(Vector2(BLOCK_WEST - 0.3, BLOCK_NORTH + 0.5), Vector2(BLOCK_WEST - 0.3, WALL_Z - 1.0), Vector2(-1, 0), 0.9)
	# The roads: in from the gate, along the shed and on behind the main
	# building, and the path past the doors of the huts.
	paving(Rect2(66.1, 26.6, 5.8, 33.4), Vector2(2.9, 4.7))
	paving(Rect2(47.5, 20.6, 253.0, 6.0), Vector2(5.0, 3.0))
	paving(Rect2(77.0, 6.9, 52.0, 13.7), Vector2(4.33, 4.6))
	paving(Rect2(129.0, 6.9, 33.0, 13.7), Vector2(4.7, 4.6))
	paving(Rect2(45.6, 16.0, 1.9, 34.5), Vector2(1.9, 1.9))
	paving(Rect2(168.0, 26.6, 8.0, 23.5), Vector2(4.0, 4.7))
	paving(Rect2(71.9, 49.6, 4.1, 2.8), Vector2(2.05, 1.4))
	paving(Rect2(230.0, 13.6, 16.0, 7.0), Vector2(4.0, 3.5))
	for x: float in [66.02, 71.98]:
		kerb(Vector2(x, 27.6), Vector2(x, 49.4) if x > 70.0 else Vector2(x, 55.3), true)
	kerb(Vector2(71.98, 52.6), Vector2(71.98, 55.3), true)
	kerb(Vector2(47.6, 26.68), Vector2(65.9, 26.68))
	kerb(Vector2(72.1, 26.68), Vector2(167.9, 26.68))
	kerb(Vector2(47.6, 20.52), Vector2(76.9, 20.52))
	fine(MID)
	# Stop before the gate, for whoever drives out.
	road_line(Vector2(66.3, 53.6), Vector2(71.7, 53.6), 0.3)
	stencil("STOP", on_ground_frame(Vector2(69.0, 51.4), Vector2(0, 1)), 1.5, WHITEWASH)
	# Where the lorries stand, beyond the shed.
	for i in 5:
		road_line(Vector2(130.4 + i * 3.4, 7.4), Vector2(130.4 + i * 3.4, 13.6))
		if i < 4:
			stencil_number(str(i + 1), on_ground_frame(Vector2(132.1 + i * 3.4, 14.6), Vector2(0, -1)), 0.8, WHITEWASH)
	road_line(Vector2(77.2, 20.3), Vector2(128.8, 20.3), 0.14, SIGNAL_YELLOW)
	road_hatch(Rect2(172.2, 34.6, 3.5, 13.9))
	road_hatch(Rect2(235.4, 22.6, 5.2, 3.8))
	stencil("KEEP CLEAR", on_ground_frame(Vector2(BACK_DOOR_X, 21.7), Vector2(0, 1)), 0.6, SIGNAL_YELLOW)
	coarse()
	for at: Vector2 in [Vector2(66.5, 36.0), Vector2(71.5, 30.0), Vector2(84.0, 26.2), Vector2(112.0, 26.2), Vector2(141.0, 26.2), Vector2(181.0, 21.0), Vector2(226.0, 21.0), Vector2(262.0, 21.0)]:
		gully(at, at.x < 72.0)
	for at: Vector2 in [Vector2(69.6, 39.5), Vector2(97.0, 23.6), Vector2(150.5, 23.8), Vector2(214.0, 23.4), Vector2(137.0, 17.0)]:
		manhole(at)
	# The flagstaff stands in a square of whitewashed kerbs.
	for side: Array in [[Vector2(56.2, 26.2), Vector2(59.8, 26.2)], [Vector2(59.8, 26.2), Vector2(59.8, 29.8)], [Vector2(59.8, 29.8), Vector2(56.2, 29.8)], [Vector2(56.2, 29.8), Vector2(56.2, 26.2)]]:
		kerb(side[0], side[1], true)
	box(CONCRETE, Vector3(58.0, YARD_Y + 0.1, 28.0), Vector3(0.9, 0.3, 0.9), Vector3.ZERO, SLIGHT)
	box(CONCRETE, Vector3(58.0, YARD_Y + 0.3, 28.0), Vector3(0.5, 0.2, 0.5), Vector3.ZERO, SLIGHT)


## What the shed along the north wall has besides its roof: purlins under
## the sheet, a beam along its front with the numbers of its bays, a gutter
## and the pipes it runs into. `roof_y` is how high its roof is in the middle.
func _shed_fittings(roof_y: float) -> void:
	var front := 21.6
	fine(FAR)
	for z: float in [9.2, 12.4, 15.0, 17.8, 20.6]:
		box("steel", Vector3(103.0, roof_y - 0.12 - (z - 15.0) * 0.052, z), Vector3(51.6, 0.14, 0.08), Vector3.ZERO, SLIGHT)
	box("steel", Vector3(103.0, roof_y - 0.62, front), Vector3(50.2, 0.26, 0.12), Vector3.ZERO, SLIGHT)
	box("galvanised", Vector3(103.0, roof_y - 0.44, front + 0.45), Vector3(52.0, 0.12, 0.16), Vector3.ZERO, SLIGHT)
	for x: float in [77.2, 128.8]:
		rod("galvanised", Vector3(x, roof_y - 0.44, front + 0.45), Vector3(x, YARD_Y + 0.2, front + 0.45), 0.05, SLIGHT, 8)
	refine(MID)
	for bay in 4:
		var plate := Transform3D(Basis(), Vector3(84.25 + bay * 12.5, roof_y - 0.62, front + 0.062))
		painted(plate, Vector2(0.9, 0.5), Color(WHITEWASH, 0.4))
		stencil_number(str(bay + 1), plate * Transform3D(Basis(), Vector3(0, 0, 0.003)), 0.38, STENCIL_BLACK)
	coarse()


## The fuel point against the north wall, beyond the shed: two pumps on a
## kerbed island, the vents of the tank under it up the wall, its filler
## caps in the slabs before it, a fire point, and what the wall says there.
## It stands against the wall and is in nobody's way.
func _fuel_point() -> void:
	var wall := WALL_NORTH + WALL_THICK * 0.5 + 0.05
	var island := Rect2(146.6, wall, 8.8, 1.3)
	box(CONCRETE, Vector3(island.get_center().x, YARD_Y + 0.05, island.get_center().y), Vector3(island.size.x, 0.18, island.size.y), Vector3.ZERO, SLIGHT)
	kerb(Vector2(island.position.x, island.end.y + 0.08), Vector2(island.end.x, island.end.y + 0.08), true)
	fine(FAR)
	for x: float in [149.2, 152.6]:
		# A pump: a cabinet with a dial in its face, a crank at its side and
		# its hose on a hook.
		var pump := Transform3D(Basis(), Vector3(x, YARD_Y + 0.14, wall + 0.42))
		rounded_box("army_green", pump * Transform3D(Basis(), Vector3(0, 0.7, 0)), Vector3(0.52, 1.4, 0.34), 0.03, SLIGHT)
		rounded_box("army_green", pump * Transform3D(Basis(), Vector3(0, 1.52, 0)), Vector3(0.4, 0.26, 0.28), 0.06, SLIGHT)
		refine(NEAR)
		_cylinder("dark_steel", pump * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.1, 0.171)), 0.15, 0.012, SLIGHT, -1.0, 16)
		painted(pump * Transform3D(Basis(), Vector3(0, 1.1, 0.19)), Vector2(0.2, 0.2), Color(0.7, 0.68, 0.6, 0.2))
		rod("dark_steel", pump * Vector3(0.27, 0.95, 0), pump * Vector3(0.36, 0.95, 0), 0.015, SLIGHT, 6)
		rod("dark_steel", pump * Vector3(0.36, 0.95, 0), pump * Vector3(0.36, 1.2, 0.05), 0.012, SLIGHT, 6)
		hose("dark_steel", PackedVector3Array([pump * Vector3(-0.2, 0.35, 0.18), pump * Vector3(-0.42, 0.12, 0.3), pump * Vector3(-0.62, 0.5, 0.24), pump * Vector3(-0.5, 1.15, 0.2), pump * Vector3(-0.3, 1.22, 0.18)]), 0.022, SLIGHT, 6)
		refine(FAR)
	# The vents of the tank under the slabs, and its name on the wall.
	for x: float in [155.6, 155.95]:
		rod("galvanised", Vector3(x, YARD_Y + 0.1, wall + 0.1), Vector3(x, YARD_Y + 3.7, wall + 0.1), 0.03, SLIGHT, 6)
		rod("galvanised", Vector3(x, YARD_Y + 3.7, wall + 0.1), Vector3(x, YARD_Y + 3.62, wall + 0.24), 0.03, SLIGHT, 6)
	var name := Transform3D(Basis(), Vector3(151.0, YARD_Y + 3.0, wall - 0.045))
	painted(name, Vector2(3.4, 1.0), Color(WHITEWASH, 0.5))
	stencil("FUEL", name * Transform3D(Basis(), Vector3(0, 0, 0.004)), 0.66, SIGNAL_RED)
	refine(MID)
	stencil("NO SMOKING", Transform3D(Basis(), Vector3(151.0, YARD_Y + 2.1, wall - 0.04)), 0.22, SIGNAL_RED)
	road_hatch(Rect2(147.0, 7.9, 8.0, 2.9))
	coarse()
	fire_point(Transform3D(Basis(), Vector3(147.4, YARD_Y, wall - 0.05)))
	manhole(Vector2(150.9, 9.4))
	manhole(Vector2(153.4, 9.9))


## The main building: a frame of concrete filled in with brick, three
## storeys of it, with two rows of steel windows high up and what it listens
## with on its roof. Its back, the north face, has the door.
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
	var face := BLOCK_NORTH + 0.25
	# What is in the way is what it was: the block itself around the way in
	# behind the back door, and its back wall with the doorway in it. What is
	# seen of it is built in front of that, face by face.
	for part: Array in [
		[Vector3((BLOCK_WEST + way_west) * 0.5, mid_y, (front + south) * 0.5), Vector3(way_west - BLOCK_WEST, high, south - front)],
		[Vector3((way_east + BLOCK_EAST) * 0.5, mid_y, (front + south) * 0.5), Vector3(BLOCK_EAST - way_east, high, south - front)],
		[Vector3(BACK_DOOR_X, mid_y, (way_back + south) * 0.5), Vector3(WAY_IN.x, high, south - way_back)],
		[Vector3(BACK_DOOR_X, (lintel + top) * 0.5, (front + way_back) * 0.5), Vector3(WAY_IN.x, top - lintel, WAY_IN.y)],
		[Vector3((BLOCK_WEST + BACK_DOOR_X - 2.0) * 0.5, mid_y, face), Vector3(BACK_DOOR_X - 2.0 - BLOCK_WEST, high, 0.5)],
		[Vector3((BACK_DOOR_X + 2.0 + BLOCK_EAST) * 0.5, mid_y, face), Vector3(BLOCK_EAST - BACK_DOOR_X - 2.0, high, 0.5)],
		[Vector3(BACK_DOOR_X, (YARD_Y + 3.82 + top) * 0.5, face), Vector3(4.0, top - YARD_Y - 3.82, 0.5)],
	]:
		_collide_box(Transform3D(Basis(), part[0]), part[1])
	# The way in, as it is seen from inside: its floor, walls and ceiling.
	box("floor", Vector3(BACK_DOOR_X, YARD_Y - 0.04, (BLOCK_NORTH + way_back) * 0.5), Vector3(WAY_IN.x, 0.1, way_back - BLOCK_NORTH), Vector3.ZERO, SLIGHT)
	fine(FAR)
	for x: float in [way_west - 0.1, way_east + 0.1]:
		box("concrete", Vector3(x, YARD_Y + 1.95, (front + way_back) * 0.5), Vector3(0.2, 3.9, WAY_IN.y), Vector3.ZERO, SLIGHT)
	box("concrete", Vector3(BACK_DOOR_X, YARD_Y + 1.95, way_back + 0.1), Vector3(WAY_IN.x + 0.4, 3.9, 0.2), Vector3.ZERO, SLIGHT)
	box("concrete", Vector3(BACK_DOOR_X, lintel + 0.1, (front + way_back) * 0.5), Vector3(WAY_IN.x + 0.4, 0.2, WAY_IN.y), Vector3.ZERO, SLIGHT)
	coarse()
	roller_door(Vector3(BACK_DOOR_X, YARD_Y + 1.7, face + 0.01), Vector3.FORWARD, Vector2(4.0, 3.4), true)
	tube(Vector3(BACK_DOOR_X, lintel - 0.16, front + 5.5), false, true, false, 5.0)
	crates(Vector3(BACK_DOOR_X - 1.1, YARD_Y, way_back - 1.3), 3)
	pallet(Vector3(BACK_DOOR_X + 1.3, YARD_Y, way_back - 1.2), 8.0, 3)
	# Posts to keep a lorry off the door.
	fine(MID)
	for x: float in [-3.0, 3.0]:
		cylinder("steel_yellow", Vector3(BACK_DOOR_X + x * 0.9, YARD_Y, BLOCK_NORTH - 1.0), 0.09, 1.0, DETAIL)
	coarse()
	# Its four faces. The south one stands on the wall of the complex and
	# begins where that ends.
	var length := BLOCK_EAST - BLOCK_WEST
	var depth := south - BLOCK_NORTH
	var ground := Vector3(0, YARD_Y, 0)
	var north := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), ground + Vector3(BLOCK_EAST, 0, BLOCK_NORTH))
	var doorway := Rect2(-2.0, -3.0, 4.0, 6.82)
	var high_light := Rect2(-2.4, 2.75, 4.8, 1.1)
	var open := {}
	for i in BLOCK_BAYS:
		open[i] = [high_light]
	# Counted from the east, as the face is seen: the door is in the middle.
	open[7] = [doorway]
	open[10] = [Rect2(-0.55, -3.0, 1.1, 5.15)]
	open[11] = []
	open[13] = []
	open[14] = []
	block_face(north, length, BLOCK_BAYS, 0.5, 0.0, open, {7: [0]})
	for i in BLOCK_BAYS:
		if open[i].size() == 1 and open[i][0] == high_light:
			steel_window(bay_frame(north, length, BLOCK_BAYS, i) * Transform3D(Basis(), Vector3(0, high_light.get_center().y, 0)), high_light.size, REVEAL, Vector2i(6, 1))
			square_box(CONCRETE, bay_frame(north, length, BLOCK_BAYS, i), Vector3(0, high_light.position.y - 0.045, (0.07 - REVEAL) * 0.5), Vector3(high_light.size.x + 0.24, 0.11, REVEAL + 0.07))
	var west := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), ground + Vector3(BLOCK_WEST, 0, BLOCK_NORTH))
	var sunny := Transform3D(Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK), ground + Vector3(BLOCK_WEST, 0, south))
	block_face(west, depth, END_BAYS, 0.4)
	block_face(sunny, length, BLOCK_BAYS, 0.4, WALL_HIGH)
	# Nothing is behind its faces but the dark: wherever a pane is out or a
	# door stands off its frame, that is what shows.
	for part: Array in [
		[Vector3((BLOCK_WEST + way_west) * 0.5 + 0.1, mid_y, (front + south) * 0.5), Vector3(way_west - BLOCK_WEST - 1.1, high - 1.0, south - front - 0.9)],
		[Vector3((way_east + BLOCK_EAST) * 0.5 - 0.1, mid_y, (front + south) * 0.5), Vector3(BLOCK_EAST - way_east - 1.1, high - 1.0, south - front - 0.9)],
		[Vector3(BACK_DOOR_X, mid_y, (way_back + south) * 0.5 + 0.2), Vector3(WAY_IN.x + 1.0, high - 1.0, south - way_back - 1.0)],
		[Vector3(BACK_DOOR_X, (lintel + top) * 0.5 + 0.2, (front + way_back) * 0.5), Vector3(WAY_IN.x + 1.0, top - lintel - 1.2, WAY_IN.y)],
	]:
		fine(FAR)
		box("rubber", part[0], part[1], Vector3.ZERO, SLIGHT)
		coarse()
	_north_face(north, length)
	_west_end(west, depth)
	# Its letter, where it is read from the dunes.
	fine(FAR)
	for i: int in [0, BLOCK_BAYS - 1]:
		stencil("C", bay_frame(sunny, length, BLOCK_BAYS, i) * Transform3D(Basis(), Vector3(0, (BEAMS[2].y + ROOF_EDGE.x) * 0.5, 0.006)), 1.45, WHITEWASH)
	coarse()
	block_face(Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), ground + Vector3(BLOCK_EAST, 0, south)), depth, END_BAYS, 0.4)
	block_corner(Vector2(BLOCK_WEST, BLOCK_NORTH), Vector3.LEFT, Vector3.FORWARD)
	block_corner(Vector2(BLOCK_EAST, BLOCK_NORTH), Vector3.RIGHT, Vector3.FORWARD)
	block_corner(Vector2(BLOCK_WEST, south), Vector3.LEFT, Vector3.BACK)
	block_corner(Vector2(BLOCK_EAST, south), Vector3.RIGHT, Vector3.BACK)
	box(CONCRETE, Vector3((BLOCK_WEST + BLOCK_EAST) * 0.5, top - 0.3, (BLOCK_NORTH + south) * 0.5), Vector3(length - 0.4, 0.3, depth - 0.4), Vector3.ZERO, SLIGHT)
	# On the roof: the dish on its tower, a mast with its aerials, a plant
	# room and its fans.
	# The masts stand where they stood, on blocks of concrete on the roof.
	var roof := top - 0.15
	var mast_foot := top + 0.6
	box(CONCRETE, Vector3(252.0, (roof + mast_foot) * 0.5, 42.0), Vector3(2.6, mast_foot - roof, 2.6), Vector3.ZERO, SLIGHT)
	box(CONCRETE, Vector3(196.0, (roof + mast_foot) * 0.5, 40.0), Vector3(1.6, mast_foot - roof, 1.6), Vector3.ZERO, SLIGHT)
	lattice_mast(Vector3(252.0, mast_foot, 42.0), 8.0, 1.4)
	var tower := Vector3(252.0, mast_foot + 8.0, 42.0)
	dish(Transform3D(Basis(Vector3(1, 0, 0.3).normalized(), deg_to_rad(52.0)), tower + Vector3(0, 2.5, 0)), 3.6, tower)
	lattice_mast(Vector3(196.0, mast_foot, 40.0), 13.0, 0.6)
	fine(FAR)
	for aerial: Array in [[11.6, 1.5, 0.0], [10.2, 1.1, 90.0], [8.4, 1.8, 40.0]]:
		var arm := Basis(Vector3.UP, deg_to_rad(aerial[2])) * Vector3.RIGHT
		var hub := Vector3(196.0, mast_foot + aerial[0], 40.0)
		rod("galvanised", hub - arm * aerial[1], hub + arm * aerial[1], 0.025, SLIGHT, 6)
		for prong: float in [-1.0, -0.5, 0.5, 1.0]:
			rod("galvanised", hub + arm * aerial[1] * prong - Vector3.UP * 0.5, hub + arm * aerial[1] * prong + Vector3.UP * 0.5, 0.012, SLIGHT, 5)
	rod("galvanised", Vector3(196.0, mast_foot + 13.0, 40.0), Vector3(196.0, mast_foot + 17.0, 40.0), 0.02, SLIGHT, 6)
	for x: float in [214.0, 222.0, 268.0]:
		box("galvanised", Vector3(x, roof + 0.7, 44.0), Vector3(3.2, 1.4, 2.2), Vector3.ZERO, SLIGHT)
		cylinder("galvanised", Vector3(x, roof + 1.4, 44.0), 0.7, 0.5, SLIGHT, Vector3.ZERO, -1.0, 14)
	coarse()
	box(BRICK, Vector3(281.0, roof + 1.5, 42.0), Vector3(11.0, 3.0, 8.0), Vector3.ZERO, SLIGHT)
	box(CONCRETE, Vector3(281.0, roof + 3.1, 42.0), Vector3(11.6, 0.2, 8.6), Vector3.ZERO, SLIGHT)


## What the north face of the main building has on it besides its windows:
## the back door under its canopy, with what tells a driver that this is the
## door, a door for men further along, the pipes that take the rain down,
## the letter of the building, and where the current comes in. `face` stands
## at its east end on the ground, as block_face() has it.
func _north_face(face: Transform3D, length: float) -> void:
	var door := bay_frame(face, length, BLOCK_BAYS, 7)
	# The doorway, lined in concrete and banded yellow and black to a
	# lorry's height.
	for side: float in [-1.0, 1.0]:
		square_box(CONCRETE, door, Vector3(side * 2.22, 2.1, 0.07), Vector3(0.44, 4.2, 0.26))
	square_box(CONCRETE, door, Vector3(0, 4.1, 0.07), Vector3(4.9, 0.56, 0.26))
	fine(MID)
	for side: float in [-1.0, 1.0]:
		for band in 8:
			painted(door * Transform3D(Basis(), Vector3(side * 2.22, 0.18 + band * 0.32, 0.202)), Vector2(0.44, 0.32), SIGNAL_YELLOW if band % 2 == 0 else STENCIL_BLACK)
		_local_box("dark_steel", door, Vector3(side * 2.22, 0.75, 0.26), Vector3(0.3, 0.5, 0.12), SLIGHT)
	coarse()
	# The canopy: a roof of sheet on two brackets, hung from the wall by a
	# rod each, with a gutter along its edge and a bar for the headroom.
	var eave := 4.55
	var reach := 3.2
	fine(FAR)
	for side: float in [-1.0, 1.0]:
		beam("steel", door * Vector3(side * 3.1, eave + 0.22, 0.0), door * Vector3(side * 3.1, eave, reach), 0.16, SLIGHT, 0.24)
		rod("dark_steel", door * Vector3(side * 3.1, eave + 2.3, 0.05), door * Vector3(side * 3.1, eave + 0.1, reach - 0.3), 0.022, SLIGHT, 6)
		_local_box("dark_steel", door, Vector3(side * 3.1, eave + 2.3, 0.04), Vector3(0.24, 0.3, 0.08), SLIGHT)
	for purlin in 4:
		var out := 0.25 + purlin * (reach - 0.4) / 3.0
		_local_box("steel", door, Vector3(0, eave + 0.2 - out * 0.069, out), Vector3(6.6, 0.1, 0.07), SLIGHT)
	corrugated("roof", door * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-86.0)), Vector3(0, eave + 0.2, reach * 0.5)), Vector2(7.0, reach + 0.2), 0.19, 0.03, SLIGHT)
	corrugated("roof", door * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(94.0)), Vector3(0, eave + 0.19, reach * 0.5)), Vector2(7.0, reach + 0.2), 0.19, 0.03, SLIGHT)
	_local_box("galvanised", door, Vector3(0, eave - 0.02, reach + 0.12), Vector3(7.1, 0.12, 0.14), SLIGHT)
	refine(MID)
	_local_box("steel_yellow", door, Vector3(0, 3.62, reach - 0.3), Vector3(4.6, 0.12, 0.05), SLIGHT)
	for side: float in [-1.0, 1.0]:
		rod("dark_steel", door * Vector3(side * 2.1, 3.68, reach - 0.3), door * Vector3(side * 2.1, eave + 0.02, reach - 0.3), 0.008, SLIGHT, 4)
	stencil("MAX 3.4 M", door * Transform3D(Basis(), Vector3(0, 3.62, reach - 0.27)), 0.085, STENCIL_BLACK)
	bulkhead(door * Vector3(-1.4, 4.42, 0.2), Vector3.FORWARD)
	bulkhead(door * Vector3(1.4, 4.42, 0.2), Vector3.FORWARD)
	coarse()
	# What it is, in letters a driver reads from the corner of the building.
	var board := door * Transform3D(Basis(), Vector3(0, 6.75, 0.0))
	fine(FAR)
	painted(board * Transform3D(Basis(), Vector3(0, 0, 0.005)), Vector2(6.2, 1.5), WHITEWASH)
	stencil("GOODS IN", board * Transform3D(Basis(), Vector3(0, 0, 0.009)), 0.95, STENCIL_BLACK)
	stencil("C", bay_frame(face, length, BLOCK_BAYS, 14) * Transform3D(Basis(), Vector3(0, 2.75, 0.006)), 2.6, WHITEWASH)
	coarse()
	# The door for men, under a slab, with a lamp and a name.
	var side_door := bay_frame(face, length, BLOCK_BAYS, 10)
	steel_door(side_door * Transform3D(Basis(), Vector3(0, 0.03, 0)), Vector2(1.1, 2.12), 0.2)
	square_box(CONCRETE, side_door, Vector3(0, 0.0, 0.35), Vector3(1.6, 0.14, 0.7))
	square_box(CONCRETE, side_door, Vector3(0, 2.42, 0.4), Vector3(1.9, 0.12, 0.9))
	fine(MID)
	bulkhead(side_door * Vector3(0, 2.75, 0), Vector3.FORWARD)
	sign_plate(side_door * Vector3(0, 2.28, 0.012), Vector3.FORWARD, "STORES", 0.16)
	coarse()
	# The rain off the roof comes down beside every third column.
	fine(FAR)
	for i: int in [1, 4, 7, 10, 13]:
		downpipe(face * Vector3(i * length / BLOCK_BAYS + COLUMN.x * 0.5 + 0.2, 0.05, 0), Vector3.FORWARD, ROOF_EDGE.x - 0.1)
	coarse()
	# A lamp on every other column, a ladder to the roof and the duct of
	# what is aired out of the ground floor.
	fine(MID)
	for i: int in [2, 4, 6, 9, 11, 13]:
		bulkhead(face * Vector3(i * length / BLOCK_BAYS, 3.95, COLUMN.y), Vector3.FORWARD)
	coarse()
	cage_ladder(face * Vector3(2.0 * length / BLOCK_BAYS + COLUMN.x * 0.5 + 0.75, 2.4, 0), Vector3.FORWARD, ROOF_EDGE.y - 2.2)
	duct_riser(face * Vector3(5.0 * length / BLOCK_BAYS - COLUMN.x * 0.5 - 0.7, 2.0, 0), Vector3.FORWARD, ROOF_EDGE.y - 1.7)
	# Where the fuel comes in: two pipes over the road from the tanks, on a
	# trestle, into the wall over the ground floor.
	var pipes_x := 205.2
	fine(FAR)
	for pipe in 2:
		var x := pipes_x + pipe * 0.42
		var tank_z := 11.0 + pipe * 4.6
		pipe_run([Vector3(x, YARD_Y + 3.0, tank_z), Vector3(x, YARD_Y + 4.9, tank_z), Vector3(x, YARD_Y + 4.9, BLOCK_NORTH + 0.1)], 0.07 - pipe * 0.015, "army_green")
	for leg: float in [-0.5, 0.92]:
		box("steel", Vector3(pipes_x + leg, YARD_Y + 2.4, 19.6), Vector3(0.12, 4.8, 0.12), Vector3.ZERO, SLIGHT)
		beam("steel", Vector3(pipes_x + leg, YARD_Y + 0.3, 19.6), Vector3(pipes_x + 0.21, YARD_Y + 3.4, 19.6), 0.06, SLIGHT)
	box("steel", Vector3(pipes_x + 0.21, YARD_Y + 4.76, 19.6), Vector3(1.7, 0.12, 0.14), Vector3.ZERO, SLIGHT)
	box("steel", Vector3(pipes_x + 0.21, YARD_Y + 4.72, BLOCK_NORTH - 0.2), Vector3(1.0, 0.1, 0.4), Vector3.ZERO, SLIGHT)
	coarse()
	# Where the current comes in: two cabinets, and the cables up from them
	# on a tray to the floor above.
	for bay: int in [13, 14]:
		var by := bay_frame(face, length, BLOCK_BAYS, bay)
		hang("utility_box_02" if bay == 13 else "utility_box_01", by * Vector3(-2.2, 2.3, 0.0), Vector3.FORWARD)
	fine(MID)
	cable_tray(bay_frame(face, length, BLOCK_BAYS, 13) * Vector3(-3.4, 3.9, 0.0), bay_frame(face, length, BLOCK_BAYS, 13) * Vector3(3.2, 3.9, 0.0), Vector3.FORWARD, 4)
	coarse()


## The west end of the main building, which looks down the yard: two great
## sliding doors, shut, and the letter of the building beside them.
func _west_end(face: Transform3D, depth: float) -> void:
	sliding_door(bay_frame(face, depth, END_BAYS, 1), Vector2(5.2, 4.3), -1.0)
	sliding_door(bay_frame(face, depth, END_BAYS, 2), Vector2(5.2, 4.3), 1.0)
	fine(FAR)
	stencil("C", bay_frame(face, depth, END_BAYS, 3) * Transform3D(Basis(), Vector3(0, 2.75, 0.006)), 2.6, WHITEWASH)
	coarse()
	fine(FAR)
	downpipe(face * Vector3(depth / END_BAYS + COLUMN.x * 0.5 + 0.2, 0.05, 0), Vector3.LEFT, ROOF_EDGE.x - 0.1)
	coarse()
	fine(MID)
	for bay: int in [1, 2]:
		bulkhead(bay_frame(face, depth, END_BAYS, bay) * Vector3(0, 5.3, 0.06), Vector3.LEFT)
	coarse()


func _behind() -> void:
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
	# A low wall round the tanks to hold what they spill, and a kerb round
	# the bed the transformers stand on: both low enough to step over.
	for side: Array in [[Vector3(204.5, 0.2, 8.5), Vector3(8.6, 0.56, 0.16)], [Vector3(204.5, 0.2, 18.3), Vector3(8.6, 0.56, 0.16)], [Vector3(200.28, 0.2, 13.4), Vector3(0.16, 0.56, 9.96)], [Vector3(208.72, 0.2, 13.4), Vector3(0.16, 0.56, 9.96)]]:
		box(CONCRETE, Vector3(0, YARD_Y, 0) + side[0], side[1], Vector3.ZERO, SLIGHT)
	for side: Array in [[Vector2(182.4, 17.8), Vector2(197.6, 17.8)], [Vector2(197.6, 17.8), Vector2(197.6, 7.4)], [Vector2(182.4, 7.4), Vector2(182.4, 17.8)]]:
		kerb(side[0], side[1])
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
