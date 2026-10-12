extends Node
## Headless gameplay smoke test. Run with: tools/selftest.sh
##
## Drives the real player through simulated input and checks that the core
## loop still works: navmesh, slide, shooting, enemy AI, weapon switching,
## enemy types, explosives, grenades, settings, how the view moves and what
## can be shot to pieces. Then it goes through every level along its route,
## from the start to the exit and on into the next: that the route can be
## walked over the navmesh, that every robot can reach the player from its
## post and none stands close by and in view where the player appears or
## walks into its zone, that the robots a zone lists wait at their posts
## until its fight starts, that a checkpoint is still there after a restart
## of the game and after a death, that the door at the exit is shut until
## the level is cleared, and that every crate, box and lamp in it can be
## broken. Where a level is cut into zones that are only drawn when they can
## be seen, it looks for lines of sight into a zone from where that zone is
## switched off.

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


## The checkout this runs from, by a name no other has: the folder it is in
## and a number made of the whole path to it, "Graphics-1c9a04e7".
func checkout() -> String:
	var folder := ProjectSettings.globalize_path("res://").trim_suffix("/")
	return "%s-%08x" % [folder.get_file(), folder.hash()]


## Where a test keeps a file called `file`: in a folder of this checkout's
## own under user://selftest/. Every checkout of the project has the same
## user://, and tests of two of them run at the same time: with one file
## between them each found there what the other had just written.
func own_file(file: String) -> String:
	var folder := "user://selftest/%s" % checkout()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	return "%s/%s" % [folder, file]


func _run() -> void:
	var tree := get_tree()
	# A script error would otherwise leave the run hanging forever.
	tree.create_timer(420.0, true, true).timeout.connect(
		func() -> void:
			print("SELFTEST FAILED (timed out)")
			tree.quit(1)
	)
	await _wait(0.5)
	# --routes leaves out everything but the levels and their routes, and
	# lists every spawn point: for working on a level.
	_routes_only = "--routes" in OS.get_cmdline_user_args()
	# --level=<name> plays one level and nothing else, entered as the first
	# is, from the menu: for working on that level. It says what --routes says.
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--level="):
			continue
		_routes_only = true
		var levels := Menu.LEVELS.filter(func(level: Dictionary) -> bool: return (level.scene as String).get_file().get_basename() == arg.trim_prefix("--level="))
		if levels.is_empty():
			print("SELFTEST FAILED (no level called %s)" % arg.trim_prefix("--level="))
			tree.quit(1)
			return
		var at := Menu.LEVELS.find(levels[0])
		Save.clear()
		tree.change_scene_to_file(levels[0].scene)
		await tree.scene_changed
		await _wait(0.5)
		await _play_through(levels[0], Menu.LEVELS[at + 1].scene if at + 1 < Menu.LEVELS.size() else "")
		_ran([levels[0].name])
		print("SELFTEST %s" % ("PASSED" if _failures == 0 else "FAILED (%d)" % _failures))
		tree.quit(1 if _failures else 0)
		return
	# --fights leaves out everything but what the enemies do in a fight.
	var fights_only := "--fights" in OS.get_cmdline_user_args()
	if fights_only:
		await _fights()
		await _supplies()
		_ran(["fights", "supplies"])
		print("SELFTEST %s" % ("PASSED" if _failures == 0 else "FAILED (%d)" % _failures))
		tree.quit(1 if _failures else 0)
		return
	# --view leaves out everything but how the view moves, and --breaks
	# everything but what can be shot to pieces.
	for only: Array in [["--view", _view, "view"], ["--breaks", _breakables, "breakables"]]:
		if only[0] not in OS.get_cmdline_user_args():
			continue
		await (only[1] as Callable).call()
		_ran([only[2]])
		print("SELFTEST %s" % ("PASSED" if _failures == 0 else "FAILED (%d)" % _failures))
		tree.quit(1 if _failures else 0)
		return
	if not _routes_only:
		await _handling()
		await _fights()
		await _supplies()
		await _view()
		# Last, since it breaks what the parts before it fight behind.
		await _breakables()
		_ran(["handling", "fights", "supplies", "view", "breakables"])

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
	_check("a render scale that sets itself draws the pixels of 1920 × 1080", is_equal_approx(Settings.scale_for(Vector2i(1920, 1080)), 1.0)
		and is_equal_approx(Settings.scale_for(Vector2i(2560, 1440)), 0.75) and is_equal_approx(Settings.scale_for(Vector2i(3456, 2160)), 0.5)
		and is_equal_approx(Settings.scale_for(Vector2i(7680, 4320)), Settings.MIN_SCALE))
	var window := game.get_window()
	var windowed := window.size
	Settings.put("auto_scale", true)
	_check("left to itself, it takes the scale of the window", is_equal_approx(game.get_viewport().scaling_3d_scale, Settings.scale_for(windowed)))
	window.size = Vector2i(3456, 2160)
	_check("and follows the window as that changes size", is_equal_approx(game.get_viewport().scaling_3d_scale, 0.5))
	window.size = windowed
	Settings.put("auto_scale", false)

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

	# Cover may not hang on the last digit of a ray. Jolt returns every hit a
	# hair differently once a collider is added anywhere in the level, or the
	# same ones come in another order: both are done here, and neither may
	# change which spots there are or what one is worth.
	var colliders: StaticBody3D = game.get_node("Level/Collision")
	var cover := _cover_from(player, eye)
	var far := CollisionShape3D.new()
	far.shape = BoxShape3D.new()
	(far.shape as BoxShape3D).size = Vector3.ONE * 30.0
	far.position = Vector3(300, 50, -200)
	colliders.add_child(far)
	await _wait(0.1)
	var with_more := _cover_differs(cover, _cover_from(player, eye))
	far.free()
	var shapes := colliders.get_children()
	for i in range(0, shapes.size(), 7):
		colliders.remove_child(shapes[i])
		colliders.add_child(shapes[i])
	await _wait(0.1)
	var shuffled := _cover_differs(cover, _cover_from(player, eye))
	for shape in shapes:
		colliders.remove_child(shape)
		colliders.add_child(shape)
	await _wait(0.1)
	Squad._surveyed = [0, 0]
	print("    cover against somebody at the stand: %d spots to stand behind and %d to duck behind, of %d; with a collider more: %s; in another order: %s" % [
		cover.standing, cover.ducked, cover.spots.size(), with_more if with_more else "the same", shuffled if shuffled else "the same"])
	_check("there is cover to stand behind and cover to duck behind", cover.standing >= 10 and cover.ducked > 0)
	_check("a collider more, far from the fight, changes none of it", with_more.is_empty())
	_check("nor do the same colliders in another order", shuffled.is_empty())

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


