extends Node3D
## The grass of a meadow of kilometres, which nobody could strew tuft by tuft:
## it is drawn round whoever looks, as far as grass is seen, and only there.
## Every tuft stands on a grid in the world, so that it stays where it stands
## while the eye moves; where on the grid the eye is, the shader works out
## for itself, and from the maps of the land how high the ground is there
## and whether grass grows on it (shaders/alps_grass.gdshader). Nothing of it
## is in anybody's way, and it throws no shadow.
##
## It is three rings round the eye, each with its tufts twice as far apart
## and twice as large as the one inside it: as many tufts as it takes to
## cover the ground near by, and the ground itself further off.

## The rings: how far apart the tufts stand in each, and how far out it
## reaches. A ring begins where the one inside it ends.
const RINGS := [[0.42, 14.0], [0.85, 32.0], [1.7, 66.0]]

## The material of the grass, which the level hands the maps of its land.
@export var look: ShaderMaterial


func _ready() -> void:
	if look == null:
		return
	var tuft := _tuft()
	var inside := 0.0
	for ring: Array in RINGS:
		var spacing: float = ring[0]
		var reach: float = ring[1]
		var columns := int(ceilf(reach * 2.0 / spacing)) + 2
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = tuft
		multi.instance_count = columns * columns
		var drawn := MultiMeshInstance3D.new()
		drawn.multimesh = multi
		var material := look.duplicate() as ShaderMaterial
		material.set_shader_parameter("spacing", spacing)
		material.set_shader_parameter("columns", columns)
		material.set_shader_parameter("hole", inside)
		material.set_shader_parameter("reach", reach)
		drawn.material_override = material
		drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		drawn.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		# Wherever the eye is, the ring is round it.
		drawn.custom_aabb = AABB(Vector3(-1e5, -1e4, -1e5), Vector3(2e5, 2e4, 2e5))
		add_child(drawn)
		inside = reach


## One tuft: three cards through each other, each with one of the four plants
## of the picture on it, its foot at the origin and a size of one. The vertex
## colour says what grass.gdshader takes it to say: red how far a corner
## bends in the wind, blue how much light gets to it, alpha nothing (the
## shader works out per tuft how much is straw).
func _tuft() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dice := RandomNumberGenerator.new()
	dice.seed = 41
	for card in 3:
		var angle := card * TAU / 3.0 + dice.randf_range(-0.3, 0.3)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-out.z, 0.0, out.x)
		var quarter := card % 4
		var top := 0.42 if quarter < 2 else 0.2
		var high := (1.0 - top) * 1.1
		var half := 0.3
		var left := quarter * 0.25 + 0.003
		var right := quarter * 0.25 + 0.247
		var lean := out * high * 0.25
		var low := -out * 0.05
		var corners: Array[Vector3] = [low - side * half, low + side * half, low + lean + Vector3.UP * high + side * half, low + lean + Vector3.UP * high - side * half]
		var uvs: Array[Vector2] = [Vector2(left, 1.0), Vector2(right, 1.0), Vector2(right, top), Vector2(left, top)]
		var lit: Array[Color] = [Color(0, 0, 0.6, 0), Color(0, 0, 0.6, 0), Color(1, 0, 1, 0), Color(1, 0, 1, 0)]
		var normal := (Vector3.UP + out * 0.3).normalized()
		for corner: int in [0, 2, 1, 0, 3, 2]:
			st.set_color(lit[corner])
			st.set_normal(normal)
			st.set_uv(uvs[corner])
			st.add_vertex(corners[corner])
	return st.commit()
