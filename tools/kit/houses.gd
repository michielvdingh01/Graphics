extends "res://tools/kit/water.gd"
## Thirteenth drawer of the kit, see tools/kit.gd: the houses of a town of
## canals, in rows that stand shoulder to shoulder along a street. A house
## has no zone of its own: its front belongs to the street before it. A
## greybox, as tools/kit/street.gd says of all three drawers of the town.

## The houses of a row, by kind: how wide one is, how many storeys it has and
## how high a storey is, in metres. A canal house is a merchant's; a grand one
## stands on a double lot, as on the bend of the Herengracht; a low one is
## of the Prinsengracht and the streets behind it; a street house is narrow
## and has a shop under it. Measured on the 3DBAG of 14 October 2026, the
## middle half of the houses between the two axes: on the Gouden Bocht 14.6
## to 18.9 m wide and 18.8 m to the eaves, on the south side of the
## Keizersgracht 5.4 to 7.6 m and 17 m, on the Prinsengracht 4.2 to 9.8 m
## and 12 to 13 m.
const HOUSES := {
	"canal": {"wide": Vector2(5.4, 7.8), "storeys": Vector2i(4, 5), "storey": 3.2},
	"grand": {"wide": Vector2(13.5, 19.0), "storeys": Vector2i(4, 4), "storey": 4.2},
	"low": {"wide": Vector2(4.2, 6.6), "storeys": Vector2i(3, 4), "storey": 3.0},
	"street": {"wide": Vector2(4.6, 6.6), "storeys": Vector2i(3, 4), "storey": 3.0},
	"block": {"wide": Vector2(18.0, 30.0), "storeys": Vector2i(6, 7), "storey": 3.6},
}
## What a greybox house is made of, one after the other along a row.
const HOUSE_WALLS: Array[String] = ["brick", "plaster", "brick", "concrete"]
## How far behind its front the box stands that throws the shadow of a house:
## deeper than anything is set into a front.
const HOUSE_SET_BACK := 0.3

## Zone that fronts are filed under while a row is built, see _face_street().
var _before_row: Variant = null


## A row of houses shoulder to shoulder with their fronts on the line from
## `from` to `to`, x and z, as somebody sees them who stands in the street
## before them: `from` on his left and `to` on his right. They are `deep`
## from front to back and of the `kind` named, see HOUSES; no two next to each
## other are as wide or as high. Their fronts, and what light their windows
## give, belong to the zone of the street they look out on.
##
## A house is in the way as a whole and is seen from the street alone: its
## front, its side wall where it stands taller than its neighbour or ends
## the row, and its roof.
##
## With "shops" in `fit` the ground floor is a shop front with a lit window,
## with "lit" the share of the windows above it that somebody is at home
## behind, 0 to 1, and with "dark" a row nobody ever comes near, without
## windows: the far bank of a canal that runs out of the level. "dressed"
## lists the houses of the row, counted from `from`, that have their front
## as it is to be, see _canal_front(): a row of canal houses only.
func terrace(from: Vector2, to: Vector2, kind := "canal", deep := 12.0, fit := {}) -> void:
	var house: Dictionary = HOUSES[kind]
	var right := (to - from).normalized()
	var out := Vector2(-right.y, right.x)
	var length := from.distance_to(to)
	# The row is drawn up first: how high a side wall shows depends on the
	# house next door.
	var row: Array[Dictionary] = []
	var done := 0.0
	var last_storeys := -1
	while length - done > 0.5:
		var wide := _prop_rng.randf_range(house.wide.x, house.wide.y)
		# The last one takes what is left of the row, if another would not fit.
		if length - done - wide < house.wide.x:
			wide = length - done
		var storeys := _prop_rng.randi_range(house.storeys.x, house.storeys.y)
		if storeys == last_storeys and house.storeys.x != house.storeys.y and _prop_rng.randf() < 0.6:
			storeys = house.storeys.x + (storeys - house.storeys.x + 1) % (house.storeys.y - house.storeys.x + 1)
		last_storeys = storeys
		var storey: float = house.storey + _prop_rng.randf_range(-0.2, 0.2)
		# The ground floor of a house on a canal stands half a storey over
		# the street, on its basement.
		var plinth := 1.2 if kind == "canal" or kind == "grand" else 0.9 if kind == "low" else 0.0
		row.append({"at": done + wide * 0.5, "wide": wide, "storeys": storeys, "storey": storey, "plinth": plinth, "eaves": plinth + storeys * storey})
		done += wide
	_face_street(Vector3(from.x + right.x * length * 0.5 + out.x * 2.0, 1.0, from.y + right.y * length * 0.5 + out.y * 2.0))
	for i in row.size():
		var at := from + right * (row[i].at as float)
		var frame := Transform3D(Basis(Vector3(right.x, 0, right.y), Vector3.UP, Vector3(out.x, 0, out.y)), Vector3(at.x, 0, at.y))
		var beside := Vector2(row[i - 1].eaves if i > 0 else 0.0, row[i + 1].eaves if i < row.size() - 1 else 0.0)
		if kind == "canal" and i in fit.get("dressed", []):
			_canal_front(frame, row[i], beside, deep, fit)
			continue
		_row_house(frame, row[i], beside, deep, HOUSE_WALLS[i % HOUSE_WALLS.size()], kind, fit)
	_face_street_done()


