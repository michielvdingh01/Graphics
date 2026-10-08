extends "res://tools/model_builder.gd"
## The enemies: three guard robots on the same skeleton. Build with
## tools/build_model.sh enemies; stand one in a level to look at it with
## tools/benchmark.sh --quick --spawn="res://scenes/enemy.tscn@2,0,0,180".
##
## A robot faces -Z and stands on the ground at the origin, arms hanging by
## its sides; scripts/enemy_rig.gd poses and walks it. That script finds the
## joints by name: Hips, Torso, Head, ArmR/ForearmR, ArmL/ForearmL,
## ThighR/ShinR/FootR and their left counterparts. Parts whose name begins
## with Glow take the colour of the enemy's visor, Barrels spins, and the
## marker Muzzle is where its shots leave.

const FRAME := "robot_frame"
const STEEL := "gun_steel"
const BARE := "gun_bare"
const RUBBER := "rubber"
const GLOW := "robot_glow"
## A profile drawn from the robot's right-hand side is in (ahead, up).
const SIDE := Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT)

## How tall and how broad the robot being built is next to the grunt, and the
## paint on its armour.
var _tall := 1.0
var _broad := 1.0
var _armor := "robot_grey"


func _describe() -> void:
	_robot("grunt", 1.0, 1.0, "robot_grey", "rifle")
	_robot("rusher", 0.86, 0.8, "robot_orange", "blades")
	_robot("heavy", 1.15, 1.32, "robot_olive", "cannon")


## One robot: `tall` and `broad` scale the grunt's frame, `arms` is what it
## carries: "rifle" in the right forearm, "cannon" for a rotary one, or
## "blades" on both.
func _robot(robot_name: String, tall: float, broad: float, armor: String, arms: String) -> void:
	model(robot_name)
	_tall = tall
	_broad = broad * tall
	_armor = armor
	tag("stride", 0.8 * tall)
	tag("melee", arms == "blades")
	tag("bulk", broad)

	# Pelvis.
	part("Hips", _joint(0, 0.96, 0))
	_block(FRAME, _p(0, 0.97, 0.01), _d(0.3, 0.14, 0.2), 0.03 * _broad)
	_block(_armor, _p(0, 0.94, -0.095), _d(0.15, 0.17, 0.05), 0.02 * _broad)
	_block(_armor, _p(0, 0.97, 0.11), _d(0.2, 0.12, 0.04), 0.015 * _broad)
	for side: float in [-1.0, 1.0]:
		_ball(FRAME, _p(side * 0.115, 0.93, 0), 0.062 * _broad)
		_block(_armor, _p(side * 0.17, 0.97, 0), _d(0.05, 0.15, 0.17), 0.02 * _broad)

	_legs()
	_torso(arms)
	_head(arms)
	for side: float in [1.0, -1.0]:
		_arm(side, arms)


## Transform of a joint at (right, up, back), in the measures of the grunt.
func _joint(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), _p(x, y, z))


## A point given in the measures of the grunt, on the robot being built.
func _p(x: float, y: float, z: float) -> Vector3:
	return Vector3(x * _broad, y * _tall, z * _broad)


## A size given in the measures of the grunt.
func _d(x: float, y: float, z: float) -> Vector3:
	return Vector3(x * _broad, y * _tall, z * _broad)


## Armour cut to a side view of the robot: `outline` in (ahead, up) in the
## measures of the grunt, `width` across and centred `right` of the middle.
func _shell(mat: String, outline: Array, width: float, bevel := 0.02, right := 0.0) -> void:
	var points := PackedVector2Array()
	for corner: Vector2 in outline:
		points.append(Vector2(corner.x * _broad, corner.y * _tall))
	var area := 0.0
	for i in points.size():
		area += points[i].cross(points[(i + 1) % points.size()])
	if area < 0.0:
		points.reverse()
	slab(mat, Transform3D(SIDE, Vector3(right * _broad, 0, 0)), points, width * _broad, bevel * _broad, _part)


## Hinge pin across a joint, with a cap at either end.
func _hinge(at: Vector3, half: float, radius: float) -> void:
	_bar(FRAME, at - Vector3(half, 0, 0), at + Vector3(half, 0, 0), radius, 14)
	for side: float in [-1.0, 1.0]:
		_bar(BARE, at + Vector3(side * half, 0, 0), at + Vector3(side * (half + 0.006), 0, 0), radius * 0.55, 8)


