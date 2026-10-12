extends "res://tools/model_builder.gd"
## What an army drives: a jeep, a lorry with a tilt over its bed, and a tank,
## that one twice: with its gun ahead and with its turret traversed. Build
## with tools/build_model.sh vehicles; stand one in a level to look at it with
## tools/benchmark.sh --quick --spawn="res://scenes/models/tank.scn@4,0,0,30".
##
## A vehicle stands on the ground at the origin with its nose along -Z. It is
## one mesh and nothing of it moves: it is parked. A level stands it with
## vehicle() in tools/kit/field.gd, which knows what of it is in the way.

const ARMY := "army_green"
const IRON := "dark_steel"
const BARE := "bare_steel"
const RUBBER := "rubber"
const CANVAS := "canvas"
## A side view drawn as (towards the back, up) and pushed out across the
## vehicle: the frame extrude() wants for it.
const SIDE := Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT)


func _describe() -> void:
	_jeep()
	_truck()
	_tank("tank", 0.0)
	_tank("tank_b", 38.0)


## A wheel with its middle at `at`, on an axle that leaves the vehicle along
## `out`: the tyre, and the dish of the rim in it.
func _wheel(at: Vector3, radius: float, width: float, out: Vector3) -> void:
	var from := at - out * width * 0.5
	_turned(RUBBER, from, out, PackedVector2Array([
		Vector2(radius * 0.58, 0), Vector2(radius * 0.9, 0), Vector2(radius, width * 0.22), Vector2(radius, width * 0.78), Vector2(radius * 0.9, width), Vector2(radius * 0.58, width),
	]), 16)
	_turned(ARMY, from, out, PackedVector2Array([
		Vector2(radius * 0.58, width), Vector2(radius * 0.52, width * 0.7), Vector2(radius * 0.2, width * 0.7), Vector2(radius * 0.16, width * 0.92), Vector2(0, width * 0.92),
	]), 16)


## A quarter-ton field car: a flat bonnet between flat wings, a slotted
## grille, a screen that folds, four seats and the spare on the back.
func _jeep() -> void:
	model("jeep")
	var r := 0.37
	for x: float in [-0.68, 0.68]:
		for z: float in [-1.05, 1.0]:
			_wheel(Vector3(x, r, z), r, 0.17, Vector3(signf(x), 0, 0))
	_plate(IRON, Vector3(0, 0.48, 0), Vector3(0.8, 0.12, 3.1))
	# The tub: a floor with a side either way and a panel behind; the
	# scuttle, and the bonnet.
	_block(ARMY, Vector3(0, 0.62, 0.55), Vector3(1.5, 0.3, 1.9), 0.03)
	for x: float in [-0.73, 0.73]:
		_plate(ARMY, Vector3(x, 0.9, 0.62), Vector3(0.04, 0.3, 1.76))
	_plate(ARMY, Vector3(0, 0.9, 1.48), Vector3(1.5, 0.3, 0.04))
	_block(ARMY, Vector3(0, 0.9, -0.52), Vector3(1.5, 0.5, 0.3), 0.04)
	_block(ARMY, Vector3(0, 0.88, -1.12), Vector3(0.98, 0.42, 1.0), 0.05)
	for x: float in [-0.63, 0.63]:
		_block(ARMY, Vector3(x, 0.8, -1.08), Vector3(0.3, 0.04, 0.95), 0.015)
		_block(ARMY, Vector3(x, 0.69, -1.6), Vector3(0.3, 0.26, 0.04), 0.015, Vector3(-20, 0, 0))
		_bar(BARE, Vector3(x * 0.6, 0.88, -1.63), Vector3(x * 0.6, 0.88, -1.67), 0.075, 12)
	_plate(ARMY, Vector3(0, 0.84, -1.63), Vector3(0.98, 0.5, 0.03))
	for i in 9:
		_plate(IRON, Vector3((i - 4) * 0.068, 0.86, -1.648), Vector3(0.034, 0.34, 0.006))
	_plate(ARMY, Vector3(0, 0.52, -1.76), Vector3(1.5, 0.1, 0.06))
	_plate(ARMY, Vector3(0, 0.52, 1.56), Vector3(1.5, 0.1, 0.06))
	# The screen: a frame with two panes, leaning back.
	var lean := Vector3(-10, 0, 0)
	_block(ARMY, Vector3(0, 1.58, -0.61), Vector3(1.46, 0.04, 0.04), 0.01, lean)
	_block(ARMY, Vector3(0, 1.16, -0.535), Vector3(1.46, 0.04, 0.04), 0.01, lean)
	for x: float in [-0.71, 0.0, 0.71]:
		_block(ARMY, Vector3(x, 1.37, -0.572), Vector3(0.04, 0.44, 0.04), 0.01, lean)
	_block("glass", Vector3(0, 1.37, -0.572), Vector3(1.4, 0.4, 0.008), 0.002, lean)
	# Seats, the wheel, and what hangs on the back.
	for x: float in [-0.36, 0.36]:
		_block(CANVAS, Vector3(x, 0.84, -0.02), Vector3(0.44, 0.12, 0.44), 0.03)
		_block(CANVAS, Vector3(x, 1.08, 0.2), Vector3(0.44, 0.42, 0.08), 0.03, Vector3(8, 0, 0))
	_block(CANVAS, Vector3(0, 0.86, 1.05), Vector3(1.1, 0.12, 0.4), 0.03)
	_block(CANVAS, Vector3(0, 1.08, 1.3), Vector3(1.1, 0.4, 0.08), 0.03, Vector3(6, 0, 0))
	_bar(IRON, Vector3(-0.36, 0.95, -0.55), Vector3(-0.36, 1.16, -0.3), 0.015, 6)
	_ring(IRON, Vector3(-0.36, 1.17, -0.29), Vector3(0, 0.7, 0.7), 0.18, 0.012)
	_wheel(Vector3(0.35, 0.9, 1.6), r, 0.17, Vector3.BACK)
	_block(ARMY, Vector3(-0.42, 0.86, 1.6), Vector3(0.34, 0.46, 0.14), 0.03)
	_plate(BARE, Vector3(-0.42, 1.11, 1.6), Vector3(0.1, 0.03, 0.05))


