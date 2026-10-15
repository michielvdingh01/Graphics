extends CharacterBody3D
## Somebody else's player as this machine shows it: a soldier that goes where
## its own machine says it is, carries what that one carries and fires when
## that one fires. scripts/game.gd stands one in the level for everybody else
## who is in it; what it does comes in through scripts/net.gd. Its scene is
## no more than this script on a body: everything else is put together here.
##
## To the enemies and to a blast on the host it is a player like the one of
## that machine: it is in the group "player", has a head to aim at, and what
## is done to it, it passes on to the machine it belongs to.
##
## In a match (scripts/match.gd) it is on a side, can be shot at, and may be
## a bot: then nobody's machine is behind it, and on the host it is moved by
## its brain (scripts/bot.gd) instead of by what is heard of it.

const HUMANOID := preload("res://scripts/humanoid_rig.gd")
const ROBOT := preload("res://scripts/enemy_rig.gd")
const WEAPONS := preload("res://scripts/weapons.gd")
const GRENADE := preload("res://scenes/grenade.tscn")
## Who it can be: soldier_01 and up, one for every player by its id.
const CHARACTER := "res://assets/characters/soldier_%02d/soldier_%02d.glb"
const CHARACTERS := 5
## The same soldiers in the uniform of the second side of a match, where
## there is one.
const SECOND := "res://assets/characters/soldier_%02d_desert/soldier_%02d_desert.glb"
## Seconds it is shown behind what was last heard of it, so that there is a
## report on either side of that moment to go between.
const DELAY := 0.1
## The longest it carries on by itself when nothing is heard, in seconds.
const COAST := 0.25
const EYE := 1.6
const CROUCH_EYE := 0.95
const LAYER := 2
const HIT_MASK := 0b100101  # world + enemy + breakable
## Above this height over its feet a shot is one to the head, and how much
## lower that is while it crouches.
const HEAD_START := 1.36
const CROUCH_DROP := 0.65
## What marks somebody on the side of this machine's player in a match.
const FRIEND := Color(0.35, 0.65, 1.0, 0.9)
## Nearer than the first, in metres, it strikes a pose every frame; nearer
## than the second every other frame, and further off every third. Out of
## sight it does so every fourth.
const POSED := Vector2(30.0, 70.0)
## Further than this from what the screen shows, in metres, a shot of it
## makes no flash at its muzzle and no mark where it lands; its streak and
## its sound stay.
const SHOWN := 80.0
## A robot of the route, for a bot in a match whose side is robots: its
## model, how wide and tall its body is to a shot, where its eyes are and
## where its head starts, and its visor. As scenes/enemy.tscn and
## scenes/enemy_heavy.tscn have them, so that a shot lands where it would on
## the route.
const ROBOTS := {
	"grunt": {"model": "res://scenes/models/grunt.scn", "radius": 0.4, "height": 1.8, "eye": 1.5, "head": 1.36, "visor": Color(1.0, 0.15, 0.1)},
	"heavy": {"model": "res://scenes/models/heavy.scn", "radius": 0.46, "height": 2.07, "eye": 1.72, "head": 1.56, "visor": Color(0.7, 0.1, 1.0)},
}
## A soldier, to a shot.
const SOLDIER := {"radius": 0.35, "height": 1.8, "eye": EYE, "head": HEAD_START}

## The player it stands for, and what that one is called.
var id := 0
var title := ""
var dead := false
## Where its eyes are, which is what an enemy aims at.
var head := Node3D.new()
## In a match: the side it is on, and whether it is a bot that this machine
## thinks for.
var team := -1
var driven := false
## Nothing it carries stops a shot: scripts/weapons.gd asks that of whatever
## has a head to hit.
var deflected := false

var _rig: Node3D
var _weapon := 0
var _doing := 0
## What was heard of it of late: [seconds, position, yaw, pitch, velocity].
var _reports: Array[Array] = []
var _label := Label3D.new()
## The layers it is on while it stands.
var _layer := LAYER
## Who it is in a match, if not a soldier: {character, voice, tint}, as
## scripts/enemy_themes.gd casts one, or {robot} with a kind of ROBOTS.
var _look := {}
## What it is to a shot: SOLDIER or one of ROBOTS.
var _build := SOLDIER
var _collider := CollisionShape3D.new()


