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
const SPRING := preload("res://scripts/spring.gd")
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
const HIT_MASK := 0b100101  # world + enemy + breakable
const SWITCH_TIME := 0.3
const FIRE_BUFFER := 0.12
## With nothing left to fire, the trigger swings the weapon instead: how long
## that takes, the fraction of it after which the blow lands, how far it
## reaches from the eye and what it does.
const MELEE_TIME := 0.5
const MELEE_LANDS := 0.34
const MELEE_REACH := 2.1
const MELEE_DAMAGE := 60.0
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
## How far beyond the eye the lights on the weapon in view reach: no further
## than the weapon, so that the level around it does not have to look them up.
const REACH_OF_LIGHT := 1.0
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

# How the weapon in view moves in the hands of whoever carries it. All of it
# is only drawn: none of it changes where a shot goes.

## A shot kicks the weapon back on a spring: the seconds after the shot at
## which it is furthest back, and how much of its swing it loses, so that it
## comes forward a little past where it was held before it settles. By chance
## it also rolls and shifts sideways, at most this many radians and metres,
## so that no two shots look alike. Over the sights it kicks KICK_AIMED as
## far, which is about what was ever drawn of it there before it was a spring:
## the sights should jump no further off what they are held on than they did.
const KICK_TIME := 0.025
const KICK_DAMPING := 0.6
const KICK_ROLL := 0.015
const KICK_SHIFT := 0.003
const KICK_AIMED := 0.75
## Shot after shot the muzzle climbs: by this share of the weapon's
## kick_rotation for each, up to CLIMB_MAX of it. It stays up while the shots
## keep coming, which is for CLIMB_HOLD seconds after the last, and then comes
## down at CLIMB_BLEED per second: a quarter of a second and it is gone.
const CLIMB_STEP := 0.085
const CLIMB_MAX := 0.5
const CLIMB_HOLD := 0.11
const CLIMB_BLEED := 14.0
## A shot widens the field of view for a moment, by this many degrees for
## every degree it kicks the aim up, see Player.punch_fov(). A weapon that
## kicks it up by HEAVY_RECOIL degrees or more, the shotgun and the marksman
## rifle, rattles the view as well, by this much, see Player.shake().
const SHOT_FOV := 0.35
const HEAVY_RECOIL := 3.0
const SHOT_TRAUMA := 0.3
## The bob of a walk, at walking speed: metres to either side and half that
## up and down, radians of roll with the sway and of pitch with the step. It
## runs BOB_LAG of a step behind the bob of the view, as something with weight
## that is carried along.
const BOB_SIZE := 0.012
const BOB_ROLL := 0.010
const BOB_PITCH := 0.005
const BOB_LAG := 0.1
## Turning: the weapon points to where the view was SWAY_LAG seconds ago, at
## most SWAY_MAX radians behind, and catches up at SWAY_RETURN per second. For
## every radian it is behind it shifts SWAY_SHIFT metres the same way and
## banks SWAY_BANK radians into the turn. Over the sights SWAY_AIMED of that
## is left.
const SWAY_LAG := 0.015
const SWAY_MAX := 0.035
const SWAY_RETURN := 10.0
const SWAY_SHIFT := 0.2
const SWAY_BANK := 0.6
const SWAY_AIMED := 0.15
## Its own weight: it catches up with a change of the carrier's speed at
## TRAIL_RATE per second, and until it has it trails TRAIL_SHIFT metres for
## every m/s it is behind, up to TRAIL_MAX m/s. It rolls TRAIL_ROLL radians
## into a strafe for every m/s of it. Rising and falling it hangs back:
## RISE_SHIFT metres and RISE_PITCH radians of muzzle for every m/s, up to
## RISE_MAX m/s.
const TRAIL_RATE := 9.0
const TRAIL_SHIFT := 0.001
const TRAIL_MAX := 12.0
const TRAIL_ROLL := 0.003
const RISE_SHIFT := 0.003
const RISE_PITCH := 0.004
const RISE_MAX := 6.0
## Landing: the metres it drops and the radians its muzzle dips after the
## hardest landing there is, the seconds after touching down at which it is
## lowest, and how much of its swing it loses: it comes up a little past
## where it was held.
const LAND_DROP := 0.03
const LAND_PITCH := 0.04
const LAND_TIME := 0.1
const LAND_DAMPING := 0.6
## Held still it breathes: metres up and down and radians of muzzle, at this
## many breaths a second.
const BREATH_SIZE := 0.002
const BREATH_PITCH := 0.0015
const BREATH_RATE := 0.25
## A hit knocks it away from the side the hit came from: by this many metres
## for a hit of the player's HIT_FULL or more and by less for less, see
## Player.hit_weight(), with this many radians of roll, furthest after
## FLINCH_TIME seconds and swinging back a little past rest.
const FLINCH_SHIFT := 0.008
const FLINCH_ROLL := 0.03
const FLINCH_TIME := 0.06
const FLINCH_DAMPING := 0.6
## The share of all this, the kick of a shot apart, that is left with
## Settings.view_motion at zero. Not none: a weapon that is held dead still
## looks broken, and it moves no more of the picture than itself.
const STEADY_SHARE := 0.35


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
var _melee_left := 0.0
var _landed := true
var _bloom := 0.0
## The kick of a shot: on its z the share of the weapon's own kick_back and
## kick_rotation, on its x metres to the side and on its y radians of roll.
var _kick := SPRING.new(KICK_TIME, KICK_DAMPING)
## How far shot after shot has pushed the muzzle up, as a share of the
## weapon's kick_rotation.
var _climb := 0.0
## How far the weapon lags a turn of the view, in radians of yaw and pitch,
## and the yaw and pitch the view had a frame ago.
var _lag := Vector2.ZERO
var _facing := Vector2.ZERO
## The carrier's velocity as far as the weapon has caught up with it, in the
## carrier's own axes.
var _trail := Vector3.ZERO
## What a landing does to it: radians of pitch on its x, metres on its y.
var _drop := SPRING.new(LAND_TIME, LAND_DAMPING)
## Where a hit has knocked it to, in metres.
var _flinch := SPRING.new(FLINCH_TIME, FLINCH_DAMPING)
## Seconds into its breathing.
var _breath := 0.0
var _sprint_blend := 0.0
## 1 while the slide is held back on an empty magazine.
var _locked := 0.0
## 0 with room in front of the weapon, 1 with the player's nose against a wall.
var _crowded := 0.0
## Where the pump is in its stroke: 0 due, 1 on its way back, 2 done.
var _pump_stage := 2
## True while a click that macOS made a right click of is held down.
var _ctrl_click := false
## 0 for a cold barrel, 1 for one that has just emptied a magazine.
var _heat := 0.0
var _smoke_due := false

