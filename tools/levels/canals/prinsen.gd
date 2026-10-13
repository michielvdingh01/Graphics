extends "res://tools/levels/canals/plan.gd"
## The Prinsengracht, where the Spiegelgracht runs into it from the south:
## the quay is carried over that mouth by a bridge of its own.


func _describe() -> void:
	in_zone("prinsen")
	great_canal(PRINSEN, [[SPIEGELGRACHT[1], SPIEGELGRACHT[2]]])
	front("b_west", "s", "canal")
	front("c_mid", "s", "canal")
	front("b_east", "s", "canal")
	front("d_west", "n", "canal")
	front("d_mid", "n", "canal")
	front("d_east", "n", "canal")
	# The south quay over the mouth of the Spiegelgracht.
	var z := (PRINSEN[2] + PRINSEN[3]) * 0.5
	bridge(Vector3(SPIEGELGRACHT[1] - 1.0, 0, z), Vector3(SPIEGELGRACHT[2] + 1.0, 0, z), PRINSEN[3] - PRINSEN[2] - 0.6, 0.45)
	by_position()


func _route_west() -> void:
	route_checkpoint("prinsengracht", "Prinsengracht", Vector3(50.25, 0, PRINSEN[3] + 2.5), Vector3(SPIEGEL_X, 0, PRINSEN[2]),
		AABB(Vector3(SPIEGELGRACHT[2], -1, PRINSEN[3]), Vector3(8.5, 4, 5)))
	route_zone("prinsengracht", "the Prinsengracht", AABB(Vector3(WEST_END, -3, PRINSEN[0] + 2.0), Vector3(110, 10, 34)), [
		["grunt", Vector3(20, 0, 249)], ["grunt", Vector3(72, 0, 249)], ["grunt", Vector3(84, 0, 280)],
		["rusher", Vector3(16, 0, 280)],
	])


func _route_east() -> void:
	route_zone("prinsengracht_east", "the far side of the Prinsengracht", AABB(Vector3(110, -3, PRINSEN[0] + 0.5), Vector3(EAST_END - 110, 10, 42)), [
		["grunt", Vector3(130, 0, 249)], ["grunt", Vector3(206, 0, 249)], ["grunt", Vector3(206, 0, 282)],
		["rusher", Vector3(140, 0, 282)],
	])
