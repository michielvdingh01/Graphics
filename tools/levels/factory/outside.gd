extends "res://tools/levels/factory/plan.gd"
## What lies around the factory: the yard with its wall and gate, and a
## skyline, so that the windows do not look out on nothing.


func _describe() -> void:
	# The yard and the skyline surround every zone and belong to none.
	in_zone("")
	box("floor", Vector3(5, -0.55, 0), Vector3(160, 1.0, 160), Vector3.ZERO, DETAIL)
	# Yard wall and a skyline so the windows do not look out on nothing.
	box("brick", Vector3(5, 1.6, 34), Vector3(110, 3.2, 0.5), Vector3.ZERO, DETAIL)
	# The west wall has the gate of the yard in it, straight across from the
	# loading door: what the player sees when that door goes up.
	for side: float in [-1.0, 1.0]:
		box("brick", Vector3(-50, 1.6, side * 19.0), Vector3(0.5, 3.2, 30.0), Vector3.ZERO, DETAIL)
		box("concrete", Vector3(-50, 1.9, side * 3.7), Vector3(0.7, 3.8, 0.7), Vector3.ZERO, DETAIL)
		box("concrete", Vector3(-50, 3.86, side * 3.7), Vector3(0.9, 0.12, 0.9), Vector3.ZERO, DETAIL | NO_COLLIDE)
	# The apron in front of the loading door, level with the floor of the hall,
	# with a post either side of the door to keep lorries off the frame.
	box("concrete", Vector3(-HX - 5.0, -0.03, 0.0), Vector3(8.0, 0.06, 9.0), Vector3.ZERO, DETAIL | NO_COLLIDE)
	for z: float in [-3.1, 3.1]:
		cylinder("steel_yellow", Vector3(-HX - 1.3, 0, z), 0.09, 1.0, DETAIL)
	container("container_red", Vector3(-HX - 7.5, 0, -8.0), true, DETAIL)
	container("container_grey", Vector3(-HX - 11.0, 0, 9.5), false, DETAIL)
	box("brick", Vector3(60, 1.6, 0), Vector3(0.5, 3.2, 68), Vector3.ZERO, DETAIL)
	box("brick", Vector3(5, 1.6, -34), Vector3(110, 3.2, 0.5), Vector3.ZERO, DETAIL)
	box("brick", Vector3(34, 5, 52), Vector3(26, 10, 16), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("roof", Vector3(-30, 4, 56), Vector3(30, 8, 18), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("concrete", Vector3(52, 7, 14), Vector3(14, 14, 20), Vector3.ZERO, DETAIL | NO_COLLIDE)
	cylinder("brick", Vector3(42, 0, 50), 2.2, 38.0, DETAIL | NO_COLLIDE, Vector3.ZERO, 1.4, 20)
	container("container_blue", Vector3(38, 0, 9), false, DETAIL)
	# The stack of the boiler house, where its flue comes through the roof.
	cylinder("steel", Vector3(BOILER.x + 3.22, BOILER_H + 0.3, BOILER.z), 0.4, 9.0, DETAIL | NO_COLLIDE, Vector3.ZERO, 0.36, 16)
	by_position()
