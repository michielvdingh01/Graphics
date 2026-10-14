extends RefCounted
## What a match has to know of the level it is played in: the spots where
## somebody can stand, the two ends of it, and where to come back.
##
## None of that is set by hand. The spots are taken from the navmesh once it
## is baked: one every GRID metres on all the floor that can be walked to from
## where the level starts and that has room for somebody. The ends are the two
## spots that are the longest walk apart, which is where two teams begin.
## Where somebody comes back is chosen each time by where everybody stands at
## that moment, see pick().
##
## This is the first cut of it: of what the plan says makes a spot better or
## worse, it knows an enemy close by, an enemy who sees the spot and somebody
## standing on it. scripts/match.gd makes one when a level has become an arena.

const WORLD := 1
const GRID := 2.0
const EYE := 1.6
const CHEST := 1.1
## An enemy this near rules a spot out, in metres, and so does anybody at all
## standing this near.
const TOO_NEAR := 12.0
const TAKEN := 1.2
## Past this an enemy with a clear line to a spot is not counted as seeing
## it, when nothing nearer is safe.
const SEEN_FROM := 60.0
## How many of the spots a choice looks at closely, the furthest from the
## enemy first: seeing costs two rays for every enemy.
const LOOKS := 24
## The most spots that are kept. A level with more floor than that has them
## further apart: the way to every spot is looked up three times, and over
## the land of the dunes each of those takes two thousandths of a second.
const MOST := 500
const NO_WAY := 1e9
## How far along the way to somewhere somebody faces who is put down, in metres.
const LOOKS_AHEAD := 4.0

## Where somebody can stand, on the floor.
var spots := PackedVector3Array()
## The spots two teams begin at, as indices, and how far it is to walk from
## either of them to every spot.
var ends: Array[int] = [0, 0]
var walks: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
## How often nothing was safe and the least bad spot had to do.
var emergencies := 0
## The seconds it took to take the level apart.
var took := 0.0

var _space: PhysicsDirectSpaceState3D
var _map: RID


## Takes the level apart. False if there is no floor to play on.
func survey(game: Node3D) -> bool:
	var began := Time.get_ticks_usec()
	_space = game.get_world_3d().direct_space_state
	_map = game.get_world_3d().navigation_map
	var region: NavigationRegion3D = game.nav_region
	var mesh := region.navigation_mesh
	if mesh == null or mesh.get_polygon_count() == 0:
		return false
	var to_world := region.global_transform
	var corners := mesh.get_vertices()
	var start: Vector3 = game.start.origin

	# The polygons that can be walked to from the start.
	var at_edge := {}
	var first := -1
	var nearest := INF
	var outlines: Array[PackedVector2Array] = []
	for p in mesh.get_polygon_count():
		var polygon := mesh.get_polygon(p)
		var outline := PackedVector2Array()
		var middle := Vector3.ZERO
		for i in polygon.size():
			var edge := _edge(polygon, i)
			if not at_edge.has(edge):
				at_edge[edge] = PackedInt32Array()
			at_edge[edge].append(p)
			var corner := to_world * corners[polygon[i]]
			middle += corner / polygon.size()
			outline.append(Vector2(corner.x, corner.z))
		outlines.append(outline)
		var gap := middle.distance_to(start)
		if absf(middle.y - start.y) < 1.5 and Geometry2D.is_point_in_polygon(Vector2(start.x, start.z), outline):
			gap = 0.0
		if gap < nearest:
			nearest = gap
			first = p
	var todo: Array[int] = [first]
	var walked := {first: true}
	while not todo.is_empty():
		var polygon := mesh.get_polygon(todo.pop_back())
		for i in polygon.size():
			for other: int in at_edge[_edge(polygon, i)]:
				if not walked.has(other):
					walked[other] = true
					todo.append(other)

	# The spots on that floor.
	spots = PackedVector3Array()
	var looked := {}
	for p: int in walked:
		var polygon := mesh.get_polygon(p)
		var plane := Plane(to_world * corners[polygon[0]], to_world * corners[polygon[1]], to_world * corners[polygon[2]])
		if absf(plane.normal.y) < 0.5:
			continue
		var from := Vector2(INF, INF)
		var to := Vector2(-INF, -INF)
		for point in outlines[p]:
			from = from.min(point)
			to = to.max(point)
		for x in range(ceili(from.x / GRID), floori(to.x / GRID) + 1):
			for z in range(ceili(from.y / GRID), floori(to.y / GRID) + 1):
				var flat := Vector2(x, z) * GRID + Vector2(0.37, 0.41)
				if not Geometry2D.is_point_in_polygon(flat, outlines[p]):
					continue
				var y := (plane.d - plane.normal.x * flat.x - plane.normal.z * flat.y) / plane.normal.y
				var cell := Vector3i(x, roundi(y), z)
				if looked.has(cell):
					continue
				looked[cell] = true
				var at := Vector3(flat.x, y + 0.3, flat.y)
				var ground := _space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 1.5, WORLD))
				if ground and _room(ground.position):
					spots.append(ground.position)
	if spots.size() < 2:
		return false
	if spots.size() > MOST:
		var kept := PackedVector3Array()
		var stride := ceili(float(spots.size()) / MOST)
		for i in range(0, spots.size(), stride):
			kept.append(spots[i])
		spots = kept

	# Its ends: the spot that is the longest walk from the start, and the one
	# that is the longest walk from that.
	var from_start := _walks_from(start)
	ends[0] = _furthest(from_start)
	walks[0] = _walks_from(spots[ends[0]])
	ends[1] = _furthest(walks[0])
	walks[1] = _walks_from(spots[ends[1]])
	took = (Time.get_ticks_usec() - began) / 1e6
	return true


