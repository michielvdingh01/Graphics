extends Node
## Headless gameplay smoke test. Run with: tools/selftest.sh
##
## Drives the real player through simulated input and checks that the core
## loop still works: navmesh, slide, shooting, enemy AI, weapon switching,
## enemy types, explosives, grenades and settings. Then it goes through every
## level along its route, from the start to the exit and on into the next:
## that the route can be walked over the navmesh, that every robot can reach
## the player from its post and none stands close by and in view where the
## player appears or walks into its zone, that the robots a zone lists wait
## at their posts until its fight starts, that a checkpoint is still there
## after a restart of the game and after a death, and that the door at the
## exit is shut until the level is cleared. Where a level is cut into zones
## that are only drawn when they can be seen, it looks for lines of sight
## into a zone from where that zone is switched off.

## Spots in the factory level: on the mezzanine deck, an open lane with 6 m
## of clear floor to the east of it, and a stretch of floor to sprint along.
const MEZZANINE := Vector3(-10, 3.2, -9.5)
const RANGE_TARGET := Vector3(1, 0, -7.5)
const RUNWAY := Vector3(17.5, 0, 5.5)
## Where the player stands in the hall for the fights that are tried out:
## open floor, with crates and machines to the west of it.
const FIGHT_STAND := Vector3(12, 0, 4)
## A robot may stand in sight of where the player walks into its zone, starts
## the level or carries on from a checkpoint, but not closer than this.
const SPAWN_DISTANCE := 14.0
## Distance in metres between the points a route is sampled at.
const STRIDE := 0.5
## To see whether one zone can be seen from another: how many spots to look
## from at most, and how far apart the points are that are looked at.
const LOOKOUTS := 150
const SIGHT_GRID := 1.5

## True for a self-test run; menus and saved progress stay out of the way.
var active := false

var _failures := 0
var _routes_only := false
## The parts of the test that ran to their end. A script error ends the part
## it happens in without a word, and what was never checked has not passed.
var _finished: Array[String] = []


func _ready() -> void:
	active = "--selftest" in OS.get_cmdline_user_args()
	if active:
		_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	# A script error would otherwise leave the run hanging forever.
	tree.create_timer(300.0, true, true).timeout.connect(
		func() -> void:
			print("SELFTEST FAILED (timed out)")
			tree.quit(1)
	)
	await _wait(0.5)
	# --routes leaves out everything but the levels and their routes, and
	# lists every spawn point: for working on a level.
	_routes_only = "--routes" in OS.get_cmdline_user_args()
	# --fights leaves out everything but what the enemies do in a fight.
	var fights_only := "--fights" in OS.get_cmdline_user_args()
	if fights_only:
		await _fights()
		await _supplies()
		_ran(["fights", "supplies"])
		print("SELFTEST %s" % ("PASSED" if _failures == 0 else "FAILED (%d)" % _failures))
		tree.quit(1 if _failures else 0)
		return
	if not _routes_only:
		await _handling()
		await _fights()
		await _supplies()
		_ran(["handling", "fights", "supplies"])

	# Every level, in the order they are played, each entered the way the
	# game enters it: the first from the menu, the rest through an exit.
	Save.clear()
	tree.change_scene_to_file(Menu.LEVELS[0].scene)
	await tree.scene_changed
	for i in Menu.LEVELS.size():
		await _wait(0.5)
		await _play_through(Menu.LEVELS[i], Menu.LEVELS[i + 1].scene if i + 1 < Menu.LEVELS.size() else "")
	_ran(Menu.LEVELS.map(func(level: Dictionary) -> String: return level.name))

	print("SELFTEST %s" % ("PASSED" if _failures == 0 else "FAILED (%d)" % _failures))
	tree.quit(1 if _failures else 0)


