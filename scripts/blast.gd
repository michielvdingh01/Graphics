extends Node
## What an explosion does: it hurts and throws whatever is near it and in the
## open, sets off other explosives, breaks the windows it can see, sears what
## can catch fire and shakes the player's view. A fire it leaves burns
## whoever stands in it and spreads to the stacks and the piles beside it, at
## most MAX_ALIGHT of them at once: see kindle(), heat() and _spread(). How
## any of that looks is up to Fx.explosion(), Fx.fire() and Fx.blaze().

signal exploded(position: Vector3)

const WORLD := 1
## Layers a blast looks for bodies on: player, enemy, debris, explosive and
## breakable. The level itself is one body of thousands of shapes with
## nothing to say to a blast, which is why whatever explodes or breaks is on
## a layer of its own as well.
const REACHED := 0b111110
## The most shapes a blast looks at. A lamp is one or two of them, a pile of
## crates up to three, and a dozen piles can stand around one barrel.
const MOST := 96
## Within this fraction of its radius a blast does all of its damage; from
## there it falls off to nothing at the edge.
const CORE := 0.25
## What the player takes of it, which leaves a mistake survivable.
const PLAYER_SHARE := 0.5
## Speed in m/s something at the centre is thrown at.
const PUSH := 9.0
## A fire hurts this much a second, in ticks this far apart.
const BURN_DAMAGE := 24.0
const BURN_TICK := 0.25
## How far outside its flames a fire still burns somebody, in metres: half
## the width of whoever stands there.
const BESIDE := 0.45
## The group of what can catch fire: the stacks of crates and boxes and the
## piles of pallets. Each of them has `girth`, how far it reaches sideways
## from where it stands, and `warm(fire, seconds)`, see _spread().
const TINDER := &"tinder"
## How far from the flames something still gets hot, in metres. The stacks of
## one pile of crates stand 0.6 to 1.1 m apart and catch from each other; an
## aisle is wider, and stops a fire.
const REACH := 1.2
## How much of the heat something took without catching it loses again, in
## seconds of fire a second.
const COOLING := 0.5
## How far above what burns its flames light something, in metres. That is
## less than a crate is high, so that a fire climbs a stack one crate at a
## time.
const CROWN := 0.3
## What stands that far off gets hot this many times as slowly as what the
## flames touch, and what stands as high as a fire lights at all this many
## times as slowly as what stands at its foot. What lies under a fire gets
## this share of it, from the embers that come down, if it is no deeper
## under it than DEPTH metres.
const FAR := 0.35
const HIGH := 0.6
const UNDER := 0.3
const DEPTH := 1.0
## How high above the floor burning fuel lights something, in metres: what
## stands on that floor beside it, and not the crate or the box on top of
## that. From there a fire climbs by itself, one crate at a time.
const LOW := 0.3
## The most fires on crates, boxes and pallets at once: every one of them is
## flames, a light and a column of smoke, and costs about what the fuel of a
## barrel does while it burns. What gets hot while there are that many waits
## its turn, and catches when one of them is out if a fire is still near it.
const MAX_ALIGHT := 4
## The fireball of an explosion lights what it does not break: it fills this
## share of the reach of the blast, and is as much heat as this many seconds
## of fire.
const FIREBALL := 0.45
const SEAR := 2.0

## Patches of floor on fire: {at, radius, left}. A patch says as well how far
## its flames reach from `at` and how high above it they light something,
## `flames` and `tall`, for how many seconds it has burnt since it last heated
## what is near it, `owed`, and has `tinder` if it is something that caught
## fire and not fuel.
var _burning: Array[Dictionary] = []
var _tick := 0.0


