extends "res://tools/kit.gd"
## The plan of the wing: a works wing of five rooms, and the first level that
## is laid out as rooms (see tools/kit/rooms.gd). A lobby and a storeroom on
## the west side of a corridor, a workshop and a boiler room on the east
## side, and a loading door in the east wall of the workshop for a way out.
##
##      0        8  11                 27
##    0 +--------+--+------------------+
##      | lobby  |c |                  |
##    6 +--------+o |    workshop      = loading door
##      |        |r |                  |
##      | store  |r +-----------+------+ 14
##   16 +--------+i |   plant   |
##               |d |           |
##   20          +--+           |
##   23             +-----------+ 21


func _level_name() -> String:
	return "wing"


func _plan() -> void:
	# Set to true while the wing is being laid out, to walk and fight through
	# it before anything is hung, dirtied or stood about.
	_bare = false
	_detail_inside = AABB(Vector3(-0.5, 0, -0.5), Vector3(28.0, 8.5, 24.0))
	room("lobby", "office", Rect2(0, 0, 8, 6), 3.2)
	room("store", "storage", Rect2(0, 6, 8, 10), 3.4)
	room("corridor", "corridor", Rect2(8, 0, 3, 20), 3.0)
	room("workshop", "hall", Rect2(11, 0, 16, 14), 6.5)
	room("plant", "plant", Rect2(11, 14, 10, 9), 6.5)
	door("lobby", "corridor", 3.0)
	door("store", "corridor", 11.0)
	door("corridor", "workshop", 5.0, 2.4, 2.6)
	door("corridor", "plant", 16.0)
	door("workshop", "plant", 16.0, 2.4, 2.6)
	window("lobby", NORTH, 4.0, 3.0)
	window("store", WEST, 11.0, 3.0)
	for x: float in [15.0, 19.0, 23.0]:
		window("workshop", NORTH, x, 3.0, 3.2, 5.4)
	window("workshop", SOUTH, 24.0, 3.0, 3.2, 5.4)
	window("plant", SOUTH, 14.5, 2.5, 3.6, 5.4)
	window("plant", EAST, 16.5, 2.5, 3.6, 5.4)
	# Where the machines go, see workshop.gd and plant.gd.
	keep_clear("workshop", Rect2(15.2, 0.6, 7.6, 3.8))
	keep_clear("workshop", Rect2(21.4, 9.6, 5.2, 4.0))
	keep_clear("workshop", Rect2(11.8, 0.8, 3.2, 3.4))
	keep_clear("plant", Rect2(11.6, 18.4, 9.0, 4.2))
	keep_clear("plant", Rect2(19.3, 14.6, 1.3, 3.6))
	# The way through: out of the lobby, down the corridor, the storeroom and
	# the boiler room off it, and through the workshop to the loading door.
	start_in("lobby")
	fight("corridor", "the corridor", ["rusher"], "lobby")
	fight("store", "the storeroom", ["grunt", "grunt"], "corridor")
	checkpoint_in("store", "Storeroom")
	fight("plant", "the boiler room", ["grunt", "grunt", "rusher"], "corridor")
	fight("workshop", "the workshop", ["grunt", "grunt", "grunt", "rusher", "heavy"], "corridor")
	exit_through("workshop", EAST, 7.0, "Leave by the loading door")
