extends "res://tools/kit.gd"
## The test quay: forty metres of a canal as wide as the Herengracht, by
## night. A bridge at its west end, a row of houses on either side, and
## along the water on both quays a lantern, an elm and a parked car or two.
## Build with: tools/build_level.sh quay
##
## This is where the pieces of the town are dressed and looked at, one by
## one, dry and wet, before the town of tools/levels/canals.gd is built with
## them and baked. It builds in seconds and is one zone, so that its bake is
## one small lightmap: a piece is judged here in a minute, where the town
## takes the better part of an hour. Nobody is fought here; the way out is
## the far end of the south quay. See "De grachten" in PLAN.md.

## The quay from west to east, and from north to south as a great canal of
## the town has it: the fronts on the north side, the two edges of the
## water, and the fronts on the south side.
const LONG := 40.0
const LINES: Array[float] = [0.0, 10.5, 36.5, 47.0]
## Where the bridge crosses, and how wide it is.
const BRIDGE_X := 6.0
const BRIDGE_WIDE := 9.0
## How far from the edge of the water the trees and lanterns stand.
const KERB := 1.4


func _level_name() -> String:
	return "quay"


func _describe() -> void:
	# As the town has them: see tools/levels/canals/plan.gd.
	_texel = 0.16
	_detail_block = Vector3(36, 400, 36)
	zone("quay", [AABB(Vector3(0, -4, LINES[0]), Vector3(LONG, 20, LINES[3] - LINES[0]))])
	in_zone("quay")
	street_paving(Rect2(0, LINES[0], LONG, LINES[1] - LINES[0]))
	street_paving(Rect2(0, LINES[2], LONG, LINES[3] - LINES[2]))
	canal(Rect2(0, LINES[1], LONG, LINES[2] - LINES[1]), "we")
	terrace(Vector2(0, LINES[0]), Vector2(LONG, LINES[0]), "grand")
	terrace(Vector2(LONG, LINES[3]), Vector2(0, LINES[3]), "canal")
	var from := Vector3(BRIDGE_X, 0, LINES[2] + 1.0)
	var to := Vector3(BRIDGE_X, 0, LINES[1] - 1.0)
	bridge(from, to, BRIDGE_WIDE)
	for end: Vector3 in [from, to]:
		for side: float in [-1.0, 1.0]:
			lantern(Vector3(end.x + side * (BRIDGE_WIDE * 0.5 + 0.5), 0, end.z + signf(to.z - from.z) * (0.4 if end == from else -0.4)), "crown")
	kerb_line(Vector3(BRIDGE_X + 7.0, 0, LINES[1] - KERB), Vector3(LONG - 1.0, 0, LINES[1] - KERB))
	kerb_line(Vector3(BRIDGE_X + 7.0, 0, LINES[2] + KERB), Vector3(LONG - 1.0, 0, LINES[2] + KERB))
	water_steps(Vector3(30.0, 0, LINES[2]), 180.0)
	# Where the town would go on: a hoarding at either end, from the bed up.
	for x: float in [-0.2, LONG + 0.2]:
		box("roof", Vector3(x, 1.15, (LINES[0] + LINES[3]) * 0.5), Vector3(0.4, 5.7, LINES[3] - LINES[0]))
	probe("Quay", Vector3(LONG * 0.5, 7.0, (LINES[0] + LINES[3]) * 0.5), Vector3(LONG, 18.0, LINES[3] - LINES[0]), Vector3(0, -5.0, 0))
	by_position()
	route_start(Vector3(BRIDGE_X, 0, LINES[3] - 3.0), Vector3(LONG, 0, LINES[2] + 4.0))
	route_exit("Walk to the far end of the quay", AABB(Vector3(LONG - 3.0, -0.1, LINES[2] + 3.5), Vector3(2.6, 3.0, 6.0)))
