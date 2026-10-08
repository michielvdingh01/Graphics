extends SceneTree
## Shared level generator; the levels themselves live in tools/levels/ and are
## built with tools/build_level.sh <name>.
##
## A level is described in code by overriding _describe() and written to
## scenes/levels/ as merged meshes (lightmapped "static", probe-lit "detail"
## in blocks and unshadowed "glass"), one static body, the props placed from
## assets/models/, and the lights, decals and reflection probes that belong to
## the building. The scene that uses it holds everything that is tuned by
## hand: environment, sun, lightmap, spawns and benchmark views.

const OUT_DIR := "res://scenes/levels/"
## Lightmap texel size in metres. Imported models get the same value through
## the scene import defaults in project.godot.
const TEXEL := 0.08
## Models the prefabs draw from; ids refer to assets/manifest.json.
const BARRELS: Array[String] = ["Barrel_01", "Barrel_02", "barrel_03"]
const CRATE := "wooden_crate_02"
const SMALL_CRATE := "wooden_crate_01"
const BARRIER := "concrete_road_barrier_02"
const RACK := "worn_metal_rack"
const WIDE_RACK := "steel_frame_shelves_03"
const DESK := "metal_office_desk"
const LAMP := "hanging_industrial_lamp"
const CABINETS: Array[String] = ["utility_box_02", "utility_box_01", "utility_box_01"]
const TYRE := "old_tyre"
const GAS_BOTTLE := "propane_tank"
const BAG := "cement_bag"

## Box/cylinder flags.
const DETAIL := 1  # thin or far geometry: no lightmap, lit by probes instead
const NO_COLLIDE := 2
const GLASS := 4  # transparent: no lightmap, no shadow
## Vertex colour of a point that is nowhere near an edge, see _edge().
const NO_EDGE := Color(0.5, 0.5, 1.0, 1.0)
## Floor paint: its resolution in pixels per metre, and the colours in use.
const PAINT_SCALE := 40.0
const PAINT_YELLOW := Color(0.8, 0.57, 0.06)
const PAINT_WHITE := Color(0.76, 0.76, 0.72)
const PAINT_BLACK := Color(0.035, 0.035, 0.035)

var _tools := {}
## Size of the blocks that probe-lit detail is cut into, see _tool(). A level
## under an open sky can do with larger ones. Whatever lies outside
## `_detail_inside`, if a level sets that, goes into one mesh: for the skyline
## beyond the walls, one sample of the probes will do.
var _detail_block := Vector3(14, 6, 12)
var _detail_inside := AABB()
var _shapes := {}
var _root: Node3D
var _body: StaticBody3D
var _lights: Node3D
var _decals: Node3D
var _props: Node3D
## Model id -> {path, scene, box}; scene and box are filled in on first use.
var _models := {}
## Glowing material -> its copy for a lamp that is off.
var _dark := {}
## What is painted on the floor, the part of the floor (x and z) it covers and
## the copy of the floor material that shows it.
var _paint: Image
var _paint_area: Rect2
var _painted_floor: ShaderMaterial
var _rng := RandomNumberGenerator.new()
## Separate streams, so adding glass, decals or model variation never
## reshuffles where the props stand.
var _glass_rng := RandomNumberGenerator.new()
var _decal_rng := RandomNumberGenerator.new()
var _prop_rng := RandomNumberGenerator.new()
var _clutter_rng := RandomNumberGenerator.new()
## Frame of the machine or model being built; the part helpers work in it.
var _m: Transform3D
## Flags those helpers build with: lightmapped, or DETAIL for whatever is too
## thin or hangs too high for a patch of lightmap.
var _part := NO_COLLIDE


func _init() -> void:
	_rng.seed = 7
	_glass_rng.seed = 11
	_decal_rng.seed = 23
	_prop_rng.seed = 31
	_clutter_rng.seed = 43
	_build()
	quit()


## Builds what _describe() describes and writes it out. This one makes a
## level; tools/model_builder.gd overrides it to make models.
func _build() -> void:
	_root = Node3D.new()
	_root.name = _level_name().capitalize() + "Level"
	_body = StaticBody3D.new()
	_body.name = "Collision"
	_add(_body, _root)
	_lights = Node3D.new()
	_lights.name = "Lights"
	_add(_lights, _root)
	_decals = Node3D.new()
	_decals.name = "Decals"
	_add(_decals, _root)
	_props = Node3D.new()
	_props.name = "Props"
	_add(_props, _root)

	_describe()

	var kinds := {}
	for key: String in _tools:
		kinds[key.get_slice("/", 0)] = true
	# Detail comes in as many meshes as it has blocks; clear out last time's.
	var folder := DirAccess.open(OUT_DIR)
	for file in folder.get_files():
		if file.begins_with(_level_name() + "_detail"):
			folder.remove(file)
	var names := kinds.keys()
	names.sort()
	for kind: String in names:
		_commit(kind, kind.replace(" ", "_"))
	var scene := PackedScene.new()
	scene.pack(_root)
	var err := ResourceSaver.save(scene, OUT_DIR + _level_name() + "_level.tscn")
	print("Saved level: ", error_string(err))


## File name stem of the level, e.g. "factory".
func _level_name() -> String:
	return ""


## Builds the level out of the prefabs and geometry builders below.
func _describe() -> void:
	pass


# --- Prefabs -----------------------------------------------------------------


## Wall along X (or Z) at a fixed position on the other axis. Openings are
## [from, to, bottom, top] along the wall.
func wall(mat: String, along_x: bool, fixed: float, thickness: float, a0: float, a1: float, y0: float, y1: float, openings: Array) -> void:
	var sorted := openings.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var cursor := a0
	for o: Array in sorted:
		_wall_piece(mat, along_x, fixed, thickness, cursor, o[0], y0, y1)
		_wall_piece(mat, along_x, fixed, thickness, o[0], o[1], y0, o[2])
		_wall_piece(mat, along_x, fixed, thickness, o[0], o[1], o[3], y1)
		cursor = o[1]
	_wall_piece(mat, along_x, fixed, thickness, cursor, a1, y0, y1)


func _wall_piece(mat: String, along_x: bool, fixed: float, thickness: float, a0: float, a1: float, y0: float, y1: float) -> void:
	if a1 - a0 < 0.001 or y1 - y0 < 0.001:
		return
	var mid := (a0 + a1) * 0.5
	if along_x:
		box(mat, Vector3(mid, (y0 + y1) * 0.5, fixed), Vector3(a1 - a0, y1 - y0, thickness))
	else:
		box(mat, Vector3(fixed, (y0 + y1) * 0.5, mid), Vector3(thickness, y1 - y0, a1 - a0))


## Steel glazing bars and glass panes in a window opening.
func _mullions(center: Vector3, width: float, height: float, along_x: bool, spacing: float) -> void:
	var flags := DETAIL | NO_COLLIDE
	var across := Vector3.RIGHT if along_x else Vector3.BACK
	var n := roundi(width / spacing)
	for i in range(1, n):
		var offset := -width * 0.5 + width * i / n
		box("steel", center + across * offset, Vector3(0.05, height, 0.05), Vector3.ZERO, flags)
	var rows := roundi(height)
	for i in range(1, rows):
		var y := -height * 0.5 + height * i / rows
		var size := Vector3(width, 0.05, 0.05) if along_x else Vector3(0.05, 0.05, width)
		box("steel", center + Vector3(0, y, 0), size, Vector3.ZERO, flags)
	# One pane per cell; a few are long gone.
	var pane := Vector3(width / n, height / rows, 0.012) if along_x else Vector3(0.012, height / rows, width / n)
	for i in n:
		for j in rows:
			if _glass_rng.randf() < 0.1:
				continue
			var offset := across * (-width * 0.5 + width * (i + 0.5) / n) + Vector3(0, -height * 0.5 + height * (j + 0.5) / rows, 0)
			box("glass", center + offset, pane, Vector3.ZERO, GLASS | NO_COLLIDE)


## Yellow tube railing between two points, with one collider for the whole run.
## A level run gets a toe board; one that follows a stair does not.
func railing(from: Vector3, to: Vector3) -> void:
	var flags := DETAIL | NO_COLLIDE
	var up := Vector3(0, 1.05, 0)
	rod("steel_yellow", from + up, to + up, 0.022, flags, 8)
	rod("steel_yellow", from + up * 0.52, to + up * 0.52, 0.017, flags, 8)
	var posts := maxi(1, roundi(Vector2(to.x - from.x, to.z - from.z).length() / 1.5))
	for i in posts + 1:
		var p := from.lerp(to, float(i) / posts)
		rod("steel_yellow", p, p + up, 0.022, flags, 8)
		box("steel_yellow", p + Vector3(0, 0.006, 0), Vector3(0.13, 0.012, 0.13), Vector3.ZERO, flags)
	if absf(to.y - from.y) < 0.01:
		var toe := Vector3(0, 0.062, 0)
		beam("steel_yellow", from + toe, to + toe, 0.006, flags, 0.1)
	var mid := (from + to) * 0.5 + up * 0.5
	var length := from.distance_to(to)
	_collide_box(Transform3D(_along(to - from), mid), Vector3(0.06, 1.05, length))


func crates(at: Vector3, count: int) -> void:
	# Ground slots are far enough apart that the stacks never intersect: the
	# front two stand lengthwise, the back two crosswise. Whatever does not fit
	# on the ground is stacked on top.
	var slots: Array[Vector2] = [Vector2(-0.8, -0.4), Vector2(0.8, -0.3), Vector2(0.1, 1.3), Vector2(-1.6, 1.2)]
	var turn := Basis(Vector3.UP, _rng.randi_range(0, 3) * PI * 0.5)
	var on_ground := count if count <= 2 else mini(count - count / 3, slots.size())
	var ground: Array[Vector3] = []
	for i in count:
		var size := _rng.randf_range(0.85, 1.25)
		var yaw := _rng.randf_range(-15, 15)
		var slot := i
		var pos: Vector3
		if i < on_ground:
			pos = at + turn * Vector3(slots[i].x, size * 0.5, slots[i].y)
			ground.append(pos + Vector3(0, size * 0.5, 0))
		else:
			slot = (i - on_ground) % ground.size()
			var below := ground[slot]
			size = minf(size, 0.95)
			pos = below + Vector3(_rng.randf_range(-0.08, 0.08), size * 0.5, _rng.randf_range(-0.08, 0.08))
		var facing := turn * Basis(Vector3.UP, deg_to_rad(yaw) + (PI * 0.5 if slot >= 2 else 0.0))
		crate(pos, size, facing)


