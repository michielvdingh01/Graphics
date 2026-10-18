extends "res://tools/kit/rooms.gd"
## Fifteenth drawer of the kit, see tools/kit.gd: what stands in a valley of
## Tyrol. Hay barns by the dozen over the meadows, a farmhouse with its barn
## under one roof, a chapel, a cross and a shrine by the way, a hunter's
## stand at the edge of a wood, fences, poles hung with hay, stacks of
## firewood, a bridge over a brook, a line of wooden poles with its wires,
## and a trough. All of it stands on the ground as it lies (see
## tools/kit/land.gd): a spot is given as x and z, and its height is asked.
##
## A valley is looked across: a barn two kilometres off still stands out
## against the meadow. Everything that is seen from that far is built twice,
## as it is and as a few faces coloured as it looks from afar, and the one
## gives way to the other at NEAR_REACH. What is small is not drawn from
## further off than it can be seen. What is built goes into the meshes of
## its block of ground, ALPINE_BLOCK metres square, one for each material
## and each distance: a barn costs no draw call of its own. See _tool() and
## _commit().
##
## Nothing here has a lightmap. What a piece is made of says how it has
## weathered, and the materials read that off where they stand: which way a
## face looks, how high it is over the ground, where its edges are. See
## shaders/alpine_wood.gdshader and the others beside it.

const LARCH := "alpine_larch"
const DARK_WOOD := "alpine_brown"
const STONE := "alpine_stone"
const ROCK := "alpine_rock"
const LIME := "alpine_lime"
const SHINGLES := "alpine_shingles"
const TIN := "alpine_tin"
const HAY := "alpine_hay"
const PAINT := "alpine_paint"
const PANE := "alpine_pane"
const LOG_ENDS := "alpine_logends"
const WATER := "alpine_water"
const FAR := "alpine_far"
const BARK := "bark"
## The paints of alpine_paint by number, see shaders/alpine_paint.gdshader:
## what goes into UV2.x is the number over ten.
const PAINTS := {"white": 0, "green": 1, "oxblood": 2, "pale": 3, "blue": 4, "gold": 5, "black": 6, "meadow": 7}
## How many metres of ground go into the meshes of one block, along x and
## along z.
const ALPINE_BLOCK := 64.0
## Where a building gives way to its drawing from afar, in metres; and from
## how far to how far off each kind of mesh is drawn, nought for no limit:
## a building as it is, the same from afar, what is small (a fence, a cross,
## a stack of wood), what is tall and thin (a pole), and wire.
const NEAR_REACH := 240.0
const ALPINE_REACH := {
	"near": Vector2(0.0, NEAR_REACH),
	"far": Vector2(NEAR_REACH, 0.0),
	"small": Vector2(0.0, 170.0),
	"tall": Vector2(0.0, 450.0),
	"wire": Vector2(0.0, 230.0),
}
## How far past one of those distances a mesh is still drawn, or not yet,
## once it is or is not: so that it does not blink at the very distance.
const ALPINE_MARGIN := 10.0
## Across a timber the scan of boards is squeezed this much, so that a log
## shows the grain of one board and not the joints of three.
const SQUEEZE := 0.35
## What a bullet finds in each material, see _surface().
const ALPINE_SURFACES := {
	"alpine_larch": "wood", "alpine_brown": "wood", "alpine_paint": "wood", "alpine_shingles": "wood",
	"alpine_logends": "wood", "alpine_tin": "metal", "alpine_hay": "soft", "alpine_stone": "brick",
	"alpine_rock": "brick", "alpine_lime": "", "alpine_water": "soft",
}
## The hay barns: how wide they are (across the ridge, outside the walls),
## how long, how high their walls are over the floor, how high the floor of
## the loft lies, how wide the doorway is, and how deep the loft reaches from
## the back.
const BARNS := {
	"small": {"wide": 4.4, "long": 5.2, "eaves": 2.6, "loft": 1.95, "door": 2.0, "loft_deep": 2.2},
	"middle": {"wide": 5.4, "long": 6.6, "eaves": 2.95, "loft": 2.2, "door": 2.1, "loft_deep": 2.9},
	"large": {"wide": 6.6, "long": 8.2, "eaves": 3.3, "loft": 2.45, "door": 2.4, "loft_deep": 3.6},
}
## A log of a barn's wall: how deep, how high, and how far one lies over the
## last, which leaves a gap between them for the air to dry the hay. How far
## its ends stand out past the corner where it crosses another.
const LOG := Vector3(0.15, 0.25, 0.3)
const LOG_ENDS_OUT := 0.2
## How the colours of the drawings from afar are chosen: what each looks like
## from a few hundred metres, in the sun of an afternoon. sRGB.
const FAR_LOGS := Color(0.44, 0.39, 0.33)
const FAR_BOARDS := Color(0.42, 0.37, 0.31)
const FAR_DARK := Color(0.07, 0.06, 0.05)
const FAR_ROOFS := {"boards": Color(0.42, 0.4, 0.37), "shingles": Color(0.38, 0.37, 0.35), "tin": Color(0.46, 0.33, 0.24)}
const FAR_STONE := Color(0.52, 0.5, 0.46)
const FAR_LIME := Color(0.86, 0.85, 0.81)
const FAR_BROWN := Color(0.26, 0.19, 0.14)

## What is being built, if anything: the distance it is drawn to (a key of
## ALPINE_REACH), the block of ground it goes into, and its own dice.
var _alp_reach := ""
var _alp_block := Vector2i.ZERO
var _alp_own: RandomNumberGenerator
## What every corner that is built now is told in UV2: a tone of its own
## and how high the ground lies, see shaders/alpine_wood.gdshader.
var _alp_uv2 := Vector2(0.5, 0.0)
## The inside of the building that is being built, in its frame, if it has
## one: a face that lies in there is out of the light of the sky. See
## _alp_inside().
var _alp_room := AABB()
var _alp_room_xf := Transform3D()
## Whether the pieces say what they cost as they are built, and the count
## of their triangles by distance.
var _alp_tally := false
var _alp_count := {}


# --- What it is all built with -------------------------------------------------------


## Begins a piece that stands at `at` and is drawn as far as `reach` says:
## what follows goes into the meshes of its block. Returns its dice.
func _alp_begin(at: Vector2, reach := "near", salt := 0) -> RandomNumberGenerator:
	_alp_reach = reach
	_alp_block = Vector2i(floori(at.x / ALPINE_BLOCK), floori(at.y / ALPINE_BLOCK))
	_alp_uv2 = Vector2(0.5, ground_height(at.x, at.y))
	_alp_room = AABB()
	_alp_own = _dice(at, 1501 + salt)
	_alp_count = {}
	return _alp_own


## Ends the piece begun last, and says what it cost if the level asked.
func _alp_end(what: String, at: Vector2, colliders := 0) -> void:
	if _alp_tally:
		var counts := []
		for key: String in _alp_count:
			counts.append("%d %s" % [_alp_count[key], key])
		print("%s at (%.0f, %.0f): %s triangles, %d colliders" % [what, at.x, at.y, ", ".join(counts), colliders])
	_alp_reach = ""


## How many colliders the level has so far: what a piece added is the
## difference.
func _alp_colliders() -> int:
	return _body.get_child_count()


## While a piece is being built, all it is made of goes into the meshes of
## its block and its distance, whatever builds it; each corner is told what
## _alp_uv2 says.
func _tool(mat: String, flags: int, at: Vector3) -> SurfaceTool:
	if _alp_reach != "" and not flags & GLASS and not _moving:
		var st := _tool_named("|alpine %s %d %d/%s" % [_alp_reach, _alp_block.x, _alp_block.y, mat])
		st.set_uv2(_alp_uv2)
		return st
	return super(mat, flags, at)


func _tri(st: SurfaceTool, p: Array, n: Array, uv: Array, edge: Array = []) -> void:
	if _alp_reach != "":
		_alp_count[_alp_reach] = _alp_count.get(_alp_reach, 0) + 1
	super(st, p, n, uv, edge)


