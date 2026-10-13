extends "res://tools/levels/dunes/plan.gd"
## What lies beyond the dunes, where nobody comes: the ground the land goes on
## as, out to where the haze takes it, and what is seen on it from a high
## dune or through a glade in the wood.
##
##             north: the wood goes on, and inland the dunes are high
##                 +------------------------------------------+
##   the sea       |                                          |
##   ~  ~  beach   |               the land                   |   wood, and
##   ~  ~  and the |                                          |   high dunes
##   ~  ~  first   +------------------------------------------+
##   ~     dune       south: the dune that shuts the land in falls
##                    away into the wood, and behind it dunes in rows
##
## The coast lies to the west, some way off: low open dunes, a first dune
## along the beach, and the sea. North of where the player comes out of the
## wood there is no wood beyond the land on that side, so that whoever stands
## high enough sees a strip of water over the first dune.
##
## The ground is three rings of squares round the land, each four times as
## coarse as the one inside it, and meets the land at the height of its edge.
## What it looks like is not in its corners but in two maps the material lays
## over it. Nothing of it throws a shadow or is in anybody's way.

## How far beyond the land its edge has become the ground that lies there.
const EDGE_REACH := 70.0
## The rings: how large their squares are, and how far beyond the land each
## reaches to the west and north (x and z) and to the east and south.
const RINGS := [
	[10.0, Vector2(100, 100), Vector2(120, 110)],
	[40.0, Vector2(580, 580), Vector2(680, 630)],
	[160.0, Vector2(1220, 1220), Vector2(1320, 1270)],
]
## Where the water begins, x at the middle of the land: the coast runs a
## little off north to south.
const WATER_X := -540.0
## How far in from the water the beach ends and the first dune stands, how
## wide that is, and where the open dunes behind it have become the country
## inland.
const BEACH := 80.0
const FOREDUNE := 140.0
const FOREDUNE_WIDE := 62.0
const COAST_ENDS := Vector2(200.0, 340.0)
## South of this the wood the player comes out of stands beyond the land in
## the west, and north of it the coast is open.
const WOOD_FROM_Z := Vector2(138.0, 160.0)
## The colours of what lies there: bare sand, sand that is wet, the grey
## dune with its moss and low grass, the floor of a wood, and its crowns.
const SAND := Color(0.37, 0.295, 0.2)
const WET := Color(0.2, 0.17, 0.13)
const GREY_DUNE := Color(0.2, 0.2, 0.125)
const WOOD_FLOOR := Color(0.085, 0.075, 0.058)
const CROWNS := Color(0.013, 0.021, 0.013)
## Where the woods far off stand as a line of trees: how far beyond the land.
const WOOD_LINES: Array[float] = [58.0, 82.0, 112.0, 150.0, 200.0, 265.0, 350.0, 460.0, 600.0, 780.0, 1000.0]

var _rolling: FastNoiseLite
var _humps: FastNoiseLite
var _rows: FastNoiseLite
var _crest: FastNoiseLite
var _woods: FastNoiseLite
var _patches: FastNoiseLite
var _own := RandomNumberGenerator.new()


func _describe() -> void:
	in_zone("")
	_own.seed = hash("dunes/vista")
	_rolling = _noise(4211, 150.0)
	_humps = _noise(4217, 46.0)
	_rows = _noise(4229, 520.0)
	_crest = _noise(4231, 95.0)
	_woods = _noise(4241, 300.0)
	_patches = _noise(4253, 70.0)
	_stands_beyond = _height_beyond
	_map_ground()
	_lay()
	_sea()
	_far_woods()
	_scrub()
	by_position()


## How much of the wood beyond the land there is at (x, z): none where the
## coast is open, see tree_wall().
func wood_kept(x: float, z: float) -> float:
	if x > 0.0:
		return 1.0
	return smoothstep(WOOD_FROM_Z.x, WOOD_FROM_Z.y, z)


