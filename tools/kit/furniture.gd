extends "res://tools/kit/services.gd"
## Eighth drawer of the kit, see tools/kit.gd: what stands about in a room
## and is made in code rather than placed as a model. Furniture of steel and
## wood for offices, kitchens and workshops, and the tall things a robot can
## wait behind: screens of sheet steel, racks of plate, cases and cable
## drums. Each stands on the floor at `at` and faces `yaw_deg` (0 looks
## along +Z), and has one simple collider or a few.


## Row of `count` filing cabinets with four drawers each, centred on `at`.
## One drawer in a dozen was left a hand open.
func filing_cabinets(at: Vector3, yaw_deg: float, count: int, mat := "machine_grey") -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	var small := DETAIL | NO_COLLIDE
	var wide := 0.46
	var high := 1.32
	var deep := 0.62
	var drawer := (high - 0.08) / 4.0
	_collide_box(xf * Transform3D(Basis(), Vector3(0, high * 0.5, 0)), Vector3(count * wide, high, deep), "metal")
	for i in count:
		var x := (i - (count - 1) * 0.5) * wide
		_local_box(mat, xf, Vector3(x, high * 0.5, -0.012), Vector3(wide - 0.006, high, deep - 0.024), NO_COLLIDE)
		for d in 4:
			var y := 0.06 + (d + 0.5) * drawer
			var out := deep * 0.5 - 0.012 + (_prop_rng.randf_range(0.04, 0.16) if _prop_rng.randf() < 0.08 else 0.0)
			rounded_box(mat, xf * Transform3D(Basis(), Vector3(x, y, out)), Vector3(wide - 0.03, drawer - 0.02, 0.022), 0.006, NO_COLLIDE)
			_local_box("bare_steel", xf, Vector3(x, y + 0.045, out + 0.02), Vector3(0.13, 0.018, 0.016), small)
			_local_box("paper", xf, Vector3(x, y - 0.03, out + 0.012), Vector3(0.075, 0.035, 0.003), small)


## A counter `length` long: a closed body on a recessed plinth under a top
## that overhangs it. With `open_back` the body is a front and two ends, for
## somebody to stand behind: the desk of a lodge, the hatch of a canteen.
func counter(at: Vector3, yaw_deg: float, length: float, top := "wood", body := "machine_grey", high := 1.0, deep := 0.7, open_back := false) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	var small := DETAIL | NO_COLLIDE
	_collide_box(xf * Transform3D(Basis(), Vector3(0, high * 0.5, 0)), Vector3(length, high, deep), _surface(body))
	if open_back:
		_local_box(body, xf, Vector3(0, 0.1 + (high - 0.14) * 0.5, deep * 0.5 - 0.05), Vector3(length - 0.04, high - 0.14, 0.04), NO_COLLIDE)
		for end: float in [-1.0, 1.0]:
			_local_box(body, xf, Vector3(end * (length * 0.5 - 0.04), 0.1 + (high - 0.14) * 0.5, 0), Vector3(0.04, high - 0.14, deep - 0.06), NO_COLLIDE)
		_local_box(body, xf, Vector3(0, 0.55, -0.02), Vector3(length - 0.1, 0.03, deep - 0.14), NO_COLLIDE)
	else:
		_local_box(body, xf, Vector3(0, 0.1 + (high - 0.14) * 0.5, 0), Vector3(length - 0.04, high - 0.14, deep - 0.06), NO_COLLIDE)
	_local_box("dark_steel", xf, Vector3(0, 0.05, -0.03), Vector3(length - 0.12, 0.1, deep - 0.16), NO_COLLIDE)
	rounded_box(top, xf * Transform3D(Basis(), Vector3(0, high - 0.02, 0)), Vector3(length + 0.04, 0.04, deep + 0.04), 0.008, NO_COLLIDE)
	# The seams between its doors, and a pull on each.
	var doors := maxi(1, roundi(length / 0.6))
	for i in range(1, doors):
		_local_box("rubber", xf, Vector3(-length * 0.5 + length * i / doors, 0.1 + (high - 0.14) * 0.5, deep * 0.5 - 0.029), Vector3(0.006, high - 0.2, 0.004), small)
	for i in doors:
		_local_box("bare_steel", xf, Vector3(-length * 0.5 + length * (i + 0.5) / doors, high - 0.22, deep * 0.5 - 0.018), Vector3(0.1, 0.016, 0.02), small)


