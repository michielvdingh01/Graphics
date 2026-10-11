extends "res://tools/levels/powerhouse/plan.gd"
## What lies around the powerhouse: the ground, the apron in front of the
## great door, the pylon the lines of the switch yard come from, the stacks
## of the boiler house, the wall around the grounds and a skyline beyond it,
## so that the windows do not look out on nothing.


func _describe() -> void:
	in_zone("")
	box("floor", Vector3(38, -0.55, 28), Vector3(260, 1.0, 240), Vector3.ZERO, DETAIL)
	# The apron in front of the great door, with a post either side of it.
	box("concrete", Vector3(81.0, -0.03, 12.0), Vector3(9.0, 0.06, 11.0), Vector3.ZERO, DETAIL | NO_COLLIDE)
	for z: float in [8.9, 15.1]:
		cylinder("steel_yellow", Vector3(77.2, 0, z), 0.09, 1.0, DETAIL)
	container("container_green", Vector3(88.0, 0, 3.0), false, DETAIL)
	container("container_grey", Vector3(86.5, 0, 22.0), true, DETAIL)

	# The pylon beyond the north wall, and the lines that go on from it.
	lattice_mast(Vector3(29.0, 0, -27.0), 15.0, 1.3)
	lattice_girder(Vector3(24.6, 13.3, -27.0), Vector3(33.4, 13.3, -27.0), 0.5)
	for i in 3:
		var arm := Vector3(29.0 + (i - 1) * 3.4, 13.0, -27.0)
		wire(arm, arm + Vector3(-30.0, 3.0, -90.0), 5.0, 0.02)

	# The turbine hall stands higher than the wall of the switch yard: its
	# west gable and the edge of its roof, as the yard sees them over that wall.
	wall_above("turbine_hall", WEST, _floor_plan["switch_yard"].height + 0.12)

	# The stacks of the two boilers, where their flues come through the roof.
	var roof: float = _floor_plan["boiler_house"].height + 0.3
	for flue: Vector3 in [spot_in("boiler_house", 17.22, 6.0, roof), spot_in("boiler_house", 19.22, 12.0, roof)]:
		cylinder("steel", flue, 0.4, 9.0, DETAIL | NO_COLLIDE, Vector3.ZERO, 0.36, 16)

	# The wall around the grounds.
	box("brick", Vector3(38, 1.6, -40), Vector3(190, 3.2, 0.5), Vector3.ZERO, DETAIL)
	box("brick", Vector3(38, 1.6, 82), Vector3(190, 3.2, 0.5), Vector3.ZERO, DETAIL)
	box("brick", Vector3(-57, 1.6, 21), Vector3(0.5, 3.2, 122), Vector3.ZERO, DETAIL)
	box("brick", Vector3(133, 1.6, 21), Vector3(0.5, 3.2, 122), Vector3.ZERO, DETAIL)
	# And what stands beyond it.
	box("brick", Vector3(-20, 7, -62), Vector3(44, 14, 20), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("concrete", Vector3(70, 10, -66), Vector3(34, 20, 24), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("roof", Vector3(120, 5, -56), Vector3(26, 10, 30), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("concrete", Vector3(-82, 8, 10), Vector3(22, 16, 44), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("brick", Vector3(-78, 6, 66), Vector3(26, 12, 24), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("roof", Vector3(20, 5, 104), Vector3(70, 10, 24), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("concrete", Vector3(158, 9, 30), Vector3(24, 18, 56), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("brick", Vector3(100, 7, 104), Vector3(40, 14, 22), Vector3.ZERO, DETAIL | NO_COLLIDE)
	# The great chimney of the works, and a cooling tower: a cone with its
	# top cut off.
	cylinder("brick", Vector3(-30, 0, 80), 2.6, 48.0, DETAIL | NO_COLLIDE, Vector3.ZERO, 1.6, 20)
	cylinder("concrete", Vector3(112, 0, 70), 15.0, 30.0, DETAIL | NO_COLLIDE, Vector3.ZERO, 9.5, 28)
	by_position()