## Stack of wooden crates that is `size` high, centred on `center`; the crates
## lie along the local Z of `facing`.
func crate(center: Vector3, size: float, facing: Basis) -> void:
	var box: AABB = _model(CRATE).box
	# Two crates high, or three smaller ones for a tall stack.
	var layers := 2 if size <= 1.05 else 3
	var scale := size / (layers * box.size.y)
	var base := center - Vector3(0, size * 0.5, 0)
	for i in layers:
		# Nobody stacks crates perfectly square, and some go on back to front.
		var skew := deg_to_rad(_prop_rng.randf_range(-4.0, 4.0)) + (PI if _prop_rng.randf() < 0.5 else 0.0)
		var at := base + Vector3(0, i * box.size.y * scale, 0)
		prop(CRATE, Transform3D(facing * Basis(Vector3.UP, skew), at), scale)
	_collide_box(Transform3D(facing, center), Vector3(box.size.x * scale, size, box.size.z * scale))


## Concrete road barrier, two segments long, centred on `at`.
func barrier(at: Vector3, yaw_deg: float) -> void:
	var box: AABB = _model(BARRIER).box
	var facing := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	for side in [-0.5, 0.5]:
		var skew := Basis(Vector3.UP, deg_to_rad(_prop_rng.randf_range(-1.5, 1.5)))
		prop(BARRIER, Transform3D(facing * skew, at + facing * Vector3(side * (box.size.x + 0.02), 0, 0)))
	_collide_box(Transform3D(facing, at + Vector3(0, box.size.y * 0.5, 0)), Vector3(box.size.x * 2.0, box.size.y, box.size.z))


## Numbers the containers go by; each takes one according to where it stands.
const CONTAINER_NUMBERS: Array[String] = ["KLDU 482316 7", "TRNU 207745 2", "MBCU 931580 4", "HSLU 660192 5", "OVZU 318477 0"]

## Shipping container, 6 m long, of pressed steel panels in a frame of posts
## and rails. `along_x` is the direction of its length; the doors are at the
## far end of it.
func container(mat: String, at: Vector3, along_x: bool, flags := 0) -> void:
	var size := Vector3(6.0, 2.6, 2.4)
	var half := size * 0.5
	var xf := Transform3D(Basis() if along_x else Basis(Vector3.UP, PI * 0.5), at + Vector3(0, half.y, 0))
	if not flags & NO_COLLIDE:
		_collide_box(xf, size)
	var skin := flags | NO_COLLIDE
	# Openings and other dark slivers are not worth a patch of lightmap.
	var hole := skin | DETAIL

	# Corner posts with a casting at either end.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_local_box(mat, xf, Vector3(sx * (half.x - 0.08), 0, sz * (half.z - 0.08)), Vector3(0.14, size.y - 0.2, 0.14), skin)
			for sy: float in [-1.0, 1.0]:
				var corner := Vector3(sx * (half.x - 0.09), sy * (half.y - 0.06), sz * (half.z - 0.085))
				_local_box(mat, xf, corner, Vector3(0.18, 0.12, 0.17), skin)
				# Where a twistlock or a crane hook goes in.
				_local_box("rubber", xf, corner + Vector3(sx * 0.09, 0, 0), Vector3(0.004, 0.06, 0.08), hole)
				_local_box("rubber", xf, corner + Vector3(0, 0, sz * 0.085), Vector3(0.09, 0.06, 0.004), hole)
				_local_box("rubber", xf, corner + Vector3(0, sy * 0.06, 0), Vector3(0.11, 0.004, 0.065), hole)

	# Side rails with forklift pockets, and the side panels between them.
	for sz: float in [-1.0, 1.0]:
		var z := sz * (half.z - 0.04)
		_local_box(mat, xf, Vector3(0, half.y - 0.04, z), Vector3(size.x - 0.36, 0.08, 0.06), skin)
		_local_box(mat, xf, Vector3(0, -half.y + 0.08, z), Vector3(size.x - 0.36, 0.16, 0.06), skin)
		for x: float in [-1.02, 1.02]:
			_local_box("rubber", xf, Vector3(x, -half.y + 0.07, sz * (half.z - 0.01)), Vector3(0.36, 0.09, 0.004), hole)
		var side := Basis(Vector3.UP, 0.0 if sz > 0.0 else PI)
		corrugated(mat, xf * Transform3D(side, Vector3(0, 0.04, sz * (half.z - 0.014))), Vector2(size.x - 0.3, size.y - 0.24), 0.28, 0.036, skin)

	# Rails across both ends, the closed end wall, the roof and the underside.
	for sx: float in [-1.0, 1.0]:
		var x := sx * (half.x - 0.04)
		_local_box(mat, xf, Vector3(x, half.y - 0.06, 0), Vector3(0.06, 0.12, size.z - 0.34), skin)
		_local_box(mat, xf, Vector3(x, -half.y + 0.08, 0), Vector3(0.06, 0.16, size.z - 0.34), skin)
	var door_height := size.y - 0.28
	corrugated(mat, xf * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-half.x + 0.014, 0.02, 0)), Vector2(size.z - 0.3, door_height), 0.26, 0.036, skin)
	corrugated(mat, xf * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, half.y - 0.02, 0)), Vector2(size.x - 0.14, size.z - 0.14), 0.21, 0.018, skin)
	_local_box(mat, xf, Vector3(0, -half.y + 0.14, 0), Vector3(size.x - 0.14, 0.02, size.z - 0.14), skin)

	# Two doors, each a frame around a panel with horizontal pressings, shut
	# by two locking rods.
	var face := half.x - 0.06
	var leaf := 1.045
	var pressed := Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.BACK, PI * 0.5)
	for sz: float in [-1.0, 1.0]:
		var mid := sz * (0.005 + leaf * 0.5)
		for end: float in [-1.0, 1.0]:
			_local_box(mat, xf, Vector3(face - 0.02, 0.02 + end * (door_height * 0.5 - 0.03), mid), Vector3(0.04, 0.06, leaf), skin)
			_local_box(mat, xf, Vector3(face - 0.02, 0.02, mid + end * (leaf * 0.5 - 0.03)), Vector3(0.04, door_height - 0.12, 0.06), skin)
		corrugated(mat, xf * Transform3D(pressed, Vector3(face - 0.012, 0.02, mid)), Vector2(door_height - 0.12, leaf - 0.12), 0.44, 0.02, skin)
		for offset: float in [-0.27, 0.27]:
			var z := mid + offset
			var reach := door_height * 0.5 + 0.02
			rod("steel", xf * Vector3(face + 0.025, 0.02 - reach, z), xf * Vector3(face + 0.025, 0.02 + reach, z), 0.017, skin, 8)
			for end: float in [-1.0, 1.0]:
				_local_box("steel", xf, Vector3(face + 0.02, 0.02 + end * (door_height * 0.5 + 0.04), z), Vector3(0.05, 0.07, 0.08), skin)
			for y: float in [-0.75, 0.15, 0.85]:
				_local_box("steel", xf, Vector3(face + 0.012, y, z), Vector3(0.03, 0.05, 0.07), skin)
			# The handle lies towards the hinges, held down by a catch at its tip.
			_local_box("steel", xf, Vector3(face + 0.025, -0.3, z), Vector3(0.05, 0.07, 0.05), skin)
			_local_box("steel", xf, Vector3(face + 0.04, -0.3, z + sz * 0.12), Vector3(0.012, 0.035, 0.24), skin)
			_local_box("steel", xf, Vector3(face + 0.02, -0.3, z + sz * 0.22), Vector3(0.04, 0.09, 0.04), skin)
		var edge := sz * (half.z - 0.15)
		for y: float in [-0.9, -0.3, 0.3, 0.9]:
			rod("steel", xf * Vector3(face + 0.012, y - 0.06, edge), xf * Vector3(face + 0.012, y + 0.06, edge), 0.014, skin, 6)
			_local_box("steel", xf, Vector3(face + 0.004, y, edge - sz * 0.06), Vector3(0.008, 0.07, 0.12), skin)
	_local_box("rubber", xf, Vector3(face - 0.004, 0.02, 0), Vector3(0.012, door_height, 0.012), hole)

	# Its number on both sides, its type on a door. Not for one that only
	# stands in the distance.
	if flags & DETAIL:
		return
	var light := mat in ["container_grey", "container_orange"]
	var ink := Color(0.07, 0.07, 0.08) if light else Color(0.86, 0.86, 0.82)
	var number := CONTAINER_NUMBERS[posmod(roundi(at.x * 7.0 + at.y * 3.0 + at.z * 13.0), CONTAINER_NUMBERS.size())]
	for sz: float in [-1.0, 1.0]:
		label(number, xf * Vector3(sz * (half.x - 1.25), half.y - 0.42, sz * (half.z - 0.03)), xf.basis * Vector3(0, 0, sz), 0.17, ink)
	label("22G1", xf * Vector3(face - 0.02, 0.78, -0.53), xf.basis * Vector3.RIGHT, 0.12, ink)


## Stack of pallets, each one of boards on nine blocks; the boards run along
## the local X of `yaw`.
func pallet(at: Vector3, yaw: float, stack: int) -> void:
	var wide: Array[float] = [0.145, 0.1, 0.145, 0.1, 0.145]
	for i in stack:
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw + _rng.randf_range(-4, 4))), at + Vector3(0, i * 0.15, 0))
		for j in 3:
			var x := (j - 1) * 0.5275
			var z := (j - 1) * 0.35
			var board: float = wide[j + 1]
			_local_box("wood", xf, Vector3(0, 0.011, z), Vector3(1.2, 0.022, board), NO_COLLIDE)
			_local_box("wood", xf, Vector3(x, 0.117, 0), Vector3(0.145, 0.022, 0.8), NO_COLLIDE)
			for k in 3:
				_local_box("wood", xf, Vector3(x, 0.064, (k - 1) * 0.35), Vector3(0.145, 0.084, wide[k + 1]), NO_COLLIDE)
		for j in 5:
			_local_box("wood", xf, Vector3(0, 0.139, (j - 2) * 0.16375), Vector3(1.2, 0.022, wide[j]), NO_COLLIDE)
	_collide_box(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), at + Vector3(0, stack * 0.075, 0)), Vector3(1.2, stack * 0.15, 0.8))


