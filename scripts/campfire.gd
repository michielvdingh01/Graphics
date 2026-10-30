extends Node3D
## The fire of a camp by night: it burns as long as the level is there. It is
## a fire as Fx.fire() makes one, with its flames, its flickering light and
## its sparks, that does not go out, whose light carries farther and throws a
## shadow, and without the balls of smoke: the camp has a column of its own
## (smoke() in tools/kit/field.gd), which the fire lights from below. It
## stands in the night of a level, see campfire() in tools/kit/field.gd.

## How wide the fire is, how far its light carries, in metres, and from how
## far off it throws a shadow.
@export var across := 0.7
@export var reach := 10.0
@export var shadow_reach := 30.0
## Longer than any level is played.
const FOREVER := 1.0e7

var _flames: Node3D


func _ready() -> void:
	# Fx puts what it makes into the scene that is played, which has to be
	# there first.
	_light.call_deferred()


func _exit_tree() -> void:
	if is_instance_valid(_flames):
		_flames.queue_free()


func _light() -> void:
	if not is_inside_tree():
		return
	_flames = Fx.fire(global_position, across, FOREVER, false)
	for light: OmniLight3D in _flames.find_children("*", "OmniLight3D", false, false):
		light.omni_range = reach
		light.shadow_enabled = true
		light.distance_fade_enabled = true
		light.distance_fade_begin = 120.0
		light.distance_fade_length = 30.0
		light.distance_fade_shadow = shadow_reach
		light.add_to_group(&"night_fire")
