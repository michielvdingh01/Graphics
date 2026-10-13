extends SceneTree
## Draws the textures of what grows, and of what is knotted and woven, that
## assets/manifest.json lists with source "drawn": into assets/foliage/. Each
## is a picture with holes in it, for a card of leaves, a net or a fence. Run
## with: tools/gen_foliage.sh
##
## An entry names a kind, a size and a seed:
##
##   needles    the twigs at the end of a pine's branch, seen from above
##   grass      a tuft of marram, blades fanning up from the foot of the card
##   leaves     a spray of thorn scrub, narrow leaves and a few berries
##   net        a camouflage net: cord with scrim knotted into it; it tiles
##   concertina one turn of a coil of barbed wire, and two strands of it
##   stencils   a sheet of what an army paints on its vehicles
##   chainlink  wire mesh; it tiles
##   treeline   the edge of a pine wood from afar; it tiles from left to right
##   ruts       the two ruts of a track; it tiles from top to bottom
##
## Nothing here is scanned: where a card is seen from close by it shows. The
## cards are for crowns ten metres up and for what stands a stone's throw off.

const OUT_DIR := "res://assets/foliage/"
## What the importer is told of every texture here: compressed for the video
## card and with mipmaps, as the scanned textures are. The decals are not,
## but a decal is not a crown seen from two hundred metres.
const IMPORT := "[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[params]\n\ncompress/mode=2\ncompress/high_quality=true\nmipmaps/generate=true\nprocess/fix_alpha_border=true\ndetect_3d/compress_to=0\n"

var _rng := RandomNumberGenerator.new()
var _image: Image


func _init() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/manifest.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var only := OS.get_cmdline_user_args()
	for asset: Dictionary in manifest.assets:
		if asset.source != "drawn" or (not only.is_empty() and asset.id not in only):
			continue
		_rng.seed = asset.seed
		_image = Image.create_empty(asset.size[0], asset.size[1], false, Image.FORMAT_RGBA8)
		_image.fill(Color(0, 0, 0, 0))
		call("_" + asset.kind)
		_image.save_png(OUT_DIR + asset.id + ".png")
		var settings: String = OUT_DIR + asset.id + ".png.import"
		if not FileAccess.file_exists(settings):
			var file := FileAccess.open(settings, FileAccess.WRITE)
			file.store_string(IMPORT)
		print(asset.id)
	quit()


# --- What is drawn -----------------------------------------------------------------


## The twigs at the end of a branch of a pine: each a short shoot with needles
## standing off it all the way along, darker ones underneath and lighter on
## top, thick enough in the middle to stay a mass from far off.
func _needles() -> void:
	var size := float(_image.get_width())
	var middle := Vector2.ONE * size * 0.5
	var twigs := 340
	for i in twigs:
		var depth := float(i) / twigs
		var out := Vector2.RIGHT.rotated(_rng.randf() * TAU)
		var foot := middle + out * size * 0.4 * sqrt(_rng.randf())
		var way := out.rotated(_rng.randf_range(-1.0, 1.0))
		var length := size * _rng.randf_range(0.06, 0.1)
		var tip := foot + way * length
		if tip.distance_to(middle) > size * 0.47:
			continue
		var dark := Color(0.028, 0.07, 0.034).lerp(Color(0.06, 0.13, 0.05), depth)
		var light := Color(0.075, 0.15, 0.06).lerp(Color(0.17, 0.28, 0.11), depth)
		_stroke(foot, tip, size * 0.005, Color(0.15, 0.1, 0.06).lerp(Color(0.22, 0.16, 0.09), depth))
		var count := int(length / (size * 0.0042))
		for n in count:
			var along := float(n) / count
			var from := foot.lerp(tip, along)
			for side: float in [-1.0, 1.0]:
				var lean := _rng.randf_range(0.45, 1.0) * side * (1.0 - along * 0.5)
				var reach := size * _rng.randf_range(0.028, 0.045) * (0.75 + 0.25 * along)
				_stroke(from, from + way.rotated(lean) * reach, size * 0.003, dark.lerp(light, _rng.randf()))
		# The bud the shoot ends in, with the needles that stand round it.
		for n in 7:
			_stroke(tip, tip + way.rotated(_rng.randf_range(-0.7, 0.7)) * size * _rng.randf_range(0.025, 0.04), size * 0.003, light.lerp(Color(0.27, 0.37, 0.15), _rng.randf() * 0.5))


