extends Node
## What the enemies of a level know together, so that a fight is more than
## each of them walking up to the player on its own: where there is cover and
## who has taken it, whose turn it is to shoot, who goes round, and where
## something is about to go off.
##
## Cover is surveyed once per level, from the navmesh: spots a pace apart over
## every floor it has. The ones with something beside them at knee height are
## kept and moved up against it. Whether such a spot really hides someone from
## the player is only looked at when one is asked for, see find_cover().
##
## Shooting goes by turns. An enemy that wants to attack asks for one, and
## there are only so many at a time (Settings.rules().attackers), with a
## pause after each: the others wait behind something or move. That is what
## leaves the player room to move as well, and what makes a fight read as one.

const WORLD := 1
## Distance between the spots the survey looks at.
const GRID := 1.0
## Heights above the floor at which something counts as cover: to crouch
## behind, and to stand behind.
const LOW := 0.55
const HIGH := 1.3
## How far from a spot what covers it may stand, and how close to it somebody
## who takes cover there stands.
const NEAR := 1.6
const HUG := 0.6
## Half the width of somebody who has to fit behind something.
const SHOULDER := 0.32
## A point of the navmesh hovers over the floor it belongs to, by a quarter to
## half a metre: how much depends on where the lowest collider of the level
## lies. Up to this much higher or lower it is still the same floor, and how
## far it is from a point on the floor is measured flat, see _flat().
const HOVER := 0.6
## The survey looks from a finger's breadth beside each spot and never from
## the spot itself. Spots lie on whole metres, and a level is built on those
## and on parts of them: a ray from a spot runs along the faces of walls and
## crates, past their corners and on to exactly where the next wall begins,
## and whether it hits is decided in its last digit. That digit is not the
## same from one build of a level to the next. Jolt keeps the shapes of a
## body relative to the centre of all of them, so every hit moves a hair when
## a collider is added, taken away or moved up the list anywhere in the level.
const ASIDE := Vector3(0.005625, 0.00375, 0.01125)
## Two distances that differ by less than this are the same distance.
const HAIR := 0.0015
const AROUND := 8
## Spots that are looked at properly, out of the ones that seem best.
const SHORTLIST := 8
## A turn to attack that is not given back lapses after this long.
const TURN_TIME := 6.0
## Somebody who asked for a turn this long ago is no longer waiting for one.
const WAITING := 0.3
## An enemy is this likely to go round the player when there is room for one
## more to do so.
const FLANK_CHANCE := 0.4

## Spots with cover, and for each what stands around it low and high: a bit
## for every one of AROUND directions.
var _spots := PackedVector3Array()
var _low := PackedInt32Array()
var _high := PackedInt32Array()
## Spots out in the open: somewhere to run to.
var _open := PackedVector3Array()
## Index of a spot -> the enemy that has taken it.
var _held := {}
## Enemy -> seconds its turn to attack has lasted.
var _turns := {}
## Enemy -> [when it started asking for a turn, when it last asked].
var _asking := {}
## Seconds left of the pauses after turns that were used: each keeps a turn
## from being handed on at once.
var _rests: Array[float] = []
var _flankers: Array[Node3D] = []
var _clock := 0.0
## What the survey was made of: a level, and the navmesh it had then.
var _surveyed := [0, 0]
## True once a level has asked for its survey ahead of the first fight: it
## is then made as soon as the navmesh is there, and again if that changes.
var _ahead := false
## Where in the level there is fighting: the survey looks nowhere else. With
## nothing here it looks at all of the navmesh.
var _grounds: Array[AABB] = []
## For whoever measures: when this is a list, every look for cover adds the
## milliseconds it took.
var timed: Variant = null


func _ready() -> void:
	process_physics_priority = -10


