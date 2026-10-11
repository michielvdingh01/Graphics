extends SceneTree
## Runs the builders named after "--", one after the other: a level from
## tools/levels/ or a set of models from tools/models/, as a path within the
## project. tools/build_level.sh and tools/build_model.sh start Godot with it.

## A builder that runs into an error stops where it is and never says so.
## After this many seconds without an end, Godot is not left running.
const PATIENCE := 240.0

var _waited := 0.0


func _initialize() -> void:
	# The root is in the tree from the first frame on, and a level needs it there.
	await process_frame
	for path in OS.get_cmdline_user_args():
		var script := load("res://" + path) as GDScript
		if script == null or not script.can_instantiate():
			push_error("No builder that can be run at " + path)
			continue
		await script.new().make()
	quit()


func _process(delta: float) -> bool:
	_waited += delta
	if _waited > PATIENCE:
		push_error("The builder did not come to an end: look for an error above")
		quit(1)
	return false
