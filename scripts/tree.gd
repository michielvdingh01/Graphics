extends Node3D
## A tree of tools/models/trees.gd as the game shows it. It is drawn three
## times over and shows the drawing that fits how far off it is; where one
## gives way to the next, it does so a tuft at a time, see
## shaders/tree_lod.gdshaderinc. Over which distances is in the meta "shown"
## of each drawing, and handed to its shaders here: whoever built the tree
## could not, without anything to draw with.


func _ready() -> void:
	for part in get_children():
		if part.has_meta(&"shown"):
			(part as GeometryInstance3D).set_instance_shader_parameter(&"shown", part.get_meta(&"shown"))
