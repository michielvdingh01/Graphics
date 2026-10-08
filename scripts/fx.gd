extends Node
## Short-lived visual effects: tracers, impact sparks and bullet holes.
## Everything is parented to the current scene so a scene reload cleans it up.

const MAX_HOLES := 64
const TRACER_TIME := 0.05

var _tracer_mesh := BoxMesh.new()
var _spark_mesh := BoxMesh.new()
var _hole_mesh := QuadMesh.new()
var _holes: Array[Node3D] = []


func _ready() -> void:
	_tracer_mesh.size = Vector3(0.012, 0.012, 1.0)
	_spark_mesh.size = Vector3.ONE * 0.025

	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.vertex_color_use_as_albedo = true
	_spark_mesh.material = spark_mat

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.02, 0.02, 0.02, 0.95), Color(0.05, 0.05, 0.05, 0.0)])
	var hole_tex := GradientTexture2D.new()
	hole_tex.gradient = gradient
	hole_tex.fill = GradientTexture2D.FILL_RADIAL
	hole_tex.fill_from = Vector2(0.5, 0.5)
	hole_tex.fill_to = Vector2(1.0, 0.5)
	hole_tex.width = 32
	hole_tex.height = 32
	var hole_mat := StandardMaterial3D.new()
	hole_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hole_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hole_mat.albedo_texture = hole_tex
	_hole_mesh.size = Vector2.ONE * 0.09
	_hole_mesh.material = hole_mat


func tracer(from: Vector3, to: Vector3, color := Color(4.0, 3.0, 1.5)) -> void:
	var length := from.distance_to(to)
	if length < 0.5:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	var streak := MeshInstance3D.new()
	streak.mesh = _tracer_mesh
	streak.material_override = mat
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	streak.transform = Transform3D(_facing(to - from).scaled_local(Vector3(1, 1, length)), (from + to) * 0.5)
	_spawn(streak, TRACER_TIME)


func sparks(position: Vector3, direction: Vector3, color := Color(4.0, 2.5, 1.0), amount := 8) -> void:
	var particles := CPUParticles3D.new()
	particles.mesh = _spark_mesh
	particles.amount = amount
	particles.lifetime = 0.35
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = direction
	particles.spread = 40.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 6.0
	particles.color = color
	particles.position = position
	particles.emitting = true
	_spawn(particles, 0.6)


## Sparks plus a bullet hole on world geometry.
func impact(position: Vector3, normal: Vector3) -> void:
	sparks(position, normal)
	Sfx.play_at(&"impact", position, -8.0)
	var hole := MeshInstance3D.new()
	hole.mesh = _hole_mesh
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# QuadMesh faces +Z, so look along the inverted normal.
	hole.transform = Transform3D(_facing(-normal), position + normal * 0.005)
	get_tree().current_scene.add_child(hole)
	_holes.append(hole)
	_holes = _holes.filter(is_instance_valid)
	while _holes.size() > MAX_HOLES:
		_holes.pop_front().queue_free()


func _facing(direction: Vector3) -> Basis:
	var up := Vector3.RIGHT if absf(direction.normalized().y) > 0.99 else Vector3.UP
	return Basis.looking_at(direction, up)


func _spawn(node: Node3D, lifetime: float) -> void:
	get_tree().current_scene.add_child(node)
	get_tree().create_timer(lifetime, false).timeout.connect(node.queue_free)
