extends "res://tools/level_builder.gd"
## The factory: the hall with its crane and mezzanine, an annex with a
## corridor and two rooms, and behind the annex the boiler house, reached
## through a passage with a bend in it. Build with: tools/build_level.sh factory

# Hall dimensions (interior faces).
const HX := 20.0
const HZ := 12.0
const EAVES := 8.0
const RIDGE := 10.6
const BAYS: Array[float] = [-16.0, -8.0, 0.0, 8.0, 16.0]
const TRUSSES: Array[float] = [-12.0, -4.0, 4.0, 12.0]
const DECK_Y := 3.2
## Where the pipe header runs along the north wall.
const HEADER_Z := -11.75
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
## Walls of the annex: plaster with a painted dado.
const WALL := "plaster_dado"
# The boiler house (interior faces) and the passage to it.
const BX0 := 29.4
const BX1 := 41.4
const BZ0 := -26.5
const BZ1 := -14.5
const BOILER_H := 7.0
const PASSAGE_H := 3.0
## Where the boiler stands.
const BOILER := Vector3(36.0, 0, -22.0)


func _level_name() -> String:
	return "factory"


func _describe() -> void:
	_detail_inside = AABB(Vector3(-HX - 0.5, 0, -HZ - 0.5), Vector3(HX * 2.0 + 12.0, RIDGE + 1.0, HZ * 2.0 + 1.0))
	# Four zones in a row. The hall and the annex look into each other through
	# two doorways; the passage has a bend in it, so that neither the annex and
	# the boiler house nor the passage and the hall are ever in sight of each
	# other. The selftest checks that with rays.
	zone("hall", [AABB(Vector3(-HX - 0.6, -1.0, -HZ - 0.6), Vector3(HX * 2.0 + 1.1, 13.0, HZ * 2.0 + 1.2))], ["annex"])
	zone("annex", [AABB(Vector3(HX + 0.5, -1.0, -HZ - 0.4), Vector3(10.45, 5.0, HZ + 2.85))], ["passage"])
	zone("passage", [
		AABB(Vector3(23.3, -1.0, -18.6), Vector3(2.8, 4.6, 6.2)), AABB(Vector3(26.1, -1.0, -18.6), Vector3(2.9, 4.6, 2.8)),
	], ["boiler"])
	zone("boiler", [AABB(Vector3(BX0 - 0.4, -1.0, BZ0 - 0.4), Vector3(BX1 - BX0 + 0.8, BOILER_H + 1.5, BZ1 - BZ0 + 0.8))])
	_shell()
	_roof()
	_mezzanine()
	_crane()
	_hall_props()
	_annex()
	_passage()
	_boiler_house()
	_clutter()
	# The yard and the skyline surround every zone and belong to none.
	in_zone("")
	_exterior()
	by_position()
	_probes()
	_dirt()
	_floor_paint()
	_route_through()


## In by the yard door of the boiler house, through the passage into the
## annex, down its corridor, the length of the hall and out by the loading
## door in the west wall.
func _route_through() -> void:
	route_start(Vector3(40.2, 0, -17.1), Vector3(30.0, 0, -17.1))
	# Two behind the boiler, and one that comes running out of the passage.
	route_zone("boiler", "the boiler house", AABB(Vector3(BX0, 0, BZ0), Vector3(9.2, BOILER_H, BZ1 - BZ0)), [
		["grunt", Vector3(36.2, 0, -25.2)], ["grunt", Vector3(33.6, 0, -25.2)], ["rusher", Vector3(24.7, 0, -14.4)],
	])
	route_checkpoint("passage", "Passage", Vector3(27.6, 0, -17.2), Vector3(24.0, 0, -17.2), AABB(Vector3(23.5, 0, -18.4), Vector3(5.5, PASSAGE_H, 6.0)))
	# Two come out of the locker room and one in from the hall.
	route_zone("annex", "the annex", AABB(Vector3(20.56, 0, -12.0), Vector3(9.94, 3.4, 6.7)), [
		["grunt", Vector3(27.5, 0, -2.6)], ["grunt", Vector3(25.8, 0, -0.6)], ["rusher", Vector3(18.6, 0, -1.2)],
	])
	route_checkpoint("corridor", "Corridor", Vector3(22.0, 0, -9.0), Vector3(19.0, 0, -9.0), AABB(Vector3(20.56, 0, -12.0), Vector3(2.94, 3.4, 14.0)))
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
	var east: Array = [[-10.0, -8.0, 0.0, 2.6], [-3.0, 0.0, 0.0, 3.0], [-9.5, -4.5, 5.2, 7.0], [4.5, 9.5, 3.0, 7.0]]
	wall("brick", false, HX + 0.25, 0.5, -HZ, HZ, 0.0, EAVES, east)
	_mullions(Vector3(HX + 0.25, 6.1, -7.0), 5.0, 1.8, false, 1.0)
	_mullions(Vector3(HX + 0.25, 5.0, 7.0), 5.0, 4.0, false, 1.0)
	box("concrete", Vector3(HX + 0.15, 2.94, 7.0), Vector3(0.7, 0.12, 5.3))
	box("steel", Vector3(HX + 0.25, 2.68, -9.0), Vector3(0.56, 0.16, 2.4))
	box("steel", Vector3(HX + 0.25, 3.08, -1.5), Vector3(0.56, 0.16, 3.4))
	# Each doorway is shut on both sides while a lightmap is baked, right where
	# the two zones meet: a strip of floor beyond the panel would lie in the sun.
	for x: float in [HX + 0.49, HX + 0.51]:
		bake_blocker(Vector3(x, 1.35, -9.0), Vector3(0.02, 2.7, 2.2))
		bake_blocker(Vector3(x, 1.55, -1.5), Vector3(0.02, 3.1, 3.2))

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


