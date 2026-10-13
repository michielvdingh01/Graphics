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
##   Body   from close by: every limb, the plate at the end of a limb as two
##          cards, and sprigs round its rim
##   Mid    from NEAR metres: the limbs with fewer sides, and the plates
##   Far    from FAR metres: a trunk, and all a bough carries as one card
##
## None of the three throws a shadow. That is done by a fourth, Shade, which
## is never seen: a thin trunk, thin boughs, and one card that lies level for
## every plate, which is all the sun needs to dapple the ground. The shadow
## then stays what it was when the tree changes, the sun has a quarter of the
## cards to draw, and no limb is in the shadow of a coarser copy of itself.
##
## What a crown costs is how many dots its cards cover and how often one
## lies over another, not how many triangles it has: every card here is as
## small as what it shows, and there are as few as show the tree.
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
const LEAVES := "thorn_scrub"
## The pictures of sprigs and boughs each of those is drawn with, and where
## on their sheet each picture is.
const SHEETS := {NEEDLES: "res://assets/foliage/pine_sprigs.json", LEAVES: "res://assets/foliage/thorn_sprigs.json"}
## From how far off a tree is its Mid and its Far, how much further it has to
## go before it changes back, and how far its Far carries. A bush, which is
## small, is itself up to FAR. SHADE_END is how far off a tree still throws
## a shadow: as far as the sun's shadow reaches in the dunes, 110 m.
const NEAR := 21.0
const FAR := 62.0
const SHADE_END := 112.0
## How much thinner than the limb itself the limb is that throws its shadow:
## it has fewer sides, and its corners would stand out of the limb that is
## seen and stripe it with their own shadow, a seam of saw-teeth down every
## trunk.
const SHADE_TRUNK := 0.8
const SHADE_LIMB := 0.68
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
const BARK_LOW := Color(0.56, 0.6, 0.68)
const BARK_HIGH := Color(0.88, 0.68, 0.5)
## The stub of a branch that was shed, and a dead branch that still hangs:
## weathered, and darker than the trunk it sticks out of.
const BARK_STUB := Color(0.42, 0.42, 0.44)
const BARK_DEAD := Color(0.3, 0.285, 0.28)
const BARK_YOUNG := Color(0.55, 0.5, 0.44)

var _dice := RandomNumberGenerator.new()
## Dice for what was added to a tree later, so that what it had keeps the
## shape the first dice gave it.
var _more := RandomNumberGenerator.new()
## The crown that is being built, for the normals of its cards.
var _crown_at := Vector3.ZERO
var _crown_size := Vector3.ONE
## What is on each sheet, by material: {pictures, size, bark}. The pictures
## by what they show and from where ("sprig plan"), a list of {rect, size,
## anchor, depth, box} each; the size of the sheet in dots; and where on it
## the strip of bark is, 0 to 1.
var _sheets := {}
## The material the foliage of the plant that is being built is drawn with,
## and what is on its sheet.
var _leaf := NEEDLES
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
## What the bark of this tree is tinted with, over what all bark is.
var _bark_cast := Color.WHITE


func _describe() -> void:
	for mat: String in SHEETS:
		_read_sheet(mat)
	# name, seed, height, girth, where the crown begins, how far it reaches,
	# how many boughs, how far the top stands out of plumb.
	_pine("pine_a", 11, 14.0, 0.26, 0.58, 3.4, 11, 0.5)
	_pine("pine_b", 23, 16.5, 0.3, 0.62, 3.8, 13, 1.0)
	_pine("pine_c", 37, 11.0, 0.22, 0.5, 3.0, 10, 0.3)
	_pine("pine_d", 41, 8.5, 0.24, 0.32, 3.9, 14, 1.4)
	_pine("pine_young", 53, 5.0, 0.1, 0.12, 1.7, 12, 0.2)
	_scrub("scrub_a", 61, 2.1, 1.6)
	_scrub("scrub_b", 67, 1.5, 2.0)


