extends Node
## Pooled combat effects: bullet-hole decals, sparks, dust, flesh hits and tracers.
## Everything is allocated once at startup so firing never allocates nodes or hitches.
## Emissive colours deliberately exceed 1.0 so the glow pass picks them up.

const DECAL_POOL := 64
const SPARK_POOL := 10
const DUST_POOL := 10
const FLESH_POOL := 8
const TRACER_POOL := 24
const TRACER_SPEED := 320.0
const TRACER_LENGTH := 5.0
const WORLD_MASK := 1
## Decals only project onto visual layer 1, so they never paint over enemies (layer 2).
const DECAL_CULL_MASK := 1

var _decals: Array[Decal] = []
var _sparks: Array[GPUParticles3D] = []
var _dust: Array[GPUParticles3D] = []
var _flesh: Array[GPUParticles3D] = []
var _tracers: Array[MeshInstance3D] = []
var _next := {"decal": 0, "spark": 0, "dust": 0, "flesh": 0, "tracer": 0}
## Per active tracer: [from, direction, length_of_path, travelled].
var _tracer_state: Array[Array] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var hole := _make_hole_texture()
	for i in DECAL_POOL:
		var d := Decal.new()
		d.size = Vector3(0.28, 0.25, 0.28)
		d.texture_albedo = hole
		d.cull_mask = DECAL_CULL_MASK
		d.upper_fade = 0.5
		d.lower_fade = 0.5
		d.distance_fade_enabled = true
		d.distance_fade_begin = 45.0
		d.distance_fade_length = 12.0
		d.visible = false
		add_child(d)
		_decals.append(d)
	for i in SPARK_POOL:
		_sparks.append(_make_emitter(_spark_material(), _spark_mesh(), 14, 0.5, true))
	for i in DUST_POOL:
		_dust.append(_make_emitter(_dust_material(), _dust_mesh(), 6, 0.9, false))
	for i in FLESH_POOL:
		_flesh.append(_make_emitter(_flesh_material(), _flesh_mesh(), 10, 0.55, true))
	var tracer_mat := StandardMaterial3D.new()
	tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer_mat.albedo_color = Color(4.0, 3.0, 1.4)
	tracer_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tracer_mesh := BoxMesh.new()
	tracer_mesh.size = Vector3(0.012, 0.012, 1.0)
	tracer_mesh.material = tracer_mat
	for i in TRACER_POOL:
		var t := MeshInstance3D.new()
		t.mesh = tracer_mesh
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.visible = false
		add_child(t)
		_tracers.append(t)
		_tracer_state.append([])
	set_process(false)


func _process(delta: float) -> void:
	var any_active := false
	for i in TRACER_POOL:
		var state := _tracer_state[i]
		if state.is_empty():
			continue
		var from: Vector3 = state[0]
		var dir: Vector3 = state[1]
		var path_len: float = state[2]
		var travelled: float = state[3] + TRACER_SPEED * delta
		state[3] = travelled
		var tail := maxf(travelled - TRACER_LENGTH, 0.0)
		var head := minf(travelled, path_len)
		if tail >= path_len:
			_tracers[i].visible = false
			_tracer_state[i] = []
			continue
		any_active = true
		var seg := maxf(head - tail, 0.01)
		var tracer := _tracers[i]
		tracer.visible = true
		tracer.global_transform = Transform3D(
			_basis_looking(dir, seg), from + dir * (tail + seg * 0.5)
		)
	set_process(any_active)


## Tracer streak from `from` to `to`. Colour is multiplied so it reads in HDR.
func tracer(from: Vector3, to: Vector3, color := Color(1.0, 0.78, 0.35)) -> void:
	var offset := to - from
	var path_len := offset.length()
	if path_len < 1.0:
		return
	var i: int = _take("tracer", TRACER_POOL)
	var mat := _tracers[i].mesh.material as StandardMaterial3D
	mat.albedo_color = Color(color.r * 4.0, color.g * 4.0, color.b * 4.0)
	_tracer_state[i] = [from, offset / path_len, path_len, 0.0]
	_tracers[i].visible = false
	set_process(true)


## Hit on level geometry: decal, sparks, dust.
func world_impact(position: Vector3, normal: Vector3) -> void:
	var d := _decals[_take("decal", DECAL_POOL)]
	d.visible = true
	d.global_transform = Transform3D(_basis_from_normal(normal, _rng.randf() * TAU), position)
	_burst(_sparks[_take("spark", SPARK_POOL)], position, normal)
	_burst(_dust[_take("dust", DUST_POOL)], position, normal)


## Hit on an enemy: no decal, red droplets instead.
func flesh_impact(position: Vector3, normal: Vector3) -> void:
	_burst(_flesh[_take("flesh", FLESH_POOL)], position, normal)