## Each block's mesh of a distance is drawn from as far and to as far as
## ALPINE_REACH says. Wire throws no shadow.
func _commit(zone_name: String, kind: String) -> void:
	super(zone_name, kind)
	if not kind.begins_with("alpine "):
		return
	var instance := _root.get_child(0) as MeshInstance3D
	var reach: Vector2 = ALPINE_REACH[kind.get_slice(" ", 1)]
	if reach.x > 0.0:
		instance.visibility_range_begin = reach.x
		instance.visibility_range_begin_margin = ALPINE_MARGIN
	if reach.y > 0.0:
		instance.visibility_range_end = reach.y
		instance.visibility_range_end_margin = ALPINE_MARGIN
	if kind.begins_with("alpine wire"):
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _surface(mat: String) -> String:
	if ALPINE_SURFACES.has(mat):
		return ALPINE_SURFACES[mat]
	return super(mat)


## What a face whose middle is at `spot` is told in UV2.x besides its tone:
## 4 if it lies inside the building, where the light of the sky hardly
## comes, see shaders/alpine_wood.gdshader. The inside is _alp_room, which
## takes in the inner faces of the walls and leaves out the outer ones.
func _alp_inside(spot: Vector3) -> float:
	if not _alp_room.has_volume():
		return 0.0
	return 4.0 if _alp_room.has_point(_alp_room_xf.affine_inverse() * spot) else 0.0


## A squared timber: a box `size` across in the frame `xf`, its grain along
## the axis `along` of that frame (0 for X, 1 for Y, 2 for Z). Each of its
## long faces shows a strip of the scan of its own, squeezed across by
## `squeeze`, and its ends show rings: both, or as `ends` says, 1 for the
## end towards -along and 2 for the other, 0 for neither where nothing sees
## them. `tone` is how light it is among the rest, from 0 to 1, and the dice
## say if it is less than nought. `rounded` shades its long faces as if its
## edges were rounded off, a log hewn by hand more than a sawn board. It is
## in nobody's way: a piece says itself what is.
func _alp_timber(mat: String, xf: Transform3D, size: Vector3, along := 2, tone := -1.0, squeeze := SQUEEZE, ends := 3, rounded := 0.0) -> void:
	if tone < 0.0:
		tone = _alp_own.randf()
	var st := _tool(mat, DETAIL | NO_COLLIDE, xf.origin)
	var half := size * 0.5
	var shift := Vector2(_alp_own.randf() * 9.0, _alp_own.randf() * 9.0)
	var grain: Vector3 = [Vector3.RIGHT, Vector3.UP, Vector3.BACK][along]
	for n: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var end := absf(n.dot(grain)) > 0.5
		if end and not ends & (2 if n.dot(grain) > 0.0 else 1):
			continue
		var up: Vector3 = grain if not end else (Vector3.UP if along != 1 else Vector3.BACK)
		var right := up.cross(n)
		var c := n * absf(n.dot(half))
		var r := right * absf(right.dot(half))
		var u := up * absf(up.dot(half))
		var normal := (xf.basis * n).normalized()
		var points := []
		var uvs := []
		var normals := []
		var across := (xf.basis * right).normalized()
		for p: Vector3 in [c - r - u, c + r - u, c + r + u, c - r + u]:
			points.append(xf * p)
			if end:
				uvs.append(Vector2(p.dot(right), -p.dot(up)))
				normals.append(normal)
			else:
				uvs.append(Vector2(p.dot(right) * squeeze + shift.x, -p.dot(up) + shift.y))
				normals.append((normal + across * signf(p.dot(right)) * rounded).normalized())
		st.set_uv2(Vector2(tone + (2.0 if end else 0.0) + _alp_inside(xf * c), _alp_uv2.y))
		var face := Vector2(r.length(), u.length()) * 2.0
		_quad(st, points, normals, uvs, [_edge(Vector2(0, 0), face), _edge(Vector2(1, 0), face), _edge(Vector2(1, 1), face), _edge(Vector2(0, 1), face)])
	st.set_uv2(_alp_uv2)


## Boards cut to `outline`, convex and counter-clockwise in the XY of the
## frame `xf` as seen from its +Z, `thick` thick along Z: a gable, a door
## with a slanted top. The boards stand up and down. With `collide` they are
## in the way, as wood.
func _alp_boarding(mat: String, outline: PackedVector2Array, thick: float, xf: Transform3D, tone := -1.0, collide := true) -> void:
	if tone < 0.0:
		tone = _alp_own.randf()
	var st := _tool(mat, DETAIL | NO_COLLIDE, xf.origin)
	var shift := Vector2(_alp_own.randf() * 9.0, _alp_own.randf() * 9.0)
	var count := outline.size()
	var middle := Vector2.ZERO
	for corner in outline:
		middle += corner / count
	for face: float in [1.0, -1.0]:
		var at := Vector3(middle.x, middle.y, face * thick * 0.5)
		st.set_uv2(Vector2(tone + _alp_inside(xf * at), _alp_uv2.y))
		var normal := xf.basis * Vector3(0, 0, face)
		for i in range(1, count - 1):
			var corners: Array[Vector2] = [outline[0], outline[i], outline[i + 1]]
			if face < 0.0:
				corners.reverse()
			var points := []
			var uvs := []
			for corner in corners:
				points.append(xf * Vector3(corner.x, corner.y, face * thick * 0.5))
				uvs.append(Vector2(corner.x * face, -corner.y) + shift)
			_tri(st, points, [normal, normal, normal], uvs)
	st.set_uv2(Vector2(tone + 2.0, _alp_uv2.y))
	var hull := PackedVector3Array()
	for i in count:
		var a := outline[i]
		var b := outline[(i + 1) % count]
		var normal := xf.basis * Vector3(b.y - a.y, a.x - b.x, 0).normalized()
		var run := a.distance_to(b)
		_quad(st, [xf * Vector3(a.x, a.y, -thick * 0.5), xf * Vector3(b.x, b.y, -thick * 0.5), xf * Vector3(b.x, b.y, thick * 0.5), xf * Vector3(a.x, a.y, thick * 0.5)],
			[normal, normal, normal, normal], [Vector2(0, thick), Vector2(run, thick), Vector2(run, 0), Vector2.ZERO])
		hull.append(xf * Vector3(a.x, a.y, thick * 0.5))
		hull.append(xf * Vector3(a.x, a.y, -thick * 0.5))
	st.set_uv2(_alp_uv2)
	if collide:
		var shape := ConvexPolygonShape3D.new()
		shape.points = hull
		_collide(shape, Transform3D(), _surface(mat))


## The same between two points: a timber `width` wide and `height` high
## whose grain runs from `from` to `to`, its height as near upright as it can
## be. With `collide` it is in the way, as wood.
func _alp_beam(mat: String, from: Vector3, to: Vector3, width: float, height := -1.0, tone := -1.0, collide := false) -> void:
	var size := Vector3(width, width if height < 0.0 else height, from.distance_to(to))
	var xf := Transform3D(_along(to - from), (from + to) * 0.5)
	_alp_timber(mat, xf, size, 2, tone)
	if collide:
		_collide_box(xf, size, _surface(mat))


## A round pole from `from` to `to`, of bark or of wood, tapering to
## `top_radius` if that is given; `sides` round. With `collide` it is in the
## way.
func _alp_pole(mat: String, from: Vector3, to: Vector3, radius: float, top_radius := -1.0, sides := 7, collide := false) -> void:
	_cylinder(mat, Transform3D(_up_along(to - from), from), radius, from.distance_to(to), DETAIL | NO_COLLIDE, top_radius, sides)
	if collide:
		_collide_cylinder(Transform3D(_up_along(to - from), (from + to) * 0.5), maxf(radius, top_radius), from.distance_to(to), _surface(mat))


