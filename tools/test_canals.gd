extends SceneTree
## Tries whether the canals and the test quay can be got through as built:
## along the middle of every canal a body of the player's size wades, upright
## and stooped, under every bridge; every set of steps out of the water has
## room on its landing and on the quay above; and along every quay, street
## and bridge the player can walk, a step's height over whatever floor is
## there, without anything across the way. Headless, on the levels as
## tools/build_level.sh last wrote them:
##
##   tools/test_canals.sh
##
## Whoever dresses a bridge, a quay or the steps runs this after building.
## A canal that is only stooped through says so without failing: the quays
## carried over the mouths of the Spiegelgracht are that low.

const PLAN := preload("res://tools/levels/canals/plan.gd")
const KIT := preload("res://tools/kit/water.gd")
const LIJNBAAN := preload("res://tools/levels/canals/lijnbaan.gd")
const VIJZEL := preload("res://tools/levels/canals/vijzel.gd")
const QUAY := preload("res://tools/levels/quay.gd")
## The player as the game has him: see scenes/player.tscn and scripts/player.gd.
const RADIUS := 0.35
const STANDING := 1.8
const STOOPED := 1.1
## How high a floor may rise from one step to the next for the walk.
const STEP := 0.3
const WATCHDOG := 120.0

var _failed := 0
var _checked := 0


func _initialize() -> void:
	var timer := Timer.new()
	timer.wait_time = WATCHDOG
	timer.autostart = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.timeout.connect(func() -> void:
		print("test_canals: timed out")
		quit(2))
	root.add_child(timer)
	_run.call_deferred()


