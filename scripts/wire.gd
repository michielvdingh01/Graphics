extends StaticBody3D
## A coil of barbed wire with its pickets (wire_coil() in tools/kit/field.gd):
## in the way of whoever walks up to it, until a vehicle drives over it.
## Then it lies flattened in the sand and stops nobody any more.
##
## A vehicle does not stop at it: scripts/vehicle.gd goes through it and
## tells it so, see run_into().

## How high it still stands once a vehicle has been over it, as a share.
const FLAT := 0.2

var flat := false


## A vehicle drives over it at `speed` m/s along `way`. What is left of the
## speed of a vehicle of `mass` kg once it is through, as a share.
func run_into(_vehicle: Node3D, _speed: float, _way: Vector3, mass: float) -> float:
	if flat:
		return 1.0
	Net.show(self, &"_flatten")
	return clampf(1.0 - 400.0 / maxf(mass, 1.0), 0.6, 1.0)


func _flatten() -> void:
	if flat:
		return
	flat = true
	collision_layer = 0
	# The coil is pressed down onto the ground it lies on, which is where its
	# body stands.
	for child in get_children():
		if child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			mesh.transform = Transform3D(Basis.from_scale(Vector3(1.0, FLAT, 1.0)), Vector3.ZERO) * mesh.transform
	Sfx.play_at(&"wire_crush", global_position, 4.0)
