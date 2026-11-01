extends Node3D
## A flashlight lying somewhere in a shop, for when the mains are gone: see
## scripts/mains.gd. Whoever walks up to it has it on their weapon from then on,
## see give_torch() in scripts/weapons.gd, until they die. Each machine looks
## after its own player: a flashlight that somebody else took is still there
## for you. It shines a little by itself, so that it can be found in the dark.

const MODEL := preload("res://scenes/models/flashlight.scn")
## It is taken from this near, in metres, measured from the player's chest.
const TAKE := 1.25
const LOOK_EVERY := 0.2
const TINT := Color(1.0, 0.92, 0.7)
const TURN := 0.8

var _player: CharacterBody3D
var _look := 0.0
var _model: Node3D
var _glow := OmniLight3D.new()


func _ready() -> void:
	add_to_group(&"flashlight")
	_model = MODEL.instantiate()
	_model.scale = Vector3.ONE * 1.6
	_model.rotation = Vector3(0, 0, 0)
	add_child(_model)
	_glow.light_color = TINT
	_glow.light_energy = 0.35
	_glow.omni_range = 1.6
	_glow.omni_attenuation = 1.4
	_glow.light_bake_mode = Light3D.BAKE_DISABLED
	add_child(_glow)


func _process(delta: float) -> void:
	_model.rotation.y += delta * TURN
	_look -= delta
	if _look > 0.0:
		return
	_look = LOOK_EVERY
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player")
		if _player == null:
			return
	var weapons: Node = _player.weapons
	visible = not weapons.has_torch
	if visible and not _player.dead and (_player.global_position + Vector3.UP * 0.9).distance_to(global_position) < TAKE:
		weapons.give_torch()
		Sfx.play(&"pickup_ammo", -8.0)
		var game := get_tree().get_first_node_in_group(&"game")
		if game:
			game.picked_up.emit("FLASHLIGHT  [F]", TINT)