## How far beyond the land (x, z) lies: nought on it.
func _out(x: float, z: float) -> float:
	var nearest := Vector2(clampf(x, LAND.position.x, LAND.end.x), clampf(z, LAND.position.y, LAND.end.y))
	return nearest.distance_to(Vector2(x, z))


## Where the water begins at `z`, as an x.
func _water_x(z: float) -> float:
	return WATER_X - 0.22 * (z - 115.0) + 26.0 * sin(z / 210.0)


## How far in from the water (x, z) lies: less than nought in the sea.
func _from_water(x: float, z: float) -> float:
	return x - _water_x(z)


## How much of the open coast there is at (x, z), nought to one: all of it
## from the water to behind the first dune, none of it inland.
func _coastal(x: float, z: float) -> float:
	return 1.0 - smoothstep(COAST_ENDS.x, COAST_ENDS.y, _from_water(x, z))


## The lie of the country far from the land.
func _height_far(x: float, z: float) -> float:
	var at := Vector2(x, z)
	var out := _out(x, z)
	var inland := 4.6 + _rolling.get_noise_2dv(at) * 3.6 + _humps.get_noise_2dv(at) * 1.3
	# The high dunes, in rows that run east and west as those of the land do.
	var row := 1.0 - absf(_rows.get_noise_2d(x * 0.42, z))
	inland += pow(row, 2.6) * 27.0 * smoothstep(130.0, 430.0, out) * (0.7 + 0.3 * _rolling.get_noise_2dv(at * 0.5))
	var w := _from_water(x, z)
	if w > COAST_ENDS.y:
		return inland
	# The coast: the beach, the first dune with its notches, and the low
	# dunes behind it.
	var beach := -2.4 + 4.6 * smoothstep(-30.0, BEACH, w)
	var notch := smoothstep(-0.5, 0.1, _crest.get_noise_2d(z, 7.0))
	var first := lerpf(2.6, 7.2, notch) * _bell(absf(w - FOREDUNE) / FOREDUNE_WIDE)
	var low := (2.2 + _humps.get_noise_2dv(at) * 1.4 + _rolling.get_noise_2dv(at) * 1.2) * smoothstep(FOREDUNE, COAST_ENDS.x + 40.0, w)
	return lerpf(beach + first + low, inland, smoothstep(COAST_ENDS.x, COAST_ENDS.y, w))


## How high the ground lies beyond the land at (x, z): the height of the
## edge of the land where it leaves it, and the country as it is further off.
func _height_beyond(x: float, z: float) -> float:
	var out := _out(x, z)
	var far := _height_far(x, z)
	if out >= EDGE_REACH:
		return far
	return lerpf(ground_height(x, z), far, smoothstep(0.0, EDGE_REACH, out))


## How much wood stands at (x, z) beyond the land, nought to one: none on the
## coast, a belt round the land, and further off in patches.
func _wood_at(x: float, z: float) -> float:
	var open := _coastal(x, z)
	var out := _out(x, z)
	var belt := (1.0 - smoothstep(60.0, 130.0, out)) * (wood_kept(x, z) if x < 0.0 else 1.0)
	var patch := smoothstep(-0.2, 0.05, _woods.get_noise_2d(x, z)) * wood_kept(x, z)
	return clampf(maxf(belt, patch) * (1.0 - open), 0.0, 1.0)


