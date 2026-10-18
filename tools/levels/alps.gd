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
	woods()
	route_start(ground(400, 900), ground(1600, 900))
