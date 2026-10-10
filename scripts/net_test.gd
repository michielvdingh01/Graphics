extends Node
## Test of playing together. Run with: tools/nettest.sh
##
## That starts the game twice on this machine, without a window. Both come up
## on the title screen and go by the menu, as players do: one hosts the
## factory and the other joins it at 127.0.0.1. Each checks its own side of
## the same story: a latecomer finds the level as it stands, the two see each
## other walk, the guest's shots count on the host and the host's robots hurt
## the guest, a grenade and a barrel go off on both, a death is not the end,
## the level only ends with both at the exit, with both down the next one
## starts again for both, whoever leaves is gone for the other, and whoever
## comes back to a level that is past a checkpoint finds it so. Neither can
## ask the other how far it is, so each waits for what it should get to see.

const FACTORY := "res://scenes/factory.tscn"
## The level the factory leads on to.
const NEXT := "res://scenes/works.tscn"
## An open lane in the factory with 6 m of clear floor to the east of it.
const RANGE_TARGET := Vector3(1, 0, -7.5)
## Not the port the game hosts on, so that a test never meets a real game.
const PORT := 24599

## True for a run of this test. The menu stays on for it, unlike for the
## self-test.
var active := false

var _role := ""
var _port := PORT
var _failures := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--nettest="):
			_role = arg.get_slice("=", 1)
		elif arg.begins_with("--port="):
			_port = int(arg.get_slice("=", 1))
	active = _role != ""
	if active:
		# Saved settings and saved progress stay out of the way, as they do
		# for the self-test.
		SelfTest.active = true
		_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	# A script error would otherwise leave the run hanging forever.
	tree.create_timer(200.0, true, true).timeout.connect(
		func() -> void:
			print("NETTEST %s FAILED (timed out)" % _role)
			tree.quit(1)
	)
	Net.port = _port
	Net.bind = "127.0.0.1"
	await _wait(0.5)
	_check("the game opens on its title screen", Menu.at_title() and tree.paused)
	if _role == "host":
		await _host()
	else:
		await _join()
	print("NETTEST %s %s" % [_role, "PASSED" if _failures == 0 else "FAILED (%d)" % _failures])
	Net.leave()
	await _wait(0.3)
	tree.quit(1 if _failures else 0)