## How the game handles, tried out in the factory: moving, shooting, the
## robots, what explodes and the settings.
func _handling() -> void:
	var tree := get_tree()
	var game := tree.current_scene
	var player: CharacterBody3D = game.player
	var weapons: Node3D = player.weapons
	player.force_control = true
	# Health regenerates, so count hits instead of comparing health later.
	var hits := [0]
	player.damaged.connect(func(_amount: float) -> void: hits[0] += 1)

	var navmesh: NavigationMesh = game.nav_region.navigation_mesh
	_check("navmesh is baked", navmesh.get_polygon_count() > 0)
	_check("the level starts quiet, with the player at its start", _all_posted(game)
		and not game.fighting() and player.global_position.distance_to(game.start.origin) < 0.5)
	var first: RefCounted = game.zones[0]
	_check("the HUD is told where to go", game.objective == "Reach %s" % first.title)

	var map := player.get_world_3d().navigation_map
	var top := NavigationServer3D.map_get_path(map, MEZZANINE, player.global_position, true)
	_check("mezzanine connects via stairs", top.size() > 1 and top[0].y > 2.5 and top[-1].distance_to(player.global_position) < 1.0)

	# The part that tests how things handle goes all over the hall; only the
	# first zone is left to notice, and only its robots are left standing.
	for zone: RefCounted in game.zones:
		zone.area.set_deferred("monitoring", zone == first)
		if zone != first:
			for robot: Node3D in zone.robots:
				robot.queue_free()
	await _wait(0.1)

	# Sprint, then slide.
	player.global_position = RUNWAY
	player.rotation.y = PI * 0.5
	await _wait(0.2)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _wait(0.6)
	_check("sprint reaches sprint speed", player.velocity.length() > 7.0)
	Input.action_press("crouch")
	await _wait(0.1)
	_check("crouch while sprinting slides", player.is_sliding() and player.velocity.length() > 9.0)
	await _wait(1.5)
	_check("slide decays into crouch", not player.is_sliding() and player.is_crouched())
	for action in ["crouch", "sprint", "move_forward"]:
		Input.action_release(action)
	await _wait(0.2)
	_check("stands up again", not player.is_crouched())

	# A fight: walking into a zone switches on the robots it lists, and no others.
	var entries := _entries(game, _walk(game))
	_move(player, entries.get(first.id, Vector3.ZERO))
	await _wait(0.3)
	var enemies := tree.get_nodes_in_group("enemy")
	_check("walking into a zone starts its fight", first.fighting() and game.objective == "Clear %s" % first.title)
	_check("with the robots that zone lists", not enemies.is_empty() and _kinds(enemies) == _roster(game, first)
		and enemies.all(func(e: Node) -> bool: return e.can_process()))
	var path := NavigationServer3D.map_get_path(map, enemies[0].global_position, player.global_position, true)
	_check("enemy can path to player", path.size() > 1)

	# Enemy AI: they should come looking for the player, wherever they
	# appeared, close in and deal damage. The player stands still from here on.
	var enemy: CharacterBody3D = enemies[0]
	player.health = 1e6
	var start_distances := {}
	for e in enemies:
		start_distances[e] = e.global_position.distance_to(player.global_position)
	var approached := false
	for i in 40:
		approached = approached or enemies.any(
			func(e: Node3D) -> bool:
				return e.global_position.distance_to(player.global_position) < start_distances[e] - 3.0
		)
		if approached and hits[0] > 0:
			break
		await _wait(0.5)
	_check("enemies approach", approached)
	_check("enemies damage the player", hits[0] > 0)

	# Shooting: face the enemy from close range and hold the trigger.
	for other in enemies:
		other.set_physics_process(false)
	enemy.global_position = RANGE_TARGET
	enemy.velocity = Vector3.ZERO
	player.global_position = RANGE_TARGET + Vector3(6, 0, 0)
	player.velocity = Vector3.ZERO
	player.look_at(Vector3(enemy.global_position.x, player.global_position.y, enemy.global_position.z))
	player.head.rotation.x = 0.0
	await _wait(0.3)
	Input.action_press("fire")
	await _wait(0.25)
	_check("rifle uses ammo", weapons._mags[0] < 30)
	_check("rifle damages enemy", enemy.health < enemy.max_health)
	_check("recoil kicks the camera", player.camera.rotation.x > 0.005)
	await _wait(1.5)
	Input.action_release("fire")
	_check("enemy dies", enemy.dead and game.kills == 1)

	Input.action_press("reload")
	await _wait(0.1)
	Input.action_release("reload")
	_check("reload starts", weapons.reload_fraction() > 0.0)
	await _wait(2.0)
	_check("reload fills the magazine", weapons._mags[0] == 30)

	# Weapon keys are read in _unhandled_input, which needs a real event.
	var key := InputEventAction.new()
	key.action = "weapon_3"
	key.pressed = true
	Input.parse_input_event(key)
	await _wait(0.5)
	_check("switches to shotgun", weapons.current().display_name == "Shotgun")
	# One shot, then a reload: the shell goes in before the reload is over.
	Input.action_press("fire")
	await _wait(0.05)
	Input.action_release("fire")
	await _wait(0.8)
	var after_shot: int = weapons._mags[2]
	Input.action_press("reload")
	await _wait(0.1)
	Input.action_release("reload")
	await _wait(0.75)
	_check("shotgun loads shell by shell", after_shot == 5 and weapons._mags[2] == 6 and weapons.reload_fraction() > 0.0)
	await _wait(0.5)
	Input.action_press("ads")
	await _wait(0.4)
	_check("aiming zooms the camera", weapons.ads_blend == 1.0 and player.camera.fov < 70.0)
	Input.action_release("ads")
	key = key.duplicate()
	key.action = "weapon_5"
	Input.parse_input_event(key)
	await _wait(0.5)
	_check("switches to marksman", weapons.current().display_name == "Marksman")
	Input.action_press("ads")
	await _wait(0.6)
	_check("scope takes over from the weapon in view", weapons.scope_blend() == 1.0 and not weapons._models[4].root.visible)
	Input.action_release("ads")

	# Enemy types.
	var rusher: CharacterBody3D = game.RUSHER.instantiate()
	rusher.position = player.global_position + Vector3(-5, 0, 1.5)
	game.add_child(rusher)
	var hits_before: int = hits[0]
	await _wait(3.0)
	_check("rusher closes in and strikes", hits[0] > hits_before
		and rusher.global_position.distance_to(player.global_position) < 2.5)
	var heavy: CharacterBody3D = game.HEAVY.instantiate()
	_check("heavy outlasts a grunt", heavy.max_health > 200.0)
	heavy.free()

	# Explosives: a barrel in the open lane with a robot beside it and a
	# second barrel a little further on. Shooting the first should set it
	# alight, then off; its blast should wreck the robot and take the second
	# barrel with it.
	rusher.queue_free()
	var blasts := [0]
	Blast.exploded.connect(func(_at: Vector3) -> void: blasts[0] += 1)
	var barrels: Array[StaticBody3D] = []
	for offset: Vector3 in [Vector3.ZERO, Vector3(-1.6, 0, 0)]:
		var barrel := StaticBody3D.new()
		barrel.set_script(preload("res://scripts/explosive.gd"))
		barrel.collision_layer = 0b10001
		var collider := CollisionShape3D.new()
		collider.shape = CylinderShape3D.new()
		collider.shape.radius = 0.3
		collider.shape.height = 0.9
		collider.position.y = 0.45
		barrel.add_child(collider)
		barrel.position = RANGE_TARGET + offset
		game.add_child(barrel)
		barrels.append(barrel)
	var bystander: CharacterBody3D = game.GRUNT.instantiate()
	bystander.position = RANGE_TARGET + Vector3(0, 0, 1.7)
	game.add_child(bystander)
	bystander.set_physics_process(false)
	key = key.duplicate()
	key.action = "weapon_1"
	Input.parse_input_event(key)
	player.global_position = RANGE_TARGET + Vector3(6, 0, 0)
	player.velocity = Vector3.ZERO
	player.look_at(Vector3(RANGE_TARGET.x, player.global_position.y, RANGE_TARGET.z))
	player.head.rotation.x = -atan2(1.15, 6.0)
	await _wait(0.6)
	Input.action_press("fire")
	await _wait(0.16)
	Input.action_release("fire")
	_check("two hits set a barrel alight", is_instance_valid(barrels[0]) and barrels[0].is_alight() and blasts[0] == 0)
	Input.action_press("fire")
	await _wait(0.5)
	Input.action_release("fire")
	_check("more set it off", not is_instance_valid(barrels[0]) and blasts[0] >= 1)
	_check("the blast wrecks the robot beside it", bystander.dead)
	await _wait(0.5)
	_check("and takes the next barrel with it", not is_instance_valid(barrels[1]) and blasts[0] == 2)

	# A grenade: thrown, it lands in the lane and goes off by itself.
	player.head.rotation.x = 0.0
	await _wait(4.0)
	Input.action_press("grenade")
	await _wait(0.1)
	Input.action_release("grenade")
	await _wait(0.5)
	var thrown := tree.get_nodes_in_group("grenade")
	_check("a grenade is thrown", weapons.grenades == weapons.START_GRENADES - 1 and thrown.size() == 1)
	if not thrown.is_empty():
		_check("it flies ahead of the player", thrown[0].global_position.x < player.global_position.x - 2.0)
	await _wait(2.4)
	_check("and goes off", blasts[0] == 3 and tree.get_nodes_in_group("grenade").is_empty())

	# Settings.
	var environment: Environment = game.get_viewport().find_world_3d().environment
	Settings.put("quality", 0)
	_check("low quality switches effects off", not environment.ssr_enabled and not environment.volumetric_fog_enabled)
	Settings.put("quality", 2)
	_check("high quality restores them", environment.ssr_enabled and environment.volumetric_fog_enabled)
	Settings.put("upscaler", Viewport.SCALING_3D_MODE_FSR2)
	Settings.put("render_scale", 0.67)
	_check("upscaler applies to the viewport", game.get_viewport().scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2
		and is_equal_approx(game.get_viewport().scaling_3d_scale, 0.67))

	# A sound is found by its name, and that of an impact by what was hit, so a
	# folder that is missing would only show up as an error in mid-fight.
	var sounds: Array[StringName] = []
	for data: WeaponData in weapons.LOADOUT:
		sounds.append(data.shot_sound)
	for surface: String in Fx.HOLE_VARIANTS:
		sounds.append(StringName("impact_" + surface))
	_check("every weapon and every surface has its sound", sounds.all(Sfx.has))
	# Without the bus layout everything would still play, dry and unlimited.
	var world := AudioServer.get_bus_index(Sfx.WORLD)
	_check("the world has its own bus, with effects on it", world > 0 and AudioServer.get_bus_effect_count(world) > 0)
	# A click with Ctrl held, as macOS hands it on: a shot, not the sights.
	if OS.get_name() == "macOS":
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_RIGHT
		click.ctrl_pressed = true
		click.pressed = true
		Input.parse_input_event(click)
		await _wait(0.1)
		_check("a click with Ctrl held fires instead of aiming", Input.is_action_pressed("fire") and not Input.is_action_pressed("ads"))
		click = click.duplicate()
		click.pressed = false
		Input.parse_input_event(click)
		await _wait(0.1)
		_check("and stops firing when it is let go", not Input.is_action_pressed("fire"))

	# Music: a piece plays on its own bus, which its own slider turns down,
	# and one there is no file for is silence and no error.
	var piece := AudioStreamWAV.new()
	piece.format = AudioStreamWAV.FORMAT_16_BITS
	piece.data = PackedByteArray()
	piece.data.resize(44100)
	Sfx._start_music(&"test", piece)
	var music_bus := AudioServer.get_bus_index(Sfx.MUSIC)
	_check("music plays on its own bus", music_bus > 0 and Sfx._music.playing and Sfx._music.bus == Sfx.MUSIC and Sfx.music_playing() == &"test")
	Settings.put("music", 0.5)
	_check("and has a slider of its own", is_equal_approx(AudioServer.get_bus_volume_db(music_bus), linear_to_db(0.5)))
	# From the title screen into a level the menu asks for the level's piece
	# twice in a row, which once left the theme playing.
	Sfx.music(Menu.THEME, 0.0)
	Sfx.music(&"level1and2", 0.1, Menu.LEVEL_MUSIC_DB)
	Sfx.music(&"level1and2", 0.1, Menu.LEVEL_MUSIC_DB)
	await _wait(Sfx.CHANGE_TIME + 0.6)
	_check("the theme makes way for the music of the level", Sfx._music.playing and Sfx._music.stream.resource_path.contains("level1and2")
		and absf(Sfx._music.volume_db - Menu.LEVEL_MUSIC_DB) < 0.5)
	Sfx.music(&"a piece nobody has written", 0.1)
	await _wait(0.5)
	_check("a piece there is no file for is silence", not Sfx._music.playing and Sfx.music_playing() == &"")
	_finished.append("handling")


