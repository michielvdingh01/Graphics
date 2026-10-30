extends "res://tools/levels/dunes/plan.gd"
## What the complex at the end of the dunes is built from: the bays of its
## wall and the wire on it, the leaves of its gate, the masts of its lamps.
## tools/levels/dunes/complex.gd says where each of them stands.
##
## Much of it is small: a strand of wire, a number on a wall, a weep hole.
## What is small is not drawn from afar and casts no shadow. It goes into
## meshes of its own for that, a block of ground at a time: see fine().

## Concrete that has stood outside for thirty years, the wall and everything
## else that was poured, and brick likewise.
const CONCRETE := "depot_concrete"
const WALL := CONCRETE
const BRICK := "depot_brick"
## Paint on concrete, in the colour each point is given.
const PAINT := "depot_paint"
## The glass of a window by day, the painted steel it sits in, and the room
## that is seen where a pane is out. A pane is this thick.
const PANE := "depot_glass"
const FRAME := "depot_frame"
const ROOM := "depot_room"
const PANE_THICK := 0.008
## Slabs of concrete laid as a road.
const SLAB := "depot_slab"
## Dark steel wire, seen from either side.
const WIRE := "depot_wire"
const WHITEWASH := Color(0.74, 0.73, 0.68)
const SIGNAL_YELLOW := Color(0.78, 0.56, 0.08)
const STENCIL_BLACK := Color(0.05, 0.05, 0.05)
const SIGNAL_RED := Color(0.52, 0.07, 0.05)
## The foot of everything that is built here: well under the ground, so that
## nothing shows daylight where the ground dips.
const FOOT := 4.4
## The wall round the complex: how far apart its piers stand, how wide and
## how deep a pier is, and how thick the wall between them.
const BAY := 4.0
const PIER := Vector2(0.55, 0.78)
const WALL_THICK := 0.4
## How high the first lift of the wall was poured: it is a little thicker
## than the one on top of it, and the ledge between them shows.
const FIRST_LIFT := 2.3

## How far off what is small is still drawn: what is only seen from close
## by, what shows across the yard, and what is never left out but casts no
## shadow. Three distances and no more: every one of them is a mesh for each
## block of ground it is used on.
const NEAR := 70.0
const MID := 150.0
const FAR := 420.0
## How many metres of ground such a mesh covers each way: twice what a block
## of the land does, since every surface of it is drawn by itself.
const FINE_BLOCK := 64.0

## How far off what is being built is still drawn, or nought for what is
## drawn from anywhere and casts a shadow: see fine().
var _fine := 0.0
var _fine_before: Array[float] = []
## The surfaces of what is small, by "<reach> <block x> <block z>/<material>".
var _fine_tools := {}
## Materials that are made here instead of being kept in materials/, by name:
## paint through a stencil, one for each text.
var _made := {}
## Dice for what is new here, so that nothing else falls differently.
var _depot_rng := RandomNumberGenerator.new()


func _init() -> void:
	super()
	_depot_rng.seed = 7106


# --- What is small ---------------------------------------------------------------


## From here on what is built is small: it is not drawn from further off than
## `reach` metres and casts no shadow. coarse() ends that, and what is built
## is again whatever it was before: every fine() has its coarse(). Between
## the two, refine() changes how far off it is drawn.
func fine(reach: float) -> void:
	_fine_before.append(_fine)
	_fine = reach


func refine(reach: float) -> void:
	_fine = reach


func coarse() -> void:
	_fine = _fine_before.pop_back() if not _fine_before.is_empty() else 0.0


## What is small goes into a surface of its own, by how far it is drawn and
## the block of ground it stands on.
func _tool(mat: String, flags: int, at: Vector3) -> SurfaceTool:
	if _fine <= 0.0 or flags & GLASS or _moving:
		return super(mat, flags, at)
	var block := (at / FINE_BLOCK).floor()
	var key := "%d %d %d/%s" % [int(_fine), int(block.x), int(block.z), mat]
	if not _fine_tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_fine_tools[key] = st
	return _still(_fine_tools[key], mat)


## The new kinds of concrete and brick are concrete and brick to a bullet.
func _surface(mat: String) -> String:
	match mat:
		CONCRETE, SLAB:
			return ""
		BRICK:
			return "brick"
	return super(mat)


## Puts down what was built small: a mesh for every block of ground and
## every distance, under a node of their own. The meshes become files of the
## level along with what the land has strewn, see _finish_zones() in
## tools/kit/land.gd.
func _commit_fine() -> void:
	var groups := {}
	for key: String in _fine_tools:
		groups[key.get_slice("/", 0)] = true
	if groups.is_empty():
		return
	var holder := Node3D.new()
	holder.name = "Fine"
	_add(holder, _root)
	var names := groups.keys()
	names.sort()
	var triangles := 0
	for group: String in names:
		var keys := _fine_tools.keys().filter(func(key: String) -> bool: return key.begins_with(group + "/"))
		keys.sort()
		var mesh := ArrayMesh.new()
		for key: String in keys:
			var st: SurfaceTool = _fine_tools[key]
			st.index()
			st.generate_tangents()
			var mat := key.get_slice("/", 1)
			st.set_material(_made[mat] if _made.has(mat) else load("res://materials/%s.tres" % mat))
			st.commit(mesh)
			triangles += mesh.surface_get_array_index_len(mesh.get_surface_count() - 1) / 3
		var reach := group.get_slice(" ", 0).to_float()
		var node := MeshInstance3D.new()
		node.name = "Fine_" + group.replace(" ", "_")
		node.mesh = mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		node.visibility_range_end = reach
		node.visibility_range_end_margin = maxf(4.0, reach * 0.08)
		_add(node, holder)
		_strewn["complex/fine_" + group.replace(" ", "_")] = {"mesh": mesh, "fit": Transform3D()}
	var used := {}
	for key: String in _fine_tools:
		var slot := "%s %s" % [key.get_slice(" ", 0), key.get_slice("/", 1)]
		used[slot] = used.get(slot, 0) + 1
	print("The complex, what is small: %d meshes of %d surfaces, %d triangles: %s" % [names.size(), _fine_tools.size(), triangles, used])
	_fine_tools.clear()


## A box given in the frame `xf`, which stands square to the world, built
## square to the world: a scan then runs on unbroken from one box into the
## next, whichever way the frame looks. Thin and in nobody's way unless
## `flags` say otherwise.
func square_box(mat: String, xf: Transform3D, centre: Vector3, size: Vector3, flags := DETAIL | NO_COLLIDE) -> void:
	box(mat, xf * centre, (xf.basis * size).abs(), Vector3.ZERO, flags)


# --- Paint -------------------------------------------------------------------------


## A patch of paint of `colour`: it lies in the XY of `xf`, `size` across, and
## is seen from its +Z. The alpha of the colour is how much of the wear of
## paint on a road it has had: one for a line that is driven over, less for
## the enamel of a board. `mat` is the paint, and `part` the part of its stencil
## that this patch shows, if it has one.
func painted(xf: Transform3D, size: Vector2, colour: Color, mat := PAINT, part := Rect2(0, 0, 1, 1)) -> void:
	var st := _tool(mat, DETAIL | NO_COLLIDE, xf.origin)
	var half := size * 0.5
	var corners: Array[Vector3] = [Vector3(-half.x, -half.y, 0), Vector3(half.x, -half.y, 0), Vector3(half.x, half.y, 0), Vector3(-half.x, half.y, 0)]
	var within: Array[Vector2] = [Vector2(part.position.x, part.end.y), Vector2(part.end.x, part.end.y), Vector2(part.end.x, part.position.y), Vector2(part.position.x, part.position.y)]
	var normal := xf.basis.z.normalized()
	# The wear is spread over the world, not over the patch: two patches that
	# lie over each other, a figure on a panel, wear through in the same places.
	var shift := Vector2(xf.origin.dot(xf.basis.x.normalized()), xf.origin.dot(xf.basis.y.normalized()))
	for i: int in [0, 2, 1, 0, 3, 2]:
		st.set_color(colour)
		st.set_normal(normal)
		st.set_uv(Vector2(corners[i].x, -corners[i].y) + Vector2(shift.x, -shift.y))
		st.set_uv2(within[i])
		st.add_vertex(xf * corners[i])


## The paint that goes through the stencil of `texture`, a decal of kind
## "text" of the manifest. It is made here, so it only goes on what is small.
func _stencil_paint(texture: String) -> String:
	var mat := "stencil " + texture
	if not _made.has(mat):
		var paint := (load("res://materials/%s.tres" % PAINT) as ShaderMaterial).duplicate() as ShaderMaterial
		paint.set_shader_parameter("stencil", load("res://assets/decals/%s.png" % texture))
		# The stencil is worn as it is.
		paint.set_shader_parameter("worn", 0.22)
		_made[mat] = paint
	return mat


## `text` stencilled in paint of `colour`, `height` high, around the origin
## of `xf` and read from its +Z. Unlike a label() it is a thing of the level
## and not a decal: it is drawn from as far off as fine() says, where a decal
## is gone at 45 m. The text has to be in the manifest as a decal of kind
## "text".
func stencil(text: String, xf: Transform3D, height: float, colour: Color) -> void:
	var texture := _lettering(text)
	painted(xf, Vector2(height * _lettering_aspect(texture), height), colour, _stencil_paint(texture))


## A number stencilled the same way, out of the figures of one texture: the
## hundred bays of a wall are then one paint and not a hundred.
func stencil_number(figures: String, xf: Transform3D, height: float, colour: Color) -> void:
	var texture := "text_0123456789"
	var size: Vector2 = (load("res://assets/decals/%s.png" % texture) as Texture2D).get_size()
	# The figures of the font are all as wide, and the first begins 0.15 of
	# the height in: see _lettering() in tools/gen_decals.gd.
	var advance := (size.x - 0.3 * size.y) / 10.0
	var cell := height * advance / size.y
	var mat := _stencil_paint(texture)
	for i in figures.length():
		var figure := figures.unicode_at(i) - 48
		if figure < 0 or figure > 9:
			continue
		var part := Rect2((0.15 * size.y + figure * advance) / size.x, 0.0, advance / size.x, 1.0)
		painted(xf * Transform3D(Basis(), Vector3((i + 0.5 - figures.length() * 0.5) * cell, 0, 0)), Vector2(cell, height), colour, mat, part)


# --- The wall ----------------------------------------------------------------------


