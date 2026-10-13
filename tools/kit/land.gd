extends "res://tools/kit/furniture.gd"
## Ninth drawer of the kit, see tools/kit.gd: land under an open sky. The
## other drawers stand things on a floor at height nought; this one makes the
## ground itself, as a field of heights a metre apart, and says what covers it.
##
## A level says how much land it has with land(), shapes it from coarse to
## fine with swell(), ridge(), mound(), hollow(), bank(), dig(), level_off()
## and track(), and has it laid with lay_ground(). From then on ground() says
## how high the ground lies anywhere, and whatever is stood on it asks:
##
##     land(Rect2(0, 0, 340, 230), 4.0)
##     swell(1.5, 60.0)
##     ridge([Vector2(0, 150), Vector2(250, 158)], 7.0, 16.0, 9.0)
##     track([Vector2(20, 196), Vector2(130, 185)], 3.6)
##     roughen(0.2)
##     lay_ground()
##     place("ammo_box", ground(64.0, 190.0), 20)
##
## The ground is one collider, a height field in a body of its own, and a mesh
## in blocks that is lit as it stands: there is no lightmap under an open sky,
## where the light is the sun and the sky. What covers it is painted on a map
## of the land, two dots to the metre, and the ground material mixes its sand,
## needles, moss and earth by that map: cover(). The map also holds where the
## sun does not come. That is worked out when everything stands, see
## _shade_land(), and it is what somebody stands in who is not to be seen:
## the game reads it off the level, see scripts/land.gd.
##
## The collider is laid at once and the mesh when everything stands, see
## _dress_ground(): what the sand looks like at a spot depends on what has
## come to stand around it, and the mesh carries that to the material.

## How far apart the heights of the land lie, in metres. One, which is what
## the collider of a height field takes without being scaled.
const LAND_CELL := 1.0
## How many metres of ground go into one mesh, along x and along z.
const GROUND_BLOCK := 32
## Dots to the metre of the map that says what covers the ground.
const COVER_SCALE := 2.0
## What cover() can lay, and the channel of the map each is kept in. The
## fourth holds the shade.
const COVERS := {"needles": 0, "moss": 1, "earth": 2}
## How high over the ground the sun is looked for, for the shade: the chest of
## somebody who stands there.
const SHADE_HEIGHT := 1.2
## How far towards the sun is looked.
const SHADE_REACH := 80.0
## A sheet of paper: no lightmap and in nobody's way.
const SLIGHT_SHEET := DETAIL | NO_COLLIDE
## A track that is further off than this is none to the ground material, in
## metres.
const TRACK_FAR := 10.0
## What is strewn on the land goes into a mesh a block of ground, one for
## each of these, and this is how far off each is still drawn, in metres:
## clumps of grass, what grows under the pines, and what lies on the ground.
const STREWN_REACH := {"strewn": 85.0, "undergrowth": 50.0, "litter": 40.0}
## A clump of grass this large and larger has caught a mound of sand, this
## high for a clump of size one.
const MOUND_FROM := 0.5
const MOUND_HIGH := 0.13

## The land of the level (x and z), or nothing for a level without any.
var _land := Rect2()
## Its heights, LAND_CELL apart, row after row from north to south.
var _heights := PackedFloat32Array()
## How much of each spot was raised by a ridge or a mound: two that cross do
## not stack, the higher one counts.
var _raised := PackedFloat32Array()
## How firm each spot is, 0 to 1: levelled or driven on, which roughen()
## leaves as it is and nothing grows on by itself.
var _firm := PackedFloat32Array()
## The map of what covers the ground: see COVERS.
var _cover: Image
## The tracks that were cut, for whatever follows them: {path, width}.
var _tracks: Array[Dictionary] = []
## The earth that was laid by anything but a track, a dot of the map each:
## the ground material draws a track itself, rut by rut, and wants to know
## what earth lies there besides. And whether it is a track that is laying.
var _earth_beside: Image
var _cutting_track := false
## The material the ground was laid in, once it has been: its mesh is made
## when everything stands.
var _ground_mat := ""
## What the ground material is told of every spot of the land, see
## _read_land(): its look, and where it lies by the nearest track.
var _looks := PackedColorArray()
var _by_track := PackedVector2Array()
## How much of the ground around each spot of the land lies under needles:
## how deep in a wood it is.
var _wooded := PackedFloat32Array()
## Where marram was asked for, see marram(): {area, spacing, gaps}. And the
## clumps that came of it, once the ground is dressed: {at, size}.
var _marram: Array[Dictionary] = []
var _clumps: Array[Dictionary] = []
## The dice for whatever is strewn on the land. Their own: what stands, and
## was thrown with the dice of the level, stays where it stood.
var _strew_rng := RandomNumberGenerator.new()
## What stands in the way of the sun without being a collider, the crowns of
## trees: [centre, radii] of a ball each.
var _crowns: Array = []
## Where the sun stands: the way to it, from the ground.
var _sunward := Vector3(0.0, 1.0, 0.0)
## The walls nobody sees that keep everybody on the land, see shut_in(). The
## sun shines through them.
var _unseen: Array[AABB] = []
## The copy of the ground material that carries the map of this level.
var _own_ground: ShaderMaterial
## Where the sun does not come, a bit a dot of the map: see _shade_land().
var _shade_bits: BitMap
## What a tree of each kind is like, read off its model: {scene, crowns,
## girth, height}.
var _grown := {}
## The node the trees of the level stand under.
var _trees: Node3D
## Where no tree is to stand: what a level keeps open (x and z).
var _open: Array[Rect2] = []
## The pieces of scanned models that are strewn about, by model and part:
## what _scan_piece() made of each.
var _strewn := {}
## Whether the level asked for what lies and grows under its pines, see
## forest_floor(), and for the fine grass that grows low, see dune_grass().
var _floor_asked := false
var _grass_asked := false
## What somebody has drawn on the map of the land in red: spots (x and z)
## with a ring round each. And the material that shows that map, once a
## level has asked for one: see map_sheet().
var _map_marks: Array[Vector2] = []
var _own_map: StandardMaterial3D


# --- The lie of the land ---------------------------------------------------------


## Sets out the land of the level: `area` on the ground (x and z, whole
## metres), lying `height` high to begin with. That height keeps it clear of
## nought, which hollows and ditches may come close to but not under.
func land(area: Rect2, height: float) -> void:
	_land = area
	var count := _across() * _down()
	_heights.resize(count)
	_heights.fill(height)
	_raised.resize(count)
	_raised.fill(0.0)
	_firm.resize(count)
	_firm.fill(0.0)
	_cover = Image.create(int(area.size.x * COVER_SCALE), int(area.size.y * COVER_SCALE), false, Image.FORMAT_RGBA8)
	_cover.fill(Color(0, 0, 0, 0))
	_earth_beside = Image.create(_cover.get_width(), _cover.get_height(), false, Image.FORMAT_L8)
	_earth_beside.fill(Color(0, 0, 0))


## Says what the open air of the level sounds like: the bed "ambience_<kind>"
## instead of that of a yard between sheds. See scripts/sfx.gd.
func open_air(kind: String) -> void:
	_root.set_meta(&"open_air", StringName(kind))


## Where the sun stands, as the scene of the level has it: `turn_deg` round
## from north by east, and `rise_deg` over the horizon.
func sun_at(turn_deg: float, rise_deg: float) -> void:
	var turn := deg_to_rad(turn_deg)
	var rise := deg_to_rad(rise_deg)
	_sunward = Vector3(sin(turn) * cos(rise), sin(rise), -cos(turn) * cos(rise))


## Keeps everybody on the land: a wall nobody sees along each of its sides,
## `inset` inside its edge and higher than anybody gets. It stops whoever
## walks and whatever flies, and shows nothing of it: a shot that ends on it
## leaves no mark (the surface "air", see scripts/fx.gd), and the sun shines
## through it, see _stops_sun().
func shut_in(inset := 2.6) -> void:
	var middle := _land.get_center()
	var high := 60.0
	for wall: Array in [
		[Vector3(middle.x, 20.0, _land.position.y + inset), Vector3(_land.size.x, high, 1.0)],
		[Vector3(middle.x, 20.0, _land.end.y - inset), Vector3(_land.size.x, high, 1.0)],
		[Vector3(_land.position.x + inset, 20.0, middle.y), Vector3(1.0, high, _land.size.y)],
		[Vector3(_land.end.x - inset, 20.0, middle.y), Vector3(1.0, high, _land.size.y)],
	]:
		_collide_box(Transform3D(Basis(), wall[0]), wall[1], "air")
		_unseen.append(AABB(wall[0] - wall[1] * 0.5, wall[1]))


func _across() -> int:
	return int(_land.size.x / LAND_CELL) + 1


func _down() -> int:
	return int(_land.size.y / LAND_CELL) + 1


## The spots of the land that lie in `area`, as [first column, first row,
## last column, last row].
func _spots_in(area: Rect2) -> Array[int]:
	var from := ((area.position - _land.position) / LAND_CELL).floor()
	var to := ((area.end - _land.position) / LAND_CELL).ceil()
	return [clampi(int(from.x), 0, _across() - 1), clampi(int(from.y), 0, _down() - 1), clampi(int(to.x), 0, _across() - 1), clampi(int(to.y), 0, _down() - 1)]


## Where spot (`column`, `row`) lies on the ground.
func _spot(column: int, row: int) -> Vector2:
	return _land.position + Vector2(column, row) * LAND_CELL


## The box around a path, grown by `reach`.
func _around(path: PackedVector2Array, reach: float) -> Rect2:
	var box := Rect2(path[0], Vector2.ZERO)
	for point in path:
		box = box.expand(point)
	return box.grow(reach)


## The spot on `path` nearest to `at`: how far off it lies (x), how far along
## the path (y) and on which side of the way it runs (z): 1 for the right, -1
## for the left.
func _nearest_on(path: PackedVector2Array, at: Vector2) -> Vector3:
	var best := Vector3(INF, 0.0, 1.0)
	var run := 0.0
	for i in path.size() - 1:
		var along := path[i + 1] - path[i]
		var length := along.length()
		var share := clampf((at - path[i]).dot(along) / maxf(along.length_squared(), 0.0001), 0.0, 1.0)
		var gap := at.distance_to(path[i] + along * share)
		if gap < best.x:
			best = Vector3(gap, run + length * share, 1.0 if along.cross(at - path[i]) >= 0.0 else -1.0)
		run += length
	return best


func _length_of(path: PackedVector2Array) -> float:
	var run := 0.0
	for i in path.size() - 1:
		run += path[i].distance_to(path[i + 1])
	return run


## A path through `points` that bends smoothly from one to the next, in steps
## of about `step` metres.
func curve(points: Array, step := 1.0) -> PackedVector2Array:
	var path := PackedVector2Array()
	for i in points.size() - 1:
		var from: Vector2 = points[i]
		var to: Vector2 = points[i + 1]
		var before: Vector2 = points[maxi(i - 1, 0)]
		var after: Vector2 = points[mini(i + 2, points.size() - 1)]
		var pieces := maxi(1, ceili(from.distance_to(to) / step))
		for piece in pieces:
			path.append(from.cubic_interpolate(to, before, after, float(piece) / pieces))
	path.append(points[points.size() - 1])
	return path


## One that falls away smoothly from 1 in the middle to 0 at `share` 1.
func _bell(share: float) -> float:
	return 0.5 + 0.5 * cos(PI * clampf(share, 0.0, 1.0))


