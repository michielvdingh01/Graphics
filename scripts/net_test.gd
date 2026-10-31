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
##
## With --match, tools/nettest.sh starts it three times, for a match in the
## factory, opened from the menu as a player opens one. A guest takes the place
## of a bot; the two shoot each other down, on the counts of both; a bot hurts
## the guest; the guest changes sides, takes up a weapon of the arena and
## drops it, and takes a cell. Then the host has capture the banana played,
## and a third comes in by the list of games on the network while the guest
## runs off with the banana: it finds all of that so, and leaves again.

const FACTORY := "res://scenes/factory.tscn"
## The level with motorcycles that two ride one of, see _host_ride().
const ALPS := "res://scenes/alps.tscn"
## The level the factory leads on to.
const NEXT := "res://scenes/works.tscn"
## An open lane in the factory with 6 m of clear floor to the east of it.
const RANGE_TARGET := Vector3(1, 0, -7.5)
## Not the port the game hosts on, so that a test never meets a real game.
## Every checkout of the project counts on from here to a port of its own, so
## that a test never meets the test of another checkout either.
const PORT := 24599
const PORTS := 400
## The file the host writes once the guest may join, see _join().
const READY := "nettest_ready"
## The same for the third of a match, see _late_match().
const READY_LATE := "nettest_ready_late"
## The prize made on the host in a match, that the guest does not have.
const BOX := "test_box"
const STACK := preload("res://scripts/stack.gd")

## True for a run of this test. The menu stays on for it, unlike for the
## self-test.
var active := false

var _role := ""
var _port := PORT
var _failures := 0


func _ready() -> void:
	_port = PORT + absi(SelfTest.checkout().hash()) % PORTS
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
	tree.create_timer(360.0 if _role.ends_with("match") else 200.0, true, true).timeout.connect(
		func() -> void:
			print("NETTEST %s FAILED (timed out)" % _role)
			tree.quit(1)
	)
	Net.port = _port
	# With --lan over the network this machine is on, not over its own loop.
	Net.bind = "*" if "--lan" in OS.get_cmdline_user_args() else "127.0.0.1"
	Net.call_port = _port + 1
	await _wait(0.5)
	_check("the game opens on its title screen", Menu.at_title() and tree.paused)
	if _role == "host":
		await _host()
	elif _role == "host_ride":
		await _host_ride()
	elif _role == "join_ride":
		await _join_ride()
	elif _role == "host_match":
		await _host_match()
	elif _role == "join_match":
		await _join_match()
	elif _role == "late_match":
		await _late_match()
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
	# And a lamp is shot out and a crate to pieces.
	var lamps := _far(game, true)
	var stacks := _far(game, false)
	lamps[0].take_damage(1.0, lamps[0].global_position, Vector3.UP)
	stacks[0].take_damage(1000.0, stacks[0].global_position, Vector3.FORWARD)
	_check("so do a lamp and a crate", lamps[0].out and stacks[0].standing() == stacks[0].size() - 1)
	# Now the guest may knock, see _join().
	FileAccess.open(SelfTest.own_file(READY), FileAccess.WRITE).store_string(_role)

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
	_check("and so does the cloud of its smoke grenade stand here", await _until(func() -> bool: return Smoke.count() >= 1, 15.0))
	_check("the robot went for the guest", shooter._player == puppet or shooter.dead)
	shooter.set_physics_process(false)

	# A barrel, set off here.
	var barrels := tree.get_nodes_in_group("explosive")
	barrels[0].take_damage(1000.0, barrels[0].global_position, Vector3.FORWARD)
	_check("a barrel goes off", await _until(func() -> bool: return blasts[0] >= 2 and tree.get_nodes_in_group("explosive").size() == barrels.size() - 1, 10.0))
	# Another lamp and another crate, with the guest there to see it.
	lamps[1].take_damage(1.0, lamps[1].global_position, Vector3.UP)
	stacks[1].take_damage(1000.0, stacks[1].global_position, Vector3.FORWARD)
	_check("another lamp is shot out and another crate to pieces", lamps[1].out and stacks[1].standing() == stacks[1].size() - 1)
	_check("the guest is seen to hit out with its weapon", await _until(func() -> bool: return puppet._rig._strike >= 0.0, 15.0))

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
	# A guest that knocks while the host still loads its level, behind the
	# loading screen (scripts/loading.gd), is let in the moment that level is
	# there (net.gd, _arrived()): before the host has had a robot fall and a
	# lamp and a crate break for it to find so. The host says when it has, in
	# a file that is newer than this run.
	var since := int(Time.get_unix_time_from_system()) - 1
	var ready := func() -> bool: return FileAccess.file_exists(SelfTest.own_file(READY)) and FileAccess.get_modified_time(SelfTest.own_file(READY)) >= since
	_check("the host is ready for a guest", await _until(ready, 60.0))
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
	var lamps := _far(game, true)
	var stacks := _far(game, false)
	_check("the lamp and the crate that broke before are broken, with nothing flying", lamps[0].out and not lamps[0].light.visible
		and stacks[0].standing() == stacks[0].size() - 1 and STACK.pieces() == 0)
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
	var tins: int = weapons.tacticals
	Input.action_press("tactical")
	await _wait(0.1)
	Input.action_release("tactical")
	_check("its smoke grenade makes a cloud here too", await _until(func() -> bool: return Smoke.count() >= 1, 6.0) and tins > 0 and weapons.tacticals == tins - 1)
	_check("a barrel the host sets off is gone here", await _until(func() -> bool: return blasts[0] >= 2 and tree.get_nodes_in_group("explosive").size() == barrels - 1, 15.0))
	_check("a lamp and a crate the host breaks then break here too, in pieces", await _until(func() -> bool: return lamps[1].out and stacks[1].standing() == stacks[1].size() - 1, 10.0)
		and STACK.pieces() > 0)
	# A blow with the weapon, which the host sees.
	Input.action_press("melee")
	await _wait(0.1)
	Input.action_release("melee")

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