## Double-girder overhead crane on runway beams along both long walls, parked
## east of the lathe with its hook block hanging over the aisle.
func _crane() -> void:
	# All of it is too thin or hangs too high up for a patch of lightmap.
	_part = DETAIL | NO_COLLIDE
	var span := HZ - 0.6
	var seat := 6.3

	# Runway beams on the corbels, a rail on each.
	_m = Transform3D()
	for z: float in [-span, span]:
		_i_beam(RUST, Vector3(-HX, seat, z), Vector3(HX, seat, z), 0.25, 0.36)
		_plate(BARE, Vector3(0, seat + 0.38, z), Vector3(HX * 2.0, 0.04, 0.05))

	# Everything that travels is built from the top of the rails up.
	_m = Transform3D(Basis(), Vector3(6.0, seat + 0.4, 0))
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
	for sx: float in [-1.0, 1.0]:
		var x := sx * 0.75
		_plate(YELLOW, Vector3(x, 0.35, 0), Vector3(0.36, 0.56, reach * 2.0))
		for y: float in [0.06, 0.64]:
			_plate(YELLOW, Vector3(x, y, 0), Vector3(0.44, 0.02, reach * 2.0))
		_plate(BARE, Vector3(x, 0.665, 0), Vector3(0.045, 0.03, reach * 2.0))
		for i in 12:
			_plate(YELLOW, Vector3(x + sx * 0.2, 0.35, (i - 5.5) * 1.9), Vector3(0.04, 0.56, 0.012))
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
	var block := Vector3(0, 3.7 - _m.origin.y, at)
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
	for i in 12:
		_plate(IRON, Vector3(1.08, 0.7, (i - 5.5) * 1.9), Vector3(0.28, 0.03, 0.03))
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
	var pendant := Vector3(hang.x, 1.3 - _m.origin.y, hang.z)
	_plate(IRON, hang, Vector3(0.03, 0.08, 0.1))
	_line(RUBBER, [hang, hang.lerp(pendant, 0.5) + Vector3(0.02, 0, 0.03), pendant + Vector3(0, 0.15, 0)], 0.011)
	_block(YELLOW, pendant, Vector3(0.08, 0.34, 0.09), 0.02)
	var buttons: Array[String] = [RED, GREEN, RUBBER, RUBBER, RUBBER, RUBBER]
	for i in buttons.size():
		var button := pendant + Vector3(-0.04, 0.12 - i * 0.048, 0)
		_bar(buttons[i], button, button - Vector3(0.012, 0, 0), 0.015, 8)
	_part = NO_COLLIDE


func _hall_props() -> void:
	_press(Vector3(-6.0, 0, 3.5))
	_lathe(Vector3(2.0, 0, 7.8))
	_workbench(Vector3(0.6, 0, HZ - 0.37))

	cabinets(Vector3(-12.05, 0, 3.0), 0)

	# Tanks against the north wall, feeding the header that runs along it.
	_tank(Vector3(11.5, 0, -9.6), 20, -55, -100)
	_tank(Vector3(15.0, 0, -9.6), -10, 55)
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


## Storage tank of three welded courses under a dished head, on a concrete
## plinth. Seen from above, the manhole faces `yaw_deg` (0 looks along +Z) and
## the outlet and the caged ladder sit that many degrees round from it. The
## line from its head runs north to a header at `header_z`.
func _tank(at: Vector3, yaw_deg: float, outlet_deg: float, ladder_deg := NAN, header_z := HEADER_Z) -> void:
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
func _press(at: Vector3) -> void:
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
func _lathe(at: Vector3) -> void:
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
	# Whatever was in use when the last shift went home.
	var flat := Basis(Vector3.RIGHT, -PI * 0.5)
	drop("screwdrivers_02", top + Vector3(-0.08, 0, 0.14), 90)
	drop("adjustable_wrench", top + Vector3(0.6, 0, -0.12), 35, flat)
	drop("cross_pein_hammer", top + Vector3(0.62, 0, 0.12), 80, flat)
	drop("measuring_tape_01", top + Vector3(1.27, 0, -0.15), 10)
	drop("oil_tin", top + Vector3(-1.24, 0, -0.12), 200)
	place("metal_tool_chest", at + Vector3(-1.85, 0, 0.1), 180)
	drop("plastic_broom", at + Vector3(-2.75, 0, -0.2), 180)
	drop("sledgehammer_01", Vector3(at.x + 1.7, 0, HZ - 0.13), 0, Basis(Vector3.RIGHT, 0.17) * Basis(Vector3.BACK, PI))
	drop("crowbar_01", Vector3(at.x + 1.95, 0, HZ - 0.12), 0, Basis(Vector3.RIGHT, 0.2))
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
	box("floor", Vector3(25.7, -0.25, -5.0), Vector3(10.4, 0.5, 14.8))
	wall(WALL, true, z0 - 0.2, 0.4, x0, x1 + 0.4, 0.0, height, [[23.9, 25.5, 0.0, 2.2]])
	wall(WALL, false, x1 + 0.2, 0.4, z0, z1, 0.0, height, [])
	wall(WALL, true, z1 + 0.2, 0.4, x0, x1 + 0.4, 0.0, height, [[25.5, 29.0, 1.1, 2.6]])
	_mullions(Vector3(27.25, 1.85, z1 + 0.2), 3.5, 1.5, true, 0.875)
	box("concrete", Vector3(27.25, 1.06, z1 + 0.1), Vector3(3.7, 0.08, 0.6))
	box("concrete", Vector3((x0 + x1 + 0.4) * 0.5, height + 0.15, (z0 + z1) * 0.5), Vector3(x1 + 0.4 - x0, 0.3, z1 - z0 + 0.8))
	# The hall side of the annex is brick; give it a plaster lining.
	wall(WALL, false, x0 + 0.03, 0.06, z0, z1, 0.0, height, [[-10.0, -8.0, 0.0, 2.6], [-3.0, 0.0, 0.0, 3.0]])
	# Corridor partition and the wall between the two rooms.
	wall(WALL, false, 23.6, 0.2, z0, z1, 0.0, height, [[-9.8, -8.2, 0.0, 2.2], [-2.8, -1.2, 0.0, 2.2]])
	wall(WALL, true, -5.2, 0.2, 23.7, x1, 0.0, height, [])
	_door(-9.0, 95.0, 166.0, "1")
	_door(-2.0, 100.0, 168.0, "2")
	# The door to the passage, in the north wall of the storeroom: its leaves
	# stand open against the walls of the passage.
	_doorway(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(24.7, 0, z0 - 0.2)), 0.4, 97.0, 86.0)
	bake_blocker(Vector3(24.7, 1.15, z0 - 0.39), Vector3(1.8, 2.3, 0.02))
	_corridor_services(z0, z1, height)
	_notice_board(Vector3(x0 + 0.06, 1.62, -4.4))

	for z in [-10.0, -5.0, 0.0]:
		tube(Vector3(22.0, height - 0.08, z), false, z != -5.0)
	tube(Vector3(27.0, height - 0.08, -8.6), true, true)
	tube(Vector3(27.0, height - 0.08, -1.6), true, false)

	# Corridor: pipes under the ceiling and a few barrels.
	cylinder("pipe", Vector3(20.9, 3.0, z0), 0.09, z1 - z0, NO_COLLIDE, Vector3(90, 0, 0))
	cylinder("steel", Vector3(21.15, 3.1, z0), 0.05, z1 - z0, NO_COLLIDE, Vector3(90, 0, 0))
	barrel(Vector3(23.1, 0, -11.4))
	barrel(Vector3(22.4, 0, -11.5))
	cupboard("machine", Vector3(23.3, 0, -5.5), -90, Vector3(1.2, 1.8, 0.35))

	# Room A: storage.
	shelf(Vector3(27.0, 0, -11.6), 0, true)
	shelf(Vector3(30.1, 0, -8.5), -90, false)
	crates(Vector3(25.5, 0, -6.6), 4)
	pallet(Vector3(28.6, 0, -6.4), 10.0, 2)

	# Room B: lockers, desk and the window.
	lockers("machine_blue", Vector3(30.2, 0, -3.56), -90, 7, {2: 70.0, 5: 12.0})
	place(DESK, Vector3(27.2, 0, 1.45), 180)
	crates(Vector3(24.6, 0, -4.2), 2)