## How the view moves, tried out on the runway of the factory: the bob of a
## walk on the stride the footsteps go by, what a shot, a hit and a landing do
## to it, the one setting that scales all of it, and the settings screen that
## setting is on. What is checked is where the camera sits on the head and how
## it is turned there: the head itself is where the player looks, and what the
## enemies aim at.
func _view() -> void:
	var tree := get_tree()
	var game := tree.current_scene
	var player: CharacterBody3D = game.player
	var weapons: Node3D = player.weapons
	var camera: Camera3D = player.camera
	var hud: CanvasLayer = game.get_node("HUD")
	var rifle: WeaponData = weapons.LOADOUT[0]
	player.force_control = true
	player.health = 1e6
	for zone: RefCounted in game.zones:
		zone.area.set_deferred("monitoring", false)
	for enemy in tree.get_nodes_in_group("enemy"):
		enemy.queue_free()
	var stand := func() -> void:
		for action in ["move_forward", "move_right", "sprint", "crouch", "jump", "ads", "fire"]:
			Input.action_release(action)
		_move(player, RUNWAY)
		player.rotation = Vector3(0, PI * 0.5, 0)
		player.head.rotation.x = 0.0
	stand.call()
	await _wait(0.6)
	_check("standing still, the camera sits dead level on the head", camera.position.length() < 0.0001 and camera.rotation.length() < 0.0001)

	# A walk: once it has got going the eye rises and falls with every step,
	# and it is lowest as the foot comes down, which is when the step sounds.
	# The sound is listened for where it is made: for every step, how many
	# frames of this walk the stride is past the footfall as it starts. That
	# is one at most if it starts on the frame the foot comes down.
	var steps: Array[float] = []
	var hear := func(sound: Node) -> void:
		if sound is AudioStreamPlayer and Sfx._streams[&"footstep"].has(sound.stream):
			var frame: float = Vector2(player.velocity.x, player.velocity.z).length() * get_process_delta_time() / player.STEP_DISTANCE
			steps.append(fposmod(player.stride(), 1.0) / frame)
	Sfx.child_entered_tree.connect(hear)
	Input.action_press("move_forward")
	var walk := await _watch(player, 1.8)
	Sfx.child_entered_tree.disconnect(hear)
	var steady := walk.filter(func(frame: Array) -> bool: return frame[0] > 0.5)
	var heights := steady.map(func(frame: Array) -> float: return frame[2].y)
	var walk_swing: float = heights.max()
	var off_step := 0.0
	var dips := 0
	for i in range(1, steady.size() - 1):
		if heights[i] < heights[i - 1] and heights[i] <= heights[i + 1]:
			dips += 1
			off_step = maxf(off_step, absf(steady[i][1] - roundf(steady[i][1])))
	print("    a walk: the eye goes from %.1f to %.1f mm, lowest %.3f of a step off the footfall at worst; %d steps sound, %.2f of a frame after the footfall at worst" % [
		heights.min() * 1000.0, walk_swing * 1000.0, off_step, steps.size(), steps.max() if steps.size() > 0 else -1.0])
	_check("walking, the eye rises and falls between 1 and 2 cm with every step", walk_swing > 0.01 and walk_swing < 0.02
		and heights.min() < -0.01 and heights.min() > -0.02)
	_check("and is lowest as the foot comes down", dips >= 2 and off_step < 0.05)
	_check("which is the frame on which the step sounds", steps.size() >= 3 and steps.all(func(frames: float) -> bool: return frames < 1.001))

	# The one setting: at nothing the camera does not move, whatever happens.
	# The weapon in view keeps some of its bob, or it would look broken.
	Settings.put("view_motion", 0.0)
	stand.call()
	Input.action_press("move_forward")
	await tree.process_frame
	await tree.process_frame
	player.take_damage(40.0)
	player.punch_fov(1.0)
	var held := await _watch(player, 0.6)
	var sways := held.map(func(frame: Array) -> float: return frame[6].x)
	var level: float = held[0][4]
	var still := func(frame: Array) -> bool: return frame[2].length() < 1e-7 and frame[3].length() < 1e-6 and absf(frame[4] - level) < 1e-4
	_check("with view motion at 0 the camera holds still through a walk, a hard hit and a shot's punch", held.all(still))
	_check("and the weapon in view still moves, a third as much", sways.max() - sways.min() > 0.002 and sways.max() - sways.min() < 0.01)
	# And through what leans the view and widens it: a strafe at a sprint and a
	# jump with its landing, then a slide. The player is turned an eighth so
	# that forward and to the right together run down the runway.
	var landings := [0]
	var count := func(_hardness: float) -> void: landings[0] += 1
	player.landed.connect(count)
	stand.call()
	player.rotation.y = PI * 0.75
	for action in ["move_forward", "move_right", "sprint", "jump"]:
		Input.action_press(action)
	var leant := await _watch(player, 0.9)
	var strafed: bool = player.is_sprinting() and player.velocity.dot(player.global_basis.x) > 4.0
	Input.action_press("crouch")
	leant.append_array(await _watch(player, 0.2))
	player.landed.disconnect(count)
	_check("nor does it lean or widen: through a strafe at a sprint, a landing and a slide", strafed and landings[0] == 1 and player.is_sliding()
		and leant.all(still))
	Settings.put("view_motion", 1.0)

	stand.call()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var sprint := await _watch(player, 0.9)
	var sprint_swing: float = sprint.filter(func(frame: Array) -> bool: return frame[0] > 0.5).map(func(frame: Array) -> float: return frame[2].y).max()
	_check("with it back at 1 it moves again, and more at a sprint than at a walk", sprint_swing > walk_swing * 1.3)

	# Over the sights the camera may still rise and fall a little, but it
	# does not turn: the sights hold on what they are held on.
	stand.call()
	Input.action_press("move_forward")
	Input.action_press("ads")
	var aimed := (await _watch(player, 0.9)).filter(func(frame: Array) -> bool: return frame[0] > 0.5)
	var aimed_heights := aimed.map(func(frame: Array) -> float: return frame[2].y)
	var aimed_swing: float = aimed_heights.max() - aimed_heights.min()
	_check("walking with the sights up, the camera does not turn", weapons.ads_blend == 1.0 and aimed_swing > 0.0005 and aimed_swing < 0.005
		and aimed.all(func(frame: Array) -> bool: return frame[3].length() < 0.0001))

	# A jump: the knees give as the player comes down and straighten again,
	# on the camera and not on the head that the enemies aim at.
	stand.call()
	await _wait(0.1)
	Input.action_press("jump")
	var jump := await _watch(player, 1.3)
	Input.action_release("jump")
	var dip: float = jump.map(func(frame: Array) -> float: return frame[2].y).min()
	print("    a jump: the eye dips %.0f mm on landing" % (-dip * 1000.0))
	_check("landing dips the view and it comes back", dip < -0.05 and dip > -0.12 and absf(jump[-1][2].y) < 0.002)
	_check("and the head the camera sits on stays where it is all the while", jump.all(
		func(frame: Array) -> bool: return absf(frame[7] - player.STAND_EYE) < 0.001))

	# One shot of the rifle. What it does to the aim is what it did before
	# the view learned to move: a kick of what its data says, of which the
	# view showed 0.598 at its peak at 45 frames a second, 0.608 at 60, 0.624
	# at 120 and 0.627 as fast as this test runs. Each frame is held against
	# that recoil worked out here: nothing else may turn the camera of
	# somebody who stands still. Next to it the field of view widens for a
	# moment, and the weapon kicks back in the hands. How much of either kick
	# a frame gets to show depends on how long the frame before it took: the
	# bounds leave room for one of 50 ms, which shows 0.547 of the kick of the
	# aim and 0.6 of that of the weapon, as on a machine that is busy.
	weapons._mags[0] = rifle.mag_size
	var wide: float = camera.fov
	var held_at: Vector3 = weapons._models[0].root.position
	Input.action_press("fire")
	for i in 100:
		if weapons._mags[0] < rifle.mag_size:
			break
		await tree.process_frame
	Input.action_release("fire")
	var kick: Vector3 = player._recoil_target
	var due := kick
	var aim: Vector3 = player._recoil
	var stray := 0.0
	var peak := 0.0
	var punch := 0.0
	var back := 0.0
	var forward := 0.0
	var since := 0.0
	while since < 0.3:
		# What the frame before this one left to be seen, and then what the
		# recoil will have come to by the next.
		stray = maxf(stray, (camera.rotation - aim).length())
		peak = maxf(peak, camera.rotation.x)
		punch = maxf(punch, camera.fov - wide)
		var pushed: float = weapons._models[0].root.position.z - held_at.z
		back = maxf(back, pushed)
		forward = minf(forward, pushed)
		var step := get_process_delta_time()
		since += step
		due = due.lerp(Vector3.ZERO, 1.0 - exp(-player.RECOIL_RETURN * step))
		aim = aim.lerp(due, 1.0 - exp(-player.RECOIL_SNAP * step))
		await tree.process_frame
	var nominal := deg_to_rad(rifle.recoil_pitch_deg)
	print("    a rifle shot: the aim is kicked %.2f° up, of which the view shows %.3f; it widens %.2f°; the weapon comes %.0f mm back and %.1f mm forward of where it was held" % [
		rad_to_deg(kick.x), peak / kick.x, punch, back * 1000.0, -forward * 1000.0])
	_check("a rifle shot kicks the aim by what its data says, as it did before", kick.x > nominal * 0.849 and kick.x < nominal * 1.151
		and absf(kick.y) <= deg_to_rad(rifle.recoil_yaw_deg) and is_equal_approx(kick.z, kick.y * 0.5))
	_check("and the view shows the same share of it, with nothing else turning the camera", peak / kick.x > 0.5 and peak / kick.x < 0.645 and stray < 1e-5)
	_check("the shot widens the field of view for a moment, and it is back within 0.3 s", punch > 0.3 and punch < 0.5 and absf(camera.fov - wide) < 0.01)
	_check("the weapon kicks back as far as its data says and swings a little past where it was held", back > rifle.kick_back * 0.5
		and back < rifle.kick_back * 1.05 and forward < 0.0)

	# A hit from the left: `direction` is the way the shot travels, so to the
	# player's right. The head rolls away from it and the aim stays put, which
	# here is where the shot just fired has left it; the HUD draws an arc on
	# the left, which stays on whoever fired as the player turns to face them.
	var bearings: Array[Vector3] = []
	var note := func(_amount: float, bearing: Vector3) -> void: bearings.append(bearing)
	player.hit_from.connect(note)
	var to_right: Vector3 = player.global_basis.x
	player.take_damage(7.0, player.global_position + Vector3.UP, to_right)
	var rolled := 0.0
	var turned := 0.0
	for frame in await _watch(player, 0.12):
		var knock: Vector3 = frame[3] - frame[5]
		rolled = minf(rolled, knock.z)
		turned = maxf(turned, Vector2(knock.x, knock.y).length())
	_check("a hit says where it came from: a direction to the left of the player", bearings.size() == 1 and bearings[0].dot(-to_right) > 0.99)
	_check("it rolls the head away from that side, by something to see, and leaves the aim alone", rolled < -0.004 and rolled > -0.009 and turned < 1e-5)
	var arcs: Array[Vector2] = hud._hit_arcs.arcs
	_check("the HUD draws an arc on the side the hit came from", arcs.size() == 1 and absf(arcs[0].x + PI * 0.5) < 0.02 and arcs[0].y > 0.4)
	player.rotate_y(PI * 0.5)
	await tree.process_frame
	await tree.process_frame
	_check("which stays on where it came from as the player turns to face it", arcs.size() == 1 and absf(arcs[0].x) < 0.02)
	player.take_damage(7.0)
	player.take_damage(7.0, Vector3.ZERO, to_right.rotated(Vector3.UP, deg_to_rad(10.0)))
	await tree.process_frame
	await tree.process_frame
	var renewed := arcs.size()
	player.take_damage(7.0, Vector3.ZERO, -to_right)
	await tree.process_frame
	await tree.process_frame
	_check("a hit from no side draws none, one from the same side renews its arc, one from elsewhere adds one",
		bearings.size() == 4 and bearings[1] == Vector3.ZERO and renewed == 1 and arcs.size() == 2)
	player.hit_from.disconnect(note)

	# The commonest hit there is, a grunt's shot from straight ahead: it has
	# no side to roll the head away from, and still rolls it, half as far and
	# either way, and throws it back by as much.
	stand.call()
	await _wait(0.3)
	player._knock.settle()
	player.take_damage(7.0, Vector3.ZERO, player.global_basis.z)
	var thrown := Vector3.ZERO
	for frame in await _watch(player, 0.12):
		var knock: Vector3 = frame[3] - frame[5]
		thrown = thrown.max(Vector3(knock.x, absf(knock.y), absf(knock.z)))
	_check("a grunt's shot from straight ahead throws the head back and rolls it, each by a fifth of a degree", thrown.x > 0.002 and thrown.x < 0.0045
		and thrown.z > 0.002 and thrown.z < 0.0045 and thrown.y < 1e-5)

	# The weapon lags a turn of the view, but only so far, however sudden:
	# the test itself turns the player a quarter circle in one frame. Posed
	# for a picture of a player who stands still, it sits where its data puts
	# it, whatever it swung with before.
	var held_to := rifle.hip_rotation_deg * (PI / 180.0)
	player.rotate_y(-PI * 0.5)
	await tree.process_frame
	await tree.process_frame
	var lag: float = absf(weapons._models[0].root.rotation.y - held_to.y)
	player.rotate_y(PI * 0.5)
	weapons.preview(0)
	_check("a sudden turn leaves the weapon behind, by no more than it may lag", lag > 0.005 and lag < weapons.SWAY_MAX + 0.001)
	_check("posed for a picture, the weapon sits where its data puts it", weapons._models[0].root.position.is_equal_approx(rifle.hip_offset)
		and weapons._models[0].root.rotation.is_equal_approx(held_to))
	# Posed with its kick at its furthest, at the hip and then over the
	# sights, where it comes less far back: the sights should stay near what
	# they are held on.
	var kicks: Array[float] = []
	for sights: float in [0.0, 1.0]:
		weapons.preview(0, sights)
		weapons._kick.at = Vector3(0.0, 0.0, 1.0)
		weapons._animate_viewmodel(rifle, 0.0)
		kicks.append(weapons._models[0].root.position.z - rifle.hip_offset.lerp(rifle.ads_offset, sights).z)
	weapons.preview(0)
	_check("over the sights the weapon kicks less far back than at the hip", is_equal_approx(kicks[0], rifle.kick_back)
		and kicks[1] > rifle.kick_back * 0.5 and kicks[1] < rifle.kick_back * 0.8)

	# The settings screen has more on it than fits a screen of 1920 × 1080,
	# which is as low as one gets: the list in it scrolls, and the way back
	# stays in view.
	var window := game.get_window()
	var windowed := window.size
	window.size = Vector2i(1920, 1080)
	Menu._show(Menu.Screen.SETTINGS)
	for i in 4:
		await tree.process_frame
	var column: Array[Node] = Menu._column.get_children()
	var list: ScrollContainer = column.filter(func(child: Node) -> bool: return child is ScrollContainer)[0]
	var heading: Control = column[0]
	var back_button: Button = column[-1]
	var top := heading.global_position.y
	var bottom := back_button.global_position.y + back_button.size.y
	var screen: float = Menu._root.size.y
	# Down the list with the keys, as a controller steps through it too.
	var stops := 0
	var in_view := true
	var focused := window.gui_get_focus_owner()
	while focused and stops < 40:
		stops += 1
		var box := focused.get_global_rect()
		var frame := list.get_global_rect() if list.is_ancestor_of(focused) else Rect2(0, 0, 1920, screen)
		in_view = in_view and box.position.y > frame.position.y - 0.5 and box.end.y < frame.end.y + 0.5
		for pressed: bool in [true, false]:
			var key := InputEventAction.new()
			key.action = "ui_down"
			key.pressed = pressed
			Input.parse_input_event(key)
		await tree.process_frame
		await tree.process_frame
		if window.gui_get_focus_owner() == focused:
			break
		focused = window.gui_get_focus_owner()
	var sliders := Menu._column.find_children("*", "HSlider", true, false)
	var lines := Menu._column.find_children("*", "Control", true, false).filter(
		func(control: Control) -> bool: return control.focus_mode == Control.FOCUS_ALL).size()
	print("    the settings screen at 1920 × 1080: its column is %.0f px high, from %.0f to %.0f of %.0f, and the Back button ends at %.0f; the list in it shows %.0f of %.0f px; %d stops for the keys" % [
		bottom - top, top, bottom, screen, bottom, list.size.y, list.get_child(0).size.y, stops])
	_check("the settings screen fits a screen of 1920 × 1080, Back button and all", screen == 1080.0 and top >= 0.0 and bottom <= screen
		and back_button.text == "Back")
	_check("and stepping down it reaches every setting, each in view when its turn comes", stops == lines and in_view and focused == back_button)
	_check("view motion is one of them, from 0 to 150 percent", Settings.KEYS.has("view_motion") and Settings.view_motion == 1.0
		and sliders.any(func(slider: HSlider) -> bool: return slider.max_value == Settings.MAX_VIEW_MOTION))
	Menu._show(Menu.Screen.NONE)
	Sfx.stop_music(0.0)
	window.size = windowed
	await _wait(0.2)
	_finished.append("view")


