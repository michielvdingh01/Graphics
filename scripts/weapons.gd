extends Node3D
## Owns the player's loadout: firing, recoil, aim down sights, reloading,
## switching, throwing grenades and the animation of the weapon in view.
##
## A viewmodel is a scene built by tools/models/weapons.gd. Whatever moves on
## it is found by name, and a weapon without one of these simply skips that
## motion: the parts Mag, Slide or Bolt, Pump, ArmL and ArmR, and the markers
## Muzzle (required), Eject and MagHold.

signal ammo_changed(weapon_name: String, mag: int, reserve: int)
signal hit_confirmed(headshot: bool, killed: bool)
signal grenades_changed(count: int)

const LOADOUT: Array[WeaponData] = [
	preload("res://weapons/rifle.tres"),
	preload("res://weapons/pistol.tres"),
	preload("res://weapons/shotgun.tres"),
	preload("res://weapons/smg.tres"),
	preload("res://weapons/marksman.tres"),
]
const GRENADE := preload("res://scenes/grenade.tscn")
## The most grenades that are carried, and how many a level starts with.
const GRENADES := 3
const START_GRENADES := 2
## The reserve a weapon starts a level with, in magazines. What it can hold
## is in its data; the difference has to be picked up off the floor.
const START_MAGS := 2
## What a can of ammunition holds: this many magazines for the weapon in
## hand and for each of the others.
const CAN_MAGS := 1.0
const CAN_MAGS_OTHERS := 0.34
## A throw: how long the left hand is away from the weapon, the fraction of
## that after which the grenade leaves it, and the speed it leaves at in m/s.
const THROW_TIME := 0.55
const THROW_RELEASE := 0.4
const THROW_SPEED := 15.0
const HIT_MASK := 0b101  # world + enemy
const SWITCH_TIME := 0.3
const FIRE_BUFFER := 0.12
## A barrel smokes once it has been silent for this long, more the more shots
## went through it: the heat of a shot, and how much of it is lost per second.
const SMOKE_DELAY := 0.14
const SHOT_HEAT := 0.14
const COOLING := 0.35
## Field of view the weapon in hand is drawn with, whatever the view of the
## world is set to or zoomed to: narrower, so it sits large and undistorted.
const VIEWMODEL_FOV := 58.0
## Render layer of the weapon in view; the fill light reaches nothing else.
const VIEW_LAYER := 2
## How far ahead of the eye a wall starts to crowd the weapon.
const REACH := 0.9
## Seconds a slide or bolt takes to come back after a shot and to close again,
## and how far it travels.
const CYCLE_BACK := 0.03
const CYCLE_CLOSE := 0.06
const SLIDE_TRAVEL := 0.038
const BOLT_TRAVEL := 0.05
## Pump action: when the stroke starts after a shot, how long it takes and how
## far the forend comes back.
const PUMP_DELAY := 0.14
const PUMP_TIME := 0.42
const PUMP_TRAVEL := 0.075
## A magazine change, in fractions of the reload: when the magazine leaves,
## when the fresh one is home and when the bolt is let go.
const MAG_OUT := 0.14
const MAG_IN := 0.72
const BOLT_RELEASE := 0.88
const MAG_DROP := 0.32
## Loading one shell at a time: seconds before the first and after the last.
const SHELL_LEAD := 0.35
const SHELL_TAIL := 0.3


## The parts of one viewmodel that move, and where they rest.
class Viewmodel:
	var root: Node3D
	var muzzle: Node3D
	var eject: Node3D
	var mag: Node3D
	var action: Node3D
	var pump: Node3D
	var arm_l: Node3D
	var travel := BOLT_TRAVEL
	## A slide stays back on an empty magazine.
	var locks_open := false
	var mag_hold := Vector3.ZERO
	var rest := {}

	func _init(scene: Node3D) -> void:
		root = scene
		muzzle = scene.get_node("Muzzle")
		eject = scene.get_node_or_null("Eject")
		mag = scene.get_node_or_null("Mag")
		pump = scene.get_node_or_null("Pump")
		arm_l = scene.find_child("ArmL")
		action = scene.get_node_or_null("Slide")
		if action:
			travel = SLIDE_TRAVEL
			locks_open = true
		else:
			action = scene.get_node_or_null("Bolt")
		var hold: Node3D = scene.get_node_or_null("MagHold")
		if hold:
			mag_hold = hold.position
		for node: Node3D in [mag, action, pump, arm_l]:
			if node:
				rest[node] = node.transform


