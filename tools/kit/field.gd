extends "res://tools/kit/land.gd"
## Tenth drawer of the kit, see tools/kit.gd: what an army leaves standing in
## the field. Walls of sandbags, tents and nets, wire, a barrier and its
## sentry box, a pillbox, and the vehicles it came in. All of it stands on
## the ground as it lies (see tools/kit/land.gd): a spot is given as x and z,
## and its height is asked.
##
## Nothing here has a lightmap: it stands under an open sky, lit by the sun
## and the sky as it is. What is cloth, a tent or a net, keeps the sun off
## the ground under it without being a collider, and says so with
## casts_shade(): somebody under it stands in the shade.

const CANVAS := "canvas"
const SACKING := "sandbag"
const ARMY := "army_green"
## A filled sandbag as it lies in a wall: along the wall, high, and deep.
const SACK := Vector3(0.6, 0.14, 0.3)
## Thin things that are in nobody's way.
const SLIGHT := DETAIL | NO_COLLIDE
## What the canvas shader is told of cloth that nothing has happened to: no
## dirt in it, not faded, hanging free and letting the sun through. See
## shaders/canvas.gdshader.
const CLOTH := Color(0.0, 0.5, 1.0, 1.0)
## What is left of the light of the sky in a tent and under a net: its
## colour by the time it has come through canvas or been thrown up by the
## sand, and how strong.
const TENT_LIGHT := Color(0.62, 0.6, 0.52, 0.4)
const NET_LIGHT := Color(0.82, 0.83, 0.8, 0.6)
## What moves in the wind: cloth that says in UV2 how far each of its
## corners gives, in metres, and how light it is: 0 for a wall of canvas that
## fills and sinks back, 1 for a shirt on a line. See shaders/canvas.gdshader.
const WINDBLOWN: Array[String] = ["canvas", "camo_net", "flag"]
## The way the wind blows over the land (x and z), as the grass and the
## canvas have it in their shaders.
const WIND := Vector2(0.12, 1.0)
## From how far off the small things are still drawn: ropes, pegs, strands
## of wire. See _trim().
const TRIM_REACH := 80.0
## The vehicles of tools/models/vehicles.gd: what of each is in the way, as
## [middle, size] of a box in the model, and over how many metres of ground
## it rests.
const VEHICLES := {
	"jeep": {"span": 1.2, "boxes": [[Vector3(0, 0.75, 0.05), Vector3(1.6, 1.0, 3.4)]]},
	"truck": {"span": 2.0, "boxes": [[Vector3(0, 1.3, -2.1), Vector3(2.2, 1.9, 2.5)], [Vector3(0, 1.75, 1.55), Vector3(2.4, 2.8, 4.0)]]},
	"tank": {"span": 2.4, "boxes": [[Vector3(0, 0.85, 0), Vector3(3.0, 1.5, 6.0)], [Vector3(0, 2.0, 0.1), Vector3(2.0, 0.85, 3.0)], [Vector3(0, 2.0, -3.3), Vector3(0.3, 0.3, 3.6)]]},
	"tank_b": {"span": 2.4, "boxes": [[Vector3(0, 0.85, 0), Vector3(3.0, 1.5, 6.0)], [Vector3(0, 2.0, 0.0), Vector3(2.6, 0.85, 2.8)]]},
	"motorcycle": {"span": 1.0, "boxes": [[Vector3(0, 0.62, -0.02), Vector3(0.62, 0.86, 2.15)], [Vector3(1.06, 0.62, -0.06), Vector3(0.7, 0.5, 1.72)]]},
}
## The sheet of what an army stencils on what it drives, as far as a level
## uses it: the ten figures in a row, and under them the letters a number
## begins with, by the kind of vehicle, and the stroke between its parts.
## Each as [where on the sheet it begins, how much of the sheet it takes].
## See _stencils() in tools/gen_foliage.gd.
const FIGURES := Rect2(0, 0.5, 0.1, 0.125)
const NUMBER_BEGINS := {"jeep": Rect2(0, 0.625, 0.25, 0.125), "truck": Rect2(0.25, 0.625, 0.25, 0.125), "tank": Rect2(0.5, 0.625, 0.25, 0.125), "tank_b": Rect2(0.5, 0.625, 0.25, 0.125), "motorcycle": Rect2(0, 0.625, 0.25, 0.125)}
const STROKE := Rect2(0.825, 0.625, 0.1, 0.125)
## How far the turret of each tank is traversed to its right, in degrees.
const TRAVERSE := {"tank": 0.0, "tank_b": 38.0}

## The node the vehicles of the level stand under, and how many there are.
var _vehicles: Node3D
var _vehicle_count := 0
## What a vehicle breaks or flattens as it drives into it, each a body of its
## own with a mesh of its own (scripts/barrier.gd, scripts/wire.gd): the node
## they stand under, them by name, and the one that is being built now, into
## which whatever is built goes, see _breakable_into().
const CRUSHABLE := &"crushable"
const BREAKABLE := 32
var _crushables: Node3D
var _owned := {}
var _owning: StaticBody3D
## The vehicle that can be driven whose number and load are being built, and
## whether what is built now is on its turret: it goes into a mesh of its own
## that moves with it, see _trim() and _commit().
var _riding: Node3D
var _on_turret := false
## How many shelter() there are, for their names.
var _shelters := 0
## How far before the glass of the level a shot stops, on the wall the glass
## sits in: the deepest reveal of its windows. The mesh of the glass says so
## to scripts/window.gd, see _commit().
var _glass_reveal := 0.0
## True while what is being built is one of the small things: it goes into
## the surface of _trim() whatever builds it. See _tool().
var _small := false


func _surface(mat: String) -> String:
	match mat:
		CANVAS, SACKING, "camo_net":
			return "soft"
	return super(mat)


# --- What it is all made with --------------------------------------------------------


## Dice of its own for the piece that stands at `at`: what is added to a
## piece later rolls these, and leaves where everything else stands alone.
func _dice(at: Vector2, salt := 0) -> RandomNumberGenerator:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash("%.2f/%.2f/%d" % [at.x, at.y, salt])
	return dice


## The surface that small things of `mat` near `at` go into: a rope, a
## strand of wire, a toggle. They throw no shadow and are not drawn from
## further off than TRIM_REACH, see _commit().
func _trim(mat: String, at: Vector3) -> SurfaceTool:
	if _owning:
		return _still(_tool_named("|own %s/%s" % [_owning.name, mat]), mat)
	if _riding:
		return _still(_tool_named("|vehicle %s%s/%s" % [_riding.name, " turret" if _on_turret else "", mat]), mat)
	@warning_ignore("integer_division")
	return _still(_tool_named("|trim %d %d/%s" % [int(at.x) / GROUND_BLOCK, int(at.z) / GROUND_BLOCK, mat]), mat)


## Cloth says of every corner how it gives in the wind, in UV2: see _cloth().
## A surface of cloth has that from its first corner on, and whatever is
## built into it stands still unless it says otherwise.
func _still(st: SurfaceTool, mat: String) -> SurfaceTool:
	if mat in WINDBLOWN:
		st.set_uv2(Vector2.ZERO)
	return st


## Something small that is in nobody's way goes with the small things, as
## long as _small says so: a mug, a peg, a helmet.
func _tool(mat: String, flags: int, at: Vector3) -> SurfaceTool:
	if _owning:
		return _trim(mat, at)
	if _small and flags & DETAIL and flags & NO_COLLIDE and not _moving:
		return _trim(mat, at)
	return _still(super(mat, flags, at), mat)


