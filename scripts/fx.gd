extends Node
## Short-lived visual effects: muzzle flashes, tracers, what a shot does to the
## surface it hits, spent cases, the end of a robot, explosions and the fires
## they leave. Everything is parented to the current scene so a scene reload
## cleans it up.
##
## Sparks, chips and smoke come in bursts. A burst is one mesh instance whose
## shader works out where every particle is from the time since the burst
## began (see shaders/fx_common.gdshaderinc), so it costs nothing per frame
## here. All of it runs on `time`, a clock of its own that stops with the game
## and that a screenshot can hold still.

const MAX_HOLES := 80
const MAX_CASINGS := 24
const CASING_TIME := 3.0
const TRACER_SPEED := 260.0
## Seconds a hole in steel keeps glowing, and how brightly it starts.
const COOLING_TIME := 0.9
const HOLE_HEAT := 5.0
## How far a burst can throw its particles; it is not drawn when a box this
## size around it is out of view.
const REACH := 3.0
const WORLD := 1
## The shaders keep time in single precision, which gets coarse after hours;
## past this many seconds the clock starts again as soon as nothing is playing.
const CLOCK_SPAN := 600.0

const HOLE_VARIANTS := {"concrete": 2, "metal": 2, "wood": 2, "soft": 1}
const SCORCH_VARIANTS := 2
const DECALS := "res://assets/decals/"

## Seconds the effects have been running. Bursts are timed against this.
var time := 0.0
## Stops the clock and keeps everything from expiring, so that a screenshot can
## show an effect at an exact age: fire it, then advance(). See benchmark.gd.
var held := false

var _sparks: ArrayMesh
var _chips: ArrayMesh
var _puffs: ArrayMesh
## The same balls, not lit pixel by pixel, for what fills too much of the
## picture for that: the smoke of a fire, and the cloud of an explosion.
var _smoke: ArrayMesh
var _clouds: ArrayMesh
var _flames: ArrayMesh
var _shell := SphereMesh.new()
var _tracer: ArrayMesh
var _flame: ArrayMesh
## Surface -> one [albedo, normal, orm, emission] per variant of its hole.
var _hole_textures := {}
var _scorch_textures: Array[Texture2D] = []
var _holes: Array[Decal] = []
## What is freed once `time` passes a moment: [node, moment].
var _expiring: Array[Array] = []
## Lights that die down: [light, start, seconds, energy].
var _lights: Array[Array] = []
## Holes in steel that are still glowing: [decal, start].
var _cooling: Array[Array] = []
## Fires that are burning: {light, at, start, seconds, energy, smoke, shade,
## seed}. `smoke` is when the next of it rises and `shade` the light on it.
var _fires: Array[Dictionary] = []
var _casing_mesh := CylinderMesh.new()
var _shell_mesh := CylinderMesh.new()
var _shell_head := CylinderMesh.new()
## Spent cases in flight: {node, velocity, spin, floor, age, bounces}.
var _casings: Array[Dictionary] = []


