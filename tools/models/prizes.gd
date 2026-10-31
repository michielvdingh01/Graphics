extends "res://tools/model_builder.gd"
## What two teams fight over, and what each of those stands on at home: a flag
## and the foot of its mast, a football and its spot, a banana as long as a
## rifle and its crate. assets/prizes.json says which goes with which and how
## each is carried; scripts/prize.gd shows them. Build with
## tools/build_model.sh prizes.
##
## Whatever takes the colour of a team is in a part called Team, in a
## material whose shader has the instance uniforms `team` and `teamed`, see
## shaders/team.gdshader. A part called Net is only there while the thing is
## carried.

## The flag: how tall its mast is and how thick, and its cloth from the mast
## to the fly end and from top to bottom.
const MAST := 1.95
const MAST_RADIUS := 0.016
const CLOTH := Vector2(0.9, 0.6)
## The football, and how deep the seams between its panels lie.
const BALL := 0.11
const SEAM := 0.0022
## The banana: the radius of the curve it follows and the angle of that curve
## it takes up, which make it 1.05 m long; how thick it is from the cut end of
## its stalk (0) to its tip (1); and how far its five ridges stand out.
const BEND := 0.75
const ARC := 1.4
const GIRTH: Array[Vector2] = [
	Vector2(0.0, 0.027), Vector2(0.02, 0.022), Vector2(0.06, 0.024), Vector2(0.1, 0.04), Vector2(0.16, 0.062),
	Vector2(0.25, 0.078), Vector2(0.4, 0.086), Vector2(0.55, 0.086), Vector2(0.7, 0.078), Vector2(0.82, 0.062),
	Vector2(0.9, 0.045), Vector2(0.955, 0.028), Vector2(0.985, 0.016), Vector2(1.0, 0.012),
]
const RIDGE := 0.05
## The crate the banana lies on: long, high and deep, and how thick a slat is.
const BOX := Vector3(0.8, 0.3, 0.36)
const SLAT := 0.014


func _describe() -> void:
	_flag()
	_flag_stand()
	_football()
	_football_stand()
	_banana()
	_banana_stand()


## A flag on its mast. The foot of the mast is the origin and the cloth flies
## towards -Z, which is behind whoever carries it on his back.
func _flag() -> void:
	model("flag")
	_bar("galvanised", Vector3(0, 0.03, 0), Vector3(0, MAST, 0), MAST_RADIUS, 12)
	# A shoe on the foot of it, and a spearhead on a ball at the top.
	_turned("dark_steel", Vector3.ZERO, Vector3.UP, [Vector2(0, 0), Vector2(0.012, 0), Vector2(0.019, 0.03), Vector2(0.019, 0.09), Vector2(MAST_RADIUS, 0.095)], 12)
	_bar("brass", Vector3(0, MAST - 0.012, 0), Vector3(0, MAST + 0.008, 0), 0.021, 12)
	_ball("brass", Vector3(0, MAST + 0.03, 0), 0.026)
	_turned("brass", Vector3(0, MAST + 0.05, 0), Vector3.UP, [Vector2(0.01, 0), Vector2(0.017, 0.03), Vector2(0, 0.1)], 10)
	var top := MAST - 0.04
	for height: float in [top - 0.02, top - CLOTH.y * 0.5, top - CLOTH.y + 0.02]:
		_ring("brass", Vector3(0, height, 0), Vector3.UP, MAST_RADIUS + 0.004, 0.004)
	# The cloth is a part of its own that lies in its own x and y, as
	# shaders/prize_flag.gdshader wants it: x from the mast to the fly end, y up.
	part("Team", Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), Vector3(0, top - CLOTH.y, -MAST_RADIUS)))
	var st := _tool("flag_cloth", _part, Vector3.ZERO)
	var across := 24
	var down := 12
	var face := [Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT]
	for i in across:
		for j in down:
			var corners := []
			var uvs := []
			# Bottom left, bottom right, top right, top left, seen from +X.
			for corner: Vector2i in [Vector2i(i, j + 1), Vector2i(i + 1, j + 1), Vector2i(i + 1, j), Vector2i(i, j)]:
				var uv := Vector2(float(corner.x) / across, float(corner.y) / down)
				uvs.append(uv)
				corners.append(Vector3(0, top - uv.y * CLOTH.y, -MAST_RADIUS - uv.x * CLOTH.x))
			_quad(st, corners, face, uvs)
	tag("flies", true)
	part("Body")