## A stone as it was found: a block `size` across in the frame `xf` (its
## middle), its corners pushed about by the dice so that no two are alike
## and none is a box.
func _alp_stone(mat: String, xf: Transform3D, size: Vector3) -> void:
	var st := _tool(mat, DETAIL | NO_COLLIDE, xf.origin)
	var half := size * 0.5
	var corners: Array[Vector3] = []
	for i in 8:
		var sign := Vector3(1.0 if i & 1 else -1.0, 1.0 if i & 2 else -1.0, 1.0 if i & 4 else -1.0)
		var squeeze := Vector3(_alp_own.randf_range(0.62, 1.0), _alp_own.randf_range(0.75, 1.0), _alp_own.randf_range(0.62, 1.0))
		# The top is the narrower: a stone lies on its broad side.
		if sign.y > 0.0:
			squeeze *= Vector3(0.82, 1.0, 0.82)
		corners.append(sign * half * squeeze)
	# Each face as four of those corners, counter-clockwise from outside. It
	# lies on what it lies on: its underside is not seen.
	for face: Array in [[1, 3, 7, 5], [4, 6, 2, 0], [2, 6, 7, 3], [4, 5, 7, 6], [1, 0, 2, 3]]:
		var p: Array[Vector3] = []
		for i: int in face:
			p.append(xf * corners[i])
		var normal := (p[1] - p[0]).cross(p[3] - p[0]).normalized()
		var right := (p[1] - p[0]).normalized()
		var up := normal.cross(right)
		var uvs := []
		for q in p:
			uvs.append(Vector2(q.dot(right), -q.dot(up)))
		var size2 := Vector2(p[0].distance_to(p[1]), p[0].distance_to(p[3]))
		_quad(st, p, [normal, normal, normal, normal], uvs, [_edge(Vector2(0, 0), size2), _edge(Vector2(1, 0), size2), _edge(Vector2(1, 1), size2), _edge(Vector2(0, 1), size2)])


## A heap of hay over the rectangle `size` (x and z) round the middle `at` in
## the frame `xf`, `high` in its middle and nothing at its rim: a dome that
## the dice make lumpy. It is in nobody's way unless `collide` says so, and
## then as a box of two thirds its height.
func _alp_heap(xf: Transform3D, at: Vector3, size: Vector2, high: float, collide := false, cells := 4) -> void:
	var st := _tool(HAY, DETAIL | NO_COLLIDE, xf * at)
	var lumps := Vector4(_alp_own.randf_range(0.0, TAU), _alp_own.randf_range(0.0, TAU), _alp_own.randf_range(2.0, 4.0), _alp_own.randf_range(-0.25, 0.25))
	var height := func(u: float, v: float) -> float:
		var r := minf(Vector2(u, v).length(), 1.0)
		var dome := pow(maxf(1.0 - r * r, 0.0), 0.55)
		return high * dome * (1.0 + 0.12 * sin(u * lumps.z + lumps.x) * cos(v * lumps.z + lumps.y)) + lumps.w * u * high * 0.3 * dome
	var spot := func(i: int, j: int) -> Vector3:
		var u := -1.0 + 2.0 * i / cells
		var v := -1.0 + 2.0 * j / cells
		# The corners of the rectangle are pulled in to round it off.
		var round_off := 1.0 - 0.18 * absf(u * v)
		return at + Vector3(u * size.x * 0.5 * round_off, height.call(u * round_off, v * round_off) - 0.02, v * size.y * 0.5 * round_off)
	for i in cells:
		for j in cells:
			var p: Array[Vector3] = [spot.call(i, j + 1), spot.call(i + 1, j + 1), spot.call(i + 1, j), spot.call(i, j)]
			var normals := []
			var uvs := []
			for q: Vector3 in p:
				var w := xf * q
				normals.append(xf.basis * _alp_heap_normal(q, at, size, high))
				uvs.append(Vector2(w.x + w.y * 0.3, w.z - w.y * 0.3))
			var world: Array[Vector3] = []
			for q in p:
				world.append(xf * q)
			_quad(st, world, normals, uvs)
	if collide:
		_collide_box(xf * Transform3D(Basis(), at + Vector3(0, high * 0.33, 0)), Vector3(size.x * 0.75, high * 0.66, size.y * 0.75), "soft")


## Which way a heap faces at the spot `q`: as a dome of that size does.
func _alp_heap_normal(q: Vector3, at: Vector3, size: Vector2, high: float) -> Vector3:
	var d := q - at
	return Vector3(d.x * 2.0 * high / (size.x * size.x * 0.25), 1.0, d.z * 2.0 * high / (size.y * size.y * 0.25)).normalized()


# --- From afar -----------------------------------------------------------------------


## A face of a piece as it is drawn from afar: four corners counter-clockwise
## seen from outside, each with its colour (or one for all).
func _far_quad(p: Array, colours: Array) -> void:
	var st := _tool_named("|alpine far %d %d/%s" % [_alp_block.x, _alp_block.y, FAR])
	var normal: Vector3 = ((p[1] as Vector3) - (p[0] as Vector3)).cross((p[3] as Vector3) - (p[0] as Vector3)).normalized()
	for i: int in [0, 2, 1, 0, 3, 2]:
		st.set_color(colours[i] if colours.size() > 1 else colours[0])
		st.set_normal(normal)
		st.set_uv(Vector2.ZERO)
		st.add_vertex(p[i])
	_alp_count["far"] = _alp_count.get("far", 0) + 2


func _far_tri(p: Array, colour: Color) -> void:
	var st := _tool_named("|alpine far %d %d/%s" % [_alp_block.x, _alp_block.y, FAR])
	var normal: Vector3 = ((p[1] as Vector3) - (p[0] as Vector3)).cross((p[2] as Vector3) - (p[0] as Vector3)).normalized()
	for i: int in [0, 2, 1]:
		st.set_color(colour)
		st.set_normal(normal)
		st.set_uv(Vector2.ZERO)
		st.add_vertex(p[i])
	_alp_count["far"] = _alp_count.get("far", 0) + 1


## A box from afar: `size` across round the middle `at` of the frame `xf`, its
## sides `side`, darker towards the foot by `foot`, and its top `top`; no
## bottom.
func _far_box(xf: Transform3D, at: Vector3, size: Vector3, side: Color, top: Color, foot := 1.0) -> void:
	var h := size * 0.5
	var low := side * foot
	low.a = 1.0
	var c := func(x: float, y: float, z: float) -> Vector3: return xf * (at + Vector3(x * h.x, y * h.y, z * h.z))
	_far_quad([c.call(-1, -1, 1), c.call(1, -1, 1), c.call(1, 1, 1), c.call(-1, 1, 1)], [low, low, side, side])
	_far_quad([c.call(1, -1, -1), c.call(-1, -1, -1), c.call(-1, 1, -1), c.call(1, 1, -1)], [low, low, side, side])
	_far_quad([c.call(1, -1, 1), c.call(1, -1, -1), c.call(1, 1, -1), c.call(1, 1, 1)], [low, low, side, side])
	_far_quad([c.call(-1, -1, -1), c.call(-1, -1, 1), c.call(-1, 1, 1), c.call(-1, 1, -1)], [low, low, side, side])
	_far_quad([c.call(-1, 1, 1), c.call(1, 1, 1), c.call(1, 1, -1), c.call(-1, 1, -1)], [top])


## A pitched roof from afar, its ridge along Z of the frame `xf`: the ridge
## `ridge` high, its eaves `eaves` high and `half_wide` out from the middle
## at either side, `half_long` out along it; its top `top`, and under it the
## dark of its overhang.
func _far_roof(xf: Transform3D, half_wide: float, half_long: float, eaves: float, ridge: float, top: Color) -> void:
	var under := top * 0.35
	under.a = 1.0
	for side: float in [-1.0, 1.0]:
		var eave_front := xf * Vector3(side * half_wide, eaves, half_long)
		var eave_back := xf * Vector3(side * half_wide, eaves, -half_long)
		var ridge_front := xf * Vector3(0, ridge, half_long)
		var ridge_back := xf * Vector3(0, ridge, -half_long)
		var drop := xf.basis * Vector3(0, -0.18, 0)
		if side > 0.0:
			_far_quad([eave_front, eave_back, ridge_back, ridge_front], [top])
			_far_quad([eave_back + drop, eave_front + drop, ridge_front + drop, ridge_back + drop], [under])
		else:
			_far_quad([eave_back, eave_front, ridge_front, ridge_back], [top])
			_far_quad([eave_front + drop, eave_back + drop, ridge_back + drop, ridge_front + drop], [under])


