extends RefCounted
## The shapes of what is on sale, made here in code when a level with goods
## loads: a metre each way, standing on its base with the middle of that base
## at the origin and its front towards +Z. scripts/goods.gd scales one to the
## size of a product. They are few and small, since a shop holds tens of
## thousands of them.
##
## How a shape wears its cell of the sheet of labels (see tools/gen_goods.py):
## a box has the cell on its front and back, and its left edge on the sides, the
## top and the bottom. What is turned round an axis has the cell twice round,
## once on each half, with the top of the cell at the top of the shape, so that
## the label reads the same from either side. A bag has it on both sides, a
## tray on top. What grows has it all over.

## How much of a cell is left unused along its edges: the mipmaps of a label
## would otherwise bleed into the one next to it.
const INSET := 0.012
## A shape's own list of points from the top down, for what is turned: how far
## from the axis, how high, and where on the cell from the top. A point with a
## v of its own is a sharp edge there.
const CAN: Array[Vector3] = [
	Vector3(0.0, 1.0, 0.0), Vector3(0.44, 1.0, 0.03), Vector3(0.5, 0.95, 0.07), Vector3(0.5, 0.05, 0.93), Vector3(0.44, 0.0, 0.97), Vector3(0.0, 0.0, 1.0),
]
const BOTTLE: Array[Vector3] = [
	Vector3(0.0, 1.0, 0.0), Vector3(0.19, 1.0, 0.02), Vector3(0.19, 0.92, 0.09), Vector3(0.36, 0.78, 0.28),
	Vector3(0.5, 0.6, 0.4), Vector3(0.5, 0.08, 0.88), Vector3(0.42, 0.0, 0.97), Vector3(0.0, 0.0, 1.0),
]
const WINE: Array[Vector3] = [
	Vector3(0.0, 1.0, 0.0), Vector3(0.17, 1.0, 0.02), Vector3(0.15, 0.74, 0.28), Vector3(0.38, 0.64, 0.34),
	Vector3(0.5, 0.54, 0.4), Vector3(0.5, 0.02, 0.97), Vector3(0.0, 0.0, 1.0),
]
const JAR: Array[Vector3] = [
	Vector3(0.0, 1.0, 0.0), Vector3(0.44, 1.0, 0.04), Vector3(0.44, 0.86, 0.1), Vector3(0.5, 0.8, 0.14), Vector3(0.5, 0.05, 0.92), Vector3(0.0, 0.0, 1.0),
]
const TUB: Array[Vector3] = [
	Vector3(0.0, 0.97, 0.0), Vector3(0.5, 0.98, 0.06), Vector3(0.5, 0.9, 0.09), Vector3(0.4, 0.0, 0.95), Vector3(0.0, 0.0, 1.0),
]
const WHEEL: Array[Vector3] = [
	Vector3(0.0, 1.0, 0.0), Vector3(0.45, 1.0, 0.45), Vector3(0.5, 0.82, 0.5), Vector3(0.5, 0.18, 0.5), Vector3(0.45, 0.0, 0.55), Vector3(0.0, 0.0, 1.0),
]
const ROUND: Array[Vector3] = [
	Vector3(0.0, 0.93, 0.02), Vector3(0.28, 0.99, 0.16), Vector3(0.47, 0.76, 0.34), Vector3(0.48, 0.34, 0.62), Vector3(0.26, 0.04, 0.86), Vector3(0.0, 0.03, 1.0),
]
const LONG: Array[Vector3] = [
	Vector3(0.0, 1.0, 0.0), Vector3(0.36, 0.96, 0.14), Vector3(0.5, 0.82, 0.32), Vector3(0.5, 0.18, 0.68), Vector3(0.36, 0.04, 0.86), Vector3(0.0, 0.0, 1.0),
]
const HEAD: Array[Vector3] = [
	Vector3(0.0, 1.0, 0.0), Vector3(0.3, 0.94, 0.2), Vector3(0.48, 0.66, 0.42), Vector3(0.46, 0.28, 0.68), Vector3(0.24, 0.03, 0.88), Vector3(0.0, 0.0, 1.0),
]
## The same from further off: a few sides, no ends to speak of.
const FAR_UPRIGHT: Array[Vector3] = [Vector3(0.0, 1.0, 0.0), Vector3(0.5, 0.92, 0.08), Vector3(0.5, 0.0, 1.0)]
const FAR_BOTTLE: Array[Vector3] = [Vector3(0.16, 1.0, 0.02), Vector3(0.5, 0.62, 0.38), Vector3(0.5, 0.0, 1.0)]
const FAR_ROUND: Array[Vector3] = [Vector3(0.0, 1.0, 0.0), Vector3(0.5, 0.55, 0.5), Vector3(0.0, 0.0, 1.0)]
## What a far shape is made of, by shape. A shape that is not here has no
## cheaper form.
const FAR := {
	"can": [FAR_UPRIGHT, 6], "jar": [FAR_UPRIGHT, 6], "tub": [FAR_UPRIGHT, 6], "wheel": [FAR_UPRIGHT, 6],
	"bottle": [FAR_BOTTLE, 6], "wine": [FAR_BOTTLE, 6], "jug": [FAR_UPRIGHT, 4],
	"round": [FAR_ROUND, 5], "long": [FAR_ROUND, 4], "head": [FAR_ROUND, 5],
}

