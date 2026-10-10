extends CharacterBody3D
## Enemy AI. An enemy finds the player over the navmesh and attacks in
## telegraphed bursts, and what it does in between depends on what it is. One
## that takes cover fights from behind things: it runs to a spot that hides
## it, waits there for its turn to shoot, steps or stands out for a burst and
## goes back. One that does not walks up and stands its ground. Whose turn it
## is, where there is cover and who goes round the player is kept by Squad.
## All of them get out of the way of what is about to explode, unless they do
## not heed danger.
##
## The grunt, rusher and heavy are this same script with different exported
## tuning and a different model; how the model moves is up to its rig. That is
## enemy_rig.gd for a robot, and humanoid_rig.gd when the theme of the enemies
## (see enemy_themes.gd) has a character for this role. A rig may also give
## its enemy something to carry: the robot grunt has a plate on its arm that
## stops shots from the front, and the robot heavy a pack of ammunition on
## its back that goes off when it is holed.

signal died(enemy: Node3D)
## Something hit it, whether that hurt it or not.
signal disturbed

const ACCEL := 22.0
const SIGHT_RANGE := 45.0
const ALERT_RADIUS := 14.0
const LOS_MASK := 0b011  # world + player
const RIG := preload("res://scripts/enemy_rig.gd")
const HUMANOID := preload("res://scripts/humanoid_rig.gd")
const THEMES := preload("res://scripts/enemy_themes.gd")
## Seconds a dead enemy stays around as a node; its pieces look after themselves.
const LINGER := 6.0
## What a role that fights hand to hand gets when its theme says no more than
## that it does: it has to come close, and it strikes once.
const MELEE := {"preferred_range": 1.4, "attack_range": 2.0, "burst_shots": 1}
## Which way an enemy walks in a pose for a screenshot, see preview().
const PREVIEW_MOVES := {2.0: Vector3.FORWARD, 5.0: Vector3.RIGHT * 0.5, 6.0: Vector3.LEFT * 0.5, 7.0: Vector3.BACK * 0.5}
## A character is slighter than a robot: its collider is this many times its
## height across at most, and never wider than the one in the scene.
const GIRTH := 0.19

## How much faster than its walk it runs for cover, and from danger.
const COVER_PACE := 1.15
const FLEE_PACE := 1.3
## Seconds between two looks for cover while it has none.
const COVER_RETRY := 0.8
## With the player this close, cover is no use any more.
const FLUSHED := 4.0
## Seconds it lets itself be seen where it meant to be hidden.
const EXPOSED := 0.7
## Seconds it stays out of cover with nothing to shoot at before it gives up
## its turn, and how often that may happen before it looks for a better spot.
const PATIENCE := 1.8
const MISSES := 2
## Seconds a run for cover may take.
const RUN_TIME := 9.0
## It attacks what is this far off its nose at most, as a cosine, and holds
## its fire in the middle of a burst when the player has got further round.
const FACING := 0.7
const FACING_HELD := 0.45
## A hit on the pack on its back counts for this much more. Once the pack is
## holed it burns for a moment and then goes off, like a fuel barrel.
const PACK_HURT := 1.5
const PACK_FUSE := 1.3
const PACK_RADIUS := 5.0
const PACK_DAMAGE := 140.0
## Seconds it is out of action when the plate is shot off its arm.
const STAGGER := 0.9

enum Attack { COOLDOWN, TELEGRAPH, BURST }
## What it is doing about the player: going for it, running for cover,
## waiting there, out of it to shoot, or getting away from something.
enum Mode { HUNT, TO_COVER, COVER, PEEK, FLEE }

