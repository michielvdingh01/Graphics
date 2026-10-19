extends Node3D
## The grass of a meadow of kilometres, which nobody could strew tuft by tuft,
## and the flowers between it and the floor of the wood: drawn round whoever
## looks, as far as each is seen, and only there.
## Every tuft stands on a grid in the world, so that it stays where it stands
## while the eye moves; where on the grid it is, the shader works out for
## itself, and from the maps of the land how high the ground is there, whether
## grass grows on it and which (shaders/alps_grass.gdshader). Nothing of it
## is in anybody's way, and it throws no shadow.
##
## It is five rings round the eye, each with its tufts twice as far apart as
## the one inside it, and wider: as many tufts as it takes to cover the
## ground near by, and the ground itself further off, until the last ring
## sinks into it at 128 m. Every ring is cut into tiles that follow the eye
## square by square, so that the renderer leaves out what is not in sight;
## where a ring has a hole for the one inside it, it has no tiles.

## What is drawn: the grass, the flowers and herbs between it, and the floor
## of the wood, each a layer with a material of its own, the sheet of
## pictures it is drawn with (tools/gen_plants.py) and rings of its own.
##
## A ring: how far apart the tufts stand, how far out the ring reaches (a ring
## begins where the one inside it ends), how many cards a tuft is (one turns
## to the eye; with three there is a fourth lying flat), and what the layer's
## material is told besides.
const LAYERS := [
	{
		"material": "res://materials/alps_grass.tres",
		"sheet": "res://assets/foliage/alps_meadow.json",
		"cells": ["mown0", "mown1", "mown2", "mown3", "top0", "top1", "top2", "top3", "long0", "long1", "long2", "long3", "wet0", "wet1", "wet2", "wet3", "far0", "far1", "far2", "far3"],
		# Which pictures each kind is drawn with, up close and from afar, to
		# make it the colour of the ground from afar (mown, long, wet).
		"kinds": [[0, 1, 2, 3], [8, 9, 10, 11], [12, 13, 14, 15]],
		"far_kinds": [[16], [17], [18]],
		# Each ring: whether it shows the pictures for afar, how much wider
		# and higher than its picture a tuft is, and how many of the tufts of
		# each kind it keeps (mown, long, wet).
		"rings": [
			[0.2, 8.0, 3, {"far_cells": false, "grown": Vector2(1.0, 1.0), "keep": Vector3(1.0, 0.3, 0.45)}],
			[0.4, 16.0, 3, {"far_cells": false, "grown": Vector2(1.3, 1.05), "keep": Vector3(1.0, 0.45, 0.6)}],
			[0.8, 32.0, 2, {"far_cells": false, "grown": Vector2(1.7, 1.1), "keep": Vector3(1.0, 0.75, 0.85)}],
			[1.6, 64.0, 1, {"far_cells": true, "grown": Vector2(2.2, 1.1), "keep": Vector3(1.0, 1.0, 1.0)}],
			[3.2, 128.0, 1, {"far_cells": true, "grown": Vector2(3.8, 1.1), "keep": Vector3(1.0, 1.0, 1.0)}],
		],
	},
	{
		"material": "res://materials/alps_herbs.tres",
		"sheet": "res://assets/foliage/alps_herbs.json",
		"cells": ["crocus0", "crocus1", "crocus2", "crocus3", "puff0", "puff1", "puff2", "puff3", "knapweed0", "knapweed1", "yarrow0", "yarrow1", "nettle0", "nettle1", "nettle2", "nettle3", "dandelion0", "dandelion1", "dandelion2", "dandelion3"],
		# Each ring: how much larger a plant is, and how much likelier a
		# square holds one, as there are four times fewer squares.
		"rings": [
			[0.5, 12.0, 3, {"layer": 0, "grown": Vector2(1.0, 1.0), "more": 1.0}],
			[1.0, 24.0, 2, {"layer": 0, "grown": Vector2(1.1, 1.05), "more": 4.0}],
			[2.0, 48.0, 1, {"layer": 0, "grown": Vector2(1.2, 1.1), "more": 16.0}],
		],
	},
	{
		"material": "res://materials/alps_shrubs.tres",
		"sheet": "res://assets/foliage/alps_shrubs.json",
		"cells": ["hazel0", "hazel1", "hazel2", "hazel3", "hazel4", "hazel5", "rowan0", "rowan1", "rowan2", "rowan3", "rowan4", "rowan5", "juniper0", "juniper1", "juniper2", "juniper3", "juniper4", "juniper5"],
		# Shrubs stand a metre or more high: those near by throw a shadow.
		"rings": [
			[3.0, 45.0, 3, {"layer": 2, "grown": Vector2(1.0, 1.0), "more": 1.0}, true],
			[6.0, 100.0, 1, {"layer": 2, "grown": Vector2(1.0, 1.0), "more": 4.0}],
			[12.0, 220.0, 1, {"layer": 2, "grown": Vector2(1.0, 1.0), "more": 16.0}],
		],
	},
	{
		"material": "res://materials/alps_floor.tres",
		"sheet": "res://assets/foliage/alps_floor.json",
		"cells": ["bilberry0", "bilberry1", "bilberry2", "bilberry3", "fern0", "fern1", "fern2", "fern3", "seedling0", "seedling1", "seedling2", "seedling3", "moss0", "moss1", "sorrel0", "sorrel1", "moss_top0", "moss_top1", "sorrel_top0", "sorrel_top1"],
		"rings": [
			[0.4, 10.0, 3, {"layer": 1, "grown": Vector2(1.0, 1.0), "more": 1.0}],
			[0.8, 20.0, 2, {"layer": 1, "grown": Vector2(1.5, 1.05), "more": 1.0}],
			[1.6, 40.0, 1, {"layer": 1, "grown": Vector2(2.4, 1.1), "more": 1.0}],
			[3.2, 72.0, 1, {"layer": 1, "grown": Vector2(4.0, 1.15), "more": 1.0}],
		],
	},
]
## A ring is so many tiles across.
const TILES := 6
## The maps of the land every material here reads.
const MAPS := ["land_height", "land_a", "land_b", "land_c", "land_rect", "land_cell"]