func _commit(zone_name: String, kind: String) -> void:
	if kind.begins_with("vehicle "):
		# A vehicle that carries nothing of some material still asked for a
		# surface of it.
		var kept := 0
		for key: String in _tools.keys():
			if key.begins_with("%s|%s/" % [zone_name, kind]):
				var arrays: Array = (_tools[key] as SurfaceTool).commit_to_arrays()
				if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null or (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
					_tools.erase(key)
				else:
					kept += 1
		if kept == 0:
			return
	super(zone_name, kind)
	if kind.begins_with("trim "):
		var small := _root.get_child(0) as MeshInstance3D
		small.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		small.visibility_range_end = TRIM_REACH
		small.visibility_range_end_margin = 8.0
	elif kind == "smoke":
		# The cards stand where the shader puts them: wider than the mesh says.
		var column := _root.get_child(0) as MeshInstance3D
		column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		column.extra_cull_margin = 12.0
	elif kind == "glass" and zone_name == "" and _glass_reveal > 0.0:
		(_root.get_child(0) as MeshInstance3D).set_meta(&"reveal", _glass_reveal)
	elif kind.begins_with("own "):
		# Something a vehicle breaks: its mesh goes with its body, in the
		# coordinates of the level.
		var mesh := _root.get_child(0) as MeshInstance3D
		var body: StaticBody3D = _owned[kind.get_slice(" ", 1)]
		mesh.owner = null
		_root.remove_child(mesh)
		_add(mesh, body)
		mesh.name = "Mesh"
		mesh.transform = body.transform.affine_inverse()
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if body.get_meta(&"shadow", false) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.visibility_range_end = TRIM_REACH
		mesh.visibility_range_end_margin = 8.0
	elif kind.begins_with("vehicle "):
		# The number and the load of a vehicle that can be driven go along
		# with it, and what is on its turret turns with that: see
		# scripts/vehicle.gd. The mesh is in the coordinates of the level.
		var load := _root.get_child(0) as MeshInstance3D
		var ride: Node3D = _vehicles.get_node(NodePath(kind.get_slice(" ", 1)))
		load.owner = null
		_root.remove_child(load)
		_add(load, ride)
		load.name = "TurretLoad" if kind.ends_with(" turret") else "Load"
		load.transform = ride.transform.affine_inverse()
		load.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		load.visibility_range_end = TRIM_REACH
		load.visibility_range_end_margin = 8.0
		if kind.ends_with(" turret"):
			load.set_meta(&"on_turret", true)


## The light under a roof that keeps the sky off: in a tent, under a net,
## in an open shed. Out of doors everything in the shade is lit by the whole
## of the sky and by the sand; under a roof most of that is kept out, and a
## thing stands darker on the ground the further in it stands. A box in the
## frame `xf`, `size` across, in which what is lit from all round is `light`
## instead of the sky, its alpha how strong; over `blend` metres inside its
## sides it goes over into the open air. It is a reflection probe: what
## shines in there shows the inside of the tent, and not the sky, `shine`
## of it. Canvas with the sun on it glows, and a tent that gave all of that
## back would be the colour of its roof all through.
func shelter(xf: Transform3D, size: Vector3, light: Color, blend := 0.8, shine := 0.8) -> void:
	_shelters += 1
	var node := ReflectionProbe.new()
	node.name = "Shelter%d" % _shelters
	node.transform = xf
	node.size = size
	node.box_projection = true
	node.enable_shadows = true
	node.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	node.ambient_color = Color(light.r, light.g, light.b)
	node.ambient_color_energy = light.a
	node.blend_distance = blend
	node.intensity = shine
	node.max_distance = maxf(size.x, size.z) * 0.5 + 6.0
	_add(node, _root)


## One corner at a time: the spot, which way it faces, where on the texture
## it lies and what its vertex colour says.
func _corner(st: SurfaceTool, at: Vector3, normal: Vector3, uv: Vector2, tone: Color) -> void:
	st.set_color(tone)
	st.set_normal(normal)
	st.set_uv(uv)
	st.add_vertex(at)


## Cloth through a grid of `spots`, `across` squares to a row, that faces
## the side `out` points to. It is shaded as one smooth sheet: every spot
## faces the way the cloth lies there. `uvs` and `tones` go with the spots,
## and so does `gives` for cloth that moves in the wind: see WINDBLOWN.
func _cloth(st: SurfaceTool, spots: PackedVector3Array, across: int, uvs: PackedVector2Array, tones: PackedColorArray, out: Vector3, gives := PackedVector2Array()) -> void:
	var wide := across + 1
	@warning_ignore("integer_division")
	var down := spots.size() / wide - 1
	var normals := PackedVector3Array()
	var turned := false
	for j in down + 1:
		for i in wide:
			var east := spots[j * wide + mini(i + 1, across)] - spots[j * wide + maxi(i - 1, 0)]
			var south := spots[mini(j + 1, down) * wide + i] - spots[maxi(j - 1, 0) * wide + i]
			var normal := east.cross(south)
			normals.append(normal.normalized() if normal.length_squared() > 1e-12 else out)
	@warning_ignore("integer_division")
	turned = normals[(down / 2) * wide + across / 2].dot(out) < 0.0
	for j in down:
		for i in across:
			var corners: Array[int] = [j * wide + i, j * wide + i + 1, (j + 1) * wide + i + 1, (j + 1) * wide + i]
			if turned:
				corners.reverse()
			# Godot's winding is clockwise: two triangles, each given backwards.
			for c: int in [0, 2, 1, 0, 3, 2]:
				var k := corners[c]
				if not gives.is_empty():
					st.set_uv2(gives[k])
				_corner(st, spots[k], -normals[k] if turned else normals[k], uvs[k], tones[k])
	if not gives.is_empty():
		st.set_uv2(Vector2.ZERO)


## A skin over rings of spots, `around` to a ring and one more that lies on
## the first, counter-clockwise seen from the far end: a sack, a roll of
## canvas, a rope. Shaded as one smooth skin. `caps` closes the first ring
## (1), the last (2) or both (3).
func _skin(st: SurfaceTool, spots: PackedVector3Array, around: int, uvs: PackedVector2Array, tones: PackedColorArray, caps := 0) -> void:
	var wide := around + 1
	@warning_ignore("integer_division")
	var last := spots.size() / wide - 1
	var normals := PackedVector3Array()
	for j in last + 1:
		for i in wide:
			var round := spots[j * wide + (i + 1) % around] - spots[j * wide + (i + around - 1) % around]
			var along := spots[mini(j + 1, last) * wide + i % around] - spots[maxi(j - 1, 0) * wide + i % around]
			var normal := round.cross(along)
			normals.append(normal.normalized() if normal.length_squared() > 1e-14 else Vector3.UP)
	for j in last:
		for i in around:
			var corners: Array[int] = [j * wide + i, j * wide + i + 1, (j + 1) * wide + i + 1, (j + 1) * wide + i]
			for c: int in [0, 2, 1, 0, 3, 2]:
				var k := corners[c]
				_corner(st, spots[k], normals[k], uvs[k], tones[k])
	for end: int in [0, last]:
		if not caps & (1 if end == 0 else 2):
			continue
		var middle := Vector3.ZERO
		for i in around:
			middle += spots[end * wide + i] / around
		var faces := (spots[end * wide] - middle).cross(spots[end * wide + 1] - middle).normalized() * (-1.0 if end == 0 else 1.0)
		for i in around:
			var a := end * wide + i
			var b := end * wide + i + 1
			var first := a if end == 0 else b
			var second := b if end == 0 else a
			_corner(st, middle, faces, uvs[a], tones[a])
			_corner(st, spots[first], faces, uvs[first], tones[first])
			_corner(st, spots[second], faces, uvs[second], tones[second])


## A round pole from `from` to `to`, painted the green everything is
## painted: of a tent, of a net.
func _pole(from: Vector3, to: Vector3, radius: float, top_radius := -1.0, sides := 6) -> void:
	var st := _tool(ARMY, SLIGHT, (from + to) * 0.5)
	var frame := Transform3D(_up_along(to - from), from)
	var length := from.distance_to(to)
	var top := radius if top_radius < 0.0 else top_radius
	var start := fposmod(from.x * 1.3 + from.z * 0.7, 3.0)
	var up := frame.basis.y
	# Its two ends are edges, and the paint is knocked off them.
	var foot := _edge(Vector2(0.5, 0), Vector2(256.0, length))
	var head := _edge(Vector2(0.5, 1), Vector2(256.0, length))
	for s in sides:
		var a0 := TAU * s / sides
		var a1 := TAU * (s + 1) / sides
		var d0 := Vector3(cos(a1), 0, sin(a1))
		var d1 := Vector3(cos(a0), 0, sin(a0))
		_quad(st, [frame * (d0 * radius), frame * (d1 * radius), frame * (d1 * top + Vector3.UP * length), frame * (d0 * top + Vector3.UP * length)],
			[frame.basis * d0, frame.basis * d1, frame.basis * d1, frame.basis * d0],
			[Vector2(start - a1 * radius, 0), Vector2(start - a0 * radius, 0), Vector2(start - a0 * radius, -length), Vector2(start - a1 * radius, -length)], [foot, foot, head, head])
		_tri(st, [frame * (Vector3.UP * length), frame * (d0 * top + Vector3.UP * length), frame * (d1 * top + Vector3.UP * length)], [up, up, up],
			[Vector2(start, 0), Vector2(start + d0.x * top, d0.z * top), Vector2(start + d1.x * top, d1.z * top)])


## A rope from `from` to `to` that hangs `sag` lower in its middle. It is of
## the stuff sandbags are made of, and too thin to throw a shadow.
func _rope(from: Vector3, to: Vector3, sag := 0.02, radius := 0.006) -> void:
	var st := _trim(SACKING, (from + to) * 0.5)
	var steps := 4 if sag > 0.0 else 1
	var around := 4
	var spots := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tones := PackedColorArray()
	var frame := _up_along(to - from)
	var length := from.distance_to(to)
	for step in steps + 1:
		var t := float(step) / steps
		var middle := from.lerp(to, t) + Vector3.DOWN * sag * sin(PI * t)
		for s in around + 1:
			var turn := TAU * s / around
			spots.append(middle + (frame.x * cos(turn) - frame.z * sin(turn)) * radius)
			uvs.append(Vector2(0.37 + 0.04 * s / around, t * length))
			tones.append(Color(1.0, 0.98, 0.94, 1.0))
	_skin(st, spots, around, uvs, tones)


## A peg driven into the ground at `at`, leaning away from what it holds:
## `pull` is the way to that, on the ground.
func _peg(at: Vector3, pull: Vector3, length := 0.4) -> void:
	var away := -Vector3(pull.x, 0, pull.z).normalized()
	var lean := (Vector3.UP + away * 0.45).normalized()
	var foot := on_ground(at, -length * 0.62)
	_small = true
	_box("wood", Transform3D(_up_along(lean), foot + lean * length * 0.5), Vector3(0.045, length, 0.03), SLIGHT)
	_small = false


## A guy rope from `head` down to a peg at `foot`, with the wooden runner it
## is tightened with.
func _guy(head: Vector3, foot: Vector3) -> void:
	var peg := on_ground(foot, 0.1)
	_rope(head, peg, 0.03)
	_peg(peg, head - peg)
	var runner := peg.lerp(head, 0.3)
	_small = true
	_box("wood", Transform3D(_along(head - peg), runner + Vector3.DOWN * 0.012), Vector3(0.035, 0.016, 0.11), SLIGHT)
	_small = false


# --- Sandbags ----------------------------------------------------------------------


## A wall of sandbags from `from` to `to` (x and z), `layers` bags high, laid
## as bricks are and following the ground. Seven layers is a wall to kneel
## behind. Every other course is closed at either end with half a bag.
func sandbags(from: Vector2, to: Vector2, layers := 7) -> void:
	var length := from.distance_to(to)
	var way := (to - from) / length
	var along := Vector3(way.x, 0, way.y)
	var count := maxi(1, roundi(length / SACK.x))
	var pitch := length / count
	var own := _dice((from + to) * 0.5, layers)
	for layer in layers:
		var shift := 0.5 if layer % 2 == 1 else 0.0
		var top := layer == layers - 1
		# The lower a bag lies, the longer it stays damp.
		var damp := lerpf(0.66, 1.0, sqrt(float(layer) / maxf(layers - 1.0, 1.0)))
		for i in range(-1 if shift > 0.0 else 0, count):
			var run := (i + 0.5 + shift) * pitch
			if run < 0.15 or run > length - 0.15:
				continue
			var at := from + way * run
			var turn := Basis(Vector3.UP, _clutter_rng.randf_range(-0.07, 0.07))
			var across := turn * Vector3.UP.cross(along)
			var middle := ground(at.x, at.y, layer * SACK.y - 0.02) + across * _clutter_rng.randf_range(-0.025, 0.025)
			var long := pitch * _clutter_rng.randf_range(0.9, 0.98)
			var shade := _clutter_rng.randf_range(0.72, 1.0)
			var tint := Color(shade, shade * _clutter_rng.randf_range(0.94, 1.0), shade * _clutter_rng.randf_range(0.86, 0.98))
			_sack(Transform3D(Basis(across, Vector3.UP, turn * along), middle), long, tint * damp, own, top)
		if shift > 0.0:
			for run: float in [pitch * 0.25, length - pitch * 0.25]:
				var at := from + way * run
				var turn := Basis(Vector3.UP, own.randf_range(-0.09, 0.09))
				var across := turn * Vector3.UP.cross(along)
				var shade := own.randf_range(0.72, 1.0)
				var tint := Color(shade, shade * own.randf_range(0.94, 1.0), shade * own.randf_range(0.86, 0.98))
				_sack(Transform3D(Basis(across, Vector3.UP, turn * along), ground(at.x, at.y, layer * SACK.y - 0.02)), pitch * own.randf_range(0.46, 0.5), tint * damp, own, top)
	# What has run out of them lies against the foot of the wall.
	_drift(from, to, SACK.z * 0.5 + 0.02, own)
	var low := minf(ground_height(from.x, from.y), ground_height(to.x, to.y)) - 0.5
	var high := maxf(ground_height(from.x, from.y), ground_height(to.x, to.y)) + layers * SACK.y
	var middle := (from + to) * 0.5
	_collide_box(Transform3D(Basis.looking_at(along), Vector3(middle.x, (low + high) * 0.5, middle.y)), Vector3(SACK.z + 0.04, high - low, length), "soft")


## One sandbag: lying along the Z of `xf` with its underside at the origin.
## A sack of hessian that was filled, tied and thrown down: flat underneath,
## round on top, and pressed flat at either end where its seam is, or
## gathered where it was tied. `tint` is its shade; `own` are the dice of
## the wall it lies in. One that lies on `top` has nothing pressing on it.
func _sack(xf: Transform3D, length: float, tint: Color, own: RandomNumberGenerator, top := false) -> void:
	var st := _tool(SACKING, SLIGHT, xf.origin)
	var half := SACK.z * 0.5
	var rise := SACK.y * (0.58 if top else 0.54) * own.randf_range(0.93, 1.06)
	var around := 8
	# Some have been out a winter longer: darker, or bleached to grey.
	var age := own.randf()
	if age < 0.2:
		tint = tint * Color(0.66, 0.63, 0.58)
	elif age > 0.8:
		tint = tint * Color(1.08, 1.04, 0.94)
	# Along the sack: where a ring lies, how wide and how high it is there,
	# and how round: 0.6 is a sack under load, 1 a neck that was tied.
	var rings: Array[Vector4] = [
		Vector4(-0.5, 0.86, 0.0, 0.6), Vector4(-0.455, 0.95, 0.62, 0.6), Vector4(-0.33, 1.0, 0.98, 0.6),
		Vector4(0.33, 1.0, 0.98, 0.6), Vector4(0.455, 0.95, 0.62, 0.6), Vector4(0.5, 0.86, 0.0, 0.6),
	]
	# One in five was tied at its neck and not folded under.
	var tied := own.randf() < 0.2
	if tied:
		rings = rings.slice(0, 4)
		rings.append_array([Vector4(0.44, 0.7, 0.8, 0.85), Vector4(0.5, 0.25, 0.34, 1.0), Vector4(0.58, 0.42, 0.14, 1.0)])
	var mirror := -1.0 if own.randf() < 0.5 else 1.0
	var lean := own.randf_range(-0.12, 0.12)
	var droop := own.randf_range(0.0, 0.22)
	var slide := own.randf() * 3.0
	var girth := half * 5.2
	var spots := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tones := PackedColorArray()
	for ring in rings:
		var full := ring.z * (1.0 + lean * ring.x * 2.0)
		var middle := rise * (1.0 - 0.25 * (1.0 - minf(ring.z, 1.0))) - droop * rise * ring.x * ring.x * 4.0
		for s in around + 1:
			# Round from the side its seam is on, by way of the top.
			var turn := TAU * s / around + PI
			var x := signf(cos(turn)) * pow(absf(cos(turn)), ring.w) * half * ring.y * mirror
			var y := middle + signf(sin(turn)) * pow(absf(sin(turn)), ring.w) * rise * full * (1.0 if sin(turn) > 0.0 else 0.92)
			spots.append(xf * Vector3(x, maxf(y, 0.0), ring.x * length * mirror))
			uvs.append(Vector2((float(s) / around - 0.5) * girth, slide + ring.x * length))
			# Dark underneath and where two sacks meet end to end.
			var lit := (0.72 + 0.28 * sin(turn) if top else 0.7 + 0.2 * absf(cos(turn)) + 0.1 * sin(turn)) * (0.8 if ring.z < 0.5 else 1.0)
			tones.append(Color(tint.r, tint.g, tint.b, lit))
	# A seam shuts a sack by itself; a neck ends in a tuft of hessian.
	_skin(st, spots, around, uvs, tones, 2 if tied else 0)


## Sand along the foot of something that stands from `from` to `to` (x and
## z), on either side of it `off` from its middle: what the wind has laid
## against it and what has run out of it. It is the ground, a little higher.
func _drift(from: Vector2, to: Vector2, off: float, own: RandomNumberGenerator) -> void:
	var length := from.distance_to(to)
	var way := (to - from) / length
	var across := way.orthogonal()
	var steps := maxi(2, roundi(length / 0.5))
	for side: float in [-1.0, 1.0]:
		var spots := PackedVector3Array()
		var uvs := PackedVector2Array()
		var tones := PackedColorArray()
		for step in steps + 1:
			var at := from + way * length * step / steps
			var reach := own.randf_range(0.1, 0.3)
			var high := own.randf_range(0.03, 0.1) * (0.4 if step == 0 or step == steps else 1.0)
			for row: Vector2 in [Vector2(-0.06, high), Vector2(reach * 0.45, high * 0.55), Vector2(reach, -0.015)]:
				var spot := at + across * side * (off + row.x)
				spots.append(ground(spot.x, spot.y, row.y))
				uvs.append(spot)
				tones.append(Color.WHITE)
		_cloth(_trim("dune_ground", ground(from.x, from.y)), spots, 2, uvs, tones, Vector3.UP)


## A post of sandbags to shoot from: a wall `width` wide across the way
## `yaw_deg` faces (0 looks along +Z) with a wing `depth` long at either end,
## open at the back.
func sandbag_post(at: Vector2, yaw_deg: float, width := 4.2, depth := 2.4, layers := 7) -> void:
	var ahead := Vector2(0, 1).rotated(-deg_to_rad(yaw_deg))
	var side := ahead.orthogonal()
	var front := at + ahead * depth * 0.5
	sandbags(front - side * width * 0.5, front + side * width * 0.5, layers)
	for end: float in [-1.0, 1.0]:
		var corner := front + side * end * (width * 0.5 - 0.15) - ahead * 0.3
		sandbags(corner, corner - ahead * depth, layers)
	cover("earth", at, maxf(width, depth) * 0.6, 0.8)
	# By night a lantern on the ground inside, against a wall.
	var lantern := at - ahead * (depth * 0.3) + side * (width * 0.5 - 0.5)
	storm_lantern(ground(lantern.x, lantern.y, 0.01))


## A ring of sandbags `radius` across its middle, with a way in on the side
## `opens_deg` (0 is +Z): a pit for a gun or a look-out.
func sandbag_ring(at: Vector2, radius: float, opens_deg: float, layers := 6) -> void:
	var sides := maxi(8, roundi(TAU * radius / 1.8))
	for i in sides:
		var from := deg_to_rad(opens_deg) + TAU * (i + 0.5) / sides
		var to := deg_to_rad(opens_deg) + TAU * (i + 1.5) / sides
		if i == sides - 1:
			continue
		sandbags(at + Vector2(sin(from), cos(from)) * radius, at + Vector2(sin(to), cos(to)) * radius, layers)
	cover("earth", at, radius + 0.5, 0.8)


# --- Cloth -------------------------------------------------------------------------


## A sheet of cloth between four corners, counter-clockwise seen from the
## side it faces, that hangs `sag` lower in its middle.
func _sheet(mat: String, corners: Array, sag := 0.0, across := 4, down := 2) -> void:
	var first: Vector3 = corners[0]
	var second: Vector3 = corners[1]
	var third: Vector3 = corners[2]
	var fourth: Vector3 = corners[3]
	var st := _tool(mat, SLIGHT, (first + third) * 0.5)
	var wide := first.distance_to(second)
	var high := first.distance_to(fourth)
	var spots := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tones := PackedColorArray()
	for j in down + 1:
		for i in across + 1:
			var u := float(i) / across
			var v := float(j) / down
			spots.append(first.lerp(second, u).lerp(fourth.lerp(third, u), v) + Vector3.DOWN * sag * sin(PI * u) * sin(PI * v))
			uvs.append(Vector2(wide * u, -high * v))
			tones.append(CLOTH)
	_cloth(st, spots, across, uvs, tones, (second - first).cross(fourth - first))


## A tent on the ground at `at`, its ridge along the X of the way it is
## turned: `size` is its length, the height of its ridge and its depth. The
## long side that faces `yaw_deg` (0 looks along +Z) is rolled up; the back
## and the two ends are shut, and those stop a look and a shot. Returns where
## it stands, for whatever goes into it: X along the ridge, +Z out of the
## open side, the origin on the ground in its middle.
##
## A ridge tent of proofed canvas: a ridge pole on two uprights, the roof
## drawn out over a pole at every seam of the wall and roped down to pegs,
## the walls hanging from its eaves into the sand. Nothing of it is straight:
## the roof hangs between its poles and the walls belly.
func tent(at: Vector2, yaw_deg: float, size := Vector3(7.0, 3.1, 5.0)) -> Transform3D:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y))
	var half := size.x * 0.5
	var deep := size.z * 0.5
	var eaves := 1.8
	var over := 0.2
	var own := _dice(at, 1)
	var st := _tool(CANVAS, SLIGHT, xf.origin)
	# An odd number of bays: no pole in the middle of the open side.
	var bays := 2 * maxi(0, roundi((size.x / 2.6 - 1.0) * 0.5)) + 1
	var bay := size.x / bays
	var slope := Vector2(deep, size.y - eaves).length()
	# How high the roof hangs over a spot of the floor: taut from the ridge
	# to every pole, and hanging in between.
	var roof := func(x: float, z: float) -> float:
		var s := absf(z) / deep
		var between := pow(sin(PI * fposmod((x + half) / bay, 1.0)), 2.0) if absf(x) < half else 0.0
		var fall := (sqrt(s * s + 0.0012) - 0.0346) / 0.966
		return size.y - (size.y - eaves) * fall - (0.035 + 0.075 * between) * sin(PI * minf(s, 1.0)) - 0.07 * between * s * s
	# How the roof gives in the wind over a spot of the floor: it is held
	# along its ridge and at every pole, and breathes where it hangs between
	# them. Whatever is sewn on it goes with it.
	var breathes := func(x: float, z: float) -> Vector2:
		var slack := pow(sin(PI * fposmod((x + half) / bay, 1.0)), 2.0) if absf(x) < half else 0.0
		return Vector2(0.014 * slack * sin(PI * minf(absf(z) / deep, 1.0)), 0.0)
	# Puts a spot of the tent where it stands, and on the ground where it
	# hangs that low.
	var stood := func(x: float, y: float, z: float) -> Vector3:
		var spot := xf * Vector3(x, y, z)
		return on_ground(spot, y) if y < 0.12 else spot

	# The roof, from the eave at the back over the ridge to the eave in front.
	var columns := PackedFloat32Array([-half - 0.14])
	for i in bays * 6 + 1:
		columns.append(-half + bay * i / 6.0)
	columns.append(half + 0.14)
	var rows := PackedFloat32Array([-1.0 - over / deep, -1.0, -0.82, -0.58, -0.32, -0.1, 0.0, 0.1, 0.32, 0.58, 0.82, 1.0, 1.0 + over / deep])
	var spots := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tones := PackedColorArray()
	var gives := PackedVector2Array()
	var fade := PackedFloat32Array()
	for x in columns:
		fade.append(own.randf_range(-0.07, 0.07))
	for s in rows:
		for i in columns.size():
			var x := columns[i]
			spots.append(xf * Vector3(x, roof.call(x, s * deep), -s * deep))
			uvs.append(Vector2(x + 50.0, s * slope))
			tones.append(Color(0.1 * absf(s) * absf(s), 0.62 - 0.12 * absf(s) + fade[i], 1.0, 1.0))
			gives.append(breathes.call(x, s * deep))
	_cloth(st, spots, columns.size() - 1, uvs, tones, Vector3.UP, gives)
	# A band doubled over the ridge, and a patch or two where it was mended.
	for side: float in [-1.0, 1.0]:
		spots.clear()
		uvs.clear()
		tones.clear()
		gives.clear()
		for s: float in [0.0, 0.035, 0.07]:
			for x in columns:
				spots.append(xf * Vector3(x, roof.call(x, s * deep) + 0.006, s * deep * side))
				uvs.append(Vector2(s * slope + 7.3, x))
				tones.append(Color(0.0, 0.42, 1.0, 0.3))
				gives.append(breathes.call(x, s * deep))
		_cloth(st, spots, columns.size() - 1, uvs, tones, Vector3.UP, gives)
	for patch in 3:
		var x := own.randf_range(-half * 0.8, half * 0.8)
		var s := own.randf_range(0.2, 0.8) * (1.0 if patch < 2 else -1.0)
		var wide := own.randf_range(0.2, 0.4)
		var long := own.randf_range(0.18, 0.3)
		var shade := own.randf_range(0.3, 0.42) if patch != 1 else 0.72
		spots.clear()
		uvs.clear()
		tones.clear()
		gives.clear()
		for j in 3:
			for i in 3:
				var px := x + wide * (i - 1)
				var pz := (s + long / slope * (j - 1)) * deep
				spots.append(xf * Vector3(px, roof.call(px, pz) + 0.005, pz))
				uvs.append(Vector2(pz + 3.1 * patch, px))
				tones.append(Color(0.0, shade, 1.0, 0.25))
				gives.append(breathes.call(px, pz))
		_cloth(st, spots, 2, uvs, tones, Vector3.UP, gives)

	# What hangs from the eaves: the valance, and under it the wall.
	for side: float in [-1.0, 1.0]:
		spots.clear()
		uvs.clear()
		tones.clear()
		gives.clear()
		for drop: float in [0.0, 0.08, 0.17]:
			for x in columns:
				var z := (deep + over + drop * 0.12) * side
				spots.append(xf * Vector3(x, roof.call(x, (deep + over) * side) - drop, z))
				uvs.append(Vector2(x + 50.0, slope * (1.0 + over / deep) + drop))
				tones.append(Color(0.1, 0.5, 1.0 - drop * 0.9, 1.0))
				# The valance hangs free: its hem is never still.
				gives.append(Vector2(0.16 * drop, 0.7))
		_cloth(st, spots, columns.size() - 1, uvs, tones, Vector3(0, 0, side), gives)
	# The back, a length of wall to every bay, laced to the next at a pole.
	var heights := PackedFloat32Array([1.0, 0.85, 0.55, 0.25, 0.06, 0.0])
	spots.clear()
	uvs.clear()
	tones.clear()
	gives.clear()
	var belly := PackedFloat32Array()
	for i in bays:
		belly.append(own.randf_range(-0.05, 0.06))
	var folds := own.randf() * 6.0
	for h in heights:
		for i in bays * 4 + 1:
			var x := -half + bay * i / 4.0
			var top: float = roof.call(x, -deep) - 0.015
			var out := belly[mini(floori(i / 4.0), bays - 1)] * sin(PI * fposmod(i / 4.0, 1.0)) * sin(PI * h) + 0.014 * sin(x * 7.3 + folds) * (1.0 - h) * (1.0 - h)
			out += 0.02 if h < 0.1 else 0.0
			spots.append(stood.call(x, h * top, -deep - out))
			uvs.append(Vector2(x + 20.0, -h * top))
			tones.append(Color(pow(clampf(1.0 - h * top / 0.34, 0.0, 1.0), 2.0), 0.47 + 0.05 * sin(i * 1.7), 1.0 - 0.3 * smoothstep(0.8, 1.0, h), 1.0))
			# A wall is laced to its poles, hangs from the eave and is held
			# by the sand on its sod cloth: it fills in the middle of a bay.
			gives.append(Vector2(0.04 * sin(PI * fposmod(i / 4.0, 1.0)) * sin(PI * h), 0.15))
	# The sod cloth: what lies on the ground along its foot, with sand on it.
	for i in bays * 4 + 1:
		var x := -half + bay * i / 4.0
		spots.append(stood.call(x, 0.004, -deep - 0.13 - 0.03 * sin(i * 2.3)))
		uvs.append(Vector2(x + 20.0, 0.12))
		tones.append(Color(1.0, 0.5, 1.0, 0.0))
		gives.append(Vector2.ZERO)
	_cloth(st, spots, bays * 4, uvs, tones, Vector3(0, 0, -1), gives)
	_collide_box(xf * Transform3D(Basis(), Vector3(0, eaves * 0.5, -deep)), Vector3(size.x, eaves, 0.06), "soft")
	# The ends: each in two halves that lap over one another under the ridge
	# and are held shut there with toggles.
	for end: float in [-1.0, 1.0]:
		var x := end * half
		for part: float in [-1.0, 1.0]:
			spots.clear()
			uvs.clear()
			tones.clear()
			gives.clear()
			var swell := own.randf_range(-0.03, 0.05)
			var across := PackedFloat32Array([1.0, 0.75, 0.5, 0.25, 0.0, -0.035] if part < 0.0 else [1.0, 0.75, 0.5, 0.25, 0.0])
			for h in heights:
				for share in across:
					var z := share * deep * part
					var top: float = roof.call(x, z) - 0.015
					var out := swell * sin(PI * clampf(share, 0.0, 1.0)) * sin(PI * h) + 0.012 * sin(z * 8.1 + folds) * (1.0 - h) * (1.0 - h)
					out += (0.02 if h < 0.1 else 0.0) + (0.016 if part < 0.0 and share < 0.1 else 0.0)
					spots.append(stood.call(x + end * out, h * top, z))
					uvs.append(Vector2(z + 31.0 + end, -h * top))
					tones.append(Color(pow(clampf(1.0 - h * top / 0.34, 0.0, 1.0), 2.0), 0.47 + 0.04 * part, 1.0 - 0.25 * smoothstep(0.8, 1.0, h), 1.0))
					# Held at the corner pole and toggled shut under the ridge.
					gives.append(Vector2(0.035 * sin(PI * clampf(share, 0.0, 1.0)) * sin(PI * h), 0.15))
			for share in across:
				var z := share * deep * part
				spots.append(stood.call(x + end * 0.14, 0.004, z))
				uvs.append(Vector2(z + 31.0 + end, 0.12))
				tones.append(Color(1.0, 0.5, 1.0, 0.0))
				gives.append(Vector2.ZERO)
			_cloth(st, spots, across.size() - 1, uvs, tones, Vector3(end, 0, 0), gives)
		_small = true
		for toggle in 6:
			var y := 0.3 + toggle * 0.42
			_box("wood", xf * Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(x + end * 0.03, y, -0.02)), Vector3(0.022, 0.018, 0.07), SLIGHT)
		_small = false
		_collide_box(xf * Transform3D(Basis(), Vector3(x, eaves * 0.5, 0)), Vector3(0.06, eaves, size.z), "soft")

	# The front is rolled up under its eave and tied there with tapes; at
	# either end a width of it hangs, gathered and tied back to the pole.
	var ties := bays * 2
	spots.clear()
	uvs.clear()
	tones.clear()
	for i in ties * 4 + 1:
		var x := -half + 0.04 + (size.x - 0.08) * i / (ties * 4.0)
		var slack := pow(sin(PI * fposmod(i / 4.0, 1.0)), 2.0)
		var thick := 0.082 * (1.0 + 0.2 * slack + own.randf_range(-0.08, 0.08))
		var middle := Vector3(x, roof.call(x, deep) - 0.22 - 0.045 * slack, deep + 0.02)
		for s in 9:
			var turn := TAU * s / 8.0
			spots.append(xf * (middle + Vector3(0, sin(turn) * thick, -cos(turn) * thick * 0.9)))
			uvs.append(Vector2(x + 20.0, s * 0.055 + 1.0))
			tones.append(Color(0.05, 0.46 + 0.05 * sin(i * 0.9), 0.68 + 0.2 * sin(turn), 0.0))
	_skin(st, spots, 8, uvs, tones, 3)
	for i in ties + 1:
		var x := -half + 0.05 + (size.x - 0.1) * i / ties
		spots.clear()
		uvs.clear()
		tones.clear()
		for edge: float in [-0.02, 0.02]:
			for s in 9:
				var turn := TAU * s / 8.0
				spots.append(xf * Vector3(x + edge, roof.call(x, deep) - 0.2 + sin(turn) * 0.105, deep + 0.02 - cos(turn) * 0.088))
				uvs.append(Vector2(0.3 + edge, s * 0.06))
				tones.append(Color(0.0, 0.9, 0.9, 0.0))
		_skin(st, spots, 8, uvs, tones)
	for end: float in [-1.0, 1.0]:
		spots.clear()
		uvs.clear()
		tones.clear()
		var top: float = roof.call(end * (half - 0.2), deep) - 0.16
		# From the eave down: how high, how wide along the wall, how thick,
		# and how far it is drawn to the pole.
		for ring: Vector4 in [Vector4(top, 0.3, 0.03, 0.0), Vector4(1.45, 0.17, 0.05, 0.08), Vector4(1.12, 0.06, 0.05, 0.16), Vector4(0.8, 0.13, 0.07, 0.12), Vector4(0.42, 0.2, 0.08, 0.06), Vector4(0.2, 0.24, 0.07, 0.04)]:
			for s in 13:
				var turn := TAU * s / 12.0
				var fold := 1.0 + 0.3 * sin(turn * 4.0 + ring.x * 3.0)
				spots.append(xf * Vector3(end * (half - 0.3 + ring.w) - cos(turn) * ring.y * fold * end, ring.x, deep - 0.03 + sin(turn) * ring.z * fold))
				uvs.append(Vector2(s * 0.08 + 40.0, -ring.x))
				tones.append(Color(pow(clampf(1.0 - ring.x / 0.4, 0.0, 1.0), 2.0), 0.5, 0.75 + 0.25 * sin(turn * 4.0 + ring.x * 3.0), 0.15))
		if end > 0.0:
			# Seen from above the rings run the other way round at this end.
			var turned := PackedVector3Array()
			for k in spots.size():
				turned.append(spots[k - k % 13 + 12 - k % 13])
			spots = turned
		_skin(st, spots, 12, uvs, tones)
		_rope(xf * Vector3(end * (half - 0.14), 1.12, deep - 0.02), xf * Vector3(end * (half - 0.03), 1.2, deep), 0.0, 0.005)

	# Its poles: two under the ridge with the ridge pole on them, and one
	# under the eave at every seam of the wall.
	for end: float in [-1.0, 1.0]:
		_pole(xf * Vector3(end * (half - 0.07), 0, 0), xf * Vector3(end * (half - 0.07), size.y - 0.07, 0), 0.042, 0.036)
	_pole(xf * Vector3(-half - 0.1, size.y - 0.045, 0), xf * Vector3(half + 0.1, size.y - 0.045, 0), 0.032)
	for i in bays + 1:
		var x := -half + bay * i
		var inset := 0.05 if i == 0 else (-0.05 if i == bays else 0.0)
		for side: float in [-1.0, 1.0]:
			var head: float = roof.call(x, deep)
			_pole(xf * Vector3(x + inset, 0, side * (deep - 0.04)), xf * Vector3(x + inset, head + 0.05, side * (deep - 0.04)), 0.028, 0.022)
			# The rope from the eave over that pole to its peg, and the
			# cloth the eave is doubled with where the rope pulls on it.
			var eave := Vector3(x, roof.call(x, deep + over) - 0.01, side * (deep + over))
			var splay := (-0.9 if i == 0 else (0.9 if i == bays else own.randf_range(-0.12, 0.12)))
			_guy(xf * eave, xf * Vector3(x + splay, 0, side * (deep + over + own.randf_range(1.35, 1.6))))
			spots.clear()
			uvs.clear()
			tones.clear()
			gives.clear()
			for j in 2:
				for k: float in [-0.13, 0.0, 0.13]:
					var pz := (deep + over - 0.24 * j * (1.0 - absf(k) * 5.0)) * side
					spots.append(xf * Vector3(x + k, roof.call(x + k, pz) + 0.005, pz))
					uvs.append(Vector2(k + 9.0, j * 0.2))
					tones.append(Color(0.1, 0.36, 1.0, 0.2))
					gives.append(breathes.call(x + k, pz))
			_cloth(st, spots, 2, uvs, tones, Vector3.UP, gives)
	# Two ropes from either end of the ridge, against the wind.
	for end: float in [-1.0, 1.0]:
		for side: float in [-1.0, 1.0]:
			_guy(xf * Vector3(end * (half + 0.1), size.y - 0.05, 0), xf * Vector3(end * (half + own.randf_range(1.9, 2.3)), 0, side * own.randf_range(1.2, 1.6)))
	casts_shade(xf * Vector3(0, size.y * 0.75, 0), Vector3(half + 0.4, 0.9, half + 0.4) if absf(fposmod(yaw_deg, 180.0) - 90.0) < 45.0 else Vector3(half + 0.4, 0.9, deep + 0.4))
	cover("earth", at, maxf(half, deep) + 1.6, 0.9)
	# Inside it is dim. The box reaches as far beyond the walls and under
	# the ground as it takes to go over into the open air, so that it is as
	# dim against a wall as in the middle; out of the open front it goes
	# over where the light comes in.
	var over_into := 0.8
	shelter(xf * Transform3D(Basis(), Vector3(0, (size.y - over_into) * 0.5, 0.2)), Vector3(size.x + over_into * 2.0, size.y + over_into, size.z + over_into * 2.0 + 0.4), TENT_LIGHT, over_into, 0.18)
	return xf