## Which of the three it is: "grunt", "rusher" or "heavy". A theme casts a
## character for each.
@export var role := "grunt"
## What it looks like as a robot: a scene from tools/models/enemies.gd.
@export var model: PackedScene
## Tuning for one enemy type; the variants in scenes/ override these.
@export var max_health := 100.0
@export var speed := 4.2
## Strafes inside this distance, closes in outside it.
@export var preferred_range := 11.0
@export var attack_range := 26.0
## Strikes at arm's length instead of shooting.
@export var melee := false
@export var damage := 7.0
@export var burst_shots := 3
@export var shot_interval := 0.14
@export var spread_deg := 2.5
@export var telegraph_time := 0.45
## Shortest and longest pause between attacks.
@export var cooldown := Vector2(1.2, 2.2)
## Height above the feet of the eyes, and of where headshots start.
@export var eye_height := 1.5
@export var head_start := 1.36
@export var visor_color := Color(1.0, 0.15, 0.1)
## Length of the flame at its muzzle, in metres.
@export var flash_size := 0.26
## How tall a character stands next to the way it was made. A robot is built
## to size.
@export var size := 1.0
## Radians a second it turns at, more or less: a slow one can be got behind.
@export var turn_speed := 8.0
## Fights from behind things where there are any. One that strikes instead of
## shooting never does.
@export var takes_cover := true
## Gets out of the way of what is about to go off, and walks round a fire.
@export var heeds_danger := true
## What the plate on its arm takes before it is shot off, and what the pack
## on its back takes before it is holed. Only for a model that has one.
@export var shield := 80.0
@export var pack := 0.0

var health := 0.0
var dead := false
## True if the last thing that hit it was stopped by its plate.
var deflected := false

var _player: CharacterBody3D
var _alerted := false
var _has_los := false
var _los_timer := 0.0
var _repath_timer := 0.0
var _strafe_dir := 1.0
var _strafe_timer := 0.0
var _attack := Attack.COOLDOWN
var _attack_timer := 1.0
var _shots_left := 0
var _last_hit := Vector3.FORWARD
var _rig: Node3D
var _mode := Mode.HUNT
## Where it fights from: {index, at, fire, crouch}, see Squad.find_cover().
var _cover := {}
var _cover_timer := 0.0
## Spots that were no good the last few times it looked, and where the
## player stood then: they may be good again once the player has moved.
var _no_good: Array[int] = []
var _no_good_from := Vector3.ZERO
var _in_cover := 0.0
var _move_on := 10.0
var _exposed := 0.0
var _peek := 0.0
var _misses := 0
var _run := 0.0
var _face := Vector3.FORWARD
var _crouched := false
var _can_crouch := false
## How far its head comes down when it ducks.
var _drop := 0.0
var _stand_height := 1.8
var _refuge := Vector3.ZERO
var _flee_left := 0.0
var _danger_timer := 0.0
## How long it has known of a danger, and how long it takes to act on one.
var _noticed := 0.0
var _nerve := 0.3
var _stun := 0.0
var _shield := 0.0
var _pack := 0.0
var _pack_fuse := -1.0
var _pack_flame: Node3D

@onready var agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	var cast := THEMES.cast(Settings.enemy_theme, role)
	var tuned := _tune(cast.get("tuning", {}))
	health = max_health
	_player = get_tree().get_first_node_in_group("player")
	if not (cast and _embody(cast, tuned)):
		_rig = model.instantiate()
		_rig.name = "Model"
		_rig.set_script(RIG)
		add_child(_rig)
	_rig.set_glow(visor_color)
	_los_timer = randf() * 0.15
	_danger_timer = randf() * 0.2
	_nerve = randf_range(0.3, 0.6)
	# What it carries is up to its model. Not every one that could carry a
	# plate does: how many is a matter of the difficulty, unless whoever made
	# this one has said so with the meta "plate".
	if _rig.get("has_shield") == true and not get_meta(&"plate", Benchmark.active or randf() < Settings.rules().plates):
		_rig.drop_shield()
	_shield = shield if _rig.get("has_shield") == true else 0.0
	_pack = pack if _rig.get("has_pack") == true else 0.0
	_can_crouch = _rig.has_method("crouch")
	if _can_crouch:
		_drop = _rig.crouch_drop
		# The collider comes down with it, and is this enemy's alone for that.
		var collider: CollisionShape3D = $CollisionShape3D
		collider.shape = collider.shape.duplicate()
		_stand_height = (collider.shape as CapsuleShape3D).height


