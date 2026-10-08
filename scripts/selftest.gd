extends Node
## Headless gameplay smoke test. Run with: tools/selftest.sh
##
## Drives the real player through simulated input and checks that the core
## loop still works: navmesh, slide, shooting, enemy AI, weapon switching,
## enemy types, checkpoints and settings.

## Spots in the factory level: on the mezzanine deck, and an open lane with
## 6 m of clear floor to the east of it.
const MEZZANINE := Vector3(-10, 3.2, -9.5)
const RANGE_TARGET := Vector3(1, 0, -7.5)

## True for a self-test run; menus and saved progress stay out of the way.
var active := false

var _failures := 0


func _ready() -> void:
	active = "--selftest" in OS.get_cmdline_user_args()
	if active:
		_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	# A script error would otherwise leave the run hanging forever.
	tree.create_timer(120.0, true, true).timeout.connect(
		func() -> void:
			print("SELFTEST FAILED (timed out)")
			tree.quit(1)
	)
	await _wait(0.5)
	var game := tree.current_scene
	var player: CharacterBody3D = game.player
	var weapons: Node3D = player.weapons
	player.force_control = true
	# Health regenerates, so count hits instead of comparing health later.
	var hits := [0]
	player.damaged.connect(func(_amount: float) -> void: hits[0] += 1)

	var navmesh: NavigationMesh = game.nav_region.navigation_mesh
	_check("navmesh is baked", navmesh.get_polygon_count() > 0)
	var enemies := tree.get_nodes_in_group("enemy")
	_check("first wave spawned", enemies.size() == 3 and game.wave == 1)

	var map := player.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, enemies[0].global_position, player.global_position, true)
	_check("enemy can path to player", path.size() > 1)
	var top := NavigationServer3D.map_get_path(map, MEZZANINE, player.global_position, true)
	_check("mezzanine connects via stairs", top.size() > 1 and top[0].y > 2.5 and top[-1].distance_to(player.global_position) < 1.0)

	# Sprint, then slide.
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

	# Enemy AI: the wave should come looking for the player, wherever it
	# spawned, close in and deal damage. The player stands still from here on.
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

	# Enemy types and wave make-up.
	_check("first wave is all grunts", game.roster(1).all(func(s: PackedScene) -> bool: return s == game.GRUNT))
	var later: Array[PackedScene] = game.roster(4)
	_check("later waves mix in rushers and heavies", later.has(game.RUSHER) and later.has(game.HEAVY))
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

	# Checkpoints and settings.
	var checkpoint: Dictionary = Save.resume_point(game.scene_file_path)
	_check("wave start is a checkpoint", checkpoint.get("wave", 0) == game.wave)
	var environment: Environment = game.get_viewport().find_world_3d().environment
	Settings.put("quality", 0)
	_check("low quality switches effects off", not environment.ssr_enabled and not environment.volumetric_fog_enabled)
	Settings.put("quality", 2)
	_check("high quality restores them", environment.ssr_enabled and environment.volumetric_fog_enabled)
	Settings.put("upscaler", Viewport.SCALING_3D_MODE_FSR2)
	Settings.put("render_scale", 0.67)
	_check("upscaler applies to the viewport", game.get_viewport().scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2
		and is_equal_approx(game.get_viewport().scaling_3d_scale, 0.67))

	# Every level: loads, bakes a navmesh and has spawns the enemies can leave.
	for level in Menu.LEVELS:
		tree.change_scene_to_file(level.scene)
		await tree.scene_changed
		await _wait(0.5)
		game = tree.current_scene
		var region: NavigationMesh = game.nav_region.navigation_mesh
		_check("%s: navmesh is baked" % level.name, region.get_polygon_count() > 0)
		var nav_map: RID = game.player.get_world_3d().navigation_map
		var goal: Vector3 = game.player.global_position
		var stranded := 0
		for spawn: Node3D in tree.get_nodes_in_group("enemy_spawn"):
			var route := NavigationServer3D.map_get_path(nav_map, spawn.global_position, goal, true)
			if route.size() < 2 or route[0].distance_to(spawn.global_position) > 1.0 or route[-1].distance_to(goal) > 1.0:
				stranded += 1
				print("    stranded spawn: ", spawn.name)
		_check("%s: every spawn reaches the player" % level.name, stranded == 0)

	print("SELFTEST %s" % ("PASSED" if _failures == 0 else "FAILED (%d)" % _failures))
	tree.quit(1 if _failures else 0)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
