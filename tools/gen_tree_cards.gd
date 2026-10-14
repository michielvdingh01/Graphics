extends SceneTree
## Pictures the pines of tools/models/trees.gd from eight sides, for the one
## card a tree is drawn with from afar: tools/gen_tree_cards.sh
##
## A tree far off is one card that turns to whoever looks, with the picture on
## it that was taken from nearest to where he stands. A picture is of the
## tree as it is from the middle distance, without light: what colour every
## dot of it is, and in a second sheet which way it faces and whether it is
## wood, so that the sun can be put on it afterwards as it is put on the tree
## itself. See shaders/tree_far.gdshader.
##
## Writes assets/foliage/pine_far.png, pine_far_n.png and pine_far.json: where
## on the sheets each tree is, how many metres its pictures are across and
## where on them its foot stands. It draws, so it runs through tools/godot.sh
## and takes its turn on the GPU. Build the models first, and again after:
## tools/models/trees.gd reads the json.

const TREES: Array[String] = ["pine_a", "pine_b", "pine_c", "pine_d", "pine_young"]
const SIDES := 8
## The size of one picture on the sheet, and how many times as large it is
## drawn before it is brought down to that.
const CELL := Vector2i(192, 320)
const OVER := 3
const OUT := "res://assets/foliage/pine_far"
## What the importer is told of a sheet, as tools/gen_sprigs.py tells it.
const IMPORT := "[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[params]\n\ncompress/mode=2\ncompress/high_quality=true\nmipmaps/generate=true\nprocess/fix_alpha_border=true\ndetect_3d/compress_to=0\n"

