extends SceneTree
## Cuts the moves of the humanoid enemies out of the animation sources and
## writes them to assets/animations/moves.res. Run with tools/build_moves.sh.
##
## The sources are imported onto Godot's humanoid profile (see the bone maps
## next to them), so a move made here fits any character that was imported the
## same way. Which clip becomes which move is listed in the manifest.
##
## A move keeps the turning of the 22 bones of body, arms and legs and the
## travel of the hips. Fingers are left out: scripts/humanoid_rig.gd poses them
## once, from the moves of kind "hands". Tracks are addressed from the skeleton
## itself, as ".:Hips". What the rig has to know about a move (how far a walk
## cycle travels, when each foot is down, when a strike lands) is measured here
## and stored on the library as the metadata "moves", next to "sets": the ways
## of moving the manifest makes of them.

const DIR := "res://assets/animations/"
const OUT := DIR + "moves.res"
const FPS := 30.0
const BODY: Array[String] = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head"]
const LIMBS: Array[String] = ["Shoulder", "UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot", "Toes"]
const FINGERS: Array[String] = [
	"ThumbMetacarpal", "ThumbProximal", "ThumbDistal", "IndexProximal", "IndexIntermediate", "IndexDistal",
	"MiddleProximal", "MiddleIntermediate", "MiddleDistal", "RingProximal", "RingIntermediate", "RingDistal",
	"LittleProximal", "LittleIntermediate", "LittleDistal",
]
const SIDES: Array[String] = ["Left", "Right"]
## The hips travel is kept under this name in a pose.
const TRAVEL := "@"
## Samples of a walk cycle that are looked at to measure it.
const GAIT_SAMPLES := 120

var _skeleton: Skeleton3D
## Height of the hips of the mannequin: the unit the travel of the hips and
## the length of a stride are stored in.
var _hips := 1.0
## Bone -> how it is turned at rest, for every bone a move may hold.
var _rest := {}
var _players := {}
## Animation -> its tracks as [track, type, bone].
var _tracks := {}


func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "manifest.json"))
	for source: Dictionary in manifest.sources:
		var scene: Node = (load(DIR + source.id + ".glb") as PackedScene).instantiate()
		root.add_child(scene)
		_players[source.id] = scene.find_child("AnimationPlayer", true, false)
		if _skeleton == null:
			_skeleton = scene.find_child("GeneralSkeleton", true, false)
	# A skeleton only works out where its bones are once it is in the tree,
	# and the tree only starts after this function.
	await process_frame
	_hips = _skeleton.get_bone_global_rest(_skeleton.find_bone("Hips")).origin.y
	for bone in _bones(true):
		_rest[bone] = _skeleton.get_bone_rest(_skeleton.find_bone(bone)).basis.get_rotation_quaternion()
	_rest[TRAVEL] = _skeleton.get_bone_rest(_skeleton.find_bone("Hips")).origin / _hips
	_check_symmetry()

	var library := AnimationLibrary.new()
	var facts := {}
	for move_name: String in manifest.moves:
		var move: Dictionary = manifest.moves[move_name]
		if not (_players[move.source] as AnimationPlayer).has_animation(move.clip):
			push_error("%s: %s has no clip %s" % [move_name, move.source, move.clip])
			continue
		var fact := {"kind": move.kind}
		var animation: Animation
		match move.kind:
			"gait":
				animation = _gait(move, fact)
			"hands":
				animation = _hands(move)
			_:
				animation = _plain(move, fact)
		fact["length"] = snappedf(animation.length, 0.001)
		facts[move_name] = fact
		library.add_animation(move_name, animation)
		print("%-14s %s" % [move_name, fact])
	for set_name: String in manifest.sets:
		var way: Dictionary = manifest.sets[set_name]
		for move: String in [way.idle, way.fingers] + way.gaits + way.attacks:
			if not facts.has(move):
				push_error("set %s names a move that is not there: %s" % [set_name, move])
	library.set_meta("moves", facts)
	library.set_meta("sets", manifest.sets)
	library.set_meta("hips", _hips)
	print("%s: %d moves, %s" % [OUT, facts.size(), error_string(ResourceSaver.save(library, OUT, ResourceSaver.FLAG_COMPRESS))])
	for player: AnimationPlayer in _players.values():
		player.owner.free()
	quit()


## The bones a move holds, or with `fingers` every bone a source is read for.
func _bones(fingers := false) -> Array[String]:
	var bones := BODY.duplicate()
	for side in SIDES:
		for limb in LIMBS:
			bones.append(side + limb)
		if fingers:
			for finger in FINGERS:
				bones.append(side + finger)
	return bones


