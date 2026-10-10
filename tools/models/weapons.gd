extends "res://tools/model_builder.gd"
## The weapons as the player sees them, with the hands that hold them. Build
## with tools/build_model.sh weapons; look at one with
## tools/benchmark.sh --quick --weapon=0 (and --weapon=0,1 for the sights).
##
## A weapon points along -Z with its bore on the Z axis and the origin where
## the grip meets the receiver. Positions are given as _at(ahead, up, right).
## What scripts/weapons.gd animates is found by name: the parts Mag, Bolt,
## Slide, Pump, ArmL and ArmR, and the markers Muzzle, Eject and MagHold.

const STEEL := "gun_steel"
const ALU := "gun_receiver"
const POLY := "gun_polymer"
const TAN := "gun_tan"
const GRIP := "gun_grip"
const BARE := "gun_bare"
const BRASS := "brass"
const RUBBER := "rubber"
const LENS := "sight_lens"
const OPTIC := "scope_glass"
const GLOW := "tritium"
const GLOVE := "glove"
const PAD := "glove_pad"
const SLEEVE := "sleeve"

## A profile drawn from the weapon's right-hand side is in (ahead, up).
const SIDE := Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT)


## Cross-sections, in (right, up): a flat-topped receiver and an octagonal
## handguard with a raised top for the rail.
const UPPER: Array[Vector2] = [Vector2(-0.019, -0.022), Vector2(0.019, -0.022), Vector2(0.019, 0.016), Vector2(0.0125, 0.03), Vector2(-0.0125, 0.03), Vector2(-0.019, 0.016)]
const HANDGUARD: Array[Vector2] = [
	Vector2(-0.0084, -0.0203), Vector2(0.0084, -0.0203), Vector2(0.0203, -0.0084), Vector2(0.0203, 0.0084), Vector2(0.0105, 0.021),
	Vector2(0.0105, 0.03), Vector2(-0.0105, 0.03), Vector2(-0.0105, 0.021), Vector2(-0.0203, 0.0084), Vector2(-0.0203, -0.0084),
]


func _describe() -> void:
	_rifle()
	_pistol()
	_shotgun()
	_smg()
	_marksman()


# --- Rifle ---------------------------------------------------------------------


