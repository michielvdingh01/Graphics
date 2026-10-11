extends SceneTree
## Tries what scripts/sfx.gd reads from a level and does by itself: the reverb
## of each zone, the beds, more reverb from further off, the second layer of
## the music, the door of the exit and a shot that goes by. Headless, without
## a sound card:
##
##   tools/test_sound.sh            every check
##   tools/test_sound.sh --zones    also lists what every zone of every level sounds like
##
## The game's own autoloads are there, Sfx among them; --play keeps the title
## screen out of the way.

const LEVELS: Array[String] = ["factory", "works", "depot", "powerhouse", "wing"]
const WATCHDOG := 120.0

var _sfx: Node
var _failed := 0
var _checked := 0


## Stands in for a level that says whether there is a fight on.
class Fight:
	extends Node
	var on := false

	func fighting() -> bool:
		return on


func _initialize() -> void:
	var timer := Timer.new()
	timer.wait_time = WATCHDOG
	timer.autostart = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.timeout.connect(func() -> void:
		print("test_sound: timed out")
		quit(2))
	root.add_child(timer)
	_run.call_deferred()


func _check(what: String, passed: bool) -> void:
	_checked += 1
	if not passed:
		_failed += 1
	print("  [%s] %s" % ["ok" if passed else "FAIL", what])


func _load(level: String) -> Node:
	change_scene_to_file("res://scenes/%s.tscn" % level)
	await scene_changed
	paused = false
	await physics_frame
	await physics_frame
	return current_scene


func _room(zone: String) -> Dictionary:
	for room: Dictionary in _sfx._rooms:
		if room.name == zone:
			return room
	return {}


## A camera of our own in the middle of a zone, at head height.
func _stand_in(camera: Camera3D, zone: String) -> void:
	var box: AABB = _room(zone).boxes[0]
	camera.global_position = (current_scene.get_node(^"Level") as Node3D).to_global(Vector3(box.get_center().x, box.position.y + 2.6, box.get_center().z))


func _players(under: Node, bus: StringName) -> Array[Node]:
	return under.get_children().filter(func(node: Node) -> bool:
		return (node is AudioStreamPlayer3D or node is AudioStreamPlayer) and node.bus == bus and not node.is_queued_for_deletion())


