extends RefCounted
## The heights of the Ehrwald basin as the elevation tiles have them: AWS
## Terrain Tiles in the terrarium encoding (by Mapzen; for Austria they are the
## terrain model of data.gv.at at 10 m, CC BY), fetched by
## tools/fetch_map.py into assets/maps/alps/, where Godot does not import them.
##
## A spot is given in metres from the middle of the Moos, x to the east and z
## to the south, and its height is in metres over the sea. The tiles come at
## three zooms: 14 (6.5 m a pixel) over the basin, 13 (13 m) over the mountains
## round it, and 11 (52 m) out to twenty kilometres. Each zoom is put together
## into one grid, a spot is read from the finest that has it, and where one
## grid ends the next takes over gradually: the two do not quite agree.

const FOLDER := "res://assets/maps/alps/"
## The middle of the Moos, between Lermoos and Ehrwald.
const LAT := 47.405
const LON := 10.905
## The zooms, finest first, and the tiles of each: first x and y, and how
## many across and down.
const ZOOMS := [
	[14, Vector2i(8687, 5734), Vector2i(3, 3)],
	[13, Vector2i(4342, 2866), Vector2i(5, 4)],
	[11, Vector2i(1085, 716), Vector2i(3, 3)],
]
## Over how many pixels of a grid, from its edge in, the next coarser one
## gives way to it.
const SEAM := 24.0
## Finer than the tiles: the laser scans of the Land Tirol, laid out in the
## metres of this file by tools/fetch_dgm.py (in the same terrarium encoding):
## the file, where its first dot lies (x and z) and how far apart its dots
## are, finest first. Over the land a metre apart, round it five. Where a
## scan has nought, it has no height there.
const SCANS := [
	["dgm_1m.png", Vector2(-1700, -1300), 1.0],
	["dgm_5m.png", Vector2(-5500, -5300), 5.0],
]
## Over how many metres from its edge in a scan gives way to the next.
const SCAN_SEAM := [60.0, 400.0]

## Metres to a degree here, north and east.
var _north := 0.0
var _east := 0.0
## For every zoom: its first pixel (x, y), its size in pixels and its heights.
var _grids: Array[Dictionary] = []
## For every scan: where it lies, its size in dots and its heights.
var _scans: Array[Dictionary] = []


func _init() -> void:
	var phi := deg_to_rad(LAT)
	_north = 111132.954 - 559.822 * cos(2.0 * phi) + 1.175 * cos(4.0 * phi)
	_east = 111412.84 * cos(phi) - 93.5 * cos(3.0 * phi)
	for zoom: Array in ZOOMS:
		var first: Vector2i = zoom[1]
		var count: Vector2i = zoom[2]
		var size := count * 256
		var heights := PackedFloat32Array()
		heights.resize(size.x * size.y)
		for ty in count.y:
			for tx in count.x:
				var path := "%s%d_%d_%d.png" % [FOLDER, zoom[0], first.x + tx, first.y + ty]
				var tile := Image.load_from_file(ProjectSettings.globalize_path(path))
				if tile == null:
					push_error("Missing elevation tile %s: run tools/fetch_map.py alps" % path)
					continue
				var data := tile.get_data()
				var channels := 4 if tile.get_format() == Image.FORMAT_RGBA8 else 3
				for y in 256:
					var row := (ty * 256 + y) * size.x + tx * 256
					for x in 256:
						var at := (y * 256 + x) * channels
						heights[row + x] = data[at] * 256.0 + data[at + 1] + data[at + 2] / 256.0 - 32768.0
		_grids.append({"zoom": zoom[0], "first": first * 256, "size": size, "heights": heights})
	for scan: Array in SCANS:
		var picture := Image.load_from_file(ProjectSettings.globalize_path(FOLDER + scan[0]))
		if picture == null:
			push_error("Missing height scan %s: run tools/fetch_dgm.py" % scan[0])
			continue
		picture.convert(Image.FORMAT_RGB8)
		var data := picture.get_data()
		var count := picture.get_width() * picture.get_height()
		var heights := PackedFloat32Array()
		heights.resize(count)
		for i in count:
			var h := data[i * 3] * 256.0 + data[i * 3 + 1] + data[i * 3 + 2] / 256.0 - 32768.0
			heights[i] = NAN if h == 0.0 else h
		_scans.append({"at": scan[1], "cell": scan[2], "size": Vector2i(picture.get_width(), picture.get_height()), "heights": heights})


