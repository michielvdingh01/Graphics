extends Node
## Short-lived visual effects: muzzle flashes, tracers, what a shot does to the
## surface it hits, spent cases, the end of a robot, of a crate, of a lamp and
## of a pane of glass, explosions with the smoke they light, the fires they
## leave, the flames on what has caught fire and the soot it leaves, and the
## splash of a shot into a puddle. Everything is parented to the current scene
## so a scene reload cleans it up.
##
## Two things here are more than a look. Every shot's streak comes through
## tracer(), so that is where the host breaks the glass the shot went
## through: see _through_glass(). And water_at() and in_puddle() answer from a
## copy of the mask the wet floor is drawn with, so a puddle is where it is
## seen.
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
## How far below a lamp its glass and its sparks look for a floor, in metres.
const LAMP_DROP := 14.0
## How many frames rehearse() draws for.
const REHEARSAL := 6
## The shaders keep time in single precision, which gets coarse after hours;
## past this many seconds the clock starts again as soon as nothing is playing.
const CLOCK_SPAN := 600.0

const HOLE_VARIANTS := {"concrete": 2, "metal": 2, "wood": 2, "soft": 1}
const SCORCH_VARIANTS := 2
const BLOOD_VARIANTS := 2
## Splashes and pools of blood that stay; the oldest makes way.
const MAX_STAINS := 24
## How many prints of boots lie in the sand before the oldest blows over.
const MAX_PRINTS := 60
## How long and wide the texture of a print lies on the ground, in metres:
## the boot in it is 30 cm long.
const PRINT_ACROSS := 0.36
## How much of its own colour a print gives the sand it is pressed in.
const PRINT_STAIN := 0.4
const DECALS := "res://assets/decals/"

## Seconds the effects have been running. Bursts are timed against this.
var time := 0.0
## Stops the clock and keeps everything from expiring, so that a screenshot can
## show an effect at an exact age: fire it, then advance(). See benchmark.gd.
var held := false

var _sparks: ArrayMesh
var _chips: ArrayMesh
var _shards: ArrayMesh
var _puffs: ArrayMesh
## The same balls, not lit pixel by pixel, for what fills too much of the
## picture for that: the smoke of a fire, and the cloud of an explosion.
var _smoke: ArrayMesh
var _clouds: ArrayMesh
var _flames: ArrayMesh
## Every mesh a burst is drawn with, which is what rehearse() goes through:
## whoever adds a kind of burst adds its mesh to this. The shader of each
## has an instance uniform `amount`, below which a particle is left out.
var _bursts: Array[Mesh] = []
var _shell := SphereMesh.new()
## What the cloud of a smoke grenade is drawn on: a ball, one in radius.
var _standing := SphereMesh.new()
var _tracer: ArrayMesh
var _flame: ArrayMesh
## Surface -> one [albedo, normal, orm, emission] per variant of its hole.
var _hole_textures := {}
var _scorch_textures: Array[Texture2D] = []
var _blood_textures: Array[Texture2D] = []
var _pool_texture: Texture2D
## What makes blood shine: no occlusion, hardly any roughness, no metal.
var _wet: ImageTexture
var _stains: Array[Decal] = []
var _holes: Array[Decal] = []
## The print of a boot in sand, and its dent.
var _print_textures: Array[Texture2D] = []
var _prints: Array[Decal] = []
## What is freed once `time` passes a moment: [node, moment].
var _expiring: Array[Array] = []
## Lights that die down: [light, start, seconds, energy].
var _lights: Array[Array] = []
## Holes in steel that are still glowing: [decal, start].
var _cooling: Array[Array] = []
## Fires that are burning: {flames, light, at, start, seconds, energy, smoke,
## spit, floor, puffs, seed}. `smoke` is when the next of it rises, `spit`
## when it next throws sparks, `floor` the height they land on and `puffs`
## the smoke that it still lights from below.
var _fires: Array[Dictionary] = []
var _casing_mesh := CylinderMesh.new()
var _shell_mesh := CylinderMesh.new()
var _shell_head := CylinderMesh.new()
## The empty clip of a weapon loaded by clips (WeaponData.en_bloc): sheet
## steel round the bases of eight rounds.
var _clip_mesh := BoxMesh.new()
## Spent cases in flight: {node, velocity, spin, floor, age, bounces}.
var _casings: Array[Dictionary] = []

# The glass of a window that breaks.

## The layer the glass of the windows is on, which no shot stops at and no
## look: scripts/breakables.gd puts it there and _through_glass() finds it
## there. And the most panes one shot breaks on its way.
const GLASS := 64
const MOST_PANES := 6
## How far a shot is followed on from where it went into a pane before the
## next pane is looked for, in metres: further than a pane is thick.
const PANE_STEP := 0.1
## How near the camera a streak starts that is the shot of whoever looks
## through it, in metres: no further than a weapon is long.
const OWN_SHOT := 1.0
## The pieces a pane of a square metre breaks into, the longest side of the
## largest of them in metres and the seconds they are there, which is the
## LINGER of shaders/glass.gdshader. A smaller pane leaves fewer and smaller
## pieces, and one of more than PANE_PART m² breaks as several.
const PANE_SHARDS := 64
const PANE_SHARD := 0.3
const PANE_TIME := 4.0
const PANE_PART := 2.0
## How far from a pane its glass is taken to land, in metres, and the speed
## in m/s at which it leaves: let go by a shot, and thrown by a blast at its
## hardest.
const PANE_THROW := 0.5
const PANE_SPEED := 2.2
const PANE_BLOWN := 11.0
## The most bursts of shards the blasts of one frame set off. A blast breaks
## the panes nearest to it first, and what it breaks beyond these is gone
## without shards.
const MAX_BLOWN := 16

## The shards of a pane of a window: those of a lamp, and more of them.
var _pane_shards: ArrayMesh
## The frame in which a blast last broke a pane, and how many bursts of
## shards the blasts of that frame have set off.
var _blown_frame := -1
var _blown := 0

# The light on the smoke of an explosion and of a fire.

## How far over an explosion its cloud of smoke hangs, in metres: where the
## light on it is looked for.
const SMOKE_HEIGHT := 1.2
## How much further than its fullest the cloud of a smoke grenade can reach.
const SMOKE_CLOUD_BOX := 1.8
## Its smoke is white where the rest is soot: how much of the light on smoke
## it gets under a roof with no sun on it, for it not to glow in a dim hall,
## how high a roof can be in metres, and how much it gets of what the night
## sky is taken to give.
const SMOKE_CLOUD_SHADE := 0.4
const SMOKE_ROOFED := 40.0
const SMOKE_CLOUD_NIGHT := 0.05
## How bright the light of the sky makes smoke, against a lamp of energy 1
## that shines straight on it: a roof keeps half of it out.
const SMOKE_SKY := 0.5
## The share of the key light that comes back off the floor and the walls
## around a cloud, as light from all around.
const SMOKE_BOUNCE := 0.12
## How much brighter than the light from all around the light from straight
## above is taken to be, where no sun and no lamp gets to a cloud.
const SMOKE_OVERHEAD := 4.0
## How many of the brightest lights around a cloud are tried for a clear line
## to it before it counts as standing in the dark.
const SMOKE_TRIES := 3
## A lamp counts as no nearer to a cloud than this, in metres: the cloud is a
## good deal larger than the point its light is looked for at.
const SMOKE_NEAR := 1.5
## How far short of a lamp the line to it stops, in metres, so that what the
## lamp hangs from is not in the way.
const SMOKE_CLEAR := 0.5
## How much of its colour a light loses on smoke, which scatters the blue of
## it best: the low sun turns soot tan, not orange.
const SMOKE_GREY := 0.35
## The share of the key light that gets to the column of smoke inside the
## cloud of an explosion.
const SMOKE_SHROUDED := 0.6
## How strongly a fire lights the smoke that rises off it.
const SMOKE_EMBER := 8.0

## How bright red, green and blue are to the eye.
const LUMINANCE := Vector3(0.2126, 0.7152, 0.0722)

## The lamps of the level that is being played, and which level that is.
var _lamps: Array[Light3D] = []
var _lamps_of := 0

# The fire on what burns, as against fuel on the floor: a crate, a
# cardboard box, a pile of pallets.

