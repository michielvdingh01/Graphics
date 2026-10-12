extends Node3D
## What the way out of a level lets in once its door goes up.
##
## A level is lightmapped with its door shut. The sun that falls into the
## doorway once the door is up is in no lightmap, so the floor behind an open
## door looked as it did behind a shut one. scripts/breakables.gd makes one
## of these for every door in the group "exit_door" when a level loads. It
## looks at what lies beyond the door, and that is what falls in:
##
## - the sun of the level, where it shines into the doorway: a patch of its
##   light in its colour and along its direction, so that the shadows inside
##   run the way the shadows outside do;
## - the sky, where the doorway is open to it but the sun does not get
##   there: cooler and softer, straight in;
## - the lamp that hangs beyond the door, where the door leads into a
##   building: its light, out through the doorway.
##
## That is a spotlight which stands beyond the door and shines through the
## doorway. The curtain of the door and the wall around it cast their own
## shadow in it, so the patch on the floor grows as the door goes up with
## nothing here that moves it, and whatever stands in it casts a shadow. A
## second light without a shadow, in the doorway itself, is what comes in
## from all of the opening at once: the sky and the lit ground beyond it.
##
## Nothing looks at the door from frame to frame. A node that rides on the
## door says when it has moved, and the lights are then set to how far up it
## is: however it got there, rolled up by the game, open already in a level
## that is carried on with, or put there by hand. Shut, the lights are off.

## What falls in through the doorway.
enum Source { NONE, SUN, SKY, LAMP }

## The render layers of scripts/zones.gd, which gives every zone its own.
const ZONES := preload("res://scripts/zones.gd")
## What stops light: the colliders of the level.
const WORLD := 1
## Physics frames after the level is in the tree before the lights are made.
## Its colliders are in the world after two, and that is also when
## scripts/zones.gd goes through the lamps of the level and holds each to
## the zones it gets to. These are made after that and so left out of it, on
## purpose: what they light is whatever stands in the beam of the doorway.
const SETTLE := 3
## How far beyond the door the light of the sun or of the sky stands, in
## metres. The further off, the more its rays come through the doorway side
## by side, as those of the sun do. But the shadow of a spotlight is kept in
## sixteen bits, coarser with the square of the distance: from 40 m the floor
## was striped by its own shadow, from 28 m faintly so at the far end of the
## patch, from 20 m not at all.
const AFAR := 18.0
## How far into the room such a light carries at the most, in metres from
## the door: the patch of a sun on the horizon would have no end.
const INSIDE := 18.0
## How far a ray is followed towards the sun or the sky, in metres.
const REACH := 150.0
## A light that does not fall off with distance still fades towards the end
## of its range. Within this share of its range it keeps nine tenths of its
## strength, so its range is made that much longer than the patch needs.
const FLAT := 0.45
## The least the sun has to shine into the doorway, as the cosine of the
## angle between its rays and the way in, to count as shining in.
const SLANT := 0.1
## The floors of these halls are dark, damp concrete: a tenth of what falls
## on them comes back, and a low sun lays its light thin on a floor. A sun
## that stands lower than this, as the sine of its height, is made stronger
## in the patch by as much as it loses on the floor that way, and by no more
## than SUN_MOST times. What stands upright in the patch gets that as well.
const SUN_LOW := 0.7
const SUN_MOST := 3.0
## The cone of the sun and of a lamp is this much wider than the doorway,
## and as good as even from side to side: the edge of the patch is the
## shadow of the doorway.
const WIDE := 1.15
const EVEN := 16.0
## The light of the sky: its colour, its strength under a sky at full
## brightness, how steeply it comes down in degrees, how much of it shows in
## the haze and how much softer than a lamp's the edge of its shadow is.
const SKY_TINT := Color(0.72, 0.82, 1.0)
const SKY_ENERGY := 5.0
const SKY_PITCH := 30.0
const SKY_HAZE := 0.4
const SKY_BLUR := 2.5
## It is aimed at the doorstep and fades away from there, towards the sides
## and into the room: a cone this much wider than the doorway, and how fast
## it fades towards its edge.
const SKY_WIDE := 1.25
const SKY_FADE := 1.0
## How far beyond the door a lamp may hang to be the one whose light comes
## out, in metres, and how far beyond the door the sky is looked up at.
const LAMP_NEAR := 10.0
const BEYOND := 1.0
## How much stronger than the lamp itself its light comes out of the
## doorway, which it reaches along the floor, and how far past the door it
## carries in metres.
const LAMP_GAIN := 8.0
const LAMP_CARRY := 12.0
## The share of the opening within which the light comes up to strength: a
## door that has only just left the floor lets in a sliver, not a flash.
const CRACK := 0.04
## What comes in from all of the doorway at once and so without a shadow:
## the sky and the lit ground beyond the door. One light in the middle of
## the doorway, this far beyond the door in metres, so that the wall the
## door is in gets none of it. How strong it is next to what stands beyond
## the door, by what that is, and how far it reaches in metres.
const BOUNCE_OUT := 0.4
const BOUNCE := {Source.SUN: 1.0, Source.SKY: 0.25, Source.LAMP: 0.5}
const BOUNCE_REACH := 9.0