## Takes over what a theme says is different about this role: exported
## variables by name. Returns the names it set.
func _tune(tuning: Dictionary) -> Array:
	var tuned := []
	if tuning.is_empty():
		return tuned
	var exported := []
	for property: Dictionary in (get_script() as Script).get_script_property_list():
		if property.usage & PROPERTY_USAGE_EDITOR:
			exported.append(property.name)
	for key: String in tuning:
		if not exported.has(key):
			continue
		var value: Variant = tuning[key]
		var now: Variant = get(key)
		var fits := typeof(value) == typeof(now)
		match typeof(now):
			TYPE_INT, TYPE_FLOAT:
				fits = typeof(value) in [TYPE_INT, TYPE_FLOAT]
			TYPE_VECTOR2:
				# A span of two numbers, as JSON writes it.
				fits = value is Array and value.size() == 2
				if fits:
					value = Vector2(value[0], value[1])
			TYPE_COLOR:
				fits = value is String
			TYPE_BOOL:
				pass
			_:
				fits = false
		if fits:
			set(key, type_convert(value, typeof(now)))
			tuned.append(key)
	if melee and tuned.has("melee"):
		for key: String in MELEE:
			if not tuned.has(key):
				set(key, MELEE[key])
	return tuned


## Becomes the character a theme cast for it. False if that cannot be shown.
func _embody(cast: Dictionary, tuned: Array) -> bool:
	var rig := HUMANOID.new()
	rig.name = "Model"
	cast.merge({"melee": melee, "windup": telegraph_time, "size": size})
	if not rig.setup(cast):
		rig.free()
		return false
	add_child(rig)
	_rig = rig
	# It is shot at where it is seen: the collider takes its height, and the
	# eyes and the head are where the character has them.
	var fit: Dictionary = rig.fit
	var collider: CollisionShape3D = $CollisionShape3D
	var capsule: CapsuleShape3D = collider.shape.duplicate()
	capsule.radius = minf(capsule.radius, fit.height * GIRTH)
	capsule.height = maxf(fit.height, capsule.radius * 2.0)
	collider.shape = capsule
	collider.position.y = capsule.height * 0.5
	if not tuned.has("eye_height"):
		eye_height = fit.eyes
	if not tuned.has("head_start"):
		head_start = fit.head
	if not tuned.has("flash_size"):
		flash_size = rig.flash_size
	return true


## Strikes a pose for a screenshot of an enemy that is not running: 1 with
## its weapon on a target straight ahead, 2 in mid-stride as well, 3 shot to
## pieces or lying dead, 4 firing at that target. 5, 6 and 7 are mid-stride
## to its right, to its left and backwards, 8 is the moment before it
## attacks and 9 the moment it is hit. 10 has its plate up in front of it, 11
## is ducked behind something and 12 has its pack alight.
func preview(pose: float) -> void:
	if pose == 3.0:
		_die()
		return
	if (pose == 10.0 or pose == 11.0) and _shield > 0.0:
		_rig.guard(true)
	if pose == 11.0:
		_set_crouched(true)
	elif pose == 12.0 and _pack > 0.0:
		_light_pack()
	if PREVIEW_MOVES.has(pose):
		velocity = global_basis * PREVIEW_MOVES[pose] * speed
	var eye := global_position + Vector3.UP * eye_height
	_rig.aim(eye - global_basis.z * 8.0)
	for i in 40:
		_rig._pose(0.03)
	if pose == 4.0:
		_shoot(eye, eye - global_basis.z * 8.0)
	elif pose == 8.0:
		_rig.charge(true)
		for i in 6:
			_rig._pose(0.03)
	elif pose == 9.0:
		_rig.hit(eye - Vector3.UP * 0.25 - global_basis.z * 0.2, global_basis.z, 20.0)
		_rig._pose(0.04)


