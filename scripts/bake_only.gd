extends Node3D
## What hangs under this node is there for the bake and gone in the game.
##
## A lamp whose light is all in the lightmap (Light3D.BAKE_STATIC) lights
## nothing that is baked, but the renderer still hands it to every pixel
## within its range, and whatever has no lightmap is lit by it in full: the
## models, the pipework, a robot. With eleven of them along the walls of the
## switch room of the powerhouse that was 1.4 ms of a frame of 16, at the
## settings the game is played at, and 1.1 ms in the room next door. Marking
## such a lamp as editor-only will not do: a bake leaves those out.
##
## The level builder hangs them here, see wall_lamp() in tools/kit/services.gd.


func _ready() -> void:
	# The editor, and with it the bake, runs no script that is not a tool; a
	# tool that loads a level by itself has no game around it.
	if not Engine.is_editor_hint() and get_node_or_null(^"/root/Settings") != null:
		queue_free()
