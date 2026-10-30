extends RefCounted
## A way over the navmesh from one spot to another, as
## NavigationServer3D.map_get_path() finds it, but searching as far as it
## takes. That one gives up after 4096 polygons and returns the way to
## whatever it had come nearest to: on land of kilometres, whose navmesh
## follows the ground in squares of 128 m (tools/levels/alps/plan.gd), a way
## across the valley ended half-way.
##
## And the spot of the navmesh nearest another, as map_get_closest_point()
## finds it, but on such a map from the square the spot lies in: the map
## looks through every polygon of every square, 1.25 ms a time on the Alps,
## and the survey of cover asks it twenty thousand times.

static var _query := NavigationPathQueryParameters3D.new()
static var _result := NavigationPathQueryResult3D.new()


static func between(map: RID, from: Vector3, to: Vector3) -> PackedVector3Array:
	_query.map = map
	_query.start_position = from
	_query.target_position = to
	_query.path_search_max_polygons = 0
	_query.path_postprocessing = NavigationPathQueryParameters3D.PATH_POSTPROCESSING_CORRIDORFUNNEL
	_query.metadata_flags = NavigationPathQueryParameters3D.PATH_METADATA_INCLUDE_NONE
	NavigationServer3D.query_path(_query, _result)
	return _result.path


## The squares of a navmesh of kilometres by where they lie: {Vector2i: RID},
## the region of each, and how large a square is. See scripts/game.gd.
static var _squares := {}
static var _square := 0.0


## Takes the squares of the map that is loaded: `regions` by the place of
## their middle, each `square` metres.
static func know_squares(regions: Array[NavigationRegion3D], square: float) -> void:
	_squares.clear()
	_square = square
	if square <= 0.0:
		return
	for region: NavigationRegion3D in regions:
		var corners := region.navigation_mesh.get_vertices()
		if corners.is_empty():
			continue
		var box := AABB(corners[0], Vector3.ZERO)
		for corner in corners:
			box = box.expand(corner)
		var middle := box.get_center()
		_squares[Vector2i(floori(middle.x / square), floori(middle.z / square))] = region.get_rid()


## Forgets them, for a map without squares.
static func forget_squares() -> void:
	_squares.clear()
	_square = 0.0


## The spot of the navmesh of `map` nearest `at`: from the square it lies in,
## or where that has nothing right there, the nearest of it and the squares
## round it, as the floor near an edge may be the next one's, and a loft over
## the edge is in the square that reaches over it.
static func closest(map: RID, at: Vector3) -> Vector3:
	if _square <= 0.0:
		return NavigationServer3D.map_get_closest_point(map, at)
	var square := Vector2i(floori(at.x / _square), floori(at.z / _square))
	var region: Variant = _squares.get(square)
	if region == null or NavigationServer3D.region_get_map(region) != map:
		return NavigationServer3D.map_get_closest_point(map, at)
	var best := NavigationServer3D.region_get_closest_point(region, at)
	if best.distance_squared_to(at) < 0.25:
		return best
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var next: Variant = _squares.get(square + Vector2i(dx, dz))
			if next == null or (dx == 0 and dz == 0):
				continue
			var spot := NavigationServer3D.region_get_closest_point(next, at)
			if spot.distance_squared_to(at) < best.distance_squared_to(at):
				best = spot
	return best