## A cargo lorry of two and a half tons: a bonnet between its wings, a cab
## under a canvas top, and a bed of boards with a tilt over its hoops. Six
## wheels, the rear four on two axles.
func _truck() -> void:
	model("truck")
	var r := 0.5
	for x: float in [-0.98, 0.98]:
		_wheel(Vector3(x, r, -2.25), r, 0.28, Vector3(signf(x), 0, 0))
		for z: float in [1.15, 2.3]:
			_wheel(Vector3(x * 0.92, r, z), r, 0.5, Vector3(signf(x), 0, 0))
		_plate(IRON, Vector3(x * 0.42, 0.78, 0.3), Vector3(0.1, 0.2, 6.2))
		# Wings over the front wheels, and a step under each door.
		_block(ARMY, Vector3(x, 1.14, -2.25), Vector3(0.5, 0.07, 1.3), 0.03)
		_block(ARMY, Vector3(x, 0.98, -2.95), Vector3(0.5, 0.36, 0.06), 0.02, Vector3(-25, 0, 0))
		_plate(ARMY, Vector3(x * 1.08, 0.72, -1.15), Vector3(0.26, 0.04, 0.8))
		_bar(BARE, Vector3(x * 0.72, 1.3, -3.2), Vector3(x * 0.72, 1.3, -3.25), 0.1, 12)
	_plate(IRON, Vector3(0, 0.7, 1.72), Vector3(1.9, 0.14, 0.14))
	# Bonnet, radiator guard and bumper.
	_block(ARMY, Vector3(0, 1.48, -2.5), Vector3(1.46, 0.72, 1.5), 0.08)
	_plate(ARMY, Vector3(0, 1.4, -3.27), Vector3(1.5, 0.9, 0.04))
	for i in 7:
		_plate(IRON, Vector3((i - 3) * 0.19, 1.42, -3.3), Vector3(0.04, 0.8, 0.03))
	_plate(ARMY, Vector3(0, 0.82, -3.4), Vector3(2.3, 0.2, 0.1))
	# The cab: steel to the waist, a screen in two panes, canvas over it.
	_block(ARMY, Vector3(0, 1.5, -1.15), Vector3(2.0, 0.9, 1.15), 0.06)
	_block(ARMY, Vector3(0, 2.2, -1.68), Vector3(1.96, 0.56, 0.05), 0.02, Vector3(-8, 0, 0))
	_block("glass", Vector3(-0.47, 2.21, -1.71), Vector3(0.8, 0.4, 0.01), 0.002, Vector3(-8, 0, 0))
	_block("glass", Vector3(0.47, 2.21, -1.71), Vector3(0.8, 0.4, 0.01), 0.002, Vector3(-8, 0, 0))
	_block(CANVAS, Vector3(0, 2.5, -1.12), Vector3(2.02, 0.1, 1.26), 0.04)
	_block(CANVAS, Vector3(0, 2.2, -0.56), Vector3(2.0, 0.6, 0.06), 0.03)
	# The bed, its sides and tailboard, and the tilt.
	_plate("wood", Vector3(0, 1.26, 1.6), Vector3(2.34, 0.1, 3.9))
	for x: float in [-1.15, 1.15]:
		_plate(ARMY, Vector3(x, 1.66, 1.6), Vector3(0.05, 0.72, 3.9))
		for z: float in [0.0, 1.3, 2.6, 3.5]:
			_plate(ARMY, Vector3(x * 1.03, 1.66, z - 0.2), Vector3(0.04, 0.72, 0.08))
	_plate(ARMY, Vector3(0, 1.66, 3.53), Vector3(2.34, 0.72, 0.05))
	_plate(ARMY, Vector3(0, 1.66, -0.33), Vector3(2.34, 0.72, 0.05))
	extrude(CANVAS, PackedVector2Array([
		Vector2(-1.18, 0), Vector2(1.18, 0), Vector2(1.18, 0.66), Vector2(0.74, 1.06), Vector2(-0.74, 1.06), Vector2(-1.18, 0.66),
	]), 3.86, Transform3D(Basis(), Vector3(0, 2.0, 1.6)), _part)
	# The tank under the bed, and the spare behind the cab.
	_bar(ARMY, Vector3(-1.02, 0.95, -0.2), Vector3(-1.02, 0.95, 0.6), 0.24, 12)
	_wheel(Vector3(1.0, 1.5, -0.2), r, 0.28, Vector3.RIGHT)


