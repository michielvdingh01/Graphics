extends "res://tools/level_builder.gd"
## The factory hall: hall with crane and mezzanine, plus an annex with a
## corridor and two rooms. Build with: tools/build_level.sh factory

# Hall dimensions (interior faces).
const HX := 20.0
const HZ := 12.0
const EAVES := 8.0
const RIDGE := 10.6
const BAYS: Array[float] = [-16.0, -8.0, 0.0, 8.0, 16.0]
const TRUSSES: Array[float] = [-12.0, -4.0, 4.0, 12.0]
const DECK_Y := 3.2
# Materials of the machines.
const GREEN := "machine"
const BLUE := "machine_blue"
const BARE := "bare_steel"
const IRON := "dark_steel"
const RUST := "steel"
const YELLOW := "steel_yellow"
const RUBBER := "rubber"
const BRASS := "brass"
const RED := "enamel_red"

## Frame of the machine being built; the part helpers at the end work in it.
var _m: Transform3D


func _level_name() -> String:
	return "factory"


func _describe() -> void:
	_shell()
	_roof()
	_mezzanine()
	_crane()
	_hall_props()
	_annex()
	_exterior()
	_probes()
	_dirt()


func _shell() -> void:
	box("floor", Vector3(5.2, -0.25, -0.1), Vector3(52.4, 0.5, 25.8))

	# South wall: tall windows the evening sun comes through.
	var south: Array = []
	for x in BAYS:
		south.append([x - 2.5, x + 2.5, 3.0, 7.0])
		box("concrete", Vector3(x, 2.94, HZ + 0.15), Vector3(5.3, 0.12, 0.7))
		_mullions(Vector3(x, 5.0, HZ + 0.25), 5.0, 4.0, true, 1.0)
	wall("brick", true, HZ + 0.25, 0.5, -HX - 0.5, HX + 0.5, 0.0, EAVES, south)

	# North wall: a strip of clerestory windows above the mezzanine.
	var north: Array = []
	for x in BAYS:
		north.append([x - 1.5, x + 1.5, 5.4, 7.0])
		_mullions(Vector3(x, 6.2, -HZ - 0.25), 3.0, 1.6, true, 1.0)
	wall("brick", true, -HZ - 0.25, 0.5, -HX - 0.5, HX + 0.5, 0.0, EAVES, north)

	# West wall with the closed loading door.
	wall("brick", false, -HX - 0.25, 0.5, -HZ, HZ, 0.0, EAVES, [[-2.5, 2.5, 0.0, 5.0]])
	box("roof", Vector3(-HX - 0.3, 2.5, 0.0), Vector3(0.08, 5.0, 5.0))
	for z in [-2.6, 2.6]:
		box("steel", Vector3(-HX - 0.05, 2.6, z), Vector3(0.2, 5.2, 0.2))
	box("steel", Vector3(-HX - 0.05, 5.1, 0.0), Vector3(0.2, 0.25, 5.4))
	for y in [0.9, 1.8, 2.7, 3.6, 4.5]:
		box("steel", Vector3(-HX - 0.24, y, 0.0), Vector3(0.04, 0.05, 5.0), Vector3.ZERO, DETAIL | NO_COLLIDE)

	# East wall: two doorways into the annex and windows above its roof.
	var east: Array = [[-10.0, -8.0, 0.0, 2.6], [-3.0, 0.0, 0.0, 3.0], [-9.5, -4.5, 5.2, 7.0], [4.5, 9.5, 3.0, 7.0]]
	wall("brick", false, HX + 0.25, 0.5, -HZ, HZ, 0.0, EAVES, east)
	_mullions(Vector3(HX + 0.25, 6.1, -7.0), 5.0, 1.8, false, 1.0)
	_mullions(Vector3(HX + 0.25, 5.0, 7.0), 5.0, 4.0, false, 1.0)
	box("concrete", Vector3(HX + 0.15, 2.94, 7.0), Vector3(0.7, 0.12, 5.3))
	box("steel", Vector3(HX + 0.25, 2.68, -9.0), Vector3(0.56, 0.16, 2.4))
	box("steel", Vector3(HX + 0.25, 3.08, -1.5), Vector3(0.56, 0.16, 3.4))

	# Gable ends.
	var gable := PackedVector2Array([Vector2(-HZ - 0.5, EAVES), Vector2(HZ + 0.5, EAVES), Vector2(0, RIDGE)])
	var side := Basis(Vector3(0, 0, -1), Vector3.UP, Vector3.RIGHT)
	for x in [-HX - 0.25, HX + 0.25]:
		extrude("brick", gable, 0.5, Transform3D(side, Vector3(x, 0, 0)))

	# Concrete plinth, pilasters and the corbels that carry the crane rails.
	for z in [-HZ, HZ]:
		var inward: float = -signf(z)
		box("concrete", Vector3(0, 0.5, z + inward * 0.04), Vector3(HX * 2.0, 1.0, 0.08), Vector3.ZERO, NO_COLLIDE)
		for x in TRUSSES:
			box("concrete", Vector3(x, EAVES * 0.5, z + inward * 0.2), Vector3(0.7, EAVES, 0.4))
			box("concrete", Vector3(x, 6.05, z + inward * 0.6), Vector3(0.5, 0.5, 0.4), Vector3.ZERO, NO_COLLIDE)
	for x in [-HX, HX]:
		var inward: float = -signf(x)
		for z in [-HZ + 0.35, HZ - 0.35]:
			box("concrete", Vector3(x + inward * 0.2, EAVES * 0.5, z), Vector3(0.4, EAVES, 0.7))