## Carbine with a flat-top receiver, a slotted handguard and a reflex sight.
func _rifle() -> void:
	model("rifle")

	# Upper receiver and the lower with its magazine well.
	_section(ALU, UPPER, -0.105, 0.095)
	_side(ALU, [
		Vector2(-0.105, -0.02), Vector2(-0.105, -0.046), Vector2(-0.085, -0.053), Vector2(-0.04, -0.053), Vector2(-0.03, -0.047),
		Vector2(0.022, -0.047), Vector2(0.018, -0.098), Vector2(0.086, -0.108), Vector2(0.096, -0.06), Vector2(0.096, -0.02),
	], 0.032, 0.0025)
	_rail(ALU, Transform3D(Basis(), _at(-0.1, 0.03)), 0.515)
	for pin: Vector2 in [Vector2(-0.092, -0.036), Vector2(0.088, -0.036), Vector2(-0.012, -0.036), Vector2(-0.035, -0.03)]:
		_bar(STEEL, _at(pin.x, pin.y, -0.0166), _at(pin.x, pin.y, 0.0166), 0.0028 if pin.x < -0.05 or pin.x > 0.05 else 0.002, 10)

	# Controls on the left: bolt catch, selector, and the charging handle on top.
	_block(STEEL, _at(0.035, -0.012, -0.0205), Vector3(0.004, 0.03, 0.013), 0.0015)
	_block(STEEL, _at(0.035, -0.001, -0.0225), Vector3(0.004, 0.012, 0.017), 0.0015)
	_bar(STEEL, _at(-0.062, -0.034, -0.016), _at(-0.062, -0.034, -0.0188), 0.005, 12)
	_block(STEEL, _at(-0.062, -0.027, -0.0195), Vector3(0.003, 0.022, 0.006), 0.0012)
	_bar("enamel_red", _at(-0.062, -0.018, -0.0159), _at(-0.062, -0.018, -0.0163), 0.0016, 8)
	_block(STEEL, _at(-0.108, 0.02), Vector3(0.052, 0.009, 0.012), 0.002)
	_block(STEEL, _at(-0.104, 0.02, -0.027), Vector3(0.008, 0.011, 0.02), 0.002)
	_bar(STEEL, _at(-0.098, -0.032, -0.0158), _at(-0.098, -0.032, -0.0185), 0.0065, 12)

	# And on the right: forward assist, ejection port with its cover hanging
	# open, the deflector behind it and the magazine catch.
	_bar(STEEL, _at(-0.058, 0.004, 0.018), _at(-0.084, 0.002, 0.03), 0.0062, 10)
	_plate(RUBBER, _at(0.01, 0.003, 0.0192), Vector3(0.0006, 0.018, 0.062))
	_block(ALU, _at(0.01, -0.019, 0.0215), Vector3(0.002, 0.018, 0.064), 0.0008, Vector3(0, 0, 18))
	_block(ALU, _at(-0.032, 0.005, 0.0205), Vector3(0.01, 0.014, 0.014), 0.003)
	_block(STEEL, _at(0.012, -0.031, 0.0168), Vector3(0.003, 0.012, 0.012), 0.001)

	_grip()

	# Handguard: an octagon with a rail along the top and slots down the rest.
	_bar(STEEL, _at(0.088), _at(0.1), 0.0235, 20)
	_section(ALU, HANDGUARD, 0.098, 0.42, 0.0015)
	_slots(0.145, 5)
	_side(POLY, [Vector2(0.186, -0.019), Vector2(0.24, -0.019), Vector2(0.204, -0.044), Vector2(0.19, -0.044)], 0.022, 0.004)

	# Barrel and flash hider.
	_turned(STEEL, _at(0.4), Vector3.FORWARD, [Vector2(0.009, 0), Vector2(0.009, 0.07), Vector2(0.0075, 0.072), Vector2(0.0075, 0.076)], 20)
	_turned(STEEL, _at(0.474), Vector3.FORWARD, [
		Vector2(0.0075, 0), Vector2(0.0105, 0), Vector2(0.0115, 0.002), Vector2(0.0115, 0.042), Vector2(0.0105, 0.048),
		Vector2(0.006, 0.048), Vector2(0.0055, 0.03),
	], 20)
	_bar(RUBBER, _at(0.502), _at(0.505), 0.0057, 12)
	for out: Vector3 in [Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3(-0.707, 0.707, 0), Vector3(0.707, 0.707, 0)]:
		_slot(_at(0.5) + out * 0.01155, out, 0.024, 0.0036)

	# Buffer tube and stock.
	_bar(ALU, _at(-0.105), _at(-0.3), 0.0148, 20)
	_bar(STEEL, _at(-0.105), _at(-0.113), 0.02, 16)
	_block(STEEL, _at(-0.1035, -0.01), Vector3(0.036, 0.052, 0.003), 0.001)
	_side(TAN, [
		Vector2(-0.335, 0.026), Vector2(-0.343, -0.105), Vector2(-0.31, -0.108), Vector2(-0.215, -0.04),
		Vector2(-0.165, -0.03), Vector2(-0.158, -0.02), Vector2(-0.158, 0.026),
	], 0.044, 0.007)
	_side(RUBBER, [Vector2(-0.333, 0.028), Vector2(-0.341, -0.108), Vector2(-0.352, -0.108), Vector2(-0.344, 0.028)], 0.046, 0.004)
	_block(TAN, _at(-0.2, -0.046), Vector3(0.018, 0.012, 0.045), 0.004, Vector3(-27, 0, 0))
	_slot(_at(-0.3, -0.06, -0.0221), Vector3.LEFT, 0.03, 0.008)

	# Reflex sight: a clamp on the rail, a hood around the window.
	var sight := 0.03
	_block(ALU, _at(sight, 0.0435), Vector3(0.031, 0.012, 0.058), 0.002)
	_block(STEEL, _at(sight, 0.041, -0.0168), Vector3(0.004, 0.011, 0.034), 0.001)
	_bar(STEEL, _at(sight, 0.041, -0.0185), _at(sight, 0.041, -0.0225), 0.0045, 6)
	for side: float in [-1.0, 1.0]:
		_block(ALU, _at(sight + 0.019, 0.0665, side * 0.0158), Vector3(0.0045, 0.037, 0.018), 0.0016)
	_block(ALU, _at(sight + 0.019, 0.0852), Vector3(0.036, 0.0045, 0.018), 0.0016)
	_pane(LENS, _at(sight + 0.019, 0.066), Vector2(0.0275, 0.034))
	_block(ALU, _at(sight - 0.014, 0.053), Vector3(0.027, 0.009, 0.024), 0.002)
	_bar(STEEL, _at(sight - 0.014, 0.053, 0.0135), _at(sight - 0.014, 0.053, 0.016), 0.0055, 12)
	for ahead: float in [-0.006, 0.004]:
		_block(RUBBER, _at(sight + ahead, 0.0445, -0.0158), Vector3(0.0012, 0.005, 0.007), 0.0005)

	# Weapon light on the upper left of the handguard, and the folded-down iron sights.
	var lamp := Vector3(-0.0245, 0.0235, 0)
	_block(ALU, _at(0.365, 0.0165, -0.0175), Vector3(0.008, 0.012, 0.03), 0.002, Vector3(0, 0, 38))
	_turned(ALU, lamp + _at(0.325), Vector3.FORWARD, [
		Vector2(0, 0), Vector2(0.0095, 0.001), Vector2(0.0105, 0.004), Vector2(0.0105, 0.012), Vector2(0.0095, 0.014), Vector2(0.0095, 0.058),
		Vector2(0.0125, 0.064), Vector2(0.0125, 0.082), Vector2(0.0105, 0.082), Vector2(0.01, 0.078), Vector2(0, 0.078),
	], 16)
	_bar(OPTIC, lamp + _at(0.4025), lamp + _at(0.4032), 0.01, 16)
	_bar(RUBBER, lamp + _at(0.3235), lamp + _at(0.326), 0.0065, 12)
	for ahead: float in [-0.082, 0.395]:
		_block(STEEL, _at(ahead, 0.0412), Vector3(0.021, 0.008, 0.03), 0.002)
		_block(STEEL, _at(ahead - 0.006, 0.047), Vector3(0.012, 0.004, 0.016), 0.001)

	part("Bolt")
	_plate(BARE, _at(0.008, 0.003, 0.0194), Vector3(0.0008, 0.014, 0.05))

	part("Mag", Transform3D(Basis(), _at(0.055, -0.06)))
	_side(TAN, [
		Vector2(0.026, -0.03), Vector2(0.024, -0.1), Vector2(0.03, -0.15), Vector2(0.044, -0.196),
		Vector2(0.106, -0.18), Vector2(0.09, -0.13), Vector2(0.082, -0.095), Vector2(0.082, -0.03),
	], 0.0225, 0.003)
	_block(TAN, _at(0.076, -0.19), Vector3(0.027, 0.011, 0.072), 0.003, Vector3(14.5, 0, 0))
	for side: float in [-1.0, 1.0]:
		_side(TAN, [Vector2(0.036, -0.112), Vector2(0.042, -0.15), Vector2(0.052, -0.181), Vector2(0.094, -0.17), Vector2(0.082, -0.135), Vector2(0.075, -0.112)], 0.0015, 0.0005, side * 0.0115)
	_bar(BRASS, _at(0.034, -0.027), _at(0.078, -0.027), 0.0047, 10)

	_trigger_hand()
	_support_hand(0.275, 0.021)

	marker("Muzzle", Transform3D(Basis(), _at(0.535)))
	marker("Eject", Transform3D(Basis(), _at(0.01, 0.006, 0.024)))
	marker("MagHold", Transform3D(Basis(), _at(0.075, -0.19)))


# --- Pistol --------------------------------------------------------------------


