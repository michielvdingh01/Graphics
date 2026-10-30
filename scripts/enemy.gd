extends CharacterBody3D
## Enemy AI. An enemy finds the player over the navmesh and attacks in
## telegraphed bursts, and what it does in between depends on what it is. One
## that takes cover fights from behind things: it runs to a spot that hides
## it, waits there for its turn to shoot, steps or stands out for a burst and
## goes back. One that does not walks up and stands its ground. Whose turn it
## is, where there is cover and who goes round the player is kept by Squad.
## All of them get out of the way of what is about to explode, unless they do
## not heed danger. One that panics loses its head when it is badly hurt or
## sees one of its own die: from then on it only runs about.
##
## An enemy that is on watch (see watch()) does not know of the player yet,
## and that is not a matter of being switched off: it walks its round or
## stands guard, and goes by what it sees and hears. It sees what is in front
## of it, far off if it stands in the light and hardly at all if it stands in
## the shade of a level with land (scripts/land.gd), and it takes a moment to
## be sure: `awareness` runs up while it has somebody in view. A shot it
## hears. Once it knows, it is like any other, and so are those with it.
##
## The grunt, rusher and heavy are this same script with different exported
## tuning and a different model; how the model moves is up to its rig. That is
## enemy_rig.gd for a robot, and humanoid_rig.gd when the theme of the enemies
## (see enemy_themes.gd) has a character for this role. A rig may also give
## its enemy something to carry: the robot grunt has a plate on its arm that
## stops shots from the front, and the robot heavy a pack of ammunition on
## its back that goes off when it is holed.
##
## In a game with others (see net.gd) all of that happens on the host. What
## there is to see of it, the _show_ functions, happens on every machine, and
## on a guest the enemy only goes where the host says it is.

signal died(enemy: Node3D)
## Something hit it, whether that hurt it or not.
signal disturbed

const WAY := preload("res://scripts/way.gd")
const ACCEL := 22.0
const SIGHT_RANGE := 45.0
const ALERT_RADIUS := 14.0
const LOS_MASK := 0b011  # world + player
## Seconds it goes on firing at where it last saw somebody who disappeared
## into smoke, at the least and at the most.
const FIRES_ON := Vector2(1.2, 2.6)
const LAND := preload("res://scripts/land.gd")
const RIG := preload("res://scripts/enemy_rig.gd")
const HUMANOID := preload("res://scripts/humanoid_rig.gd")
const THEMES := preload("res://scripts/enemy_themes.gd")
## Seconds a dead enemy stays around as a node; its pieces look after themselves.
const LINGER := 6.0
## What a role that fights hand to hand gets when its theme says no more than
## that it does: it has to come close, and it strikes once.
const MELEE := {"preferred_range": 1.4, "attack_range": 2.0, "burst_shots": 1}
## Which way an enemy walks in a pose for a screenshot, see preview().
const PREVIEW_MOVES := {2.0: Vector3.FORWARD, 5.0: Vector3.RIGHT * 0.5, 6.0: Vector3.LEFT * 0.5, 7.0: Vector3.BACK * 0.5, 13.0: Vector3.FORWARD * 1.35}
## A character is slighter than a robot: its collider is this many times its
## height across at most, and never wider than the one in the scene.
const GIRTH := 0.19
## Seconds between two looks at which of the players to go for, and how much
## closer another has to be before it lets go of the one it is after.
const CHOOSE_TIME := 0.5
const LOYALTY := 0.75

## How much faster than its walk it runs for cover, and from danger.
const COVER_PACE := 1.15
const FLEE_PACE := 1.3
## A person cannot go every way alike, as a robot can. Sideways it goes this
## share of how fast it goes ahead and backwards this share, with its weapon
## up this share of its speed at most whichever way, and it gets going and
## stops again at PERSON_ACCEL m/s². Each is the first number on Easy, the
## second on Hard, and in between as the difficulty has it (agility in
## Settings.RULES): on Hard it is quicker on its feet and harder to hit.
## Cover that lies further round than TURN_AND_RUN radians from where it
## faces it does not back into: it turns its back on the player and runs.
const SIDEWAYS := Vector2(0.65, 0.85)
const BACKWARDS := Vector2(0.4, 0.55)
const AIMED := Vector2(0.7, 0.9)
const PERSON_ACCEL := Vector2(8.0, 16.0)
const TURN_AND_RUN := 1.9
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
## How far one that has lost its head runs before it turns, in metres, and
## the seconds it gives that.
const PANIC_RUN := Vector2(4.0, 11.0)
const PANIC_TIME := Vector2(0.8, 2.2)