func _roof() -> void:
	var angle := atan2(RIDGE - EAVES, HZ + 0.5)
	var length := Vector2(HZ + 0.5, RIDGE - EAVES).length() + 0.5
	# Local +Z runs down the slope from the ridge; the slab hangs below local Y = 0.
	var slopes: Array[Transform3D] = [
		Transform3D(Basis(Vector3.RIGHT, angle), Vector3(0, RIDGE + 0.2, 0)),
		Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, angle), Vector3(0, RIDGE + 0.2, 0)),
	]
	var skylights: Array = [[-8.0, 8.0], [-16.0, 0.0, 16.0]]
	for i in 2:
		var xf := slopes[i]
		var half := HX + 0.9
		_local_box("roof", xf, Vector3(0, -0.06, 2.4), Vector3(half * 2.0, 0.12, 4.8))
		_local_box("roof", xf, Vector3(0, -0.06, (7.0 + length) * 0.5), Vector3(half * 2.0, 0.12, length - 7.0))
		# The strip in between is broken up by skylights.
		var edge := -half
		# The north slope is mirrored, so its local X runs the other way.
		var holes: Array = skylights[i].map(func(x: float) -> float: return x if i == 0 else -x)
		holes.sort()
		for x: float in holes:
			_local_box("roof", xf, Vector3((edge + x - 2.5) * 0.5, -0.06, 5.9), Vector3(x - 2.5 - edge, 0.12, 2.2))
			for bar in [-1.25, 0.0, 1.25]:
				_local_box("steel", xf, Vector3(x + bar, -0.06, 5.9), Vector3(0.06, 0.08, 2.2), DETAIL | NO_COLLIDE)
			_local_box("glass", xf, Vector3(x, -0.06, 5.9), Vector3(5.0, 0.012, 2.2), GLASS | NO_COLLIDE)
			edge = x + 2.5
		_local_box("roof", xf, Vector3((edge + half) * 0.5, -0.06, 5.9), Vector3(half - edge, 0.12, 2.2))

		for z in [0.6, 2.8, 4.75, 7.05, 9.3, 11.6]:
			_local_box("steel", xf, Vector3(0, -0.19, z), Vector3(HX * 2.0, 0.14, 0.1), DETAIL | NO_COLLIDE)
		for x in TRUSSES:
			_local_box("steel", xf, Vector3(x, -0.36, (length - 0.6) * 0.5), Vector3(0.16, 0.2, length - 0.6), DETAIL | NO_COLLIDE)

	for x in TRUSSES:
		box("steel", Vector3(x, EAVES - 0.1, 0), Vector3(0.16, 0.2, HZ * 2.0), Vector3.ZERO, DETAIL | NO_COLLIDE)
		var posts: Array[float] = [-8.0, -4.0, 0.0, 4.0, 8.0]
		for j in posts.size():
			var z := posts[j]
			var top := _roof_underside(z)
			beam("steel", Vector3(x, EAVES, z), Vector3(x, top, z), 0.1, DETAIL | NO_COLLIDE)
			if j > 0:
				var prev := posts[j - 1]
				# Diagonals rise towards the ridge.
				if z <= 0.0:
					beam("steel", Vector3(x, EAVES, prev), Vector3(x, top, z), 0.08, DETAIL | NO_COLLIDE)
				else:
					beam("steel", Vector3(x, _roof_underside(prev), prev), Vector3(x, EAVES, z), 0.08, DETAIL | NO_COLLIDE)

	# Hanging lamps: only a few still work.
	var lit := {Vector2(-8, 5): true, Vector2(8, -5): true, Vector2(0, -5): false, Vector2(-16, -5): false}
	for x in BAYS:
		for z in [-5.0, 5.0]:
			var key := Vector2(x, z)
			lamp(Vector3(x, 6.0, z), _roof_underside(z) - 0.2, lit.has(key), lit.get(key, false))


func _roof_underside(z: float) -> float:
	return RIDGE - absf(z) * (RIDGE - EAVES) / (HZ + 0.5) - 0.3


