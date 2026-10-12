extends "res://tools/kit/land.gd"
## Tenth drawer of the kit, see tools/kit.gd: what an army leaves standing in
## the field. Walls of sandbags, tents and nets, wire, a barrier and its
## sentry box, a pillbox, and the vehicles it came in. All of it stands on
## the ground as it lies (see tools/kit/land.gd): a spot is given as x and z,
## and its height is asked.
##
## Nothing here has a lightmap: it stands under an open sky, lit by the sun
## and the sky as it is. What is cloth, a tent or a net, keeps the sun off
## the ground under it without being a collider, and says so with
## casts_shade(): somebody under it stands in the shade.

const CANVAS := "canvas"
const SACKING := "sandbag"
const ARMY := "army_green"
## A filled sandbag as it lies in a wall: along the wall, high, and deep.
const SACK := Vector3(0.6, 0.14, 0.3)
## Thin things that are in nobody's way.
const SLIGHT := DETAIL | NO_COLLIDE
## The vehicles of tools/models/vehicles.gd: what of each is in the way, as
## [middle, size] of a box in the model, and over how many metres of ground
## it rests.
const VEHICLES := {
	"jeep": {"span": 1.2, "boxes": [[Vector3(0, 0.75, 0.05), Vector3(1.6, 1.0, 3.4)]]},
	"truck": {"span": 2.0, "boxes": [[Vector3(0, 1.3, -2.1), Vector3(2.2, 1.9, 2.5)], [Vector3(0, 1.75, 1.55), Vector3(2.4, 2.8, 4.0)]]},
	"tank": {"span": 2.4, "boxes": [[Vector3(0, 0.85, 0), Vector3(3.0, 1.5, 6.0)], [Vector3(0, 2.0, 0.1), Vector3(2.0, 0.85, 3.0)], [Vector3(0, 2.0, -3.3), Vector3(0.3, 0.3, 3.6)]]},
	"tank_b": {"span": 2.4, "boxes": [[Vector3(0, 0.85, 0), Vector3(3.0, 1.5, 6.0)], [Vector3(0, 2.0, 0.0), Vector3(2.6, 0.85, 2.8)]]},
}

## The node the vehicles of the level stand under.
var _vehicles: Node3D


func _surface(mat: String) -> String:
	match mat:
		CANVAS, SACKING, "camo_net":
			return "soft"
	return super(mat)


# --- Sandbags ----------------------------------------------------------------------


## A wall of sandbags from `from` to `to` (x and z), `layers` bags high, laid
## as bricks are and following the ground. Seven layers is a wall to kneel
## behind.
func sandbags(from: Vector2, to: Vector2, layers := 7) -> void:
	var length := from.distance_to(to)
	var way := (to - from) / length
	var along := Vector3(way.x, 0, way.y)
	var count := maxi(1, roundi(length / SACK.x))
	var pitch := length / count
	for layer in layers:
		var shift := 0.5 if layer % 2 == 1 else 0.0
		for i in range(-1 if shift > 0.0 else 0, count):
			var run := (i + 0.5 + shift) * pitch
			if run < 0.15 or run > length - 0.15:
				continue
			var at := from + way * run
			var turn := Basis(Vector3.UP, _clutter_rng.randf_range(-0.07, 0.07))
			var across := turn * Vector3.UP.cross(along)
			var middle := ground(at.x, at.y, layer * SACK.y - 0.02) + across * _clutter_rng.randf_range(-0.025, 0.025)
			_sack(Transform3D(Basis(across, Vector3.UP, turn * along), middle), pitch * _clutter_rng.randf_range(0.9, 0.98))
	var low := minf(ground_height(from.x, from.y), ground_height(to.x, to.y)) - 0.5
	var high := maxf(ground_height(from.x, from.y), ground_height(to.x, to.y)) + layers * SACK.y
	var middle := (from + to) * 0.5
	_collide_box(Transform3D(Basis.looking_at(along), Vector3(middle.x, (low + high) * 0.5, middle.y)), Vector3(SACK.z + 0.04, high - low, length), "soft")


