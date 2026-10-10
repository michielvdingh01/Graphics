extends "res://tools/kit/parts.gd"
## Second drawer of the kit, see tools/kit.gd: what stands on the floor of a
## works, and the crane over it.

## Storage tank of three welded courses under a dished head, on a concrete
## plinth. Seen from above, the manhole faces `yaw_deg` (0 looks along +Z) and
## the outlet and the caged ladder sit that many degrees round from it. The
## line from its head runs north to a header at `header_z`.
func tank(at: Vector3, yaw_deg: float, outlet_deg: float, header_z: float, ladder_deg := NAN) -> void:
	var shell := "tank"
	var r := 1.25
	var facing := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	_m = facing
	cylinder("concrete", at, r + 0.2, 0.25, 0, Vector3.ZERO, -1.0, 32)
	_collide_cylinder(Transform3D(Basis(), at + Vector3(0, 2.57, 0)), r + 0.02, 4.64, "metal")

	# Base ring bolted to the plinth, the courses lapped in and out, the head.
	_turned(shell, Vector3(0, 0.25, 0), Vector3.UP, PackedVector2Array([
		Vector2(r + 0.11, 0), Vector2(r + 0.11, 0.02), Vector2(r + 0.02, 0.02), Vector2(r + 0.02, 0.1), Vector2(r, 0.1),
	]), 48)
	_bolt_circle(Vector3(0, 0.27, 0), Vector3.UP, r + 0.065, 16)
	_turned(shell, Vector3(0, 0.25, 0), Vector3.UP, PackedVector2Array([
		Vector2(r, 0), Vector2(r, 1.4), Vector2(r + 0.012, 1.4), Vector2(r + 0.012, 2.8), Vector2(r, 2.8), Vector2(r, 4.2),
	]), 48)
	_turned(shell, Vector3(0, 4.45, 0), Vector3.UP, PackedVector2Array([
		Vector2(r, 0), Vector2(r, 0.04), Vector2(r - 0.03, 0.12), Vector2(r - 0.12, 0.21),
		Vector2(r - 0.3, 0.3), Vector2(0.6, 0.39), Vector2(0.3, 0.435), Vector2(0, 0.45),
	]), 48, true)
	_ring(shell, Vector3(0, 4.45, 0), Vector3.UP, r + 0.003, 0.012)
	# Every course is a plate rolled round and welded shut; the seams are staggered.
	for course in 3:
		for k in 2:
			var turn := 35.0 + course * 70.0 + k * 180.0
			var seam := _round(turn) * (r + (0.014 if course == 1 else 0.002))
			_block(shell, seam + Vector3(0, 0.95 + course * 1.4, 0), Vector3(0.035, 1.4, 0.012), 0.004, Vector3(0, turn, 0))

	# Manhole with a bolted cover.
	var hatch := Vector3(0, 1.25, r - 0.06)
	_turned(shell, hatch, Vector3.BACK, PackedVector2Array([
		Vector2(0.29, 0), Vector2(0.29, 0.2), Vector2(0.36, 0.2), Vector2(0.36, 0.25), Vector2(0, 0.25),
	]), 32)
	_bolt_circle(hatch + Vector3(0, 0, 0.25), Vector3.BACK, 0.325, 16)
	_line(BARE, [hatch + Vector3(-0.1, 0, 0.24), hatch + Vector3(-0.08, 0, 0.31), hatch + Vector3(0.08, 0, 0.31), hatch + Vector3(0.1, 0, 0.24)], 0.012)
	# Nameplate, standing off the shell on two strips.
	var plate := _round(-32.0) * (r + 0.03) + Vector3(0, 1.45, 0)
	_block(BRASS, plate, Vector3(0.3, 0.2, 0.006), 0.003, Vector3(0, -32, 0))
	for y: float in [-0.07, 0.07]:
		_block(shell, plate - _round(-32.0) * 0.012 + Vector3(0, y, 0), Vector3(0.36, 0.03, 0.02), 0.004, Vector3(0, -32, 0))

	# Sight glass between two cocks.
	var gauge := _round(38.0)
	for y: float in [0.9, 3.7]:
		_bar(BARE, gauge * (r - 0.02) + Vector3(0, y, 0), gauge * (r + 0.13) + Vector3(0, y, 0), 0.018, 8)
		_block(BRASS, gauge * (r + 0.13) + Vector3(0, y, 0), Vector3(0.05, 0.08, 0.05), 0.012)
	_bar(BARE, gauge * (r + 0.13) + Vector3(0, 0.9, 0), gauge * (r + 0.13) + Vector3(0, 3.7, 0), 0.012, 8)

	# Outlet through a gate valve and down into the floor.
	var out := _round(outlet_deg)
	var low := Vector3(0, 0.62, 0)
	_bar(RUST, out * (r - 0.03) + low, out * (r + 0.24) + low, 0.07)
	_flange(RUST, out * (r + 0.15) + low, out, 0.07)
	_m = facing * Transform3D(Basis(Vector3.UP, deg_to_rad(outlet_deg)), Vector3.ZERO)
	var valve := Vector3(0, low.y, r + 0.33)
	_block(IRON, valve, Vector3(0.22, 0.22, 0.2), 0.04)
	_turned(IRON, valve, Vector3.UP, PackedVector2Array([
		Vector2(0.07, 0.1), Vector2(0.07, 0.18), Vector2(0.1, 0.18), Vector2(0.1, 0.2), Vector2(0.03, 0.2), Vector2(0.03, 0.34), Vector2(0, 0.34),
	]), 12)
	_bar(BARE, valve + Vector3(0, 0.3, 0), valve + Vector3(0, 0.44, 0), 0.012, 8)
	_handwheel(valve + Vector3(0, 0.42, 0), Vector3.UP, 0.12)
	_flange(RUST, valve + Vector3(0, 0, 0.13), Vector3.BACK, 0.07)
	_line(RUST, [valve + Vector3(0, 0, 0.1), valve + Vector3(0, 0, 0.36), valve + Vector3(0, -0.14, 0.52), valve + Vector3(0, -0.4, 0.56), Vector3(0, -0.05, r + 0.89)], 0.07, 12)
	_turned(IRON, Vector3(0, 0, r + 0.89), Vector3.UP, PackedVector2Array([Vector2(0.13, 0), Vector2(0.13, 0.015), Vector2(0.07, 0.015)]), 16)

	if not is_nan(ladder_deg):
		# Ladder up to the head, caged from above head height.
		_m = facing * Transform3D(Basis(Vector3.UP, deg_to_rad(ladder_deg)), Vector3.ZERO)
		_part = DETAIL | NO_COLLIDE
		var off := r + 0.2
		for sx: float in [-1.0, 1.0]:
			_plate(YELLOW, Vector3(sx * 0.21, 2.95, off), Vector3(0.012, 5.3, 0.05))
			for y: float in [0.8, 2.4, 4.0]:
				_plate(YELLOW, Vector3(sx * 0.21, y, r + 0.09), Vector3(0.012, 0.04, 0.22))
		for i in 17:
			var y := 0.55 + i * 0.3
			_bar(YELLOW, Vector3(-0.21, y, off), Vector3(0.21, y, off), 0.012, 6)
		for i in 5:
			_ring(YELLOW, Vector3(0, 2.4 + i * 0.78, off + 0.34), Vector3.UP, 0.36, 0.011)
		for i in 5:
			var strap := _round((i - 2) * 32.0) * 0.36 + Vector3(0, 0, off + 0.34)
			_bar(YELLOW, strap + Vector3(0, 2.4, 0), strap + Vector3(0, 5.52, 0), 0.008, 6)
		_part = NO_COLLIDE

	# Flanged nozzle on the head and the line over to the header on the wall.
	_m = Transform3D(Basis(), at)
	_turned(RUST, Vector3(0, 4.84, 0), Vector3.UP, PackedVector2Array([
		Vector2(0.15, 0), Vector2(0.15, 0.2), Vector2(0.25, 0.2), Vector2(0.25, 0.23), Vector2(0, 0.23),
	]), 20)
	var run := header_z - at.z
	_line(RUST, [
		Vector3(0, 4.95, 0), Vector3(0, 5.06, 0), Vector3(0, 5.21, -0.04), Vector3(0, 5.32, -0.15),
		Vector3(0, 5.36, -0.3), Vector3(0, 5.36, -0.7), Vector3(0, 5.36, run),
	], 0.14, 14)
	_flange(RUST, Vector3(0, 5.36, run * 0.5), Vector3.BACK, 0.14)
	_flange(RUST, Vector3(0, 5.36, run + 0.22), Vector3.BACK, 0.14)
	# A vent with a gooseneck, so rain stays out.
	_line(RUST, [Vector3(0.55, 4.7, 0.3), Vector3(0.55, 5.1, 0.3), Vector3(0.6, 5.22, 0.36), Vector3(0.7, 5.2, 0.48), Vector3(0.72, 5.08, 0.5)], 0.04, 10)
	_turned(RUST, Vector3(0.72, 5.09, 0.5), Vector3.DOWN, PackedVector2Array([Vector2(0.06, 0), Vector2(0.06, 0.02), Vector2(0, 0.02)]), 12)


