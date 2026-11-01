extends "res://tools/kit.gd"
## The plan of the supermarket. North is -Z. The front of the store looks west
## into the sun that is going down, over the biggest part of the lot; the
## aisles run from there towards the back of the store, and behind the back
## wall lie the stockroom and the loading doors.

## Where the sun stands: its turn from north by east and its height, degrees.
const SUN_TURN := 268.0
const SUN_RISE := 9.5

## The building, on x and z, in metres. The shop floor runs from the front
## wall to BACK, the stockroom from there to REAR.
const FRONT := 0.0
const BACK := 66.0
const REAR := 86.0
const NORTH_WALL := -44.0
const SOUTH_WALL := 44.0
## How high the deck of the roof is over the shop, and the top of the walls.
const DECK := 6.6
const WALL_TOP := 7.6
const PARAPET := 9.4
## The two ways in, by the middle of each along the front, and how wide each
## is and how high.
const ENTRANCES: Array[float] = [-25.0, 25.0]
const ENTRANCE_WIDE := 5.2
const ENTRANCE_HIGH := 3.0
## The window in the front wall, on z, and its height.
const WINDOW_NORTH := -19.0
const WINDOW_SOUTH := 19.0
const WINDOW_LOW := 0.7
const WINDOW_HIGH := 3.7
## The doors in the back wall of the shop, by the middle of each on z, and how
## wide each is.
const BACK_DOORS: Array[float] = [-34.5, 3.0]
const BACK_DOOR_WIDE := 3.0
const BACK_DOOR_HIGH := 2.7

## The loading doors in the back wall, by the middle of each on z.
const DOCK_DOORS: Array[float] = [-22.0, -8.0, 6.0]

## The aisles: from the front end of the gondolas to the cross aisle, from
## there to the back, and the middles of the gondolas on z.
const AISLE_A := Vector2(20.0, 38.0)
const AISLE_B := Vector2(41.0, 59.0)
const GONDOLAS := 12
const GONDOLA_FIRST := -26.0
const GONDOLA_PITCH := 4.72

## How far the lot reaches on every side, and the line in front of the store
## that the walk ends at.
const LOT_WEST := -122.0
const LOT_EAST := 128.0
const LOT_NORTH := -96.0
const LOT_SOUTH := 96.0
const WALK := -6.0
## The land beyond the lot, as far as it is drawn.
const BEYOND := 900.0


func _level_name() -> String:
	return "supermarket"


## The shop, the stockroom and all that lies round them. None of them hides the
## next one, as long as there is glass in the front; they are what the reverb and
## the bed of each go by.
func _zones_of_the_shop() -> void:
	zone("shop", [AABB(Vector3(FRONT, -1.0, NORTH_WALL), Vector3(BACK - FRONT, DECK + 2.0, SOUTH_WALL - NORTH_WALL))])
	zone("stock", [AABB(Vector3(BACK, -1.0, NORTH_WALL), Vector3(REAR - BACK, DECK + 2.0, SOUTH_WALL - NORTH_WALL))])
	zone("lot", [AABB(Vector3(LOT_WEST - 300.0, -2.0, LOT_NORTH - 300.0), Vector3(LOT_EAST - LOT_WEST + 600.0, 80.0, LOT_SOUTH - LOT_NORTH + 600.0))])
	_zones.lot.node.set_meta(&"space", &"yard")


## The middle of gondola `index` on z.
func gondola_z(index: int) -> float:
	return GONDOLA_FIRST + GONDOLA_PITCH * index