## The lamps of a level that are on, or else its stacks of crates and boxes:
## the ones furthest from the lane first, out of reach of whatever goes off
## there. The same ones in the same order on both machines.
func _far(game: Node3D, lamps: bool) -> Array:
	var found: Array = game._breakables.filter(func(body: Node) -> bool: return body.get("light") != null if lamps else body.has_method("cover"))
	found.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_to(RANGE_TARGET) > b.global_position.distance_to(RANGE_TARGET))
	return found


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


# --- A match together (tools/nettest.sh --match) ----------------------------------


## The host of a match: see the top of this file.
func _host_match() -> void:
	var tree := get_tree()
	Settings.enemy_theme = "soldiers"
	Settings.prize = "banana"
	Net.player_name = "Host"
	await _press("Multiplayer")
	await _press("Arena")
	await _press("Arena")
	await _press("Players a side")
	await _press("Players a side")
	await _press("Friends on your network")
	await _press("Start")
	_check("opens a match to the network from the menu", Net.active and Net.is_host() and Match.setup.open and await _until(_match_on.bind(FACTORY, "tdm"), 60.0))
	_check("two a side, the host and three bots", Match.entrants.size() == 4 and Match.me() != null and Match.setup.size == 2)
	var game := tree.current_scene
	var player: CharacterBody3D = game.player
	player.force_control = true
	_hold_bots(true)
	var lone_bots := _bots().size()
	var stands := tree.get_nodes_in_group("stash")
	FileAccess.open(SelfTest.own_file(READY), FileAccess.WRITE).store_string(_role)

	_check("the guest walks in", await _until(func() -> bool: return Net.players.size() == 2 and Net.present.size() == 2 and game.puppets.size() == 1, 60.0))
	var guest: int = game.puppets.keys()[0]
	var puppet: CharacterBody3D = game.puppets[guest]
	_check("and is in the match", await _until(func() -> bool: return Match.entrants.has(guest) and Match.entrants[guest].body == puppet, 5.0))
	var them: RefCounted = Match.entrants[guest]
	_check("on the other side, in the place of a bot", them.team != Match.me().team and Match.entrants.size() == 4 and _bots().size() == lone_bots - 1)
	_check("as a soldier of that side", await _until(func() -> bool: return puppet.visible and puppet._rig != null and puppet.team == them.team, 8.0))
	_hold_bots(true)

	# The guest shoots the host down, with what it has in hand.
	player.global_position = RANGE_TARGET
	player.velocity = Vector3.ZERO
	_check("the guest shoots the host down", await _until(func() -> bool: return player.dead, 30.0))
	_check("which counts for the guest's side", await _until(func() -> bool: return Match.tally[them.team] == 1 and them.kills == 1 and Match.me().deaths == 1, 3.0))
	_check("and the host is back a moment later", await _until(func() -> bool: return not player.dead, 8.0))

	# And the other way round.
	_check("the guest stands in the lane", await _until(func() -> bool: return puppet.global_position.distance_to(RANGE_TARGET) < 1.0, 20.0))
	_face(player, RANGE_TARGET)
	await _wait(0.3)
	Input.action_press("fire")
	var shot := await _until(func() -> bool: return them.deaths == 1, 12.0)
	Input.action_release("fire")
	_check("the host shoots the guest down", shot and Match.me().kills == 1 and Match.tally[Match.me().team] == 1)
	_check("the guest comes back", await _until(func() -> bool: return them.out <= 0.0 and not puppet.dead, 8.0))

	# A bot that stands in front of the guest does what bots do.
	player.health = 1e6
	await _wait(2.0)
	var bot: RefCounted = null
	for one: RefCounted in _bots():
		if one.team != them.team:
			bot = one
	bot.body.global_position = puppet.global_position + Vector3(4, 0, 0)
	bot.brain.set_physics_process(true)
	var side: int = them.team
	_check("the guest changes sides from the pause screen", await _until(func() -> bool: return them.team != side, 40.0))
	_hold_bots(true)
	_check("and a bot comes over the other way", _sides() == [2, 2])
	_check("the host marks the guest as a friend now", puppet._label.get_meta(&"friend", false) and puppet.team == them.team)
	_check("both are back", await _until(func() -> bool: return them.out <= 0.0 and _bots().all(func(one: RefCounted) -> bool: return one.out <= 0.0), 5.0))

	# A weapon of the arena comes up on all machines at once.
	var stand: Node3D = stands[0]
	stand.release(0.0)
	_check("the guest takes the weapon of the arena up", await _until(func() -> bool: return not stand.is_up() and stand.due() == INF, 15.0))
	_check("and it is seen in the hands of its puppet", await _until(func() -> bool: return puppet.ARMORY.at(puppet.weapon_in_hand()).special, 5.0))
	# Whoever goes down with it leaves it where they fell.
	await _wait(2.0)
	var dropped := func() -> bool: return tree.get_nodes_in_group("stash").any(func(one: Node3D) -> bool: return one.dropped)
	Match.harm(guest, 50.0, puppet.global_position, Vector3.FORWARD)
	_check("the guest goes down with it, and it lies there", await _until(dropped, 5.0) and them.deaths == 2)
	_check("and it is back up", await _until(func() -> bool: return them.out <= 0.0 and not puppet.dead, 8.0))
	_check("the guest takes a cell, which is gone here as well", await _until(func() -> bool: return Match._cells[0].cell == null, 20.0))

	# Capture the banana, chosen on the pause screen.
	await _wait(1.0)
	await _pause()
	await _press("Kind")
	await _press("Kind")
	await _press("Start the match again")
	_check("capture the banana opens for both, the guest in the level first", await _until(_match_on.bind(FACTORY, "ctf"), 60.0))
	game = tree.current_scene
	player = game.player
	player.force_control = true
	player.health = 1e6
	_hold_bots(true)
	_check("the guest is in it", await _until(func() -> bool: return Net.present.size() == 2 and game.puppets.size() == 1 and Match.entrants.has(guest) and Match.entrants[guest].body != null, 30.0))
	them = Match.entrants[guest]
	puppet = them.body
	_check("six a side now, as capture the flag usually is", Match.entrants.size() == 12 and Match.setup.size == 6)
	_check("the prize is a banana", Match.mode.prizes[0].kind == "banana")
	FileAccess.open(SelfTest.own_file(READY_LATE), FileAccess.WRITE).store_string(_role)
	var theirs: Node3D = Match.mode.prizes[1 - them.team]
	_check("the guest takes the other side's prize", await _until(func() -> bool: return theirs.state == 1 and theirs.carrier == puppet, 30.0))

	_check("a third walks in", await _until(func() -> bool: return Net.players.size() == 3 and Net.present.size() == 3 and _people() == 3, 60.0))
	_hold_bots(true)
	_check("in the place of a bot", Match.entrants.size() == 12 and _bots().size() == 9)
	_check("and leaves again, and a bot takes over", await _until(func() -> bool: return Net.players.size() == 2 and _people() == 2 and Match.entrants.size() == 12, 30.0))
	_hold_bots(true)
	_check("the guest brings it home", await _until(func() -> bool: return Match.tally[them.team] == 1 and theirs.state == 0, 30.0))

	# It goes down with whoever carries it, where they fall.
	_check("the guest takes it again", await _until(func() -> bool: return theirs.state == 1 and theirs.carrier == puppet, 30.0))
	await _wait(2.0)
	Match.harm(guest, 50.0, puppet.global_position, Vector3.FORWARD)
	_check("and drops it going down", await _until(func() -> bool: return theirs.state == 2, 5.0))

	# The end, and the next one: with a prize that only this machine has.
	Net.show(Match, &"_show_end", [them.team])
	await _wait(1.0)
	_make_box()
	Match.setup.prize = BOX
	Match.again()
	_check("the next match opens, for both", await _until(_match_on.bind(FACTORY, "ctf"), 60.0) and Match.tally == [0, 0])
	game = tree.current_scene
	_check("the guest is in that as well", await _until(func() -> bool: return Net.present.size() == 2 and Match.entrants.has(guest), 30.0))
	_check("the prize that was made here is the prize", Match.mode.prizes[0].kind == BOX)
	await _wait(3.0)
	var folder: String = Match.PRIZE._made_folder()
	# Everybody for themselves, and no bots at all.
	Match.setup.bots = false
	Match.upcoming = {"mode": "ffa"}
	Match.again()
	_check("free for all opens for both, with nobody but the two", await _until(_match_on.bind(FACTORY, "ffa"), 60.0) and await _until(func() -> bool: return Net.present.size() == 2 and Match.entrants.size() == 2, 30.0))
	game = tree.current_scene
	player = game.player
	player.force_control = true
	_check("the two are on their own", await _until(func() -> bool: return Match.entrants.has(guest) and is_instance_valid(Match.entrants[guest].body), 5.0) and Match.mode.hostile(Match.me(), Match.entrants[guest]))
	them = Match.entrants[guest]
	puppet = them.body
	_check("the guest stands in the lane again", await _until(func() -> bool: return puppet.global_position.distance_to(RANGE_TARGET) < 1.0, 20.0))
	_face(player, RANGE_TARGET)
	await _wait(0.3)
	Input.action_press("fire")
	var felled := await _until(func() -> bool: return them.deaths == 1, 12.0)
	Input.action_release("fire")
	_check("the host shoots the guest down, for a point of its own", felled and Match.me().kills == 1 and them.kills == 0)
	await _wait(1.0)
	DirAccess.remove_absolute("%s/%s/model.glb" % [folder, BOX])
	DirAccess.remove_absolute("%s/%s/prize.json" % [folder, BOX])
	DirAccess.remove_absolute("%s/%s" % [folder, BOX])