## A tuft of marram: stiff pale blades that rise from one foot and bend over
## at the top, the outer ones lying almost flat.
func _grass() -> void:
	var wide := float(_image.get_width())
	var high := float(_image.get_height())
	for i in 110:
		var spread := _rng.randf_range(-1.0, 1.0)
		var foot := Vector2(wide * (0.5 + spread * 0.13), high)
		var rise := high * _rng.randf_range(0.45, 0.97) * (1.0 - absf(spread) * 0.35)
		var lean := spread * _rng.randf_range(0.35, 1.0) + _rng.randf_range(-0.15, 0.15)
		var knee := foot + Vector2(lean * wide * 0.12, -rise * 0.6)
		var tip := foot + Vector2(lean * wide * _rng.randf_range(0.3, 0.46), -rise * _rng.randf_range(0.75, 1.0))
		var straw := Color(0.5, 0.47, 0.27).lerp(Color(0.31, 0.37, 0.2), _rng.randf())
		straw = straw.darkened(_rng.randf() * 0.35)
		var before := foot
		for step in range(1, 9):
			var t := step / 8.0
			var at := foot.lerp(knee, t).lerp(knee.lerp(tip, t), t)
			_stroke(before, at, wide * lerpf(0.016, 0.006, t), straw.lightened(t * 0.25))
			before = at


## A spray of thorn scrub: thin grey twigs with narrow leaves two by two, and
## here and there a cluster of orange berries against the twig.
func _leaves() -> void:
	var size := float(_image.get_width())
	var middle := Vector2.ONE * size * 0.5
	for i in 46:
		var depth := i / 46.0
		var out := Vector2.RIGHT.rotated(_rng.randf() * TAU)
		var foot := middle + out * size * 0.2 * sqrt(_rng.randf())
		var way := out.rotated(_rng.randf_range(-0.7, 0.7))
		var length := size * _rng.randf_range(0.16, 0.26)
		if (foot + way * length).distance_to(middle) > size * 0.46:
			continue
		_stroke(foot, foot + way * length, size * 0.005, Color(0.2, 0.18, 0.14))
		var berries := _rng.randf() < 0.3
		var count := int(length / (size * 0.019))
		for n in count:
			var along := (n + 0.5) / count
			var from := foot + way * length * along
			for side: float in [-1.0, 1.0]:
				var turn := way.rotated(side * _rng.randf_range(0.5, 1.1))
				var leaf := Color(0.13, 0.19, 0.1).lerp(Color(0.33, 0.4, 0.27), depth * 0.6 + _rng.randf() * 0.4)
				_blade(from + turn * size * 0.03, turn, size * _rng.randf_range(0.024, 0.034), size * 0.0075, leaf)
			if berries and n % 2 == 0:
				for b in 3:
					_blade(from + Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * size * 0.012, Vector2.RIGHT, size * 0.008, size * 0.008, Color(0.82, 0.38, 0.05).darkened(_rng.randf() * 0.3))