## On watch: how sure it has to be before it stops and looks, how fast its
## suspicion fades again, in shares a second, and how fast it turns to look,
## in radians a second.
const WARY := 0.3
const FORGETS := 0.35
const LOOK_PACE := 2.6
## Somebody at its shoulder it notices whichever way it looks, and somebody
## who runs it hears: from this many metres.
const AT_ITS_SHOULDER := 2.6
const HEARS_RUNNING := 9.0
## A player who moves faster than this is running.
const RUNNING := 6.0
## Seconds it waits at either end of its round, and between two looks about
## when it stands guard.
const ROUND_WAIT := Vector2(1.5, 4.0)
const LOOK_WAIT := Vector2(2.5, 6.0)

enum Attack { COOLDOWN, TELEGRAPH, BURST }
## What it is doing about the player: going for it, running for cover,
## waiting there, out of it to shoot, or getting away from something. Or
## nothing at all any more: it has lost its head.
enum Mode { HUNT, TO_COVER, COVER, PEEK, FLEE, PANIC }

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
## Loses its head when it has little health left or one of its own dies next
## to it, and does not find it again: it drops what it carries and runs about.
## Only for a model that can show that.
@export var panics := false
## It does so with this much of its health left, or when another dies this
## many metres from it, and then runs this much faster than it walks.
@export var panic_health := 0.4
@export var panic_radius := 8.0
@export var panic_pace := 1.35
## What the plate on its arm takes before it is shot off, and what the pack
## on its back takes before it is holed. Only for a model that has one.
@export var shield := 80.0
@export var pack := 0.0
## On watch: from how far it makes out somebody who stands in the light, and
## somebody who stands in the shade. A crouching player counts for less.
@export var sight_lit := 34.0
@export var sight_shade := 7.5
## How far it makes out somebody who stands in the dark by night: in neither
## moonlight nor the light of a lamp. See light_at() in scripts/land.gd.
@export var sight_dark := 5.0
@export var sight_crouched := 0.7
## How far to either side of its nose it sees, in degrees.
@export var sight_side := 58.0
## Seconds it takes to be sure of somebody at the edge of what it sees; of
## somebody close by, a fifth of that.
@export var notice_time := 1.7
## How fast it walks its round, in metres a second.
@export var round_pace := 1.25

var health := 0.0
var dead := false
## True if the last thing that hit it was stopped by its plate.
var deflected := false
## On watch: how sure it is that somebody is there, 0 to 1. At 1 it knows.
var awareness := 0.0

var _player: CharacterBody3D
var _alerted := false
var _has_los := false
## Where it last saw the player, whether smoke has come between them since,
## and the seconds it goes on firing at that spot.
var _seen_at := Vector3.ZERO
var _smoked := false
var _fires_on := 0.0
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
## Where it is running to without its head, and the seconds it still has for it.
var _bolt_to := Vector3.ZERO
var _bolt := 0.0
var _stun := 0.0
var _shield := 0.0
var _pack := 0.0
var _pack_fuse := -1.0
var _pack_flame: Node3D
var _choose_timer := 0.0
## True while it has its weapon on the one it is after.
var _aims := false
## True for one that is a person, see SIDEWAYS; and while it has turned its
## back to run for cover, see TURN_AND_RUN.
var _person := false
var _turned := false
## On watch, see watch(): the spots of its round and whether it goes round
## and round or there and back, the spot it is making for and which way
## along the round, how long it still waits, the way it faces when it stands
## guard and how far it looks to either side of that, and where it last saw
## what it is not sure of.
var _watching := false
var _round := PackedVector3Array()
var _round_loops := false
var _round_at := 0
var _round_step := 1
var _wait := 0.0
var _guards := 0.0
var _looks := 0.0
var _look := 0.0
var _suspect := Vector3.ZERO
## On a guest: where the host last said it was and which way it faced, and
## the id of the player it has its weapon on, 0 for nobody.
var _told_at := Vector3.ZERO
var _told_yaw := 0.0
var _told_aim := 0