func _run() -> void:
	var middle := func(lines: Array) -> float: return (lines[1] + lines[2]) * 0.5
	var bed := -KIT.CANAL_BED
	var west: float = PLAN.WEST_END + 1.0
	var east: float = PLAN.EAST_END - 1.0
	var spiegel_west: float = (PLAN.SPIEGELGRACHT[0] + PLAN.SPIEGELGRACHT[1]) * 0.5
	var spiegel_east: float = (PLAN.SPIEGELGRACHT[2] + PLAN.SPIEGELGRACHT[3]) * 0.5
	# Along a canal: on its north quay, five metres from the fronts, and on
	# its south quay, four to five from them.
	var quays := func(lines: Array) -> Array: return [[Vector2(west + 2.0, lines[0] + 5.0), Vector2(east - 2.0, lines[0] + 5.0)], [Vector2(west + 2.0, lines[3] - 4.5), Vector2(east - 2.0, lines[3] - 4.5)]]
	var over := func(x: float, lines: Array) -> Array: return [Vector2(x, lines[3] - 4.5), Vector2(x, lines[0] + 5.0)]
	var bridges := []
	for crossing: Array in PLAN.HEREN_CROSSINGS:
		bridges.append(over.call(crossing[0], PLAN.HEREN))
	for crossing: Array in PLAN.KEIZERS_CROSSINGS:
		bridges.append(over.call(crossing[0], PLAN.KEIZERS))
	for crossing: Array in PLAN.PRINSEN_CROSSINGS:
		bridges.append(over.call(crossing[0], PLAN.PRINSEN))
	bridges.append([Vector2(LIJNBAAN.START_X, PLAN.LIJNBAAN[3] - 9.0), Vector2(LIJNBAAN.START_X, PLAN.LIJNBAAN[0] - 4.0)])
	bridges.append([Vector2(PLAN.VIJZEL_X, PLAN.LIJNBAAN[3] - 9.0), Vector2(PLAN.VIJZEL_X, PLAN.LIJNBAAN[0] - 22.0)])
	await _level("res://scenes/levels/canals_level.tscn", "Canals", bed, [
		["the Herengracht", Vector2(west, middle.call(PLAN.HEREN)), Vector2(east, middle.call(PLAN.HEREN))],
		["the Keizersgracht", Vector2(west, middle.call(PLAN.KEIZERS)), Vector2(east, middle.call(PLAN.KEIZERS))],
		["the Prinsengracht", Vector2(west, middle.call(PLAN.PRINSEN)), Vector2(east, middle.call(PLAN.PRINSEN))],
		["the Lijnbaansgracht", Vector2(west, middle.call(PLAN.LIJNBAAN)), Vector2(east, middle.call(PLAN.LIJNBAAN))],
		["the Spiegelgracht", Vector2(PLAN.SPIEGEL_X, middle.call(PLAN.PRINSEN)), Vector2(PLAN.SPIEGEL_X, middle.call(PLAN.LIJNBAAN))],
	], [
		["the round", [Vector2(LIJNBAAN.START_X, PLAN.SOUTH_END - 9.0), Vector2(LIJNBAAN.START_X, PLAN.PRINSEN[3] - 3.0), Vector2(PLAN.SPIEGEL_X, PLAN.PRINSEN[3] - 3.0),
			Vector2(PLAN.SPIEGEL_X, PLAN.HEREN[3] - 4.5), Vector2(PLAN.VIJZEL_X, PLAN.HEREN[3] - 4.5), Vector2(PLAN.VIJZEL_X, VIJZEL.METRO.z - 4.0)]],
		["the quays of the Herengracht"] + quays.call(PLAN.HEREN),
		["the quays of the Keizersgracht"] + quays.call(PLAN.KEIZERS),
		["the quays of the Prinsengracht"] + quays.call(PLAN.PRINSEN),
		["the Kerkstraat", [Vector2(PLAN.SPIEGEL_X - 4.0, middle.call([0.0, PLAN.KERK[0], PLAN.KERK[1], 0.0])), Vector2(PLAN.VIJZEL_X + 10.0, middle.call([0.0, PLAN.KERK[0], PLAN.KERK[1], 0.0]))]],
		["the Weteringdwarsstraat", [Vector2(PLAN.SPIEGELGRACHT[3] - 2.0, middle.call([0.0, PLAN.DWARS[0], PLAN.DWARS[1], 0.0])), Vector2(PLAN.VIJZELGRACHT[0] + 3.0, middle.call([0.0, PLAN.DWARS[0], PLAN.DWARS[1], 0.0]))]],
		["the quays of the Spiegelgracht", [Vector2(spiegel_west, PLAN.PRINSEN[3] - 3.0), Vector2(spiegel_west, PLAN.LIJNBAAN[0] + 3.0)], [Vector2(spiegel_east, PLAN.PRINSEN[3] - 3.0), Vector2(spiegel_east, PLAN.LIJNBAAN[0] + 3.0)]],
		["the quays of the Lijnbaansgracht", [Vector2(west + 2.0, PLAN.LIJNBAAN[0] + 4.0), Vector2(east - 2.0, PLAN.LIJNBAAN[0] + 4.0)], [Vector2(west + 2.0, PLAN.LIJNBAAN[3] - 12.0), Vector2(east - 2.0, PLAN.LIJNBAAN[3] - 12.0)]],
		["every bridge"] + bridges,
	])
	var quay_middle := (QUAY.LINES[1] + QUAY.LINES[2]) * 0.5
	await _level("res://scenes/levels/quay_level.tscn", "Quay", bed, [
		["its canal", Vector2(1.0, quay_middle), Vector2(QUAY.LONG - 1.0, quay_middle)],
	], [
		["its quays and its bridge", [Vector2(1.5, QUAY.LINES[0] + 5.0), Vector2(QUAY.LONG - 1.5, QUAY.LINES[0] + 5.0)], [Vector2(1.5, QUAY.LINES[3] - 4.5), Vector2(QUAY.LONG - 1.5, QUAY.LINES[3] - 4.5)],
			[Vector2(QUAY.BRIDGE_X, QUAY.LINES[3] - 4.5), Vector2(QUAY.BRIDGE_X, QUAY.LINES[0] + 5.0)]],
	])
	print("test_canals: %d of %d checks passed" % [_checked - _failed, _checked])
	quit(1 if _failed > 0 else 0)