## A stretch of the wall round the complex from `from` to `to` (x and z),
## with its outside on the right of the way it runs: concrete poured in bays
## between piers, on a footing, under a coping, each bay with two weep holes
## (which its concrete shows: see shaders/weathered_wall.gdshader) and its
## number stencilled on the inside. With `wire`, an arm of concrete leans
## out over the outside from every pier, with three strands of barbed wire
## on it and a coil on top. A stretch has a pier at either end unless `ends` says
## not: a corner and a gate post stand there instead. Returns the number of
## the bay after its last.
func wall_run(from: Vector2, to: Vector2, number := 1, wire := true, ends := Vector2i(1, 1)) -> int:
	var length := from.distance_to(to)
	var way := (to - from) / length
	var along := Vector3(way.x, 0, way.y)
	var xf := Transform3D(Basis(along, Vector3.UP, along.cross(Vector3.UP)), Vector3(from.x, YARD_Y, from.y))
	var low := FOOT - YARD_Y
	var middle := (from + to) * 0.5
	# What is in the way is one wall, as it was.
	var along_x := absf(way.x) > 0.5
	_collide_box(Transform3D(Basis(), Vector3(middle.x, (YARD_Y + WALL_HIGH + FOOT) * 0.5, middle.y)), Vector3(length if along_x else WALL_THICK, YARD_Y + WALL_HIGH - FOOT, WALL_THICK if along_x else length))
	var bays := maxi(1, roundi(length / BAY))
	var pitch := length / bays
	for i in bays:
		var x0 := i * pitch + PIER.x * 0.5
		var x1 := (i + 1) * pitch - PIER.x * 0.5
		var mid := (x0 + x1) * 0.5
		square_box(WALL, xf, Vector3(mid, (WALL_HIGH + FIRST_LIFT) * 0.5, 0), Vector3(x1 - x0, WALL_HIGH - FIRST_LIFT, WALL_THICK))
		square_box(WALL, xf, Vector3(mid, (FIRST_LIFT + low) * 0.5, 0), Vector3(x1 - x0, FIRST_LIFT - low, WALL_THICK + 0.09))
		square_box(WALL, xf, Vector3(mid, 0.05, 0), Vector3(x1 - x0, 1.1, WALL_THICK + 0.3))
		square_box(WALL, xf, Vector3(mid, WALL_HIGH + 0.07, 0), Vector3(pitch - 0.75, 0.14, WALL_THICK + 0.3))
		# Its number, stencilled at head height on the inside.
		fine(NEAR)
		stencil_number("%02d" % (number + i), xf * Transform3D(Basis(Vector3.UP, PI), Vector3(mid, 1.85, -WALL_THICK * 0.5 - 0.049)), 0.3, STENCIL_BLACK)
		coarse()
	for i in bays + 1:
		if (i == 0 and ends.x == 0) or (i == bays and ends.y == 0):
			continue
		var x := i * pitch
		square_box(WALL, xf, Vector3(x, (WALL_HIGH + low) * 0.5, 0), Vector3(PIER.x, WALL_HIGH - low, PIER.y))
		square_box(WALL, xf, Vector3(x, 0.1, 0), Vector3(PIER.x + 0.16, 1.2, PIER.y + 0.16))
		square_box(WALL, xf, Vector3(x, WALL_HIGH + 0.09, 0), Vector3(PIER.x + 0.2, 0.18, PIER.y + 0.18))
	if wire:
		_wall_wire(xf, length, bays)
	return number + bays


## The wire on a stretch of wall, see wall_run(): `xf` stands at its
## beginning on the ground, with X along it and Z to its outside.
func _wall_wire(xf: Transform3D, length: float, bays: int) -> void:
	var pitch := length / bays
	var top := WALL_HIGH + 0.18
	var knee := Vector3(0, top + 0.34, 0)
	var tip := Vector3(0, top + 0.86, 0.52)
	for i in bays + 1:
		var at := Vector3(i * pitch, 0, 0)
		beam(CONCRETE, xf * (at + Vector3(0, top - 0.02, 0)), xf * (at + knee + Vector3(0, 0.04, 0)), 0.11, SLIGHT)
		beam(CONCRETE, xf * (at + knee), xf * (at + tip), 0.1, SLIGHT)
	fine(MID)
	for i in range(1, bays + 1):
		var before := Vector3((i - 1) * pitch, 0, 0)
		var at := Vector3(i * pitch, 0, 0)
		for share: float in [0.2, 0.58, 0.96]:
			var hung := knee.lerp(tip, share) + Vector3(0, 0.07, 0)
			beam(WIRE, xf * (before + hung), xf * (at + hung), 0.014, SLIGHT)
		_coil(xf * Transform3D(Basis(), before + Vector3(0, top + 0.27, -0.02)), pitch, 0.27)
	coarse()


## A coil of barbed wire, `length` long along the X of `xf` and `radius`
## round: two bands of steel wound against each other, as it comes off the
## lorry, sagging a little between where it is tied down. A band is wider
## than wire is: a coil has to show from across the yard, where a wire
## would be less than a dot of the screen.
func _coil(xf: Transform3D, length: float, radius: float) -> void:
	var st := _tool(WIRE, SLIGHT, xf * Vector3(length * 0.5, 0, 0))
	var turns := maxi(2, roundi(length / 0.5))
	var steps := 8
	var band := 0.02
	for wound: float in [1.0, -1.0]:
		var loose := _depot_rng.randf_range(0.9, 1.08)
		var phase := _depot_rng.randf() * TAU
		var before := Vector3.ZERO
		var before_out := Vector3.ZERO
		for i in turns * steps + 1:
			var share := float(i) / (turns * steps)
			var angle := wound * TAU * i / steps + phase
			var out := Vector3(0, cos(angle), sin(angle))
			var sag := sin(PI * share) * 0.04
			var at := Vector3(share * length, -sag, 0) + out * radius * loose * (1.0 + 0.07 * sin(share * 23.0 + phase))
			if i > 0:
				var along := Vector3(band, 0, 0)
				_quad(st, [xf * (before - along), xf * (before + along), xf * (at + along), xf * (at - along)],
					[xf.basis * before_out, xf.basis * before_out, xf.basis * out, xf.basis * out],
					[Vector2(0, 0), Vector2(0.03, 0), Vector2(0.03, 0.2), Vector2(0, 0.2)])
			before = at
			before_out = out


## The pier where two stretches of the wall meet, at `at` (x and z): stouter
## than the others and a head higher.
func corner_pier(at: Vector2) -> void:
	var low := FOOT - YARD_Y
	var foot := Vector3(at.x, YARD_Y, at.y)
	box(WALL, foot + Vector3.UP * (WALL_HIGH + 0.3 + low) * 0.5, Vector3(1.0, WALL_HIGH + 0.3 - low, 1.0), Vector3.ZERO, SLIGHT)
	box(WALL, foot + Vector3.UP * 0.1, Vector3(1.18, 1.2, 1.18), Vector3.ZERO, SLIGHT)
	box(WALL, foot + Vector3.UP * (WALL_HIGH + 0.39), Vector3(1.2, 0.18, 1.2), Vector3.ZERO, SLIGHT)


## A concrete watch post on a corner of the wall at `at` (x and z), its
## slits looking out along `looks` and to both sides of it: a cabin that
## rides on the corner, a storey up, under a slab of a roof. Nobody is in
## it. It stands on the wall, above everybody's head: it is in nobody's way.
func watch_post(at: Vector2, looks: Vector3) -> void:
	var out := looks.normalized()
	var xf := Transform3D(Basis(Vector3.UP.cross(out), Vector3.UP, out), Vector3(at.x, YARD_Y + WALL_HIGH + 0.3, at.y) + out * 0.35)
	var half := 1.25
	# Two steps of concrete under it, wider as they go up.
	_local_box(WALL, xf, Vector3(0, -0.62, 0), Vector3(1.5, 0.36, 1.5), SLIGHT)
	_local_box(WALL, xf, Vector3(0, -0.28, 0), Vector3(2.0, 0.34, 2.0), SLIGHT)
	_local_box(WALL, xf, Vector3(0, 0.0, 0), Vector3(half * 2.0 + 0.16, 0.24, half * 2.0 + 0.16), SLIGHT)
	# Its walls: a breast, a slit all round between four corner posts, a head.
	for side: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var across := Vector3(absf(side.y), 0, absf(side.x))
		var middle := Vector3(side.x, 0, side.y) * (half - 0.09)
		var long := across * half * 2.0 + Vector3(absf(side.x), 0, absf(side.y)) * 0.18
		_local_box(WALL, xf, middle + Vector3(0, 0.72, 0), long + Vector3(0, 1.2, 0), SLIGHT)
		_local_box(WALL, xf, middle + Vector3(0, 2.14, 0), long + Vector3(0, 0.52, 0), SLIGHT)
		fine(FAR)
		_local_box("rubber", xf, middle * 0.9 + Vector3(0, 1.6, 0), across * (half * 2.0 - 0.3) + Vector3(absf(side.x), 0, absf(side.y)) * 0.02 + Vector3(0, 0.56, 0), SLIGHT)
		coarse()
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			_local_box(WALL, xf, Vector3(x * (half - 0.11), 1.6, z * (half - 0.11)), Vector3(0.22, 0.6, 0.22), SLIGHT)
	_local_box(WALL, xf, Vector3(0, 2.5, 0), Vector3(half * 2.0 + 0.7, 0.2, half * 2.0 + 0.7), SLIGHT)
	# A searchlight on the roof, off by day; by night it sweeps the ground
	# before the wall.
	fine(FAR)
	cylinder("galvanised", xf * Vector3(0.5, 2.6, 0.6), 0.03, 0.54, SLIGHT, Vector3.ZERO, -1.0, 6)
	rod("galvanised", xf * Vector3(0.5, 3.2, 0.42), xf * Vector3(0.5, 3.3, 0.86), 0.24, SLIGHT, 12)
	rod("lamp_glass", xf * Vector3(0.5, 3.299, 0.858), xf * Vector3(0.5, 3.301, 0.872), 0.205, SLIGHT, 12)
	coarse()
	searchlight(xf * Vector3(0.5, 3.3, 0.95), xf.basis.z, 9.0)


