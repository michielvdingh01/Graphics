extends SceneTree
## The headless test of the effects, see tools/test_effects.sh. It loads a
## level for every script in tools/effects/ and hands itself to that script's
## `run(test)`, which looks at what it finds there and says so with check().
##
## A part is a script that extends RefCounted:
##
##     func run(test: SceneTree) -> void:
##         var game: Node = await test.level()
##         test.check(game.get_node("Level/Breakables") != null, "the level has breakables")
##
## What this script gives back has no type a part can know of, so a part says
## the type of what it keeps: `var game: Node =`, not `var game :=`.

const PARTS := "res://tools/effects/"
const FACTORY := "res://scenes/factory.tscn"
## Seconds the whole of it may take before it is given up as hung.
const LIMIT := 240.0

var passed := 0
var failed := 0


func _initialize() -> void:
	# An error in a part would otherwise leave the run hanging for ever.
	create_timer(LIMIT, true, false, true).timeout.connect(
		func() -> void:
			print("EFFECTS TEST FAILED (timed out)")
			quit(1)
	)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
	var parts: Array[String] = []
	for file in DirAccess.get_files_at(PARTS):
		if file.ends_with(".gd") and (only == "" or file.get_basename() == only):
			parts.append(file)
	parts.sort()
	for file in parts:
		print("-- ", file.get_basename())
		var script := load(PARTS + file) as GDScript
		if script == null or not script.can_instantiate():
			check(false, "%s can be read" % file)
			continue
		await (script.new() as RefCounted).run(self)
	print("%d of %d checks passed" % [passed, passed + failed])
	print("EFFECTS TEST FAILED" if failed or parts.is_empty() else "EFFECTS TEST PASSED")
	quit(1 if failed or parts.is_empty() else 0)


## Says whether something is as it should be.
func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("  ok      " if ok else "  FAILED  ", title)


## Loads a level afresh and returns its scene once its colliders are in the
## world: nobody is in it to fight, and nothing can kill the player.
func level(scene := FACTORY) -> Node:
	autoload("Save").clear()
	change_scene_to_file(scene)
	await scene_changed
	var game := current_scene
	if "zones" in game:
		for zone: RefCounted in game.zones:
			zone.area.set_deferred("monitoring", false)
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	for i in 4:
		await physics_frame
	var player := get_first_node_in_group("player")
	if player:
		player.health = 1e6
	return game


func autoload(title: String) -> Node:
	return root.get_node(title)


## Seconds of the game, which stand still while it is paused.
func wait(seconds: float) -> void:
	await create_timer(seconds, false, true).timeout


func frames(count: int) -> void:
	for i in count:
		await physics_frame
