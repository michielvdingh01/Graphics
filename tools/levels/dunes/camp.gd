extends "res://tools/levels/dunes/plan.gd"
## The middle leg of the way, from east to west under the long dune: the
## picket on the saddle the track comes over; the bivouac in its hollow,
## where they stand over the map in the command tent; the motor pool, its
## lorries under nets; and the laager of the tanks.

## Where the post of the picket stands, and which way it looks: down the
## track, towards the valley.
const PICKET := Vector2(283.0, 153.6)
const PICKET_LOOKS := -35.0

## Where the command tent stands, and where in it the table with the map is.
const TENT := Vector2(279, 121)
const TABLE := Vector3(0, 0, -0.3)


func _describe() -> void:
	_picket()
	_bivouac()
	_motor_pool()
	_laager()


## The picket: a post of sandbags beside the track where it comes over the
## saddle, and the shelter of the two who are off watch.
func _picket() -> void:
	sandbag_post(PICKET, PICKET_LOOKS, 4.0, 2.4)
	_put("ammo_box", 284.2, 151.4, 35)
	bivouac(Vector2(283.5, 147.5), 65.0)
	sign_post(Vector2(275.2, 160.2), -32.0, "HALT", 0.3, "paper")
	cover("earth", Vector2(281, 152), 6.0, 0.85, 0.5)
	# What two men on watch have with them: a helmet on the bags, the
	# telephone to the tent, their kit by the shelter.
	var looks := Vector2(0, 1).rotated(-deg_to_rad(PICKET_LOOKS))
	var wall := PICKET + looks * 1.2 + looks.orthogonal() * 1.1
	helmet(ground(wall.x, wall.y, 0.99), 40.0)
	var inside := PICKET + looks * 0.85 - looks.orthogonal() * 1.55
	field_telephone(ground(inside.x, inside.y), PICKET_LOOKS + 100.0, Vector2(279.5, 136.0))
	kit(Vector2(285.4, 148.9), 50.0)
	strew("metal_jerrycan_green", ground(284.9, 150.6), 70)


