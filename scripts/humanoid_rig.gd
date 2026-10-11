extends Node3D
## Shows an enemy that is a person: one skinned character on Godot's humanoid
## skeleton, moved by the clips in assets/animations/moves.res. It answers to
## the same calls as enemy_rig.gd does for a robot, so enemy.gd need not know
## which of the two it is talking to.
##
## The clips say how a body walks, strikes, flinches and falls. On top of them
## this script turns the legs the way the body is going, so that one walk
## serves forwards, sideways and backwards; keeps a foot that is down where
## it came down, at the height the floor has there, so that it climbs a stair
## one foot above the other; puts a weapon to the shoulder with both hands on
## it; and throws the arms up of one that has lost its head. For those there
## are no clips.
##
## Everything it works out about bones is in the space of the skeleton, in
## which the character looks along +Z with its left arm along +X.

enum Hold { NONE, HANDS, SHOULDER }

const MOVES: AnimationLibrary = preload("res://assets/animations/moves.res")
const GLINT: Shader = preload("res://shaders/glint.gdshader")
const MODELS := "res://scenes/models/"
const WEAPON_DATA := "res://weapons/"
const FLINCHES: Array[String] = ["hit_chest", "hit_head"]
const FALLS: Array[String] = ["death", "death_mirror", "knockback", "fall_forward", "thrown_forward"]
const SIDES: Array[String] = ["Left", "Right"]
const TORSO: Array[String] = ["Spine", "Chest", "UpperChest"]
const ARM: Array[String] = ["Shoulder", "UpperArm", "LowerArm", "Hand"]
const NEEDED: Array[String] = ["UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot"]

## How far to either side of where it faces the chest may be turned, in
## radians (to its left is positive), and how the hips stand when it is
## still. A rifle only reaches the shoulder with the chest turned away
## from it.
const CHEST := {Hold.NONE: Vector2(-0.6, 0.6), Hold.HANDS: Vector2(-0.45, 0.3), Hold.SHOULDER: Vector2(-0.9, -0.2)}
const STANCE := {Hold.NONE: 0.0, Hold.HANDS: -0.1, Hold.SHOULDER: -0.35}
## The most the spine twists between hips and chest.
const TWIST := 1.2
## Walking backwards has to save this much twist before it is preferred, and
## a change of mind this much.
const RELUCTANCE := 0.5
const RESOLVE := 0.25
## Hip heights per second below which it counts as standing.
const STILL := 0.15
## A walk cycle is made to cover more or less ground than it was made for by
## stepping faster and by taking longer steps, in equal measure; this is
## how much shorter and longer a step may get.
const SHORTEST := 0.75
const LONGEST := 1.45
## Cycles per second the legs never exceed, however far behind they are.
const TOP_PACE := 1.7
## It breaks into the next faster cycle a little late: a cycle that is
## hurried looks better than the next one in slow motion.
const LATE := 1.1
## A foot that is down lets go when it is this many hip heights from where the
## clip wants it, or when the body has turned this far over it.
const FOOT_REACH := 0.38
const FOOT_TURN := 0.6
## The slowest and the fastest a blow is played to land in time.
const PACED := Vector2(0.5, 2.5)
## Damage within a moment that throws a body off its feet.
const BLOW := 60.0
## A shot that came in further round than this, in radians from straight in
## front, came from behind: the body goes down on its face.
const BEHIND := 2.2
## A foot is put no further above or below the floor under the body than
## this, in hip heights; a floor that is less than SLACK metres higher or
## lower is the same floor. Feet lie flat on a floor up to the first of
## LEVEL, in radians, and stay level on one steeper than the second: that
## is a stair.
const STEP_UP := 0.4
const STEP_DOWN := 0.4
const SLACK := 0.015
const LEVEL := Vector2(0.35, 0.5)
## Seconds a body lies there before it fades, and how long fading takes. The
## enemy that owns it is freed a little later, see LINGER in enemy.gd.
const CORPSE_TIME := 4.9
const FADE_TIME := 0.9
const STEP_RANGE := 30.0
## Shortest and longest breath between two screams of one that has lost its
## head, in seconds, and how loud it screams.
const BREATH := Vector2(0.25, 0.9)
const SCREAM_DB := -3.0

const GAIT := &"parameters/gait/blend_position"
const PACE := &"parameters/pace/scale"
const MOVE := &"parameters/move/blend_amount"
const ACT_CLIP := &"parameters/act_clip/transition_request"
const ACT_PACE := &"parameters/act_pace/scale"
const ACT := &"parameters/act/request"
const ACT_ACTIVE := &"parameters/act/active"
const FLINCH_CLIP := &"parameters/flinch_clip/transition_request"
const FLINCH := &"parameters/flinch/request"
const FALL_CLIP := &"parameters/fall_clip/transition_request"
const FALL := &"parameters/fall/blend_amount"
const CARRY := &"parameters/carry/blend_amount"


## Two bones and what they end in: an arm with its hand, a leg with its foot.
class Limb:
	var upper := -1
	var lower := -1
	var end := -1
	var upper_length := 0.0
	var lower_length := 0.0
	## From a frame of (along the bone, the axis the joint bends about, the
	## cross of the two) to the bone itself, see _solve().
	var upper_fix := Basis()
	var lower_fix := Basis()


## Set of moves -> the blend tree that plays it, shared by every rig.
static var _trees := {}
## Bones a skeleton lacks, as a string -> the moves without them.
static var _libraries := {}
static var _tinted := {}
static var _glint_material: ShaderMaterial

## What enemy.gd plays and draws for this enemy.
var sounds := {&"alert": &"human_alert", &"death": &"human_death", &"shot": &"enemy_shot", &"melee": &"swing"}
var tracer_tint := Color(1.0, 0.3, 0.2)
var flash_tint := Color(1.0, 0.62, 0.25)
var flash_prongs := 4
var flash_size := 0.3
## Heights above its feet, in metres, once it stands in the level: the top of
## its head, its eyes and where its head begins.
var fit := {"height": 1.8, "eyes": 1.6, "head": 1.5}

var _body: CharacterBody3D
var _figure: Node3D
var _skeleton: Skeleton3D
var _tree: AnimationTree
var _meshes: Array[MeshInstance3D] = []
## What was measured of each move, and the ways of moving there are: the
## clips to stand, walk and strike with. See assets/animations/manifest.json.
var _facts: Dictionary = MOVES.get_meta("moves")
var _sets: Dictionary = MOVES.get_meta("sets")
var _set: Dictionary = _sets["default"]
var _melee := false
var _windup := 0.3
var _hold := Hold.NONE
## True for one that fights hand to hand with something in its right hand,
## and where that sits in the hand: from the wrist to the thing.
var _wielding := false
var _haft := Transform3D()

# Bones, by index; -1 for one the character does not have.
var _parent := PackedInt32Array()
var _hips := -1
var _torso: Array[int] = []
var _head := -1
var _arms: Array[Limb] = []
var _legs: Array[Limb] = []
var _balls: Array[int] = []
## For each hand, from (along the fingers, out of the back of the hand, the
## cross of the two) to the bone.
var _hand_fix: Array[Basis] = [Basis(), Basis()]
var _head_ahead := Vector3.BACK
var _hip_height := 1.0
## Where each bone is this frame, worked out as it is asked for.
var _g := {}
var _upper := Basis()
var _lower := Basis()

