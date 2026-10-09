extends Node3D
## Draws only the zones of a level that can be seen from where the camera is.
##
## The level builder cuts a level into zones (see zone() in
## tools/level_builder.gd) and notes on each one which boxes it fills and
## which other zones are in sight from inside it. Every frame this looks up
## the zone the camera is in and switches the contents of all others off,
## except the ones in sight. What a frame costs then depends on what can be
## seen, not on how large the level has become.
##
## The shell of a zone, its lightmapped walls, floor and roof, is never
## switched off but left to cast its shadow: without it the sun would shine
## into the zones next to it through the doorways.
##
## The robots are not part of any zone, but one that stands in a zone that is
## switched off is behind the same walls, and is not drawn either.

## How far outside the boxes of a zone the camera still counts as inside it,
## so that the zone behind a doorway is there before the camera is through.
const MARGIN := 0.6
## Frames at the start in which everything is drawn. Whatever is drawn for
## the first time takes a moment, for its shaders and its textures; better
## while the level fades in than when the player walks into the next zone.
## Without them the hall of the factory cost a frame of 290 ms on first sight.
const WARM_FRAMES := 4
## Group of what walks about in the level.
const WALKERS := &"enemy"

## Switch off to draw everything, as a level without zones is drawn; the
## benchmark does that to measure what the zones save (--off=zones).
var culling := true:
	set(value):
		culling = value
		_shown = {}

var _warm := WARM_FRAMES
var _zones: Array[Dictionary] = []
## What is switched on at the moment, by zone name; empty before the first frame.
var _shown := {}
## What walks about and is not drawn at the moment. One of them may be shot
## to pieces by a blast and leave the group while it still lies there.
var _unseen: Array[Node3D] = []


func _ready() -> void:
	for node in get_children():
		if not node.is_in_group("level_zone"):
			continue
		var boxes: Array[AABB] = []
		for box: AABB in node.get_meta(&"bounds"):
			boxes.append(box.grow(MARGIN))
		_zones.append({
			"name": node.get_meta(&"zone"),
			"sees": node.get_meta(&"sees"),
			"boxes": boxes,
			"contents": node.get_node("Contents"),
			"shell": node.get_node_or_null("Static"),
		})


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var at := to_local(camera.global_position)
	var shown := {}
	_warm = maxi(_warm - 1, 0)
	for zone in _zones:
		if not culling or _warm > 0:
			shown[zone.name] = true
		elif zone.boxes.any(func(box: AABB) -> bool: return box.has_point(at)):
			shown[zone.name] = true
			for other: String in zone.sees:
				shown[other] = true
	# A camera outside every zone looks at the level from afar: draw it all.
	if shown.is_empty():
		for zone in _zones:
			shown[zone.name] = true
	_hide_walkers(shown)
	if shown == _shown:
		return
	_shown = shown
	for zone in _zones:
		var on: bool = shown.has(zone.name)
		zone.contents.visible = on
		if zone.shell:
			zone.shell.cast_shadow = (
				GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on
				else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			)


## Draws what walks about only where it stands in a zone that is drawn, or
## in none.
func _hide_walkers(shown: Dictionary) -> void:
	var walkers := get_tree().get_nodes_in_group(WALKERS)
	for node in _unseen:
		if is_instance_valid(node) and node not in walkers:
			walkers.append(node)
	_unseen.clear()
	for walker: Node3D in walkers:
		var at := to_local(walker.global_position) + Vector3.UP
		var inside := false
		var in_sight := false
		for zone in _zones:
			if zone.boxes.any(func(box: AABB) -> bool: return box.has_point(at)):
				inside = true
				in_sight = in_sight or shown.has(zone.name)
		walker.visible = in_sight or not inside
		if not walker.visible:
			_unseen.append(walker)


## Names of the zones that are drawn at the moment.
func drawn() -> PackedStringArray:
	return PackedStringArray(_shown.keys())
