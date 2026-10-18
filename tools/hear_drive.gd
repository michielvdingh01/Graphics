extends SceneTree
## Records what the driver of a vehicle hears on a ride, the way the game
## plays it: the game's own vehicle (scripts/vehicle.gd) on a floor, driven
## with the keys, heard from its camera through the game's buses, and what
## arrives at the end of Master written to a WAV. tools/hear.py runs it:
##
##   tools/hear.py drive jeep            get in, start, pull away through the
##                                       gears, brake hard, idle, get out
##   tools/hear.py drive tank crash      flat out into a wall
##   tools/hear.py drive truck wreck     the engine hit, alight, and going up
##   tools/hear.py drive tank gun        the turret turning and the gun firing
##   tools/hear.py drive jeep b          the same with variant b of whatever
##                                       sound has one (<sound>_b)
##
##   Godot --headless --path . --script res://tools/hear_drive.gd -- <kind> <ride> <variant> out.wav

const PLAYER := "res://scenes/player.tscn"
const VEHICLE := "res://scripts/vehicle.gd"
const WATCHDOG := 120.0
## The sounds a vehicle names, which a variant can swap.
const SOUNDS: Array[StringName] = [&"start_sound", &"stop_sound", &"shift_sound", &"brake_sound", &"door_sound", &"crash_sound",
	&"damaged_sound", &"explode_sound", &"roll_sound", &"turret_sound", &"cannon_sound", &"load_sound"]

var _capture: AudioEffectCapture
var _frames := PackedVector2Array()
var _player: CharacterBody3D
var _vehicle: RigidBody3D


func _initialize() -> void:
	create_timer(WATCHDOG, true, false, true).timeout.connect(func() -> void:
		print("hear_drive: timed out")
		quit(2))
	_run.call_deferred()


func _run() -> void:
	paused = false
	var args := Array(OS.get_cmdline_user_args()).filter(func(a: String) -> bool: return not a.begins_with("--"))
	if args.size() < 4:
		print("usage: hear_drive.gd -- <kind> <ride> <variant> out.wav")
		quit(2)
		return
	var kind: String = args[0]
	var ride: String = args[1]
	var variant: String = args[2]
	var out: String = args[3]
	await process_frame
	_stage(kind, variant, 90.0 if ride == "crash" else 380.0)
	await _seconds(0.6)
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 2.0
	AudioServer.add_bus_effect(0, _capture)
	_capture.clear_buffer()
	_vehicle.shifted.connect(func(to: int) -> void: _mark("shift to %d at %.1f km/h" % [to, _vehicle.speed * 3.6]))
	match ride:
		"drive":
			await _drive()
		"crash":
			await _crash()
		"wreck":
			await _wreck()
		"gun":
			await _gun()
		_:
			print("hear_drive: no ride called ", ride)
			quit(2)
			return
	await _seconds(1.5)
	_take()
	_write(out)
	print("hear_drive: %.1f s of %s %s to %s; %d frames lost" % [_frames.size() / AudioServer.get_mix_rate(), kind, ride, out, _capture.get_discarded_frames()])
	quit(0)


## A floor with a wall at its end, the player, and the vehicle at the start.
func _stage(kind: String, variant: String, wall_at: float) -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var ground := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(400, 1, 800)
	floor_shape.shape = slab
	floor_shape.position = Vector3(0, -0.5, 380)
	floor_shape.set_meta(&"surface", "sand")
	ground.add_child(floor_shape)
	var wall := CollisionShape3D.new()
	var block := BoxShape3D.new()
	block.size = Vector3(40, 4, 2)
	wall.shape = block
	wall.position = Vector3(0, 2, wall_at)
	ground.add_child(wall)
	world.add_child(ground)
	_player = (load(PLAYER) as PackedScene).instantiate()
	world.add_child(_player)
	_player.force_control = true
	_player.global_position = Vector3(-2.6, 0, 0)
	_vehicle = RigidBody3D.new()
	_vehicle.set_script(load(VEHICLE))
	_vehicle.set("kind", kind)
	_vehicle.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.05, 0))
	# Variant b of whatever has one, on a copy of the vehicle's numbers. The
	# autoloads have no names in a script that runs the tree.
	var sfx := root.get_node("Sfx")
	var data: VehicleData = (load("res://vehicles/%s.tres" % kind) as VehicleData).duplicate()
	if variant != "a":
		for field in SOUNDS:
			var sound: StringName = data.get(field)
			if sound != &"" and sfx.has(StringName("%s_%s" % [sound, variant])):
				data.set(field, StringName("%s_%s" % [sound, variant]))
		var loops: Array[StringName] = []
		for loop in data.engine_loops:
			loops.append(StringName("%s_%s" % [loop, variant]) if sfx.has(StringName("%s_%s" % [loop, variant])) else loop)
		data.engine_loops = loops
	_vehicle.data = data
	world.add_child(_vehicle)


