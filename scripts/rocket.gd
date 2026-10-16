extends Node3D
## A rocket from the rocket launcher on its way: it flies straight, with a
## flame at its tail and smoke behind it, and goes off at the first thing it
## meets or when its motor is spent. What it hits square is hurt by the hit
## itself as well as by the blast, which is that of scripts/blast.gd, bigger
## than a barrel's, and hurts whoever fired it as much as anybody.
## scripts/weapons.gd fires it.

## The blast: how far it reaches and what it does at its heart.
const RADIUS := 6.0
const DAMAGE := 130.0
## How big it looks and sounds, next to a barrel going off.
const SIZE := 1.6
## Seconds before the motor is spent and it goes off wherever it is.
const LIFE := 3.0
## Seconds between two puffs of the smoke it leaves.
const TRAIL := 0.03
const HIT_MASK := 0b100101  # world + enemy + breakable

## Metres a second, along the way it flies.
var velocity := Vector3.ZERO
## What a hit square does, on top of the blast.
var direct := 150.0
## True for the copy another machine shows of a rocket somebody fired there:
## that one goes off where it goes off, and this only disappears.
var echo := false
## Who fired it, as scripts/match.gd numbers those who play, 0 for nobody,
## and their body, which it does not hit on its way out.
var thrower := 0
var shooter: CollisionObject3D
## The weapon it came from, as a place in scripts/armory.gd.
var weapon := -1

var _age := 0.0
var _puff := 0.0
var _flame := OmniLight3D.new()
var _hiss := AudioStreamPlayer3D.new()


func _ready() -> void:
	_flame.light_color = Color(1.0, 0.55, 0.2)
	_flame.light_energy = 2.5
	_flame.omni_range = 5.0
	_flame.light_bake_mode = Light3D.BAKE_DISABLED
	_flame.position = Vector3(0, 0, 0.35)
	add_child(_flame)
	add_child(_tail())
	_hiss.stream = Sfx.loop_of(&"rocket_flight")
	_hiss.bus = Sfx.WORLD
	_hiss.unit_size = 6.0
	_hiss.max_distance = 90.0
	_hiss.attenuation_filter_db = -6.0
	add_child(_hiss)
	if _hiss.stream:
		_hiss.play()
	if velocity != Vector3.ZERO:
		look_at(global_position + velocity)


## The flame at its tail.
func _tail() -> MeshInstance3D:
	var tail := MeshInstance3D.new()
	var glow := SphereMesh.new()
	glow.radius = 0.05
	glow.height = 0.1
	glow.radial_segments = 8
	glow.rings = 4
	tail.mesh = glow
	tail.scale = Vector3(1.0, 1.0, 3.0)
	tail.position = Vector3(0, 0, 0.42)
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = Color(1.0, 0.75, 0.4)
	hot.emission_enabled = true
	hot.emission = Color(1.0, 0.5, 0.15)
	hot.emission_energy_multiplier = 4.0
	tail.material_override = hot
	return tail


## What it is drawn with, for Fx.rehearse(): its model and the flame at its
## tail. Its smoke is a burst, which Fx rehearses anyway.
func looks() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = [_tail()]
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		var copy := MeshInstance3D.new()
		copy.mesh = mesh.mesh
		copy.material_override = mesh.material_override
		found.append(copy)
	return found


func _physics_process(delta: float) -> void:
	_age += delta
	var from := global_position
	var to := from + velocity * delta
	var mask := HIT_MASK | (Match.foes_of(shooter) if Match.active and shooter else 0)
	var skip: Array[RID] = []
	if shooter:
		skip.append(shooter.get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, skip)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		_go_off(hit.position - velocity.normalized() * 0.15, hit.collider)
		return
	if _age >= LIFE:
		_go_off(from, null)
		return
	global_position = to
	_puff -= delta
	if _puff <= 0.0:
		_puff = TRAIL
		Fx.rocket_trail(global_position - velocity.normalized() * 0.45, velocity.normalized())


func _go_off(at: Vector3, struck: Object) -> void:
	if echo:
		queue_free()
		return
	var direction := velocity.normalized()
	if struck and struck.has_method("take_damage"):
		if Match.active:
			Match.hit(shooter, struck, direct, at, direction, weapon)
		else:
			Net.damage(struck, direct, at, direction)
	Blast.explode(at, RADIUS, DAMAGE, SIZE, null, thrower)
	queue_free()
