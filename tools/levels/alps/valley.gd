extends "res://tools/levels/alps/plan.gd"
## The floor of the basin as people made it, and what grows on it between
## the woods. The hay barns of the Moos by the dozen, the chapel by the road,
## the farm, a shrine, the hunters' stands at the edges of the woods on the
## slopes, where a marksman sees out over the valley; fences, and a line of
## poles along the road. And the cover a valley full of marksmen needs:
## hedges of dwarf pine and young spruce along the ditches of the Moos,
## copses, and a sycamore by a barn or alone on a meadow.
##
## In three goes (see tools/levels/alps.gd): _describe() before the vehicles
## and the route, for what the route is fought round; _scatter() after them,
## for the barns that stand anywhere they leave room; _meadow_cover() after the
## woods. Whatever is built keeps the woods off its ground (keep_open()), and
## nothing grows where an enemy stands or a vehicle waits (keep_bare()).

## The hay barns where the route is fought, and by the road between:
## [x, z, the way the door faces, size].
const BARNS := [
	# The barns of the Moos in the west, by the cart track.
	[425, 1085, 0.0, "middle"], [515, 1052, 90.0, "large"], [395, 1020, 180.0, "small"],
	# By the chapel, between the road and the track.
	[630, 965, 10.0, "large"], [705, 975, 170.0, "small"],
	# By the farm.
	[975, 955, 180.0, "middle"], [1130, 965, 0.0, "small"],
	# The Moos in the east, before the camp.
	[1255, 815, 200.0, "middle"], [1300, 915, 160.0, "large"],
]
## The hunters' stands: [x, z, how high its floor is, how far down the
## slope the wood leaves open for its view, in metres]. The one by the route
## stands on the terrace by the path along it and looks out over the Moos;
## the others stand on the spurs of the slope, from 1100 to 1270 metres, and
## look at the middle of the Moos.
const STANDS := [
	[862, 452, 4.5, 0.0],
	[300, 250, 5.0, 240.0],
	[1300, 250, 4.5, 240.0],
	[1000, 60, 5.0, 280.0],
	[200, 460, 4.5, 180.0],
]
## Where the stands high on the slopes look, and the way the one by the
## route looks (0 looks along +Z: a stand has its stair at the back).
const VIEW_TO := Vector2(800, 1000)
const ROUTE_STAND_LOOKS := 20.0
## How many more barns stand about the meadows, and how far one is from the
## next at least, in metres.
const MORE_BARNS := 30
const BARN_SPACING := 40.0
## Where barns, copses and hedges go: the Moos and the meadows at the foot of
## the slope.
const FLOOR := Rect2(20, 640, 1560, 545)


func _describe() -> void:
	in_zone("")
	for barn: Array in BARNS:
		_barn(Vector2(barn[0], barn[1]), barn[2], barn[3])
	_chapel(Vector2(522, 962))
	_farm(Vector2(1050, 900))
	_shrine()
	for stand: Array in STANDS:
		var at := Vector2(stand[0], stand[1])
		var view: float = stand[3]
		var looks := ROUTE_STAND_LOOKS
		if view > 0.0:
			var ahead := (VIEW_TO - at).normalized()
			looks = rad_to_deg(atan2(ahead.x, ahead.y))
		hunting_stand(at, looks, stand[2])
		keep_open(Rect2(at - Vector2(4, 4), Vector2(8, 8)))
		if view > 0.0:
			_perch(at, looks, view)
	_poles()


