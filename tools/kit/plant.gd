extends "res://tools/kit/machines.gd"
## Third drawer of the kit, see tools/kit.gd: what makes steam and moves
## water.

## Fire-tube boiler lying on two saddles: the burner at its west end, the
## smokebox and the flue up through the roof at the other. `at` is the middle
## of its footprint. The steam main leaves at a height of 5.85 m for the wall
## to the south of it, whose face is at `wall_z`, and hangs from the roof,
## which is at `roof_y`.
func boiler(at: Vector3, wall_z: float, roof_y: float) -> void:
	_m = Transform3D(Basis(), at)
	var r := 1.3
	var half := 2.8
	var axis := 1.95
	var shell := "tank"
	_collide_box(_m * Transform3D(Basis(), Vector3(0.35, 1.65, 0)), Vector3(half * 2.0 + 0.9, 3.3, r * 2.0 + 0.1), "metal")
	_collide_box(_m * Transform3D(Basis(), Vector3(-half - 0.6, 1.5, 0.1)), Vector3(1.0, 1.3, 1.3), "metal")

	# A plinth, the saddles, the shell with its dished end and the straps
	# round the lagging.
	_plate("concrete", Vector3(0, 0.1, 0), Vector3(half * 2.0 + 0.5, 0.2, 2.5))
	for x: float in [-1.8, 1.8]:
		_block(IRON, Vector3(x, 0.62, 0), Vector3(0.36, 0.84, 2.3), 0.03)
	_turned(shell, Vector3(-half, axis, 0), Vector3.RIGHT, PackedVector2Array([
		Vector2(r, 0), Vector2(r, half * 2.0 - 0.3), Vector2(r - 0.04, half * 2.0 - 0.16), Vector2(r - 0.16, half * 2.0 - 0.06),
		Vector2(r - 0.4, half * 2.0 + 0.02), Vector2(0.5, half * 2.0 + 0.09), Vector2(0, half * 2.0 + 0.11),
	]), 48, true)
	for x: float in [-2.25, -0.75, 0.75, 2.25]:
		_turned(BARE, Vector3(x - 0.035, axis, 0), Vector3.RIGHT, PackedVector2Array([
			Vector2(r, 0), Vector2(r + 0.012, 0), Vector2(r + 0.012, 0.07), Vector2(r, 0.07),
		]), 48)

	# The front: a plate bolted round its rim, the furnace door low down with
	# the burner on it, gauges above.
	var front := Vector3(-half, axis, 0)
	_turned(IRON, front, Vector3.LEFT, PackedVector2Array([
		Vector2(r + 0.05, -0.06), Vector2(r + 0.05, 0.06), Vector2(r - 0.02, 0.1), Vector2(0, 0.1),
	]), 48)
	_bolt_circle(front + Vector3(-0.1, 0, 0), Vector3.LEFT, r - 0.12, 24)
	var door := front + Vector3(-0.1, -0.5, 0)
	_turned(IRON, door, Vector3.LEFT, PackedVector2Array([
		Vector2(0.52, 0), Vector2(0.52, 0.07), Vector2(0.46, 0.1), Vector2(0.22, 0.1),
	]), 32)
	_bolt_circle(door + Vector3(-0.07, 0, 0), Vector3.LEFT, 0.49, 10)
	for y: float in [-0.25, 0.25]:
		_block(IRON, door + Vector3(-0.07, y, 0.56), Vector3(0.1, 0.09, 0.16), 0.02)
	_turned(BLUE, door + Vector3(-0.08, 0, 0), Vector3.LEFT, PackedVector2Array([
		Vector2(0.22, 0), Vector2(0.22, 0.28), Vector2(0.28, 0.34), Vector2(0.28, 0.82), Vector2(0.22, 0.88), Vector2(0, 0.88),
	]), 24)
	# The fan that blows it, with its motor, beside the burner.
	var fan := door + Vector3(-0.62, 0.08, 0.36)
	_turned(BLUE, fan, Vector3.BACK, PackedVector2Array([Vector2(0, 0), Vector2(0.34, 0), Vector2(0.34, 0.2), Vector2(0, 0.2)]), 24)
	_motor(BLUE, fan + Vector3(0, 0, 0.2), Vector3.BACK, 0.13, 0.36, false)
	_block(BLUE, fan + Vector3(0.0, 0.42, 0.1), Vector3(0.3, 0.26, 0.2), 0.03)
	_block(IRON, fan + Vector3(0.0, 0.57, 0.1), Vector3(0.32, 0.04, 0.22), 0.008)
	_line(RUBBER, [fan + Vector3(0, 0.1, 0.42), fan + Vector3(0.05, -0.2, 0.5), fan + Vector3(0.3, -0.62, 0.45), fan + Vector3(0.62, -0.7, 0.3)], 0.014)
	# Fuel line down the front to the floor.
	_line(RUST, [door + Vector3(-0.5, -0.28, -0.1), door + Vector3(-0.5, -0.4, -0.5), door + Vector3(-0.42, -0.9, -0.85), door + Vector3(-0.42, -1.5, -0.9)], 0.025, 8)
	_gauge(front + Vector3(-0.1, 0.72, -0.34), Vector3.LEFT, 0.11)
	_gauge(front + Vector3(-0.1, 0.72, 0.34), Vector3.LEFT, 0.09)
	# The water level, in a glass between two cocks.
	for y: float in [0.2, 0.62]:
		_bar(BARE, front + Vector3(-0.08, y, 0.86), front + Vector3(-0.22, y, 0.86), 0.016, 8)
		_block(BRASS, front + Vector3(-0.22, y, 0.86), Vector3(0.05, 0.07, 0.05), 0.012)
	_bar(BARE, front + Vector3(-0.22, 0.2, 0.86), front + Vector3(-0.22, 0.62, 0.86), 0.011, 8)
	_block(BRASS, front + Vector3(-0.103, 0.3, -0.8), Vector3(0.006, 0.2, 0.3), 0.003)
	wall_decal("warning_1", _m * (front + Vector3(-0.105, 0.72, 0.0)), Vector3.LEFT, 0.22, 0.22, Color.WHITE, 0.04)
	# Where the fire shows: a port in the furnace door, and the slots of the
	# air register round the burner.
	_part = DETAIL | NO_COLLIDE
	_turned(BRASS, door + Vector3(-0.1, 0.34, -0.2), Vector3.LEFT, PackedVector2Array([Vector2(0.06, 0), Vector2(0.06, 0.02), Vector2(0.045, 0.02)]), 16)
	_turned("emissive_warm", door + Vector3(-0.1, 0.34, -0.2), Vector3.LEFT, PackedVector2Array([Vector2(0.045, 0.012), Vector2(0, 0.012)]), 16)
	for i in 6:
		var turn := Basis(Vector3.RIGHT, TAU * (i + 0.5) / 6.0)
		_local_box("emissive_warm", _m * Transform3D(turn, door + Vector3(-0.46, 0, 0)), Vector3(0, 0.283, 0), Vector3(0.12, 0.004, 0.08), DETAIL | NO_COLLIDE)
	_part = NO_COLLIDE

	# On top: a manhole, two safety valves and the stop valve the steam main
	# leaves by, which runs up and off through the south wall.
	var top := axis + r - 0.02
	_turned(shell, Vector3(-1.5, top, 0), Vector3.UP, PackedVector2Array([
		Vector2(0.3, 0), Vector2(0.3, 0.16), Vector2(0.37, 0.16), Vector2(0.37, 0.2), Vector2(0, 0.2),
	]), 32)
	_bolt_circle(Vector3(-1.5, top + 0.2, 0), Vector3.UP, 0.335, 12)
	for x: float in [1.0, 1.55]:
		_turned(BRASS, Vector3(x, top, 0), Vector3.UP, PackedVector2Array([
			Vector2(0.07, 0), Vector2(0.07, 0.2), Vector2(0.1, 0.2), Vector2(0.1, 0.34), Vector2(0.05, 0.4), Vector2(0.05, 0.52), Vector2(0, 0.52),
		]), 16)
		_lever(Vector3(x, top + 0.52, 0), Vector3.UP, Vector3.BACK, 0.3)
	var stop := Vector3(-0.2, top + 0.5, 0)
	_turned(RUST, Vector3(-0.2, top, 0), Vector3.UP, PackedVector2Array([
		Vector2(0.11, 0), Vector2(0.11, 0.3), Vector2(0.2, 0.3), Vector2(0.2, 0.33), Vector2(0, 0.33),
	]), 20)
	_block(IRON, stop, Vector3(0.36, 0.38, 0.36), 0.06)
	_bar(BARE, stop + Vector3(0, 0, 0.16), stop + Vector3(0, 0, 0.5), 0.018)
	_handwheel(stop + Vector3(0, 0, 0.46), Vector3.BACK, 0.2)
	var main := 5.85
	var south := wall_z - at.z
	_line(RUST, [
		stop + Vector3(0, 0.15, 0), Vector3(-0.2, main - 0.5, 0), Vector3(-0.2, main - 0.15, 0.12), Vector3(-0.2, main, 0.45), Vector3(-0.2, main, south + 0.1),
	], 0.11, 14)
	# Flanges and hangers along the main, as far as the wall.
	for z: float in [2.6, 5.4]:
		if z < south:
			_flange(RUST, Vector3(-0.2, main, z), Vector3.BACK, 0.11)
	for z: float in [1.6, 4.4, 7.0]:
		if z > south:
			break
		_part = DETAIL | NO_COLLIDE
		_bar(IRON, Vector3(-0.2, main + 0.11, z), Vector3(-0.2, roof_y - at.y, z), 0.008, 6)
		_part = NO_COLLIDE

	# The smokebox at the back and the flue out of it.
	_block(IRON, Vector3(half + 0.42, axis + 0.1, 0), Vector3(0.72, 2.3, 2.1), 0.1)
	_block(IRON, Vector3(half + 0.79, axis - 0.2, 0), Vector3(0.03, 0.9, 0.7), 0.01)
	_lever(Vector3(half + 0.805, axis - 0.2, 0.2), Vector3.RIGHT, Vector3.DOWN, 0.16)
	var flue := roof_y - at.y - (axis + 1.2)
	_turned("galvanised", Vector3(half + 0.42, axis + 1.2, 0), Vector3.UP, PackedVector2Array([Vector2(0.36, 0), Vector2(0.36, flue)]), 24)
	for y: float in [0.5, 1.7, 2.9]:
		_turned("galvanised", Vector3(half + 0.42, axis + 1.2 + y, 0), Vector3.UP, PackedVector2Array([
			Vector2(0.36, 0), Vector2(0.385, 0), Vector2(0.385, 0.05), Vector2(0.36, 0.05),
		]), 24)

	# Blow-down from the bottom, through a valve and into the floor.
	_line(RUST, [Vector3(-1.1, 0.75, r - 0.1), Vector3(-1.1, 0.6, r + 0.2), Vector3(-1.1, 0.45, r + 0.4), Vector3(-1.1, -0.05, r + 0.42)], 0.045, 10)
	_block(IRON, Vector3(-1.1, 0.5, r + 0.37), Vector3(0.16, 0.16, 0.16), 0.03)
	_handwheel(Vector3(-1.1, 0.5, r + 0.5), Vector3.BACK, 0.08)
	# What it is called, on the side the room sees it from.
	label("K1", _m * Vector3(0.75, axis + 0.25, r), Vector3.BACK, 0.5, Color(0.06, 0.06, 0.06), 0.25)
	var plate := Vector3(-1.5, axis + 0.1, r + 0.02)
	_block(BRASS, plate, Vector3(0.3, 0.2, 0.006), 0.003)

	# The fire, as far as it lights the floor in front of the burner.
	var glow := OmniLight3D.new()
	glow.name = "Fire"
	glow.position = _m * (door + Vector3(-1.15, 0.1, 0.0))
	glow.light_color = Color(1.0, 0.5, 0.2)
	glow.light_energy = 2.2
	glow.omni_range = 4.5
	glow.omni_attenuation = 1.4
	glow.light_bake_mode = Light3D.BAKE_DYNAMIC
	_add(glow, _group("Lights", glow.position))


