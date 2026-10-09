extends SceneTree
## Renders the contact sheet of a character: front, side and back as it was
## imported, and two poses that show whether the skin follows the skeleton, one
## with the arms down and a knee bent, one with an arm held forward.
##   tools/godot.sh --script res://tools/characters/sheet.gd -- <id> [more ids]
## The sheets land in assets/characters/sheets/<id>.jpg. It needs the GPU, so
## it goes through tools/godot.sh; the poses are set on GeneralSkeleton by the
## profile's bone names, so a sheet that looks right also says the retarget worked.

const SIZE := Vector2i(3280, 1000)
## Metres of height in view; the camera has no perspective, so that the front
## view is a front view wherever on the sheet it stands.
const VIEW_HEIGHT := 2.2
const SETTLE_FRAMES := 12

## Turns about the character's own axes (x to its left, y up, z ahead), in
## degrees, applied from the top of the list down.
const ARMS_DOWN := [
	["LeftUpperArm", Vector3.BACK, -78.0], ["RightUpperArm", Vector3.BACK, 78.0],
	["LeftLowerArm", Vector3.UP, -25.0], ["RightLowerArm", Vector3.UP, 25.0],
	["LeftUpperLeg", Vector3.RIGHT, -65.0], ["LeftLowerLeg", Vector3.RIGHT, 95.0],
	["Spine", Vector3.RIGHT, 8.0],
]
const ARM_FORWARD := [
	["LeftUpperArm", Vector3.BACK, -78.0],
	["RightUpperArm", Vector3.UP, 84.0], ["RightUpperArm", Vector3.RIGHT, 12.0], ["RightLowerArm", Vector3.UP, 25.0],
	["RightUpperLeg", Vector3.RIGHT, -40.0], ["RightLowerLeg", Vector3.RIGHT, 70.0],
	["Head", Vector3.UP, 35.0], ["Chest", Vector3.UP, -18.0],
]
## Label, turn of the whole figure in degrees, pose, metres from the left figure.
const VIEWS := [
	["front", 0.0, [], 0.0], ["side", -90.0, [], 1.45], ["back", 180.0, [], 2.9],
	["arms down, knee bent", -35.0, ARMS_DOWN, 4.25], ["arm forward", 55.0, ARM_FORWARD, 5.4],
]
const CENTRE := 2.6

var _ids: PackedStringArray
var _viewport: SubViewport
var _stage: Node3D
var _frames := 0
var _failed := false


func _initialize() -> void:
	_ids = OS.get_cmdline_user_args()
	if _ids.is_empty():
		printerr("sheet: pass the id of a character in assets/characters/")
		quit(1)
		return
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_studio()


func _process(_delta: float) -> bool:
	if _ids.is_empty():
		return true
	# A skeleton only takes a pose once it is in the tree, and the tree only
	# starts after _initialize.
	if _stage == null:
		_show(_ids[0])
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return false
	var id := _ids[0]
	var path := "res://assets/characters/sheets/%s.jpg" % id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	_viewport.get_texture().get_image().save_jpg(ProjectSettings.globalize_path(path), 0.9)
	print("sheet: ", path)
	_ids.remove_at(0)
	_stage.free()
	_stage = null
	if _ids.is_empty() and _failed:
		quit(1)
	return _ids.is_empty()


func _studio() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.2, 0.205, 0.21)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.66, 0.72)
	environment.ambient_light_energy = 1.0
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.ssao_enabled = true
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, 150.0, 0.0)
	key.light_energy = 3.2
	key.light_color = Color(1.0, 0.96, 0.9)
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 30.0
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25.0, -40.0, 0.0)
	rim.light_energy = 1.4
	rim.light_color = Color(0.75, 0.85, 1.0)
	_viewport.add_child(rim)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(40.0, 40.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.3, 0.3, 0.31)
	floor_material.roughness = 0.9
	floor_mesh.material = floor_material
	var ground := MeshInstance3D.new()
	ground.mesh = floor_mesh
	_viewport.add_child(ground)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = VIEW_HEIGHT
	camera.position = Vector3(0.0, 0.97, 12.0)
	_viewport.add_child(camera)
	camera.make_current()
	for view: Array in VIEWS:
		var label := Label.new()
		label.text = view[0]
		label.add_theme_font_size_override("font_size", 30)
		label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(500.0, 40.0)
		label.position = Vector2(SIZE.x * 0.5 + (view[3] - CENTRE) * SIZE.y / VIEW_HEIGHT - 250.0, 14.0)
		_viewport.add_child(label)


func _show(id: String) -> void:
	_frames = 0
	_stage = Node3D.new()
	_viewport.add_child(_stage)
	var scene := load("res://assets/characters/%s/%s.glb" % [id, id]) as PackedScene
	if scene == null:
		printerr("sheet: no character at assets/characters/%s/%s.glb" % [id, id])
		_failed = true
		return
	for view: Array in VIEWS:
		var figure: Node3D = scene.instantiate()
		_stage.add_child(figure)
		figure.position.x = view[3] - CENTRE
		figure.rotation_degrees.y = view[1]
		var skeleton := figure.get_node_or_null("%GeneralSkeleton") as Skeleton3D
		if skeleton == null:
			printerr("sheet: %s has no GeneralSkeleton" % id)
			_failed = true
			continue
		for turn: Array in view[2]:
			var bone := skeleton.find_bone(turn[0])
			if bone < 0:
				printerr("sheet: %s has no bone %s" % [id, turn[0]])
				_failed = true
				continue
			var pose := skeleton.get_bone_global_pose(bone)
			pose.basis = Basis(turn[1], deg_to_rad(turn[2])) * pose.basis
			skeleton.set_bone_global_pose(bone, pose)
	var title := Label.new()
	title.name = "Title"
	title.text = id
	title.add_theme_font_size_override("font_size", 36)
	title.position = Vector2(28.0, SIZE.y - 64.0)
	_stage.add_child(title)
