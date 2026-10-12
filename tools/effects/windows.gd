extends RefCounted
## The glass of the windows: a shot goes through a pane and breaks it and no
## other, a blast breaks the panes it gets to and no wall hides from it, and
## only so many of them leave shards, what is left is the same for whoever
## comes into the level later, and nothing of it is in the way of a shot or
## of what an enemy sees.

## For every level: how many windows the level builder's glass makes, and how
## many panes they have together.
const LEVELS := {
	"factory": [30, 189],
	"works": [61, 193],
	"depot": [1, 3],
	"powerhouse": [35, 303],
}
## The layer the glass is on, and the triangle corners of one pane.
const WINDOW := 64
const CORNERS := 36

var _test: SceneTree
var _fx: Node


func run(test: SceneTree) -> void:
	_test = test
	_fx = test.autoload("Fx")
	var net: Node = test.autoload("Net")
	var blast: Node = test.autoload("Blast")
	var game: Node = await test.level()
	var space: PhysicsDirectSpaceState3D = (game as Node3D).get_world_3d().direct_space_state
	var windows: Array[Node] = _windows(game)
	_count(game, "factory")

	# A window that the builder left a pane out of, and the first of the
	# panes it has.
	var window: StaticBody3D = null
	var hole := Vector3.INF
	for one: StaticBody3D in windows:
		hole = _hole_in(one, space)
		if hole != Vector3.INF and one.size() >= 12:
			window = one
			break
	test.check(window != null, "there is a window that had a pane missing when the level was built")
	if window == null:
		return
	var glass: MeshInstance3D = _glass_of(game, window)
	var saved: Mesh = _saved(game, glass)
	var whole: int = glass.mesh.surface_get_array_index_len(0)
	var points: int = glass.mesh.surface_get_array_len(0)
	test.check(glass.mesh != saved and glass.mesh.get_surface_count() == 1 and glass.mesh.surface_get_format(0) == saved.surface_get_format(0)
		and whole == saved.surface_get_array_index_len(0) and points == saved.surface_get_array_len(0),
		"the glass of a zone is drawn with a mesh of its own, made as the saved one is")
	var pane := 0
	var through: Vector3 = window.facing(pane)
	var at: Vector3 = window.middle(pane)
	var from := at - through * 3.0
	var to := at + through * 3.0

	# Nothing but a ray on its own layer finds it.
	var sees: int = (load("res://scripts/enemy.gd") as GDScript).get_script_constant_map().LOS_MASK
	var shoots: int = (load("res://scripts/weapons.gd") as GDScript).get_script_constant_map().HIT_MASK
	test.check(space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, sees)).is_empty(), "an enemy sees through a window as before")
	test.check(space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, shoots)).is_empty(), "and a shot is not stopped by one")
	var found := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, WINDOW))
	test.check(not found.is_empty() and found.collider == window and window.shape_find_owner(found.shape) == pane, "a ray on the layer of the windows finds the pane it goes through")

	# A guest shows the shot and breaks nothing: that is for the host to say.
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 9)
	net.multiplayer.multiplayer_peer = peer
	net.active = true
	var guest: bool = net.is_guest()
	_fx.tracer(from, to)
	var kept: bool = window.standing() == window.size()
	net.active = false
	peer.close()
	net.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	test.check(guest and kept and not net.is_guest(), "a guest's tracer breaks nothing by itself")

	# One shot, one pane.
	var standing: int = _standing(windows)
	_fx.tracer(from, to)
	test.check(window.standing() == window.size() - 1 and window.net_state() == 1 << pane and _standing(windows) == standing - 1,
		"a shot through a pane breaks that pane and no other")
	test.check(_later(space, from, to) != window, "the pane is gone for the next shot")
	var of_glass: Array = _shards()
	test.check(of_glass.size() >= 2 and of_glass.all(func(burst: MeshInstance3D) -> bool:
			return burst.get_instance_shader_parameter(&"area") == Vector2(window.measures(pane).x, window.measures(pane).y)),
		"its glass comes down as shards that start out all over the pane, on both sides of it")
	await test.frames(2)
	var teeth: PackedVector3Array = _teeth(glass)
	@warning_ignore("integer_division")
	var bites: int = teeth.size() / 3
	print("    the pane left %d teeth" % bites)
	test.check(glass.mesh.surface_get_array_index_len(0) == whole - CORNERS and glass.mesh.surface_get_array_len(0) == points and bites >= 3 and bites <= 24,
		"its triangles have left the mesh of the zone, and a few teeth have come instead")
	test.check(saved.surface_get_array_index_len(0) == whole and saved.surface_get_array_len(0) == points, "and the mesh the builder saved is as it was")
	var frame: Transform3D = glass.global_transform.affine_inverse() * Transform3D(window.global_basis * window.shape_owner_get_transform(pane).basis, at)
	var half: Vector2 = window.measures(pane) * 0.5
	test.check(Array(teeth).all(func(point: Vector3) -> bool:
			var local := point * frame
			return absf(local.y) < 0.001 and absf(local.x) <= half.x + 0.001 and absf(local.z) <= half.y + 0.001),
		"the teeth stand in the opening of that pane, in the middle of where the glass was")

	# Again through the hole, and through the one the builder left: the
	# streak of the shot is all that is added.
	var bursts: int = _fx._expiring.size()
	_fx.tracer(from, to)
	test.check(_standing(windows) == standing - 1 and _fx._expiring.size() == bursts + 1, "a second shot through the hole breaks nothing")
	bursts = _fx._expiring.size()
	_fx.tracer(hole - through * 3.0, hole + through * 3.0)
	test.check(_standing(windows) == standing - 1 and _fx._expiring.size() == bursts + 1, "a shot through a pane that was missing already breaks nothing")

	# The shards are cleared away when their time is up.
	_fx.advance(_fx.PANE_TIME + 0.1)
	await test.frames(2)
	test.check(of_glass.all(func(burst: Variant) -> bool: return not is_instance_valid(burst)), "the shards are cleared away when their time is up")

	# A rifle, from the floor of the hall.
	await _shoot(game, windows, space)

	# A blast in front of another window: what is within reach goes, what is
	# not stays.
	var other: StaticBody3D = null
	for one: StaticBody3D in windows:
		if one != window and one.size() >= 12 and one.standing() == one.size():
			other = one
			break
	test.check(other != null, "there is a whole window to set off a blast in front of")
	if other:
		var reach := 2.5
		var centre: Vector3 = other.middle(0) + other.facing(0)
		var near := 0
		for i: int in other.size():
			if other.middle(i).distance_to(centre) < reach:
				near |= 1 << i
		# With a wall between them the blast leaves the glass alone.
		var wall := StaticBody3D.new()
		var slab := CollisionShape3D.new()
		slab.shape = BoxShape3D.new()
		slab.shape.size = Vector3(12.0, 12.0, 0.1)
		wall.add_child(slab)
		game.add_child(wall)
		wall.global_transform = Transform3D(_fx.facing(other.facing(0)), other.middle(0) + other.facing(0) * 0.5)
		await test.frames(2)
		standing = _standing(windows)
		blast.explode(centre, reach, 150.0)
		test.check(near != 0 and _standing(windows) == standing, "a wall between a blast and a window saves its glass")
		wall.free()
		await test.frames(2)
		blast.explode(centre, reach, 150.0)
		print("    a blast of %.1f m a metre from a window of %d panes broke %d" % [reach, other.size(), other.size() - other.standing()])
		test.check(near != 0 and other.net_state() == near and other.standing() > 0, "a blast breaks the panes within its reach and leaves the ones beyond it")
		test.check(standing - _standing(windows) == other.size() - other.standing(), "and those of no other window")

		# A large blast breaks more panes than may leave shards: the glass of
		# the rest is gone without any.
		_fx.advance(_fx.PANE_TIME + 0.1)
		await test.frames(2)
		var whole_panes := {}
		for one: StaticBody3D in windows:
			whole_panes[one] = one.net_state()
		blast.explode(centre, 9.0, 150.0)
		var blown := 0
		var wanted := 0
		for one: StaticBody3D in windows:
			for i: int in one.size():
				if one.is_shape_owner_disabled(i) and whole_panes[one] & (1 << i) == 0:
					blown += 1
					var across: Vector2 = one.measures(i)
					wanted += clampi(ceili(across.x * across.y / _fx.PANE_PART), 1, 4)
		var thrown: int = _shards().filter(func(burst: MeshInstance3D) -> bool: return burst.mesh == _fx._pane_shards).size()
		print("    a blast of 9 m broke %d panes, which would be %d bursts of shards, and set off %d" % [blown, wanted, thrown])
		test.check(wanted > _fx.MAX_BLOWN and thrown <= _fx.MAX_BLOWN and thrown > _fx.MAX_BLOWN - 4, "a blast that breaks many panes sets off no more than %d bursts of shards" % _fx.MAX_BLOWN)

	# Somebody who comes in later: a level afresh, and what the host says of it.
	await test.frames(2)
	var states: Array = windows.map(func(one: Node) -> int: return one.net_state())
	var meshes: Array = _glasses(game).map(_bites)
	var corners: Array = _glasses(game).map(func(one: MeshInstance3D) -> int: return one.mesh.surface_get_array_index_len(0))
	var gone: int = states.filter(func(state: int) -> bool: return state != 0).size()
	game = await test.level()
	windows = _windows(game)
	test.check(windows.size() == states.size() and windows.all(func(one: Node) -> bool: return one.net_state() == 0), "a level that is loaded afresh has all its glass")
	for i in mini(windows.size(), states.size()):
		if states[i]:
			windows[i].net_restore(states[i])
	await test.frames(2)
	var same := true
	for i in mini(windows.size(), states.size()):
		same = same and windows[i].net_state() == states[i]
	print("    %d windows had lost panes" % gone)
	test.check(gone >= 2 and same and _shards().is_empty(), "what was broken before somebody came is gone for them too, without shards")
	test.check(_glasses(game).map(_bites) == meshes
		and _glasses(game).map(func(one: MeshInstance3D) -> int: return one.mesh.surface_get_array_index_len(0)) == corners,
		"and the teeth that stay are the same teeth")

	for level: String in LEVELS:
		if level != "factory":
			game = await test.level("res://scenes/%s.tscn" % level)
			_count(game, level)