## 0 at the hip, 1 fully aimed down sights.
var ads_blend := 0.0
var grenades := START_GRENADES

var _index := 0
var _pending := 0
var _models: Array[Viewmodel] = []
## Holds the viewmodels and squeezes them into VIEWMODEL_FOV.
var _rig := Node3D.new()
var _mags: Array[int] = []
var _reserves: Array[int] = []
var _cooldown := 0.0
var _fire_buffer := 0.0
var _since_shot := 10.0
var _reload_left := 0.0
var _reload_total := 1.0
## How many of the moments of the current reload have been and gone.
var _reload_stage := 0
var _shells_to_load := 0
var _switch_left := 0.0
var _throw_left := 0.0
var _thrown := true
var _bloom := 0.0
var _kick := 0.0
var _sway := Vector2.ZERO
var _bob_time := 0.0
var _sprint_blend := 0.0
## 1 while the slide is held back on an empty magazine.
var _locked := 0.0
## 0 with room in front of the weapon, 1 with the player's nose against a wall.
var _crowded := 0.0
## Where the pump is in its stroke: 0 due, 1 on its way back, 2 done.
var _pump_stage := 2
## 0 for a cold barrel, 1 for one that has just emptied a magazine.
var _heat := 0.0
var _smoke_due := false

@onready var player: CharacterBody3D = owner
@onready var camera: Camera3D = get_parent()


func _ready() -> void:
	add_child(_rig)
	for data in LOADOUT:
		var model: Node3D = data.viewmodel.instantiate()
		model.visible = false
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D"):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.set_layer_mask_value(VIEW_LAYER, true)
		_rig.add_child(model)
		_models.append(Viewmodel.new(model))
		_mags.append(data.mag_size)
		_reserves.append(_start_reserve(data))
	_models[_index].root.visible = true
	_build_fill()
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
	return 1.0 - _reload_left / _reload_total if _reload_left > 0.0 else 0.0


## How far the picture through a telescopic sight has taken over from the
## weapon in view: 0 at the hip, 1 fully aimed. Halfway the view is black,
## which is when the weapon makes way; the HUD draws the rest.
func scope_blend() -> float:
	return smoothstep(0.6, 1.0, ads_blend) if current().scoped else 0.0


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


## Puts one weapon in view, `aim` of the way to the sights and `reload` of the
## way through reloading. For a screenshot: nothing else poses the weapon
## while the player stands still.
func preview(index: int, aim := 0.0, reload := 0.0) -> void:
	_models[_index].root.visible = false
	_index = index
	_pending = index
	_models[_index].root.visible = true
	ads_blend = aim
	camera.fov = lerpf(Settings.fov, current().ads_fov, smoothstep(0.0, 1.0, aim))
	if reload > 0.0:
		_mags[_index] = 0
		_start_reload()
		_reload_left = _reload_total * (1.0 - reload)
	_animate_viewmodel(current(), 0.0)


## Brings whatever has run low back up to what a level starts with: the
## reserve of every weapon and the grenades. What is over that is kept.
func resupply() -> void:
	for i in LOADOUT.size():
		_reserves[i] = maxi(_reserves[i], _start_reserve(LOADOUT[i]))
	grenades = maxi(grenades, START_GRENADES)
	grenades_changed.emit(grenades)
	_emit_ammo()


## Takes what a can of ammunition holds: most for the weapon in hand, some
## for the others. False if nothing of it fitted.
func add_ammo() -> bool:
	var took := false
	for i in LOADOUT.size():
		var data := LOADOUT[i]
		if data.bottomless:
			continue
		var rounds := ceili(data.mag_size * (CAN_MAGS if i == _pending else CAN_MAGS_OTHERS))
		var fits := mini(rounds, data.reserve_ammo - _reserves[i])
		if fits > 0:
			_reserves[i] += fits
			took = true
	if took:
		_emit_ammo()
	return took


## True if a can of ammunition would not be wasted: some weapon has room.
func ammo_room() -> bool:
	for i in LOADOUT.size():
		if not LOADOUT[i].bottomless and _reserves[i] < LOADOUT[i].reserve_ammo:
			return true
	return false


## One more grenade. False if no more can be carried.
func add_grenade() -> bool:
	if grenades >= GRENADES:
		return false
	grenades += 1
	grenades_changed.emit(grenades)
	return true