## Eccentric press with an open front: the bed below, the slide and its drive
## in the head that reaches out over it, the flywheel on the east side. `at` is
## the middle of its foot; the operator stands on the north side.
func press(at: Vector3) -> void:
	_m = Transform3D(Basis(), at)
	_collide_box(_m * Transform3D(Basis(), Vector3(0, 0.54, 0)), Vector3(3.1, 1.08, 2.2), "metal")
	_collide_box(_m * Transform3D(Basis(), Vector3(0, 2.4, 0.45)), Vector3(2.42, 2.7, 1.1), "metal")
	_collide_box(_m * Transform3D(Basis(), Vector3(0, 2.75, -0.5)), Vector3(2.5, 2.0, 0.8), "metal")

	# Foot, bolted to the floor, and the bed with its bolster plate.
	_block(GREEN, Vector3(0, 0.07, 0), Vector3(3.1, 0.14, 2.2), 0.03)
	for x in [-1.42, 0.0, 1.42]:
		for z in [-0.98, 0.98]:
			_bar(IRON, Vector3(x, 0.14, z), Vector3(x, 0.148, z), 0.05)
			_bolt(Vector3(x, 0.148, z), Vector3.UP, 0.032)
	_block(GREEN, Vector3(0, 0.6, 0.05), Vector3(2.5, 0.96, 1.9), 0.06)
	_block(GREEN, Vector3(0, 0.58, -0.905), Vector3(1.2, 0.6, 0.03), 0.012)
	for x in [-0.54, 0.54]:
		for y in [0.34, 0.82]:
			_bolt(Vector3(x, y, -0.92), Vector3.FORWARD)
	_block(BARE, Vector3(0, 1.12, -0.3), Vector3(1.7, 0.1, 1.05), 0.012)
	for x in [-0.6, -0.2, 0.2, 0.6]:
		_block(IRON, Vector3(x, 1.17, -0.3), Vector3(0.03, 0.006, 1.05), 0.0)
	_louvred_door(GREEN, Vector3(0.5, 0.58, 1.0), Vector3.BACK, Vector2(0.9, 0.62))

	# Frame: two flanged cheeks joined by a ribbed web at the back, the head on top.
	var sideways := Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT)
	for x in [-1.05, 1.05]:
		_block(GREEN, Vector3(x, 2.3, 0.45), Vector3(0.26, 2.5, 1.1), 0.04)
		_block(GREEN, Vector3(x, 1.62, -0.05), Vector3(0.36, 1.1, 0.12), 0.04)
		_block(GREEN, Vector3(x, 2.3, 0.96), Vector3(0.36, 2.5, 0.12), 0.04)
		extrude(GREEN, PackedVector2Array([Vector2(0, 2.1), Vector2(0.75, 2.8), Vector2(0, 2.8)]), 0.3,
			_m * Transform3D(sideways, Vector3(x, 0, -0.08)), NO_COLLIDE)
	# Inspection cover on the cheek that has no electrics on it.
	_turned(GREEN, Vector3(1.18, 1.75, 0.45), Vector3.RIGHT, PackedVector2Array([Vector2(0.22, 0), Vector2(0.22, 0.03), Vector2(0, 0.03)]))
	_bolt_circle(Vector3(1.21, 1.75, 0.45), Vector3.RIGHT, 0.18, 6)
	_block(GREEN, Vector3(0, 2.3, 0.92), Vector3(1.8, 2.4, 0.16), 0.03)
	for x in [-0.45, 0.45]:
		_block(GREEN, Vector3(x, 2.2, 1.03), Vector3(0.1, 2.3, 0.1), 0.03)
	_block(GREEN, Vector3(0, 1.9, 1.03), Vector3(1.8, 0.1, 0.1), 0.03)
	_block(GREEN, Vector3(0, 3.25, 0.05), Vector3(2.5, 1.0, 1.9), 0.08)
	_block(GREEN, Vector3(0, 3.27, 1.005), Vector3(1.6, 0.6, 0.03), 0.012)
	for x in [-0.74, -0.25, 0.25, 0.74]:
		for y in [3.03, 3.51]:
			_bolt(Vector3(x, y, 1.02), Vector3.BACK)
	_turned(BRASS, Vector3(0.98, 3.3, -0.9), Vector3.FORWARD, PackedVector2Array([Vector2(0.07, 0), Vector2(0.07, 0.03), Vector2(0, 0.03)]), 16)
	_block(GREEN, Vector3(0, 3.27, -0.905), Vector3(1.5, 0.62, 0.03), 0.012)
	for x in [-0.69, -0.23, 0.23, 0.69]:
		for y in [3.02, 3.52]:
			_bolt(Vector3(x, y, -0.92), Vector3.FORWARD)
	_block(BRASS, Vector3(0, 3.27, -0.923), Vector3(0.46, 0.16, 0.008), 0.003)
	for x in [-0.95, 0.95]:
		_ring(IRON, Vector3(x, 3.81, 0.0), Vector3.RIGHT, 0.07, 0.016)

	# What it is and what it can do, and a warning where the slide comes down.
	var ink := Color(0.84, 0.84, 0.8)
	var engraved := Color(0.09, 0.07, 0.04)
	label("250 t", _m * Vector3(0, 3.47, -0.921), Vector3.FORWARD, 0.13, ink, 0.03)
	label("TYPE EP 250", _m * Vector3(0, 3.3, -0.928), Vector3.FORWARD, 0.05, engraved, 0.012)
	label("NR 4471", _m * Vector3(0, 3.235, -0.928), Vector3.FORWARD, 0.05, engraved, 0.012)
	label("P1", _m * Vector3(1.181, 2.6, 0.45), Vector3.RIGHT, 0.3, ink, 0.03)
	wall_decal("warning_1", _m * Vector3(-0.44, 2.22, -0.781), Vector3.FORWARD, 0.2, 0.2, Color.WHITE, 0.04)
	wall_decal("warning_1", _m * Vector3(0.44, 2.22, -0.781), Vector3.FORWARD, 0.2, 0.2, Color.WHITE, 0.04)

	# Slide between its gibs, and the die set it works.
	for x in [-0.72, 0.72]:
		_block(GREEN, Vector3(x, 2.25, -0.5), Vector3(0.16, 1.1, 0.6), 0.03)
	_block(GREEN, Vector3(0, 2.3, -0.5), Vector3(1.28, 0.9, 0.56), 0.04)
	_turned(GREEN, Vector3(0, 2.42, -0.78), Vector3.FORWARD, PackedVector2Array([
		Vector2(0.26, 0), Vector2(0.26, 0.04), Vector2(0.16, 0.04), Vector2(0.16, 0.09), Vector2(0, 0.09),
	]))
	_bolt_circle(Vector3(0, 2.42, -0.82), Vector3.FORWARD, 0.21, 8)
	_block(YELLOW, Vector3(0, 1.93, -0.785), Vector3(1.28, 0.12, 0.012), 0.004)
	_block(BARE, Vector3(0, 1.8, -0.5), Vector3(1.1, 0.1, 0.5), 0.01)
	_block(IRON, Vector3(0, 1.7, -0.42), Vector3(0.8, 0.1, 0.44), 0.01)
	_bar(BARE, Vector3(0, 1.46, -0.42), Vector3(0, 1.65, -0.42), 0.09, 16)
	_block(IRON, Vector3(0, 1.22, -0.42), Vector3(0.8, 0.1, 0.44), 0.01)
	_block(BARE, Vector3(0, 1.31, -0.42), Vector3(0.34, 0.08, 0.3), 0.008)
	for x in [-0.31, 0.31]:
		_bar(BARE, Vector3(x, 1.27, -0.27), Vector3(x, 1.68, -0.27), 0.028)
		_bar(IRON, Vector3(x, 1.55, -0.27), Vector3(x, 1.65, -0.27), 0.045)
		_bolt(Vector3(x * 1.1, 1.27, -0.59), Vector3.UP)

	# Crankshaft through the head: flywheel on one end, clutch on the other.
	var shaft := Vector3(0, 3.25, -0.2)
	_turned(GREEN, shaft + Vector3(1.25, 0, 0), Vector3.RIGHT, PackedVector2Array([
		Vector2(0.3, 0), Vector2(0.3, 0.08), Vector2(0.2, 0.08), Vector2(0.2, 0.14), Vector2(0, 0.14),
	]))
	_bolt_circle(shaft + Vector3(1.33, 0, 0), Vector3.RIGHT, 0.25, 6)
	_bar(BARE, shaft + Vector3(1.39, 0, 0), shaft + Vector3(1.9, 0, 0), 0.085, 16)
	_bar(IRON, shaft + Vector3(1.9, 0, 0), shaft + Vector3(1.94, 0, 0), 0.12, 6)
	var wheel := shaft + Vector3(1.7, 0, 0)
	_flywheel(wheel, 0.8, 0.22)
	_turned(GREEN, shaft + Vector3(-1.25, 0, 0), Vector3.LEFT, PackedVector2Array([
		Vector2(0.44, 0), Vector2(0.44, 0.22), Vector2(0.38, 0.28), Vector2(0.14, 0.28), Vector2(0.14, 0.36), Vector2(0, 0.36),
	]), 32)
	_bolt_circle(shaft + Vector3(-1.53, 0, 0), Vector3.LEFT, 0.28, 8)

	# Motor on the head, belted to the flywheel.
	var motor := Vector3(0.95, 4.0, 0.5)
	_block(IRON, motor + Vector3(0, -0.23, 0), Vector3(0.7, 0.04, 0.56), 0.006)
	_motor(BLUE, motor - Vector3(0.28, 0, 0), Vector3.RIGHT, 0.2, 0.56)
	var pulley := motor + Vector3(0.75, 0, 0)
	_bar(BARE, motor + Vector3(0.28, 0, 0), pulley + Vector3(0.14, 0, 0), 0.03)
	_bar(IRON, pulley - Vector3(0.11, 0, 0), pulley + Vector3(0.11, 0, 0), 0.11, 20)
	var between := pulley - wheel
	var lean := (0.8 - 0.11) / between.length()
	for way: float in [-1.0, 1.0]:
		# Where a straight run of belt leaves both wheels.
		var touch := between.normalized() * lean + Vector3.RIGHT.cross(between).normalized() * way * sqrt(1.0 - lean * lean)
		beam(RUBBER, _m * (wheel + touch * 0.805), _m * (pulley + touch * 0.115), 0.16, NO_COLLIDE, 0.012)

	# Air receiver for the clutch, with its line down to the housing.
	var receiver := Vector3(-0.7, 3.75, 0.5)
	_block(IRON, receiver + Vector3(0, 0.03, 0), Vector3(0.5, 0.06, 0.5), 0.01)
	_turned(YELLOW, receiver + Vector3(0, 0.04, 0), Vector3.UP, PackedVector2Array([
		Vector2(0, 0), Vector2(0.2, 0.015), Vector2(0.29, 0.07), Vector2(0.32, 0.16),
		Vector2(0.32, 0.76), Vector2(0.29, 0.85), Vector2(0.2, 0.905), Vector2(0, 0.92),
	]), 24, true)
	_bar(BARE, receiver + Vector3(0, 0.94, 0), receiver + Vector3(0, 1.04, 0), 0.03)
	_turned(BRASS, receiver + Vector3(0, 0.6, -0.32), Vector3.FORWARD, PackedVector2Array([Vector2(0.055, 0), Vector2(0.055, 0.03), Vector2(0, 0.03)]), 16)
	_line(IRON, [receiver + Vector3(0, 1.0, 0), receiver + Vector3(-0.25, 1.06, -0.1), receiver + Vector3(-0.72, 0.5, -0.45), shaft + Vector3(-1.4, 0.36, 0)], 0.018)

	# Oiler on the west cheek with copper lines to the bearings and the gib.
	var oiler := Vector3(-1.24, 2.45, 0.25)
	_block(IRON, oiler, Vector3(0.12, 0.22, 0.16), 0.015)
	_line(BRASS, [oiler + Vector3(0, 0.1, 0.03), Vector3(-1.2, 2.8, 0.25), Vector3(-1.2, 3.05, 0.05), shaft + Vector3(-1.3, -0.3, 0)], 0.006)
	_line(BRASS, [oiler + Vector3(0, 0.1, -0.03), Vector3(-1.2, 2.7, 0.1), Vector3(-1.2, 2.55, -0.14), Vector3(-1.0, 2.5, -0.19), Vector3(-0.76, 2.5, -0.3)], 0.006)

	# Electrics: the box on the cheek, conduit over the head to the motor and
	# a pendant with the run buttons and the emergency stop.
	mount("power_box_01", _m * Vector3(-1.18, 1.7, 0.5), -90)
	_line(IRON, [Vector3(-1.2, 1.9, 0.5), Vector3(-1.2, 2.6, 0.6), Vector3(-1.27, 3.4, 0.62), Vector3(-1.1, 3.77, 0.9), Vector3(0.5, 3.77, 0.9), Vector3(0.95, 3.9, 0.78), motor + Vector3(0, 0.24, 0)], 0.018)
	_bar(IRON, Vector3(1.1, 2.76, -0.8), Vector3(1.1, 1.74, -0.8), 0.018)
	var pendant := Vector3(1.1, 1.6, -0.82)
	_block(IRON, pendant, Vector3(0.3, 0.3, 0.14), 0.02)
	_turned(RED, pendant + Vector3(0, 0.07, -0.07), Vector3.FORWARD, PackedVector2Array([
		Vector2(0.02, 0), Vector2(0.02, 0.02), Vector2(0.04, 0.02), Vector2(0.04, 0.035), Vector2(0.025, 0.045), Vector2(0, 0.045),
	]), 12)
	for x in [-0.08, 0.08]:
		_bar(RUBBER, pendant + Vector3(x, -0.06, -0.07), pendant + Vector3(x, -0.06, -0.085), 0.03)
	_block(YELLOW, Vector3(0.35, 0.05, -1.42), Vector3(0.26, 0.1, 0.34), 0.02)
	_line(RUBBER, [Vector3(0.35, 0.05, -1.3), Vector3(0.5, 0.02, -1.2), Vector3(0.75, 0.03, -1.14), Vector3(0.85, 0.2, -0.92)], 0.012)

	# Lubrication unit behind the bed: tank, pump and the lines up to the head.
	var lube := Vector3(-0.55, 0, 1.3)
	_collide_box(_m * Transform3D(Basis(), lube + Vector3(0, 0.4, 0)), Vector3(0.9, 0.8, 0.4), "metal")
	_block(IRON, lube + Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.4), 0.03)
	_motor(BLUE, lube + Vector3(-0.3, 0.73, 0), Vector3.RIGHT, 0.1, 0.3)
	_block(IRON, lube + Vector3(0.2, 0.7, 0), Vector3(0.16, 0.2, 0.18), 0.02)
	_turned(BRASS, lube + Vector3(-0.2, 0.42, 0.2), Vector3.BACK, PackedVector2Array([Vector2(0.045, 0), Vector2(0.045, 0.02), Vector2(0, 0.02)]), 16)
	for x: float in [0.17, 0.23]:
		_line(IRON, [lube + Vector3(x, 0.78, 0), lube + Vector3(x, 1.2, -0.2), Vector3(x - 0.75, 2.1, 1.1), Vector3(x - 0.75, 2.95, 1.05)], 0.012)

	# Oil has run down from the bearings and the slide.
	wall_decal("leak_1", _m * Vector3(1.2, 2.2, -0.1), Vector3.RIGHT, 0.7, 1.8)
	wall_decal("leak_2", _m * Vector3(0.2, 1.9, 1.02), Vector3.BACK, 1.0, 2.2)
	wall_decal("leak_2", _m * Vector3(-0.3, 0.62, -0.9), Vector3.FORWARD, 0.9, 1.0)


