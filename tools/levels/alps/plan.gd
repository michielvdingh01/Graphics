extends "res://tools/kit.gd"
## The plan of the Alps: the Ehrwald basin in Tyrol, late on an afternoon in
## October. A flat moor of meadows and hay barns, the Moos, lies between the
## mountains of the Lechtal and Ammergau Alps in the west and the foot of the
## Zugspitze in the east, and the land of the map is a strip across it, from
## the wooded slopes in the west over the Moos to the meadows that rise
## towards Ehrwald in the east:
##
##        0          800        1600        2400       3200
##      0 +-------------------------------------------------+  north: the foot
##        |  ^^ slopes ^^       the Moos      ^ meadows ^   |  of the Daniel
##        |  in the shade   the line of the     rising to   |
##        |  of the west    mountains' shadow   Ehrwald, in |
##        |  mountains      runs down here      the sun     |
##   1792 +-------------------------------------------------+
##
## North is up. The sun stands low in the south-west and the mountains there
## throw their shadow over the western half of the land. The heights are those
## of the real basin (tools/levels/alps/dem.gd), two metres apart; the level's
## nought lies SEA metres over the sea. Every file of the level extends this
## one.

const DEM := preload("res://tools/levels/alps/dem.gd")
const LIGHT := preload("res://tools/levels/alps/light.gd")

## The land of the map, x and z, and where its corner (0, 0) lies in the
## metres of the elevation data: from the middle of the Moos, x to the east
## and z to the south.
const LAND := Rect2(0, 0, 3200, 1792)
const DEM_AT := Vector2(-1700, -350)
## How far apart the heights of the land lie, and the dots to the metre of
## the map of what covers it.
const CELL := 2.0
const COVER := 0.5
## How high over the sea the level's nought lies, in metres.
const SEA := 900.0
## Where the sun stands, as scenes/alps.tscn has it and the sky shows it:
## round from north by east, and over the horizon. About five in the
## afternoon in the middle of October; lower and all of the Moos is in the
## shade, higher and none of it.
const SUN_TURN := 230.0
const SUN_RISE := 11.5

## The elevation data, read once for every file of the level.
static var _dem: RefCounted
## The maps the ground material reads: the far one (see vista.gd), two
## textures, and where it lies (x and z of its corner, and one over its size
## each way); and the map of the land.
var _far_maps: Array[ImageTexture] = []
var _far_rect := Vector4()
var _land_maps: Array[ImageTexture] = []
## The ground material of this level, with its maps: see ground_look().
var _look: ShaderMaterial

## Where wood grows, and where snow lies: the tree line and the snow line in
## metres over the sea, how far either wanders up and down with the lie of
## the land, and the steepness (the up of the normal) below which the ground
## is bare rock and below which snow does not hold.
const TREE_LINE := 1720.0
const SNOW_LINE := 2000.0
const LINES_WANDER := 160.0
const ROCK_FROM := 0.64
const SNOW_HOLDS := 0.5
## The floor of the basin is mown meadow up to this high over the sea.
const MEADOW_TO := 1030.0
static var _lie_noise: FastNoiseLite
static var _clearings: FastNoiseLite
static var _gullies: FastNoiseLite
static var _edges: FastNoiseLite


func _level_name() -> String:
	return "alps"


## The height of the real ground at (x, z) of the level, over its nought:
## the land as the elevation data has it, before anything was done to it.
func altitude(x: float, z: float) -> float:
	if _dem == null:
		_dem = DEM.new()
	return _dem.altitude(x + DEM_AT.x, z + DEM_AT.y) - SEA


## What covers the ground at `at` (x and z), `high` metres over the sea,
## facing `normal`: how much of it is wood, snow and rock, 0 to 1 each. The
## same rule for the far map and for the land's own, and for where trees are
## planted, so that the wood stands where the ground is drawn as wood.
##
## The wood is spruce, dense up to about TREE_LINE and thinning above it,
## where the crowns stand apart and the dwarf pine creeps between them; it
## leaves the floor of the basin to the meadows, gives way to rock where it is
## too steep and is cut by the gullies avalanches come down every winter,
## which run with the fall of the slope. Here and there an alp lies open on a
## shoulder of the mountain.
func lie_of(at: Vector2, high: float, normal: Vector3) -> Dictionary:
	if _lie_noise == null:
		_lie_noise = _noise(7101, 900.0)
		_clearings = _noise(7103, 340.0)
		_gullies = _noise(7107, 70.0)
		_edges = _noise(7109, 45.0)
	var wander := _lie_noise.get_noise_2dv(at)
	var ragged := _edges.get_noise_2dv(at)
	var up := normal.y
	var rock := 1.0 - smoothstep(ROCK_FROM - 0.05, ROCK_FROM + 0.05, up + wander * 0.06 + ragged * 0.04)
	rock = maxf(rock, smoothstep(2350.0, 2600.0, high) * (1.0 - smoothstep(0.82, 0.92, up)))
	var line := high + wander * LINES_WANDER + ragged * 40.0
	var below_line := 1.0 - smoothstep(TREE_LINE - 120.0, TREE_LINE + 60.0, line)
	var thin := 1.0 - smoothstep(TREE_LINE - 40.0, TREE_LINE + 200.0, line)
	# Meadow on the floor of the basin and on the gentlest slopes round it.
	var mown := 1.0 - smoothstep(MEADOW_TO - 15.0, MEADOW_TO + 40.0, high + wander * 50.0 + ragged * 15.0)
	var pasture := smoothstep(0.992, 0.998, up + ragged * 0.003) * (1.0 - smoothstep(1050.0, 1120.0, high))
	var alp := smoothstep(0.5, 0.6, _clearings.get_noise_2dv(at) + ragged * 0.08) * smoothstep(0.93, 0.97, up)
	# Gullies: noise stretched along the fall of the slope, on the steep.
	var fall := Vector2(normal.x, normal.z)
	var gully := 0.0
	if fall.length() > 0.2:
		fall = fall.normalized()
		var across_fall := Vector2(-fall.y, fall.x)
		var stretched := Vector2(at.dot(across_fall), at.dot(fall) * 0.12)
		gully = smoothstep(0.38, 0.5, _gullies.get_noise_2dv(stretched)) * smoothstep(0.88, 0.78, up)
	var forest := below_line * (1.0 - mown) * (1.0 - pasture) * (1.0 - alp) * (1.0 - gully) * (1.0 - rock)
	# Above the dense wood: scattered crowns, about half of the ground.
	forest = maxf(forest, thin * (1.0 - below_line) * (1.0 - rock) * (1.0 - gully) * 0.5 * smoothstep(-0.2, 0.3, ragged))
	# Fresh snow lies higher on the slopes the sun has had all day.
	var sunny := clampf(-normal.x * 0.6 + normal.z * 0.5, -1.0, 1.0)
	var snow := smoothstep(SNOW_LINE - 70.0, SNOW_LINE + 70.0, high + wander * LINES_WANDER - sunny * 120.0 + ragged * 30.0)
	snow *= smoothstep(SNOW_HOLDS - 0.1, SNOW_HOLDS + 0.1, up)
	return {"forest": clampf(forest, 0.0, 1.0), "snow": snow, "rock": rock}


