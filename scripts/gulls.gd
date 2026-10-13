extends MultiMeshInstance3D
## Gulls over the dunes: a few of them wheeling high up, alone and in twos
## and threes, where the land is open. They are there to be seen from far
## below and are in nobody's way. One mesh, drawn once for all of them; each
## flies its circle in shaders/gull.gdshader. Stands in the scene of a level.

## Where they wheel: the middle of a circle (x, height, z) and its radius, in
## metres, for every loose group.
const HAUNTS: Array[Vector4] = [
	Vector4(205, 44, 186, 40), Vector4(118, 52, 126, 52), Vector4(250, 40, 70, 36), Vector4(60, 60, 40, 64),
]
## How many there are in each, and how fast a gull flies, in metres a second.
const FLOCK := [3, 2, 3, 1]
const AIRSPEED := 10.0
## Half the span of a wing and the length of the body, in metres. A herring
## gull spans 1.4 m; from the ground a bird a little larger reads better.
const WING := 0.85
const BODY := 0.62


func _ready() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = 1953
	var paint := ShaderMaterial.new()
	paint.shader = load("res://shaders/gull.gdshader")
	var flock := MultiMesh.new()
	flock.transform_format = MultiMesh.TRANSFORM_3D
	flock.use_custom_data = true
	flock.mesh = _bird()
	flock.mesh.surface_set_material(0, paint)
	var count := 0
	for birds: int in FLOCK:
		count += birds
	flock.instance_count = count
	var bird := 0
	var reach := AABB()
	for haunt in HAUNTS.size():
		for i: int in FLOCK[haunt]:
			var middle := Vector3(HAUNTS[haunt].x, HAUNTS[haunt].y, HAUNTS[haunt].z) + Vector3(dice.randf_range(-9, 9), dice.randf_range(-7, 7), dice.randf_range(-9, 9))
			var radius := HAUNTS[haunt].w * dice.randf_range(0.7, 1.15)
			var way := 1.0 if haunt % 2 == 0 else -1.0
			flock.set_instance_transform(bird, Transform3D(Basis(), middle))
			flock.set_instance_custom_data(bird, Color(radius, dice.randf() * TAU, way * AIRSPEED * dice.randf_range(0.85, 1.1) / radius, dice.randf() * TAU))
			var box := AABB(middle - Vector3.ONE * (radius + 3.0), Vector3.ONE * (radius + 3.0) * 2.0)
			reach = box if bird == 0 else reach.merge(box)
			bird += 1
	multimesh = flock
	# The birds are not where the mesh says: they are anywhere on their circles.
	custom_aabb = reach
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ignore_occlusion_culling = true


## A gull with its wings out, looking along Z: a body and, to either side,
## an arm and a hand of the wing, swept back.
func _bird() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body: Array[Vector3] = [Vector3(0, 0, BODY * 0.5), Vector3(0.07, 0, 0), Vector3(0, 0, -BODY * 0.5), Vector3(-0.07, 0, 0)]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_uv(Vector2.ZERO)
		st.set_normal(Vector3.UP)
		st.add_vertex(body[i])
	for side: float in [-1.0, 1.0]:
		# Shoulder, front and back; wrist, front and back; tip.
		var points: Array[Vector3] = [
			Vector3(0.05 * side, 0, 0.16), Vector3(0.05 * side, 0, -0.1),
			Vector3(WING * 0.5 * side, 0, 0.2), Vector3(WING * 0.5 * side, 0, -0.02),
			Vector3(WING * side, 0, -0.2),
		]
		var out: Array[float] = [0.0, 0.0, 0.5, 0.5, 1.0]
		for i: int in [0, 2, 1, 1, 2, 3, 2, 4, 3]:
			st.set_uv(Vector2(out[i], 0.0))
			st.set_normal(Vector3.UP)
			st.add_vertex(points[i])
	return st.commit()
