extends Node
## Headless test of the enemies that are people. Run with: tools/test_humanoid.sh
##
## It plays the first fight of the factory with a theme of characters (the
## mannequins, unless --enemies= names another) and checks what selftest.gd
## checks for robots: that they come for the player, hit, and die, and that
## one of them fights from cover. On top of that it has some lose their
## heads, walks one in every direction and measures how far its feet slide
## while they are down, and it looks at what is left of one that has died.

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
	if THEMES.names().has("panic_clowns"):
		var calm := THEMES.cast("clowns", "heavy", 0)
		var wild := THEMES.cast("panic_clowns", "heavy", 0)
		_check("a theme that is like another has its cast, with its own tuning on top", wild.character == calm.character and wild.weapon == calm.weapon
			and wild.tuning.max_health == calm.tuning.max_health and wild.tuning.get("panics") == true and not calm.tuning.has("panics"))
	# The fight for the first zone of the route; the rest of the level is
	# left out of it.
	var first: RefCounted = game.zones[0]
	for zone: RefCounted in game.zones:
		zone.area.set_deferred("monitoring", false)
		if zone != first:
			for other: Node in zone.robots:
				other.queue_free()
	await _wait(0.1)
	var enemies := tree.get_nodes_in_group("enemy")
	_check("the first zone of the route is posted", enemies.size() >= 3 and enemies.size() == first.robots.size()
		and enemies.all(func(e: Node) -> bool: return not e.can_process()))
	_check("with characters", enemies.all(_is_character))
	_check("who carry no plate and no pack, and do not duck", enemies.all(func(e: Node) -> bool: return e._shield == 0.0 and e._pack == 0.0 and e._drop == 0.0))
	game._start(first)

	# They come looking for the player and deal damage, wherever they stood.
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

	# A character that shoots fights from cover like a robot does, standing.
	var hider: CharacterBody3D = game.GRUNT.instantiate()
	hider.position = player.global_position + Vector3(-11, 0, 0)
	game.add_child(hider)
	if _is_character(hider) and not hider.melee:
		hider.alert()
		var hid := false
		for i in 240:
			await _wait(0.05)
			if hider._mode == hider.Mode.COVER:
				hid = true
				break
		_check("a character that shoots takes cover", hid and not hider._crouched)
	else:
		print("  [--] the grunt of this theme does not shoot, or is a robot")
	hider.queue_free()
	await _wait(0.1)

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

	# Losing its head. One that panics does when another dies next to it: it
	# lets go of what it carries, throws its arms up and runs about, and does
	# not attack again. Being badly hurt does the same to one that is alone.
	var nervous: Array[CharacterBody3D] = []
	for i in 3:
		var one: CharacterBody3D = game.GRUNT.instantiate()
		one.panics = true
		one.position = player.global_position + Vector3(-8, 0, i * 2.5 - 2.5)
		game.add_child(one)
		one.alert()
		nervous.append(one)
	if nervous.all(_is_character):
		await _wait(0.3)
		var witness := nervous[1]
		var wild: Node3D = witness._rig
		var carried: Node3D = wild._weapon
		_check("one that panics is calm until something happens", nervous.all(func(one: CharacterBody3D) -> bool: return one._mode != one.Mode.PANIC))
		nervous[0].take_damage(1e6, nervous[0].global_position + Vector3.UP, Vector3.LEFT)
		_check("it loses its head when another dies next to it", nervous[0].dead and witness._mode == witness.Mode.PANIC and nervous[2]._mode == witness.Mode.PANIC)
		_check("and lets go of what it carried", wild._weapon == null and wild._hold == HUMANOID.Hold.NONE and (carried == null or not wild.is_ancestor_of(carried)))
		before = hits[0]
		var ran := 0.0
		var screamed := false
		var was := witness.global_position
		for i in 30:
			await _wait(0.1)
			ran += witness.global_position.distance_to(was)
			was = witness.global_position
			screamed = screamed or is_instance_valid(wild._scream)
		var head: float = wild._global(wild._head).origin.y
		_check("it runs about (%.1f m in 3 s) with its hands over its head" % ran, ran > 6.0
			and wild._arms.all(func(arm: RefCounted) -> bool: return wild._global(arm.end).origin.y > head))
		_check("it does not attack any more", hits[0] == before and witness._attack == witness.Attack.COOLDOWN and not witness._aims)
		_check("the others are told with where it is", witness.net_state()[3] == -1)
		# Of the rig's own `_set`, which every object has a method called.
		if Sfx.has(StringName(wild.get(&"_set").voice + "_panic")):
			_check("it screams", screamed)
		else:
			print("  [--] there is no scream for the voice of this theme")
		witness.take_damage(1e6, witness.global_position + Vector3.UP, Vector3.LEFT)
		await _wait(0.4)
		_check("and dies like any other, its scream cut short", witness.dead and not is_instance_valid(wild._scream))
		nervous[2].free()
		var loner: CharacterBody3D = game.GRUNT.instantiate()
		loner.panics = true
		loner.position = player.global_position + Vector3(-8, 0, 0)
		game.add_child(loner)
		loner.take_damage(loner.max_health * 0.5, loner.global_position + Vector3.UP, Vector3.LEFT)
		var held: bool = loner._mode != loner.Mode.PANIC
		loner.take_damage(loner.max_health * 0.15, loner.global_position + Vector3.UP, Vector3.LEFT)
		_check("one that is badly hurt loses its head as well", held and not loner.dead and loner._mode == loner.Mode.PANIC)
	else:
		print("  [--] the grunt of this theme is a robot, and a robot keeps its head")

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
	for control: Control in Menu._column.find_children("*", "Button", true, false):
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
