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
## Of what the plan says makes a spot better or worse, it knows an enemy close
## by, an enemy who sees the spot, somebody standing on it, how far the
## nearest enemy is and how near a friend, and whether somebody came back
## near it a moment ago; it draws from the best few, and puts whoever comes
## back anywhere on the ground of that spot. Distances are as the crow flies,
## not walked. scripts/match.gd makes one
## when a level has become an arena.

const WAY := preload("res://scripts/way.gd")
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
const SEEN_FROM := 80.0
## With friends about: how far from the nearest enemy somebody best comes
## back, in metres, and how near to the nearest friend. Nearer to the enemy
## counts three times as heavily as further off; further from a friend than
## that, and nearer to an enemy than to a friend, count against a spot too.
const FRONT := Vector2(35.0, 60.0)
const WITH_FRIENDS := 20.0
## Of the best spots, how many are drawn from: not always the same one.
const DRAWN := 6
## Somebody who came back makes the ground within CROWDED metres of where
## they did worth less for the next RECENT who come back: one after another
## would otherwise come back on the same spot, which the other side then
## only has to watch. What one of them costs a spot, in metres of FRONT.
const RECENT := 12
const CROWDED := 30.0
const CROWDING := 25.0
## A person, and not a bot, sees a spot from this far, in metres: who looks
## through a scope picks off whoever comes back where they can see it.
const WATCHED_FROM := 300.0
## How many of the spots a choice looks at closely, the best first: seeing
## costs two rays for every enemy.
const LOOKS := 24
## The most spots that are kept. A level with more floor than that has them
## further apart: the way to every spot is looked up three times, and over
## the land of the dunes each of those takes two thousandths of a second.
const MOST := 500
const NO_WAY := 1e9
## How far along the way to somewhere somebody faces who is put down, in metres.
const LOOKS_AHEAD := 4.0
## For hideouts(): how much further it may be to walk from one end than from
## the other, as a share of the walk between them; how far from either end
## it is at least; how many metres off the shortest way counts as a detour;
## and how far apart two of them are at least.
const FAIR := 0.12
const END_CLEAR := 25.0
const DETOUR := 15.0
const AWAY := 30.0

## Where somebody can stand, on the floor.
var spots := PackedVector3Array()
## Where the last RECENT came back, the latest last.
var _recent := PackedVector3Array()
## About how far apart the spots lie, in metres.
var _grid := GRID
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

	# The spots on that floor: GRID apart, or further on floor of kilometres,
	# where there would be a million and only MOST are kept.
	var floor_area := 0.0
	for p: int in walked:
		floor_area += absf(_area(outlines[p]))
	var grid := maxf(GRID, sqrt(floor_area / (MOST * 2.5)))
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
		for x in range(ceili(from.x / grid), floori(to.x / grid) + 1):
			for z in range(ceili(from.y / grid), floori(to.y / grid) + 1):
				var flat := Vector2(x, z) * grid + Vector2(0.37, 0.41)
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
	_grid = maxf(grid, sqrt(floor_area / spots.size()))

	# Its ends: the spot that is the longest walk from the start, and the one
	# that is the longest walk from that. Unless the level says where they
	# are (assets/arenas.json): then the spots nearest to those.
	var said := _said_ends(game)
	if said.size() == 2:
		for k in 2:
			var best := INF
			for i in spots.size():
				var gap := Vector2(spots[i].x - said[k].x, spots[i].z - said[k].z).length()
				if gap < best:
					best = gap
					ends[k] = i
		walks[0] = _walks_from(spots[ends[0]])
	else:
		var from_start := _walks_from(start)
		ends[0] = _furthest(from_start)
		walks[0] = _walks_from(spots[ends[0]])
		ends[1] = _furthest(walks[0])
	walks[1] = _walks_from(spots[ends[1]])
	took = (Time.get_ticks_usec() - began) / 1e6
	return true


## Where the level says its two sides begin, as assets/arenas.json has it
## under "ends", or nothing.
func _said_ends(game: Node3D) -> PackedVector3Array:
	var level := game.scene_file_path.get_file().get_basename()
	var path := "res://assets/arenas.json"
	var said: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	var ends_said := PackedVector3Array()
	if said is Dictionary and (said as Dictionary).get(level) is Dictionary:
		for end: Variant in (said[level] as Dictionary).get("ends", []):
			ends_said.append(Vector3(end[0], end[1], end[2]))
	return ends_said


