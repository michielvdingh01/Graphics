extends SceneTree
## Generates the procedural textures listed in assets/manifest.json (source
## "procedural"): decals into assets/decals/ and the noise masks that shaders
## scatter wear with into assets/masks/. Run with: tools/gen_decals.sh
##
## Each entry names a kind (leak, stain, grime, scorch, warning, text or hole
## for a decal, wear or grain for a mask), a size and a seed, so a texture can
## be regenerated or varied without touching this script. A text has a height
## only; its width follows from what it says. A grain names the pattern it is
## made of, and a hole the surface it is shot in; a hole comes with a normal
## map and more, see _hole().

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
			image = _grain(asset) if asset.kind == "grain" else _mask(asset)
		elif asset.kind == "text":
			image = _lettering(asset)
		elif asset.kind == "hole":
			_hole(asset, folder)
			print(asset.id)
			continue
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


## Tiling normal map of a surface seen from a hand's breadth away, which is
## how close the weapon in view is: the weave of cloth, the stipple of moulded
## plastic, the tooth of a blasted finish, the diamonds of a knurled grip.
## `count` is how many threads, bumps or diamonds fit across the texture.
func _grain(asset: Dictionary) -> Image:
	var size: int = asset.size[0]
	var count: float = asset.get("count", 32)
	var noise := FastNoiseLite.new()
	noise.seed = asset.seed
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR if asset.pattern == "stipple" else FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = count / size * (1.0 if asset.pattern == "stipple" else 2.0)
	noise.fractal_octaves = 3
	var field := noise.get_seamless_image(size, size, false, false, 0.25)
	var height := PackedFloat32Array()
	height.resize(size * size)
	for y in size:
		for x in size:
			var random := field.get_pixel(x, y).r
			var u := float(x) / size * count
			var v := float(y) / size * count
			var fu := fposmod(u, 1.0) - 0.5
			var fv := fposmod(v, 1.0) - 0.5
			var h := random
			match asset.pattern:
				"weave":
					# Plain weave: every thread goes over one and under the next.
					var over := (int(u) + int(v)) % 2 == 0
					var across := fu if over else fv
					var along := fv if over else fu
					h = sqrt(maxf(0.0, 1.0 - across * across * 4.0)) * (0.55 + 0.45 * cos(along * PI)) + random * 0.25
				"knurl":
					h = minf(1.0 - absf(fposmod(u + v, 1.0) * 2.0 - 1.0), 1.0 - absf(fposmod(u - v, 1.0) * 2.0 - 1.0))
				"stipple":
					h = smoothstep(0.25, 0.8, random)
			height[y * size + x] = h
	return _normals(height, size, asset.get("depth", 1.0) * size / 64.0)


## Normal map of a square height field, `steep` times as steep as the heights
## say. It tiles: a pixel on one edge slopes towards the opposite edge.
func _normals(height: PackedFloat32Array, size: int, steep: float) -> Image:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var dx := height[y * size + (x + 1) % size] - height[y * size + (x + size - 1) % size]
			var dy := height[((y + 1) % size) * size + x] - height[((y + size - 1) % size) * size + x]
			# Green points up the texture, which is down the image.
			var n := Vector3(-dx * steep, dy * steep, 1.0).normalized() * 0.5 + Vector3(0.5, 0.5, 0.5)
			image.set_pixel(x, y, Color(n.x, n.y, n.z))
	return image