## Double steel doors in the partition between the corridor and a room, left
## standing open into the room. `z` is the middle of the doorway; the angles
## are how far the north leaf and the south leaf have swung. The plate on the
## corridor wall carries `number`.
func _door(z: float, north_deg: float, south_deg: float, number: String) -> void:
	_doorway(Transform3D(Basis(), Vector3(23.6, 0, z)), 0.2, north_deg, south_deg, number)


## Double steel doors in a doorway 1.6 m wide. `frame` stands on the floor in
## the middle of the wall, with the wall along its Z and its X pointing the
## way the leaves swing; `thick` is how thick the wall is. The angles are how
## far the leaf on the -Z side and the one on the +Z side have swung, 0 for
## shut. With a `number`, a plate beside the door on the other side carries it.
func _doorway(frame: Transform3D, thick: float, first_deg: float, second_deg: float, number := "") -> void:
	var half := 0.8
	var top := 2.2
	# A frame of folded steel lines the opening, a little proud of the wall.
	for side: float in [-1.0, 1.0]:
		_local_box("door", frame, Vector3(0, top * 0.5, side * (half - 0.025)), Vector3(thick + 0.06, top, 0.05), NO_COLLIDE)
	_local_box("door", frame, Vector3(0, top - 0.025, 0), Vector3(thick + 0.06, 0.05, half * 2.0 - 0.1), NO_COLLIDE)
	var leaf := 0.045
	for side: float in [-1.0, 1.0]:
		var swing := deg_to_rad(first_deg if side < 0.0 else second_deg)
		# From the hinge to the free edge: along the wall when the leaf is shut.
		var along := Vector3(sin(swing), 0.0, -side * cos(swing))
		# The hinges sit on the outside of the frame, so that an open leaf
		# stands clear of the doorway: the way through is no wider than the
		# robots need.
		var hinge := Vector3(thick * 0.5 + 0.03 + leaf * 0.5, 0.0, side * (half + leaf * 0.5 + 0.003))
		_leaf(frame * Transform3D(Basis(along, Vector3.UP, along.cross(Vector3.UP)), hinge), half - 0.055, leaf)
	if number == "":
		return
	var plate := Vector3(-thick * 0.5, 1.62, half + 0.24)
	_local_box("bare_steel", frame, plate - Vector3(0.002, 0, 0), Vector3(0.004, 0.13, 0.17), DETAIL | NO_COLLIDE)
	label(number, frame * (plate - Vector3(0.004, 0, 0)), frame.basis * Vector3.LEFT, 0.09, Color(0.04, 0.04, 0.04), 0.01)


## One leaf of a steel door. `leaf` has the foot of its hinge edge for origin,
## X towards the free edge and Z out of its face. It has a pane of glass at
## eye height, a kick plate and a lever handle on either side, and three
## hinges.
func _leaf(leaf: Transform3D, width: float, thick: float) -> void:
	var small := DETAIL | NO_COLLIDE
	var foot := 0.012
	var top := 2.16
	var pane := Vector3(width - 0.23, 1.56, 0.0)
	var glass := Vector2(0.2, 0.5)
	# The leaf is a frame around the pane: a rail below and one above it, and
	# a stile to either side.
	var sill := pane.y - glass.y * 0.5
	var head := pane.y + glass.y * 0.5
	var left := pane.x - glass.x * 0.5
	var right := pane.x + glass.x * 0.5
	_local_box("door", leaf, Vector3(width * 0.5, (foot + sill) * 0.5, 0), Vector3(width, sill - foot, thick), NO_COLLIDE)
	_local_box("door", leaf, Vector3(width * 0.5, (head + top) * 0.5, 0), Vector3(width, top - head, thick), NO_COLLIDE)
	_local_box("door", leaf, Vector3(left * 0.5, pane.y, 0), Vector3(left, glass.y, thick), NO_COLLIDE)
	_local_box("door", leaf, Vector3((right + width) * 0.5, pane.y, 0), Vector3(width - right, glass.y, thick), NO_COLLIDE)
	_local_box("glass", leaf, pane, Vector3(glass.x, glass.y, 0.008), GLASS | NO_COLLIDE)
	_collide_box(leaf * Transform3D(Basis(), Vector3(width * 0.5, (foot + top) * 0.5, 0)), Vector3(width, top - foot, thick), "metal")
	for face: float in [-1.0, 1.0]:
		var out := Vector3(0, 0, face * thick * 0.5)
		# The beading that holds the glass.
		for edge: float in [-1.0, 1.0]:
			_local_box("dark_steel", leaf, pane + out + Vector3(edge * (glass.x * 0.5 + 0.008), 0, 0), Vector3(0.016, glass.y + 0.032, 0.014), small)
			_local_box("dark_steel", leaf, pane + out + Vector3(0, edge * (glass.y * 0.5 + 0.008), 0), Vector3(glass.x, 0.016, 0.014), small)
		_local_box("bare_steel", leaf, Vector3(width * 0.5, 0.15, 0) + out, Vector3(width - 0.06, 0.22, 0.004), small)
		var grip := Vector3(width - 0.075, 1.05, 0) + out
		_local_box("bare_steel", leaf, grip, Vector3(0.045, 0.17, 0.008), small)
		var stem := grip + Vector3(0, 0.03, face * 0.05)
		rod("bare_steel", leaf * (grip + Vector3(0, 0.03, 0)), leaf * stem, 0.009, small, 8)
		rod("bare_steel", leaf * (stem + Vector3(0.009, 0, 0)), leaf * (stem - Vector3(0.12, 0, 0)), 0.009, small, 8)
	for y: float in [0.25, 1.08, 1.92]:
		rod("dark_steel", leaf * Vector3(-0.014, y - 0.05, 0), leaf * Vector3(-0.014, y + 0.05, 0), 0.012, small, 8)


