extends "res://tools/kit/structure.gd"
## Seventh drawer of the kit, see tools/kit.gd: what runs through a building
## and what hangs on its walls. Pipes, ducts and sprinklers under a ceiling,
## each on its hangers; cable trays, conduit, rainwater pipes and radiators
## along a wall; and what is screwed to one: a sign over a door, a lamp, a
## notice board, a model on a hook.
##
## A run is given by where it goes and by the ceiling it hangs from. What
## goes on a wall is given by a spot on the face of that wall and the way
## the face looks, `inwards`, so that it can go on any wall of any room.


# --- Under a ceiling ------------------------------------------------------------


## A pipe through `points`, with a bend where it turns, a pair of flanges
## near either end of every long stretch, and on every level stretch a
## hanger up to `ceiling` every couple of metres. Without a ceiling it hangs
## from nothing: for a pipe along a wall, which wall_brackets() holds.
func pipe_run(points: Array, radius: float, mat := "pipe", ceiling := NAN, flags := DETAIL | NO_COLLIDE) -> void:
	_m = Transform3D()
	_part = flags
	var bend := maxf(radius * 2.4, 0.12)
	var from: Vector3 = points[0]
	for i in range(1, points.size()):
		var corner: Vector3 = points[i]
		var into := (corner - from).normalized()
		var to := corner
		var next := corner
		if i < points.size() - 1:
			# Stop short of the corner, and go round it.
			var out := ((points[i + 1] as Vector3) - corner).normalized()
			var before := corner - into * bend
			var after := corner + out * bend
			var half := corner - into * bend * 0.293 + out * bend * 0.293
			to = before - into * bend
			next = after + out * bend
			hose(mat, PackedVector3Array([to, before, half, after, next]), radius, flags, 10)
		var length := (to - from).dot(into)
		if length > 0.02:
			rod(mat, from, to, radius, flags, 10)
		if length > 2.4:
			for near: float in [0.45, length - 0.45]:
				_flange(mat, from + into * near, into, radius)
		if not is_nan(ceiling) and absf(into.y) < 0.2 and length > 1.2:
			var hangers := maxi(1, roundi(length / 2.3))
			for h in hangers:
				var hung := from + into * length * (h + 0.5) / hangers
				rod(IRON, hung + Vector3(0, radius, 0), Vector3(hung.x, ceiling, hung.z), 0.006, flags, 6)
				_bar(IRON, hung - into * 0.012, hung + into * 0.012, radius + 0.01, 10)
		from = next
	_part = NO_COLLIDE


## A gate valve in a pipe of `radius` that runs along `axis` through `at`,
## its wheel on a stem that stands out along `stem`.
func pipe_valve(at: Vector3, axis: Vector3, stem: Vector3, radius: float, flags := DETAIL | NO_COLLIDE) -> void:
	_m = Transform3D()
	_part = flags
	var along := axis.normalized()
	var out := stem.normalized()
	for side: float in [-1.0, 1.0]:
		_flange(RUST, at + along * side * radius * 1.6, along, radius)
	_block(IRON, at, Vector3.ONE * radius * 2.6, radius * 0.4)
	_bar(BARE, at + out * radius * 1.2, at + out * radius * 4.4, radius * 0.14, 8)
	_handwheel(at + out * radius * 4.2, out, radius * 1.5)
	_part = NO_COLLIDE


