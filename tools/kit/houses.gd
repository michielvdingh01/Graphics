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
## windows: the far bank of a canal that runs out of the level.
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
	var up_there := DETAIL | NO_COLLIDE
	_collide_box(frame * Transform3D(Basis(), Vector3(0, eaves * 0.5, -deep * 0.5)), Vector3(wide, eaves, deep), _surface(mat))
	wall_face(mat, frame * Transform3D(Basis(), Vector3(0, eaves * 0.5, 0)), Vector2(wide, eaves))
	for side in 2:
		var neighbour: float = beside[side]
		if eaves - neighbour < 0.3:
			continue
		var turn := Basis(Vector3.UP, -PI * 0.5 if side == 0 else PI * 0.5)
		var x := -wide * 0.5 if side == 0 else wide * 0.5
		# Down to the street it is lit with the street; over a roof it is not.
		wall_face(mat, frame * Transform3D(turn, Vector3(x, (eaves + neighbour) * 0.5, -deep * 0.5)), Vector2(deep, eaves - neighbour), 0 if neighbour == 0.0 else DETAIL)
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
		_local_box("concrete", frame, Vector3(wide * 0.5 - 1.3, plinth * 0.5, 0.75), Vector3(1.6, plinth, 1.5))
		_local_box("concrete", frame, Vector3(wide * 0.5 - 2.9, plinth * 0.25, 0.75), Vector3(1.6, plinth * 0.5, 1.5))
	# Windows, in bays a good two metres apart: lit for whoever is at home.
	# A lit one is part of what is baked, and lights the street before it.
	var bays := maxi(2, roundi(wide / 2.3))
	var lit: float = fit.get("lit", 0.22)
	for floor_number: int in plan.storeys:
		var sill := plinth + floor_number * storey + storey * 0.28
		if floor_number == 0 and fit.get("shops", false):
			var open := _prop_rng.randf() < 0.75
			wall_face("emissive_warm" if open else "dark_steel", frame * Transform3D(Basis(), Vector3(-0.5, storey * 0.5 + 0.2, 0.03)), Vector2(wide - 2.4, storey - 1.0), 0 if open else DETAIL)
			continue
		var home := _prop_rng.randf() < lit * 1.6
		for bay in bays:
			if floor_number == 0 and bay == bays - 1:
				# The door, at the head of the stoop.
				wall_face("door", frame * Transform3D(Basis(), Vector3(wide * 0.5 - 1.3, plinth + 1.15, 0.03)), Vector2(1.1, 2.3), DETAIL)
				continue
			var x := (bay + 0.5) / bays * wide - wide * 0.5
			var glows := home and _prop_rng.randf() < 0.7
			wall_face("emissive_warm" if glows else "dark_steel", frame * Transform3D(Basis(), Vector3(x, sill + storey * 0.3, 0.03)), Vector2(wide / bays * 0.52, storey * 0.6), 0 if glows else DETAIL)


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