## What the enemies do in a fight, tried out in the hall of the factory.
func _fights() -> void:
	var tree := get_tree()
	var game := tree.current_scene
	var player: CharacterBody3D = game.player
	player.force_control = true
	player.health = 1e6
	# Nothing else in the level takes part.
	for zone: RefCounted in game.zones:
		zone.area.set_deferred("monitoring", false)
	for enemy in tree.get_nodes_in_group("enemy"):
		enemy.queue_free()
	await _wait(0.3)
	if "--map" in OS.get_cmdline_user_args():
		_print_cover(player)
	var space := player.get_world_3d().direct_space_state
	var weapons: Node3D = player.weapons
	var rules: Dictionary = Settings.rules()
	_move(player, FIGHT_STAND)
	player.rotation.y = PI * 0.5
	await _wait(0.2)
	var eye: Vector3 = player.head.global_position

	# Cover: a grunt that knows of the player runs for a spot where it cannot
	# be seen, comes out of it to shoot and goes back.
	var grunt: CharacterBody3D = game.GRUNT.instantiate()
	grunt.position = FIGHT_STAND + Vector3(-11, 0, 0)
	game.add_child(grunt)
	grunt.alert()
	var settled := 0
	var hid := 0.0
	var hidden := false
	var shot_from := Vector3.ZERO
	var went_back := false
	var modes := ""
	for i in 400:
		await _wait(0.05)
		var mode: int = grunt._mode
		if modes.is_empty() or modes[-1] != str(mode):
			modes += str(mode)
		if "--trace" in OS.get_cmdline_user_args() and i % 4 == 0:
			print("      %.1f mode %d at %s cover %s fire %s los %s attack %d timer %.2f turn %s faces %s" % [i * 0.05, mode, grunt.global_position.snappedf(0.1),
				(grunt._cover.get("at", Vector3.ZERO) as Vector3).snappedf(0.1), (grunt._cover.get("fire", Vector3.ZERO) as Vector3).snappedf(0.1),
				grunt._has_los, grunt._attack, grunt._attack_timer, Squad._turns.has(grunt), grunt._faces(eye, 0.7)])
		# It is nobody's turn until it has been seen to hide, so that it has
		# to wait where it hides.
		if hid == 0.0:
			Squad._rests.assign(range(rules.attackers).map(func(_n: int) -> float: return 0.5))
		settled = settled + 1 if mode == grunt.Mode.COVER and grunt._flat(grunt._cover.at) < 0.4 else 0
		if settled == 10 and hid == 0.0:
			hid = i * 0.05
			# From the top of its head down, ducked or standing as it is.
			var top: Vector3 = grunt.global_position + Vector3.UP * (grunt._eyes() + 0.2)
			hidden = not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, top, 1)).is_empty() \
				and not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, top - Vector3.UP * 0.5, 1)).is_empty()
			if "--trace" in OS.get_cmdline_user_args():
				var c: Dictionary = grunt._cover
				print("      settled: at %s cover %s crouch %s crouched %s eyes %.2f los %s exposed %.2f; eye %s" % [grunt.global_position, c.at, c.crouch, grunt._crouched, grunt._eyes(), grunt._has_los, grunt._exposed, eye])
				for h: float in [0.2, 0.41, 0.6, 0.82, 1.04, 1.3, 1.5, 1.7]:
					var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, (c.at as Vector3) + Vector3.UP * h, 1))
					var hit2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, grunt.global_position + Vector3.UP * h, 1))
					print("        %.2f: to the spot %s, to the grunt %s" % [h, hit.position if hit else "open", hit2.position if hit2 else "open"])
		if grunt._attack == grunt.Attack.BURST and mode == grunt.Mode.PEEK and shot_from == Vector3.ZERO:
			shot_from = grunt.global_position
		if shot_from != Vector3.ZERO and mode == grunt.Mode.COVER and grunt._attack == grunt.Attack.COOLDOWN:
			went_back = true
			break
	print("    a grunt is in cover after %.1f s, behind something %s; modes %s" % [hid, "low" if grunt._cover.get("crouch", false) else "high", modes])
	_check("the hall has cover", Squad._spots.size() > 100)
	_check("a grunt runs for cover and cannot be seen there", hid > 0.0 and hidden)
	_check("it comes out to shoot when it is its turn", shot_from != Vector3.ZERO)
	_check("and goes back", went_back)

	# Turns: of a group, only so many attack at the same moment.
	var squad: Array[CharacterBody3D] = [grunt]
	for offset: Vector3 in [Vector3(-9, 0, 3), Vector3(-8, 0, -3), Vector3(-12, 0, -2), Vector3(-10, 0, 5)]:
		var one: CharacterBody3D = game.GRUNT.instantiate()
		one.position = FIGHT_STAND + offset
		game.add_child(one)
		one.alert()
		squad.append(one)
	var most := 0
	var bursts := 0
	var in_cover := 0
	var was_attacking := {}
	var looks: Array[float] = []
	Squad.timed = looks
	for i in 240:
		await _wait(0.05)
		var now := 0
		for one in squad:
			var attacking: bool = one._attack != one.Attack.COOLDOWN
			if attacking and not was_attacking.get(one, false):
				bursts += 1
			was_attacking[one] = attacking
			now += int(attacking)
		most = maxi(most, now)
		if i == 239:
			in_cover = squad.filter(func(one: CharacterBody3D) -> bool: return one._mode != one.Mode.HUNT).size()
	print("    five grunts: %d attacks in 12 s, at most %d at once, %d of them fighting from cover" % [bursts, most, in_cover])
	Squad.timed = null
	looks.sort()
	if not looks.is_empty():
		print("    they looked for cover %d times in 12 s: %.2f ms each at the median, %.2f ms at worst" % [looks.size(), looks[looks.size() >> 1], looks[-1]])
	_check("a group attacks by turns: never more than %d at once" % rules.attackers, most <= rules.attackers and bursts >= 3)
	_check("and most of it fights from cover", in_cover >= 3)
	var round_it := 0
	for i in 40:
		for one in squad:
			round_it += int(Squad.goes_round(one))
		if round_it > 0:
			break
	_check("one of a group goes round the player, and no more", Squad._flankers.size() == rules.flankers)

	# Danger: a grenade at its feet sends a grunt running.
	for one in squad:
		if one != grunt:
			one.queue_free()
	await _wait(0.2)
	var before: float = grunt.health
	var grenade: RigidBody3D = weapons.GRENADE.instantiate()
	game.add_child(grenade)
	grenade.global_position = grunt.global_position + Vector3(0.6, 0.2, 0.6)
	var lay := grenade.global_position
	var fled := false
	for i in 50:
		await _wait(0.05)
		fled = fled or grunt._mode == grunt.Mode.FLEE
		if not is_instance_valid(grenade):
			break
		lay = grenade.global_position
	var got_away: float = grunt.global_position.distance_to(lay)
	print("    a grenade at its feet: it gets %.1f m away and loses %.0f of %.0f health" % [got_away, before - grunt.health, grunt.max_health])
	# Out of its reach, or behind something that stands between them.
	_check("a grunt runs from a grenade", fled and not grunt.dead and (got_away > 4.0 or before - grunt.health < 50.0))
	# And fire: it does not stay standing in it.
	await _wait(1.0)
	Blast.burn(grunt.global_position, 1.3, 4.0)
	var patch := grunt.global_position
	await _wait(1.2)
	_check("and gets out of a fire", grunt.dead or not Blast.burning(grunt.global_position) or grunt.global_position.distance_to(patch) > 1.0)
	grunt.queue_free()
	await _wait(4.0)

	# The plate on a grunt's arm.
	var guard: CharacterBody3D = game.GRUNT.instantiate()
	guard.set_meta(&"plate", true)
	guard.position = FIGHT_STAND + Vector3(-6, 0, 0)
	guard.rotation.y = -PI * 0.5
	game.add_child(guard)
	guard.set_physics_process(false)
	var ahead: Vector3 = guard.global_basis.z
	var chest: Vector3 = guard.global_position + Vector3.UP * 1.1
	guard.take_damage(10.0, chest, ahead)
	_check("the first shot at a grunt that has not seen it coming goes home", guard.health == guard.max_health - 10.0 and not guard.deflected)
	guard.take_damage(10.0, chest, ahead)
	_check("after that its plate stops a shot from the front", guard.health == guard.max_health - 10.0 and guard.deflected)
	guard.take_damage(10.0, guard.global_position + Vector3.UP * 1.6, ahead)
	guard.take_damage(10.0, guard.global_position + Vector3.UP * 0.4, ahead)
	guard.take_damage(10.0, chest, -ahead)
	_check("but not one at its head, its legs or its back", guard.health == guard.max_health - 40.0 and not guard.deflected)
	guard.take_blast(10.0, chest, ahead)
	_check("nor an explosion", guard.health == guard.max_health - 50.0)
	# With the rifle, from the front: a stopped shot is no hit.
	var marks := [0]
	var count_mark := func(_headshot: bool, _killed: bool) -> void: marks[0] += 1
	weapons.hit_confirmed.connect(count_mark)
	_move(player, FIGHT_STAND)
	player.look_at(Vector3(guard.global_position.x, player.global_position.y, guard.global_position.z))
	player.head.rotation.x = atan2(1.1 - 1.6, 6.0)
	await _wait(0.3)
	Input.action_press("fire")
	await _wait(0.12)
	Input.action_release("fire")
	await _wait(0.1)
	_check("a shot the plate stops shows no hit marker", marks[0] == 0 and guard._shield < guard.shield and guard.health == guard.max_health - 50.0)
	Input.action_press("fire")
	await _wait(0.6)
	Input.action_release("fire")
	weapons.hit_confirmed.disconnect(count_mark)
	_check("enough shots take the plate off its arm, and then it is hurt", not guard._rig.has_shield and guard._shield <= 0.0 and marks[0] > 0)
	guard.queue_free()

	# The pack on a heavy's back.
	var blasts := [0]
	var count_blast := func(_at: Vector3) -> void: blasts[0] += 1
	Blast.exploded.connect(count_blast)
	var heavy: CharacterBody3D = game.HEAVY.instantiate()
	heavy.position = FIGHT_STAND + Vector3(-6, 0, 0)
	heavy.rotation.y = -PI * 0.5
	heavy.speed = 0.0
	game.add_child(heavy)
	var bystander: CharacterBody3D = game.GRUNT.instantiate()
	bystander.position = heavy.position + Vector3(-2.2, 0, 0)
	game.add_child(bystander)
	bystander.set_physics_process(false)
	var back: Vector3 = heavy.global_position + heavy.global_basis.z * 0.4 + Vector3.UP * 1.55
	heavy.take_damage(30.0, heavy.global_position + Vector3.UP * 1.3, heavy.global_basis.z)
	_check("a heavy shot from the front is hurt and no more", heavy.health == heavy.max_health - 30.0 and heavy.danger().is_empty())
	_check("a heavy stands its ground and turns slowly", not heavy.takes_cover and not heavy.heeds_danger and heavy.turn_speed < 4.0)
	heavy.take_damage(30.0, back, -heavy.global_basis.z)
	heavy.take_damage(30.0, back, -heavy.global_basis.z)
	_check("shots in the pack on its back hurt more and set it alight", heavy.health < heavy.max_health - 90.0
		and not heavy.dead and not heavy.danger().is_empty() and blasts[0] == 0)
	await _wait(heavy.PACK_FUSE + 0.4)
	_check("then it goes off, and takes the heavy and the grunt beside it along", blasts[0] == 1 and heavy.dead and bystander.dead)
	Blast.exploded.disconnect(count_blast)
	await _wait(0.5)
	_finished.append("fights")


