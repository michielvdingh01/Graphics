extends StaticBody3D
## The pole of a barrier across a track (barrier_pole() in tools/kit/field.gd)
## with its weight and its disc: in the way of whoever walks up to it, until
## a vehicle drives into it or a blast catches it. Then it snaps off its post
## and is thrown aside, and lies where it comes down. Its post and its block
## stay; they are the level's.
##
## A vehicle does not stop at it: scripts/vehicle.gd goes through it and
## tells it so, see run_into().

## Blast damage that snaps it, and the speed in m/s at which whatever is
## thrown off flies at most.
const SNAPS := 40.0
const FLIES := 9.0
## What the pole weighs, in kg, as debris.
const WEIGHT := 25.0
const DEBRIS := 8

var broken := false


## A vehicle drives into it at `speed` m/s along `way`. What is left of the
## speed of a vehicle of `mass` kg once it has gone through, as a share.
func run_into(_vehicle: Node3D, speed: float, way: Vector3, mass: float) -> float:
	if broken:
		return 1.0
	Net.show(self, &"_snap", [way.normalized() * minf(speed, FLIES)])
	return clampf(1.0 - 120.0 / maxf(mass, 1.0), 0.75, 1.0)


func take_blast(amount: float, at: Vector3, push: Vector3) -> void:
	if not broken and amount >= SNAPS:
		Net.show(self, &"_snap", [(global_position - at).normalized() * FLIES * 0.6 + push])


## It snaps: the pole, its weight and its disc fly off as one piece, along
## `push` and up.
func _snap(push: Vector3) -> void:
	if broken:
		return
	broken = true
	collision_layer = 0
	var middle := global_position
	for child in get_children():
		if child is CollisionShape3D:
			middle = (child as CollisionShape3D).global_position
			break
	var piece := RigidBody3D.new()
	piece.name = name + "Pole"
	piece.collision_layer = DEBRIS
	piece.collision_mask = 1
	piece.mass = WEIGHT
	get_parent().add_child(piece)
	piece.global_transform = global_transform
	for child in get_children():
		if child is CollisionShape3D:
			var shape := CollisionShape3D.new()
			shape.shape = (child as CollisionShape3D).shape
			shape.transform = (child as CollisionShape3D).transform
			piece.add_child(shape)
		elif child is MeshInstance3D:
			child.reparent(piece)
	piece.linear_velocity = push + Vector3.UP * (2.0 + push.length() * 0.3)
	piece.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-6, 6), randf_range(-4, 4))
	Fx.smash(middle, push, "wood", 0.5)
	Sfx.play_at(&"crate_break", middle, 2.0)
	Sfx.play_at(&"clang", middle, -2.0)