## Fires `count` random rays through `origin` along `forward`, for the benchmark.
func test_burst(space: PhysicsDirectSpaceState3D, origin: Vector3, forward: Vector3, count: int) -> void:
	for i in count:
		# Aim slightly downwards so most rays land on the floor 6 to 20 m ahead and stay on screen.
		var dir := (
			forward
			+ Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.3, -0.08), _rng.randf_range(-0.1, 0.1))
		).normalized()
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 40.0, WORLD_MASK)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		tracer(origin + Vector3(0.2, -0.15, -0.3), hit.position)
		world_impact(hit.position, hit.normal)


func _take(kind: String, pool_size: int) -> int:
	var i: int = _next[kind]
	_next[kind] = (i + 1) % pool_size
	return i


func _burst(emitter: GPUParticles3D, position: Vector3, normal: Vector3) -> void:
	emitter.global_transform = Transform3D(_basis_from_normal(normal, 0.0), position + normal * 0.03)
	emitter.restart()
	emitter.emitting = true


## Basis whose Y axis is `normal`, spun by `spin` radians around it.
func _basis_from_normal(normal: Vector3, spin: float) -> Basis:
	var up := normal.normalized()
	var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.95 else Vector3.FORWARD
	var x := ref.cross(up).normalized()
	var z := x.cross(up).normalized()
	return Basis(x, up, z).rotated(up, spin)


## Basis whose -Z axis points along `dir`, with Z scaled to `length` (tracer box is 1 m long).
func _basis_looking(dir: Vector3, length: float) -> Basis:
	var ref := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var x := ref.cross(dir).normalized()
	var y := dir.cross(x).normalized()
	return Basis(x, y, dir).scaled(Vector3(1.0, 1.0, length))


func _make_emitter(
	material: ParticleProcessMaterial, mesh: Mesh, amount: int, lifetime: float, align_to_velocity: bool
) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.process_material = material
	p.draw_pass_1 = mesh
	p.local_coords = false
	p.fixed_fps = 0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	if align_to_velocity:
		p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Y_TO_VELOCITY
	add_child(p)
	return p


func _spark_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 62.0
	m.initial_velocity_min = 2.5
	m.initial_velocity_max = 7.5
	m.gravity = Vector3(0, -9.8, 0)
	m.damping_min = 0.5
	m.damping_max = 1.5
	m.scale_min = 0.6
	m.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(5.0, 3.2, 1.2, 1.0))
	fade.set_color(1, Color(2.0, 0.5, 0.1, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	m.color_ramp = ramp
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0.15))
	var shrink_tex := CurveTexture.new()
	shrink_tex.curve = shrink
	m.scale_curve = shrink_tex
	return m


func _spark_mesh() -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, 0.11, 0.012)
	mesh.material = _unshaded_vertex_color()
	return mesh


func _dust_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 40.0
	m.initial_velocity_min = 0.4
	m.initial_velocity_max = 1.6
	m.gravity = Vector3(0, 0.25, 0)
	m.damping_min = 2.0
	m.damping_max = 3.0
	m.scale_min = 0.5
	m.scale_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, Color(0.62, 0.58, 0.52, 0.5))
	fade.set_color(1, Color(0.55, 0.52, 0.48, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	m.color_ramp = ramp
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.35))
	grow.add_point(Vector2(1, 1.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	m.scale_curve = grow_tex
	return m


func _dust_mesh() -> Mesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.28, 0.28)
	var mat := _unshaded_vertex_color()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _make_soft_dot()
	mesh.material = mat
	return mesh


func _flesh_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 55.0
	m.initial_velocity_min = 1.5
	m.initial_velocity_max = 4.5
	m.gravity = Vector3(0, -12.0, 0)
	m.scale_min = 0.7
	m.scale_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, Color(0.7, 0.02, 0.02, 1.0))
	fade.set_color(1, Color(0.25, 0.0, 0.0, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	m.color_ramp = ramp
	return m


func _flesh_mesh() -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.015, 0.06, 0.015)
	mesh.material = _unshaded_vertex_color()
	return mesh


func _unshaded_vertex_color() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _make_soft_dot() -> ImageTexture:
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var r := (Vector2(x, y) / (size - 1) * 2.0 - Vector2.ONE).length()
			img.set_pixel(x, y, Color(1, 1, 1, 1.0 - smoothstep(0.0, 1.0, r)))
	return ImageTexture.create_from_image(img)


func _make_hole_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.14
	for y in size:
		for x in size:
			var p := Vector2(x, y) / (size - 1) * 2.0 - Vector2.ONE
			var r := p.length()
			var rr := r + noise.get_noise_2d(x, y) * 0.28
			var hole := 1.0 - smoothstep(0.1, 0.2, rr)
			var scorch := (1.0 - smoothstep(0.15, 0.85, rr)) * 0.7
			var alpha := maxf(hole, scorch) * (1.0 - smoothstep(0.82, 1.0, r))
			var shade := lerpf(0.09, 0.015, hole)
			img.set_pixel(x, y, Color(shade, shade, shade, alpha))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