## Reads what tools/gen_sprigs.py wrote next to the sheet of a material.
func _read_sheet(mat: String) -> void:
	var sheet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHEETS[mat]))
	var size := Vector2(sheet.size[0], sheet.size[1])
	var pictures := {}
	var bark := Rect2()
	for picture: Dictionary in sheet.pictures:
		var rect := Rect2(picture.rect[0], picture.rect[1], picture.rect[2], picture.rect[3])
		if picture.view == "bark":
			bark = Rect2(rect.position / size, rect.size / size)
			continue
		var key := "%s %s" % [picture.what, picture.view]
		if not pictures.has(key):
			pictures[key] = []
		(pictures[key] as Array).append({
			"view": picture.view,
			"rect": rect,
			"size": Vector2(picture.size[0], picture.size[1]),
			"anchor": Vector2(picture.anchor[0], picture.anchor[1]),
			"depth": float(picture.depth),
			"box": Rect2(picture.box[0], picture.box[1], picture.box[2] - picture.box[0], picture.box[3] - picture.box[1]),
		})
	_sheets[mat] = {"pictures": pictures, "size": size, "bark": bark}


## Says which material the foliage of what is built from here on is drawn
## with.
func _use(mat: String) -> void:
	_leaf = mat
	_pictures = _sheets[mat].pictures
	_sheet = _sheets[mat].size
	_bark_strip = _sheets[mat].bark


## One pine: a bare trunk with the stubs of dead branches on it, and from
## `crown_from` of its height up the boughs that carry the crown. A pine whose
## crown begins near the ground is a young one: dense and pointed, a whorl of
## branches for every year.
func _pine(tree: String, seed: int, height: float, girth: float, crown_from: float, spread: float, boughs: int, lean: float) -> void:
	model(tree)
	_use(NEEDLES)
	_dice.seed = seed
	_more.seed = seed * 7919 + 13
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
	# Every tree has its own bark: one greyer, the next redder.
	_bark_cast = Color(1.0, 1.0, 1.0).lerp(Color(1.06, 0.97, 0.9) if _dice.randf() < 0.5 else Color(0.9, 0.93, 0.96), _dice.randf())
	var tints: Array[Color] = []
	for i in trunk.size():
		tints.append(BARK_LOW.lerp(BARK_HIGH, smoothstep(0.42, 0.72, i / 6.0)) * _bark_cast)
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
		var long := _dice.randf() < 0.15
		var reach := _dice.randf_range(0.6, 1.1) if long else _dice.randf_range(0.1, 0.32)
		var start := girth * (0.17 if long else 0.24)
		var crook := Vector3(_dice.randf_range(-1, 1), _dice.randf_range(-0.6, 0.2), _dice.randf_range(-1, 1)) * reach * 0.08
		var sag := _dice.randf_range(0.05, 0.2)
		if long:
			_dead_branch(foot, way, reach * 1.5, start * 0.8)
			continue
		var points: Array[Vector3] = [foot, foot + way * reach * 0.5 + crook, foot + way * reach + Vector3.DOWN * reach * sag]
		var widths: Array[float] = [start, start * 0.7, start * 0.55]
		_limbs.append({"points": points, "thick": widths, "tints": _all(BARK_STUB, 3), "order": 3})
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
			_limbs.append({"points": twig, "thick": widths, "tints": _all(BARK_HIGH * _bark_cast, 3), "order": 2})
			_cloud(twig, i, lerpf(1.55, 1.3, up))
	# The top: what the trunk itself ends in, a plate to either side.
	var head := trunk[trunk.size() - 1]
	var first := _dice.randf() * TAU
	for i in 2:
		var out := Vector3.RIGHT.rotated(Vector3.UP, first + i * PI + _dice.randf_range(-0.4, 0.4))
		var top: Array[Vector3] = [head - Vector3.UP * 0.5, head + out * 0.5 + Vector3.UP * 0.1]
		_cloud(top, boughs, 1.5)


