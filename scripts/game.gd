extends Node3D
## Level flow: bakes the navmesh and takes the player down the route the level
## describes (tools/levels/<name>.gd, built into Level/Route). The robots a
## zone lists stand at their posts from the moment the level loads, switched
## off. Their fight starts when the player walks into the zone or shoots at
## one of them. A checkpoint is a place: it counts once everything before it
## is cleared, and a death or a restart of the game carries on from the last
## one. The exit opens when every zone is cleared: its lamp comes on and its
## door rolls up.
##
## In a game with others (see net.gd) the host keeps track of all this and
## the others are told: the _show_ functions run on every machine. Everybody
## else in the level stands in it as a puppet. Whoever dies is back at the
## last checkpoint a moment later, unless everybody is down: then the level
## starts again from there for all. It ends once everybody who is still
## standing is at the exit.

## What the HUD shows as the thing to do, and how many robots still stand in
## the way of it.
signal objective_changed(text: String, hostiles: int)
signal kills_changed(kills: int)
signal checkpoint_reached(title: String)
signal exit_opened
## The player has left by the exit; `next` is the level that follows, or
## empty when this was the last one.
signal finished(next: String)

const GRUNT := preload("res://scenes/enemy.tscn")
const RUSHER := preload("res://scenes/enemy_rusher.tscn")
const HEAVY := preload("res://scenes/enemy_heavy.tscn")
## What a zone can list.
const ENEMIES := {"grunt": GRUNT, "rusher": RUSHER, "heavy": HEAVY}
## Shortest and longest time before a robot whose fight has started comes
## looking for the player.
const HUNT_DELAY := Vector2(1.5, 4.0)
const RESTART_DELAY := 2.5
## In a game with others: how long somebody who died is out of it.
const RESPAWN_DELAY := 5.0
## Seconds between two reports of where the robots are, and how far apart
## players stand who appear at the same place.
const ROBOT_TICK := 0.05
const ELBOW_ROOM := 0.9
const PUPPET := preload("res://scenes/puppet.tscn")
## How long the screen takes to go dark at the exit before the next level loads.
const EXIT_FADE := 0.9
## How long the door at the exit takes to roll up, and how long after the
## lamp over it has come on it starts.
const DOOR_TIME := 3.2
const DOOR_DELAY := 0.5


## A part of the level that is fought over.
class Zone:
	var id := ""
	var title := ""
	var area: Area3D
	## Its place along the route, which checkpoints are measured against.
	var order := 0
	var started := false
	var cleared := false
	var alive := 0
	## The robots that hold it, from the moment they are posted.
	var robots: Array[Node3D] = []

	func fighting() -> bool:
		return started and not cleared


class Checkpoint:
	var id := ""
	var title := ""
	var area: Area3D
	var order := 0
	## Where the player stands after carrying on from here.
	var pose: Transform3D


var kills := 0
var objective := ""
var zones: Array[Zone] = []
var checkpoints: Array[Checkpoint] = []
## Where the level begins.
var start := Transform3D()
## The way out and whether it is open; null in a level without a route.
var exit: Area3D
var exit_open := false
## The other players in the level, by id.
var puppets := {}

## Index of the checkpoint to carry on from; -1 is the start of the level.
var _checkpoint := -1
var _finished := false
## Every robot posted, by a number that is the same on every machine: a
## hundred times the zone's place in the list plus its own place in the zone.
## A machine that came in at a later checkpoint has not posted them all.
var _robots := {}
## What can explode in the level, by path, to tell a latecomer what is gone.
var _explosives: Array[NodePath] = []
var _robot_tick := 0.0
var _wiped := false

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var player: CharacterBody3D = $Player


