extends "res://tools/kit.gd"
## Everything that is built in code side by side on a slab under an open sky,
## to judge a prefab from close by without rebuilding and rebaking a level.
## Build with tools/build_level.sh showroom, then look around with
## tools/benchmark.sh --quick --scene=res://scenes/showroom.tscn --at="0,1.7,9,0,-5"
##
## Along the wall at the back, from west to east: containers, a roller door,
## pallets and bags, railings, lockers and cupboards, the tanks, the press,
## the lathe, two pumps under a board of gauges, and the boiler. In front of
## them, on the south side of the slab: the workbenches against a wall of
## their own, and a partition with a doorway and a notice board. Further
## east on that side the turbo-alternator, and to the west of the benches
## what a substation is made of: a transformer under the lines from a mast,
## a row of switchgear, and the desk and the panel of a control room. The
## crane needs a hall to span and is only to be seen in the factory.
##
## South of all that, on a slab of their own: a wall with what stands and
## hangs against one (cabinets, a counter, shelving, a bench with hooks, a
## sink, a range, a radiator, a board, a plate, a lamp, a tray of cables, a
## pipe, a rainwater pipe and a buttress), in front of it what stands free
## (a table, a fitter's bench, screens, a rack of plate, cable drums, packing
## cases, a spray booth and piles of crates), and to the east four sheds
## that are open to the north, one under each roof: trusses, a sawtooth,
## steel beams and a slab on beams, with pipes, ducts and sprinklers under
## them. Look at those with
## tools/benchmark.sh --quick --scene=res://scenes/showroom.tscn --at="-14,1.7,31,180,-3"


func _level_name() -> String:
	return "showroom"


func _describe() -> void:
	box("floor", Vector3(0, -0.25, 0), Vector3(70, 0.5, 30))
	_power()
	wall("brick", true, -6.25, 0.5, -35.0, 35.0, 0.0, 6.0, [])

	container("container_red", Vector3(-26, 0, 0), true)
	container("container_blue", Vector3(-19.5, 0, -1), false)
	container("container_orange", Vector3(-26, 2.6, 0.2), true)
	roller_door(Vector3(-12, 2.0, -5.95), Vector3.BACK, Vector2(4.0, 4.0))
	pallet(Vector3(-13.5, 0, 0), 15.0, 5)
	pallet(Vector3(-11.8, 0, 1.0), -20.0, 1)
	bags(Vector3(-10.0, 0, 0), 5.0, 3)
	railing(Vector3(-8, 0, -2), Vector3(-4, 0, -2))
	railing(Vector3(-4, 0, -2), Vector3(-1.5, 1.5, -2))
	lockers("machine_blue", Vector3(-6, 0, -5.7), 0, 7, {2: 70.0, 5: 12.0})
	cupboard("machine", Vector3(-2.5, 0, -5.65), 0, Vector3(0.98, 1.9, 0.6))
	cupboard("machine", Vector3(-1.2, 0, -5.8), 0, Vector3(1.2, 1.8, 0.35))

	tank(Vector3(3, 0, -3), 20, -55, -11.75, -100)
	tank(Vector3(7, 0, -3), -10, 55, -11.75)
	press(Vector3(13, 0, -2))
	lathe(Vector3(20, 0, -2))

	pump(Vector3(24.3, 0, -3.2), 0)
	pump(Vector3(25.5, 0, -3.2), 0)
	gauge_board(Vector3(24.9, 1.75, -6.0), Vector3.BACK)
	# The boiler's steam main runs south to a wall that is not there, and its
	# flue ends where a roof would be.
	boiler(Vector3(31.0, 0, -1.5), 6.0, 7.0)

	wall("brick", true, 12.25, 0.5, -4.0, 5.0, 0.0, 3.0, [])
	workbench(Vector3(0.6, 0, 11.63), 12.0)
	wall("plaster_dado", false, 9.0, 0.2, 7.0, 13.0, 0.0, 3.0, [[8.2, 9.8, 0.0, 2.2]])
	doorway(Transform3D(Basis(), Vector3(9.0, 0, 9.0)), 0.2, 95.0, 30.0, "1")
	notice_board(Vector3(9.1, 1.62, 11.8))
	_fittings()
	_roofs()


