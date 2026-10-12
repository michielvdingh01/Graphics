extends Node3D
## Something two teams fight over: a flag, a football, a banana as long as a
## rifle. assets/prizes.json lists what there is: the model of each and the
## stand it has at home (scenes in scenes/models/, built by
## tools/models/prizes.gd), and how it sits at home, on whoever carries it and
## on the ground.
##
## This node is the home of one prize. It stands where the prize belongs, with
## the stand, and the prize itself is at home, carried or down. It knows
## nothing of the rules of a game: it says who touches the prize and who comes
## to the stand, and does as it is told with take(), drop() and send_home().
## Whoever runs the match decides what a touch comes to.
##
## Whoever carries it bears it on a rig that knows how (bear() of
## scripts/humanoid_rig.gd, which a puppet has and an enemy that is a person),
## and on its own back otherwise, as the player of this machine does.

## Somebody has come within reach of the prize, which is at home or down.
signal touched(body: Node3D)
## Somebody has come to the stand.
signal reached(body: Node3D)
## It was taken, dropped or sent home.
signal moved

enum State { HOME, CARRIED, DOWN }

const TABLE := "res://assets/prizes.json"
const MODELS := "res://scenes/models/%s.scn"
## How near somebody has to come to touch it, or to count as at the stand.
const REACH := 1.0
## The layer of what can touch it, the players, and that of the level.
const PLAYERS := 2
const WORLD := 1
## The light around it where it stands or lies, as a pickup has: enough to
## find it by in a dark hall.
const GLOW := 0.3
const GLOW_REACH := 2.2
## Where the back and the hips are of somebody without a rig, in metres above
## the feet, and what a hip height is then.
const WITHOUT_RIG := {"back": 1.36, "hips": 0.98}
const HIP_HEIGHT := 0.98
## A flag stands out straight on somebody who goes this fast, in m/s.
const FULL_WIND := 7.0
## Whose it is in a picture, see preview(): nobody's, and the two sides.
const PREVIEW_TINTS: Array[Color] = [Color(0.5, 0.5, 0.5), Color(0.1, 0.34, 0.85), Color(0.95, 0.42, 0.06)]

static var _prizes := {}
static var _read := false

## Which prize it is: a name from the table.
@export var kind := "flag"
## Whose it is: the number of a team, or -1 for nobody's. And the colour of
## that team, which the prize and its stand take on.
@export var team := -1
@export var tint := Color(0.5, 0.5, 0.5)

var state := State.HOME
## Who has it, while it is carried.
var carrier: Node3D
## Seconds it has lain where it was dropped.
var down_for := 0.0

var _spec := {}
var _stand: Node3D
## What moves: the model of the prize under a node that is where the prize
## is, with the ball around it that feels who touches it and its light.
var _item: Node3D
var _model: Node3D
var _touch: Area3D
var _base: Area3D
var _light: OmniLight3D
## The rig that bears it, if whoever carries it has one.
var _rig: Node3D


## Every prize there is, by the name the table has for it.
static func kinds() -> PackedStringArray:
	return PackedStringArray(_all().keys())


## What the table says of one prize; nothing for one it does not know.
static func spec(of: String) -> Dictionary:
	var found: Variant = _all().get(of)
	return found if found is Dictionary else {}


static func _all() -> Dictionary:
	if not _read:
		_read = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE)) if FileAccess.file_exists(TABLE) else null
		var listed: Variant = parsed.get("prizes") if parsed is Dictionary else null
		if listed is Dictionary:
			_prizes = listed
		else:
			push_warning("%s lists no prizes" % TABLE)
	return _prizes


func _ready() -> void:
	_build()


## Puts the stand and the prize together as `kind`, `team` and `tint` say,
## with the prize at home.
func _build() -> void:
	if state == State.CARRIED and is_instance_valid(_item):
		_dismount()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_stand = null
	_item = null
	_model = null
	_base = null
	carrier = null
	state = State.HOME
	down_for = 0.0
	_spec = spec(kind)
	if _spec.is_empty():
		push_warning("No prize called '%s'; there is %s." % [kind, ", ".join(kinds())])
		return
	_stand = _scene(str(_spec.get("stand", "")))
	if _stand:
		_stand.name = "Stand"
		add_child(_stand)
	_base = _reach("Base", self, reached)
	_make_item()
	_dress()
	_settle()
	if is_inside_tree() and not Benchmark.active:
		Fx.rehearse(_looks())