# --- Hay barns -----------------------------------------------------------------------


## A hay barn (Heustadel) on the meadow at `at`, its doorway in the gable that
## faces `yaw_deg` (0 looks along +Z). `size` is "small", "middle" or
## "large", see BARNS. Its walls are "logs", squared and laid crosswise with
## a gap between one and the next for the hay to dry, or "boards", a frame
## sheeted with boards that leave a slot every few; its roof "boards" laid
## from the ridge down and weighed with poles and stones, "shingles" or
## "tin", corrugated and rusting; it stands on "stones" under its corners or
## on wooden "blocks". Whatever is left empty the dice of the spot decide.
##
## It is cover in an open valley, and it is to be gone into: the doorway is
## two metres and more wide, and both wings stand open; inside lies hay on
## the floor, and over the back a loft with more of it, which in a large
## barn a steep stair leads up to, with a hatch in the gable to look out
## of. Every barn has a hatch in one long side at the height of an eye, and
## between the logs or the boards whoever is inside looks out and shoots,
## while a shot from outside stops on whatever it hits of the wall. On ground
## that is not level it stands level, on taller stones downhill, and a ramp
## of boards leads up to its door where the floor lies above the meadow.
func hay_barn(at: Vector2, yaw_deg: float, size := "middle", walls := "", roof := "", footing := "") -> void:
	var own := _alp_begin(at, "near")
	var colliders := _alp_colliders()
	var spec: Dictionary = BARNS[size]
	if walls == "":
		walls = "logs" if own.randf() < 0.65 else "boards"
	if roof == "":
		roof = ["boards", "boards", "shingles", "tin", "tin"][own.randi() % 5]
	if footing == "":
		footing = "stones" if own.randf() < 0.7 else "blocks"
	var wide: float = spec.wide
	var long: float = spec.long
	var turn := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	# The floor lies level, a hand over the highest of its corners.
	var highest := -INF
	var lowest := INF
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var spot := turn * Vector3(corner.x * (wide * 0.5 + 0.2), 0, corner.y * (long * 0.5 + 0.2))
		var height := ground_height(at.x + spot.x, at.y + spot.z)
		highest = maxf(highest, height)
		lowest = minf(lowest, height)
	var floor_y := highest + (0.32 if footing == "stones" else 0.4)
	var xf := Transform3D(turn, Vector3(at.x, floor_y, at.y))
	var pitch := {"boards": 24.0, "shingles": 33.0, "tin": 27.0}[roof] as float
	var over_eave := 0.75 if size != "large" else 0.9
	var over_gable := 0.6 if size != "large" else 0.75
	var dim := {
		"wide": wide, "long": long, "eaves": spec.eaves, "door": spec.door, "loft": spec.loft, "loft_deep": spec.loft_deep,
		"hatch_side": 1.0 if own.randf() < 0.5 else -1.0, "hatch_at": own.randf_range(-0.2, 0.2) * long,
		"stair": size == "large", "over_gable": over_gable,
	}
	# Inside: within the inner faces of the walls, up to under the ridge.
	_alp_room_xf = xf
	_alp_room = AABB(Vector3(-wide * 0.5 + 0.025, -0.02, -long * 0.5 + 0.025), Vector3(wide - 0.05, float(spec.eaves) + wide * 0.5 * tan(deg_to_rad(pitch)) + 0.6, long - 0.05))
	var eaves: float
	if walls == "logs":
		eaves = _barn_logs(xf, dim)
	else:
		eaves = _barn_boards(xf, dim)
	dim.eaves = eaves
	_barn_footing(xf, dim, footing)
	var ridge := _alp_roof(xf, wide, long, eaves, pitch, over_eave, over_gable, roof)
	_barn_gables(xf, dim, pitch, walls)
	_barn_door(xf, dim)
	_barn_inside(xf, dim, pitch)
	_barn_ramp(xf, dim, at)
	# From afar: the walls on their footing, the gables, the dark of the
	# doorway and the roof.
	var wall_colour := FAR_LOGS if walls == "logs" else FAR_BOARDS
	var foot := lowest - floor_y - 0.1
	_far_box(xf, Vector3(0, (eaves + foot) * 0.5, 0), Vector3(wide, eaves - foot, long), wall_colour, wall_colour, 0.7)
	var roof_rise := tan(deg_to_rad(pitch))
	for end: float in [-1.0, 1.0]:
		var z := end * long * 0.5
		var left := xf * Vector3(-wide * 0.5 * end, eaves, z)
		var right := xf * Vector3(wide * 0.5 * end, eaves, z)
		_far_tri([left, right, xf * Vector3(0, eaves + wide * 0.5 * roof_rise, z)], wall_colour)
	var door: float = spec.door
	_far_quad([xf * Vector3(-door * 0.5, 0.0, long * 0.5 + 0.03), xf * Vector3(door * 0.5, 0.0, long * 0.5 + 0.03), xf * Vector3(door * 0.5, 2.1, long * 0.5 + 0.03), xf * Vector3(-door * 0.5, 2.1, long * 0.5 + 0.03)], [FAR_DARK])
	var eave_drop := over_eave * roof_rise
	_far_roof(xf, wide * 0.5 + over_eave, long * 0.5 + over_gable, eaves + 0.16 - eave_drop, ridge, FAR_ROOFS[roof])
	_alp_end("hay_barn %s, %s, %s, %s" % [size, walls, roof, footing], at, _alp_colliders() - colliders)