static var _made := {}


## Whether a shape has a cheaper form for further off, far().
static func has_far(shape: String) -> bool:
	return FAR.has(shape)


## The cheaper form of a shape.
static func far(shape: String) -> ArrayMesh:
	var key := "far " + shape
	if _made.has(key):
		return _made[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_turned(st, FAR[shape][0], FAR[shape][1])
	st.index()
	st.generate_normals()
	var made := st.commit()
	_made[key] = made
	return made


## The mesh of a shape, made the first time it is asked for.
static func mesh(shape: String) -> ArrayMesh:
	if _made.has(shape):
		return _made[shape]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match shape:
		"box":
			_box(st)
		"can":
			_turned(st, CAN, 8)
		"bottle":
			_turned(st, BOTTLE, 8)
		"wine":
			_turned(st, WINE, 8)
		"jar":
			_turned(st, JAR, 8)
		"tub":
			_turned(st, TUB, 8)
		"wheel":
			_turned(st, WHEEL, 12)
		"round":
			_turned(st, ROUND, 8)
		"long":
			_turned(st, LONG, 6)
		"head":
			_turned(st, HEAD, 8, 0.09)
		"jug":
			_jug(st)
		"bag":
			_bag(st)
		"tray":
			_tray(st)
		"wedge":
			_wedge(st)
		"scrap":
			_scrap(st)
		"chunk":
			_chunk(st)
		"shard":
			_shard(st)
		"drop":
			_drop(st)
		_:
			push_error("No shape called %s" % shape)
	st.index()
	st.generate_normals()
	var made := st.commit()
	_made[shape] = made
	return made


## How far the middle of a shape lies above its base, as a share of its height.
static func middle(_shape: String) -> float:
	return 0.5


## The point on the cell for `uv`, kept off its edges.
static func _in(uv: Vector2) -> Vector2:
	return uv * (1.0 - INSET * 2.0) + Vector2(INSET, INSET)


static func _corner(st: SurfaceTool, at: Vector3, uv: Vector2, group := 0) -> void:
	st.set_smooth_group(group)
	st.set_uv(_in(uv))
	st.add_vertex(at)


## Two triangles, going round a, b, c, d seen from outside. A group of -1
## gives every face its own edge.
static func _face(st: SurfaceTool, p: Array[Vector3], uv: Array[Vector2], group := -1) -> void:
	for i: int in [0, 1, 2, 0, 2, 3]:
		_corner(st, p[i], uv[i], group)


static func _box(st: SurfaceTool) -> void:
	var a := Vector3(-0.5, 0, -0.5)
	var b := Vector3(0.5, 0, -0.5)
	var c := Vector3(0.5, 0, 0.5)
	var d := Vector3(-0.5, 0, 0.5)
	var up := Vector3.UP
	var whole: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var edge: Array[Vector2] = [Vector2(0.0, 0), Vector2(0.05, 0), Vector2(0.05, 1), Vector2(0.0, 1)]
	_face(st, [d + up, c + up, c, d], whole)
	_face(st, [b + up, a + up, a, b], whole)
	_face(st, [c + up, b + up, b, c], edge)
	_face(st, [a + up, d + up, d, a], edge)
	_face(st, [a + up, b + up, c + up, d + up], edge)
	_face(st, [d, c, b, a], edge)


## A body turned round its upright: `profile` from the top down, as CAN is,
## with `sides` sides, wearing the cell once on each half. `lumps` pushes its
## ring in and out, for what grew.
static func _turned(st: SurfaceTool, profile: Array[Vector3], sides: int, lumps := 0.0) -> void:
	var half := sides / 2
	for side in 2:
		for ring in profile.size() - 1:
			var top := profile[ring]
			var foot := profile[ring + 1]
			for i in half:
				var a0 := (float(i) / half + side) * PI
				var a1 := (float(i + 1) / half + side) * PI
				var u0 := float(i) / half
				var u1 := float(i + 1) / half
				var quad: Array[Vector3] = [
					_on_ring(top, a0, ring, lumps), _on_ring(top, a1, ring, lumps),
					_on_ring(foot, a1, ring + 1, lumps), _on_ring(foot, a0, ring + 1, lumps),
				]
				var uv: Array[Vector2] = [Vector2(u0, top.z), Vector2(u1, top.z), Vector2(u1, foot.z), Vector2(u0, foot.z)]
				_face(st, quad, uv, 1)


static func _on_ring(point: Vector3, angle: float, ring: int, lumps: float) -> Vector3:
	var reach := point.x * (1.0 + lumps * sin(angle * 3.0 + ring * 1.7) + lumps * 0.6 * sin(angle * 5.0 - ring * 2.3))
	return Vector3(sin(angle) * reach, point.y, cos(angle) * reach)


## A jug: a body with square shoulders, a neck with a cap and a handle on the
## side of it that shows on a shelf.
static func _jug(st: SurfaceTool) -> void:
	const RINGS: Array[Vector3] = [
		Vector3(0.0, 1.0, 0.0), Vector3(0.14, 1.0, 0.02), Vector3(0.14, 0.92, 0.07), Vector3(0.16, 0.88, 0.1),
		Vector3(0.36, 0.72, 0.2), Vector3(0.5, 0.6, 0.31), Vector3(0.5, 0.05, 0.92), Vector3(0.44, 0.0, 0.97), Vector3(0.0, 0.0, 1.0),
	]
	const SIDES := 8
	var half := SIDES / 2
	for side in 2:
		for ring in RINGS.size() - 1:
			var top := RINGS[ring]
			var foot := RINGS[ring + 1]
			for i in half:
				var a0 := (float(i) / half + side) * PI
				var a1 := (float(i + 1) / half + side) * PI
				var u0 := float(i) / half
				var u1 := float(i + 1) / half
				var quad: Array[Vector3] = [_squared(top, a0), _squared(top, a1), _squared(foot, a1), _squared(foot, a0)]
				_face(st, quad, [Vector2(u0, top.z), Vector2(u1, top.z), Vector2(u1, foot.z), Vector2(u0, foot.z)], 1)
	# The handle stands out from the shoulder; it reads as one against a row.
	var a := Vector3(0.4, 0.58, -0.1)
	var b := Vector3(0.5, 0.58, -0.1)
	var c := Vector3(0.5, 0.83, -0.1)
	var d := Vector3(0.3, 0.83, -0.1)
	var depth := Vector3(0, 0, 0.2)
	var edge: Array[Vector2] = [Vector2(0.5, 0.05), Vector2(0.55, 0.05), Vector2(0.55, 0.1), Vector2(0.5, 0.1)]
	_face(st, [d + depth, c + depth, b + depth, a + depth], edge)
	_face(st, [a, b, c, d], edge)
	_face(st, [c + depth, c, b, b + depth], edge)
	_face(st, [d, d + depth, a + depth, a], edge)


## A ring pushed out towards a square, the shape a jug is blown in.
static func _squared(point: Vector3, angle: float) -> Vector3:
	var s := sin(angle)
	var c := cos(angle)
	var square := 1.0 / maxf(absf(s), absf(c)) if point.x >= 0.3 else 1.0
	var reach := point.x * lerpf(1.0, square, 0.72) * 0.86
	return Vector3(s * reach, point.y, c * reach)


## A bag: a pillow that is sealed along the top and the bottom. Its faces are a
## grid that bulges, and they meet in the seams.
static func _bag(st: SurfaceTool) -> void:
	const ACROSS := 3
	const UP := 3
	for side: float in [1.0, -1.0]:
		for i in ACROSS:
			for j in UP:
				var u0 := float(i) / ACROSS
				var u1 := float(i + 1) / ACROSS
				var v0 := float(j) / UP
				var v1 := float(j + 1) / UP
				var quad: Array[Vector3] = [_bulge(u0, v0, side), _bulge(u1, v0, side), _bulge(u1, v1, side), _bulge(u0, v1, side)]
				var uv: Array[Vector2] = [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]
				if side < 0.0:
					quad = [quad[1], quad[0], quad[3], quad[2]]
					uv = [uv[1], uv[0], uv[3], uv[2]]
				_face(st, quad, uv, 1)


static func _bulge(u: float, v: float, side: float) -> Vector3:
	var across := sin(u * PI)
	var along := sin(v * PI)
	return Vector3((u - 0.5) * (1.0 - 0.06 * along * along), 1.0 - v, side * 0.5 * pow(across * along, 0.55))


## A tray with what is in it under film: the rim, and the top that rises to
## the middle.
static func _tray(st: SurfaceTool) -> void:
	const ACROSS := 2
	for i in ACROSS:
		for j in ACROSS:
			var u0 := float(i) / ACROSS
			var u1 := float(i + 1) / ACROSS
			var v0 := float(j) / ACROSS
			var v1 := float(j + 1) / ACROSS
			_face(st, [_film(u0, v0), _film(u1, v0), _film(u1, v1), _film(u0, v1)], [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)], 1)
	var a := Vector3(-0.5, 0.5, -0.5)
	var b := Vector3(0.5, 0.5, -0.5)
	var c := Vector3(0.5, 0.5, 0.5)
	var d := Vector3(-0.5, 0.5, 0.5)
	var low := Vector3(0.94, 0.0, 0.94)
	var rim: Array[Vector2] = [Vector2(0.0, 0.5), Vector2(0.03, 0.5), Vector2(0.03, 0.53), Vector2(0.0, 0.53)]
	_face(st, [d, c, Vector3(c.x, 0, c.z) * low, Vector3(d.x, 0, d.z) * low], rim)
	_face(st, [c, b, Vector3(b.x, 0, b.z) * low, Vector3(c.x, 0, c.z) * low], rim)
	_face(st, [b, a, Vector3(a.x, 0, a.z) * low, Vector3(b.x, 0, b.z) * low], rim)
	_face(st, [a, d, Vector3(d.x, 0, d.z) * low, Vector3(a.x, 0, a.z) * low], rim)