## The area inside an outline, signed by which way it goes round.
func _area(outline: PackedVector2Array) -> float:
	var sum := 0.0
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


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
## at `friends`: a spot that none of the enemies sees, that no enemy is
## within TOO_NEAR of and that nobody stands on. Of those, with friends about,
## one near them and about FRONT from the nearest enemy: back in the fight in
## a few seconds, and not at the far end of an arena as big as the dunes.
## Ground where others came back a moment ago counts against a spot. Without
## friends, or where nothing near the fight is safe, the one furthest from
## the nearest enemy. If no spot is safe, the one furthest from them all,
## which is counted in `emergencies`.
##
## `among` narrows it down to those spots, as around() gives them: a base.
## `watchers` are those of `foes` who are people: they see as far as
## WATCHED_FROM, bots only SEEN_FROM.
func pick(foes: PackedVector3Array, friends: PackedVector3Array, among := PackedInt32Array(), watchers := PackedVector3Array()) -> Transform3D:
	var gaps := PackedFloat32Array()
	var worth := PackedFloat32Array()
	gaps.resize(spots.size())
	worth.resize(spots.size())
	for i in spots.size():
		var gap := INF
		for foe in foes:
			gap = minf(gap, spots[i].distance_to(foe))
		gaps[i] = gap
		worth[i] = gap
		if not friends.is_empty():
			var near := INF
			for friend in friends:
				near = minf(near, spots[i].distance_to(friend))
			var off := 0.0
			if not foes.is_empty():
				off = maxf(FRONT.x - gap, 0.0) * 3.0 + maxf(gap - FRONT.y, 0.0) + (30.0 if near > gap else 0.0)
			worth[i] = -(off + maxf(near - WITH_FRIENDS, 0.0))
		for back in _recent:
			if back.distance_to(spots[i]) < CROWDED:
				worth[i] -= CROWDING
	var order := Array(among) if not among.is_empty() else range(spots.size())
	order.sort_custom(func(a: int, b: int) -> bool: return worth[a] > worth[b])
	var good := _safe(order.slice(0, LOOKS), gaps, foes, friends, watchers, DRAWN if not friends.is_empty() else 1)
	if good.is_empty():
		# Where the fight is, everything may be in somebody's sight: then the
		# spots furthest from the enemy, as when there are no friends.
		order.sort_custom(func(a: int, b: int) -> bool: return gaps[a] - _crowd(a) > gaps[b] - _crowd(b))
		if not friends.is_empty():
			good = _safe(order.slice(0, LOOKS), gaps, foes, friends, watchers, 1)
	var best := -1
	if not good.is_empty():
		best = good.pick_random()
	else:
		emergencies += 1
		best = order[0]
	var at := _somewhere_on(best, foes, friends, watchers)
	_recent.append(at)
	if _recent.size() > RECENT:
		_recent.remove_at(0)
	var towards := _middle()
	for foe in foes:
		if towards == _middle() or foe.distance_to(at) < towards.distance_to(at):
			towards = foe
	return _facing(at, _ahead(at, towards))


## What the ground where others came back a moment ago takes off `spot`.
func _crowd(spot: int) -> float:
	var cost := 0.0
	for back in _recent:
		if back.distance_to(spots[spot]) < CROWDED:
			cost += CROWDING
	return cost


## Somewhere on the ground of `spot`: as far as halfway to the next spot,
## where there is room, nobody stands and nobody of `foes` or `watchers`
## sees it, else the spot itself. Spots of the dunes lie seven metres apart.
func _somewhere_on(spot: int, foes: PackedVector3Array, friends: PackedVector3Array, watchers: PackedVector3Array) -> Vector3:
	var grid := minf(_grid, 10.0)
	for i in 4:
		var try := spots[spot] + Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5)) * grid
		var on := NavigationServer3D.map_get_closest_point(_map, try)
		if on.distance_to(try) > 1.0 or _taken(on, foes) or _taken(on, friends) or not _room(on):
			continue
		var seen := false
		for foe in foes:
			if foe.distance_to(on) < SEEN_FROM and _sees(foe, on):
				seen = true
				break
		for watcher in watchers:
			if not seen and watcher.distance_to(on) < WATCHED_FROM and _sees(watcher, on):
				seen = true
		if not seen:
			return on
	return spots[spot]