## The guest of a match: see the top of this file.
func _join_match() -> void:
	var tree := get_tree()
	Net.player_name = "Guest"
	await _press("Play together")
	_type(1, "127.0.0.1:%d" % _port)
	var since := int(Time.get_unix_time_from_system()) - 1
	var ready := func() -> bool: return FileAccess.file_exists(SelfTest.own_file(READY)) and FileAccess.get_modified_time(SelfTest.own_file(READY)) >= since
	_check("the match is open", await _until(ready, 60.0))
	for attempt in 6:
		if Net.active:
			break
		if not Net.is_joining():
			await _press("Join the game")
		await _wait(1.0)
	_check("joins, and is let into the match", await _until(_match_on.bind(FACTORY, "tdm"), 60.0) and Net.is_guest())
	_check("and sits it out behind nothing", not Menu.is_open() and not tree.paused)
	if not Net.active:
		return
	_check("it knows who is in it", await _until(func() -> bool: return Match.entrants.size() == 4 and Match.me() != null, 5.0))
	var game := tree.current_scene
	var player: CharacterBody3D = game.player
	player.force_control = true
	var me: RefCounted = Match.me()
	var host: CharacterBody3D = game.puppets.get(1)
	_check("the host stands there as a soldier of the other side", host != null and await _until(func() -> bool: return host.visible and host._rig != null and host.team != me.team, 8.0))
	_check("the bots are there, and stand where the host has them", await _until(func() -> bool: return _bots().size() == 2 and _bots().all(func(one: RefCounted) -> bool: return one.body.visible), 8.0))
	_check("and the clock runs", Match.left > 0.0 and Match.left <= float(Match.mode.numbers.minutes) * 60.0)
	_check("the stands and the cells are here too", tree.get_nodes_in_group("stash").size() >= 2 and not Match._cells.is_empty())

	# Shoots the host down, on the host's word.
	_check("the host stands in the lane", await _until(func() -> bool: return host.global_position.distance_to(RANGE_TARGET) < 1.0, 20.0))
	_face(player, RANGE_TARGET)
	await _wait(0.3)
	Input.action_press("fire")
	var shot := await _until(func() -> bool: return me.kills == 1, 12.0)
	Input.action_release("fire")
	_check("the guest brings the host down", shot and Match.tally[me.team] == 1 and game.kills == 1)
	await _wait(0.2)
	_check("and sees its own count go up", Match._hud._mine.text == "KILLS 1")

	# Stands in the lane for the host to do the same.
	_check("the host is back", await _until(func() -> bool: return not host.dead, 8.0))
	player.global_position = RANGE_TARGET
	player.velocity = Vector3.ZERO
	_check("the host brings the guest down", await _until(func() -> bool: return player.dead, 30.0))
	_check("the guest is told so, and how long it takes", await _until(func() -> bool: return me.deaths == 1 and me.out > 0.0, 3.0))
	_check("and is back, as good as new", await _until(func() -> bool: return not player.dead and player.health == player.MAX_HEALTH, 8.0))
	_check("somewhere else", player.global_position.distance_to(RANGE_TARGET) > 2.0)

	# A bot comes up to it and fires.
	player.global_position = RANGE_TARGET
	player.velocity = Vector3.ZERO
	player.health = 1e6
	var hits := [0]
	player.damaged.connect(func(_amount: float) -> void: hits[0] += 1)
	_check("a bot hurts the guest", await _until(func() -> bool: return hits[0] > 0, 30.0))

	# Over to the other side, by the pause screen.
	var side: int = me.team
	await _pause()
	await _press("Change sides")
	_check("the guest is on the other side", await _until(func() -> bool: return me.team != side, 5.0))
	_check("and can be walked through by its own, and not by the others", player.collision_layer & Match.SIDES[me.team] != 0 and player.collision_layer & Match.SIDES[1 - me.team] == 0 and player.team == me.team)
	_check("is back at its new end", await _until(func() -> bool: return me.out <= 0.0, 5.0))
	_check("the host is a friend now", host._label.get_meta(&"friend", false))

	# Takes up a weapon of the arena as it comes up.
	var stands: Array = tree.get_nodes_in_group("stash")
	var up := func() -> Array: return stands.filter(func(one: Node3D) -> bool: return one.is_up())
	_check("a weapon of the arena comes up", await _until(func() -> bool: return not up.call().is_empty(), 15.0))
	var stand: Node3D = up.call()[0]
	player.global_position = stand.global_position
	player.velocity = Vector3.ZERO
	var weapons: Node3D = player.weapons
	_check("the guest takes it up", await _until(func() -> bool: return weapons.current().special, 5.0))
	_check("and it is gone from its stand", not stand.is_up())
	player.health = 1.0
	var lying := func() -> Array: return tree.get_nodes_in_group("stash").filter(func(one: Node3D) -> bool: return one.dropped)
	_check("the guest goes down with it, and it lies there", await _until(func() -> bool: return lying.call().size() == 1, 8.0) and player.dead and not weapons.current().special)
	_check("and is back", await _until(func() -> bool: return not player.dead, 8.0))

	# A cell, on the host's count too.
	var cell: Dictionary = Match._cells[0]
	_check("a cell lies there", await _until(func() -> bool: return is_instance_valid(cell.cell), 5.0))
	player.health = 10.0
	player.global_position = cell.at
	player.velocity = Vector3.ZERO
	_check("the guest takes it", await _until(func() -> bool: return cell.cell == null or not is_instance_valid(cell.cell), 10.0) and player.health > 10.0)

	# Capture the banana, for which the host brings everybody along.
	_check("the host has capture the banana played", await _until(_match_on.bind(FACTORY, "ctf"), 60.0))
	game = tree.current_scene
	player = game.player
	player.force_control = true
	player.health = 1e6
	_check("it has a place in that", await _until(func() -> bool: return Match.me() != null, 5.0))
	me = Match.me()
	_check("both prizes stand here, bananas", Match.mode.prizes.all(func(one: Node3D) -> bool: return is_instance_valid(one) and one.kind == "banana"))
	_check("in the colours of whose they are", Match.mode._labels[me.team].text == "YOURS" and Match.mode._labels[1 - me.team].text == "THEIRS")
	await _wait(1.0)
	var theirs: Node3D = Match.mode.prizes[1 - me.team]
	var home: Node3D = Match.mode.prizes[me.team]
	var away: Vector3 = theirs.global_position
	player.global_position = away
	player.velocity = Vector3.ZERO
	_check("the guest has the banana", await _until(func() -> bool: return theirs.state == 1 and theirs.carrier == player, 10.0))
	var says: String = Match.mode.status(me)
	_check("and the screen says so", says.contains("bring it home"))
	# It waits for the third to come and go, and holds on to it meanwhile.
	_check("a third comes in", await _until(func() -> bool: return Net.players.size() == 3, 60.0))
	_check("and goes", await _until(func() -> bool: return Net.players.size() == 2 and Match.entrants.size() == 12, 40.0))
	player.global_position = home.global_position
	player.velocity = Vector3.ZERO
	_check("the guest brings it home and scores", await _until(func() -> bool: return Match.tally[me.team] == 1 and theirs.state == 0, 10.0))
	await _wait(0.5)
	player.global_position = away
	player.velocity = Vector3.ZERO
	_check("takes it again", await _until(func() -> bool: return theirs.state == 1 and theirs.carrier == player, 10.0))
	player.health = 1.0
	_check("and goes down with it", await _until(func() -> bool: return theirs.state == 2 and player.dead, 8.0))
	_check("it lies where the guest fell", theirs.where().distance_to(away) < 2.0)

	_check("the match ends", await _until(func() -> bool: return Match.state == Match.State.OVER, 10.0))
	await _wait(0.2)
	_check("it says the host starts the next one", Match._hud._centre.text.contains("The host starts the next one"))
	_check("and the next one opens, from the start", await _until(func() -> bool: return Match.state != Match.State.OVER, 20.0) and await _until(_match_on.bind(FACTORY, "ctf"), 60.0) and Match.tally == [0, 0])
	_check("with the prize made on the host, which it now has as well", Match.PRIZE.made(BOX) and Match.mode.prizes[0].kind == BOX)
	_check("free for all, the two of them, and the host brings the guest down", await _until(_match_on.bind(FACTORY, "ffa"), 60.0) and await _until(func() -> bool: return Match.entrants.size() == 2 and Match.me() != null, 30.0))
	game = tree.current_scene
	player = game.player
	player.force_control = true
	player.global_position = RANGE_TARGET
	player.velocity = Vector3.ZERO
	await _wait(0.5)
	_check("on its feet, though it was down as the match before ended", absf(player.global_position.y - RANGE_TARGET.y) < 0.05)
	_check("which counts for the host alone", await _until(func() -> bool: return Match.me() != null and Match.me().deaths == 1, 30.0) and Match.me().kills == 0)
	_check("and when the host has gone, so has the match", await _until(func() -> bool: return not Net.active, 40.0) and not Match.active and Menu.at_title())