func _ready() -> void:
	add_to_group("player")
	# Not there until it is heard of.
	collision_layer = 0
	collision_mask = 0
	visible = false
	_collider.shape = CapsuleShape3D.new()
	add_child(_collider)
	add_child(head)
	_fit(SOLDIER)
	_label.text = title
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.003
	_label.font_size = 40
	_label.outline_size = 8
	_label.modulate = Color(1, 1, 1, 0.85)
	_label.position.y = 2.05
	add_child(_label)
	_dress()


## Becomes its soldier, with the weapon its player has in hand. A change of
## weapon is a new figure: the rig takes up a weapon once, as it is set up.
func _dress() -> void:
	if _rig:
		remove_child(_rig)
		_rig.queue_free()
		_rig = null
	if _look.has("robot"):
		_robot(ROBOTS[_look.robot])
		return
	_fit(SOLDIER)
	var number := absi(id) % CHARACTERS + 1
	var path := CHARACTER % [number, number]
	if team == 1 and ResourceLoader.exists(SECOND % [number, number]):
		path = SECOND % [number, number]
	var data: WeaponData = WEAPONS.LOADOUT[clampi(_weapon, 0, WEAPONS.LOADOUT.size() - 1)]
	var rig := HUMANOID.new()
	rig.name = "Model"
	var cast := {"weapon": data.resource_path.get_file().get_basename(), "moves": "default"}
	if _look.has("character"):
		cast.merge(_look)
	elif ResourceLoader.exists(path):
		cast.character = load(path)
	if not cast.has("character") or not rig.setup(cast):
		rig.free()
		return
	add_child(rig)
	_rig = rig


## Becomes a robot of the route. Its weapon is its arm, whatever of the
## loadout it fires; the plate the grunt holds up on the route it has left
## behind, for nothing it carries stops a shot here.
func _robot(robot: Dictionary) -> void:
	var rig: Node3D = (load(robot.model) as PackedScene).instantiate()
	rig.name = "Model"
	rig.set_script(ROBOT)
	add_child(rig)
	rig.set_glow(robot.visor)
	rig.drop_shield()
	_rig = rig
	_fit(robot)


## Is as wide and tall to a shot as `build` says, with its eyes and the
## start of its head where that has them, and sounds like what it is made
## of when a shot lands, see Fx.surface_of().
func _fit(build: Dictionary) -> void:
	_build = build
	var capsule := _collider.shape as CapsuleShape3D
	capsule.radius = build.radius
	capsule.height = build.height
	_collider.position.y = capsule.height * 0.5
	_collider.set_meta(&"surface", "metal" if build.has("model") else "flesh")
	head.position.y = build.eye


## Where its eyes are, standing or ducked down.
func _eyes() -> float:
	return float(_build.eye) - (EYE - CROUCH_EYE if _doing & Net.CROUCHED else 0.0)


func _physics_process(_delta: float) -> void:
	if _reports.is_empty():
		return
	# The two reports that the moment to show lies between. Past the last one
	# it carries on the way it was going, for a moment.
	var now := Time.get_ticks_msec() * 0.001 - DELAY
	var i := _reports.size() - 1
	while i > 0 and _reports[i][0] > now:
		i -= 1
	var from := _reports[i]
	var pitch: float = from[3]
	if i + 1 < _reports.size():
		var to := _reports[i + 1]
		var between := clampf(inverse_lerp(from[0], to[0], now), 0.0, 1.0)
		global_position = (from[1] as Vector3).lerp(to[1], between)
		rotation.y = lerp_angle(from[2], to[2], between)
		pitch = lerpf(from[3], to[3], between)
		velocity = (from[4] as Vector3).lerp(to[4], between)
	else:
		var ahead: float = now - from[0]
		velocity = from[4] if ahead < COAST else Vector3.ZERO
		global_position = from[1] + from[4] * clampf(ahead, 0.0, COAST)
		rotation.y = from[2]
	head.rotation.x = pitch
	head.position.y = _eyes()