static func _film(u: float, v: float) -> Vector3:
	var rise := pow(sin(u * PI) * sin(v * PI), 0.5)
	return Vector3(u - 0.5, 0.5 + 0.5 * rise, v - 0.5)


## A wedge out of a wheel: the point towards the front, the rind at the back.
static func _wedge(st: SurfaceTool) -> void:
	var tip := Vector3(0, 0, 0.5)
	var left := Vector3(-0.5, 0, -0.5)
	var right := Vector3(0.5, 0, -0.5)
	var up := Vector3.UP
	var cut: Array[Vector2] = [Vector2(0.2, 0.2), Vector2(0.8, 0.2), Vector2(0.8, 0.8), Vector2(0.2, 0.8)]
	var rind: Array[Vector2] = [Vector2(0, 0), Vector2(0.04, 0), Vector2(0.04, 0.04), Vector2(0, 0.04)]
	_face(st, [tip + up, right + up, right, tip], cut)
	_face(st, [left + up, tip + up, tip, left], cut)
	_face(st, [right + up, left + up, left, right], rind)
	_corner(st, left + up, Vector2(0.1, 0.9))
	_corner(st, right + up, Vector2(0.9, 0.9))
	_corner(st, tip + up, Vector2(0.5, 0.1))
	_corner(st, tip, Vector2(0.5, 0.1))
	_corner(st, right, Vector2(0.9, 0.9))
	_corner(st, left, Vector2(0.1, 0.9))