## The foot a flag stands in at home: a cast disc with a socket for the mast,
## standing on the origin. The mast goes 0.2 m into it.
func _flag_stand() -> void:
	model("flag_stand")
	_turned("dark_steel", Vector3.ZERO, Vector3.UP, [
		Vector2(0.27, 0), Vector2(0.27, 0.02), Vector2(0.235, 0.05), Vector2(0.11, 0.065), Vector2(0.095, 0.1),
		Vector2(0.05, 0.11), Vector2(0.05, 0.3), Vector2(0.024, 0.3), Vector2(0.024, 0.1), Vector2(0, 0.1),
	], 28)
	for i in 4:
		var out := Vector3(cos(TAU * (i + 0.5) / 4.0), 0, sin(TAU * (i + 0.5) / 4.0)) * 0.17
		_bar("bare_steel", out + Vector3(0, 0.05, 0), out + Vector3(0, 0.07, 0), 0.013, 6)
	part("Team")
	_turned("team_paint", Vector3.ZERO, Vector3.UP, [Vector2(0.272, 0.003), Vector2(0.272, 0.019)], 28)
	_turned("team_paint", Vector3.ZERO, Vector3.UP, [Vector2(0.052, 0.2), Vector2(0.052, 0.28)], 28)
	part("Body")


## A football of thirty-two panels: twenty pale ones with six sides and
## twelve with five, which take the colour of a team and are black without
## one. Its middle is the origin. The net it is carried in hangs from the
## marker Hang.
func _football() -> void:
	model("football")
	# The twelve corners of the solid the panels are cut from, and for each
	# the five next to it.
	var golden := (1.0 + sqrt(5.0)) / 2.0
	var tips: Array[Vector3] = []
	for one: float in [-1.0, 1.0]:
		for other: float in [-golden, golden]:
			tips.append(Vector3(0, one, other).normalized())
			tips.append(Vector3(one, other, 0).normalized())
			tips.append(Vector3(other, 0, one).normalized())
	var apart := 2.1 / sqrt(1.0 + golden * golden)
	var beside: Array = []
	for i in tips.size():
		var near: Array[int] = []
		for j in tips.size():
			if j != i and tips[i].distance_to(tips[j]) < apart:
				near.append(j)
		beside.append(near)
	# A panel of five round every corner, a third of the way to each of its
	# neighbours, and one of six on every face between three of them.
	part("Team")
	for i in tips.size():
		var corners: Array[Vector3] = []
		for j: int in beside[i]:
			corners.append(tips[i].lerp(tips[j], 1.0 / 3.0).normalized())
		_panel("team_leather", corners, i)
	part("Body")
	var number := tips.size()
	for i in tips.size():
		for j: int in beside[i]:
			for k: int in beside[j]:
				if i < j and j < k and (beside[i] as Array).has(k):
					var corners: Array[Vector3] = []
					for pair: Array in [[i, j], [j, i], [j, k], [k, j], [k, i], [i, k]]:
						corners.append(tips[pair[0]].lerp(tips[pair[1]], 1.0 / 3.0).normalized())
					_panel("ball_leather", corners, number)
					number += 1
	# The net: three hoops over the top and three round it, knotted above the
	# ball, and the cord it hangs by.
	part("Net")
	var reach := BALL + 0.004
	for turn in 3:
		var hoop := []
		for i in 9:
			var angle := TAU * i / 8.0
			hoop.append(Basis(Vector3.UP, PI * turn / 3.0) * Vector3(sin(angle), cos(angle), 0) * reach)
		_line("cord", hoop, 0.003, 4)
	for height: float in [-0.5, 0.05, 0.6]:
		var hoop := []
		var wide := sqrt(1.0 - height * height) * reach
		for i in 9:
			var angle := TAU * i / 8.0
			hoop.append(Vector3(cos(angle) * wide, height * reach, sin(angle) * wide))
		_line("cord", hoop, 0.003, 4)
	_ball("cord", Vector3(0, reach + 0.006, 0), 0.012)
	_line("cord", [Vector3(0, reach + 0.01, 0), Vector3(0.012, reach + 0.09, 0), Vector3(0, reach + 0.17, 0)], 0.004, 5)
	marker("Hang", Transform3D(Basis(), Vector3(0, reach + 0.17, 0)), "Net")
	part("Body")


