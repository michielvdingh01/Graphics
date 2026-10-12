extends "res://tools/model_builder.gd"
## What grows tall on the dunes: pines in five shapes and thorn scrub in two.
## Build with tools/build_model.sh trees; stand one in a level to look at it
## with tools/benchmark.sh --quick --spawn="res://scenes/models/pine_a.scn@2,0,0,0".
##
## A tree stands on the ground at the origin. It is grown first and drawn
## afterwards: a trunk, the boughs that leave it and twist and fork, and at
## the end of every limb a plate of sprigs, lying level as the foliage of a
## pine does, with the sky between one plate and the next. What was grown is
## then drawn three times over, each time with less to it, and the game shows
## the one that fits how far off the tree is:
##
##   Body   from close by: every limb, and every sprig as two or three cards
##   Mid    from NEAR metres: the limbs with fewer sides, and the plate at
##          the end of a limb as three cards
##   Far    from FAR metres: a trunk, and all a bough carries as three cards
##
## and a fourth time as Shade, which is Mid again and only throws the shadow
## of the tree while Body is what is seen: the shadow then stays what it was
## when the tree changes, and the sun has less to draw.
##
## A card shows a picture of a sprig or of a whole bough end that was grown
## and rendered, see tools/gen_sprigs.py: cards through each other show the
## sides it was pictured from, so there is something to see from anywhere. A
## sprig is thin, a twig with a few brushes of needles and the sky between
## them: from close by a plate is many of them behind each other. A bough end
## is a mass, which is what a plate is from further off.
## Every corner of a card gets a normal that is half that of the tuft it is
## part of and half that of the crown, not that of the card: the crown is
## then lit as a mass of tufts, each bright on top and towards the sun.
##
## The tag "crowns" lists the balls a crown fills, [centre, radii] each, for
## whoever works out what stands in its shade, "girth" how thick its trunk
## is, for a collider, and "height" how high it is.

const BARK := "pine_trunk"
const NEEDLES := "pine_needles"
## The pictures of sprigs and boughs, and where on their sheet each is.
const SHEET := "res://assets/foliage/pine_sprigs.json"
## From how far off a tree is its Mid and its Far, how much further it has to
## go before it changes back, and how far its Far carries.
const NEAR := 26.0
const FAR := 62.0
const MARGIN := 4.0
const FAR_END := 420.0
## What is to the right on a picture of a sprig, what is up and what comes
## towards whoever looks, for each side it was pictured from: in the frame of
## the sprig, which grows along X with Y up.
const VIEWS := {
	"plan": [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	"side": [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	"front": [Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)],
}
## The vertex colour of wood that is drawn with the needles, see
## shaders/crown.gdshader: it does not sway and lets no light through.
const WOOD := Color(0.0, 0.0, 1.0, 0.5)
## The bark of a pine low on its trunk, grey and plated, and high up, where
## it is thin and orange and flakes: what the scan is tinted with.
const BARK_LOW := Color(0.74, 0.7, 0.68)
const BARK_HIGH := Color(0.8, 0.66, 0.54)
const BARK_DEAD := Color(0.56, 0.54, 0.52)
const BARK_YOUNG := Color(0.55, 0.5, 0.44)

var _dice := RandomNumberGenerator.new()
## The crown that is being built, for the normals of its cards.
var _crown_at := Vector3.ZERO
var _crown_size := Vector3.ONE
## The pictures on the sheet, by what they show and from where ("sprig plan"):
## a list of {rect, size, anchor, depth, box} each. And the size of the sheet
## in dots, and where on it the strip of bark is, 0 to 1.
var _pictures := {}
var _sheet := Vector2.ONE
var _bark_strip := Rect2()
## The tree that has been grown and is being drawn. Its limbs: {points, thick,
## tints, order}, order 0 for the trunk, 1 for a bough, 2 for what forks off
## a bough and 3 for what is dead. Its tufts, a sprig each: {frame, size,
## which, views, bough, end, level, phase}: the sides it is drawn from when
## the tree is close, the bough and the limb end it belongs to, for what is
## drawn of it from further off, and the way that limb runs over the ground.
var _limbs: Array[Dictionary] = []
var _tufts: Array[Dictionary] = []
## How many limb ends the tree has so far.
var _ends := 0
## Whether it is a young tree, with its crown down to the ground.
var _young := false


func _describe() -> void:
	_read_sheet()
	# name, seed, height, girth, where the crown begins, how far it reaches,
	# how many boughs, how far the top stands out of plumb.
	_pine("pine_a", 11, 14.0, 0.26, 0.58, 3.4, 11, 0.5)
	_pine("pine_b", 23, 16.5, 0.3, 0.62, 3.8, 13, 1.0)
	_pine("pine_c", 37, 11.0, 0.22, 0.5, 3.0, 10, 0.3)
	_pine("pine_d", 41, 8.5, 0.24, 0.32, 3.9, 14, 1.4)
	_pine("pine_young", 53, 5.0, 0.1, 0.12, 1.7, 12, 0.2)
	_scrub("scrub_a", 61, 2.1, 1.6)
	_scrub("scrub_b", 67, 1.5, 2.0)


## Reads what tools/gen_sprigs.py wrote next to its sheet.
func _read_sheet() -> void:
	var sheet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHEET))
	_sheet = Vector2(sheet.size[0], sheet.size[1])
	for picture: Dictionary in sheet.pictures:
		var rect := Rect2(picture.rect[0], picture.rect[1], picture.rect[2], picture.rect[3])
		if picture.view == "bark":
			_bark_strip = Rect2(rect.position / _sheet, rect.size / _sheet)
			continue
		var key := "%s %s" % [picture.what, picture.view]
		if not _pictures.has(key):
			_pictures[key] = []
		(_pictures[key] as Array).append({
			"view": picture.view,
			"rect": rect,
			"size": Vector2(picture.size[0], picture.size[1]),
			"anchor": Vector2(picture.anchor[0], picture.anchor[1]),
			"depth": float(picture.depth),
			"box": Rect2(picture.box[0], picture.box[1], picture.box[2] - picture.box[0], picture.box[3] - picture.box[1]),
		})


