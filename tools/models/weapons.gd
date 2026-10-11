extends "res://tools/model_builder.gd"
## The weapons as the player sees them, with the hands that hold them. Build
## with tools/build_model.sh weapons; look at one with
## tools/benchmark.sh --quick --weapon=0 (and --weapon=0,1 for the sights).
##
## A weapon points along -Z with its bore on the Z axis and the origin where
## the grip meets the receiver. Positions are given as _at(ahead, up, right).
## What scripts/weapons.gd animates is found by name: the parts Mag, Bolt,
## Slide, Pump, ArmL and ArmR, and the markers Muzzle, Eject and MagHold.
##
## The hands are the glove that tools/build_hands.sh makes, with bones in it:
## an arm holds a node Glove at the wrist with a Skeleton3D under it, and the
## glove says under "holds" how its bones lie for everything the hand is given
## to hold. tools/models/held.gd builds the same weapons without them.

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

## A profile drawn from the weapon's right-hand side is in (ahead, up).
const SIDE := Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT)

const GLOVE_SCENE := "res://scenes/models/glove.scn"
## How far the palm lies under the middle of the knuckles: half the thickness
## of the hand, less what a glove gives.
const PALM := 0.016
## How far a glove is pressed in where a finger closes on something.
const SQUEEZE := 0.0012
## How far the knuckle and the two joints of a finger open and close from
## where they rest, in degrees.
const JOINT_OPEN: Array[float] = [-28.0, -26.0, -14.0]
const JOINT_CLOSED: Array[float] = [70.0, 82.0, 62.0]


## Cross-sections of an AR-15, in (right, up) and to its real measurements: a
## tube around the bolt carrier with a neck on top for the rail to stand on,
## and the octagon of a handguard.
const UPPER_TUBE: Array[Vector2] = [
	Vector2(-0.0165, -0.019), Vector2(0.0165, -0.019), Vector2(0.0165, 0.006), Vector2(0.0155, 0.011), Vector2(0.013, 0.0155),
	Vector2(0.0095, 0.0185), Vector2(0.0078, 0.0195), Vector2(-0.0078, 0.0195), Vector2(-0.0095, 0.0185), Vector2(-0.013, 0.0155),
	Vector2(-0.0155, 0.011), Vector2(-0.0165, 0.006),
]
const OCTAGON: Array[Vector2] = [
	Vector2(-0.0084, -0.0203), Vector2(0.0084, -0.0203), Vector2(0.0203, -0.0084), Vector2(0.0203, 0.0084),
	Vector2(0.0084, 0.0203), Vector2(-0.0084, 0.0203), Vector2(-0.0203, 0.0084), Vector2(-0.0203, -0.0084),
]
## How high the top of a rail on an AR-15 stands above its bore.
const RAIL_TOP := 0.0307


## The glove made last and whether it is a left hand, for _holds_also().
var _worn: Node3D
var _worn_left := false


func model(model_name: String) -> void:
	super(model_name)
	_worn = null


## Whether the hands of the model being built are the glove with bones in it:
## they are for the player, see tools/models/held.gd for anybody else.
func _gloved() -> bool:
	return true


func _describe() -> void:
	_rifle()
	_pistol()
	_shotgun()
	_smg()
	_marksman()


# --- Rifle ---------------------------------------------------------------------