# The weapon and how it is held, in its own space.
var _weapon: Node3D
var _muzzle: Node3D
var _glint: MeshInstance3D
var _grip: Array = [null, null]
var _butt := Vector3.ZERO
var _held := Transform3D()
var _glow := Color(1.0, 0.15, 0.1)

# Walking: for each cycle of the set its own pace, how far it gets, when its
# feet are down and the pace at which the next one takes over.
var _speeds := PackedFloat32Array()
var _strides := PackedFloat32Array()
var _downs: Array = []
var _switch := PackedFloat32Array()
var _gait := 0
var _gait_at := 0.0
var _stretch := 1.0
var _sink := 0.0
var _moving := 0.0
var _yaw := 0.0
var _backward := false
var _cycles := 0.0
var _steps := 0
## How far the body went of late and how far its speed says it should have:
## when the two differ it is walking on the spot, for a screenshot or a
## measurement, and there is no ground to hold a foot to.
var _went := Vector3.ZERO
var _due := Vector3.ZERO
var _was_at := Vector3.ZERO
var _on_the_spot := false
var _planted: Array[bool] = [false, false]
var _plant_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _plant_yaw: Array[float] = [0.0, 0.0]
var _slip: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
## How far the floor under each foot is above the floor under the body, in
## metres, and how that floor lies; `follow_floor` off leaves both feet at
## the height of the body, as tools/test_humanoid.sh does to compare.
var follow_floor := true
var _rise: Array[float] = [0.0, 0.0]
var _lie: Array[Vector3] = [Vector3.UP, Vector3.UP]
## Metres the feet have slid while they were down, and the seconds they were
## down for: what tools/test_humanoid.sh checks, with `measure` on. It
## switches `lock_feet` off to see what the clips do by themselves.
var measure := false
var slid := 0.0
var stood := 0.0
var lock_feet := true
var _ball_was: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _ankle: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _bent: Array[bool] = [false, false]
var _was_down: Array[bool] = [false, false]
var _measured: Array[bool] = [false, false]

# Aiming and fighting.
var _aiming := false
var _target := Vector3.ZERO
var _raised := 0.0
var _aim_yaw := 0.0
var _aim_pitch := 0.0
var _chest_yaw := 0.0
var _charging := false
var _charge := 0.0
var _struck := false
var _attack := 0
var _recoil := 0.0
var _flinch := Vector3.ZERO
var _flinched := -1.0
var _hurt := 0.0
var _hurt_at := -1.0
var _cried := -1.0
var _time := randf() * 10.0
## It has lost its head, and how far its arms are up for it.
var _panicking := false
var _thrown_up := 0.0
var _scream: AudioStreamPlayer3D
## Whose voice it has: the sounds <voice>_alert, _hurt, _death and _panic.
var _voice := "human"
var _breath := 0.0

# Dying.
var _dead := false
var _fallen := 0.0
var _fall_length := 2.4
var _spin := 0.0
var _landed := false
var _resting := false


## Dresses the rig as `cast` describes, see enemy_themes.gd: a character, a
## weapon or none, a set of moves. False if the character cannot be used.
func setup(cast: Dictionary) -> bool:
	_figure = (cast.character as PackedScene).instantiate() as Node3D
	if _figure == null:
		return false
	_skeleton = _figure.find_child("GeneralSkeleton", true, false) as Skeleton3D
	if _skeleton == null:
		var found := _figure.find_children("*", "Skeleton3D", true, false)
		_skeleton = found[0] if found else null
	if _skeleton == null or not _find_bones():
		push_warning("%s has no humanoid skeleton" % (cast.character as PackedScene).resource_path)
		_figure.free()
		return false
	# A character looks along +Z, an enemy along -Z.
	_figure.rotation.y = PI
	_figure.scale = Vector3.ONE * float(cast.get("size", 1.0))
	add_child(_figure)
	for player: Node in _figure.find_children("*", "AnimationPlayer", true, false):
		player.free()
	var tint: Dictionary = cast.get("tint", {})
	for mesh: MeshInstance3D in _figure.find_children("*", "MeshInstance3D", true, false):
		# Nothing that walks about has a lightmap; the probes light it.
		mesh.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		_meshes.append(mesh)
		for surface in mesh.get_surface_override_material_count():
			var material := mesh.get_active_material(surface)
			if material is BaseMaterial3D and tint.has(material.resource_name):
				mesh.set_surface_override_material(surface, _tint(material, Color(str(tint[material.resource_name]))))

	# A way of moving nobody has heard of is the usual one.
	_set = _sets.get(cast.get("moves", "default"), _sets["default"])
	_melee = cast.get("melee", false)
	_windup = cast.get("windup", 0.3)
	# Whose voice it has is the theme's to say; else it sounds as it moves.
	_voice = cast.get("voice", "")
	if _voice.is_empty():
		_voice = _set.voice
	sounds[&"alert"] = StringName(_voice + "_alert")
	sounds[&"death"] = StringName(_voice + "_death")
	# Whoever fights hand to hand strikes with what the theme gives it, if
	# that is something to strike with, and with its hands otherwise.
	var weapon: String = cast.get("weapon", "")
	if weapon != "" and not _melee:
		_arm(weapon)
	elif weapon != "" and _set.has("strikes"):
		_wield(weapon)
	if _weapon == null and not _melee:
		# Nothing in its hands, yet it shoots: it points, and its shots leave
		# from its fingers.
		_hold = Hold.HANDS
		_grip[1] = Transform3D()
		_muzzle = Marker3D.new()
		_skeleton.add_child(_muzzle)
	return true


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	for gait: String in _set.gaits:
		if not _speeds.is_empty():
			_switch.append(sqrt(_speeds[-1] * _facts[gait].speed) * LATE)
		_speeds.append(_facts[gait].speed)
		_strides.append(_facts[gait].stride)
		_downs.append([_facts[gait].down_left, _facts[gait].down_right])
	_gait_at = _speeds[0]

	_tree = AnimationTree.new()
	_tree.add_animation_library(&"", _library())
	_tree.tree_root = _blend_tree()
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(_tree)
	_tree.root_node = _tree.get_path_to(_skeleton)
	_tree.active = true

	_fingers("hand_relaxed", [0, 1])
	if _wielding:
		_fingers(_set.grip, [1])
		_tree.set(CARRY, 1.0)
	elif _hold == Hold.NONE:
		if _melee:
			_fingers(_set.fingers, [0, 1])
	else:
		_fingers("hand_grip", [1] if _grip[0] == null else [0, 1])
	if _muzzle:
		_glint = MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.material = _glint_shared()
		_glint.mesh = quad
		_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glint.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		_glint.extra_cull_margin = 3.0
		_glint.visible = false
		_muzzle.add_child(_glint)
	set_glow(_glow)

	# Not everybody breathes in time.
	_tree.set(MOVE, 0.0)
	_tree.advance(randf() * 2.5)
	_shape(0.0, 1.0)
	_g.clear()
	var size := _figure.scale.y
	var head := _global(_head).origin.y
	var top := head + 0.27 * _hip_height
	for mesh in _meshes:
		top = maxf(top, head + ((mesh.transform * mesh.get_aabb()).end.y - _rest_global(_head).origin.y))
	fit = {"height": top * size, "eyes": lerpf(head, top, 0.35) * size, "head": (head - 0.02) * size}
	# Whoever spawned it may still move it to where it belongs.
	_planted = [false, false]
	_was_at = _body.global_position if _body else Vector3.ZERO