func _noise(seed: int, wavelength: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	noise.frequency = 1.0 / wavelength
	return noise


## Lets the whole land rise and fall by up to `height` either way, in waves
## about `wavelength` long: what lies under the dunes.
func swell(height: float, wavelength: float, seed := 1) -> void:
	var wide := _noise(seed, wavelength)
	var narrow := _noise(seed + 100, wavelength * 0.37)
	for row in _down():
		for column in _across():
			var at := _spot(column, row)
			_heights[row * _across() + column] += (wide.get_noise_2dv(at) * 0.75 + narrow.get_noise_2dv(at) * 0.25) * height


## Raises spot `i` by `rise`, counted from the ground as it lay before
## anything was raised there: of two ridges that cross, the higher counts.
func _raise(i: int, rise: float) -> void:
	if rise > _raised[i]:
		_heights[i] += rise - _raised[i]
		_raised[i] = rise


## A dune along `path`, `height` high: it falls away over `left` metres on the
## left of the way the path runs and over `right` metres on the right, so a
## dune can have a long back and a short, steep face. Its crest rises and
## falls a little, and it runs out at both ends. A face that falls a good deal
## more than its width cannot be walked up: steeper than 45 degrees is where
## 1.57 * height / width passes 1.
func ridge(path: Array, height: float, left: float, right: float, seed := 3) -> void:
	var way := curve(path, 2.0)
	var total := _length_of(way)
	var wave := _noise(seed, 23.0)
	var ends := maxf(left, right)
	var box := _spots_in(_around(way, ends))
	for row in range(box[1], box[3] + 1):
		for column in range(box[0], box[2] + 1):
			var near := _nearest_on(way, _spot(column, row))
			var width := right if near.z > 0.0 else left
			if near.x >= width:
				continue
			var crest := height * (0.86 + 0.14 * wave.get_noise_1d(near.y)) * smoothstep(0.0, ends, minf(near.y, total - near.y) + ends * 0.15)
			_raise(row * _across() + column, crest * _bell(near.x / width))


## A round dune at `at`, `height` high and `radius` across at its foot.
func mound(at: Vector2, radius: float, height: float) -> void:
	var box := _spots_in(Rect2(at, Vector2.ZERO).grow(radius))
	for row in range(box[1], box[3] + 1):
		for column in range(box[0], box[2] + 1):
			var gap := _spot(column, row).distance_to(at)
			if gap < radius:
				_raise(row * _across() + column, height * _bell(gap / radius))


## A hollow blown out of the sand at `at`: `depth` deep in the middle, and
## `radii` across from west to east and from north to south.
func hollow(at: Vector2, radii: Vector2, depth: float) -> void:
	var box := _spots_in(Rect2(at - radii, radii * 2.0))
	for row in range(box[1], box[3] + 1):
		for column in range(box[0], box[2] + 1):
			var share := ((_spot(column, row) - at) / radii).length()
			if share < 1.0:
				_heights[row * _across() + column] -= depth * _bell(share)


## A bank thrown up along `path`, `height` high and `width` wide at its foot,
## on top of whatever lies there: the berm of a gun pit, the lip of a ditch.
## The heights lie a metre apart, so one narrower than three metres is no
## more than a ripple.
func bank(path: Array, height: float, width: float) -> void:
	_along_path(curve(path, 1.0), width * 0.5, func(i: int, share: float) -> void:
		_heights[i] += height * _bell(share)
		_firm[i] = maxf(_firm[i], 1.0 - share))


## A ditch dug along `path`, `depth` deep and `width` wide at the top.
func dig(path: Array, depth: float, width: float) -> void:
	_along_path(curve(path, 1.0), width * 0.5, func(i: int, share: float) -> void:
		_heights[i] -= depth * _bell(share)
		_firm[i] = maxf(_firm[i], 1.0 - share))


## Calls `shape` for every spot within `reach` of the path, with the spot and
## how far off it lies as a share of `reach`.
func _along_path(way: PackedVector2Array, reach: float, shape: Callable) -> void:
	var box := _spots_in(_around(way, reach))
	for row in range(box[1], box[3] + 1):
		for column in range(box[0], box[2] + 1):
			var near := _nearest_on(way, _spot(column, row))
			if near.x < reach:
				shape.call(row * _across() + column, near.x / reach)


## Levels the ground of `area` (x and z) off at `height`, or at what it comes
## to there on average for a height that is not given, and eases it into the
## land around over `margin` metres: for a camp, a yard, anything that stands
## on a floor.
func level_off(area: Rect2, height := NAN, margin := 5.0) -> float:
	var box := _spots_in(area.grow(margin))
	if is_nan(height):
		var inside := _spots_in(area)
		var sum := 0.0
		for row in range(inside[1], inside[3] + 1):
			for column in range(inside[0], inside[2] + 1):
				sum += _heights[row * _across() + column]
		height = sum / ((inside[3] - inside[1] + 1) * (inside[2] - inside[0] + 1))
	for row in range(box[1], box[3] + 1):
		for column in range(box[0], box[2] + 1):
			var at := _spot(column, row)
			var out := at.distance_to(at.clamp(area.position, area.end))
			var hold := 1.0 - smoothstep(0.0, margin, out)
			var i := row * _across() + column
			_heights[i] = lerpf(_heights[i], height, hold)
			_firm[i] = maxf(_firm[i], hold)
	return height


## A track `width` wide through `points`. It follows the land as it lies, but
## evens out what a lorry would not take: it cuts through a rise and fills a
## dip, over `ease` metres along its way, and its sides fall away into the
## land over `margin` metres. What follows a track later, the earth on it and
## the wood that keeps clear of it, finds it in `_tracks`.
func track(points: Array, width: float, margin := 4.0, ease := 9.0) -> void:
	var way := curve(points, 1.0)
	var level := PackedFloat32Array()
	for point in way:
		level.append(ground_height(point.x, point.y))
	# The height along the way, evened out a few times over.
	var reach := maxi(1, int(ease))
	for pass_ in 3:
		var evened := PackedFloat32Array()
		for i in level.size():
			var sum := 0.0
			var count := 0
			for j in range(maxi(i - reach, 0), mini(i + reach, level.size() - 1) + 1):
				sum += level[j]
				count += 1
			evened.append(sum / count)
		level = evened
	var half := width * 0.5
	var box := _spots_in(_around(way, half + margin))
	for row in range(box[1], box[3] + 1):
		for column in range(box[0], box[2] + 1):
			var at := _spot(column, row)
			var nearest := 0
			var gap := INF
			for i in way.size():
				var off := at.distance_squared_to(way[i])
				if off < gap:
					gap = off
					nearest = i
			var hold := 1.0 - smoothstep(half, half + margin, sqrt(gap))
			if hold <= 0.0:
				continue
			var i := row * _across() + column
			_heights[i] = lerpf(_heights[i], level[nearest], hold)
			_firm[i] = maxf(_firm[i], hold)
	_tracks.append({"path": way, "width": width})
	_cutting_track = true
	cover_along("earth", way, half + 0.6, 0.8)
	_cutting_track = false


## Takes the edges off the land, `times` over: the creases where one dune
## runs into another.
func soften(times := 1) -> void:
	var across := _across()
	for time in times:
		var before := _heights.duplicate()
		for row in range(1, _down() - 1):
			for column in range(1, across - 1):
				var i := row * across + column
				_heights[i] = (before[i] * 4.0 + before[i - 1] + before[i + 1] + before[i - across] + before[i + across]) * 0.125


## Hummocks and ripples up to `height` high wherever the ground is not firm.
func roughen(height: float, seed := 7) -> void:
	var humps := _noise(seed, 11.0)
	var ripples := _noise(seed + 50, 4.3)
	for row in _down():
		for column in _across():
			var at := _spot(column, row)
			var i := row * _across() + column
			_heights[i] += (humps.get_noise_2dv(at) * 0.7 + ripples.get_noise_2dv(at) * 0.3) * height * (1.0 - _firm[i])


## How high the ground lies at (x, z). Each square of heights is two
## triangles, cut from its north-west to its south-east corner, as the mesh
## and the collider have it.
func ground_height(x: float, z: float) -> float:
	# A level without land has a floor at nought, and things of this drawer
	# and the next stand on that.
	if _heights.is_empty():
		return 0.0
	var at := (Vector2(x, z) - _land.position) / LAND_CELL
	var column := clampi(int(floorf(at.x)), 0, _across() - 2)
	var row := clampi(int(floorf(at.y)), 0, _down() - 2)
	var u := clampf(at.x - column, 0.0, 1.0)
	var v := clampf(at.y - row, 0.0, 1.0)
	var i := row * _across() + column
	var nw := _heights[i]
	var se := _heights[i + _across() + 1]
	if u >= v:
		var ne := _heights[i + 1]
		return nw + (ne - nw) * u + (se - ne) * v
	var sw := _heights[i + _across()]
	return nw + (sw - nw) * v + (se - sw) * u


## The spot on the ground at (x, z), `lift` over it.
func ground(x: float, z: float, lift := 0.0) -> Vector3:
	return Vector3(x, ground_height(x, z) + lift, z)


## The same for a spot that is known but for its height.
func on_ground(at: Vector3, lift := 0.0) -> Vector3:
	return ground(at.x, at.z, lift)


## Which way the ground faces at (x, z), taken over `span` metres.
func ground_normal(x: float, z: float, span := 1.0) -> Vector3:
	return Vector3(
		ground_height(x - span, z) - ground_height(x + span, z), 2.0 * span, ground_height(x, z - span) - ground_height(x, z + span)
	).normalized()


## How steep the ground is at (x, z), in degrees.
func slope(x: float, z: float, span := 1.0) -> float:
	return rad_to_deg(acos(clampf(ground_normal(x, z, span).y, -1.0, 1.0)))


## Standing on the ground at (x, z) and turned `yaw_deg`, tilted with the
## ground under it as it is over `span` metres: a lorry, a crate that was put
## down where the ground was not level.
func resting(x: float, z: float, yaw_deg: float, span := 1.5, lift := 0.0) -> Transform3D:
	var up := ground_normal(x, z, span)
	var ahead := Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3.BACK
	var side := up.cross(ahead).normalized()
	return Transform3D(Basis(-side, up, -side.cross(up)).orthonormalized(), ground(x, z, lift))


# --- What covers it ----------------------------------------------------------------


## Lays `kind` of cover (see COVERS) on the ground around `at`, out to
## `radius`: `amount` of it in the middle, thinning out over the outer
## `soft` share. It never takes away what lies there already.
func cover(kind: String, at: Vector2, radius: float, amount := 1.0, soft := 0.5) -> void:
	if _cover == null:
		return
	var channel: int = COVERS[kind]
	var middle := (at - _land.position) * COVER_SCALE
	var reach := radius * COVER_SCALE
	for y in range(maxi(int(middle.y - reach), 0), mini(int(middle.y + reach) + 1, _cover.get_height())):
		for x in range(maxi(int(middle.x - reach), 0), mini(int(middle.x + reach) + 1, _cover.get_width())):
			var share := Vector2(x + 0.5, y + 0.5).distance_to(middle) / reach
			if share >= 1.0:
				continue
			_lay_dot(x, y, channel, amount * (1.0 - smoothstep(1.0 - soft, 1.0, share)))


## The same along a path, `reach` to either side of it.
func cover_along(kind: String, way: PackedVector2Array, reach: float, amount := 1.0, soft := 0.4) -> void:
	if _cover == null:
		return
	var channel: int = COVERS[kind]
	var box := _around(way, reach)
	var from := ((box.position - _land.position) * COVER_SCALE).floor()
	var to := ((box.end - _land.position) * COVER_SCALE).ceil()
	for y in range(maxi(int(from.y), 0), mini(int(to.y), _cover.get_height())):
		for x in range(maxi(int(from.x), 0), mini(int(to.x), _cover.get_width())):
			var share := _nearest_on(way, _land.position + Vector2(x + 0.5, y + 0.5) / COVER_SCALE).x / reach
			if share >= 1.0:
				continue
			_lay_dot(x, y, channel, amount * (1.0 - smoothstep(1.0 - soft, 1.0, share)))


## The same over the whole of `area` (x and z), evenly.
func cover_over(kind: String, area: Rect2, amount := 1.0) -> void:
	if _cover == null:
		return
	var channel: int = COVERS[kind]
	var from := ((area.position - _land.position) * COVER_SCALE).floor()
	var to := ((area.end - _land.position) * COVER_SCALE).ceil()
	for y in range(maxi(int(from.y), 0), mini(int(to.y), _cover.get_height())):
		for x in range(maxi(int(from.x), 0), mini(int(to.x), _cover.get_width())):
			_lay_dot(x, y, channel, amount)


## Lays `amount` of a cover on one dot of the map, unless more lies there.
func _lay_dot(x: int, y: int, channel: int, amount: float) -> void:
	var dot := _cover.get_pixel(x, y)
	dot[channel] = maxf(dot[channel], amount)
	_cover.set_pixel(x, y, dot)
	if channel == COVERS.earth and not _cutting_track:
		_earth_beside.set_pixel(x, y, Color(maxf(_earth_beside.get_pixel(x, y).r, amount), 0, 0))


## How much of `kind` covers the ground at `at`.
func cover_at(kind: String, at: Vector2) -> float:
	if _cover == null:
		return 0.0
	var dot := ((at - _land.position) * COVER_SCALE).floor()
	if dot.x < 0.0 or dot.y < 0.0 or dot.x >= _cover.get_width() or dot.y >= _cover.get_height():
		return 0.0
	return _cover.get_pixel(int(dot.x), int(dot.y))[COVERS[kind]]


## How firm the ground is at `at`: 1 where it was levelled or is driven on.
func firm_at(at: Vector2) -> float:
	if _firm.is_empty():
		return 1.0
	var spot := ((at - _land.position) / LAND_CELL).round()
	return _firm[clampi(int(spot.y), 0, _down() - 1) * _across() + clampi(int(spot.x), 0, _across() - 1)]


## How near the nearest track passes `at`, counted from its edge.
func track_gap(at: Vector2) -> float:
	var gap := INF
	for cut: Dictionary in _tracks:
		gap = minf(gap, _nearest_on(cut.path, at).x - cut.width * 0.5)
	return gap


# --- Laying it ---------------------------------------------------------------------


## Lays the ground as it has been shaped: its collider now, and its mesh, in
## blocks, when everything stands. Nothing shapes it after this.
func lay_ground(mat := "dune_ground") -> void:
	var field := HeightMapShape3D.new()
	field.map_width = _across()
	field.map_depth = _down()
	field.map_data = _heights
	var body := StaticBody3D.new()
	body.name = "Ground"
	_add(body, _root)
	var collider := CollisionShape3D.new()
	collider.shape = field
	collider.position = Vector3(_land.get_center().x, 0.0, _land.get_center().y)
	collider.set_meta(&"surface", "sand")
	_add(collider, body)
	_ground_mat = mat


## The ground is dressed when the level has been looked over: every tree
## stands by then, every cover lies and the shade is known.
func _survey() -> bool:
	var done: bool = await super()
	_dress_ground()
	return done


## Makes the mesh of the ground, in blocks, with what _read_land() says of
## every spot on its corners.
func _dress_ground() -> void:
	if _ground_mat == "":
		return
	_read_land()
	_strew_rng.seed = hash(_level_name() + " strewn")
	_stand_marram()
	if _floor_asked:
		_strew_wood()
	if _grass_asked:
		_strew_grass()
	_stain_standings()
	var across := _across()
	var down := _down()
	# The clumps of each block: the sand each has caught is part of the
	# ground.
	var caught := {}
	for clump: Dictionary in _clumps:
		if clump.size >= MOUND_FROM:
			var block := Vector2i(((clump.at as Vector2) - _land.position) / (GROUND_BLOCK * LAND_CELL))
			if not caught.has(block):
				caught[block] = []
			caught[block].append(clump)
	# Which way every spot faces, from its neighbours on the whole land: the
	# blocks then meet without a seam.
	var normals := PackedVector3Array()
	normals.resize(across * down)
	for row in down:
		for column in across:
			normals[row * across + column] = _facing(column, row)
	for first_row in range(0, down - 1, GROUND_BLOCK):
		for first_column in range(0, across - 1, GROUND_BLOCK):
			var columns := mini(GROUND_BLOCK, across - 1 - first_column)
			var rows := mini(GROUND_BLOCK, down - 1 - first_row)
			var points := PackedVector3Array()
			var facing := PackedVector3Array()
			var uvs := PackedVector2Array()
			var tracks := PackedVector2Array()
			var looks := PackedColorArray()
			var corners := PackedInt32Array()
			for row in rows + 1:
				for column in columns + 1:
					var i := (first_row + row) * across + first_column + column
					var at := _spot(first_column + column, first_row + row)
					points.append(Vector3(at.x, _heights[i], at.y))
					facing.append(normals[i])
					uvs.append(at)
					tracks.append(_by_track[i])
					looks.append(_looks[i])
			for row in rows:
				for column in columns:
					var nw := row * (columns + 1) + column
					var ne := nw + 1
					var sw := nw + columns + 1
					var se := sw + 1
					corners.append_array([nw, se, sw, nw, ne, se])
			@warning_ignore("integer_division")
			for clump: Dictionary in caught.get(Vector2i(first_column / GROUND_BLOCK, first_row / GROUND_BLOCK), []):
				_mound(clump.at, clump.size, points, facing, uvs, tracks, looks, corners)
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = points
			arrays[Mesh.ARRAY_NORMAL] = facing
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			arrays[Mesh.ARRAY_TEX_UV2] = tracks
			arrays[Mesh.ARRAY_COLOR] = looks
			arrays[Mesh.ARRAY_INDEX] = corners
			@warning_ignore("integer_division")
			var key := "|ground %d %d/%s" % [first_column / GROUND_BLOCK, first_row / GROUND_BLOCK, _ground_mat]
			var st := SurfaceTool.new()
			st.create_from_arrays(arrays)
			_tools[key] = st


## Which way the spot (`column`, `row`) of the land faces, from its
## neighbours.
func _facing(column: int, row: int) -> Vector3:
	var across := _across()
	var west := _heights[row * across + maxi(column - 1, 0)]
	var east := _heights[row * across + mini(column + 1, across - 1)]
	var north := _heights[maxi(row - 1, 0) * across + column]
	var south := _heights[mini(row + 1, _down() - 1) * across + column]
	return Vector3(west - east, 2.0 * LAND_CELL, north - south).normalized()


## Reads off the land what its material cannot see for itself, for every
## spot of it, see shaders/dune_ground.gdshader. Its look, as the red,
## green, blue and alpha of a colour: how high it lies among what is around
## it (a half for level with it, more for a crest, less for a hollow, and
## less again for what lies low on the whole land, where the sand is damp);
## how loose its sand is; how much of a crust of moss and lichen it has,
## the grey dune; how much grass stands on it. And where it lies by the
## nearest track: metres to the right of its middle, and metres along it.
func _read_land() -> void:
	var across := _across()
	var down := _down()
	var count := across * down
	var around := _evened(_heights, 9)
	var firm := _evened(_firm, 1)
	var litter := PackedFloat32Array()
	litter.resize(count)
	var mean := 0.0
	for row in down:
		for column in across:
			var i := row * across + column
			litter[i] = cover_at("needles", _spot(column, row))
			mean += _heights[i] / count
	_wooded = _evened(litter, 7)
	var patches := _noise(4711, 38.0)
	_looks.resize(count)
	for row in down:
		for column in across:
			var i := row * across + column
			var low := clampf((mean - 1.0 - _heights[i]) / 2.5, 0.0, 1.0)
			var high := clampf(0.5 + (_heights[i] - around[i]) / 3.0 - low * 0.22, 0.0, 1.0)
			var loose := 1.0 - firm[i]
			# The crust takes where the sand lies still: by a wood, on a
			# back that looks north, and not on a crest, on a face that
			# slides or on the floor of a hollow the wind has blown out.
			var faces := _facing(column, row)
			var slides := smoothstep(0.1, 0.2, 1.0 - faces.y)
			var crest := clampf((high - 0.5) * 2.5, 0.0, 1.0)
			var crust := clampf(0.38 + patches.get_noise_2dv(_spot(column, row)) * 0.7 + _wooded[i] * 1.2 - faces.z * 0.6 - crest * 1.5 - slides * 1.5 - low * 0.6, 0.0, 1.0) * loose
			_looks[i] = Color(high, loose, crust, 0.0)

	_by_track.resize(count)
	_by_track.fill(Vector2(TRACK_FAR, -TRACK_FAR * 10.0))
	var run := 0.0
	for cut: Dictionary in _tracks:
		# A track is measured a little beyond both its ends, as if it ran
		# straight on: there the way along it counts down from nought, and
		# the material lets the ruts run out.
		var way: PackedVector2Array = cut.path
		var before := way[0] + (way[0] - way[1]).normalized() * TRACK_FAR
		var after := way[way.size() - 1] + (way[way.size() - 1] - way[way.size() - 2]).normalized() * TRACK_FAR
		for i in range(-1, way.size()):
			var from := before if i < 0 else way[i]
			var to := after if i == way.size() - 1 else way[i + 1]
			var along := to - from
			var length := along.length()
			var box := _spots_in(Rect2(from, Vector2.ZERO).expand(to).grow(TRACK_FAR))
			for row in range(box[1], box[3] + 1):
				for column in range(box[0], box[2] + 1):
					var at := _spot(column, row)
					var share := clampf((at - from).dot(along) / maxf(length * length, 0.0001), 0.0, 1.0)
					var gap := at.distance_to(from + along * share)
					var spot := row * across + column
					if gap < absf(_by_track[spot].x):
						var gone := run + length * share
						if i < 0:
							gone = -length * (1.0 - share)
						elif i == way.size() - 1:
							gone = -length * share
						_by_track[spot] = Vector2(gap if along.cross(at - from) >= 0.0 else -gap, gone)
			if i >= 0 and i < way.size() - 1:
				run += length
	# A spot with no track near has none on the side its neighbours have
	# theirs: between a spot on the left of a track and one that was simply
	# far from it, the mesh would otherwise pass through the middle of a
	# track that is not there.
	var reached := PackedInt32Array()
	var sided := PackedByteArray()
	sided.resize(count)
	for spot in count:
		if absf(_by_track[spot].x) < TRACK_FAR:
			reached.append(spot)
			sided[spot] = 1
	var next := 0
	while next < reached.size():
		var spot := reached[next]
		next += 1
		var side := -TRACK_FAR if _by_track[spot].x < 0.0 else TRACK_FAR
		for beside: int in [spot - 1, spot + 1, spot - across, spot + across]:
			if beside >= 0 and beside < count and absi(beside % across - spot % across) <= 1 and sided[beside] == 0:
				_by_track[beside] = Vector2(side, -TRACK_FAR * 10.0)
				sided[beside] = 1
				reached.append(beside)


## `values`, one for every spot of the land, each evened out with what lies
## within `reach` spots of it to either side.
func _evened(values: PackedFloat32Array, reach: int) -> PackedFloat32Array:
	var across := _across()
	var down := _down()
	# The sum of everything north-west of each spot: what lies in a square
	# is then four of these.
	var sums := PackedFloat64Array()
	sums.resize((across + 1) * (down + 1))
	for row in down:
		var line := 0.0
		for column in across:
			line += values[row * across + column]
			sums[(row + 1) * (across + 1) + column + 1] = sums[row * (across + 1) + column + 1] + line
	var evened := PackedFloat32Array()
	evened.resize(across * down)
	for row in down:
		var top := maxi(row - reach, 0)
		var bottom := mini(row + reach, down - 1) + 1
		for column in across:
			var left := maxi(column - reach, 0)
			var right := mini(column + reach, across - 1) + 1
			var sum := sums[bottom * (across + 1) + right] - sums[top * (across + 1) + right] - sums[bottom * (across + 1) + left] + sums[top * (across + 1) + left]
			evened[row * across + column] = sum / ((bottom - top) * (right - left))
	return evened


## What `values`, one for every spot of the land, come to at `at`, between
## the spots.
func _between(values: PackedFloat32Array, at: Vector2) -> float:
	var spot := (at - _land.position) / LAND_CELL
	var column := clampi(int(floorf(spot.x)), 0, _across() - 2)
	var row := clampi(int(floorf(spot.y)), 0, _down() - 2)
	var u := clampf(spot.x - column, 0.0, 1.0)
	var v := clampf(spot.y - row, 0.0, 1.0)
	var i := row * _across() + column
	return lerpf(lerpf(values[i], values[i + 1], u), lerpf(values[i + _across()], values[i + _across() + 1], u), v)


## What _read_land() says of the ground at `at`, between the spots it was
## read at.
func look_at_ground(at: Vector2) -> Color:
	var spot := (at - _land.position) / LAND_CELL
	var column := clampi(int(floorf(spot.x)), 0, _across() - 2)
	var row := clampi(int(floorf(spot.y)), 0, _down() - 2)
	var u := clampf(spot.x - column, 0.0, 1.0)
	var v := clampf(spot.y - row, 0.0, 1.0)
	var i := row * _across() + column
	return _looks[i].lerp(_looks[i + 1], u).lerp(_looks[i + _across()].lerp(_looks[i + _across() + 1], u), v)


## The ground material with the map of this level on it, and every other
## material as it is.
func _material(mat: String) -> Material:
	if mat == "land_map":
		if _own_map == null:
			_own_map = StandardMaterial3D.new()
			_own_map.albedo_texture = ImageTexture.create_from_image(_draw_map())
			_own_map.roughness = 0.85
			var file := "%s%s_map.res" % [OUT_DIR, _level_name()]
			ResourceSaver.save(_own_map, file, ResourceSaver.FLAG_COMPRESS)
			_own_map.take_over_path(file)
		return _own_map
	if mat != "dune_ground" or _cover == null:
		return super(mat)
	if _own_ground == null:
		_own_ground = (load("res://materials/dune_ground.tres") as ShaderMaterial).duplicate()
		# The map as the material gets it has no earth where a track laid
		# it: the material draws the track itself. And where pines stand
		# close their litter lies everywhere, not under each by itself.
		var map := _cover.duplicate() as Image
		for y in map.get_height():
			for x in map.get_width():
				var dot := map.get_pixel(x, y)
				dot.b = _earth_beside.get_pixel(x, y).r
				dot.r = maxf(dot.r, smoothstep(0.3, 0.55, _between(_wooded, _land.position + Vector2(x + 0.5, y + 0.5) / COVER_SCALE)))
				map.set_pixel(x, y, dot)
		map.generate_mipmaps()
		_own_ground.set_shader_parameter("cover", ImageTexture.create_from_image(map))
		_own_ground.set_shader_parameter("cover_rect", Vector4(_land.position.x, _land.position.y, 1.0 / _land.size.x, 1.0 / _land.size.y))
		var path := "%s%s_ground.res" % [OUT_DIR, _level_name()]
		ResourceSaver.save(_own_ground, path, ResourceSaver.FLAG_COMPRESS)
		_own_ground.take_over_path(path)
	return _own_ground


## The ground casts no shadow of its own: no dune is steep enough to stand in
## the way of a sun this high, and the sun would draw every block of it for
## each of its shadow maps.
func _commit(zone_name: String, kind: String) -> void:
	super(zone_name, kind)
	if kind.begins_with("ground "):
		(_root.get_child(0) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	elif kind.get_slice(" ", 0) in STREWN_REACH:
		# What grows low and what lies about: there are thousands, and none
		# matters from afar.
		var low := _root.get_child(0) as MeshInstance3D
		low.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		low.visibility_range_end = STREWN_REACH[kind.get_slice(" ", 0)]
		low.visibility_range_end_margin = 6.0
	elif kind.begins_with("beyond "):
		# The wood beyond the land, see tree_wall(): it throws a shadow only
		# where that falls away from the land, and its front row is one mesh
		# from close by and another from afar.
		var wood := _root.get_child(0) as MeshInstance3D
		if not _beyond_shadows.get(kind.get_slice(" ", 1).to_int(), false):
			wood.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if kind.ends_with(" near"):
			wood.visibility_range_end = BEYOND_FAR
			wood.visibility_range_end_margin = 8.0
		elif kind.ends_with(" far"):
			wood.visibility_range_begin = BEYOND_FAR
			wood.visibility_range_begin_margin = 8.0


# --- The shade ---------------------------------------------------------------------


## Something that keeps the sun off the ground without being in anybody's
## way: the crown of a tree, a net over a lorry. A ball around `centre`,
## `radii` across each way.
func casts_shade(centre: Vector3, radii: Vector3) -> void:
	_crowns.append([centre, radii])


## Works out where on the land the sun does not come and writes that into the
## map of the cover: for the ground to show it far off, where the sun draws
## no shadow any more, and for the game to know who stands out of the light.
## A spot is in the shade when, from chest height, the way to the sun meets a
## collider or passes through a crown. Called when everything stands.
func _shade_land(space: PhysicsDirectSpaceState3D, ray: PhysicsRayQueryParameters3D) -> void:
	if _cover == null:
		return
	var wide := _cover.get_width()
	var high := _cover.get_height()
	var shade := PackedFloat32Array()
	shade.resize(wide * high)
	shade.fill(0.0)
	# The crowns first: each darkens the dots that lie under it as the sun
	# sees it, most where the way to the sun passes through its middle.
	for crown: Array in _crowns:
		var centre: Vector3 = crown[0]
		var radii: Vector3 = crown[1]
		# Where its shadow falls on ground that lies about as high as its foot.
		var fall := centre.y - ground_height(centre.x, centre.z) - SHADE_HEIGHT
		var onto := Vector2(centre.x, centre.z) - Vector2(_sunward.x, _sunward.z) * (fall / _sunward.y)
		var reach := maxf(radii.x, maxf(radii.y, radii.z)) / _sunward.y + 2.0
		var from := ((onto - Vector2.ONE * reach - _land.position) * COVER_SCALE).floor()
		var to := ((onto + Vector2.ONE * reach - _land.position) * COVER_SCALE).ceil()
		for y in range(maxi(int(from.y), 0), mini(int(to.y), high)):
			for x in range(maxi(int(from.x), 0), mini(int(to.x), wide)):
				var at := _land.position + Vector2(x + 0.5, y + 0.5) / COVER_SCALE
				var eye := ground(at.x, at.y, SHADE_HEIGHT)
				# How near the way to the sun passes the middle of the crown,
				# in a space where the crown is a ball of radius one.
				var off := (centre - eye) / radii
				var way := (_sunward / radii).normalized()
				var along := off.dot(way)
				if along <= 0.0:
					continue
				var miss := (off - way * along).length()
				if miss < 1.0:
					var i := y * wide + x
					shade[i] = maxf(shade[i], 1.0 - smoothstep(0.55, 1.0, miss))
	# Then whatever stands there: walls, lorries, tents, the land itself.
	for y in high:
		for x in wide:
			var i := y * wide + x
			if shade[i] >= 0.999:
				continue
			var at := _land.position + Vector2(x + 0.5, y + 0.5) / COVER_SCALE
			ray.from = ground(at.x, at.y, SHADE_HEIGHT)
			ray.to = ray.from + _sunward * SHADE_REACH
			if _stops_sun(space, ray):
				shade[i] = 1.0
	var shaded := 0
	var bits := BitMap.new()
	bits.create(Vector2i(wide, high))
	for y in high:
		for x in wide:
			var i := y * wide + x
			var dot := _cover.get_pixel(x, y)
			dot.a = shade[i]
			_cover.set_pixel(x, y, dot)
			# For the game a spot is shaded or it is not: half and over.
			if shade[i] >= 0.5:
				bits.set_bit(x, y, true)
				shaded += 1
	_shade_bits = bits
	print("Shade: %d%% of the land lies out of the sun" % roundi(100.0 * shaded / (wide * high)))


## True if something stands between the two ends of `ray` that the sun does
## not shine through: any collider but the walls of shut_in(). Those are met
## on a side, which the land never is, and a ray that starts inside one does
## not meet it again.
func _stops_sun(space: PhysicsDirectSpaceState3D, ray: PhysicsRayQueryParameters3D) -> bool:
	for wall in _unseen.size() + 1:
		var hit := space.intersect_ray(ray)
		if hit.is_empty():
			return false
		var at: Vector3 = hit.position
		if absf(hit.normal.y) > 0.01 or not _unseen.any(func(box: AABB) -> bool: return box.grow(0.05).has_point(at)):
			return true
		ray.from = at + (ray.to - at).normalized() * 0.05
	return false


## Leaves what the game has to know of the land on the level, see
## scripts/land.gd: where the shade lies. It is a file of the level, written
## once last time's have been cleared out.
func _finish_zones() -> void:
	super()
	if _shade_bits:
		var path := "%s%s_shade.res" % [OUT_DIR, _level_name()]
		ResourceSaver.save(_shade_bits, path, ResourceSaver.FLAG_COMPRESS)
		_shade_bits.take_over_path(path)
		var node := Node.new()
		node.name = "Land"
		node.set_script(load("res://scripts/land.gd"))
		node.set_meta(&"shade", _shade_bits)
		node.set_meta(&"land", _land)
		node.set_meta(&"sunward", _sunward)
		_add(node, _root)
	if _land.has_area():
		# The heights are a file of the level, not a line of its scene.
		var field := ((_root.get_node("Ground") as StaticBody3D).get_child(0) as CollisionShape3D).shape
		var heights := "%s%s_land.res" % [OUT_DIR, _level_name()]
		ResourceSaver.save(field, heights, ResourceSaver.FLAG_COMPRESS)
		field.take_over_path(heights)


## The shade is worked out when the builder has the level standing in a world.
func _garrison(space: PhysicsDirectSpaceState3D, ray: PhysicsRayQueryParameters3D, navmesh: NavigationMesh, walked: Dictionary) -> void:
	super(space, ray, navmesh, walked)
	_shade_land(space, ray)


## Sand is sand to a bullet, and bark is wood.
func _surface(mat: String) -> String:
	match mat:
		"dune_ground":
			return "sand"
		"bark":
			return "wood"
	return super(mat)


# --- The map of it -------------------------------------------------------------------


## A sheet with the map of this land on it: north at the top, heights as
## contour lines, the woods green, the tracks, and a red ring round every
## spot of mark_on_map(). It lies in the XY of `xf`, `width` wide, and is
## read from its +Z. The map is drawn when the level is written, so it shows
## the land as it then lies.
func map_sheet(xf: Transform3D, width: float) -> void:
	var st := _tool("land_map", SLIGHT_SHEET, xf.origin)
	var half := Vector2(width, width * _land.size.y / _land.size.x) * 0.5
	var normal := xf.basis.z
	_quad(st, [xf * Vector3(-half.x, -half.y, 0), xf * Vector3(half.x, -half.y, 0), xf * Vector3(half.x, half.y, 0), xf * Vector3(-half.x, half.y, 0)],
		[normal, normal, normal, normal], [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])


## Has somebody ring `at` (x and z) on the map in red.
func mark_on_map(at: Vector2) -> void:
	_map_marks.append(at)


func _draw_map() -> Image:
	var wide := 1024
	var high := int(wide * _land.size.y / _land.size.x)
	var scale := _land.size.x / wide
	var map := Image.create_empty(wide, high, true, Image.FORMAT_RGB8)
	var paper := Color(0.8, 0.76, 0.62)
	var levels := PackedFloat32Array()
	levels.resize(wide * high)
	for y in high:
		for x in wide:
			levels[y * wide + x] = ground_height(_land.position.x + (x + 0.5) * scale, _land.position.y + (y + 0.5) * scale)
	for y in high:
		for x in wide:
			var at := _land.position + Vector2(x + 0.5, y + 0.5) * scale
			var level := levels[y * wide + x]
			var east := levels[y * wide + mini(x + 1, wide - 1)]
			var south := levels[mini(y + 1, high - 1) * wide + x]
			# Lit from the north-west, as a map is.
			var ink := paper * clampf(1.0 + (east - level) * 0.35 + (south - level) * 0.35, 0.82, 1.1)
			if cover_at("needles", at) > 0.5:
				ink = ink.lerp(Color(0.5, 0.63, 0.42), 0.55)
			if floorf(level / 2.0) != floorf(east / 2.0) or floorf(level / 2.0) != floorf(south / 2.0):
				ink = ink.lerp(Color(0.45, 0.28, 0.16), 0.75 if floorf(level / 10.0) != floorf(east / 10.0) or floorf(level / 10.0) != floorf(south / 10.0) else 0.45)
			if fposmod(at.x, 50.0) < scale or fposmod(at.y, 50.0) < scale:
				ink = ink.lerp(Color(0.3, 0.4, 0.6), 0.5)
			map.set_pixel(x, y, ink)
	for cut: Dictionary in _tracks:
		var way: PackedVector2Array = cut.path
		for i in way.size():
			# A track is a broken line.
			if i % 8 < 5:
				_map_dot(map, (way[i] - _land.position) / scale, 1.6, Color(0.14, 0.11, 0.08))
	for mark in _map_marks:
		var middle := (mark - _land.position) / scale
		for step in 96:
			_map_dot(map, middle + Vector2.RIGHT.rotated(TAU * step / 96.0) * 14.0 / scale, 1.5, Color(0.68, 0.1, 0.07))
	map.generate_mipmaps()
	return map


func _map_dot(map: Image, at: Vector2, radius: float, ink: Color) -> void:
	for y in range(maxi(int(at.y - radius), 0), mini(int(at.y + radius) + 1, map.get_height())):
		for x in range(maxi(int(at.x - radius), 0), mini(int(at.x + radius) + 1, map.get_width())):
			if Vector2(x + 0.5, y + 0.5).distance_to(at) <= radius:
				map.set_pixel(x, y, ink)


# --- Who keeps watch on it -------------------------------------------------------------
# Entries for route_zone() in tools/level_builder.gd, on the ground as it lies.


## An enemy of `kind` that stands on the ground at `at` (x and z) and does
## nothing else: for route_zone().
func stands(kind: String, at: Vector2) -> Array:
	return [kind, ground(at.x, at.y)]


## One that stands guard at `at` and looks towards `faces`, up to `looks`
## degrees to either side of it.
func guard(kind: String, at: Vector2, faces: Vector2, looks := 35.0) -> Array:
	return [kind, ground(at.x, at.y), {"faces": ground(faces.x, faces.y), "looks": looks}]


## One that walks a beat: from the first of `spots` to the last and back, or
## round and round if it `loops`.
func beat(kind: String, spots: Array, loops := false) -> Array:
	var on_the_ground: Array[Vector3] = []
	for spot: Vector2 in spots:
		on_the_ground.append(ground(spot.x, spot.y))
	return [kind, on_the_ground[0], {"beat": on_the_ground, "loops": loops}]


# --- What grows on it ----------------------------------------------------------------


func _tree_kind(kind: String) -> Dictionary:
	if not _grown.has(kind):
		var scene := load("res://scenes/models/%s.scn" % kind) as PackedScene
		var one := scene.instantiate()
		_grown[kind] = {"scene": scene, "crowns": one.get_meta(&"crowns", []), "girth": one.get_meta(&"girth", 0.0), "height": one.get_meta(&"height", 1.0)}
		one.free()
	return _grown[kind]


## A tree of `kind`, one of the models of tools/models/trees.gd, on the
## ground at `at`: `size` times as large as it was made and turned `yaw_deg`.
## Its trunk is in the way. Its crown is not, but it keeps the sun off what
## lies beyond it, and the ground under it is needles.
func tree(kind: String, at: Vector2, size := 1.0, yaw_deg := 0.0) -> void:
	var info := _tree_kind(kind)
	var foot := ground(at.x, at.y, -0.12 * size)
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled(Vector3.ONE * size), foot)
	var node: Node3D = info.scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.name = kind.to_pascal_case()
	node.transform = xf
	if _trees == null:
		_trees = Node3D.new()
		_trees.name = "Trees"
		_add(_trees, _root)
	_add(node, _trees)
	var girth: float = info.girth * size
	if girth > 0.0:
		_collide_cylinder(Transform3D(Basis(), foot + Vector3.UP * 2.6), girth, 5.4, "wood")
	var reach := 0.0
	for crown: Array in info.crowns:
		casts_shade(xf * (crown[0] as Vector3), (crown[1] as Vector3) * size)
		reach = maxf(reach, (crown[1] as Vector3).x * size)
	if girth > 0.0:
		# What it has dropped lies well beyond its crown, and moss has taken
		# under it.
		cover("needles", at, reach * 1.9, 1.0, 0.55)
		cover("moss", at + Vector2(_prop_rng.randf_range(-1.0, 1.0), _prop_rng.randf_range(-1.0, 1.0)) * reach, reach * 0.9, 0.75, 0.6)


## How long a stretch of the wood beyond the land is one mesh, how many rows
## deep that wood stands, how far apart its rows and the trees of a row are,
## and from how far off its front row is drawn as trees are from afar.
const BEYOND_STRETCH := 52.0
const BEYOND_ROWS := 4
const BEYOND_ROW := 6.0
const BEYOND_GAP := 5.6
const BEYOND_FAR := 105.0
## How much of the light gets to each row of it where the wood throws no
## shadow, and the rows further in are simply darker; and how much of that
## its bark gets, which stands under its own crown.
const BEYOND_LIGHT: Array[float] = [1.0, 0.8, 0.62, 0.5]
const BEYOND_BARK := 0.6
## The pines of its edge, and of the rows behind: [kind, share].
const BEYOND_EDGE := [["pine_d", 2.0], ["pine_c", 2.0], ["pine_a", 2.0], ["pine_young", 0.6]]
const BEYOND_INNER := [["pine_a", 3.0], ["pine_b", 3.0], ["pine_c", 1.0]]
## What a tree of each kind adds to a mesh that many trees are merged into,
## by the part of its model and then by material: the arrays of a surface.
var _merged := {}
## How many stretches of wood beyond the land there are so far, and which
## of them throw a shadow.
var _beyond := 0
var _beyond_shadows := {}


## The wood that goes on beyond the land, where nobody comes: rows of pines
## behind the line from `from` to `to`, the tallest about `height` high, and
## behind them the dark of the wood. It faces whoever has `from` on his right
## and `to` on his left. The pines are those of the land. They are in
## nobody's way and are not instances but one mesh for every stretch of the
## line: the front row as a tree is from the middle distance, or from afar
## when the stretch is far off, and the rows behind it always as from afar.
##
## The shade the game knows of does not know of this wood. Where its shadow
## would fall on the land it therefore throws none, and the rows further in
## are simply made darker; where the sun stands on the side of the land, so
## that its shadow falls away from it, it throws one, on itself.
func tree_wall(from: Vector3, to: Vector3, height := 22.0) -> void:
	var length := from.distance_to(to)
	var along := (to - from) / length
	var back := along.cross(Vector3.UP)
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([from, to])
	var shadows := back.dot(-Vector3(_sunward.x, 0, _sunward.z).normalized()) > 0.3
	var stretches := maxi(roundi(length / BEYOND_STRETCH), 1)
	var stretch := length / stretches
	for s in stretches:
		var near := {}
		var far := {}
		var inner := {}
		for row in BEYOND_ROWS:
			var count := int(stretch / BEYOND_GAP)
			var kinds: Array = BEYOND_EDGE if row == 0 else BEYOND_INNER
			var total := 0.0
			for kind: Array in kinds:
				total += kind[1]
			for i in count:
				var at := from + along * (s * stretch + (i + dice.randf_range(0.1, 0.9)) * stretch / count) + back * (row * BEYOND_ROW + dice.randf_range(-1.6, 1.6)) + Vector3.DOWN * dice.randf_range(0.3, 0.9)
				# The trees further in stand higher over those in front.
				var size := height / 19.0 * dice.randf_range(0.84, 1.12) * (0.92 if row == 0 else 1.0)
				var xf := Transform3D(Basis(Vector3.UP, dice.randf() * TAU).scaled(Vector3.ONE * size), at)
				var light := (1.0 if shadows else BEYOND_LIGHT[row]) * dice.randf_range(0.82, 1.0)
				var pick := dice.randf() * total
				for kind: Array in kinds:
					pick -= kind[1]
					if pick <= 0.0:
						var bark := light * (1.0 if shadows else BEYOND_BARK)
						if row == 0:
							_merge_tree(near, kind[0], "Mid", xf, light, bark)
							_merge_tree(far, kind[0], "Far", xf, light, bark)
						else:
							_merge_tree(inner, kind[0], "Far", xf, light, bark)
						break
		for part: Array in [["near", near], ["far", far], ["inner", inner]]:
			for mat: String in part[1]:
				var st := SurfaceTool.new()
				st.create_from_arrays(_merged_arrays(part[1][mat]))
				_tools["|beyond %d %s/%s" % [_beyond, part[0], mat]] = st
		_beyond_shadows[_beyond] = shadows
		_beyond += 1
	# The dark of the wood, behind the last row: what is seen between the
	# trunks, and what shuts the gaps between the crowns.
	var st := _tool_named("|detail far/tree_line")
	var behind := back * (BEYOND_ROWS * BEYOND_ROW - 1.0) + Vector3.DOWN * 1.5
	var faces := -back
	var high := height * 0.86
	var repeats := length / (high * 4.0)
	_quad(st, [to + behind, from + behind, from + behind + Vector3.UP * high, to + behind + Vector3.UP * high], [faces, faces, faces, faces], [Vector2(0, 1), Vector2(repeats, 1), Vector2(repeats, 0), Vector2(0, 0)])


## What a tree of `kind` is made of, for merging into a larger mesh: by part
## ("Mid", "Far") and by material the arrays of that surface.
func _tree_surfaces(kind: String) -> Dictionary:
	if not _merged.has(kind):
		var one := (_tree_kind(kind).scene as PackedScene).instantiate()
		var parts := {}
		for part: MeshInstance3D in one.find_children("*", "MeshInstance3D", true, false):
			var surfaces := {}
			for i in part.mesh.get_surface_count():
				surfaces[part.mesh.surface_get_material(i).resource_path.get_file().get_basename()] = part.mesh.surface_get_arrays(i)
			parts[String(part.name)] = surfaces
		one.free()
		_merged[kind] = parts
	return _merged[kind]


## Adds the part `part` of a tree of `kind`, standing at `xf`, to the meshes
## gathered in `into`, one for each material: {points, normals, colours, uvs,
## corners}. `light` is how much of the light gets to its needles, 0 to 1,
## and `bark_light` how much to its wood.
func _merge_tree(into: Dictionary, kind: String, part: String, xf: Transform3D, light: float, bark_light: float) -> void:
	var surfaces: Dictionary = _tree_surfaces(kind)[part]
	var turn := Transform3D(xf.basis.orthonormalized(), Vector3.ZERO)
	for mat: String in surfaces:
		var arrays: Array = surfaces[mat]
		if not into.has(mat):
			into[mat] = {"points": PackedVector3Array(), "normals": PackedVector3Array(), "colours": PackedColorArray(), "uvs": PackedVector2Array(), "corners": PackedInt32Array()}
		var mesh: Dictionary = into[mat]
		var points: PackedVector3Array = mesh.points
		var normals: PackedVector3Array = mesh.normals
		var colours: PackedColorArray = mesh.colours
		var uvs: PackedVector2Array = mesh.uvs
		var corners: PackedInt32Array = mesh.corners
		var first := points.size()
		points.append_array(xf * (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array))
		normals.append_array(turn * (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array))
		uvs.append_array(arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array)
		# Bark is tinted by its vertex colour; needles keep in its blue how
		# much light gets to them, and wood that is drawn with the needles
		# says so in its alpha: see shaders/crown.gdshader.
		var bark := mat == "pine_trunk"
		for colour: Color in (arrays[Mesh.ARRAY_COLOR] as PackedColorArray):
			if bark:
				colours.append(Color(colour.r * bark_light, colour.g * bark_light, colour.b * bark_light, colour.a))
			else:
				colours.append(Color(colour.r, colour.g, colour.b * (bark_light if absf(colour.a - 0.5) < 0.1 else light), colour.a))
		for corner: int in (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array):
			corners.append(corner + first)
		mesh.points = points
		mesh.normals = normals
		mesh.colours = colours
		mesh.uvs = uvs
		mesh.corners = corners


## The arrays of a mesh as _merge_tree() gathers it, for a surface.
func _merged_arrays(mesh: Dictionary) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = mesh.points
	arrays[Mesh.ARRAY_NORMAL] = mesh.normals
	arrays[Mesh.ARRAY_COLOR] = mesh.colours
	arrays[Mesh.ARRAY_TEX_UV] = mesh.uvs
	arrays[Mesh.ARRAY_INDEX] = mesh.corners
	return arrays


## Keeps `area` (x and z) clear of the trees of a wood: a camp, a yard, a view.
func keep_open(area: Rect2) -> void:
	_open.append(area)


## Whether a tree can stand at `at`: on the land, on ground that is not
## firm, off the tracks, not in what is kept open, and not on a face of sand.
func _tree_fits(at: Vector2) -> bool:
	if not _land.grow(-2.0).has_point(at) or firm_at(at) > 0.25 or track_gap(at) < 2.6 or slope(at.x, at.y, 1.5) > 37.0:
		return false
	return not _open.any(func(area: Rect2) -> bool: return area.has_point(at))


## A wood over `area` (x and z): trees about `spacing` apart, of `kinds`,
## which lists [kind, share] for each. With `gaps` over -1 the wood has
## glades: the higher, the more of it is glade.
func wood(area: Rect2, spacing: float, kinds: Array, gaps := -1.0) -> void:
	var total := 0.0
	for kind: Array in kinds:
		total += kind[1]
	var glades := _noise(hash(area) & 0xffff, 31.0)
	for row in int(area.size.y / spacing):
		for column in int(area.size.x / spacing):
			# The dice fall the same way whether a tree comes of it or not.
			var at := area.position + (Vector2(column, row) + Vector2(_prop_rng.randf(), _prop_rng.randf())) * spacing
			var pick := _prop_rng.randf() * total
			var size := _prop_rng.randf_range(0.85, 1.2)
			var yaw := _prop_rng.randf() * 360.0
			if glades.get_noise_2dv(at) < gaps or not _tree_fits(at):
				continue
			for kind: Array in kinds:
				pick -= kind[1]
				if pick <= 0.0:
					tree(kind[0], at, size, yaw)
					break


## Thorn scrub so thick along `path` that nobody gets through it and nobody
## sees through it: bushes shoulder to shoulder over `width`, and a wall in
## them. What shuts a level in where there is no dune to do it.
func thicket(path: Array, width := 3.0, height := 2.6) -> void:
	var way := curve(path, 1.5)
	for i in way.size():
		var along := (way[mini(i + 1, way.size() - 1)] - way[maxi(i - 1, 0)]).normalized()
		for bush in 2:
			var at := way[i] + along.orthogonal() * _prop_rng.randf_range(-0.5, 0.5) * width + along * _prop_rng.randf_range(-0.6, 0.6)
			tree("scrub_a" if _prop_rng.randf() < 0.6 else "scrub_b", at, _prop_rng.randf_range(0.95, 1.45), _prop_rng.randf() * 360.0)
	for i in range(0, way.size() - 1, 3):
		var from := way[i]
		var to := way[mini(i + 3, way.size() - 1)]
		var middle := (from + to) * 0.5
		var low := minf(ground_height(from.x, from.y), ground_height(to.x, to.y)) - 1.0
		var top := maxf(ground_height(from.x, from.y), ground_height(to.x, to.y)) + height
		var heading := Vector3(to.x - from.x, 0, to.y - from.y)
		_collide_box(Transform3D(Basis.looking_at(heading), Vector3(middle.x, (low + top) * 0.5, middle.y)), Vector3(width * 0.6, top - low, heading.length() + 0.6), "soft")


## One part of a scanned model as it is strewn: its corners with its foot at
## nought, at the level of detail its importer made that comes nearest to
## `triangles` of them. `model` is its id in the manifest
## and `part` the name of the node in it. {points, normals, uvs, corners,
## high}.
func _scan_piece(model: String, part: String, triangles: int) -> Dictionary:
	var key := model + "/" + part
	if not _strewn.has(key):
		var found := (_model(model).scene as PackedScene).instantiate()
		var one := found.find_child(part, true, false) as MeshInstance3D
		var arrays := one.mesh.surface_get_arrays(0)
		var corners: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var surface := RenderingServer.mesh_get_surface(one.mesh.get_rid(), 0)
		var wide := 2 if (surface.vertex_count as int) <= 65536 else 4
		# Of the levels the importer made, the one nearest to what was asked.
		var nearest := absf(log(corners.size() / 3.0 / triangles))
		for lod: Dictionary in surface.get("lods", []):
			var packed: PackedByteArray = lod.index_data
			@warning_ignore("integer_division")
			var count := packed.size() / wide
			var off := absf(log(count / 3.0 / triangles))
			if off < nearest:
				nearest = off
				corners = PackedInt32Array()
				for i in count:
					corners.append(packed.decode_u16(i * 2) if wide == 2 else packed.decode_u32(i * 4))
		var box := one.mesh.get_aabb()
		var fit := Transform3D(one.transform.basis, one.transform.basis * -Vector3(box.get_center().x, box.position.y, box.get_center().z))
		var points := PackedVector3Array()
		var normals := PackedVector3Array()
		for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			points.append(fit * point)
		for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
			normals.append(fit.basis * normal)
		_strewn[key] = {"points": points, "normals": normals, "uvs": arrays[Mesh.ARRAY_TEX_UV], "corners": corners, "high": box.size.y}
		found.free()
	return _strewn[key]


## Stands or lays `piece`, see _scan_piece(), at `xf`, in the material `mat`
## (one of shaders/strewn.gdshader). It goes into the mesh its block of
## ground has for `kind`, one of STREWN_REACH: it is in nobody's way, casts
## no shadow and sinks away with distance. `sways` is how much of the wind
## it feels, none for wood.
func _strew(kind: String, mat: String, piece: Dictionary, xf: Transform3D, sways := 1.0) -> void:
	@warning_ignore("integer_division")
	var st := _tool_named("|%s %d %d/%s" % [kind, int(xf.origin.x) / GROUND_BLOCK, int(xf.origin.z) / GROUND_BLOCK, mat])
	var points: PackedVector3Array = piece.points
	var normals: PackedVector3Array = piece.normals
	var uvs: PackedVector2Array = piece.uvs
	var size := xf.basis.get_scale().y
	var phase := fposmod(xf.origin.x * 0.37 + xf.origin.z * 0.61, 1.0)
	for corner: int in piece.corners:
		var point := points[corner]
		st.set_color(Color(clampf(point.y / (piece.high as float), 0.0, 1.0) * sways, phase, clampf(point.y * size * 0.5, 0.0, 1.0)))
		st.set_normal((xf.basis * normals[corner]).normalized())
		st.set_uv(uvs[corner])
		st.add_vertex(xf * point)


## Stands one part of a scanned plant on the ground at `xf`: a fern out of
## the four the model holds, say. `model` is its id in the manifest and
## `part` the name of the node in it.
func sprig(model: String, part: String, xf: Transform3D) -> void:
	_strew("undergrowth", SPRIGS[model], _scan_piece(model, part, 260), xf)


## The material each scanned plant is strewn in.
const SPRIGS := {"fern_02": "fern", "shrub_03": "dune_weed"}
const FERNS: Array[String] = ["fern_02_a", "fern_02_b", "fern_02_c", "fern_02_d"]
const WEEDS: Array[String] = ["shrub_03_a", "shrub_03_b", "shrub_03_c", "shrub_03_d"]
const BOUGHS: Array[String] = ["dry_branches_medium_01_a", "dry_branches_medium_01_b", "dry_branches_medium_01_c"]


## Ferns under the pines around `at`: `count` of them within `radius`.
func ferns(at: Vector2, radius: float, count: int) -> void:
	for i in count:
		var spot := at + Vector2.RIGHT.rotated(_prop_rng.randf() * TAU) * radius * sqrt(_prop_rng.randf())
		var size := _prop_rng.randf_range(0.9, 1.5)
		sprig("fern_02", FERNS[_prop_rng.randi() % 4], Transform3D(Basis(Vector3.UP, _prop_rng.randf() * TAU).scaled(Vector3.ONE * size), ground(spot.x, spot.y, -0.02)))


## What a pine wood drops and what grows in it, wherever the land is wood:
## cones under every crown and roots at the foot of every trunk, dead boughs
## where they fell, ferns in drifts, thickest where the sun gets in, and
## weeds along its edges and beside its tracks. It is strewn when the ground
## is dressed, see _strew_wood().
func forest_floor() -> void:
	_floor_asked = true


## Strews what forest_floor() asked for, now that every tree stands and the
## shade is known.
func _strew_wood() -> void:
	var dice := _strew_rng
	var drifts := _noise(1301, 21.0)
	var cones := 0
	var roots := 0
	var count := {"fern": 0, "weed": 0, "bough": 0}
	# What grows: a throw for every two strides of the land.
	var step := 1.9
	for row in int(_land.size.y / step):
		for column in int(_land.size.x / step):
			var at := _land.position + (Vector2(column, row) + Vector2(dice.randf(), dice.randf())) * step
			var chance := dice.randf()
			var size := dice.randf()
			var yaw := dice.randf() * TAU
			var pick := dice.randi()
			if not _land.grow(-3.0).has_point(at) or firm_at(at) > 0.2 or slope(at.x, at.y) > 32.0:
				continue
			var deep := _between(_wooded, at)
			if deep < 0.06:
				continue
			var by_track := absf(_by_track[_spot_at(at)].x)
			var lit := 1.0 if not _in_shade(at) else 0.35
			var thick := smoothstep(0.05, 0.5, drifts.get_noise_2dv(at))
			var xf := Transform3D(Basis(Vector3.UP, yaw), ground(at.x, at.y, -0.02))
			if deep > 0.35 and by_track > 2.8 and chance < thick * lit * 0.22:
				_strew("undergrowth", "fern", _scan_piece("fern_02", FERNS[pick % 4], 260), xf.scaled_local(Vector3.ONE * lerpf(0.9, 1.7, size)))
				count.fern += 1
			elif by_track > 2.2 and (deep < 0.42 or by_track < 4.6) and chance > 0.6 and chance < 0.6 + lit * 0.2 * (1.0 - thick):
				_strew("undergrowth", "dune_weed", _scan_piece("shrub_03", WEEDS[pick % 4], 170), xf.scaled_local(Vector3.ONE * lerpf(1.0, 1.9, size)))
				count.weed += 1
			elif deep > 0.4 and by_track > 2.3 and chance > 0.984:
				# A bough lies as the ground lies.
				var lying := resting(at.x, at.y, rad_to_deg(yaw), 0.6, 0.01)
				_strew("undergrowth", "dead_wood", _scan_piece("dry_branches_medium_01", BOUGHS[pick % 3], 950), lying.scaled_local(Vector3.ONE * lerpf(0.8, 1.5, size)), 0.0)
				count.bough += 1
	# What every pine has at its foot and has dropped around it.
	if _trees:
		for tree: Node3D in _trees.get_children():
			var info := _tree_kind(tree.scene_file_path.get_file().get_basename())
			var girth: float = info.girth * tree.scale.y
			if girth <= 0.0:
				continue
			var at := Vector2(tree.position.x, tree.position.z)
			var reach := 2.0
			for crown: Array in info.crowns:
				reach = maxf(reach, (crown[1] as Vector3).x * tree.scale.y)
			for i in dice.randi_range(4, 8):
				var spot := at + Vector2.RIGHT.rotated(dice.randf() * TAU) * lerpf(girth + 0.3, reach * 1.15, sqrt(dice.randf()))
				_cone(spot, dice)
				cones += 1
			if girth > 0.14:
				var turn := dice.randf() * TAU
				var many := dice.randi_range(3, 5)
				for i in many:
					_pine_root(at, girth, turn + TAU * (i + dice.randf_range(-0.3, 0.3)) / many, dice)
					roots += 1
	print("Floor: %d ferns, %d weeds, %d boughs, %d cones, %d roots" % [count.fern, count.weed, count.bough, cones, roots])


## The fine grass that grows low, in tufts a hand or two high: under the
## pines where the sun gets in, on the crust of the grey dune, and on a
## track where no wheel goes, between the ruts and along its sides. It is
## strewn when the ground is dressed, see _strew_grass().
func dune_grass() -> void:
	_grass_asked = true


## Strews what dune_grass() asked for.
func _strew_grass() -> void:
	var dice := _strew_rng
	var glades := _noise(1409, 14.0)
	var tufts := 0
	var step := 1.5
	for row in int(_land.size.y / step):
		for column in int(_land.size.x / step):
			var at := _land.position + (Vector2(column, row) + Vector2(dice.randf(), dice.randf())) * step
			var chance := dice.randf()
			var seed := int(dice.randi())
			if not _land.grow(-3.0).has_point(at) or firm_at(at) > 0.3 or cover_at("earth", at) > 0.3 or slope(at.x, at.y) > 34.0:
				continue
			if absf(_by_track[_spot_at(at)].x) < 3.4:
				continue
			# How much of it grows here: in the wood by the light, in the
			# open by the crust.
			var patch := glades.get_noise_2dv(at)
			var want := smoothstep(0.4, 0.75, look_at_ground(at).b) * smoothstep(-0.35, 0.2, patch) * 0.55
			if _between(_wooded, at) > 0.3:
				want = smoothstep(0.0, 0.4, patch) * (0.5 if not _in_shade(at) else 0.14)
			if chance > want:
				continue
			# It stands a few tufts together.
			for i in 2 + seed % 3:
				var beside := at + Vector2.RIGHT.rotated(seed * 0.013 + i * 2.3) * 0.34 * i
				_tuft("dune_grass", beside, 0.55 + 0.12 * ((seed >> (4 + i * 2)) % 5), seed + i)
				tufts += 1
	for cut: Dictionary in _tracks:
		var way: PackedVector2Array = cut.path
		var run := 0.0
		for i in way.size() - 1:
			var along := way[i + 1] - way[i]
			run += along.length()
			var right := Vector2(-along.y, along.x).normalized()
			var seed := int(dice.randi())
			var chance := dice.randf()
			if cover_at("earth", way[i]) > 0.3 and _earth_beside.get_pixelv(Vector2i(((way[i] - _land.position) * COVER_SCALE).floor().clamp(Vector2.ZERO, Vector2(_cover.get_size() - Vector2i.ONE)))).r > 0.3:
				continue
			# Between the ruts, which weave as the material has them weave,
			# and along both sides: more of it where a wood shelters it.
			var sheltered := 0.35 + 0.65 * smoothstep(0.1, 0.4, _between(_wooded, way[i]))
			var weave := 0.17 * sin(run * 0.071) + 0.09 * sin(run * 0.19 + 1.7)
			var knots := glades.get_noise_2dv(way[i] * 2.3)
			if chance < smoothstep(-0.3, 0.3, knots) * 0.75 * sheltered:
				_tuft("dune_grass", way[i] + right * (-weave + ((seed % 100) / 100.0 - 0.5) * 0.5), 0.5 + 0.1 * (seed % 4), seed)
				tufts += 1
			for side: float in [-1.0, 1.0]:
				if (seed >> (8 if side > 0.0 else 12)) % 16 < int(7.0 * sheltered):
					_tuft("dune_grass", way[i] + right * side * (2.5 + 0.9 * ((seed >> 16) % 100) / 100.0), 0.6 + 0.12 * ((seed >> 20) % 5), seed + 7)
					tufts += 1
	print("Grass: %d tufts" % tufts)


## A tuft of fine grass at `at`, `size` times a tuft that stands half a
## metre high: three cards that stand through each other and lean apart,
## each with one quarter of the picture `mat` shows. The tufts of a block of
## ground are one mesh, which is only drawn from close by, see _commit().
func _tuft(mat: String, at: Vector2, size: float, seed: int) -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = seed
	@warning_ignore("integer_division")
	var st := _tool_named("|litter %d %d/%s" % [int(at.x) / GROUND_BLOCK, int(at.y) / GROUND_BLOCK, mat])
	var foot := ground(at.x, at.y, -0.03)
	var phase := dice.randf()
	var withered := dice.randf() * dice.randf()
	var turn := dice.randf() * TAU
	for card in 3:
		var angle := turn + card * TAU / 3.0 + dice.randf_range(-0.3, 0.3)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-out.z, 0.0, out.x)
		# Which quarter: the withered ones, in seed, are the taller.
		var quarter := dice.randi() % 4
		var top := 0.42 if quarter < 2 else 0.2
		var high := size * (1.0 - top) * 1.1
		var half := size * 0.55 * 0.5 * dice.randf_range(0.85, 1.15)
		var left := quarter * 0.25 + 0.003
		var right := quarter * 0.25 + 0.247
		if dice.randf() < 0.5:
			var swap := left
			left = right
			right = swap
		var lean := out * high * dice.randf_range(0.15, 0.5)
		var low := foot - out * size * 0.05
		var corners: Array[Vector3] = [low - side * half, low + side * half, low + lean + Vector3.UP * high + side * half, low + lean + Vector3.UP * high - side * half]
		var uvs: Array[Vector2] = [Vector2(left, 1.0), Vector2(right, 1.0), Vector2(right, top), Vector2(left, top)]
		var lit: Array[Color] = [Color(0, phase, 0.6, withered), Color(0, phase, 0.6, withered), Color(1, phase, 1, withered), Color(1, phase, 1, withered)]
		var normal := (Vector3.UP + out * 0.3).normalized()
		for corner: int in [0, 2, 1, 0, 3, 2]:
			st.set_color(lit[corner])
			st.set_normal(normal)
			st.set_uv(uvs[corner])
			st.add_vertex(corners[corner])


