extends Node
## The brain of a bot in a match, on the host: a child of its puppet
## (scripts/puppet.gd), which it moves about and has aim and fire. What comes
## of its shots is up to scripts/match.gd, as for anybody who plays.
##
## This is the first cut of it. It goes for the nearest enemy it knows of and
## shoots when it sees one, and otherwise walks to where it last knew of one,
## or to where the other side is to be found. What it knows it has seen, in
## front of it and with a clear line; or heard, a shot that carried as far as
## where it stands; or felt, by being hit. It carries one weapon of the
## loadout, which does in its hands what it does in the player's: the same
## damage, rate of fire and magazine, and every shot is a ray along where it
## points. It walks and runs as fast as the player. Its aim runs after the
## chest of its target and takes a moment to get there, and it does not fire
## on sight: how long that takes, how far its aim wanders and how wide it
## looks is its level (assets/bots.json), which goes by the difficulty. So is
## how long it keeps firing before it lets up, and at a person no more bots
## fire at a time than the match allows.
## Whom it sees, its side knows of as well. What it does not do yet: take
## cover, fall back, throw grenades, jump or crouch.

const WEAPONS := preload("res://scripts/weapons.gd")
const ARMORY := preload("res://scripts/armory.gd")
const PLAYER := preload("res://scripts/player.gd")
const WORLD := 1
## From how near it notices somebody whichever way it looks. How far it sees
## ahead is up to the weapon in its hands (WeaponData.bot_sight).
const AT_ITS_SHOULDER := 4.0
## Seconds between two looks around.
const LOOK := 0.12
## Its level where assets/bots.json says nothing: seconds from seeing
## somebody to the first shot, how far off its aim wanders, in degrees, the
## seconds its aim takes to catch up, how wide it looks, in degrees, and the
## seconds it keeps firing before it lets up for somewhere between the two
## numbers of `rest`.
const LEVEL := {"reaction": 0.55, "wander": 2.0, "aim_time": 0.6, "fov": 110.0, "burst": 1.0, "rest": [0.4, 0.7]}
## How far under the eyes of its target it aims, in metres: at the chest.
const CHEST := 0.5
## One that is in a hurry, with a prize on its back, still turns on an enemy
## who is this near, in metres.
const CORNERED := 14.0
## One that has somewhere to be goes on walking there while it fights
## somebody who is further off than this, in metres.
const PRESSES_ON := 7.0
## It fires while its aim is no further off its target than this, in degrees.
const ON_TARGET := 3.5
## What its spread is on top of that of its weapon over the sights, in degrees.
const UNSTEADY := 0.6
## Seconds it goes on knowing where somebody was, and the seconds between
## two times it tells its side where somebody it sees is.
const MEMORY := 8.0
const TELLS := 1.5
const WALK := PLAYER.WALK_SPEED
const SPRINT := PLAYER.SPRINT_SPEED
const ACCEL := 40.0
const TURN := 9.0
## It has got nowhere if it moved less than this many metres in this many
## seconds while it meant to walk.
const STUCK := Vector2(0.4, 1.5)
## Seconds between two looks for the way to somewhere that moves, and the
## seconds it goes somewhere else after it got stuck on the way to where the
## match wants it.
const REPATH := 0.3
const DETOUR := 3.0
const EYE := 1.6
## Further than this from what the screen shows, in metres, it thinks and
## moves every other step of the physics, a step twice as long: nobody sees
## that at such a distance, and with forty in a match it saves the processor
## half of what they cost it.
const FAR_OFF := 40.0

## The entrant it thinks for, see match.gd.
var me: RefCounted

var _body: CharacterBody3D
var _agent := NavigationAgent3D.new()
var _data: WeaponData
## Who it knows of, by number: [where, the clock then].
var _known := {}
var _clock := 0.0
var _look := 0.0
## Whom it sees and has chosen, and for how long it has.
var _target: RefCounted
var _seen := 0.0
## Where its weapon points, in the world, and how far off its target it is
## holding it just now.
var _aim := Vector3.ZERO
var _off := Vector3.ZERO
var _off_left := 0.0
var _mag := 0
var _cooldown := 0.0
## It fires in bursts: whether it is in one, when that ends, and until when
## it lets up after it.
var _bursting := false
var _burst_ends := 0.0
var _rest_until := 0.0
var _reload := 0.0
## Where it is walking to with nobody in sight, and whether it has anywhere.
var _goal := Vector3.ZERO
var _going := false
var _strafe := 0.0
var _strafe_left := 0.0
var _stood := Vector3.ZERO
var _stood_for := 0.0
var _sprinting := false
var _level := LEVEL
var _path_at := 0.0
## Until when it goes its own way instead of where the match wants it.
var _detour := 0.0
## Whether it is far from what the screen shows, and whether it let the last
## step of the physics go by.
var _far := false
var _skipped := false


