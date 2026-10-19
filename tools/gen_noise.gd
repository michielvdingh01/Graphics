extends SceneTree
## Writes the noise the ground of the Alps reads (shaders/alps_ground.gdshader,
## fbm()): four octaves of value noise that tile, 256 by 256, a cell of the
## first octave four dots across, into assets/noise/alps_fbm.png. Run with:
##   Godot --headless --path . --script tools/gen_noise.gd
## and once more with --import for the editor to take it.

const OUT := "res://assets/noise/alps_fbm.png"


func _initialize() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 7151
	noise.noise_type = FastNoiseLite.TYPE_VALUE
	noise.frequency = 0.25
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	var image := noise.get_seamless_image(256, 256, false, false, 0.1, false)
	image.convert(Image.FORMAT_L8)
	image.save_png(OUT)
	print("Noise: %s" % OUT)
	quit()
