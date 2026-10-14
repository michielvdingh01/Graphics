extends "res://tools/levels/canals/plan.gd"
## The Spiegel axis, one straight line from the Herengracht to the museum:
## north of the Prinsengracht the Nieuwe Spiegelstraat, a street of antique
## shops eleven metres from front to front, and south of it the
## Spiegelgracht, a narrow canal between two quays. The way north.

## The middle of the west quay and of the east quay of the Spiegelgracht, x.
const WEST_QUAY := (SPIEGELGRACHT[0] + SPIEGELGRACHT[1]) * 0.5
const EAST_QUAY := (SPIEGELGRACHT[2] + SPIEGELGRACHT[3]) * 0.5


func _describe() -> void:
	_street("spiegelstraat_north", HEREN[3], KEIZERS[0])
	front("a_west", "e", "street", {"shops": true})
	front("a_mid", "w", "street", {"shops": true})
	by_position()
	_street("spiegelstraat_south", KEIZERS[3], PRINSEN[0])
	front("b_west", "e", "street", {"shops": true})
	front("b_mid", "w", "street", {"shops": true}, DEEP, DEEP_STREET)
	front("c_mid", "w", "street", {"shops": true}, DEEP_STREET, DEEP)
	by_position()
	_gracht()


## One length of the street, from `z0` to `z1`: its paving, a lantern on a
## bracket now on this side and now on that, and something to stand behind.
func _street(zone_name: String, z0: float, z1: float) -> void:
	in_zone(zone_name)
	street_paving(Rect2(SPIEGELSTRAAT[0], z0, SPIEGELSTRAAT[1] - SPIEGELSTRAAT[0], z1 - z0))
	var count := roundi((z1 - z0) / 16.0)
	for i in count:
		var z := z0 + (z1 - z0) * (i + 0.5) / count
		# Not where the Kerkstraat comes in from the east.
		var east := i % 2 == 1 and not (z > KERK[0] - 1.0 and z < KERK[1] + 1.0)
		lantern(Vector3(SPIEGELSTRAAT[1] if east else SPIEGELSTRAAT[0], 0, z), "wall", -90.0 if east else 90.0)
		if i % 2 == 0:
			crates(Vector3(SPIEGELSTRAAT[1] - 1.6, 0, z + 5.0), 3)
		else:
			barrier(Vector3(SPIEGELSTRAAT[0] + 1.4, 0, z + 5.0), 90.0)
	probe(zone_name.to_pascal_case(), Vector3(SPIEGEL_X, 6.0, (z0 + z1) * 0.5), Vector3(SPIEGELSTRAAT[1] - SPIEGELSTRAAT[0], 16.0, z1 - z0), Vector3(0, -4.0, 0))


## The Spiegelgracht: its water runs from the Prinsengracht to the
## Lijnbaansgracht, under the quays of both.
func _gracht() -> void:
	in_zone("spiegelgracht")
	var from := PRINSEN[3]
	var to := LIJNBAAN[0]
	canal(Rect2(SPIEGELGRACHT[1], PRINSEN[2], SPIEGELGRACHT[2] - SPIEGELGRACHT[1], LIJNBAAN[1] - PRINSEN[2]), "ns")
	street_paving(Rect2(SPIEGELGRACHT[0], from, SPIEGELGRACHT[1] - SPIEGELGRACHT[0], to - from))
	street_paving(Rect2(SPIEGELGRACHT[2], from, SPIEGELGRACHT[3] - SPIEGELGRACHT[2], to - from))
	front("d_west", "e", "low")
	front("d_mid", "w", "low", {}, DEEP, DEEP_STREET)
	front("e_mid", "w", "low", {}, DEEP_STREET, DEEP)
	var steps := PackedVector3Array([Vector3(SPIEGELGRACHT[1], 0, lerpf(from, to, 0.3)), Vector3(SPIEGELGRACHT[2], 0, lerpf(from, to, 0.75))])
	kerb_line(Vector3(SPIEGELGRACHT[1] - KERB, 0, from + 5.0), Vector3(SPIEGELGRACHT[1] - KERB, 0, to - 5.0), "ritter", 0.6, steps)
	kerb_line(Vector3(SPIEGELGRACHT[2] + KERB, 0, to - 5.0), Vector3(SPIEGELGRACHT[2] + KERB, 0, from + 5.0), "ritter", 0.6, steps)
	water_steps(steps[0], 90.0)
	water_steps(steps[1], -90.0)
	probe("Spiegelgracht", Vector3(SPIEGEL_X, 7.0, (from + to) * 0.5), Vector3(SPIEGELGRACHT[3] - SPIEGELGRACHT[0], 18.0, to - from), Vector3(0, -5.0, 0))
	by_position()


func _route_gracht() -> void:
	var at := func(share: float) -> float: return lerpf(PRINSEN[3], LIJNBAAN[0], share)
	route_zone("spiegelgracht", "the Spiegelgracht", AABB(Vector3(SPIEGELGRACHT[0], -3, PRINSEN[3] + 9.0), Vector3(SPIEGELGRACHT[3] - SPIEGELGRACHT[0], 10, LIJNBAAN[0] - PRINSEN[3] - 17.0)), [
		["grunt", Vector3(WEST_QUAY, 0, at.call(0.55))], ["grunt", Vector3(EAST_QUAY, 0, at.call(0.35))], ["grunt", Vector3(WEST_QUAY, 0, at.call(0.2))],
		["rusher", Vector3(EAST_QUAY, 0, at.call(0.15))],
	])


func _route_south() -> void:
	route_zone("spiegelstraat", "the Nieuwe Spiegelstraat", AABB(Vector3(SPIEGELSTRAAT[0], -3, KEIZERS[3] + 5.0), Vector3(SPIEGELSTRAAT[1] - SPIEGELSTRAAT[0], 10, PRINSEN[0] - KEIZERS[3] - 9.0)), [
		["grunt", Vector3(SPIEGEL_X - 3.0, 0, KERK[1] + 8.0)], ["grunt", Vector3(SPIEGEL_X + 3.0, 0, KERK[0] - 6.0)], ["grunt", Vector3(SPIEGEL_X - 3.0, 0, KEIZERS[3] + 8.0)],
		["rusher", Vector3(SPIEGELSTRAAT[1] + 16.0, 0, (KERK[0] + KERK[1]) * 0.5)],
	])


func _route_north() -> void:
	route_zone("antique_shops", "the antique shops", AABB(Vector3(SPIEGELSTRAAT[0], -3, HEREN[3] + 5.0), Vector3(SPIEGELSTRAAT[1] - SPIEGELSTRAAT[0], 10, KEIZERS[0] - HEREN[3] - 9.0)), [
		["grunt", Vector3(SPIEGEL_X - 3.0, 0, HEREN[3] + 27.0)], ["grunt", Vector3(SPIEGEL_X + 3.0, 0, HEREN[3] + 43.0)], ["rusher", Vector3(SPIEGEL_X, 0, HEREN[3] + 12.0)],
	])
