extends Node
## Headless test of a match. Run with: tools/test_match.sh
##
## It has bots play a whole match of team deathmatch among themselves, faster
## than the clock, and checks what a match promises: the level is an arena
## and no more, the sides start at their own ends, shots land on the other
## side and not on one's own, every death is counted once, whoever dies comes
## back, and it ends when a side has the points. Then it plays with the
## player in it: a kill counts for the player, the player's own side cannot
## be hurt, and a death is not the end of the level. It prints how often a
## bot got stuck and how often nobody could come back anywhere safe.

## True for a run of this test.
var active := false

var _failures := 0


func _ready() -> void:
	active = "--matchtest" in OS.get_cmdline_user_args()
	if active:
		# Menus, saved settings and saved progress stay out of the way, as
		# they do for the self-test.
		SelfTest.active = true
		_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	# A script error would otherwise leave the run hanging forever.
	tree.create_timer(400.0, true, false, true).timeout.connect(
		func() -> void:
			print("MATCH TEST FAILED (timed out)")
			tree.quit(1)
	)
	await _wait(0.5)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--soak="):
			await _soak(arg.get_slice("=", 1).to_float())
			tree.quit(0)
			return
	var saved: Dictionary = Save.checkpoint.duplicate()
	var plain: Dictionary = Settings.rules()

	# Bots among themselves.
	_check("a match opens", Match.open({"mode": "tdm", "level": "factory", "size": 3, "only_bots": true}) and Match.active)
	_check("and not one of a kind there is not", not Match.MODES.has("nonsense") and Match.kinds.has("tdm") and Match.kinds.has("ffa"))
	await _until(func() -> bool: return Match.state == Match.State.PLAYING, 20.0)
	var game := tree.current_scene
	_check("in its level, once the floor is known", Match.state == Match.State.PLAYING and game.scene_file_path == "res://scenes/factory.tscn" and Match.arena.spots.size() > 50)
	print("  %d spots to stand on, the ends %.0f m apart as the crow flies" % [Match.arena.spots.size(), Match.arena.spots[Match.arena.ends[0]].distance_to(Match.arena.spots[Match.arena.ends[1]])])
	_check("the route is off: no robots, no checkpoints, no way out", game.exit == null and game.checkpoints.is_empty()
		and game.zones.all(func(zone: RefCounted) -> bool: return zone.cleared and zone.robots.is_empty())
		and tree.get_nodes_in_group("enemy").is_empty())
	_check("the rules are those of a match", Settings.rules().regen_to == 100.0 and Settings.rules().drops == 0.0)
	var all: Array = Match.entrants.values()
	var sides := [all.filter(func(who: RefCounted) -> bool: return who.team == 0), all.filter(func(who: RefCounted) -> bool: return who.team == 1)]
	_check("six bots, three a side, and the player looks on", all.size() == 6 and sides[0].size() == 3 and sides[1].size() == 3
		and all.all(func(who: RefCounted) -> bool: return who.bot and who.id < 0 and who.brain != null) and Match.me() == null)
	_check("each on the layer of its side, with the other side to walk into", all.all(func(who: RefCounted) -> bool:
		return who.body.collision_layer == (2 | Match.SIDES[who.team]) and who.body.collision_mask == (1 | Match.SIDES[1 - who.team])))
	var middles: Array[Vector3] = []
	for side: Array in sides:
		var middle := Vector3.ZERO
		for who: RefCounted in side:
			middle += who.body.global_position / side.size()
		middles.append(middle)
	_check("the sides start at their own ends", middles[0].distance_to(middles[1]) > 25.0
		and sides[0].all(func(who: RefCounted) -> bool: return who.body.global_position.distance_to(middles[0]) < 12.0))
	var bot: RefCounted = sides[0][0]
	var mate: RefCounted = sides[0][1]
	var foe: RefCounted = sides[1][0]
	_check("a shot at one's own side does nothing", not Match.harm(mate.id, 30.0, mate.body.global_position, Vector3.FORWARD, bot.id, 0) and mate.health == Match.MAX_HEALTH)
	_check("and one at the other side hurts", not Match.harm(foe.id, 30.0, foe.body.global_position, Vector3.FORWARD, bot.id, 0) and foe.health == Match.MAX_HEALTH - 30.0)
	_check("a shot to the head is told from one to the chest", foe.body.is_headshot(foe.body.global_position + Vector3.UP * 1.6) and not foe.body.is_headshot(foe.body.global_position + Vector3.UP * 1.1))
	_check("a bot's ray finds the other side and not its own", Match.foes_of(bot.body) == Match.SIDES[1] and Match.foes_of(foe.body) == Match.SIDES[0])

	# The match, played out to a score that is soon reached.
	Match.mode.numbers = Match.mode.numbers.duplicate()
	Match.mode.numbers.limit = 8
	var falls := [0]
	var back_near := [0]
	var backs := [0]
	Match.felled.connect(func(_by: int, _fallen: int, _weapon: int, _head: bool) -> void: falls[0] += 1)
	Engine.time_scale = 6.0
	var began := Time.get_ticks_msec()
	var clock := 0.0
	var seen_out := {}
	while Match.state == Match.State.PLAYING and clock < 420.0:
		await _wait(0.25)
		clock += 0.25
		for who: RefCounted in Match.entrants.values():
			if who.out > 0.0:
				seen_out[who.id] = true
			elif seen_out.has(who.id):
				# Just back: how near is the nearest of the other side?
				seen_out.erase(who.id)
				backs[0] += 1
				for other: RefCounted in Match.entrants.values():
					if other.out <= 0.0 and other.team != who.team and other.body.global_position.distance_to(who.body.global_position) < 8.0:
						back_near[0] += 1
						break
	Engine.time_scale = 1.0
	var kills := 0
	var deaths := 0
	for who: RefCounted in Match.entrants.values():
		kills += who.kills
		deaths += who.deaths
	print("  played %.0f s of match in %.0f s: %d : %d, %d deaths, %d came back (%d of them within 8 m of an enemy), %d times nowhere was safe, %d times a bot got stuck"
		% [clock, (Time.get_ticks_msec() - began) / 1000.0, Match.tally[0], Match.tally[1], deaths, backs[0], back_near[0], Match.arena.emergencies, Match.stuck])
	_check("the bots find each other and fight it out", Match.state == Match.State.OVER and maxi(Match.tally[0], Match.tally[1]) == 8)
	_check("the side with the points has won", Match.won == (0 if Match.tally[0] > Match.tally[1] else 1))
	_check("every kill is a point and every death is counted once", kills == Match.tally[0] + Match.tally[1] and deaths == falls[0] and deaths >= kills)
	_check("whoever died came back", backs[0] >= deaths - 6 and backs[0] > 0)
	_check("and seldom next to an enemy", back_near[0] * 5 <= backs[0])
	_check("nothing hurts once it is over", not Match.harm(foe.id, 500.0, foe.body.global_position, Vector3.FORWARD, bot.id, 0))
	Match.again()
	await tree.scene_changed
	await _until(func() -> bool: return Match.state == Match.State.PLAYING, 20.0)
	_check("it is played again from nought, in a level loaded afresh", tree.current_scene != game and Match.state == Match.State.PLAYING
		and Match.tally == [0, 0] and Match.entrants.size() == 6 and Match.entrants.values().all(func(who: RefCounted) -> bool: return who.kills == 0 and who.out <= 0.0 and not who.body.dead))

	# With the player in it, everybody for themselves.
	_check("another kind opens from the first", Match.open({"mode": "ffa", "level": "factory", "size": 4}) and Match.setup.mode == "ffa")
	await tree.scene_changed
	await _until(func() -> bool: return Match.state == Match.State.PLAYING, 20.0)
	game = tree.current_scene
	var player: CharacterBody3D = game.player
	player.force_control = true
	var me: RefCounted = Match.me()
	_check("the player is one of four, each on a side of its own", me != null and me.body == player and Match.entrants.size() == 4
		and Match.entrants.values().all(func(who: RefCounted) -> bool: return who == me or Match.mode.hostile(me, who)))
	_check("and can be shot at like the others", Match.plays(player) and player.collision_layer & Match.SIDES[0] != 0 and Match.foes_of(player) == Match.SIDES[0])
	# The bots stand still for what follows.
	for who: RefCounted in Match.entrants.values():
		if who.brain:
			who.brain.process_mode = Node.PROCESS_MODE_DISABLED
	var target: RefCounted = Match.entrants.values().filter(func(who: RefCounted) -> bool: return who.bot)[0]
	_check("a shot of the player's that kills counts for the player", Match.hit(player, target.body, 500.0, target.body.global_position + Vector3.UP, Vector3.FORWARD, 0, true)
		and me.kills == 1 and target.deaths == 1 and target.out > 0.0 and target.body.dead and game.kills == 1)
	_check("and leaves a can of ammunition", tree.get_nodes_in_group("pickup").size() == 1)
	await _wait(float(Match.mode.numbers.respawn) + 0.3)
	_check("the bot is back, as good as new and somewhere else", target.out <= 0.0 and not target.body.dead and target.health == Match.MAX_HEALTH and target.body.visible)
	_check("nothing hurts it for a moment", target.safe > 0.0 and not Match.harm(target.id, 50.0, target.body.global_position, Vector3.FORWARD, me.id, 0) and target.health == Match.MAX_HEALTH)
	Match.harm(me.id, 40.0, player.global_position, Vector3.FORWARD, target.id, 0)
	_check("a bot's shot hurts the player", player.health == 60.0 and not player.dead)
	Match.harm(me.id, 500.0, player.global_position, Vector3.FORWARD, target.id, 2, true)
	_check("and can bring the player down, which counts for the bot", player.dead and me.deaths == 1 and target.kills == 1 and me.out > 0.0)
	await _wait(float(Match.mode.numbers.respawn) + 0.3)
	_check("the player is back in the same level, on their feet", tree.current_scene == game and not player.dead and player.health == player.MAX_HEALTH and me.out <= 0.0)
	player.take_damage(30.0)
	await _wait(float(Match.rules.regen_after) + 2.0)
	_check("health comes back all the way", player.health == player.MAX_HEALTH)

	# What the menu offers, and leaving.
	Menu._show(Menu.Screen.MATCH)
	var offered := Menu._column.get_children().filter(func(control: Node) -> bool: return control is Button).map(func(button: Button) -> String: return button.text)
	_check("the menu has a screen for it", offered.has("Start") and offered.any(func(text: String) -> bool: return text.begins_with("Kind")))
	var buttons := Menu._column.get_children().filter(func(control: Node) -> bool: return control is Button)
	var kind: Button = buttons.filter(func(button: Button) -> bool: return button.text.begins_with("Kind"))[0]
	var was := kind.text
	kind.pressed.emit()
	_check("on which a button goes through the kinds", kind.text != was and kind.text.begins_with("Kind"))
	kind.pressed.emit()
	_check("and back to the first", kind.text == was)
	(buttons.filter(func(button: Button) -> bool: return button.text == "Start")[0] as Button).pressed.emit()
	await tree.scene_changed
	await _until(func() -> bool: return Match.state == Match.State.PLAYING, 30.0)
	_check("Start plays what was chosen: six a side on the works, the player among them", Match.setup.mode == "tdm" and Match.setup.level == "works"
		and Match.entrants.size() == 12 and Match.me() != null and Match.entrants.values().filter(func(who: RefCounted) -> bool: return who.team == Match.me().team).size() == 6)
	var far := INF
	for who: RefCounted in Match.entrants.values():
		for other: RefCounted in Match.entrants.values():
			if who.team != other.team:
				far = minf(far, who.body.global_position.distance_to(other.body.global_position))
	_check("there too the sides start far apart, at ends a long walk from each other", far > 30.0 and Match.arena.walks[0][Match.arena.ends[1]] > 100.0 and Match.arena.walks[0][Match.arena.ends[1]] < 1000.0)
	print("  the works: %d spots, the ends %.0f m apart to walk, the nearest two of different sides %.0f m apart" % [Match.arena.spots.size(), Match.arena.walks[0][Match.arena.ends[1]], far])
	Match.close()
	_check("leaving it gives back the rules and what was saved", not Match.active and Settings.rules() == plain and Save.checkpoint == saved)

	print("MATCH TEST %s" % ("PASSED" if _failures == 0 else "FAILED (%d)" % _failures))
	tree.quit(1 if _failures else 0)