## What makes electricity and sends it off, see tools/kit/power.gd.
func _power() -> void:
	turbine(Vector3(24.0, 0, 9.0), 0, "1")
	var tips := transformer(Vector3(-22.0, 0, 9.0), 0, "T1")
	lattice_mast(Vector3(-27.0, 0, 12.5), 8.5)
	lattice_mast(Vector3(-17.0, 0, 12.5), 8.5)
	lattice_girder(Vector3(-27.0, 8.2, 12.5), Vector3(-17.0, 8.2, 12.5))
	for i in 3:
		var hung := insulator_string(Vector3(-22.0 + (i - 1) * 0.9, 7.9, 12.5))
		wire(hung, tips[i], 0.35)
	switchboard(Vector3(-13.0, 0, 8.0), 0, 5)
	switchboard(Vector3(-7.0, 0, 11.5), 180, 4, true)
	control_desk(Vector3(-7.0, 0, 9.0), 0)
	cable_ladder(Vector3(-15.0, 2.6, 6.6), Vector3(-5.0, 2.6, 6.6), 3.2)


## What stands and hangs against a wall, and what stands free in front of
## it: see tools/kit/services.gd and tools/kit/furniture.gd.
func _fittings() -> void:
	box("floor", Vector3(0, -0.25, 28), Vector3(70, 0.5, 26))
	wall("plaster_dado", true, 17.0, 0.2, -34.0, 2.0, 0.0, 3.4, [[-3.2, -1.6, 0.0, 2.2]])
	var face := 17.1
	filing_cabinets(Vector3(-32.0, 0, face + 0.34), 0, 3)
	counter(Vector3(-28.6, 0, face + 0.38), 0, 2.4)
	shelving(Vector3(-25.2, 0, face + 0.26), 0, 2.0)
	shelving(Vector3(-22.8, 0, face + 0.26), 0, 2.0, 2.1, true)
	slat_bench(Vector3(-20.0, 0, face + 0.2), 0, 1.8, true)
	wash_trough(Vector3(-17.4, 0, face + 0.27), 0, 1.8)
	kitchen_range(Vector3(-14.4, 0, face + 0.45), 0, 3.4)
	radiator(Vector3(-11.6, 0, face), Vector3.BACK, 14)
	pin_board(Vector3(-9.6, 1.6, face), Vector3.BACK)
	hang("wall_clock", Vector3(-8.4, 2.3, face), Vector3.BACK)
	hang("medical_box", Vector3(-7.6, 1.6, face), Vector3.BACK, Basis(Vector3.RIGHT, PI * 0.5))
	hang("clipboard", Vector3(-6.9, 1.5, face), Vector3.BACK, Basis(Vector3.RIGHT, PI * 0.5))
	hang("dartboard", Vector3(-6.0, 1.73, face), Vector3.BACK)
	hang("security_camera_01", Vector3(-5.0, 2.6, face), Vector3.BACK)
	switch_drop(Vector3(-3.6, 3.3, face), Vector3.BACK)
	sign_plate(Vector3(-2.4, 2.5, face), Vector3.BACK, "WORKSHOP")
	wall_lamp(Vector3(-2.4, 2.95, face), Vector3.BACK)
	sign_plate(Vector3(-0.2, 2.2, face), Vector3.BACK, "NO SMOKING", 0.24, "enamel_red")
	cable_tray(Vector3(-33.5, 2.8, face), Vector3(-12.0, 2.8, face), Vector3.BACK)
	wall_pipe(Vector3(-11.0, 2.8, face), Vector3(1.5, 2.8, face), Vector3.BACK)
	wall("brick", true, 17.0, 0.4, 2.0, 7.0, 0.0, 6.0, [])
	plinth(Vector3(2.0, 0, 17.2), Vector3(7.0, 0, 17.2), Vector3.BACK)
	pier(Vector3(3.2, 0, 17.2), Vector3.BACK, 5.6)
	corbel(Vector3(3.2, 5.8, 17.2), Vector3.BACK, 0.3)
	buttress(Vector3(5.6, 0, 17.2), Vector3.BACK, 6.0)
	downpipe(Vector3(6.6, 0, 17.2), Vector3.BACK, 6.0)

	table(Vector3(-31.5, 0, 22.5), 10)
	bench(Vector3(-28.0, 0, 22.5), -5)
	screens(Vector3(-23.5, 0, 22.5), 0, 3)
	plate_rack(Vector3(-18.5, 0, 22.8), 0)
	cable_drum(Vector3(-14.6, 0, 22.5), 0, 2.0, 1.1)
	cable_drum(Vector3(-12.6, 0, 22.8), 70, 1.5, 1.0)
	case(Vector3(-10.0, 0, 22.5), 15, Vector3(1.6, 1.3, 1.1))
	cases(Vector3(-6.0, 0, 22.5), 0, 3.7)
	spray_booth(Vector3(-0.6, 0, 22.2), 0, 3.4)
	pile("industrial_pastic_container", Vector3(3.2, 0, 22.5), 0, 4)
	pile("plastic_crate_02", Vector3(4.2, 0, 22.5), 10, 5)
	place("covered_car", Vector3(-30.0, 0, 28.0), 80)
	place("portable_generator", Vector3(-25.5, 0, 27.5), 0)
	place("barrel_stove", Vector3(-24.0, 0, 27.5), 0)
	place("metal_trash_can", Vector3(-21.8, 0, 27.5), 0)
	place("old_military_crate", Vector3(-19.0, 0, 27.5), 0)
	place("dining_table", Vector3(-15.5, 0, 27.5), 0)
	place("SchoolChair_01", Vector3(-15.5, 0, 28.7), 180)
	place("painted_wooden_table", Vector3(-12.0, 0, 27.5), 0)
	place("metal_stool_03", Vector3(-12.0, 0, 28.6), 180)
	place("painted_wooden_bench", Vector3(-9.6, 0, 27.5), 0)
	place("painted_wooden_cabinet", Vector3(-7.8, 0, 27.5), 0)
	prop("vintage_microwave", Transform3D(Basis(), Vector3(-7.8, _model("painted_wooden_cabinet").box.size.y, 27.5)), 0.55)
	place("wooden_bookshelf_worn", Vector3(-6.0, 0, 27.5), 0)
	place("Shelf_01", Vector3(-4.6, 0, 27.5), 0)
	place("steel_frame_shelves_01", Vector3(-3.2, 0, 27.5), 0, true, 0.1)
	place("CoffeeCart_01", Vector3(-0.4, 0, 27.5), 0)
	place("Television_01", Vector3(1.8, 0, 27.5), 0)
	place("boombox", Vector3(2.8, 0, 27.5), 0)


