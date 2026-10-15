extends "res://tools/kit/street.gd"
## Twelfth drawer of the kit, see tools/kit.gd: the water of a town of
## canals. A canal between its quay walls, the steps down to it, and the
## bridges over it. A greybox, as tools/kit/street.gd says of all three
## drawers of the town.

## How far the water lies under the quays, and the bed of a canal: as deep as
## somebody wades through to the knee, since nobody swims in this game.
const WATER_BELOW := 1.1
const CANAL_BED := 1.7
## How far under the quay the landing of a set of steps lies: more than
## anyone on a navmesh climbs, and less than the player jumps. Whoever falls
## in gets out by the steps; nobody is sent in after him.
const LANDING_BELOW := 0.6


## The water of a canal over `area`, x and z, its bed under it and a quay
## wall along every side but those named in `open`: "n", "s", "w" and "e" for
## a side where the water runs on, into another canal or out of the level.
func canal(area: Rect2, open := "") -> void:
	var middle := area.get_center()
	box("concrete", Vector3(middle.x, -CANAL_BED - 0.25, middle.y), Vector3(area.size.x, 0.5, area.size.y), Vector3.ZERO, DETAIL)
	box("canal_water", Vector3(middle.x, -WATER_BELOW - 0.02, middle.y), Vector3(area.size.x, 0.04, area.size.y), Vector3.ZERO, DETAIL | NO_COLLIDE)
	if not open.contains("n"):
		quay_wall(area.position, Vector2(area.end.x, area.position.y))
	if not open.contains("s"):
		quay_wall(area.end, Vector2(area.position.x, area.end.y))
	if not open.contains("w"):
		quay_wall(Vector2(area.position.x, area.end.y), area.position)
	if not open.contains("e"):
		quay_wall(Vector2(area.end.x, area.position.y), area.end)


## The wall a quay stands on, along the edge of the water from `from` to
## `to`, x and z, as somebody sees it who is on the water: `from` on his left
## and `to` on his right. It is seen from the water alone, down to the bed,
## and throws its shadow as a box under the edge of the quay: without it, a
## lantern on the quay would light the water at the foot of the wall.
func quay_wall(from: Vector2, to: Vector2, mat := "quay_brick") -> void:
	var right := (to - from).normalized()
	var out := Vector2(-right.y, right.x)
	var length := from.distance_to(to)
	var middle := (from + to) * 0.5
	var frame := Transform3D(Basis(Vector3(right.x, 0, right.y), Vector3.UP, Vector3(out.x, 0, out.y)), Vector3(middle.x, 0, middle.y))
	# Its top lies a finger under the paving, not in it.
	var high := CANAL_BED - 0.02
	wall_face(mat, frame * Transform3D(Basis(), Vector3(0, -0.02 - high * 0.5, 0)), Vector2(length, high))
	_collide_box(frame * Transform3D(Basis(), Vector3(0, -CANAL_BED * 0.5 - 0.25, -0.3)), Vector3(length, CANAL_BED + 0.5, 0.6), _surface(mat))
	shadow_box(frame * Transform3D(Basis(), Vector3(0, -CANAL_BED * 0.5 - 0.25, -0.3)), Vector3(length, CANAL_BED + 0.5, 0.6))


## Steps down to the water at `at` on the edge of a quay, the water lying the
## way `yaw_deg` looks from there (0 looks along +Z): a landing just under
## the quay and a ramp from it to the bed, along the wall.
func water_steps(at: Vector3, yaw_deg: float) -> void:
	var frame := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	var run := (CANAL_BED - LANDING_BELOW) / tan(deg_to_rad(28.0))
	_local_box("concrete", frame, Vector3(0, -LANDING_BELOW - 0.15, 0.7), Vector3(2.2, 0.3, 1.4), CASTS)
	var slope := Transform3D(Basis(Vector3.BACK, deg_to_rad(-28.0)), Vector3(1.1 + run * 0.5, -(CANAL_BED + LANDING_BELOW) * 0.5 - 0.13, 0.7))
	_box("concrete", frame * slope, Vector3(run / cos(deg_to_rad(28.0)), 0.3, 1.4), CASTS)


## A bridge over a canal from `from` to `to`, the middles of its two ends
## where they meet the quays, `width` wide. Its deck, `deck` thick, rises to
## `rise` over the quays at the crown, and it has a parapet along either
## side. It rests on the quay walls and on nothing in the water, so that
## whoever wades through the canal can go under it: upright under the
## crown wherever the underside is 0.2 m or more over the quays, since the
## bed lies CANAL_BED down and the player stands 1.8 m tall, and stooped
## nearer the ends. A bridge without a rise carries a quay over the mouth of
## a canal; under that one only stooped. `parapets` are the sides that have
## one: -1 for the left of somebody who walks from `from` to `to`, 1 for his
## right. A quay carried over a mouth has one only on the side of the
## canal that runs into it, so that another bridge can come down on it.
func bridge(from: Vector3, to: Vector3, width: float, rise := 1.2, mat := "quay_brick", deck := 0.4, parapets: Array[float] = [-1.0, 1.0]) -> void:
	var along := (to - from).normalized()
	var across := along.cross(Vector3.UP)
	var span := from.distance_to(to)
	var parts := 8
	for i in parts:
		var t0 := float(i) / parts
		var t1 := float(i + 1) / parts
		# A flat arch: nought at either end, `rise` in the middle.
		var a := from + along * span * t0 + Vector3.UP * rise * (1.0 - pow(2.0 * t0 - 1.0, 2.0))
		var b := from + along * span * t1 + Vector3.UP * rise * (1.0 - pow(2.0 * t1 - 1.0, 2.0))
		var lie := Basis.looking_at(b - a, Vector3.UP)
		var middle := (a + b) * 0.5
		_box("cobbles", Transform3D(lie, middle + lie.y * -deck * 0.5), Vector3(width, deck, a.distance_to(b) + 0.06), CASTS)
		for side: float in parapets:
			_box(mat, Transform3D(lie, middle + across * side * (width * 0.5 - 0.2) + lie.y * 0.45), Vector3(0.4, 0.9, a.distance_to(b) + 0.06), CASTS)
