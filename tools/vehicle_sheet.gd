extends Node
## Pictures each vehicle in the dunes from a few sides, as tools/vehicle_sheet.py
## asks: the game runs with --direct=res://tools/vehicle_sheet.gd --shots=<dir>,
## this goes to the dunes, makes them quiet, and saves <dir>/<vehicle>_<view>.png
## for every vehicle of SUBJECTS and every view of VIEWS. The motorcycle has no
## place in the dunes: it is stood by the jeep for its picture. The game reads
## the settings of whoever plays on this machine, so the pictures look as the
## game does for him.

const SIZE := Vector2i(1600, 1000)
## Each vehicle: the one of its kind standing nearest to `near` in the dunes,
## how long it is, and how wide; a motorcycle is stood `beside` the jeep.
const SUBJECTS := [
	{"name": "jeep", "kind": "jeep", "near": Vector2(266.5, 114.0), "length": 3.4, "width": 1.6},
	{"name": "truck", "kind": "truck", "near": Vector2(198.0, 201.0), "length": 6.6, "width": 2.4},
	{"name": "tank", "kind": "tank", "near": Vector2(104.0, 41.0), "length": 6.6, "width": 3.0, "behind": true},
	{"name": "motorcycle", "kind": "motorcycle", "beside": Vector3(-4.5, 0.0, 1.0), "length": 2.3, "width": 1.9, "behind": true},
]
## Each view: where the eye is and what it looks at, in the frame of the
## vehicle (nose along -Z, X to its right, metres over the ground), as
## multiples of [length, width, 1]; and the field of view. "seat" looks out
## of the eyes of the driver instead, or for a vehicle that says `behind`,
## where the eye hangs behind it as it is driven.
const VIEWS := [
	{"name": "front", "eye": Vector3(-0.95, 1.65, -0.9), "at": Vector3(0.0, 0.85, 0.0), "fov": 40.0},
	{"name": "rear", "eye": Vector3(0.85, 2.3, 0.95), "at": Vector3(0.0, 0.9, 0.0), "fov": 40.0},
	{"name": "close", "eye": Vector3(-0.08, 1.15, -0.95), "at": Vector3(-0.2, 0.75, -0.25), "fov": 40.0, "close": true},
	{"name": "seat", "fov": 75.0},
]

var tree: SceneTree
var game: Node3D
var _shots := "user://vehicle_sheet"
var _eye: Camera3D
var _only := PackedStringArray()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	tree = get_tree()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.get_slice("=", 1)
		elif arg.begins_with("--only="):
			_only = arg.get_slice("=", 1).split(",")
	DirAccess.make_dir_recursive_absolute(_shots)
	Settings.music = 0.0
	Settings.show_fps = false
	Settings.apply()
	await tree.process_frame
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_window().content_scale_size = SIZE
	# Not Menu._play(), which would clear the save of whoever plays here.
	Menu._show(Menu.Screen.NONE)
	tree.change_scene_to_file("res://scenes/dunes.tscn")
	await tree.scene_changed
	game = tree.current_scene
	for i in 3:
		await tree.physics_frame
	_quiet()
	_eye = Camera3D.new()
	game.add_child(_eye)
	_eye.current = true
	var jeep: Node3D = null
	for subject: Dictionary in SUBJECTS:
		var vehicle: Node3D
		if subject.has("beside"):
			vehicle = _stand(subject.kind, jeep, subject.beside)
		else:
			vehicle = _nearest(subject.kind, subject.near)
		if subject.kind == "jeep":
			jeep = vehicle
		if not _only.is_empty() and not subject.name in _only:
			continue
		if vehicle == null:
			push_error("vehicle_sheet: no %s" % subject.name)
			continue
		for view: Dictionary in VIEWS:
			await _picture(vehicle, subject, view)
	tree.quit(0)


## No robots, nothing that starts a fight, no player in the way and no HUD.
func _quiet() -> void:
	for zone: RefCounted in game.zones:
		zone.area.set_deferred("monitoring", false)
		for robot: Variant in zone.robots:
			if is_instance_valid(robot):
				robot.queue_free()
		zone.robots.clear()
	for checkpoint: RefCounted in game.checkpoints:
		checkpoint.area.set_deferred("monitoring", false)
	var player: Node3D = game.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	player.global_position += Vector3(0, -40, 0)
	var hud := tree.get_first_node_in_group("hud")
	if hud:
		hud.visible = false


func _nearest(kind: String, near: Vector2) -> Node3D:
	var best: Node3D = null
	for node in tree.root.find_children("*", "RigidBody3D", true, false):
		if node.get("kind") != kind:
			continue
		var at := Vector2(node.global_position.x, node.global_position.z)
		if best == null or at.distance_to(near) < Vector2(best.global_position.x, best.global_position.z).distance_to(near):
			best = node
	return best


## The model of `kind` stood on the ground `offset` from `by`, in its frame,
## facing the same way.
func _stand(kind: String, by: Node3D, offset: Vector3) -> Node3D:
	var node: Node3D = (load("res://scenes/models/%s.scn" % kind) as PackedScene).instantiate()
	game.add_child(node)
	var at := by.global_transform * offset
	node.global_transform = Transform3D(by.global_basis, Vector3(at.x, _ground(at.x, at.z), at.z))
	return node


func _ground(x: float, z: float) -> float:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(x, 400.0, z), Vector3(x, -100.0, z), 1)
	var hit := game.get_world_3d().direct_space_state.intersect_ray(ray)
	return (hit.position as Vector3).y if hit else 0.0


func _picture(vehicle: Node3D, subject: Dictionary, view: Dictionary) -> void:
	var xf := vehicle.global_transform.orthonormalized()
	if view.name == "seat" and subject.get("behind", false):
		var behind := xf * Vector3(0.0, 1.3 + subject.length * 0.22, subject.length * 1.25)
		var ahead := xf * Vector3(0.0, 1.0, -subject.length * 0.4)
		_eye.global_transform = Transform3D(Basis.looking_at(ahead - behind), behind)
		_eye.fov = 55.0
	elif view.name == "seat":
		if not vehicle.has_method("eye_frame"):
			return
		var eye: Transform3D = vehicle.eye_frame(0)
		_eye.global_transform = Transform3D(Basis.looking_at(-eye.basis.z.slide(Vector3.UP).normalized() + Vector3(0, -0.12, 0)), eye.origin)
	else:
		var scale := Vector3(subject.length, 1.0, subject.length) if not view.get("close", false) else Vector3(subject.width, 1.0, subject.length)
		var eye := xf * (view.eye as Vector3 * scale)
		var at := xf * (view.at as Vector3 * scale)
		eye.y = maxf(eye.y, _ground(eye.x, eye.z) + 0.4)
		_eye.global_transform = Transform3D(Basis.looking_at(at - eye), eye)
	if not (view.name == "seat" and subject.get("behind", false)):
		_eye.fov = view.fov
	# Long enough for the upscaler and the exposure to settle where it looks.
	for i in 45:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s_%s.png" % [_shots, subject.name, view.name]
	get_viewport().get_texture().get_image().save_png(path)
	print("vehicle_sheet: ", path)
