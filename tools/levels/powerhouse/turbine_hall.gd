extends "res://tools/levels/powerhouse/plan.gd"
## What the powerhouse is there for: two turbo-alternators in line down the
## middle of the hall, the crane that lifts their covers on its runway over
## them, and the steam main that feeds them along the south wall.

## The height of the corbels the crane's runway lies on.
const SEAT := 7.2


func _describe() -> void:
	turbine(spot_in("turbine_hall", 9.6, 12.0), 0, "G1")
	turbine(spot_in("turbine_hall", 23.4, 12.0), 0, "G2")
	# The runway beams of the crane lie on corbels along both long walls.
	for z: float in [0.7, 23.3]:
		for x: float in [2.5, 8.5, 14.5, 20.5, 26.5, 31.5]:
			box("concrete", spot_in("turbine_hall", x, z, SEAT - 0.25), Vector3(0.5, 0.5, 0.6), Vector3.ZERO, NO_COLLIDE)
	crane(spot_in("turbine_hall", 16.5, 12.0), 16.1, 11.6, SEAT, 11.0)
	# A lamp over the gangway beside the first machine: of those the builder
	# hung over this end of the hall, three are out, and the machine the
	# player sees first stood in the dark.
	var high: float = _floor_plan["turbine_hall"].height
	lamp(spot_in("turbine_hall", 8.5, 16.2, high - 0.9), high, true, true)

	# The steam main comes in through the west end of the south wall and runs
	# along it under the runway, with a branch down into the floor for each
	# machine.
	_m = Transform3D(Basis(), spot_in("turbine_hall", 0, 23.0))
	_part = NO_COLLIDE
	var main := 5.9
	_bar("tank", Vector3(4.6, main, 0), Vector3(21.0, main, 0), 0.2, 20)
	_line("tank", [Vector3(4.6, main, 0), Vector3(4.2, main, 0), Vector3(3.9, main, 0.3), Vector3(3.9, main, 0.75)], 0.2, 14)
	_bar("tank", Vector3(21.0, main, 0), Vector3(21.06, main, 0), 0.3, 20)
	_bolt_circle(Vector3(21.06, main, 0), Vector3.RIGHT, 0.25, 10)
	for x: float in [6.4, 20.2]:
		_line("tank", [Vector3(x, main, 0), Vector3(x, main - 0.15, 0), Vector3(x, main - 0.5, 0.2), Vector3(x, main - 0.8, 0.3), Vector3(x, 1.4, 0.3)], 0.15, 14)
		_bar("tank", Vector3(x, 1.4, 0.3), Vector3(x, -0.05, 0.3), 0.15, 14)
		_block(IRON, Vector3(x, 1.4, 0.3), Vector3(0.44, 0.46, 0.44), 0.07)
		_bar(BARE, Vector3(x, 1.4, 0.1), Vector3(x, 1.4, -0.3), 0.018, 8)
		_handwheel(Vector3(x, 1.4, -0.28), Vector3.FORWARD, 0.22)
		_flange(RUST, Vector3(x, 2.4, 0.3), Vector3.UP, 0.15)
	for x: float in [9.0, 13.5, 18.0]:
		_flange(RUST, Vector3(x, main, 0), Vector3.RIGHT, 0.2)
		_block(IRON, Vector3(x + 0.6, main - 0.32, 0.25), Vector3(0.08, 0.24, 0.5), 0.01)

	# Paint on the floor: a striped border round both machines, a gangway
	# down either side, and the way to the great door.
	var hall: Rect2 = _floor_plan["turbine_hall"].rect
	floor_paint_area(hall)
	for x: float in [9.6, 23.4]:
		var middle := spot_in("turbine_hall", x, 12.0)
		floor_frame(Rect2(middle.x - 5.75, middle.z - 2.3, 11.5, 4.6), PAINT_YELLOW, 0.16, PAINT_BLACK)
	for z: float in [8.2, 15.8]:
		floor_line(Vector2(hall.position.x + 2.6, hall.position.y + z), Vector2(hall.end.x - 2.0, hall.position.y + z))
	for x: float in [6.0, 16.5, 27.0]:
		floor_arrow(Vector2(hall.position.x + x, hall.position.y + 17.6), Vector2.RIGHT)
	floor_hatch(Rect2(hall.end.x - 3.4, hall.position.y + 9.2, 3.0, 5.6))
	floor_frame(Rect2(hall.end.x - 3.4, hall.position.y + 9.2, 3.0, 5.6))