## A shelter half pitched low over two poles, for two men to sleep under:
## its ridge along the X of the way it is turned. Two sheets buttoned
## together along the ridge, pegged down along their hems, shut at one end;
## inside, a groundsheet with a bedroll and a pack on it.
func bivouac(at: Vector2, yaw_deg: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y))
	var own := _dice(at, 2)
	var st := _tool(CANVAS, SLIGHT, xf.origin)
	var long := 1.1
	var wide := 0.95
	var ridge := func(x: float) -> float:
		return 1.05 - 0.05 * (1.0 - x * x / (long * long))
	var hem := func(x: float) -> float:
		return 0.015 + 0.05 * pow(sin(PI * (x / long * 0.5 + 0.5) * 2.0), 2.0)
	var spots := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tones := PackedColorArray()
	var shade := own.randf_range(0.42, 0.58)
	for side: float in [-1.0, 1.0]:
		spots.clear()
		uvs.clear()
		tones.clear()
		var gives := PackedVector2Array()
		for j in 5:
			var v := j / 4.0
			for i in 9:
				var x := -long + 2.0 * long * i / 8.0
				var low: float = hem.call(x)
				var y: float = lerpf(ridge.call(x), low, v) - 0.045 * sin(PI * v)
				var spot := xf * Vector3(x, y, side * wide * v * (1.0 - 0.04 * sin(PI * (x / long * 0.5 + 0.5) * 2.0) * v))
				spots.append(on_ground(spot, y) if j == 4 else spot)
				uvs.append(Vector2(x + 3.0 + side, v * 1.4))
				tones.append(Color(pow(clampf(v * 3.0 - 2.0, 0.0, 1.0), 2.0), shade + 0.04 * side, 1.0, 1.0))
				# Buttoned along the ridge, pegged along the hem.
				gives.append(Vector2(0.022 * sin(PI * v) * sin(PI * i / 8.0), 0.3))
		_cloth(st, spots, 8, uvs, tones, Vector3(0, 0.6, side), gives)
		for x: float in [-long, 0.0, long]:
			_peg(on_ground(xf * Vector3(x, 0, side * (wide + 0.03)), 0.08), Vector3(0, 0, -side), 0.26)
	# The end that is shut: two flaps, one over the other.
	for side: float in [-1.0, 1.0]:
		spots.clear()
		uvs.clear()
		tones.clear()
		for j in 4:
			var v := j / 3.0
			for i in 3:
				var u := i / 2.0
				var z := side * wide * v * (1.0 - u) - side * 0.05 * u
				var spot := xf * Vector3(-long - 0.02 - 0.012 * side * u, lerpf(ridge.call(-long), 0.015, v), z)
				spots.append(on_ground(spot, 0.015) if j == 3 else spot)
				uvs.append(Vector2(z + 8.0, v * 1.1))
				tones.append(Color(pow(clampf(v * 3.0 - 2.0, 0.0, 1.0), 2.0), shade - 0.04, 1.0, 1.0))
		_cloth(st, spots, 2, uvs, tones, Vector3(-1, 0, 0))
	# What they sleep on, and what lies on it.
	spots.clear()
	uvs.clear()
	tones.clear()
	for z: float in [-0.7, 0.0, 0.7]:
		for x: float in [-1.0, 0.0, 1.25]:
			spots.append(on_ground(xf * Vector3(x, 0, z), 0.012))
			uvs.append(Vector2(z + 5.0, x))
			tones.append(Color(0.75, 0.35, 0.85, 0.0))
	_cloth(st, spots, 2, uvs, tones, Vector3.UP)
	_bundle(st, xf * Vector3(-0.72, 0.1, own.randf_range(-0.35, 0.35)), xf.basis * Vector3(0.12, 0, 1.0).normalized(), 0.62, 0.095, Color(0.15, 0.78, 1.0, 0.0))
	_bundle(st, xf * Vector3(-0.2, 0.13, 0.42), xf.basis * Vector3(1.0, 0, 0.25).normalized(), 0.5, 0.13, Color(0.3, 0.38, 1.0, 0.0))
	for x: float in [-long, long]:
		_pole(on_ground(xf * Vector3(x, 0, 0)), xf * Vector3(x, 1.09, 0), 0.022, 0.018, 5)
		_guy(xf * Vector3(x, 1.06, 0), xf * Vector3(x * 2.15, 0, 0))
	_collide_box(xf * Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(2.2, 0.9, 1.5), "soft")
	# By night a lantern hangs on the pole at the open end.
	storm_lantern(xf * Vector3(long + 0.035, 0.98, 0), true)