## A bullet hole in one of the surfaces a shot can find. Next to the texture
## itself it writes a normal map of the dent (<id>_n) and what the bared
## material is like (<id>_orm: occlusion, roughness, metallic). A hole in
## metal also gets the glow of the heat that went into it (<id>_e).
func _hole(asset: Dictionary, folder: String) -> void:
	var size: int = asset.size[0]
	var noise := FastNoiseLite.new()
	noise.seed = asset.seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 4
	var albedo := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var orm := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var glow := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var height := PackedFloat32Array()
	height.resize(size * size)
	for y in size:
		for x in size:
			var uv := Vector2(x + 0.5, y + 0.5) / size
			var p := uv * 2.0 - Vector2.ONE
			var r := p.length()
			var around := p.normalized()
			# No hole is round: its outline has lumps, and finer teeth on those.
			var lumps := _n(noise, around.x * 140.0, around.y * 140.0)
			var teeth := _n(noise, around.x * 600.0 + 900.0, around.y * 600.0)
			var grit := _n(noise, uv.x * 5000.0, uv.y * 5000.0)
			var color := Color.BLACK
			var alpha := 0.0
			var h := 0.0
			var surface := Color(1.0, 0.9, 0.0)
			match asset.surface:
				"concrete":
					# A crater of freshly broken concrete, paler than the wall,
					# around the hole itself, and dust thrown out around that.
					var crater := 0.42 * (0.65 + 0.7 * lumps) * (0.9 + 0.2 * teeth)
					var bore := 0.12 * (0.8 + 0.4 * teeth)
					var inside := smoothstep(crater, crater * 0.82, r)
					var deep := smoothstep(bore * 1.7, bore * 0.6, r)
					var dust := smoothstep(crater * 2.1, crater, r) * (0.2 + 0.3 * grit)
					color = Color(0.66, 0.64, 0.6).lerp(Color(0.44, 0.43, 0.41), grit).lerp(Color(0.07, 0.07, 0.07), deep * 0.9)
					color = Color(0.7, 0.68, 0.64).lerp(color, inside)
					alpha = maxf(inside * 0.96, dust)
					h = -inside * (0.3 + 0.7 * smoothstep(crater, bore, r)) - deep * 0.5 + (grit - 0.5) * 0.25 * inside
					surface = Color(1.0 - 0.6 * deep, 0.95, 0.0)
				"metal":
					# Punched through: the paint has flaked off around the hole
					# down to bright steel, and soot lies around that.
					var bore := 0.19 * (0.85 + 0.3 * teeth)
					var ring := bore + 0.17 * (0.4 + lumps) * (0.8 + 0.4 * teeth)
					var hole := smoothstep(bore, bore * 0.8, r)
					var bare := smoothstep(ring, ring * 0.9, r) * (1.0 - hole)
					var soot := smoothstep(0.95, ring, r) * (0.3 + 0.35 * grit) * (1.0 - bare) * (1.0 - hole)
					var scratched := 0.7 + 0.6 * _n(noise, around.x * 2500.0, around.y * 2500.0)
					color = Color(0.03, 0.028, 0.025).lerp(Color(0.6, 0.6, 0.62) * scratched, bare).lerp(Color(0.012, 0.012, 0.012), hole)
					alpha = maxf(maxf(hole, bare * 0.96), soot)
					var lip := exp(-pow((r - bore * 1.25) / 0.05, 2.0))
					h = -0.5 * smoothstep(0.85, bore, r) - 0.8 * hole + 0.35 * lip
					surface = Color(1.0 - 0.7 * hole, lerpf(0.85, 0.32, bare), bare)
					var heat := smoothstep(ring * 1.3, bore * 0.9, r) * (1.0 - 0.7 * hole)
					glow.set_pixel(x, y, Color(1.0, 0.32, 0.06) * heat)
				"wood":
					# Torn along the grain, which runs up the texture: splinters
					# of pale fresh wood around a hole that is longer than wide.
					var fibre := _n(noise, uv.x * 9000.0, uv.y * 320.0)
					var across := Vector2(p.x * 1.9, p.y).length()
					var torn := 0.55 * (0.45 + 1.0 * fibre)
					var bore := 0.17
					var inside := smoothstep(torn, torn * 0.7, across)
					var deep := smoothstep(bore * 1.5, bore * 0.7, across)
					color = Color(0.78, 0.63, 0.42).lerp(Color(0.5, 0.36, 0.2), fibre).lerp(Color(0.04, 0.03, 0.02), deep)
					alpha = inside * 0.96
					h = -inside * (0.3 + 0.5 * deep) + (fibre - 0.5) * 0.5 * inside
					surface = Color(1.0 - 0.6 * deep, 0.8, 0.0)
				"soft":
					# A bag, a tyre, a cardboard box: a small dark hole and a scuff.
					var bore := 0.28 * (0.75 + 0.5 * teeth)
					var hole := smoothstep(bore, bore * 0.7, r)
					color = Color(0.02, 0.02, 0.02)
					alpha = maxf(hole * 0.96, smoothstep(0.85, bore, r) * 0.4 * grit)
					h = -hole
			# Nothing may reach the edge of the texture.
			alpha *= smoothstep(1.0, 0.85, r)
			albedo.set_pixel(x, y, Color(color, alpha))
			orm.set_pixel(x, y, surface)
			height[y * size + x] = h
	albedo.generate_mipmaps()
	albedo.save_png(folder + asset.id + ".png")
	_normals(height, size, asset.get("depth", 1.0) * size / 24.0).save_png(folder + asset.id + "_n.png")
	orm.save_png(folder + asset.id + "_orm.png")
	if asset.surface == "metal":
		glow.save_png(folder + asset.id + "_e.png")