## Colour of what announces an attack: the glint on its weapon.
func set_glow(color: Color) -> void:
	_glow = color
	if _glint:
		_glint.set_instance_shader_parameter(&"tint", Vector3(color.r, color.g, color.b))


## Brings the weapon to bear on a point; lower() lets it hang again.
func aim(target: Vector3) -> void:
	_aiming = true
	_target = target


func lower() -> void:
	_aiming = false


## The moment before an attack. With a weapon it comes up onto the target and
## glints; without one the blow is wound up, timed to land as fire() is called.
func charge(on: bool) -> void:
	if on == _charging:
		return
	_charging = on
	if _hold != Hold.NONE:
		return
	if on:
		_struck = false
		_swing(true)
	elif not _struck:
		_tree.set(ACT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


## A shot, or the moment a blow lands.
func fire() -> void:
	if _hold == Hold.NONE:
		if not _tree.get(ACT_ACTIVE):
			_swing(false)
		_struck = true
		_tree.set(ACT_PACE, 1.0)
	else:
		_recoil = 1.0
	if not can_process():
		# Nothing is running: this is a pose for a screenshot.
		_charging = true
		_charge = 1.0
		_pose(0.0)


## Loses its head: what it carried falls, its arms go up and stay up, and it
## screams for as long as it lives.
func panic() -> void:
	if _panicking or _dead:
		return
	_panicking = true
	_aiming = false
	_charging = false
	_tree.set(ACT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	_drop_weapon(Vector3.ZERO)
	if _wielding:
		_wielding = false
		_tree.set(CARRY, 0.0)
	if _muzzle:
		# It was pointing, and its shots left from there.
		_muzzle.queue_free()
		_muzzle = null
		_glint = null
	_hold = Hold.NONE
	_grip = [null, null]
	_fingers("hand_relaxed", [0, 1])
	_breath = randf() * 0.3


## Where its shots leave.
func muzzle() -> Vector3:
	return _muzzle.global_position if _muzzle else global_position + Vector3.UP * fit.eyes


## A hit at `at` that came in along `direction` and did `amount` of damage.
func hit(at: Vector3, direction: Vector3, amount := 0.0) -> void:
	Fx.blood(at, direction)
	var along := _skeleton.global_basis.inverse() * direction
	_flinch = Vector3(along.x, 0.0, along.z).normalized()
	if _time - _hurt_at > 0.15:
		_hurt = 0.0
	_hurt += amount
	_hurt_at = _time
	if _time - _flinched > 0.22:
		_flinched = _time
		var high: bool = at.y - global_position.y > fit.head
		_tree.set(FLINCH_CLIP, "hit_head" if high else "hit_chest")
		_tree.set(FLINCH, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if _time - _cried > 0.5:
		_cried = _time
		Sfx.play_at(StringName(_voice + "_hurt"), global_position, -4.0)


## Dies: it lets go of its weapon and falls, away from the shot that came in
## along `push` where there is room to.
func collapse(push: Vector3) -> void:
	_dead = true
	_aiming = false
	_charging = false
	var blown := _hurt >= BLOW and _time - _hurt_at < 0.15
	var fall: String = "knockback" if blown else ["death", "death_mirror"].pick_random()
	_spin = _room_to_fall(push)
	if is_nan(_spin):
		# From behind, and there is room in front of it: down on its face.
		fall = "thrown_forward" if blown else "fall_forward"
		_spin = _room_ahead(push)
	_fall_length = _facts[fall].length
	_tree.set(FALL_CLIP, fall)
	_tree.set(ACT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	if _glint:
		_glint.visible = false
	_drop_weapon(push)
	_wielding = false
	if is_instance_valid(_scream):
		# Cut short, but not with a click.
		var hush := _scream.create_tween()
		hush.tween_property(_scream, ^"volume_db", -60.0, 0.08)
		hush.tween_callback(_scream.queue_free)
	if not can_process():
		# Nothing is running: this is a pose for a screenshot.
		_fall(0.0)
		_fall(_fall_length + 1.0)


func _process(delta: float) -> void:
	_pose(delta)


func _pose(delta: float) -> void:
	_time += delta
	if _dead:
		_fall(delta)
		return

	# How fast and which way the body is going, as the skeleton sees it: in
	# hip heights per second, so that a tall character takes longer steps.
	var to_model := _skeleton.global_basis.inverse()
	var motion := to_model * _body.velocity if _body else Vector3.ZERO
	var speed := Vector2(motion.x, motion.z).length() / _hip_height
	if _body:
		var fade := exp(-4.0 * delta)
		var step := _body.global_position - _was_at
		# Put down somewhere else: that is not walking.
		if step.length() > 1.0:
			step = _body.velocity * delta
		_went = _went * fade + step
		_due = _due * fade + _body.velocity * delta
		_was_at = _body.global_position
		# Over the ground: up a stair it goes further than its speed says.
		var short := Vector2(_went.x - _due.x, _went.z - _due.z).length()
		_on_the_spot = _due.length() > 0.15 and short > 0.5 * _due.length()
	var facing := _aim_yaw * _raised
	var want := facing + float(STANCE[_hold])
	if speed > STILL:
		# The legs face the way it goes and walk forwards, or face the other
		# way and walk backwards: whichever twists the spine least.
		var heading := atan2(motion.x, motion.z)
		var reverse := wrapf(heading + PI, -PI, PI)
		var ahead := _strain(heading - facing) - (0.0 if _backward else RESOLVE)
		var behind := _strain(reverse - facing) + RELUCTANCE - (RESOLVE if _backward else 0.0)
		_backward = behind < ahead
		want = reverse if _backward else heading
	_yaw = lerp_angle(_yaw, want, 1.0 - exp(-12.0 * delta))

	# One cycle at a time: the slowest, until it would have to hurry too much.
	if _gait < _switch.size() and speed > _switch[_gait] * 1.06:
		_gait += 1
	elif _gait > 0 and speed < _switch[_gait - 1] * 0.94:
		_gait -= 1
	_gait_at = lerpf(_gait_at, _speeds[_gait], 1.0 - exp(-10.0 * delta))
	_moving = lerpf(_moving, clampf(speed / (_speeds[0] * 0.5), 0.0, 1.0), 1.0 - exp(-10.0 * delta))
	var moving := _moving if _moving > 0.02 else 0.0
	var pace := 0.0
	_stretch = 1.0
	if moving > 0.0:
		# The cycle has to cover this many times the ground it was made for.
		# Half of that comes from longer steps, see _walk(), half from faster ones.
		var pressed := speed / (moving * _speeds[_gait])
		_stretch = clampf(sqrt(pressed), SHORTEST, LONGEST)
		pace = minf(speed / (moving * _stretch * _strides[_gait]), TOP_PACE) * (-1.0 if _backward else 1.0)
	_tree.set(GAIT, _gait_at)
	_tree.set(PACE, pace)
	_tree.set(MOVE, moving)
	_tree.advance(delta)

	# A foot comes down at the start of the cycle and halfway.
	_cycles += pace * delta
	var steps := floori(_cycles * 2.0)
	if steps != _steps and _moving > 0.4:
		var ear := get_viewport().get_camera_3d()
		if ear and ear.global_position.distance_to(global_position) < STEP_RANGE:
			Sfx.play_at(&"human_step", global_position, -10.0)
	_steps = steps

	if _panicking and can_process():
		_wail(delta)
	_thrown_up = lerpf(_thrown_up, 1.0 if _panicking else 0.0, 1.0 - exp(-9.0 * delta))
	_raised = lerpf(_raised, 1.0 if _aiming else 0.0, 1.0 - exp(-9.0 * delta))
	_charge = lerpf(_charge, 1.0 if _charging else 0.0, 1.0 - exp(-14.0 * delta))
	_recoil = lerpf(_recoil, 0.0, 1.0 - exp(-14.0 * delta))
	_flinch = _flinch.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * delta))
	if _glint:
		_glint.visible = _charge > 0.02
		if _glint.visible:
			_glint.set_instance_shader_parameter(&"power", _charge)
	_shape(delta, 1.0)


## Everything the clips do not do, on top of what the tree has just posed.
## `hold_on` fades the work of the upper body out, as it dies.
func _shape(delta: float, hold_on: float) -> void:
	_g.clear()
	# The hips turn about the upright through the middle of the body, and
	# the legs with them.
	var hips := _global(_hips)
	var turn := Basis(Vector3.UP, _yaw)
	hips = Transform3D(turn * hips.basis, turn * hips.origin + Vector3.DOWN * _sink)
	var above := _global(_parent[_hips]) if _parent[_hips] >= 0 else Transform3D()
	var local := above.affine_inverse() * hips
	_skeleton.set_bone_pose_position(_hips, local.origin)
	_skeleton.set_bone_pose_rotation(_hips, local.basis.get_rotation_quaternion())
	_g[_hips] = hips
	if not _dead:
		_walk(delta)

	# The spine twists back so that the chest faces what it is doing, leans
	# with the aim and gives when it is hit.
	var facing := _aim_yaw * _raised
	var span: Vector2 = CHEST[_hold]
	var twist := clampf(clampf(_yaw, facing + span.x, facing + span.y) - _yaw, -TWIST, TWIST) * hold_on
	_chest_yaw = _yaw + twist
	var chest := Basis(Vector3.UP, _chest_yaw)
	var lean := (-_aim_pitch * 0.35 * _raised + 0.05 * _charge - 0.03 * _recoil) * hold_on
	if _hold == Hold.SHOULDER:
		# Into the weapon.
		lean += 0.1 * _raised * hold_on
	var give := Vector3.UP.cross(_flinch)
	var share := 1.0 / _torso.size()
	for bone in _torso:
		var stand := Basis(Vector3.UP, twist * share) * Basis(chest.x, lean * share) * _global(bone).basis
		if give.length_squared() > 0.0001:
			stand = Basis(give.normalized(), 0.32 * give.length() * share * hold_on) * stand
		_turn_to(bone, stand)

	if _hold != Hold.NONE and hold_on > 0.0:
		_carry(delta, chest, hold_on)
	if _thrown_up * hold_on > 0.01:
		_flail(chest, _thrown_up * hold_on)
	if _aiming and _hold == Hold.NONE:
		_aim_yaw = lerpf(_aim_yaw, _bearing(_global(_head).origin).x, 1.0 - exp(-12.0 * delta))
	_look(hold_on)
	if _wielding and _weapon:
		# It goes where the hand goes: the wrist has -Z along the fingers and
		# +Y out of the back of the hand, as the marker on the model has.
		var hand := _global(_arms[1].end)
		var grasp := hand.basis.orthonormalized() * _hand_fix[1].inverse()
		_weapon.transform = Transform3D(Basis(grasp.z, grasp.y, -grasp.x), hand.origin) * _haft


## Holds the weapon, or points: where it goes follows from what it is aimed
## at, and the arms follow the weapon.
func _carry(delta: float, chest: Basis, hold_on: float) -> void:
	var right: Limb = _arms[1]
	var shoulder := _global(right.upper).origin
	var head := _global(_head).origin
	var from := head
	var low := chest * Vector3(0.1, -0.74, 0.66).normalized()
	var rest := (_global(_arms[0].upper).origin + shoulder) * 0.5 + chest * Vector3(-0.06, -0.3, 0.27) * _hip_height
	if _hold == Hold.SHOULDER:
		# The butt sits in the pocket of the shoulder, lower when it hangs.
		from = shoulder + chest * Vector3(0.04, lerpf(-0.09, 0.02, _raised), 0.06) * _hip_height
		low = chest * Vector3(0.38, -0.62, 0.68).normalized()
	var bearing := _bearing(from)
	if _aiming:
		_aim_yaw = lerpf(_aim_yaw, bearing.x, 1.0 - exp(-12.0 * delta))
		_aim_pitch = lerpf(_aim_pitch, bearing.y, 1.0 - exp(-12.0 * delta))
	# Up on the target as it is about to fire, a little below it otherwise.
	var pitch := _aim_pitch - 0.14 * (1.0 - _charge) + 0.05 * _recoil
	var on := Vector3(sin(_aim_yaw) * cos(pitch), sin(pitch), cos(_aim_yaw) * cos(pitch))
	var along := low.slerp(on, _raised).normalized()
	var hold := Basis.looking_at(along, Vector3.UP)
	var origin: Vector3
	if _hold == Hold.SHOULDER:
		origin = from - along * 0.03 * _recoil * _hip_height - hold * _butt
	else:
		# At arm's length under the eyes, or drawn in against the chest.
		origin = rest.lerp(from + (along * 0.56 + Vector3.DOWN * 0.02) * _hip_height, _raised) - along * 0.03 * _recoil * _hip_height
	_held = Transform3D(hold, origin)
	if _weapon:
		_weapon.transform = _held
	elif _muzzle:
		_muzzle.position = origin + along * 0.15 * _hip_height

	for side in 2:
		if _grip[side] == null:
			continue
		var arm := _arms[side]
		var wrist: Transform3D = _held * (_grip[side] as Transform3D)
		# Elbows down and out.
		var pole := chest * (Vector3(0.35, -0.9, -0.25) if side == 0 else Vector3(-0.55, -0.75, -0.35))
		_solve(arm, _global(arm.upper).origin, wrist.origin, pole)
		_turn_to(arm.upper, _upper, hold_on)
		_turn_to(arm.lower, _lower, hold_on)
		var fingers := -wrist.basis.z
		var back := wrist.basis.y
		_turn_to(arm.end, Basis(fingers, back, fingers.cross(back)) * _hand_fix[side], hold_on)


## The arms of one that has lost its head: up over it and thrown about, palms
## to the front, and the head thrown back. `amount` is how far it has got.
func _flail(chest: Basis, amount: float) -> void:
	for side in 2:
		var arm := _arms[side]
		var out := 1.0 if side == 0 else -1.0
		var beat := _time * 9.0 + side * 2.2
		var shoulder := _global(arm.upper).origin
		var up := Vector3(out * (0.3 + 0.16 * sin(beat)), 0.8 + 0.1 * sin(beat * 0.7 + 1.0), 0.14 + 0.12 * cos(beat * 0.8))
		var wrist := shoulder + chest * up * (arm.upper_length + arm.lower_length)
		# Elbows out.
		_solve(arm, shoulder, wrist, chest * Vector3(out, -0.35, -0.1))
		_turn_to(arm.upper, _upper, amount)
		_turn_to(arm.lower, _lower, amount)
		var fingers := (wrist - _global(arm.lower).origin).normalized()
		var back := chest * Vector3(0.0, 0.0, -1.0)
		back = (back - fingers * fingers.dot(back)).normalized()
		_turn_to(arm.end, Basis(fingers, back, fingers.cross(back)) * _hand_fix[side], amount)
	var toss := Basis(Vector3.UP, 0.3 * sin(_time * 5.3)) * Basis(chest.x, -0.25 + 0.1 * sin(_time * 7.9))
	_turn_to(_head, toss * _global(_head).basis, amount)


## Screams, draws breath and screams again. The scream goes where it goes.
func _wail(delta: float) -> void:
	if is_instance_valid(_scream):
		return
	_breath -= delta
	if _breath <= 0.0:
		_breath = randf_range(BREATH.x, BREATH.y)
		_scream = Sfx.play_on(StringName(_voice + "_panic"), self, Vector3.UP * fit.eyes, SCREAM_DB)


## The head turns to what it is aiming at.
func _look(hold_on: float) -> void:
	var amount := _raised * hold_on
	if amount < 0.01:
		return
	var head := _global(_head)
	var ahead := head.basis * _head_ahead
	var to := _skeleton.global_transform.affine_inverse() * _target - head.origin
	var axis := ahead.cross(to.normalized())
	if axis.length_squared() < 0.0001:
		return
	var angle := minf(ahead.angle_to(to), 1.0) * 0.85 * amount
	var stand := Basis(axis.normalized(), angle) * head.basis
	if _hold == Hold.SHOULDER:
		# Cheek to the stock.
		stand = Basis(ahead, 0.22 * amount) * stand
	_turn_to(_head, stand)


## Fits the legs to the ground: steps are made as long as the pace asks, a
## foot that is down stays where it came down, each foot is as high as the
## floor is under it, and the hips come down as far as it takes for both legs
## to reach. The ankles go where that puts them and the legs bend to fit.
## Called when only the hips have been placed.
func _walk(delta: float) -> void:
	var to_world := _skeleton.global_transform
	var to_model := to_world.basis.inverse()
	var space: PhysicsDirectSpaceState3D = null
	if follow_floor and _body and is_inside_tree() and not _on_the_spot:
		space = get_world_3d().direct_space_state
	var heading := atan2(to_world.basis.z.x, to_world.basis.z.z) + _yaw
	var phase := fposmod(_cycles, 1.0)
	var reach := FOOT_REACH * _hip_height * _figure.scale.y
	var middle := _global(_hips).origin
	var travel := Basis(Vector3.UP, _yaw) * Vector3.BACK
	var deepest := 0.0
	for side in 2:
		var leg := _legs[side]
		# Where the clip has the foot, were the hips not sunk; then further
		# from the hips or nearer to them along the way it goes, for a longer
		# or a shorter step.
		var ankle := _global(leg.end).origin + Vector3.UP * _sink
		var further := travel * (ankle - middle).dot(travel) * (_stretch - 1.0)
		ankle += further
		var ball := to_world * (_global(_balls[side]).origin + Vector3.UP * _sink + further)
		var down := _moving < 0.05
		if not down:
			var from: Array = _downs[_gait][side]
			down = fposmod(phase - from[0], 1.0) < from[1] - from[0]
		var shift := _slip[side]
		if down and lock_feet and not _on_the_spot and not _planted[side]:
			_planted[side] = true
			_plant_at[side] = ball + shift
			_plant_yaw[side] = heading
		if _planted[side]:
			shift = _plant_at[side] - ball
			shift.y = 0.0
			if not down or _on_the_spot or shift.length() > reach or absf(angle_difference(heading, _plant_yaw[side])) > FOOT_TURN:
				_planted[side] = false
			# Put down somewhere else altogether: there is no stepping back from that.
			if shift.length() > reach * 4.0:
				shift = Vector3.ZERO
		if not _planted[side]:
			shift *= exp(-18.0 * delta)
		_slip[side] = shift
		_was_down[side] = down
		ankle += to_model * shift
		# The floor under this foot, next to the floor the body stands on.
		var under := _floor(space, ball + shift, to_world.origin.y)
		var settle := 1.0 - exp(-30.0 * delta)
		_rise[side] = lerpf(_rise[side], under[0], settle)
		_lie[side] = _lie[side].lerp(under[1], settle).normalized()
		if under[0] == 0.0 and absf(_rise[side]) < 0.0005:
			_rise[side] = 0.0
		ankle += to_model * Vector3(0.0, _rise[side], 0.0)
		_ankle[side] = ankle
		_bent[side] = _stretch != 1.0 or _sink > 0.0005 or shift.length_squared() > 0.000001 or _rise[side] != 0.0

		# How far the hips have to come down for this leg to reach that far.
		var hip := _global(leg.upper).origin + Vector3.UP * _sink
		var flat := Vector2(ankle.x - hip.x, ankle.z - hip.z).length_squared()
		var longest := (leg.upper_length + leg.lower_length) * 0.985
		deepest = maxf(deepest, hip.y - ankle.y - sqrt(maxf(longest * longest - flat, 0.0)))

	# Down at once, up again at leisure. A foot that stands lower than the
	# body may take the hips that much further down.
	deepest = minf(deepest, 0.2 * _hip_height + maxf(-minf(_rise[0], _rise[1]), 0.0) / _figure.scale.y)
	var sink := lerpf(_sink, deepest, 1.0 - exp(-(45.0 if deepest > _sink else 10.0) * delta))
	var drop := Vector3.DOWN * (sink - _sink)
	_sink = sink
	if drop.y != 0.0:
		var hips := _global(_hips)
		hips.origin += drop
		var above := _global(_parent[_hips]) if _parent[_hips] >= 0 else Transform3D()
		_skeleton.set_bone_pose_position(_hips, above.affine_inverse() * hips.origin)
		_g[_hips] = hips

	for side in 2:
		var leg := _legs[side]
		# These were worked out before the hips moved.
		var foot := _global(leg.end)
		var ball_at := _global(_balls[side]).origin
		if _bent[side] or drop.y != 0.0:
			var hip := _global(leg.upper).origin + drop
			var knee := _global(leg.lower).origin + drop
			_solve(leg, hip, _ankle[side], knee - hip)
			_turn_to(leg.upper, _upper)
			_turn_to(leg.lower, _lower)
			var keep := foot.basis
			if _planted[side]:
				keep = Basis(Vector3.UP, angle_difference(heading, _plant_yaw[side])) * keep
			# Flat on a floor that slopes; level on a stair.
			var lie := (to_model * _lie[side]).normalized()
			var slope := Vector3.UP.angle_to(lie)
			if slope > 0.01 and slope < LEVEL.y:
				keep = Basis(Vector3.UP.cross(lie).normalized(), slope * (1.0 - smoothstep(LEVEL.x, LEVEL.y, slope))) * keep
			_turn_to(leg.end, keep)
		if measure:
			# How far the foot really moved while the clip had it on the ground.
			var now := to_world * (_global(leg.end) * (foot.affine_inverse() * ball_at))
			if _was_down[side] and _measured[side] and delta > 0.0:
				slid += Vector2(now.x - _ball_was[side].x, now.z - _ball_was[side].z).length()
				stood += delta
			_measured[side] = _was_down[side]
			_ball_was[side] = now


## The floor under `at`, a point of the level: how far it is above `level`,
## the height the body stands at, in metres, and its normal. A floor that is
## out of reach of a foot, or that there is no `space` to look for in, is the
## floor the body stands on.
func _floor(space: PhysicsDirectSpaceState3D, at: Vector3, level: float) -> Array:
	if space == null:
		return [0.0, Vector3.UP]
	var leg := _hip_height * _figure.scale.y
	var from := Vector3(at.x, level + STEP_UP * leg, at.z)
	var found := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(at.x, level - STEP_DOWN * leg, at.z), 1))
	if found.is_empty():
		return [0.0, Vector3.UP]
	var rise: float = found.position.y - level
	return [signf(rise) * maxf(absf(rise) - SLACK, 0.0), found.normal]