## One sandbag: lying along the Z of `xf` with its underside at the origin.
## A sack that was filled and thrown down: flat underneath, round on top,
## and pinched at both ends where it was tied and folded. No two are quite
## the same shade.
func _sack(xf: Transform3D, length: float) -> void:
	var st := _tool(SACKING, SLIGHT, xf.origin)
	var half := SACK.z * 0.5
	var rise := SACK.y * 0.54
	var shade := _clutter_rng.randf_range(0.72, 1.0)
	var tint := Color(shade, shade * _clutter_rng.randf_range(0.94, 1.0), shade * _clutter_rng.randf_range(0.86, 0.98))
	var sides := 8
	var rings: Array[Vector2] = [Vector2(-0.5, 0.45), Vector2(-0.4, 0.9), Vector2(0.0, 1.0), Vector2(0.4, 0.9), Vector2(0.5, 0.45)]
	var before: Array[Vector3] = []
	var before_out: Array[Vector3] = []
	for ring in rings.size():
		var around: Array[Vector3] = []
		var out: Array[Vector3] = []
		for s in sides + 1:
			var turn := TAU * s / sides
			# Squarer than a circle, and flatter underneath than on top.
			var x := signf(cos(turn)) * pow(absf(cos(turn)), 0.6) * half * rings[ring].y
			var y := rise + signf(sin(turn)) * pow(absf(sin(turn)), 0.6) * rise * rings[ring].y * (1.0 if sin(turn) > 0.0 else 0.92)
			around.append(xf * Vector3(x, y, rings[ring].x * length))
			out.append(xf.basis * Vector3(cos(turn), sin(turn), rings[ring].x * 0.6).normalized())
		if ring > 0:
			for s in sides:
				var u0 := float(s) / sides * 0.9
				var u1 := float(s + 1) / sides * 0.9
				var v0 := (rings[ring - 1].x + 0.5) * length
				var v1 := (rings[ring].x + 0.5) * length
				_quad(st, [before[s], before[s + 1], around[s + 1], around[s]], [before_out[s], before_out[s + 1], out[s + 1], out[s]],
					[Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)], [tint, tint, tint, tint])
		before = around
		before_out = out
	# Its two ends.
	for end: int in [0, rings.size() - 1]:
		var face := xf.basis * Vector3(0, 0, signf(rings[end].x))
		var middle := xf * Vector3(0, rise, rings[end].x * length)
		for s in sides:
			var turn := TAU * s / sides
			var next := TAU * (s + 1) / sides
			var a := xf * Vector3(signf(cos(turn)) * pow(absf(cos(turn)), 0.6) * half * rings[end].y, rise + signf(sin(turn)) * pow(absf(sin(turn)), 0.6) * rise * rings[end].y, rings[end].x * length)
			var b := xf * Vector3(signf(cos(next)) * pow(absf(cos(next)), 0.6) * half * rings[end].y, rise + signf(sin(next)) * pow(absf(sin(next)), 0.6) * rise * rings[end].y, rings[end].x * length)
			var corners := [middle, a, b] if end > 0 else [middle, b, a]
			_tri(st, corners, [face, face, face], [Vector2(0.45, 0.1), Vector2(0.4, 0.0), Vector2(0.5, 0.0)], [tint, tint, tint])


## A post of sandbags to shoot from: a wall `width` wide across the way
## `yaw_deg` faces (0 looks along +Z) with a wing `depth` long at either end,
## open at the back.
func sandbag_post(at: Vector2, yaw_deg: float, width := 4.2, depth := 2.4, layers := 7) -> void:
	var ahead := Vector2(0, 1).rotated(-deg_to_rad(yaw_deg))
	var side := ahead.orthogonal()
	var front := at + ahead * depth * 0.5
	sandbags(front - side * width * 0.5, front + side * width * 0.5, layers)
	for end: float in [-1.0, 1.0]:
		var corner := front + side * end * (width * 0.5 - 0.15) - ahead * 0.3
		sandbags(corner, corner - ahead * depth, layers)
	cover("earth", at, maxf(width, depth) * 0.6, 0.8)