## Of `candidates`, the first `wanted` that no enemy is too near to or sees
## and that nobody stands on. Of `watchers` it is as far as WATCHED_FROM.
func _safe(candidates: Array, gaps: PackedFloat32Array, foes: PackedVector3Array, friends: PackedVector3Array, watchers: PackedVector3Array, wanted: int) -> Array[int]:
	var good: Array[int] = []
	for spot: int in candidates:
		if gaps[spot] < TOO_NEAR or _taken(spots[spot], foes) or _taken(spots[spot], friends):
			continue
		var seen := false
		for foe in foes:
			if foe.distance_to(spots[spot]) < SEEN_FROM and _sees(foe, spots[spot]):
				seen = true
				break
		for watcher in watchers:
			if not seen and watcher.distance_to(spots[spot]) < WATCHED_FROM and _sees(watcher, spots[spot]):
				seen = true
		if not seen:
			good.append(spot)
			if good.size() >= wanted:
				break
	return good


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


## Kinds of a spot a little out of the way, see hideouts().
enum Hideout { OFF_THE_WAY, UP, IN_THE_OPEN }

## `kinds.size()` spots a little out of the way, for what is worth going out
## of one's way for: about as far to walk from either end, on a spot where
## somebody can stand, as far apart as they can be and at least AWAY metres,
## each of its own kind:
## - OFF_THE_WAY: a detour of DETOUR metres or more off the shortest walk
##   between the ends, into a room that does not lead on: in is easy, out is
##   a fight;
## - UP: well above the floor that most of the arena is on, up a stair or a
##   ramp;
## - IN_THE_OPEN: where whoever stands there is seen from much of the arena.
## A kind there is no such spot for gives the best of IN_THE_OPEN instead.
func hideouts(kinds: Array) -> PackedVector3Array:
	var fair: Array[int] = []
	for spot in spots.size():
		var near := minf(walks[0][spot], walks[1][spot])
		var far := maxf(walks[0][spot], walks[1][spot])
		if far < NO_WAY and far - near < FAIR * length() and near > END_CLEAR:
			fair.append(spot)
	if fair.is_empty():
		return PackedVector3Array()
	var heights := PackedFloat32Array()
	for spot in spots:
		heights.append(spot.y)
	heights.sort()
	@warning_ignore("integer_division")
	var ground := heights[heights.size() / 2]
	var chosen := PackedVector3Array()
	for kind: int in kinds:
		var best := -1
		var best_score := -INF
		for spot: int in fair:
			var at := spots[spot]
			var apart := INF
			for other in chosen:
				apart = minf(apart, at.distance_to(other))
			if apart < AWAY:
				continue
			var score := _out_of_the_way(spot, kind, ground)
			if score > best_score:
				best_score = score
				best = spot
		if best < 0 or best_score <= 0.0 and kind != Hideout.IN_THE_OPEN:
			# Nothing of that kind: the most open spot there is, as far from
			# the others as it can be.
			best = -1
			best_score = -INF
			for spot: int in fair:
				var apart := INF
				for other in chosen:
					apart = minf(apart, spots[spot].distance_to(other))
				var score := _out_of_the_way(spot, Hideout.IN_THE_OPEN, ground) + minf(apart, AWAY) * 0.01
				if best < 0 or score > best_score:
					best_score = score
					best = spot
		chosen.append(spots[best])
	return chosen


## How well `spot` is out of the way in the manner of `kind`; 0 or less if
## not at all.
func _out_of_the_way(spot: int, kind: int, ground: float) -> float:
	match kind:
		Hideout.OFF_THE_WAY:
			var detour := walks[0][spot] + walks[1][spot] - length()
			return minf(detour, DETOUR * 2.5) - DETOUR + 0.1
		Hideout.UP:
			return spots[spot].y - ground - 1.5
	# In the open: the share of a sample of the other spots that sees it.
	var seen := 0
	var asked := 0
	@warning_ignore("integer_division")
	var stride := maxi(spots.size() / 60, 1)
	for i in range(spot % 7, spots.size(), stride):
		if i == spot:
			continue
		asked += 1
		if _sees(spots[i], spots[spot]):
			seen += 1
	return float(seen) / maxi(asked, 1)


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
	var path := WAY.between(_map, from, to)
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


## How far it is to walk from `from` to `to`; NO_WAY where there is no way.
func walk(from: Vector3, to: Vector3) -> float:
	var path := WAY.between(_map, from, to)
	if path.is_empty() or path[-1].distance_to(to) > 1.5:
		return NO_WAY
	var length := 0.0
	for i in path.size() - 1:
		length += path[i].distance_to(path[i + 1])
	return length


## How far it is to walk from `from` to every spot; NO_WAY where there is none.
func _walks_from(from: Vector3) -> PackedFloat32Array:
	var lengths := PackedFloat32Array()
	for spot in spots:
		var path := WAY.between(_map, from, spot)
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
