extends SceneTree
## Makes of the hand that Blender built (tools/models/hands.py) what the
## weapons use. tools/build_hands.sh starts Godot with it and the path of the
## file Blender wrote.
##
## Two files come out. scenes/models/glove.res is the mesh: glove, plates and
## sleeve, each with its material. scenes/models/glove.scn is a right hand to
## put on: a Skeleton3D called Skeleton with that mesh on it as Mesh, lying
## palm down with the wrist at the origin, the fingers towards -Z and the back
## of the hand towards +Y. Its root says under "bones" how long and how thick
## each bone of a finger is, which tools/models/weapons.gd needs to close the
## hand around something.

const MESH := "res://scenes/models/glove.res"
const SCENE := "res://scenes/models/glove.scn"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Which file did Blender write?")
		quit(1)
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var err := document.append_from_file(args[0], state)
	if err != OK:
		push_error("Cannot read %s: %s" % [args[0], error_string(err)])
		quit(1)
		return
	var built := document.generate_scene(state)
	var bones: Skeleton3D = built.find_children("*", "Skeleton3D", true, false)[0]

	# One mesh out of the three, a surface each. They hang on the same bones
	# in the same order, so the skin of any of them serves all.
	var mesh := ArrayMesh.new()
	var skin: Skin
	var triangles := 0
	for instance: MeshInstance3D in built.find_children("*", "MeshInstance3D", true, false):
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var made_of: String = instance.mesh.surface_get_material(surface).resource_name
			mesh.surface_set_name(mesh.get_surface_count() - 1, made_of)
			mesh.surface_set_material(mesh.get_surface_count() - 1, load("res://materials/%s.tres" % made_of))
			triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		if skin == null:
			skin = instance.skin
		elif instance.skin.get_bind_count() != skin.get_bind_count():
			push_error("%s hangs on other bones than the rest" % instance.name)
	err = ResourceSaver.save(mesh, MESH, ResourceSaver.FLAG_COMPRESS)
	mesh.take_over_path(MESH)

	var glove := Node3D.new()
	glove.name = "Glove"
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton"
	glove.add_child(skeleton)
	skeleton.owner = glove
	# Whatever stood between the root and the bones in Blender's file is
	# worked into their rest, so that the hand lies as described above.
	var above := Transform3D()
	var node: Node3D = bones
	while node != built:
		above = node.transform * above
		node = node.get_parent()
	for bone in bones.get_bone_count():
		skeleton.add_bone(bones.get_bone_name(bone))
	for bone in bones.get_bone_count():
		var parent := bones.get_bone_parent(bone)
		skeleton.set_bone_parent(bone, parent)
		var rest := bones.get_bone_rest(bone)
		skeleton.set_bone_rest(bone, above * rest if parent < 0 else rest)
	skeleton.reset_bone_poses()
	var held := MeshInstance3D.new()
	held.name = "Mesh"
	held.mesh = mesh
	held.skin = skin
	skeleton.add_child(held)
	held.owner = glove
	held.skeleton = NodePath("..")

	var about: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0] + ".json"))
	glove.set_meta("bones", about.bones)
	glove.set_meta("forearm", about.forearm)
	var scene := PackedScene.new()
	scene.pack(glove)
	var err_scene := ResourceSaver.save(scene, SCENE, ResourceSaver.FLAG_COMPRESS)
	print("%s and %s: %d bones, %d triangles, %s" % [MESH, SCENE, skeleton.get_bone_count(), triangles, error_string(maxi(err, err_scene))])
	glove.free()
	built.free()
	quit()