## Engine lathe, six metres long, with a shaft between its centres that is
## half turned. `at` is the middle of its footprint; the headstock is at the
## west end and the operator stands on the north side.
func lathe(at: Vector3) -> void:
	_m = Transform3D(Basis(), at)
	_collide_box(_m * Transform3D(Basis(), Vector3(0, 0.56, 0)), Vector3(6.0, 1.12, 1.4), "metal")
	_collide_box(_m * Transform3D(Basis(), Vector3(-2.25, 1.6, 0)), Vector3(1.6, 1.04, 1.1), "metal")
	_collide_box(_m * Transform3D(Basis(), Vector3(2.45, 1.4, 0)), Vector3(0.7, 0.56, 0.66), "metal")
	_collide_box(_m * Transform3D(Basis(), Vector3(0.45, 1.42, 0)), Vector3(3.3, 0.6, 0.5), "metal")
	var axis := 1.5

	# Pedestals with the chip tray between them, and the bed with its ways.
	_block(BLUE, Vector3(-2.2, 0.44, 0), Vector3(1.5, 0.88, 1.3), 0.05)
	_louvred_door(BLUE, Vector3(-2.2, 0.46, -0.65), Vector3.FORWARD, Vector2(0.9, 0.62))
	_louvred_door(BLUE, Vector3(-2.2, 0.46, 0.65), Vector3.BACK, Vector2(0.9, 0.62))
	_block(BLUE, Vector3(2.4, 0.44, 0), Vector3(0.9, 0.88, 1.1), 0.05)
	_block(BLUE, Vector3(0.3, 0.44, 0), Vector3(0.4, 0.88, 0.9), 0.04)
	_block(BLUE, Vector3(0.25, 0.33, 0), Vector3(3.4, 0.03, 1.36), 0.004)
	for z in [-0.68, 0.68]:
		_block(BLUE, Vector3(0.25, 0.4, z), Vector3(3.4, 0.14, 0.03), 0.004)
	_block(BLUE, Vector3(0.3, 0.98, 0), Vector3(5.3, 0.2, 0.78), 0.03)
	_block(BARE, Vector3(0.3, 1.1, -0.27), Vector3(5.3, 0.045, 0.1), 0.004)
	_block(BARE, Vector3(0.3, 1.105, -0.27), Vector3(5.3, 0.06, 0.06), 0.002, Vector3(45, 0, 0))
	_block(BARE, Vector3(0.3, 1.1, 0.27), Vector3(5.3, 0.045, 0.12), 0.004)
	# Lead screw, feed rod and control rod along the front.
	_bar(BARE, Vector3(-1.5, 0.93, -0.45), Vector3(2.92, 0.93, -0.45), 0.022)
	_bar(BARE, Vector3(-1.5, 0.86, -0.45), Vector3(2.92, 0.86, -0.45), 0.016)
	_bar(BARE, Vector3(-1.5, 0.79, -0.45), Vector3(2.92, 0.79, -0.45), 0.012)
	_block(BLUE, Vector3(2.92, 0.86, -0.45), Vector3(0.1, 0.28, 0.12), 0.02)
	_block(IRON, Vector3(0.6, 1.03, -0.4), Vector3(4.4, 0.03, 0.02), 0.0)

	# Headstock with its gearbox, levers and chuck.
	_block(BLUE, Vector3(-2.2, 1.6, 0), Vector3(1.5, 1.04, 1.1), 0.07)
	_block(BLUE, Vector3(-2.2, 2.13, 0), Vector3(1.3, 0.04, 0.9), 0.015)
	_block(BLUE, Vector3(-3.0, 1.25, 0), Vector3(0.12, 1.7, 1.0), 0.04)
	_block(BLUE, Vector3(-2.2, 0.99, -0.52), Vector3(1.3, 0.34, 0.26), 0.03)
	_block(BRASS, Vector3(-2.45, 1.85, -0.553), Vector3(0.34, 0.2, 0.008), 0.003)
	_block(BRASS, Vector3(-2.3, 1.0, -0.653), Vector3(0.5, 0.12, 0.008), 0.003)
	label("TYPE DB 6000", _m * Vector3(-2.45, 1.885, -0.558), Vector3.FORWARD, 0.05, Color(0.09, 0.07, 0.04), 0.012)
	label("NR 2209", _m * Vector3(-2.45, 1.815, -0.558), Vector3.FORWARD, 0.05, Color(0.09, 0.07, 0.04), 0.012)
	label("D1", _m * Vector3(-2.72, 0.5, -0.651), Vector3.FORWARD, 0.2, Color(0.84, 0.84, 0.8), 0.03)
	wall_decal("warning_1", _m * Vector3(-1.98, 2.0, -0.551), Vector3.FORWARD, 0.16, 0.16, Color.WHITE, 0.04)
	for i in 3:
		_lever(Vector3(-2.75 + i * 0.3, 1.48, -0.55), Vector3.FORWARD, Vector3(0.3 - i * 0.3, -1, 0), 0.16)
	for x in [-2.7, -1.85]:
		_lever(Vector3(x, 0.94, -0.65), Vector3.FORWARD, Vector3(0.4, 1, 0), 0.13)
	_block(IRON, Vector3(-1.72, 1.8, -0.56), Vector3(0.14, 0.22, 0.04), 0.01)
	_bar(RED, Vector3(-1.72, 1.85, -0.58), Vector3(-1.72, 1.85, -0.6), 0.025)
	_bar(GREEN, Vector3(-1.72, 1.76, -0.58), Vector3(-1.72, 1.76, -0.595), 0.022)
	var nose := Vector3(-1.45, axis, 0)
	_turned(BARE, nose, Vector3.RIGHT, PackedVector2Array([Vector2(0.2, 0), Vector2(0.2, 0.06), Vector2(0.16, 0.08), Vector2(0.16, 0.12)]))
	_turned(BARE, nose + Vector3(0.12, 0, 0), Vector3.RIGHT, PackedVector2Array([
		Vector2(0.14, 0), Vector2(0.3, 0), Vector2(0.32, 0.02), Vector2(0.32, 0.2), Vector2(0.3, 0.22), Vector2(0.1, 0.22),
	]), 32)
	for i in 3:
		var turn := 120.0 * i + 20.0
		var out := Basis(Vector3.RIGHT, deg_to_rad(turn)) * Vector3.UP
		_block(IRON, nose + Vector3(0.37, 0, 0) + out * 0.22, Vector3(0.07, 0.18, 0.07), 0.006, Vector3(turn, 0, 0))
		_block(IRON, nose + Vector3(0.39, 0, 0) + out * 0.15, Vector3(0.11, 0.07, 0.07), 0.006, Vector3(turn, 0, 0))

	# The work: rough stock from the chuck up to the cut, turned bright beyond it.
	_bar(RUST, nose + Vector3(0.34, 0, 0), Vector3(0.62, axis, 0), 0.12, 20)
	_bar(BARE, Vector3(0.62, axis, 0), Vector3(2.03, axis, 0), 0.1, 20)

	# Carriage: saddle across the ways, apron down the front, slides and tool post on top.
	var saddle := Vector3(0.74, 1.17, 0)
	_block(BLUE, saddle, Vector3(0.75, 0.1, 0.9), 0.02)
	_block(BLUE, saddle + Vector3(0, -0.24, -0.46), Vector3(0.62, 0.44, 0.13), 0.03)
	_handwheel(saddle + Vector3(-0.18, -0.2, -0.58), Vector3.FORWARD, 0.1)
	_lever(saddle + Vector3(0.12, -0.14, -0.525), Vector3.FORWARD, Vector3(1, -0.6, 0), 0.12)
	_lever(saddle + Vector3(0.2, -0.34, -0.525), Vector3.FORWARD, Vector3(0.3, -1, 0), 0.1)
	_block(BLUE, saddle + Vector3(0, 0.09, -0.03), Vector3(0.34, 0.08, 0.84), 0.012)
	_bar(BARE, saddle + Vector3(0, 0.09, -0.45), saddle + Vector3(0, 0.09, -0.52), 0.016)
	_handwheel(saddle + Vector3(0, 0.09, -0.52), Vector3.FORWARD, 0.06)
	_block(BLUE, saddle + Vector3(0, 0.17, -0.28), Vector3(0.2, 0.08, 0.4), 0.012, Vector3(0, 20, 0))
	_block(IRON, saddle + Vector3(-0.02, 0.28, -0.25), Vector3(0.13, 0.14, 0.13), 0.01)
	_block(BARE, saddle + Vector3(-0.06, 0.32, -0.16), Vector3(0.03, 0.03, 0.14), 0.0)
	for x in [-0.05, 0.01]:
		_bolt(saddle + Vector3(x, 0.35, -0.25), Vector3.UP, 0.014)

	# Tailstock with its quill, centre and handwheel.
	var tail := Vector3(2.45, 0, 0)
	_block(BLUE, tail + Vector3(0, 1.2, 0), Vector3(0.5, 0.16, 0.66), 0.02)
	_block(BLUE, tail + Vector3(0, 1.42, 0), Vector3(0.4, 0.3, 0.3), 0.05)
	_turned(BLUE, tail + Vector3(-0.3, axis, 0), Vector3.RIGHT, PackedVector2Array([
		Vector2(0, 0), Vector2(0.085, 0), Vector2(0.11, 0.03), Vector2(0.11, 0.6), Vector2(0.085, 0.63), Vector2(0, 0.63),
	]))
	_bar(BARE, tail + Vector3(-0.39, axis, 0), tail + Vector3(-0.3, axis, 0), 0.05, 16)
	_turned(BARE, tail + Vector3(-0.39, axis, 0), Vector3.LEFT, PackedVector2Array([Vector2(0.045, 0), Vector2(0, 0.07)]), 16)
	_bar(BARE, tail + Vector3(0.33, axis, 0), tail + Vector3(0.4, axis, 0), 0.02)
	_handwheel(tail + Vector3(0.4, axis, 0), Vector3.RIGHT, 0.13)
	_lever(tail + Vector3(-0.05, 1.57, 0), Vector3.UP, Vector3(0.2, 0.5, 1), 0.14)
	for z in [-0.24, 0.24]:
		_bolt(tail + Vector3(0, 1.28, z), Vector3.UP)

	# Splash guard along the back and a work lamp on a gooseneck.
	_block(BLUE, Vector3(0.2, 1.45, 0.47), Vector3(2.9, 0.62, 0.02), 0.004)
	for x in [-1.0, 1.4]:
		_block(IRON, Vector3(x, 1.2, 0.44), Vector3(0.04, 0.2, 0.04), 0.004)
	# Somebody left the lamp on: it still shines on the chuck.
	var lamp_end := Vector3(-1.2, 2.42, 0.05)
	var aim := Vector3(0.3, -0.92, -0.1).normalized()
	_line(BARE, [Vector3(-1.75, 2.12, 0.35), Vector3(-1.75, 2.45, 0.35), Vector3(-1.5, 2.62, 0.22), lamp_end], 0.012)
	_turned(BLUE, lamp_end, aim, PackedVector2Array([
		Vector2(0.03, -0.02), Vector2(0.09, 0.1), Vector2(0.085, 0.1), Vector2(0.025, -0.015),
	]), 16)
	_ball("emissive_warm", lamp_end + aim * 0.05, 0.03)
	var light := SpotLight3D.new()
	light.name = "WorkLamp"
	light.transform = _m * Transform3D(_along(aim), lamp_end + aim * 0.1)
	light.light_color = Color(1.0, 0.74, 0.46)
	light.light_energy = 8.0
	light.light_volumetric_fog_energy = 0.5
	light.spot_range = 3.2
	light.spot_angle = 48.0
	light.spot_attenuation = 1.2
	light.shadow_enabled = true
	light.light_bake_mode = Light3D.BAKE_DYNAMIC
	_add(light, _lights)

	# At the back, where the sun finds them: the electrics and the coolant
	# tank, whose pump feeds a hose that ends over the tool.
	mount("power_box_01", _m * Vector3(-2.2, 1.6, 0.55), 0)
	_line(IRON, [Vector3(-2.2, 1.36, 0.57), Vector3(-2.2, 1.05, 0.62), Vector3(-2.2, 0.92, 0.69), Vector3(-2.2, 0.8, 0.64)], 0.018)
	_block(BLUE, Vector3(-2.2, 1.6, 0.553), Vector3(1.2, 0.8, 0.012), 0.004)
	var coolant := Vector3(1.3, 0, 0.8)
	_collide_box(_m * Transform3D(Basis(), coolant + Vector3(0, 0.3, 0)), Vector3(0.7, 0.6, 0.5), "metal")
	_block(BLUE, coolant + Vector3(0, 0.15, 0), Vector3(0.7, 0.3, 0.5), 0.02)
	_motor(IRON, coolant + Vector3(0, 0.3, 0.12), Vector3.UP, 0.07, 0.24, false)
	_line(RUBBER, [coolant + Vector3(0.1, 0.33, 0.12), coolant + Vector3(0.1, 0.9, 0), Vector3(1.15, 1.85, 0.5), Vector3(0.9, 1.8, 0.2), saddle + Vector3(0.02, 0.5, -0.08)], 0.012)
	wall_decal("leak_1", _m * Vector3(-1.9, 0.5, -0.64), Vector3.FORWARD, 0.8, 0.9)
	wall_decal("leak_2", _m * Vector3(0.9, 0.75, -0.4), Vector3.FORWARD, 1.2, 0.7)