func _host() -> void:
	var tree := get_tree()
	await _press("Play together")
	await _press("Host a game")
	await _press("Factory")
	_check("hosts a game from the menu", Net.active and Net.is_host() and await _until(_in_level.bind(FACTORY), 30.0))
	_check("which makes way, and nothing is stopped", not Menu.is_open() and not tree.paused)
	var game := tree.current_scene
	var player: CharacterBody3D = game.player
	player.health = 1e6
	_check("nobody else is there yet", game.puppets.is_empty())
	# The robots stand still for this, and one has fallen before anybody joins.
	for robot: Node in game._robots.values():
		robot.set_physics_process(false)
	var first: CharacterBody3D = game._robots.values()[2]
	first.take_damage(1000.0, first.global_position, Vector3.FORWARD)
	_check("a robot falls before the guest is there", first.dead and game.kills == 1)

	_check("the guest walks in", await _until(func() -> bool: return game.puppets.size() == 1, 60.0))
	var puppet: CharacterBody3D = game.puppets.values()[0]
	_check("and stands there as a soldier", await _until(func() -> bool: return puppet.visible and puppet._rig != null, 5.0))
	_check("the player of this machine is still the first of the players", tree.get_first_node_in_group("player") == player)
	var seen_at := puppet.global_position
	var walked := await _until(func() -> bool: return puppet.global_position.distance_to(seen_at) > 2.0 and puppet.velocity.length() > 1.0, 20.0)
	_check("the guest is seen walking", walked)

	# A robot in the lane for the guest to shoot.
	var target: CharacterBody3D = game._robots.values()[0]
	game._start(game.zones.filter(func(zone: RefCounted) -> bool: return zone.robots.has(target))[0])
	target.global_position = RANGE_TARGET
	target.velocity = Vector3.ZERO
	_check("the guest's shots kill a robot here", await _until(func() -> bool: return target.dead, 30.0) and game.kills == 2)

	# The next one stands where that one stood and goes for the guest: the
	# host's own player is out of the way.
	player.global_position = RANGE_TARGET + Vector3(0, 0, 14)
	var shooter: CharacterBody3D = game._robots.values()[1]
	if not shooter.can_process():
		game._start(game.zones.filter(func(zone: RefCounted) -> bool: return zone.robots.has(shooter))[0])
	shooter.global_position = RANGE_TARGET
	shooter.velocity = Vector3.ZERO
	shooter.set_physics_process(true)
	shooter.alert()
	# Once it is hurt, the guest throws a grenade.
	var blasts := [0]
	Blast.exploded.connect(func(_at: Vector3) -> void: blasts[0] += 1)
	_check("a grenade the guest throws goes off here", await _until(func() -> bool: return blasts[0] >= 1, 40.0))
	_check("the robot went for the guest", shooter._player == puppet or shooter.dead)
	shooter.set_physics_process(false)

	# A barrel, set off here.
	var barrels := tree.get_nodes_in_group("explosive")
	barrels[0].take_damage(1000.0, barrels[0].global_position, Vector3.FORWARD)
	_check("a barrel goes off", await _until(func() -> bool: return blasts[0] >= 2 and tree.get_nodes_in_group("explosive").size() == barrels.size() - 1, 10.0))

	# The guest dies, gets up again and takes up another weapon.
	_check("the guest is seen to die", await _until(func() -> bool: return puppet.dead, 20.0))
	_check("and to get up again", await _until(func() -> bool: return not puppet.dead, 15.0))
	_check("and to take up its shotgun", await _until(func() -> bool: return puppet._weapon == 2 and puppet._rig != null, 10.0))

	# With every robot down the exit opens, and waits for both.
	var robots: int = game._robots.size()
	_clear(game._robots.values())
	_check("the exit opens when every robot is down", game.exit_open and game.kills == robots)
	player.global_position = _exit_floor(game)
	player.velocity = Vector3.ZERO
	await _wait(1.5)
	_check("the level does not end with the host alone at the exit", not game._finished and tree.current_scene == game)
	_check("it ends with both there, and both go on", await _until(_in_level.bind(NEXT), 30.0))
	game = tree.current_scene
	_check("the kills come along", game.kills == robots)
	_check("the guest is there too", await _until(func() -> bool: return game.puppets.size() == 1, 60.0))

	# Both down: the level starts again for both.
	puppet = game.puppets.values()[0]
	_check("the guest is seen to die there", await _until(func() -> bool: return puppet.dead, 30.0))
	game.player.take_damage(1e9)
	var before := game.get_instance_id()
	_check("with both down the level starts again", await _until(func() -> bool: return _in_level(NEXT) and tree.current_scene.get_instance_id() != before, 15.0))
	game = tree.current_scene
	_check("for both of them", not game.player.dead and await _until(func() -> bool: return game.puppets.size() == 1 and not game.puppets.values()[0].dead, 60.0))

	# The guest leaves. While it is away the zones before the first
	# checkpoint are cleared, that checkpoint is taken and a robot of the
	# zone after it ends up at the start of the level, which is where the
	# guest is to find it. Then the host leaves.
	_check("the guest's soldier goes when the guest does", await _until(func() -> bool: return game.puppets.is_empty() and Net.players.size() == 1, 30.0))
	for robot: Node in game._robots.values():
		robot.set_physics_process(false)
	var behind := _before_checkpoint(game)
	for zone: RefCounted in behind:
		_clear(zone.robots)
	game.player.global_position = game.checkpoints[0].pose.origin
	_check("the host takes a checkpoint meanwhile", await _until(func() -> bool: return game._checkpoint == 0, 5.0)
		and Net.session.at == game.checkpoints[0].id)
	game._start(game.zones[behind.size()])
	var stray: CharacterBody3D = game.zones[behind.size()].robots[0]
	stray.global_position = game.start.origin
	stray.velocity = Vector3.ZERO
	_check("and the guest is back", await _until(func() -> bool: return game.puppets.size() == 1, 60.0))
	await _wait(2.0)
	await _pause()
	_check("a menu does not stop a game with others", Menu.is_open() and not tree.paused)
	await _press("Leave the game")
	_check("leaving goes back to the title screen", not Net.active and Menu.at_title() and tree.paused)


