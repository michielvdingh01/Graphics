extends "res://tools/kit/power.gd"
## Sixth drawer of the kit, see tools/kit.gd: what closes a building overhead
## and what divides its walls. A roof on steel over a rectangle of walls, with
## the glass that lets the day in, and the piers, the plinth and the beam
## along the head of a wall that keep it from being one flat face.
##
## A roof is asked for by the rectangle its walls stand in (x and z, out to
## their outer faces), how thick those walls are and how high: the eaves. It
## closes that rectangle from the head of the walls up, gables included, so
## that a zone under it is shut for its bake but for the glass. roof() hands
## back what it made, and roof_height() says of that how high its underside
## hangs over a spot: for whatever is hung from it.

const NORTH := 0  # towards -Z
const SOUTH := 1
const WEST := 2  # towards -X
const EAST := 3

## How thick the sheeting of a roof is.
const SHEETING := 0.12


## A roof of one of these forms over `area`:
##
##   "flat"      a slab, as over an office
##   "slab"      a slab on concrete beams, as over a plant room
##   "beams"     sheeting on rolled steel beams, with a rooflight in every bay
##   "trusses"   a pitched roof on steel trusses, with skylights in its slopes
##   "sawtooth"  a row of pitched bays, each glazed on its steep side
##
## `fit` can say more: "ceiling" is what a slab is made of, "wall" what the
## gables are, "ridge" ("x" or "z") which way the ridge runs when that is not
## along the longer side, "bay" how far apart the trusses or the beams stand,
## "lines" where the trusses stand instead (x or z in the level, whichever
## the ridge runs along), "rise" how high the ridge lies over the eaves,
## "glass" which bays of a trussed roof have a skylight ("alternate", "all"
## or "none"), and "glazed" the side the glass of a sawtooth roof looks to.
##
## Returns the roof as roof_height() takes it. Its "bearings" are where it
## rests on the walls, {at, inwards}: at the head of the wall, on its inner
## face. Its "glass" lists the middle of every pane the day comes in by.
func roof(form: String, area: Rect2, thick: float, eaves: float, fit := {}) -> Dictionary:
	var along_x: bool = fit.get("ridge", "x" if area.size.x >= area.size.y else "z") == "x"
	var turn := 0.0 if along_x else -PI * 0.5
	if form == "sawtooth":
		# The glass looks along the local Z of the roof.
		var glazed: int = fit.get("glazed", SOUTH)
		turn = [PI, 0.0, -PI * 0.5, PI * 0.5][glazed]
		along_x = glazed == NORTH or glazed == SOUTH
	var middle := area.get_center()
	var made := {
		"form": form, "area": area, "thick": thick, "eaves": eaves, "along_x": along_x, "rise": 0.0,
		"frame": Transform3D(Basis(Vector3.UP, turn), Vector3(middle.x, eaves, middle.y)),
		"half_along": (area.size.x if along_x else area.size.y) * 0.5,
		"half_across": (area.size.y if along_x else area.size.x) * 0.5,
		"bearings": [], "glass": [],
	}
	match form:
		"flat":
			box(fit.get("ceiling", "concrete"), Vector3(middle.x, eaves + 0.15, middle.y), Vector3(area.size.x, 0.3, area.size.y))
		"slab":
			_roof_slab(made, fit)
		"beams":
			_roof_beams(made, fit)
		"trusses":
			_roof_trusses(made, fit)
		"sawtooth":
			_roof_sawtooth(made, fit)
		_:
			push_error("roof: there is no roof called '%s'" % form)
	return made


## How high the underside of a roof hangs over a spot (x and z in the level).
func roof_height(made: Dictionary, x: float, z: float) -> float:
	var at: Vector3 = (made.frame as Transform3D).affine_inverse() * Vector3(x, made.eaves, z)
	match made.form:
		"trusses":
			return made.eaves + made.rise * (1.0 - minf(1.0, absf(at.z) / made.half_across))
		"sawtooth":
			var depth: float = made.depth
			var tooth := clampi(floori((at.z + made.half_across) / depth), 0, made.teeth - 1)
			var far: float = -made.half_across + depth * tooth
			var ridge: float = far + depth - made.run
			if at.z <= ridge:
				return made.eaves + made.rise * clampf((at.z - far) / (ridge - far), 0.0, 1.0)
			return made.eaves + made.rise * clampf((far + depth - at.z) / made.run, 0.0, 1.0)
	return made.eaves