## Striker-fired service pistol with a polymer frame.
func _pistol() -> void:
	model("pistol")

	# Frame, with its rail under the dust cover and the panels of the grip.
	_side(POLY, [
		Vector2(-0.066, -0.011), Vector2(-0.076, -0.02), Vector2(-0.068, -0.045), Vector2(-0.086, -0.125), Vector2(-0.03, -0.137),
		Vector2(-0.004, -0.05), Vector2(-0.002, -0.027), Vector2(0.126, -0.027), Vector2(0.126, -0.011),
	], 0.027, 0.004)
	_side(GRIP, [Vector2(-0.066, -0.052), Vector2(-0.08, -0.118), Vector2(-0.034, -0.128), Vector2(-0.012, -0.057)], 0.0285, 0.001)
	for i in 3:
		_plate(POLY, _at(0.084 + i * 0.012, -0.0285), Vector3(0.021, 0.004, 0.006))
	_line(POLY, [_at(0.066, -0.026), _at(0.071, -0.05), _at(0.058, -0.068), _at(0.012, -0.07), _at(-0.008, -0.056)], 0.0035)
	_line(STEEL, [_at(0.024, -0.026), _at(0.027, -0.04), _at(0.021, -0.052), _at(0.014, -0.058)], 0.003)
	_block(STEEL, _at(0.012, -0.0145, -0.0142), Vector3(0.002, 0.005, 0.03), 0.001)
	_plate(STEEL, _at(0.045, -0.02, -0.0138), Vector3(0.0012, 0.006, 0.012))
	_block(POLY, _at(-0.008, -0.04, -0.0142), Vector3(0.003, 0.009, 0.009), 0.001)

	# Barrel and guide rod: they stay where they are when the slide comes back.
	_bar(BARE, _at(-0.03), _at(0.13), 0.0073, 16)
	_bar(RUBBER, _at(0.1302), _at(0.1306), 0.0045, 12)
	_bar(STEEL, _at(0.08, -0.0075), _at(0.1284, -0.0075), 0.0035, 10)

	part("Slide")
	_section(STEEL, [Vector2(-0.0135, -0.011), Vector2(0.0135, -0.011), Vector2(0.0135, 0.011), Vector2(0.0105, 0.0165), Vector2(-0.0105, 0.0165), Vector2(-0.0135, 0.011)], -0.058, 0.128, 0.0015)
	for side: float in [-1.0, 1.0]:
		for i in 6:
			_plate(RUBBER, _at(-0.051 + i * 0.006, 0.0, side * 0.0137), Vector3(0.0006, 0.019, 0.0022))
		for i in 4:
			_plate(RUBBER, _at(0.094 + i * 0.006, 0.0, side * 0.0137), Vector3(0.0006, 0.019, 0.0022))
		_block(STEEL, _at(-0.047, 0.0205, side * 0.0066), Vector3(0.008, 0.008, 0.01), 0.001)
		_dot(_at(-0.052, 0.0215, side * 0.0066))
	_block(STEEL, _at(-0.047, 0.0182), Vector3(0.021, 0.004, 0.012), 0.001)
	_block(STEEL, _at(0.118, 0.0205), Vector3(0.0036, 0.008, 0.008), 0.0008)
	_dot(_at(0.114, 0.0215))
	_plate(RUBBER, _at(0.022, 0.006, 0.0137), Vector3(0.0006, 0.011, 0.036))
	_plate(RUBBER, _at(0.022, 0.0167, 0.0045), Vector3(0.016, 0.0006, 0.036))
	_plate(BARE, _at(0.03, 0.0169, 0.003), Vector3(0.012, 0.0006, 0.018))
	_plate(POLY, _at(-0.0582, 0.002), Vector3(0.02, 0.02, 0.0006))

	var grip := Vector3(0, 0.975, -0.222)
	part("Mag", Transform3D(Basis(Vector3.RIGHT, grip, Vector3.RIGHT.cross(grip)), _at(-0.04, -0.08)))
	_side(STEEL, [Vector2(-0.06, -0.03), Vector2(-0.079, -0.128), Vector2(-0.04, -0.136), Vector2(-0.018, -0.04)], 0.02, 0.001)
	_block(POLY, _at(-0.059, -0.136), Vector3(0.028, 0.009, 0.06), 0.003, Vector3(-12, 0, 0))
	_bar(BRASS, _at(-0.055, -0.027), _at(-0.027, -0.027), 0.0045, 8)

	# Both thumbs forward: the right hand on the grip, the left wrapped round it.
	var around := Basis(Vector3.RIGHT, grip, Vector3.RIGHT.cross(grip))
	part("ArmR", Transform3D(Basis(), _at(-0.135, -0.1, 0.035)))
	_hand(Transform3D(around, _at(-0.0464, -0.08)), Vector2(0.0145, 0.026), -25, -1,
		_at(-0.135, -0.1, 0.035), _at(-0.42, -0.24, 0.14),
		[_at(-0.082, -0.036, 0.008), _at(-0.066, -0.022, -0.014), _at(-0.04, -0.02, -0.022), _at(-0.016, -0.019, -0.022)],
		[_at(-0.04, -0.045, 0.024), _at(-0.012, -0.028, 0.02), _at(0.016, -0.022, 0.0185), _at(0.042, -0.02, 0.0175)])
	part("ArmL", Transform3D(Basis(), _at(-0.043, -0.085)))
	_hand(Transform3D(around, _at(-0.043, -0.088)), Vector2(0.026, 0.036), 215, 1,
		_at(-0.105, -0.13, -0.075), _at(-0.36, -0.3, -0.25),
		[_at(-0.066, -0.052, -0.032), _at(-0.036, -0.032, -0.028), _at(-0.006, -0.024, -0.025), _at(0.02, -0.022, -0.023)])

	marker("Muzzle", Transform3D(Basis(), _at(0.14)))
	marker("Eject", Transform3D(Basis(), _at(0.022, 0.012, 0.016)))
	marker("MagHold", Transform3D(Basis(), _at(-0.065, -0.17)))


# --- Shotgun -------------------------------------------------------------------