## The material the level hands the maps of its land; what is drawn is drawn
## with materials of its own, which get the maps from this one.
@export var look: ShaderMaterial

## Every tile: the instance, which ring, and its place in the ring in
## squares from the ring's first.
var _tiles: Array[MultiMeshInstance3D] = []
var _tile_ring := PackedInt32Array()
var _tile_at: Array[Vector2i] = []
## Every ring: [spacing, squares across a tile, squares across the ring].
var _rings: Array = []
var _heights := PackedFloat32Array()
var _height_size := Vector2i.ZERO
var _land_rect := Vector4.ZERO
var _land_cell := 2.0
## The colours the grass is seen as from afar, if the level's ground says.
var _seen := {}


func _ready() -> void:
	if look == null:
		return
	# The grass follows the eye also while the game stands still.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var maps := {}
	for map: String in MAPS:
		maps[map] = look.get_shader_parameter(map)
	_land_rect = maps.land_rect
	_land_cell = maps.land_cell
	var heights: Texture2D = maps.land_height
	if heights:
		var image := heights.get_image()
		_height_size = image.get_size()
		_heights = image.get_data().to_float32_array()
	# A level built while the grass did not read land_c yet has it next to its
	# other maps but not on the material.
	if maps.land_c == null and maps.land_a is Resource:
		var beside := (maps.land_a as Resource).resource_path.replace("_land_a.", "_land_c.")
		if beside != (maps.land_a as Resource).resource_path and ResourceLoader.exists(beside):
			maps.land_c = load(beside)
	if maps.land_c == null:
		maps.land_c = _stand_in_lie(maps.land_a, maps.land_b)
	# What the meadow is seen as from afar, as the level's ground has it.
	if maps.land_a is Resource:
		var ground := (maps.land_a as Resource).resource_path.replace("_land_a.", "_ground_look.")
		if ResourceLoader.exists(ground):
			var ground_look := load(ground) as ShaderMaterial
			for seen: Array in [["green_seen", "mown_seen"], ["straw_seen", "long_seen"]]:
				var colour: Variant = ground_look.get_shader_parameter(seen[0]) if ground_look else null
				# A colour the level left as the ground shader has it.
				if colour == null and ground_look and ground_look.shader:
					colour = RenderingServer.shader_get_parameter_default(ground_look.shader.get_rid(), seen[0])
				if colour is Vector3:
					colour = Color(colour.x, colour.y, colour.z)
				if colour is Color:
					_seen[seen[1]] = colour
	for layer: Dictionary in LAYERS:
		if ResourceLoader.exists(layer.material) and FileAccess.file_exists(layer.sheet):
			_layer(layer, maps)
	_follow(true)