## A leaf of the gate: a frame of steel tube, sheet below, bars above, on
## three hinges, with a wheel under its free edge and a bolt to drop into the
## road. `leaf` stands in its middle with X towards its free edge; `outer` is
## the sign of the Z that looks out when the gate is shut.
func gate_leaf(leaf: Transform3D, size: Vector2, outer: float) -> void:
	var half := size * 0.5
	var mat := "army_green"
	var rail := 0.3
	fine(FAR)
	for x: float in [-half.x + 0.045, half.x - 0.045]:
		_local_box(mat, leaf, Vector3(x, 0, 0), Vector3(0.09, size.y, 0.08), SLIGHT)
	for y: float in [-half.y + 0.045, rail, half.y - 0.045]:
		_local_box(mat, leaf, Vector3(0, y, 0), Vector3(size.x - 0.18, 0.09, 0.08), SLIGHT)
	# The sheet, pressed into ribs, seen from either side.
	var sheet := Vector2(size.x - 0.18, rail - 0.045 + half.y - 0.09)
	var sheet_y := (rail - 0.045 - half.y + 0.09) * 0.5
	for face: float in [0.0, PI]:
		corrugated(mat, leaf * Transform3D(Basis(Vector3.UP, face), Vector3(0, sheet_y, 0.012 * cos(face))), sheet, 0.28, 0.024, SLIGHT)
	beam(mat, leaf * Vector3(-half.x + 0.09, -half.y + 0.09, outer * 0.035), leaf * Vector3(half.x - 0.09, rail - 0.045, outer * 0.035), 0.07, SLIGHT, 0.014)
	# The bars, through the top rail and a hand above it.
	var bars := roundi((size.x - 0.18) / 0.15)
	for i in range(1, bars):
		var x := -half.x + 0.09 + (size.x - 0.18) * i / bars
		_local_box(mat, leaf, Vector3(x, (rail + half.y + 0.16) * 0.5, 0), Vector3(0.022, half.y + 0.16 - rail, 0.022), SLIGHT)
	refine(NEAR)
	for y: float in [-half.y + 0.4, 0.0, half.y - 0.4]:
		cylinder("dark_steel", leaf * Vector3(-half.x - 0.03, y - 0.09, 0), 0.035, 0.18, SLIGHT, Vector3.ZERO, -1.0, 8)
		_local_box("dark_steel", leaf, Vector3(-half.x + 0.12, y, outer * 0.045), Vector3(0.3, 0.05, 0.01), SLIGHT)
	# The wheel that carries its free edge, beside the frame.
	var axle := Vector3(half.x - 0.14, -half.y + 0.06, -outer * 0.1)
	rod("dark_steel", leaf * (axle - Vector3(0, 0, 0.03)), leaf * (axle + Vector3(0, 0, 0.03)), 0.1, SLIGHT, 12)
	_local_box("dark_steel", leaf, axle + Vector3(0, 0.1, 0.02 * outer), Vector3(0.06, 0.26, 0.012), SLIGHT)
	_local_box("dark_steel", leaf, axle + Vector3(0, 0.22, 0.05 * outer), Vector3(0.06, 0.012, 0.1), SLIGHT)
	# The bolt, and the plate the padlock hangs on.
	rod("dark_steel", leaf * Vector3(half.x - 0.26, -half.y - 0.02, outer * 0.06), leaf * Vector3(half.x - 0.26, -half.y + 0.95, outer * 0.06), 0.012, SLIGHT, 6)
	rod("dark_steel", leaf * Vector3(half.x - 0.26, -half.y + 0.95, outer * 0.06), leaf * Vector3(half.x - 0.26, -half.y + 0.95, outer * 0.15), 0.012, SLIGHT, 6)
	for y: float in [-half.y + 0.3, -half.y + 0.75]:
		_local_box("dark_steel", leaf, Vector3(half.x - 0.26, y, outer * 0.05), Vector3(0.06, 0.05, 0.03), SLIGHT)
	_local_box("dark_steel", leaf, Vector3(half.x - 0.05, rail + 0.25, outer * 0.05), Vector3(0.16, 0.22, 0.02), SLIGHT)
	# No way in: a red disc with a white bar, on the side that looks out.
	refine(MID)
	var disc := leaf * Transform3D(Basis(Vector3.RIGHT, outer * PI * 0.5), Vector3(0, rail + (half.y - rail) * 0.5, outer * 0.02))
	_cylinder("enamel_red", disc, 0.36, 0.012, SLIGHT, -1.0, 20)
	painted(leaf * Transform3D(Basis(Vector3.UP, 0.0 if outer > 0.0 else PI), Vector3(0, rail + (half.y - rail) * 0.5, outer * 0.034)), Vector2(0.5, 0.11), Color(WHITEWASH, 0.2))
	coarse()


## A post of the gate at `hinge`, on the ground: stouter and higher than the
## wall, whitewashed to shoulder height, under a cap, with a lamp on the side
## `out` that is off by day.
func gate_post(hinge: Vector3, out: Vector3) -> void:
	var low := FOOT - YARD_Y
	var high := 5.2
	box(WALL, hinge + Vector3.UP * (high + low) * 0.5, Vector3(0.9, high - low, 0.9), Vector3.ZERO, SLIGHT)
	_collide_box(Transform3D(Basis(), hinge + Vector3.UP * 2.6), Vector3(0.9, 5.2, 0.9))
	box(WALL, hinge + Vector3.UP * 0.1, Vector3(1.06, 1.0, 1.06), Vector3.ZERO, SLIGHT)
	box(WALL, hinge + Vector3.UP * (high + 0.1), Vector3(1.12, 0.2, 1.12), Vector3.ZERO, SLIGHT)
	box(WALL, hinge + Vector3.UP * (high + 0.27), Vector3(0.7, 0.14, 0.7), Vector3.ZERO, SLIGHT)
	fine(MID)
	for side: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var face := Transform3D(Basis(Vector3.UP.cross(side), Vector3.UP, side), hinge + side * 0.455 + Vector3.UP * 1.05)
		painted(face, Vector2(0.9, 0.9), WHITEWASH)
		painted(face * Transform3D(Basis(), Vector3(0, 0.62, 0.001)), Vector2(0.9, 0.34), STENCIL_BLACK)
	bulkhead(hinge + out * 0.45 + Vector3.UP * 4.5, out)
	coarse()


## A board on a wall: a plate of steel painted white in a red border, with `lines` of text on
## it one under the other, each [text, height of its letters, colour]. `xf`
## stands in the middle of its back on the face of the wall, with Z out of
## it. Its texts are stencils, so it is read from as far as it is drawn.
func sign_board(xf: Transform3D, size: Vector2, lines: Array) -> void:
	fine(MID)
	_local_box("dark_steel", xf, Vector3(0, 0, 0.012), Vector3(size.x, size.y, 0.024), SLIGHT)
	painted(xf * Transform3D(Basis(), Vector3(0, 0, 0.0245)), size - Vector2(0.01, 0.01), Color(WHITEWASH, 0.25))
	for edge: float in [-1.0, 1.0]:
		painted(xf * Transform3D(Basis(), Vector3(0, edge * (size.y * 0.5 - 0.03), 0.0255)), Vector2(size.x, 0.06), Color(SIGNAL_RED, 0.25))
		painted(xf * Transform3D(Basis(), Vector3(edge * (size.x * 0.5 - 0.03), 0, 0.0255)), Vector2(0.06, size.y), Color(SIGNAL_RED, 0.25))
	var total := 0.0
	for line: Array in lines:
		total += (line[1] as float) * 1.5
	var y := total * 0.5
	for line: Array in lines:
		var high: float = line[1]
		y -= high * 0.75
		stencil(line[0], xf * Transform3D(Basis(), Vector3(0, y, 0.027)), high, line[2])
		y -= high * 0.75
	coarse()


## A mast with two floodlights at its head, `height` high, against the wall
## at `at` (x and z) on the side `inwards`: a steel tube on a block of
## concrete, strapped to the wall, with the lamps turned down at the ground
## either side of `aims`. They are off: it is day.
func flood_mast(at: Vector2, inwards: Vector3, height := 8.2, aims := Vector3.ZERO) -> void:
	var foot := Vector3(at.x, YARD_Y, at.y) + inwards * 0.2
	var look := inwards if aims == Vector3.ZERO else aims.normalized()
	box(WALL, foot + Vector3.UP * 0.2, Vector3(0.5, 0.5, 0.4), Vector3.ZERO, SLIGHT)
	fine(FAR)
	cylinder("galvanised", foot + Vector3.UP * 0.45, 0.075, height - 0.45, SLIGHT, Vector3.ZERO, 0.05, 10)
	for y: float in [1.6, WALL_HIGH - 0.3]:
		box("galvanised", foot - inwards * 0.1 + Vector3.UP * y, inwards.abs() * 0.24 + Vector3(absf(inwards.z), 0, absf(inwards.x)) * 0.22 + Vector3.UP * 0.05, Vector3.ZERO, SLIGHT)
	var across := Vector3.UP.cross(look)
	var head := foot + Vector3.UP * (height - 0.12)
	beam("galvanised", head - across * 0.62, head + across * 0.62, 0.06, SLIGHT)
	for side: float in [-1.0, 1.0]:
		var aim := (look + across * side * 0.45 + Vector3.DOWN * 0.55).normalized()
		var lamp := Transform3D(Basis.looking_at(-aim), head + across * side * 0.5 + Vector3.UP * 0.12 + aim * 0.08)
		_box("galvanised", lamp, Vector3(0.42, 0.34, 0.2), SLIGHT)
		_box("lamp_glass", lamp * Transform3D(Basis(), Vector3(0, 0, 0.102)), Vector3(0.36, 0.28, 0.01), SLIGHT)
		_box("galvanised", lamp * Transform3D(Basis(), Vector3(0, 0.19, 0.06)), Vector3(0.46, 0.02, 0.34), SLIGHT)
	# The conduit down the mast to its switch.
	rod("galvanised", foot + inwards * 0.085 + Vector3.UP * 1.3, head + inwards * 0.06, 0.012, SLIGHT, 5)
	rounded_box("galvanised", Transform3D(Basis(), foot + inwards * 0.12 + Vector3.UP * 1.3), Vector3(0.16, 0.24, 0.1), 0.01, SLIGHT)
	coarse()
	# By night both lamps burn: one light for the two, down at the ground
	# between where they look.
	var down := (look + Vector3.DOWN * 0.55).normalized()
	night_beam(Transform3D(Basis.looking_at(down, look), head + Vector3.UP * 0.12 + down * 0.25), SODIUM, 22.0, 27.0, 100.0)