## A roll or a bag of cloth lying at `middle` along `way`: a blanket rolled
## up and strapped, a pack. `tone` is what the canvas shader is told of it.
func _bundle(st: SurfaceTool, middle: Vector3, way: Vector3, length: float, radius: float, tone: Color) -> void:
	var side := Vector3.UP.cross(way).normalized()
	var spots := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tones := PackedColorArray()
	for ring: Vector2 in [Vector2(-0.5, 0.55), Vector2(-0.44, 0.94), Vector2(-0.15, 1.0), Vector2(0.15, 1.0), Vector2(0.44, 0.94), Vector2(0.5, 0.55)]:
		for s in 9:
			var turn := TAU * s / 8.0
			spots.append(middle + way * ring.x * length + (side * cos(turn) + Vector3.UP * sin(turn) * 0.9) * radius * ring.y)
			uvs.append(Vector2(ring.x * length + 0.45, s * radius * 0.8))
			tones.append(Color(tone.r, tone.g, 0.6 + 0.4 * maxf(sin(turn), -0.2), tone.a))
	_skin(st, spots, 8, uvs, tones, 3)


## A camouflage net over the ground at `at`, `size` long (along the X of the
## way it is turned) and deep, `height` up on poles and pegged down along its
## long sides. Whoever stands under it stands in the shade.
##
## It lies on its poles as a net does: up at every pole, hanging between
## them, deepest in the middle. Its skirts come down to a peg every few
## feet and lift off the ground between one peg and the next; at its open
## ends it hangs over its ropes in a ragged apron.
func camo_net(at: Vector2, yaw_deg: float, size: Vector2, height := 3.3) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), Vector3(at.x, 0, at.y))
	var half := size * 0.5
	var own := _dice(at, 3)
	var st := _tool("camo_net", SLIGHT, ground(at.x, at.y))
	var corner := func(x: float, z: float, lift: float) -> Vector3:
		var spot := xf * Vector3(x, 0, z)
		return ground(spot.x, spot.z, lift)
	# How far under the tops of its poles the net hangs over a spot.
	var hang := func(x: float, z: float) -> float:
		var between := pow(sin(PI * absf(x) / half.x), 2.0)
		var inward := pow(cos(PI * 0.5 * clampf(z / half.y, -1.0, 1.0)), 2.0)
		return 0.5 * inward * (0.62 + 0.38 * between) + 0.3 * between * (1.0 - inward * 0.6)
	var pegs := maxi(2, roundi(size.x / 1.7))
	var across := pegs * 4
	var spots := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tones := PackedColorArray()
	var gives := PackedVector2Array()
	for j in 7:
		var z := half.y - size.y * j / 6.0
		for i in across + 1:
			var x := -half.x + size.x * i / across
			spots.append(corner.call(x, z, height - hang.call(x, z) + (own.randf_range(-0.04, 0.04) if j > 0 and j < 6 else 0.0)))
			uvs.append(Vector2(x, z))
			tones.append(Color.WHITE)
			# A net is slack: it lifts and settles where it hangs between
			# its poles, the more the lower it hangs.
			gives.append(Vector2(0.16 * hang.call(x, z), 0.35))
	_cloth(st, spots, across, uvs, tones, Vector3.UP, gives)
	for side: float in [-1.0, 1.0]:
		spots.clear()
		uvs.clear()
		tones.clear()
		gives.clear()
		# How far out each peg stands; between two pegs the hem is drawn in
		# and lifts off the ground.
		var out := PackedFloat32Array()
		for peg in pegs + 1:
			out.append(2.2 + own.randf_range(-0.3, 0.2))
		for j in 5:
			var v := j / 4.0
			for i in across + 1:
				var x := -half.x + size.x * i / across
				var lift := pow(sin(PI * fposmod(i / 4.0, 1.0)), 0.6)
				var reach := lerpf(out[floori(i / 4.0)], out[mini(floori(i / 4.0) + 1, pegs)], fposmod(i / 4.0, 1.0)) - 0.3 * lift
				var top: Vector3 = corner.call(x, side * half.y, height - hang.call(x, side * half.y))
				var foot: Vector3 = corner.call(x, side * (half.y + reach), 0.05 + 0.3 * lift)
				spots.append(top.lerp(foot, v) + Vector3.DOWN * 0.28 * sin(PI * v))
				uvs.append(Vector2(x, side * (half.y + v * 2.6)))
				tones.append(Color.WHITE)
				# The skirt joins the top where that moves, and is held at
				# its pegs; between them the hem is free.
				gives.append(Vector2(lerpf(0.16 * hang.call(x, side * half.y), 0.07 * lift, v) + 0.07 * sin(PI * v), 0.35))
		_cloth(st, spots, across, uvs, tones, Vector3(0, 0.7, side), gives)
		for peg in pegs + 1:
			var x := -half.x + size.x * peg / pegs
			_peg(corner.call(x, side * (half.y + out[peg] + 0.03), 0.08), xf.basis * Vector3(0, 0, -side), 0.3)
	# The apron over either open end.
	for end: float in [-1.0, 1.0]:
		spots.clear()
		uvs.clear()
		tones.clear()
		gives.clear()
		for j in 3:
			for i in 9:
				var z := -half.y + size.y * i / 8.0
				var drop := (0.32 + 0.3 * absf(sin(i * 2.4 + end))) * j * 0.5
				spots.append(corner.call(end * (half.x + 0.1 * j), z, height - hang.call(end * half.x, z) - drop))
				uvs.append(Vector2(end * (half.x + drop), z))
				tones.append(Color.WHITE)
				# The apron hangs free, and its rags are never still.
				gives.append(Vector2(0.16 * hang.call(end * half.x, z) + 0.3 * drop, 0.35 + 0.3 * j))
		_cloth(st, spots, 8, uvs, tones, Vector3(end, 0.3, 0), gives)
	for x: float in [-half.x, 0.0, half.x]:
		for z: float in [-half.y, half.y]:
			var foot: Vector3 = corner.call(x, z, 0.0)
			_pole(foot, foot + Vector3.UP * (height + 0.03), 0.04, 0.032)
			cylinder("wood", foot + Vector3.UP * (height - 0.01), 0.13, 0.03, SLIGHT, Vector3.ZERO, -1.0, 8)
			if x != 0.0:
				_guy(foot + Vector3.UP * height, corner.call(x + signf(x) * 2.1, z + signf(z) * 0.5, 0.0))
	var middle: Vector3 = corner.call(0.0, 0.0, height - 0.3)
	shelter(Transform3D(xf.basis, corner.call(0.0, 0.0, height * 0.5 - 0.3)), Vector3(size.x + 0.6, height + 0.6, size.y + 3.0), NET_LIGHT, 1.6)
	var reach := maxf(half.x, half.y) if absf(fposmod(yaw_deg, 90.0) - 45.0) < 20.0 else 0.0
	casts_shade(middle, Vector3(maxf(half.x, reach) + 0.5, 0.7, maxf(half.y, reach) + 1.2) if absf(fposmod(yaw_deg, 180.0) - 90.0) > 45.0 else Vector3(maxf(half.y, reach) + 1.2, 0.7, maxf(half.x, reach) + 0.5))
	# By night bulbs hang from its middle line, one to every nine metres.
	var bulbs := maxi(1, roundi(size.x / 9.0))
	for i in bulbs:
		var x := -half.x + size.x * (i + 0.5) / bulbs
		hanging_bulb(corner.call(x, 0.0, height - 0.25), 0.55)


# --- Wire and barriers ---------------------------------------------------------------


## A strand of barbed wire from `from` to `to` that hangs `sag` in its
## middle: two ribbons through one another, with the picture of a strand out
## of the concertina on them (see _concertina() in tools/gen_foliage.gd).
func _strand(from: Vector3, to: Vector3, sag := 0.0) -> void:
	var length := from.distance_to(to)
	var pieces := maxi(1, ceili(length / 0.3))
	var way := (to - from) / length
	var flat := way.cross(Vector3.UP).normalized() if absf(way.y) < 0.95 else Vector3.RIGHT
	var up := flat.cross(way)
	var st := _tool("wire", SLIGHT, (from + to) * 0.5)
	for piece in pieces:
		var t0 := float(piece) / pieces
		var t1 := float(piece + 1) / pieces
		var a := from.lerp(to, t0) + Vector3.DOWN * sag * sin(PI * t0)
		var b := from.lerp(to, t1) + Vector3.DOWN * sag * sin(PI * t1)
		# Along one strand of the picture and back along it.
		var u0 := 0.52 + 0.46 * fposmod(piece * 0.31, 1.0) * 0.4
		var u1 := u0 + (b.distance_to(a) / 0.95) * 0.5
		var v := 0.25 if piece % 2 == 0 else 0.75
		for side: Vector3 in [flat, up]:
			var off := side * 0.016
			var faces := (Vector3.UP * 0.85 + way.cross(side) * 0.15).normalized()
			_quad(st, [a - off, b - off, b + off, a + off], [faces, faces, faces, faces],
				[Vector2(u0, v + 0.017), Vector2(u1, v + 0.017), Vector2(u1, v - 0.017), Vector2(u0, v - 0.017)])


## An angle-iron picket driven in at `at`, `height` out of the ground,
## leaning as `lean_deg` says.
func _iron_picket(at: Vector3, height: float, lean_deg: Vector3) -> Transform3D:
	var xf := Transform3D(Basis.from_euler(lean_deg * PI / 180.0), at + Vector3.DOWN * 0.2)
	_box("steel", xf * Transform3D(Basis(), Vector3(0.016, (height + 0.2) * 0.5, 0)), Vector3(0.038, height + 0.2, 0.005), SLIGHT)
	_box("steel", xf * Transform3D(Basis(), Vector3(0, (height + 0.2) * 0.5, 0.016)), Vector3(0.005, height + 0.2, 0.038), SLIGHT)
	return xf * Transform3D(Basis(), Vector3(0, height + 0.2, 0))


## A fence of barbed wire along `path`: posts with five strands between
## them. It shuts a level in, and is as solid to the game as a wall: there
## is nothing beyond it to shoot at.
func wire_fence(path: Array, height := 1.7) -> void:
	var way := curve(path, 3.0)
	var heads: Array[Transform3D] = []
	for i in way.size():
		var foot := ground(way[i].x, way[i].y, -0.3)
		var lean := Vector3(_clutter_rng.randf_range(-3, 3), 0, _clutter_rng.randf_range(-3, 3))
		var frame := Transform3D(Basis.from_euler(lean * PI / 180.0), foot)
		_iron_picket(foot + Vector3.UP * 0.2, height + 0.2, lean)
		heads.append(frame)
		if i == 0:
			continue
		var before := ground(way[i - 1].x, way[i - 1].y)
		var here := ground(way[i].x, way[i].y)
		for strand in 5:
			var lift := 0.55 + strand * (height - 0.3) / 4.0
			_strand(heads[i - 1] * Vector3(0, lift, 0), frame * Vector3(0, lift, 0), 0.03 + 0.01 * strand)
		# Two that cross, to keep the others apart.
		_strand(heads[i - 1] * Vector3(0, 0.55, 0), frame * Vector3(0, height + 0.25, 0))
		_strand(heads[i - 1] * Vector3(0, height + 0.25, 0), frame * Vector3(0, 0.55, 0))
		var middle := (before + here) * 0.5
		_collide_box(Transform3D(Basis.looking_at(Vector3(here.x - before.x, 0, here.z - before.z)), middle + Vector3.UP * (height * 0.5 + 0.3)), Vector3(0.12, height + 2.2, before.distance_to(here) + 0.1), "metal")


## Coils of barbed wire from `from` to `to`, chest high: nobody walks through
## them, but a look and a shot go over.
##
## Concertina: one coil of spring steel a yard across, pulled out along the
## ground between pickets and tied to a strand that runs along their tops.
## Every turn of it is a hoop that leans on the next, one forward and one
## back, and no two stand alike; between two pickets the coil hangs lower.
func wire_coil(from: Vector2, to: Vector2) -> void:
	var length := from.distance_to(to)
	var way := (to - from) / length
	var along := Vector3(way.x, 0, way.y)
	var across := Vector3.UP.cross(along)
	var rings := int(length / 0.42)
	# The dice fall as they always did: two for every turn, two for a picket.
	var turns: Array[Vector2] = []
	for i in rings:
		turns.append(Vector2(_clutter_rng.randf_range(-0.08, 0.08), _clutter_rng.randf_range(-0.3, 0.3)))
	var pickets := maxi(2, int(length / 3.0) + 1)
	var gap := length / maxf(int(length / 3.0), 1.0)
	# A vehicle flattens it: it is a body of its own, see scripts/wire.gd.
	var middle_at := (from + to) * 0.5
	_breakable_into("Wire", "res://scripts/wire.gd", ground(middle_at.x, middle_at.y))
	var heads: Array[Vector3] = []
	for stake in pickets:
		var at := from + way * gap * stake
		var lean := Vector3(_clutter_rng.randf_range(-6, 6), 0, _clutter_rng.randf_range(-6, 6))
		heads.append(_iron_picket(ground(at.x, at.y), 1.1, lean).origin)
	for i in heads.size() - 1:
		_strand(heads[i] + Vector3.DOWN * 0.08, heads[i + 1] + Vector3.DOWN * 0.08, 0.07)
	var own := _dice((from + to) * 0.5, 4)
	for i in rings:
		# Two hoops where there was one, leaning against one another.
		for half: float in [-1.0, 1.0]:
			var run := clampf(length * (i + 0.5) / rings + turns[i].x + half * 0.105, 0.05, length - 0.05)
			var at := from + way * run
			# Slack between two pickets: lower there.
			var slack := pow(sin(PI * fposmod(run / gap, 1.0)), 2.0)
			var radius := 0.475 * own.randf_range(0.9, 1.03) * (1.0 - 0.1 * slack)
			var lean := half * own.randf_range(0.32, 0.55)
			var frame := Basis(Vector3.UP, turns[i].y * 0.7 + own.randf_range(-0.12, 0.12)) * Basis(across, lean) * Basis(across, Vector3.UP, along) * Basis(Vector3.BACK, own.randf() * TAU)
			var middle := ground(at.x, at.y, radius * cos(lean) * 0.96) + across * own.randf_range(-0.05, 0.05)
			var st := _tool("wire", SLIGHT, middle)
			# Lit from above whichever way it leans: wire has no faces.
			var faces := (Vector3.UP * 0.85 + frame.z * 0.15).normalized()
			_quad(st, [middle + frame * Vector3(-radius, -radius, 0), middle + frame * Vector3(radius, -radius, 0), middle + frame * Vector3(radius, radius, 0), middle + frame * Vector3(-radius, radius, 0)],
				[faces, faces, faces, faces], [Vector2(0, 1), Vector2(0.5, 1), Vector2(0.5, 0), Vector2(0, 0)])
	var low := minf(ground_height(from.x, from.y), ground_height(to.x, to.y)) - 0.4
	var high := maxf(ground_height(from.x, from.y), ground_height(to.x, to.y)) + 1.15
	var half_way := (from + to) * 0.5
	_collide_box(Transform3D(Basis.looking_at(along), Vector3(half_way.x, (low + high) * 0.5, half_way.y)), Vector3(0.9, high - low, length), "metal")
	_breakable_into("", "", Vector3.ZERO)


