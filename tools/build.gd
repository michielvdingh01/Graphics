extends SceneTree
## Runs the builders named after "--", one after the other: a level from
## tools/levels/ or a set of models from tools/models/, as a path within the
## project. tools/build_level.sh and tools/build_model.sh start Godot with it.


func _init() -> void:
	for path in OS.get_cmdline_user_args():
		var script := load("res://" + path) as GDScript
		if script == null:
			push_error("No builder at " + path)
			continue
		script.new().run()
	quit()