## A table on a steel frame: `size` is its length, its height and its depth.
func table(at: Vector3, yaw_deg: float, size := Vector3(1.8, 0.76, 0.8), top := "wood") -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	_collide_box(xf * Transform3D(Basis(), Vector3(0, size.y * 0.5, 0)), size, _surface(top))
	rounded_box(top, xf * Transform3D(Basis(), Vector3(0, size.y - 0.02, 0)), Vector3(size.x, 0.04, size.z), 0.008, NO_COLLIDE)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_local_box("dark_steel", xf, Vector3(sx * (size.x * 0.5 - 0.07), (size.y - 0.04) * 0.5, sz * (size.z * 0.5 - 0.07)), Vector3(0.04, size.y - 0.04, 0.04), NO_COLLIDE)
		_local_box("dark_steel", xf, Vector3(sx * (size.x * 0.5 - 0.07), size.y - 0.08, 0), Vector3(0.03, 0.06, size.z - 0.18), DETAIL | NO_COLLIDE)
	for sz: float in [-1.0, 1.0]:
		_local_box("dark_steel", xf, Vector3(0, size.y - 0.08, sz * (size.z * 0.5 - 0.07)), Vector3(size.x - 0.18, 0.06, 0.03), DETAIL | NO_COLLIDE)


## A fitter's bench that stands free: a thick wooden top on a steel frame
## with a shelf under it, a vice at one end and what was last worked with.
func bench(at: Vector3, yaw_deg: float, length := 2.2) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	var high := 0.9
	var deep := 0.78
	_collide_box(xf * Transform3D(Basis(), Vector3(0, high * 0.5, 0)), Vector3(length, high, deep), "wood")
	rounded_box("wood", xf * Transform3D(Basis(), Vector3(0, high - 0.035, 0)), Vector3(length, 0.07, deep), 0.008, NO_COLLIDE)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_local_box("steel", xf, Vector3(sx * (length * 0.5 - 0.1), (high - 0.07) * 0.5, sz * (deep * 0.5 - 0.08)), Vector3(0.06, high - 0.07, 0.06), NO_COLLIDE)
	_local_box("steel", xf, Vector3(0, high - 0.11, deep * 0.5 - 0.08), Vector3(length - 0.26, 0.08, 0.04), DETAIL | NO_COLLIDE)
	_local_box("steel", xf, Vector3(0, high - 0.11, -deep * 0.5 + 0.08), Vector3(length - 0.26, 0.08, 0.04), DETAIL | NO_COLLIDE)
	_local_box("deck", xf, Vector3(0, 0.22, 0), Vector3(length - 0.2, 0.02, deep - 0.16), NO_COLLIDE)
	# The vice is bolted on at the left, a few tools lie about on the rest.
	# Its handle hangs 9 cm below its foot, so it sits at the edge.
	prop("bench_vice_01", xf * Transform3D(Basis(), Vector3(-length * 0.5 + 0.35, high - 0.09, deep * 0.5 - 0.145)), 1.0, true)
	var tools: Array[String] = ["cross_pein_hammer", "adjustable_wrench", "screwdrivers_02", "measuring_tape_01"]
	for i in tools.size():
		if _clutter_rng.randf() < 0.3:
			continue
		var where := xf * Vector3(-length * 0.5 + 0.8 + (length - 1.1) * i / tools.size(), high, _clutter_rng.randf_range(-0.2, 0.2))
		var flat := Basis(Vector3.RIGHT, -PI * 0.5) if tools[i] in ["cross_pein_hammer", "adjustable_wrench"] else Basis()
		drop(tools[i], where, yaw_deg + _clutter_rng.randf_range(0.0, 360.0), flat)
	if _clutter_rng.randf() < 0.6:
		place("metal_toolbox", xf * Vector3(length * 0.5 - 0.5, 0.23, 0), yaw_deg + _clutter_rng.randf_range(-12.0, 12.0))
	if _clutter_rng.randf() < 0.7:
		place("metal_stool_03", xf * Vector3(_clutter_rng.randf_range(-0.4, 0.5), 0, deep * 0.5 + 0.45), yaw_deg + 180.0 + _clutter_rng.randf_range(-30.0, 30.0))