## Pump-action shotgun with a ghost-ring sight and spare shells on the receiver.
func _shotgun() -> void:
	model("shotgun")

	_section(STEEL, [Vector2(-0.02, -0.05), Vector2(0.02, -0.05), Vector2(0.02, 0.012), Vector2(0.013, 0.022), Vector2(-0.013, 0.022), Vector2(-0.02, 0.012)], -0.15, 0.07, 0.003)
	_rail(ALU, Transform3D(Basis(), _at(-0.135, 0.022)), 0.14)
	_plate(RUBBER, _at(-0.03, -0.0503), Vector3(0.024, 0.0006, 0.08))
	_plate(BARE, _at(-0.03, -0.0507), Vector3(0.018, 0.0004, 0.062))
	_plate(RUBBER, _at(-0.01, -0.004, 0.0203), Vector3(0.0006, 0.022, 0.075))
	_bar(STEEL, _at(-0.105, -0.03, -0.0195), _at(-0.105, -0.03, 0.0215), 0.004, 10)
	for pin: float in [-0.02, 0.03]:
		_bar(STEEL, _at(pin, -0.034, -0.0206), _at(pin, -0.034, 0.0206), 0.0022, 10)
	_grip()

	# Ghost ring behind, a blade on a ramp in front.
	_block(STEEL, _at(-0.115, 0.0325), Vector3(0.022, 0.007, 0.02), 0.001)
	_ring(STEEL, _at(-0.115, 0.043), Vector3.BACK, 0.007, 0.0018)
	for side: float in [-1.0, 1.0]:
		_block(STEEL, _at(-0.115, 0.043, side * 0.0125), Vector3(0.003, 0.02, 0.018), 0.001)
	_block(STEEL, _at(0.535, 0.016), Vector3(0.008, 0.012, 0.034), 0.002)
	_block(STEEL, _at(0.535, 0.032), Vector3(0.003, 0.022, 0.012), 0.0008)
	_dot(_at(0.5285, 0.0395), 0.0013)

	# Spare shells in a carrier on the left of the receiver, heads up and down in turn.
	_block(POLY, _at(-0.04, -0.012, -0.0225), Vector3(0.006, 0.034, 0.14), 0.002)
	_block(POLY, _at(-0.04, -0.012, -0.033), Vector3(0.017, 0.024, 0.13), 0.004)
	for i in 5:
		var ahead := -0.09 + i * 0.025
		var up := 1.0 if i % 2 == 0 else -1.0
		_bar("enamel_red", _at(ahead, -0.012 - up * 0.02, -0.034), _at(ahead, -0.012 + up * 0.018, -0.034), 0.0101, 14)
		_bar(BRASS, _at(ahead, -0.012 + up * 0.018, -0.034), _at(ahead, -0.012 + up * 0.032, -0.034), 0.0104, 14)
		_bar(BRASS, _at(ahead, -0.012 + up * 0.032, -0.034), _at(ahead, -0.012 + up * 0.0335, -0.034), 0.0113, 14)

	# Barrel over the magazine tube, clamped together near the muzzle.
	_turned(STEEL, _at(0.07), Vector3.FORWARD, [
		Vector2(0.0125, 0), Vector2(0.0125, 0.02), Vector2(0.0108, 0.03), Vector2(0.0108, 0.5), Vector2(0.0092, 0.5), Vector2(0.0092, 0.47),
	], 20)
	_bar(RUBBER, _at(0.54), _at(0.541), 0.0093, 12)
	_bar(STEEL, _at(0.07, -0.03), _at(0.5, -0.03), 0.0125, 16)
	_turned(STEEL, _at(0.5, -0.03), Vector3.FORWARD, [Vector2(0.0135, 0), Vector2(0.0135, 0.02), Vector2(0.01, 0.028), Vector2(0, 0.028)], 16)
	_block(STEEL, _at(0.46, -0.014), Vector3(0.03, 0.056, 0.016), 0.006)
	_bar(STEEL, _at(0.46, -0.014, -0.0155), _at(0.46, -0.014, 0.0165), 0.0045, 6)

	# Stock.
	_side(POLY, [
		Vector2(-0.15, 0.018), Vector2(-0.355, 0.012), Vector2(-0.362, -0.115), Vector2(-0.33, -0.118), Vector2(-0.235, -0.046), Vector2(-0.15, -0.04),
	], 0.04, 0.008)
	_side(RUBBER, [Vector2(-0.353, 0.014), Vector2(-0.36, -0.118), Vector2(-0.372, -0.118), Vector2(-0.365, 0.014)], 0.042, 0.004)
	_slot(_at(-0.31, -0.05, -0.0201), Vector3.LEFT, 0.03, 0.008)

	part("Bolt")
	_plate(BARE, _at(-0.012, -0.004, 0.0206), Vector3(0.0006, 0.018, 0.06))

	# Forend on its two action bars.
	part("Pump", Transform3D(Basis(), _at(0.28, -0.03)))
	var forend: Array[Vector2] = [Vector2(-0.022, -0.054), Vector2(0.022, -0.054), Vector2(0.026, -0.032), Vector2(0.022, -0.012), Vector2(-0.022, -0.012), Vector2(-0.026, -0.032)]
	_section(POLY, forend, 0.2, 0.36, 0.005)
	for i in 7:
		_section(POLY, forend.map(func(corner: Vector2) -> Vector2: return (corner - Vector2(0, -0.033)) * 1.07 + Vector2(0, -0.033)), 0.213 + i * 0.02, 0.222 + i * 0.02, 0.0025)
	for side: float in [-1.0, 1.0]:
		_plate(STEEL, _at(0.14, -0.022, side * 0.0145), Vector3(0.003, 0.008, 0.14))

	_trigger_hand()
	_support_hand(0.28, 0.024, "Pump", 0.033)

	marker("Muzzle", Transform3D(Basis(), _at(0.585)))
	marker("Eject", Transform3D(Basis(), _at(-0.01, 0.0, 0.026)))
	marker("MagHold", Transform3D(Basis(), _at(-0.03, -0.085)))


# --- Submachine gun ------------------------------------------------------------