## Where a roof rests on a wall: remembered for a pier to stand under.
func _bearing(made: Dictionary, at: Vector3, inwards: Vector3) -> void:
	var frame: Transform3D = made.frame
	made.bearings.append({"at": frame * at, "inwards": (frame.basis * inwards).round()})


## A slab on concrete beams: one across the room every few metres, and a
## deeper one down its length where the room is wide.
func _roof_slab(made: Dictionary, fit: Dictionary) -> void:
	var area: Rect2 = made.area
	var frame: Transform3D = made.frame
	var mat: String = fit.get("ceiling", "concrete")
	var middle := area.get_center()
	box(mat, Vector3(middle.x, made.eaves + 0.15, middle.y), Vector3(area.size.x, 0.3, area.size.y))
	var in_l: float = made.half_along - made.thick
	var in_w: float = made.half_across - made.thick
	var bays := maxi(1, roundi(in_l * 2.0 / fit.get("bay", 4.2)))
	for i in range(1, bays):
		var x := -in_l + in_l * 2.0 * i / bays
		_local_box(mat, frame, Vector3(x, -0.25, 0), Vector3(0.36, 0.5, in_w * 2.0), NO_COLLIDE)
		for side: float in [-1.0, 1.0]:
			_bearing(made, Vector3(x, -0.5, side * in_w), Vector3(0, 0, -side))
	if in_w * 2.0 > 8.0:
		_local_box(mat, frame, Vector3(0, -0.34, 0), Vector3(in_l * 2.0, 0.68, 0.46), NO_COLLIDE)


## Sheeting on purlins on rolled steel beams that span the shorter way, with
## a rooflight down the middle of every bay between two beams.
func _roof_beams(made: Dictionary, fit: Dictionary) -> void:
	var frame: Transform3D = made.frame
	var small := DETAIL | NO_COLLIDE
	var half_l: float = made.half_along
	var half_w: float = made.half_across
	var in_l: float = half_l - made.thick
	var in_w: float = half_w - made.thick
	var bays := maxi(2, roundi(in_l * 2.0 / fit.get("bay", 4.0)))
	var bay := in_l * 2.0 / bays
	# How long a rooflight is, along the ridge, and how wide.
	var pane := Vector2(clampf(bay - 1.5, 1.2, 3.0), clampf(in_w * 0.45, 1.0, 1.8))
	var lit: Array[float] = []
	if fit.get("glass", "all") != "none":
		for i in bays:
			if fit.get("glass", "all") == "all" or i % 2 == 0:
				lit.append(-in_l + bay * (i + 0.5))
	var deck := SHEETING * 0.5
	for side: float in [-1.0, 1.0]:
		var wide := half_w - pane.y * 0.5
		_local_box("roof", frame, Vector3(0, deck, side * (pane.y * 0.5 + wide * 0.5)), Vector3(half_l * 2.0, SHEETING, wide))
	var edge := -half_l
	for x in lit:
		_local_box("roof", frame, Vector3((edge + x - pane.x * 0.5) * 0.5, deck, 0), Vector3(x - pane.x * 0.5 - edge, SHEETING, pane.y))
		# A kerb of steel lines the opening, with a bar across every metre.
		for end: float in [-1.0, 1.0]:
			_local_box("steel", frame, Vector3(x + end * pane.x * 0.5, -0.03, 0), Vector3(0.06, 0.3, pane.y + 0.06), small)
			_local_box("steel", frame, Vector3(x, -0.03, end * pane.y * 0.5), Vector3(pane.x + 0.06, 0.3, 0.06), small)
		var bars := maxi(1, roundi(pane.x / 1.0))
		for k in range(1, bars):
			_local_box("steel", frame, Vector3(x - pane.x * 0.5 + pane.x * k / bars, deck, 0), Vector3(0.05, 0.07, pane.y), small)
		_local_box("glass", frame, Vector3(x, deck, 0), Vector3(pane.x, 0.012, pane.y), GLASS | NO_COLLIDE)
		made.glass.append(frame * Vector3(x, deck, 0))
		edge = x + pane.x * 0.5
	_local_box("roof", frame, Vector3((edge + half_l) * 0.5, deck, 0), Vector3(half_l - edge, SHEETING, pane.y))
	# The beams, and the purlins that lie on them.
	_m = frame
	_part = small
	for i in range(1, bays):
		var x := -in_l + bay * i
		_i_beam(RUST, Vector3(x, -0.5, -in_w - 0.1), Vector3(x, -0.5, in_w + 0.1), 0.2, 0.38)
		for side: float in [-1.0, 1.0]:
			_bearing(made, Vector3(x, -0.5, side * in_w), Vector3(0, 0, -side))
	_part = NO_COLLIDE
	var purlins := maxi(2, roundi(in_w * 2.0 / 1.8))
	for i in purlins + 1:
		var z := -in_w + 0.12 + (in_w * 2.0 - 0.24) * i / purlins
		if absf(z) < pane.y * 0.5 + 0.1:
			continue
		_local_box("steel", frame, Vector3(0, -0.06, z), Vector3(in_l * 2.0, 0.12, 0.08), small)