## One pine: a bare trunk with the stubs of dead branches on it, and from
## `crown_from` of its height up the boughs that carry the crown. A pine whose
## crown begins near the ground is a young one: dense and pointed, a whorl of
## branches for every year.
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

	_limbs = []
	_tufts = []
	_ends = 0
	var tints: Array[Color] = []
	for i in trunk.size():
		tints.append(BARK_LOW.lerp(BARK_HIGH, smoothstep(0.3, 0.62, i / 6.0)))
	_limbs.append({"points": trunk, "thick": thick, "tints": tints, "order": 0})
	_young = crown_from < 0.2
	if _young:
		_grow_young(trunk, thick, height, spread)
	else:
		_grow_old(trunk, thick, girth, crown_from, spread, boughs, leans)
	_draw(tree)


## The crown of a grown pine: boughs that leave the trunk upwards and end on
## the outside of the crown, the lower ones long and the upper ones short,
## each with a twist in it and a few forks. A tree that leans has grown
## towards the open: its boughs are longer on that side.
func _grow_old(trunk: Array[Vector3], thick: Array[float], girth: float, crown_from: float, spread: float, boughs: int, leans: Vector3) -> void:
	# What is left of the branches the tree has shed on its way up: stubs,
	# and a dead branch or two that has not come down yet.
	@warning_ignore("integer_division")
	for i in 4 + boughs / 2:
		var share := _dice.randf_range(0.22, crown_from)
		var foot := _spot_on(trunk, share)
		var way := (Vector3.RIGHT.rotated(Vector3.UP, _dice.randf() * TAU) + Vector3.UP * _dice.randf_range(-0.35, 0.25)).normalized()
		var long := _dice.randf() < 0.18
		var reach := _dice.randf_range(0.7, 1.3) if long else _dice.randf_range(0.1, 0.32)
		var start := girth * (0.2 if long else 0.24)
		var crook := Vector3(_dice.randf_range(-1, 1), _dice.randf_range(-1, 0.2), _dice.randf_range(-1, 1)) * reach * (0.22 if long else 0.08)
		var points: Array[Vector3] = [foot, foot + way * reach * 0.5 + crook, foot + way * reach + Vector3.DOWN * reach * _dice.randf_range(0.1, 0.45)]
		var widths: Array[float] = [start, start * 0.7, start * (0.4 if long else 0.55)]
		_limbs.append({"points": points, "thick": widths, "tints": _all(BARK_DEAD, 3), "order": 3})
	var open := Vector3(leans.x, 0, leans.z)
	var pull := clampf(open.length() * 0.3, 0.0, 0.4)
	for i in boughs:
		var up := (i + _dice.randf() * 0.6) / boughs
		var foot := _spot_on(trunk, lerpf(crown_from, 0.95, pow(up, 0.85)))
		var turn := i * 2.39996 + _dice.randf_range(-0.35, 0.35)
		var out := Vector3(cos(turn), 0, sin(turn))
		var fuller := 1.0 + pull * out.dot(open.normalized()) if pull > 0.0 else 1.0
		# Where it ends: on the ball the crown fills, low on it for the
		# lowest bough and near its top for the highest.
		var slant := deg_to_rad(lerpf(-30.0, 70.0, up) + _dice.randf_range(-7, 7))
		var tip := _crown_at + (out * cos(slant) * _crown_size.x * 0.7 * fuller + Vector3.UP * sin(slant) * _crown_size.y * 0.78) * _dice.randf_range(0.82, 1.05)
		var start := girth * lerpf(0.34, 0.17, up)
		var bough := _bough(foot, tip, out, deg_to_rad(lerpf(8.0, 50.0, up) + _dice.randf_range(-8, 8)), start, i, up)
		_cloud(bough, i, lerpf(1.7, 1.4, up))
		# What forks off it, to one side and the other by turns.
		var length := foot.distance_to(tip)
		var forks := clampi(int(length / 1.1), 2, 3)
		for fork in forks:
			var along := lerpf(0.3, 0.82, (fork + _dice.randf()) / forks)
			var from := _spot_on(bough, along)
			var heading := (_spot_on(bough, along + 0.1) - _spot_on(bough, along - 0.1)).normalized()
			var hand := 1.0 if (fork + i) % 2 == 0 else -1.0
			var way := (heading.rotated(Vector3.UP, hand * deg_to_rad(_dice.randf_range(34, 58))) + Vector3.UP * _dice.randf_range(0.0, 0.3)).normalized()
			var reach := length * (1.0 - along) * _dice.randf_range(0.7, 1.0) + 0.55
			var bend := Vector3(_dice.randf_range(-1, 1), _dice.randf_range(-0.6, 0.6), _dice.randf_range(-1, 1)) * reach * 0.1
			var twig: Array[Vector3] = [from, from + way * reach * 0.5 + bend, from + way * reach + Vector3.UP * reach * 0.14]
			var begins := start * lerpf(0.62, 0.4, along)
			var widths: Array[float] = [begins, begins * 0.6, 0.016]
			_limbs.append({"points": twig, "thick": widths, "tints": _all(BARK_HIGH, 3), "order": 2})
			_cloud(twig, i, lerpf(1.55, 1.3, up))
	# The top: what the trunk itself ends in, a plate to either side.
	var head := trunk[trunk.size() - 1]
	var first := _dice.randf() * TAU
	for i in 2:
		var out := Vector3.RIGHT.rotated(Vector3.UP, first + i * PI + _dice.randf_range(-0.4, 0.4))
		var top: Array[Vector3] = [head - Vector3.UP * 0.5, head + out * 0.5 + Vector3.UP * 0.1]
		_cloud(top, boughs, 1.5)


