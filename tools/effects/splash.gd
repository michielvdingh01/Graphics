extends RefCounted
## A shot into a puddle: the effects know where the floor shader puts its
## water, a shot that lands in it throws up a splash instead of dust, and a
## shot beside it does what it always did.
##
## Where the water is, is worked out here a second time, from the mesh and
## the material of every floor and from the image of its mask, with the
## formula of shaders/wet_floor.gdshader written out again: what the effects
## say has to agree with that, not with themselves.

const WET_FLOOR := "res://shaders/wet_floor.gdshader"
const LEVELS: Array[String] = ["res://scenes/factory.tscn", "res://scenes/works.tscn", "res://scenes/depot.tscn", "res://scenes/powerhouse.tscn"]
## How many points of every level the effects are asked about.
const POINTS := 400
## The dust and the chips a shot knocks out of dry concrete, as strike() has
## made them since before there were splashes.
const DUST := Color(0.72, 0.7, 0.66, 0.5)
const CHIPS := Color(0.62, 0.6, 0.57)
## Milliseconds the lookup of a level may take.
const BUDGET := 10.0


func run(test: SceneTree) -> void:
	var fx: Node = test.autoload("Fx")
	var random := RandomNumberGenerator.new()
	random.seed = 7
	# A point of the works that lies on a floor there, and on none in the depot.
	var left_behind := Vector3.ZERO
	for scene in LEVELS:
		var title := scene.get_file().get_basename()
		var game: Node = await test.level(scene)
		test.check(fx._charted == game.get_instance_id(), "%s: the water is looked up as the level loads" % title)
		var floors: Array[Dictionary] = _floors(game)
		var waited: int = await _masks(test, fx, floors)
		# The least of a few goes: the laptop is seldom doing nothing else.
		var cost := INF
		for go in 5:
			var began := Time.get_ticks_usec()
			fx._chart_water()
			cost = minf(cost, (Time.get_ticks_usec() - began) / 1000.0)
		await _masks(test, fx, floors)
		var patches: int = fx._floors.size()
		print("  %s: %d floors in %d triangles, looked up in %.2f ms; the masks had their image %d frames after the level was there" % [title, floors.size(), patches, cost, waited])
		test.check(cost < BUDGET, "%s: looking it up takes less than %d ms" % [title, int(BUDGET)])
		test.check(not floors.is_empty() and patches == floors.size() * 2, "%s: every floor with the wet shader is found, two triangles each" % title)
		var skew := 0.0
		for ground in floors:
			skew = maxf(skew, ground.skew)
		test.check(skew < 0.001, "%s: the UV of the top of every floor is its position in metres (off by %.4f)" % [title, skew])

		var wet := 0
		var wrong := 0
		var afloat := 0
		for i in POINTS:
			var ground: Dictionary = floors[random.randi() % floors.size()]
			var rect: Rect2 = ground.rect
			var point := Vector3(random.randf_range(rect.position.x, rect.end.x), ground.height, random.randf_range(rect.position.y, rect.end.y))
			var expected := _puddle(ground.material, ground.image, Vector2(point.x, point.z))
			var found: float = fx.water_at(point)
			wet += int(expected > 0.5)
			wrong += int(absf(found - expected) > 0.002 or fx.in_puddle(point) != (expected > 0.5))
			afloat += int(fx.in_puddle(point + Vector3.UP * random.randf_range(0.06, 3.0)) or fx.in_puddle(point + Vector3.DOWN * random.randf_range(0.12, 3.0)))
			if title == "works" and expected > 0.9 and ground.height == 0.0 and point.x > 35.0 and point.z > 25.0:
				left_behind = point
		print("  %s: %d of %d points are in a puddle" % [title, wet, POINTS])
		test.check(wrong == 0, "%s: the effects and the formula of the floor shader agree at %d points (%d differ)" % [title, POINTS, wrong])
		test.check(wet > POINTS / 10 and wet < POINTS * 9 / 10, "%s: some of those points are wet and some are dry" % title)
		test.check(afloat == 0, "%s: no point above or below a floor is wet" % title)
		test.check(not fx.in_puddle(Vector3(4000.0, 0.0, 4000.0)), "%s: nor is one beyond every floor" % title)
		if title == "factory":
			await _shots(test, fx, game, floors, random)
		if title == "works":
			test.check(left_behind != Vector3.ZERO and fx.in_puddle(left_behind), "works: there is a puddle indoors, far from the first corner")
		if title == "depot":
			test.check(not fx.in_puddle(left_behind), "depot: where the works had a puddle, and the depot has no floor, it is dry")