## Open shelving of angle iron with what an archive or a store keeps on it:
## boxes of files, and here and there a row of binders. `length` long and
## `high` high; with a `back` of sheet steel nobody sees through it.
func shelving(at: Vector3, yaw_deg: float, length := 2.0, high := 2.1, back := false) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	var small := DETAIL | NO_COLLIDE
	var deep := 0.45
	_collide_box(xf * Transform3D(Basis(), Vector3(0, high * 0.5, 0)), Vector3(length, high, deep), "metal")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_local_box("galvanised", xf, Vector3(sx * (length * 0.5 - 0.02), high * 0.5, sz * (deep * 0.5 - 0.02)), Vector3(0.04, high, 0.04), small)
	if back:
		_local_box("galvanised", xf, Vector3(0, high * 0.5, -deep * 0.5 + 0.006), Vector3(length - 0.04, high - 0.1, 0.012), NO_COLLIDE)
	var shelves := maxi(3, roundi(high / 0.45))
	var binders: Array[String] = ["machine_blue", "enamel_red", "machine", "machine_grey"]
	for s in shelves:
		var y := 0.12 + (high - 0.2) * s / shelves
		_local_box("galvanised", xf, Vector3(0, y, 0), Vector3(length - 0.02, 0.022, deep), NO_COLLIDE)
		var room := (high - 0.2) / shelves - 0.05
		var x := -length * 0.5 + 0.06
		while x < length * 0.5 - 0.36:
			var kind := _clutter_rng.randf()
			if kind < 0.2:
				# A gap where something was taken out.
				x += _clutter_rng.randf_range(0.15, 0.4)
			elif kind < 0.75 and room > 0.26:
				var size := Vector3(_clutter_rng.randf_range(0.26, 0.34), minf(room, _clutter_rng.randf_range(0.24, 0.3)), deep - _clutter_rng.randf_range(0.05, 0.1))
				_box("paper", xf * Transform3D(Basis(Vector3.UP, deg_to_rad(_clutter_rng.randf_range(-4.0, 4.0))), Vector3(x + size.x * 0.5, y + 0.011 + size.y * 0.5, 0)), size, NO_COLLIDE)
				_local_box("machine_grey", xf, Vector3(x + size.x * 0.5, y + 0.011 + size.y * 0.5, size.z * 0.5 + 0.001), Vector3(size.x * 0.6, 0.06, 0.002), small)
				x += size.x + 0.02
			else:
				var count := _clutter_rng.randi_range(3, 6)
				var tall := minf(room, 0.31)
				var colour := binders[_clutter_rng.randi_range(0, binders.size() - 1)]
				for b in count:
					_local_box(colour, xf, Vector3(x + 0.035 + b * 0.072, y + 0.011 + tall * 0.5, 0.03), Vector3(0.066, tall, 0.28), small)
				x += count * 0.072 + 0.03


## Changing-room bench: slats on a steel frame, `length` long, with a rail
## of hooks over it when it stands against a wall (`hooks`).
func slat_bench(at: Vector3, yaw_deg: float, length := 1.8, hooks := false) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	var small := DETAIL | NO_COLLIDE
	_collide_box(xf * Transform3D(Basis(), Vector3(0, 0.23, 0)), Vector3(length, 0.46, 0.36), "wood")
	for i in 3:
		_local_box("wood", xf, Vector3(0, 0.44, (i - 1) * 0.115), Vector3(length, 0.035, 0.095), NO_COLLIDE)
	var frames := maxi(2, roundi(length / 0.9))
	for i in frames:
		var x := -length * 0.5 + 0.12 + (length - 0.24) * i / maxf(1.0, frames - 1.0)
		for sz: float in [-1.0, 1.0]:
			_local_box("dark_steel", xf, Vector3(x, 0.21, sz * 0.14), Vector3(0.03, 0.42, 0.03), small)
		_local_box("dark_steel", xf, Vector3(x, 0.41, 0), Vector3(0.03, 0.03, 0.31), small)
	if hooks:
		_local_box("wood", xf, Vector3(0, 1.7, -0.165), Vector3(length, 0.09, 0.02), small)
		var count := maxi(2, roundi(length / 0.3))
		for i in count:
			var x := -length * 0.5 + length * (i + 0.5) / count
			rod("bare_steel", xf * Vector3(x, 1.7, -0.155), xf * Vector3(x, 1.68, -0.09), 0.006, small, 5)