func is_headshot(hit_position: Vector3) -> bool:
	return hit_position.y - global_position.y > head_start - (_drop if _crouched else 0.0)


## True once it knows of the player.
func is_alert() -> bool:
	return _alerted and not dead


func alert() -> void:
	if _alerted or dead:
		return
	_alerted = true
	_attack_timer = randf_range(0.4, 1.2)
	if _shield > 0.0:
		_rig.guard(true)
	Sfx.play_at(_rig.sounds[&"alert"], global_position)
	for other in get_tree().get_nodes_in_group("enemy"):
		if other.global_position.distance_to(global_position) < ALERT_RADIUS:
			other.alert()


## A shot that hits it at `hit_position`, coming in along `direction`. True if
## that was the end of it.
func take_damage(amount: float, hit_position: Vector3, direction: Vector3) -> bool:
	if dead:
		return false
	deflected = false
	disturbed.emit()
	# A plate it has not raised yet stops nothing: the first shot at one that
	# does not know of the player goes home.
	var guarded := _shield > 0.0 and _alerted
	alert()
	var at := global_basis.inverse() * (hit_position - global_position)
	var along := global_basis.inverse() * direction
	if guarded and _behind_plate(at, along):
		deflected = true
		_shield -= amount
		_rig.block(hit_position, direction)
		Sfx.play_at(&"shield_block", hit_position, -2.0)
		if _shield <= 0.0:
			_lose_shield(direction)
		return false
	if _pack > 0.0 and _on_pack(at, along):
		amount *= PACK_HURT
		_pack -= amount
		if _pack <= 0.0:
			_light_pack()
	return _hurt(amount, hit_position, direction)


## What an explosion does to it: no plate stops that, and the plate itself
## takes as much.
func take_blast(amount: float, hit_position: Vector3, direction: Vector3) -> bool:
	if dead:
		return false
	disturbed.emit()
	alert()
	if _shield > 0.0:
		_shield -= amount
		if _shield <= 0.0:
			_lose_shield(direction)
	return _hurt(amount, hit_position, direction)


## What whoever stands near it has to fear, once its pack burns: see
## Squad.threat().
func danger() -> Dictionary:
	if _pack_fuse < 0.0 or dead:
		return {}
	return {"at": global_position + Vector3.UP, "radius": PACK_RADIUS, "left": _pack_fuse}


func _hurt(amount: float, hit_position: Vector3, direction: Vector3) -> bool:
	health -= amount
	_last_hit = direction
	_rig.hit(hit_position, direction, amount)
	if health <= 0.0:
		_die()
	return dead


## True if a shot that lands at `at` and travels along `along`, both as the
## enemy itself sees them, meets the plate: it comes from the front and at
## the height of the trunk. Head and legs stick out past it.
func _behind_plate(at: Vector3, along: Vector3) -> bool:
	var span: Vector2 = _rig.shield_span
	var down := _drop if _crouched else 0.0
	return along.z > 0.3 and at.y > span.x - down and at.y < span.y - down


## The same for the pack on its back: from behind, between the shoulders.
func _on_pack(at: Vector3, along: Vector3) -> bool:
	var span: Vector2 = _rig.pack_span
	return along.z < -0.3 and at.z > 0.0 and at.y > span.x and at.y < span.y


## The plate is shot off its arm, and that takes it a moment to get over.
func _lose_shield(push: Vector3) -> void:
	_shield = 0.0
	_stun = STAGGER
	_rig.shed_shield(push)
	Sfx.play_at(&"shield_break", global_position + Vector3.UP, 2.0)
	if _attack != Attack.COOLDOWN:
		_end_attack(STAGGER)


