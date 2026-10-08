extends Node3D
## Owns the player's loadout: firing, recoil, aim down sights, reloading,
## switching and the procedural viewmodel animation.

signal ammo_changed(weapon_name: String, mag: int, reserve: int)
signal hit_confirmed(headshot: bool, killed: bool)

const LOADOUT: Array[WeaponData] = [
	preload("res://weapons/rifle.tres"),
	preload("res://weapons/pistol.tres"),
	preload("res://weapons/shotgun.tres"),
]
const HIT_MASK := 0b101  # world + enemy
const SWITCH_TIME := 0.3
const FIRE_BUFFER := 0.12
const FLASH_TIME := 0.04

## 0 at the hip, 1 fully aimed down sights.
var ads_blend := 0.0

var _index := 0
var _pending := 0
var _models: Array[Node3D] = []
var _mags: Array[int] = []
var _reserves: Array[int] = []
var _cooldown := 0.0
var _fire_buffer := 0.0
var _since_shot := 10.0
var _reload_left := 0.0
var _switch_left := 0.0
var _bloom := 0.0
var _kick := 0.0
var _sway := Vector2.ZERO
var _bob_time := 0.0
var _sprint_blend := 0.0
var _flash := Node3D.new()
var _flash_left := 0.0

@onready var player: CharacterBody3D = owner
@onready var camera: Camera3D = get_parent()


func _ready() -> void:
	for data in LOADOUT:
		var model: Node3D = data.viewmodel.instantiate()
		model.visible = false
		for mesh in model.find_children("*", "MeshInstance3D"):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(model)
		_models.append(model)
		_mags.append(data.mag_size)
		_reserves.append(data.reserve_ammo)
	_models[_index].visible = true
	_build_flash()
	_emit_ammo.call_deferred()


func current() -> WeaponData:
	return LOADOUT[_index]


func ads_fov() -> float:
	return current().ads_fov


func move_speed_scale() -> float:
	return lerpf(1.0, current().ads_move_scale, ads_blend)


func blocks_sprint() -> bool:
	return ads_blend > 0.1 or _since_shot < 0.3


func reload_fraction() -> float:
	return 1.0 - _reload_left / current().reload_time if _reload_left > 0.0 else 0.0


func current_spread_deg() -> float:
	var data := current()
	var spread := lerpf(data.hip_spread_deg, data.ads_spread_deg, ads_blend) + _bloom
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	spread += data.move_spread_deg * minf(speed / 8.0, 1.5) * (1.0 - 0.7 * ads_blend)
	if not player.is_on_floor():
		spread += 2.0
	elif player.is_crouched() and not player.is_sliding():
		spread *= 0.7
	return spread


## Tops up reserve ammo for every weapon, e.g. between waves.
func refill() -> void:
	for i in LOADOUT.size():
		_reserves[i] = LOADOUT[i].reserve_ammo
	_emit_ammo()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and player.has_control():
		_sway = (_sway - event.relative * 0.00005).limit_length(0.025)


func _unhandled_input(event: InputEvent) -> void:
	if not player.has_control():
		return
	for i in LOADOUT.size():
		if event.is_action_pressed("weapon_%d" % (i + 1)):
			_switch_to(i)
	if event.is_action_pressed("weapon_next"):
		_switch_to((_pending + 1) % LOADOUT.size())
	elif event.is_action_pressed("weapon_prev"):
		_switch_to((_pending - 1 + LOADOUT.size()) % LOADOUT.size())


func _process(delta: float) -> void:
	var control: bool = player.has_control()
	_cooldown = maxf(_cooldown - delta, 0.0)
	_fire_buffer -= delta
	_since_shot += delta

	if _switch_left > 0.0:
		_switch_left -= delta
		if _pending != _index and _switch_left <= SWITCH_TIME * 0.5:
			_models[_index].visible = false
			_index = _pending
			_models[_index].visible = true
			_emit_ammo()
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()

	var data := current()
	var busy := _switch_left > 0.0 or _reload_left > 0.0
	var aiming := control and Input.is_action_pressed("ads") and not busy
	ads_blend = move_toward(ads_blend, 1.0 if aiming else 0.0, delta / data.ads_time)
	_bloom = move_toward(_bloom, 0.0, data.bloom_recovery_deg * delta)

	if control:
		if Input.is_action_just_pressed("fire"):
			_fire_buffer = FIRE_BUFFER
		var trigger := _fire_buffer > 0.0 or (data.automatic and Input.is_action_pressed("fire"))
		if trigger and not busy and _cooldown <= 0.0:
			if _mags[_index] > 0:
				_fire(data)
			elif _reserves[_index] > 0:
				_start_reload()
			elif _fire_buffer > 0.0:
				Sfx.play(&"dry_fire")
			_fire_buffer = 0.0
		if Input.is_action_just_pressed("reload"):
			_start_reload()

	_flash_left -= delta
	_flash.visible = _flash_left > 0.0
	_animate_viewmodel(data, delta)