func _physics_process(delta: float) -> void:
	_clock += delta
	for enemy: Variant in _turns.keys():
		if not _fights(enemy) or _turns[enemy] > TURN_TIME:
			_turns.erase(enemy)
		else:
			_turns[enemy] += delta
	for enemy: Variant in _asking.keys():
		if not _fights(enemy) or _clock - _asking[enemy][1] > WAITING:
			_asking.erase(enemy)
	for index: int in _held.keys():
		if not _fights(_held[index]):
			_held.erase(index)
	_flankers = _flankers.filter(_fights)
	if _ahead:
		_survey()
	for i in range(_rests.size() - 1, -1, -1):
		_rests[i] -= delta
		if _rests[i] <= 0.0:
			_rests.remove_at(i)


## Tells where in the level that is loading there is fighting to be done,
## so that the survey can leave out the land around it. The level says so
## before anybody asks for cover.
func fight_in(grounds: Array[AABB]) -> void:
	_grounds = grounds
	_surveyed = [0, 0]
	_ahead = false


## Surveys the level as soon as its navmesh is there, instead of when cover
## is first asked for, which is in the middle of a fight.
func prepare() -> void:
	_ahead = true
	_survey()


# --- Turns -------------------------------------------------------------------


## True if `enemy` may attack now. It keeps its turn until it gives it back
## with done_attacking(). Whoever has waited longest goes first.
func may_attack(enemy: Node3D) -> bool:
	if _turns.has(enemy):
		return true
	if not _asking.has(enemy):
		_asking[enemy] = [_clock, _clock]
	_asking[enemy][1] = _clock
	var free: int = Settings.rules().attackers - _turns.size() - _rests.size()
	if free <= 0:
		return false
	var ahead := 0
	for other: Node3D in _asking:
		if other != enemy and _asking[other][0] < _asking[enemy][0]:
			ahead += 1
	if ahead >= free:
		return false
	_asking.erase(enemy)
	_turns[enemy] = 0.0
	return true


## Gives a turn back. One that was `used` to attack is followed by a pause
## (Settings.rules().rest) before anybody else gets it: the moments in which
## nobody shoots are when the player gets to do something.
func done_attacking(enemy: Node3D, used := true) -> void:
	if _turns.erase(enemy) and used:
		_rests.append(Settings.rules().rest)


## How many are attacking at this moment.
func attacking() -> int:
	return _turns.size()


## True if `enemy` is to go round the player instead of facing it: one or two
## of a group that is large enough do.
func goes_round(enemy: Node3D) -> bool:
	if _flankers.has(enemy):
		return true
	if _flankers.size() >= Settings.rules().flankers or randf() > FLANK_CHANCE:
		return false
	var fighters := 0
	for other in get_tree().get_nodes_in_group("enemy"):
		if other.get("takes_cover") == true and other.is_alert():
			fighters += 1
	if fighters < 3:
		return false
	_flankers.append(enemy)
	return true


func done_flanking(enemy: Node3D) -> void:
	_flankers.erase(enemy)


func is_flanking(enemy: Node3D) -> bool:
	return _flankers.has(enemy)


# --- Cover -------------------------------------------------------------------


## Looks for somewhere for `seeker` to fight `foe` from, which is where the
## foe's eyes are. `wants` says what suits it: `reach`, how far it will walk;
## `nearest` and `farthest`, the distances to the foe to stay between, and
## `ideal`, the one it likes best; `eyes`, the height it looks and shoots
## from; `drop`, how far its head comes down if it can duck behind something
## low; `flank`, whether it is going round; `not`, the index of a spot it has
## had enough of; and `tried`, a list that the spots that turned out to be no
## good are added to, so that the next look goes further afield.
##
## Returns {index, at, fire, crouch}, or nothing if there is no such place.
## `at` is where it cannot be seen, and `fire` where it shoots from: a step
## to the side of it, or the same spot standing up if `crouch` is set.
func find_cover(seeker: Node3D, foe: Vector3, wants: Dictionary) -> Dictionary:
	if not _survey():
		return {}
	if timed is Array:
		var began := Time.get_ticks_usec()
		var found := _find_cover(seeker, foe, wants)
		timed.append((Time.get_ticks_usec() - began) / 1000.0)
		return found
	return _find_cover(seeker, foe, wants)


