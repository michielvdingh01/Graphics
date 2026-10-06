extends Node
## Headless gameplay smoke test. Run with tools/smoke_test.sh (uses --fixed-fps so time is simulated).
## Exercises the full chain: firing, damage, kills, weapon switching, reload, crouch, slide,
## enemy navigation and attack, player death and respawn.

var _failures := 0
var _hit_events: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	print("%s  %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await _frames(int(seconds * 60.0))


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await _frames(5)

	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	var wm := player.get_node("Head/Camera3D/WeaponManager") as WeaponManager
	var arena := get_tree().get_first_node_in_group("arena") as Arena
	wm.hit_confirmed.connect(func(kind: String) -> void: _hit_events.append(kind))
	_check(wm.current.id == "rifle", "starts with the rifle")

	# --- firing and damage ---------------------------------------------------------------
	var mag_before: int = wm._mag[0]
	wm._fire()
	_check(wm._mag[0] == mag_before - 1, "firing consumes one round")

	var target := arena._add_enemy(Vector3(0, 0, 12), 0.0, true)
	await _frames(3)
	var start_health := target.health
	for i in 3:
		wm._fire()
	await _frames(2)
	_check(target.health < start_health, "rifle hits reduce enemy health (%.0f -> %.0f)" % [start_health, target.health])
	_check(not _hit_events.is_empty(), "hit_confirmed fires (%s)" % ",".join(_hit_events))
	for i in 30:
		if target.state == Enemy.State.DEAD:
			break
		wm._fire()
	_check(target.state == Enemy.State.DEAD, "sustained fire kills the enemy")
	_check(arena.kills == 1, "arena counts the kill")
	_check("kill" in _hit_events, "kill feedback is emitted")

	# --- shotgun pellets -----------------------------------------------------------------
	wm._request_switch(2)
	await _seconds(0.7)
	_check(wm.current.id == "shotgun", "switches to the shotgun")
	var pellet_target := arena._add_enemy(Vector3(0, 0, 14), 0.0, true)
	await _frames(3)
	var pellet_start := pellet_target.health
	wm._fire()
	await _frames(2)
	_check(pellet_target.health < pellet_start, "shotgun pellets deal damage (%.0f -> %.0f)" % [pellet_start, pellet_target.health])
	pellet_target.queue_free()

	# --- pistol reload -------------------------------------------------------------------
	wm._request_switch(1)
	await _seconds(0.7)
	_check(wm.current.id == "pistol", "switches to the pistol")
	wm._mag[1] = 3
	var reserve_before: int = wm._reserve[1]
	wm._start_reload()
	_check(wm.is_reloading(), "reload starts")
	await _seconds(current_reload_seconds(wm) + 0.3)
	_check(wm._mag[1] == wm.current.mag_size, "reload refills the magazine")
	_check(wm._reserve[1] == reserve_before - (wm.current.mag_size - 3), "reload takes ammo from reserve")

	# --- movement ------------------------------------------------------------------------
	Input.action_press("crouch")
	await _seconds(0.6)
	_check(player.crouched and player._height < 1.3, "crouch lowers the capsule (%.2f m)" % player._height)
	Input.action_release("crouch")
	await _seconds(0.6)
	_check(not player.crouched and player._height > 1.75, "standing up restores the capsule")

	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _seconds(1.2)
	_check(player.speed_h > 6.5, "sprinting reaches speed (%.1f m/s)" % player.speed_h)
	Input.action_press("crouch")
	await _frames(2)
	_check(player.sliding, "crouch while sprinting starts a slide")
	await _seconds(0.3)
	_check(player.speed_h > 8.0, "slide is faster than sprint (%.1f m/s)" % player.speed_h)
	Input.action_release("crouch")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _seconds(1.5)
	_check(not player.sliding, "slide ends")

	# --- enemies navigate and attack -----------------------------------------------------
	# Natural spawning first: the arena must produce live enemies once the navmesh is baked.
	player.global_position = Vector3(0, 0.05, 20)
	player.velocity = Vector3.ZERO
	arena._clear_enemies()
	await _frames(2)
	var spawned: Array = []
	for i in 40:
		await _seconds(0.25)
		spawned = get_tree().get_nodes_in_group("enemy").filter(func(e: Node) -> bool: return not e.frozen and e.state != Enemy.State.DEAD)
		if not spawned.is_empty():
			break
	_check(not spawned.is_empty(), "arena spawns enemies after the navmesh bakes (%d)" % spawned.size())

	# Then a controlled run: one enemy from the far corner must path around the obstacles.
	arena._clear_enemies()
	arena._ready_to_spawn = false
	await _frames(2)
	player.health = player.MAX_HEALTH
	var enemy := arena._add_enemy(Vector3(-24, 0, -24), 0.0, false)
	var start_distance := enemy.global_position.distance_to(player.global_position)
	enemy._alert()
	var health_before: float = player.health
	var closest := start_distance
	# Poll until the enemy has shot the player (or time runs out); a long fight could kill
	# the player, which would respawn and clear the arena.
	for i in 80:
		await _seconds(0.25)
		if not is_instance_valid(enemy):
			break
		closest = minf(closest, enemy.global_position.distance_to(player.global_position))
		if player.health < health_before:
			break
	_check(closest < start_distance - 15.0, "enemy paths around obstacles (%.1f m -> %.1f m)" % [start_distance, closest])
	_check(player.health < health_before, "enemy shots damage the player (%.0f -> %.0f)" % [health_before, player.health])
	arena._ready_to_spawn = true

	# --- death and respawn ---------------------------------------------------------------
	player.take_damage(1000.0, Vector3.ZERO)
	_check(player.dead, "player dies at zero health")
	await _seconds(3.0)
	_check(not player.dead and player.health == player.MAX_HEALTH, "player respawns with full health")
	_check(wm._mag[0] == wm._weapons[0].mag_size, "loadout resets on respawn")

	print("\nsmoke test: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(_failures)


func current_reload_seconds(wm: WeaponManager) -> float:
	return wm.current.reload_time
