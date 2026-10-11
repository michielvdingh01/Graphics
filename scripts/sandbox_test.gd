extends Node
## Headless test of the sandbox. Run with: tools/test_sandbox.sh
##
## It starts the game in the first experiment the way --sandbox= does, plays
## rounds of it without firing a shot (the enemies are hurt directly) and
## checks what the sandbox promises: one zone with the variant's enemies at
## its posts, a round that starts again at once and with another variant, a
## line in the log for each, the switches, and that what the game had saved
## is as it was afterwards.

## True for a run of this test.
var active := false

var _failures := 0


func _ready() -> void:
	active = "--sandboxtest" in OS.get_cmdline_user_args()
	if active:
		# Menus, saved settings and saved progress stay out of the way, as
		# they do for the self-test.
		SelfTest.active = true
		_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	# A script error would otherwise leave the run hanging forever.
	tree.create_timer(120.0, true, true).timeout.connect(
		func() -> void:
			print("SANDBOX TEST FAILED (timed out)")
			tree.quit(1)
	)
	await _wait(0.5)
	var first: String = Sandbox.experiments.keys()[0]
	var spec: Dictionary = Sandbox.experiments[first]
	var theme: String = Settings.enemy_theme
	_check("--sandbox= opens an experiment", Sandbox.active and Sandbox.id == first and Sandbox.rounds == 1)
	var game := tree.current_scene
	var player: CharacterBody3D = game.player
	player.force_control = true
	var zone: RefCounted = _arena(game)
	_check("in its level, with one zone to fight over", game.scene_file_path == spec.level and zone.id == spec.zone
		and game.zones.all(func(other: RefCounted) -> bool: return other == zone or other.cleared))
	_check("and no way on or out", game.exit == null and game.checkpoints.is_empty())
	var squad: Array = zone.robots.duplicate()
	var posts: Array = zone.area.get_children().filter(func(node: Node) -> bool: return node.is_in_group("enemy_spawn"))
	_check("its enemies stand at the posts of the zone, switched off", squad.size() == posts.size() and not zone.started
		and squad.all(func(one: Node) -> bool: return not one.can_process() and posts.any(func(post: Node3D) -> bool: return post.global_position.distance_to(one.global_position) < 0.5)))
	_check("cast from the variant, not from the setting", squad.all(func(one: Node) -> bool: return one.panics and one.panic_radius == 8.0)
		and Settings.enemy_theme == theme)
	var way_in: Vector3 = player.global_position
	_check("the player starts outside it", not game._holds(zone.area))

	# A round, won. Whoever is shot starts the fight, as in the game.
	squad[0].take_damage(1.0, squad[0].global_position + Vector3.UP, Vector3.LEFT)
	await _wait(0.3)
	_check("a shot starts the fight", zone.started and squad.all(func(one: Node) -> bool: return one.can_process()))
	player.global_position += Vector3(0, 0, 1.5)
	for one: Node in squad:
		one.take_damage(1e6, one.global_position + Vector3.UP, Vector3.LEFT)
	await _wait(0.3)
	_check("with all of them down the round is over", zone.cleared and Sandbox.result == "cleared" and game.kills == squad.size())
	Sandbox.judge(true)
	_check("nothing is written before the next round", _lines().is_empty())

	# The next variant, at once and in the same level.
	Sandbox.step(1)
	await _wait(0.2)
	var fresh: Array = zone.robots.duplicate()
	_check("another variant starts a round at once", Sandbox.variant == 1 and Sandbox.rounds == 2 and Sandbox.result == "" and tree.current_scene == game
		and not zone.started and not zone.cleared and game.kills == 0)
	_check("with new enemies, cast from that variant", fresh.size() == squad.size() and squad.all(func(one: Variant) -> bool: return not is_instance_valid(one))
		and fresh.all(func(one: Node) -> bool: return not one.dead and one.panic_radius == spec.variants[1].tuning.panic_radius))
	_check("and the player back at the way in", player.global_position.distance_to(way_in) < 0.2 and player.health == player.MAX_HEALTH)
	var lines := _lines()
	_check("the round before is in the log, with what was said of it", lines.size() == 1 and lines[0].experiment == first and lines[0].variant == "A"
		and lines[0].result == "cleared" and lines[0].verdict == "good" and lines[0].kills == squad.size())

	# The switches.
	Sandbox.unhurt = true
	_check("nothing hurts the player", not player.take_damage(60.0) and player.health == player.MAX_HEALTH)
	Sandbox.unhurt = false
	Sandbox.slow = true
	_check("slow motion", Engine.time_scale == Sandbox.SLOW)
	Sandbox.slow = false
	fresh[0].take_damage(1.0, fresh[0].global_position + Vector3.UP, Vector3.LEFT)
	await _wait(0.3)
	Sandbox.still = true
	await _wait(0.1)
	var stood: Array = fresh.map(func(one: Node3D) -> Vector3: return one.global_position)
	await _wait(1.0)
	var moved := 0.0
	for i in fresh.size():
		moved = maxf(moved, fresh[i].global_position.distance_to(stood[i]))
	var health: float = fresh[1].health
	fresh[1].take_damage(5.0, fresh[1].global_position + Vector3.UP, Vector3.LEFT)
	_check("enemies hold still and can be shot at", moved < 0.01 and fresh[1].health < health)
	Sandbox.still = false
	await _wait(1.5)
	moved = 0.0
	for i in fresh.size():
		moved = maxf(moved, fresh[i].global_position.distance_to(stood[i]))
	_check("and go on when they are let go", moved > 0.5)
	var weapons: Node3D = player.weapons
	weapons._reserves[0] = 0
	Sandbox.endless = true
	await _wait(Sandbox.TOP_UP + 0.2)
	_check("the ammunition never runs out", weapons._reserves[0] > 0)
	Sandbox.endless = false
	player.look_at(Vector3(fresh[0].global_position.x, player.global_position.y, fresh[0].global_position.z))
	player.head.rotation.x = -0.3
	await _wait(0.1)
	_check("an enemy more where the player looks", Sandbox.put("heavy") and zone.robots.size() == fresh.size() + 1 and zone.robots[-1].role == "heavy"
		and zone.alive == fresh.size() + 1)

	# A round broken off, and one lost.
	Sandbox.restart()
	await _wait(0.2)
	lines = _lines()
	_check("a round that is started again is in the log as broken off", lines.size() == 2 and lines[1].variant == "B" and lines[1].result == "broken off"
		and Sandbox.rounds == 3 and zone.robots.size() == squad.size())
	player.take_damage(1e6)
	_check("a death ends the round", player.dead and Sandbox.result == "died")
	await _wait(game.RESTART_DELAY + 0.5)
	_check("and does not start the level again", tree.current_scene == game and player.dead)
	Sandbox.restart()
	_check("the next round has the player on their feet", not player.dead and player.health == player.MAX_HEALTH and _lines()[-1].result == "died")

	# The level again, for what a round does not bring back.
	Sandbox.reload()
	await tree.scene_changed
	await _wait(0.3)
	var again := tree.current_scene
	_check("the level loads again into a round", again != game and Sandbox.rounds == 5 and _arena(again).robots.size() == squad.size())

	# What the menu offers.
	Menu._show(Menu.Screen.SANDBOX)
	var offered := Menu._column.get_children().filter(func(control: Node) -> bool: return control is Button).map(func(button: Button) -> String: return button.text)
	_check("the menu lists every experiment", Sandbox.experiments.keys().all(func(key: String) -> bool: return offered.has(Sandbox.title(key))))
	Menu._show(Menu.Screen.PAUSE)
	offered = Menu._column.find_children("*", "Button", true, false).filter(func(button: Node) -> bool: return not button.is_queued_for_deletion()).map(func(button: Button) -> String: return button.text)
	_check("and its pause menu has the round, the switches, an enemy more and the way out", offered.has("Start the round again") and offered.has("Slow motion")
		and offered.has("Heavy") and offered.has("Leave the sandbox") and not offered.has("Restart from checkpoint")
		and offered.any(func(text: String) -> bool: return text.begins_with("Variant")))
	Menu._show(Menu.Screen.NONE)

	# What the game had saved is left alone.
	Sandbox.close()
	_check("closing it switches everything off", not Sandbox.active and Engine.time_scale == 1.0 and not again.player.invulnerable)
	Save.store(spec.level, "hall", "Hall", 7)
	var other: String = Sandbox.experiments.keys()[-1]
	Sandbox.open(other)
	await tree.scene_changed
	await _wait(0.3)
	var yard := tree.current_scene
	_check("another experiment goes to its own level", yard.scene_file_path == Sandbox.experiments[other].level and _arena(yard) != null
		and _arena(yard).robots.size() == Sandbox.experiments[other].squad.size())
	_check("what was saved is set aside meanwhile", Save.checkpoint.is_empty() and yard.kills == 0)
	Save.store(Sandbox.experiments[other].level, "", "", 3)
	Save.tally("deaths")
	Save.flush()
	Sandbox.close()
	Save.reload()
	_check("and is as it was afterwards, on disk as well", Save.checkpoint.get("at") == "hall" and Save.checkpoint.get("kills") == 7 and Save.stats.deaths == 0.0)

	print("SANDBOX TEST %s" % ("PASSED" if _failures == 0 else "FAILED (%d)" % _failures))
	tree.quit(1 if _failures else 0)


## The zone of a level that is still to be fought over.
func _arena(game: Node) -> RefCounted:
	for zone: RefCounted in game.zones:
		if not zone.cleared:
			return zone
	return null


func _lines() -> Array:
	var lines := []
	if FileAccess.file_exists(Sandbox.TEST_LOG):
		for line in FileAccess.get_file_as_string(Sandbox.TEST_LOG).split("\n", false):
			lines.append(JSON.parse_string(line))
	return lines


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
