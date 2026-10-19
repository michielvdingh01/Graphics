extends Node3D
## The trees of a level of kilometres: tens of thousands, too many to stand
## each as a scene of its own the way the pines of the dunes stand. The level
## builder plants them and writes where each stands into a file of the level
## (tools/levels/alps/plan.gd, plant()); this node reads it when the level
## loads and draws every kind as MultiMeshes, cell by cell, and gives every
## trunk its collider.
##
## A tree model (tools/models/trees.gd) is a few drawings of the same tree,
## each a mesh of its own: Body from close by, Mid, Far as one card, and
## Shade, which is never seen and only throws the shadow. Which of them shows
## goes by how far off each tree is, in its shaders (tree_lod.gdshaderinc),
## so a MultiMesh of a whole cell can carry them all; the cell itself is only
## drawn while some of its trees can be close enough for the drawing it
## carries, as its visibility range.
##
## The file is a Resource whose metadata holds, for every kind of tree, the
## cells (Vector2i, CELL metres square) and in each the transforms of its
## trees as a MultiMesh buffer, twelve numbers a tree, and their girths.

## How large a cell is, in metres. The builder files the trees by it.
const CELL := 64.0
## The parts of a tree model that are drawn, and whether each throws a
## shadow or is only a shadow.
const PARTS := ["Body", "Mid", "Far", "Shade"]
## How high a trunk's collider reaches.
const TRUNK := 6.0

## The trees as the builder planted them.
@export var plantings: Resource
## Where the sun reaches the land, as the ground reads it far off, and the
## rect of the land it covers (x, z, 1/width, 1/depth): the pictures of trees
## far off read it too, so that the trees in the shadow of the mountains are
## in it (shaders/tree_far.gdshader).
@export var sun_map: Texture2D
@export var sun_rect := Vector4()

## How many trees stand, and how many cells hold them.
var trees := 0
var cells := 0


func _ready() -> void:
	if plantings == null:
		return
	var began := Time.get_ticks_usec()
	var shapes := {}
	var bodies := {}
	for kind: String in plantings.get_meta_list():
		var planted: Dictionary = plantings.get_meta(kind)
		var scene := load("res://scenes/models/%s.scn" % kind) as PackedScene
		if scene == null:
			push_warning("Grove: there is no model %s" % kind)
			continue
		var model := scene.instantiate()
		var parts := _parts_of(model)
		var girth: float = model.get_meta(&"girth", 0.0)
		var height: float = model.get_meta(&"height", 20.0)
		model.free()
		for cell: Vector2i in planted.cells:
			var buffer: PackedFloat32Array = planted.cells[cell]
			var count := buffer.size() / 12
			# The visibility range of a cell goes by its middle; a tree in a
			# corner is this much nearer or further.
			var radius := CELL * 0.71
			for part: Dictionary in parts:
				var multi := MultiMesh.new()
				multi.transform_format = MultiMesh.TRANSFORM_3D
				multi.mesh = part.mesh
				multi.instance_count = count
				multi.buffer = buffer
				var shown := MultiMeshInstance3D.new()
				shown.multimesh = multi
				shown.custom_aabb = AABB(Vector3(cell.x * CELL - 8.0, _low(buffer) - 2.0, cell.y * CELL - 8.0), Vector3(CELL + 16.0, _high(buffer) - _low(buffer) + height + 4.0, CELL + 16.0))
				shown.cast_shadow = part.shadow
				if part.begin > 0.0:
					shown.visibility_range_begin = maxf(0.0, part.begin - radius)
				if part.end > 0.0:
					shown.visibility_range_end = part.end + radius
				shown.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				add_child(shown)
			if girth > 0.0:
				_trunks(buffer, girth, shapes, bodies, cell)
			trees += count
			cells += 1
	print("Grove: %d trees in %d cells, in %.0f ms" % [trees, cells, (Time.get_ticks_usec() - began) / 1000.0])


## What of a tree model is drawn: [{mesh, begin, end, shadow}], each part with
## its materials put on its mesh, which a MultiMesh has no other way to carry.
func _parts_of(model: Node) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	for part_name: String in PARTS:
		var part := model.get_node_or_null(part_name) as MeshInstance3D
		if part == null or part.mesh == null:
			continue
		var mesh := part.mesh.duplicate() as Mesh
		for i in mesh.get_surface_count():
			var material := part.get_surface_override_material(i)
			if material == null and part.material_override:
				material = part.material_override
			if material and sun_map and material is ShaderMaterial and (material as ShaderMaterial).shader.resource_path.ends_with("tree_far.gdshader"):
				material = material.duplicate()
				material.set_shader_parameter(&"sun_map", sun_map)
				material.set_shader_parameter(&"sun_rect", sun_rect)
			if material:
				mesh.surface_set_material(i, material)
		parts.append({"mesh": mesh, "begin": part.visibility_range_begin, "end": part.visibility_range_end, "shadow": part.cast_shadow})
	return parts


## The lowest and highest foot in a buffer of transforms.
func _low(buffer: PackedFloat32Array) -> float:
	var low := INF
	for i in range(7, buffer.size(), 12):
		low = minf(low, buffer[i])
	return low


func _high(buffer: PackedFloat32Array) -> float:
	var high := -INF
	for i in range(7, buffer.size(), 12):
		high = maxf(high, buffer[i])
	return high


## The trunks of a cell, as colliders in a body of the cell: a cylinder each,
## as thick as the tree's girth at its size, shared between trees of about
## the same size.
func _trunks(buffer: PackedFloat32Array, girth: float, shapes: Dictionary, bodies: Dictionary, cell: Vector2i) -> void:
	if not bodies.has(cell):
		var body := StaticBody3D.new()
		body.name = "Trunks%d_%d" % [cell.x, cell.y]
		# A trunk is no cover worth surveying a wood of thousands for: see
		# Squad._survey_near_things().
		body.add_to_group(&"no_cover")
		add_child(body)
		bodies[cell] = body
	var body: StaticBody3D = bodies[cell]
	for i in range(0, buffer.size(), 12):
		var size := Vector3(buffer[i], buffer[i + 4], buffer[i + 8]).length()
		var key := snappedf(girth * size, 0.05)
		if not shapes.has(key):
			var cylinder := CylinderShape3D.new()
			cylinder.radius = maxf(key, 0.08)
			cylinder.height = TRUNK
			shapes[key] = cylinder
		var collider := CollisionShape3D.new()
		collider.shape = shapes[key]
		collider.position = Vector3(buffer[i + 3], buffer[i + 7] + TRUNK * 0.5, buffer[i + 11])
		collider.set_meta(&"surface", "wood")
		body.add_child(collider)