## Carbine with a flat-top receiver, a slotted handguard and a reflex sight:
## an AR-15 with a 14.5 inch barrel, to the measurements of the real thing.
func _rifle() -> void:
	model("rifle")

	# Upper receiver, and the lower with its magazine well.
	_section(ALU, UPPER_TUBE, -0.105, 0.095, 0.0012)
	_picatinny(ALU, -0.103, 0.093, RAIL_TOP, 0.019)
	_side(ALU, _chamfer([
		Vector2(-0.105, -0.019), Vector2(-0.105, -0.044), Vector2(-0.09, -0.0515), Vector2(-0.04, -0.0515), Vector2(-0.03, -0.047),
		Vector2(0.022, -0.047), Vector2(0.018, -0.098), Vector2(0.086, -0.108), Vector2(0.096, -0.062), Vector2(0.096, -0.019),
	], 0.002), 0.03, 0.002)
	# The mouth of the well is flared, with a fence round the catch above it.
	_side(ALU, [Vector2(0.0175, -0.09), Vector2(0.017, -0.0985), Vector2(0.0865, -0.109), Vector2(0.0885, -0.1)], 0.0335, 0.0018)
	_side(ALU, _chamfer([Vector2(0.0, -0.022), Vector2(0.0, -0.041), Vector2(0.024, -0.041), Vector2(0.024, -0.022)], 0.003), 0.004, 0.001, 0.0152)
	for pin: Vector2 in [Vector2(-0.092, -0.036), Vector2(0.088, -0.036), Vector2(-0.012, -0.036), Vector2(-0.035, -0.03)]:
		_bar(STEEL, _at(pin.x, pin.y, -0.0156), _at(pin.x, pin.y, 0.0156), 0.0028 if pin.x < -0.05 or pin.x > 0.05 else 0.002, 10)

	# Controls on the left: bolt catch, selector, and the charging handle with
	# its latch across the back of the receiver.
	_block(STEEL, _at(0.035, -0.014, -0.0172), Vector3(0.004, 0.026, 0.012), 0.0015)
	_block(STEEL, _at(0.035, -0.003, -0.0192), Vector3(0.004, 0.012, 0.016), 0.0015)
	for i in 4:
		_plate(STEEL, _at(0.035, -0.0065 + i * 0.0024, -0.0214), Vector3(0.0006, 0.0011, 0.014))
	_bar(STEEL, _at(-0.062, -0.034, -0.015), _at(-0.062, -0.034, -0.0178), 0.005, 12)
	_block(STEEL, _at(-0.05, -0.034, -0.0186), Vector3(0.003, 0.006, 0.024), 0.0012)
	_bar("enamel_red", _at(-0.062, -0.0245, -0.0149), _at(-0.062, -0.0245, -0.0153), 0.0016, 8)
	_section(STEEL, _chamfer([Vector2(-0.0178, 0.0118), Vector2(0.0178, 0.0118), Vector2(0.0178, 0.0192), Vector2(-0.0178, 0.0192)], 0.0016), -0.1185, -0.1055, 0.0008)
	_side(STEEL, _chamfer([Vector2(-0.119, 0.012), Vector2(-0.094, 0.012), Vector2(-0.094, 0.019), Vector2(-0.119, 0.019)], 0.0015), 0.0035, 0.0008, -0.0196)
	_bar(STEEL, _at(-0.098, 0.0155, -0.0165), _at(-0.098, 0.0155, -0.0222), 0.002, 8)

	# And on the right: forward assist, ejection port with its cover hanging
	# open, the deflector behind it and the magazine catch.
	_bar(ALU, _at(-0.052, 0.004, 0.0145), _at(-0.078, 0.002, 0.0255), 0.0068, 12)
	_bar(STEEL, _at(-0.078, 0.002, 0.0255), _at(-0.087, 0.0013, 0.0293), 0.0052, 12)
	_plate(RUBBER, _at(0.01, 0.003, 0.0166), Vector3(0.0006, 0.017, 0.062))
	_block(ALU, _at(0.01, -0.0175, 0.0188), Vector3(0.002, 0.017, 0.064), 0.0008, Vector3(0, 0, 18))
	_bar(STEEL, _at(-0.024, -0.0085, 0.0168), _at(0.044, -0.0085, 0.0168), 0.0013, 6)
	_side(ALU, [Vector2(-0.04, 0.0), Vector2(-0.024, -0.004), Vector2(-0.024, 0.011), Vector2(-0.033, 0.012)], 0.012, 0.002, 0.0195)
	_bar(STEEL, _at(0.012, -0.031, 0.015), _at(0.012, -0.031, 0.0178), 0.0042, 10)

	_grip()

	# The receiver extension with its lock nut and end plate, and the stock on it.
	_bar(ALU, _at(-0.105), _at(-0.3), 0.0146, 20)
	_section(STEEL, _chamfer([Vector2(-0.015, -0.044), Vector2(0.015, -0.044), Vector2(0.0185, -0.008), Vector2(0.0185, 0.008), Vector2(0.012, 0.0185), Vector2(-0.012, 0.0185), Vector2(-0.0185, 0.008), Vector2(-0.0185, -0.008)], 0.003), -0.1085, -0.1055, 0.0008)
	_bar(STEEL, _at(-0.1085), _at(-0.1165), 0.0192, 12)
	for i in 6:
		var round := TAU * (i + 0.5) / 6.0
		_plate(RUBBER, _at(-0.1125, cos(round) * 0.0188, sin(round) * 0.0188), Vector3(0.004, 0.004, 0.0082))
	_stock()

	# Handguard: an octagon with a rail along the top and slots down the rest.
	_bar(STEEL, _at(0.088), _at(0.1), 0.0235, 20)
	_section(ALU, OCTAGON, 0.098, 0.42, 0.0015)
	_picatinny(ALU, 0.101, 0.418, RAIL_TOP, 0.019)
	_guard_slots(0.145, 5)
	for side: float in [-1.0, 1.0]:
		_bar(STEEL, _at(0.108, -0.006, side * 0.0196), _at(0.108, -0.006, side * 0.0208), 0.0032, 6)
		_bar(STEEL, _at(0.119, -0.006, side * 0.0196), _at(0.119, -0.006, side * 0.0208), 0.0032, 6)
	_side(POLY, _chamfer([Vector2(0.186, -0.019), Vector2(0.24, -0.019), Vector2(0.206, -0.044), Vector2(0.19, -0.044)], 0.003), 0.022, 0.004)

	# Barrel and flash hider.
	_turned(STEEL, _at(0.4), Vector3.FORWARD, [Vector2(0.009, 0), Vector2(0.009, 0.07), Vector2(0.0075, 0.072), Vector2(0.0075, 0.076)], 20)
	_turned(STEEL, _at(0.474), Vector3.FORWARD, [
		Vector2(0.0075, 0), Vector2(0.0105, 0), Vector2(0.0115, 0.002), Vector2(0.0115, 0.042), Vector2(0.0105, 0.048),
		Vector2(0.006, 0.048), Vector2(0.0055, 0.03),
	], 20)
	_bar(RUBBER, _at(0.502), _at(0.505), 0.0057, 12)
	for out: Vector3 in [Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3(-0.707, 0.707, 0), Vector3(0.707, 0.707, 0)]:
		_slot(_at(0.5) + out * 0.01155, out, 0.024, 0.0036)

	_reflex_sight(0.012)
	_flip_sight(-0.084, true)
	_flip_sight(0.398, false)

	# Weapon light on the upper left of the handguard, in a ring of its own.
	var lamp := Vector3(-0.0245, 0.0235, 0)
	_block(ALU, _at(0.365, 0.0165, -0.0175), Vector3(0.008, 0.012, 0.03), 0.002, Vector3(0, 0, 38))
	_bar(ALU, lamp + _at(0.352), lamp + _at(0.378), 0.0112, 16)
	_turned(ALU, lamp + _at(0.325), Vector3.FORWARD, [
		Vector2(0, 0), Vector2(0.0095, 0.001), Vector2(0.0105, 0.004), Vector2(0.0105, 0.012), Vector2(0.0095, 0.014), Vector2(0.0095, 0.058),
		Vector2(0.0125, 0.064), Vector2(0.0125, 0.082), Vector2(0.0105, 0.082), Vector2(0.01, 0.078), Vector2(0, 0.078),
	], 16)
	_bar(OPTIC, lamp + _at(0.4025), lamp + _at(0.4032), 0.01, 16)
	_bar(RUBBER, lamp + _at(0.3235), lamp + _at(0.326), 0.0065, 12)

	part("Bolt")
	_plate(BARE, _at(0.008, 0.003, 0.0168), Vector3(0.0008, 0.014, 0.05))

	part("Mag", Transform3D(Basis(), _at(0.055, -0.06)))
	_side(TAN, [
		Vector2(0.026, -0.03), Vector2(0.024, -0.1), Vector2(0.03, -0.15), Vector2(0.044, -0.196),
		Vector2(0.106, -0.18), Vector2(0.09, -0.13), Vector2(0.082, -0.095), Vector2(0.082, -0.03),
	], 0.0225, 0.003)
	_block(TAN, _at(0.076, -0.19), Vector3(0.027, 0.011, 0.072), 0.003, Vector3(14.5, 0, 0))
	for side: float in [-1.0, 1.0]:
		_side(TAN, [Vector2(0.036, -0.112), Vector2(0.042, -0.15), Vector2(0.052, -0.181), Vector2(0.094, -0.17), Vector2(0.082, -0.135), Vector2(0.075, -0.112)], 0.0015, 0.0005, side * 0.0115)
	# Ribs to hold it by, down its front and its back.
	for edge: Array in [[Vector2(0.0255, -0.112), Vector2(0.0305, -0.15), Vector2(0.042, -0.186)], [Vector2(0.0805, -0.105), Vector2(0.0885, -0.132), Vector2(0.103, -0.175)]]:
		for i in 7:
			var share := i / 6.0
			var at: Vector2 = (edge[0] as Vector2).lerp(edge[1], share * 2.0) if share < 0.5 else (edge[1] as Vector2).lerp(edge[2], share * 2.0 - 1.0)
			var lean: Vector2 = (edge[1] - edge[0]) if share < 0.5 else (edge[2] - edge[1])
			_block(TAN, _at(at.x, at.y), Vector3(0.0236, 0.0032, 0.0046), 0.0014, Vector3(rad_to_deg(atan2(lean.x, -lean.y)), 0, 0))
	_bar(BRASS, _at(0.034, -0.027), _at(0.078, -0.027), 0.0047, 10)

	_trigger_hand()
	_support_hand(0.275, 0.021)
	# To change the magazine the same hand takes it low down, from its left:
	# the fingers round its front, the thumb behind it.
	var lean := Vector3(0, 0.988, 0.152)
	_holds_also("mag", Transform3D(Basis(Vector3.RIGHT, lean, Vector3.RIGHT.cross(lean)), _at(0.071, -0.152)), Vector2(0.0113, 0.029), 180.0,
		_at(-0.02, -0.19, -0.03), 0.03, 0.0, _at(-0.12, -0.42, -0.2))

	marker("Muzzle", Transform3D(Basis(), _at(0.535)))
	marker("Eject", Transform3D(Basis(), _at(0.01, 0.006, 0.024)))
	marker("MagHold", Transform3D(Basis(), _at(0.075, -0.19)))


## Collapsible stock on the receiver extension of the carbine: a sleeve round
## the tube, a butt with its pad, and a strut from the toe up to the sleeve
## that leaves the triangle between them open.
func _stock() -> void:
	var sleeve: Array[Vector2] = []
	for i in 9:
		var round := PI * i / 8.0
		sleeve.append(Vector2(cos(round) * 0.0212, sin(round) * 0.0212 + 0.002))
	sleeve.append_array([Vector2(-0.0212, -0.014), Vector2(-0.013, -0.027), Vector2(0.013, -0.027), Vector2(0.0212, -0.014)])
	_section(TAN, sleeve, -0.168, -0.318, 0.004)
	_side(TAN, _chamfer([
		Vector2(-0.31, 0.0235), Vector2(-0.343, 0.0235), Vector2(-0.349, -0.106), Vector2(-0.322, -0.109), Vector2(-0.3, -0.03),
	], 0.004), 0.04, 0.007)
	_side(TAN, [
		Vector2(-0.326, -0.108), Vector2(-0.305, -0.108), Vector2(-0.196, -0.036), Vector2(-0.176, -0.036), Vector2(-0.176, -0.024), Vector2(-0.205, -0.024),
	], 0.022, 0.004)
	_side(RUBBER, [Vector2(-0.341, 0.0255), Vector2(-0.3475, -0.109), Vector2(-0.359, -0.109), Vector2(-0.352, 0.0255)], 0.042, 0.004)
	for i in 5:
		_plate(RUBBER, _at(-0.3565 + i * 0.00035, -0.085 + i * 0.022), Vector3(0.036, 0.0016, 0.0012))
	# The latch that lets it slide, under the sleeve, and a socket for a sling.
	_side(TAN, _chamfer([Vector2(-0.182, -0.027), Vector2(-0.24, -0.027), Vector2(-0.232, -0.04), Vector2(-0.19, -0.037)], 0.002), 0.016, 0.003)
	for side: float in [-1.0, 1.0]:
		_bar(STEEL, _at(-0.3, 0.0, side * 0.0205), _at(-0.3, 0.0, side * 0.0221), 0.0062, 12)
		_bar(RUBBER, _at(-0.3, 0.0, side * 0.0221), _at(-0.3, 0.0, side * 0.0223), 0.004, 12)