func _clip(move: Dictionary, key := "clip") -> Animation:
	return (_players[move.source] as AnimationPlayer).get_animation(move[key])


## How the mannequin stands `time` seconds into a clip: bone -> rotation, and
## the travel of the hips in hip heights.
func _pose(animation: Animation, time: float) -> Dictionary:
	if not _tracks.has(animation):
		var found := []
		for track in animation.get_track_count():
			var path := animation.track_get_path(track)
			var bone := String(path.get_subname(0)) if path.get_subname_count() == 1 else ""
			var type := animation.track_get_type(track)
			if (type == Animation.TYPE_ROTATION_3D and _rest.has(bone)) or (type == Animation.TYPE_POSITION_3D and bone == "Hips"):
				found.append([track, type, bone])
		_tracks[animation] = found
	var pose := _rest.duplicate()
	for entry: Array in _tracks[animation]:
		if entry[1] == Animation.TYPE_ROTATION_3D:
			pose[entry[2]] = animation.rotation_track_interpolate(entry[0], time)
		else:
			pose[TRAVEL] = animation.position_track_interpolate(entry[0], time)
	return pose


## The same pose with left and right changed over.
func _mirrored(pose: Dictionary) -> Dictionary:
	var mirrored := {}
	for bone: String in pose:
		if bone == TRAVEL:
			var travel: Vector3 = pose[bone]
			mirrored[bone] = Vector3(-travel.x, travel.y, travel.z)
			continue
		var other := bone
		if bone.begins_with("Left"):
			other = "Right" + bone.trim_prefix("Left")
		elif bone.begins_with("Right"):
			other = "Left" + bone.trim_prefix("Right")
		var turn: Quaternion = pose[bone]
		mirrored[other] = Quaternion(turn.x, -turn.y, -turn.z, turn.w)
	return mirrored


## Mirroring a pose like that only holds if the right side of the skeleton is
## the left side in a mirror at rest.
func _check_symmetry() -> void:
	var mirrored := _mirrored(_rest)
	for bone: String in _rest:
		if bone != TRAVEL and (mirrored[bone] as Quaternion).angle_to(_rest[bone]) > deg_to_rad(1.0):
			push_warning("%s is not the mirror image of its counterpart at rest; mirrored moves will be off" % bone)


## Puts the mannequin in a pose, to measure where its hands and feet end up.
func _strike(pose: Dictionary) -> void:
	for bone: String in pose:
		if bone == TRAVEL:
			_skeleton.set_bone_pose_position(_skeleton.find_bone("Hips"), (pose[bone] as Vector3) * _hips)
		else:
			_skeleton.set_bone_pose_rotation(_skeleton.find_bone(bone), pose[bone])


func _where(bone: String) -> Vector3:
	return _skeleton.get_bone_global_pose(_skeleton.find_bone(bone)).origin


## An animation of `length` seconds whose pose at any moment is `pose_at`.
func _bake(length: float, loop: bool, pose_at: Callable) -> Animation:
	var animation := Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var bones := _bones()
	for bone in bones:
		animation.track_set_path(animation.add_track(Animation.TYPE_ROTATION_3D), NodePath(".:" + bone))
	var travel := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(travel, NodePath(".:Hips"))
	var steps := maxi(ceili(length * FPS), 1)
	for step in steps + 1:
		var time := length * step / steps
		# A loop ends exactly as it began.
		var pose: Dictionary = pose_at.call(0.0 if loop and step == steps else time)
		for i in bones.size():
			animation.rotation_track_insert_key(i, time, pose[bones[i]])
		animation.position_track_insert_key(travel, time, pose[TRAVEL])
	return animation


## A clip as it is, trimmed, followed by another, reversed or mirrored.
func _plain(move: Dictionary, fact: Dictionary) -> Animation:
	var parts := [[_clip(move), float(move.get("from", 0.0)), float(move.get("to", _clip(move).length))]]
	if move.has("then"):
		parts.append([_clip(move, "then"), 0.0, _clip(move, "then").length])
	var length := 0.0
	for part: Array in parts:
		length += part[2] - part[1]
	var loop: bool = move.kind == "loop"
	var pose_at := func(time: float) -> Dictionary:
		if move.get("reverse", false):
			time = length - time
		var pose := {}
		for part: Array in parts:
			var span: float = part[2] - part[1]
			if time <= span or part == parts[-1]:
				pose = _pose(part[0], part[1] + minf(time, span))
				break
			time -= span
		return _mirrored(pose) if move.get("mirror", false) else pose
	if move.kind == "once":
		fact["hit"] = move["hit"] if move.has("hit") else _reach(length, pose_at)
	return _bake(length, loop, pose_at)


