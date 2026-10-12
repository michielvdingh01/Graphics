extends Node3D
## What can be shot to pieces in a level: the stacks of wooden crates, the
## cardboard boxes and the lamps. The level builder knows nothing of it. A
## level is generated and lightmapped and comes as it is; scripts/game.gd
## adds this node to it as Level/Breakables when it loads, on every machine,
## and this goes through what the builder saved and gives everything that
## can break a body of its own: scripts/stack.gd around what is stacked and
## scripts/lamp.gd around a lamp.
##
## The level is the same on every machine and is gone through in the order
## of its tree, so the bodies get the same names everywhere, which is what
## scripts/net.gd finds them by. Whatever is not as expected is left as it
## was, with a warning that names it.

const STACK := preload("res://scripts/stack.gd")
const LAMP := preload("res://scripts/lamp.gd")
## The layers of a stack: the world, which it is part of as before, and the
## layer that shots and blasts look for what breaks on. A lamp is on that
## one alone, so nothing else finds it: it is in nobody's way, as before.
const WORLD := 1
const BREAKABLE := 32
## The layer of the glass in the windows, which no shot stops at and no look.
## Whatever asks where a shot went finds it there, see Fx.tracer().
const WINDOW := 64
## The models that are stacked, by the folder they come from: what their
## collider is made of, and what kind of thing they are to a stack.
const STACKED := {
	"wooden_crate_02": {"surface": "wood", "kind": STACK.Kind.CRATE},
	"cardboard_box_01": {"surface": "soft", "kind": STACK.Kind.CARTON},
}
## How far the middle of a model may lie from the upright through the middle
## of its collider, in metres. The builder puts it there exactly.
const ON_AXIS := 0.02
## How much the models of a collider may be higher or lower together than
## the collider is, and how far the underside of a stack may be from the top
## of the one it stands on, in metres.
const SLACK := 0.03
## The lights that are lamps, where they hang under a node called Lights:
## their class, what their name begins with and the kind of lamp they are.
const LAMPS := [
	["SpotLight3D", "HallLamp", LAMP.Kind.HALL],
	["OmniLight3D", "Bulb", LAMP.Kind.BULB],
	["OmniLight3D", "Tube", LAMP.Kind.TUBE],
	["SpotLight3D", "Floodlight", LAMP.Kind.FLOOD],
	["SpotLight3D", "WorkLamp", LAMP.Kind.WORK],
]
## The folder the model of a hall lamp comes from.
const HUNG := "hanging_industrial_lamp"
## How far the light of a hall lamp may be from the middle of its glass, and
## how far the middle of anything that glows from the light it glows by, in
## metres.
const PAIRED := 0.6
const GLOW_REACH := 0.8
## What glows in the meshes of a level is made of one of these.
const GLOWING: Array[String] = ["res://materials/emissive_warm.tres", "res://materials/emissive_cool.tres"]


## A box collider of the level that models may turn out to be stacked in.
class Box:
	var node: CollisionShape3D
	## Takes a point in the level to the space of the collider.
	var inverse: Transform3D
	var size: Vector3
	var kind := STACK.Kind.CRATE
	var models: Array[Node3D] = []
	## The stack this one stands on, if it stands on one.
	var on: Box


## What _rehearse() has drawn once, besides the boards and the lamps: each
## of the _adopt functions adds the looks that are new with it.
var _looks: Array[MeshInstance3D] = []


func _ready() -> void:
	var level := get_parent() as Node3D
	_adopt_stacks(level)
	_adopt_lamps(level)
	_adopt_windows(level)
	_adopt_tinder(level)
	_adopt_exits(level)
	_rehearse()