## Open reflex sight clamped on the rail, its back `ahead` of the origin: a
## housing with the battery behind and a hood round the window in front. The
## middle of the window is where the eye is when the carbine is aimed.
func _reflex_sight(ahead: float) -> void:
	# The clamp, with its lever on the left.
	_section(ALU, _chamfer([Vector2(-0.0135, 0.0262), Vector2(0.0135, 0.0262), Vector2(0.0135, 0.0375), Vector2(-0.0135, 0.0375)], 0.0018), ahead, ahead + 0.056, 0.001)
	_side(STEEL, _chamfer([Vector2(ahead + 0.006, 0.028), Vector2(ahead + 0.043, 0.0285), Vector2(ahead + 0.047, 0.0315), Vector2(ahead + 0.043, 0.0345), Vector2(ahead + 0.006, 0.0358)], 0.001), 0.0036, 0.001, -0.0158)
	_bar(STEEL, _at(ahead + 0.011, 0.032, -0.0135), _at(ahead + 0.011, 0.032, -0.0192), 0.0046, 6)
	for at: float in [0.018, 0.042]:
		_bar(STEEL, _at(ahead + at, 0.0318, 0.0135), _at(ahead + at, 0.0318, 0.0158), 0.0034, 6)

	# The housing: low under the window, higher behind it.
	_side(ALU, _chamfer([
		Vector2(ahead, 0.0375), Vector2(ahead + 0.056, 0.0375), Vector2(ahead + 0.056, 0.0465), Vector2(ahead + 0.05, 0.0495), Vector2(ahead + 0.0215, 0.0495),
		Vector2(ahead + 0.0185, 0.053), Vector2(ahead + 0.003, 0.053), Vector2(ahead, 0.05),
	], 0.0012), 0.031, 0.0028)
	for side: float in [-1.0, 1.0]:
		_block(RUBBER, _at(ahead - 0.0002, 0.0455, side * 0.0072), Vector3(0.0088, 0.0062, 0.0012), 0.0006)
	_bar(STEEL, _at(ahead + 0.01, 0.0452, 0.0155), _at(ahead + 0.01, 0.0452, 0.0196), 0.0058, 12)
	_plate(RUBBER, _at(ahead + 0.01, 0.0452, 0.01965), Vector3(0.0004, 0.0012, 0.008))
	_bar(STEEL, _at(ahead + 0.011, 0.0531, 0.0), _at(ahead + 0.011, 0.0548, 0.0), 0.0036, 10)
	_bar(STEEL, _at(ahead + 0.044, 0.0435, 0.0155), _at(ahead + 0.044, 0.0435, 0.0178), 0.0032, 10)

	# The hood, and the glass in it.
	var hood: Array[Vector2] = []
	var corners := [[0.0178, 0.0815, 0.0065], [0.0146, 0.0783, 0.0034]]
	for i in 2:
		var half: float = corners[i][0]
		var top: float = corners[i][1]
		var round: float = corners[i][2]
		var ring: Array[Vector2] = [Vector2(half, 0.0492)]
		for step in 5:
			var turn := PI * 0.5 * step / 4.0
			ring.append(Vector2(half - round + cos(turn) * round, top - round + sin(turn) * round))
		for step in 5:
			var turn := PI * 0.5 * (1.0 + step / 4.0)
			ring.append(Vector2(-half + round + cos(turn) * round, top - round + sin(turn) * round))
		ring.append(Vector2(-half, 0.0492))
		if i == 1:
			ring.reverse()
		hood.append_array(ring)
	_section(ALU, hood, ahead + 0.0225, ahead + 0.0465, 0.0008)
	_pane(LENS, _at(ahead + 0.0345, 0.0638), Vector2(0.0292, 0.029))
	for side: float in [-1.0, 1.0]:
		_side(ALU, _chamfer([Vector2(ahead + 0.0465, 0.0492), Vector2(ahead + 0.054, 0.0492), Vector2(ahead + 0.0465, 0.066)], 0.001), 0.003, 0.0008, side * 0.0162)


## Folded-down iron sight on the rail, its hinge `ahead` of the origin: the
## one at the back has a wheel to set it sideways, the one in front a post
## between two ears.
func _flip_sight(ahead: float, rear: bool) -> void:
	_section(STEEL, _chamfer([Vector2(-0.0128, 0.0262), Vector2(0.0128, 0.0262), Vector2(0.0128, 0.0372), Vector2(-0.0128, 0.0372)], 0.0016), ahead - 0.012, ahead + 0.014, 0.0008)
	_bar(STEEL, _at(ahead, 0.031, -0.0128), _at(ahead, 0.031, -0.0166), 0.0038, 6)
	_bar(STEEL, _at(ahead + 0.0095, 0.0392, -0.0112), _at(ahead + 0.0095, 0.0392, 0.0112), 0.0026, 10)
	var arm := [Vector2(ahead + 0.011, 0.0372), Vector2(ahead + 0.011, 0.0418), Vector2(ahead - 0.02, 0.043), Vector2(ahead - 0.027, 0.041), Vector2(ahead - 0.027, 0.0372)]
	if rear:
		_side(STEEL, _chamfer(arm, 0.001), 0.0165, 0.0012)
		_bar(STEEL, _at(ahead - 0.016, 0.0405, 0.0082), _at(ahead - 0.016, 0.0405, 0.0138), 0.0046, 10)
		_ring(RUBBER, _at(ahead - 0.0272, 0.0401), Vector3.BACK, 0.0016, 0.0005)
	else:
		for side: float in [-1.0, 1.0]:
			_side(STEEL, _chamfer(arm, 0.001), 0.003, 0.0008, side * 0.0052)
		_side(STEEL, [Vector2(ahead + 0.01, 0.0372), Vector2(ahead + 0.01, 0.04), Vector2(ahead - 0.024, 0.04), Vector2(ahead - 0.024, 0.0372)], 0.0018, 0.0004)


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
	var index := [_at(-0.04, -0.045, 0.024), _at(-0.012, -0.028, 0.02), _at(0.016, -0.022, 0.0185), _at(0.042, -0.02, 0.0175)]
	part("ArmR", Transform3D(Basis(), _at(-0.135, -0.1, 0.035)))
	if _gloved():
		_glove(Transform3D(around, _at(-0.0464, -0.08)), Vector2(0.0145, 0.026), false, 30.0, _at(-0.17, -0.13, 0.02), 0.03, 0.014, _at(-0.42, -0.24, 0.14),
			[_at(-0.08, -0.036, 0.004), _at(-0.062, -0.024, -0.016), _at(-0.036, -0.021, -0.023), _at(-0.012, -0.02, -0.023)], index)
	else:
		_hand(Transform3D(around, _at(-0.0464, -0.08)), Vector2(0.0145, 0.026), -25, -1,
			_at(-0.135, -0.1, 0.035), _at(-0.42, -0.24, 0.14),
			[_at(-0.082, -0.036, 0.008), _at(-0.066, -0.022, -0.014), _at(-0.04, -0.02, -0.022), _at(-0.016, -0.019, -0.022)], index)
	part("ArmL", Transform3D(Basis(), _at(-0.043, -0.085)))
	if _gloved():
		# The palm against the left of the grip, the fingers over those of the
		# other hand; to change the magazine it goes under the grip and takes it.
		_glove(Transform3D(around, _at(-0.043, -0.088)), Vector2(0.026, 0.036), true, 200.0, _at(-0.13, -0.15, -0.09), 0.036, 0.0, _at(-0.36, -0.3, -0.25),
			[_at(-0.07, -0.05, -0.034), _at(-0.038, -0.032, -0.03), _at(-0.008, -0.025, -0.027), _at(0.02, -0.023, -0.025)], [])
		_holds_also("mag", Transform3D(around, _at(-0.062, -0.155)), Vector2(0.0105, 0.02), 185.0, _at(-0.1, -0.22, -0.05), 0.03, 0.0, _at(-0.2, -0.45, -0.2))
	else:
		_hand(Transform3D(around, _at(-0.043, -0.088)), Vector2(0.026, 0.036), 215, 1,
			_at(-0.105, -0.13, -0.075), _at(-0.36, -0.3, -0.25),
			[_at(-0.066, -0.052, -0.032), _at(-0.036, -0.032, -0.028), _at(-0.006, -0.024, -0.025), _at(0.02, -0.022, -0.023)])

	marker("Muzzle", Transform3D(Basis(), _at(0.14)))
	marker("Eject", Transform3D(Basis(), _at(0.022, 0.012, 0.016)))
	marker("MagHold", Transform3D(Basis(), _at(-0.065, -0.17)))