## A duct of galvanised sheet between two points at the same height, in
## lengths that are flanged together and hung from `ceiling` on straps, with
## `grilles` grilles in its underside.
func duct_run(from: Vector3, to: Vector3, ceiling: float, size := Vector2(0.4, 0.28), grilles := 0) -> void:
	var small := DETAIL | NO_COLLIDE
	var length := from.distance_to(to)
	# Local -Z runs along the duct.
	var frame := Transform3D(Basis.looking_at(to - from), (from + to) * 0.5)
	_local_box("galvanised", frame, Vector3.ZERO, Vector3(size.x, size.y, length), NO_COLLIDE)
	var joints := maxi(1, roundi(length / 1.5))
	for i in joints:
		var z := -length * 0.5 + length * (i + 0.5) / joints
		_local_box("galvanised", frame, Vector3(0, 0, z), Vector3(size.x + 0.06, size.y + 0.06, 0.03), small)
		if i % 2 == 0:
			_local_box("dark_steel", frame, Vector3(0, -size.y * 0.5 - 0.006, z + 0.12), Vector3(size.x + 0.1, 0.012, 0.03), small)
			for side: float in [-1.0, 1.0]:
				var strap := frame * Vector3(side * (size.x * 0.5 + 0.035), -size.y * 0.5 - 0.006, z + 0.12)
				rod("dark_steel", strap, Vector3(strap.x, ceiling, strap.z), 0.005, small, 6)
	for g in grilles:
		var z := -length * 0.5 + length * (g + 0.5) / grilles
		var under := Vector3(0, -size.y * 0.5 - 0.002, z)
		_local_box("dark_steel", frame, under, Vector3(size.x * 0.75, 0.004, 0.5), small)
		for i in 8:
			_box("galvanised", frame * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(28.0)), under + Vector3(0, -0.012, (i - 3.5) * 0.058)), Vector3(size.x * 0.7, 0.003, 0.04), small)


## A round duct of spiral-wound sheet between two points at the same height,
## hung from `ceiling`, with `outlets` nozzles that blow down and aside.
func round_duct(from: Vector3, to: Vector3, ceiling: float, radius := 0.25, outlets := 0) -> void:
	var small := DETAIL | NO_COLLIDE
	var length := from.distance_to(to)
	var along := (to - from).normalized()
	var across := Vector3.UP.cross(along)
	rod("galvanised", from, to, radius, NO_COLLIDE, 14)
	_m = Transform3D()
	_part = small
	var joints := maxi(1, roundi(length / 2.0))
	for i in joints + 1:
		var at := from + along * length * i / joints
		_bar("galvanised", at - along * 0.02, at + along * 0.02, radius + 0.025, 14)
		if i < joints:
			var hung := at + along * length / joints * 0.5
			for side: float in [-1.0, 1.0]:
				rod("dark_steel", hung + across * side * (radius + 0.01), Vector3(hung.x + across.x * side * (radius + 0.01), ceiling, hung.z + across.z * side * (radius + 0.01)), 0.005, small, 6)
			_bar("dark_steel", hung - along * 0.015, hung + along * 0.015, radius + 0.012, 14)
	for o in outlets:
		var at := from + along * length * (o + 0.5) / outlets
		var side := 1.0 if o % 2 == 0 else -1.0
		var down := (Vector3.DOWN + across * side * 0.7).normalized()
		_bar("galvanised", at + down * radius * 0.6, at + down * (radius + 0.3), radius * 0.5, 10)
		_bar("dark_steel", at + down * (radius + 0.3), at + down * (radius + 0.33), radius * 0.56, 10)
	_part = NO_COLLIDE


## A line of sprinklers between two points at the same height: a red pipe on
## clips from `ceiling`, with a head on a drop every few metres.
func sprinkler_line(from: Vector3, to: Vector3, ceiling: float, every := 3.0) -> void:
	var small := DETAIL | NO_COLLIDE
	var length := from.distance_to(to)
	var along := (to - from).normalized()
	rod(RED, from, to, 0.024, small, 8)
	var heads := maxi(1, roundi(length / every))
	for i in heads:
		var at := from + along * length * (i + 0.5) / heads
		rod(RED, at, at + Vector3.DOWN * 0.12, 0.012, small, 6)
		rod(BRASS, at + Vector3.DOWN * 0.12, at + Vector3.DOWN * 0.16, 0.022, small, 6)
		var hung := at + along * length / heads * 0.5
		if i < heads - 1:
			rod(IRON, hung, Vector3(hung.x, ceiling, hung.z), 0.004, small, 4)


# --- Along a wall ---------------------------------------------------------------


## The frame of something on a wall: at `at` on its face, with X along the
## wall to the right of whoever looks at it, Y up and Z out of the wall.
func _on_wall(at: Vector3, inwards: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP.cross(inwards), Vector3.UP, inwards), at)