## Workbenches with what a fitter needs, against the wall to the south of
## them, whose face is at `wall_z`; `at` is the middle of the two benches.
func workbench(at: Vector3, wall_z: float) -> void:
	var bench := "WoodenTable_03"
	var size: Vector3 = _model(bench).box.size
	for side in [-0.5, 0.5]:
		place(bench, at + Vector3(side * (size.x + 0.02), 0, 0), 180)
	var north := Basis(Vector3.UP, PI)
	var top := at + Vector3(0, size.y, 0)
	prop("old_drill_press", Transform3D(north * Basis(Vector3.UP, 0.1), top + Vector3(-0.85, 0, 0.03)))
	prop("drill_press_01", Transform3D(north * Basis(Vector3.UP, -0.15), top + Vector3(0.25, 0, 0.0)))
	prop("metal_toolbox", Transform3D(north * Basis(Vector3.UP, 0.3), top + Vector3(1.0, 0, 0.05)))
	# The vice is bolted on at the edge, since its handle hangs 9 cm below its foot.
	prop("bench_vice_01", Transform3D(north, top + Vector3(-0.3, -0.09, -size.z * 0.5 + 0.145)))
	place("metal_stool_02", at + Vector3(0.45, 0, -0.85), 25)
	# Whatever was in use when the last shift went home.
	var flat := Basis(Vector3.RIGHT, -PI * 0.5)
	drop("screwdrivers_02", top + Vector3(-0.08, 0, 0.14), 90)
	drop("adjustable_wrench", top + Vector3(0.6, 0, -0.12), 35, flat)
	drop("cross_pein_hammer", top + Vector3(0.62, 0, 0.12), 80, flat)
	drop("measuring_tape_01", top + Vector3(1.27, 0, -0.15), 10)
	drop("oil_tin", top + Vector3(-1.24, 0, -0.12), 200)
	place("metal_tool_chest", at + Vector3(-1.85, 0, 0.1), 180)
	drop("plastic_broom", at + Vector3(-2.75, 0, -0.2), 180)
	drop("sledgehammer_01", Vector3(at.x + 1.7, 0, wall_z - 0.13), 0, Basis(Vector3.RIGHT, 0.17) * Basis(Vector3.BACK, PI))
	drop("crowbar_01", Vector3(at.x + 1.95, 0, wall_z - 0.12), 0, Basis(Vector3.RIGHT, 0.2))
	mount("power_box_01", Vector3(at.x + 2.3, 1.75, wall_z), 180)
	# A fluorescent tube on brackets, so the bench is not lost in the shade
	# under the windows.
	var fixture := Vector3(at.x, 2.5, wall_z - 0.3)
	tube(fixture, true, true, true, 5.0)
	for x in [-0.5, 0.5]:
		box("steel", fixture + Vector3(x, 0.04, 0.19), Vector3(0.04, 0.04, 0.22), Vector3.ZERO, NO_COLLIDE)


