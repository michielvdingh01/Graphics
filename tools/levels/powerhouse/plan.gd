extends "res://tools/kit.gd"
## The plan of the powerhouse: the power station of the works, laid out as
## rooms (see tools/kit/rooms.gd). The player comes in where the power goes
## out and works his way back to where it is made: from the stores through
## the switch room into the switch yard with its transformers, round by the
## pump house and the workshop into the boiler house, and by the control room
## into the turbine hall, which is the way out.
##
##      0             16                         43                           76
##    0 +-------------+--------------------------+----------------------------+
##      |  receiving  |                          |                            |
##    9 +-------------+       switch yard        |                            |
##   12 +-cable corr.-+                          |        turbine hall        = out
##      | switch room |                          |                            |
##   24 +-----------+-+-----------+--------------+-----------+----------------+
##                  |  workshop   |  pump house  |  control  |
##   34             |             |              +-----------+
##   38       +-----+-+-----------+--------------+--passage--+
##        +---+       |                             |
##        | fuel      |        boiler house         |
##        | store     |                             |
##   52   +-----------+                             |
##   56               +-----------------------------+
##
## The way through is one line: receiving, cable corridor, switch room,
## switch yard, pump house, workshop, boiler house, passage, control room,
## turbine hall. Only the fuel store lies off it, and is fought over together
## with the boiler house it opens on.


func _level_name() -> String:
	return "powerhouse"