## One layer: a MultiMesh for every ring of it, drawn by the tiles of the ring.
func _layer(layer: Dictionary, maps: Dictionary) -> void:
	var look_of := load(layer.material) as ShaderMaterial
	var sheet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(layer.sheet))
	var cells := PackedColorArray()
	var sizes := PackedVector2Array()
	for cell: String in layer.cells:
		var uv: Array = sheet.cells[cell].uv
		var size: Array = sheet.cells[cell].size
		cells.append(Color(uv[0], uv[1], uv[2], uv[3]))
		sizes.append(Vector2(size[0], size[1]))
	var inside := 0.0
	var rings: Array = layer.rings
	for ring: Array in rings:
		var spacing: float = ring[0]
		var reach: float = ring[1]
		var per_tile := int(ceilf((reach * 2.0 / spacing + 2.0) / TILES))
		var across := per_tile * TILES
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = _tuft(ring[2])
		multi.instance_count = per_tile * per_tile
		# The tufts take where they stand from the tile, which is where the
		# instance stands.
		for i in multi.instance_count:
			multi.set_instance_transform(i, Transform3D.IDENTITY)
		var material := look_of.duplicate() as ShaderMaterial
		for map: String in MAPS:
			material.set_shader_parameter(map, maps[map])
		material.set_shader_parameter("cells", cells)
		material.set_shader_parameter("cell_size", sizes)
		material.set_shader_parameter("spacing", spacing)
		material.set_shader_parameter("columns", per_tile)
		material.set_shader_parameter("hole", inside)
		material.set_shader_parameter("reach", reach)
		material.set_shader_parameter("last_ring", ring == rings[-1])
		material.set_shader_parameter("facing_eye", ring[2] == 1)
		var told: Dictionary = ring[3]
		for parameter: String in told:
			material.set_shader_parameter(parameter, told[parameter])
		if layer.has("kinds"):
			var means := PackedVector3Array()
			for pictures: Array in (layer.far_kinds if told.get("far_cells", false) else layer.kinds):
				var sum := Vector3.ZERO
				for index: int in pictures:
					var mean: Array = sheet.cells[layer.cells[index]].get("mean", [0.1, 0.1, 0.1])
					sum += Vector3(mean[0], mean[1], mean[2])
				means.append(sum / pictures.size())
			material.set_shader_parameter("kind_mean", means)
			for parameter: String in _seen:
				material.set_shader_parameter(parameter, _seen[parameter])
		var index := _rings.size()
		_rings.append([spacing, per_tile, across])
		for j in TILES:
			for i in TILES:
				# The tile lies wholly where the ring inside draws.
				var low := mini(i, j) * per_tile - (across >> 1) - 1
				var high := (maxi(i, j) + 1) * per_tile - (across >> 1) + 1
				if maxi(absi(low), absi(high)) * spacing < inside * 0.8 - spacing:
					continue
				var drawn := MultiMeshInstance3D.new()
				drawn.multimesh = multi
				drawn.material_override = material
				drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ring.size() > 4 and ring[4] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				drawn.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				drawn.top_level = true
				add_child(drawn)
				_tiles.append(drawn)
				_tile_ring.append(index)
				_tile_at.append(Vector2i(i * per_tile, j * per_tile))
		inside = reach


func _process(_delta: float) -> void:
	_follow(false)


## Every tile to where it is round the eye now, and as high as the land it
## covers, so that the renderer can tell whether it is in sight.
func _follow(all: bool) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _tiles.is_empty():
		return
	var eye := camera.global_position
	var firsts: Array[Vector2i] = []
	for ring: Array in _rings:
		var spacing: float = ring[0]
		firsts.append(Vector2i(floori(eye.x / spacing), floori(eye.z / spacing)) - Vector2i.ONE * (int(ring[2]) >> 1))
	for index in _tiles.size():
		var ring: Array = _rings[_tile_ring[index]]
		var spacing: float = ring[0]
		var square := firsts[_tile_ring[index]] + _tile_at[index]
		var corner := Vector3(square.x * spacing, 0.0, square.y * spacing)
		var drawn := _tiles[index]
		if not all and drawn.position.is_equal_approx(corner):
			continue
		drawn.position = corner
		var side: float = ring[1] * spacing
		var low := INF
		var high := -INF
		for k in 9:
			var h := _height_at(corner.x + side * 0.5 * (k % 3), corner.z + side * 0.5 * floorf(k / 3.0))
			low = minf(low, h)
			high = maxf(high, h)
		var pad := 1.0 + side * 0.2
		drawn.custom_aabb = AABB(Vector3(-1.0, low - pad, -1.0), Vector3(side + 2.0, high - low + pad * 2.0 + 1.5, side + 2.0))


