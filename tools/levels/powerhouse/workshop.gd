extends "res://tools/levels/powerhouse/plan.gd"
## What makes the workshop of the powerhouse a workshop: a lathe along the
## north wall with a press beside it, the fitters' benches against the south
## wall, and the drills under the windows.


func _describe() -> void:
	lathe(spot_in("workshop", 6.8, 3.0))
	press(spot_in("workshop", 12.2, 3.4))
	var south := spot_in("workshop", 0, 13.6).z
	workbench(spot_in("workshop", 9.0, 13.23), south)
	place("old_drill_press", spot_in("workshop", 1.1, 6.6), 90)
	place("drill_press_01", spot_in("workshop", 1.1, 8.2), 90)
	place("metal_tool_chest", spot_in("workshop", 1.0, 11.4), 90)
	place("portable_welding_cart", spot_in("workshop", 13.4, 8.6), -100)
	floor_decal("stain_1", spot_in("workshop", 12.2, 5.2), Vector2(4.5, 3.6), 30)
	floor_decal("stain_2", spot_in("workshop", 7.0, 4.2), Vector2(6.0, 3.0), 5)
