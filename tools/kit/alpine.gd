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
	"small": {"wide": 4.4, "long": 5.2, "eaves": 2.6, "loft": 1.95, "door": 2.3, "loft_deep": 2.2},
	"middle": {"wide": 5.4, "long": 6.6, "eaves": 2.95, "loft": 2.2, "door": 2.4, "loft_deep": 2.9},
	"large": {"wide": 6.6, "long": 8.2, "eaves": 3.3, "loft": 2.45, "door": 2.6, "loft_deep": 3.6},
}
## A log of a barn's wall: how deep, how high, and how far one lies over the
## last, which leaves a gap between them for the air to dry the hay. How far
## its ends stand out past the corner where it crosses another.
const LOG := Vector3(0.15, 0.25, 0.3)
const LOG_ENDS_OUT := 0.2
## How the colours of the drawings from afar are chosen: what each looks like
## from a few hundred metres, in the sun of an afternoon. sRGB.
const FAR_LOGS := Color(0.39, 0.35, 0.31)
const FAR_BOARDS := Color(0.38, 0.34, 0.3)
const FAR_DARK := Color(0.07, 0.06, 0.05)
const FAR_WINDOW := Color(0.2, 0.22, 0.2)
const FAR_ROOFS := {"boards": Color(0.4, 0.385, 0.36), "shingles": Color(0.36, 0.35, 0.335), "tin": Color(0.42, 0.35, 0.3)}
const FAR_LIME := Color(0.84, 0.83, 0.8)
const FAR_BROWN := Color(0.27, 0.2, 0.15)
const FAR_STONE_CAP := Color(0.45, 0.44, 0.42)

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


## A way for bots from `from` to `to` where the navmesh of a level of
## kilometres cannot see one: up a stair steeper or narrower than its cells
## take. Whoever follows it walks it, both ways, as a player would.
func _alp_link(from: Vector3, to: Vector3) -> void:
	var links := _root.get_node_or_null("AlpineLinks")
	if links == null:
		links = Node3D.new()
		links.name = "AlpineLinks"
		_add(links, _root)
	var link := NavigationLink3D.new()
	link.name = "Link%d" % links.get_child_count()
	link.position = from
	link.start_position = Vector3.ZERO
	link.end_position = to - from
	link.bidirectional = true
	_add(link, links)


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
## edges were rounded off, a log hewn by hand more than a sawn board. A
## piece of a `whole` wall has the place of its corners in the world for UV,
## so that what is drawn on it runs on into the next piece, and no end
## grain. It is in nobody's way: a piece says itself what is.
func _alp_timber(mat: String, xf: Transform3D, size: Vector3, along := 2, tone := -1.0, squeeze := SQUEEZE, ends := 3, rounded := 0.0, whole := false) -> void:
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
		var rises := (xf.basis * up).normalized()
		for p: Vector3 in [c - r - u, c + r - u, c + r + u, c - r + u]:
			points.append(xf * p)
			if whole:
				uvs.append(Vector2((xf * p).dot(across), -(xf * p).dot(rises)))
				normals.append(normal)
			elif end:
				uvs.append(Vector2(p.dot(right), -p.dot(up)))
				normals.append(normal)
			else:
				uvs.append(Vector2(p.dot(right) * squeeze + shift.x, -p.dot(up) + shift.y))
				normals.append((normal + across * signf(p.dot(right)) * rounded).normalized())
		st.set_uv2(Vector2(tone + (2.0 if end and not whole else 0.0) + _alp_inside(xf * c), _alp_uv2.y))
		var face := Vector2(r.length(), u.length()) * 2.0
		_quad(st, points, normals, uvs, [_edge(Vector2(0, 0), face), _edge(Vector2(1, 0), face), _edge(Vector2(1, 1), face), _edge(Vector2(0, 1), face)])
	st.set_uv2(_alp_uv2)


## Boards cut to `outline`, convex and counter-clockwise in the XY of the
## frame `xf` as seen from its +Z, `thick` thick along Z: a gable, a door
## with a slanted top. The boards stand up and down. A piece of a `whole`
## wall, of lime, has the place of its corners in the world for UV, as in
## _alp_timber(). With `collide` it is in the way, as what it is made of.
func _alp_boarding(mat: String, outline: PackedVector2Array, thick: float, xf: Transform3D, tone := -1.0, collide := true, whole := false) -> void:
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
				var point := xf * Vector3(corner.x, corner.y, face * thick * 0.5)
				points.append(point)
				if whole:
					uvs.append(Vector2(point.dot(xf.basis.x * face), -point.dot(xf.basis.y)))
				else:
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
## right), whose top is at `top`: boards on a ledge, hung from the top and
## propped up on a stick nearly level, so that it keeps the rain off and not
## the eye or the shot of whoever looks out from under it.
func _barn_shutter(xf: Transform3D, top: Vector3, side: float, size: Vector2) -> void:
	var out := Vector3(side, 0, 0)
	var open := _alp_own.randf_range(1.35, 1.48)
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
			var swung := frame * Transform3D(Basis(Vector3.UP, -0.25), Vector3(half + 0.08, (low + high) * 0.5, 0.05))
			_alp_timber(LARCH, swung * Transform3D(Basis(), Vector3(0.5, 0, 0)), Vector3(1.0, high - low, 0.035), 1, -1.0, 1.0)
		else:
			polygons.append(PackedVector2Array([Vector2(-hw, base), Vector2(hw, base), Vector2(hw, eaves), Vector2(0, ridge), Vector2(-hw, eaves)]))
		var tone := _alp_own.randf()
		for polygon in polygons:
			_alp_boarding(LARCH, polygon, 0.035, frame, tone)


## The doorway of a barn: both wings of its door stand open, swung out past
## square so that they keep clear of whoever goes in.
func _barn_door(xf: Transform3D, dim: Dictionary) -> void:
	var hl := float(dim.long) * 0.5
	_alp_wings(xf * Transform3D(Basis(), Vector3(0, 0, hl + 0.04)), dim.door, float(dim.door_top) - 0.04)


## The two wings of a door `wide` and `high`, hung either side of a doorway
## whose foot is the origin of the frame `xf`, facing its +Z: boards on two
## ledges and a brace, swung open outwards past square. Each is in the way.
func _alp_wings(xf: Transform3D, wide: float, high: float, mat := LARCH) -> void:
	var wing := wide * 0.5
	for side: float in [-1.0, 1.0]:
		var swing := _alp_own.randf_range(1.75, 2.5)
		var frame := xf * Transform3D(Basis(Vector3.UP, side * swing), Vector3(side * wing, 0.02, 0))
		# The wing reaches from its hinge towards the middle of the doorway
		# when it is shut: -X for the right one, +X for the left.
		var middle := Vector3(-side * wing * 0.5, high * 0.5, 0)
		_alp_timber(mat, frame * Transform3D(Basis(), middle), Vector3(wing - 0.02, high, 0.04), 1, -1.0, 1.0)
		for y: float in [0.25, high - 0.25]:
			_alp_timber(mat, frame * Transform3D(Basis(), Vector3(-side * wing * 0.5, y, -0.04)), Vector3(wing - 0.1, 0.12, 0.04), 0)
		var brace_from := frame * Vector3(-side * 0.08, 0.3, -0.04)
		var brace_to := frame * Vector3(-side * (wing - 0.1), high - 0.3, -0.04)
		_alp_beam(mat, brace_from, brace_to, 0.1, 0.04)
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
		# Along the far side only: from the top of the stair, beside the
		# middle where the roof is high enough to stand under, back to the
		# hatch in the gable the loft is clear.
		loft_heap.x = inner.x - 0.7
		heap_at.x = -stair_side * (inner.x + 0.7) * 0.5
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
		_barn_stair(xf, Vector3(stair_side * 0.75, 0.0, edge + 0.02), loft + 0.04)


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
	_alp_link(xf * (bottom + Vector3(0, 0.05, 0.6)), xf * (top + Vector3(-top.x * 0.6, 0.05, -0.9)))


## A ramp of boards up to the door of a barn whose floor lies above the
## meadow in front of it.
func _barn_ramp(xf: Transform3D, dim: Dictionary, _at: Vector2) -> void:
	_alp_ramp(xf * Transform3D(Basis(), Vector3(0, 0, float(dim.long) * 0.5 + 0.05)), dim.door)


## A ramp of boards `wide`, on two bearers, from the threshold at the origin
## of the frame `xf` out along its +Z down to the ground, as long as it has
## to be not to be steep; nothing where the threshold lies on the ground.
## Whoever walks goes up it, and so do bots.
func _alp_ramp(xf: Transform3D, wide: float) -> void:
	var front := xf * Vector3(0, 0, 0.3)
	var rise := xf.origin.y - ground_height(front.x, front.z)
	if rise < 0.12:
		return
	var run := maxf(rise / tan(deg_to_rad(16.0)), 0.8)
	var out_there := xf * Vector3(0, 0, run)
	var foot := xf.affine_inverse() * ground(out_there.x, out_there.z, 0.02)
	var head := Vector3.ZERO
	var slant := atan2(head.y - foot.y, foot.z - head.z)
	var middle := (head + foot) * 0.5 + Vector3(0, -0.03, 0)
	var length := head.distance_to(foot)
	var frame := xf * Transform3D(Basis(Vector3.RIGHT, slant), middle)
	_alp_timber(LARCH, frame, Vector3(wide - 0.1, 0.05, length), 2, -1.0, 1.0)
	for x: float in [-0.35, 0.35]:
		_alp_timber(LARCH, frame * Transform3D(Basis(), Vector3(x * wide, -0.08, 0)), Vector3(0.12, 0.1, length), 2)
	_collide_box(frame, Vector3(wide - 0.1, 0.08, length), "wood")


# --- What walls are built with -------------------------------------------------------


## The frame of the face of a wall that looks along `out` (level), `off` out
## from the origin of `xf`: X along the wall (left to right seen from
## outside), Y up and Z out of it.
func _alp_face(xf: Transform3D, out: Vector3, off: float) -> Transform3D:
	return xf * Transform3D(Basis(Vector3.UP.cross(out), Vector3.UP, out), out * off)


## A wall of `mat` in the frame `xf` of its face (see _alp_face()), from
## `from` to `to` along it and from `low` to `high`, `thick` thick behind its
## face, with the openings `holes` through it, each a Rect2 of where along it
## and how high. What is drawn on it runs on from piece to piece, and the
## grain of wood lies along it. It is in the way, as `surface`.
func _alp_wall(mat: String, xf: Transform3D, from: float, to: float, low: float, high: float, thick: float, holes: Array, surface := "") -> void:
	var sorted := holes.duplicate()
	sorted.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	var pieces: Array[Rect2] = []
	var x := from
	for hole: Rect2 in sorted:
		if hole.position.x > x:
			pieces.append(Rect2(x, low, hole.position.x - x, high - low))
		pieces.append(Rect2(hole.position.x, low, hole.size.x, hole.position.y - low))
		pieces.append(Rect2(hole.position.x, hole.end.y, hole.size.x, high - hole.end.y))
		x = hole.end.x
	if to > x:
		pieces.append(Rect2(x, low, to - x, high - low))
	var tone := _alp_own.randf()
	for piece in pieces:
		if piece.size.x < 0.005 or piece.size.y < 0.005:
			continue
		var frame := xf * Transform3D(Basis(), Vector3(piece.get_center().x, piece.get_center().y, -thick * 0.5))
		var size := Vector3(piece.size.x, piece.size.y, thick)
		_alp_timber(mat, frame, size, 0, tone, 1.0, 3, 0.0, true)
		_collide_box(frame, size, surface)