## A ring of sandbags `radius` across its middle, with a way in on the side
## `opens_deg` (0 is +Z): a pit for a gun or a look-out.
func sandbag_ring(at: Vector2, radius: float, opens_deg: float, layers := 6) -> void:
	var sides := maxi(8, roundi(TAU * radius / 1.8))
	for i in sides:
		var from := deg_to_rad(opens_deg) + TAU * (i + 0.5) / sides
		var to := deg_to_rad(opens_deg) + TAU * (i + 1.5) / sides
		if i == sides - 1:
			continue
		sandbags(at + Vector2(sin(from), cos(from)) * radius, at + Vector2(sin(to), cos(to)) * radius, layers)
	cover("earth", at, radius + 0.5, 0.8)


# --- Cloth -------------------------------------------------------------------------


## A sheet of cloth between four corners, counter-clockwise seen from the
## side it faces, that hangs `sag` lower in its middle.
func _sheet(mat: String, corners: Array, sag := 0.0, across := 4, down := 2) -> void:
	var first: Vector3 = corners[0]
	var second: Vector3 = corners[1]
	var third: Vector3 = corners[2]
	var fourth: Vector3 = corners[3]
	var st := _tool(mat, SLIGHT, (first + third) * 0.5)
	var wide := first.distance_to(second)
	var high := first.distance_to(fourth)
	var spots: Array[Vector3] = []
	for j in down + 1:
		for i in across + 1:
			var u := float(i) / across
			var v := float(j) / down
			spots.append(first.lerp(second, u).lerp(fourth.lerp(third, u), v) + Vector3.DOWN * sag * sin(PI * u) * sin(PI * v))
	for j in down:
		for i in across:
			var a := spots[j * (across + 1) + i]
			var b := spots[j * (across + 1) + i + 1]
			var c := spots[(j + 1) * (across + 1) + i + 1]
			var d := spots[(j + 1) * (across + 1) + i]
			var normal := (b - a).cross(d - a).normalized()
			var u0 := wide * i / across
			var u1 := wide * (i + 1) / across
			var v0 := -high * j / down
			var v1 := -high * (j + 1) / down
			_quad(st, [a, b, c, d], [normal, normal, normal, normal], [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)])