func _plan() -> void:
	# Set to true while the powerhouse is being laid out, to walk and fight
	# through it before anything is hung, dirtied or stood about.
	_bare = false
	_detail_inside = AABB(Vector3(-0.5, 0, -0.5), Vector3(77.0, 14.5, 57.0))

	# The west range: where the power leaves.
	room("receiving", "storage", Rect2(0, 0, 16, 9), 4.0)
	room("cable_corridor", "corridor", Rect2(0, 9, 16, 3), 3.0)
	room("switch_room", "plant", Rect2(0, 12, 16, 12), 5.0)
	room("switch_yard", "yard", Rect2(16, 0, 27, 24), 7.0)
	# South of the yard, and the boiler house south of that.
	# The pump house has pipes enough of its own under its roof.
	room("pump_house", "plant", Rect2(29, 24, 14, 14), 6.5, {"mains": false})
	room("workshop", "hall", Rect2(14, 24, 15, 14), 6.5)
	# The beams of the boiler house leave the two flues between them.
	room("boiler_house", "plant", Rect2(16, 38, 30, 18), 9.0, {"bay": 5.0})
	room("fuel_store", "storage", Rect2(4, 40, 12, 12), 4.0)
	# The east range: where it is made.
	room("passage", "corridor", Rect2(43, 34, 12, 4), 3.0)
	room("control_room", "control", Rect2(43, 24, 12, 10), 3.6)
	# The trusses of the turbine hall stand between its windows, and every
	# bay of its roof has a skylight: the hall the level ends in is the
	# lightest of them.
	room("turbine_hall", "hall", Rect2(43, 0, 33, 24), 10.0, {"lines": [45.6, 53.5, 62.3, 69.0], "glass": "all"})

	# In the order of the way through: a checkpoint looks at the last door
	# of its room.
	door("receiving", "cable_corridor", 4.0)
	door("cable_corridor", "switch_room", 12.0)
	door("switch_room", "switch_yard", 18.0, 2.4, 2.6)
	door("switch_yard", "pump_house", 37.0, 3.0, 3.0)
	# Through the pump house and the workshop from corner to corner, and
	# into the boiler house well to the west: with these three doors in one
	# line, whoever stands in the yard would have the boiler house drawn.
	door("pump_house", "workshop", 35.5, 2.4, 2.6)
	door("workshop", "boiler_house", 18.0, 2.4, 2.6)
	door("boiler_house", "fuel_store", 46.0)
	# The passage turns the way to the control room twice, so that the
	# boiler house and the turbine hall are never drawn together.
	door("boiler_house", "passage", 44.5)
	door("passage", "control_room", 53.0)
	door("control_room", "turbine_hall", 45.5, 2.4, 2.6)

	# The evening sun stands low in the south-south-west: it comes in by the
	# windows that face south and west.
	window("receiving", WEST, 4.5, 3.0)
	window("receiving", NORTH, 12.0, 3.0, 2.0, 3.4)
	for z: float in [15.5, 20.5]:
		window("switch_room", WEST, z, 2.5, 2.6, 4.2)
	for z: float in [27.5, 33.5]:
		window("workshop", WEST, z, 3.0, 1.4, 4.6)
	window("fuel_store", WEST, 46.0, 2.5, 2.0, 3.4)
	window("fuel_store", SOUTH, 10.0, 2.5, 2.0, 3.4)
	# Either side of where the two steam mains go through the wall.
	for x: float in [20.5, 25.5, 36.5, 41.5]:
		window("boiler_house", SOUTH, x, 3.0, 3.0, 7.6)
	# Over the roof of the fuel store.
	for z: float in [43.0, 50.0]:
		window("boiler_house", WEST, z, 3.0, 5.0, 8.0)
	window("control_room", EAST, 31.0, 4.0, 1.0, 2.6)
	for x: float in [49.0, 57.0, 65.0, 72.0]:
		window("turbine_hall", NORTH, x, 4.0, 4.0, 8.5)
	for z: float in [4.5, 19.5]:
		window("turbine_hall", EAST, z, 4.0, 4.0, 8.5)
	for x: float in [59.5, 66.0, 72.5]:
		window("turbine_hall", SOUTH, x, 4.0, 4.0, 8.5)
	# And one over the roof of the control room.
	window("turbine_hall", SOUTH, 50.0, 4.0, 5.0, 8.5)

	# What goes in by hand: see the file of each of these rooms. The first
	# of a room is what the player should see when he comes in, and gets a
	# lamp that burns.
	keep_clear("receiving", Rect2(1.0, 0.2, 8.4, 3.0))
	keep_clear("switch_room", Rect2(1.4, 14.8, 8.6, 1.6))
	keep_clear("switch_room", Rect2(1.4, 19.6, 8.6, 1.6))
	keep_clear("switch_yard", Rect2(16.4, 0.4, 26.2, 9.6))
	# The starters of the pump house are what whoever comes in from the yard
	# sees: their row comes first, and has the lamp.
	keep_clear("pump_house", Rect2(33.2, 27.6, 7.6, 1.2))
	keep_clear("pump_house", Rect2(31.4, 32.2, 6.2, 3.2))
	keep_clear("pump_house", Rect2(39.4, 30.8, 3.2, 3.2))
	keep_clear("pump_house", Rect2(37.6, 34.2, 3.2, 3.2))
	keep_clear("pump_house", Rect2(29.6, 26.0, 2.0, 4.6))
	keep_clear("workshop", Rect2(17.6, 25.6, 7.0, 2.8))
	keep_clear("workshop", Rect2(24.4, 25.4, 4.0, 4.2))
	keep_clear("workshop", Rect2(20.0, 36.4, 6.0, 1.2))
	keep_clear("boiler_house", Rect2(25.6, 41.8, 9.0, 4.4))
	keep_clear("boiler_house", Rect2(27.6, 47.8, 9.0, 4.4))
	keep_clear("boiler_house", Rect2(21.6, 38.4, 4.4, 2.6))
	keep_clear("boiler_house", Rect2(37.6, 38.4, 5.0, 3.4))
	keep_clear("fuel_store", Rect2(4.4, 43.2, 2.6, 5.6))
	# The desk of the control room and the way round it to the door, the
	# panel behind it, and what stands along its west wall.
	keep_clear("control_room", Rect2(48.8, 29.8, 6.0, 2.4))
	keep_clear("control_room", Rect2(47.4, 26.6, 7.6, 1.8))
	keep_clear("control_room", Rect2(43.2, 24.9, 0.9, 2.0))
	keep_clear("control_room", Rect2(43.2, 30.0, 0.9, 1.2))
	keep_clear("control_room", Rect2(44.4, 31.8, 2.6, 2.0))
	keep_clear("turbine_hall", Rect2(46.9, 9.8, 11.4, 4.4))
	keep_clear("turbine_hall", Rect2(60.7, 9.8, 11.4, 4.4))
	keep_clear("turbine_hall", Rect2(48.6, 22.4, 1.6, 1.2))
	keep_clear("turbine_hall", Rect2(62.4, 22.4, 1.6, 1.2))
	# The boards of gauges on the walls, the drills and the welder's cart of
	# the workshop, and what stands about in the fuel store.
	keep_clear("switch_room", Rect2(12.8, 23.0, 1.6, 0.6))
	keep_clear("pump_house", Rect2(33.7, 37.0, 1.6, 0.6))
	keep_clear("workshop", Rect2(14.4, 29.9, 1.6, 6.4))
	keep_clear("workshop", Rect2(26.7, 31.9, 1.5, 1.5))
	keep_clear("fuel_store", Rect2(8.4, 49.0, 2.0, 2.2))
	keep_clear("fuel_store", Rect2(12.8, 41.4, 1.8, 1.8))
	keep_clear("fuel_store", Rect2(14.3, 49.6, 1.5, 1.6))
	keep_clear("fuel_store", Rect2(7.1, 42.1, 1.4, 1.4))

	# Where the player carries on from in the yard and in the workshop: kept
	# clear before their fights are planned, which comes first.
	keep_clear("switch_yard", Rect2(27.1, 9.6, 4.8, 4.8))
	keep_clear("workshop", Rect2(20.3, 29.8, 2.4, 2.4))

	start_in("receiving")
	# No fight is larger than those of the factory and the depot, three to
	# six, and the first is as small as the first of the factory. Where a
	# room has its own machines to hide behind, nothing is stood in it for
	# the robots to wait behind.
	fight("switch_room", "the switch room", {"switch_room": ["grunt", "grunt", "rusher"]}, "cable_corridor", false)
	fight("switch_yard", "the switch yard", {"switch_yard": ["grunt", "grunt", "grunt", "rusher"]}, "switch_room")
	checkpoint_in("switch_yard", "Switch yard")
	fight("pump_house", "the pump house", {"pump_house": ["grunt", "grunt", "rusher", "rusher"]}, "switch_yard", false)
	fight("workshop", "the workshop", {"workshop": ["grunt", "grunt", "grunt", "heavy"]}, "pump_house")
	checkpoint_in("workshop", "Workshop")
	fight("boiler_house", "the boiler house", {
		"boiler_house": ["grunt", "grunt", "grunt", "rusher", "heavy"], "fuel_store": ["rusher"],
	}, "workshop", false)
	fight("control_room", "the control room", {"control_room": ["grunt", "grunt", "rusher"]}, "passage", false)
	checkpoint_in("control_room", "Control room")
	fight("turbine_hall", "the turbine hall", {"turbine_hall": ["grunt", "grunt", "grunt", "rusher", "heavy", "heavy"]}, "control_room", false)
	# Out by the great door at the far end of the hall, and on to the dunes.
	exit_through("turbine_hall", EAST, 12.0, "Leave by the great door", "dunes", 5.0, 4.0)