## Compact submachine gun: a stick magazine, a wire stock and a cocking
## handle on the left that travels with the bolt.
func _smg() -> void:
	model("smg")

	_section(ALU, [Vector2(-0.017, -0.02), Vector2(0.017, -0.02), Vector2(0.017, 0.014), Vector2(0.011, 0.026), Vector2(-0.011, 0.026), Vector2(-0.017, 0.014)], -0.12, 0.2)
	_section(ALU, [Vector2(-0.0165, -0.038), Vector2(0.0165, -0.038), Vector2(0.0175, -0.019), Vector2(-0.0175, -0.019)], 0.085, 0.2, 0.003)
	_rail(ALU, Transform3D(Basis(), _at(-0.112, 0.026)), 0.305)
	_side(POLY, [
		Vector2(-0.12, -0.018), Vector2(-0.12, -0.042), Vector2(-0.09, -0.053), Vector2(-0.04, -0.053), Vector2(-0.03, -0.047),
		Vector2(0.03, -0.047), Vector2(0.028, -0.086), Vector2(0.074, -0.091), Vector2(0.078, -0.03), Vector2(0.078, -0.018),
	], 0.03, 0.003)
	for pin: Vector2 in [Vector2(-0.1, -0.032), Vector2(0.07, -0.03), Vector2(-0.014, -0.035)]:
		_bar(STEEL, _at(pin.x, pin.y, -0.0156), _at(pin.x, pin.y, 0.0156), 0.0026, 10)
	_bar(STEEL, _at(-0.062, -0.034, -0.015), _at(-0.062, -0.034, -0.0178), 0.005, 12)
	_block(STEEL, _at(-0.062, -0.027, -0.0185), Vector3(0.003, 0.022, 0.006), 0.0012)
	_grip()
	_slot(_at(0.115, 0.004, -0.0171), Vector3.LEFT, 0.1, 0.0065)
	_plate(RUBBER, _at(0.03, 0.002, 0.0172), Vector3(0.0006, 0.016, 0.05))
	for i in 3:
		_slot(_at(0.115 + i * 0.03, -0.029, -0.0172), Vector3.LEFT, 0.02, 0.006)
		_slot(_at(0.115 + i * 0.03, -0.029, 0.0172), Vector3.RIGHT, 0.02, 0.006)

	# Short barrel with lugs for a suppressor.
	_bar(STEEL, _at(0.2), _at(0.236), 0.008, 16)
	_turned(STEEL, _at(0.236), Vector3.FORWARD, [
		Vector2(0.008, 0), Vector2(0.011, 0), Vector2(0.011, 0.006), Vector2(0.009, 0.008), Vector2(0.009, 0.016), Vector2(0.012, 0.018),
		Vector2(0.012, 0.04), Vector2(0.0055, 0.04), Vector2(0.005, 0.02),
	], 16)
	_bar(RUBBER, _at(0.258), _at(0.259), 0.0052, 12)

	# Sights: an aperture behind, a hooded post in front.
	_block(STEEL, _at(-0.09, 0.0375), Vector3(0.022, 0.016, 0.018), 0.002)
	_ring(STEEL, _at(-0.09, 0.052), Vector3.BACK, 0.0062, 0.002)
	_block(STEEL, _at(0.175, 0.0355), Vector3(0.02, 0.012, 0.016), 0.002)
	_ring(STEEL, _at(0.175, 0.052), Vector3.BACK, 0.0105, 0.0018)
	_block(STEEL, _at(0.175, 0.0465), Vector3(0.0022, 0.011, 0.003), 0.0005)
	_dot(_at(0.1734, 0.0505), 0.001)

	# Wire stock, pulled out.
	for side: float in [-1.0, 1.0]:
		_bar(STEEL, _at(-0.05, 0.006, side * 0.0195), _at(-0.33, 0.006, side * 0.0195), 0.0038, 10)
		_block(ALU, _at(-0.1, 0.006, side * 0.0185), Vector3(0.008, 0.012, 0.03), 0.002)
	_block(POLY, _at(-0.335, -0.03), Vector3(0.05, 0.115, 0.016), 0.007)

	part("Bolt")
	_bar(STEEL, _at(0.15, 0.004, -0.016), _at(0.15, 0.004, -0.032), 0.0045, 10)
	_ball(STEEL, _at(0.15, 0.004, -0.034), 0.0072)

	part("Mag", Transform3D(Basis(), _at(0.052, -0.06)))
	_side(STEEL, [Vector2(0.034, -0.03), Vector2(0.04, -0.205), Vector2(0.074, -0.2), Vector2(0.07, -0.03)], 0.02, 0.002)
	_block(POLY, _at(0.057, -0.204), Vector3(0.024, 0.01, 0.04), 0.003, Vector3(8, 0, 0))
	for side: float in [-1.0, 1.0]:
		_side(STEEL, [Vector2(0.046, -0.1), Vector2(0.049, -0.19), Vector2(0.064, -0.188), Vector2(0.06, -0.1)], 0.001, 0.0003, side * 0.0102)
	_bar(BRASS, _at(0.038, -0.027), _at(0.066, -0.027), 0.0045, 8)

	_trigger_hand()
	_support_hand(0.145, 0.0235, "", 0.011)

	marker("Muzzle", Transform3D(Basis(), _at(0.29)))
	marker("Eject", Transform3D(Basis(), _at(0.03, 0.004, 0.022)))
	marker("MagHold", Transform3D(Basis(), _at(0.057, -0.2)))


# --- Marksman rifle ------------------------------------------------------------