func _legs() -> void:
	for side: float in [1.0, -1.0]:
		var leg := "R" if side > 0.0 else "L"
		var x := side * 0.115
		part("Thigh" + leg, _joint(x, 0.93, 0), "Hips")
		_bar(FRAME, _p(x, 0.93, 0), _p(x, 0.5, 0), 0.04 * _broad, 10)
		_shell(_armor, [Vector2(-0.085, 0.88), Vector2(-0.07, 0.56), Vector2(0.07, 0.55), Vector2(0.1, 0.72), Vector2(0.085, 0.9)], 0.15, 0.03, x)
		_block(_armor, _p(x + side * 0.075, 0.74, 0), _d(0.03, 0.26, 0.12), 0.012 * _broad)

		part("Shin" + leg, _joint(x, 0.5, 0), "Thigh" + leg)
		_hinge(_p(x, 0.5, 0), 0.075 * _broad, 0.052 * _broad)
		_bar(FRAME, _p(x, 0.5, 0), _p(x, 0.09, 0), 0.035 * _broad, 10)
		_shell(_armor, [Vector2(-0.07, 0.44), Vector2(-0.055, 0.14), Vector2(0.06, 0.13), Vector2(0.085, 0.36), Vector2(0.095, 0.52), Vector2(0.02, 0.56)], 0.13, 0.018, x)
		# Piston down the calf.
		_bar(FRAME, _p(x, 0.44, 0.075), _p(x, 0.28, 0.07), 0.021 * _broad, 10)
		_bar(BARE, _p(x, 0.28, 0.07), _p(x, 0.13, 0.055), 0.012 * _broad, 8)

		part("Foot" + leg, _joint(x, 0.09, 0), "Shin" + leg)
		_hinge(_p(x, 0.09, 0), 0.06 * _broad, 0.04 * _broad)
		_shell(FRAME, [Vector2(-0.1, 0.0), Vector2(0.17, 0.0), Vector2(0.18, 0.035), Vector2(0.09, 0.085), Vector2(-0.07, 0.085), Vector2(-0.11, 0.04)], 0.12, 0.02, x)
		_shell(_armor, [Vector2(0.05, 0.03), Vector2(0.185, 0.03), Vector2(0.185, 0.05), Vector2(0.1, 0.1), Vector2(0.05, 0.1)], 0.13, 0.02, x)
		_block(RUBBER, _p(x, 0.006, -0.035), _d(0.11, 0.012, 0.26), 0.005 * _broad)


func _torso(arms: String) -> void:
	part("Torso", _joint(0, 1.04, 0), "Hips")
	# Waist: a bellows between the pelvis and the chest.
	_bar(RUBBER, _p(0, 1.02, 0), _p(0, 1.17, 0), 0.105 * _broad, 16)
	for i in 3:
		_ring(RUBBER, _p(0, 1.05 + i * 0.04, 0), Vector3.UP, 0.108 * _broad, 0.013 * _tall)

	# Chest: a faceted shell, a plate over each breast, the power unit on the back.
	_shell(_armor, [
		Vector2(-0.15, 1.17), Vector2(0.11, 1.15), Vector2(0.18, 1.27), Vector2(0.185, 1.4), Vector2(0.12, 1.5), Vector2(-0.13, 1.5), Vector2(-0.16, 1.4),
	], 0.42, 0.035)
	for side: float in [-1.0, 1.0]:
		_block(_armor, _p(side * 0.105, 1.39, -0.175), _d(0.17, 0.14, 0.04), 0.02 * _broad, Vector3(-12, side * -14, 0))
		_block(FRAME, _p(side * 0.215, 1.27, 0), _d(0.03, 0.16, 0.2), 0.012 * _broad)
		_bar(FRAME, _p(side * 0.2, 1.42, 0), _p(side * 0.3, 1.42, 0), 0.058 * _broad, 14)
	_block(FRAME, _p(0, 1.25, -0.165), _d(0.2, 0.12, 0.04), 0.012 * _broad, Vector3(18, 0, 0))
	_block(FRAME, _p(0, 1.34, 0.18), _d(0.32, 0.3, 0.1), 0.03 * _broad)
	for i in 4:
		_plate(RUBBER, _p(0, 1.25 + i * 0.045, 0.2305), _d(0.2, 0.018, 0.002))
	for side: float in [-1.0, 1.0]:
		_bar(FRAME, _p(side * 0.11, 1.47, 0.19), _p(side * 0.11, 1.56, 0.2), 0.022 * _broad, 10)
		_bar(RUBBER, _p(side * 0.11, 1.558, 0.2), _p(side * 0.11, 1.562, 0.2), 0.016 * _broad, 10)
	_ring(FRAME, _p(0, 1.5, 0), Vector3.UP, 0.075 * _broad, 0.018 * _tall)
	if arms == "cannon":
		# Ammunition for the cannon rides on the back.
		_block(_armor, _p(0.02, 1.36, 0.27), _d(0.3, 0.26, 0.12), 0.025 * _broad)
		_line(STEEL, [_p(0.16, 1.3, 0.27), _p(0.27, 1.22, 0.2), _p(0.33, 1.16, 0.1)], 0.028 * _broad)
	elif arms == "rifle":
		_bar(FRAME, _p(-0.12, 1.5, 0.21), _p(-0.14, 1.83, 0.24), 0.005, 6)

	# What shows that it is switched on: a lamp in the chest.
	part("GlowCore", _joint(0, 1.04, 0), "Torso")
	_turned(GLOW, _p(0, 1.36, -0.19), Vector3.FORWARD, [Vector2(0.026 * _broad, 0), Vector2(0.026 * _broad, 0.012), Vector2(0, 0.016)], 12)
	part("Torso")
	_ring(FRAME, _p(0, 1.36, -0.198), Vector3.FORWARD, 0.03 * _broad, 0.007 * _broad)


