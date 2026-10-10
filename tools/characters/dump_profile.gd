extends SceneTree
## Writes what the Blender half of tools/import_character.sh needs to know about
## Godot's humanoid profile: the bones, their parents and where they sit in the
## reference pose. Also writes the bone map every character is imported with.
## Run once per Godot version:
##   godot --headless --path . --script tools/characters/dump_profile.gd


func _init() -> void:
	var profile := SkeletonProfileHumanoid.new()
	var bones := []
	var globals := {}
	for i in profile.bone_size:
		var bone := profile.get_bone_name(i)
		var parent := profile.get_bone_parent(i)
		var pose := profile.get_reference_pose(i)
		var global: Transform3D = (globals[parent] if globals.has(parent) else Transform3D()) * pose
		globals[bone] = global
		bones.append({
			"name": String(bone),
			"parent": String(parent),
			"tail": String(profile.get_bone_tail(i)),
			"group": String(profile.get_group(i)),
			"required": profile.is_required(i),
			"position": [snappedf(global.origin.x, 0.00001), snappedf(global.origin.y, 0.00001), snappedf(global.origin.z, 0.00001)],
		})
	var file := FileAccess.open("res://tools/characters/humanoid_profile.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"godot": Engine.get_version_info().string, "bones": bones}, "\t") + "\n")
	file.close()

	# The Blender half already names the bones after the profile, so the map is
	# every bone to itself; importing with it is what makes Godot rename the
	# skeleton and turn its rest pose into the profile's.
	var map := BoneMap.new()
	map.profile = profile
	for i in profile.bone_size:
		map.set_skeleton_bone_name(profile.get_bone_name(i), profile.get_bone_name(i))
	ResourceSaver.save(map, "res://assets/characters/humanoid_bone_map.tres")
	quit()