## A camouflage net: a mesh of knotted cord, garnished with strips of scrim
## that were threaded through it by hand, a foot or so long and every one a
## little different. The strips lie in drifts of one colour, the way the
## pattern was laid out, and leave holes where the garnish has thinned. Two
## metres of net; it tiles.
func _net() -> void:
	var size := _image.get_width()
	var unit := size / 1024.0
	var shades := _tiling(0.006 / unit, 1)
	var holes := _tiling(0.011 / unit, 3)
	var sway := _tiling(0.02 / unit, 5)
	# The cord: a square mesh, pulled a little out of true.
	var mesh := size / 16.0
	for y in size:
		for x in size:
			var pull := (sway.get_pixel(x, y).r - 0.5) * 9.0 * unit
			var off := minf(absf(fposmod(x + pull + mesh * 0.5, mesh) - mesh * 0.5), absf(fposmod(y - pull + mesh * 0.5, mesh) - mesh * 0.5))
			var cover := clampf(1.9 * unit - off, 0.0, 1.0)
			if cover > 0.0:
				_image.set_pixel(x, y, Color(0.2, 0.17, 0.12, cover))
	var scrim: Array[Color] = [Color(0.08, 0.1, 0.055), Color(0.14, 0.17, 0.085), Color(0.23, 0.185, 0.115), Color(0.18, 0.2, 0.1), Color(0.33, 0.29, 0.19)]
	for i in 1150:
		var middle := Vector2(_rng.randf(), _rng.randf()) * size
		var thin := holes.get_pixelv(Vector2i(middle)).r
		if thin < 0.5 and _rng.randf() > (thin - 0.24) * 1.5:
			continue
		var drift := shades.get_pixelv(Vector2i(middle)).r
		var tone := scrim[clampi(int((drift - 0.22) / 0.56 * 5.0 + _rng.randf_range(-0.7, 0.7)), 0, 4)]
		tone = tone.darkened(_rng.randf() * 0.3).lightened(_rng.randf() * 0.08)
		var way := Vector2.RIGHT.rotated(_rng.randf() * PI)
		var length := _rng.randf_range(70.0, 170.0) * unit
		var width := _rng.randf_range(16.0, 30.0) * unit
		var bend := _rng.randf_range(-0.6, 0.6)
		var spots: Array[Vector2] = []
		for step in 6:
			var t := step / 5.0
			spots.append(middle + way.rotated(bend * (t - 0.5)) * length * (t - 0.5))
		# Dark along its edges, where it curls, and narrow at its ends, where
		# it is knotted in.
		for coat: Array in [[1.0, tone.darkened(0.22)], [0.8, tone], [0.3, tone.lightened(0.06)]]:
			for step in 5:
				var pinch := 1.0 - 0.5 * absf((step + 0.5) / 5.0 - 0.5) * 2.0
				_stroke_tiled(spots[step], spots[step + 1], width * pinch * (coat[0] as float), coat[1])