## Roller shutter `size.x` wide and `size.y` high, seen from the side `normal`
## points to. `center` is the middle of its curtain; the roll sits in a hood
## above that.
func roller_door(center: Vector3, normal: Vector3, size: Vector2) -> void:
	var xf := Transform3D(Basis(Vector3.UP.cross(normal), Vector3.UP, normal), center)
	var half := size * 0.5
	# The slats only face the room, so a plate behind them keeps the daylight out.
	_local_box("steel", xf, Vector3(0, 0, -0.04), Vector3(size.x, size.y, 0.03))
	corrugated("roof", xf * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO), Vector2(size.y - 0.1, size.x), 0.095, 0.014, NO_COLLIDE)
	for side: float in [-1.0, 1.0]:
		_local_box("dark_steel", xf, Vector3(side * (half.x - 0.03), 0, 0.03), Vector3(0.1, size.y, 0.1), NO_COLLIDE)
	_local_box("dark_steel", xf, Vector3(0, -half.y + 0.06, 0.02), Vector3(size.x - 0.16, 0.1, 0.05), NO_COLLIDE)
	_local_box("rubber", xf, Vector3(0, -half.y + 0.008, 0.02), Vector3(size.x - 0.16, 0.016, 0.03), DETAIL | NO_COLLIDE)
	_local_box("bare_steel", xf, Vector3(0, -half.y + 0.07, 0.055), Vector3(0.22, 0.03, 0.02), NO_COLLIDE)
	rounded_box("steel", xf * Transform3D(Basis(), Vector3(0, half.y + 0.21, 0.17)), Vector3(size.x + 0.3, 0.42, 0.42), 0.05, NO_COLLIDE)
	# Hand chain, hanging in a loop from the end of the hood.
	var chain := half.x - 0.18
	_local_box("dark_steel", xf, Vector3(chain, half.y + 0.21, 0.4), Vector3(0.2, 0.26, 0.06), NO_COLLIDE)
	for dx: float in [-0.06, 0.06]:
		rod("dark_steel", xf * Vector3(chain + dx, half.y + 0.1, 0.4), xf * Vector3(chain + dx, -half.y + 1.1, 0.4), 0.006, DETAIL | NO_COLLIDE, 6)


## Steel cupboard with double doors, standing on the ground at `at` and
## facing `yaw_deg` (0 looks along +Z).
func cupboard(mat: String, at: Vector3, yaw_deg: float, size: Vector3) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	_collide_box(xf * Transform3D(Basis(), Vector3(0, size.y * 0.5, 0)), size)
	var front := size.z * 0.5
	var middle := 0.08 + (size.y - 0.08) * 0.5
	_local_box("dark_steel", xf, Vector3(0, 0.04, -0.02), Vector3(size.x - 0.04, 0.08, size.z - 0.08), NO_COLLIDE)
	_local_box(mat, xf, Vector3(0, middle, -0.01), Vector3(size.x, size.y - 0.08, size.z - 0.02), NO_COLLIDE)
	var door := Vector3(size.x * 0.5 - 0.012, size.y - 0.12, 0.02)
	for side: float in [-1.0, 1.0]:
		var mid := Vector3(side * (door.x * 0.5 + 0.003), middle, front)
		rounded_box(mat, xf * Transform3D(Basis(), mid), door, 0.006, NO_COLLIDE)
		for i in 4:
			_local_box("rubber", xf, mid + Vector3(0, door.y * 0.5 - 0.14 - i * 0.035, 0.0105), Vector3(door.x * 0.55, 0.012, 0.002), DETAIL | NO_COLLIDE)
		for y: float in [-0.38, 0.0, 0.38]:
			var pin := mid + Vector3(side * door.x * 0.5, y * door.y, 0.012)
			rod("dark_steel", xf * (pin - Vector3(0, 0.035, 0)), xf * (pin + Vector3(0, 0.035, 0)), 0.008, NO_COLLIDE, 6)
	_local_box("bare_steel", xf, Vector3(0.04, size.y * 0.55, front + 0.014), Vector3(0.045, 0.045, 0.012), NO_COLLIDE)
	_local_box("bare_steel", xf, Vector3(0.04, size.y * 0.55, front + 0.026), Vector3(0.022, 0.12, 0.014), NO_COLLIDE)


## Row of `count` changing-room lockers, centred on `at` and facing `yaw_deg`
## (0 looks along +Z). The ones listed in `open` have their door ajar by that
## many degrees.
func lockers(mat: String, at: Vector3, yaw_deg: float, count: int, open := {}) -> void:
	var width := 0.37
	var height := 1.85
	var depth := 0.5
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	_collide_box(xf * Transform3D(Basis(), Vector3(0, height * 0.5, 0)), Vector3(count * width, height, depth))
	_local_box("dark_steel", xf, Vector3(0, 0.05, -0.02), Vector3(count * width - 0.04, 0.1, depth - 0.08), NO_COLLIDE)
	var middle := 0.1 + (height - 0.1) * 0.5
	var inside := Vector3(width, height - 0.1, depth - 0.02)
	for i in count:
		var body := Vector3((i - (count - 1) * 0.5) * width, middle, -0.01)
		if open.has(i):
			# Walls instead of a block, and a shelf, so there is something to look into.
			for side: float in [-1.0, 1.0]:
				_local_box(mat, xf, body + Vector3(side * (inside.x * 0.5 - 0.006), 0, 0), Vector3(0.012, inside.y, inside.z), NO_COLLIDE)
				_local_box(mat, xf, body + Vector3(0, side * (inside.y * 0.5 - 0.006), 0), Vector3(inside.x, 0.012, inside.z), NO_COLLIDE)
			_local_box(mat, xf, body + Vector3(0, 0, -inside.z * 0.5 + 0.006), Vector3(inside.x, inside.y, 0.012), NO_COLLIDE)
			_local_box(mat, xf, body + Vector3(0, inside.y * 0.5 - 0.3, 0), Vector3(inside.x, 0.012, inside.z - 0.02), NO_COLLIDE)
		else:
			_local_box(mat, xf, body, inside, NO_COLLIDE)
		var door := Vector3(width - 0.016, height - 0.13, 0.018)
		var hinge := Vector3(body.x - door.x * 0.5, middle, depth * 0.5)
		var swing := Basis(Vector3.UP, -deg_to_rad(open.get(i, 0.0)))
		var leaf := xf * Transform3D(swing, hinge) * Transform3D(Basis(), Vector3(door.x * 0.5, 0, 0))
		rounded_box(mat, leaf, door, 0.005, NO_COLLIDE)
		for end: float in [-1.0, 1.0]:
			for k in 3:
				_local_box("rubber", leaf, Vector3(0, end * (door.y * 0.5 - 0.1 - k * 0.03), 0.0095), Vector3(door.x * 0.6, 0.011, 0.002), DETAIL | NO_COLLIDE)
		_local_box("brass", leaf, Vector3(0, door.y * 0.5 - 0.24, 0.0095), Vector3(0.07, 0.03, 0.002), NO_COLLIDE)
		_local_box("bare_steel", leaf, Vector3(door.x * 0.5 - 0.045, 0.02, 0.014), Vector3(0.024, 0.1, 0.012), NO_COLLIDE)


func barrel(at: Vector3) -> void:
	# Every barrel takes one draw from the main stream, so the props placed
	# after it stay put whichever models are on offer.
	_rng.randf()
	var model := BARRELS[_prop_rng.randi_range(0, BARRELS.size() - 1)]
	var box: AABB = _model(model).box
	prop(model, Transform3D(Basis(Vector3.UP, _prop_rng.randf() * TAU), at))
	_collide_cylinder(Transform3D(Basis(), at + Vector3(0, box.size.y * 0.5, 0)), maxf(box.size.x, box.size.z) * 0.5, box.size.y)


## Storage racks against a wall, just under 3 m wide in all and facing
## `yaw_deg` (0 looks along +Z): one wide rack or three narrow ones.
func shelf(at: Vector3, yaw_deg: float, wide: bool) -> void:
	var facing := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	# Where things can stand: [x along the rack, height of the board, room above it].
	var slots: Array = []
	if wide:
		prop(WIDE_RACK, Transform3D(facing, at), 1.0, true)
		slots = [[-0.63, 0.67, 0.6], [0.5, 0.67, 0.38], [0.5, 1.09, 0.62], [-0.63, 1.33, 0.9], [0.5, 1.77, 0.5], [0.5, 0.02, 0.6], [-0.6, 2.31, 0.5], [0.55, 2.31, 0.5]]
	else:
		for i in 3:
			var x := (i - 1) * 0.96
			prop(RACK, Transform3D(facing, at + facing * Vector3(x, 0, 0)), 1.0, true)
			for y: float in [0.45, 0.93, 1.43]:
				slots.append([x, y, 0.44])
	# Nine draws from the main stream whatever the rack holds, so the props
	# placed after a shelf stay put.
	for k in 9:
		if _rng.randf() >= 0.7:
			continue
		var s := _rng.randf_range(0.3, 0.55)
		var wooden := _rng.randf() < 0.6
		var turn := facing * Basis(Vector3.UP, deg_to_rad(_rng.randf_range(-10, 10)))
		if k >= slots.size():
			continue
		var slot: Array = slots[k]
		var base: Vector3 = at + facing * Vector3(slot[0], slot[1], 0.0)
		var kind := _clutter_rng.randi_range(0, 2)
		if wooden:
			# Crates lie along the shelf, scaled to leave room above.
			prop(SMALL_CRATE, Transform3D(turn, base), remap(s, 0.3, 0.55, 0.7, 1.0))
		elif kind == 0 and slot[2] > 0.58:
			prop(GAS_BOTTLE, Transform3D(turn, base))
		elif kind == 1:
			_stack(TYRE, base, turn, _clutter_rng.randi_range(1, 2), Basis(Vector3.RIGHT, PI * 0.5))
		else:
			_stack(BAG, base, turn * Basis(Vector3.UP, PI * 0.5), _clutter_rng.randi_range(1, 2))
	var height: float = _model(WIDE_RACK if wide else RACK).box.size.y
	_collide_box(Transform3D(facing, at + Vector3(0, height * 0.5, 0)), Vector3(2.9, height, 0.72 if wide else 0.6))


