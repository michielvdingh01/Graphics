extends Node3D
## Level flow: bakes the navmesh, spawns enemy waves and restarts on death.

signal wave_started(wave: int)
signal kills_changed(kills: int)

const ENEMY := preload("res://scenes/enemy.tscn")
const MAX_ENEMIES := 8
const MIN_SPAWN_DISTANCE := 14.0
const WAVE_DELAY := 3.0
const RESTART_DELAY := 2.5

var wave := 0
var kills := 0
var _alive := 0

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var player: CharacterBody3D = $Player


func _ready() -> void:
	# CSG builds its geometry a frame late, so wait before baking from it. The
	# server only picks this bake up with region_use_async_iterations off.
	await get_tree().physics_frame
	await get_tree().physics_frame
	nav_region.bake_navigation_mesh(false)
	if Benchmark.active:
		return
	player.died.connect(_on_player_died)
	_start_wave()


func _start_wave() -> void:
	wave += 1
	player.weapons.refill()
	var spawns := get_tree().get_nodes_in_group("enemy_spawn").filter(
		func(spawn: Node3D) -> bool:
			return spawn.global_position.distance_to(player.global_position) > MIN_SPAWN_DISTANCE
	)
	spawns.shuffle()
	var count := mini(2 + wave, MAX_ENEMIES)
	for i in count:
		var enemy := ENEMY.instantiate()
		var spawn: Node3D = spawns[i % spawns.size()]
		# Doubled-up spawn points get a small offset so enemies do not overlap.
		enemy.position = spawn.global_position + Vector3(i / spawns.size() * 1.2, 0.0, 0.0)
		enemy.died.connect(_on_enemy_died)
		add_child(enemy)
	_alive = count
	wave_started.emit(wave)


func _on_enemy_died(_enemy: Node3D) -> void:
	kills += 1
	_alive -= 1
	kills_changed.emit(kills)
	if _alive <= 0:
		await get_tree().create_timer(WAVE_DELAY, false).timeout
		_start_wave()


func _on_player_died() -> void:
	await get_tree().create_timer(RESTART_DELAY).timeout
	get_tree().reload_current_scene()