func _fire(data: WeaponData) -> void:
	_mags[_index] -= 1
	_cooldown = 60.0 / data.rounds_per_minute
	_since_shot = 0.0

	var origin := camera.global_position
	var spread := tan(deg_to_rad(current_spread_deg()))
	var muzzle: Vector3 = _models[_index].get_node("Muzzle").global_position
	var space := get_world_3d().direct_space_state
	var any_hit := false
	var headshot := false
	var killed := false

	for i in data.pellets:
		var angle := randf() * TAU
		var radius := sqrt(randf()) * spread
		var direction := camera.global_basis * Vector3(cos(angle) * radius, sin(angle) * radius, -1.0)
		direction = direction.normalized()
		var end := origin + direction * data.max_range
		var query := PhysicsRayQueryParameters3D.create(origin, end, HIT_MASK, [player.get_rid()])
		var hit := space.intersect_ray(query)
		if hit:
			end = hit.position
			var target: Object = hit.collider
			if target.has_method("take_damage"):
				var distance := origin.distance_to(end)
				var falloff := remap(distance, data.falloff_start, data.falloff_end, 1.0, data.min_damage_scale)
				var amount := data.damage * clampf(falloff, data.min_damage_scale, 1.0)
				if target.has_method("is_headshot") and target.is_headshot(end):
					amount *= data.headshot_multiplier
					headshot = true
				any_hit = true
				killed = target.take_damage(amount, end, direction) or killed
			else:
				Fx.impact(end, hit.normal)
		Fx.tracer(muzzle, end)

	var recoil_scale := lerpf(1.0, data.ads_recoil_scale, ads_blend)
	player.add_recoil(
		deg_to_rad(data.recoil_pitch_deg) * recoil_scale * randf_range(0.85, 1.15),
		deg_to_rad(data.recoil_yaw_deg) * recoil_scale * randf_range(-1.0, 1.0)
	)
	_bloom = minf(_bloom + data.bloom_per_shot_deg, data.bloom_max_deg)
	_kick = 1.0
	_flash_left = FLASH_TIME
	_flash.global_position = muzzle
	_flash.rotation.z = randf() * TAU
	_flash.scale = Vector3.ONE * randf_range(0.8, 1.3)

	Sfx.play(data.shot_sound)
	if any_hit:
		Sfx.play(&"kill" if killed else (&"headshot" if headshot else &"hit"), -4.0)
		hit_confirmed.emit(headshot, killed)
	_emit_ammo()


func _start_reload() -> void:
	var data := current()
	if _reload_left > 0.0 or _switch_left > 0.0:
		return
	if _mags[_index] >= data.mag_size or _reserves[_index] <= 0:
		return
	_reload_left = data.reload_time
	Sfx.play(&"reload")


func _finish_reload() -> void:
	var needed := mini(current().mag_size - _mags[_index], _reserves[_index])
	_mags[_index] += needed
	_reserves[_index] -= needed
	_reload_left = 0.0
	Sfx.play(&"reload_end")
	_emit_ammo()


func _switch_to(index: int) -> void:
	if index == _pending:
		return
	_pending = index
	_reload_left = 0.0
	_switch_left = SWITCH_TIME
	Sfx.play(&"switch", -6.0)


func _emit_ammo() -> void:
	ammo_changed.emit(current().display_name, _mags[_index], _reserves[_index])


func _animate_viewmodel(data: WeaponData, delta: float) -> void:
	var model := _models[_index]
	var aim := smoothstep(0.0, 1.0, ads_blend)
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var grounded: bool = player.is_on_floor() and not player.is_sliding()

	_kick = lerpf(_kick, 0.0, 1.0 - exp(-16.0 * delta))
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-9.0 * delta))
	var sprinting: bool = player.is_sprinting() and speed > 5.5 and grounded
	_sprint_blend = lerpf(_sprint_blend, 1.0 if sprinting else 0.0, 1.0 - exp(-10.0 * delta))

	if grounded:
		_bob_time += delta * speed * 1.5
	var bob_size := 0.012 * minf(speed / 5.0, 1.6) * (1.0 - 0.9 * aim) * float(grounded)
	var bob := Vector3(cos(_bob_time * 0.5), -absf(sin(_bob_time * 0.5)), 0.0) * bob_size

	# The gun dips out of view while reloading or switching.
	var lower := 0.0
	if _switch_left > 0.0:
		lower = sin(PI * (1.0 - _switch_left / SWITCH_TIME))
	elif _reload_left > 0.0:
		lower = minf(sin(PI * reload_fraction()) * 2.5, 1.0)

	var offset := data.hip_offset.lerp(data.ads_offset, aim)
	offset += bob + Vector3(_sway.x, -_sway.y, 0.0) * (1.0 - 0.7 * aim)
	offset += Vector3(-0.05 * _sprint_blend, -0.22 * lower - 0.03 * _sprint_blend, _kick * data.kick_back)
	model.position = offset
	model.rotation = Vector3(
		_kick * data.kick_rotation * (1.0 - 0.5 * aim) - 0.9 * lower - 0.25 * _sprint_blend,
		_sway.x * 2.0 + 0.5 * _sprint_blend,
		_sway.x * 3.0
	)


func _build_flash() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.albedo_color = Color(3.0, 1.8, 0.6)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	mat.albedo_texture = texture
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.22
	quad.material = mat
	var sprite := MeshInstance3D.new()
	sprite.mesh = quad
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.add_child(sprite)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.4)
	light.light_energy = 2.5
	light.omni_range = 7.0
	_flash.add_child(light)
	_flash.visible = false
	add_child(_flash)