## The same model `count` times on top of itself, each turned a little.
func _stack(model: String, base: Vector3, facing: Basis, count: int, pose := Basis()) -> void:
	var step: float = (Transform3D(pose, Vector3.ZERO) * (_model(model).box as AABB)).size.y
	for i in count:
		var skew := Basis(Vector3.UP, deg_to_rad(_clutter_rng.randf_range(-6.0, 6.0)))
		prop(model, Transform3D(facing * skew, base + Vector3(0, i * step * 0.97, 0)), 1.0, false, pose)


## Stack of old tyres lying flat.
func tyres(at: Vector3, count: int) -> void:
	var box: AABB = _model(TYRE).box
	var facing := Basis(Vector3.UP, _clutter_rng.randf() * TAU)
	_stack(TYRE, at, facing, count, Basis(Vector3.RIGHT, PI * 0.5))
	var height := count * box.size.z
	_collide_cylinder(Transform3D(Basis(), at + Vector3(0, height * 0.5, 0)), box.size.x * 0.5, height)


func gas_bottle(at: Vector3) -> void:
	var box: AABB = _model(GAS_BOTTLE).box
	prop(GAS_BOTTLE, Transform3D(Basis(Vector3.UP, _clutter_rng.randf() * TAU), at))
	_collide_cylinder(Transform3D(Basis(), at + Vector3(0, box.size.y * 0.5, 0)), box.size.x * 0.5, box.size.y)


## Pallets with `layers` of cement bags on top: two bags to a layer, every
## other layer turned a quarter.
func bags(at: Vector3, yaw: float, layers: int, pallets := 1) -> void:
	pallet(at, yaw, pallets)
	var box: AABB = _model(BAG).box
	var facing := Basis(Vector3.UP, deg_to_rad(yaw))
	var top := at + Vector3(0, pallets * 0.15, 0)
	for layer in layers:
		var quarter := layer % 2 == 1
		for i in 2:
			# The top layer is sometimes one bag short.
			if layer == layers - 1 and i == 1 and _clutter_rng.randf() < 0.5:
				continue
			var side := (i - 0.5) * (box.size.x + 0.03)
			var offset := Vector3(0, layer * box.size.y * 0.97, side) if quarter else Vector3(side, layer * box.size.y * 0.97, 0)
			var skew := deg_to_rad(_clutter_rng.randf_range(-5.0, 5.0)) + (PI * 0.5 if quarter else 0.0)
			prop(BAG, Transform3D(facing * Basis(Vector3.UP, skew), top + facing * offset))
	var height := layers * box.size.y
	_collide_box(Transform3D(facing, top + Vector3(0, height * 0.5, 0)), Vector3(1.0, height, 0.8))


## Row of switchgear cabinets on a concrete plinth, centred on `at`.
func cabinets(at: Vector3, yaw_deg: float) -> void:
	var facing := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	# The models are street cabinets; scaled up they pass for factory switchgear.
	var scale := 1.45
	var plinth := 0.3
	var gap := 0.03
	var total := -gap
	for id in CABINETS:
		total += _model(id).box.size.x * scale + gap
	_box("concrete", Transform3D(facing, at + Vector3(0, plinth * 0.5, 0)), Vector3(total + 0.2, plinth, 0.85), 0)
	var x := -total * 0.5
	for id in CABINETS:
		var width: float = _model(id).box.size.x * scale
		prop(id, Transform3D(facing, at + facing * Vector3(x + width * 0.5, plinth, 0)), scale)
		x += width + gap
	var size: Vector3 = _model(CABINETS[0]).box.size * scale
	_collide_box(Transform3D(facing, at + Vector3(0, plinth + size.y * 0.5, 0)), Vector3(total, size.y, size.z))


## A model standing on the ground at `at`, with a box collider around it.
func place(model: String, at: Vector3, yaw_deg: float, dynamic := false, scale := 1.0) -> void:
	var facing := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var size: Vector3 = _model(model).box.size * scale
	prop(model, Transform3D(facing, at), scale, dynamic)
	_collide_box(Transform3D(facing, at + Vector3(0, size.y * 0.5, 0)), size)


## A model hung on a wall or a machine: `at` is the middle of its back and
## `yaw_deg` the way its front faces (0 looks along +Z).
func mount(model: String, at: Vector3, yaw_deg: float, dynamic := false) -> void:
	var facing := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var size: Vector3 = _model(model).box.size
	prop(model, Transform3D(facing, at + facing * Vector3(0, -size.y * 0.5, size.z * 0.5)), 1.0, dynamic)


## Something small put down at `at` or left leaning there: no collider, and
## lit by the probes instead of a patch of lightmap. `pose` turns the model
## first, for a tool that was scanned upright and has to lie flat or lean.
func drop(model: String, at: Vector3, yaw_deg: float, pose := Basis()) -> void:
	prop(model, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at), 1.0, true, pose)


## Hanging hall lamp; its rim sits just under `at` and a rod runs up to `hang_y`.
func lamp(at: Vector3, hang_y: float, on: bool, shadows: bool) -> void:
	var height: float = _model(LAMP).box.size.y
	var rim := at + Vector3(0, -0.05, 0)
	var node := prop(LAMP, Transform3D(Basis(), rim), 1.0, true)
	beam("steel", rim + Vector3(0, height - 0.05, 0), Vector3(at.x, hang_y, at.z), 0.02, DETAIL | NO_COLLIDE)
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(i) as BaseMaterial3D
			if material == null:
				continue
			# The glass is imported opaque and hides the bulb, so a lamp that
			# is on gets a glowing lens; one that is off loses the bulb's glow.
			if on and material.resource_name.ends_with("_glass"):
				mesh.set_surface_override_material(i, load("res://materials/emissive_warm.tres"))
			elif not on and material.emission_enabled:
				if not _dark.has(material):
					_dark[material] = material.duplicate()
					_dark[material].emission_enabled = false
				mesh.set_surface_override_material(i, _dark[material])
	if not on:
		return
	var light := SpotLight3D.new()
	light.name = "HallLamp"
	light.position = at + Vector3(0, -0.15, 0)
	light.rotation_degrees = Vector3(-90, 0, 0)
	# Tuned for a lamp 6 m up; one that hangs higher shines harder through a
	# narrower cone, so that the pool of light on the floor stays as it was.
	var drop := (at.y - 0.15) / 5.85
	light.light_color = Color(1.0, 0.74, 0.46)
	light.light_energy = 26.0 * drop * drop
	light.light_volumetric_fog_energy = 1.6 / drop
	light.spot_range = 11.0 + (drop - 1.0) * 5.85
	light.spot_angle = rad_to_deg(atan(tan(deg_to_rad(52.0)) / drop))
	light.spot_angle_attenuation = 0.6
	light.spot_attenuation = 1.2
	light.shadow_enabled = shadows
	light.light_bake_mode = Light3D.BAKE_DYNAMIC
	_add(light, _lights)


## Bare bulb in a cage under the mezzanine.
func bulb(at: Vector3, shadows: bool) -> void:
	cylinder("steel", at + Vector3(0, 0.1, 0), 0.05, 0.25, DETAIL | NO_COLLIDE, Vector3.ZERO, -1.0, 8)
	cylinder("emissive_warm", at, 0.05, 0.1, DETAIL | NO_COLLIDE, Vector3.ZERO, -1.0, 8)
	var light := OmniLight3D.new()
	light.name = "Bulb"
	light.position = at + Vector3(0, -0.1, 0)
	light.light_color = Color(1.0, 0.7, 0.42)
	light.light_energy = 4.0
	light.omni_range = 7.0
	light.omni_attenuation = 1.3
	light.shadow_enabled = shadows
	light.light_bake_mode = Light3D.BAKE_DYNAMIC
	_add(light, _lights)


## Fluorescent ceiling fixture; `reach` is how far its light carries.
func tube(at: Vector3, along_x: bool, on: bool, shadows := true, reach := 7.5) -> void:
	var long := Vector3(1.3, 0, 0) if along_x else Vector3(0, 0, 1.3)
	var cross := Vector3(0, 0, 0.16) if along_x else Vector3(0.16, 0, 0)
	box("steel", at + Vector3(0, 0.03, 0), long + cross + Vector3(0, 0.06, 0), Vector3.ZERO, NO_COLLIDE)
	box("emissive_cool" if on else "plaster", at + Vector3(0, -0.03, 0), long * 0.92 + cross * 0.3 + Vector3(0, 0.04, 0), Vector3.ZERO, DETAIL | NO_COLLIDE)
	if not on:
		return
	var light := OmniLight3D.new()
	light.name = "Tube"
	light.position = at + Vector3(0, -0.25, 0)
	light.light_color = Color(0.82, 0.93, 1.0)
	light.light_energy = 3.0
	light.omni_range = reach
	light.omni_attenuation = 1.4
	light.shadow_enabled = shadows
	light.light_bake_mode = Light3D.BAKE_DYNAMIC
	_add(light, _lights)


func probe(probe_name: String, center: Vector3, size: Vector3, origin: Vector3) -> void:
	var node := ReflectionProbe.new()
	node.name = "Probe" + probe_name
	node.position = center
	node.size = size
	node.origin_offset = origin
	node.box_projection = true
	node.enable_shadows = true
	node.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	node.max_distance = 60.0
	_add(node, _root)


