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
## reverb of the space the player stands in. What that space is, is read from
## the zones of the level, see _survey(): how long it rings follows from how
## large the zone is. A sound from further off puts more of itself into that
## reverb, over the Far bus: see _far(). A sound that tells the player
## something instead of coming from the world would play dry on UI; there is
## none at the moment. The buses themselves are in
## res://default_bus_layout.tres.
##
## What a space sounds like when nothing happens is here too: a bed per kind
## of space, a sound named ambience_<kind> that goes round on the Ambience
## bus, and now and then a sound of its own from somewhere in it, see
## _lay_beds(). So is what the level does by itself: the door of the exit
## rolling up, see _watch_doors().
##
## Music is a piece in assets/music/, or a few that take turns, played from
## disk as it goes, on the Music bus: see music(). A piece may come with a
## second layer that swells while there is a fight on.

const SAMPLES := "res://assets/audio/"
const RATE := 22050
const WORLD := &"World"
## Carries what a sound from far off adds to the reverb, and nothing else.
const FAR_BUS := &"Far"
## Carries the bed of a space, which has that space in it already.
const AMBIENCE := &"Ambience"
const UI := &"UI"
const MUSIC := &"Music"
const PIECES := "res://assets/music/"
## The kinds of file a piece may be. Both are played as a stream, not held
## unpacked in memory the way the takes of a shot are.
const PIECE_KINDS: Array[String] = [".ogg", ".mp3"]
## Seconds a piece takes to make way for the next.
const CHANGE_TIME := 0.7
## What the second layer of a piece is called: <piece>_fight next to <piece>.
## It starts with the piece, as long as the piece and in step with it, and is
## only heard while there is a fight on.
const FIGHT_LAYER := "_fight"
## Seconds the second layer takes to come in when a fight starts, and to go
## once it is over.
const FIGHT_RISE := 1.2
const FIGHT_FALL := 5.0
## Sounds that tell the player something instead of coming from the world.
## They play dry and always at the same pitch. A hit had three of them, which
## went: what a shot does to an enemy is heard where it lands.
const UI_SOUNDS: Array[StringName] = []

## The reverb on World per kind of space: room_size, damping, hipass,
## predelay_msec, predelay_feedback, wet. "hall" is what the bus layout holds.
## room_size sets the decay (0.4: 1.0 s, 0.8: 2.6 s below 1 kHz); damping is
## how much treble the walls give back, so higher is brighter; predelay only
## does something with feedback, as an echo that repeats at that interval.
## A zone is tuned between "room" and "hall" by its size, see _enclosed();
## these three are also what a level without zones is one of.
const SPACES := {
	&"hall": [0.80, 0.50, 0.02, 20.0, 0.00, 0.18],
	&"room": [0.40, 0.65, 0.02, 20.0, 0.00, 0.28],
	&"yard": [0.15, 0.30, 0.02, 175.0, 0.35, 0.22],
}
## The boxes of a zone reach a metre under its floor and half a metre over
## its ceiling, see room() in tools/kit/rooms.gd.
const BOX_SLACK := 1.5
## How long an enclosed space rings below 1 kHz, by its volume over its
## surface in metres: DECAY * pow(metres, DECAY_POWER) seconds. Fitted to the
## two spaces that were tuned by measurement and by ear, the hall of the
## factory (3.3 m, 2.6 s) and its annex (1.1 m, 1.0 s).
const DECAY := 0.908
const DECAY_POWER := 0.889
## What room_size is to that: the combs of the reverb feed back
## 0.7 + 0.28 * room_size of what they hold, and at 0.812 that takes a second
## to fall by 60 dB.
const COMB := 0.0904
## A space this high is a hall, if its zone does not say what it is.
const TALL := 6.0
## How far a level without zones is felt out around the camera, and how often.
const PROBE_REACH := 40.0
const PROBE_EVERY := 0.25
## The layer the level itself is on.
const SOLID := 1

## Up to this distance a sound is as it always was: its reverb falls with it.
## It is the unit_size of a placed sound.
const NEAR := 8.0
## Past it only the sound itself goes on falling. The room it is in answers
## no less for it being further off, so the reverb stays as loud as it is at
## NEAR, up to this distance: at 16 m the two are level and at 20 m it is
## mostly the room one hears. From here on the reverb falls off as well: it
## is another building by then.
const FAR := 24.0

