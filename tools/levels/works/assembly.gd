extends "res://tools/levels/works/plan.gd"
## What makes the assembly hall the largest room of the works: an overhead
## crane on its runway, a lathe and two presses, and two tanks in the corner.


func _describe() -> void:
	var middle := spot_in("assembly", 13.5, 15.0)
	# The runway beams of the crane lie on corbels along both long walls: on
	# every pier there is.
	for side: int in [NORTH, SOUTH]:
		for x in piers_along("assembly", side):
			box("concrete", _wall_spot("assembly", side, x, 0.3, 5.75), Vector3(0.5, 0.5, 0.6), Vector3.ZERO, NO_COLLIDE)
	crane(middle, 13.1, 14.6, 6.0, 5.0)
	lathe(spot_in("assembly", 16.0, 2.8))
	press(spot_in("assembly", 8.0, 6.0))
	press(spot_in("assembly", 16.0, 24.0))
	var header_z := spot_in("assembly", 0, 0.65).z
	tank(spot_in("assembly", 21.6, 2.6), 20, -55, header_z, -100)
	tank(spot_in("assembly", 24.8, 2.6), -10, 55, header_z)
	_m = Transform3D()
	_part = NO_COLLIDE
	var header := spot_in("assembly", 19.0, 0.65, 5.36)
	_bar(RUST, header, header + Vector3(7.6, 0, 0), 0.14, 16)
	_bar(RUST, header - Vector3(0.04, 0, 0), header, 0.25, 20)
	_bolt_circle(header - Vector3(0.04, 0, 0), Vector3.LEFT, 0.2, 8)
	_flange(RUST, header + Vector3(4.2, 0, 0), Vector3.RIGHT, 0.14)
	floor_decal("stain_1", spot_in("assembly", 8.0, 4.6), Vector2(4.5, 4.0), 30)
	floor_decal("stain_1", spot_in("assembly", 16.0, 22.6), Vector2(4.5, 4.0), 200)
	floor_decal("stain_2", spot_in("assembly", 16.4, 3.8), Vector2(6.0, 3.0), 5)