## Semi-automatic rifle with a long barrel and a telescopic sight. Aimed, the
## HUD takes over with the picture through the scope; this is what is seen of
## it from the hip.
func _marksman() -> void:
	model("marksman")

	_section(ALU, UPPER, -0.11, 0.112)
	_side(ALU, [
		Vector2(-0.11, -0.02), Vector2(-0.11, -0.046), Vector2(-0.085, -0.053), Vector2(-0.04, -0.053), Vector2(-0.03, -0.047),
		Vector2(0.02, -0.047), Vector2(0.016, -0.092), Vector2(0.104, -0.1), Vector2(0.112, -0.06), Vector2(0.112, -0.02),
	], 0.034, 0.0025)
	_rail(ALU, Transform3D(Basis(), _at(-0.104, 0.03)), 0.6)
	for pin: Vector2 in [Vector2(-0.095, -0.036), Vector2(0.1, -0.036), Vector2(-0.012, -0.036)]:
		_bar(STEEL, _at(pin.x, pin.y, -0.0176), _at(pin.x, pin.y, 0.0176), 0.0028, 10)
	_bar(STEEL, _at(-0.062, -0.034, -0.017), _at(-0.062, -0.034, -0.0198), 0.005, 12)
	_block(STEEL, _at(-0.062, -0.027, -0.0205), Vector3(0.003, 0.022, 0.006), 0.0012)
	_slot(_at(0.045, 0.006, -0.0191), Vector3.LEFT, 0.11, 0.0065)
	_plate(RUBBER, _at(0.02, 0.003, 0.0192), Vector3(0.0006, 0.018, 0.075))
	_grip()

	_bar(STEEL, _at(0.105), _at(0.118), 0.0235, 20)
	_section(ALU, HANDGUARD, 0.115, 0.5, 0.0015)
	_slots(0.16, 6)
	_turned(STEEL, _at(0.48), Vector3.FORWARD, [Vector2(0.0098, 0), Vector2(0.0098, 0.175), Vector2(0.0082, 0.178), Vector2(0.0082, 0.185)], 20)
	_block(STEEL, _at(0.698), Vector3(0.023, 0.021, 0.066), 0.004)
	for i in 3:
		for side: float in [-1.0, 1.0]:
			_slot(_at(0.68 + i * 0.018, 0, side * 0.0116), Vector3(side, 0, 0), 0.011, 0.012)
	_bar(RUBBER, _at(0.7311), _at(0.7314), 0.0055, 12)

	# Bipod folded back under the handguard.
	_block(ALU, _at(0.455, -0.026), Vector3(0.03, 0.014, 0.03), 0.003)
	for side: float in [-1.0, 1.0]:
		_bar(STEEL, _at(0.452, -0.03, side * 0.013), _at(0.24, -0.034, side * 0.016), 0.0048, 10)
		_bar(ALU, _at(0.34, -0.0325, side * 0.0145), _at(0.24, -0.034, side * 0.016), 0.0062, 10)
		_ball(RUBBER, _at(0.232, -0.034, side * 0.016), 0.0085)

	# Stock with a raised cheek piece.
	_bar(ALU, _at(-0.11), _at(-0.3), 0.0148, 20)
	_bar(STEEL, _at(-0.11), _at(-0.118), 0.02, 16)
	_side(POLY, [
		Vector2(-0.16, 0.026), Vector2(-0.335, 0.026), Vector2(-0.343, -0.112), Vector2(-0.305, -0.114), Vector2(-0.28, -0.06),
		Vector2(-0.2, -0.036), Vector2(-0.16, -0.03),
	], 0.042, 0.007)
	_block(POLY, _at(-0.243, 0.036), Vector3(0.036, 0.022, 0.13), 0.009)
	_side(RUBBER, [Vector2(-0.333, 0.028), Vector2(-0.341, -0.115), Vector2(-0.353, -0.115), Vector2(-0.345, 0.028)], 0.044, 0.004)
	for ahead: float in [-0.21, -0.275]:
		_bar(STEEL, _at(ahead, 0.02, -0.0215), _at(ahead, 0.02, -0.025), 0.006, 10)

	# Telescopic sight in two rings.
	var eye := 0.067
	for ahead: float in [-0.012, 0.118]:
		_block(ALU, _at(ahead, 0.0445), Vector3(0.03, 0.016, 0.022), 0.003)
		_bar(ALU, _at(ahead - 0.011, eye), _at(ahead + 0.011, eye), 0.0192, 20)
		_bar(STEEL, _at(ahead, 0.042, -0.0165), _at(ahead, 0.042, -0.021), 0.005, 6)
	_turned(ALU, _at(-0.115, eye), Vector3.FORWARD, [
		Vector2(0.0172, 0), Vector2(0.021, 0.004), Vector2(0.021, 0.05), Vector2(0.0185, 0.062), Vector2(0.0152, 0.07), Vector2(0.0152, 0.215),
		Vector2(0.019, 0.24), Vector2(0.027, 0.28), Vector2(0.027, 0.35), Vector2(0.0255, 0.352), Vector2(0.0255, 0.345),
	], 24)
	_bar(RUBBER, _at(-0.1155, eye), _at(-0.085, eye), 0.0222, 20)
	_bar(OPTIC, _at(-0.1162, eye), _at(-0.1158, eye), 0.0175, 20)
	_bar(OPTIC, _at(0.2295, eye), _at(0.23, eye), 0.0255, 20)
	_block(ALU, _at(0.052, eye), Vector3(0.035, 0.035, 0.036), 0.007)
	var knob: Array[Vector2] = [Vector2(0.011, 0), Vector2(0.011, 0.01), Vector2(0.0128, 0.011), Vector2(0.0128, 0.022), Vector2(0.011, 0.024), Vector2(0, 0.024)]
	_turned(ALU, _at(0.052, eye + 0.0165), Vector3.UP, knob, 16)
	_turned(ALU, _at(0.052, eye, 0.0165), Vector3.RIGHT, knob, 16)
	_turned(ALU, _at(0.052, eye, -0.0165), Vector3.LEFT, knob, 16)

	part("Bolt")
	_bar(STEEL, _at(0.09, 0.006, -0.018), _at(0.09, 0.006, -0.034), 0.0045, 10)
	_ball(STEEL, _at(0.09, 0.006, -0.036), 0.0072)

	part("Mag", Transform3D(Basis(), _at(0.06, -0.06)))
	_side(POLY, [Vector2(0.024, -0.03), Vector2(0.021, -0.152), Vector2(0.099, -0.158), Vector2(0.098, -0.03)], 0.026, 0.003)
	_block(POLY, _at(0.06, -0.156), Vector3(0.03, 0.01, 0.084), 0.003, Vector3(-4, 0, 0))
	for side: float in [-1.0, 1.0]:
		_side(POLY, [Vector2(0.034, -0.105), Vector2(0.033, -0.146), Vector2(0.088, -0.15), Vector2(0.088, -0.105)], 0.0015, 0.0005, side * 0.0132)
	_bar(BRASS, _at(0.03, -0.026), _at(0.092, -0.026), 0.0058, 10)

	_trigger_hand()
	_support_hand(0.285, 0.021)

	marker("Muzzle", Transform3D(Basis(), _at(0.745)))
	marker("Eject", Transform3D(Basis(), _at(0.02, 0.006, 0.024)))
	marker("MagHold", Transform3D(Basis(), _at(0.06, -0.155)))


# --- Shared pieces -------------------------------------------------------------