## The third of a match, who comes in by the list of games on the network
## while the guest runs off with the banana.
func _late_match() -> void:
	var tree := get_tree()
	Net.player_name = "Late"
	var since := int(Time.get_unix_time_from_system()) - 1
	var ready := func() -> bool: return FileAccess.file_exists(SelfTest.own_file(READY_LATE)) and FileAccess.get_modified_time(SelfTest.own_file(READY_LATE)) >= since
	_check("capture the banana is on", await _until(ready, 200.0))
	await _press("Multiplayer")
	await _press("Join a game on your network")
	_check("finds the game on the network", await _until(func() -> bool: return not Net.found.is_empty(), 8.0))
	var heard: Dictionary = Net.found.values()[0] if not Net.found.is_empty() else {}
	_check("and hears what it is", heard.get("name") == "Host" and str(heard.get("what")) == "Capture the flag, Factory" and heard.get("people") == 2 and heard.get("fits", false))
	# The guest has to have the banana first: it holds on to it for this.
	await _wait(6.0)
	await _wait(0.2)
	await _press("Join Host")
	_check("joins it from the list, and is let into the match", await _until(_match_on.bind(FACTORY, "ctf"), 60.0) and Net.is_guest())
	if not Net.active:
		return
	_check("and has a place in it", await _until(func() -> bool: return Match.me() != null and Match.entrants.size() == 12, 5.0))
	var carried := func() -> bool: return Match.mode.prizes.any(func(one: Node3D) -> bool: return one.state == 1)
	_check("finds the banana on the guest's back", await _until(carried, 15.0))
	_check("the stands, the cells and the clock as they are", tree.get_nodes_in_group("stash").size() >= 2 and not Match._cells.is_empty() and Match.left < float(Match.mode.numbers.minutes) * 60.0)
	_check("the people there are soldiers, standing", await _until(func() -> bool: return tree.current_scene.puppets.size() == 2 and tree.current_scene.puppets.values().all(func(one: Node3D) -> bool: return one.visible), 8.0))
	await _wait(1.0)
	await _pause()
	await _press("Leave the match")
	await _wait(1.0)
	_check("leaves again, for the title screen", not Net.active and not Match.active and Menu.at_title())