## The barns that stand anywhere the route, the camps and the vehicles leave
## room: on the meadows of the floor, never steep, never in the wood, off the
## roads, each turned with the strips of the Moos.
func _scatter() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash("alps barns")
	var placed: Array[Vector2] = []
	for barn: Array in BARNS:
		placed.append(Vector2(barn[0], barn[1]))
	var tries := 0
	var built := 0
	while built < MORE_BARNS and tries < 4000:
		tries += 1
		var at := Vector2(dice.randf_range(FLOOR.position.x, FLOOR.end.x), dice.randf_range(FLOOR.position.y, FLOOR.end.y))
		if not _barn_fits(at, placed):
			continue
		var size: String = ["small", "middle", "middle", "large"][dice.randi() % 4]
		var faces := (0.0 if dice.randf() < 0.5 else 180.0) + dice.randf_range(-12.0, 12.0)
		if dice.randf() < 0.2:
			faces += 90.0
		_barn(at, faces, size)
		placed.append(at)
		built += 1
		# A sycamore by every third barn.
		if dice.randf() < 0.33:
			var by := at + Vector2.from_angle(dice.randf() * TAU) * dice.randf_range(9.0, 13.0)
			if _tree_fits(by):
				plant("maple", by, dice.randf_range(0.8, 1.1), dice.randf() * 360.0)
	print("Valley: %d barns more in %d tries" % [built, tries])
	_strays(dice, placed)
	_farmland(dice, placed)


## Below a hunter's stand high on a slope, that `looks` the way it looks: a
## stretch the wood leaves open for its view, widening down the slope for
## `view` metres, with the stumps of the wood that was cut in it; a face of
## rock behind the stand, two boulders down the slope in front for whoever
## lies behind them, and a fallen trunk further down.
func _perch(at: Vector2, looks: float, view: float) -> void:
	var ahead := Vector2(sin(deg_to_rad(looks)), cos(deg_to_rad(looks)))
	var aside := Vector2(ahead.y, -ahead.x)
	var own := _dice(at, 31)
	var along := 0.0
	while along < view:
		var wide := lerpf(18.0, 45.0, along / view)
		var middle := at + ahead * (along + 10.0)
		keep_open(Rect2(middle - Vector2.ONE * wide, Vector2.ONE * wide * 2.0))
		for i in 2:
			var spot := middle + aside * own.randf_range(-wide, wide) + ahead * own.randf_range(-10.0, 10.0)
			if spot.distance_to(at) > 8.0:
				strew("tree_stump_02", ground(spot.x, spot.y, -0.05), own.randf() * 360.0)
		along += 25.0
	_boulder("rock_face_01", at - ahead * 9.0 + aside * 3.0, looks + own.randf_range(-30.0, 30.0), own.randf_range(1.0, 1.3))
	_boulder("boulder_01", at + ahead * 11.0 + aside * 6.0, own.randf() * 360.0, own.randf_range(1.6, 2.1))
	_boulder("boulder_01", at + ahead * 13.0 - aside * 7.0, own.randf() * 360.0, own.randf_range(1.6, 2.1))
	_boulder("dead_tree_trunk", at + ahead * 22.0 + aside * own.randf_range(-4.0, 4.0), looks + 90.0 + own.randf_range(-20.0, 20.0), 2.4)


## Where the road along the foot of the slope has a fence of Tyrol on its
## north side, between the meadows on the slope and the road: from x to x,
## leaving the ways up the slope and the chapel open.
const ROAD_FENCES := [[160.0, 410.0], [690.0, 880.0], [960.0, 1180.0], [1240.0, 1470.0]]


## What a farmed valley has about its barns and along its roads: the fence
## of Tyrol on the slope side of the road; in front of some barns a row of
## poles hung with hay; against others a stack of firewood.
func _farmland(dice: RandomNumberGenerator, barns: Array[Vector2]) -> void:
	var fences := 0
	for stretch: Array in ROAD_FENCES:
		var points: Array = []
		var x: float = stretch[0]
		while x <= stretch[1]:
			points.append(Vector2(x, _road_z(x) - 5.5))
			x += 12.0
		if points.size() >= 2:
			slant_fence(points)
			_fence_lines.append(points)
			for point: Vector2 in points:
				keep_bare(point, 1.5)
			fences += 1
	var poles := 0
	var piles := 0
	for i in barns.size():
		var at: Vector2 = barns[i]
		var roll := dice.randf()
		# Not in the way of a fight of the route, nor of the way into it.
		if _route_fights().any(func(fight: Array) -> bool: return (fight[2] as Rect2).grow(20.0).has_point(at)):
			continue
		if roll < 0.35:
			# Six to nine poles in a row on the meadow beside the barn, across
			# the strips, if the ground there is open meadow.
			var along := Vector2.from_angle(dice.randf() * TAU)
			var start := at + along.orthogonal() * dice.randf_range(16.0, 24.0)
			var many := dice.randi_range(6, 9)
			var row: Array[Vector2] = []
			for k in many:
				var spot := start + along * (k - many * 0.5) * 3.4
				if not _grows_on_floor(spot) or road_gap(spot) < 6.0 or slope(spot.x, spot.y, 2.0) > 10.0:
					row.clear()
					break
				row.append(spot)
			for spot in row:
				hay_pole(spot)
				keep_bare(spot, 1.5)
				poles += 1
		elif roll < 0.6:
			var side := Vector2.from_angle(dice.randf() * TAU)
			var spot := at + side * 6.5
			if _grows_on_floor(spot) and road_gap(spot) > 4.0:
				woodpile(spot, rad_to_deg(atan2(side.x, side.y)) + 90.0, dice.randf_range(2.5, 4.0), dice.randf_range(1.2, 1.7))
				keep_bare(spot, 2.5)
				piles += 1
	print("Valley: %d fences along the road, %d hay poles, %d woodpiles" % [fences, poles, piles])


