extends AnimatableBody3D
## One leaf of the sliding doors of a shop: it runs aside while anybody stands
## near, and shuts again behind them. Without power it stays where it was
## pushed aside to and lets everybody through: see scripts/mains.gd. It goes by
## what stands near on this machine; the leaves of different machines do not
## have to agree, and nobody is shut out by one.

## How far it slides, in the coordinates of the level, and how fast, in m/s.
@export var slides := Vector3.ZERO
const SPEED := 2.6
## It opens for anybody this near, in metres.
const NEAR := 4.2
const LOOK_EVERY := 0.2

var _shut := Vector3.ZERO
var _open := 0.0
var _wants := false
var _look := 0.0
var _unpowered := false


func _ready() -> void:
	_shut = position
	add_to_group(&"shop_door")


## The power has gone: it runs open and stays there.
func lose_power() -> void:
	_unpowered = true
	_wants = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_look -= delta
	if _look <= 0.0 and not _unpowered:
		_look = LOOK_EVERY
		_wants = _anybody_near()
	var goal := 1.0 if _wants else 0.0
	if is_equal_approx(_open, goal):
		return
	_open = move_toward(_open, goal, delta * SPEED / maxf(slides.length(), 0.1))
	position = _shut + slides * _open


func _anybody_near() -> bool:
	var at := global_position
	for group: StringName in [&"player", &"enemy", &"puppet", &"bot", &"vehicle"]:
		for body: Node in get_tree().get_nodes_in_group(group):
			if body is Node3D and (body as Node3D).global_position.distance_squared_to(at) < NEAR * NEAR:
				return true
	return false
