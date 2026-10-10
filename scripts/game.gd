extends Node3D
## Level flow: bakes the navmesh and takes the player down the route the level
## describes (tools/levels/<name>.gd, built into Level/Route). The robots a
## zone lists stand at their posts from the moment the level loads, switched
## off. Their fight starts when the player walks into the zone or shoots at
## one of them. A checkpoint is a place: it counts once everything before it
## is cleared, and a death or a restart of the game carries on from the last
## one. The exit opens when every zone is cleared: its lamp comes on and its
## door rolls up.

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

## Index of the checkpoint to carry on from; -1 is the start of the level.
var _checkpoint := -1
var _finished := false

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
		_update_objective()
		if _route_cleared():
			_open_exit(false)
	elif exit:
		_put_player(start)
	# The level's static body is built a frame late, so wait before baking from
	# it. The server only picks this bake up with region_use_async_iterations off.
	await get_tree().physics_frame
	await get_tree().physics_frame
	nav_region.bake_navigation_mesh(false)
	# Cover is only looked for where there is fighting: in the zones.
	var grounds: Array[AABB] = []
	for zone in zones:
		var size: Vector3 = (zone.area.get_child(0) as CollisionShape3D).shape.size
		grounds.append(AABB(zone.area.global_position - size * 0.5, size).grow(0.3))
	Squad.fight_in(grounds)
	if playing:
		# And it is looked up now, while the screen is still coming up out of
		# black, not when the first fight asks for it.
		await get_tree().physics_frame
		Squad.prepare()


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
	var saved := Save.resume_point(scene_file_path)
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
## its signals died and disturbed, alert() and dead.
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
			# One that is shot at where it stands does not take it standing,
			# whether the shot hurt it or its plate stopped it.
			robot.disturbed.connect(_start.bind(zone))
			add_child(robot)
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


## Begins the fight for a zone: its robots are switched on.
func _start(zone: Zone) -> void:
	if zone.started:
		return
	zone.started = true
	for robot: Variant in zone.robots:
		if not is_instance_valid(robot) or robot.dead:
			continue
		robot.process_mode = Node.PROCESS_MODE_INHERIT
		# One that cannot see the player would otherwise stand there for good.
		get_tree().create_timer(randf_range(HUNT_DELAY.x, HUNT_DELAY.y), false).timeout.connect(robot.alert)
	_update_objective()


func _watch_route() -> void:
	for zone in zones:
		zone.area.body_entered.connect(_on_zone_entered.bind(zone))
	for i in checkpoints.size():
		checkpoints[i].area.body_entered.connect(_on_checkpoint_entered.bind(i))
	if exit:
		exit.body_entered.connect(_on_exit_entered)


func _put_player(pose: Transform3D) -> void:
	player.global_position = pose.origin
	player.rotation = Vector3(0.0, pose.basis.get_euler().y, 0.0)
	player.head.rotation.x = 0.0
	player.velocity = Vector3.ZERO


## True if the player really stands in the box of that step of the route.
## The physics server can report the spot the player had in the scene file
## before being put at the start, a frame after that was done.
func _holds(area: Area3D) -> bool:
	var size: Vector3 = (area.get_child(0) as CollisionShape3D).shape.size
	var box := AABB(area.global_position - size * 0.5, size).grow(0.5)
	return box.has_point(player.global_position + Vector3.UP * 0.9)


func _on_zone_entered(body: Node3D, zone: Zone) -> void:
	if body != player or zone.started or player.dead or not _holds(zone.area):
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
		# The player may be standing in a checkpoint already, or at the exit.
		for i in checkpoints.size():
			_on_checkpoint_entered(player, i)
	if _route_cleared():
		_open_exit(true)


func _on_checkpoint_entered(body: Node3D, index: int) -> void:
	if body != player or index <= _checkpoint or player.dead or fighting():
		return
	var checkpoint := checkpoints[index]
	if not _holds(checkpoint.area):
		return
	for zone in zones:
		if zone.order < checkpoint.order and not zone.cleared:
			return
	_checkpoint = index
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
	_on_exit_entered(player)


func _on_exit_entered(body: Node3D) -> void:
	if body != player or not exit_open or _finished or player.dead or not _holds(exit):
		return
	_finished = true
	var next := next_level()
	# The next level starts at its beginning; after the last there is nothing
	# left to carry on from.
	if next:
		Save.store(next, "", "", kills)
	else:
		Save.clear()
	finished.emit(next)
	await get_tree().create_timer(EXIT_FADE, false).timeout
	if next:
		get_tree().change_scene_to_file(next)
	else:
		Menu.show_end(kills)


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
	await get_tree().create_timer(RESTART_DELAY, false).timeout
	get_tree().reload_current_scene()
