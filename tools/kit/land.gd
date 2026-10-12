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
## The meshes of scanned models that are strewn about one by one, by model
## and part: {mesh, fit}. See sprig().
var _strewn := {}
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
	cover_along("earth", way, half + 0.6, 0.8)


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
			var dot := _cover.get_pixel(x, y)
			dot[channel] = maxf(dot[channel], amount * (1.0 - smoothstep(1.0 - soft, 1.0, share)))
			_cover.set_pixel(x, y, dot)


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
			var dot := _cover.get_pixel(x, y)
			dot[channel] = maxf(dot[channel], amount * (1.0 - smoothstep(1.0 - soft, 1.0, share)))
			_cover.set_pixel(x, y, dot)


## The same over the whole of `area` (x and z), evenly.
func cover_over(kind: String, area: Rect2, amount := 1.0) -> void:
	if _cover == null:
		return
	var channel: int = COVERS[kind]
	var from := ((area.position - _land.position) * COVER_SCALE).floor()
	var to := ((area.end - _land.position) * COVER_SCALE).ceil()
	for y in range(maxi(int(from.y), 0), mini(int(to.y), _cover.get_height())):
		for x in range(maxi(int(from.x), 0), mini(int(to.x), _cover.get_width())):
			var dot := _cover.get_pixel(x, y)
			dot[channel] = maxf(dot[channel], amount)
			_cover.set_pixel(x, y, dot)


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


## Lays the ground as it has been shaped: its collider, and its mesh in
## blocks. Nothing shapes it after this.
func lay_ground(mat := "dune_ground") -> void:
	var across := _across()
	var down := _down()
	var field := HeightMapShape3D.new()
	field.map_width = across
	field.map_depth = down
	field.map_data = _heights
	var body := StaticBody3D.new()
	body.name = "Ground"
	_add(body, _root)
	var collider := CollisionShape3D.new()
	collider.shape = field
	collider.position = Vector3(_land.get_center().x, 0.0, _land.get_center().y)
	collider.set_meta(&"surface", "sand")
	_add(collider, body)

	# Which way every spot faces, from its neighbours on the whole land: the
	# blocks then meet without a seam.
	var normals := PackedVector3Array()
	normals.resize(across * down)
	for row in down:
		for column in across:
			var west := _heights[row * across + maxi(column - 1, 0)]
			var east := _heights[row * across + mini(column + 1, across - 1)]
			var north := _heights[maxi(row - 1, 0) * across + column]
			var south := _heights[mini(row + 1, down - 1) * across + column]
			normals[row * across + column] = Vector3(west - east, 2.0 * LAND_CELL, north - south).normalized()
	for first_row in range(0, down - 1, GROUND_BLOCK):
		for first_column in range(0, across - 1, GROUND_BLOCK):
			var columns := mini(GROUND_BLOCK, across - 1 - first_column)
			var rows := mini(GROUND_BLOCK, down - 1 - first_row)
			var points := PackedVector3Array()
			var facing := PackedVector3Array()
			var uvs := PackedVector2Array()
			var corners := PackedInt32Array()
			for row in rows + 1:
				for column in columns + 1:
					var i := (first_row + row) * across + first_column + column
					var at := _spot(first_column + column, first_row + row)
					points.append(Vector3(at.x, _heights[i], at.y))
					facing.append(normals[i])
					uvs.append(at)
			for row in rows:
				for column in columns:
					var nw := row * (columns + 1) + column
					var ne := nw + 1
					var sw := nw + columns + 1
					var se := sw + 1
					corners.append_array([nw, se, sw, nw, ne, se])
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = points
			arrays[Mesh.ARRAY_NORMAL] = facing
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			arrays[Mesh.ARRAY_INDEX] = corners
			@warning_ignore("integer_division")
			var key := "|ground %d %d/%s" % [first_column / GROUND_BLOCK, first_row / GROUND_BLOCK, mat]
			var st := SurfaceTool.new()
			st.create_from_arrays(arrays)
			_tools[key] = st


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
		var map := _cover.duplicate() as Image
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
	elif kind.begins_with("strewn "):
		# Tufts of grass: there are thousands, and none matters from afar.
		var tufts := _root.get_child(0) as MeshInstance3D
		tufts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tufts.visibility_range_end = 85.0
		tufts.visibility_range_end_margin = 6.0


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
## scripts/land.gd: where the shade lies. And puts down what was strewn. Both
## are files of the level, written once last time's have been cleared out.
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
	for key: String in _strewn:
		var mesh: Mesh = _strewn[key].mesh
		var file := "%s%s_%s.res" % [OUT_DIR, _level_name(), key.get_file()]
		ResourceSaver.save(mesh, file, ResourceSaver.FLAG_COMPRESS)
		mesh.take_over_path(file)


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