## How many balls of flame the largest of them has, a pile of pallets two
## metres high, and how many there are to a square metre of what burns. Half
## of them are on the far side of it at any time.
const BLAZE_FLAMES := 64
const BLAZE_DENSITY := 14.0
## The longest anything burns, in seconds. Whoever sets something alight puts
## it out as well; flames that were forgotten go by themselves after this.
const BLAZE_TIME := 60.0
## How far the flames of a burning thing are from the foot of it at most, in
## metres: for when to leave them out of the picture.
const BLAZE_REACH := 4.0
## How far a burn mark on the floor reaches beyond what burnt there, as a
## multiple of how wide that was. The mark is thin towards its rim.
const SOOT_SPREAD := 2.6
## Burn marks that soot() leaves on the floor; the oldest makes way. The
## stacks of one pile stand close together, and each leaves one of its own.
const MAX_SOOT := 12

var _blaze: ArrayMesh
## What lies on something that has burnt and still stands.
var _soot: ImageTexture
var _soot_marks: Array[Decal] = []

# A shot into a puddle, and where the puddles are.

## The shader of a floor that puddles stand on, which decides where they are
## from a mask. What follows from here to RAGGED says what it does with that
## mask and has to follow it: see shaders/wet_floor.gdshader.
const WET_FLOOR := preload("res://shaders/wet_floor.gdshader")
const SMOKE_TIN := preload("res://scenes/models/smoke_grenade.scn")
## How wide the shore of a puddle is, in what the mask is measured in.
const SHORE := 0.035
## The scale at which the mask is read a second time, and how much of that
## is added to it, for a shore that is ragged.
const PATCHY := 0.37
const RAGGED := 0.09
## The least the normal of a surface points up for water to stand on it.
const FACES_UP := 0.7
## How far above or below the top of a floor a point is still on it, in
## metres. The ground outdoors lies 5 cm under the floors indoors.
const ON_FLOOR := 0.03
## Seconds the rings of a splash run out for, and how far they get in metres.
const RING_TIME := 1.4
const RING_REACH := 0.9


## Where the water stands on the floors of one material, as the shader of
## that material has it.
class Water:
	## The mask, one byte for each of its texels, row after row, and how many
	## texels it is wide and high. Empty until the image of the mask is there.
	var mask := PackedByteArray()
	var size := Vector2i.ZERO
	## `mask_scale` of the material, and the least the mask has to be for
	## water to stand: one less its `puddle_amount`.
	var scale := 0.045
	var level := 1.0
	## What the rings of a splash on such a floor are drawn with: it reads
	## the same mask.
	var rings: ShaderMaterial

	## How much water stands where the floor has `uv`: 1 in a puddle, 0 on
	## dry floor and in between on the shore, as `puddle` is in the shader.
	func puddle(uv: Vector2) -> float:
		if mask.is_empty():
			return 0.0
		var value := _read(uv * scale) + (_read(uv * PATCHY) - 0.5) * RAGGED
		return smoothstep(level, level + SHORE, value)

	## The mask at `uv` as a shader reads it: between the four texels
	## around, and round to the other side at an edge.
	func _read(uv: Vector2) -> float:
		var x := uv.x * size.x - 0.5
		var y := uv.y * size.y - 0.5
		var column := floori(x)
		var row := floori(y)
		var left := posmod(column, size.x)
		var right := posmod(column + 1, size.x)
		var top := posmod(row, size.y) * size.x
		var bottom := posmod(row + 1, size.y) * size.x
		var above := lerpf(mask[top + left], mask[top + right], x - column)
		var below := lerpf(mask[bottom + left], mask[bottom + right], x - column)
		return lerpf(above, below, y - row) / 255.0


## A triangle of floor that faces up and that water can stand on.
class Patch:
	var water: Water
	## One of its corners, in the world.
	var corner: Vector3
	## What a metre along the X and along the Z of the world adds to how far
	## a point is on the way from that corner to each of the other two.
	var towards_second: Vector2
	var towards_third: Vector2
	## What that adds to the height of the floor.
	var slope: Vector2
	## The UV of the floor at the corner, and what a metre along X and a
	## metre along Z add to it. For the top of a floor that the level
	## builder made, the UV is simply x and z.
	var uv: Vector2
	var uv_along_x: Vector2
	var uv_along_z: Vector2

	## Whether `position` lies on this triangle: over it, and no further
	## above or below it than ON_FLOOR.
	func holds(position: Vector3) -> bool:
		var from := Vector2(position.x - corner.x, position.z - corner.z)
		var second := towards_second.dot(from)
		var third := towards_third.dot(from)
		if second < -0.0001 or third < -0.0001 or second + third > 1.0001:
			return false
		return absf(position.y - corner.y - slope.dot(from)) <= ON_FLOOR

	## The UV the floor has at `position`.
	func uv_at(position: Vector3) -> Vector2:
		return uv + uv_along_x * (position.x - corner.x) + uv_along_z * (position.z - corner.z)


var _drops: ArrayMesh
var _rings: ArrayMesh
## Every triangle of floor in the level that water can stand on, and the
## level they were looked up in: the id of its scene, 0 for none.
var _floors: Array[Patch] = []
var _charted := 0


func _ready() -> void:
	_sparks = _burst_mesh(28, preload("res://shaders/sparks.gdshader"))
	_chips = _burst_mesh(18, preload("res://shaders/chips.gdshader"))
	_shards = _burst_mesh(24, preload("res://shaders/glass.gdshader"))
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
	var standing := ShaderMaterial.new()
	standing.shader = preload("res://shaders/smoke_cloud.gdshader")
	standing.set_shader_parameter(&"noise", _stacked(preload("res://assets/noise/smoke.res")))
	_standing.radius = 1.0
	_standing.height = 2.0
	_standing.radial_segments = 24
	_standing.rings = 12
	_standing.material = standing
	_bursts = [_sparks, _chips, _shards, _puffs, _smoke, _clouds, _flames, _standing]
	_ready_glass()
	_ready_burning()
	_ready_splash()

	for surface: String in HOLE_VARIANTS:
		var variants := []
		for i in HOLE_VARIANTS[surface]:
			var stem := "%shole_%s_%d" % [DECALS, surface, i + 1]
			var glow: Texture2D = load(stem + "_e.png") if surface == "metal" else null
			variants.append([load(stem + ".png"), load(stem + "_n.png"), load(stem + "_orm.png"), glow])
		_hole_textures[surface] = variants
	_print_textures = [load(DECALS + "boot_print.png"), load(DECALS + "boot_print_n.png")]
	for i in SCORCH_VARIANTS:
		_scorch_textures.append(load("%sscorch_%d.png" % [DECALS, i + 1]))
	for i in BLOOD_VARIANTS:
		_blood_textures.append(load("%sblood_%d.png" % [DECALS, i + 1]))
	_pool_texture = load(DECALS + "blood_pool.png")
	var wet := Image.create_empty(4, 4, false, Image.FORMAT_RGB8)
	wet.fill(Color(1.0, 0.22, 0.0))
	_wet = ImageTexture.create_from_image(wet)

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
	_clip_mesh.size = Vector3(0.016, 0.052, 0.019)
	_clip_mesh.material = load("res://materials/gun_steel.tres")


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


## The streak of a bullet on its way from `from` to `to`. Every shot that is
## fired comes by here, on every machine, so this is also where the glass it
## went through breaks: see _through_glass().
func tracer(from: Vector3, to: Vector3, tint := Color(1.0, 0.7, 0.35)) -> void:
	_through_glass(from, to)
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


## What a ray hit is made of: "concrete", "brick", "metal", "wood", "soft" or
## "sand", "flesh" for somebody, or "air" for a wall nobody sees at the edge
## of open land. The level builder marks every collider that is not concrete.
##
## Land is one collider and all of it sand, but slabs may lie on it: the
## builder leaves where on the collider, as "paved", the parts of the land
## (x and z) that are laid with concrete. A hit there is on concrete.
func surface_of(hit: Dictionary) -> String:
	var body := hit.collider as CollisionObject3D
	if body == null or body.get_shape_owners().is_empty():
		return "concrete"
	var shape := body.shape_owner_get_owner(body.shape_find_owner(hit.shape))
	if shape == null:
		return "concrete"
	var surface: String = shape.get_meta(&"surface", "concrete")
	if surface == "sand" and shape.has_meta(&"paved") and hit.has("position"):
		var at := Vector2(hit.position.x, hit.position.z)
		for slab: Rect2 in shape.get_meta(&"paved"):
			if slab.has_point(at):
				return "concrete"
	return surface