func _ready() -> void:
	_body = get_parent()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 1.0
	_agent.radius = 0.4
	_body.add_child.call_deferred(_agent)
	_data = ARMORY.at(me.weapon)
	# Those far off do not all take the same steps.
	_skipped = randi() % 2 == 0
	begin()


## As good as new: after coming back.
func begin() -> void:
	_known.clear()
	_target = null
	_seen = 0.0
	_mag = _data.mag_size
	_reload = 0.0
	_cooldown = 0.0
	_bursting = false
	_rest_until = 0.0
	_going = false
	_look = randf() * LOOK
	_aim = _body.global_position + Vector3.UP * EYE - _body.global_basis.z * 10.0
	_stood = _body.global_position
	_stood_for = 0.0


## Somebody against it fired where it could be heard.
func heard(who: RefCounted, at: Vector3) -> void:
	_known[who.id] = [at, _clock]


## Somebody hit it: it knows from where.
func hit_by(who: RefCounted) -> void:
	if is_instance_valid(who.body):
		_known[who.id] = [who.body.global_position, _clock]


## What the other machines are told of it: what net_state() of its puppet
## takes.
func net_state() -> Array:
	var doing := 0
	if _sprinting:
		doing |= Net.SPRINTING
	if me.out > 0.0:
		doing |= Net.DEAD
	return [_body.global_position, _body.rotation.y, _body.head.rotation.x, _body.velocity, doing, me.weapon]


func _physics_process(delta: float) -> void:
	if _far:
		# Far from what the screen shows it takes every other step, one twice
		# as long.
		_skipped = not _skipped
		if _skipped:
			return
		delta *= 2.0
	if not _body.is_on_floor():
		_body.velocity += _body.get_gravity() * delta
	if me.out > 0.0 or Match.state != Match.State.PLAYING or not _agent.is_inside_tree():
		_body.velocity.x = move_toward(_body.velocity.x, 0.0, ACCEL * delta)
		_body.velocity.z = move_toward(_body.velocity.z, 0.0, ACCEL * delta)
		if me.out <= 0.0:
			_slide(delta)
		return
	_clock += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _reload > 0.0:
		_reload -= delta
		if _reload <= 0.0:
			_mag = _data.mag_size
	_look -= delta
	if _look <= 0.0:
		_look = LOOK
		_level = LEVEL.merged(Match.bot_level(), true)
		var camera := _body.get_viewport().get_camera_3d()
		_far = camera != null and camera.global_position.distance_to(_body.global_position) > FAR_OFF
		_look_around()

	var eye: Vector3 = _body.head.global_position
	var desired := Vector3.ZERO
	var facing := Vector3.ZERO
	# What the kind of match wants of it, unless it got nowhere with that a
	# moment ago.
	var wish: Variant = Match.mode.wish(me) if _clock >= _detour else null
	# Whoever has something better to do than to fight runs on, unless the
	# enemy is on top of them.
	if _target and not (Match.mode.hurries(me) and eye.distance_to(_target.body.head.global_position) > CORNERED):
		_seen += delta
		var at: Vector3 = _target.body.head.global_position - Vector3.UP * CHEST
		var distance := eye.distance_to(at)
		# Its aim wanders about its target, and takes a moment to follow.
		_off_left -= delta
		if _off_left <= 0.0:
			_off_left = randf_range(0.25, 0.6)
			_off = Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)) * distance * tan(deg_to_rad(float(_level.wander)))
		_aim = _aim.lerp(at + _off, 1.0 - exp(-delta * 3.0 / float(_level.aim_time)))
		facing = _aim - eye
		desired = _fight(delta, distance)
		if wish != null and distance > PRESSES_ON:
			# It has somewhere to be: it walks on, firing as it goes.
			desired = _towards(wish, WALK)
		_sprinting = false
		var on_target := (_aim - eye).normalized().dot((at - eye).normalized()) > cos(deg_to_rad(ON_TARGET))
		if _bursting and _clock >= _burst_ends:
			_bursting = false
			var rest: Array = _level.rest
			_rest_until = _clock + randf_range(float(rest[0]), float(rest[1]))
		if _seen >= float(_level.reaction) and on_target and _cooldown <= 0.0 and _reload <= 0.0:
			if _mag <= 0:
				_reload = _data.reload_time
			elif _clock >= _rest_until and Match.may_fire(me, _target):
				# A burst, and with a slow weapon one shot of it.
				if not _bursting:
					_bursting = true
					_burst_ends = _clock + float(_level.burst)
				_shoot(eye)
	else:
		_seen = 0.0
		desired = _roam(wish)
		_sprinting = desired.length() > WALK
		if desired.length_squared() > 0.01:
			facing = desired
			_aim = _aim.lerp(eye + desired.normalized() * 10.0, 1.0 - exp(-delta * 4.0))
		# A quiet moment is one to reload in.
		if _reload <= 0.0 and _mag < _data.mag_size * 0.5:
			_reload = _data.reload_time
	_notice_stuck(delta, desired)

	facing.y = 0.0
	if facing.length_squared() > 0.001:
		_body.rotation.y = lerp_angle(_body.rotation.y, atan2(-facing.x, -facing.z), 1.0 - exp(-TURN * delta))
	var to_aim := _aim - eye
	_body.head.rotation.x = clampf(atan2(to_aim.y, Vector2(to_aim.x, to_aim.z).length()), -1.2, 1.2)
	_body.act(Net.SPRINTING if _sprinting else 0)
	_body.velocity.x = move_toward(_body.velocity.x, desired.x, ACCEL * delta)
	_body.velocity.z = move_toward(_body.velocity.z, desired.z, ACCEL * delta)
	_slide(delta)


