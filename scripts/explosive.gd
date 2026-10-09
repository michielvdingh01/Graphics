extends StaticBody3D
## Something that goes up when it is shot: a fuel barrel, a gas bottle or a
## jerrycan. The level builder puts one of these around the model it stands
## for, as that model's collider (see `_explosive()` in
## tools/level_builder.gd).
##
## A hole in it sets it alight, and it burns for a moment before it goes off:
## long enough to get away from it, or to see a robot walk up to it. More
## damage, or an explosion next to it, sets it off at once.

enum Kind { BARREL, BOTTLE, CAN }

## Per kind: the damage that holes it, the seconds it burns before it goes
## off, the reach and damage of its blast, how large that looks, and the width
## and duration of the fire it leaves on the floor.
const TUNING := {
	Kind.BARREL: {"health": 45.0, "fuse": 1.8, "radius": 6.5, "damage": 150.0, "size": 1.0, "fire": 1.3, "burns": 7.0},
	Kind.BOTTLE: {"health": 35.0, "fuse": 1.3, "radius": 5.5, "damage": 130.0, "size": 0.85, "fire": 0.0, "burns": 0.0},
	Kind.CAN: {"health": 20.0, "fuse": 0.9, "radius": 3.5, "damage": 70.0, "size": 0.55, "fire": 0.9, "burns": 5.0},
}
const DEBRIS := 8
## Blown-out hulks that lie about; the oldest makes way for one more.
const MAX_HULKS := 10

static var _hulks: Array[RigidBody3D] = []
## Material of a model -> its copy covered in soot.
static var _charred := {}

@export var kind := Kind.BARREL
## The model this is the collider of.
@export var model: NodePath

var health := 0.0
var gone := false

var _tuning: Dictionary
var _alight := false
var _fuse := 0.0
var _flame: Node3D

# The level builder loads this script outside the game, where the autoloads
# have no names; here they are found by where they sit.
@onready var _fx: Node = get_node("/root/Fx")
@onready var _sfx: Node = get_node("/root/Sfx")
@onready var _blast: Node = get_node("/root/Blast")


func _ready() -> void:
	_tuning = TUNING[kind]
	health = _tuning.health
	add_to_group("explosive")
	set_physics_process(false)


func is_alight() -> bool:
	return _alight


func take_damage(amount: float, hit_position: Vector3, _direction: Vector3) -> bool:
	if gone:
		return false
	health -= amount
	if health > 0.0:
		return false
	if not _alight:
		_ignite(hit_position)
	# Twice what it takes to hole it does not leave it time to burn.
	if health < -_tuning.health:
		_fuse = minf(_fuse, randf_range(0.08, 0.22))
	return false


func _physics_process(delta: float) -> void:
	_fuse -= delta
	if _fuse <= 0.0:
		explode()


## Flame comes out of the hole: straight out of a gas bottle, licking up the
## side of anything that holds fuel.
func _ignite(hole: Vector3) -> void:
	_alight = true
	_fuse = _tuning.fuse
	set_physics_process(true)
	var middle := _middle()
	var out := hole - middle
	out.y = 0.0
	if out.length() < 0.05:
		# Not a shot but heat: it burns from the top.
		hole = Vector3(middle.x, global_position.y + (middle.y - global_position.y) * 2.0, middle.z)
		out = Vector3.UP
	if kind == Kind.BOTTLE:
		_flame = _fx.jet(hole, out, 1.2, _tuning.fuse + 0.3)
	else:
		_flame = _fx.jet(hole, out.normalized() * 0.5 + Vector3.UP, 0.8, _tuning.fuse + 0.3)
	_sfx.play_at(&"vent", hole, 2.0)


## Goes off, there and then.
func explode() -> void:
	gone = true
	set_physics_process(false)
	collision_layer = 0
	if is_instance_valid(_flame):
		_flame.queue_free()
	var middle := _middle()
	_blast.explode(middle, _tuning.radius, _tuning.damage, _tuning.size, self)
	if _tuning.burns > 0.0:
		_blast.burn(global_position, _tuning.fire, _tuning.burns)
	_leave_hulk()
	queue_free()


## The model goes from the level; what is left of it is thrown up, black and
## bent, and lies where it comes down.
func _leave_hulk() -> void:
	var prop := get_node_or_null(model) as Node3D
	if prop == null:
		return
	var hulk := RigidBody3D.new()
	hulk.collision_layer = DEBRIS
	hulk.collision_mask = 1
	hulk.mass = 12.0
	hulk.contact_monitor = true
	hulk.max_contacts_reported = 1
	for child in get_children():
		if child is CollisionShape3D:
			var shape := CollisionShape3D.new()
			shape.shape = child.shape
			shape.transform = child.transform
			hulk.add_child(shape)
	get_tree().current_scene.add_child(hulk)
	hulk.global_transform = global_transform
	# The model in the level has a patch of lightmap that says where it stood;
	# the hulk is a copy that the probes light wherever it ends up.
	var dent := Transform3D(Basis.from_euler(Vector3(randf_range(-0.12, 0.12), 0.0, randf_range(-0.12, 0.12))).scaled(Vector3(1.06, 0.84, 0.94)), Vector3.ZERO)
	for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
		var copy := MeshInstance3D.new()
		copy.mesh = mesh.mesh
		copy.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		for i in mesh.mesh.get_surface_count():
			copy.set_surface_override_material(i, _soot(mesh.mesh.surface_get_material(i)))
		hulk.add_child(copy)
		copy.global_transform = global_transform * dent * global_transform.affine_inverse() * mesh.global_transform
	prop.visible = false
	var force: float = 0.6 + 0.6 * _tuning.size
	hulk.linear_velocity = Vector3(randf_range(-2.5, 2.5), randf_range(5.5, 8.0), randf_range(-2.5, 2.5)) * force
	hulk.angular_velocity = Vector3(randf_range(-7, 7), randf_range(-3, 3), randf_range(-7, 7))
	hulk.body_entered.connect(func(_other: Node) -> void:
		if hulk.linear_velocity.length() > 1.5:
			_sfx.play_at(&"clang", hulk.global_position, -4.0)
	)
	_hulks = _hulks.filter(is_instance_valid)
	_hulks.append(hulk)
	while _hulks.size() > MAX_HULKS:
		_hulks.pop_front().queue_free()


func _soot(material: Material) -> Material:
	if not _charred.has(material):
		var black := material.duplicate()
		if black is BaseMaterial3D:
			black.albedo_color = Color(0.07, 0.065, 0.06)
			black.metallic = 0.0
			black.roughness = 1.0
		_charred[material] = black
	return _charred[material]


## Middle of the collider, which is the middle of the model.
func _middle() -> Vector3:
	for child in get_children():
		if child is CollisionShape3D:
			return child.global_position
	return global_position