## A shot that came in along `incoming` lands on the level: `hit` is what the
## ray found. One pellet of several makes a `light` impact, so that a load of
## shot does not throw nine times the dust of a bullet.
func impact(hit: Dictionary, incoming: Vector3, light := false) -> void:
	var surface := surface_of(hit)
	strike(hit.position, hit.normal, incoming, surface, light)
	thud(hit.position, surface)


## What a shot sounds like where it lands. In a puddle that is duller than
## on the concrete under it: `impact_soft`, for as long as there is no
## recording of a shot into water. Sfx picks up a folder
## `assets/audio/impact_water/` by itself, and that is played here from then
## on.
func thud(position: Vector3, surface: String) -> void:
	if surface == "air":
		return
	var sound := "concrete" if surface == "brick" else surface
	if sound == "concrete" and in_puddle(position):
		sound = "water" if Sfx.has(&"impact_water") else "soft"
	Sfx.play_at(StringName("impact_" + sound), position, -8.0)


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
		"sand":
			# Sand takes a shot with a spurt of itself and keeps a dent.
			_burst(_puffs, frame, 1.8, {&"tint": Color(0.8, 0.72, 0.56, 0.55), &"speed": randf_range(2.0, 3.2), &"size": Vector2(0.05, 0.36), &"life": 1.5, &"rise": -0.05, &"amount": share})
			_burst(_chips, frame, 2.2, {&"floor_y": floor_y, &"tint": Color(0.78, 0.7, 0.54), &"size": 0.012, &"amount": 0.6 * share})
			_hole("soft", frame, randf_range(0.06, 0.09)).modulate = Color(0.5, 0.43, 0.33)
		"flesh":
			# Somebody: what a hit does to them is theirs to show, see blood().
			pass
		"air":
			# A wall nobody sees: a shot that ends on it leaves nothing.
			pass
		_:
			if normal.y > FACES_UP and in_puddle(position):
				# Water throws up no dust. The shot goes through it into the
				# floor all the same: the pit it leaves is seen through the
				# water, which lies smooth over it.
				splash(position, normal, incoming, light)
				var pit := _hole("concrete", frame, randf_range(0.11, 0.15))
				pit.texture_normal = null
				pit.texture_orm = null
				pit.modulate = Color(0.5, 0.5, 0.55)
				return
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


## A shot lands on flesh: blood out of the back of the wound, the way the
## shot was going, a little out of the front, and now and then a splash on
## the floor or the wall behind.
func blood(position: Vector3, incoming: Vector3) -> void:
	var floor_y := floor_below(position)
	var through := Transform3D(_up_along((incoming + Vector3.UP * 0.2).normalized()), position)
	_burst(_chips, through, 3.0, {&"floor_y": floor_y, &"tint": Color(0.3, 0.008, 0.008), &"size": 0.028, &"slender": 2.0, &"speed": 3.4, &"spread": 0.5, &"amount": randf_range(0.5, 1.0)})
	_burst(_puffs, through, 0.45, {&"tint": Color(0.36, 0.015, 0.015, 0.6), &"speed": 1.8, &"spread": 0.5, &"size": Vector2(0.03, 0.22), &"life": 0.4, &"rise": -0.4, &"amount": 0.6})
	var back := Transform3D(_up_along((Vector3.UP * 0.4 - incoming).normalized()), position)
	_burst(_chips, back, 3.0, {&"floor_y": floor_y, &"tint": Color(0.3, 0.008, 0.008), &"size": 0.02, &"slender": 2.0, &"speed": 2.0, &"spread": 0.6, &"amount": 0.3})
	if randf() < 0.5:
		var beyond := position + (incoming + Vector3.DOWN * 0.35).normalized() * 3.0
		var hit := get_viewport().find_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(position, beyond, WORLD))
		if hit:
			_stain(_blood_textures.pick_random(), Transform3D(_up_along(hit.normal), hit.position), randf_range(0.25, 0.5))


## Blood runs out from under a body that lies at `position`.
func blood_pool(position: Vector3) -> void:
	var floor_y := floor_below(position + Vector3.UP * 0.3, 2.5)
	if floor_y < position.y - 2.5:
		return
	var pool := _stain(_pool_texture, Transform3D(Basis(), Vector3(position.x, floor_y, position.z)), 0.3)
	var across := randf_range(0.9, 1.3)
	pool.create_tween().tween_property(pool, "size", Vector3(across, 0.2, across), 5.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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


## Draws every kind of burst once, with nothing in it, and with it whatever
## is in `extras`: meshes as they will look when their moment comes, such as
## a board of a crate that has yet to be shot to pieces. The first time the
## renderer is to draw a kind of thing it has to make ready for it, and on a
## machine that has never drawn it before that can hold up a frame for
## seconds. A level calls this as it loads, so that it happens while the
## picture comes up out of black and not at the first shot. It is all drawn
## a metre in front of the camera, a thousandth of its size.
func rehearse(extras: Array[MeshInstance3D] = []) -> void:
	_chart_water()
	var stage := Node3D.new()
	for mesh: Mesh in _bursts:
		var burst := MeshInstance3D.new()
		burst.mesh = mesh
		burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		burst.gi_mode = GeometryInstance3D.GI_MODE_DISABLED if mesh == _sparks else GeometryInstance3D.GI_MODE_DYNAMIC
		burst.custom_aabb = AABB(Vector3.ONE * -REACH, Vector3.ONE * REACH * 2.0)
		# Less than none of it: every one of its particles is left out.
		burst.set_instance_shader_parameter(&"amount", -1.0)
		stage.add_child(burst)
	# The pressure wave, the streak of a shot and the flame at a muzzle are
	# no bursts, and each is long over at the moment it starts out with.
	for mesh: Mesh in [_shell, _tracer, _flame]:
		var looks := MeshInstance3D.new()
		looks.mesh = mesh
		looks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		looks.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		looks.custom_aabb = AABB(Vector3.ONE * -REACH, Vector3.ONE * REACH * 2.0)
		stage.add_child(looks)
	# The tin of a smoke grenade, which no level has lying about.
	stage.add_child(SMOKE_TIN.instantiate())
	for extra in extras:
		stage.add_child(extra)
	add_child(stage)
	# It goes wherever the picture is taken from, frame by frame, and not
	# along with one camera: a level that is started from the title screen
	# loads while the camera of the menu still stands, which is gone before a
	# frame is drawn.
	for i in REHEARSAL:
		var camera := get_viewport().get_camera_3d()
		stage.visible = camera != null
		if camera:
			stage.global_transform = camera.global_transform * Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0.0, 0.0, -1.0))
		await get_tree().process_frame
	stage.queue_free()


## Something of wood or cardboard comes apart around `position`: `matter` is
## "wood" for a crate and "soft" for a cardboard box, and `across` how large
## it was in metres. Splinters or scraps fly, most of them the way of `push`,
## and the dust that lay on it hangs there for a moment. The boards
## themselves are up to whoever breaks: see scripts/stack.gd.
func smash(position: Vector3, push: Vector3, matter := "wood", across := 0.5) -> void:
	var floor_y := floor_below(position)
	var about := Transform3D(Basis(), position)
	var along := Transform3D(_up_along(push.normalized() + Vector3.UP), position)
	if matter == "wood":
		_burst(_chips, along, 3.0, {&"floor_y": floor_y, &"tint": Color(0.7, 0.55, 0.36), &"slender": 5.0, &"size": 0.11, &"speed": 5.5, &"spread": 0.9})
		_burst(_chips, about.rotated_local(Vector3.UP, 1.3), 3.0, {&"floor_y": floor_y, &"tint": Color(0.5, 0.38, 0.25), &"slender": 3.5, &"size": 0.06, &"speed": 4.0, &"spread": 1.0})
		_burst(_puffs, about, 1.3, {&"tint": Color(0.68, 0.58, 0.45, 0.4), &"speed": 1.6, &"spread": 1.0, &"size": Vector2(0.12, across), &"life": 1.1, &"rise": -0.05, &"amount": 0.6})
	else:
		_burst(_chips, along, 3.0, {&"floor_y": floor_y, &"tint": Color(0.62, 0.5, 0.36), &"slender": 1.3, &"size": 0.07, &"speed": 3.0, &"spread": 0.9})
		_burst(_puffs, about, 1.1, {&"tint": Color(0.7, 0.64, 0.55, 0.35), &"speed": 1.2, &"spread": 1.0, &"size": Vector2(0.08, across), &"life": 0.9, &"rise": -0.05, &"amount": 0.5})


