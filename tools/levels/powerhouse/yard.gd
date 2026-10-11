extends "res://tools/levels/powerhouse/plan.gd"
## What makes the switch yard a switch yard: three transformers in their bays
## along the north wall, with a blast wall between one and the next, under
## the lines that come in over the wall from the pylon outside and hang from
## a gantry in front of them.

## Where the three transformers stand, from the west wall, and how far from
## the north wall.
const BAYS: Array[float] = [5.5, 13.0, 20.5]
const BAY_Z := 3.7
## How far from the north wall the gantry stands, and how high it is.
const GANTRY_Z := 8.6
const GANTRY_Y := 8.3
## Where the lines come from: the cross arm of the pylon beyond the wall.
const PYLON := Vector3(29.0, 13.0, -27.0)


func _describe() -> void:
	# The gantry: four masts, at the walls and at the heads of the two
	# blast walls, and a girder over them.
	var masts: Array[float] = [1.6, 9.25, 16.75, 25.4]
	for x in masts:
		lattice_mast(spot_in("switch_yard", x, GANTRY_Z), GANTRY_Y + 0.3)
	lattice_girder(spot_in("switch_yard", masts[0], GANTRY_Z, GANTRY_Y), spot_in("switch_yard", masts[3], GANTRY_Z, GANTRY_Y))
	for x: float in [9.25, 16.75]:
		box("concrete", spot_in("switch_yard", x, 3.6, 2.1), Vector3(0.3, 4.2, 6.4))
		box("concrete", spot_in("switch_yard", x, 3.6, 4.23), Vector3(0.42, 0.06, 6.52), Vector3.ZERO, NO_COLLIDE)
		for side: float in [-1.0, 1.0]:
			label("10 kV", spot_in("switch_yard", x + side * 0.151, 5.5, 2.7), Vector3(side, 0, 0), 0.45, Color(0.1, 0.1, 0.1), 0.04)

	# A transformer in every bay. Its three lines come in over the wall, hang
	# from the girder on a string of insulators each, and drop to its bushings.
	for bay in BAYS.size():
		var tips := transformer(spot_in("switch_yard", BAYS[bay], BAY_Z), 0, "T%d" % (bay + 1))
		for phase in 3:
			var aside := (phase - 1) * 0.9
			var hung := insulator_string(spot_in("switch_yard", BAYS[bay] + aside, GANTRY_Z, GANTRY_Y - 0.3))
			wire(hung, tips[phase], 0.35)
			wire(PYLON + Vector3((bay - 1) * 2.6 + aside, 0, 0), hung, 1.3)
		# The cables to the switch room lie in a trench under chequer plate.
		box("deck", spot_in("switch_yard", BAYS[bay] + 1.9, 7.6, 0.008), Vector3(0.6, 0.016, 3.0), Vector3.ZERO, NO_COLLIDE)
	box("deck", spot_in("switch_yard", 11.4, 9.4, 0.008), Vector3(22.0, 0.016, 0.6), Vector3.ZERO, NO_COLLIDE)

	# What the walls say.
	for x: float in [2.6, 23.6]:
		label("DANGER", spot_in("switch_yard", x, 0.41, 3.4), Vector3.BACK, 0.5, Color(0.86, 0.86, 0.82), 0.04)
		wall_decal("warning_1", spot_in("switch_yard", x, 0.41, 2.5), Vector3.BACK, 0.7, 0.7, Color.WHITE, 0.06)
	label("10 kV", spot_in("switch_yard", 0.41, 13.5, 3.6), Vector3.RIGHT, 0.6, Color(0.86, 0.86, 0.82), 0.04)
