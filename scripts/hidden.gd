extends Node3D
## Leaves out what the land of a level hides from the camera: whoever stands
## guard behind a dune, a tent, a lorry, the grass of the next valley.
##
## A level on land has no zones to switch off (see scripts/zones.gd), and
## from its first wood every post of the whole of it was drawn, three dunes
## away. Here the land itself and the walls that stand on it are handed to
## the renderer as occluders, once, when the level loads; the renderer then
## leaves out, model by model, what lies wholly behind them.
##
## The occluder of the land is the land seen coarsely and from below: a
## point every STEP metres, as low as the lowest ground anywhere around it
## and UNDER lower still. It never rises above the real ground, so it hides
## nothing that could be seen; a crest it flattens hides a little less than
## the real one would. A tree stands taller than a dune and is drawn anyway.
##
## Stands in the scene of a level, after its "Level".

## How far apart the points of the land's occluder are, in points of the
## land, which lie a metre apart.
const STEP := 2
## How far under the lowest ground around it a point of the occluder lies.
const UNDER := 0.3
## Frames at the start in which everything is drawn, for the same reason as
## in scripts/zones.gd: what is drawn for the first time takes a moment.
const WARM_FRAMES := 4
const ZONES := preload("res://scripts/zones.gd")

## Switch off to draw whatever is in view, hidden or not (--undo=occlusion).
var occlusion := true:
	set(value):
		occlusion = value
		_occlude()

var _warm := WARM_FRAMES
var _occluder: OccluderInstance3D


func _ready() -> void:
	var level := get_parent().get_node_or_null("Level") as Node3D
	if level == null:
		return
	var settings := get_node_or_null("/root/Settings")
	if settings:
		occlusion = not settings.undone("occlusion")
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var ground := level.get_node_or_null("Ground/CollisionShape3D") as CollisionShape3D
	if ground and ground.shape is HeightMapShape3D:
		_land_from_below(ground.global_transform, ground.shape as HeightMapShape3D, vertices, indices)
	var body := level.get_node_or_null("Collision") as Node3D
	if body:
		ZONES.wall_boxes(body, vertices, indices)
	if indices.is_empty():
		return
	var hides := ArrayOccluder3D.new()
	hides.set_arrays(vertices, indices)
	_occluder = OccluderInstance3D.new()
	_occluder.name = "Land"
	_occluder.occluder = hides
	add_child(_occluder)
	# Only what is drawn itself is left out: a lamp, a reflection probe and a
	# decal are known to the renderer by a box, and that box being hidden
	# says nothing of what they light or colour.
	for node: VisualInstance3D in level.find_children("*", "VisualInstance3D", true, false):
		if not node is GeometryInstance3D:
			RenderingServer.instance_geometry_set_flag(node.get_instance(), RenderingServer.INSTANCE_FLAG_IGNORE_OCCLUSION_CULLING, true)


func _exit_tree() -> void:
	# The window outlives the level.
	get_viewport().use_occlusion_culling = false


func _process(_delta: float) -> void:
	_warm -= 1
	if _warm <= 0:
		_occlude()
		set_process(false)


func _occlude() -> void:
	if is_inside_tree():
		get_viewport().use_occlusion_culling = occlusion and _occluder != null and _warm <= 0


## Adds the land of `field`, which lies at `place`, to the occluder: its
## corners to `vertices` and its triangles to `indices`.
func _land_from_below(place: Transform3D, field: HeightMapShape3D, vertices: PackedVector3Array, indices: PackedInt32Array) -> void:
	var across := field.map_width
	var down := field.map_depth
	var heights := field.map_data
	# The lowest ground within STEP of every point, along its row and then
	# along its column: a patch between four points of the occluder then lies
	# under all of the ground over it.
	var along := PackedFloat32Array()
	along.resize(across * down)
	for row in down:
		for column in across:
			var low := INF
			for i in range(maxi(column - STEP, 0), mini(column + STEP, across - 1) + 1):
				low = minf(low, heights[row * across + i])
			along[row * across + column] = low
	var columns := PackedInt32Array(range(0, across - 1, STEP))
	columns.append(across - 1)
	var rows := PackedInt32Array(range(0, down - 1, STEP))
	rows.append(down - 1)
	var first := vertices.size()
	for row in rows:
		for column in columns:
			var low := INF
			for i in range(maxi(row - STEP, 0), mini(row + STEP, down - 1) + 1):
				low = minf(low, along[i * across + column])
			vertices.append(place * Vector3(column - (across - 1) * 0.5, low - UNDER, row - (down - 1) * 0.5))
	var wide := columns.size()
	for row in rows.size() - 1:
		for column in wide - 1:
			var nw := first + row * wide + column
			indices.append_array([nw, nw + wide + 1, nw + wide, nw, nw + 1, nw + wide + 1])