## One panel of the football: `corners` lie on a ball one across. It is a
## little fuller in the middle and sunk along its rim, where the seam is, and
## `number` gives it a patch of the wear of its own.
func _panel(mat: String, corners: Array[Vector3], number: int) -> void:
	var st := _tool(mat, _part, Vector3.ZERO)
	var middle := Vector3.ZERO
	for corner in corners:
		middle += corner
	middle = middle.normalized()
	# Round the middle, counter-clockwise as seen from outside.
	var across := middle.cross(Vector3.UP if absf(middle.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := middle.cross(across)
	corners.sort_custom(func(a: Vector3, b: Vector3) -> bool: return atan2(a.dot(up), a.dot(across)) < atan2(b.dot(up), b.dot(across)))
	var rim: Array[Vector3] = []
	for i in corners.size():
		for step in 3:
			rim.append(corners[i].lerp(corners[(i + 1) % corners.size()], step / 3.0).normalized())
	var patch := Vector2(number * 0.37, number * 0.61)
	var flat := func(point: Vector3) -> Vector2: return Vector2(point.dot(across), point.dot(up)) + patch
	# Rings from the middle out to the rim: where each lies, and which way it faces.
	var rings: Array = [[], [], []]
	var facing: Array = [[], [], []]
	var shares: Array[float] = [0.5, 0.86, 1.0]
	for ring in shares.size():
		for at in rim:
			var spot := middle.lerp(at, shares[ring]).normalized()
			if ring < 2:
				rings[ring].append(spot * (BALL + 0.0006 * (1.0 - shares[ring])))
				facing[ring].append(spot)
			else:
				# Down into the seam, and turned away from the panel.
				var outward := (at - middle * at.dot(middle)).normalized()
				rings[ring].append(spot * (BALL - SEAM))
				facing[ring].append((spot + outward * 0.9).normalized())
	var centre := middle * (BALL + 0.0006)
	for i in rim.size():
		var j := (i + 1) % rim.size()
		_face(st, [centre, rings[0][i], rings[0][j]], [middle, facing[0][i], facing[0][j]], [flat.call(centre), flat.call(rings[0][i]), flat.call(rings[0][j])])
		for ring in [1, 2]:
			var inner: Array = rings[ring - 1]
			var outer: Array = rings[ring]
			var inner_way: Array = facing[ring - 1]
			var outer_way: Array = facing[ring]
			_face(st, [inner[i], outer[i], outer[j]], [inner_way[i], outer_way[i], outer_way[j]], [flat.call(inner[i]), flat.call(outer[i]), flat.call(outer[j])])
			_face(st, [inner[i], outer[j], inner[j]], [inner_way[i], outer_way[j], inner_way[j]], [flat.call(inner[i]), flat.call(outer[j]), flat.call(inner[j])])


## The spot a football lies on at home, standing on the origin: a mat with a
## pale middle and a band in the colour of the team round it, and a ring of
## rubber that keeps the ball where it is. The middle of the ball comes 0.115 m
## above the floor.
func _football_stand() -> void:
	model("football_stand")
	_turned("chalk", Vector3.ZERO, Vector3.UP, [Vector2(0.3, 0.006), Vector2(0, 0.006)], 32)
	_ring("rubber", Vector3(0, 0.015, 0), Vector3.UP, 0.07, 0.012)
	part("Team")
	_turned("team_paint", Vector3.ZERO, Vector3.UP, [Vector2(0.39, 0), Vector2(0.38, 0.006), Vector2(0.3, 0.006)], 32)
	part("Body")


## A banana, lying on its back: the lowest point of the line through its
## middle is the origin, its stalk rises towards -X and its tip towards +X,
## and the ribbon round its waist has its bow on top.
func _banana() -> void:
	model("banana")
	var along_steps := 44
	var round_steps := 20
	var st := _tool("banana_peel", _part, Vector3.ZERO)
	_peel(st, 0.0, 1.0, along_steps, round_steps, 0.0)
	# Both ends are shut.
	for end: float in [0.0, 1.0]:
		var angle := (end - 0.5) * ARC
		var heart := _banana_point(end, 0.0, -1.0)
		var out := Vector3(cos(angle), sin(angle), 0.0) * (1.0 if end > 0.5 else -1.0)
		for j in round_steps:
			var a := _banana_point(end, float(j) / round_steps)
			var b := _banana_point(end, float(j + 1) / round_steps)
			_face(st, [heart, a, b], [out, out, out], [Vector2(end, 0.5), Vector2(lerpf(end, 0.5, 0.004), float(j) / round_steps), Vector2(lerpf(end, 0.5, 0.004), float(j + 1) / round_steps)])
	# The ribbon: a band round the waist, a knot on top, two loops along the
	# banana and two ends that hang down either side.
	part("Team")
	var band := _tool("team_ribbon", _part, Vector3.ZERO)
	var half := 0.05 / (BEND * ARC)
	_peel(band, 0.5 - half, 0.5 + half, 4, round_steps, 0.004)
	var knot := _banana_point(0.5, 0.0, 0.012)
	_block("team_ribbon", knot, Vector3(0.05, 0.026, 0.05), 0.011)
	for side: float in [-1.0, 1.0]:
		var loop: Array[Vector3] = []
		for spot: Vector2 in [Vector2(0.0, 0.0), Vector2(0.05, 0.045), Vector2(0.115, 0.06), Vector2(0.15, 0.03), Vector2(0.12, 0.0), Vector2(0.055, -0.004), Vector2(0.0, 0.0)]:
			loop.append(knot + Vector3(spot.x * side, spot.y, 0.0))
		var wide: Array[Vector3] = []
		for i in loop.size():
			wide.append(Vector3.BACK * lerpf(0.02, 0.03, sin(PI * i / (loop.size() - 1.0))))
		_strip(band, loop, wide)
		var tail: Array[Vector3] = []
		var broad: Array[Vector3] = []
		for i in 7:
			var about := side * lerpf(0.02, 0.3, i / 6.0)
			tail.append(_banana_point(0.5 + side * 0.012, about, 0.008 + 0.006 * sin(PI * i / 6.0)))
			broad.append(Vector3.RIGHT * lerpf(0.02, 0.028, i / 6.0))
		_strip(band, tail, broad)
	part("Body")


## Where the skin of the banana is, `along` it from the stalk (0) to the tip
## (1) and `about` it, once round being 1 and 0 the side that faces the
## inside of the curve. `extra` is how far off the skin; less than nothing
## gives the middle of the banana there.
func _banana_point(along: float, about: float, extra := 0.0) -> Vector3:
	var angle := (along - 0.5) * ARC
	var heart := Vector3(sin(angle), 1.0 - cos(angle), 0.0) * BEND
	if extra < 0.0:
		return heart
	var inward := Vector3(-sin(angle), cos(angle), 0.0)
	var turn := about * TAU
	var thick := _girth(along) * (1.0 + RIDGE * cos(turn * 5.0)) + extra
	return heart + (inward * cos(turn) + Vector3.BACK * sin(turn)) * thick


func _girth(along: float) -> float:
	for i in GIRTH.size() - 1:
		if along <= GIRTH[i + 1].x:
			var share := inverse_lerp(GIRTH[i].x, GIRTH[i + 1].x, along)
			return cubic_interpolate(GIRTH[i].y, GIRTH[i + 1].y, GIRTH[maxi(i - 1, 0)].y, GIRTH[mini(i + 2, GIRTH.size() - 1)].y, share)
	return GIRTH[-1].y


## The skin of the banana from `from` to `to` along it, `extra` off it, as a
## sheet of `along_steps` by `round_steps`.
func _peel(st: SurfaceTool, from: float, to: float, along_steps: int, round_steps: int, extra: float) -> void:
	var points: Array = []
	var ways: Array = []
	var small := 0.002
	for i in along_steps + 1:
		var along := lerpf(from, to, float(i) / along_steps)
		var row: Array[Vector3] = []
		var row_ways: Array[Vector3] = []
		for j in round_steps + 1:
			var about := float(j) / round_steps
			var at := _banana_point(along, about, extra)
			# Which way the skin faces there: across the two ways one can go over it.
			var ahead := _banana_point(minf(along + small, 1.0), about, extra) - _banana_point(maxf(along - small, 0.0), about, extra)
			var aside := _banana_point(along, about + small, extra) - _banana_point(along, about - small, extra)
			var way := aside.cross(ahead).normalized()
			if way.dot(at - _banana_point(along, about, -1.0)) < 0.0:
				way = -way
			row.append(at)
			row_ways.append(way)
		points.append(row)
		ways.append(row_ways)
	for i in along_steps:
		for j in round_steps:
			var u0 := lerpf(from, to, float(i) / along_steps)
			var u1 := lerpf(from, to, float(i + 1) / along_steps)
			var v0 := float(j) / round_steps
			var v1 := float(j + 1) / round_steps
			_face(st, [points[i][j], points[i + 1][j], points[i + 1][j + 1]], [ways[i][j], ways[i + 1][j], ways[i + 1][j + 1]], [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1)])
			_face(st, [points[i][j], points[i + 1][j + 1], points[i][j + 1]], [ways[i][j], ways[i + 1][j + 1], ways[i][j + 1]], [Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1)])