## Places a model from assets/models/ with the centre of its base at the
## origin of `xf`, wherever the model's own origin is; `pose` turns the model
## first, for one that has to lie down. A `dynamic` prop is lit by the lightmap
## probes instead of getting a patch of lightmap. That suits things made of
## thin bars, which a lightmap texel cannot resolve; anything solid looks out
## of place in a dark corner without its own patch. Colliders are up to the
## caller, since a simple shape is all the gameplay needs.
func prop(model: String, xf: Transform3D, scale := 1.0, dynamic := false, pose := Basis()) -> Node3D:
	var info := _model(model)
	var box: AABB = Transform3D(pose, Vector3.ZERO) * (info.box as AABB)
	var base := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var node: Node3D = info.scene.instantiate()
	node.name = model.to_pascal_case()
	node.transform = xf * Transform3D(Basis.from_scale(Vector3.ONE * scale) * pose, -base * scale)
	_add(node, _props)
	if dynamic:
		# Overrides on the nodes inside an instanced scene are only saved for
		# an editable instance.
		_root.set_editable_instance(node, true)
		for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			mesh.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	return node


## The imported scene of a model in the manifest and its bounding box.
func _model(id: String) -> Dictionary:
	if _models.is_empty():
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/manifest.json"))
		for asset: Dictionary in manifest.assets:
			if asset.type == "model":
				_models[asset.id] = {"path": "res://assets/models/%s/%s_%s.gltf" % [asset.id, asset.id, asset.resolution]}
	var info: Dictionary = _models[id]
	if not info.has("scene"):
		info.scene = load(info.path)
		var node: Node3D = info.scene.instantiate()
		var boxes: Array[AABB] = []
		for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			# The node is not in a tree, so walk up to the root by hand.
			var xf := Transform3D()
			var at: Node3D = mesh
			while at != node:
				xf = at.transform * xf
				at = at.get_parent()
			boxes.append(xf * mesh.get_aabb())
		info.box = boxes.reduce(func(sum: AABB, box: AABB) -> AABB: return sum.merge(box))
		node.free()
	return info


## Dirt projected onto a wall whose surface normal is `normal`; `at` is the
## centre of the patch on the wall. The top of the texture points up.
func wall_decal(texture: String, at: Vector3, normal: Vector3, width: float, height: float, tint := Color.WHITE, depth := 0.5) -> void:
	var basis := Basis(normal.cross(Vector3.DOWN), normal, Vector3.DOWN)
	_decal(texture, Transform3D(basis, at), Vector3(width, depth, height), tint)


## Stencilled lettering `height` high on a surface whose normal is `normal`,
## centred on `at`. The text has to be in the manifest as a decal of kind
## "text"; `reach` is how far the paint carries in front of and behind `at`,
## for a surface that is not flat.
func label(text: String, at: Vector3, normal: Vector3, height: float, ink := Color(0.86, 0.86, 0.82), reach := 0.08) -> void:
	var texture := _lettering(text)
	wall_decal(texture, at, normal, height * _lettering_aspect(texture), height, ink, reach * 2.0)


## The decal that holds a text, and how many times wider than high it is.
func _lettering(text: String) -> String:
	return "text_" + text.to_lower().replace(" ", "_")


func _lettering_aspect(texture: String) -> float:
	var size: Vector2 = (load("res://assets/decals/%s.png" % texture) as Texture2D).get_size()
	return size.x / size.y


## Stain projected onto the floor around `at`.
func floor_decal(texture: String, at: Vector3, size: Vector2, yaw_deg := 0.0, tint := Color.WHITE) -> void:
	_decal(texture, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at), Vector3(size.x, 0.3, size.y), tint)


## One of the numbered variants of a decal, e.g. "leak" gives leak_1 or leak_2.
func _pick(kind: String) -> String:
	return "%s_%d" % [kind, _decal_rng.randi_range(1, 2)]


func _decal(texture: String, xf: Transform3D, size: Vector3, tint: Color) -> void:
	var node := Decal.new()
	node.name = texture.capitalize().replace(" ", "")
	node.texture_albedo = load("res://assets/decals/%s.png" % texture)
	node.transform = xf
	node.size = size
	node.modulate = tint
	node.upper_fade = 0.05
	node.lower_fade = 0.05
	node.distance_fade_enabled = true
	node.distance_fade_begin = 35.0
	node.distance_fade_length = 10.0
	_add(node, _decals)


## Sets aside the part of the floor (x and z) that floor_line() and the others
## paint on. The level then gets a copy of the floor material that carries the
## paint, in scenes/levels/<name>_floor.res.
func floor_paint_area(area: Rect2) -> void:
	_paint_area = area
	_paint = Image.create_empty(ceili(area.size.x * PAINT_SCALE), ceili(area.size.y * PAINT_SCALE), false, Image.FORMAT_RGBA8)


## Painted line between two points on the floor (x and z), along X or along Z.
func floor_line(from: Vector2, to: Vector2, color := PAINT_YELLOW, width := 0.1) -> void:
	var half := Vector2(width, width) * 0.5
	_fill(Rect2(from.min(to) - half, (to - from).abs() + half * 2.0), color)


## Outline of a rectangle on the floor. With a second colour it becomes a
## border of diagonal stripes, as around a machine.
func floor_frame(area: Rect2, color := PAINT_YELLOW, width := 0.1, striped := Color(0, 0, 0, 0)) -> void:
	var stripe := width if striped.a > 0.0 else 0.0
	var across := Vector2(area.size.x, width)
	var down := Vector2(width, area.size.y)
	_fill(Rect2(area.position, across), color, stripe, striped)
	_fill(Rect2(area.position + Vector2(0, area.size.y - width), across), color, stripe, striped)
	_fill(Rect2(area.position, down), color, stripe, striped)
	_fill(Rect2(area.position + Vector2(area.size.x - width, 0), down), color, stripe, striped)


## Stencilled lettering `height` high on the floor, centred on `at` (x and z).
## It reads from the north; every quarter `turns` takes it a quarter round.
func floor_text(text: String, at: Vector2, height: float, color := PAINT_WHITE, turns := 0) -> void:
	# Read as a file: the builder runs without a renderer to hand textures back.
	var stencil := Image.load_from_file(ProjectSettings.globalize_path("res://assets/decals/%s.png" % _lettering(text)))
	var rows := roundi(height / 0.71 * PAINT_SCALE)
	stencil.resize(roundi(rows * stencil.get_width() / float(stencil.get_height())), rows, Image.INTERPOLATE_LANCZOS)
	# The image as it comes reads from the south.
	stencil.rotate_180()
	for i in posmod(turns, 4):
		stencil.rotate_90(CLOCKWISE)
	var corner := Vector2i(((at - _paint_area.position) * PAINT_SCALE).round()) - stencil.get_size() / 2
	for y in stencil.get_height():
		for x in stencil.get_width():
			var to := corner + Vector2i(x, y)
			var cover := stencil.get_pixel(x, y).a
			if Rect2i(Vector2i.ONE, _paint.get_size() - Vector2i(2, 2)).has_point(to) and cover > _paint.get_pixelv(to).a:
				_paint.set_pixelv(to, Color(color.r, color.g, color.b, cover))


## Diagonal stripes, `stripe` wide and as far apart, over a part of the floor
## that has to stay clear.
func floor_hatch(area: Rect2, color := PAINT_YELLOW, stripe := 0.15) -> void:
	_fill(area, color, stripe)


## Paints a rectangle of floor, solid or in diagonal stripes of `color` with
## `between` in the gaps.
func _fill(area: Rect2, color: Color, stripe := 0.0, between := Color(0, 0, 0, 0)) -> void:
	var from := (area.position - _paint_area.position) * PAINT_SCALE
	var to := (area.end - _paint_area.position) * PAINT_SCALE
	# The outermost pixels stay clear: the shader repeats them beyond the area.
	for y in range(maxi(floori(from.y), 1), mini(ceili(to.y), _paint.get_height() - 1)):
		for x in range(maxi(floori(from.x), 1), mini(ceili(to.x), _paint.get_width() - 1)):
			# How much of this pixel the rectangle covers.
			var cover := clampf(minf(x + 1.0, to.x) - maxf(x, from.x), 0.0, 1.0) * clampf(minf(y + 1.0, to.y) - maxf(y, from.y), 0.0, 1.0)
			var paint := color
			if stripe > 0.0:
				# How far this pixel lies inside a stripe, measured across them.
				var band := stripe * PAINT_SCALE
				var along := fposmod((x + y + 1.0) * 0.7071, band * 2.0)
				var inside := clampf(minf(along, band - along) + 0.5, 0.0, 1.0)
				if between.a > 0.0:
					paint = between.lerp(color, inside)
				else:
					cover *= inside
			if cover > _paint.get_pixel(x, y).a:
				_paint.set_pixel(x, y, Color(paint.r, paint.g, paint.b, cover))


# --- Geometry builders -------------------------------------------------------


func box(mat: String, center: Vector3, size: Vector3, rot_deg := Vector3.ZERO, flags := 0) -> void:
	_box(mat, Transform3D(Basis.from_euler(rot_deg * PI / 180.0), center), size, flags)


func _local_box(mat: String, frame: Transform3D, center: Vector3, size: Vector3, flags := 0) -> void:
	_box(mat, frame * Transform3D(Basis(), center), size, flags)


## Square-section member between two points.
func beam(mat: String, from: Vector3, to: Vector3, width: float, flags := 0, height := -1.0) -> void:
	var size := Vector3(width, width if height < 0.0 else height, from.distance_to(to))
	_box(mat, Transform3D(_along(to - from), (from + to) * 0.5), size, flags)


func _box(mat: String, xf: Transform3D, size: Vector3, flags: int) -> void:
	var st := _tool(mat, flags, xf.origin)
	var half := size * 0.5
	for n: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var up := Vector3.FORWARD if absf(n.y) > 0.5 else Vector3.UP
		var right := up.cross(n)
		var c := n * absf(n.dot(half))
		var r := right * absf(right.dot(half))
		var u := up * absf(up.dot(half))
		var corners: Array[Vector3] = [c - r - u, c + r - u, c + r + u, c - r + u]
		var normal := xf.basis * n
		var points: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for p in corners:
			# Unrotated offset keeps the texture continuous across abutting boxes.
			var q := p + xf.origin
			points.append(xf * p)
			uvs.append(Vector2(q.dot(right), -q.dot(up)))
		var face := Vector2(r.length(), u.length()) * 2.0
		_quad(st, points, [normal, normal, normal, normal], uvs,
			[_edge(Vector2(0, 0), face), _edge(Vector2(1, 0), face), _edge(Vector2(1, 1), face), _edge(Vector2(0, 1), face)])
	if not flags & NO_COLLIDE:
		_collide_box(xf, size)