## The height over the sea at (x, z), in metres from the middle of the Moos:
## from the finest scan that has the spot, else from the tiles.
func altitude(x: float, z: float) -> float:
	var height := _tiles(x, z)
	for s in range(_scans.size() - 1, -1, -1):
		var scan: Dictionary = _scans[s]
		var cell: float = scan.cell
		var at := (Vector2(x, z) - (scan.at as Vector2)) / cell
		var size := Vector2(scan.size as Vector2i)
		var inside := minf(minf(at.x, at.y), minf(size.x - 1.0 - at.x, size.y - 1.0 - at.y)) * cell
		# Two dots from the edge, which the smooth reading needs on every side.
		if inside < 2.0 * cell:
			continue
		var here := _from_scan(scan, at)
		if is_nan(here):
			continue
		height = here if is_nan(height) else lerpf(height, here, clampf((inside - 2.0 * cell) / SCAN_SEAM[s], 0.0, 1.0))
	return 0.0 if is_nan(height) else height


## The height of a scan between its dots, at `at` in dots: bilinear a metre
## apart, where the scan is fine enough for that to show no facets, and
## smooth through the dots (Catmull-Rom) further apart.
func _from_scan(scan: Dictionary, at: Vector2) -> float:
	var heights: PackedFloat32Array = scan.heights
	var width: int = scan.size.x
	if scan.cell > 2.0:
		return _bicubic({"heights": heights, "size": scan.size}, at)
	var x0 := floori(at.x)
	var y0 := floori(at.y)
	var tx := at.x - x0
	var ty := at.y - y0
	var i := y0 * width + x0
	return lerpf(lerpf(heights[i], heights[i + 1], tx), lerpf(heights[i + width], heights[i + width + 1], tx), ty)


## The height over the sea at (x, z) as the elevation tiles have it.
func _tiles(x: float, z: float) -> float:
	var lat := LAT - z / _north
	var lon := LON + x / _east
	var height := NAN
	# From the coarsest grid that has the spot to the finest.
	for g in range(_grids.size() - 1, -1, -1):
		var grid: Dictionary = _grids[g]
		var at := _pixel(grid.zoom, lat, lon) - Vector2(grid.first)
		var size := Vector2(grid.size)
		var inside := minf(minf(at.x, at.y), minf(size.x - 1.0 - at.x, size.y - 1.0 - at.y))
		if inside < 2.0:
			continue
		var here := _bicubic(grid, at)
		height = here if is_nan(height) else lerpf(height, here, clampf((inside - 2.0) / SEAM, 0.0, 1.0))
	return height


## Where (lat, lon) lies in the pixels of all the world at `zoom`.
func _pixel(zoom: int, lat: float, lon: float) -> Vector2:
	var world := 256.0 * float(1 << zoom)
	var phi := deg_to_rad(lat)
	return Vector2((lon + 180.0) / 360.0 * world, (1.0 - log(tan(phi) + 1.0 / cos(phi)) / PI) * 0.5 * world) - Vector2(0.5, 0.5)


## The height of a grid between its pixels, smooth through them: a
## Catmull-Rom spline both ways, so that the ground has no crease along the
## rows and columns of the tiles.
func _bicubic(grid: Dictionary, at: Vector2) -> float:
	var heights: PackedFloat32Array = grid.heights
	var width: int = grid.size.x
	var x0 := floori(at.x)
	var y0 := floori(at.y)
	var tx := at.x - x0
	var ty := at.y - y0
	var rows := PackedFloat32Array([0, 0, 0, 0])
	for j in 4:
		var i := (y0 - 1 + j) * width + x0 - 1
		rows[j] = _spline(heights[i], heights[i + 1], heights[i + 2], heights[i + 3], tx)
	return _spline(rows[0], rows[1], rows[2], rows[3], ty)


func _spline(a: float, b: float, c: float, d: float, t: float) -> float:
	return b + 0.5 * t * (c - a + t * (2.0 * a - 5.0 * b + 4.0 * c - d + t * (3.0 * (b - c) + d - a)))