## The crate a banana lies on at home, standing on the origin: slats on four
## posts, shut on top. One slat of each side is in the colour of the team.
## The banana lies along it, 0.396 m above the floor.
func _banana_stand() -> void:
	model("banana_stand")
	var half := BOX * 0.5
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			_plate("wood", Vector3(x * (half.x - 0.035), half.y, z * (half.z - 0.035)), Vector3(0.04, BOX.y, 0.04))
	# Four slats to a side, the third from the floor painted.
	for row in 4:
		var height := 0.035 + row * 0.074
		part("Team" if row == 2 else "Body")
		var mat := "team_paint" if row == 2 else "wood"
		for side: float in [-1.0, 1.0]:
			_plate(mat, Vector3(0, height, side * (half.z - SLAT * 0.5)), Vector3(BOX.x, 0.058, SLAT))
			_plate(mat, Vector3(side * (half.x - SLAT * 0.5), height, 0), Vector3(SLAT, 0.058, BOX.z - SLAT * 2.0))
	part("Body")
	for i in 5:
		_plate("wood", Vector3(0, BOX.y + SLAT * 0.5, lerpf(-half.z + 0.034, half.z - 0.034, i / 4.0)), Vector3(BOX.x + 0.02, SLAT, 0.064))


## A ribbon through `spine`, reaching `across` to either side of each point
## of it, with two faces.
func _strip(st: SurfaceTool, spine: Array[Vector3], across: Array[Vector3]) -> void:
	var run := 0.0
	for i in spine.size() - 1:
		var length := spine[i].distance_to(spine[i + 1])
		var way := across[i].cross(spine[i + 1] - spine[i]).normalized()
		var corners := [spine[i] - across[i], spine[i] + across[i], spine[i + 1] + across[i + 1], spine[i + 1] - across[i + 1]]
		var uvs := [Vector2(0, run), Vector2(across[i].length() * 2.0, run), Vector2(across[i + 1].length() * 2.0, run + length), Vector2(0, run + length)]
		for flip: float in [1.0, -1.0]:
			var faces := [way * flip, way * flip, way * flip, way * flip]
			_face(st, [corners[0], corners[1], corners[2]], faces, [uvs[0], uvs[1], uvs[2]])
			_face(st, [corners[0], corners[2], corners[3]], faces, [uvs[0], uvs[2], uvs[3]])
		run += length