## The pack is holed: flame comes out of it, and it goes off a moment later.
func _light_pack() -> void:
	_pack = 0.0
	_pack_fuse = PACK_FUSE
	add_to_group("hazard")
	var from: Vector3 = _rig.pack_position()
	_pack_flame = Fx.jet(from, global_basis.z * 0.4 + Vector3.UP, 0.9, PACK_FUSE + 0.3)
	Sfx.play_at(&"vent", from, 2.0)


func _burn_pack(delta: float) -> void:
	_pack_fuse -= delta
	if is_instance_valid(_pack_flame):
		_pack_flame.global_position = _rig.pack_position()
	if _pack_fuse <= 0.0:
		_burst_pack()


func _burst_pack() -> void:
	var from: Vector3 = _rig.pack_position()
	_pack_fuse = -1.0
	remove_from_group("hazard")
	if is_instance_valid(_pack_flame):
		_pack_flame.queue_free()
	if not dead:
		# Thrown forwards, away from what went off behind it.
		_rig.lose_pack()
		_last_hit = -global_basis.z
		health = 0.0
		_die()
	Blast.explode(from, PACK_RADIUS, PACK_DAMAGE, 0.8, self)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var desired := Vector3.ZERO
	if _pack_fuse >= 0.0:
		_burn_pack(delta)

	if not dead and is_instance_valid(_player) and not _player.dead:
		var eye := global_position + Vector3.UP * _eyes()
		var target: Vector3 = _player.head.global_position - Vector3.UP * 0.25
		var distance := eye.distance_to(target)

		_los_timer -= delta
		if _los_timer <= 0.0:
			_los_timer = 0.15
			_has_los = distance < SIGHT_RANGE and _ray_hits_player(eye, target)
		if _has_los:
			alert()

		if _alerted:
			_stun = maxf(_stun - delta, 0.0)
			_face = target - eye
			desired = _decide(delta, distance)
			if heeds_danger:
				desired = _mind_fire(desired)
			if _stun > 0.0:
				desired *= 0.25
			_turn_towards(_face, delta)
			_update_attack(delta, eye, target, distance)
			# The weapon is on the player for as long as there is a shot.
			if _has_los and distance < attack_range * 1.5 and _mode != Mode.FLEE and _stun <= 0.0:
				_rig.aim(target)
			else:
				_rig.lower()

	velocity.x = move_toward(velocity.x, desired.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, desired.z, ACCEL * delta)
	move_and_slide()


## Works out what to do and returns the velocity that goes with it; `_face`
## is left pointing where it should look meanwhile.
func _decide(delta: float, distance: float) -> Vector3:
	if heeds_danger and _mode != Mode.FLEE:
		_danger_timer -= delta
		if _danger_timer <= 0.0:
			_danger_timer = 0.1
			var threat := Squad.threat(global_position)
			# Not its own pack: there is no running from that.
			if threat.is_empty() or _pack_fuse >= 0.0:
				_noticed = 0.0
			else:
				_noticed += 0.1
				if _noticed >= _nerve:
					_flee(threat)
	match _mode:
		Mode.FLEE:
			return _get_away(delta)
		Mode.TO_COVER:
			return _run_for_cover(delta)
		Mode.COVER:
			return _hold_cover(delta, distance)
		Mode.PEEK:
			return _lean_out(delta)
	return _hunt(delta, distance)


## Goes for the player: up to it while it is out of sight or too far, and to
## and fro in front of it otherwise. One that takes cover keeps an eye out
## for some.
func _hunt(delta: float, distance: float) -> Vector3:
	var desired: Vector3
	if not _has_los or distance > preferred_range:
		desired = _chase(delta)
		if not _has_los and desired.length_squared() > 0.01:
			_face = desired
	else:
		desired = _strafe(delta)
	if takes_cover and not melee:
		_cover_timer -= delta
		if _cover_timer <= 0.0 and distance < attack_range * 1.4:
			_cover_timer = COVER_RETRY * randf_range(0.8, 1.3)
			_seek_cover()
	return desired