## A stroke in an image that tiles both ways.
func _stroke_tiled(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	var size := Vector2(_image.get_size())
	var low := from.min(to) - Vector2.ONE * (width + 2.0)
	var high := from.max(to) + Vector2.ONE * (width + 2.0)
	for shift_y: float in [-1.0, 0.0, 1.0]:
		for shift_x: float in [-1.0, 0.0, 1.0]:
			var off := Vector2(shift_x, shift_y) * size
			if high.x + off.x < 0.0 or high.y + off.y < 0.0 or low.x + off.x > size.x or low.y + off.y > size.y:
				continue
			_stroke(from + off, to + off, width, color)


## Concertina wire: one turn of the coil seen along it, a hoop of spring
## steel with a barb every hand's breadth, in the left half of the picture;
## and in the right half two strands of barbed wire, for a ribbon. Galvanised
## and gone dull, rusting where the zinc has gone. A level stands a card of
## the hoop for every turn of a coil: see wire_coil() in tools/kit/field.gd.
func _concertina() -> void:
	var size := float(_image.get_height())
	var thick := size * 0.0062
	var rust := _tiling(0.02, 2)
	var middle := Vector2(size, size) * 0.5
	var before := Vector2.ZERO
	var run := 0.0
	for step in 181:
		var turn := TAU * step / 180.0
		# Pulled out of the round where it was clipped to the turns beside it.
		var at := middle + Vector2.RIGHT.rotated(turn) * size * (0.455 + 0.012 * sin(turn * 5.0) + 0.006 * sin(turn * 2.0 + 1.0))
		if step > 0:
			run = _wire(before, at, thick, rust, run, size * 0.09)
		before = at
	for strand in 2:
		var y := size * (0.25 + 0.5 * strand)
		run = 0.0
		for step in 32:
			run = _wire(Vector2(size + size * step / 32.0, y), Vector2(size + size * (step + 1) / 32.0, y), thick, rust, run, size * 0.1)


## A piece of barbed wire from `from` to `to`, `run` along the strand it is
## part of, with a barb every `apart`: two short points wound round it.
## Returns how far along the strand it ends.
func _wire(from: Vector2, to: Vector2, thick: float, rust: Image, run: float, apart: float) -> float:
	var worn := rust.get_pixelv(Vector2i(to.posmodv(Vector2(rust.get_size())))).r
	var steel := Color(0.52, 0.52, 0.5).lerp(Color(0.3, 0.2, 0.13), smoothstep(0.5, 0.75, worn)).darkened(_rng.randf() * 0.12)
	_stroke(from, to, thick, steel.darkened(0.3))
	_stroke(from, to, thick * 0.5, steel.lightened(0.25))
	var length := from.distance_to(to)
	if int((run + length) / apart) > int(run / apart):
		var way := (to - from).normalized()
		for lean: float in [0.9, -1.1]:
			var point := way.rotated(lean + _rng.randf_range(-0.2, 0.2)) * thick * _rng.randf_range(2.6, 3.4)
			_stroke(to - point, to + point, thick * 0.6, steel.lightened(0.1))
	return run + length


## What an army paints on what it drives, sixteen marks on a sheet of four by
## four (tools/models/vehicles.gd knows which is where): in the top row a
## white star and three bridge plates, yellow discs with the weight in tons;
## under them two turret numbers, a tactical sign and an arrow; and in the
## lower half eight lines of stencilled lettering, two to a square. All of it
## was sprayed through a stencil once and has been rubbed since.
func _stencils() -> void:
	var cell := _image.get_width() / 4
	var white := Color(0.82, 0.81, 0.76)
	var yellow := Color(0.78, 0.6, 0.08)
	var black := Color(0.04, 0.04, 0.04)
	# The star: five points, a fifth of a turn apart.
	var middle := Vector2(cell, cell) * 0.5
	var star := PackedVector2Array()
	for i in 10:
		star.append(middle + Vector2.UP.rotated(TAU * i / 10.0) * cell * (0.46 if i % 2 == 0 else 0.176))
	_fill_shape(star, white)
	var tons: Array[String] = ["5", "12", "50"]
	for i in 3:
		var at := Vector2((i + 1.5) * cell, cell * 0.5)
		var disc := PackedVector2Array()
		for step in 48:
			disc.append(at + Vector2.RIGHT.rotated(TAU * step / 48.0) * cell * 0.44)
		_fill_shape(disc, yellow)
		_write(tons[i], Rect2(at - Vector2(cell, cell) * 0.33, Vector2(cell, cell) * 0.66), black)
	_write("14", Rect2(0, cell, cell, cell).grow(-cell * 0.06), white)
	_write("23", Rect2(cell, cell, cell, cell).grow(-cell * 0.06), white)
	# A tactical sign: a square halved from corner to corner, red over white.
	var sign := Rect2(cell * 2, cell, cell, cell).grow(-cell * 0.12)
	_fill_shape(PackedVector2Array([sign.position, Vector2(sign.end.x, sign.position.y), sign.end, Vector2(sign.position.x, sign.end.y)]), white)
	_fill_shape(PackedVector2Array([sign.position, Vector2(sign.end.x, sign.position.y), Vector2(sign.position.x, sign.end.y)]), Color(0.5, 0.07, 0.05))
	_write("3", Rect2(sign.position + sign.size * 0.5, sign.size * 0.46), black)
	var arrow := Rect2(cell * 3, cell, cell, cell).grow(-cell * 0.15)
	_fill_shape(PackedVector2Array([Vector2(arrow.position.x, arrow.end.y), Vector2(arrow.get_center().x, arrow.position.y), arrow.end, Vector2(arrow.get_center().x, arrow.end.y - arrow.size.y * 0.3)]), white)
	var lines: Array[String] = ["KN-45-12", "KN-45-27", "KP-63-08", "KZ-07-31", "TP 2.1", "MAX 60 KM", "NO STEP", "BENZINE"]
	for i in lines.size():
		@warning_ignore("integer_division")
		_write(lines[i], Rect2((i % 2) * cell * 2, cell * 2 + (i / 2) * cell * 0.5, cell * 2, cell * 0.5).grow(-cell * 0.04), white)
	# Rubbed, and thin where the stencil was lifted too soon.
	var worn := _tiling(0.012, 1)
	var speck := _tiling(0.12, 2)
	for y in _image.get_height():
		for x in _image.get_width():
			var ink := _image.get_pixel(x, y)
			if ink.a > 0.0:
				ink.a *= smoothstep(0.26, 0.5, worn.get_pixel(x, y).r) * (0.82 + 0.18 * speck.get_pixel(x, y).r)
				_image.set_pixel(x, y, ink)


## Fills a shape with `color`: any outline that does not cross itself.
func _fill_shape(outline: PackedVector2Array, color: Color) -> void:
	var low := outline[0]
	var high := outline[0]
	for corner in outline:
		low = low.min(corner)
		high = high.max(corner)
	for y in range(int(low.y), int(high.y) + 1):
		for x in range(int(low.x), int(high.x) + 1):
			# Four looks to a dot, for an edge that is not a staircase.
			var cover := 0.0
			for sub: Vector2 in [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.25, 0.75), Vector2(0.75, 0.75)]:
				if Geometry2D.is_point_in_polygon(Vector2(x, y) + sub, outline):
					cover += 0.25
			_dab(x, y, color, cover)


