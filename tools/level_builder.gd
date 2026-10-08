extends SceneTree
## Shared level generator; the levels themselves live in tools/levels/ and are
## built with tools/build_level.sh <name>.
##
## A level is described in code by overriding _describe() and written to
## scenes/levels/ as merged meshes (lightmapped "static", probe-lit "detail"
## and unshadowed "glass"), one static body, the props placed from
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

var _tools := {}
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
var _rng := RandomNumberGenerator.new()
## Separate streams, so adding glass, decals or model variation never
## reshuffles where the props stand.
var _glass_rng := RandomNumberGenerator.new()
var _decal_rng := RandomNumberGenerator.new()
var _prop_rng := RandomNumberGenerator.new()
var _clutter_rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 7
	_glass_rng.seed = 11
	_decal_rng.seed = 23
	_prop_rng.seed = 31
	_clutter_rng.seed = 43
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

	_commit("static")
	_commit("detail")
	_commit("glass")
	var scene := PackedScene.new()
	scene.pack(_root)
	var err := ResourceSaver.save(scene, OUT_DIR + _level_name() + "_level.tscn")
	print("Saved level: ", error_string(err))
	quit()


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
func railing(from: Vector3, to: Vector3) -> void:
	var flags := DETAIL | NO_COLLIDE
	var up := Vector3(0, 1.05, 0)
	beam("steel_yellow", from + up, to + up, 0.05, flags)
	beam("steel_yellow", from + up * 0.5, to + up * 0.5, 0.035, flags)
	var posts := maxi(1, roundi(Vector2(to.x - from.x, to.z - from.z).length() / 1.5))
	for i in posts + 1:
		var p := from.lerp(to, float(i) / posts)
		box("steel_yellow", p + up * 0.5, Vector3(0.05, 1.05, 0.05), Vector3.ZERO, flags)
	var mid := (from + to) * 0.5 + up * 0.5
	var length := from.distance_to(to)
	_collide_box(Transform3D(_along(to - from), mid), Vector3(0.06, 1.05 + absf(to.y - from.y) * 0.0, length))


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


## Shipping container with ribbed sides; `along_x` is the direction of its length.
func container(mat: String, at: Vector3, along_x: bool, flags := 0) -> void:
	var xf := Transform3D(Basis() if along_x else Basis(Vector3.UP, PI * 0.5), at + Vector3(0, 1.3, 0))
	var length := 6.0
	var width := 2.4
	var height := 2.6
	_box(mat, xf, Vector3(length - 0.1, height - 0.2, width - 0.1), flags)
	var trim := flags | NO_COLLIDE
	for y: float in [-height * 0.5 + 0.08, height * 0.5 - 0.08]:
		_local_box(mat, xf, Vector3(0, y, 0), Vector3(length, 0.16, width), trim)
	for x: float in [-length * 0.5 + 0.06, length * 0.5 - 0.06]:
		for z: float in [-width * 0.5 + 0.06, width * 0.5 - 0.06]:
			_local_box(mat, xf, Vector3(x, 0, z), Vector3(0.12, height, 0.12), trim)
	var ribs := 19
	for i in ribs:
		var x := -length * 0.5 + length * (i + 1) / (ribs + 1)
		_local_box(mat, xf, Vector3(x, 0, 0), Vector3(0.1, height - 0.3, width - 0.02), trim)
	# Door bars on one end.
	for z: float in [-0.75, -0.25, 0.25, 0.75]:
		_local_box("steel", xf, Vector3(length * 0.5 - 0.03, 0, z), Vector3(0.05, height - 0.3, 0.04), trim)
	_local_box(mat, xf, Vector3(length * 0.5 - 0.04, 0, 0), Vector3(0.04, height - 0.3, 0.04), trim)


func pallet(at: Vector3, yaw: float, stack: int) -> void:
	for i in stack:
		var rot := Vector3(0, yaw + _rng.randf_range(-4, 4), 0)
		var base := at + Vector3(0, i * 0.15, 0)
		box("wood", base + Vector3(0, 0.125, 0), Vector3(1.2, 0.03, 1.0), rot, NO_COLLIDE if i > 0 else 0)
		box("wood", base + Vector3(0, 0.055, 0), Vector3(1.2, 0.11, 0.8), rot, NO_COLLIDE)
	_collide_box(Transform3D(Basis(), at + Vector3(0, stack * 0.075, 0)), Vector3(1.2, stack * 0.15, 1.0))


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
	light.light_color = Color(1.0, 0.74, 0.46)
	light.light_energy = 26.0
	light.light_volumetric_fog_energy = 1.6
	light.spot_range = 11.0
	light.spot_angle = 52.0
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


