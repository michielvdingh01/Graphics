extends SceneTree
## The headless test of what two teams fight over, see tools/test_prize.sh. It
## stands every prize of assets/prizes.json in the hall of the factory and
## goes through what can happen to it: somebody touches it, takes it, carries
## it, changes weapon with it on his back, lets go of it, is taken out of the
## level with it, and it is sent home. Whose rules those are is not looked at:
## the prize has none of its own.
##
## Next to those it makes prizes of its own the way a prize is made on a
## machine (see scripts/prize.gd): a folder in user://prizes/ with a model as
## a .glb. tools/test_prize.sh gives the test a home of its own, so that is
## not the folder of whoever plays here.

const FACTORY := "res://scenes/factory.tscn"
const PRIZE := "res://scenes/prize.tscn"
const PUPPET := "res://scenes/puppet.tscn"
## Open floor in the hall, and six metres of it to walk along.
const SPOT := Vector3(12, 0, 4)
const AWAY := Vector3(17.5, 0, 5.5)
const BLUE := Color(0.1, 0.34, 0.85)
## The prize the test makes: a crate with a band round it in the colour of
## its team, as long, high and deep as this.
const MADE := "test_crate"
const MADE_SIZE := Vector3(0.6, 0.4, 0.3)
## Seconds the whole of it may take before it is given up as hung.
const LIMIT := 120.0

var passed := 0
var failed := 0
## What a prize has said since the last look: its signals, by name.
var _heard := {}


func _initialize() -> void:
	create_timer(LIMIT, true, false, true).timeout.connect(
		func() -> void:
			print("PRIZE TEST FAILED (timed out)")
			quit(1)
	)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	root.get_node("Save").clear()
	change_scene_to_file(FACTORY)
	await scene_changed
	var game := current_scene
	for zone: RefCounted in game.zones:
		zone.area.set_deferred("monitoring", false)
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	await _frames(4)
	var prize_script: GDScript = load("res://scripts/prize.gd")
	await _made_ones(prize_script)
	var kinds: PackedStringArray = prize_script.kinds()
	check(kinds.size() >= 3 and kinds.has("flag") and kinds.has("football") and kinds.has("banana"), "the table lists a flag, a football and a banana")
	for kind in kinds:
		print("-- ", kind)
		await _go_through(kind, prize_script)
	print("%d of %d checks passed" % [passed, passed + failed])
	print("PRIZE TEST FAILED" if failed else "PRIZE TEST PASSED")
	quit(1 if failed else 0)