## Point `ahead` of the origin along the barrel, `up` above it and `right` of it.
func _at(ahead: float, up := 0.0, right := 0.0) -> Vector3:
	return Vector3(right, up, -ahead)


## Plate cut to a side view of the weapon: `outline` in (ahead, up), `width`
## across and centred `right` of the middle.
func _side(mat: String, outline: Array, width: float, bevel := 0.002, right := 0.0) -> void:
	slab(mat, _m * Transform3D(SIDE, Vector3(right, 0, 0)), _ccw(outline), width, bevel, _part)


## A length of one cross-section: `outline` in (right, up), running from
## `from` to `to` ahead of the origin.
func _section(mat: String, outline: Array, from: float, to: float, bevel := 0.002) -> void:
	slab(mat, _m * Transform3D(Basis(), Vector3(0, 0, -(from + to) * 0.5)), _ccw(outline), absf(to - from), bevel, _part)


## The outline counter-clockwise, whichever way round it was written down.
func _ccw(outline: Array) -> PackedVector2Array:
	var points := PackedVector2Array(outline)
	var area := 0.0
	for i in points.size():
		area += points[i].cross(points[(i + 1) % points.size()])
	if area < 0.0:
		points.reverse()
	return points


## Accessory rail with a tooth every centimetre. It starts at the origin of
## `frame`, runs `length` along its -Z and stands on its XZ plane.
func _rail(mat: String, frame: Transform3D, length: float) -> void:
	var xf := _m * frame
	_local_box(mat, xf, Vector3(0, 0.002, -length * 0.5), Vector3(0.0156, 0.004, length), _part)
	var teeth := int(length / 0.01)
	for i in teeth:
		_local_box(mat, xf, Vector3(0, 0.0052, -(i + 0.5) * length / teeth), Vector3(0.0212, 0.0028, 0.0053), _part)


## Slot through a handguard or a flash hider, as a dark inlay with rounded
## ends: `at` is its middle on the surface and `out` the normal there. It runs
## along the barrel.
func _slot(at: Vector3, out: Vector3, length := 0.032, width := 0.007) -> void:
	var outline := PackedVector2Array()
	var straight := (length - width) * 0.5
	for end: float in [1.0, -1.0]:
		for i in 7:
			var angle := PI * (i / 6.0 - 0.5)
			outline.append(Vector2(end * (straight + cos(angle) * width * 0.5), end * sin(angle) * width * 0.5))
	slab(RUBBER, _m * Transform3D(Basis(Vector3.FORWARD, out.cross(Vector3.FORWARD), out), at), outline, 0.0005, 0.0, _part)


## Pistol grip under the back of a receiver whose underside lies 5 cm below
## the bore, with the trigger and its guard in front of it.
func _grip(mat := GRIP) -> void:
	_side(mat, [
		Vector2(-0.088, -0.048), Vector2(-0.097, -0.075), Vector2(-0.118, -0.148), Vector2(-0.07, -0.156),
		Vector2(-0.052, -0.09), Vector2(-0.04, -0.064), Vector2(-0.04, -0.05),
	], 0.03, 0.007)
	_line(ALU, [_at(-0.037, -0.05), _at(-0.032, -0.078), _at(-0.008, -0.089), _at(0.015, -0.086), _at(0.021, -0.062), _at(0.021, -0.05)], 0.003)
	_line(STEEL, [_at(-0.008, -0.045), _at(-0.006, -0.058), _at(-0.011, -0.07), _at(-0.017, -0.077)], 0.0028)


## Rows of slots down an octagonal handguard, the first `ahead` of the origin.
func _slots(ahead: float, count: int) -> void:
	for i in count:
		var at := ahead + i * 0.056
		_slot(_at(at, 0, -0.0204), Vector3.LEFT)
		_slot(_at(at, 0, 0.0204), Vector3.RIGHT)
		_slot(_at(at, -0.0204), Vector3.DOWN)
		for side: float in [-1.0, 1.0]:
			_slot(_at(at + 0.028, -0.01445, side * 0.01445), Vector3(side, -1, 0).normalized(), 0.022, 0.006)
			_slot(_at(at + 0.028, 0.0149, side * 0.0156), Vector3(side * 0.79, 0.613, 0), 0.022, 0.005)


## Glowing dot on the back of a sight, facing the shooter.
func _dot(at: Vector3, radius := 0.0014) -> void:
	_bar(GLOW, at, at + Vector3(0, 0, 0.0004), radius, 8)


## Right hand around a pistol grip that hangs where the rifle's does, with the
## index finger laid along the receiver. Shift `_m` for a grip that sits elsewhere.
func _trigger_hand() -> void:
	var grip := Vector3(0, 0.96, -0.28)
	part("ArmR", _m * Transform3D(Basis(), _at(-0.165, -0.125, 0.05)))
	_hand(Transform3D(Basis(Vector3.RIGHT, grip, Vector3.RIGHT.cross(grip)), _at(-0.079, -0.1)), Vector2(0.015, 0.024), -25, -1,
		_at(-0.165, -0.125, 0.05), _at(-0.42, -0.27, 0.13),
		[_at(-0.112, -0.062, 0.014), _at(-0.094, -0.05, -0.012), _at(-0.066, -0.049, -0.023), _at(-0.04, -0.046, -0.023)],
		[_at(-0.068, -0.064, 0.025), _at(-0.04, -0.046, 0.0225), _at(-0.012, -0.04, 0.0215), _at(0.014, -0.038, 0.0205)])


## Left hand cupped under a handguard of `radius` around the bore, `ahead` of
## the origin, thumb along its left side. It moves with `parent`, if given.
func _support_hand(ahead: float, radius: float, parent := "", drop := 0.0) -> void:
	part("ArmL", _m * Transform3D(Basis(), _at(ahead, -drop)), parent)
	_hand(Transform3D(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), _at(ahead, -drop)), Vector2(radius, radius), -110, 1,
		_at(ahead - 0.077, -0.055 - radius - drop, -0.035 - radius), _at(ahead - 0.375, -0.3 - drop, -0.22),
		[_at(ahead - 0.025, -0.019 - radius - drop, -0.019 - radius), _at(ahead + 0.008, -0.016 - drop, -0.013 - radius),
			_at(ahead + 0.037, -0.001 - drop, -0.01 - radius), _at(ahead + 0.059, 0.005 - drop, -0.009 - radius)])


