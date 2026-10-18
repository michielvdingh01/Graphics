extends SpotLight3D
## A searchlight that sweeps to and fro: it turns about the upright from one
## side of where it was set to look to the other, slowing at either end and
## resting there a moment, as a man at a lamp would. Its dip stays as set.
## It stands in the night of a level, see searchlight() in tools/kit/field.gd.
##
## Every machine sweeps by its own clock, from where the lamp was set: the
## beam is not the same for all who play together.

## How far it turns either side, in degrees, and how long one sweep from one
## side to the other takes, in seconds; how long it rests at either end.
@export var reach_deg := 55.0
@export var sweep_time := 9.0
@export var rest := 1.2

var _set: Basis
var _clock := 0.0


func _ready() -> void:
	_set = basis
	# Two searchlights that came on together would not sweep together.
	_clock = fposmod(global_position.x * 1.7 + global_position.z * 0.9, (sweep_time + rest) * 2.0)


func _process(delta: float) -> void:
	_clock += delta
	var leg := sweep_time + rest
	var at := fposmod(_clock, leg * 2.0)
	var going := at < leg
	var share := clampf(fposmod(at, leg) / sweep_time, 0.0, 1.0)
	# Eased at both ends: from -1 to 1 and back.
	var swing := -cos(share * PI)
	if not going:
		swing = -swing
	basis = Basis(Vector3.UP, deg_to_rad(reach_deg) * swing) * _set