## What there is to live on: health that only comes back so far, a reserve
## that runs out, what the enemies leave behind and what a run is measured by.
func _supplies() -> void:
	var tree := get_tree()
	var game := tree.current_scene
	var player: CharacterBody3D = game.player
	var weapons: Node3D = player.weapons
	var rules: Dictionary = Settings.rules()
	for enemy in tree.get_nodes_in_group("enemy"):
		enemy.queue_free()
	_move(player, FIGHT_STAND)
	await _wait(0.2)

	# Health comes back by itself, but not all of it.
	player.health = 10.0
	player._since_damage = player.REGEN_DELAY
	await _wait(3.0)
	_check("health comes back by itself up to %d and no further" % rules.regen_to, is_equal_approx(player.health, rules.regen_to))
	_check("the HUD marks how far, and shows the health as a number", game.get_node("HUD")._health_label.text == str(int(rules.regen_to))
		and game.get_node("HUD")._regen_mark.position.x > 60.0)

	# The reserve: less than it can hold to begin with, none at all for the
	# pistol to run out of.
	var key := InputEventAction.new()
	key.pressed = true
	key.action = "weapon_2"
	Input.parse_input_event(key)
	await _wait(0.5)
	weapons._mags[1] = 3
	Input.action_press("reload")
	await _wait(0.1)
	Input.action_release("reload")
	await _wait(2.2)
	_check("the pistol never runs out of reserve", weapons.current().display_name == "Pistol" and weapons._mags[1] == 12
		and weapons.ammo_lack() == 0.0)
	key = key.duplicate()
	key.action = "weapon_1"
	Input.parse_input_event(key)
	await _wait(0.5)
	var rifle: WeaponData = weapons.LOADOUT[0]
	weapons.resupply()
	_check("a level starts with part of the reserve a weapon can hold", weapons._start_reserve(rifle) == rifle.mag_size * weapons.START_MAGS
		and weapons._start_reserve(rifle) < rifle.reserve_ammo and weapons._reserves[0] >= weapons._start_reserve(rifle))

	# What the enemies leave behind follows what the player lacks: hurt and
	# with an empty reserve, three kills from close by leave cells and cans.
	weapons._reserves[0] = 0
	weapons.grenades = 0
	game._due.fill(0.0)
	var notes: Array[String] = []
	var note := func(text: String, _tint: Color) -> void: notes.append(text)
	game.picked_up.connect(note)
	for i in 3:
		var one: CharacterBody3D = game.GRUNT.instantiate()
		one.position = FIGHT_STAND + Vector3(-5.0, 0, i * 1.5 - 1.5)
		game.add_child(one)
		one.set_physics_process(false)
		one.died.connect(game._leave_behind)
		one.take_damage(1e6, one.global_position + Vector3.UP * 1.6, Vector3.DOWN)
	await _wait(0.8)
	var lying := tree.get_nodes_in_group("pickup")
	var cells := lying.filter(func(p: Node) -> bool: return p.kind == p.Kind.HEALTH)
	var cans := lying.filter(func(p: Node) -> bool: return p.kind == p.Kind.AMMO)
	print("    three kills, hurt and out of rifle rounds: %d cells, %d cans, %d grenades" % [cells.size(), cans.size(), lying.size() - cells.size() - cans.size()])
	_check("kills leave cells for somebody who is hurt", cells.size() >= 2)
	_check("and cans for somebody whose reserve is gone", cans.size() >= 2)
	# One of each by itself, a step in front of the player.
	for pickup in lying:
		pickup.free()
	var drop := func(kind: int) -> Node3D:
		return game.leave(kind, player.global_position + Vector3(-1.2, 0.9, 0))
	var cell: Node3D = drop.call(game.PICKUP.Kind.HEALTH)
	var mended: float = player.health + cell.HEALTH
	await _wait(1.2)
	_check("walking up to a cell mends", is_equal_approx(player.health, mended) and not is_instance_valid(cell) and notes.has("+25 HEALTH"))
	var can: Node3D = drop.call(game.PICKUP.Kind.AMMO)
	await _wait(1.2)
	_check("and a can fills the reserve, most of all that of the weapon in hand", not is_instance_valid(can) and notes.has("+AMMO")
		and weapons._reserves[0] == rifle.mag_size
		and weapons._reserves[2] == weapons._start_reserve(weapons.LOADOUT[2]) + ceili(weapons.LOADOUT[2].mag_size * weapons.CAN_MAGS_OTHERS))
	var grenade: Node3D = drop.call(game.PICKUP.Kind.GRENADE)
	await _wait(1.2)
	_check("and a grenade is one more to throw", not is_instance_valid(grenade) and weapons.grenades == 1)
	# What there is no use for is left lying.
	player.health = player.MAX_HEALTH
	var spare: Node3D = drop.call(game.PICKUP.Kind.HEALTH)
	await _wait(1.2)
	_check("a cell is left lying by somebody who is not hurt", is_instance_valid(spare))
	spare.queue_free()

	# With nothing left to fire, the trigger swings the weapon itself.
	var dummy: CharacterBody3D = game.GRUNT.instantiate()
	dummy.position = player.global_position + Vector3(-1.5, 0, 0)
	game.add_child(dummy)
	dummy.set_physics_process(false)
	player.look_at(Vector3(dummy.global_position.x, player.global_position.y, dummy.global_position.z))
	player.head.rotation.x = 0.0
	var rounds: int = weapons._reserves[0]
	weapons._mags[0] = 0
	weapons._reserves[0] = 0
	await _wait(0.2)
	Input.action_press("fire")
	await _wait(0.1)
	Input.action_release("fire")
	_check("out of rounds, the trigger swings the weapon", weapons._melee_left > 0.0 and dummy.health == dummy.max_health)
	await _wait(0.6)
	_check("and the blow lands on what stands in front of it", is_equal_approx(dummy.health, dummy.max_health - weapons.MELEE_DAMAGE))
	dummy.free()
	weapons._mags[0] = rifle.mag_size
	weapons._reserves[0] = rounds
	game.picked_up.disconnect(note)
	for pickup in tree.get_nodes_in_group("pickup"):
		pickup.queue_free()

	# What a checkpoint is good for: back up to what a level starts with.
	player.health = 20.0
	weapons._reserves[0] = 0
	weapons.grenades = 0
	weapons.resupply()
	player.heal(maxf(game.CHECKPOINT_HEALTH - player.health, 0.0))
	_check("a checkpoint brings health and reserves back up, not to the full", player.health == game.CHECKPOINT_HEALTH
		and weapons._reserves[0] == weapons._start_reserve(rifle) and weapons.grenades == weapons.START_GRENADES)
	player.health = 1e6

	# The difficulty is one table, and a run is measured.
	Settings.put("difficulty", 2)
	var hard: Dictionary = Settings.rules()
	Settings.put("difficulty", 0)
	var easy: Dictionary = Settings.rules()
	Settings.put("difficulty", 1)
	_check("hard lets more of them shoot at once, hit harder and leave less; easy the other way", hard.attackers > rules.attackers
		and rules.attackers > easy.attackers and hard.damage > 1.0 and easy.damage < 1.0 and hard.regen_to < easy.regen_to and hard.drops < easy.drops)
	var run: Dictionary = Save.stats
	var summary := Menu.run_summary({"seconds": 754.0, "shots": 200.0, "hits": 82.0, "headshots": 9.0, "deaths": 2.0})
	print("    the run so far: %s; the end screen would say: %s" % [run, " / ".join(summary)])
	_check("a run is measured: time, shots, hits", run.seconds > 5.0 and run.shots > 0.0 and run.hits > 0.0 and run.hits <= run.shots)
	_check("and summed up for the end screen", summary.size() == 2 and summary[0].begins_with("Time  12:34   ·   Deaths  2") and summary[1] == "Accuracy  41%   ·   Headshots  9")
	_finished.append("supplies")