## A tent on the ground at `at`, its ridge along the X of the way it is
## turned: `size` is its length, the height of its ridge and its depth. The
## long side that faces `yaw_deg` (0 looks along +Z) is rolled up; the back
## and the two ends are shut, and those stop a look and a shot. Returns where
## it stands, for whatever goes into it: X along the ridge, +Z out of the
## open side, the origin on the ground in its middle.
func tent(at: Vector2, yaw_deg: float, size := Vector3(7.0, 3.1, 5.0)) -> Transform3D:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y))
	var half := size.x * 0.5
	var deep := size.z * 0.5
	var eaves := 1.8
	var over := 0.3
	# The roof: a panel either side of the ridge, hanging a little between poles.
	for side: float in [-1.0, 1.0]:
		var ridge_a := xf * Vector3(-half - over, size.y, 0)
		var ridge_b := xf * Vector3(half + over, size.y, 0)
		var eave_a := xf * Vector3(-half - over, eaves - 0.12, side * (deep + over))
		var eave_b := xf * Vector3(half + over, eaves - 0.12, side * (deep + over))
		_sheet(CANVAS, [eave_a, eave_b, ridge_b, ridge_a] if side > 0.0 else [eave_b, eave_a, ridge_a, ridge_b], 0.07, 6, 3)
	# The ends, and the back.
	for end: float in [-1.0, 1.0]:
		var x := end * half
		_sheet(CANVAS, [xf * Vector3(x, 0, -deep * end), xf * Vector3(x, 0, deep * end), xf * Vector3(x, eaves, deep * end), xf * Vector3(x, eaves, -deep * end)], 0.0, 3, 1)
		var st := _tool(CANVAS, SLIGHT, xf * Vector3(x, eaves, 0))
		var out := xf.basis * Vector3(end, 0, 0)
		_tri(st, [xf * Vector3(x, eaves, -deep * end), xf * Vector3(x, eaves, deep * end), xf * Vector3(x, size.y, 0)], [out, out, out], [Vector2(0, 0), Vector2(size.z, 0), Vector2(deep, -(size.y - eaves))])
		_collide_box(xf * Transform3D(Basis(), Vector3(x, eaves * 0.5, 0)), Vector3(0.06, eaves, size.z), "soft")
	_sheet(CANVAS, [xf * Vector3(half, 0, -deep), xf * Vector3(-half, 0, -deep), xf * Vector3(-half, eaves, -deep), xf * Vector3(half, eaves, -deep)], 0.0, 6, 1)
	_collide_box(xf * Transform3D(Basis(), Vector3(0, eaves * 0.5, -deep)), Vector3(size.x, eaves, 0.06), "soft")
	# What the front was rolled up into, under its eave.
	rod(CANVAS, xf * Vector3(-half, eaves - 0.1, deep), xf * Vector3(half, eaves - 0.1, deep), 0.09, SLIGHT, 8)
	# Poles: three under the ridge and one at every corner and half-way, with
	# the ridge pole on them, and a guy from every pole of the sides.
	for x: float in [-half, 0.0, half]:
		# No pole under the middle of the ridge: that is where a table stands.
		if x != 0.0:
			cylinder("wood", xf * Vector3(x, 0, 0), 0.05, size.y, SLIGHT, Vector3.ZERO, -1.0, 6)
		for side: float in [-1.0, 1.0]:
			var head := xf * Vector3(x, eaves, side * deep)
			cylinder("wood", xf * Vector3(x, 0, side * deep), 0.035, eaves, SLIGHT, Vector3.ZERO, -1.0, 6)
			var peg := xf * Vector3(x * 1.08, 0, side * (deep + 1.7))
			rod(SACKING, head, on_ground(peg, 0.05), 0.008, SLIGHT, 4)
			cylinder("wood", on_ground(peg, -0.05), 0.02, 0.3, SLIGHT, Vector3(side * 20, 0, 0), -1.0, 5)
	rod("wood", xf * Vector3(-half - over, size.y - 0.03, 0), xf * Vector3(half + over, size.y - 0.03, 0), 0.04, SLIGHT, 6)
	casts_shade(xf * Vector3(0, size.y * 0.75, 0), Vector3(half + 0.4, 0.9, half + 0.4) if absf(fposmod(yaw_deg, 180.0) - 90.0) < 45.0 else Vector3(half + 0.4, 0.9, deep + 0.4))
	cover("earth", at, maxf(half, deep) + 1.6, 0.9)
	return xf


## A shelter half pitched low over two poles, for two men to sleep under:
## its ridge along the X of the way it is turned.
func bivouac(at: Vector2, yaw_deg: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y))
	for side: float in [-1.0, 1.0]:
		var corners := [xf * Vector3(-1.1, 0.02, side * 0.95), xf * Vector3(1.1, 0.02, side * 0.95), xf * Vector3(1.1, 1.05, 0), xf * Vector3(-1.1, 1.05, 0)]
		if side < 0.0:
			corners = [corners[1], corners[0], corners[3], corners[2]]
		_sheet(CANVAS, corners, 0.03, 2, 1)
	for x: float in [-1.1, 1.1]:
		cylinder("wood", xf * Vector3(x, 0, 0), 0.025, 1.08, SLIGHT, Vector3.ZERO, -1.0, 5)
		rod(SACKING, xf * Vector3(x, 1.05, 0), xf * Vector3(x * 2.1, 0.05, 0), 0.006, SLIGHT, 4)
	_collide_box(xf * Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(2.2, 0.9, 1.5), "soft")