## Stencilled lettering in white, for a decal to tint. Letters with a closed
## counter get the bridges that hold a stencil together, and the paint has
## gone thin in patches. Set in the engine's own font, so it needs no asset.
func _lettering(asset: Dictionary) -> Image:
	var font := ThemeDB.fallback_font as FontFile
	var height: int = asset.height
	var size := Vector2i(height, 0)
	var text: String = asset.text
	var glyphs: Array[int] = []
	var width := height * 0.3
	for i in text.length():
		glyphs.append(font.get_glyph_index(height, text.unicode_at(i), 0))
		font.render_glyph(0, size, glyphs[i])
		width += font.get_glyph_advance(0, height, glyphs[i]).x
	var image := Image.create_empty(ceili(width), height, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	var noise := FastNoiseLite.new()
	noise.seed = asset.seed
	noise.fractal_octaves = 4
	# Capitals are 0.71 of the size high; they stand in the middle.
	var pen := Vector2(height * 0.15, height * 0.855)
	for i in glyphs.size():
		# A space has an advance and nothing to draw.
		var page := font.get_glyph_texture_idx(0, size, glyphs[i])
		var rect := font.get_glyph_uv_rect(0, size, glyphs[i]) if page >= 0 else Rect2()
		var atlas := font.get_texture_image(0, size, page) if page >= 0 else null
		var corner := pen + font.get_glyph_offset(0, size, glyphs[i])
		var bridge := "ABDOPQR04689".contains(text[i])
		for y in int(rect.size.y):
			for x in int(rect.size.x):
				var at := Vector2i(corner) + Vector2i(x, y)
				if at.x < 0 or at.y < 0 or at.x >= image.get_width() or at.y >= height:
					continue
				if bridge and absf(x - rect.size.x * 0.5) < height * 0.035:
					continue
				var ink := atlas.get_pixel(int(rect.position.x) + x, int(rect.position.y) + y).a
				var worn := smoothstep(0.28, 0.6, _n(noise, at.x * 450.0 / height, at.y * 450.0 / height)) * (0.88 + 0.12 * _n(noise, at.x * 6000.0 / height, at.y * 6000.0 / height))
				image.set_pixel(at.x, at.y, Color(1, 1, 1, ink * worn))
		pen.x += font.get_glyph_advance(0, height, glyphs[i]).x
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


## Warning sign: a yellow triangle with a black border and an exclamation
## mark, scuffed where it has been brushed past.
func _warning(uv: Vector2, noise: FastNoiseLite) -> Color:
	# Distance to an equilateral triangle, point up, with rounded corners.
	var p := Vector2(uv.x - 0.5, 0.6 - uv.y)
	var half := 0.4
	var q := Vector2(absf(p.x) - half, p.y + half / sqrt(3.0))
	if q.x + sqrt(3.0) * q.y > 0.0:
		q = Vector2(q.x - sqrt(3.0) * q.y, -sqrt(3.0) * q.x - q.y) * 0.5
	q.x -= clampf(q.x, -2.0 * half, 0.0)
	var distance := -q.length() * signf(q.y) - 0.03
	var mark := (absf(p.x) < 0.03 + 0.06 * (p.y + 0.02) and p.y > -0.02 and p.y < 0.3) or p.distance_to(Vector2(0, -0.12)) < 0.042
	var black := distance > -0.065 or mark
	var color := Color(0.04, 0.04, 0.04) if black else Color(0.85, 0.6, 0.04)
	var scuffed := smoothstep(0.1, 0.3, _n(noise, uv.x * 900.0, uv.y * 900.0)) * (0.85 + 0.15 * _n(noise, uv.x * 9000.0, uv.y * 9000.0))
	return Color(color, smoothstep(0.0, -0.012, distance) * scuffed)


## Soot burnt onto a floor where something blew up: black in the middle,
## with rays of unequal length around it.
func _scorch(uv: Vector2, noise: FastNoiseLite) -> Color:
	var p := uv * 2.0 - Vector2.ONE
	var r := p.length()
	var around := p.normalized()
	var reach := 0.4 + 0.55 * _n(noise, around.x * 300.0, around.y * 300.0)
	var body := smoothstep(reach, reach * 0.3, r)
	var core := smoothstep(0.4, 0.0, r)
	var breakup := 0.55 + 0.45 * _n(noise, uv.x * 3000.0, uv.y * 3000.0)
	return Color(0.02, 0.018, 0.016, (0.55 * body + 0.35 * core) * breakup * smoothstep(1.0, 0.85, r))


## Dirt that has built up along the bottom edge.
func _grime(uv: Vector2, noise: FastNoiseLite) -> Color:
	var level := 0.25 + 0.5 * _n(noise, uv.x * 500.0, 0.0)
	var build_up := smoothstep(level, 1.0, uv.y)
	var breakup := 0.5 + 0.5 * _n(noise, uv.x * 4000.0, uv.y * 1000.0)
	var ends := smoothstep(0.0, 0.08, uv.x) * smoothstep(1.0, 0.92, uv.x)
	return Color(0.07, 0.06, 0.05, build_up * breakup * ends * 0.75)
