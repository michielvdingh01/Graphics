extends Node3D
## The grass of a meadow of kilometres, which nobody could strew tuft by tuft:
## it is drawn round whoever looks, as far as grass is seen, and only there.
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

## The rings: how far apart the tufts stand, how far out the ring reaches (a
## ring begins where the one inside it ends), how many cards a tuft is (one
## turns to the eye), whether it shows the pictures for afar, how much wider
## and higher than its picture a tuft is, and how many of the tufts of each
## kind it keeps (mown, long, wet).
const RINGS := [
	[0.2, 8.0, 3, false, Vector2(1.0, 1.0), Vector3(1.0, 0.3, 0.45)],
	[0.4, 16.0, 3, false, Vector2(1.3, 1.05), Vector3(1.0, 0.45, 0.6)],
	[0.8, 32.0, 2, true, Vector2(1.25, 1.1), Vector3(1.0, 0.75, 0.85)],
	[1.6, 64.0, 1, true, Vector2(2.2, 1.1), Vector3(1.0, 1.0, 1.0)],
	[3.2, 128.0, 1, true, Vector2(3.8, 1.1), Vector3(1.0, 1.0, 1.0)],
]
## A ring is so many tiles across.
const TILES := 6
## The pictures of the grass, and where on their sheet each one is.
const GRASS := "res://materials/alps_grass.tres"
const GRASS_SHEET := "res://assets/foliage/alps_meadow.json"
const CELLS := ["mown0", "mown1", "mown2", "mown3", "top0", "top1", "top2", "top3", "long0", "long1", "long2", "long3", "wet0", "wet1", "wet2", "wet3", "far0", "far1", "far2", "far3"]
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
	if maps.land_c == null:
		maps.land_c = _stand_in_lie(maps.land_a, maps.land_b)
	var grass := load(GRASS) as ShaderMaterial
	var sheet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GRASS_SHEET))
	var cells := PackedColorArray()
	var sizes := PackedVector2Array()
	for cell: String in CELLS:
		var uv: Array = sheet.cells[cell].uv
		var size: Array = sheet.cells[cell].size
		cells.append(Color(uv[0], uv[1], uv[2], uv[3]))
		sizes.append(Vector2(size[0], size[1]))
	var inside := 0.0
	for ring: Array in RINGS:
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
		var material := grass.duplicate() as ShaderMaterial
		for map: String in MAPS:
			material.set_shader_parameter(map, maps[map])
		material.set_shader_parameter("cells", cells)
		material.set_shader_parameter("cell_size", sizes)
		material.set_shader_parameter("spacing", spacing)
		material.set_shader_parameter("columns", per_tile)
		material.set_shader_parameter("hole", inside)
		material.set_shader_parameter("reach", reach)
		material.set_shader_parameter("last_ring", ring == RINGS[-1])
		material.set_shader_parameter("facing_eye", ring[2] == 1)
		material.set_shader_parameter("far_cells", ring[3])
		material.set_shader_parameter("grown", ring[4])
		material.set_shader_parameter("keep", ring[5])
		var index := _rings.size()
		_rings.append([spacing, per_tile, across])
		for j in TILES:
			for i in TILES:
				# The tile lies wholly where the ring inside draws the grass.
				var low := mini(i, j) * per_tile - across / 2 - 1
				var high := (maxi(i, j) + 1) * per_tile - across / 2 + 1
				if maxi(absi(low), absi(high)) * spacing < inside * 0.8 - spacing:
					continue
				var drawn := MultiMeshInstance3D.new()
				drawn.multimesh = multi
				drawn.material_override = material
				drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				drawn.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				drawn.top_level = true
				add_child(drawn)
				_tiles.append(drawn)
				_tile_ring.append(index)
				_tile_at.append(Vector2i(i * per_tile, j * per_tile))
		inside = reach
	_follow(true)


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
		firsts.append(Vector2i(floori(eye.x / spacing), floori(eye.z / spacing)) - Vector2i.ONE * (ring[2] / 2))
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
			var h := _height_at(corner.x + side * 0.5 * (k % 3), corner.z + side * 0.5 * (k / 3))
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
	var size := a.get_size() / step
	var forest := Image.create(size.x, size.y, false, Image.FORMAT_L8)
	for y in size.y:
		for x in size.x:
			var wood := a.get_pixel(x * step, y * step).b
			forest.set_pixel(x, y, Color(wood, wood, wood))
	var soft := forest.duplicate() as Image
	soft.resize(maxi(1, size.x / 2), maxi(1, size.y / 2), Image.INTERPOLATE_BILINEAR)
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
