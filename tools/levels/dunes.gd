extends "res://tools/levels/dunes/plan.gd"
## The dunes: from the edge of a wood over the dunes to the back door of the
## complex an army guards there, by day. Build with: tools/build_level.sh dunes
##
## The plan is in tools/levels/dunes/plan.gd, with the lie of the land and
## what grows on it, and next to it a file for every stretch of the way.

const STRETCHES: Array[String] = ["wood", "valley", "camp", "complex"]


func _describe() -> void:
	# The land is laid in blocks of its own; what stands on it is cut to match.
	_detail_block = Vector3(32, 400, 32)
	_lie_of_the_land()
	_grow()
	for file in STRETCHES:
		build(file)
	build("outside")
	for file in STRETCHES:
		build(file, &"_route_through")


## Where to look at the level from, for tools/zone_sheet.py: what the player
## sees as he comes to each stretch of the way, before the views the builder
## picks for itself. Each is x and z, then the turn and the tilt of the look.
const VIEWS: Array[Vector4] = [
	Vector4(16, 199.5, -85, -3), Vector4(60, 200, -70, -2), Vector4(88, 193, -80, -2), Vector4(122, 187, -88, -2),
	Vector4(160, 188, -82, -2), Vector4(226, 172.5, 140, -8), Vector4(271, 167, -15, -3), Vector4(278, 148, 5, -4),
	Vector4(279, 127, 0, -4), Vector4(232, 121, 92, -3), Vector4(190, 124, 80, -2), Vector4(148, 123, 92, -2),
	Vector4(52, 100, -5, -2), Vector4(60, 84, -25, -1), Vector4(69, 52, -70, -1), Vector4(120, 34, -88, 0),
	Vector4(166, 16, -90, 1), Vector4(218, 17, -78, 2), Vector4(238, 12, 180, 4),
]


func _own_views(zone_name: String) -> PackedFloat32Array:
	var views := PackedFloat32Array()
	if zone_name == "":
		for view in VIEWS:
			views.append_array([view.x, snappedf(ground_height(view.x, view.y) + 1.6, 0.01), view.y, view.z, view.w])
	return views
