extends "res://tools/level_builder.gd"
## Shared generator for the models that are built in code because there is
## nothing scanned or generated to use yet: the weapons in the player's hands
## and the enemies. The models themselves live in tools/models/ and are built
## with tools/build_model.sh <name>.
##
## A model is a tree of parts. Each part is one mesh with a pivot of its own,
## so that whatever animates the model can move it: a bolt, a magazine, a leg.
## The geometry builders of the level builder work as they do in a level, in
## the coordinates of the model as a whole; the current part only decides
## which mesh their triangles end up in. A model has no colliders and no
## lightmap, and is saved as one file, scenes/models/<name>.scn.

const MODEL_DIR := "res://scenes/models/"

var _figure: Node3D
## Part name -> {node, frame}: its node and its pivot in model coordinates.
var _parts := {}
var _current := ""
## From model coordinates to those of the current part.
var _to_part := Transform3D()


func _build() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MODEL_DIR))
	_describe()
	_save()


## Starts a model; whatever is built from here on belongs to it. It opens with
## a part called "Body" at the origin, for everything that never moves.
func model(model_name: String) -> void:
	_save()
	_figure = Node3D.new()
	_figure.name = model_name.to_pascal_case()
	_parts = {}
	_tools = {}
	_m = Transform3D()
	part("Body")


## Starts a part, or goes back to one. `pivot` is where it turns or slides
## from, in model coordinates, and `parent` the part it moves along with.
func part(part_name: String, pivot := Transform3D(), parent := "") -> void:
	if not _parts.has(part_name):
		var node := MeshInstance3D.new()
		node.name = part_name
		var above: Node3D = _parts[parent].node if parent else _figure
		var above_frame: Transform3D = _parts[parent].frame if parent else Transform3D()
		node.transform = above_frame.affine_inverse() * pivot
		# Nothing here gets a lightmap, so the probes have to light it.
		node.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		above.add_child(node)
		node.owner = _figure
		_parts[part_name] = {"node": node, "frame": pivot}
	_current = part_name
	_to_part = (_parts[part_name].frame as Transform3D).affine_inverse()


## Named point on a part, in model coordinates: a muzzle, an ejection port,
## somewhere for a hand to hold on.
func marker(marker_name: String, at: Transform3D, parent := "") -> void:
	var node := Marker3D.new()
	node.name = marker_name
	var above: Node3D = _parts[parent].node if parent else _figure
	var above_frame: Transform3D = _parts[parent].frame if parent else Transform3D()
	node.transform = above_frame.affine_inverse() * at
	above.add_child(node)
	node.owner = _figure


func _tool(mat: String, _flags: int, _at: Vector3) -> SurfaceTool:
	return _tool_named(_current + "/" + mat)


func _tri(st: SurfaceTool, p: Array, n: Array, uv: Array, edge: Array = []) -> void:
	for i: int in [0, 2, 1]:
		st.set_color(NO_EDGE if edge.is_empty() else edge[i])
		st.set_normal(_to_part.basis * n[i])
		st.set_uv(uv[i])
		st.add_vertex(_to_part * p[i])


func _collide(_shape: Shape3D, _xf: Transform3D) -> void:
	pass


## Writes out the model that was being built, if any.
func _save() -> void:
	if _figure == null:
		return
	var triangles := 0
	for part_name: String in _parts:
		var keys := _tools.keys().filter(func(key: String) -> bool: return key.begins_with(part_name + "/"))
		if keys.is_empty():
			continue
		keys.sort()
		var mesh := ArrayMesh.new()
		for key: String in keys:
			var st: SurfaceTool = _tools[key]
			st.index()
			st.generate_tangents()
			st.set_material(_material(key.get_slice("/", 1)))
			st.commit(mesh)
			triangles += mesh.surface_get_array_index_len(mesh.get_surface_count() - 1) / 3
		(_parts[part_name].node as MeshInstance3D).mesh = mesh
	var scene := PackedScene.new()
	scene.pack(_figure)
	var path := MODEL_DIR + _figure.name.to_snake_case() + ".scn"
	var err := ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS)
	print("%s: %d parts, %d triangles, %s" % [path, _parts.size(), triangles, error_string(err)])
	_figure.free()
	_figure = null