## Builds what follows into a body of its own at `at`, with `script`, which
## a vehicle breaks or flattens as it drives into it; an empty name builds
## into the level again. Its colliders go into that body, and its mesh, see _commit().
## A shot and a blast find it as they found it in the level.
func _breakable_into(body_name: String, script: String, at: Vector3, shadow := false) -> void:
	if body_name == "":
		_owning = null
		_into = null
		return
	if _crushables == null:
		_crushables = Node3D.new()
		_crushables.name = "Crushables"
		_add(_crushables, _root)
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = at
	body.collision_layer = 1 | BREAKABLE
	body.set_script(load(script))
	body.set_meta(&"shadow", shadow)
	_add(body, _crushables)
	body.add_to_group(CRUSHABLE, true)
	_owned[String(body.name)] = body
	_owning = body
	_into = body


## A barrier across a track: a pole, red and white, on a post with a weight
## at its short end. It lies across the way `yaw_deg` faces, `length` long
## from its post at `at`; `raised`, it points at the sky and is in nobody's
## way.
##
## A round pole between two irons set in a block of concrete, banded in
## paint, with a disc hung from its middle for whoever drives up to it and
## a forked post to lie in.
##
## What stops a shot is what is there: the pole, its weight, the irons, the
## disc and the fork, each in a box of its own. Over and under the pole a
## shot goes through, both ways. Nobody walks under it, nor jumps over: it
## lies at a metre, and a player who ducks is 1.1 m tall and jumps 0.9 m.
func barrier_pole(at: Vector2, yaw_deg: float, length := 5.0, raised := false) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y))
	box("concrete", xf * Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), Vector3(0, yaw_deg, 0))
	for z: float in [-0.085, 0.085]:
		_local_box("steel", xf, Vector3(0, 0.82, z), Vector3(0.11, 0.74, 0.012), SLIGHT)
		_local_box("steel", xf, Vector3(0, 0.82, z * 1.3), Vector3(0.012, 0.74, 0.05), SLIGHT)
	_collide_box(xf * Transform3D(Basis(), Vector3(0, 0.82, 0)), Vector3(0.11, 0.74, 0.27), "metal")
	var tilt := Basis(Vector3.BACK, deg_to_rad(78.0 if raised else 0.0))
	var arm := xf * Transform3D(tilt, Vector3(0, 1.0, 0))
	var lying := Basis(Vector3.BACK, -PI * 0.5)
	var bands := int(length / 0.5)
	if not raised:
		var rest := on_ground(xf * Vector3(length - 0.2, 0, 0))
		cylinder("steel", rest, 0.025, 0.94, SLIGHT, Vector3.ZERO, -1.0, 6)
		for z: float in [-0.05, 0.05]:
			_local_box("steel", xf, Vector3(length - 0.2, 0.98, z), Vector3(0.04, 0.16, 0.008), SLIGHT)
		_collide_box(Transform3D(xf.basis, rest + Vector3.UP * 0.53), Vector3(0.06, 1.06, 0.12), "metal")
	# The pole with its weight and its disc snaps off its post when a vehicle
	# drives into it: a body of its own, see scripts/barrier.gd.
	_breakable_into("Barrier", "res://scripts/barrier.gd", arm.origin, true)
	for i in bands:
		# Thicker at the butt than at the tip, as a pole is.
		var thick := lerpf(0.055, 0.038, float(i) / bands)
		_cylinder("enamel_red" if i % 2 == 0 else "paper", arm * Transform3D(lying, Vector3(i * 0.5, 0, 0)), thick, 0.5, SLIGHT, lerpf(0.055, 0.038, float(i + 1) / bands), 8)
	_cylinder("steel", arm * Transform3D(lying, Vector3(-0.85, 0, 0)), 0.05, 0.85, SLIGHT, -1.0, 8)
	_local_box("steel", arm, Vector3(-0.62, -0.02, 0), Vector3(0.44, 0.26, 0.15), SLIGHT)
	_collide_box(arm * Transform3D(Basis(), Vector3(-0.62, -0.02, 0)), Vector3(0.44, 0.26, 0.15), "metal")
	_collide_box(arm * Transform3D(Basis(), Vector3((bands * 0.5 - 0.85) * 0.5, 0, 0)), Vector3(bands * 0.5 + 0.85, 0.11, 0.11), "metal")
	_cylinder("steel", arm * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.13)), 0.018, 0.26, SLIGHT, -1.0, 6)
	if not raised:
		# The disc, red with a white bar, on two links of chain.
		var middle := Vector3(length * 0.5, -0.32, 0)
		_cylinder("enamel_red", arm * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), middle + Vector3(0, 0, -0.006)), 0.21, 0.012, SLIGHT, -1.0, 16)
		_collide_box(arm * Transform3D(Basis(), middle), Vector3(0.42, 0.42, 0.03), "metal")
		for z: float in [-0.008, 0.008]:
			_local_box("paper", arm, middle + Vector3(0, 0, z), Vector3(0.3, 0.065, 0.004), SLIGHT)
		for x: float in [-0.1, 0.1]:
			_local_box("steel", arm, middle + Vector3(x, 0.25, 0), Vector3(0.008, 0.12, 0.008), SLIGHT)
	_breakable_into("", "", Vector3.ZERO)


## A sentry box of boards, its open front facing `yaw_deg`: on skids, with
## a post at every corner, a roof of sheet over a boarded gable, and the
## bands of white it is known by at night.
func sentry_box(at: Vector2, yaw_deg: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y))
	var turn := Vector3(0, yaw_deg, 0)
	for x: float in [-0.6, 0.6]:
		box("wood", xf * Vector3(x, 1.1, 0), Vector3(0.05, 2.2, 1.2), turn)
	box("wood", xf * Vector3(0, 1.1, -0.6), Vector3(1.25, 2.2, 0.05), turn)
	box("wood", xf * Vector3(0, 0.03, 0), Vector3(1.2, 0.06, 1.2), turn, SLIGHT)
	for x: float in [-0.6, 0.6]:
		_local_box("wood", xf, Vector3(x * 0.8, -0.02, 0), Vector3(0.1, 0.1, 1.5), SLIGHT)
		for z: float in [-0.6, 0.6]:
			_local_box("wood", xf, Vector3(x * 1.03, 1.1, z * 1.03), Vector3(0.075, 2.2, 0.075), SLIGHT)
		# A batten along the eave, and the bands.
		_local_box("wood", xf, Vector3(x * 1.05, 2.16, 0), Vector3(0.03, 0.09, 1.3), SLIGHT)
		for stripe in 4:
			_local_box("paper", xf, Vector3(x * 1.047, 0.35 + stripe * 0.5, 0), Vector3(0.008, 0.22, 1.16), SLIGHT)
	_local_box("wood", xf, Vector3(0, 2.16, 0.63), Vector3(1.3, 0.09, 0.03), SLIGHT)
	for z: float in [-0.62, 0.62]:
		extrude("wood", PackedVector2Array([Vector2(-0.66, 0), Vector2(0.66, 0), Vector2(0, 0.37)]), 0.03, xf * Transform3D(Basis(), Vector3(0, 2.2, z)), SLIGHT)
	var pitch := atan2(0.37, 0.66)
	for side: float in [-1.0, 1.0]:
		var faces := Vector3(side * sin(pitch), cos(pitch), 0)
		var rises := Vector3(-side * cos(pitch), sin(pitch), 0)
		var frame := xf * Transform3D(Basis(rises.cross(faces), rises, faces), Vector3(0, 2.6, 0) - rises * 0.44 + faces * 0.012)
		corrugated("roof", frame, Vector2(1.56, 0.92), 0.076, 0.016, SLIGHT)
	_local_box("roof", xf, Vector3(0, 2.61, 0), Vector3(0.1, 0.02, 1.58), SLIGHT)
	# Inside: a shelf, and a peg with what hangs on it.
	_local_box("wood", xf, Vector3(0, 1.25, -0.5), Vector3(1.1, 0.03, 0.16), SLIGHT)
	_local_box("wood", xf, Vector3(0.45, 1.7, -0.56), Vector3(0.03, 0.03, 0.08), SLIGHT)
	# By night a lantern on a hook under the eave of the way in.
	_local_box("dark_steel", xf, Vector3(0.48, 2.06, 0.66), Vector3(0.01, 0.08, 0.01), SLIGHT)
	storm_lantern(xf * Vector3(0.48, 2.02, 0.66), true)


## A board on a post with `text` on it, which has to be in the manifest as a
## decal of kind "text"; it is read from the side `yaw_deg` faces. A post
## that was driven in by hand: it does not stand quite straight.
func sign_post(at: Vector2, yaw_deg: float, text: String, height := 0.2, board := "wood") -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y))
	var wide := height * _lettering_aspect(_lettering(text)) + 0.16
	var own := _dice(at, 7)
	var leans := xf * Transform3D(Basis.from_euler(Vector3(own.randf_range(-0.05, 0.03), 0, own.randf_range(-0.05, 0.05))), Vector3.ZERO)
	_local_box("wood", leans, Vector3(0, 0.68, -0.05), Vector3(0.07, 1.86, 0.06), SLIGHT)
	for y: float in [-1.0, 1.0]:
		_local_box("wood", leans, Vector3(0, 1.45 + y * (height * 0.5 + 0.02), -0.022), Vector3(wide * 0.86, 0.045, 0.02), SLIGHT)
	_local_box(board, leans, Vector3(0, 1.45, 0), Vector3(wide, height + 0.16, 0.022), SLIGHT)
	label(text, leans * Vector3(0, 1.45, 0.012), leans.basis * Vector3.BACK, height, Color(0.9, 0.88, 0.8) if board != "paper" else Color(0.1, 0.1, 0.1), 0.03)


## A pillbox: a low block of concrete with a slit to shoot from on the side
## `yaw_deg` faces and a steel door at the back, half dug in. Nobody is in
## it: its crew stand outside. The slit lies deep in its frame, and the
## sand has drifted against it.
func pillbox(at: Vector2, yaw_deg: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y, -0.5))
	var turn := Vector3(0, yaw_deg, 0)
	# What is in the way is the block it always was. What is seen of it is
	# poured in a shutter of boards with its front corners cut off, under a
	# roof a foot and a half thick that was poured after it and stands over
	# it all round, its upper edge cut back.
	_collide_box(Transform3D(Basis.from_euler(turn * PI / 180.0), xf * Vector3(0, 1.5, 0)), Vector3(5.0, 3.0, 4.4), _surface("concrete"))
	var cut := 0.42
	# Seen from above, with the front of it (+Z) down: counter-clockwise.
	var up_frame := xf * Transform3D(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), Vector3.ZERO)
	extrude("concrete", PackedVector2Array([
		Vector2(-2.5 + cut, -2.2), Vector2(2.5 - cut, -2.2), Vector2(2.5, -2.2 + cut), Vector2(2.5, 2.2), Vector2(-2.5, 2.2), Vector2(-2.5, -2.2 + cut),
	]), 3.0, up_frame * Transform3D(Basis(), Vector3(0, 0, 1.5)), SLIGHT)
	var eave := 0.28
	extrude("concrete", PackedVector2Array([
		Vector2(-2.5 + cut - eave * 0.4, -2.2 - eave), Vector2(2.5 - cut + eave * 0.4, -2.2 - eave), Vector2(2.5 + eave, -2.2 + cut - eave * 0.4),
		Vector2(2.5 + eave, 2.2 + eave), Vector2(-2.5 - eave, 2.2 + eave), Vector2(-2.5 - eave, -2.2 + cut - eave * 0.4),
	]), 0.34, up_frame * Transform3D(Basis(), Vector3(0, 0, 3.12)), SLIGHT)
	extrude("concrete", PackedVector2Array([
		Vector2(-2.3 + cut, -2.1), Vector2(2.3 - cut, -2.1), Vector2(2.4, -2.0 + cut), Vector2(2.4, 2.3), Vector2(-2.4, 2.3), Vector2(-2.4, -2.0 + cut),
	]), 0.14, up_frame * Transform3D(Basis(), Vector3(0, 0, 3.36)), SLIGHT)
	# The slit, stepped back into the wall so that nothing glances in: two
	# frames of concrete, one inside the other, and the dark behind them.
	# Out of it, the muzzle of what is laid on the track.
	_local_box("rubber", xf, Vector3(0, 2.05, 2.205), Vector3(2.4, 0.34, 0.02), SLIGHT)
	for step: Vector3 in [Vector3(3.3, 0.86, 0.1), Vector3(2.9, 0.6, 0.2)]:
		_local_box("concrete", xf, Vector3(0, 2.05 + step.y * 0.5 + 0.07, 2.2 + step.z * 0.5), Vector3(step.x + 0.28, 0.14, step.z), SLIGHT)
		_box("concrete", xf * Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0, 2.05 - step.y * 0.5 - 0.04, 2.2 + step.z * 0.5)), Vector3(step.x + 0.28, 0.1, step.z + 0.06), SLIGHT)
		for x: float in [-1.0, 1.0]:
			_local_box("concrete", xf, Vector3(x * (step.x * 0.5 + 0.07), 2.05, 2.2 + step.z * 0.5), Vector3(0.14, step.y, step.z), SLIGHT)
	# What is new here rolls dice of its own; the sand at its foot falls as
	# it always did.
	var newer := _dice(at, 28)
	var aim := Basis(Vector3.UP, newer.randf_range(-0.3, 0.3)) * Basis(Vector3.RIGHT, 0.06)
	_cylinder("dark_steel", xf * Transform3D(aim * Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 2.02, 2.0)), 0.017, 0.62, SLIGHT, 0.017, 6)
	_cylinder("dark_steel", xf * Transform3D(aim * Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 2.02, 2.0) + aim * Vector3(0, 0, 0.5)), 0.027, 0.16, SLIGHT, 0.022, 6)
	# The eyes it was lifted its shutters by, left in the roof, and the
	# irons a net is hung from along its front.
	_small = true
	for corner: Vector2 in [Vector2(-1.9, -1.6), Vector2(1.9, -1.6), Vector2(-1.9, 1.7), Vector2(1.9, 1.7)]:
		var foot := xf * Vector3(corner.x, 3.42, corner.y)
		rod("steel", foot + xf.basis.x * 0.07, foot + Vector3.UP * 0.1, 0.008, SLIGHT, 4)
		rod("steel", foot - xf.basis.x * 0.07, foot + Vector3.UP * 0.1, 0.008, SLIGHT, 4)
	for x: float in [-2.2, -1.1, 0.0, 1.1, 2.2]:
		rod("steel", xf * Vector3(x, 3.2, 2.46), xf * Vector3(x, 3.2, 2.58), 0.008, SLIGHT, 4)
	_small = false
	# What is left of its net, hung from those irons over one corner.
	var hangs := 1.0 if newer.randf() < 0.5 else -1.0
	var net := _tool("camo_net", SLIGHT, xf.origin)
	var spots := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tones := PackedColorArray()
	var gives := PackedVector2Array()
	for j in 4:
		var v := j / 3.0
		for i in 6:
			var u := i / 5.0
			var x := hangs * lerpf(0.5, 2.95, u)
			var out := lerpf(2.56, 3.05, v) + 0.12 * sin(u * 5.0 + v * 2.0)
			var low := lerpf(3.2, 0.62 + 0.5 * absf(sin(u * 7.0 + hangs)), pow(v, 0.8))
			# Round the corner at its far end.
			var spot := Vector3(x, low, out - maxf(u - 0.75, 0.0) * 2.6)
			spots.append(xf * spot)
			uvs.append(Vector2(u * 2.6 + at.x, v * 2.7))
			tones.append(Color.WHITE)
			gives.append(Vector2(0.09 * v, 0.5))
	_cloth(net, spots, 5, uvs, tones, xf.basis * Vector3(0, 0.2, 1), gives)
	# The door, in its frame, and a step down to it.
	_local_box("door", xf, Vector3(1.2, 1.52, -2.215), Vector3(1.04, 2.02, 0.03), SLIGHT)
	_local_box("door", xf, Vector3(1.2, 1.5, -2.235), Vector3(0.9, 1.9, 0.03), SLIGHT)
	for y: float in [0.9, 2.1]:
		_local_box("door", xf, Vector3(0.78, y, -2.255), Vector3(0.12, 0.05, 0.02), SLIGHT)
	_local_box("door", xf, Vector3(1.56, 1.5, -2.265), Vector3(0.03, 0.16, 0.04), SLIGHT)
	_local_box("concrete", xf, Vector3(1.2, 0.46, -2.5), Vector3(1.3, 0.12, 0.6), SLIGHT)
	# On its roof: the pipe that airs it.
	_cylinder("door", xf * Transform3D(Basis(), Vector3(-1.6, 3.43, -1.2)), 0.07, 0.5, SLIGHT, -1.0, 8)
	_cylinder("door", xf * Transform3D(Basis(), Vector3(-1.6, 3.9, -1.2)), 0.13, 0.05, SLIGHT, 0.04, 8)
	# A slab over the door, to keep the rain and the splinters off it.
	_local_box("concrete", xf, Vector3(1.2, 2.72, -2.5), Vector3(1.7, 0.16, 0.7), SLIGHT)
	var own := _dice(at, 8)
	wall_decal(_pick("leak"), xf * Vector3(-1.2, 2.2, 2.21), xf.basis * Vector3.BACK, 1.4, 1.8)
	wall_decal("grime", xf * Vector3(0, 0.9, 2.21), xf.basis * Vector3.BACK, 4.6, 1.0)
	wall_decal("grime", xf * Vector3(0, 0.9, -2.21), xf.basis * Vector3.FORWARD, 4.6, 1.0)
	for side: Array in [[Vector3(-2.52, 0, -2.2), Vector3(-2.52, 0, 2.2)], [Vector3(-2.5, 0, 2.22), Vector3(2.5, 0, 2.22)], [Vector3(2.52, 0, 2.2), Vector3(2.52, 0, -2.2)]]:
		var from: Vector3 = xf * (side[0] as Vector3)
		var to: Vector3 = xf * (side[1] as Vector3)
		_drift(Vector2(from.x, from.z), Vector2(to.x, to.z), 0.0, own)