@onready var agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	# Every machine has to cast the same character for the same enemy.
	var theme: String = Sandbox.theme if Sandbox.active else Settings.enemy_theme
	var cast := THEMES.cast(theme, role, String(name).hash() if Net.active else -1)
	var tuned := _tune(cast.get("tuning", {}))
	health = max_health
	_player = get_tree().get_first_node_in_group("player")
	if not (cast and _embody(cast, tuned)):
		_rig = model.instantiate()
		_rig.name = "Model"
		_rig.set_script(RIG)
		add_child(_rig)
	# What a shot sounds like on it: a person is not the steel a robot is.
	_person = _rig is HUMANOID
	$CollisionShape3D.set_meta(&"surface", "flesh" if _person else "metal")
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
	# A person only ducks if its way of moving has it go down on one knee.
	_can_crouch = _rig.has_method("crouch") and float(_rig.get("crouch_drop")) > 0.0
	panics = panics and _rig.has_method("panic")
	if _can_crouch:
		_drop = _rig.crouch_drop
		# The collider comes down with it, and is this enemy's alone for that.
		var collider: CollisionShape3D = $CollisionShape3D
		collider.shape = collider.shape.duplicate()
		_stand_height = (collider.shape as CapsuleShape3D).height
	_told_at = global_position
	_told_yaw = rotation.y


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
## is ducked behind something and 12 has its pack alight. 13 has lost its head
## and runs.
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
	if pose == 13.0 and _rig.has_method("panic"):
		_show_panic()
	else:
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
	# A character's head is where its rig has it, see HumanoidRig.head_start().
	if _rig and _rig.has_method(&"head_start"):
		return hit_position.y > _rig.head_start()
	return hit_position.y - global_position.y > head_start - (_drop if _crouched else 0.0)


## True once it knows of the player.
func is_alert() -> bool:
	return _alerted and not dead


## Puts it on watch, where it stands: it walks the spots of `beat` there and
## back, or round and round if it `loops`, or with no beat stands guard facing
## as it does and looking up to `looks` degrees to either side. It stays on
## watch until it knows of the player.
func watch(beat := PackedVector3Array(), loops := false, looks := 35.0) -> void:
	if _alerted or dead:
		return
	_watching = true
	_round = beat
	_round_loops = loops
	_round_at = 0
	_round_step = 1
	_guards = rotation.y
	_look = rotation.y
	_looks = deg_to_rad(looks)
	_wait = randf_range(0.0, LOOK_WAIT.y)
	add_to_group(&"watch")
	if not Blast.exploded.is_connected(_hears_blast):
		Blast.exploded.connect(_hears_blast)


## True while it is on watch and knows of nothing.
func is_watching() -> bool:
	return _watching and not _alerted and not dead


## Something loud at `at` that carries `reach` metres: a shot, a bang. One
## that is on watch and within earshot knows where to look.
func hears(at: Vector3, reach: float) -> void:
	if is_watching() and global_position.distance_to(at) < reach:
		alert()


func _hears_blast(at: Vector3) -> void:
	hears(at, SIGHT_RANGE * 1.4)


func alert() -> void:
	if _alerted or dead:
		return
	_alerted = true
	awareness = 1.0
	_attack_timer = randf_range(0.4, 1.2)
	if _watching:
		# Whoever is on watch with it will know in a moment: see game.gd.
		_watching = false
		remove_from_group(&"watch")
		disturbed.emit()
	Net.show(self, &"_show_alert")
	for other in get_tree().get_nodes_in_group("enemy"):
		if other.global_position.distance_to(global_position) < ALERT_RADIUS:
			other.alert()


