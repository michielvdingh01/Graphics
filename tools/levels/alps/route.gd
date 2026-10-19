extends "res://tools/levels/alps/plan.gd"
## The way across the Alps when they are played as a level, alone or
## together, and not as an arena: from the camp in the west, in the shade of
## the mountains, through the wood's edge, the barns of the Moos, the chapel,
## the farm and the shrine, past the hunter's stand on the slope to the north
## and over the meadows below Ehrwald, into the sun, to the camp in the east
## and the road to Ehrwald beyond it. It is near three kilometres: the
## vehicles of the camps and of the valley are there to cover it.
##
## Every fight is held by a watch (guard() and beat() in tools/kit/land.gd):
## nothing starts by walking into it, but by being seen or heard. The
## checkpoints lie between the fights, each where whoever carries on finds a
## vehicle near by.

## The fights, west to east: [id, title, (x0, z0, x1, z1) of where it is
## fought]. Each lies across the way from the place before it to the next,
## with its enemies in the near half of it, and a place to carry on from
## lies within 75 m of it: a watch further from anybody than that sleeps
## (scripts/game.gd, _stir()). The enemies of each are in _describe().
const FIGHTS := [
	["edge", "the edge of the wood", Rect2(560, 830, 110, 150)],
	["barns", "the barns of the Moos", Rect2(900, 840, 110, 160)],
	["chapel", "the chapel", Rect2(1250, 800, 110, 150)],
	["farm", "the farm", Rect2(1530, 780, 110, 150)],
	["shrine", "the shrine by the road", Rect2(1820, 800, 110, 150)],
	["stand", "the hunter's stand", Rect2(2110, 560, 130, 180)],
	["meadows", "the meadows below Ehrwald", Rect2(2420, 560, 110, 160)],
	["camp", "the camp in the east", Rect2(2790, 640, 110, 200)],
]


