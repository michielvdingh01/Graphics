extends "res://tools/model_builder.gd"
## What grows on the dunes: pines in five shapes and thorn scrub in two. Build with
## tools/build_model.sh trees; stand one in a level to look at it with
## tools/benchmark.sh --quick --spawn="res://scenes/models/pine_a.scn@2,0,0,0".
##
## A tree stands on the ground at the origin. It is two meshes: Body, which is
## what is seen from close by, with every branch, and Far, a trunk and a
## handful of cards, which takes its place from SWITCH metres off and is
## what a wood at a distance is made of. The tag "crowns" lists the balls its
## crown fills, [centre, radii] each, for whoever works out what stands in
## its shade, and "girth" how thick its trunk is, for a collider.
##
## A crown is cards of foliage (shaders/foliage.gdshader): a card lies on a
## branch, more or less flat, and a second one stands in it, so that there is
## something to see from below and from the side. Every corner of a card
## gets the normal of the crown it is part of, not that of the card: the
## crown is then lit as one mass, bright on top and towards the sun.

const BARK := "bark"
## From how far off a tree is its Far, and how far that carries.
const SWITCH := 60.0
const SWITCH_MARGIN := 5.0
const FAR_END := 420.0

var _dice := RandomNumberGenerator.new()
## The crown that is being built, for the normals of its cards.
var _crown_at := Vector3.ZERO
var _crown_size := Vector3.ONE


func _describe() -> void:
	# name, seed, height, girth, where the crown begins, how far it reaches,
	# how many boughs, how far the top stands out of plumb.
	_pine("pine_a", 11, 14.0, 0.26, 0.58, 3.4, 11, 0.5)
	_pine("pine_b", 23, 16.5, 0.3, 0.62, 3.8, 13, 1.0)
	_pine("pine_c", 37, 11.0, 0.22, 0.5, 3.0, 10, 0.3)
	_pine("pine_d", 41, 8.5, 0.24, 0.32, 3.9, 14, 1.4)
	_pine("pine_young", 53, 5.0, 0.1, 0.12, 1.7, 12, 0.2)
	_scrub("scrub_a", 61, 2.1, 1.6)
	_scrub("scrub_b", 67, 1.5, 2.0)