func _find_cover(seeker: Node3D, foe: Vector3, wants: Dictionary) -> Dictionary:
	var from := seeker.global_position
	var space := seeker.get_world_3d().direct_space_state
	var map := seeker.get_world_3d().navigation_map
	var reach: float = wants.get("reach", 14.0)
	var nearest: float = wants.get("nearest", 5.0)
	var farthest: float = wants.get("farthest", 24.0)
	var ideal: float = wants.get("ideal", 11.0)
	var eyes: float = wants.get("eyes", 1.5)
	# How far its head comes down when it ducks; 0 for one that cannot.
	var drop: float = wants.get("drop", 0.0)
	var flank: bool = wants.get("flank", false)
	var skip: int = wants.get("not", -1)
	var tried: Array = wants.get("tried", [])
	# Where the others are, as seen from the foe: going round is going
	# somewhere else.
	var front := _front(seeker, foe)
	var own := Vector2(from.x - foe.x, from.z - foe.z).normalized()

	var best: Array[int] = []
	var scores: Array[float] = []
	for i in _spots.size():
		var at := _spots[i]
		if i == skip or absf(at.y - from.y) > 2.0 or tried.has(i):
			continue
		var walk := Vector2(at.x - from.x, at.z - from.z).length()
		if walk > reach:
			continue
		var away := Vector2(at.x - foe.x, at.z - foe.z)
		var distance := away.length()
		if distance < nearest or distance > farthest:
			continue
		var holder: Variant = _held.get(i)
		if holder != null and holder != seeker and _fights(holder):
			continue
		var bit := _bit(at, foe)
		var facing := (1 << bit) | (1 << ((bit + 1) % AROUND)) | (1 << ((bit + AROUND - 1) % AROUND))
		if (_low[i] | _high[i]) & facing == 0:
			continue
		var score := -walk - absf(distance - ideal) * 0.6
		var side := away / maxf(distance, 0.01)
		if flank:
			# A good way round is well to the side of where the rest stand.
			score += 14.0 * clampf(1.0 - side.dot(front), 0.0, 1.3)
		elif side.dot(own) < 0.0:
			# The far side of the foe means running past it.
			score -= 8.0
		var place := scores.size()
		while place > 0 and scores[place - 1] < score:
			place -= 1
		if place < SHORTLIST:
			scores.insert(place, score)
			best.insert(place, i)
			if scores.size() > SHORTLIST:
				scores.pop_back()
				best.pop_back()

	for i in best:
		var at := _spots[i]
		if not threat(at).is_empty() or Blast.burning(at, 1.0):
			continue
		var found := _suits(space, map, at, foe, eyes, drop)
		if found.is_empty():
			tried.append(i)
			continue
		# Not somewhere the other side of a wall.
		var path := NavigationServer3D.map_get_path(map, from, at, true)
		if path.is_empty() or path[-1].distance_to(at) > 1.0 or _length(path) > from.distance_to(at) * 1.7 + 5.0:
			tried.append(i)
			continue
		found.index = i
		return found
	return {}


## Marks a spot as taken, and gives up whatever `enemy` held before.
func take(enemy: Node3D, index: int) -> void:
	leave(enemy)
	_held[index] = enemy


func leave(enemy: Node3D) -> void:
	for index: int in _held.keys():
		if _held[index] == enemy:
			_held.erase(index)


