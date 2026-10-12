extends "res://tools/kit.gd"
## The plan of the works: the grounds between the factory and the depot, laid
## out as rooms (see tools/kit/rooms.gd). Offices along a corridor on the
## west side, stores and a workshop to the north of a yard, a canteen and
## the boiler house to the south of it, and on the east side the assembly
## hall, the paint shop, despatch and the loading bay, which is the way out.
##
##      0      12 15          33            54 57                    84
##    0 +-------+--+-----------+-------------+--+---------------------+
##      | lodge |v |  stores   |             |  |                     |
##    8 +-------+--+           |  workshop   |e |                     |
##      | off a |w +-----+-----+             |a |      assembly       |
##   16 +-------+e |tool |compr|             |s |                     |
##      | off b |s +-----+-----+-------------+t |                     |
##   24 +-------+t |                         |  |                     |
##      |archive|  |           yard          |c +----------+----------+ 30
##   34 +-------+c |                         |o |  paint   | despatch |
##      |lockers|o |                         |r |   shop   |          |
##   41 +-------+--+-----------+-------------+  |          |          |
##      |   south corridor w   | south corr e|  +----------+----------+ 44
##   44 +-----------+----------+------+------+--+                     |
##      |  canteen  | kitchen  |boiler|switch|     loading bay        = out
##   57 +-----------+----------+------+------+  +---------------------+
##
## The way through is one line: lodge, west corridor, stores, tool room,
## compressor room, workshop, yard, south corridor, east corridor, assembly,
## paint shop, despatch, loading bay. The rooms off it are dead ends, fought
## over together with the corridor or the room they open on.


func _level_name() -> String:
	return "works"