## A branch that died and has not come down yet, from `foot` on the trunk
## along `way`: it hangs, it has the kinks of every year it lost its tip,
## what forked off it is still on it as a spur or two, and it ends where it
## broke. Grey, and never straight.
func _dead_branch(foot: Vector3, way: Vector3, reach: float, start: float) -> void:
	var points: Array[Vector3] = [foot]
	var widths: Array[float] = [start]
	var at := foot
	var runs := way
	var side := way.cross(Vector3.UP).normalized()
	for step in 4:
		# Down a little further with every length, and off to one side.
		runs = (runs + Vector3.DOWN * _more.randf_range(0.1, 0.34) + side * _more.randf_range(-0.42, 0.42) + Vector3.UP * _more.randf_range(-0.12, 0.2)).normalized()
		at += runs * reach * 0.25 * _more.randf_range(0.75, 1.25)
		points.append(at)
		widths.append(start * lerpf(0.78, 0.3, step / 3.0))
		if step < 3 and _more.randf() < 0.6:
			var off := (runs.rotated(Vector3.UP, (1.0 if _more.randf() < 0.5 else -1.0) * _more.randf_range(0.7, 1.2)) + Vector3.UP * _more.randf_range(-0.2, 0.35)).normalized()
			var spur := reach * _more.randf_range(0.16, 0.34)
			var spur_points: Array[Vector3] = [at, at + off * spur * 0.55 + Vector3.DOWN * spur * 0.06, at + off * spur + Vector3.DOWN * spur * _more.randf_range(0.0, 0.25)]
			var spur_widths: Array[float] = [start * 0.3, start * 0.2, start * 0.1]
			_limbs.append({"points": spur_points, "thick": spur_widths, "tints": _all(BARK_DEAD, 3), "order": 3, "spur": true})
	_limbs.append({"points": points, "thick": widths, "tints": _all(BARK_DEAD, points.size()), "order": 3})


## A young pine: a straight stem with a whorl of branches for every year it
## has grown, the lowest the longest, and needles on every one of them from
## the stem out.
func _grow_young(trunk: Array[Vector3], _thick: Array[float], height: float, spread: float) -> void:
	var whorls := int(height / 0.5)
	var first_end := _ends
	for whorl in whorls:
		var up := (whorl + 0.5) / whorls
		var foot := _spot_on(trunk, lerpf(0.1, 0.95, up))
		var reach := spread * lerpf(1.0, 0.2, pow(up, 0.85)) * _dice.randf_range(0.85, 1.05)
		var branches := 5 if up < 0.6 else 4
		var first := _dice.randf() * TAU
		# The tufts of a few whorls count as one bough from afar, and from
		# the middle distance those of two whorls on one side of the stem
		# as one plate.
		@warning_ignore("integer_division")
		var tier := whorl * 4 / whorls
		for branch in branches:
			var turn := first + branch * TAU / branches + _dice.randf_range(-0.25, 0.25)
			@warning_ignore("integer_division")
			_ends = first_end + (whorl / 2) * 3 + int(fposmod(turn, TAU) / TAU * 3.0)
			var rise := deg_to_rad(lerpf(8.0, 48.0, up) + _dice.randf_range(-6, 6))
			var way := Vector3(cos(turn) * cos(rise), sin(rise), sin(turn) * cos(rise))
			var length := reach * _dice.randf_range(0.8, 1.1)
			var points: Array[Vector3] = [foot, foot + way * length * 0.55 + Vector3.DOWN * length * 0.05, foot + way * length + Vector3.UP * length * 0.16]
			var start := lerpf(0.022, 0.01, up)
			var widths: Array[float] = [start, start * 0.65, 0.005]
			_limbs.append({"points": points, "thick": widths, "tints": _all(BARK_YOUNG, 3), "order": 2})
			_sprays_along(points, tier, 0.2, lerpf(1.3, 1.0, up), 0.5)
	# The leader: this year's shoot, straight up.
	@warning_ignore("integer_division")
	_ends = first_end + (whorls / 2 + 1) * 3
	var head := trunk[trunk.size() - 1]
	for i in 3:
		_tuft(head - Vector3.UP * (0.2 + i * 0.3), (Vector3.UP + Vector3.RIGHT.rotated(Vector3.UP, _dice.randf() * TAU) * 0.25 * i).normalized(), 1.2, "side front", 3, _ends, Vector3.ZERO)
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
		tints.append(BARK_HIGH.lerp(BARK_LOW, 0.25 * (1.0 - up) * (1.0 - t)) * _bark_cast)
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
	var fan := 3
	for i in fan:
		var spread := lerpf(-1.0, 1.0, (i + _dice.randf_range(0.2, 0.8)) / fan)
		var way := (level.rotated(Vector3.UP, spread * deg_to_rad(85.0)) + Vector3.UP * _dice.randf_range(0.04, 0.24)).normalized()
		# The outer ones of the fan leave the limb further back.
		var at := end + level * size * (0.3 - 0.5 * absf(spread)) * _dice.randf_range(0.8, 1.2) + across * size * spread * 0.35 + Vector3.UP * size * _dice.randf_range(-0.04, 0.08)
		_tuft(at, way, size * _dice.randf_range(0.88, 1.12), "plan side" if i % 2 == 0 else "plan front", bough, _ends, level)
	for i in 2:
		var way := (level.rotated(Vector3.UP, _dice.randf_range(-1.0, 1.0)) * 0.75 + Vector3.UP * _dice.randf_range(0.55, 0.95)).normalized()
		var at := end - level * size * _dice.randf_range(0.0, 0.5) + across * size * _dice.randf_range(-0.4, 0.4) + Vector3.UP * size * 0.08
		_tuft(at, way, size * _dice.randf_range(0.75, 0.95), "side front", bough, _ends, level)
	_ends += 1