## A lamp is shot out at `position`: its glass comes down, which leaves the
## way of `out`. `size` is 1 for the glass of a hall lamp. A lamp that was
## `lit` goes with a flash, a shower of sparks and a wisp of smoke.
func shatter(position: Vector3, out := Vector3.DOWN, size := 1.0, lit := true) -> void:
	var floor_y := _floor_under_lamp(position)
	var reach := maxf(REACH, position.y - floor_y + 1.0)
	var frame := Transform3D(_up_along(out), position)
	_burst(_shards, frame, 4.0, {&"floor_y": floor_y, &"size": 0.06 * size, &"speed": 2.0 + size, &"spread": 0.85, &"amount": clampf(0.3 + 0.7 * size, 0.0, 1.0)}, reach)
	if not lit:
		return
	flash(position + out * 0.1, Color(0.85, 0.92, 1.0), 5.0 * size, 7.0, 0.12)
	_burst(_sparks, frame, 1.5, {&"floor_y": floor_y, &"tint": Color(1.0, 0.75, 0.45), &"speed": 3.0 + 3.0 * size, &"spread": 0.85, &"life": 1.2, &"amount": clampf(size, 0.3, 1.0)}, reach)
	_burst(_puffs, Transform3D(Basis(), position), 1.3, {&"tint": Color(0.8, 0.8, 0.82, 0.3), &"speed": 0.5, &"spread": 0.6, &"size": Vector2(0.03, 0.12 + 0.12 * size), &"life": 1.1, &"rise": 0.3, &"amount": 0.45})


## What is left of a lamp that was shot out spits a few sparks, the way of
## `out`.
func spit(position: Vector3, out := Vector3.DOWN) -> void:
	var floor_y := _floor_under_lamp(position)
	_burst(_sparks, Transform3D(_up_along(out), position), 1.0, {&"floor_y": floor_y, &"tint": Color(1.0, 0.75, 0.45), &"speed": randf_range(2.0, 4.5), &"spread": 0.6, &"life": 0.8, &"amount": randf_range(0.15, 0.4)},
		maxf(REACH, position.y - floor_y + 1.0))
	flash(position + out * 0.1, Color(0.85, 0.92, 1.0), 1.6, 4.0, 0.06)


## Height of the floor that what falls from a lamp lands on. A lamp hangs
## higher than anything else that looks for a floor, and one that hangs over
## nothing drops its glass no further than LAMP_DROP.
func _floor_under_lamp(position: Vector3) -> float:
	return maxf(floor_below(position, LAMP_DROP), position.y - LAMP_DROP)


## Makes ready what the glass of a window needs when it breaks, as _ready()
## does for the rest.
func _ready_glass() -> void:
	_pane_shards = _burst_mesh(PANE_SHARDS, preload("res://shaders/glass.gdshader"))
	(_pane_shards.surface_get_material(0) as ShaderMaterial).set_shader_parameter(&"pieces", float(PANE_SHARDS))
	_bursts.append(_pane_shards)


## Breaks the panes of glass that a shot went through on its way from `from`,
## where its streak starts, to `to`. Glass stops no shot, so whoever fired it
## never knew: the windows are found here, on the layer that only they are
## on, see scripts/window.gd. The host decides what breaks.
func _through_glass(from: Vector3, to: Vector3) -> void:
	if Net.is_guest() or from.is_equal_approx(to):
		return
	# The streak of the player's own shot leaves the muzzle, a hand's breadth
	# beside the line the shot itself went along, which starts at the eye:
	# the pane under the crosshair is the one that has to break.
	var camera := get_viewport().get_camera_3d()
	if camera and from.distance_to(camera.global_position) < OWN_SHOT:
		from = camera.global_position
	var space := get_viewport().find_world_3d().direct_space_state
	var along := from.direction_to(to)
	var query := PhysicsRayQueryParameters3D.create(from, to, GLASS)
	for i in MOST_PANES:
		var hit := space.intersect_ray(query)
		if hit.is_empty() or not hit.collider.has_method("shot"):
			return
		hit.collider.shot(hit.shape, along)
		query.from = (hit.position as Vector3) + along * PANE_STEP
		if (to - query.from).dot(along) <= 0.0:
			return


## A pane of glass breaks. `frame` stands in the middle of it with its X and
## Z along its sides, which are `size` metres, and its Y through the glass.
## The glass leaves on the side that `out` points to. `force` is how hard a
## blast throws it, up to 1. At 0 it is only let go of, which is what a shot
## does: then some of it comes down on the near side as well, and the dust
## that lay on it hangs there for a moment. A blast that has set off
## MAX_BLOWN bursts of shards leaves none for the panes after that.
func pane(frame: Transform3D, size: Vector2, out: Vector3, force := 0.0) -> void:
	var area := size.x * size.y
	var parts := clampi(ceili(area / PANE_PART), 1, 4)
	if force > 0.0:
		if _blown_frame != Engine.get_process_frames():
			_blown_frame = Engine.get_process_frames()
			_blown = 0
		if _blown + parts > MAX_BLOWN:
			return
		_blown += parts
	var through := frame.basis.y if frame.basis.y.dot(out) >= 0.0 else -frame.basis.y
	var leaving := (through + out.normalized() * lerpf(0.5, 2.0, force)).normalized()
	var beyond := floor_below(frame.origin + through * PANE_THROW, LAMP_DROP)
	var before := _floor_under_lamp(frame.origin - through * PANE_THROW)
	# Where there is nothing out there to land on, the ground is taken to be
	# as high as the floor on this side.
	if beyond < frame.origin.y - LAMP_DROP:
		beyond = before
	# A large pane breaks as several side by side, along its longer side.
	var lengthwise := size.x >= size.y
	var part := Vector2(size.x / parts, size.y) if lengthwise else Vector2(size.x, size.y / parts)
	var share := part.x * part.y
	# A blast breaks many panes at once: each of them leaves half its shards.
	var away := {&"floor_y": beyond, &"area": part, &"size": PANE_SHARD * clampf(sqrt(share), 0.4, 1.2), &"spread": lerpf(0.8, 0.5, force),
		&"amount": clampf(share, 0.15, 1.0) * (0.5 if force > 0.0 else 1.0)}
	var back := away.merged({&"floor_y": before, &"speed": PANE_SPEED * 0.4, &"amount": away.amount * 0.35}, true)
	for i in parts:
		var offset := (i + 0.5) / parts - 0.5
		var middle := frame.origin + (frame.basis.x * size.x if lengthwise else frame.basis.z * size.y) * offset
		# The same shards every time, so they are turned another way round
		# for every pane.
		var x := frame.basis.x * (1.0 if randf() < 0.5 else -1.0)
		var z := frame.basis.z * (1.0 if randf() < 0.5 else -1.0)
		away[&"speed"] = lerpf(PANE_SPEED, PANE_BLOWN, force) * randf_range(0.8, 1.2)
		_burst(_pane_shards, Transform3D(Basis(x, leaving, z), middle), PANE_TIME, away, maxf(REACH, middle.y - beyond + 1.0))
		if force == 0.0:
			_burst(_pane_shards, Transform3D(Basis(-x, -through, -z), middle), PANE_TIME, back, maxf(REACH, middle.y - before + 1.0))
	if force == 0.0:
		_burst(_puffs, Transform3D(_up_along(leaving), frame.origin), 0.8, {&"tint": Color(0.8, 0.82, 0.84, 0.16), &"speed": 0.9, &"spread": 1.0,
			&"size": Vector2(0.05, 0.28 * clampf(sqrt(area), 0.3, 1.5)), &"life": 0.7, &"rise": -0.1, &"amount": 0.45})