func _mezzanine() -> void:
	var x0 := -HX
	var x1 := -2.0
	var z1 := -6.5
	box("deck", Vector3((x0 + x1) * 0.5, DECK_Y - 0.04, (-HZ + z1) * 0.5), Vector3(x1 - x0, 0.08, z1 + HZ))
	for z in [z1 - 0.1, -9.25, -HZ + 0.1]:
		box("steel", Vector3((x0 + x1) * 0.5, DECK_Y - 0.23, z), Vector3(x1 - x0, 0.3, 0.16), Vector3.ZERO, NO_COLLIDE)
	for x in [-18.0, -14.0, -10.0, -6.0, -2.1]:
		box("steel", Vector3(x, (DECK_Y - 0.38) * 0.5, z1 - 0.1), Vector3(0.2, DECK_Y - 0.38, 0.2))
		box("steel", Vector3(x, DECK_Y - 0.2, (-HZ + z1) * 0.5), Vector3(0.1, 0.24, z1 + HZ), Vector3.ZERO, DETAIL | NO_COLLIDE)
	railing(Vector3(x0, DECK_Y, z1 - 0.05), Vector3(x1, DECK_Y, z1 - 0.05))
	railing(Vector3(x1 - 0.05, DECK_Y, z1), Vector3(x1 - 0.05, DECK_Y, -9.8))

	# Stairs down along the north wall; a ramp collider keeps movement smooth.
	# They are wide enough to leave the navmesh a walkable strip between the
	# wall and the railing.
	var steps := 16
	var rise := DECK_Y / steps
	var run := 0.3
	for i in range(1, steps):
		var y := DECK_Y - rise * i
		box("deck", Vector3(x1 + run * (i - 0.5), y - 0.02, -10.9), Vector3(run, 0.04, 2.2), Vector3.ZERO, NO_COLLIDE)
	var foot := Vector3(x1 + run * steps, 0.0, 0.0)
	for z in [-9.82, -11.96]:
		beam("steel", Vector3(x1, DECK_Y - 0.14, z), Vector3(foot.x, -0.14, z), 0.07, NO_COLLIDE, 0.25)
	var slope := Vector3(foot.x - x1, -DECK_Y, 0.0)
	var ramp := Transform3D(Basis(Vector3.BACK, atan2(slope.y, slope.x)), Vector3(x1, DECK_Y, -10.9) + slope * 0.5)
	_collide_box(ramp * Transform3D(Basis(), Vector3(0, -0.1, 0)), Vector3(slope.length(), 0.2, 2.2))
	railing(Vector3(x1, DECK_Y, -9.82), Vector3(foot.x, 0.0, -9.82))

	# Storage underneath.
	shelf(Vector3(-17.5, 0, -11.4), 0, false)
	shelf(Vector3(-13.5, 0, -11.4), 0, true)
	shelf(Vector3(-9.5, 0, -11.4), 0, true)
	crates(Vector3(-16.5, 0, -8.6), 4)
	crates(Vector3(-6.0, 0, -10.6), 3)
	bulb(Vector3(-15.0, DECK_Y - 0.5, -9.2), true)
	bulb(Vector3(-7.0, DECK_Y - 0.5, -9.2), false)
	# And a few things on top.
	crates(Vector3(-17.0, DECK_Y, -10.0), 3)
	box("machine", Vector3(-11.0, DECK_Y + 0.95, -11.6), Vector3(3.0, 1.9, 0.6))


func _crane() -> void:
	var rail_y := 6.4
	for z in [-HZ + 0.6, HZ - 0.6]:
		box("steel", Vector3(0, rail_y, z), Vector3(HX * 2.0, 0.3, 0.25), Vector3.ZERO, DETAIL | NO_COLLIDE)
	var x := 6.0
	for dx in [-0.6, 0.6]:
		box("steel_yellow", Vector3(x + dx, rail_y + 0.55, 0), Vector3(0.35, 0.8, HZ * 2.0 - 0.9), Vector3.ZERO, DETAIL | NO_COLLIDE)
	for z in [-HZ + 0.6, HZ - 0.6]:
		box("steel_yellow", Vector3(x, rail_y + 0.4, z), Vector3(2.2, 0.5, 0.4), Vector3.ZERO, DETAIL | NO_COLLIDE)
	var trolley := Vector3(x, rail_y + 1.05, 3.0)
	box("machine", trolley, Vector3(1.5, 0.5, 1.2), Vector3.ZERO, DETAIL | NO_COLLIDE)
	for dz in [-0.12, 0.12]:
		beam("steel", trolley + Vector3(0, 0, dz), Vector3(x, 3.9, 3.0 + dz), 0.02, DETAIL | NO_COLLIDE)
	box("steel_yellow", Vector3(x, 3.65, 3.0), Vector3(0.35, 0.5, 0.45), Vector3.ZERO, DETAIL)
	box("steel", Vector3(x, 3.3, 3.0), Vector3(0.08, 0.3, 0.08), Vector3.ZERO, DETAIL | NO_COLLIDE)