## How short of ammunition the weapon in hand is: 0 with the reserve a level
## starts with or more, 1 with none. One that never runs out is never short.
func ammo_lack() -> float:
	var data := LOADOUT[_pending]
	if data.bottomless:
		return 0.0
	return clampf(1.0 - float(_reserves[_pending]) / _start_reserve(data), 0.0, 1.0)


func _start_reserve(data: WeaponData) -> int:
	return mini(data.mag_size * START_MAGS, data.reserve_ammo)


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
			_models[_index].root.visible = false
			_index = _pending
			_models[_index].root.visible = true
			_since_shot = 10.0
			_pump_stage = 2
			_locked = 1.0 if _models[_index].locks_open and _mags[_index] == 0 else 0.0
			_emit_ammo()
	if _reload_left > 0.0:
		_reload_left -= delta
		_update_reload()
	if _throw_left > 0.0:
		_throw_left -= delta
		if not _thrown and _throw_left <= THROW_TIME * (1.0 - THROW_RELEASE):
			_release_grenade()

	var data := current()
	var busy := _switch_left > 0.0 or _reload_left > 0.0 or _throw_left > 0.0
	var aiming := control and Input.is_action_pressed("ads") and not busy
	ads_blend = move_toward(ads_blend, 1.0 if aiming else 0.0, delta / data.ads_time)
	_bloom = move_toward(_bloom, 0.0, data.bloom_recovery_deg * delta)

	if control:
		if Input.is_action_just_pressed("fire"):
			_fire_buffer = FIRE_BUFFER
		var trigger := _fire_buffer > 0.0 or (data.automatic and Input.is_action_pressed("fire"))
		# Shells go in one at a time, so there is something to fire before the last is in.
		if trigger and data.loads_singly and _reload_left > SHELL_TAIL and _mags[_index] > 0:
			_reload_left = SHELL_TAIL
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
		if Input.is_action_just_pressed("grenade"):
			_start_throw()

	_update_pump(data)
	_heat = maxf(_heat - COOLING * delta, 0.0)
	if _smoke_due and _since_shot > SMOKE_DELAY:
		_smoke_due = false
		smoke(_heat)
	_animate_viewmodel(data, delta)


func _fire(data: WeaponData) -> void:
	_mags[_index] -= 1
	_cooldown = 60.0 / data.rounds_per_minute
	_since_shot = 0.0

	var origin := camera.global_position
	var spread := tan(deg_to_rad(current_spread_deg()))
	var model := _models[_index]
	var muzzle := model.muzzle.global_position
	var space := get_world_3d().direct_space_state
	var any_hit := false
	var headshot := false
	var killed := false

	# A load of shot makes one sound per thing it lands on, not one per pellet.
	var struck := {}
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
			# An enemy shows a hit itself; anything else is part of the level,
			# even if it can be damaged, like a fuel barrel. Both sound like
			# what they are made of.
			var robot := target.has_method("is_headshot")
			var surface := Fx.surface_of(hit)
			if not robot:
				Fx.strike(hit.position, hit.normal, direction, surface, data.pellets > 1)
			if not struck.has(target):
				struck[target] = true
				Fx.thud(end, surface)
			if target.has_method("take_damage"):
				var distance := origin.distance_to(end)
				var falloff := remap(distance, data.falloff_start, data.falloff_end, 1.0, data.min_damage_scale)
				var amount := data.damage * clampf(falloff, data.min_damage_scale, 1.0)
				var head: bool = robot and target.is_headshot(end)
				if head:
					amount *= data.headshot_multiplier
				killed = target.take_damage(amount, end, direction) or killed
				# A shot that the plate on its arm stopped is no hit.
				if robot and not target.deflected:
					any_hit = true
					headshot = headshot or head
		# One pellet in three of a load of shot is enough to show where it went.
		if i % 3 == 0:
			Fx.tracer(muzzle, end)

	var recoil_scale := lerpf(1.0, data.ads_recoil_scale, ads_blend)
	player.add_recoil(
		deg_to_rad(data.recoil_pitch_deg) * recoil_scale * randf_range(0.85, 1.15),
		deg_to_rad(data.recoil_yaw_deg) * recoil_scale * randf_range(-1.0, 1.0)
	)
	_bloom = minf(_bloom + data.bloom_per_shot_deg, data.bloom_max_deg)
	_kick = 1.0
	flash()
	_heat = minf(_heat + SHOT_HEAT * (2.5 if data.pellets > 1 else 1.0), 1.0)
	_smoke_due = true
	if model.pump:
		_pump_stage = 0
	else:
		_eject(model, data)
	if model.locks_open and _mags[_index] == 0:
		_locked = 1.0

	Sfx.play(data.shot_sound)
	Save.tally("shots")
	if any_hit:
		Save.tally("hits")
		if headshot:
			Save.tally("headshots")
		Sfx.play(&"kill" if killed else (&"headshot" if headshot else &"hit"), -10.0)
		hit_confirmed.emit(headshot, killed)
	_emit_ammo()