## A pitched roof on steel trusses: sheeting on purlins on the rafters of a
## truss every few metres, with skylights in a strip a third of the way down
## each slope, a gable at either end and a concrete beam along the head of
## the two walls it rests on. With "lines" in `fit` the trusses stand where
## those say, along the ridge in the level: between the windows of a wall,
## say, so that each has a pier to rest on.
func _roof_trusses(made: Dictionary, fit: Dictionary) -> void:
	var frame: Transform3D = made.frame
	var small := DETAIL | NO_COLLIDE
	var thick: float = made.thick
	var half_l: float = made.half_along
	var half_w: float = made.half_across
	var in_l := half_l - thick
	var in_w := half_w - thick
	var rise: float = fit.get("rise", clampf(half_w * 0.21, 1.3, 3.0))
	made.rise = rise
	var angle := atan2(rise, half_w)
	# From the ridge down to the outer face of the wall, along the slope.
	var slope := Vector2(half_w, rise).length() + SHEETING * tan(angle)
	# Where the trusses stand along the ridge, and the bays between them.
	var lines: Array[float] = []
	if fit.has("lines"):
		for line: float in fit.lines:
			lines.append((frame.affine_inverse() * (Vector3(line, 0, frame.origin.z) if made.along_x else Vector3(frame.origin.x, 0, line))).x)
		lines.sort()
	else:
		var count := maxi(2, roundi(in_l * 2.0 / fit.get("bay", 5.5)))
		for t in range(1, count):
			lines.append(-in_l + in_l * 2.0 * t / count)
	var edges: Array[float] = [-in_l]
	edges.append_array(lines)
	edges.append(in_l)
	# The underside of the sheeting runs from the ridge to the head of the
	# wall at its outer face. Local +Z of a slope runs down it from the ridge,
	# and its sheeting hangs below local Y = 0.
	var top := Vector3(0, rise + SHEETING / cos(angle), 0)
	var slopes: Array[Transform3D] = [
		frame * Transform3D(Basis(Vector3.RIGHT, angle), top),
		frame * Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, angle), top),
	]
	var strip := Vector2(slope * 0.3, slope * 0.3 + minf(2.4, slope * 0.24))
	var along_strip := (strip.x + strip.y) * 0.5
	var glazed: String = fit.get("glass", "alternate")
	for i in 2:
		var xf := slopes[i]
		# The second slope is turned about, so its own X runs the other way.
		var mirror := 1.0 if i == 0 else -1.0
		# A skylight over the middle of a bay: [where, how long].
		var holes: Array[Vector2] = []
		for b in edges.size() - 1:
			var bay := edges[b + 1] - edges[b]
			if bay >= 3.0 and (glazed == "all" or (glazed == "alternate" and b % 2 == i)):
				holes.append(Vector2((edges[b] + edges[b + 1]) * 0.5 * mirror, minf(bay - 1.4, 5.0)))
		holes.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		_local_box("roof", xf, Vector3(0, -SHEETING * 0.5, strip.x * 0.5), Vector3(half_l * 2.0, SHEETING, strip.x))
		_local_box("roof", xf, Vector3(0, -SHEETING * 0.5, (strip.y + slope) * 0.5), Vector3(half_l * 2.0, SHEETING, slope - strip.y))
		var edge := -half_l
		for hole in holes:
			var x := hole.x
			var pane := hole.y
			_local_box("roof", xf, Vector3((edge + x - pane * 0.5) * 0.5, -SHEETING * 0.5, along_strip), Vector3(x - pane * 0.5 - edge, SHEETING, strip.y - strip.x))
			var bars := maxi(2, roundi(pane / 1.25))
			for k in range(1, bars):
				_local_box("steel", xf, Vector3(x - pane * 0.5 + pane * k / bars, -SHEETING * 0.5, along_strip), Vector3(0.06, 0.08, strip.y - strip.x), small)
			_local_box("glass", xf, Vector3(x, -SHEETING * 0.5, along_strip), Vector3(pane, 0.012, strip.y - strip.x), GLASS | NO_COLLIDE)
			made.glass.append(xf * Vector3(x, 0, along_strip))
			edge = x + pane * 0.5
		_local_box("roof", xf, Vector3((edge + half_l) * 0.5, -SHEETING * 0.5, along_strip), Vector3(half_l - edge, SHEETING, strip.y - strip.x))
		var purlins := maxi(2, ceili(slope / 2.3))
		for p in purlins:
			_local_box("steel", xf, Vector3(0, -SHEETING - 0.07, slope * (p + 0.4) / purlins), Vector3(in_l * 2.0, 0.14, 0.1), small)
		for x in lines:
			_local_box("steel", xf, Vector3(x * mirror, -SHEETING - 0.24, (slope - 0.3) * 0.5), Vector3(0.16, 0.2, slope - 0.3), small)

	# The trusses: a tie from wall to wall, posts up to the rafters and
	# diagonals that rise towards the ridge.
	var each_side := 2 if in_w > 5.5 else 1
	for x in lines:
		_local_box("steel", frame, Vector3(x, -0.1, 0), Vector3(0.16, 0.2, in_w * 2.0 + 0.1), small)
		var posts: Array[float] = []
		for k in range(-each_side, each_side + 1):
			posts.append(in_w * k / (each_side + 1.0))
		for j in posts.size():
			var head := rise * (1.0 - absf(posts[j]) / half_w) - 0.3
			beam("steel", frame * Vector3(x, 0, posts[j]), frame * Vector3(x, head, posts[j]), 0.1, small)
			if j == 0:
				continue
			var before := posts[j - 1]
			if posts[j] <= 0.001:
				beam("steel", frame * Vector3(x, 0, before), frame * Vector3(x, head, posts[j]), 0.08, small)
			else:
				beam("steel", frame * Vector3(x, rise * (1.0 - absf(before) / half_w) - 0.3, before), frame * Vector3(x, 0, posts[j]), 0.08, small)
		for side: float in [-1.0, 1.0]:
			_bearing(made, Vector3(x, -0.2, side * in_w), Vector3(0, 0, -side))

	# The gables, and along the head of the two other walls a beam that the
	# sheeting comes down on: without it the day comes in over the wall.
	var wall_mat: String = fit.get("wall", "brick")
	var gable := PackedVector2Array([Vector2(-half_w, 0), Vector2(half_w, 0), Vector2(0, rise)])
	var on_end := Basis(Vector3(0, 0, -1), Vector3.UP, Vector3.RIGHT)
	for end: float in [-1.0, 1.0]:
		extrude(wall_mat, gable, thick, frame * Transform3D(on_end, Vector3(end * (half_l - thick * 0.5), 0, 0)))
		_local_box("concrete", frame, Vector3(end * (in_l - 0.03), -0.05, 0), Vector3(0.06, 0.3, in_w * 2.0), NO_COLLIDE)
		_local_box("concrete", frame, Vector3(0, -0.05, end * (half_w - thick * 0.5)), Vector3(half_l * 2.0, 0.3, thick + 0.1), NO_COLLIDE)


