extends "res://tools/kit/fittings.gd"
## Fifth drawer of the kit, see tools/kit.gd: what makes electricity, switches
## it and sends it on its way.

# Materials of the electrical plant.
const GREY := "machine_grey"
const PORCELAIN := "porcelain"
const COPPER := "copper"


## Porcelain insulator that starts at `base` and runs along `axis`: a core
## with `sheds` skirts on it, between a metal cap at either end. The skirts
## shed the rain of one that stands up.
func _insulator(base: Vector3, axis: Vector3, length: float, radius: float, sheds: int) -> void:
	var along := axis.normalized()
	var cap := minf(0.07, length * 0.12)
	var core := radius * 0.42
	var pitch := (length - cap * 2.0) / sheds
	_bar(IRON, base, base + along * cap, core * 1.3, 10)
	var profile := PackedVector2Array([Vector2(core, 0)])
	for i in sheds:
		var y := pitch * i
		profile.append(Vector2(radius, y + pitch * 0.15))
		profile.append(Vector2(radius, y + pitch * 0.28))
		profile.append(Vector2(core, y + pitch * 0.9))
	profile.append(Vector2(core, pitch * sheds))
	_turned(PORCELAIN, base + along * cap, along, profile, 14)
	_bar(IRON, base + along * (length - cap), base + along * length, core * 1.3, 10)