## Darkens the ground where a lorry, a jeep or a tank stands: what drips
## out of an engine and an axle, as a stain or two under each. Whatever
## stands under the node "Vehicles" of the level counts, see vehicle() in
## tools/kit/field.gd.
func _stain_standings() -> void:
	var parked := _root.get_node_or_null("Vehicles")
	if parked == null:
		return
	var dice := _strew_rng
	for standing: Node3D in parked.get_children():
		var nose := -standing.transform.basis.z
		for drip: float in [0.55, -0.35]:
			# Not all of it under the middle: it has stood here before, a
			# little to one side.
			var at := standing.position + nose * (drip * 2.4 + dice.randf_range(-0.4, 0.4)) + standing.transform.basis.x * dice.randf_range(0.5, 1.5) * (1.0 if dice.randf() < 0.5 else -1.0)
			var wide := dice.randf_range(1.4, 2.6)
			var stain := Decal.new()
			stain.name = "Drip"
			stain.texture_albedo = load("res://assets/decals/stain_%d.png" % dice.randi_range(1, 2))
			# It lies as the ground lies there, and is deep enough for
			# ground that is not level.
			stain.transform = resting(at.x, at.z, dice.randf() * 360.0, 0.8)
			stain.size = Vector3(wide, 0.7, wide * dice.randf_range(0.7, 1.2))
			stain.modulate = Color(0.5, 0.42, 0.34, dice.randf_range(0.75, 1.0))
			stain.upper_fade = 0.05
			stain.lower_fade = 0.05
			stain.distance_fade_enabled = true
			stain.distance_fade_begin = 35.0
			stain.distance_fade_length = 10.0
			_add(stain, _group("Decals", stain.position))