## The sprigs of a branch of a young pine: one at its end, and from `from`
## of its length on one to either side by turns, `step` sprigs apart. They
## belong to the limb end that _ends says.
func _sprays_along(points: Array[Vector3], bough: int, from: float, size: float, step: float) -> void:
	var last := points.size() - 1
	var heading := (points[last] - points[last - 1]).normalized()
	var level := Vector3(heading.x, 0, heading.z).normalized()
	_tuft(points[last] - heading * 0.12 * size, (heading + Vector3.UP * 0.2).normalized(), size * _dice.randf_range(1.0, 1.15), "plan side", bough, _ends, level)
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
	var ends := _grouped("end")
	var boughs := _grouped("bough")
	_seen(0.0, NEAR, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for limb: Dictionary in _limbs:
		var sides: int = [8, 5, 3, 4][limb.order]
		if limb.order == 0:
			_tube(BARK, _finer(limb.points), _finer_floats(limb.thick), sides, _finer_colours(limb.tints))
		else:
			_tube(BARK, limb.points, limb.thick, 3 if limb.has("spur") else sides, limb.tints, false, limb.order == 3 and not limb.has("spur"))
	# The mass of a plate is a picture of a whole bough end: something for a
	# crown high up, not for a young tree somebody stands next to.
	if not _young:
		for end: int in ends:
			_bough_cards(ends[end], ["plan", "side" if end % 2 == 0 else "front"])
	for tuft: Dictionary in _tufts:
		for view: String in (tuft.views as String).split(" "):
			_sprig_card(tuft, view, 1.0)

	part("Mid")
	_seen(NEAR, FAR, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for limb: Dictionary in _limbs:
		var points: Array[Vector3] = limb.points
		# What is short is a stub, or is inside the needles it carries.
		if limb.has("spur") or (limb.order >= 2 and points[0].distance_to(points[points.size() - 1]) < (0.9 if limb.order == 3 else 1.5)):
			continue
		if limb.order == 0:
			# The trunk keeps its line: its shadow is thrown by a trunk
			# that runs the same way, see Shade.
			_tube(BARK, points, limb.thick, 6, limb.tints)
		else:
			_tube(BARK, _coarser(points), _coarser_floats(limb.thick), 3, _coarser_colours(limb.tints), false, limb.order == 3)
	# A young tree has no plates: its branches stand up, with needles all
	# along them. What stands is what shows of it, and only its lowest
	# whorls, which are looked down on, lie as well.
	@warning_ignore("integer_division")
	var low := (ends.size() / 3) / 3
	for end: int in ends:
		if _young:
			@warning_ignore("integer_division")
			_bough_cards(ends[end], ["plan", "side", "front"] if end / 3 <= low else ["side", "front"])
		else:
			_bough_cards(ends[end], ["plan", "side" if end % 2 == 0 else "front"])

	# From afar a plate that lies level is seen along its plane, which is
	# not at all: what stands is what shows.
	part("Far")
	_seen(FAR, FAR_END, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var trunk: Dictionary = _limbs[0]
	var none: Array[Color] = []
	_tube(_leaf, _coarser(trunk.points), _coarser_floats(trunk.thick), 5, none, true)
	for bough: int in boughs:
		_bough_cards(boughs[bough], ["side", "front"] if _young or bough % 3 == 0 else ["side"])

	part("Shade")
	_seen(0.0, SHADE_END, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	for limb: Dictionary in _limbs:
		if limb.order >= 2:
			continue
		# The trunk runs through every point the trunk that is seen runs
		# through, and stays inside it; a bough is too thin to see stripes on.
		var whole: bool = limb.order == 0
		var thin: Array[float] = []
		for width: float in (limb.thick as Array[float]) if whole else _coarser_floats(limb.thick):
			thin.append(width * (SHADE_TRUNK if whole else SHADE_LIMB))
		_tube(BARK, limb.points if whole else _coarser(limb.points), thin, 5 if whole else 3, limb.tints if whole else _coarser_colours(limb.tints))
	for end: int in ends:
		# A young tree stands in its own shadow from its top down, whorl over
		# whorl, and was a dark cone for it: its shadow is thrown by every
		# other whorl, and by less than the whole of that.
		if _young:
			@warning_ignore("integer_division")
			if (end / 3) % 2 == 0:
				_bough_cards(ends[end], ["plan"], 0.62)
		else:
			_bough_cards(ends[end], ["plan"])
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
## foot to top. With `capped` it does have an end, where it broke off.
func _tube(mat: String, points: Array[Vector3], thick: Array[float], sides: int, tints: Array[Color], strip := false, capped := false) -> void:
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
					# The plates of the bark are longer than they are wide, but not
					# as long as the scan stretched over a trunk would make them.
					uvs = [Vector2(turns * s / sides, -run * 1.4), Vector2(turns * (s + 1) / sides, -run * 1.4), Vector2(turns * (s + 1) / sides, (-run - length) * 1.4), Vector2(turns * s / sides, (-run - length) * 1.4)]
				_quad(
					st,
					[points[i - 1] + before[s] * thick[i - 1], points[i - 1] + before[s + 1] * thick[i - 1], points[i] + around[s + 1] * thick[i], points[i] + around[s] * thick[i]],
					[before[s], before[s + 1], around[s + 1], around[s]],
					uvs,
					[WOOD, WOOD, WOOD, WOOD] if strip else [tints[i - 1], tints[i - 1], tints[i], tints[i]]
				)
			run += length
		before = around
	if capped:
		# The wood inside, paler than the bark.
		var last := points.size() - 1
		var end := points[last]
		var pale := tints[last].lerp(Color(0.8, 0.74, 0.62), 0.6)
		for s in sides:
			_tri(st, [end, end + before[s + 1] * thick[last], end + before[s] * thick[last]], [heading, heading, heading], [Vector2(0.5, 0.5), Vector2(0.6, 0.5), Vector2(0.5, 0.6)], [pale, pale, pale])


## One picture of a sprig as a card: the side `view` of the sprig `tuft`,
## `larger` times the size of the tuft.
func _sprig_card(tuft: Dictionary, view: String, larger: float) -> void:
	var pictures: Array = _pictures["sprig " + view]
	var picture: Dictionary = pictures[tuft.which % pictures.size()]
	var frame: Transform3D = tuft.frame
	var size: float = tuft.size * larger
	var middle := frame * (Vector3(0.25, 0.08, 0.0) * size)
	_card(picture, frame, size, middle, size * 0.3, tuft.phase)


## The tufts of one bough, or of one limb end, as cards with a picture of a
## whole bough end on them, from the sides `views` names: the mass of a
## plate, and what a tree is made of from afar. `smaller` is how much of
## their size the cards are, for a shadow that lets the sun past.
func _bough_cards(tufts: Array, views: Array, smaller := 1.0) -> void:
	var middle := Vector3.ZERO
	for tuft: Dictionary in tufts:
		middle += (tuft.frame as Transform3D) * (Vector3(0.25, 0.08, 0.0) * tuft.size)
	middle /= tufts.size()
	var reach := 0.0
	for tuft: Dictionary in tufts:
		reach = maxf(reach, ((tuft.frame as Transform3D) * (Vector3(0.25, 0.08, 0.0) * tuft.size)).distance_to(middle) + 0.18 * tuft.size)
	reach *= smaller
	# It runs the way its limbs do, or away from the trunk, or any way if it
	# stands round it.
	var out := Vector3.ZERO
	for tuft: Dictionary in tufts:
		out += tuft.level as Vector3
	if out.length() < 0.5 * tufts.size():
		out = Vector3(middle.x - _crown_at.x, 0, middle.z - _crown_at.z)
	var first: Dictionary = tufts[0]
	out = out.normalized() if out.length() > 0.4 else Vector3.RIGHT.rotated(Vector3.UP, first.phase * TAU)
	for view: String in views:
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
	var st := _tool(_leaf, 0, frame.origin)
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
	# A young tree stands by itself and is open to the light all the way down.
	return clampf(from_middle.length() * 0.75 + clampf(from_middle.y, -1.0, 1.0) * 0.3 + (0.4 if _young else 0.15), 0.0, 1.0)


# --- Thorn scrub -------------------------------------------------------------------


## Thorn scrub, sea buckthorn: a man high and wider than that. Stems out of
## one foot that arch outwards, a tangle of branches between them that
## nobody sees through, and sprays of narrow leaves and berries all over
## the outside of it. From afar it is the tangle alone.
func _scrub(bush: String, seed: int, height: float, spread: float) -> void:
	model(bush)
	_use(LEAVES)
	_dice.seed = seed
	_crown_size = Vector3(spread, height * 0.6, spread)
	_crown_at = Vector3(0, height * 0.5, 0)
	tag("crowns", [[_crown_at, _crown_size * 0.9]])
	tag("girth", 0.0)
	tag("height", height)
	_limbs = []
	_tufts = []
	_ends = 0
	_young = false
	var stems := 8
	var none: Array[Color] = []
	for i in stems:
		var turn := i * TAU / stems + _dice.randf_range(-0.3, 0.3)
		var out := Vector3(cos(turn), 0, sin(turn))
		var reach := spread * _dice.randf_range(0.5, 0.9)
		var top := out * reach + Vector3.UP * height * _dice.randf_range(0.55, 0.9)
		var crook := Vector3(_dice.randf_range(-1, 1), 0, _dice.randf_range(-1, 1)) * 0.12
		var stem: Array[Vector3] = [out * 0.1, out * reach * 0.35 + Vector3.UP * height * 0.38 + crook, top]
		var widths: Array[float] = [0.032, 0.022, 0.008]
		_limbs.append({"points": stem, "thick": widths, "tints": none, "order": 2})
		# What it carries: a spray up and out of its end, one to either side
		# of that, and one half-way up it, facing out.
		var size := spread * _dice.randf_range(0.95, 1.2)
		_tuft(top - out * 0.15, (out + Vector3.UP * _dice.randf_range(0.4, 0.9)).normalized(), size, "plan side", 0, 0, Vector3.ZERO)
		for hand: float in [-1.0, 1.0]:
			_tuft(top - out * 0.2 + Vector3.DOWN * 0.1, (out.rotated(Vector3.UP, hand * _dice.randf_range(0.7, 1.2)) + Vector3.UP * _dice.randf_range(0.1, 0.5)).normalized(), size * 0.9, "plan front" if hand < 0.0 else "side front", 0, 0, Vector3.ZERO)
		_tuft(_spot_on(stem, 0.6) + out * 0.1, (out + Vector3.UP * _dice.randf_range(-0.1, 0.3)).normalized(), size * 0.95, "side front", 0, 0, Vector3.ZERO)
	# Its top: what stands up out of the middle.
	for i in 3:
		var out := Vector3.RIGHT.rotated(Vector3.UP, _dice.randf() * TAU) * spread * _dice.randf_range(0.0, 0.35)
		_tuft(out + Vector3.UP * height * _dice.randf_range(0.7, 0.85), (Vector3.UP + out.normalized() * 0.5).normalized(), spread * 1.1, "plan side front", 0, 0, Vector3.ZERO)

	_seen(0.0, FAR, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	for limb: Dictionary in _limbs:
		_tube(_leaf, limb.points, limb.thick, 3, none, true)
	_tangle(height, spread)
	for tuft: Dictionary in _tufts:
		for view: String in (tuft.views as String).split(" "):
			_sprig_card(tuft, view, 1.0)
	part("Far")
	_seen(FAR, FAR_END * 0.5, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	_tangle(height, spread)
	print("%s: %d stems, %d sprays" % [bush, _limbs.size(), _tufts.size()])


## The inside of a bush: whole branches as cards that stand through each
## other and one that lies over them, large enough to fill it.
func _tangle(height: float, spread: float) -> void:
	var stands: Array = _pictures["bough side"]
	var lies: Array = _pictures["bough plan"]
	for i in 3:
		var picture: Dictionary = stands[i % stands.size()]
		var out := Vector3.RIGHT.rotated(Vector3.UP, i * PI / 3.0 + 0.3)
		_whole_card(picture, Vector3(0, height * 0.46, 0), out, Vector3.UP, spread * 1.9, height * 0.92, 0.3 + i * 0.3)
	var over: Dictionary = lies[0]
	_whole_card(over, Vector3(0, height * 0.62, 0), Vector3.RIGHT.rotated(Vector3.UP, 0.8), Vector3.FORWARD.rotated(Vector3.UP, 0.8), spread * 1.8, spread * 1.8, 0.1)


## A card with the whole of what `picture` shows on it, `wide` by `high`
## about `middle`: `right` and `up` are where the right and the top of the
## picture go.
func _whole_card(picture: Dictionary, middle: Vector3, right: Vector3, up: Vector3, wide: float, high: float, phase: float) -> void:
	var st := _tool(_leaf, 0, middle)
	var box: Rect2 = picture.box
	var rect: Rect2 = picture.rect
	var corners: Array[Vector3] = [middle - right * wide * 0.5 - up * high * 0.5, middle + right * wide * 0.5 - up * high * 0.5, middle + right * wide * 0.5 + up * high * 0.5, middle - right * wide * 0.5 + up * high * 0.5]
	var at: Array[Vector2] = [Vector2(box.position.x, box.end.y), Vector2(box.end.x, box.end.y), Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.position.y)]
	var normals: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	var colours: Array[Color] = []
	var lies := 1.0 if absf(up.y) < 0.5 else 0.0
	for i in 4:
		normals.append(_crown_normal(corners[i]))
		uvs.append((rect.position + at[i] * rect.size) / _sheet)
		var sway := clampf(corners[i].y / (_crown_size.y * 2.0), 0.0, 1.0)
		colours.append(Color(sway, phase, _crown_light(corners[i]), lies))
	_quad(st, corners, normals, uvs, colours)
