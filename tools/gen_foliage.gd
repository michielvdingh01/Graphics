extends SceneTree
## Draws the textures of what grows, and of what is knotted and woven, that
## assets/manifest.json lists with source "drawn": into assets/foliage/. Each
## is a picture with holes in it, for a card of leaves, a net or a fence. Run
## with: tools/gen_foliage.sh
##
## An entry names a kind, a size and a seed:
##
##   grass      a tuft of marram, blades fanning up from the foot of the card
##   net        a camouflage net: cord with scrim knotted into it; it tiles
##   concertina a coil of barbed wire, unrolled; it tiles
##   chainlink  wire mesh; it tiles
##   treeline   the dark inside a pine wood, behind the trees of its edge; it tiles from left to right
##   ruts       the two ruts of a track; it tiles from top to bottom
##
## Nothing here is scanned: where a card is seen from close by it shows. The
## needles of the pines and the leaves of the scrub are not drawn here any
## more but grown and rendered: tools/gen_sprigs.py.

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
	for i in 1500:
		var middle := Vector2(_rng.randf(), _rng.randf()) * size
		var thin := holes.get_pixelv(Vector2i(middle)).r
		if thin < 0.47 and _rng.randf() > (thin - 0.2) * 1.6:
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


## Concertina wire, unrolled and laid flat: the coil cut open along its length.
## Every turn of it is clipped to the turn before and to the turn after, at
## places that alternate round the coil, so that pulled out it stands as a
## lattice of diamonds. The picture is one diamond: a fifth of the way round
## the coil from left to right, and two turns from top to bottom. Spring
## steel, galvanised and gone dull, with a barb every hand's breadth. It
## tiles.
func _concertina() -> void:
	var size := float(_image.get_width())
	var half := size * 0.5
	var gap := size * 0.011
	var thick := size * 0.0085
	var rust := _tiling(0.02, 2)
	for turn in 2:
		var before := Vector2.ZERO
		var steps := 64
		var run := 0.0
		for step in steps + 1:
			var x := size * step / steps
			var rise := clampf(half * (1.0 - absf(2.0 * x / size - 1.0)), gap, half - gap)
			var at := Vector2(x, rise if turn == 0 else size - rise)
			if step > 0:
				var worn := rust.get_pixelv(Vector2i(at.posmod(size))).r
				var steel := Color(0.5, 0.5, 0.48).lerp(Color(0.3, 0.2, 0.13), smoothstep(0.5, 0.75, worn)).darkened(_rng.randf() * 0.15)
				_stroke_tiled(before, at, thick, steel.darkened(0.35))
				_stroke_tiled(before, at, thick * 0.5, steel.lightened(0.25))
				var length := before.distance_to(at)
				# A barb: two short points of wire wound round the strand.
				if int((run + length) / (size * 0.125)) > int(run / (size * 0.125)) and absf(rise - half * 0.5) < half * 0.42:
					var way := (at - before).normalized()
					for lean: float in [0.9, -1.1]:
						var point := way.rotated(lean + _rng.randf_range(-0.2, 0.2)) * size * _rng.randf_range(0.016, 0.022)
						_stroke_tiled(at - point, at + point, thick * 0.55, steel.lightened(0.1))
				run += length
			before = at
	# The clips that hold one turn to the next.
	for clip: Vector2 in [Vector2(half, half), Vector2(0, 0)]:
		_stroke_tiled(clip - Vector2(0, gap * 1.25), clip + Vector2(0, gap * 1.25), thick * 1.5, Color(0.27, 0.25, 0.22))


## Chain-link fencing: wires that run both ways on the slant. It tiles.
func _chainlink() -> void:
	var size := _image.get_width()
	var pitch := size / 4.0
	for y in size:
		for x in size:
			var one := absf(fposmod(x + y + 0.5, pitch) - pitch * 0.5)
			var other := absf(fposmod(x - y + 0.5, pitch) - pitch * 0.5)
			var wire := minf(one, other)
			var cover := clampf(2.6 - wire, 0.0, 1.0)
			if cover > 0.0:
				# Round wire: light along its middle. One runs over the other.
				var round := 1.0 - wire / 2.6
				var tone := lerpf(0.34, 0.62, round) * (1.0 if one < other else 0.82)
				_image.set_pixel(x, y, Color(tone, tone * 1.02, tone * 1.04, cover))


## The dark of a pine wood, as it is seen between the trunks of the trees at
## its edge and behind their crowns: gloom under the canopy, the trunks that
## stand further in as paler stripes in it, and a little light on its floor.
## Its top is ragged and stays below the crowns that stand in front of it.
## It tiles from left to right.
func _treeline() -> void:
	var wide := _image.get_width()
	var high := float(_image.get_height())
	var gloom := Color(0.03, 0.045, 0.036)
	var floor_light := Color(0.1, 0.085, 0.06)
	for y in range(int(high * 0.12), int(high)):
		var down := (y / high - 0.12) / 0.88
		for x in wide:
			_image.set_pixel(x, y, gloom.lerp(floor_light, pow(down, 5.0) * 0.8))
	# The trunks further in: the deeper, the thinner and the nearer the gloom.
	for row in 3:
		var trees := 40 + row * 22
		for i in trees:
			var x := (i + _rng.randf_range(0.1, 0.9)) * wide / trees
			var top := high * _rng.randf_range(0.3, 0.5)
			var girth := high * _rng.randf_range(0.008, 0.013) * (1.0 - row * 0.25)
			var bark := gloom.lerp(Color(0.14, 0.11, 0.085), (0.6 - row * 0.18) * _rng.randf_range(0.6, 1.0))
			_stroke_round(Vector2(x, high), Vector2(x + _rng.randf_range(-10, 10), top), girth, bark)
	# The undersides of the crowns close it off at the top.
	for i in 150:
		var at := Vector2(_rng.randf() * wide, high * _rng.randf_range(0.1, 0.32))
		_cushion(at, Vector2(high * _rng.randf_range(0.1, 0.2), high * _rng.randf_range(0.04, 0.09)), gloom.lightened(_rng.randf() * 0.03))


## The two ruts of a track that lorries use: darker, damper earth with the
## print of the tread in it. It tiles from top to bottom.
func _ruts() -> void:
	var wide := _image.get_width()
	var high := _image.get_height()
	var grain := _tiling(0.03, 4)
	for y in high:
		for x in wide:
			var u := (x + 0.5) / wide
			var wear := grain.get_pixel(x % grain.get_width(), y % grain.get_height()).r
			var alpha := 0.0
			var dark := 0.0
			for rut: float in [0.27, 0.73]:
				var off := absf(u - rut) / 0.115
				if off < 1.0:
					# Chevrons of tread, pressed in.
					var tread := fposmod((y + absf(u - rut) * wide * 1.6) / (high / 16.0), 1.0)
					var lug := smoothstep(0.35, 0.5, tread) * (1.0 - smoothstep(0.85, 1.0, tread))
					alpha = maxf(alpha, (1.0 - smoothstep(0.55, 1.0, off)) * (0.5 + 0.35 * lug + 0.25 * wear))
					dark = lug
			alpha = maxf(alpha, (1.0 - smoothstep(0.3, 0.5, absf(u - 0.5))) * 0.1 * wear)
			if alpha > 0.0:
				var earth := Color(0.2, 0.15, 0.1).lerp(Color(0.11, 0.08, 0.055), dark * 0.7 + wear * 0.3)
				_image.set_pixel(x, y, Color(earth.r, earth.g, earth.b, clampf(alpha, 0.0, 0.9)))


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