## Gloved hand closed around something, with its forearm. `frame` sits in the
## middle of what is held, between the middle and the ring finger: its Y runs
## along it towards the index finger, and `radii` are how thick it is along X
## and Z. The knuckles lie `palm_deg` round from X towards Z; from there the
## fingers curl on towards Z if `curl` is 1 and away from it if -1. The back
## of the hand runs from the knuckles to `wrist` and the forearm from there
## towards `elbow`. `thumb` is the path the thumb takes, and `index` that of
## the index finger if it does not curl with the others.
func _hand(frame: Transform3D, radii: Vector2, palm_deg: float, curl: float, wrist: Vector3, elbow: Vector3, thumb: Array, index: Array = []) -> void:
	var lengths: Array[float] = [0.078, 0.088, 0.082, 0.064]
	var thick: Array[float] = [0.0093, 0.0097, 0.0092, 0.0083]
	var start := deg_to_rad(palm_deg)
	var reach := (radii.x + radii.y) * 0.5 + 0.01
	var knuckles: Array[Vector3] = []
	for k in 4:
		var along := (1.5 - k) * 0.0205
		knuckles.append(_around(frame, radii, start, 0.011, along))
		_ball(GLOVE, knuckles[k], 0.0112)
		if k == 0 and not index.is_empty():
			_finger(index, thick[k], PackedFloat32Array([1.1, 1.02, 0.95, 0.86]))
			continue
		var points := []
		for i in 7:
			points.append(_around(frame, radii, start + curl * lengths[k] / reach * i / 6.0, thick[k], along))
		_finger(points, thick[k])

	# Back of the hand, with a hard guard over the knuckles.
	var middle := (knuckles[0] + knuckles[3]) * 0.5
	var back := (wrist - middle).normalized()
	var out := back.cross(knuckles[0] - knuckles[3]).normalized()
	if out.dot(middle - frame.origin) < 0.0:
		out = -out
	var basis := Basis(out.cross(back), out, back)
	rounded_box(GLOVE, _m * Transform3D(basis, (middle + wrist) * 0.5 - out * 0.004), Vector3(0.09, 0.034, middle.distance_to(wrist) + 0.024), 0.014, _part)
	# The guard is a moulded plate per knuckle on a strip of the same stuff,
	# and a seam runs down the back of the hand from between each two.
	rounded_box(PAD, _m * Transform3D(basis, middle + back * 0.02 + out * 0.0125), Vector3(0.08, 0.005, 0.03), 0.0025, _part)
	for k in 4:
		var across: Vector3 = basis.x * (knuckles[k] - middle).dot(basis.x)
		rounded_box(PAD, _m * Transform3D(basis, middle + across + back * 0.012 + out * 0.0155), Vector3(0.0165, 0.008, 0.021), 0.0038, _part)
		if k < 3:
			var between: Vector3 = basis.x * ((knuckles[k] + knuckles[k + 1]) * 0.5 - middle).dot(basis.x)
			_bar(PAD, middle + between + back * 0.038 + out * 0.0128, middle + between * 0.8 + back * (middle.distance_to(wrist) - 0.004) + out * 0.0128, 0.0011, 6)
	# The ball of the thumb is part of the hand, not a ball on it.
	var heel: Vector3 = thumb[0].lerp(wrist, 0.5)
	_ball(GLOVE, heel, 0.0185)
	_line(GLOVE, [heel, thumb[0], thumb[1]], 0.0108, 10, PackedFloat32Array([1.7, 1.45, 1.12]))
	_finger(thumb, 0.0108, PackedFloat32Array([1.14, 1.04, 1.0, 0.9]))

	# Cuff of the glove with its strap, and the sleeve.
	var arm := (elbow - wrist).normalized()
	_turned(GLOVE, wrist - arm * 0.014, arm, [Vector2(0, 0), Vector2(0.028, 0.002), Vector2(0.0335, 0.014), Vector2(0.0345, 0.056), Vector2(0.031, 0.058)], 16, true)
	_turned(PAD, wrist + arm * 0.018, arm, [Vector2(0.034, 0), Vector2(0.0358, 0.002), Vector2(0.0358, 0.02), Vector2(0.034, 0.022)], 16)
	var sleeve := PackedVector2Array([Vector2(0.031, 0), Vector2(0.0365, 0.003)])
	for i in 15:
		var along := 0.012 + i * 0.024
		var folds := 0.0022 * sin(along * 95.0) + 0.0016 * sin(along * 41.0 + 1.0)
		sleeve.append(Vector2(lerpf(0.0375, 0.052, pow(i / 14.0, 0.8)) + folds, along))
	_turned(SLEEVE, wrist + arm * 0.046, arm, sleeve, 16, true)


## Point on the outside of something held, see _hand(): `angle` round it,
## `clear` of its surface and `along` it from the middle of the hand.
func _around(frame: Transform3D, radii: Vector2, angle: float, clear: float, along: float) -> Vector3:
	return frame * Vector3((radii.x + clear) * cos(angle), along, (radii.y + clear) * sin(angle))


## Finger or thumb of a glove along `points`, rounded off at the tip. It is
## thickest at the hand and at its joints and thinner towards the tip; `taper`
## says how thick at each point, for one that is not a finger of seven points.
func _finger(points: Array, radius: float, taper := PackedFloat32Array([1.1, 1.0, 1.05, 0.95, 0.99, 0.88, 0.84])) -> void:
	_line(GLOVE, points, radius, 10, taper)
	_ball(GLOVE, points[-1], radius * taper[taper.size() - 1])


## Pane of glass that faces the shooter.
func _pane(mat: String, center: Vector3, size: Vector2) -> void:
	var st := _tool(mat, _part, center)
	var half := Vector3(size.x, size.y, 0) * 0.5
	var corners: Array[Vector3] = [Vector3(-half.x, -half.y, 0), Vector3(half.x, -half.y, 0), Vector3(half.x, half.y, 0), Vector3(-half.x, half.y, 0)]
	var points := corners.map(func(corner: Vector3) -> Vector3: return _m * (center + corner))
	var normal := _m.basis * Vector3.BACK
	_quad(st, points, [normal, normal, normal, normal], [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