@onready var player: CharacterBody3D = owner
@onready var camera: Camera3D = get_parent()
## What the camera sits on: its pitch is where the player looks, without the
## recoil and the shake that the camera adds to it.
@onready var _head: Node3D = camera.get_parent()


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
	player.hit_from.connect(_on_hit)
	player.landed.connect(_on_landed)
	_settle()
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


## Puts one weapon in view, `aim` of the way to the sights, `reload` of the
## way through reloading and `blow` of the way through hitting with it. For a screenshot: nothing else poses the weapon
## while the player stands still.
func preview(index: int, aim := 0.0, reload := 0.0, blow := 0.0) -> void:
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
	_melee_left = MELEE_TIME * (1.0 - blow) if blow > 0.0 else 0.0
	_settle()
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
	_mend_ctrl_click(event)


## macOS hands a click with Ctrl held on as a right click. Ctrl crouches, so
## whoever fires from a crouch would aim instead and never get a shot off.
## A right click that comes with Ctrl is therefore a shot here. It costs
## aiming with the right button of a mouse while Ctrl is held on a Mac; C
## crouches as well, and Option aims.
func _mend_ctrl_click(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_RIGHT or OS.get_name() != "macOS":
		return
	if click.pressed and click.ctrl_pressed:
		_ctrl_click = true
		Input.action_release("ads")
		Input.action_press("fire")
	elif not click.pressed and _ctrl_click:
		_ctrl_click = false
		Input.action_release("fire")


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
	if _melee_left > 0.0:
		_melee_left -= delta
		if not _landed and _melee_left <= MELEE_TIME * (1.0 - MELEE_LANDS):
			_land_blow()

	var data := current()
	var busy := _switch_left > 0.0 or _reload_left > 0.0 or _throw_left > 0.0 or _melee_left > 0.0
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
				_start_melee()
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
	var ends := PackedVector3Array()

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
				killed = Net.damage(target, amount, end, direction) or killed
				# A shot that the plate on its arm stopped is no hit.
				if robot and not target.deflected:
					any_hit = true
					headshot = headshot or head
		ends.append(end)
		# One pellet in three of a load of shot is enough to show where it went.
		if i % 3 == 0:
			Fx.tracer(muzzle, end)
	Net.player_did(&"fired", [_index, ends])

	var recoil_scale := lerpf(1.0, data.ads_recoil_scale, ads_blend)
	player.add_recoil(
		deg_to_rad(data.recoil_pitch_deg) * recoil_scale * randf_range(0.85, 1.15),
		deg_to_rad(data.recoil_yaw_deg) * recoil_scale * randf_range(-1.0, 1.0)
	)
	_bloom = minf(_bloom + data.bloom_per_shot_deg, data.bloom_max_deg)
	_kick_view(data)
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
		# No sound of its own for a hit: the shot landing on the enemy is what
		# there is to hear, and the HUD marks it.
		hit_confirmed.emit(headshot, killed)
	_emit_ammo()


## What a shot does to the picture, the aim apart: the weapon kicks back in
## the hands, never twice alike, and climbs if more follow; the view widens for
## a moment, less over the sights and not at all through a telescopic one;
## and a heavy weapon rattles it, half as much over the sights.
func _kick_view(data: WeaponData) -> void:
	_kick.push(Vector3(randf_range(-KICK_SHIFT, KICK_SHIFT), randf_range(-KICK_ROLL, KICK_ROLL), 1.0))
	_climb = minf(_climb + CLIMB_STEP, CLIMB_MAX)
	var sights := lerpf(1.0, 0.5, ads_blend)
	player.punch_fov(data.recoil_pitch_deg * SHOT_FOV * sights * (1.0 - scope_blend()))
	if data.recoil_pitch_deg >= HEAVY_RECOIL:
		# What a rattle shows goes by its square, so it is the root that halves it.
		player.shake(SHOT_TRAUMA * sqrt(sights))


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
	# A recording of the whole stroke plays from its start; without one the
	# way back and the way forward each make their own sound.
	var stroke := _handling(data, "pump", &"")
	if _pump_stage == 0:
		Sfx.play(stroke if stroke != &"" else _handling(data, "pump_back", &"reload"), -7.0)
		_pump_stage = 1
	elif _since_shot > PUMP_DELAY + PUMP_TIME * 0.45:
		_eject(_models[_index], data)
		if stroke == &"":
			Sfx.play(_handling(data, "pump_forward", &"reload_end"), -5.0)
		_pump_stage = 2


## The sound of one step in handling a weapon: its own if it has one, named
## after its shot ("pistol_mag_in" for the pistol), else the one all weapons
## share ("mag_in"), else `fallback`. Recording a step for one weapon and
## adding it to the manifest is all it takes to give that weapon its own.
func _handling(data: WeaponData, step: String, fallback: StringName) -> StringName:
	var own := StringName("%s_%s" % [String(data.shot_sound).trim_suffix("_shot"), step])
	if Sfx.has(own):
		return own
	return StringName(step) if Sfx.has(StringName(step)) else fallback


func _start_reload() -> void:
	var data := current()
	if _reload_left > 0.0 or _switch_left > 0.0 or _throw_left > 0.0 or _melee_left > 0.0:
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
			Sfx.play(_handling(data, "shell_in", &"reload"), -9.0)
			_emit_ammo()
		if _reload_left <= 0.0:
			_reload_left = 0.0
			Sfx.play(_handling(data, "pump", &"reload_end"), -6.0)
		return

	var fraction := 1.0 - _reload_left / _reload_total
	var moments: Array[float] = [MAG_OUT, MAG_IN, BOLT_RELEASE]
	var steps: Array[String] = ["mag_out", "mag_in", "bolt"]
	var sounds: Array[StringName] = [&"reload", &"reload_end", &"switch"]
	while _reload_stage < moments.size() and fraction >= moments[_reload_stage]:
		Sfx.play(_handling(data, steps[_reload_stage], sounds[_reload_stage]), -9.0)
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
	if grenades <= 0 or _throw_left > 0.0 or _switch_left > 0.0 or _melee_left > 0.0:
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
	Net.player_did(&"threw", [from, grenade.linear_velocity, grenade.angular_velocity])
	Sfx.play(&"throw", -6.0)


## Out of rounds altogether: the weapon itself is what is left to hit with.
func _start_melee() -> void:
	_melee_left = MELEE_TIME
	_landed = false
	Sfx.play(&"dry_fire", -6.0)
	Sfx.play(&"swing", -2.0)


## The blow lands on what is in reach in front of the player: an enemy before
## anything else, so that one standing beside a crate can be hit.
func _land_blow() -> void:
	_landed = true
	var origin := camera.global_position
	var aim := camera.global_basis
	var space := get_world_3d().direct_space_state
	var found := {}
	for off: Vector2 in [Vector2.ZERO, Vector2(-0.22, 0), Vector2(0.22, 0), Vector2(0, -0.25), Vector2(0, 0.18)]:
		var end := origin + aim * Vector3(off.x, off.y, -1.0).normalized() * MELEE_REACH
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, HIT_MASK, [player.get_rid()]))
		if hit and (found.is_empty() or (hit.collider.has_method("is_headshot") and not found.collider.has_method("is_headshot"))):
			found = hit
	if found.is_empty():
		return
	var target: Object = found.collider
	var at: Vector3 = found.position
	var direction := (at - origin).normalized()
	Fx.thud(at, Fx.surface_of(found))
	Sfx.play(&"melee", -3.0)
	player.shake(0.22)
	player.add_recoil(-0.03, randf_range(-0.01, 0.01))
	if not target.has_method("take_damage"):
		return
	var robot := target.has_method("is_headshot")
	var killed: bool = Net.damage(target, MELEE_DAMAGE, at, direction)
	if robot and not target.deflected:
		hit_confirmed.emit(false, killed)