## What runs under the corridor ceiling from end to end: a ventilation duct of
## galvanised sheet with a grille every few metres, and a cable ladder with
## the cables that feed the annex. Conduit comes down from the ladder to a
## switch beside each door.
func _corridor_services(z0: float, z1: float, ceiling: float) -> void:
	var small := DETAIL | NO_COLLIDE
	var length := z1 - z0 - 0.02
	var mid := (z0 + z1) * 0.5

	# The duct, 400 by 280 mm, in lengths that are flanged together and hung
	# from the slab on a strap and two threaded rods.
	var duct := Vector3(21.52, ceiling - 0.2, mid)
	box("galvanised", duct, Vector3(0.4, 0.28, length), Vector3.ZERO, NO_COLLIDE)
	var z := z0 + 0.7
	while z < z1 - 0.2:
		box("galvanised", Vector3(duct.x, duct.y, z), Vector3(0.46, 0.34, 0.03), Vector3.ZERO, small)
		box("dark_steel", Vector3(duct.x, duct.y - 0.146, z + 0.12), Vector3(0.5, 0.012, 0.03), Vector3.ZERO, small)
		for side: float in [-1.0, 1.0]:
			var strap := Vector3(duct.x + side * 0.235, duct.y - 0.146, z + 0.12)
			rod("dark_steel", strap, Vector3(strap.x, ceiling, strap.z), 0.005, small, 6)
		z += 1.5
	for grille: float in [-9.4, -4.6, -0.2]:
		var under := Vector3(duct.x, duct.y - 0.141, grille)
		box("dark_steel", under, Vector3(0.3, 0.004, 0.5), Vector3.ZERO, small)
		for i in 8:
			box("galvanised", under + Vector3(0, -0.012, (i - 3.5) * 0.058), Vector3(0.28, 0.003, 0.04), Vector3(28, 0, 0), small)

	# The cable ladder: two rails, a rung every 300 mm, a hanger every 1.5 m.
	var ladder := Vector3(23.02, ceiling - 0.3, mid)
	for side: float in [-1.0, 1.0]:
		box("galvanised", ladder + Vector3(side * 0.15, 0.025, 0), Vector3(0.012, 0.05, length), Vector3.ZERO, small)
	z = z0 + 0.15
	var rung := 0
	while z < z1:
		box("galvanised", Vector3(ladder.x, ladder.y + 0.008, z), Vector3(0.3, 0.012, 0.025), Vector3.ZERO, small)
		if rung % 5 == 2:
			for side: float in [-1.0, 1.0]:
				rod("dark_steel", Vector3(ladder.x + side * 0.165, ladder.y, z), Vector3(ladder.x + side * 0.165, ceiling, z), 0.005, small, 6)
		z += 0.3
		rung += 1
	# Cables of several gauges lie on it side by side. Each is one long
	# sliver of a thing, which is what a tiled renderer likes least, so there
	# are few of them and they have few sides.
	var lay := -0.11
	for gauge: float in [0.018, 0.013, 0.024, 0.015]:
		lay += gauge
		var cable := Vector3(ladder.x + lay, ladder.y + 0.014 + gauge, 0)
		rod("rubber", cable + Vector3(0, 0, z0 + 0.01), cable + Vector3(0, 0, z1 - 0.01), gauge, small, 5)
		lay += gauge + 0.012

	# Conduit from the ladder across to the wall and down to a switch.
	for door_z: float in [-9.0, -2.0]:
		var drop_z := door_z - 1.08
		var wall_x := 23.47
		var from := Vector3(ladder.x + 0.15, ladder.y + 0.03, drop_z)
		hose("galvanised", PackedVector3Array([
			from, Vector3(wall_x - 0.08, from.y, drop_z), Vector3(wall_x - 0.02, from.y - 0.02, drop_z),
			Vector3(wall_x, from.y - 0.08, drop_z), Vector3(wall_x, 1.33, drop_z),
		]), 0.011, small, 6)
		for y: float in [2.6, 1.9]:
			box("galvanised", Vector3(wall_x + 0.006, y, drop_z), Vector3(0.036, 0.02, 0.05), Vector3.ZERO, small)
		rounded_box("galvanised", Transform3D(Basis(), Vector3(wall_x - 0.005, 1.27, drop_z)), Vector3(0.06, 0.12, 0.08), 0.008, small)
		box("rubber", Vector3(wall_x - 0.04, 1.27, drop_z), Vector3(0.012, 0.035, 0.018), Vector3(0, 0, 14), small)


## Notice board on the corridor wall, with what was pinned to it when the
## place closed; `at` is the middle of its back, on a wall that faces +X.
func _notice_board(at: Vector3) -> void:
	var small := DETAIL | NO_COLLIDE
	var size := Vector2(1.15, 0.8)
	box("wood", at + Vector3(0.008, 0, 0), Vector3(0.016, size.y, size.x), Vector3.ZERO, small)
	for edge: float in [-1.0, 1.0]:
		box("galvanised", at + Vector3(0.013, edge * size.y * 0.5, 0), Vector3(0.026, 0.03, size.x + 0.03), Vector3.ZERO, small)
		box("galvanised", at + Vector3(0.013, 0, edge * size.x * 0.5), Vector3(0.026, size.y, 0.03), Vector3.ZERO, small)
	# Sheets of A4 and smaller, none of them straight: [along the board, up, tilt in degrees, scale].
	var sheets: Array = [
		[-0.4, 0.14, 2.0, 1.0], [-0.15, 0.17, -1.5, 1.0], [0.11, 0.12, 1.0, 1.0], [0.4, 0.15, -3.0, 1.0],
		[-0.36, -0.2, -2.5, 0.7], [-0.08, -0.17, 4.0, 1.0], [0.25, -0.2, -14.0, 0.7], [0.44, -0.22, 2.0, 0.5],
	]
	for i in sheets.size():
		var sheet: Array = sheets[i]
		var paper: Vector3 = Vector3(0.0012, 0.297, 0.21) * float(sheet[3])
		var xf := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(sheet[2])), at + Vector3(0.017 + i * 0.0004, sheet[1], sheet[0]))
		_box("paper", xf, paper, small)
		_box("enamel_red" if i % 3 == 0 else "bare_steel", xf * Transform3D(Basis(), Vector3(0.003, paper.y * 0.5 - 0.015, 0)), Vector3(0.005, 0.009, 0.009), small)