## Where the shots of the weapon in hand leave it.
func muzzle_position() -> Vector3:
	return _models[_index].muzzle.global_position


## The flash at the muzzle of the weapon in hand. Over the sights it is
## smaller, so that it does not hide what is being shot at.
func flash() -> void:
	var data := current()
	Fx.muzzle_flash(_models[_index].muzzle, Transform3D(), data.flash_size * lerpf(1.0, 0.65, ads_blend), data.flash_prongs)


## The wisp of smoke the barrel leaves when it falls silent; `heat` is 1 after
## a long burst.
func smoke(heat: float) -> void:
	Fx.gun_smoke(muzzle_position(), Vector3.UP * 0.4 - camera.global_basis.z, heat)


## Throws the spent case out of the ejection port, to the right and a little up.
func _eject(model: Viewmodel, data: WeaponData) -> void:
	if model.eject == null:
		return
	var out := camera.global_basis * Vector3(randf_range(1.6, 2.4), randf_range(0.8, 1.5), randf_range(-0.2, 0.5))
	Fx.casing(model.eject.global_position, camera.global_basis, player.velocity + out, data.loads_singly)


## A pump action is worked by hand after every shot: back, which throws the
## shell out, and forward again.
func _update_pump(data: WeaponData) -> void:
	if _pump_stage > 1 or _since_shot < PUMP_DELAY:
		return
	if _pump_stage == 0:
		Sfx.play(&"reload", -5.0)
		_pump_stage = 1
	elif _since_shot > PUMP_DELAY + PUMP_TIME * 0.45:
		_eject(_models[_index], data)
		Sfx.play(&"reload_end", -5.0)
		_pump_stage = 2


func _start_reload() -> void:
	var data := current()
	if _reload_left > 0.0 or _switch_left > 0.0 or _throw_left > 0.0:
		return
	if _mags[_index] >= data.mag_size or _reserves[_index] <= 0:
		return
	_reload_stage = 0
	_reload_total = data.reload_time
	if data.loads_singly:
		_shells_to_load = mini(data.mag_size - _mags[_index], _reserves[_index])
		_reload_total = SHELL_LEAD + _shells_to_load * data.reload_time / data.mag_size + SHELL_TAIL
	_reload_left = _reload_total
	Sfx.play(&"switch", -8.0)


## Passes the moments of a reload as they come: the clicks, and the rounds
## that go in.
func _update_reload() -> void:
	var data := current()
	if data.loads_singly:
		var each := data.reload_time / data.mag_size
		var elapsed := _reload_total - _reload_left
		# A shell is in a little over halfway through its turn.
		while _reload_stage < _shells_to_load and _reload_left > SHELL_TAIL and elapsed > SHELL_LEAD + (_reload_stage + 0.55) * each:
			_reload_stage += 1
			_mags[_index] += 1
			if not data.bottomless:
				_reserves[_index] -= 1
			Sfx.play(&"reload", -3.0)
			_emit_ammo()
		if _reload_left <= 0.0:
			_reload_left = 0.0
			Sfx.play(&"reload_end")
		return

	var fraction := 1.0 - _reload_left / _reload_total
	var moments: Array[float] = [MAG_OUT, MAG_IN, BOLT_RELEASE]
	var sounds: Array[StringName] = [&"reload", &"reload_end", &"switch"]
	while _reload_stage < moments.size() and fraction >= moments[_reload_stage]:
		Sfx.play(sounds[_reload_stage], -2.0)
		_reload_stage += 1
	if _reload_left <= 0.0:
		var needed := mini(data.mag_size - _mags[_index], _reserves[_index])
		_mags[_index] += needed
		if not data.bottomless:
			_reserves[_index] -= needed
		_reload_left = 0.0
		_emit_ammo()


## The left hand lets go of the weapon, which breaks off a reload, and comes
## back once the grenade is on its way.
func _start_throw() -> void:
	if grenades <= 0 or _throw_left > 0.0 or _switch_left > 0.0:
		return
	_reload_left = 0.0
	_throw_left = THROW_TIME
	_thrown = false
	Sfx.play(&"pin", -4.0)