## A young pine: a straight stem with a whorl of branches for every year it
## has grown, the lowest the longest, and needles on every one of them from
## the stem out.
func _grow_young(trunk: Array[Vector3], _thick: Array[float], height: float, spread: float) -> void:
	var whorls := int(height / 0.42)
	for whorl in whorls:
		var up := (whorl + 0.5) / whorls
		var foot := _spot_on(trunk, lerpf(0.1, 0.95, up))
		var reach := spread * lerpf(1.0, 0.2, pow(up, 0.85)) * _dice.randf_range(0.85, 1.05)
		var branches := 6 if up < 0.6 else 5
		var first := _dice.randf() * TAU
		# The tufts of a few whorls count as one bough from afar.
		@warning_ignore("integer_division")
		var tier := whorl * 4 / whorls
		for branch in branches:
			var turn := first + branch * TAU / branches + _dice.randf_range(-0.25, 0.25)
			var rise := deg_to_rad(lerpf(8.0, 48.0, up) + _dice.randf_range(-6, 6))
			var way := Vector3(cos(turn) * cos(rise), sin(rise), sin(turn) * cos(rise))
			var length := reach * _dice.randf_range(0.8, 1.1)
			var points: Array[Vector3] = [foot, foot + way * length * 0.55 + Vector3.DOWN * length * 0.05, foot + way * length + Vector3.UP * length * 0.16]
			var start := lerpf(0.022, 0.01, up)
			var widths: Array[float] = [start, start * 0.65, 0.005]
			_limbs.append({"points": points, "thick": widths, "tints": _all(BARK_YOUNG, 3), "order": 2})
			_sprays_along(points, tier, 0.2, lerpf(1.3, 1.0, up), 0.5)
	# The leader: this year's shoot, straight up.
	var head := trunk[trunk.size() - 1]
	for i in 3:
		_tuft(head - Vector3.UP * (0.2 + i * 0.3), (Vector3.UP + Vector3.RIGHT.rotated(Vector3.UP, _dice.randf() * TAU) * 0.25 * i).normalized(), 1.2, "plan side front", 3, _ends, Vector3.ZERO)
	_ends += 1