func _bivouac() -> void:
	var tent_xf := tent(TENT, 0.0, Vector3(8.5, 3.2, 5.6))
	# The map: one on the table they stand over, and the large one on its
	# board against the back of the tent, both ringed in red where the posts
	# are and where the way into the complex is.
	for mark: Vector2 in [Vector2(138, 186), Vector2(226, 171), PICKET, TENT, Vector2(188, 122), Vector2(104, 122), Vector2(GATE_X, WALL_Z), Vector2(BACK_DOOR_X, BLOCK_NORTH)]:
		mark_on_map(mark)
	table(tent_xf * TABLE, 0.0, Vector3(2.6, 0.82, 1.4))
	map_sheet(tent_xf * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), TABLE + Vector3(0, 0.832, 0)), 1.95)
	var board := tent_xf * Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0, 1.5, -2.45))
	_local_box("wood", board, Vector3(0, 0, -0.03), Vector3(2.9, 2.0, 0.04), SLIGHT)
	map_sheet(board, 2.7)
	for x: float in [-1.2, 1.2]:
		beam("wood", tent_xf * Vector3(x, 0.0, -2.2), tent_xf * Vector3(x, 2.4, -2.62), 0.05, SLIGHT)
		beam("wood", tent_xf * Vector3(x, 0.0, -2.75), tent_xf * Vector3(x, 1.6, -2.55), 0.05, SLIGHT)
	bulb(tent_xf * Vector3(0, 2.72, -0.3), false)
	drop("clipboard", tent_xf * (TABLE + Vector3(1.0, 0.835, 0.45)), 20, Basis(Vector3.RIGHT, -PI * 0.5))
	drop("office_notepads", tent_xf * (TABLE + Vector3(-1.02, 0.835, -0.4)), 70)
	# The set, on a table of its own at the east end, and somewhere to sit.
	table(tent_xf * Vector3(3.3, 0, -1.7), 90.0, Vector3(1.5, 0.76, 0.75))
	drop("vintage_radio_transceiver", tent_xf * Vector3(3.3, 0.77, -1.7), -90)
	place("metal_stool_03", tent_xf * Vector3(2.5, 0, -1.6), 40)
	place("SchoolChair_01", tent_xf * Vector3(-3.4, 0, -1.9), 110)
	place("old_military_crate", tent_xf * Vector3(-3.3, 0, 0.6), 84)
	place("ammo_box", tent_xf * Vector3(-3.2, 0, 1.7), 30)
	sign_post(Vector2(271.5, 127.5), 200.0, "HQ", 0.26)
	_furnish(tent_xf)

	# Round it: the fire, the shelters of those who sleep here, the mast of
	# the set with its aerial, a field car and what the camp runs on.
	campfire(Vector2(289.5, 131.5))
	bivouac(Vector2(296.5, 112.5), 20.0)
	bivouac(Vector2(301.0, 119.0), 100.0)
	bivouac(Vector2(295.5, 125.0), -30.0)
	lattice_mast(ground(288.5, 112.0), 11.0, 0.5)
	wire(ground(288.5, 112.0, 10.8), tent_xf * Vector3(4.4, 3.25, 0), 0.6, 0.006)
	wire(ground(288.5, 112.0, 10.8), ground(302, 104, 3.0), 0.5, 0.006)
	vehicle("jeep", Vector2(266.5, 114.0), 25.0)
	_put("portable_generator", 271.5, 112.6, 0)
	_put("metal_jerrycan", 272.9, 112.2, 30)
	_put("metal_jerrycan", 273.3, 112.9, -15)
	crates(ground(286.2, 117.4), 3)
	_put("wooden_military_crate", 285.4, 123.6, 10)
	ferns(Vector2(300, 134), 8.0, 7)
	ferns(Vector2(258, 142), 7.0, 6)
	cover("earth", TENT + Vector2(0, 6), 13.0, 0.9, 0.5)
	# Between the shelters: a line with the washing on it, the drum they
	# cook on, water, and what a man puts down.
	var post := ground(292.4, 121.6)
	var other := ground(296.8, 118.6)
	_pole(post + Vector3.DOWN * 0.2, post + Vector3.UP * 1.85, 0.03, 0.025)
	_pole(other + Vector3.DOWN * 0.2, other + Vector3.UP * 1.8, 0.03, 0.025)
	washing_line(post + Vector3.UP * 1.8, other + Vector3.UP * 1.75)
	strew("barrel_stove", ground(287.6, 116.6), 30)
	strew("metal_jerrycan_green", ground(287.2, 115.6), 80)
	strew("metal_jerrycan_green", ground(286.7, 115.8), 95)
	kit(Vector2(298.4, 113.6), 110.0)
	kit(Vector2(302.2, 117.2), 10.0, true, false)
	kit(Vector2(293.9, 126.2), 150.0, false, true)
	helmet(ground(297.9, 124.0), 200.0)
	floor_decal("stain_1", ground(266.4, 113.2), Vector2(1.3, 1.0), 25.0)
	probe("Bivouac", ground(280, 122, 3.0), Vector3(44, 9, 34), Vector3.ZERO)


## What stands and lies in the command tent besides its tables: a sheet
## on the ground, boards at the way in, the telephone, helmets, the kit of
## those who sleep in it, what they drink out of.
func _furnish(tent_xf: Transform3D) -> void:
	ground_sheet(TENT + Vector2(0.2, -0.3), 0.0, Vector2(7.4, 4.4))
	var door := tent_xf * Vector3(0.3, 0, 2.3)
	var out := tent_xf * Vector3(0.3, 0, 4.2)
	duckboards(Vector2(door.x, door.z), Vector2(out.x, out.z), 0.8)
	field_telephone(tent_xf * (TABLE + Vector3(1.02, 0.84, -0.42)), -20.0, Vector2(288.2, 112.6))
	helmet(tent_xf * (TABLE + Vector3(-0.3, 0.84, -0.5)), 30.0)
	helmet(tent_xf * Vector3(3.3, 0.77, -1.12), 140.0)
	for mug: Vector2 in [Vector2(0.55, 0.5), Vector2(-0.7, 0.42), Vector2(-1.1, 0.1)]:
		_small = true
		cylinder(ARMY, tent_xf * (TABLE + Vector3(mug.x, 0.84, mug.y)), 0.04, 0.085, SLIGHT, Vector3.ZERO, 0.045, 8)
		_small = false
	var back := tent_xf * Vector3(-2.7, 0, -2.3)
	kit(Vector2(back.x, back.z), 5.0)
	back = tent_xf * Vector3(2.2, 0, -2.4)
	kit(Vector2(back.x, back.z), 170.0, true, false)
	back = tent_xf * Vector3(-3.6, 0, -0.7)
	kit(Vector2(back.x, back.z), 95.0, false, true)
	strew("metal_jerrycan_green", tent_xf * Vector3(3.85, 0, 2.2), 25)


