extends "res://tools/levels/works/plan.gd"
## What makes the workshop of the works a workshop: a lathe along the north
## wall, a press by the east wall, a tank in the corner feeding a header, and
## the fitters' benches against the south wall.


func _describe() -> void:
	lathe(spot_in("workshop", 10.5, 2.6))
	press(spot_in("workshop", 17.0, 11.0))
	var header_z := spot_in("workshop", 0, 0.65).z
	tank(spot_in("workshop", 18.4, 2.6), -20, -55, header_z)
	_m = Transform3D()
	_part = NO_COLLIDE
	var header := spot_in("workshop", 15.0, 0.65, 5.36)
	_bar(RUST, header, header + Vector3(5.6, 0, 0), 0.14, 16)
	_bar(RUST, header - Vector3(0.04, 0, 0), header, 0.25, 20)
	_bolt_circle(header - Vector3(0.04, 0, 0), Vector3.LEFT, 0.2, 8)
	_flange(RUST, header + Vector3(2.0, 0, 0), Vector3.RIGHT, 0.14)
	var south := spot_in("workshop", 0, 20.6).z
	workbench(spot_in("workshop", 6.0, 20.23), south)
	floor_decal("stain_1", spot_in("workshop", 17.0, 9.6), Vector2(4.5, 4.0), 30)
	floor_decal("stain_2", spot_in("workshop", 10.8, 3.6), Vector2(6.0, 3.0), 5)