## How far it is to walk from one end to the other.
func length() -> float:
	return walks[0][ends[1]]


## Where `count` of a side stand as a match begins: the spots nearest to
## their end by walking, facing the way to the other end. Side -1 is nobody's:
## those are spread over the whole of the arena, each as far from the others
## as can be.
func line_up(side: int, count: int) -> Array[Transform3D]:
	var chosen: Array[int] = []
	if side < 0:
		chosen.append(ends[0])
		var nearest := walks[0].duplicate()
		while chosen.size() < mini(count, spots.size()):
			var next := _furthest(nearest)
			chosen.append(next)
			for i in spots.size():
				nearest[i] = minf(nearest[i], spots[i].distance_to(spots[next]))
	else:
		var order := range(spots.size())
		order.sort_custom(func(a: int, b: int) -> bool: return walks[side][a] < walks[side][b])
		chosen.assign(order.slice(0, count))
	var poses: Array[Transform3D] = []
	for i in count:
		var spot := chosen[i % chosen.size()]
		poses.append(_facing(spots[spot], _ahead(spots[spot], spots[ends[1 - side]] if side >= 0 else _middle())))
	return poses


## Where somebody comes back whose enemies stand at `foes` and whose friends
## at `friends`: the spot furthest from the nearest enemy that none of them
## sees and nobody stands on. If no spot is safe, the one furthest from them
## all, which is counted in `emergencies`.
##
## `among` narrows it down to those spots, as around() gives them: a base.
func pick(foes: PackedVector3Array, friends: PackedVector3Array, among := PackedInt32Array()) -> Transform3D:
	var gaps := PackedFloat32Array()
	gaps.resize(spots.size())
	for i in spots.size():
		var gap := INF
		for foe in foes:
			gap = minf(gap, spots[i].distance_to(foe))
		gaps[i] = gap
	var order := Array(among) if not among.is_empty() else range(spots.size())
	order.sort_custom(func(a: int, b: int) -> bool: return gaps[a] > gaps[b])
	var best := -1
	for spot: int in order.slice(0, LOOKS):
		if gaps[spot] < TOO_NEAR:
			break
		if _taken(spots[spot], foes) or _taken(spots[spot], friends):
			continue
		var seen := false
		for foe in foes:
			if foe.distance_to(spots[spot]) < SEEN_FROM and _sees(foe, spots[spot]):
				seen = true
				break
		if not seen:
			best = spot
			break
	if best < 0:
		emergencies += 1
		best = order[0]
	var towards := _middle()
	for foe in foes:
		if towards == _middle() or foe.distance_to(spots[best]) < towards.distance_to(spots[best]):
			towards = foe
	return _facing(spots[best], _ahead(spots[best], towards))


