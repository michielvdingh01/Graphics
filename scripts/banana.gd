extends Node3D
## A banana from the banana gun on its way: it turns after whatever it can see
## ahead of it, spinning as it goes, and sticks in what it meets. What it
## sticks in is hurt a little; once enough of them are in the same thing, as
## many as `bunch` in weapons/banana_gun.tres, they go off together, with a blast of scripts/blast.gd. One that finds nothing
## drops out of the air when LIFE is over, and one that sticks falls off after
## STUCK seconds. scripts/weapons.gd fires it.

## What the blast does when they set each other off.
const RADIUS := 3.5
const DAMAGE := 110.0
const SIZE := 0.45
## Seconds in the air, and seconds it stays where it sticks.
const LIFE := 2.2
const STUCK := 3.0
## How far ahead it looks for something to turn after, how wide (the cosine of
## half the angle), how often, and how fast it turns in radians a second.
const SEEKS := 30.0
const WIDE := 0.8
const EVERY := 0.1
const TURNS := 4.5
## Radians a second it spins about its length.
const SPIN := 16.0
## Where on a body it aims: about the middle of somebody standing.
const MIDDLE := Vector3.UP * 1.1
const HIT_MASK := 0b100101  # world + enemy + breakable
const ENEMY := 0b100
const WORLD := 0b1
## Asked for as it is needed: the armory holds the weapon that holds this.
const ARMORY := "res://scripts/armory.gd"

static var _streak: SphereMesh
static var _streak_look: StandardMaterial3D

## Metres a second, along the way it flies.
var velocity := Vector3.ZERO
## What a hit does.
var direct := 14.0
## True for the copy another machine shows of a banana somebody fired there:
## that one flies and sticks the same but hurts nobody.
var echo := false
## Who fired it, as scripts/match.gd numbers those who play, 0 for nobody,
## and their body, which it does not hit on its way out.
var thrower := 0
var shooter: CollisionObject3D
## The weapon it came from, as a place in scripts/armory.gd.
var weapon := -1
## Something else it passes through on its way out: the vehicle it was fired from.
var passes := RID()

var _age := 0.0
var _look := 0.0
var _after: Node3D
## Seconds left where it sticks; less than none while it flies.
var _stuck := -1.0
var _tail: MeshInstance3D

@onready var _model: Node3D = $Model


func _ready() -> void:
	_tail = _streak_of_it()
	add_child(_tail)
	_face(velocity)


## The short yellow streak behind it, which is what can be followed by eye.
func _streak_of_it() -> MeshInstance3D:
	if _streak == null:
		_streak = SphereMesh.new()
		_streak.radius = 0.02
		_streak.height = 0.04
		_streak.radial_segments = 8
		_streak.rings = 4
		_streak_look = StandardMaterial3D.new()
		_streak_look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_streak_look.albedo_color = Color(1.0, 0.85, 0.3)
		_streak_look.emission_enabled = true
		_streak_look.emission = Color(1.0, 0.75, 0.15)
		_streak_look.emission_energy_multiplier = 3.0
	var tail := MeshInstance3D.new()
	tail.mesh = _streak
	tail.material_override = _streak_look
	tail.scale = Vector3(1.0, 1.0, 9.0)
	tail.position = Vector3(0, 0, 0.3)
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return tail


## What it is drawn with, for Fx.rehearse(): its model and its streak.
func looks() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = [_streak_of_it()]
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		var copy := MeshInstance3D.new()
		copy.mesh = mesh.mesh
		copy.material_override = mesh.material_override
		found.append(copy)
	return found


func _physics_process(delta: float) -> void:
	if _stuck >= 0.0:
		_stuck -= delta
		if _stuck < 0.0:
			queue_free()
		return
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	_look -= delta
	if _look <= 0.0:
		_look = EVERY
		_seek()
	if is_instance_valid(_after):
		var wanted := (_after.global_position + MIDDLE - global_position).normalized()
		var way := velocity.normalized()
		var angle := way.angle_to(wanted)
		if angle > 0.001:
			var axis := way.cross(wanted)
			if axis.length_squared() > 0.000001:
				velocity = velocity.rotated(axis.normalized(), minf(angle, TURNS * delta))
	var from := global_position
	var to := from + velocity * delta
	var skip: Array[RID] = []
	if shooter:
		skip.append(shooter.get_rid())
	if passes.is_valid():
		skip.append(passes)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, _mask(), skip))
	if hit:
		_land(hit)
		return
	global_position = to
	_face(velocity)
	_model.rotate_object_local(Vector3.BACK, SPIN * delta)


func _mask() -> int:
	return HIT_MASK | (Match.foes_of(shooter) if Match.active and shooter else 0)


func _face(way: Vector3) -> void:
	if way.length_squared() < 0.0001:
		return
	look_at(global_position + way, Vector3.UP if absf(way.normalized().y) < 0.99 else Vector3.RIGHT)


## Whatever living thing lies nearest to straight ahead, in plain view.
func _seek() -> void:
	var ball := SphereShape3D.new()
	ball.radius = SEEKS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = _mask() & ~(WORLD | 0b100000)
	if shooter:
		query.exclude = [shooter.get_rid()]
	var space := get_world_3d().direct_space_state
	var way := velocity.normalized()
	var best: Node3D
	var best_ahead := WIDE
	for found: Dictionary in space.intersect_shape(query, 32):
		var body := found.collider as Node3D
		if body == null or not body.has_method("take_damage") or body.get(&"dead") == true:
			continue
		var there := body.global_position + MIDDLE
		var ahead := way.dot((there - global_position).normalized())
		if ahead <= best_ahead:
			continue
		var sight := PhysicsRayQueryParameters3D.create(global_position, there, WORLD)
		if space.intersect_ray(sight):
			continue
		best_ahead = ahead
		best = body
	_after = best


## It has met something: there it stays, and if that is alive it counts.
func _land(hit: Dictionary) -> void:
	var struck: Object = hit.collider
	var way := velocity.normalized()
	global_position = hit.position
	_face(way)
	_stuck = STUCK
	_tail.visible = false
	Sfx.play_at(&"banana_stick", hit.position)
	if not struck.has_method("take_damage"):
		Fx.impact(hit, way, true)
		return
	reparent(struck as Node)
	if echo:
		return
	var killed: bool
	if Match.active:
		killed = Match.hit(shooter, struck, direct, hit.position, way, weapon)
	else:
		killed = Net.damage(struck, direct, hit.position, way)
	var weapons: Variant = shooter.get(&"weapons") if shooter else null
	if weapons and struck is CharacterBody3D:
		weapons.hit_confirmed.emit(false, killed)
	var bunch: Array[Node] = []
	for child in (struck as Node).get_children():
		if child.is_in_group(&"banana") and not child.is_queued_for_deletion():
			bunch.append(child)
	if bunch.size() < (load(ARMORY).at(weapon) as WeaponData).bunch:
		return
	for banana in bunch:
		banana.queue_free()
	var middle: Vector3 = (struck as Node3D).global_position + (MIDDLE if struck is CharacterBody3D else Vector3.ZERO)
	Blast.explode(middle, RADIUS, DAMAGE, SIZE, null, thrower)
