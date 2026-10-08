extends Node
## Headless gameplay smoke test. Run with: tools/selftest.sh
##
## Drives the real player through simulated input and checks that the core
## loop still works: navmesh, slide, shooting, enemy AI and weapon switching.

var _failures := 0


func _ready() -> void:
	if "--selftest" in OS.get_cmdline_user_args():
		_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	# A script error would otherwise leave the run hanging forever.
	tree.create_timer(60.0, true, true).timeout.connect(
		func() -> void:
			print("SELFTEST FAILED (timed out)")
			tree.quit(1)
	)
	await _wait(0.5)
	var game := tree.current_scene
	var player: CharacterBody3D = game.player
	var weapons: Node3D = player.weapons
	player.force_control = true

	var navmesh: NavigationMesh = game.nav_region.navigation_mesh
	_check("navmesh is baked", navmesh.get_polygon_count() > 0)
	var enemies := tree.get_nodes_in_group("enemy")
	_check("first wave spawned", enemies.size() == 3 and game.wave == 1)

	var map := player.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, enemies[0].global_position, player.global_position, true)
	_check("enemy can path to player", path.size() > 1)
	var top := NavigationServer3D.map_get_path(map, Vector3(-12, 2.5, -10), player.global_position, true)
	_check("platform connects via ramp", top.size() > 1 and top[0].y > 2.0)

	var start_distances := {}
	for e in enemies:
		start_distances[e] = e.global_position.distance_to(player.global_position)

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

	# Enemy AI: it should notice the player, close in and deal damage.
	var enemy: CharacterBody3D = enemies[0]
	await _wait(4.0)
	_check("enemies approach", enemies.any(
		func(e: Node3D) -> bool:
			return e.global_position.distance_to(player.global_position) < start_distances[e] - 3.0
	))
	_check("enemies damage the player", player.health < player.MAX_HEALTH)
	player.health = 1e6

	# Shooting: face the enemy from close range and hold the trigger.
	for other in enemies:
		other.set_physics_process(false)
	player.global_position = enemy.global_position + Vector3(0, 0, 6)
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
	Input.action_press("ads")
	await _wait(0.4)
	_check("aiming zooms the camera", weapons.ads_blend == 1.0 and player.camera.fov < 70.0)
	Input.action_release("ads")

	print("SELFTEST %s" % ("PASSED" if _failures == 0 else "FAILED (%d)" % _failures))
	tree.quit(1 if _failures else 0)


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