## A window in a wall of the frame `xf` of its face, in the opening `hole`:
## a frame painted white `inset` behind the face, the panes dark behind it
## with a cross of glazing bars, a sill, and two shutters of `paint` (see
## PAINTS) opened flat against the wall either side, or none.
func _alp_window(xf: Transform3D, hole: Rect2, inset: float, shutters := "green", sill := LIME) -> void:
	var middle := hole.get_center()
	var depth := -inset
	_alp_uv2.x = PAINTS.white / 10.0
	for side: float in [-1.0, 1.0]:
		_alp_timber(PAINT, xf * Transform3D(Basis(), Vector3(middle.x + side * (hole.size.x * 0.5 - 0.03), middle.y, depth)), Vector3(0.06, hole.size.y, 0.08), 1, PAINTS.white / 10.0, 1.0, 0)
		_alp_timber(PAINT, xf * Transform3D(Basis(), Vector3(middle.x, middle.y + side * (hole.size.y * 0.5 - 0.03), depth)), Vector3(hole.size.x - 0.12, 0.06, 0.08), 0, PAINTS.white / 10.0, 1.0, 0)
	_alp_timber(PAINT, xf * Transform3D(Basis(), Vector3(middle.x, middle.y, depth + 0.01)), Vector3(0.04, hole.size.y - 0.1, 0.05), 1, PAINTS.white / 10.0, 1.0, 0)
	_alp_timber(PAINT, xf * Transform3D(Basis(), Vector3(middle.x, middle.y + hole.size.y * 0.12, depth + 0.01)), Vector3(hole.size.x - 0.1, 0.04, 0.05), 0, PAINTS.white / 10.0, 1.0, 0)
	_alp_uv2.x = 0.5
	var st := _tool(PANE, DETAIL | NO_COLLIDE, xf.origin)
	var out := xf.basis.z
	var corners: Array[Vector3] = []
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		corners.append(xf * Vector3(middle.x + corner.x * hole.size.x * 0.5, middle.y + corner.y * hole.size.y * 0.5, depth - 0.02))
	_quad(st, corners, [out, out, out, out], [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	_collide_box(xf * Transform3D(Basis(), Vector3(middle.x, middle.y, depth - 0.02)), Vector3(hole.size.x, hole.size.y, 0.04))
	_alp_timber(sill, xf * Transform3D(Basis(), Vector3(middle.x, hole.position.y - 0.03, -inset * 0.5 + 0.03)), Vector3(hole.size.x + 0.1, 0.06, inset + 0.06), 0, 0.5, 1.0, 3, 0.0, sill == LIME)
	if shutters != "":
		var leaf := Vector3(hole.size.x * 0.5 + 0.03, hole.size.y + 0.06, 0.035)
		for side: float in [-1.0, 1.0]:
			var at := Vector3(middle.x + side * (hole.size.x * 0.5 + leaf.x * 0.5 + 0.04), middle.y, 0.03)
			_alp_timber(PAINT, xf * Transform3D(Basis(), at), leaf, 1, PAINTS[shutters] / 10.0, 1.0)


## Boards in runs of three, `run` wide with a slot between one run and the
## next, on the face of the frame `xf` from `from` to `to` along it and from
## `low` to `high`: the wall of a barn that lets the air through to the hay.
## Each run is in the way.
func _alp_slats(xf: Transform3D, from: float, to: float, low: float, high: float, run := 0.6, slot := 0.05) -> void:
	var count := maxi(int(round((to - from + slot) / (run + slot))), 1)
	var each := (to - from - (count - 1) * slot) / count
	for i in count:
		var board := xf * Transform3D(Basis(), Vector3(from + each * 0.5 + i * (each + slot), (low + high) * 0.5, -0.015))
		_alp_timber(LARCH, board, Vector3(each, high - low, 0.03), 1, -1.0, 1.0)
		_collide_box(board, Vector3(each, high - low, 0.06), "wood")


## A plinth of grey stone round a building whose walls stand on the
## rectangle `half` (half its length and depth) round the origin of `xf`, a
## hand proud of them: from a little under the ground, which it follows in
## lengths of a few metres, up to `top`.
func _alp_plinth(xf: Transform3D, half: Vector2, top: float) -> void:
	for out: Vector3 in [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT]:
		var reach := half.x if absf(out.z) > 0.5 else half.y
		var off := half.y if absf(out.z) > 0.5 else half.x
		var face := _alp_face(xf, out, off + 0.05)
		var lengths := maxi(int(round(reach * 2.0 / 3.5)), 1)
		for i in lengths:
			var a := -reach - 0.05 + (reach * 2.0 + 0.1) * i / lengths
			var b := -reach - 0.05 + (reach * 2.0 + 0.1) * (i + 1) / lengths
			var low := INF
			for x: float in [a, b]:
				var spot := face * Vector3(x, 0, 0)
				low = minf(low, ground_height(spot.x, spot.z) - xf.origin.y)
			var frame := face * Transform3D(Basis(), Vector3((a + b) * 0.5, (top + low - 0.2) * 0.5, -0.2))
			var size := Vector3(b - a, top - low + 0.2, 0.4)
			_alp_timber(STONE, frame, size, 0, 0.5, 1.0, 3, 0.0, true)
			_collide_box(frame, size, "brick")


# --- The farmhouse -------------------------------------------------------------------


## How a farmhouse is laid out: how deep it is across its ridge, how long the
## house and the barn under the same roof are, how high its ground floor of
## stone and its upper floor of wood are, how steep its roof is and how far
## it stands out.
const FARM := {"deep": 10.4, "house": 10.0, "barn": 9.0, "ground": 2.9, "upper": 2.6, "pitch": 22.0, "over_eave": 1.35, "over_gable": 1.2}


## A farmhouse of Tyrol (an Einhof) at `at`, its long front with the balcony
## facing `yaw_deg` (0 looks along +Z): the house and its barn in line under
## one flat roof that stands far out, the house to the left seen from the
## front. The ground floor is rubble stone under white lime on a plinth of
## grey stone, with small windows behind green shutters; the upper floor is
## of logs gone dark brown in the sun, and along it runs the balcony on its
## brackets, its boards sawn into balusters. The barn above the stable is of
## boards that let the air through. In front of the door a bench, and
## firewood stacked under the eaves of the gable. The house has no inside
## and its door is shut; the stable is open, to be gone into. Its roof is
## "shingles", "boards" weighed with stones, or "tin".
func farmhouse(at: Vector2, yaw_deg: float, roof := "shingles") -> void:
	_alp_begin(at, "near", 7)
	var colliders := _alp_colliders()
	var deep: float = FARM.deep
	var long := float(FARM.house) + float(FARM.barn)
	var hl := long * 0.5
	var hd := deep * 0.5
	var ground: float = FARM.ground
	var eaves := ground + float(FARM.upper)
	var pitch: float = FARM.pitch
	var rise := tan(deg_to_rad(pitch))
	var turn := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var highest := -INF
	var lowest := INF
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var spot := turn * Vector3(corner.x * hl, 0, corner.y * hd)
		highest = maxf(highest, ground_height(at.x + spot.x, at.y + spot.z))
		lowest = minf(lowest, ground_height(at.x + spot.x, at.y + spot.z))
	var xf := Transform3D(turn, Vector3(at.x, highest + 0.25, at.y))
	# Where the house ends and the barn begins, along X.
	var split := -hl + float(FARM.house)
	# The stable and the barn over it are the inside of this piece.
	_alp_room_xf = xf
	_alp_room = AABB(Vector3(split + 0.25, -0.02, -hd + 0.025), Vector3(hl - split - 0.25 - 0.025, eaves + hd * rise + 1.0, deep - 0.05))
	_alp_plinth(xf, Vector2(hl, hd), 0.0)
	_farm_ground_floor(xf, hl, hd, split)
	_farm_upper_floor(xf, hl, hd, split, eaves, rise)
	_farm_balcony(xf, hd, -hl + 0.35, split - 0.35)
	_farm_stable(xf, hl, hd, split)
	var roof_frame := xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
	var ridge := _alp_roof(roof_frame, deep, long, eaves, pitch, FARM.over_eave, FARM.over_gable, roof, 1.8)
	_farm_chimney(xf, -hl + 3.6, -1.6, eaves, rise, hd, ridge)
	_alp_room = AABB()
	# By the door a bench, and under the eaves of the gable the wood for the
	# winter.
	_alp_bench(xf * Transform3D(Basis(), Vector3(-5.6, 0, hd + 0.25)), 1.7)
	_alp_reach = "small"
	_woodpile(xf * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-hl - 0.4, 0, 0.3)), 6.5, 1.7, 0.55, false)
	_alp_reach = "near"
	# From afar: the white ground floor with its windows, the brown upper floor
	# of the house, the grey of the barn, the balcony, and the roof.
	var foot := lowest - xf.origin.y - 0.1
	_far_box(xf, Vector3(0, (ground + foot) * 0.5, 0), Vector3(long, ground - foot, deep), FAR_LIME, FAR_LIME, 0.8)
	_far_box(xf, Vector3((-hl + split) * 0.5, (ground + eaves) * 0.5, 0), Vector3(split + hl, eaves - ground, deep), FAR_BROWN, FAR_BROWN)
	_far_box(xf, Vector3((hl + split) * 0.5, (ground + eaves) * 0.5, 0), Vector3(hl - split, eaves - ground, deep), FAR_BOARDS, FAR_BOARDS)
	for end: float in [-1.0, 1.0]:
		var colour := FAR_BROWN if end < 0.0 else FAR_BOARDS
		_far_tri([xf * Vector3(end * hl, eaves, end * hd), xf * Vector3(end * hl, eaves, -end * hd), xf * Vector3(end * hl, eaves + hd * rise, 0)], colour)
	# The windows of the front, as the panes between their shutters look from
	# afar, and the doorway of the stable.
	for hole: Rect2 in [Rect2(-8.25, 1.15, 0.5, 0.7), Rect2(-6.45, 1.15, 0.5, 0.7), Rect2(-1.45, 1.15, 0.5, 0.7),
			Rect2(-8.25, 3.95, 0.5, 0.65), Rect2(-6.45, 3.95, 0.5, 0.65), Rect2(-2.85, 3.95, 0.5, 0.65), Rect2(-1.45, 3.95, 0.5, 0.65)]:
		_far_quad([xf * Vector3(hole.position.x, hole.position.y, hd + 0.02), xf * Vector3(hole.end.x, hole.position.y, hd + 0.02), xf * Vector3(hole.end.x, hole.end.y, hd + 0.02), xf * Vector3(hole.position.x, hole.end.y, hd + 0.02)], [FAR_WINDOW])
	_far_quad([xf * Vector3(3.45, 0.0, hd + 0.02), xf * Vector3(5.75, 0.0, hd + 0.02), xf * Vector3(5.75, 2.35, hd + 0.02), xf * Vector3(3.45, 2.35, hd + 0.02)], [FAR_DARK])
	_far_quad([xf * Vector3(-hl + 0.35, ground, hd + 1.15), xf * Vector3(split - 0.35, ground, hd + 1.15), xf * Vector3(split - 0.35, ground + 1.15, hd + 1.15), xf * Vector3(-hl + 0.35, ground + 1.15, hd + 1.15)], [FAR_BROWN])
	_far_box(xf, Vector3(-hl + 3.6, ridge + 0.1, -1.6), Vector3(0.62, 1.8, 0.62), FAR_LIME, FAR_STONE_CAP)
	var over_eave: float = FARM.over_eave
	var far_roof := xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
	_far_roof(far_roof, hd + over_eave, hl + float(FARM.over_gable), eaves + 0.2 - over_eave * rise, ridge, FAR_ROOFS[roof])
	_alp_end("farmhouse, %s" % roof, at, _alp_colliders() - colliders)