## What the ground looks like at (x, z), facing `faces`: the colour it has
## from far off, which is all anybody sees of it.
func _look(x: float, z: float, faces: Vector3) -> Color:
	var at := Vector2(x, z)
	var w := _from_water(x, z)
	var out := _out(x, z)
	# Bare sand on what is steep and on the beach, the grey dune elsewhere.
	var bare := maxf(smoothstep(0.93, 0.8, faces.y), 1.0 - smoothstep(BEACH, FOREDUNE + 30.0, w))
	bare = maxf(bare, smoothstep(0.1, 0.5, _patches.get_noise_2dv(at)) * 0.8)
	var look := GREY_DUNE.lerp(SAND, bare)
	# Under a wood near by its floor is seen between the trunks; of a wood
	# far off, its crowns.
	var wood := _wood_at(x, z)
	look = look.lerp(WOOD_FLOOR.lerp(CROWNS, smoothstep(90.0, 200.0, out)), wood)
	look = look.lerp(WET, 1.0 - smoothstep(4.0, 34.0, w))
	return look * (0.92 + 0.16 * _humps.get_noise_2d(z * 1.7, x * 1.7))


## A map of what the ground looks like over `area`, a dot for every `dot`
## metres: the material lays it over the ground by where a spot lies, so
## that a square of a hundred and sixty metres is not one colour.
func _look_map(area: Rect2, dot: float) -> ImageTexture:
	var wide := roundi(area.size.x / dot)
	var high := roundi(area.size.y / dot)
	# How high the ground lies at the middle of every dot, and one beyond.
	var heights := PackedFloat32Array()
	heights.resize((wide + 2) * (high + 2))
	for row in high + 2:
		for column in wide + 2:
			heights[row * (wide + 2) + column] = beyond_height(area.position.x + (column - 0.5) * dot, area.position.y + (row - 0.5) * dot)
	var map := Image.create(wide, high, true, Image.FORMAT_RGB8)
	for row in high:
		for column in wide:
			var i := (row + 1) * (wide + 2) + column + 1
			var faces := Vector3(heights[i - 1] - heights[i + 1], 2.0 * dot, heights[i - wide - 2] - heights[i + wide + 2]).normalized()
			map.set_pixel(column, row, _look(area.position.x + (column + 0.5) * dot, area.position.y + (row + 0.5) * dot, faces).linear_to_srgb())
	map.generate_mipmaps()
	return ImageTexture.create_from_image(map)


## The material of the ground beyond with its maps on it: one of what lies
## near the land and a coarser one of all of it.
func _map_ground() -> void:
	var near := _ring_area(1)
	var far := _ring_area(RINGS.size() - 1)
	_beyond_look = (load("res://materials/beyond_ground.tres") as ShaderMaterial).duplicate()
	_beyond_look.set_shader_parameter("look_near", _look_map(near, 4.0))
	_beyond_look.set_shader_parameter("near_rect", Vector4(near.position.x, near.position.y, 1.0 / near.size.x, 1.0 / near.size.y))
	_beyond_look.set_shader_parameter("look_far", _look_map(far, 16.0))
	_beyond_look.set_shader_parameter("far_rect", Vector4(far.position.x, far.position.y, 1.0 / far.size.x, 1.0 / far.size.y))


## How far ring `ring` of the ground reaches, x and z.
func _ring_area(ring: int) -> Rect2:
	return Rect2(LAND.position - (RINGS[ring][1] as Vector2), LAND.size + (RINGS[ring][1] as Vector2) + (RINGS[ring][2] as Vector2))


## The height of a corner of a ring of squares `cell` wide that reaches from
## `inner` to `outer`. On the land's edge it lies just under the land; on the
## outside of its ring it lies on the line between the corners of the coarser
## ring it meets there, so that no sky shows between the two.
func _ring_corner(x: float, z: float, cell: float, outer: Rect2, coarser: float) -> float:
	if LAND.grow(0.01).has_point(Vector2(x, z)):
		# As low as the land lies within half a square to either side.
		var low := INF
		for step in 11:
			var shift := (step / 10.0 - 0.5) * cell
			low = minf(low, minf(ground_height(x + shift, z), ground_height(x, z + shift)))
		return low - 0.25
	if coarser > 0.0:
		var on_x := is_equal_approx(x, outer.position.x) or is_equal_approx(x, outer.end.x)
		var on_z := is_equal_approx(z, outer.position.y) or is_equal_approx(z, outer.end.y)
		if on_x and not on_z:
			var from := outer.position.y + floorf((z - outer.position.y) / coarser + 0.0001) * coarser
			return lerpf(_height_beyond(x, from), _height_beyond(x, from + coarser), (z - from) / coarser)
		if on_z and not on_x:
			var from := outer.position.x + floorf((x - outer.position.x) / coarser + 0.0001) * coarser
			return lerpf(_height_beyond(from, z), _height_beyond(from + coarser, z), (x - from) / coarser)
	return _height_beyond(x, z)


