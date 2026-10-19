extends "res://tools/model_builder.gd"
## What grows tall on the dunes: pines in five shapes and thorn scrub in two.
## And what grows in the Alps: Norway spruce in three shapes, larch in two,
## dwarf mountain pine in two, and sycamore, see "The trees of the Alps"
## below. Build with tools/build_model.sh trees; stand one in a level to look
## at it with tools/benchmark.sh --quick --spawn="res://scenes/models/pine_a.scn@2,0,0,0".
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
##   Far    from FAR metres: one card that turns to whoever looks, with a
##          picture of the whole tree on it, see _far_card()
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
## The needles of a Norway spruce, of a larch in October and of a dwarf
## mountain pine, and the bark of the two trees.
const SPRUCE := "spruce_needles"
const LARCH := "larch_needles"
const DWARF := "dwarf_pine_needles"
const MAPLE := "maple_leaves"
const SPRUCE_BARK := "spruce_bark"
const LARCH_BARK := "larch_bark"
const MAPLE_BARK := "maple_bark"
## The pictures of sprigs and boughs each of those is drawn with, and where
## on their sheet each picture is.
const SHEETS := {
	NEEDLES: "res://assets/foliage/pine_sprigs.json",
	LEAVES: "res://assets/foliage/thorn_sprigs.json",
	SPRUCE: "res://assets/foliage/spruce_sprigs.json",
	LARCH: "res://assets/foliage/larch_sprigs.json",
	DWARF: "res://assets/foliage/mugo_sprigs.json",
	MAPLE: "res://assets/foliage/maple_sprigs.json",
}
## The material a pine is drawn with from afar, as one card, and what
## tools/gen_tree_cards.sh wrote of the pictures on it. Without that file a
## tree is drawn from afar as it was before there were pictures.
const FAR_PICTURE := "pine_far"
const FAR_SHEET := "res://assets/foliage/pine_far.json"
## The same for the trees of the Alps, which are pictured on a sheet of their
## own: tools/gen_tree_cards.sh alpine.
const ALPINE_FAR := "alpine_far"
const ALPINE_FAR_SHEET := "res://assets/foliage/alpine_far.json"
## From how far off a tree is its Mid and its Far, and how far its Far
## carries. A bush, which is small, is itself up to FAR. SHADE_END is how far
## off a tree still throws a shadow: as far as the sun's shadow reaches in the
## dunes, 110 m.
const NEAR := 21.0
const FAR := 62.0
const SHADE_END := 112.0
## Over how many metres either side of NEAR one drawing gives way to the
## next a tuft at a time, see shaders/tree_lod.gdshaderinc, and over how
## many before and beyond FAR. Wider is smoother and costs more, for in
## between the tree is drawn twice over.
const NEAR_BLEND := 3.0
const FAR_BLEND := 5.0
## How much thinner than the limb itself the limb is that throws its shadow:
## it has fewer sides, and its corners would stand out of the limb that is
## seen and stripe it with their own shadow, a seam of saw-teeth down every
## trunk.
const SHADE_TRUNK := 0.8
const SHADE_LIMB := 0.68
## How much further than SHADE_END a tree has to be before it no longer
## throws a shadow, and the other way: the shadow does not give way, it goes.
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
## Whether that crown is a cone, as that of a spruce or a larch is, and if so
## how high it begins and ends and how wide it is at its foot.
var _cone_on := false
var _cone := Vector3.ZERO
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
## The pictures of the trees from afar, by tree, and how many there are of a
## tree side by side and how many trees one under the other.
var _far := {}
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
## The drawings of the tree that give way to one another, by part: over
## which distances each comes in and goes out, see _seen().
var _shown := {}
## From how far off the tree that is being built is its Mid and its Far, how
## far its Far carries and over how many metres before that it goes, a tree
## at a time, how far off it throws a shadow, and over how many metres one
## drawing gives way to the next: NEAR, FAR, FAR_END, SHADE_END, NEAR_BLEND
## and FAR_BLEND for what grows on the dunes, more for the large trees of the
## Alps, see _distances().
var _near := NEAR
var _far_from := FAR
var _far_end := FAR_END
var _far_fade := 0.0
var _shade_end := SHADE_END
var _near_blend := NEAR_BLEND
var _far_blend := FAR_BLEND
## What the trunk and limbs of the tree that is being built are drawn with.
var _bark := BARK