## The ground floor of a farmhouse: lime over stone, 0.6 m thick, with the
## door of the house and its windows, the door and the windows of the stable,
## and the wall between them.
func _farm_ground_floor(xf: Transform3D, hl: float, hd: float, split: float) -> void:
	var ground: float = FARM.ground
	var thick := 0.6
	var window := Vector2(0.8, 1.0)
	var small := Vector2(0.6, 0.5)
	# Each side as which way it looks, its windows of the house, those of the
	# stable, and its doors: [along, wide, high].
	var sides := [
		[Vector3.BACK, [-8.0, -6.2, -1.2], [1.6, 7.9], [[-3.6, 1.0, 2.1], [4.6, 2.3, 2.35]]],
		[Vector3.FORWARD, [7.6, 4.4, 1.4], [-2.5, -6.8], []],
		[Vector3.LEFT, [-2.4, 2.4], [], []],
		[Vector3.RIGHT, [], [-1.5], []],
	]
	for side: Array in sides:
		var out: Vector3 = side[0]
		var lengthwise := absf(out.z) > 0.5
		var face := _alp_face(xf, out, hd if lengthwise else hl)
		var reach := hl if lengthwise else hd - thick
		var holes: Array = []
		for x: float in side[1]:
			holes.append(Rect2(x - window.x * 0.5, 1.0, window.x, window.y))
		for x: float in side[2]:
			holes.append(Rect2(x - small.x * 0.5, 1.5, small.x, small.y))
		for door: Array in side[3]:
			holes.append(Rect2(door[0] - door[1] * 0.5, 0.0, door[1], door[2]))
		if lengthwise:
			# In two, at the wall between the house and the stable: the part of
			# the stable is inside the piece, that of the house is not.
			var cut := (split + 0.25) * out.z
			var before := holes.filter(func(hole: Rect2) -> bool: return hole.end.x <= cut)
			var after := holes.filter(func(hole: Rect2) -> bool: return hole.position.x >= cut)
			_alp_wall(LIME, face, -reach, cut, -0.2, ground, thick, before)
			_alp_wall(LIME, face, cut, reach, -0.2, ground, thick, after)
		else:
			_alp_wall(LIME, face, -reach, reach, -0.2, ground, thick, holes)
		for x: float in side[1]:
			_alp_window(face, Rect2(x - window.x * 0.5, 1.0, window.x, window.y), 0.14)
		for x: float in side[2]:
			_alp_window(face, Rect2(x - small.x * 0.5, 1.5, small.x, small.y), 0.2, "")
	# The door of the house, shut, under a lintel of stone, with steps up to
	# it; and the doorway of the stable, its wings open, with a ramp.
	var front := _alp_face(xf, Vector3.BACK, hd)
	_alp_door(front, Rect2(-4.1, 0.0, 1.0, 2.1))
	var stable := front * Transform3D(Basis(), Vector3(4.6, 0, 0.02))
	_alp_wings(stable, 2.3, 2.3)
	_alp_ramp(stable * Transform3D(Basis(), Vector3(0, 0, 0.05)), 2.3)
	# The wall between the house and the stable.
	var between := xf * Transform3D(Basis(), Vector3(split + 0.25, ground * 0.5 - 0.1, 0))
	_alp_timber(LIME, between, Vector3(0.5, ground + 0.2, hd * 2.0 - thick * 2.0), 2, 0.5, 1.0, 3, 0.0, true)
	_collide_box(between, Vector3(0.5, ground + 0.2, hd * 2.0 - thick * 2.0))


## The door of a house in the opening `hole` of the wall of the frame `xf`:
## boards painted the red-brown of a door, shut, in a frame, a hand behind
## the face, with stone steps from the ground up to it.
func _alp_door(xf: Transform3D, hole: Rect2) -> void:
	var middle := hole.get_center()
	_alp_timber(PAINT, xf * Transform3D(Basis(), Vector3(middle.x, middle.y, -0.12)), Vector3(hole.size.x, hole.size.y, 0.06), 1, PAINTS.oxblood / 10.0, 1.0)
	for x: float in [-1.0, 1.0]:
		_alp_timber(DARK_WOOD, xf * Transform3D(Basis(), Vector3(middle.x + x * (hole.size.x * 0.5 - 0.05), middle.y, -0.07)), Vector3(0.1, hole.size.y, 0.1), 1, -1.0, SQUEEZE, 0)
	_alp_timber(DARK_WOOD, xf * Transform3D(Basis(), Vector3(middle.x, hole.end.y - 0.05, -0.07)), Vector3(hole.size.x, 0.1, 0.1), 0, -1.0, SQUEEZE, 0)
	# Panels on the door, and its handle.
	for y: float in [0.6, 1.5]:
		_alp_timber(PAINT, xf * Transform3D(Basis(), Vector3(middle.x, hole.position.y + y, -0.085)), Vector3(hole.size.x - 0.3, 0.6, 0.02), 1, PAINTS.oxblood / 10.0, 1.0)
	_alp_timber("dark_steel", xf * Transform3D(Basis(), Vector3(middle.x + hole.size.x * 0.35, hole.position.y + 1.05, -0.07)), Vector3(0.12, 0.025, 0.04), 0)
	_collide_box(xf * Transform3D(Basis(), Vector3(middle.x, middle.y, -0.12)), Vector3(hole.size.x, hole.size.y, 0.08), "wood")
	var below := xf * Vector3(middle.x, 0, 0.6)
	var drop := xf.origin.y - ground_height(below.x, below.z)
	var steps := int(ceil(drop / 0.18))
	for i in steps:
		var top := -i * 0.18
		var frame := xf * Transform3D(Basis(), Vector3(middle.x, top - 0.12, 0.15 + 0.3 * i + 0.0))
		_alp_timber(STONE, frame, Vector3(hole.size.x + 0.5 + 0.1 * i, 0.24, 0.32 + 0.6 * i), 0, 0.5, 1.0, 3, 0.0, true)
		_collide_box(frame, Vector3(hole.size.x + 0.5 + 0.1 * i, 0.24, 0.32 + 0.6 * i), "brick")


## The upper floor of a farmhouse: over the house logs gone dark, with its
## windows and the door to the balcony, and a gable of boards with a small
## window; over the stable the barn, of boards in runs with slots between
## them, and a gable with the door the hay goes in by.
func _farm_upper_floor(xf: Transform3D, hl: float, hd: float, split: float, eaves: float, rise: float) -> void:
	var ground: float = FARM.ground
	var thick := 0.25
	var window := Vector2(0.8, 0.95)
	var low := ground + 0.9
	var front := _alp_face(xf, Vector3.BACK, hd)
	var back := _alp_face(xf, Vector3.FORWARD, hd)
	var west := _alp_face(xf, Vector3.LEFT, hl)
	var east := _alp_face(xf, Vector3.RIGHT, hl)
	var balcony_door := Rect2(-4.55, ground + 0.12, 0.9, 2.0)
	var holes := [balcony_door]
	for x: float in [-8.0, -6.2, -2.6, -1.2]:
		holes.append(Rect2(x - window.x * 0.5, low, window.x, window.y))
	_alp_wall(DARK_WOOD, front, -hl, split, ground, eaves, thick, holes, "wood")
	for x: float in [-8.0, -6.2, -2.6, -1.2]:
		_alp_window(front, Rect2(x - window.x * 0.5, low, window.x, window.y), 0.08, "green", DARK_WOOD)
	_alp_timber(DARK_WOOD, front * Transform3D(Basis(), Vector3(balcony_door.get_center().x, balcony_door.get_center().y, -0.1)), Vector3(balcony_door.size.x, balcony_door.size.y, 0.05), 1, 0.3, 1.0)
	holes = []
	for x: float in [7.6, 4.4, 1.4]:
		holes.append(Rect2(x - window.x * 0.5, low, window.x, window.y))
	_alp_wall(DARK_WOOD, back, -split, hl, ground, eaves, thick, holes, "wood")
	for x: float in [7.6, 4.4, 1.4]:
		_alp_window(back, Rect2(x - window.x * 0.5, low, window.x, window.y), 0.08, "green", DARK_WOOD)
	holes = []
	for x: float in [-2.4, 2.4]:
		holes.append(Rect2(x - window.x * 0.5, low, window.x, window.y))
	_alp_wall(DARK_WOOD, west, -hd + thick, hd - thick, ground, eaves, thick, holes, "wood")
	for x: float in [-2.4, 2.4]:
		_alp_window(west, Rect2(x - window.x * 0.5, low, window.x, window.y), 0.08, "green", DARK_WOOD)
	# The ends of the logs where the walls cross at the corners of the house.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(-1, 1)]:
		for y in int((eaves - ground) / 0.3):
			var at := Vector3(corner.x * (hl + 0.12) , ground + 0.15 + y * 0.3, corner.y * (hd - 0.12))
			_alp_timber(DARK_WOOD, xf * Transform3D(Basis(), at), Vector3(0.24, 0.27, 0.24), 0, -1.0, SQUEEZE, 3)
	# The gables above the eaves, of boards: the house's own and the barn's,
	# and between them the wall that closes the barn off from the house.
	var gable := PackedVector2Array([Vector2(-hd, eaves - 0.02), Vector2(hd, eaves - 0.02), Vector2(0, eaves + hd * rise)])
	_alp_boarding(DARK_WOOD, gable, 0.04, west * Transform3D(Basis(), Vector3(0, 0, -0.1)))
	_alp_boarding(LARCH, gable, 0.04, east * Transform3D(Basis(), Vector3(0, 0, -0.03)))
	_alp_boarding(DARK_WOOD, gable, 0.04, xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(split, 0, 0)), -1.0, true)
	_alp_window(west * Transform3D(Basis(), Vector3(0, 0, -0.055)), Rect2(-0.35, eaves + 0.6, 0.7, 0.6), 0.0, "", DARK_WOOD)
	# The hay door in the barn's gable, shut, and its beam for the pulley.
	_alp_timber(LARCH, east * Transform3D(Basis(), Vector3(0, eaves + 0.75, 0.02)), Vector3(1.4, 1.3, 0.04), 1, -1.0, 1.0)
	_alp_timber(LARCH, east * Transform3D(Basis(), Vector3(0, eaves + 1.65, 0.3)), Vector3(0.14, 0.16, 0.9), 2)
	# The barn: walls of boards over the stable, front, back and gable.
	_alp_timber(DARK_WOOD, xf * Transform3D(Basis(), Vector3(split + 0.125, (ground + eaves) * 0.5, 0)), Vector3(0.25, eaves - ground, hd * 2.0 - 0.1), 2, 0.4, 1.0)
	_alp_slats(front, split, hl, ground, eaves)
	_alp_slats(back, -hl, -split, ground, eaves)
	_alp_slats(east, -hd, hd, ground, eaves)
	# A plate over each run of slats, on which the roof rests.
	for face: Transform3D in [front, back]:
		_alp_timber(LARCH, face * Transform3D(Basis(), Vector3((split + hl) * 0.5 * (1.0 if face == front else -1.0), eaves - 0.08, -0.1)), Vector3(hl - split, 0.16, 0.16), 0)


## The balcony along the front of the upper floor of a farmhouse, from
## `from` to `to` along it: boards on brackets that stand out of the wall,
## and a parapet of boards sawn into balusters under a rail, with its ends.
## It stops a shot.
func _farm_balcony(xf: Transform3D, hd: float, from: float, to: float) -> void:
	var ground: float = FARM.ground
	var deep := 1.1
	var floor_y := ground + 0.1
	var front := _alp_face(xf, Vector3.BACK, hd)
	var length := to - from
	var middle := (from + to) * 0.5
	var floor_frame := front * Transform3D(Basis(), Vector3(middle, floor_y, deep * 0.5))
	_alp_timber(DARK_WOOD, floor_frame, Vector3(length, 0.06, deep), 0, 0.4, 1.0)
	_collide_box(floor_frame, Vector3(length, 0.12, deep), "wood")
	var brackets := int(length / 1.3) + 1
	for i in brackets:
		var x := from + 0.1 + (length - 0.2) * i / (brackets - 1)
		_alp_timber(DARK_WOOD, front * Transform3D(Basis(), Vector3(x, floor_y - 0.14, deep * 0.5 - 0.05)), Vector3(0.14, 0.2, deep + 0.1), 2)
	# The parapet: sawn boards on the front and at either end, a rail on top
	# of them and a post at each corner.
	var high := 0.95
	_alp_fret(front * Transform3D(Basis(), Vector3(middle, floor_y + 0.03, deep - 0.04)), length - 0.1, high)
	for end: float in [-1.0, 1.0]:
		var at := from if end < 0.0 else to
		var side := front * Transform3D(Basis(Vector3.UP, -end * PI * 0.5), Vector3(at + end * -0.04, floor_y + 0.03, deep * 0.5))
		_alp_fret(side, deep - 0.1, high)
		_alp_timber(DARK_WOOD, front * Transform3D(Basis(), Vector3(at - end * 0.05, floor_y + high * 0.5 + 0.05, deep - 0.05)), Vector3(0.1, high + 0.1, 0.1), 1)
		_alp_timber(DARK_WOOD, front * Transform3D(Basis(), Vector3(at - end * 0.04, floor_y + high + 0.12, deep * 0.5)), Vector3(0.1, 0.06, deep), 2)
	_alp_timber(DARK_WOOD, front * Transform3D(Basis(), Vector3(middle, floor_y + high + 0.12, deep - 0.04)), Vector3(length, 0.06, 0.12), 0)
	_collide_box(front * Transform3D(Basis(), Vector3(middle, floor_y + 0.55, deep - 0.04)), Vector3(length, 1.1, 0.08), "wood")


