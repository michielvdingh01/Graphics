extends "res://tools/levels/wing/plan.gd"
## What makes the boiler room of the wing a boiler room: the boiler along its
## south side, two feed pumps by the east wall and a board of gauges by the
## door to the workshop.


func _describe() -> void:
	var south := spot_in("plant", 0, 8.6).z
	boiler(spot_in("plant", 5.0, 6.2), south, _floor_plan["plant"].height)
	for z: float in [1.5, 3.3]:
		pump(spot_in("plant", 8.95, z), 0)
	gauge_board(spot_in("plant", 2.2, 0.4, 1.75), Vector3.BACK)
	# Fuel for the burner, at its end of the boiler.
	fuel(spot_in("plant", 0.9, 4.2))
	fuel(spot_in("plant", 1.5, 3.9))
	floor_decal("stain_1", spot_in("plant", 4.0, 4.6), Vector2(3.6, 3.0), 30)
