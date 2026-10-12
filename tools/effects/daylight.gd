extends RefCounted
## The daylight at the exit, see scripts/daylight.gd: every door that goes up
## to let the player out has one, it is dark while the door is shut, what it
## lets in is what lies beyond the door, and it follows how far up the door
## is, whoever put it there.

const DAYLIGHT := preload("res://scripts/daylight.gd")
## What lies beyond the door of every level: the evening sun shines into
## that of the factory, those of the works and the powerhouse face away from
## it, and that of the depot leads from the dock into the warehouse, where a
## tube hangs.
const LEVELS := {
	"factory": DAYLIGHT.Source.SUN,
	"works": DAYLIGHT.Source.SKY,
	"powerhouse": DAYLIGHT.Source.SKY,
	"depot": DAYLIGHT.Source.LAMP,
}
const WORLD := 1


func run(test: SceneTree) -> void:
	for level: String in LEVELS:
		var game: Node = await test.level("res://scenes/%s.tscn" % level)
		await test.frames(DAYLIGHT.SETTLE + 2)
		await _look(test, game, level)

	# The same level twice in a row, and its door rolled up by the game as it
	# is when the last zone is cleared.
	await test.level()
	var game: Node = await test.level()
	await test.frames(DAYLIGHT.SETTLE + 2)
	var daylights: Array[Node] = test.get_nodes_in_group("daylight")
	test.check(daylights.size() == 1 and daylights[0].get_node_or_null("Beam") != null, "a level that is loaded twice in a row has its one daylight, with its lights")
	if daylights.size() != 1:
		return
	var daylight: Node3D = daylights[0]
	var beam: SpotLight3D = daylight.get_node_or_null("Beam")
	game._open_exit(true)
	await test.wait(game.DOOR_DELAY + game.DOOR_TIME * 0.5)
	var half: float = daylight.opening
	test.check(half > 0.2 and half < 0.8 and beam != null and beam.visible, "half way through rolling up the door is half open and the light is on (%.2f)" % half)
	await test.wait(game.DOOR_TIME * 0.5 + 0.5)
	test.check(is_equal_approx(daylight.opening, 1.0), "once the door has rolled up it is open all the way (%.2f)" % daylight.opening)