## Looks for a spot to fight from and makes for it. False if there is none.
func _seek_cover(tired_of := -1) -> bool:
	var flank := Squad.goes_round(self)
	var foe: Vector3 = _player.head.global_position
	if foe.distance_to(_no_good_from) > 2.0 or _no_good.size() > 60:
		_no_good.clear()
		_no_good_from = foe
	var found := Squad.find_cover(self, foe, {
		"reach": 22.0 if flank else 14.0,
		"nearest": maxf(preferred_range * 0.45, FLUSHED + 1.0),
		"farthest": attack_range * 0.9,
		"ideal": preferred_range,
		"eyes": eye_height,
		"drop": _drop,
		"flank": flank,
		"not": tired_of,
		"tried": _no_good,
	})
	if found.is_empty():
		Squad.done_flanking(self)
		return false
	if flank and _mode != Mode.TO_COVER:
		_say(&"flank")
	Squad.take(self, found.index)
	_cover = found
	_mode = Mode.TO_COVER
	_set_crouched(false)
	_run = 0.0
	_exposed = 0.0
	_misses = 0
	_move_on = randf_range(7.0, 12.0)
	return true


func _run_for_cover(delta: float) -> Vector3:
	_run += delta
	var step := _go_to(_cover.at, speed * COVER_PACE)
	if _flat(_cover.at) < 0.3:
		_mode = Mode.COVER
		_in_cover = 0.0
	elif _run > RUN_TIME:
		_leave_cover()
	elif not _has_los and step.length_squared() > 0.01:
		_face = step
	return step


## Stays where it cannot be seen until it is its turn to shoot, and moves on
## when the spot is no good any more: the player has come round it or up to
## it, or it has been here long enough.
func _hold_cover(delta: float, distance: float) -> Vector3:
	_in_cover += delta
	var off := _flat(_cover.at)
	if off < 0.6:
		_set_crouched(_cover.crouch)
	_exposed = _exposed + delta if _has_los else maxf(_exposed - delta, 0.0)
	var found_out := distance < FLUSHED or _exposed > EXPOSED
	if found_out or _in_cover > _move_on or _misses >= MISSES:
		if not _seek_cover(_cover.index):
			if found_out:
				_leave_cover()
				return Vector3.ZERO
			_in_cover = 0.0
			_misses = 0
	elif _attack == Attack.COOLDOWN and _attack_timer <= 0.0 and _stun <= 0.0 and off < 0.6 and Squad.may_attack(self):
		_mode = Mode.PEEK
		_peek = 0.0
		_set_crouched(false)
	return _go_to(_cover.at, speed)


## Out of cover for a burst: a step to the side, or up from behind something
## low. _end_attack() sends it back.
func _lean_out(delta: float) -> Vector3:
	_peek += delta
	if _attack == Attack.COOLDOWN and _peek > PATIENCE and not _has_los:
		# Nothing to shoot at from here.
		Squad.done_attacking(self, false)
		_misses += 1
		_mode = Mode.COVER
	return _go_to(_cover.fire, speed)


## Gives up its cover and its turn, and goes for the player in the open.
func _leave_cover() -> void:
	Squad.leave(self)
	Squad.done_flanking(self)
	_cover = {}
	_set_crouched(false)
	_mode = Mode.HUNT
	_cover_timer = COVER_RETRY


## Something is about to go off within reach: it drops what it is doing and
## runs.
func _flee(threat: Dictionary) -> void:
	if _attack != Attack.COOLDOWN:
		_end_attack(0.4)
	Squad.done_attacking(self, false)
	_leave_cover()
	_mode = Mode.FLEE
	_refuge = Squad.find_refuge(self, threat)
	_flee_left = clampf(threat.left + 0.4, 0.8, 3.5)
	_noticed = 0.0
	_say(&"alarm")


