extends "res://tools/levels/canals/plan.gd"
## The two streets that cut across from the Spiegel axis to the Vijzel axis:
## the Kerkstraat between the Keizersgracht and the Prinsengracht, and a
## Weteringdwarsstraat between the Spiegelgracht and the Vijzelgracht.
## Narrow, with a lantern on a bracket now and then, and dark between. The
## round does not go through them; whoever knows them cuts it short.


func _describe() -> void:
	_alley("kerkstraat", SPIEGELSTRAAT[1], VIJZELSTRAAT[0], KERK)
	front("b_mid", "s", "street")
	front("c_mid", "n", "street")
	by_position()
	_alley("weteringdwars", SPIEGELGRACHT[3], VIJZELGRACHT[0], DWARS)
	front("d_mid", "s", "street")
	front("e_mid", "n", "street")
	by_position()


## One of them, from `x0` to `x1`, between the fronts `lines` gives.
func _alley(zone_name: String, x0: float, x1: float, lines: Array[float]) -> void:
	in_zone(zone_name)
	street_paving(Rect2(x0, lines[0], x1 - x0, lines[1] - lines[0]))
	var count := roundi((x1 - x0) / 20.0)
	for i in count:
		var x := x0 + (x1 - x0) * (i + 0.5) / count
		var south := i % 2 == 1
		lantern(Vector3(x, 0, lines[1] if south else lines[0]), "wall", 180.0 if south else 0.0)
		if i % 2 == 0:
			crates(Vector3(x + 6.0, 0, lines[1] - 1.5), 2)
	var middle := Vector3((x0 + x1) * 0.5, 5.0, (lines[0] + lines[1]) * 0.5)
	probe(zone_name.to_pascal_case(), middle, Vector3(x1 - x0, 14.0, lines[1] - lines[0]), Vector3(0, -3.0, 0))