## A bough from `foot` on the trunk to `tip`: it leaves the trunk towards
## `out` and `rise` above level, turns up again where it ends, and is bent
## sideways on the way, as no bough of a pine is straight. `up` is how high
## in the crown it sits, 0 to 1. Returns its points.
func _bough(foot: Vector3, tip: Vector3, out: Vector3, rise: float, start: float, _index: int, up: float) -> Array[Vector3]:
	var length := foot.distance_to(tip)
	var leaves := out * cos(rise) + Vector3.UP * sin(rise)
	var arrives := (out + Vector3.UP * 0.55).normalized()
	var side := out.cross(Vector3.UP)
	var first := foot + leaves * length * 0.36 + side * length * _dice.randf_range(-0.2, 0.2)
	var second := tip - arrives * length * 0.3 + side * length * _dice.randf_range(-0.2, 0.2)
	var points: Array[Vector3] = []
	var thick: Array[float] = []
	var tints: Array[Color] = []
	for step in 7:
		var t := step / 6.0
		var at := foot.bezier_interpolate(first, second, tip, t)
		if step > 0 and step < 6:
			# The kinks of a limb that lost its leader more than once.
			at += Vector3(_dice.randf_range(-1, 1), _dice.randf_range(-0.7, 0.7), _dice.randf_range(-1, 1)) * length * 0.05
		points.append(at)
		thick.append(lerpf(start, 0.02, pow(t, 0.6)))
		tints.append(BARK_HIGH.lerp(BARK_LOW, 0.25 * (1.0 - up) * (1.0 - t)))
	_limbs.append({"points": points, "thick": thick, "tints": tints, "order": 1})
	return points


## The foliage at the end of a limb through `points`: a plate that lies
## level whatever the limb does. From afar it is a mass, see _bough_cards();
## from close by there are sprigs round its rim and standing up out of it,
## which is what this puts there. `bough` is the bough it belongs to and
## `size` how many times the size they were grown at the sprigs are.
func _cloud(points: Array[Vector3], bough: int, size: float) -> void:
	var last := points.size() - 1
	var heading := points[last] - points[last - 1]
	var level := Vector3(heading.x, 0, heading.z)
	level = level.normalized() if level.length() > 0.05 else Vector3.RIGHT.rotated(Vector3.UP, _dice.randf() * TAU)
	var across := level.cross(Vector3.UP)
	var end := points[last]
	var fan := 4
	for i in fan:
		var spread := lerpf(-1.0, 1.0, (i + _dice.randf_range(0.2, 0.8)) / fan)
		var way := (level.rotated(Vector3.UP, spread * deg_to_rad(85.0)) + Vector3.UP * _dice.randf_range(0.04, 0.24)).normalized()
		# The outer ones of the fan leave the limb further back.
		var at := end + level * size * (0.3 - 0.5 * absf(spread)) * _dice.randf_range(0.8, 1.2) + across * size * spread * 0.35 + Vector3.UP * size * _dice.randf_range(-0.04, 0.08)
		_tuft(at, way, size * _dice.randf_range(0.88, 1.12), "plan side" if i % 2 == 0 else "plan front", bough, _ends, level)
	for i in 2:
		var way := (level.rotated(Vector3.UP, _dice.randf_range(-1.0, 1.0)) * 0.75 + Vector3.UP * _dice.randf_range(0.55, 0.95)).normalized()
		var at := end - level * size * _dice.randf_range(0.0, 0.5) + across * size * _dice.randf_range(-0.4, 0.4) + Vector3.UP * size * 0.08
		_tuft(at, way, size * _dice.randf_range(0.75, 0.95), "plan side front", bough, _ends, level)
	_ends += 1


