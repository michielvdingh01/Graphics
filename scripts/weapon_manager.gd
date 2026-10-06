class_name WeaponManager
extends Node3D
## Owns the player's weapons: input, hitscan firing, spread, recoil, ADS, reload, switching and
## the procedural viewmodel animation. Lives under the player camera.

signal ammo_changed(mag: int, reserve: int, weapon_name: String)
signal hit_confirmed(kind: String)
signal fired

enum State { READY, RELOADING, LOWERING, RAISING }

const WEAPON_PATHS: Array[String] = [
	"res://data/weapons/rifle.tres",
	"res://data/weapons/pistol.tres",
	"res://data/weapons/shotgun.tres",
]
## World (1) + enemy (4).
const HIT_MASK := 1 | 4
const MAX_RECOIL_PITCH := 14.0
const WALL_PROBE_LENGTH := 0.75

var current: WeaponData
var ads_t := 0.0
var spread_deg := 0.0
## Camera offset in radians (pitch, yaw) that the player applies on top of the aim.
var recoil_offset := Vector2.ZERO

var _player: CharacterBody3D
var _camera: Camera3D
var _holder: Node3D
var _weapons: Array[WeaponData] = []
var _viewmodels: Array[Node3D] = []
var _mag: Array[int] = []
var _reserve: Array[int] = []
var _index := 0
var _pending_index := 0
var _state := State.READY
var _state_t := 0.0
var _state_len := 1.0
var _reload_in_played := false
var _cooldown := 0.0
var _since_shot := 99.0
var _bloom := 0.0
var _recoil_target := Vector2.ZERO
var _kick := 0.0
var _kick_rot := 0.0
var _sway := Vector2.ZERO
var _wall_push := 0.0
var _flash_t := 0.0
var _pump_t := 1.0
var _dry_clicked := false
var _rng := RandomNumberGenerator.new()
var _muzzle: Marker3D
var _flash: MeshInstance3D
var _flash_light: OmniLight3D


func _ready() -> void:
	_rng.randomize()
	_camera = get_parent() as Camera3D
	var node: Node = self
	while node and not node is CharacterBody3D:
		node = node.get_parent()
	_player = node as CharacterBody3D

	_holder = Node3D.new()
	_holder.name = "Holder"
	add_child(_holder)
	for path in WEAPON_PATHS:
		var data := load(path) as WeaponData
		_weapons.append(data)
		_mag.append(data.mag_size)
		_reserve.append(data.reserve_ammo)
		var vm: Node3D
		if data.viewmodel_scene:
			vm = data.viewmodel_scene.instantiate() as Node3D
		else:
			vm = PlaceholderViewmodels.build(data.placeholder_style)
		vm.visible = false
		_holder.add_child(vm)
		_viewmodels.append(vm)
	_activate(0)


## Called by the player with raw mouse motion so the weapon can lag behind the view.
func add_look(relative: Vector2) -> void:
	_sway += relative


## Replenish reserve ammo, e.g. as a reward for a kill.
func restock(fraction: float) -> void:
	for i in _weapons.size():
		var cap := _weapons[i].reserve_ammo * 2
		_reserve[i] = mini(_reserve[i] + ceili(_weapons[i].mag_size * fraction), cap)
	_emit_ammo()


func reset_loadout() -> void:
	for i in _weapons.size():
		_mag[i] = _weapons[i].mag_size
		_reserve[i] = _weapons[i].reserve_ammo
	_state = State.READY
	_activate(0)


func refresh() -> void:
	_emit_ammo()


func is_reloading() -> bool:
	return _state == State.RELOADING


func _process(delta: float) -> void:
	if not _player:
		return
	var live: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _player.get("dead")
	_cooldown = maxf(_cooldown - delta, 0.0)
	_since_shot += delta
	_update_state(delta, live)
	if live:
		_handle_input()
	_update_ads(delta, live)
	_update_recoil(delta)
	_update_spread(delta)
	_update_viewmodel(delta)