# --- Walls with openings, and what is in them ---------------------------------------


## A wall in the frame `xf`, which stands square to the world with X along
## the wall, Y up and Z out of its face: it fills `area` of that face (x and
## y), is `thick` behind it and stands `proud` of it, and leaves `openings`
## open, each a part of the face.
func pierced(mat: String, xf: Transform3D, area: Rect2, thick: float, openings: Array, proud := 0.0) -> void:
	var cuts: Array[float] = [area.position.x, area.end.x]
	for opening: Rect2 in openings:
		for cut: float in [opening.position.x, opening.end.x]:
			if cut > area.position.x and cut < area.end.x:
				cuts.append(cut)
	cuts.sort()
	for i in cuts.size() - 1:
		var x0 := cuts[i]
		var x1 := cuts[i + 1]
		if x1 - x0 < 0.001:
			continue
		var mid := (x0 + x1) * 0.5
		var over := openings.filter(func(opening: Rect2) -> bool: return opening.position.x < mid and opening.end.x > mid)
		over.sort_custom(func(one: Rect2, other: Rect2) -> bool: return one.position.y < other.position.y)
		var y := area.position.y
		for opening: Rect2 in over:
			var to := minf(opening.position.y, area.end.y)
			if to - y > 0.001:
				square_box(mat, xf, Vector3(mid, (y + to) * 0.5, (proud - thick) * 0.5), Vector3(x1 - x0, to - y, thick + proud))
			y = maxf(y, opening.end.y)
		if area.end.y - y > 0.001:
			square_box(mat, xf, Vector3(mid, (y + area.end.y) * 0.5, (proud - thick) * 0.5), Vector3(x1 - x0, area.end.y - y, thick + proud))


## One pane of glass: it lies in the XY of `xf` around its origin and is
## seen from its +Z. What has become of it the dice say, unless `kind` does:
## nought for glass, a half for painted over, one for gone.
##
## A pane is a box of glass, as the panes of every level are, and breaks as
## they do: see scripts/window.gd. Panes that meet edge to edge are one
## window there. One that is gone is not built: what shows in its place is
## the room, see _room_behind().
func pane(xf: Transform3D, size: Vector2, kind := -1.0) -> void:
	var dice := _depot_rng.randf()
	if kind < 0.0:
		kind = 1.0 if dice < 0.025 else (0.5 if dice < 0.06 else 0.0)
	var dirt := _depot_rng.randf()
	var look := Color(_depot_rng.randf(), _depot_rng.randf(), dirt * dirt, kind)
	if kind >= 0.75:
		return
	var st := _tool(PANE, GLASS | NO_COLLIDE, xf.origin)
	var half := Vector3(size.x, size.y, PANE_THICK) * 0.5
	var shift := Vector2(xf.origin.dot(xf.basis.x), xf.origin.dot(xf.basis.y))
	# Side by side as _box() builds them, which is what a window is taken
	# apart by; every corner carries what the pane looks like.
	for n: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var up := Vector3.FORWARD if absf(n.y) > 0.5 else Vector3.UP
		var right := up.cross(n)
		var c := n * absf(n.dot(half))
		var r := right * absf(right.dot(half))
		var u := up * absf(up.dot(half))
		var corners: Array[Vector3] = [c - r - u, c + r - u, c + r + u, c - r + u]
		var normal := xf.basis * n
		for i: int in [0, 2, 1, 0, 3, 2]:
			st.set_color(look)
			st.set_normal(normal)
			st.set_uv(Vector2(corners[i].dot(right) + shift.x, -corners[i].dot(up) - shift.y))
			st.add_vertex(xf * corners[i])


## What shows where a pane is out, and behind every pane once it is shot
## out: the room, on a sheet just behind the glass of an opening `size`
## large in the frame `glass`. See shaders/depot_room.gdshader.
func _room_behind(glass: Transform3D, size: Vector2) -> void:
	var st := _tool(ROOM, DETAIL | NO_COLLIDE, glass.origin)
	var half := size * 0.5
	var back := -0.05
	var corners: Array[Vector3] = [Vector3(-half.x, -half.y, back), Vector3(half.x, -half.y, back), Vector3(half.x, half.y, back), Vector3(-half.x, half.y, back)]
	for i: int in [0, 2, 1, 0, 3, 2]:
		st.set_color(Color.WHITE)
		st.set_normal(glass.basis.z)
		st.set_uv(Vector2(corners[i].x, -corners[i].y))
		st.add_vertex(glass * corners[i])


## A steel window in an opening of a wall: `xf` stands in the middle of the
## opening on the face of the wall, with Z out of it. `size` is the opening,
## and the glass lies `deep` behind the face. It is `lights` lights wide and
## high. With `vents`, its top row is that high and hung at the top, and a
## few of those lights stand ajar.
func steel_window(xf: Transform3D, size: Vector2, deep: float, lights: Vector2i, vents := 0.0) -> void:
	var half := size * 0.5
	var bar := 0.05
	var slim := 0.034
	var glass := xf * Transform3D(Basis(), Vector3(0, 0, -deep))
	# Where the rows begin and end, from the bottom up.
	var rows: Array[float] = [-half.y + bar * 0.5]
	var full := size.y - bar - (vents if lights.y > 1 else 0.0)
	var even := lights.y - (1 if vents > 0.0 and lights.y > 1 else 0)
	for j in even:
		rows.append(rows[0] + full * (j + 1) / even)
	if vents > 0.0 and lights.y > 1:
		rows.append(half.y - bar * 0.5)
	var wide := (size.x - bar) / lights.x
	fine(MID)
	for side: float in [-1.0, 1.0]:
		_local_box(FRAME, glass, Vector3(side * (half.x - bar * 0.5), 0, 0.02), Vector3(bar, size.y, 0.07), SLIGHT)
		_local_box(FRAME, glass, Vector3(0, side * (half.y - bar * 0.5), 0.02), Vector3(size.x - bar * 2.0, bar, 0.07), SLIGHT)
	for i in range(1, lights.x):
		_local_box(FRAME, glass, Vector3(-half.x + bar * 0.5 + wide * i, 0, 0.015), Vector3(slim, size.y - bar * 2.0, 0.05), SLIGHT)
	for j in range(1, rows.size() - 1):
		_local_box(FRAME, glass, Vector3(0, rows[j], 0.018), Vector3(size.x - bar * 2.0, slim, 0.054), SLIGHT)
	refine(FAR)
	_room_behind(glass, size)
	# A shot at the glass stops on the wall it sits in, this far before it.
	_glass_reveal = maxf(_glass_reveal, deep + 0.03)
	for j in rows.size() - 1:
		var high := rows[j + 1] - rows[j]
		for i in lights.x:
			var x := -half.x + bar * 0.5 + wide * (i + 0.5)
			var is_vent := vents > 0.0 and lights.y > 1 and j == rows.size() - 2
			if is_vent and _depot_rng.randf() < 0.13:
				# Ajar: swung out at the bottom, on its hinges at the top.
				var swung := glass * Transform3D(Basis(Vector3.RIGHT, -_depot_rng.randf_range(0.1, 0.24)), Vector3(x, rows[j + 1], 0.012))
				pane(swung * Transform3D(Basis(), Vector3(0, -high * 0.5, 0)), Vector2(wide - slim, high - slim), 0.0)
				refine(MID)
				_local_box(FRAME, swung, Vector3(0, -high + 0.02, 0.005), Vector3(wide - slim, 0.03, 0.03), SLIGHT)
				for side: float in [-1.0, 1.0]:
					_local_box(FRAME, swung, Vector3(side * (wide - slim) * 0.5, -high * 0.5, 0.005), Vector3(0.025, high, 0.03), SLIGHT)
				refine(FAR)
				# What is seen past it is the room.
				pane(glass * Transform3D(Basis(), Vector3(x, (rows[j] + rows[j + 1]) * 0.5, -0.02)), Vector2(wide - slim, high - slim), 1.0)
			else:
				# The glass runs on behind the bars: the panes of an
				# opening meet edge to edge, and are one window.
				pane(glass * Transform3D(Basis(), Vector3(x, (rows[j] + rows[j + 1]) * 0.5, 0.012)), Vector2(wide, high))
	coarse()


# --- The main building ---------------------------------------------------------------


## How the faces of the main building are divided, in metres over the
## ground: the top of its plinth, the three beams that show in its faces,
## the sill and the head of its two rows of windows, and its roof edge.
const PLINTH := 1.0
const BEAMS: Array[Vector2] = [Vector2(4.6, 5.2), Vector2(7.8, 8.4), Vector2(12.2, 12.8)]
const WINDOW_ROWS: Array[Vector2] = [Vector2(5.6, 7.8), Vector2(10.0, 12.2)]
const ROOF_EDGE := Vector2(14.5, 15.0)
## How far a column stands out of a face, and how far behind the face the
## glass of a window lies.
const COLUMN := Vector2(0.7, 0.3)
const REVEAL := 0.24


## Where bay `i` of `bays` of a face `length` long has its middle, on the
## face at the ground: the frame of the face, moved along.
func bay_frame(xf: Transform3D, length: float, bays: int, i: int) -> Transform3D:
	return xf * Transform3D(Basis(), Vector3(length * (i + 0.5) / bays, 0, 0))