## One house of a row, in a frame with its origin at the middle of its front
## on the ground, its X along the front and its Z looking out on the street.
## `beside` is how high the houses to its left and its right stand, nought
## for none.
func _row_house(frame: Transform3D, plan: Dictionary, beside: Vector2, deep: float, mat: String, kind: String, fit: Dictionary) -> void:
	var wide: float = plan.wide
	var storey: float = plan.storey
	var plinth: float = plan.plinth
	var eaves: float = plan.eaves
	var up_there := DETAIL | NO_COLLIDE | NO_SHADOW
	_house_box(frame, wide, eaves, deep, mat)
	wall_face(mat, frame * Transform3D(Basis(), Vector3(0, eaves * 0.5, 0)), Vector2(wide, eaves))
	for side in 2:
		var neighbour: float = beside[side]
		if eaves - neighbour < 0.3:
			continue
		var turn := Basis(Vector3.UP, -PI * 0.5 if side == 0 else PI * 0.5)
		var x := -wide * 0.5 if side == 0 else wide * 0.5
		# Down to the street it is lit with the street; over a roof it is not.
		wall_face(mat, frame * Transform3D(turn, Vector3(x, (eaves + neighbour) * 0.5, -deep * 0.5)), Vector2(deep, eaves - neighbour), 0 if neighbour == 0.0 else DETAIL | NO_SHADOW)
	# What stands on the cornice: a gable narrower than the house before a
	# steep roof, or the attic of a grand one.
	if kind == "canal" or kind == "low" or kind == "street":
		var top := _prop_rng.randf_range(2.4, 4.2)
		_local_box(mat, frame, Vector3(0, eaves + top * 0.5, -0.4), Vector3(wide * _prop_rng.randf_range(0.42, 0.6), top, 0.8), up_there)
		_local_box("roof", frame, Vector3(0, eaves + top * 0.3, -deep * 0.5 - 0.4), Vector3(wide - 0.4, top * 0.6, deep - 1.0), up_there)
	else:
		_local_box("concrete", frame, Vector3(0, eaves + 0.3, 0.15), Vector3(wide + 0.1, 0.6, 0.7), up_there)
		_local_box("roof", frame, Vector3(0, eaves + 1.3, -deep * 0.5 - 0.6), Vector3(wide - 0.8, 1.4, deep - 2.0), up_there)
	if fit.get("dark", false):
		return
	if plinth > 0.0:
		# The stoop: steps along the front up to the door.
		_local_box("concrete", frame, Vector3(wide * 0.5 - 1.3, plinth * 0.5, 0.75), Vector3(1.6, plinth, 1.5), CASTS)
		_local_box("concrete", frame, Vector3(wide * 0.5 - 2.9, plinth * 0.25, 0.75), Vector3(1.6, plinth * 0.5, 1.5), CASTS)
	# Windows, in bays a good two metres apart: lit for whoever is at home.
	# A lit one is part of what is baked, and lights the street before it.
	var bays := maxi(2, roundi(wide / 2.3))
	var lit: float = fit.get("lit", 0.22)
	for floor_number: int in plan.storeys:
		var sill := plinth + floor_number * storey + storey * 0.28
		if floor_number == 0 and fit.get("shops", false):
			var open := _prop_rng.randf() < 0.75
			wall_face("window_glow" if open else "window_glass", frame * Transform3D(Basis(), Vector3(-0.5, storey * 0.5 + 0.2, 0.03)), Vector2(wide - 2.4, storey - 1.0), 0 if open else DETAIL | NO_SHADOW)
			continue
		var home := _prop_rng.randf() < lit * 1.6
		for bay in bays:
			if floor_number == 0 and bay == bays - 1:
				# The door, at the head of the stoop.
				wall_face("door", frame * Transform3D(Basis(), Vector3(wide * 0.5 - 1.3, plinth + 1.15, 0.03)), Vector2(1.1, 2.3), DETAIL | NO_SHADOW)
				continue
			var x := (bay + 0.5) / bays * wide - wide * 0.5
			var glows := home and _prop_rng.randf() < 0.7
			wall_face("window_glow" if glows else "window_glass", frame * Transform3D(Basis(), Vector3(x, sill + storey * 0.3, 0.03)), Vector2(wide / bays * 0.52, storey * 0.6), 0 if glows else DETAIL | NO_SHADOW)