## Loses its head, if it is one that does. There is no way back from that.
func panic() -> void:
	if not panics or dead or _mode == Mode.PANIC:
		return
	alert()
	if _attack != Attack.COOLDOWN:
		_end_attack(0.0)
	Squad.done_attacking(self, false)
	_leave_cover()
	_mode = Mode.PANIC
	_bolt = 0.0
	# The others hear of it with where it is, see net_state().
	_show_panic()


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
		Sfx.play_at(&"shield_block", hit_position, -6.0)
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
	Net.show(self, &"_show_hit", [hit_position, direction, amount, health])
	if health <= 0.0:
		_die()
	elif health <= max_health * panic_health:
		panic()
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
	if Net.is_guest():
		_follow(delta)
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	var desired := Vector3.ZERO
	if _pack_fuse >= 0.0:
		_burn_pack(delta)
	_aims = false
	_choose_timer -= delta
	if _choose_timer <= 0.0:
		_choose_timer = CHOOSE_TIME
		_choose()

	if not dead and is_instance_valid(_player) and not _player.dead:
		var eye := global_position + Vector3.UP * _eyes()
		var target: Vector3 = _player.head.global_position - Vector3.UP * 0.25
		var distance := eye.distance_to(target)

		_los_timer -= delta
		if _los_timer <= 0.0:
			_los_timer = 0.15
			_look_for_player(eye, target, distance)
		_fires_on -= delta
		if _smoked:
			# All it has to go on is where it last saw the player.
			target = _seen_at
			distance = eye.distance_to(target)
		if _watching and not _alerted:
			_notice(delta, target - eye, distance)
			if not _alerted:
				desired = _keep_watch(delta)
				_turn_towards(_face, delta, LOOK_PACE)
				_rig.lower()
		elif _has_los:
			alert()

		if _alerted:
			_stun = maxf(_stun - delta, 0.0)
			_face = target - eye
			var turned := _turned
			_turned = false
			desired = _decide(delta, distance, turned)
			if heeds_danger:
				desired = _mind_fire(desired)
			if _stun > 0.0:
				desired *= 0.25
			_turn_towards(_face, delta)
			_update_attack(delta, eye, target, distance)
			# The weapon is on the player for as long as there is a shot.
			if _has_los and distance < attack_range * 1.5 and _fights() and _stun <= 0.0 and not _turned:
				_aims = true
				_rig.aim(target)
			else:
				_rig.lower()

	var accel := ACCEL
	if _person and not dead:
		desired = _paced(desired)
		accel = pace_limits().accel
	velocity.x = move_toward(velocity.x, desired.x, accel * delta)
	velocity.z = move_toward(velocity.z, desired.z, accel * delta)
	move_and_slide()


## How freely a person moves at the difficulty that is set, see SIDEWAYS:
## the shares of its speed it goes sideways, backwards and with its weapon
## up, and how fast it gets going in m/s².
func pace_limits() -> Dictionary:
	var agility: float = Settings.rules().get("agility", 0.5)
	return {
		"sideways": lerpf(SIDEWAYS.x, SIDEWAYS.y, agility),
		"backwards": lerpf(BACKWARDS.x, BACKWARDS.y, agility),
		"aimed": lerpf(AIMED.x, AIMED.y, agility),
		"accel": lerpf(PERSON_ACCEL.x, PERSON_ACCEL.y, agility),
	}


## How fast a person can go that way, see SIDEWAYS: `desired`, or slower
## the further round it is from where the person faces.
func _paced(desired: Vector3) -> Vector3:
	var flat := Vector3(desired.x, 0.0, desired.z)
	var wanted := flat.length()
	if wanted < 0.01:
		return desired
	var ahead := -global_basis.z
	ahead = Vector3(ahead.x, 0.0, ahead.z).normalized()
	var along := flat / wanted
	var facing := ahead.dot(along)
	var limits := pace_limits()
	var share: float = lerpf(limits.sideways, 1.0, facing) if facing >= 0.0 else lerpf(limits.sideways, limits.backwards, -facing)
	if _aims:
		share = minf(share, limits.aimed)
	var most := speed * share
	if wanted <= most:
		return desired
	return Vector3(along.x * most, desired.y, along.z * most)


