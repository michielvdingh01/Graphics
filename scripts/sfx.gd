extends Node
## Every sound in the game, by name: gameplay code never refers to a file.
##
## A folder in assets/audio/ named after a sound holds its recorded takes, cut
## from the manifest by tools/build_sounds.py; each time it plays, one of them
## is picked. A sound without a folder is synthesised at startup from SOUNDS as
## a placeholder, so recording it and adding it to the manifest replaces it
## without touching any caller.
##
## Where a sound goes is decided here as well. Everything in the game world,
## the player's own weapon included, plays on the World bus, which carries the
## reverb of the space the player stands in; the hit-marker tones play dry on
## UI. The buses themselves are in res://default_bus_layout.tres.

const SAMPLES := "res://assets/audio/"
const RATE := 22050
const WORLD := &"World"
const UI := &"UI"
## Sounds that tell the player something instead of coming from the world.
## They play dry and always at the same pitch.
const UI_SOUNDS: Array[StringName] = [&"hit", &"headshot", &"kill"]

## The reverb on World per kind of space: room_size, damping, hipass,
## predelay_msec, predelay_feedback, wet. "hall" is what the bus layout holds.
## room_size sets the decay (0.4: 1.0 s, 0.8: 2.7 s below 1 kHz); damping is
## how much treble the walls give back, so higher is brighter; predelay only
## does something with feedback, as an echo that repeats at that interval.
const SPACES := {
	&"hall": [0.80, 0.50, 0.02, 20.0, 0.00, 0.18],
	&"room": [0.40, 0.65, 0.02, 20.0, 0.00, 0.28],
	&"yard": [0.15, 0.30, 0.02, 175.0, 0.35, 0.22],
}
## Per level: the space it is, and the boxes inside it that are another one.
## The annex of the factory and the gatehouse of the depot are rooms.
const LEVELS := {
	"res://scenes/factory.tscn": [&"hall", [AABB(Vector3(20.25, -0.5, -12.2), Vector3(10.45, 4.4, 14.4)), &"room"]],
	"res://scenes/depot.tscn": [&"yard", [AABB(Vector3(22.9, -0.5, 13.9), Vector3(7.1, 4.0, 6.1)), &"room"]],
}

# name: [length s, noise gain, noise decay, noise lowpass 0..1,
#        tone gain, tone Hz, tone pitch drop, tone decay, drive]
const SOUNDS := {
	&"enemy_alert": [0.12, 0.0, 1.0, 1.0, 0.5, 1200.0, -3.0, 15.0, 1.0],
	&"dry_fire": [0.04, 0.3, 120.0, 1.0, 0.3, 1800.0, 0.0, 150.0, 1.0],
	&"reload": [0.12, 0.6, 40.0, 0.8, 0.4, 500.0, 30.0, 50.0, 1.5],
	&"reload_end": [0.08, 0.6, 60.0, 1.0, 0.5, 900.0, 10.0, 70.0, 1.5],
	&"switch": [0.07, 0.5, 60.0, 0.6, 0.3, 700.0, 20.0, 60.0, 1.2],
	&"hit": [0.05, 0.1, 200.0, 1.0, 0.8, 1400.0, 0.0, 60.0, 1.0],
	&"headshot": [0.07, 0.1, 200.0, 1.0, 0.8, 2100.0, 0.0, 45.0, 1.0],
	&"kill": [0.18, 0.0, 1.0, 1.0, 0.7, 880.0, -4.0, 14.0, 1.0],
	&"slide": [0.60, 0.5, 5.0, 0.25, 0.0, 100.0, 0.0, 1.0, 1.2],
	&"casing": [0.07, 0.12, 90.0, 1.0, 0.45, 3400.0, 3.0, 55.0, 1.0],
	&"pin": [0.05, 0.3, 90.0, 1.0, 0.4, 2400.0, 0.0, 90.0, 1.0],
	&"throw": [0.22, 0.5, 10.0, 0.07, 0.0, 100.0, 0.0, 1.0, 1.5],
}

var _streams := {}
var _last := {}
var _reverb: AudioEffectReverb
var _space := &"hall"
var _level := ""
var _unknown := {}
var _fade: Tween


func _ready() -> void:
	for folder in ResourceLoader.list_directory(SAMPLES):
		if not folder.ends_with("/"):
			continue
		var takes: Array[AudioStream] = []
		for file in ResourceLoader.list_directory(SAMPLES + folder):
			takes.append(load(SAMPLES + folder + file))
		if not takes.is_empty():
			_streams[StringName(folder.trim_suffix("/"))] = takes
	for sound: StringName in SOUNDS:
		if not _streams.has(sound):
			_streams[sound] = [_synthesise(SOUNDS[sound])]

	# A player whose bus does not exist plays on Master without a word, so say
	# it once here if the layout is missing.
	var world := AudioServer.get_bus_index(WORLD)
	if world < 0:
		push_warning("No audio bus named World: default_bus_layout.tres is missing, every sound plays dry on Master.")
		return
	for index in AudioServer.get_bus_effect_count(world):
		if AudioServer.get_bus_effect(world, index) is AudioEffectReverb:
			_reverb = AudioServer.get_bus_effect(world, index)
			break


