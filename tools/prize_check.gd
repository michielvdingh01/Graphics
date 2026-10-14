extends SceneTree
## Checks one prize the way the game shows it, without a window, and says
## what it came to: see tools/prize_check.sh. The prize is put together as in
## a match, by scripts/prize.gd, and nothing is written.

const PRIZE := "res://scenes/prize.tscn"
## What a prize should keep within: seen across a hall, carried without
## reaching far over a head, and drawn without cost.
const LEAST := 0.4
const HIGHEST := 1.5
const TRIANGLES := 6000


func _initialize() -> void:
	create_timer(60.0, true, false, true).timeout.connect(
		func() -> void:
			print("PRIZE CHECK FAILED: it did not come to an end")
			quit(1)
	)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var names := Array(OS.get_cmdline_user_args()).filter(func(arg: String) -> bool: return not arg.begins_with("--"))
	var prize_script: GDScript = load("res://scripts/prize.gd")
	prize_script.reread()
	var kinds: PackedStringArray = prize_script.kinds()
	if names.is_empty() or not kinds.has(names[0]):
		print("PRIZE CHECK FAILED: there is no prize called %s; there is %s." % [names[0] if names else "?", ", ".join(kinds)])
		quit(1)
		return
	var kind: String = names[0]
	var prize: Node3D = (load(PRIZE) as PackedScene).instantiate()
	prize.kind = kind
	root.add_child(prize)
	await process_frame
	var model := prize.get_node_or_null("Prize/Model") as Node3D
	if model == null:
		print("PRIZE CHECK FAILED: the game could not show the model of %s; see the warning above." % kind)
		quit(1)
		return
	var spec: Dictionary = prize._spec
	var box: AABB = prize_script._bounds(model)
	var triangles := 0
	var parts := 0
	var team := 0
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		parts += 1
		if String(mesh.name).begins_with("Team"):
			team += 1
		var arrays := mesh.mesh as ArrayMesh
		for surface in arrays.get_surface_count() if arrays else 0:
			var indices := arrays.surface_get_array_index_len(surface)
			@warning_ignore("integer_division")
			triangles += (indices if indices > 0 else arrays.surface_get_array_len(surface)) / 3
	print("%s (%s), %s" % [prize.title(), kind, spec.get("folder", "in the table")])
	print("  %.2f m across, %.2f from front to back and %.2f high; %d triangles in %d parts, %d of them in the colour of a team" % [box.size.x, box.size.z, box.size.y, triangles, parts, team])
	print("  on %s; at home %s, down %s, carried on the %s %s" % [str(spec.get("stand", "?")), _way(spec.home), _way(spec.down), str(spec.carried.get("on", "back")), _way(spec.carried, "hip heights")])
	var warned := false
	for warning: String in [
		"under %.1f m on every side: hard to see across a hall" % LEAST if maxf(box.size.x, maxf(box.size.y, box.size.z)) < LEAST else "",
		"over %.1f m high: carried, it reaches far over a head" % HIGHEST if box.size.y > HIGHEST else "",
		"more than %d triangles" % TRIANGLES if triangles > TRIANGLES else "",
		"nothing of it takes the colour of a team, only its stand" if team == 0 else "",
	]:
		if warning:
			print("  WARNING: " + warning)
			warned = true
	print("PRIZE CHECK PASSED" + (", with warnings" if warned else ""))
	quit(0)


## A way of sitting as words: where, and how it is turned if it is.
func _way(entry: Dictionary, unit := "m") -> String:
	var at: Array = entry.get("at", [0, 0, 0])
	var turn: Array = entry.get("turn", [0, 0, 0])
	var text := "at (%.2f, %.2f, %.2f) %s" % [at[0], at[1], at[2], unit]
	if turn != [0, 0, 0] and turn != [0.0, 0.0, 0.0]:
		text += " turned (%.0f, %.0f, %.0f)°" % [turn[0], turn[1], turn[2]]
	return text