## One pine: a bare trunk with the stubs of dead branches on it, and from
## `crown_from` of its height up the boughs that carry the crown, the lower
## ones long and level, the upper ones short and steep.
func _pine(tree: String, seed: int, height: float, girth: float, crown_from: float, spread: float, boughs: int, lean: float) -> void:
	model(tree)
	_dice.seed = seed
	# The trunk: not quite straight, and out of plumb at the top by `lean`.
	var leans := Vector3.RIGHT.rotated(Vector3.UP, _dice.randf() * TAU) * lean
	var trunk: Array[Vector3] = []
	var thick: Array[float] = []
	var wander := Vector3.ZERO
	for i in 7:
		var share := i / 6.0
		if i > 0:
			wander += Vector3(_dice.randf_range(-1, 1), 0, _dice.randf_range(-1, 1)) * girth * 0.35
		trunk.append(Vector3(0, height * 0.97 * share, 0) + leans * share * share + wander)
		thick.append(girth * lerpf(1.0, 0.3, pow(share, 1.4)))
	thick[0] = girth * 1.45
	var crown_low := height * crown_from
	_crown_size = Vector3(spread * 1.05, (height - crown_low) * 0.56, spread * 1.05)
	_crown_at = _spot_on(trunk, crown_from + (1.0 - crown_from) * 0.5) + Vector3.UP * _crown_size.y * 0.05
	tag("crowns", [[_crown_at - Vector3.UP * _crown_size.y * 0.12, Vector3(spread * 0.92, _crown_size.y * 0.8, spread * 0.92)]])
	tag("girth", girth)
	tag("height", height)
	_far(SWITCH, false)

	_limb(trunk, thick, 8)
	# What is left of the branches the tree has shed on its way up.
	@warning_ignore("integer_division")
	for i in 3 + boughs / 2:
		var foot := _spot_on(trunk, _dice.randf_range(0.3, crown_from))
		var way := Vector3.RIGHT.rotated(Vector3.UP, _dice.randf() * TAU) + Vector3.DOWN * _dice.randf_range(0.0, 0.35)
		_limb([foot, foot + way.normalized() * _dice.randf_range(0.35, 1.1)], [girth * 0.14, girth * 0.05], 3)
	var tips: Array[Vector3] = []
	for i in boughs:
		var up := (i + _dice.randf() * 0.6) / boughs
		var share := lerpf(crown_from, 0.95, up)
		var foot := _spot_on(trunk, share)
		var turn := i * 2.39996 + _dice.randf_range(-0.3, 0.3)
		var rise := deg_to_rad(lerpf(6.0, 55.0, pow(up, 1.3)) + _dice.randf_range(-8, 8))
		var way := Vector3(cos(turn) * cos(rise), sin(rise), sin(turn) * cos(rise))
		var length := spread * lerpf(1.0, 0.42, pow(up, 1.5)) * _dice.randf_range(0.82, 1.15)
		var elbow := foot + way * length * 0.55 + Vector3.DOWN * length * 0.05
		var tip := foot + way * length + Vector3.UP * length * 0.1
		_limb([foot, elbow, tip], [girth * lerpf(0.3, 0.17, up), girth * lerpf(0.2, 0.1, up), girth * 0.05], 4)
		tips.append(tip)
		# The foliage sits on the outer half of a bough, and on the twigs
		# that leave it there to either side.
		var across := way.cross(Vector3.UP).normalized()
		var size := lerpf(2.5, 1.6, up) * spread / 3.4
		_pad(tip, way, size * _dice.randf_range(0.9, 1.15))
		_pad(elbow.lerp(tip, 0.35) + Vector3.UP * 0.15, way, size * _dice.randf_range(0.8, 1.0))
		for side: float in [-1.0, 1.0]:
			if _dice.randf() < 0.75:
				_pad(elbow.lerp(tip, _dice.randf_range(0.2, 0.8)) + across * side * length * _dice.randf_range(0.22, 0.4), (way + across * side).normalized(), size * _dice.randf_range(0.7, 0.95))
	# The top: a cushion over the head of the trunk.
	var head := trunk[trunk.size() - 1]
	_pad(head + Vector3.UP * 0.3, Vector3.UP, 2.2 * spread / 3.4)
	for i in 4:
		var out := Vector3.RIGHT.rotated(Vector3.UP, i * TAU / 4.0 + _dice.randf())
		_pad(head + out * spread * 0.2 - Vector3.UP * 0.3, out, 1.9 * spread / 3.4)

	# From afar: the trunk, three decks of foliage and two cards that stand.
	part("Far")
	_far(FAR_END, true)
	_limb([trunk[0], trunk[3], trunk[6]], [girth * 1.2, girth * 0.7, girth * 0.3], 4)
	for deck in 3:
		var share := deck / 2.0
		var at := _crown_at + Vector3.UP * _crown_size.y * lerpf(-0.55, 0.6, share)
		_card("pine_needles", at, Vector3.UP.rotated(Vector3.RIGHT, _dice.randf_range(-0.15, 0.15)), _crown_size.x * lerpf(2.3, 1.35, share), _dice.randf() * TAU, 0.5)
	for stand in 2:
		var faces := Vector3.RIGHT.rotated(Vector3.UP, stand * PI * 0.5 + 0.4)
		_card("pine_needles", _crown_at, faces, _crown_size.x * 2.1, 0.0, 0.5, _crown_size.y * 2.0 / (_crown_size.x * 2.1))


