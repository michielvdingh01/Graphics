extends Node
## Headless test of the enemies that are people. Run with: tools/test_humanoid.sh
##
## It plays the factory with a theme of characters (the mannequins, unless
## --enemies= names another) and checks what selftest.gd checks for robots:
## that they come for the player, hit, and die. On top of that it walks one
## in every direction and measures how far its feet slide while they are down,
## and it looks at what is left of one that has died.

const HUMANOID := preload("res://scripts/humanoid_rig.gd")
const THEMES := preload("res://scripts/enemy_themes.gd")
## An open lane in the factory with 6 m of clear floor to the east of it.
const RANGE_TARGET := Vector3(1, 0, -7.5)
## Metres a second a foot may slide while it is down.
const SLIDE := 0.05

## True for a run of this test.
var active := false

var _failures := 0
## What is being walked about by hand, and how fast.
var _walker: CharacterBody3D
var _stride := Vector3.ZERO


func _ready() -> void:
	active = "--humanoidtest" in OS.get_cmdline_user_args()
	if active:
		# Menus, saved settings and saved progress stay out of the way, as
		# they do for the self-test.
		SelfTest.active = true
		_run.call_deferred()


func _process(delta: float) -> void:
	if is_instance_valid(_walker):
		_walker.global_position += _stride * delta