## Works out what to do and returns the velocity that goes with it; `_face`
## is left pointing where it should look meanwhile.
func _decide(delta: float, distance: float, turned := false) -> Vector3:
	if heeds_danger and _fights():
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
			return _run_for_cover(delta, turned)
		Mode.COVER:
			return _hold_cover(delta, distance)
		Mode.PEEK:
			return _lean_out(delta)
		Mode.PANIC:
			return _run_about(delta)
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


## Makes for its cover. `turned` is whether it ran there with its back to
## the player a moment ago: it keeps doing so until the cover is a good deal
## less far round, so that it does not keep turning to and fro.
func _run_for_cover(delta: float, turned := false) -> Vector3:
	_run += delta
	var step := _go_to(_cover.at, speed * COVER_PACE)
	if _flat(_cover.at) < 0.3:
		_mode = Mode.COVER
		_in_cover = 0.0
	elif _run > RUN_TIME:
		_leave_cover()
	elif step.length_squared() > 0.01 and (not _has_los or (_person and _flat_angle(_face, step) > TURN_AND_RUN - (0.4 if turned else 0.0))):
		# Out of sight, or a person with its cover behind it: it looks where
		# it runs.
		_face = step
		_turned = _has_los
	return step


## The angle between two directions seen from above, in radians.
func _flat_angle(a: Vector3, b: Vector3) -> float:
	var flat_a := Vector2(a.x, a.z)
	var flat_b := Vector2(b.x, b.z)
	if flat_a.length_squared() < 0.0001 or flat_b.length_squared() < 0.0001:
		return 0.0
	return absf(flat_a.angle_to(flat_b))


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


## Without its head: to one spot and then to another, wherever they happen
## to be, and never for long.
func _run_about(delta: float) -> Vector3:
	_bolt -= delta
	if _bolt <= 0.0 or _flat(_bolt_to) < 1.0:
		_bolt = randf_range(PANIC_TIME.x, PANIC_TIME.y)
		var way := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(PANIC_RUN.x, PANIC_RUN.y)
		_bolt_to = WAY.closest(agent.get_navigation_map(), global_position + way)
	var step := _go_to(_bolt_to, speed * panic_pace)
	if step.length_squared() > 0.01:
		_face = step
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
		agent.target_position = _seen_at if _smoked else _player.global_position
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


func _turn_towards(direction: Vector3, delta: float, pace := -1.0) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	var yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-(turn_speed if pace < 0.0 else minf(pace, turn_speed)) * delta))


# --- On watch ------------------------------------------------------------------


## How far off it makes out the player right now, who stands `to` from its
## eyes: far in the light, hardly in the shade, and outside what it looks at
## only what is at its shoulder or runs.
func _sees_as_far_as(to: Vector3) -> float:
	var crouched: bool = _player.has_method(&"is_crouched") and _player.is_crouched()
	var runs := Vector2(_player.velocity.x, _player.velocity.z).length() > RUNNING
	var flat := Vector3(to.x, 0.0, to.z).normalized()
	if flat.dot(-global_basis.z) < cos(deg_to_rad(sight_side)):
		return HEARS_RUNNING if runs else AT_ITS_SHOULDER
	var land := LAND.of(get_tree())
	var light: float = land.light_at(_player.global_position) if land else 1.0
	var least := sight_dark if land and land.by_night() else sight_shade
	var reach := lerpf(least, sight_lit, light) * (sight_crouched if crouched else 1.0)
	return maxf(reach, HEARS_RUNNING) if runs else reach


## Grows surer of the player while it has him in view, and less sure while it
## has not; sure, it knows.
func _notice(delta: float, to: Vector3, distance: float) -> void:
	var reach := _sees_as_far_as(to)
	if _has_los and distance < reach:
		awareness += delta / (notice_time * lerpf(0.2, 1.0, distance / reach))
		_suspect = _player.global_position
		if awareness >= 1.0:
			alert()
	else:
		awareness = maxf(awareness - FORGETS * delta, 0.0)


