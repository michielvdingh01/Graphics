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


## A camouflage net: a mesh of cord, with strips of scrim knotted into it in
## three colours that leave holes between them. It tiles.
func _net() -> void:
	var size := _image.get_width()
	var patches := _tiling(0.012, 2)
	var shades := _tiling(0.02, 1)
	var holes := _tiling(0.05, 3)
	var scrim: Array[Color] = [Color(0.3, 0.34, 0.18), Color(0.42, 0.36, 0.22), Color(0.22, 0.27, 0.15), Color(0.5, 0.46, 0.31)]
	for y in size:
		for x in size:
			var cloth := patches.get_pixel(x, y).r * 0.75 + holes.get_pixel(x, y).r * 0.25
			var cord := minf(float(x % 32), float(y % 32)) < 2.0
			if cloth > 0.44:
				var tone := scrim[int(shades.get_pixel(x, y).r * 3.999)]
				_image.set_pixel(x, y, Color(tone.r, tone.g, tone.b, 1.0).darkened(holes.get_pixel(x, y).r * 0.3))
			elif cord:
				_image.set_pixel(x, y, Color(0.24, 0.21, 0.15, 1.0))


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


## The edge of a pine wood from afar: three rows of bare trunks under flat
## crowns, the further the paler, on a band of undergrowth that shuts the
## bottom of the card. It tiles from left to right.
func _treeline() -> void:
	var wide := _image.get_width()
	var high := float(_image.get_height())
	var tones: Array[Color] = [Color(0.15, 0.2, 0.19), Color(0.09, 0.15, 0.1), Color(0.05, 0.095, 0.05)]
	# Between the trunks it is dark: more wood, further in.
	for y in range(int(high * 0.3), int(high)):
		for x in wide:
			_image.set_pixel(x, y, Color(0.045, 0.07, 0.05).lerp(Color(0.025, 0.04, 0.028), (y / high - 0.3) / 0.7))
	for row in 3:
		var tone := tones[row]
		var trees := 26 - row * 4
		for i in trees:
			var x := (i + _rng.randf_range(0.1, 0.9)) * wide / trees
			var top := high * _rng.randf_range(0.06, 0.26) + row * high * 0.05
			var girth := high * _rng.randf_range(0.012, 0.02)
			_stroke_round(Vector2(x, high), Vector2(x + _rng.randf_range(-12, 12), top + high * 0.12), girth, tone.darkened(0.35))
			# The crown: a handful of flat cushions about the top of the trunk.
			for c in _rng.randi_range(6, 10):
				var at := Vector2(x + _rng.randf_range(-1, 1) * high * 0.14, top + _rng.randf() * high * 0.2)
				_cushion(at, Vector2(high * _rng.randf_range(0.07, 0.13), high * _rng.randf_range(0.03, 0.055)), tone.lightened(_rng.randf() * 0.12))
		# What grows under them.
		for i in 120:
			var at := Vector2(_rng.randf() * wide, high * (0.86 + row * 0.04 + _rng.randf() * 0.1))
			_cushion(at, Vector2(high * _rng.randf_range(0.05, 0.12), high * _rng.randf_range(0.03, 0.07)), tone.darkened(0.15))


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