## Thorn scrub, a man high and wider than that: a few stems out of one foot
## under a dome of leaves.
func _scrub(bush: String, seed: int, height: float, spread: float) -> void:
	model(bush)
	_dice.seed = seed
	_crown_size = Vector3(spread, height * 0.6, spread)
	_crown_at = Vector3(0, height * 0.5, 0)
	tag("crowns", [[_crown_at, _crown_size * 0.9]])
	tag("girth", 0.0)
	tag("height", height)
	_far(SWITCH, false)
	for i in 7:
		var turn := i * TAU / 7.0 + _dice.randf_range(-0.3, 0.3)
		var out := Vector3(cos(turn), 0, sin(turn))
		var reach := spread * _dice.randf_range(0.55, 0.95)
		var top := out * reach + Vector3.UP * height * _dice.randf_range(0.5, 0.85)
		_limb([out * 0.1, out * reach * 0.4 + Vector3.UP * height * 0.35, top], [0.035, 0.025, 0.01], 3)
		_pad_of("thorn_scrub", top, (out + Vector3.UP * 0.8).normalized(), spread * _dice.randf_range(0.9, 1.2))
		_pad_of("thorn_scrub", out * reach * 0.6 + Vector3.UP * height * 0.3, out, spread * _dice.randf_range(0.8, 1.0))
	_pad_of("thorn_scrub", Vector3.UP * height * 0.9, Vector3.UP, spread * 1.3)
	part("Far")
	_far(FAR_END * 0.5, true)
	_card("thorn_scrub", _crown_at + Vector3.UP * height * 0.2, Vector3.UP, spread * 2.2, 0.3, 0.3)
	for stand in 2:
		_card("thorn_scrub", _crown_at, Vector3.RIGHT.rotated(Vector3.UP, stand * PI * 0.5 + 0.3), spread * 2.1, 0.0, 0.3, height / (spread * 2.1))


# --- What a tree is made of ----------------------------------------------------------


## Says of the part that is being built from how far off it is seen: up to
## `reach` for what is close, from SWITCH to `reach` for what is far.
func _far(reach: float, is_far: bool) -> void:
	var mesh := _parts[_current].node as MeshInstance3D
	if is_far:
		mesh.visibility_range_begin = SWITCH
		mesh.visibility_range_begin_margin = SWITCH_MARGIN
		mesh.visibility_range_end = reach
	else:
		mesh.visibility_range_end = reach
		mesh.visibility_range_end_margin = SWITCH_MARGIN


## Where a trunk is at a share of its length.
func _spot_on(points: Array[Vector3], share: float) -> Vector3:
	var at := clampf(share, 0.0, 1.0) * (points.size() - 1)
	var i := mini(int(at), points.size() - 2)
	return points[i].lerp(points[i + 1], at - i)


## A trunk or a branch through `points`, `thick[i]` in radius at each, with
## `sides` faces round it. It has no ends: they are in the ground, in the
## trunk or in the leaves.
func _limb(points: Array[Vector3], thick: Array[float], sides: int) -> void:
	var st := _tool(BARK, 0, points[0])
	var heading := (points[1] - points[0]).normalized()
	var side := _up_along(heading).x
	var before: Array[Vector3] = []
	var run := 0.0
	for i in points.size():
		var next := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		if not next.is_equal_approx(heading):
			side = Quaternion(heading, next) * side
			heading = next
		var around: Array[Vector3] = []
		for s in sides + 1:
			around.append(Basis(heading, TAU * s / sides) * side)
		if i > 0:
			var length := points[i].distance_to(points[i - 1])
			var girth := TAU * maxf(thick[i - 1], thick[i])
			for s in sides:
				_quad(
					st,
					[points[i - 1] + before[s] * thick[i - 1], points[i - 1] + before[s + 1] * thick[i - 1], points[i] + around[s + 1] * thick[i], points[i] + around[s] * thick[i]],
					[before[s], before[s + 1], around[s + 1], around[s]],
					[Vector2(girth * s / sides, -run), Vector2(girth * (s + 1) / sides, -run), Vector2(girth * (s + 1) / sides, -run - length), Vector2(girth * s / sides, -run - length)]
				)
			run += length
		before = around


## The foliage at one spot of a pine's bough: a card that lies there, tilted
## the way the bough runs, and one that stands in it.
func _pad(at: Vector3, way: Vector3, size: float) -> void:
	_pad_of("pine_needles", at, way, size)


