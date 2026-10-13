extends "res://tools/levels/canals/plan.gd"
## The Vijzel axis: the Vijzelstraat, a traffic street 22 m wide between
## buildings that fill a block each, and south of the Prinsengracht the
## Vijzelgracht, a canal filled in long ago and now a broad street with the
## metro under it. The way back, and at its end the way out.

## The entrance to the metro, on the Vijzelgracht: where its shutter hangs,
## which faces north, and how wide and how deep the head of the stairs is.
const METRO := Vector3(VIJZEL_X, 0, 356.0)
const METRO_WIDE := 8.0
const METRO_DEEP := 8.0


func _describe() -> void:
	_street("vijzelstraat_north", HEREN[3], KEIZERS[0])
	front("a_mid", "e", "block")
	front("a_east", "w", "block")
	by_position()
	_street("vijzelstraat_south", KEIZERS[3], PRINSEN[0])
	front("b_mid", "e", "street", {}, DEEP, DEEP_STREET)
	front("c_mid", "e", "street", {}, DEEP_STREET, DEEP)
	front("b_east", "w", "block")
	by_position()
	_gracht()


## One length of the street, from `z0` to `z1`: its paving, a mast now on
## this side and now on that, and cars along both kerbs.
func _street(zone_name: String, z0: float, z1: float) -> void:
	in_zone(zone_name)
	street_paving(Rect2(VIJZELSTRAAT[0], z0, VIJZELSTRAAT[1] - VIJZELSTRAAT[0], z1 - z0))
	var count := roundi((z1 - z0) / 20.0)
	for i in count:
		var z := z0 + (z1 - z0) * (i + 0.5) / count
		var east := i % 2 == 1
		# Not in the mouth of the Kerkstraat, on the west side.
		if not east and z > KERK[0] - 2.0 and z < KERK[1] + 2.0:
			z = KERK[1] + 3.0
		lantern(Vector3(VIJZELSTRAAT[1] - 2.6 if east else VIJZELSTRAAT[0] + 2.6, 0, z), "mast")
	parked_cars(Vector3(VIJZELSTRAAT[0] + 4.0, 0, z0 + 8.0), Vector3(VIJZELSTRAAT[0] + 4.0, 0, minf(z1 - 8.0, KERK[0] - 4.0) if z0 > KEIZERS[0] else z1 - 8.0), 0.55)
	parked_cars(Vector3(VIJZELSTRAAT[1] - 4.0, 0, z1 - 8.0), Vector3(VIJZELSTRAAT[1] - 4.0, 0, z0 + 8.0), 0.55)
	probe(zone_name.to_pascal_case(), Vector3(VIJZEL_X, 8.0, (z0 + z1) * 0.5), Vector3(22.0, 20.0, z1 - z0), Vector3(0, -6.0, 0))


## The Vijzelgracht, 36 m from front to front, with the way down to the
## metro in the middle of it.
func _gracht() -> void:
	in_zone("vijzelgracht")
	var from := PRINSEN[3]
	var to := LIJNBAAN[0]
	street_paving(Rect2(VIJZELGRACHT[0], from, VIJZELGRACHT[1] - VIJZELGRACHT[0], to - from))
	front("d_mid", "e", "canal", {}, DEEP, DEEP_STREET)
	front("e_mid", "e", "canal", {}, DEEP_STREET, DEEP)
	front("d_east", "w", "canal")
	lanterns(Vector3(VIJZELGRACHT[0] + 4.0, 0, from + 6.0), Vector3(VIJZELGRACHT[0] + 4.0, 0, to - 6.0), 26.0, "mast")
	lanterns(Vector3(VIJZELGRACHT[1] - 4.0, 0, to - 6.0), Vector3(VIJZELGRACHT[1] - 4.0, 0, from + 6.0), 26.0, "mast")
	parked_cars(Vector3(VIJZELGRACHT[0] + 6.5, 0, from + 10.0), Vector3(VIJZELGRACHT[0] + 6.5, 0, DWARS[0] - 3.0), 0.6)
	parked_cars(Vector3(VIJZELGRACHT[0] + 6.5, 0, DWARS[1] + 3.0), Vector3(VIJZELGRACHT[0] + 6.5, 0, to - 8.0), 0.6)
	parked_cars(Vector3(VIJZELGRACHT[1] - 6.5, 0, to - 8.0), Vector3(VIJZELGRACHT[1] - 6.5, 0, from + 10.0), 0.6)
	_metro()
	for i in 2:
		var z := from + (to - from) * (i + 0.5) / 2.0
		probe("Vijzelgracht%d" % i, Vector3(VIJZEL_X, 7.0, z), Vector3(36.0, 18.0, (to - from) / 2.0), Vector3(0, -5.0, 0))
	by_position()