## The front of a canal house as the town is to have them, the first one
## dressed: a neck gable, as so many houses on the Herengracht have. It is the
## house _row_house() draws in grey, in the same frame and to the same plan,
## with the same box to run into and to throw its shadow; only what is drawn
## is new.
##
## From the street up: a plinth of blue stone with the windows of the
## basement in it, a stoop of steps of the same along the front up to the
## door, with an iron railing, floors of sash windows in white frames with their glazing
## bars, the shoulders of the front at the eaves, and on them the neck: the
## door of the loft with the hoisting beam over it, the scrolls of sandstone
## that fill out its shoulders, and a pediment. The roof behind it.
##
## A window that somebody is at home behind glows, and what it throws on the
## street is baked from a lamp in the room behind the glass, not from the
## glowing glass: a small bright surface bakes grainy.
func _canal_front(frame: Transform3D, plan: Dictionary, beside: Vector2, deep: float, fit: Dictionary) -> void:
	var wide: float = plan.wide
	var storey: float = plan.storey
	var plinth: float = plan.plinth
	var eaves: float = plan.eaves
	var storeys: int = plan.storeys
	# Dice of its own, so that the rest of the row falls as it did.
	var dice := RandomNumberGenerator.new()
	dice.seed = hash(frame.origin.snappedf(0.01))
	var trim := DETAIL | NO_COLLIDE | NO_SHADOW
	_house_box(frame, wide, eaves, deep, "canal_brick")
	for side in 2:
		var neighbour: float = beside[side]
		if eaves - neighbour < 0.3:
			continue
		var turn := Basis(Vector3.UP, -PI * 0.5 if side == 0 else PI * 0.5)
		var x := -wide * 0.5 if side == 0 else wide * 0.5
		wall_face("canal_brick", frame * Transform3D(turn, Vector3(x, (eaves + neighbour) * 0.5, -deep * 0.5)), Vector2(deep, eaves - neighbour), 0 if neighbour == 0.0 else DETAIL | NO_SHADOW)

	# The axes of the windows: the last over the door at the head of the
	# stoop, the first as far in from the other side, the rest between.
	var bays := 2 if wide < 5.5 else 3 if wide < 8.5 else 4
	var door := wide * 0.5 - 1.3
	var axes: Array[float] = []
	for bay in bays:
		axes.append(lerpf(-door, door, float(bay) / (bays - 1)))
	var across := clampf(2.0 * door / (bays - 1) - 0.7, 0.85, 1.3)

	# The plinth, of blue stone, with the windows of the basement in it but
	# under the stoop, and a band along its top.
	var cellar: Array[Rect2] = []
	for bay in bays - 1:
		var hole := Rect2(axes[bay] - across * 0.45, 0.18, across * 0.9, plinth - 0.36)
		if hole.end.x < door - 2.2:
			cellar.append(hole)
	_front_wall("bluestone", frame, Rect2(-wide * 0.5, 0.0, wide, plinth), cellar, 0.08)
	# Its top a finger under that of the landing of the stoop.
	_local_box("bluestone", frame, Vector3(0, plinth - 0.07, 0.03), Vector3(wide, 0.12, 0.06), trim)
	for hole in cellar:
		_pane("window_glass", frame, hole, -0.1, DETAIL | NO_COLLIDE | NO_SHADOW)
		for bar in 3:
			var x := hole.position.x + hole.size.x * (bar + 1) / 4.0
			rod("lantern_iron", frame * Vector3(x, hole.position.y, -0.04), frame * Vector3(x, hole.end.y, -0.04), 0.012, DETAIL | NO_COLLIDE, 6)

	# The floors over it, of brick.
	var holes: Array[Rect2] = []
	var windows: Array[Dictionary] = []
	var lit: float = fit.get("lit", 0.22)
	for floor_number in storeys:
		var foot := plinth + floor_number * storey
		var sill := foot + (0.55 if floor_number == 0 else 0.7)
		var head := foot + storey - (0.65 if floor_number == storeys - 1 else 0.45)
		var home := dice.randf() < lit * 1.6
		for bay in bays:
			if floor_number == 0 and bay == bays - 1:
				continue
			var hole := Rect2(axes[bay] - across * 0.5, sill, across, head - sill)
			holes.append(hole)
			windows.append({"hole": hole, "lit": home and dice.randf() < 0.7})
	var doorway := Rect2(door - 0.6, plinth, 1.2, 2.95)
	holes.append(doorway)
	_front_wall("canal_brick", frame, Rect2(-wide * 0.5, plinth, wide, eaves - plinth), holes, WINDOW_SET)
	for window: Dictionary in windows:
		_sash_window(frame, window.hole, window.lit)
		_local_box("sandstone", frame, Vector3(window.hole.get_center().x, window.hole.position.y - 0.04, 0.045), Vector3(window.hole.size.x + 0.16, 0.08, 0.09), trim)
	_front_door(frame, doorway, dice.randf() < 0.8)
	_stoop(frame, door, plinth)

	# The shoulders of the front, and the neck on them.
	var neck := clampf(wide * 0.48, 2.4, 3.6)
	var neck_high := clampf(storey * 0.95, 2.6, 3.3)
	for side: float in [-1.0, 1.0]:
		var reach := (wide - neck) * 0.5
		_local_box("sandstone", frame, Vector3(side * (neck * 0.5 + reach * 0.5), eaves + 0.07, -0.1), Vector3(reach, 0.14, 0.32), trim)
	var loft := Rect2(-0.45, eaves + 0.35, 0.9, 1.55)
	_front_wall("canal_brick", frame, Rect2(-neck * 0.5, eaves, neck, neck_high), [loft], WINDOW_SET, DETAIL | NO_SHADOW)
	for side: float in [-1.0, 1.0]:
		wall_face("canal_brick", frame * Transform3D(Basis(Vector3.UP, side * PI * 0.5), Vector3(side * neck * 0.5, eaves + neck_high * 0.5, -0.15)), Vector2(0.3, neck_high), DETAIL | NO_SHADOW)
		# Quoins of sandstone up its edges.
		_local_box("sandstone", frame, Vector3(side * (neck * 0.5 - 0.07), eaves + neck_high * 0.5, 0.02), Vector3(0.14, neck_high, 0.04), trim)
	_loft_door(frame, loft)
	# The scrolls that fill out its shoulders, standing on them.
	var scroll := neck_high * 0.72
	for side: float in [-1.0, 1.0]:
		var outline := PackedVector2Array()
		var outer := side * (wide * 0.5 - 0.05)
		var inner := side * neck * 0.5
		outline.append(Vector2(outer, 0.0))
		outline.append(Vector2(inner, 0.0))
		for i in 9:
			var t := i / 8.0
			outline.append(Vector2(lerpf(inner, outer, t), 0.35 + (scroll - 0.35) * pow(1.0 - t, 2.0) + 0.12 * sin(t * PI)))
		if side > 0.0:
			outline.reverse()
		slab("sandstone", frame * Transform3D(Basis(), Vector3(0, eaves + 0.14, -0.04)), outline, 0.24, 0.02, trim)
	# The beam for hoisting the furniture in, and the pediment over it.
	var top := eaves + neck_high
	_local_box("wood", frame, Vector3(0, top - 0.42, 0.35), Vector3(0.14, 0.18, 1.1), trim)
	rod("lantern_iron", frame * Vector3(0, top - 0.51, 0.85), frame * Vector3(0, top - 0.75, 0.85), 0.012, trim, 6)
	_local_box("sandstone", frame, Vector3(0, top + 0.06, -0.08), Vector3(neck + 0.3, 0.12, 0.36), trim)
	extrude("sandstone", PackedVector2Array([Vector2(-neck * 0.5 - 0.1, 0), Vector2(neck * 0.5 + 0.1, 0), Vector2(0, 0.75)]), 0.3, frame * Transform3D(Basis(), Vector3(0, top + 0.12, -0.1)), trim)
	# The roof behind, its ridge from the front to the back.
	extrude("roof", PackedVector2Array([Vector2(-wide * 0.5, 0), Vector2(wide * 0.5, 0), Vector2(0, neck_high + 0.2)]), deep - 1.0, frame * Transform3D(Basis(), Vector3(0, eaves, -0.3 - (deep - 1.0) * 0.5)), trim)