## What is left of a life: the fall, and then nothing.
func _fall(delta: float) -> void:
	if _resting:
		return
	_fallen += delta
	_tree.set(FALL, minf(_fallen / 0.12, 1.0))
	_tree.advance(delta)
	_figure.rotation.y = PI + _spin * smoothstep(0.0, 0.35, _fallen)
	# The pose it died in lets go as the fall takes over.
	_yaw = lerp_angle(_yaw, 0.0, 1.0 - exp(-10.0 * delta))
	_sink = lerpf(_sink, 0.0, 1.0 - exp(-10.0 * delta))
	_flinch = _flinch.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * delta))
	var hold_on := 1.0 - smoothstep(0.0, 0.2, _fallen)
	if hold_on > 0.0 or absf(_yaw) > 0.002 or _sink > 0.002:
		_shape(delta, hold_on)

	if not _landed and _fallen > _fall_length * 0.4:
		_landed = true
		_g.clear()
		var chest := _skeleton.global_transform * _global(_torso[-1]).origin
		Sfx.play_at(&"body_fall", chest, -6.0)
		Fx.blood_pool(chest)
	if _fallen >= _fall_length + 0.1:
		# It lies still: nothing moves any more, so nothing is worked out.
		_resting = true
		_tree.active = false
		set_process(false)
		var fade := create_tween()
		fade.tween_interval(maxf(CORPSE_TIME - _fallen, 0.05))
		fade.tween_method(_fade, 0.0, 1.0, FADE_TIME)


