extends SceneTree
## Generates the procedural textures listed in assets/manifest.json (source
## "procedural"): decals into assets/decals/ and the noise masks that shaders
## scatter wear with into assets/masks/. Run with: tools/gen_decals.sh
##
## Each entry names a kind (leak, stain or grime for a decal, wear for a
## mask), a size and a seed, so a texture can be regenerated or varied without
## touching this script.

const OUT_DIR := {"decal": "res://assets/decals/", "mask": "res://assets/masks/"}


func _init() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/manifest.json"))
	for asset: Dictionary in manifest.assets:
		if asset.source != "procedural":
			continue
		var folder: String = OUT_DIR[asset.type]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		var image: Image
		if asset.type == "mask":
			image = _mask(asset)
		else:
			image = Image.create_empty(asset.size[0], asset.size[1], true, Image.FORMAT_RGBA8)
			var noise := FastNoiseLite.new()
			noise.seed = asset.seed
			noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			noise.fractal_octaves = 4
			for y in image.get_height():
				for x in image.get_width():
					var uv := Vector2(x + 0.5, y + 0.5) / Vector2(image.get_size())
					image.set_pixel(x, y, call("_" + asset.kind, uv, noise))
			image.generate_mipmaps()
		image.save_png(folder + asset.id + ".png")
		print(asset.id)
	quit()


## Three unrelated noises that tile, one per channel: soft blotches in red and
## blue, and in green the finer cells that break up an outline.
func _mask(asset: Dictionary) -> Image:
	var width: int = asset.size[0]
	var height: int = asset.size[1]
	var channels: Array[Image] = []
	for i in 3:
		var noise := FastNoiseLite.new()
		noise.seed = asset.seed + i * 17
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR if i == 1 else FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.035 if i == 1 else 0.011
		noise.fractal_octaves = 5
		noise.fractal_gain = 0.55
		channels.append(noise.get_seamless_image(width, height, false, false, 0.25))
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGB8)
	for y in height:
		for x in width:
			image.set_pixel(x, y, Color(channels[0].get_pixel(x, y).r, channels[1].get_pixel(x, y).r, channels[2].get_pixel(x, y).r))
	return image


## Noise in 0..1.
func _n(noise: FastNoiseLite, x: float, y: float) -> float:
	return noise.get_noise_2d(x, y) * 0.5 + 0.5


## Water streaks running down from the top edge.
func _leak(uv: Vector2, noise: FastNoiseLite) -> Color:
	# Every column is its own streak with its own strength and length.
	var streak := smoothstep(0.35, 0.8, _n(noise, uv.x * 900.0, 0.0))
	var length := 0.35 + 0.65 * _n(noise, uv.x * 500.0, 77.0)
	var run := smoothstep(length, length * 0.2, uv.y)
	var breakup := 0.6 + 0.4 * _n(noise, uv.x * 1400.0, uv.y * 250.0)
	var sides := smoothstep(0.0, 0.25, uv.x) * smoothstep(1.0, 0.75, uv.x)
	var top := smoothstep(0.0, 0.03, uv.y)
	var rust := _n(noise, uv.x * 300.0, 300.0)
	var color := Color(0.1, 0.08, 0.06).lerp(Color(0.32, 0.15, 0.05), smoothstep(0.55, 0.8, rust))
	return Color(color, streak * run * breakup * sides * top * 0.8)


## Irregular oil stain with a darker core.
func _stain(uv: Vector2, noise: FastNoiseLite) -> Color:
	var p := uv - Vector2(0.5, 0.5)
	var distance := p.length() + (_n(noise, uv.x * 500.0, uv.y * 500.0) - 0.5) * 0.3
	var body := smoothstep(0.4, 0.22, distance)
	var core := smoothstep(0.25, 0.05, distance)
	var breakup := 0.55 + 0.45 * _n(noise, uv.x * 2500.0, uv.y * 2500.0)
	# The noise must never push the stain out to the edge of the texture.
	var edge := smoothstep(0.5, 0.42, p.length())
	return Color(0.03, 0.03, 0.035, (0.45 * body + 0.4 * core) * breakup * edge)


## Dirt that has built up along the bottom edge.
func _grime(uv: Vector2, noise: FastNoiseLite) -> Color:
	var level := 0.25 + 0.5 * _n(noise, uv.x * 500.0, 0.0)
	var build_up := smoothstep(level, 1.0, uv.y)
	var breakup := 0.5 + 0.5 * _n(noise, uv.x * 4000.0, uv.y * 1000.0)
	var ends := smoothstep(0.0, 0.08, uv.x) * smoothstep(1.0, 0.92, uv.x)
	return Color(0.07, 0.06, 0.05, build_up * breakup * ends * 0.75)
