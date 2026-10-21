extends SceneTree
## Checks an imported character against the contract the rig relies on and
## prints what it measured as one line of JSON:
##   godot --headless --path . --script tools/characters/check.gd -- <id>
## Exits with 1 when the character breaks the contract: at most 20 thousand
## triangles, metres, feet on the origin, facing +Z, one skeleton that is the
## unique node GeneralSkeleton with the bones of SkeletonProfileHumanoid in
## that profile's rest pose, no animations and nothing hung on a bone.

const TRIANGLES := 20000
## A character should stay around 5 MB, with textures of 1K; four times as
## much with textures of 2K.
const BYTES := 5_500_000

var _problems := PackedStringArray()


func _initialize() -> void:
	var failed := false
	for id in OS.get_cmdline_user_args():
		_problems.clear()
		var facts := _check(id)
		facts["id"] = id
		facts["problems"] = _problems
		print("check: ", JSON.stringify(facts))
		for problem in _problems:
			printerr("check: %s: %s" % [id, problem])
		failed = failed or not _problems.is_empty()
	quit(1 if failed else 0)


func _check(id: String) -> Dictionary:
	var path := "res://assets/characters/%s/%s.glb" % [id, id]
	var facts := {}
	if not ResourceLoader.exists(path):
		_problems.append("there is no %s, or it has not been imported" % path)
		return facts
	var scene := (load(path) as PackedScene).instantiate()
	var side := 1024
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var material := mesh.get_active_material(0) as BaseMaterial3D
		if material and material.albedo_texture:
			side = maxi(side, material.albedo_texture.get_width())
	var bytes := FileAccess.get_file_as_bytes(path).size()
	facts["bytes"] = bytes
	var most := BYTES * (side / 1024.0) ** 2
	if bytes > most:
		_problems.append("the file is %.1f MB; a character with textures of %d should stay around %.0f MB" % [bytes / 1e6, side, most / 1.1e6])

	var skeletons := scene.find_children("*", "Skeleton3D", true, false)
	if skeletons.size() != 1:
		_problems.append("it has %d skeletons instead of one" % skeletons.size())
		return facts
	var skeleton: Skeleton3D = skeletons[0]
	if skeleton.name != &"GeneralSkeleton" or not skeleton.unique_name_in_owner:
		_problems.append("its skeleton is %s, not the unique node GeneralSkeleton: the retarget did not run" % skeleton.name)
	for node in scene.find_children("*", "", true, false):
		if node is AnimationPlayer or node is AnimationTree:
			_problems.append("it carries animations (%s)" % node.name)
		elif node is BoneAttachment3D:
			_problems.append("something hangs on a bone (%s); a character carries no weapon" % node.name)

	# The bones of the profile, each where and how the profile has it at rest.
	var profile := SkeletonProfileHumanoid.new()
	var missing := PackedStringArray()
	var reference := {}
	var worst := 0.0
	var worst_bone := ""
	for index in profile.bone_size:
		var bone := profile.get_bone_name(index)
		var parent := profile.get_bone_parent(index)
		reference[bone] = (reference[parent] if reference.has(parent) else Basis()) * profile.get_reference_pose(index).basis
		var found := skeleton.find_bone(bone)
		if found < 0:
			missing.append(bone)
			if profile.is_required(index):
				_problems.append("it has no bone %s" % bone)
			continue
		var parent_found := skeleton.get_bone_parent(found)
		if parent != &"" and (parent_found < 0 or skeleton.get_bone_name(parent_found) != String(parent)) and skeleton.find_bone(parent) >= 0:
			_problems.append("%s hangs on %s instead of %s" % [bone, skeleton.get_bone_name(parent_found) if parent_found >= 0 else "nothing", parent])
		var off := rad_to_deg(skeleton.get_bone_global_rest(found).basis.orthonormalized().get_rotation_quaternion().angle_to(reference[bone].get_rotation_quaternion()))
		if off > worst:
			worst = off
			worst_bone = bone
	facts["bones"] = skeleton.get_bone_count()
	facts["missing_bones"] = missing
	facts["rest_off_degrees"] = snappedf(worst, 0.1)
	if worst > 1.0:
		_problems.append("the rest pose of %s is %.0f degrees off the profile's" % [worst_bone, worst])

	var triangles := 0
	var surfaces := 0
	var box := AABB()
	var first := true
	for instance: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		surfaces += instance.mesh.get_surface_count()
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		# The mesh is stored as it was skinned, which is not the rest pose, but
		# its feet and its crown are where they will be.
		var own := _to_scene(instance, scene) * instance.mesh.get_aabb()
		box = own if first else box.merge(own)
		first = false
	facts["triangles"] = triangles
	facts["surfaces"] = surfaces
	if triangles > TRIANGLES:
		_problems.append("it has %d triangles, more than %d" % [triangles, TRIANGLES])
	if triangles == 0:
		_problems.append("it has no mesh")
		return facts
	facts["height"] = snappedf(box.end.y, 0.001)
	if box.end.y < 0.9 or box.end.y > 2.6:
		_problems.append("it is %.2f m tall; is it in metres?" % box.end.y)
	if absf(box.position.y) > 0.03:
		_problems.append("its feet are %.2f m off the ground" % box.position.y)

	var at := func(bone: String) -> Vector3:
		var found := skeleton.find_bone(bone)
		return skeleton.get_bone_global_rest(found).origin if found >= 0 else Vector3.ZERO
	var hips: Vector3 = at.call("Hips")
	if Vector2(hips.x, hips.z).length() > 0.08:
		_problems.append("it stands %.2f m off the origin" % Vector2(hips.x, hips.z).length())
	if at.call("LeftUpperArm").x <= at.call("RightUpperArm").x:
		_problems.append("its left arm is on its right: it does not face +Z")
	if skeleton.find_bone("LeftToes") >= 0 and at.call("LeftToes").z <= at.call("LeftFoot").z:
		_problems.append("its toes point backwards: it does not face +Z")
	# For the tuning of whoever uses it: where the eyes are and where the head begins.
	if skeleton.find_bone("LeftEye") >= 0:
		facts["eye_height"] = snappedf(at.call("LeftEye").y, 0.01)
	facts["head_start"] = snappedf(at.call("Head").y, 0.01)
	scene.free()
	return facts


func _to_scene(node: Node3D, scene: Node) -> Transform3D:
	var transform := Transform3D()
	var at: Node = node
	while at != scene and at is Node3D:
		transform = (at as Node3D).transform * transform
		at = at.get_parent()
	return transform
