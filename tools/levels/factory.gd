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
	# Press.
	box("machine", Vector3(-6.0, 0.5, 3.5), Vector3(3.2, 1.0, 2.2))
	box("machine", Vector3(-6.0, 2.3, 3.9), Vector3(2.4, 2.6, 1.2))
	box("steel", Vector3(-6.0, 1.15, 3.1), Vector3(1.6, 0.3, 1.0))
	cylinder("steel", Vector3(-6.0, 1.3, 3.1), 0.22, 1.2)
	cylinder("pipe", Vector3(-6.9, 3.6, 3.9), 0.35, 0.9)

	# Long machine bed.
	box("machine", Vector3(2.0, 0.55, 7.8), Vector3(6.0, 1.1, 1.5))
	box("machine", Vector3(-0.2, 1.6, 7.9), Vector3(1.4, 1.0, 1.2))
	box("steel", Vector3(2.6, 1.16, 7.8), Vector3(4.0, 0.12, 0.9))
	cylinder("steel", Vector3(0.5, 1.55, 7.8), 0.3, 3.2, 0, Vector3(0, 0, -90))
	box("machine", Vector3(4.6, 1.5, 7.8), Vector3(0.6, 0.8, 0.9))

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
