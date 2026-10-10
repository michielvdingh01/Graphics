extends "res://tools/levels/factory/plan.gd"
## The hall of the factory: brick walls with tall windows to the south, a
## roof on steel trusses with skylights, the crane, a mezzanine along the
## north wall, and the machines. The loading door in the west wall is the way
## out of the level.


func _describe() -> void:
	_shell()
	_roof()
	_mezzanine()
	# Parked east of the lathe, with its hook block hanging over the aisle.
	crane(Vector3.ZERO, HX, HZ, 6.3, 6.0)
	_furnish()
	_probes()
	_dirt()
	_floor_paint()


## Out of the corridor of the annex, the length of the hall and out by the
## loading door in the west wall.
func _route_through() -> void:
	route_zone("hall", "the hall", AABB(Vector3(0.0, 0, -HZ), Vector3(HX, EAVES, HZ * 2.0)), [
		["grunt", Vector3(7.0, 0, -1.5)], ["grunt", Vector3(3.6, 0, 10.0)], ["grunt", Vector3(1.5, 0, -6.5)], ["rusher", Vector3(5.6, 0, -8.6)],
	])
	route_checkpoint("hall", "Hall", Vector3(2.5, 0, 0.0), Vector3(-5.0, 0, 0.0), AABB(Vector3(0.0, 0, -HZ), Vector3(4.0, 4.0, HZ * 2.0)))
	# The last of them hold the way out: one on the deck, one in front of the door.
	route_zone("loading_bay", "the loading bay", AABB(Vector3(-HX, 0, -HZ), Vector3(HX, EAVES, HZ * 2.0)), [
		["grunt", Vector3(-10.3, 0, 6.2)], ["grunt", Vector3(-16.3, 0, 10.2)], ["grunt", Vector3(-15.0, DECK_Y, -8.2)],
		["rusher", Vector3(-13.5, 0, -9.0)], ["rusher", Vector3(-17.2, 0, -10.2)], ["heavy", Vector3(-17.5, 0, 0.5)],
	])
	# Out is out: the level ends a step beyond the door, in the yard.
	route_exit("Leave by the loading door", AABB(Vector3(-HX - 4.5, -0.3, -4.0), Vector3(3.0, 4.5, 8.0)), "depot", Vector3(-HX, 5.6, 0.0), Vector3.RIGHT)


func _shell() -> void:
	box("floor", Vector3(-0.25, -0.25, -0.1), Vector3(41.5, 0.5, 25.8))
	dust(AABB(Vector3(-HX, 0.2, -HZ), Vector3(HX * 2.0, 8.0, HZ * 2.0)), 4000)

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

	# West wall with the loading door, which is the way out and stays shut
	# until the hall is cleared.
	wall("brick", false, -HX - 0.25, 0.5, -HZ, HZ, 0.0, EAVES, [[-2.5, 2.5, 0.0, 5.0]])
	roller_door(Vector3(-HX - 0.26, 2.29, 0.0), Vector3.RIGHT, Vector2(5.0, 4.58), true)
	for z in [-2.6, 2.6]:
		box("steel", Vector3(-HX - 0.05, 2.6, z), Vector3(0.2, 5.2, 0.2))
	box("steel", Vector3(-HX - 0.05, 5.1, 0.0), Vector3(0.2, 0.25, 5.4))

	# East wall: two doorways into the annex and windows above its roof.
	var east: Array = HALL_DOORWAYS + [[-9.5, -4.5, 5.2, 7.0], [4.5, 9.5, 3.0, 7.0]]
	wall("brick", false, HX + 0.25, 0.5, -HZ, HZ, 0.0, EAVES, east)
	_mullions(Vector3(HX + 0.25, 6.1, -7.0), 5.0, 1.8, false, 1.0)
	_mullions(Vector3(HX + 0.25, 5.0, 7.0), 5.0, 4.0, false, 1.0)
	box("concrete", Vector3(HX + 0.15, 2.94, 7.0), Vector3(0.7, 0.12, 5.3))
	box("steel", Vector3(HX + 0.25, 2.68, -9.0), Vector3(0.56, 0.16, 2.4))
	box("steel", Vector3(HX + 0.25, 3.08, -1.5), Vector3(0.56, 0.16, 3.4))
	_shut_hall_doorways(HX + 0.49)

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
			# Up between the trusses, where the crane passes underneath.
			lamp(Vector3(x, 8.3, z), _roof_underside(z) - 0.2, lit.has(key), lit.get(key, false))


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
	_collide_box(ramp * Transform3D(Basis(), Vector3(0, -0.1, 0)), Vector3(slope.length(), 0.2, 2.2), "metal")
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
	for x: float in [-12.0, -11.0, -10.0]:
		cupboard("machine", Vector3(x, DECK_Y, -11.6), 0, Vector3(0.98, 1.9, 0.6))