func _match_on(level: String, kind: String) -> bool:
	return _in_level(level) and Match.active and Match.setup.mode == kind and Match.playing() and not Loading.busy()


func _bots() -> Array:
	return Match.entrants.values().filter(func(one: RefCounted) -> bool: return one.bot)


func _people() -> int:
	return Match.entrants.size() - _bots().size()


## How many there are on either side.
func _sides() -> Array:
	var sides := [0, 0]
	for one: RefCounted in Match.entrants.values():
		sides[one.team] += 1
	return sides


## Has the bots stand still, or not.
func _hold_bots(still: bool) -> void:
	for one: RefCounted in _bots():
		if one.brain:
			one.brain.set_physics_process(not still)


## Makes a prize on this machine, of a box, as a made prize is on disk.
func _make_box() -> void:
	var folder: String = "%s/%s" % [Match.PRIZE._made_folder(), BOX]
	DirAccess.make_dir_recursive_absolute(folder)
	FileAccess.open(folder + "/prize.json", FileAccess.WRITE).store_string(JSON.stringify({"name": "Test box", "model": "model.glb"}))
	var whole := Node3D.new()
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	whole.add_child(box)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	document.append_from_scene(whole, state)
	document.write_to_filesystem(state, folder + "/model.glb")
	whole.free()
	Match.PRIZE.reread()