func _head(arms: String) -> void:
	part("Head", _joint(0, 1.5, 0), "Torso")
	_bar(FRAME, _p(0, 1.48, 0), _p(0, 1.56, 0), 0.045 * _broad, 12)
	if arms == "blades":
		# Long and low, like the head of a dog.
		_shell(_armor, [Vector2(-0.1, 1.55), Vector2(0.12, 1.55), Vector2(0.2, 1.6), Vector2(0.19, 1.66), Vector2(0.05, 1.73), Vector2(-0.09, 1.72), Vector2(-0.12, 1.64)], 0.17, 0.03)
		_shell(FRAME, [Vector2(0.03, 1.535), Vector2(0.17, 1.55), Vector2(0.18, 1.585), Vector2(0.03, 1.58)], 0.12, 0.012)
	else:
		_shell(_armor, [Vector2(-0.11, 1.55), Vector2(0.1, 1.55), Vector2(0.135, 1.6), Vector2(0.125, 1.69), Vector2(0.05, 1.745), Vector2(-0.09, 1.745), Vector2(-0.125, 1.67)], 0.2, 0.035)
		_block(FRAME, _p(0, 1.575, -0.1), _d(0.13, 0.055, 0.07), 0.015 * _broad)
	for side: float in [-1.0, 1.0]:
		_bar(FRAME, _p(side * 0.08, 1.64, 0.01), _p(side * 0.115, 1.64, 0.01), 0.036 * _broad, 12)
	var face := 0.2 if arms == "blades" else 0.133
	part("GlowVisor", _joint(0, 1.5, 0), "Head")
	_block(GLOW, _p(0, 1.645 if arms != "blades" else 1.63, -face + 0.008), _d(0.15 if arms != "blades" else 0.11, 0.028, 0.03), 0.008 * _broad)
	part("Head")
	for side: float in [-1.0, 1.0]:
		_block(_armor, _p(side * 0.085, 1.645 if arms != "blades" else 1.63, -face + 0.02), _d(0.03, 0.05, 0.05), 0.01 * _broad)