# --- Shotgun -------------------------------------------------------------------


## Pump-action shotgun with a ghost-ring sight, a heat shield over the barrel
## and spare shells on the receiver.
func _shotgun() -> void:
	model("shotgun")

	# Receiver: flat-sided under a rounded top, with the trigger plate let in below.
	_section(STEEL, [
		Vector2(-0.02, -0.05), Vector2(0.02, -0.05), Vector2(0.02, 0.008), Vector2(0.0185, 0.014), Vector2(0.0145, 0.019), Vector2(0.0085, 0.0218),
		Vector2(-0.0085, 0.0218), Vector2(-0.0145, 0.019), Vector2(-0.0185, 0.014), Vector2(-0.02, 0.008),
	], -0.15, 0.07, 0.0025)
	_picatinny(ALU, -0.138, 0.012, 0.0312, 0.0205)
	_side(ALU, _chamfer([Vector2(-0.046, -0.049), Vector2(0.034, -0.049), Vector2(0.034, -0.0555), Vector2(-0.046, -0.0555)], 0.002), 0.034, 0.0012)
	_plate(RUBBER, _at(-0.03, -0.0558), Vector3(0.024, 0.0006, 0.08))
	_plate(BARE, _at(-0.03, -0.0562), Vector3(0.018, 0.0004, 0.062))
	_plate(RUBBER, _at(-0.01, -0.004, 0.0203), Vector3(0.0006, 0.022, 0.075))
	# The safety, a button right through behind the trigger, and the pins of the trigger plate.
	_bar(STEEL, _at(-0.105, -0.03, -0.0215), _at(-0.105, -0.03, 0.0215), 0.004, 10)
	_bar("enamel_red", _at(-0.105, -0.03, -0.0217), _at(-0.105, -0.03, -0.0211), 0.0046, 10)
	for pin: float in [-0.02, 0.03]:
		_bar(STEEL, _at(pin, -0.034, -0.0206), _at(pin, -0.034, 0.0206), 0.0022, 10)
	_block(STEEL, _at(0.032, -0.046, -0.0185), Vector3(0.005, 0.006, 0.014), 0.0015)
	_grip()

	# Ghost ring behind, between two ears, and a blade on a ramp in front.
	_section(STEEL, _chamfer([Vector2(-0.0128, 0.0268), Vector2(0.0128, 0.0268), Vector2(0.0128, 0.0358), Vector2(-0.0128, 0.0358)], 0.0016), -0.128, -0.102, 0.0008)
	_bar(STEEL, _at(-0.115, 0.031, -0.0128), _at(-0.115, 0.031, -0.0166), 0.0038, 6)
	_ring(STEEL, _at(-0.115, 0.043), Vector3.BACK, 0.007, 0.0018)
	for side: float in [-1.0, 1.0]:
		_side(STEEL, _chamfer([Vector2(-0.127, 0.0358), Vector2(-0.103, 0.0358), Vector2(-0.106, 0.0555), Vector2(-0.122, 0.0555)], 0.002), 0.003, 0.0008, side * 0.0122)
	_side(STEEL, _chamfer([Vector2(0.515, 0.0108), Vector2(0.552, 0.0108), Vector2(0.548, 0.021), Vector2(0.524, 0.023)], 0.0015), 0.009, 0.0015)
	_side(STEEL, _chamfer([Vector2(0.528, 0.021), Vector2(0.541, 0.021), Vector2(0.539, 0.043), Vector2(0.533, 0.043)], 0.001), 0.003, 0.0006)
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
	_section(STEEL, _chamfer([Vector2(-0.015, -0.042), Vector2(0.015, -0.042), Vector2(0.015, 0.014), Vector2(-0.015, 0.014)], 0.006), 0.452, 0.468, 0.001)
	_bar(STEEL, _at(0.46, -0.014, -0.0155), _at(0.46, -0.014, 0.0165), 0.0045, 6)

	# Heat shield: half a tube of pierced sheet steel over the barrel, in two clamps.
	var shield: Array[Vector2] = []
	for i in 11:
		var round := deg_to_rad(12.0 + 156.0 * i / 10.0)
		shield.append(Vector2(cos(round), sin(round)) * 0.0152)
	for i in 11:
		var round := deg_to_rad(168.0 - 156.0 * i / 10.0)
		shield.append(Vector2(cos(round), sin(round)) * 0.0136)
	_section(STEEL, shield, 0.1, 0.43, 0.0005)
	for i in 8:
		for lean: float in [42.0, 90.0, 138.0]:
			var out := Vector3(cos(deg_to_rad(lean)), sin(deg_to_rad(lean)), 0)
			_slot(_at(0.122 + i * 0.041) + out * 0.01525, out, 0.026, 0.0062)
	for ahead: float in [0.104, 0.424]:
		_bar(STEEL, _at(ahead - 0.004), _at(ahead + 0.004), 0.0158, 16)

	# Stock.
	_side(POLY, _chamfer([
		Vector2(-0.15, 0.016), Vector2(-0.21, 0.019), Vector2(-0.355, 0.013), Vector2(-0.362, -0.115), Vector2(-0.33, -0.118),
		Vector2(-0.25, -0.052), Vector2(-0.19, -0.042), Vector2(-0.15, -0.04),
	], 0.004), 0.04, 0.008)
	_side(RUBBER, [Vector2(-0.353, 0.015), Vector2(-0.36, -0.118), Vector2(-0.372, -0.118), Vector2(-0.365, 0.015)], 0.042, 0.004)
	for i in 5:
		_plate(RUBBER, _at(-0.3695 + i * 0.0003, -0.094 + i * 0.022), Vector3(0.036, 0.0016, 0.0012))
	_slot(_at(-0.31, -0.05, -0.0201), Vector3.LEFT, 0.03, 0.008)
	_slot(_at(-0.31, -0.05, 0.0201), Vector3.RIGHT, 0.03, 0.008)

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
	# To load, the same hand brings a shell up under the receiver and thumbs it in.
	_holds_also("shell", Transform3D(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), _at(-0.035, -0.064)), Vector2(0.0105, 0.0105), -96.0,
		_at(-0.1, -0.075, -0.07), 0.034, 0.0, _at(-0.3, -0.36, -0.2),
		[_at(-0.085, -0.074, -0.014), _at(-0.058, -0.064, -0.008), _at(-0.03, -0.059, -0.004), _at(-0.006, -0.057, -0.001)])

	marker("Muzzle", Transform3D(Basis(), _at(0.585)))
	marker("Eject", Transform3D(Basis(), _at(-0.01, 0.0, 0.026)))
	marker("MagHold", Transform3D(Basis(), _at(-0.03, -0.085)))


# --- Submachine gun ------------------------------------------------------------