## Shots in the factory hall: on dry floor, in a puddle, and on what is not
## the floor.
func _shots(test: SceneTree, fx: Node, game: Node, floors: Array[Dictionary], random: RandomNumberGenerator) -> void:
	var hall: Dictionary = floors[0]
	for ground in floors:
		if ground.height == 0.0 and (ground.rect as Rect2).get_area() > (hall.rect as Rect2).get_area():
			hall = ground
	# A puddle and a dry patch well inside the hall, and the wall behind them.
	var water := _spot(hall, random, true)
	var dry := _spot(hall, random, false)
	test.check(water != Vector3.ZERO and dry != Vector3.ZERO, "the hall of the factory has a puddle and a dry patch")
	var space := (game as Node3D).get_world_3d().direct_space_state
	var wall := {}
	for way: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(water + Vector3.UP, water + Vector3.UP + way * 100.0, 1))
		if not hit.is_empty() and absf(hit.normal.y) < 0.1:
			wall = hit
	test.check(not wall.is_empty(), "a look along the floor from the puddle ends on something upright")
	var down := Vector3(0.3, -1.0, 0.1).normalized()

	fx.clear()
	await test.frames(2)
	fx.strike(dry, Vector3.UP, down)
	var dust := _bursts(game, fx._puffs)
	var chips := _bursts(game, fx._chips)
	test.check(dust.size() == 1 and chips.size() == 1 and _bursts(game, fx._drops).is_empty() and _bursts(game, fx._rings).is_empty(),
		"a shot on dry floor makes a puff of dust and chips, and no splash")
	test.check(not dust.is_empty() and dust[0].get_instance_shader_parameter(&"tint") == DUST and dust[0].get_instance_shader_parameter(&"size") == Vector2(0.05, 0.32)
		and dust[0].get_instance_shader_parameter(&"life") == 1.4 and dust[0].get_instance_shader_parameter(&"amount") == 1.0,
		"the dust is the dust it made before")
	test.check(not chips.is_empty() and chips[0].get_instance_shader_parameter(&"tint") == CHIPS and chips[0].get_instance_shader_parameter(&"amount") == 1.0,
		"and the chips are the chips")
	test.check(fx._holes.size() == 1 and fx._holes[0].texture_normal != null and fx._holes[0].texture_orm != null, "it leaves a crater with its own relief")

	fx.clear()
	await test.frames(2)
	fx.strike(water, Vector3.UP, down)
	var drops := _bursts(game, fx._drops)
	var rings := _bursts(game, fx._rings)
	var spray := _bursts(game, fx._puffs)
	test.check(drops.size() == 2 and rings.size() == 1, "a shot in a puddle throws up drops and leaves rings")
	test.check(_bursts(game, fx._chips).is_empty() and _bursts(game, fx._sparks).is_empty(), "it knocks out no chips and strikes no spark")
	test.check(not spray.is_empty() and spray.all(func(puff: MeshInstance3D) -> bool: return puff.get_instance_shader_parameter(&"tint") != DUST),
		"what hangs over it is spray, not the dust of concrete")
	test.check(not rings.is_empty() and rings[0].material_override != null
		and rings[0].material_override.get_shader_parameter(&"wet_mask") == (hall.material as ShaderMaterial).get_shader_parameter(&"wet_mask")
		and rings[0].get_instance_shader_parameter(&"floor_uv") == Vector2(water.x, water.z),
		"the rings read the mask of the floor they are on, from where the shot landed")
	test.check(fx._holes.size() == 1 and fx._holes[0].texture_normal == null, "the pit under the water leaves the water smooth")
	var full: float = drops[0].get_instance_shader_parameter(&"amount") if not drops.is_empty() else 0.0
	var wide: float = rings[0].get_instance_shader_parameter(&"reach") if not rings.is_empty() else 0.0

	fx.clear()
	await test.frames(2)
	fx.strike(water, Vector3.UP, down, "concrete", true)
	drops = _bursts(game, fx._drops)
	rings = _bursts(game, fx._rings)
	test.check(drops.size() == 2 and rings.size() == 1 and drops[0].get_instance_shader_parameter(&"amount") < full and rings[0].get_instance_shader_parameter(&"reach") < wide,
		"one pellet of a load of shot makes a smaller splash")
	fx.advance(3.0)
	await test.frames(2)
	test.check(_bursts(game, fx._drops).is_empty() and _bursts(game, fx._rings).is_empty() and _bursts(game, fx._puffs).is_empty(), "three seconds on the drops, the rings and the spray are freed")

	fx.clear()
	await test.frames(2)
	fx.strike(water, Vector3.UP, down, "metal")
	fx.strike(water, Vector3.RIGHT, Vector3.LEFT)
	if not wall.is_empty():
		fx.strike(wall.position, wall.normal, Vector3.LEFT)
		test.check(not fx.in_puddle(wall.position) and not fx.in_puddle(Vector3(wall.position.x, 0.0, wall.position.z) + wall.normal * -0.2), "a point on a wall is not wet, nor one inside it")
	test.check(_bursts(game, fx._drops).is_empty() and _bursts(game, fx._rings).is_empty(), "steel that stands in a puddle, something upright in it and a wall do not splash")

	var sfx: Node = test.autoload("Sfx")
	var wet_sound := &"impact_water" if sfx.has(&"impact_water") else &"impact_soft"
	test.check(_sound_of(fx, sfx, water, "concrete") == wet_sound, "a shot in a puddle sounds like %s" % wet_sound)
	test.check(_sound_of(fx, sfx, dry, "concrete") == &"impact_concrete", "a shot on dry floor sounds like concrete")
	test.check(_sound_of(fx, sfx, water + Vector3.UP, "concrete") == &"impact_concrete", "and so does one on concrete over a puddle")
	test.check(_sound_of(fx, sfx, water, "metal") == &"impact_metal", "steel in a puddle sounds like steel")

	for mesh: Mesh in [fx._drops, fx._rings]:
		var shader := (mesh.surface_get_material(0) as ShaderMaterial).shader
		test.check(mesh in fx._bursts and "instance uniform float amount" in shader.code, "%s is rehearsed with the other bursts" % shader.resource_path.get_file().get_basename())