## True if the sun does not come to the ground at `at`, as _shade_land() found.
func _in_shade(at: Vector2) -> bool:
	if _shade_bits == null:
		return false
	var dot := Vector2i(((at - _land.position) * COVER_SCALE).floor())
	var size := _shade_bits.get_size()
	return dot.x >= 0 and dot.y >= 0 and dot.x < size.x and dot.y < size.y and _shade_bits.get_bitv(dot)


## A pine cone lying on the ground at `at`: a thumb long, fat in the middle.
func _cone(at: Vector2, dice: RandomNumberGenerator) -> void:
	const SIDES := 5
	@warning_ignore("integer_division")
	var st := _tool_named("|litter %d %d/pine_litter" % [int(at.x) / GROUND_BLOCK, int(at.y) / GROUND_BLOCK])
	var long := dice.randf_range(0.055, 0.085)
	var xf := Transform3D(Basis(Vector3.UP, dice.randf() * TAU) * Basis(Vector3.RIGHT, dice.randf_range(-0.3, 0.3)), ground(at.x, at.y, long * 0.2))
	var patch := Vector2(dice.randf(), dice.randf())
	# It lies along its own Z: a point, two rings and a point.
	var rings: Array[Vector2] = [Vector2(-0.5, 0.0), Vector2(-0.22, 0.27), Vector2(0.18, 0.3), Vector2(0.5, 0.0)]
	var points: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	for ring in rings.size():
		for side in SIDES + 1:
			var out := Vector3(cos(TAU * side / SIDES), sin(TAU * side / SIDES), 0.0)
			points.append(xf * ((out * rings[ring].y + Vector3(0, 0, rings[ring].x)) * long))
			normals.append(xf.basis * (out + Vector3(0, 0, rings[ring].x * 1.4)).normalized())
			uvs.append(patch + Vector2(float(side) / SIDES * 0.16, ring * 0.05))
	for ring in rings.size() - 1:
		for side in SIDES:
			var a := ring * (SIDES + 1) + side
			for corner: int in [a, a + SIDES + 2, a + 1, a, a + SIDES + 1, a + SIDES + 2]:
				st.set_color(Color(0, 0, 0.02))
				st.set_normal(normals[corner])
				st.set_uv(uvs[corner])
				st.add_vertex(points[corner])


