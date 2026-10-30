extends SceneTree
## Checks the yard of the Alps (tools/levels/alps_yard.gd) as the game would
## find it: that a bot can walk into the barns and the stable, up the stair
## of the hunter's stand and over the bridge, on a navmesh baked as the Alps
## bake theirs (tools/levels/alps/plan.gd); and that a shot through the wall
## of a barn stops, unless it goes through a gap or a hatch. Build the yard
## first, then run with:
##   timeout 300 /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/alpine_check.gd

var _failed := 0


func _initialize() -> void:
	var level: Node3D = (load("res://scenes/levels/alps_yard_level.tscn") as PackedScene).instantiate()
	root.add_child(level)
	for i in 3:
		await physics_frame
	var space := level.get_world_3d().direct_space_state
	_walks(level)
	await _wait_for_map(level)
	_shots(space)
	await _climbs(level)
	print("alpine_check: %s" % ("all passed" if _failed == 0 else "%d failed" % _failed))
	quit(1 if _failed else 0)


func _check(what: String, ok: bool, detail := "") -> void:
	print("%s  %s%s" % ["ok  " if ok else "FAIL", what, ("  (" + detail + ")") if detail != "" else ""])
	if not ok:
		_failed += 1


## The ways a bot is to find: from where to where, the box the navmesh is
## baked in for it, and how high a step it takes from one cell to the next if
## not the 0.25 m of the Alps.
const WAYS := [
	["up the stair of the hunter's stand", Vector3(-28, 100, 16), Vector3(-28, 104.5, 30.2), AABB(Vector3(-40, 95, 10), Vector3(24, 16, 30))],
	["up the stair to the loft of the large barn of logs", Vector3(32, 100, 11), Vector3(32, 102.8, -3.0), AABB(Vector3(20, 95, -10), Vector3(24, 12, 26))],
	["into the large barn of logs", Vector3(32, 100, 11), Vector3(32, 100.3, -2.0), AABB(Vector3(20, 95, -10), Vector3(24, 12, 26))],
	["into the small barn of logs", Vector3(0, 100, 7), Vector3(0, 100.3, -1.5), AABB(Vector3(-10, 95, -8), Vector3(20, 12, 20))],
	["into the large barn of boards", Vector3(32, 100, -33), Vector3(32, 100.4, -21), AABB(Vector3(20, 95, -40), Vector3(24, 12, 28))],
	["into the barn on the mound", Vector3(80.3, 101, 64.5), Vector3(74, 104, 56), AABB(Vector3(60, 95, 42), Vector3(30, 14, 30))],
	["into the stable of the farmhouse", Vector3(19.6, 100, 59), Vector3(21.5, 100.3, 48.5), AABB(Vector3(2, 95, 38), Vector3(30, 12, 26))],
	["over the bridge", Vector3(92, 100, 25.5), Vector3(92, 100, 42), AABB(Vector3(82, 95, 18), Vector3(20, 12, 30))],
]


## Bakes a navmesh round each way, the way the Alps are baked, and asks for
## the path along it.
func _walks(level: Node3D) -> void:
	for way: Array in WAYS:
		var navmesh := NavigationMesh.new()
		navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
		navmesh.geometry_collision_mask = 1
		navmesh.cell_size = 0.5
		navmesh.cell_height = 0.25
		navmesh.agent_radius = 0.5
		navmesh.edge_max_error = 1.0
		navmesh.border_size = 2.0
		navmesh.filter_baking_aabb = way[3]
		navmesh.agent_max_climb = way[4] if way.size() > 4 else 0.25
		var source := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(navmesh, source, level)
		NavigationServer3D.bake_from_source_geometry_data(navmesh, source)
		var region := NavigationRegion3D.new()
		region.navigation_mesh = navmesh
		region.name = "Walk%d" % level.get_child_count()
		level.add_child(region)


func _wait_for_map(level: Node3D) -> void:
	var map := level.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, 0.5)
	NavigationServer3D.map_set_cell_height(map, 0.25)
	# The regions are baked on threads: wait until the map has them all.
	for i in 1200:
		await physics_frame
		if i > 10 and NavigationServer3D.map_get_iteration_id(map) > 0 and NavigationServer3D.map_get_regions(map).size() >= WAYS.size():
			var near := NavigationServer3D.map_get_closest_point(map, WAYS[WAYS.size() - 1][1])
			if near != Vector3.ZERO:
				break
	for i in 10:
		await physics_frame
	for way: Array in WAYS:
		var from: Vector3 = way[1]
		var to: Vector3 = way[2]
		var start := NavigationServer3D.map_get_closest_point(map, from)
		var goal := NavigationServer3D.map_get_closest_point(map, to)
		var path := NavigationServer3D.map_get_path(map, start, goal, true)
		var reached := not path.is_empty() and path[path.size() - 1].distance_to(goal) < 0.6 and goal.distance_to(to) < 1.2
		var highest := -INF
		for point in path:
			highest = maxf(highest, point.y)
		_check(way[0], reached, "from %s to %s, nearest on the navmesh %s, %d points, highest %.2f, ends at %s" % [from, to, goal, path.size(), highest, path[path.size() - 1] if not path.is_empty() else Vector3.INF])