## What a dot of a tree is, without light: the colour of its needles as
## shaders/crown.gdshader makes it, or of its bark.
const SHOW := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float deep = 1.0;
uniform float cut = 0.0;
uniform vec2 scale = vec2(1.0);
// 0 for the colour, 1 for which way the dot faces, 2 for whether it is wood.
uniform int what = 0;
// Whether this is bark: its colour is that of its corners, and it is wood.
uniform bool bark = false;
void fragment() {
	vec4 dot = texture(tex, UV * scale);
	if (!bark) {
		ALPHA = dot.a;
		ALPHA_SCISSOR_THRESHOLD = cut;
	}
	float wood = bark ? 1.0 : 1.0 - abs(COLOR.a - 0.5) * 2.0;
	vec3 faces = FRONT_FACING || bark ? NORMAL : -NORMAL;
	if (what == 0) {
		ALBEDO = bark ? dot.rgb * COLOR.rgb * tint : dot.rgb * mix(tint, vec3(1.0), wood) * mix(deep, 1.0, COLOR.b);
	} else if (what == 1) {
		ALBEDO = normalize(faces) * 0.5 + 0.5;
	} else {
		ALBEDO = vec3(wood);
	}
}
"""

var _viewport: SubViewport
var _camera: Camera3D


func _initialize() -> void:
	await process_frame
	_viewport = SubViewport.new()
	_viewport.size = CELL * OVER
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_CLEAR_COLOR
	world.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	_viewport.add_child(world)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 1.0
	_camera.far = 200.0
	_viewport.add_child(_camera)
	_camera.make_current()

	var colour := Image.create(CELL.x * SIDES, CELL.y * TREES.size(), false, Image.FORMAT_RGBA8)
	var facing := Image.create(CELL.x * SIDES, CELL.y * TREES.size(), false, Image.FORMAT_RGBA8)
	var table := {"cell": [CELL.x, CELL.y], "sides": SIDES, "rows": TREES.size(), "trees": {}}
	for row in TREES.size():
		table.trees[TREES[row]] = await _picture(TREES[row], row, colour, facing)
	colour.save_png(OUT + ".png")
	facing.save_png(OUT + "_n.png")
	var file := FileAccess.open(OUT + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(table, "\t") + "\n")
	file.close()
	for sheet: String in [OUT + ".png.import", OUT + "_n.png.import"]:
		if not FileAccess.file_exists(sheet):
			var settings := FileAccess.open(sheet, FileAccess.WRITE)
			settings.store_string(IMPORT)
			settings.close()
	print("Wrote %s.png, %s_n.png and %s.json" % [OUT, OUT, OUT])
	quit()


## The pictures of one tree, into row `row` of the sheets. Returns what the
## json says of it.
func _picture(tree: String, row: int, colour: Image, facing: Image) -> Dictionary:
	var model: Node3D = (load("res://scenes/models/%s.scn" % tree) as PackedScene).instantiate()
	_viewport.add_child(model)
	var seen: MeshInstance3D
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		part.visibility_range_begin = 0.0
		part.visibility_range_end = 0.0
		part.visible = part.name == "Mid"
		if part.visible:
			seen = part
	# The materials it is pictured with: one for each of its own.
	var shows: Array[ShaderMaterial] = []
	var shader := Shader.new()
	shader.code = SHOW
	for surface in seen.mesh.get_surface_count():
		var own := seen.mesh.surface_get_material(surface)
		var show := ShaderMaterial.new()
		show.shader = shader
		if own is ShaderMaterial:
			show.set_shader_parameter("tex", (own as ShaderMaterial).get_shader_parameter("leaf_tex"))
			show.set_shader_parameter("tint", (own as ShaderMaterial).get_shader_parameter("tint"))
			show.set_shader_parameter("deep", (own as ShaderMaterial).get_shader_parameter("deep"))
			show.set_shader_parameter("cut", (own as ShaderMaterial).get_shader_parameter("cut"))
		else:
			var bark := own as BaseMaterial3D
			show.set_shader_parameter("tex", bark.albedo_texture)
			show.set_shader_parameter("tint", bark.albedo_color)
			show.set_shader_parameter("scale", Vector2(bark.uv1_scale.x, bark.uv1_scale.y))
			show.set_shader_parameter("bark", true)
		seen.set_surface_override_material(surface, show)
		shows.append(show)

	# As large as fits all of it from every side: how far it reaches from its
	# stem, and how high.
	var box := seen.get_aabb()
	var reach := 0.0
	for corner: Vector3 in [box.position, box.end]:
		reach = maxf(reach, Vector2(corner.x, corner.z).length())
	reach = minf(reach, maxf(maxf(absf(box.position.x), absf(box.end.x)), maxf(absf(box.position.z), absf(box.end.z))) * 1.08)
	var low := minf(box.position.y, 0.0) - 0.1
	var high := box.end.y + 0.15
	var metre := maxf(2.0 * reach / CELL.x, (high - low) / CELL.y)
	var size := Vector2(CELL.x, CELL.y) * metre
	_camera.size = size.y
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	var middle := Vector3(0.0, low + size.y * 0.5, 0.0)
	var used := Rect2i()
	for side in SIDES:
		var turn := TAU * side / SIDES
		var from := Vector3(sin(turn), 0.0, cos(turn))
		_camera.position = middle + from * 60.0
		_camera.look_at(middle, Vector3.UP)
		var taken: Array[Image] = []
		for what in 3:
			for show in shows:
				show.set_shader_parameter("what", what)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var image := _viewport.get_texture().get_image()
			image.convert(Image.FORMAT_RGBAF)
			taken.append(_brought_down(image, what > 0))
		var at := Vector2i(side * CELL.x, row * CELL.y)
		for y in CELL.y:
			for x in CELL.x:
				var dot := taken[0].get_pixel(x, y)
				colour.set_pixel(at.x + x, at.y + y, dot)
				var faces := taken[1].get_pixel(x, y)
				facing.set_pixel(at.x + x, at.y + y, Color(faces.r, faces.g, faces.b, 1.0 - taken[2].get_pixel(x, y).r))
				if dot.a > 0.1:
					used = Rect2i(x, y, 1, 1) if used.size == Vector2i.ZERO else used.expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
	model.queue_free()
	await process_frame
	print("%s: %.1f m wide and %.1f m high in a picture of %.1f by %.1f m" % [tree, 2.0 * reach, high - low, size.x, size.y])
	used = used.grow(3).intersection(Rect2i(Vector2i.ZERO, CELL))
	return {
		"row": row,
		"size": [snappedf(size.x, 0.001), snappedf(size.y, 0.001)],
		# Where the foot of the stem is on a picture, from the left and from the top.
		"foot": [0.5, snappedf(1.0 + low / size.y, 0.0001)],
		"box": [float(used.position.x) / CELL.x, float(used.position.y) / CELL.y, float(used.end.x) / CELL.x, float(used.end.y) / CELL.y],
	}


## A picture brought down to the size of a cell, with the colour of every dot
## that of what is on it and not of the nothing around it. With `plain` what
## was drawn is not a colour, and what the screen made of it is undone.
func _brought_down(image: Image, plain: bool) -> Image:
	var small := Image.create(CELL.x, CELL.y, false, Image.FORMAT_RGBAF)
	for y in CELL.y:
		for x in CELL.x:
			var sum := Color(0, 0, 0, 0)
			for oy in OVER:
				for ox in OVER:
					var dot := image.get_pixel(x * OVER + ox, y * OVER + oy)
					if plain:
						dot = Color(dot.srgb_to_linear(), dot.a)
					# What the screen holds is the colour times how much of the dot
					# it covers, or near enough: weigh by that either way.
					sum += Color(dot.r * dot.a, dot.g * dot.a, dot.b * dot.a, dot.a)
			var cover := sum.a / (OVER * OVER)
			small.set_pixel(x, y, Color(sum.r / maxf(sum.a, 0.0001), sum.g / maxf(sum.a, 0.0001), sum.b / maxf(sum.a, 0.0001), cover))
	return small