## Something blows up at `position`: a flash, a pressure wave, a ball of fire
## that burns out into smoke, a ring of dust along the floor, sparks, debris
## and soot where it stood. `size` 1 is a fuel barrel or a hand grenade.
func explosion(position: Vector3, size := 1.0) -> void:
	var up := Transform3D(Basis(), position)
	var floor_y := floor_below(position + Vector3.UP * 0.2)
	var reach := 7.0 * size
	# The cloud hangs over where it went off, and is lit as it is there.
	var light := smoke_light(position + Vector3.UP * SMOKE_HEIGHT * size)
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
	_burst(_clouds, up, 3.6, {&"tint": Color(0.17, 0.162, 0.154, 0.9), &"glow": 1.0, &"fire": 0.16, &"speed": 12.0 * size, &"spread": 1.0, &"size": Vector2(0.3, 1.5) * size, &"life": 3.4, &"rise": 0.9}.merged(light), reach)
	_burst(_smoke, up, 0.5, {&"tint": Color(1.0, 0.6, 0.25, 1.0), &"glow": 1.6, &"fire": 1.0, &"speed": 5.0 * size, &"spread": 1.0, &"size": Vector2(0.3, 1.0) * size, &"life": 0.4, &"rise": 0.5}.merged(light), reach)
	# The column stands in the cloud, which keeps part of the key light off it.
	var column := _burst(_smoke, up, 6.0, {&"tint": Color(0.17, 0.166, 0.162, 0.7), &"key_light": (light.key_light as Vector3) * SMOKE_SHROUDED, &"speed": 2.5 * size, &"spread": 0.8, &"size": Vector2(0.4, 1.8) * size, &"life": 5.0, &"rise": 0.9}.merged(light), reach)
	column.set_instance_shader_parameter(&"start", time + 0.25)
	for turn in 3:
		_burst(_sparks, up.rotated_local(Vector3.UP, turn * 2.1), 2.0, {&"floor_y": floor_y, &"speed": randf_range(11.0, 17.0) * size, &"spread": 1.0, &"life": randf_range(1.1, 1.8)}, reach * 2.0)
	for turn in 2:
		_burst(_chips, up.rotated_local(Vector3.UP, turn * 1.3), 3.0, {&"floor_y": floor_y, &"tint": Color(0.07, 0.07, 0.075), &"speed": randf_range(8.0, 11.0) * size, &"size": 0.06 * size, &"spread": 1.0}, reach * 2.0)

	if floor_y > position.y - 2.0 * size:
		var ground := Vector3(position.x, floor_y, position.z)
		# The blast sweeps the dust off the floor in a ring.
		_burst(_clouds, Transform3D(Basis(), ground + Vector3.UP * 0.15), 1.6, {&"tint": Color(0.33, 0.31, 0.28, 0.4), &"speed": 17.0 * size, &"spread": 2.0, &"size": Vector2(0.25, 1.0) * size, &"life": 1.4, &"rise": 0.2}.merged(light), reach)
		var soot := Decal.new()
		soot.texture_albedo = _scorch_textures.pick_random()
		var across := randf_range(3.0, 3.6) * size
		soot.size = Vector3(across, 0.3, across)
		soot.transform = Transform3D(Basis(Vector3.UP, randf() * TAU), ground)
		_keep(soot)


## The light on a cloud of smoke that hangs around `position`, as the instance
## uniforms of shaders/smoke.gdshader: the renderer does not light that smoke,
## so whoever sets it off hands this in with the rest. The key light is the
## brightest of the sun and the lamps that get to the cloud with nothing in
## the way. A cloud that none of them gets to is lit from above, by the light
## that comes from all around.
func smoke_light(position: Vector3) -> Dictionary:
	# Every light that reaches this far: [how bright, the way to it, its
	# colour, how far the line to it has to be clear].
	var lights: Array[Array] = []
	var sun := _sun()
	if sun and sun.visible:
		lights.append([sun.light_energy, sun.global_basis.z, sun.light_color, 80.0])
	for lamp in level_lamps():
		var strength := lamp_strength(lamp, position)
		if strength > 0.0:
			var to := lamp.global_position - position
			lights.append([strength, to.normalized(), lamp.light_color, to.length() - SMOKE_CLEAR])
	lights.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var space := get_viewport().find_world_3d().direct_space_state
	var around := _ambient()
	for light: Array in lights.slice(0, SMOKE_TRIES):
		var way: Vector3 = light[1]
		var query := PhysicsRayQueryParameters3D.create(position, position + way * maxf(light[3], 0.0), WORLD)
		if space.intersect_ray(query).is_empty():
			var colour := _rgb(light[2])
			var key: Vector3 = colour.lerp(Vector3.ONE * colour.dot(LUMINANCE), SMOKE_GREY) * light[0]
			return {&"key": way, &"key_light": key, &"fill": around + key * SMOKE_BOUNCE}
	return {&"key": Vector3.UP, &"key_light": around * SMOKE_OVERHEAD, &"fill": around}


## How brightly a lamp lights a point, by the renderer's own reckoning: its
## energy, less what is lost over the distance and, for a spot, towards the
## edge of its beam. Nothing for a lamp that is out or out of reach.
func lamp_strength(lamp: Light3D, position: Vector3) -> float:
	if not is_instance_valid(lamp) or not lamp.visible:
		return 0.0
	var reach := lamp.get_param(Light3D.PARAM_RANGE)
	var from := position - lamp.global_position
	var distance := maxf(from.length(), SMOKE_NEAR)
	if distance >= reach:
		return 0.0
	var strength := lamp.light_energy * (1.0 - (distance / reach) ** 4.0) ** 2.0 * distance ** -lamp.get_param(Light3D.PARAM_ATTENUATION)
	if lamp is SpotLight3D:
		var edge := cos(deg_to_rad(lamp.get_param(Light3D.PARAM_SPOT_ANGLE)))
		var off := (1.0 - maxf(from.normalized().dot(-lamp.global_basis.z), edge)) / (1.0 - edge)
		strength *= 1.0 - off ** lamp.get_param(Light3D.PARAM_SPOT_ATTENUATION)
	return strength


## The lamps the level builder put in the level, looked up once per level.
func level_lamps() -> Array[Light3D]:
	var scene := get_tree().current_scene
	if scene.get_instance_id() != _lamps_of:
		_lamps_of = scene.get_instance_id()
		_lamps.assign(scene.find_children("*", "Light3D", true, false).filter(
			func(light: Light3D) -> bool: return light.get_parent().name == &"Lights" and not light is DirectionalLight3D))
	return _lamps


## The sun of the level, or its moon; nothing if it has neither.
func _sun() -> DirectionalLight3D:
	var sun: DirectionalLight3D = null
	for light in get_tree().current_scene.find_children("*", "DirectionalLight3D", false, false):
		sun = light
	return sun


## The light that comes from all around in the level, going by what its
## environment says: the ambient colour, and white for the share of it that
## the sky gives.
func _ambient() -> Vector3:
	var environment := get_viewport().find_world_3d().environment
	if environment == null:
		return Vector3.ONE * SMOKE_SKY
	var source := environment.ambient_light_source
	var sky := 0.0
	if source == Environment.AMBIENT_SOURCE_BG or source == Environment.AMBIENT_SOURCE_SKY:
		sky = environment.ambient_light_sky_contribution
	var colour := Vector3.ZERO if source == Environment.AMBIENT_SOURCE_DISABLED else _rgb(environment.ambient_light_color) * (1.0 - sky)
	return (colour + Vector3.ONE * sky * environment.background_energy_multiplier) * environment.ambient_light_energy * SMOKE_SKY


## A colour as the three numbers a shader works with.
func _rgb(colour: Color) -> Vector3:
	var linear := colour.srgb_to_linear()
	return Vector3(linear.r, linear.g, linear.b)


## A fire that burns for `seconds` on a patch `across` metres wide around
## `position`: the flames, the light they throw and, unless `smokes` is
## false, the smoke that rises off them (a campfire has a column of its own).
## Freeing what it returns puts it out.
func fire(position: Vector3, across: float, seconds: float, smokes := true) -> Node3D:
	var scale := clampf(across, 0.5, 1.6)
	var flames := _burst(_flames, Transform3D(Basis(), position), seconds, {&"life": seconds, &"radius": across * 0.5, &"size": Vector2(0.24, 1.3) * scale})
	_burn(flames, Vector3.UP * 0.5 * scale, 1.6 * scale, 3.5 + across * 2.0, seconds, time + 0.3 if smokes else INF)
	return flames