## Oil-filled power transformer on its plinth: the tank with a bank of
## radiators along either long side, the conservator over the back of it and
## three bushings for the high voltage on the lid. `at` is the middle of the
## plinth and `yaw_deg` the way its front faces, one of the long sides (0
## looks along +Z); the conservator hangs over the other. `number` is
## stencilled on a plate on that front, if the manifest has it as a text. Returns where the tops of
## the three high-voltage bushings are, for what is connected to them.
func transformer(at: Vector3, yaw_deg: float, number := "") -> PackedVector3Array:
	_m = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	_part = NO_COLLIDE
	var w := 2.8
	var d := 1.5
	var foot := 0.52
	var h := 2.1
	var top := foot + h
	var fin_deep := 0.42
	_collide_box(_m * Transform3D(Basis(), Vector3(0, top * 0.5, 0)), Vector3(w + 0.1, top, d + (fin_deep + 0.14) * 2.0), "metal")
	_collide_box(_m * Transform3D(Basis(), Vector3(0, top + 0.72, -d * 0.5 + 0.1)), Vector3(2.3, 0.7, 0.7), "metal")

	# A slab with a kerb round it to catch the oil, a plinth in the middle of
	# that, and the two rails the tank was rolled in on.
	var pit := Vector2(w + 1.7, d + 2.7)
	_plate("concrete", Vector3(0, 0.03, 0), Vector3(pit.x, 0.06, pit.y))
	for sz: float in [-1.0, 1.0]:
		_plate("concrete", Vector3(0, 0.11, sz * (pit.y * 0.5 - 0.075)), Vector3(pit.x, 0.22, 0.15))
	for sx: float in [-1.0, 1.0]:
		_plate("concrete", Vector3(sx * (pit.x * 0.5 - 0.075), 0.11, 0), Vector3(0.15, 0.22, pit.y - 0.3))
	_plate("concrete", Vector3(0, 0.19, 0), Vector3(w - 0.2, 0.26, d + 0.9))
	for x: float in [-0.85, 0.85]:
		_i_beam(IRON, Vector3(x, 0.32, -d * 0.5 - 0.3), Vector3(x, 0.32, d * 0.5 + 0.3), 0.16, 0.2)

	# The tank: a skirt round its foot, the lid bolted down along its edges,
	# stiffeners up both ends.
	_block(GREY, Vector3(0, foot + h * 0.5, 0), Vector3(w, h, d), 0.05)
	_plate(GREY, Vector3(0, foot + 0.04, 0), Vector3(w + 0.1, 0.08, d + 0.1))
	_block(GREY, Vector3(0, top + 0.03, 0), Vector3(w + 0.14, 0.06, d + 0.14), 0.012)
	for i in 12:
		var x := -w * 0.5 + 0.1 + (w - 0.2) * i / 11.0
		for sz: float in [-1.0, 1.0]:
			_bolt(Vector3(x, top + 0.06, sz * (d * 0.5 + 0.03)), Vector3.UP)
	for sx: float in [-1.0, 1.0]:
		for z: float in [-0.5, 0.0, 0.5]:
			_plate(GREY, Vector3(sx * (w * 0.5 + 0.03), foot + h * 0.5, z), Vector3(0.06, h - 0.24, 0.05))

	# The radiators: a row of thin panels down either long side, between a
	# header above and one below, each joined to the tank by two flanged stubs.
	var fins := int((w - 0.5) / 0.1)
	var fin_high := h - 0.5
	for sz: float in [-1.0, 1.0]:
		var z := sz * (d * 0.5 + 0.14 + fin_deep * 0.5)
		_part = DETAIL | NO_COLLIDE
		for i in fins:
			_plate(GREY, Vector3((i - (fins - 1) * 0.5) * 0.1, foot + 0.28 + fin_high * 0.5, z), Vector3(0.022, fin_high, fin_deep))
		_part = NO_COLLIDE
		for y: float in [foot + 0.22, foot + 0.34 + fin_high]:
			_bar(GREY, Vector3(-w * 0.5 + 0.18, y, z), Vector3(w * 0.5 - 0.18, y, z), 0.055, 12)
			for x: float in [-0.8, 0.8]:
				_bar(GREY, Vector3(x, y, sz * d * 0.5), Vector3(x, y, z), 0.045, 10)
				_flange(GREY, Vector3(x, y, sz * (d * 0.5 + 0.07)), Vector3(0, 0, sz), 0.045)

	# The conservator on its two brackets, strapped down, with a gauge in one
	# end, the pipe to the lid with its relay, and the breather down the side.
	var cz := -d * 0.5 + 0.1
	var cy := top + 0.75
	var r := 0.3
	var long := 2.2
	_turned(GREY, Vector3(-long * 0.5, cy, cz), Vector3.RIGHT, PackedVector2Array([
		Vector2(0, 0), Vector2(r * 0.6, 0.02), Vector2(r * 0.92, 0.08), Vector2(r, 0.16),
		Vector2(r, long - 0.16), Vector2(r * 0.92, long - 0.08), Vector2(r * 0.6, long - 0.02), Vector2(0, long),
	]), 24, true)
	for x: float in [-0.7, 0.7]:
		var stand := cy - r - top
		_plate(GREY, Vector3(x, top + stand * 0.5 + 0.04, cz), Vector3(0.05, stand + 0.08, 0.34))
		_turned(BARE, Vector3(x - 0.02, cy, cz), Vector3.RIGHT, PackedVector2Array([
			Vector2(r, 0), Vector2(r + 0.008, 0), Vector2(r + 0.008, 0.04), Vector2(r, 0.04),
		]), 24)
	_turned(GREY, Vector3(0.3, cy + r - 0.02, cz), Vector3.UP, PackedVector2Array([
		Vector2(0.06, 0), Vector2(0.06, 0.08), Vector2(0.08, 0.08), Vector2(0.08, 0.11), Vector2(0, 0.11),
	]), 12)
	_gauge(Vector3(long * 0.5, cy, cz), Vector3.RIGHT, 0.1)
	_line(GREY, [Vector3(0.95, cy - r + 0.02, cz), Vector3(0.95, cy - r - 0.1, cz + 0.05), Vector3(0.95, top + 0.3, cz + 0.4), Vector3(0.95, top + 0.04, cz + 0.45)], 0.03)
	_block(IRON, Vector3(0.95, top + 0.33, cz + 0.33), Vector3(0.14, 0.14, 0.16), 0.02)
	_line(BARE, [Vector3(-0.95, cy - r + 0.02, cz), Vector3(-1.2, cy - r - 0.12, cz), Vector3(-w * 0.5 - 0.1, top - 0.1, cz), Vector3(-w * 0.5 - 0.1, foot + 1.25, cz)], 0.012, 6)
	_bar(BRASS, Vector3(-w * 0.5 - 0.1, foot + 1.0, cz), Vector3(-w * 0.5 - 0.1, foot + 1.25, cz), 0.05, 10)

	# The bushings: three tall ones for the high voltage, each leaning away
	# from the next, and four short ones for the low.
	var tips := PackedVector3Array()
	for i in 3:
		var axis := Vector3((i - 1) * 0.22, 1.0, 0.12).normalized()
		var seat := Vector3((i - 1) * 0.8, top + 0.06, 0.12)
		_bar(GREY, seat, seat + axis * 0.2, 0.14, 14)
		_insulator(seat + axis * 0.2, axis, 0.95, 0.13, 7)
		var tip := seat + axis * 1.15
		_bar(BARE, tip, tip + axis * 0.12, 0.018, 8)
		_block(BARE, tip + axis * 0.14, Vector3(0.08, 0.05, 0.08), 0.01)
		tips.append(_m * (tip + axis * 0.14))
	for i in 4:
		var seat := Vector3((i - 1.5) * 0.45, top + 0.06, 0.56)
		_insulator(seat, Vector3.UP, 0.34, 0.07, 3)
		_bar(COPPER, seat + Vector3(0, 0.34, 0), seat + Vector3(0, 0.42, 0), 0.012, 8)

	# On one end: the cabinet of the tap changer with its cable, a thermometer,
	# the maker's plate and the drain valve.
	var end := w * 0.5 + 0.06
	_block(GREY, Vector3(end + 0.14, foot + 1.05, -0.25), Vector3(0.28, 0.8, 0.6), 0.02)
	_louvred_door(GREY, Vector3(end + 0.28, foot + 1.05, -0.25), Vector3.RIGHT, Vector2(0.52, 0.72))
	_bar(RUBBER, Vector3(end + 0.14, foot + 0.66, -0.25), Vector3(end + 0.14, 0.2, -0.25), 0.03, 8)
	_gauge(Vector3(end, foot + 1.62, 0.25), Vector3.RIGHT, 0.09)
	_block(BRASS, Vector3(end + 0.004, foot + 1.2, 0.25), Vector3(0.008, 0.2, 0.3), 0.003)
	_bar(GREY, Vector3(w * 0.5, foot + 0.2, 0.25), Vector3(end + 0.12, foot + 0.2, 0.25), 0.04)
	_block(IRON, Vector3(end + 0.16, foot + 0.2, 0.25), Vector3(0.14, 0.14, 0.14), 0.03)
	_handwheel(Vector3(end + 0.16, foot + 0.36, 0.25), Vector3.UP, 0.08)
	# Lifting lugs on the corners of the lid.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_block(GREY, Vector3(sx * (w * 0.5 - 0.12), top + 0.12, sz * (d * 0.5 - 0.1)), Vector3(0.04, 0.14, 0.12), 0.015)

	# Its number, on a plate that hangs from the upper header at the front.
	if number != "":
		var plate := Vector3(-w * 0.5 + 0.6, top - 0.46, d * 0.5 + 0.14 + fin_deep + 0.03)
		_block(YELLOW, plate, Vector3(0.74, 0.52, 0.02), 0.006)
		label(number, _m * (plate + Vector3(0, 0, 0.011)), _m.basis * Vector3.BACK, 0.38, Color(0.03, 0.03, 0.03), 0.02)
	floor_decal("stain_2", _m * Vector3(0.5, 0, d * 0.5 + 0.5), Vector2(2.4, 1.6), yaw_deg + 15.0)
	return tips


