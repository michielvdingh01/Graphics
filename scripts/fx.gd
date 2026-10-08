extends Node
## Short-lived visual effects: tracers, impact sparks, bullet holes and spent cases.
## Everything is parented to the current scene so a scene reload cleans it up.

const MAX_HOLES := 64
const TRACER_TIME := 0.05
const MAX_CASINGS := 24
const CASING_TIME := 3.0

var _tracer_mesh := BoxMesh.new()
var _spark_mesh := BoxMesh.new()
var _hole_mesh := QuadMesh.new()
var _holes: Array[Node3D] = []
var _casing_mesh := CylinderMesh.new()
var _shell_mesh := CylinderMesh.new()
var _shell_head := CylinderMesh.new()
## Spent cases in flight: {node, velocity, spin, floor, age, bounces}.
var _casings: Array[Dictionary] = []


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

	var brass: Material = load("res://materials/brass.tres")
	for mesh: CylinderMesh in [_casing_mesh, _shell_mesh, _shell_head]:
		mesh.radial_segments = 10
		mesh.rings = 0
		mesh.material = brass
	_casing_mesh.top_radius = 0.0042
	_casing_mesh.bottom_radius = 0.0048
	_casing_mesh.height = 0.03
	_shell_mesh.top_radius = 0.0101
	_shell_mesh.bottom_radius = 0.0101
	_shell_mesh.height = 0.045
	_shell_mesh.material = load("res://materials/enamel_red.tres")
	_shell_head.top_radius = 0.0104
	_shell_head.bottom_radius = 0.0104
	_shell_head.height = 0.014


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


## Spent case thrown from a weapon that points along `basis`: it tumbles,
## bounces off the floor below and lies there a while. `shell` makes it the
## hull of a shotgun shell.
func casing(position: Vector3, basis: Basis, velocity: Vector3, shell := false) -> void:
	var node := MeshInstance3D.new()
	node.mesh = _shell_mesh if shell else _casing_mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	if shell:
		var head := MeshInstance3D.new()
		head.mesh = _shell_head
		head.position.y = -0.0295
		head.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		node.add_child(head)
	# It leaves lying along the barrel.
	node.transform = Transform3D(basis * Basis(Vector3.RIGHT, PI * 0.5), position)
	get_tree().current_scene.add_child(node)
	var floor_y := position.y - 4.0
	var query := PhysicsRayQueryParameters3D.create(position, position + Vector3.DOWN * 4.0, 1)
	var hit := node.get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		floor_y = hit.position.y
	var spin := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(12.0, 30.0)
	_casings.append({"node": node, "velocity": velocity, "spin": spin, "floor": floor_y + (0.011 if shell else 0.005), "age": 0.0, "bounces": 0})
	if _casings.size() > MAX_CASINGS:
		var oldest: Dictionary = _casings.pop_front()
		if is_instance_valid(oldest.node):
			oldest.node.queue_free()


func _process(delta: float) -> void:
	for i in range(_casings.size() - 1, -1, -1):
		var item := _casings[i]
		var node: MeshInstance3D = item.node
		# A scene reload takes the cases with it.
		if not is_instance_valid(node):
			_casings.remove_at(i)
			continue
		item.age += delta
		if item.age > CASING_TIME:
			node.queue_free()
			_casings.remove_at(i)
		elif item.bounces < 3:
			item.velocity.y -= 9.8 * delta
			node.position += item.velocity * delta
			node.rotate(item.spin.normalized(), item.spin.length() * delta)
			if node.position.y < item.floor and item.velocity.y < 0.0:
				node.position.y = item.floor
				item.bounces += 1
				if item.bounces == 1:
					Sfx.play_at(&"casing", node.position, -12.0)
				item.velocity = Vector3(item.velocity.x * 0.45, -item.velocity.y * 0.3, item.velocity.z * 0.45)
				item.spin *= 0.4
				if item.velocity.y < 0.5:
					# Too slow to leave the floor again: it comes to rest on its side.
					item.bounces = 3
					node.rotation = Vector3(PI * 0.5, node.rotation.y, 0.0)


func _facing(direction: Vector3) -> Basis:
	var up := Vector3.RIGHT if absf(direction.normalized().y) > 0.99 else Vector3.UP
	return Basis.looking_at(direction, up)


func _spawn(node: Node3D, lifetime: float) -> void:
	get_tree().current_scene.add_child(node)
	get_tree().create_timer(lifetime, false).timeout.connect(node.queue_free)