## Centrifugal pump with its motor on one base: the motor behind, the casing
## with its inlet in front and its outlet pointing up. `at` is the middle of
## the base and `yaw_deg` the way the inlet faces (0 looks along +Z).
func pump(at: Vector3, yaw_deg: float) -> void:
	_m = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	_collide_box(_m * Transform3D(Basis(), Vector3(0, 0.42, 0)), Vector3(0.6, 0.84, 1.5), "metal")
	_plate("concrete", Vector3(0, 0.06, 0), Vector3(0.74, 0.12, 1.62))
	_block(IRON, Vector3(0, 0.15, 0), Vector3(0.5, 0.06, 1.46), 0.01)
	var shaft := 0.44
	_motor(BLUE, Vector3(0, shaft, -0.68), Vector3.BACK, 0.17, 0.56)
	# A guard over the coupling, the bearing housing, and the casing.
	_block(YELLOW, Vector3(0, shaft, -0.01), Vector3(0.26, 0.26, 0.2), 0.06)
	_turned(GREEN, Vector3(0, shaft, 0.09), Vector3.BACK, PackedVector2Array([
		Vector2(0, 0), Vector2(0.1, 0), Vector2(0.1, 0.2), Vector2(0.2, 0.2), Vector2(0.27, 0.24), Vector2(0.27, 0.36),
		Vector2(0.2, 0.4), Vector2(0.09, 0.4), Vector2(0.09, 0.52), Vector2(0, 0.52),
	]), 24)
	_block(GREEN, Vector3(0, 0.26, 0.19), Vector3(0.2, 0.2, 0.12), 0.02)
	_flange(RUST, Vector3(0, shaft, 0.6), Vector3.BACK, 0.07)
	_bar(RUST, Vector3(0, shaft + 0.2, 0.39), Vector3(0, shaft + 0.56, 0.39), 0.055)
	_flange(RUST, Vector3(0, shaft + 0.5, 0.39), Vector3.UP, 0.055)
	_bolt_circle(Vector3(0, shaft, 0.33), Vector3.FORWARD, 0.235, 8)