## Goes through what the daylights of one level are and do.
func _look(test: SceneTree, game: Node, level: String) -> void:
	var doors: Array[Node] = test.get_nodes_in_group("exit_door")
	var daylights: Array[Node] = test.get_nodes_in_group("daylight")
	var paired := doors.size() == daylights.size() and not doors.is_empty()
	for door in doors:
		paired = paired and daylights.filter(func(daylight: Node) -> bool: return daylight.door == door).size() == 1
	test.check(paired, "%s: every door at the exit has one daylight (%d for %d)" % [level, daylights.size(), doors.size()])
	var breakables: Node = game.get_node("Level/Breakables")
	test.check(daylights.all(func(daylight: Node) -> bool: return not breakables.is_ancestor_of(daylight) and game.get_node("Level").is_ancestor_of(daylight)), "%s: it is part of the level and not of what can break" % level)
	test.check(not game._breakables.any(func(body: Node) -> bool: return body.is_in_group("daylight")), "%s: nor is it in the list of what can break that the game keeps" % level)
	if not paired:
		return

	var daylight: Node3D = daylights[0]
	var door: Node3D = daylight.door
	var rise: float = door.get_meta(&"rise", 0.0)
	var front: Vector3 = door.get_meta(&"front", Vector3.ZERO)
	var beam: SpotLight3D = daylight.get_node_or_null("Beam")
	var bounce: OmniLight3D = daylight.get_node_or_null("Bounce")
	test.check(beam != null and bounce != null and daylight.source == LEVELS[level], "%s: it found what lies beyond the door (%s)" % [level, DAYLIGHT.Source.find_key(daylight.source)])
	if beam == null or bounce == null:
		return
	test.check(daylight.opening == 0.0 and not beam.visible and not bounce.visible, "%s: it is dark while the door is shut" % level)
	# With what else the zone of the door holds, in a level that has zones.
	var zone := door.get_parent()
	test.check(daylight.get_parent() == (zone.get_node("Contents") if zone.is_in_group("level_zone") else zone), "%s: it goes with the zone of its door, or with the door" % level)
	test.check(beam.shadow_enabled and beam.light_bake_mode == Light3D.BAKE_DISABLED and not bounce.shadow_enabled and bounce.light_bake_mode == Light3D.BAKE_DISABLED, "%s: its beam casts a shadow, its bounce does not, and neither is baked" % level)
	# scripts/zones.gd holds the lamps of a level to their zones and has left
	# these alone: they light what the zones hold, and in a level without
	# zones everything.
	var held: Variant = game.get_node("Level").get("_held")
	var layers: int = DAYLIGHT.ZONES.EVERY_LAYER & ~DAYLIGHT.ZONES.COMMON_MASK if zone.is_in_group("level_zone") else DAYLIGHT.ZONES.EVERY_LAYER
	test.check((held == null or not (held.has(beam) or held.has(bounce))) and beam.light_cull_mask == layers and bounce.light_cull_mask == layers, "%s: its lights are not held to a zone as the lamps of the level are" % level)
	test.check(bounce.global_position.distance_to(door.global_position) < 1.0, "%s: its bounce hangs in the doorway" % level)

	# What falls in, by what the level has beyond the door. The middle of the
	# door is the middle of the doorway while it is shut.
	var along := -beam.global_basis.z
	var middle := door.global_position
	var suns: Array[Node] = game.find_children("*", "DirectionalLight3D", true, false)
	var sun: DirectionalLight3D = suns[0] if not suns.is_empty() else null
	var travel := -sun.global_basis.z if sun else Vector3.DOWN
	var space := door.get_world_3d().direct_space_state
	var to_sun := PhysicsRayQueryParameters3D.create(middle, middle - travel * 150.0, WORLD)
	to_sun.exclude = [(door as CollisionObject3D).get_rid()]
	var sunlit := travel.dot(front) > 0.0 and space.intersect_ray(to_sun).is_empty()
	# The beam goes through the doorway from beyond it.
	var through := (beam.global_position - middle).dot(front) < 0.0 and along.dot(front) > 0.0
	var across := Vector3.UP.cross(front)
	match LEVELS[level]:
		DAYLIGHT.Source.SUN:
			test.check(sunlit, "%s: the sun shines into the doorway" % level)
			test.check(through and along.dot(travel) > 0.999, "%s: the light comes in along the sun (%.4f)" % [level, along.dot(travel)])
			test.check(beam.light_color.is_equal_approx(sun.light_color) and beam.spot_attenuation == 0.0, "%s: in the colour of the sun, and it does not fall off" % level)
		DAYLIGHT.Source.SKY:
			test.check(not sunlit and travel.dot(front) < 0.0, "%s: the door faces away from the sun" % level)
			test.check(through and absf(along.dot(across)) < 0.001 and along.y < -0.2, "%s: the light comes straight in, and down" % level)
			test.check(beam.light_color.b > beam.light_color.r and beam.light_color.b > sun.light_color.b and daylight._full < sun.light_energy, "%s: cooler than the sun, and weaker" % level)
		DAYLIGHT.Source.LAMP:
			test.check(not sunlit, "%s: neither sun nor moon gets to the doorway: there is a roof beyond it" % level)
			var lamps: Array[Node] = game.find_children("*", "Light3D", true, false).filter(func(lamp: Light3D) -> bool:
				return lamp != beam and lamp != bounce and lamp.global_position.distance_to(beam.global_position) < 0.01)
			test.check(lamps.size() == 1 and beam.light_color.is_equal_approx(lamps[0].light_color), "%s: the light is that of the lamp that hangs beyond the door, from where it hangs" % level)
			test.check(through and absf(along.dot(across)) < 0.05, "%s: it comes straight out of the doorway" % level)
			# Shot out, the lamp takes what came out of the doorway with it.
			if lamps.size() == 1:
				door.translate(Vector3.UP * rise)
				await test.frames(4)
				lamps[0].hide()
				var gone := not beam.visible and not bounce.visible
				lamps[0].show()
				test.check(gone and beam.visible, "%s: with that lamp out nothing comes through the doorway" % level)
				door.translate(Vector3.DOWN * rise)
				await test.frames(4)
	# Every corner of the doorway is in the cone.
	var inside := true
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at: Vector3 = middle + across * corner.x * daylight._size.x * 0.5 + Vector3.UP * corner.y * daylight._size.y * 0.5
		inside = inside and rad_to_deg(along.angle_to(at - beam.global_position)) < beam.spot_angle and beam.global_position.distance_to(at) < beam.spot_range
	test.check(inside, "%s: the whole doorway is in the beam" % level)

	# Half way up by hand: on in part.
	door.translate(Vector3.UP * rise * 0.5)
	await test.frames(4)
	var half: float = bounce.light_energy
	test.check(is_equal_approx(daylight.opening, 0.5) and beam.visible and bounce.visible and half > 0.0, "%s: with the door half way up it is on (%.2f)" % [level, daylight.opening])
	door.translate(Vector3.DOWN * rise * 0.5)
	await test.frames(4)
	test.check(daylight.opening == 0.0 and not beam.visible and not bounce.visible, "%s: and dark again with the door back down" % level)

	# Open as the game opens it for somebody who comes in later.
	game._open_exit(false)
	await test.frames(4)
	test.check(daylight.opening == 1.0 and beam.visible and bounce.visible, "%s: with the door up it is on" % level)
	test.check(is_equal_approx(bounce.light_energy, half * 2.0) and is_equal_approx(beam.light_energy, daylight._full) and daylight._full > 0.0, "%s: what it throws back grows with the opening (%.3f, then %.3f)" % [level, half, bounce.light_energy])
	# And it is drawn for somebody who stands at the door.
	var player: Node3D = test.get_first_node_in_group("player")
	player.global_position = door.global_position + front * 3.0 + Vector3.DOWN * daylight._size.y * 0.5
	await test.frames(8)
	test.check(beam.is_visible_in_tree() and bounce.is_visible_in_tree(), "%s: from the door its lights are drawn" % level)
	var parts: Array[Node] = [daylight]
	parts.append_array(daylight.get_children())
	parts.append_array(door.get_children().filter(func(node: Node) -> bool: return node is DAYLIGHT.Rider))
	test.check(parts.size() == 4 and not parts.any(func(node: Node) -> bool: return node.is_processing() or node.is_physics_processing()), "%s: nothing of it is run from frame to frame" % level)