func _physics_process(_delta: float) -> void:
	var scene := get_tree().current_scene
	var camera := get_viewport().get_camera_3d()
	if scene == null or camera == null:
		return
	var level: Array = LEVELS.get(scene.scene_file_path, [&"hall"])
	var space: StringName = level[0]
	for i in range(1, level.size()):
		if (level[i][0] as AABB).has_point(camera.global_position):
			space = level[i][1]
	# A level that has just loaded starts in its own space at once: its first
	# shot should not ring in the one before.
	var loaded := scene.scene_file_path != _level
	_level = scene.scene_file_path
	set_space(space, 0.0 if loaded else 0.5)


func has(sound: StringName) -> bool:
	return _streams.has(sound)


func play(sound: StringName, volume_db := 0.0) -> void:
	var player := AudioStreamPlayer.new()
	player.volume_db = volume_db
	_start(player, sound)


func play_at(sound: StringName, position: Vector3, volume_db := 0.0) -> void:
	var player := AudioStreamPlayer3D.new()
	player.volume_db = volume_db
	player.unit_size = 8.0
	player.max_distance = 80.0
	# By default a 3D player takes the top off a sound as it gets further away
	# or quieter: 21 to 29 dB above 5 kHz at 16 m, a robot across the hall.
	player.attenuation_filter_db = -6.0
	# It also caps how loud a sound close by can get, at 3 dB: an explosion
	# asks for more.
	player.max_db = maxf(player.max_db, volume_db)
	player.position = position
	_start(player, sound)


## Changes the reverb on World to that of another kind of space, over `seconds`.
func set_space(space: StringName, seconds := 0.5) -> void:
	if space == _space or _reverb == null or not SPACES.has(space):
		return
	_space = space
	var to: Array = SPACES[space]
	if _fade:
		_fade.kill()
	if seconds <= 0.0:
		_reverb.room_size = to[0]
		_reverb.damping = to[1]
		_reverb.hipass = to[2]
		_reverb.predelay_msec = to[3]
		_reverb.predelay_feedback = to[4]
		_reverb.wet = to[5]
		return
	# The echo's interval cannot slide without bending the pitch of what is in
	# it, so it jumps: at once when there is no echo to hear, else at the end.
	var jump_first := _reverb.predelay_feedback == 0.0
	if jump_first:
		_reverb.predelay_msec = to[3]
	_fade = create_tween().set_parallel()
	_fade.tween_property(_reverb, ^"room_size", to[0], seconds)
	_fade.tween_property(_reverb, ^"damping", to[1], seconds)
	_fade.tween_property(_reverb, ^"hipass", to[2], seconds)
	_fade.tween_property(_reverb, ^"wet", to[5], seconds)
	if jump_first:
		_fade.tween_property(_reverb, ^"predelay_feedback", to[4], seconds)
	else:
		_fade.tween_property(_reverb, ^"predelay_feedback", 0.0, seconds)
		_fade.chain().tween_callback(func() -> void:
			_reverb.predelay_msec = to[3]
			_reverb.predelay_feedback = to[4])


func _start(player: Node, sound: StringName) -> void:
	if not _streams.has(sound):
		if not _unknown.has(sound):
			_unknown[sound] = true
			push_warning("Sfx has no sound named %s" % sound)
		player.free()
		return
	var takes: Array = _streams[sound]
	var take := 0
	if takes.size() > 1:
		# Any take but the one before: the same one twice in a row is what
		# gives a recording away.
		take = (_last.get(sound, 0) + 1 + randi() % (takes.size() - 1)) % takes.size()
		_last[sound] = take
	var ui := sound in UI_SOUNDS
	player.stream = takes[take]
	player.bus = UI if ui else WORLD
	# A semitone either way suits a footstep; a weapon would sound like a
	# different one with every round.
	var spread := 0.0 if ui else (0.03 if String(sound).ends_with("_shot") else 0.06)
	player.pitch_scale = randf_range(1.0 - spread, 1.0 + spread)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _synthesise(p: Array) -> AudioStreamWAV:
	var length: float = p[0]
	var count := int(length * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var lowpassed := 0.0
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		lowpassed += p[3] * (randf_range(-1.0, 1.0) - lowpassed)
		phase += TAU * p[5] * exp(-t * p[6]) / RATE
		var sample: float = p[1] * lowpassed * exp(-t * p[2]) + p[4] * sin(phase) * exp(-t * p[7])
		# Soft clip for punch, and fade the last 5 ms so the tail never clicks.
		sample = tanh(sample * p[8]) * minf(1.0, (length - t) * 200.0)
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 29000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