## A bed is a sound named ambience_<kind>, and what happens in that kind of
## space now and then is ambience_<kind>_spot. The kind is what a zone is as
## a space (hall, room or yard), unless one of these words is in its name.
const BED := "ambience_"
const SPOT := "_spot"
const BEDS := {"boiler": &"boiler", "turbine": &"turbine"}
## How loud the bed of a space in sight is on its doorstep, against standing
## in it, and how many dB it loses with every metre from there.
const NEXT_DOOR_DB := -8.0
const BED_FALLOFF := 1.2
## How fast a bed comes and goes, in dB a second.
const BED_RATE := 30.0
const SILENT := -60.0
## Seconds between two sounds from somewhere in the space, how far off they
## are and how loud.
const SPOT_EVERY := Vector2(6.0, 16.0)
const SPOT_REACH := Vector2(9.0, 22.0)
const SPOT_DB := -8.0

## The group of what goes up to open the way out, see roller_door() in
## tools/level_builder.gd, and what one of them sounds like on its way.
const DOORS := &"exit_door"
const DOOR_SOUND := &"roller_door"
## Metres a door has to move in a physics frame to count as moving, and
## seconds over which its sound stops once it does not.
const DOOR_MOVES := 0.0002
const DOOR_STOP := 0.12

## A shot that passes the camera within this many metres is heard passing.
const PASS_REACH := 3.0
## How far it has to go on past the camera: one that ends there was a hit.
const PASS_BEYOND := 1.5
## Seconds in which no second one is heard: a burst is not a swarm.
const PASS_GAP := 0.07

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
	&"zombie_alert": [0.6, 0.45, 3.5, 0.25, 0.8, 110.0, 0.6, 3.0, 4.0, 0.12, 38.0],
	&"zombie_hurt": [0.3, 0.45, 8.0, 0.25, 0.8, 130.0, 2.0, 7.0, 4.0, 0.02, 45.0],
	&"zombie_death": [0.9, 0.45, 3.0, 0.2, 0.8, 120.0, 1.6, 2.6, 4.0, 0.05, 32.0],
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
## The reverb on World and the one on Far, which are always tuned alike.
var _reverbs: Array[AudioEffectReverb] = []
## What they are tuned to, a row as in SPACES.
var _tuning: Array = SPACES[&"hall"]
var _unknown := {}
var _fade: Tween
var _music: AudioStreamPlayer
var _piece := &""
## The pieces that take turns, as music() was given them last, each with its
## stream: _piece is one of them.
var _turns := {}
var _music_fade: Tween
## True while the piece that plays is dying away to make room for _piece.
var _changing := false
## The second layer of the piece that plays, if it has one, how loud the
## piece is and how far the layer is in: 0 is not at all, 1 as loud as it.
var _music_over: AudioStreamPlayer
var _music_db := 0.0
var _heat := 0.0

## The level that was looked at last, and what its zones sound like:
## {name, boxes, tuning, bed, sees}, with the boxes as the level has them.
var _scene := 0
var _rooms: Array[Dictionary] = []
## The zone the camera is in, or was in last.
var _room := -1
## A level without zones is felt out instead: what was found last, and when.
var _probed := {}
var _probe_in := 0.0
## The players of the beds, by kind, and the seconds to the next spot.
var _beds := {}
## The bed of the open air in the level that is loaded, where it is not cut
## into zones: that of a yard, unless the level says otherwise.
var _open_bed := &"yard"
var _spot_in := 0.0
## Doors that are on their way: instance id -> {at, player, still}.
var _doors := {}
var _passed := 0.0


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
	get_tree().scene_changed.connect(_on_scene_changed)

	# A player whose bus does not exist plays on Master without a word, so say
	# it once here if the layout is missing.
	if AudioServer.get_bus_index(WORLD) < 0:
		push_warning("No audio bus named World: default_bus_layout.tres is missing, every sound plays dry on Master.")
		return
	for bus: StringName in [WORLD, FAR_BUS]:
		var index := AudioServer.get_bus_index(bus)
		for effect in AudioServer.get_bus_effect_count(index) if index >= 0 else 0:
			if AudioServer.get_bus_effect(index, effect) is AudioEffectReverb:
				_reverbs.append(AudioServer.get_bus_effect(index, effect))
				break