func _switch_to(index: int) -> void:
	if index == _pending:
		return
	_melee_left = 0.0
	_landed = true
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

	_kick.step(delta)
	if _since_shot > CLIMB_HOLD:
		_climb *= exp(-CLIMB_BLEED * delta)
	var sprinting: bool = player.is_sprinting() and speed > 5.5 and grounded
	_sprint_blend = lerpf(_sprint_blend, 1.0 if sprinting else 0.0, 1.0 - exp(-10.0 * delta))
	var carried := _carry(aim, delta)

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

	# A blow with the weapon: drawn back over the shoulder, then the butt comes
	# round and forward, and back to where it was held.
	if _melee_left > 0.0:
		var swing := 1.0 - _melee_left / MELEE_TIME
		var back := smoothstep(0.0, 0.22, swing) * (1.0 - smoothstep(0.22, MELEE_LANDS, swing))
		var out := smoothstep(0.2, MELEE_LANDS, swing) * (1.0 - smoothstep(0.5, 1.0, swing))
		handling[0] += Vector3(0.06, 0.03, 0.12) * back + Vector3(-0.15, 0.05, -0.3) * out
		handling[1] += Vector3(0.12, -0.3, -0.25) * back + Vector3(0.05, 0.55, 0.4) * out

	# Up against a wall it is drawn back with the muzzle up, instead of poking
	# through to the other side.
	var eye := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(eye, eye - camera.global_basis.z * REACH, 1, [player.get_rid()])
	var wall := get_world_3d().direct_space_state.intersect_ray(query)
	var room := eye.distance_to(wall.position) / REACH if wall else 1.0
	_crowded = lerpf(_crowded, 1.0 - smoothstep(0.3, 1.0, room), 1.0 - exp(-12.0 * delta))
	handling[0] += Vector3(-0.02, -0.07, 0.14) * _crowded
	handling[1] += Vector3(0.95, 0.25, 0.0) * _crowded

	# Over the sights the kick is smaller and straighter and the muzzle climbs
	# less, so that the sights stay close to what they are held on.
	var kick := _kick.at
	var askew := 1.0 - 0.7 * aim
	var shove := kick.z * lerpf(1.0, KICK_AIMED, aim)
	var offset := data.hip_offset.lerp(data.ads_offset, aim) + carried[0]
	offset += Vector3(-0.05 * _sprint_blend + kick.x * askew, -0.22 * lower - 0.03 * _sprint_blend, shove * data.kick_back)
	model.root.position = offset + handling[0]
	model.root.rotation = data.hip_rotation_deg * (PI / 180.0) * (1.0 - aim) + handling[1] + carried[1] + Vector3(
		(shove * (1.0 - 0.5 * aim) + _climb * (1.0 - 0.8 * aim)) * data.kick_rotation - 0.9 * lower - 0.25 * _sprint_blend,
		0.5 * _sprint_blend,
		kick.y * askew
	)
	# Through a telescopic sight the weapon is not seen at all.
	model.root.visible = scope_blend() < 0.5