func _get_away(delta: float) -> Vector3:
	_flee_left -= delta
	var step := _go_to(_refuge, speed * FLEE_PACE)
	if step.length_squared() > 0.01:
		_face = step
	if _flee_left <= 0.0:
		_mode = Mode.HUNT
		_cover_timer = 0.0
	return step


## Keeps out of a fire on the floor: out of it the shortest way, and round
## it instead of through it.
func _mind_fire(desired: Vector3) -> Vector3:
	for patch in Blast.fires():
		var to: Vector3 = patch.at - global_position
		if absf(to.y) > 1.5:
			continue
		to.y = 0.0
		var gap: float = to.length() - patch.radius
		var inwards := to.normalized() if to.length() > 0.05 else -global_basis.z
		if gap < 0.0:
			return -inwards * speed * FLEE_PACE
		if gap < 1.2 and desired.dot(inwards) > 0.0:
			var round_it := inwards.cross(Vector3.UP)
			if round_it.dot(desired) < 0.0:
				round_it = -round_it
			desired = (desired - inwards * desired.dot(inwards) + round_it * desired.dot(inwards)).limit_length(desired.length())
	return desired


func _chase(delta: float) -> Vector3:
	# The navmesh is baked a moment after the level loads.
	if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) == 0:
		return Vector3.ZERO
	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = 0.3
		agent.target_position = _player.global_position
	if agent.is_navigation_finished():
		return Vector3.ZERO
	var step := agent.get_next_path_position() - global_position
	step.y = 0.0
	return step.normalized() * speed


## The velocity that takes it to `goal` over the navmesh at `pace`, and
## straight at it over the last stretch: a spot behind a crate is a matter of
## a hand's breadth.
func _go_to(goal: Vector3, pace: float) -> Vector3:
	if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) == 0:
		return Vector3.ZERO
	var straight := goal - global_position
	straight.y = 0.0
	if straight.length() < 0.08:
		return Vector3.ZERO
	if agent.target_position.distance_to(goal) > 0.2:
		agent.target_position = goal
	var step := straight
	if straight.length() > 1.4 and not agent.is_navigation_finished():
		step = agent.get_next_path_position() - global_position
		step.y = 0.0
	return step.normalized() * minf(pace, straight.length() * 6.0)


## How far it is from `spot`, measured over the floor.
func _flat(spot: Vector3) -> float:
	return Vector2(spot.x - global_position.x, spot.z - global_position.z).length()


func _strafe(delta: float) -> Vector3:
	_strafe_timer -= delta
	if _strafe_timer <= 0.0 or is_on_wall():
		_strafe_timer = randf_range(0.8, 2.2)
		_strafe_dir = -_strafe_dir if is_on_wall() else [-1.0, 0.0, 1.0].pick_random()
	return global_basis.x * _strafe_dir * speed * 0.5


func _turn_towards(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	var yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-turn_speed * delta))


## Ducks behind something low, or stands up again. Its collider and its eyes
## come down with it.
func _set_crouched(crouch: bool) -> void:
	if crouch == _crouched or not _can_crouch:
		return
	_crouched = crouch
	_rig.crouch(crouch)
	var collider: CollisionShape3D = $CollisionShape3D
	var capsule: CapsuleShape3D = collider.shape
	capsule.height = _stand_height - (_drop if crouch else 0.0)
	collider.position.y = capsule.height * 0.5


## Height of its eyes above its feet at this moment.
func _eyes() -> float:
	return eye_height - (_drop if _crouched else 0.0)


## Makes the sound its rig has for `what`, if it has one.
func _say(what: StringName, volume := 0.0) -> void:
	var sound: StringName = _rig.sounds.get(what, &"")
	if sound:
		Sfx.play_at(sound, global_position + Vector3.UP, volume)