## Follows the camera of `player` for `seconds`. Returns a line for every
## frame that was drawn: the seconds since the start, the stride, where the
## camera sits on the head, how it is turned there, its field of view, how
## much of that turn is recoil, where the weapon in view is held, and how
## high the head is that the camera sits on.
func _watch(player: CharacterBody3D, seconds: float) -> Array[Array]:
	var frames: Array[Array] = []
	var clock := [0.0]
	var note := func() -> void:
		clock[0] += get_process_delta_time()
		frames.append([clock[0], player.stride(), player.camera.position, player.camera.rotation, player.camera.fov, player._recoil,
			player.weapons._models[player.weapons._index].root.position, player.head.position.y])
	get_tree().process_frame.connect(note)
	await _wait(seconds)
	get_tree().process_frame.disconnect(note)
	return frames


## Surveys the level as it is at this moment and asks of every spot what it
## is worth to a robot grunt against somebody looking from `eye`: nothing,
## cover to stand behind or cover to duck behind. `standing` and `ducked` count
## the spots on the player's floor, at a distance a grunt fights from.
func _cover_from(player: Node3D, eye: Vector3) -> Dictionary:
	Squad._surveyed = [0, 0]
	Squad.find_cover(player, eye, {})
	var space := player.get_world_3d().direct_space_state
	var map := player.get_world_3d().navigation_map
	var worth := PackedInt32Array()
	var counts := [0, 0, 0]
	for at in Squad._spots:
		var found := Squad._suits(space, map, at, eye, 1.5, 0.68)
		worth.append(0 if found.is_empty() else 2 if found.crouch else 1)
		var away := Vector2(at.x - eye.x, at.z - eye.z).length()
		if away > 5.0 and away < 23.0 and absf(at.y - player.global_position.y) < 2.0:
			counts[worth[-1]] += 1
	return {"spots": Squad._spots.duplicate(), "low": Squad._low.duplicate(), "high": Squad._high.duplicate(), "worth": worth, "standing": counts[1], "ducked": counts[2]}