## Compact submachine gun: a stick magazine, a wire stock and a cocking
## handle on the left that travels with the bolt.
func _smg() -> void:
	model("smg")

	# Receiver: a tube of pressed steel, eight-sided above and square below,
	# with the lower of moulded plastic under it.
	_section(ALU, [
		Vector2(-0.017, -0.02), Vector2(0.017, -0.02), Vector2(0.017, 0.012), Vector2(0.0135, 0.021), Vector2(0.0078, 0.0245),
		Vector2(-0.0078, 0.0245), Vector2(-0.0135, 0.021), Vector2(-0.017, 0.012),
	], -0.12, 0.2, 0.0012)
	_section(ALU, _chamfer([Vector2(-0.0165, -0.038), Vector2(0.0165, -0.038), Vector2(0.0175, -0.019), Vector2(-0.0175, -0.019)], 0.002), 0.085, 0.2, 0.002)
	_picatinny(ALU, -0.114, 0.194, 0.0339, 0.0238)
	_side(POLY, _chamfer([
		Vector2(-0.12, -0.018), Vector2(-0.12, -0.042), Vector2(-0.09, -0.053), Vector2(-0.04, -0.053), Vector2(-0.03, -0.047),
		Vector2(0.03, -0.047), Vector2(0.028, -0.086), Vector2(0.074, -0.091), Vector2(0.078, -0.03), Vector2(0.078, -0.018),
	], 0.002), 0.03, 0.003)
	_side(POLY, [Vector2(0.0265, -0.079), Vector2(0.026, -0.0875), Vector2(0.0745, -0.0925), Vector2(0.076, -0.084)], 0.0335, 0.0018)
	for pin: Vector2 in [Vector2(-0.1, -0.032), Vector2(0.07, -0.03), Vector2(-0.014, -0.035)]:
		_bar(STEEL, _at(pin.x, pin.y, -0.0156), _at(pin.x, pin.y, 0.0156), 0.0026, 10)
	_bar(STEEL, _at(-0.062, -0.034, -0.015), _at(-0.062, -0.034, -0.0178), 0.005, 12)
	_block(STEEL, _at(-0.05, -0.034, -0.0186), Vector3(0.003, 0.006, 0.024), 0.0012)
	_bar("enamel_red", _at(-0.062, -0.0245, -0.0149), _at(-0.062, -0.0245, -0.0153), 0.0016, 8)
	_bar(STEEL, _at(0.022, -0.036, 0.015), _at(0.022, -0.036, 0.0178), 0.0042, 10)
	_grip()
	_slot(_at(0.115, 0.004, -0.0171), Vector3.LEFT, 0.1, 0.0065)
	_plate(RUBBER, _at(0.03, 0.002, 0.0172), Vector3(0.0006, 0.016, 0.05))
	_side(ALU, [Vector2(-0.012, -0.002), Vector2(0.0, -0.006), Vector2(0.0, 0.009), Vector2(-0.008, 0.01)], 0.008, 0.0015, 0.0195)
	for i in 3:
		_slot(_at(0.115 + i * 0.03, -0.029, -0.0172), Vector3.LEFT, 0.02, 0.006)
		_slot(_at(0.115 + i * 0.03, -0.029, 0.0172), Vector3.RIGHT, 0.02, 0.006)
	# A stop for the hand, so that it stays behind the muzzle.
	_side(POLY, _chamfer([Vector2(0.172, -0.038), Vector2(0.2, -0.038), Vector2(0.197, -0.06), Vector2(0.181, -0.06)], 0.003), 0.02, 0.004)

	# Short barrel with lugs for a suppressor.
	_bar(STEEL, _at(0.2), _at(0.236), 0.008, 16)
	_bar(STEEL, _at(0.2), _at(0.206), 0.0135, 16)
	_turned(STEEL, _at(0.236), Vector3.FORWARD, [
		Vector2(0.008, 0), Vector2(0.011, 0), Vector2(0.011, 0.006), Vector2(0.009, 0.008), Vector2(0.009, 0.016), Vector2(0.012, 0.018),
		Vector2(0.012, 0.04), Vector2(0.0055, 0.04), Vector2(0.005, 0.02),
	], 16)
	_bar(RUBBER, _at(0.258), _at(0.259), 0.0052, 12)

	# Sights: an aperture behind and a hooded post in front, each clamped on the rail.
	for ahead: float in [-0.09, 0.175]:
		_section(STEEL, _chamfer([Vector2(-0.0128, 0.0298), Vector2(0.0128, 0.0298), Vector2(0.0128, 0.0398), Vector2(-0.0128, 0.0398)], 0.0016), ahead - 0.012, ahead + 0.012, 0.0008)
		_bar(STEEL, _at(ahead, 0.0345, -0.0128), _at(ahead, 0.0345, -0.0166), 0.0038, 6)
	_side(STEEL, _chamfer([Vector2(-0.094, 0.0398), Vector2(-0.086, 0.0398), Vector2(-0.087, 0.047), Vector2(-0.093, 0.047)], 0.001), 0.006, 0.0008)
	_ring(STEEL, _at(-0.09, 0.052), Vector3.BACK, 0.0062, 0.002)
	for side: float in [-1.0, 1.0]:
		_side(STEEL, _chamfer([Vector2(-0.1, 0.0398), Vector2(-0.08, 0.0398), Vector2(-0.083, 0.061), Vector2(-0.096, 0.061)], 0.002), 0.0028, 0.0008, side * 0.0114)
	_ring(STEEL, _at(0.175, 0.052), Vector3.BACK, 0.0105, 0.0018)
	_side(STEEL, _chamfer([Vector2(0.169, 0.0398), Vector2(0.181, 0.0398), Vector2(0.178, 0.0425), Vector2(0.172, 0.0425)], 0.0008), 0.02, 0.0008)
	_block(STEEL, _at(0.175, 0.0468), Vector3(0.0022, 0.011, 0.003), 0.0005)
	_dot(_at(0.1734, 0.0505), 0.001)

	# Wire stock, pulled out, on the cap that closes the receiver.
	_section(ALU, _chamfer([Vector2(-0.0178, -0.021), Vector2(0.0178, -0.021), Vector2(0.0178, 0.018), Vector2(0.012, 0.0245), Vector2(-0.012, 0.0245), Vector2(-0.0178, 0.018)], 0.002), -0.128, -0.119, 0.001)
	for side: float in [-1.0, 1.0]:
		_bar(STEEL, _at(-0.05, 0.006, side * 0.0195), _at(-0.33, 0.006, side * 0.0195), 0.0038, 10)
		_block(ALU, _at(-0.1, 0.006, side * 0.0185), Vector3(0.008, 0.012, 0.03), 0.002)
		_bar(STEEL, _at(-0.33, 0.006, side * 0.0195), _at(-0.336, -0.012, side * 0.012), 0.0038, 10)
	_side(POLY, _chamfer([Vector2(-0.329, 0.03), Vector2(-0.343, 0.03), Vector2(-0.343, -0.088), Vector2(-0.329, -0.088)], 0.004), 0.05, 0.006)
	_side(RUBBER, [Vector2(-0.342, 0.03), Vector2(-0.342, -0.088), Vector2(-0.349, -0.086), Vector2(-0.349, 0.028)], 0.048, 0.003)

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
	_holds_also("mag", Transform3D(Basis(), _at(0.056, -0.165)), Vector2(0.0102, 0.018), 180.0,
		_at(-0.03, -0.2, -0.03), 0.03, 0.0, _at(-0.12, -0.42, -0.2))

	marker("Muzzle", Transform3D(Basis(), _at(0.29)))
	marker("Eject", Transform3D(Basis(), _at(0.03, 0.004, 0.022)))
	marker("MagHold", Transform3D(Basis(), _at(0.057, -0.2)))


# --- Marksman rifle ------------------------------------------------------------


