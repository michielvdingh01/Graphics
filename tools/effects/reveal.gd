extends RefCounted
## The dunes, where two things are not as in a level of rooms. The glass of
## the main building sits a hand deep in a wall whose collider has no
## opening: a shot at a pane stops on that wall, and has to break the pane
## all the same. And the slabs of the yard lie on land, which is one
## collider and all of it sand: a step or a shot on a slab has to be on
## concrete.

const DUNES := "res://scenes/dunes.tscn"
## The layer the glass is on, and the triangle corners of one pane.
const WINDOW := 64
const CORNERS := 36


func run(test: SceneTree) -> void:
	var fx: Node = test.autoload("Fx")
	var game: Node = await test.level(DUNES)
	var space: PhysicsDirectSpaceState3D = (game as Node3D).get_world_3d().direct_space_state
	var windows: Array[Node] = []
	for one in test.get_nodes_in_group("window"):
		if game.is_ancestor_of(one):
			windows.append(one)
	var panes := 0
	var most := 0
	for one in windows:
		panes += one.size()
		most = maxi(most, one.size())
	var glass := 0
	for mesh: MeshInstance3D in game.find_children("Glass", "MeshInstance3D", true, false):
		@warning_ignore("integer_division")
		glass += mesh.mesh.surface_get_array_index_len(0) / CORNERS
	print("    dunes: %d windows of %d panes, %d at most" % [windows.size(), panes, most])
	test.check(not windows.is_empty() and panes == glass and most <= 31, "every pane of the glass of the dunes is in a window")
	test.check(windows.size() * 4 < panes, "the panes of an opening are one window, not a window each")

	# A pane that is looked up at from the ground before it, as the player
	# does: the shot stops on the wall, short of the glass.
	var shoots: int = (load("res://scripts/weapons.gd") as GDScript).get_script_constant_map().HIT_MASK
	var target: StaticBody3D = null
	var pane := -1
	var eye := Vector3.ZERO
	var stopped := Vector3.ZERO
	for one: StaticBody3D in windows:
		for i: int in one.size():
			var at: Vector3 = one.middle(i)
			var out: Vector3 = one.facing(i)
			if absf(out.y) > 0.1:
				continue
			for side: float in [1.0, -1.0]:
				var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + out * side * 12.0, at + out * side * 12.0 + Vector3.DOWN * 30.0, 1))
				if ground.is_empty() or target != null:
					continue
				var from: Vector3 = ground.position + Vector3.UP * 1.6
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, at + (at - from).normalized() * 2.0, shoots))
				if not hit.is_empty() and (hit.position as Vector3).distance_to(at) < 0.5 and (hit.position as Vector3).distance_to(from) < at.distance_to(from):
					target = one
					pane = i
					eye = from
					stopped = hit.position
	test.check(target != null, "there is a pane that a shot from the ground stops short of, on the wall it sits in")
	if target != null:
		print("    the shot stops %.2f m before the glass" % stopped.distance_to(target.middle(pane)))
		var standing: int = target.standing()
		fx.tracer(eye, stopped)
		await test.frames(2)
		test.check(target.is_shape_owner_disabled(pane) and target.standing() == standing - 1, "and it breaks that pane and no other")

	# The road behind the main building is paved; the yard beside it is not.
	var on_slab := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(100, 30, 23.5), Vector3(100, -10, 23.5), 1))
	var on_sand := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(100, 30, 36), Vector3(100, -10, 36), 1))
	test.check(not on_slab.is_empty() and fx.surface_of(on_slab) == "concrete", "a step on a slab of the yard is on concrete")
	test.check(not on_sand.is_empty() and fx.surface_of(on_sand) == "sand", "and one beside it on sand")