## Box whose edges and corners are rounded off over `radius`, for anything
## cast or machined: the shading runs smoothly around every edge.
func rounded_box(mat: String, xf: Transform3D, size: Vector3, radius: float, flags := 0) -> void:
	var st := _tool(mat, flags, xf.origin)
	var half := size * 0.5
	var r := minf(radius, minf(half.x, minf(half.y, half.z)))
	var core := half - Vector3.ONE * r
	for n: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var up := Vector3.FORWARD if absf(n.y) > 0.5 else Vector3.UP
		var right := up.cross(n)
		var hr := absf(right.dot(half))
		var hu := absf(up.dot(half))
		# Three strips each way: the flat middle and half a rounded edge on
		# either side. The other half belongs to the neighbouring face.
		var across: Array[float] = [-hr, -hr + r, hr - r, hr]
		var along: Array[float] = [-hu, -hu + r, hu - r, hu]
		for i in 3:
			for j in 3:
				var points: Array[Vector3] = []
				var normals: Array[Vector3] = []
				var uvs: Array[Vector2] = []
				var edges: Array[Color] = []
				for corner: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
					var flat := n * absf(n.dot(half)) + right * across[corner.x] + up * along[corner.y]
					var inner := flat.clamp(-core, core)
					var normal := (flat - inner).normalized()
					var q := flat + xf.origin
					points.append(xf * (inner + normal * r))
					normals.append(xf.basis * normal)
					uvs.append(Vector2(q.dot(right), -q.dot(up)))
					# The middle of the rounding is where the edge of the box is.
					edges.append(_edge(Vector2(across[corner.x] / hr, along[corner.y] / hu) * 0.5 + Vector2(0.5, 0.5), Vector2(hr, hu) * 2.0))
				_quad(st, points, normals, uvs, edges)
	if not flags & NO_COLLIDE:
		_collide_box(xf, size)


## Pressed-steel panel standing in the XY plane of `xf` and facing its +Z:
## flat crests in that plane and flat troughs `depth` behind it, joined by
## slopes. The waves follow one another along X, `pitch` apart, and the panel
## starts and ends in a trough, so its edges tuck in behind a frame.
func corrugated(mat: String, xf: Transform3D, size: Vector2, pitch: float, depth: float, flags := 0) -> void:
	var st := _tool(mat, flags, xf.origin)
	var waves := maxi(1, roundi(size.x / pitch))
	var step := size.x / waves
	# One wave: half a trough, the slope up, the crest, the slope down, half a trough.
	var wave: Array[Vector2] = [Vector2(0, -depth), Vector2(0.15, -depth), Vector2(0.36, 0), Vector2(0.64, 0), Vector2(0.85, -depth), Vector2(1, -depth)]
	var half := size * 0.5
	var shift := xf.origin.x + xf.origin.z
	for w in waves:
		for i in wave.size() - 1:
			var a := Vector3(-half.x + (w + wave[i].x) * step, 0, wave[i].y)
			var b := Vector3(-half.x + (w + wave[i + 1].x) * step, 0, wave[i + 1].y)
			var normal := xf.basis * Vector3(a.z - b.z, 0, b.x - a.x).normalized()
			var up := Vector3(0, half.y, 0)
			# Only the two bends at the crest stick out, and those are rounded.
			var across := _stretch(a.distance_to(b), i == 2 or i == 3, i == 1 or i == 2, 0.01)
			var left := _edge(Vector2(across.x, 0.5), Vector2(across.z, 256.0))
			var right := _edge(Vector2(across.y, 0.5), Vector2(across.z, 256.0))
			_quad(
				st,
				[xf * (a - up), xf * (b - up), xf * (b + up), xf * (a + up)],
				[normal, normal, normal, normal],
				[Vector2(a.x + shift, half.y - xf.origin.y), Vector2(b.x + shift, half.y - xf.origin.y), Vector2(b.x + shift, -half.y - xf.origin.y), Vector2(a.x + shift, -half.y - xf.origin.y)],
				[left, right, right, left]
			)
	if not flags & NO_COLLIDE:
		_collide_box(xf * Transform3D(Basis(), Vector3(0, 0, -depth * 0.5)), Vector3(size.x, size.y, depth))


## Cylinder or cone standing on `base`; rot_deg tilts its axis.
func cylinder(mat: String, base: Vector3, radius: float, height: float, flags := 0, rot_deg := Vector3.ZERO, top_radius := -1.0, segments := 20) -> void:
	_cylinder(mat, Transform3D(Basis.from_euler(rot_deg * PI / 180.0), base), radius, height, flags, top_radius, segments)


## Round bar between two points.
func rod(mat: String, from: Vector3, to: Vector3, radius: float, flags := 0, segments := 12) -> void:
	_cylinder(mat, Transform3D(_up_along(to - from), from), radius, from.distance_to(to), flags, -1.0, segments)


func _cylinder(mat: String, xf: Transform3D, radius: float, height: float, flags: int, top_radius: float, segments: int) -> void:
	var st := _tool(mat, flags, xf * Vector3(0, height * 0.5, 0))
	var r_top := radius if top_radius < 0.0 else top_radius
	var top := Vector3(0, height, 0)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		# Counter-clockwise seen from outside means going towards -angle around +Y.
		var d0 := Vector3(cos(a1), 0, sin(a1))
		var d1 := Vector3(cos(a0), 0, sin(a0))
		var u0 := -a1 * radius
		var u1 := -a0 * radius
		# The rims are the only edges: across the wall, and around either end.
		var foot := _edge(Vector2(0.5, 0), Vector2(256.0, height))
		var head := _edge(Vector2(0.5, 1), Vector2(256.0, height))
		_quad(
			st,
			[xf * (d0 * radius), xf * (d1 * radius), xf * (d1 * r_top + top), xf * (d0 * r_top + top)],
			[xf.basis * d0, xf.basis * d1, xf.basis * d1, xf.basis * d0],
			[Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, -height), Vector2(u0, -height)],
			[foot, foot, head, head]
		)
		var up := xf.basis * Vector3.UP
		var rim := _edge(Vector2(0.5, 1), Vector2(256.0, r_top * 2.0))
		_tri(st, [xf * top, xf * (d0 * r_top + top), xf * (d1 * r_top + top)], [up, up, up],
			[Vector2.ZERO, Vector2(d0.x, d0.z) * r_top, Vector2(d1.x, d1.z) * r_top], [NO_EDGE, rim, rim])
		rim = _edge(Vector2(0.5, 1), Vector2(256.0, radius * 2.0))
		_tri(st, [xf * Vector3.ZERO, xf * (d1 * radius), xf * (d0 * radius)], [-up, -up, -up],
			[Vector2.ZERO, Vector2(d1.x, d1.z) * radius, Vector2(d0.x, d0.z) * radius], [NO_EDGE, rim, rim])
	if not flags & NO_COLLIDE:
		_collide_cylinder(xf * Transform3D(Basis(), top * 0.5), maxf(radius, r_top), height)


## Surface of revolution around the Y axis of `xf`. `profile` lists (radius,
## height) pairs from the bottom up; starting or ending at radius 0 closes that
## end. `smooth` rounds the profile off as well, for a torus or a dome.
func revolve(mat: String, xf: Transform3D, profile: PackedVector2Array, flags := 0, segments := 24, smooth := false) -> void:
	var st := _tool(mat, flags, xf.origin)
	var last := profile.size() - 2
	# Outward normal of every stretch of the profile, as (radial, height).
	var facets: Array[Vector2] = []
	for i in last + 1:
		var d := profile[i + 1] - profile[i]
		facets.append(Vector2(d.y, -d.x).normalized())
	# A corner of the profile that sticks out is an edge; one that goes in is not.
	var sharp: Array[bool] = [false]
	for i in range(1, last + 1):
		var before := profile[i] - profile[i - 1]
		var after := profile[i + 1] - profile[i]
		sharp.append(not smooth and before.cross(after) > 0.0001 * before.length() * after.length())
	sharp.append(false)
	var run := 0.0
	var widest := 0.0
	for i in last + 1:
		var p0 := profile[i]
		var p1 := profile[i + 1]
		var n0 := facets[i]
		var n1 := facets[i]
		if smooth:
			# A profile that ends where it began, like a ring, is smooth there too.
			var closed := profile[0].is_equal_approx(profile[last + 1])
			var before := (i + last) % (last + 1) if closed else maxi(i - 1, 0)
			var after := (i + 1) % (last + 1) if closed else mini(i + 1, last)
			n0 = (facets[before] + facets[i]).normalized()
			n1 = (facets[i] + facets[after]).normalized()
		var length := p0.distance_to(p1)
		var girth := maxf(p0.x, p1.x)
		widest = maxf(widest, girth)
		for s in segments:
			var a0 := TAU * s / segments
			var a1 := TAU * (s + 1) / segments
			# Same winding as the wall of a cylinder.
			var d0 := Vector3(cos(a1), 0, sin(a1))
			var d1 := Vector3(cos(a0), 0, sin(a0))
			var points := [
				xf * (d0 * p0.x + Vector3.UP * p0.y), xf * (d1 * p0.x + Vector3.UP * p0.y),
				xf * (d1 * p1.x + Vector3.UP * p1.y), xf * (d0 * p1.x + Vector3.UP * p1.y),
			]
			var normals := [
				xf.basis * (d0 * n0.x + Vector3.UP * n0.y), xf.basis * (d1 * n0.x + Vector3.UP * n0.y),
				xf.basis * (d1 * n1.x + Vector3.UP * n1.y), xf.basis * (d0 * n1.x + Vector3.UP * n1.y),
			]
			var uvs := [
				Vector2(-a1 * girth, -run), Vector2(-a0 * girth, -run),
				Vector2(-a0 * girth, -run - length), Vector2(-a1 * girth, -run - length),
			]
			if absf(p1.y - p0.y) < 0.0001:
				# A flat ring or lid is mapped straight on, not wound round the axis.
				uvs = [Vector2(d0.x, d0.z) * p0.x, Vector2(d1.x, d1.z) * p0.x, Vector2(d1.x, d1.z) * p1.x, Vector2(d0.x, d0.z) * p1.x]
			var along := _stretch(length, sharp[i], sharp[i + 1])
			var start := _edge(Vector2(0.5, along.x), Vector2(256.0, along.z))
			var end := _edge(Vector2(0.5, along.y), Vector2(256.0, along.z))
			# A stretch that starts or ends on the axis is a fan of triangles.
			if p0.x < 0.0001:
				_tri(st, [points[0], points[2], points[3]], [normals[0], normals[2], normals[3]], [uvs[0], uvs[2], uvs[3]], [start, end, end])
			elif p1.x < 0.0001:
				_tri(st, [points[0], points[1], points[2]], [normals[0], normals[1], normals[2]], [uvs[0], uvs[1], uvs[2]], [start, start, end])
			else:
				_quad(st, points, normals, uvs, [start, start, end, end])
		run += length
	if not flags & NO_COLLIDE:
		var bottom := profile[0].y
		var height := profile[last + 1].y - bottom
		_collide_cylinder(xf * Transform3D(Basis(), Vector3(0, bottom + height * 0.5, 0)), widest, height)