## The first thing that differs between two looks at the cover, or nothing.
func _cover_differs(a: Dictionary, b: Dictionary) -> String:
	if a.spots.size() != b.spots.size():
		return "%d spots instead of %d" % [b.spots.size(), a.spots.size()]
	for i in a.spots.size():
		var at: Vector3 = a.spots[i]
		if at.distance_to(b.spots[i]) > 0.001:
			return "the spot at %s is at %s" % [at.snappedf(0.01), (b.spots[i] as Vector3).snappedf(0.01)]
		if a.low[i] != b.low[i] or a.high[i] != b.high[i]:
			return "other things stand around %s" % at.snappedf(0.01)
		if a.worth[i] != b.worth[i]:
			return "%s is worth %d instead of %d" % [at.snappedf(0.01), b.worth[i], a.worth[i]]
	return ""


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


## What can be shot to pieces, tried out in the factory: the lamps, the
## stacks of crates and the cardboard boxes. A stack is only tried on if no
## part before this one has touched it.
func _breakables() -> void:
	var tree := get_tree()
	var game := tree.current_scene
	var player: CharacterBody3D = game.player
	var weapons: Node3D = player.weapons
	var space := player.get_world_3d().direct_space_state
	var stack_script: GDScript = game.BREAKABLES.STACK
	player.force_control = true
	player.health = 1e6
	weapons._mags[0] = 30
	for zone: RefCounted in game.zones:
		zone.area.set_deferred("monitoring", false)
	for enemy in tree.get_nodes_in_group("enemy"):
		enemy.queue_free()
	await _wait(0.3)
	var lamps: Array = game._breakables.filter(func(body: Node) -> bool: return body.has_method("lens"))
	var whole := func(body: Node) -> bool:
		return body.has_method("cover") and body._members.all(func(member: RefCounted) -> bool:
			return not member.gone and member.health == body.TUNING[member.kind].health)
	var stacks: Array = game._breakables.filter(whole)
	var threes := stacks.filter(func(stack: Node) -> bool: return stack.size() == 3 and stack._colliders.size() == 1)
	var towers := stacks.filter(func(stack: Node) -> bool: return stack._colliders.size() == 2 and stack._members[0].kind == stack.Kind.CRATE)

	# Something that lies on top of a stack that stands on another, with the
	# time of all that comes first to settle there.
	var sleeper: RigidBody3D = null
	if not towers.is_empty():
		var highest: RefCounted = towers[0]._members[-1]
		var cube := BoxShape3D.new()
		cube.size = Vector3.ONE * 0.2
		var shape := CollisionShape3D.new()
		shape.shape = cube
		sleeper = RigidBody3D.new()
		sleeper.collision_layer = 0
		sleeper.add_child(shape)
		game.add_child(sleeper)
		sleeper.global_position = (towers[0]._colliders[1] as Node3D).global_position * Vector3(1, 0, 1) + Vector3.UP * (towers[0].global_position.y + highest.foot + highest.height + 0.11)
	# Every piece that is made from here on, and the most there are of them
	# at once: a piece is a rigid body on no layer.
	var made: Array = []
	var most := [0]
	var note := func(node: Node) -> void:
		if node is RigidBody3D and node.collision_layer == 0:
			made.append(node)
			most[0] = maxi(most[0], made.filter(is_instance_valid).size())
	tree.node_added.connect(note)

	# The bottom crate of a stack, which also starts the clock on its pieces,
	# and one more hit where it stood, before the crates above have moved.
	var low: StaticBody3D = threes.pop_back()
	var crates: Array = low._members
	low.take_damage(1000.0, low.global_position + Vector3.UP * 0.1, Vector3.FORWARD)
	low.take_damage(50.0, low.global_position + Vector3.UP * 0.1, Vector3.FORWARD)
	var began := Time.get_ticks_msec()
	var low_collider: CollisionShape3D = low._colliders[0]
	_check("a crate that takes enough breaks, and its model is hidden", crates[0].gone and not crates[0].model.visible and low.standing() == 2)
	_check("the collider of its stack fits what is left at once", is_equal_approx(low_collider.shape.size.y, crates[1].height + crates[2].height)
		and is_equal_approx(low_collider.position.y, (crates[1].height + crates[2].height) * 0.5))
	_check("a hit where it stood hurts none of the crates that have yet to come down", crates.slice(1).all(func(crate: RefCounted) -> bool:
		return crate.health == low.TUNING[crate.kind].health))
	await _wait(0.5)
	var first_pieces: Array = made.duplicate()
	_check("it lies about in pieces, all that a crate is cut into", not first_pieces.is_empty() and first_pieces.size() == stack_script.pieces_of(crates[0].model).size()
		and stack_script.pieces() >= first_pieces.size())
	_check("and the crates above it come down by its height", crates.slice(1).all(func(crate: RefCounted) -> bool:
		return crate.model.visible and is_equal_approx(crate.rest.y - crate.model.global_position.y, crates[0].height)))

	# A hall lamp that is on, shot at from the floor below it.
	var lamp: StaticBody3D = null
	var feet := Vector3.INF
	var glass := Vector3.ZERO
	for one: StaticBody3D in lamps:
		if one.kind != one.Kind.HALL or one.light == null or one.out:
			continue
		glass = (one.get_child(0) as Node3D).global_position
		var below := space.intersect_ray(PhysicsRayQueryParameters3D.create(glass, glass + Vector3.DOWN * 20.0, 1))
		feet = _stand_for(player, one, glass, 2.0, below.position.y if below else 0.0)
		if feet != Vector3.INF:
			lamp = one
			break
	_check("there is a hall lamp to shoot at from the floor", lamp != null)
	if lamp:
		var bursts: int = Fx._expiring.size()
		await _aim(player, feet, glass)
		Input.action_press("fire")
		await _wait(0.1)
		Input.action_release("fire")
		_check("a rifle shot puts a hall lamp out: there is nothing left to hit, and glass and sparks come down", lamp.out and lamp.collision_layer == 0
			and Fx._expiring.size() >= bursts + 3)
		await _wait(0.4)
		var eye: Vector3 = player.camera.global_position
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + (glass - eye) * 1.2, weapons.HIT_MASK, [player.get_rid()]))
		_check("its light has gone, nothing of it glows, and the next shot finds nothing there", not lamp.light.visible and not _glows(lamp._model)
			and (hit.is_empty() or hit.collider != lamp))

	# A stack of three, from a few steps away: first a shot into the floor in
	# front of it, then the top crate.
	var shot: StaticBody3D = null
	var top := Vector3.ZERO
	for one: StaticBody3D in threes:
		top = one._members[2].model.global_transform * stack_script.box_of(one._members[2].model).get_center()
		feet = _stand_for(player, one, top, 3.5, one.global_position.y)
		if feet != Vector3.INF:
			shot = one
			threes.erase(one)
			break
	_check("there is a stack of three crates to shoot at", shot != null)
	if shot:
		crates = shot._members
		await _aim(player, feet, (feet + top) * 0.5 * Vector3(1, 0, 1) + Vector3.UP * feet.y)
		Input.action_press("fire")
		await _wait(0.06)
		Input.action_release("fire")
		await _wait(0.25)
		_check("a shot that lands beside a stack breaks nothing", whole.call(shot) and weapons._mags[0] < 30)
		await _aim(player, feet, top)
		var loaded: int = weapons._mags[0]
		for i in 8:
			Input.action_press("fire")
			await _wait(0.06)
			Input.action_release("fire")
			await _wait(0.24)
			if crates[2].gone:
				break
		print("    the top crate of a stack of three took %d rifle rounds" % (loaded - weapons._mags[0]))
		var collider: CollisionShape3D = shot._colliders[0]
		_check("rifle rounds into the top crate of a stack break that one, and the collider is a crate lower", crates[2].gone and not crates[2].model.visible
			and not crates[0].gone and not crates[1].gone and is_equal_approx(collider.shape.size.y, crates[0].height + crates[1].height)
			and is_equal_approx(collider.position.y, (crates[0].height + crates[1].height) * 0.5))

	# A stack that stands on another: the crate it stands on goes.
	_check("there is a stack that stands on another", not towers.is_empty())
	if not towers.is_empty():
		var tower: StaticBody3D = towers[0]
		crates = tower._members
		var under: int = crates.filter(func(crate: RefCounted) -> bool: return crate.collider == 0).size() - 1
		var upper: CollisionShape3D = tower._colliders[1]
		var stood: float = upper.position.y
		var lay: float = sleeper.global_position.y
		sleeper.sleeping = true
		tower.take_damage(1000.0, tower.global_position + Vector3.UP * (crates[under].foot + crates[under].height * 0.5), Vector3.FORWARD)
		await _wait(0.5)
		_check("breaking the crate it stands on brings that stack down too", crates[under].gone and tower.standing() == tower.size() - 1
			and is_equal_approx(stood - upper.position.y, crates[under].height)
			and crates.slice(under + 1).all(func(crate: RefCounted) -> bool: return is_equal_approx(crate.rest.y - crate.model.global_position.y, crates[under].height)))
		var highest: RefCounted = crates[-1]
		_check("and what lay asleep on top of it comes down with it", absf(lay - tower.global_position.y - highest.foot - highest.height - 0.1) < 0.02
			and absf(lay - sleeper.global_position.y - crates[under].height) < 0.02)
		sleeper.free()

	# What somebody is told who comes into the level later: the same stack
	# and the same lamp, with nothing flying.
	var late: StaticBody3D = threes.pop_back()
	var dark: StaticBody3D = lamps.filter(func(one: Node) -> bool: return one.light != null and not one.out and one.kind != one.Kind.HALL)[0]
	var lying: int = made.size()
	var playing: int = Fx._expiring.size()
	late.net_restore(low.net_state())
	dark.net_restore(1)
	var quiet: bool = Fx._expiring.size() == playing
	# Pieces are thrown when the frame is over, if any were.
	await tree.process_frame
	await tree.process_frame
	crates = late._members
	var late_collider: CollisionShape3D = late._colliders[0]
	_check("a stack that was broken before somebody came stands the same for them, with no pieces", low.net_state() == 1 and late.net_state() == 1
		and not crates[0].model.visible and is_equal_approx(late_collider.shape.size.y, crates[1].height + crates[2].height)
		and is_equal_approx(late_collider.position.y - late_collider.shape.size.y * 0.5, low_collider.position.y - low_collider.shape.size.y * 0.5)
		and crates.slice(1).all(func(crate: RefCounted) -> bool: return is_equal_approx(crate.rest.y - crate.model.global_position.y, crates[0].height))
		and made.size() == lying)
	_check("and a lamp that was shot out is dark for them, with no glass and no sparks", dark.out and dark.collision_layer == 0 and not dark.light.visible
		and dark._covers.all(func(cover: Node3D) -> bool: return cover.visible) and not dark._covers.is_empty() and quiet)

	# The pieces of the first crate, once their time is up: those and no
	# others, and not because there were more than there may be.
	var left: float = stack_script.PIECE_TIME + stack_script.SHRINK_TIME + 0.3 - (Time.get_ticks_msec() - began) / 1000.0
	if left > 0.0:
		await _wait(left)
	_check("pieces are cleared away when their time is up", first_pieces.all(func(piece: Variant) -> bool: return not is_instance_valid(piece))
		and made.size() > first_pieces.size() and made.size() <= stack_script.MAX_PIECES and made.slice(first_pieces.size()).all(is_instance_valid))

	# A blast beside the largest pile there is, which breaks more crates than
	# may all lie about in pieces.
	var piles := stacks.filter(whole)
	piles.sort_custom(func(a: Node, b: Node) -> bool: return a.size() > b.size())
	var blown: StaticBody3D = piles[0]
	var middle: Vector3 = (blown._colliders[0] as Node3D).global_position
	var beside := middle + Vector3(0.9, 0.0, 0.0)
	for turn in 4:
		beside = middle + Vector3(0.9, 0.0, 0.0).rotated(Vector3.UP, turn * PI * 0.5)
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(beside, middle, 1, [blown.get_rid()])).is_empty():
			break
	var standing: Array = []
	for stack: Node in game._breakables:
		if stack.has_method("cover"):
			standing.append_array(stack._members.filter(func(crate: RefCounted) -> bool: return not crate.gone))
	var before: int = made.size()
	Blast.explode(beside, 6.5, 150.0)
	# The pieces are thrown when the frame is over; what the blast broke is
	# counted before anything it set alight can go off.
	await tree.process_frame
	await tree.process_frame
	var broke := standing.filter(func(crate: RefCounted) -> bool: return crate.gone)
	var thrown: int = made.size() - before
	@warning_ignore("integer_division")
	var share: int = stack_script.MAX_PIECES / maxi(broke.size(), 1)
	var whole_pieces := 0
	var shared := 0
	for crate: RefCounted in broke:
		whole_pieces += stack_script.pieces_of(crate.model).size()
		shared += mini(stack_script.pieces_of(crate.model).size(), share)
	await _wait(0.2)
	_check("a blast beside a stack breaks every crate of it, and it is in nobody's way after that", blown.standing() == 0 and blown.collision_layer == 0
		and blown._members.all(func(crate: RefCounted) -> bool: return not crate.model.visible))
	print("    the blast broke %d crates and boxes, which are cut into %d pieces and left %d, %d each at most" % [broke.size(), whole_pieces, thrown, share])
	_check("a blast that breaks more than may lie about in pieces leaves as many of every crate", whole_pieces > stack_script.MAX_PIECES and thrown == shared)
	print("    at most %d pieces lay about at once, of the %d there may be" % [most[0], stack_script.MAX_PIECES])
	_check("there are never more pieces than there may be", most[0] > 0 and most[0] <= stack_script.MAX_PIECES
		and made.filter(is_instance_valid).size() <= stack_script.MAX_PIECES)
	tree.node_added.disconnect(note)
	_finished.append("breakables")