func _handle_input() -> void:
	if Input.is_action_just_pressed("weapon_1"):
		_request_switch(0)
	elif Input.is_action_just_pressed("weapon_2"):
		_request_switch(1)
	elif Input.is_action_just_pressed("weapon_3"):
		_request_switch(2)
	elif Input.is_action_just_pressed("weapon_next"):
		_request_switch((_index + 1) % _weapons.size())
	elif Input.is_action_just_pressed("weapon_prev"):
		_request_switch((_index - 1 + _weapons.size()) % _weapons.size())

	if Input.is_action_just_pressed("reload"):
		_start_reload()

	var wants_fire := (
		Input.is_action_pressed("fire") if current.automatic else Input.is_action_just_pressed("fire")
	)
	if Input.is_action_just_released("fire"):
		_dry_clicked = false
	if wants_fire:
		_try_fire()


func _try_fire() -> void:
	if _state != State.READY or _cooldown > 0.0 or _player.get("sprint_t") > 0.6:
		return
	if _mag[_index] <= 0:
		if not _dry_clicked:
			_dry_clicked = true
			Sfx.play("dry_fire", -4.0)
		_start_reload()
		return
	_fire()


func _fire() -> void:
	var w := current
	_mag[_index] -= 1
	_cooldown = w.shot_interval()
	_since_shot = 0.0
	_emit_ammo()
	fired.emit()

	var origin := _camera.global_position
	var aim_basis := _camera.global_basis
	var space := _camera.get_world_3d().direct_space_state
	var exclude: Array[RID] = [_player.get_rid()]
	var muzzle_pos := _muzzle.global_position
	var result := ""
	var tracer_every := 1 if w.pellets <= 3 else 3

	for i in w.pellets:
		var dir := _spread_direction(aim_basis, spread_deg)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * w.max_range, HIT_MASK, exclude)
		var hit := space.intersect_ray(query)
		var end: Vector3 = hit.position if not hit.is_empty() else origin + dir * w.max_range
		if i % tracer_every == 0:
			Effects.tracer(muzzle_pos, end, w.tracer_color)
		if not hit.is_empty():
			result = _worse_result(result, _apply_hit(hit, dir, w, origin.distance_to(end)))

	if result != "":
		hit_confirmed.emit(result)
		if result == "kill":
			restock(0.35)

	Sfx.play("shot_" + w.id, 0.0, 1.0)
	var rscale := lerpf(1.0, w.ads_recoil_scale, ads_t)
	_recoil_target.x = minf(_recoil_target.x + w.recoil_pitch * rscale * _rng.randf_range(0.85, 1.15), MAX_RECOIL_PITCH)
	_recoil_target.y += _rng.randf_range(-1.0, 1.0) * w.recoil_yaw * rscale
	_kick = minf(_kick + w.kick_back, w.kick_back * 3.0)
	_kick_rot = minf(_kick_rot + w.kick_rotation, w.kick_rotation * 3.0)
	_bloom = minf(_bloom + w.bloom_per_shot, w.bloom_max)
	_flash_t = 0.045
	_pump_t = 0.0
	if _flash:
		_flash.rotation.z = _rng.randf() * TAU
		_flash.scale = Vector3.ONE * _rng.randf_range(0.8, 1.3)


## Returns "", "hit", "head" or "kill".
func _apply_hit(hit: Dictionary, dir: Vector3, w: WeaponData, distance: float) -> String:
	var collider: Object = hit.collider
	if collider and collider.has_method("take_damage"):
		var head_y: float = collider.global_position.y + collider.get("head_height")
		var is_head: bool = hit.position.y > head_y
		var falloff := lerpf(1.0, 0.55, clampf((distance - w.max_range * 0.3) / (w.max_range * 0.7), 0.0, 1.0))
		var damage := w.damage * falloff * (w.headshot_multiplier if is_head else 1.0)
		var killed: bool = collider.take_damage(damage, hit.position, dir, is_head)
		Effects.flesh_impact(hit.position, hit.normal)
		if killed:
			return "kill"
		return "head" if is_head else "hit"
	Effects.world_impact(hit.position, hit.normal)
	Sfx.play_at("impact", hit.position, -8.0)
	return ""


