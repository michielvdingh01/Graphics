extends Node3D
## Lays a move out as a row of poses, to look at it without running the game:
## tools/benchmark.sh --quick --scene=res://scenes/moves_sheet.tscn --move=death --at="0,1.2,7.5,0,-4"
##
## --move= is a move from assets/animations/moves.res, --count= the number of
## poses from its start to its end, --turn= the angle the figures are turned
## from facing the camera (90 shows them from their right-hand side),
## --character= the scene of another character than the mannequin and
## --hands= a hands move for the fingers.

const MOVES := preload("res://assets/animations/moves.res")
const SPACING := 1.3


func _ready() -> void:
	var options := {"move": "walk", "count": "8", "turn": "0", "character": "res://assets/animations/ual1.glb", "hands": "hand_relaxed"}
	for arg in OS.get_cmdline_user_args():
		var key := arg.get_slice("=", 0).trim_prefix("--")
		if options.has(key):
			options[key] = arg.get_slice("=", 1)

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
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.42, 0.42, 0.4)
	paint.roughness = 0.9
	plane.material = paint
	ground.mesh = plane
	add_child(ground)

	var move: Animation = MOVES.get_animation(options.move)
	var hands: Animation = MOVES.get_animation(options.hands)
	var count := int(options.count)
	var scene: PackedScene = load(options.character)
	for i in count:
		var figure: Node3D = scene.instantiate()
		add_child(figure)
		figure.position.x = (i - (count - 1) * 0.5) * SPACING
		figure.rotation_degrees.y = float(options.turn)
		var time := move.length * i / maxi(count - 1, 1)
		var skeleton: Skeleton3D = figure.find_child("GeneralSkeleton", true, false)
		for animation: Animation in [hands, move]:
			for track in animation.get_track_count():
				var bone := skeleton.find_bone(animation.track_get_path(track).get_subname(0))
				if bone < 0:
					continue
				if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D:
					skeleton.set_bone_pose_rotation(bone, animation.rotation_track_interpolate(track, minf(time, animation.length)))
				else:
					skeleton.set_bone_pose_position(bone, animation.position_track_interpolate(track, time) * skeleton.motion_scale)
		var label := Label3D.new()
		label.text = "%.2f" % time
		label.font_size = 48
		label.pixel_size = 0.004
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = figure.position + Vector3(0, 2.15, 0)
		add_child(label)
