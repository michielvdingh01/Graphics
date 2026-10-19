extends RefCounted
## Meshes of land out of a grid of heights, for land of kilometres: in square
## blocks, each block three times, finer for close by and coarser for far
## off, so that what is drawn of the land is about as dense on the screen
## near and far. Each mesh has a skirt along its edges that hangs down, so
## that where a fine block meets a coarse one no sky shows through the seam.
##
## The grid is a row after row of heights (north to south), `cell` metres
## apart, its first at `origin` (x and z). Every vertex gets the normal of
## the full grid where it stands, so that a coarse block is lit as the fine
## one is.

## How far a skirt hangs below its edge, for a block of each step: the most
## a coarse edge can lie above the fine one beside it.
const SKIRT_PER_STEP := 1.6

var heights := PackedFloat32Array()
var across := 0
var down := 0
var cell := 1.0
var origin := Vector2.ZERO
var _normals := PackedVector3Array()


func _init(grid: PackedFloat32Array, columns: int, rows: int, spacing: float, at: Vector2) -> void:
	heights = grid
	across = columns
	down = rows
	cell = spacing
	origin = at
	_normals.resize(across * down)
	for row in down:
		for column in across:
			var west := heights[row * across + maxi(column - 1, 0)]
			var east := heights[row * across + mini(column + 1, across - 1)]
			var north := heights[maxi(row - 1, 0) * across + column]
			var south := heights[mini(row + 1, down - 1) * across + column]
			_normals[row * across + column] = Vector3(west - east, 2.0 * cell, north - south).normalized()


## The height at (column, row) of the grid, clamped to its edge.
func height(column: int, row: int) -> float:
	return heights[clampi(row, 0, down - 1) * across + clampi(column, 0, across - 1)]


## Where (column, row) of the grid lies.
func spot(column: int, row: int) -> Vector3:
	return Vector3(origin.x + column * cell, height(column, row), origin.y + row * cell)


## The mesh of the block whose first column and row are (`c0`, `r0`), `size`
## cells each way, taking every `step`-th height of the grid, with a skirt of
## its own. What lies in `hole` (x and z) is left out: the land inside a ring
## of what lies round it. Null if nothing of the block is left.
func block(c0: int, r0: int, size: int, step: int, hole := Rect2()) -> ArrayMesh:
	var c1 := mini(c0 + size, across - 1)
	var r1 := mini(r0 + size, down - 1)
	if c1 <= c0 or r1 <= r0:
		return null
	var columns: Array[int] = []
	for c in range(c0, c1, step):
		columns.append(c)
	columns.append(c1)
	var rows: Array[int] = []
	for r in range(r0, r1, step):
		rows.append(r)
	rows.append(r1)
	var points := PackedVector3Array()
	var facing := PackedVector3Array()
	var uvs := PackedVector2Array()
	var corners := PackedInt32Array()
	for r in rows:
		for c in columns:
			var p := spot(c, r)
			points.append(p)
			facing.append(_normals[r * across + c])
			uvs.append(Vector2(p.x, p.z))
	var w := columns.size()
	for j in rows.size() - 1:
		for i in w - 1:
			var nw := j * w + i
			if hole.has_area() and hole.has_point((uvs[nw] + uvs[nw + w + 1]) * 0.5):
				continue
			corners.append_array([nw, nw + w + 1, nw + w, nw, nw + 1, nw + w + 1])
	if corners.is_empty():
		return null
	# The skirt: every edge vertex again, hanging down, and a strip between
	# the two facing out of the block.
	var hang := SKIRT_PER_STEP * step * cell
	var edges: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
	for i in w:
		edges[0].append(i)  # north, west to east
		edges[2].append((rows.size() - 1) * w + (w - 1 - i))  # south, east to west
	for j in rows.size():
		edges[1].append(j * w + w - 1)  # east, north to south
		edges[3].append((rows.size() - 1 - j) * w)  # west, south to north
	for edge in edges:
		var first := points.size()
		for k in edge.size():
			points.append(points[edge[k]] - Vector3(0, hang, 0))
			facing.append(facing[edge[k]])
			uvs.append(uvs[edge[k]])
		for k in edge.size() - 1:
			var a := edge[k]
			var b := edge[k + 1]
			if hole.has_area() and hole.grow(-0.01).has_point((uvs[a] + uvs[b]) * 0.5):
				continue
			var a2 := first + k
			var b2 := first + k + 1
			# Seen from outside the block, going round it clockwise from above.
			corners.append_array([a, a2, b, b, a2, b2])
	# The material reads where a spot lies from the spot itself: no UV. And
	# the positions and normals are packed to sixteen bits, which within a
	# block is millimetres.
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = facing
	arrays[Mesh.ARRAY_INDEX] = corners
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
	return mesh


## A flat grid of `size` cells each way, every `step`-th of them, `cell`
## metres apart, with a skirt round it: the shape of every block of the land,
## which the ground material lifts to the heights of the land where it is
## drawn (see shaders/alps_ground.gdshader). The skirt's corners have red in
## their colour; the material hangs them `step` times SKIRT_PER_STEP cells
## down. One such mesh serves every block of the land at that step.
static func flat(size: int, step: int, cell: float) -> ArrayMesh:
	var n := size / step + 1
	var points := PackedVector3Array()
	var marks := PackedColorArray()
	var corners := PackedInt32Array()
	for j in n:
		for i in n:
			points.append(Vector3(i * step * cell, 0.0, j * step * cell))
			marks.append(Color(0, 0, 0))
	for j in n - 1:
		for i in n - 1:
			var nw := j * n + i
			corners.append_array([nw, nw + n + 1, nw + n, nw, nw + 1, nw + n + 1])
	var edges: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
	for i in n:
		edges[0].append(i)
		edges[2].append((n - 1) * n + (n - 1 - i))
		edges[1].append(i * n + n - 1)
		edges[3].append((n - 1 - i) * n)
	for edge in edges:
		var first := points.size()
		for k in edge.size():
			points.append(points[edge[k]])
			marks.append(Color(1, 0, 0))
		for k in edge.size() - 1:
			corners.append_array([edge[k], first + k, edge[k + 1], edge[k + 1], first + k, first + k + 1])
	var normals := PackedVector3Array()
	normals.resize(points.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = marks
	arrays[Mesh.ARRAY_INDEX] = corners
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