func _physics_process(delta: float) -> void:
	var scene := get_tree().current_scene
	var camera := get_viewport().get_camera_3d()
	if scene == null or camera == null:
		return
	var loaded := scene.get_instance_id() != _scene
	if loaded:
		_scene = scene.get_instance_id()
		_survey(scene)
		_spot_in = randf_range(SPOT_EVERY.x, SPOT_EVERY.y)
	var here := _here(scene, camera, loaded, delta)
	# A level that has just loaded starts in its own space at once: its first
	# shot should not ring in the one before.
	_tune(here.tuning, 0.0 if loaded else 0.5)
	_lay_beds(here, camera, loaded, delta)
	_watch_doors(delta)
	_follow_fight(scene, delta)


## A sound that still rings when a level is left belongs to that level. The
## title screen would stop it in mid-air, to carry on at the start of the
## next game.
func _on_scene_changed() -> void:
	for child in get_children():
		if child != _music and child != _music_over and (child is AudioStreamPlayer or child is AudioStreamPlayer3D):
			child.queue_free()
	_beds.clear()
	_doors.clear()


## Reads from the zones of a level what each of them sounds like. A zone is
## a node under Level with its boxes as the meta "bounds", see zone() in
## tools/level_builder.gd; one that was laid out as a room also says what
## kind of space it is, see room() in tools/kit/rooms.gd.
func _survey(scene: Node) -> void:
	_rooms.clear()
	_room = -1
	_probed = {}
	_open_bed = &"yard"
	var level := scene.get_node_or_null(^"Level")
	if level == null:
		return
	# A level that is not a yard between sheds says what its open air sounds
	# like: see open_air() in tools/kit/land.gd. By night (the environment of
	# the scene says so) it is the bed of that kind by night, if there is one.
	_open_bed = level.get_meta(&"open_air", &"yard")
	var world := scene.get_viewport().find_world_3d().environment if scene.is_inside_tree() else null
	if world and world.get_meta(&"night", false) and _streams.has(StringName(BED + String(_open_bed) + "_night")):
		_open_bed = StringName(String(_open_bed) + "_night")
	for zone in level.get_children():
		if not zone.has_meta(&"bounds"):
			continue
		var boxes: Array[AABB] = []
		boxes.assign(zone.get_meta(&"bounds"))
		var volume := 0.0
		var surface := 0.0
		var ground := 0.0
		var height := 0.0
		for box in boxes:
			var high := maxf(box.size.y - BOX_SLACK, 2.0)
			volume += box.size.x * box.size.z * high
			surface += 2.0 * (box.size.x * box.size.z + (box.size.x + box.size.z) * high)
			ground += box.size.x * box.size.z
			height = maxf(height, high)
		var zone_name := String(zone.get_meta(&"zone", zone.name))
		var space: StringName = zone.get_meta(&"space", &"hall" if height >= TALL else &"room")
		var bed := space
		for word: String in BEDS:
			if zone_name.contains(word):
				bed = BEDS[word]
		_rooms.append({
			"name": zone_name,
			"boxes": boxes,
			"tuning": _open_air(sqrt(ground)) if space == &"yard" else _enclosed(volume / surface),
			"bed": bed,
			"sees": zone.get_meta(&"sees", PackedStringArray()),
		})


## The reverb of a space with walls and a roof, as a row of SPACES. `metres`
## is its volume over its surface: the larger that is, the longer a sound is
## on its way between two walls and the longer the space rings.
func _enclosed(metres: float) -> Array:
	var seconds := DECAY * pow(metres, DECAY_POWER)
	var room: Array = SPACES[&"room"]
	var hall: Array = SPACES[&"hall"]
	var size := clampf((pow(10.0, -COMB / seconds) - 0.7) / 0.28, 0.0, 0.95)
	# How bright and how loud the reverb is, was set for a room and for a
	# hall: anything else is between the two by how long it rings.
	var between := clampf(inverse_lerp(room[0], hall[0], size), 0.0, 1.0)
	return [size, lerpf(room[1], hall[1], between), hall[2], hall[3], 0.0, lerpf(room[5], hall[5], between)]


## The reverb of a space under the open sky that is `across` metres wide.
func _open_air(across: float) -> Array:
	var yard: Array = SPACES[&"yard"].duplicate()
	# All there is out there is the echo off the far side: there and back at
	# the speed of sound.
	yard[3] = clampf(2000.0 * across / 343.0, 90.0, 260.0)
	return yard


