extends "res://tools/levels/works/plan.gd"
## The works: the grounds between the factory and the depot, twenty-three
## rooms laid out on a plan. Build with: tools/build_level.sh works
##
## The plan is in tools/levels/works/plan.gd, and next to it the files with
## what was put into a room by hand.


func _describe() -> void:
	_plan()
	build_rooms()
	for file: String in ["workshop", "assembly", "plant", "outside"]:
		build(file)