## A watchtower of timber, `height` to its floor: four legs, braced both
## ways, a boarded cabin under a pitched roof of sheet, a rail, and a ladder
## up one side. Nobody is up there; it is what is seen of a camp from afar.
## Its legs, braces and floor are in the way, and between them a shot goes
## through.
func watch_tower(at: Vector2, height := 7.0, yaw_deg := 0.0) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y, -0.3))
	var turn := Vector3(0, yaw_deg, 0)
	var half := 1.25
	for x: float in [-half, half]:
		for z: float in [-half, half]:
			beam("wood", xf * Vector3(x * 1.25, 0, z * 1.25), xf * Vector3(x, height + 0.3, z), 0.16, DETAIL)
	for level in 2:
		var low := height * level * 0.5
		var high := height * (level + 1) * 0.5
		var wide_low := half * lerpf(1.25, 1.0, level * 0.5)
		var wide_high := half * lerpf(1.25, 1.0, (level + 1) * 0.5)
		for side: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var across := Vector3(side.y, 0, side.x)
			var out := Vector3(side.x, 0, side.y)
			beam("wood", xf * (out * wide_low + across * wide_low + Vector3.UP * (low + 0.3)), xf * (out * wide_high - across * wide_high + Vector3.UP * high), 0.08, DETAIL)
			beam("wood", xf * (out * wide_low - across * wide_low + Vector3.UP * (low + 0.3)), xf * (out * wide_high + across * wide_high + Vector3.UP * high), 0.08, DETAIL)
			# A girt from leg to leg where the braces meet the legs.
			beam("wood", xf * (out * wide_high + across * wide_high + Vector3.UP * high), xf * (out * wide_high - across * wide_high + Vector3.UP * high), 0.1, DETAIL)
	# The floor on its joists, the boards of the cabin, its posts and the
	# rail on them.
	for z: float in [-1.0, 0.0, 1.0]:
		_local_box("wood", xf, Vector3(0, height + 0.25, z), Vector3(3.2, 0.14, 0.09), SLIGHT)
	box("wood", xf * Vector3(0, height + 0.36, 0), Vector3(3.1, 0.1, 3.1), turn, DETAIL)
	for side: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		_local_box("wood", xf, Vector3(side.x * 1.5, height + 0.95, side.y * 1.5), Vector3(0.06 if side.x != 0.0 else 3.06, 1.1, 0.06 if side.y != 0.0 else 3.06), SLIGHT)
		_local_box("wood", xf, Vector3(side.x * 1.53, height + 1.52, side.y * 1.53), Vector3(0.09 if side.x != 0.0 else 3.16, 0.05, 0.09 if side.y != 0.0 else 3.16), SLIGHT)
	for x: float in [-1.5, 1.5]:
		for z: float in [-1.5, 1.5]:
			_local_box("wood", xf, Vector3(x, height + 1.5, z), Vector3(0.1, 2.2, 0.1), SLIGHT)
	var pitch := atan2(0.55, 1.95)
	for side: float in [-1.0, 1.0]:
		var faces := Vector3(side * sin(pitch), cos(pitch), 0)
		var rises := Vector3(-side * cos(pitch), sin(pitch), 0)
		corrugated("roof", xf * Transform3D(Basis(rises.cross(faces), rises, faces), Vector3(0, height + 3.18, 0) - rises * 1.05), Vector2(3.9, 2.1), 0.13, 0.025, SLIGHT)
	for z: float in [-1.5, 1.5]:
		extrude("wood", PackedVector2Array([Vector2(-1.55, 0), Vector2(1.55, 0), Vector2(0, 0.44)]), 0.03, xf * Transform3D(Basis(), Vector3(0, height + 2.6, z)), SLIGHT)
	_local_box("roof", xf, Vector3(0, height + 3.2, 0), Vector3(0.12, 0.02, 3.94), SLIGHT)
	# The ladder, and a searchlight that is off by day.
	for x: float in [-0.25, 0.25]:
		beam("wood", xf * Vector3(x, 0.2, 2.1), xf * Vector3(x, height + 0.4, 1.56), 0.06, SLIGHT)
	for rung in int(height / 0.32):
		var share := (rung + 1) * 0.32 / height
		_local_box("wood", xf, Vector3(0, 0.2 + share * (height + 0.2), lerpf(2.1, 1.56, share)), Vector3(0.5, 0.04, 0.04), SLIGHT)
	var lamp := xf * Transform3D(Basis.from_euler(Vector3(deg_to_rad(70.0), deg_to_rad(45.0), 0)), Vector3(1.3, height + 1.72, 1.3))
	_cylinder("dark_steel", lamp, 0.2, 0.3, SLIGHT, -1.0, 10)
	_cylinder("lamp_glass", lamp * Transform3D(Basis(), Vector3(0, 0.3, 0)), 0.17, 0.012, SLIGHT, -1.0, 10)
	_local_box("dark_steel", xf, Vector3(1.3, height + 1.56, 1.3), Vector3(0.05, 0.3, 0.05), SLIGHT)
	searchlight(xf * Vector3(1.3, height + 1.78, 1.3), xf.basis * Vector3(1, 0, 1), 14.0)


## A hut of corrugated sheet bent over hoops, `length` long along the X of
## the way it is turned, with an end of brick at either side: a door in it
## between two windows, and at one end the pipe of its stove.
func nissen_hut(at: Vector2, yaw_deg: float, length := 11.0, radius := 2.6) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y, -0.05))
	# The roof is a half round of corrugated sheet, bent over ribs: round, and
	# not a row of flats. Its corrugations are those of the scan it is drawn
	# with, which run over the arch; the sheets lap one over the next down
	# either side, each standing a little proud of the one below it.
	var panels := 20
	var st := _tool("roof", SLIGHT, xf.origin)
	var long := length + 0.12
	var laps: Array[int] = [0, 4, 8, 12, 16, 20]
	for lap in laps.size() - 1:
		# The sheets nearer the ridge lie over those below them.
		var over := 0.012 * (2.0 - absf(lap - 2.0))
		for i in range(laps[lap], laps[lap + 1]):
			var from := PI * i / panels
			var to := PI * (i + 1) / panels
			# A sheet reaches a hand's breadth under the next one up.
			if i == laps[lap] and lap > 2:
				from -= 0.035
			if i == laps[lap + 1] - 1 and lap < 2:
				to += 0.035
			var a := Vector3(0, sin(from), cos(from))
			var b := Vector3(0, sin(to), cos(to))
			var reach := radius + over
			var points: Array[Vector3] = [xf * (a * reach + Vector3(-long * 0.5, 0, 0)), xf * (a * reach + Vector3(long * 0.5, 0, 0)), xf * (b * reach + Vector3(long * 0.5, 0, 0)), xf * (b * reach + Vector3(-long * 0.5, 0, 0))]
			var faces: Array[Vector3] = [xf.basis * a, xf.basis * a, xf.basis * b, xf.basis * b]
			_quad(st, points, faces, [Vector2(0, from * radius), Vector2(long, from * radius), Vector2(long, to * radius), Vector2(0, to * radius)])
	var face := PackedVector2Array()
	for i in panels + 1:
		face.append(Vector2(cos(PI * i / panels), sin(PI * i / panels)) * (radius - 0.02))
	for end: float in [-1.0, 1.0]:
		# The end faces out along the hut: the Z of its frame.
		var out := Vector3(end, 0, 0)
		var wall := xf * Transform3D(Basis(Vector3.UP.cross(out), Vector3.UP, out), out * length * 0.5)
		extrude("brick", face, 0.11, wall * Transform3D(Basis(), Vector3(0, 0, -0.055)), SLIGHT)
		# The door in its frame, with a step; a window either side of it.
		_local_box("wood", wall, Vector3(0, 1.04, 0.01), Vector3(1.08, 2.12, 0.04), SLIGHT)
		_local_box("door", wall, Vector3(0, 1.0, 0.03), Vector3(0.9, 2.0, 0.03), SLIGHT)
		_local_box("door", wall, Vector3(0.36, 1.0, 0.055), Vector3(0.03, 0.14, 0.03), SLIGHT)
		_local_box("concrete", wall, Vector3(0, 0.05, 0.3), Vector3(1.3, 0.14, 0.6), SLIGHT)
		for x: float in [-1.35, 1.35]:
			_local_box("wood", wall, Vector3(x, 1.5, 0.01), Vector3(0.78, 0.68, 0.035), SLIGHT)
			_local_box("scope_glass", wall, Vector3(x, 1.5, 0.02), Vector3(0.68, 0.58, 0.03), SLIGHT)
			_local_box("wood", wall, Vector3(x, 1.5, 0.03), Vector3(0.03, 0.58, 0.02), SLIGHT)
			_local_box("wood", wall, Vector3(x, 1.5, 0.03), Vector3(0.68, 0.03, 0.02), SLIGHT)
			_local_box("concrete", wall, Vector3(x, 1.13, 0.03), Vector3(0.86, 0.06, 0.1), SLIGHT)
		# The sheet stands a hand's breadth proud of the brick, on a rim.
		for i in panels:
			var from := PI * i / panels
			var to := PI * (i + 1) / panels
			beam("roof", wall * (Vector3(cos(from), sin(from), 0) * (radius + 0.01) + Vector3(0, 0, 0.05)), wall * (Vector3(cos(to), sin(to), 0) * (radius + 0.01) + Vector3(0, 0, 0.05)), 0.05, SLIGHT, 0.02)
	# A kerb of concrete the sheet stands on, and the stove's pipe.
	for side: float in [-1.0, 1.0]:
		_local_box("concrete", xf, Vector3(0, 0.12, side * (radius + 0.02)), Vector3(length, 0.3, 0.16), SLIGHT)
	var flue := xf * Vector3(length * 0.5 - 1.6, 0, 0.9)
	_cylinder("roof", Transform3D(Basis(), flue + Vector3.UP * (radius * 0.9)), 0.07, 1.1, SLIGHT, -1.0, 8)
	_cylinder("roof", Transform3D(Basis(), flue + Vector3.UP * (radius * 0.9 + 1.12)), 0.14, 0.06, SLIGHT, 0.03, 8)
	_collide_box(xf * Transform3D(Basis(), Vector3(0, radius * 0.45, 0)), Vector3(length, radius * 0.9, radius * 1.8), "metal")
	_collide_box(xf * Transform3D(Basis(), Vector3(0, radius * 0.9, 0)), Vector3(length, radius * 0.2, radius * 1.1), "metal")
	cover("earth", at, length * 0.6, 0.6)


## A fire of a bivouac: stones in a ring, what is left of the wood, and logs
## to sit on round it. Over it a dixie on a tripod; by it the wood for the
## night, and the mugs of whoever sat here last.
func campfire(at: Vector2) -> void:
	place("stone_fire_pit", ground(at.x, at.y, -0.05), _prop_rng.randf() * 360.0)
	var seats: Array[Vector3] = []
	for i in 3:
		var turn := TAU * i / 3.0 + 0.5
		var seat := at + Vector2(cos(turn), sin(turn)) * 1.7
		var along := Vector3(-sin(turn), 0, cos(turn))
		var middle := ground(seat.x, seat.y, 0.17)
		rod("bark", middle - along * 0.8, middle + along * 0.8, 0.17, DETAIL, 8)
		seats.append(middle)
	cover("earth", at, 2.6, 0.9)
	var own := _dice(at, 9)
	var hearth := ground(at.x, at.y)
	_small = true
	# The tripod, three poles lashed at the top, a chain and the dixie.
	var top := hearth + Vector3.UP * 1.35
	for i in 3:
		var turn := TAU * i / 3.0 + 1.3
		rod("steel", hearth + Vector3(cos(turn), 0, sin(turn)) * 0.62, top + Vector3(cos(turn), 0, sin(turn)) * -0.04, 0.014, SLIGHT, 5)
	rod("steel", top, top + Vector3.DOWN * 0.62, 0.005, SLIGHT, 4)
	cylinder("steel", top + Vector3.DOWN * 0.9, 0.14, 0.22, SLIGHT, Vector3.ZERO, 0.15, 10)
	rod("steel", top + Vector3(-0.14, -0.7, 0), top + Vector3(0, -0.62, 0), 0.004, SLIGHT, 4)
	rod("steel", top + Vector3(0.14, -0.7, 0), top + Vector3(0, -0.62, 0), 0.004, SLIGHT, 4)
	# Wood for the night, stacked by one of the seats.
	var stack := seats[1] + (seats[1] - hearth).normalized() * 0.7 + Vector3.DOWN * 0.17
	var lies := (seats[1] - hearth).cross(Vector3.UP).normalized()
	for layer in 3:
		for i in 4 - layer:
			var across := (seats[1] - hearth).normalized() * ((i - (3 - layer) * 0.5) * 0.13)
			rod("bark", stack + across + Vector3.UP * (0.06 + layer * 0.11) - lies * own.randf_range(0.28, 0.34), stack + across + Vector3.UP * (0.06 + layer * 0.11) + lies * own.randf_range(0.28, 0.34), 0.06, SLIGHT, 6)
	# Mugs on a log, and a tin.
	for i in 2:
		cylinder("steel", seats[0] + Vector3(own.randf_range(-0.3, 0.3), 0.17, own.randf_range(-0.05, 0.05)), 0.04, 0.085, SLIGHT, Vector3.ZERO, 0.045, 8)
	_box("steel", Transform3D(Basis(Vector3.UP, own.randf() * TAU), seats[2] + Vector3(0.2, 0.2, 0)), Vector3(0.17, 0.055, 0.12), SLIGHT)
	_small = false
	smoke(Vector3(at.x, hearth.y + 0.3, at.y), 30.0)
	# By night it burns: scripts/campfire.gd lights it once the level is there.
	if _by_night:
		var fire := Node3D.new()
		fire.name = "Campfire"
		fire.position = hearth + Vector3.UP * 0.05
		fire.set_script(load("res://scripts/campfire.gd"))
		night_light(fire)


# --- By night ------------------------------------------------------------------