func _run() -> void:
	_sfx = root.get_node(^"Sfx")
	var listing := "--zones" in OS.get_cmdline_user_args()
	var hall: Array = _sfx.SPACES[&"hall"]
	var room: Array = _sfx.SPACES[&"room"]

	print("The reverb of a zone")
	await _load("factory")
	_check("the factory is read as its four zones", _sfx._rooms.size() == 4 and not _room("hall").is_empty() and not _room("boiler").is_empty())
	var tuned: Array = _room("hall").tuning
	_check("its hall rings as the hall always did (room_size %.3f, wet %.3f)" % [tuned[0], tuned[5]], absf(tuned[0] - hall[0]) < 0.01 and absf(tuned[5] - hall[5]) < 0.005 and absf(tuned[1] - hall[1]) < 0.01)
	tuned = _room("annex").tuning
	_check("and its annex as the room always did (room_size %.3f, wet %.3f)" % [tuned[0], tuned[5]], absf(tuned[0] - room[0]) < 0.01 and absf(tuned[5] - room[5]) < 0.005)
	_check("the boiler house is between the two, and the passage is the smallest", _room("boiler").tuning[0] > room[0] and _room("boiler").tuning[0] < hall[0] and _room("passage").tuning[0] < room[0])
	_check("the reverb on Far is there and tuned like the one on World", _sfx._reverbs.size() == 2 and _sfx._reverbs[1].dry == 0.0 and _sfx._reverbs[0].room_size == _sfx._reverbs[1].room_size)

	var camera := Camera3D.new()
	root.add_child(camera)
	_stand_in(camera, "annex")
	var here: Dictionary = _sfx._here(current_scene, camera, false, 0.016)
	_check("standing in the annex it is the annex one hears", here.tuning == _room("annex").tuning and here.bed == &"room")
	_check("with the hall next door under it", here.beds.has(&"hall") and here.beds[&"hall"] <= _sfx.NEXT_DOOR_DB and here.beds[&"hall"] > _sfx.SILENT)
	camera.global_position += Vector3.UP * 60.0
	here = _sfx._here(current_scene, camera, false, 0.016)
	_check("and outside every zone it stays what it was", here.tuning == _room("annex").tuning)
	_stand_in(camera, "boiler")
	here = _sfx._here(current_scene, camera, false, 0.016)
	_check("the boiler house has a bed of its own", here.bed == &"boiler" and here.beds[&"boiler"] == 0.0)
	_stand_in(camera, "hall")
	here = _sfx._here(current_scene, camera, false, 0.016)
	_check("the hall has the bed of a hall", here.bed == &"hall" and here.tuning == _room("hall").tuning)

	print("A level without zones")
	await _load("depot")
	_check("the depot has no zones to read", _sfx._rooms.is_empty())
	camera.global_position = Vector3(0.0, 1.7, 0.0)
	here = _sfx._probe(camera)
	_check("out on its yard it is the open air", here.bed == &"yard" and here.tuning == _sfx.SPACES[&"yard"])
	camera.global_position = Vector3(26.4, 1.7, 17.0)
	here = _sfx._probe(camera)
	_check("and in its gatehouse a room (room_size %.2f)" % here.tuning[0], here.bed == &"room" and here.tuning[4] == 0.0 and here.tuning[0] < 0.6)

	print("Every level")
	for level in LEVELS:
		await _load(level)
		var kinds := {}
		for zone: Dictionary in _sfx._rooms:
			kinds[zone.bed] = kinds.get(zone.bed, 0) + 1
			if listing:
				var seconds: float = _sfx.COMB / -(log(0.7 + 0.28 * zone.tuning[0]) / log(10.0))
				print("    %-12s %-18s %-8s room_size %.2f (%.1f s)  wet %.2f  echo %3.0f ms" % [level, zone.name, zone.bed, zone.tuning[0], seconds, zone.tuning[5], zone.tuning[3] if zone.tuning[4] > 0.0 else 0.0])
		_check("%s: %d zones, %s" % [level, _sfx._rooms.size(), kinds], _sfx._rooms.all(func(zone: Dictionary) -> bool:
			return zone.tuning.size() == 6 and zone.tuning[0] >= 0.0 and zone.tuning[0] <= 0.95 and zone.tuning[5] > 0.1))

	print("From further off")
	_check("up to 8 m a sound adds nothing to the reverb", _sfx._far(3.0) == 0.0 and _sfx._far(8.0) == 0.0)
	_check("at 16 m it adds %.1f dB against full level, at 24 m %.1f, at 60 m %.1f" % [linear_to_db(_sfx._far(16.0)), linear_to_db(_sfx._far(24.0)), linear_to_db(_sfx._far(60.0))],
		is_equal_approx(_sfx._far(16.0), 0.5) and _sfx._far(24.0) > _sfx._far(16.0) and _sfx._far(60.0) < _sfx._far(24.0))
	await _load("factory")
	camera.make_current()
	camera.global_position = Vector3(0.0, 1.7, 0.0)
	await physics_frame
	var before := _players(_sfx, _sfx.FAR_BUS).size()
	_sfx.play_at(&"enemy_shot", camera.global_position + Vector3(4.0, 0.0, 0.0))
	_check("a shot at 4 m plays once", _players(_sfx, _sfx.FAR_BUS).size() == before)
	_sfx.play_at(&"enemy_shot", camera.global_position + Vector3(24.0, 0.0, 0.0))
	var far := _players(_sfx, _sfx.FAR_BUS)
	_check("a shot at 24 m plays a second time into the reverb", far.size() == before + 1 and far[-1].attenuation_model == AudioStreamPlayer3D.ATTENUATION_DISABLED)

	print("A shot that goes by")
	if _sfx.has(&"whiz"):
		var count := func() -> int: return _players(_sfx, _sfx.WORLD).filter(func(node: Node) -> bool: return _sfx._streams[&"whiz"].has(node.stream)).size()
		var ear := camera.global_position
		_sfx._passed = 0.0
		_sfx.passing(ear + Vector3(-20.0, 0.0, 1.0), ear + Vector3(20.0, 0.0, 1.0))
		_check("one that passes a metre off is heard", count.call() == 1)
		_sfx._passed = 0.0
		_sfx.passing(ear + Vector3(-20.0, 0.0, 0.0), ear)
		_check("one that ends at the camera is not: that was a hit", count.call() == 1)
		_sfx._passed = 0.0
		_sfx.passing(ear + Vector3(-20.0, 0.0, 6.0), ear + Vector3(20.0, 0.0, 6.0))
		_check("nor one that passes six metres off", count.call() == 1)
		_sfx._passed = 0.0
		_sfx.passing(ear + Vector3(-20.0, 0.0, 1.0), ear + Vector3(-6.0, 0.0, 1.0))
		_check("nor one that stops short of the camera", count.call() == 1)
	else:
		print("  [--] there is no sound named whiz yet")

	print("The door of the exit")
	var doors := get_nodes_in_group(_sfx.DOORS)
	if doors.is_empty() or not _sfx.has(_sfx.DOOR_SOUND):
		print("  [--] no door in this level, or no sound named %s yet" % _sfx.DOOR_SOUND)
	else:
		var door: Node3D = doors[0]
		await physics_frame
		_check("a door that stands still is silent", _players(door, _sfx.WORLD).is_empty())
		for i in 6:
			door.position.y += 0.02
			await physics_frame
		_check("one that goes up is heard, from where it is", _players(door, _sfx.WORLD).size() == 1)
		for i in 30:
			await physics_frame
		_check("and falls silent when it is up", _players(door, _sfx.WORLD).is_empty())
		door.position.y += 3.0
		await physics_frame
		await physics_frame
		_check("one that is put somewhere else makes no sound", _players(door, _sfx.WORLD).is_empty())

	print("The bed of a space")
	var beds: Array = _sfx._beds.keys()
	if _sfx.has(&"ambience_hall"):
		_stand_in(camera, "hall")
		for i in 4:
			await physics_frame
		_check("the hall's bed goes round on its own bus", _sfx._beds.has(&"hall") and _sfx._beds[&"hall"].playing and _sfx._beds[&"hall"].bus == _sfx.AMBIENCE
			and _sfx._beds[&"hall"].stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
		change_scene_to_file("res://scenes/depot.tscn")
		await scene_changed
		_check("and is gone with the level", _sfx._beds.is_empty())
	else:
		print("  [--] there is no sound named ambience_hall yet (beds: %s)" % [beds])

	print("The second layer of the music")
	var piece := AudioStreamWAV.new()
	piece.format = AudioStreamWAV.FORMAT_16_BITS
	piece.data = PackedByteArray()
	piece.data.resize(88200)
	_sfx._start_music(&"a piece of the test", piece, 0.0, -9.0)
	_check("a piece without a second layer plays alone", _sfx._music.playing and _sfx._music_over == null)
	_sfx._music_over = _sfx._music_player()
	_sfx._music_over.stream = piece
	_sfx._music_over.play()
	_sfx._set_music_db(-9.0)
	var fight := Fight.new()
	_check("a layer is not heard while nothing happens", _sfx._music_over.volume_db < -60.0)
	fight.on = true
	_sfx._follow_fight(fight, _sfx.FIGHT_RISE * 0.5)
	var half: float = _sfx._music_over.volume_db
	_sfx._follow_fight(fight, _sfx.FIGHT_RISE * 0.5)
	_check("it comes in with a fight, up to the level of the piece (%.1f dB halfway)" % half, half > -20.0 and half < -9.0 and is_equal_approx(_sfx._music_over.volume_db, -9.0))
	fight.on = false
	_sfx._follow_fight(fight, _sfx.FIGHT_FALL)
	_check("and goes when it is over", _sfx._music_over.volume_db < -60.0 and is_equal_approx(_sfx._music.volume_db, -9.0))
	_sfx.stop_music(0.05)
	await create_timer(0.3).timeout
	_check("both stop together", not _sfx._music.playing and not _sfx._music_over.playing)
	fight.free()

	# Whatever still plays when the engine quits is reported as a leak.
	for player in _players(_sfx, _sfx.MUSIC) + _players(_sfx, _sfx.WORLD) + _players(_sfx, _sfx.FAR_BUS) + _players(_sfx, _sfx.AMBIENCE):
		player.stop()
		player.stream = null
	await process_frame
	print("test_sound: %d of %d checks passed" % [_checked - _failed, _checked])
	quit(1 if _failed > 0 else 0)
