extends "res://tools/levels/wing/plan.gd"
## What lies around the wing: the yard the loading door opens on, its wall,
## and a skyline, so that the windows do not look out on nothing.


func _describe() -> void:
	in_zone("")
	box("floor", Vector3(13, -0.55, 11), Vector3(150, 1.0, 150), Vector3.ZERO, DETAIL)
	# The apron in front of the loading door, with a post either side of it.
	box("concrete", Vector3(31.5, -0.03, 7.0), Vector3(8.0, 0.06, 9.0), Vector3.ZERO, DETAIL | NO_COLLIDE)
	for z: float in [4.4, 9.6]:
		cylinder("steel_yellow", Vector3(28.2, 0, z), 0.09, 1.0, DETAIL)
	container("container_blue", Vector3(36.0, 0, 15.5), false, DETAIL)
	container("container_orange", Vector3(34.0, 0, -2.5), true, DETAIL)
	# The yard wall, and what stands beyond it.
	box("brick", Vector3(13, 1.6, -22), Vector3(100, 3.2, 0.5), Vector3.ZERO, DETAIL)
	box("brick", Vector3(13, 1.6, 44), Vector3(100, 3.2, 0.5), Vector3.ZERO, DETAIL)
	box("brick", Vector3(-37, 1.6, 11), Vector3(0.5, 3.2, 66), Vector3.ZERO, DETAIL)
	box("brick", Vector3(63, 1.6, 11), Vector3(0.5, 3.2, 66), Vector3.ZERO, DETAIL)
	box("brick", Vector3(-20, 6, -40), Vector3(34, 12, 18), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("concrete", Vector3(40, 8, -44), Vector3(24, 16, 20), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("roof", Vector3(78, 5, 6), Vector3(18, 10, 40), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("concrete", Vector3(-58, 7, 20), Vector3(20, 14, 30), Vector3.ZERO, DETAIL | NO_COLLIDE)
	cylinder("brick", Vector3(70, 0, 48), 2.2, 38.0, DETAIL | NO_COLLIDE, Vector3.ZERO, 1.4, 20)
	# The stack of the boiler room, where its flue comes through the roof.
	var flue := spot_in("plant", 8.22, 6.2, _floor_plan["plant"].height + 0.3)
	cylinder("steel", flue, 0.4, 7.0, DETAIL | NO_COLLIDE, Vector3.ZERO, 0.36, 16)
	by_position()