## Counts what can be shot to pieces in a level, and checks that nothing of
## the kind was left out.
func _inventory(game: Node, title: String) -> void:
	var level: Node3D = game.get_node("Level")
	var stack_script: GDScript = game.BREAKABLES.STACK
	var stacks: Array = game._breakables.filter(func(body: Node) -> bool: return body.has_method("cover"))
	var lamps: Array = game._breakables.filter(func(body: Node) -> bool: return body.has_method("lens"))
	# How many stacks each model is part of, and how many colliders there are
	# of crates.
	var held := {}
	var piles := {}
	var cartons := 0
	for stack: Node in stacks:
		for member: RefCounted in stack._members:
			held[member.model] = held.get(member.model, 0) + 1
			if member.kind == stack.Kind.CRATE:
				piles[stack._colliders[member.collider]] = true
			else:
				cartons += 1
	var colliders: Array[CollisionShape3D] = []
	for collider in level.get_node("Collision").get_children():
		if collider is CollisionShape3D and collider.shape is BoxShape3D:
			colliders.append(collider)
	var inverses := colliders.map(func(collider: CollisionShape3D) -> Transform3D: return collider.global_transform.affine_inverse())
	var loose := 0
	var covered := 0
	for model: Node3D in level.find_children("*", "Node3D", true, false):
		var folder := model.scene_file_path.get_base_dir().get_file()
		if folder != "wooden_crate_02" and folder != "cardboard_box_01":
			continue
		if held.get(model, 0) != 1:
			loose += 1
			print("    not in one stack: %s" % level.get_path_to(model))
		var middle: Vector3 = model.global_transform * stack_script.box_of(model).get_center()
		for i in colliders.size():
			var offset: Vector3 = (inverses[i] as Transform3D) * middle
			var half: Vector3 = colliders[i].shape.size * 0.5
			if absf(offset.x) < half.x and absf(offset.y) < half.y and absf(offset.z) < half.z:
				covered += 1
				print("    still in the body of the level: %s around %s" % [colliders[i].name, level.get_path_to(model)])
	# The lights that are lamps, by what their names begin with.
	var classes := {"HallLamp": "SpotLight3D", "Bulb": "OmniLight3D", "Tube": "OmniLight3D", "Floodlight": "SpotLight3D", "WorkLamp": "SpotLight3D"}
	var unlit := 0
	for light: Light3D in level.find_children("*", "Light3D", true, false):
		if light.get_parent().name != &"Lights":
			continue
		for prefix: String in classes:
			if String(light.name).begins_with(prefix) and light.is_class(classes[prefix]) and lamps.filter(func(lamp: Node) -> bool: return lamp.light == light).size() != 1:
				unlit += 1
				print("    no lamp around %s" % level.get_path_to(light))
	var of_kind := func(kind: int, lit: bool) -> int:
		return lamps.filter(func(lamp: Node) -> bool: return lamp.kind == kind and (lamp.light != null) == lit).size()
	var kinds: Dictionary = game.BREAKABLES.LAMP.Kind
	print("    %s: %d stacks of crates and %d cardboard boxes in %d piles; %d hall lamps on and %d off, %d bulbs, %d tubes, %d floodlights, %d work lamps" % [title,
		piles.size(), cartons, stacks.size(), of_kind.call(kinds.HALL, true), of_kind.call(kinds.HALL, false), of_kind.call(kinds.BULB, true),
		of_kind.call(kinds.TUBE, true), of_kind.call(kinds.FLOOD, true), of_kind.call(kinds.WORK, true)])
	_check("%s: every crate and every cardboard box is part of one stack that can be shot to pieces" % title, loose == 0 and not stacks.is_empty())
	_check("%s: and no collider of theirs is left in the body of the level" % title, covered == 0)
	_check("%s: every lamp that is on can be shot out" % title, unlit == 0 and not lamps.is_empty())