func _plan() -> void:
	# Set to true while the works are being laid out, to walk and fight
	# through them before anything is hung, dirtied or stood about.
	_bare = false
	_detail_inside = AABB(Vector3(-0.5, 0, -0.5), Vector3(85.0, 12.0, 58.0))

	# The west range: offices along a corridor.
	room("lodge", "office", Rect2(0, 0, 12, 8), 3.2, {"stock": "lodge"})
	room("vestibule", "corridor", Rect2(12, 0, 3, 8), 3.0)
	room("west_corridor", "corridor", Rect2(12, 8, 3, 33), 3.0)
	room("office_a", "office", Rect2(0, 8, 12, 8), 3.2)
	room("office_b", "office", Rect2(0, 16, 12, 8), 3.2)
	room("archive", "storage", Rect2(0, 24, 12, 10), 3.4, {"stock": "archive"})
	room("locker_room", "changing", Rect2(0, 34, 12, 7), 3.2)
	# The north range, and the yard it stands along.
	room("stores", "storage", Rect2(15, 0, 18, 12), 4.0)
	room("tool_room", "storage", Rect2(15, 12, 9, 9), 3.4, {"stock": "tools"})
	room("compressor_room", "plant", Rect2(24, 12, 9, 9), 5.0, {"sign": "COMPRESSORS"})
	# The trusses of the workshop stand between its windows.
	room("workshop", "hall", Rect2(33, 0, 21, 21), 6.5, {"lines": [35.2, 40.75, 46.25, 51.8]})
	room("yard", "yard", Rect2(15, 21, 39, 20), 7.0)
	# The south range.
	room("south_corridor_w", "corridor", Rect2(0, 41, 28, 3), 3.0)
	room("south_corridor_e", "corridor", Rect2(28, 41, 26, 3), 3.0)
	room("canteen", "canteen", Rect2(0, 44, 18, 13), 3.6)
	room("kitchen", "kitchen", Rect2(18, 44, 10, 13), 3.4)
	room("boiler_house", "plant", Rect2(28, 44, 14, 13), 7.0)
	room("switch_room", "plant", Rect2(42, 44, 12, 13), 5.0)
	# The east range.
	room("east_corridor", "corridor", Rect2(54, 0, 3, 44), 3.0)
	# The assembly hall has a sawtooth roof whose glass looks south, into
	# the evening sun; the paint shop a flat one on steel with rooflights.
	room("assembly", "hall", Rect2(57, 0, 27, 30), 8.0, {"roof": "sawtooth", "glazed": SOUTH})
	room("paint_shop", "hall", Rect2(57, 30, 13, 14), 5.5, {"roof": "beams", "stock": "paint"})
	room("despatch", "storage", Rect2(70, 30, 14, 14), 4.5, {"stock": "despatch"})
	room("loading_bay", "hall", Rect2(57, 44, 27, 13), 6.5, {"stock": "bay", "lines": [59.8, 67.0, 74.0, 80.5]})

	door("lodge", "vestibule", 4.0)
	door("vestibule", "west_corridor", 13.5)
	door("west_corridor", "office_a", 12.0)
	door("west_corridor", "office_b", 20.0)
	door("west_corridor", "archive", 29.0)
	door("west_corridor", "locker_room", 37.5)
	door("west_corridor", "stores", 10.0)
	# From the stores on to the workshop by the tool room and the compressor
	# room, round two corners: a door straight through would put the
	# workshop and the yard in sight from the stores and from the corridor
	# behind them, and whoever stands in the door of the stores would have
	# half the works drawn.
	door("stores", "tool_room", 19.5)
	door("tool_room", "compressor_room", 16.5)
	door("compressor_room", "workshop", 14.3, 2.4, 2.6)
	door("workshop", "yard", 43.5, 3.0, 3.0)
	door("yard", "south_corridor_w", 21.5, 2.4, 2.6)
	door("south_corridor_w", "canteen", 9.0)
	door("south_corridor_w", "kitchen", 23.0)
	door("canteen", "kitchen", 50.5)
	door("south_corridor_w", "south_corridor_e", 42.5)
	door("south_corridor_e", "boiler_house", 35.0)
	door("south_corridor_e", "switch_room", 48.0)
	door("boiler_house", "switch_room", 50.5)
	door("south_corridor_e", "east_corridor", 42.5)
	door("east_corridor", "assembly", 15.0, 2.4, 2.6)
	door("assembly", "paint_shop", 63.5, 2.4, 2.6)
	door("paint_shop", "despatch", 37.0, 2.4, 2.6)
	door("despatch", "loading_bay", 77.0, 3.0, 3.0)

	window("lodge", NORTH, 6.0, 3.0)
	window("lodge", WEST, 4.0, 2.5)
	window("office_a", WEST, 12.0, 3.0)
	window("office_b", WEST, 20.0, 3.0)
	window("locker_room", WEST, 37.5, 2.0, 1.6, 2.6)
	for x: float in [20.0, 28.0]:
		window("stores", NORTH, x, 3.0, 2.0, 3.4)
	for x: float in [38.0, 43.5, 49.0]:
		window("workshop", NORTH, x, 3.0, 3.2, 5.4)
	for x: float in [5.0, 13.0]:
		window("canteen", SOUTH, x, 3.5)
	window("canteen", WEST, 50.5, 3.0)
	window("kitchen", SOUTH, 23.0, 2.5, 1.4, 2.6)
	for x: float in [32.0, 38.0]:
		window("boiler_house", SOUTH, x, 2.5, 4.0, 6.0)
	window("switch_room", SOUTH, 48.0, 2.5, 3.0, 4.4)
	for x: float in [62.0, 70.5, 79.0]:
		window("assembly", NORTH, x, 4.0, 4.0, 7.0)
	for z: float in [7.0, 15.0, 23.0]:
		window("assembly", EAST, z, 4.0, 4.0, 7.0)
	window("despatch", EAST, 37.0, 3.0, 1.4, 3.2)
	for x: float in [63.0, 71.0]:
		window("loading_bay", SOUTH, x, 3.0, 3.2, 5.4)

	# Where the machines go: see the file of each of these rooms. The first
	# of a room is what the player should see when he comes in, and gets a
	# lamp that burns: the press of the workshop, which stands straight
	# ahead of its door, and the nearer press of the assembly hall.
	keep_clear("workshop", Rect2(47.4, 9.0, 5.2, 4.0))
	keep_clear("workshop", Rect2(39.6, 0.6, 7.8, 4.0))
	keep_clear("workshop", Rect2(49.6, 0.8, 3.6, 3.6))
	keep_clear("workshop", Rect2(36.0, 18.6, 5.8, 2.0))
	keep_clear("compressor_room", Rect2(28.6, 17.2, 4.0, 3.6))
	keep_clear("assembly", Rect2(62.4, 4.0, 5.2, 4.0))
	keep_clear("assembly", Rect2(69.2, 0.8, 7.6, 4.0))
	keep_clear("assembly", Rect2(70.4, 22.0, 5.2, 4.0))
	keep_clear("assembly", Rect2(76.6, 0.8, 6.9, 3.6))
	keep_clear("boiler_house", Rect2(30.6, 51.6, 9.0, 5.0))
	keep_clear("boiler_house", Rect2(28.4, 46.0, 1.4, 3.8))
	keep_clear("switch_room", Rect2(43.0, 55.0, 10.4, 1.6))
	# And the boards of gauges on two walls.
	keep_clear("boiler_house", Rect2(37.7, 44.4, 1.6, 0.6))
	keep_clear("switch_room", Rect2(50.8, 44.4, 1.6, 0.6))

	start_in("lodge")
	# A wing that is fought over as one sends everybody in it at the player
	# the moment he steps into its corridor, where nothing stands to hide
	# behind. So it holds no more than a fight of the factory or the depot
	# does, three to six, and the first of the level as few as the first of
	# the factory: with eight in each, the first lasted under a minute.
	fight("offices", "the offices", {
		"west_corridor": [], "office_a": ["grunt"], "office_b": ["grunt"],
		"archive": ["rusher"], "locker_room": [],
	}, "vestibule")
	fight("stores", "the stores", {
		"stores": ["grunt", "grunt", "rusher"], "tool_room": ["grunt"], "compressor_room": ["grunt"],
	}, "west_corridor")
	checkpoint_in("stores", "Stores")
	fight("workshop", "the workshop", {"workshop": ["grunt", "grunt", "grunt", "grunt", "rusher", "rusher", "heavy"]}, "compressor_room")
	fight("yard", "the yard", {"yard": ["grunt", "grunt", "grunt", "grunt", "rusher", "rusher", "heavy", "heavy"]}, "workshop")
	checkpoint_in("yard", "Yard")
	fight("canteen", "the canteen", {
		"south_corridor_w": [], "canteen": ["grunt", "grunt", "rusher"], "kitchen": ["grunt", "grunt"],
	}, "yard")
	checkpoint_in("canteen", "Canteen")
	fight("boiler_house", "the boiler house", {
		"south_corridor_e": [], "boiler_house": ["grunt", "grunt", "heavy"], "switch_room": ["grunt", "rusher"],
	}, "south_corridor_w")
	fight("east_corridor", "the east corridor", {"east_corridor": ["grunt", "rusher"]}, "south_corridor_e")
	checkpoint_in("east_corridor", "East corridor")
	fight("assembly", "the assembly hall", {"assembly": ["grunt", "grunt", "grunt", "grunt", "rusher", "rusher", "heavy", "heavy"]}, "east_corridor")
	fight("paint_shop", "the paint shop", {"paint_shop": ["grunt", "grunt", "rusher", "heavy"]}, "assembly")
	checkpoint_in("paint_shop", "Paint shop")
	fight("despatch", "despatch", {"despatch": ["grunt", "grunt", "grunt", "rusher"]}, "paint_shop")
	fight("loading_bay", "the loading bay", {"loading_bay": ["grunt", "grunt", "grunt", "grunt", "rusher", "rusher", "heavy", "heavy"]}, "despatch")
	# Out by the loading door, and on to the depot.
	exit_through("loading_bay", EAST, 50.5, "Leave by the loading door", "depot", 5.0, 4.0)
