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
##
## By night (the environment of the level says so, see Settings.apply()) the
## same map is where the moon does not come, which stands where the sun did;
## and the lamps of the level light whoever stands where they shine, which
## is worked out here as it is: a lamp that is shot out lights nobody. See
## light_at().

## The node of this kind in the level that is loaded, or null.
static func of(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group(&"land") if tree else null


## How lit somebody is who stands in the moonlight, next to somebody in the
## sun by day; how strong the lamps that shine on somebody have to be
## together for him to stand in full light (as Fx.lamp_strength() reckons
## them); and how high up a lamp is looked at from, from his feet.
const MOONLIT := 0.25
const LIT := 0.35
const CHEST := Vector3(0, 1.2, 0)
## What stops the light of a lamp: the colliders of the level.
const WORLD := 1
## Under this much light somebody counts as in the dark (by day: in the
## shade), see hidden_at().
const HIDDEN_BY_DAY := 0.5
const HIDDEN_BY_NIGHT := 0.2

var _shade: BitMap
var _land := Rect2()
var _scale := 1.0
## Whether it is night, once known; and the light worked out this physics
## frame, by the spot it was asked for.
var _night: Variant = null
var _lit := {}
var _lit_frame := -1


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


## Whether the level is played by night.
func by_night() -> bool:
	if _night == null:
		var world := get_viewport().find_world_3d().environment if is_inside_tree() else null
		if world == null:
			return false
		_night = world.get_meta(&"night", false)
	return _night


## How well lit somebody is who stands at `at` (his feet), 0 to 1. By day it
## is the sun, all of it out of the shade and none in it. By night it is the
## moon out of its shade, MOONLIT, or the lamps that shine on him with
## nothing in between, whichever is more. `clear` false leaves out whether
## something stands between a lamp and him, which is cheaper and right in
## the open.
func light_at(at: Vector3, clear := true) -> float:
	var sun := 1.0 - shade_around(at)
	if not by_night():
		return sun
	var frame := Engine.get_physics_frames()
	if frame != _lit_frame:
		_lit.clear()
		_lit_frame = frame
	var key := Vector4(snappedf(at.x, 0.25), snappedf(at.y, 0.25), snappedf(at.z, 0.25), 1.0 if clear else 0.0)
	if _lit.has(key):
		return _lit[key]
	var body := at + CHEST
	var lamps := 0.0
	var space := get_viewport().find_world_3d().direct_space_state
	for lamp: Light3D in _lamps():
		var strength := Fx.lamp_strength(lamp, body)
		if strength <= 0.0:
			continue
		if clear:
			var from := lamp.global_position
			# Not from inside the fitting, and not up to his own body.
			var way := (body - from).normalized()
			var ray := PhysicsRayQueryParameters3D.create(from + way * 0.4, body - way * 0.5, WORLD)
			if not space.intersect_ray(ray).is_empty():
				continue
		lamps += strength
		if lamps >= LIT:
			break
	var light := maxf(sun * MOONLIT, clampf(lamps / LIT, 0.0, 1.0))
	_lit[key] = light
	return light


## Whether somebody at `at` stands in the shade by day or in the dark by
## night: what the HUD tells the player.
func hidden_at(at: Vector3) -> bool:
	return light_at(at) < (HIDDEN_BY_NIGHT if by_night() else HIDDEN_BY_DAY)


## The lamps of the level, and the fires that burn in it by night.
func _lamps() -> Array:
	var lamps: Array = Fx.level_lamps().duplicate()
	lamps.append_array(get_tree().get_nodes_in_group(&"night_fire"))
	return lamps
