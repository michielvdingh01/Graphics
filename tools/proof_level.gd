extends SceneTree
## Makes a level to measure with out of several copies of one that is built
## and baked: the factory five times over, say, as one level of twenty zones
## and eighty robots. It answers what a level of that size costs to load, to
## hold in memory and to draw, before anybody builds one.
##   tools/proof_level.sh [level] [copies]
## It writes scenes/levels/proof_level.tscn and scenes/proof.tscn, which git
## passes over; make them again whenever the level they are copied from has
## been built again.
##
## The copies stand SPACING apart along X, too far to see or to shade each
## other. Every copy keeps its zones, its colliders and its robots; only the
## first keeps what lies around the building, its start, its checkpoints and
## its exit, so only the first can be played through. The zones of a copy
## share their meshes and their lightmaps with the first, which makes the
## level a little lighter in memory than one with twenty rooms of its own:
## see what tools/level_cost.gd says of one level and multiply.

const SPACING := 300.0


func _init() -> void:
	# Whatever goes wrong in there, Godot is not left running.
	_make()
	quit()


func _make() -> void:
	var args := OS.get_cmdline_user_args()
	var source := args[0] if args.size() > 0 else "factory"
	var copies := maxi(args[1].to_int(), 1) if args.size() > 1 else 5
	var packed := load("res://scenes/levels/%s_level.tscn" % source) as PackedScene
	if packed == null:
		push_error("There is no level called %s in scenes/levels/." % source)
		return
	var proof := Node3D.new()
	proof.name = "ProofLevel"
	proof.set_script(load("res://scripts/zones.gd"))
	var route: Node = null
	var fights: Array[Node3D] = []
	var zones := 0
	# Every node of the copies, to be owned by the new level once it stands.
	var moved: Array[Node] = []
	for i in copies:
		# Instantiated as the editor does it, so that the models in it are
		# saved as what they are and not as copies of their meshes.
		var level := packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		var offset := Vector3(SPACING * i, 0, 0)
		var suffix := "" if i == 0 else "_%d" % (i + 1)
		for node in level.find_children("*", "", true, false):
			if node.owner == level:
				node.owner = null
				moved.append(node)
		# What explodes knows its model by a path, which is about to change.
		var models := {}
		if level.has_node("Explosives"):
			for body in level.get_node("Explosives").get_children():
				models[body] = body.get_node(body.get("model"))
		var rest := Node3D.new()
		rest.name = "Copy%d" % (i + 1)
		rest.position = offset
		proof.add_child(rest)
		rest.owner = proof
		for child in level.get_children():
			level.remove_child(child)
			if child.is_in_group("level_zone"):
				_move_zone(child, offset, suffix)
				proof.add_child(child)
				zones += 1
			elif child.name == "Route":
				if i == 0:
					route = child
				else:
					for step: Node in child.get_children():
						if step.is_in_group("route_zone"):
							child.remove_child(step)
							(step as Node3D).position += offset
							step.set_meta(&"id", "%s%s" % [step.get_meta(&"id"), suffix])
							step.name = "%s%d" % [step.name, i + 1]
							fights.append(step)
					child.free()
			elif i > 0 and child.name not in [&"Collision", &"Explosives"]:
				# What lies around the building, in sight from anywhere.
				child.free()
			else:
				rest.add_child(child)
		for body: Node in models:
			var model: Node = models[body]
			if is_instance_valid(model) and proof.is_ancestor_of(model):
				body.set("model", body.get_path_to(model))
			else:
				body.free()
		level.free()
	if route:
		# The fights of the copies come before the exit of the first.
		proof.add_child(route)
		var exit := route.get_node_or_null("Exit")
		for fight in fights:
			route.add_child(fight)
			if exit:
				route.move_child(fight, exit.get_index())
	for node in moved:
		if is_instance_valid(node) and proof.is_ancestor_of(node):
			node.owner = proof
	var scene := PackedScene.new()
	scene.pack(proof)
	var err := ResourceSaver.save(scene, "res://scenes/levels/proof_level.tscn")
	# The scene that is played is the one of the level it was copied from,
	# with the copies for a level.
	var played := FileAccess.get_file_as_string("res://scenes/%s.tscn" % source)
	played = played.replace("res://scenes/levels/%s_level.tscn" % source, "res://scenes/levels/proof_level.tscn")
	var header := played.get_slice("\n", 0)
	played = played.replace(header, "[gd_scene format=3]")
	FileAccess.open("res://scenes/proof.tscn", FileAccess.WRITE).store_string(played)
	print("Proof level: %d copies of %s, %d zones, %s" % [copies, source, zones, error_string(err)])


## Stands a zone of a copy where the copy stands, under a name of its own.
func _move_zone(zone: Node3D, offset: Vector3, suffix: String) -> void:
	zone.position += offset
	zone.name = "%s%s" % [zone.name, suffix.trim_prefix("_")]
	zone.set_meta(&"zone", "%s%s" % [zone.get_meta(&"zone"), suffix])
	var sees := PackedStringArray()
	for other: String in zone.get_meta(&"sees"):
		sees.append(other + suffix)
	zone.set_meta(&"sees", sees)
	var bounds: Array[AABB] = []
	for box: AABB in zone.get_meta(&"bounds"):
		bounds.append(AABB(box.position + offset, box.size))
	zone.set_meta(&"bounds", bounds)
	# A copy of the numbers: the ones on the zone are shared by all the copies.
	var views: PackedFloat32Array = (zone.get_meta(&"views", PackedFloat32Array()) as PackedFloat32Array).duplicate()
	for v in range(0, views.size(), 5):
		views[v] += offset.x
		views[v + 1] += offset.y
		views[v + 2] += offset.z
	zone.set_meta(&"views", views)