func _seconds(time: float) -> void:
	var until := Time.get_ticks_msec() + int(time * 1000.0)
	while Time.get_ticks_msec() < until:
		await physics_frame
		_take()


## Says what happens, and at which second of the recording.
func _mark(what: String) -> void:
	_take()
	print("  %5.1f s  %s" % [_frames.size() / AudioServer.get_mix_rate(), what])


func _take() -> void:
	if _capture:
		_frames.append_array(_capture.get_buffer(_capture.get_frames_available()))


func _press(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _get_in() -> void:
	_mark("get in")
	await _press("use")
	await _seconds(_vehicle.data.start_time + 1.5)
	_mark("idling")


## Get in, start, idle, pull away flat out through the gears, brake hard to
## a stop, idle, get out.
func _drive() -> void:
	await _get_in()
	_mark("gas")
	Input.action_press("move_forward")
	await _seconds(9.0)
	_mark("off the gas at %.0f km/h" % (_vehicle.speed * 3.6))
	Input.action_release("move_forward")
	await _seconds(0.6)
	_mark("brake")
	Input.action_press("move_back")
	while _vehicle.speed > 0.3:
		await _seconds(0.1)
	_mark("stopped")
	Input.action_release("move_back")
	await _seconds(2.0)
	_mark("get out")
	await _press("use")


func wall_at() -> float:
	return 90.0


func _crash() -> void:
	await _get_in()
	Input.action_press("move_forward")
	while _vehicle.global_position.z < wall_at() - 6.0:
		await _seconds(0.1)
	await _seconds(1.5)
	Input.action_release("move_forward")
	await _seconds(1.0)
	await _press("use")


## Hit, misfiring and smoking, alight and burning down, and going up.
func _wreck() -> void:
	await _get_in()
	var data: VehicleData = _vehicle.data
	_vehicle.take_damage(data.health * (1.0 - data.damaged) + 1.0, _vehicle.global_position, Vector3.FORWARD)
	Input.action_press("move_forward")
	await _seconds(4.0)
	Input.action_release("move_forward")
	await _seconds(2.0)
	_vehicle.take_damage(data.health * (data.damaged - data.burning) + 1.0, _vehicle.global_position, Vector3.FORWARD)
	await _seconds(3.0)
	_player.health = 1e9
	_vehicle.take_damage(1e5, _vehicle.global_position, Vector3.FORWARD)
	await _seconds(5.0)


## The turret going round, and the gun firing twice.
func _gun() -> void:
	await _get_in()
	_vehicle.view().look(Vector2(-1.5, 0.0))
	await _seconds(3.0)
	Input.action_press("fire")
	await _seconds(0.1)
	Input.action_release("fire")
	await _seconds(_vehicle.data.reload_time + 0.5)
	_vehicle.view().look(Vector2(1.0, 0.0))
	await _seconds(2.0)
	Input.action_press("fire")
	await _seconds(0.1)
	Input.action_release("fire")
	await _seconds(2.0)


func _write(path: String) -> void:
	var rate := int(AudioServer.get_mix_rate())
	var body := PackedByteArray()
	body.resize(_frames.size() * 4)
	for i in _frames.size():
		body.encode_s16(i * 4, clampi(roundi(_frames[i].x * 32767.0), -32768, 32767))
		body.encode_s16(i * 4 + 2, clampi(roundi(_frames[i].y * 32767.0), -32768, 32767))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(36 + body.size())
	file.store_buffer("WAVEfmt ".to_ascii_buffer())
	file.store_32(16)
	file.store_16(1)
	file.store_16(2)
	file.store_32(rate)
	file.store_32(rate * 4)
	file.store_16(4)
	file.store_16(16)
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(body.size())
	file.store_buffer(body)
	file.close()