## A spot on the floor at the height `floor_y` to shoot at `target` from,
## `reach` metres to the side of it, with nothing between the eye and `body`.
## Vector3.INF if there is none.
func _stand_for(player: CharacterBody3D, body: CollisionObject3D, target: Vector3, reach: float, floor_y: float) -> Vector3:
	var map := player.get_world_3d().navigation_map
	var space := player.get_world_3d().direct_space_state
	for turn in 8:
		var spot := Vector3(target.x, floor_y, target.z) + Vector3(reach, 0.0, 0.0).rotated(Vector3.UP, turn * TAU / 8.0)
		var feet := NavigationServer3D.map_get_closest_point(map, spot)
		if feet.distance_to(spot) > 0.5:
			continue
		var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.5, feet + Vector3.DOWN, 1))
		if ground:
			feet = ground.position
		var eye := feet + Vector3.UP * 1.6
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + (target - eye) * 1.2, player.weapons.HIT_MASK, [player.get_rid()]))
		if hit and hit.collider == body:
			return feet
	return Vector3.INF


## Stands the player at `feet`, looking at `target`, and gives the weapon a
## moment to come to rest.
func _aim(player: CharacterBody3D, feet: Vector3, target: Vector3) -> void:
	_move(player, feet)
	player.look_at(Vector3(target.x, feet.y, target.z))
	await _wait(0.2)
	var eye: Vector3 = player.camera.global_position
	player.head.rotation.x = atan2(target.y - eye.y, Vector2(target.x - eye.x, target.z - eye.z).length())
	await _wait(0.1)


