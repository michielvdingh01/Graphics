extends SceneTree
## Renders a list of (sound file, time) events through a bus layout and writes
## what arrives at the end of the Master bus to a WAV. No sound card, no window:
##
##   Godot --headless --script render_mix.gd -- spec.json out.wav
##
## Run it with --path <a folder holding an empty project.godot> to use only
## what the spec names (without any project Godot takes itself for the editor
## and rewrites the editor's settings), or with --path <the game> (and
## --log-file <somewhere else>) to get its default_bus_layout.tres and res://
## paths.
##
## spec.json:
##   "layout":  path of a bus layout .tres to load first (optional)
##   "buses":   [{"name", "send", "volume_db", "effects": [{"class", ...properties}]}]
##              buses to add or, when the name exists, to replace the effects of (optional)
##   "set":     [{"bus", "effect": index, ...properties}] changes to effects of the layout (optional)
##   "volume_db": {"World": -3.0, ...} bus volumes (optional)
##   "length":  seconds to render
##   "taps":    ["World", ...] also writes out.<bus>.wav, taken after that bus's effects (optional)
##   "listener": [x, y, z] where the camera stands for 3D events; it looks along -Z (optional)
##   "float":   true writes 32-bit float WAVs instead of 16-bit (optional)
##   "events":  [{"t": seconds, "file": path, "bus": "World", "db": 0.0, "pitch": 1.0,
##                "pos": [x, y, z], "unit_size": 8.0, "max_distance": 80.0, "max_db": 3.0,
##                "filter_db": -24.0, "filter_hz": 5000.0, "attenuation": true, "panning": 1.0}]
##              with "pos" the event is an AudioStreamPlayer3D set up as scripts/sfx.gd does;
##              "attenuation": false is one that is as loud from any distance.
##              "from": seconds into the file at which to begin; "until": the moment at
##              which the event is cut off, having died away over "fade" seconds.
##
## How it keeps time. The Dummy driver mixes 4096 frames at a go, about every
## 93 ms, and a sound starts at the beginning of the block after play() was
## called: started the ordinary way, two shots 65 ms apart would land either on
## top of each other or 93 ms apart. So every event is started at once, before
## the first block, behind as much silence as its time asks for. The silence is
## prepended to the sample data, which is why "file" has to be a WAV: 16-bit
## PCM on disk, or a res:// path of the project, which is decoded as imported.
## The result does not depend on how fast the machine is: the same spec gives
## the same samples.

const WATCHDOG := 30.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args().duplicate()
	# Arguments meant for the project's own autoloads (such as --play) pass through.
	args = Array(args).filter(func(a: String) -> bool: return not a.begins_with("--"))
	if args.size() < 2:
		print("usage: Godot --headless --script render_mix.gd -- spec.json out.wav")
		quit(2)
		return
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var timer := Timer.new()
	timer.wait_time = float(spec.get("length", 3.0)) * 1.5 + WATCHDOG
	timer.autostart = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.timeout.connect(func() -> void:
		print("render_mix: timed out")
		quit(2))
	root.add_child(timer)
	_run.call_deferred(spec, args[1])


func _effect(description: Dictionary) -> AudioEffect:
	var effect: AudioEffect = ClassDB.instantiate(description["class"])
	for key: String in description:
		if key != "class":
			effect.set(key, description[key])
	return effect


## The sound at `path` as 16-bit PCM with `frames` of silence in front.
## A path on disk is read as it is. A res:// path is taken as the project
## imported it, which is what the game plays: with the default import that is
## Quite OK Audio, a lossy format, so it is decoded here first.
## `first` and `count` cut a piece out of it, in frames (a count below 0 is
## all that is left), of which the last `fade` frames die away.
func _padded(path: String, frames: int, cache: Dictionary, first := 0, count := -1, fade := 0) -> AudioStreamWAV:
	if not cache.has(path):
		var loaded: AudioStreamWAV
		if path.begins_with("res://") and ResourceLoader.exists(path):
			loaded = _as_pcm(load(path))
		else:
			loaded = AudioStreamWAV.load_from_file(path)
		cache[path] = loaded
	var source: AudioStreamWAV = cache[path]
	if source == null or source.format != AudioStreamWAV.FORMAT_16_BITS:
		push_error("render_mix: %s is not a WAV this script can play" % path)
		return null
	var stream := AudioStreamWAV.new()
	stream.format = source.format
	stream.mix_rate = source.mix_rate
	stream.stereo = source.stereo
	var size := 4 if source.stereo else 2
	var sound := source.data
	if first > 0 or count >= 0:
		sound = sound.slice(first * size, (first + count) * size if count >= 0 else sound.size())
		var total := sound.size() / size
		for i in range(maxi(total - fade, 0), total):
			for at in range(i * size, (i + 1) * size, 2):
				sound.encode_s16(at, int(sound.decode_s16(at) * float(total - i) / fade))
	var silence := PackedByteArray()
	silence.resize(frames * size)
	silence.append_array(sound)
	stream.data = silence
	return stream