## Boulders the ice left on the floor of the basin and fallen spruces at the
## edges of the woods: cover where there is little.
func _strays(dice: RandomNumberGenerator, placed: Array[Vector2]) -> void:
	var boulders := 0
	var trunks := 0
	var tries := 0
	while (boulders < 30 or trunks < 14) and tries < 3000:
		tries += 1
		var at := Vector2(dice.randf_range(FLOOR.position.x - 300.0, FLOOR.end.x + 200.0), dice.randf_range(FLOOR.position.y - 300.0, FLOOR.end.y + 250.0))
		if not _land.grow(-10.0).has_point(at) or road_gap(at) < 8.0 or not _tree_fits(at) or slope(at.x, at.y, 2.0) > 18.0:
			continue
		if placed.any(func(other: Vector2) -> bool: return other.distance_to(at) < 14.0):
			continue
		var high := ground_height(at.x, at.y) + SEA
		var forest: float = lie_of(at, high, ground_normal(at.x, at.y, 2.0)).forest
		if boulders < 30 and forest < 0.05 and FLOOR.has_point(at):
			_boulder("boulder_01", at, dice.randf() * 360.0, dice.randf_range(1.4, 2.3))
			boulders += 1
			placed.append(at)
		elif trunks < 14 and forest > 0.3 and forest < 0.8:
			_boulder("dead_tree_trunk", at, dice.randf() * 360.0, dice.randf_range(2.0, 2.6))
			trunks += 1
			placed.append(at)
	print("Valley: %d boulders and %d fallen trunks in %d tries" % [boulders, trunks, tries])


## A rock or a trunk of the downloads on the ground at `at`, turned
## `yaw_deg`, `size` times as large as it was scanned, a little sunk into the
## ground, with a box round it in the way: cover. It is not drawn from
## further off than `seen` metres, and no tree grows on it.
func _boulder(model: String, at: Vector2, yaw_deg: float, size: float, seen := 700.0) -> void:
	var foot := ground(at.x, at.y, -0.15 * size)
	var facing := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var node := prop(model, Transform3D(facing, foot), size)
	_root.set_editable_instance(node, true)
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mesh.visibility_range_end = seen
		mesh.visibility_range_end_margin = 20.0
	var box: Vector3 = (_model(model).box as AABB).size * size
	_collide_box(Transform3D(facing, foot + Vector3(0, box.y * 0.5, 0)), box * Vector3(0.85, 1.0, 0.85), _model(model).surface)
	# No tree on it; but the ground under the wood stays the wood's, which
	# keep_open() would make meadow.
	keep_bare(at, maxf(box.x, box.z) * 0.6 + 1.0)


## Whether a barn can stand at `at`: on the meadow, near level, off the
## roads, out of the camps, the fights and the wood, and no nearer another
## barn than BARN_SPACING.
func _barn_fits(at: Vector2, placed: Array[Vector2]) -> bool:
	if slope(at.x, at.y, 4.0) > 7.0 or road_gap(at) < 12.0 or not _tree_fits(at):
		return false
	var high := ground_height(at.x, at.y) + SEA
	if lie_of(at, high, ground_normal(at.x, at.y, 2.0)).forest > 0.05:
		return false
	for other: Vector2 in placed:
		if at.distance_squared_to(other) < BARN_SPACING * BARN_SPACING:
			return false
	for fight: Array in _route_fights():
		if (fight[2] as Rect2).grow(15.0).has_point(at):
			return false
	return true


