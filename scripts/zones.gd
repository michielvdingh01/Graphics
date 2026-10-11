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
## into the zones next to it through the doorways. The same goes for what
## moves in that shell, such as the shutter at an exit.
##
## The robots are not part of any zone, but one that stands in a zone that is
## switched off is behind the same walls, and is not drawn either.
##
## Two things more are done once, when the level loads, for the zones that
## are drawn together. A lamp is held to the zones its light can get to, see
## _bind_lamps(); and the walls of the level are handed to the renderer as
## occluders, see _wall_off(), so that of a zone in sight only what is not
## behind a wall is drawn.

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

## Render layers. Layer 1 is whatever belongs to no zone, 2 the weapon in view
## (scripts/weapons.gd) and 3 what belongs to no zone and stands in the shade
## (scripts/shade.gd). The layers from FIRST_COLOUR on go round the zones:
## COLOURS of them for what the sun may fall on and as many again for what
## stands in the shade. Two zones share a colour where no lamp has to tell
## them apart. All of it fits the twenty layers that a camera, a decal and a
## reflection probe look at unless told otherwise.
const SHADE_LAYER := 3
const FIRST_COLOUR := 4
const COLOURS := 8
## Every layer of what stands in the shade.
const SHADE_MASK := (1 << (SHADE_LAYER - 1)) | (((1 << COLOURS) - 1) << (FIRST_COLOUR - 1 + COLOURS))
## The layers of what belongs to no zone, which every lamp goes on lighting:
## the ground outside, the robots, the weapon, and whatever the game makes.
const COMMON_MASK := (1 << (FIRST_COLOUR - 1)) - 1
## What a lamp lights that is held to nothing.
const EVERY_LAYER := 0xFFFFFFFF
## What stops the light of a lamp: the colliders of the level.
const WORLD := 1
## Rays that go out from a lamp in every direction to find where its light
## gets to, over and above the ones aimed at every doorway and window.
const LAMP_RAYS := 300
## How far apart those aimed at a doorway are, in metres.
const OPENING_STEP := 0.3
## How far such a ray is followed into what stops it, in metres: less than
## the thinnest wall of a room, which is 0.2 m.
const INTO_WALL := 0.1
## A box collider of the level counts as a wall, for an occluder, when it is
## no thicker than this and at least WALL_SPAN long and high, in metres.
const WALL_THICK := 0.5
const WALL_SPAN := 1.2
## How far inside the wall its occluder stays, in metres.
const OCCLUDER_INSET := 0.02

## Switch off to draw everything, as a level without zones is drawn; the
## benchmark does that to measure what the zones save (--off=zones).
var culling := true:
	set(value):
		culling = value
		_shown = {}

## Switch off to let every lamp light whatever is within its range, as it
## did before; the benchmark does that to measure what holding them saves
## (--undo=lamps).
var lamps_bound := true:
	set(value):
		lamps_bound = value
		# A lamp that was shot out may be gone by now.
		for light: Variant in _held:
			if is_instance_valid(light):
				light.light_cull_mask = _held[light] if value else EVERY_LAYER
				light.shadow_caster_mask = _held[light] if value else EVERY_LAYER

## Switch off to draw whatever of a zone in sight is in view, behind a wall
## or not (--undo=occlusion).
var occlusion := true:
	set(value):
		occlusion = value
		_occlude()

var _warm := WARM_FRAMES
var _zones: Array[Dictionary] = []
## What is switched on at the moment, by zone name; empty before the first frame.
var _shown := {}
## What walks about and is not drawn at the moment. One of them may be shot
## to pieces by a blast and leave the group while it still lies there.
var _unseen: Array[Node3D] = []
## The lamps that are held to their zones, with the layers each one lights.
var _held := {}
var _occluder: OccluderInstance3D


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
			"bounds": node.get_meta(&"bounds"),
			"node": node,
			"contents": node.get_node("Contents"),
			"shells": _shells(node),
		})
	# A benchmark can ask for either to be left as it was, see UNDO in
	# scripts/settings.gd; the level builder loads this without the game.
	var settings := get_node_or_null("/root/Settings")
	if settings:
		lamps_bound = not settings.undone("lamps")
		occlusion = not settings.undone("occlusion")
	_wall_off()
	_bind_lamps()


