extends SceneTree
## Writes scenes out as text, for tools/build_check.py to compare a model as
## it was with what it is now. After "--" come pairs: a scene to read, which
## may lie outside the project, and the .tscn to write.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(0, args.size() - 1, 2):
		var scene := ResourceLoader.load(args[i], "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		if scene == null:
			push_error("No scene at " + args[i])
			continue
		ResourceSaver.save(scene, args[i + 1])
	quit()
