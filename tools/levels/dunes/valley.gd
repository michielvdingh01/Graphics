extends "res://tools/levels/dunes/plan.gd"
## The second stretch: the pass through the spur where the wood ends, with
## its barrier, and the valley beyond it that the wind has blown bare. In the
## valley there is no shade but under the pines along its south side, beside
## the lorry that was left in it and under the net of the dump. It ends
## where the track climbs to the saddle.


func _describe() -> void:
	# The pass: a barrier across the track, a box for the sentry and a post
	# of sandbags that looks down the track into the wood.
	barrier_pole(Vector2(137.5, 182.6), -90.0, 5.2)
	sentry_box(Vector2(139.8, 181.2), 0.0)
	sign_post(Vector2(127.5, 188.8), -90.0, "HALT", 0.3, "paper")
	sandbag_post(Vector2(141.5, 190.6), -90.0, 4.0, 2.6)
	_put("ammo_box", 142.4, 190.0, 10)
	_put("old_military_crate", 142.8, 191.6, 80)
	vehicle("jeep", Vector2(148.5, 191.5), 78.0)
	cover("earth", Vector2(142, 186), 9.0, 0.95, 0.5)
	probe("Pass", ground(142, 186, 3.0), Vector3(40, 10, 40), Vector3.ZERO)

	# The valley: a look-out on the knoll under the north dune, the lorry
	# that broke down, and a dump under a net where the track leaves.
	sandbag_ring(Vector2(226, 171), 2.7, 180.0, 6)
	_put("ammo_box", 227.3, 170.2, 40)
	vehicle("truck", Vector2(198, 201), 118.0)
	_put("old_tyre", 195.2, 203.4, 0)
	camo_net(Vector2(240, 197.5), 14.0, Vector2(9.5, 6.0), 3.2)
	crates(ground(238.0, 196.4), 4)
	crates(ground(241.6, 199.0), 3)
	_put("old_military_crate", 236.2, 199.4, 12)
	_put("wooden_military_crate", 243.2, 196.0, 95)
	fuel(ground(244.4, 199.8))
	fuel(ground(245.2, 199.2))
	barrel(ground(244.9, 200.6))
	cover("earth", Vector2(240, 197.5), 6.5, 0.8)
	ferns(Vector2(190, 214), 8.0, 6)
	# Thorn scrub shuts off the wood to the east, beyond where the track
	# turns north.
	thicket([Vector2(263, 203), Vector2(280, 187), Vector2(296, 175), Vector2(330, 169)])


func _route_through() -> void:
	route_zone("pass", "the pass", _ground_box(120, 162, 160, 214), [
		guard("grunt", Vector2(138.8, 184.7), Vector2(118, 186), 40.0),
		guard("grunt", Vector2(141.6, 189.6), Vector2(120, 188), 40.0),
		beat("grunt", [Vector2(152, 186), Vector2(156, 192), Vector2(149, 195)], true),
		guard("rusher", Vector2(146.6, 188.4), Vector2(128, 186), 50.0),
	])
	_carry_on("pass", "Dune pass", Vector2(158, 188), Vector2(176, 191), 5.0)
	# The valley is held in two: the lorry that broke down with those who
	# walk the track to it, and beyond them the dump, with the look-out on
	# its knoll over both.
	route_zone("valley", "the valley", _ground_box(166, 160, 208, 226), [
		beat("rusher", [Vector2(182, 191), Vector2(206, 193.5)]),
		guard("grunt", Vector2(192.0, 197.0), Vector2(176, 192), 45.0),
		guard("heavy", Vector2(204.0, 198.6), Vector2(222, 192), 35.0),
		beat("grunt", [Vector2(186, 184), Vector2(204, 180), Vector2(208, 187), Vector2(190, 189)], true),
		beat("grunt", [Vector2(184, 208.5), Vector2(208, 209)]),
	])
	route_zone("dump", "the dump", _ground_box(208, 160, 258, 226), [
		guard("grunt", Vector2(225.4, 171.6), Vector2(200, 192), 55.0),
		guard("grunt", Vector2(227.2, 170.3), Vector2(246, 188), 45.0),
		guard("heavy", Vector2(237.0, 201.2), Vector2(212, 198), 40.0),
		guard("grunt", Vector2(247.5, 194.0), Vector2(252, 184), 45.0),
		beat("grunt", [Vector2(238, 189), Vector2(250, 184), Vector2(240, 178), Vector2(226, 184)], true),
		beat("rusher", [Vector2(250, 186), Vector2(220, 192.5)]),
	])
	_carry_on("saddle", "The saddle", Vector2(261, 176.5), Vector2(270, 168), 5.5)