## A model hung on a wall: `at` is the middle of its back, on the face of
## the wall. `pose` turns the model first, for one that was scanned lying
## down, and `turn_deg` turns it on the wall, for one that hangs askew.
func hang(model: String, at: Vector3, inwards: Vector3, pose := Basis(), scale := 1.0, turn_deg := 0.0) -> void:
	var size: Vector3 = (Transform3D(pose, Vector3.ZERO) * (_model(model).box as AABB)).size * scale
	var on_wall := _on_wall(at, inwards) * Transform3D(Basis(Vector3.BACK, deg_to_rad(turn_deg)), Vector3.ZERO)
	prop(model, on_wall * Transform3D(Basis(), Vector3(0, -size.y * 0.5, size.z * 0.5)), scale, true, pose)


## A sign over a door or on a wall: an enamelled plate with `text` on it,
## which has to be in the manifest as a decal of kind "text". `at` is the
## middle of the plate on the face of the wall.
func sign_plate(at: Vector3, inwards: Vector3, text: String, height := 0.2, mat := "machine_blue") -> void:
	var texture := _lettering(text)
	if not ResourceLoader.exists("res://assets/decals/%s.png" % texture):
		push_error("sign_plate: no lettering for '%s': add a decal of kind text to assets/manifest.json and run tools/gen_decals.sh" % text)
		return
	var small := DETAIL | NO_COLLIDE
	var on_wall := _on_wall(at, inwards)
	var letters := height * 0.55
	var width := letters * _lettering_aspect(texture) + height * 0.9
	rounded_box(mat, on_wall * Transform3D(Basis(), Vector3(0, 0, 0.008)), Vector3(width, height, 0.016), 0.006, small)
	for side: float in [-1.0, 1.0]:
		_local_box("bare_steel", on_wall, Vector3(side * (width * 0.5 - 0.035), 0, 0.018), Vector3(0.014, 0.014, 0.006), small)
	label(text, on_wall * Vector3(0, 0, 0.017), inwards, letters, Color(0.86, 0.86, 0.82), 0.012)


## A bulkhead lamp on a wall: a cast housing with a cage over its glass. Its
## light is baked into the lightmap whole, and the lamp itself is there for
## the bake alone: scripts/bake_only.gd takes it out of the game, where it
## would cost every pixel within its range and light only what has no
## lightmap. So it costs nothing to draw however many there are, and for the
## same reason it is no lamp to the game: it cannot be shot out.
func wall_lamp(at: Vector3, inwards: Vector3, on := true, reach := 7.0, energy := 4.0) -> void:
	var small := DETAIL | NO_COLLIDE
	var on_wall := _on_wall(at, inwards)
	rounded_box("dark_steel", on_wall * Transform3D(Basis(), Vector3(0, 0, 0.03)), Vector3(0.34, 0.2, 0.06), 0.02, small)
	rounded_box("emissive_warm" if on else "plaster", on_wall * Transform3D(Basis(), Vector3(0, 0, 0.085)), Vector3(0.26, 0.13, 0.06), 0.025, small)
	for bar: float in [-0.085, 0.0, 0.085]:
		_local_box("dark_steel", on_wall, Vector3(bar, 0, 0.12), Vector3(0.012, 0.16, 0.012), small)
	_local_box("dark_steel", on_wall, Vector3(0, 0, 0.12), Vector3(0.28, 0.012, 0.012), small)
	if not on:
		return
	var light := OmniLight3D.new()
	light.name = "Bulkhead"
	light.position = on_wall * Vector3(0, -0.05, 0.3)
	light.light_color = Color(1.0, 0.72, 0.44)
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	light.light_bake_mode = Light3D.BAKE_STATIC
	# Outside every zone it stays with the other lamps: a level that is not
	# cut into zones, the showroom for one, has no group of its own for it.
	if _zone_at(light.position) == "":
		_add(light, _group("Lights", light.position))
		return
	var baked := _group("Baked", light.position)
	if baked.get_script() == null:
		baked.set_script(load("res://scripts/bake_only.gd"))
	_add(light, baked)