## How far a window frame or a door stands back in a dressed front.
const WINDOW_SET := 0.1


## A front of `mat` in `frame` over `area`, x along the front and y up, with
## `holes` in it, and in every hole its sides `deep` into the wall: the brick
## a window or a door is set back into.
func _front_wall(mat: String, frame: Transform3D, area: Rect2, holes: Array[Rect2], deep: float, flags := 0) -> void:
	var xs := PackedFloat32Array([area.position.x, area.end.x])
	var ys := PackedFloat32Array([area.position.y, area.end.y])
	for hole in holes:
		xs.append_array([hole.position.x, hole.end.x])
		ys.append_array([hole.position.y, hole.end.y])
	xs.sort()
	ys.sort()
	# Cut along every edge of a hole, and draw what is wall of each strip in
	# runs from side to side.
	for j in ys.size() - 1:
		if ys[j + 1] - ys[j] < 0.001:
			continue
		var from := -1
		for i in xs.size():
			var solid := false
			if i < xs.size() - 1 and xs[i + 1] - xs[i] > 0.001:
				var middle := Vector2((xs[i] + xs[i + 1]) * 0.5, (ys[j] + ys[j + 1]) * 0.5)
				solid = holes.all(func(hole: Rect2) -> bool: return not hole.has_point(middle))
			elif i < xs.size() - 1:
				continue
			if solid and from < 0:
				from = i
			elif not solid and from >= 0:
				var piece := Rect2(xs[from], ys[j], xs[i] - xs[from], ys[j + 1] - ys[j])
				wall_face(mat, frame * Transform3D(Basis(), Vector3(piece.get_center().x, piece.get_center().y, 0)), piece.size, flags)
				from = -1
	for hole in holes:
		var middle := hole.get_center()
		for side: float in [-1.0, 1.0]:
			wall_face(mat, frame * Transform3D(Basis(Vector3.UP, -side * PI * 0.5), Vector3(middle.x + side * hole.size.x * 0.5, middle.y, -deep * 0.5)), Vector2(deep, hole.size.y), flags)
			wall_face(mat, frame * Transform3D(Basis(Vector3.RIGHT, side * PI * 0.5), Vector3(middle.x, middle.y + side * hole.size.y * 0.5, -deep * 0.5)), Vector2(hole.size.x, deep), flags)


