extends Node3D
## Something an enemy leaves behind for the player to pick up: a cell that
## mends, a can of ammunition or a grenade. scripts/game.gd decides what is
## left and where; this is the thing itself.
##
## It hops out of the wreck, hangs a hand above the floor turning slowly, and
## glows in its own colour so that it is found in a dark hall. Walking up to
## it takes it, if there is any use for it: a cell is left lying by somebody
## who is not hurt. After a while it blinks and is gone, which is a reason
## not to wait behind a crate until the fight is over.

signal taken(kind: Kind)

enum Kind { HEALTH, AMMO, GRENADE }

const MODELS := {
	Kind.HEALTH: preload("res://scenes/models/cell.scn"),
	Kind.AMMO: preload("res://scenes/models/ammo_can.scn"),
	Kind.GRENADE: preload("res://scenes/models/grenade.scn"),
}
## The colour it glows in, how large it is drawn next to how it was built,
## and the sound of taking it.
const TINT := {Kind.HEALTH: Color(0.3, 1.0, 0.45), Kind.AMMO: Color(1.0, 0.7, 0.28), Kind.GRENADE: Color(0.75, 0.88, 1.0)}
const SIZE := {Kind.HEALTH: 1.5, Kind.AMMO: 1.15, Kind.GRENADE: 2.4}
const SOUND := {Kind.HEALTH: &"pickup_health", Kind.AMMO: &"pickup_ammo", Kind.GRENADE: &"pickup_grenade"}
## What the HUD says when it is taken.
const LABEL := {Kind.HEALTH: "+%d HEALTH", Kind.AMMO: "+AMMO", Kind.GRENADE: "+GRENADE"}
## Health a cell mends.
const HEALTH := 25.0
## It is taken from this close, and comes to the player from that close.
const TAKE := 1.1
const DRAW := 2.6
## Seconds it lies there, the last of them blinking.
const LIFE := 40.0
const BLINK := 6.0
const HOVER := 0.35
const HOP_TIME := 0.45
const WORLD := 1

var kind := Kind.HEALTH

var _age := 0.0
var _from := Vector3.ZERO
var _rest := Vector3.ZERO
var _model: Node3D
var _light := OmniLight3D.new()
var _player: CharacterBody3D


func _ready() -> void:
	add_to_group("pickup")
	_model = MODELS[kind].instantiate()
	_model.scale = Vector3.ONE * SIZE[kind]
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D"):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_model)
	_light.light_color = TINT[kind]
	_light.light_energy = 0.7
	_light.omni_range = 2.4
	_light.omni_attenuation = 1.4
	_light.light_bake_mode = Light3D.BAKE_DISABLED
	_light.light_volumetric_fog_energy = 0.0
	_light.position.y = 0.12
	add_child(_light)
	_player = get_tree().get_first_node_in_group("player")
	# Where it comes to rest: a step from the wreck, unless a wall is there.
	_from = global_position
	var angle := randf() * TAU
	var out := Vector3(cos(angle), 0.0, sin(angle)) * randf_range(0.4, 0.9)
	var space := get_world_3d().direct_space_state
	if not space.intersect_ray(PhysicsRayQueryParameters3D.create(_from, _from + out * 1.6, WORLD)).is_empty():
		out = Vector3.ZERO
	_rest = _from + out
	_rest.y = Fx.floor_below(_rest) + HOVER


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	_model.rotation.y += delta * 1.7
	var hop := minf(_age / HOP_TIME, 1.0)
	var at := _from.lerp(_rest, hop) + Vector3.UP * (sin(PI * hop) * 0.5 + sin(_age * 2.4) * 0.04 * hop)
	# About to go: it blinks, faster towards the end.
	var left := LIFE - _age
	visible = left > BLINK or fmod(left * (2.0 + (BLINK - left)), 1.0) < 0.65
	if hop >= 1.0 and is_instance_valid(_player) and not _player.dead and _wanted():
		var to := _player.global_position + Vector3.UP * 0.9 - global_position
		if to.length() < TAKE:
			_take()
			return
		if to.length() < DRAW:
			# The last stretch it comes by itself.
			_rest += to.normalized() * delta * 6.0
			at = _rest
	global_position = at


## What it is, as the HUD says it.
func label() -> String:
	return LABEL[kind] % HEALTH if kind == Kind.HEALTH else LABEL[kind]


func tint() -> Color:
	return TINT[kind]


## True if the player has any use for it.
func _wanted() -> bool:
	match kind:
		Kind.HEALTH:
			return _player.health < _player.MAX_HEALTH
		Kind.AMMO:
			return _player.weapons.ammo_room()
		_:
			return _player.weapons.grenades < _player.weapons.GRENADES


func _take() -> void:
	match kind:
		Kind.HEALTH:
			_player.heal(HEALTH)
		Kind.AMMO:
			_player.weapons.add_ammo()
		_:
			_player.weapons.add_grenade()
	Sfx.play(SOUND[kind], -3.0)
	taken.emit(kind)
	queue_free()
