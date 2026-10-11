extends "res://tools/levels/factory/plan.gd"
## The boiler house of the factory: a tall room of brick under a concrete
## roof, with the boiler along its north side, the feed tank and its pumps by
## the west wall and the switchgear on the south wall. Its windows face north
## and east, so the evening sun never comes in; what light there is comes
## from two lamps and the fire. The level starts here, at the yard door.


func _describe() -> void:
	# Shut at the door to the passage while its lightmap is baked.
	bake_blocker(Vector3(29.01, 1.15, -17.1), Vector3(0.02, 2.3, 1.8))
	_house()
	probe("Boiler", Vector3((BX0 + BX1) * 0.5, BOILER_H * 0.5, (BZ0 + BZ1) * 0.5), Vector3(BX1 - BX0, BOILER_H, BZ1 - BZ0), Vector3(-1.5, -1.5, 2.5))
	_dirt()
	_floor_paint()


## In by the yard door, which is shut behind the player.
func _route_through() -> void:
	route_start(Vector3(40.2, 0, -17.1), Vector3(30.0, 0, -17.1))
	# Two behind the boiler, and one that comes running out of the passage.
	route_zone("boiler", "the boiler house", AABB(Vector3(BX0, 0, BZ0), Vector3(9.2, BOILER_H, BZ1 - BZ0)), [
		["grunt", Vector3(36.2, 0, -25.2)], ["grunt", Vector3(33.6, 0, -25.2)], ["rusher", Vector3(24.7, 0, -14.4)],
	])


## The room itself, the boiler with its feed tank and pumps, the switchgear
## and what stands about.
func _house() -> void:
	var mid := Vector3((BX0 + BX1) * 0.5, 0, (BZ0 + BZ1) * 0.5)
	var wide := BX1 - BX0
	var deep := BZ1 - BZ0
	box("floor", mid + Vector3(0, -0.25, 0), Vector3(wide + 0.8, 0.5, deep + 0.8))
	box("concrete", mid + Vector3(0, BOILER_H + 0.15, 0), Vector3(wide + 0.8, 0.3, deep + 0.8))
	# West wall with the door to the passage, east wall with the door to the
	# yard, which is shut, and a window over the boiler's flue end.
	wall("brick", false, BX0 - 0.2, 0.4, BZ0 - 0.4, BZ1 + 0.4, 0.0, BOILER_H, [BOILER_DOORWAY])
	wall("brick", false, BX1 + 0.2, 0.4, BZ0 - 0.4, BZ1 + 0.4, 0.0, BOILER_H, [[-17.9, -16.3, 0.0, 2.2], [-21.5, -18.5, 4.4, 6.2]])
	wall("brick", true, BZ0 - 0.2, 0.4, BX0, BX1, 0.0, BOILER_H, [[31.5, 38.5, 4.4, 6.2]])
	wall("brick", true, BZ1 + 0.2, 0.4, BX0, BX1, 0.0, BOILER_H, [])
	_mullions(Vector3(35.0, 5.3, BZ0 - 0.2), 7.0, 1.8, true, 1.0)
	_mullions(Vector3(BX1 + 0.2, 5.3, -20.0), 3.0, 1.8, false, 1.0)
	box("concrete", Vector3(35.0, 4.34, BZ0 - 0.1), Vector3(7.3, 0.12, 0.6))
	box("concrete", Vector3(BX1 + 0.1, 4.34, -20.0), Vector3(0.6, 0.12, 3.3))
	doorway(Transform3D(Basis(), Vector3(BX0 - 0.2, 0, -17.1)), 0.4, 108.0, 163.0)
	doorway(Transform3D(Basis(Vector3.UP, PI), Vector3(BX1 + 0.2, 0, -17.1)), 0.4, 0.0, 0.0)
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

	boiler(BOILER, BZ1, BOILER_H)
	# The feed tank stands in the corner behind the boiler, its two pumps by
	# the west wall; the line from the pumps crosses to the boiler overhead.
	var feed := Vector3(39.85, 0, -25.0)
	tank(feed, 25, -115, BZ0 + 0.25)
	var facing := Basis(Vector3.UP, deg_to_rad(25.0))
	label("T3", feed + Vector3(0, 3.0, 0) + facing * Vector3(0, 0, 1.25), facing * Vector3.BACK, 0.5, Color(0.06, 0.06, 0.06), 0.2)
	var pumps: Array[float] = [-23.4, -21.7]
	for z in pumps:
		pump(Vector3(29.97, 0, z), 0)
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
	gauge_board(Vector3(34.6, 1.75, BZ1), Vector3.FORWARD)
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


## Rain under the windows, soot and oil on the floor.
func _dirt() -> void:
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


## Arrows across to the door of the passage, a border around the boiler and
## the pumps, and hatching to keep the yard door clear.
func _floor_paint() -> void:
	for at: Vector2 in [Vector2(38.2, -17.1), Vector2(32.6, -17.1)]:
		floor_arrow(at, Vector2.LEFT)
	floor_frame(Rect2(BOILER.x - 4.2, BOILER.z - 1.75, 8.1, 3.5), PAINT_YELLOW, 0.16, PAINT_BLACK)
	floor_frame(Rect2(29.5, -24.5, 1.0, 3.9), PAINT_YELLOW, 0.16, PAINT_BLACK)
	floor_hatch(Rect2(BX1 - 2.4, -18.1, 2.3, 2.0))
	floor_frame(Rect2(BX1 - 2.4, -18.1, 2.3, 2.0))