## A pane of glass over `area` of a front, `z` before it (behind it, when
## less than nought). The glass of a lit window has a UV for each window,
## see shaders/lit_window.gdshader.
func _pane(mat: String, frame: Transform3D, area: Rect2, z: float, flags: int) -> void:
	var at := frame * Vector3(area.get_center().x, area.get_center().y, z)
	var st := _tool(mat, flags, at)
	var normal := frame.basis.z
	var points: Array[Vector3] = []
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		points.append(frame * Vector3(area.position.x + area.size.x * corner.x, area.position.y + area.size.y * corner.y, z))
	# Which window it is, from where it is: the same on every build.
	var id := float(posmod(hash(at.snappedf(0.01)), 4096))
	_quad(st, points, [normal, normal, normal, normal], [Vector2(id, 0), Vector2(id + 0.999, 0), Vector2(id + 0.999, 1), Vector2(id, 1)],
		[_edge(Vector2(0, 0), area.size), _edge(Vector2(1, 0), area.size), _edge(Vector2(1, 1), area.size), _edge(Vector2(0, 1), area.size)])


## A sash window in the hole `hole` of a front: its frame, the meeting rail
## of the two sashes, the glazing bars and the glass. A lit one glows, and a
## lamp in the room behind it lights the street for the bake.
func _sash_window(frame: Transform3D, hole: Rect2, lit: bool) -> void:
	var trim := DETAIL | NO_COLLIDE | NO_SHADOW
	var back := -WINDOW_SET
	var member := 0.075
	var inner := hole.grow(-member)
	var middle := hole.get_center()
	for side: float in [-1.0, 1.0]:
		_local_box("window_paint", frame, Vector3(middle.x + side * (hole.size.x - member) * 0.5, middle.y, back - 0.05), Vector3(member, hole.size.y, 0.1), trim)
		_local_box("window_paint", frame, Vector3(middle.x, middle.y + side * (hole.size.y - member) * 0.5, back - 0.05), Vector3(hole.size.x - member * 2.0, member, 0.1), trim)
	var meeting := inner.position.y + inner.size.y * 0.5
	_local_box("window_paint", frame, Vector3(middle.x, meeting, back - 0.05), Vector3(inner.size.x, 0.06, 0.07), trim)
	# Six panes to a sash where it is wide enough, four where it is not.
	var columns := 3 if hole.size.x >= 1.05 else 2
	for column in range(1, columns):
		var x := inner.position.x + inner.size.x * column / columns
		_local_box("window_paint", frame, Vector3(x, middle.y, back - 0.045), Vector3(0.024, inner.size.y, 0.03), trim)
	for sash: Vector2 in [Vector2(inner.position.y, meeting), Vector2(meeting, inner.end.y)]:
		if sash.y - sash.x > 0.75:
			_local_box("window_paint", frame, Vector3(middle.x, (sash.x + sash.y) * 0.5, back - 0.045), Vector3(inner.size.x, 0.024, 0.03), trim)
	if not lit:
		_pane("window_glass", frame, inner, back - 0.06, trim)
		return
	_pane("window_lit", frame, inner, back - 0.06, trim)
	_room_lamp(frame * Vector3(middle.x, middle.y + 0.3, -0.9), inner.size.x * inner.size.y)