func _ready() -> void:
	_sparks = _burst_mesh(28, preload("res://shaders/sparks.gdshader"))
	_chips = _burst_mesh(18, preload("res://shaders/chips.gdshader"))
	_puffs = _burst_mesh(7, preload("res://shaders/puff.gdshader"))
	_smoke = _burst_mesh(8, preload("res://shaders/smoke.gdshader"))
	_clouds = _burst_mesh(20, preload("res://shaders/smoke.gdshader"))
	_flames = _burst_mesh(36, preload("res://shaders/flames.gdshader"))
	for mesh: ArrayMesh in [_puffs, _smoke, _clouds, _flames]:
		(mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter(&"noise", preload("res://assets/masks/wear.png"))
	var wave := ShaderMaterial.new()
	wave.shader = preload("res://shaders/shockwave.gdshader")
	_shell.radius = 1.0
	_shell.height = 2.0
	_shell.radial_segments = 32
	_shell.rings = 16
	_shell.material = wave
	_tracer = _burst_mesh(1, preload("res://shaders/tracer.gdshader"))
	_flame = _flame_mesh()

	for surface: String in HOLE_VARIANTS:
		var variants := []
		for i in HOLE_VARIANTS[surface]:
			var stem := "%shole_%s_%d" % [DECALS, surface, i + 1]
			var glow: Texture2D = load(stem + "_e.png") if surface == "metal" else null
			variants.append([load(stem + ".png"), load(stem + "_n.png"), load(stem + "_orm.png"), glow])
		_hole_textures[surface] = variants
	for i in SCORCH_VARIANTS:
		_scorch_textures.append(load("%sscorch_%d.png" % [DECALS, i + 1]))

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


## Moves the clock on by hand while it is held.
func advance(seconds: float) -> void:
	time += seconds
	_step(0.0)


## The flame at a muzzle and the light it throws. The flame is `size` metres
## long and points along the -Z of `at`, which is in the space of `parent`: the
## muzzle of a weapon it should stay on, or nothing for a place in the world.
## `prongs` is the number of tongues the muzzle device splits it into, 0 for a
## bare muzzle.
func muzzle_flash(parent: Node3D, at: Transform3D, size: float, prongs := 4, tint := Color(1.0, 0.62, 0.25), energy := 2.5) -> void:
	var seconds := randf_range(0.035, 0.05)
	var flame := MeshInstance3D.new()
	flame.mesh = _flame
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# A muzzle brake blows to the sides and stays level; any other flash is
	# turned about the barrel at random.
	var roll := 0.0 if prongs == 2 else randf() * TAU
	flame.transform = at * Transform3D(Basis(Vector3.FORWARD, roll).scaled(Vector3.ONE * size * randf_range(0.8, 1.2)), Vector3.ZERO)
	flame.set_instance_shader_parameter(&"start", time)
	flame.set_instance_shader_parameter(&"seed", randf() * 100.0)
	flame.set_instance_shader_parameter(&"life", seconds)
	flame.set_instance_shader_parameter(&"tint", tint)
	flame.set_instance_shader_parameter(&"prongs", float(prongs))
	if parent:
		parent.add_child(flame)
		_expire(flame, seconds)
	else:
		_spawn(flame, seconds)
	var from := parent.global_transform * at.origin if parent else at.origin
	flash(from, tint.lerp(Color.WHITE, 0.3), energy * size / 0.3, 7.0, seconds + 0.02)


## Brief burst of light that dies down over `seconds`.
func flash(position: Vector3, color := Color(1.0, 0.75, 0.4), energy := 2.0, reach := 5.0, seconds := 0.06) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.light_bake_mode = Light3D.BAKE_DISABLED
	light.position = position
	_spawn(light, seconds)
	_lights.append([light, time, seconds, energy])


## The streak of a bullet on its way from `from` to `to`.
func tracer(from: Vector3, to: Vector3, tint := Color(1.0, 0.7, 0.35)) -> void:
	var length := from.distance_to(to)
	if length < 2.0:
		return
	var streak := MeshInstance3D.new()
	streak.mesh = _tracer
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	streak.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	streak.position = from
	streak.custom_aabb = AABB(Vector3.ZERO, to - from).abs().grow(0.5)
	streak.set_instance_shader_parameter(&"start", time)
	streak.set_instance_shader_parameter(&"from", from)
	streak.set_instance_shader_parameter(&"to", to)
	streak.set_instance_shader_parameter(&"tint", tint)
	streak.set_instance_shader_parameter(&"speed", TRACER_SPEED)
	_spawn(streak, length / TRACER_SPEED + 0.05)


## What a ray hit is made of: "concrete", "brick", "metal", "wood" or "soft".
## The level builder marks every collider that is not concrete.
func surface_of(hit: Dictionary) -> String:
	var body := hit.collider as CollisionObject3D
	if body == null or body.get_shape_owners().is_empty():
		return "concrete"
	var shape := body.shape_owner_get_owner(body.shape_find_owner(hit.shape))
	return shape.get_meta(&"surface", "concrete") if shape else "concrete"


## A shot that came in along `incoming` lands on the level: `hit` is what the
## ray found. One pellet of several makes a `light` impact, so that a load of
## shot does not throw nine times the dust of a bullet.
func impact(hit: Dictionary, incoming: Vector3, light := false) -> void:
	strike(hit.position, hit.normal, incoming, surface_of(hit), light)
	Sfx.play_at(&"impact", hit.position, -8.0)


## The same without a ray to go by.
func strike(position: Vector3, normal: Vector3, incoming: Vector3, surface := "concrete", light := false) -> void:
	var frame := Transform3D(_up_along(normal), position)
	var floor_y := floor_below(position + normal * 0.05)
	var share := 0.45 if light else 1.0
	match surface:
		"metal":
			# Steel throws sparks, mostly the way the shot glances off.
			var off := Transform3D(_up_along((incoming.bounce(normal) + normal).normalized()), position)
			_burst(_sparks, off, 1.0, {&"floor_y": floor_y, &"amount": share * randf_range(0.5, 1.0), &"speed": randf_range(6.0, 10.0)})
			_burst(_puffs, frame, 0.7, {&"tint": Color(0.45, 0.44, 0.43, 0.3), &"speed": 1.2, &"size": Vector2(0.03, 0.16), &"life": 0.6, &"amount": 0.45})
			flash(position + normal * 0.08, Color(1.0, 0.6, 0.3), 1.2 * share, 3.0, 0.07)
			_cooling.append([_hole("metal", frame, randf_range(0.06, 0.075)), time])
		"wood":
			_burst(_chips, frame, 3.0, {&"floor_y": floor_y, &"tint": Color(0.7, 0.55, 0.36), &"slender": 4.5, &"size": 0.04, &"speed": 3.5, &"amount": share})
			_burst(_puffs, frame, 0.8, {&"tint": Color(0.68, 0.58, 0.45, 0.35), &"speed": 1.4, &"size": Vector2(0.03, 0.2), &"life": 0.7, &"amount": 0.6 * share})
			_hole("wood", frame, randf_range(0.085, 0.11))
		"soft":
			_burst(_puffs, frame, 1.3, {&"tint": Color(0.7, 0.69, 0.66, 0.45), &"speed": 1.6, &"size": Vector2(0.04, 0.26), &"life": 1.1, &"rise": -0.05, &"amount": 0.7 * share})
			_hole("soft", frame, 0.035)
		_:
			# Concrete and brick: a puff of dust, chips, and now and then a
			# spark off the jacket of the bullet.
			var brick := surface == "brick"
			var dust := Color(0.66, 0.44, 0.36, 0.5) if brick else Color(0.72, 0.7, 0.66, 0.5)
			_burst(_puffs, frame, 1.6, {&"tint": dust, &"speed": randf_range(1.8, 2.8), &"size": Vector2(0.05, 0.32), &"life": 1.4, &"rise": -0.04, &"amount": share})
			_burst(_chips, frame, 3.0, {&"floor_y": floor_y, &"tint": Color(0.55, 0.27, 0.2) if brick else Color(0.62, 0.6, 0.57), &"amount": share})
			if randf() < 0.3:
				_burst(_sparks, frame, 0.5, {&"floor_y": floor_y, &"amount": 0.15, &"speed": 5.0, &"life": 0.35})
			var hole := _hole("concrete", frame, randf_range(0.11, 0.15))
			if brick:
				hole.modulate = Color(1.0, 0.72, 0.62)


## A shot lands on a robot: sparks, the way the shot glances off.
func robot_hit(position: Vector3, incoming: Vector3, tint := Color(1.0, 0.5, 0.15)) -> void:
	var out := (Vector3.UP * 0.5 - incoming).normalized()
	_burst(_sparks, Transform3D(_up_along(out), position), 0.8, {&"floor_y": floor_below(position), &"tint": tint, &"amount": randf_range(0.3, 0.6), &"speed": 6.0, &"life": 0.45, &"spread": 0.9})
	flash(position - incoming * 0.1, tint.lerp(Color.WHITE, 0.3), 1.0, 3.0, 0.07)


## A robot blows up around `position`: a flash, a ball of fire, a shower of
## sparks, smoke that hangs about and soot on the floor below.
func wreck(position: Vector3, tint := Color(1.0, 0.5, 0.15)) -> void:
	var up := Transform3D(Basis(), position)
	var floor_y := floor_below(position)
	flash(position, Color(1.0, 0.7, 0.45), 7.0, 9.0, 0.3)
	_burst(_sparks, up, 1.6, {&"floor_y": floor_y, &"tint": tint, &"speed": 9.0, &"spread": 1.0, &"life": 1.3})
	_burst(_sparks, up.rotated_local(Vector3.UP, 2.0), 1.6, {&"floor_y": floor_y, &"tint": tint, &"speed": 5.0, &"spread": 0.8, &"life": 0.9})
	_burst(_chips, up, 3.0, {&"floor_y": floor_y, &"tint": Color(0.09, 0.09, 0.1), &"speed": 6.5, &"size": 0.045, &"spread": 1.0})
	# The fire is out in a third of a second; the smoke it leaves is not.
	_burst(_puffs, up, 0.5, {&"tint": Color(1.0, 0.5, 0.16, 0.85), &"glow": 9.0, &"speed": 3.5, &"spread": 1.0, &"size": Vector2(0.15, 0.6), &"life": 0.32, &"rise": 0.8})
	_burst(_puffs, up, 4.0, {&"tint": Color(0.07, 0.07, 0.075, 0.8), &"speed": 2.4, &"spread": 0.9, &"size": Vector2(0.2, 0.95), &"life": 3.4, &"rise": 0.55})
	var smoulder := _burst(_puffs, Transform3D(Basis(), Vector3(position.x, maxf(floor_y, position.y - 0.9) + 0.25, position.z)), 6.0,
		{&"tint": Color(0.1, 0.1, 0.105, 0.5), &"speed": 0.5, &"spread": 0.5, &"size": Vector2(0.12, 0.6), &"life": 4.5, &"rise": 0.7})
	smoulder.set_instance_shader_parameter(&"start", time + 0.6)
	if floor_y > position.y - 2.5:
		var soot := Decal.new()
		soot.texture_albedo = _scorch_textures.pick_random()
		var across := randf_range(1.5, 2.1)
		soot.size = Vector3(across, 0.3, across)
		soot.transform = Transform3D(Basis(Vector3.UP, randf() * TAU), Vector3(position.x, floor_y, position.z))
		_keep(soot)


## Something blows up at `position`: a flash, a pressure wave, a ball of fire
## that burns out into smoke, a ring of dust along the floor, sparks, debris
## and soot where it stood. `size` 1 is a fuel barrel or a hand grenade.
func explosion(position: Vector3, size := 1.0) -> void:
	var up := Transform3D(Basis(), position)
	var floor_y := floor_below(position + Vector3.UP * 0.2)
	var reach := 7.0 * size
	var shade := light_at(position + Vector3.UP * 0.5)
	flash(position + Vector3.UP * 0.4, Color(1.0, 0.72, 0.45), 12.0 * size, 14.0 * size, 0.35)

	var shell := MeshInstance3D.new()
	shell.mesh = _shell
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	shell.position = position
	shell.custom_aabb = AABB(-Vector3.ONE * reach, Vector3.ONE * reach * 2.0)
	shell.set_instance_shader_parameter(&"start", time)
	shell.set_instance_shader_parameter(&"reach", reach)
	_spawn(shell, 0.4)

	# The fire is out within half a second; what it burnt hangs about as smoke.
	_burst(_clouds, up, 3.6, {&"tint": Color(0.085, 0.08, 0.075, 0.9), &"shade": shade, &"glow": 1.0, &"fire": 0.16, &"speed": 12.0 * size, &"spread": 1.0, &"size": Vector2(0.3, 1.5) * size, &"life": 3.4, &"rise": 0.9}, reach)
	_burst(_smoke, up, 0.5, {&"tint": Color(1.0, 0.6, 0.25, 1.0), &"glow": 1.6, &"fire": 1.0, &"speed": 5.0 * size, &"spread": 1.0, &"size": Vector2(0.3, 1.0) * size, &"life": 0.4, &"rise": 0.5}, reach)
	var column := _burst(_smoke, up, 6.0, {&"tint": Color(0.09, 0.088, 0.085, 0.7), &"shade": shade, &"speed": 2.5 * size, &"spread": 0.8, &"size": Vector2(0.4, 1.8) * size, &"life": 5.0, &"rise": 0.9}, reach)
	column.set_instance_shader_parameter(&"start", time + 0.25)
	for turn in 3:
		_burst(_sparks, up.rotated_local(Vector3.UP, turn * 2.1), 2.0, {&"floor_y": floor_y, &"speed": randf_range(11.0, 17.0) * size, &"spread": 1.0, &"life": randf_range(1.1, 1.8)}, reach * 2.0)
	for turn in 2:
		_burst(_chips, up.rotated_local(Vector3.UP, turn * 1.3), 3.0, {&"floor_y": floor_y, &"tint": Color(0.07, 0.07, 0.075), &"speed": randf_range(8.0, 11.0) * size, &"size": 0.06 * size, &"spread": 1.0}, reach * 2.0)

	if floor_y > position.y - 2.0 * size:
		var ground := Vector3(position.x, floor_y, position.z)
		# The blast sweeps the dust off the floor in a ring.
		_burst(_clouds, Transform3D(Basis(), ground + Vector3.UP * 0.15), 1.6, {&"tint": Color(0.33, 0.31, 0.28, 0.4), &"shade": shade, &"speed": 17.0 * size, &"spread": 2.0, &"size": Vector2(0.25, 1.0) * size, &"life": 1.4, &"rise": 0.2}, reach)
		var soot := Decal.new()
		soot.texture_albedo = _scorch_textures.pick_random()
		var across := randf_range(3.0, 3.6) * size
		soot.size = Vector3(across, 0.3, across)
		soot.transform = Transform3D(Basis(Vector3.UP, randf() * TAU), ground)
		_keep(soot)


## A fire that burns for `seconds` on a patch `across` metres wide around
## `position`: the flames, the light they throw and the smoke that rises off
## them. Freeing what it returns puts it out.
func fire(position: Vector3, across: float, seconds: float) -> Node3D:
	var scale := clampf(across, 0.5, 1.6)
	var flames := _burst(_flames, Transform3D(Basis(), position), seconds, {&"life": seconds, &"radius": across * 0.5, &"size": Vector2(0.24, 1.3) * scale})
	_burn(flames, Vector3.UP * 0.5 * scale, 1.6 * scale, 3.5 + across * 2.0, seconds, time + 0.3)
	return flames


## The flame that roars out of a hole in something under pressure: `length`
## metres long, leaving `position` along `direction`, for `seconds`. Freeing
## what it returns puts it out.
func jet(position: Vector3, direction: Vector3, length: float, seconds: float) -> Node3D:
	var flames := _burst(_flames, Transform3D(_up_along(direction), position), seconds, {&"life": seconds, &"radius": 0.015, &"size": Vector2(0.13, length), &"rush": 5.0, &"amount": 0.45})
	_burn(flames, Vector3.UP * length * 0.4, 1.0, 3.5, seconds, INF)
	return flames


## The light of a fire, which flickers for as long as it burns: it hangs at
## `offset` from the flames and goes when they do. Smoke starts to rise at
## the moment `smoke`.
func _burn(flames: Node3D, offset: Vector3, energy: float, reach: float, seconds: float, smoke: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.22)
	light.light_energy = 0.0
	light.omni_range = reach
	# It falls off as the light of a real flame does, so it stays near the fire.
	light.omni_attenuation = 2.0
	light.light_bake_mode = Light3D.BAKE_DISABLED
	light.position = offset
	flames.add_child(light)
	var at := flames.global_transform * offset
	_fires.append({"light": light, "at": at, "start": time, "seconds": seconds, "energy": energy, "smoke": smoke, "shade": light_at(at), "seed": randf() * 100.0})


## The wisp of smoke a barrel leaves once it falls silent, drifting on along
## `direction`; `amount` is 1 after a long burst.
func gun_smoke(position: Vector3, direction: Vector3, amount := 1.0) -> void:
	_burst(_puffs, Transform3D(_up_along(direction), position), 1.2,
		{&"tint": Color(0.62, 0.62, 0.64, 0.42), &"speed": 0.9, &"spread": 0.3, &"size": Vector2(0.015, 0.17), &"life": 1.0, &"rise": 0.3, &"amount": lerpf(0.45, 1.0, amount)})


## Looking along `direction`, whichever way that is.
func facing(direction: Vector3) -> Basis:
	var up := Vector3.RIGHT if absf(direction.normalized().y) > 0.99 else Vector3.UP
	return Basis.looking_at(direction, up)


## Frees every effect at once, marks included.
func clear() -> void:
	for entry: Array in _expiring:
		if is_instance_valid(entry[0]):
			entry[0].queue_free()
	for decal in _holes:
		if is_instance_valid(decal):
			decal.queue_free()
	_expiring.clear()
	_holes.clear()


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
	var floor_y := floor_below(position, 4.0)
	if floor_y < position.y - 4.0:
		floor_y = position.y - 4.0
	var spin := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(12.0, 30.0)
	_casings.append({"node": node, "velocity": velocity, "spin": spin, "floor": floor_y + (0.011 if shell else 0.005), "age": 0.0, "bounces": 0})
	if _casings.size() > MAX_CASINGS:
		var oldest: Dictionary = _casings.pop_front()
		if is_instance_valid(oldest.node):
			oldest.node.queue_free()


func _process(delta: float) -> void:
	if held:
		return
	time += delta
	if time > CLOCK_SPAN and _expiring.is_empty() and _lights.is_empty() and _cooling.is_empty() and _fires.is_empty():
		time = 0.0
	_step(delta)


func _step(delta: float) -> void:
	RenderingServer.global_shader_parameter_set(&"fx_time", time)
	# A scene reload takes its effects with it, so any of these may be gone.
	for i in range(_expiring.size() - 1, -1, -1):
		if not is_instance_valid(_expiring[i][0]):
			_expiring.remove_at(i)
		elif time > _expiring[i][1] and not held:
			_expiring[i][0].queue_free()
			_expiring.remove_at(i)
	for i in range(_lights.size() - 1, -1, -1):
		var left: float = 1.0 - (time - _lights[i][1]) / _lights[i][2]
		if not is_instance_valid(_lights[i][0]):
			_lights.remove_at(i)
		else:
			_lights[i][0].light_energy = _lights[i][3] * maxf(left, 0.0) ** 2
			if left <= 0.0:
				_lights.remove_at(i)
	for i in range(_cooling.size() - 1, -1, -1):
		var left: float = 1.0 - (time - _cooling[i][1]) / COOLING_TIME
		if not is_instance_valid(_cooling[i][0]):
			_cooling.remove_at(i)
		else:
			_cooling[i][0].emission_energy = HOLE_HEAT * maxf(left, 0.0) ** 2
			if left <= 0.0:
				_cooling.remove_at(i)

	for i in range(_fires.size() - 1, -1, -1):
		var burning := _fires[i]
		var age: float = time - burning.start
		if not is_instance_valid(burning.light) or age > burning.seconds:
			_fires.remove_at(i)
			continue
		# In step with the flames: up at once, down over the last second or so.
		var dying := minf(1.5, burning.seconds * 0.4)
		var strength := smoothstep(0.0, 0.2, age) * (1.0 - smoothstep(burning.seconds - dying, burning.seconds, age))
		var flicker := 0.8 + 0.12 * sin(time * 23.0 + burning.seed) + 0.08 * sin(time * 57.0 + burning.seed * 2.0)
		burning.light.light_energy = burning.energy * strength * flicker
		while time >= burning.smoke and burning.smoke < burning.start + burning.seconds - dying:
			var smoke := _burst(_smoke, Transform3D(Basis(), burning.at + Vector3.UP * 0.4), 3.0,
				{&"tint": Color(0.07, 0.07, 0.075, 0.5), &"shade": burning.shade, &"speed": 0.7, &"spread": 0.5, &"size": Vector2(0.15, 0.75), &"life": 2.6, &"rise": 1.2, &"amount": 0.45})
			smoke.set_instance_shader_parameter(&"start", burning.smoke)
			burning.smoke += 0.3

	for i in range(_casings.size() - 1, -1, -1):
		var item := _casings[i]
		if not is_instance_valid(item.node):
			_casings.remove_at(i)
			continue
		var node: MeshInstance3D = item.node
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


## Sets off a burst at `at`, flying out along its +Y, and frees it `seconds`
## later. `parameters` are the instance uniforms of its shader, and `reach` is
## how far it throws its particles.
func _burst(mesh: Mesh, at: Transform3D, seconds: float, parameters: Dictionary, reach := REACH) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Lit by the lightmap probes around where it goes off, unless it glows.
	# The box is what the probes are read at the middle of: a little way out
	# from the surface.
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED if mesh == _sparks else GeometryInstance3D.GI_MODE_DYNAMIC
	node.custom_aabb = AABB(Vector3(-reach, 0.3 - reach, -reach), Vector3.ONE * reach * 2.0)
	node.transform = at
	node.set_instance_shader_parameter(&"start", time)
	for parameter: StringName in parameters:
		node.set_instance_shader_parameter(parameter, parameters[parameter])
	_spawn(node, seconds)
	return node


## A bullet hole `across` metres wide on the surface `frame` stands on. The
## oldest hole makes way once there are MAX_HOLES.
func _hole(surface: String, frame: Transform3D, across: float) -> Decal:
	var textures: Array = (_hole_textures[surface] as Array).pick_random()
	var decal := Decal.new()
	decal.texture_albedo = textures[0]
	decal.texture_normal = textures[1]
	decal.texture_orm = textures[2]
	if textures[3]:
		decal.texture_emission = textures[3]
		decal.emission_energy = HOLE_HEAT
	# Deep enough to find the model inside a collider that fits it loosely.
	decal.size = Vector3(across, 0.16, across)
	decal.transform = frame.rotated_local(Vector3.UP, randf() * TAU)
	_keep(decal)
	_holes.append(decal)
	_holes = _holes.filter(is_instance_valid)
	while _holes.size() > MAX_HOLES:
		_holes.pop_front().queue_free()
	return decal


## Adds a mark that stays for as long as the level does.
func _keep(decal: Decal) -> void:
	decal.upper_fade = 0.05
	decal.lower_fade = 0.05
	decal.normal_fade = 0.4
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = 30.0
	decal.distance_fade_length = 10.0
	get_tree().current_scene.add_child(decal)


func _spawn(node: Node3D, seconds: float) -> void:
	get_tree().current_scene.add_child(node)
	_expire(node, seconds)


func _expire(node: Node3D, seconds: float) -> void:
	_expiring.append([node, time + seconds])


## How much light falls on a point, for smoke that is not lit by the renderer:
## 1 in the shade, more where the sun reaches it.
func light_at(position: Vector3) -> float:
	var sun: DirectionalLight3D = null
	for light in get_tree().current_scene.find_children("*", "DirectionalLight3D", false, false):
		sun = light
	if sun == null or not sun.visible:
		return 1.0
	var query := PhysicsRayQueryParameters3D.create(position, position + sun.global_basis.z * 80.0, WORLD)
	var shaded := not get_viewport().find_world_3d().direct_space_state.intersect_ray(query).is_empty()
	return 1.0 if shaded else 1.0 + sun.light_energy * 0.3


## Height of the floor below a point, or far below when there is none within `reach`.
func floor_below(from: Vector3, reach := 8.0) -> float:
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * reach, WORLD)
	var hit := get_viewport().find_world_3d().direct_space_state.intersect_ray(query)
	return hit.position.y if hit else -1000.0


