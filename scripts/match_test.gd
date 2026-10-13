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
	var caps := []
	for difficulty in 3:
		Settings.difficulty = difficulty
		caps.append([Settings.rules().regen_to, Settings.rules().hurts, int(Settings.rules().focus), Settings.rules().bots])
	Settings.difficulty = 1
	_check("the rules are those of a match, by the difficulty: health comes back to 100, 75 and 50", Settings.rules().drops == 0.0
		and caps == [[100.0, 0.75, 1, "recruit"], [75.0, 0.9, 2, "regular"], [50.0, 1.0, 0, "hardened"]])
	_check("and so is how good the bots are: slower, wider of the mark and firing shorter the easier it is", Match.bot_level().reaction == 0.55 and Match.bot_level().fov == 110.0
		and Match.levels.recruit.reaction > Match.levels.hardened.reaction and Match.levels.recruit.wander > Match.levels.hardened.wander
		and Match.levels.recruit.burst < Match.levels.hardened.burst and Match.levels.recruit.rest[0] > Match.levels.hardened.rest[1])
	_check("whoever goes down is back in two seconds, whatever the kind", Match.kinds.values().all(func(numbers: Dictionary) -> bool: return numbers.respawn == 2.0))
	var cells := tree.get_nodes_in_group("pickup").filter(func(pickup: Node) -> bool: return pickup.kind == pickup.Kind.HEALTH)
	_check("a cell or two that mend lie between the ends, and stay there", cells.size() >= 1 and cells.size() <= 4 and cells.all(func(cell: Node) -> bool:
		return cell.stays and absf(Match.arena.spots[Match.arena.ends[0]].distance_to(cell.global_position) - Match.arena.spots[Match.arena.ends[1]].distance_to(cell.global_position)) < 40.0))
	var all: Array = Match.entrants.values()
	var sides := [all.filter(func(who: RefCounted) -> bool: return who.team == 0), all.filter(func(who: RefCounted) -> bool: return who.team == 1)]
	_check("six bots, three a side, and the player looks on", all.size() == 6 and sides[0].size() == 3 and sides[1].size() == 3
		and all.all(func(who: RefCounted) -> bool: return who.bot and who.id < 0 and who.brain != null) and Match.me() == null)
	_check("each on the layer of its side, with the other side to walk into", all.all(func(who: RefCounted) -> bool:
		return who.body.collision_layer == (2 | Match.SIDES[who.team]) and who.body.collision_mask == (1 | Match.SIDES[1 - who.team])))
	_check("the second side wears the other uniform, the first the usual one", sides[1].all(func(who: RefCounted) -> bool: return who.body._rig._figure.scene_file_path.contains("_desert"))
		and sides[0].all(func(who: RefCounted) -> bool: return not who.body._rig._figure.scene_file_path.contains("_desert")))
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
	_check("and leaves a can of ammunition", tree.get_nodes_in_group("pickup").filter(func(pickup: Node) -> bool: return pickup.kind == pickup.Kind.AMMO).size() == 1)
	await _wait(float(Match.mode.numbers.respawn) + 0.3)
	_check("the bot is back, as good as new and somewhere else", target.out <= 0.0 and not target.body.dead and target.health == Match.MAX_HEALTH and target.body.visible)
	_check("nothing hurts it for a moment", target.safe > 0.0 and not Match.harm(target.id, 50.0, target.body.global_position, Vector3.FORWARD, me.id, 0) and target.health == Match.MAX_HEALTH)
	# How many bots fire at a person at a time.
	var bots: Array = Match.entrants.values().filter(func(who: RefCounted) -> bool: return who.bot)
	Settings.difficulty = 0
	_check("on easy one bot fires at the player at a time, and the next waits", Match.may_fire(bots[0], me) and not Match.may_fire(bots[1], me) and Match.may_fire(bots[0], me) and not Match.may_fire(bots[2], me))
	_check("at another bot they all may", Match.may_fire(bots[1], bots[0]) and Match.may_fire(bots[2], bots[0]))
	await _wait(Match.LETS_UP + 0.2)
	_check("once the one lets up, another may", Match.may_fire(bots[1], me) and not Match.may_fire(bots[0], me))
	Settings.difficulty = 1
	await _wait(Match.LETS_UP + 0.2)
	_check("on normal two at a time", Match.may_fire(bots[0], me) and Match.may_fire(bots[1], me) and not Match.may_fire(bots[2], me))
	Settings.difficulty = 2
	_check("and on hard everybody who sees them", Match.may_fire(bots[2], me))
	# On easy it takes two shots of a marksman's rifle to the body, or one to
	# the head.
	Settings.difficulty = 0
	var marksman: WeaponData = player.weapons.LOADOUT[4]
	me.safe = 0.0
	Match.harm(me.id, marksman.damage, player.global_position, Vector3.FORWARD, target.id, 4)
	_check("on easy one shot of a marksman's rifle to the body leaves the player standing", not player.dead and player.health > 40.0 and player.health < 60.0)
	Match.harm(me.id, marksman.damage, player.global_position, Vector3.FORWARD, target.id, 4)
	_check("and the second brings them down, which counts for the bot", player.dead and me.deaths == 1 and target.kills == 1 and me.out > 0.0)
	await _wait(float(Match.mode.numbers.respawn) + 0.3)
	_check("the player is back in the same level, on their feet", tree.current_scene == game and not player.dead and player.health == player.MAX_HEALTH and me.out <= 0.0)
	me.safe = 0.0
	Match.harm(me.id, marksman.damage * marksman.headshot_multiplier, player.global_position, Vector3.FORWARD, target.id, 4, true)
	_check("one to the head is enough, on easy too", player.dead)
	var shotgun: WeaponData = player.weapons.LOADOUT[2]
	_check("a bot's whole load of shot is not, on easy: pellets to the head count as any other", shotgun.damage * shotgun.pellets * float(Match.rules.hurts) < player.MAX_HEALTH)
	await _wait(float(Match.mode.numbers.respawn) + 0.3)
	Settings.difficulty = 2
	me.safe = 0.0
	Match.harm(me.id, 40.0, player.global_position, Vector3.FORWARD, target.id, 0)
	_check("on hard a bot's shot does all it does", player.health == 60.0)
	# How far health comes back by itself.
	Engine.time_scale = 4.0
	var came_to := []
	for difficulty in [2, 1, 0]:
		Settings.difficulty = difficulty
		player.health = 20.0
		player.take_damage(1.0)
		await _wait(float(Match.rules.regen_after) + 5.0)
		came_to.append(player.health)
	Engine.time_scale = 1.0
	_check("health comes back to half on hard, three quarters on normal and all the way on easy", came_to == [50.0, 75.0, 100.0])
	Settings.difficulty = 1

	# Against whoever the enemies were chosen to be.
	var theme: String = Settings.enemy_theme
	Settings.enemy_theme = "zombies"
	_check("a match against zombies opens", Match.open({"mode": "tdm", "level": "factory", "size": 3}))
	await tree.scene_changed
	await _until(func() -> bool: return Match.state == Match.State.PLAYING, 20.0)
	game = tree.current_scene
	player = game.player
	me = Match.me()
	var others: Array = Match.entrants.values().filter(func(who: RefCounted) -> bool: return who.team != me.team)
	var own: Array = Match.entrants.values().filter(func(who: RefCounted) -> bool: return who.team == me.team and who.bot)
	_check("the other side is zombies, with a weapon of the loadout in their hands, and the player's side soldiers", others.size() == 3
		and others.all(func(who: RefCounted) -> bool: return who.body._rig._figure.scene_file_path.contains("zombie") and who.body._rig._weapon != null)
		and own.all(func(who: RefCounted) -> bool: return who.body._rig._figure.scene_file_path.contains("soldier")))
	player.invulnerable = true
	var from: Array = others.map(func(who: RefCounted) -> Vector3: return who.body.global_position)
	Engine.time_scale = 4.0
	await _wait(4.0)
	var fastest := 0.0
	for i in others.size():
		fastest = maxf(fastest, others[i].body.global_position.distance_to(from[i]) / 4.0)
	await _wait(30.0)
	Engine.time_scale = 1.0
	var zombie_kills := 0
	for who: RefCounted in others:
		zombie_kills += who.kills
	print("  zombies: the fastest covered %.1f m a second on its way; in 34 s they brought down %d and lost %d" % [fastest, zombie_kills, Match.tally[me.team]])
	_check("they run as fast as anybody, and fight", fastest > player.WALK_SPEED and others[0].brain.SPRINT == player.SPRINT_SPEED and zombie_kills + Match.tally[me.team] > 0)
	Settings.enemy_theme = theme

	# Capture the flag, with a banana.
	_check("capture the flag opens", Match.open({"mode": "ctf", "level": "factory", "size": 3, "prize": "banana", "only_bots": true}) and Match.title() == "Capture the flag")
	await tree.scene_changed
	await _until(func() -> bool: return Match.state == Match.State.PLAYING, 20.0)
	game = tree.current_scene
	var rules: RefCounted = Match.mode
	var prizes: Array = rules.prizes
	var ctf_arena: RefCounted = Match.arena
	_check("each side has a banana on a stand at its own end, in a colour of its own", prizes.size() == 2 and prizes.all(func(prize: Node3D) -> bool: return is_instance_valid(prize) and prize.kind == "banana" and prize.state == rules.HOME)
		and prizes[0].global_position.distance_to(ctf_arena.spots[ctf_arena.ends[0]]) < 0.1 and prizes[1].global_position.distance_to(ctf_arena.spots[ctf_arena.ends[1]]) < 0.1
		and prizes[0].tint != prizes[1].tint)
	for who: RefCounted in Match.entrants.values():
		who.brain.process_mode = Node.PROCESS_MODE_DISABLED
		who.safe = 0.0
	var blues: Array = Match.entrants.values().filter(func(who: RefCounted) -> bool: return who.team == 0)
	var oranges: Array = Match.entrants.values().filter(func(who: RefCounted) -> bool: return who.team == 1)
	var runner: RefCounted = blues[0]
	var second: RefCounted = blues[1]
	var keeper: RefCounted = oranges[0]
	var aside := Vector3(0.4, 0.0, 0.0)
	runner.body.global_position = prizes[0].global_position + aside
	await _wait(0.3)
	_check("touching one's own prize at home does nothing", prizes[0].state == rules.HOME)
	runner.body.global_position = prizes[1].global_position + aside
	await _wait(0.3)
	_check("walking into the other side's prize takes it", prizes[1].state == rules.CARRIED and prizes[1].carrier == runner.body and rules.hurries(runner) and rules.carried_by(runner) == 1)
	_check("whoever has it is wanted at their own stand", (rules.wish(runner) as Vector3).distance_to(prizes[0].global_position) < 0.1)
	runner.body.global_position = ctf_arena.spots[ctf_arena.caches(1)[0] if false else 0] if false else (prizes[0].global_position + prizes[1].global_position) * 0.5
	var fell_at: Vector3 = runner.body.global_position
	Match.harm(runner.id, 500.0, fell_at, Vector3.FORWARD, keeper.id, 0)
	_check("whoever has it drops it where they go down, and that kill is nobody's point", prizes[1].state == rules.DOWN and Vector2(prizes[1].where().x - fell_at.x, prizes[1].where().z - fell_at.z).length() < 1.5
		and runner.out > 0.0 and Match.tally == [0, 0] and keeper.kills == 1)
	_check("the nearest of its own side is wanted there", (rules.wish(rules._nearest(1, prizes[1].where())) as Vector3).distance_to(prizes[1].where()) < 0.1)
	keeper.body.global_position = prizes[1].where() + aside
	await _wait(0.3)
	_check("one of its own side brings it home by touching it", prizes[1].state == rules.HOME)
	second.body.global_position = prizes[1].global_position + aside
	await _wait(0.3)
	keeper.body.global_position = prizes[0].global_position + aside
	await _wait(0.3)
	_check("both can be away at once", prizes[1].carrier == second.body and prizes[0].carrier == keeper.body)
	second.body.global_position = prizes[0].global_position + aside
	await _wait(0.3)
	_check("and nobody scores at a stand that is empty", Match.tally == [0, 0] and prizes[1].state == rules.CARRIED)
	Match.harm(keeper.id, 500.0, keeper.body.global_position, Vector3.FORWARD, second.id, 0)
	rules.numbers = rules.numbers.duplicate()
	rules.numbers.returns = 1.0
	await _wait(1.6)
	_check("a prize that lies there goes home by itself after a while", prizes[0].state == rules.HOME)
	await _wait(0.3)
	_check("and whoever waited at the stand with the other one scores", Match.tally == [1, 0] and prizes[1].state == rules.HOME and Match.state == Match.State.PLAYING)
	rules.numbers.returns = 20.0
	await _wait(float(rules.numbers.respawn) + 0.3)
	var home: Vector3 = ctf_arena.spots[ctf_arena.ends[0]]
	_check("whoever went down comes back on the ground of their own base", runner.out <= 0.0 and runner.body.global_position.distance_to(home) < 26.0 and runner.body.global_position.distance_to(home) > 3.0)
	# Bots play it out among themselves.
	for who: RefCounted in Match.entrants.values():
		who.brain.process_mode = Node.PROCESS_MODE_INHERIT
	var took := [0]
	Match.said.connect(func(text: String) -> void:
		if text.contains(" has "):
			took[0] += 1)
	Engine.time_scale = 6.0
	clock = 0.0
	var before: Array = Match.tally.duplicate()
	Match.left = 300.0
	while Match.state == Match.State.PLAYING and clock < 320.0:
		await _wait(0.5)
		clock += 0.5
	Engine.time_scale = 1.0
	print("  capture the flag among bots: %d : %d after %.0f s, the prize taken %d times, %d times a bot got stuck" % [Match.tally[0], Match.tally[1], clock, took[0], Match.stuck])
	_check("it ends at three points or when the time is up, for whoever leads then", Match.state == Match.State.OVER
		and Match.won == (rules.DRAW if Match.tally[0] == Match.tally[1] else 0 if Match.tally[0] > Match.tally[1] else 1)
		and Match.tally[0] >= before[0] and maxi(Match.tally[0], Match.tally[1]) <= 3)

	# The player with the prize: going down drops it, and it stays dropped.
	_check("capture the flag opens with the player in it", Match.open({"mode": "ctf", "level": "factory", "size": 2, "prize": "flag"}))
	await tree.scene_changed
	await _until(func() -> bool: return Match.state == Match.State.PLAYING, 20.0)
	game = tree.current_scene
	player = game.player
	me = Match.me()
	rules = Match.mode
	for who: RefCounted in Match.entrants.values():
		who.safe = 0.0
		if who.brain:
			who.brain.process_mode = Node.PROCESS_MODE_DISABLED
	var ally: RefCounted = Match.entrants.values().filter(func(who: RefCounted) -> bool: return who.bot and who.team == me.team)[0]
	var enemy: RefCounted = Match.entrants.values().filter(func(who: RefCounted) -> bool: return who.team != me.team)[0]
	var theirs: Node3D = rules.prizes[1 - me.team]
	var ours: Node3D = rules.prizes[me.team]
	player.global_position = theirs.global_position + aside
	await _wait(0.3)
	_check("the player takes the other side's flag by walking into it", theirs.state == rules.CARRIED and theirs.carrier == player and rules.status(me).contains("with you"))
	var halfway: Vector3 = (ours.global_position + theirs.global_position) * 0.5
	player.global_position = halfway
	await _wait(0.2)
	Match.harm(me.id, 500.0, halfway, Vector3.FORWARD, enemy.id, 0)
	_check("and drops it where they go down", player.dead and theirs.state == rules.DOWN and Vector2(theirs.where().x - halfway.x, theirs.where().z - halfway.z).length() < 1.5)
	await _wait(float(rules.numbers.respawn) + 0.5)
	_check("it does not come along when they are back at their base: it lies where it fell", not player.dead and theirs.state == rules.DOWN and theirs.carrier == null
		and Vector2(theirs.where().x - halfway.x, theirs.where().z - halfway.z).length() < 1.5 and player.global_position.distance_to(theirs.where()) > 5.0)
	ally.body.global_position = theirs.where() + aside
	await _wait(0.3)
	_check("one of their own side takes it over", theirs.state == rules.CARRIED and theirs.carrier == ally.body)
	Match.harm(ally.id, 500.0, ally.body.global_position, Vector3.FORWARD, enemy.id, 0)
	enemy.body.global_position = theirs.where() + aside
	await _wait(0.3)
	_check("and the side it belongs to sends it home by touching it", theirs.state == rules.HOME and Match.tally == [0, 0])

	# What the menu offers, and leaving.
	Menu._show(Menu.Screen.MATCH)
	var offered := Menu._column.get_children().filter(func(control: Node) -> bool: return control is Button).map(func(button: Button) -> String: return button.text)
	_check("the menu has a screen for it", offered.has("Start") and offered.any(func(text: String) -> bool: return text.begins_with("Kind")))
	var buttons := Menu._column.get_children().filter(func(control: Node) -> bool: return control is Button)
	var kind: Button = buttons.filter(func(button: Button) -> bool: return button.text.begins_with("Kind"))[0]
	var was := kind.text
	var kinds_seen := [was]
	for i in Match.kinds.size() - 1:
		kind.pressed.emit()
		kinds_seen.append(kind.text)
	_check("on which a button goes through the kinds, capture the flag among them", kinds_seen.has("Kind  ·  Capture the flag") and kinds_seen.has("Kind  ·  Free for all") and kinds_seen.has("Kind  ·  Team deathmatch"))
	var prize_button: Button = buttons.filter(func(button: Button) -> bool: return button.text.begins_with("Prize"))[0]
	var prizes_seen := []
	for i in 3:
		prizes_seen.append(prize_button.text)
		prize_button.pressed.emit()
	_check("and another through what is fought over, when it is capture the flag", prize_button.visible and prizes_seen.has("Prize  ·  Flag") and prizes_seen.has("Prize  ·  Football") and prizes_seen.has("Prize  ·  Giant banana"))
	kind.pressed.emit()
	_check("and back to the first", kind.text == was and not prize_button.visible)
	var against: Button = buttons.filter(func(button: Button) -> bool: return button.text.begins_with("Against"))[0]
	var seen := [against.text]
	for i in 8:
		against.pressed.emit()
		if not seen.has(against.text):
			seen.append(against.text)
	_check("another goes through who to play against: soldiers, zombies and clowns among them, robots not", seen.has("Against  ·  Soldiers") and seen.has("Against  ·  Zombies") and seen.has("Against  ·  Clowns")
		and not seen.any(func(text: String) -> bool: return text.contains("Robots") or text.contains("Desert")))
	Settings.enemy_theme = theme
	var level: Button = buttons.filter(func(button: Button) -> bool: return button.text.begins_with("Difficulty"))[0]
	level.pressed.emit()
	_check("and another through the difficulty", level.text == "Difficulty  ·  Hard" and Settings.difficulty == 2)
	Settings.difficulty = 1
	var arenas: Button = buttons.filter(func(button: Button) -> bool: return button.text.begins_with("Arena"))[0]
	var places := [arenas.text]
	for i in 4:
		arenas.pressed.emit()
		places.append(arenas.text)
	arenas.pressed.emit()
	_check("the dunes are among the arenas", places.has("Arena  ·  Dunes") and arenas.text == places[0])
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
	await _until(func() -> bool: return Match.state == Match.State.PLAYING, 60.0)
	if Match.state != Match.State.PLAYING:
		print("MATCH SOAK FAILED: no match is being played; give one with --match=")
		return
	Match.mode.numbers = Match.mode.numbers.duplicate()
	Match.mode.numbers.limit = 100000
	Match.left = seconds + 60.0
	var arena: RefCounted = Match.arena
	print("  %d spots, found in %.2f s; the ends are %.0f m apart to walk and %.0f m as the crow flies" % [arena.spots.size(), arena.took, arena.length(), arena.spots[arena.ends[0]].distance_to(arena.spots[arena.ends[1]])])
	for who: RefCounted in Match.entrants.values():
		print("  %s side %d at %s, %.0f m from end 0 and %.0f m from end 1" % [who.title, who.team, who.body.global_position.snappedf(0.1), who.body.global_position.distance_to(arena.spots[arena.ends[0]]), who.body.global_position.distance_to(arena.spots[arena.ends[1]])])
	Match.felled.connect(func(by: int, fallen: int, _weapon: int, _head: bool) -> void:
		if Match.entrants.has(by) and Match.left > seconds + 50.0:
			print("  %.1f s: %s brought down %s, from %.0f m" % [seconds + 60.0 - Match.left, Match.entrants[by].title, Match.entrants[fallen].title, Match.entrants[by].body.global_position.distance_to(Match.entrants[fallen].body.global_position)]))
	var physics := PackedFloat32Array()
	var began := Time.get_ticks_msec()
	var waited := 0.0
	var nearest := INF
	var walked := 0.0
	var stood := {}
	# With the player in it: they stand where they were put and cannot die,
	# and what the bots do to them is added up, at the difficulty asked for
	# with --difficulty=<0 to 2>.
	var hits: Array[Vector2] = []
	var game := get_tree().current_scene
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--difficulty="):
			Settings.difficulty = arg.get_slice("=", 1).to_int()
	if Match.me():
		game.player.damaged.connect(func(amount: float) -> void:
			hits.append(Vector2(Match.left, amount))
			game.player.health = 1e6)
	var news := {}
	Match.said.connect(func(text: String) -> void:
		for word: String in [" has ", " dropped ", " brought ", " back home", " scored "]:
			if text.contains(word):
				news[word.strip_edges()] = int(news.get(word.strip_edges(), 0)) + 1)
	while waited < seconds:
		await _wait(0.5)
		waited += 0.5
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		for who: RefCounted in Match.entrants.values():
			if who.out > 0.0:
				stood.erase(who.id)
				continue
			if stood.has(who.id):
				walked += who.body.global_position.distance_to(stood[who.id])
			stood[who.id] = who.body.global_position
			for other: RefCounted in Match.entrants.values():
				if other.out <= 0.0 and Match.mode.hostile(who, other):
					nearest = minf(nearest, who.body.global_position.distance_to(other.body.global_position))
	print("  each walked %.1f m a second on average; the nearest two against each other ever came is %.0f m" % [walked / seconds / Match.entrants.size(), nearest])
	if Match.me():
		# The shortest stretch in which the player took a hundred, and how
		# much of the time they were being hit at all.
		var total := 0.0
		var quickest := INF
		for i in hits.size():
			total += hits[i].y
			var sum := 0.0
			for j in range(i, hits.size()):
				sum += hits[j].y
				if sum >= 100.0:
					quickest = minf(quickest, hits[i].x - hits[j].x)
					break
		print("  on %s the player, standing still, was hit %d times for %.0f in all, %.1f a second; the quickest hundred took %s" % [Settings.DIFFICULTY_NAMES[Settings.difficulty].to_lower(), hits.size(), total, total / seconds, "%.1f s" % quickest if quickest < INF else "longer than there was"])
	if not news.is_empty():
		print("  the score is %d : %d; what was said of the prizes, and how often: %s" % [Match.tally[0], Match.tally[1], news])
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