## The way from the storeroom to the boiler house: north out of the annex,
## then east. With the bend in it, nobody in the annex looks into the boiler
## house or the other way round, so only one of the two is ever drawn.
func _passage() -> void:
	var height := PASSAGE_H
	# Two legs, each 2.4 m wide: north from the storeroom, then east.
	box("floor", Vector3(24.7, -0.25, -15.5), Vector3(2.8, 0.5, 6.2))
	box("floor", Vector3(27.55, -0.25, -17.2), Vector3(2.9, 0.5, 2.8))
	box("concrete", Vector3(24.7, height + 0.125, -15.5), Vector3(2.8, 0.25, 6.2))
	box("concrete", Vector3(27.55, height + 0.125, -17.2), Vector3(2.9, 0.25, 2.8))
	wall(WALL, false, 23.4, 0.2, -18.6, -12.4, 0.0, height, [])
	wall(WALL, true, -18.5, 0.2, 23.5, 29.0, 0.0, height, [])
	wall(WALL, false, 26.0, 0.2, -15.8, -12.4, 0.0, height, [])
	wall(WALL, true, -15.9, 0.2, 25.9, 29.0, 0.0, height, [])
	# Shut at both ends while its lightmap is baked, and the boiler house at
	# its side of the door.
	bake_blocker(Vector3(24.7, 1.55, -12.41), Vector3(2.6, 3.1, 0.02))
	bake_blocker(Vector3(28.99, 1.55, -17.2), Vector3(0.02, 3.1, 2.6))
	bake_blocker(Vector3(29.01, 1.15, -17.1), Vector3(0.02, 2.3, 1.8))

	tube(Vector3(24.7, height - 0.08, -14.2), false, true, true, 5.0)
	tube(Vector3(27.4, height - 0.08, -17.2), true, true, true, 4.5)
	# Conduit along the ceiling from one fitting to the next, and a pipe that
	# follows the passage round the corner above head height.
	var small := DETAIL | NO_COLLIDE
	hose("galvanised", PackedVector3Array([
		Vector3(24.3, height - 0.03, -12.5), Vector3(24.3, height - 0.03, -17.0), Vector3(24.45, height - 0.03, -17.6), Vector3(25.1, height - 0.03, -17.75), Vector3(28.9, height - 0.03, -17.75),
	]), 0.012, small, 6)
	hose("pipe", PackedVector3Array([
		Vector3(23.62, 2.45, -12.5), Vector3(23.62, 2.45, -17.7), Vector3(23.7, 2.45, -18.15), Vector3(24.2, 2.45, -18.28), Vector3(28.95, 2.45, -18.28),
	]), 0.05, NO_COLLIDE, 10)
	for at: Vector3 in [Vector3(23.62, 2.45, -13.6), Vector3(23.62, 2.45, -16.0), Vector3(25.8, 2.45, -18.28), Vector3(28.2, 2.45, -18.28)]:
		box("dark_steel", at + Vector3(0, 0.07, 0), Vector3(0.14, 0.03, 0.14), Vector3.ZERO, small)
	# Nothing stands in the way through: what there is, is in the far corner.
	place("korean_fire_extinguisher_01", Vector3(23.7, 0, -17.6), 90)
	place("cardboard_box_01", Vector3(24.0, 0, -18.1), 25)
	drop("plastic_broom", Vector3(25.8, 0, -13.4), -90)


