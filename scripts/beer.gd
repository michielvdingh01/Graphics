extends Node3D
## A bottle of beer thrown: it falls as it flies, turning end over end, and
## breaks on what it meets, which is hurt a little. scripts/weapons.gd throws
## it.

## Metres a second that it falls faster each second: less than a stone, so
## that a bottle reaches as far as somebody can be seen to be hit by it.
const FALLS := 6.0
## Seconds before it is gone, wherever it is.
const LIFE := 3.0
## Radians a second it turns end over end.
const TURNS := 13.0
const HIT_MASK := 0b100101  # world + enemy + breakable

## Metres a second, along the way it flies.
var velocity := Vector3.ZERO
## What a hit does.
var direct := 8.0
## True for the copy another machine shows of a bottle somebody threw there:
## that one flies and breaks the same but hurts nobody.
var echo := false
## Who threw it, as scripts/match.gd numbers those who play, 0 for nobody,
## and their body, which it does not hit on its way out.
var thrower := 0
var shooter: CollisionObject3D
## The weapon it came from, as a place in scripts/armory.gd.
var weapon := -1
## Something else it passes through on its way out: the vehicle it came from.
var passes := RID()

var _age := 0.0

@onready var _model: Node3D = $Model


## What it is drawn with, for Fx.rehearse().
func looks() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		var copy := MeshInstance3D.new()
		copy.mesh = mesh.mesh
		copy.material_override = mesh.material_override
		found.append(copy)
	return found


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	velocity += Vector3.DOWN * FALLS * delta
	var from := global_position
	var to := from + velocity * delta
	var mask := HIT_MASK | (Match.foes_of(shooter) if Match.active and shooter else 0)
	var skip: Array[RID] = []
	if shooter:
		skip.append(shooter.get_rid())
	if passes.is_valid():
		skip.append(passes)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, mask, skip))
	if hit:
		_break(hit)
		return
	global_position = to
	_model.rotate_object_local(Vector3.RIGHT, TURNS * delta)


func _break(hit: Dictionary) -> void:
	var way := velocity.normalized()
	Fx.shatter(hit.position, hit.normal, 0.35, false)
	Fx.splash(hit.position, hit.normal, way, true)
	Sfx.play_at(&"beer_smash", hit.position, -3.0)
	var struck: Object = hit.collider
	if not echo and struck.has_method("take_damage"):
		var killed: bool
		if Match.active:
			killed = Match.hit(shooter, struck, direct, hit.position, way, weapon)
		else:
			killed = Net.damage(struck, direct, hit.position, way)
		var weapons: Variant = shooter.get(&"weapons") if shooter else null
		if weapons and struck is CharacterBody3D:
			weapons.hit_confirmed.emit(false, killed)
	queue_free()
