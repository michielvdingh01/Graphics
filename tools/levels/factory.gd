extends "res://tools/levels/factory/plan.gd"
## The factory: the hall with its crane and mezzanine, an annex with a
## corridor and two rooms, and behind the annex the boiler house, reached
## through a passage with a bend in it. Build with: tools/build_level.sh factory
##
## The level is written in tools/levels/factory/: the plan, with the
## measurements, the zones and the doorways between them, a file for each
## zone with what stands in it and its stretch of the route, one for the
## clutter and one for what lies around the building.


func _describe() -> void:
	_plan()
	# From the hall outwards, then a round with what was left standing about,
	# and what lies around the building last.
	for file: String in ["hall", "annex", "passage", "boiler", "clutter", "outside"]:
		build(file)
	# The route, in the order the player walks it: in by the yard door of the
	# boiler house, through the passage into the annex, down its corridor, the
	# length of the hall and out by the loading door in the west wall.
	for file: String in ["boiler", "passage", "annex", "hall"]:
		build(file, &"_route_through")