## A board `long` along the X of `xf` and `high` from its origin up, its
## middle at the origin along X, both faces of it sawn into balusters: see
## shaders/alpine_fretwork.gdshader.
func _alp_fret(xf: Transform3D, long: float, high: float) -> void:
	var st := _tool("alpine_fretwork", DETAIL | NO_COLLIDE, xf.origin)
	var out := xf.basis.z
	var corners: Array[Vector3] = [xf * Vector3(-long * 0.5, 0, 0), xf * Vector3(long * 0.5, 0, 0), xf * Vector3(long * 0.5, high, 0), xf * Vector3(-long * 0.5, high, 0)]
	var uvs := [Vector2(0, high), Vector2(long, high), Vector2(long, 0), Vector2(0, 0)]
	_quad(st, corners, [out, out, out, out], uvs)


## The stable under the barn of a farmhouse: its floor of stones, its
## ceiling of boards on beams, a post under them, a manger along the back
## wall and hay.
func _farm_stable(xf: Transform3D, hl: float, hd: float, split: float) -> void:
	var ground: float = FARM.ground
	var inner := Rect2(split + 0.5, -hd + 0.6, hl - 0.6 - split - 0.5, hd * 2.0 - 1.2)
	var middle := inner.get_center()
	_alp_timber(STONE, xf * Transform3D(Basis(), Vector3(middle.x, -0.03, middle.y)), Vector3(inner.size.x, 0.06, inner.size.y), 0, 0.5, 1.0, 0, 0.0, true)
	_collide_box(xf * Transform3D(Basis(), Vector3(middle.x, -0.5, middle.y)), Vector3(inner.size.x, 1.0, inner.size.y), "brick")
	var ceiling := xf * Transform3D(Basis(), Vector3(middle.x, ground - 0.03, 0))
	_alp_timber(LARCH, ceiling, Vector3(hl - split, 0.06, hd * 2.0 - 0.1), 0, 0.5, 1.0)
	_collide_box(ceiling, Vector3(hl - split, 0.1, hd * 2.0 - 0.1), "wood")
	for z: float in [-2.0, 2.0]:
		_alp_timber(LARCH, xf * Transform3D(Basis(), Vector3(middle.x, ground - 0.16, z)), Vector3(inner.size.x, 0.2, 0.18), 0)
	var post := xf * Transform3D(Basis(), Vector3(middle.x, ground * 0.5 - 0.1, -2.0))
	_alp_timber(LARCH, post, Vector3(0.18, ground - 0.2, 0.18), 1)
	_collide_box(post, Vector3(0.18, ground - 0.2, 0.18), "wood")
	var manger := xf * Transform3D(Basis(), Vector3(middle.x, 0.4, inner.position.y + 0.35))
	_alp_timber(LARCH, manger, Vector3(inner.size.x - 0.4, 0.8, 0.6), 0)
	_collide_box(manger, Vector3(inner.size.x - 0.4, 0.8, 0.6), "wood")
	_alp_uv2.x = 4.5
	_alp_heap(xf, Vector3(middle.x, 0.8, inner.position.y + 0.35), Vector2(inner.size.x - 0.6, 0.5), 0.25)
	_alp_heap(xf, Vector3(inner.end.x - 1.2, 0.0, inner.end.y - 1.4), Vector2(1.8, 2.2), 0.9, true)
	_alp_uv2.x = 0.5


## The chimney of a farmhouse at `x` and `z`, through the roof from under it
## to over the ridge: lime over stone, with a slab on four stones over it to
## keep the rain out.
func _farm_chimney(xf: Transform3D, x: float, z: float, eaves: float, rise: float, hd: float, ridge: float) -> void:
	var low := eaves + (hd - absf(z)) * rise - 0.3
	var top := ridge + 0.9
	var stack := xf * Transform3D(Basis(), Vector3(x, (low + top) * 0.5, z))
	_alp_timber(LIME, stack, Vector3(0.62, top - low, 0.62), 1, 0.5, 1.0, 3, 0.0, true)
	_collide_box(stack, Vector3(0.62, top - low, 0.62))
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		_alp_stone(ROCK, xf * Transform3D(Basis(), Vector3(x + corner.x * 0.24, top + 0.08, z + corner.y * 0.24)), Vector3(0.12, 0.16, 0.12))
	_alp_timber(STONE, xf * Transform3D(Basis(), Vector3(x, top + 0.19, z)), Vector3(0.8, 0.07, 0.8), 0, 0.5, 1.0, 3, 0.0, true)


## A bench against a wall, its back to the origin of `xf` and facing its +Z,
## `long` along it: a thick board on two legs, worn smooth.
func _alp_bench(xf: Transform3D, long: float) -> void:
	var under := xf * Vector3(0, 0, 0.25)
	var low := ground_height(under.x, under.z) - xf.origin.y
	var seat := xf * Transform3D(Basis(), Vector3(0, low + 0.44, 0.2))
	_alp_timber(DARK_WOOD, seat, Vector3(long, 0.06, 0.36), 0, 0.2, SQUEEZE, 3, 0.3)
	for x: float in [-1.0, 1.0]:
		_alp_timber(DARK_WOOD, xf * Transform3D(Basis(), Vector3(x * (long * 0.5 - 0.2), low + 0.21, 0.2)), Vector3(0.06, 0.44, 0.3), 1, 0.3)
	_collide_box(xf * Transform3D(Basis(), Vector3(0, low + 0.24, 0.2)), Vector3(long, 0.48, 0.36), "wood")


# --- The chapel ----------------------------------------------------------------------


## A chapel by the way at `at`, its door in the gable that faces `yaw_deg`
## (0 looks along +Z): small and white, lime over stone on a grey plinth,
## a steep roof of shingles and at its back a choir of three sides under a
## roof of its own. Over the door, astride the ridge, a little tower of
## boards with a bell in it, an onion of shingles on it and a cross on top.
## The door of boards is round at the top and shut; two round-headed windows
## light either side. A bench stands against its sunny side. It is cover,
## and there is nothing inside.
func chapel(at: Vector2, yaw_deg: float) -> void:
	_alp_begin(at, "near", 11)
	var colliders := _alp_colliders()
	var wide := 5.0
	var long := 6.6
	var hw := wide * 0.5
	var hl := long * 0.5
	var eaves := 3.9
	var thick := 0.55
	var pitch := 45.0
	var rise := tan(deg_to_rad(pitch))
	var turn := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var highest := -INF
	var lowest := INF
	for corner: Vector2 in [Vector2(-1, -1.5), Vector2(1, -1.5), Vector2(1, 1), Vector2(-1, 1)]:
		var spot := turn * Vector3(corner.x * hw, 0, corner.y * hl)
		highest = maxf(highest, ground_height(at.x + spot.x, at.y + spot.z))
		lowest = minf(lowest, ground_height(at.x + spot.x, at.y + spot.z))
	var xf := Transform3D(turn, Vector3(at.x, highest + 0.2, at.y))
	_alp_plinth(xf, Vector2(hw, hl), 0.0)
	var front := _alp_face(xf, Vector3.BACK, hl)
	var door := Rect2(-0.55, 0.0, 1.1, 2.75)
	_alp_wall(LIME, front, -hw, hw, -0.2, eaves, thick, [door])
	_alp_arch(front, door, thick, "door")
	for out: Vector3 in [Vector3.RIGHT, Vector3.LEFT]:
		var side := _alp_face(xf, out, hw)
		var holes: Array = []
		for x: float in [-1.3, 1.3]:
			holes.append(Rect2(x - 0.3, 1.7, 0.6, 1.5))
		# Along the left side the wall runs from the back to the front wall,
		# along the right the other way.
		var back_end := -hl if out.x < 0.0 else -(hl - thick)
		_alp_wall(LIME, side, back_end, back_end + long - thick, -0.2, eaves, thick, holes)
		for hole: Rect2 in holes:
			_alp_arch(side, hole, thick, "window")
	# The choir: three walls round the back, and the gable over the front.
	var choir: Array[Vector2] = [Vector2(-hw, -hl), Vector2(-hw + 1.15, -hl - 1.5), Vector2(hw - 1.15, -hl - 1.5), Vector2(hw, -hl)]
	for i in 3:
		var a := choir[i]
		var b := choir[i + 1]
		var along := Vector3(b.x - a.x, 0, b.y - a.y)
		var out := Vector3.UP.cross(along).normalized()
		var face := xf * Transform3D(Basis(Vector3.UP.cross(out), Vector3.UP, out), Vector3((a.x + b.x) * 0.5, 0, (a.y + b.y) * 0.5))
		var holes: Array = []
		if i == 1:
			holes.append(Rect2(-0.25, 1.9, 0.5, 1.1))
		_alp_wall(LIME, face, -along.length() * 0.5 - 0.12, along.length() * 0.5 + 0.12, -0.2, eaves, thick, holes)
		if i == 1:
			_alp_arch(face, holes[0], thick, "window")
	var gable := PackedVector2Array([Vector2(-hw, eaves - 0.02), Vector2(hw, eaves - 0.02), Vector2(0, eaves + hw * rise)])
	_alp_boarding(LIME, gable, thick, front * Transform3D(Basis(), Vector3(0, 0, -thick * 0.5)), 0.5, true, true)
	# The roof of the nave, from the choir to its overhang over the door, and
	# the choir's own, three faces of shingles up to the end of the ridge.
	var over := 0.45
	var ridge := _alp_roof(xf * Transform3D(Basis(), Vector3(0, 0, over * 0.5)), wide, long + over, eaves, pitch, 0.4, 0.0, "shingles", 1.0)
	_chapel_choir_roof(xf, choir, eaves, Vector3(0, ridge - 0.03, -hl), rise)
	_chapel_tower(xf, Vector3(0, eaves + hw * rise, hl - 0.85), ridge)
	# The bench, against the side the sun stands on in the afternoon.
	_alp_bench(_alp_face(xf, Vector3.LEFT, hw + 0.05) * Transform3D(Basis(), Vector3(0, 0, 0)), 1.8)
	# From afar.
	var foot := lowest - xf.origin.y - 0.1
	_far_box(xf, Vector3(0, (eaves + foot) * 0.5, 0), Vector3(wide, eaves - foot, long), FAR_LIME, FAR_LIME, 0.85)
	_far_box(xf, Vector3(0, (eaves + foot) * 0.5, -hl - 0.7), Vector3(wide - 1.4, eaves - foot, 1.4), FAR_LIME, FAR_LIME, 0.85)
	_far_tri([xf * Vector3(-hw, eaves, hl), xf * Vector3(hw, eaves, hl), xf * Vector3(0, eaves + hw * rise, hl)], FAR_LIME)
	_far_quad([xf * Vector3(-0.55, 0, hl + 0.02), xf * Vector3(0.55, 0, hl + 0.02), xf * Vector3(0.55, 2.6, hl + 0.02), xf * Vector3(-0.55, 2.6, hl + 0.02)], [FAR_DARK])
	_far_roof(xf * Transform3D(Basis(), Vector3(0, 0, -0.75 + over * 0.5)), hw + 0.4, hl + 0.75 + over * 0.5, eaves + 0.2 - 0.4 * rise, ridge, FAR_ROOFS.shingles)
	var tower := xf * Vector3(0, ridge, hl - 0.85)
	_far_box(Transform3D(xf.basis, tower), Vector3(0, 0.9, 0), Vector3(1.1, 1.8, 1.1), FAR_BOARDS, FAR_ROOFS.shingles)
	var tip := Transform3D(xf.basis, tower) * Vector3(0, 3.6, 0)
	for side in 4:
		var a := Transform3D(xf.basis, tower) * (Basis(Vector3.UP, PI * 0.5 * side) * Vector3(0.6, 1.8, 0.6))
		var b := Transform3D(xf.basis, tower) * (Basis(Vector3.UP, PI * 0.5 * (side + 1)) * Vector3(0.6, 1.8, 0.6))
		_far_tri([b, a, tip], FAR_ROOFS.shingles)
	_alp_end("chapel", at, _alp_colliders() - colliders)


