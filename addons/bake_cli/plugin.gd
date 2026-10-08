@tool
extends EditorPlugin
## Godot has no command line switch for baking lightmaps and LightmapGI.bake()
## is not exposed to scripts, so this presses the editor's own bake button.
## Does nothing unless BAKE_LIGHTMAPS holds a scene path; see tools/bake_lightmaps.sh.


func _enter_tree() -> void:
	var scene_path := OS.get_environment("BAKE_LIGHTMAPS")
	if scene_path:
		_bake.call_deferred(scene_path)


func _bake(scene_path: String) -> void:
	var tree := get_tree()
	# Give the editor time to finish importing and loading its layout.
	while EditorInterface.get_resource_filesystem().is_scanning():
		await tree.process_frame
	await tree.create_timer(1.0).timeout
	EditorInterface.open_scene_from_path(scene_path)
	await tree.create_timer(1.0).timeout

	var root := EditorInterface.get_edited_scene_root()
	var lightmap: LightmapGI = root.find_children("*", "LightmapGI", true, false).front() if root else null
	if lightmap == null:
		_finish("no LightmapGI node in " + scene_path, 1)
		return
	# Without saved light data the editor would stop to ask for a file name.
	var data_path := scene_path.get_basename() + ".lmbake"
	if lightmap.light_data == null or lightmap.light_data.resource_path != data_path:
		ResourceSaver.save(LightmapGIData.new(), data_path)
		lightmap.light_data = load(data_path)

	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(lightmap)
	await tree.create_timer(0.5).timeout
	var buttons := EditorInterface.get_base_control().find_children("*", "Button", true, false).filter(
		func(button: Button) -> bool: return button.text == "Bake Lightmaps" and button.is_visible_in_tree()
	)
	if buttons.is_empty():
		_finish("could not find the editor's bake button", 1)
		return
	print("Baking lightmaps for ", scene_path, " ...")
	var started := int(Time.get_unix_time_from_system())
	# Blocks until the bake is done.
	buttons[0].pressed.emit()
	await tree.process_frame
	if FileAccess.get_modified_time(data_path) < started or lightmap.light_data.get_user_count() == 0:
		_finish("bake produced no data, check the editor output", 1)
		return
	EditorInterface.save_scene()
	_finish("saved %s" % data_path, 0)


func _finish(message: String, code: int) -> void:
	print("Lightmap bake: ", message)
	get_tree().quit(code)