## Moves the body as far as its velocity takes it in `delta` seconds, which
## is one step of the physics or two.
func _slide(delta: float) -> void:
	var stride := delta / get_physics_process_delta_time()
	if stride > 1.01:
		_body.velocity *= stride
		_body.move_and_slide()
		_body.velocity /= stride
	else:
		_body.move_and_slide()


## Sees who there is to see, and goes for the nearest of them.
func _look_around() -> void:
	var space := _body.get_world_3d().direct_space_state
	var eye: Vector3 = _body.head.global_position
	var ahead := -_body.global_basis.z
	var sight: float = _data.bot_sight
	var sideways := cos(deg_to_rad(float(_level.fov) * 0.5))
	var nearest := INF
	var found: RefCounted = null
	for other: RefCounted in Match.entrants.values():
		if other.out > 0.0 or not Match.mode.hostile(me, other) or not is_instance_valid(other.body):
			continue
		var head: Vector3 = other.body.head.global_position
		var to := head - eye
		var distance := to.length()
		if distance > sight or (distance > AT_ITS_SHOULDER and to.normalized().dot(ahead) < sideways):
			continue
		# The head or the chest, with nothing of the level in between.
		var seen := false
		for drop: float in [0.0, 0.5]:
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, head + Vector3.DOWN * drop, WORLD)).is_empty():
				seen = true
				break
		if not seen:
			continue
		if not _known.has(other.id) or _clock - float(_known[other.id][1]) > TELLS:
			# News: its side hears of it.
			Match.seen(me, other, other.body.global_position)
		_known[other.id] = [other.body.global_position, _clock]
		# The one it is on already stays that, unless another is clearly nearer.
		var counted := distance * (0.75 if other == _target else 1.0)
		if counted < nearest:
			nearest = counted
			found = other
	if found != _target:
		_seen = 0.0 if found == null else minf(_seen, float(_level.reaction) * 0.5)
		_target = found


## With somebody in sight: closes in to the distance its weapon is for, and
## steps from side to side there.
func _fight(delta: float, distance: float) -> Vector3:
	var reach: float = _data.bot_range
	if distance > reach:
		return _towards(_target.body.global_position, WALK)
	_strafe_left -= delta
	if _strafe_left <= 0.0 or _body.is_on_wall():
		_strafe_left = randf_range(0.6, 1.8)
		_strafe = -_strafe if _body.is_on_wall() and _strafe != 0.0 else [-1.0, 0.0, 1.0].pick_random()
	return _body.global_basis.x * _strafe * WALK * 0.6


