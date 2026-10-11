extends "res://tools/levels/wing/plan.gd"
## What makes the workshop of the wing a workshop: a lathe along the north
## wall, a press in the south-east corner and a tank by the door, feeding a
## header on the north wall. The room itself and what stands about in it are
## the builder's, see the plan.


func _describe() -> void:
	lathe(spot_in("workshop", 8.0, 2.5))
	press(spot_in("workshop", 13.0, 11.6))
	var header_z := spot_in("workshop", 0, 0.65).z
	tank(spot_in("workshop", 2.4, 2.5), 20, 55, header_z)
	_m = Transform3D()
	_part = NO_COLLIDE
	var header := spot_in("workshop", 0.4, 0.65, 5.36)
	_bar(RUST, header, header + Vector3(4.2, 0, 0), 0.14, 16)
	_bar(RUST, header + Vector3(4.2, 0, 0), header + Vector3(4.24, 0, 0), 0.25, 20)
	_bolt_circle(header + Vector3(4.24, 0, 0), Vector3.RIGHT, 0.2, 8)
	_flange(RUST, header + Vector3(2.9, 0, 0), Vector3.RIGHT, 0.14)
	floor_decal("stain_1", spot_in("workshop", 13.0, 10.2), Vector2(4.5, 4.0), 30)
	floor_decal("stain_2", spot_in("workshop", 8.4, 3.4), Vector2(6.0, 3.0), 5)