## Lays the ground beyond the land, ring by ring.
func _lay() -> void:
	var inner := LAND
	for ring in RINGS.size():
		var cell: float = RINGS[ring][0]
		var outer := _ring_area(ring)
		var coarser: float = RINGS[ring + 1][0] if ring + 1 < RINGS.size() else 0.0
		var columns := roundi(outer.size.x / cell)
		var rows := roundi(outer.size.y / cell)
		var points := PackedVector3Array()
		var facing := PackedVector3Array()
		var uvs := PackedVector2Array()
		var corners := PackedInt32Array()
		var index := {}
		for row in rows:
			for column in columns:
				var square := Rect2(outer.position + Vector2(column, row) * cell, Vector2(cell, cell))
				if inner.grow(0.01).encloses(square):
					continue
				var own: Array[int] = []
				for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
					var key := Vector2i(column, row) + corner
					if not index.has(key):
						var x := outer.position.x + key.x * cell
						var z := outer.position.y + key.y * cell
						var high := _ring_corner(x, z, cell, outer, coarser)
						var span := cell * 0.5
						var faces := Vector3(_height_beyond(x - span, z) - _height_beyond(x + span, z), 2.0 * span, _height_beyond(x, z - span) - _height_beyond(x, z + span)).normalized()
						index[key] = points.size()
						points.append(Vector3(x, high, z))
						facing.append(faces)
						uvs.append(Vector2(x, z))
					own.append(index[key])
				corners.append_array([own[0], own[2], own[3], own[0], own[1], own[2]])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_NORMAL] = facing
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = corners
		var st := SurfaceTool.new()
		st.create_from_arrays(arrays)
		_tools["|vista %d/beyond_ground" % ring] = st
		@warning_ignore("integer_division")
		print("The ground beyond, ring %d: %d squares of %d m" % [ring, corners.size() / 6, roundi(cell)])
		inner = outer


