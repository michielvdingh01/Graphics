extends "res://tools/levels/powerhouse/plan.gd"
## Where the power is switched and watched over: the stores it all comes in
## by, the cable corridor, the switch room with its two rows of gear, and the
## control room, where a wall of instruments divides the room in two.


func _describe() -> void:
	# Receiving: the roller door the stores come in by, shut, and what was
	# wheeled in last.
	roller_door(spot_in("receiving", 5.0, 0.25, 1.6), Vector3.BACK, Vector2(3.2, 3.2))
	# A tube over the door that still burns: where the level begins, there
	# has to be enough light to see which way it goes on.
	tube(spot_in("receiving", 5.0, 2.4, _floor_plan["receiving"].height - 0.08), true, true, false)
	place("hand_truck", spot_in("receiving", 8.4, 1.0), 200)
	place("industrial_storage_cart", spot_in("receiving", 2.0, 2.4), 80)

	# The cable corridor: the cables of the switch room on a ladder under the
	# ceiling, down its south side.
	cable_ladder(spot_in("cable_corridor", 0.4, 2.45, 2.5), spot_in("cable_corridor", 15.6, 2.45, 2.5), 3.0, 6)

	# The switch room: two rows of gear facing each other across an aisle,
	# with rubber mats to stand on, and the cables over both on ladders that
	# cross to the wall of the yard.
	var high: float = _floor_plan["switch_room"].height
	switchboard(spot_in("switch_room", 5.6, 3.6), 0, 9)
	switchboard(spot_in("switch_room", 5.6, 8.4), 180, 9)
	for z: float in [4.5, 7.5]:
		box("rubber", spot_in("switch_room", 5.6, z, 0.006), Vector3(7.2, 0.012, 0.8), Vector3.ZERO, NO_COLLIDE)
	for z: float in [3.5, 8.5]:
		cable_ladder(spot_in("switch_room", 1.4, z, 2.7), spot_in("switch_room", 15.6, z, 2.7), high, 6)
	cable_ladder(spot_in("switch_room", 11.0, 0.4, 2.95), spot_in("switch_room", 11.0, 8.5, 2.95), high, 4)
	gauge_board(spot_in("switch_room", 13.6, 11.6, 1.75), Vector3.FORWARD)
	wall_decal("warning_1", spot_in("switch_room", 9.21, 3.6, 1.5), Vector3.RIGHT, 0.4, 0.4, Color.WHITE, 0.06)
	wall_decal("warning_1", spot_in("switch_room", 9.21, 8.4, 1.5), Vector3.RIGHT, 0.4, 0.4, Color.WHITE, 0.06)
	place("tool_cart", spot_in("switch_room", 14.4, 2.2), -70)
	crates(spot_in("switch_room", 13.6, 9.6), 3)
	pallet(spot_in("switch_room", 2.0, 10.9), 12, 3)
	place("WetFloorSign_01", spot_in("switch_room", 11.4, 6.2), 30)
	floor_decal("stain_2", spot_in("switch_room", 12.4, 5.0), Vector2(3.0, 2.2), 70)

	# The control room: the instrument panel stands across the room with the
	# relays at its back, and the desk in front of it. Who walks in sees the
	# desk and the panel; what waits behind the panel he does not.
	var ceiling: float = _floor_plan["control_room"].height
	switchboard(spot_in("control_room", 8.2, 3.8), 0, 9, true)
	switchboard(spot_in("control_room", 8.2, 3.1), 180, 9)
	cable_ladder(spot_in("control_room", 4.6, 3.45, 2.75), spot_in("control_room", 11.8, 3.45, 2.75), ceiling, 6)
	control_desk(spot_in("control_room", 8.2, 6.4), 180)
	place("plastic_monobloc_chair_01", spot_in("control_room", 8.4, 7.5), 15)
	place(DESK, spot_in("control_room", 2.6, 9.25), 180)
	place("plastic_monobloc_chair_01", spot_in("control_room", 2.4, 8.3), -20)
	cupboard("machine", spot_in("control_room", 0.55, 6.6), 90, Vector3(0.98, 1.9, 0.6))
	lockers("machine_blue", spot_in("control_room", 0.47, 1.9), 90, 5, {1: 35.0, 3: 8.0})
	mount("fire_alarm", spot_in("control_room", 11.8, 8.0, 1.4), -90, true)
	place("korean_fire_extinguisher_01", spot_in("control_room", 11.6, 9.4), -90)
	floor_decal("stain_2", spot_in("control_room", 4.4, 6.0), Vector2(2.4, 1.8), 120)