func _exit_tree() -> void:
	# The window outlives the level.
	get_viewport().use_occlusion_culling = false


## What of a zone stays when it is switched off: its shell, and the meshes of
## the parts that the game moves.
func _shells(zone: Node) -> Array[GeometryInstance3D]:
	var shells: Array[GeometryInstance3D] = []
	for child in zone.get_children():
		if child.name == &"Contents" or child.is_in_group("bake_blocker"):
			continue
		if child is GeometryInstance3D:
			shells.append(child)
		for part: GeometryInstance3D in child.find_children("*", "GeometryInstance3D", true, false):
			shells.append(part)
	return shells


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var at := to_local(camera.global_position)
	var shown := {}
	if _warm > 0:
		_warm -= 1
		if _warm == 0:
			_occlude()
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
		for shell: GeometryInstance3D in zone.shells:
			shell.cast_shadow = (
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


## The layers of something that stood on `layers` and turns out to stand in
## the shade: scripts/shade.gd asks.
static func shaded(layers: int) -> int:
	var colours := (layers >> (FIRST_COLOUR - 1)) & ((1 << COLOURS) - 1)
	if colours:
		return colours << (FIRST_COLOUR - 1 + COLOURS)
	return layers if layers & SHADE_MASK else 1 << (SHADE_LAYER - 1)


## Holds the lamps of the level to the zones their light can get to.
##
## A lamp lights whatever lies within its range, and the renderer works that
## out for every pixel there: behind a wall as well, in the room next door,
## where it then looks up the lamp's shadow to find that nothing arrives.
## With rooms in rows along a corridor, a pixel pays for the lamps of four
## rooms and is lit by those of one.
##
## So, once the colliders of the level are in the world, rays go out from
## every lamp: at each doorway and window within its range, and all round.
## A zone that such a ray passes through before it is stopped is one the lamp
## gets to. The zones are then given render layers, so that no lamp gets to
## one zone and, within its range, not to another of the same layer, and the
## lamp lights only the layers of the zones it gets to. It also leaves the
## others out of its shadow: what stands in them cannot be between the lamp
## and anything it lights.
##
## Only the level itself stops a ray: what can be shot to pieces, blown up or
## rolled open is looked through, and so is a robot.
##
## This goes for the lamps that cast a shadow, whose light never got past
## the wall. A lamp without one does light the room behind the wall, and is
## left to: holding those as well left half of a room of the powerhouse dark
## that had its light from the corridor next to it.
func _bind_lamps() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree() or _zones.size() < 2:
		return
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, WORLD)
	var walls := get_node_or_null("Collision")
	var passing: Array[RID] = []
	var scene := get_tree().current_scene
	if walls and scene:
		for body: CollisionObject3D in scene.find_children("*", "CollisionObject3D", true, false):
			if body != walls and body.collision_layer & WORLD:
				passing.append(body.get_rid())
	ray.exclude = passing
	var openings := _openings()
	var all_round := _all_round(LAMP_RAYS)

	# For every lamp, the zones it gets to and the ones within its range that
	# it does not get to.
	var lamps: Array[Dictionary] = []
	for light: Light3D in find_children("*", "Light3D", true, false):
		if light is DirectionalLight3D:
			continue
		var from := light.global_position
		var here := to_local(from)
		var spot := light as SpotLight3D
		var reach: float = spot.spot_range if spot else (light as OmniLight3D).omni_range
		var reached := PackedInt32Array()
		var missed := PackedInt32Array()
		# The boxes of the zones it has not got to yet, and whose they are.
		var boxes: Array[AABB] = []
		var owners := PackedInt32Array()
		for i in _zones.size():
			var inside := false
			var near: Array[AABB] = []
			for box: AABB in _zones[i].bounds:
				inside = inside or box.has_point(here)
				if here.distance_to(here.clamp(box.position, box.end)) < reach:
					near.append(box)
			if inside:
				reached.append(i)
			elif not near.is_empty():
				missed.append(i)
				for box in near:
					boxes.append(box)
					owners.append(i)
		if not light.shadow_enabled:
			# Without a shadow its light goes through walls and is there to be
			# seen, in the room next door as well: it keeps all it lit.
			reached.append_array(missed)
			missed.clear()
		if not missed.is_empty():
			var aims := PackedVector3Array()
			for point in openings:
				if from.distance_to(point) < reach:
					aims.append(from.direction_to(point))
			aims.append_array(all_round)
			var axis := -light.global_basis.z
			var cone := cos(deg_to_rad(minf(spot.spot_angle + 3.0, 180.0))) if spot else -1.0
			for aim in aims:
				if aim.dot(axis) < cone:
					continue
				ray.from = from
				ray.to = from + aim * reach
				var hit := space.intersect_ray(ray)
				# A little way into what stopped it: the outside of a wall
				# or a roof that a lamp shines on belongs to a zone as well,
				# is lit by that lamp and keeps its light from what is behind.
				var end := to_local(hit.position + aim * INTO_WALL if hit else ray.to)
				for b in range(boxes.size() - 1, -1, -1):
					var zone := owners[b]
					if zone in missed and boxes[b].intersects_segment(here, end) != null:
						missed.remove_at(missed.find(zone))
						reached.append(zone)
				if missed.is_empty():
					break
		lamps.append({"light": light, "reached": reached, "missed": missed})

	# A colour for every zone: another one than any zone it has to be told
	# apart from, as long as there are colours. Without one left it shares
	# the colour it clashes with least, and a lamp or two light through a
	# wall as they did before.
	var clashes: Array[Dictionary] = []
	for i in _zones.size():
		clashes.append({})
	for lamp in lamps:
		for i: int in lamp.reached:
			for j: int in lamp.missed:
				clashes[i][j] = clashes[i].get(j, 0) + 1
				clashes[j][i] = clashes[j].get(i, 0) + 1
	var order := range(_zones.size())
	order.sort_custom(func(a: int, b: int) -> bool: return clashes[a].size() > clashes[b].size() or (clashes[a].size() == clashes[b].size() and a < b))
	var colour := PackedInt32Array()
	colour.resize(_zones.size())
	colour.fill(-1)
	for i: int in order:
		var taken := PackedInt32Array()
		taken.resize(COLOURS)
		for j: int in clashes[i]:
			if colour[j] >= 0:
				taken[colour[j]] += clashes[i][j]
		var best := 0
		for c in COLOURS:
			if taken[c] < taken[best]:
				best = c
		colour[i] = best

	for i in _zones.size():
		var node: Node = _zones[i].node
		for instance: GeometryInstance3D in node.find_children("*", "GeometryInstance3D", true, false):
			var in_shade := instance.layers & SHADE_MASK != 0
			instance.layers = 1 << (FIRST_COLOUR - 1 + colour[i] + (COLOURS if in_shade else 0))
	for lamp in lamps:
		var mask := COMMON_MASK
		for i: int in lamp.reached:
			mask |= (1 | (1 << COLOURS)) << (FIRST_COLOUR - 1 + colour[i])
		_held[lamp.light] = mask
	lamps_bound = lamps_bound


