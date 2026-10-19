extends "res://tools/levels/alps/plan.gd"
## The Alps: the Ehrwald basin in Tyrol on an afternoon in October, a map for
## matches that is too large to cross on foot. Build with:
## tools/build_level.sh alps
##
## The plan is in tools/levels/alps/plan.gd, with the lie of the land, and next
## to it a file for each part of it.


func _describe() -> void:
	_lie_of_the_land()
	build("vista")
	# The camps at either end are kept clear of the wood.
	for camp: Vector2 in [Vector2(330, 905), Vector2(2880, 760)]:
		keep_open(Rect2(camp - Vector2(70, 60), Vector2(140, 120)))
	# The barns, the chapel and the farm the route is fought round, then the
	# vehicles and the route, then the barns about the meadows where they
	# leave room; the woods, and last what grows between the meadows.
	build("valley")
	build("bases")
	build("route")
	build("valley", &"_scatter")
	woods()
	build("valley", &"_meadow_cover")