func _ready() -> void:
	Settings.apply()
	Blast.clear()
	_read_route()
	# Behind the title screen the level is only a backdrop.
	var playing := not Benchmark.active and not Menu.at_title()
	if playing:
		_resume()
		post_robots()
		_watch_route()
		player.died.connect(_on_player_died)
		player.damaged.connect(func(amount: float) -> void: Net.player_did(&"hurt", [amount]))
		_update_objective()
		if _route_cleared():
			_open_exit(false)
		for explosive in get_tree().get_nodes_in_group("explosive"):
			_explosives.append(get_path_to(explosive))
		Net.changed.connect(_meet)
		Net.arrive(self)
		_meet()
	elif exit:
		_put_player(start)
	# Only the host's robots find their own way.
	if Net.is_guest():
		return
	# The level's static body is built a frame late, so wait before baking from
	# it. The server only picks this bake up with region_use_async_iterations off.
	await get_tree().physics_frame
	await get_tree().physics_frame
	nav_region.bake_navigation_mesh(false)


func _exit_tree() -> void:
	Net.depart(self)


## True while robots of any zone are still standing.
func fighting() -> bool:
	return zones.any(func(zone: Zone) -> bool: return zone.fighting())


## The scene that follows this level, or empty at the end of the game.
func next_level() -> String:
	var next: String = exit.get_meta(&"next", "") if exit else ""
	return "res://scenes/%s.tscn" % next if next else ""


## Takes the route apart into what the game keeps track of. A level without
## one, such as the greybox, just has nothing going on.
func _read_route() -> void:
	var route := get_node_or_null("Level/Route")
	if route == null:
		return
	for step in route.get_children():
		if step.is_in_group("route_zone"):
			var zone := Zone.new()
			zone.id = step.get_meta(&"id")
			zone.title = step.get_meta(&"title")
			zone.area = step
			zone.order = step.get_index()
			zones.append(zone)
		elif step.is_in_group("route_checkpoint"):
			var checkpoint := Checkpoint.new()
			checkpoint.id = step.get_meta(&"id")
			checkpoint.title = step.get_meta(&"title")
			checkpoint.area = step
			checkpoint.order = step.get_index()
			checkpoint.pose = (step.get_node("Respawn") as Node3D).global_transform
			checkpoints.append(checkpoint)
		elif step.is_in_group("route_exit"):
			exit = step
		elif step.name == &"Start":
			start = (step as Node3D).global_transform


## Puts the player at the last checkpoint, with everything before it cleared,
## or at the start of the level.
func _resume() -> void:
	# Together, where to carry on from is the host's to say.
	var saved: Dictionary = Net.session if Net.active else Save.resume_point(scene_file_path)
	var pose := start
	if saved:
		kills = saved.kills
		for i in checkpoints.size():
			if checkpoints[i].id == saved.at:
				_checkpoint = i
				pose = checkpoints[i].pose
				for zone in zones:
					if zone.order < checkpoints[i].order:
						zone.started = true
						zone.cleared = true
	elif exit:
		# The start of a level is the first place to carry on from.
		Save.store(scene_file_path, "", "", kills)
	if exit:
		_put_player(pose)
	kills_changed.emit(kills)


## Stands the robots of every zone that is still to be fought over at their
## posts, facing the way the player will come. They wait there switched off:
## a robot that is running goes for the player on sight, and across a hall
## that would start every fight at once. Switched off, a robot does not move
## a joint either: one that so much as sways makes every lamp around it draw
## its shadows again, frame after frame. Of a robot this reads no more than
## the agreed signal, alert() and dead, and its health to see that it was hit.
func post_robots() -> void:
	for zone in zones:
		if zone.cleared or not zone.robots.is_empty():
			continue
		var from := _approach(zone)
		for spawn in zone.area.get_children():
			if not spawn.is_in_group("enemy_spawn"):
				continue
			var robot: CharacterBody3D = ENEMIES[spawn.get_meta(&"kind")].instantiate()
			robot.position = (spawn as Node3D).global_position
			var towards := from - robot.position
			robot.rotation.y = atan2(-towards.x, -towards.z)
			robot.died.connect(_on_enemy_died.bind(zone))
			# By the same name on every machine, see net.gd.
			robot.name = "%s_%d" % [zone.id, zone.robots.size()]
			add_child(robot)
			_robots[zones.find(zone) * 100 + zone.robots.size()] = robot
			# It stays there to be shot at and walked into.
			robot.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
			robot.process_mode = Node.PROCESS_MODE_DISABLED
			zone.robots.append(robot)
			zone.alive += 1