## The roads of the land. A gravel road from camp to camp, past the farm, on
## to Ehrwald; a cart track over the Moos from the south; and a track up the
## slope in the north to the hunter's stand.
const ROADS := [
	[4.6, [Vector2(300, 905), Vector2(520, 900), Vector2(820, 905), Vector2(1100, 930), Vector2(1350, 880), Vector2(1600, 840), Vector2(1850, 860), Vector2(2100, 880), Vector2(2380, 820), Vector2(2650, 780), Vector2(2880, 765), Vector2(3170, 770)]],
	[3.2, [Vector2(940, 1760), Vector2(980, 1500), Vector2(1060, 1250), Vector2(1120, 1060), Vector2(1100, 930)]],
	[3.2, [Vector2(2100, 880), Vector2(2140, 760), Vector2(2120, 650), Vector2(2200, 560), Vector2(2260, 470), Vector2(2250, 400)]],
]
## How far from the middle of a road the map of the land keeps count, in
## metres: see _land_map().
const ROAD_REACH := 16.0
## The roads that were cut: {path, width}.
var _roads_cut: Array[Dictionary] = []


## Cuts ROADS into the land.
func _roads() -> void:
	for way: Array in ROADS:
		road(way[1], way[0])


## A road along `points`, `width` wide: the land along it evened out
## lengthwise, laid level across it and eased into the land over `margin`
## either side. As track() of tools/kit/land.gd does, but from the road out:
## that one looks at every spot of the land round it for the nearest spot of
## the road, which over kilometres takes minutes.
func road(points: Array, width: float, margin := 5.0, ease := 12) -> void:
	var way := curve(points, 1.0)
	var level := PackedFloat32Array()
	for point in way:
		level.append(ground_height(point.x, point.y))
	for pass_ in 3:
		var evened := PackedFloat32Array()
		for i in level.size():
			var sum := 0.0
			var count := 0
			for j in range(maxi(i - ease, 0), mini(i + ease, level.size() - 1) + 1):
				sum += level[j]
				count += 1
			evened.append(sum / count)
		level = evened
	var half := width * 0.5
	var reach := half + margin
	var nearest := {}
	for k in way.size():
		var box := _spots_in(Rect2(way[k] - Vector2.ONE * reach, Vector2.ONE * reach * 2.0))
		for row in range(box[1], box[3] + 1):
			for column in range(box[0], box[2] + 1):
				var gap := _spot(column, row).distance_to(way[k])
				var i := row * _across() + column
				if gap <= reach and (not nearest.has(i) or gap < nearest[i][0]):
					nearest[i] = [gap, level[k]]
	for i: int in nearest:
		var hold := 1.0 - smoothstep(half, reach, nearest[i][0])
		_heights[i] = lerpf(_heights[i], nearest[i][1], hold)
		_firm[i] = maxf(_firm[i], hold)
	_roads_cut.append({"path": way, "width": width})


## How far from the middle of the nearest road the spot `at` lies, up to
## ROAD_REACH, to the nearest spot of the land.
func road_gap(at: Vector2) -> float:
	if _road_gaps.is_empty():
		_road_gaps = _road_distances()[0]
	var spots := _spots_in(Rect2(at, Vector2.ZERO))
	return _road_gaps[spots[1] * _across() + spots[0]]


var _road_gaps := PackedFloat32Array()