## The head of the stairs to the metro: a low building of concrete with a
## shutter in its north side, down at night. It goes up when the town is
## cleared.
func _metro() -> void:
	var high := 3.8
	var west := METRO.x - METRO_WIDE * 0.5
	var east := METRO.x + METRO_WIDE * 0.5
	var south := METRO.z + METRO_DEEP
	wall("concrete", true, METRO.z + 0.2, 0.4, west, east, 0.0, high, [[METRO.x - 2.0, METRO.x + 2.0, 0.0, 3.4]])
	wall("concrete", true, south - 0.2, 0.4, west, east, 0.0, high, [])
	wall("concrete", false, west + 0.2, 0.4, METRO.z + 0.4, south - 0.4, 0.0, high, [])
	wall("concrete", false, east - 0.2, 0.4, METRO.z + 0.4, south - 0.4, 0.0, high, [])
	box("concrete", Vector3(METRO.x, high + 0.15, METRO.z + METRO_DEEP * 0.5), Vector3(METRO_WIDE + 0.6, 0.3, METRO_DEEP + 0.6))
	roller_door(Vector3(METRO.x, 1.7, METRO.z + 0.2), Vector3.FORWARD, Vector2(4.0, 3.4), true)


func _route_north() -> void:
	route_checkpoint("vijzelstraat", "Vijzelstraat", Vector3(VIJZEL_X, 0, HEREN[3] + 2.5), Vector3(VIJZEL_X, 0, KEIZERS[0]),
		AABB(Vector3(VIJZELSTRAAT[0], -1, HEREN[3]), Vector3(22, 4, 5)))
	route_zone("vijzelstraat", "the Vijzelstraat", AABB(Vector3(VIJZELSTRAAT[0], -3, 52), Vector3(22, 10, 57)), [
		["grunt", Vector3(172.5, 0, 78)], ["grunt", Vector3(187.5, 0, 92)], ["grunt", Vector3(186, 0, 70)],
		["rusher", Vector3(180, 0, 104)],
	])


func _route_south() -> void:
	route_checkpoint("kerkstraat", "Kerkstraat", Vector3(VIJZEL_X, 0, KEIZERS[3] + 2.2), Vector3(VIJZEL_X, 0, PRINSEN[0]),
		AABB(Vector3(VIJZELSTRAAT[0], -1, KEIZERS[3]), Vector3(22, 4, 4.5)))
	route_zone("kerkstraat", "the Kerkstraat corner", AABB(Vector3(VIJZELSTRAAT[0], -3, 167), Vector3(22, 10, 73)), [
		["grunt", Vector3(173, 0, 192)], ["grunt", Vector3(183.5, 0, 216)], ["grunt", Vector3(175, 0, 233)],
		["rusher", Vector3(152, 0, 204)],
	])


func _route_gracht() -> void:
	route_checkpoint("vijzelgracht", "Vijzelgracht", Vector3(VIJZEL_X, 0, PRINSEN[3] + 2.5), Vector3(VIJZEL_X, 0, METRO.z),
		AABB(Vector3(VIJZELGRACHT[0], -1, PRINSEN[3] + 0.5), Vector3(36, 4, 5)))
	route_zone("vijzelgracht", "the Vijzelgracht", AABB(Vector3(VIJZELGRACHT[0], -3, 296), Vector3(36, 10, 96)), [
		["grunt", Vector3(168, 0, 330)], ["grunt", Vector3(187.5, 0, 345)], ["grunt", Vector3(190, 0, 314)],
		["rusher", Vector3(170, 0, 384)], ["heavy", Vector3(171, 0, 360)], ["heavy", Vector3(190, 0, 372)],
	])
	route_exit("Leave by the metro", AABB(Vector3(METRO.x - 2.3, -0.1, METRO.z + 1.4), Vector3(4.6, 3.6, 3.0)), "",
		Vector3(METRO.x, 3.55, METRO.z), Vector3.FORWARD)