func _height_at(x: float, z: float) -> float:
	if _heights.is_empty():
		return 0.0
	var cell := Vector2i(clampi(roundi((x - _land_rect.x) / _land_cell), 0, _height_size.x - 1), clampi(roundi((z - _land_rect.y) / _land_cell), 0, _height_size.y - 1))
	return _heights[cell.y * _height_size.x + cell.x]


## One tuft: so many cards through each other, each a unit wide and high,
## its foot at the origin, and with three of them one that lies in the grass
## at a third of its height, for the meadow seen from above. The vertex
## colour says what the shader takes it to say: red how far a corner bends in
## the wind, blue how much light gets to it. UV2.x is which card it is, so
## that each shows another picture, and UV2.y is 1 on the one that lies.
func _tuft(cards: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dice := RandomNumberGenerator.new()
	dice.seed = 41
	for card in cards:
		var angle := card * PI / cards + dice.randf_range(-0.25, 0.25)
		if cards == 1:
			angle = 0.0
		var out := Vector3(sin(angle), 0.0, cos(angle))
		var side := Vector3(out.z, 0.0, -out.x)
		var lean := out * (0.08 if cards > 1 else 0.0)
		var corners: Array[Vector3] = [-side * 0.5, side * 0.5, side * 0.5 + lean + Vector3.UP, -side * 0.5 + lean + Vector3.UP]
		var uvs: Array[Vector2] = [Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)]
		var lit: Array[Color] = [Color(0, 0, 0.82, 0), Color(0, 0, 0.82, 0), Color(1, 0, 1, 0), Color(1, 0, 1, 0)]
		var normal := (Vector3.UP + out * 0.3).normalized()
		for corner: int in [0, 2, 1, 0, 3, 2]:
			st.set_color(lit[corner])
			st.set_normal(normal)
			st.set_tangent(Plane(side, 1.0))
			st.set_uv(uvs[corner])
			st.set_uv2(Vector2(card, 0.0))
			st.add_vertex(corners[corner])
	if cards == 3:
		# Up on its picture is north.
		var corners: Array[Vector3] = [Vector3(-0.5, 0.35, 0.5), Vector3(0.5, 0.35, 0.5), Vector3(0.5, 0.35, -0.5), Vector3(-0.5, 0.35, -0.5)]
		var uvs: Array[Vector2] = [Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)]
		for corner: int in [0, 2, 1, 0, 3, 2]:
			st.set_color(Color(0.35, 0, 0.9, 0))
			st.set_normal(Vector3.UP)
			st.set_tangent(Plane(Vector3.RIGHT, -1.0))
			st.set_uv(uvs[corner])
			st.set_uv2(Vector2(cards, 1.0))
			st.add_vertex(corners[corner])
	st.index()
	return st.commit()


## Until the level has a map of what grows where on its meadows (land_c), one
## made up from what it does have: long grass along the edge of the wood and
## the verges of the roads and in patches, wet grass in other patches. Eight
## metres a dot.
func _stand_in_lie(land_a: Texture2D, land_b: Texture2D) -> ImageTexture:
	var a := land_a.get_image()
	var b := land_b.get_image()
	for image: Image in [a, b]:
		if image.is_compressed():
			image.decompress()
	var step := 4
	var size := Vector2i(a.get_width() >> 2, a.get_height() >> 2)
	var forest := Image.create(size.x, size.y, false, Image.FORMAT_L8)
	for y in size.y:
		for x in size.x:
			var wood := a.get_pixel(x * step, y * step).b
			forest.set_pixel(x, y, Color(wood, wood, wood))
	var soft := forest.duplicate() as Image
	soft.resize(maxi(1, size.x >> 1), maxi(1, size.y >> 1), Image.INTERPOLATE_BILINEAR)
	soft.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.09
	noise.fractal_octaves = 3
	var lie := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var wood := forest.get_pixel(x, y).r
			var edge := clampf(soft.get_pixel(x, y).r * 2.6 - wood * 2.0, 0.0, 1.0)
			var ways := b.get_pixel(x * step, y * step)
			var from_middle := ways.r * 16.0
			var half_wide := ways.g * 4.0
			var verge := smoothstep(half_wide + 0.4, half_wide + 1.2, from_middle) * (1.0 - smoothstep(half_wide + 2.5, half_wide + 4.0, from_middle))
			var patch := smoothstep(0.45, 0.6, noise.get_noise_2d(x, y))
			var wet := smoothstep(0.4, 0.55, noise.get_noise_2d(x * 0.7 + 400.0, y * 0.7)) * (1.0 - edge)
			lie.set_pixel(x, y, Color(maxf(verge * 0.8, patch * 0.7), wet * 0.9, 0.0, edge))
	return ImageTexture.create_from_image(lie)