## One face of the main building, a frame of concrete filled in with brick:
## a column on every line between its `bays`, a plinth, a beam over every
## storey, and in every bay two windows one over the other, of steel, set
## back in the brick over a sill. `xf` stands at the left end of the face as
## it is seen from outside, on the ground, with X along the face and Z out
## of it, and the face is `thick`. A face that begins higher up, behind the
## wall of the complex, says where with `from_y`. `ground` holds what is
## left open in the ground storey of a bay, by the number of the bay: parts
## of the face (x from the middle of the bay, y from the ground), for the
## doors and windows that are built into them afterwards, and `plain` the
## rows of windows a bay goes without, likewise. The two ends of a face are
## left to block_corner().
func block_face(xf: Transform3D, length: float, bays: int, thick: float, from_y := 0.0, ground := {}, plain := {}) -> void:
	var pitch := length / bays
	var low := FOOT - YARD_Y if from_y <= 0.0 else from_y
	for i in range(1, bays):
		square_box(CONCRETE, xf, Vector3(i * pitch, (low + ROOF_EDGE.x) * 0.5, COLUMN.y * 0.5), Vector3(COLUMN.x, ROOF_EDGE.x - low, COLUMN.y))
	for i in bays:
		var a := i * pitch + COLUMN.x * 0.5
		var b := (i + 1) * pitch - COLUMN.x * 0.5
		var mid := (a + b) * 0.5
		var clear := b - a
		var first := BEAMS[0].x
		if from_y <= 0.0:
			var openings: Array = []
			for part: Rect2 in ground.get(i, []):
				openings.append(Rect2(part.position + Vector2(mid, 0), part.size))
			pierced(CONCRETE, xf, Rect2(a, low, clear, PLINTH - low), thick, openings, 0.08)
			pierced(BRICK, xf, Rect2(a, PLINTH, clear, first - PLINTH), thick, openings)
		else:
			first = from_y
		for beam_at: Vector2 in [Vector2(first, BEAMS[0].y), BEAMS[1], BEAMS[2]]:
			square_box(CONCRETE, xf, Vector3(mid, (beam_at.x + beam_at.y) * 0.5, (0.06 - thick) * 0.5), Vector3(clear, beam_at.y - beam_at.x, thick + 0.06))
		for row in WINDOW_ROWS.size():
			var sill := WINDOW_ROWS[row].x
			var head := WINDOW_ROWS[row].y
			var wide := clear - 1.2
			if row in plain.get(i, []):
				square_box(BRICK, xf, Vector3(mid, (BEAMS[row].y + head) * 0.5, -thick * 0.5), Vector3(clear, head - BEAMS[row].y, thick))
				continue
			pierced(BRICK, xf, Rect2(a, BEAMS[row].y, clear, head - BEAMS[row].y), thick, [Rect2(mid - wide * 0.5, sill, wide, head - sill)])
			steel_window(xf * Transform3D(Basis(), Vector3(mid, (sill + head) * 0.5, 0)), Vector2(wide, head - sill), REVEAL, Vector2i(roundi(wide / 0.8), 2), 0.72)
			square_box(CONCRETE, xf, Vector3(mid, sill - 0.045, (0.07 - REVEAL) * 0.5), Vector3(wide + 0.24, 0.11, REVEAL + 0.07))
		square_box(BRICK, xf, Vector3(mid, (BEAMS[2].y + ROOF_EDGE.x) * 0.5, -thick * 0.5), Vector3(clear, ROOF_EDGE.x - BEAMS[2].y, thick))
		# The roof edge runs on over the columns, and its coping over that.
		square_box(CONCRETE, xf, Vector3((i + 0.5) * pitch, (ROOF_EDGE.x + ROOF_EDGE.y) * 0.5, (COLUMN.y + 0.04 - thick) * 0.5), Vector3(pitch, ROOF_EDGE.y - ROOF_EDGE.x, thick + COLUMN.y + 0.04))
		square_box(CONCRETE, xf, Vector3((i + 0.5) * pitch, ROOF_EDGE.y + 0.07, (COLUMN.y + 0.12 - thick) * 0.5), Vector3(pitch, 0.14, thick + COLUMN.y + 0.12))


## The corner of the main building at `at` (x and z), where the faces that
## look out along `one` and `other` meet: a post of concrete from `from_y`
## up, and the roof edge round it.
func block_corner(at: Vector2, one: Vector3, other: Vector3, from_y := 0.0) -> void:
	var low := FOOT - YARD_Y if from_y <= 0.0 else from_y
	var corner := Vector3(at.x, YARD_Y, at.y)
	var out := one + other
	box(CONCRETE, corner + out * (COLUMN.y - 0.5) * 0.5 + Vector3.UP * (low + ROOF_EDGE.x) * 0.5, Vector3(COLUMN.y + 0.5, ROOF_EDGE.x - low, COLUMN.y + 0.5), Vector3.ZERO, SLIGHT)
	var edge := COLUMN.y + 0.04
	box(CONCRETE, corner + out * (edge - 0.5) * 0.5 + Vector3.UP * (ROOF_EDGE.x + ROOF_EDGE.y) * 0.5, Vector3(edge + 0.5, ROOF_EDGE.y - ROOF_EDGE.x, edge + 0.5), Vector3.ZERO, SLIGHT)
	box(CONCRETE, corner + out * (edge + 0.08 - 0.5) * 0.5 + Vector3.UP * (ROOF_EDGE.y + 0.07), Vector3(edge + 0.58, 0.14, edge + 0.58), Vector3.ZERO, SLIGHT)


# --- At the gate ---------------------------------------------------------------------


## The middle of bay `i` of the stretch of wall from `from` to `to`, as
## wall_run() divides it.
func bay_middle(from: Vector2, to: Vector2, i: int) -> Vector2:
	var bays := maxi(1, roundi(from.distance_to(to) / BAY))
	return from.lerp(to, (i + 0.5) / bays)


## The frame of the face of a box that looks along `out`: at its left end as
## it is seen from outside, with X along the face and Z out of it. `centre`
## is the middle of the box and `size` its sizes; the frame stands as high
## as `centre` does.
func face_of(centre: Vector3, size: Vector3, out: Vector3) -> Transform3D:
	var along := Vector3.UP.cross(out)
	var half := size * 0.5
	return Transform3D(Basis(along, Vector3.UP, out), centre + out * absf(out.dot(half)) - along * absf(along.dot(half)))


## A steel door in an opening of a wall: `xf` stands on the sill in the
## middle of the opening, on the face of the wall with Z out of it, and the
## leaf lies `deep` behind the face. It is shut.
func steel_door(xf: Transform3D, size: Vector2, deep: float) -> void:
	var leaf := xf * Transform3D(Basis(), Vector3(0, size.y * 0.5, -deep))
	fine(MID)
	_local_box("door", leaf, Vector3.ZERO, Vector3(size.x - 0.08, size.y - 0.04, 0.05), SLIGHT)
	for side: float in [-1.0, 1.0]:
		_local_box("dark_steel", leaf, Vector3(side * (size.x * 0.5 - 0.025), 0, 0.02), Vector3(0.05, size.y, 0.09), SLIGHT)
	_local_box("dark_steel", leaf, Vector3(0, size.y * 0.5 - 0.025, 0.02), Vector3(size.x, 0.05, 0.09), SLIGHT)
	refine(NEAR)
	for y: float in [-size.y * 0.3, size.y * 0.3]:
		_local_box("dark_steel", leaf, Vector3(-size.x * 0.5 + 0.11, y, 0.03), Vector3(0.1, 0.14, 0.012), SLIGHT)
	_local_box("dark_steel", leaf, Vector3(0, -size.y * 0.5 + 0.14, 0.028), Vector3(size.x - 0.16, 0.2, 0.006), SLIGHT)
	rounded_box("dark_steel", leaf * Transform3D(Basis(), Vector3(size.x * 0.5 - 0.14, -0.02, 0.05)), Vector3(0.035, 0.16, 0.05), 0.012, SLIGHT)
	_local_box("dark_steel", leaf, Vector3(size.x * 0.5 - 0.14, 0.14, 0.03), Vector3(0.05, 0.07, 0.012), SLIGHT)
	coarse()


## The guardroom inside the gate: a room of brick on a plinth under a slab
## of concrete, its footprint `size` around `centre` (x and z). Its door and
## a window look west at the road in from the gate, a second window looks
## north across the yard. A stove pipe stands on its roof. Its door has
## `plate` over it, if that says anything, and with `fire` a fire point
## hangs on its north wall.
func guardroom(centre: Vector2, size: Vector3, plate := "GUARDROOM", fire := true) -> void:
	var foot := Vector3(centre.x, YARD_Y, centre.y)
	_collide_box(Transform3D(Basis(), foot + Vector3.UP * size.y * 0.5), size, "brick")
	var thick := 0.3
	var doorway := Rect2(1.42, -1.0, 0.96, 3.08)
	var looks := {
		Vector3.LEFT: [doorway, Rect2(2.95, 1.0, 1.3, 1.15)],
		Vector3.FORWARD: [Rect2(1.7, 1.0, 2.6, 1.15)],
		Vector3.RIGHT: [],
		Vector3.BACK: [],
	}
	for out: Vector3 in looks:
		var face := face_of(foot, size, out)
		var wide := absf(Vector3.UP.cross(out).dot(size))
		pierced(CONCRETE, face, Rect2(0, -1.0, wide, 1.45), thick, looks[out], 0.05)
		pierced(BRICK, face, Rect2(0, 0.45, wide, size.y - 0.45), thick, looks[out])
		for opening: Rect2 in looks[out]:
			if opening == doorway:
				continue
			var middle := opening.get_center()
			steel_window(face * Transform3D(Basis(), Vector3(middle.x, middle.y, 0)), opening.size, 0.14, Vector2i(roundi(opening.size.x / 0.65), 2))
			square_box(CONCRETE, face, Vector3(middle.x, opening.position.y - 0.04, -0.035), Vector3(opening.size.x + 0.2, 0.1, 0.21))
			square_box(CONCRETE, face, Vector3(middle.x, opening.end.y + 0.09, -0.115), Vector3(opening.size.x + 0.3, 0.2, 0.25))
	# The roof: a slab that oversails the walls, with a kerb round its edge.
	box(CONCRETE, foot + Vector3.UP * (size.y + 0.1), Vector3(size.x + 0.7, 0.2, size.z + 0.7), Vector3.ZERO, SLIGHT)
	box(CONCRETE, foot + Vector3.UP * (size.y + 0.24), Vector3(size.x + 0.5, 0.1, size.z + 0.5), Vector3.ZERO, SLIGHT)
	fine(MID)
	cylinder("galvanised", foot + Vector3(size.x * 0.3, size.y + 0.2, size.z * 0.2), 0.07, 1.3, SLIGHT, Vector3.ZERO, -1.0, 10)
	cylinder("galvanised", foot + Vector3(size.x * 0.3, size.y + 1.5, size.z * 0.2), 0.12, 0.05, SLIGHT, Vector3.ZERO, 0.02, 10)
	coarse()
	# The door, its step, its lamp and its name.
	var west := face_of(foot, size, Vector3.LEFT)
	var door_x := doorway.get_center().x
	steel_door(west * Transform3D(Basis(), Vector3(door_x, 0.04, 0)), Vector2(doorway.size.x, 2.04), 0.12)
	square_box(CONCRETE, west, Vector3(door_x, 0.0, 0.3), Vector3(1.5, 0.16, 0.6))
	square_box(CONCRETE, west, Vector3(door_x, 2.17, -0.1), Vector3(doorway.size.x + 0.3, 0.18, 0.3))
	fine(MID)
	bulkhead(west * Vector3(door_x, 2.55, 0), Vector3.LEFT)
	if plate != "":
		sign_plate(west * Vector3(door_x, 2.32, 0.012), Vector3.LEFT, plate, 0.14, "enamel_red")
	downpipe(face_of(foot, size, Vector3.RIGHT) * Vector3(0.4, 0, 0), Vector3.RIGHT, size.y)
	coarse()
	if fire:
		fire_point(face_of(foot, size, Vector3.FORWARD) * Transform3D(Basis(), Vector3(5.1, 0, 0)))