## Draws the cover the survey found on the floor the player stands on: `#`
## where nobody can stand, `.` open floor, `c` something to duck behind and
## `C` something to stand behind. North is up, a character is a metre.
func _print_cover(player: Node3D) -> void:
	var began := Time.get_ticks_usec()
	Squad._surveyed = [0, 0]
	Squad.find_cover(player, player.global_position + Vector3.UP * 1.6, {})
	print("    the survey took %.1f ms" % ((Time.get_ticks_usec() - began) / 1000.0))
	var cells := {}
	for at: Vector3 in Squad._open:
		if absf(at.y) < 0.6:
			cells[Vector2i(roundi(at.x), roundi(at.z))] = "."
	for i in Squad._spots.size():
		var at := Squad._spots[i]
		if absf(at.y) < 0.6:
			cells[Vector2i(roundi(at.x), roundi(at.z))] = "C" if Squad._high[i] else "c"
	var from := Vector2i(1000, 1000)
	var to := -from
	for cell: Vector2i in cells:
		from = from.min(cell)
		to = to.max(cell)
	print("    cover: %d spots, %d in the open; x %d to %d, z %d to %d" % [Squad._spots.size(), Squad._open.size(), from.x, to.x, from.y, to.y])
	for z in range(from.y, to.y + 1):
		var line := "    %4d " % z
		for x in range(from.x, to.x + 1):
			line += cells.get(Vector2i(x, z), "#")
		print(line)