## Board of gauges with the pipes that come up to them; `at` is the middle of
## its back on a wall that faces `out`.
func gauge_board(at: Vector3, out: Vector3) -> void:
	_m = Transform3D()
	var across := Vector3.UP.cross(out)
	var size := Vector2(1.7, 0.9)
	_block(GREEN, at + out * 0.02, Vector3(size.x, size.y, 0.04) if absf(out.z) > 0.5 else Vector3(0.04, size.y, size.x), 0.008)
	for i in 5:
		var spot := at + out * 0.04 + across * (i - 2.0) * 0.32 + Vector3(0, 0.12 if i % 2 == 0 else 0.16, 0)
		_gauge(spot, out, 0.11 if i % 2 == 0 else 0.085)
		var foot := at + out * 0.06 + across * (i - 2.0) * 0.32
		_bar(BARE, foot + Vector3(0, -0.02, 0), foot + Vector3(0, -size.y * 0.5 - 0.25 - i * 0.02, 0), 0.008, 6)
	for i in 3:
		var knob := at + out * 0.04 + across * (i - 1.0) * 0.4 + Vector3(0, -0.28, 0)
		_block(IRON, knob + out * 0.012, Vector3(0.09, 0.12, 0.024) if absf(out.z) > 0.5 else Vector3(0.024, 0.12, 0.09), 0.006)
		_bar(RED if i == 1 else BARE, knob + out * 0.024, knob + out * 0.05, 0.022, 10)