## True if any surface of a mesh is drawn with a material that gives light.
func _glows(mesh: MeshInstance3D) -> bool:
	for surface in mesh.mesh.get_surface_count():
		var material := mesh.get_active_material(surface) as BaseMaterial3D
		if material and material.emission_enabled:
			return true
	return false


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
	_inventory(game, title)

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
	# Whether the shade has been tried on a watch of this level, see _try_watch().
	var watch_tried := false
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
			if here.watched:
				# A watch is not switched off, and is not started by walking in.
				_check("%s: the robots of %s keep watch and know of nothing" % [title, here.title], not here.started
					and _kinds(robots) == _roster(game, here) and _on_watch(robots))
				_move(player, entries.get(here.id, Vector3.ZERO))
				await _wait(0.3)
				_check("%s: walking in starts nothing where a watch is kept" % title, not here.started
					and robots.all(func(robot: Node) -> bool: return robot.can_process()))
				if not watch_tried and await _try_watch(game, here, title):
					watch_tried = true
				else:
					robots[0].take_damage(1.0, robots[0].global_position + Vector3.UP, Vector3.DOWN)
					await _wait(0.3)
					_check("%s: a shot at one of them starts their fight" % title, here.fighting())
				var fallen: int = game.kills
				for robot in robots:
					robot.take_damage(1e6, robot.global_position, Vector3.DOWN)
				await _wait(0.2)
				_check("%s: and is cleared when they are down" % title, here.cleared and not game.fighting() and game.kills == fallen + robots.size())
				continue
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