## The sprigs of a branch of a young pine: one at its end, and from `from`
## of its length on one to either side by turns, `step` sprigs apart.
func _sprays_along(points: Array[Vector3], bough: int, from: float, size: float, step: float) -> void:
	var last := points.size() - 1
	var heading := (points[last] - points[last - 1]).normalized()
	var level := Vector3(heading.x, 0, heading.z).normalized()
	_tuft(points[last] - heading * 0.12 * size, (heading + Vector3.UP * 0.2).normalized(), size * _dice.randf_range(1.0, 1.15), "plan side front", bough, _ends, level)
	var length := 0.0
	for i in last:
		length += points[i].distance_to(points[i + 1])
	var count := int(length * (1.0 - from) / (0.5 * size * step))
	var hand := 1.0 if _dice.randf() < 0.5 else -1.0
	for i in count:
		var along := lerpf(from, 0.94, (i + _dice.randf_range(0.25, 0.75)) / count)
		var at := _spot_on(points, along)
		var runs := (_spot_on(points, along + 0.08) - _spot_on(points, along - 0.08)).normalized()
		var side := runs.cross(Vector3.UP).normalized() * hand
		hand = -hand
		var way := (runs * _dice.randf_range(0.4, 0.8) + side * 0.8 + Vector3.UP * _dice.randf_range(0.35, 0.9)).normalized()
		_tuft(at, way, size * _dice.randf_range(0.82, 1.05), "plan side" if i % 2 == 0 else "side front", bough, _ends, level)
	_ends += 1


## One sprig, its twig at `at` and growing along `way`, drawn from the sides
## `views` names. It is part of the limb end `end` of the bough `bough`,
## which runs `level` over the ground.
func _tuft(at: Vector3, way: Vector3, size: float, views: String, bough: int, end: int, level: Vector3) -> void:
	var x := way.normalized()
	var z := x.cross(Vector3.UP)
	z = (z.normalized() if z.length() > 0.05 else Vector3.RIGHT.rotated(Vector3.UP, _dice.randf() * TAU)).rotated(x, _dice.randf_range(-0.3, 0.3))
	var y := z.cross(x)
	_tufts.append({"frame": Transform3D(Basis(x, y, z), at), "size": size, "which": _dice.randi(), "views": views, "bough": bough, "end": end, "level": level, "phase": _dice.randf()})


# --- Drawing what was grown --------------------------------------------------------