## The colours of the lamps of the field by night: the flame of a lantern, a
## bulb on a cable from a generator, the sodium lamps on the masts of a wall,
## and the arc of a searchlight.
const FLAME := Color(1.0, 0.58, 0.28)
const BULB_LIGHT := Color(1.0, 0.74, 0.48)
const SODIUM := Color(1.0, 0.66, 0.34)
const ARC := Color(0.9, 0.94, 1.0)
## A lamp of the night throws a shadow as far as NIGHT_SHADOW metres from
## whoever looks, and from NIGHT_SEEN on fades out over NIGHT_FADE: the
## engine's own fade, lamp by lamp. Farther off a lamp is its glass alone.
const NIGHT_SHADOW := 40.0
const NIGHT_SEEN := 120.0
const NIGHT_FADE := 30.0
## A small lamp, a bulb or a lantern, lights nothing from this far on: what
## it lights is a few metres round it, and from farther off its glass is all
## there is to see of it. Every lamp that lights a spot costs that spot.
const SMALL_SEEN := 55.0
const SMALL_FADE := 15.0
## How strong the beam of a searchlight is in the air, see light_beam().
const BEAM_AIR := 0.12


## A lamp that burns by night at `at`, of `colour`, `energy` strong, as far as
## `reach`: an OmniLight3D in the night of the level, called Bulb so that it
## can be shot out (see night_light()). Most throw no shadow: one that does
## draws six of them. Nothing by day, nor in a level that has no night.
func night_bulb(at: Vector3, colour: Color, energy: float, reach: float, shadow := false) -> void:
	if not _by_night:
		return
	var light := OmniLight3D.new()
	light.name = "Bulb"
	light.position = at
	light.light_color = colour
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.4
	light.shadow_enabled = shadow
	_night_fades(light)
	light.distance_fade_begin = SMALL_SEEN
	light.distance_fade_length = SMALL_FADE
	night_light(light)
	light.add_to_group(&"night_bulbs", true)


## A beam that burns by night from `xf` along its -Z, `angle` degrees across:
## a SpotLight3D in the night of the level, called Floodlight (or a name that
## begins so) so that it can be shot out. Returns it, null without a night.
func night_beam(xf: Transform3D, colour: Color, energy: float, reach: float, angle: float, shadow := true, beam_name := "Floodlight") -> SpotLight3D:
	if not _by_night:
		return null
	var light := SpotLight3D.new()
	light.name = beam_name
	light.transform = xf
	light.light_color = colour
	light.light_energy = energy
	light.spot_range = reach
	light.spot_angle = angle * 0.5
	light.spot_angle_attenuation = 0.8
	light.spot_attenuation = 1.1
	light.shadow_enabled = shadow
	_night_fades(light)
	night_light(light)
	light.add_to_group(&"night_beams", true)
	return light


func _night_fades(light: Light3D) -> void:
	# Nothing of the night is baked: the dunes have no lightmap, and the day
	# has none of these lamps.
	light.light_bake_mode = Light3D.BAKE_DISABLED
	light.distance_fade_enabled = true
	light.distance_fade_begin = NIGHT_SEEN
	light.distance_fade_length = NIGHT_FADE
	light.distance_fade_shadow = NIGHT_SHADOW


## A storm lantern: a tin fount, a glass globe between wires under a cap, and
## a bail. `at` is where it stands, or with `hung` the hook it hangs from. By
## night it burns; a level without a night has none.
func storm_lantern(at: Vector3, hung := false) -> void:
	if not _by_night:
		return
	var foot := at + (Vector3.DOWN * 0.36 if hung else Vector3.ZERO)
	_small = true
	cylinder(ARMY, foot, 0.075, 0.065, SLIGHT, Vector3.ZERO, 0.068, 12)
	_turned("lamp_glass", foot + Vector3.UP * 0.065, Vector3.UP, [
		Vector2(0.036, 0.0), Vector2(0.05, 0.03), Vector2(0.053, 0.065), Vector2(0.044, 0.105), Vector2(0.03, 0.125),
	], 12, true)
	cylinder(ARMY, foot + Vector3.UP * 0.19, 0.058, 0.03, SLIGHT, Vector3.ZERO, 0.032, 12)
	cylinder(ARMY, foot + Vector3.UP * 0.22, 0.022, 0.035, SLIGHT, Vector3.ZERO, 0.018, 8)
	for i in 3:
		var round := TAU * i / 3.0
		var out := Vector3(cos(round), 0, sin(round))
		rod("dark_steel", foot + out * 0.07 + Vector3.UP * 0.065, foot + out * 0.06 + Vector3.UP * 0.19, 0.003, SLIGHT, 4)
	# The bail, over the top from one side to the other.
	var last := foot + Vector3(-0.065, 0.1, 0)
	for i in range(1, 7):
		var turn := PI * i / 6.0
		var point := foot + Vector3(-cos(turn) * 0.065, 0.1 + sin(turn) * (at.y - foot.y - 0.1 if hung else 0.2), 0)
		rod("dark_steel", last, point, 0.0025, SLIGHT, 4)
		last = point
	_small = false
	night_bulb(foot + Vector3.UP * 0.13, FLAME, 1.2, 6.0)


## A bare bulb on its cable, by night: `at` is where the cable hangs from, and
## the bulb is `drop` under it. A level without a night has none.
func hanging_bulb(at: Vector3, drop := 0.6, energy := 2.0, reach := 9.0) -> void:
	if not _by_night:
		return
	_small = true
	rod("rubber", at, at + Vector3.DOWN * drop, 0.005, SLIGHT, 4)
	cylinder("dark_steel", at + Vector3.DOWN * (drop + 0.05), 0.02, 0.05, SLIGHT, Vector3.ZERO, -1.0, 8)
	_ball("lamp_glass", at + Vector3.DOWN * (drop + 0.09), 0.038)
	_small = false
	night_bulb(at + Vector3.DOWN * (drop + 0.1), BULB_LIGHT, energy, reach)


## A searchlight by night at `head`, sweeping to and fro over `sweep` degrees
## either side of `out` (outwards, level), its beam `dip` degrees down:
## scripts/sweep.gd swings it, and a cone in the air shows the beam. It can
## be shot out like a floodlight.
func searchlight(head: Vector3, out: Vector3, dip := 10.0, sweep := 55.0) -> void:
	var look := Basis.looking_at(Vector3(out.x, 0, out.z).normalized(), Vector3.UP) * Basis(Vector3.RIGHT, -deg_to_rad(dip))
	var light := night_beam(Transform3D(look, head), ARC, 60.0, 110.0, 7.0, true, "FloodlightSweep")
	if light == null:
		return
	light.set_script(load("res://scripts/sweep.gd"))
	light.set(&"reach_deg", sweep)
	light.add_to_group(&"searchlights", true)
	# The beam in the air is shorter than the light: it is gone before the
	# light comes down on the ground.
	light_beam(light, 38.0, 7.0)


## The beam of `light`, a spot, seen in the air: a cone `length` long and
## `angle` degrees across along its -Z, that adds light to what is behind
## it, most in its middle and near the lamp (shaders/light_beam.gdshader).
func light_beam(light: SpotLight3D, length: float, angle: float) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.12
	cone.bottom_radius = tan(deg_to_rad(angle * 0.5)) * length + 0.12
	cone.height = length
	cone.radial_segments = 16
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/light_beam.gdshader")
	material.set_shader_parameter(&"colour", light.light_color)
	material.set_shader_parameter(&"strength", BEAM_AIR)
	material.set_shader_parameter(&"beam_length", length)
	cone.material = material
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	beam.mesh = cone
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# The cylinder stands on Y with its top up: laid along -Z, its top at the lamp.
	beam.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -length * 0.5))
	light.add_child(beam)
	beam.owner = light.owner


# --- What says that men live here ------------------------------------------------------


## A model from the manifest put down at `at` as drop() puts one, but for
## what is small: it throws no shadow and is not drawn from far off.
func strew(model: String, at: Vector3, yaw_deg: float, pose := Basis()) -> void:
	var node := prop(model, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at), 1.0, true, pose)
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.visibility_range_end = 45.0
		mesh.visibility_range_end_margin = 5.0


## A sheet of canvas spread on the ground at `at`, `size` long (along the X
## of the way it is turned) and wide: what a tent is floored with, what
## stores are stood on. Trodden, with the sand of every boot on it.
func ground_sheet(at: Vector2, yaw_deg: float, size: Vector2) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), Vector3(at.x, 0, at.y))
	var own := _dice(at, 10)
	var across := maxi(2, roundi(size.x / 0.4))
	var down := maxi(2, roundi(size.y / 0.4))
	var spots := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tones := PackedColorArray()
	for j in down + 1:
		for i in across + 1:
			var spot := xf * Vector3(size.x * (float(i) / across - 0.5), 0, size.y * (float(j) / down - 0.5))
			var edge := i == 0 or j == 0 or i == across or j == down
			# Clear of the ground, which is not as flat as a sheet.
			spots.append(ground(spot.x, spot.z, 0.03 + (0.0 if edge else own.randf_range(0.0, 0.02))))
			uvs.append(Vector2(spot.x, spot.z))
			tones.append(Color(own.randf_range(0.05, 0.36) if not edge else 0.42, own.randf_range(0.4, 0.55), 0.9, 0.0))
	_cloth(_trim(CANVAS, ground(at.x, at.y)), spots, across, uvs, tones, Vector3.UP)


## A tarpaulin drawn over a stack that stands at `at` (its foot) turned
## `yaw_deg`: `size` is how wide, how high and how deep the stack is. The
## canvas lies on its corners and hangs between them and down its sides to
## a hand above the ground, where it is weighted with stones or roped. It
## is the cover and not the stack: what is under it is in the way already.
func tarpaulin(at: Vector3, yaw_deg: float, size: Vector3) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	var own := _dice(Vector2(at.x, at.z), 11)
	var st := _tool(CANVAS, SLIGHT, at)
	var half := Vector3(size.x * 0.5 + 0.04, size.y + 0.03, size.z * 0.5 + 0.04)
	# From the hem on one side up over the stack and down to the other, in
	# rows from one end to the other.
	var over: Array[Vector2] = [Vector2(-1.0, 0.12), Vector2(-1.0, 0.55), Vector2(-1.0, 1.0), Vector2(-0.4, 1.0), Vector2(0.4, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.55), Vector2(1.0, 0.12)]
	var along: Array[Vector2] = [Vector2(-1.0, 0.12), Vector2(-1.0, 0.6), Vector2(-1.0, 1.0), Vector2(-0.33, 1.0), Vector2(0.33, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.6), Vector2(1.0, 0.12)]
	var spots := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tones := PackedColorArray()
	var shade := own.randf_range(0.4, 0.6)
	for j in along.size():
		for i in over.size():
			# Where two sides come down together the canvas stands off the
			# corner in a fold.
			var down := minf(over[i].y, along[j].y)
			var swell := (1.0 - down) * 0.16 + (0.05 if over[i].y < 1.0 and along[j].y < 1.0 else 0.0)
			var x := over[i].x * (half.x + swell * absf(over[i].x) * (1.0 if over[i].y < 1.0 else 0.0))
			var z := along[j].x * (half.z + swell * absf(along[j].x) * (1.0 if along[j].y < 1.0 else 0.0))
			var y := half.y * down + (own.randf_range(-0.04, 0.0) if down >= 1.0 else own.randf_range(-0.03, 0.03) * (1.0 - down))
			spots.append(xf * Vector3(x, y, z))
			uvs.append(Vector2(i * half.x * 0.4 + at.x, j * half.z * 0.4 + at.z))
			tones.append(Color(pow(clampf(1.0 - half.y * down / 0.5, 0.0, 1.0), 2.0) + (0.12 if down >= 1.0 else 0.0), shade + (0.1 if down >= 1.0 else 0.0), 0.8 + 0.2 * down, 0.0))
	_cloth(st, spots, over.size() - 1, uvs, tones, Vector3.UP)
	# A rope over it, from peg to peg.
	var foot := xf * Vector3(0, 0, half.z + 0.5)
	var other := xf * Vector3(0, 0, -half.z - 0.5)
	_rope(on_ground(foot, 0.08), xf * Vector3(0, half.y + 0.012, half.z), 0.0, 0.006)
	_rope(xf * Vector3(0, half.y + 0.012, half.z), xf * Vector3(0, half.y + 0.012, -half.z), 0.0, 0.006)
	_rope(xf * Vector3(0, half.y + 0.012, -half.z), on_ground(other, 0.08), 0.0, 0.006)
	_peg(on_ground(foot, 0.08), xf.basis * Vector3(0, 0, -1), 0.28)
	_peg(on_ground(other, 0.08), xf.basis * Vector3(0, 0, 1), 0.28)


## A kit bag lying at `at` along `yaw_deg`, a blanket rolled next to it, or
## both: what a man owns in the field.
func kit(at: Vector2, yaw_deg: float, bag := true, roll := true) -> void:
	var way := Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3.RIGHT
	var st := _trim(CANVAS, ground(at.x, at.y))
	if bag:
		_bundle(st, ground(at.x, at.y, 0.14), way, 0.72, 0.15, Color(0.3, 0.42, 1.0, 0.0))
	if roll:
		var beside := at + Vector2(way.z, -way.x) * (0.3 if bag else 0.0)
		_bundle(st, ground(beside.x, beside.y, 0.09), way.rotated(Vector3.UP, 0.25), 0.55, 0.09, Color(0.2, 0.78, 1.0, 0.0))


## A steel helmet put down at `at`, on the ground or on whatever is there.
func helmet(at: Vector3, yaw_deg := 0.0) -> void:
	_small = true
	revolve(ARMY, Transform3D(Basis.from_euler(Vector3(0.12, deg_to_rad(yaw_deg), 0.08)), at), PackedVector2Array([
		Vector2(0.155, 0.0), Vector2(0.15, 0.03), Vector2(0.13, 0.1), Vector2(0.085, 0.15), Vector2(0.0, 0.165),
	]), SLIGHT, 10, true)
	_small = false


## A field telephone at `at`: the set in its case, the handset on it, and
## its line running off along the ground towards `line_to` (x and z).
func field_telephone(at: Vector3, yaw_deg: float, line_to: Vector2) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	_small = true
	rounded_box(ARMY, xf * Transform3D(Basis(), Vector3(0, 0.07, 0)), Vector3(0.26, 0.14, 0.12), 0.012, SLIGHT)
	_local_box(ARMY, xf, Vector3(0, 0.16, 0), Vector3(0.2, 0.035, 0.045), SLIGHT)
	for x: float in [-0.085, 0.085]:
		_local_box(ARMY, xf, Vector3(x, 0.15, 0), Vector3(0.05, 0.05, 0.055), SLIGHT)
	rod(ARMY, xf * Vector3(0.14, 0.08, 0), xf * Vector3(0.17, 0.08, 0), 0.02, SLIGHT, 6)
	var far := ground(line_to.x, line_to.y, 0.015)
	var points := PackedVector3Array([xf * Vector3(-0.13, 0.04, 0), on_ground(xf * Vector3(-0.3, 0, 0.1), 0.015)])
	for step in range(1, 6):
		var spot := points[1].lerp(far, step / 5.0) + Vector3(sin(step * 2.1) * 0.25, 0, cos(step * 1.7) * 0.25) * (1.0 if step < 5 else 0.0)
		points.append(on_ground(spot, 0.015))
	hose(ARMY, points, 0.005, SLIGHT, 4)
	_small = false


## Duckboards on the ground from `from` to `to` (x and z): slats nailed on
## two bearers, where the sand was trodden to dust.
func duckboards(from: Vector2, to: Vector2, wide := 0.7) -> void:
	var length := from.distance_to(to)
	var way := (to - from) / length
	var yaw := Vector3(0, rad_to_deg(atan2(way.x, way.y)), 0)
	var slats := int(length / 0.14)
	_small = true
	for side: float in [-1.0, 1.0]:
		var bearer := (from + to) * 0.5 + way.orthogonal() * side * wide * 0.32
		box("wood", ground(bearer.x, bearer.y, 0.025), Vector3(0.07, 0.05, length), yaw, SLIGHT)
	for i in slats:
		var at := from + way * length * (i + 0.5) / slats
		box("wood", ground(at.x, at.y, 0.062), Vector3(wide, 0.024, 0.1), yaw, SLIGHT)
	_small = false


