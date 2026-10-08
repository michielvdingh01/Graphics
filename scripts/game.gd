extends Node3D
## Level flow: bakes the navmesh, spawns enemy waves and restarts from the last
## checkpoint on death. Every wave the player reaches is a checkpoint.

signal wave_started(wave: int)
signal kills_changed(kills: int)

const GRUNT := preload("res://scenes/enemy.tscn")
const RUSHER := preload("res://scenes/enemy_rusher.tscn")
const HEAVY := preload("res://scenes/enemy_heavy.tscn")
const MAX_ENEMIES := 8
const MAX_RUSHERS := 3
const MIN_SPAWN_DISTANCE := 14.0
const WAVE_DELAY := 3.0
## Shortest and longest time before a spawned enemy comes looking for the player.
const HUNT_DELAY := Vector2(1.5, 4.0)
const RESTART_DELAY := 2.5

var wave := 0
var kills := 0
var _alive := 0

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var player: CharacterBody3D = $Player


func _ready() -> void:
	Settings.apply()
	# The level's static body is built a frame late, so wait before baking from
	# it. The server only picks this bake up with region_use_async_iterations off.
	await get_tree().physics_frame
	await get_tree().physics_frame
	nav_region.bake_navigation_mesh(false)
	# Behind the title screen the level is only a backdrop.
	if Benchmark.active or Menu.at_title():
		return
	player.died.connect(_on_player_died)
	var checkpoint := Save.resume_point(scene_file_path)
	if checkpoint:
		wave = checkpoint.wave - 1
		kills = checkpoint.kills
		kills_changed.emit(kills)
	_start_wave()


## Scenes to spawn for a wave: grunts first, then rushers and heavies mixed in
## as the waves go up.
func roster(for_wave: int) -> Array[PackedScene]:
	var count := mini(2 + for_wave, MAX_ENEMIES)
	@warning_ignore("integer_division")
	var heavies := (for_wave - 1) / 3
	@warning_ignore("integer_division")
	var rushers := mini(for_wave / 2, MAX_RUSHERS)
	var scenes: Array[PackedScene] = []
	for i in count:
		if i < heavies:
			scenes.append(HEAVY)
		elif i < heavies + rushers:
			scenes.append(RUSHER)
		else:
			scenes.append(GRUNT)
	return scenes


func _start_wave() -> void:
	wave += 1
	Save.store(scene_file_path, wave, kills)
	player.weapons.refill()
	var spawns := get_tree().get_nodes_in_group("enemy_spawn").filter(
		func(spawn: Node3D) -> bool:
			return spawn.global_position.distance_to(player.global_position) > MIN_SPAWN_DISTANCE
	)
	spawns.shuffle()
	var scenes := roster(wave)
	for i in scenes.size():
		var enemy := scenes[i].instantiate()
		var spawn: Node3D = spawns[i % spawns.size()]
		# Doubled-up spawn points get a small offset so enemies do not overlap.
		@warning_ignore("integer_division")
		enemy.position = spawn.global_position + Vector3(i / spawns.size() * 1.2, 0.0, 0.0)
		enemy.died.connect(_on_enemy_died)
		add_child(enemy)
		# One that spawns out of sight would otherwise stand there for good.
		get_tree().create_timer(randf_range(HUNT_DELAY.x, HUNT_DELAY.y), false).timeout.connect(enemy.alert)
	_alive = scenes.size()
	wave_started.emit(wave)


func _on_enemy_died(_enemy: Node3D) -> void:
	kills += 1
	_alive -= 1
	kills_changed.emit(kills)
	if _alive <= 0:
		await get_tree().create_timer(WAVE_DELAY, false).timeout
		_start_wave()


func _on_player_died() -> void:
	await get_tree().create_timer(RESTART_DELAY, false).timeout
	get_tree().reload_current_scene()
