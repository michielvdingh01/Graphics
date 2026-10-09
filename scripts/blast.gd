extends Node
## What an explosion does: it hurts and throws whatever is near it and in the
## open, sets off other explosives and shakes the player's view. A fire it
## leaves burns whoever stands in it. How any of that looks is up to
## Fx.explosion() and Fx.fire().

signal exploded(position: Vector3)

const WORLD := 1
## Layers a blast looks for bodies on: player, enemy, debris and explosive.
## The level itself is one body of thousands of shapes with nothing to say to
## a blast, which is why whatever explodes is on a layer of its own as well.
const REACHED := 0b11110
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
func explode(position: Vector3, radius: float, damage: float, size := 1.0, source: CollisionObject3D = null) -> void:
	Fx.explosion(position, size)
	Sfx.play_at(&"explosion", position, 6.0)
	exploded.emit(position)

	var space := get_viewport().find_world_3d().direct_space_state
	var ball := SphereShape3D.new()
	ball.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.transform = Transform3D(Basis(), position)
	query.collision_mask = REACHED
	var reached := {}
	for found: Dictionary in space.intersect_shape(query, 48):
		reached[found.collider] = true
	var ignored: Array[RID] = []
	if source:
		ignored.append(source.get_rid())
	reached.erase(source)
	for body: Node3D in reached:
		var middle := _middle(body)
		var offset := middle - position
		var strength := clampf(1.0 - (offset.length() - radius * CORE) / (radius * (1.0 - CORE)), 0.0, 1.0)
		strength *= _exposure(space, position, body, ignored)
		if strength <= 0.0:
			continue
		# Things are thrown outwards and a little up, off the floor.
		var away := (offset.normalized() + Vector3.UP * 0.4).normalized()
		var player := body.is_in_group("player")
		if body.has_method("take_damage"):
			body.take_damage(damage * strength * (PLAYER_SHARE if player else 1.0), middle, away * 2.5)
		if body is CharacterBody3D:
			body.velocity += away * PUSH * strength
		elif body is RigidBody3D:
			body.apply_central_impulse(away * PUSH * strength * body.mass)

	var witness := get_tree().get_first_node_in_group("player")
	if witness and witness.has_method("shake"):
		var distance: float = witness.global_position.distance_to(position)
		witness.shake(clampf(1.3 - distance / (radius * 2.5), 0.0, 1.0) * minf(size + 0.2, 1.0))


## Fuel burning on the floor around `position`, `across` metres wide, for
## `seconds`.
func burn(position: Vector3, across: float, seconds: float) -> void:
	Fx.fire(position, across, seconds)
	_burning.append({"at": position, "radius": across * 0.5 + 0.45, "left": seconds})


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
