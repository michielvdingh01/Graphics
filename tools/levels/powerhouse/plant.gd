extends "res://tools/levels/powerhouse/plan.gd"
## The steam side of the powerhouse: the pump house with its feed tanks and
## pumps, the boiler house with its two boilers side by side, and the fuel
## store that feeds their burners.


func _describe() -> void:
	_pump_house()
	_boiler_house()
	_fuel_store()


## The starters of the pumps stand in a row across the room, a few steps in
## from the door of the yard. Behind them: four pumps in a row on the floor
## between a suction main and a delivery main, and two feed tanks in the
## south-east corner, their lines overhead to a header on the north wall.
## The heater lies along the west wall. Who comes in from the yard sees the
## starters; what waits among the pumps behind them he does not.
func _pump_house() -> void:
	var header_z := spot_in("pump_house", 0, 0.65).z
	tank(spot_in("pump_house", 12.0, 8.4), -90, -150, header_z, 170)
	tank(spot_in("pump_house", 10.2, 11.8), -70, -120, header_z)
	_m = Transform3D()
	_part = NO_COLLIDE
	var header := spot_in("pump_house", 9.4, 0.65, 5.36)
	_bar(RUST, header, header + Vector3(3.7, 0, 0), 0.14, 16)
	_bar(RUST, header - Vector3(0.04, 0, 0), header, 0.25, 20)
	_bolt_circle(header - Vector3(0.04, 0, 0), Vector3.LEFT, 0.2, 8)
	_flange(RUST, header + Vector3(1.9, 0, 0), Vector3.RIGHT, 0.14)

	# The pumps, their inlets to the north, and the two mains.
	var row := spot_in("pump_house", 3.4, 9.8)
	for i in 4:
		pump(row + Vector3(i * 1.4, 0, 0), 180)
	_m = Transform3D(Basis(), row)
	_part = NO_COLLIDE
	_collide_box(_m * Transform3D(Basis(), Vector3(2.1, 0.45, -1.15)), Vector3(5.6, 0.9, 0.5), "metal")
	_bar(RUST, Vector3(-0.9, 0.44, -1.15), Vector3(5.1, 0.44, -1.15), 0.1, 16)
	_bar(RUST, Vector3(-0.94, 0.44, -1.15), Vector3(-0.9, 0.44, -1.15), 0.18, 16)
	_bolt_circle(Vector3(-0.94, 0.44, -1.15), Vector3.LEFT, 0.14, 8)
	for x: float in [-0.5, 2.1, 4.7]:
		_block("concrete", Vector3(x, 0.17, -1.15), Vector3(0.3, 0.34, 0.4), 0.02)
	_bar("pipe", Vector3(-0.9, 2.5, 0.39), Vector3(9.3, 2.5, 0.39), 0.09, 16)
	_bar("pipe", Vector3(-0.94, 2.5, 0.39), Vector3(-0.9, 2.5, 0.39), 0.16, 16)
	for i in 4:
		var x := i * 1.4
		_bar(RUST, Vector3(x, 0.44, -0.75), Vector3(x, 0.44, -1.15), 0.07, 12)
		_flange(RUST, Vector3(x, 0.44, -0.9), Vector3.FORWARD, 0.07)
		_bar("pipe", Vector3(x, 0.98, 0.39), Vector3(x, 2.5, 0.39), 0.055, 12)
		_block(IRON, Vector3(x, 1.5, 0.39), Vector3(0.2, 0.22, 0.2), 0.04)
		_bar(BARE, Vector3(x, 1.5, 0.48), Vector3(x, 1.5, 0.7), 0.012, 8)
		_handwheel(Vector3(x, 1.5, 0.68), Vector3.BACK, 0.1)
		_flange("pipe", Vector3(x, 2.1, 0.39), Vector3.UP, 0.055)
	for x: float in [1.6, 6.0]:
		_part = DETAIL | NO_COLLIDE
		_bar(IRON, Vector3(x, 2.59, 0.39), Vector3(x, _floor_plan["pump_house"].height, 0.39), 0.008, 6)
		_part = NO_COLLIDE
	# The delivery main turns up the east wall and off through the roof.
	_line("pipe", [Vector3(9.3, 2.5, 0.39), Vector3(9.65, 2.5, 0.39), Vector3(9.9, 2.75, 0.39), Vector3(9.9, 3.4, 0.39), Vector3(9.9, _floor_plan["pump_house"].height + 0.05, 0.39)], 0.09, 12)
	box("deck", row + Vector3(2.1, 0.008, 1.3), Vector3(6.4, 0.016, 0.5), Vector3.ZERO, NO_COLLIDE)
	gauge_board(spot_in("pump_house", 5.5, 13.6, 1.75), Vector3.FORWARD)
	# And a lamp over the pumps, where the builder's is out.
	var high: float = _floor_plan["pump_house"].height
	lamp(spot_in("pump_house", 6.2, 8.0, high - 0.9), high, true, false)

	vessel(spot_in("pump_house", 1.5, 4.3), 0, 3.6, 0.7)
	switchboard(spot_in("pump_house", 8.0, 4.2), 180, 9)
	place("old_military_compressor", spot_in("pump_house", 2.4, 1.5), 180)
	for spot: Vector3 in [spot_in("pump_house", 0.9, 1.0), spot_in("pump_house", 0.85, 1.6)]:
		gas_bottle(spot)
	crates(spot_in("pump_house", 6.6, 6.8), 3)
	pallet(spot_in("pump_house", 2.4, 12.6), 20, 4)
	barrel(spot_in("pump_house", 13.0, 5.6))
	fuel(spot_in("pump_house", 12.6, 5.2))
	floor_decal("stain_1", row + Vector3(2.0, 0, -0.2), Vector2(5.0, 3.4), 10)
	floor_decal("stain_2", spot_in("pump_house", 10.6, 9.6), Vector2(3.2, 2.6), 200)
	floor_decal("stain_2", spot_in("pump_house", 2.6, 4.4), Vector2(2.6, 2.0), 80)


