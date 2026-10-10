extends "res://tools/levels/works/plan.gd"
## What lies around the works: the ground, the apron in front of the loading
## door, the wall around the grounds and a skyline beyond it, so that the
## windows do not look out on nothing.


func _describe() -> void:
	in_zone("")
	box("floor", Vector3(42, -0.55, 28), Vector3(240, 1.0, 220), Vector3.ZERO, DETAIL)
	# The apron in front of the loading door, with a post either side of it.
	box("concrete", Vector3(89.0, -0.03, 50.5), Vector3(9.0, 0.06, 10.0), Vector3.ZERO, DETAIL | NO_COLLIDE)
	for z: float in [47.4, 53.6]:
		cylinder("steel_yellow", Vector3(85.2, 0, z), 0.09, 1.0, DETAIL)
	container("container_blue", Vector3(95.0, 0, 41.0), false, DETAIL)
	container("container_red", Vector3(93.0, 0, 60.5), true, DETAIL)
	container("container_grey", Vector3(93.2, 2.6, 60.3), true, DETAIL)
	# The wall around the grounds.
	box("brick", Vector3(42, 1.6, -22), Vector3(170, 3.2, 0.5), Vector3.ZERO, DETAIL)
	box("brick", Vector3(42, 1.6, 79), Vector3(170, 3.2, 0.5), Vector3.ZERO, DETAIL)
	box("brick", Vector3(-43, 1.6, 28), Vector3(0.5, 3.2, 101), Vector3.ZERO, DETAIL)
	box("brick", Vector3(127, 1.6, 28), Vector3(0.5, 3.2, 101), Vector3.ZERO, DETAIL)
	# And what stands beyond it.
	box("brick", Vector3(-10, 7, -44), Vector3(40, 14, 20), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("concrete", Vector3(52, 9, -48), Vector3(30, 18, 22), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("roof", Vector3(112, 5, -40), Vector3(26, 10, 30), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("concrete", Vector3(-66, 8, 20), Vector3(22, 16, 40), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("brick", Vector3(-62, 6, 70), Vector3(26, 12, 22), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("roof", Vector3(30, 5, 100), Vector3(60, 10, 22), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("concrete", Vector3(150, 8, 40), Vector3(22, 16, 50), Vector3.ZERO, DETAIL | NO_COLLIDE)
	cylinder("brick", Vector3(138, 0, 92), 2.4, 44.0, DETAIL | NO_COLLIDE, Vector3.ZERO, 1.5, 20)
	cylinder("brick", Vector3(-58, 0, -36), 2.0, 36.0, DETAIL | NO_COLLIDE, Vector3.ZERO, 1.3, 20)
	# The stack of the boiler house, where its flue comes through the roof.
	var flue := spot_in("boiler_house", 10.22, 9.6, _floor_plan["boiler_house"].height + 0.3)
	cylinder("steel", flue, 0.4, 9.0, DETAIL | NO_COLLIDE, Vector3.ZERO, 0.36, 16)
	by_position()