func _join() -> void:
	var tree := get_tree()
	await _press("Play together")
	_type(1, "127.0.0.1:%d" % _port)
	# The host may still be starting: no answer is an answer after a while.
	for attempt in 6:
		if Net.active:
			break
		if not Net.is_joining():
			await _press("Join the game")
		await _wait(1.0)
	_check("joins from the menu, and is let into the host's level", await _until(_in_level.bind(FACTORY), 60.0) and Net.is_guest())
	_check("the menu makes way, and nothing is stopped", not Menu.is_open() and not tree.paused)
	if not Net.active:
		return
	var game := tree.current_scene
	var player: CharacterBody3D = game.player
	var weapons: Node3D = player.weapons
	player.force_control = true
	player.health = 1e6
	var hits := [0]
	player.damaged.connect(func(_amount: float) -> void: hits[0] += 1)
	var blasts := [0]
	Blast.exploded.connect(func(_at: Vector3) -> void: blasts[0] += 1)
	var barrels := tree.get_nodes_in_group("explosive").size()

	_check("the enemies are the host's", Settings.enemy_theme == Net.session.theme)
	_check("the robot that fell before is gone, and counted", not is_instance_valid(game._robots.values()[2]) and game.kills == 1)
	var host: CharacterBody3D = game.puppets.get(1)
	_check("the host stands there as a soldier", host != null and await _until(func() -> bool: return host.visible and host._rig != null, 5.0))
	_check("the player of this machine is still the first of the players", tree.get_first_node_in_group("player") == player)

	Input.action_press("move_forward")
	await _wait(1.5)
	Input.action_release("move_forward")

	# The robot the host puts in the lane.
	var target: CharacterBody3D = game._robots.values()[0]
	_check("a robot is where the host put it", await _until(func() -> bool: return target.global_position.distance_to(RANGE_TARGET) < 0.3, 20.0))
	_face(player, RANGE_TARGET)
	await _wait(0.3)
	Input.action_press("fire")
	var killed := await _until(func() -> bool: return target.dead, 6.0)
	Input.action_release("fire")
	_check("the guest shoots it dead, on the host's word", killed and game.kills == 2 and weapons._mags[0] < 30)

	# The next robot comes for the guest.
	_check("a robot of the host's hurts the guest", await _until(func() -> bool: return hits[0] > 0, 30.0))
	_face(player, RANGE_TARGET)
	await _wait(0.2)
	var carried: int = weapons.grenades
	Input.action_press("grenade")
	await _wait(0.1)
	Input.action_release("grenade")
	_check("the guest's grenade goes off here too", await _until(func() -> bool: return blasts[0] >= 1, 10.0) and weapons.grenades == carried - 1)
	_check("a barrel the host sets off is gone here", await _until(func() -> bool: return blasts[0] >= 2 and tree.get_nodes_in_group("explosive").size() == barrels - 1, 15.0))

	# Dying is not the end.
	player.health = 1.0
	player.take_damage(50.0)
	_check("the guest dies", player.dead)
	_check("and is back on its feet a moment later", await _until(func() -> bool: return not player.dead and player.health == player.MAX_HEALTH, 10.0))
	# Weapon keys are read in _unhandled_input, which needs a real event.
	_act("weapon_3")
	await _wait(0.5)
	_check("takes up its shotgun", weapons.current().display_name == "Shotgun")

	# The exit: the host is there first, and the level waits.
	var robots: int = game._robots.size()
	_check("the exit opens here as well", await _until(func() -> bool: return game.exit_open and game.kills == robots, 20.0))
	await _wait(2.5)
	_check("and waits for the guest", not game._finished)
	player.global_position = _exit_floor(game)
	player.velocity = Vector3.ZERO
	_check("with both there it is on to the next level", await _until(_in_level.bind(NEXT), 60.0))
	game = tree.current_scene
	_check("where the kills come along", game.kills == robots)

	# Both down: the level starts again for both.
	await _wait(1.0)
	game.player.take_damage(1e9)
	var before := game.get_instance_id()
	_check("with both down the level starts again here too", await _until(func() -> bool: return _in_level(NEXT) and tree.current_scene.get_instance_id() != before, 60.0))
	_check("with the guest on its feet", not tree.current_scene.player.dead)

	# Leaving by the menu, and coming back to a game that is going on.
	await _wait(1.0)
	await _pause()
	_check("a menu does not stop a game with others", Menu.is_open() and not tree.paused)
	await _press("Leave the game")
	_check("leaving goes back to the title screen, alone", not Net.active and Menu.at_title() and tree.paused)
	await _wait(2.0)
	await _press("Play together")
	_check("the address is remembered", _typed(1) == "127.0.0.1:%d" % _port)
	await _press("Join the game")
	_check("and joins again, into the level the host is in", await _until(_in_level.bind(NEXT), 60.0))
	game = tree.current_scene
	var behind := _before_checkpoint(game)
	var cleared := 0
	for zone: RefCounted in behind:
		cleared += zone.area.get_children().filter(func(spot: Node) -> bool: return spot.is_in_group("enemy_spawn")).size()
	_check("which is past its first checkpoint by now", game._checkpoint == 0 and game.kills == robots + cleared
		and behind.all(func(zone: RefCounted) -> bool: return zone.cleared))
	_check("so that is where the guest stands", game.player.global_position.distance_to(game.checkpoints[0].pose.origin) < 2.5)
	var stray := game.get_node_or_null("%s_0" % game.zones[behind.size()].id) as Node3D
	_check("and each robot is the one the host means", stray != null
		and await _until(func() -> bool: return stray.global_position.distance_to(game.start.origin) < 0.5, 10.0))
	_check("when the host leaves, the guest is back at the title screen and told why", await _until(func() -> bool: return not Net.active and Menu.at_title(), 30.0)
		and Menu._together_note == "The host has left")


