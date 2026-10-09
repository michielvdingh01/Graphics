extends Node3D
## Lays a move out as a row of poses, to look at it without running the game:
## tools/benchmark.sh --quick --scene=res://scenes/moves_sheet.tscn --move=death --at="0,1.15,5.4,0,-3"
##
## --move= is a move from assets/animations/moves.res, --count= the number of
## poses from its start to its end, --turn= the angle the figures are turned
## from facing the camera (90 shows them from their right-hand side),
## --character= the scene of another character than the mannequin and
## --hands= a hands move for the fingers.
##
## With --enemy= it shows an enemy as the game would instead of a bare move:
## tools/benchmark.sh --quick --scene=res://scenes/moves_sheet.tscn --enemies=mannequin
##     --enemy=res://scenes/enemy.tscn --walk=1,0 --turn=90 --at="0,1.15,5.4,0,-3"
## --walk=right,ahead is the way it goes, as a share of its speed (0,1 runs
## forwards, 0.5,0 steps to its right), and the poses are --step= seconds
## apart. --then=die, blast, hit, charge or swing makes that happen first, so
## that the row shows what follows. --lower leaves its weapon down.

const MOVES := preload("res://assets/animations/moves.res")
const SPACING := 1.3
const TICK := 0.02


func _ready() -> void:
	var options := {
		"move": "walk", "count": "8", "turn": "0", "character": "res://assets/animations/ual1.glb", "hands": "hand_relaxed",
		"enemy": "", "walk": "0,0", "step": "0.1", "then": "", "lower": "",
	}
	for arg in OS.get_cmdline_user_args():
		var key := arg.get_slice("=", 0).trim_prefix("--")
		if options.has(key):
			options[key] = arg.get_slice("=", 1) if arg.contains("=") else "1"

	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.5, 0.56, 0.64)
	sky.sky_horizon_color = Color(0.72, 0.73, 0.74)
	sky.ground_bottom_color = Color(0.3, 0.3, 0.3)
	sky.ground_horizon_color = Color(0.72, 0.73, 0.74)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.ssao_enabled = true
	environment.glow_enabled = true
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := StaticBody3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.42, 0.42, 0.4)
	paint.roughness = 0.9
	plane.material = paint
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = plane
	ground.add_child(floor_mesh)
	var slab := CollisionShape3D.new()
	slab.shape = WorldBoundaryShape3D.new()
	ground.add_child(slab)
	add_child(ground)

	var count := int(options.count)
	for i in count:
		var place := Vector3((i - (count - 1) * 0.5) * SPACING, 0, 0)
		var time := 0.0
		if options.enemy != "":
			time = i * float(options.step)
			_enemy(options, place, time)
		else:
			var move: Animation = MOVES.get_animation(options.move)
			time = move.length * i / maxi(count - 1, 1)
			_figure(options, place, time)
		var label := Label3D.new()
		label.text = "%.2f" % time
		label.font_size = 48
		label.pixel_size = 0.004
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = place + Vector3(0, 2.15, 0)
		add_child(label)


## A character `time` seconds into a move, with nothing else done to it.
func _figure(options: Dictionary, place: Vector3, time: float) -> void:
	var figure: Node3D = (load(options.character) as PackedScene).instantiate()
	add_child(figure)
	figure.position = place
	figure.rotation_degrees.y = float(options.turn)
	var skeleton: Skeleton3D = figure.find_child("GeneralSkeleton", true, false)
	for animation: Animation in [MOVES.get_animation(options.hands), MOVES.get_animation(options.move)]:
		for track in animation.get_track_count():
			var bone := skeleton.find_bone(animation.track_get_path(track).get_subname(0))
			if bone < 0:
				continue
			if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D:
				skeleton.set_bone_pose_rotation(bone, animation.rotation_track_interpolate(track, minf(time, animation.length)))
			else:
				skeleton.set_bone_pose_position(bone, animation.position_track_interpolate(track, time) * skeleton.motion_scale)


## An enemy that has been going for a second and then `time` seconds more,
## moved back to its place in the row.
func _enemy(options: Dictionary, place: Vector3, time: float) -> void:
	var enemy: CharacterBody3D = (load(options.enemy) as PackedScene).instantiate()
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(enemy)
	enemy.position = place
	# An enemy looks along -Z; turned round it faces the camera.
	enemy.rotation_degrees.y = 180.0 + float(options.turn)
	var walk: PackedFloat64Array = str(options.walk).split_floats(",")
	var going: Vector3 = enemy.global_basis * Vector3(walk[0], 0, -walk[1]) * enemy.speed
	enemy.velocity = going
	var rig: Node3D = enemy._rig
	var target := enemy.global_position + enemy.global_basis * Vector3(0, enemy.eye_height, -400)
	if options.lower == "":
		rig.aim(target)
	var before := 1.0
	if options.then == "":
		before += time
	for tick in int(before / TICK):
		enemy.global_position += going * TICK
		rig._pose(TICK)
	if options.then != "":
		enemy.process_mode = Node.PROCESS_MODE_INHERIT
		enemy.set_physics_process(false)
		rig.set_process(false)
		match options.then:
			"die":
				enemy.health = 1.0
				enemy.take_damage(10.0, enemy.global_position + Vector3.UP * 1.2, enemy.global_basis.z.rotated(Vector3.UP, 0.4))
			"blast":
				enemy.take_damage(1e6, enemy.global_position + Vector3.UP * 1.2, enemy.global_basis.z.rotated(Vector3.UP, 0.4))
			"hit":
				enemy.take_damage(1.0, enemy.global_position + Vector3.UP * 1.2, enemy.global_basis.z)
			"charge":
				rig.charge(true)
			"swing":
				rig.charge(true)
				for tick in int(enemy.telegraph_time / TICK):
					rig._pose(TICK)
				rig.fire()
		for tick in int(time / TICK):
			enemy.global_position += going * TICK
			rig._pose(TICK)
		rig.set_process(false)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.global_position = place