func _describe() -> void:
	for mat: String in SHEETS:
		_read_sheet(mat)
	for far: Array in [[FAR_PICTURE, FAR_SHEET], [ALPINE_FAR, ALPINE_FAR_SHEET]]:
		if not FileAccess.file_exists(far[1]):
			continue
		var sheet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(far[1]))
		for tree: String in sheet.trees:
			var picture: Dictionary = sheet.trees[tree]
			picture["material"] = far[0]
			picture["sides"] = float(sheet.sides)
			picture["rows"] = float(sheet.rows)
			_far[tree] = picture
	# name, seed, height, girth, where the crown begins, how far it reaches,
	# how many boughs, how far the top stands out of plumb.
	_pine("pine_a", 11, 14.0, 0.26, 0.58, 3.4, 11, 0.5)
	_pine("pine_b", 23, 16.5, 0.3, 0.62, 3.8, 13, 1.0)
	_pine("pine_c", 37, 11.0, 0.22, 0.5, 3.0, 10, 0.3)
	_pine("pine_d", 41, 8.5, 0.24, 0.32, 3.9, 14, 1.4)
	_pine("pine_young", 53, 5.0, 0.1, 0.12, 1.7, 12, 0.2)
	_scrub("scrub_a", 61, 2.1, 1.6)
	_scrub("scrub_b", 67, 1.5, 2.0)
	# The Alps. name, kind, seed, height, girth, where the crown begins, how
	# wide it is at its foot, how far apart its whorls are, how many boughs to
	# a whorl, how far the top stands out of plumb.
	_conifer("spruce_old", "spruce", 101, 32.0, 0.36, 0.38, 4.5, 0.55, 5, 0.25)
	_conifer("spruce_mid", "spruce", 103, 17.5, 0.2, 0.14, 3.2, 0.48, 5, 0.15)
	_conifer("spruce_young", "spruce", 107, 6.0, 0.07, 0.0, 1.8, 0.32, 6, 0.05)
	_conifer("larch_old", "larch", 109, 27.0, 0.33, 0.4, 4.4, 0.62, 6, 0.6)
	_conifer("larch_young", "larch", 113, 20.0, 0.22, 0.24, 3.5, 0.55, 6, 0.35)
	# name, seed, height, how far its stems reach, how many there are.
	_dwarf_pine("dwarf_pine_a", 127, 2.1, 2.2, 12)
	_dwarf_pine("dwarf_pine_b", 131, 1.6, 2.5, 14)
	# name, seed, height, girth, where the crown begins, how wide it is.
	_maple("maple", 137, 17.0, 0.42, 0.2, 6.5)


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
	_distances(NEAR, FAR, FAR_END, SHADE_END, NEAR_BLEND, FAR_BLEND)
	_bark = BARK
	_cone_on = false
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
	_seen(0.0, _near, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
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
	_seen(_near, _far_from, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
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
	_seen(_far_from, _far_end, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	if _far.has(_tree):
		# One card with a picture of the whole tree on it, see _far_card().
		_far_card(_far[_tree])
	else:
		# Until the trees have been pictured: a trunk, and a card or two for
		# all a bough carries.
		var trunk: Dictionary = _limbs[0]
		var none: Array[Color] = []
		_tube(_leaf, _coarser(trunk.points), _coarser_floats(trunk.thick), 5, none, true)
		for bough: int in boughs:
			_bough_cards(boughs[bough], ["side", "front"] if _young or bough % 3 == 0 else ["side"])

	part("Shade")
	_seen(0.0, _shade_end, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
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


## The whole tree as one card, for from afar: it turns to whoever looks and
## shows the picture of the tree that tools/gen_tree_cards.sh took from
## nearest to where he stands, see shaders/tree_far.gdshader. `picture` is
## what the json says of this tree: the row of the sheet it is on, how many
## metres one of its pictures is across, where on that its foot stands and
## the part of it there is something on.
func _far_card(picture: Dictionary) -> void:
	var st := _tool(picture.material, 0, Vector3.ZERO)
	var sides: float = picture.sides
	var rows: float = picture.rows
	var size := Vector2(picture.size[0], picture.size[1])
	var foot := Vector2(picture.foot[0], picture.foot[1])
	var box: Array = picture.box
	var points: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	for corner: Vector2 in [Vector2(box[0], box[3]), Vector2(box[2], box[3]), Vector2(box[2], box[1]), Vector2(box[0], box[1])]:
		points.append(Vector3((corner.x - foot.x) * size.x, (foot.y - corner.y) * size.y, 0.0))
		uvs.append(Vector2(corner.x / sides, (float(picture.row) + corner.y) / rows))
	# Each corner says how far to the side of the stem it is: the card is
	# stood up again around the stem for whoever looks. And its colour says
	# that the tree is not turned and gets all of the light.
	for i: int in [0, 2, 1, 0, 3, 2]:
		st.set_color(Color(0.0, 1.0, 0.0, 1.0))
		st.set_normal(Vector3.BACK)
		st.set_uv(uvs[i])
		st.set_uv2(Vector2(points[i].x, 0.0))
		st.add_vertex(points[i])


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
## whether it throws a shadow. At NEAR and at FAR it gives way to the next
## drawing, or that to it. Near, it does so over NEAR_BLEND metres either
## side of NEAR, a tuft of the one where the same tuft of the other is not.
## Far, the one card comes in over FAR_BLEND metres before FAR and the
## nearer drawing goes over as many beyond it: a card and the limbs it is a
## picture of have nothing in common, and so they are both there for a
## while rather than neither. A part that only throws a shadow is there or
## not.
func _seen(from: float, to: float, shadow: GeometryInstance3D.ShadowCastingSetting) -> void:
	var mesh := _parts[_current].node as MeshInstance3D
	mesh.cast_shadow = shadow
	if shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		mesh.visibility_range_end = to
		mesh.visibility_range_end_margin = MARGIN
		return
	var coming := Vector2.ZERO
	if from == _near:
		coming = Vector2(_near - _near_blend, _near + _near_blend)
	elif from == _far_from:
		coming = Vector2(_far_from - _far_blend, _far_from)
	var going := Vector2.ZERO
	if to == _near:
		going = Vector2(_near - _near_blend, _near + _near_blend)
	elif to == _far_from:
		going = Vector2(_far_from, _far_from + _far_blend)
	elif to == _far_end and _far_fade > 0.0:
		# The far card of a tree of the Alps goes where the ground takes
		# over the wood, one tree at a time, see shaders/tree_far.gdshader.
		going = Vector2(_far_end - _far_fade, _far_end)
	mesh.visibility_range_begin = coming.x
	mesh.visibility_range_end = going.y if going.y > 0.0 else to
	_shown[_current] = Vector4(coming.x, coming.y, going.x, going.y)


## Says from how far off the tree that is being built is its Mid and its
## Far, how far its Far carries, how far off it throws a shadow, and over how
## many metres one drawing gives way to the next. `fade` is how many metres
## before `far_end` its far card begins to go.
func _distances(near: float, far: float, far_end: float, shade_end: float, near_blend: float, far_blend: float, fade := 0.0) -> void:
	_near = near
	_far_from = far
	_far_end = far_end
	_shade_end = shade_end
	_near_blend = near_blend
	_far_blend = far_blend
	_far_fade = fade


## Before the tree is written out: each of its drawings gets copies of its
## materials that say over which distances it gives way, and all are, to the
## renderer, a box around the foot of the tree. The renderer measures how far
## off a drawing is from the middle of its box, and the shaders from the
## foot: in one box the two agree, and every drawing changes over at the same
## distance. The box is as wide as the widest of them, the card from afar
## turned any way, and reaches as far under the ground as the tree stands
## over it.
##
## The copies are made here and kept in the model, not in materials/: what is
## changed in pine_needles.tres, thorn_scrub.tres, pine_trunk.tres or
## pine_far.tres shows on the trees once they are built again. An instance
## uniform would have kept one material for all, but Godot keeps those in one
## buffer for about 4000 instances, and the dunes hold 2259 drawings of
## trees: loaded a second time, after a death, the old level and the new one
## did not fit in it together.
func _finish() -> void:
	if _shown.is_empty():
		return
	var reach := 0.0
	var high := 0.0
	for part: String in _shown:
		var box := (_parts[part].node as MeshInstance3D).get_aabb()
		for corner: Vector3 in [box.position, box.end]:
			reach = maxf(reach, maxf(absf(corner.x), absf(corner.z)))
			high = maxf(high, absf(corner.y))
	var copies := {}
	for part: String in _shown:
		var mesh := _parts[part].node as MeshInstance3D
		mesh.custom_aabb = AABB(Vector3(-reach, -high, -reach), Vector3(reach, high, reach) * 2.0)
		# On the node and not on the mesh: whoever puts trees together into
		# one mesh, see _merge_tree() in tools/kit/land.gd, takes the mesh's
		# own, which give way to nothing.
		for surface in mesh.mesh.get_surface_count():
			var own := mesh.mesh.surface_get_material(surface) as ShaderMaterial
			var key := "%s %s" % [own.resource_path, _shown[part]]
			if not copies.has(key):
				var copy := own.duplicate() as ShaderMaterial
				copy.set_shader_parameter("shown", _shown[part])
				copies[key] = copy
			mesh.set_surface_override_material(surface, copies[key])
	_shown = {}


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
## `phase` where in its sway it is next to the others. `tuft_share` is how
## much of a corner's normal is that of the tuft and how much that of the
## crown: a card as long as a whole bough is no tuft, and the half of it
## near the trunk would face inwards.
func _card(picture: Dictionary, frame: Transform3D, size: float, middle: Vector3, reach: float, phase: float, tuft_share := 0.5) -> void:
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
		normals.append((of_tuft.normalized() * tuft_share + _crown_normal(point) * (1.0 - tuft_share)).normalized())
		uvs.append((rect.position + corner * rect.size) / _sheet)
		var sway := clampf(Vector2(point.x - _crown_at.x, point.z - _crown_at.z).length() / _crown_size.x, 0.2, 1.0)
		colours.append(Color(sway, phase, _crown_light(point), lies))
	_quad(st, corners, normals, uvs, colours)


## Which way a point of the crown faces, as part of the whole crown.
func _crown_normal(point: Vector3) -> Vector3:
	if _cone_on:
		# Out from the trunk and a little up, as the side of a slender cone
		# faces: in a low sun one side of it is lit and the other is not.
		var out := Vector3(point.x, 0.0, point.z)
		if out.length() < 0.05:
			return Vector3.UP
		var slope := atan2(_cone.z, _cone.y - _cone.x)
		return (out.normalized() * cos(slope) + Vector3.UP * (sin(slope) + 0.2)).normalized()
	return (((point - _crown_at) / _crown_size).normalized() + Vector3.UP * 0.6).normalized()


## How much light gets to a point of the crown: more the further out it is
## and the higher up.
func _crown_light(point: Vector3) -> float:
	if _cone_on:
		var up := clampf((point.y - _cone.x) / (_cone.y - _cone.x), 0.0, 1.0)
		var wide := _cone.z * pow(1.0 - up, 0.9) + 0.3
		var out := Vector2(point.x, point.z).length() / wide
		return clampf(out * 0.85 + up * 0.25 + (0.25 if _young else 0.0), 0.0, 1.0)
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
	_distances(NEAR, FAR, FAR_END, SHADE_END, NEAR_BLEND, FAR_BLEND)
	_bark = BARK
	_cone_on = false
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

	_seen(0.0, _far_from, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	for limb: Dictionary in _limbs:
		_tube(_leaf, limb.points, limb.thick, 3, none, true)
	_tangle(height, spread)
	for tuft: Dictionary in _tufts:
		for view: String in (tuft.views as String).split(" "):
			_sprig_card(tuft, view, 1.0)
	part("Far")
	_seen(_far_from, _far_end * 0.5, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
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


# --- The trees of the Alps ---------------------------------------------------------
#
# Norway spruce, larch and dwarf mountain pine, planted in tens of thousands
# by the level (tools/levels/alps/plan.gd) and drawn as MultiMeshes, cell by
# cell (scripts/grove.gd): nothing of a tree may need a node or a uniform of
# its own, and every drawing gives way to the next in its shaders, by the
# distance to the foot of that one tree. The drawings are those of the
# pines: Body, Mid, Far as one card, and Shade, which only throws the shadow.
#
# What differs is the crown. A spruce of the mountains is a slender cone of
# whorls, a whorl of boughs for every year, and every bough is a comb: a
# limb that leaves the trunk level and turns up at its end, with the twigs
# it put out hanging under it like a curtain. A card here is a picture of
# such a whole bough (tools/gen_sprigs.py, comb_bough()), one that stands
# along the bough and one that lies, rather than plates of sprigs. A larch is
# built the same way, more open and less even, in gold. And the sun is low:
# a crown's corners face out from its trunk, so that one side of the cone is
# lit and the other is in its own shade.

## How far off a tree of the Alps is still drawn as a card: further off, the
## ground draws the wood as crowns. It goes over the last ALPINE_FAR_FADE
## metres before that, a tree at a time. A dwarf pine, which is low, goes
## sooner.
const ALPINE_FAR_END := 1500.0
const ALPINE_FAR_FADE := 160.0
const DWARF_FAR_END := 800.0
## How long the limb of each whole bough on a sheet is, in the order of the
## sheet, as assets/manifest.json grows them: a card shows a bough of some
## length at that length over this.
const BOUGH_LENGTHS := {SPRUCE: [2.6, 1.7, 0.9], LARCH: [2.4, 1.5], DWARF: [1.1, 0.8], MAPLE: [1.6, 1.2]}
## The bark of a spruce low on its trunk and high up, a larch's, and the
## stems of a dwarf pine: tints on the scanned bark.
const SPRUCE_LOW := Color(0.44, 0.4, 0.38)
const SPRUCE_HIGH := Color(0.56, 0.42, 0.35)
const LARCH_LOW := Color(0.5, 0.4, 0.36)
const LARCH_HIGH := Color(0.66, 0.45, 0.36)
const DWARF_STEM := Color(0.45, 0.42, 0.4)
const MAPLE_LOW := Color(0.62, 0.6, 0.57)
const MAPLE_HIGH := Color(0.75, 0.73, 0.68)

## The boughs of the tree that is being built: {foot, out, tilt, length, up,
## whorl, phase, which, roll}. Where on the trunk it leaves it, the way it
## runs over the ground, how far its limb rises from level (radians), how
## long it is, how high in the crown it sits (0 to 1), the whorl it is part
## of, its number for giving way (see shaders/tree_lod.gdshaderinc), dice
## for the picture it is drawn with, and how far it is turned about itself.
var _boughs: Array[Dictionary] = []


## A spruce or a larch of the Alps, as it grows in a wood on a mountain: a
## straight trunk, bare up to `crown_from` of its height but for the stubs
## and the dead branches of what it shed, and above that a whorl of boughs
## every `gap` metres, about `per_whorl` to a whorl, each shorter than the
## one below, so that the crown is a slender cone `spread` metres in radius
## at its foot. `lean` is how far its top stands out of plumb.
func _conifer(tree: String, kind: String, seed: int, height: float, girth: float, crown_from: float, spread: float, gap: float, per_whorl: int, lean: float) -> void:
	model(tree)
	var larch := kind == "larch"
	_use(LARCH if larch else SPRUCE)
	_bark = LARCH_BARK if larch else SPRUCE_BARK
	_dice.seed = seed
	_more.seed = seed * 7919 + 13
	# A tall tree gives way to its next drawing further off than a young one.
	var tall := clampf((height - 6.0) / 26.0, 0.0, 1.0)
	_distances(lerpf(16.0, 32.0, tall), lerpf(52.0, 110.0, tall), ALPINE_FAR_END, lerpf(110.0, 220.0, tall), lerpf(2.5, 4.0, tall), lerpf(5.0, 9.0, tall), ALPINE_FAR_FADE)
	var leans := Vector3.RIGHT.rotated(Vector3.UP, _dice.randf() * TAU) * lean
	var trunk: Array[Vector3] = []
	var thick: Array[float] = []
	var tints: Array[Color] = []
	_bark_cast = Color(1.0, 1.0, 1.0).lerp(Color(1.05, 0.97, 0.92) if _dice.randf() < 0.5 else Color(0.92, 0.94, 0.97), _dice.randf())
	var low := LARCH_LOW if larch else SPRUCE_LOW
	var high := LARCH_HIGH if larch else SPRUCE_HIGH
	# Closer together at the foot, where it spreads into its roots.
	for share: float in [0.0, 0.015, 0.06, 0.15, 0.3, 0.45, 0.6, 0.75, 0.88, 1.0]:
		trunk.append(Vector3(0, height * share, 0) + leans * share * share)
		thick.append(lerpf(girth, 0.025, pow(share, 0.9)))
		tints.append(low.lerp(high, smoothstep(0.35, 0.85, share)) * _bark_cast)
	thick[0] = girth * 1.45
	thick[1] = girth * 1.15
	var crown_low := height * crown_from
	_young = crown_from < 0.08
	_cone_on = true
	_cone = Vector3(crown_low, height, spread)
	_crown_at = trunk[0] + Vector3.UP * (crown_low + height) * 0.5
	_crown_size = Vector3(spread, (height - crown_low) * 0.5, spread)
	var length := height - crown_low
	tag("kind", kind)
	tag("crowns", [
		[Vector3(0, crown_low + length * 0.27, 0), Vector3(spread * 0.85, length * 0.28, spread * 0.85)],
		[Vector3(0, crown_low + length * 0.66, 0), Vector3(spread * 0.5, length * 0.3, spread * 0.5)],
	])
	tag("girth", girth)
	tag("height", height)
	tag("far_end", _far_end)
	_limbs = [{"points": trunk, "thick": thick, "tints": tints, "order": 0}]
	_tufts = []
	_boughs = []
	_ends = 0
	if not _young:
		_shed(trunk, girth, height, crown_low)
	var whorl := 0
	var at := crown_low + gap * _dice.randf_range(0.0, 0.6)
	while at < height - 0.4:
		var up := (at - crown_low) / length
		var reach := spread * pow(1.0 - up, 1.0 if larch else 1.08)
		# The lowest live boughs of a tree in a wood are short: they are in
		# the shade of the rest. A young tree in the open has none such.
		if not _young:
			reach *= lerpf(0.8, 1.0, smoothstep(0.0, 0.1, up))
		var count := per_whorl + _dice.randi_range(-1, 1)
		var first := whorl * 2.39996 + _dice.randf() * 0.6
		var share := at / height
		var foot := _spot_on(trunk, share)
		var width := _width_on(thick, share)
		for i in count:
			# A larch is open and uneven: a bough is missing here and there.
			if larch and _dice.randf() < 0.1:
				continue
			var turn := first + i * TAU / count + _dice.randf_range(-0.3, 0.3)
			var out := Vector3(cos(turn), 0.0, sin(turn))
			var rises := lerpf(-10.0, 42.0, up) + _dice.randf_range(-12.0, 12.0) if larch else lerpf(-16.0, 34.0, pow(up, 1.2)) + _dice.randf_range(-7.0, 7.0)
			var tilt := deg_to_rad(rises)
			var long := reach * _dice.randf_range(0.86, 1.12) * (_dice.randf_range(0.7, 1.2) if larch else 1.0) / maxf(cos(tilt), 0.6)
			_boughs.append({
				"foot": foot + out * width * 0.8, "out": out, "tilt": tilt, "length": maxf(long, 0.22),
				"up": up, "whorl": whorl, "phase": _dice.randf(), "which": _dice.randi(), "roll": _dice.randf_range(-0.14, 0.14),
			})
		whorl += 1
		at += gap * _dice.randf_range(0.8, 1.2)
	_draw_conifer(tree)


## What a tree of a wood keeps of the boughs it shed on its way up, on the
## bare trunk below `crown_low`: stubs low down, and just under the crown,
## dead branches that still hang on with their twigs.
func _shed(trunk: Array[Vector3], girth: float, height: float, crown_low: float) -> void:
	var stubs := clampi(int(crown_low / 0.6), 0, 18)
	for i in stubs:
		var h := _dice.randf_range(1.6, crown_low)
		var foot := _spot_on(trunk, h / height)
		var way := (Vector3.RIGHT.rotated(Vector3.UP, _dice.randf() * TAU) + Vector3.UP * _dice.randf_range(-0.5, 0.1)).normalized()
		var near_crown := smoothstep(crown_low * 0.55, crown_low, h)
		var reach := lerpf(0.12, 0.45, near_crown) * _dice.randf_range(0.6, 1.4)
		var start := girth * lerpf(0.12, 0.07, near_crown)
		if near_crown > 0.4 and _dice.randf() < 0.4:
			_dead_branch(foot, way, reach * 3.0, start)
			continue
		var points: Array[Vector3] = [foot, foot + way * reach + Vector3.DOWN * reach * _dice.randf_range(0.0, 0.2)]
		var widths: Array[float] = [start, start * 0.45]
		_limbs.append({"points": points, "thick": widths, "tints": _all(BARK_STUB, 2), "order": 3, "stub": true})


## The thickness of a limb at a share of its length.
func _width_on(thick: Array[float], share: float) -> float:
	var at := clampf(share, 0.0, 1.0) * (thick.size() - 1)
	var i := mini(int(at), thick.size() - 2)
	return lerpf(thick[i], thick[i + 1], at - i)


## Draws the spruce or the larch that was grown, once for every distance it
## is seen from, and once more for its shadow.
func _draw_conifer(tree: String) -> void:
	_seen(0.0, _near, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for limb: Dictionary in _limbs:
		if limb.order == 0:
			_tube(_bark, limb.points, limb.thick, 8, limb.tints)
		else:
			_tube(_bark, limb.points, limb.thick, 3, limb.tints, false, not limb.has("spur"))
	# Each bough as it is seen from beside, from above and along it: a card
	# that stands along a bough is seen edge on from where the bough points,
	# and without the one across it the crown would be a fan with the trunk
	# in front of it.
	for i in _boughs.size():
		var bough := _boughs[i]
		_comb_cards(bough, ["side", "plan", "front"])
		# What can be reached from the ground is seen from close by: the
		# spray at its end as sprigs, sharper than a picture of the whole.
		if (bough.foot as Vector3).y < 3.5:
			_comb_sprigs(bough)
	_spire(1.0)

	# From the middle distance every other whorl stands for two, and a few
	# lie, for whoever looks down on the wood from a mountain.
	part("Mid")
	_seen(_near, _far_from, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var trunk: Dictionary = _limbs[0]
	# Inside a spruce's crown the trunk is hidden, and would show through the
	# gaps a coarser crown has as a pale line: it stops a third of the way up.
	var stem: Array[Vector3] = _coarser(trunk.points)
	var stem_thick: Array[float] = _coarser_floats(trunk.thick)
	var stem_tints: Array[Color] = _coarser_colours(trunk.tints)
	if _leaf == SPRUCE:
		var hidden := _cone.x + (_cone.y - _cone.x) * 0.35
		while stem.size() > 2 and stem[stem.size() - 2].y > hidden:
			stem.resize(stem.size() - 1)
			stem_thick.resize(stem_thick.size() - 1)
			stem_tints.resize(stem_tints.size() - 1)
		var last := stem.size() - 1
		var share := (hidden - stem[last - 1].y) / maxf(stem[last].y - stem[last - 1].y, 0.01)
		stem_thick[last] = lerpf(stem_thick[last - 1], stem_thick[last], clampf(share, 0.0, 1.0))
		stem[last] = stem[last - 1].lerp(stem[last], clampf(share, 0.0, 1.0))
	_tube(_bark, stem, stem_thick, 5, stem_tints)
	for limb: Dictionary in _limbs:
		var points: Array[Vector3] = limb.points
		if limb.order == 3 and not limb.has("spur") and not limb.has("stub") and points[0].distance_to(points[points.size() - 1]) > 0.9:
			_tube(_bark, _coarser(points), _coarser_floats(limb.thick), 3, _coarser_colours(limb.tints))
	# Every bough of every other whorl stands for the one under it as well,
	# seen from beside or along it by turns, so that there is about as much
	# to see of the crown from any side.
	for i in _boughs.size():
		var bough := _boughs[i]
		if bough.whorl % 2 == 0:
			_comb_cards(bough, ["side"] if i % 2 == 0 else ["front"], 1.15, 1.6)
			if i % 6 == 0:
				_comb_cards(bough, ["front"], 1.15, 1.6)
		elif bough.whorl % 8 == 1 and _leaf == SPRUCE:
			# Something to see from above: a larch is open enough without.
			_comb_cards(bough, ["plan"], 1.1)
	_spire(1.15)

	part("Far")
	_seen(_far_from, _far_end, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	if _far.has(tree):
		_far_card(_far[tree])
	else:
		# Until the trees have been pictured: the trunk, and every third
		# whorl standing for three.
		_tube(_bark, _coarser(trunk.points), _coarser_floats(trunk.thick), 4, _coarser_colours(trunk.tints))
		for bough: Dictionary in _boughs:
			if bough.whorl % 3 == 0:
				_comb_cards(bough, ["side"], 1.2)

	# The sun is low in the Alps, and what throws its shadow has to stand:
	# a card that lies is seen along its plane from there. The trunk runs
	# through every point of the trunk that is seen, and stays inside it.
	part("Shade")
	_seen(0.0, _shade_end, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	var thin: Array[float] = []
	for width: float in (trunk.thick as Array[float]):
		thin.append(width * SHADE_TRUNK)
	_tube(_bark, trunk.points, thin, 5, trunk.tints)
	for i in _boughs.size():
		var bough := _boughs[i]
		if bough.whorl % 2 == 0:
			_comb_cards(bough, ["side", "front"] if i % 3 == 0 else ["side"], 1.05, 1.5)
	print("%s: %d limbs, %d boughs in %d whorls" % [tree, _limbs.size(), _boughs.size(), (_boughs[_boughs.size() - 1].whorl as int) + 1 if not _boughs.is_empty() else 0])


## The frame of a bough: its limb along X, from the trunk, with Y up as the
## bough sees it, `stretch` times as long.
func _bough_frame(bough: Dictionary, stretch := 1.0) -> Transform3D:
	var out: Vector3 = bough.out
	var tilt: float = bough.tilt
	var along := out * cos(tilt) + Vector3.UP * sin(tilt)
	var lift := Vector3.UP * cos(tilt) - out * sin(tilt)
	var basis := Basis(along, lift, along.cross(lift)).rotated(along, bough.roll)
	return Transform3D(Basis(basis.x, basis.y * stretch, basis.z), bough.foot)


## The cards of one bough of a spruce or a larch, from the sides `views`
## names: a picture of a whole bough of about its length, its limb along
## that of the bough. `larger` is how much larger than the bough they are, in
## a drawing that has fewer of them, and `stretch` how much further down
## they reach than they are long: a bough that stands for the whorl under it
## as well hangs that much lower.
func _comb_cards(bough: Dictionary, views: Array, larger := 1.0, stretch := 1.0) -> void:
	var lengths: Array = BOUGH_LENGTHS[_leaf]
	var long: float = bough.length
	# The picture of the longest bough that is not much longer than this.
	var which := lengths.size() - 1
	for i in lengths.size():
		if long >= (lengths[i] as float) * 0.72:
			which = i
			break
	var size := long / (lengths[which] as float) * larger
	var frame := _bough_frame(bough, stretch)
	var middle := frame * (Vector3(long * 0.55, -long * 0.12, 0.0))
	for view: String in views:
		var pictures: Array = _pictures["bough " + view]
		var picture: Dictionary = pictures[which % pictures.size()]
		_card(picture, frame, size, middle, long * 0.6, bough.phase, 0.2 if _cone_on else 0.5)


## The end of a bough as sprigs, for whoever stands next to it: the spray it
## ends in, lying, and one that stands through it.
func _comb_sprigs(bough: Dictionary) -> void:
	var frame := _bough_frame(bough)
	var long: float = bough.length
	var size := clampf(long * 0.45, 0.5, 1.2)
	var tip := frame * Vector3(long - size * 0.32, size * 0.04, 0.0)
	var tuft := {"frame": Transform3D(frame.basis, tip), "size": size, "which": bough.which, "phase": bough.phase}
	_sprig_card(tuft, "plan", 1.0)
	_sprig_card(tuft, "side", 1.0)


## The leader at the top of a spruce or a larch, this year's shoot straight
## up: two sprigs standing through each other.
func _spire(larger: float) -> void:
	var trunk: Dictionary = _limbs[0]
	var points: Array[Vector3] = trunk.points
	var top := points[points.size() - 1]
	var size := 1.3 * larger
	var turn := Vector3.RIGHT.rotated(Vector3.UP, _dice.randf() * TAU)
	var tuft := {"frame": Transform3D(Basis(Vector3.UP, turn.cross(Vector3.UP), turn), top - Vector3.UP * size * 0.45), "size": size, "which": 1, "phase": 0.99}
	_sprig_card(tuft, "side", 1.0)
	_sprig_card(tuft, "front", 1.0)


## Dwarf mountain pine, Latschen: a bush of crooked stems out of one foot
## that creep over the ground and then rise, `height` high and reaching
## `spread` metres from its foot, dense and dark, with a brush of needles at
## every end. Above the tree line it covers whole slopes; below it, it is
## cover on the scree.
func _dwarf_pine(tree: String, seed: int, height: float, spread: float, stems: int) -> void:
	model(tree)
	_use(DWARF)
	_bark = SPRUCE_BARK
	_cone_on = false
	_young = false
	_dice.seed = seed
	_distances(24.0, 70.0, DWARF_FAR_END, 90.0, 3.0, 6.0, 90.0)
	_crown_size = Vector3(spread, height * 0.55, spread)
	_crown_at = Vector3(0, height * 0.45, 0)
	tag("kind", "dwarf_pine")
	tag("crowns", [[Vector3(0, height * 0.42, 0), Vector3(spread * 0.85, height * 0.48, spread * 0.85)]])
	tag("girth", 0.0)
	tag("height", height)
	tag("far_end", _far_end)
	_limbs = []
	_tufts = []
	_boughs = []
	for i in stems:
		var turn := i * TAU / stems + _dice.randf_range(-0.35, 0.35)
		var out := Vector3(cos(turn), 0.0, sin(turn))
		var reach := spread * _dice.randf_range(0.5, 1.0)
		# The longest creep the furthest and rise the least.
		var rise := height * _dice.randf_range(0.6, 1.0) * lerpf(1.1, 0.7, reach / spread)
		var aside := out.cross(Vector3.UP) * reach * _dice.randf_range(-0.25, 0.25)
		var bend := reach * _dice.randf_range(0.4, 0.7)
		var points: Array[Vector3] = [out * 0.05 + Vector3.UP * 0.05, out * bend * 0.5 + aside * 0.3 + Vector3.UP * 0.1, out * bend + aside * 0.6 + Vector3.UP * rise * 0.28, out * reach + aside + Vector3.UP * rise]
		var widths: Array[float] = [0.07, 0.05, 0.035, 0.012]
		_limbs.append({"points": points, "thick": widths, "tints": _all(DWARF_STEM, 4), "order": 1})
		var along := (points[3] - points[2]).normalized()
		var level := Vector3(along.x, 0.0, along.z).normalized()
		_boughs.append({
			"foot": points[2], "out": level, "tilt": asin(clampf(along.y, -1.0, 1.0)) * 0.45, "length": points[2].distance_to(points[3]) * 1.25,
			"up": 0.5, "whorl": i, "phase": _dice.randf(), "which": _dice.randi(), "roll": _dice.randf_range(-0.3, 0.3),
		})
		# The brushes: one at its end, standing, and one on the way up.
		_tuft(points[3] - along * 0.15, (along + Vector3.UP * 0.5).normalized(), 1.15, "plan side", i, i, level)
		_tuft(_spot_on(points, 0.72), (out + Vector3.UP * 0.7).normalized(), 1.0, "side front", i, i, level)

	_seen(0.0, _near, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for limb: Dictionary in _limbs:
		_tube(_bark, limb.points, limb.thick, 3, limb.tints)
	_tangle(height, spread)
	for bough: Dictionary in _boughs:
		_comb_cards(bough, ["side", "front"])
	for tuft: Dictionary in _tufts:
		for view: String in (tuft.views as String).split(" "):
			_sprig_card(tuft, view, 1.0)
	part("Mid")
	_seen(_near, _far_from, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_tangle(height, spread)
	for bough: Dictionary in _boughs:
		if bough.whorl % 2 == 0:
			_comb_cards(bough, ["side"], 1.15)
	part("Far")
	_seen(_far_from, _far_end, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	if _far.has(tree):
		_far_card(_far[tree])
	else:
		_tangle(height, spread)
	part("Shade")
	_seen(0.0, _shade_end, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	_tangle(height, spread)
	print("%s: %d stems, %d brushes" % [tree, _limbs.size(), _tufts.size()])


## A sycamore of the meadows by the farms, alone in the open: a short stout
## trunk that forks into a few limbs going up and out, and a broad dome of a
## crown `spread` metres in radius, in October yellow and gold. The crown is
## clumps of leaves on the outside of the dome, each a picture of a whole
## branch end facing out, with the limbs that carry them showing between.
func _maple(tree: String, seed: int, height: float, girth: float, crown_from: float, spread: float) -> void:
	model(tree)
	_use(MAPLE)
	_bark = MAPLE_BARK
	_cone_on = false
	_young = false
	_dice.seed = seed
	_more.seed = seed * 7919 + 13
	_distances(30.0, 100.0, ALPINE_FAR_END, 200.0, 4.0, 8.0, ALPINE_FAR_FADE)
	var crown_low := height * crown_from
	_crown_size = Vector3(spread, (height - crown_low) * 0.52, spread)
	_crown_at = Vector3(0, crown_low + (height - crown_low) * 0.5, 0)
	tag("kind", "maple")
	tag("crowns", [[_crown_at, Vector3(spread * 0.9, _crown_size.y * 0.9, spread * 0.9)]])
	tag("girth", girth)
	tag("height", height)
	tag("far_end", _far_end)
	_limbs = []
	_tufts = []
	_boughs = []
	_bark_cast = Color(1.0, 1.0, 1.0)
	# The trunk, up to where it forks.
	var fork := crown_low * 1.25
	var trunk: Array[Vector3] = []
	var thick: Array[float] = []
	for share: float in [0.0, 0.03, 0.12, 0.4, 0.75, 1.0]:
		trunk.append(Vector3(0.0, fork * share, 0.0))
		thick.append(lerpf(girth, girth * 0.8, share))
	thick[0] = girth * 1.4
	_limbs.append({"points": trunk, "thick": thick, "tints": _all(MAPLE_LOW, trunk.size()), "order": 0})
	# The limbs: up and out from the fork, each with a bend in it, and the
	# leader on up the middle.
	var scaffold: Array = []
	var limbs := 5
	for i in limbs + 1:
		var lead := i == limbs
		var turn := i * TAU / limbs + _dice.randf_range(-0.3, 0.3)
		var out := Vector3(cos(turn), 0.0, sin(turn))
		var tip := _crown_at + (Vector3.UP * _crown_size.y * 0.75 if lead else out * spread * 0.62 + Vector3.UP * _crown_size.y * _dice.randf_range(-0.05, 0.4))
		var foot := trunk[trunk.size() - 1]
		var bend := (foot + tip) * 0.5 + out * spread * 0.12 + Vector3(_dice.randf_range(-1, 1), 0, _dice.randf_range(-1, 1)) * 0.4
		var points: Array[Vector3] = [foot, foot.lerp(bend, 0.6), bend, bend.lerp(tip, 0.6), tip]
		var widths: Array[float] = [girth * 0.62, girth * 0.5, girth * 0.4, girth * 0.25, girth * 0.12]
		_limbs.append({"points": points, "thick": widths, "tints": _all(MAPLE_HIGH, points.size()), "order": 1})
		scaffold.append(points)
	# The clumps of leaves, spread evenly over the dome.
	var clumps := 72
	for i in clumps:
		var y := 1.0 - (i + 0.5) / clumps * 1.7
		var ring := sqrt(maxf(0.0, 1.0 - y * y))
		var turn := i * 2.39996 + _dice.randf_range(-0.2, 0.2)
		var way := Vector3(cos(turn) * ring, y, sin(turn) * ring)
		var spot := _crown_at + way * _crown_size * _dice.randf_range(0.78, 0.98)
		var long := spread * _dice.randf_range(0.32, 0.42)
		var level := Vector3(way.x, 0.0, way.z)
		level = level.normalized() if level.length() > 0.1 else Vector3.RIGHT.rotated(Vector3.UP, turn)
		var tilt := clampf(asin(clampf(way.y, -1.0, 1.0)) * 0.8 + deg_to_rad(15.0), deg_to_rad(-20.0), deg_to_rad(65.0))
		var along := level * cos(tilt) + Vector3.UP * sin(tilt)
		var foot := spot - along * long * 0.55
		_boughs.append({"foot": foot, "out": level, "tilt": tilt, "length": long, "up": (y + 1.0) * 0.5, "whorl": i, "phase": _dice.randf(), "which": _dice.randi(), "roll": _dice.randf_range(-0.25, 0.25)})
		# What carries it: a branch from the nearest limb.
		var nearest := Vector3.ZERO
		var best := INF
		for points: Array[Vector3] in scaffold:
			for point: Vector3 in points.slice(1):
				if point.distance_to(foot) < best:
					best = point.distance_to(foot)
					nearest = point
		if i % 2 == 0:
			var branch: Array[Vector3] = [nearest, foot + along * long * 0.2]
			var widths: Array[float] = [girth * 0.12, girth * 0.04]
			_limbs.append({"points": branch, "thick": widths, "tints": _all(MAPLE_HIGH, 2), "order": 2})

	_seen(0.0, _near, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for limb: Dictionary in _limbs:
		_tube(_bark, limb.points, limb.thick, [8, 5, 3][limb.order], limb.tints)
	for i in _boughs.size():
		var bough := _boughs[i]
		_comb_cards(bough, ["side", "plan", "front"] if i % 3 == 0 else ["side", "plan"])
		if (bough.foot as Vector3).y < 5.0:
			_comb_sprigs(bough)
	part("Mid")
	_seen(_near, _far_from, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for limb: Dictionary in _limbs:
		if limb.order < 2:
			_tube(_bark, _coarser(limb.points), _coarser_floats(limb.thick), [5, 3][limb.order], _coarser_colours(limb.tints))
	for i in _boughs.size():
		_comb_cards(_boughs[i], ["side"] if i % 3 != 1 else ["plan"], 1.1)
	part("Far")
	_seen(_far_from, _far_end, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	if _far.has(tree):
		_far_card(_far[tree])
	else:
		for bough: Dictionary in _boughs:
			if bough.whorl % 2 == 0:
				_comb_cards(bough, ["side"], 1.2)
	part("Shade")
	_seen(0.0, _shade_end, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	for limb: Dictionary in _limbs:
		if limb.order < 2:
			var thin: Array[float] = []
			for width: float in (limb.thick as Array[float]):
				thin.append(width * SHADE_TRUNK)
			_tube(_bark, _coarser(limb.points) if limb.order > 0 else limb.points, _coarser_floats(thin) if limb.order > 0 else thin, 4, _coarser_colours(limb.tints) if limb.order > 0 else limb.tints)
	for i in _boughs.size():
		if i % 3 != 1:
			_comb_cards(_boughs[i], ["side"], 1.1)
	print("%s: %d limbs, %d clumps" % [tree, _limbs.size(), _boughs.size()])
