extends CharacterBody3D
## The ICP of the Unmuted match (scripts/modes/icp.gd): the client both sides
## want, a big man who walks slowly to wherever the rules send him (`goal`)
## and stands where nothing does. He is nobody who plays: nothing hurts him,
## and a sticker that meets him is gone (see scripts/sticker.gd, which knows
## him by the group "icp").
##
## On the host he finds his own way over the navmesh; another machine is told
## where he is TELLS times a second and walks him there.
##
## Every four of his steps a banknote falls out of his pocket and flutters
## down, and lies there BILL_LIES seconds; and when he is won over he goes in
## a shower of them. That is on every machine by itself, for it is only to be
## seen.

const HUMANOID := preload("res://scripts/humanoid_rig.gd")
## Who he looks like: a man in a black suit with a grin and sunglasses
## (tools/unmuted/build_people.sh), a size up.
const LOOK := "res://assets/characters/icp_01/icp_01.glb"
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
## The banknotes: the picture (tools/unmuted/stickers.py), how big one is in
## metres (twice as big as a dollar, to be seen), every how many metres
## he walks one falls (four of his steps), how fast it falls, how long it
## lies, how many there are at most, and how many go up when he is won over.
const BILL := "res://assets/unmuted/bill.png"
const BILL_SIZE := Vector2(0.31, 0.133)
const BILL_EVERY := 3.6
const BILL_FALLS := 0.75
const BILL_LIES := 15.0
const BILL_MOST := 60
const RAIN := 36
## How loud a banknote is as it falls, in dB, and one in how many of the
## shower is heard.
const RUSTLE_DB := -16.0
const RUSTLE_EVERY := 6

## Metres a second he walks, and where to; INF to stand.
var pace := 1.3
var goal := Vector3.INF

var _agent := NavigationAgent3D.new()
var _tell := 0.0
## On another machine: the last report, [the clock, where, facing, velocity].
var _heard: Array = []
## The banknotes, in a node of their own in the level, for they stay where
## they fell: [the note, the floor under it, its age, a phase of its own, the
## way it drifts].
var _money: Node3D
var _bills: Array = []
var _walked := 0.0
var _was := Vector3.INF
var _note_look: StandardMaterial3D
var _note_mesh: QuadMesh


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
	_note_mesh = QuadMesh.new()
	_note_mesh.orientation = PlaneMesh.FACE_Y
	_note_mesh.size = BILL_SIZE
	_note_look = StandardMaterial3D.new()
	_note_look.albedo_texture = load(BILL)
	_note_look.cull_mode = BaseMaterial3D.CULL_DISABLED
	_note_look.roughness = 0.9
	_money = Node3D.new()
	_money.name = "Money"
	get_parent().add_child.call_deferred(_money)


func _exit_tree() -> void:
	if is_instance_valid(_money):
		_money.queue_free()


## A banknote, for Fx.rehearse().
func looks() -> Array[MeshInstance3D]:
	var note := MeshInstance3D.new()
	note.mesh = _note_mesh
	note.material_override = _note_look
	return [note]


## True once he is where he was sent, or as near as the floor lets him come.
func arrived() -> bool:
	return goal == Vector3.INF or not _agent.is_inside_tree() or _agent.is_navigation_finished()


## Gone for a moment, in a shower of banknotes: somebody has won him over.
func vanish() -> void:
	if visible:
		for i in RAIN:
			var off := Vector3(randf_range(-0.8, 0.8), randf_range(0.8, 3.2), randf_range(-0.8, 0.8))
			_drop(global_position + off, Vector3(off.x, 0.0, off.z) * 1.2)
			if i % RUSTLE_EVERY == 0:
				Sfx.play_at(&"money_drop", global_position + off, RUSTLE_DB + 4.0)
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


func _process(delta: float) -> void:
	if visible:
		if _was != Vector3.INF:
			var step := global_position - _was
			step.y = 0.0
			if step.length() < 2.0:
				_walked += step.length()
		_was = global_position
		if _walked >= BILL_EVERY:
			_walked -= BILL_EVERY
			# Out of a pocket of his jacket, on one side or the other.
			var pocket := global_position + Vector3.UP * 1.05 * SIZE + global_basis.x * (0.28 * SIZE * (1.0 if randf() < 0.5 else -1.0))
			_drop(pocket, -global_basis.z * 0.2)
			Sfx.play_at(&"money_drop", pocket, RUSTLE_DB)
	for i in range(_bills.size() - 1, -1, -1):
		var line: Array = _bills[i]
		var note: MeshInstance3D = line[0]
		line[2] += delta
		var age: float = line[2]
		if age > BILL_LIES or not is_instance_valid(note):
			if is_instance_valid(note):
				note.queue_free()
			_bills.remove_at(i)
			continue
		var phase: float = line[3]
		if note.global_position.y > float(line[1]) + 0.012:
			# Fluttering down: it sways from side to side and tumbles.
			var sway := Vector3(sin(age * 2.6 + phase), 0.0, cos(age * 2.1 + phase)) * 0.45
			note.global_position += ((line[4] as Vector3) + sway) * delta + Vector3.DOWN * BILL_FALLS * delta
			note.global_position.y = maxf(note.global_position.y, float(line[1]) + 0.01)
			note.basis = Basis.from_euler(Vector3(sin(age * 3.1 + phase) * 0.9, age * 1.7 + phase, cos(age * 2.4 + phase) * 0.7))
		else:
			note.basis = Basis(Vector3.UP, phase)
		if age > BILL_LIES - 1.0:
			note.scale = Vector3.ONE * maxf(BILL_LIES - age, 0.01)


## A banknote at `at`, drifting along `drift` as it falls.
func _drop(at: Vector3, drift: Vector3) -> void:
	if not is_instance_valid(_money) or not _money.is_inside_tree():
		return
	var floor_y := at.y - 3.0
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 30.0, 1, [get_rid()]))
	if hit:
		floor_y = (hit.position as Vector3).y
	var note := MeshInstance3D.new()
	note.mesh = _note_mesh
	note.material_override = _note_look
	note.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_money.add_child(note)
	note.global_position = at
	_bills.append([note, floor_y, 0.0, randf() * TAU, drift])
	while _bills.size() > BILL_MOST:
		var oldest: Array = _bills.pop_front()
		if is_instance_valid(oldest[0]):
			(oldest[0] as Node).queue_free()


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