## Somewhere for `seeker` to run to from what is about to go off (see
## threat()): out of its reach if it can get that far, and otherwise as far
## as it gets, behind something if there is anything.
func find_refuge(seeker: Node3D, from_what: Dictionary) -> Vector3:
	var from := seeker.global_position
	var centre: Vector3 = from_what.at
	var clear: float = from_what.radius + 0.5
	var out := from - centre
	out.y = 0.0
	if out.length() < 0.1:
		out = seeker.global_basis.z
	var map := seeker.get_world_3d().navigation_map
	# If nothing better turns up: straight away from it.
	var refuge := NavigationServer3D.map_get_closest_point(map, from + out.normalized() * maxf(clear - out.length() + 1.0, 2.0))
	if not _survey():
		return refuge
	var space := seeker.get_world_3d().direct_space_state
	var best: Array[Vector3] = []
	var scores: Array[float] = []
	for spots: PackedVector3Array in [_spots, _open]:
		for at in spots:
			if absf(at.y - from.y) > 2.0:
				continue
			var walk := Vector2(at.x - from.x, at.z - from.z).length()
			if walk > 12.0 or walk < 1.5:
				continue
			var gap := Vector2(at.x - centre.x, at.z - centre.z).length()
			# Half its reach away is the least that is worth running to.
			if gap < clear * 0.5:
				continue
			var score := minf(gap, clear) * 2.0 - walk
			# Not through it to get there.
			if (at - from).normalized().dot(-out.normalized()) > 0.3 and walk > out.length():
				score -= 15.0
			var place := scores.size()
			while place > 0 and scores[place - 1] < score:
				place -= 1
			if place < SHORTLIST:
				scores.insert(place, score)
				best.insert(place, at)
				if scores.size() > SHORTLIST:
					scores.pop_back()
					best.pop_back()
	# Of the best of those: one that something stands in front of, if it is
	# still within reach of the blast, and that can be walked to.
	var top := -INF
	for i in best.size():
		var at := best[i]
		var score := scores[i]
		if Blast.burning(at, 1.0):
			continue
		if Vector2(at.x - centre.x, at.z - centre.z).length() < clear:
			var sheltered := _blocked(space, centre + Vector3.UP * 0.3, at + Vector3.UP * 0.9) and _blocked(space, centre + Vector3.UP * 0.3, at + Vector3.UP * 1.5)
			score += 5.0 if sheltered else -3.0
		if score <= top:
			continue
		var path := NavigationServer3D.map_get_path(map, from, at, true)
		if path.is_empty() or path[-1].distance_to(at) > 1.0 or _length(path) > from.distance_to(at) * 1.5 + 2.0:
			continue
		top = score
		refuge = at
	return refuge


# --- Danger ------------------------------------------------------------------


## What is about to go off within reach of `at`: {at, radius, left} of the
## nearest such thing, or nothing. Anything in the group "hazard" can say so
## of itself with a method danger() that returns the same.
func threat(at: Vector3) -> Dictionary:
	var worst := {}
	var closest := INF
	for hazard in get_tree().get_nodes_in_group("hazard"):
		var danger: Dictionary = hazard.danger()
		if danger.is_empty():
			continue
		var gap: float = (danger.at as Vector3).distance_to(at)
		if gap < danger.radius and gap < closest:
			closest = gap
			worst = danger
	return worst


# --- The survey --------------------------------------------------------------


