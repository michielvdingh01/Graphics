extends "res://tools/levels/canals/plan.gd"
## The canals: the middle of Amsterdam by night, from the Lijnbaansgracht up
## the Spiegelgracht to the Herengracht and back down the Vijzelstraat to the
## metro on the Vijzelgracht. Build with: tools/build_level.sh canals
##
## The plan is in tools/levels/canals/plan.gd, with every measure of the
## town, and next to it a file for every stretch: the three great canals,
## the two axes that cross them, the streets that cut across and the south
## edge. As yet it is a greybox, see tools/kit/street.gd.


func _describe() -> void:
	_plan()
	for file: String in ["heren", "keizers", "prinsen", "spiegel", "vijzel", "cross", "lijnbaan"]:
		build(file)
	# The route, in the order the player walks it: round by the west.
	build("lijnbaan", &"_route_start")
	build("spiegel", &"_route_gracht")
	build("prinsen", &"_route_west")
	build("spiegel", &"_route_south")
	build("keizers", &"_route_west")
	build("spiegel", &"_route_north")
	build("heren", &"_route_through")
	build("vijzel", &"_route_north")
	build("keizers", &"_route_east")
	build("vijzel", &"_route_south")
	build("prinsen", &"_route_east")
	build("vijzel", &"_route_gracht")