## Decodes any stream to 16-bit PCM at the mix rate by mixing it the way the
## audio server would, without the server.
func _as_pcm(stream: AudioStream) -> AudioStreamWAV:
	if stream == null:
		return null
	if stream is AudioStreamWAV and (stream as AudioStreamWAV).format == AudioStreamWAV.FORMAT_16_BITS:
		return stream
	var rate := int(AudioServer.get_mix_rate())
	# Mixing a stream by hand delays it by a few frames (the resampler looks
	# ahead), and playing the result delays it again. Measure the first delay
	# with a click at the stream's own rate and cut it off.
	var source_rate: Variant = stream.get(&"mix_rate")
	var click := AudioStreamWAV.new()
	click.format = AudioStreamWAV.FORMAT_16_BITS
	click.mix_rate = int(source_rate) if source_rate != null else rate
	var click_data := PackedByteArray()
	click_data.resize(256)
	click_data.encode_s16(0, 32767)
	click.data = click_data
	var probe := click.instantiate_playback()
	probe.start(0.0)
	var heard := probe.mix_audio(1.0, 64)
	probe.stop()
	var skip := 0
	for i in heard.size():
		if absf(heard[i].x) > absf(heard[skip].x):
			skip = i

	var playback := stream.instantiate_playback()
	playback.start(0.0)
	var frames := playback.mix_audio(1.0, int(ceil(stream.get_length() * rate)) + 64)
	playback.stop()
	frames = frames.slice(skip)
	var data := PackedByteArray()
	data.resize(frames.size() * 4)
	for i in frames.size():
		data.encode_s16(i * 4, clampi(roundi(frames[i].x * 32768.0), -32768, 32767))
		data.encode_s16(i * 4 + 2, clampi(roundi(frames[i].y * 32768.0), -32768, 32767))
	var pcm := AudioStreamWAV.new()
	pcm.format = AudioStreamWAV.FORMAT_16_BITS
	pcm.mix_rate = rate
	pcm.stereo = true
	pcm.data = data
	return pcm