func _update_attack(delta: float, eye: Vector3, target: Vector3, distance: float) -> void:
	_attack_timer -= delta
	match _attack:
		Attack.COOLDOWN:
			# From cover it leans out first, and from danger it only runs. One
			# that shoots waits for its turn; one that strikes just comes.
			var set_to := _attack_timer <= 0.0 and _has_los and distance < attack_range and _stun <= 0.0
			if set_to and _mode != Mode.COVER and _mode != Mode.FLEE and _faces(target, FACING) and (melee or Squad.may_attack(self)):
				_attack = Attack.TELEGRAPH
				_attack_timer = telegraph_time * Settings.rules().warning
				_rig.charge(true)
				_say(&"charge", -3.0)
		Attack.TELEGRAPH:
			if not _has_los:
				_end_attack(0.5)
			elif _attack_timer <= 0.0:
				_attack = Attack.BURST
				_shots_left = burst_shots
		Attack.BURST:
			if _attack_timer <= 0.0:
				# The player may have got round it since it took aim.
				if _faces(target, FACING_HELD):
					_shoot(eye, target)
				_shots_left -= 1
				_attack_timer = shot_interval
				if _shots_left <= 0:
					_end_attack(randf_range(cooldown.x, cooldown.y))


func _end_attack(pause: float) -> void:
	_attack = Attack.COOLDOWN
	_attack_timer = pause
	_rig.charge(false)
	Squad.done_attacking(self)
	Squad.done_flanking(self)
	if _mode == Mode.PEEK:
		_mode = Mode.COVER


## True if `target` is no further off its nose than the cosine `within`.
func _faces(target: Vector3, within: float) -> bool:
	var to := target - global_position
	to.y = 0.0
	return to.normalized().dot(-global_basis.z) > within


func _shoot(eye: Vector3, target: Vector3) -> void:
	_rig.fire()
	var hurts: float = damage * Settings.rules().damage
	if melee:
		if eye.distance_to(target) < attack_range + 0.6:
			_player.take_damage(hurts, target, (target - eye).normalized())
		Sfx.play_at(_rig.sounds[&"melee"], global_position)
		return
	# A fast-moving player is harder to hit, which rewards sprinting and sliding.
	var spread := tan(deg_to_rad(spread_deg + _player.velocity.length() * 0.45))
	var aim := Basis.looking_at(target - eye)
	var angle := randf() * TAU
	var radius := sqrt(randf()) * spread
	var direction := (aim * Vector3(cos(angle) * radius, sin(angle) * radius, -1.0)).normalized()
	var end := eye + direction * 100.0
	var query := PhysicsRayQueryParameters3D.create(eye, end, LOS_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		end = hit.position
		if hit.collider == _player:
			_player.take_damage(hurts, end, direction)
		else:
			Fx.impact(hit, direction)
			# A stray shot sets off a fuel barrel as well as the player's does.
			if hit.collider.has_method("take_damage"):
				hit.collider.take_damage(damage, end, direction)
	var muzzle: Vector3 = _rig.muzzle()
	Fx.tracer(muzzle, end, _rig.tracer_tint)
	Fx.muzzle_flash(null, Transform3D(Fx.facing(end - muzzle), muzzle), flash_size, _rig.flash_prongs, _rig.flash_tint)
	Sfx.play_at(_rig.sounds[&"shot"], global_position)


func _ray_hits_player(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, LOS_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == _player


func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 1
	remove_from_group("enemy")
	Squad.leave(self)
	Squad.done_attacking(self, false)
	Squad.done_flanking(self)
	_set_crouched(false)
	# A pack that was alight does not wait for its fuse.
	if _pack_fuse >= 0.0:
		_burst_pack.call_deferred()
	Sfx.play_at(_rig.sounds[&"death"], global_position)
	died.emit(self)
	_rig.collapse(_last_hit * 3.0)
	get_tree().create_timer(LINGER, false).timeout.connect(queue_free)
