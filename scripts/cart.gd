extends RigidBody3D
## A shopping cart. It stands where somebody left it, rolls away from a shot or
## a shove, and can be pushed: `use` near it takes it by the handle, `use`
## again lets go. Pushed into a rack it goes home, see scripts/cart_rack.gd.
##
## Whoever pushes it runs it, as whoever drives a vehicle does: that machine
## moves it and tells the others where it is, through the same call a vehicle
## uses, and the rest follow. A cart nobody pushes is the host's.

## It lets itself be taken from this near, in metres.
const REACH := 2.0
## How far in front of who pushes it its middle goes, and how hard it is held
## there: how fast it may be made to go, in m/s.
const AHEAD := 1.05
const SPEED := 9.0
const TURNS := 8.0
## How it rolls by itself.
const ROLLS := 0.28
const STOPS := 1.6
## What a bullet gives it, per point of damage, in N s.
const KNOCK := 0.28
## Times a second somebody who pushes it tells the others.
const TOLD := 15.0

var home := false
## Who has it by the handle: a player on this machine, or null.
var pusher: CharacterBody3D
var _tell := 0.0
var _from := Transform3D()
var _to := Transform3D()
var _age := 1.0
var _rolled := 0.0
var _rattle: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group(&"cart")
	mass = 26.0
	gravity_scale = 1.0
	linear_damp = ROLLS
	angular_damp = 3.0
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	collision_layer = 1
	collision_mask = 1
	can_sleep = true
	var body := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.54, 0.86, 0.96)
	body.shape = box
	body.position = Vector3(0, 0.55, 0)
	add_child(body)
	var friction := PhysicsMaterial.new()
	friction.friction = 0.05
	friction.bounce = 0.1
	physics_material_override = friction
	if Net.is_guest():
		freeze = true


## The way a player takes it, or lets go.
func use_by(player: CharacterBody3D) -> void:
	if pusher:
		pusher = null
		return
	pusher = player
	if freeze and not home:
		freeze = false
	sleeping = false


func take_damage(amount: float, at: Vector3, direction: Vector3) -> bool:
	if not home:
		sleeping = false
		apply_impulse(direction * amount * KNOCK, at - global_position)
	Fx.strike(at, -direction, direction, "metal", true)
	return false


func take_blast(amount: float, at: Vector3, push: Vector3) -> void:
	if not home:
		sleeping = false
		apply_impulse(push * mass * 0.5 + (global_position - at).normalized() * amount * 0.4)


## It rolls into its place in the rack, `yaw` turned, and stays.
func go_home(spot: Vector3, yaw: float) -> void:
	home = true
	pusher = null
	freeze = true
	collision_layer = 0
	var tween := create_tween().set_parallel()
	tween.tween_property(self, ^"global_position", spot, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, ^"rotation:y", yaw, 0.4)
	tween.chain().tween_callback(func() -> void: Sfx.play_at(&"cart_nest", spot))


func _physics_process(delta: float) -> void:
	if home:
		return
	if is_instance_valid(pusher):
		if pusher.dead or pusher.global_position.distance_to(global_position) > REACH * 1.8:
			pusher = null
		else:
			_follow(delta)
	elif not freeze:
		_tell = 0.0
	if not freeze and not sleeping:
		_rolled += linear_velocity.length() * delta
		# A cart on tarmac wants to go on as it faces: what slides sideways
		# is taken out of it, as its wheels would.
		var across := global_basis.x
		linear_velocity -= across * linear_velocity.dot(across) * clampf(delta * STOPS * 3.0, 0.0, 1.0)
	_sound(delta)


## Goes to where whoever has it holds it.
func _follow(delta: float) -> void:
	var look: Vector3 = -pusher.global_basis.z
	var goal: Vector3 = pusher.global_position + look * AHEAD
	var offset := goal - global_position
	offset.y = 0.0
	linear_velocity = (offset / maxf(delta, 0.001) * 0.25).limit_length(SPEED) + Vector3(0, linear_velocity.y, 0)
	var wanted := atan2(-look.x, -look.z) + PI
	angular_velocity.y = clampf(wrapf(wanted - rotation.y, -PI, PI) * TURNS, -8.0, 8.0)
	_tell -= delta
	if _tell <= 0.0:
		_tell = 1.0 / TOLD
		Net.vehicle_state(self, [global_position, rotation.y])


## Where somebody else's push has it: see Net.vehicle_state().
func net_state(_sender: int, state: Array) -> void:
	if home or is_instance_valid(pusher):
		return
	if not freeze:
		freeze = true
	global_position = state[0]
	rotation.y = state[1]


func _sound(_delta: float) -> void:
	var speed := 0.0 if freeze else linear_velocity.length()
	if _rattle == null:
		if speed < 0.6 or not Sfx.has(&"cart_roll"):
			return
		_rattle = AudioStreamPlayer3D.new()
		_rattle.stream = Sfx.loop_of(&"cart_roll")
		_rattle.bus = &"World"
		_rattle.unit_size = 6.0
		add_child(_rattle)
		_rattle.play()
	_rattle.volume_db = linear_to_db(clampf(speed / 3.0, 0.03, 1.0))
	_rattle.pitch_scale = clampf(0.75 + speed * 0.12, 0.75, 1.4)
	if speed < 0.2:
		_rattle.queue_free()
		_rattle = null