## Surveys the level that is loaded, if that is still to be done. False if
## there is nothing to survey yet.
func _survey() -> bool:
	var scene := get_tree().current_scene
	var region := scene.get_node_or_null("NavigationRegion3D") as NavigationRegion3D if scene else null
	if region == null:
		return false
	var map := region.get_navigation_map()
	var made := NavigationServer3D.map_get_iteration_id(map)
	if made == 0:
		return false
	if _surveyed == [scene.get_instance_id(), made]:
		return true
	var navmesh := region.navigation_mesh
	var to_world := region.global_transform
	var corners := navmesh.get_vertices()
	# A navmesh that has just been baked is only on the map a few frames
	# later. Until then the map knows of no floor to put a spot on.
	if corners.is_empty() or NavigationServer3D.map_get_closest_point_owner(map, to_world * corners[0]) != region.get_rid():
		return false
	_surveyed = [scene.get_instance_id(), made]
	_spots.clear()
	_low.clear()
	_high.clear()
	_open.clear()
	_held.clear()
	var space := region.get_world_3d().direct_space_state
	var looked := {}
	var kept := {}
	for p in navmesh.get_polygon_count():
		var outline := PackedVector2Array()
		var points: Array[Vector3] = []
		var from := Vector2(INF, INF)
		var to := Vector2(-INF, -INF)
		for corner in navmesh.get_polygon(p):
			var point := to_world * corners[corner]
			points.append(point)
			outline.append(Vector2(point.x, point.z))
			from = from.min(outline[-1])
			to = to.max(outline[-1])
		if points.size() < 3:
			continue
		if not _grounds.is_empty():
			# Most of a level's navmesh is the land around it, in few and
			# large polygons: only the part of one that reaches the fighting.
			var reach := Rect2()
			for ground in _grounds:
				var floor_of := Rect2(ground.position.x, ground.position.z, ground.size.x, ground.size.z)
				reach = floor_of if reach.size == Vector2.ZERO else reach.merge(floor_of)
			from = from.max(reach.position)
			to = to.min(reach.end)
		var plane := Plane(points[0], points[1], points[2])
		if absf(plane.normal.y) < 0.5:
			continue
		for x in range(ceili(from.x / GRID), floori(to.x / GRID) + 1):
			for z in range(ceili(from.y / GRID), floori(to.y / GRID) + 1):
				var flat := Vector2(x, z) * GRID
				if not Geometry2D.is_point_in_polygon(flat, outline):
					continue
				var y := (plane.d - plane.normal.x * flat.x - plane.normal.z * flat.y) / plane.normal.y
				var cell := Vector3i(x, roundi(y * 2.0), z)
				if looked.has(cell):
					continue
				looked[cell] = true
				var at := Vector3(flat.x, y, flat.y)
				if _grounds.is_empty() or _grounds.any(func(ground: AABB) -> bool: return ground.has_point(at + Vector3.UP * 0.5)):
					_look_at(space, map, at, kept)
	return true


## Files one spot of the survey: as cover if something stands by it, moved
## up against that, or else as open floor.
func _look_at(space: PhysicsDirectSpaceState3D, map: RID, at: Vector3, kept: Dictionary) -> void:
	at = _on_floor(space, at)
	var closest := INF
	var towards := Vector3.ZERO
	for i in AROUND:
		var way := _way(i)
		var gap := _feel(space, at, LOW, way)
		# In the middle between two walls the first way round wins, whatever
		# the last digit of either says.
		if gap < closest - HAIR:
			closest = gap
			towards = way
	if closest == INF:
		_open.append(at)
		return
	if closest > HUG + HAIR:
		# Asked from a hair beside it as well: a spot that walks up to a
		# pillar on its own line would otherwise end up left or right of it
		# by the last digit.
		var moved := NavigationServer3D.map_get_closest_point(map, at + towards * (closest - HUG) + ASIDE)
		if _flat(moved, at) < NEAR and absf(moved.y - at.y) < HOVER:
			at = _on_floor(space, moved)
	# Two spots that were moved up against the same thing may have met.
	var cell := Vector3i(((at + ASIDE) * 2.0).round())
	if kept.has(cell):
		return
	kept[cell] = true
	var low := 0
	var high := 0
	for i in AROUND:
		var way := _way(i)
		if _feel(space, at, LOW, way) < INF:
			low |= 1 << i
		if _feel(space, at, HIGH, way) < INF:
			high |= 1 << i
	_spots.append(at)
	_low.append(low)
	_high.append(high)


## How far from `at` something stands in the direction `way`, at `height`
## above the floor: INF if nothing does within NEAR. Looked at from a hair
## beside the spot, see ASIDE, and measured from the spot.
func _feel(space: PhysicsDirectSpaceState3D, at: Vector3, height: float, way: Vector3) -> float:
	var from := at + ASIDE + Vector3.UP * height
	var hit := _ray(space, from, from + way * NEAR)
	# A fuel barrel is nothing to hide behind.
	if hit.is_empty() or (hit.collider as Node).is_in_group("explosive"):
		return INF
	return ((hit.position as Vector3) - at).dot(way)


