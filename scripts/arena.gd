class_name Arena
extends Node
## Spawns and respawns enemies once the navigation mesh is baked, and counts kills.
## In benchmark mode it places frozen enemies on fixed markers instead, so views are repeatable.

signal kills_changed(kills: int)

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const TARGET_ALIVE := 4
const SPAWN_INTERVAL := 3.0
const MIN_SPAWN_DISTANCE := 16.0

@export var nav_region: NavigationRegion3D

var kills := 0

var _alive: Array[Enemy] = []
var _spawn_t := 1.0
var _ready_to_spawn := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("arena")
	_rng.randomize()
	if Benchmark.active:
		_spawn_benchmark_enemies.call_deferred()
		return
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.respawned.connect(_clear_enemies)
	_bake_navigation()


## Builds the navmesh from the CPU-side level geometry (CSG faces), so nothing is read back from
## the GPU and the bake also works headless.
func _bake_navigation() -> void:
	# CSG shapes compute their geometry on the first frames after entering the tree.
	await get_tree().process_frame
	await get_tree().process_frame
	var source := NavigationMeshSourceGeometryData3D.new()
	for root in get_tree().get_nodes_in_group("navigation_geometry"):
		_collect_geometry(root, source)
	var nav_mesh := nav_region.navigation_mesh.duplicate() as NavigationMesh
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source)
	nav_region.navigation_mesh = nav_mesh
	_ready_to_spawn = true


func _collect_geometry(node: Node, source: NavigationMeshSourceGeometryData3D) -> void:
	if node is CSGShape3D and node.is_root_shape():
		var shape := node.bake_collision_shape() as ConcavePolygonShape3D
		if shape:
			source.add_faces(shape.get_faces(), node.global_transform)
	elif node is MeshInstance3D and node.mesh is PrimitiveMesh:
		source.add_mesh_array((node.mesh as PrimitiveMesh).get_mesh_arrays(), node.global_transform)
	for child in node.get_children():
		_collect_geometry(child, source)


func _process(delta: float) -> void:
	if not _ready_to_spawn:
		return
	_spawn_t -= delta
	if _spawn_t <= 0.0 and _alive.size() < TARGET_ALIVE:
		_spawn_t = SPAWN_INTERVAL
		_spawn_enemy()


func _spawn_enemy() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var points := get_tree().get_nodes_in_group("enemy_spawn")
	points.shuffle()
	for point: Node3D in points:
		if player and point.global_position.distance_to(player.global_position) < MIN_SPAWN_DISTANCE:
			continue
		_add_enemy(point.global_position, point.global_rotation.y, false)
		return


func _add_enemy(position: Vector3, yaw: float, frozen: bool) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.frozen = frozen
	get_parent().add_child(enemy)
	enemy.global_position = position
	enemy.rotation.y = yaw
	enemy.died.connect(_on_enemy_died)
	_alive.append(enemy)
	return enemy


func _on_enemy_died(enemy: Enemy) -> void:
	_alive.erase(enemy)
	kills += 1
	kills_changed.emit(kills)


func _clear_enemies() -> void:
	for enemy in _alive:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_alive.clear()
	_spawn_t = 2.0


func _spawn_benchmark_enemies() -> void:
	for marker: Node3D in get_tree().get_nodes_in_group("benchmark_enemy"):
		_add_enemy(marker.global_position, marker.global_rotation.y, true)