func _fade(amount: float) -> void:
	for mesh in _meshes:
		mesh.transparency = amount


# --- Fighting ------------------------------------------------------------------


## Starts a blow. Wound up, it is paced to land when the wind-up is over, and
## it is one of the blows that can be: a quick one after a long wind-up would
## have landed and be on its way back by then.
func _swing(wound_up: bool) -> void:
	var attacks := _blows()
	if wound_up:
		var timely := attacks.filter(func(blow: String) -> bool: return _pace(blow) == clampf(_pace(blow), PACED.x, PACED.y))
		if timely.is_empty():
			# None of them: the one that comes nearest.
			timely = [attacks.reduce(func(best: String, blow: String) -> String: return blow if absf(log(_pace(blow))) < absf(log(_pace(best))) else best)]
		attacks = timely
	var attack: String = attacks[_attack % attacks.size()]
	_attack += 1 + randi() % 2
	var lands: float = _facts[attack].hit
	_tree.set(ACT_CLIP, attack)
	_tree.set(ACT_PACE, clampf(_pace(attack), PACED.x, PACED.y) if wound_up else 1.0)
	_tree.set(ACT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if not wound_up and not can_process():
		_tree.advance(0.0)
		_tree.advance(lands)


## How many times as fast a blow has to be played to land as its wind-up ends.
func _pace(blow: String) -> float:
	return _facts[blow].hit / maxf(_windup, 0.05)


## The blows it has: with what it holds, or with its hands.
func _blows() -> Array:
	return _set.strikes if _wielding else _set.attacks


## The bearing of the target from a point: x to its left, y up, in radians.
func _bearing(from: Vector3) -> Vector2:
	var to := _skeleton.global_transform.affine_inverse() * _target - from
	return Vector2(clampf(atan2(to.x, to.z), -1.3, 1.3), clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.0, 1.0))