## The walls of a barn of logs in its frame `xf`, its floor at nought: each
## pair of walls lies half a log higher than the other, so that the logs
## cross at the corners, where their ends stand out. Returns how high the
## walls are: the top of the logs of the long sides, which the roof rests on.
func _barn_logs(xf: Transform3D, dim: Dictionary) -> float:
	var wide: float = dim.wide
	var long: float = dim.long
	var door: float = dim.door
	var hw := wide * 0.5
	var hl := long * 0.5
	var courses := int(round((float(dim.eaves) + 0.18 - LOG.y) / LOG.z)) + 1
	var eaves := -0.18 + (courses - 1) * LOG.z + LOG.y
	# The hatch in a long side: two logs taken out at the height of an eye.
	var hatch_side: float = dim.hatch_side
	var hatch_at: float = dim.hatch_at
	var hatch := Rect2(hatch_at - 0.42, 1.27, 0.84, 0.65)
	for k in courses:
		var low := -0.18 + k * LOG.z
		var top := k == courses - 1
		# The long sides, and their top logs run on to carry the roof over
		# the gables.
		var reach := hl + (float(dim.over_gable) if top else LOG_ENDS_OUT)
		for side: float in [-1.0, 1.0]:
			var x := side * (hw - LOG.x * 0.5)
			var pieces: Array[Vector2] = [Vector2(-reach - _log_end(top), reach + _log_end(top))]
			if side == hatch_side and low + LOG.y > hatch.position.y + 0.01 and low < hatch.end.y - 0.01:
				pieces = [Vector2(pieces[0].x, hatch.position.x), Vector2(hatch.end.x, pieces[0].y)]
			for i in pieces.size():
				var piece := pieces[i]
				# A log cut for the hatch has its cut end in the frame of it.
				var ends := 3 if pieces.size() == 1 else (1 if i == 0 else 2)
				_barn_log(xf, Vector3(x, low + LOG.y * 0.5, (piece.x + piece.y) * 0.5), Vector3(LOG.x, LOG.y, piece.y - piece.x), 2, ends)
		if top:
			break
		# The gables, half a log higher, the door through the front one.
		var gable_low := low + LOG.z * 0.5
		for end: float in [-1.0, 1.0]:
			var z := end * (hl - LOG.x * 0.5)
			var pieces: Array[Vector2] = [Vector2(-hw - LOG_ENDS_OUT - _log_end(false), hw + LOG_ENDS_OUT + _log_end(false))]
			if end > 0.0 and gable_low < 2.0:
				pieces = [Vector2(pieces[0].x, -door * 0.5 - 0.07), Vector2(door * 0.5 + 0.07, pieces[0].y)]
			for i in pieces.size():
				var piece := pieces[i]
				# And one cut for the door in its post.
				var ends := 3 if pieces.size() == 1 else (1 if i == 0 else 2)
				_barn_log(xf, Vector3((piece.x + piece.y) * 0.5, gable_low + LOG.y * 0.5, z), Vector3(piece.y - piece.x, LOG.y, LOG.x), 0, ends)
	# The posts either side of the doorway hold the ends of the logs cut for
	# it, and two more those of the hatch.
	var door_top := -0.18 + LOG.z * 0.5
	while door_top < 2.0:
		door_top += LOG.z
	dim.door_top = door_top
	for x: float in [-1.0, 1.0]:
		var post := xf * Transform3D(Basis(), Vector3(x * (door * 0.5 + 0.07), (door_top + 0.1) * 0.5 - 0.05, hl - LOG.x * 0.5))
		_alp_timber(LARCH, post, Vector3(0.14, door_top + 0.1, LOG.x + 0.04), 1)
		_collide_box(post, Vector3(0.14, door_top + 0.1, LOG.x + 0.04), "wood")
		var jamb := xf * Transform3D(Basis(), Vector3(hatch_side * (hw - LOG.x * 0.5), hatch.get_center().y, hatch_at + x * (hatch.size.x * 0.5 + 0.05)))
		_alp_timber(LARCH, jamb, Vector3(LOG.x + 0.03, hatch.size.y + 0.1, 0.1), 1)
	dim.hatch = hatch
	_barn_shutter(xf, Vector3(hatch_side * hw, hatch.end.y, hatch_at), hatch_side, hatch.size)
	return eaves


## One log of a barn: a timber along `along` of the frame `xf` round
## `middle`, `size` across, in the way of whoever walks and whatever is shot.
## It was hewn by hand: a little higher or lower than the next, lying a
## little in or out, and so the gaps are not all as wide.
func _barn_log(xf: Transform3D, middle: Vector3, size: Vector3, along: int, ends := 3) -> void:
	var hewn := Vector3(_alp_own.randf_range(-0.01, 0.01), _alp_own.randf_range(-0.012, 0.012), _alp_own.randf_range(-0.01, 0.01))
	hewn[along] = 0.0
	var high := size.y * _alp_own.randf_range(0.92, 1.04)
	var frame := xf * Transform3D(Basis(), middle + hewn + Vector3(0, (high - size.y) * 0.5, 0))
	size.y = high
	_alp_timber(LARCH, frame, size, along, -1.0, SQUEEZE, ends, 0.55)
	_collide_box(frame, size, "wood")


## How much further than the others the end of a log stands out past its
## corner: the top logs, which carry the roof, all as far.
func _log_end(top: bool) -> float:
	return 0.0 if top else _alp_own.randf_range(-0.07, 0.07)


## The walls of a barn of boards in its frame `xf`: a frame of squared timber
## on a sill, sheeted outside with boards, tight below a rail at the height
## of a hip and above it in runs of three boards with a slot between one run
## and the next. Returns how high the walls are.
func _barn_boards(xf: Transform3D, dim: Dictionary) -> float:
	var wide: float = dim.wide
	var long: float = dim.long
	var door: float = dim.door
	var eaves: float = dim.eaves
	var hw := wide * 0.5
	var hl := long * 0.5
	var stud := 0.15
	var rail := 1.05
	var door_top := 2.15
	dim.door_top = door_top
	var hatch_side: float = dim.hatch_side
	var hatch_at: float = dim.hatch_at
	# The frame: sills, posts at the corners and by the door, and the plates
	# the roof rests on, which run on under its overhang at the gables.
	var inner := Vector2(hw - 0.03 - stud * 0.5, hl - 0.03 - stud * 0.5)
	var plate := long + 2.0 * float(dim.over_gable)
	for side: float in [-1.0, 1.0]:
		_alp_timber(LARCH, xf * Transform3D(Basis(), Vector3(side * inner.x, -0.1, 0)), Vector3(stud, 0.17, long - 0.06), 2)
		_alp_timber(LARCH, xf * Transform3D(Basis(), Vector3(0, -0.1, side * inner.y)), Vector3(wide - 0.06, 0.17, stud), 0)
		_alp_timber(LARCH, xf * Transform3D(Basis(), Vector3(side * inner.x, eaves - 0.08, 0)), Vector3(stud, 0.16, plate), 2)
		_alp_timber(LARCH, xf * Transform3D(Basis(), Vector3(0, eaves - 0.08, side * inner.y)), Vector3(wide - 0.06, 0.16, stud), 0)
		for z: float in [-1.0, 1.0]:
			_alp_timber(LARCH, xf * Transform3D(Basis(), Vector3(side * inner.x, eaves * 0.5, z * inner.y)), Vector3(stud, eaves, stud), 1)
		var post := xf * Transform3D(Basis(), Vector3(side * (door * 0.5 + stud * 0.5), door_top * 0.5, inner.y))
		_alp_timber(LARCH, post, Vector3(stud, door_top, stud), 1)
		_collide_box(post, Vector3(stud, door_top, stud), "wood")
	_alp_timber(LARCH, xf * Transform3D(Basis(), Vector3(0, door_top + 0.08, inner.y)), Vector3(door + stud * 2.0, 0.16, stud), 0)
	# The sheeting of each wall, as the middle of the wall, the way along it
	# and the way out of it.
	var run := 0.6
	var slot := 0.05
	for wall: Array in [
		[Vector3(hw - 0.015, 0, 0), Vector3.BACK, Vector3.RIGHT],
		[Vector3(-hw + 0.015, 0, 0), Vector3.FORWARD, Vector3.LEFT],
		[Vector3(0, 0, -hl + 0.015), Vector3.RIGHT, Vector3.FORWARD],
		[Vector3(0, 0, hl - 0.015), Vector3.LEFT, Vector3.BACK],
	]:
		var middle: Vector3 = wall[0]
		var way: Vector3 = wall[1]
		var out: Vector3 = wall[2]
		var length := long if absf(out.x) > 0.5 else wide
		var front := out.z > 0.5
		var frame := Basis(way, Vector3.UP, way.cross(Vector3.UP))
		# Along the wall it is sheeted from corner to corner, or from either
		# corner to the door.
		var spans: Array[Vector2] = [Vector2(-length * 0.5, length * 0.5)]
		if front:
			spans = [Vector2(-length * 0.5, -door * 0.5), Vector2(door * 0.5, length * 0.5)]
		var hatch_wall := absf(out.x - hatch_side) < 0.1
		for span in spans:
			# Tight below the rail.
			var panel := xf * Transform3D(frame, middle + way * (span.x + span.y) * 0.5 + Vector3.UP * (rail - 0.18) * 0.5)
			_alp_timber(LARCH, panel, Vector3(span.y - span.x, rail + 0.18, 0.03), 1, -1.0, 1.0)
			_collide_box(panel, Vector3(span.y - span.x, rail + 0.18, 0.06), "wood")
			# Above it the runs: as many as fit, and the slots between them.
			var count := maxi(int(round((span.y - span.x + slot) / (run + slot))), 1)
			var each := (span.y - span.x - (count - 1) * slot) / count
			var nearest := -1
			if hatch_wall:
				var best := INF
				for i in count:
					var along := (middle + way * (span.x + each * 0.5 + i * (each + slot))).z
					if absf(along - hatch_at) < best:
						best = absf(along - hatch_at)
						nearest = i
			for i in count:
				var at := span.x + each * 0.5 + i * (each + slot)
				var pieces: Array[Vector2] = [Vector2(rail, eaves)]
				if i == nearest:
					# The hatch is this run left out at the height of an eye.
					pieces = [Vector2(rail, 1.27), Vector2(1.92, eaves)]
					var hatch_middle := (middle + way * at).z
					dim.hatch_at = hatch_middle
					dim.hatch = Rect2(hatch_middle - each * 0.5, 1.27, each, 0.65)
				for piece in pieces:
					var board := xf * Transform3D(frame, middle + way * at + Vector3.UP * (piece.x + piece.y) * 0.5)
					_alp_timber(LARCH, board, Vector3(each, piece.y - piece.x, 0.03), 1, -1.0, 1.0)
					_collide_box(board, Vector3(each, piece.y - piece.x, 0.06), "wood")
		if front:
			# Over the door, tight.
			var over := xf * Transform3D(frame, middle + Vector3.UP * (door_top + eaves) * 0.5)
			_alp_timber(LARCH, over, Vector3(door, eaves - door_top, 0.03), 1, -1.0, 1.0)
			_collide_box(over, Vector3(door, eaves - door_top, 0.06), "wood")
	var hatch: Rect2 = dim.hatch
	for x: float in [-1.0, 1.0]:
		var jamb := xf * Transform3D(Basis(), Vector3(hatch_side * inner.x, hatch.get_center().y, hatch.get_center().x + x * (hatch.size.x * 0.5 + 0.05)))
		_alp_timber(LARCH, jamb, Vector3(stud, hatch.size.y + 0.1, 0.1), 1)
	_barn_shutter(xf, Vector3(hatch_side * hw, hatch.end.y, hatch.get_center().x), hatch_side, hatch.size)
	return eaves