## Hose, cable or bent pipe through `points`, curving smoothly from one to the
## next. It has no collider and no end caps, so both ends belong inside something.
func hose(mat: String, points: PackedVector3Array, radius: float, flags := 0, segments := 8) -> void:
	var st := _tool(mat, flags, points[points.size() / 2])
	var steps := 6
	var path := PackedVector3Array()
	for i in points.size() - 1:
		var before := points[maxi(i - 1, 0)]
		var after := points[mini(i + 2, points.size() - 1)]
		for step in steps:
			path.append(points[i].cubic_interpolate(points[i + 1], before, after, float(step) / steps))
	path.append(points[points.size() - 1])
	# Carry one sideways direction along the path, turning it only as much as
	# the path itself turns, so the rings do not twist against each other.
	var heading := (path[1] - path[0]).normalized()
	var side := _up_along(heading).x
	var ring: Array[Vector3] = []
	var run := 0.0
	for i in path.size():
		var next := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		if not next.is_equal_approx(heading):
			side = Quaternion(heading, next) * side
			heading = next
		var around: Array[Vector3] = []
		for s in segments + 1:
			around.append(Basis(heading, TAU * s / segments) * side)
		if i > 0:
			var length := path[i].distance_to(path[i - 1])
			for s in segments:
				# Seen from outside with the path running upwards, s + 1 lies to the right of s.
				var u0 := s * TAU * radius / segments
				var u1 := (s + 1) * TAU * radius / segments
				_quad(
					st,
					[path[i - 1] + ring[s] * radius, path[i - 1] + ring[s + 1] * radius, path[i] + around[s + 1] * radius, path[i] + around[s] * radius],
					[ring[s], ring[s + 1], around[s + 1], around[s]],
					[Vector2(u0, -run), Vector2(u1, -run), Vector2(u1, -run - length), Vector2(u0, -run - length)]
				)
			run += length
		ring = around


## Convex polygon (counter-clockwise in local XY) extruded along local Z.
func extrude(mat: String, polygon: PackedVector2Array, depth: float, xf: Transform3D, flags := 0) -> void:
	var st := _tool(mat, flags, xf.origin)
	var front := Vector3(0, 0, depth * 0.5)
	var count := polygon.size()
	var hull := PackedVector3Array()
	for i in count:
		var a := polygon[i]
		var b := polygon[(i + 1) % count]
		var a3 := Vector3(a.x, a.y, 0)
		var b3 := Vector3(b.x, b.y, 0)
		hull.append(xf * (a3 + front))
		hull.append(xf * (a3 - front))
		var n := xf.basis * Vector3(b.y - a.y, a.x - b.x, 0).normalized()
		var run := a.distance_to(b)
		var side := Vector2(run, depth)
		_quad(st, [xf * (a3 - front), xf * (b3 - front), xf * (b3 + front), xf * (a3 + front)], [n, n, n, n],
			[Vector2(0, depth), Vector2(run, depth), Vector2(run, 0), Vector2(0, 0)],
			[_edge(Vector2(0, 0), side), _edge(Vector2(1, 0), side), _edge(Vector2(1, 1), side), _edge(Vector2(0, 1), side)])
		if i >= 2:
			var o := polygon[0]
			var o3 := Vector3(o.x, o.y, 0)
			var p := polygon[i - 1]
			var p3 := Vector3(p.x, p.y, 0)
			var nf := xf.basis * Vector3.BACK
			_tri(st, [xf * (o3 + front), xf * (p3 + front), xf * (a3 + front)], [nf, nf, nf],
				[Vector2(o.x, -o.y), Vector2(p.x, -p.y), Vector2(a.x, -a.y)])
			_tri(st, [xf * (o3 - front), xf * (a3 - front), xf * (p3 - front)], [-nf, -nf, -nf],
				[Vector2(-o.x, -o.y), Vector2(-a.x, -a.y), Vector2(-p.x, -p.y)])
	if not flags & NO_COLLIDE:
		var shape := ConvexPolygonShape3D.new()
		shape.points = hull
		_collide(shape, Transform3D())


## Plate cut to `outline` (counter-clockwise in the local XY of `xf`, hollows
## allowed) and `thickness` thick along local Z, with both rims rounded off
## over `bevel`. A corner of the outline of more than 40 degrees stays a
## corner; anything gentler shades as a curve.
func slab(mat: String, xf: Transform3D, outline: PackedVector2Array, thickness: float, bevel := 0.0, flags := 0) -> void:
	var st := _tool(mat, flags, xf.origin)
	var count := outline.size()
	var half := thickness * 0.5
	var b := minf(bevel, half)
	# Outward normal of every side, and of every corner: one for the side that
	# arrives there and one for the side that leaves, the same if it is gentle.
	var sides: Array[Vector2] = []
	for i in count:
		var d := outline[(i + 1) % count] - outline[i]
		sides.append(Vector2(d.y, -d.x).normalized())
	var arriving: Array[Vector2] = []
	var leaving: Array[Vector2] = []
	var sharp: Array[bool] = []
	var inset := PackedVector2Array()
	for i in count:
		var before := sides[(i + count - 1) % count]
		var after := sides[i]
		var gentle := before.dot(after) > 0.766
		var mean := (before + after).normalized()
		arriving.append(mean if gentle else before)
		leaving.append(mean if gentle else after)
		# Only a corner that sticks out is an edge to wear.
		sharp.append(not gentle and before.cross(after) > 0.0)
		# The rim of the faces lies `bevel` inside both sides that meet here.
		var miter := (before + after) / maxf(1.0 + before.dot(after), 0.35)
		inset.append(outline[i] - miter * b)
	var across := _stretch(thickness - b * 2.0, true, true, b * 0.5)
	var rim := _edge(Vector2(0.5, across.x), Vector2(256.0, across.z))
	var front := Vector3(0, 0, half)
	var wall := Vector3(0, 0, half - b)
	var run := 0.0
	for i in count:
		var j := (i + 1) % count
		var a := Vector3(outline[i].x, outline[i].y, 0)
		var c := Vector3(outline[j].x, outline[j].y, 0)
		var na := xf.basis * Vector3(leaving[i].x, leaving[i].y, 0)
		var nc := xf.basis * Vector3(arriving[j].x, arriving[j].y, 0)
		var length := outline[i].distance_to(outline[j])
		var along := _stretch(length, sharp[i], sharp[j])
		var size := Vector2(along.z, across.z)
		_quad(st, [xf * (a - wall), xf * (c - wall), xf * (c + wall), xf * (a + wall)], [na, nc, nc, na],
			[Vector2(run, half), Vector2(run + length, half), Vector2(run + length, -half), Vector2(run, -half)],
			[_edge(Vector2(along.x, across.x), size), _edge(Vector2(along.y, across.x), size), _edge(Vector2(along.y, across.y), size), _edge(Vector2(along.x, across.y), size)])
		if b > 0.0:
			var ai := Vector3(inset[i].x, inset[i].y, 0)
			var ci := Vector3(inset[j].x, inset[j].y, 0)
			var out := xf.basis * Vector3.BACK
			_quad(st, [xf * (a + wall), xf * (c + wall), xf * (ci + front), xf * (ai + front)], [na, nc, out, out],
				[Vector2(run, -half), Vector2(run + length, -half), Vector2(run + length, -half - b), Vector2(run, -half - b)], [rim, rim, rim, rim])
			_quad(st, [xf * (c - wall), xf * (a - wall), xf * (ai - front), xf * (ci - front)], [nc, na, -out, -out],
				[Vector2(run + length, half), Vector2(run, half), Vector2(run, half + b), Vector2(run + length, half + b)], [rim, rim, rim, rim])
		run += length
	var face := inset if b > 0.0 else outline
	var corners := Geometry2D.triangulate_polygon(face)
	if corners.is_empty():
		# The rim has crossed itself where the outline is narrower than two
		# bevels. The outline itself has the same corners in the same order.
		corners = Geometry2D.triangulate_polygon(outline)
	if corners.is_empty():
		push_error("slab: outline cannot be triangulated (does it cross itself?)")
	var shift := Vector2(xf.origin.x + xf.origin.z, -xf.origin.y)
	for t in range(0, corners.size(), 3):
		var p: Array[Vector2] = [face[corners[t]], face[corners[t + 1]], face[corners[t + 2]]]
		if (p[1] - p[0]).cross(p[2] - p[0]) < 0.0:
			p.reverse()
		var n := xf.basis * Vector3.BACK
		_tri(st, [xf * (Vector3(p[0].x, p[0].y, half)), xf * (Vector3(p[1].x, p[1].y, half)), xf * (Vector3(p[2].x, p[2].y, half))], [n, n, n],
			[Vector2(p[0].x, -p[0].y) + shift, Vector2(p[1].x, -p[1].y) + shift, Vector2(p[2].x, -p[2].y) + shift])
		_tri(st, [xf * (Vector3(p[0].x, p[0].y, -half)), xf * (Vector3(p[2].x, p[2].y, -half)), xf * (Vector3(p[1].x, p[1].y, -half))], [-n, -n, -n],
			[Vector2(-p[0].x, -p[0].y) + shift, Vector2(-p[2].x, -p[2].y) + shift, Vector2(-p[1].x, -p[1].y) + shift])
	if not flags & NO_COLLIDE:
		var hull := PackedVector3Array()
		for corner in outline:
			hull.append(xf * Vector3(corner.x, corner.y, half))
			hull.append(xf * Vector3(corner.x, corner.y, -half))
		var shape := ConvexPolygonShape3D.new()
		shape.points = hull
		_collide(shape, Transform3D())