## True if every zone has the robots it lists standing at their posts, or
## keeping watch where the level has a watch kept.
func _all_posted(game: Node) -> bool:
	for zone: RefCounted in game.zones:
		if _kinds(zone.robots) != _roster(game, zone):
			return false
		if not (_on_watch(zone.robots) if zone.watched else _waiting(zone.robots, _spawns(zone))):
			return false
	return not game.zones.is_empty()


## True if those robots keep watch and none of them knows of anything. They
## are not switched off, and one that walks a beat is not where it was posted.
func _on_watch(robots: Array) -> bool:
	return not robots.is_empty() and robots.all(func(robot: Node) -> bool: return robot.is_watching())


## Tries the shade on the watch of a zone: somebody who stands in the shade
## in front of one of its guards is not seen, and somebody who stands in the
## light there is, which starts their fight. It takes a guard that stands
## still with a spot of each kind in front of it; false if this zone has
## none, and then nothing was tried.
func _try_watch(game: Node, zone: RefCounted, title: String) -> bool:
	var land: Node = load("res://scripts/land.gd").of(get_tree())
	if land == null:
		return false
	var space: PhysicsDirectSpaceState3D = game.player.get_world_3d().direct_space_state
	for guard: Node3D in zone.robots:
		if not guard._round.is_empty():
			continue
		var ahead := Vector3(-sin(guard._guards), 0.0, -cos(guard._guards))
		var eye: Vector3 = guard.global_position + Vector3.UP * guard.eye_height
		var spots := {true: Vector3.INF, false: Vector3.INF}
		for reach: float in [12.0, 14.0, 10.0, 16.0, 18.0]:
			for turn: float in [0.0, 0.15, -0.15, 0.3, -0.3, 0.45, -0.45]:
				var floor_ray := PhysicsRayQueryParameters3D.create(guard.global_position + ahead.rotated(Vector3.UP, turn) * reach + Vector3.UP * 20.0, guard.global_position + ahead.rotated(Vector3.UP, turn) * reach + Vector3.DOWN * 20.0, 1)
				var floor_hit := space.intersect_ray(floor_ray)
				if floor_hit.is_empty() or not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, floor_hit.position + Vector3.UP * 1.35, 1)).is_empty():
					continue
				var shade: float = land.shade_around(floor_hit.position)
				if (shade > 0.9 or shade < 0.1) and spots[shade > 0.5] == Vector3.INF:
					spots[shade > 0.5] = floor_hit.position
		if spots[true] == Vector3.INF or spots[false] == Vector3.INF:
			continue
		# It looks straight ahead for as long as this takes, and the others of
		# its watch stand still: this is about what one guard sees.
		guard._looks = 0.0
		guard._look = guard._guards
		guard._wait = 1e6
		var others: Array = zone.robots.filter(func(robot: Node) -> bool: return robot != guard)
		for other: Node in others:
			other.set_physics_process(false)
		await _wait(0.8)
		_move(game.player, spots[true])
		await _wait(guard.notice_time + 1.0)
		_check("%s: somebody who stands in the shade is not seen by the watch" % title, not zone.started and guard.awareness < 0.05)
		_move(game.player, spots[false])
		await _wait(guard.notice_time + 0.8)
		_check("%s: somebody who stands in the light is, and that starts their fight" % title, zone.fighting() and guard.is_alert())
		for other: Node in others:
			if is_instance_valid(other):
				other.set_physics_process(true)
		return true
	return false


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
