extends "res://tools/kit/plant.gd"
## Fourth drawer of the kit, see tools/kit.gd: what a building is fitted out
## with.

## Double steel doors in a doorway 1.6 m wide. `frame` stands on the floor in
## the middle of the wall, with the wall along its Z and its X pointing the
## way the leaves swing; `thick` is how thick the wall is. The angles are how
## far the leaf on the -Z side and the one on the +Z side have swung, 0 for
## shut. With a `number`, a plate beside the door on the other side carries it.
func doorway(frame: Transform3D, thick: float, first_deg: float, second_deg: float, number := "") -> void:
	var half := 0.8
	var top := 2.2
	# A frame of folded steel lines the opening, a little proud of the wall.
	for side: float in [-1.0, 1.0]:
		_local_box("door", frame, Vector3(0, top * 0.5, side * (half - 0.025)), Vector3(thick + 0.06, top, 0.05), NO_COLLIDE)
	_local_box("door", frame, Vector3(0, top - 0.025, 0), Vector3(thick + 0.06, 0.05, half * 2.0 - 0.1), NO_COLLIDE)
	var leaf := 0.045
	for side: float in [-1.0, 1.0]:
		var swing := deg_to_rad(first_deg if side < 0.0 else second_deg)
		# From the hinge to the free edge: along the wall when the leaf is shut.
		var along := Vector3(sin(swing), 0.0, -side * cos(swing))
		# The hinges sit on the outside of the frame, so that an open leaf
		# stands clear of the doorway: the way through is no wider than the
		# robots need.
		var hinge := Vector3(thick * 0.5 + 0.03 + leaf * 0.5, 0.0, side * (half + leaf * 0.5 + 0.003))
		_leaf(frame * Transform3D(Basis(along, Vector3.UP, along.cross(Vector3.UP)), hinge), half - 0.055, leaf)
	if number == "":
		return
	var plate := Vector3(-thick * 0.5, 1.62, half + 0.24)
	_local_box("bare_steel", frame, plate - Vector3(0.002, 0, 0), Vector3(0.004, 0.13, 0.17), DETAIL | NO_COLLIDE)
	label(number, frame * (plate - Vector3(0.004, 0, 0)), frame.basis * Vector3.LEFT, 0.09, Color(0.04, 0.04, 0.04), 0.01)


## One leaf of a steel door. `leaf` has the foot of its hinge edge for origin,
## X towards the free edge and Z out of its face. It has a pane of glass at
## eye height, a kick plate and a lever handle on either side, and three
## hinges.
func _leaf(leaf: Transform3D, width: float, thick: float) -> void:
	var small := DETAIL | NO_COLLIDE
	var foot := 0.012
	var top := 2.16
	var pane := Vector3(width - 0.23, 1.56, 0.0)
	var glass := Vector2(0.2, 0.5)
	# The leaf is a frame around the pane: a rail below and one above it, and
	# a stile to either side.
	var sill := pane.y - glass.y * 0.5
	var head := pane.y + glass.y * 0.5
	var left := pane.x - glass.x * 0.5
	var right := pane.x + glass.x * 0.5
	_local_box("door", leaf, Vector3(width * 0.5, (foot + sill) * 0.5, 0), Vector3(width, sill - foot, thick), NO_COLLIDE)
	_local_box("door", leaf, Vector3(width * 0.5, (head + top) * 0.5, 0), Vector3(width, top - head, thick), NO_COLLIDE)
	_local_box("door", leaf, Vector3(left * 0.5, pane.y, 0), Vector3(left, glass.y, thick), NO_COLLIDE)
	_local_box("door", leaf, Vector3((right + width) * 0.5, pane.y, 0), Vector3(width - right, glass.y, thick), NO_COLLIDE)
	_local_box("glass", leaf, pane, Vector3(glass.x, glass.y, 0.008), GLASS | NO_COLLIDE)
	_collide_box(leaf * Transform3D(Basis(), Vector3(width * 0.5, (foot + top) * 0.5, 0)), Vector3(width, top - foot, thick), "metal")
	for face: float in [-1.0, 1.0]:
		var out := Vector3(0, 0, face * thick * 0.5)
		# The beading that holds the glass.
		for edge: float in [-1.0, 1.0]:
			_local_box("dark_steel", leaf, pane + out + Vector3(edge * (glass.x * 0.5 + 0.008), 0, 0), Vector3(0.016, glass.y + 0.032, 0.014), small)
			_local_box("dark_steel", leaf, pane + out + Vector3(0, edge * (glass.y * 0.5 + 0.008), 0), Vector3(glass.x, 0.016, 0.014), small)
		_local_box("bare_steel", leaf, Vector3(width * 0.5, 0.15, 0) + out, Vector3(width - 0.06, 0.22, 0.004), small)
		var grip := Vector3(width - 0.075, 1.05, 0) + out
		_local_box("bare_steel", leaf, grip, Vector3(0.045, 0.17, 0.008), small)
		var stem := grip + Vector3(0, 0.03, face * 0.05)
		rod("bare_steel", leaf * (grip + Vector3(0, 0.03, 0)), leaf * stem, 0.009, small, 8)
		rod("bare_steel", leaf * (stem + Vector3(0.009, 0, 0)), leaf * (stem - Vector3(0.12, 0, 0)), 0.009, small, 8)
	for y: float in [0.25, 1.08, 1.92]:
		rod("dark_steel", leaf * Vector3(-0.014, y - 0.05, 0), leaf * Vector3(-0.014, y + 0.05, 0), 0.012, small, 8)