## Gives every stack of crates and every cardboard box a body of its own.
## The builder made one box collider for each, in the one body of the level,
## and the models as loose props: a model belongs to the collider that its
## middle is in, on the upright through the middle of that collider. Stacks
## that stand on each other go into one body, since the upper one comes down
## when the lower one goes.
func _adopt_stacks(level: Node3D) -> void:
	# The box colliders that stand upright, by what they are made of. A level
	# has one body called Collision; one that is put together from copies of
	# a level has one in each copy.
	var boxes := {}
	for ground: StaticBody3D in level.find_children("Collision", "StaticBody3D", true, false):
		for collider in ground.get_children():
			if collider is CollisionShape3D and collider.shape is BoxShape3D and _upright(collider):
				var box := Box.new()
				box.node = collider
				box.inverse = collider.global_transform.affine_inverse()
				box.size = collider.shape.size
				var surface: String = collider.get_meta(&"surface", "")
				if not boxes.has(surface):
					boxes[surface] = []
				boxes[surface].append(box)
	var stacks: Array[Box] = []
	for model: Node3D in level.find_children("*", "Node3D", true, false):
		var folder := model.scene_file_path.get_base_dir().get_file()
		if not STACKED.has(folder):
			continue
		var middle := model.global_transform * STACK.box_of(model).get_center()
		var found: Array[Box] = []
		if _upright(model):
			for box: Box in boxes.get(STACKED[folder].surface, []):
				var offset := box.inverse * middle
				if Vector2(offset.x, offset.z).length() <= ON_AXIS and absf(offset.y) <= box.size.y * 0.5:
					found.append(box)
		if found.size() != 1:
			push_warning("Breakables: %s is in %d colliders and stays as it is" % [level.get_path_to(model), found.size()])
			continue
		if found[0].models.is_empty():
			stacks.append(found[0])
		found[0].kind = STACKED[folder].kind
		found[0].models.append(model)
		# Cut into its pieces now, not in the middle of a fight.
		STACK.pieces_of(model)
	# The models of a collider from the lowest up, which have to be as high
	# together as the collider is.
	for stack: Box in stacks.duplicate():
		stack.models.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.y < b.global_position.y)
		var height := 0.0
		for model in stack.models:
			height += STACK.box_of(model).size.y * model.global_basis.get_scale().y
		if absf(height - stack.size.y) > SLACK:
			push_warning("Breakables: %s is %.2f m high and its %d models %.2f m, so it stays as it is" % [level.get_path_to(stack.node), stack.size.y, stack.models.size(), height])
			stacks.erase(stack)
	# What stands on what: a stack whose underside lies on the top of another.
	for stack in stacks:
		var underside := stack.node.global_transform * Vector3(0.0, -stack.size.y * 0.5, 0.0)
		for other in stacks:
			var offset := other.inverse * underside
			if other != stack and absf(offset.y - other.size.y * 0.5) <= SLACK and absf(offset.x) <= other.size.x * 0.5 and absf(offset.z) <= other.size.z * 0.5:
				stack.on = other
				break
	# A body for every stack that stands on the floor, and into it that stack
	# and whatever stands on it, from the floor up. The colliders keep their
	# place in the level and what they are made of.
	var count := 0
	for stack in stacks:
		if stack.on:
			continue
		var body: StaticBody3D = STACK.new()
		body.name = "Stack%d" % count
		count += 1
		body.collision_layer = WORLD | BREAKABLE
		add_child(body)
		body.global_position = stack.node.global_transform * Vector3(0.0, -stack.size.y * 0.5, 0.0)
		var pile: Array[Box] = [stack]
		var done := 0
		while done < pile.size():
			for other in stacks:
				if other.on == pile[done]:
					pile.append(other)
			done += 1
		for part in pile:
			part.node.reparent(body)
			body.cover(part.node, part.kind, part.models, part.on.node if part.on else null)


## Finds what can catch fire besides the stacks. Whatever becomes a child of
## this node is kept by scripts/game.gd in a list for those who come into the
## level later, and has a net_state() and a net_restore() as a stack has.
func _adopt_tinder(_level: Node3D) -> void:
	pass


## Gives every lamp a body of its own: the hall lamps, which are models,
## lit or not, and every light of one of the LAMPS, with what glows by it.
func _adopt_lamps(level: Node3D) -> void:
	var lights: Array[Light3D] = []
	lights.assign(level.find_children("*", "Light3D", true, false))
	var lamps := {}
	var count := 0
	for model: Node3D in level.find_children("*", "Node3D", true, false):
		if model.scene_file_path.get_base_dir().get_file() != HUNG:
			continue
		var lamp: StaticBody3D = LAMP.new()
		lamp.name = "Lamp%d" % count
		lamp.collision_layer = BREAKABLE
		add_child(lamp)
		lamp.global_transform = Transform3D(model.global_basis.orthonormalized(), model.global_position)
		var hung := false
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			hung = hung or lamp.hang(mesh)
		if not hung:
			push_warning("Breakables: %s has no glass and stays as it is" % level.get_path_to(model))
			lamp.free()
			continue
		count += 1
		# Its light, if it is on: the one that hangs under its glass.
		var glass: Vector3 = (lamp.get_child(0) as Node3D).global_position
		for light in lights:
			if _kind_of(light) == LAMP.Kind.HALL and not lamps.has(light) and light.global_position.distance_to(glass) <= PAIRED:
				lamp.light = light
				lamps[light] = lamp
				break
	for light in lights:
		var kind := _kind_of(light)
		if kind < 0 or lamps.has(light):
			continue
		var lamp: StaticBody3D = LAMP.new()
		lamp.name = "Lamp%d" % count
		count += 1
		lamp.collision_layer = BREAKABLE
		lamp.kind = kind
		lamp.light = light
		if kind == LAMP.Kind.FLOOD or kind == LAMP.Kind.WORK:
			lamp.facing = -light.global_basis.z
		add_child(lamp)
		lamp.global_transform = light.global_transform
		lamps[light] = lamp
	# What glows goes to the lamp of the light it is nearest to, if that is
	# near enough: measured in the space of that light, since a floodlight
	# is aimed and its glass lies askew in the level.
	for glow in _find_glow(level):
		var around := AABB(glow[0], Vector3.ZERO)
		for point in glow:
			around = around.expand(point)
		var nearest: Light3D = null
		for light in lights:
			if nearest == null or light.global_position.distance_to(around.get_center()) < nearest.global_position.distance_to(around.get_center()):
				nearest = light
		var lamp: StaticBody3D = lamps.get(nearest)
		if lamp and lamp.kind != LAMP.Kind.HALL and nearest.global_position.distance_to(around.get_center()) <= GLOW_REACH:
			lamp.lens(lamp.global_transform.affine_inverse() * glow)
	for light: Light3D in lamps:
		if lamps[light].get_child_count() == 0:
			push_warning("Breakables: nothing glows by %s, so it goes out and leaves no dark glass" % level.get_path_to(light))
			lamps[light].bare()