## The sea: flat water from the beach out to where nobody sees further.
func _sea() -> void:
	var st := _tool_named("|vista %d/sea" % RINGS.size())
	var up := Vector3.UP
	var step := 120.0
	var z := -1400.0
	while z < 1700.0:
		var near_a := Vector3(_water_x(z) + 70.0, 0.0, z)
		var near_b := Vector3(_water_x(z + step) + 70.0, 0.0, z + step)
		_quad(st, [Vector3(-3900.0, 0.0, z + step), near_b, near_a, Vector3(-3900.0, 0.0, z)], [up, up, up, up], [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		z += step


## The woods far off: each a line of trees along the ground, one behind the
## other and each a little further from the land, wherever wood stands.
func _far_woods() -> void:
	var st := _tool_named("|vista %d/tree_line" % (RINGS.size() + 1))
	var middle := LAND.get_center()
	var lines := 0
	for reach: float in WOOD_LINES:
		# Round the land, at about that distance from it.
		var around := 2.0 * (LAND.size.x + LAND.size.y) + TAU * reach
		var steps := maxi(roundi(around / lerpf(18.0, 60.0, smoothstep(60.0, 800.0, reach))), 8)
		var high := 15.0 + reach * 0.004
		var run := _own.randf()
		var before := Vector3.INF
		for step in steps + 1:
			var spot := _way_round(float(step % steps) / steps, reach * (1.0 + 0.16 * _patches.get_noise_2d(step * 9.0, reach)))
			var here := Vector3(spot.x, _height_beyond(spot.x, spot.y) - 1.6, spot.y)
			if before != Vector3.INF:
				var half := (before + here) * 0.5
				var across := before.distance_to(here)
				var repeat := across / (high * 4.0)
				if _wood_at(half.x, half.z) >= 0.5:
					var tall_a := high * (0.8 + 0.3 * _humps.get_noise_2d(before.x * 0.6, before.z * 0.6))
					var tall_b := high * (0.8 + 0.3 * _humps.get_noise_2d(here.x * 0.6, here.z * 0.6))
					var faces := (Vector3(middle.x, half.y, middle.y) - half).normalized()
					# Seen from the land, the spot before lies to the left.
					_quad(st, [before, here, here + Vector3.UP * tall_b, before + Vector3.UP * tall_a], [faces, faces, faces, faces], [Vector2(run, 1), Vector2(run + repeat, 1), Vector2(run + repeat, 0), Vector2(run, 0)])
					lines += 1
				run += repeat
			before = here
	print("The woods far off: %d stretches of tree line" % lines)


## A spot on the way round the land, `reach` beyond it: `share` of the way
## round, 0 to 1, clockwise from its north-west corner as the map has it.
func _way_round(share: float, reach: float) -> Vector2:
	var sides := 2.0 * (LAND.size.x + LAND.size.y)
	var turn := TAU * reach
	var at := share * (sides + turn)
	var corner_arc := turn * 0.25
	# North side, north-east corner, east side, and so on round.
	var legs := [
		[LAND.position, Vector2.RIGHT, LAND.size.x, Vector2.UP],
		[Vector2(LAND.end.x, LAND.position.y), Vector2.DOWN, LAND.size.y, Vector2.RIGHT],
		[LAND.end, Vector2.LEFT, LAND.size.x, Vector2.DOWN],
		[Vector2(LAND.position.x, LAND.end.y), Vector2.UP, LAND.size.y, Vector2.LEFT],
	]
	for leg: Array in legs:
		var from: Vector2 = leg[0]
		var along: Vector2 = leg[1]
		var out: Vector2 = leg[3]
		if at <= leg[2]:
			return from + along * at + out * reach
		at -= leg[2]
		if at <= corner_arc:
			return from + along * leg[2] + out.rotated(at / maxf(reach, 0.01)) * reach
		at -= corner_arc
	return LAND.position + Vector2.UP * reach


## Thorn scrub on the open dunes of the coast, as far as anybody can tell a
## bush from the ground it stands on: where the grey dune is, in drifts.
func _scrub() -> void:
	var bushes := {}
	var count := 0
	for i in 2600:
		var at := Vector2(_own.randf_range(-260.0, 0.0), _own.randf_range(-60.0, 250.0))
		var size := _own.randf_range(0.9, 1.7)
		var turn := _own.randf() * TAU
		var kind := "scrub_a" if _own.randf() < 0.6 else "scrub_b"
		if LAND.grow(1.5).has_point(at) or _wood_at(at.x, at.y) > 0.3 or wood_kept(at.x, at.y) > 0.5:
			continue
		if _patches.get_noise_2d(at.x * 1.6 + 400.0, at.y * 1.6) < 0.18 + 0.3 * smoothstep(40.0, 240.0, _out(at.x, at.y)):
			continue
		var xf := Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * size), Vector3(at.x, _height_beyond(at.x, at.y) - 0.15, at.y))
		_merge_tree(bushes, kind, "Far", xf, 1.0, 1.0)
		count += 1
	for mat: String in bushes:
		var st := SurfaceTool.new()
		st.create_from_arrays(_merged_arrays(bushes[mat]))
		_tools["|vista %d/%s" % [RINGS.size() + 2, mat]] = st
	print("Scrub on the coast: %d bushes" % count)