func _go_through(kind: String, prize_script: GDScript) -> void:
	var spec: Dictionary = prize_script.spec(kind)
	var made: bool = prize_script.made(kind)
	if not made:
		var models_there := true
		for key in ["model", "stand"]:
			models_there = models_there and ResourceLoader.exists("res://scenes/models/%s.scn" % spec.get(key, ""))
		check(models_there and spec.has("home") and spec.has("carried") and spec.has("down"), "it has a model, a stand and three ways of sitting")
	var prize: Node3D = (load(PRIZE) as PackedScene).instantiate()
	prize.kind = kind
	prize.team = 0
	prize.tint = BLUE
	prize.name = "Prize_%s" % kind
	current_scene.add_child(prize)
	prize.global_position = SPOT
	for heard: String in ["touched", "reached", "moved"]:
		_heard[heard] = 0
		prize.connect(heard, func(_body: Variant = null) -> void: _heard[heard] += 1)
	await _frames(3)
	# What it does not say of how it sits, a made prize has from its size.
	spec = prize._spec

	# At home.
	var item := prize.get_node_or_null("Prize") as Node3D
	var stand := prize.get_node_or_null("Stand") as Node3D
	check(item != null and stand != null and item.get_node_or_null("Model") != null, "it stands at home, on its stand")
	var home: Array = spec.home.at
	check(item != null and item.global_position.distance_to(SPOT + Vector3(home[0], home[1], home[2])) < 0.01, "where the table says")
	if made:
		var bottom: float = item.global_position.y + prize_script._bounds(item.get_node("Model")).position.y
		var top: float = SPOT.y + prize_script._bounds(stand).end.y
		check(absf(bottom - top) < 0.005, "a made prize stands on top of its stand (%.3f m over it)" % (bottom - top))
		var band := item.find_child("Team*", true, false) as MeshInstance3D
		var material := band.material_override as ShaderMaterial if band else null
		check(material != null and material.shader == (load("res://materials/team_paint.tres") as ShaderMaterial).shader, "and what of it takes the colour of a team is in the material for that")
	var coloured := 0
	var parts := 0
	for whole: Node3D in [stand, item]:
		for part: MeshInstance3D in whole.find_children("Team*", "MeshInstance3D", true, false):
			parts += 1
			var shown: Variant = part.get_instance_shader_parameter(&"team")
			if shown is Color and (shown as Color).is_equal_approx(BLUE) and part.get_instance_shader_parameter(&"teamed") == 1.0:
				coloured += 1
	check(parts >= 2 and coloured == parts, "the prize and its stand have the colour of their team (%d parts)" % parts)
	var net := item.find_child("Net", true, false) as Node3D
	check(net == null or not net.visible, "what it is carried in is not there while it is at home")
	check(prize.state == 0 and prize.where().distance_to(item.global_position) < 0.01, "it says that it is at home, and where")

	# Somebody comes up to it.
	var walker := _walker(SPOT + Vector3(4, 0, 0))
	await _frames(3)
	check(_heard.touched == 0 and _heard.reached == 0, "nobody is near it")
	walker.global_position = SPOT + Vector3(0.6, 0, 0)
	await _frames(4)
	check(_heard.touched == 1 and _heard.reached == 1, "somebody who walks up to it touches it, and is at its stand")
	check(prize.at_stand().has(walker) and prize.within_reach().has(walker), "and is known to be there")

	# Taken and carried.
	prize.take(walker)
	await _frames(2)
	check(prize.state == 1 and prize.carrier == walker and _heard.moved == 1, "it can be taken")
	check(walker.is_ancestor_of(item) and not item.find_child("Glow", false, false).visible, "it is on whoever took it, and no longer glows")
	check(net == null or net.visible, "in its net, if it has one")
	walker.global_position = AWAY
	await _frames(4)
	if made:
		# Nothing of it reaches into the trunk of whoever carries it, whose
		# back is some 10 cm behind the middle of it.
		var box: AABB = prize_script._bounds(item.get_node("Model"))
		var nearest: float = (walker.global_transform.affine_inverse() * item.get_node("Model").global_transform * box).position.z
		check(nearest > 0.1, "a made prize hangs clear of the back of whoever carries it (%.2f m behind the middle)" % nearest)
	check(prize.where().distance_to(AWAY) < 0.01 and item.global_position.distance_to(AWAY) < 1.6, "it goes where that one goes")
	var behind: Vector3 = walker.global_transform.affine_inverse() * item.global_position
	check(behind.z > 0.05 and behind.y > 0.3, "on his back")
	check(_heard.touched == 1, "and cannot be touched there")
	if item.get_node("Model").get_meta(&"flies", false):
		var cloth := item.find_child("Team", true, false) as MeshInstance3D
		var still: float = cloth.get_instance_shader_parameter(&"wind")
		walker.velocity = Vector3(8, 0, 0)
		await _frames(3)
		var running: float = cloth.get_instance_shader_parameter(&"wind")
		walker.velocity = Vector3.ZERO
		check(running > still + 0.1, "its cloth stands out further the faster it is carried (%.2f standing, %.2f at a run)" % [still, running])

	# Let go of.
	prize.drop()
	await _frames(3)
	var down: Array = spec.down.at
	if made:
		var lowest: float = (item.get_node("Model").global_transform * prize_script._bounds(item.get_node("Model"))).position.y
		check(absf(lowest) < 0.005, "a made prize lies on the floor, not in it (%.3f m)" % lowest)
	check(prize.state == 2 and prize.carrier == null and _heard.moved == 2, "it can be dropped")
	check(item.get_parent() == prize and absf(item.global_position.y - down[1]) < 0.03 and Vector2(item.global_position.x - AWAY.x, item.global_position.z - AWAY.z).length() < 0.05, "and lies on the floor where that one stood")
	check(net == null or not net.visible, "out of its net")
	await _wait(0.5)
	check(prize.down_for > 0.3, "it counts how long it has lain there")
	check(_heard.touched >= 2, "whoever stands over it touches it again")

	# Sent home.
	prize.send_home()
	await _frames(3)
	check(prize.state == 0 and item.global_position.distance_to(SPOT + Vector3(home[0], home[1], home[2])) < 0.01 and _heard.moved == 3, "it can be sent home")
	walker.queue_free()

	# On a figure with a rig: a puppet, as somebody else's player is.
	var puppet: CharacterBody3D = (load(PUPPET) as PackedScene).instantiate()
	puppet.id = 7
	puppet.title = "Bearer"
	current_scene.add_child(puppet)
	puppet.net_state(SPOT + Vector3(2.5, 0, 0), 0.0, 0.0, Vector3.ZERO, 0, 0)
	await _frames(3)
	prize.take(puppet)
	await _frames(3)
	var rig := puppet.get_node_or_null("Model") as Node3D
	check(rig != null and rig.is_ancestor_of(item), "a figure with a rig bears it on that")
	var on_back: Vector3 = puppet.global_transform.affine_inverse() * item.global_position
	check(on_back.z > 0.05 and on_back.z < 0.6 and absf(on_back.x) < 0.5 and on_back.y > 0.2 and on_back.y < 1.6, "behind its trunk (%.2f to its right, %.2f up, %.2f behind)" % [-on_back.x, on_back.y, on_back.z])
	check(item.global_basis.get_scale().is_equal_approx(Vector3.ONE), "at its own size")
	# A puppet that changes its weapon is a new figure.
	puppet.net_state(SPOT + Vector3(2.5, 0, 0), 0.0, 0.0, Vector3.ZERO, 0, 2)
	await _frames(4)
	var new_rig := puppet.get_node_or_null("Model") as Node3D
	item = prize.get_node_or_null("Prize") as Node3D if prize.get_node_or_null("Prize") else new_rig.find_child("Prize", true, false) as Node3D
	check(new_rig != rig and prize.state == 1 and prize.carrier == puppet and item != null and new_rig.is_ancestor_of(item), "it stays on somebody who changes weapon, and so becomes a new figure")
	# Taken out of the level without letting go.
	var last := puppet.global_position
	puppet.queue_free()
	await _frames(4)
	item = prize.get_node_or_null("Prize") as Node3D
	check(prize.state == 2 and item != null and Vector2(item.global_position.x - last.x, item.global_position.z - last.z).length() < 0.05, "it comes down where somebody stood who is taken out of the level with it")

	# On the player of this machine, who has no figure.
	var player := get_first_node_in_group("player") as CharacterBody3D
	player.global_position = SPOT + Vector3(-3, 0, 0)
	prize.take(player)
	await _frames(2)
	var on_player: Vector3 = player.global_transform.affine_inverse() * item.global_position
	check(player.is_ancestor_of(item) and on_player.z > 0.05 and on_player.y > 0.2, "the player of this machine bears it on his own back")
	prize.send_home()
	await _frames(2)
	check(prize.state == 0 and item.get_parent() == prize, "and it goes home from there")
	prize.queue_free()
	await _frames(2)