## Stands one level in the world and tries `canals`, each a name and a line
## through the water, and `walks`, each a name and one or more lines on the
## street.
func _level(path: String, title: String, bed: float, canals: Array, walks: Array) -> void:
	if not ResourceLoader.exists(path):
		_check("%s: is built (tools/build_level.sh)" % title, false)
		return
	var level: Node3D = (load(path) as PackedScene).instantiate()
	root.add_child(level)
	for i in 3:
		await physics_frame
	var space := root.get_world_3d().direct_space_state
	for canal: Array in canals:
		var upright := _blocked(space, canal[1], canal[2], func(at: Vector2) -> Vector3: return Vector3(at.x, bed + STANDING * 0.5 + 0.05, at.y), STANDING)
		var stooped := _blocked(space, canal[1], canal[2], func(at: Vector2) -> Vector3: return Vector3(at.x, bed + STOOPED * 0.5 + 0.05, at.y), STOOPED)
		_check("%s: whoever falls into %s can wade its length, under every bridge" % [title, canal[0]], stooped.is_empty(), stooped)
		if not upright.is_empty():
			print("    %s: stooped only at %s" % [canal[0], ", ".join(upright.slice(0, 6))])
	_steps(space, level, title)
	for walk: Array in walks:
		var blocked := []
		for k in range(1, walk.size()):
			var points: Array = walk[k]
			for i in points.size() - 1:
				blocked.append_array(_blocked(space, points[i], points[i + 1], func(at: Vector2) -> Vector3:
					var down := PhysicsRayQueryParameters3D.create(Vector3(at.x, 6.0, at.y), Vector3(at.x, -1.0, at.y), 1)
					var floor_hit := space.intersect_ray(down)
					return Vector3(at.x, (floor_hit.position.y if floor_hit else -9.0) + STEP + STANDING * 0.5, at.y), STANDING))
		_check("%s: %s can be walked" % [title, walk[0]], blocked.is_empty(), blocked)
	level.queue_free()
	await process_frame


## Every set of steps out of the water: room to stand on its landing, and on
## the quay above it.
func _steps(space: PhysicsDirectSpaceState3D, level: Node3D, title: String) -> void:
	var landings := 0
	var shut := []
	for body: StaticBody3D in level.find_children("*", "StaticBody3D", true, false):
		for shape: CollisionShape3D in body.find_children("*", "CollisionShape3D", false, false):
			var box := shape.shape as BoxShape3D
			if box == null or not is_equal_approx(box.size.x, 2.2) or not is_equal_approx(box.size.y, 0.3):
				continue
			var xf: Transform3D = body.global_transform * shape.transform
			var top := xf * Vector3(0, 0.15, 0)
			if absf(top.y + KIT.LANDING_BELOW) > 0.02:
				continue
			landings += 1
			# The landing lies against the wall, its middle 0.7 m out from it.
			var to_quay := -(xf.basis * Vector3.BACK).normalized()
			if _hits(space, top + Vector3.UP * (STANDING * 0.5 + 0.05), STANDING) or _hits(space, top + to_quay * 1.3 + Vector3.UP * (KIT.LANDING_BELOW + STANDING * 0.5 + 0.05), STANDING):
				shut.append("%s" % top.snappedf(0.1))
	_check("%s: there are steps out of the water, and nothing stands on them or where they come up" % title, landings > 0 and shut.is_empty(), shut)
	print("    %d sets of steps" % landings)


## Where along the line from `a` to `b`, every half metre, a body of that
## height stands in something, at the spot `place` gives for each point.
func _blocked(space: PhysicsDirectSpaceState3D, a: Vector2, b: Vector2, place: Callable, height: float) -> Array:
	var found := []
	var length := a.distance_to(b)
	var d := 0.0
	while d <= length:
		var at := a.lerp(b, d / length) if length > 0.0 else a
		var spot: Vector3 = place.call(at)
		if spot.y < -5.0 or _hits(space, spot, height):
			found.append("(%.1f, %.1f)" % [at.x, at.y])
		d += 0.5
	return found


func _hits(space: PhysicsDirectSpaceState3D, at: Vector3, height: float) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis(), at)
	query.collision_mask = 1
	return not space.intersect_shape(query, 1).is_empty()


func _check(what: String, ok: bool, where := []) -> void:
	_checked += 1
	if ok:
		print("  [ok] %s" % what)
	else:
		_failed += 1
		print("  [FAIL] %s%s" % [what, (": " + ", ".join(where.slice(0, 6))) if not where.is_empty() else ""])