## How the weapon moves with whoever carries it, as [offset, rotation]: it
## bobs with their stride, lags a turn of the view, trails a change of speed,
## hangs back from a jump and a fall, dips on landing, flinches from a hit and
## breathes when all else is still. `aim` is how far it is up at the eye,
## where most of this makes way for the sights. Every part of it is nothing
## at rest and stays where it is over a `delta` of no time at all, so that a
## weapon posed for a picture sits where its data puts it.
func _carry(aim: float, delta: float) -> Array[Vector3]:
	var offset := Vector3.ZERO
	var turn := Vector3.ZERO

	# The bob of a walk, on the stride that the view and the footsteps go by.
	var walk: float = player.bob_weight()
	var stride: float = player.stride() - BOB_LAG
	var side := sin(PI * stride)
	var lift := -cos(TAU * stride)
	var bob := walk * (1.0 - 0.9 * aim)
	offset += Vector3(side * BOB_SIZE, lift * BOB_SIZE * 0.5, 0.0) * bob
	turn += Vector3(lift * BOB_PITCH, 0.0, -side * BOB_ROLL) * bob

	# A turn of the view, however it came about: mouse, stick or a look that
	# was set. Half of what was turned is added before the weapon catches up
	# over this frame and half after, which comes to the same lag at any frame
	# rate; and a turn of any size in one frame is no more than SWAY_MAX.
	var facing := Vector2(player.rotation.y, _head.rotation.x)
	var turned := Vector2(angle_difference(_facing.x, facing.x), facing.y - _facing.y) * (SWAY_LAG * SWAY_RETURN * 0.5)
	_facing = facing
	_lag = ((_lag + turned) * exp(-SWAY_RETURN * delta) + turned).limit_length(SWAY_MAX)
	var sway := _lag * lerpf(1.0, SWAY_AIMED, aim)
	offset += Vector3(sway.x, -sway.y, 0.0) * SWAY_SHIFT
	turn += Vector3(-sway.y, -sway.x, sway.x * SWAY_BANK)

	# Its own weight against the carrier's: setting off, stopping, a strafe, a
	# jump and a fall.
	var moving: Vector3 = player.global_basis.inverse() * player.velocity
	_trail = _trail.lerp(moving, 1.0 - exp(-TRAIL_RATE * delta))
	var behind := (moving - _trail).limit_length(TRAIL_MAX)
	var rise := clampf(_trail.y, -RISE_MAX, RISE_MAX)
	var loose := 1.0 - 0.7 * aim
	offset += Vector3(-behind.x * TRAIL_SHIFT, -rise * RISE_SHIFT, -behind.z * TRAIL_SHIFT) * loose
	turn += Vector3(rise * RISE_PITCH, 0.0, -_trail.x * TRAIL_ROLL) * loose

	_drop.step(delta)
	offset.y += _drop.at.y * (1.0 - 0.5 * aim)
	turn.x += _drop.at.x * (1.0 - 0.5 * aim)

	_flinch.step(delta)
	var flinch := _flinch.at * (1.0 - 0.6 * aim)
	offset += flinch
	turn.z -= flinch.x * (FLINCH_ROLL / FLINCH_SHIFT)

	# Breathing, with a slower drift to the side so that it does not repeat
	# itself breath for breath. Both start from nothing and come round again
	# together after a hundred seconds.
	_breath = fposmod(_breath + delta, 100.0)
	var still := (1.0 - minf(walk * 2.0, 1.0)) * (1.0 - 0.6 * aim)
	var breath := sin(TAU * BREATH_RATE * _breath) * still
	offset += Vector3(sin(TAU * 0.16 * _breath) * 0.5 * still, breath, 0.0) * BREATH_SIZE
	turn.x += breath * BREATH_PITCH

	var own := lerpf(STEADY_SHARE, 1.0, Settings.view_motion)
	return [offset * own, turn * own]