## What it sounds like where the camera is: {tuning, bed, beds}. `tuning` is
## a row as in SPACES, `bed` the kind of bed of the space itself and `beds`
## every bed that is heard there with how loud: its own at 0 dB, and under it
## those of the spaces that are in sight, louder the nearer they are.
func _here(scene: Node, camera: Camera3D, loaded: bool, delta: float) -> Dictionary:
	if _rooms.is_empty():
		_probe_in -= delta
		if loaded or _probe_in <= 0.0 or _probed.is_empty():
			_probe_in = PROBE_EVERY
			_probed = _probe(camera)
		return _probed
	var at := (scene.get_node(^"Level") as Node3D).to_local(camera.global_position)
	var nearest := -1
	var least := INF
	for i in _rooms.size():
		var away := _away(_rooms[i].boxes, at)
		if away < least:
			least = away
			nearest = i
	# Outside every zone, through a window or over a wall, it goes on
	# sounding like the zone that was left.
	if least <= 0.0 or _room < 0:
		_room = nearest
	var room := _rooms[_room]
	var beds := {room.bed: 0.0}
	for other in _rooms:
		if other.bed != room.bed and other.name in room.sees:
			var db: float = NEXT_DOOR_DB - BED_FALLOFF * _away(other.boxes, at)
			beds[other.bed] = maxf(db, beds.get(other.bed, SILENT))
	return {"tuning": room.tuning, "bed": room.bed, "beds": beds}


## How far `at` is from the nearest of `boxes`; 0 inside one.
func _away(boxes: Array[AABB], at: Vector3) -> float:
	var least := INF
	for box in boxes:
		least = minf(least, at.distance_to(at.clamp(box.position, box.end)))
	return least


## The same as _here() for a level that is not cut into zones, felt out from
## where the camera is: whether there is a roof over it, and how far off the
## walls are.
func _probe(camera: Camera3D) -> Dictionary:
	var space := camera.get_world_3d().direct_space_state
	var at := camera.global_position
	var reach: Array[float] = []
	var open := 0
	for way: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + way * PROBE_REACH, SOLID))
		reach.append(at.distance_to(hit.position) if hit else PROBE_REACH)
		if hit.is_empty() and way.y == 0.0:
			open += 1
	# No roof, or one that stands on posts: the open air.
	if reach[0] >= PROBE_REACH or open >= 2:
		return {"tuning": SPACES[&"yard"], "bed": _open_bed, "beds": {_open_bed: 0.0}}
	var size := Vector3(reach[2] + reach[3], reach[0] + reach[1], reach[4] + reach[5])
	var bed := &"hall" if size.y >= TALL else &"room"
	var volume := size.x * size.y * size.z
	var surface := 2.0 * (size.x * size.z + (size.x + size.z) * size.y)
	# In steps, so that walking past a crate does not retune the room.
	return {"tuning": _enclosed(maxf(snappedf(volume / surface, 0.25), 0.25)), "bed": bed, "beds": {bed: 0.0}}


## Has every bed that is heard here go round as loud as it should be, and now
## and then something sound from somewhere in the space.
func _lay_beds(here: Dictionary, camera: Camera3D, at_once: bool, delta: float) -> void:
	var beds: Dictionary = here.beds
	for kind: StringName in beds:
		var sound := StringName(BED + String(kind))
		if not _beds.has(kind) and _streams.has(sound):
			_beds[kind] = _bed(_streams[sound][0])
	for kind: StringName in _beds:
		var player: AudioStreamPlayer = _beds[kind]
		var to: float = beds.get(kind, SILENT)
		player.volume_db = to if at_once else move_toward(player.volume_db, to, BED_RATE * delta)
		if player.volume_db > SILENT and not player.playing:
			# Not from its start: the same few seconds every time one walks
			# in would soon be known by heart.
			player.play(randf() * player.stream.get_length())
		elif player.volume_db <= SILENT and player.playing:
			player.stop()
	_spot_in -= delta
	if _spot_in > 0.0:
		return
	_spot_in = randf_range(SPOT_EVERY.x, SPOT_EVERY.y)
	var spot := StringName(BED + String(here.bed) + SPOT)
	if _streams.has(spot):
		var off := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(SPOT_REACH.x, SPOT_REACH.y)
		play_at(spot, camera.global_position + off + Vector3.UP * randf_range(0.0, 4.0), SPOT_DB)