## A root of the pine that stands at `at` with a trunk `girth` thick: it
## leaves the trunk towards `heading`, lies on the ground for a stride, and
## goes under.
func _pine_root(at: Vector2, girth: float, heading: float, dice: RandomNumberGenerator) -> void:
	const SIDES := 5
	@warning_ignore("integer_division")
	var st := _tool_named("|litter %d %d/pine_litter" % [int(at.x) / GROUND_BLOCK, int(at.y) / GROUND_BLOCK])
	var out := Vector2.RIGHT.rotated(heading)
	var bend := dice.randf_range(-0.7, 0.7)
	var long := girth * dice.randf_range(2.6, 5.0)
	var thick := girth * dice.randf_range(0.34, 0.5)
	# Where it runs, and how high over the ground and how thick it is there:
	# out of the trunk a hand over the ground, down on to it, along it with
	# a kink or two, and under.
	var path: Array[Vector3] = []
	var radii: Array[float] = []
	for i in 6:
		var t := i / 5.0
		var spot := at + out.rotated(bend * t * t + dice.randf_range(-0.12, 0.12) * minf(i, 1)) * (girth * 0.5 + long * t)
		var lift: float = [girth * 1.1 + thick, thick * 0.9, thick * 0.35, thick * 0.1, -thick * 0.3, -thick * 1.4][i]
		path.append(ground(spot.x, spot.y, lift))
		radii.append(thick * [1.2, 1.0, 0.8, 0.62, 0.46, 0.3][i])
	var around: Array[Vector3] = []
	var run := 0.0
	var u := dice.randf()
	for i in path.size():
		var along := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var side := along.cross(Vector3.UP).normalized()
		var up := side.cross(along)
		var ring: Array[Vector3] = []
		for s in SIDES + 1:
			ring.append(side * cos(TAU * s / SIDES) + up * sin(TAU * s / SIDES))
		if i > 0:
			var length := path[i].distance_to(path[i - 1])
			for s in SIDES:
				var corners: Array[Vector3] = [path[i - 1] + around[s] * radii[i - 1], path[i - 1] + around[s + 1] * radii[i - 1], path[i] + ring[s + 1] * radii[i], path[i] + ring[s] * radii[i]]
				var normals: Array[Vector3] = [around[s], around[s + 1], ring[s + 1], ring[s]]
				var uvs: Array[Vector2] = [Vector2(u + s * 0.12, run), Vector2(u + (s + 1) * 0.12, run), Vector2(u + (s + 1) * 0.12, run + length * 0.6), Vector2(u + s * 0.12, run + length * 0.6)]
				for corner: int in [0, 1, 2, 0, 2, 3]:
					st.set_color(Color(0, 0, 0.03))
					st.set_normal(normals[corner])
					st.set_uv(uvs[corner])
					st.add_vertex(corners[corner])
			run += length * 0.6
		around = ring