## The shutter of a hatch in the side `side` of a barn (-1 its left, 1 its
## right), whose top is at `top`: boards on two ledges, hung from the top
## and propped open on a stick, or swung back flat against the wall.
func _barn_shutter(xf: Transform3D, top: Vector3, side: float, size: Vector2) -> void:
	var out := Vector3(side, 0, 0)
	var open := _alp_own.randf_range(0.9, 1.25)
	var hang := xf * Transform3D(Basis(Vector3.BACK, side * open), top + out * 0.03)
	_alp_timber(LARCH, hang * Transform3D(Basis(), Vector3(0, -size.y * 0.5, 0)), Vector3(0.035, size.y, size.x + 0.06), 1, -1.0, 1.0)
	_alp_timber(LARCH, hang * Transform3D(Basis(), Vector3(-0.03, -size.y * 0.5, 0)), Vector3(0.03, 0.09, size.x - 0.04), 2)
	# The stick it rests on, from the sill of the hatch.
	var tip := hang * Vector3(0, -size.y + 0.1, 0)
	var foot := xf * (top + Vector3(0, -size.y, 0) + out * 0.08)
	_alp_pole(LARCH, foot, tip, 0.018, -1.0, 4)
	_collide_box(hang * Transform3D(Basis(), Vector3(0, -size.y * 0.5, 0)), Vector3(0.04, size.y, size.x + 0.06), "wood")


## What a barn stands on: a stone or a block of wood under each corner and
## under the middle of each long side, from the ground to its sill. Where
## the ground falls away so far that the barn would stand on stilts, it
## stands on a plinth of stones laid dry all round instead, its foot
## following the ground.
func _barn_footing(xf: Transform3D, dim: Dictionary, footing: String) -> void:
	var hw := float(dim.wide) * 0.5
	var hl := float(dim.long) * 0.5
	var top := -0.17
	var spots: Array[Vector2] = []
	for side: float in [-1.0, 1.0]:
		for z: float in [-1.0, 0.0, 1.0]:
			spots.append(Vector2(side * (hw - 0.08), z * (hl - 0.08)))
	var lowest := INF
	for spot in spots:
		var world := xf * Vector3(spot.x, 0, spot.y)
		lowest = minf(lowest, ground_height(world.x, world.z) - xf.origin.y)
	if top - lowest > 0.75:
		# A plinth: each side in lengths of a metre or two, each from a hand
		# under the ground at its lower end up to the sill.
		for wall: Array in [[Vector2(-hw, hl), Vector2(hw, hl)], [Vector2(hw, hl), Vector2(hw, -hl)], [Vector2(hw, -hl), Vector2(-hw, -hl)], [Vector2(-hw, -hl), Vector2(-hw, hl)]]:
			var from: Vector2 = wall[0]
			var to: Vector2 = wall[1]
			var lengths := maxi(int(round(from.distance_to(to) / 1.6)), 1)
			var way := (to - from).normalized()
			for i in lengths:
				var a := from.lerp(to, float(i) / lengths)
				var b := from.lerp(to, float(i + 1) / lengths)
				var low := INF
				for spot: Vector2 in [a, b]:
					var world := xf * Vector3(spot.x, 0, spot.y)
					low = minf(low, ground_height(world.x, world.z) - xf.origin.y)
				var high := top - low + 0.2
				var middle := (a + b) * 0.5 - Vector2(way.y, -way.x) * 0.22
				var frame := xf * Transform3D(Basis(Vector3.UP, atan2(way.x, way.y)), Vector3(middle.x, top - high * 0.5, middle.y))
				_alp_timber(STONE, frame, Vector3(0.5, high, a.distance_to(b) + 0.5), 2, 0.5, 1.0)
	else:
		for spot in spots:
			var world := xf * Vector3(spot.x, 0, spot.y)
			var below := ground_height(world.x, world.z) - xf.origin.y
			var high := top - below + 0.15
			var middle := Vector3(spot.x, top - high * 0.5, spot.y)
			if footing == "stones":
				var size := Vector3(_alp_own.randf_range(0.45, 0.62), high, _alp_own.randf_range(0.45, 0.62))
				_alp_stone(ROCK, xf * Transform3D(Basis(Vector3.UP, _alp_own.randf_range(-0.4, 0.4)), middle), size)
			else:
				var block := xf * Transform3D(Basis(Vector3.UP, _alp_own.randf_range(-0.2, 0.2)), middle)
				_alp_timber(LARCH, block, Vector3(0.3, high, 0.3), 1, _alp_own.randf_range(0.0, 0.4))
	# The floor and what is under it are one block to whoever walks and
	# shoots, from the sill down into the ground.
	var depth := -lowest + 0.3
	_collide_box(xf * Transform3D(Basis(), Vector3(0, -depth * 0.5, 0)), Vector3(hw * 2.0, depth, hl * 2.0), "wood")