## A round-headed opening in a wall of the frame `xf` of its face: `hole` is
## the rectangle it was cut as, the round head in the top of it, and the
## wall `thick`. The corners above the round are filled with the wall again,
## its underside follows the round through the wall, and in it is a door of
## boards, shut, or a window, its panes dark behind a frame.
func _alp_arch(xf: Transform3D, hole: Rect2, thick: float, what: String) -> void:
	var radius := hole.size.x * 0.5
	var spring := hole.end.y - radius
	var middle := hole.get_center().x
	var steps := 6
	var arc := PackedVector2Array()
	for i in steps + 1:
		var angle := PI * i / steps
		arc.append(Vector2(middle + cos(angle) * radius, spring + sin(angle) * radius))
	# The corners over the round, in slices with upright sides, and under the
	# round, faces from the wall's face to its back.
	var st := _tool(LIME, DETAIL | NO_COLLIDE, xf.origin)
	for i in steps:
		var a := arc[i]
		var b := arc[i + 1]
		var slice := PackedVector2Array([a, b, Vector2(b.x, hole.end.y), Vector2(a.x, hole.end.y)])
		if a.x > b.x:
			slice = PackedVector2Array([b, a, Vector2(a.x, hole.end.y), Vector2(b.x, hole.end.y)])
		if absf(hole.end.y - minf(a.y, b.y)) > 0.01:
			_alp_boarding(LIME, slice, thick, xf * Transform3D(Basis(), Vector3(0, 0, -thick * 0.5)), 0.5, false, true)
		var down := ((a + b) * 0.5 - Vector2(middle, spring)).normalized() * -1.0
		var normal := xf.basis * Vector3(down.x, down.y, 0)
		var corners := [xf * Vector3(a.x, a.y, 0.0), xf * Vector3(b.x, b.y, 0.0), xf * Vector3(b.x, b.y, -thick), xf * Vector3(a.x, a.y, -thick)]
		var uvs := []
		for corner: Vector3 in corners:
			uvs.append(Vector2(corner.x + corner.z, -corner.y))
		_quad(st, corners, [normal, normal, normal, normal], uvs)
	var outline := PackedVector2Array([Vector2(hole.position.x, hole.position.y), Vector2(hole.end.x, hole.position.y)])
	for i in steps + 1:
		outline.append(arc[i])
	# The arc ran from right to left over the top: the outline is counter-
	# clockwise seen from outside.
	if what == "door":
		var leaf := xf * Transform3D(Basis(), Vector3(0, 0, -0.18))
		_alp_boarding(PAINT, outline, 0.06, leaf, PAINTS.oxblood / 10.0, true)
		for y: float in [0.5, 1.6]:
			_alp_timber(DARK_WOOD, leaf * Transform3D(Basis(), Vector3(middle, hole.position.y + y, 0.045)), Vector3(hole.size.x - 0.1, 0.1, 0.03), 0)
		_alp_timber("dark_steel", leaf * Transform3D(Basis(), Vector3(middle + radius * 0.65, 1.1, 0.06)), Vector3(0.03, 0.18, 0.03), 1)
		var below := xf * Vector3(middle, 0, 0.5)
		var step := xf * Transform3D(Basis(), Vector3(middle, -0.1, 0.25))
		if xf.origin.y - ground_height(below.x, below.z) > 0.1:
			_alp_timber(STONE, step, Vector3(hole.size.x + 0.6, 0.2, 0.5), 0, 0.5, 1.0, 3, 0.0, true)
	else:
		var pane := xf * Transform3D(Basis(), Vector3(0, 0, -thick * 0.45))
		var glass := _tool(PANE, DETAIL | NO_COLLIDE, pane.origin)
		var out := xf.basis.z
		for i in range(1, outline.size() - 1):
			var corners := [pane * Vector3(outline[0].x, outline[0].y, 0), pane * Vector3(outline[i].x, outline[i].y, 0), pane * Vector3(outline[i + 1].x, outline[i + 1].y, 0)]
			_tri(glass, corners, [out, out, out], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
		_alp_timber(PAINT, pane * Transform3D(Basis(), Vector3(middle, hole.get_center().y, 0.02)), Vector3(0.04, hole.size.y, 0.04), 1, PAINTS.white / 10.0, 1.0, 0)
		_alp_timber(PAINT, pane * Transform3D(Basis(), Vector3(middle, spring, 0.02)), Vector3(hole.size.x, 0.04, 0.04), 0, PAINTS.white / 10.0, 1.0, 0)
		_collide_box(pane * Transform3D(Basis(), Vector3(middle, hole.get_center().y, 0)), Vector3(hole.size.x, hole.size.y, 0.05))


## The roof of the choir of a chapel: a face of shingles over each of the
## walls `choir` (from one corner of the nave round to the other), all up to
## `apex`, the end of the ridge of the nave, and a face of boards under each.
func _chapel_choir_roof(xf: Transform3D, choir: Array[Vector2], eaves: float, apex: Vector3, _rise: float) -> void:
	var middle := Vector2(0, -3.3 - 0.4)
	for i in 3:
		var a := choir[i]
		var b := choir[i + 1]
		# Out over the wall by the overhang, and down by as much as that.
		var out_a := a + (a - middle).normalized() * 0.45
		var out_b := b + (b - middle).normalized() * 0.45
		var low := eaves + 0.12 - 0.4
		var pa := xf * Vector3(out_a.x, low, out_a.y)
		var pb := xf * Vector3(out_b.x, low, out_b.y)
		var top := xf * apex
		for under: bool in [false, true]:
			var lift := Vector3.UP * (-0.14 if under else 0.0)
			var corners := [pb + lift, pa + lift, top + lift]
			if under:
				corners = [pa + lift, pb + lift, top + lift]
			var normal: Vector3 = ((corners[1] as Vector3) - (corners[0] as Vector3)).cross((corners[2] as Vector3) - (corners[0] as Vector3)).normalized()
			var along: Vector3 = ((corners[1] as Vector3) - (corners[0] as Vector3)).normalized()
			var downhill := normal.cross(along) * -1.0
			var uvs := []
			for corner: Vector3 in corners:
				uvs.append(Vector2(corner.dot(along), corner.dot(downhill)))
			var st := _tool(LARCH if under else SHINGLES, DETAIL | NO_COLLIDE, top)
			_tri(st, corners, [normal, normal, normal], uvs)
	var choir_box := xf * Transform3D(Basis(), Vector3(0, eaves + 0.8, -3.3 - 0.75))
	_collide_box(choir_box, Vector3(3.2, 1.6, 1.5), "wood")


## The little tower astride the ridge of a chapel, its foot at `foot` on the
## ridge: a box of boards with an opening on each side and the bell hung in
## it, a skirt of shingles over it, the onion on that and the cross on top.
func _chapel_tower(xf: Transform3D, foot: Vector3, ridge: float) -> void:
	var half := 0.55
	var high := 1.9
	var low := foot.y - 0.6
	var base := xf * Transform3D(Basis(), Vector3(foot.x, 0, foot.z))
	for out: Vector3 in [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT]:
		var face := _alp_face(base, out, half)
		var opening := Rect2(-0.22, ridge + 0.55, 0.44, 0.75)
		_alp_wall(LARCH, face, -half + (0.05 if absf(out.x) > 0.5 else 0.0), half - (0.05 if absf(out.x) > 0.5 else 0.0), low, ridge + high, 0.05, [opening], "wood")
	# The bell, on its beam, and its clapper.
	_alp_timber(LARCH, base * Transform3D(Basis(), Vector3(0, ridge + 1.55, 0)), Vector3(half * 2.0 - 0.1, 0.1, 0.1), 0)
	revolve("brass", base * Transform3D(Basis(), Vector3(0, ridge + 1.1, 0)), PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.21, 0.0), Vector2(0.2, 0.02), Vector2(0.15, 0.12), Vector2(0.13, 0.3), Vector2(0.09, 0.41), Vector2(0.0, 0.42)]), DETAIL | NO_COLLIDE, 10)
	_collide_box(base * Transform3D(Basis(), Vector3(0, (low + ridge + high) * 0.5, 0)), Vector3(half * 2.0, ridge + high - low, half * 2.0), "wood")
	# The skirt: four faces of shingles from over the boards up to the foot of
	# the onion.
	var top := ridge + high
	var skirt := 0.78
	var neck := 0.42
	for side in 4:
		var turn := Basis(Vector3.UP, PI * 0.5 * side)
		var a := base * (turn * Vector3(-skirt, top - 0.05, skirt))
		var b := base * (turn * Vector3(skirt, top - 0.05, skirt))
		var c := base * (turn * Vector3(neck, top + 0.35, neck))
		var d := base * (turn * Vector3(-neck, top + 0.35, neck))
		var normal := (b - a).cross(d - a).normalized()
		var along := (b - a).normalized()
		var downhill := normal.cross(along) * -1.0
		var uvs := []
		for corner: Vector3 in [a, b, c, d]:
			uvs.append(Vector2(corner.dot(along), corner.dot(downhill)))
		_quad(_tool(SHINGLES, DETAIL | NO_COLLIDE, a), [a, b, c, d], [normal, normal, normal, normal], uvs)
	# The onion, from its neck up to the spire, shingled: its profile from
	# the top down, turned round for revolve(), which wants it from the foot
	# up and lays the courses down it.
	var onion := PackedVector2Array([Vector2(0.0, 1.95), Vector2(0.04, 1.55), Vector2(0.09, 1.32), Vector2(0.24, 1.12), Vector2(0.46, 0.86), Vector2(0.58, 0.6), Vector2(0.56, 0.36), Vector2(0.44, 0.16), Vector2(0.4, 0.0)])
	var flipped := PackedVector2Array()
	for i in onion.size():
		flipped.append(Vector2(onion[onion.size() - 1 - i].x, onion[onion.size() - 1 - i].y))
	revolve(SHINGLES, base * Transform3D(Basis(), Vector3(0, top + 0.3, 0)), flipped, DETAIL | NO_COLLIDE, 12, true)
	# The cross on the spire, gilt.
	var spire := top + 0.3 + 1.95
	_alp_timber(PAINT, base * Transform3D(Basis(), Vector3(0, spire + 0.35, 0)), Vector3(0.05, 0.7, 0.05), 1, PAINTS.gold / 10.0, 1.0)
	_alp_timber(PAINT, base * Transform3D(Basis(), Vector3(0, spire + 0.48, 0)), Vector3(0.36, 0.05, 0.05), 0, PAINTS.gold / 10.0, 1.0)


# --- By the way ----------------------------------------------------------------------


## A cross by the way (Wegkreuz) at `at`, facing `yaw_deg` (0 looks along
## +Z): a post of dark wood on a stone, its arms, a little roof of boards over
## the top, and the carved figure on it, painted, with the board over its
## head. It stands in the way only as a post.
func wayside_cross(at: Vector2, yaw_deg: float) -> void:
	_alp_begin(at, "small", 13)
	var colliders := _alp_colliders()
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y))
	var stone := xf * Transform3D(Basis(), Vector3(0, 0.12, 0))
	_alp_stone(STONE, stone, Vector3(0.7, 0.5, 0.6))
	var post := xf * Transform3D(Basis(), Vector3(0, 1.85, 0))
	_alp_timber(DARK_WOOD, post, Vector3(0.15, 3.4, 0.12), 1, -1.0, SQUEEZE, 2)
	_collide_box(post, Vector3(0.18, 3.4, 0.16), "wood")
	_alp_timber(DARK_WOOD, xf * Transform3D(Basis(), Vector3(0, 2.75, 0)), Vector3(1.5, 0.13, 0.11), 0)
	# The roof over the top: two boards in a gable, its eaves forward and back.
	for side: float in [-1.0, 1.0]:
		var board := xf * Transform3D(Basis(Vector3.BACK, -side * 0.7), Vector3(side * 0.16, 3.56, 0.02))
		_alp_timber(DARK_WOOD, board, Vector3(0.46, 0.025, 0.42), 0, -1.0, 1.0)
	_alp_timber(DARK_WOOD, xf * Transform3D(Basis(), Vector3(0, 3.5, 0.2)), Vector3(0.6, 0.12, 0.02), 0, -1.0, 1.0)
	# The figure, its arms along the cross and its head bowed, and the board.
	_alp_figure(xf * Transform3D(Basis(), Vector3(0, 2.75, 0.085)), 1.0)
	_alp_timber(PAINT, xf * Transform3D(Basis(), Vector3(0, 3.2, 0.075)), Vector3(0.24, 0.1, 0.02), 0, PAINTS.white / 10.0, 1.0)
	_alp_end("wayside_cross", at, _alp_colliders() - colliders)


