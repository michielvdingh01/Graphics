extends "res://tools/levels/supermarket/plan.gd"
## The way through the level: over the lot from the far end, in through the
## doors, through the shop to the back, and out across the yard.


## An AABB on the floor from corner to corner, two storeys high.
func _floor(x0: float, z0: float, x1: float, z1: float) -> AABB:
	return AABB(Vector3(x0, 0, z0), Vector3(x1 - x0, 4, z1 - z0))


func _on(x: float, z: float) -> Vector3:
	return Vector3(x, 0.1, z)


func _describe() -> void:
	route_start(_on(-112.0, 9.5), _on(-90.0, 9.5))
	route_zone("lot", "the parking lot", _floor(-86.0, -40.0, -30.0, 40.0), [
		["grunt", _on(-44.0, -4.0)], ["grunt", _on(-52.0, 12.0)], ["rusher", _on(-40.0, 22.0)], ["grunt", _on(-36.0, -18.0)], ["heavy", _on(-30.0, 2.0)],
	])
	route_checkpoint("walk", "the store", _on(-12.0, 25.0), _on(0.0, 25.0), _floor(-14.0, 20.0, -7.0, 30.0))
	route_zone("front", "the checkouts", _floor(1.0, -30.0, 19.5, 43.0), [
		["grunt", _on(13.5, -13.0)], ["grunt", _on(13.5, 2.0)], ["rusher", _on(13.5, -8.0)], ["grunt", _on(5.0, -6.0)],
		["grunt", _on(8.0, 40.0)], ["rusher", _on(6.0, 34.5)],
	])
	route_checkpoint("cross", "the aisles", _on(18.5, 28.0), _on(30.0, 28.0), _floor(16.0, 25.0, 19.4, 30.0))
	route_zone("aisles", "the aisles", _floor(19.5, -30.0, 60.0, 43.0), [
		["grunt", _on(30.0, -0.1)], ["grunt", _on(39.5, -16.0)], ["heavy", _on(39.5, 7.0)], ["rusher", _on(50.0, 9.4)], ["grunt", _on(50.0, -14.2)], ["grunt", _on(30.0, 18.8)], ["grunt", _on(30.0, 40.0)],
	])
	route_zone("fresh", "the back of the shop", _floor(60.0, -42.0, 66.0, 43.0), [
		["grunt", _on(61.0, -14.0)], ["rusher", _on(62.0, -22.0)], ["grunt", _on(63.0, 34.0)], ["heavy", _on(58.0, -33.0)],
	])
	route_checkpoint("stock", "the stockroom", _on(63.5, 3.0), _on(70.0, 3.0), _floor(61.0, 0.0, 65.9, 6.0))
	route_zone("stockroom", "the stockroom", _floor(70.0, -44.0, 86.0, 28.0), [
		["grunt", _on(78.0, -14.5)], ["grunt", _on(83.0, 10.0)], ["rusher", _on(72.0, 14.0)], ["heavy", _on(78.0, 24.0)],
	])
	route_exit("the yard", _floor(112.0, -30.0, 126.0, 10.0))
