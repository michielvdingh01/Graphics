extends "res://tools/levels/canals/plan.gd"
## The Keizersgracht, the widest of the three. The round crosses it twice:
## by the bridge of the Nieuwe Spiegelstraat on the way north, and by the
## wide bridge of the Vijzelstraat on the way back.

## Where somebody stands on its north quay and on its south one, z.
const NORTH_QUAY := KEIZERS[0] + 5.0
const SOUTH_QUAY := KEIZERS[3] - 5.0


func _describe() -> void:
	in_zone("keizers")
	great_canal(KEIZERS, KEIZERS_CROSSINGS)
	front("a_west", "s", "canal")
	front("a_mid", "s", "grand")
	front("a_east", "s", "canal")
	front("b_west", "n", "canal")
	front("b_mid", "n", "canal")
	front("b_east", "n", "canal")
	by_position()


func _route_west() -> void:
	route_checkpoint("keizersgracht", "Keizersgracht", Vector3(SPIEGEL_X, 0, KEIZERS[3] + 2.2), Vector3(SPIEGEL_X, 0, KEIZERS[1]),
		AABB(Vector3(SPIEGELSTRAAT[0], -1, KEIZERS[3]), Vector3(SPIEGELSTRAAT[1] - SPIEGELSTRAAT[0], 4, 4.5)))
	route_zone("keizersgracht", "the Keizersgracht", AABB(Vector3(WEST_END, -3, KEIZERS[0] + 0.5), Vector3(110, 10, KEIZERS[3] - KEIZERS[0] - 0.5)), [
		["grunt", Vector3(15, 0, NORTH_QUAY)], ["grunt", Vector3(72, 0, NORTH_QUAY)], ["grunt", Vector3(20, 0, SOUTH_QUAY)],
		["rusher", Vector3(90, 0, SOUTH_QUAY)], ["heavy", Vector3(56, 0, NORTH_QUAY)],
	])


func _route_east() -> void:
	route_zone("keizersgracht_east", "the far side of the Keizersgracht", AABB(Vector3(110, -3, KEIZERS[0] + 0.5), Vector3(EAST_END - 110, 10, KEIZERS[3] - KEIZERS[0] - 0.5)), [
		["grunt", Vector3(130, 0, NORTH_QUAY)], ["grunt", Vector3(206, 0, NORTH_QUAY)], ["grunt", Vector3(140, 0, SOUTH_QUAY)],
		["rusher", Vector3(206, 0, SOUTH_QUAY)], ["heavy", Vector3(155, 0, NORTH_QUAY)],
	])