## A sawtooth roof: bays that follow each other along the local Z of the
## roof, each with a long slope of sheeting up to its ridge and a steep face
## of glass down from it, which looks along that Z. The girder that carries a
## bay stands in its glass, so nothing hangs below the eaves.
func _roof_sawtooth(made: Dictionary, fit: Dictionary) -> void:
	var frame: Transform3D = made.frame
	var small := DETAIL | NO_COLLIDE
	var thick: float = made.thick
	var half_l: float = made.half_along
	var half_d: float = made.half_across
	var in_l := half_l - thick
	var teeth := maxi(2, roundi(half_d * 2.0 / fit.get("bay", 5.6)))
	var depth := half_d * 2.0 / teeth
	var rise: float = fit.get("rise", clampf(depth * 0.42, 1.6, 2.6))
	# How far the glass leans back from its foot to the ridge.
	var run := rise / tan(deg_to_rad(66.0))
	made.rise = rise
	made.teeth = teeth
	made.depth = depth
	made.run = run
	var wall_mat: String = fit.get("wall", "brick")
	var on_end := Basis(Vector3(0, 0, -1), Vector3.UP, Vector3.RIGHT)
	var rafters := maxi(2, roundi(in_l * 2.0 / 3.4))
	for i in teeth:
		# The valley behind the bay, and the foot of its glass.
		var far := -half_d + depth * i
		var near := far + depth
		var ridge := Vector3(0, rise, near - run)
		# The long slope: its underside runs from the valley up to the ridge.
		var angle := atan2(rise, ridge.z - far)
		var length := Vector2(ridge.z - far, rise).length()
		var slope := frame * Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, angle), ridge + Vector3(0, SHEETING / cos(angle), 0))
		_local_box("roof", slope, Vector3(0, -SHEETING * 0.5, length * 0.5), Vector3(half_l * 2.0, SHEETING, length + 0.1))
		for p in 2:
			_local_box("steel", slope, Vector3(0, -SHEETING - 0.05, length * (p + 1) / 3.0), Vector3(in_l * 2.0, 0.1, 0.08), small)
		for r in rafters + 1:
			var x := -in_l + 0.1 + (in_l * 2.0 - 0.2) * r / rafters
			_local_box("steel", slope, Vector3(-x, -SHEETING - 0.19, length * 0.5), Vector3(0.12, 0.18, length - 0.15), small)
			if i == 0 and r > 0 and r < rafters:
				_bearing(made, Vector3(x, -0.2, -half_d + thick), Vector3(0, 0, 1))
				_bearing(made, Vector3(x, -0.2, half_d - thick), Vector3(0, 0, -1))

		# The glass: in a face that leans back from its foot, on a kerb, with
		# the girder of the bay just inside it.
		var tilt := atan2(run, rise)
		var tall := Vector2(run, rise).length()
		var face := frame * Transform3D(Basis(Vector3.RIGHT, -tilt), Vector3(0, 0, near))
		_local_box("roof", face, Vector3(0, 0.15, 0), Vector3(half_l * 2.0, 0.3, 0.1))
		_glazing(face * Transform3D(Basis(), Vector3(0, (0.3 + tall - 0.08) * 0.5, 0)), in_l * 2.0, tall - 0.38, 1.15)
		made.glass.append(face * Vector3(0, tall * 0.5, 0))
		var low := 0.2
		var high := tall - 0.22
		for chord: float in [low, high]:
			_local_box("steel", face, Vector3(0, chord, -0.14), Vector3(in_l * 2.0, 0.14, 0.14), small)
		var panels := maxi(2, roundi(in_l * 2.0 / (tall * 1.15)))
		for k in panels:
			var from := -in_l + in_l * 2.0 * k / panels
			var to := -in_l + in_l * 2.0 * (k + 1) / panels
			if k % 2 == 0:
				beam("steel", face * Vector3(from, low, -0.14), face * Vector3(to, high, -0.14), 0.08, small)
			else:
				beam("steel", face * Vector3(from, high, -0.14), face * Vector3(to, low, -0.14), 0.08, small)
		# A capping along the ridge and a gutter in the valley close what the
		# sheeting and the glass leave open where they meet.
		_local_box("steel", frame, ridge + Vector3(0, 0.04, 0), Vector3(half_l * 2.0, 0.3, 0.34), NO_COLLIDE)
		if i > 0:
			_local_box("steel", frame, Vector3(0, 0, far), Vector3(half_l * 2.0, 0.24, 0.5), NO_COLLIDE)
			for end: float in [-1.0, 1.0]:
				_bearing(made, Vector3(end * in_l, -0.2, far), Vector3(-end, 0, 0))
		# The end walls go up with the bay.
		var end_wall := PackedVector2Array([Vector2(-near, 0), Vector2(-far, 0), Vector2(-ridge.z, rise)])
		for end: float in [-1.0, 1.0]:
			extrude(wall_mat, end_wall, thick, frame * Transform3D(on_end, Vector3(end * (half_l - thick * 0.5), 0, 0)))
	for end: float in [-1.0, 1.0]:
		_local_box("concrete", frame, Vector3(end * (in_l - 0.03), -0.05, 0), Vector3(0.06, 0.3, (half_d - thick) * 2.0), NO_COLLIDE)
		_local_box("concrete", frame, Vector3(0, -0.05, end * (half_d - thick * 0.5)), Vector3(half_l * 2.0, 0.3, thick + 0.1), NO_COLLIDE)