## A camouflage net over the ground at `at`, `size` long (along the X of the
## way it is turned) and deep, `height` up on poles and pegged down along its
## long sides. Whoever stands under it stands in the shade.
func camo_net(at: Vector2, yaw_deg: float, size: Vector2, height := 3.3) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), Vector3(at.x, 0, at.y))
	var half := size * 0.5
	var corner := func(x: float, z: float, lift: float) -> Vector3:
		var spot := xf * Vector3(x, 0, z)
		return ground(spot.x, spot.z, lift)
	_sheet("camo_net", [corner.call(-half.x, half.y, height), corner.call(half.x, half.y, height), corner.call(half.x, -half.y, height), corner.call(-half.x, -half.y, height)], 0.5, 6, 4)
	for side: float in [-1.0, 1.0]:
		var skirt := [corner.call(-half.x, side * (half.y + 2.2), 0.1), corner.call(half.x, side * (half.y + 2.2), 0.1), corner.call(half.x, side * half.y, height), corner.call(-half.x, side * half.y, height)]
		if side < 0.0:
			skirt = [skirt[1], skirt[0], skirt[3], skirt[2]]
		_sheet("camo_net", skirt, 0.25, 6, 2)
	for x: float in [-half.x, 0.0, half.x]:
		for z: float in [-half.y, half.y]:
			var foot: Vector3 = corner.call(x, z, 0.0)
			cylinder("wood", foot, 0.04, height + 0.05, SLIGHT, Vector3.ZERO, -1.0, 6)
	var middle: Vector3 = corner.call(0.0, 0.0, height - 0.3)
	var reach := maxf(half.x, half.y) if absf(fposmod(yaw_deg, 90.0) - 45.0) < 20.0 else 0.0
	casts_shade(middle, Vector3(maxf(half.x, reach) + 0.5, 0.7, maxf(half.y, reach) + 1.2) if absf(fposmod(yaw_deg, 180.0) - 90.0) > 45.0 else Vector3(maxf(half.y, reach) + 1.2, 0.7, maxf(half.x, reach) + 0.5))


# --- Wire and barriers ---------------------------------------------------------------


## A fence of barbed wire along `path`: posts with five strands between
## them. It shuts a level in, and is as solid to the game as a wall: there
## is nothing beyond it to shoot at.
func wire_fence(path: Array, height := 1.7) -> void:
	var way := curve(path, 3.0)
	for i in way.size():
		var foot := ground(way[i].x, way[i].y, -0.3)
		cylinder("wood", foot, 0.05, height + 0.4, SLIGHT, Vector3(_clutter_rng.randf_range(-3, 3), 0, _clutter_rng.randf_range(-3, 3)), -1.0, 6)
		if i == 0:
			continue
		var before := ground(way[i - 1].x, way[i - 1].y)
		var here := ground(way[i].x, way[i].y)
		for strand in 5:
			var lift := Vector3.UP * (0.25 + strand * (height - 0.3) / 4.0)
			beam("dark_steel", before + lift, here + lift, 0.012, SLIGHT)
		var middle := (before + here) * 0.5
		_collide_box(Transform3D(Basis.looking_at(Vector3(here.x - before.x, 0, here.z - before.z)), middle + Vector3.UP * (height * 0.5 + 0.3)), Vector3(0.12, height + 2.2, before.distance_to(here) + 0.1), "metal")