## A roof over walls `wide` across and `long` along the Z of the frame `xf`,
## which rest at `eaves` over its floor: rafters from the walls up to the
## ridge, `pitch_deg` steep, standing `over_eave` out over the long sides and
## `over_gable` past the gables, boarded, and covered with what `cover`
## says: "boards" weighed with poles and stones, "shingles" or "tin".
## Returns how high the top of the ridge is.
func _alp_roof(xf: Transform3D, wide: float, long: float, eaves: float, pitch_deg: float, over_eave: float, over_gable: float, cover: String, rafter_gap := 1.4) -> float:
	var pitch := deg_to_rad(pitch_deg)
	var hw := wide * 0.5
	var reach := long * 0.5 + over_gable
	var rafter := Vector2(0.09, 0.12)
	var deck := 0.025
	var skin := {"boards": 0.0, "shingles": 0.04, "tin": 0.015}[cover] as float
	# Down the slope from the ridge, as it lies on the rafters' undersides.
	var slope := (hw + over_eave) / cos(pitch)
	var apex := Vector3(0, eaves + hw * tan(pitch), 0)
	for side: float in [-1.0, 1.0]:
		var down := Vector3(side * cos(pitch), -sin(pitch), 0)
		var out := Vector3(side * sin(pitch), cos(pitch), 0)
		var up_slope := -down
		var along := up_slope.cross(out)
		# A frame for what lies on the slope: X up it, Y out of it, and Z along
		# the ridge, so that whatever is laid there has its V down the slope.
		var lay := Basis(up_slope, out, along)
		var rafters := maxi(int(ceil(reach * 2.0 / rafter_gap)), 2)
		for i in rafters + 1:
			var z := -reach + 0.06 + (reach * 2.0 - 0.12) * i / rafters
			var middle := apex + down * (slope * 0.5) + out * (rafter.y * 0.5) + Vector3(0, 0, z)
			_alp_timber(LARCH, xf * Transform3D(lay, middle), Vector3(slope, rafter.y, rafter.x), 0, -1.0, SQUEEZE, 2)
		# The boards that lie on the rafters, from the ridge to the eaves, and
		# what covers them.
		var deck_middle := apex + down * (slope * 0.5 + 0.02) + out * (rafter.y + deck * 0.5) + Vector3.ZERO
		_alp_timber(LARCH, xf * Transform3D(lay, deck_middle), Vector3(slope + 0.04, deck, reach * 2.0), 0, _alp_own.randf_range(0.3, 0.7), 1.0)
		if skin > 0.0:
			var skin_middle := apex + down * (slope * 0.5 + 0.03) + out * (rafter.y + deck + skin * 0.5)
			_alp_timber(SHINGLES if cover == "shingles" else TIN, xf * Transform3D(lay, skin_middle), Vector3(slope + 0.06, skin, reach * 2.0 + 0.04), 0, 0.5, 1.0)
		# To whoever shoots the roof is one slab a side.
		var whole := apex + down * (slope * 0.5) + out * (rafter.y + 0.06)
		_collide_box(xf * Transform3D(lay, whole), Vector3(slope, 0.14, reach * 2.0), "wood" if cover != "tin" else "metal")
		# The boards along the gables that keep the wind from under the roof.
		for end: float in [-1.0, 1.0]:
			var verge := apex + down * (slope * 0.5) + out * (rafter.y + deck - 0.05) + Vector3(0, 0, end * (reach + 0.015))
			_alp_timber(LARCH, xf * Transform3D(lay, verge), Vector3(slope + 0.04, 0.22, 0.03), 0, -1.0, 1.0)
		if cover == "boards":
			# Poles laid across the boards, and stones on them.
			for share: float in [0.3, 0.78]:
				var pole_at := apex + down * (slope * share) + out * (rafter.y + deck + 0.05)
				_alp_pole(LARCH, xf * (pole_at + Vector3(0, 0, -reach + 0.1)), xf * (pole_at + Vector3(0, 0, reach - 0.1)), 0.05, -1.0, 5)
				var stones := int(reach * 2.0 / 1.5) if share > 0.5 else 0
				for s in stones:
					var z := -reach + 0.5 + (reach * 2.0 - 1.0) * (s + _alp_own.randf_range(0.2, 0.8)) / stones
					var size := Vector3(_alp_own.randf_range(0.22, 0.34), _alp_own.randf_range(0.13, 0.2), _alp_own.randf_range(0.2, 0.3))
					var stone_at := apex + down * (slope * share - 0.12) + out * (rafter.y + deck + size.y * 0.45)
					_alp_stone(ROCK, xf * Transform3D(lay * Basis(Vector3.UP, _alp_own.randf_range(-0.5, 0.5)), stone_at + Vector3(0, 0, z)), size)
	# The ridge: two boards that meet over it, or a cap of sheet.
	var top := apex + Vector3(0, (rafter.y + deck + skin) / cos(pitch), 0)
	for side: float in [-1.0, 1.0]:
		var down := Vector3(side * cos(pitch), -sin(pitch), 0)
		var out := Vector3(side * sin(pitch), cos(pitch), 0)
		var lay := Basis(-down, out, (-down).cross(out))
		var wing := 0.2
		_alp_timber(TIN if cover == "tin" else LARCH, xf * Transform3D(lay, top + down * (wing * 0.5 - 0.02) + out * 0.015), Vector3(wing, 0.03, reach * 2.0 + 0.06), 0, -1.0, 1.0)
	return top.y + 0.03


## The gables of a barn above its walls: boards from the top log or plate up
## under the roof, tight, with the hatch of the loft in the back one of a
## barn that has a stair.
func _barn_gables(xf: Transform3D, dim: Dictionary, pitch_deg: float, _walls: String) -> void:
	var hw := float(dim.wide) * 0.5
	var hl := float(dim.long) * 0.5
	var eaves: float = dim.eaves
	var rise := tan(deg_to_rad(pitch_deg))
	var base := eaves - LOG.z * 0.5 - 0.02
	for end: float in [-1.0, 1.0]:
		# Seen from outside, counter-clockwise: its frame faces out of the
		# gable.
		var face := Basis(Vector3(end, 0, 0), Vector3.UP, Vector3(0, 0, end))
		var frame := xf * Transform3D(face, Vector3(0, 0, end * (hl - 0.035)))
		var ridge := eaves + hw * rise
		var polygons: Array[PackedVector2Array] = []
		if dim.stair and end < 0.0:
			# The hatch the hay was pitched in by, a metre square at the
			# height of the eye of whoever stands on the loft.
			var loft: float = dim.loft
			var low := maxf(loft + 0.55, eaves + 0.05)
			var high := low + 0.95
			var half := 0.5
			var at_low := hw - (low - eaves) / rise
			var at_high := hw - (high - eaves) / rise
			polygons.append(PackedVector2Array([Vector2(-hw, base), Vector2(hw, base), Vector2(hw, eaves), Vector2(at_low, low), Vector2(-at_low, low), Vector2(-hw, eaves)]))
			polygons.append(PackedVector2Array([Vector2(half, low), Vector2(at_low, low), Vector2(at_high, high), Vector2(half, high)]))
			polygons.append(PackedVector2Array([Vector2(-at_low, low), Vector2(-half, low), Vector2(-half, high), Vector2(-at_high, high)]))
			polygons.append(PackedVector2Array([Vector2(-at_high, high), Vector2(at_high, high), Vector2(0, ridge)]))
			dim.loft_hatch = Rect2(-half, low, half * 2.0, high - low)
			# Its frame, and the door of it standing open against the gable.
			for x: float in [-1.0, 1.0]:
				_alp_timber(LARCH, frame * Transform3D(Basis(), Vector3(x * (half + 0.04), (low + high) * 0.5, 0.02)), Vector3(0.08, high - low + 0.08, 0.07), 1)
			_alp_timber(LARCH, frame * Transform3D(Basis(), Vector3(0, low - 0.04, 0.03)), Vector3(half * 2.0 + 0.16, 0.08, 0.1), 0)
			var swung := frame * Transform3D(Basis(Vector3.UP, -2.6), Vector3(half + 0.08, (low + high) * 0.5, 0.05))
			_alp_timber(LARCH, swung * Transform3D(Basis(), Vector3(0.5, 0, 0)), Vector3(1.0, high - low, 0.035), 1, -1.0, 1.0)
		else:
			polygons.append(PackedVector2Array([Vector2(-hw, base), Vector2(hw, base), Vector2(hw, eaves), Vector2(0, ridge), Vector2(-hw, eaves)]))
		var tone := _alp_own.randf()
		for polygon in polygons:
			_alp_boarding(LARCH, polygon, 0.035, frame, tone)