## Checks the windows of a level against LEVELS: how many, how they are
## called, that the level keeps them for whoever comes in later, and how many
## panes they have: all the glass there is, and no window more than fits.
func _count(game: Node, level: String) -> void:
	var windows: Array[Node] = _windows(game)
	var panes := 0
	var named := true
	var most := 0
	for i in windows.size():
		panes += windows[i].size()
		most = maxi(most, windows[i].size())
		named = named and windows[i].name == "Window%d" % i and windows[i].collision_layer == WINDOW and game._breakables.has(windows[i])
	var glass := 0
	for mesh in _glasses(game):
		@warning_ignore("integer_division")
		glass += mesh.mesh.surface_get_array_index_len(0) / CORNERS
	print("    %s: %d windows of %d panes, %d at most" % [level, windows.size(), panes, most])
	_test.check(windows.size() == LEVELS[level][0] and panes == LEVELS[level][1] and panes == glass and named and most <= 31,
		"the %s has %d windows of %d panes together, called Window0 and so on" % [level, LEVELS[level][0], LEVELS[level][1]])
	_test.check(not windows.any(func(one: Node) -> bool: return one.has_method("cover") or one.has_method("lens")), "a window is told apart from a stack and from a lamp")


## A rifle shot from the floor at a pane that can be seen from there.
func _shoot(game: Node, windows: Array[Node], space: PhysicsDirectSpaceState3D) -> void:
	var player: CharacterBody3D = _test.get_first_node_in_group("player")
	var shoots: int = player.weapons.HIT_MASK
	var target: StaticBody3D = null
	var pane := -1
	var feet := Vector3.ZERO
	for one: StaticBody3D in windows:
		for i: int in one.size():
			var at: Vector3 = one.middle(i)
			if one.is_shape_owner_disabled(i) or absf(one.facing(i).y) > 0.1 or at.y < 2.5:
				continue
			for side: float in [1.0, -1.0]:
				var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + one.facing(i) * side * 5.0, at + one.facing(i) * side * 5.0 + Vector3.DOWN * 12.0, 1))
				if ground.is_empty():
					continue
				var eye: Vector3 = ground.position + Vector3.UP * 1.6
				var clear := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, at + (at - eye).normalized(), shoots)).is_empty()
				var room := space.intersect_ray(PhysicsRayQueryParameters3D.create(ground.position + Vector3.UP * 1.9, ground.position + Vector3.UP * 0.1, 1)).is_empty()
				if clear and room and target == null:
					target = one
					pane = i
					feet = ground.position
	_test.check(target != null, "there is a pane to shoot at from the floor")
	if target == null:
		return
	var at: Vector3 = target.middle(pane)
	var before: int = _standing(windows)
	player.force_control = true
	player.weapons._mags[0] = 30
	player.global_position = feet
	player.velocity = Vector3.ZERO
	player.look_at(Vector3(at.x, feet.y, at.z))
	await _test.wait(0.2)
	var eye: Vector3 = player.camera.global_position
	player.head.rotation.x = atan2(at.y - eye.y, Vector2(at.x - eye.x, at.z - eye.z).length())
	await _test.wait(0.1)
	Input.action_press("fire")
	await _test.wait(0.1)
	Input.action_release("fire")
	await _test.wait(0.2)
	_test.check(target.is_shape_owner_disabled(pane) and before - _standing(windows) <= 2, "a rifle shot from the floor breaks the pane it is aimed at")
	player.force_control = false

	# The streak of the player's shot starts at the muzzle, to the right of
	# the line the shot goes along. Aimed at the right-hand edge of a pane,
	# the streak passes through the pane beside it.
	eye = player.camera.global_position
	for one: int in target.size():
		for beside: int in target.size():
			var step: Vector3 = target.middle(beside) - target.middle(one)
			if target.is_shape_owner_disabled(one) or target.is_shape_owner_disabled(beside) or step.length() > 1.5 or step.normalized().dot(player.camera.global_basis.x) < 0.95:
				continue
			var aim: Vector3 = target.middle(one) + step.normalized() * (step.length() * 0.5 - 0.04)
			var muzzle: Vector3 = eye + (aim - eye).normalized() * 0.8 + step.normalized() * 0.15 + Vector3.DOWN * 0.12
			_fx.tracer(muzzle, eye + (aim - eye) * 2.0)
			_test.check(target.is_shape_owner_disabled(one) and not target.is_shape_owner_disabled(beside), "the pane under the crosshair breaks, not the one the streak of the shot passes through")
			return
	_test.check(false, "there are two panes side by side to aim between")


