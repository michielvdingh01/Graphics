extends "res://tools/levels/canals/plan.gd"
## The south edge: the Lijnbaansgracht, a narrow canal, and beyond it the
## Weteringschans, where the player comes from. The Spiegelgracht runs into
## the Lijnbaansgracht from the north, and the Vijzelgracht crosses it on a
## broad bridge. What stands on the south side stands in for the museum.

## Where the player comes over the water: in line with the east quay of the
## Spiegelgracht.
const START_X := 50.25


func _describe() -> void:
	in_zone("lijnbaan")
	long_canal(LIJNBAAN, [[SPIEGELGRACHT[1], SPIEGELGRACHT[2]]], "n")
	var quay := (LIJNBAAN[0] + LIJNBAAN[1]) * 0.5
	bridge(Vector3(SPIEGELGRACHT[1] - 1.0, 0, quay), Vector3(SPIEGELGRACHT[2] + 1.0, 0, quay), LIJNBAAN[1] - LIJNBAAN[0] - 0.6, 0.4)
	var from := Vector3(START_X, 0, LIJNBAAN[2] + 1.0)
	var to := Vector3(START_X, 0, LIJNBAAN[1] - 1.0)
	bridge(from, to, 8.0, 0.7)
	bridge_lanterns(from, to, 8.0)
	bridge(Vector3(VIJZEL_X, 0, LIJNBAAN[2] + 1.0), Vector3(VIJZEL_X, 0, LIJNBAAN[1] - 1.0), 34.0, 0.25)
	front("d_west", "s", "canal")
	front("e_mid", "s", "canal")
	front("d_east", "s", "canal")
	terrace(Vector2(EAST_END, SOUTH_END), Vector2(WEST_END, SOUTH_END), "block", DEEP, {"lit": 0.08})
	lanterns(Vector3(62, 0, LIJNBAAN[1] - 1.2), Vector3(158, 0, LIJNBAAN[1] - 1.2))
	lanterns(Vector3(WEST_END + 8.0, 0, LIJNBAAN[3] - 4.0), Vector3(EAST_END - 8.0, 0, LIJNBAAN[3] - 4.0), 28.0, "mast")
	parked_cars(Vector3(70, 0, LIJNBAAN[2] + 2.0), Vector3(160, 0, LIJNBAAN[2] + 2.0), 0.5)
	var third := (EAST_END - WEST_END) / 3.0
	for i in 3:
		probe("Lijnbaan%d" % i, Vector3(WEST_END + third * (i + 0.5), 7.0, (LIJNBAAN[0] + LIJNBAAN[3]) * 0.5), Vector3(third, 18.0, LIJNBAAN[3] - LIJNBAAN[0]), Vector3(0, -5.0, 0))
	by_position()


func _route_start() -> void:
	route_start(Vector3(START_X, 0, LIJNBAAN[3] - 9.0), Vector3(START_X, 0, LIJNBAAN[1]))
