@tool
extends EditorPlugin
## Godot has no command line switch for baking lightmaps and LightmapGI.bake()
## is not exposed to scripts, so this presses the editor's own bake button.
## Does nothing unless BAKE_LIGHTMAPS holds a scene path; see tools/bake_lightmaps.sh.
##
## A level that the builder has cut into zones has a LightmapGI in every zone,
## and each is baked by itself, with nothing but its own zone around it. With
## BAKE_ZONES set to their names, separated by commas, only those are baked.


func _enter_tree() -> void:
	var scene_path := OS.get_environment("BAKE_LIGHTMAPS")
	if scene_path:
		_out_of_sight()
		_bake.call_deferred(scene_path)


func _bake(scene_path: String) -> void:
	var tree := get_tree()
	# Give the editor time to finish importing and loading its layout.
	while EditorInterface.get_resource_filesystem().is_scanning():
		await tree.process_frame
	await tree.create_timer(1.0).timeout
	_out_of_sight()
	EditorInterface.open_scene_from_path(scene_path)
	# The bake button sits in the toolbar of the 3D view, which is not always
	# the view the editor comes up in.
	EditorInterface.set_main_screen_editor("3D")
	await tree.create_timer(1.0).timeout

	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		_finish("could not open " + scene_path, 1)
		return
	var zones := root.find_children("*", "Node3D", true, false).filter(
		func(node: Node) -> bool: return node.is_in_group("level_zone") and node.has_node("LightmapGI")
	)
	if not zones.is_empty():
		await _bake_zones(root, zones)
		return

	var lightmap: LightmapGI = root.find_children("*", "LightmapGI", true, false).front()
	if lightmap == null:
		_finish("no LightmapGI node in " + scene_path, 1)
		return
	# Without saved light data the editor would stop to ask for a file name.
	var data_path := scene_path.get_basename() + ".lmbake"
	if lightmap.light_data == null or lightmap.light_data.resource_path != data_path:
		ResourceSaver.save(LightmapGIData.new(), data_path)
		lightmap.light_data = load(data_path)
	if not await _press_bake(lightmap):
		return
	EditorInterface.save_scene()
	_finish("saved %s" % data_path, 0)


## Bakes the zones of a level one by one. The scene itself is not saved:
## every zone already points at the file its bake goes into.
func _bake_zones(root: Node, zones: Array) -> void:
	var only := OS.get_environment("BAKE_ZONES").split(",", false)
	var baked := PackedStringArray()
	for zone: Node3D in zones:
		var zone_name: String = zone.get_meta(&"zone")
		if not only.is_empty() and zone_name not in only:
			continue
		var lightmap: LightmapGI = zone.get_node("LightmapGI")
		# A bake only looks at what stands under the parent of its LightmapGI,
		# which is the zone. The sun stands outside it, so it gets a stand-in.
		var extras: Array[Node] = []
		for sun: DirectionalLight3D in root.find_children("*", "DirectionalLight3D", true, false):
			var copy: DirectionalLight3D = sun.duplicate()
			zone.add_child(copy)
			# A bake passes over whatever has no owner, taking it for a helper.
			copy.owner = root
			copy.global_transform = sun.global_transform
			extras.append(copy)
		# And its doorways are shut, see bake_blocker() in the level builder.
		var blockers := zone.get_children().filter(func(node: Node) -> bool: return node.is_in_group("bake_blocker"))
		for blocker: Node3D in blockers:
			blocker.visible = true
		print("Zone ", zone_name, ":")
		var ok := await _press_bake(lightmap)
		for blocker: Node3D in blockers:
			blocker.visible = false
		for extra in extras:
			extra.free()
		if not ok:
			return
		baked.append(zone_name)
	if baked.is_empty():
		_finish("no zone called %s" % ", ".join(only), 1)
		return
	_finish("baked %s" % ", ".join(baked), 0)


## Selects a LightmapGI and presses the button that bakes it; false, with the
## editor on its way out, if that did not produce anything.
func _press_bake(lightmap: LightmapGI) -> bool:
	var tree := get_tree()
	var data_path := lightmap.light_data.resource_path
	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(lightmap)
	await tree.create_timer(0.5).timeout
	var buttons := EditorInterface.get_base_control().find_children("*", "Button", true, false).filter(
		func(button: Button) -> bool: return button.text == "Bake Lightmaps" and button.is_visible_in_tree()
	)
	if buttons.is_empty():
		var hidden := EditorInterface.get_base_control().find_children("*", "Button", true, false).filter(
			func(button: Button) -> bool: return button.text.contains("Bake")
		)
		print("Buttons that mention baking: ", hidden.map(func(button: Button) -> String: return "%s (visible: %s)" % [button.text, button.is_visible_in_tree()]))
		print("Selected: ", selection.get_selected_nodes())
		_finish("could not find the editor's bake button", 1)
		return false
	print("Baking lightmaps into ", data_path, " ...")
	var started := int(Time.get_unix_time_from_system())
	# Blocks until the bake is done.
	buttons[0].pressed.emit()
	await tree.process_frame
	if FileAccess.get_modified_time(data_path) < started or lightmap.light_data == null or lightmap.light_data.get_user_count() == 0:
		_finish("bake produced no data, check the editor output", 1)
		return false
	return true


func _finish(message: String, code: int) -> void:
	print("Lightmap bake: ", message)
	get_tree().quit(code)


## On Windows the editor of a bake has a window (see tools/godot.sh): off the
## screen with it, where it goes on drawing. Once when the plugin is loaded and
## once more when the editor is up, which puts its window back in its place.
## The editor remembers that place: tools/bake_lightmaps.py puts back what it
## remembered before.
func _out_of_sight() -> void:
	if not OS.get_environment("GODOT_OUT_OF_SIGHT"):
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_position(Vector2i(-20000, -20000))