func _hall_props() -> void:
	_press(Vector3(-6.0, 0, 3.5))
	_lathe(Vector3(2.0, 0, 7.8))
	_workbench(Vector3(0.6, 0, HZ - 0.37))

	cabinets(Vector3(-12.05, 0, 3.0), 0)

	# Tanks and pipework against the north wall.
	for x in [11.5, 15.0]:
		cylinder("pipe", Vector3(x, 0.0, -9.6), 1.25, 4.6, 0, Vector3.ZERO, -1.0, 28)
		cylinder("concrete", Vector3(x, 0.0, -9.6), 1.4, 0.25)
		cylinder("steel", Vector3(x, 4.6, -9.6), 0.14, 0.9, NO_COLLIDE)
		cylinder("steel", Vector3(x, 5.36, -9.6), 0.14, 2.3, NO_COLLIDE, Vector3(-90, 0, 0))
	cylinder("steel", Vector3(-1.0, 5.36, -11.75), 0.14, 21.0, NO_COLLIDE, Vector3(0, 0, -90))
	cylinder("pipe", Vector3(-1.0, 4.9, -11.8), 0.08, 21.0, NO_COLLIDE, Vector3(0, 0, -90))
	for x in [0.0, 4.0, 8.0, 18.0]:
		box("steel", Vector3(x, 5.1, -11.85), Vector3(0.06, 0.7, 0.3), Vector3.ZERO, DETAIL | NO_COLLIDE)

	# Containers.
	container("pipe", Vector3(-11.5, 0, 9.6), true)
	container("machine", Vector3(9.5, 0, -2.5), false)

	# Concrete road barriers.
	barrier(Vector3(-2.0, 0, -1.5), 12)
	barrier(Vector3(13.5, 0, 2.3), 80)
	barrier(Vector3(-15.5, 0, -1.0), -30)

	crates(Vector3(3.5, 0, -4.5), 5)
	crates(Vector3(-9.5, 0, -2.5), 4)
	crates(Vector3(16.5, 0, 9.5), 5)
	crates(Vector3(-17.5, 0, 6.0), 4)
	crates(Vector3(5.0, 0, 2.0), 2)
	pallet(Vector3(12.5, 0, 9.0), 20.0, 3)
	pallet(Vector3(-3.0, 0, 10.5), -8.0, 5)
	bags(Vector3(17.5, 0, -3.5), 4.0, 5)
	for p in [Vector3(18.6, 0, -5.4), Vector3(17.9, 0, -5.9), Vector3(18.8, 0, -6.3), Vector3(-19.2, 0, 3.6), Vector3(-19.1, 0, 4.4)]:
		barrel(p)

	# What the last shift left standing around.
	place("old_military_compressor", Vector3(13.2, 0, -7.6), 90)
	place("portable_welding_cart", Vector3(-8.4, 0, 4.3), 25)
	place("tool_cart", Vector3(3.0, 0, 6.3), 5)
	place("industrial_storage_cart", Vector3(-9.3, 0, 3.3), 90)
	place("wooden_ladder", Vector3(6.3, 0, 8.4), -70, true)
	place("hand_truck", Vector3(14.6, 0, 10.9), 160, true)
	tyres(Vector3(19.3, 0, -6.9), 4)
	tyres(Vector3(18.6, 0, -7.3), 2)
	tyres(Vector3(-7.8, 0, 11.1), 3)
	for p in [Vector3(17.0, 0, -11.2), Vector3(17.45, 0, -11.25), Vector3(17.2, 0, -10.8)]:
		gas_bottle(p)