## Brings everything that swings to rest, with the weapon held on where the
## player now looks: for a picture of it, and to begin with. What is not the
## weapon's own to bring to rest stays as it is: the stride and the speed of
## whoever carries it, and with them the bob of a walk and the hold of a
## sprint. A picture is taken of a player who stands still.
func _settle() -> void:
	_kick.settle()
	_drop.settle()
	_flinch.settle()
	_climb = 0.0
	_breath = 0.0
	_lag = Vector2.ZERO
	_facing = Vector2(player.rotation.y, _head.rotation.x)
	_trail = player.global_basis.inverse() * player.velocity


## A hit knocks the weapon away from the side it came from, and back for one
## from the front. One that came from no side only makes it sag.
func _on_hit(amount: float, bearing: Vector3) -> void:
	var size: float = player.hit_weight(amount) * FLINCH_SHIFT
	if bearing == Vector3.ZERO:
		_flinch.push(Vector3(0.0, -0.4 * size, 0.0))
		return
	var from: Vector3 = player.global_basis.inverse() * bearing
	_flinch.push(Vector3(-from.x, 0.0, -0.6 * from.z) * size)


## The weapon drops and its muzzle dips as the player lands, see Player.landed.
func _on_landed(hardness: float) -> void:
	_drop.push(Vector3(-LAND_PITCH, -LAND_DROP, 0.0) * hardness)


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


