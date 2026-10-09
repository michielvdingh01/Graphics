extends Node
## Headless gameplay smoke test. Run with: tools/selftest.sh
##
## Drives the real player through simulated input and checks that the core
## loop still works: navmesh, slide, shooting, enemy AI, weapon switching,
## enemy types, explosives, grenades and settings. Then it goes through every
## level along its route, from the start to the exit and on into the next:
## that the route can be walked over the navmesh, that every spawn point can
## reach the player and is out of sight when its robot appears, that a zone
## brings out the robots it lists, and that a checkpoint is still there after
## a restart of the game and after a death.

## Spots in the factory level: on the mezzanine deck, an open lane with 6 m
## of clear floor to the east of it, and a stretch of floor to sprint along.
const MEZZANINE := Vector3(-10, 3.2, -9.5)
const RANGE_TARGET := Vector3(1, 0, -7.5)
const RUNWAY := Vector3(17.5, 0, 5.5)
## A robot may appear in sight of where the player walks into its zone, but
## not closer than this.
const SPAWN_DISTANCE := 14.0
## Distance in metres between the points a route is sampled at.
const STRIDE := 0.5

## True for a self-test run; menus and saved progress stay out of the way.
var active := false

var _failures := 0
var _routes_only := false


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
	if not _routes_only:
		await _handling()

	# Every level, in the order they are played, each entered the way the
	# game enters it: the first from the menu, the rest through an exit.
	Save.clear()
	tree.change_scene_to_file(Menu.LEVELS[0].scene)
	await tree.scene_changed
	for i in Menu.LEVELS.size():
		await _wait(0.5)
		await _play_through(Menu.LEVELS[i], Menu.LEVELS[i + 1].scene if i + 1 < Menu.LEVELS.size() else "")

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
	_check("the level starts quiet, with the player at its start", tree.get_nodes_in_group("enemy").is_empty()
		and not game.fighting() and player.global_position.distance_to(game.start.origin) < 0.5)
	var first: RefCounted = game.zones[0]
	_check("the HUD is told where to go", game.objective == "Reach %s" % first.title)

	var map := player.get_world_3d().navigation_map
	var top := NavigationServer3D.map_get_path(map, MEZZANINE, player.global_position, true)
	_check("mezzanine connects via stairs", top.size() > 1 and top[0].y > 2.5 and top[-1].distance_to(player.global_position) < 1.0)

	# The part that tests how things handle goes all over the hall; only the
	# first zone is left to notice.
	for zone: RefCounted in game.zones:
		zone.area.set_deferred("monitoring", zone == first)
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

	# A fight: walking into a zone brings out the robots it lists, and no others.
	var entries := _entries(game, _walk(game))
	_move(player, entries.get(first.id, Vector3.ZERO))
	await _wait(0.3)
	var enemies := tree.get_nodes_in_group("enemy")
	_check("walking into a zone starts its fight", first.fighting() and game.objective == "Clear %s" % first.title)
	_check("with the robots that zone lists", not enemies.is_empty() and _kinds(enemies) == _roster(game, first))
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
	_check("a grenade is thrown", weapons.grenades == weapons.GRENADES - 1 and thrown.size() == 1)
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
	_check("%s: starts quiet, with the player at its start" % title, tree.get_nodes_in_group("enemy").is_empty()
		and game.player.global_position.distance_to(game.start.origin) < 0.5)
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
				print("    %s/%s: %.1f m from where the zone is entered, %s" % [zone.id, spawn.name, eye.distance_to(at), "in view" if seen else "hidden"])
			if eye.distance_to(at) < SPAWN_DISTANCE and seen:
				exposed += 1
				print("    spawn in view: %s/%s at %.1f m" % [zone.id, spawn.name, eye.distance_to(at)])
	_check("%s: every spawn point reaches the player" % title, stranded == 0)
	_check("%s: no robot appears close by and in view" % title, exposed == 0)
	var misplaced := 0
	for checkpoint: RefCounted in game.checkpoints:
		for zone: RefCounted in game.zones:
			if zone.order > checkpoint.order and _box(zone.area).has_point(checkpoint.pose.origin + Vector3.UP):
				misplaced += 1
	_check("%s: no checkpoint lies in a zone that comes after it" % title, misplaced == 0)

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
			_move(player, entries.get(here.id, Vector3.ZERO))
			await _wait(0.3)
			var robots := tree.get_nodes_in_group("enemy")
			_check("%s: %s brings out the robots it lists" % [title, here.title], here.fighting() and _kinds(robots) == _roster(game, here))
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
				quiet = quiet and tree.get_nodes_in_group("enemy").is_empty()
		_check("%s: and what was cleared before it stays cleared" % title, quiet)
		_move(game.player, again.pose.origin)
		await _wait(0.2)

	# And out.
	var lamp := game.exit.get_node_or_null("Lamp") as Node3D
	_check("%s: the exit opens when every zone is cleared" % title, game.exit_open and (lamp == null or lamp.visible)
		and game.objective == game.exit.get_meta(&"title"))
	var left := []
	game.finished.connect(func(to: String) -> void: left.append(to))
	if not walk.is_empty():
		_move(game.player, walk[-1])
	await _wait(0.3)
	_check("%s: walking into it leaves the level" % title, left == [next] and game.next_level() == next)
	if next:
		await tree.scene_changed
		_check("%s: and the next one starts from its beginning" % title, tree.current_scene.scene_file_path == next
			and Save.resume_point(next).get("at", "?") == "")
	else:
		_check("%s: and that is the end of the game" % title, Save.checkpoint.is_empty())


## The way from the start past every checkpoint to the exit, as points
## STRIDE apart over the navmesh; empty if a stretch of it cannot be walked.
func _walk(game: Node) -> PackedVector3Array:
	var map: RID = game.player.get_world_3d().navigation_map
	var stops: Array[Vector3] = [game.start.origin]
	for checkpoint: RefCounted in game.checkpoints:
		stops.append(checkpoint.pose.origin)
	# The exit is a box; make for the floor in the middle of it.
	var out := _box(game.exit)
	var door := NavigationServer3D.map_get_closest_point(map, Vector3(out.get_center().x, out.position.y, out.get_center().z))
	if not out.grow(0.3).has_point(door):
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


## The box of a zone, a checkpoint or an exit.
func _box(area: Area3D) -> AABB:
	var size: Vector3 = (area.get_child(0) as CollisionShape3D).shape.size
	return AABB(area.global_position - size * 0.5, size)


func _spawns(zone: RefCounted) -> Array:
	return zone.area.get_children().filter(func(node: Node) -> bool: return node.is_in_group("enemy_spawn"))


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


## True if a robot standing at `spot` shows from `eye`: its head or its middle.
func _in_view(space: PhysicsDirectSpaceState3D, eye: Vector3, spot: Vector3) -> bool:
	for height: float in [1.5, 0.8]:
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, spot + Vector3.UP * height, 1)).is_empty():
			return true
	return false


func _move(player: CharacterBody3D, to: Vector3) -> void:
	player.global_position = to
	player.velocity = Vector3.ZERO


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