## The doorway of a barn: both wings of its door stand open, swung out past
## square so that they keep clear of whoever goes in.
func _barn_door(xf: Transform3D, dim: Dictionary) -> void:
	var door: float = dim.door
	var hl := float(dim.long) * 0.5
	var high := float(dim.door_top) - 0.04
	var wing := door * 0.5
	for side: float in [-1.0, 1.0]:
		var swing := _alp_own.randf_range(1.75, 2.5)
		var hinge := Vector3(side * door * 0.5, 0.02, hl + 0.04)
		var frame := xf * Transform3D(Basis(Vector3.UP, side * swing), hinge)
		# The wing reaches from its hinge towards the middle of the doorway
		# when it is shut: -X for the right one, +X for the left.
		var middle := Vector3(-side * wing * 0.5, high * 0.5, 0)
		_alp_timber(LARCH, frame * Transform3D(Basis(), middle), Vector3(wing - 0.02, high, 0.04), 1, -1.0, 1.0)
		for y: float in [0.25, high - 0.25]:
			_alp_timber(LARCH, frame * Transform3D(Basis(), Vector3(-side * wing * 0.5, y, -0.04)), Vector3(wing - 0.1, 0.12, 0.04), 0)
		var brace_from := frame * Vector3(-side * 0.08, 0.3, -0.04)
		var brace_to := frame * Vector3(-side * (wing - 0.1), high - 0.3, -0.04)
		_alp_beam(LARCH, brace_from, brace_to, 0.1, 0.04)
		_collide_box(frame * Transform3D(Basis(), middle), Vector3(wing, high, 0.06), "wood")


## Inside a barn: its floor of boards, hay on it, and over the back the loft
## on its beams with more hay. A large barn has a steep stair up to the loft
## along one side.
func _barn_inside(xf: Transform3D, dim: Dictionary, _pitch_deg: float) -> void:
	var hw := float(dim.wide) * 0.5
	var hl := float(dim.long) * 0.5
	var inner := Vector2(hw - LOG.x, hl - LOG.x)
	_alp_timber(LARCH, xf * Transform3D(Basis(), Vector3(0, -0.025, 0)), Vector3(inner.x * 2.0, 0.05, inner.y * 2.0), 2, 0.5, 1.0, 0)
	var loft: float = dim.loft
	var deep: float = dim.loft_deep
	var edge := -inner.y + deep
	# The beams of the loft, across, and its boards on them.
	for z: float in [-inner.y + 0.4, edge - 0.08]:
		_alp_timber(LARCH, xf * Transform3D(Basis(), Vector3(0, loft - 0.1, z)), Vector3(inner.x * 2.0 + 0.1, 0.16, 0.14), 0)
	var boards := xf * Transform3D(Basis(), Vector3(0, loft + 0.02, (edge - inner.y) * 0.5))
	_alp_timber(LARCH, boards, Vector3(inner.x * 2.0, 0.04, deep), 2, 0.5, 1.0)
	_collide_box(boards, Vector3(inner.x * 2.0, 0.08, deep), "wood")
	# A post under the middle of the edge of the loft.
	_alp_timber(LARCH, xf * Transform3D(Basis(), Vector3(0, (loft - 0.18) * 0.5, edge - 0.08)), Vector3(0.14, loft - 0.18, 0.14), 1)
	_collide_box(xf * Transform3D(Basis(), Vector3(0, (loft - 0.18) * 0.5, edge - 0.08)), Vector3(0.14, loft - 0.18, 0.14), "wood")
	# The hay. On the loft, heaped up under the roof but clear of where the
	# stair comes up; under it, along the back; and strewn on the floor.
	var stair_side := -float(dim.hatch_side)
	var loft_heap := Vector2(inner.x * 2.0 - 0.3, deep - 0.25)
	var heap_at := Vector3(0, loft + 0.04, -inner.y + deep * 0.5 - 0.05)
	if dim.stair:
		# Along the far side only: from the top of the stair to the hatch in
		# the back gable the loft is clear.
		loft_heap.x = inner.x - 0.6
		heap_at.x = -stair_side * (inner.x + 0.6) * 0.5
	_alp_uv2.x = 4.5
	_alp_heap(xf, heap_at, loft_heap, minf(1.3, float(dim.eaves) - loft + 0.6), false)
	_alp_heap(xf, Vector3(-stair_side * inner.x * 0.35, 0.0, -inner.y + 0.75), Vector2(inner.x * 1.1, 1.3), 0.75, true)
	# What was dropped on the floor: a ragged patch of it, thin as a sheet.
	var st := _tool(HAY, DETAIL | NO_COLLIDE, xf.origin)
	var rim: Array[Vector3] = []
	for i in 9:
		var angle := TAU * i / 9.0
		var reach := Vector2(inner.x * 0.75, inner.y * 0.55) * _alp_own.randf_range(0.6, 1.0)
		rim.append(xf * Vector3(cos(angle) * reach.x, 0.012, -sin(angle) * reach.y + inner.y * 0.15))
	var middle := xf * Vector3(0, 0.012, inner.y * 0.15)
	var up := xf.basis.y
	for i in 9:
		var a := rim[i]
		var b := rim[(i + 1) % 9]
		_tri(st, [middle, a, b], [up, up, up], [Vector2(middle.x, middle.z), Vector2(a.x, a.z), Vector2(b.x, b.z)])
	_alp_uv2.x = 0.5
	if dim.stair:
		_barn_stair(xf, Vector3(stair_side * (inner.x - 0.5), 0.0, edge + 0.02), loft + 0.04)


## A steep stair of a barn from the floor at `foot`'s height up to `high`,
## arriving at `foot` (x and z) on the edge of the loft, coming from the
## front: two strings with treads between them. To whoever walks it is a
## slope, which bots climb as well as a player.
func _barn_stair(xf: Transform3D, foot: Vector3, high: float) -> void:
	var steep := deg_to_rad(38.0)
	var run := high / tan(steep)
	var wide := 0.9
	var bottom := foot + Vector3(0, 0, run)
	var top := foot + Vector3(0, high, 0)
	for x: float in [-1.0, 1.0]:
		var side := Vector3(x * (wide * 0.5 + 0.03), 0, 0)
		_alp_beam(LARCH, xf * (bottom + side + Vector3(0, 0.05, 0.08)), xf * (top + side + Vector3(0, 0.12, -0.05)), 0.05, 0.2)
	var steps := int(round(high / 0.36))
	for i in range(1, steps + 1):
		var share := float(i) / (steps + 1)
		var tread := bottom.lerp(top, share)
		_alp_timber(LARCH, xf * Transform3D(Basis(), tread + Vector3(0, 0.0, 0.05)), Vector3(wide, 0.04, 0.22), 0)
	var ramp := Transform3D(Basis(Vector3.RIGHT, steep), (bottom + top) * 0.5 + Vector3(0, -0.04, 0))
	_collide_box(xf * ramp, Vector3(wide, 0.08, run / cos(steep) + 0.1), "wood")


## A ramp of boards up to the door of a barn whose floor lies above the
## meadow in front of it, on two bearers, as long as it has to be not to be
## steep.
func _barn_ramp(xf: Transform3D, dim: Dictionary, _at: Vector2) -> void:
	var hl := float(dim.long) * 0.5
	var door: float = dim.door
	var front := xf * Vector3(0, 0, hl + 0.3)
	var rise := xf.origin.y - ground_height(front.x, front.z)
	if rise < 0.12:
		return
	var run := maxf(rise / tan(deg_to_rad(16.0)), 0.8)
	var out_there := xf * Vector3(0, 0, hl + run)
	var foot := xf.affine_inverse() * ground(out_there.x, out_there.z, 0.02)
	var head := Vector3(0, 0.0, hl + 0.05)
	var slant := atan2(head.y - foot.y, foot.z - head.z)
	var middle := (head + foot) * 0.5 + Vector3(0, -0.03, 0)
	var length := head.distance_to(foot)
	var frame := xf * Transform3D(Basis(Vector3.RIGHT, slant), middle)
	_alp_timber(LARCH, frame, Vector3(door - 0.1, 0.05, length), 2, -1.0, 1.0)
	for x: float in [-0.35, 0.35]:
		_alp_timber(LARCH, frame * Transform3D(Basis(), Vector3(x * door, -0.08, 0)), Vector3(0.12, 0.1, length), 2)
	_collide_box(frame, Vector3(door - 0.1, 0.08, length), "wood")