## A sink of galvanised steel on legs, `length` long, against a wall behind
## it: a trough, a splashback, a tap every 60 cm and the waste down to the
## floor.
func wash_trough(at: Vector3, yaw_deg: float, length := 1.8) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	var small := DETAIL | NO_COLLIDE
	_collide_box(xf * Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(length, 0.9, 0.5), "metal")
	rounded_box("galvanised", xf * Transform3D(Basis(), Vector3(0, 0.76, 0)), Vector3(length, 0.26, 0.5), 0.02, NO_COLLIDE)
	_local_box("rubber", xf, Vector3(0, 0.891, 0.01), Vector3(length - 0.08, 0.002, 0.4), small)
	_local_box("galvanised", xf, Vector3(0, 1.1, -0.24), Vector3(length, 0.42, 0.012), NO_COLLIDE)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_local_box("galvanised", xf, Vector3(sx * (length * 0.5 - 0.06), 0.315, sz * 0.19), Vector3(0.04, 0.63, 0.04), small)
	var taps := maxi(1, roundi(length / 0.6))
	for i in taps:
		var x := -length * 0.5 + length * (i + 0.5) / taps
		hose("brass", PackedVector3Array([xf * Vector3(x, 1.12, -0.23), xf * Vector3(x, 1.12, -0.14), xf * Vector3(x, 1.08, -0.1), xf * Vector3(x, 1.0, -0.1)]), 0.011, small, 6)
		_local_box("brass", xf, Vector3(x, 1.16, -0.2), Vector3(0.06, 0.012, 0.012), small)
	rod("pipe", xf * Vector3(0, 0.63, 0), xf * Vector3(0, 0.0, 0), 0.03, small, 8)
	rod("pipe", xf * Vector3(-length * 0.5 + 0.1, 1.2, -0.22), xf * Vector3(length * 0.5 - 0.1, 1.2, -0.22), 0.012, small, 6)