## How far from the middle of the nearest road every spot of the land lies, up
## to ROAD_REACH, and how wide that road is: two grids the size of the land.
func _road_distances() -> Array[PackedFloat32Array]:
	var gaps := PackedFloat32Array()
	gaps.resize(_across() * _down())
	gaps.fill(ROAD_REACH)
	var widths := PackedFloat32Array()
	widths.resize(gaps.size())
	for cut: Dictionary in _roads_cut:
		var way: PackedVector2Array = cut.path
		for k in way.size():
			var box := _spots_in(Rect2(way[k] - Vector2.ONE * ROAD_REACH, Vector2.ONE * ROAD_REACH * 2.0))
			for row in range(box[1], box[3] + 1):
				for column in range(box[0], box[2] + 1):
					var i := row * _across() + column
					# The nearest spot of the road between this point and the
					# next, not the point itself.
					var at := _spot(column, row)
					var gap := at.distance_to(way[k])
					if k + 1 < way.size():
						var along := way[k + 1] - way[k]
						var share := clampf((at - way[k]).dot(along) / maxf(along.length_squared(), 0.0001), 0.0, 1.0)
						gap = at.distance_to(way[k] + along * share)
					if gap < gaps[i]:
						gaps[i] = gap
						widths[i] = cut.width
	return [gaps, widths]


## The land of the basin as it is.
func _lie_of_the_land() -> void:
	land(LAND, 0.0, CELL, COVER)
	sun_at(SUN_TURN, SUN_RISE)
	open_air("alps")
	for row in _down():
		for column in _across():
			var at := _spot(column, row)
			_heights[row * _across() + column] = altitude(at.x, at.y)
	# The two camps at the ends, levelled where their vehicles stand.
	for camp: Vector2 in [Vector2(330, 905), Vector2(2880, 760)]:
		level_off(Rect2(camp - Vector2(45, 35), Vector2(90, 70)), NAN, 18.0)
	_roads()
	lay_ground("alps_ground")


# --- The mesh of the land ---------------------------------------------------------

const GROUND := preload("res://tools/levels/alps/ground.gd")
## How many cells of the land go into a block of its mesh, and each block's
## three meshes: every how many-th height each takes, and from how far to
## how far off it is drawn, in metres.
const BLOCK := 64
const LAND_LODS := [[1, 0.0, 320.0], [2, 320.0, 900.0], [8, 900.0, 0.0]]

## The meshes of the land and of what lies round it, made by this file and
## vista.gd. They go into a scene of their own when everything stands, see
## _finish_zones(): a level file holds no thousand meshes well.
var _land_mesh: Node3D


## Lays `mesh` in `mat` with the meshes of the land, drawn from `from` to `to`
## metres off (nought for no limit), throwing a shadow or not.
func lay_mesh(mesh: ArrayMesh, mat: Material, from := 0.0, to := 0.0, shadow := true) -> void:
	if mesh == null:
		return
	mesh.surface_set_material(0, mat)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if from > 0.0:
		instance.visibility_range_begin = from
	if to > 0.0:
		instance.visibility_range_end = to
	_land_node().add_child(instance, true)
	instance.owner = _land_mesh


## The ground material of this level: materials/alps_ground.tres with the maps
## of the level on it, one for the land and the mountains alike. It is
## written with the level, see _finish_zones().
func ground_look() -> ShaderMaterial:
	if _look == null:
		_look = (load("res://materials/alps_ground.tres") as ShaderMaterial).duplicate()
		_look.set_shader_parameter("sea", SEA)
	if not _far_maps.is_empty():
		_look.set_shader_parameter("far_a", _far_maps[0])
		_look.set_shader_parameter("far_b", _far_maps[1])
		_look.set_shader_parameter("far_rect", _far_rect)
	if not _land_maps.is_empty():
		_look.set_shader_parameter("land_a", _land_maps[0])
		_look.set_shader_parameter("land_b", _land_maps[1])
		_look.set_shader_parameter("land_rect", Vector4(_land.position.x, _land.position.y, 1.0 / _land.size.x, 1.0 / _land.size.y))
	return _look


## The map of the land, a dot for every height of it: how much sun reaches
## it (the mountains round it from the far map, the land itself and what
## stands on it from its own heights), how much of the sky it sees, how much
## of it is wood, and how much rock.
func _land_map() -> void:
	var began := Time.get_ticks_msec()
	var across := _across()
	var down := _down()
	var lit: PackedFloat32Array = LIGHT.sun(_heights, across, down, _cell, _sunward)
	var open: PackedFloat32Array = LIGHT.open_sky(_heights, across, down, _cell)
	var far := (_far_maps[0] as ImageTexture).get_image()
	if far.has_mipmaps():
		far.clear_mipmaps()
	var roads := _road_distances()
	# What is kept open of the wood (keep_open()) is meadow on the ground too.
	var kept_open := PackedByteArray()
	kept_open.resize(across * down)
	for area: Rect2 in _open:
		var box := _spots_in(area)
		for row in range(box[1], box[3] + 1):
			for column in range(box[0], box[2] + 1):
				kept_open[row * across + column] = 1
	var map := Image.create(across, down, false, Image.FORMAT_RGBA8)
	var ways := Image.create(across, down, false, Image.FORMAT_RGBA8)
	for row in down:
		for column in across:
			var i := row * across + column
			var at := _spot(column, row)
			var normal := _facing(column, row)
			var cover := lie_of(at, _heights[i] + SEA, normal)
			var uv := (at - Vector2(_far_rect.x, _far_rect.y)) * Vector2(_far_rect.z, _far_rect.w) * Vector2(far.get_size()) - Vector2(0.5, 0.5)
			var mountains := _bilinear(far, uv).r
			var by_road := roads[0][i] / ROAD_REACH
			# No wood on a road, nor right beside it.
			var forest: float = cover.forest * smoothstep(0.25, 0.45, by_road) * float(1 - kept_open[i])
			map.set_pixel(column, row, Color(minf(lit[i], mountains), open[i], forest, cover.rock))
			ways.set_pixel(column, row, Color(by_road, roads[1][i] / 8.0, 0.0, 0.0))
	map.generate_mipmaps()
	_land_maps = [ImageTexture.create_from_image(map), ImageTexture.create_from_image(ways)]
	print("Land map: %d x %d dots, in %.1f s" % [across, down, (Time.get_ticks_msec() - began) / 1000.0])