## Eccentric press with an open front: the bed below, the slide and its drive
## in the head that reaches out over it, the flywheel on the east side. `at` is
## the middle of its foot; the operator stands on the north side.
func _press(at: Vector3) -> void:
	_m = Transform3D(Basis(), at)
	_collide_box(_m * Transform3D(Basis(), Vector3(0, 0.54, 0)), Vector3(3.1, 1.08, 2.2))
	_collide_box(_m * Transform3D(Basis(), Vector3(0, 2.4, 0.45)), Vector3(2.42, 2.7, 1.1))
	_collide_box(_m * Transform3D(Basis(), Vector3(0, 2.75, -0.5)), Vector3(2.5, 2.0, 0.8))

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
	var tank := Vector3(-0.7, 3.75, 0.5)
	_block(IRON, tank + Vector3(0, 0.03, 0), Vector3(0.5, 0.06, 0.5), 0.01)
	_turned(YELLOW, tank + Vector3(0, 0.04, 0), Vector3.UP, PackedVector2Array([
		Vector2(0, 0), Vector2(0.2, 0.015), Vector2(0.29, 0.07), Vector2(0.32, 0.16),
		Vector2(0.32, 0.76), Vector2(0.29, 0.85), Vector2(0.2, 0.905), Vector2(0, 0.92),
	]), 24, true)
	_bar(BARE, tank + Vector3(0, 0.94, 0), tank + Vector3(0, 1.04, 0), 0.03)
	_turned(BRASS, tank + Vector3(0, 0.6, -0.32), Vector3.FORWARD, PackedVector2Array([Vector2(0.055, 0), Vector2(0.055, 0.03), Vector2(0, 0.03)]), 16)
	_line(IRON, [tank + Vector3(0, 1.0, 0), tank + Vector3(-0.25, 1.06, -0.1), tank + Vector3(-0.72, 0.5, -0.45), shaft + Vector3(-1.4, 0.36, 0)], 0.018)

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
	_collide_box(_m * Transform3D(Basis(), lube + Vector3(0, 0.4, 0)), Vector3(0.9, 0.8, 0.4))
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
func _lathe(at: Vector3) -> void:
	_m = Transform3D(Basis(), at)
	_collide_box(_m * Transform3D(Basis(), Vector3(0, 0.56, 0)), Vector3(6.0, 1.12, 1.4))
	_collide_box(_m * Transform3D(Basis(), Vector3(-2.25, 1.6, 0)), Vector3(1.6, 1.04, 1.1))
	_collide_box(_m * Transform3D(Basis(), Vector3(2.45, 1.4, 0)), Vector3(0.7, 0.56, 0.66))
	_collide_box(_m * Transform3D(Basis(), Vector3(0.45, 1.42, 0)), Vector3(3.3, 0.6, 0.5))
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
	_collide_box(_m * Transform3D(Basis(), coolant + Vector3(0, 0.3, 0)), Vector3(0.7, 0.6, 0.5))
	_block(BLUE, coolant + Vector3(0, 0.15, 0), Vector3(0.7, 0.3, 0.5), 0.02)
	_motor(IRON, coolant + Vector3(0, 0.3, 0.12), Vector3.UP, 0.07, 0.24, false)
	_line(RUBBER, [coolant + Vector3(0.1, 0.33, 0.12), coolant + Vector3(0.1, 0.9, 0), Vector3(1.15, 1.85, 0.5), Vector3(0.9, 1.8, 0.2), saddle + Vector3(0.02, 0.5, -0.08)], 0.012)
	wall_decal("leak_1", _m * Vector3(-1.9, 0.5, -0.64), Vector3.FORWARD, 0.8, 0.9)
	wall_decal("leak_2", _m * Vector3(0.9, 0.75, -0.4), Vector3.FORWARD, 1.2, 0.7)


## Workbenches against the south wall with what a fitter needs; `at` is the
## middle of the two benches.
func _workbench(at: Vector3) -> void:
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
	mount("power_box_01", Vector3(at.x + 2.3, 1.75, HZ), 180)
	# A fluorescent tube on brackets, so the bench is not lost in the shade
	# under the windows.
	var fixture := Vector3(at.x, 2.5, HZ - 0.3)
	tube(fixture, true, true, true, 5.0)
	for x in [-0.5, 0.5]:
		box("steel", fixture + Vector3(x, 0.04, 0.19), Vector3(0.04, 0.04, 0.22), Vector3.ZERO, NO_COLLIDE)


func _annex() -> void:
	var x0 := HX + 0.5
	var x1 := 30.5
	var z0 := -HZ
	var z1 := 2.0
	var height := 3.4
	wall("plaster", true, z0 - 0.2, 0.4, x0, x1 + 0.4, 0.0, height, [])
	wall("plaster", false, x1 + 0.2, 0.4, z0, z1, 0.0, height, [])
	wall("plaster", true, z1 + 0.2, 0.4, x0, x1 + 0.4, 0.0, height, [[25.5, 29.0, 1.1, 2.6]])
	_mullions(Vector3(27.25, 1.85, z1 + 0.2), 3.5, 1.5, true, 0.875)
	box("concrete", Vector3(27.25, 1.06, z1 + 0.1), Vector3(3.7, 0.08, 0.6))
	box("concrete", Vector3((x0 + x1 + 0.4) * 0.5, height + 0.15, (z0 + z1) * 0.5), Vector3(x1 + 0.4 - x0, 0.3, z1 - z0 + 0.8))
	# The hall side of the annex is brick; give it a plaster lining.
	wall("plaster", false, x0 + 0.03, 0.06, z0, z1, 0.0, height, [[-10.0, -8.0, 0.0, 2.6], [-3.0, 0.0, 0.0, 3.0]])
	# Corridor partition and the wall between the two rooms.
	wall("plaster", false, 23.6, 0.2, z0, z1, 0.0, height, [[-9.8, -8.2, 0.0, 2.2], [-2.8, -1.2, 0.0, 2.2]])
	wall("plaster", true, -5.2, 0.2, 23.7, x1, 0.0, height, [])

	for z in [-10.0, -5.0, 0.0]:
		tube(Vector3(22.0, height - 0.08, z), false, z != -5.0)
	tube(Vector3(27.0, height - 0.08, -8.6), true, true)
	tube(Vector3(27.0, height - 0.08, -1.6), true, false)

	# Corridor: pipes under the ceiling and a few barrels.
	cylinder("pipe", Vector3(20.9, 3.0, z0), 0.09, z1 - z0, NO_COLLIDE, Vector3(90, 0, 0))
	cylinder("steel", Vector3(21.15, 3.1, z0), 0.05, z1 - z0, NO_COLLIDE, Vector3(90, 0, 0))
	barrel(Vector3(23.1, 0, -11.4))
	barrel(Vector3(22.4, 0, -11.5))
	box("machine", Vector3(23.3, 0.9, -5.5), Vector3(0.35, 1.8, 1.2))

	# Room A: storage.
	shelf(Vector3(27.0, 0, -11.6), 0, true)
	shelf(Vector3(30.1, 0, -8.5), -90, false)
	crates(Vector3(25.5, 0, -6.6), 4)
	pallet(Vector3(28.6, 0, -6.4), 10.0, 2)

	# Room B: lockers, desk and the window.
	for i in 5:
		box("machine", Vector3(30.2, 0.95, -4.6 + i * 0.52), Vector3(0.5, 1.9, 0.5))
	place(DESK, Vector3(27.2, 0, 1.45), 180)
	crates(Vector3(24.6, 0, -4.2), 2)