## Coils of barbed wire from `from` to `to`, chest high: nobody walks through
## them, but a look and a shot go over.
func wire_coil(from: Vector2, to: Vector2) -> void:
	var length := from.distance_to(to)
	var way := (to - from) / length
	var along := Vector3(way.x, 0, way.y)
	var across := Vector3.UP.cross(along)
	var st := _tool("wire", SLIGHT, ground(from.x, from.y))
	var rings := int(length / 0.42)
	for i in rings:
		var at := from + way * length * (i + 0.5) / rings
		var middle := ground(at.x, at.y, 0.5) + along * _clutter_rng.randf_range(-0.08, 0.08)
		var lean := Basis(Vector3.UP, _clutter_rng.randf_range(-0.3, 0.3))
		for s in 7:
			var a := lean * (across * cos(TAU * s / 7.0) + Vector3.UP * sin(TAU * s / 7.0)) * 0.48
			var b := lean * (across * cos(TAU * (s + 1) / 7.0) + Vector3.UP * sin(TAU * (s + 1) / 7.0)) * 0.48
			var out := (a + b).normalized()
			_quad(st, [middle + a - along * 0.012, middle + b - along * 0.012, middle + b + along * 0.012, middle + a + along * 0.012], [out, out, out, out], [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	for stake in maxi(2, int(length / 3.0) + 1):
		var at := from + way * length * stake / maxf(int(length / 3.0), 1.0)
		cylinder("dark_steel", ground(at.x, at.y, -0.2), 0.02, 1.3, SLIGHT, Vector3(_clutter_rng.randf_range(-6, 6), 0, _clutter_rng.randf_range(-6, 6)), -1.0, 5)
	var low := minf(ground_height(from.x, from.y), ground_height(to.x, to.y)) - 0.4
	var high := maxf(ground_height(from.x, from.y), ground_height(to.x, to.y)) + 1.15
	var half := (from + to) * 0.5
	_collide_box(Transform3D(Basis.looking_at(along), Vector3(half.x, (low + high) * 0.5, half.y)), Vector3(0.9, high - low, length), "metal")


## A barrier across a track: a pole, red and white, on a post with a weight
## at its short end. It lies across the way `yaw_deg` faces, `length` long
## from its post at `at`; `raised`, it points at the sky and is in nobody's
## way.
func barrier_pole(at: Vector2, yaw_deg: float, length := 5.0, raised := false) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y))
	box("concrete", xf * Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), Vector3(0, yaw_deg, 0))
	for z: float in [-0.12, 0.12]:
		box("dark_steel", xf * Vector3(0, 0.8, z), Vector3(0.12, 0.7, 0.03), Vector3(0, yaw_deg, 0), SLIGHT)
	var tilt := Basis(Vector3.BACK, deg_to_rad(78.0 if raised else 0.0))
	var arm := xf * Transform3D(tilt, Vector3(0, 1.0, 0))
	for i in int(length / 0.5):
		_local_box("enamel_red" if i % 2 == 0 else "paper", arm, Vector3(0.25 + i * 0.5, 0, 0), Vector3(0.5, 0.09, 0.09), SLIGHT)
	_local_box("dark_steel", arm, Vector3(-0.55, 0, 0), Vector3(0.7, 0.26, 0.2), SLIGHT)
	if not raised:
		_collide_box(xf * Transform3D(Basis(), Vector3(length * 0.5, 0.8, 0)), Vector3(length, 1.6, 0.14), "metal")
		var rest := xf * Vector3(length - 0.2, 0, 0)
		cylinder("dark_steel", on_ground(rest), 0.03, 0.98, SLIGHT, Vector3.ZERO, -1.0, 6)


## A sentry box of boards, its open front facing `yaw_deg`.
func sentry_box(at: Vector2, yaw_deg: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y))
	var turn := Vector3(0, yaw_deg, 0)
	for x: float in [-0.6, 0.6]:
		box("wood", xf * Vector3(x, 1.1, 0), Vector3(0.05, 2.2, 1.2), turn)
	box("wood", xf * Vector3(0, 1.1, -0.6), Vector3(1.25, 2.2, 0.05), turn)
	box("wood", xf * Vector3(0, 0.03, 0), Vector3(1.2, 0.06, 1.2), turn, SLIGHT)
	for side: float in [-1.0, 1.0]:
		_box("roof", xf * Transform3D(Basis(Vector3.BACK, side * 0.5), Vector3(side * 0.36, 2.38, 0)), Vector3(0.86, 0.04, 1.5), SLIGHT)
	for stripe in 4:
		_local_box("paper", xf, Vector3(-0.63, 0.35 + stripe * 0.5, 0), Vector3(0.012, 0.22, 1.2), SLIGHT)
		_local_box("paper", xf, Vector3(0.63, 0.35 + stripe * 0.5, 0), Vector3(0.012, 0.22, 1.2), SLIGHT)


## A board on a post with `text` on it, which has to be in the manifest as a
## decal of kind "text"; it is read from the side `yaw_deg` faces.
func sign_post(at: Vector2, yaw_deg: float, text: String, height := 0.2, board := "wood") -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y))
	var wide := height * _lettering_aspect(_lettering(text)) + 0.16
	cylinder("wood", xf * Vector3(0, -0.2, -0.05), 0.04, 1.85, SLIGHT, Vector3.ZERO, -1.0, 6)
	_local_box(board, xf, Vector3(0, 1.45, 0), Vector3(wide, height + 0.16, 0.03), SLIGHT)
	label(text, xf * Vector3(0, 1.45, 0.016), xf.basis * Vector3.BACK, height, Color(0.9, 0.88, 0.8) if board != "paper" else Color(0.1, 0.1, 0.1), 0.03)