## Marram over `area` (x and z), where the sand is loose and bare. It grows
## in drifts: clumps about `spacing` apart where it stands thick, on crests
## and on the backs the wind climbs more than in the hollows, and none at
## all between the drifts; the higher `gaps`, the more of the area has none.
## The clumps are stood when the ground is dressed, see _stand_marram().
func marram(area: Rect2, spacing: float, gaps := 0.0) -> void:
	_marram.append({"area": area, "spacing": spacing, "gaps": gaps})


## One clump of marram by itself at `at`, `size` times a clump that stands a
## metre high: at the foot of a wall, beside a post. `seed` makes it this
## clump and no other. It is stood with the rest, see _stand_marram().
func marram_clump(at: Vector2, size: float, seed: int) -> void:
	_clumps.append({"at": at, "size": size, "seed": seed})


## Stands the marram that was asked for, now that the land has been read:
## where it grows depends on how the land lies. Each clump is thrown with
## dice of its own kind, whether it comes to stand or not.
func _stand_marram() -> void:
	var drifts := _noise(977, 27.0)
	var knots := _noise(978, 6.0)
	for asked: Dictionary in _marram:
		var area: Rect2 = asked.area
		var step: float = asked.spacing * 0.6
		for row in int(area.size.y / step):
			for column in int(area.size.x / step):
				var at := area.position + (Vector2(column, row) + Vector2(_strew_rng.randf(), _strew_rng.randf())) * step
				var chance := _strew_rng.randf()
				var size := _strew_rng.randf()
				var seed := int(_strew_rng.randi())
				if not _land.grow(-1.0).has_point(at) or firm_at(at) > 0.15 or cover_at("needles", at) > 0.4 or cover_at("earth", at) > 0.15:
					continue
				if absf(_by_track[_spot_at(at)].x) < 3.0:
					continue
				var look := look_at_ground(at)
				# How thick it stands here, 0 to 1: nothing outside a drift,
				# and the heart of a drift is thick with it.
				var thick := 0.5 + drifts.get_noise_2dv(at) * 0.6 + (look.r - 0.5) * 0.9 - (asked.gaps as float) * 0.5
				thick = smoothstep(0.47, 0.72, thick)
				# Within a drift it stands in knots: large clumps together,
				# and little between one knot and the next.
				var knot := smoothstep(-0.25, 0.45, knots.get_noise_2dv(at))
				if chance > thick * (0.14 + 0.8 * knot * thick):
					continue
				var large := lerpf(0.45, 1.1, pow(size, 1.3)) * lerpf(0.62, 1.22, thick * knot)
				_clumps.append({"at": at, "size": large, "seed": seed})
				# A large clump has young ones around its foot.
				for i in (seed % 4 if large > 0.75 else 0):
					var beside := at + Vector2.RIGHT.rotated((seed >> 4) * 0.37 + i * 2.1) * (0.55 + 0.2 * i) * large
					_clumps.append({"at": beside, "size": 0.22 + 0.06 * ((seed >> (8 + i)) % 4), "seed": seed + i + 1})
	for clump: Dictionary in _clumps:
		_clump("marram", clump.at, clump.size, clump.seed)
	# How much grass stands around each spot, for the ground to show when
	# it is too far off to be drawn; and where it stands the sand moves,
	# and no crust forms.
	var grass := PackedFloat32Array()
	grass.resize(_looks.size())
	for clump: Dictionary in _clumps:
		grass[_spot_at(clump.at)] += clump.size * clump.size
	grass = _evened(grass, 2)
	for i in _looks.size():
		var stands := clampf(grass[i] * 5.0, 0.0, 1.0)
		_looks[i] = Color(_looks[i].r, _looks[i].g, _looks[i].b * (1.0 - stands * 0.7), stands)
	print("Marram: %d clumps" % _clumps.size())