func _release_grenade() -> void:
	_thrown = true
	grenades -= 1
	grenades_changed.emit(grenades)
	var eye := camera.global_position
	var aim := camera.global_basis
	# It leaves from the left hand, unless there is a wall where that is.
	var from := eye + aim * Vector3(-0.22, -0.1, -0.45)
	var query := PhysicsRayQueryParameters3D.create(eye, eye + (from - eye) * 1.4, 1, [player.get_rid()])
	if get_world_3d().direct_space_state.intersect_ray(query):
		from = eye
	var grenade: RigidBody3D = GRENADE.instantiate()
	get_tree().current_scene.add_child(grenade)
	grenade.global_position = from
	grenade.linear_velocity = player.velocity + (aim.y * 0.18 - aim.z).normalized() * THROW_SPEED
	grenade.angular_velocity = aim * Vector3(-9.0, 0.0, randf_range(-3.0, 3.0))
	Sfx.play(&"throw", -6.0)


func _switch_to(index: int) -> void:
	if index == _pending:
		return
	_pending = index
	_reload_left = 0.0
	_switch_left = SWITCH_TIME
	Sfx.play(&"switch", -6.0)


## The reserve goes out as -1 for a weapon that never runs out.
func _emit_ammo() -> void:
	ammo_changed.emit(current().display_name, _mags[_index], -1 if current().bottomless else _reserves[_index])


func _animate_viewmodel(data: WeaponData, delta: float) -> void:
	var model := _models[_index]
	# Stretching the weapon sideways and upwards in front of the camera is the
	# same as looking at it through a narrower lens.
	var squeeze := tan(deg_to_rad(camera.fov) * 0.5) / tan(deg_to_rad(VIEWMODEL_FOV) * 0.5)
	_rig.scale = Vector3(squeeze, squeeze, 1.0)

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

	# The weapon dips out of view while it is being switched.
	var lower := sin(PI * (1.0 - _switch_left / SWITCH_TIME)) if _switch_left > 0.0 else 0.0
	var handling := _animate_parts(model, data, delta)
	# Held in one hand while the other throws, it sags and rolls outwards.
	var throw := sin(PI * (1.0 - _throw_left / THROW_TIME)) if _throw_left > 0.0 else 0.0
	handling[0] += Vector3(0.025, -0.045, 0.02) * throw
	handling[1] += Vector3(-0.12, -0.16, -0.22) * throw
	if model.arm_l:
		# The arm that throws swings down and back out of view, then forward.
		var swing := 1.0 - _throw_left / THROW_TIME if _throw_left > 0.0 else 0.0
		model.arm_l.position += Vector3(-0.1, -0.32, 0.25 - 0.3 * smoothstep(0.2, 0.6, swing)) * throw

	# Up against a wall it is drawn back with the muzzle up, instead of poking
	# through to the other side.
	var eye := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(eye, eye - camera.global_basis.z * REACH, 1, [player.get_rid()])
	var wall := get_world_3d().direct_space_state.intersect_ray(query)
	var room := eye.distance_to(wall.position) / REACH if wall else 1.0
	_crowded = lerpf(_crowded, 1.0 - smoothstep(0.3, 1.0, room), 1.0 - exp(-12.0 * delta))
	handling[0] += Vector3(-0.02, -0.07, 0.14) * _crowded
	handling[1] += Vector3(0.95, 0.25, 0.0) * _crowded

	var offset := data.hip_offset.lerp(data.ads_offset, aim)
	offset += bob + Vector3(_sway.x, -_sway.y, 0.0) * (1.0 - 0.7 * aim)
	offset += Vector3(-0.05 * _sprint_blend, -0.22 * lower - 0.03 * _sprint_blend, _kick * data.kick_back)
	model.root.position = offset + handling[0]
	model.root.rotation = data.hip_rotation_deg * (PI / 180.0) * (1.0 - aim) + handling[1] + Vector3(
		_kick * data.kick_rotation * (1.0 - 0.5 * aim) - 0.9 * lower - 0.25 * _sprint_blend,
		_sway.x * 2.0 + 0.5 * _sprint_blend,
		_sway.x * 3.0
	)
	# Through a telescopic sight the weapon is not seen at all.
	model.root.visible = scope_blend() < 0.5


