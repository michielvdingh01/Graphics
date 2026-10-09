extends Node3D
## Level flow: bakes the navmesh and takes the player down the route the level
## describes (tools/levels/<name>.gd, built into Level/Route). A fight starts
## when the player walks into a zone, with the robots that zone lists. A
## checkpoint is a place: it counts once everything before it is cleared, and
## a death or a restart of the game carries on from the last one. The exit
## opens when every zone is cleared.

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
## Shortest and longest time before a spawned enemy comes looking for the player.
const HUNT_DELAY := Vector2(1.5, 4.0)
const RESTART_DELAY := 2.5
## How long the screen takes to go dark at the exit before the next level loads.
const EXIT_FADE := 0.9


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
	zone.started = true
	for spawn in zone.area.get_children():
		if not spawn.is_in_group("enemy_spawn"):
			continue
		var enemy: Node3D = ENEMIES[spawn.get_meta(&"kind")].instantiate()
		enemy.position = (spawn as Node3D).global_position
		# Facing the way the player came in.
		var towards := player.global_position - enemy.position
		enemy.rotation.y = atan2(-towards.x, -towards.z)
		enemy.died.connect(_on_enemy_died.bind(zone))
		add_child(enemy)
		zone.alive += 1
		# One that cannot see the player would otherwise stand there for good.
		get_tree().create_timer(randf_range(HUNT_DELAY.x, HUNT_DELAY.y), false).timeout.connect(enemy.alert)
	_update_objective()


func _on_enemy_died(_enemy: Node3D, zone: Zone) -> void:
	kills += 1
	kills_changed.emit(kills)
	zone.alive -= 1
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