## Basis whose Y axis points along `direction`.
func _up_along(direction: Vector3) -> Basis:
	var y := direction.normalized()
	var x := (Vector3.FORWARD if absf(y.y) > 0.99 else Vector3.UP).cross(y).normalized()
	return Basis(x, y, x.cross(y))


## A mesh of `count` quads for a burst shader. A quad carries nothing but the
## random numbers of its particle: three in the vertex, a direction in the
## normal and two in UV2, the first of which says how many-eth it is, so that
## a burst can use a fraction of them. UV is the corner.
func _burst_mesh(count: int, shader: Shader) -> ArrayMesh:
	var random := RandomNumberGenerator.new()
	random.seed = count
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var extras := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in count:
		var numbers := Vector3(random.randf_range(-1, 1), random.randf_range(-1, 1), random.randf_range(-1, 1))
		var direction := Vector3(random.randfn(), random.randfn(), random.randfn()).normalized()
		var extra := Vector2((i + 0.5) / count, random.randf())
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			vertices.append(numbers)
			normals.append(direction)
			uvs.append(corner)
			extras.append(extra)
		for corner: int in [0, 1, 2, 0, 2, 3]:
			indices.append(i * 4 + corner)
	return _mesh(vertices, normals, uvs, extras, indices, shader)


## The cards a muzzle flash is drawn on, one unit long along -Z: three down
## the length of the flame and one across it just ahead of the muzzle. UV2.x
## tells the shader which is which.
func _flame_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var extras := PackedVector2Array()
	var indices := PackedInt32Array()
	var corners: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for card in 4:
		var turn := Basis(Vector3.FORWARD, card * PI / 3.0)
		for corner in corners:
			if card < 3:
				vertices.append(turn * Vector3((corner.x - 0.5) * 0.5, 0.0, -corner.y))
			else:
				vertices.append(Vector3(corner.x - 0.5, corner.y - 0.5, -0.06) * 0.95)
			normals.append(Vector3.BACK)
			uvs.append(corner)
			extras.append(Vector2(float(card == 3), card / 3.0))
		for corner: int in [0, 1, 2, 0, 2, 3]:
			indices.append(card * 4 + corner)
	return _mesh(vertices, normals, uvs, extras, indices, preload("res://shaders/muzzle_flash.gdshader"))


func _mesh(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, extras: PackedVector2Array, indices: PackedInt32Array, shader: Shader) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = extras
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = shader
	mesh.surface_set_material(0, material)
	return mesh
