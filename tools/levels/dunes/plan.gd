extends "res://tools/kit.gd"
## The plan of the dunes: a wood of pines on a coast of dunes, by day, and
## beyond it the complex this army guards. The player comes out of the wood
## in the south-west and follows the track the lorries use, three legs of it
## with a long dune between one and the next:
##
##      0        60        130       200       260       340
##    0 +---------------------------------------------------+
##      | wall..............................................|
##      | :  the yard     :   main building     [back door] |
##   56 | :....gate.......:.........wall...................:|
##      |   the wire                                        |
##   95 |^^^^^gap^^^^^^^^^^^^^^^^^ dune ^^^^^^^^^^^^^^^^^^^^|
##      |  tank laager  <  motor pool  <   bivouac          |
##  155 |^^^^^^^^^^^^^^^^^^^ dune ^^^^^^^^^^^^^^^^saddle^^^^|
##      |  the wood   > pass >    the valley       >        |
##  230 +---------------------------------------------------+
##
## North is up, and the sun stands in the south-south-west: shadows fall to
## the north-north-east. A dune is steep on its south face, where nobody
## walks up it, and has a long back to the north. Every file of the level
## extends this one: the land is shaped here, and each stretch of the way
## stands its own things on it.

## The land of the level, x and z.
const LAND := Rect2(0, 0, 340, 230)
## Where the sun stands, as scenes/dunes.tscn has it and the sky shows it:
## round from north by east, and over the horizon.
const SUN_TURN := 214.1
const SUN_RISE := 48.0
## The track, from where the player comes out of the wood to the gate.
const TRACK: Array[Vector2] = [
	Vector2(2, 201), Vector2(22, 199), Vector2(48, 203), Vector2(72, 198), Vector2(96, 190), Vector2(118, 186),
	Vector2(132, 185), Vector2(150, 187), Vector2(175, 191), Vector2(210, 193), Vector2(245, 186), Vector2(268, 172),
	Vector2(278, 152), Vector2(276, 134), Vector2(262, 122), Vector2(238, 120), Vector2(205, 124), Vector2(170, 126),
	Vector2(142, 122), Vector2(110, 122), Vector2(78, 118), Vector2(56, 108), Vector2(50, 92), Vector2(56, 74),
	Vector2(66, 62), Vector2(70, 50),
]
## The wall round the complex: its south side with the gate in it, where its
## other sides stand, how high it is and how high the ground inside lies.
const WALL_Z := 56.0
const GATE_X := 69.0
const WALL_WEST := 18.0
const WALL_EAST := 322.0
const WALL_NORTH := 6.0
const WALL_HIGH := 4.2
const YARD_Y := 6.4
## The main building: from where to where it stands (x), its north face,
## which is its back, how high it is, and where in that face the back door is.
const BLOCK_WEST := 176.0
const BLOCK_EAST := 300.0
const BLOCK_NORTH := 27.0
const BLOCK_HIGH := 15.0
const BACK_DOOR_X := 238.0
## The pines of this coast, and how much there is of each.
const PINES := [["pine_a", 3.0], ["pine_b", 2.0], ["pine_c", 2.0], ["pine_d", 0.6], ["pine_young", 1.0]]
const EDGE_PINES := [["pine_d", 2.0], ["pine_c", 1.5], ["pine_young", 2.0], ["scrub_a", 1.0]]


func _level_name() -> String:
	return "dunes"