func _describe() -> void:
	route_start(ground(372, 905, 0.0), ground(600, 900))
	_carry_on("wood_edge", "the edge of the wood", Vector2(495, 905), Vector2(600, 905))
	_fight(0, [
		guard("grunt", Vector2(605, 870), Vector2(450, 900), 40.0),
		guard("grunt", Vector2(610, 945), Vector2(450, 910), 40.0),
		beat("rusher", [Vector2(595, 850), Vector2(640, 960)]),
		guard("heavy", Vector2(645, 905), Vector2(480, 905), 30.0),
	])
	_carry_on("moos", "the Moos", Vector2(840, 905), Vector2(950, 920))
	_fight(1, [
		guard("grunt", Vector2(940, 880), Vector2(800, 900), 45.0),
		guard("grunt", Vector2(945, 965), Vector2(800, 920), 45.0),
		beat("grunt", [Vector2(935, 990), Vector2(990, 940)]),
		guard("rusher", Vector2(975, 905), Vector2(820, 905), 50.0),
		guard("heavy", Vector2(995, 870), Vector2(840, 900), 35.0),
	])
	_carry_on("chapel_approach", "the way to the chapel", Vector2(1190, 885), Vector2(1300, 875))
	_fight(2, [
		guard("grunt", Vector2(1290, 840), Vector2(1150, 880), 45.0),
		guard("grunt", Vector2(1300, 920), Vector2(1150, 890), 45.0),
		beat("rusher", [Vector2(1285, 860), Vector2(1330, 935)]),
		guard("grunt", Vector2(1335, 875), Vector2(1180, 885), 40.0),
	])
	_carry_on("chapel_way", "the way past the chapel", Vector2(1460, 870), Vector2(1580, 860))
	_fight(3, [
		guard("grunt", Vector2(1565, 830), Vector2(1420, 870), 45.0),
		guard("grunt", Vector2(1575, 910), Vector2(1420, 880), 40.0),
		guard("heavy", Vector2(1610, 860), Vector2(1450, 870), 35.0),
		beat("rusher", [Vector2(1590, 800), Vector2(1630, 920)]),
		guard("grunt", Vector2(1620, 890), Vector2(1460, 880), 45.0),
		guard("rusher", Vector2(1630, 840), Vector2(1470, 860), 50.0),
	])
	_carry_on("shrine_approach", "the way to the shrine", Vector2(1760, 870), Vector2(1870, 870))
	_fight(4, [
		guard("grunt", Vector2(1855, 840), Vector2(1720, 870), 45.0),
		guard("grunt", Vector2(1860, 915), Vector2(1720, 880), 45.0),
		beat("rusher", [Vector2(1850, 900), Vector2(1900, 820)]),
		guard("heavy", Vector2(1900, 880), Vector2(1740, 870), 35.0),
	])
	_carry_on("track", "the track up the slope", Vector2(2120, 795), Vector2(2160, 680))
	_fight(5, [
		guard("grunt", Vector2(2160, 690), Vector2(2120, 820), 50.0),
		guard("grunt", Vector2(2200, 660), Vector2(2130, 830), 50.0),
		beat("rusher", [Vector2(2140, 650), Vector2(2215, 700)]),
	])
	_carry_on("stand_top", "the hunter's stand", Vector2(2190, 600), Vector2(2400, 620))
	_carry_on("meadows_approach", "the way to the meadows", Vector2(2365, 620), Vector2(2480, 630))
	_fight(6, [
		guard("grunt", Vector2(2455, 590), Vector2(2320, 610), 45.0),
		guard("grunt", Vector2(2460, 670), Vector2(2320, 630), 45.0),
		beat("grunt", [Vector2(2450, 640), Vector2(2510, 700)]),
		guard("rusher", Vector2(2490, 610), Vector2(2340, 620), 50.0),
		guard("heavy", Vector2(2510, 660), Vector2(2350, 630), 35.0),
	])
	_carry_on("ehrwald_meadows", "the meadows below Ehrwald", Vector2(2730, 650), Vector2(2850, 740))
	_fight(7, [
		guard("grunt", Vector2(2825, 690), Vector2(2690, 650), 45.0),
		guard("grunt", Vector2(2830, 760), Vector2(2690, 660), 45.0),
		guard("heavy", Vector2(2860, 720), Vector2(2700, 660), 35.0),
		beat("rusher", [Vector2(2845, 800), Vector2(2880, 700)]),
		guard("grunt", Vector2(2870, 745), Vector2(2710, 670), 40.0),
		guard("rusher", Vector2(2860, 670), Vector2(2700, 650), 50.0),
	])
	var road := ground(3110, 770)
	route_exit("Take the road to Ehrwald", AABB(road - Vector3(12, 2, 12), Vector3(24, 6, 24)))


## Fight `index` of FIGHTS, held by `enemies`: the box it is fought in reaches
## from under the lowest ground in it to well over the highest.
func _fight(index: int, enemies: Array) -> void:
	var fight: Array = FIGHTS[index]
	route_zone(fight[0], fight[1], _box_over(fight[2]), enemies)
	# No tree stands where an enemy stands or walks.
	for enemy: Array in enemies:
		var spots: Array = enemy[2].get("beat", [enemy[1]])
		for spot: Vector3 in spots:
			keep_bare(Vector2(spot.x, spot.z), 3.0)


## The box over `area` of the land, from under its lowest ground to well
## over its highest.
func _box_over(area: Rect2) -> AABB:
	var low := INF
	var high := -INF
	var spots := _spots_in(area)
	for row in range(spots[1], spots[3] + 1):
		for column in range(spots[0], spots[2] + 1):
			var h := _heights[row * _across() + column]
			low = minf(low, h)
			high = maxf(high, h)
	return AABB(Vector3(area.position.x, low - 4.0, area.position.y), Vector3(area.size.x, high - low + 30.0, area.size.y))


## A place to carry on from, on the ground at `at`, looking towards `look`,
## that counts within 9 m of it.
func _carry_on(id: String, title: String, at: Vector2, look: Vector2) -> void:
	var foot := ground(at.x, at.y)
	route_checkpoint(id, title, foot, ground(look.x, look.y), AABB(foot - Vector3(9, 3, 9), Vector3(18, 8, 18)))
	keep_bare(at, 12.0)