## The spot of the land nearest to `at`, as its place in the lists that
## have one entry a spot.
func _spot_at(at: Vector2) -> int:
	var spot := ((at - _land.position) / LAND_CELL).round()
	return clampi(int(spot.y), 0, _down() - 1) * _across() + clampi(int(spot.x), 0, _across() - 1)


## What a card shows of each of the four tussocks in the picture of a
## grass material such as "marram", see tools/render_grass.py: two cells by
## two, of which a card is cut to a trapezium, narrow at the foot. For each
## tussock how high it stands in its cell, as a share of the cell.
const TUSSOCK_HIGH: Array[float] = [0.9, 0.96, 0.84, 0.56]
## How wide a tussock is at its foot and at its top, as a share of its cell.
const TUSSOCK_FOOT := 0.44
const TUSSOCK_TOP := 0.86
## How large a cell is for a clump of size one, in metres.
const TUSSOCK_CELL := 1.2


## A clump of grass at `at`, `size` times a clump that stands a metre high:
## pictures of a whole tussock on cards (shaders/grass.gdshader) that stand
## through each other in its middle, each leaning its own way a little, and
## round them a skirt of shorter ones that lean well out. `seed` is what
## makes it this clump and no other. The clumps of a block of ground are one
## mesh, which casts no shadow and is not drawn from far off, see _commit().
func _clump(mat: String, at: Vector2, size: float, seed: int) -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = seed
	@warning_ignore("integer_division")
	var st := _tool_named("|strewn %d %d/%s" % [int(at.x) / GROUND_BLOCK, int(at.y) / GROUND_BLOCK, mat])
	var foot := ground(at.x, at.y, (MOUND_HIGH * size if size >= MOUND_FROM else 0.0) - 0.05 * size)
	var phase := dice.randf()
	# How much of it is last year's straw.
	var withered := dice.randf() * dice.randf()
	var turn := dice.randf() * TAU
	# In flower or not, the whole clump.
	var flowers := size > 0.6 and dice.randf() < 0.35
	var upright := 3 if size > 0.55 else 2
	var skirt := (2 + dice.randi() % 3) if size > 0.4 else 0
	for card in upright + skirt:
		var stands := card < upright
		var angle := turn + (card * PI / upright if stands else (card - upright) * TAU / maxi(skirt, 1) + 0.6) + dice.randf_range(-0.3, 0.3)
		var side := Vector3(cos(angle), 0.0, sin(angle))
		var out := Vector3(-side.z, 0.0, side.x)
		# Which tussock of the four: in leaf or in flower in the middle, and
		# round it short ones and straw.
		var tussock := 1 if flowers and card == 0 else (2 if dice.randf() < withered else 0)
		if not stands:
			tussock = 2 if dice.randf() < 0.25 + withered * 0.5 else 3
		var cell := TUSSOCK_CELL * size * dice.randf_range(0.88, 1.12) * (1.0 if stands else 0.8)
		var high: float = cell * TUSSOCK_HIGH[tussock]
		var lean := dice.randf_range(-0.16, 0.16) if stands else dice.randf_range(0.5, 0.85)
		var low := foot + (Vector3.ZERO if stands else out * 0.1 * size)
		var top := low + (Vector3.UP * cos(lean) + out * sin(lean)) * high
		var left := float(tussock % 2) * 0.5
		@warning_ignore("integer_division")
		var over := float(tussock / 2) * 0.5
		var mirror := -1.0 if dice.randf() < 0.5 else 1.0
		var light := 1.0 if stands else 0.88
		var corners: Array[Vector3] = []
		var normals: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		var lit: Array[Color] = []
		for row in 2:
			var half := cell * 0.5 * (TUSSOCK_FOOT if row == 0 else TUSSOCK_TOP)
			var share := (TUSSOCK_FOOT if row == 0 else TUSSOCK_TOP) * 0.5
			for edge: float in [-1.0, 1.0]:
				corners.append((low if row == 0 else top) + side * half * edge)
				# Lit as one round mass: up at the foot, up and outwards at
				# the tips.
				normals.append((Vector3.UP + (side * edge * 0.55 + out * (0.0 if stands else 0.5)) * row).normalized())
				uvs.append(Vector2(left + 0.25 + share * edge * mirror * 0.5, over + 0.5 - 0.005 - (TUSSOCK_HIGH[tussock] * 0.5 if row == 1 else 0.0)))
				lit.append(Color(row, phase, light * (0.5 if row == 0 else 1.0), withered))
		for corner: int in [0, 1, 3, 0, 3, 2]:
			st.set_color(lit[corner])
			st.set_normal(normals[corner])
			st.set_uv(uvs[corner])
			st.add_vertex(corners[corner])


