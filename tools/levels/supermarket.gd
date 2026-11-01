extends "res://tools/levels/supermarket/plan.gd"
## The supermarket: a big American store at the end of the afternoon, with its
## parking lot all round it. Build with: tools/build_level.sh supermarket
##
## The measurements are in tools/levels/supermarket/plan.gd, and next to it a
## file for each part: the building, the aisles, what is fresh round the walls,
## the front end with its checkouts, what lies behind the shop, and the lot.
## Nothing here is baked: the light of the shop goes out when its mains are
## shot, see scripts/mains.gd, and what stands on the shelves moves.

const PARTS: Array[String] = ["building", "aisles", "fresh", "front", "back", "lot"]


func _describe() -> void:
	_detail_block = Vector3(24, 16, 24)
	_wall_flags = DETAIL
	sun_at(SUN_TURN, SUN_RISE)
	_zones_of_the_shop()
	for part in PARTS:
		build(part)
	build("route")
