extends "res://tools/levels/alps/plan.gd"
## The villages round the land, Lermoos in the west and Ehrwald in the east,
## as they are seen from it: a house wherever the aerial photograph is built
## up close together, and a church where most of them stand. Nobody comes
## there, and none of it is in anybody's way: each house is a few faces
## coloured by their vertices, a house of Tyrol with its walls plastered white
## below and boarded dark above, under a low roof that reaches out far, and
## shaders/alps_house_far.gdshader lights them as the ground round them is lit.

## The villages: a name, the rectangle of the land (x and z) they lie in, and
## the turn of their streets, in degrees.
const VILLAGES := [
	["Lermoos", Rect2(-950, 940, 1300, 980), -8.0],
	["Ehrwald", Rect2(1850, -120, 1050, 2450), 12.0],
]
## How far apart houses may stand at most, about; how close to the land the
## nearest may stand, in metres; and how much of the photograph round a spot
## must be built on for a house to stand there.
const HOUSE_CELL := 21.0
const KEEP_OFF := 100.0
const BUILT_UP := 0.6
## The houses go into meshes of squares this large.
const CHUNK := 512.0

## The colours, as they look: plaster, boards, roofs.
const PLASTER := [Color(0.88, 0.86, 0.81), Color(0.92, 0.9, 0.84), Color(0.84, 0.8, 0.72)]
const BOARDS := [Color(0.33, 0.22, 0.14), Color(0.4, 0.27, 0.17), Color(0.27, 0.19, 0.13)]
const ROOFS := [Color(0.24, 0.22, 0.21), Color(0.36, 0.2, 0.14), Color(0.3, 0.27, 0.24), Color(0.42, 0.25, 0.17)]
const SPIRE := Color(0.2, 0.26, 0.23)

var _village_chunks := {}


func _describe() -> void:
	in_zone("")
	if not _read_photo():
		return
	var began := Time.get_ticks_msec()
	var look := ShaderMaterial.new()
	look.shader = load("res://shaders/alps_house_far.gdshader")
	if not _far_maps.is_empty():
		look.set_shader_parameter("far_a", _far_maps[0])
		look.set_shader_parameter("far_rect", _far_rect)
	if not _mid_maps.is_empty():
		look.set_shader_parameter("mid_b", _mid_maps[1])
		look.set_shader_parameter("mid_rect", _mid_rect)
	var houses := 0
	for village: Array in VILLAGES:
		var area: Rect2 = village[1]
		var streets: float = village[2]
		var dice := RandomNumberGenerator.new()
		dice.seed = hash(village[0])
		var most := -1.0
		var middle := Vector2()
		var z := area.position.y
		while z < area.end.y:
			var x := area.position.x
			while x < area.end.x:
				var at := Vector2(x, z) + Vector2(dice.randf_range(-0.3, 0.3), dice.randf_range(-0.3, 0.3)) * HOUSE_CELL
				x += HOUSE_CELL
				if LAND.grow(KEEP_OFF).has_point(at):
					continue
				var share := _village_built_share(at, 14.0)
				if share < BUILT_UP:
					continue
				var foot := altitude(at.x, at.y)
				var fall := absf(altitude(at.x + 8.0, at.y) - altitude(at.x - 8.0, at.y)) + absf(altitude(at.x, at.y + 8.0) - altitude(at.x, at.y - 8.0))
				if fall > 7.0 or foot + SEA > 1150.0:
					continue
				if share > most:
					most = share
					middle = at
				var turn := streets + (0.0 if dice.randf() < 0.5 else 90.0) + dice.randf_range(-8.0, 8.0)
				_village_house(at, foot, turn, dice)
				houses += 1
			z += HOUSE_CELL
		if most > 0.0:
			_village_church(middle, altitude(middle.x, middle.y), streets, dice)
	for key: Vector2i in _village_chunks:
		var tool: SurfaceTool = _village_chunks[key]
		lay_mesh(tool.commit(), look, 0.0, 9000.0, true)
	print("Villages: %d houses in %d meshes, in %.1f s" % [houses, _village_chunks.size(), (Time.get_ticks_msec() - began) / 1000.0])


## How much of the photograph within `radius` of `at` is built on.
func _village_built_share(at: Vector2, radius: float) -> float:
	var dot := (at - _photo_origin) / PHOTO_CELL
	var reach := int(ceilf(radius / PHOTO_CELL))
	var built := 0
	var all := 0
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if dx * dx + dy * dy > reach * reach:
				continue
			var c := int(dot.x) + dx
			var r := int(dot.y) + dy
			if c < 0 or r < 0 or c >= _photo_size.x or r >= _photo_size.y:
				continue
			all += 1
			built += _photo_built[r * _photo_size.x + c]
	return float(built) / maxf(all, 1)


## The mesh of the square `at` lies in.
func _village_tool_at(at: Vector2) -> SurfaceTool:
	var key := Vector2i((at / CHUNK).floor())
	if not _village_chunks.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_village_chunks[key] = tool
	return _village_chunks[key]


## A house of Tyrol on the ground at `at`, `foot` high, its ridge turned
## `turn_deg` from north: plastered below, boarded above, under a low roof.
func _village_house(at: Vector2, foot: float, turn_deg: float, dice: RandomNumberGenerator) -> void:
	var wide := dice.randf_range(9.0, 12.5)
	var long := dice.randf_range(11.0, 16.0)
	var high := dice.randf_range(5.5, 7.5)
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(turn_deg)), Vector3(at.x, foot, at.y))
	var tool := _village_tool_at(at)
	var plaster: Color = PLASTER[dice.randi() % PLASTER.size()]
	var boards: Color = BOARDS[dice.randi() % BOARDS.size()]
	var lower := high * dice.randf_range(0.55, 0.7)
	_village_box(tool, xf, Vector3(0, -2.5, 0), Vector3(wide, lower + 2.5, long), plaster)
	_village_box(tool, xf, Vector3(0, lower, 0), Vector3(wide, high - lower, long), boards)
	_village_roof(tool, xf, high, wide * 0.5 + 1.4, long * 0.5 + 1.6, wide * 0.27, ROOFS[dice.randi() % ROOFS.size()], boards)