## A figure on a cross, `scale` times life size of a carving by the way (a
## metre and a quarter tall), its hands at the ends of the arms of the cross
## whose middle is the origin of `xf`, facing its +Z: pale, with a white
## cloth round its loins, its head bowed to its right.
func _alp_figure(xf: Transform3D, scale: float) -> void:
	var pale := PAINTS.pale / 10.0
	var at := func(x: float, y: float) -> Transform3D: return xf * Transform3D(Basis(), Vector3(x, y, 0) * scale)
	_alp_timber(PAINT, at.call(0, -0.2), Vector3(0.19, 0.4, 0.1) * scale, 1, pale, 1.0)
	_alp_timber(PAINT, at.call(0, -0.43), Vector3(0.22, 0.14, 0.11) * scale, 0, PAINTS.white / 10.0, 1.0)
	_alp_timber(PAINT, xf * Transform3D(Basis(Vector3.BACK, 0.4), Vector3(0.035, 0.07, 0.04) * scale), Vector3(0.1, 0.13, 0.11) * scale, 1, pale, 1.0)
	for side: float in [-1.0, 1.0]:
		var shoulder := Vector3(side * 0.08, -0.04, 0) * scale
		var hand := Vector3(side * 0.62, 0.02, 0) * scale
		_alp_beam(PAINT, xf * shoulder, xf * hand, 0.05 * scale, 0.05 * scale, pale)
		var hip := Vector3(side * 0.05, -0.48, 0) * scale
		var foot := Vector3(-side * 0.01, -1.05, 0.02) * scale
		_alp_beam(PAINT, xf * hip, xf * foot, 0.07 * scale, 0.07 * scale, pale)


## A shrine on a post by the way (Marterl) at `at`, facing `yaw_deg`: a box
## of boards open at the front under a little roof of shingles, with a
## picture painted blue in it, a small cross before it and a candle. In the
## way only as a post.
func marterl(at: Vector2, yaw_deg: float) -> void:
	_alp_begin(at, "small", 17)
	var colliders := _alp_colliders()
	var own := _alp_own
	var lean := Basis.from_euler(Vector3(own.randf_range(-0.03, 0.03), 0, own.randf_range(-0.03, 0.03)))
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)) * lean, ground(at.x, at.y, -0.3))
	var post := xf * Transform3D(Basis(), Vector3(0, 0.95, 0))
	_alp_timber(LARCH, post, Vector3(0.14, 1.9, 0.14), 1, -1.0, SQUEEZE, 0)
	_collide_box(post, Vector3(0.16, 1.9, 0.16), "wood")
	var box := xf * Transform3D(Basis(), Vector3(0, 2.2, 0))
	_alp_timber(LARCH, box * Transform3D(Basis(), Vector3(0, -0.3, 0.0)), Vector3(0.56, 0.04, 0.34), 0)
	_alp_timber(LARCH, box * Transform3D(Basis(), Vector3(0, 0, -0.15)), Vector3(0.56, 0.6, 0.03), 1, -1.0, 1.0)
	for x: float in [-1.0, 1.0]:
		_alp_timber(LARCH, box * Transform3D(Basis(), Vector3(x * 0.265, 0, 0.0)), Vector3(0.03, 0.6, 0.3), 1, -1.0, 1.0)
	_alp_timber(PAINT, box * Transform3D(Basis(), Vector3(0, 0.0, -0.13)), Vector3(0.44, 0.46, 0.01), 1, PAINTS.blue / 10.0, 1.0)
	_alp_timber(PAINT, box * Transform3D(Basis(), Vector3(0, 0.02, -0.12)), Vector3(0.12, 0.3, 0.01), 1, PAINTS.gold / 10.0, 1.0)
	_alp_timber(DARK_WOOD, box * Transform3D(Basis(), Vector3(0, -0.06, -0.07)), Vector3(0.03, 0.4, 0.03), 1)
	_alp_timber(DARK_WOOD, box * Transform3D(Basis(), Vector3(0, 0.04, -0.07)), Vector3(0.2, 0.03, 0.03), 0)
	_alp_figure(box * Transform3D(Basis(), Vector3(0, 0.04, -0.05)), 0.15)
	_alp_timber(PAINT, box * Transform3D(Basis(), Vector3(0.15, -0.22, 0.05)), Vector3(0.04, 0.12, 0.04), 1, PAINTS.oxblood / 10.0, 1.0)
	for side: float in [-1.0, 1.0]:
		var board := box * Transform3D(Basis(Vector3.BACK, -side * 0.75), Vector3(side * 0.19, 0.41, 0.02))
		_alp_timber(SHINGLES, board, Vector3(0.5, 0.03, 0.5), 0, 0.5, 1.0)
	_alp_end("marterl", at, _alp_colliders() - colliders)


# --- The hunter's stand --------------------------------------------------------------


## A hunter's stand (Hochstand) at `at`, looking out the way `yaw_deg` faces:
## four legs of peeled poles, splayed and braced, a floor `high` over the
## ground, a cabin with a parapet of boards to the chest and the rest open to
## shoot from, under a roof of boards; and at the back a steep stair of
## treads between two strings up to the floor, with a rail. A place for a
## sniper: whoever stands up there sees over the meadow and the parapet
## stops what is shot at him when he ducks. The stair is a slope to whoever
## walks, wide enough for bots to climb.
func hunting_stand(at: Vector2, yaw_deg: float, high := 4.5) -> void:
	_alp_begin(at, "near", 19)
	var colliders := _alp_colliders()
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y))
	var half := 1.25
	var foot := 1.55
	var cabin := 2.15
	var roof_at := high + cabin
	# The legs, from the ground under each up to the roof, which they carry.
	var tops: Array[Vector3] = []
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var world := xf * Vector3(corner.x * foot, 0, corner.y * foot)
		var low := xf.affine_inverse() * ground(world.x, world.z, -0.3)
		var top := Vector3(corner.x * half, roof_at, corner.y * half)
		_alp_pole(LARCH, xf * low, xf * top, 0.1, 0.075, 7, true)
		tops.append(top)
	# Braces crosswise on the two sides and the front, under the floor.
	for pair: Array in [[0, 3], [1, 2], [2, 3]]:
		var a: Vector3 = tops[pair[0]]
		var b: Vector3 = tops[pair[1]]
		var a_low := Vector3(a.x / half * foot, 0.5, a.z / half * foot)
		var b_low := Vector3(b.x / half * foot, 0.5, b.z / half * foot)
		var a_high := a_low.lerp(a, (high - 0.4) / roof_at)
		var b_high := b_low.lerp(b, (high - 0.4) / roof_at)
		a_high.y = high - 0.4
		b_high.y = high - 0.4
		_alp_pole(LARCH, xf * a_low, xf * b_high, 0.045, -1.0, 5)
		_alp_pole(LARCH, xf * b_low, xf * a_high, 0.045, -1.0, 5)
	# The floor on two beams.
	for x: float in [-1.0, 1.0]:
		_alp_timber(LARCH, xf * Transform3D(Basis(), Vector3(x * (half - 0.1), high - 0.12, 0)), Vector3(0.12, 0.16, half * 2.0 + 0.3), 2)
	var floor_frame := xf * Transform3D(Basis(), Vector3(0, high - 0.02, 0))
	_alp_timber(LARCH, floor_frame, Vector3(half * 2.0 + 0.1, 0.04, half * 2.0 + 0.1), 2, -1.0, 1.0)
	_collide_box(xf * Transform3D(Basis(), Vector3(0, high - 0.06, 0)), Vector3(half * 2.0 + 0.1, 0.12, half * 2.0 + 0.1), "wood")
	# The parapet, to the chest of whoever stands, on all sides but where
	# the stair comes up at the back; a sill on it to rest a rifle on.
	var stair_wide := 1.6
	var parapet := 1.0
	for out: Vector3 in [Vector3.BACK, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD]:
		var face := _alp_face(xf, out, half + 0.06)
		var spans: Array[Vector2] = [Vector2(-half - 0.06, half + 0.06)]
		if out.z < -0.5:
			spans = [Vector2(-half - 0.06, -stair_wide * 0.5), Vector2(stair_wide * 0.5, half + 0.06)]
		for span in spans:
			var board := face * Transform3D(Basis(), Vector3((span.x + span.y) * 0.5, high + parapet * 0.5, -0.015))
			_alp_timber(LARCH, board, Vector3(span.y - span.x, parapet, 0.03), 1, -1.0, 1.0)
			_collide_box(board, Vector3(span.y - span.x, parapet, 0.06), "wood")
			_alp_timber(LARCH, face * Transform3D(Basis(), Vector3((span.x + span.y) * 0.5, high + parapet + 0.02, -0.06)), Vector3(span.y - span.x, 0.04, 0.16), 0, -1.0, 1.0)
	# The roof: boards falling to the back, under a sheet of tin.
	var slope := atan2(0.25, half * 2.0)
	var roof := xf * Transform3D(Basis(Vector3.RIGHT, -slope), Vector3(0, roof_at + 0.1, 0))
	_alp_timber(LARCH, roof, Vector3(half * 2.0 + 0.7, 0.03, half * 2.0 + 0.8), 2, -1.0, 1.0)
	_alp_timber(TIN, roof * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0.025, 0)), Vector3(half * 2.0 + 0.9, 0.015, half * 2.0 + 0.74), 0, 0.5, 1.0)
	_collide_box(roof, Vector3(half * 2.0 + 0.7, 0.1, half * 2.0 + 0.8), "metal")
	for z: float in [-1.0, 1.0]:
		_alp_timber(LARCH, xf * Transform3D(Basis(), Vector3(0, roof_at + 0.02 - z * 0.12, z * (half - 0.05))), Vector3(half * 2.0 + 0.3, 0.12, 0.1), 0)
	_hunting_stair(xf, Vector3(0, high, -half - 0.06), stair_wide)
	# From afar: the legs, the cabin and its roof.
	for i in 4:
		var top: Vector3 = tops[i]
		var low := Vector3(top.x / half * foot, -0.2, top.z / half * foot)
		_far_box(Transform3D(xf.basis, xf * ((low + top) * 0.5)), Vector3.ZERO, Vector3(0.13, roof_at + 0.2, 0.13), FAR_BOARDS, FAR_BOARDS)
	_far_box(xf, Vector3(0, high + parapet * 0.5, 0), Vector3(half * 2.0 + 0.1, parapet, half * 2.0 + 0.1), FAR_BOARDS, FAR_BOARDS)
	_far_box(xf, Vector3(0, roof_at + 0.12, 0), Vector3(half * 2.0 + 0.7, 0.06, half * 2.0 + 0.8), FAR_ROOFS.tin, FAR_ROOFS.tin)
	_alp_end("hunting_stand", at, _alp_colliders() - colliders)


## The stair of a hunter's stand: from the edge of its floor at `top` down
## and back to the ground, `wide`, at 38 degrees: two strings, treads, and a
## rail on the left. To whoever walks it is a slope.
func _hunting_stair(xf: Transform3D, top: Vector3, wide: float) -> void:
	var steep := deg_to_rad(38.0)
	var run := top.y / tan(steep)
	var reach := xf * Vector3(0, 0, top.z - run)
	var low := ground_height(reach.x, reach.z) - xf.origin.y
	run = (top.y - low) / tan(steep)
	var bottom := Vector3(0, low, top.z - run)
	for x: float in [-1.0, 1.0]:
		var side := Vector3(x * (wide * 0.5 + 0.04), 0, 0)
		_alp_beam(LARCH, xf * (bottom + side + Vector3(0, 0.06, -0.1)), xf * (top + side + Vector3(0, 0.1, 0.05)), 0.06, 0.22)
	var steps := int(round((top.y - low) / 0.32))
	for i in range(1, steps):
		var tread := bottom.lerp(top, float(i) / steps)
		_alp_timber(LARCH, xf * Transform3D(Basis(), tread + Vector3(0, 0.0, 0.04)), Vector3(wide, 0.045, 0.24), 0)
	# The rail, on posts at the foot and the head.
	for at: Vector3 in [bottom + Vector3(-wide * 0.5 - 0.08, 0, 0.2), top + Vector3(-wide * 0.5 - 0.08, 0, 0)]:
		_alp_pole(LARCH, xf * at, xf * (at + Vector3.UP * 1.0), 0.035, -1.0, 5)
	_alp_pole(LARCH, xf * (bottom + Vector3(-wide * 0.5 - 0.08, 0.95, 0.2)), xf * (top + Vector3(-wide * 0.5 - 0.08, 0.95, 0)), 0.03, -1.0, 5)
	var ramp := Transform3D(Basis(Vector3.RIGHT, -steep), (bottom + top) * 0.5 + Vector3(0, -0.05, 0))
	_collide_box(xf * ramp, Vector3(wide, 0.1, (top - bottom).length() + 0.1), "wood")
	_alp_link(xf * (bottom + Vector3(0, 0.05, -0.7)), xf * (top + Vector3(0, 0.05, 0.9)))


