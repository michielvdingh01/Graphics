extends Node
## The night over a level under an open sky. Stands in the scene of a level
## by night, beside its "Moon", and makes what the level was built with for
## the day fit the night.
##
## The level is the one the day has, as the builder made it: the same file.
## What it says about the light of the day, it says for the sun: under a
## tent, under a net and in the sheds the light from round about is the light
## of that roof by day (shelter() in tools/kit/field.gd). By night that is
## what the moon lets in, which is nearly nothing.

## What is left of the light under a roof by night, and the colour it takes.
@export var shelter_left := 0.05
@export var shelter_tint := Color(0.62, 0.72, 1.0)


func _ready() -> void:
	var level := get_parent().get_node_or_null(^"Level")
	if level == null:
		return
	for probe: ReflectionProbe in level.find_children("Shelter*", "ReflectionProbe", true, false):
		if probe.ambient_mode == ReflectionProbe.AMBIENT_COLOR:
			probe.ambient_color *= shelter_tint
			probe.ambient_color_energy *= shelter_left