## A fire point on a wall: a red board with two buckets of sand on hooks
## and a beater, under its name. `xf` stands at the foot of the wall under
## its middle, with Z out of the wall.
func fire_point(xf: Transform3D) -> void:
	fine(NEAR)
	_local_box("dark_steel", xf, Vector3(0, 1.35, 0.012), Vector3(1.1, 0.9, 0.024), SLIGHT)
	painted(xf * Transform3D(Basis(), Vector3(0, 1.35, 0.0245)), Vector2(1.09, 0.89), Color(SIGNAL_RED, 0.3))
	for x: float in [-0.28, 0.28]:
		_local_box("dark_steel", xf, Vector3(x, 1.62, 0.07), Vector3(0.02, 0.02, 0.1), SLIGHT)
		rod("dark_steel", xf * Vector3(x - 0.13, 1.5, 0.13), xf * Vector3(x, 1.63, 0.11), 0.005, SLIGHT, 4)
		rod("dark_steel", xf * Vector3(x + 0.13, 1.5, 0.13), xf * Vector3(x, 1.63, 0.11), 0.005, SLIGHT, 4)
		revolve("enamel_red", xf * Transform3D(Basis(), Vector3(x, 1.2, 0.15)), PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.135, 0.3), Vector2(0.125, 0.3), Vector2(0.0, 0.27)]), SLIGHT, 12)
	sign_plate(xf * Vector3(0, 1.93, 0.0), xf.basis.z, "FIRE POINT", 0.12, "enamel_red")
	coarse()


# --- The yard ----------------------------------------------------------------------


## Slabs of concrete over the ground of `area` (x and z), each about `slab`
## large: a road, an apron, the floor of a shed. None lies quite level with
## the next. They are laid on the ground and are in nobody's way: what is
## walked on is still the ground under them, which knows that it is paved.
func paving(area: Rect2, slab := Vector2(5.0, 3.5)) -> void:
	# The game is told where they lie, on the ground itself: a step or a
	# shot there is on concrete. See Fx.surface_of().
	var land := _root.get_node_or_null("Ground/CollisionShape3D")
	if land:
		var paved: Array = land.get_meta(&"paved", [])
		paved.append(area)
		land.set_meta(&"paved", paved)
	var across := maxi(1, roundi(area.size.x / slab.x))
	var down := maxi(1, roundi(area.size.y / slab.y))
	var size := area.size / Vector2(across, down)
	fine(FAR)
	for j in down:
		for i in across:
			var middle := area.position + (Vector2(i, j) + Vector2(0.5, 0.5)) * size
			var lift := _depot_rng.randf_range(0.03, 0.044)
			var tilt := Vector3(_depot_rng.randf_range(-0.1, 0.1), 0, _depot_rng.randf_range(-0.1, 0.1))
			box(SLAB, Vector3(middle.x, YARD_Y + lift - 0.06, middle.y), Vector3(size.x - 0.025, 0.12, size.y - 0.025), tilt, SLIGHT)
	coarse()


## The frame of something painted on the ground at `at` (x and z), to be
## read by whoever looks along `heading`: X to his right, Y away from him
## and Z up.
func on_ground_frame(at: Vector2, heading: Vector2, lift := 0.058) -> Transform3D:
	var ahead := Vector3(heading.x, 0, heading.y).normalized()
	return Transform3D(Basis(ahead.cross(Vector3.UP), ahead, Vector3.UP), Vector3(at.x, YARD_Y + lift, at.y))


## A line of paint on the ground from `from` to `to` (x and z).
func road_line(from: Vector2, to: Vector2, width := 0.12, colour := WHITEWASH) -> void:
	painted(on_ground_frame((from + to) * 0.5, (to - from).orthogonal()), Vector2(from.distance_to(to), width), colour)


## A box on the ground that nothing is to be stood in: the outline of
## `area` (x and z) with stripes across it.
func road_hatch(area: Rect2, colour := SIGNAL_YELLOW, every := 0.9, width := 0.14) -> void:
	var corners: Array[Vector2] = [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]
	for i in 4:
		road_line(corners[i], corners[(i + 1) % 4], width, colour)
	var run := every
	while run < area.size.x + area.size.y:
		var from := Vector2(area.position.x + run, area.position.y)
		var to := Vector2(area.position.x + run - area.size.y, area.end.y)
		if from.x > area.end.x:
			from = Vector2(area.end.x, area.position.y + (from.x - area.end.x))
		if to.x < area.position.x:
			to = Vector2(area.position.x, area.end.y - (area.position.x - to.x))
		road_line(from, to, width, colour)
		run += every


## Kerbstones along the ground from `from` to `to` (x and z). With
## `whitewashed`, every other one is painted white, as an army has them.
func kerb(from: Vector2, to: Vector2, whitewashed := false) -> void:
	var length := from.distance_to(to)
	var stones := maxi(1, roundi(length / 0.95))
	var pitch := length / stones
	var way := (to - from) / length
	fine(MID)
	for i in stones:
		var middle := from + way * pitch * (i + 0.5)
		var xf := Transform3D(Basis(Vector3.UP, atan2(-way.y, way.x) + _depot_rng.randf_range(-0.012, 0.012)), Vector3(middle.x, YARD_Y + 0.02 + _depot_rng.randf_range(-0.012, 0.008), middle.y))
		_box(CONCRETE, xf, Vector3(pitch - 0.016, 0.28, 0.15), SLIGHT)
		if whitewashed and i % 2 == 0:
			painted(xf * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.1415, 0)), Vector2(pitch - 0.016, 0.15), WHITEWASH)
			for side: float in [-1.0, 1.0]:
				painted(xf * Transform3D(Basis(Vector3.UP, 0.0 if side > 0.0 else PI), Vector3(0, 0.07, side * 0.0765)), Vector2(pitch - 0.016, 0.14), WHITEWASH)
	coarse()


## The grating of a gully in a road at `at` (x and z).
func gully(at: Vector2, turned := false) -> void:
	var xf := Transform3D(Basis(Vector3.UP, PI * 0.5 if turned else 0.0), Vector3(at.x, YARD_Y + 0.058, at.y))
	fine(NEAR)
	painted(xf * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, -0.004, 0)), Vector2(0.5, 0.38), STENCIL_BLACK)
	for side: float in [-1.0, 1.0]:
		_local_box("dark_steel", xf, Vector3(0, 0, side * 0.21), Vector3(0.58, 0.014, 0.05), SLIGHT)
		_local_box("dark_steel", xf, Vector3(side * 0.265, 0, 0), Vector3(0.05, 0.014, 0.38), SLIGHT)
	for bar in 7:
		_local_box("dark_steel", xf, Vector3(-0.21 + bar * 0.07, 0, 0), Vector3(0.028, 0.012, 0.38), SLIGHT)
	coarse()


## The lid of a manhole in a road at `at` (x and z).
func manhole(at: Vector2) -> void:
	fine(NEAR)
	cylinder("dark_steel", Vector3(at.x, YARD_Y + 0.046, at.y), 0.31, 0.014, SLIGHT, Vector3.ZERO, -1.0, 16)
	for bar: float in [-0.12, 0.0, 0.12]:
		box("dark_steel", Vector3(at.x + bar, YARD_Y + 0.062, at.y), Vector3(0.03, 0.006, 0.4 - absf(bar)), Vector3.ZERO, SLIGHT)
	coarse()


## What the ground of `area` (x and z) inside the wall is: sand packed with
## gravel and earth, in patches, darkest along `ways`, where it is driven on
## (each a path of x and z) and wheels have left their ruts, and with the
## bare sand the wind brings lying along the sides of it that are walls.
func yard_cover(area: Rect2, ways: Array, seed := 5, walled := Vector4(1, 1, 1, 1)) -> void:
	if _cover == null:
		return
	var blotch := _noise(seed, 15.0)
	var speck := _noise(seed + 9, 4.6)
	var from := ((area.position - _land.position) * COVER_SCALE).floor()
	var to := ((area.end - _land.position) * COVER_SCALE).ceil()
	var boxes: Array[Rect2] = []
	for way: PackedVector2Array in ways:
		boxes.append(_around(way, 3.0))
		# The ground draws the ruts of whatever it knows as a track, see
		# _read_land() in tools/kit/land.gd: these are tracks to it.
		_tracks.append({"path": way, "width": 3.0})
	for y in range(maxi(int(from.y), 0), mini(int(to.y), _cover.get_height())):
		for x in range(maxi(int(from.x), 0), mini(int(to.x), _cover.get_width())):
			var at := _land.position + Vector2(x + 0.5, y + 0.5) / COVER_SCALE
			var earth := 0.6 + 0.6 * (blotch.get_noise_2dv(at) * 0.7 + speck.get_noise_2dv(at) * 0.3)
			# How near the nearest wall is: `walled` says which sides of the
			# area are walls, west, north, east and south.
			var edge := INF
			if walled.x > 0.0:
				edge = minf(edge, at.x - area.position.x)
			if walled.y > 0.0:
				edge = minf(edge, at.y - area.position.y)
			if walled.z > 0.0:
				edge = minf(edge, area.end.x - at.x)
			if walled.w > 0.0:
				edge = minf(edge, area.end.y - at.y)
			earth -= (1.0 - smoothstep(0.2, 3.2, edge)) * 0.5
			for i in ways.size():
				if boxes[i].has_point(at):
					earth = maxf(earth, 0.9 * (1.0 - smoothstep(1.5, 2.9, _nearest_on(ways[i], at).x)))
			_lay_dot(x, y, COVERS.earth, clampf(earth, 0.0, 1.0))