## What runs under the ceiling of a corridor along Z, from `z0` to `z1`: a
## ventilation duct of galvanised sheet above `duct_x`, with a grille at each
## of `grilles`, and a cable ladder above `ladder_x` with the cables that feed
## the rooms. Conduit comes down from the ladder to a switch beside each of
## `doors`, which are named by the middle of their doorway and stand in the
## wall on the +X side of the ladder, whose face is at `wall_x`.
func corridor_services(z0: float, z1: float, ceiling: float, duct_x: float, ladder_x: float, grilles: Array, wall_x: float, doors: Array) -> void:
	var small := DETAIL | NO_COLLIDE
	var length := z1 - z0 - 0.02
	var mid := (z0 + z1) * 0.5

	# The duct, 400 by 280 mm, in lengths that are flanged together and hung
	# from the slab on a strap and two threaded rods.
	var duct := Vector3(duct_x, ceiling - 0.2, mid)
	box("galvanised", duct, Vector3(0.4, 0.28, length), Vector3.ZERO, NO_COLLIDE)
	var z := z0 + 0.7
	while z < z1 - 0.2:
		box("galvanised", Vector3(duct.x, duct.y, z), Vector3(0.46, 0.34, 0.03), Vector3.ZERO, small)
		box("dark_steel", Vector3(duct.x, duct.y - 0.146, z + 0.12), Vector3(0.5, 0.012, 0.03), Vector3.ZERO, small)
		for side: float in [-1.0, 1.0]:
			var strap := Vector3(duct.x + side * 0.235, duct.y - 0.146, z + 0.12)
			rod("dark_steel", strap, Vector3(strap.x, ceiling, strap.z), 0.005, small, 6)
		z += 1.5
	for grille: float in grilles:
		var under := Vector3(duct.x, duct.y - 0.141, grille)
		box("dark_steel", under, Vector3(0.3, 0.004, 0.5), Vector3.ZERO, small)
		for i in 8:
			box("galvanised", under + Vector3(0, -0.012, (i - 3.5) * 0.058), Vector3(0.28, 0.003, 0.04), Vector3(28, 0, 0), small)

	# The cable ladder: two rails, a rung every 300 mm, a hanger every 1.5 m.
	var ladder := Vector3(ladder_x, ceiling - 0.3, mid)
	for side: float in [-1.0, 1.0]:
		box("galvanised", ladder + Vector3(side * 0.15, 0.025, 0), Vector3(0.012, 0.05, length), Vector3.ZERO, small)
	z = z0 + 0.15
	var rung := 0
	while z < z1:
		box("galvanised", Vector3(ladder.x, ladder.y + 0.008, z), Vector3(0.3, 0.012, 0.025), Vector3.ZERO, small)
		if rung % 5 == 2:
			for side: float in [-1.0, 1.0]:
				rod("dark_steel", Vector3(ladder.x + side * 0.165, ladder.y, z), Vector3(ladder.x + side * 0.165, ceiling, z), 0.005, small, 6)
		z += 0.3
		rung += 1
	# Cables of several gauges lie on it side by side. Each is one long
	# sliver of a thing, which is what a tiled renderer likes least, so there
	# are few of them and they have few sides.
	var lay := -0.11
	for gauge: float in [0.018, 0.013, 0.024, 0.015]:
		lay += gauge
		var cable := Vector3(ladder.x + lay, ladder.y + 0.014 + gauge, 0)
		rod("rubber", cable + Vector3(0, 0, z0 + 0.01), cable + Vector3(0, 0, z1 - 0.01), gauge, small, 5)
		lay += gauge + 0.012

	# Conduit from the ladder across to the wall and down to a switch.
	for door_z: float in doors:
		var drop_z := door_z - 1.08
		var from := Vector3(ladder.x + 0.15, ladder.y + 0.03, drop_z)
		hose("galvanised", PackedVector3Array([
			from, Vector3(wall_x - 0.08, from.y, drop_z), Vector3(wall_x - 0.02, from.y - 0.02, drop_z),
			Vector3(wall_x, from.y - 0.08, drop_z), Vector3(wall_x, 1.33, drop_z),
		]), 0.011, small, 6)
		for y: float in [2.6, 1.9]:
			box("galvanised", Vector3(wall_x + 0.006, y, drop_z), Vector3(0.036, 0.02, 0.05), Vector3.ZERO, small)
		rounded_box("galvanised", Transform3D(Basis(), Vector3(wall_x - 0.005, 1.27, drop_z)), Vector3(0.06, 0.12, 0.08), 0.008, small)
		box("rubber", Vector3(wall_x - 0.04, 1.27, drop_z), Vector3(0.012, 0.035, 0.018), Vector3(0, 0, 14), small)