## Two boilers side by side with their fronts to the firing floor, on the
## west; their steam mains run to the south wall between the windows. The
## feed pumps and the gauges stand by the north wall, a feed tank in the
## north-east corner.
func _boiler_house() -> void:
	var high: float = _floor_plan["boiler_house"].height
	var south := spot_in("boiler_house", 0, 17.6).z
	boiler(spot_in("boiler_house", 14.0, 6.0), south, high, "K1")
	boiler(spot_in("boiler_house", 16.0, 12.0), south, high, "K2")
	for x: float in [6.6, 8.0]:
		pump(spot_in("boiler_house", x, 1.4), 0)
	gauge_board(spot_in("boiler_house", 7.3, 0.4, 1.75), Vector3.BACK)
	var header_z := spot_in("boiler_house", 0, 0.65).z
	tank(spot_in("boiler_house", 24.0, 2.4), 30, 120, header_z, -150)
	# What the burners are fed with, where a stray shot finds it.
	for spot: Vector3 in [spot_in("boiler_house", 8.6, 8.6), spot_in("boiler_house", 9.2, 9.0), spot_in("boiler_house", 9.4, 14.4), spot_in("boiler_house", 22.6, 9.2)]:
		fuel(spot)
	barrel(spot_in("boiler_house", 8.5, 9.4))
	barrel(spot_in("boiler_house", 23.3, 9.5))
	_room_islands("boiler_house", 5.0, ["crates", "crates", "barrier", "pallet", "barrels", "bags"], 2, 4)
	# Soot on the firing floor, and what dripped under the boilers.
	for z: float in [6.0, 12.0]:
		floor_decal("scorch_1", spot_in("boiler_house", 9.4 + (z - 6.0) / 3.0, z), Vector2(2.6, 2.6), z * 20.0)
	floor_decal("stain_1", spot_in("boiler_house", 14.0, 7.8), Vector2(5.0, 2.6), 5)
	floor_decal("stain_1", spot_in("boiler_house", 16.0, 13.8), Vector2(5.0, 2.6), 185)
	floor_decal("stain_2", spot_in("boiler_house", 24.0, 4.6), Vector2(3.0, 2.4), 40)


## Fuel oil in a tank along the west wall, and in drums, cans and bottles
## about the floor: a room to keep out of, or to shoot into.
func _fuel_store() -> void:
	vessel(spot_in("fuel_store", 1.6, 6.0), 0, 4.4, 0.8)
	for spot: Vector3 in [spot_in("fuel_store", 5.0, 9.6), spot_in("fuel_store", 5.7, 10.1), spot_in("fuel_store", 5.2, 10.6), spot_in("fuel_store", 9.4, 2.0), spot_in("fuel_store", 10.0, 2.5)]:
		fuel(spot)
	gas_bottle(spot_in("fuel_store", 10.9, 10.6))
	gas_bottle(spot_in("fuel_store", 11.2, 10.2))
	place("metal_jerrycan", spot_in("fuel_store", 3.6, 3.0), 30)
	place("metal_jerrycan", spot_in("fuel_store", 3.9, 2.6), -50)
	floor_decal("stain_1", spot_in("fuel_store", 4.0, 6.4), Vector2(3.4, 3.0), 60)