## Moss on the ground along the foot of a wall the sun never reaches, from
## `from` to `to` (x and z) and out to `width` on the side `out`.
func moss_along(from: Vector2, to: Vector2, out: Vector2, width := 1.6) -> void:
	if _cover == null:
		return
	var patch := _noise(31, 6.0)
	var steps := int(from.distance_to(to) * COVER_SCALE)
	for i in steps + 1:
		var foot := from.lerp(to, float(i) / maxf(steps, 1.0))
		var much := clampf(0.55 + 0.9 * patch.get_noise_2dv(foot), 0.0, 1.0)
		for j in int(width * COVER_SCALE) + 1:
			var at := foot + out * (j + 0.5) / COVER_SCALE
			var dot_at := ((at - _land.position) * COVER_SCALE).floor()
			if dot_at.x < 0.0 or dot_at.y < 0.0 or dot_at.x >= _cover.get_width() or dot_at.y >= _cover.get_height():
				continue
			_lay_dot(int(dot_at.x), int(dot_at.y), COVERS.moss, much * (1.0 - smoothstep(0.2, width, (j + 0.5) / COVER_SCALE)))


## Sand that the wind has laid against the foot of a wall: along its face
## from `from` to `to` (x and z), on the side `out`, up to `height` high
## against the wall and `reach` wide, more here than there. It is the
## ground's own sand, and in nobody's way.
func sand_drift(from: Vector2, to: Vector2, out: Vector3, height := 0.5, reach := 2.4, seed := 3) -> void:
	var length := from.distance_to(to)
	var steps := maxi(1, roundi(length))
	var way := (to - from) / length
	var heap := _noise(seed, 9.0)
	var ripple := _noise(seed + 5, 2.7)
	var flip := Vector3(way.x, 0, way.y).cross(Vector3.UP).dot(out) < 0.0
	var before: Array[Vector3] = []
	var before_normals: Array[Vector3] = []
	for i in steps + 1:
		var at := from + way * length * i / steps
		var much := clampf(0.5 + 0.65 * heap.get_noise_2dv(at) + 0.25 * ripple.get_noise_2dv(at), 0.0, 1.0)
		var taper := smoothstep(0.0, 3.0, minf(i, steps - i) * length / steps)
		var wide := 0.5 + reach * much
		var outer := ground(at.x + out.x * wide, at.y + out.z * wide, -0.06)
		var inner := Vector3(at.x, maxf(ground_height(at.x, at.y), outer.y) + 0.03 + (0.05 + height * much * much) * taper, at.y)
		var half := inner.lerp(outer, 0.42)
		half.y = lerpf(outer.y + 0.06, inner.y, 0.34)
		var steep := (out * (inner.y - half.y) + Vector3.UP * wide * 0.42).normalized()
		var gentle := (out * (half.y - outer.y) + Vector3.UP * wide * 0.58).normalized()
		var points: Array[Vector3] = [inner, half, outer]
		var normals: Array[Vector3] = [steep, (steep + gentle).normalized(), Vector3.UP]
		if i > 0:
			# With the grass of that block of ground: not drawn from afar, and
			# without a shadow, see _commit() in tools/kit/land.gd.
			@warning_ignore("integer_division")
			var st := _tool_named("|strewn %d %d/dune_ground" % [int(half.x) / GROUND_BLOCK, int(half.z) / GROUND_BLOCK])
			for row in 2:
				var corners := [before[row + 1], points[row + 1], points[row], before[row]]
				var facing := [before_normals[row + 1], normals[row + 1], normals[row], before_normals[row]]
				if flip:
					corners.reverse()
					facing.reverse()
				for corner: int in [0, 2, 1, 0, 3, 2]:
					# What the ground's material reads off a mesh, see
					# shaders/dune_ground.gdshader: level, loose sand without
					# crust or grass, and far from any track.
					st.set_color(Color(0.5, 1.0, 0.0, 0.0))
					st.set_normal(facing[corner])
					st.set_uv(Vector2(corners[corner].x, corners[corner].z))
					st.set_uv2(Vector2(6.0, 0.0))
					st.add_vertex(corners[corner])
		before = points
		before_normals = normals


## Clumps of marram at the foot of a wall, along its face from `from` to `to`
## (x and z) and within `reach` of it on the side `out`: about one every
## `every` metres, in twos and threes.
func wall_tufts(from: Vector2, to: Vector2, out: Vector2, every := 5.0, reach := 1.2) -> void:
	var length := from.distance_to(to)
	var run := _depot_rng.randf_range(0.0, every)
	while run < length:
		for one in _depot_rng.randi_range(1, 3):
			var at := from.lerp(to, clampf((run + _depot_rng.randf_range(-0.7, 0.7)) / length, 0.0, 1.0)) + out * _depot_rng.randf_range(0.25, reach)
			marram_clump(at, _depot_rng.randf_range(0.45, 0.95), _depot_rng.randi())
		run += every * _depot_rng.randf_range(0.5, 1.7)


# --- Doors that are shut, and what is on the roof --------------------------------------


## A sliding door hung on the outside of a wall, shut: `xf` stands on the
## ground in the middle of the doorway it covers, on the face of the wall
## with Z out of it. The leaf is `size`, hangs on rollers from a rail that
## runs on to the side it slides to (`slides`, 1 or -1 along X), and has a
## wicket for a man in it.
func sliding_door(xf: Transform3D, size: Vector2, slides := 1.0) -> void:
	var mat := "army_green"
	var half := size * 0.5
	var leaf := xf * Transform3D(Basis(), Vector3(0, half.y + 0.05, 0.1))
	fine(FAR)
	for x: float in [-half.x + 0.06, 0.0, half.x - 0.06]:
		_local_box(mat, leaf, Vector3(x, 0, 0), Vector3(0.12, size.y, 0.08), SLIGHT)
	for y: float in [-half.y + 0.06, 0.0, half.y - 0.06]:
		_local_box(mat, leaf, Vector3(0, y, 0), Vector3(size.x - 0.24, 0.12, 0.08), SLIGHT)
	corrugated(mat, leaf * Transform3D(Basis(), Vector3(0, 0, 0.012)), Vector2(size.x - 0.2, size.y - 0.2), 0.3, 0.028, SLIGHT)
	# The rail, its brackets, and the rollers the leaf hangs from.
	var rail_y := size.y + 0.24
	var rail := xf * Transform3D(Basis(), Vector3(slides * half.x * 1.0, rail_y, 0.13))
	_local_box("dark_steel", rail, Vector3.ZERO, Vector3(size.x * 2.0 + 0.5, 0.16, 0.1), SLIGHT)
	_local_box("dark_steel", rail, Vector3(0, 0.1, -0.02), Vector3(size.x * 2.0 + 0.5, 0.04, 0.22), SLIGHT)
	for i in 7:
		_local_box("dark_steel", rail, Vector3((i - 3) * (size.x * 2.0 + 0.3) / 6.0, 0.02, -0.08), Vector3(0.08, 0.34, 0.1), SLIGHT)
	for x: float in [-half.x * 0.6, half.x * 0.6]:
		_local_box("dark_steel", leaf, Vector3(x, half.y + 0.1, 0.03), Vector3(0.12, 0.26, 0.05), SLIGHT)
	refine(MID)
	# The channel its foot runs in, the wicket, and what it is pulled by.
	_local_box("dark_steel", xf, Vector3(slides * half.x, 0.03, 0.12), Vector3(size.x * 2.0 + 0.3, 0.06, 0.14), SLIGHT)
	var wicket := leaf * Transform3D(Basis(), Vector3(-slides * half.x * 0.5, -half.y + 1.08, 0.045))
	for x: float in [-0.46, 0.46]:
		_local_box(mat, wicket, Vector3(x, 0, 0), Vector3(0.05, 2.0, 0.02), SLIGHT)
	_local_box(mat, wicket, Vector3(0, 1.0, 0), Vector3(0.97, 0.05, 0.02), SLIGHT)
	for y: float in [-0.6, 0.6]:
		_local_box("dark_steel", wicket, Vector3(-0.44, y, 0.014), Vector3(0.1, 0.12, 0.012), SLIGHT)
	rounded_box("dark_steel", wicket * Transform3D(Basis(), Vector3(0.34, 0.0, 0.03)), Vector3(0.035, 0.16, 0.05), 0.012, SLIGHT)
	rounded_box("dark_steel", leaf * Transform3D(Basis(), Vector3(slides * (half.x - 0.2), -half.y + 1.2, 0.07)), Vector3(0.04, 0.5, 0.06), 0.015, SLIGHT)
	coarse()


## A dish aerial: a bowl `radius` across its half, painted a dull grey, on a
## frame of ribs, with its feed on four struts before it and a yoke under it
## to turn it by. `xf` stands in the middle of the bowl with Y the way it
## looks; `foot` is the top of whatever carries it.
func dish(xf: Transform3D, radius: float, foot: Vector3) -> void:
	var deep := radius * 0.26
	var focus := radius * radius / (4.0 * deep)
	fine(FAR)
	var bowl := PackedVector2Array()
	var back := PackedVector2Array()
	for i in 9:
		var r := radius * i / 8.0
		bowl.append(Vector2(r, deep * r * r / (radius * radius)))
	for i in 9:
		var r := radius * i / 8.0
		back.append(Vector2(r, deep * r * r / (radius * radius) - 0.06))
	# Seen from before it and from behind: the two sides of the bowl. A
	# profile that runs in to the middle faces up, one that runs out faces down.
	var inside := PackedVector2Array()
	for i in 9:
		inside.append(bowl[8 - i])
	revolve("depot_dish", xf, inside, SLIGHT, 28, true)
	revolve("depot_dish", xf, back, SLIGHT, 28, true)
	# The rim, the ribs behind and the ring that ties them.
	_m = xf
	_part = SLIGHT
	_ring("dark_steel", Vector3(0, deep, 0), Vector3.UP, radius, 0.05)
	for i in 12:
		var turn := Basis(Vector3.UP, TAU * i / 12.0)
		beam("dark_steel", xf * (turn * Vector3(0.5, -0.5, 0)), xf * (turn * Vector3(radius * 0.97, deep * 0.94 - 0.06, 0)), 0.07, SLIGHT)
		beam("dark_steel", xf * (turn * Vector3(radius * 0.5, deep * 0.25 - 0.1, 0)), xf * (Basis(Vector3.UP, TAU * (i + 1) / 12.0) * Vector3(radius * 0.5, deep * 0.25 - 0.1, 0)), 0.06, SLIGHT)
	cylinder("dark_steel", xf * Vector3(0, -0.75, 0), 0.55, 0.7, SLIGHT, xf.basis.get_euler() * 180.0 / PI, -1.0, 12)
	# The feed, on four struts from the rim.
	for i in 4:
		var turn := Basis(Vector3.UP, TAU * (i + 0.5) / 4.0)
		rod("dark_steel", xf * (turn * Vector3(radius * 0.96, deep * 0.92, 0)), xf * Vector3(0, focus - 0.1, 0), 0.035, SLIGHT, 6)
	cylinder("depot_dish", xf * Vector3(0, focus - 0.45, 0), 0.2, 0.5, SLIGHT, xf.basis.get_euler() * 180.0 / PI, 0.32, 10)
	# The yoke: two arms up from the turntable to the back of the bowl.
	var hub := xf * Vector3(0, -0.45, 0)
	var across := xf.basis.x.normalized()
	box("dark_steel", foot + Vector3.UP * 0.15, Vector3(2.2, 0.3, 2.2), Vector3.ZERO, SLIGHT)
	for side: float in [-1.0, 1.0]:
		beam("dark_steel", foot + across * side * 0.9 + Vector3.UP * 0.3, hub + across * side * 0.75, 0.22, SLIGHT)
	beam("dark_steel", hub - across * 0.9, hub + across * 0.9, 0.16, SLIGHT)
	_part = NO_COLLIDE
	coarse()