## Three lights that reach only the weapon in view, so that it keeps its shape
## wherever the level leaves it: a soft one over the left shoulder for the
## side that faces the eye, one above and ahead of it that draws a highlight
## along the top of everything, and one from beyond the muzzle that picks out
## its outline against a dark hall. None of them casts a shadow.
func _build_fill() -> void:
	for at: Array in [
		["Fill", Vector3(-0.45, 0.5, 0.25), Color(0.85, 0.9, 1.0), 0.7, 0.5],
		["Key", Vector3(0.3, 0.55, -0.55), Color(1.0, 0.95, 0.88), 0.45, 2.0],
		["Rim", Vector3(-0.55, 0.1, -1.3), Color(0.8, 0.88, 1.0), 0.4, 3.0],
	]:
		var light := OmniLight3D.new()
		light.name = at[0]
		light.position = at[1]
		light.omni_range = REACH_OF_LIGHT + (at[1] as Vector3).length()
		light.omni_attenuation = 0.6
		light.light_color = at[2]
		light.light_energy = at[3]
		light.light_specular = at[4]
		light.light_cull_mask = 1 << (VIEW_LAYER - 1)
		light.light_volumetric_fog_energy = 0.0
		light.light_bake_mode = Light3D.BAKE_DISABLED
		add_child(light)