## Semi-automatic rifle with a long barrel and a telescopic sight. Aimed, the
## HUD takes over with the picture through the scope; this is what is seen of
## it from the hip.
func _marksman() -> void:
	model("marksman")

	# The receivers of the carbine, a size up for the longer cartridge.
	var wide := UPPER_TUBE.map(func(corner: Vector2) -> Vector2: return Vector2(corner.x * 1.07 if absf(corner.x) > 0.008 else corner.x, corner.y))
	_section(ALU, wide, -0.11, 0.112, 0.0012)
	_picatinny(ALU, -0.108, 0.11, RAIL_TOP, 0.019)
	_side(ALU, _chamfer([
		Vector2(-0.11, -0.019), Vector2(-0.11, -0.044), Vector2(-0.09, -0.0515), Vector2(-0.04, -0.0515), Vector2(-0.03, -0.047),
		Vector2(0.02, -0.047), Vector2(0.016, -0.092), Vector2(0.104, -0.1), Vector2(0.112, -0.06), Vector2(0.112, -0.019),
	], 0.002), 0.032, 0.002)
	_side(ALU, [Vector2(0.0155, -0.084), Vector2(0.015, -0.0925), Vector2(0.1045, -0.101), Vector2(0.106, -0.092)], 0.0355, 0.0018)
	for pin: Vector2 in [Vector2(-0.095, -0.036), Vector2(0.1, -0.036), Vector2(-0.012, -0.036)]:
		_bar(STEEL, _at(pin.x, pin.y, -0.0166), _at(pin.x, pin.y, 0.0166), 0.0028, 10)
	_bar(STEEL, _at(-0.062, -0.034, -0.016), _at(-0.062, -0.034, -0.0188), 0.005, 12)
	_block(STEEL, _at(-0.05, -0.034, -0.0196), Vector3(0.003, 0.006, 0.024), 0.0012)
	_bar("enamel_red", _at(-0.062, -0.0245, -0.0159), _at(-0.062, -0.0245, -0.0163), 0.0016, 8)
	_slot(_at(0.045, 0.006, -0.0177), Vector3.LEFT, 0.11, 0.0065)
	_plate(RUBBER, _at(0.02, 0.003, 0.0178), Vector3(0.0006, 0.018, 0.075))
	_side(ALU, [Vector2(-0.038, 0.0), Vector2(-0.022, -0.004), Vector2(-0.022, 0.011), Vector2(-0.031, 0.012)], 0.012, 0.002, 0.0205)
	_bar(STEEL, _at(0.012, -0.031, 0.016), _at(0.012, -0.031, 0.0188), 0.0042, 10)
	_grip()

	# A long handguard on its own, clear of the barrel, with a rail all the way.
	_bar(STEEL, _at(0.105), _at(0.118), 0.0235, 20)
	_section(ALU, OCTAGON, 0.115, 0.5, 0.0015)
	_picatinny(ALU, 0.118, 0.498, RAIL_TOP, 0.019)
	_guard_slots(0.16, 6)
	_turned(STEEL, _at(0.48), Vector3.FORWARD, [Vector2(0.0098, 0), Vector2(0.0098, 0.175), Vector2(0.0082, 0.178), Vector2(0.0082, 0.185)], 20)
	# Muzzle brake: a block with three ports a side.
	_section(STEEL, _chamfer([Vector2(-0.0115, -0.0105), Vector2(0.0115, -0.0105), Vector2(0.0115, 0.0105), Vector2(-0.0115, 0.0105)], 0.003), 0.665, 0.731, 0.0012)
	for i in 3:
		for side: float in [-1.0, 1.0]:
			_slot(_at(0.68 + i * 0.018, 0, side * 0.0116), Vector3(side, 0, 0), 0.011, 0.012)
	_bar(RUBBER, _at(0.7311), _at(0.7314), 0.0055, 12)

	# Bipod folded back under the handguard.
	_section(ALU, _chamfer([Vector2(-0.015, -0.033), Vector2(0.015, -0.033), Vector2(0.015, -0.0195), Vector2(-0.015, -0.0195)], 0.003), 0.44, 0.47, 0.001)
	for side: float in [-1.0, 1.0]:
		_bar(STEEL, _at(0.452, -0.03, side * 0.013), _at(0.24, -0.034, side * 0.016), 0.0048, 10)
		_bar(ALU, _at(0.34, -0.0325, side * 0.0145), _at(0.24, -0.034, side * 0.016), 0.0062, 10)
		_ball(RUBBER, _at(0.232, -0.034, side * 0.016), 0.0085)

	# The receiver extension with its lock nut, and a stock with a raised cheek piece.
	_bar(ALU, _at(-0.11), _at(-0.3), 0.0148, 20)
	_section(STEEL, _chamfer([Vector2(-0.016, -0.044), Vector2(0.016, -0.044), Vector2(0.0195, -0.008), Vector2(0.0195, 0.008), Vector2(0.012, 0.0185), Vector2(-0.012, 0.0185), Vector2(-0.0195, 0.008), Vector2(-0.0195, -0.008)], 0.003), -0.1135, -0.1105, 0.0008)
	_bar(STEEL, _at(-0.1135), _at(-0.1215), 0.0192, 12)
	_side(POLY, _chamfer([
		Vector2(-0.16, 0.026), Vector2(-0.335, 0.026), Vector2(-0.343, -0.112), Vector2(-0.305, -0.114), Vector2(-0.28, -0.06),
		Vector2(-0.2, -0.036), Vector2(-0.16, -0.03),
	], 0.004), 0.042, 0.007)
	_side(POLY, _chamfer([Vector2(-0.18, 0.026), Vector2(-0.305, 0.026), Vector2(-0.3, 0.047), Vector2(-0.19, 0.047)], 0.005), 0.036, 0.009)
	_side(RUBBER, [Vector2(-0.333, 0.028), Vector2(-0.341, -0.115), Vector2(-0.353, -0.115), Vector2(-0.345, 0.028)], 0.044, 0.004)
	for i in 5:
		_plate(RUBBER, _at(-0.3505 + i * 0.0004, -0.09 + i * 0.024), Vector3(0.038, 0.0016, 0.0012))
	for ahead: float in [-0.21, -0.275]:
		_bar(STEEL, _at(ahead, 0.02, -0.0215), _at(ahead, 0.02, -0.025), 0.006, 10)
		_bar(STEEL, _at(ahead, 0.02, -0.025), _at(ahead, 0.02, -0.0262), 0.0072, 12)

	# Telescopic sight in two rings.
	var eye := 0.067
	for ahead: float in [-0.012, 0.118]:
		_section(ALU, _chamfer([Vector2(-0.0135, 0.0262), Vector2(0.0135, 0.0262), Vector2(0.0135, 0.05), Vector2(-0.0135, 0.05)], 0.002), ahead - 0.011, ahead + 0.011, 0.001)
		_bar(ALU, _at(ahead - 0.011, eye), _at(ahead + 0.011, eye), 0.0192, 20)
		_bar(STEEL, _at(ahead, 0.0315, -0.0135), _at(ahead, 0.0315, -0.0178), 0.005, 6)
		for side: float in [-1.0, 1.0]:
			for along: float in [-0.006, 0.006]:
				_bar(STEEL, _at(ahead + along, eye + 0.0125, side * 0.0135), _at(ahead + along, eye + 0.0165, side * 0.0135), 0.0022, 6)
	_turned(ALU, _at(-0.115, eye), Vector3.FORWARD, [
		Vector2(0.0172, 0), Vector2(0.021, 0.004), Vector2(0.021, 0.05), Vector2(0.0185, 0.062), Vector2(0.0152, 0.07), Vector2(0.0152, 0.215),
		Vector2(0.019, 0.24), Vector2(0.027, 0.28), Vector2(0.027, 0.35), Vector2(0.0255, 0.352), Vector2(0.0255, 0.345),
	], 24)
	_bar(RUBBER, _at(-0.1155, eye), _at(-0.085, eye), 0.0222, 20)
	_bar(OPTIC, _at(-0.1162, eye), _at(-0.1158, eye), 0.0175, 20)
	_bar(OPTIC, _at(0.2295, eye), _at(0.23, eye), 0.0255, 20)
	_section(ALU, _chamfer([Vector2(-0.0175, eye - 0.0175), Vector2(0.0175, eye - 0.0175), Vector2(0.0175, eye + 0.0175), Vector2(-0.0175, eye + 0.0175)], 0.006), 0.034, 0.07, 0.002)
	var knob: Array[Vector2] = [Vector2(0.011, 0), Vector2(0.011, 0.01), Vector2(0.0128, 0.011), Vector2(0.0128, 0.022), Vector2(0.011, 0.024), Vector2(0, 0.024)]
	_turned(ALU, _at(0.052, eye + 0.0165), Vector3.UP, knob, 16)
	_turned(ALU, _at(0.052, eye, 0.0165), Vector3.RIGHT, knob, 16)
	_turned(ALU, _at(0.052, eye, -0.0165), Vector3.LEFT, knob, 16)
	_bar(STEEL, _at(-0.062, eye), _at(-0.05, eye), 0.0208, 24)

	part("Bolt")
	_bar(STEEL, _at(0.09, 0.006, -0.018), _at(0.09, 0.006, -0.034), 0.0045, 10)
	_ball(STEEL, _at(0.09, 0.006, -0.036), 0.0072)

	part("Mag", Transform3D(Basis(), _at(0.06, -0.06)))
	_side(POLY, _chamfer([Vector2(0.024, -0.03), Vector2(0.021, -0.152), Vector2(0.099, -0.158), Vector2(0.098, -0.03)], 0.003), 0.026, 0.003)
	for i in 5:
		_block(POLY, _at(0.022, -0.108 - i * 0.0095), Vector3(0.0272, 0.0032, 0.0046), 0.0014)
		_block(POLY, _at(0.0985, -0.108 - i * 0.0095), Vector3(0.0272, 0.0032, 0.0046), 0.0014)
	_block(POLY, _at(0.06, -0.156), Vector3(0.03, 0.01, 0.084), 0.003, Vector3(-4, 0, 0))
	for side: float in [-1.0, 1.0]:
		_side(POLY, [Vector2(0.034, -0.105), Vector2(0.033, -0.146), Vector2(0.088, -0.15), Vector2(0.088, -0.105)], 0.0015, 0.0005, side * 0.0132)
	_bar(BRASS, _at(0.03, -0.026), _at(0.092, -0.026), 0.0058, 10)

	_trigger_hand()
	_support_hand(0.285, 0.021)
	_holds_also("mag", Transform3D(Basis(), _at(0.06, -0.125)), Vector2(0.013, 0.038), 180.0,
		_at(-0.03, -0.165, -0.03), 0.03, 0.0, _at(-0.12, -0.42, -0.2))

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