## Plays the level that is loaded from its start to its exit: zone by zone
## and checkpoint by checkpoint, with a restart of the game at the first
## checkpoint and a death at the last. `next` is the level its exit should
## lead to, or empty for the last one.
func _play_through(level: Dictionary, next: String) -> void:
	var tree := get_tree()
	var game := tree.current_scene
	var title: String = level.name
	_check("%s: is the level that loads" % title, game.scene_file_path == level.scene)
	_check("%s: navmesh is baked" % title, game.nav_region.navigation_mesh.get_polygon_count() > 0)
	_check("%s: starts quiet, with the player at its start and every robot at its post" % title, _all_posted(game)
		and not game.fighting() and game.player.global_position.distance_to(game.start.origin) < 0.5)
	_check("%s: starting it is something to carry on from" % title, Save.resume_point(level.scene).get("at", "?") == "")
	var explosives := tree.get_nodes_in_group("explosive")
	_check("%s: has things that explode, each with its model" % title, not explosives.is_empty()
		and explosives.all(func(e: Node) -> bool: return e.get_node_or_null(e.model) != null))

	# The route as the level describes it, before anything is fought over.
	var walk := _walk(game)
	_check("%s: the route can be walked from start to exit" % title, not walk.is_empty())
	var entries := _entries(game, walk)
	_check("%s: the route passes through every zone" % title, entries.size() == game.zones.size())
	if _routes_only:
		print("    zones are entered at ", entries)
	var map: RID = game.player.get_world_3d().navigation_map
	var space: PhysicsDirectSpaceState3D = game.player.get_world_3d().direct_space_state
	var stranded := 0
	var exposed := 0
	for zone: RefCounted in game.zones:
		for spawn: Node3D in _spawns(zone):
			var at := spawn.global_position
			if not _reaches(map, at, game.start.origin):
				stranded += 1
				print("    stranded spawn: %s/%s" % [zone.id, spawn.name])
			if not entries.has(zone.id):
				continue
			# The player's eyes, over the floor at the spot the navmesh gives.
			var eye: Vector3 = entries[zone.id] + Vector3.UP
			var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + Vector3.DOWN * 3.0, 1))
			eye = (ground.position if ground else entries[zone.id]) + Vector3.UP * 1.6
			var seen := _in_view(space, eye, at)
			if _routes_only:
				# And from where on the way there the player already sees it standing.
				var early := PackedStringArray()
				for other: RefCounted in game.zones:
					if other.order >= zone.order or not entries.has(other.id):
						continue
					var from: Vector3 = entries[other.id] + Vector3.UP * 1.15
					if _in_view(space, from, at):
						early.append("%s at %.0f m" % [other.title, from.distance_to(at)])
				print("    %s/%s: %.1f m from where the zone is entered, %s%s" % [zone.id, spawn.name, eye.distance_to(at),
					"in view" if seen else "hidden", "" if early.is_empty() else "; stands in view from the way into " + ", ".join(early)])
			if eye.distance_to(at) < SPAWN_DISTANCE and seen:
				exposed += 1
				print("    spawn in view: %s/%s at %.1f m" % [zone.id, spawn.name, eye.distance_to(at)])
	_check("%s: every robot can reach the player from its post" % title, stranded == 0)
	_check("%s: none stands close by and in view where its zone is walked into" % title, exposed == 0)
	# Nor where the player appears: at the start, or at a checkpoint with the
	# zones before it cleared.
	var company := 0
	var poses := [[-1, "the start", game.start.origin]]
	for checkpoint: RefCounted in game.checkpoints:
		poses.append([checkpoint.order, checkpoint.title, checkpoint.pose.origin])
	for pose: Array in poses:
		var eye: Vector3 = pose[2] + Vector3.UP * 1.6
		for zone: RefCounted in game.zones:
			if zone.order < pose[0]:
				continue
			for spawn: Node3D in _spawns(zone):
				var at := spawn.global_position
				if eye.distance_to(at) < SPAWN_DISTANCE and _in_view(space, eye, at):
					company += 1
					print("    in view from %s: %s/%s at %.1f m" % [pose[1], zone.id, spawn.name, eye.distance_to(at)])
	_check("%s: nor where the player starts or carries on" % title, company == 0)
	var misplaced := 0
	for checkpoint: RefCounted in game.checkpoints:
		for zone: RefCounted in game.zones:
			if zone.order > checkpoint.order and _box(zone.area).has_point(checkpoint.pose.origin + Vector3.UP):
				misplaced += 1
	_check("%s: no checkpoint lies in a zone that comes after it" % title, misplaced == 0)
	# Where the level is left: on the floor in the middle of the exit, which
	# lies behind its door if it has one.
	var out := _box(game.exit)
	var beyond := Vector3(out.get_center().x, out.end.y, out.get_center().z)
	var floor_there := space.intersect_ray(PhysicsRayQueryParameters3D.create(beyond, beyond + Vector3.DOWN * (out.size.y + 1.0), 1))
	beyond = floor_there.position if floor_there else Vector3(beyond.x, out.position.y, beyond.z)
	var has_door := not tree.get_nodes_in_group("exit_door").is_empty()
	if has_door and not walk.is_empty():
		_check("%s: the door at the exit is shut" % title, not _open_way(space, walk[-1], beyond))
	var parts := game.get_node_or_null("Level")
	if parts and parts.has_method("drawn"):
		_check("%s: a zone that is switched off cannot be seen" % title, _sightlines(game, parts) == 0)

	# Now along it. A restart loads the level again, so everything is looked
	# up afresh at every step.
	var restarts := 0
	var step := 0
	while true:
		var steps := []
		steps.append_array(game.zones)
		steps.append_array(game.checkpoints)
		steps.sort_custom(func(a: RefCounted, b: RefCounted) -> bool: return a.order < b.order)
		if step >= steps.size():
			break
		var player: CharacterBody3D = game.player
		player.force_control = true
		player.health = 1e6
		var here: RefCounted = steps[step]
		step += 1
		if here.area.is_in_group("route_zone"):
			var robots: Array = here.robots.duplicate()
			_check("%s: the robots of %s wait at their posts" % [title, here.title], not here.started
				and _kinds(robots) == _roster(game, here) and _waiting(robots, _spawns(here)))
			# The last zone is not walked into but shot at from outside it.
			var shot: bool = here == game.zones[-1] and not robots.is_empty()
			if shot:
				robots[0].take_damage(1.0, robots[0].global_position + Vector3.UP, Vector3.DOWN)
			else:
				_move(player, entries.get(here.id, Vector3.ZERO))
			await _wait(0.3)
			_check("%s: %s starts their fight" % [title, "a shot at one of them" if shot else "walking in"], here.fighting()
				and robots.all(func(robot: Node) -> bool: return robot.can_process()))
			var before: int = game.kills
			for robot in robots:
				robot.take_damage(1e6, robot.global_position, Vector3.DOWN)
			await _wait(0.2)
			_check("%s: and is cleared when they are down" % title, here.cleared and not game.fighting() and game.kills == before + robots.size())
			continue

		# A checkpoint.
		_move(player, here.pose.origin)
		await _wait(0.3)
		_check("%s: checkpoint %s is taken" % [title, here.title], Save.resume_point(level.scene).get("at", "") == here.id)
		var kills: int = game.kills
		var last: bool = here == game.checkpoints[-1]
		if restarts == 0:
			# A restart of the game: what is on disk is all that is left.
			Save.reload()
			tree.change_scene_to_file(level.scene)
		elif last:
			player.health = 1.0
			player.take_damage(50.0)
		else:
			continue
		var how := "a restart" if restarts == 0 else "a death"
		restarts += 1
		var old := game
		for i in 80:
			await _wait(0.1)
			if tree.current_scene != null and tree.current_scene != old:
				break
		game = tree.current_scene
		await _wait(0.5)
		var again: RefCounted = game.checkpoints.filter(func(c: RefCounted) -> bool: return c.id == here.id)[0]
		_check("%s: %s carries on from that checkpoint" % [title, how], game != old
			and game.player.global_position.distance_to(again.pose.origin) < 0.5 and game.kills == kills)
		# What lies before it stays cleared, also when it is walked into again.
		var quiet := true
		for zone: RefCounted in game.zones:
			quiet = quiet and zone.cleared == (zone.order < again.order)
			if zone.order < again.order:
				_move(game.player, entries.get(zone.id, Vector3.ZERO))
				await _wait(0.3)
				quiet = quiet and zone.robots.is_empty() and not game.fighting()
			else:
				quiet = quiet and _kinds(zone.robots) == _roster(game, zone)
		_check("%s: and what was cleared before it stays cleared" % title, quiet)
		_move(game.player, again.pose.origin)
		await _wait(0.2)

	# And out.
	var lamp := game.exit.get_node_or_null("Lamp") as Node3D
	_check("%s: the exit opens when every zone is cleared" % title, game.exit_open and (lamp == null or lamp.visible)
		and game.objective == game.exit.get_meta(&"title"))
	var left := []
	game.finished.connect(func(to: String) -> void: left.append(to))
	if has_door and not walk.is_empty():
		# In front of the door nothing happens; it has to go up first.
		_move(game.player, walk[-1])
		await _wait(game.DOOR_DELAY + game.DOOR_TIME + 0.5)
		_check("%s: and its door rolls up out of the way" % title, left.is_empty()
			and _open_way(game.player.get_world_3d().direct_space_state, walk[-1], beyond))
	_move(game.player, beyond)
	await _wait(0.3)
	_check("%s: walking into it leaves the level" % title, left == [next] and game.next_level() == next)
	if next:
		await tree.scene_changed
		_check("%s: and the next one starts from its beginning" % title, tree.current_scene.scene_file_path == next
			and Save.resume_point(next).get("at", "?") == "")
	else:
		_check("%s: and that is the end of the game" % title, Save.checkpoint.is_empty())
	_finished.append(title)


