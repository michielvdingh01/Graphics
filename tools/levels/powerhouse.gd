extends "res://tools/levels/powerhouse/plan.gd"
## The powerhouse: the power station of the works, eleven rooms laid out on a
## plan. Build with: tools/build_level.sh powerhouse
##
## The plan is in tools/levels/powerhouse/plan.gd, and next to it the files
## with what was put into a room by hand.


func _describe() -> void:
	_plan()
	build_rooms()
	for file: String in ["switchgear", "yard", "plant", "workshop", "turbine_hall", "outside"]:
		build(file)
