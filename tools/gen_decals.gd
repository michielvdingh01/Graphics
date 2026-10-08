extends SceneTree
## Generates the procedural decal textures listed in assets/manifest.json
## (source "procedural") into assets/decals/. Run with: tools/gen_decals.sh
##
## Each entry names a kind (leak, stain or grime), a size and a seed, so a
## decal can be regenerated or varied without touching this script.

const OUT_DIR := "res://assets/decals/"


func _init() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/manifest.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for asset: Dictionary in manifest.assets:
		if asset.source != "procedural" or asset.type != "decal":
			continue
		var image := Image.create_empty(asset.size[0], asset.size[1], true, Image.FORMAT_RGBA8)
		var noise := FastNoiseLite.new()
		noise.seed = asset.seed
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.fractal_octaves = 4
		for y in image.get_height():
			for x in image.get_width():
				var uv := Vector2(x + 0.5, y + 0.5) / Vector2(image.get_size())
				image.set_pixel(x, y, call("_" + asset.kind, uv, noise))
		image.generate_mipmaps()
		image.save_png(OUT_DIR + asset.id + ".png")
		print(asset.id)
	quit()


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