## Notice board on the corridor wall, with what was pinned to it when the
## place closed; `at` is the middle of its back, on a wall that faces +X.
func notice_board(at: Vector3) -> void:
	var small := DETAIL | NO_COLLIDE
	var size := Vector2(1.15, 0.8)
	box("wood", at + Vector3(0.008, 0, 0), Vector3(0.016, size.y, size.x), Vector3.ZERO, small)
	for edge: float in [-1.0, 1.0]:
		box("galvanised", at + Vector3(0.013, edge * size.y * 0.5, 0), Vector3(0.026, 0.03, size.x + 0.03), Vector3.ZERO, small)
		box("galvanised", at + Vector3(0.013, 0, edge * size.x * 0.5), Vector3(0.026, size.y, 0.03), Vector3.ZERO, small)
	# Sheets of A4 and smaller, none of them straight: [along the board, up, tilt in degrees, scale].
	var sheets: Array = [
		[-0.4, 0.14, 2.0, 1.0], [-0.15, 0.17, -1.5, 1.0], [0.11, 0.12, 1.0, 1.0], [0.4, 0.15, -3.0, 1.0],
		[-0.36, -0.2, -2.5, 0.7], [-0.08, -0.17, 4.0, 1.0], [0.25, -0.2, -14.0, 0.7], [0.44, -0.22, 2.0, 0.5],
	]
	for i in sheets.size():
		var sheet: Array = sheets[i]
		var paper: Vector3 = Vector3(0.0012, 0.297, 0.21) * float(sheet[3])
		var xf := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(sheet[2])), at + Vector3(0.017 + i * 0.0004, sheet[1], sheet[0]))
		_box("paper", xf, paper, small)
		_box("enamel_red" if i % 3 == 0 else "bare_steel", xf * Transform3D(Basis(), Vector3(0.003, paper.y * 0.5 - 0.015, 0)), Vector3(0.005, 0.009, 0.009), small)