## Something goes off at `position`: `damage` at the centre, nothing beyond
## `radius`. `size` is how large it looks, 1 for a fuel barrel, and `source`
## the body that is exploding, if it is still there to be in the way. `by` is
## who set it off, as a match numbers those who play, 0 for nobody.
##
## In a game with others the host does the harm and everybody sees the blast;
## on a guest this asks the host for it, as a grenade of its player does.
func explode(position: Vector3, radius: float, damage: float, size := 1.0, source: CollisionObject3D = null, by := 0) -> void:
	if Net.is_guest():
		Net.ask(self, &"explode", [position, radius, damage, size, null, by])
		return
	Net.show(self, &"_show_blast", [position, radius, size])

	var space := get_viewport().find_world_3d().direct_space_state
	var ball := SphereShape3D.new()
	ball.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.transform = Transform3D(Basis(), position)
	query.collision_mask = REACHED
	var reached := {}
	for found: Dictionary in space.intersect_shape(query, MOST):
		reached[found.collider] = true
	var ignored: Array[RID] = []
	if source:
		ignored.append(source.get_rid())
	reached.erase(source)
	var through := _through(ignored)
	# The glass of the windows is on none of those layers: a wall of panes
	# would leave no room among the MOST for anything else. Every window sees
	# for itself which of its panes are within reach, the nearest window
	# first: only so many panes leave shards, see Fx.pane().
	var windows: Array[Array] = []
	for window in get_tree().get_nodes_in_group("window"):
		var distance: float = window.distance_to(position)
		if distance < radius:
			windows.append([distance, window])
	windows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for found in windows:
		found[1].blast(position, radius, through)
	# How hard it hits each of them is worked out before any of them is hurt:
	# a stack of crates that it breaks still stood in the way of whatever was
	# behind it.
	var struck: Array[Array] = []
	for body: Node3D in reached:
		var middle := _middle(body)
		var offset := middle - position
		var strength := clampf(1.0 - (offset.length() - radius * CORE) / (radius * (1.0 - CORE)), 0.0, 1.0)
		strength *= _exposure(space, position, body, ignored)
		if strength > 0.0:
			struck.append([body, middle, offset, strength])
	for hit: Array in struck:
		var body: Node3D = hit[0]
		var middle: Vector3 = hit[1]
		var offset: Vector3 = hit[2]
		var strength: float = hit[3]
		# Things are thrown outwards and a little up, off the floor.
		var away := (offset.normalized() + Vector3.UP * 0.4).normalized()
		var player := body.is_in_group("player")
		# A blast is not a bullet: no plate in front of somebody stops it.
		if Match.active and Match.plays(body):
			# In a match it is whose blast it was that counts, and it does to
			# a player what it does to anybody.
			Match.harm(Match.number(body), damage * strength, middle, away * 2.5, by, Match.BLAST)
		elif body.has_method("take_blast"):
			body.take_blast(damage * strength, middle, away * 2.5)
		elif body.has_method("take_damage"):
			body.take_damage(damage * strength * (PLAYER_SHARE if player else 1.0), middle, away * 2.5)
		if body.has_method("shove"):
			# Somebody else's player: that is up to their own machine.
			body.shove(away * PUSH * strength)
		elif body is CharacterBody3D:
			body.velocity += away * PUSH * strength
		elif body is RigidBody3D:
			body.apply_central_impulse(away * PUSH * strength * body.mass)
	_sear(space, position, radius, through)


## What a blast looks and sounds like, and how it rattles the view of the
## player on this machine, who is the first of the players here.
func _show_blast(position: Vector3, radius: float, size: float) -> void:
	Fx.explosion(position, size)
	Sfx.play_at(&"explosion", position, 6.0)
	exploded.emit(position)
	var witness := get_tree().get_first_node_in_group("player")
	if witness and witness.has_method("shake"):
		var distance: float = witness.global_position.distance_to(position)
		witness.shake(clampf(1.3 - distance / (radius * 2.5), 0.0, 1.0) * minf(size + 0.2, 1.0))


## Fuel burning on the floor around `position`, `across` metres wide, for
## `seconds`.
func burn(position: Vector3, across: float, seconds: float) -> void:
	Net.show(self, &"_show_fire", [position, across, seconds])
	_burning.append({"at": position, "radius": across * 0.5 + BESIDE, "left": seconds, "flames": across * 0.5, "tall": LOW, "owed": 0.0})


func _show_fire(position: Vector3, across: float, seconds: float) -> void:
	Fx.fire(position, across, seconds)