## A line strung from `from` to `to`, with washing on it.
func washing_line(from: Vector3, to: Vector3) -> void:
	var own := _dice(Vector2(from.x, from.z), 12)
	_rope(from, to, 0.12, 0.004)
	var st := _tool(CANVAS, SLIGHT, (from + to) * 0.5)
	var way := (to - from).normalized()
	var length := from.distance_to(to)
	var run := 0.5
	while run < length - 0.8:
		var wide := own.randf_range(0.35, 0.7)
		var long := own.randf_range(0.4, 0.75)
		var shade := own.randf_range(0.45, 0.95)
		var spots := PackedVector3Array()
		var uvs := PackedVector2Array()
		var tones := PackedColorArray()
		var gives := PackedVector2Array()
		for j in 5:
			for i in 3:
				var t := (run + wide * i * 0.5) / length
				var hangs := from.lerp(to, t) + Vector3.DOWN * 0.12 * sin(PI * t)
				spots.append(hangs + Vector3.DOWN * long * j * 0.25 + way.cross(Vector3.UP) * 0.03 * sin(i * 2.0 + j * 0.65 + run))
				uvs.append(Vector2(run + wide * i * 0.5, long * j * 0.25))
				tones.append(Color(0.0, shade, 0.9, 0.9))
				# Pegged to the line, and free below it: the further down,
				# the further the wind takes it.
				gives.append(Vector2(long * 0.38 * pow(j / 4.0, 1.5), 1.0))
		_cloth(st, spots, 2, uvs, tones, way.cross(Vector3.UP), gives)
		run += wide + own.randf_range(0.15, 0.5)


## A flag flying from the head of its hoist at `head`: `size` is how long
## and how high it is. It is hung out flat here, straight downwind, and
## flies in shaders/flag.gdshader, which has the wind of the grass. With it
## the halyard, down to a cleat `cleat` under the head.
func flag(head: Vector3, size := Vector2(2.3, 1.45), cleat := 6.2) -> void:
	var st := _tool("flag", SLIGHT, head)
	var downwind := WIND.normalized()
	var along := Vector3(downwind.x, 0, downwind.y)
	var across := 14
	var down := 7
	# The staff side of the cloth faces the way the wind comes across it.
	var faces := Vector3.UP.cross(along)
	for j in down:
		for i in across:
			var corners: Array[Vector2i] = [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			for c: int in [0, 2, 1, 0, 3, 2]:
				var on := Vector2(corners[c]) / Vector2(across, down)
				st.set_color(Color.WHITE)
				st.set_normal(faces)
				st.set_uv(on)
				st.set_uv2(size)
				st.add_vertex(head + along * on.x * size.x + Vector3.DOWN * on.y * size.y)
	st.set_uv2(Vector2.ZERO)
	_rope(head + Vector3.UP * 0.06, head + Vector3(0.05, -cleat, 0.03), 0.0, 0.004)
	_rope(head + Vector3.DOWN * size.y, head + Vector3(0.05, -cleat, 0.03), 0.0, 0.004)


## Cases of brass where a gun was fired, or where they were thrown out of a
## tank: `count` of them lying about `at`.
func shell_cases(at: Vector2, count: int) -> void:
	var own := _dice(at, 13)
	_small = true
	for i in count:
		var spot := at + Vector2(own.randf_range(-0.7, 0.7), own.randf_range(-0.5, 0.5))
		var turn := own.randf() * TAU
		var way := Vector3(cos(turn), 0, sin(turn))
		var middle := ground(spot.x, spot.y, 0.045)
		_cylinder("brass", Transform3D(_up_along(way), middle - way * 0.3), 0.047, 0.6, SLIGHT, 0.04, 8)
	_small = false


## A thread of smoke that rises `height` over `at`: what is seen of a camp
## from two dunes off. One mesh of cards that turn to whoever looks, with
## the smoke drawn on them by shaders/smoke_column.gdshader.
func smoke(at: Vector3, height: float) -> void:
	var st := _tool_named("|smoke/smoke_column")
	var rows := 12
	for card in 2:
		for row in rows:
			var low := float(row) / rows
			var high := float(row + 1) / rows
			# The corners say how high up the column they are and which
			# side of it; the shader does the rest.
			for corner: Vector3 in [Vector3(-1, low, 0), Vector3(1, low, 0), Vector3(1, high, 0), Vector3(-1, low, 0), Vector3(1, high, 0), Vector3(-1, high, 0)]:
				st.set_color(Color(card * 0.5, 0, 0, 1))
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(corner.x * 0.5 + 0.5, corner.y))
				st.set_uv2(Vector2(height, 0.0))
				st.add_vertex(at + Vector3(0, corner.y * height, 0))


# --- Vehicles ------------------------------------------------------------------------


## A vehicle of tools/models/vehicles.gd on the ground at `at`: "jeep",
## "truck", "tank" or "tank_b", its nose towards `yaw_deg` (0 looks along
## +Z). It rests on the ground as the ground lies. Unless it is `parked`,
## it can be driven (scripts/vehicle.gd): its number and its load go with it
## and its colliders are its own; a tank_b is a tank whose turret is turned.
## A parked one is part of the level, as anything else that stands in it:
## one with a sheet thrown over it, say.
func vehicle(kind: String, at: Vector2, yaw_deg: float, parked := false) -> void:
	var facts: Dictionary = VEHICLES[kind]
	# A model's nose points along -Z.
	var xf := resting(at.x, at.y, yaw_deg + 180.0, facts.span)
	var model := kind if parked or kind != "tank_b" else "tank"
	var node: Node3D = (load("res://scenes/models/%s.scn" % model) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	if _vehicles == null:
		_vehicles = Node3D.new()
		_vehicles.name = "Vehicles"
		_add(_vehicles, _root)
	if parked:
		node.name = kind.to_pascal_case()
		node.transform = xf
		_add(node, _vehicles)
		for part: Array in facts.boxes:
			_collide_box(xf * Transform3D(Basis(), part[0]), part[1], "metal")
	else:
		var body := RigidBody3D.new()
		body.name = kind.to_pascal_case()
		body.transform = xf
		body.set_script(load("res://scripts/vehicle.gd"))
		body.set("kind", model)
		body.set("turret_deg", TRAVERSE.get(kind, 0.0))
		_add(body, _vehicles)
		node.name = "Model"
		_add(node, body)
		_riding = body
	cover("earth", at, facts.span * 1.6, 0.7)
	# No two are the same vehicle: each has its number, and what it carries.
	_vehicle_count += 1
	var own := _dice(at, 20)
	_small = true
	_number(kind, xf, _vehicle_count)
	match kind:
		"jeep":
			_load_jeep(xf, own)
		"truck":
			_load_truck(xf, own)
		"motorcycle":
			pass
		_:
			_load_tank(xf * Transform3D(Basis(Vector3.UP, -deg_to_rad(TRAVERSE[kind])), Vector3(0, 0, -0.2)), xf, own)
	_small = false
	_riding = null
	_on_turret = false


## A part of the sheet of stencils, painted `size` wide and high on a face
## that lies in the XY of `xf` and looks along its +Z.
func _mark(part: Rect2, xf: Transform3D, size: Vector2) -> void:
	var half := size * 0.5
	var out := xf.basis.z
	_quad(_trim("field_marks", xf.origin), [xf * Vector3(-half.x, -half.y, 0.004), xf * Vector3(half.x, -half.y, 0.004), xf * Vector3(half.x, half.y, 0.004), xf * Vector3(-half.x, half.y, 0.004)],
		[out, out, out, out], [Vector2(part.position.x, part.end.y), part.end, Vector2(part.end.x, part.position.y), part.position])


## `figures` stencilled `height` high around the origin of `xf`, read from
## its +Z: figures, and a stroke for anything else. With `begins`, the
## letters of that part of the sheet go before them.
func _stencilled(figures: String, xf: Transform3D, height: float, begins := Rect2()) -> void:
	var wide := height * 0.8
	var lead := height * 2.0 if begins.has_area() else 0.0
	var run := -(lead + wide * figures.length()) * 0.5
	if begins.has_area():
		_mark(begins, xf * Transform3D(Basis(), Vector3(run + lead * 0.5, 0, 0)), Vector2(lead, height))
	run += lead
	for i in figures.length():
		var figure := figures.unicode_at(i) - 48
		var part := Rect2(FIGURES.position + Vector2(figure * FIGURES.size.x, 0), FIGURES.size) if figure >= 0 and figure <= 9 else STROKE
		_mark(part, xf * Transform3D(Basis(), Vector3(run + wide * (i + 0.5), 0, 0)), Vector2(wide, height))


## The frame of a mark on the side `side` of a vehicle (-1 its left, 1 its
## right) at `at`: it reads the right way round from there.
func _on_side(at: Vector3, side: float) -> Transform3D:
	return Transform3D(Basis(Vector3.FORWARD * side, Vector3.UP, Vector3.RIGHT * side), at)


## The number of the vehicle that stands at `xf`, the `serial`th of the
## level: a field car and a lorry carry theirs on either side of the bonnet
## and on the bumper, a tank its last two figures large on its turret.
func _number(kind: String, xf: Transform3D, serial: int) -> void:
	var number := "-%02d-%02d" % [41 + serial * 7 % 50, 10 + (serial * 37 + 5) % 89]
	var begins: Rect2 = NUMBER_BEGINS[kind]
	match kind:
		"jeep":
			for side: float in [-1.0, 1.0]:
				_stencilled(number, xf * _on_side(Vector3(side * 0.461, 0.945, -1.15), side), 0.06, begins)
			_stencilled(number, xf * Transform3D(Basis(Vector3.UP, PI), Vector3(-0.36, 0.5, -1.768)), 0.052, begins)
		"truck":
			for side: float in [-1.0, 1.0]:
				_stencilled(number, xf * _on_side(Vector3(side * 0.611, 1.69, -2.45), side), 0.075, begins)
			_stencilled(number, xf * Transform3D(Basis(Vector3.UP, PI), Vector3(0.52, 0.86, -3.446)), 0.085, begins)
		"motorcycle":
			# On the nose of the sidecar, either side.
			for side: float in [-1.0, 1.0]:
				_stencilled(number, xf * _on_side(Vector3(1.06 + side * 0.255, 0.62, -0.6), side), 0.045, begins)
		_:
			var turret := xf * Transform3D(Basis(Vector3.UP, -deg_to_rad(TRAVERSE[kind])), Vector3(0, 0, -0.2))
			_on_turret = true
			for side: float in [-1.0, 1.0]:
				_stencilled(number.right(2), turret * _on_side(Vector3(side * 1.081, 1.98, 0.6), side), 0.34)
			_on_turret = false


## A box that lies on a vehicle: of `mat`, `size` across, its middle at
## `at` in the frame `xf`, turned `yaw_deg`.
func _stowed_box(mat: String, xf: Transform3D, at: Vector3, size: Vector3, yaw_deg := 0.0) -> void:
	_box(mat, xf * Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at), size, SLIGHT)


## What a field car has in the back of it: whatever its crew threw there.
func _load_jeep(xf: Transform3D, own: RandomNumberGenerator) -> void:
	var st := _trim(CANVAS, xf.origin)
	var across := xf.basis.x.normalized()
	var took := 0
	if own.randf() < 0.6:
		_bundle(st, xf * Vector3(own.randf_range(-0.2, 0.2), 1.06, 1.0), across.rotated(xf.basis.y.normalized(), own.randf_range(-0.2, 0.2)), 0.66, 0.13, Color(0.3, own.randf_range(0.35, 0.5), 1.0, 0.0))
		took += 1
	if own.randf() < 0.5:
		_bundle(st, xf * Vector3(own.randf_range(-0.3, 0.3), 1.0 + 0.2 * took, 1.12), across, 0.5, 0.085, Color(0.2, own.randf_range(0.7, 0.85), 1.0, 0.0))
	if own.randf() < 0.45:
		_stowed_box("wood", xf, Vector3(0.36, 0.72, 0.42), Vector3(0.46, 0.26, 0.32), own.randf_range(-12, 12))
	if own.randf() < 0.4:
		helmet(xf * Vector3(0.36, 0.91, -0.02), own.randf_range(0, 360))
		_small = true
	if own.randf() < 0.35:
		_stowed_box(ARMY, xf, Vector3(-0.34, 0.69, 0.44), Vector3(0.3, 0.2, 0.16), own.randf_range(60, 120))


## What a lorry has on its bed, as far as it shows under the tilt from
## behind: cases, drums, sacks, or next to nothing.
func _load_truck(xf: Transform3D, own: RandomNumberGenerator) -> void:
	var bed := 1.297
	match own.randi() % 5:
		0, 1:
			# Cases, stacked as they came off the last lorry.
			# Three abreast, and a second layer on the first.
			var under: Array[float] = [0.0, 0.0, 0.0]
			for i in own.randi_range(3, 6):
				var size := Vector3(own.randf_range(0.42, 0.56), own.randf_range(0.3, 0.46), own.randf_range(0.5, 0.8))
				var lane := i % 3
				_stowed_box("wood" if own.randf() < 0.7 else ARMY, xf, Vector3(-0.62 + lane * 0.62 + own.randf_range(-0.03, 0.03), bed + under[lane] + size.y * 0.5, 2.95 + own.randf_range(-0.1, 0.1)), size, own.randf_range(-5, 5))
				under[lane] += size.y
		2:
			# Drums of fuel, standing, and one on its side against them.
			for i in own.randi_range(3, 5):
				var at := Vector3(-0.72 + (i % 3) * 0.7 + own.randf_range(-0.03, 0.03), bed, 3.1 - floorf(i / 3.0) * 0.64)
				_cylinder(ARMY, xf * Transform3D(Basis(), at), 0.29, 0.88, SLIGHT, 0.29, 10)
				for hoop: float in [0.28, 0.6]:
					_cylinder(ARMY, xf * Transform3D(Basis(), at + Vector3(0, hoop, 0)), 0.3, 0.03, SLIGHT, 0.3, 10)
		3:
			# Sacks, thrown on in a heap.
			var st := _trim(SACKING, xf.origin)
			for i in own.randi_range(5, 8):
				var layer := floorf(i / 4.0)
				var at := Vector3(-0.6 + (i % 4) * 0.4 + own.randf_range(-0.05, 0.05), bed + 0.1 + layer * 0.19, 2.9 + own.randf_range(-0.2, 0.25) - layer * 0.15)
				var shade := own.randf_range(0.75, 1.0)
				_bundle(st, xf * at, xf.basis.z.normalized().rotated(xf.basis.y.normalized(), own.randf_range(-0.5, 0.5)), 0.62, 0.11, Color(shade, shade * 0.97, shade * 0.9, 0.9))
		_:
			# Unloaded: the sheet it was covered with, folded, and a can.
			_bundle(_trim(CANVAS, xf.origin), xf * Vector3(own.randf_range(-0.5, 0.3), bed + 0.12, 2.6), xf.basis.x.normalized(), 0.9, 0.13, Color(0.35, 0.4, 0.9, 0.0))
			_stowed_box(ARMY, xf, Vector3(0.7, bed + 0.21, 3.2), Vector3(0.34, 0.42, 0.15), own.randf_range(-30, 30))


## What a tank carries on its back: `turret` is the frame of its turret,
## `hull` that of its hull.
func _load_tank(turret: Transform3D, hull: Transform3D, own: RandomNumberGenerator) -> void:
	var st := _trim(CANVAS, hull.origin)
	var across := hull.basis.x.normalized()
	if own.randf() < 0.65:
		# A sheet, rolled and lashed across the engine deck.
		_bundle(st, hull * Vector3(own.randf_range(-0.1, 0.1), 1.7, 2.58), across, own.randf_range(1.2, 1.6), 0.13, Color(0.3, own.randf_range(0.38, 0.55), 0.9, 0.0))
	if own.randf() < 0.55:
		_stowed_box("wood", hull, Vector3(own.randf_range(0.4, 0.6) * (1.0 if own.randf() < 0.5 else -1.0), 1.71, own.randf_range(1.3, 1.9)), Vector3(0.55, 0.28, 0.4), own.randf_range(-8, 8))
	if own.randf() < 0.5:
		# A baulk of timber along the guard, for when it bogs.
		_cylinder("wood", hull * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3((1.0 if own.randf() < 0.5 else -1.0) * 1.22, 1.6, -1.1)), 0.085, 2.2, SLIGHT, 0.085, 7)
	# What lies on the turret goes round with it.
	_on_turret = true
	if own.randf() < 0.5:
		_bundle(_trim(CANVAS, turret.origin), turret * Vector3(own.randf_range(-0.3, 0.3), 2.21, 1.62), turret.basis.x.normalized(), 0.8, 0.1, Color(0.2, own.randf_range(0.6, 0.85), 1.0, 0.0))
	if own.randf() < 0.4:
		helmet(turret * Vector3(-0.45, 2.38, 0.25), own.randf_range(0, 360))
		_small = true
	_on_turret = false
	if own.randf() < 0.4:
		_stowed_box(ARMY, hull, Vector3(-0.3, 1.72, 2.2), Vector3(0.34, 0.3, 0.15), own.randf_range(-20, 20))
