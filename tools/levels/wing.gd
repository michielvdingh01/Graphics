extends "res://tools/levels/wing/plan.gd"
## The wing: five rooms laid out on a plan, the builder's work but for the
## machines. Build with: tools/build_level.sh wing
##
## The plan is in tools/levels/wing/plan.gd, and next to it a file for each
## room that has something in it that was put there by hand.


func _describe() -> void:
	_plan()
	build_rooms()
	for file: String in ["workshop", "plant", "outside"]:
		build(file)