## Lattice mast of four angle legs braced on every side, on a concrete foot
## at `foot`: what a substation hangs its lines from.
func lattice_mast(foot: Vector3, height: float, width := 0.6) -> void:
	var flags := DETAIL | NO_COLLIDE
	var half := width * 0.5
	box("concrete", foot + Vector3(0, 0.15, 0), Vector3(width + 0.5, 0.3, width + 0.5))
	var corners: Array[Vector3] = [Vector3(-half, 0, -half), Vector3(half, 0, -half), Vector3(half, 0, half), Vector3(-half, 0, half)]
	for corner in corners:
		beam("galvanised", foot + corner + Vector3(0, 0.3, 0), foot + corner + Vector3(0, height, 0), 0.07, flags)
	var panels := maxi(1, roundi((height - 0.3) / (width * 1.25)))
	var rise := (height - 0.3) / panels
	for i in panels:
		var low := Vector3(0, 0.3 + rise * i, 0)
		var high := low + Vector3(0, rise, 0)
		for side in 4:
			var a := corners[side]
			var b := corners[(side + 1) % 4]
			if i % 2 == 0:
				beam("galvanised", foot + a + low, foot + b + high, 0.04, flags)
			else:
				beam("galvanised", foot + b + low, foot + a + high, 0.04, flags)
			beam("galvanised", foot + a + high, foot + b + high, 0.04, flags)
	_collide_box(Transform3D(Basis(), foot + Vector3(0, height * 0.5, 0)), Vector3(width, height, width), "metal")


## Lattice girder between two points at the same height, `depth` square,
## braced like the masts it lies on.
func lattice_girder(from: Vector3, to: Vector3, depth := 0.6) -> void:
	var flags := DETAIL | NO_COLLIDE
	var along := (to - from).normalized()
	var across := Vector3.UP.cross(along) * depth * 0.5
	var up := Vector3.UP * depth * 0.5
	var corners: Array[Vector3] = [-across - up, across - up, across + up, -across + up]
	for corner in corners:
		beam("galvanised", from + corner, to + corner, 0.06, flags)
	var panels := maxi(1, roundi(from.distance_to(to) / depth))
	var step := (to - from) / panels
	for i in panels:
		var start := from + step * i
		for side in 4:
			var a := corners[side]
			var b := corners[(side + 1) % 4]
			if i % 2 == 0:
				beam("galvanised", start + a, start + step + b, 0.035, flags)
			else:
				beam("galvanised", start + b, start + step + a, 0.035, flags)