## The fights of the route, as tools/levels/alps/route.gd has them.
func _route_fights() -> Array:
	return ROUTE.FIGHTS


const ROUTE := preload("res://tools/levels/alps/route.gd")


## A hay barn whose ground the wood keeps off and nothing grows on.
func _barn(at: Vector2, faces: float, size: String) -> void:
	hay_barn(at, faces, size)
	keep_open(Rect2(at - Vector2(7, 7), Vector2(14, 14)))
	keep_bare(at, 8.0)


## The chapel by the road, its door to it; the cross before it and two
## sycamores that shade it.
func _chapel(at: Vector2) -> void:
	chapel(at, 180.0)
	keep_open(Rect2(at - Vector2(8, 9), Vector2(16, 18)))
	keep_bare(at, 9.0)
	wayside_cross(at + Vector2(-20, -8), 180.0)
	plant("maple", at + Vector2(-11, 7), 1.05, 40.0)
	plant("maple", at + Vector2(10, 9), 0.9, 200.0)


## The farm north of the road, its front to the sun: the house and its barn
## under one roof, the wood stacked against the wall, a trough, the hay on
## its poles on the meadow over the road and a fence round the yard.
func _farm(at: Vector2) -> void:
	farmhouse(at, 0.0)
	keep_open(Rect2(at - Vector2(16, 12), Vector2(32, 26)))
	keep_bare(at, 14.0)
	woodpile(at + Vector2(-12, 7.5), 0.0, 4.0)
	trough(at + Vector2(4, 11), 0.0)
	for i in 6:
		hay_pole(at + Vector2(-4 + i * 3.4, 66 + (i % 2) * 0.8))
	rail_fence([at + Vector2(-26, -14), at + Vector2(-26, 14), at + Vector2(-16, 18)])
	rail_fence([at + Vector2(16, 18), at + Vector2(28, 14), at + Vector2(28, -14)])
	plant("maple", at + Vector2(-22, -16), 1.1, 10.0)


## The shrine where the track up the slope leaves the road in the west: a
## shrine on its post and a cross, a stack of wood and a fence of Tyrol
## along the road.
func _shrine() -> void:
	marterl(Vector2(132, 930), 0.0)
	wayside_cross(Vector2(170, 985), 180.0)
	woodpile(Vector2(95, 905), 90.0, 3.5)
	slant_fence([Vector2(180, 955), Vector2(210, 968), Vector2(240, 980)])


## The line of poles that carries the wires along the road, a little off it
## on its north side, from the chapel to the camp in the east.
func _poles() -> void:
	var points: Array = []
	var x := 560.0
	while x <= 1580.0:
		points.append(Vector2(x, _road_z(x) - 9.0))
		x += 42.0
	pole_line(points)
	for point: Vector2 in points:
		keep_bare(point, 2.0)


## The z of the main road at `x`, as ROADS lays it.
func _road_z(x: float) -> float:
	var way: Array = ROADS[0][1]
	for k in way.size() - 1:
		var a: Vector2 = way[k]
		var b: Vector2 = way[k + 1]
		if x >= a.x and x <= b.x:
			return lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
	return (way[-1] as Vector2).y


## What grows on the floor of the basin besides the woods: the hedges along
## the ditches of the Moos, copses on the meadows, and the trees that stand
## alone.
func _meadow_cover() -> void:
	var began := Time.get_ticks_msec()
	var dice := RandomNumberGenerator.new()
	dice.seed = hash("alps cover")
	var counts := {"hedges": 0, "copses": 0, "alone": 0}
	counts.hedges = _hedges(dice)
	counts.copses = _copses(dice)
	counts.alone = _alone(dice)
	print("Cover: %d in hedges, %d in copses, %d alone, in %.1f s" % [counts.hedges, counts.copses, counts.alone, (Time.get_ticks_msec() - began) / 1000.0])