# --- Fences, hay, wood ---------------------------------------------------------------


## A fence of Tyrol (Kreuzzaun) along `path` (points x and z): pairs of
## stakes every metre and a half, and between the stakes of each pair split
## laths that lean all the same way, each across the next few, `high` at the
## top. Nobody walks through it; a shot over it goes on.
func slant_fence(path: Array, high := 1.15) -> void:
	var way := curve(path, 1.6)
	var middle: Vector2 = way[way.size() / 2]
	_alp_begin(middle, "small", 23)
	var colliders := _alp_colliders()
	var own := _alp_own
	for i in way.size():
		var at := way[i]
		_alp_block = Vector2i(floori(at.x / ALPINE_BLOCK), floori(at.y / ALPINE_BLOCK))
		var ahead := (way[mini(i + 1, way.size() - 1)] - way[maxi(i - 1, 0)]).normalized()
		var across := Vector3(-ahead.y, 0, ahead.x)
		var foot := ground(at.x, at.y, -0.2)
		for side: float in [-1.0, 1.0]:
			var stake := Transform3D(Basis(Vector3.UP, atan2(ahead.x, ahead.y)) * Basis.from_euler(Vector3(own.randf_range(-0.04, 0.04), 0, own.randf_range(-0.04, 0.04))), foot + across * side * 0.055 + Vector3.UP * (high + 0.35) * 0.5)
			_alp_timber(LARCH, stake, Vector3(0.05, high + 0.35, 0.05), 1, -1.0, SQUEEZE, 2)
		if i == 0:
			continue
		var from := way[i - 1]
		var length := from.distance_to(at)
		var dir := Vector3(at.x - from.x, 0, at.y - from.y).normalized()
		# Laths leaning forward along the fence, three or four to a length,
		# their feet in the grass and their heads over the stakes.
		var laths := int(round(length / 0.38))
		for k in laths:
			var share := (k + own.randf_range(0.3, 0.7)) / laths
			var spot := from.lerp(at, share)
			var base := ground(spot.x, spot.y, 0.05)
			var lean := deg_to_rad(own.randf_range(38.0, 46.0))
			var reach := (high + 0.1) / sin(lean)
			var axis := (dir * cos(lean) + Vector3.UP * sin(lean)).normalized()
			var lath := base + axis * reach * 0.5 - dir * reach * cos(lean) * 0.5
			_alp_timber(LARCH, Transform3D(_along(axis), lath), Vector3(0.075, 0.018, reach), 2, -1.0, SQUEEZE, 2)
		var a := ground(from.x, from.y)
		var b := ground(at.x, at.y)
		_collide_box(Transform3D(Basis.looking_at(dir), (a + b) * 0.5 + Vector3.UP * high * 0.5), Vector3(0.14, high, length), "wood")
	_alp_end("slant_fence, %d m" % roundi(_length_of(way)), middle, _alp_colliders() - colliders)


## A fence of rails along `path`: round posts every two and a half metres
## and `rails` poles between them, the top one `high`. Nobody walks through
## it, and a shot goes between the rails.
func rail_fence(path: Array, rails := 2, high := 1.1) -> void:
	var way := curve(path, 2.5)
	var middle: Vector2 = way[way.size() / 2]
	_alp_begin(middle, "small", 29)
	var colliders := _alp_colliders()
	var own := _alp_own
	var tops: Array[Vector3] = []
	for i in way.size():
		var at := way[i]
		_alp_block = Vector2i(floori(at.x / ALPINE_BLOCK), floori(at.y / ALPINE_BLOCK))
		var foot := ground(at.x, at.y, -0.25)
		var top := foot + Vector3(own.randf_range(-0.03, 0.03), high + 0.38, own.randf_range(-0.03, 0.03))
		_alp_pole(LARCH, foot, top, 0.065, 0.055, 6, true)
		tops.append(top)
		if i == 0:
			continue
		for r in rails:
			var lift := high * (r + 1) / rails - high + 0.25
			var a := tops[i - 1] + Vector3.UP * (lift - 0.05)
			var b := top + Vector3.UP * lift
			_alp_pole(LARCH, a, b, 0.04, 0.035, 5)
			_collide_box(Transform3D(_along(b - a), (a + b) * 0.5), Vector3(0.1, 0.1, a.distance_to(b)), "wood")
	_alp_end("rail_fence, %d m" % roundi(_length_of(way)), middle, _alp_colliders() - colliders)


## A pole hung with hay to dry (Heumandl) at `at`: a stake with two arms
## across it, and the hay heaped round it to over a man's height, thick at
## the foot, narrowing to a head under the end of the stake. It is in the
## way, and stops a shot.
func hay_pole(at: Vector2) -> void:
	_alp_begin(at, "small", 31)
	var colliders := _alp_colliders()
	var own := _alp_own
	var foot := ground(at.x, at.y)
	var high := own.randf_range(1.75, 2.0)
	_alp_pole(LARCH, foot + Vector3.DOWN * 0.3, foot + Vector3.UP * (high + 0.3), 0.04, 0.03, 5)
	# The heap: rings round the stake, each a little out of round.
	var rings: Array[Vector2] = [Vector2(0.5, -0.05), Vector2(0.6, 0.2), Vector2(0.56, 0.65), Vector2(0.46, 1.1), Vector2(0.34, 1.45), Vector2(0.17, high - 0.1), Vector2(0.03, high)]
	var around := 9
	var lumps: Array[float] = []
	for i in around:
		lumps.append(own.randf_range(0.85, 1.15))
	var spin := own.randf() * TAU
	var spot := func(ring: int, step: int) -> Vector3:
		var angle := spin + TAU * step / around
		var r := rings[ring].x * lumps[step % around] * (1.0 if ring < rings.size() - 1 else 1.0)
		return foot + Vector3(cos(angle) * r, rings[ring].y, sin(angle) * r)
	_alp_uv2.x = 0.5
	var st := _tool(HAY, DETAIL | NO_COLLIDE, foot)
	for ring in rings.size() - 1:
		for step in around:
			var p: Array[Vector3] = [spot.call(ring, step + 1), spot.call(ring, step), spot.call(ring + 1, step), spot.call(ring + 1, step + 1)]
			var normals := []
			var uvs := []
			for q in p:
				var out := Vector3(q.x - foot.x, 0.0, q.z - foot.z).normalized()
				var lean := (rings[ring].x - rings[ring + 1].x) / maxf(rings[ring + 1].y - rings[ring].y, 0.05)
				normals.append((out + Vector3.UP * lean).normalized())
				uvs.append(Vector2(atan2(q.z - foot.z, q.x - foot.x) * 0.6, -(q.y - foot.y)))
			_quad(st, p, normals, uvs)
	_collide_cylinder(Transform3D(Basis(), foot + Vector3.UP * high * 0.45), 0.45, high * 0.9, "soft")
	_alp_end("hay_pole", at, _alp_colliders() - colliders)


## A stack of firewood at `at`, `long` along the way `yaw_deg` faces turned
## a quarter to the left, `high` and `deep`: the ends of split logs on its
## two faces, held at either end by stakes, on two bearers, and if `roofed`
## under a roof of boards. It is in the way, and stops a shot.
func woodpile(at: Vector2, yaw_deg: float, long := 3.0, high := 1.5, deep := 0.5, roofed := true) -> void:
	_alp_begin(at, "small", 37)
	var colliders := _alp_colliders()
	_woodpile(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y)), long, high, deep, roofed)
	_alp_end("woodpile", at, _alp_colliders() - colliders)


## The same in the frame `xf`, whose origin is on the ground in the middle of
## the stack and whose X runs along it: as part of whatever is being built.
func _woodpile(xf: Transform3D, long: float, high: float, deep: float, roofed: bool) -> void:
	var under := xf * Vector3.ZERO
	var low := ground_height(under.x, under.z) - xf.origin.y
	var frame := xf * Transform3D(Basis(), Vector3(0, low, 0))
	for z: float in [-1.0, 1.0]:
		_alp_pole(BARK, frame * Vector3(-long * 0.5 - 0.1, 0.06, z * deep * 0.3), frame * Vector3(long * 0.5 + 0.1, 0.06, z * deep * 0.3), 0.06, -1.0, 5)
	var bottom := 0.12
	var h := Vector3(long * 0.5, 0, deep * 0.5)
	# The two faces of ends, and over and at the ends of the stack the round
	# sides of the logs.
	for side: Array in [
		[LOG_ENDS, Vector3.BACK, [Vector3(-h.x, bottom, h.z), Vector3(h.x, bottom, h.z), Vector3(h.x, high, h.z), Vector3(-h.x, high, h.z)]],
		[LOG_ENDS, Vector3.FORWARD, [Vector3(h.x, bottom, -h.z), Vector3(-h.x, bottom, -h.z), Vector3(-h.x, high, -h.z), Vector3(h.x, high, -h.z)]],
		[BARK, Vector3.UP, [Vector3(-h.x, high, h.z), Vector3(h.x, high, h.z), Vector3(h.x, high, -h.z), Vector3(-h.x, high, -h.z)]],
		[BARK, Vector3.RIGHT, [Vector3(h.x, bottom, h.z), Vector3(h.x, bottom, -h.z), Vector3(h.x, high, -h.z), Vector3(h.x, high, h.z)]],
		[BARK, Vector3.LEFT, [Vector3(-h.x, bottom, -h.z), Vector3(-h.x, bottom, h.z), Vector3(-h.x, high, h.z), Vector3(-h.x, high, -h.z)]],
	]:
		var points := []
		var uvs := []
		var normal: Vector3 = frame.basis * (side[1] as Vector3)
		var right := ((side[2][1] as Vector3) - (side[2][0] as Vector3)).normalized()
		var up := ((side[2][3] as Vector3) - (side[2][0] as Vector3)).normalized()
		for corner: Vector3 in side[2]:
			points.append(frame * corner)
			uvs.append(Vector2(corner.dot(right), -corner.dot(up)) + Vector2(frame.origin.x, frame.origin.z))
		_quad(_tool(side[0], DETAIL | NO_COLLIDE, frame.origin), points, [normal, normal, normal, normal], uvs)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			_alp_timber(LARCH, frame * Transform3D(Basis(), Vector3(x * (h.x + 0.04), (high + 0.1) * 0.5 - 0.05, z * (h.z - 0.06))), Vector3(0.06, high + 0.15, 0.06), 1, -1.0, SQUEEZE, 2)
	if roofed:
		var roof := frame * Transform3D(Basis(Vector3.RIGHT, 0.18), Vector3(0, high + 0.12, 0))
		_alp_timber(LARCH, roof, Vector3(long + 0.4, 0.03, deep + 0.4), 0, -1.0, 1.0)
	_collide_box(frame * Transform3D(Basis(), Vector3(0, (high + bottom) * 0.5, 0)), Vector3(long, high - bottom, deep), "wood")