func _physics_process(delta: float) -> void:
	if _burning.is_empty():
		return
	for i in range(_burning.size() - 1, -1, -1):
		_burning[i].left -= delta
		_burning[i].owed += delta
		if _burning[i].left <= 0.0:
			_burning.remove_at(i)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = BURN_TICK
	# A fire hurts at the host's word, like everything else in the world.
	if Net.is_guest():
		return
	var bodies := get_tree().get_nodes_in_group("enemy")
	bodies.append_array(get_tree().get_nodes_in_group("player"))
	for body: Node3D in bodies:
		for patch in _burning:
			var offset: Vector3 = body.global_position - patch.at
			if absf(offset.y) < 1.5 and Vector2(offset.x, offset.z).length() < patch.radius:
				body.take_damage(BURN_DAMAGE * BURN_TICK * (PLAYER_SHARE if body.is_in_group("player") else 1.0), body.global_position + Vector3.UP * 0.5, Vector3.UP)
				break
	_spread()


## A scene change takes its fires with it. Without one, what burns in the
## level goes out as well, since its patch is gone from the list.
func clear() -> void:
	_burning.clear()
	douse()


## Puts out every stack and every pile that burns: each is as it was before
## it caught, and can catch again. What has burnt stays burnt.
func douse() -> void:
	for thing in get_tree().get_nodes_in_group(TINDER):
		thing.douse()


## True if the floor at `position` is on fire, or within `margin` of it: fuel
## that burns there, or a crate or a pile of pallets that does.
func burning(position: Vector3, margin := 0.0) -> bool:
	for patch in _burning:
		var offset: Vector3 = position - patch.at
		if absf(offset.y) < 1.5 and Vector2(offset.x, offset.z).length() < patch.radius + margin:
			return true
	return false


## The patches of floor that are on fire, of fuel and of whatever caught
## fire alike: {at, radius, left} each, and the rest of what _burning lists.
func fires() -> Array[Dictionary]:
	return _burning


## The point of a body a blast is measured to.
func _middle(body: Node3D) -> Vector3:
	if body is CharacterBody3D:
		return body.global_position + Vector3.UP * 0.9
	for child in body.get_children():
		if child is CollisionShape3D:
			return child.global_position
	return body.global_position


## How much of a body the blast can see, from 0 behind cover to 1 in the open.
func _exposure(space: PhysicsDirectSpaceState3D, from: Vector3, body: Node3D, ignored: Array[RID]) -> float:
	var points: Array[Vector3] = [_middle(body)]
	if body is CharacterBody3D:
		points = [body.global_position + Vector3.UP * 0.3, body.global_position + Vector3.UP * 0.9, body.global_position + Vector3.UP * 1.5]
	var open := 0
	for point in points:
		var query := PhysicsRayQueryParameters3D.create(from, point, WORLD, ignored + [(body as CollisionObject3D).get_rid()])
		if space.intersect_ray(query).is_empty():
			open += 1
	return float(open) / points.size()


## Something that can catch fire has done so: a patch like that of burn(),
## but with no fuel on the floor, since what burns shows its own flames. `at`
## is the middle of its underside, `flames` how far its flames reach from
## there and `tall` how high they light something. What comes back is the
## patch itself, for whoever burns to move along with and to put out: with
## `left` at 0 it is gone at the next step. Only the host has patches.
func kindle(at: Vector3, flames: float, tall: float, seconds: float) -> Dictionary:
	var patch := {"at": at, "radius": flames + BESIDE, "left": seconds, "flames": flames, "tall": tall, "owed": 0.0, "tinder": true}
	_burning.append(patch)
	return patch


## How many crates, boxes and piles of pallets are on fire.
func alight() -> int:
	var count := 0
	for patch in _burning:
		if patch.has("tinder") and patch.left > 0.0:
			count += 1
	return count


## True if one more of them may catch fire: see MAX_ALIGHT.
func room() -> bool:
	return alight() < MAX_ALIGHT