## The flame that roars out of a hole in something under pressure: `length`
## metres long, leaving `position` along `direction`, for `seconds`. Freeing
## what it returns puts it out.
func jet(position: Vector3, direction: Vector3, length: float, seconds: float) -> Node3D:
	var flames := _burst(_flames, Transform3D(_up_along(direction), position), seconds, {&"life": seconds, &"radius": 0.015, &"size": Vector2(0.13, length), &"rush": 5.0, &"amount": 0.45})
	_burn(flames, Vector3.UP * length * 0.4, 1.0, 3.5, seconds, INF)
	return flames


## The light of a fire, which flickers for as long as it burns: it hangs at
## `offset` from the flames and goes when they do. It throws no shadows.
## Smoke starts to rise at the moment `smoke`. What comes back is what
## _step() keeps of the fire, with the flames it belongs to as `flames`, the
## moment it next spits sparks as `spit`, which is never unless somebody says
## so, and the height of the floor they land on as `floor`.
func _burn(flames: Node3D, offset: Vector3, energy: float, reach: float, seconds: float, smoke: float) -> Dictionary:
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
	var burning := {"flames": flames, "light": light, "at": at, "start": time, "seconds": seconds, "energy": energy, "smoke": smoke, "spit": INF, "floor": at.y, "puffs": [], "seed": randf() * 100.0}
	_fires.append(burning)
	return burning


## Tells the smoke that a fire still lights from below when that fire is
## out: at the moment `end`, on the clock of the effects.
func _embers(burning: Dictionary, end: float) -> void:
	for puff: Variant in burning.puffs:
		if is_instance_valid(puff):
			(puff as MeshInstance3D).set_instance_shader_parameter(&"ember", Vector2(SMOKE_EMBER, end))


## Makes ready what something that has caught fire is drawn with.
func _ready_burning() -> void:
	_blaze = _burst_mesh(BLAZE_FLAMES, preload("res://shaders/flames.gdshader"))
	(_blaze.surface_get_material(0) as ShaderMaterial).set_shader_parameter(&"noise", preload("res://assets/masks/wear.png"))
	_bursts.append(_blaze)
	_soot = _soot_texture()


## Flames on something that has caught fire: they come out of the sides and
## the top of a box `size` metres large that stands on the origin of `at`,
## lick up along it and stand over it, for `seconds`, with the light they
## throw, the smoke that rises off them and the sparks that wood spits.
## Freeing what it returns puts it out, and feed() fits it to what burns when
## that changes.
func blaze(at: Transform3D, size: Vector3, seconds: float) -> Node3D:
	var flames := _burst(_blaze, at, BLAZE_TIME, {}, BLAZE_REACH)
	var burning := _burn(flames, Vector3.ZERO, 0.0, 4.0, seconds, time + 0.3)
	burning.spit = time + randf_range(0.2, 0.7)
	feed(flames, at, size, seconds)
	return flames


## Fits the flames of blaze() to what burns now: the box that stands on the
## origin of `at`, `size` metres large, with `seconds` left to burn. A larger
## box gets larger flames, more of them, and more light. If it is `covered`,
## something stands on it that does not burn, and the flames keep to its
## sides. False if that fire is over: its time was up, though whoever lit it
## may still have the flames.
func feed(flames: Node3D, at: Transform3D, size: Vector3, seconds: float, covered := false) -> bool:
	if not is_instance_valid(flames):
		return false
	for burning in _fires:
		if not is_same(burning.flames, flames):
			continue
		var age: float = time - burning.start
		# Flames are sized by how much there is to burn: the root of its area.
		var grown := sqrt(2.0 * (size.x + size.z) * size.y + (0.0 if covered else size.x * size.z))
		flames.global_transform = at
		flames.set_instance_shader_parameter(&"box", size)
		flames.set_instance_shader_parameter(&"crown", 0.0 if covered else 1.0)
		flames.set_instance_shader_parameter(&"size", Vector2(0.2 + 0.07 * grown, 0.6 + 0.3 * grown))
		flames.set_instance_shader_parameter(&"amount", clampf(grown * grown * BLAZE_DENSITY / BLAZE_FLAMES, 0.22, 1.0))
		flames.set_instance_shader_parameter(&"life", age + seconds)
		var light: OmniLight3D = burning.light
		light.position = Vector3.UP * (size.y * 0.5 + 0.3)
		light.omni_range = 3.0 + grown
		burning.energy = 0.9 + 0.35 * grown
		burning.seconds = age + seconds
		_embers(burning, burning.start + burning.seconds)
		# Smoke and sparks leave from its top, and the sparks come down on
		# what it stands on.
		burning.at = at * Vector3(0.0, size.y, 0.0)
		burning.floor = floor_below(at.origin + Vector3.UP * 0.1)
		return true
	return false


## Something that has burnt through falls apart around `position`: charred
## splinters, a shower of sparks and a cloud of ash. `across` is how large it
## was in metres. The boards themselves are up to whoever burnt: see
## scripts/stack.gd.
func crumble(position: Vector3, across := 0.5) -> void:
	var floor_y := floor_below(position)
	var about := Transform3D(Basis(), position)
	_burst(_chips, about, 3.0, {&"floor_y": floor_y, &"tint": Color(0.05, 0.045, 0.04), &"slender": 4.0, &"size": 0.08, &"speed": 2.6, &"spread": 1.0})
	_burst(_sparks, about, 1.6, {&"floor_y": floor_y, &"speed": 3.5, &"spread": 0.9, &"life": 1.3, &"amount": 0.7})
	_burst(_puffs, about, 1.8, {&"tint": Color(0.1, 0.095, 0.09, 0.5), &"speed": 1.3, &"spread": 1.0, &"size": Vector2(0.12, across * 1.3), &"life": 1.6, &"rise": 0.35, &"amount": 0.7})


## Soot where something has burnt: a burn mark on the floor around the origin
## of `at`, and, if what burnt still stands there as a box `size` metres
## large, soot on that as well, down its sides as much as on its top. The
## oldest mark on the floor makes way once there are MAX_SOOT; the soot on
## what still stands stays for as long as the level does, since that is what
## shows it is burnt.
func soot(at: Transform3D, size: Vector3) -> void:
	var floor_y := floor_below(at.origin + Vector3.UP * 0.2, 1.2)
	if floor_y > at.origin.y - 1.0:
		var mark := Decal.new()
		mark.texture_albedo = _scorch_textures.pick_random()
		var across := maxf(size.x, size.z) * SOOT_SPREAD
		mark.size = Vector3(across, 0.3, across)
		mark.transform = Transform3D(at.basis.orthonormalized(), Vector3(at.origin.x, floor_y, at.origin.z))
		_keep(mark)
		_soot_marks.append(mark)
		_soot_marks = _soot_marks.filter(is_instance_valid)
		while _soot_marks.size() > MAX_SOOT:
			_soot_marks.pop_front().queue_free()
	if size.y > 0.0:
		var coat := Decal.new()
		coat.texture_albedo = _soot
		coat.size = size + Vector3.ONE * 0.1
		coat.transform = at * Transform3D(Basis(), Vector3.UP * size.y * 0.5)
		_keep(coat)
		# It is thrown down from above, and what it meets on the way down are
		# the sides.
		coat.normal_fade = 0.0


