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
## their own, and a partition with a doorway and a notice board. The crane
## needs a hall to span and is only to be seen in the factory.


func _level_name() -> String:
	return "showroom"


func _describe() -> void:
	box("floor", Vector3(0, -0.25, 0), Vector3(70, 0.5, 30))
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
