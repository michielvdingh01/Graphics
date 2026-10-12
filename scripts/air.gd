extends GPUParticles3D
## What hangs in the air of open land: pollen, midges and dust, as specks
## that show only where the sun falls on them. Under the pines they glitter
## in the beams between the crowns; against sand in full sun they are lost,
## as they are to the eye.
##
## A room has its dust where the builder put it (dust() in
## tools/level_builder.gd). Land is too large for that: the specks are let
## go around whoever looks and stay where they were let go, so the air
## stands still when the camera moves through it. Stands in the scene of a
## level.

## The air that has specks in it, around the camera: across and high, in
## metres.
const AROUND := Vector3(18.0, 5.0, 18.0)
## How far over the camera the middle of that air lies: there is more to see
## overhead, against the crowns, than underfoot.
const RAISED := 1.2
## How fast the air moves as a whole, in metres a second: the breeze that
## sways the grass, slowed.
const BREEZE := Vector3(0.22, 0.0, 0.1)


func _ready() -> void:
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	var drift := ParticleProcessMaterial.new()
	drift.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	drift.emission_box_extents = AROUND * 0.5
	drift.spread = 180.0
	drift.initial_velocity_min = 0.02
	drift.initial_velocity_max = 0.12
	drift.gravity = BREEZE * 0.05
	drift.scale_min = 0.5
	drift.scale_max = 1.5
	drift.color_ramp = ramp
	drift.turbulence_enabled = true
	drift.turbulence_noise_strength = 0.4
	drift.turbulence_noise_scale = 2.5
	drift.turbulence_influence_min = 0.03
	drift.turbulence_influence_max = 0.12
	var speck := ShaderMaterial.new()
	speck.shader = load("res://shaders/dust.gdshader")
	speck.set_shader_parameter("brightness", 0.2)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.008, 0.008)
	quad.material = speck
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	amount = 900
	lifetime = 6.0
	preprocess = 6.0
	randomness = 1.0
	local_coords = false
	emitting = false
	# Wherever the specks have drifted to, they are within this of the node.
	visibility_aabb = AABB(-AROUND - Vector3.ONE * 6.0, (AROUND + Vector3.ONE * 6.0) * 2.0)
	process_material = drift
	draw_pass_1 = quad


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var at := camera.global_position + Vector3.UP * RAISED
	# Whoever walks leaves the specks behind and finds new ones; whoever is
	# set down somewhere else finds the air there as full as it was here.
	var moved := at.distance_to(global_position)
	global_position = at
	if not emitting or moved > AROUND.x * 0.5:
		restart()
		emitting = true