## A pillbox: a low block of concrete with a slit to shoot from on the side
## `yaw_deg` faces and a steel door at the back, half dug in. Nobody is in
## it: its crew stand outside.
func pillbox(at: Vector2, yaw_deg: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y, -0.5))
	var turn := Vector3(0, yaw_deg, 0)
	box("concrete", xf * Vector3(0, 1.5, 0), Vector3(5.0, 3.0, 4.4), turn, DETAIL)
	box("concrete", xf * Vector3(0, 3.1, 0), Vector3(5.5, 0.3, 4.9), turn, SLIGHT)
	_local_box("dark_steel", xf, Vector3(0, 2.05, 2.21), Vector3(2.6, 0.4, 0.04), SLIGHT)
	_local_box("concrete", xf, Vector3(0, 2.33, 2.3), Vector3(3.0, 0.14, 0.3), SLIGHT)
	_local_box("door", xf, Vector3(1.2, 1.5, -2.21), Vector3(0.9, 1.9, 0.05), SLIGHT)
	wall_decal(_pick("leak"), xf * Vector3(-1.2, 2.2, 2.21), xf.basis * Vector3.BACK, 1.4, 1.8)
	wall_decal("grime", xf * Vector3(0, 0.9, 2.21), xf.basis * Vector3.BACK, 4.6, 1.0)
	wall_decal("grime", xf * Vector3(0, 0.9, -2.21), xf.basis * Vector3.FORWARD, 4.6, 1.0)


## A watchtower of timber, `height` to its floor: four legs, braced, a
## boarded cabin under a roof of sheet, and a ladder up one side. Nobody is
## up there; it is what is seen of a camp from afar.
func watch_tower(at: Vector2, height := 7.0, yaw_deg := 0.0) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y, -0.3))
	var turn := Vector3(0, yaw_deg, 0)
	var half := 1.25
	for x: float in [-half, half]:
		for z: float in [-half, half]:
			beam("wood", xf * Vector3(x * 1.25, 0, z * 1.25), xf * Vector3(x, height + 0.3, z), 0.16, DETAIL)
	for level in 2:
		var low := height * level * 0.5
		var high := height * (level + 1) * 0.5
		var wide_low := half * lerpf(1.25, 1.0, level * 0.5)
		var wide_high := half * lerpf(1.25, 1.0, (level + 1) * 0.5)
		for side: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var across := Vector3(side.y, 0, side.x)
			var out := Vector3(side.x, 0, side.y)
			beam("wood", xf * (out * wide_low + across * wide_low + Vector3.UP * (low + 0.3)), xf * (out * wide_high - across * wide_high + Vector3.UP * high), 0.08, SLIGHT)
	box("wood", xf * Vector3(0, height + 0.36, 0), Vector3(3.1, 0.1, 3.1), turn, SLIGHT)
	for side: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		_local_box("wood", xf, Vector3(side.x * 1.5, height + 0.95, side.y * 1.5), Vector3(0.06 if side.x != 0.0 else 3.06, 1.1, 0.06 if side.y != 0.0 else 3.06), SLIGHT)
	for x: float in [-1.5, 1.5]:
		for z: float in [-1.5, 1.5]:
			_local_box("wood", xf, Vector3(x, height + 1.5, z), Vector3(0.1, 2.2, 0.1), SLIGHT)
	_box("roof", xf * Transform3D(Basis(Vector3.RIGHT, 0.14), Vector3(0, height + 2.72, 0)), Vector3(3.9, 0.05, 3.9), SLIGHT)
	# The ladder, and a searchlight that is off by day.
	for x: float in [-0.25, 0.25]:
		beam("wood", xf * Vector3(x, 0.2, 2.1), xf * Vector3(x, height + 0.4, 1.56), 0.06, SLIGHT)
	for rung in int(height / 0.32):
		var share := (rung + 1) * 0.32 / height
		_local_box("wood", xf, Vector3(0, 0.2 + share * (height + 0.2), lerpf(2.1, 1.56, share)), Vector3(0.5, 0.04, 0.04), SLIGHT)
	cylinder("dark_steel", xf * Vector3(1.3, height + 1.55, 1.3), 0.2, 0.3, SLIGHT, Vector3(70, 45 + yaw_deg, 0), -1.0, 10)
	_collide_box(xf * Transform3D(Basis(), Vector3(0, height * 0.5, 0)), Vector3(2.9, height, 2.9), "wood")


