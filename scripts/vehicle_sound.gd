extends Node3D
## What a vehicle sounds like as it goes: its engine, its tyres or its
## tracks, its turret turning, an engine that is hit and one that burns.
## What happens once, a door, a shift, a crash, scripts/vehicle.gd plays
## itself.
##
## The engine is a few takes that go round, each recorded with the engine at
## one speed (VehicleData.engine_rpms). Whatever it turns at, the two takes
## either side of that are heard, each pitched to it and the nearer one the
## louder, so that it never jumps from one take to the next. Pulling, it is
## louder than running free; when it misfires it drops out for a moment and
## bangs.

## How far off it is as loud as close by, and how far it is heard at all.
const NEAR := 10.0
const REACH := 160.0
## dB a second in which the engine comes up as it starts and dies away as it
## stops.
const RISE := 4.0
const FALL := 1.6
## How fast what it pulls with is followed, per second: the sound eases into
## the gas, it does not jump with the key.
const FOLLOW := 6.0
## How far a misfire drops it, in dB, and the sound of the bang.
const MISFIRE_DB := -16.0
const BANG := &"engine_backfire"
## At this speed in m/s the tyres or the tracks are as loud as they get.
const LOUDEST_ROLL := 14.0
const SILENT := -80.0

var _vehicle: Node3D
var _data: VehicleData
var _engine: Array[AudioStreamPlayer3D] = []
var _roll: AudioStreamPlayer3D
var _skid: AudioStreamPlayer3D
var _turret: AudioStreamPlayer3D
var _hit: AudioStreamPlayer3D
var _fire: AudioStreamPlayer3D
var _running := 0.0
var _pull := 0.0
var _cut := 0.0


func setup(vehicle: Node3D) -> void:
	_vehicle = vehicle
	_data = vehicle.data
	position = _data.engine_at
	for loop in _data.engine_loops:
		_engine.append(_loop(loop))
	_roll = _loop(_data.roll_sound)
	_skid = _loop(&"tyre_skid" if not _data.tracked else &"")
	_turret = _loop(_data.turret_sound)
	_hit = _loop(_data.damaged_sound)
	_fire = _loop(&"vehicle_fire")


## A player for a take of `sound` that goes round, or null if there is none.
func _loop(sound: StringName) -> AudioStreamPlayer3D:
	if sound == &"" or not Sfx.has(sound):
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = Sfx.loop_of(sound)
	player.bus = Sfx.WORLD
	player.unit_size = NEAR
	player.max_distance = REACH
	player.attenuation_filter_db = -6.0
	player.max_db = 6.0
	player.volume_db = SILENT
	add_child(player)
	return player


## The engine drops out for a moment, with a bang.
func misfire() -> void:
	_cut = MISFIRE_DB
	if Sfx.has(BANG):
		Sfx.play_on(BANG, _vehicle, _data.engine_at, -4.0)


## Follows the vehicle: called every frame by it.
func listen(delta: float) -> void:
	var on: bool = _vehicle.engine_on
	_running = move_toward(_running, 1.0 if on else 0.0, delta * (RISE if on else FALL))
	var pulling: float = 0.0 if _vehicle.shifting() else maxf(_vehicle.gas, 0.0)
	_pull = lerpf(_pull, pulling, 1.0 - exp(-FOLLOW * delta))
	_cut = move_toward(_cut, 0.0, delta * 60.0) if not _vehicle.misfiring() else MISFIRE_DB
	_sound_engine()
	var rolling: float = _vehicle.rolling() if _vehicle.condition != _vehicle.Condition.WRECKED else 0.0
	var roll := clampf(rolling / LOUDEST_ROLL, 0.0, 1.0)
	_level(_roll, roll, (0.6 + rolling / 16.0) if _data.tracked else (0.85 + rolling / 40.0), -4.0)
	_level(_skid, _vehicle.skidding() * clampf(rolling / 4.0, 0.0, 1.0), 1.0, -6.0)
	_level(_turret, clampf(_vehicle.turret_moving(), 0.0, 1.0), 1.0, -8.0)
	var hit: bool = _vehicle.condition >= _vehicle.Condition.DAMAGED and _vehicle.condition < _vehicle.Condition.WRECKED and on
	_level(_hit, 1.0 if hit else 0.0, 0.9 + _vehicle.rpm / _data.max_rpm * 0.4, -6.0)
	_level(_fire, 1.0 if _vehicle.burning() else 0.0, 1.0, -2.0)


## The takes of the engine, crossfaded by its speed: see the top of this file.
func _sound_engine() -> void:
	if _engine.is_empty():
		return
	var rpm: float = maxf(_vehicle.rpm, 1.0)
	var rpms := _data.engine_rpms
	var shares: Array[float] = []
	shares.resize(_engine.size())
	shares.fill(0.0)
	if rpm <= rpms[0]:
		shares[0] = 1.0
	elif rpm >= rpms[rpms.size() - 1]:
		shares[rpms.size() - 1] = 1.0
	else:
		for i in rpms.size() - 1:
			if rpm >= rpms[i] and rpm < rpms[i + 1]:
				var t := (rpm - rpms[i]) / (rpms[i + 1] - rpms[i])
				shares[i] = cos(t * PI * 0.5)
				shares[i + 1] = sin(t * PI * 0.5)
	var loud := lerpf(_data.engine_idle_db, _data.engine_load_db, _pull) + _cut
	for i in _engine.size():
		if _engine[i] == null:
			continue
		_level(_engine[i], shares[i] * _running, clampf(rpm / rpms[i], 0.45, 2.2), loud)


## Plays `player` at `share` of its level, 0 being silent, at `pitch`, and
## `db` loud at its loudest; stops it once it is silent.
func _level(player: AudioStreamPlayer3D, share: float, pitch: float, db: float) -> void:
	if player == null:
		return
	if share < 0.002:
		if player.playing:
			player.stop()
		return
	player.volume_db = db + linear_to_db(share)
	player.pitch_scale = maxf(pitch, 0.05)
	if not player.playing:
		# Not every vehicle in step: each starts somewhere in its take.
		player.play(randf() * player.stream.get_length())
