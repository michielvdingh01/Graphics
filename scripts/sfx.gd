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
## reverb of the space the player stands in. A sound that tells the player
## something instead of coming from the world would play dry on UI; there is
## none at the moment. The buses themselves are in
## res://default_bus_layout.tres.
##
## Music is a piece in assets/music/, played from disk as it goes, on the
## Music bus: see music().

const SAMPLES := "res://assets/audio/"
const RATE := 22050
const WORLD := &"World"
const UI := &"UI"
const MUSIC := &"Music"
const PIECES := "res://assets/music/"
## The kinds of file a piece may be. Both are played as a stream, not held
## unpacked in memory the way the takes of a shot are.
const PIECE_KINDS: Array[String] = [".ogg", ".mp3"]
## Seconds a piece takes to make way for the next.
const CHANGE_TIME := 0.7
## Sounds that tell the player something instead of coming from the world.
## They play dry and always at the same pitch. A hit had three of them, which
## went: what a shot does to an enemy is heard where it lands.
const UI_SOUNDS: Array[StringName] = []

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
# and, for a voice: seconds it takes to swell, and the rate in Hz of a growl in it.
const SOUNDS := {
	&"enemy_alert": [0.12, 0.0, 1.0, 1.0, 0.5, 1200.0, -3.0, 15.0, 1.0],
	&"dry_fire": [0.04, 0.3, 120.0, 1.0, 0.3, 1800.0, 0.0, 150.0, 1.0],
	&"reload": [0.12, 0.6, 40.0, 0.8, 0.4, 500.0, 30.0, 50.0, 1.5],
	&"reload_end": [0.08, 0.6, 60.0, 1.0, 0.5, 900.0, 10.0, 70.0, 1.5],
	&"switch": [0.07, 0.5, 60.0, 0.6, 0.3, 700.0, 20.0, 60.0, 1.2],
	&"slide": [0.60, 0.5, 5.0, 0.25, 0.0, 100.0, 0.0, 1.0, 1.2],
	&"human_step": [0.09, 0.5, 50.0, 0.12, 0.35, 85.0, 22.0, 55.0, 1.4],
	&"human_alert": [0.26, 0.2, 10.0, 0.6, 0.9, 330.0, 2.2, 6.0, 3.5, 0.02],
	&"human_hurt": [0.18, 0.3, 14.0, 0.4, 0.9, 210.0, 4.0, 10.0, 3.0, 0.01],
	&"human_death": [0.7, 0.3, 5.0, 0.35, 0.9, 230.0, 2.6, 3.6, 3.0, 0.03],
	&"zombie_alert": [0.6, 0.45, 3.5, 0.25, 0.8, 110.0, 0.6, 3.0, 4.0, 0.12, 38.0],
	&"zombie_hurt": [0.3, 0.45, 8.0, 0.25, 0.8, 130.0, 2.0, 7.0, 4.0, 0.02, 45.0],
	&"zombie_death": [0.9, 0.45, 3.0, 0.2, 0.8, 120.0, 1.6, 2.6, 4.0, 0.05, 32.0],
	&"swing": [0.2, 0.9, 10.0, 0.3, 0.0, 100.0, 0.0, 1.0, 1.2, 0.06],
	&"body_fall": [0.25, 0.8, 18.0, 0.07, 0.9, 55.0, 8.0, 16.0, 2.2],
	# What a robot says of what it is about to do: the whine before a burst,
	# for each kind its own, the call of one that goes round the player and
	# the alarm of one that runs from something.
	&"enemy_charge": [0.4, 0.0, 1.0, 1.0, 0.45, 520.0, -2.4, 2.5, 1.0, 0.25],
	&"heavy_charge": [0.75, 0.25, 2.0, 0.2, 0.5, 110.0, -1.5, 1.5, 1.6, 0.4],
	&"rusher_charge": [0.26, 0.3, 8.0, 1.0, 0.5, 1500.0, -1.8, 6.0, 1.8, 0.05],
	&"enemy_flank": [0.3, 0.0, 1.0, 1.0, 0.5, 760.0, 3.2, 7.0, 1.0, 0.01, 11.0],
	&"enemy_alarm": [0.42, 0.0, 1.0, 1.0, 0.55, 1900.0, 0.0, 3.0, 1.0, 0.01, 14.0],
}

var _streams := {}
var _last := {}
var _reverb: AudioEffectReverb
var _space := &"hall"
var _level := ""
var _unknown := {}
var _fade: Tween
var _music: AudioStreamPlayer
var _piece := &""
var _music_fade: Tween
## True while the piece that plays is dying away to make room for _piece.
var _changing := false


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


## Plays the piece of music of that name round and round: assets/music/ holds
## it as <piece>.ogg or <piece>.mp3. If it is the one that is playing, it
## carries on where it is. A piece there is no file for is silence, so the
## game can ask for one that has yet to be made.
## `db` is how loud it plays: music behind a fight wants to be well under it.
## Another piece that is playing dies away first.
func music(piece: StringName, seconds := 0.5, db := 0.0) -> void:
	var busy := _music != null and _music.playing
	if busy and piece == _piece:
		# Asked for again while the piece before it is still dying away: it
		# is on its way, and a fade started now would call that off.
		if not _changing:
			_swell(db, seconds)
		return
	for kind in PIECE_KINDS:
		var path := PIECES + String(piece) + kind
		if not ResourceLoader.exists(path):
			continue
		if busy:
			_piece = piece
			_swell(-60.0, CHANGE_TIME)
			_changing = true
			_music_fade.tween_callback(_start_music.bind(piece, load(path), seconds, db))
		else:
			_start_music(piece, load(path), seconds, db)
		return
	stop_music(seconds)


## Lets the music die away over that many seconds.
func stop_music(seconds := 1.5) -> void:
	_piece = &""
	_changing = false
	if _music == null or not _music.playing:
		return
	_swell(-60.0, seconds)
	_music_fade.tween_callback(_music.stop)


## The piece that is playing, or an empty name.
func music_playing() -> StringName:
	return _piece


func _start_music(piece: StringName, stream: AudioStream, seconds := 0.0, db := 0.0) -> void:
	if _music == null:
		_music = AudioStreamPlayer.new()
		_music.bus = MUSIC
		# The title screen and the pause menu stop the tree, not the music.
		_music.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_music)
	if stream.get(&"loop") != null:
		stream.set(&"loop", true)
	_piece = piece
	_changing = false
	_music.stream = stream
	_music.volume_db = -60.0 if seconds > 0.0 else db
	_music.play()
	_swell(db, seconds)


func _swell(to_db: float, seconds: float) -> void:
	if _music_fade:
		_music_fade.kill()
	_music_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_fade.tween_property(_music, ^"volume_db", to_db, maxf(seconds, 0.01))


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
		if p.size() > 9:
			sample *= minf(1.0, t / p[9])
		if p.size() > 10:
			sample *= 0.6 + 0.4 * sin(TAU * p[10] * t)
		# Soft clip for punch, and fade the last 5 ms so the tail never clicks.
		sample = tanh(sample * p[8]) * minf(1.0, (length - t) * 200.0)
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 29000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