## Makes prizes as they are made on a machine, and checks that they are
## there when they should be and left out when they should be: one as it
## should be, one whose model is missing, one with the name of a prize of the
## table, and one that comes while the game runs.
func _made_ones(prize_script: GDScript) -> void:
	var home := ProjectSettings.globalize_path("user://")
	if not home.contains("prize_home"):
		check(false, "the test has a home of its own, so as not to make prizes in that of whoever plays here (%s)" % home)
		return
	_clear("user://prizes")
	check(_make(MADE, "Test crate"), "a prize can be made as a model in a folder")
	_make("flag", "Not the flag")
	DirAccess.make_dir_recursive_absolute("user://prizes/test_missing")
	var broken := FileAccess.open("user://prizes/test_missing/prize.json", FileAccess.WRITE)
	broken.store_string(JSON.stringify({"name": "Nothing", "model": "model.glb"}))
	broken.close()
	prize_script.reread()
	var kinds: PackedStringArray = prize_script.kinds()
	check(kinds.has(MADE) and prize_script.made(MADE) and not prize_script.made("flag") and kinds.find(MADE) > kinds.find("banana"), "a prize made here is there next to those of the table, after them")
	check(prize_script.spec("flag").get("name") == "Flag" and not kinds.has("test_missing"), "one with the name of a prize of the table is left out, and one without its model")
	_make("test_late", "Late")
	check(not prize_script.kinds().has("test_late"), "what is made later is not seen until somebody looks again")
	prize_script.reread()
	check(prize_script.kinds().has("test_late"), "and then it is")
	_clear("user://prizes/test_late")
	_clear("user://prizes/test_missing")
	_clear("user://prizes/flag")
	prize_script.reread()
	await _frames(1)


## A made prize: a crate with a band, as a .glb in a folder of its own with a
## prize.json that says no more than its name and its model.
func _make(prize_name: String, title: String) -> bool:
	var folder := "user://prizes/" + prize_name
	DirAccess.make_dir_recursive_absolute(folder)
	var root := Node3D.new()
	root.name = prize_name.to_pascal_case()
	var parts := {"Body": [MADE_SIZE, Color(0.85, 0.75, 0.2)], "Team": [Vector3(MADE_SIZE.x + 0.02, 0.06, MADE_SIZE.z + 0.02), Color.WHITE]}
	for part_name: String in parts:
		var box := BoxMesh.new()
		box.size = parts[part_name][0]
		var paint := StandardMaterial3D.new()
		paint.albedo_color = parts[part_name][1]
		box.material = paint
		var mesh := MeshInstance3D.new()
		mesh.name = part_name
		mesh.mesh = box
		# Standing on its origin.
		mesh.position.y = MADE_SIZE.y * 0.5
		root.add_child(mesh)
		mesh.owner = root
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(root, state)
	if error == OK:
		error = document.write_to_filesystem(state, folder + "/model.glb")
	root.free()
	var file := FileAccess.open(folder + "/prize.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"name": title, "model": "model.glb"}))
	file.close()
	return error == OK


## Takes away a folder of the test's own home and what is in it.
func _clear(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for inner in DirAccess.get_directories_at(folder):
		_clear(folder + "/" + inner)
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder + "/" + file)
	DirAccess.remove_absolute(folder)


## Somebody to walk about with: a body on the layer of the players.
func _walker(at: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)
	current_scene.add_child(body)
	body.global_position = at
	return body


func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("  ok      " if ok else "  FAILED  ", title)


func _wait(seconds: float) -> void:
	await create_timer(seconds, false, true).timeout


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