## Glazing in the XY plane of `pane`, around its middle: steel bars about
## `spacing` apart, a rail across every good metre, and a pane in every
## field of which a few are long gone.
func _glazing(pane: Transform3D, width: float, height: float, spacing: float) -> void:
	var small := DETAIL | NO_COLLIDE
	var across := maxi(1, roundi(width / spacing))
	var up := maxi(1, roundi(height / 1.2))
	for i in across + 1:
		_local_box("steel", pane, Vector3(-width * 0.5 + width * i / across, 0, 0), Vector3(0.05, height, 0.06), small)
	for j in up + 1:
		_local_box("steel", pane, Vector3(0, -height * 0.5 + height * j / up, 0), Vector3(width, 0.05, 0.06), small)
	for i in across:
		for j in up:
			if _glass_rng.randf() < 0.08:
				continue
			_local_box("glass", pane, Vector3(-width * 0.5 + width * (i + 0.5) / across, -height * 0.5 + height * (j + 0.5) / up, 0), Vector3(width / across, height / up, 0.012), GLASS | NO_COLLIDE)


# --- What divides a wall --------------------------------------------------------


## A pier against a wall: `foot` is the middle of its foot on the face of the
## wall, and `inwards` the way that face looks.
func pier(foot: Vector3, inwards: Vector3, height: float, width := 0.6, depth := 0.3, mat := "concrete") -> void:
	var across := Vector3(absf(inwards.z), 0, absf(inwards.x))
	box(mat, foot + inwards * depth * 0.5 + Vector3.UP * height * 0.5, across * width + inwards.abs() * depth + Vector3.UP * height)


