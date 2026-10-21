extends Node
## Headless test of the enemies that are people. Run with: tools/test_humanoid.sh
##
## It plays the first fight of the factory with a theme of characters (the
## mannequins, unless --enemies= names another) and checks what selftest.gd
## checks for robots: that they come for the player, hit, and die, and that
## one of them fights from cover. On top of that it has some lose their
## heads, walks one in every direction and measures how far its feet slide
## while they are down, and it looks at what is left of one that has died:
## on its back, or on its face if the shot came from behind. It walks one up
## the stairs of the hall to see its feet follow them, and looks at what one
## that fights hand to hand holds. Last come the robots, for what their rig
## does by itself: switched off where they are posted, and not moving a joint
## when they stand still.

const HUMANOID := preload("res://scripts/humanoid_rig.gd")
const THEMES := preload("res://scripts/enemy_themes.gd")
## An open lane in the factory with 6 m of clear floor to the east of it.
const RANGE_TARGET := Vector3(1, 0, -7.5)
## Metres a second a foot may slide while it is down.
const SLIDE := 0.05
## The stairs of the hall: between these two the floor slopes, and they are
## climbed going west.
const STAIRS_FOOT := Vector3(2.5, 0, -10.9)
const STAIRS_HEAD := Vector3(-1.7, 0, -10.9)
## Metres a foot that is down may be off the floor under it.
const OFF_FLOOR := 0.06

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
	_check("who sound like flesh where a shot lands", Sfx.has(&"impact_flesh") and enemies.all(func(e: Node) -> bool: return e.get_node("CollisionShape3D").get_meta(&"surface") == "flesh"))
	_check("who carry no plate and no pack, and duck only if they go down on one knee", enemies.all(func(e: Node) -> bool: return e._shield == 0.0 and e._pack == 0.0 and e._drop == float(e._rig.crouch_drop)))
	var kneels := enemies.filter(func(e: Node) -> bool: return e._drop > 0.0)
	if not kneels.is_empty():
		var drop: float = kneels[0]._drop
		_check("who duck behind something low on one knee (eyes %.2f m down)" % drop, drop > 0.4 and drop < 0.95)
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
		var arm: Node3D = rusher._rig
		if arm._wielding:
			var held: Node3D = arm._weapon
			var hand: Vector3 = arm._skeleton.global_transform * arm._global(arm._arms[1].end).origin
			_check("with what it holds in its right hand", arm._blows() == arm.get(&"_set").strikes and held.global_position.distance_to(hand) < 0.2)
			rusher.take_damage(1e6, rusher.global_position + Vector3.UP, Vector3.LEFT)
			_check("which it lets go of when it dies", arm._weapon == null and not arm.is_ancestor_of(held))
		else:
			print("  [--] the rusher of this theme strikes with its hands")
	else:
		print("  [--] the rusher of this theme does not fight hand to hand, or is a robot")
	rusher.queue_free()

	# Shot from in front it goes down on its back, shot from behind on its face.
	var falls := []
	for from_behind: bool in [false, true]:
		var one: CharacterBody3D = game.GRUNT.instantiate()
		one.position = RANGE_TARGET + Vector3(0, 0, 3.0 if from_behind else 0.0)
		game.add_child(one)
		one.set_physics_process(false)
		falls.append(one)
		if _is_character(one):
			# An enemy looks along -Z.
			one.take_damage(1e6 if from_behind else one.health, one.global_position + Vector3.UP * 1.2, one.global_basis.z * (-1.0 if from_behind else 1.0))
	if falls.all(_is_character):
		await _wait(2.6)
		var ways := []
		for one: CharacterBody3D in falls:
			var body: Node3D = one._rig
			var ribs: int = body._torso[-1]
			body._g.clear()
			var lies: Transform3D = body._skeleton.global_transform * body._global(ribs)
			# Which way the chest faces, and how far in front of where it stood it lies.
			ways.append([(lies.basis * body._rest_global(ribs).basis.inverse() * Vector3.BACK).y, (one.global_basis.inverse() * (lies.origin - one.global_position)).z])
		_check("shot from in front it lies on its back, behind where it stood", ways[0][0] > 0.5 and ways[0][1] > 0.2)
		_check("shot from behind it lies on its face, in front of where it stood", ways[1][0] < -0.5 and ways[1][1] < -0.2)
	for one: CharacterBody3D in falls:
		one.queue_free()
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
				["backwards", Vector3.BACK, fast * 0.5], ["forwards and left", Vector3(-0.7, 0, -0.7), fast * 0.7], ["forwards at a trot", Vector3.FORWARD, 3.0]]:
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
					if lap[2] == 3.0:
						# Neither a walk in a hurry nor a run slowed down.
						var cycle: String = legs.get(&"_set").gaits[legs._gait]
						_check("3 m/s is a pace of its own (%s, steps %.2f times as long as made)" % [cycle, legs._stretch], cycle.ends_with("trot") and absf(legs._stretch - 1.0) < 0.15)
			worst = maxf(worst, slides[1])
			print("    feet slide %.3f m/s %s; left to the clips they would slide %.3f m/s" % [slides[1], lap[0], slides[0]])
		_check("feet that are down stay put (worst %.3f m/s)" % worst, worst < SLIDE)
		_walker.global_position = RANGE_TARGET
		_stride = Vector3.RIGHT * 2.0
		_walker.velocity = _stride
		await _wait(1.0)
		_check("on a level floor both feet are left at the height of the body", legs._rise[0] == 0.0 and legs._rise[1] == 0.0)

		# Up the stairs of the hall: each foot that is down stands on the floor
		# there is under it. The body is moved along the slope by hand.
		var foot_of := Vector3(STAIRS_FOOT.x, _floor_at(STAIRS_FOOT), STAIRS_FOOT.z)
		var head_of := Vector3(STAIRS_HEAD.x, _floor_at(STAIRS_HEAD), STAIRS_HEAD.z)
		var climb := (head_of - foot_of).normalized() * 2.0
		var off := []
		for follow: bool in [false, true]:
			legs.follow_floor = follow
			legs.lock_feet = true
			_walker.global_position = foot_of
			_walker.look_at(Vector3(head_of.x, foot_of.y, head_of.z))
			legs.aim(_walker.global_position + Vector3(-30, 8, 0))
			_stride = climb
			_walker.velocity = climb
			await _wait(0.5)
			var worst_off := 0.0
			var apart := 0.0
			for i in 24:
				await _wait(0.05)
				legs._g.clear()
				var balls := []
				for side in 2:
					var ball: Vector3 = legs._skeleton.global_transform * legs._global(legs._balls[side]).origin
					balls.append(ball.y)
					if legs._planted[side]:
						worst_off = maxf(worst_off, absf(ball.y - _floor_at(ball) - 0.03))
				apart = maxf(apart, absf(balls[0] - balls[1]))
			off.append([worst_off, apart])
		_stride = Vector3.ZERO
		_check("the stairs rise (%.1f m over %.1f m)" % [head_of.y - foot_of.y, foot_of.x - head_of.x], head_of.y - foot_of.y > 2.0)
		print("    on the stairs a foot that is down is at most %.3f m off the floor under it; left at the height of the body, %.3f m" % [off[1][0], off[0][0]])
		_check("feet follow the stairs, one above the other (up to %.2f m)" % off[1][1], off[1][0] < OFF_FLOOR and off[0][0] > OFF_FLOOR * 2.0 and off[1][1] > 0.15)

		# With a weapon it stands with its feet apart, and swung round where it
		# stands it steps until they are under it again, one foot at a time and
		# without a foot sliding over the floor.
		if legs.get(&"_hold") != 0:
			legs.follow_floor = true
			_walker.global_position = RANGE_TARGET
			_walker.rotation = Vector3.ZERO
			_walker.velocity = Vector3.ZERO
			legs.aim(_walker.global_position + Vector3(0, 1.4, -30))
			await _wait(1.2)
			var gap := _feet_apart(legs)
			_check("standing with a weapon its feet are apart (%.2f m)" % gap, gap > 0.25 and gap < 0.55)
			legs.slid = 0.0
			legs.stood = 0.0
			_walker.rotation.y = deg_to_rad(-70.0)
			legs.aim(_walker.global_position + _walker.global_basis * Vector3(0, 1.4, -30))
			var steps := 0
			var both := false
			var was := [false, false]
			for i in 40:
				await _wait(0.03)
				var now := [legs._stepping[0] >= 0.0, legs._stepping[1] >= 0.0]
				both = both or (now[0] and now[1])
				for side in 2:
					if now[side] and not was[side]:
						steps += 1
				was = now
			var settled: bool = legs._planted[0] and legs._planted[1] and not was[0] and not was[1]
			var slide: float = legs.slid / maxf(legs.stood, 0.01)
			_check("swung round 70 degrees where it stands it steps until its feet are under it (%d steps, %.3f m/s while down)" % [steps, slide], steps >= 2 and not both and settled and slide < SLIDE)
		_walker.global_position = RANGE_TARGET
		_walker.rotation = Vector3.ZERO
		# What a frame of all that costs in script and animation, for the record:
		# back and forth over the floor of the hall, with and without looking
		# for the floor under each foot.
		legs.set_process(false)
		var cost := []
		for follow: bool in [false, true, false, true]:
			legs.follow_floor = follow
			_walker.global_position = RANGE_TARGET
			var began := Time.get_ticks_usec()
			for i in 600:
				_walker.velocity = Vector3.RIGHT * 2.5 * (1.0 if i % 240 < 120 else -1.0)
				_walker.global_position += _walker.velocity / 60.0
				legs._pose(1.0 / 60.0)
			cost.append((Time.get_ticks_usec() - began) / 600.0)
		var blend := Time.get_ticks_usec()
		for i in 600:
			legs._tree.advance(1.0 / 60.0)
		print("    posing it takes %d microseconds a frame, %d of them to blend the clips and %d to find the floor under its feet" % [
			(cost[1] + cost[3]) * 0.5, (Time.get_ticks_usec() - blend) / 600.0, (cost[1] + cost[3] - cost[0] - cost[2]) * 0.5])
	else:
		_check("the grunt of this theme is a character", false)
	_walker.queue_free()

	# The robots: what their rig does without being asked. One that is stopped
	# where it stands is switched off, as game.gd stops those it posts: its
	# lamps out and its head on its chest. Started again it comes on, and once
	# it stands still nothing of it moves, so no lamp has a shadow to draw again.
	Settings.enemy_theme = THEMES.ROBOTS
	for scene: PackedScene in [game.GRUNT, game.RUSHER, game.HEAVY]:
		var robot: CharacterBody3D = scene.instantiate()
		robot.position = RANGE_TARGET
		game.add_child(robot)
		robot.set_physics_process(false)
		var frame: Node3D = robot._rig
		var kind: String = robot.role
		var visor: MeshInstance3D = frame._joints["GlowVisor"]
		var middle := visor.get_aabb().get_center()
		var up := (visor.global_transform * middle).y
		robot.process_mode = Node.PROCESS_MODE_DISABLED
		var lamps: StandardMaterial3D = frame._glow_mat
		_check("a %s that is stopped where it stands is switched off: lamps out, head down" % kind, lamps.emission_energy_multiplier == 0.0 and (visor.global_transform * middle).y < up - 0.03)
		robot.process_mode = Node.PROCESS_MODE_INHERIT
		await _wait(frame.WAKE_TIME + 0.6)
		_check("started again it comes on", lamps.emission_energy_multiplier > 1.0 and absf((visor.global_transform * middle).y - up) < 0.005)
		var stood := {}
		for mesh: MeshInstance3D in frame._meshes:
			stood[mesh] = mesh.global_transform
		await _wait(0.5)
		_check("and standing still it does not move a joint", frame._meshes.all(func(mesh: MeshInstance3D) -> bool: return mesh.global_transform == stood[mesh]))
		robot.free()
	Settings.enemy_theme = theme

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


## How far apart its feet are on the floor, in metres.
func _feet_apart(legs: Node3D) -> float:
	legs._g.clear()
	var feet := []
	for side in 2:
		feet.append(legs._skeleton.global_transform * legs._global(legs._legs[side].end).origin)
	return Vector2(feet[0].x - feet[1].x, feet[0].z - feet[1].z).length()


func _is_character(enemy: Node) -> bool:
	return enemy._rig.get_script() == HUMANOID


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


## How high the floor of the level is under `at`.
func _floor_at(at: Vector3) -> float:
	var space := (get_tree().current_scene as Node3D).get_world_3d().direct_space_state
	var found := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, 6.0, at.z), Vector3(at.x, -1.0, at.z), 1))
	return found.position.y if found else 0.0
