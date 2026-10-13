extends "res://tools/levels/canals/plan.gd"
## The Keizersgracht, the widest of the three. The round crosses it twice:
## by the bridge of the Nieuwe Spiegelstraat on the way north, and by the
## wide bridge of the Vijzelstraat on the way back.


func _describe() -> void:
	in_zone("keizers")
	great_canal(KEIZERS)
	front("a_west", "s", "canal")
	front("a_mid", "s", "canal")
	front("a_east", "s", "canal")
	front("b_west", "n", "canal")
	front("b_mid", "n", "canal")
	front("b_east", "n", "canal")
	by_position()


func _route_west() -> void:
	route_checkpoint("keizersgracht", "Keizersgracht", Vector3(SPIEGEL_X, 0, KEIZERS[3] + 2.2), Vector3(SPIEGEL_X, 0, KEIZERS[1]),
		AABB(Vector3(SPIEGELSTRAAT[0], -1, KEIZERS[3]), Vector3(10, 4, 4.5)))
	route_zone("keizersgracht", "the Keizersgracht", AABB(Vector3(WEST_END, -3, KEIZERS[0] + 0.5), Vector3(110, 10, 48)), [
		["grunt", Vector3(15, 0, 118)], ["grunt", Vector3(72, 0, 117)], ["grunt", Vector3(20, 0, 157)],
		["rusher", Vector3(90, 0, 157)], ["heavy", Vector3(56, 0, 118)],
	])


func _route_east() -> void:
	route_zone("keizersgracht_east", "the far side of the Keizersgracht", AABB(Vector3(110, -3, KEIZERS[0] + 0.5), Vector3(EAST_END - 110, 10, 48)), [
		["grunt", Vector3(130, 0, 118)], ["grunt", Vector3(206, 0, 118)], ["grunt", Vector3(140, 0, 157)],
		["rusher", Vector3(204, 0, 157)], ["heavy", Vector3(158, 0, 118)],
	])