## The twist it takes to stand with the hips at `yaw` from where it faces.
func _strain(yaw: float) -> float:
	yaw = wrapf(yaw, -PI, PI)
	var span: Vector2 = CHEST[_hold]
	return absf(yaw - clampf(yaw, span.x, span.y))


## The weapon falls where it was let go of and lies there as long as the body.
func _drop_weapon(push: Vector3) -> void:
	if _weapon == null:
		return
	var at := _weapon.global_transform
	var box := _bounds(_weapon)
	_weapon.get_parent().remove_child(_weapon)
	var shape := BoxShape3D.new()
	shape.size = box.size.max(Vector3.ONE * 0.03)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = box.get_center()
	var piece := RigidBody3D.new()
	# It lies on the level and is in nobody's way.
	piece.collision_layer = 0
	piece.collision_mask = 1
	piece.mass = 3.0
	piece.add_child(collider)
	piece.add_child(_weapon)
	_weapon.transform = Transform3D()
	get_tree().current_scene.add_child(piece)
	piece.global_transform = at.orthonormalized()
	_weapon.scale = at.basis.get_scale()
	piece.linear_velocity = (_body.velocity if _body else Vector3.ZERO) + push * 0.3 + Vector3.UP * 0.8
	piece.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
	var weapon := _weapon
	var tween := piece.create_tween()
	tween.tween_interval(CORPSE_TIME + randf() * 0.5)
	tween.tween_property(weapon, "scale", Vector3.ONE * 0.01, 0.6)
	tween.tween_callback(piece.queue_free)
	_weapon = null
	_muzzle = null
	_glint = null


## Most clips fall onto the back. This is how far to turn first, so that the
## body goes down away from the shot and not into a wall. NAN for one that
## was shot from behind and has room to go down on its face instead, see
## _room_ahead().
func _room_to_fall(push: Vector3) -> float:
	var along := global_basis.inverse() * push
	var away := atan2(along.x, along.z)
	if absf(away) > BEHIND:
		if not is_nan(_room_ahead(push)):
			return NAN
		# Nowhere to fall to in front of it: it goes down as it stands.
		away = 0.0
	away = clampf(away, -1.0, 1.0)
	if not is_inside_tree() or _body == null:
		return away
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.6
	for offset: float in [0.0, 0.8, -0.8, 1.6, -1.6, PI]:
		var back := global_basis * Basis(Vector3.UP, away + offset) * Vector3.BACK
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + back * 1.9, 1)).is_empty():
			return away + offset
	return away