# --- Part helpers --------------------------------------------------------------
# Shorthands for building a machine or a model out of many small parts: they
# work in the frame `_m` and build with the flags in `_part`.


## Cast or machined block with rounded edges.
func _block(mat: String, center: Vector3, size: Vector3, radius := 0.02, rot_deg := Vector3.ZERO) -> void:
	rounded_box(mat, _m * Transform3D(Basis.from_euler(rot_deg * PI / 180.0), center), size, radius, _part)


## Plate or section with square edges.
func _plate(mat: String, center: Vector3, size: Vector3) -> void:
	_local_box(mat, _m, center, size, _part)


func _bar(mat: String, from: Vector3, to: Vector3, radius: float, segments := 12) -> void:
	rod(mat, _m * from, _m * to, radius, _part, segments)


## Turned part: `profile` revolved around the line that leaves `from` along `axis`.
func _turned(mat: String, from: Vector3, axis: Vector3, profile: PackedVector2Array, segments := 24, smooth := false) -> void:
	revolve(mat, _m * Transform3D(_up_along(axis), from), profile, _part, segments, smooth)


## Pipe, conduit or cable.
func _line(mat: String, points: Array, radius: float, segments := 8) -> void:
	hose(mat, _m * PackedVector3Array(points), radius, _part, segments)


func _ring(mat: String, center: Vector3, axis: Vector3, radius: float, thickness: float) -> void:
	var profile := PackedVector2Array()
	for i in 9:
		var angle := TAU * i / 8
		profile.append(Vector2(radius + cos(angle) * thickness, sin(angle) * thickness))
	_turned(mat, center, axis, profile, 20, true)


func _ball(mat: String, center: Vector3, radius: float) -> void:
	var profile := PackedVector2Array()
	for i in 7:
		var angle := PI * (i / 6.0 - 0.5)
		profile.append(Vector2(cos(angle), sin(angle)) * radius)
	_turned(mat, center, Vector3.UP, profile, 12, true)


## Corners are bottom-left, bottom-right, top-right, top-left seen from outside.
## `edge` holds what _edge() gives for each corner, if the face has edges.
func _quad(st: SurfaceTool, p: Array, n: Array, uv: Array, edge: Array = []) -> void:
	if edge.is_empty():
		_tri(st, [p[0], p[1], p[2]], [n[0], n[1], n[2]], [uv[0], uv[1], uv[2]])
		_tri(st, [p[0], p[2], p[3]], [n[0], n[2], n[3]], [uv[0], uv[2], uv[3]])
	else:
		_tri(st, [p[0], p[1], p[2]], [n[0], n[1], n[2]], [uv[0], uv[1], uv[2]], [edge[0], edge[1], edge[2]])
		_tri(st, [p[0], p[2], p[3]], [n[0], n[2], n[3]], [uv[0], uv[2], uv[3]], [edge[0], edge[2], edge[3]])


## Takes counter-clockwise corners and emits Godot's clockwise winding.
func _tri(st: SurfaceTool, p: Array, n: Array, uv: Array, edge: Array = []) -> void:
	for i: int in [0, 2, 1]:
		st.set_color(NO_EDGE if edge.is_empty() else edge[i])
		st.set_normal(n[i])
		st.set_uv(uv[i])
		st.add_vertex(p[i])


## Vertex colour that tells a shader where a point lies between the edges of
## its face, so that it can wear a surface along them: `at` runs from 0 to 1
## across a face that measures `size` metres. The distance to the nearest edge
## is then min(at, 1 - at) * size, whichever axis gives least. _stretch() says
## what to pass for a side of which only one end is an edge, or neither.
func _edge(at: Vector2, size: Vector2) -> Color:
	return Color(at.x, at.y, _span(size.x), _span(size.y))


## A length between 4 mm and 256 m on a logarithmic scale from 0 to 1: a
## vertex colour has eight bits per channel, and this keeps the error at 2%.
func _span(length: float) -> float:
	return clampf((log(maxf(length, 0.001)) / log(2.0) + 8.0) / 16.0, 0.0, 1.0)


## One side of a face for _edge(): where it starts and ends between 0 and 1
## (x and y) and the size to go with that (z), given which of its two ends is
## an edge. A rounded edge is `blunt`: it counts as lying that many metres
## further away, so it wears less than a sharp one.
func _stretch(length: float, from_edge: bool, to_edge: bool, blunt := 0.0) -> Vector3:
	if not from_edge and not to_edge:
		return Vector3(0.5, 0.5, 256.0)
	var size := (length if from_edge and to_edge else length * 2.0) + blunt * 2.0
	var near := blunt / size
	return Vector3(near if from_edge else 0.5, 1.0 - near if to_edge else 0.5, size)


func _along(direction: Vector3) -> Basis:
	var up := Vector3.RIGHT if absf(direction.normalized().y) > 0.99 else Vector3.UP
	return Basis.looking_at(direction, up)


## Basis whose Y axis points along `direction`.
func _up_along(direction: Vector3) -> Basis:
	var y := direction.normalized()
	var x := (Vector3.FORWARD if absf(y.y) > 0.99 else Vector3.UP).cross(y).normalized()
	return Basis(x, y, x.cross(y))


## The surface a piece of geometry at `at` goes into.
func _tool(mat: String, flags: int, at: Vector3) -> SurfaceTool:
	var kind := "glass" if flags & GLASS else ("detail" if flags & DETAIL else "static")
	if kind == "detail":
		# A mesh without a lightmap takes its indirect light from the probes at
		# one point, its middle. Detail is therefore cut into blocks, so that
		# what hangs under the roof is not lit like what stands by a window.
		if not _detail_inside.has_volume():
			pass
		elif _detail_inside.has_point(at):
			# What sits in or on a wall belongs to the block on the inside of it.
			at = at.clamp(_detail_inside.position + Vector3.ONE, _detail_inside.end - Vector3.ONE)
		else:
			return _tool_named("detail far/" + mat)
		var block := Vector3i((at / _detail_block + Vector3(0.5, 0, 0)).floor())
		kind = "detail %d %d %d" % [block.x, block.y, block.z]
	return _tool_named(kind + "/" + mat)


func _tool_named(key: String) -> SurfaceTool:
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = st
	return _tools[key]


## The material of that name. A level with paint on its floor gets its own
## copy of the floor material, which shows the paint.
func _material(mat: String) -> Material:
	var material: Material = load("res://materials/%s.tres" % mat)
	if mat != "floor" or _paint == null:
		return material
	if _painted_floor == null:
		_paint.generate_mipmaps()
		_painted_floor = material.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
		_painted_floor.set_shader_parameter("markings", ImageTexture.create_from_image(_paint))
		_painted_floor.set_shader_parameter("markings_rect", Vector4(_paint_area.position.x, _paint_area.position.y, 1.0 / _paint_area.size.x, 1.0 / _paint_area.size.y))
		var path := "%s%s_floor.res" % [OUT_DIR, _level_name()]
		ResourceSaver.save(_painted_floor, path, ResourceSaver.FLAG_COMPRESS)
		_painted_floor.take_over_path(path)
	return _painted_floor


func _collide_box(xf: Transform3D, size: Vector3) -> void:
	var key := "box %s" % size.snappedf(0.001)
	if not _shapes.has(key):
		var shape := BoxShape3D.new()
		shape.size = size
		_shapes[key] = shape
	_collide(_shapes[key], xf)


func _collide_cylinder(xf: Transform3D, radius: float, height: float) -> void:
	var key := "cyl %s %s" % [snappedf(radius, 0.001), snappedf(height, 0.001)]
	if not _shapes.has(key):
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		_shapes[key] = shape
	_collide(_shapes[key], xf)


func _collide(shape: Shape3D, xf: Transform3D) -> void:
	var node := CollisionShape3D.new()
	node.shape = shape
	node.transform = xf
	_add(node, _body)


func _add(node: Node, parent: Node) -> void:
	parent.add_child(node, true)
	if node != _root:
		node.owner = _root


## Merges every surface of one kind into a single mesh instance, saved under
## `stem`.
func _commit(kind: String, stem: String) -> void:
	var keys := _tools.keys().filter(func(key: String) -> bool: return key.begins_with(kind + "/"))
	keys.sort()
	var mesh := ArrayMesh.new()
	var triangles := 0
	for key: String in keys:
		var st: SurfaceTool = _tools[key]
		st.index()
		st.generate_tangents()
		st.set_material(_material(key.get_slice("/", 1)))
		st.commit(mesh)
		triangles += mesh.surface_get_array_index_len(mesh.get_surface_count() - 1) / 3
	if kind == "static":
		var err := mesh.lightmap_unwrap(Transform3D(), TEXEL)
		print("Lightmap unwrap: ", error_string(err), ", size hint ", mesh.lightmap_size_hint)
	var path := "%s%s_%s.res" % [OUT_DIR, _level_name(), stem]
	ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	mesh.take_over_path(path)
	var instance := MeshInstance3D.new()
	instance.name = stem.capitalize().replace(" ", "")
	instance.mesh = mesh
	match kind:
		"static":
			instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		"glass":
			instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_:
			instance.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	_add(instance, _root)
	_root.move_child(instance, 0)
	print("%s: %d surfaces, %d triangles" % [kind, mesh.get_surface_count(), triangles])