func _exterior() -> void:
	box("floor", Vector3(5, -0.55, 0), Vector3(160, 1.0, 160), Vector3.ZERO, DETAIL)
	# Yard wall and a skyline so the windows do not look out on nothing.
	box("brick", Vector3(5, 1.6, 34), Vector3(110, 3.2, 0.5), Vector3.ZERO, DETAIL)
	box("brick", Vector3(-50, 1.6, 0), Vector3(0.5, 3.2, 68), Vector3.ZERO, DETAIL)
	box("brick", Vector3(60, 1.6, 0), Vector3(0.5, 3.2, 68), Vector3.ZERO, DETAIL)
	box("brick", Vector3(5, 1.6, -34), Vector3(110, 3.2, 0.5), Vector3.ZERO, DETAIL)
	box("brick", Vector3(34, 5, 52), Vector3(26, 10, 16), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("roof", Vector3(-30, 4, 56), Vector3(30, 8, 18), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("concrete", Vector3(52, 7, 14), Vector3(14, 14, 20), Vector3.ZERO, DETAIL | NO_COLLIDE)
	cylinder("brick", Vector3(42, 0, 50), 2.2, 38.0, DETAIL | NO_COLLIDE, Vector3.ZERO, 1.4, 20)
	container("pipe", Vector3(38, 0, 9), false, DETAIL)


func _probes() -> void:
	probe("Hall", Vector3(0, 4.6, 0), Vector3(HX * 2.0, 9.4, HZ * 2.0), Vector3(2.0, -2.2, 1.0))
	probe("Corridor", Vector3(22.0, 1.7, -5.0), Vector3(3.0, 3.4, 14.0), Vector3.ZERO)
	probe("RoomA", Vector3(27.1, 1.7, -8.65), Vector3(6.8, 3.4, 6.7), Vector3(0, 0, 0.8))
	probe("RoomB", Vector3(27.1, 1.7, -1.55), Vector3(6.8, 3.4, 7.1), Vector3.ZERO)


func _dirt() -> void:
	# Rain has run down the walls below every window.
	for x in BAYS:
		wall_decal(_pick("leak"), Vector3(x + _decal_rng.randf_range(-1.8, 1.8), 1.5, HZ - 0.04), Vector3.FORWARD, 1.6, 2.9)
		wall_decal(_pick("leak"), Vector3(x + _decal_rng.randf_range(-1.8, 1.8), 1.7, HZ - 0.04), Vector3.FORWARD, 1.1, 2.4)
		wall_decal(_pick("leak"), Vector3(x + _decal_rng.randf_range(-1.0, 1.0), 3.6, -HZ + 0.04), Vector3.BACK, 1.5, 3.4)
	wall_decal(_pick("leak"), Vector3(HX - 0.04, 1.5, 7.5), Vector3.LEFT, 1.6, 2.9)
	wall_decal(_pick("leak"), Vector3(-HX + 0.04, 5.2, -6.0), Vector3.RIGHT, 2.0, 5.0)
	wall_decal(_pick("leak"), Vector3(-HX + 0.04, 5.0, 7.0), Vector3.RIGHT, 1.8, 5.5)
	# Grime where the walls meet the floor.
	for x in [-15.0, -5.0, 5.0, 15.0]:
		wall_decal("grime", Vector3(x, 0.7, HZ - 0.1), Vector3.FORWARD, 10.0, 1.4)
		wall_decal("grime", Vector3(x, 0.7, -HZ + 0.1), Vector3.BACK, 10.0, 1.4)
	for z in [-6.0, 6.0]:
		wall_decal("grime", Vector3(-HX + 0.1, 0.7, z), Vector3.RIGHT, 12.0, 1.4)
		wall_decal("grime", Vector3(HX - 0.1, 0.7, z), Vector3.LEFT, 12.0, 1.4)
	# Oil under the machines and tracks worn into the main lanes.
	floor_decal("stain_1", Vector3(-6.0, 0, 2.0), Vector2(4.5, 4.5), 20)
	floor_decal("stain_2", Vector3(2.5, 0, 6.6), Vector2(6.0, 3.0), 5)
	floor_decal("stain_2", Vector3(-12.2, 0, 3.8), Vector2(3.0, 2.2), 80)
	floor_decal("stain_1", Vector3(13.2, 0, -8.0), Vector2(5.0, 4.0), 140)
	floor_decal("stain_1", Vector3(18.3, 0, -5.8), Vector2(2.4, 2.4), 60)
	floor_decal("stain_2", Vector3(-18.0, 0, 0.5), Vector2(3.5, 5.0), 10)
	for i in 8:
		var at := Vector3(_decal_rng.randf_range(-17.0, 17.0), 0, _decal_rng.randf_range(-5.0, 10.0))
		var size := _decal_rng.randf_range(1.5, 3.5)
		floor_decal(_pick("stain"), at, Vector2(size, size * _decal_rng.randf_range(0.7, 1.3)), _decal_rng.randf_range(0, 360))
	# The annex has seen better days too.
	wall_decal(_pick("leak"), Vector3(20.56, 2.0, -6.0), Vector3.RIGHT, 1.4, 2.8, Color(1, 1, 1, 0.8))
	wall_decal(_pick("leak"), Vector3(23.48, 2.1, -4.0), Vector3.LEFT, 1.2, 2.6, Color(1, 1, 1, 0.8))
	wall_decal(_pick("leak"), Vector3(27.0, 2.0, -11.98), Vector3.BACK, 1.6, 2.8, Color(1, 1, 1, 0.8))
	wall_decal(_pick("leak"), Vector3(30.48, 2.0, 0.6), Vector3.LEFT, 1.4, 2.8, Color(1, 1, 1, 0.8))
	wall_decal("grime", Vector3(20.6, 0.5, -5.0), Vector3.RIGHT, 13.0, 1.0)
	wall_decal("grime", Vector3(23.46, 0.5, -5.0), Vector3.LEFT, 13.0, 1.0)
	floor_decal("stain_2", Vector3(22.0, 0, -8.5), Vector2(2.2, 3.5))
	floor_decal("stain_1", Vector3(27.5, 0, -8.0), Vector2(3.0, 3.0), 45)


# --- Machine parts, all in the frame of the machine being built ---------------


## Cast or machined block with rounded edges.
func _block(mat: String, center: Vector3, size: Vector3, radius := 0.02, rot_deg := Vector3.ZERO) -> void:
	rounded_box(mat, _m * Transform3D(Basis.from_euler(rot_deg * PI / 180.0), center), size, radius, NO_COLLIDE)


func _bar(mat: String, from: Vector3, to: Vector3, radius: float, segments := 12) -> void:
	rod(mat, _m * from, _m * to, radius, NO_COLLIDE, segments)


## Turned part: `profile` revolved around the line that leaves `from` along `axis`.
func _turned(mat: String, from: Vector3, axis: Vector3, profile: PackedVector2Array, segments := 24, smooth := false) -> void:
	revolve(mat, _m * Transform3D(_up_along(axis), from), profile, NO_COLLIDE, segments, smooth)


## Pipe, conduit or cable.
func _line(mat: String, points: Array, radius: float) -> void:
	hose(mat, _m * PackedVector3Array(points), radius, NO_COLLIDE)


## Hexagonal bolt head sitting on `at`.
func _bolt(at: Vector3, out: Vector3, size := 0.022) -> void:
	_bar(IRON, at, at + out * size * 0.7, size, 6)


func _bolt_circle(center: Vector3, out: Vector3, radius: float, count: int) -> void:
	var plane := _up_along(out)
	for i in count:
		var angle := TAU * i / count
		_bolt(center + (plane.x * cos(angle) + plane.z * sin(angle)) * radius, out)


func _ring(mat: String, center: Vector3, axis: Vector3, radius: float, thickness: float) -> void:
	var profile := PackedVector2Array()
	for i in 9:
		var angle := TAU * i / 8
		profile.append(Vector2(radius + cos(angle) * thickness, sin(angle) * thickness))
	_turned(mat, center, axis, profile, 20, true)


func _ball(mat: String, center: Vector3, radius: float) -> void:
	var profile := PackedVector2Array()
	for i in 7:
		var angle := PI * (i / 6.0 - 0.5)
		profile.append(Vector2(cos(angle), sin(angle)) * radius)
	_turned(mat, center, Vector3.UP, profile, 12, true)


## Handwheel with three spokes and a crank handle; `center` is the middle of
## the rim and `axis` points at whoever turns it.
func _handwheel(center: Vector3, axis: Vector3, radius: float) -> void:
	var plane := _up_along(axis)
	var thickness := radius * 0.11
	_ring(BARE, center, axis, radius, thickness)
	_bar(BARE, center - plane.y * thickness * 2.0, center + plane.y * thickness * 1.2, radius * 0.22)
	for i in 3:
		var angle := TAU * i / 3.0
		_bar(BARE, center, center + (plane.x * cos(angle) + plane.z * sin(angle)) * radius, thickness * 0.7, 8)
	var grip := center + plane.x * radius
	_bar(RUBBER, grip, grip + plane.y * radius * 0.7, thickness * 1.1, 8)


## Lever with a ball knob on a boss; `at` lies on the surface it sits on,
## `out` is the normal of that surface and `toward` the way the lever points.
func _lever(at: Vector3, out: Vector3, toward: Vector3, length: float) -> void:
	_turned(IRON, at, out, PackedVector2Array([Vector2(0.04, 0), Vector2(0.04, 0.025), Vector2(0, 0.03)]), 12)
	var tip := at + out * 0.03 + toward.normalized() * length
	_bar(BARE, at + out * 0.02, tip, 0.009, 8)
	_ball(RUBBER, tip, 0.024)


## Spoked flywheel on a shaft along X; the face of its rim is worn bright by the belt.
func _flywheel(center: Vector3, radius: float, width: float) -> void:
	var inner := radius * 0.84
	var hub := radius * 0.2
	var half := width * 0.5
	var edge := 0.015
	_turned(GREEN, center, Vector3.RIGHT, PackedVector2Array([
		Vector2(radius - edge, half), Vector2(inner, half), Vector2(inner, -half), Vector2(radius - edge, -half),
	]), 40)
	_turned(BARE, center, Vector3.RIGHT, PackedVector2Array([
		Vector2(radius - edge, -half), Vector2(radius, -half + edge), Vector2(radius, half - edge), Vector2(radius - edge, half),
	]), 40)
	_turned(GREEN, center - Vector3(width * 0.7, 0, 0), Vector3.RIGHT, PackedVector2Array([
		Vector2(0, 0), Vector2(hub, 0), Vector2(hub, width * 1.4), Vector2(0, width * 1.4),
	]))
	for i in 6:
		var turn := 60.0 * i + 15.0
		var out := Basis(Vector3.RIGHT, deg_to_rad(turn)) * Vector3.UP
		_block(GREEN, center + out * (hub + inner) * 0.5, Vector3(width * 0.45, inner - hub + 0.04, 0.11), 0.02, Vector3(turn, 0, 0))


## Electric motor with cooling fins. It starts at `start` and runs along
## `axis`, with the shaft at the far end; one that lies down stands on `feet`.
func _motor(mat: String, start: Vector3, axis: Vector3, radius: float, length: float, feet := true) -> void:
	var end := radius * 0.5
	_turned(mat, start, axis, PackedVector2Array([
		Vector2(0, 0), Vector2(radius * 0.55, end * 0.1), Vector2(radius * 0.92, end * 0.5), Vector2(radius, end),
		Vector2(radius, length - end), Vector2(radius * 0.92, length - end * 0.5), Vector2(radius * 0.55, length - end * 0.1), Vector2(0, length),
	]), 24, true)
	var fins := int((length - end * 2.4) / 0.035)
	for i in fins:
		var along := end * 1.2 + (length - end * 2.4) * (i + 0.5) / fins
		_bar(mat, start + axis * (along - 0.006), start + axis * (along + 0.006), radius * 1.09, 20)
	_bar(BARE, start + axis * (length - 0.02), start + axis * (length + radius * 0.5), radius * 0.16)
	# The terminal box sits on top of a motor that lies down.
	var plane := _up_along(axis)
	var middle := start + axis * length * 0.5
	rounded_box(mat, _m * Transform3D(plane, middle - plane.z * (radius + 0.03)), Vector3(radius * 0.6, radius * 0.7, 0.08), 0.015, NO_COLLIDE)
	if feet:
		rounded_box(mat, _m * Transform3D(plane, middle + plane.z * (radius + 0.01)), Vector3(radius * 1.8, length * 0.6, 0.04), 0.008, NO_COLLIDE)


## Sheet-metal door with ventilation slots; `at` is its middle on the surface
## it closes and `out` the normal of that surface.
func _louvred_door(mat: String, at: Vector3, out: Vector3, size: Vector2) -> void:
	var across := Vector3.UP.cross(out)
	var plate := Vector3(size.x, size.y, 0.03)
	var slot := Vector3(size.x * 0.65, 0.025, 0.012)
	if absf(out.x) > 0.5:
		plate = Vector3(0.03, size.y, size.x)
		slot = Vector3(0.012, 0.025, size.x * 0.65)
	_block(mat, at + out * 0.005, plate, 0.012)
	for i in 5:
		_block(IRON, at + out * 0.022 + Vector3(0, (i - 2) * 0.06 - size.y * 0.12, 0), slot, 0.004)
	_bar(IRON, at + out * 0.02 + across * size.x * 0.4 + Vector3(0, 0.12, 0), at + out * 0.05 + across * size.x * 0.4 + Vector3(0, 0.12, 0), 0.018, 8)