## Every floor of the level that is drawn with the wet shader: the rectangle
## its top covers (x and z), the height of that, its material and the
## furthest the UV of a corner is from its place in metres.
func _floors(game: Node) -> Array[Dictionary]:
	var floors: Array[Dictionary] = []
	for node: MeshInstance3D in game.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null:
			continue
		for surface in node.mesh.get_surface_count():
			var material := node.get_active_material(surface) as ShaderMaterial
			if material == null or material.shader == null or material.shader.resource_path != WET_FLOOR:
				continue
			var arrays := node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			# The top of a floor is two triangles that follow one another.
			for i in range(0, indices.size(), 6):
				if (node.global_basis * normals[indices[i]]).y < 0.99:
					continue
				var first := node.global_transform * vertices[indices[i]]
				var rect := Rect2(first.x, first.z, 0.0, 0.0)
				var skew := 0.0
				for corner in 6:
					var at := node.global_transform * vertices[indices[i + corner]]
					rect = rect.expand(Vector2(at.x, at.z))
					skew = maxf(skew, uvs[indices[i + corner]].distance_to(Vector2(at.x, at.z)))
				floors.append({"rect": rect, "height": first.y, "material": material, "skew": skew})
	return floors


## Waits until the mask of every floor has an image, here and in the lookup
## of the effects, and notes the image with the floor. Returns how many
## frames that took.
func _masks(test: SceneTree, fx: Node, floors: Array[Dictionary]) -> int:
	for attempt in 120:
		var ready: bool = not fx._floors.is_empty()
		for patch: RefCounted in fx._floors:
			ready = ready and not patch.water.mask.is_empty()
		for ground in floors:
			var mask := (ground.material as ShaderMaterial).get_shader_parameter(&"wet_mask") as Texture2D
			ground["image"] = mask.get_image()
			ready = ready and ground.image != null
		if ready:
			return attempt
		await test.process_frame
	test.check(false, "the mask of every floor gets an image within two seconds")
	return 120


