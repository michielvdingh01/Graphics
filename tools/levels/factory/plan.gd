extends "res://tools/kit.gd"
## The plan of the factory: its measurements, the zones it is cut into and
## the doorways between them. Every file of the level extends this one, so
## that a wall and the doorway in it are in the same place whichever file
## builds them. What stands in a zone is in the file of that zone; change
## this one only together with the files on both sides of what changes.

# Hall dimensions (interior faces).
const HX := 20.0
const HZ := 12.0
const EAVES := 8.0
const RIDGE := 10.6
const BAYS: Array[float] = [-16.0, -8.0, 0.0, 8.0, 16.0]
const TRUSSES: Array[float] = [-12.0, -4.0, 4.0, 12.0]
const DECK_Y := 3.2
## Where the pipe header runs along the north wall.
const HEADER_Z := -11.75
## Walls of the annex: plaster with a painted dado.
const WALL := "plaster_dado"
# The boiler house (interior faces) and the passage to it.
const BX0 := 29.4
const BX1 := 41.4
const BZ0 := -26.5
const BZ1 := -14.5
const BOILER_H := 7.0
const PASSAGE_H := 3.0
## Where the boiler stands.
const BOILER := Vector3(36.0, 0, -22.0)
## The doorways between the zones, as [from, to, bottom, top] along the wall
## they are in. From the hall into the annex there are two, in the east wall
## of the hall: one into the corridor and one into the locker room.
const HALL_DOORWAYS: Array = [[-10.0, -8.0, 0.0, 2.6], [-3.0, 0.0, 0.0, 3.0]]
## From the storeroom of the annex into the passage, in its north wall.
const PASSAGE_DOORWAY: Array = [23.9, 25.5, 0.0, 2.2]
## From the passage into the boiler house, in its west wall.
const BOILER_DOORWAY: Array = [-17.9, -16.3, 0.0, 2.2]


func _level_name() -> String:
	return "factory"


## Lays the plan down before anything is built: the zones, and the floor that
## carries paint.
func _plan() -> void:
	# The factory was built and baked when all of a level threw the same dice.
	# With dice of its own for every file, each crate would lie differently
	# and all four zones would have to be baked again.
	_shared_dice = true
	_detail_inside = AABB(Vector3(-HX - 0.5, 0, -HZ - 0.5), Vector3(HX * 2.0 + 12.0, RIDGE + 1.0, HZ * 2.0 + 1.0))
	# Four zones in a row. The hall and the annex look into each other through
	# two doorways; the passage has a bend in it, so that neither the annex and
	# the boiler house nor the passage and the hall are ever in sight of each
	# other. The builder finds that out for itself.
	zone("hall", [AABB(Vector3(-HX - 0.6, -1.0, -HZ - 0.6), Vector3(HX * 2.0 + 1.1, 13.0, HZ * 2.0 + 1.2))])
	zone("annex", [AABB(Vector3(HX + 0.5, -1.0, -HZ - 0.4), Vector3(10.45, 5.0, HZ + 2.85))])
	zone("passage", [
		AABB(Vector3(23.3, -1.0, -18.6), Vector3(2.8, 4.6, 6.2)), AABB(Vector3(26.1, -1.0, -18.6), Vector3(2.9, 4.6, 2.8)),
	])
	zone("boiler", [AABB(Vector3(BX0 - 0.4, -1.0, BZ0 - 0.4), Vector3(BX1 - BX0 + 0.8, BOILER_H + 1.5, BZ1 - BZ0 + 0.8))])
	floor_paint_area(Rect2(-HX, BZ0 - 0.5, BX1 + 0.5 + HX, HZ - BZ0 + 0.5))


## Shuts the two doorways between the hall and the annex while a lightmap is
## baked, on the side of the wall that `x` is on. Each side does that right
## where the two zones meet: a strip of floor beyond the panel would lie in
## the sun.
func _shut_hall_doorways(x: float) -> void:
	bake_blocker(Vector3(x, 1.35, -9.0), Vector3(0.02, 2.7, 2.2))
	bake_blocker(Vector3(x, 1.55, -1.5), Vector3(0.02, 3.1, 3.2))