## The dunes, the hollows between them and the track through them.
func _lie_of_the_land() -> void:
	land(LAND, 6.0)
	sun_at(SUN_TURN, SUN_RISE)
	open_air("dunes")
	swell(1.5, 70.0)
	# The two long dunes between the three legs of the way: a short steep
	# face to the south that nobody walks up, a long back to the north. Each
	# has one gap.
	ridge([Vector2(-10, 150), Vector2(60, 149), Vector2(130, 157), Vector2(200, 160), Vector2(258, 163)], 7.5, 20.0, 6.5)
	ridge([Vector2(296, 161), Vector2(350, 157)], 7.5, 20.0, 6.5, 5)
	ridge([Vector2(-10, 98), Vector2(34, 96)], 6.5, 18.0, 6.0, 7)
	ridge([Vector2(66, 96), Vector2(120, 99), Vector2(200, 96), Vector2(270, 93), Vector2(350, 90)], 6.5, 18.0, 6.0, 9)
	# What shuts the land in: to the south, to the east and, along the
	# middle leg, to the west.
	ridge([Vector2(-10, 229), Vector2(350, 229)], 9.0, 12.0, 30.0, 11)
	ridge([Vector2(337, -10), Vector2(337, 240)], 8.0, 25.0, 9.0, 13)
	ridge([Vector2(26, 92), Vector2(22, 152)], 9.0, 9.0, 22.0, 15)
	# The spurs that part one stretch of the way from the next.
	ridge([Vector2(131, 150), Vector2(133, 185), Vector2(130, 236)], 6.5, 15.0, 15.0, 17)
	ridge([Vector2(264, 236), Vector2(262, 204)], 5.0, 14.0, 14.0, 19)
	ridge([Vector2(233, 92), Vector2(231, 162)], 3.5, 12.0, 12.0, 21)
	ridge([Vector2(146, 94), Vector2(144, 160)], 4.5, 12.0, 12.0, 23)
	# Dunes that stand by themselves, and the knoll the look-out has.
	mound(Vector2(226, 171), 15.0, 4.5)
	mound(Vector2(98, 213), 16.0, 4.0)
	mound(Vector2(172, 212), 12.0, 3.0)
	mound(Vector2(238, 213), 14.0, 4.0)
	mound(Vector2(40, 176), 14.0, 3.5)
	mound(Vector2(304, 128), 15.0, 4.0)
	mound(Vector2(190, 142), 13.0, 3.0)
	# The valley the wind has blown out, and the hollow the camp lies in.
	hollow(Vector2(205, 196), Vector2(46, 24), 3.5)
	hollow(Vector2(276, 126), Vector2(36, 24), 1.8)
	soften(2)
	# Where an army has made the ground level: for its tents, its lorries
	# and its tanks, and under the whole of the complex.
	level_off(Rect2(266, 112, 26, 20), NAN, 5.0)
	level_off(Rect2(158, 108, 62, 30), NAN, 6.0)
	level_off(Rect2(84, 106, 46, 20), NAN, 6.0)
	level_off(Rect2(WALL_WEST, WALL_NORTH, WALL_EAST - WALL_WEST, WALL_Z - WALL_NORTH), YARD_Y, 7.0)
	level_off(Rect2(60, 56, 18, 8), YARD_Y, 6.0)
	level_off(Rect2(234, 193, 12, 9), NAN, 3.0)
	level_off(Rect2(98, 171, 20, 11), NAN, 4.0)
	track(TRACK, 4.2)
	# The gun pits of the laager: a scrape with the spoil thrown up before it.
	for pit: Vector2 in [Vector2(112, 138), Vector2(90, 139)]:
		hollow(pit, Vector2(5.5, 5.0), 0.9)
		bank([pit + Vector2(-6, 5.5), pit + Vector2(0, 7.5), pit + Vector2(6, 5.5)], 1.3, 4.5)
	roughen(0.22)
	lay_ground()


## Lets the woods grow, and the marram, with what lies and grows under the
## pines: what is kept open is open, and the rest of the land has what the
## dunes have.
func _grow() -> void:
	# The camps, the look-out and the ground before the wall.
	for clear: Rect2 in [
		Rect2(262, 108, 34, 28), Rect2(154, 104, 70, 38), Rect2(80, 102, 54, 46), Rect2(216, 162, 22, 18), Rect2(16, 56, 310, 22),
		Rect2(124, 176, 30, 20), Rect2(94, 168, 28, 17), Rect2(232, 191, 16, 13), Rect2(0, 194, 14, 12),
	]:
		keep_open(clear)
	wood(Rect2(4, 160, 124, 66), 6.5, PINES)
	wood(Rect2(134, 204, 124, 22), 7.5, PINES, -0.2)
	wood(Rect2(124, 160, 20, 44), 8.0, EDGE_PINES, -0.1)
	wood(Rect2(160, 162, 90, 10), 10.0, EDGE_PINES, 0.1)
	wood(Rect2(236, 96, 98, 66), 7.0, PINES, -0.35)
	wood(Rect2(262, 162, 72, 64), 6.0, PINES)
	wood(Rect2(150, 98, 82, 54), 9.0, PINES, 0.1)
	wood(Rect2(28, 98, 120, 54), 11.0, EDGE_PINES, 0.2)
	wood(Rect2(20, 78, 300, 16), 9.0, EDGE_PINES, 0.0)
	wood(Rect2(4, 60, 14, 100), 6.0, PINES)
	marram(Rect2(134, 160, 126, 60), 1.7, -0.1)
	marram(Rect2(28, 96, 210, 60), 2.4, 0.1)
	marram(Rect2(20, 58, 300, 36), 2.6, 0.0)
	marram(Rect2(4, 160, 130, 68), 3.4, 0.3)
	forest_floor()
	dune_grass()


## The box of a stretch of the way that is fought over: from (x0, z0) to
## (x1, z1), and as high as the dunes are.
func _ground_box(x0: float, z0: float, x1: float, z1: float) -> AABB:
	return AABB(Vector3(x0, 0.0, z0), Vector3(x1 - x0, 28.0, z1 - z0))


## A place to carry on from, on the ground at `at`, looking towards `look`,
## that counts within `reach` of it.
func _carry_on(id: String, title: String, at: Vector2, look: Vector2, reach := 7.0) -> void:
	route_checkpoint(id, title, ground(at.x, at.y), ground(look.x, look.y), AABB(Vector3(at.x - reach, ground_height(at.x, at.y) - 2.0, at.y - reach), Vector3(reach * 2.0, 6.0, reach * 2.0)))


## A model from the manifest on the ground at (x, z), as place() stands one.
func _put(model: String, x: float, z: float, yaw_deg := 0.0) -> void:
	place(model, ground(x, z), yaw_deg)