## Stencilled lettering that fills `area` as far as its shape lets it: the
## letters of the engine's own font, with the bridges a stencil needs to hold
## the middle of an O in place. See _lettering() in tools/gen_decals.gd.
func _write(text: String, area: Rect2, color: Color) -> void:
	var font := ThemeDB.fallback_font as FontFile
	var height := int(area.size.y / 0.78)
	var size := Vector2i(height, 0)
	var glyphs: Array[int] = []
	var width := 0.0
	for i in text.length():
		glyphs.append(font.get_glyph_index(height, text.unicode_at(i), 0))
		font.render_glyph(0, size, glyphs[i])
		width += font.get_glyph_advance(0, height, glyphs[i]).x
	if width > area.size.x:
		# Too long for its square at this height: smaller, then.
		_write(text, Rect2(area.position + Vector2(0, area.size.y * (1.0 - area.size.x / width) * 0.5), Vector2(area.size.x, area.size.y * area.size.x / width)), color)
		return
	var pen := Vector2(area.position.x + (area.size.x - width) * 0.5, area.position.y + area.size.y * 0.5 + height * 0.355)
	for i in glyphs.size():
		var page := font.get_glyph_texture_idx(0, size, glyphs[i])
		if page >= 0:
			var rect := font.get_glyph_uv_rect(0, size, glyphs[i])
			var atlas := font.get_texture_image(0, size, page)
			var corner := Vector2i(pen + font.get_glyph_offset(0, size, glyphs[i]))
			var bridge := "ABDOPQR04689".contains(text[i])
			for y in int(rect.size.y):
				for x in int(rect.size.x):
					var at := corner + Vector2i(x, y)
					if at.x < 0 or at.y < 0 or at.x >= _image.get_width() or at.y >= _image.get_height():
						continue
					if bridge and absf(x - rect.size.x * 0.5) < height * 0.035:
						continue
					_dab(at.x, at.y, color, atlas.get_pixel(int(rect.position.x) + x, int(rect.position.y) + y).a)
		pen.x += font.get_glyph_advance(0, height, glyphs[i]).x


