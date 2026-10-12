extends RefCounted
## The level loads, and with it what can break: the ground the other parts
## of the effects test stand on.


func run(test: SceneTree) -> void:
	var game: Node = await test.level()
	test.check(game.get_node_or_null("Level/Breakables") != null, "a level gets its breakables")
	test.check(not test.paused, "the game is being played, not paused behind a title screen")
	test.check(test.get_first_node_in_group("player") != null, "there is a player in it")
	test.check(test.get_nodes_in_group("enemy").all(func(enemy: Node) -> bool: return enemy.is_queued_for_deletion()), "nobody is there to fight")
	var fx: Node = test.autoload("Fx")
	var before: float = fx.time
	await test.wait(0.3)
	test.check(fx.time > before, "the clock of the effects runs")
