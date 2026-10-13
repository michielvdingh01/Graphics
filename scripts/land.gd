extends Node
## What a level with land under an open sky knows of its ground: where the
## sun does not come. The level builder works that out when everything
## stands (tools/kit/land.gd) and leaves it on this node as a map of the land,
## two dots to the metre. Whoever stands in the shade is hard to see for an
## enemy that does not know of him yet: scripts/enemy.gd asks here, and the
## HUD to tell the player.
##
## A level without land has no such node, and nobody in it is ever out of
## the light.

## The node of this kind in the level that is loaded, or null.
static func of(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group(&"land") if tree else null


var _shade: BitMap
var _land := Rect2()
var _scale := 1.0


func _ready() -> void:
	add_to_group(&"land")
	_shade = get_meta(&"shade", null) as BitMap
	_land = get_meta(&"land", Rect2())
	if _shade and _land.size.x > 0.0:
		_scale = _shade.get_size().x / _land.size.x
	_rehearse.call_deferred()


## Has everything the level is made of drawn once while it loads, behind the
## black it comes up out of: one mesh for every material there is in it. A
## level of rooms draws all of itself in its first frames; land is too large
## for that, and what is first seen half-way, a tent, a tank, would stall the
## picture while its shaders are made ready. See Fx.rehearse().
func _rehearse() -> void:
	var level := get_parent()
	if level == null or not is_inside_tree():
		return
	var seen := {}
	var looks: Array[MeshInstance3D] = []
	for part: MeshInstance3D in level.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null:
			continue
		var fresh := false
		for i in part.mesh.get_surface_count():
			var material := part.get_active_material(i)
			if material and not seen.has(material):
				seen[material] = true
				fresh = true
		if fresh:
			var look := MeshInstance3D.new()
			look.mesh = part.mesh
			looks.append(look)
	Fx.rehearse(looks)


## The way from the ground to the sun.
func sunward() -> Vector3:
	return get_meta(&"sunward", Vector3.UP)


## True if the sun does not reach somebody who stands at `at`.
func shaded(at: Vector3) -> bool:
	if _shade == null:
		return false
	var dot := Vector2i(((Vector2(at.x, at.z) - _land.position) * _scale).floor())
	var size := _shade.get_size()
	if dot.x < 0 or dot.y < 0 or dot.x >= size.x or dot.y >= size.y:
		return false
	return _shade.get_bitv(dot)


## How much of the ground within `reach` of `at` lies in the shade, 0 to 1:
## somebody on the edge of a shadow is half in it.
func shade_around(at: Vector3, reach := 0.4) -> float:
	var sum := 0.0
	for offset: Vector2 in [Vector2.ZERO, Vector2(reach, 0), Vector2(-reach, 0), Vector2(0, reach), Vector2(0, -reach)]:
		sum += 1.0 if shaded(at + Vector3(offset.x, 0, offset.y)) else 0.0
	return sum / 5.0