## A player for a bed, which goes round without a seam.
func _bed(take: AudioStream) -> AudioStreamPlayer:
	var loop: AudioStream = take.duplicate()
	if loop is AudioStreamWAV:
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_end = int(loop.get_length() * loop.mix_rate)
	elif loop.get(&"loop") != null:
		loop.set(&"loop", true)
	var player := AudioStreamPlayer.new()
	player.stream = loop
	player.bus = AMBIENCE
	player.volume_db = SILENT
	add_child(player)
	return player


## Plays the sound of a door for as long as it is on its way. Whatever moves
## a door does not have to say so: this looks at where the doors are.
func _watch_doors(delta: float) -> void:
	for door: Node3D in get_tree().get_nodes_in_group(DOORS):
		var id := door.get_instance_id()
		var at := door.global_position
		if not _doors.has(id):
			_doors[id] = {"at": at, "player": null, "still": 0.0}
			continue
		var seen: Dictionary = _doors[id]
		var moved := at.distance_to(seen.at)
		seen.at = at
		var player: AudioStreamPlayer3D = seen.player if is_instance_valid(seen.player) else null
		# A door that is somewhere else all at once was put there, as one
		# that is already open when the level loads.
		if moved > DOOR_MOVES and moved < 0.25:
			seen.still = 0.0
			if player == null:
				seen.player = play_on(DOOR_SOUND, door)
			continue
		seen.still += delta
		if player and seen.still > 2.0 * delta:
			var hush := player.create_tween()
			hush.tween_property(player, ^"volume_db", SILENT, DOOR_STOP)
			hush.tween_callback(player.queue_free)
			seen.player = null


## Plays the pieces of music of those names one after the other, round and
## round; a piece on its own goes round by itself. assets/music/ holds each
## as <piece>.ogg or <piece>.mp3. If one of them is playing, it carries on
## where it is and the others follow it. A piece there is no file for is
## left out, and if that is all of them it is silence, so the game can ask
## for one that has yet to be made.
## `db` is how loud they play: music behind a fight wants to be well under it.
## Another piece that is playing dies away first.
## A file <piece>_fight next to a piece is its second layer: it plays along
## from the start and is heard while the level says there is a fight on.
func music(pieces: Array[StringName], seconds := 0.5, db := 0.0) -> void:
	# All of them loaded now, while a level loads, and not when one ends in
	# the middle of a fight.
	var turns := {}
	for piece in pieces:
		var path := _file(piece)
		if path:
			turns[piece] = _turns[piece] if _turns.has(piece) else load(path)
	_turns = turns
	var busy := _music != null and _music.playing
	if busy and _turns.has(_piece):
		_loop(_music.stream)
		# Asked for again while the piece before it is still dying away: it
		# is on its way, and a fade started now would call that off.
		if not _changing:
			_swell(db, seconds)
		return
	if _turns.is_empty():
		stop_music(seconds)
		return
	var first: StringName = _turns.keys()[0]
	if busy:
		_piece = first
		_swell(-60.0, CHANGE_TIME)
		_changing = true
		_music_fade.tween_callback(_start_music.bind(first, _turns[first], seconds, db))
	else:
		_start_music(first, _turns[first], seconds, db)


## Lets the music die away over that many seconds.
func stop_music(seconds := 1.5) -> void:
	_piece = &""
	_turns = {}
	_changing = false
	if _music == null or not _music.playing:
		return
	_swell(-60.0, seconds)
	_music_fade.tween_callback(_hush_music)


## The piece that is playing, or an empty name.
func music_playing() -> StringName:
	return _piece


func _start_music(piece: StringName, stream: AudioStream, seconds := 0.0, db := 0.0) -> void:
	if _music == null:
		_music = _music_player()
		_music.finished.connect(_next_piece)
	_piece = piece
	_changing = false
	_music.stream = _loop(stream)
	_layer(piece)
	_set_music_db(-60.0 if seconds > 0.0 else db)
	# Both in the same frame, and so in the same block of the mix: the layer
	# is in step with the piece from its first sample.
	_music.play()
	if _music_over:
		_music_over.play()
	_swell(db, seconds)


func _music_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = MUSIC
	# The title screen and the pause menu stop the tree, not the music.
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


## Where the piece of that name is, or nothing if it has yet to be made.
func _file(piece: StringName) -> String:
	for kind in PIECE_KINDS:
		var path := PIECES + String(piece) + kind
		if ResourceLoader.exists(path):
			return path
	return ""