## The spots that are no nearer to the end of `side` than `from` metres to
## walk and no further than `to`: the ground around a base.
func around(side: int, from: float, to: float) -> PackedInt32Array:
	var found := PackedInt32Array()
	for spot in spots.size():
		if walks[side][spot] >= from and walks[side][spot] <= to:
			found.append(spot)
	return found


## A spot to walk to for want of anything better.
func anywhere() -> Vector3:
	return spots[randi() % spots.size()]


## A spot in the half of the arena that is nearer to the end of `side`: where
## that side is to be looked for.
func somewhere(side: int) -> Vector3:
	for i in 12:
		var spot := randi() % spots.size()
		if walks[side][spot] < walks[1 - side][spot]:
			return spots[spot]
	return anywhere()


## `count` spots between the two ends, about as far to walk from either, and
## as far from each other as that leaves room for: where something lies that
## is there for both sides.
func caches(count: int) -> PackedVector3Array:
	var order := range(spots.size()).filter(func(spot: int) -> bool: return walks[0][spot] < NO_WAY and walks[1][spot] < NO_WAY)
	order.sort_custom(func(a: int, b: int) -> bool: return absf(walks[0][a] - walks[1][a]) < absf(walks[0][b] - walks[1][b]))
	@warning_ignore("integer_division")
	var middle: Array = order.slice(0, maxi(order.size() / 5, count))
	var chosen := PackedVector3Array()
	while chosen.size() < count and not middle.is_empty():
		var best := 0
		var furthest := -1.0
		for i in middle.size():
			var gap := INF
			for other in chosen:
				gap = minf(gap, spots[middle[i]].distance_to(other))
			if chosen.is_empty():
				gap = float(-i)
			if gap > furthest:
				furthest = gap
				best = i
		chosen.append(spots[middle.pop_at(best)])
	return chosen


## True if somebody standing at `from` sees the head or the chest of somebody
## standing at `at`.
func _sees(from: Vector3, at: Vector3) -> bool:
	var eye := from + Vector3.UP * EYE
	for height: float in [EYE, CHEST]:
		if _space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, at + Vector3.UP * height, WORLD)).is_empty():
			return true
	return false


func _taken(at: Vector3, by: PackedVector3Array) -> bool:
	for other in by:
		if other.distance_to(at) < TAKEN:
			return true
	return false


## True if somebody can stand at `at`.
func _room(at: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), at + Vector3.UP * 1.0)
	query.collision_mask = WORLD | 16 | 32
	return _space.intersect_shape(query, 1).is_empty()


## Where the way from `from` to `to` is a few paces on: what somebody who
## sets out on it looks at, which is never the wall that the place itself
## lies behind.
func _ahead(from: Vector3, to: Vector3) -> Vector3:
	var path := NavigationServer3D.map_get_path(_map, from, to, true)
	var walked := 0.0
	for i in range(1, path.size()):
		walked += path[i - 1].distance_to(path[i])
		if walked >= LOOKS_AHEAD:
			return path[i]
	return path[-1] if path.size() > 1 else to


func _facing(at: Vector3, towards: Vector3) -> Transform3D:
	var way := towards - at
	way.y = 0.0
	if way.length_squared() < 0.01:
		way = Vector3.FORWARD
	return Transform3D(Basis.looking_at(way.normalized()), at)


func _middle() -> Vector3:
	return (spots[ends[0]] + spots[ends[1]]) * 0.5


## How far it is to walk from `from` to every spot; NO_WAY where there is none.
func _walks_from(from: Vector3) -> PackedFloat32Array:
	var lengths := PackedFloat32Array()
	for spot in spots:
		var path := NavigationServer3D.map_get_path(_map, from, spot, true)
		var length := NO_WAY
		if not path.is_empty() and path[-1].distance_to(spot) < 1.5:
			length = 0.0
			for i in path.size() - 1:
				length += path[i].distance_to(path[i + 1])
		lengths.append(length)
	return lengths


## The spot with the largest of `lengths` that there is a way to.
func _furthest(lengths: PackedFloat32Array) -> int:
	var far := 0
	for i in lengths.size():
		if lengths[i] < NO_WAY and (lengths[far] >= NO_WAY or lengths[i] > lengths[far]):
			far = i
	return far


func _edge(polygon: PackedInt32Array, i: int) -> Vector2i:
	var a := polygon[i]
	var b := polygon[(i + 1) % polygon.size()]
	return Vector2i(mini(a, b), maxi(a, b))