## The edge of a wood from afar, as a wall of it from `from` to `to` and
## `height` high: what stands beyond the land, where nobody comes. It faces
## whoever has `from` on his right and `to` on his left.
func tree_wall(from: Vector3, to: Vector3, height := 22.0) -> void:
	var st := _tool_named("|detail far/tree_line")
	var faces := (Vector3.UP.cross(to - from).normalized() + Vector3.UP * 0.5).normalized()
	var repeats := from.distance_to(to) / (height * 3.4)
	_quad(st, [from, to, to + Vector3.UP * height, from + Vector3.UP * height], [faces, faces, faces, faces], [Vector2(0, 1), Vector2(repeats, 1), Vector2(repeats, 0), Vector2(0, 0)])


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


## Stands one mesh of a scanned model on the ground at `xf`: a fern out of
## the four the model holds, say. `model` is its id in the manifest and `part`
## the name of the node in it. It is in nobody's way, casts no shadow and is
## not drawn from far off.
func sprig(model: String, part: String, xf: Transform3D) -> void:
	var key := model + "/" + part
	if not _strewn.has(key):
		# A copy of its own: a mesh inside an imported scene is not something
		# a level can point at. It becomes a file of the level, see
		# _finish_zones().
		var found := (_model(model).scene as PackedScene).instantiate()
		var one := found.find_child(part, true, false) as MeshInstance3D
		var box := one.mesh.get_aabb()
		_strewn[key] = {
			"mesh": one.mesh.duplicate(true),
			"fit": Transform3D(one.transform.basis, one.transform.basis * -Vector3(box.get_center().x, box.position.y, box.get_center().z)),
		}
		found.free()
	var node := MeshInstance3D.new()
	node.name = part.to_pascal_case()
	node.mesh = _strewn[key].mesh
	node.transform = xf * (_strewn[key].fit as Transform3D)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	node.visibility_range_end = 55.0
	node.visibility_range_end_margin = 5.0
	if not _root.has_node("Strewn"):
		var under := Node3D.new()
		under.name = "Strewn"
		_add(under, _root)
	_add(node, _root.get_node("Strewn"))


## Ferns under the pines around `at`: `count` of them within `radius`.
func ferns(at: Vector2, radius: float, count: int) -> void:
	var parts: Array[String] = ["fern_02_a", "fern_02_b", "fern_02_c", "fern_02_d"]
	for i in count:
		var spot := at + Vector2.RIGHT.rotated(_prop_rng.randf() * TAU) * radius * sqrt(_prop_rng.randf())
		var size := _prop_rng.randf_range(0.9, 1.5)
		sprig("fern_02", parts[_prop_rng.randi() % 4], Transform3D(Basis(Vector3.UP, _prop_rng.randf() * TAU).scaled(Vector3.ONE * size), ground(spot.x, spot.y, -0.02)))


## A tuft of grass at `xf`: three cards that stand through each other, wider
## at the top than at the foot. The tufts of a block of ground are one mesh,
## which casts no shadow and is not drawn from far off, see _commit().
func tuft(mat: String, xf: Transform3D) -> void:
	@warning_ignore("integer_division")
	var st := _tool_named("|strewn %d %d/%s" % [int(xf.origin.x) / GROUND_BLOCK, int(xf.origin.z) / GROUND_BLOCK, mat])
	var phase := fposmod(xf.origin.x * 0.37 + xf.origin.z * 0.61, 1.0)
	var up := xf.basis * Vector3.UP
	for card in 3:
		var side := Vector3.RIGHT.rotated(Vector3.UP, card * PI / 3.0 + 0.2) * 0.45
		var lean := side.cross(Vector3.UP) * 0.12
		var corners: Array[Vector3] = [xf * (-side * 0.9), xf * (side * 0.9), xf * (side + lean + Vector3.UP * 0.85), xf * (-side + lean + Vector3.UP * 0.85)]
		var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		var lit: Array[Color] = [Color(0, phase, 0.6, 0), Color(0, phase, 0.6, 0), Color(1, phase, 1, 0), Color(1, phase, 1, 0)]
		for i: int in [0, 2, 1, 0, 3, 2]:
			st.set_color(lit[i])
			st.set_normal(up)
			st.set_uv(uvs[i])
			st.add_vertex(corners[i])


## Marram over `area` (x and z), tufts about `spacing` apart, where the sand
## is loose and bare; `gaps` as for a wood.
func marram(area: Rect2, spacing: float, gaps := 0.0) -> void:
	var bare := _noise(hash(area) & 0xffff, 17.0)
	for row in int(area.size.y / spacing):
		for column in int(area.size.x / spacing):
			var at := area.position + (Vector2(column, row) + Vector2(_prop_rng.randf(), _prop_rng.randf())) * spacing
			var size := _prop_rng.randf_range(0.75, 1.5)
			var yaw := _prop_rng.randf() * TAU
			if bare.get_noise_2dv(at) < gaps or not _land.grow(-1.0).has_point(at) or firm_at(at) > 0.15 or cover_at("needles", at) > 0.4 or cover_at("earth", at) > 0.15:
				continue
			tuft("marram", Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(size, size * _prop_rng.randf_range(0.8, 1.2), size)), ground(at.x, at.y, -0.04)))