## Where the player is last sure to have stood on the way to a zone: the
## checkpoint before it on the route, or the start.
func _approach(zone: Zone) -> Vector3:
	var from := start.origin
	for checkpoint in checkpoints:
		if checkpoint.order < zone.order:
			from = checkpoint.pose.origin
	return from


func _physics_process(delta: float) -> void:
	if Net.is_guest():
		return
	# A robot that is shot at where it stands does not take it standing.
	for zone in zones:
		if not zone.started and zone.robots.any(_is_hurt):
			_start(zone)
	if Net.active:
		_tell_robots(delta)
		_check_exit()
		_check_wipe()


## Untyped, as is the robot in _start(): one that has been freed is not a
## node any more.
func _is_hurt(robot: Variant) -> bool:
	return is_instance_valid(robot) and robot.health < robot.max_health


## Begins the fight for a zone: its robots are switched on.
func _start(zone: Zone) -> void:
	if zone.started or Net.is_guest():
		return
	Net.show(self, &"_show_start", [zones.find(zone)])
	for robot: Variant in zone.robots:
		if not is_instance_valid(robot) or robot.dead:
			continue
		# One that cannot see the player would otherwise stand there for good.
		get_tree().create_timer(randf_range(HUNT_DELAY.x, HUNT_DELAY.y), false).timeout.connect(robot.alert)


func _show_start(index: int) -> void:
	var zone := zones[index]
	zone.started = true
	for robot: Variant in zone.robots:
		if is_instance_valid(robot) and not robot.dead:
			robot.process_mode = Node.PROCESS_MODE_INHERIT
	_update_objective()


func _watch_route() -> void:
	for zone in zones:
		zone.area.body_entered.connect(_on_zone_entered.bind(zone))
	for i in checkpoints.size():
		checkpoints[i].area.body_entered.connect(_on_checkpoint_entered.bind(i))
	if exit:
		exit.body_entered.connect(_on_exit_entered)


func _put_player(pose: Transform3D) -> void:
	pose = _beside(pose)
	player.global_position = pose.origin
	player.rotation = Vector3(0.0, pose.basis.get_euler().y, 0.0)
	player.head.rotation.x = 0.0
	player.velocity = Vector3.ZERO


## True if the player really stands in the box of that step of the route.
## The physics server can report the spot the player had in the scene file
## before being put at the start, a frame after that was done.
func _holds(area: Area3D, body: Node3D = null) -> bool:
	if body == null:
		body = player
	var size: Vector3 = (area.get_child(0) as CollisionShape3D).shape.size
	var box := AABB(area.global_position - size * 0.5, size).grow(0.5)
	return box.has_point(body.global_position + Vector3.UP * 0.9)


## The player of this machine and the puppets of the others.
func _players() -> Array:
	var bodies := [player]
	bodies.append_array(puppets.values())
	return bodies


func _on_zone_entered(body: Node3D, zone: Zone) -> void:
	if not _players().has(body) or zone.started or body.dead or not _holds(zone.area, body):
		return
	_start(zone)


func _on_enemy_died(enemy: Node3D, zone: Zone) -> void:
	# One that is shot down where it stood still has to fall.
	enemy.process_mode = Node.PROCESS_MODE_INHERIT
	kills += 1
	kills_changed.emit(kills)
	zone.alive -= 1
	# One shot from afar can be the first the others know of it.
	_start(zone)
	if zone.alive > 0:
		_update_objective()
		return
	zone.cleared = true
	_update_objective()
	if not fighting():
		# A player may be standing in a checkpoint already, or at the exit.
		for body: Node3D in _players():
			for i in checkpoints.size():
				_on_checkpoint_entered(body, i)
	if _route_cleared():
		_open_exit(true)


