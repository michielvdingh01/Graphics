extends Node
## Placeholder audio, synthesised at startup so the game needs no audio files yet.
##
## Gameplay code only refers to sounds by name, so phase 3 can swap these for
## generated or recorded samples without touching any caller.

const RATE := 22050

# name: [length s, noise gain, noise decay, noise lowpass 0..1,
#        tone gain, tone Hz, tone pitch drop, tone decay, drive]
const SOUNDS := {
	&"rifle_shot": [0.30, 1.0, 22.0, 0.55, 0.9, 160.0, 18.0, 20.0, 3.0],
	&"pistol_shot": [0.22, 1.0, 30.0, 0.75, 0.7, 220.0, 22.0, 28.0, 2.5],
	&"shotgun_shot": [0.50, 1.0, 11.0, 0.35, 1.1, 90.0, 10.0, 12.0, 4.0],
	&"smg_shot": [0.18, 1.0, 34.0, 0.8, 0.6, 260.0, 24.0, 32.0, 2.5],
	&"marksman_shot": [0.55, 1.0, 13.0, 0.5, 1.1, 120.0, 14.0, 11.0, 4.0],
	&"melee": [0.14, 0.7, 30.0, 0.1, 0.9, 110.0, 12.0, 26.0, 2.5],
	&"enemy_shot": [0.25, 0.4, 25.0, 0.9, 0.7, 700.0, 12.0, 22.0, 2.0],
	&"enemy_alert": [0.12, 0.0, 1.0, 1.0, 0.5, 1200.0, -3.0, 15.0, 1.0],
	&"enemy_death": [0.45, 0.6, 8.0, 0.3, 0.8, 300.0, 8.0, 7.0, 2.5],
	&"dry_fire": [0.04, 0.3, 120.0, 1.0, 0.3, 1800.0, 0.0, 150.0, 1.0],
	&"reload": [0.12, 0.6, 40.0, 0.8, 0.4, 500.0, 30.0, 50.0, 1.5],
	&"reload_end": [0.08, 0.6, 60.0, 1.0, 0.5, 900.0, 10.0, 70.0, 1.5],
	&"switch": [0.07, 0.5, 60.0, 0.6, 0.3, 700.0, 20.0, 60.0, 1.2],
	&"hit": [0.05, 0.1, 200.0, 1.0, 0.8, 1400.0, 0.0, 60.0, 1.0],
	&"headshot": [0.07, 0.1, 200.0, 1.0, 0.8, 2100.0, 0.0, 45.0, 1.0],
	&"kill": [0.18, 0.0, 1.0, 1.0, 0.7, 880.0, -4.0, 14.0, 1.0],
	&"footstep": [0.09, 0.6, 45.0, 0.15, 0.5, 90.0, 20.0, 50.0, 1.5],
	&"land": [0.16, 0.8, 25.0, 0.12, 0.9, 70.0, 15.0, 25.0, 2.0],
	&"slide": [0.60, 0.5, 5.0, 0.25, 0.0, 100.0, 0.0, 1.0, 1.2],
	&"hurt": [0.20, 0.5, 18.0, 0.2, 0.9, 140.0, 6.0, 14.0, 2.5],
	&"impact": [0.06, 0.7, 70.0, 0.5, 0.3, 400.0, 30.0, 80.0, 1.5],
	&"casing": [0.07, 0.12, 90.0, 1.0, 0.45, 3400.0, 3.0, 55.0, 1.0],
}

var _streams := {}


func _ready() -> void:
	for sound: StringName in SOUNDS:
		_streams[sound] = _synthesise(SOUNDS[sound])


func play(sound: StringName, volume_db := 0.0) -> void:
	var player := AudioStreamPlayer.new()
	player.volume_db = volume_db
	_start(player, sound)


func play_at(sound: StringName, position: Vector3, volume_db := 0.0) -> void:
	var player := AudioStreamPlayer3D.new()
	player.volume_db = volume_db
	player.unit_size = 8.0
	player.max_distance = 80.0
	player.position = position
	_start(player, sound)


func _start(player: Node, sound: StringName) -> void:
	player.stream = _streams[sound]
	player.pitch_scale = randf_range(0.94, 1.06)
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