func _motor_pool() -> void:
	# The lorries along the north side under their net, the field cars next
	# to them; fuel and the fitters along the south side.
	for x: float in [167.0, 174.5, 182.0]:
		vehicle("truck", Vector2(x, 113.0), _clutter_rng.randf_range(-3, 3))
	camo_net(Vector2(174.5, 113.5), 0.0, Vector2(24.0, 8.5), 4.0)
	for x: float in [195.0, 200.5, 206.0]:
		vehicle("jeep", Vector2(x, 113.5), _clutter_rng.randf_range(-6, 6))
	sign_post(Vector2(222.5, 117.5), 90.0, "MOTOR POOL", 0.26)
	for i in 6:
		fuel(ground(164.6 + (i % 3) * 0.75, 133.4 + (i / 3) * 0.8))
	_put("metal_jerrycan", 167.6, 134.6, 20)
	_put("metal_jerrycan", 168.0, 133.7, -40)
	_put("metal_jerrycan_green", 168.5, 134.4, 70)
	sign_post(Vector2(164.0, 131.2), 0.0, "NO SMOKING", 0.2, "paper")
	sign_post(Vector2(170.5, 136.4), 0.0, "FUEL", 0.26)
	bench(ground(188.0, 136.2), 180.0, 2.4)
	_put("metal_tool_chest", 190.6, 136.3, 180)
	_put("old_military_compressor", 184.6, 136.0, 160)
	tyres(ground(193.8, 136.4), 4)
	tyres(ground(194.9, 136.0), 2)
	vehicle("truck", Vector2(205.0, 133.5), -92.0)
	camo_net(Vector2(198.0, 134.5), 0.0, Vector2(22.0, 7.5), 3.9)
	crates(ground(178.0, 135.6), 4)
	crates(ground(212.5, 116.5), 3)
	pallet(ground(176.2, 133.2), 12.0, 3)
	# Where the fitters work: a sheet with their tools on it, a wheel that
	# is off, cans, and the oil every lorry has left where it stood.
	ground_sheet(Vector2(186.0, 134.4), 8.0, Vector2(1.9, 1.3))
	strew("metal_toolbox", ground(186.5, 134.6, 0.03), 40)
	strew("adjustable_wrench", ground(185.6, 134.2, 0.035), 110, Basis(Vector3.RIGHT, PI * 0.5))
	strew("cross_pein_hammer", ground(185.9, 134.8, 0.035), -30, Basis(Vector3.RIGHT, PI * 0.5))
	strew("old_tyre", ground(191.9, 134.5, 0.08), 0, Basis(Vector3.RIGHT, PI * 0.5))
	for can: Vector3 in [Vector3(169.3, 135.0, 15), Vector3(169.8, 134.3, -30), Vector3(170.2, 135.1, 80)]:
		strew("metal_jerrycan_green", ground(can.x, can.y), can.z)
	for stain: Vector3 in [Vector3(167.2, 114.6, 0), Vector3(174.3, 115.2, 40), Vector3(182.2, 114.4, 110), Vector3(200.4, 114.4, 70), Vector3(203.6, 133.8, 20)]:
		floor_decal("stain_%d" % (1 + int(stain.z) % 2), ground(stain.x, stain.y), Vector2(1.4, 1.1), stain.z)
	kit(Vector2(196.8, 111.0), 80.0)
	cover_over("earth", Rect2(160, 109, 58, 28), 0.9)
	cover("earth", Vector2(189, 123), 34.0, 0.8, 0.5)
	probe("MotorPool", ground(189, 123, 3.0), Vector3(64, 9, 34), Vector3.ZERO)