## An image read between its dots.
func _bilinear(image: Image, at: Vector2) -> Color:
	var size := image.get_size()
	var x0 := clampi(floori(at.x), 0, size.x - 2)
	var y0 := clampi(floori(at.y), 0, size.y - 2)
	var u := clampf(at.x - x0, 0.0, 1.0)
	var v := clampf(at.y - y0, 0.0, 1.0)
	return image.get_pixel(x0, y0).lerp(image.get_pixel(x0 + 1, y0), u).lerp(image.get_pixel(x0, y0 + 1).lerp(image.get_pixel(x0 + 1, y0 + 1), u), v)


## The mesh of the land, in blocks of three: see LAND_LODS. Every block at a
## step is the same flat grid, which the material lifts to the heights of
## the land (the map "land_height"); each block only says where it lies and
## how high it reaches, for the renderer to know when it is out of sight.
func _dress_ground() -> void:
	_land_map()
	var look := ground_look()
	var lifted := look.duplicate() as ShaderMaterial
	lifted.set_shader_parameter("lifted", true)
	var heights := Image.create_from_data(_across(), _down(), false, Image.FORMAT_RF, _heights.to_byte_array())
	lifted.set_shader_parameter("land_height", ImageTexture.create_from_image(heights))
	lifted.set_shader_parameter("land_cell", _cell)
	_lifted = lifted
	var shapes: Array[ArrayMesh] = []
	for lod: Array in LAND_LODS:
		var shape: ArrayMesh = GROUND.flat(BLOCK, lod[0], _cell)
		shape.surface_set_material(0, lifted)
		shapes.append(shape)
	var blocks := 0
	for r0 in range(0, _down() - 1, BLOCK):
		for c0 in range(0, _across() - 1, BLOCK):
			var low := INF
			var high := -INF
			for r in range(r0, mini(r0 + BLOCK, _down() - 1) + 1):
				for c in range(c0, mini(c0 + BLOCK, _across() - 1) + 1):
					low = minf(low, _heights[r * _across() + c])
					high = maxf(high, _heights[r * _across() + c])
			var corner := _spot(c0, r0)
			for k in LAND_LODS.size():
				var lod: Array = LAND_LODS[k]
				var hang: float = GROUND.SKIRT_PER_STEP * lod[0] * _cell
				var instance := MeshInstance3D.new()
				instance.mesh = shapes[k]
				instance.position = Vector3(corner.x, 0.0, corner.y)
				instance.custom_aabb = AABB(Vector3(0.0, low - hang, 0.0), Vector3(BLOCK * _cell, high - low + hang, BLOCK * _cell))
				instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				if lod[1] > 0.0:
					instance.visibility_range_begin = lod[1]
				if lod[2] > 0.0:
					instance.visibility_range_end = lod[2]
				_land_node().add_child(instance, true)
				instance.owner = _land_mesh
			blocks += 1
	print("Land: %d blocks of %d m" % [blocks, int(BLOCK * _cell)])


## The node the meshes of the land go under.
func _land_node() -> Node3D:
	if _land_mesh == null:
		_land_mesh = Node3D.new()
		_land_mesh.name = "LandMesh"
	return _land_mesh


var _lifted: ShaderMaterial


