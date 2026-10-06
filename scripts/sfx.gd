extends Node
## Placeholder sound bank. Every sound is synthesised at startup behind a stable name, so the
## AI asset pipeline (phase 3) can later replace a name with a generated file without touching callers.

const MIX_RATE := 32000
const POOL_2D := 12
const POOL_3D := 20

var _sounds: Dictionary[String, AudioStreamWAV] = {}
var _players_2d: Array[AudioStreamPlayer] = []
var _players_3d: Array[AudioStreamPlayer3D] = []
var _next_2d := 0
var _next_3d := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	_build_bank()
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players_2d.append(p)
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.max_distance = 80.0
		p.unit_size = 6.0
		add_child(p)
		_players_3d.append(p)
	# A touch of room reverb makes the dry synthesised sounds sit in the level.
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.4
	reverb.damping = 0.6
	reverb.wet = 0.1
	reverb.dry = 1.0
	AudioServer.add_bus_effect(0, reverb)


func has_sound(sound: String) -> bool:
	return _sounds.has(sound)


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _sounds.has(sound):
		return
	var p := _players_2d[_next_2d]
	_next_2d = (_next_2d + 1) % POOL_2D
	p.stream = _sounds[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch * _rng.randf_range(0.97, 1.03)
	p.play()


func play_at(sound: String, position: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	if not _sounds.has(sound):
		return
	var p := _players_3d[_next_3d]
	_next_3d = (_next_3d + 1) % POOL_3D
	p.stream = _sounds[sound]
	p.global_position = position
	p.volume_db = volume_db
	p.pitch_scale = pitch * _rng.randf_range(0.96, 1.04)
	p.play()


# --- synthesis -------------------------------------------------------------------------------

func _build_bank() -> void:
	for style in ["rifle", "pistol", "shotgun"]:
		var pitch := {"rifle": 1.0, "pistol": 1.35, "shotgun": 0.62}[style] as float
		var length := {"rifle": 0.3, "pistol": 0.22, "shotgun": 0.55}[style] as float
		_sounds["shot_" + style] = _gunshot(pitch, length, 1.0)
	_sounds["enemy_shot"] = _gunshot(0.85, 0.28, 0.8)
	_sounds["dry_fire"] = _tick(0.06, 2400.0, 0.5)
	_sounds["reload_out"] = _tick(0.18, 900.0, 0.8)
	_sounds["reload_in"] = _tick(0.14, 650.0, 1.0)
	_sounds["equip"] = _tick(0.2, 1300.0, 0.6)
	_sounds["hit"] = _tone(0.06, 1700.0, 1700.0, 0.35)
	_sounds["hit_head"] = _tone(0.11, 2600.0, 2300.0, 0.4)
	_sounds["kill"] = _tone(0.22, 700.0, 280.0, 0.55)
	_sounds["impact"] = _noise(0.16, 0.12, 0.45, 40.0)
	_sounds["flesh"] = _noise(0.2, 0.06, 0.5, 30.0)
	_sounds["enemy_hurt"] = _tone(0.16, 190.0, 120.0, 0.5, 0.35)
	_sounds["enemy_die"] = _tone(0.45, 210.0, 55.0, 0.6, 0.3)
	_sounds["enemy_windup"] = _tone(0.35, 400.0, 1100.0, 0.25)
	_sounds["player_hurt"] = _tone(0.25, 130.0, 70.0, 0.7, 0.5)
	_sounds["step"] = _noise(0.09, 0.05, 0.25, 55.0)
	_sounds["land"] = _noise(0.2, 0.08, 0.5, 35.0)
	_sounds["slide"] = _noise(0.7, 0.35, 0.22, 4.0)


func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


func _gunshot(pitch: float, length: float, gain: float) -> AudioStreamWAV:
	var n := int(length * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		# Low thump: a sine that sweeps down, like the pressure wave of the shot.
		var f := lerpf(160.0, 45.0, minf(t * 14.0, 1.0)) * pitch
		phase += TAU * f / MIX_RATE
		var thump := sin(phase) * exp(-t * 16.0 / maxf(length, 0.1) * 0.4)
		# Crack: bright noise that dies almost immediately.
		var white := _rng.randf_range(-1.0, 1.0)
		var crack := white * exp(-t * 90.0)
		# Body: low-passed noise tail, longer for bigger weapons.
		lp += (white - lp) * clampf(0.35 / pitch, 0.05, 0.7)
		var tail := lp * exp(-t * (5.0 / maxf(length, 0.1)))
		out[i] = (thump * 0.55 + crack * 0.55 + tail * 0.9) * gain
	return _make(out)


func _tick(length: float, freq: float, gain: float) -> AudioStreamWAV:
	var n := int(length * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var env := exp(-t * 55.0)
		var ping := sin(TAU * freq * t) * exp(-t * 38.0)
		out[i] = (_rng.randf_range(-1.0, 1.0) * 0.5 + ping) * env * gain
	return _make(out)


func _tone(length: float, f0: float, f1: float, gain: float, grit := 0.0) -> AudioStreamWAV:
	var n := int(length * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		phase += TAU * lerpf(f0, f1, t) / MIX_RATE
		var wave := sin(phase) + grit * (fposmod(phase / TAU, 1.0) * 2.0 - 1.0)
		var env := minf(t * 40.0, 1.0) * pow(1.0 - t, 2.0)
		out[i] = wave * env * gain
	return _make(out)


## Low-passed noise burst. `cutoff` is the filter coefficient, `decay` the envelope speed.
func _noise(length: float, cutoff: float, gain: float, decay: float) -> AudioStreamWAV:
	var n := int(length * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * cutoff
		var env := minf(t * 80.0, 1.0) * exp(-t * decay)
		out[i] = lp * env * gain * 3.0
	return _make(out)