func _worse_result(a: String, b: String) -> String:
	var rank := {"": 0, "hit": 1, "head": 2, "kill": 3}
	return a if rank[a] >= rank[b] else b


func _spread_direction(aim_basis: Basis, degrees: float) -> Vector3:
	var radius := tan(deg_to_rad(degrees)) * sqrt(_rng.randf())
	var angle := _rng.randf() * TAU
	var local := Vector3(cos(angle) * radius, sin(angle) * radius, -1.0)
	return (aim_basis * local).normalized()


func _start_reload() -> void:
	if _state != State.READY:
		return
	if _mag[_index] >= current.mag_size or _reserve[_index] <= 0:
		return
	_state = State.RELOADING
	_state_t = 0.0
	_state_len = current.reload_time
	_reload_in_played = false
	Sfx.play("reload_out", -3.0)


func _request_switch(index: int) -> void:
	if index == _index or _state == State.LOWERING or _state == State.RAISING:
		return
	_pending_index = index
	_state = State.LOWERING
	_state_t = 0.0
	_state_len = current.equip_time * 0.4


func _update_state(delta: float, _live: bool) -> void:
	if _state == State.READY:
		return
	_state_t += delta
	match _state:
		State.RELOADING:
			if not _reload_in_played and _state_t > _state_len * 0.72:
				_reload_in_played = true
				Sfx.play("reload_in", -3.0)
			if _state_t >= _state_len:
				var take := mini(current.mag_size - _mag[_index], _reserve[_index])
				_mag[_index] += take
				_reserve[_index] -= take
				_state = State.READY
				_emit_ammo()
		State.LOWERING:
			if _state_t >= _state_len:
				_activate(_pending_index)
				_state = State.RAISING
				_state_t = 0.0
				_state_len = current.equip_time * 0.6
				Sfx.play("equip", -6.0)
		State.RAISING:
			if _state_t >= _state_len:
				_state = State.READY


func _activate(index: int) -> void:
	_index = index
	current = _weapons[index]
	for i in _viewmodels.size():
		_viewmodels[i].visible = i == index
	var vm := _viewmodels[index]
	_muzzle = vm.get_node("Muzzle") as Marker3D
	_flash = _muzzle.get_node("Flash") as MeshInstance3D
	_flash_light = _muzzle.get_node("FlashLight") as OmniLight3D
	_flash.visible = false
	_flash_light.light_energy = 0.0
	_pump_t = 1.0
	_bloom = 0.0
	_emit_ammo()


func _update_ads(delta: float, live: bool) -> void:
	var sprinting: bool = _player.get("sprint_t") > 0.3
	var want := live and Input.is_action_pressed("ads") and _state == State.READY and not sprinting
	ads_t = move_toward(ads_t, 1.0 if want else 0.0, delta / maxf(current.ads_time, 0.05))


func _update_recoil(delta: float) -> void:
	# Hold the kick while firing, then pull the view back to the original aim.
	if _since_shot > current.shot_interval() * 1.6:
		_recoil_target = _recoil_target.lerp(Vector2.ZERO, 1.0 - exp(-current.recoil_recovery * delta))
	var follow := 1.0 - exp(-36.0 * delta)
	recoil_offset = recoil_offset.lerp(
		Vector2(deg_to_rad(_recoil_target.x), deg_to_rad(_recoil_target.y)), follow
	)
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-14.0 * delta))
	_kick_rot = lerpf(_kick_rot, 0.0, 1.0 - exp(-12.0 * delta))