## What shaders/wet_floor.gdshader calls `puddle` at `uv`: 1 where water
## stands, 0 on dry floor.
func _puddle(material: ShaderMaterial, image: Image, uv: Vector2) -> float:
	var mask_scale: float = material.get_shader_parameter(&"mask_scale")
	var puddle_amount: float = material.get_shader_parameter(&"puddle_amount")
	var patchy := _texture(image, uv * 0.37)
	var mask := _texture(image, uv * mask_scale) + (patchy - 0.5) * 0.09
	var level := 1.0 - puddle_amount
	return smoothstep(level, level + 0.035, mask)


## The red of an image at `uv`, as a shader reads a texture that repeats:
## from the four texels around.
func _texture(image: Image, uv: Vector2) -> float:
	var at := uv * Vector2(image.get_size()) - Vector2(0.5, 0.5)
	var corner := Vector2i(at.floor())
	var part := at - Vector2(corner)
	var rows: Array[float] = []
	for row in 2:
		var y := posmod(corner.y + row, image.get_height())
		var left := image.get_pixel(posmod(corner.x, image.get_width()), y).r
		var right := image.get_pixel(posmod(corner.x + 1, image.get_width()), y).r
		rows.append(lerpf(left, right, part.x))
	return lerpf(rows[0], rows[1], part.y)


## A point of a floor, a metre and a half or more from its edge, where water
## stands all around or none does. Zero if there is none.
func _spot(ground: Dictionary, random: RandomNumberGenerator, wet: bool) -> Vector3:
	var rect: Rect2 = (ground.rect as Rect2).grow(-1.5)
	for attempt in 4000:
		var at := Vector2(random.randf_range(rect.position.x, rect.end.x), random.randf_range(rect.position.y, rect.end.y))
		var all := true
		for offset: Vector2 in [Vector2.ZERO, Vector2(0.3, 0.0), Vector2(-0.3, 0.0), Vector2(0.0, 0.3), Vector2(0.0, -0.3)]:
			var puddle := _puddle(ground.material, ground.image, at + offset)
			all = all and (puddle > 0.99 if wet else puddle < 0.01)
		if all:
			return Vector3(at.x, ground.height, at.y)
	return Vector3.ZERO


## The bursts in the level that are drawn with `mesh` and have not been freed.
func _bursts(game: Node, mesh: Mesh) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child in game.get_children():
		if child is MeshInstance3D and child.mesh == mesh and not child.is_queued_for_deletion():
			found.append(child)
	return found


## The name of the sound a shot makes that lands at `position` on `surface`.
func _sound_of(fx: Node, sfx: Node, position: Vector3, surface: String) -> StringName:
	var before := sfx.get_children()
	fx.thud(position, surface)
	for child in sfx.get_children():
		if child in before or not child is AudioStreamPlayer3D:
			continue
		for sound: StringName in sfx._streams:
			if String(sound).begins_with("impact_") and child.stream in sfx._streams[sound]:
				return sound
	return &""