## Walks its round or stands guard, and returns the velocity that goes with
## it; `_face` is left pointing where it should look. One that thinks it saw
## something stops and looks that way.
func _keep_watch(delta: float) -> Vector3:
	if awareness > WARY:
		_face = _suspect - global_position
		return Vector3.ZERO
	_wait -= delta
	if _round.size() < 2:
		if _wait <= 0.0:
			_wait = randf_range(LOOK_WAIT.x, LOOK_WAIT.y)
			_look = _guards + randf_range(-_looks, _looks)
		_face = Vector3(-sin(_look), 0.0, -cos(_look))
		return Vector3.ZERO
	if _wait > 0.0:
		return Vector3.ZERO
	var goal := _round[_round_at]
	if _flat(goal) < 0.7:
		var last := _round.size() - 1
		if _round_loops:
			_round_at = (_round_at + 1) % _round.size()
		else:
			if (_round_at == last and _round_step > 0) or (_round_at == 0 and _round_step < 0):
				_round_step = -_round_step
				_wait = randf_range(ROUND_WAIT.x, ROUND_WAIT.y)
			_round_at += _round_step
		return Vector3.ZERO
	var step := _go_to(goal, round_pace)
	if step.length_squared() > 0.01:
		_face = step
	return step


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
			if set_to and _mode != Mode.COVER and _fights() and _faces(target, FACING) and (melee or Squad.may_attack(self)):
				_attack = Attack.TELEGRAPH
				_attack_timer = telegraph_time * Settings.rules().warning
				Net.show(self, &"_show_charge", [true])
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
	Net.show(self, &"_show_charge", [false])
	Squad.done_attacking(self)
	Squad.done_flanking(self)
	if _mode == Mode.PEEK:
		_mode = Mode.COVER


## False while it only runs, from something or from everything.
func _fights() -> bool:
	return _mode != Mode.FLEE and _mode != Mode.PANIC


## True if `target` is no further off its nose than the cosine `within`.
func _faces(target: Vector3, within: float) -> bool:
	var to := target - global_position
	to.y = 0.0
	return to.normalized().dot(-global_basis.z) > within


func _shoot(eye: Vector3, target: Vector3) -> void:
	var hurts: float = damage * Settings.rules().damage
	if melee:
		if eye.distance_to(target) < attack_range + 0.6:
			_player.take_damage(hurts, target, (target - eye).normalized())
		Net.show(self, &"_show_blow")
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
	# Whether it struck something that shows where: anything but a player.
	var struck := false
	if hit:
		end = hit.position
		struck = not hit.collider.is_in_group("player")
		# A stray shot sets off a fuel barrel as well as the player's does, and
		# hurts a player who was not the one it was meant for.
		if hit.collider.has_method("take_damage"):
			hit.collider.take_damage(damage if struck else hurts, end, direction)
	Net.show(self, &"_show_shot", [end, struck])


## Sees the player or does not. One that loses them to smoke, see Smoke.blocks(),
## goes on for a moment firing at where it last saw them, and goes there after.
func _look_for_player(eye: Vector3, target: Vector3, distance: float) -> void:
	var clear := distance < SIGHT_RANGE and _ray_hits_player(eye, target)
	if clear and Smoke.blocks(eye, target):
		if not _smoked:
			_fires_on = randf_range(FIRES_ON.x, FIRES_ON.y) if _has_los and _alerted and not melee else 0.0
			if not _has_los:
				_seen_at = target
		_smoked = true
		_has_los = _fires_on > 0.0
		return
	_smoked = false
	_has_los = clear
	if clear:
		_seen_at = target