## How far to turn one that falls on its face, so that it goes down the way
## the shot went; NAN if something stands in the way there.
func _room_ahead(push: Vector3) -> float:
	var along := global_basis.inverse() * push
	var turn := clampf(wrapf(atan2(along.x, along.z) - PI, -PI, PI), -1.0, 1.0)
	if not is_inside_tree() or _body == null:
		return turn
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.6
	for offset: float in [0.0, 0.6, -0.6]:
		var ahead := global_basis * Basis(Vector3.UP, turn + offset) * Vector3.FORWARD
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + ahead * 1.9, 1)).is_empty():
			return turn + offset
	return NAN


# --- Bones ---------------------------------------------------------------------


func _find_bones() -> bool:
	var count := _skeleton.get_bone_count()
	_parent.resize(count)
	for bone in count:
		_parent[bone] = _skeleton.get_bone_parent(bone)
	_hips = _skeleton.find_bone("Hips")
	_head = _skeleton.find_bone("Head")
	if _hips < 0 or _head < 0:
		return false
	for part in TORSO:
		if _skeleton.find_bone(part) >= 0:
			_torso.append(_skeleton.find_bone(part))
	if _torso.is_empty():
		return false
	for side in SIDES:
		for part in NEEDED:
			if _skeleton.find_bone(side + part) < 0:
				return false
	_hip_height = _rest_global(_hips).origin.y
	_head_ahead = _rest_global(_head).basis.transposed() * Vector3.BACK
	for i in 2:
		var side := SIDES[i]
		# In the T-pose an elbow bends about the upright and a knee about the
		# line from hip to hip; see _solve() for which way round.
		_arms.append(_limb(side + "UpperArm", side + "LowerArm", side + "Hand", Vector3.DOWN if i == 0 else Vector3.UP))
		_legs.append(_limb(side + "UpperLeg", side + "LowerLeg", side + "Foot", Vector3.RIGHT))
		var toes := _skeleton.find_bone(side + "Toes")
		_balls.append(toes if toes >= 0 else _legs[i].end)
		# There the fingers point out sideways and the palms face down.
		var fingers := Vector3.RIGHT if i == 0 else Vector3.LEFT
		_hand_fix[i] = Basis(fingers, Vector3.UP, fingers.cross(Vector3.UP)).transposed() * _rest_global(_arms[i].end).basis
	return true


func _limb(first: String, second: String, last: String, hinge: Vector3) -> Limb:
	var limb := Limb.new()
	limb.upper = _skeleton.find_bone(first)
	limb.lower = _skeleton.find_bone(second)
	limb.end = _skeleton.find_bone(last)
	var top := _rest_global(limb.upper)
	var middle := _rest_global(limb.lower)
	var bottom := _rest_global(limb.end)
	limb.upper_length = top.origin.distance_to(middle.origin)
	limb.lower_length = middle.origin.distance_to(bottom.origin)
	limb.upper_fix = _frame((middle.origin - top.origin) / limb.upper_length, hinge).transposed() * top.basis
	limb.lower_fix = _frame((bottom.origin - middle.origin) / limb.lower_length, hinge).transposed() * middle.basis
	return limb


## Where a bone is at rest. Worked out here: the skeleton itself only knows
## once it is in the tree.
func _rest_global(bone: int) -> Transform3D:
	var rest := _skeleton.get_bone_rest(bone)
	var parent := _skeleton.get_bone_parent(bone)
	return rest if parent < 0 else _rest_global(parent) * rest


## A frame whose X runs `along`, with Y as near to `across` as that allows.
func _frame(along: Vector3, across: Vector3) -> Basis:
	across = (across - along * along.dot(across)).normalized()
	return Basis(along, across, along.cross(across))


## Where a bone is now, given what the tree and this script have posed so far.
func _global(bone: int) -> Transform3D:
	if _g.has(bone):
		return _g[bone]
	var parent := _parent[bone]
	var at := _skeleton.get_bone_pose(bone)
	if parent >= 0:
		at = _global(parent) * at
	_g[bone] = at
	return at


## Turns a bone to stand as `stand`, or `amount` of the way there. Whatever
## hangs from it has to be asked for again afterwards.
func _turn_to(bone: int, stand: Basis, amount := 1.0) -> void:
	var above := _global(_parent[bone])
	var turn := (above.basis.transposed() * stand).get_rotation_quaternion()
	if amount < 1.0:
		turn = _skeleton.get_bone_pose_rotation(bone).slerp(turn, amount)
	_skeleton.set_bone_pose_rotation(bone, turn)
	_g[bone] = above * Transform3D(Basis(turn), _skeleton.get_bone_pose_position(bone))


## Bends a limb that starts at `from` so that it ends at `to`, with its elbow
## or knee out towards `pole`. The answer is left in _upper and _lower: how
## its two bones stand. The joint bends about the cross of `pole` and the
## line from start to end.
func _solve(limb: Limb, from: Vector3, to: Vector3, pole: Vector3) -> void:
	var line := to - from
	var longest := limb.upper_length + limb.lower_length
	var length := clampf(line.length(), absf(limb.upper_length - limb.lower_length) + 0.001, longest * 0.999)
	var along := line.normalized()
	var out := (pole - along * pole.dot(along)).normalized()
	var near := (limb.upper_length * limb.upper_length + length * length - limb.lower_length * limb.lower_length) / (2.0 * length)
	var off := sqrt(maxf(limb.upper_length * limb.upper_length - near * near, 0.0))
	var joint := along * near + out * off
	var hinge := out.cross(along)
	var first := joint / limb.upper_length
	var second := (along * length - joint) / limb.lower_length
	_upper = Basis(first, hinge, first.cross(hinge)) * limb.upper_fix
	_lower = Basis(second, hinge, second.cross(hinge)) * limb.lower_fix


## Sets the fingers of the given hands (0 left, 1 right) as a "hands" move has them.
func _fingers(move: String, hands: Array) -> void:
	var pose := MOVES.get_animation(move)
	for track in pose.get_track_count():
		var finger := String(pose.track_get_path(track).get_subname(0))
		var bone := _skeleton.find_bone(finger)
		if bone >= 0 and (1 if finger.begins_with("Right") else 0) in hands:
			_skeleton.set_bone_pose_rotation(bone, pose.track_get_key_value(track, 0))


# --- Setting up ----------------------------------------------------------------


## Puts a weapon in its hands: the model built for being carried if there is
## one, else the one the player holds without the player's hands.
func _arm(weapon: String) -> void:
	var path := MODELS + weapon + "_held.scn"
	if not ResourceLoader.exists(path):
		path = MODELS + weapon + ".scn"
	if not ResourceLoader.exists(path):
		push_warning("No weapon model %s" % weapon)
		return
	_weapon = (load(path) as PackedScene).instantiate()
	_skeleton.add_child(_weapon)
	for i in 2:
		var side := "L" if i == 0 else "R"
		var hand := _weapon.find_child("Hand" + side, true, false) as Node3D
		var arm := _weapon.find_child("Arm" + side, true, false) as Node3D
		if hand:
			_grip[i] = _within(hand, _weapon)
		elif arm:
			_grip[i] = _within(arm, _weapon)
		if arm:
			arm.get_parent().remove_child(arm)
			arm.free()
	_muzzle = _weapon.find_child("Muzzle", true, false) as Node3D
	if _muzzle == null:
		_muzzle = Marker3D.new()
		_weapon.add_child(_muzzle)
		_muzzle.position = Vector3(0, 0, _bounds(_weapon).position.z)
	if _grip[1] == null:
		_grip[1] = Transform3D(Basis(), Vector3(0.0, -0.1, 0.1))
	# Whatever reaches well back behind the trigger hand goes to the shoulder.
	var back := _bounds(_weapon).end.z
	_butt = Vector3(0.0, -0.035, back)
	_hold = Hold.SHOULDER if back - (_grip[1] as Transform3D).origin.z > 0.1 else Hold.HANDS

	if ResourceLoader.exists(WEAPON_DATA + weapon + ".tres"):
		var data := load(WEAPON_DATA + weapon + ".tres") as WeaponData
		flash_size = data.flash_size
		flash_prongs = data.flash_prongs
		if Sfx.has(data.shot_sound):
			sounds[&"shot"] = data.shot_sound