func _run() -> void:
	var tree := get_tree()
	# A script error would otherwise leave the run hanging forever.
	tree.create_timer(150.0, true, true).timeout.connect(
		func() -> void:
			print("HUMANOID TEST FAILED (timed out)")
			tree.quit(1)
	)
	await _wait(0.5)
	var game := tree.current_scene
	var player: CharacterBody3D = game.player
	player.force_control = true
	var hits := [0]
	player.damaged.connect(func(_amount: float) -> void: hits[0] += 1)

	var theme: String = Settings.enemy_theme
	print("  enemies: ", theme)
	_check("a theme of characters is chosen", theme != THEMES.ROBOTS)
	_check("an unknown theme or role is a robot", THEMES.cast("nobody", "grunt").is_empty() and THEMES.cast(theme, "boss").is_empty())
	var enemies := tree.get_nodes_in_group("enemy")
	_check("first wave spawned", enemies.size() == 3 and game.wave == 1)
	_check("the wave is made of characters", enemies.all(_is_character))

	# They come looking for the player and deal damage, wherever they spawned.
	player.health = 1e6
	var start := {}
	for e in enemies:
		start[e] = e.global_position.distance_to(player.global_position)
	var approached := false
	for i in 50:
		approached = approached or enemies.any(
			func(e: Node3D) -> bool:
				return e.global_position.distance_to(player.global_position) < start[e] - 3.0
		)
		if approached and hits[0] > 0:
			break
		await _wait(0.5)
	_check("they find the player", approached)
	_check("they hit the player", hits[0] > 0)

	# One of them is shot with the rifle from close range.
	var enemy: CharacterBody3D = enemies[0]
	for other in enemies:
		other.set_physics_process(false)
	enemy.global_position = RANGE_TARGET
	enemy.velocity = Vector3.ZERO
	player.global_position = RANGE_TARGET + Vector3(6, 0, 0)
	player.velocity = Vector3.ZERO
	player.look_at(Vector3(enemy.global_position.x, player.global_position.y, enemy.global_position.z))
	# At the chest: a character that stoops is shorter than the player's eyes are high.
	var rig: Node3D = enemy._rig
	var chest: Vector3 = enemy.global_position + Vector3.UP * rig.fit.height * 0.65
	player.head.rotation.x = atan2(chest.y - player.head.global_position.y, 6.0)
	await _wait(0.3)
	var stains: int = Fx._stains.size()
	Input.action_press("fire")
	await _wait(0.25)
	_check("a shot hurts it", enemy.health < enemy.max_health)
	_check("it flinches", rig._flinched > 0.0)
	for i in 30:
		if enemy.dead:
			break
		await _wait(0.1)
	Input.action_release("fire")
	_check("it dies", enemy.dead and game.kills == 1)
	_check("a body is in nobody's way", enemy.collision_layer == 0 and not enemy.is_in_group("enemy"))
	await _wait(0.4)
	var hips: int = rig._hips
	var standing: float = rig._rest_global(hips).origin.y * 0.8
	await _wait(rig._fall_length + 0.3)
	_check("it has fallen", rig._skeleton.get_bone_pose_position(hips).y < standing * 0.5)
	_check("a body that lies still costs nothing", not rig.is_processing() and not rig._tree.active)
	_check("it bled", Fx._stains.size() > stains)
	await _wait(enemy.LINGER)
	_check("the body is cleared away", not is_instance_valid(enemy))

	# The other two roles.
	var rusher: CharacterBody3D = game.RUSHER.instantiate()
	rusher.position = player.global_position + Vector3(-5, 0, 1.5)
	game.add_child(rusher)
	var before: int = hits[0]
	await _wait(3.5)
	if _is_character(rusher) and rusher.melee:
		_check("a rusher closes in and strikes", hits[0] > before and rusher.global_position.distance_to(player.global_position) < 2.5)
	else:
		print("  [--] the rusher of this theme does not fight hand to hand, or is a robot")
	rusher.queue_free()
	var slim := true
	for scene: PackedScene in [game.GRUNT, game.RUSHER, game.HEAVY]:
		var one: CharacterBody3D = scene.instantiate()
		game.add_child(one)
		var capsule: CapsuleShape3D = one.get_node("CollisionShape3D").shape
		slim = slim and capsule.radius <= 0.461
		if _is_character(one):
			# The head is inside the collider and counts as one.
			var fit: Dictionary = one._rig.fit
			slim = slim and capsule.height >= fit.height - 0.01 and one.is_headshot(one.global_position + Vector3.UP * (fit.height - 0.05))
		one.free()
	_check("no role is wider than a door allows, and heads can be hit", slim)

	# All three roles at once, in a fight that lasts: they attack for a while
	# and are then killed in the middle of whatever they are doing, two of
	# them by a blow that throws them down.
	var squad: Array[CharacterBody3D] = []
	for scene: PackedScene in [game.GRUNT, game.GRUNT, game.RUSHER, game.HEAVY]:
		var one: CharacterBody3D = scene.instantiate()
		one.position = player.global_position + Vector3(-7.0 - squad.size(), 0, squad.size() * 1.5 - 2.0)
		game.add_child(one)
		one.alert()
		squad.append(one)
	before = hits[0]
	await _wait(5.0)
	for i in squad.size():
		var one := squad[i]
		one.take_damage(1e6 if i % 2 == 0 else one.health, one.global_position + Vector3.UP, (one.global_position - player.global_position).normalized())
	await _wait(3.0)
	_check("a squad of all roles fights, and falls when it is killed", hits[0] > before and squad.all(
		func(one: CharacterBody3D) -> bool:
			return one.dead and (not _is_character(one) or not one._rig.is_processing())
	))

	# Walking: forwards, to either side and backwards, at the pace of a chase
	# and of a strafe. A foot that is down has to stay where it is.
	for other in tree.get_nodes_in_group("enemy"):
		other.queue_free()
	await _wait(0.1)
	_walker = game.GRUNT.instantiate()
	_walker.position = RANGE_TARGET
	game.add_child(_walker)
	_walker.set_physics_process(false)
	if _is_character(_walker):
		var legs: Node3D = _walker._rig
		legs.measure = true
		legs.aim(_walker.global_position + Vector3(0, 1.4, -30))
		var fast: float = _walker.speed
		var worst := 0.0
		for lap: Array in [["forwards", Vector3.FORWARD, fast], ["to its right", Vector3.RIGHT, fast * 0.5], ["to its left", Vector3.LEFT, fast * 0.5],
				["backwards", Vector3.BACK, fast * 0.5], ["forwards and left", Vector3(-0.7, 0, -0.7), fast * 0.7]]:
			var slides := []
			for locked: bool in [false, true]:
				legs.lock_feet = locked
				_walker.global_position = RANGE_TARGET
				_stride = lap[1] * lap[2]
				_walker.velocity = _stride
				# Up to speed first; the measurement is of the walk, not the start.
				await _wait(0.6)
				legs.slid = 0.0
				legs.stood = 0.0
				var cycles: float = legs._cycles
				await _wait(1.6)
				slides.append(legs.slid / maxf(legs.stood, 0.01))
				if locked:
					# Two steps to a cycle; between 1 and 4 a second is a walk or a run.
					var steps := absf(legs._cycles - cycles) * 2.0 / 1.6
					_check("walks %s in step (%.1f steps a second at %.1f m/s)" % [lap[0], steps, lap[2]], steps > 1.0 and steps < 4.0)
			worst = maxf(worst, slides[1])
			print("    feet slide %.3f m/s %s; left to the clips they would slide %.3f m/s" % [slides[1], lap[0], slides[0]])
		_check("feet that are down stay put (worst %.3f m/s)" % worst, worst < SLIDE)
		# What a frame of all that costs in script and animation, for the record.
		legs.set_process(false)
		var began := Time.get_ticks_usec()
		for i in 600:
			_walker.global_position += _stride / 60.0
			legs._pose(1.0 / 60.0)
		var whole := (Time.get_ticks_usec() - began) / 600.0
		began = Time.get_ticks_usec()
		for i in 600:
			legs._tree.advance(1.0 / 60.0)
		print("    posing it takes %d microseconds a frame, %d of them to blend the clips" % [whole, (Time.get_ticks_usec() - began) / 600.0])
	else:
		_check("the grunt of this theme is a character", false)
	_walker.queue_free()

	# The setting in the menu steps through the themes.
	Menu._show(Menu.Screen.SETTINGS)
	var chooser: Button = null
	for control: Control in Menu._column.get_children():
		if control is Button and (control as Button).text.begins_with("Enemies"):
			chooser = control
	chooser.pressed.emit()
	_check("the menu steps on to the next theme", Settings.enemy_theme != theme and chooser.text.ends_with(Settings.enemy_names[Settings.enemies]))
	Menu._show(Menu.Screen.NONE)

	print("HUMANOID TEST %s" % ("PASSED" if _failures == 0 else "FAILED (%d)" % _failures))
	tree.quit(1 if _failures else 0)


func _is_character(enemy: Node) -> bool:
	return enemy._rig.get_script() == HUMANOID


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