## The range of a works kitchen: an oven on either side under six plates, a
## rail along its front, and over it a hood whose duct goes up through the
## ceiling at `ceiling`.
func kitchen_range(at: Vector3, yaw_deg: float, ceiling: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	var small := DETAIL | NO_COLLIDE
	var wide := 1.8
	var deep := 0.85
	_collide_box(xf * Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(wide, 0.9, deep), "metal")
	_local_box("machine_grey", xf, Vector3(0, 0.47, 0), Vector3(wide, 0.78, deep - 0.04), NO_COLLIDE)
	_local_box("dark_steel", xf, Vector3(0, 0.04, -0.03), Vector3(wide - 0.1, 0.08, deep - 0.14), NO_COLLIDE)
	rounded_box("dark_steel", xf * Transform3D(Basis(), Vector3(0, 0.88, 0)), Vector3(wide + 0.02, 0.04, deep), 0.01, NO_COLLIDE)
	for i in 6:
		cylinder("steel", xf * Vector3((i % 3 - 1) * 0.55, 0.9, floorf(i / 3.0) * 0.36 - 0.18), 0.13, 0.012, small, Vector3.ZERO, -1.0, 14)
	for side: float in [-1.0, 1.0]:
		rounded_box("dark_steel", xf * Transform3D(Basis(), Vector3(side * 0.45, 0.42, deep * 0.5 - 0.015)), Vector3(0.78, 0.5, 0.03), 0.012, NO_COLLIDE)
		rod("bare_steel", xf * Vector3(side * 0.45 - 0.3, 0.62, deep * 0.5 + 0.035), xf * Vector3(side * 0.45 + 0.3, 0.62, deep * 0.5 + 0.035), 0.012, small, 6)
	rod("bare_steel", xf * Vector3(-wide * 0.5 + 0.05, 0.8, deep * 0.5 + 0.05), xf * Vector3(wide * 0.5 - 0.05, 0.8, deep * 0.5 + 0.05), 0.014, small, 6)
	# The hood: a skirt of sheet steel that narrows to its duct.
	var skirt := Vector3(wide + 0.3, 0.3, deep + 0.25)
	_local_box("galvanised", xf, Vector3(0, 2.05, 0.05), skirt, NO_COLLIDE)
	_local_box("galvanised", xf, Vector3(0, 2.38, 0.0), Vector3(wide * 0.6, 0.36, deep * 0.7), NO_COLLIDE)
	if ceiling > 2.6:
		_local_box("galvanised", xf, Vector3(0, (2.56 + ceiling) * 0.5, -0.05), Vector3(0.45, ceiling - 2.56, 0.4), NO_COLLIDE)
	_local_box("rubber", xf, Vector3(0, 1.898, 0.05), Vector3(skirt.x - 0.08, 0.004, skirt.z - 0.08), small)


## Screens of sheet steel on feet, as stand around a welder: `panels` of
## them, 1.25 m each and 2 m high, hinged to each other in a zigzag.
func screens(at: Vector3, yaw_deg: float, panels := 3, mat := "machine") -> void:
	var small := DETAIL | NO_COLLIDE
	var turn := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var wide := 1.25
	var high := 2.0
	var fold := deg_to_rad(12.0)
	var hinge := Vector3(-panels * wide * cos(fold) * 0.5, 0, 0)
	for i in panels:
		var swing := fold if i % 2 == 0 else -fold
		var along := Vector3(cos(swing), 0, sin(swing))
		var xf := Transform3D(turn * Basis(Vector3.UP, -swing), at + turn * (hinge + along * wide * 0.5))
		_collide_box(xf * Transform3D(Basis(), Vector3(0, high * 0.5, 0)), Vector3(wide, high, 0.06), "metal")
		_local_box(mat, xf, Vector3(0, 0.2 + (high - 0.25) * 0.5, 0), Vector3(wide - 0.08, high - 0.25, 0.008), NO_COLLIDE)
		for side: float in [-1.0, 1.0]:
			_local_box("dark_steel", xf, Vector3(side * (wide * 0.5 - 0.02), high * 0.5, 0), Vector3(0.04, high, 0.04), small)
			_local_box("dark_steel", xf, Vector3(side * (wide * 0.5 - 0.02), 0.02, 0), Vector3(0.05, 0.04, 0.55), small)
		for y: float in [0.18, high - 0.02]:
			_local_box("dark_steel", xf, Vector3(0, y, 0), Vector3(wide - 0.08, 0.04, 0.04), small)
		hinge += along * wide


## A rack of steel plate: sheets on edge, leaning against an A-frame from
## both sides, 3 m long and 2 m high.
func plate_rack(at: Vector3, yaw_deg: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	var small := DETAIL | NO_COLLIDE
	var long := 3.0
	var high := 2.0
	_collide_box(xf * Transform3D(Basis(), Vector3(0, high * 0.5, 0)), Vector3(long + 0.2, high, 1.1), "metal")
	for x: float in [-1.2, 0.0, 1.2]:
		_local_box("steel", xf, Vector3(x, 0.05, 0), Vector3(0.1, 0.1, 1.2), NO_COLLIDE)
		for side: float in [-1.0, 1.0]:
			beam("steel", xf * Vector3(x, 0.1, side * 0.42), xf * Vector3(x, high, side * 0.04), 0.08, small)
	_local_box("steel", xf, Vector3(0, high - 0.04, 0), Vector3(2.6, 0.08, 0.08), small)
	var sheets: Array[String] = ["bare_steel", "steel", "galvanised", "dark_steel"]
	for side: float in [-1.0, 1.0]:
		var count := _prop_rng.randi_range(3, 5)
		for i in count:
			var size := Vector2(long - _prop_rng.randf_range(0.0, 0.7), high - 0.25 - _prop_rng.randf_range(0.0, 0.5))
			var lean := Basis(Vector3.RIGHT, -side * deg_to_rad(10.5))
			var foot := Vector3(_prop_rng.randf_range(-0.12, 0.12), 0.1, side * (0.46 + i * 0.03))
			_box(sheets[_prop_rng.randi_range(0, sheets.size() - 1)], xf * Transform3D(lean, foot) * Transform3D(Basis(), Vector3(0, size.y * 0.5, 0)), Vector3(size.x, size.y, 0.016), NO_COLLIDE)


## A cable drum on its rim, chocked: two flanges of boards on a barrel, with
## what cable is left on it. `yaw_deg` is the way its side faces.
func cable_drum(at: Vector3, yaw_deg: float, diameter := 2.0, wide := 1.1) -> void:
	var turn := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var small := DETAIL | NO_COLLIDE
	var radius := diameter * 0.5
	var axle := at + Vector3(0, radius, 0)
	var axis := turn * Vector3.BACK
	_collide_cylinder(Transform3D(_up_along(axis), axle), radius, wide, "wood")
	for side: float in [-1.0, 1.0]:
		var face := axle + axis * side * (wide * 0.5 - 0.04)
		rod("wood", face - axis * 0.04, face + axis * 0.04, radius, NO_COLLIDE, 24)
		rod("dark_steel", face + axis * side * 0.04, face + axis * side * 0.055, radius * 0.22, small, 12)
		_m = Transform3D()
		_part = small
		_bolt_circle(face + axis * side * 0.04, axis * side, radius * 0.62, 6)
	_part = NO_COLLIDE
	rod("wood", axle - axis * (wide * 0.5 - 0.08), axle + axis * (wide * 0.5 - 0.08), radius * 0.42, NO_COLLIDE, 16)
	var wound := _prop_rng.randf_range(0.5, 0.82)
	rod("rubber", axle - axis * (wide * 0.5 - 0.09), axle + axis * (wide * 0.5 - 0.09), radius * wound, NO_COLLIDE, 20)
	var along := turn * Vector3.RIGHT
	for side: float in [-1.0, 1.0]:
		for end: float in [-1.0, 1.0]:
			_box("wood", Transform3D(turn * Basis(Vector3.BACK, end * deg_to_rad(-24.0)), at + along * end * (radius * 0.52) + axis * side * (wide * 0.5 - 0.04) + Vector3(0, 0.07, 0)), Vector3(0.36, 0.1, 0.12), small)


## A packing case of boards: a box with a frame of battens on every side
## and a brace across the two long ones, on skids. `size` is its length, its
## height and its depth.
func case(at: Vector3, yaw_deg: float, size: Vector3) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	_collide_box(xf * Transform3D(Basis(), Vector3(0, size.y * 0.5, 0)), size, "wood")
	var skid := 0.09
	var body := Vector3(size.x - 0.05, size.y - skid, size.z - 0.05)
	_local_box("wood", xf, Vector3(0, skid + body.y * 0.5, 0), body, NO_COLLIDE)
	for z: float in [-size.z * 0.5 + 0.12, size.z * 0.5 - 0.12]:
		_local_box("wood", xf, Vector3(0, skid * 0.5, z), Vector3(size.x, skid, 0.1), NO_COLLIDE)
	var batten := 0.09
	for face in 4:
		# The four sides in turn, each with its own width.
		var side := xf * Transform3D(Basis(Vector3.UP, face * PI * 0.5), Vector3(0, skid + body.y * 0.5, 0))
		var wide := body.x if face % 2 == 0 else body.z
		var out := (body.z if face % 2 == 0 else body.x) * 0.5 + 0.0125
		for edge: float in [-1.0, 1.0]:
			_local_box("wood", side, Vector3(edge * (wide * 0.5 - batten * 0.5), 0, out), Vector3(batten, body.y, 0.025), NO_COLLIDE)
			_local_box("wood", side, Vector3(0, edge * (body.y * 0.5 - batten * 0.5), out), Vector3(wide - batten * 2.0, batten, 0.025), NO_COLLIDE)
		if face % 2 == 0:
			var brace := Vector2(wide - batten * 2.0, body.y - batten * 2.0)
			_box("wood", side * Transform3D(Basis(Vector3.BACK, atan2(brace.y, brace.x) * (1.0 if face == 0 else -1.0)), Vector3(0, 0, out)), Vector3(brace.length() - 0.04, batten, 0.024), NO_COLLIDE)


## Packing cases stacked two high in a row `length` long, as bricks are
## laid: the lower ones side by side with nothing between them, the upper
## ones over where those meet. Something a robot can wait behind without
## being seen through it.
func cases(at: Vector3, yaw_deg: float, length := 3.7) -> void:
	var turn := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var count := maxi(2, roundi(length / 1.25))
	var each := length / count
	var high := _prop_rng.randf_range(1.0, 1.15)
	for i in count:
		case(at + turn * Vector3((i - (count - 1) * 0.5) * each, 0, 0), yaw_deg, Vector3(each, high, _prop_rng.randf_range(0.95, 1.05)))
	var over := (length - each) / (count - 1)
	for i in count - 1:
		case(at + turn * Vector3((i - (count - 2) * 0.5) * over, high, _prop_rng.randf_range(-0.04, 0.04)), yaw_deg, Vector3(over, _prop_rng.randf_range(0.9, 1.0), _prop_rng.randf_range(0.85, 0.95)))


## A spray booth of sheet steel, open at the front: three walls and a roof,
## a wall of filters at the back and a duct from the roof up through the
## ceiling at `ceiling`, with what was last sprayed on trestles inside.
## Without `work` it stands empty, for somebody to wait in.
func spray_booth(at: Vector3, yaw_deg: float, ceiling: float, work := true) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	var small := DETAIL | NO_COLLIDE
	var wide := 3.4
	var high := 2.5
	var deep := 2.2
	_local_box("galvanised", xf, Vector3(0, high * 0.5, -deep * 0.5 + 0.02), Vector3(wide, high, 0.04))
	for side: float in [-1.0, 1.0]:
		_local_box("galvanised", xf, Vector3(side * (wide * 0.5 - 0.02), high * 0.5, 0), Vector3(0.04, high, deep))
	_local_box("galvanised", xf, Vector3(0, high + 0.02, 0), Vector3(wide, 0.04, deep), NO_COLLIDE)
	# The filters: squares of matting in a grid, grey with what they caught.
	for i in 5:
		for j in 3:
			_local_box("rubber" if (i + j) % 3 else "machine_grey", xf, Vector3((i - 2) * 0.62, 0.5 + j * 0.62, -deep * 0.5 + 0.05), Vector3(0.56, 0.56, 0.03), small)
	if ceiling > high + 0.3:
		_local_box("galvanised", xf, Vector3(0, (high + ceiling) * 0.5, -deep * 0.5 + 0.4), Vector3(0.6, ceiling - high, 0.6), NO_COLLIDE)
	# A strip light under its roof, long dead, and outside its back wall the
	# stiffeners of the sheet and the fan that draws the air through.
	_local_box("steel", xf, Vector3(0, high - 0.04, 0.3), Vector3(1.3, 0.06, 0.16), small)
	_local_box("plaster", xf, Vector3(0, high - 0.08, 0.3), Vector3(1.2, 0.03, 0.05), small)
	for x: float in [-1.1, 0.0, 1.1]:
		_local_box("galvanised", xf, Vector3(x, high * 0.5, -deep * 0.5 - 0.02), Vector3(0.06, high, 0.04), small)
	_local_box("machine_grey", xf, Vector3(0.55, 1.7, -deep * 0.5 - 0.2), Vector3(0.9, 0.9, 0.4), NO_COLLIDE)
	_m = xf
	_part = small
	_motor(BLUE, Vector3(0.55, 1.7, -deep * 0.5 - 0.4), Vector3.FORWARD, 0.14, 0.34, false)
	_part = NO_COLLIDE
	floor_decal("stain_2", xf * Vector3(0, 0, 0.6), Vector2(3.0, 2.4), yaw_deg)
	if not work:
		return
	# Two trestles with a panel across them, half sprayed.
	for x: float in [-0.7, 0.7]:
		_local_box("steel", xf, Vector3(x, 0.78, 0.1), Vector3(0.06, 0.06, 1.0), small)
		for z: float in [-0.3, 0.5]:
			beam("steel", xf * Vector3(x - 0.22, 0, z), xf * Vector3(x, 0.78, z), 0.04, small)
			beam("steel", xf * Vector3(x + 0.22, 0, z), xf * Vector3(x, 0.78, z), 0.04, small)
	_local_box("container_orange", xf, Vector3(0, 0.83, 0.1), Vector3(1.9, 0.03, 0.9), NO_COLLIDE)


## A pile of the same crate or tote, `count` high, standing on the floor.
func pile(model: String, at: Vector3, yaw_deg: float, count: int) -> void:
	var facing := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var size: Vector3 = _model(model).box.size
	_stack(model, at, facing, count)
	_collide_box(Transform3D(facing, at + Vector3(0, size.y * count * 0.485, 0)), Vector3(size.x, size.y * count * 0.97, size.z), _model(model).surface)