func _pad_of(mat: String, at: Vector3, way: Vector3, size: float) -> void:
	var out := Vector3(way.x, 0, way.z).normalized() if Vector2(way.x, way.z).length() > 0.05 else Vector3.RIGHT.rotated(Vector3.UP, _dice.randf() * TAU)
	var lies := (Vector3.UP + out * _dice.randf_range(0.1, 0.45) + Vector3(_dice.randf_range(-0.2, 0.2), 0, _dice.randf_range(-0.2, 0.2))).normalized()
	var sway := clampf(Vector2(at.x - _crown_at.x, at.z - _crown_at.z).length() / _crown_size.x, 0.25, 1.0)
	_tent(mat, at, lies, size, _dice.randf() * TAU, sway)
	var stands := (out.rotated(Vector3.UP, _dice.randf_range(-0.6, 0.6)) + Vector3.UP * 0.35).normalized()
	_card(mat, at - Vector3.UP * size * 0.12, stands, size * 0.85, _dice.randf_range(-0.4, 0.4), sway)


## A card that lies on a bough: not flat but a low tent, its middle higher
## than its corners, as the twigs of a bough rise to their tips and hang at
## the sides. Its underside, which is what somebody under the tree sees, is
## marked as that: the shader keeps it dark.
func _tent(mat: String, middle: Vector3, faces: Vector3, size: float, turn: float, sway: float) -> void:
	var st := _tool(mat, 0, middle)
	var normal := faces.normalized()
	var side := (Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).cross(normal).normalized().rotated(normal, turn)
	var up := normal.cross(side)
	var half := size * 0.5
	var top := middle + normal * size * 0.13
	var phase := _dice.randf()
	var points: Array[Vector3] = [top]
	var uvs: Array[Vector2] = [Vector2(0.5, 0.5), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		points.append(middle + side * half * corner.x + up * half * corner.y - normal * size * 0.06)
	var normals: Array[Vector3] = []
	var colours: Array[Color] = []
	for point in points:
		normals.append(_crown_normal(point))
		colours.append(Color(sway, phase, _crown_light(point), 1.0))
	for i in 4:
		var a := 1 + i
		var b := 1 + (i + 1) % 4
		_tri(st, [points[0], points[a], points[b]], [normals[0], normals[a], normals[b]], [uvs[0], uvs[a], uvs[b]], [colours[0], colours[a], colours[b]])


## Which way a point of the crown faces, as part of the whole crown.
func _crown_normal(point: Vector3) -> Vector3:
	return (((point - _crown_at) / _crown_size).normalized() + Vector3.UP * 0.6).normalized()


## How much light gets to a point of the crown: more the further out it is
## and the higher up.
func _crown_light(point: Vector3) -> float:
	var from_middle := (point - _crown_at) / _crown_size
	return clampf(from_middle.length() * 0.75 + clampf(from_middle.y, -1.0, 1.0) * 0.3 + 0.15, 0.0, 1.0)


## One card of foliage: `size` wide around `middle`, facing `faces` and turned
## `turn` in its own plane; `tall` times as high as it is wide. Its corners
## get the normal of the crown and say how they sway, see the top of this file.
func _card(mat: String, middle: Vector3, faces: Vector3, size: float, turn: float, sway: float, tall := 1.0) -> void:
	var st := _tool(mat, 0, middle)
	var normal := faces.normalized()
	var side := (Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).cross(normal).normalized().rotated(normal, turn)
	var up := normal.cross(side)
	var half := size * 0.5
	var corners := [middle - side * half - up * half * tall, middle + side * half - up * half * tall, middle + side * half + up * half * tall, middle - side * half + up * half * tall]
	var normals: Array[Vector3] = []
	var colours: Array[Color] = []
	var phase := _dice.randf()
	for corner: Vector3 in corners:
		normals.append(_crown_normal(corner))
		colours.append(Color(sway, phase, _crown_light(corner), 0.0))
	_quad(st, corners, normals, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)], colours)