## A torn bit of card or plastic: two sheets bent along a line.
static func _scrap(st: SurfaceTool) -> void:
	var a := Vector3(-0.5, 0.0, -0.4)
	var b := Vector3(0.05, 0.3, -0.5)
	var c := Vector3(0.5, 0.05, -0.2)
	var d := Vector3(0.4, 0.0, 0.5)
	var e := Vector3(-0.1, 0.3, 0.42)
	var f := Vector3(-0.5, 0.05, 0.3)
	for corners: Array in [[a, b, e, f], [b, c, d, e]]:
		var side: Array[Vector3] = []
		side.assign(corners)
		var uv: Array[Vector2] = [Vector2(0.1, 0.1), Vector2(0.9, 0.2), Vector2(0.8, 0.9), Vector2(0.2, 0.8)]
		_face(st, side, uv)
		_face(st, [side[3], side[2], side[1], side[0]], [uv[3], uv[2], uv[1], uv[0]])


## A lump of something that grew, or of cheese.
static func _chunk(st: SurfaceTool) -> void:
	var p: Array[Vector3] = [
		Vector3(0.1, 1.0, 0.05), Vector3(-0.45, 0.55, 0.3), Vector3(0.5, 0.6, 0.25), Vector3(0.05, 0.45, -0.5),
		Vector3(-0.3, 0.0, 0.15), Vector3(0.35, 0.05, 0.1),
	]
	for face: Array in [[0, 1, 2], [0, 2, 3], [0, 3, 1], [1, 4, 5], [1, 5, 2], [2, 5, 3], [3, 5, 4], [3, 4, 1]]:
		_corner(st, p[face[0]], Vector2(0.3, 0.3))
		_corner(st, p[face[2]], Vector2(0.7, 0.4))
		_corner(st, p[face[1]], Vector2(0.5, 0.8))


## A shard of glass.
static func _shard(st: SurfaceTool) -> void:
	var a := Vector3(-0.5, 0.02, -0.15)
	var b := Vector3(0.45, 0.0, -0.45)
	var c := Vector3(0.3, 0.08, 0.5)
	var uv: Array[Vector2] = [Vector2(0.2, 0.5), Vector2(0.5, 0.45), Vector2(0.45, 0.55)]
	_corner(st, a, uv[0])
	_corner(st, b, uv[1])
	_corner(st, c, uv[2])
	_corner(st, c, uv[2])
	_corner(st, b, uv[1])
	_corner(st, a, uv[0])


## A drop of whatever came out.
static func _drop(st: SurfaceTool) -> void:
	var top := Vector3(0, 1, 0)
	var foot := Vector3.ZERO
	var ring: Array[Vector3] = [Vector3(0.5, 0.5, 0), Vector3(0, 0.5, 0.5), Vector3(-0.5, 0.5, 0), Vector3(0, 0.5, -0.5)]
	var uv := Vector2(0.5, 0.5)
	for i in 4:
		var a := ring[i]
		var b := ring[(i + 1) % 4]
		for p: Vector3 in [top, a, b, foot, b, a]:
			_corner(st, p, uv, 1)