## A shed under each of the roofs of tools/kit/structure.gd, open to the
## north, with what runs under a ceiling in the first two.
func _roofs() -> void:
	var sheds: Array = [
		["trusses", Rect2(9, 18, 12, 10), 5.0, {}],
		["sawtooth", Rect2(21, 18, 12, 12), 5.0, {"glazed": SOUTH}],
		["beams", Rect2(9, 29, 12, 9), 4.0, {}],
		["slab", Rect2(21, 30, 12, 8), 4.0, {}],
	]
	for shed: Array in sheds:
		var area: Rect2 = shed[1]
		var high: float = shed[2]
		var made := roof(shed[0], area, 0.4, high, shed[3])
		wall("brick", true, area.end.y - 0.2, 0.4, area.position.x, area.end.x, 0.0, high, [])
		for x: float in [area.position.x + 0.2, area.end.x - 0.2]:
			wall("brick", false, x, 0.4, area.position.y + 0.4, area.end.y - 0.4, 0.0, high, [])
		# The north side is open but for a post at either end and a beam over them.
		for x: float in [area.position.x + 0.2, area.end.x - 0.2]:
			box("concrete", Vector3(x, high * 0.5, area.position.y + 0.2), Vector3(0.4, high, 0.4))
		for bearing: Dictionary in made.bearings:
			if absf(bearing.inwards.z) < 0.5 or bearing.inwards.z < 0.0:
				pier(Vector3(bearing.at.x, 0, bearing.at.z), bearing.inwards, bearing.at.y)
		lamp(Vector3(area.get_center().x, high - 0.9, area.get_center().y), roof_height(made, area.get_center().x, area.get_center().y), true, false)
	round_duct(Vector3(10.0, 4.5, 21.5), Vector3(20.0, 4.5, 21.5), 4.9, 0.26, 2)
	sprinkler_line(Vector3(9.6, 4.75, 25.5), Vector3(20.4, 4.75, 25.5), 5.0)
	pipe_run([Vector3(21.6, 4.1, 21.0), Vector3(30.0, 4.1, 21.0), Vector3(30.0, 4.1, 27.0), Vector3(30.0, 0.0, 27.0)], 0.1, "tank", 5.0)
	pipe_valve(Vector3(30.0, 1.4, 27.0), Vector3.UP, Vector3.LEFT, 0.1)
	duct_run(Vector3(9.6, 3.7, 33.0), Vector3(20.4, 3.7, 33.0), 4.0, Vector2(0.45, 0.3), 2)
	cable_ladder(Vector3(21.6, 3.6, 34.0), Vector3(32.4, 3.6, 34.0), 4.0)