## A stream set to go round and round if its piece plays on its own, and to
## end if another follows it, if it is of a kind that can.
func _loop(stream: AudioStream) -> AudioStream:
	if stream.get(&"loop") != null:
		stream.set(&"loop", _turns.size() < 2)
	return stream


## The piece that played has come to its end: the next one starts straight
## after it, as loud.
func _next_piece() -> void:
	if _changing or _turns.size() < 2 or not _turns.has(_piece):
		return
	var pieces: Array = _turns.keys()
	var next: StringName = pieces[(pieces.find(_piece) + 1) % pieces.size()]
	_start_music(next, _turns[next], 0.0, _music_db)


## Gets the second layer of `piece` ready to start with it, if it has one,
## and drops that of the piece before.
func _layer(piece: StringName) -> void:
	if is_instance_valid(_music_over):
		_music_over.queue_free()
	_music_over = null
	_heat = 0.0
	var path := _file(StringName(String(piece) + FIGHT_LAYER))
	if path:
		_music_over = _music_player()
		_music_over.stream = _loop(load(path))


func _hush_music() -> void:
	_music.stop()
	if is_instance_valid(_music_over):
		_music_over.stop()


func _swell(to_db: float, seconds: float) -> void:
	if _music_fade:
		_music_fade.kill()
	_music_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_fade.tween_method(_set_music_db, _music_db, to_db, maxf(seconds, 0.01))


## Sets how loud the piece plays, and its second layer with it.
func _set_music_db(db: float) -> void:
	_music_db = db
	_music.volume_db = db
	if is_instance_valid(_music_over):
		_music_over.volume_db = db + linear_to_db(maxf(_heat, 0.001))


## Brings the second layer of the music in while the level says there is a
## fight on, and takes it out again after.
func _follow_fight(scene: Node, delta: float) -> void:
	if not is_instance_valid(_music_over):
		return
	var hot: bool = scene.has_method(&"fighting") and scene.call(&"fighting")
	var heat := move_toward(_heat, 1.0 if hot else 0.0, delta / (FIGHT_RISE if hot else FIGHT_FALL))
	if heat != _heat:
		_heat = heat
		_set_music_db(_music_db)


func has(sound: StringName) -> bool:
	return _streams.has(sound)


## A take of `sound` that goes round for as long as it is played, for
## something that runs: a motor, a roar of fire. Null if there is no such sound.
func loop_of(sound: StringName) -> AudioStream:
	if not _streams.has(sound):
		return null
	var take: AudioStream = (_streams[sound] as Array)[0].duplicate()
	if take is AudioStreamWAV:
		var wav := take as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	elif take is AudioStreamOggVorbis:
		(take as AudioStreamOggVorbis).loop = true
	return take


func play(sound: StringName, volume_db := 0.0) -> void:
	var player := AudioStreamPlayer.new()
	player.volume_db = volume_db
	_start(player, sound)


## A sound from `position`. Up to `near` metres off it sounds as it does next
## to it; further off it falls, and it is heard out to ten times that. Any
## sound but a very loud one is at home with NEAR.
func play_at(sound: StringName, position: Vector3, volume_db := 0.0, near := NEAR) -> void:
	_start(_placed(position, volume_db, near), sound)


## The same from something that moves: the sound is `offset` from `node`,
## goes where it goes and ends with it. Returns what plays it, for whoever
## wants to cut it short; null if there is no such sound.
func play_on(sound: StringName, node: Node3D, offset := Vector3.ZERO, volume_db := 0.0) -> AudioStreamPlayer3D:
	var player := _placed(offset, volume_db)
	return player if _start(player, sound, node) else null