## Draws the tree that was grown, once for every distance it is seen from.
func _draw(_tree: String) -> void:
	_seen(0.0, NEAR, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for limb: Dictionary in _limbs:
		var sides: int = [8, 5, 4, 4][limb.order]
		if limb.order == 0:
			_tube(BARK, _finer(limb.points), _finer_floats(limb.thick), sides, _finer_colours(limb.tints))
		else:
			_tube(BARK, limb.points, limb.thick, sides, limb.tints)
	var ends := _grouped("end")
	var boughs := _grouped("bough")
	# The mass of a plate is a picture of a whole bough end: something for a
	# crown high up, not for a young tree somebody stands next to.
	if not _young:
		for end: int in ends:
			_bough_cards(ends[end])
	for tuft: Dictionary in _tufts:
		for view: String in (tuft.views as String).split(" "):
			_sprig_card(tuft, view, 1.0)
	for nearby: String in ["Mid", "Shade"]:
		part(nearby)
		if nearby == "Mid":
			_seen(NEAR, FAR, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		else:
			_seen(0.0, NEAR, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
		for limb: Dictionary in _limbs:
			var points: Array[Vector3] = limb.points
			if limb.order == 3 and points[0].distance_to(points[points.size() - 1]) < 0.9:
				continue
			_tube(BARK, _coarser(points), _coarser_floats(limb.thick), 6 if limb.order == 0 else 3, _coarser_colours(limb.tints))
		for end: int in ends:
			_bough_cards(ends[end])
	part("Far")
	_seen(FAR, FAR_END, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	var trunk: Dictionary = _limbs[0]
	var none: Array[Color] = []
	_tube(NEEDLES, _coarser(trunk.points), _coarser_floats(trunk.thick), 4, none, true)
	for bough: int in boughs:
		_bough_cards(boughs[bough])
	print("%s: %d limbs, %d sprigs at %d limb ends of %d boughs" % [_tree, _limbs.size(), _tufts.size(), ends.size(), boughs.size()])


## The tufts of the tree by what they have in common: the bough they are on
## ("bough") or the limb end ("end").
func _grouped(by: String) -> Dictionary:
	var groups := {}
	for tuft: Dictionary in _tufts:
		if not groups.has(tuft[by]):
			groups[tuft[by]] = []
		(groups[tuft[by]] as Array).append(tuft)
	return groups


## Says of the part that is being built from how far off it is seen, and
## whether it throws a shadow.
func _seen(from: float, to: float, shadow: GeometryInstance3D.ShadowCastingSetting) -> void:
	var mesh := _parts[_current].node as MeshInstance3D
	mesh.visibility_range_begin = from
	mesh.visibility_range_begin_margin = MARGIN if from > 0.0 else 0.0
	mesh.visibility_range_end = to
	mesh.visibility_range_end_margin = MARGIN
	mesh.cast_shadow = shadow


## One tint, `count` times over: for a limb that is the same colour all along.
func _all(tint: Color, count: int) -> Array[Color]:
	var tints: Array[Color] = []
	tints.resize(count)
	tints.fill(tint)
	return tints


## Where a limb is at a share of its length.
func _spot_on(points: Array[Vector3], share: float) -> Vector3:
	var at := clampf(share, 0.0, 1.0) * (points.size() - 1)
	var i := mini(int(at), points.size() - 2)
	return points[i].lerp(points[i + 1], at - i)


## A limb with a point between every two of its own, on a curve through them.
func _finer(points: Array[Vector3]) -> Array[Vector3]:
	var fine: Array[Vector3] = []
	var last := points.size() - 1
	for i in last:
		fine.append(points[i])
		fine.append(points[i].cubic_interpolate(points[i + 1], points[maxi(i - 1, 0)], points[mini(i + 2, last)], 0.5))
	fine.append(points[last])
	return fine


func _finer_floats(values: Array[float]) -> Array[float]:
	var fine: Array[float] = []
	for i in values.size() - 1:
		fine.append(values[i])
		fine.append((values[i] + values[i + 1]) * 0.5)
	fine.append(values[values.size() - 1])
	# The foot of a trunk spreads only close to the ground.
	if fine.size() > 2 and fine[0] > fine[2] * 1.2:
		fine[1] = lerpf(fine[2], fine[0], 0.15)
	return fine


func _finer_colours(values: Array[Color]) -> Array[Color]:
	var fine: Array[Color] = []
	for i in values.size() - 1:
		fine.append(values[i])
		fine.append(values[i].lerp(values[i + 1], 0.5))
	fine.append(values[values.size() - 1])
	return fine


## A limb with every other point left out, its ends kept.
func _coarser(points: Array[Vector3]) -> Array[Vector3]:
	var coarse: Array[Vector3] = []
	for i in range(0, points.size(), 2):
		coarse.append(points[i])
	if points.size() % 2 == 0:
		coarse.append(points[points.size() - 1])
	return coarse


func _coarser_floats(values: Array[float]) -> Array[float]:
	var coarse: Array[float] = []
	for i in range(0, values.size(), 2):
		coarse.append(values[i])
	if values.size() % 2 == 0:
		coarse.append(values[values.size() - 1])
	return coarse


func _coarser_colours(values: Array[Color]) -> Array[Color]:
	var coarse: Array[Color] = []
	for i in range(0, values.size(), 2):
		coarse.append(values[i])
	if values.size() % 2 == 0:
		coarse.append(values[values.size() - 1])
	return coarse


## Wood through `points`, `thick[i]` in radius at each and tinted `tints[i]`
## there, with `sides` faces round it. It has no ends: they are in the
## ground, in the trunk or in the needles. The bark goes round it a whole
## number of times, so that it meets itself. With `strip` it is wood that is
## drawn with the needles: it takes the strip of bark on their sheet, from
## foot to top.
func _tube(mat: String, points: Array[Vector3], thick: Array[float], sides: int, tints: Array[Color], strip := false) -> void:
	var st := _tool(mat, 0, points[0])
	var heading := (points[1] - points[0]).normalized()
	var side := _up_along(heading).x
	var before: Array[Vector3] = []
	var run := 0.0
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	var turns := maxf(roundf(TAU * thick[0] * 0.8), 1.0) / 0.8
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
			for s in sides:
				var uvs: Array[Vector2]
				if strip:
					var low := _bark_strip.position + Vector2(run / total, 0.2 + 0.6 * s / sides) * _bark_strip.size
					var high := _bark_strip.position + Vector2((run + length) / total, 0.2 + 0.6 * (s + 1) / sides) * _bark_strip.size
					uvs = [low, Vector2(low.x, high.y), high, Vector2(high.x, low.y)]
				else:
					uvs = [Vector2(turns * s / sides, -run), Vector2(turns * (s + 1) / sides, -run), Vector2(turns * (s + 1) / sides, -run - length), Vector2(turns * s / sides, -run - length)]
				_quad(
					st,
					[points[i - 1] + before[s] * thick[i - 1], points[i - 1] + before[s + 1] * thick[i - 1], points[i] + around[s + 1] * thick[i], points[i] + around[s] * thick[i]],
					[before[s], before[s + 1], around[s + 1], around[s]],
					uvs,
					[WOOD, WOOD, WOOD, WOOD] if strip else [tints[i - 1], tints[i - 1], tints[i], tints[i]]
				)
			run += length
		before = around


## One picture of a sprig as a card: the side `view` of the sprig `tuft`,
## `larger` times the size of the tuft.
func _sprig_card(tuft: Dictionary, view: String, larger: float) -> void:
	var pictures: Array = _pictures["sprig " + view]
	var picture: Dictionary = pictures[tuft.which % pictures.size()]
	var frame: Transform3D = tuft.frame
	var size: float = tuft.size * larger
	var middle := frame * (Vector3(0.25, 0.08, 0.0) * size)
	_card(picture, frame, size, middle, size * 0.3, tuft.phase)


## The tufts of one bough as three cards with a picture of a whole bough on
## them: what a tree is made of from afar.
func _bough_cards(tufts: Array) -> void:
	var middle := Vector3.ZERO
	for tuft: Dictionary in tufts:
		middle += (tuft.frame as Transform3D) * (Vector3(0.25, 0.08, 0.0) * tuft.size)
	middle /= tufts.size()
	var reach := 0.0
	for tuft: Dictionary in tufts:
		reach = maxf(reach, ((tuft.frame as Transform3D) * (Vector3(0.25, 0.08, 0.0) * tuft.size)).distance_to(middle) + 0.18 * tuft.size)
	# It runs the way its limbs do, or away from the trunk, or any way if it
	# stands round it.
	var out := Vector3.ZERO
	for tuft: Dictionary in tufts:
		out += tuft.level as Vector3
	if out.length() < 0.5 * tufts.size():
		out = Vector3(middle.x - _crown_at.x, 0, middle.z - _crown_at.z)
	var first: Dictionary = tufts[0]
	out = out.normalized() if out.length() > 0.4 else Vector3.RIGHT.rotated(Vector3.UP, first.phase * TAU)
	for view: String in ["plan", "side", "front"]:
		var pictures: Array = _pictures["bough " + view]
		var picture: Dictionary = pictures[first.which % pictures.size()]
		# As large as shows the whole of the bough, and its middle on that
		# of the tufts.
		var box: Rect2 = picture.box
		var anchor: Vector2 = picture.anchor
		var shows: Vector2 = picture.size
		var depth: float = picture.depth
		var shown := box.size * shows
		var size := 2.0 * reach / maxf(shown.x, shown.y if view == "plan" else shown.x)
		var axes: Array = VIEWS[view]
		var basis := Basis(out, Vector3.UP, out.cross(Vector3.UP))
		var centre: Vector2 = box.get_center()
		var off: Vector3 = (axes[0] as Vector3) * (centre.x - anchor.x) * shows.x + (axes[1] as Vector3) * (anchor.y - centre.y) * shows.y + (axes[2] as Vector3) * depth
		var frame := Transform3D(basis, middle - basis * (off * size))
		_card(picture, frame, size, middle, reach, first.phase)


## A card with `picture` on it, in the frame of the sprig it shows: where its
## twig begins and how it is turned, and `size` times the size it was grown
## at. `middle` and `reach` are the tuft it is part of, for its normals, and
## `phase` where in its sway it is next to the others.
func _card(picture: Dictionary, frame: Transform3D, size: float, middle: Vector3, reach: float, phase: float) -> void:
	var st := _tool(NEEDLES, 0, frame.origin)
	var axes: Array = VIEWS[picture.view]
	var right: Vector3 = axes[0]
	var up: Vector3 = axes[1]
	var back: Vector3 = axes[2]
	var box: Rect2 = picture.box
	var rect: Rect2 = picture.rect
	var anchor: Vector2 = picture.anchor
	var shows: Vector2 = picture.size
	var depth: float = picture.depth
	var corners: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	var colours: Array[Color] = []
	var lies := 1.0 if picture.view == "plan" else 0.0
	for corner: Vector2 in [Vector2(box.position.x, box.end.y), Vector2(box.end.x, box.end.y), Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.position.y)]:
		var local: Vector3 = right * (corner.x - anchor.x) * shows.x + up * (anchor.y - corner.y) * shows.y + back * depth
		var point: Vector3 = frame * (local * size)
		corners.append(point)
		var of_tuft: Vector3 = ((point - middle) / maxf(reach, 0.01)).limit_length(1.0) + Vector3.UP * 0.35
		normals.append((of_tuft.normalized() * 0.5 + _crown_normal(point) * 0.5).normalized())
		uvs.append((rect.position + corner * rect.size) / _sheet)
		var sway := clampf(Vector2(point.x - _crown_at.x, point.z - _crown_at.z).length() / _crown_size.x, 0.2, 1.0)
		colours.append(Color(sway, phase, _crown_light(point), lies))
	_quad(st, corners, normals, uvs, colours)


## Which way a point of the crown faces, as part of the whole crown.
func _crown_normal(point: Vector3) -> Vector3:
	return (((point - _crown_at) / _crown_size).normalized() + Vector3.UP * 0.6).normalized()


## How much light gets to a point of the crown: more the further out it is
## and the higher up.
func _crown_light(point: Vector3) -> float:
	var from_middle := (point - _crown_at) / _crown_size
	return clampf(from_middle.length() * 0.75 + clampf(from_middle.y, -1.0, 1.0) * 0.3 + 0.15, 0.0, 1.0)


# --- Thorn scrub -------------------------------------------------------------------


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
	_seen(0.0, FAR, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	for i in 7:
		var turn := i * TAU / 7.0 + _dice.randf_range(-0.3, 0.3)
		var out := Vector3(cos(turn), 0, sin(turn))
		var reach := spread * _dice.randf_range(0.55, 0.95)
		var top := out * reach + Vector3.UP * height * _dice.randf_range(0.5, 0.85)
		var stem: Array[Vector3] = [out * 0.1, out * reach * 0.4 + Vector3.UP * height * 0.35, top]
		var widths: Array[float] = [0.035, 0.025, 0.01]
		_tube(BARK, stem, widths, 3, _all(BARK_DEAD, 3))
		_pad("thorn_scrub", top, (out + Vector3.UP * 0.8).normalized(), spread * _dice.randf_range(0.9, 1.2))
		_pad("thorn_scrub", out * reach * 0.6 + Vector3.UP * height * 0.3, out, spread * _dice.randf_range(0.8, 1.0))
	_pad("thorn_scrub", Vector3.UP * height * 0.9, Vector3.UP, spread * 1.3)
	part("Far")
	_seen(FAR, FAR_END * 0.5, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	_flat("thorn_scrub", _crown_at + Vector3.UP * height * 0.2, Vector3.UP, spread * 2.2, 0.3, 0.3)
	for stand in 2:
		_flat("thorn_scrub", _crown_at, Vector3.RIGHT.rotated(Vector3.UP, stand * PI * 0.5 + 0.3), spread * 2.1, 0.0, 0.3, height / (spread * 2.1))


## The leaves at one spot of a bush: a card that lies there, tilted the way
## its stem runs, and one that stands in it.
func _pad(mat: String, at: Vector3, way: Vector3, size: float) -> void:
	var out := Vector3(way.x, 0, way.z).normalized() if Vector2(way.x, way.z).length() > 0.05 else Vector3.RIGHT.rotated(Vector3.UP, _dice.randf() * TAU)
	var lies := (Vector3.UP + out * _dice.randf_range(0.1, 0.45) + Vector3(_dice.randf_range(-0.2, 0.2), 0, _dice.randf_range(-0.2, 0.2))).normalized()
	var sway := clampf(Vector2(at.x - _crown_at.x, at.z - _crown_at.z).length() / _crown_size.x, 0.25, 1.0)
	_flat(mat, at, lies, size, _dice.randf() * TAU, sway, 1.0, 1.0)
	var stands := (out.rotated(Vector3.UP, _dice.randf_range(-0.6, 0.6)) + Vector3.UP * 0.35).normalized()
	_flat(mat, at - Vector3.UP * size * 0.12, stands, size * 0.85, _dice.randf_range(-0.4, 0.4), sway)


## One card with the whole of a texture on it: `size` wide around `middle`,
## facing `faces` and turned `turn` in its own plane; `tall` times as high as
## it is wide. Its corners get the normal of the crown and say how they sway.
func _flat(mat: String, middle: Vector3, faces: Vector3, size: float, turn: float, sway: float, tall := 1.0, lies := 0.0) -> void:
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
		colours.append(Color(sway, phase, _crown_light(corner), lies))
	_quad(st, corners, normals, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)], colours)
