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

const HUMANOID := preload("res://scripts/humanoid_rig.gd")
const WEAPONS := preload("res://scripts/weapons.gd")
const GRENADE := preload("res://scenes/grenade.tscn")
## Who it can be: soldier_01 and up, one for every player by its id.
const CHARACTER := "res://assets/characters/soldier_%02d/soldier_%02d.glb"
const CHARACTERS := 5
## Seconds it is shown behind what was last heard of it, so that there is a
## report on either side of that moment to go between.
const DELAY := 0.1
## The longest it carries on by itself when nothing is heard, in seconds.
const COAST := 0.25
const EYE := 1.6
const CROUCH_EYE := 0.95
const LAYER := 2
const HIT_MASK := 0b100101  # world + enemy + breakable

## The player it stands for, and what that one is called.
var id := 0
var title := ""
var dead := false
## Where its eyes are, which is what an enemy aims at.
var head := Node3D.new()

var _rig: Node3D
var _weapon := 0
var _doing := 0
## What was heard of it of late: [seconds, position, yaw, pitch, velocity].
var _reports: Array[Array] = []
var _label := Label3D.new()


func _ready() -> void:
	add_to_group("player")
	# Not there until it is heard of.
	collision_layer = 0
	collision_mask = 0
	visible = false
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	head.position.y = EYE
	add_child(head)
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
	var number := absi(id) % CHARACTERS + 1
	var path := CHARACTER % [number, number]
	var data: WeaponData = WEAPONS.LOADOUT[clampi(_weapon, 0, WEAPONS.LOADOUT.size() - 1)]
	var rig := HUMANOID.new()
	rig.name = "Model"
	if not ResourceLoader.exists(path) or not rig.setup({"character": load(path), "weapon": data.resource_path.get_file().get_basename(), "moves": "default"}):
		rig.free()
		return
	add_child(rig)
	_rig = rig


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
	head.position.y = CROUCH_EYE if _doing & Net.CROUCHED else EYE


func _process(_delta: float) -> void:
	if _rig == null or dead:
		return
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
			_rig.collapse(global_basis.z)
	elif not down and (dead or rearmed):
		_dress()
	dead = down
	collision_layer = 0 if dead else LAYER
	_label.visible = not dead


## It fired `weapon` of the loadout; `ends` is where each pellet ended up.
func fired(weapon: int, ends: PackedVector3Array) -> void:
	if _rig == null or dead:
		return
	var data: WeaponData = WEAPONS.LOADOUT[clampi(weapon, 0, WEAPONS.LOADOUT.size() - 1)]
	_rig.fire()
	var muzzle: Vector3 = _rig.muzzle()
	var space := get_world_3d().direct_space_state
	for i in ends.size():
		var end := ends[i]
		var along := (end - head.global_position).normalized()
		# What it struck is looked up again here, where the mark is made. An
		# enemy shows a hit itself, once the host says it was one.
		var query := PhysicsRayQueryParameters3D.create(end - along * 0.3, end + along * 0.3, HIT_MASK)
		var hit := space.intersect_ray(query)
		if hit and not hit.collider.has_method("is_headshot"):
			Fx.impact(hit, along, ends.size() > 1)
		if i % 3 == 0:
			Fx.tracer(muzzle, end)
	if not ends.is_empty():
		Fx.muzzle_flash(null, Transform3D(Fx.facing(ends[0] - muzzle), muzzle), data.flash_size, data.flash_prongs)
	Sfx.play_at(data.shot_sound, muzzle)
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


## It was hurt, which it shows.
func hurt(amount: float) -> void:
	if _rig and not dead:
		_rig.hit(global_position + Vector3.UP * 1.2, global_basis.z, amount)


# --- What the host's world does to it ----------------------------------------


## Each machine keeps the health of its own player, so this only passes it on.
func take_damage(amount: float, at: Vector3, direction: Vector3) -> bool:
	if not dead:
		Net.hurt(id, amount, at, direction)
	return false


## Thrown about by a blast, which is up to its own machine as well.
func shove(push: Vector3) -> void:
	Net.shove(id, push)