## A corbel: the block under the end of a beam, on a wall or on a pier that
## is `depth` deep. `at` lies on the face of the wall, under the beam.
func corbel(at: Vector3, inwards: Vector3, depth := 0.3, mat := "concrete") -> void:
	var across := Vector3(absf(inwards.z), 0, absf(inwards.x))
	box(mat, at + inwards * (depth + 0.2) * 0.5 + Vector3.DOWN * 0.2, across * 0.5 + inwards.abs() * (depth + 0.2) + Vector3.UP * 0.4, Vector3.ZERO, NO_COLLIDE)


## A band along the foot of a wall between two points on its face, `height`
## high and `proud` of the wall: a plinth of concrete under brick, a skirting
## under plaster.
func plinth(from: Vector3, to: Vector3, inwards: Vector3, height := 1.0, proud := 0.08, mat := "concrete") -> void:
	if from.distance_to(to) < 0.05:
		return
	var middle := (from + to) * 0.5 + inwards * proud * 0.5 + Vector3.UP * height * 0.5
	box(mat, middle, (to - from).abs() + inwards.abs() * proud + Vector3.UP * height, Vector3.ZERO, NO_COLLIDE)


## A buttress against the wall of a yard: a pier of the wall's own brick that
## steps back twice on its way up, under a stone on each step.
func buttress(foot: Vector3, inwards: Vector3, height: float, mat := "brick") -> void:
	var across := Vector3(absf(inwards.z), 0, absf(inwards.x))
	var steps: Array[Vector2] = [Vector2(0.55, 0.45), Vector2(0.38, 0.75), Vector2(0.22, 0.96)]
	var from := 0.0
	for step in steps:
		var top := height * step.y
		box(mat, foot + inwards * step.x * 0.5 + Vector3.UP * (from + top) * 0.5, across * 0.8 + inwards.abs() * step.x + Vector3.UP * (top - from), Vector3.ZERO, 0 if from == 0.0 else NO_COLLIDE)
		box("concrete", foot + inwards * (step.x * 0.5 + 0.02) + Vector3.UP * (top + 0.04), across * 0.88 + inwards.abs() * (step.x + 0.06) + Vector3.UP * 0.08, Vector3.ZERO, NO_COLLIDE)
		from = top
