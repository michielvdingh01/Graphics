extends "res://tools/levels/factory/plan.gd"
## The annex of the factory, built against the east wall of the hall: a
## corridor along that wall, with a storeroom and a locker room off it. The
## storeroom has the door to the passage in its north wall.


func _describe() -> void:
	_shut_hall_doorways(HX + 0.51)
	_rooms()
	_probes()
	_dirt()
	# On the way in from the boiler house: out of the storeroom into the corridor.
	floor_arrow(Vector2(22.0, -9.0), Vector2.LEFT)


## Out of the passage into the storeroom and up the corridor.
func _route_through() -> void:
	# Two come out of the locker room and one in from the hall.
	route_zone("annex", "the annex", AABB(Vector3(20.56, 0, -12.0), Vector3(9.94, 3.4, 6.7)), [
		["grunt", Vector3(27.5, 0, -2.6)], ["grunt", Vector3(25.8, 0, -0.6)], ["rusher", Vector3(18.6, 0, -1.2)],
	])
	route_checkpoint("corridor", "Corridor", Vector3(22.0, 0, -9.0), Vector3(19.0, 0, -9.0), AABB(Vector3(20.56, 0, -12.0), Vector3(2.94, 3.4, 14.0)))


## The shell, the corridor with what runs under its ceiling, and the two
## rooms: a storeroom to the north and a locker room to the south.
func _rooms() -> void:
	var x0 := HX + 0.5
	var x1 := 30.5
	var z0 := -HZ
	var z1 := 2.0
	var height := 3.4
	box("floor", Vector3(25.7, -0.25, -5.0), Vector3(10.4, 0.5, 14.8))
	wall(WALL, true, z0 - 0.2, 0.4, x0, x1 + 0.4, 0.0, height, [PASSAGE_DOORWAY])
	wall(WALL, false, x1 + 0.2, 0.4, z0, z1, 0.0, height, [])
	wall(WALL, true, z1 + 0.2, 0.4, x0, x1 + 0.4, 0.0, height, [[25.5, 29.0, 1.1, 2.6]])
	_mullions(Vector3(27.25, 1.85, z1 + 0.2), 3.5, 1.5, true, 0.875)
	box("concrete", Vector3(27.25, 1.06, z1 + 0.1), Vector3(3.7, 0.08, 0.6))
	box("concrete", Vector3((x0 + x1 + 0.4) * 0.5, height + 0.15, (z0 + z1) * 0.5), Vector3(x1 + 0.4 - x0, 0.3, z1 - z0 + 0.8))
	# The hall side of the annex is brick; give it a plaster lining.
	wall(WALL, false, x0 + 0.03, 0.06, z0, z1, 0.0, height, HALL_DOORWAYS)
	# Corridor partition and the wall between the two rooms.
	wall(WALL, false, 23.6, 0.2, z0, z1, 0.0, height, [[-9.8, -8.2, 0.0, 2.2], [-2.8, -1.2, 0.0, 2.2]])
	wall(WALL, true, -5.2, 0.2, 23.7, x1, 0.0, height, [])
	_door(-9.0, 95.0, 166.0, "1")
	_door(-2.0, 100.0, 168.0, "2")
	# The door to the passage, in the north wall of the storeroom: its leaves
	# stand open against the walls of the passage.
	doorway(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(24.7, 0, z0 - 0.2)), 0.4, 97.0, 86.0)
	bake_blocker(Vector3(24.7, 1.15, z0 - 0.39), Vector3(1.8, 2.3, 0.02))
	corridor_services(z0, z1, height, 21.52, 23.02, [-9.4, -4.6, -0.2], 23.47, [-9.0, -2.0])
	notice_board(Vector3(x0 + 0.06, 1.62, -4.4))

	for z in [-10.0, -5.0, 0.0]:
		tube(Vector3(22.0, height - 0.08, z), false, z != -5.0)
	tube(Vector3(27.0, height - 0.08, -8.6), true, true)
	tube(Vector3(27.0, height - 0.08, -1.6), true, false)

	# Corridor: pipes under the ceiling and a few barrels.
	cylinder("pipe", Vector3(20.9, 3.0, z0), 0.09, z1 - z0, NO_COLLIDE, Vector3(90, 0, 0))
	cylinder("steel", Vector3(21.15, 3.1, z0), 0.05, z1 - z0, NO_COLLIDE, Vector3(90, 0, 0))
	barrel(Vector3(23.1, 0, -11.4))
	barrel(Vector3(22.4, 0, -11.5))
	cupboard("machine", Vector3(23.3, 0, -5.5), -90, Vector3(1.2, 1.8, 0.35))

	# Room A: storage.
	shelf(Vector3(27.0, 0, -11.6), 0, true)
	shelf(Vector3(30.1, 0, -8.5), -90, false)
	crates(Vector3(25.5, 0, -6.6), 4)
	pallet(Vector3(28.6, 0, -6.4), 10.0, 2)

	# Room B: lockers, desk and the window.
	lockers("machine_blue", Vector3(30.2, 0, -3.56), -90, 7, {2: 70.0, 5: 12.0})
	place(DESK, Vector3(27.2, 0, 1.45), 180)
	crates(Vector3(24.6, 0, -4.2), 2)


## Double steel doors in the partition between the corridor and a room, left
## standing open into the room. `z` is the middle of the doorway; the angles
## are how far the north leaf and the south leaf have swung. The plate on the
## corridor wall carries `number`.
func _door(z: float, north_deg: float, south_deg: float, number: String) -> void:
	doorway(Transform3D(Basis(), Vector3(23.6, 0, z)), 0.2, north_deg, south_deg, number)


func _probes() -> void:
	probe("Corridor", Vector3(22.0, 1.7, -5.0), Vector3(3.0, 3.4, 14.0), Vector3.ZERO)
	probe("RoomA", Vector3(27.1, 1.7, -8.65), Vector3(6.8, 3.4, 6.7), Vector3(0, 0, 0.8))
	probe("RoomB", Vector3(27.1, 1.7, -1.55), Vector3(6.8, 3.4, 7.1), Vector3.ZERO)


## The annex has seen better days too.
func _dirt() -> void:
	wall_decal(_pick("leak"), Vector3(20.56, 2.0, -6.0), Vector3.RIGHT, 1.4, 2.8, Color(1, 1, 1, 0.8))
	wall_decal(_pick("leak"), Vector3(23.48, 2.1, -4.0), Vector3.LEFT, 1.2, 2.6, Color(1, 1, 1, 0.8))
	wall_decal(_pick("leak"), Vector3(27.0, 2.0, -11.98), Vector3.BACK, 1.6, 2.8, Color(1, 1, 1, 0.8))
	wall_decal(_pick("leak"), Vector3(30.48, 2.0, 0.6), Vector3.LEFT, 1.4, 2.8, Color(1, 1, 1, 0.8))
	wall_decal("grime", Vector3(20.6, 0.5, -5.0), Vector3.RIGHT, 13.0, 1.0)
	wall_decal("grime", Vector3(23.46, 0.5, -5.0), Vector3.LEFT, 13.0, 1.0)
	floor_decal("stain_2", Vector3(22.0, 0, -8.5), Vector2(2.2, 3.5))
	floor_decal("stain_1", Vector3(27.5, 0, -8.0), Vector2(3.0, 3.0), 45)