func _laager() -> void:
	# One tank on the track, being made ready; two in their pits behind the
	# spoil, hull down, under nets.
	vehicle("tank_b", Vector2(102.0, 114.0), -92.0)
	vehicle("tank", Vector2(112.0, 138.0), -22.0)
	vehicle("tank", Vector2(90.0, 139.0), 18.0)
	camo_net(Vector2(112.0, 137.0), -22.0, Vector2(8.5, 5.5), 3.6)
	camo_net(Vector2(90.0, 138.0), 18.0, Vector2(8.5, 5.5), 3.6)
	vehicle("truck", Vector2(121.0, 111.5), 88.0)
	crates(ground(108.6, 109.2), 4)
	crates(ground(111.4, 108.6), 3)
	_put("old_military_crate", 106.0, 108.4, 5)
	_put("ammo_box", 104.6, 110.2, 60)
	_put("ammo_box", 105.1, 110.6, 15)
	for i in 3:
		fuel(ground(95.0 + i * 0.78, 108.6))
	_put("metal_jerrycan_green", 97.6, 108.9, 30)
	sandbag_ring(Vector2(133.0, 114.5), 2.5, 270.0, 6)
	cover_over("earth", Rect2(86, 107, 42, 16), 0.9)
	# The tank on the track is being made ready: the cases of what it fired
	# yesterday, the crew's tools on a sheet, their kit, a crate under a
	# tarpaulin.
	shell_cases(Vector2(107.6, 116.6), 7)
	ground_sheet(Vector2(99.4, 117.6), 20.0, Vector2(1.7, 1.2))
	strew("sledgehammer_01", ground(99.2, 117.8, 0.05), 60, Basis(Vector3.RIGHT, PI * 0.5))
	strew("crowbar_01", ground(99.8, 117.3, 0.035), 15, Basis(Vector3.RIGHT, PI * 0.5))
	kit(Vector2(97.2, 111.2), 75.0)
	kit(Vector2(115.2, 133.6), 20.0, true, false)
	helmet(ground(98.2, 117.9, 0.02), 130.0)
	tarpaulin(ground(106.0, 108.4), 5.0, Vector3(1.12, 0.4, 0.86))
	floor_decal("stain_2", ground(102.6, 114.4), Vector2(1.8, 1.3), 10.0)
	cover("earth", Vector2(106, 118), 26.0, 0.8, 0.5)
	probe("Laager", ground(106, 122, 3.0), Vector3(60, 9, 44), Vector3.ZERO)


func _route_through() -> void:
	# Round the table in the tent, which is where the map lies.
	var map := TENT + Vector2(TABLE.x, TABLE.z)
	# Two in the post of the picket, one who walks the track by it and one
	# under the pines.
	var looks := Vector2(0, 1).rotated(-deg_to_rad(PICKET_LOOKS))
	route_zone("saddle", "the saddle", _ground_box(240, 144, 332, 166), [
		guard("grunt", PICKET - looks * 0.2 - looks.orthogonal() * 0.8, Vector2(268, 172), 45.0),
		guard("heavy", PICKET - looks * 0.2 + looks.orthogonal() * 0.8, Vector2(262, 166), 35.0),
		beat("grunt", [Vector2(277.6, 147.0), Vector2(277.0, 158.0)]),
		guard("rusher", Vector2(272.0, 149.5), Vector2(264, 164), 50.0),
	])
	route_zone("bivouac", "the bivouac", _ground_box(240, 98, 332, 144), [
		guard("heavy", map + Vector2(0.2, 1.75), map, 10.0),
		guard("grunt", map + Vector2(-2.2, 0.1), map, 10.0),
		guard("grunt", map + Vector2(2.2, -0.1), map, 10.0),
		guard("rusher", map + Vector2(-1.5, 1.55), map, 10.0),
		beat("grunt", [Vector2(262, 135), Vector2(292, 138), Vector2(303, 114), Vector2(270, 107)], true),
		guard("grunt", Vector2(288.2, 133.6), Vector2(296, 146), 50.0),
	])
	_carry_on("camp", "Camp track", Vector2(236, 121), Vector2(220, 123), 5.5)
	route_zone("motor_pool", "the motor pool", _ground_box(150, 98, 228, 152), [
		beat("grunt", [Vector2(164, 121), Vector2(214, 120), Vector2(214, 129), Vector2(164, 129)], true),
		guard("grunt", Vector2(188.0, 134.0), Vector2(188, 120), 45.0),
		guard("grunt", Vector2(169.8, 131.4), Vector2(190, 130), 45.0),
		guard("rusher", Vector2(201.0, 117.2), Vector2(200, 130), 50.0),
		guard("heavy", Vector2(158.0, 125.0), Vector2(178, 125), 35.0),
		guard("grunt", Vector2(170.5, 119.4), Vector2(186, 126), 45.0),
	])
	route_zone("laager", "the tank laager", _ground_box(58, 98, 150, 152), [
		guard("heavy", Vector2(105.5, 117.6), Vector2(130, 121), 35.0),
		guard("heavy", Vector2(117.0, 133.0), Vector2(138, 126), 35.0),
		beat("grunt", [Vector2(96, 128), Vector2(122, 128)]),
		guard("grunt", Vector2(132.4, 114.8), Vector2(148, 122), 45.0),
		guard("rusher", Vector2(118.2, 108.8), Vector2(136, 116), 50.0),
		guard("grunt", Vector2(95.0, 132.5), Vector2(106, 124), 45.0),
	])
	_carry_on("gap", "The gap", Vector2(52, 104), Vector2(51, 88), 5.5)