## Moves whatever moves on the weapon itself: action, pump, magazine and the
## hand that works them. Returns how the weapon as a whole is held meanwhile,
## as [offset, rotation].
func _animate_parts(model: Viewmodel, data: WeaponData, delta: float) -> Array[Vector3]:
	for node: Node3D in model.rest:
		node.transform = model.rest[node]
	var offset := Vector3.ZERO
	var turn := Vector3.ZERO
	var fraction := reload_fraction()

	# The action snaps back with the shot and closes again, unless it is held open.
	if _mags[_index] > 0 or (_reload_left > 0.0 and fraction > BOLT_RELEASE):
		_locked = move_toward(_locked, 0.0, delta / CYCLE_CLOSE)
	var back := 0.0
	if _since_shot < CYCLE_BACK:
		back = _since_shot / CYCLE_BACK
	elif _since_shot < CYCLE_BACK + CYCLE_CLOSE:
		back = 1.0 - (_since_shot - CYCLE_BACK) / CYCLE_CLOSE
	if model.pump:
		var stroke := clampf((_since_shot - PUMP_DELAY) / PUMP_TIME, 0.0, 1.0)
		back = smoothstep(0.0, 0.4, stroke) * (1.0 - smoothstep(0.6, 1.0, stroke))
		model.pump.position.z += PUMP_TRAVEL * back
		# Working the pump pulls the muzzle down and lets it come back up.
		turn.x -= 0.05 * back
	if model.action:
		model.action.position.z += model.travel * maxf(back, _locked)

	if _reload_left <= 0.0:
		return [offset, turn]

	if data.loads_singly:
		# Rolled over, loading port up, while the hand goes to and fro with shells.
		var elapsed := _reload_total - _reload_left
		var rolled := smoothstep(0.0, SHELL_LEAD, elapsed) * (1.0 - smoothstep(_reload_total - SHELL_TAIL, _reload_total, elapsed))
		offset = Vector3(-0.03, 0.04, 0.02) * rolled
		turn += Vector3(0.3, 0.1, -0.8) * rolled
		if model.arm_l:
			var turn_at := fposmod((elapsed - SHELL_LEAD) / (data.reload_time / data.mag_size), 1.0)
			var at_port := smoothstep(0.1, 0.5, turn_at) * (1.0 - smoothstep(0.7, 1.0, turn_at))
			var port: Vector3 = (model.arm_l.get_parent() as Node3D).transform.affine_inverse() * model.mag_hold
			var away := port + Vector3(-0.1, -0.2, 0.12)
			model.arm_l.position = model.arm_l.position.lerp(away.lerp(port, at_port), rolled)
		return [offset, turn]

	# Canted with the magazine well towards the hand that changes it.
	var held := smoothstep(0.0, MAG_OUT, fraction) * (1.0 - smoothstep(BOLT_RELEASE - 0.04, 1.0, fraction))
	offset = Vector3(-0.03, 0.035, 0.03) * held
	turn += Vector3(0.22, 0.12, -0.5) * held
	# Seating the fresh magazine knocks the weapon up a little.
	offset.y += 0.012 * maxf(0.0, 1.0 - absf(fraction - MAG_IN) / 0.04)
	var out := smoothstep(MAG_OUT, MAG_OUT + 0.16, fraction) * (1.0 - smoothstep(MAG_IN - 0.2, MAG_IN, fraction))
	if model.mag:
		var drop: Vector3 = model.mag.transform.basis.y * -MAG_DROP * out
		model.mag.position += drop
		if model.arm_l:
			var reach := smoothstep(0.03, MAG_OUT, fraction) * (1.0 - smoothstep(MAG_IN + 0.05, BOLT_RELEASE + 0.06, fraction))
			model.arm_l.position = model.arm_l.position.lerp(model.mag_hold, reach) + drop
	return [offset, turn]


## A dim light over the left shoulder that reaches only the weapon in view, so
## that it keeps its shape where the level leaves it in the dark.
func _build_fill() -> void:
	var fill := OmniLight3D.new()
	fill.name = "Fill"
	fill.position = Vector3(-0.45, 0.5, 0.25)
	fill.omni_range = 2.5
	fill.omni_attenuation = 0.6
	fill.light_color = Color(0.85, 0.9, 1.0)
	fill.light_energy = 1.1
	fill.light_cull_mask = 1 << (VIEW_LAYER - 1)
	fill.light_volumetric_fog_energy = 0.0
	fill.light_bake_mode = Light3D.BAKE_DISABLED
	add_child(fill)
