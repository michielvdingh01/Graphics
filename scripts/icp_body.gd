extends CharacterBody3D
## The ICP of the Unmuted match (scripts/modes/icp.gd): the client both sides
## want, a big man who walks slowly to wherever the rules send him (`goal`)
## and stands where nothing does. He is nobody who plays: nothing hurts him,
## and a sticker that meets him is gone (see scripts/sticker.gd, which knows
## him by the group "icp").
##
## On the host he finds his own way over the navmesh; another machine is told
## where he is TELLS times a second and walks him there.

const HUMANOID := preload("res://scripts/humanoid_rig.gd")
## Who he looks like for now: a soldier, a size up. The man in the suit comes
## in step 3 of PLAN.md.
const LOOK := "res://assets/characters/soldier_04/soldier_04.glb"
const SIZE := 1.3
const RADIUS := 0.45
const HEIGHT := 1.8
## Where "ICP" stands over his head, in metres from his feet.
const MARK_AT := 2.75
const MARK := Color(1.0, 0.84, 0.3, 0.95)
const TURN := 3.0
const ACCEL := 3.0
## Seconds between two reports to the other machines, and how long another
## machine goes on walking him the way he went once a report is late.
const TELLS := 0.1
const COAST := 0.3

## Metres a second he walks, and where to; INF to stand.
var pace := 1.3
var goal := Vector3.INF

var _agent := NavigationAgent3D.new()
var _tell := 0.0
## On another machine: the last report, [the clock, where, facing, velocity].
var _heard: Array = []


func _ready() -> void:
	add_to_group(&"icp")
	# Where a shot looks, so that a sticker finds him; he stands on the world.
	collision_layer = 0b100
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS * SIZE
	capsule.height = HEIGHT * SIZE
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	shape.set_meta(&"surface", "flesh")
	add_child(shape)
	_agent.path_height_offset = 0.35
	_agent.path_desired_distance = 0.8
	_agent.target_desired_distance = 1.2
	_agent.path_search_max_polygons = 0
	_agent.radius = RADIUS
	add_child(_agent)
	var rig := HUMANOID.new()
	rig.name = "Model"
	if ResourceLoader.exists(LOOK) and rig.setup({"character": load(LOOK), "size": SIZE, "melee": true}):
		add_child(rig)
	else:
		rig.free()
	# Who he is can be read through walls, from anywhere.
	var label := Label3D.new()
	label.name = "Mark"
	label.text = "ICP"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0008
	label.font_size = 56
	label.outline_size = 14
	label.modulate = MARK
	label.position.y = MARK_AT
	add_child(label)


## True once he is where he was sent, or as near as the floor lets him come.
func arrived() -> bool:
	return goal == Vector3.INF or not _agent.is_inside_tree() or _agent.is_navigation_finished()


## Gone for a moment: somebody has won him over.
func vanish() -> void:
	visible = false
	goal = Vector3.INF
	velocity = Vector3.ZERO
	set_physics_process(false)
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred(&"disabled", true)


## Back, standing at `at`.
func appear(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	goal = Vector3.INF
	_heard.clear()
	visible = true
	set_physics_process(true)
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred(&"disabled", false)


func _physics_process(delta: float) -> void:
	if Net.is_guest():
		_follow()
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	var wanted := Vector3.ZERO
	if goal != Vector3.INF and _agent.is_inside_tree():
		if _agent.target_position.distance_to(goal) > 0.5:
			_agent.target_position = goal
		if not _agent.is_navigation_finished():
			var way := _agent.get_next_path_position() - global_position
			way.y = 0.0
			if way.length() > 0.05:
				wanted = way.normalized() * pace
	velocity.x = move_toward(velocity.x, wanted.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, wanted.z, ACCEL * delta)
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.2:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), 1.0 - exp(-TURN * delta))
	move_and_slide()
	_tell -= delta
	if _tell <= 0.0 and Net.active:
		_tell = TELLS
		Net.tell(self, &"_report", [global_position, rotation.y, velocity], false)


## Where the host has him, on another machine.
func _report(at: Vector3, facing: float, speed: Vector3) -> void:
	_heard = [Time.get_ticks_msec() * 0.001, at, facing, speed]


func _follow() -> void:
	if _heard.is_empty():
		return
	var since: float = Time.get_ticks_msec() * 0.001 - float(_heard[0])
	var there: Vector3 = _heard[1] + (_heard[3] as Vector3) * clampf(since, 0.0, COAST)
	velocity = _heard[3] if since < COAST else Vector3.ZERO
	global_position = global_position.lerp(there, 0.3) if global_position.distance_to(there) < 3.0 else there
	rotation.y = lerp_angle(rotation.y, float(_heard[2]), 0.3)
