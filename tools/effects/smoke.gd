extends RefCounted
## The smoke of an explosion and of a fire is handed the light it hangs in:
## the sun in a patch of sunlight, a lamp or the light from above in the
## shade. And every cloud is gone when its time is over.

## A patch of sunlight on the floor of the hall, and a corner the sun does
## not get to.
const SUNLIT := Vector3(15.0, 0.45, -1.0)
const SHADED := Vector3(17.5, 0.45, 9.5)
## What Fx.smoke_light() hands in, and what else the shader is told by name.
const LIGHT: Array[StringName] = [&"key", &"key_light", &"fill"]
const TOLD: Array[StringName] = [&"key", &"key_light", &"fill", &"ember", &"amount", &"start"]


func run(test: SceneTree) -> void:
	var game: Node = await test.level()
	var fx: Node = test.autoload("Fx")
	var sun: DirectionalLight3D = game.find_children("*", "DirectionalLight3D", false, false)[0]
	var over: Vector3 = Vector3.UP * fx.SMOKE_HEIGHT

	test.check(fx.light_at(SUNLIT + over) > 1.0 and fx.light_at(SHADED + over) == 1.0, "one spot is in the sun and the other is not")
	var bright: Dictionary = fx.smoke_light(SUNLIT + over)
	var dim: Dictionary = fx.smoke_light(SHADED + over)
	test.check(LIGHT.all(func(title: StringName) -> bool: return bright.has(title) and dim.has(title)), "the light on smoke comes as a key light and the light from all around")
	test.check((bright.key as Vector3).dot(sun.global_basis.z) > 0.999, "in the sun the key light is the sun, and points at it")
	test.check((dim.key as Vector3).dot(sun.global_basis.z) < 0.99, "in the shade it is not")
	test.check((bright.key_light as Vector3).length() > (dim.key_light as Vector3).length() * 1.5, "the sun is the brighter of the two")
	test.check((dim.fill as Vector3).length() > 0.0 and (dim.key_light as Vector3).length() > 0.0, "smoke in the shade is not left black")

	var shader: Shader = (fx._clouds as Mesh).surface_get_material(0).shader
	test.check(shader == (fx._smoke as Mesh).surface_get_material(0).shader, "the cloud and the column are drawn by one shader")
	var declared := RegEx.create_from_string("instance uniform \\w+ (\\w+)")
	var names: Array = declared.search_all(shader.code).map(func(found: RegExMatch) -> StringName: return StringName(found.get_string(1)))
	test.check(TOLD.all(func(title: StringName) -> bool: return names.has(title)), "the shader takes what it is told by those names")

	var before := _clouds(game, fx)
	fx.explosion(SUNLIT)
	var sunny := _clouds(game, fx).filter(func(cloud: MeshInstance3D) -> bool: return not before.has(cloud))
	test.check(sunny.size() == 4, "an explosion sets off its cloud, its fire, its column and a ring of dust (%d)" % sunny.size())
	test.check(sunny.all(func(cloud: MeshInstance3D) -> bool: return _lit_as(cloud, bright)), "each of them is handed the way to the sun and the light from all around")
	test.check(sunny.any(func(cloud: MeshInstance3D) -> bool: return cloud.get_instance_shader_parameter(&"key_light") == bright.key_light), "and the cloud all of the light of the sun")
	fx.explosion(SHADED)
	var shady := _clouds(game, fx).filter(func(cloud: MeshInstance3D) -> bool: return not before.has(cloud) and not sunny.has(cloud))
	test.check(shady.size() == 4 and shady.all(func(cloud: MeshInstance3D) -> bool: return _lit_as(cloud, dim)), "an explosion in the shade is handed the light of the shade")

	var lamp := _lamp_over_smoke(fx, sun)
	test.check(lamp != null, "somewhere in the hall a lamp is the key light")
	if lamp:
		var under := lamp.global_position + Vector3.DOWN * 2.0
		var with: Dictionary = fx.smoke_light(under)
		lamp.visible = false
		var without: Dictionary = fx.smoke_light(under)
		lamp.visible = true
		test.check((without.key_light as Vector3).length() < (with.key_light as Vector3).length(), "with that lamp out the smoke under it gets less light")

	var floor_y: float = fx.floor_below(SHADED)
	var flames: Node3D = fx.fire(Vector3(SHADED.x, floor_y, SHADED.z), 1.2, 4.0)
	var until: float = fx.time + 4.0
	fx.advance(1.0)
	var risen := _clouds(game, fx).filter(func(cloud: MeshInstance3D) -> bool: return cloud.get_instance_shader_parameter(&"ember") != null)
	test.check(not risen.is_empty(), "smoke rises off a fire")
	test.check(risen.all(func(cloud: MeshInstance3D) -> bool:
		var ember: Vector2 = cloud.get_instance_shader_parameter(&"ember")
		return ember.x > 0.0 and is_equal_approx(ember.y, until)), "and is lit from below until the fire is out")

	var stage_before: int = fx.get_child_count()
	fx.rehearse()
	var rehearsed: Array[Mesh] = []
	for stage in fx.get_children().slice(stage_before):
		for burst in stage.get_children():
			if burst is MeshInstance3D and burst.get_instance_shader_parameter(&"amount") == -1.0:
				rehearsed.append(burst.mesh)
	test.check(rehearsed.has(fx._clouds) and rehearsed.has(fx._smoke), "the rehearsal draws both meshes of the smoke, with nothing in them")

	# The column of an explosion is the last of it to go, after six seconds;
	# the smoke of a fire goes three seconds after the fire.
	fx.advance(8.0)
	flames.queue_free()
	await test.frames(2)
	test.check(_clouds(game, fx).is_empty(), "every cloud is freed when its time is over")


## The bursts of smoke that are in the level now.
func _clouds(game: Node, fx: Node) -> Array:
	return game.get_children().filter(func(node: Node) -> bool:
		return node is MeshInstance3D and not node.is_queued_for_deletion() and (node.mesh == fx._clouds or node.mesh == fx._smoke))


## Whether a burst was handed `light` when it was set off: the way to its key
## light and what comes from all around. How much of the key light gets to
## it is its own.
func _lit_as(cloud: MeshInstance3D, light: Dictionary) -> bool:
	var some: Vector3 = cloud.get_instance_shader_parameter(&"key_light")
	return cloud.get_instance_shader_parameter(&"key") == light.key and cloud.get_instance_shader_parameter(&"fill") == light.fill and some.length() > 0.0


## A lamp that is the key light of smoke two metres under it, if the level
## has one.
func _lamp_over_smoke(fx: Node, sun: DirectionalLight3D) -> Light3D:
	for lamp: Light3D in fx._level_lamps():
		var under := lamp.global_position + Vector3.DOWN * 2.0
		var key: Vector3 = fx.smoke_light(under).key
		if key.dot((lamp.global_position - under).normalized()) > 0.999 and key.dot(sun.global_basis.z) < 0.99:
			return lamp
	return null