func _update_spread(delta: float) -> void:
	_bloom = maxf(_bloom - current.bloom_recovery * delta, 0.0)
	var speed: float = _player.get("speed_h")
	var moving := clampf(speed / 8.0, 0.0, 1.0)
	var airborne: float = 0.0 if _player.is_on_floor() else 1.0
	var base := lerpf(current.spread_hip, current.spread_ads, ads_t)
	var penalty := current.spread_move * (moving + airborne) * (1.0 - ads_t * 0.7)
	spread_deg = base + penalty + _bloom


func _update_viewmodel(delta: float) -> void:
	var w := current
	var ads_s := smoothstep(0.0, 1.0, ads_t)
	var pos := w.hip_offset.lerp(w.ads_offset, ads_s)
	var rot := Vector3.ZERO

	# Walk bob and sprint pose come from the player.
	var bob: Vector2 = _player.get("bob")
	var sprint_t: float = _player.get("sprint_t")
	var bob_scale := 1.0 - ads_s * 0.85
	pos += Vector3(bob.x * 0.6, bob.y * 0.7, 0.0) * bob_scale
	pos += Vector3(-0.07, -0.05, 0.02) * sprint_t
	rot += Vector3(-6.0, 22.0, 6.0) * sprint_t

	# Mouse sway: the weapon lags slightly behind the camera.
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-10.0 * delta))
	var sway_scale := 1.0 - ads_s * 0.7
	rot.y += clampf(-_sway.x * 0.045, -4.0, 4.0) * sway_scale
	rot.x += clampf(-_sway.y * 0.045, -4.0, 4.0) * sway_scale

	# Recoil kick.
	pos.z += _kick
	rot.x += _kick_rot

	# Equip and reload animations.
	var lower := 0.0
	match _state:
		State.LOWERING:
			lower = smoothstep(0.0, 1.0, _state_t / _state_len)
		State.RAISING:
			lower = 1.0 - smoothstep(0.0, 1.0, _state_t / _state_len)
		State.RELOADING:
			var r := clampf(_state_t / _state_len, 0.0, 1.0)
			var dip := sin(r * PI)
			pos.y -= 0.1 * dip
			pos.x -= 0.03 * dip
			rot += Vector3(-18.0, 8.0, -28.0) * dip
			# A little shake when the magazine seats.
			rot.x += sin(r * 40.0) * 1.2 * smoothstep(0.65, 0.75, r) * (1.0 - smoothstep(0.75, 0.9, r))
	pos.y -= 0.22 * lower
	rot.x -= 35.0 * lower

	# Keep the barrel out of walls.
	var wall := _probe_wall()
	_wall_push = lerpf(_wall_push, wall, 1.0 - exp(-18.0 * delta))
	pos.z += _wall_push * 0.55
	rot.x += _wall_push * 55.0

	_holder.position = pos
	_holder.rotation_degrees = rot
	_animate_pump(delta)
	_animate_flash(delta)


func _probe_wall() -> float:
	var origin := _camera.global_position
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin - _camera.global_basis.z * WALL_PROBE_LENGTH, 1, [_player.get_rid()]
	)
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 0.0
	return clampf(1.0 - origin.distance_to(hit.position) / WALL_PROBE_LENGTH, 0.0, 1.0) * 0.5


func _animate_pump(delta: float) -> void:
	var vm := _viewmodels[_index]
	if not vm.has_node("Pump"):
		return
	_pump_t = minf(_pump_t + delta / 0.55, 1.0)
	# Slide the forend back and forward after a shot, once the recoil has settled.
	var phase := clampf((_pump_t - 0.25) / 0.6, 0.0, 1.0)
	vm.get_node("Pump").position.z = -0.28 + sin(phase * PI) * 0.11


func _animate_flash(delta: float) -> void:
	_flash_t = maxf(_flash_t - delta, 0.0)
	var on := _flash_t > 0.0
	_flash.visible = on
	_flash_light.light_energy = current.muzzle_energy * (_flash_t / 0.045) if on else 0.0


func _emit_ammo() -> void:
	ammo_changed.emit(_mag[_index], _reserve[_index], current.display_name)
