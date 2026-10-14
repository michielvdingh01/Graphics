extends "res://tools/levels/canals/plan.gd"
## The Prinsengracht, lower houses than on the other two, where the
## Spiegelgracht runs into it from the south: the quay is carried over that
## mouth by a bridge of its own.

## Where somebody stands on its north quay and on its south one, z.
const NORTH_QUAY := PRINSEN[0] + 5.0
const SOUTH_QUAY := PRINSEN[3] - 5.0


func _describe() -> void:
	in_zone("prinsen")
	great_canal(PRINSEN, PRINSEN_CROSSINGS, [[SPIEGELGRACHT[1], SPIEGELGRACHT[2]]])
	front("b_west", "s", "low")
	front("c_mid", "s", "low")
	front("b_east", "s", "low")
	front("d_west", "n", "low")
	front("d_mid", "n", "low")
	front("d_east", "n", "low")
	# The south quay over the mouth of the Spiegelgracht, level: the bridge
	# from the Nieuwe Spiegelstraat comes down on it.
	var z := (PRINSEN[2] + PRINSEN[3]) * 0.5
	bridge(Vector3(SPIEGELGRACHT[1] - 1.0, 0, z), Vector3(SPIEGELGRACHT[2] + 1.0, 0, z), PRINSEN[3] - PRINSEN[2] - 0.6, 0.0, "brick", 0.4, [1.0])
	by_position()


func _route_west() -> void:
	var quay := (SPIEGELGRACHT[2] + SPIEGELGRACHT[3]) * 0.5
	route_checkpoint("prinsengracht", "Prinsengracht", Vector3(quay, 0, PRINSEN[3] + 2.5), Vector3(SPIEGEL_X, 0, PRINSEN[2]),
		AABB(Vector3(SPIEGELGRACHT[2], -1, PRINSEN[3]), Vector3(SPIEGELGRACHT[3] - SPIEGELGRACHT[2], 4, 5)))
	route_zone("prinsengracht", "the Prinsengracht", AABB(Vector3(WEST_END, -3, PRINSEN[0] + 2.0), Vector3(110, 10, PRINSEN[3] - PRINSEN[0] - 4.0)), [
		["grunt", Vector3(20, 0, NORTH_QUAY)], ["grunt", Vector3(72, 0, NORTH_QUAY)], ["grunt", Vector3(84, 0, SOUTH_QUAY)],
		["rusher", Vector3(16, 0, SOUTH_QUAY)],
	])


func _route_east() -> void:
	route_zone("prinsengracht_east", "the far side of the Prinsengracht", AABB(Vector3(110, -3, PRINSEN[0] + 0.5), Vector3(EAST_END - 110, 10, PRINSEN[3] - PRINSEN[0] - 1.0)), [
		["grunt", Vector3(130, 0, NORTH_QUAY)], ["grunt", Vector3(206, 0, NORTH_QUAY)], ["grunt", Vector3(206, 0, SOUTH_QUAY)],
		["rusher", Vector3(140, 0, SOUTH_QUAY)],
	])