# --- What it is drawn with ---------------------------------------------------------


## A noise that tiles over the image, one value a dot in red.
func _tiling(frequency: float, salt: int) -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = _rng.seed + salt * 31
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = 4
	return noise.get_seamless_image(_image.get_width(), _image.get_height(), false, false, 0.25)


## A line `width` thick from `from` to `to`, laid over what is there.
func _stroke(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	var half := maxf(width * 0.5, 0.5)
	var along := to - from
	var length_squared := maxf(along.length_squared(), 0.0001)
	var wide := _image.get_width()
	var high := _image.get_height()
	for y in range(maxi(int(minf(from.y, to.y) - half - 1.0), 0), mini(int(maxf(from.y, to.y) + half + 2.0), high)):
		for x in range(maxi(int(minf(from.x, to.x) - half - 1.0), 0), mini(int(maxf(from.x, to.x) + half + 2.0), wide)):
			var at := Vector2(x + 0.5, y + 0.5)
			var share := clampf((at - from).dot(along) / length_squared, 0.0, 1.0)
			_dab(x, y, color, clampf(half + 0.5 - at.distance_to(from + along * share), 0.0, 1.0))


## The same for an image that tiles from left to right.
func _stroke_round(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	for shift: float in [-1.0, 0.0, 1.0]:
		var off := Vector2(shift * _image.get_width(), 0)
		_stroke(from + off, to + off, width, color)


## A leaf: an oval `length` long and `width` wide, lying along `way`.
func _blade(middle: Vector2, way: Vector2, length: float, width: float, color: Color) -> void:
	var reach := maxf(length, width) + 1.0
	for y in range(maxi(int(middle.y - reach), 0), mini(int(middle.y + reach) + 1, _image.get_height())):
		for x in range(maxi(int(middle.x - reach), 0), mini(int(middle.x + reach) + 1, _image.get_width())):
			var off := Vector2(x + 0.5, y + 0.5) - middle
			var share := Vector2(off.dot(way) / length, off.dot(way.orthogonal()) / width).length()
			# Lighter along the rib.
			_dab(x, y, color.lightened(0.18 * (1.0 - clampf(absf(off.dot(way.orthogonal())) / width, 0.0, 1.0))), clampf((1.0 - share) * minf(length, width), 0.0, 1.0))


## A flat cushion of foliage, in an image that tiles from left to right: an
## oval with a ragged edge, lighter on top.
func _cushion(middle: Vector2, radii: Vector2, color: Color) -> void:
	var wide := _image.get_width()
	for y in range(maxi(int(middle.y - radii.y - 2.0), 0), mini(int(middle.y + radii.y + 2.0), _image.get_height())):
		for x in range(int(middle.x - radii.x - 2.0), int(middle.x + radii.x + 2.0)):
			var off := (Vector2(x + 0.5, y + 0.5) - middle) / radii
			var edge := 1.0 + 0.18 * sin(off.angle() * 9.0 + middle.x) + 0.1 * sin(off.angle() * 23.0)
			if off.length() < edge:
				_dab(posmod(x, wide), y, color.lightened(clampf(-off.y, 0.0, 1.0) * 0.16), 1.0)


## Lays `color` over the dot at (x, y), covering `cover` of it.
func _dab(x: int, y: int, color: Color, cover: float) -> void:
	if cover <= 0.0:
		return
	var under := _image.get_pixel(x, y)
	if under.a <= 0.0:
		_image.set_pixel(x, y, Color(color.r, color.g, color.b, cover))
		return
	var over := under.lerp(color, cover)
	over.a = maxf(under.a, cover)
	_image.set_pixel(x, y, over)