## A medium tank: a hull with a sloped front over tracks behind skirts, and
## a cast turret with a long gun, turned `traverse_deg` to its right.
func _tank(tank: String, traverse_deg: float) -> void:
	model(tank)
	for side: float in [-1.0, 1.0]:
		var x := side * 1.22
		# The track: what of it shows under the skirt, and the wheels it runs on.
		_plate(IRON, Vector3(x, 0.07, -0.1), Vector3(0.55, 0.08, 4.9))
		_block(IRON, Vector3(x, 0.36, -2.72), Vector3(0.55, 0.08, 0.72), 0.01, Vector3(-52, 0, 0))
		_block(IRON, Vector3(x, 0.34, 2.62), Vector3(0.55, 0.08, 0.76), 0.01, Vector3(48, 0, 0))
		_plate(IRON, Vector3(x, 0.98, -0.05), Vector3(0.55, 0.07, 5.3))
		for i in 6:
			var z := -2.1 + i * 0.82
			_bar(ARMY, Vector3(x - side * 0.2, 0.43, z), Vector3(x + side * 0.27, 0.43, z), 0.34, 14)
			_bar(IRON, Vector3(x + side * 0.27, 0.43, z), Vector3(x + side * 0.3, 0.43, z), 0.12, 8)
		for z: float in [-2.82, 2.74]:
			_bar(ARMY, Vector3(x - side * 0.2, 0.66, z), Vector3(x + side * 0.27, 0.66, z), 0.3, 12)
		for i in 14:
			_plate(IRON, Vector3(x, 0.115, -2.4 + i * 0.36), Vector3(0.57, 0.03, 0.09))
		_plate(ARMY, Vector3(x + side * 0.3, 0.9, -0.05), Vector3(0.04, 0.46, 5.1))
		# Stowage on the track guards, the exhaust, a lamp.
		_block(ARMY, Vector3(x, 1.63, 1.0), Vector3(0.46, 0.2, 1.3), 0.02)
		_block(ARMY, Vector3(x, 1.63, -0.9), Vector3(0.46, 0.2, 0.9), 0.02)
		_bar("steel", Vector3(side * 0.9, 1.3, 2.95), Vector3(side * 0.9, 1.3, 3.2), 0.07, 8)
		_bar(BARE, Vector3(side * 1.05, 1.42, -2.55), Vector3(side * 1.05, 1.44, -2.62), 0.08, 10)
	# The hull: a tub between the tracks, and over them the box with its
	# sloped front plate.
	_plate(ARMY, Vector3(0, 0.62, 0), Vector3(1.9, 0.76, 5.5))
	_block(ARMY, Vector3(0, 0.74, -2.8), Vector3(1.9, 0.5, 0.42), 0.05, Vector3(35, 0, 0))
	extrude(ARMY, PackedVector2Array([Vector2(-3.0, 1.0), Vector2(2.95, 1.0), Vector2(2.95, 1.16), Vector2(2.5, 1.53), Vector2(-2.1, 1.53)]), 2.98, Transform3D(SIDE, Vector3.ZERO), _part)
	for x: float in [-0.55, 0.55]:
		_plate(IRON, Vector3(x, 1.54, 1.95), Vector3(0.8, 0.02, 1.0))
		for i in 6:
			_plate(ARMY, Vector3(x, 1.555, 1.55 + i * 0.16), Vector3(0.8, 0.012, 0.04))
	for i in 5:
		_block(IRON, Vector3(-0.56 + i * 0.28, 1.31, -2.5), Vector3(0.24, 0.05, 0.4), 0.01, Vector3(30, 0, 0))
	_line(IRON, [Vector3(-0.9, 1.56, -1.5), Vector3(-1.05, 1.56, 0.4), Vector3(-0.7, 1.56, 2.3)], 0.018, 5)
	# The turret, on its ring.
	_bar(ARMY, Vector3(0, 1.5, -0.2), Vector3(0, 1.62, -0.2), 0.98, 20)
	_m = Transform3D(Basis(Vector3.UP, -deg_to_rad(traverse_deg)), Vector3(0, 0, -0.2))
	_block(ARMY, Vector3(0, 1.97, 0.2), Vector3(1.95, 0.72, 2.3), 0.22)
	_block(ARMY, Vector3(0, 1.95, -1.0), Vector3(1.4, 0.62, 0.8), 0.2)
	_block(ARMY, Vector3(0, 1.9, 1.6), Vector3(1.6, 0.5, 0.7), 0.08)
	_block(ARMY, Vector3(0, 1.95, -1.5), Vector3(0.8, 0.5, 0.36), 0.12)
	_bar(ARMY, Vector3(0, 1.95, -1.6), Vector3(0, 1.96, -2.3), 0.11, 12)
	_bar(ARMY, Vector3(0, 1.96, -2.3), Vector3(0, 1.99, -4.9), 0.07, 12)
	_bar(ARMY, Vector3(0, 1.975, -3.4), Vector3(0, 1.98, -3.9), 0.1, 12)
	_bar(ARMY, Vector3(0, 1.99, -4.9), Vector3(0, 1.99, -5.25), 0.1, 12)
	_turned(ARMY, Vector3(0.45, 2.33, 0.3), Vector3.UP, PackedVector2Array([Vector2(0.33, 0), Vector2(0.33, 0.16), Vector2(0.26, 0.22), Vector2(0, 0.22)]), 14)
	_bar(ARMY, Vector3(-0.45, 2.33, 0.3), Vector3(-0.45, 2.36, 0.3), 0.28, 12)
	_bar(IRON, Vector3(0.45, 2.55, 0.3), Vector3(0.45, 2.66, 0.2), 0.03, 6)
	_bar(IRON, Vector3(0.45, 2.66, 0.45), Vector3(0.45, 2.7, -0.55), 0.02, 6)
	_bar(IRON, Vector3(-0.7, 2.3, 1.1), Vector3(-0.72, 4.5, 1.25), 0.008, 4)
	_bar(CANVAS, Vector3(-0.7, 2.27, 1.62), Vector3(0.7, 2.27, 1.62), 0.14, 8)
	for x: float in [-1.0, 1.0]:
		for i in 3:
			_bar(ARMY, Vector3(x, 2.0 + i * 0.09, -0.75), Vector3(x * 1.08, 2.06 + i * 0.09, -1.05), 0.04, 6)
		_block(ARMY, Vector3(x * 0.99, 1.95, 0.8), Vector3(0.14, 0.46, 0.34), 0.03)
	_m = Transform3D()