## The prize itself, new and at home.
func _make_item() -> void:
	_item = Node3D.new()
	_item.name = "Prize"
	add_child(_item)
	_model = _scene(str(_spec.get("model", "")))
	if _model:
		_model.name = "Model"
		_item.add_child(_model)
	_light = OmniLight3D.new()
	_light.name = "Glow"
	_light.light_energy = GLOW
	_light.omni_range = GLOW_REACH
	_light.shadow_enabled = false
	_light.position.y = 0.5
	_item.add_child(_light)
	_touch = _reach("Touch", _item, touched)


## Whose it is has changed: the prize and its stand take on the colour.
func dress(of_team: int, colour: Color) -> void:
	team = of_team
	tint = colour
	_dress()


## Gives the prize to `body`, who has it from here on.
func take(body: Node3D) -> void:
	if _item == null or body == null:
		return
	if state == State.CARRIED:
		_dismount()
	carrier = body
	state = State.CARRIED
	down_for = 0.0
	_mount()
	_settle()
	moved.emit()


## Whoever has it lets go: it comes down where that one stands, or at `at`,
## on the floor that is under there.
func drop(at := Vector3.INF) -> void:
	if _item == null or state != State.CARRIED:
		return
	var facing := carrier.global_rotation.y if is_instance_valid(carrier) and carrier.is_inside_tree() else 0.0
	if not at.is_finite():
		at = carrier.global_position if is_instance_valid(carrier) and carrier.is_inside_tree() else where()
	_dismount()
	_lay(at, facing)


## Back to its stand, from wherever it is.
func send_home() -> void:
	if _item == null or state == State.HOME:
		return
	if state == State.CARRIED:
		_dismount()
	state = State.HOME
	down_for = 0.0
	_settle()
	moved.emit()


## Where it is at this moment.
func where() -> Vector3:
	if state == State.CARRIED and is_instance_valid(carrier) and carrier.is_inside_tree():
		return carrier.global_position
	return _item.global_position if is_instance_valid(_item) and _item.is_inside_tree() else global_position


## Who is within reach of the prize right now, and who is at the stand: for
## whoever has to know that when something else changes, such as a prize
## that comes home while its owner waits there with the other one.
func within_reach() -> Array[Node3D]:
	return _touch.get_overlapping_bodies() if is_instance_valid(_touch) and state != State.CARRIED else []


func at_stand() -> Array[Node3D]:
	return _base.get_overlapping_bodies() if is_instance_valid(_base) else []


## What it is called, and how a sentence speaks of it.
func title() -> String:
	return str(_spec.get("name", kind.capitalize()))


func the() -> String:
	return str(_spec.get("the", "the " + kind))


## Strikes a pose for a picture of a prize nobody plays for: 1 at home, 2 on
## the back of a soldier who stands two paces from the stand, 3 the same in
## mid-stride, 4 on the ground beside its stand. The first decimal picks the
## prize, in the order of the table, and the second whose it is: nobody's (0),
## the one side (1) or the other (2). 2.21 is the banana of the one side on
## somebody's back.
func preview(pose: float) -> void:
	var order := kinds()
	var hundredths := roundi(pose * 100.0) % 100
	@warning_ignore("integer_division")
	kind = order[clampi(hundredths / 10, 0, order.size() - 1)]
	team = clampi(hundredths % 10, 0, PREVIEW_TINTS.size() - 1) - 1
	tint = PREVIEW_TINTS[team + 1]
	_build()
	var stance := floori(pose + 0.001)
	if stance == 2 or stance == 3:
		var bearer: CharacterBody3D = (load("res://scenes/puppet.tscn") as PackedScene).instantiate()
		bearer.id = 1 + maxi(team, 0)
		# Nobody is behind it, so nothing is written over its head.
		bearer.title = " "
		bearer.name = "Bearer"
		bearer.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(bearer)
		bearer.position = Vector3(1.6, 0.0, 1.2)
		bearer.preview(2.0 if stance == 3 else 1.0)
		take(bearer)
		var rig := bearer.get_node_or_null("Model")
		if rig:
			# Once more, now that it bears something.
			rig._pose(0.0)
	elif stance == 4:
		_lay(global_position + global_basis * Vector3(1.2, 0.0, 0.3), global_rotation.y)
	if _model and _model.get_meta(&"flies", false):
		# The same moment of the wind in every picture.
		for cloth in _team_parts(_model):
			cloth.set_instance_shader_parameter(&"phase", 2.0)