func _on_checkpoint_entered(body: Node3D, index: int) -> void:
	if Net.is_guest() or not _players().has(body) or index <= _checkpoint or body.dead or fighting():
		return
	var checkpoint := checkpoints[index]
	if not _holds(checkpoint.area, body):
		return
	for zone in zones:
		if zone.order < checkpoint.order and not zone.cleared:
			return
	Net.show(self, &"_show_checkpoint", [index])


## One of the players has reached a checkpoint, which goes for all of them.
func _show_checkpoint(index: int) -> void:
	var checkpoint := checkpoints[index]
	_checkpoint = index
	if Net.active:
		Net.session.at = checkpoint.id
		Net.session.kills = kills
	else:
		Save.store(scene_file_path, checkpoint.id, checkpoint.title, kills)
	player.weapons.refill()
	Sfx.play(&"reload_end", -4.0)
	checkpoint_reached.emit(checkpoint.title)


func _route_cleared() -> bool:
	return zones.all(func(zone: Zone) -> bool: return zone.cleared)


func _open_exit(announce: bool) -> void:
	if exit == null or exit_open:
		return
	exit_open = true
	var lamp := exit.get_node_or_null("Lamp") as Node3D
	if lamp:
		lamp.visible = true
		if announce:
			Sfx.play_at(&"clang", lamp.global_position, 4.0)
	# The door of the exit is part of the level (the group "exit_door", see
	# roller_door() in tools/level_builder.gd) and goes up into the wall.
	for door: Node3D in get_tree().get_nodes_in_group("exit_door"):
		var rise: float = door.get_meta(&"rise", 0.0)
		var up := door.position + Vector3.UP * rise
		if not announce:
			door.position = up
			continue
		var rolling := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		rolling.tween_interval(DOOR_DELAY)
		rolling.tween_property(door, "position", up, DOOR_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		rolling.tween_callback(func() -> void: Sfx.play_at(&"clang", door.global_position, -2.0))
	exit_opened.emit()
	_check_exit()


func _on_exit_entered(_body: Node3D) -> void:
	_check_exit()


## Ends the level once everybody who is still standing is at the open exit.
func _check_exit() -> void:
	if exit == null or not exit_open or _finished or Net.is_guest():
		return
	var standing := _players().filter(func(body: Node3D) -> bool: return not body.dead)
	if standing.is_empty() or not standing.all(func(body: Node3D) -> bool: return _holds(exit, body)):
		return
	Net.show(self, &"_show_finished", [next_level()])


func _show_finished(next: String) -> void:
	_finished = true
	# The next level starts at its beginning; after the last there is nothing
	# left to carry on from. A game with others leaves what was saved alone.
	if Net.active:
		pass
	elif next:
		Save.store(next, "", "", kills)
	else:
		Save.clear()
	finished.emit(next)
	await get_tree().create_timer(EXIT_FADE, false).timeout
	if next == "":
		Menu.show_end(kills)
	elif not Net.active:
		get_tree().change_scene_to_file(next)
	elif not Net.is_guest():
		Net.load_level(next, "", kills)


## Works out what there is to do: finish the fight that is going on, or else
## go to the first zone that still has to be cleared, or else leave.
func _update_objective() -> void:
	var hostiles := 0
	var text := ""
	for zone in zones:
		if zone.fighting():
			hostiles += zone.alive
			if text == "":
				text = "Clear %s" % zone.title
	if text == "":
		for zone in zones:
			if not zone.cleared:
				text = "Reach %s" % zone.title
				break
	if text == "" and exit:
		text = exit.get_meta(&"title", "")
	objective = text
	objective_changed.emit(text, hostiles)


func _on_player_died() -> void:
	if Net.active:
		# The others play on. Should they all go down, _check_wipe() has the
		# level start again before this comes to anything.
		await get_tree().create_timer(RESPAWN_DELAY, false).timeout
		if Net.active and player.dead and not _finished:
			player.revive(_beside(checkpoints[_checkpoint].pose if _checkpoint >= 0 else start))
			player.weapons.refill()
		return
	await get_tree().create_timer(RESTART_DELAY, false).timeout
	get_tree().reload_current_scene()


# --- Playing together ---------------------------------------------------------


## A place next to `pose` for this machine's player, so that those who appear
## together do not stand inside each other. Alone it is the place itself.
func _beside(pose: Transform3D) -> Transform3D:
	if Net.active:
		var place := Net.slot()
		@warning_ignore("integer_division")
		var steps := (place + 1) / 2 * (1 if place % 2 else -1)
		pose.origin += pose.basis.x.normalized() * ELBOW_ROOM * steps
	return pose


## Stands a puppet in the level for everybody else who is in it, and takes
## away that of whoever has gone. They come after the player of this machine
## in the tree, which keeps that one the first of the group "player": what
## looks for the player of this machine, such as the HUD, takes the first.
func _meet() -> void:
	for other: int in puppets.keys():
		if not Net.present.has(other):
			puppets[other].queue_free()
			puppets.erase(other)
	for other: int in Net.present:
		if other == Net.id() or puppets.has(other) or not Net.players.has(other):
			continue
		var puppet: CharacterBody3D = PUPPET.instantiate()
		puppet.id = other
		puppet.title = Net.players[other].name
		puppet.name = "Puppet%d" % other
		puppet.position = start.origin
		add_child(puppet)
		puppets[other] = puppet


## Where the robots are that are up and about, for the guests to show.
func _tell_robots(delta: float) -> void:
	_robot_tick -= delta
	if _robot_tick > 0.0:
		return
	_robot_tick = ROBOT_TICK
	var states := _robot_states()
	if not states.is_empty():
		Net.tell(self, &"_move_robots", [states, false], false)


## For every robot that is up and about: its number, then what its
## net_state() gives.
func _robot_states() -> Array:
	var states := []
	for number: int in _robots:
		var robot: Variant = _robots[number]
		if is_instance_valid(robot) and not robot.dead and robot.can_process():
			states.append(number)
			states.append_array(robot.net_state())
	return states


func _move_robots(states: Array, at_once: bool) -> void:
	for i in range(0, states.size(), 5):
		var robot: Variant = _robots.get(states[i])
		if is_instance_valid(robot):
			robot.net_follow(states[i + 1], states[i + 2], states[i + 3], states[i + 4], at_once)


## Starts the level again from the last checkpoint once everybody is down.
func _check_wipe() -> void:
	if _wiped or _finished or not _players().all(func(body: Node3D) -> bool: return body.dead):
		return
	_wiped = true
	await get_tree().create_timer(RESTART_DELAY, false).timeout
	Net.load_level(scene_file_path, Net.session.at, Net.session.kills)


## How the level stands, for somebody who walks in while it is being played:
## which robots have fallen, which zones are being fought over, what has
## exploded, the last checkpoint, the kills and where the robots are.
func net_snapshot() -> Dictionary:
	var fallen: Array[int] = []
	for number: int in _robots:
		var robot: Variant = _robots[number]
		if not is_instance_valid(robot) or robot.dead:
			fallen.append(number)
	var started: Array[int] = []
	for i in zones.size():
		if zones[i].started:
			started.append(i)
	var blown: Array[NodePath] = []
	for path in _explosives:
		var explosive := get_node_or_null(path)
		if explosive == null or explosive.gone:
			blown.append(path)
	return {"fallen": fallen, "started": started, "blown": blown, "checkpoint": _checkpoint, "kills": kills, "robots": _robot_states()}


## Brings a level that has just been loaded to how the host's stands.
func net_restore(state: Dictionary) -> void:
	for number: int in state.fallen:
		var robot: Variant = _robots.get(number)
		if not is_instance_valid(robot) or robot.dead:
			continue
		for zone in zones:
			if zone.robots.has(robot):
				zone.alive -= 1
				zone.cleared = zone.alive <= 0
		robot.free()
	for i: int in state.started:
		_show_start(i)
	for path: NodePath in state.blown:
		var explosive := get_node_or_null(path)
		if explosive:
			explosive.vanish(true)
	_checkpoint = state.checkpoint
	kills = state.kills
	kills_changed.emit(kills)
	_move_robots(state.robots, true)
	_update_objective()
	if _route_cleared():
		_open_exit(false)