## A notice board with what was pinned to it when the place closed; `at` is
## the middle of its back on the face of the wall.
func pin_board(at: Vector3, inwards: Vector3, wide := 1.15) -> void:
	var small := DETAIL | NO_COLLIDE
	var on_wall := _on_wall(at, inwards)
	var size := Vector2(wide, 0.8)
	_local_box("wood", on_wall, Vector3(0, 0, 0.008), Vector3(size.x, size.y, 0.016), small)
	for edge: float in [-1.0, 1.0]:
		_local_box("galvanised", on_wall, Vector3(0, edge * size.y * 0.5, 0.013), Vector3(size.x + 0.03, 0.03, 0.026), small)
		_local_box("galvanised", on_wall, Vector3(edge * size.x * 0.5, 0, 0.013), Vector3(0.03, size.y, 0.026), small)
	# Sheets of A4 and smaller, none of them straight.
	var sheets := maxi(3, roundi(wide / 0.26))
	for i in sheets:
		var sheet := Vector2(0.21, 0.297) * (1.0 if _decal_rng.randf() < 0.7 else 0.7)
		var where := Vector3(-size.x * 0.5 + size.x * (i + 0.5) / sheets + _decal_rng.randf_range(-0.03, 0.03), _decal_rng.randf_range(-0.2, 0.2), 0.017 + i * 0.0004)
		var xf := on_wall * Transform3D(Basis(Vector3.BACK, deg_to_rad(_decal_rng.randf_range(-6.0, 6.0))), where)
		_box("paper", xf, Vector3(sheet.x, sheet.y, 0.0012), small)
		_box("enamel_red" if i % 3 == 0 else "bare_steel", xf * Transform3D(Basis(), Vector3(0, sheet.y * 0.5 - 0.015, 0.003)), Vector3(0.009, 0.009, 0.005), small)


## Conduit down a wall from `top`, a spot on its face, to a switch at hand
## height, with a saddle or two on the way.
func switch_drop(top: Vector3, inwards: Vector3) -> void:
	var small := DETAIL | NO_COLLIDE
	var on_wall := _on_wall(Vector3(top.x, 0, top.z), inwards)
	rod("galvanised", on_wall * Vector3(0, top.y, 0.012), on_wall * Vector3(0, 1.33, 0.012), 0.011, small, 6)
	var saddles := maxi(1, int((top.y - 1.4) / 0.9))
	for i in saddles:
		_local_box("galvanised", on_wall, Vector3(0, 1.6 + i * 0.9, 0.014), Vector3(0.05, 0.02, 0.028), small)
	rounded_box("galvanised", on_wall * Transform3D(Basis(), Vector3(0, 1.27, 0.03)), Vector3(0.08, 0.12, 0.06), 0.008, small)
	_box("rubber", on_wall * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-14.0)), Vector3(0, 1.27, 0.065)), Vector3(0.018, 0.035, 0.012), small)


## A cable tray along a wall between two points on its face at the same
## height: a ladder on brackets, with `cables` cables lying in it.
func cable_tray(from: Vector3, to: Vector3, inwards: Vector3, cables := 4, width := 0.3) -> void:
	var small := DETAIL | NO_COLLIDE
	var length := from.distance_to(to)
	var along := (to - from).normalized()
	var out := inwards * (width * 0.5 + 0.06)
	for side: float in [-1.0, 1.0]:
		beam("galvanised", from + out + inwards * side * width * 0.5, to + out + inwards * side * width * 0.5, 0.02, small, 0.06)
	var rungs := maxi(2, roundi(length / 0.35))
	for i in rungs + 1:
		var rung := from.lerp(to, float(i) / rungs) + out
		beam("galvanised", rung - inwards * width * 0.5, rung + inwards * width * 0.5, 0.022, small, 0.016)
	var brackets := maxi(2, roundi(length / 1.6))
	for i in brackets:
		var foot := from + along * length * (i + 0.5) / brackets
		beam("dark_steel", foot + Vector3.DOWN * 0.04, foot + inwards * (width + 0.1) + Vector3.DOWN * 0.04, 0.03, small, 0.03)
		beam("dark_steel", foot + Vector3.DOWN * 0.3, foot + inwards * (width + 0.06) + Vector3.DOWN * 0.05, 0.022, small, 0.022)
	for i in cables:
		var thick := 0.015 if i % 2 == 0 else 0.021
		var aside := inwards * (0.06 + 0.05 + (width - 0.1) * (i + 0.5) / cables)
		rod(RUBBER, from + aside + Vector3.UP * (0.01 + thick), to + aside + Vector3.UP * (0.01 + thick), thick, small, 6)