## Rides on the door and says when it has moved.
class Rider:
	extends Node3D

	signal moved

	func _init() -> void:
		set_notify_transform(true)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSFORM_CHANGED:
			moved.emit()


## The door it follows; scripts/breakables.gd says which before this node is
## in the tree.
var door: Node3D
var source := Source.NONE
## How far up the door is, as a share of the way it goes: 0 is shut.
var opening := 0.0

var _beam: SpotLight3D
var _bounce: OmniLight3D
## The lamp beyond the door whose light this is, if it is that of a lamp.
var _lamp: Light3D
## The strength of the beam and of the bounce once the door is all the way up.
var _full := 0.0
var _thrown := 0.0
## Where the door hangs while it is shut, in the space of its parent, and how
## far up from there it goes.
var _shut := 0.0
var _rise := 0.0
## The doorway, as it lies in the level: its middle, the way in, the way
## across, and how wide and how high it is.
var _middle := Vector3.ZERO
var _front := Vector3.BACK
var _across := Vector3.RIGHT
var _size := Vector2.ONE


func _ready() -> void:
	add_to_group("daylight")
	# The door is shut now: the game opens it after the level is ready.
	_shut = door.position.y
	_rise = door.get_meta(&"rise", 0.0)
	_measure()
	var rider := Rider.new()
	rider.name = "DaylightRider"
	door.add_child(rider)
	rider.moved.connect(_follow)
	_light()


## Sets the lights to where the door is now.
func _follow() -> void:
	# To a thousandth of the way: a door that is put back down may end up a
	# hair from where it hung.
	opening = snappedf(clampf((door.position.y - _shut) / _rise, 0.0, 1.0), 0.001) if _rise > 0.0 else 0.0
	if _beam == null:
		return
	var lit := opening > 0.0 and (_lamp == null or _lamp.visible)
	_beam.visible = lit
	_bounce.visible = lit
	_beam.light_energy = _full * smoothstep(0.0, CRACK, opening)
	_bounce.light_energy = _thrown * opening


## Takes the measure of the doorway from the door that hangs in it: the box
## around whatever of the door is drawn, or around its collider.
func _measure() -> void:
	var inverse := door.global_transform.affine_inverse()
	var box := AABB()
	var any := false
	for part: GeometryInstance3D in door.find_children("*", "GeometryInstance3D", true, false):
		var around := inverse * part.global_transform * part.get_aabb()
		box = box.merge(around) if any else around
		any = true
	if not any:
		for collider: CollisionShape3D in door.find_children("*", "CollisionShape3D", true, false):
			var shape := collider.shape as BoxShape3D
			if shape:
				var around := inverse * collider.global_transform * AABB(shape.size * -0.5, shape.size)
				box = box.merge(around) if any else around
				any = true
	var front: Vector3 = door.get_meta(&"front", Vector3.BACK)
	var across := Vector3.UP.cross(front).normalized()
	_front = (door.global_basis * front).normalized()
	_across = (door.global_basis * across).normalized()
	_size = Vector2(absf(box.size.dot(across)), box.size.y)
	_middle = door.global_transform * (box.get_center() - front * box.get_center().dot(front))