## The windows of a level, in the order the level keeps them in.
func _windows(game: Node) -> Array[Node]:
	return game.get_node("Level/Breakables").get_children().filter(func(body: Node) -> bool: return body.is_in_group("window"))


## The meshes the glass of a level is drawn with.
func _glasses(game: Node) -> Array[Node]:
	return game.get_node("Level").find_children("Glass", "MeshInstance3D", true, false)


## The points of the teeth that broken panes have left in a mesh of glass,
## three for each: its second surface, once there is one.
func _teeth(glass: MeshInstance3D) -> PackedVector3Array:
	return glass.mesh.surface_get_arrays(1)[Mesh.ARRAY_VERTEX] if glass.mesh.get_surface_count() > 1 else PackedVector3Array()


## The teeth in a mesh of glass one by one, in an order that does not depend
## on the order their panes broke in: a blast breaks the nearest first.
func _bites(glass: MeshInstance3D) -> Array:
	var points := _teeth(glass)
	var found := []
	for i in range(0, points.size(), 3):
		found.append([points[i], points[i + 1], points[i + 2]])
	found.sort()
	return found


## The mesh that draws the glass of a window.
func _glass_of(game: Node, window: StaticBody3D) -> MeshInstance3D:
	for glass: MeshInstance3D in _glasses(game):
		if glass.mesh == window._glazing.mesh:
			return glass
	return null