func _process(delta: float) -> void:
	if state == State.DOWN:
		down_for += delta
	elif state == State.CARRIED and _model and _model.get_meta(&"flies", false) and is_instance_valid(carrier):
		# The faster it is carried, the straighter it stands out.
		var wind: Array = _spec.get("wind", [0.7, 1.0])
		var speed := 0.0
		if carrier.get(&"velocity") is Vector3:
			speed = (carrier.get(&"velocity") as Vector3).length()
		for cloth in _team_parts(_model):
			cloth.set_instance_shader_parameter(&"wind", lerpf(wind[0], wind[1], clampf(speed / FULL_WIND, 0.0, 1.0)))


## Lays the prize down at `at`, on the floor under there, turned the way
## `facing` says.
func _lay(at: Vector3, facing: float) -> void:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space:
		var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN * 4.0, WORLD))
		if ground:
			at = ground.position
	state = State.DOWN
	down_for = 0.0
	var pose := _pose(_spec.get("down", {}))
	var frame := Transform3D(Basis(Vector3.UP, facing), at)
	if is_inside_tree():
		_item.global_transform = frame * Transform3D(Basis(), pose.origin)
	else:
		_item.transform = frame * Transform3D(Basis(), pose.origin)
	_model.transform = Transform3D(pose.basis, Vector3.ZERO)
	_settle()
	moved.emit()


## Has what goes with where the prize is: at home it sits as the table says,
## it can only be touched where it stands or lies and only glows there, and
## its net is only there while it is carried.
func _settle() -> void:
	if not is_instance_valid(_item):
		return
	if state == State.HOME:
		if _item.get_parent() != self:
			if _item.get_parent():
				_item.get_parent().remove_child(_item)
			add_child(_item)
		# The prize is where the table says; only its model is turned, so that
		# what feels for a touch stays upright over it.
		var pose := _pose(_spec.get("home", {}))
		_item.transform = Transform3D(Basis(), pose.origin)
		if _model:
			_model.transform = Transform3D(pose.basis, Vector3.ZERO)
	elif state == State.CARRIED and _model:
		_model.transform = Transform3D()
	var loose := state != State.CARRIED
	_touch.set_deferred(&"monitoring", loose)
	_light.visible = loose
	if _model:
		var net := _model.find_child("Net", true, false) as Node3D
		if net:
			net.visible = not loose
		if _model.get_meta(&"flies", false):
			var wind: Array = _spec.get("wind", [0.7, 1.0])
			for cloth in _team_parts(_model):
				cloth.set_instance_shader_parameter(&"wind", wind[0])


## Hangs the prize on whoever carries it.
func _mount() -> void:
	var hold: Dictionary = _spec.get("carried", {})
	var on := str(hold.get("on", "back"))
	var pose := _pose(hold)
	if _item.get_parent():
		_item.get_parent().remove_child(_item)
	if not carrier.tree_exiting.is_connected(_on_carrier_leaving):
		carrier.tree_exiting.connect(_on_carrier_leaving)
	_rig = carrier.get_node_or_null("Model")
	if _rig and _rig.has_method("bear"):
		_rig.bear(_item, on, pose)
		# A puppet that changes its weapon becomes a new figure, and what the
		# old one bore would go with it.
		if not _rig.tree_exiting.is_connected(_on_rig_leaving):
			_rig.tree_exiting.connect(_on_rig_leaving)
		return
	_rig = null
	# No rig: straight on to the body, which looks along -Z where a figure
	# looks along +Z.
	carrier.add_child(_item)
	var bone := Vector3(0.0, WITHOUT_RIG.get(on, WITHOUT_RIG.back), 0.0)
	_item.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * Transform3D(pose.basis, bone + pose.origin * HIP_HEIGHT)


## Takes the prize off whoever has it and brings it back under this node,
## where it was last seen.
func _dismount() -> void:
	var at := _item.global_transform if _item.is_inside_tree() else global_transform
	if is_instance_valid(_rig):
		if _rig.tree_exiting.is_connected(_on_rig_leaving):
			_rig.tree_exiting.disconnect(_on_rig_leaving)
		_rig.release()
	if _item.get_parent():
		_item.get_parent().remove_child(_item)
	_item.scale = Vector3.ONE
	add_child(_item)
	if is_inside_tree():
		_item.global_transform = at.orthonormalized()
	if is_instance_valid(carrier) and carrier.tree_exiting.is_connected(_on_carrier_leaving):
		carrier.tree_exiting.disconnect(_on_carrier_leaving)
	_rig = null
	carrier = null