## A lamp in a room behind the glass at `at`, for the bake alone: what a lit
## window of `area` square metres throws on the street. See wall_lamp() in
## tools/kit/services.gd for why it is gone in the game.
func _room_lamp(at: Vector3, area: float) -> void:
	var light := OmniLight3D.new()
	light.name = "Room"
	light.position = at
	light.light_color = Color(1.0, 0.7, 0.42)
	light.light_energy = 0.9 * area
	light.omni_range = 9.0
	light.omni_attenuation = 1.2
	light.shadow_enabled = true
	light.light_bake_mode = Light3D.BAKE_STATIC
	var baked := _group("Baked", at)
	if baked.get_script() == null:
		baked.set_script(load("res://scripts/bake_only.gd"))
	_add(light, baked)


## The front door in `hole`, with the fanlight over it and a surround of
## sandstone: a door of panels, painted, and behind the fanlight the lamp
## of the hall when `lit`.
func _front_door(frame: Transform3D, hole: Rect2, lit: bool) -> void:
	var trim := DETAIL | NO_COLLIDE | NO_SHADOW
	var back := -WINDOW_SET - 0.04
	var middle := hole.get_center()
	var transom := hole.position.y + 2.35
	for side: float in [-1.0, 1.0]:
		_local_box("window_paint", frame, Vector3(middle.x + side * (hole.size.x * 0.5 - 0.04), middle.y, back), Vector3(0.08, hole.size.y, 0.12), trim)
		# The pilasters either side.
		_local_box("sandstone", frame, Vector3(middle.x + side * (hole.size.x * 0.5 + 0.11), middle.y + 0.03, 0.025), Vector3(0.2, hole.size.y + 0.06, 0.05), trim)
	_local_box("sandstone", frame, Vector3(middle.x, hole.end.y + 0.1, 0.06), Vector3(hole.size.x + 0.6, 0.14, 0.12), trim)
	_local_box("window_paint", frame, Vector3(middle.x, transom + 0.04, back), Vector3(hole.size.x - 0.16, 0.08, 0.12), trim)
	var leaf := Rect2(hole.position.x + 0.08, hole.position.y, hole.size.x - 0.16, transom - hole.position.y)
	_local_box("front_door", frame, Vector3(leaf.get_center().x, leaf.get_center().y, back - 0.02), Vector3(leaf.size.x, leaf.size.y, 0.06), trim)
	# Its panels: two tall ones, and a short one at its foot.
	for row: Vector2 in [Vector2(0.12, 0.62), Vector2(0.78, leaf.size.y - 0.14)]:
		for column: float in [-1.0, 1.0] if row.x > 0.5 else [0.0]:
			var wide := (leaf.size.x - 0.36) * 0.5 if row.x > 0.5 else leaf.size.x - 0.24
			_local_box("front_door", frame, Vector3(leaf.get_center().x + column * (wide * 0.5 + 0.06), leaf.position.y + (row.x + row.y) * 0.5, back + 0.015), Vector3(wide, row.y - row.x, 0.025), trim)
	rod("brass", frame * Vector3(leaf.end.x - 0.12, leaf.position.y + 1.05, back + 0.01), frame * Vector3(leaf.end.x - 0.12, leaf.position.y + 1.05, back + 0.08), 0.022, trim, 8)
	_local_box("brass", frame, Vector3(leaf.get_center().x, leaf.position.y + 0.85, back + 0.015), Vector3(0.3, 0.06, 0.012), trim)
	# The fanlight, with its bars fanning out from the foot of its middle to
	# its sides and its head.
	var fan := Rect2(leaf.position.x, transom + 0.08, leaf.size.x, hole.end.y - transom - 0.08)
	var foot := Vector3(fan.get_center().x, fan.position.y, back + 0.01)
	for bar in range(1, 5):
		var angle := PI * bar / 5.0
		var out := Vector3(cos(angle), sin(angle), 0)
		var tip := foot + out * minf(fan.size.x * 0.5 / maxf(absf(out.x), 0.001), fan.size.y / out.y)
		_box("window_paint", Transform3D(frame.basis * Basis(Vector3.BACK, angle - PI * 0.5), frame * ((foot + tip) * 0.5)), Vector3(0.02, foot.distance_to(tip), 0.025), trim)
	if lit:
		_pane("window_lit", frame, fan, back - 0.01, trim)
		_room_lamp(frame * Vector3(middle.x, fan.get_center().y, -0.8), fan.size.x * fan.size.y * 2.0)
	else:
		_pane("window_glass", frame, fan, back - 0.01, trim)