## The way from the start past every checkpoint to the exit, as points
## STRIDE apart over the navmesh; empty if a stretch of it cannot be walked.
func _walk(game: Node) -> PackedVector3Array:
	var map: RID = game.player.get_world_3d().navigation_map
	var stops: Array[Vector3] = [game.start.origin]
	for checkpoint: RefCounted in game.checkpoints:
		stops.append(checkpoint.pose.origin)
	# The exit is a box; make for the floor in the middle of it. If it lies
	# behind a door that is still shut, the way there ends a step in front of
	# that door.
	var out := _box(game.exit)
	var door := Vector3(out.get_center().x, out.position.y, out.get_center().z)
	var shutters := get_tree().get_nodes_in_group("exit_door")
	if not shutters.is_empty():
		var shutter: Node3D = shutters[0]
		var before: Vector3 = shutter.global_position + shutter.get_meta(&"front", Vector3.ZERO)
		var space: PhysicsDirectSpaceState3D = game.player.get_world_3d().direct_space_state
		var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(before, before + Vector3.DOWN * 10.0, 1))
		door = ground.position if ground else before
	door = NavigationServer3D.map_get_closest_point(map, door)
	if shutters.is_empty() and not out.grow(0.3).has_point(door):
		print("    the exit has no floor to stand on")
		return PackedVector3Array()
	stops.append(door)
	var points := PackedVector3Array()
	for i in stops.size() - 1:
		if not _reaches(map, stops[i], stops[i + 1]):
			print("    no way from %s to %s" % [stops[i], stops[i + 1]])
			return PackedVector3Array()
		var leg := NavigationServer3D.map_get_path(map, stops[i], stops[i + 1], true)
		for j in leg.size() - 1:
			var steps := maxi(1, ceili(leg[j].distance_to(leg[j + 1]) / STRIDE))
			for k in steps:
				points.append(leg[j].lerp(leg[j + 1], float(k) / steps))
	points.append(door)
	return points