func _finish_zones() -> void:
	super()
	_write_grove()
	if _walk:
		var walk_path := "%s%s_walk.res" % [OUT_DIR, _level_name()]
		ResourceSaver.save(_walk, walk_path, ResourceSaver.FLAG_COMPRESS)
		_walk.take_over_path(walk_path)
		var tiles := Resource.new()
		tiles.set_meta(&"tiles", _walk_tiles)
		tiles.set_meta(&"square", WALK_CHUNK)
		var tiles_path := "%s%s_walk_tiles.res" % [OUT_DIR, _level_name()]
		ResourceSaver.save(tiles, tiles_path, ResourceSaver.FLAG_COMPRESS)
		tiles.take_over_path(tiles_path)
	if _land_mesh == null:
		return
	# The maps and the material that reads them, as files of their own.
	ground_look()
	var maps := {"far_a": _far_maps[0], "far_b": _far_maps[1], "land_a": _land_maps[0], "land_b": _land_maps[1]}
	for map_name: String in maps:
		var map_path := "%s%s_%s.res" % [OUT_DIR, _level_name(), map_name]
		ResourceSaver.save(maps[map_name], map_path, ResourceSaver.FLAG_COMPRESS)
		(maps[map_name] as Resource).take_over_path(map_path)
	var look_path := "%s%s_ground_look.res" % [OUT_DIR, _level_name()]
	ResourceSaver.save(_look, look_path, ResourceSaver.FLAG_COMPRESS)
	_look.take_over_path(look_path)
	if _lifted:
		var height_path := "%s%s_land_height.res" % [OUT_DIR, _level_name()]
		var height_map: Resource = _lifted.get_shader_parameter("land_height")
		ResourceSaver.save(height_map, height_path, ResourceSaver.FLAG_COMPRESS)
		height_map.take_over_path(height_path)
		# The maps the land's own material reads are the ground material's.
		for map_name: String in maps:
			_lifted.set_shader_parameter(map_name, maps[map_name])
		var lifted_path := "%s%s_land_look.res" % [OUT_DIR, _level_name()]
		ResourceSaver.save(_lifted, lifted_path, ResourceSaver.FLAG_COMPRESS)
		_lifted.take_over_path(lifted_path)
		# The grass of the meadows, drawn round the eye: scripts/meadow.gd.
		var grass := (load("res://materials/alps_grass.tres") as ShaderMaterial).duplicate() as ShaderMaterial
		grass.set_shader_parameter("land_height", height_map)
		grass.set_shader_parameter("land_a", maps.land_a)
		grass.set_shader_parameter("land_b", maps.land_b)
		grass.set_shader_parameter("land_rect", _lifted.get_shader_parameter("land_rect"))
		grass.set_shader_parameter("land_cell", _cell)
		var grass_path := "%s%s_grass.res" % [OUT_DIR, _level_name()]
		ResourceSaver.save(grass, grass_path, ResourceSaver.FLAG_COMPRESS)
		grass.take_over_path(grass_path)
		var meadow := Node3D.new()
		meadow.name = "Meadow"
		meadow.set_script(load("res://scripts/meadow.gd"))
		meadow.set("look", grass)
		_add(meadow, _root)
	var scene := PackedScene.new()
	scene.pack(_land_mesh)
	var path := "%s%s_ground.scn" % [OUT_DIR, _level_name()]
	var err := ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS)
	print("Saved the mesh of the land: %s, %d meshes" % [error_string(err), _land_mesh.get_child_count()])
	_land_mesh.free()
	var laid: Node3D = (ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	_add(laid, _root)


# --- Where one can walk -------------------------------------------------------------

## The navmesh of the land: baked here, once, and not by the game when the
## level loads (see scripts/game.gd), which on land of kilometres would take
## minutes. Its cells are four times as coarse as those of the other levels,
## and the game sets the map of the level to match. It is baked in squares of
## WALK_CHUNK metres, each with what lies WALK_MARGIN round it, and every
## square is a region of its own in the game, which the map joins where
## their edges meet. Baked in one piece, Recast made polygons as large as the
## open land let it, a triangle of four hundred metres over the Moos lying
## flat a metre and a half over a hollow, where a bot never reaches the point
## of its way it is making for; a square keeps a polygon to its own size, and
## its corners are laid on the ground. The squares sewn together into one
## navmesh are what the game reads to know the floor (scripts/arena.gd,
## scripts/squad.gd). A way across the land then crosses tens of thousands of
## polygons, more than Godot searches by itself: see scripts/way.gd.
const WALK_CELL := 1.0
const WALK_CHUNK := 128.0
## How high a step one may take from one cell to the next: on land as steep
## as one can walk up, 45 degrees, that is a cell. With the quarter of a metre
## of the other levels every slope over 26 degrees fell apart into scraps.
const WALK_CLIMB := 1.0
## Whether the trunks of the wood are holes in the navmesh. Twelve thousand
## of them made it ten times as large: a bot walks round a trunk by itself.
const WALK_TRUNKS := false
const WALK_MARGIN := 6.0


## Bakes where one can walk from the colliders of the level, the ground with
## them.
func _bake_walk() -> NavigationMesh:
	var began := Time.get_ticks_msec()
	var obstacles := _obstacle_faces()
	var chunks: Array[NavigationMesh] = []
	var seams_x: Array[float] = []
	var seams_z: Array[float] = []
	var x := _land.position.x
	while x < _land.end.x - 0.1:
		var z := _land.position.y
		while z < _land.end.y - 0.1:
			var box := Rect2(x, z, minf(WALK_CHUNK, _land.end.x - x), minf(WALK_CHUNK, _land.end.y - z))
			chunks.append(_bake_chunk(box, obstacles))
			z += WALK_CHUNK
			if z < _land.end.y - 0.1 and not seams_z.has(z):
				seams_z.append(z)
		x += WALK_CHUNK
		if x < _land.end.x - 0.1:
			seams_x.append(x)
	var navmesh := _sew(chunks, seams_x, seams_z)
	_walk_tiles = chunks
	var polygons := 0
	for chunk in chunks:
		polygons += chunk.get_polygon_count()
	print("Walk: %d squares of %d m, %d polygons; sewn into one of %d polygons, in %.1f s" % [chunks.size(), int(WALK_CHUNK), polygons, navmesh.get_polygon_count(), (Time.get_ticks_msec() - began) / 1000.0])
	return navmesh


## A navmesh with the settings every square is baked with.
func _walk_settings() -> NavigationMesh:
	var navmesh := NavigationMesh.new()
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_collision_mask = 1
	navmesh.cell_size = WALK_CELL
	navmesh.cell_height = 0.25
	# A whole cell: the bake rounds half a metre up to one anyway, and says so
	# for every square.
	navmesh.agent_radius = WALK_CELL
	navmesh.agent_max_climb = WALK_CLIMB
	# Small regions into their neighbours: an open meadow in a few polygons.
	navmesh.region_min_size = 8.0
	navmesh.region_merge_size = 400.0
	navmesh.edge_max_error = 1.0
	navmesh.border_size = 2.0
	return navmesh


## Every face of what stands in the way, the ground left out: the colliders of
## the level parsed as the navmesh would, as a list of corners three by three.
func _obstacle_faces() -> PackedVector3Array:
	var tree := Engine.get_main_loop() as SceneTree
	var stand_in := Node3D.new()
	for body: StaticBody3D in _root.find_children("*", "StaticBody3D", true, false):
		if body.name == "Ground":
			continue
		var copy := StaticBody3D.new()
		var at: Node3D = body
		while at != _root:
			copy.transform = at.transform * copy.transform
			at = at.get_parent()
		copy.collision_layer = body.collision_layer
		for child in body.get_children():
			var collider := child as CollisionShape3D
			if collider:
				var shape := CollisionShape3D.new()
				shape.shape = collider.shape
				shape.transform = collider.transform
				copy.add_child(shape)
		stand_in.add_child(copy)
	tree.root.add_child(stand_in)
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(_walk_settings(), source, stand_in)
	stand_in.free()
	var corners := source.get_vertices()
	var faces := PackedVector3Array()
	for i in source.get_indices():
		faces.append(Vector3(corners[i * 3], corners[i * 3 + 1], corners[i * 3 + 2]))
	# The trunks of the wood, which are colliders only in the game (see
	# scripts/grove.gd): a square post each, as thick as the trunk.
	for trunk: Array in (_trunks if WALK_TRUNKS else []):
		var foot: Vector3 = trunk[0]
		var r: float = trunk[1]
		var top := foot + Vector3.UP * 4.0
		var square: Array[Vector3] = [Vector3(-r, 0, -r), Vector3(r, 0, -r), Vector3(r, 0, r), Vector3(-r, 0, r)]
		for k in 4:
			var a := square[k]
			var b := square[(k + 1) % 4]
			faces.append_array([foot + a, top + a, foot + b, foot + b, top + a, top + b])
		faces.append_array([top + square[0], top + square[2], top + square[1], top + square[0], top + square[3], top + square[2]])
	return faces


## The navmesh of one square of the land.
func _bake_chunk(box: Rect2, obstacles: PackedVector3Array) -> NavigationMesh:
	var reach := box.grow(WALK_MARGIN)
	var faces := PackedVector3Array()
	var spots := _spots_in(reach)
	for row in range(spots[1], spots[3]):
		for column in range(spots[0], spots[2]):
			var nw := Vector3(_spot(column, row).x, _heights[row * _across() + column], _spot(column, row).y)
			var ne := Vector3(nw.x + _cell, _heights[row * _across() + column + 1], nw.z)
			var sw := Vector3(nw.x, _heights[(row + 1) * _across() + column], nw.z + _cell)
			var se := Vector3(nw.x + _cell, _heights[(row + 1) * _across() + column + 1], nw.z + _cell)
			faces.append_array([nw, se, sw, nw, ne, se])
	for i in range(0, obstacles.size(), 3):
		var a := obstacles[i]
		var b := obstacles[i + 1]
		var c := obstacles[i + 2]
		var low := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
		var high := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
		if reach.intersects(Rect2(low, high - low), true):
			faces.append_array([a, b, c])
	var source := NavigationMeshSourceGeometryData3D.new()
	source.add_faces(faces, Transform3D())
	var navmesh := _walk_settings()
	# The border is left out inside the box that is baked: the box reaches
	# that far beyond the square, so that the square's navmesh ends where
	# the square does, against that of the next.
	var baked := box.grow(navmesh.border_size)
	navmesh.filter_baking_aabb = AABB(Vector3(baked.position.x, -1000.0, baked.position.y), Vector3(baked.size.x, 4000.0, baked.size.y))
	NavigationServer3D.bake_from_source_geometry_data(navmesh, source)
	# Its corners on the ground itself, where Recast has them to a quarter
	# of a metre: two squares that meet then have the same height along the
	# edge, and the map joins them. Not where something stands over the
	# ground, on a wall of sandbags.
	var corners := navmesh.get_vertices()
	for i in corners.size():
		var floor_at := ground_height(corners[i].x, corners[i].z)
		if absf(corners[i].y - floor_at) < 0.6:
			corners[i].y = floor_at + 0.05
	navmesh.set_vertices(corners)
	return navmesh


## The squares as one navmesh: their corners welded where they meet, and every
## edge along a seam split at the corners the other side has on it.
func _sew(chunks: Array[NavigationMesh], seams_x: Array[float], seams_z: Array[float]) -> NavigationMesh:
	var corners := PackedVector3Array()
	var polygons: Array[PackedInt32Array] = []
	for chunk in chunks:
		var first := corners.size()
		corners.append_array(chunk.get_vertices())
		for p in chunk.get_polygon_count():
			var polygon := chunk.get_polygon(p)
			for i in polygon.size():
				polygon[i] += first
			polygons.append(polygon)
	# Weld what lies on a seam at the same spot: one corner for both sides.
	var on_seam := {}
	var welded := PackedInt32Array()
	welded.resize(corners.size())
	for i in corners.size():
		welded[i] = i
		var c := corners[i]
		if not (_seam_of(c.x, seams_x) >= 0 or _seam_of(c.z, seams_z) >= 0):
			continue
		var key := Vector2i(roundi(c.x * 20.0), roundi(c.z * 20.0))
		for other: int in on_seam.get(key, []):
			if absf(corners[other].y - c.y) < 0.6:
				welded[i] = other
				break
		if welded[i] == i:
			if not on_seam.has(key):
				on_seam[key] = []
			on_seam[key].append(i)
	# The corners on each seam line, along it.
	var lines := {}
	for key: Vector2i in on_seam:
		for i: int in on_seam[key]:
			var c := corners[i]
			var sx := _seam_of(c.x, seams_x)
			if sx >= 0:
				var line := "x%d" % sx
				if not lines.has(line):
					lines[line] = []
				lines[line].append(i)
			var sz := _seam_of(c.z, seams_z)
			if sz >= 0:
				var line := "z%d" % sz
				if not lines.has(line):
					lines[line] = []
				lines[line].append(i)
	var navmesh := _walk_settings()
	var kept := PackedVector3Array()
	var renumber := {}
	for p in polygons.size():
		var polygon := polygons[p]
		var sewn := PackedInt32Array()
		for k in polygon.size():
			var a := welded[polygon[k]]
			var b := welded[polygon[(k + 1) % polygon.size()]]
			sewn.append(a)
			var line := _shared_seam(corners[a], corners[b], seams_x, seams_z)
			if line == "":
				continue
			# Along the seam from a to b: the other side's corners between.
			var along_x := line.begins_with("z")
			var from := corners[a].x if along_x else corners[a].z
			var to := corners[b].x if along_x else corners[b].z
			var between: Array = []
			for i: int in lines.get(line, []):
				if i == a or i == b:
					continue
				var c := corners[i]
				var t := c.x if along_x else c.z
				if (t - from) * (t - to) < -0.0001:
					var share := (t - from) / (to - from)
					if absf(c.y - lerpf(corners[a].y, corners[b].y, share)) < 0.6:
						between.append([share, i])
			between.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
			for entry: Array in between:
				sewn.append(entry[1])
		var numbered := PackedInt32Array()
		for i in sewn:
			if not renumber.has(i):
				renumber[i] = kept.size()
				kept.append(corners[i])
			numbered.append(renumber[i])
		polygons[p] = numbered
	navmesh.set_vertices(kept)
	for polygon in polygons:
		navmesh.add_polygon(polygon)
	return navmesh


## Which of `seams` a coordinate lies on, or -1.
func _seam_of(value: float, seams: Array[float]) -> int:
	for i in seams.size():
		if absf(value - seams[i]) < 0.02:
			return i
	return -1


## The seam line an edge from `a` to `b` runs along ("x3", "z1"), or none.
func _shared_seam(a: Vector3, b: Vector3, seams_x: Array[float], seams_z: Array[float]) -> String:
	var sx := _seam_of(a.x, seams_x)
	if sx >= 0 and sx == _seam_of(b.x, seams_x):
		return "x%d" % sx
	var sz := _seam_of(a.z, seams_z)
	if sz >= 0 and sz == _seam_of(b.z, seams_z):
		return "z%d" % sz
	return ""


## The builder of a level looks it over for sight lines between zones; land
## has no zones, and is too large for that. It gets its navmesh and its mesh.
func _survey() -> bool:
	_walk = _bake_walk()
	if _walk.get_polygon_count() == 0:
		push_error("Survey: there is nowhere to stand in this level")
		return false
	_dress_ground()
	return true


var _walk: NavigationMesh
## The squares the navmesh was baked in, each a region of its own in the
## game: see scripts/game.gd.
var _walk_tiles: Array[NavigationMesh] = []


# --- The wood -----------------------------------------------------------------------

const GROVE := preload("res://scripts/grove.gd")
## How far apart trees stand in a dense wood, about: one every so many metres
## each way, each shifted at random within its square.
const WOOD_SPACING := 6.0
## The kinds of tree, as models of tools/models/trees.gd, for the dense wood,
## its edge and young growth, the larches, and the dwarf pine above the line.
const SPRUCES := [["spruce_old", 3.0], ["spruce_mid", 2.0]]
const YOUNG := [["spruce_young", 2.0], ["spruce_mid", 1.0]]
const LARCHES := [["larch_old", 1.0], ["larch_young", 1.0]]
const DWARF_PINES := [["dwarf_pine_a", 1.0], ["dwarf_pine_b", 1.0]]

## Spots nothing grows on, [x, z, radius], filed by CLEAR_CELL squares: where
## an enemy of the route stands, a checkpoint, a vehicle. See keep_bare().
var _clear := {}
const CLEAR_CELL := 32.0


## Keeps `radius` round `at` clear of trees.
func keep_bare(at: Vector2, radius: float) -> void:
	var low := Vector2i(((at - Vector2.ONE * radius) / CLEAR_CELL).floor())
	var high := Vector2i(((at + Vector2.ONE * radius) / CLEAR_CELL).floor())
	for cz in range(low.y, high.y + 1):
		for cx in range(low.x, high.x + 1):
			var cell := Vector2i(cx, cz)
			if not _clear.has(cell):
				_clear[cell] = []
			(_clear[cell] as Array).append(Vector3(at.x, at.y, radius))


## Whether a tree can stand at `at`: as the kit has it, off the roads, and
## not on a spot kept clear.
func _tree_fits(at: Vector2) -> bool:
	if not super(at) or road_gap(at) < 5.0:
		return false
	for spot: Vector3 in _clear.get(Vector2i((at / CLEAR_CELL).floor()), []):
		if at.distance_squared_to(Vector2(spot.x, spot.y)) < spot.z * spot.z:
			return false
	return true


## A vehicle as the kit stands it, with the ground round it kept clear.
func vehicle(kind: String, at: Vector2, yaw_deg: float, parked := false) -> void:
	super(kind, at, yaw_deg, parked)
	keep_bare(at, 8.0)


## The trees planted so far, by kind: {"cells": {Vector2i: twelve numbers a
## tree}}, see scripts/grove.gd. And every trunk, [foot, radius], for the navmesh.
var _grove := {}
var _trunks: Array = []


## A tree of `kind` on the ground at `at`, `size` times as large as it was
## made and turned `yaw_deg`, drawn among the many of scripts/grove.gd. Its
## trunk is in the way; its crown keeps the sun off what lies beyond it.
func plant(kind: String, at: Vector2, size := 1.0, yaw_deg := 0.0) -> void:
	var info := _tree_kind(kind)
	var foot := ground(at.x, at.y, -0.12 * size)
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled(Vector3.ONE * size)
	var cell := Vector2i((at / GROVE.CELL).floor())
	if not _grove.has(kind):
		_grove[kind] = {"cells": {}}
	var cells: Dictionary = _grove[kind].cells
	if not cells.has(cell):
		cells[cell] = []
	(cells[cell] as Array).append_array([
		basis.x.x, basis.y.x, basis.z.x, foot.x,
		basis.x.y, basis.y.y, basis.z.y, foot.y,
		basis.x.z, basis.y.z, basis.z.z, foot.z,
	])
	var girth: float = info.girth * size
	if girth > 0.0:
		_trunks.append([foot, girth])
	for crown: Array in info.crowns:
		casts_shade(Transform3D(basis, foot) * (crown[0] as Vector3), (crown[1] as Vector3) * size)


## The wood of the land: wherever lie_of() says there is wood, as much of it
## as it says, on a grid of WOOD_SPACING shaken at random. Spruce for the
## most of it; young spruce where the wood thins out at its edge; larches in
## stands of their own between 1100 and 1900 metres; dwarf pine above the
## tree line.
func woods() -> void:
	var began := Time.get_ticks_msec()
	var dice := RandomNumberGenerator.new()
	dice.seed = hash("alps woods")
	var larch_stands := _noise(7121, 180.0)
	var planted := 0
	var z := _land.position.y + WOOD_SPACING * 0.5
	while z < _land.end.y:
		var x := _land.position.x + WOOD_SPACING * 0.5
		while x < _land.end.x:
			var at := Vector2(x, z) + Vector2(dice.randf_range(-0.45, 0.45), dice.randf_range(-0.45, 0.45)) * WOOD_SPACING
			x += WOOD_SPACING
			if not _tree_fits(at):
				continue
			var normal := ground_normal(at.x, at.y, 2.0)
			var high := ground_height(at.x, at.y) + SEA
			var cover := lie_of(at, high, normal)
			var dense: float = cover.forest
			if dense <= 0.02 or dice.randf() > dense:
				continue
			var kinds: Array = SPRUCES
			var size := dice.randf_range(0.8, 1.1)
			if high > TREE_LINE + 40.0 and dice.randf() < 0.7:
				kinds = DWARF_PINES
				size = dice.randf_range(0.8, 1.3)
			elif dense < 0.6 and dice.randf() < 0.5:
				kinds = YOUNG
			elif high > 1100.0 and high < 1900.0 and larch_stands.get_noise_2dv(at) > 0.25:
				kinds = LARCHES
			plant(_kind_by_weight(kinds, dice), at, size, dice.randf_range(0.0, 360.0))
			planted += 1
		z += WOOD_SPACING
	print("Woods: %d trees in %.1f s" % [planted, (Time.get_ticks_msec() - began) / 1000.0])


## One of `kinds`, [model, weight] each, by weight.
func _kind_by_weight(kinds: Array, dice: RandomNumberGenerator) -> String:
	var total := 0.0
	for kind: Array in kinds:
		total += kind[1]
	var roll := dice.randf() * total
	for kind: Array in kinds:
		roll -= kind[1]
		if roll <= 0.0:
			return kind[0]
	return kinds[-1][0]


## The trees as a file of the level and a node that draws them.
func _write_grove() -> void:
	if _grove.is_empty():
		return
	var plantings := Resource.new()
	for kind: String in _grove:
		# Gathered in arrays, which are kept by reference; written as buffers.
		var cells := {}
		for cell: Vector2i in _grove[kind].cells:
			cells[cell] = PackedFloat32Array(_grove[kind].cells[cell])
		plantings.set_meta(kind, {"cells": cells})
	var path := "%s%s_grove.res" % [OUT_DIR, _level_name()]
	ResourceSaver.save(plantings, path, ResourceSaver.FLAG_COMPRESS)
	plantings.take_over_path(path)
	var node := Node3D.new()
	node.name = "Grove"
	node.set_script(GROVE)
	node.set("plantings", plantings)
	if not _far_maps.is_empty():
		node.set("sun_map", _far_maps[0])
		node.set("sun_rect", _far_rect)
	_add(node, _root)


## A level for matches only has a start and no way out: see scripts/arena.gd.
func _check_route() -> void:
	if _route == null or _route.get_node_or_null("Start") == null:
		push_error("Route: the Alps need a start, for the arena to walk from")