## What grows in a hedge, by weight: mostly dwarf pine, with young spruce,
## a larch and a sycamore here and there.
const HEDGE := [["dwarf_pine_a", 3.0], ["dwarf_pine_b", 3.0], ["spruce_young", 3.0], ["larch_young", 0.4], ["maple", 0.25], ["spruce_mid", 1.0]]
## What grows in a copse.
const COPSE := [["spruce_mid", 3.0], ["spruce_young", 2.0], ["larch_young", 1.5], ["maple", 1.0], ["dwarf_pine_a", 1.0], ["dwarf_pine_b", 1.0]]


## Hedges along the ditches that drain the Moos, where the scans have them,
## with gaps. Returns how many grew.
func _hedges(dice: RandomNumberGenerator) -> int:
	var grown := 0
	var gaps := _noise(7131, 60.0)
	var lines: Array = []
	# The copses and hedges the aerial photograph shows grow with the wood
	# (lie_of()); these are the ditches.
	# Across: the ditch that drains the Moos from east to west, as the scans
	# have it, and one more north of it.
	lines.append([Vector2(205, 1165), Vector2(800, 1095), 0.0, 2.0])
	lines.append([Vector2(800, 1095), Vector2(1180, 1045), 1.0, 2.0])
	lines.append([Vector2(1180, 1045), Vector2(1430, 950), 2.0, 2.0])

	for line: Array in lines:
		var from: Vector2 = line[0]
		var to: Vector2 = line[1]
		var along := (to - from).normalized()
		var side := Vector2(-along.y, along.x)
		var length := from.distance_to(to)
		var d := 0.0
		while d < length:
			d += dice.randf_range(3.0, 6.0)
			var at: Vector2 = from + along * d + side * (sin(d / 85.0 + float(line[2])) * float(line[3]) + dice.randf_range(-1.2, 1.2))
			if gaps.get_noise_2dv(at) < -0.15:
				continue
			if not _grows_on_floor(at):
				continue
			var kind := _kind_by_weight(HEDGE, dice)
			plant(kind, at, dice.randf_range(0.7, 1.05), dice.randf() * 360.0)
			grown += 1
	return grown


## Copses on the meadows: none any more, the aerial photograph has them (see
## lie_of()); kept for a level that wants them. Each a stand of spruce with a
## larch and a sycamore in it, dwarf pine round the edge. Returns how many
## grew.
func _copses(dice: RandomNumberGenerator) -> int:
	var grown := 0
	for i in 0:
		var middle := Vector2(dice.randf_range(FLOOR.position.x, FLOOR.end.x), dice.randf_range(FLOOR.position.y, FLOOR.end.y))
		var reach := dice.randf_range(9.0, 24.0)
		var many := int(reach * reach / 22.0)
		for j in many:
			var at := middle + Vector2.from_angle(dice.randf() * TAU) * reach * sqrt(dice.randf())
			if not _grows_on_floor(at):
				continue
			var kinds: Array = COPSE
			if at.distance_to(middle) > reach * 0.75:
				kinds = HEDGE
			plant(_kind_by_weight(kinds, dice), at, dice.randf_range(0.75, 1.1), dice.randf() * 360.0)
			grown += 1
	return grown


## Sycamores and larches alone on the meadows. Returns how many grew.
func _alone(dice: RandomNumberGenerator) -> int:
	var grown := 0
	for i in 6:
		var at := Vector2(dice.randf_range(FLOOR.position.x, FLOOR.end.x), dice.randf_range(FLOOR.position.y, FLOOR.end.y))
		if not _grows_on_floor(at):
			continue
		plant("maple" if dice.randf() < 0.6 else "larch_old", at, dice.randf_range(0.8, 1.1), dice.randf() * 360.0)
		grown += 1
	return grown


## Whether something can grow at `at` on the floor of the basin: where a tree
## fits and the wood does not already stand.
func _grows_on_floor(at: Vector2) -> bool:
	if not _tree_fits(at):
		return false
	var high := ground_height(at.x, at.y) + SEA
	return lie_of(at, high, ground_normal(at.x, at.y, 2.0)).forest < 0.1