func _run(spec: Dictionary, out: String) -> void:
	# The game's own autoloads may have paused the tree (the title screen does).
	paused = false
	if spec.has("layout"):
		var layout: AudioBusLayout = load(spec["layout"])
		if layout == null:
			print("render_mix: cannot load layout ", spec["layout"])
			quit(2)
			return
		AudioServer.set_bus_layout(layout)
	for bus: Dictionary in spec.get("buses", []):
		var index := AudioServer.get_bus_index(bus["name"])
		if index < 0:
			index = AudioServer.bus_count
			AudioServer.add_bus()
			AudioServer.set_bus_name(index, bus["name"])
		if bus.has("send") and index > 0:
			AudioServer.set_bus_send(index, bus["send"])
		AudioServer.set_bus_volume_db(index, bus.get("volume_db", 0.0))
		while AudioServer.get_bus_effect_count(index) > 0:
			AudioServer.remove_bus_effect(index, 0)
		for description: Dictionary in bus.get("effects", []):
			AudioServer.add_bus_effect(index, _effect(description))
	for change: Dictionary in spec.get("set", []):
		var effect := AudioServer.get_bus_effect(AudioServer.get_bus_index(change["bus"]), int(change["effect"]))
		for key: String in change:
			if key != "bus" and key != "effect":
				effect.set(key, change[key])
	var volumes: Dictionary = spec.get("volume_db", {})
	for bus: String in volumes:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), volumes[bus])

	var rate := AudioServer.get_mix_rate()
	var length := int(float(spec.get("length", 3.0)) * rate)
	var taps: Array = ["Master"]
	taps.append_array(spec.get("taps", []))
	var captures: Array[AudioEffectCapture] = []
	var data: Array[PackedVector2Array] = []
	for tap: String in taps:
		var capture := AudioEffectCapture.new()
		capture.buffer_length = 1.0
		AudioServer.add_bus_effect(AudioServer.get_bus_index(tap), capture)
		captures.append(capture)
		data.append(PackedVector2Array())

	var camera := Camera3D.new()
	var at: Array = spec.get("listener", [0.0, 0.0, 0.0])
	camera.position = Vector3(at[0], at[1], at[2])
	root.add_child(camera)
	camera.make_current()

	var cache := {}
	var players: Array[Node] = []
	var positional := false
	for event: Dictionary in spec.get("events", []):
		var pitch: float = event.get("pitch", 1.0)
		var probe: AudioStreamWAV = _padded(event["file"], 0, cache)
		if probe == null:
			quit(2)
			return
		# Frames of silence in the stream's own rate, played at this pitch.
		var lead := roundi(float(event.get("t", 0.0)) * probe.mix_rate * pitch)
		var first := roundi(float(event.get("from", 0.0)) * probe.mix_rate)
		var count := roundi((float(event["until"]) - float(event.get("t", 0.0))) * probe.mix_rate * pitch) if event.has("until") else -1
		var stream := _padded(event["file"], lead, cache, first, count, roundi(float(event.get("fade", 0.0)) * probe.mix_rate * pitch))
		var player: Node
		if event.has("pos"):
			var p3 := AudioStreamPlayer3D.new()
			var pos: Array = event["pos"]
			p3.position = Vector3(pos[0], pos[1], pos[2])
			p3.unit_size = event.get("unit_size", 8.0)
			p3.max_distance = event.get("max_distance", 80.0)
			if event.has("max_db"):
				p3.max_db = event["max_db"]
			if event.has("filter_db"):
				p3.attenuation_filter_db = event["filter_db"]
			if event.has("filter_hz"):
				p3.attenuation_filter_cutoff_hz = event["filter_hz"]
			if not event.get("attenuation", true):
				p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
			if event.has("panning"):
				p3.panning_strength = event["panning"]
			positional = true
			player = p3
		else:
			player = AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = event.get("db", 0.0)
		player.pitch_scale = pitch
		var bus: String = event.get("bus", "Master")
		if AudioServer.get_bus_index(bus) < 0:
			print("render_mix: no bus named '%s'; Godot will play this on Master" % bus)
		player.bus = bus
		root.add_child(player)
		players.append(player)
	await process_frame
	await physics_frame

	# Everything starts in the same mix block: the audio thread waits for the
	# lock while the players are started. A 3D player only hands its playback
	# to the server in its next physics frame, so the lock is held across two.
	var wall := Time.get_ticks_usec()
	AudioServer.lock()
	for capture in captures:
		capture.clear_buffer()
	for player in players:
		player.call(&"play")
	if positional:
		await physics_frame
		await physics_frame
	AudioServer.unlock()

	while data[0].size() < length:
		await process_frame
		AudioServer.lock()
		for i in captures.size():
			data[i].append_array(captures[i].get_buffer(captures[i].get_frames_available()))
		AudioServer.unlock()
	wall = Time.get_ticks_usec() - wall
	var lost := 0
	for capture in captures:
		lost += capture.get_discarded_frames()
	print("render_mix: %d frames at %d Hz (%.3f s of sound) in %.3f s; %d events; frames lost %d" % [
		length, int(rate), length / rate, wall / 1e6, players.size(), lost])

	for i in taps.size():
		var frames := data[i].slice(0, length)
		var path := out if i == 0 else "%s.%s.wav" % [out.trim_suffix(".wav"), taps[i]]
		var peak := Vector2.ZERO
		var peak_at := 0
		var over := 0
		var energy := Vector2.ZERO
		for j in frames.size():
			var f := frames[j].abs()
			if f.x > peak.x or f.y > peak.y:
				if maxf(f.x, f.y) > maxf(peak.x, peak.y):
					peak_at = j
				peak = peak.max(f)
			if f.x > 1.0 or f.y > 1.0:
				over += 1
			energy += f * f
		_write_wav(path, frames, int(rate), spec.get("float", false))
		print("  %-8s -> %s  peak L %.2f R %.2f dBFS at %.4f s; rms L %.2f R %.2f dBFS; frames over full scale %d" % [
			taps[i], path, _db(peak.x), _db(peak.y), peak_at / rate,
			_db(sqrt(energy.x / frames.size())), _db(sqrt(energy.y / frames.size())), over])
	# A playback that is still running when the engine quits is reported as a leak.
	for player in players:
		player.call(&"stop")
		player.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _db(linear: float) -> float:
	return 20.0 * log(linear) / log(10.0) if linear > 0.0 else -999.0


func _write_wav(path: String, frames: PackedVector2Array, rate: int, as_float: bool) -> void:
	var body: PackedByteArray
	if as_float:
		# A PackedVector2Array is already interleaved 32-bit float.
		body = frames.to_byte_array()
	else:
		body.resize(frames.size() * 4)
		for i in frames.size():
			body.encode_s16(i * 4, clampi(roundi(frames[i].x * 32767.0), -32768, 32767))
			body.encode_s16(i * 4 + 2, clampi(roundi(frames[i].y * 32767.0), -32768, 32767))
	var bytes := 4 if as_float else 2
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(36 + body.size())
	file.store_buffer("WAVEfmt ".to_ascii_buffer())
	file.store_32(16)
	file.store_16(3 if as_float else 1)
	file.store_16(2)
	file.store_32(rate)
	file.store_32(rate * 2 * bytes)
	file.store_16(2 * bytes)
	file.store_16(8 * bytes)
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(body.size())
	file.store_buffer(body)
	file.close()