## Zone id -> a spot just inside that zone on the way along `walk`.
func _entries(game: Node, walk: PackedVector3Array) -> Dictionary:
	var entries := {}
	for zone: RefCounted in game.zones:
		var box := _box(zone.area)
		for i in walk.size():
			if box.has_point(walk[i] + Vector3.UP):
				# A step further, so that all of the player is inside.
				var inside := walk[mini(i + 2, walk.size() - 1)]
				entries[zone.id] = inside if box.has_point(inside + Vector3.UP) else walk[i]
				break
	return entries


## Counts the lines of sight between where the player can stand in one zone
## and the inside of a zone that is not drawn from there. Windows count as
## holes: nothing that has no collider stops a look.
func _sightlines(game: Node, level: Node) -> int:
	var space: PhysicsDirectSpaceState3D = game.player.get_world_3d().direct_space_state
	var zones := level.get_children().filter(func(node: Node) -> bool: return node.is_in_group("level_zone"))
	# Where eyes can be: over every corner and every middle of the navmesh,
	# standing and crouching, a share of them if there are many.
	var navmesh: NavigationMesh = game.nav_region.navigation_mesh
	var corners := navmesh.get_vertices()
	var spots := PackedVector3Array(corners)
	for i in navmesh.get_polygon_count():
		var middle := Vector3.ZERO
		var polygon := navmesh.get_polygon(i)
		for corner in polygon:
			middle += corners[corner]
		spots.append(middle / polygon.size())
	var eyes := {}
	var insides := {}
	for zone: Node in zones:
		var boxes: Array = zone.get_meta(&"bounds")
		var mine := PackedVector3Array()
		for spot in spots:
			if boxes.any(func(box: AABB) -> bool: return box.has_point(spot + Vector3.UP * 0.5)):
				mine.append(spot)
		var looks := PackedVector3Array()
		var step := maxi(1, ceili(float(mine.size()) / LOOKOUTS))
		for i in range(0, mine.size(), step):
			var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(mine[i] + Vector3.UP, mine[i] + Vector3.DOWN * 2.0, 1))
			var feet: Vector3 = ground.position if ground else mine[i]
			looks.append(feet + Vector3.UP * 1.6)
			looks.append(feet + Vector3.UP * 0.95)
		eyes[zone.get_meta(&"zone")] = looks
		# What there is to see of a zone: points all through it.
		var points := PackedVector3Array()
		for box: AABB in boxes:
			var inner := box.grow(-0.6)
			var counts := Vector3i((inner.size / SIGHT_GRID).ceil()).maxi(1)
			for x in counts.x + 1:
				for y in counts.y + 1:
					for z in counts.z + 1:
						points.append(inner.position + inner.size * Vector3(x, y, z) / Vector3(counts))
		insides[zone.get_meta(&"zone")] = points
	var found := 0
	for zone: Node in zones:
		var from: String = zone.get_meta(&"zone")
		var sees: PackedStringArray = zone.get_meta(&"sees")
		for to: String in insides:
			if to == from or to in sees:
				continue
			var lines := 0
			for eye: Vector3 in eyes[from]:
				for point: Vector3 in insides[to]:
					if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, point, 1)).is_empty():
						lines += 1
						if lines == 1:
							print("    %s is in sight from %s: from %s to %s" % [to, from, eye, point])
			if _routes_only:
				print("    %s from %s: %d looks from %d spots at %d points" % [to, from, lines, eyes[from].size(), insides[to].size()])
			found += lines
	return found


## The box of a zone, a checkpoint or an exit.
func _box(area: Area3D) -> AABB:
	var size: Vector3 = (area.get_child(0) as CollisionShape3D).shape.size
	return AABB(area.global_position - size * 0.5, size)


func _spawns(zone: RefCounted) -> Array:
	return zone.area.get_children().filter(func(node: Node) -> bool: return node.is_in_group("enemy_spawn"))


## True if every zone has the robots it lists standing at their posts.
func _all_posted(game: Node) -> bool:
	for zone: RefCounted in game.zones:
		if _kinds(zone.robots) != _roster(game, zone) or not _waiting(zone.robots, _spawns(zone)):
			return false
	return not game.zones.is_empty()


## True if those robots stand where they were posted, switched off.
func _waiting(robots: Array, posts: Array) -> bool:
	if robots.size() != posts.size():
		return false
	for i in robots.size():
		var robot: Node3D = robots[i]
		if robot.can_process() or robot.global_position.distance_to(posts[i].global_position) > 0.1:
			return false
	return true


## The scenes a zone lists, sorted, to compare with what _kinds() finds.
func _roster(game: Node, zone: RefCounted) -> Array:
	var scenes := _spawns(zone).map(func(spawn: Node) -> String: return game.ENEMIES[spawn.get_meta(&"kind")].resource_path)
	scenes.sort()
	return scenes


func _kinds(enemies: Array) -> Array:
	var scenes := enemies.map(func(enemy: Node) -> String: return enemy.scene_file_path)
	scenes.sort()
	return scenes


## True if the navmesh has a way from one point to the other.
func _reaches(map: RID, from: Vector3, to: Vector3) -> bool:
	var route := NavigationServer3D.map_get_path(map, from, to, true)
	return route.size() > 1 and route[0].distance_to(from) < 1.0 and route[-1].distance_to(to) < 1.0


## True if nothing stands between two spots on the floor, at the height of
## the player's middle.
func _open_way(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.9, to + Vector3.UP * 0.9, 1)).is_empty()


## True if a robot standing at `spot` shows from `eye`: its head or its middle.
func _in_view(space: PhysicsDirectSpaceState3D, eye: Vector3, spot: Vector3) -> bool:
	for height: float in [1.5, 0.8]:
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, spot + Vector3.UP * height, 1)).is_empty():
			return true
	return false


func _move(player: CharacterBody3D, to: Vector3) -> void:
	player.global_position = to
	player.velocity = Vector3.ZERO


## Fails for every one of `parts` that did not run to its end.
func _ran(parts: Array) -> void:
	for part: String in parts:
		if not _finished.has(part):
			_check("the part of the test called '%s' ran to its end" % part, false)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