func _ray_hits_player(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, LOS_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	# A player in a vehicle is seen in it, and the vehicle is what is shot.
	return not hit.is_empty() and (hit.collider == _player or (hit.collider == _player.get(&"riding") and hit.collider != null))


func _die() -> void:
	Net.show(self, &"_show_death", [_last_hit])
	# Whoever of its kind stood near enough loses its head over it.
	if panics:
		for other in get_tree().get_nodes_in_group("enemy"):
			if other.global_position.distance_to(global_position) < panic_radius:
				other.panic()


## Goes for whoever of the players is nearest and still standing. The one it
## is after stays that, unless another is clearly closer.
func _choose() -> void:
	var best: CharacterBody3D = null
	var nearest := INF
	if is_instance_valid(_player) and not _player.dead:
		best = _player
		nearest = global_position.distance_to(_player.global_position) * LOYALTY
	for body: CharacterBody3D in get_tree().get_nodes_in_group("player"):
		var distance := global_position.distance_to(body.global_position)
		if not body.dead and distance < nearest:
			best = body
			nearest = distance
	if best:
		_player = best


# --- What there is to see of it, on every machine ----------------------------


func _show_alert() -> void:
	if _shield > 0.0:
		_rig.guard(true)
	Sfx.play_at(_rig.sounds[&"alert"], global_position)


## `left` is the health it has left, which a guest counts its own shots
## against, see Net.damage().
func _show_hit(at: Vector3, direction: Vector3, amount: float, left: float) -> void:
	health = left
	_rig.hit(at, direction, amount)


func _show_charge(on: bool) -> void:
	_rig.charge(on)
	if on:
		_say(&"charge", -3.0)


func _show_panic() -> void:
	_rig.panic()


func _show_blow() -> void:
	_rig.fire()
	Sfx.play_at(_rig.sounds[&"melee"], global_position)


## A shot that went to `end`; `struck` if it left its mark on something there.
func _show_shot(end: Vector3, struck: bool) -> void:
	_rig.fire()
	var muzzle: Vector3 = _rig.muzzle()
	var along := (end - muzzle).normalized()
	if struck:
		# What it struck is looked up again here, where the mark is made.
		var query := PhysicsRayQueryParameters3D.create(end - along * 0.3, end + along * 0.3, LOS_MASK & 1, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit:
			Fx.impact(hit, along)
	Fx.tracer(muzzle, end, _rig.tracer_tint)
	Fx.muzzle_flash(null, Transform3D(Fx.facing(along), muzzle), flash_size, _rig.flash_prongs, _rig.flash_tint)
	Sfx.play_at(_rig.sounds[&"shot"], global_position)
	Sfx.passing(muzzle, end)


func _show_death(push: Vector3) -> void:
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
	_rig.collapse(push * 3.0)
	get_tree().create_timer(LINGER, false).timeout.connect(queue_free)


# --- On a guest: where the host says it is ------------------------------------


## What the copies of this enemy on the other machines need to be shown as it
## is here: where it is, which way it faces, how it moves and the id of the
## player it has its weapon on, 0 for nobody and -1 once it has lost its head.
func net_state() -> Array:
	var aimed := -1 if _mode == Mode.PANIC else 0
	if _aims and is_instance_valid(_player):
		aimed = _player.get(&"id") if _player.get(&"id") else 1
	return [global_position, rotation.y, velocity, aimed]


## The host's word on the above. `at_once` puts it there instead of letting it
## catch up, for somebody who walks into a fight that is going on.
func net_follow(at: Vector3, yaw: float, moving: Vector3, aimed: int, at_once := false) -> void:
	_told_at = at
	_told_yaw = yaw
	_told_aim = aimed
	velocity = moving
	if aimed < 0:
		_show_panic()
	if at_once:
		global_position = at
		rotation.y = yaw


## Carries on the way it was last said to be going, and closes in on where
## that should have brought it.
func _follow(delta: float) -> void:
	if dead:
		return
	_told_at += velocity * delta
	global_position = global_position.lerp(_told_at, 1.0 - exp(-18.0 * delta))
	rotation.y = lerp_angle(rotation.y, _told_yaw, 1.0 - exp(-14.0 * delta))
	var target := Net.body(_told_aim) if _told_aim > 0 else null
	if target:
		_rig.aim(target.head.global_position - Vector3.UP * 0.25)
	else:
		_rig.lower()