## The zones of a level that have to be cleared before its first checkpoint
## can be taken.
func _before_checkpoint(game: Node) -> Array:
	return game.zones.filter(func(zone: RefCounted) -> bool: return zone.order < game.checkpoints[0].order)


## True once this machine is in `level` and the host has let it in there.
func _in_level(level: String) -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == level and Net.game == scene and Net.present.has(Net.id())


## Stands a player in the lane, looking at `spot` from 6 m to the east of it.
func _face(player: CharacterBody3D, spot: Vector3) -> void:
	player.global_position = spot + Vector3(6, 0, 0)
	player.velocity = Vector3.ZERO
	player.look_at(Vector3(spot.x, player.global_position.y, spot.z))
	player.head.rotation.x = 0.0


## The floor in the middle of the exit of a level.
func _exit_floor(game: Node3D) -> Vector3:
	var area: Area3D = game.exit
	var size: Vector3 = (area.get_child(0) as CollisionShape3D).shape.size
	var top := area.global_position + Vector3.UP * size.y * 0.5
	var floor_there := game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * (size.y + 1.0), 1))
	return floor_there.position if floor_there else top + Vector3.DOWN * size.y


## Shoots down every robot of `robots` that still stands.
func _clear(robots: Array) -> void:
	for robot: Variant in robots:
		if is_instance_valid(robot) and not robot.dead:
			robot.take_damage(1e4, robot.global_position, Vector3.FORWARD)


## Presses the button of the menu whose text starts with `text`, as a click
## would. A button that is not there fails the run.
func _press(text: String) -> void:
	for button: Button in Menu._column.find_children("*", "Button", true, false):
		if button.text.begins_with(text) and not button.is_queued_for_deletion():
			button.pressed.emit()
			await get_tree().process_frame
			return
	_check("the menu has a button '%s'" % text, false)


## The lines of the menu to type in, top to bottom.
func _lines() -> Array[LineEdit]:
	var lines: Array[LineEdit] = []
	for line: LineEdit in Menu._column.find_children("*", "LineEdit", true, false):
		if not line.is_queued_for_deletion():
			lines.append(line)
	return lines


func _type(line: int, text: String) -> void:
	var lines := _lines()
	lines[line].text = text
	lines[line].text_changed.emit(text)


func _typed(line: int) -> String:
	var lines := _lines()
	return lines[line].text if line < lines.size() else ""


## An action that is read as an event, such as a weapon key or the pause key.
func _act(action: String) -> void:
	var key := InputEventAction.new()
	key.action = action
	key.pressed = true
	Input.parse_input_event(key)


func _pause() -> void:
	_act("pause")
	await get_tree().process_frame
	await get_tree().process_frame


## Waits until `done` holds, for `seconds` at most. True if it came to hold.
func _until(done: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		if done.call():
			return true
		await _wait(0.1)
		left -= 0.1
	return done.call()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s: %s" % ["ok" if ok else "FAIL", _role, label])
	if not ok:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
