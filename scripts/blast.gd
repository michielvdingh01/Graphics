extends Node
## What an explosion does: it hurts and throws whatever is near it and in the
## open, sets off other explosives and shakes the player's view. A fire it
## leaves burns whoever stands in it. How any of that looks is up to
## Fx.explosion() and Fx.fire().

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

## Patches of floor on fire: {at, radius, left}.
var _burning: Array[Dictionary] = []
var _tick := 0.0


## Something goes off at `position`: `damage` at the centre, nothing beyond
## `radius`. `size` is how large it looks, 1 for a fuel barrel, and `source`
## the body that is exploding, if it is still there to be in the way.
##
## In a game with others the host does the harm and everybody sees the blast;
## on a guest this asks the host for it, as a grenade of its player does.
func explode(position: Vector3, radius: float, damage: float, size := 1.0, source: CollisionObject3D = null) -> void:
	if Net.is_guest():
		Net.ask(self, &"explode", [position, radius, damage, size])
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
	# The glass of the windows is on none of those layers: a wall of panes
	# would leave no room among the MOST for anything else. Every window sees
	# for itself which of its panes the blast gets to.
	for window in get_tree().get_nodes_in_group("window"):
		window.blast(position, radius, ignored)
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
		if body.has_method("take_blast"):
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
	_burning.append({"at": position, "radius": across * 0.5 + 0.45, "left": seconds})


func _show_fire(position: Vector3, across: float, seconds: float) -> void:
	Fx.fire(position, across, seconds)


func _physics_process(delta: float) -> void:
	if _burning.is_empty():
		return
	for i in range(_burning.size() - 1, -1, -1):
		_burning[i].left -= delta
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


## A scene change takes its fires with it.
func clear() -> void:
	_burning.clear()


## True if the floor at `position` is on fire, or within `margin` of it.
func burning(position: Vector3, margin := 0.0) -> bool:
	for patch in _burning:
		var offset: Vector3 = position - patch.at
		if absf(offset.y) < 1.5 and Vector2(offset.x, offset.z).length() < patch.radius + margin:
			return true
	return false


## The patches of floor that are on fire: {at, radius, left} each.
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