## A church: a nave under a steep roof, and a tower at its west end with a
## spire.
func _village_church(at: Vector2, foot: float, turn_deg: float, dice: RandomNumberGenerator) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(turn_deg + 90.0)), Vector3(at.x, foot, at.y))
	var tool := _village_tool_at(at)
	var white := Color(0.93, 0.91, 0.86)
	_village_box(tool, xf, Vector3(0, -2.5, 0), Vector3(13.0, 13.5, 28.0), white)
	_village_roof(tool, xf, 11.0, 7.4, 15.0, 7.5, ROOFS[0], white)
	var tower := xf * Transform3D(Basis(), Vector3(0, 0, -16.0))
	_village_box(tool, tower, Vector3(0, -2.5, 0), Vector3(7.0, 38.5, 7.0), white)
	_village_spire(tool, tower, 36.0, 3.8, 14.0, SPIRE)


## A box in the frame `xf`: its foot's middle at `low`, `size` large, with
## its four sides and its top.
func _village_box(tool: SurfaceTool, xf: Transform3D, low: Vector3, size: Vector3, colour: Color) -> void:
	var h := size * 0.5
	var c := [
		low + Vector3(-h.x, 0, -h.z), low + Vector3(h.x, 0, -h.z), low + Vector3(h.x, 0, h.z), low + Vector3(-h.x, 0, h.z),
		low + Vector3(-h.x, size.y, -h.z), low + Vector3(h.x, size.y, -h.z), low + Vector3(h.x, size.y, h.z), low + Vector3(-h.x, size.y, h.z),
	]
	var sides := [[[0, 1, 5, 4], Vector3.FORWARD], [[1, 2, 6, 5], Vector3.RIGHT], [[2, 3, 7, 6], Vector3.BACK], [[3, 0, 4, 7], Vector3.LEFT], [[4, 5, 6, 7], Vector3.UP]]
	for side: Array in sides:
		var k: Array = side[0]
		_village_quad(tool, xf, [c[k[0]], c[k[1]], c[k[2]], c[k[3]]], colour, side[1])


## A saddle roof in the frame `xf`, its eaves `eaves` high, reaching out
## `half_wide` either side of the ridge and `half_long` along it, the ridge
## `rise` over the eaves; the gables between in `gable`.
func _village_roof(tool: SurfaceTool, xf: Transform3D, eaves: float, half_wide: float, half_long: float, rise: float, colour: Color, gable: Color) -> void:
	var a := Vector3(-half_wide, eaves, -half_long)
	var b := Vector3(-half_wide, eaves, half_long)
	var c := Vector3(half_wide, eaves, half_long)
	var d := Vector3(half_wide, eaves, -half_long)
	var r0 := Vector3(0, eaves + rise, -half_long)
	var r1 := Vector3(0, eaves + rise, half_long)
	_village_quad(tool, xf, [a, b, r1, r0], colour, Vector3(-1, 1, 0))
	_village_quad(tool, xf, [c, d, r0, r1], colour, Vector3(1, 1, 0))
	# Under the eaves, seen from the street.
	_village_quad(tool, xf, [a, b, c, d], colour * 0.6, Vector3.DOWN)
	_village_tri(tool, xf, [d, a, r0], gable, Vector3.FORWARD)
	_village_tri(tool, xf, [b, c, r1], gable, Vector3.BACK)


## A spire on the tower of the frame `xf`: four faces from a square `half`
## either side, `low` high, to a point `rise` over it.
func _village_spire(tool: SurfaceTool, xf: Transform3D, low: float, half: float, rise: float, colour: Color) -> void:
	var c := [Vector3(-half, low, -half), Vector3(half, low, -half), Vector3(half, low, half), Vector3(-half, low, half)]
	var top := Vector3(0, low + rise, 0)
	for i in 4:
		var out: Vector3 = ((c[i] as Vector3) + (c[(i + 1) % 4] as Vector3)) * Vector3(1, 0, 1)
		_village_tri(tool, xf, [c[i], c[(i + 1) % 4], top], colour, out + Vector3.UP)


func _village_quad(tool: SurfaceTool, xf: Transform3D, p: Array, colour: Color, outward: Vector3) -> void:
	_village_tri(tool, xf, [p[0], p[1], p[2]], colour, outward)
	_village_tri(tool, xf, [p[0], p[2], p[3]], colour, outward)


## A triangle that faces `outward` (in the frame `xf`): Godot draws the side
## whose corners go round clockwise.
func _village_tri(tool: SurfaceTool, xf: Transform3D, p: Array, colour: Color, outward: Vector3) -> void:
	var a: Vector3 = xf * (p[0] as Vector3)
	var b: Vector3 = xf * (p[1] as Vector3)
	var c: Vector3 = xf * (p[2] as Vector3)
	var normal := (b - a).cross(c - a).normalized()
	if normal.dot(xf.basis * outward) < 0.0:
		normal = -normal
		var swap := b
		b = c
		c = swap
	for corner: Vector3 in [a, c, b]:
		tool.set_color(colour)
		tool.set_normal(normal)
		tool.add_vertex(corner)