## A point in every pane of glass and every OPENING_STEP across every doorway
## of the level: where the light of a lamp may leave its zone.
func _openings() -> PackedVector3Array:
	var points := PackedVector3Array()
	for panel: MeshInstance3D in get_tree().get_nodes_in_group("bake_blocker"):
		if panel.mesh == null or not is_ancestor_of(panel):
			continue
		var box := panel.mesh.get_aabb()
		var steps := Vector3i((box.size / OPENING_STEP).ceil()).clamp(Vector3i.ONE, Vector3i.ONE * 16)
		for x in steps.x:
			for y in steps.y:
				for z in steps.z:
					points.append(panel.global_transform * (box.position + box.size * Vector3((x + 0.5) / steps.x, (y + 0.5) / steps.y, (z + 0.5) / steps.z)))
	for glass: MeshInstance3D in find_children("Glass", "MeshInstance3D", true, false):
		if glass.mesh == null:
			continue
		var faces := glass.mesh.get_faces()
		var seen := {}
		for i in range(0, faces.size(), 3):
			var middle := (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
			var key := Vector3i((middle / OPENING_STEP).round())
			if not seen.has(key):
				seen[key] = true
				points.append(glass.global_transform * middle)
	return points


## `count` directions spread evenly over the sphere.
func _all_round(count: int) -> PackedVector3Array:
	var directions := PackedVector3Array()
	for i in count:
		var y := 1.0 - 2.0 * (i + 0.5) / count
		var turn := i * PI * (3.0 - sqrt(5.0))
		directions.append(Vector3(cos(turn) * sqrt(1.0 - y * y), y, sin(turn) * sqrt(1.0 - y * y)))
	return directions


## Has the renderer leave out what a wall hides, or not: not while the level
## is still drawing everything once, see WARM_FRAMES.
func _occlude() -> void:
	if is_inside_tree():
		get_viewport().use_occlusion_culling = occlusion and _occluder != null and _warm == 0


## Hands the walls of the level to the renderer as occluders.
##
## The zones in sight are drawn whole or not at all: from a room on a
## corridor that is the corridor and every room that can be looked into from
## anywhere in this one, though from where the camera stands most of them are
## behind a wall. With occluders the renderer leaves out what a wall hides,
## model by model.
##
## A wall is a box of the level builder, which is as solid as its collider:
## the two are made together. Of the colliders only those of brick, concrete
## and plaster count, thin and at least WALL_SPAN long and high, so that a
## rack, a fence or a barrier, whose collider is a box around something that
## can be seen through or past, hides nothing.
func _wall_off() -> void:
	var body := get_node_or_null("Collision") as Node3D
	if body == null:
		return
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for node in body.get_children():
		var collider := node as CollisionShape3D
		var shape := (collider.shape if collider else null) as BoxShape3D
		if shape == null or collider.disabled or collider.get_meta(&"surface", "") not in ["", "brick"]:
			continue
		var sizes := [shape.size.x, shape.size.y, shape.size.z]
		sizes.sort()
		if sizes[0] > WALL_THICK or sizes[1] < WALL_SPAN:
			continue
		var half := shape.size * 0.5 - Vector3.ONE * OCCLUDER_INSET
		if half.x <= 0.0 or half.y <= 0.0 or half.z <= 0.0:
			continue
		var first := vertices.size()
		var place := body.transform * collider.transform
		for corner in 8:
			vertices.append(place * (half * Vector3(1.0 if corner & 1 else -1.0, 1.0 if corner & 2 else -1.0, 1.0 if corner & 4 else -1.0)))
		for index: int in [0, 1, 3, 0, 3, 2, 4, 6, 7, 4, 7, 5, 0, 4, 5, 0, 5, 1, 2, 3, 7, 2, 7, 6, 0, 2, 6, 0, 6, 4, 1, 5, 7, 1, 7, 3]:
			indices.append(first + index)
	if indices.is_empty():
		return
	var walls := ArrayOccluder3D.new()
	walls.set_arrays(vertices, indices)
	_occluder = OccluderInstance3D.new()
	_occluder.name = "Walls"
	_occluder.occluder = walls
	add_child(_occluder)
	# Only what is drawn itself is left out behind a wall. A lightmap, a lamp,
	# a reflection probe and a decal are known to the renderer by a box, and
	# that box being hidden says nothing of what they light or colour: with
	# the box of its lightmap behind a wall, seen from a corner, a room was
	# drawn without its baked light.
	for node: VisualInstance3D in find_children("*", "VisualInstance3D", true, false):
		if not node is GeometryInstance3D:
			RenderingServer.instance_geometry_set_flag(node.get_instance(), RenderingServer.INSTANCE_FLAG_IGNORE_OCCLUSION_CULLING, true)