## Whoever carried it is taken out of the level without having let go: it
## comes down where that one last stood. Nothing can be moved about while a
## branch of the tree is being taken down, so that waits a moment.
func _on_carrier_leaving() -> void:
	if state != State.CARRIED or not is_instance_valid(carrier):
		return
	_orphaned.call_deferred(carrier.global_position, carrier.global_rotation.y, null)


## The figure that bore it is being replaced by another, as when a puppet
## changes its weapon: on to the next one, a moment later.
func _on_rig_leaving() -> void:
	if state != State.CARRIED or not is_instance_valid(carrier) or carrier.is_queued_for_deletion():
		return
	_orphaned.call_deferred(carrier.global_position, carrier.global_rotation.y, carrier)


## What it was on has gone: on to `heir` if there is one, and down at `at`
## otherwise. If the prize went with what bore it, there is a new one.
func _orphaned(at: Vector3, facing: float, heir: Node3D) -> void:
	if not is_inside_tree() or state != State.CARRIED:
		return
	if is_instance_valid(_item) and not _item.is_queued_for_deletion():
		_dismount()
	else:
		_rig = null
		carrier = null
		_make_item()
		_dress()
	if is_instance_valid(heir) and heir.is_inside_tree() and not heir.is_queued_for_deletion():
		take(heir)
	else:
		_lay(at, facing)


## The prize and its stand take on the colour of whose they are.
func _dress() -> void:
	for whole: Node3D in [_stand, _model]:
		if whole == null:
			continue
		for part in _team_parts(whole):
			part.set_instance_shader_parameter(&"team", tint)
			part.set_instance_shader_parameter(&"teamed", 1.0 if team >= 0 else 0.0)
			if whole.get_meta(&"flies", false):
				# The cloth goes further than its mesh says it is, and no two
				# flags move in step.
				part.extra_cull_margin = 1.0
				part.set_instance_shader_parameter(&"phase", float(hash(String(name)) % 1000) * 0.01)
	if _light:
		_light.light_color = tint if team >= 0 else Color(1.0, 0.95, 0.85)


## The parts of a model that take the colour of a team.
func _team_parts(whole: Node3D) -> Array[MeshInstance3D]:
	var parts: Array[MeshInstance3D] = []
	for found in whole.find_children("Team*", "MeshInstance3D", true, false):
		parts.append(found as MeshInstance3D)
	return parts


## Every mesh of it as it can come to look, for Fx.rehearse() to draw once
## before anybody sees it.
func _looks() -> Array[MeshInstance3D]:
	var looks: Array[MeshInstance3D] = []
	for whole: Node3D in [_stand, _model]:
		if whole == null:
			continue
		for mesh: MeshInstance3D in whole.find_children("*", "MeshInstance3D", true, false):
			var copy := MeshInstance3D.new()
			copy.mesh = mesh.mesh
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			copy.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
			if String(mesh.name).begins_with("Team"):
				copy.set_instance_shader_parameter(&"team", tint)
				copy.set_instance_shader_parameter(&"teamed", 1.0)
			looks.append(copy)
	return looks


func _scene(model: String) -> Node3D:
	var path := MODELS % model
	if model == "" or not ResourceLoader.exists(path):
		if model:
			push_warning("No model %s for the prize %s" % [path, kind])
		return null
	return (load(path) as PackedScene).instantiate() as Node3D


## A ball over `under` that tells `heard` who of the players comes into it.
func _reach(title_of: String, under: Node3D, heard: Signal) -> Area3D:
	var area := Area3D.new()
	area.name = title_of
	area.collision_layer = 0
	area.collision_mask = PLAYERS
	area.monitorable = false
	var ball := SphereShape3D.new()
	ball.radius = REACH
	var shape := CollisionShape3D.new()
	shape.shape = ball
	shape.position.y = 0.9
	area.add_child(shape)
	under.add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void: heard.emit(body))
	return area


## A way of sitting from the table as a transform: {"at": metres, "turn":
## degrees about x, y and z}.
func _pose(entry: Dictionary) -> Transform3D:
	var at: Array = entry.get("at", [0, 0, 0])
	var turn: Array = entry.get("turn", [0, 0, 0])
	return Transform3D(Basis.from_euler(Vector3(turn[0], turn[1], turn[2]) * PI / 180.0), Vector3(at[0], at[1], at[2]))