## A hut of corrugated sheet bent over hoops, `length` long along the X of
## the way it is turned, with a boarded end at either side, a door in the one
## that faces `yaw_deg` + 90.
func nissen_hut(at: Vector2, yaw_deg: float, length := 11.0, radius := 2.6) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), ground(at.x, at.y, -0.05))
	var panels := 8
	for i in panels:
		var from := PI * i / panels
		var to := PI * (i + 1) / panels
		var a := Vector3(0, sin(from), cos(from)) * radius
		var b := Vector3(0, sin(to), cos(to)) * radius
		var out := ((a + b) * 0.5).normalized()
		# A panel stands in the XY of its frame and faces its +Z: out of the hut.
		var frame := xf * Transform3D(Basis(Vector3.RIGHT, out.cross(Vector3.RIGHT), out), (a + b) * 0.5)
		corrugated("roof", frame, Vector2(length, a.distance_to(b) + 0.03), 0.09, 0.02, SLIGHT)
	var face := PackedVector2Array()
	for i in panels + 1:
		face.append(Vector2(cos(PI * i / panels), sin(PI * i / panels)) * radius)
	for end: float in [-1.0, 1.0]:
		# The end faces out along the hut: the Z of its frame.
		var out := Vector3(end, 0, 0)
		extrude("wood", face, 0.08, xf * Transform3D(Basis(Vector3.UP.cross(out), Vector3.UP, out), out * length * 0.5), SLIGHT)
		_local_box("door", xf, Vector3(end * (length * 0.5 + 0.045), 1.0, 0), Vector3(0.03, 2.0, 0.9), SLIGHT)
		_local_box("dark_steel", xf, Vector3(end * (length * 0.5 + 0.045), 1.55, 1.35), Vector3(0.02, 0.6, 0.7), SLIGHT)
	_collide_box(xf * Transform3D(Basis(), Vector3(0, radius * 0.45, 0)), Vector3(length, radius * 0.9, radius * 1.8), "metal")
	_collide_box(xf * Transform3D(Basis(), Vector3(0, radius * 0.9, 0)), Vector3(length, radius * 0.2, radius * 1.1), "metal")
	cover("earth", at, length * 0.6, 0.6)


## A fire of a bivouac: stones in a ring, what is left of the wood, and logs
## to sit on round it.
func campfire(at: Vector2) -> void:
	place("stone_fire_pit", ground(at.x, at.y, -0.05), _prop_rng.randf() * 360.0)
	for i in 3:
		var turn := TAU * i / 3.0 + 0.5
		var seat := at + Vector2(cos(turn), sin(turn)) * 1.7
		var along := Vector3(-sin(turn), 0, cos(turn))
		var middle := ground(seat.x, seat.y, 0.17)
		rod("bark", middle - along * 0.8, middle + along * 0.8, 0.17, DETAIL, 8)
	cover("earth", at, 2.6, 0.9)


# --- Vehicles ------------------------------------------------------------------------


## A vehicle of tools/models/vehicles.gd on the ground at `at`: "jeep",
## "truck", "tank" or "tank_b", its nose towards `yaw_deg` (0 looks along
## +Z). It rests on the ground as the ground lies.
func vehicle(kind: String, at: Vector2, yaw_deg: float) -> void:
	var facts: Dictionary = VEHICLES[kind]
	# A model's nose points along -Z.
	var xf := resting(at.x, at.y, yaw_deg + 180.0, facts.span)
	var node: Node3D = (load("res://scenes/models/%s.scn" % kind) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.name = kind.to_pascal_case()
	node.transform = xf
	if _vehicles == null:
		_vehicles = Node3D.new()
		_vehicles.name = "Vehicles"
		_add(_vehicles, _root)
	_add(node, _vehicles)
	for part: Array in facts.boxes:
		_collide_box(xf * Transform3D(Basis(), part[0]), part[1], "metal")
	cover("earth", at, facts.span * 1.6, 0.7)
