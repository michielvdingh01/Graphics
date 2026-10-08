extends "res://tools/levels/factory.gd"
## Everything that is built in code side by side on a slab under an open sky,
## to judge a prefab from close by without rebuilding and rebaking a level.
## Build with tools/build_level.sh showroom, then look around with
## tools/benchmark.sh --quick --scene=res://scenes/showroom.tscn --at="0,1.7,9,0,-5"


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

	_tank(Vector3(3, 0, -3), 20, -55, -100)
	_tank(Vector3(7, 0, -3), -10, 55)
	_press(Vector3(13, 0, -2))
	_lathe(Vector3(20, 0, -2))
