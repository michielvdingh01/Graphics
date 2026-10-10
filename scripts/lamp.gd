extends StaticBody3D
## A lamp that can be shot out: a hanging hall lamp, a bulb in its cage, a
## fluorescent tube, a floodlight on a mast or the lamp over a machine.
## scripts/breakables.gd makes one when a level loads, around a light the
## level builder put there and the glass that glows by it, or around a hall
## lamp that was off already and has only its glass to lose.
##
## One hit puts it out, and so does a blast. Its glass comes down, the light
## stutters and is gone, and what glowed is dark from then on. Of a hall lamp
## that is its own model, whose glass is taken away and whose bulb stops
## glowing. Everywhere else the glow is a few triangles in a mesh the lamp
## shares with half the building, which cannot be switched off: those get a
## dark copy of themselves over them.
##
## Only what a lamp throws directly is gone with it. What it threw on the
## walls by way of other walls is baked into the lightmap and stays.
##
## It is in nobody's way: shots and blasts find it on a layer of its own, and
## nothing else does.

enum Kind { HALL, BULB, TUBE, FLOOD, WORK }

## Per kind: how large the glass is that comes down, 1 for a hall lamp, the
## sound of it and how loud that is in dB, and whether what is left of it
## goes on spitting sparks for a while.
const TUNING := {
	Kind.HALL: {"size": 1.0, "sound": &"lamp_break", "level": 0.0, "spits": true},
	Kind.BULB: {"size": 0.5, "sound": &"bulb_break", "level": -6.0, "spits": false},
	Kind.TUBE: {"size": 0.7, "sound": &"bulb_break", "level": -4.0, "spits": false},
	Kind.FLOOD: {"size": 1.0, "sound": &"lamp_break", "level": 0.0, "spits": true},
	Kind.WORK: {"size": 0.4, "sound": &"bulb_break", "level": -6.0, "spits": false},
}
## What breaking glass sounds like as long as there is no recording of it.
const STAND_IN := &"shield_break"
## Seconds the light stutters before it is gone.
const FLICKER := 0.25
## How many times a large lamp spits sparks after that, and within how many
## seconds.
const SPITS := 3
const SPIT_TIME := 3.5
## How far a collider reaches beyond the glass it is for, and the least it
## measures either way, in metres: glass that is a few centimetres across is
## no target.
const PAD := 0.03
const LEAST := 0.1
## How far the dark copy of a glowing part lies outside it, in metres.
const COVER := 0.004

## Mesh of a hall lamp -> the box around its glass, in the space of the mesh.
static var _glass := {}
## Material that glows -> its copy that does not.
static var _dark := {}
static var _nothing: StandardMaterial3D
static var _dead: StandardMaterial3D

var kind := Kind.HALL
## The light it gives; none for a lamp that was off already.
var light: Light3D
## The way its glass faces, which is the way it comes down.
var facing := Vector3.DOWN
var out := false

## The mesh of a hall lamp, which is all of its own.
var _model: MeshInstance3D
## The dark copies of what glows elsewhere, hidden until the lamp is out.
var _covers: Array[MeshInstance3D] = []
## The middle of each piece of glass, in the space of this body.
var _spots: Array[Vector3] = []


func _ready() -> void:
	add_to_group("breakable")


## Becomes the lamp that a hall lamp's model is, `mesh` being the mesh of
## that model. False if the model has no glass to break.
func hang(mesh: MeshInstance3D) -> bool:
	if not _glass.has(mesh.mesh):
		var around := AABB()
		var any := false
		for surface in mesh.mesh.get_surface_count():
			if not _is_glass(mesh.mesh.surface_get_material(surface)):
				continue
			for vertex: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				around = around.expand(vertex) if any else AABB(vertex, Vector3.ZERO)
				any = true
		_glass[mesh.mesh] = around
	var glass: AABB = global_transform.affine_inverse() * mesh.global_transform * (_glass[mesh.mesh] as AABB)
	if not glass.has_volume():
		return false
	_model = mesh
	var shape := CylinderShape3D.new()
	shape.radius = maxf(glass.size.x, glass.size.z) * 0.5 + PAD
	shape.height = glass.size.y + PAD * 2.0
	_collide(shape, glass.get_center())
	return true