## The sand a clump of grass at `at` has caught: a low mound, added to the
## corners of a block of ground as the lists of _dress_ground() have them.
## It is ground like the ground around it, but that the material is told
## where each corner lies under the clump, in place of where it lies by a
## track: (0, 0) at its foot and one out at its rim, put TRACK_FAR + 2 to
## the right. By that it draws the foot dark, which is all the shadow the
## grass has. The mound reaches further on the side away from the sun,
## where that shadow would fall, and to the lee, where the sand drops.
func _mound(at: Vector2, size: float, points: PackedVector3Array, facing: PackedVector3Array, uvs: PackedVector2Array, tracks: PackedVector2Array, looks: PackedColorArray, corners: PackedInt32Array) -> void:
	const SIDES := 7
	var first := points.size()
	var reach := 0.42 * size + 0.14
	var shadow := -Vector2(_sunward.x, _sunward.z).normalized()
	var lie := ground_normal(at.x, at.y, 0.6)
	points.append(ground(at.x, at.y, MOUND_HIGH * size))
	facing.append(lie)
	uvs.append(at)
	tracks.append(Vector2(TRACK_FAR + 2.0, 0.0))
	looks.append(look_at_ground(at))
	for ring in 2:
		var share := 0.5 if ring == 0 else 1.0
		for i in SIDES:
			var out := Vector2.RIGHT.rotated(TAU * (i + ring * 0.5) / SIDES)
			var far := reach * (1.0 + 0.5 * maxf(out.dot(shadow), 0.0) + 0.25 * maxf(out.y, 0.0))
			var spot := at + out * far * share
			points.append(ground(spot.x, spot.y, MOUND_HIGH * size * 0.5 if ring == 0 else -0.035))
			facing.append((lie + Vector3(out.x, 0.0, out.y) * (0.3 if ring == 0 else 0.1)).normalized())
			uvs.append(spot)
			tracks.append(Vector2(TRACK_FAR + 2.0, 0.0) + out * share)
			looks.append(look_at_ground(spot))
	for i in SIDES:
		var inner := first + 1 + i
		var inner_next := first + 1 + (i + 1) % SIDES
		var outer := first + 1 + SIDES + i
		var outer_next := first + 1 + SIDES + (i + 1) % SIDES
		corners.append_array([first, inner, inner_next, inner, outer, inner_next, inner_next, outer, outer_next])