## Finds out what lies beyond the door and makes the lights for it, once the
## colliders of the level are in the world.
func _light() -> void:
	for i in SETTLE:
		await get_tree().physics_frame
	if not is_inside_tree() or _size.x <= 0.0 or _size.y <= 0.0:
		return
	var scene := get_tree().current_scene
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, WORLD)
	if door is CollisionObject3D:
		ray.exclude = [(door as CollisionObject3D).get_rid()]

	var colour := Color.WHITE
	var haze := 0.0
	var specular := 1.0
	var blur := 1.0
	# How strong what lies beyond the door is at the doorway, and the colour
	# of what comes in from all of the doorway.
	var glow := 0.0
	var glow_colour := Color.WHITE
	# Where the light stands, what it is aimed at, and how its cone is cut.
	var from := Vector3.ZERO
	var aim := _middle
	var wide := WIDE
	var fade := EVEN
	var falloff := 0.0
	var carry := 0.0
	for sun: DirectionalLight3D in scene.find_children("*", "DirectionalLight3D", false, false):
		var travel := -sun.global_basis.z
		if source != Source.NONE or not sun.visible or travel.dot(_front) < SLANT or not _open_to(space, ray, -travel):
			continue
		source = Source.SUN
		colour = sun.light_color
		_full = sun.light_energy * clampf(SUN_LOW / maxf(-travel.y, 0.01), 1.0, SUN_MOST)
		glow = sun.light_energy
		# Half sun off the ground, half sky.
		glow_colour = colour.lerp(SKY_TINT, 0.5)
		# The sun itself lights the haze in the doorway: its shadow is drawn
		# with the door where it is.
		haze = 0.0
		from = aim - travel * AFAR
		carry = AFAR + minf(_size.y / maxf(-travel.y, 0.01), INSIDE)
	if source == Source.NONE and _under_sky(space, ray):
		source = Source.SKY
		var environment := get_world_3d().environment
		colour = SKY_TINT
		_full = SKY_ENERGY * (environment.background_energy_multiplier if environment else 1.0)
		glow = _full
		glow_colour = colour
		haze = SKY_HAZE
		blur = SKY_BLUR
		# Nothing in the sky is small enough to glint.
		specular = 0.0
		var down := deg_to_rad(SKY_PITCH)
		var travel := _front * cos(down) + Vector3.DOWN * sin(down)
		aim = _middle + Vector3.DOWN * _size.y * 0.5
		from = aim - travel * AFAR
		wide = SKY_WIDE
		fade = SKY_FADE
		carry = AFAR + minf(_size.y / sin(down), INSIDE)
	if source == Source.NONE:
		_lamp = _lamp_beyond(scene, space, ray)
		if _lamp:
			source = Source.LAMP
			colour = _lamp.light_color
			_full = _lamp.light_energy * LAMP_GAIN
			from = _lamp.global_position
			glow = _full / maxf(from.distance_to(aim), 1.0)
			glow_colour = colour
			haze = _lamp.light_volumetric_fog_energy
			falloff = 1.0
			carry = from.distance_to(aim) + LAMP_CARRY
			# Shot out, it takes what came through the doorway with it.
			_lamp.visibility_changed.connect(_follow)
	if source == Source.NONE:
		return

	# In a level that is cut into zones, whatever a zone holds is on the
	# layers of the zones. On the layers below those is what belongs to none:
	# the ground outside, the robots and the weapon in view. None of that has
	# a lightmap, so it stands in the light of the sun and the sky as it is.
	var zoned := door.get_parent().is_in_group("level_zone")
	var mask := ZONES.EVERY_LAYER & ~ZONES.COMMON_MASK if zoned else ZONES.EVERY_LAYER
	var along := from.direction_to(aim)

	_beam = SpotLight3D.new()
	_beam.name = "Beam"
	_beam.light_color = colour
	_beam.light_specular = specular
	_beam.light_volumetric_fog_energy = haze
	_beam.light_bake_mode = Light3D.BAKE_DISABLED
	_beam.light_cull_mask = mask
	_beam.shadow_enabled = true
	_beam.shadow_blur = blur
	# The floor is lit along itself: pushed off along its normal, as what a
	# shadow falls on is by default, it would be looked up above the beam.
	_beam.shadow_normal_bias = 0.0
	_beam.spot_angle = minf(_cone(from, along) * wide, 80.0)
	_beam.spot_angle_attenuation = fade
	_beam.spot_attenuation = falloff
	_beam.spot_range = carry if falloff > 0.0 else carry / FLAT
	_beam.visible = false
	add_child(_beam)
	_beam.global_transform = Transform3D(Fx.facing(along), from)

	_thrown = glow * BOUNCE[source]
	_bounce = OmniLight3D.new()
	_bounce.name = "Bounce"
	_bounce.light_color = glow_colour
	_bounce.light_specular = 0.0
	_bounce.light_volumetric_fog_energy = 0.0
	_bounce.light_bake_mode = Light3D.BAKE_DISABLED
	_bounce.light_cull_mask = mask
	_bounce.omni_range = BOUNCE_REACH
	_bounce.visible = false
	add_child(_bounce)
	_bounce.global_position = _middle - _front * BOUNCE_OUT

	# As scripts/zones.gd does for every lamp of the level: a light is known
	# to the renderer by a box, and that box being behind a wall says nothing
	# of what the light falls on.
	for light: Light3D in [_beam, _bounce]:
		RenderingServer.instance_geometry_set_flag(light.get_instance(), RenderingServer.INSTANCE_FLAG_IGNORE_OCCLUSION_CULLING, true)
	_follow()