## What lies on something that has burnt: black, thick in patches and thin
## between them, where a little of the wood shows through.
func _soot_texture() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.09
	var image := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			image.set_pixel(x, y, Color(0.035, 0.032, 0.03, clampf(0.86 + 0.3 * noise.get_noise_2d(x, y), 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


## The wisp of smoke a barrel leaves once it falls silent, drifting on along
## `direction`; `amount` is 1 after a long burst.
func gun_smoke(position: Vector3, direction: Vector3, amount := 1.0) -> void:
	_burst(_puffs, Transform3D(_up_along(direction), position), 1.2,
		{&"tint": Color(0.62, 0.62, 0.64, 0.42), &"speed": 0.9, &"spread": 0.3, &"size": Vector2(0.015, 0.17), &"life": 1.0, &"rise": 0.3, &"amount": lerpf(0.45, 1.0, amount)})


## The cloud of a smoke grenade, which grows out of `position` on the floor and
## stands there: scripts/smoke.gd keeps it and says what it is told in
## `shape`. It is too wide to hang in one light: a shaft of sun on one side of
## it does not light the rest, so it gets what five spots in it get together.
func smoke_cloud(position: Vector3, shape: Dictionary) -> MeshInstance3D:
	var out: float = shape[&"radius"]
	var middle := position + Vector3.UP * SMOKE_HEIGHT
	var spots: Array[Vector3] = [middle]
	for side: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		# Higher than the middle: on a slope they would be in the ground.
		spots.append(middle + side * out * 0.6 + Vector3.UP * out * 0.4)
	var sun := _sun()
	var sun_way := sun.global_basis.z if sun else Vector3.ZERO
	var world := get_viewport().find_world_3d()
	var space := world.direct_space_state
	var night: bool = world.environment != null and world.environment.get_meta(&"night", false)
	var key := Vector3.ZERO
	var key_light := Vector3.ZERO
	var fill := Vector3.ZERO
	for spot in spots:
		var light := smoke_light(spot)
		var under_a_roof := space.intersect_ray(PhysicsRayQueryParameters3D.create(spot, spot + Vector3.UP * SMOKE_ROOFED, WORLD)).size() > 0
		var share := SMOKE_CLOUD_SHADE if under_a_roof and (light.key as Vector3).dot(sun_way) < 0.999 else 1.0
		key += (light.key as Vector3) * (light.key_light as Vector3).length()
		key_light += (light.key_light as Vector3) * share / spots.size()
		fill += (light.fill as Vector3) * share * (SMOKE_CLOUD_NIGHT if night else 1.0) / spots.size()
	var lit := {&"key": key.normalized() if key.length() > 0.0 else Vector3.UP, &"key_light": key_light, &"fill": fill}
	return _burst(_standing, Transform3D(Basis(), position), shape[&"life"], shape.merged(lit), out * SMOKE_CLOUD_BOX)


## A puff of the smoke out of an engine that is hit, carried along `drift`:
## grey while it only smokes, black and thick as `thick` goes to 1, once it
## burns.
func engine_smoke(position: Vector3, drift: Vector3, thick := 0.0) -> void:
	_burst(_puffs, Transform3D(_up_along(drift), position), 3.2,
		{&"tint": Color(0.3, 0.29, 0.28, 0.7).lerp(Color(0.07, 0.065, 0.06, 0.9), thick), &"speed": 1.2, &"spread": 0.4, &"size": Vector2(0.35, 1.8 + 1.0 * thick), &"life": 3.0, &"rise": 0.7, &"amount": 1.0})


## A puff of the smoke a rocket leaves behind it, `direction` the way it flies:
## thicker than a barrel's, slow to spread and slow to go.
func rocket_trail(position: Vector3, direction: Vector3) -> void:
	_burst(_puffs, Transform3D(_up_along(-direction), position), 2.4,
		{&"tint": Color(0.66, 0.66, 0.68, 0.5), &"speed": 0.35, &"spread": 0.5, &"size": Vector2(0.07, 0.55), &"life": 2.2, &"rise": 0.12, &"amount": 0.4})


## The slices of `sheet`, square and one under the other, as a texture of
## three dimensions: see tools/gen_smoke_noise.gd.
func _stacked(sheet: Image) -> ImageTexture3D:
	var across := sheet.get_width()
	var slices: Array[Image] = []
	for i in sheet.get_height() / across:
		slices.append(sheet.get_region(Rect2i(0, i * across, across, across)))
	var stacked := ImageTexture3D.new()
	stacked.create(sheet.get_format(), across, across, slices.size(), false, slices)
	return stacked


## Makes ready what a shot into a puddle throws up.
func _ready_splash() -> void:
	_drops = _burst_mesh(48, preload("res://shaders/drops.gdshader"))
	_rings = _burst_mesh(1, preload("res://shaders/rings.gdshader"))
	# Nothing that can be seen through lies under a puddle, so the rings go
	# before everything else that can.
	_rings.surface_get_material(0).render_priority = -1
	_bursts.append(_drops)
	_bursts.append(_rings)


## How much water stands at `position`: 1 in a puddle, 0 on dry floor and
## anywhere that is not the top of a floor, in between on the shore of a
## puddle. It is worked out from the mask the floor is drawn with, so it is
## where the puddle is seen.
func water_at(position: Vector3) -> float:
	var patch := _patch_at(position)
	return patch.water.puddle(patch.uv_at(position)) if patch else 0.0


## Whether `position` lies in a puddle.
func in_puddle(position: Vector3) -> bool:
	return water_at(position) > 0.5


## A shot lands in a puddle at `position`, on a floor that faces `normal`:
## a crown of drops that fly up and out and fall back, leaning the way the
## shot was going, a spout of spray that hangs for a moment, and rings that
## run out over the water as far as its shore. One pellet of a load of shot
## makes a `light` one.
func splash(position: Vector3, normal := Vector3.UP, incoming := Vector3.DOWN, light := false) -> void:
	var share := 0.45 if light else 1.0
	var kick := 0.7 if light else 1.0
	var onward := incoming - normal * incoming.dot(normal)
	var up := Transform3D(_up_along(normal + onward * 0.25), position)
	# The crown, the jet that stands up out of the middle of it, and the
	# spray around that: low and wide, and for a bullet high and thin as well.
	_burst(_drops, up, 1.6, {&"floor_y": position.y, &"speed": randf_range(3.0, 3.8) * kick, &"spread": 0.75, &"amount": share})
	_burst(_drops, up, 1.6, {&"floor_y": position.y, &"speed": randf_range(4.5, 5.5) * kick, &"spread": 0.1, &"size": 0.018, &"trail": 0.026, &"amount": 0.5 * share})
	_burst(_puffs, up, 0.55, {&"tint": Color(0.92, 0.95, 0.98, 0.55), &"speed": 3.0 * kick, &"spread": 0.22, &"size": Vector2(0.05, 0.2) * kick, &"life": 0.4, &"rise": -0.6, &"amount": 0.75 * share})
	if not light:
		_burst(_puffs, up, 0.65, {&"tint": Color(0.92, 0.95, 0.98, 0.6), &"speed": 7.0, &"spread": 0.1, &"size": Vector2(0.05, 0.26), &"life": 0.5, &"rise": -1.4, &"amount": 0.6})
	var patch := _patch_at(position)
	if patch == null:
		return
	var at := patch.uv_at(position)
	var rings := _burst(_rings, Transform3D(_up_along(normal), position), RING_TIME, {
		&"floor_uv": at, &"floor_uv_step": Vector4(patch.uv_along_x.x, patch.uv_along_x.y, patch.uv_along_z.x, patch.uv_along_z.y),
		&"reach": RING_REACH * (0.6 if light else 1.0), &"life": RING_TIME, &"steep": 0.6 if light else 1.0})
	rings.material_override = patch.water.rings


## The triangle of floor that `position` lies on, of the floors that are
## drawn with the shader of the wet floor. Null for anywhere else.
func _patch_at(position: Vector3) -> Patch:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	if scene.get_instance_id() != _charted:
		_chart_water()
	for patch in _floors:
		if patch.holds(position):
			return patch
	return null


## Looks up where water can stand in the level that is there now: every
## surface that is drawn with the shader of the wet floor, the triangles of
## it that face up, and the mask and the numbers of its material. A level
## does this as it loads, see rehearse(), and _patch_at() does it for one
## that did not; whatever was known of the level before is forgotten.
func _chart_water() -> void:
	var scene := get_tree().current_scene
	_floors.clear()
	_charted = scene.get_instance_id() if scene else 0
	if scene == null:
		return
	var waters := {}
	for node: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null:
			continue
		for surface in node.mesh.get_surface_count():
			var material := node.get_active_material(surface) as ShaderMaterial
			if material == null or material.shader != WET_FLOOR:
				continue
			if not waters.has(material):
				waters[material] = _water_of(material)
			_chart_surface(node, surface, waters[material])


## What there is to know of the water on floors of `material`. The image of
## its mask follows as soon as there is one.
func _water_of(material: ShaderMaterial) -> Water:
	var water := Water.new()
	water.scale = _number(material, &"mask_scale")
	water.level = 1.0 - _number(material, &"puddle_amount")
	var mask := material.get_shader_parameter(&"wet_mask") as Texture2D
	water.rings = _rings.surface_get_material(0).duplicate() as ShaderMaterial
	water.rings.set_shader_parameter(&"wet_mask", mask)
	water.rings.set_shader_parameter(&"mask_scale", water.scale)
	water.rings.set_shader_parameter(&"level", water.level)
	if mask:
		_read_mask(mask, water)
	return water


## A number of a material, or what its shader takes when the material does
## not say.
func _number(material: ShaderMaterial, parameter: StringName) -> float:
	var value: Variant = material.get_shader_parameter(parameter)
	if value == null:
		value = RenderingServer.shader_get_parameter_default(material.shader.get_rid(), parameter)
	return value if value != null else 0.0


## Gives `water` the image of its mask. A mask of noise has none until it
## has been worked out, which takes a moment after it is loaded; until then
## the floor counts as dry.
func _read_mask(mask: Texture2D, water: Water) -> void:
	if mask.get_image() == null:
		await mask.changed
	var image := mask.get_image()
	if image == null or image.is_empty():
		return
	# The red of every texel, at full size, is what the shader reads close by.
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	image.clear_mipmaps()
	image.convert(Image.FORMAT_R8)
	water.size = image.get_size()
	water.mask = image.get_data()


## Adds the triangles of a surface of wet floor that face up to `_floors`.
func _chart_surface(node: MeshInstance3D, surface: int, water: Water) -> void:
	var arrays := node.mesh.surface_get_arrays(surface)
	if arrays[Mesh.ARRAY_NORMAL] == null or arrays[Mesh.ARRAY_TEX_UV] == null:
		return
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	# Without a list of corners, every three vertices are a triangle.
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(vertices.size()))
	var to_world := node.global_transform
	for i in range(0, indices.size() - 2, 3):
		if (to_world.basis * normals[indices[i]]).normalized().y < FACES_UP:
			continue
		var first := to_world * vertices[indices[i]]
		var second := to_world * vertices[indices[i + 1]] - first
		var third := to_world * vertices[indices[i + 2]] - first
		# Twice what the triangle covers of the ground, seen from above.
		var area := second.x * third.z - second.z * third.x
		if is_zero_approx(area):
			continue
		var patch := Patch.new()
		patch.water = water
		patch.corner = first
		patch.towards_second = Vector2(third.z, -third.x) / area
		patch.towards_third = Vector2(-second.z, second.x) / area
		patch.slope = patch.towards_second * second.y + patch.towards_third * third.y
		patch.uv = uvs[indices[i]]
		var uv_second := uvs[indices[i + 1]] - patch.uv
		var uv_third := uvs[indices[i + 2]] - patch.uv
		patch.uv_along_x = uv_second * patch.towards_second.x + uv_third * patch.towards_third.x
		patch.uv_along_z = uv_second * patch.towards_second.y + uv_third * patch.towards_third.y
		_floors.append(patch)


## Looking along `direction`, whichever way that is.
func facing(direction: Vector3) -> Basis:
	var up := Vector3.RIGHT if absf(direction.normalized().y) > 0.99 else Vector3.UP
	return Basis.looking_at(direction, up)


## Frees every effect at once, marks included. The flames on what burns go
## with the rest, so what burns is put out; the soot of what has burnt stays,
## as what has burnt does.
func clear() -> void:
	Blast.douse()
	for entry: Array in _expiring:
		if is_instance_valid(entry[0]):
			entry[0].queue_free()
	for decal in _holes + _stains:
		if is_instance_valid(decal):
			decal.queue_free()
	_expiring.clear()
	_holes.clear()
	_stains.clear()


## Spent case thrown from a weapon that points along `basis`: it tumbles,
## bounces off the floor below and lies there a while. `shell` makes it the
## hull of a shotgun shell, `clip` the empty clip of a weapon loaded by clips.
func casing(position: Vector3, basis: Basis, velocity: Vector3, shell := false, clip := false) -> void:
	var node := MeshInstance3D.new()
	node.mesh = _clip_mesh if clip else (_shell_mesh if shell else _casing_mesh)
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
	_casings.append({"node": node, "velocity": velocity, "spin": spin, "floor": floor_y + (0.011 if shell else 0.005), "age": 0.0, "bounces": 0, "shell": shell})
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
	# Between two scenes there is nowhere to put the smoke of a fire that was
	# still burning in the one that is going.
	if get_tree().current_scene == null:
		return
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
			# Put out before its time: its smoke is lit no longer.
			if age <= burning.seconds:
				_embers(burning, time)
			_fires.remove_at(i)
			continue
		# Wood that burns spits a few sparks now and then.
		while time >= burning.spit:
			var sparks := _burst(_sparks, Transform3D(Basis(), burning.at), 1.5, {&"floor_y": burning.floor, &"speed": randf_range(2.0, 3.5), &"spread": 0.5, &"life": randf_range(0.8, 1.4), &"amount": randf_range(0.08, 0.2)})
			sparks.set_instance_shader_parameter(&"start", burning.spit)
			burning.spit += randf_range(0.3, 0.9)
		# In step with the flames: up at once, down over the last second or so.
		var dying := minf(1.5, burning.seconds * 0.4)
		var strength := smoothstep(0.0, 0.2, age) * (1.0 - smoothstep(burning.seconds - dying, burning.seconds, age))
		var flicker := 0.8 + 0.12 * sin(time * 23.0 + burning.seed) + 0.08 * sin(time * 57.0 + burning.seed * 2.0)
		burning.light.light_energy = burning.energy * strength * flicker
		while time >= burning.smoke and burning.smoke < burning.start + burning.seconds - dying:
			# The fire lights its smoke from below until it is out.
			var smoke := _burst(_smoke, Transform3D(Basis(), burning.at + Vector3.UP * 0.4), 3.0,
				{&"tint": Color(0.14, 0.14, 0.148, 0.5), &"ember": Vector2(SMOKE_EMBER, burning.start + burning.seconds), &"speed": 0.7, &"spread": 0.5, &"size": Vector2(0.15, 0.75), &"life": 2.6, &"rise": 1.2, &"amount": 0.45}.merged(smoke_light(burning.at + Vector3.UP * SMOKE_HEIGHT)))
			smoke.set_instance_shader_parameter(&"start", burning.smoke)
			burning.puffs = (burning.puffs as Array).filter(is_instance_valid)
			burning.puffs.append(smoke)
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
					# The take rings on over the bounces that follow.
					Sfx.play_at(&"shell_drop" if item.shell and Sfx.has(&"shell_drop") else &"casing", node.position, -24.0)
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


## The print a boot leaves in sand at `at`, a point on the ground that faces
## `up`, by somebody walking towards `heading`. The oldest print makes way
## once there are MAX_PRINTS: the wind has had it.
func footprint(at: Vector3, up: Vector3, heading: Vector3) -> void:
	var ahead := heading.slide(up)
	if ahead.length_squared() < 0.0001:
		return
	var decal := Decal.new()
	decal.texture_albedo = _print_textures[0]
	decal.texture_normal = _print_textures[1]
	# A dent more than a stain: the sand keeps most of its own colour.
	decal.albedo_mix = PRINT_STAIN
	decal.size = Vector3(PRINT_ACROSS, 0.2, PRINT_ACROSS)
	# A decal lies in its own X and Z and the top of its texture is its -Z:
	# the toe of the print.
	decal.transform = Transform3D(Basis.looking_at(ahead.normalized(), up), at)
	_keep(decal)
	_prints.append(decal)
	_prints = _prints.filter(is_instance_valid)
	while _prints.size() > MAX_PRINTS:
		_prints.pop_front().queue_free()


## A mark of blood `across` metres wide on the surface `frame` stands on,
## turned about at random. The oldest makes way once there are MAX_STAINS.
func _stain(texture: Texture2D, frame: Transform3D, across: float) -> Decal:
	var decal := Decal.new()
	decal.texture_albedo = texture
	decal.texture_orm = _wet
	decal.size = Vector3(across, 0.2, across)
	decal.transform = frame.rotated_local(Vector3.UP, randf() * TAU)
	_keep(decal)
	_stains.append(decal)
	_stains = _stains.filter(is_instance_valid)
	while _stains.size() > MAX_STAINS:
		_stains.pop_front().queue_free()
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