func _process(_delta: float) -> void:
	if _rig == null or dead:
		return
	# Far off, or out of sight, a figure strikes a pose less often. A robot
	# has no pose to strike.
	var camera := get_viewport().get_camera_3d()
	if camera and _rig is HUMANOID:
		var off := camera.global_position.distance_to(global_position)
		_rig.every = 1 if off < POSED.x else 4 if not camera.is_position_in_frustum(global_position + Vector3.UP) else 2 if off < POSED.y else 3
	# The weapon is on what its player looks at, and down while that one runs.
	if _doing & Net.SPRINTING:
		_rig.lower()
	else:
		_rig.aim(head.global_position - head.global_basis.z * 20.0)


## Strikes a pose for a screenshot of a puppet that nobody is behind: 1 with
## its weapon up, 2 in mid-stride as well, 3 running with its weapon down.
## Tenths choose the weapon of the loadout: 1.2 has the shotgun up.
func preview(pose: float) -> void:
	_weapon = roundi(fmod(pose, 1.0) * 10.0)
	_label.text = title if title else "Player"
	_dress()
	visible = true
	var stance := floorf(pose)
	if stance >= 2.0:
		velocity = -global_basis.z * (7.0 if stance == 3.0 else 4.0)
	if stance == 3.0:
		_rig.lower()
	else:
		_rig.aim(head.global_position - head.global_basis.z * 20.0)
	for i in 40:
		_rig._pose(0.03)


# --- What its own machine says of it, see net.gd ------------------------------


## Where it is, which way it looks, how it moves, what it is doing (the bits
## of net.gd) and which weapon of the loadout it has in hand.
func net_state(at: Vector3, yaw: float, pitch: float, speed: Vector3, doing: int, weapon: int) -> void:
	var down := doing & Net.DEAD != 0
	if dead and not down:
		# Back on its feet somewhere else: there is no way between the two.
		_reports.clear()
	if _reports.is_empty():
		global_position = at
		rotation.y = yaw
		visible = true
	_reports.append([Time.get_ticks_msec() * 0.001, at, yaw, pitch, speed])
	if _reports.size() > 12:
		_reports.pop_front()
	_doing = doing
	var rearmed := weapon != _weapon
	_weapon = weapon
	if down and not dead:
		if _rig:
			_collapse(global_basis.z)
	elif not down and (dead or rearmed):
		_dress()
	dead = down
	collision_layer = 0 if dead else _layer
	_label.visible = not dead and (not Match.active or _label.get_meta(&"friend", false))


## It fired `weapon` of the loadout; `ends` is where each pellet ended up.
func fired(weapon: int, ends: PackedVector3Array) -> void:
	if _rig == null or dead:
		return
	var data: WeaponData = WEAPONS.LOADOUT[clampi(weapon, 0, WEAPONS.LOADOUT.size() - 1)]
	_rig.fire()
	var muzzle: Vector3 = _rig.muzzle()
	# What a robot fires glows the colour it does on the route.
	var robot := _rig is ROBOT
	var space := get_world_3d().direct_space_state
	# What is further off than SHOWN makes no flash and no mark: in a match of
	# forty there are shots all over the land.
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera else muzzle
	for i in ends.size():
		var end := ends[i]
		var along := (end - head.global_position).normalized()
		if eye.distance_to(end) < SHOWN:
			# What it struck is looked up again here, where the mark is made.
			# An enemy shows a hit itself, once the host says it was one.
			var query := PhysicsRayQueryParameters3D.create(end - along * 0.3, end + along * 0.3, HIT_MASK)
			var hit := space.intersect_ray(query)
			if hit and not hit.collider.has_method("is_headshot"):
				Fx.impact(hit, along, ends.size() > 1)
		# The streak is also where the glass it went through breaks, so it is
		# always there.
		if i % 3 == 0 and robot:
			Fx.tracer(muzzle, end, _rig.tracer_tint)
		elif i % 3 == 0:
			Fx.tracer(muzzle, end)
	var flash := not ends.is_empty() and eye.distance_to(muzzle) < SHOWN
	if flash and robot:
		Fx.muzzle_flash(null, Transform3D(Fx.facing(ends[0] - muzzle), muzzle), data.flash_size, _rig.flash_prongs, _rig.flash_tint)
	elif flash:
		Fx.muzzle_flash(null, Transform3D(Fx.facing(ends[0] - muzzle), muzzle), data.flash_size, data.flash_prongs)
	Sfx.play_at(data.shot_sound, muzzle)
	if Match.active and not ends.is_empty():
		# Whoever it was meant for hears it go by.
		Sfx.passing(muzzle, ends[0])
	get_tree().call_group(&"watch", &"hears", muzzle, data.flash_size * WEAPONS.HEARD)