## With --soak=<seconds> and a --match= of its own: lets that match run for
## so long, however many points are made, and prints what it came to and what
## it cost the processor. With --only-bots that is all bots.
func _soak(seconds: float) -> void:
	await _until(func() -> bool: return Match.state == Match.State.PLAYING, 30.0)
	if Match.state != Match.State.PLAYING:
		print("MATCH SOAK FAILED: no match is being played; give one with --match=")
		return
	Match.mode.numbers = Match.mode.numbers.duplicate()
	Match.mode.numbers.limit = 100000
	Match.left = seconds + 60.0
	var arena: RefCounted = Match.arena
	print("  %d spots; the ends are %.0f m apart to walk and %.0f m as the crow flies" % [arena.spots.size(), arena.walks[0][arena.ends[1]], arena.spots[arena.ends[0]].distance_to(arena.spots[arena.ends[1]])])
	for who: RefCounted in Match.entrants.values():
		print("  %s side %d at %s, %.0f m from end 0 and %.0f m from end 1" % [who.title, who.team, who.body.global_position.snappedf(0.1), who.body.global_position.distance_to(arena.spots[arena.ends[0]]), who.body.global_position.distance_to(arena.spots[arena.ends[1]])])
	Match.felled.connect(func(by: int, fallen: int, _weapon: int, _head: bool) -> void:
		if Match.entrants.has(by) and Match.left > seconds + 50.0:
			print("  %.1f s: %s brought down %s, from %.0f m" % [seconds + 60.0 - Match.left, Match.entrants[by].title, Match.entrants[fallen].title, Match.entrants[by].body.global_position.distance_to(Match.entrants[fallen].body.global_position)]))
	var physics := PackedFloat32Array()
	var began := Time.get_ticks_msec()
	var waited := 0.0
	while waited < seconds:
		await _wait(0.5)
		waited += 0.5
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	physics.sort()
	var mean := 0.0
	for sample in physics:
		mean += sample / physics.size()
	var deaths := 0
	for who: RefCounted in Match.entrants.values():
		deaths += who.deaths
	print("MATCH SOAK %s in %s, %d playing, %.0f s in %.0f s: %d deaths, %d times nowhere was safe, %d times a bot got stuck; a physics step took %.2f ms on average, %.2f ms at the 95th of a hundred and %.2f ms at worst, %d steps a second"
		% [Match.setup.mode, Match.setup.level, Match.entrants.size(), seconds, (Time.get_ticks_msec() - began) / 1000.0, deaths, Match.arena.emergencies, Match.stuck,
			mean, physics[int(physics.size() * 0.95)], physics[-1], Engine.physics_ticks_per_second])


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


## Waits until `done` holds, `seconds` at most.
func _until(done: Callable, seconds: float) -> void:
	var waited := 0.0
	while not done.call() and waited < seconds:
		await _wait(0.1)
		waited += 0.1