## The machines, the tanks and their pipework, and what stands about for
## cover.
func _furnish() -> void:
	press(Vector3(-6.0, 0, 3.5))
	lathe(Vector3(2.0, 0, 7.8))
	workbench(Vector3(0.6, 0, HZ - 0.37), HZ)

	cabinets(Vector3(-12.05, 0, 3.0), 0)

	# Tanks against the north wall, feeding the header that runs along it.
	tank(Vector3(11.5, 0, -9.6), 20, -55, HEADER_Z, -100)
	tank(Vector3(15.0, 0, -9.6), -10, 55, HEADER_Z)
	label("T1", Vector3(11.5, 3.0, -9.6) + Basis(Vector3.UP, deg_to_rad(20.0)) * Vector3(0, 0, 1.25), Basis(Vector3.UP, deg_to_rad(20.0)) * Vector3.BACK, 0.5, Color(0.06, 0.06, 0.06), 0.2)
	label("T2", Vector3(15.0, 3.0, -9.6) + Basis(Vector3.UP, deg_to_rad(-10.0)) * Vector3(0, 0, 1.25), Basis(Vector3.UP, deg_to_rad(-10.0)) * Vector3.BACK, 0.5, Color(0.06, 0.06, 0.06), 0.2)
	_m = Transform3D()
	var header := Vector3(0, 5.36, HEADER_Z)
	_bar(RUST, header + Vector3(-1.0, 0, 0), header + Vector3(HX, 0, 0), 0.14, 16)
	_bar(RUST, header + Vector3(-1.04, 0, 0), header + Vector3(-1.0, 0, 0), 0.25, 20)
	_bolt_circle(header + Vector3(-1.04, 0, 0), Vector3.LEFT, 0.2, 8)
	for x: float in [2.0, 6.0, 9.8, 13.25, 17.5]:
		_flange(RUST, header + Vector3(x, 0, 0), Vector3.RIGHT, 0.14)
	_bar("pipe", Vector3(-1.0, 4.9, -11.8), Vector3(HX, 4.9, -11.8), 0.08)
	for x: float in [0.0, 4.0, 8.0, 18.0]:
		box("steel", Vector3(x, 5.1, -11.85), Vector3(0.06, 0.7, 0.3), Vector3.ZERO, DETAIL | NO_COLLIDE)
		box("steel", Vector3(x, 5.2, -11.72), Vector3(0.06, 0.04, 0.4), Vector3.ZERO, DETAIL | NO_COLLIDE)
	# A gate valve in the header, its wheel within reach of nobody.
	var valve := header + Vector3(7.9, 0, 0)
	_flange(RUST, valve - Vector3(0.22, 0, 0), Vector3.RIGHT, 0.14)
	_flange(RUST, valve + Vector3(0.22, 0, 0), Vector3.RIGHT, 0.14)
	_block(IRON, valve, Vector3(0.36, 0.4, 0.36), 0.06)
	_turned(IRON, valve, Vector3.BACK, PackedVector2Array([
		Vector2(0.13, 0.17), Vector2(0.13, 0.3), Vector2(0.17, 0.3), Vector2(0.17, 0.33), Vector2(0.05, 0.33), Vector2(0.05, 0.52), Vector2(0, 0.52),
	]), 16)
	_bolt_circle(valve + Vector3(0, 0, 0.33), Vector3.BACK, 0.13, 6)
	_bar(BARE, valve + Vector3(0, 0, 0.5), valve + Vector3(0, 0, 0.66), 0.018)
	_handwheel(valve + Vector3(0, 0, 0.62), Vector3.BACK, 0.2)

	# Containers.
	container("container_red", Vector3(-11.5, 0, 9.6), true)
	container("container_green", Vector3(9.5, 0, -2.5), false)

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
	# Fuel, left where it was last needed: beside the lane the robots come
	# down, at the ends of the containers and up on the deck.
	for p in [
		Vector3(-4.3, 0, -2.9), Vector3(-3.6, 0, -3.15), Vector3(7.5, 0, -3.4), Vector3(-7.7, 0, 9.0),
		Vector3(-19.0, 0, 5.2), Vector3(18.6, 0, 10.6), Vector3(-14.2, DECK_Y, -11.3),
	]:
		fuel(p)


func _probes() -> void:
	probe("Hall", Vector3(0, 4.6, 0), Vector3(HX * 2.0, 9.4, HZ * 2.0), Vector3(2.0, -2.2, 1.0))


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


## Lines from when the hall was in use: an aisle from the loading door to the
## annex with a branch to the stairs, borders around the machines, bays along
## the south wall and hatching where nothing was to be put down. Arrows down
## the aisle point the way out, which is the way the route goes.
func _floor_paint() -> void:
	for x: float in [16.5, 12.6, 1.5, -5.5, -12.5]:
		floor_arrow(Vector2(x, 1.2 if x == 12.6 else 0.0), Vector2.LEFT)
	# The last of the way in from the boiler house: through the nearer doorway
	# to the aisle.
	floor_arrow(Vector2(17.4, -9.0), Vector2.LEFT)
	floor_arrow(Vector2(15.0, -5.6), Vector2(-0.6, 0.8))
	floor_line(Vector2(-16.2, 2.2), Vector2(19.95, 2.2))
	floor_line(Vector2(-16.2, -2.2), Vector2(3.3, -2.2))
	floor_line(Vector2(6.7, -2.2), Vector2(19.95, -2.2))
	for x: float in [3.3, 6.7]:
		floor_line(Vector2(x, -2.2), Vector2(x, -9.4))
	floor_hatch(Rect2(-19.7, -2.5, 3.5, 5.0))
	floor_frame(Rect2(-19.7, -2.5, 3.5, 5.0))
	floor_frame(Rect2(-8.4, 1.6, 5.2, 4.0), PAINT_YELLOW, 0.16, PAINT_BLACK)
	floor_frame(Rect2(-1.7, 5.9, 7.4, 3.6), PAINT_YELLOW, 0.16, PAINT_BLACK)
	floor_hatch(Rect2(-13.5, 3.5, 2.9, 1.3))
	floor_frame(Rect2(-13.5, 3.5, 2.9, 1.3))
	# Storage bays, open towards the aisle.
	for i in 5:
		var x := 10.4 + i * 2.35
		floor_line(Vector2(x, 8.3), Vector2(x, 11.85), PAINT_WHITE, 0.08)
	floor_line(Vector2(10.4, 11.85), Vector2(19.8, 11.85), PAINT_WHITE, 0.08)
	for i in 4:
		floor_text("A%d" % (i + 1), Vector2(11.575 + i * 2.35, 8.75), 0.45)
