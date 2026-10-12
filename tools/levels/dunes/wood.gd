extends "res://tools/levels/dunes/plan.gd"
## The first stretch of the dunes: the wood the player comes out of, and the
## cutting in it where pines were felled for the wire. The track runs through
## both under the trees, which is where the shade is.


func _describe() -> void:
	# Where the player comes from: the track runs on into the wood, under
	# pines that came down across it.
	for i in 3:
		var middle := ground(4.5 + i * 1.3, 200.0 + i * 0.9, 0.3 + i * 0.42)
		var along := Vector3(0.3 - i * 0.22, 0.03 * i, 1.0).normalized()
		rod("bark", middle - along * 5.0, middle + along * 5.0, 0.3, DETAIL, 8)
	ferns(Vector2(30, 190), 9.0, 7)
	ferns(Vector2(58, 212), 10.0, 8)
	ferns(Vector2(74, 180), 9.0, 7)
	_put("ammo_box", 62.8, 186.6, 20)
	_put("ammo_box", 63.3, 186.2, 75)
	_put("tree_stump_01", 61.2, 185.0, 40)

	# The cutting: what was felled lies stacked for the lorry that is here
	# to take it to the wire.
	_logs(Vector2(111, 174.5), 8.0, 4)
	_logs(Vector2(103, 172.5), -6.0, 3)
	vehicle("truck", Vector2(106, 180.5), -84.0)
	_put("tree_stump_01", 97.5, 176.5, 0)
	_put("tree_stump_01", 116.5, 180.0, 130)
	_put("tree_stump_01", 101.0, 169.5, 250)
	drop("dry_branches_medium_01", ground(113, 180.5, 0.02), 30)
	drop("dry_branches_medium_01", ground(99.5, 181.5, 0.02), 200)
	bivouac(Vector2(118.5, 172.5), 70.0)
	cover("earth", Vector2(107, 177), 9.0, 0.8)


## A stack of felled trunks on the ground at `at`, lying along the X of the
## way it is turned: `wide` of them at the bottom and one fewer in every
## layer over it.
func _logs(at: Vector2, yaw_deg: float, wide: int) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y))
	var thick := 0.24
	var layers := mini(wide, 3)
	for layer in layers:
		for i in wide - layer:
			var z := (i - (wide - layer - 1) * 0.5) * thick * 2.02
			var shift := _clutter_rng.randf_range(-0.25, 0.25)
			rod("bark", xf * Vector3(-2.6 + shift, thick + layer * thick * 1.75, z), xf * Vector3(2.6 + shift, thick + layer * thick * 1.75, z), thick, SLIGHT, 8)
	_collide_box(xf * Transform3D(Basis(), Vector3(0, layers * thick * 0.9, 0)), Vector3(5.4, layers * thick * 1.8, wide * thick * 2.0), "wood")
	for end: float in [-1.0, 1.0]:
		cylinder("wood", xf * Vector3(end * 1.6, 0, wide * thick + 0.08), 0.05, 1.0, SLIGHT, Vector3.ZERO, -1.0, 6)


func _route_through() -> void:
	route_start(ground(16, 199.5), ground(40, 201.5))
	route_zone("wood", "the wood", _ground_box(36, 162, 86, 226), [
		beat("grunt", [Vector2(56, 202.5), Vector2(68, 199), Vector2(82, 195.5)]),
		beat("grunt", [Vector2(58, 204.5), Vector2(70, 201), Vector2(84, 197.5)]),
		guard("rusher", Vector2(62.5, 187.8), Vector2(50, 200), 50.0),
	])
	route_zone("cutting", "the cutting", _ground_box(86, 162, 120, 226), [
		beat("grunt", [Vector2(117, 186.5), Vector2(99, 189)]),
		guard("grunt", Vector2(104.5, 183.6), Vector2(92, 190), 45.0),
		guard("grunt", Vector2(113.5, 177.5), Vector2(104, 186), 40.0),
		guard("rusher", Vector2(100.5, 175.0), Vector2(100, 188), 55.0),
	])