## Gives the glass in the windows bodies of its own, on the layer WINDOW.
func _adopt_windows(_level: Node3D) -> void:
	pass


## Has everything that breaking brings into view drawn once now, while the
## level comes up out of black: a board of every model that is stacked, a
## hall lamp without its glass, the dark glass of the other lamps, and the
## splinters, the shards and the sparks. See Fx.rehearse() for why.
func _rehearse() -> void:
	var looks: Array[MeshInstance3D] = STACK.first_pieces()
	looks.append_array(_looks)
	var hall := false
	var other := false
	for body in get_children():
		if not body.has_method("broken_look") or (hall if body.kind == LAMP.Kind.HALL else other):
			continue
		var look: MeshInstance3D = body.broken_look()
		if look:
			looks.append(look)
			if body.kind == LAMP.Kind.HALL:
				hall = true
			else:
				other = true
	Fx.rehearse(looks)


## Sees to what the way out of the level lets in once its door goes up.
func _adopt_exits(_level: Node3D) -> void:
	pass


## The kind of lamp a light is, or -1 if it is not one of the LAMPS.
func _kind_of(light: Light3D) -> int:
	if light.get_parent().name != &"Lights":
		return -1
	for lamp: Array in LAMPS:
		if light.is_class(lamp[0]) and String(light.name).begins_with(lamp[1]):
			return lamp[2]
	return -1


## What glows in the meshes the level itself is made of: every group of
## triangles of a glowing material that hang together is the glass of one
## lamp. For each, the corners of its triangles, three by three, as they lie
## in the level. Only the surfaces of those materials are gone through,
## which are a few dozen triangles each.
func _find_glow(level: Node3D) -> Array[PackedVector3Array]:
	var found: Array[PackedVector3Array] = []
	for mesh: MeshInstance3D in level.find_children("*", "MeshInstance3D", true, true):
		# Not the meshes of the models that stand in it.
		if mesh.owner != level or mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(surface)
			if material == null or not GLOWING.has(material.resource_path):
				continue
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] else PackedInt32Array(range(vertices.size()))
			# Which group each vertex is in: that of the first vertex at the
			# same place to begin with, since the sides of a box share no
			# vertices, and from there that of whatever a triangle joins it to.
			var places := {}
			var group := PackedInt32Array()
			for i in vertices.size():
				var place := Vector3i((vertices[i] * 1000.0).round())
				if not places.has(place):
					places[place] = i
				group.append(places[place])
			for corner in range(0, indices.size(), 3):
				var a := _first_of(group, indices[corner])
				var b := _first_of(group, indices[corner + 1])
				var c := _first_of(group, indices[corner + 2])
				var first := mini(a, mini(b, c))
				group[a] = first
				group[b] = first
				group[c] = first
			var groups := {}
			for corner in range(0, indices.size(), 3):
				var first := _first_of(group, indices[corner])
				if not groups.has(first):
					groups[first] = PackedVector3Array()
				var points: PackedVector3Array = groups[first]
				for i in 3:
					points.append(mesh.global_transform * vertices[indices[corner + i]])
				groups[first] = points
			found.append_array(groups.values())
	return found


## The vertex that stands for the group that vertex `index` is in.
func _first_of(group: PackedInt32Array, index: int) -> int:
	while group[index] != index:
		index = group[index]
	return index


## True if something stands straight up, turned about its upright at most.
func _upright(node: Node3D) -> bool:
	return node.global_basis.y.normalized().is_equal_approx(Vector3.UP)