## With nobody in sight: to where the kind of match wants it, if anywhere;
## else to where it last knew of somebody, the nearest first, and otherwise
## to the half of the arena where the other side is to be found, or just
## somewhere if there are no sides.
func _roam(wish: Variant) -> Vector3:
	# What the kind of match wants of it comes first.
	if wish != null:
		_going = false
		return _towards(wish, SPRINT)
	var nearest := INF
	var lead := Vector3.ZERO
	for id: int in _known.keys():
		var known: Array = _known[id]
		var who: RefCounted = Match.entrants.get(id)
		var there: Vector3 = known[0]
		# Once it is there and sees nobody, that is that.
		if _clock - float(known[1]) > MEMORY or who == null or who.out > 0.0 or _body.global_position.distance_to(there) < 2.0:
			_known.erase(id)
			continue
		var gap := _body.global_position.distance_to(there)
		if gap < nearest:
			nearest = gap
			lead = there
	if nearest < INF:
		_going = false
		return _towards(lead, SPRINT)
	if not _going or _body.global_position.distance_to(_goal) < 2.0:
		_goal = Match.arena.somewhere(1 - me.team) if Match.mode.teams() else Match.arena.anywhere()
		_going = true
	return _towards(_goal, SPRINT)


## The velocity that takes it to `goal` over the navmesh. Where the navmesh
## has no way for it, on a patch that hangs together with nothing, it makes
## straight for the goal: that takes it off the patch.
func _towards(goal: Vector3, pace: float) -> Vector3:
	if _clock >= _path_at and _agent.target_position.distance_to(goal) > 0.5:
		_agent.target_position = goal
		_path_at = _clock + REPATH
	var straight := goal - _body.global_position
	straight.y = 0.0
	if straight.length() < 1.0:
		return Vector3.ZERO
	var step := straight
	if not _agent.is_navigation_finished():
		step = _agent.get_next_path_position() - _body.global_position
		step.y = 0.0
		if step.length_squared() < 0.01:
			step = straight
	return step.normalized() * pace


## One that means to walk and gets nowhere thinks of somewhere else to go.
func _notice_stuck(delta: float, desired: Vector3) -> void:
	if desired.length() < 1.0 or _body.global_position.distance_to(_stood) > STUCK.x:
		_stood = _body.global_position
		_stood_for = 0.0
		return
	_stood_for += delta
	if _stood_for > STUCK.y:
		_stood_for = 0.0
		_known.clear()
		_going = false
		_strafe = -_strafe
		_detour = _clock + DETOUR
		Match.stuck += 1


## A shot: a ray for every pellet along where it points, as wide as its
## weapon spreads, and the match is told what it landed on.
func _shoot(eye: Vector3) -> void:
	_mag -= 1
	_cooldown = 60.0 / _data.rounds_per_minute
	var space := _body.get_world_3d().direct_space_state
	var aim := Basis.looking_at((_aim - eye).normalized())
	var spread := tan(deg_to_rad(_data.ads_spread_deg + UNSTEADY + _data.move_spread_deg * minf(_body.velocity.length() / 8.0, 1.5) * 0.3))
	if _data.pellets > 1:
		spread = tan(deg_to_rad(_data.hip_spread_deg))
	var mask: int = WEAPONS.HIT_MASK | Match.foes_of(_body)
	var ends := PackedVector3Array()
	for i in _data.pellets:
		var angle := randf() * TAU
		var radius := sqrt(randf()) * spread
		var direction := (aim * Vector3(cos(angle) * radius, sin(angle) * radius, -1.0)).normalized()
		var end := eye + direction * _data.max_range
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, end, mask, [_body.get_rid()]))
		if hit:
			end = hit.position
			var target: Object = hit.collider
			if target.has_method("take_damage"):
				var falloff := remap(eye.distance_to(end), _data.falloff_start, _data.falloff_end, 1.0, _data.min_damage_scale)
				var amount := _data.damage * clampf(falloff, _data.min_damage_scale, 1.0)
				# A load of shot is a load of shot, wherever its pellets land:
				# in a bot's hands it does to a head what it does to a chest.
				var head: bool = _data.pellets == 1 and target.has_method("is_headshot") and target.is_headshot(end)
				if head:
					amount *= _data.headshot_multiplier
				Match.hit(_body, target, amount, end, direction, me.weapon, head)
		ends.append(end)
	Net.show(_body, &"fired", [me.weapon, ends])
	Match.fired(_body, eye, _data.flash_size * WEAPONS.HEARD)