## The boiler house: a tall room of brick under a concrete roof, with the
## boiler along its north side, the feed tank and its pumps by the west wall
## and the switchgear on the south wall. Its windows face north and east, so
## the evening sun never comes in; what light there is comes from two lamps
## and the fire.
func _boiler_house() -> void:
	var mid := Vector3((BX0 + BX1) * 0.5, 0, (BZ0 + BZ1) * 0.5)
	var wide := BX1 - BX0
	var deep := BZ1 - BZ0
	box("floor", mid + Vector3(0, -0.25, 0), Vector3(wide + 0.8, 0.5, deep + 0.8))
	box("concrete", mid + Vector3(0, BOILER_H + 0.15, 0), Vector3(wide + 0.8, 0.3, deep + 0.8))
	# West wall with the door to the passage, east wall with the door to the
	# yard, which is shut, and a window over the boiler's flue end.
	wall("brick", false, BX0 - 0.2, 0.4, BZ0 - 0.4, BZ1 + 0.4, 0.0, BOILER_H, [[-17.9, -16.3, 0.0, 2.2]])
	wall("brick", false, BX1 + 0.2, 0.4, BZ0 - 0.4, BZ1 + 0.4, 0.0, BOILER_H, [[-17.9, -16.3, 0.0, 2.2], [-21.5, -18.5, 4.4, 6.2]])
	wall("brick", true, BZ0 - 0.2, 0.4, BX0, BX1, 0.0, BOILER_H, [[31.5, 38.5, 4.4, 6.2]])
	wall("brick", true, BZ1 + 0.2, 0.4, BX0, BX1, 0.0, BOILER_H, [])
	_mullions(Vector3(35.0, 5.3, BZ0 - 0.2), 7.0, 1.8, true, 1.0)
	_mullions(Vector3(BX1 + 0.2, 5.3, -20.0), 3.0, 1.8, false, 1.0)
	box("concrete", Vector3(35.0, 4.34, BZ0 - 0.1), Vector3(7.3, 0.12, 0.6))
	box("concrete", Vector3(BX1 + 0.1, 4.34, -20.0), Vector3(0.6, 0.12, 3.3))
	_doorway(Transform3D(Basis(), Vector3(BX0 - 0.2, 0, -17.1)), 0.4, 108.0, 163.0)
	_doorway(Transform3D(Basis(Vector3.UP, PI), Vector3(BX1 + 0.2, 0, -17.1)), 0.4, 0.0, 0.0)
	# Steel behind the panes of the yard door: nobody looks in from outside.
	box("door", Vector3(BX1 + 0.3, 1.1, -17.1), Vector3(0.04, 2.2, 1.6), Vector3.ZERO, NO_COLLIDE)
	_collide_box(Transform3D(Basis(), Vector3(BX1 + 0.2, 1.1, -17.1)), Vector3(0.4, 2.2, 1.6), "metal")
	# Concrete plinth along the walls and beams under the roof.
	for z: float in [BZ0 + 0.04, BZ1 - 0.04]:
		box("concrete", Vector3(mid.x, 0.5, z), Vector3(wide, 1.0, 0.08), Vector3.ZERO, NO_COLLIDE)
	for x: float in [BX0 + 0.04, BX1 - 0.04]:
		box("concrete", Vector3(x, 0.5, -22.2), Vector3(0.08, 1.0, 8.6), Vector3.ZERO, NO_COLLIDE)
		box("concrete", Vector3(x, 0.5, -15.4), Vector3(0.08, 1.0, 1.8), Vector3.ZERO, NO_COLLIDE)
	for x: float in [32.4, 35.4, 38.4]:
		box("concrete", Vector3(x, BOILER_H - 0.25, mid.z), Vector3(0.3, 0.5, deep), Vector3.ZERO, NO_COLLIDE)
	dust(AABB(Vector3(BX0, 0.2, BZ0), Vector3(wide, BOILER_H - 0.6, deep)), 1400)

	_boiler(BOILER)
	# The feed tank stands in the corner behind the boiler, its two pumps by
	# the west wall; the line from the pumps crosses to the boiler overhead.
	var tank := Vector3(39.85, 0, -25.0)
	_tank(tank, 25, -115, NAN, BZ0 + 0.25)
	var facing := Basis(Vector3.UP, deg_to_rad(25.0))
	label("T3", tank + Vector3(0, 3.0, 0) + facing * Vector3(0, 0, 1.25), facing * Vector3.BACK, 0.5, Color(0.06, 0.06, 0.06), 0.2)
	var pumps: Array[float] = [-23.4, -21.7]
	for z in pumps:
		_pump(Vector3(29.97, 0, z), 0)
	_m = Transform3D()
	for z in pumps:
		# Suction comes up out of the floor, the discharge goes up the wall.
		_line(RUST, [Vector3(29.97, -0.05, z + 1.15), Vector3(29.97, 0.25, z + 1.1), Vector3(29.97, 0.44, z + 0.95), Vector3(29.97, 0.44, z + 0.7)], 0.05, 8)
		_line(RUST, [Vector3(29.97, 1.0, z + 0.39), Vector3(29.97, 2.4, z + 0.39), Vector3(30.05, 2.65, z + 0.39), Vector3(30.5, 2.7, z + 0.39)], 0.045, 8)
		_flange(RUST, Vector3(29.97, 1.6, z + 0.39), Vector3.UP, 0.045)
	_line(RUST, [
		Vector3(30.5, 2.7, -23.1), Vector3(30.5, 2.7, -21.2), Vector3(30.65, 2.7, -20.9), Vector3(31.2, 2.7, -20.8),
		Vector3(33.2, 2.7, -20.8), Vector3(33.75, 2.6, -20.85), Vector3(33.95, 2.3, -21.0),
	], 0.045, 8)
	_flange(RUST, Vector3(32.2, 2.7, -20.8), Vector3.RIGHT, 0.045)
	# The header on the north wall that the tank is filled from.
	_bar(RUST, Vector3(38.75, 5.36, BZ0 + 0.25), Vector3(BX1 - 0.02, 5.36, BZ0 + 0.25), 0.14, 16)
	_bar(RUST, Vector3(38.71, 5.36, BZ0 + 0.25), Vector3(38.75, 5.36, BZ0 + 0.25), 0.25, 20)
	_flange(RUST, Vector3(40.8, 5.36, BZ0 + 0.25), Vector3.RIGHT, 0.14)

	# Switchgear and a board of gauges on the south wall, a cupboard beside them.
	cabinets(Vector3(37.6, 0, BZ1 - 0.5), 180)
	_gauge_board(Vector3(34.6, 1.75, BZ1), Vector3.FORWARD)
	cupboard("machine", Vector3(32.2, 0, BZ1 - 0.32), 180, Vector3(0.98, 1.9, 0.6))
	tube(Vector3(35.4, 2.75, BZ1 - 0.3), true, true, true, 5.5)
	for x: float in [-0.5, 0.5]:
		box("steel", Vector3(35.4 + x, 2.79, BZ1 - 0.11), Vector3(0.04, 0.04, 0.22), Vector3.ZERO, NO_COLLIDE)

	# Two lamps hang from the beams; the one over the way through still works.
	lamp(Vector3(33.6, 6.1, -18.2), BOILER_H, true, true)
	lamp(Vector3(38.3, 6.1, -18.6), BOILER_H, false, false)
	# And a bulb on the east wall, or the corner with the tank would be black.
	bulb(Vector3(BX1 - 0.25, 3.4, -23.0), true)
	# What stands about: fuel for the burner, crates, the things of whoever
	# looked after the boiler.
	for at: Vector3 in [Vector3(32.5, 0, -19.3), Vector3(33.15, 0, -18.95), Vector3(40.9, 0, -19.5)]:
		fuel(at)
	barrel(Vector3(40.9, 0, -20.3))
	barrel(Vector3(40.3, 0, -20.6))
	crates(Vector3(37.0, 0, -19.3), 2)
	pallet(Vector3(33.7, 0, -15.3), 4.0, 3)
	barrel(Vector3(29.9, 0, -15.1))
	place("metal_jerrycan", Vector3(29.75, 0, -20.5), 30)
	place("metal_jerrycan", Vector3(29.8, 0, -20.05), -50)
	place("tool_cart", Vector3(40.4, 0, -22.4), 80)
	place("wooden_ladder", Vector3(41.0, 0, -15.6), 90, true)
	place("korean_fire_extinguisher_01", Vector3(BX0 + 0.2, 0, -18.4), 90)
	place("korean_fire_extinguisher_01", Vector3(BX1 - 0.2, 0, -18.4), -90)
	mount("fire_alarm", Vector3(BX0, 1.4, -18.9), 90, true)
	place("plastic_monobloc_chair_01", Vector3(35.0, 0, -15.6), 170)
	drop("oil_tin", Vector3(30.7, 0, -20.6), 80)
	place("trashbag", Vector3(39.9, 0, -15.0), 40)
	prop("water_manhole_cover", Transform3D(Basis(), Vector3(34.6, -0.055, -19.4)))


## Fire-tube boiler lying on two saddles: the burner at its west end, the
## smokebox and the flue up through the roof at the other. `at` is the middle
## of its footprint.
func _boiler(at: Vector3) -> void:
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
	var south := BZ1 - at.z
	_line(RUST, [
		stop + Vector3(0, 0.15, 0), Vector3(-0.2, main - 0.5, 0), Vector3(-0.2, main - 0.15, 0.12), Vector3(-0.2, main, 0.45), Vector3(-0.2, main, south + 0.1),
	], 0.11, 14)
	for z: float in [2.6, 5.4]:
		_flange(RUST, Vector3(-0.2, main, z), Vector3.BACK, 0.11)
	for z: float in [1.6, 4.4, 7.0]:
		_part = DETAIL | NO_COLLIDE
		_bar(IRON, Vector3(-0.2, main + 0.11, z), Vector3(-0.2, BOILER_H - at.y, z), 0.008, 6)
		_part = NO_COLLIDE

	# The smokebox at the back and the flue out of it.
	_block(IRON, Vector3(half + 0.42, axis + 0.1, 0), Vector3(0.72, 2.3, 2.1), 0.1)
	_block(IRON, Vector3(half + 0.79, axis - 0.2, 0), Vector3(0.03, 0.9, 0.7), 0.01)
	_lever(Vector3(half + 0.805, axis - 0.2, 0.2), Vector3.RIGHT, Vector3.DOWN, 0.16)
	var flue := BOILER_H - at.y - (axis + 1.2)
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
func _pump(at: Vector3, yaw_deg: float) -> void:
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