## A shot that went from `from` to `to` and was not fired by whoever listens.
## If it went by close to the camera and on, it is heard going by, on the
## side it passed.
func passing(from: Vector3, to: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	var now := Time.get_ticks_msec() / 1000.0
	if camera == null or now - _passed < PASS_GAP:
		return
	var ear := camera.global_position
	var path := to - from
	var length := path.length()
	if length < PASS_BEYOND:
		return
	var along := (ear - from).dot(path) / length
	# One that ends at the camera was a hit, and one that ends before it hit
	# whatever is in between.
	if along <= 0.0 or along > length - PASS_BEYOND:
		return
	var nearest := from + path * (along / length)
	var miss := nearest.distance_to(ear)
	if miss > PASS_REACH:
		return
	_passed = now
	play_at(&"whiz", nearest, lerpf(0.0, -9.0, miss / PASS_REACH))


func _placed(position: Vector3, volume_db: float, near := NEAR) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.volume_db = volume_db
	player.unit_size = near
	player.max_distance = 10.0 * near
	# By default a 3D player takes the top off a sound as it gets further away
	# or quieter: 21 to 29 dB above 5 kHz at 16 m, a robot across the hall.
	player.attenuation_filter_db = -6.0
	# It also caps how loud a sound close by can get, at 3 dB: an explosion
	# asks for more.
	player.max_db = maxf(player.max_db, volume_db)
	player.position = position
	return player


## Changes the reverb to that of another kind of space, over `seconds`.
func set_space(space: StringName, seconds := 0.5) -> void:
	if SPACES.has(space):
		_tune(SPACES[space], seconds)


## Tunes the reverb to a row as in SPACES, over `seconds`.
func _tune(to: Array, seconds: float) -> void:
	if to == _tuning or _reverbs.is_empty():
		return
	_tuning = to
	if _fade:
		_fade.kill()
	if seconds <= 0.0:
		for reverb in _reverbs:
			reverb.room_size = to[0]
			reverb.damping = to[1]
			reverb.hipass = to[2]
			reverb.predelay_msec = to[3]
			reverb.predelay_feedback = to[4]
			reverb.wet = to[5]
		return
	# The echo's interval cannot slide without bending the pitch of what is in
	# it, so it jumps: at once when there is no echo to hear, else at the end.
	var jump_first := _reverbs[0].predelay_feedback == 0.0
	_fade = create_tween().set_parallel()
	for reverb in _reverbs:
		if jump_first:
			reverb.predelay_msec = to[3]
		_fade.tween_property(reverb, ^"room_size", to[0], seconds)
		_fade.tween_property(reverb, ^"damping", to[1], seconds)
		_fade.tween_property(reverb, ^"hipass", to[2], seconds)
		_fade.tween_property(reverb, ^"wet", to[5], seconds)
		_fade.tween_property(reverb, ^"predelay_feedback", to[4] if jump_first else 0.0, seconds)
	if not jump_first:
		_fade.chain().tween_callback(func() -> void:
			for reverb in _reverbs:
				reverb.predelay_msec = to[3]
				reverb.predelay_feedback = to[4])


## What a sound from `distance` metres off puts into the reverb on top of
## what it puts there by itself, as a gain against the sound at full level.
## By itself the reverb of a sound falls as the sound does, by 6 dB for every
## doubling of the distance; this is what is missing from a reverb that stays
## as loud as it is at NEAR all the way to FAR.
func _far(distance: float) -> float:
	if distance <= NEAR:
		return 0.0
	return minf(1.0, FAR / distance) - NEAR / distance


## Starts a second player beside a placed one for what the sound adds to the
## reverb from where it is: the same take at the same pitch, on Far.
func _send_far(player: AudioStreamPlayer3D, under: Node) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or AudioServer.get_bus_index(FAR_BUS) < 0:
		return
	# A sound that carries further than NEAR fills the room from as much
	# further off.
	var gain := _far(camera.global_position.distance_to(player.global_position) * NEAR / player.unit_size)
	if gain < 0.05:
		return
	var far := AudioStreamPlayer3D.new()
	far.stream = player.stream
	far.pitch_scale = player.pitch_scale
	far.bus = FAR_BUS
	far.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	far.volume_db = player.volume_db + linear_to_db(gain)
	far.max_db = maxf(far.max_db, far.volume_db)
	far.max_distance = player.max_distance
	far.attenuation_filter_db = player.attenuation_filter_db
	# A room answers from all round, not from where the sound was.
	far.panning_strength = 0.5
	far.position = player.position
	far.finished.connect(far.queue_free)
	player.tree_exiting.connect(far.queue_free)
	under.add_child(far)
	far.play()


## Plays `sound` on `player`, as a child of `under`. False if there is no such
## sound, and then the player is gone.
func _start(player: Node, sound: StringName, under: Node = self) -> bool:
	if not _streams.has(sound):
		if not _unknown.has(sound):
			_unknown[sound] = true
			push_warning("Sfx has no sound named %s" % sound)
		player.free()
		return false
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
	under.add_child(player)
	player.play()
	if player is AudioStreamPlayer3D and not ui:
		_send_far(player, under)
	return true


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
