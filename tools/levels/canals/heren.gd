extends "res://tools/levels/canals/plan.gd"
## The Herengracht, and on it the Golden Bend: the widest houses of the
## town, on double lots, between the Nieuwe Spiegelstraat and the
## Vijzelstraat. The far end of the round, and its longest fight.


func _describe() -> void:
	in_zone("heren")
	great_canal(HEREN)
	# The north side: one row, but for where the Vijzelstraat runs on north.
	terrace(Vector2(WEST_END, HEREN[0]), Vector2(VIJZELSTRAAT[0], HEREN[0]), "grand")
	terrace(Vector2(VIJZELSTRAAT[1], HEREN[0]), Vector2(EAST_END, HEREN[0]), "canal")
	shut(Vector2(VIJZELSTRAAT[0], HEREN[0] - 0.4), Vector2(VIJZELSTRAAT[1], HEREN[0] - 0.4))
	# The south side: the heads of the three blocks.
	front("a_west", "n", "canal")
	front("a_mid", "n", "grand")
	front("a_east", "n", "canal")
	by_position()


func _route_through() -> void:
	route_checkpoint("herengracht", "Herengracht", Vector3(SPIEGEL_X, 0, HEREN[3] + 2.5), Vector3(SPIEGEL_X, 0, HEREN[1]),
		AABB(Vector3(SPIEGELSTRAAT[0], -1, HEREN[3]), Vector3(10, 4, 5)))
	route_zone("herengracht", "the Herengracht", AABB(Vector3(WEST_END, -3, HEREN[0] + 0.5), Vector3(110, 10, 46)), [
		["grunt", Vector3(18, 0, 5)], ["grunt", Vector3(72, 0, 5)], ["grunt", Vector3(88, 0, 42)],
		["rusher", Vector3(14, 0, 42)], ["heavy", Vector3(60, 0, 6)],
	])
	route_zone("golden_bend", "the Golden Bend", AABB(Vector3(110, -3, HEREN[0] + 0.5), Vector3(EAST_END - 110, 10, 46)), [
		["grunt", Vector3(132, 0, 5)], ["grunt", Vector3(158, 0, 42)], ["grunt", Vector3(203, 0, 5)],
		["rusher", Vector3(150, 0, 6)], ["heavy", Vector3(204, 0, 42)],
	])