## The navmesh hovers over the floor by up to half a metre, and what counts
## as cover is measured from the floor. That is looked for from a hair beside
## `at` as well, see ASIDE: a spot may lie on the seam between two floors.
func _on_floor(space: PhysicsDirectSpaceState3D, at: Vector3) -> Vector3:
	var from := Vector3(at.x + ASIDE.x, at.y + 0.3, at.z + ASIDE.z)
	var ground := _ray(space, from, from + Vector3.DOWN * 1.5)
	return Vector3(at.x, ground.position.y, at.z) if ground else at


## Whether somebody at `at` is hidden from `foe` and can still shoot at it:
## {at, fire, crouch}, or nothing.
func _suits(space: PhysicsDirectSpaceState3D, map: RID, at: Vector3, foe: Vector3, eyes: float, drop: float) -> Dictionary:
	var aim := foe - Vector3.UP * 0.25
	var ahead := foe - at
	ahead.y = 0.0
	ahead = ahead.normalized()
	var across := ahead.cross(Vector3.UP)
	if _hides(space, foe, at, across, [eyes + 0.15, eyes * 0.7]):
		# Hidden standing up: it shoots from a step to the side.
		for step: Vector3 in [across * 1.2, -across * 1.2, across * 1.9, -across * 1.9, across * 1.2 + ahead * 0.8, -across * 1.2 + ahead * 0.8]:
			var spot := NavigationServer3D.map_get_closest_point(map, at + step)
			if _flat(spot, at + step) > 0.45 or absf(spot.y - at.y) > HOVER:
				continue
			spot = _on_floor(space, spot)
			# The step itself has to be walkable in a straight line.
			if _blocked(space, at + Vector3.UP * 0.5, spot + Vector3.UP * 0.5):
				continue
			if not _blocked(space, spot + Vector3.UP * eyes, aim):
				return {"at": at, "fire": spot, "crouch": false}
		return {}
	if drop <= 0.0:
		return {}
	# Hidden ducked down, to the top of its head: it shoots standing up
	# where it is.
	var ducked := eyes - drop
	if _hides(space, foe, at, across, [ducked + 0.22, ducked * 0.5]) and not _blocked(space, at + Vector3.UP * eyes, aim):
		return {"at": at, "fire": at, "crouch": true}
	return {}


## True if somebody at `at` cannot be seen from `foe` at any of `heights`:
## not down the middle, and not at either shoulder. A spot at the very edge
## of what hides it hides half of whoever stands there.
func _hides(space: PhysicsDirectSpaceState3D, foe: Vector3, at: Vector3, across: Vector3, heights: Array) -> bool:
	for height: float in heights:
		for side: float in [0.0, -SHOULDER, SHOULDER]:
			if not _blocked(space, foe, at + Vector3.UP * height + across * side):
				return false
	return true


## Which way, seen from `foe`, the enemies other than `seeker` stand.
func _front(seeker: Node3D, foe: Vector3) -> Vector2:
	var sum := Vector2.ZERO
	for other: Node3D in get_tree().get_nodes_in_group("enemy"):
		if other != seeker and other.is_alert():
			sum += Vector2(other.global_position.x - foe.x, other.global_position.z - foe.z).normalized()
	if sum.length() < 0.01:
		var from := seeker.global_position
		return Vector2(from.x - foe.x, from.z - foe.z).normalized()
	return sum.normalized()


func _fights(enemy: Variant) -> bool:
	return is_instance_valid(enemy) and not enemy.dead and enemy.can_process()


## The direction, out of AROUND, in which `to` lies from `from`.
func _bit(from: Vector3, to: Vector3) -> int:
	return posmod(roundi(atan2(to.z - from.z, to.x - from.x) / TAU * AROUND), AROUND)


func _way(i: int) -> Vector3:
	return Vector3(cos(TAU * i / AROUND), 0.0, sin(TAU * i / AROUND))


## How far apart two points are over the floor, whatever their heights.
func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, WORLD))


func _blocked(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	return not _ray(space, from, to).is_empty()


func _length(path: PackedVector3Array) -> float:
	var length := 0.0
	for i in path.size() - 1:
		length += path[i].distance_to(path[i + 1])
	return length