## Double-girder overhead crane on runway beams along both long walls of a
## hall that runs along X. `center` is the middle of the floor of the hall,
## `half_length` and `half_width` half its measurements inside the walls, and
## `seat` the height of the corbels that the runway beams lie on. The bridge
## stands `parked` along the hall from its middle, with the hook block hanging
## down to above head height.
func crane(center: Vector3, half_length: float, half_width: float, seat: float, parked: float) -> void:
	# All of it is too thin or hangs too high up for a patch of lightmap.
	_part = DETAIL | NO_COLLIDE
	var span := half_width - 0.6

	# Runway beams on the corbels, a rail on each.
	_m = Transform3D(Basis(), center)
	for z: float in [-span, span]:
		_i_beam(RUST, Vector3(-half_length, seat, z), Vector3(half_length, seat, z), 0.25, 0.36)
		_plate(BARE, Vector3(0, seat + 0.38, z), Vector3(half_length * 2.0, 0.04, 0.05))

	# Everything that travels is built from the top of the rails up.
	_m = Transform3D(Basis(), center + Vector3(parked, seat + 0.4, 0))
	var wheel := PackedVector2Array([
		Vector2(0, 0), Vector2(1.18, 0), Vector2(1.18, 0.14), Vector2(1, 0.18),
		Vector2(1, 0.82), Vector2(1.18, 0.86), Vector2(1.18, 1), Vector2(0, 1),
	])

	# End carriages: a box section over two flanged wheels, a buffer at either
	# end and a travel drive on the inside.
	for sz: float in [-1.0, 1.0]:
		var z := sz * span
		_plate(YELLOW, Vector3(0, 0.25, z), Vector3(3.2, 0.34, 0.3))
		for sx: float in [-1.0, 1.0]:
			var axle := Vector3(sx * 1.25, 0.14, z)
			_turned(IRON, axle - Vector3(0, 0, 0.07), Vector3.BACK, Transform2D(0.0, Vector2(0.14, 0.14), 0.0, Vector2.ZERO) * wheel, 20)
			_turned(IRON, axle + Vector3(0, 0, sz * 0.15), Vector3(0, 0, sz), PackedVector2Array([Vector2(0.1, 0), Vector2(0.1, 0.03), Vector2(0, 0.04)]), 12)
			_bar(RUBBER, Vector3(sx * 1.6, 0.25, z), Vector3(sx * 1.72, 0.25, z), 0.06)
		_block(IRON, Vector3(1.25, 0.2, z - sz * 0.2), Vector3(0.22, 0.26, 0.1), 0.02)
		_motor(BLUE, Vector3(1.25, 0.2, z - sz * 0.56), Vector3(0, 0, sz), 0.09, 0.3, false)

	# Two box girders, stiffened down the outside, with a rail for the trolley.
	var reach := span - 0.15
	# A stiffener, and further down a bracket for the festoon, every 1.9 m.
	var ribs := roundi(reach * 2.0 / 1.9)
	for sx: float in [-1.0, 1.0]:
		var x := sx * 0.75
		_plate(YELLOW, Vector3(x, 0.35, 0), Vector3(0.36, 0.56, reach * 2.0))
		for y: float in [0.06, 0.64]:
			_plate(YELLOW, Vector3(x, y, 0), Vector3(0.44, 0.02, reach * 2.0))
		_plate(BARE, Vector3(x, 0.665, 0), Vector3(0.045, 0.03, reach * 2.0))
		for i in ribs:
			_plate(YELLOW, Vector3(x + sx * 0.2, 0.35, (i - (ribs - 1) * 0.5) * 1.9), Vector3(0.04, 0.56, 0.012))
		for sz: float in [-1.0, 1.0]:
			_plate(YELLOW, Vector3(x, 0.36, sz * (reach - 0.01)), Vector3(0.52, 0.66, 0.02))

	for sx: float in [-1.0, 1.0]:
		label("10 t", _m * Vector3(sx * 0.93, 0.35, -5.6), Vector3(sx, 0, 0), 0.34, Color(0.05, 0.05, 0.05))

	# Trolley: a frame on four wheels, the rope drum slung between the girders
	# and the hoist motor with its gearbox on the deck above.
	var at := 3.0
	for sx: float in [-1.0, 1.0]:
		_plate(GREEN, Vector3(sx * 0.75, 0.84, at), Vector3(0.16, 0.14, 1.4))
		_plate(GREEN, Vector3(sx * 0.5, 0.66, at), Vector3(0.03, 0.44, 0.3))
		for sz: float in [-1.0, 1.0]:
			_turned(IRON, Vector3(sx * 0.75 - 0.045, 0.76, at + sz * 0.5), Vector3.RIGHT, Transform2D(0.0, Vector2(0.08, 0.09), 0.0, Vector2.ZERO) * wheel, 16)
	for sz: float in [-1.0, 1.0]:
		_plate(GREEN, Vector3(0, 0.84, at + sz * 0.45), Vector3(1.34, 0.14, 0.12))
		_plate("deck", Vector3(0, 0.916, at + sz * 0.46), Vector3(1.66, 0.012, 0.44))
	_bar(IRON, Vector3(-0.42, 0.6, at), Vector3(0.42, 0.6, at), 0.17, 24)
	for sx: float in [-1.0, 1.0]:
		_bar(IRON, Vector3(sx * 0.42, 0.6, at), Vector3(sx * 0.45, 0.6, at), 0.21, 24)
	_bar(BARE, Vector3(-0.56, 0.6, at), Vector3(0.56, 0.6, at), 0.04)
	_motor(BLUE, Vector3(-0.66, 1.03, at + 0.46), Vector3.RIGHT, 0.1, 0.42)
	_block(IRON, Vector3(0.02, 1.03, at + 0.46), Vector3(0.36, 0.2, 0.36), 0.03)
	_bar(IRON, Vector3(0.2, 1.03, at + 0.46), Vector3(0.34, 1.03, at + 0.46), 0.09, 16)
	_block(BLUE, Vector3(0.4, 1.06, at - 0.46), Vector3(0.5, 0.28, 0.26), 0.015)
	_block(IRON, Vector3(-0.35, 0.98, at - 0.46), Vector3(0.4, 0.12, 0.3), 0.01)

	# Four falls of rope down to the hook block.
	var block := Vector3(0, center.y + 3.7 - _m.origin.y, at)
	for i in 4:
		var side := i - 1.5
		_bar(IRON, block + Vector3(side * 0.07, 0.14, 0), Vector3(side * 0.16, 0.5, at), 0.007, 6)
	for sx: float in [-1.0, 1.0]:
		_bar(IRON, block + Vector3(sx * 0.07 - 0.025, 0, 0), block + Vector3(sx * 0.07 + 0.025, 0, 0), 0.16, 24)
	for x: float in [-0.14, 0.0, 0.14]:
		_block(YELLOW, block + Vector3(x, -0.06, 0), Vector3(0.02, 0.5, 0.38), 0.008)
	_bar(BARE, block + Vector3(-0.18, 0, 0), block + Vector3(0.18, 0, 0), 0.035)
	_block(IRON, block + Vector3(0, -0.3, 0), Vector3(0.34, 0.1, 0.14), 0.02)
	_bar(BARE, block + Vector3(0, -0.4, 0), block + Vector3(0, -0.24, 0), 0.05, 8)
	var tip := block + Vector3(0, -0.58, 0.13)
	_line(IRON, [
		block + Vector3(0, -0.3, 0), block + Vector3(0, -0.46, 0), block + Vector3(0, -0.56, -0.05), block + Vector3(0, -0.66, -0.06),
		block + Vector3(0, -0.75, 0), block + Vector3(0, -0.74, 0.09), block + Vector3(0, -0.66, 0.14), tip,
	], 0.035, 10)
	_ball(IRON, tip, 0.035)
	_collide_box(_m * Transform3D(Basis(), block + Vector3(0, -0.3, 0)), Vector3(0.34, 1.0, 0.4), "metal")

	# Festoon: the trolley's cable hangs in loops from runners on a track, and
	# the pendant hangs from a runner of its own down to hand height.
	var track := Vector3(1.22, 0.72, 0)
	_plate(IRON, track, Vector3(0.04, 0.04, reach * 2.0))
	for i in ribs:
		_plate(IRON, Vector3(1.08, 0.7, (i - (ribs - 1) * 0.5) * 1.9), Vector3(0.28, 0.03, 0.03))
	var runners := 9
	var from := -reach + 0.4
	var loop := (at - from) / runners
	for i in runners + 1:
		var runner := track + Vector3(0, -0.06, from + i * loop)
		_plate(IRON, runner, Vector3(0.03, 0.08, 0.1))
		if i < runners:
			var low := Vector3(0, -0.55, 0)
			var along := Vector3(0, 0, loop)
			_line(RUBBER, [runner, runner + along * 0.2 + low * 0.75, runner + along * 0.5 + low, runner + along * 0.8 + low * 0.75, runner + along], 0.014)
	_line(RUBBER, [track + Vector3(0, -0.06, at), Vector3(1.1, 0.86, at - 0.15), Vector3(0.62, 1.0, at - 0.46)], 0.014)
	var hang := track + Vector3(0, -0.06, at + 0.8)
	var pendant := Vector3(hang.x, center.y + 1.3 - _m.origin.y, hang.z)
	_plate(IRON, hang, Vector3(0.03, 0.08, 0.1))
	_line(RUBBER, [hang, hang.lerp(pendant, 0.5) + Vector3(0.02, 0, 0.03), pendant + Vector3(0, 0.15, 0)], 0.011)
	_block(YELLOW, pendant, Vector3(0.08, 0.34, 0.09), 0.02)
	var buttons: Array[String] = [RED, GREEN, RUBBER, RUBBER, RUBBER, RUBBER]
	for i in buttons.size():
		var button := pendant + Vector3(-0.04, 0.12 - i * 0.048, 0)
		_bar(buttons[i], button, button - Vector3(0.012, 0, 0), 0.015, 8)
	_part = NO_COLLIDE