# --- Riding together (tools/nettest.sh --ride) ------------------------------------


## The host of a ride: in the Alps it gets on a motorcycle at the camp in the
## west, waits for the guest to get into the sidecar, rides off, waits for
## the guest to get out again, and wears the motorcycle down.
func _host_ride() -> void:
	var tree := get_tree()
	# The Alps are no level of the list to play together: hosted as the
	# menu hosts one.
	Menu._host(ALPS)
	_check("hosts a game in the Alps", await _until(_in_level.bind(ALPS), 60.0) and Net.active and Net.is_host())
	var game := tree.current_scene
	var player: CharacterBody3D = game.player
	player.force_control = true
	player.health = 1e6
	var bike := _motorcycle(game)
	_check("there is a motorcycle at the camp in the west", bike != null)
	if bike == null:
		return
	player.global_position = bike.global_position + bike.global_basis.x * -1.4 + Vector3.UP
	await _wait(0.3)
	bike.request_seat(player, 0)
	_check("the host is at the handlebars, and runs it", await _until(func() -> bool: return bike.driver() == player, 3.0) and bike.runs_here())
	_check("the guest comes", await _until(func() -> bool: return game.puppets.size() == 1, 60.0))
	var puppet: CharacterBody3D = game.puppets.values()[0]
	_check("and gets into the sidecar", await _until(func() -> bool: return bike.occupants[1] == puppet, 40.0))
	_check("where it sits, with the motorcycle", await _until(func() -> bool: return puppet.riding == bike and puppet.global_position.distance_to(bike.seat_frame(1).origin) < 1.2, 5.0))
	var from := bike.global_position
	# Not so far that it leaves the open ground of the camp: beyond it stand
	# the trees of a hedge, and the guest rides on from wherever it stops.
	Input.action_press("move_forward")
	await _wait(2.5)
	Input.action_release("move_forward")
	print("  the motorcycle went %.1f m, at %.1f m/s at the end" % [bike.global_position.distance_to(from), bike.speed])
	_check("rides off with the guest in the sidecar", bike.global_position.distance_to(from) > 8.0 and bike.occupants[1] == puppet)
	_check("the guest is carried along", puppet.global_position.distance_to(bike.seat_frame(1).origin) < 1.2)
	_check("the guest gets out again", await _until(func() -> bool: return bike.occupants[1] == null and puppet.riding == null, 30.0))
	await _wait(0.5)
	bike.take_damage(150.0, bike.global_position, Vector3.FORWARD)
	_check("a hit wears it down", bike.health < bike.data.health)
	# Now the other way round: the guest drives, the host rides along.
	bike.request_leave(player)
	_check("the host gets off, and runs it with nobody at the handlebars", bike.driver() == null and bike.runs_here())
	_check("the guest takes the handlebars, and its machine runs it now", await _until(func() -> bool: return bike.driver() == puppet and not bike.runs_here(), 30.0))
	player.global_position = bike.global_position + bike.global_basis.x * 2.2 + Vector3.UP
	await _wait(0.3)
	bike.request_seat(player, 1)
	_check("the host gets into the sidecar", await _until(func() -> bool: return bike.occupants[1] == player and player.riding == bike, 5.0))
	var still := bike.global_position
	_check("and is carried off as the guest rides", await _until(func() -> bool: return bike.global_position.distance_to(still) > 8.0, 30.0))
	print("  seen here, the guest's motorcycle went %.1f m; the eyes of the host are %.2f m from those of the sidecar" % [bike.global_position.distance_to(still), (player.global_position + Vector3.UP * player._eye_height).distance_to(bike.eye_frame(1).origin)])
	_check("with the eyes where the sidecar has them", (player.global_position + Vector3.UP * player._eye_height).distance_to(bike.eye_frame(1).origin) < 0.3)
	await _until(func() -> bool: return bike.speed < 1.0, 15.0)
	bike.request_leave(player)
	_check("and gets out", player.riding == null and bike.occupants[1] == null)
	# The guest says when it has seen it; leaving before would end its game.
	await _until(func() -> bool: return game.puppets.is_empty(), 40.0)