# --- What hangs on a wall and stands against it ----------------------------------------


## A bulkhead lamp on a wall: a cast housing with a cage over its glass.
## `at` is the middle of its back on the face of the wall, which looks along
## `out`. By day it is off, a fitting that lights nothing; by night it burns.
func bulkhead(at: Vector3, out: Vector3) -> void:
	var on_wall := Transform3D(Basis(Vector3.UP.cross(out), Vector3.UP, out), at)
	rounded_box("dark_steel", on_wall * Transform3D(Basis(), Vector3(0, 0, 0.04)), Vector3(0.36, 0.22, 0.08), 0.02, SLIGHT)
	if _by_night:
		_local_box("lamp_glass", on_wall, Vector3(0, 0, 0.085), Vector3(0.27, 0.14, 0.012), SLIGHT)
		night_bulb(on_wall * Vector3(0, -0.04, 0.32), BULB_LIGHT, 1.3, 5.5)
	else:
		painted(on_wall * Transform3D(Basis(), Vector3(0, 0, 0.082)), Vector2(0.27, 0.14), Color(0.62, 0.6, 0.5, 0.3))
	for bar: float in [-0.09, 0.0, 0.09]:
		_local_box("dark_steel", on_wall, Vector3(bar, 0, 0.1), Vector3(0.012, 0.17, 0.03), SLIGHT)
	_local_box("dark_steel", on_wall, Vector3(0, 0, 0.1), Vector3(0.3, 0.012, 0.03), SLIGHT)


## A ladder up a wall with hoops round it from above a man's reach: `foot`
## is where its lowest rung is, on the face of the wall, which looks along
## `out`, and it is `height` high.
func cage_ladder(foot: Vector3, out: Vector3, height: float) -> void:
	var on_wall := Transform3D(Basis(Vector3.UP.cross(out), Vector3.UP, out), foot)
	fine(MID)
	for side: float in [-1.0, 1.0]:
		_local_box("dark_steel", on_wall, Vector3(side * 0.24, height * 0.5 + 0.5, 0.2), Vector3(0.05, height + 1.0, 0.012), SLIGHT)
	for rung in int(height / 0.3) + 1:
		rod("dark_steel", on_wall * Vector3(-0.24, rung * 0.3, 0.2), on_wall * Vector3(0.24, rung * 0.3, 0.2), 0.011, SLIGHT, 5)
	for stay in int(height / 2.4) + 1:
		for side: float in [-1.0, 1.0]:
			_local_box("dark_steel", on_wall, Vector3(side * 0.24, 0.4 + stay * 2.4, 0.1), Vector3(0.04, 0.008, 0.2), SLIGHT)
	# The hoops, and the three straps that tie them.
	var around := 7
	for hoop in int((height - 2.2) / 0.9) + 1:
		var y := 2.2 + hoop * 0.9
		for s in around:
			var a0 := PI * s / around
			var a1 := PI * (s + 1) / around
			beam("dark_steel", on_wall * Vector3(cos(a0) * 0.36, y, 0.2 + sin(a0) * 0.62), on_wall * Vector3(cos(a1) * 0.36, y, 0.2 + sin(a1) * 0.62), 0.04, SLIGHT, 0.006)
	for strap: float in [0.25, 0.5, 0.75]:
		var angle := PI * strap
		_local_box("dark_steel", on_wall, Vector3(cos(angle) * 0.36, (2.2 + height + 0.9) * 0.5, 0.2 + sin(angle) * 0.62), Vector3(0.03, height - 1.3, 0.006), SLIGHT)
	coarse()


## A duct of galvanised sheet up a wall, from a louvre a man's height up to
## over the edge of the roof: `foot` is where it begins on the face of the
## wall, which looks along `out`; `height` is how high the edge of the roof
## is above that.
func duct_riser(foot: Vector3, out: Vector3, height: float, size := Vector2(0.7, 0.45)) -> void:
	var on_wall := Transform3D(Basis(Vector3.UP.cross(out), Vector3.UP, out), foot)
	fine(FAR)
	_local_box("galvanised", on_wall, Vector3(0, height * 0.5, size.y * 0.5 + 0.08), Vector3(size.x, height, size.y), SLIGHT)
	_local_box("galvanised", on_wall, Vector3(0, height + size.y * 0.5, -0.4 + (size.y + 0.08 + 0.4) * 0.5), Vector3(size.x, size.y, size.y + 0.08 + 0.8), SLIGHT)
	# Where it begins: a box on the wall with a louvre in its face.
	_local_box("galvanised", on_wall, Vector3(0, -0.5, size.y * 0.5 + 0.12), Vector3(size.x + 0.3, 1.1, size.y + 0.08), SLIGHT)
	refine(MID)
	for joint in int(height / 1.5) + 1:
		_local_box("galvanised", on_wall, Vector3(0, joint * 1.5, size.y * 0.5 + 0.08), Vector3(size.x + 0.07, 0.035, size.y + 0.07), SLIGHT)
		if joint % 2 == 1:
			_local_box("dark_steel", on_wall, Vector3(0, joint * 1.5 + 0.3, 0.04), Vector3(size.x + 0.24, 0.05, 0.08), SLIGHT)
	for slat in 8:
		_box("dark_steel", on_wall * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(35.0)), Vector3(0, -0.92 + slat * 0.105, size.y + 0.17)), Vector3(size.x + 0.14, 0.006, 0.09), SLIGHT)
	coarse()


## A tarpaulin thrown over something of more than one height, a tank or a
## gun, where tarpaulin() of the field covers a stack: over what stands in
## `boxes`, each the [middle, size] of a box in the frame `xf`: it lies on their tops, hangs taut between one
## high place and the next and falls from the edge of the first of them,
## the widest, to `hem` over the ground. It takes the place of nothing: what
## is under it is in the way as it was.
func sheeted(xf: Transform3D, boxes: Array, hem := 0.4) -> void:
	var under: Vector3 = boxes[0][0]
	var spread: Vector3 = boxes[0][1] + Vector3(0.16, 0, 0.16)
	var across := maxi(2, ceili(spread.x / 0.3))
	var down := maxi(2, ceili(spread.z / 0.3))
	var creases := _noise(_depot_rng.randi() % 1000, 0.9)
	# How high the cloth lies at a spot of the frame.
	var lies := func(x: float, z: float) -> float:
		var high := -INF
		for part: Array in boxes:
			var middle: Vector3 = part[0]
			var size: Vector3 = part[1]
			var beyond := Vector2(maxf(absf(x - middle.x) - size.x * 0.5, 0.0), maxf(absf(z - middle.z) - size.z * 0.5, 0.0)).length()
			high = maxf(high, middle.y + size.y * 0.5 + 0.04 - beyond * 0.85)
		return high + creases.get_noise_2d(x, z) * 0.035
	var st := _tool(CANVAS, SLIGHT, xf * under)
	var spots := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tones := PackedColorArray()
	for j in down + 1:
		for i in across + 1:
			var x := under.x + spread.x * (float(i) / across - 0.5)
			var z := under.z + spread.z * (float(j) / down - 0.5)
			spots.append(xf * Vector3(x, lies.call(x, z), z))
			uvs.append(Vector2(x, z))
			tones.append(Color(0.12, 0.5 + creases.get_noise_2d(z, x) * 0.3, 0.85, 0.0))
	_cloth(st, spots, across, uvs, tones, xf.basis.y)
	# The four sides, each hanging from the edge of the top to the hem, a
	# little out at the foot, and never straight along it.
	var corners: Array[Vector2] = [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]
	for side in 4:
		var from := corners[side]
		var to := corners[(side + 1) % 4]
		var out := Vector2((from + to).x, (from + to).y).normalized()
		var steps := maxi(2, ceili((to - from).length() * (spread.x if from.y == to.y else spread.z) / 0.3))
		spots = PackedVector3Array()
		uvs = PackedVector2Array()
		tones = PackedColorArray()
		for row in 4:
			var drop := row / 3.0
			for i in steps + 1:
				var along := from.lerp(to, float(i) / steps)
				var x := under.x + spread.x * along.x
				var z := under.z + spread.z * along.y
				var top: float = lies.call(x, z)
				var flare := drop * (0.07 + 0.06 * creases.get_noise_2d(x * 3.0 + drop, z * 3.0)) + sin(drop * PI) * 0.03
				var low := hem + 0.08 * creases.get_noise_2d(x * 2.0, z * 2.0 + 7.0)
				spots.append(xf * Vector3(x + out.x * flare, lerpf(top, low, drop), z + out.y * flare))
				uvs.append(Vector2((x if from.y == to.y else z), spread.z * 0.5 + drop * (top - low)))
				tones.append(Color(0.12 + 0.5 * drop * drop, 0.5, 0.9, 0.0))
		_cloth(st, spots, steps, uvs, tones, xf.basis * Vector3(out.x, 0, out.y))
