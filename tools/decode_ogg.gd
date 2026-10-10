extends SceneTree
## Decodes Ogg Vorbis files to 16-bit stereo WAV, for tools/build_sounds.py:
## macOS brings a converter for every other format, but not for this one.
## Arguments after `--` come in pairs: an .ogg to read and the .wav to write.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(0, args.size() - 1, 2):
		var stream := AudioStreamOggVorbis.load_from_file(args[i])
		if stream == null:
			push_error("cannot read " + args[i])
			quit(1)
			return
		var playback := stream.instantiate_playback()
		playback.start(0.0)
		var data := PackedByteArray()
		while playback.is_playing():
			var frames := playback.mix_audio(1.0, 4096)
			if frames.is_empty():
				break
			var at := data.size()
			data.resize(at + frames.size() * 4)
			for frame in frames:
				data.encode_s16(at, int(clampf(frame.x, -1.0, 1.0) * 32767.0))
				data.encode_s16(at + 2, int(clampf(frame.y, -1.0, 1.0) * 32767.0))
				at += 4
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.stereo = true
		wav.mix_rate = int(AudioServer.get_mix_rate())
		wav.data = data
		wav.save_to_wav(args[i + 1])
	quit()