## The outline with every corner that sticks out cut off over `cut`, so that
## what is made of it has a flat chamfer there instead of a sharp edge.
func _chamfer(outline: Array, cut: float) -> Array[Vector2]:
	var points := _ccw(outline)
	var cut_off: Array[Vector2] = []
	for i in points.size():
		var before := points[(i + points.size() - 1) % points.size()] - points[i]
		var after := points[(i + 1) % points.size()] - points[i]
		if after.cross(before) <= 0.0 or before.length() < cut * 2.2 or after.length() < cut * 2.2:
			cut_off.append(points[i])
			continue
		cut_off.append(points[i] + before.normalized() * cut)
		cut_off.append(points[i] + after.normalized() * cut)
	return cut_off


## Accessory rail to the pattern that every sight and lamp clamps onto (MIL-STD
## 1913): a dovetail 21.2 mm wide, slotted every 10 mm. It runs from `from` to
## `to` ahead of the origin with its top `top` above the bore, on a neck that
## goes down to `base`.
func _picatinny(mat: String, from: float, to: float, top: float, base: float) -> void:
	var floor := top - 0.003
	_section(mat, [Vector2(-0.0078, base), Vector2(0.0078, base), Vector2(0.0078, top - 0.00554), Vector2(0.01037, floor), Vector2(-0.01037, floor), Vector2(-0.0078, top - 0.00554)], from, to, 0.0004)
	var lands := int((to - from - 0.00477) / 0.010008) + 1
	var first := from + (to - from - (lands - 1) * 0.010008 - 0.00477) * 0.5
	for i in lands:
		var at := first + i * 0.010008
		_section(mat, [Vector2(-0.01037, floor), Vector2(0.01037, floor), Vector2(0.0106, top - 0.00277), Vector2(0.007835, top), Vector2(-0.007835, top), Vector2(-0.0106, top - 0.00277)], at, at + 0.00477, 0.00035)


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


## Rows of slots down an octagonal handguard, the first `ahead` of the origin:
## on its sides and underneath, and shorter ones on the four slanted faces.
func _guard_slots(ahead: float, count: int) -> void:
	for i in count:
		var at := ahead + i * 0.056
		_slot(_at(at, 0, -0.0204), Vector3.LEFT)
		_slot(_at(at, 0, 0.0204), Vector3.RIGHT)
		_slot(_at(at, -0.0204), Vector3.DOWN)
		for side: float in [-1.0, 1.0]:
			for up: float in [-1.0, 1.0]:
				_slot(_at(at + 0.028, up * 0.01445, side * 0.01445), Vector3(side, up, 0).normalized(), 0.022, 0.006)


## Glowing dot on the back of a sight, facing the shooter.
func _dot(at: Vector3, radius := 0.0014) -> void:
	_bar(GLOW, at, at + Vector3(0, 0, 0.0004), radius, 8)


## Right hand around a pistol grip that hangs where the rifle's does, with the
## index finger laid along the receiver. Shift `_m` for a grip that sits elsewhere.
func _trigger_hand() -> void:
	var grip := Vector3(0, 0.96, -0.28)
	var around := Transform3D(Basis(Vector3.RIGHT, grip, Vector3.RIGHT.cross(grip)), _at(-0.079, -0.1))
	var elbow := _at(-0.42, -0.27, 0.13)
	var index := [_at(-0.068, -0.064, 0.025), _at(-0.04, -0.046, 0.0225), _at(-0.012, -0.04, 0.0215), _at(0.014, -0.038, 0.0205)]
	part("ArmR", _m * Transform3D(Basis(), _at(-0.165, -0.125, 0.05)))
	if _gloved():
		# The palm against the right of the grip and its back, the web of the
		# thumb high up under the receiver, the thumb over to the left.
		_glove(around, Vector2(0.015, 0.024), false, 28.0, _at(-0.2, -0.17, 0.02), 0.03, 0.012, elbow,
			[_at(-0.11, -0.06, 0.0), _at(-0.085, -0.052, -0.02), _at(-0.058, -0.05, -0.026), _at(-0.03, -0.049, -0.026)], index)
		return
	_hand(around, Vector2(0.015, 0.024), -25, -1, _at(-0.165, -0.125, 0.05), elbow,
		[_at(-0.112, -0.062, 0.014), _at(-0.094, -0.05, -0.012), _at(-0.066, -0.049, -0.023), _at(-0.04, -0.046, -0.023)], index)


## Left hand cupped under a handguard of `radius` around the bore, `ahead` of
## the origin, thumb along its left side. It moves with `parent`, if given.
func _support_hand(ahead: float, radius: float, parent := "", drop := 0.0) -> void:
	var around := Transform3D(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), _at(ahead, -drop))
	var elbow := _at(ahead - 0.375, -0.3 - drop, -0.22)
	part("ArmL", _m * Transform3D(Basis(), _at(ahead, -drop)), parent)
	if _gloved():
		# The handguard lies across the palm from below, the fingers come up
		# its right side and the thumb points along its left.
		_glove(around, Vector2(radius, radius), true, -104.0, _at(ahead - 0.07, -0.02 - drop, -0.085), 0.028, 0.0, elbow, [], [])
		return
	_hand(around, Vector2(radius, radius), -110, 1,
		_at(ahead - 0.077, -0.055 - radius - drop, -0.035 - radius), elbow,
		[_at(ahead - 0.025, -0.019 - radius - drop, -0.019 - radius), _at(ahead + 0.008, -0.016 - drop, -0.013 - radius),
			_at(ahead + 0.037, -0.001 - drop, -0.01 - radius), _at(ahead + 0.059, 0.005 - drop, -0.009 - radius)])


## Where a hand holds a weapon that is built without the glove: `frame` sits
## in the middle of what is held, between the middle and the ring finger, its
## Y along it towards the index finger, and `radii` are how thick it is along
## X and Z. The knuckles lie `palm_deg` round from X towards Z, and the back
## of the hand runs from there to `wrist`, the forearm on towards `elbow`.
## Nothing is built of it here; tools/models/held.gd makes markers of it for
## the hands of whoever carries the weapon.
func _hand(_frame: Transform3D, _radii: Vector2, _palm_deg: float, _curl: float, _wrist: Vector3, _elbow: Vector3, _thumb: Array, _index: Array = []) -> void:
	pass