## The door of the loft in `hole` of a neck: two leaves of boards.
func _loft_door(frame: Transform3D, hole: Rect2) -> void:
	var trim := DETAIL | NO_COLLIDE | NO_SHADOW
	var back := -WINDOW_SET
	var middle := hole.get_center()
	for side: float in [-1.0, 1.0]:
		_local_box("window_paint", frame, Vector3(middle.x + side * (hole.size.x - 0.07) * 0.5, middle.y, back - 0.05), Vector3(0.07, hole.size.y, 0.1), trim)
		_local_box("window_paint", frame, Vector3(middle.x, middle.y + side * (hole.size.y - 0.07) * 0.5, back - 0.05), Vector3(hole.size.x - 0.14, 0.07, 0.1), trim)
		_local_box("front_door", frame, Vector3(middle.x + side * (hole.size.x - 0.14) * 0.25, middle.y, back - 0.07), Vector3((hole.size.x - 0.14) * 0.5 - 0.01, hole.size.y - 0.14, 0.05), trim)


## The stoop of a canal house: a landing before the door at `door` along
## the front, `high` up, and steps down from it along the front, of blue
## stone, with an iron railing along their edge. Whoever runs into it
## runs into the two boxes the grey stoop has.
func _stoop(frame: Transform3D, door: float, high: float) -> void:
	_collide_box(frame * Transform3D(Basis(), Vector3(door, high * 0.5, 0.75)), Vector3(1.6, high, 1.5), "")
	_collide_box(frame * Transform3D(Basis(), Vector3(door - 1.6, high * 0.25, 0.75)), Vector3(1.6, high * 0.5, 1.5), "")
	var steps := 5
	var tread := 1.6 / steps
	var deep := 1.4
	_local_box("bluestone", frame, Vector3(door, high * 0.5, deep * 0.5), Vector3(1.6, high, deep), NO_COLLIDE | CASTS)
	for step in range(1, steps + 1):
		var top := high * (1.0 - float(step) / steps)
		if top <= 0.0:
			break
		_local_box("bluestone", frame, Vector3(door - 0.8 - tread * (step - 0.5), top * 0.5, deep * 0.5), Vector3(tread, top, deep), NO_COLLIDE | CASTS)
	# The railing: a rail along the landing and down the steps, balusters
	# from it to the stone under it, and a post where it turns and where it
	# ends.
	var iron := DETAIL | NO_COLLIDE
	var edge := deep - 0.05
	var rail := 0.92
	var corner := Vector3(door + 0.75, high + rail, edge)
	var turn := Vector3(door - 0.8, high + rail, edge)
	var foot := Vector3(door - 0.8 - tread * (steps - 1.0), high / steps + rail, edge)
	for run: Array in [[corner, turn], [turn, foot], [Vector3(door + 0.75, high + rail, 0.05), corner]]:
		rod("lantern_iron", frame * (run[0] as Vector3), frame * (run[1] as Vector3), 0.02, iron, 6)
		var from: Vector3 = run[0]
		var to: Vector3 = run[1]
		var count := maxi(1, roundi(from.distance_to(to) / 0.13))
		for i in range(1, count):
			var top := from.lerp(to, float(i) / count)
			var below := (door - 0.8 - top.x) / tread
			var stone := high if below <= 0.0 else high * maxf(0.0, 1.0 - ceilf(below) / steps)
			rod("lantern_iron", frame * Vector3(top.x, stone, top.z), frame * top, 0.009, iron, 5)
	for post: Vector3 in [corner, turn, foot]:
		_local_box("lantern_iron", frame, post - Vector3(0, rail * 0.5, 0), Vector3(0.045, rail + 0.04, 0.045), iron)
		revolve("lantern_iron", frame * Transform3D(Basis(), post + Vector3(0, 0.02, 0)), _knob(0.03), iron, 8, true)


## What a house of a row is to whoever runs into it or shoots at it, one box
## from its front to its back and up to its eaves, and the box of the shadow
## model that throws its shadow, see shadow_box(). That box stands a little
## behind the front, so that what is set into the front, a window, a door,
## is lit by a lantern before it as the front is.
func _house_box(frame: Transform3D, wide: float, eaves: float, deep: float, mat: String) -> void:
	_collide_box(frame * Transform3D(Basis(), Vector3(0, eaves * 0.5, -deep * 0.5)), Vector3(wide, eaves, deep), _surface(mat))
	shadow_box(frame * Transform3D(Basis(), Vector3(0, eaves * 0.5, -deep * 0.5 - HOUSE_SET_BACK * 0.5)), Vector3(wide, eaves, deep - HOUSE_SET_BACK))


## Files what is built from here on under the zone that `before` lies in,
## whatever stands where: the fronts of a row belong to the street they look
## out on. _face_street_done() goes back to how things were filed before.
func _face_street(before: Vector3) -> void:
	_before_row = _zone_forced
	if _zone_forced == null:
		var zone_name := _zone_at(before)
		if zone_name != "":
			in_zone(zone_name)


func _face_street_done() -> void:
	_zone_forced = _before_row
	_before_row = null
