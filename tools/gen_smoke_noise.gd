extends SceneTree
## Writes the noise the cloud of a smoke grenade is read from
## (shaders/smoke_cloud.gdshader), 64 dots each way and tiling, into
## assets/noise/smoke.res: an image with its 64 slices one under the other,
## which scripts/fx.gd stacks into a texture. Saved as a texture it would come
## out empty, as a run without a GPU cannot read one back. In red the billows:
## round cells with a little of something softer through them. In green the
## fine grain that frays their edges. Run with:
##   Godot --headless --path . --script tools/gen_smoke_noise.gd

const OUT := "res://assets/noise/smoke.res"
const SIZE := 64
## How much of the softer noise goes through the cells.
const SOFT := 0.35


func _initialize() -> void:
	var cells := _noise(FastNoiseLite.TYPE_CELLULAR, 0.09, 3, 7151).get_seamless_image_3d(SIZE, SIZE, SIZE, true, 0.15)
	var soft := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.05, 3, 802).get_seamless_image_3d(SIZE, SIZE, SIZE, false, 0.15)
	var fine := _noise(FastNoiseLite.TYPE_CELLULAR, 0.24, 2, 311).get_seamless_image_3d(SIZE, SIZE, SIZE, true, 0.15)
	var sheet := Image.create_empty(SIZE, SIZE * SIZE, false, Image.FORMAT_RG8)
	for z in SIZE:
		for y in SIZE:
			for x in SIZE:
				var billow := lerpf(cells[z].get_pixel(x, y).r, soft[z].get_pixel(x, y).r, SOFT)
				sheet.set_pixel(x, z * SIZE + y, Color(billow, fine[z].get_pixel(x, y).r, 0.0))
	var error := ResourceSaver.save(sheet, OUT, ResourceSaver.FLAG_COMPRESS)
	print("Noise: %s (%s)" % [OUT, error_string(error)])
	quit()


func _noise(kind: FastNoiseLite.NoiseType, frequency: float, octaves: int, seed_number: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_number
	noise.noise_type = kind
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	return noise
