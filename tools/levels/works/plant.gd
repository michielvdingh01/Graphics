extends "res://tools/levels/works/plan.gd"
## The plant of the works: the boiler with its pumps and gauges in the boiler
## house, the switchgear next door, and the compressors between the tool room
## and the workshop.


func _describe() -> void:
	# The boiler house.
	var south := spot_in("boiler_house", 0, 12.6).z
	boiler(spot_in("boiler_house", 7.0, 9.6), south, _floor_plan["boiler_house"].height)
	for z: float in [3.0, 4.8]:
		pump(spot_in("boiler_house", 1.0, z), 0)
	gauge_board(spot_in("boiler_house", 10.5, 0.4, 1.75), Vector3.BACK)
	fuel(spot_in("boiler_house", 1.6, 7.4))
	fuel(spot_in("boiler_house", 2.3, 7.1))
	floor_decal("stain_1", spot_in("boiler_house", 5.0, 7.4), Vector2(3.6, 3.0), 30)
	# The switch room: switchgear along the south wall, gauges by the door.
	for x: float in [3.2, 7.0]:
		cabinets(spot_in("switch_room", x, 12.1), 180)
	gauge_board(spot_in("switch_room", 9.6, 0.4, 1.75), Vector3.BACK)
	# The compressor room: two compressors side by side south of the way
	# through, and their bottles in the corner.
	for z: float in [6.1, 7.6]:
		place("old_military_compressor", spot_in("compressor_room", 6.2, z), 90)
	for spot: Vector3 in [spot_in("compressor_room", 8.2, 8.2), spot_in("compressor_room", 7.7, 8.45)]:
		gas_bottle(spot)
	floor_decal("stain_2", spot_in("compressor_room", 6.0, 6.9), Vector2(3.4, 2.6), 80)
