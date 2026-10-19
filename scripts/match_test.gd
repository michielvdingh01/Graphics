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
## bot got stuck and how often nobody could come back anywhere safe. Last it
## has twenty a side play in the dunes, and looks at where those who fall
## come back: near a friend and near the fight, not at the far end. On the
## way it has bots take up the weapons of the arena and fight with them;
## with --specials it does only that. With --pack=<name> it only has bots play
## a match with that pack and counts the kills by weapon, see _pack_kills().

const ROBOT_RIG := preload("res://scripts/enemy_rig.gd")

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
	tree.create_timer(600.0, true, false, true).timeout.connect(
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
	var told := Array(OS.get_cmdline_user_args())
	if not told.any(func(arg: String) -> bool: return arg.begins_with("--match=")):
		for arg in told:
			if arg.begins_with("--pack="):
				await _pack_kills(arg.get_slice("=", 1))
				tree.quit(0)
				return
	if "--specials" in OS.get_cmdline_user_args():
		# Only the part with the weapons of the arena in the hands of bots.
		Settings.enemy_theme = "soldiers"
		await _bots_and_specials()
		print("MATCH TEST %s" % ("PASSED" if _failures == 0 else "FAILED (%d)" % _failures))
		tree.quit(1 if _failures else 0)
		return
	var saved: Dictionary = Save.checkpoint.duplicate()
	var plain: Dictionary = Settings.rules()
	# Soldiers on both sides, until it is played against others further on.
	var theme: String = Settings.enemy_theme
	Settings.enemy_theme = "soldiers"

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
	# The weapons of the arena: on a stand somewhere out of the way, there
	# after a while, taken by walking up to them and lost by going down.
	var stands := tree.get_nodes_in_group("stash")
	var arena: RefCounted = Match.arena
	var stand: Node3D = stands[0] if not stands.is_empty() else null
	var minigun: WeaponData = load("res://weapons/minigun.tres")
	var from_ends := []
	for one: Node3D in stands:
		var nearest := INF
		for end: int in arena.ends:
			nearest = minf(nearest, one.global_position.distance_to(arena.spots[end]))
		from_ends.append(snappedf(nearest, 0.1))
	print("  the weapons of the arena: %s, %s m from the nearest end" % [stands.map(func(one: Node3D) -> String: return one.weapon.display_name), from_ends])
	var places_apart: bool = stands.size() == 2 and stands[0].global_position.distance_to(stands[1].global_position) > 15.0
	_check("the minigun and the rocket launcher stand apart, away from both ends, and are not there yet at the start", stand != null and stand.weapon == minigun and places_apart
		and from_ends.all(func(metres: float) -> bool: return metres > 15.0) and stands.all(func(one: Node3D) -> bool: return not one.is_up() and one.due() > 30.0))
	var news := []
	var listen := func(text: String) -> void: news.append(text)
	Match.said.connect(listen)
	stand.come_in(0.0)
	_check("once one is there everybody is told", stand.is_up() and news.has("Minigun is up"))
	player.global_position = stand.global_position + Vector3(0.4, 0.0, 0.0)
	await _wait(0.3)
	_check("the player takes it by walking up to it, and the stand stays empty", player.weapons.special() == minigun and not stand.is_up() and stand.due() == INF
		and news.any(func(text: String) -> bool: return text.ends_with("has the minigun")))
	Match.said.disconnect(listen)
	var went_down_at := player.global_position
	# Down by nobody's hand, so that no bot has a kill to show for it.
	Match.harm(me.id, 500.0, went_down_at, Vector3.FORWARD, 0, Match.BLAST)
	await _wait(0.2)
	var lying := tree.get_nodes_in_group("stash").filter(func(one: Node3D) -> bool: return one.dropped)
	_check("going down the player leaves it where they fell, with all that was left in it", player.weapons.special() == null and lying.size() == 1
		and Vector2(lying[0].global_position.x - went_down_at.x, lying[0].global_position.z - went_down_at.z).length() < 0.5 and lying[0].rounds == minigun.mag_size)
	lying[0]._age = lying[0].LIES - 0.1
	await _wait(0.3)
	_check("left lying, it goes, and its stand has it back a while later", not is_instance_valid(lying[0]) and stand.due() > 60.0 and stand.due() < INF)
	await _wait(float(Match.mode.numbers.respawn))
	me.deaths = 0
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
	var marksman: WeaponData = player.weapons.loadout[4]
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
	var shotgun: WeaponData = player.weapons.loadout[2]
	_check("a bot's whole load of shot is not, on easy: pellets to the head count as any other", shotgun.damage * shotgun.pellets * float(Match.rules.hurts) < player.MAX_HEALTH)
	await _wait(float(Match.mode.numbers.respawn) + 0.3)
	me.safe = 0.0
	var blow: float = player.weapons.MELEE_DAMAGE
	Match.harm(me.id, blow, player.global_position, Vector3.FORWARD, target.id, Match.MELEE)
	var after_one: float = player.health
	Match.harm(me.id, blow, player.global_position, Vector3.FORWARD, target.id, Match.MELEE)
	_check("two blows of a bot's weapon bring the player down, on easy too", after_one == player.MAX_HEALTH - blow and player.dead)
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
	await _bots_and_specials()

	# Against whoever the enemies were chosen to be.
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

	# Against robots: those of the route, with a weapon of the loadout in
	# their arm.
	Settings.enemy_theme = "robots"
	_check("a match against robots opens", Match.open({"mode": "tdm", "level": "factory", "size": 6}))
	await tree.scene_changed
	await _until(func() -> bool: return Match.state == Match.State.PLAYING, 20.0)
	game = tree.current_scene
	player = game.player
	me = Match.me()
	others = Match.entrants.values().filter(func(who: RefCounted) -> bool: return who.team != me.team)
	own = Match.entrants.values().filter(func(who: RefCounted) -> bool: return who.team == me.team and who.bot)
	var robot := func(who: RefCounted) -> bool: return who.body._rig is ROBOT_RIG and who.body._rig.scene_file_path.get_file() in ["grunt.scn", "heavy.scn"]
	_check("the other side is grunts and a heavy, and the player's side soldiers", others.size() == 6 and others.all(robot)
		and others.any(func(who: RefCounted) -> bool: return who.body._rig.scene_file_path.ends_with("heavy.scn"))
		and own.all(func(who: RefCounted) -> bool: return who.body._rig._figure.scene_file_path.contains("soldier")))
	var heavy: CharacterBody3D = others.filter(func(who: RefCounted) -> bool: return who.body._rig.scene_file_path.ends_with("heavy.scn"))[0].body
	var grunt: CharacterBody3D = others.filter(func(who: RefCounted) -> bool: return who.body._rig.scene_file_path.ends_with("grunt.scn"))[0].body
	_check("they carry no plate, a shot on one sounds of steel, and the heavy is taller to it than a grunt", others.all(func(who: RefCounted) -> bool: return not who.body._rig.has_shield)
		and Fx.surface_of({"collider": grunt, "shape": 0}) == "metal" and heavy.is_headshot(heavy.global_position + Vector3.UP * 1.6) and not heavy.is_headshot(heavy.global_position + Vector3.UP * 1.5)
		and grunt.is_headshot(grunt.global_position + Vector3.UP * 1.4))
	player.invulnerable = true
	Engine.time_scale = 4.0
	await _wait(30.0)
	Engine.time_scale = 1.0
	var robot_kills := 0
	var robot_deaths := 0
	for who: RefCounted in others:
		robot_kills += who.kills
		robot_deaths += who.deaths
	print("  robots: in 30 s they brought down %d and lost %d" % [robot_kills, robot_deaths])
	var standing: Array = others.filter(func(who: RefCounted) -> bool: return who.out <= 0.0)
	_check("they fight, fall apart, and come back as robots", robot_kills > 0 and robot_deaths > 0 and others.all(robot) and not standing.is_empty()
		and standing.all(func(who: RefCounted) -> bool: return who.body._rig.find_children("*", "MeshInstance3D").size() > 10))
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
		if text.contains(" has ") and not _of_the_arena(text):
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
	print("  %s" % _taken())
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
	var prize_was := Settings.prize
	_check("and another for what is fought over, when it is capture the flag", prize_button.visible and prize_button.text == "Prize  ·  %s" % (load("res://scripts/prize.gd") as GDScript).spec(Settings.prize).get("name", "?"))
	prize_button.pressed.emit()
	var listed := _shown_buttons()
	_check("which opens a list of every prize there is", ["Flag", "Football", "Giant banana", "Back"].all(func(text: String) -> bool: return listed.any(func(button: Button) -> bool: return button.text == text)))
	(listed.filter(func(button: Button) -> bool: return button.text == "Football")[0] as Button).pressed.emit()
	buttons = _shown_buttons()
	prize_button = buttons.filter(func(button: Button) -> bool: return button.text.begins_with("Prize"))[0]
	_check("choosing one goes back with it chosen, and keeps it", prize_button.text == "Prize  ·  Football" and Settings.prize == "football" and Menu.MATCH_MENU.chosen.prize == "football")
	Settings.prize = prize_was
	kind = buttons.filter(func(button: Button) -> bool: return button.text.begins_with("Kind"))[0]
	kind.pressed.emit()
	_check("and back to the first", kind.text == was and not prize_button.visible)
	var against: Button = buttons.filter(func(button: Button) -> bool: return button.text.begins_with("Against"))[0]
	var seen := [against.text]
	for i in 8:
		against.pressed.emit()
		if not seen.has(against.text):
			seen.append(against.text)
	_check("another goes through who to play against: soldiers, robots, zombies and clowns among them", seen.has("Against  ·  Soldiers") and seen.has("Against  ·  Robots") and seen.has("Against  ·  Zombies") and seen.has("Against  ·  Clowns")
		and not seen.any(func(text: String) -> bool: return text.contains("Desert")))
	Settings.enemy_theme = theme
	var level: Button = buttons.filter(func(button: Button) -> bool: return button.text.begins_with("Difficulty"))[0]
	level.pressed.emit()
	_check("and another through the difficulty", level.text == "Difficulty  ·  Hard" and Settings.difficulty == 2)
	Settings.difficulty = 1
	var pack_was: String = Settings.pack
	var weapons_button: Button = buttons.filter(func(button: Button) -> bool: return button.text.begins_with("Weapons"))[0]
	var packs_seen := [weapons_button.text]
	for i in 7:
		weapons_button.pressed.emit()
		if not packs_seen.has(weapons_button.text):
			packs_seen.append(weapons_button.text)
	print("  the packs on the screen: %s" % [packs_seen])
	_check("and another through the packs of weapons, all seven of them", packs_seen.size() == 7 and packs_seen.has("Weapons  ·  1944") and packs_seen.has("Weapons  ·  Pistols only")
		and packs_seen.has("Weapons  ·  Silenced"))
	Settings.pack = pack_was
	Menu.MATCH_MENU.chosen.pack = pack_was
	var arenas: Button = buttons.filter(func(button: Button) -> bool: return button.text.begins_with("Arena"))[0]
	var places := [arenas.text]
	for i in Menu.MATCH_MENU.ARENAS.size() - 1:
		arenas.pressed.emit()
		places.append(arenas.text)
	arenas.pressed.emit()
	_check("the dunes are among the arenas, by day and by night", places.has("Arena  ·  Dunes (large)") and places.has("Arena  ·  Dunes Night (large)")
		and arenas.text == places[0])
	_check("and the Alps, which are huge", places.has("Arena  ·  Alps (huge)"))
	_check("and each says whether it is small, medium, large or huge", places.all(func(text: String) -> bool:
		return ["(small)", "(medium)", "(large)", "(huge)"].any(func(size: String) -> bool: return text.ends_with(size))))
	var size: Button = buttons.filter(func(button: Button) -> bool: return button.text.begins_with("Players"))[0]
	var size_was := size.text
	while not arenas.text.begins_with("Arena  ·  Dunes"):
		arenas.pressed.emit()
	var sizes := [size.text]
	for i in 14:
		size.pressed.emit()
		sizes.append(size.text.get_slice("·", 1).strip_edges())
	_check("there twenty a side play, and the button goes up to that in steps above twelve", sizes[0] == "Players a side  ·  20"
		and sizes.slice(1) == ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "16", "20"])
	while arenas.text != places[0]:
		arenas.pressed.emit()
	_check("and back in a hall, as many as play there", size.text == size_was)
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

	# A match with another pack: everybody carries it, the player and the bots.
	var armory: GDScript = load("res://scripts/armory.gd")
	_check("a match opens with the pack of 1944", Match.open({"mode": "tdm", "level": "factory", "size": 3, "pack": "1944"}) and Match.setup.pack == "1944")
	await tree.scene_changed
	await _until(func() -> bool: return Match.state == Match.State.PLAYING, 20.0)
	var carried: Array = tree.current_scene.player.weapons.loadout
	var pack_bots: Array = armory.bots("1944")
	var bot_arms := Match.entrants.values().filter(func(who: RefCounted) -> bool: return who.bot).map(func(who: RefCounted) -> String: return armory.at(who.weapon).display_name)
	print("  1944: the player carries %s; the bots %s" % [carried.map(func(data: WeaponData) -> String: return data.display_name), bot_arms])
	_check("the player carries its weapons on their keys, and every bot one of them", carried == armory.weapons("1944")
		and Match.entrants.values().all(func(who: RefCounted) -> bool: return not who.bot or pack_bots.has(who.weapon)))
	# Another pack, chosen in the settings during the match: for when it is
	# started again.
	var pack_set: String = Settings.pack
	Menu._show(Menu.Screen.PAUSE)
	Menu._show(Menu.Screen.SETTINGS)
	var choice: Array = _shown_buttons().filter(func(button: Button) -> bool: return button.text.begins_with("Weapons"))
	_check("in a match the settings offer the packs, at the one that is played", choice.size() == 1 and choice[0].text == "Weapons  ·  1944")
	if choice.size() == 1:
		choice[0].pressed.emit()
	_check("another is for when the match starts again: what is in hand stays in hand", Match.setup.pack == "heavy" and choice.size() == 1
		and choice[0].text == "Weapons  ·  Heavy  (once the match starts again)" and tree.current_scene.player.weapons.loadout == armory.weapons("1944"))
	Menu._show(Menu.Screen.PAUSE)
	var again: Array = _shown_buttons().filter(func(button: Button) -> bool: return button.text.begins_with("Start the match again"))
	_check("and the pause screen says which it starts again with", again.size() == 1 and again[0].text == "Start the match again  ·  Heavy")
	if again.size() == 1:
		again[0].pressed.emit()
	await tree.scene_changed
	await _until(func() -> bool: return Match.state == Match.State.PLAYING, 20.0)
	var heavy_bots: Array = armory.bots("heavy")
	_check("started again, the player carries that pack and every bot a weapon of it", tree.current_scene.player.weapons.loadout == armory.weapons("heavy")
		and Match.pack_in_play == "heavy" and not Menu.is_open() and Match.entrants.values().all(func(who: RefCounted) -> bool: return not who.bot or heavy_bots.has(who.weapon)))
	Settings.pack = pack_set
	Menu.MATCH_MENU.chosen.pack = pack_set
	# A big arena: twenty a side in the dunes, coming back where the fight is.
	_check("the dunes take twenty a side, forty each on their own; the halls six and twelve", Match.most("tdm", "dunes") == 20 and Match.usual("tdm", "dunes") == 20
		and Match.most("ctf", "dunes") == 20 and Match.most("ffa", "dunes") == 40 and Match.most("tdm", "works") == 6 and Match.most("ffa", "works") == 12 and Match.usual("tdm", "works") == 6)
	_check("a match there is twenty a side unless asked otherwise, played to a limit that grows with it", Match.open({"mode": "tdm", "level": "dunes", "only_bots": true})
		and Match.setup.size == 20 and int(Match.mode.numbers.limit) == 170 and int(Match.kinds.tdm.limit) == 50)
	await _until(func() -> bool: return Match.state == Match.State.PLAYING, 90.0)
	var crowd: Array = Match.entrants.values()
	var titles := {}
	for who: RefCounted in crowd:
		titles[who.title] = true
	_check("forty bots, twenty a side, no two of one name", crowd.size() == 40 and titles.size() == 40
		and crowd.filter(func(who: RefCounted) -> bool: return who.team == 0).size() == 20)
	var said_spot: Array = (JSON.parse_string(FileAccess.get_file_as_string(Match.ARENAS)) as Dictionary).dunes.specials.minigun
	var minigun_stand: Array = tree.get_nodes_in_group("stash").filter(func(one: Node3D) -> bool: return one.weapon.resource_path.ends_with("minigun.tres"))
	_check("there the minigun stands where assets/arenas.json says, and not where it is worked out", minigun_stand.size() == 1
		and minigun_stand[0].global_position.distance_to(Vector3(said_spot[0], said_spot[1], said_spot[2])) < 0.01)
	var board: PackedStringArray = Match._hud._table()
	_check("the table under Tab has a column for each side", board.size() == 2 and board[0].count("\n") == 20 and board[1].count("\n") == 20)
	# Who comes back: how far the nearest enemy and the nearest friend are, and
	# how far their own end.
	var comebacks: Array[Vector3] = []
	var gone := {}
	clock = 0.0
	Engine.time_scale = 3.0
	# The sides meet half a minute in: until a dozen have come back.
	while comebacks.size() < 12 and clock < 240.0:
		await _wait(0.25)
		clock += 0.25 * 3.0
		for who: RefCounted in Match.entrants.values():
			if who.out > 0.0:
				gone[who.id] = true
			elif gone.has(who.id):
				gone.erase(who.id)
				var near := Vector2(INF, INF)
				for other: RefCounted in Match.entrants.values():
					if other != who and other.out <= 0.0:
						var gap: float = other.body.global_position.distance_to(who.body.global_position)
						if other.team != who.team:
							near.x = minf(near.x, gap)
						else:
							near.y = minf(near.y, gap)
				comebacks.append(Vector3(near.x, near.y, who.body.global_position.distance_to(Match.arena.spots[Match.arena.ends[who.team]])))
	Engine.time_scale = 1.0
	comebacks.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
	@warning_ignore("integer_division")
	var middle: Vector3 = comebacks[comebacks.size() / 2] if not comebacks.is_empty() else Vector3.INF
	print("  the dunes, twenty a side: %d came back in %.0f s of match, %d times nowhere was safe; the nearest enemy then %.0f m off at the least and %.0f m in the middle, the nearest friend %.0f m in the middle, their own end %.0f m in the middle"
		% [comebacks.size(), clock, Match.arena.emergencies, comebacks[0].x if not comebacks.is_empty() else INF, middle.x,
			_middle_of(comebacks.map(func(one: Vector3) -> float: return one.y)), _middle_of(comebacks.map(func(one: Vector3) -> float: return one.z))])
	_check("there, whoever comes back does so near the fight and near a friend: no enemy within twelve metres, half within ninety, a friend within twenty-five",
		comebacks.size() >= 10 and comebacks[0].x >= 12.0 and middle.x < 90.0 and _middle_of(comebacks.map(func(one: Vector3) -> float: return one.y)) < 25.0)
	Match.close()

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
	var counted := _count_kills()
	var news := {}
	Match.said.connect(func(text: String) -> void:
		for word: String in [" has ", " dropped ", " brought ", " back home", " scored "]:
			if text.contains(word) and not _of_the_arena(text):
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
	print("  %s" % _taken())
	_print_kills(counted[0])
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


## Bots and the weapons of the arena: they take one up by walking past it,
## from Hardened on the nearest of each side goes to fetch it, they fight
## with it as the weapon asks and leave it where they fall.
func _bots_and_specials() -> void:
	var tree := get_tree()
	_check("a match of bots opens to see them with the weapons of the arena", Match.open({"mode": "tdm", "level": "factory", "size": 3, "only_bots": true}))
	await tree.scene_changed
	await _until(func() -> bool: return Match.state == Match.State.PLAYING, 20.0)
	var armory: GDScript = load("res://scripts/armory.gd")
	var minigun: WeaponData = load("res://weapons/minigun.tres")
	var launcher: WeaponData = load("res://weapons/rocket_launcher.tres")
	var bots: Array = Match.entrants.values()
	for who: RefCounted in bots:
		who.brain.process_mode = Node.PROCESS_MODE_DISABLED
		who.safe = 0.0
	var stands := tree.get_nodes_in_group("stash")
	var stand: Node3D = stands.filter(func(one: Node3D) -> bool: return one.weapon == minigun)[0]
	var blue: RefCounted = bots.filter(func(who: RefCounted) -> bool: return who.team == 0)[0]
	var orange: RefCounted = bots.filter(func(who: RefCounted) -> bool: return who.team == 1)[0]
	var own: WeaponData = armory.at(blue.weapon)

	# Walking past.
	stand.come_in(0.0)
	blue.body.global_position = stand.global_position + Vector3(0.4, 0.0, 0.0)
	await _wait(0.3)
	var rig: Node3D = blue.body._rig
	_check("a bot that walks up to the minigun takes it, has it in its hands and is said to have it", blue.brain.special() == minigun and armory.at(blue.weapon) == minigun
		and not stand.is_up() and not Match.takes.is_empty() and Match.takes[-1].by == blue.title and Match.takes[-1].bot and Match.takes[-1].weapon == "minigun")
	_check("its figure carries the minigun, with barrels that turn", rig._weapon != null and rig._weapon.scene_file_path.ends_with("minigun_held.scn") and is_instance_valid(blue.body._barrels))
	_check("one bot does not take a second weapon of the arena while it has one", not Match.can_arm(blue.body))

	# The minigun in a fight: it spins up on sight, fires in bursts and never
	# overheats.
	var pair := _facing_spots(10.0)
	_check("there are two spots 10 m apart that see each other", not pair.is_empty())
	if pair.is_empty():
		return
	blue.body.global_position = pair[0]
	orange.body.global_position = pair[1]
	orange.health = 1e6
	blue.body.look_at(pair[1] + Vector3.UP * (blue.body.global_position.y - pair[1].y), Vector3.UP)
	blue.brain._aim = pair[1] + Vector3.UP
	# It looks at once, and knows where to look: as if it had heard a shot.
	blue.brain._look = 0.0
	blue.brain.heard(orange, pair[1])
	blue.brain.process_mode = Node.PROCESS_MODE_INHERIT
	var first_round := -1.0
	var spun_at := -1.0
	var hottest := 0.0
	var bursts := 0
	var was_firing := false
	var overheated := false
	var clock := 0.0
	while clock < 9.0:
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
		var brain: Node = blue.brain
		if brain._spin >= 1.0 and spun_at < 0.0:
			spun_at = clock
		if brain._mag < minigun.mag_size and first_round < 0.0:
			first_round = clock
		hottest = maxf(hottest, brain._hot)
		overheated = overheated or brain._overheated > 0.0
		if brain._firing and not was_firing:
			bursts += 1
		was_firing = brain._firing
		blue.body.global_position = pair[0]
		orange.body.global_position = pair[1]
	var fired: int = minigun.mag_size - blue.brain._mag
	print("  a bot with the minigun at 10 m: up to speed after %.2f s, first round after %.2f s, %d rounds in %d bursts in 9 s, at most %.0f%% hot" % [spun_at, first_round, fired, bursts, hottest * 100.0])
	_check("it spins up as soon as it sees somebody, and fires once its barrels are up to speed", spun_at > 0.0 and first_round >= spun_at - 0.02 and first_round < spun_at + 0.6)
	_check("it fires in bursts, and never lets the minigun overheat", fired > 80 and bursts >= 2 and not overheated and hottest < 1.0)
	_check("its figure spins the barrels and roars, instead of a shot for every round", blue.body._spin > 0.5 and absf(blue.body._turned) > 0.0 and blue.body._roars_until > 0.0)
	blue.brain.process_mode = Node.PROCESS_MODE_DISABLED

	# The rocket launcher: at the feet, and never from close by.
	blue.brain.take_special(launcher, launcher.mag_size + launcher.reserve_ammo)
	_check("a bot that takes another weapon of the arena lets go of the one it had", blue.brain.special() == launcher)
	var far := _facing_spots(15.0)
	if far.is_empty():
		far = pair
	blue.body.global_position = far[0]
	orange.body.global_position = far[1]
	blue.body.look_at(far[1] + Vector3.UP * (far[0].y - far[1].y), Vector3.UP)
	blue.brain._aim = far[1]
	blue.brain._seen = 0.0
	blue.brain._look = 0.0
	blue.brain.heard(orange, far[1])
	blue.brain.process_mode = Node.PROCESS_MODE_INHERIT
	var rockets: Array = []
	var health: float = orange.health
	clock = 0.0
	while clock < 5.0 and rockets.is_empty():
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
		_note_rockets(rockets, blue.body, orange.body)
		blue.body.global_position = far[0]
		orange.body.global_position = far[1]
	await _wait(1.0)
	var feet: Vector3 = far[1]
	var miss := INF
	if not rockets.is_empty():
		var from: Vector3 = rockets[0][0]
		var along: Vector3 = (rockets[0][1] as Vector3).normalized()
		miss = (feet - from - along * (feet - from).dot(along)).length()
	print("  a bot with the rocket launcher at %.0f m: %d rockets, the first passing %.2f m from the feet; the other lost %.0f" % [far[0].distance_to(far[1]), rockets.size(), miss, health - orange.health])
	_check("it fires a rocket instead of a ray, at the feet, and it hurts", not rockets.is_empty() and miss < 0.9 and orange.health < health)
	rockets.clear()
	var near: Vector3 = far[1] + (far[0] - far[1]).normalized() * 4.0
	blue.body.global_position = near
	blue.brain._reload = 0.0
	blue.brain._mag = 1
	clock = 0.0
	while clock < 2.5:
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
		_note_rockets(rockets, blue.body, orange.body)
	print("  from 4 m: rockets fired at %s m, and it ended up %.1f m away" % [rockets.map(func(one: Array) -> String: return "%.1f" % one[2]), blue.body.global_position.distance_to(orange.body.global_position)])
	_check("nearer than 6 m it fires no rocket, and backs away", rockets.all(func(one: Array) -> bool: return one[2] >= 6.0) and blue.body.global_position.distance_to(orange.body.global_position) > 4.5)
	blue.brain.process_mode = Node.PROCESS_MODE_DISABLED

	# Going down with it.
	var left: int = blue.brain._mag + blue.brain._spare
	var fell_at: Vector3 = blue.body.global_position
	Match.harm(blue.id, 500.0, fell_at, Vector3.FORWARD, orange.id, 0)
	await _wait(0.2)
	var lying := tree.get_nodes_in_group("stash").filter(func(one: Node3D) -> bool: return one.dropped)
	_check("a bot that goes down with it leaves it where it fell, with what was left in it, and is back with its own weapon", lying.size() == 1 and lying[0].weapon == launcher
		and lying[0].rounds == left and Vector2(lying[0].global_position.x - fell_at.x, lying[0].global_position.z - fell_at.z).length() < 0.5
		and blue.brain.special() == null and armory.at(blue.weapon) == own)
	for one: Node3D in lying:
		one.queue_free()
	await _wait(float(Match.mode.numbers.respawn) + 0.3)

	# Fetching, from Hardened on.
	for one: Node3D in tree.get_nodes_in_group("stash"):
		one.come_in(INF if one != stand else 0.0)
	Settings.difficulty = 1
	await _wait(Match.FETCH + 0.1)
	_check("on normal nobody is sent to fetch it", Match._errands.is_empty())
	Settings.difficulty = 2
	await _wait(Match.FETCH + 0.1)
	var sent: Array = bots.filter(func(who: RefCounted) -> bool: return Match.errand(who) != null)
	var nearest := [null, null]
	for side in 2:
		var shortest := INF
		for who: RefCounted in bots:
			if who.team == side:
				var walk: float = Match.arena.walk(who.body.global_position, stand.global_position)
				if walk < shortest:
					shortest = walk
					nearest[side] = who
	print("  on hard, sent to fetch the minigun: %s" % [sent.map(func(who: RefCounted) -> String: return "%s of side %d" % [who.title, who.team])])
	_check("on hard the nearest bot of each side is sent to fetch it, and nobody else", sent.size() == 2 and sent.has(nearest[0]) and sent.has(nearest[1]))
	var runner: RefCounted = nearest[0]
	var other: RefCounted = nearest[1]
	other.body.global_position = Match.arena.spots[Match.arena.ends[1]]
	runner.brain.process_mode = Node.PROCESS_MODE_INHERIT
	await _until(func() -> bool: return runner.brain.special() == minigun, 40.0)
	_check("and the one that is sent goes and takes it", runner.brain.special() == minigun and Match.takes[-1].by == runner.title)
	runner.brain.process_mode = Node.PROCESS_MODE_DISABLED
	Settings.difficulty = 1

	# Up close a bot hits with its weapon instead of firing.
	var hitter: RefCounted = bots.filter(func(who: RefCounted) -> bool: return who.team == 0 and who != runner and who.out <= 0.0)[0]
	var victim: RefCounted = bots.filter(func(who: RefCounted) -> bool: return who.team == 1 and who.out <= 0.0)[0]
	var hitter_rig: Node3D = hitter.body._rig
	hitter_rig.strike_at(0.15)
	var drawn: Vector3 = hitter.body.global_transform.affine_inverse() * (hitter_rig._weapon.global_transform * hitter_rig._butt)
	hitter_rig.strike_at(hitter_rig.STRIKE_LANDS)
	var driven: Vector3 = hitter.body.global_transform.affine_inverse() * (hitter_rig._weapon.global_transform * hitter_rig._butt)
	hitter_rig._strike = -1.0
	print("  a soldier's blow with the carbine: the butt drawn back to %s, driven to %s (x right, y up, -z ahead)" % [drawn.snappedf(0.01), driven.snappedf(0.01)])
	_check("a soldier hits out with the butt of its weapon: drawn back low, then driven forward at the height of a head", drawn.y < 1.3 and driven.y > drawn.y + 0.15 and driven.z < -0.3 and driven.z < drawn.z - 0.4)
	victim.health = Match.MAX_HEALTH
	victim.safe = 0.0
	var deaths: int = victim.deaths
	var start: Vector3 = pair[0]
	var close_by: Vector3 = start + (pair[1] - start).normalized() * 1.5
	hitter.body.global_position = start
	victim.body.global_position = close_by
	hitter.body.look_at(close_by + Vector3.UP * (start.y - close_by.y), Vector3.UP)
	hitter.brain._aim = close_by + Vector3.UP * 1.1
	hitter.brain._seen = 0.0
	hitter.brain._look = 0.0
	hitter.brain.heard(victim, close_by)
	var rounds: int = hitter.brain._mag
	var struck := [false]
	var healths := []
	hitter.brain.process_mode = Node.PROCESS_MODE_INHERIT
	clock = 0.0
	while clock < 3.0 and victim.deaths == deaths:
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
		hitter.body.global_position = start
		if victim.out <= 0.0:
			victim.body.global_position = close_by
		struck[0] = struck[0] or hitter_rig._strike >= 0.0
		if healths.is_empty() or healths[-1] != victim.health:
			healths.append(victim.health)
	hitter.brain.process_mode = Node.PROCESS_MODE_DISABLED
	print("  a bot 1.5 m from an enemy: its health went %s in %.2f s, and it fired %d rounds" % [healths, clock, rounds - hitter.brain._mag])
	_check("a bot nearer than 2 m hits instead of firing, and two blows bring the other down", victim.deaths == deaths + 1 and hitter.brain._mag == rounds
		and healths.size() >= 2 and is_equal_approx(float(healths[1]), Match.MAX_HEALTH - 60.0))
	_check("and its figure is seen to strike", struck[0])
	Match.close()


## Adds a rocket that has appeared since the last look to `rockets`: where it
## was first seen, how fast it went and how far `from` was from `at` then.
func _note_rockets(rockets: Array, from: Node3D, at: Node3D) -> void:
	for rocket: Node3D in get_tree().get_nodes_in_group("rocket"):
		if not rocket.has_meta(&"noted"):
			rocket.set_meta(&"noted", true)
			rockets.append([rocket.global_position, rocket.velocity, from.global_position.distance_to(at.global_position)])


## Two spots of the arena about `metres` apart, on one floor, that see each
## other with nothing in between; empty if there are none.
func _facing_spots(metres: float) -> Array[Vector3]:
	var arena: RefCounted = Match.arena
	var space: PhysicsDirectSpaceState3D = get_tree().current_scene.get_world_3d().direct_space_state
	for i in range(0, arena.spots.size(), 3):
		var a: Vector3 = arena.spots[i]
		for j in arena.spots.size():
			var b: Vector3 = arena.spots[j]
			if absf(a.distance_to(b) - metres) > 1.0 or absf(a.y - b.y) > 0.3:
				continue
			var clear := true
			for height: float in [0.2, 1.0, 1.6]:
				if not space.intersect_ray(PhysicsRayQueryParameters3D.create(a + Vector3.UP * height, b + Vector3.UP * height, 1)).is_empty():
					clear = false
			if clear:
				return [a, b]
	return []


## True if `text` is the line that says who took a weapon of the arena, not
## a prize.
func _of_the_arena(text: String) -> bool:
	return Match.SPECIALS.any(func(weapon: String) -> bool: return text.ends_with(weapon.replace("_", " ")))


## With --pack=<name> and no --match= of its own: a match of bots only with
## that pack, team deathmatch in the arena --arena=<level> (the works unless
## said otherwise), as many a side as play there, for --seconds=<seconds> of
## match (300) at four times the clock. It counts the kills by weapon, next to
## how many bots carry each: a weapon that takes more than twice its share of
## the kills is one to look at. Bots play otherwise than people do, but an
## outlier shows.
func _pack_kills(pack: String) -> void:
	var tree := get_tree()
	var level := "works"
	var seconds := 300.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--arena="):
			level = arg.get_slice("=", 1)
		elif arg.begins_with("--seconds="):
			seconds = arg.get_slice("=", 1).to_float()
	var armory: GDScript = load("res://scripts/armory.gd")
	if not armory.names().has(pack):
		print("MATCH PACK FAILED: no pack called %s; there are %s" % [pack, ", ".join(armory.names())])
		return
	Settings.enemy_theme = "soldiers"
	if not Match.open({"mode": "tdm", "level": level, "only_bots": true, "pack": pack}):
		print("MATCH PACK FAILED: no arena called %s" % level)
		return
	await tree.scene_changed
	await _until(func() -> bool: return Match.state == Match.State.PLAYING, 90.0)
	if Match.state != Match.State.PLAYING:
		print("MATCH PACK FAILED: the match did not begin")
		return
	Match.mode.numbers = Match.mode.numbers.duplicate()
	Match.mode.numbers.limit = 100000
	Match.left = seconds + 60.0
	var counted := _count_kills()
	var began := Time.get_ticks_msec()
	Engine.time_scale = 4.0
	var clock := 0.0
	while clock < seconds:
		await _wait(0.5)
		clock += 0.5
	Engine.time_scale = 1.0
	print("  %s in the %s, %d a side, %.0f s of match in %.0f s" % [armory.title(pack), level, Match.setup.size, seconds, (Time.get_ticks_msec() - began) / 1000.0])
	var suspects := _print_kills(counted[0])
	print("  %s" % _taken())
	print("MATCH PACK %s: %s" % [pack, "no weapon takes more than twice its share of the kills" if suspects.is_empty() else "; ".join(suspects)])
	Match.close()


## Counts every kill of the match by what it was done with, from now on: the
## first of what this gives is the count, by the place of the weapon in the
## armory, or Match.MELEE or BLAST.
func _count_kills() -> Array:
	var kills := {}
	Match.felled.connect(func(by: int, _fallen: int, weapon: int, _head: bool) -> void:
		if by != 0:
			kills[weapon] = int(kills.get(weapon, 0)) + 1)
	return [kills]


## Prints `kills` by weapon, next to how many bots carry each, and gives back
## what is suspect: a weapon of the bots with more than twice its share.
func _print_kills(kills: Dictionary) -> PackedStringArray:
	var armory: GDScript = load("res://scripts/armory.gd")
	var carried := {}
	var bots := 0
	for who: RefCounted in Match.entrants.values():
		if who.bot:
			bots += 1
			var own: int = armory.index(who.brain._own) if who.brain else who.weapon
			carried[own] = int(carried.get(own, 0)) + 1
	var total := 0
	for weapon: int in kills:
		total += int(kills[weapon])
	print("  %d kills: by weapon, the kills, their share and the share of the bots that carry it" % total)
	var suspects := PackedStringArray()
	var weapons := carried.keys()
	for weapon: int in kills:
		if not weapons.has(weapon):
			weapons.append(weapon)
	for weapon: int in weapons:
		var title: String = "blows" if weapon == Match.MELEE else "blasts" if weapon == Match.BLAST else armory.at(weapon).display_name if weapon >= 0 else "something else"
		var share := float(kills.get(weapon, 0)) / maxi(total, 1)
		var bearers := float(carried.get(weapon, 0)) / maxi(bots, 1)
		print("    %-18s %4d   %3.0f%%   %s" % [title, int(kills.get(weapon, 0)), share * 100.0, "%3.0f%% of the bots" % (bearers * 100.0) if carried.has(weapon) else "from the arena or no weapon"])
		if carried.has(weapon) and share > bearers * 2.0 and total >= 20:
			suspects.append("%s takes %.1f times its share" % [title, share / bearers])
	return suspects


## How often the weapons of the arena were taken up in the match, and by whom.
func _taken() -> String:
	if Match.takes.is_empty():
		return "nobody took a weapon of the arena"
	var by := {}
	for take: Dictionary in Match.takes:
		var line: Array = by.get(take.weapon, [])
		line.append("%s%s at %d:%02d" % [take.by, "" if take.bot else " (a person)", floori(float(take.at) / 60.0), int(take.at) % 60])
		by[take.weapon] = line
	var parts := PackedStringArray()
	for weapon: String in by:
		parts.append("the %s %d times, by %s" % [weapon.replace("_", " "), (by[weapon] as Array).size(), ", ".join(by[weapon])])
	return "the weapons of the arena were taken up %d times: %s" % [Match.takes.size(), "; ".join(parts)]


func _middle_of(values: Array) -> float:
	if values.is_empty():
		return INF
	var sorted := values.duplicate()
	sorted.sort()
	@warning_ignore("integer_division")
	return sorted[sorted.size() / 2]


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


## The buttons the menu shows right now, also those in a list that scrolls,
## and not those of the screen it showed before, which are only taken away
## at the end of the frame.
func _shown_buttons() -> Array:
	return Menu._column.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return not button.is_queued_for_deletion() and not button.get_parent().is_queued_for_deletion())
