extends "res://tools/levels/alps/plan.gd"
## The two ends of the Alps, where the two sides begin a match: in the west a
## camp at the edge of the wood, in the shade of the mountains; in the east one
## on the meadows below Ehrwald, still in the sun. Each has its vehicles for
## the long way across: two field cars, two motorcycles with a sidecar, a
## lorry and a tank. A few more stand about the valley, where whoever is on
## foot can find one.

## Where the camps are (x and z): the ends assets/arenas.json gives the
## arena, and the ground each is levelled over.
const WEST_CAMP := Vector2(330, 905)
const EAST_CAMP := Vector2(2880, 760)
const CAMP := Vector2(90, 70)


func _describe() -> void:
	in_zone("")
	# The west faces east, the way to the other side; the east faces west.
	_camp(WEST_CAMP, -90.0)
	_camp(EAST_CAMP, 90.0)
	# About the valley: on the farm track, by the barns, on the road north.
	vehicle("jeep", Vector2(1590, 830), 0.0)
	vehicle("motorcycle", Vector2(1215, 505), -60.0)
	vehicle("truck", Vector2(2110, 1190), 120.0)
	vehicle("motorcycle", Vector2(905, 1310), 30.0)
	vehicle("jeep", Vector2(2290, 420), -150.0)
	vehicle("motorcycle", Vector2(1905, 960), 80.0)


## A camp at `at` whose vehicles face `facing` (the yaw of vehicle(): -90
## is east), lined up along the way out.
func _camp(at: Vector2, facing: float) -> void:
	var ahead := Vector2(1, 0) if facing < 0.0 else Vector2(-1, 0)
	var across := Vector2(0, 1)
	var row := at - ahead * 12.0
	vehicle("jeep", row + across * -12.0, facing)
	vehicle("jeep", row + across * -6.0, facing)
	vehicle("motorcycle", row + across * 0.0, facing)
	vehicle("motorcycle", row + across * 4.0, facing)
	vehicle("truck", row + across * 10.0 - ahead * 4.0, facing)
	vehicle("tank", row + across * 20.0 - ahead * 6.0, facing)
	tent(at - ahead * 30.0 + across * -4.0, facing + 90.0)
	sandbag_post(at + ahead * 18.0 + across * 2.0, facing + 180.0)