## The guest of a ride: gets into the sidecar of the motorcycle the host is
## at the handlebars of, is carried along while it rides, gets out, and sees
## the motorcycle worn down.
func _join_ride() -> void:
	var tree := get_tree()
	await _press("Play together")
	_type(1, "127.0.0.1:%d" % _port)
	for attempt in 10:
		if Net.active:
			break
		if not Net.is_joining():
			await _press("Join the game")
		await _wait(1.0)
	_check("joins the host in the Alps", await _until(_in_level.bind(ALPS), 90.0) and Net.is_guest())
	if not Net.active:
		return
	var game := tree.current_scene
	var player: CharacterBody3D = game.player
	player.force_control = true
	player.health = 1e6
	var bike := _motorcycle(game)
	_check("the same motorcycle is there", bike != null)
	if bike == null:
		return
	var host: CharacterBody3D = game.puppets.get(1)
	_check("with the host at its handlebars, run by the host", await _until(func() -> bool: return host != null and bike.driver() == host, 20.0) and not bike.runs_here())
	player.global_position = bike.global_position + bike.global_basis.x * 2.2 + Vector3.UP
	await _wait(0.5)
	bike.request_seat(player, 1)
	_check("gets into the sidecar when the host says so", await _until(func() -> bool: return bike.occupants[1] == player and player.riding == bike, 5.0))
	var from := bike.global_position
	_check("is carried along as the host rides off", await _until(func() -> bool: return bike.global_position.distance_to(from) > 8.0, 20.0))
	print("  seen here, the motorcycle went %.1f m; the player is %.2f m from the eyes of the sidecar" % [bike.global_position.distance_to(from), (player.global_position + Vector3.UP * player._eye_height).distance_to(bike.eye_frame(1).origin)])
	_check("with the eyes where the sidecar has them", (player.global_position + Vector3.UP * player._eye_height).distance_to(bike.eye_frame(1).origin) < 0.3)
	await _until(func() -> bool: return bike.speed < 1.0, 10.0)
	bike.request_leave(player)
	_check("and gets out", player.riding == null and bike.occupants[1] == null)
	_check("sees the motorcycle worn down by the host", await _until(func() -> bool: return bike.health < bike.data.health, 20.0))
	# Now the guest drives and the host rides along.
	_check("the host gets off", await _until(func() -> bool: return bike.driver() == null, 20.0))
	player.global_position = bike.global_position + bike.global_basis.x * -1.4 + Vector3.UP
	await _wait(0.3)
	bike.request_seat(player, 0)
	_check("the guest takes the handlebars, and runs it here", await _until(func() -> bool: return bike.driver() == player, 5.0) and bike.runs_here())
	_check("the host gets into the sidecar", await _until(func() -> bool: return host != null and bike.occupants[1] == host, 20.0))
	var from_here := bike.global_position
	Input.action_press("move_forward")
	await _wait(4.0)
	Input.action_release("move_forward")
	print("  the guest rode %.1f m, at %.1f m/s at the end" % [bike.global_position.distance_to(from_here), bike.speed])
	_check("rides off with the host in the sidecar", bike.global_position.distance_to(from_here) > 8.0 and bike.occupants[1] == host)
	_check("the host is carried along here", host.global_position.distance_to(bike.seat_frame(1).origin) < 1.2)
	_check("the host gets out again", await _until(func() -> bool: return bike.occupants[1] == null, 30.0))
	bike.request_leave(player)
	await _wait(0.5)


## The motorcycle nearest to the camp in the west of the Alps.
func _motorcycle(game: Node) -> RigidBody3D:
	var best: RigidBody3D = null
	for vehicle: Node in game.get_tree().get_nodes_in_group("vehicle"):
		if vehicle.get(&"kind") == "motorcycle" and (best == null or (vehicle as Node3D).global_position.distance_to(Vector3(330, 0, 905)) < best.global_position.distance_to(Vector3(330, 0, 905))):
			best = vehicle
	return best


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
