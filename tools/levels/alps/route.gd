extends "res://tools/levels/alps/plan.gd"
## The way across the Alps when they are played as a level, alone or
## together, and not as an arena: from the camp in the west over the barns of
## the Moos to the chapel by the road, up through the edge of the wood to the
## hunter's stand on the terrace, along the path on the terrace, down the
## steep path in the east to the road, and through the camp in the east to
## the canal that leads on to Ehrwald.
##
## Every fight is held by a watch (guard() and beat() in tools/kit/land.gd):
## nothing starts by walking into it, but by being seen or heard. The
## checkpoints lie between the fights.

## The fights, west to east: [id, title, (x0, z0, x1, z1) of where it is
## fought]. Each lies across the way from the place before it to the next,
## with its enemies in the near half of it, and a place to carry on from
## lies within 75 m of it: a watch further from anybody than that sleeps
## (scripts/game.gd, _stir()). The enemies of each are in _describe().
const FIGHTS := [
	["barns", "the barns of the Moos", Rect2(390, 1000, 150, 110)],
	["chapel", "the chapel", Rect2(480, 900, 130, 110)],
	["edge", "the edge of the wood", Rect2(680, 760, 110, 120)],
	["stand", "the hunter's stand", Rect2(820, 420, 120, 140)],
	["terrace", "the path along the terrace", Rect2(1090, 370, 140, 110)],
	["foot", "the foot of the slope", Rect2(1460, 590, 130, 120)],
	["camp", "the camp in the east", Rect2(1350, 780, 170, 160)],
]


func _describe() -> void:
	var camp: Vector2 = CAMPS[0]
	route_start(ground(camp.x + 40.0, camp.y, 0.0), ground(420, 1080))
	_carry_on("west_moos", "the Moos", Vector2(330, 1110), Vector2(430, 1060))
	_fight(0, [
		guard("grunt", Vector2(420, 1050), Vector2(300, 1100), 40.0),
		guard("grunt", Vector2(440, 1095), Vector2(300, 1120), 40.0),
		beat("rusher", [Vector2(410, 1010), Vector2(470, 1070)]),
		guard("heavy", Vector2(500, 1060), Vector2(330, 1100), 30.0),
	])
	_carry_on("chapel_way", "the way to the chapel", Vector2(560, 1030), Vector2(530, 960))
	_fight(1, [
		guard("grunt", Vector2(520, 930), Vector2(560, 1030), 45.0),
		guard("grunt", Vector2(560, 945), Vector2(560, 1030), 45.0),
		beat("rusher", [Vector2(500, 915), Vector2(590, 960)]),
		guard("grunt", Vector2(595, 925), Vector2(560, 1020), 40.0),
	])
	_carry_on("slope_road", "the road below the slope", Vector2(655, 935), Vector2(720, 840))
	_fight(2, [
		guard("grunt", Vector2(720, 800), Vector2(660, 930), 45.0),
		guard("grunt", Vector2(750, 830), Vector2(660, 930), 45.0),
		beat("rusher", [Vector2(700, 780), Vector2(760, 860)]),
		guard("heavy", Vector2(740, 775), Vector2(690, 880), 35.0),
	])
	_carry_on("path_up", "the path up the slope", Vector2(855, 610), Vector2(870, 540))
	_fight(3, [
		guard("grunt", Vector2(870, 500), Vector2(850, 620), 45.0),
		guard("grunt", Vector2(900, 470), Vector2(860, 610), 45.0),
		beat("rusher", [Vector2(840, 470), Vector2(910, 530)]),
		guard("grunt", Vector2(880, 440), Vector2(855, 610), 40.0),
	])
	_carry_on("terrace", "the terrace", Vector2(1032, 402), Vector2(1100, 412))
	_fight(4, [
		guard("grunt", Vector2(1150, 395), Vector2(990, 400), 45.0),
		guard("grunt", Vector2(1170, 440), Vector2(990, 405), 45.0),
		beat("rusher", [Vector2(1150, 380), Vector2(1200, 455)]),
		guard("heavy", Vector2(1195, 458), Vector2(1000, 405), 35.0),
	])
	_carry_on("path_down", "the path down", Vector2(1470, 540), Vector2(1520, 600))
	_fight(5, [
		guard("grunt", Vector2(1540, 640), Vector2(1480, 545), 45.0),
		guard("grunt", Vector2(1505, 686), Vector2(1480, 550), 45.0),
		beat("rusher", [Vector2(1510, 640), Vector2(1560, 690)]),
		guard("grunt", Vector2(1555, 655), Vector2(1500, 560), 40.0),
	])
	_carry_on("road_east", "the road in the east", Vector2(1440, 720), Vector2(1400, 840))
	_fight(6, [
		guard("grunt", Vector2(1400, 850), Vector2(1440, 720), 45.0),
		guard("grunt", Vector2(1465, 860), Vector2(1440, 720), 45.0),
		guard("heavy", Vector2(1420, 890), Vector2(1440, 730), 35.0),
		beat("rusher", [Vector2(1385, 845), Vector2(1480, 905)]),
		guard("grunt", Vector2(1495, 880), Vector2(1430, 730), 40.0),
		guard("rusher", Vector2(1370, 880), Vector2(1440, 730), 50.0),
	])
	# Past the camp, along the canal that drains the Moos towards Ehrwald.
	var way_out := ground(1545, 905)
	route_exit("Follow the canal to Ehrwald", AABB(way_out - Vector3(12, 2, 12), Vector3(24, 6, 24)))


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