## Shots at the walls of the barns, from outside in, at every centimetre of
## height: how many of them get through, and where.
func _shots(space: PhysicsDirectSpaceState3D) -> void:
	# The east wall of the large barn of logs (its hatch is on one side or the
	# other), the west wall of the middle one, and the east wall of the large
	# barn of boards; and the parapet of the hunter's stand.
	for shot: Array in [
		["the east wall of the large barn of logs", Vector3(40, 0, 1.0), Vector3(32, 0, 1.0), 100.32],
		["the west wall of the large barn of logs", Vector3(24, 0, 1.0), Vector3(32, 0, 1.0), 100.32],
		["the side of the middle barn of logs", Vector3(23, 0, -1.5), Vector3(15, 0, -1.5), 100.32],
	]:
		var from: Vector3 = shot[1]
		var to: Vector3 = shot[2]
		var floor_y: float = shot[3]
		var through: Array[float] = []
		for cm in range(5, 330):
			var y := floor_y + cm * 0.01
			var ray := PhysicsRayQueryParameters3D.create(Vector3(from.x, y, from.z), Vector3(to.x, y, to.z), 1)
			if space.intersect_ray(ray).is_empty():
				through.append(cm * 0.01)
		var gaps: Array[String] = []
		var start := -1.0
		var last := -1.0
		for h in through:
			if start < 0.0:
				start = h
			elif h - last > 0.015:
				gaps.append("%.2f-%.2f" % [start, last])
				start = h
			last = h
		if start >= 0.0:
			gaps.append("%.2f-%.2f" % [start, last])
		var widest := 0.0
		for gap in gaps:
			widest = maxf(widest, float(gap.get_slice("-", 1)) - float(gap.get_slice("-", 0)))
		_check("%s stops a shot, except through its gaps" % shot[0], through.size() < 120 and not gaps.is_empty(), "%d of 325 heights get through: %s" % [through.size(), ", ".join(gaps)])
	# And along the walls at the height of an eye and of a knee: where along
	# them a shot gets through, which for boards is the slots between their
	# runs and for both the hatch in one side.
	for sweep: Array in [
		["the east wall of the large barn of logs, on a log at an eye", 40.0, 32.0, 0.0, 1.45 + 100.32, Vector2(-4.4, 4.4)],
		["the west wall of the large barn of logs, on a log at an eye", 24.0, 32.0, 0.0, 1.45 + 100.32, Vector2(-4.4, 4.4)],
		["the east wall of the large barn of boards, at an eye", 40.0, 32.0, -22.0, 1.6 + 100.4, Vector2(-4.4, 4.4)],
		["the east wall of the large barn of boards, at a knee", 40.0, 32.0, -22.0, 0.6 + 100.4, Vector2(-4.4, 4.4)],
		["the west wall of the large barn of boards, at an eye", 24.0, 32.0, -22.0, 1.6 + 100.4, Vector2(-4.4, 4.4)],
	]:
		var through: Array[float] = []
		var z_from: Vector2 = sweep[5]
		for cm in range(int(z_from.x * 100), int(z_from.y * 100)):
			var z: float = float(sweep[3]) + cm * 0.01
			var ray := PhysicsRayQueryParameters3D.create(Vector3(sweep[1], sweep[4], z), Vector3(sweep[2], sweep[4], z), 1)
			if space.intersect_ray(ray).is_empty():
				through.append(cm * 0.01)
		var spans: Array[String] = []
		var start := -100.0
		var last := -100.0
		for z in through:
			if start < -99.0:
				start = z
			elif z - last > 0.015:
				spans.append("%.2f..%.2f" % [start, last])
				start = z
			last = z
		if start > -99.0:
			spans.append("%.2f..%.2f" % [start, last])
		print("      %s: %d of %d cm along it let a shot through: %s" % [sweep[0], through.size(), int((z_from.y - z_from.x) * 100), ", ".join(spans)])


## Whoever walks: a body the shape of the player (scripts/player.gd), set
## down at the foot of a stair and walked at it, at a walking pace. It should
## come out at the top.
const CLIMBS := [
	["a player walks up the stair of the hunter's stand", Vector3(-28, 100.95, 21.5), Vector3(-28, 104.5, 30.0)],
	["a player walks up the stair to the loft of the large barn", Vector3(32.75, 101.3, 3.4), Vector3(32.4, 102.81, -1.5)],
	["a player walks up the ramp into the barn on the mound", Vector3(80.3, 102.0, 64.5), Vector3(74.0, 104.0, 56.0)],
	["a player walks up the ramp into the stable", Vector3(19.6, 100.0, 59.0), Vector3(21.5, 100.25, 48.5)],
]


func _climbs(level: Node3D) -> void:
	for climb: Array in CLIMBS:
		var body := CharacterBody3D.new()
		body.collision_mask = 1
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.35
		capsule.height = 1.8
		shape.shape = capsule
		shape.position.y = 0.9
		body.add_child(shape)
		level.add_child(body)
		# On whatever is under the spot it starts from.
		var start: Vector3 = climb[1]
		var down := PhysicsRayQueryParameters3D.create(start + Vector3.UP * 3.0, start + Vector3.DOWN * 10.0, 1)
		var under := level.get_world_3d().direct_space_state.intersect_ray(down)
		body.global_position = (under.position as Vector3) + Vector3.UP * 0.05 if under else start
		var goal: Vector3 = climb[2]
		var highest := -INF
		for i in 600:
			var flat := Vector3(goal.x - body.global_position.x, 0, goal.z - body.global_position.z)
			if flat.length() < 0.3:
				break
			body.velocity = flat.normalized() * 4.0 + Vector3.DOWN * (0.0 if body.is_on_floor() else 4.0)
			body.move_and_slide()
			highest = maxf(highest, body.global_position.y)
			await physics_frame
		var arrived := Vector2(body.global_position.x - goal.x, body.global_position.z - goal.z).length() < 0.6 and absf(body.global_position.y - goal.y) < 0.4
		_check(climb[0], arrived, "ends at %s, highest %.2f" % [body.global_position, highest])
		body.queue_free()