## Bare conductor hanging between two points, `sag` lower in the middle.
func wire(from: Vector3, to: Vector3, sag: float, radius := 0.014) -> void:
	var points := PackedVector3Array()
	for i in 7:
		var t := i / 6.0
		points.append(from.lerp(to, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	hose(BARE, points, radius, DETAIL | NO_COLLIDE, 6)


## String of insulators hanging from `top`, with a clamp at its lower end.
## Returns where the conductor passes through the clamp.
func insulator_string(top: Vector3, length := 0.9) -> Vector3:
	_m = Transform3D()
	_part = DETAIL | NO_COLLIDE
	var low := top + Vector3.DOWN * length
	_bar(IRON, top, top + Vector3.DOWN * 0.08, 0.012, 6)
	_insulator(low + Vector3.UP * 0.06, Vector3.UP, length - 0.14, 0.11, 6)
	_block(BARE, low, Vector3(0.07, 0.07, 0.16), 0.015)
	_part = NO_COLLIDE
	return low


## Insulator standing out from a wall at `at`, whose face looks along `out`:
## what a conductor is led off a building on. Returns its outer end.
func wall_insulator(at: Vector3, out: Vector3, length := 0.7) -> Vector3:
	_m = Transform3D()
	_part = DETAIL | NO_COLLIDE
	_block(IRON, at + out * 0.015, Vector3(0.26, 0.26, 0.03) if absf(out.z) > 0.5 else Vector3(0.03, 0.26, 0.26), 0.008)
	_insulator(at + out * 0.03, out, length, 0.1, 5)
	var tip := at + out * (length + 0.06)
	_block(BARE, tip, Vector3(0.07, 0.07, 0.07), 0.015)
	_part = NO_COLLIDE
	return tip


## Cable ladder between two points at the same height, hung from a ceiling
## at `ceiling_y`, with `cables` cables lying in it.
func cable_ladder(from: Vector3, to: Vector3, ceiling_y: float, cables := 5, width := 0.4) -> void:
	var flags := DETAIL | NO_COLLIDE
	var along := (to - from).normalized()
	var across := Vector3.UP.cross(along)
	var length := from.distance_to(to)
	for side: float in [-1.0, 1.0]:
		beam("galvanised", from + across * side * width * 0.5, to + across * side * width * 0.5, 0.025, flags, 0.07)
	var rungs := maxi(2, roundi(length / 0.3))
	for i in rungs + 1:
		var rung := from.lerp(to, float(i) / rungs)
		beam("galvanised", rung - across * width * 0.5, rung + across * width * 0.5, 0.025, flags, 0.018)
	var hangers := maxi(1, roundi(length / 2.4))
	for i in hangers:
		var hung := from.lerp(to, (i + 0.5) / hangers)
		for side: float in [-1.0, 1.0]:
			var foot := hung + across * side * (width * 0.5 + 0.02)
			rod(IRON, foot + Vector3(0, -0.03, 0), Vector3(foot.x, ceiling_y, foot.z), 0.006, flags, 6)
	var thick := 0.022
	for i in cables:
		var aside := (i - (cables - 1) * 0.5) * (width - 0.1) / maxf(1.0, cables - 1.0)
		var lift := Vector3(0, 0.04 + thick * (0.8 if i % 2 == 0 else 1.0), 0)
		rod(RUBBER, from + across * aside + lift, to + across * aside + lift, thick * (0.8 if i % 2 == 0 else 1.0), flags, 8)


## Row of `count` switchgear cubicles on a channel base, 80 cm each; `at` is
## the middle of the row on the floor and `yaw_deg` the way its front faces
## (0 looks along +Z). With `instruments` every cubicle carries meters and a
## recorder: the panel of a control room.
func switchboard(at: Vector3, yaw_deg: float, count: int, instruments := false) -> void:
	_m = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	_part = NO_COLLIDE
	var wide := 0.8
	var high := 2.1
	var deep := 0.7
	var base := 0.1
	var length := wide * count
	var front := deep * 0.5
	# Dice of its own: which cubicle carries what depends on where the row
	# stands and on nothing else.
	var dice := RandomNumberGenerator.new()
	dice.seed = hash(Vector3i(at * 10.0)) + count
	_collide_box(_m * Transform3D(Basis(), Vector3(0, (base + high) * 0.5, 0)), Vector3(length, base + high, deep), "metal")
	_plate(IRON, Vector3(0, base * 0.5, 0), Vector3(length - 0.02, base, deep - 0.06))
	_block(GREY, Vector3(0, base + high * 0.5, 0), Vector3(length, high, deep), 0.015)
	# The bus chamber along the top, where the cables come in.
	_block(GREY, Vector3(0, base + high + 0.09, -0.08), Vector3(length - 0.08, 0.18, deep - 0.3), 0.015)
	for i in count:
		var x := (i - (count - 1) * 0.5) * wide
		var upper := Vector3(x, base + 1.56, front)
		var lower := Vector3(x, base + 0.52, front)
		_block(GREY, upper + Vector3(0, 0, 0.006), Vector3(wide - 0.07, 0.96, 0.014), 0.006)
		_block(GREY, lower + Vector3(0, 0, 0.006), Vector3(wide - 0.07, 0.92, 0.014), 0.006)
		_block("paper", Vector3(x, base + high - 0.035, front + 0.003), Vector3(0.26, 0.045, 0.006), 0.002)
		for door: Vector3 in [upper, lower]:
			_block(IRON, door + Vector3(wide * 0.5 - 0.1, 0, 0.032), Vector3(0.022, 0.14, 0.036), 0.008)
		var face := upper + Vector3(0, 0, 0.013)
		if instruments:
			for sx: float in [-1.0, 1.0]:
				_gauge(face + Vector3(sx * 0.17, 0.28, 0), Vector3.BACK, 0.1)
			for k in 3:
				_gauge(face + Vector3((k - 1) * 0.2, 0.02, 0), Vector3.BACK, 0.065)
			# A recorder: a strip of paper behind a brass frame.
			_block(BRASS, face + Vector3(-0.08, -0.26, 0.004), Vector3(0.3, 0.2, 0.012), 0.004)
			_block("paper", face + Vector3(-0.08, -0.26, 0.011), Vector3(0.25, 0.15, 0.004), 0.001)
			_lamps(face + Vector3(0.2, -0.2, 0), 2, 0.07, dice, true)
			_bar(IRON, face + Vector3(0.2, -0.34, 0), face + Vector3(0.2, -0.34, 0.035), 0.022, 10)
		else:
			match dice.randi_range(0, 2):
				0:
					# A feeder: its ammeter, the lamps that say whether it is in,
					# and the switch that puts it in.
					_gauge(face + Vector3(0, 0.24, 0), Vector3.BACK, 0.09)
					_lamps(face + Vector3(0, 0.04, 0), 2, 0.1, dice)
					_block(IRON, face + Vector3(0, -0.18, 0.012), Vector3(0.1, 0.14, 0.024), 0.008)
					_lever(face + Vector3(0, -0.18, 0.024), Vector3.BACK, Vector3.UP if dice.randf() < 0.5 else Vector3.DOWN, 0.12)
				1:
					# A breaker: its handle behind a guard, and a plate that says
					# what it feeds.
					_block(IRON, face + Vector3(0, 0.1, 0.02), Vector3(0.22, 0.34, 0.04), 0.012)
					_lever(face + Vector3(0, 0.1, 0.04), Vector3.BACK, Vector3.DOWN if dice.randf() < 0.7 else Vector3.UP, 0.16)
					_lamps(face + Vector3(0, 0.36, 0), 1, 0.0, dice)
					_block(BRASS, face + Vector3(0, -0.2, 0.003), Vector3(0.24, 0.07, 0.006), 0.002)
				2:
					# Two meters over a row of push buttons.
					for sx: float in [-1.0, 1.0]:
						_gauge(face + Vector3(sx * 0.16, 0.22, 0), Vector3.BACK, 0.075)
					for k in 3:
						var button := face + Vector3((k - 1) * 0.12, -0.06, 0)
						_bar(BARE, button, button + Vector3(0, 0, 0.008), 0.03, 10)
						_bar([RED, GREEN, RUBBER][k], button, button + Vector3(0, 0, 0.022), 0.02, 10)
					_lamps(face + Vector3(0, -0.26, 0), 2, 0.1, dice)
		# Slots in the lower door, to let the heat out.
		for k in 5:
			_block(IRON, lower + Vector3(0, -0.22 + k * 0.055, 0.014), Vector3(wide * 0.5, 0.02, 0.008), 0.003)


## A row of `count` signal lamps in brass bezels on the front of a panel
## that faces +Z in the frame of what is being built, `pitch` apart around
## `at`. Which of them are lit, and red or green, is up to the dice; `lit`
## makes that all of them.
func _lamps(at: Vector3, count: int, pitch: float, dice: RandomNumberGenerator, lit := false) -> void:
	var part := _part
	for i in count:
		var lamp_at := at + Vector3((i - (count - 1) * 0.5) * pitch, 0, 0)
		_part = part
		_bar(BRASS, lamp_at, lamp_at + Vector3(0, 0, 0.01), 0.024, 10)
		var colour := "indicator_red" if dice.randf() < 0.5 else "indicator_green"
		if not lit and dice.randf() < 0.45:
			colour = RUBBER
		_part = DETAIL | NO_COLLIDE
		_bar(colour, lamp_at, lamp_at + Vector3(0, 0, 0.018), 0.016, 10)
	_part = part


## Control desk of three sections, the outer two standing a little apart and
## turned in towards whoever stands at it: each a sloping panel of meters,
## lamps and switches on a steel pedestal. `at` is the middle of the desk on the floor and `yaw_deg` the
## way the operator looks across it (0 looks along +Z).
func control_desk(at: Vector3, yaw_deg: float) -> void:
	var desk := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	var wide := 1.2
	var turn := 22.0
	var dice := RandomNumberGenerator.new()
	dice.seed = hash(Vector3i(at * 10.0))
	# The panel rises away from the operator; this is the way it faces.
	var slope := Vector3(0, 0.65, -0.32).normalized()
	var tilt := -rad_to_deg(atan2(0.32, 0.65))
	for section in 3:
		var side := section - 1.0
		var turned := deg_to_rad(side * turn)
		# A wing stands a hand apart from the middle section, its near corner
		# level with the corner of that.
		var swing := absf(turned)
		var offset := Vector3(side * (wide * 0.5 + 0.08 + wide * 0.5 * cos(swing) + 0.4 * sin(swing)), 0, absf(side) * (0.4 * cos(swing) - 0.4 - wide * 0.5 * sin(swing)))
		_m = desk * Transform3D(Basis(Vector3.UP, turned), offset)
		_part = NO_COLLIDE
		_collide_box(_m * Transform3D(Basis(), Vector3(0, 0.55, 0.02)), Vector3(wide, 1.1, 0.85), "metal")
		_plate(IRON, Vector3(0, 0.05, 0.02), Vector3(wide - 0.04, 0.1, 0.78))
		extrude(GREY, PackedVector2Array([
			Vector2(0.4, 0.1), Vector2(0.4, 0.78), Vector2(-0.25, 1.1), Vector2(-0.45, 1.1), Vector2(-0.45, 0.1),
		]), wide - 0.01, _m * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO), NO_COLLIDE)
		# A raised frame round the panel, and what is set in it.
		for row in 3:
			var t: float = [0.8, 0.47, 0.18][row]
			var on_panel := Vector3(0, 0.78 + 0.32 * t, -0.4 + 0.65 * t) + slope * 0.002
			match row:
				0:
					for k in 3:
						_gauge(on_panel + Vector3((k - 1) * 0.36, 0, 0), slope, 0.085)
				1:
					for k in 6:
						var lamp_at := on_panel + Vector3((k - 2.5) * 0.17, 0, 0)
						_bar(BRASS, lamp_at, lamp_at + slope * 0.01, 0.024, 10)
						var colour := "indicator_red" if dice.randf() < 0.4 else "indicator_green"
						if dice.randf() < 0.3:
							colour = RUBBER
						_part = DETAIL | NO_COLLIDE
						_bar(colour, lamp_at, lamp_at + slope * 0.018, 0.016, 10)
						_part = NO_COLLIDE
				2:
					for k in 4:
						var knob := on_panel + Vector3((k - 1.5) * 0.26, 0, 0)
						_block(BRASS, knob - slope * 0.001, Vector3(0.11, 0.004, 0.11), 0.002, Vector3(tilt, 0, 0))
						_bar(IRON, knob, knob + slope * 0.03, 0.03, 12)
						_block(IRON, knob + slope * 0.04, Vector3(0.022, 0.02, 0.085), 0.006, Vector3(tilt, dice.randf_range(-50.0, 50.0), 0))
		# Vents in the back of the pedestal.
		for k in 4:
			_block(IRON, Vector3(0, 0.3 + k * 0.07, 0.452), Vector3(wide * 0.6, 0.022, 0.008), 0.003)


## Turbo-alternator on its foundation block: from one end to the other the
## governor standard, the high-pressure and the low-pressure cylinder of the
## turbine, the alternator and its exciter, all on one shaft. `at` is the
## middle of the block on the floor and `yaw_deg` the way the steam end
## points from there (0 puts it at -X, with the shaft along X). Steam comes
## up through the block in two lagged pipes, each with its stop valve, and
## leaves downwards into it. `number` is stencilled on the alternator, if
## the manifest has it as a text.
func turbine(at: Vector3, yaw_deg: float, number := "") -> void:
	_m = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	_part = NO_COLLIDE
	var block := Vector3(10.6, 1.0, 3.2)
	var deck := block.y
	var shaft := deck + 1.15
	_collide_box(_m * Transform3D(Basis(), Vector3(0, deck * 0.5, 0)), block, "")
	_collide_box(_m * Transform3D(Basis(), Vector3(-4.6, deck + 0.9, 0)), Vector3(0.9, 1.8, 1.1), "metal")
	_collide_box(_m * Transform3D(Basis(), Vector3(-3.2, shaft, 0)), Vector3(1.9, 2.0, 2.9), "metal")
	_collide_box(_m * Transform3D(Basis(), Vector3(-0.35, shaft + 0.1, 0)), Vector3(2.5, 2.5, 2.4), "metal")
	_collide_box(_m * Transform3D(Basis(), Vector3(3.2, shaft, 0)), Vector3(2.7, 2.2, 2.3), "metal")
	_collide_box(_m * Transform3D(Basis(), Vector3(1.35, deck + 0.8, 0)), Vector3(0.7, 1.6, 0.9), "metal")
	_collide_box(_m * Transform3D(Basis(), Vector3(4.85, deck + 0.8, 0)), Vector3(0.7, 1.6, 0.8), "metal")

	# The foundation block, a steel sole plate under everything that stands
	# on it, and a kerb angle round its top edge.
	_block("concrete", Vector3(0, deck * 0.5, 0), block, 0.03)
	_plate(IRON, Vector3(-0.2, deck + 0.015, 0), Vector3(block.x - 0.9, 0.03, 2.3))
	for sz: float in [-1.0, 1.0]:
		_plate(YELLOW, Vector3(0, deck + 0.02, sz * (block.z * 0.5 - 0.03)), Vector3(block.x, 0.04, 0.06))
	for sx: float in [-1.0, 1.0]:
		_plate(YELLOW, Vector3(sx * (block.x * 0.5 - 0.03), deck + 0.02, 0), Vector3(0.06, 0.04, block.z - 0.12))

	# The governor standard at the steam end: the first bearing under its cap,
	# the governor on top with its handwheel, gauges facing the gangway, and
	# the oil pump on its end.
	_block(GREEN, Vector3(-4.6, deck + 0.62, 0), Vector3(0.8, 1.24, 1.0), 0.07)
	_bar(GREEN, Vector3(-5.02, shaft, 0), Vector3(-4.18, shaft, 0), 0.4, 28)
	for sz: float in [-1.0, 1.0]:
		_block(GREEN, Vector3(-4.6, shaft, sz * 0.46), Vector3(0.7, 0.09, 0.2), 0.02)
		for x: float in [-4.85, -4.35]:
			_bolt(Vector3(x, shaft + 0.045, sz * 0.5), Vector3.UP, 0.03)
	_turned(GREEN, Vector3(-4.6, shaft + 0.38, 0), Vector3.UP, PackedVector2Array([
		Vector2(0.2, 0), Vector2(0.2, 0.3), Vector2(0.15, 0.36), Vector2(0.15, 0.5), Vector2(0.08, 0.56), Vector2(0, 0.57),
	]), 20)
	_bar(BARE, Vector3(-4.6, shaft + 0.72, 0.1), Vector3(-4.6, shaft + 0.72, 0.42), 0.016, 8)
	_handwheel(Vector3(-4.6, shaft + 0.72, 0.4), Vector3.BACK, 0.17)
	_block(GREEN, Vector3(-4.6, deck + 1.02, 0.52), Vector3(0.66, 0.34, 0.05), 0.012)
	for k in 3:
		_gauge(Vector3(-4.6 + (k - 1) * 0.21, deck + 1.02, 0.545), Vector3.BACK, 0.085 if k == 1 else 0.07)
	_motor(BLUE, Vector3(-5.02, deck + 0.38, -0.2), Vector3.LEFT, 0.13, 0.36, false)
	_line(RUST, [Vector3(-5.2, deck + 0.38, -0.2), Vector3(-5.24, deck + 0.3, -0.5), Vector3(-5.1, deck + 0.14, -0.9), Vector3(-4.6, deck + 0.1, -1.0)], 0.022)
	_lever(Vector3(-5.0, deck + 0.95, 0.25), Vector3.LEFT, Vector3.UP, 0.22)

	# The high-pressure cylinder: a barrel split along the shaft, its two
	# halves bolted together along a flange, with the steam chest on top.
	_bar(BARE, Vector3(-4.2, shaft, 0), Vector3(-4.05, shaft, 0), 0.15, 16)
	_turned(GREEN, Vector3(-4.1, shaft, 0), Vector3.RIGHT, PackedVector2Array([
		Vector2(0.3, 0), Vector2(0.52, 0.04), Vector2(0.76, 0.24), Vector2(0.85, 0.55),
		Vector2(0.85, 1.25), Vector2(0.76, 1.56), Vector2(0.52, 1.76), Vector2(0.3, 1.8),
	]), 40, true)
	_block(GREEN, Vector3(-3.2, shaft, 0), Vector3(1.5, 0.1, 1.96), 0.02)
	for i in 7:
		for sz: float in [-1.0, 1.0]:
			_bolt(Vector3(-3.8 + i * 0.2, shaft + 0.05, sz * 0.92), Vector3.UP, 0.032)
	_block(GREEN, Vector3(-3.2, shaft + 0.93, 0), Vector3(0.86, 0.36, 1.2), 0.08)
	for z: float in [-0.3, 0.3]:
		_turned(GREEN, Vector3(-3.2, shaft + 1.11, z), Vector3.UP, PackedVector2Array([
			Vector2(0.11, 0), Vector2(0.11, 0.2), Vector2(0.07, 0.24), Vector2(0.03, 0.24), Vector2(0.03, 0.38), Vector2(0, 0.38),
		]), 14)
	_plate(BARE, Vector3(-3.2, shaft + 1.5, 0), Vector3(0.05, 0.03, 0.74))
	_bar(BARE, Vector3(-3.2, shaft + 1.5, 0), Vector3(-4.4, shaft + 0.95, 0), 0.014, 8)
	# Steam comes up either side through a stop valve and over into the chest.
	for sz: float in [-1.0, 1.0]:
		var out := Vector3(0, 0, sz)
		_line("tank", [
			Vector3(-3.2, shaft + 0.93, sz * 0.5), Vector3(-3.2, shaft + 0.93, sz * 1.02), Vector3(-3.2, shaft + 0.82, sz * 1.24),
			Vector3(-3.2, shaft + 0.5, sz * 1.32), Vector3(-3.2, deck - 0.05, sz * 1.32),
		], 0.15, 14)
		_flange(RUST, Vector3(-3.2, shaft + 0.93, sz * 0.72), out, 0.15)
		_block(IRON, Vector3(-3.2, deck + 0.55, sz * 1.32), Vector3(0.42, 0.44, 0.42), 0.07)
		for y: float in [deck + 0.3, deck + 0.8]:
			_flange(RUST, Vector3(-3.2, y, sz * 1.32), Vector3.UP, 0.15)
		_bar(BARE, Vector3(-3.2 - 0.2, deck + 0.55, sz * 1.32), Vector3(-3.2 - 0.52, deck + 0.55, sz * 1.32), 0.018, 8)
		_handwheel(Vector3(-3.2 - 0.5, deck + 0.55, sz * 1.32), Vector3.LEFT, 0.2)

	# A bearing between the two cylinders, under a cap like the first.
	_bar(BARE, Vector3(-2.32, shaft, 0), Vector3(-1.58, shaft, 0), 0.16, 16)
	_block(GREEN, Vector3(-1.95, deck + 0.5, 0), Vector3(0.46, 1.0, 0.9), 0.06)
	_bar(GREEN, Vector3(-2.2, shaft, 0), Vector3(-1.7, shaft, 0), 0.34, 24)

	# The low-pressure cylinder: wider, ribbed, with a relief valve on top.
	# Its exhaust goes straight down into the block.
	var low := 1.22
	_turned(GREEN, Vector3(-1.6, shaft, 0), Vector3.RIGHT, PackedVector2Array([
		Vector2(0.36, 0), Vector2(0.7, 0.04), Vector2(1.06, 0.2), Vector2(low, 0.5),
		Vector2(low, 2.0), Vector2(1.06, 2.3), Vector2(0.7, 2.46), Vector2(0.36, 2.5),
	]), 48, true)
	for x: float in [-0.95, -0.35, 0.25]:
		_turned(GREEN, Vector3(x - 0.035, shaft, 0), Vector3.RIGHT, PackedVector2Array([
			Vector2(low, 0), Vector2(low + 0.05, 0), Vector2(low + 0.05, 0.07), Vector2(low, 0.07),
		]), 48)
	_block(GREEN, Vector3(-0.35, shaft, 0), Vector3(2.0, 0.11, low * 2.0 + 0.28), 0.02)
	for i in 9:
		for sz: float in [-1.0, 1.0]:
			_bolt(Vector3(-1.15 + i * 0.2, shaft + 0.055, sz * (low + 0.08)), Vector3.UP, 0.034)
	_block(GREEN, Vector3(-0.35, deck + 0.25, 0), Vector3(1.9, 0.5, 2.1), 0.05)
	_turned(GREEN, Vector3(-0.35, shaft + low - 0.03, 0), Vector3.UP, PackedVector2Array([
		Vector2(0.3, 0), Vector2(0.3, 0.2), Vector2(0.4, 0.2), Vector2(0.4, 0.25), Vector2(0, 0.25),
	]), 28)
	_bolt_circle(Vector3(-0.35, shaft + low + 0.22, 0), Vector3.UP, 0.35, 12)
	_block(BRASS, Vector3(-0.65, shaft + 0.3, low * 0.975), Vector3(0.34, 0.2, 0.012), 0.004, Vector3(-14, 0, 0))

	# The coupling under its guard, on a third bearing.
	_bar(BARE, Vector3(0.9, shaft, 0), Vector3(1.95, shaft, 0), 0.15, 16)
	_block(GREEN, Vector3(1.22, deck + 0.5, 0), Vector3(0.44, 1.0, 0.9), 0.06)
	_bar(GREEN, Vector3(0.98, shaft, 0), Vector3(1.46, shaft, 0), 0.34, 24)
	_bar(YELLOW, Vector3(1.5, shaft, 0), Vector3(1.86, shaft, 0), 0.3, 20)

	# The alternator: the stator in its ribbed frame on two feet, the air
	# cooler on top, the terminal box at the back with the cables that carry
	# off what it makes.
	var stator := 1.0
	_turned(BLUE, Vector3(1.9, shaft, 0), Vector3.RIGHT, PackedVector2Array([
		Vector2(0.4, 0), Vector2(0.78, 0.05), Vector2(0.96, 0.26), Vector2(stator, 0.46),
		Vector2(stator, 2.14), Vector2(0.96, 2.34), Vector2(0.78, 2.55), Vector2(0.4, 2.6),
	]), 48, true)
	for i in 6:
		_turned(BLUE, Vector3(2.5 + i * 0.28, shaft, 0), Vector3.RIGHT, PackedVector2Array([
			Vector2(stator, 0), Vector2(stator + 0.045, 0), Vector2(stator + 0.045, 0.05), Vector2(stator, 0.05),
		]), 48)
	for sz: float in [-1.0, 1.0]:
		_block(BLUE, Vector3(3.2, deck + 0.2, sz * 0.82), Vector3(2.1, 0.4, 0.4), 0.04)
		for x: float in [2.4, 3.2, 4.0]:
			_bolt(Vector3(x, deck + 0.4, sz * 0.93), Vector3.UP, 0.034)
	_block(BLUE, Vector3(3.2, shaft + stator + 0.12, 0), Vector3(1.5, 0.34, 1.1), 0.05)
	for k in 6:
		for sz: float in [-1.0, 1.0]:
			_block(IRON, Vector3(2.7 + k * 0.2, shaft + stator + 0.12, sz * 0.552), Vector3(0.11, 0.22, 0.008), 0.003)
	_block(BLUE, Vector3(3.2, shaft - 0.1, -stator - 0.1), Vector3(0.9, 0.7, 0.3), 0.04)
	for k in 3:
		var cable := Vector3(2.95 + k * 0.25, shaft - 0.45, -stator - 0.1)
		_line(RUBBER, [cable, cable + Vector3(0, -0.3, -0.06), Vector3(cable.x, deck + 0.2, -stator - 0.32), Vector3(cable.x, deck - 0.05, -stator - 0.34)], 0.04)
	_block(BRASS, Vector3(2.25, shaft + 0.5, 0.72), Vector3(0.012, 0.2, 0.3), 0.004, Vector3(0, -62, 0))

	# The exciter on the end of the shaft.
	_bar(BARE, Vector3(4.45, shaft, 0), Vector3(4.62, shaft, 0), 0.1, 12)
	_block(IRON, Vector3(4.86, deck + 0.42, 0), Vector3(0.56, 0.84, 0.66), 0.04)
	_turned(BLUE, Vector3(4.58, shaft, 0), Vector3.RIGHT, PackedVector2Array([
		Vector2(0.16, 0), Vector2(0.34, 0.04), Vector2(0.38, 0.12), Vector2(0.38, 0.45), Vector2(0.34, 0.52), Vector2(0.1, 0.56), Vector2(0, 0.56),
	]), 24, true)
	_block(BLUE, Vector3(4.86, shaft + 0.42, 0), Vector3(0.24, 0.12, 0.2), 0.02)

	# Oil to every bearing along the gangway side of the block, and back.
	_line(RUST, [
		Vector3(-4.6, deck + 0.1, 1.0), Vector3(-4.0, deck + 0.12, 1.5), Vector3(-2.0, deck + 0.12, 1.5),
		Vector3(1.2, deck + 0.12, 1.5), Vector3(4.4, deck + 0.12, 1.5), Vector3(4.86, deck + 0.12, 0.6),
	], 0.028)
	for x: float in [-1.95, 1.22]:
		_line(RUST, [Vector3(x, deck + 0.12, 1.5), Vector3(x, deck + 0.14, 1.0), Vector3(x, deck + 0.3, 0.47)], 0.02)

	if number != "":
		label(number, _m * Vector3(3.2, shaft + 0.2, stator * 0.98), _m.basis * Vector3.BACK, 0.5, Color(0.86, 0.86, 0.8), 0.3)
	floor_decal("stain_1", _m * Vector3(-3.6, 0, 2.6), Vector2(3.2, 2.4), yaw_deg + 40.0)
	floor_decal("stain_2", _m * Vector3(1.4, 0, 2.4), Vector2(3.0, 1.8), yaw_deg)