## True if any of five places in the doorway has a free line along `towards`.
func _open_to(space: PhysicsDirectSpaceState3D, ray: PhysicsRayQueryParameters3D, towards: Vector3) -> bool:
	for place: Vector2 in [Vector2.ZERO, Vector2(-0.3, -0.3), Vector2(0.3, -0.3), Vector2(-0.3, 0.3), Vector2(0.3, 0.3)]:
		ray.from = _middle + _across * _size.x * place.x + Vector3.UP * _size.y * place.y
		ray.to = ray.from + towards * REACH
		if space.intersect_ray(ray).is_empty():
			return true
	return false


## True if there is sky to be seen from just beyond the door: straight up or
## up and away from it.
func _under_sky(space: PhysicsDirectSpaceState3D, ray: PhysicsRayQueryParameters3D) -> bool:
	ray.from = _middle - _front * BEYOND
	for towards: Vector3 in [Vector3.UP, (Vector3.UP - _front).normalized()]:
		ray.to = ray.from + towards * REACH
		if space.intersect_ray(ray).is_empty():
			return true
	return false


## The nearest lamp that hangs beyond the door and is lit, with nothing
## between it and the middle of the doorway.
func _lamp_beyond(scene: Node, space: PhysicsDirectSpaceState3D, ray: PhysicsRayQueryParameters3D) -> Light3D:
	var nearest: Light3D = null
	for lamp: Light3D in scene.find_children("*", "Light3D", true, false):
		var away := lamp.global_position - _middle
		if lamp is DirectionalLight3D or not lamp.visible or away.dot(_front) > -BEYOND or away.length() > LAMP_NEAR:
			continue
		if nearest and away.length() >= nearest.global_position.distance_to(_middle):
			continue
		ray.from = lamp.global_position
		ray.to = _middle
		if space.intersect_ray(ray).is_empty():
			nearest = lamp
	return nearest


## The angle in degrees between `along` and the corner of the doorway that
## lies furthest from it, seen from `from`.
func _cone(from: Vector3, along: Vector3) -> float:
	var widest := 0.0
	for corner: Vector2 in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
		var at := _middle + _across * _size.x * corner.x + Vector3.UP * _size.y * corner.y
		widest = maxf(widest, along.angle_to(at - from))
	return rad_to_deg(widest)