## One arm, hanging straight down: `side` is 1 for the right.
func _arm(side: float, arms: String) -> void:
	var arm := "R" if side > 0.0 else "L"
	var x := side * 0.3
	part("Arm" + arm, _joint(x, 1.42, 0), "Torso")
	_shell(_armor, [Vector2(-0.1, 1.37), Vector2(0.1, 1.37), Vector2(0.11, 1.46), Vector2(0.06, 1.53), Vector2(-0.06, 1.53), Vector2(-0.11, 1.46)], 0.15, 0.035, x + side * 0.02)
	_bar(FRAME, _p(x, 1.42, 0), _p(x, 1.12, 0), 0.036 * _broad, 10)
	_block(_armor, _p(x + side * 0.01, 1.26, 0), _d(0.1, 0.2, 0.115), 0.028 * _broad)

	part("Forearm" + arm, _joint(x, 1.12, 0), "Arm" + arm)
	_hinge(_p(x, 1.12, 0), 0.058 * _broad, 0.044 * _broad)
	if arms == "blades":
		_block(_armor, _p(x, 0.99, 0), _d(0.09, 0.2, 0.1), 0.025 * _broad)
		slab(BARE, Transform3D(SIDE, Vector3((x + side * 0.03) * _broad, 0, 0)), PackedVector2Array([
			Vector2(-0.035 * _broad, 1.08 * _tall), Vector2(-0.03 * _broad, 0.62 * _tall), Vector2(0.01 * _broad, 0.36 * _tall),
			Vector2(0.045 * _broad, 0.6 * _tall), Vector2(0.06 * _broad, 1.08 * _tall),
		]), 0.014 * _broad, 0.006 * _broad, _part)
		for i in 2:
			_bar(FRAME, _p(x - 0.02, 1.04 - i * 0.1, 0.01), _p(x + 0.055 * side, 1.04 - i * 0.1, 0.01), 0.014 * _broad, 8)
		if side > 0.0:
			marker("Muzzle", _joint(x, 0.6, 0), "ForearmR")
		return
	if side < 0.0 or arms == "none":
		# A plain forearm with a three-fingered gripper.
		_block(_armor, _p(x, 0.98, 0), _d(0.1, 0.24, 0.11), 0.028 * _broad)
		_bar(FRAME, _p(x, 0.87, 0), _p(x, 0.82, 0), 0.034 * _broad, 10)
		_block(FRAME, _p(x, 0.79, 0), _d(0.085, 0.07, 0.055), 0.014 * _broad)
		for finger: Vector2 in [Vector2(-0.028, -0.012), Vector2(0.028, -0.012), Vector2(0, 0.022)]:
			_bar(FRAME, _p(x + finger.x, 0.76, finger.y), _p(x + finger.x * 1.2, 0.69, finger.y * 0.6 - 0.01), 0.011 * _broad, 8)
		if arms == "rifle":
			# The grunt carries a shield on this arm.
			_block(_armor, _p(x - 0.07, 1.0, -0.01), _d(0.025, 0.36, 0.24), 0.012 * _broad)
			_block("steel_yellow", _p(x - 0.0835, 1.08, -0.01), _d(0.004, 0.05, 0.2), 0.001)
		return

	if arms == "rifle":
		# The forearm is the weapon: receiver, magazine, barrel in a shroud.
		_block(FRAME, _p(x, 0.97, 0), _d(0.115, 0.29, 0.13), 0.024 * _broad)
		_block(_armor, _p(x + 0.03, 1.0, 0), _d(0.08, 0.2, 0.14), 0.02 * _broad)
		_block(STEEL, _p(x, 0.94, 0.09), _d(0.045, 0.13, 0.06), 0.01 * _broad)
		_bar(FRAME, _p(x, 0.83, 0), _p(x, 0.63, 0), 0.034 * _broad, 12)
		for i in 4:
			_ring(STEEL, _p(x, 0.8 - i * 0.045, 0), Vector3.UP, 0.035 * _broad, 0.006)
		_bar(STEEL, _p(x, 0.63, 0), _p(x, 0.55, 0), 0.016 * _broad, 10)
		_bar(RUBBER, _p(x, 0.551, 0), _p(x, 0.5495, 0), 0.01 * _broad, 8)
		_bar("scope_glass", _p(x - 0.045, 0.86, -0.03), _p(x - 0.045, 0.84, -0.03), 0.014 * _broad, 10)
		marker("Muzzle", _joint(x, 0.55, 0), "ForearmR")
	else:
		# Rotary cannon: six barrels in a cage, driven from the housing above.
		_block(FRAME, _p(x, 0.98, 0), _d(0.14, 0.26, 0.15), 0.028 * _broad)
		_block(_armor, _p(x + 0.035, 1.0, 0), _d(0.09, 0.2, 0.16), 0.02 * _broad)
		_bar(STEEL, _p(x, 0.86, 0), _p(x, 0.82, 0), 0.062 * _broad, 16)
		marker("Muzzle", _joint(x, 0.44, 0), "ForearmR")
		part("Barrels", _joint(x, 0.82, 0), "ForearmR")
		for i in 6:
			var out := Vector3(cos(TAU * i / 6.0), 0, sin(TAU * i / 6.0)) * 0.036 * _broad
			_bar(STEEL, _p(x, 0.82, 0) + out, _p(x, 0.45, 0) + out, 0.0115 * _broad, 8)
		for y: float in [0.7, 0.5]:
			_bar(FRAME, _p(x, y, 0), _p(x, y - 0.018, 0), 0.054 * _broad, 16)
		_bar(STEEL, _p(x, 0.82, 0), _p(x, 0.47, 0), 0.014 * _broad, 8)