## Takes a glowing part of the level for its glass: `points` are the corners
## of its triangles, three by three, in the space of this body. It gets a
## collider to be hit by and a dark copy of itself to go over it.
func lens(points: PackedVector3Array) -> void:
	var around := AABB(points[0], Vector3.ZERO)
	for point in points:
		around = around.expand(point)
	var shape := BoxShape3D.new()
	shape.size = (around.size + Vector3.ONE * PAD * 2.0).max(Vector3.ONE * LEAST)
	var middle := around.get_center()
	_collide(shape, middle)
	var swell := Vector3.ONE + Vector3.ONE * COVER * 2.0 / around.size.max(Vector3.ONE * COVER)
	var swollen := PackedVector3Array()
	for point in points:
		swollen.append(middle + (point - middle) * swell)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = swollen
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if _dead == null:
		_dead = StandardMaterial3D.new()
		_dead.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_dead.albedo_color = Color(0.04, 0.04, 0.045)
		_dead.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, _dead)
	var cover := MeshInstance3D.new()
	cover.mesh = mesh
	cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cover.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	cover.visible = false
	add_child(cover)
	_covers.append(cover)


## Becomes a lamp with no glass that could be found: something to hit where
## the light is, and nothing to go dark but the light.
func bare() -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * LEAST
	_collide(shape, Vector3.ZERO)


func take_damage(_amount: float, _at: Vector3, _direction: Vector3) -> bool:
	if not out:
		Net.show(self, &"_shatter")
	return false


func take_blast(_amount: float, _at: Vector3, _push: Vector3) -> void:
	if not out:
		Net.show(self, &"_shatter")


## Whether it is out, as a number: all there is to tell somebody who comes
## into the level later. See net_snapshot() in game.gd.
func net_state() -> int:
	return int(out)


## Is out as it was put out before whoever looks at it now was there: dark,
## and no more than that.
func net_restore(state: int) -> void:
	if state:
		_go_dark()
		if light:
			light.visible = false


## The glass goes, and with it the light: not at once but after a stutter,
## and from a large lamp a few more sparks come down afterwards.
func _shatter() -> void:
	var tuning: Dictionary = TUNING[kind]
	_go_dark()
	for spot in _spots:
		Fx.shatter(global_transform * spot, facing, tuning.size, light != null)
	Sfx.play_at(tuning.sound if Sfx.has(tuning.sound) else STAND_IN, global_transform * _spots[0], tuning.level)
	if light == null:
		return
	var full := light.light_energy
	var dying := create_tween()
	for share: float in [0.15, 0.9, 0.1, 0.55, 0.0]:
		dying.tween_property(light, "light_energy", full * share, FLICKER / 5.0)
	dying.tween_callback(light.hide)
	if tuning.spits:
		var after := create_tween()
		after.tween_interval(FLICKER)
		for i in SPITS:
			after.tween_interval(randf_range(0.2, 1.0) * SPIT_TIME / SPITS)
			after.tween_callback(Fx.spit.bind(global_transform * _spots[randi() % _spots.size()], facing))


## It is out from here on: nothing to hit, and nothing that glows.
func _go_dark() -> void:
	out = true
	collision_layer = 0
	for cover in _covers:
		cover.visible = true
	if _model == null:
		return
	for surface in _model.mesh.get_surface_count():
		var material := _model.mesh.surface_get_material(surface) as BaseMaterial3D
		if material == null:
			continue
		if _is_glass(material):
			# What is left of a surface when every pixel of it is cut away.
			if _nothing == null:
				_nothing = StandardMaterial3D.new()
				_nothing.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
				_nothing.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			_model.set_surface_override_material(surface, _nothing)
		elif material.emission_enabled:
			# The bulb under the glass, as the level builder makes it for a
			# lamp that is off.
			if not _dark.has(material):
				_dark[material] = material.duplicate()
				_dark[material].emission_enabled = false
			_model.set_surface_override_material(surface, _dark[material])


func _is_glass(material: Material) -> bool:
	return material != null and material.resource_name.ends_with("_glass")


## Adds a collider around a piece of glass that has its middle at `at`. A
## shot that lands on it rings and sparks as one on steel does.
func _collide(shape: Shape3D, at: Vector3) -> void:
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = at
	collider.set_meta(&"surface", "metal")
	add_child(collider)
	_spots.append(at)