## How fast a fire heats something that stands upright, in seconds of fire a
## second: 1 where its flames touch it, less the further off it stands and
## the higher up, a little where it lies under the fire, and 0 out of its
## reach. `fire` is a patch, `box` the box around the thing and `inverse`
## what takes a point in the level to the space that box is in.
func heat(fire: Dictionary, inverse: Transform3D, box: AABB) -> float:
	var from: Vector3 = inverse * (fire.at as Vector3)
	var middle := box.get_center()
	var gap: float = Vector2(maxf(absf(from.x - middle.x) - box.size.x * 0.5, 0.0), maxf(absf(from.z - middle.z) - box.size.z * 0.5, 0.0)).length() - fire.flames
	if gap > REACH:
		return 0.0
	var near := lerpf(1.0, FAR, clampf(gap / REACH, 0.0, 1.0))
	# Its top is no higher than the foot of the fire, give or take the
	# thickness of a board: it lies under it.
	if box.end.y <= from.y + 0.02:
		return UNDER * near if from.y - box.end.y <= DEPTH else 0.0
	# How far up what the fire lights its underside is.
	var rise: float = (box.position.y - from.y) / fire.tall
	if rise >= 1.0:
		return 0.0
	return near * lerpf(1.0, HIGH, clampf(rise, 0.0, 1.0))


## Every fire heats what can catch fire around it, for as long as it has
## burnt since it last did: `owed`, which is a tick, or less for a fire that
## has only just begun. What is near enough to a patch is looked up once,
## when its first tick comes: neither of them moves sideways after that.
func _spread() -> void:
	# What catches adds a patch of its own, which waits for the next tick.
	for patch: Dictionary in _burning.duplicate():
		if not patch.has("near"):
			patch.near = _near(patch.at, patch.flames + REACH)
		var seconds: float = patch.owed
		patch.owed = 0.0
		for thing: Variant in patch.near:
			if is_instance_valid(thing):
				thing.warm(patch, seconds)


## What can catch fire and stands within `reach` of the upright through a
## point.
func _near(at: Vector3, reach: float) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for thing: Node3D in get_tree().get_nodes_in_group(TINDER):
		var offset := thing.global_position - at
		if Vector2(offset.x, offset.z).length() < reach + thing.girth:
			found.append(thing)
	return found


## The fireball of a blast at `position` that reaches `radius` metres heats
## what it has left standing and can see, as a fire that stood there for SEAR
## seconds would: cardboard and pallets close by catch at once, and so do
## crates that were behind other crates. A wall or a floor in between keeps
## it off, as it keeps off the blast itself. `through` is what _through()
## gave for this blast.
func _sear(space: PhysicsDirectSpaceState3D, position: Vector3, radius: float, through: Array[RID]) -> void:
	var ball := radius * FIREBALL
	var fire := {"at": position + Vector3.DOWN * 0.5, "flames": ball, "tall": ball + 0.5}
	for thing in _near(position, ball + REACH):
		if _lit(space, position, thing, through):
			thing.warm(fire, SEAR)


## What a look from a blast goes through as if it were not there: `ignored`,
## and every stack of crates and boxes. A stack is on the layer of the world
## as well, but it is no wall: what stands behind it still gets the heat,
## and the glass behind it still breaks.
func _through(ignored: Array[RID]) -> Array[RID]:
	var through := ignored.duplicate()
	for thing in get_tree().get_nodes_in_group(TINDER):
		if thing is CollisionObject3D:
			through.append((thing as CollisionObject3D).get_rid())
	return through


## True if nothing of the level stands between `from` and `to`, going
## through whatever is in `through`.
func in_sight(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, through: Array[RID]) -> bool:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, WORLD, through)).is_empty()


## True if the fireball at `from` can see something that can catch fire: the
## middle of one of the colliders of a stack, or a pile of pallets. The box of
## a pile is part of the body of the level, so a look that ends on that box
## has got to the pile.
func _lit(space: PhysicsDirectSpaceState3D, from: Vector3, thing: Node3D, through: Array[RID]) -> bool:
	if thing is CollisionObject3D:
		for child in thing.get_children():
			if child is CollisionShape3D and not child.disabled and in_sight(space, from, child.global_position, through):
				return true
		return false
	var size: Vector3 = thing.size
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, thing.global_transform * Vector3(0.0, size.y * 0.5, 0.0), WORLD, through))
	if hit.is_empty():
		return true
	var at: Vector3 = thing.global_transform.affine_inverse() * (hit.position as Vector3)
	return absf(at.x) <= size.x * 0.5 + 0.05 and absf(at.z) <= size.z * 0.5 + 0.05 and at.y >= -0.05 and at.y <= size.y + 0.05