## The glove with bones in it, closed around something: `frame` and `radii`
## say what is held, as for _hand(). The palm lies against it `palm_deg` round
## from X towards Z, at a point `seat` behind the knuckles and `along` what is
## held from the middle of the hand, and from there the hand points to `wrist`,
## which only gives the direction: the hand is one size. Every finger closes
## until it touches, and so does the thumb; one that is given a path goes
## towards the points of it in turn instead. The forearm points at `elbow`.
##
## The arm gets a node Glove at the wrist, -Z along the back of the hand to
## the knuckles and +Y out of the back of it. A left hand is the right one
## seen in a mirror, which is a node Mirror between the two. The glove keeps
## under "holds" how it lies and how its bones are turned, as "rest" for this
## and under their own names for what _holds_also() adds.
func _glove(frame: Transform3D, radii: Vector2, left: bool, palm_deg: float, wrist: Vector3, seat: float, along: float, elbow: Vector3, thumb: Array, index: Array) -> void:
	var glove: Node3D = (load(GLOVE_SCENE) as PackedScene).instantiate()
	var skeleton: Skeleton3D = glove.get_node("Skeleton")
	var arm: Node3D = _parts[_current].node
	arm.add_child(glove)
	glove.owner = _figure
	glove.scene_file_path = ""
	if left:
		var seen := Node3D.new()
		seen.name = "Mirror"
		seen.transform = Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO)
		glove.add_child(seen)
		seen.owner = _figure
		skeleton.owner = null
		skeleton.reparent(seen, false)
	skeleton.owner = _figure
	for node in skeleton.get_children():
		node.owner = _figure
		(node as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	_worn = glove
	_worn_left = left

	var hold := _grasp(frame, radii, palm_deg, wrist, seat, along, elbow, thumb, index)
	glove.transform = hold.at
	for bone in skeleton.get_bone_count():
		skeleton.set_bone_pose_rotation(bone, hold.bones[bone])
	# Holding nothing, the hand is as it was made, a little further open:
	# that is how it travels from one hold to the next.
	var loose := Grasp.new(skeleton, glove.get_meta("bones"))
	loose.open()
	glove.set_meta("holds", {"rest": hold, "loose": {"bones": loose.pose()}})


## Another way for the glove made last to hold something, kept under `hold`
## for scripts/weapons.gd to move the hand to: see _glove() for the rest.
func _holds_also(hold: String, frame: Transform3D, radii: Vector2, palm_deg: float, wrist: Vector3, seat: float, along: float, elbow: Vector3, thumb: Array = []) -> void:
	if _worn == null:
		return
	var holds: Dictionary = _worn.get_meta("holds")
	holds[hold] = _grasp(frame, radii, palm_deg, wrist, seat, along, elbow, thumb, [])
	_worn.set_meta("holds", holds)


## Closes the glove made last around something, see _glove(). Gives where its
## wrist then is, as seen from the arm it is on ("at"), and how every bone of
## it is turned ("bones").
func _grasp(frame: Transform3D, radii: Vector2, palm_deg: float, wrist: Vector3, seat: float, along: float, elbow: Vector3, thumb: Array, index: Array) -> Dictionary:
	var skeleton: Skeleton3D = _worn.find_child("Skeleton", true, false)
	# Everything is worked out for a right hand: for a left one, in a mirror.
	var mirror := Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO) if _worn_left else Transform3D()
	var middle := mirror * frame.origin
	var across := mirror.basis * frame.basis.x
	var axis := mirror.basis * frame.basis.y
	var depth := mirror.basis * frame.basis.z

	var grasp := Grasp.new(skeleton, _worn.get_meta("bones"))
	var start := deg_to_rad(palm_deg)
	var out := (across * cos(start) + depth * sin(start)).normalized()
	var touch := middle + across * radii.x * cos(start) + depth * radii.y * sin(start) + axis * along
	var back := mirror * wrist - touch
	back = (back - out * out.dot(back)).normalized()
	var lies := Basis(out.cross(back), out, back)
	if lies.x.dot(axis) > 0.0:
		push_warning("%s: a hand is laid on with its little finger foremost" % _figure.name)
	var knuckles := (grasp.place(grasp.bone("middle1")).origin + grasp.place(grasp.bone("ring1")).origin) * 0.5
	var hand := Transform3D(lies, touch - lies * (knuckles + Vector3(0.0, -PALM, seat)))

	# From here on in the hand's own space.
	var inwards := hand.affine_inverse()
	var into := func(point: Vector3) -> Vector3: return inwards * (mirror * point)
	grasp.hold(inwards * middle, inwards.basis * across, inwards.basis * depth, radii)
	for finger: String in ["index", "middle", "ring", "little"]:
		if finger == "index" and not index.is_empty():
			grasp.follow(finger, index.map(into))
		else:
			grasp.close(finger)
	if thumb.is_empty():
		grasp.close("thumb")
	else:
		grasp.follow("thumb", thumb.map(into))
	grasp.aim("forearm", into.call(elbow))
	var arm: Node3D = _worn.get_parent()
	var to_arm := Transform3D()
	for part_name: String in _parts:
		if _parts[part_name].node == arm:
			to_arm = (_parts[part_name].frame as Transform3D).affine_inverse()
	return {"at": to_arm * _m * (mirror * hand * mirror), "bones": grasp.pose()}


## The bones of the glove while a hand is being closed around something:
## where each rests, how it is turned so far and what is held. Everything is
## in the space of the hand itself, see tools/build_hands.gd.
class Grasp:
	var names := PackedStringArray()
	var parents := PackedInt32Array()
	var rests: Array[Transform3D] = []
	var turned: Array[Transform3D] = []
	## Bone name -> {length, radius: [where it starts, where it ends]}.
	var sizes := {}
	# What is held: a bar through `_middle`, `_half` thick along `_across` and
	# `_depth`, rounded like a pill.
	var _middle := Vector3.ZERO
	var _across := Vector3.RIGHT
	var _depth := Vector3.BACK
	var _half := Vector2.ONE

	func _init(skeleton: Skeleton3D, bone_sizes: Dictionary) -> void:
		sizes = bone_sizes
		for i in skeleton.get_bone_count():
			names.append(skeleton.get_bone_name(i))
			parents.append(skeleton.get_bone_parent(i))
			rests.append(skeleton.get_bone_rest(i))
			turned.append(skeleton.get_bone_rest(i))

	func bone(bone_name: String) -> int:
		return names.find(bone_name)

	## Where a bone is, with everything above it turned as it is so far.
	func place(index: int) -> Transform3D:
		var at := Transform3D()
		while index >= 0:
			at = turned[index] * at
			index = parents[index]
		return at

	func hold(middle: Vector3, across: Vector3, depth: Vector3, half: Vector2) -> void:
		_middle = middle
		_across = across.normalized()
		_depth = depth.normalized()
		_half = half

	## How far a point is from the surface of what is held.
	func clear(point: Vector3) -> float:
		var corner := minf(_half.x, _half.y)
		var off := point - _middle
		var q := Vector2(absf(off.dot(_across)), absf(off.dot(_depth))) - (_half - Vector2(corner, corner))
		return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - corner

	## Closes a finger joint by joint, each until the bone beyond it touches.
	func close(finger: String) -> void:
		for joint in 3:
			var index := bone("%s%d" % [finger, joint + 1])
			var size: Dictionary = sizes[names[index]]
			var above := place(parents[index])
			var angle := JOINT_OPEN[joint]
			while angle < JOINT_CLOSED[joint]:
				if _touches(above * _bent(index, angle), size):
					break
				angle += 1.0
			turned[index] = _bent(index, angle)

	## Lays a finger along a path: each bone heads for the next point of it.
	func follow(finger: String, path: Array) -> void:
		for joint in 3:
			aim("%s%d" % [finger, joint + 1], path[joint + 1])

	## Turns a bone the short way round to point at something.
	func aim(bone_name: String, at: Vector3) -> void:
		var index := bone(bone_name)
		var above := place(parents[index])
		var now := above * rests[index]
		var turn := Basis(Quaternion(now.basis.y.normalized(), (at - now.origin).normalized()))
		turned[index] = Transform3D(above.basis.inverse() * turn * now.basis, rests[index].origin)

	## Opens every finger a little from where it rests.
	func open() -> void:
		for index in names.size():
			if names[index].right(1) in "123":
				turned[index] = _bent(index, -9.0 if names[index].begins_with("thumb") else -6.0)

	## The rotations of all bones as they are now, to be played back later.
	func pose() -> Array[Quaternion]:
		var all: Array[Quaternion] = []
		for at in turned:
			all.append(at.basis.get_rotation_quaternion())
		return all

	func _bent(index: int, degrees: float) -> Transform3D:
		return rests[index] * Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(degrees)), Vector3.ZERO)

	func _touches(at: Transform3D, size: Dictionary) -> bool:
		for step in range(1, 7):
			var share := step / 6.0
			var thick: float = lerpf(size.radius[0], size.radius[1], share)
			if clear(at.origin + at.basis.y * (size.length * share)) < thick - SQUEEZE:
				return true
		return false


## Point on the outside of something held, see _hand(): `angle` round it,
## `clear` of its surface and `along` it from the middle of the hand.
func _around(frame: Transform3D, radii: Vector2, angle: float, clear: float, along: float) -> Vector3:
	return frame * Vector3((radii.x + clear) * cos(angle), along, (radii.y + clear) * sin(angle))


## Pane of glass that faces the shooter.
func _pane(mat: String, center: Vector3, size: Vector2) -> void:
	var st := _tool(mat, _part, center)
	var half := Vector3(size.x, size.y, 0) * 0.5
	var corners: Array[Vector3] = [Vector3(-half.x, -half.y, 0), Vector3(half.x, -half.y, 0), Vector3(half.x, half.y, 0), Vector3(-half.x, half.y, 0)]
	var points := corners.map(func(corner: Vector3) -> Vector3: return _m * (center + corner))
	var normal := _m.basis * Vector3.BACK
	_quad(st, points, [normal, normal, normal, normal], [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
