extends Node3D
## Somebody in a seat of a vehicle as seen from outside it: a soldier, posed
## by a clip of assets/animations/moves.res, at the wheel or just sitting,
## with the hips where the seat has them. The player of this machine has no
## body anybody sees; while the view of a vehicle is from behind, this sits
## where the player does. See scripts/vehicle.gd.

const MOVES: AnimationLibrary = preload("res://assets/animations/moves.res")
## Who the player is: the first of the soldiers of scripts/puppet.gd, and in
## the second side of a match in the uniform of that side.
const SOLDIER := "res://assets/characters/soldier_01/soldier_01.glb"
const SECOND := "res://assets/characters/soldier_01_desert/soldier_01_desert.glb"

var _figure: Node3D


## What a rider is drawn with, for Fx.rehearse(): the meshes of both
## uniforms, without their skeletons.
static func looks() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for path: String in [SOLDIER, SECOND]:
		if not ResourceLoader.exists(path):
			continue
		var figure: Node = (load(path) as PackedScene).instantiate()
		for mesh: MeshInstance3D in figure.find_children("*", "MeshInstance3D", true, false):
			var copy := MeshInstance3D.new()
			copy.mesh = mesh.mesh
			for i in mesh.get_surface_override_material_count():
				copy.set_surface_override_material(i, mesh.get_surface_override_material(i))
			found.append(copy)
		figure.free()
	return found


## Dresses it as `who` would be dressed and poses it with `move`. False if
## that cannot be done, and then it shows nothing.
func setup(who: Node3D, move: String) -> bool:
	var path := SECOND if Match.active and int(who.get(&"team")) == 1 and ResourceLoader.exists(SECOND) else SOLDIER
	var character := load(path) as PackedScene
	if character == null:
		return false
	_figure = character.instantiate()
	var skeleton := _figure.find_child("GeneralSkeleton", true, false) as Skeleton3D
	if skeleton == null or skeleton.find_bone("Hips") < 0 or not MOVES.has_animation(move):
		_figure.free()
		return false
	for player: Node in _figure.find_children("*", "AnimationPlayer", true, false):
		player.free()
	# A character looks along +Z, a vehicle along -Z.
	_figure.rotation.y = PI
	add_child(_figure)
	for mesh: MeshInstance3D in _figure.find_children("*", "MeshInstance3D", true, false):
		mesh.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	var library := AnimationLibrary.new()
	library.add_animation(move, MOVES.get_animation(move))
	var animator := AnimationPlayer.new()
	animator.add_animation_library(&"", library)
	_figure.add_child(animator)
	animator.root_node = animator.get_path_to(skeleton)
	animator.play(move)
	animator.advance(0.0)
	# The hips where the seat has them.
	var to_figure := Transform3D()
	var node: Node = skeleton
	while node != _figure:
		to_figure = (node as Node3D).transform * to_figure
		node = node.get_parent()
	var hips: Vector3 = to_figure * skeleton.get_bone_global_pose(skeleton.find_bone("Hips")).origin
	_figure.position = -(_figure.transform.basis * hips)
	return true