## Fluorescent ceiling fixture.
func tube(at: Vector3, along_x: bool, on: bool, shadows := true) -> void:
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
	light.omni_range = 7.5
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
func wall_decal(texture: String, at: Vector3, normal: Vector3, width: float, height: float, tint := Color.WHITE) -> void:
	var basis := Basis(normal.cross(Vector3.DOWN), normal, Vector3.DOWN)
	_decal(texture, Transform3D(basis, at), Vector3(width, 0.5, height), tint)


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
	var st := _tool(mat, flags)
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
		_quad(st, points, [normal, normal, normal, normal], uvs)
	if not flags & NO_COLLIDE:
		_collide_box(xf, size)


## Cylinder or cone standing on `base`; rot_deg tilts its axis.
func cylinder(mat: String, base: Vector3, radius: float, height: float, flags := 0, rot_deg := Vector3.ZERO, top_radius := -1.0, segments := 20) -> void:
	var st := _tool(mat, flags)
	var xf := Transform3D(Basis.from_euler(rot_deg * PI / 180.0), base)
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
		_quad(
			st,
			[xf * (d0 * radius), xf * (d1 * radius), xf * (d1 * r_top + top), xf * (d0 * r_top + top)],
			[xf.basis * d0, xf.basis * d1, xf.basis * d1, xf.basis * d0],
			[Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, -height), Vector2(u0, -height)]
		)
		var up := xf.basis * Vector3.UP
		_tri(st, [xf * top, xf * (d0 * r_top + top), xf * (d1 * r_top + top)], [up, up, up],
			[Vector2.ZERO, Vector2(d0.x, d0.z) * r_top, Vector2(d1.x, d1.z) * r_top])
		_tri(st, [xf * Vector3.ZERO, xf * (d1 * radius), xf * (d0 * radius)], [-up, -up, -up],
			[Vector2.ZERO, Vector2(d1.x, d1.z) * radius, Vector2(d0.x, d0.z) * radius])
	if not flags & NO_COLLIDE:
		_collide_cylinder(xf * Transform3D(Basis(), top * 0.5), maxf(radius, r_top), height)


## Convex polygon (counter-clockwise in local XY) extruded along local Z.
func extrude(mat: String, polygon: PackedVector2Array, depth: float, xf: Transform3D, flags := 0) -> void:
	var st := _tool(mat, flags)
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
		_quad(st, [xf * (a3 - front), xf * (b3 - front), xf * (b3 + front), xf * (a3 + front)], [n, n, n, n],
			[Vector2(0, depth), Vector2(run, depth), Vector2(run, 0), Vector2(0, 0)])
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


## Corners are bottom-left, bottom-right, top-right, top-left seen from outside.
func _quad(st: SurfaceTool, p: Array, n: Array, uv: Array) -> void:
	_tri(st, [p[0], p[1], p[2]], [n[0], n[1], n[2]], [uv[0], uv[1], uv[2]])
	_tri(st, [p[0], p[2], p[3]], [n[0], n[2], n[3]], [uv[0], uv[2], uv[3]])


## Takes counter-clockwise corners and emits Godot's clockwise winding.
func _tri(st: SurfaceTool, p: Array, n: Array, uv: Array) -> void:
	for i: int in [0, 2, 1]:
		st.set_normal(n[i])
		st.set_uv(uv[i])
		st.add_vertex(p[i])


func _along(direction: Vector3) -> Basis:
	var up := Vector3.RIGHT if absf(direction.normalized().y) > 0.99 else Vector3.UP
	return Basis.looking_at(direction, up)


func _tool(mat: String, flags: int) -> SurfaceTool:
	var kind := "glass/" if flags & GLASS else ("detail/" if flags & DETAIL else "static/")
	var key := kind + mat
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = st
	return _tools[key]


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


## Merges every surface of one kind into a single mesh instance.
func _commit(kind: String) -> void:
	var keys := _tools.keys().filter(func(key: String) -> bool: return key.begins_with(kind + "/"))
	if keys.is_empty():
		return
	keys.sort()
	var mesh := ArrayMesh.new()
	var triangles := 0
	for key: String in keys:
		var st: SurfaceTool = _tools[key]
		st.index()
		st.generate_tangents()
		st.set_material(load("res://materials/%s.tres" % key.get_slice("/", 1)))
		st.commit(mesh)
		triangles += mesh.surface_get_array_index_len(mesh.get_surface_count() - 1) / 3
	if kind == "static":
		var err := mesh.lightmap_unwrap(Transform3D(), TEXEL)
		print("Lightmap unwrap: ", error_string(err), ", size hint ", mesh.lightmap_size_hint)
	var path := "%s%s_%s.res" % [OUT_DIR, _level_name(), kind]
	ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	mesh.take_over_path(path)
	var instance := MeshInstance3D.new()
	instance.name = kind.capitalize()
	instance.mesh = mesh
	match kind:
		"static":
			instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		"detail":
			instance.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		"glass":
			instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(instance, _root)
	_root.move_child(instance, 0)
	print("%s: %d surfaces, %d triangles" % [kind, mesh.get_surface_count(), triangles])