## Pressure gauge: a brass case with a white dial and a hand. `at` lies on the
## surface it sits on and `out` is the normal of that surface.
func _gauge(at: Vector3, out: Vector3, radius: float) -> void:
	_turned(BRASS, at, out, PackedVector2Array([
		Vector2(radius, 0), Vector2(radius, 0.04), Vector2(radius * 0.88, 0.045), Vector2(radius * 0.88, 0.03),
	]), 20)
	var part := _part
	_part = DETAIL | NO_COLLIDE
	_turned("paper", at, out, PackedVector2Array([Vector2(radius * 0.88, 0.03), Vector2(0, 0.03)]), 20)
	var plane := _up_along(out)
	var hand := (plane.x * 0.6 + plane.z * 0.8) * radius * 0.6
	_bar(IRON, at + out * 0.034 - hand * 0.2, at + out * 0.034 + hand, radius * 0.035, 4)
	_bar(IRON, at + out * 0.03, at + out * 0.04, radius * 0.1, 8)
	_part = part


## Board of gauges with the pipes that come up to them; `at` is the middle of
## its back on a wall that faces `out`.
func _gauge_board(at: Vector3, out: Vector3) -> void:
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


func _exterior() -> void:
	box("floor", Vector3(5, -0.55, 0), Vector3(160, 1.0, 160), Vector3.ZERO, DETAIL)
	# Yard wall and a skyline so the windows do not look out on nothing.
	box("brick", Vector3(5, 1.6, 34), Vector3(110, 3.2, 0.5), Vector3.ZERO, DETAIL)
	# The west wall has the gate of the yard in it, straight across from the
	# loading door: what the player sees when that door goes up.
	for side: float in [-1.0, 1.0]:
		box("brick", Vector3(-50, 1.6, side * 19.0), Vector3(0.5, 3.2, 30.0), Vector3.ZERO, DETAIL)
		box("concrete", Vector3(-50, 1.9, side * 3.7), Vector3(0.7, 3.8, 0.7), Vector3.ZERO, DETAIL)
		box("concrete", Vector3(-50, 3.86, side * 3.7), Vector3(0.9, 0.12, 0.9), Vector3.ZERO, DETAIL | NO_COLLIDE)
	# The apron in front of the loading door, level with the floor of the hall,
	# with a post either side of the door to keep lorries off the frame.
	box("concrete", Vector3(-HX - 5.0, -0.03, 0.0), Vector3(8.0, 0.06, 9.0), Vector3.ZERO, DETAIL | NO_COLLIDE)
	for z: float in [-3.1, 3.1]:
		cylinder("steel_yellow", Vector3(-HX - 1.3, 0, z), 0.09, 1.0, DETAIL)
	container("container_red", Vector3(-HX - 7.5, 0, -8.0), true, DETAIL)
	container("container_grey", Vector3(-HX - 11.0, 0, 9.5), false, DETAIL)
	box("brick", Vector3(60, 1.6, 0), Vector3(0.5, 3.2, 68), Vector3.ZERO, DETAIL)
	box("brick", Vector3(5, 1.6, -34), Vector3(110, 3.2, 0.5), Vector3.ZERO, DETAIL)
	box("brick", Vector3(34, 5, 52), Vector3(26, 10, 16), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("roof", Vector3(-30, 4, 56), Vector3(30, 8, 18), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("concrete", Vector3(52, 7, 14), Vector3(14, 14, 20), Vector3.ZERO, DETAIL | NO_COLLIDE)
	cylinder("brick", Vector3(42, 0, 50), 2.2, 38.0, DETAIL | NO_COLLIDE, Vector3.ZERO, 1.4, 20)
	container("container_blue", Vector3(38, 0, 9), false, DETAIL)
	# The stack of the boiler house, where its flue comes through the roof.
	cylinder("steel", Vector3(BOILER.x + 3.22, BOILER_H + 0.3, BOILER.z), 0.4, 9.0, DETAIL | NO_COLLIDE, Vector3.ZERO, 0.36, 16)


func _probes() -> void:
	probe("Hall", Vector3(0, 4.6, 0), Vector3(HX * 2.0, 9.4, HZ * 2.0), Vector3(2.0, -2.2, 1.0))
	probe("Corridor", Vector3(22.0, 1.7, -5.0), Vector3(3.0, 3.4, 14.0), Vector3.ZERO)
	probe("RoomA", Vector3(27.1, 1.7, -8.65), Vector3(6.8, 3.4, 6.7), Vector3(0, 0, 0.8))
	probe("RoomB", Vector3(27.1, 1.7, -1.55), Vector3(6.8, 3.4, 7.1), Vector3.ZERO)
	probe("Passage", Vector3(25.0, 1.5, -15.8), Vector3(3.4, 3.0, 5.2), Vector3(-0.3, 0, 1.0))
	probe("Boiler", Vector3((BX0 + BX1) * 0.5, BOILER_H * 0.5, (BZ0 + BZ1) * 0.5), Vector3(BX1 - BX0, BOILER_H, BZ1 - BZ0), Vector3(-1.5, -1.5, 2.5))


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
	# The boiler house: rain under its windows, soot and oil on its floor.
	for x: float in [32.8, 35.3, 37.6]:
		wall_decal(_pick("leak"), Vector3(x, 2.9, BZ0 + 0.04), Vector3.BACK, 1.5, 3.2)
	wall_decal(_pick("leak"), Vector3(BX1 - 0.04, 2.9, -19.6), Vector3.LEFT, 1.6, 3.2)
	wall_decal("grime", Vector3(35.4, 0.7, BZ1 - 0.1), Vector3.FORWARD, 11.0, 1.4)
	wall_decal("grime", Vector3(35.4, 0.7, BZ0 + 0.1), Vector3.BACK, 11.0, 1.4)
	wall_decal("grime", Vector3(BX0 + 0.1, 0.7, -22.5), Vector3.RIGHT, 7.5, 1.4)
	wall_decal("grime", Vector3(BX1 - 0.1, 0.7, -22.0), Vector3.LEFT, 8.5, 1.4)
	floor_decal("stain_1", Vector3(32.0, 0, -21.6), Vector2(3.6, 3.0), 30)
	floor_decal("stain_2", Vector3(30.6, 0, -22.4), Vector2(2.6, 3.4), 80)
	floor_decal("stain_1", Vector3(36.5, 0, -18.2), Vector2(4.0, 3.2), 150)
	floor_decal("stain_2", Vector3(39.4, 0, -22.4), Vector2(2.4, 2.4), 10)
	wall_decal("grime", Vector3(23.52, 0.5, -15.4), Vector3.RIGHT, 5.8, 1.0)
	floor_decal("stain_2", Vector3(26.8, 0, -17.2), Vector2(3.0, 1.8), 5)


## What makes the place look as if people worked here until yesterday: fire
## points, fuel and oil by the machines, rubbish, boxes and chairs.
func _clutter() -> void:
	var fire_points: Array = [
		[Vector3(-4.75, 0, HZ - 0.2), 180], [Vector3(4.75, 0, -HZ + 0.2), 0], [Vector3(HX - 0.2, 0, 0.7), -90],
		[Vector3(20.76, 0, -6.5), 90], [Vector3(-4.0, DECK_Y, -HZ + 0.22), 0],
	]
	for point: Array in fire_points:
		place("korean_fire_extinguisher_01", point[0], point[1])
	mount("fire_alarm", Vector3(-HX, 1.4, 3.1), 90, true)
	mount("fire_alarm", Vector3(HX, 1.4, 0.4), -90, true)
	mount("fire_alarm", Vector3(20.56, 1.4, -7.4), 90, true)
	# The corridor floor is wet, and somebody did put out a sign.
	prop("WetFloorSign_01", Transform3D(Basis(Vector3.UP, 0.3), Vector3(21.9, 0, -2.6)))

	place("metal_jerrycan", Vector3(11.9, 0, -7.1), 20)
	place("metal_jerrycan", Vector3(11.7, 0, -7.6), -75)
	place("metal_jerrycan", Vector3(-9.1, 0, 5.2), 100)
	drop("oil_tin", Vector3(-0.75, 0, 6.8), 40)
	drop("oil_tin", Vector3(-7.2, 0, 2.3), 150)

	place("trashbag", Vector3(19.3, 0, 11.3), 20)
	place("trashbag", Vector3(19.35, 0, 10.55), 140)
	place("trashbag", Vector3(20.95, 0, -11.4), 0)
	place("trashbag", Vector3(21.5, 0, -11.5), 60)
	drop("plastic_broom", Vector3(22.93, 0, -6.7), -90)

	var box: Vector3 = _model("cardboard_box_01").box.size
	place("cardboard_box_01", Vector3(29.6, 0, -11.5), 5)
	place("cardboard_box_01", Vector3(29.62, box.y, -11.48), -12)
	place("cardboard_box_01", Vector3(28.95, 0, -11.6), 80)
	place("cardboard_box_01", Vector3(25.3, 0, 1.6), 0)
	place("cardboard_box_01", Vector3(25.32, box.y, 1.58), 15)
	place("plastic_monobloc_chair_01", Vector3(27.3, 0, 0.55), 15)
	place("plastic_monobloc_chair_01", Vector3(28.9, 0, -1.9), -70)

	# Drains along the middle of the hall, their frames flush with the floor.
	for x: float in [-8.5, 4.9]:
		prop("water_manhole_cover", Transform3D(Basis(), Vector3(x, -0.055, 0)))


## Lines from when the hall was in use: an aisle from the loading door to the
## annex with a branch to the stairs, borders around the machines, bays along
## the south wall and hatching where nothing was to be put down. Arrows down
## the aisle point the way out, which is the way the route goes.
func _floor_paint() -> void:
	floor_paint_area(Rect2(-HX, BZ0 - 0.5, BX1 + 0.5 + HX, HZ - BZ0 + 0.5))
	for x: float in [16.5, 12.6, 1.5, -5.5, -12.5]:
		floor_arrow(Vector2(x, 1.2 if x == 12.6 else 0.0), Vector2.LEFT)
	# The way in from the boiler house: across it, round the bend in the
	# passage, out of the storeroom into the corridor and through the nearer
	# doorway to the aisle.
	for at: Vector2 in [Vector2(38.2, -17.1), Vector2(32.6, -17.1), Vector2(27.4, -17.2), Vector2(22.0, -9.0), Vector2(17.4, -9.0)]:
		floor_arrow(at, Vector2.LEFT)
	floor_arrow(Vector2(24.7, -14.6), Vector2.DOWN)
	floor_arrow(Vector2(15.0, -5.6), Vector2(-0.6, 0.8))
	floor_frame(Rect2(BOILER.x - 4.2, BOILER.z - 1.75, 8.1, 3.5), PAINT_YELLOW, 0.16, PAINT_BLACK)
	floor_frame(Rect2(29.5, -24.5, 1.0, 3.9), PAINT_YELLOW, 0.16, PAINT_BLACK)
	floor_hatch(Rect2(BX1 - 2.4, -18.1, 2.3, 2.0))
	floor_frame(Rect2(BX1 - 2.4, -18.1, 2.3, 2.0))
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


# --- Machine parts, all in the frame of the machine being built ---------------


## Rolled I-section lying between two points, standing on them.
func _i_beam(mat: String, from: Vector3, to: Vector3, width: float, height: float) -> void:
	var flange := height * 0.08
	for y: float in [flange * 0.5, height - flange * 0.5]:
		beam(mat, _m * (from + Vector3(0, y, 0)), _m * (to + Vector3(0, y, 0)), width, _part, flange)
	var middle := Vector3(0, height * 0.5, 0)
	beam(mat, _m * (from + middle), _m * (to + middle), width * 0.08, _part, height - flange * 2.0)


## Bolted pair of flanges on a pipe of `radius` that runs along `axis` through `at`.
func _flange(mat: String, at: Vector3, axis: Vector3, radius: float) -> void:
	var along := axis.normalized()
	var rim := radius * 1.5 + 0.03
	_bar(mat, at - along * 0.03, at + along * 0.03, rim, 20)
	for side: float in [-1.0, 1.0]:
		_bolt_circle(at + along * side * 0.03, along * side, (radius + rim) * 0.5, 8)


## Unit vector `deg` degrees round from +Z towards +X.
func _round(deg: float) -> Vector3:
	return Basis(Vector3.UP, deg_to_rad(deg)) * Vector3.BACK


## Hexagonal bolt head sitting on `at`.
func _bolt(at: Vector3, out: Vector3, size := 0.022) -> void:
	_bar(IRON, at, at + out * size * 0.7, size, 6)


func _bolt_circle(center: Vector3, out: Vector3, radius: float, count: int) -> void:
	var plane := _up_along(out)
	for i in count:
		var angle := TAU * i / count
		_bolt(center + (plane.x * cos(angle) + plane.z * sin(angle)) * radius, out)


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
	rounded_box(mat, _m * Transform3D(plane, middle - plane.z * (radius + 0.03)), Vector3(radius * 0.6, radius * 0.7, 0.08), 0.015, _part)
	if feet:
		rounded_box(mat, _m * Transform3D(plane, middle + plane.z * (radius + 0.01)), Vector3(radius * 1.8, length * 0.6, 0.04), 0.008, _part)


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