## It threw a grenade. The one shown here flies the same way and is gone when
## its time is up; the blast is that of the thrower's own.
func threw(from: Vector3, speed: Vector3, spin: Vector3) -> void:
	var grenade: RigidBody3D = GRENADE.instantiate()
	grenade.echo = true
	get_tree().current_scene.add_child(grenade)
	grenade.global_position = from
	grenade.linear_velocity = speed
	grenade.angular_velocity = spin
	Sfx.play_at(&"throw", from, -6.0)


## It was hurt, which it shows: at `at` and by something that came along
## `direction`, if that is known.
func hurt(amount: float, at := Vector3.INF, direction := Vector3.ZERO) -> void:
	if _rig and not dead:
		if at.is_finite():
			_rig.hit(at, direction, amount)
		else:
			_rig.hit(global_position + Vector3.UP * 1.2, global_basis.z, amount)


# --- In a match, see match.gd -------------------------------------------------


## Puts it on a side: the layers that side is on, `foes` those of who it can
## walk into, and `friend` if that is the side of this machine's player, whose
## own are marked and named through walls. `weapon` is what a bot carries, and
## `look` who it is if not a soldier.
func enlist(side: int, layers: int, foes: int, friend: bool, weapon := -1, look := {}) -> void:
	team = side
	_look = look
	_layer = LAYER | layers
	if driven:
		collision_mask = 1 | foes
	if weapon >= 0:
		_weapon = weapon
	_label.visible = friend
	_label.modulate = FRIEND
	_label.no_depth_test = friend
	_label.set_meta(&"friend", friend)
	_dress()


## True if a shot that landed at `at` is one to the head.
func is_headshot(at: Vector3) -> bool:
	return at.y - global_position.y > float(_build.head) - (CROUCH_DROP if _doing & Net.CROUCHED else 0.0)


## A bot goes down, pushed along `push`.
func fall(push: Vector3) -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	velocity = Vector3.ZERO
	_label.visible = false
	if _rig:
		_collapse(push)


## Goes down as what it is: a robot falls apart, with the sound it makes on
## the route.
func _collapse(push: Vector3) -> void:
	_rig.collapse(push)
	if _rig is ROBOT:
		Sfx.play_at(_rig.sounds[&"death"], global_position)


## A bot is back on its feet at `pose`, as good as new.
func rise(pose: Transform3D) -> void:
	dead = false
	_reports.clear()
	_doing = 0
	velocity = Vector3.ZERO
	global_position = pose.origin
	rotation = Vector3(0.0, pose.basis.get_euler().y, 0.0)
	head.rotation.x = 0.0
	visible = true
	collision_layer = _layer
	_label.visible = _label.get_meta(&"friend", false)
	_dress()


## What a bot is doing, the bits of net.gd: its brain says so.
func act(doing: int) -> void:
	_doing = doing


# --- What the host's world does to it ----------------------------------------


## Each machine keeps the health of its own player, so this only passes it on.
func take_damage(amount: float, at: Vector3, direction: Vector3) -> bool:
	if Match.active:
		# Whatever did this, a fire or a barrel, the match keeps count.
		return Match.harm(id, amount, at, direction)
	if not dead:
		Net.hurt(id, amount, at, direction)
	return false


## Thrown about by a blast, which is up to its own machine as well.
func shove(push: Vector3) -> void:
	if driven:
		velocity += push
	else:
		Net.shove(id, push)