## The mesh the builder saved for the glass that `glass` draws: the one the
## scene of the level names for it.
func _saved(game: Node, glass: MeshInstance3D) -> Mesh:
	var level: Node = (load(game.scene_file_path) as PackedScene).instantiate()
	var mesh: Mesh = (level.get_node(game.get_path_to(glass)) as MeshInstance3D).mesh
	level.free()
	return mesh


## The bursts of glass that are in the air or on the floor at the moment.
func _shards() -> Array:
	var found := []
	for entry: Array in _fx._expiring:
		var burst: Variant = entry[0]
		if is_instance_valid(burst) and burst is MeshInstance3D:
			var material := (burst as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial
			if material and material.shader.resource_path == "res://shaders/glass.gdshader":
				found.append(burst)
	return found


## How many panes stand in all of the windows together.
func _standing(windows: Array[Node]) -> int:
	var count := 0
	for window in windows:
		count += window.standing()
	return count


## The window a ray on the layer of the windows finds from `from` to `to`.
func _later(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Object:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, WINDOW))
	return hit.collider if hit else null


## The middle of a pane that the builder left out of a window, between panes
## that are there; Vector3.INF if it has none.
func _hole_in(window: StaticBody3D, space: PhysicsDirectSpaceState3D) -> Vector3:
	var around := AABB(window.middle(0), Vector3.ZERO)
	for pane: int in window.size():
		around = around.expand(window.middle(pane))
	for pane: int in window.size():
		var frame: Transform3D = window.global_transform * window.shape_owner_get_transform(pane)
		var across: Vector2 = window.measures(pane)
		for step: Vector3 in [frame.basis.x * across.x, frame.basis.x * -across.x, frame.basis.z * across.y, frame.basis.z * -across.y]:
			var spot := frame.origin + step
			if around.grow(0.01).has_point(spot) and space.intersect_ray(PhysicsRayQueryParameters3D.create(spot - frame.basis.y, spot + frame.basis.y, WINDOW)).is_empty():
				return spot
	return Vector3.INF
