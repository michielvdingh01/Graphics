extends Node3D
## A weapon from the arena on its stand: a weapon of scripts/armory.gd with
## `special`, which no pack carries. It turns slowly over a low plinth, in a
## warm light, for whoever walks up to it, and is taken up with what it holds
## and nothing more.
##
## Taken, the stand stays empty while the weapon is carried. Once it is fired
## empty or lost, release() starts the clock, and a count over the stand says
## when it is back. Whoever goes down with it leaves it where they fell: a
## second one of these, `dropped`, with what was left in it, that lies there
## for LIES seconds and then lets its stand know. scripts/match.gd sets them
## out and keeps them going.

## Somebody took it up; `dropped` is what they carried before and let go of,
## [weapon, rounds] or [].
signal taken(by: Node3D, dropped: Array)
## It is there to be taken: on its stand, not when it was dropped.
signal arrived

const ARMORY := preload("res://scripts/armory.gd")
## It is taken from this close, in metres to the side and up.
const TAKE := 1.2
const TAKE_UP := 1.6
## Seconds a weapon that was dropped lies where it fell.
const LIES := 20.0
## Seconds its name is seen through walls once it is there.
const TOLD := 5.0
## How far a count over an empty stand is seen, in metres.
const COUNT_SEEN := 45.0
const HOVER := 1.0
const TURN := 0.6
const TINT := Color(1.0, 0.62, 0.3)
const PLINTH := preload("res://materials/steel.tres")

var weapon: WeaponData
## What it holds when it is taken: in full on its stand.
var rounds := 0
var dropped := false
## For one that was dropped, the stand it belongs to, and the seconds after it
## is gone that the stand has it there again.
var stand: Node3D
var back := 90.0

## Seconds until it is there; 0 while it is, and INF while it is carried.
var _due := 0.0
var _age := 0.0
var _told := 0.0
var _model: Node3D
var _label := Label3D.new()
var _light := OmniLight3D.new()


func _ready() -> void:
	add_to_group("stash")
	var held := "res://scenes/models/%s_held.scn" % weapon.resource_path.get_file().get_basename()
	if ResourceLoader.exists(held):
		_model = (load(held) as PackedScene).instantiate()
	else:
		_model = weapon.viewmodel.instantiate()
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D"):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_model)
	_model.position.y = HOVER if not dropped else 0.35
	if not dropped:
		var plinth := MeshInstance3D.new()
		var shape := CylinderMesh.new()
		shape.top_radius = 0.42
		shape.bottom_radius = 0.48
		shape.height = 0.14
		shape.radial_segments = 8
		shape.rings = 1
		plinth.mesh = shape
		plinth.material_override = PLINTH
		plinth.position.y = 0.07
		add_child(plinth)
		var rim := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.4
		ring.outer_radius = 0.43
		ring.rings = 24
		ring.ring_segments = 6
		rim.mesh = ring
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = TINT
		rim.material_override = glow
		rim.position.y = 0.145
		add_child(rim)
	_light.light_color = TINT
	_light.light_energy = 0.6
	_light.omni_range = 2.2
	_light.omni_attenuation = 1.2
	_light.light_bake_mode = Light3D.BAKE_DISABLED
	_light.light_volumetric_fog_energy = 0.0
	_light.position.y = HOVER
	add_child(_light)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.003
	_label.font_size = 44
	_label.outline_size = 10
	_label.modulate = TINT
	_label.position.y = HOVER + 0.75
	_label.visibility_range_end = COUNT_SEEN
	add_child(_label)
	if rounds <= 0:
		rounds = weapon.mag_size + weapon.reserve_ammo
	_show(_due <= 0.0)


## Has it there in `seconds`; at once with 0.
func come_in(seconds: float) -> void:
	_due = seconds
	_show(_due <= 0.0)
	if _due <= 0.0:
		_arrive()


## The weapon that was taken from here is fired empty or lost: it is back in
## `seconds`.
func release(seconds: float) -> void:
	come_in(seconds)


func is_up() -> bool:
	return _due <= 0.0


## Seconds until it is there, 0 if it is and INF while somebody carries it.
func due() -> float:
	return _due


func _physics_process(delta: float) -> void:
	if dropped:
		_age += delta
		visible = _age < LIES - 4.0 or fmod(_age * 3.0, 1.0) < 0.65
		if _age >= LIES:
			if is_instance_valid(stand):
				stand.release(back)
			queue_free()
			return
	if _due > 0.0 and _due < INF:
		_due -= delta
		var left := int(ceilf(_due))
		@warning_ignore("integer_division")
		_label.text = "%s  %d:%02d" % [weapon.display_name.to_upper(), left / 60, left % 60]
		if _due <= 0.0:
			_due = 0.0
			_show(true)
			_arrive()
		return
	if _due > 0.0:
		return
	_model.rotation.y += delta * TURN
	_model.position.y = (HOVER if not dropped else 0.35) + sin(Time.get_ticks_msec() * 0.0015) * 0.03
	if _told > 0.0:
		_told -= delta
		if _told <= 0.0:
			_label.no_depth_test = false
			_label.visibility_range_end = COUNT_SEEN
	for body in _takers():
		var to: Vector3 = body.global_position - global_position
		if Vector2(to.x, to.z).length() < TAKE and absf(to.y) < TAKE_UP:
			_take(body)
			return


## Who can take it: the player, while alive. Bots leave it lying for now.
func _takers() -> Array[Node3D]:
	var found: Array[Node3D] = []
	for player: Node3D in get_tree().get_nodes_in_group("player"):
		if not player.dead and player.has_method("has_control") and player.has_control():
			found.append(player)
	return found


func _take(body: Node3D) -> void:
	var before: Array = body.weapons.take_special(weapon, rounds)
	Sfx.play(&"pickup_ammo", -4.0)
	if dropped:
		taken.emit(body, before)
		queue_free()
		return
	_due = INF
	_show(false)
	taken.emit(body, before)


func _arrive() -> void:
	# Everybody is told, and sees its name through the walls for a moment.
	_told = TOLD
	_label.no_depth_test = true
	_label.visibility_range_end = 0.0
	arrived.emit()


func _show(there: bool) -> void:
	_model.visible = there
	_light.visible = there
	_label.visible = there or (_due < INF and not dropped)
	_label.text = weapon.display_name.to_upper()