## A bridge of boards over a brook from `from` to `to` (x and z), on the
## banks at either end: two logs laid across, boards nailed over them, and a
## rail on posts either side; a stone under each end of the logs. It lies
## straight from one bank to the other, a hand over each.
func footbridge(from: Vector2, to: Vector2, wide := 1.3) -> void:
	var middle := (from + to) * 0.5
	_alp_begin(middle, "small", 41)
	var colliders := _alp_colliders()
	var a := ground(from.x, from.y, 0.18)
	var b := ground(to.x, to.y, 0.18)
	var along := b - a
	var xf := Transform3D(_along(along), (a + b) * 0.5)
	var length := along.length()
	# In the frame of the bridge -Z runs from `from` to `to`.
	for x: float in [-1.0, 1.0]:
		var side := Vector3(x * (wide * 0.5 - 0.2), -0.16, 0)
		_alp_pole(BARK, xf * (side + Vector3(0, 0, length * 0.5 + 0.5)), xf * (side + Vector3(0, 0, -length * 0.5 - 0.5)), 0.14, 0.12, 7)
		for end: float in [-1.0, 1.0]:
			var stone := xf * (side + Vector3(0, -0.3, end * (length * 0.5 + 0.3)))
			_alp_stone(ROCK, Transform3D(Basis(Vector3.UP, _alp_own.randf_range(0, TAU)), stone), Vector3(0.6, 0.45, 0.6))
	var deck := xf * Transform3D(Basis(), Vector3(0, -0.01, 0))
	_alp_timber(LARCH, deck, Vector3(wide, 0.05, length + 0.6), 0, -1.0, 1.0)
	_collide_box(deck, Vector3(wide, 0.08, length + 0.6), "wood")
	var posts := maxi(int(round(length / 1.6)), 1)
	for x: float in [-1.0, 1.0]:
		var heads: Array[Vector3] = []
		for i in posts + 1:
			var z := -length * 0.5 + length * i / posts
			var post := Vector3(x * (wide * 0.5 + 0.04), 0.0, z)
			_alp_timber(LARCH, xf * Transform3D(Basis(), post + Vector3(0, 0.4, 0)), Vector3(0.08, 1.0, 0.08), 1, -1.0, SQUEEZE, 2)
			heads.append(post + Vector3(0, 0.95, 0))
		_alp_pole(LARCH, xf * heads[0], xf * heads[heads.size() - 1], 0.035, -1.0, 5)
		_collide_box(xf * Transform3D(Basis(), Vector3(x * (wide * 0.5 + 0.04), 0.5, 0)), Vector3(0.08, 1.0, length), "wood")
	_alp_end("footbridge, %d m" % roundi(length), middle, _alp_colliders() - colliders)


# --- Poles and wires -----------------------------------------------------------------


## A line of wooden poles that carries `wires` wires over the land, a pole at
## each of `points` (x and z): poles of dark wood soaked against the rot,
## `high` out of the ground, each with an arm across the line and on it the
## white insulators, and the wires hanging between one pole and the next. A
## pole is seen from further off than a wire; each is in the way.
func pole_line(points: Array, high := 8.0, wires := 3) -> void:
	_alp_begin(points[0], "tall", 43)
	var colliders := _alp_colliders()
	var heads: Array = []
	for i in points.size():
		var at: Vector2 = points[i]
		_alp_block = Vector2i(floori(at.x / ALPINE_BLOCK), floori(at.y / ALPINE_BLOCK))
		var before: Vector2 = points[maxi(i - 1, 0)]
		var after: Vector2 = points[mini(i + 1, points.size() - 1)]
		var ahead := (after - before).normalized()
		var foot := ground(at.x, at.y, -0.5)
		var top := foot + Vector3(_alp_own.randf_range(-0.05, 0.05), high + 0.5, _alp_own.randf_range(-0.05, 0.05))
		_alp_pole(DARK_WOOD, foot, top, 0.14, 0.1, 7, true)
		var across := Vector3(-ahead.y, 0, ahead.x)
		var arm := Transform3D(Basis(across, Vector3.UP, across.cross(Vector3.UP)), top + Vector3.DOWN * 0.35)
		_alp_timber(DARK_WOOD, arm, Vector3(1.7, 0.1, 0.1), 0)
		_alp_beam(DARK_WOOD, top + Vector3.DOWN * 0.9, arm * Vector3(0.55, -0.04, 0), 0.06)
		var own_heads: Array[Vector3] = []
		for w in wires:
			var x := -0.7 + 1.4 * w / maxf(wires - 1, 1)
			var seat := arm * Vector3(x, 0.05, 0)
			_cylinder("porcelain", Transform3D(Basis(), seat), 0.045, 0.14, DETAIL | NO_COLLIDE, 0.03, 6)
			own_heads.append(seat + Vector3.UP * 0.12)
		heads.append(own_heads)
	# The wires, each sagging between one insulator and the next.
	_alp_reach = "wire"
	for i in range(1, points.size()):
		var middle: Vector2 = ((points[i - 1] as Vector2) + (points[i] as Vector2)) * 0.5
		_alp_block = Vector2i(floori(middle.x / ALPINE_BLOCK), floori(middle.y / ALPINE_BLOCK))
		for w in wires:
			var a: Vector3 = heads[i - 1][w]
			var b: Vector3 = heads[i][w]
			_alp_wire(a, b, 0.012 * a.distance_to(b) + 0.25)
	_alp_reach = "tall"
	_alp_end("pole_line, %d poles" % points.size(), points[0], _alp_colliders() - colliders)


## A wire from `a` to `b` that hangs `sag` lower in its middle: a thin bar of
## three sides, bent in a dozen lengths.
func _alp_wire(a: Vector3, b: Vector3, sag: float) -> void:
	var st := _tool("dark_steel", DETAIL | NO_COLLIDE, (a + b) * 0.5)
	var lengths := 12
	var radius := 0.011
	var spots: Array[Vector3] = []
	for i in lengths + 1:
		var t := float(i) / lengths
		spots.append(a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	for i in lengths:
		var p := spots[i]
		var q := spots[i + 1]
		var basis := _up_along(q - p)
		for k in 3:
			var a0 := TAU * k / 3.0
			var a1 := TAU * (k + 1) / 3.0
			var d0 := basis * Vector3(cos(a1), 0, sin(a1))
			var d1 := basis * Vector3(cos(a0), 0, sin(a0))
			_quad(st, [p + d0 * radius, p + d1 * radius, q + d1 * radius, q + d0 * radius], [d0, d1, d1, d0], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


# --- The trough ----------------------------------------------------------------------


## A trough by the way at `at`, `long` along the way `yaw_deg` faces turned a
## quarter to the left: a log hollowed out and lying on two stones, full of
## water, and at one end a post with an iron pipe that runs into it. It is
## in the way, and stops a shot.
func trough(at: Vector2, yaw_deg: float, long := 2.6) -> void:
	_alp_begin(at, "small", 47)
	var colliders := _alp_colliders()
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y))
	var radius := 0.34
	var axis := Vector3(0, radius + 0.08, 0)
	var cut := radius * 0.55
	var wall := 0.07
	var end_wall := 0.12
	var h := long * 0.5
	# The outside, round under the cut, and the inside, as points of the
	# plane across it: x out of its front (+Z), y up. Each runs from the rim
	# at the front down round under it to the rim at the back.
	var outer: Array[Vector2] = []
	var inner: Array[Vector2] = []
	var steps := 10
	for ring: Array in [[outer, radius], [inner, radius - wall]]:
		var r: float = ring[1]
		var rim := asin(cut / r)
		for i in steps + 1:
			var angle := lerpf(rim, -PI - rim, float(i) / steps)
			(ring[0] as Array).append(Vector2(cos(angle), sin(angle)) * r)
	var at_x := func(x: float, p: Vector2) -> Vector3: return xf * (axis + Vector3(x, p.y, p.x))
	var hi := h - end_wall
	var wood := _tool(LARCH, DETAIL | NO_COLLIDE, xf.origin)
	var wet := _tool(DARK_WOOD, DETAIL | NO_COLLIDE, xf.origin)
	wood.set_uv2(Vector2(0.3, _alp_uv2.y))
	wet.set_uv2(Vector2(0.7, _alp_uv2.y))
	for i in steps:
		var p := outer[i]
		var q := outer[i + 1]
		var np := xf.basis * Vector3(0, p.y, p.x).normalized()
		var nq := xf.basis * Vector3(0, q.y, q.x).normalized()
		_quad(wood, [at_x.call(h, p), at_x.call(-h, p), at_x.call(-h, q), at_x.call(h, q)], [np, np, nq, nq], [Vector2(i * 0.11, -long), Vector2(i * 0.11, 0), Vector2((i + 1) * 0.11, 0), Vector2((i + 1) * 0.11, -long)])
		p = inner[i]
		q = inner[i + 1]
		np = xf.basis * -Vector3(0, p.y, p.x).normalized()
		nq = xf.basis * -Vector3(0, q.y, q.x).normalized()
		_quad(wet, [at_x.call(-hi, p), at_x.call(hi, p), at_x.call(hi, q), at_x.call(-hi, q)], [np, np, nq, nq], [Vector2(i * 0.1, 0), Vector2(i * 0.1, -long), Vector2((i + 1) * 0.1, -long), Vector2((i + 1) * 0.1, 0)])
	# The rims along the top, front and back, and the tops of its ends.
	var up := xf.basis.y
	var front := [outer[0], inner[0]]
	var back := [inner[steps], outer[steps]]
	for rim: Array in [front, back]:
		_quad(wood, [at_x.call(-h, rim[0]), at_x.call(h, rim[0]), at_x.call(h, rim[1]), at_x.call(-h, rim[1])], [up, up, up, up], [Vector2(0, 0), Vector2(long, 0), Vector2(long, 0.07), Vector2(0, 0.07)])
	for span: Vector2 in [Vector2(hi, h), Vector2(-h, -hi)]:
		_quad(wood, [at_x.call(span.x, inner[0]), at_x.call(span.y, inner[0]), at_x.call(span.y, inner[steps]), at_x.call(span.x, inner[steps])], [up, up, up, up], [Vector2(0, 0), Vector2(0.1, 0), Vector2(0.1, 0.4), Vector2(0, 0.4)])
	# The ends, which show the rings of the log, and the ends of the hollow.
	wood.set_uv2(Vector2(2.3, _alp_uv2.y))
	for end: float in [-1.0, 1.0]:
		for ring: Array in [[outer, h, wood, 1.0], [inner, hi, wet, -1.0]]:
			var points: Array[Vector2] = ring[0]
			var x: float = end * float(ring[1])
			var faces: float = end * float(ring[3])
			var normal := xf.basis * Vector3(faces, 0, 0)
			var centre := Vector2(0, cut)
			for i in steps:
				var tri := [at_x.call(x, centre), at_x.call(x, points[i]), at_x.call(x, points[i + 1])]
				var uvs := [Vector2(0, -cut), Vector2(points[i].x, -points[i].y), Vector2(points[i + 1].x, -points[i + 1].y)]
				if faces < 0.0:
					tri = [tri[0], tri[2], tri[1]]
					uvs = [uvs[0], uvs[2], uvs[1]]
				_tri(ring[2], tri, [normal, normal, normal], uvs)
	wood.set_uv2(_alp_uv2)
	wet.set_uv2(_alp_uv2)
	# The water, a hand under the rim.
	var level := cut - 0.08
	var spread := sqrt(pow(radius - wall, 2.0) - level * level)
	var water := _tool(WATER, DETAIL | NO_COLLIDE, xf.origin)
	_quad(water, [xf * (axis + Vector3(-hi, level, spread)), xf * (axis + Vector3(hi, level, spread)), xf * (axis + Vector3(hi, level, -spread)), xf * (axis + Vector3(-hi, level, -spread))], [up, up, up, up], [Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	# The stones it lies on, and the post with the pipe at its far end.
	for x: float in [-0.6, 0.6]:
		_alp_stone(ROCK, xf * Transform3D(Basis(Vector3.UP, _alp_own.randf()), Vector3(x * long, 0.04, 0)), Vector3(0.4, 0.22, 0.6))
	var post := xf * Transform3D(Basis(), Vector3(h + 0.18, 0.55, 0))
	_alp_timber(LARCH, post, Vector3(0.16, 1.4, 0.16), 1, -1.0, SQUEEZE, 2)
	var spout := xf * Vector3(h - 0.25, axis.y + cut + 0.35, 0)
	hose("dark_steel", PackedVector3Array([xf * Vector3(h + 0.18, axis.y + cut + 0.4, 0), xf * Vector3(h - 0.05, axis.y + cut + 0.4, 0), spout]), 0.022, DETAIL | NO_COLLIDE, 6)
	# The water that runs from it.
	var stream := _tool(WATER, DETAIL | NO_COLLIDE, spout)
	var fall := xf * Vector3(h - 0.3, axis.y + level, 0)
	var side := xf.basis.z * 0.012
	var facing := xf.basis.x
	_quad(stream, [fall - side, fall + side, spout + side, spout - side], [facing, facing, facing, facing], [Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	_quad(stream, [fall + side, fall - side, spout - side, spout + side], [-facing, -facing, -facing, -facing], [Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	_collide_box(xf * Transform3D(Basis(), Vector3(0, (axis.y + cut) * 0.5, 0)), Vector3(long, axis.y + cut, radius * 2.0), "wood")
	_collide_box(post, Vector3(0.16, 1.4, 0.16), "wood")
	_alp_end("trough", at, _alp_colliders() - colliders)