## The moment a hand is furthest out in front of the chest: when a blow lands.
func _reach(length: float, pose_at: Callable) -> float:
	var best := 0.0
	var furthest := -INF
	var steps := ceili(length * 60.0)
	for step in steps + 1:
		var time := length * step / steps
		_strike(pose_at.call(time))
		var chest := _where("UpperChest")
		for side in SIDES:
			var out := _where(side + "Hand").z - chest.z
			if out > furthest:
				furthest = out
				best = time
	return snappedf(best, 0.01)


## A walk cycle: brought to one second, starting as the left foot comes down,
## and measured. A foot is down while its heel or the ball of the foot is on
## the ground and the ball travels back under the body; how fast it does that
## is how far the walk gets in a cycle.
func _gait(move: Dictionary, fact: Dictionary) -> Animation:
	var clip := _clip(move)
	var length := clip.length
	var heels := {}
	var balls := {}
	for side in SIDES:
		heels[side] = []
		balls[side] = []
	for i in GAIT_SAMPLES:
		_strike(_pose(clip, length * i / GAIT_SAMPLES))
		for side in SIDES:
			heels[side].append(_where(side + "Foot"))
			balls[side].append(_where(side + "Toes"))

	# Metres the ball of each foot travels back per cycle, sample by sample.
	var back := {}
	var low := {}
	var paces := []
	for side in SIDES:
		var heel_floor := _floor_under(heels[side])
		var ball_floor := _floor_under(balls[side])
		back[side] = []
		low[side] = []
		for i in GAIT_SAMPLES:
			var before: Vector3 = balls[side][i - 1]
			var after: Vector3 = balls[side][(i + 1) % GAIT_SAMPLES]
			back[side].append((before.z - after.z) * GAIT_SAMPLES / 2.0)
			var ball_low: bool = balls[side][i].y < ball_floor + 0.02 * _hips
			low[side].append(ball_low or heels[side][i].y < heel_floor + 0.02 * _hips)
			if ball_low:
				paces.append(back[side][i])
	paces.sort()
	var stride: float = paces[paces.size() / 2]

	var down := {}
	for side in SIDES:
		var planted := []
		for i in GAIT_SAMPLES:
			planted.append(low[side][i] and back[side][i] > 0.5 * stride)
		# A single sample that falls outside does not end the step.
		for i in GAIT_SAMPLES:
			if not planted[i] and planted[i - 1] and planted[(i + 1) % GAIT_SAMPLES]:
				planted[i] = true
		# The longest run of samples in which the foot is down, round the loop.
		var best := Vector2i(0, 0)
		for from in GAIT_SAMPLES:
			if planted[from] and not planted[from - 1]:
				var run := 0
				while run < GAIT_SAMPLES and planted[(from + run) % GAIT_SAMPLES]:
					run += 1
				if run > best.y:
					best = Vector2i(from, run)
		down[side] = best
	var begin: float = float(down["Left"].x) / GAIT_SAMPLES
	# In hip heights, so that a taller character takes longer steps.
	fact["stride"] = snappedf(stride / _hips, 0.001)
	fact["speed"] = snappedf(stride / length / _hips, 0.001)
	fact["cycle"] = snappedf(length, 0.001)
	for side in SIDES:
		var from := fposmod(float(down[side].x) / GAIT_SAMPLES - begin, 1.0)
		fact["down_" + side.to_lower()] = [snappedf(from, 0.001), snappedf(from + float(down[side].y) / GAIT_SAMPLES, 0.001)]
	return _bake(1.0, true, func(phase: float) -> Dictionary: return _pose(clip, fposmod(begin + phase, 1.0) * length))


## The height a point of a foot is at while it stands on the ground: the
## middle of the lowest heights it reaches in a cycle.
func _floor_under(path: Array) -> float:
	var heights := []
	for at: Vector3 in path:
		heights.append(at.y)
	heights.sort()
	return heights[heights.size() * 15 / 200]


## How the fingers are held at one moment of a clip, as a move of one key. The
## fingers of one hand are used for both.
func _hands(move: Dictionary) -> Animation:
	var pose := _pose(_clip(move), float(move.get("at", 0.0)))
	var from: String = move.get("from_hand", "Right")
	var mirrored := _mirrored(pose)
	var animation := Animation.new()
	animation.length = 0.1
	for side in SIDES:
		for finger in FINGERS:
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track, NodePath(".:" + side + finger))
			animation.rotation_track_insert_key(track, 0.0, (pose if side == from else mirrored)[side + finger])
	return animation