## A pipe along a wall between two points on its face at the same height,
## standing off it on a bracket every couple of metres.
func wall_pipe(from: Vector3, to: Vector3, inwards: Vector3, radius := 0.05, mat := "pipe") -> void:
	var small := DETAIL | NO_COLLIDE
	var off := inwards * (radius + 0.07)
	var length := from.distance_to(to)
	var along := (to - from).normalized()
	rod(mat, from + off, to + off, radius, small, 10)
	var brackets := maxi(2, roundi(length / 2.2))
	for i in brackets:
		var foot := from + along * length * (i + 0.5) / brackets
		beam(IRON, foot, foot + off, 0.025, small, 0.025)
		rod(IRON, foot + off - along * 0.012, foot + off + along * 0.012, radius + 0.01, small, 10)
	_part = NO_COLLIDE


## A rainwater pipe down the wall of a yard, from a hopper under its coping
## to a shoe over the ground; `at` is its foot on the face of the wall.
func downpipe(at: Vector3, inwards: Vector3, height: float) -> void:
	var small := DETAIL | NO_COLLIDE
	var on_wall := _on_wall(at, inwards)
	var out := 0.1
	rod("galvanised", on_wall * Vector3(0, 0.25, out), on_wall * Vector3(0, height - 0.5, out), 0.055, small, 10)
	_box("galvanised", on_wall * Transform3D(Basis(), Vector3(0, height - 0.35, out)), Vector3(0.3, 0.3, 0.2), small)
	hose("galvanised", PackedVector3Array([on_wall * Vector3(0, 0.45, out), on_wall * Vector3(0, 0.25, out), on_wall * Vector3(0, 0.14, out + 0.06), on_wall * Vector3(0, 0.08, out + 0.2)]), 0.055, small, 10)
	var clips := maxi(2, roundi(height / 1.8))
	for i in clips:
		var y := 0.6 + (height - 1.4) * i / maxf(1.0, clips - 1.0)
		_local_box("dark_steel", on_wall, Vector3(0, y, out * 0.5), Vector3(0.16, 0.03, out), small)


## A column radiator under a window: `at` is the foot of the wall under its
## middle, and `sections` how many columns it has. It stands off the wall on
## its feet, with a valve and the two pipes that go down into the floor.
func radiator(at: Vector3, inwards: Vector3, sections := 12) -> void:
	var on_wall := _on_wall(at, inwards)
	var pitch := 0.062
	var wide := sections * pitch
	var high := 0.62
	for i in sections:
		rounded_box("machine_grey", on_wall * Transform3D(Basis(), Vector3(-wide * 0.5 + (i + 0.5) * pitch, 0.12 + high * 0.5, 0.14)), Vector3(pitch - 0.012, high, 0.15), 0.018, NO_COLLIDE)
	var small := DETAIL | NO_COLLIDE
	for end: float in [-1.0, 1.0]:
		_local_box("machine_grey", on_wall, Vector3(end * (wide * 0.5 - pitch * 0.5), 0.06, 0.14), Vector3(0.04, 0.12, 0.16), small)
		rod("pipe", on_wall * Vector3(end * (wide * 0.5 + 0.07), 0, 0.14), on_wall * Vector3(end * (wide * 0.5 + 0.07), 0.19 if end > 0.0 else 0.66, 0.14), 0.014, small, 6)
		rod("pipe", on_wall * Vector3(end * (wide * 0.5 + 0.07), 0.19 if end > 0.0 else 0.66, 0.14), on_wall * Vector3(end * wide * 0.5, 0.19 if end > 0.0 else 0.66, 0.14), 0.014, small, 6)
	rounded_box("brass", on_wall * Transform3D(Basis(), Vector3(-wide * 0.5 - 0.07, 0.7, 0.14)), Vector3(0.045, 0.07, 0.045), 0.012, small)
	_collide_box(on_wall * Transform3D(Basis(), Vector3(0, 0.4, 0.14)), Vector3(wide, 0.8, 0.18), "metal")