## Puts something to strike with in its right hand: a model that says of
## itself that it is one (the tag "wield"), with the marker HandR where the
## hand closes round it. Anything else it leaves where it is.
func _wield(weapon: String) -> void:
	var path := MODELS + weapon + ".scn"
	if not ResourceLoader.exists(path):
		push_warning("No weapon model %s" % weapon)
		return
	var model: Node3D = (load(path) as PackedScene).instantiate()
	var hand := model.find_child("HandR", true, false) as Node3D
	if hand == null or not model.get_meta("wield", false):
		model.free()
		return
	_weapon = model
	_skeleton.add_child(_weapon)
	_haft = _within(hand, _weapon).affine_inverse()
	_wielding = true


## The box around everything a model is made of, in its own space.
func _bounds(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var part := _within(mesh, model) * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	if model is MeshInstance3D and (model as MeshInstance3D).mesh:
		box = (model as MeshInstance3D).get_aabb() if first else box.merge((model as MeshInstance3D).get_aabb())
	return box


## Where a node of a model is, seen from the model.
func _within(node: Node3D, model: Node3D) -> Transform3D:
	var at := node.transform
	var above := node.get_parent() as Node3D
	while above != model:
		at = above.transform * at
		above = above.get_parent() as Node3D
	return at


func _tint(material: BaseMaterial3D, color: Color) -> Material:
	var key := [material, color]
	if not _tinted.has(key):
		var copy: BaseMaterial3D = material.duplicate()
		copy.albedo_color = color
		_tinted[key] = copy
	return _tinted[key]


func _glint_shared() -> ShaderMaterial:
	if _glint_material == null:
		_glint_material = ShaderMaterial.new()
		_glint_material.shader = GLINT
	return _glint_material


## The moves, without the tracks of bones this skeleton does not have: a
## track for a missing bone would move the skeleton as a whole.
func _library() -> AnimationLibrary:
	var missing := PackedStringArray()
	var sample := MOVES.get_animation("idle")
	for track in sample.get_track_count():
		var bone := String(sample.track_get_path(track).get_subname(0))
		if _skeleton.find_bone(bone) < 0 and not missing.has(bone):
			missing.append(bone)
	var key := ",".join(missing)
	if not _libraries.has(key):
		var library := AnimationLibrary.new()
		for move: String in MOVES.get_animation_list():
			if _facts[move].kind == "hands":
				continue
			var animation := MOVES.get_animation(move)
			if not missing.is_empty():
				animation = animation.duplicate()
				for track in range(animation.get_track_count() - 1, -1, -1):
					if missing.has(String(animation.track_get_path(track).get_subname(0))):
						animation.remove_track(track)
			library.add_animation(move, animation)
		_libraries[key] = library
	return _libraries[key]


## The tree that blends the clips of this set of moves: standing and walking,
## a blow over that from the waist up, a flinch over that, and the fall
## over everything.
func _blend_tree() -> AnimationNodeBlendTree:
	var key: String = _set.idle + ("+" + _set.carry if _wielding else "")
	if _trees.has(key):
		return _trees[key]
	var tree := AnimationNodeBlendTree.new()
	tree.add_node(&"idle", _clip(_set.idle))
	var gait := AnimationNodeBlendSpace1D.new()
	for move: String in _set.gaits:
		gait.add_blend_point(_clip(move), _facts[move].speed, -1, move)
	gait.set_min_space(_facts[_set.gaits[0]].speed)
	gait.set_max_space(_facts[_set.gaits[-1]].speed)
	# The cycles are all a second long and start on the same foot, so they
	# stay in step as long as they all run.
	gait.set_use_sync(true)
	tree.add_node(&"gait", gait)
	tree.add_node(&"pace", AnimationNodeTimeScale.new())
	tree.connect_node(&"pace", 0, &"gait")
	tree.add_node(&"move", AnimationNodeBlend2.new())
	tree.connect_node(&"move", 0, &"idle")
	tree.connect_node(&"move", 1, &"pace")

	var upper_body := TORSO + ["Neck", "Head"]
	for side in SIDES:
		for part in ARM:
			upper_body.append(side + part)
	var below := &"move"
	if _wielding:
		# What it strikes with it carries at the ready, whatever its legs do.
		var carry := AnimationNodeBlend2.new()
		carry.set_filter_enabled(true)
		for part in ARM:
			carry.set_filter_path(NodePath(".:Right" + part), true)
		tree.add_node(&"carry", carry)
		tree.add_node(&"carry_clip", _clip(_set.carry))
		tree.connect_node(&"carry", 0, &"move")
		tree.connect_node(&"carry", 1, &"carry_clip")
		below = &"carry"
	_choice(tree, &"act_clip", _blows())
	tree.add_node(&"act_pace", AnimationNodeTimeScale.new())
	tree.connect_node(&"act_pace", 0, &"act_clip")
	tree.add_node(&"act", _one_shot(upper_body, 0.08, 0.2))
	tree.connect_node(&"act", 0, below)
	tree.connect_node(&"act", 1, &"act_pace")

	_choice(tree, &"flinch_clip", FLINCHES)
	tree.add_node(&"flinch", _one_shot(TORSO + ["Neck", "Head"], 0.04, 0.15))
	tree.connect_node(&"flinch", 0, &"act")
	tree.connect_node(&"flinch", 1, &"flinch_clip")

	_choice(tree, &"fall_clip", FALLS)
	tree.add_node(&"fall", AnimationNodeBlend2.new())
	tree.connect_node(&"fall", 0, &"flinch")
	tree.connect_node(&"fall", 1, &"fall_clip")
	tree.connect_node(&"output", 0, &"fall")
	_trees[key] = tree
	return tree


func _clip(move: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = move
	return node


## A node that plays whichever of `moves` it is asked for by name.
func _choice(tree: AnimationNodeBlendTree, node_name: StringName, moves: Array) -> void:
	var choice := AnimationNodeTransition.new()
	tree.add_node(node_name, choice)
	for i in moves.size():
		choice.add_input(moves[i])
		var clip_name := StringName("%s_%s" % [node_name, moves[i]])
		tree.add_node(clip_name, _clip(moves[i]))
		tree.connect_node(node_name, i, clip_name)


func _one_shot(bones: Array, fade_in: float, fade_out: float) -> AnimationNodeOneShot:
	var node := AnimationNodeOneShot.new()
	node.fadein_time = fade_in
	node.fadeout_time = fade_out
	node.set_filter_enabled(true)
	for bone: String in bones:
		node.set_filter_path(NodePath(".:" + bone), true)
	return node
