extends Node
## Films one take of the trailer, as tools/trailer.sh asks: the game runs under
## Movie Maker with --direct=res://tools/trailer/director.gd --take=<name>, and
## this plays it. A take sets a scene up out of sight of the film (a level, who
## is in it, where the eye is), then calls action() and lets it run for as long
## as the cut needs; what came before is cut away. A take that films more than
## one scene names each: action("depot"). The frames at which they began go to
## the file --marks= names, for tools/trailer/cut.py.
##
## The player is driven the way the tests drive it: force_control, and the
## actions of the input map pressed and let go. Where it looks is set here
## every frame, after everything else has moved, so that recoil and sway come
## on top as they do in the hand. Nobody can hurt it. The HUD shows only what
## belongs to the picture: the scope, a hit, the edge of the screen when hurt.
## A take can also look through an eye of its own, which moves along a path.

const ARMORY := preload("res://scripts/armory.gd")
const FPS := 60
## The layer of the weapon in view, which an eye of its own does not see.
const VIEW_LAYER := 2
## Seconds of the clock on the wall a take may take, all in: one that is
## stuck would otherwise go on filming until the disk is full.
const DEADLINE := 240.0
const TITLE := "GRAPHICS FPS"

var tree: SceneTree
var game: Node3D
var player: CharacterBody3D
## An eye of the take's own, null while it looks through the player's.
var eye: Camera3D

var _take := ""
var _marks := ""
var _actions := {}
## What the player looks at: a node, with `_aim_lift` metres above its feet,
## or a point; how fast its gaze gets there, per second; and how far it
## wanders about that, in metres there.
var _aim: Variant = null
var _aim_lift := 1.2
var _aim_rate := 8.0
var _sway := 0.0
var _clock := 0.0
## Where an eye of its own goes: a Callable from seconds to a Transform3D.
var _path := Callable()
var _path_time := 0.0
var _hud: CanvasLayer
var _hud_shown: Array = []
## The bot that the eye rides behind in a match, and where the eye is.
var _rider: CharacterBody3D
var _ride_at := Vector3.ZERO
## No wisp of smoke from the barrel when it falls silent: through a scope it
## fills the view just as what was shot at falls.
var _no_smoke := false


func _ready() -> void:
	# After the player and its weapons, so that what is set here holds.
	process_priority = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	tree = get_tree()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--take="):
			_take = arg.get_slice("=", 1)
		elif arg.begins_with("--marks="):
			_marks = arg.get_slice("=", 1)
	# The music is laid under the cut as one piece: none in the takes.
	Settings.music = 0.0
	Settings.show_fps = false
	Settings.apply()
	await tree.process_frame
	if not has_method("take_" + _take):
		push_error("trailer: no take called '%s'" % _take)
		tree.quit(1)
		return
	await Callable(self, "take_" + _take).call()
	_finish()


## The cut begins here; `scene` names it in a take of more than one.
func action(scene := "action") -> void:
	_actions[scene] = Engine.get_frames_drawn()


func _finish() -> void:
	if _marks:
		var file := FileAccess.open(_marks, FileAccess.WRITE)
		file.store_string(JSON.stringify({"take": _take, "actions": _actions, "end": Engine.get_frames_drawn()}))
		file.close()
	for action_name in ["fire", "ads", "move_forward", "move_back", "move_left", "move_right", "sprint", "crouch"]:
		Input.action_release(action_name)
	tree.quit()


## Lets `seconds` of the game go by, which under Movie Maker is a number of
## frames.
func hold(seconds: float) -> void:
	for i in maxi(roundi(seconds * FPS), 1):
		await tree.process_frame


## Goes to a level and makes it quiet: who stands at the posts of its route is
## gone, walking into a zone starts nothing, and the player is beyond hurting.
func level(level_name: String) -> void:
	eye = null
	_path = Callable()
	_aim = null
	tree.change_scene_to_file("res://scenes/%s.tscn" % level_name)
	await tree.scene_changed
	await _settle_in()
	for zone: RefCounted in game.zones:
		zone.area.set_deferred("monitoring", false)
		for robot: Variant in zone.robots:
			if is_instance_valid(robot):
				robot.queue_free()
		zone.robots.clear()
		zone.alive = 0
		zone.watched = false
	for checkpoint: RefCounted in game.checkpoints:
		checkpoint.area.set_deferred("monitoring", false)
	player.force_control = true
	player.invulnerable = true


func _settle_in() -> void:
	game = tree.current_scene
	player = game.player
	for i in 3:
		await tree.physics_frame
	_hud = tree.get_first_node_in_group("hud")
	if _hud:
		_hud_shown = [_hud._scope, _hud._vignette, _hud._hitmarker, _hud._curtain]


## How high the ground is at x and z: what the first thing under a point high
## above stops.
func ground(x: float, z: float, from := 400.0) -> float:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(x, from, z), Vector3(x, -100.0, z), 1)
	var hit := game.get_world_3d().direct_space_state.intersect_ray(ray)
	return (hit.position as Vector3).y if hit else 0.0


## On the ground at x and z, `up` metres above it. Indoors the ground is
## looked for under the roof: from `from` metres up.
func on_ground(x: float, z: float, up := 0.0, from := 400.0) -> Vector3:
	return Vector3(x, ground(x, z, from) + up, z)


## Stands the player at x and z, looking along `yaw` and `pitch` in degrees.
func stand(x: float, z: float, yaw: float, pitch := 0.0, from := 400.0) -> void:
	player.global_position = on_ground(x, z, 0.0, from)
	player.velocity = Vector3.ZERO
	player.rotation = Vector3(0.0, deg_to_rad(yaw), 0.0)
	player.head.rotation.x = deg_to_rad(pitch)


## Puts one enemy of `kind` (grunt, rusher, heavy) of the theme `theme` on the
## ground at x and z, facing `towards`. It stands still until woken.
func enemy(kind: String, x: float, z: float, towards: Vector3, theme := "", from := 400.0) -> CharacterBody3D:
	if theme:
		Settings.enemy_theme = theme
	var zone: RefCounted = game.zones[0]
	return game.post(zone, kind, on_ground(x, z, 0.0, from), towards)


## Has it fight: it knows where the player is from now on.
func wake(robot: CharacterBody3D) -> void:
	robot.process_mode = Node.PROCESS_MODE_INHERIT
	robot.alert()


## Has it stand guard where it is, looking about, knowing of nothing.
func on_watch(robot: CharacterBody3D, looks := 30.0) -> void:
	robot.process_mode = Node.PROCESS_MODE_INHERIT
	robot.watch(PackedVector3Array(), false, looks)


## Gives the player one weapon of the armoury in hand: a special one such as
## the minigun as found in an arena, any other as the only one it carries.
func arm(weapon_name: String) -> void:
	var data: WeaponData = ARMORY.named(weapon_name)
	if data.special:
		player.weapons.take_special(data, data.mag_size + data.reserve_ammo, true)
	else:
		var only: Array[WeaponData] = [data]
		player.weapons.equip(only)


## Has the player look at `what` (a node, `lift` metres above its feet, or a
## point), getting there at `rate` per second and wandering `sway` metres
## about it; null lets the gaze be.
func look_at_it(what: Variant, lift := 1.2, rate := 8.0, sway := 0.0) -> void:
	_aim = what
	_aim_lift = lift
	_aim_rate = rate
	_sway = sway


## Turns the player at once to where look_at_it() would take it.
func face(what: Variant, lift := 1.2) -> void:
	look_at_it(what, lift)
	var angles := _aim_angles()
	player.rotation.y = angles.x
	player.head.rotation.x = angles.y


func press(action_name: String, down := true) -> void:
	if down:
		Input.action_press(action_name)
	else:
		Input.action_release(action_name)


## Pulls the trigger for `seconds`.
func fire(seconds := 0.08) -> void:
	press("fire")
	await hold(seconds)
	press("fire", false)


## The nearest of `enemies` that is still standing, null if none is.
func nearest(enemies: Array) -> CharacterBody3D:
	var best: CharacterBody3D = null
	for one: CharacterBody3D in enemies:
		if is_instance_valid(one) and not one.dead:
			if best == null or one.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position):
				best = one
	return best


## Looks through an eye of the take's own, which `path` moves: a Callable that
## takes the seconds since now and gives where the eye is. The weapon in view
## is not seen from there, nor the player.
func film(path: Callable, fov := 60.0) -> void:
	if eye == null or not is_instance_valid(eye):
		eye = Camera3D.new()
		eye.near = 0.05
		eye.set_cull_mask_value(VIEW_LAYER, false)
		game.add_child(eye)
	eye.fov = fov
	_path = path
	_path_time = 0.0
	eye.global_transform = path.call(0.0)
	eye.make_current()
	player.visible = false


## A path from `from` to `to` over `seconds`, eased, that looks at `target`
## all the way.
func dolly(from: Vector3, to: Vector3, target: Vector3, seconds: float) -> Callable:
	return func(t: float) -> Transform3D:
		var at := from.lerp(to, smoothstep(0.0, 1.0, clampf(t / seconds, 0.0, 1.0)))
		return Transform3D(Basis.looking_at(target - at), at)


## A path that starts at `view` and moves `by` (in the axes of the view) over
## `seconds`, looking the way the view looks.
func drift(view: Transform3D, by: Vector3, seconds: float) -> Callable:
	return func(t: float) -> Transform3D:
		var share := clampf(t / seconds, 0.0, 1.0)
		return Transform3D(view.basis, view.origin + view.basis * (by * share))


## A view of the level by the name of its marker in BenchmarkViews.
func view(view_name: String) -> Transform3D:
	return (game.get_node("BenchmarkViews/" + view_name) as Node3D).global_transform


## A view from x, y (above the ground, or absolute if `absolute`) and z
## looking along yaw and pitch in degrees.
func pose(x: float, y: float, z: float, yaw: float, pitch := 0.0, absolute := false) -> Transform3D:
	var at := Vector3(x, y, z) if absolute else on_ground(x, z, y)
	return Transform3D(Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0)), at)


## What the gaze is after, as yaw and pitch.
func _aim_angles() -> Vector2:
	var point: Vector3 = _aim if _aim is Vector3 else (_aim as Node3D).global_position + Vector3.UP * _aim_lift
	if _sway > 0.0:
		point += Vector3(sin(_clock * 1.3) + 0.5 * sin(_clock * 2.9), 0.7 * sin(_clock * 1.7 + 1.0), 0.0) * _sway
	var direction: Vector3 = (point - player.head.global_position).normalized()
	return Vector2(atan2(-direction.x, -direction.z), asin(clampf(direction.y, -1.0, 1.0)))


func _process(delta: float) -> void:
	_clock += delta
	if Time.get_ticks_msec() > DEADLINE * 1000.0:
		push_error("trailer: the take '%s' did not finish in %d s" % [_take, DEADLINE])
		tree.quit(1)
	if _hud and is_instance_valid(_hud):
		for child: Control in _hud._root.get_children():
			if not child in _hud_shown:
				child.visible = false
	if not is_instance_valid(player):
		return
	if _no_smoke:
		player.weapons._smoke_due = false
	if _aim != null and (not _aim is Object or is_instance_valid(_aim)):
		var angles := _aim_angles()
		var weight := 1.0 - exp(-_aim_rate * delta)
		player.rotation.y = lerp_angle(player.rotation.y, angles.x, weight)
		player.head.rotation.x = lerpf(player.head.rotation.x, angles.y, weight)
	if eye and is_instance_valid(eye) and _path.is_valid():
		_path_time += delta
		eye.global_transform = _path.call(_path_time)


## A sniper's shot in the dunes: through the scope at a guard by the tent of
## the bivouac, who has not seen the player; the crosshair settles on his head,
## one shot.
func take_sniper() -> void:
	await level("dunes")
	arm("bolt_rifle")
	_no_smoke = true
	var guard := enemy("grunt", 262.0, 120.0, Vector3(262.0, 0.0, 100.0), "soldiers_desert")
	# He is looking the other way, as far as seeing the player goes.
	guard.sight_lit = 3.0
	on_watch(guard, 25.0)
	stand(240.0, 124.0, -90.0)
	face(guard, 0.9)
	await hold(2.0)
	action()
	await hold(0.15)
	press("ads")
	look_at_it(guard, 0.9, 2.5, 0.1)
	await hold(0.9)
	look_at_it(guard, 1.62, 3.5, 0.03)
	await hold(0.75)
	await fire()
	look_at_it(null)
	await hold(1.6)


## The minigun in the dunes: the barrels already turning, it mows through
## soldiers coming across the motor pool.
func take_minigun() -> void:
	await level("dunes")
	arm("minigun")
	var soldiers: Array = []
	var spots := [Vector2(186, 113), Vector2(192, 116), Vector2(182, 119), Vector2(196, 121), Vector2(188, 123), Vector2(179, 114), Vector2(194, 111), Vector2(184, 126)]
	for i in spots.size():
		soldiers.append(enemy(["grunt", "rusher", "grunt", "grunt", "heavy", "rusher", "grunt", "grunt"][i], spots[i].x, spots[i].y, Vector3(189, 0, 100), "soldiers_desert"))
	stand(189.0, 100.0, 180.0)
	face(soldiers[0], 1.1)
	# The barrels spin up on the other trigger, without firing.
	press("ads")
	await hold(1.0)
	for soldier: CharacterBody3D in soldiers:
		wake(soldier)
	await hold(0.8)
	action()
	press("fire")
	press("move_forward")
	for i in 240:
		var target := nearest(soldiers)
		if target == null:
			break
		if _aim != target:
			look_at_it(target, 1.1, 5.0)
		if i == 90:
			press("move_forward", false)
		await tree.process_frame
	press("fire", false)
	press("ads", false)
	await hold(0.5)


## Soldiers in action at the works: seen from beside the player, low, they
## come down an alley against the low sun and fire, and are fired at over
## their heads.
func take_soldiers() -> void:
	await level("works")
	arm("rifle")
	var soldiers: Array = []
	var spots := [Vector2(40, 30), Vector2(37, 33), Vector2(34, 30.5), Vector2(31, 32.5), Vector2(38.5, 32)]
	for i in spots.size():
		soldiers.append(enemy(["rusher", "grunt", "grunt", "heavy", "rusher"][i], spots[i].x, spots[i].y, Vector3(54, 0, 31), "soldiers"))
	stand(54.0, 31.0, 90.0)
	await hold(1.0)
	for soldier: CharacterBody3D in soldiers:
		wake(soldier)
	film(dolly(on_ground(51.0, 32.6, 0.7), on_ground(50.6, 31.8, 0.85), on_ground(36.0, 31.0, 1.3), 3.0), 55.0)
	await hold(1.2)
	action()
	# The player's shots go over their heads: they are here to be seen.
	for i in 200:
		var target := nearest(soldiers)
		if target:
			face(target, 3.0)
		press("fire", i % 40 < 14)
		await tree.process_frame
	press("fire", false)


## Clowns in action in the factory hall: seen low from beside the player, they
## come through the sunlight with their cleavers and pistols, and are fired at
## over their heads.
func take_clowns() -> void:
	await level("factory")
	arm("smg")
	var clowns: Array = []
	var spots := [Vector2(6, 3), Vector2(4, 6), Vector2(7.5, 0), Vector2(3, 1), Vector2(2, 4.5), Vector2(5, -2)]
	for i in spots.size():
		clowns.append(enemy(["rusher", "rusher", "rusher", "grunt", "grunt", "grunt"][i], spots[i].x, spots[i].y, Vector3(17, 0, 8), "clowns", 2.2))
	stand(17.0, 8.0, 112.0, 0.0, 2.2)
	await hold(1.0)
	for clown: CharacterBody3D in clowns:
		wake(clown)
	film(dolly(on_ground(15.0, 9.2, 0.6, 2.2), on_ground(14.6, 7.8, 0.75, 2.2), on_ground(4.0, 3.0, 1.3, 2.2), 3.0), 55.0)
	await hold(0.6)
	action()
	for i in 200:
		var target := nearest(clowns)
		if target:
			face(target, 3.0)
		press("fire", i % 30 < 12)
		await tree.process_frame
	press("fire", false)


## Robots in action in the turbine hall of the powerhouse: they come, they
## fire, and are shot to pieces.
func take_robots() -> void:
	await level("powerhouse")
	arm("rifle")
	var robots: Array = []
	var spots := [Vector2(66, 16), Vector2(68, 19.5), Vector2(70, 14), Vector2(72, 18)]
	for i in spots.size():
		robots.append(enemy(["grunt", "heavy", "rusher", "grunt"][i], spots[i].x, spots[i].y, Vector3(58, 0, 17), "robots", 2.2))
	stand(58.0, 17.0, -93.5, 0.0, 2.2)
	face(robots[0], 1.2)
	await hold(1.0)
	for robot: CharacterBody3D in robots:
		wake(robot)
	await hold(1.0)
	action()
	for i in 200:
		var target := nearest(robots)
		if target == null:
			break
		if _aim != target:
			look_at_it(target, 1.1, 6.0)
		press("fire", i % 30 < 20)
		await tree.process_frame
	press("fire", false)
	await hold(0.5)


## A barrel that goes up in the factory, by the door where the sun comes in,
## with the soldiers who come through it.
func take_barrels() -> void:
	await level("factory")
	arm("rifle")
	var barrel: Node3D = null
	var at := Vector3(17.9, 0.5, -5.9)
	for one: Node3D in tree.get_nodes_in_group("explosive"):
		if barrel == null or one.global_position.distance_to(at) < barrel.global_position.distance_to(at):
			barrel = one
	var soldiers: Array = []
	for spot: Vector2 in [Vector2(19.2, -7.2), Vector2(18.9, -4.6)]:
		var soldier := enemy("grunt", spot.x, spot.y, Vector3(12, 0, -4), "soldiers", 2.2)
		soldier.heeds_danger = false
		soldier.takes_cover = false
		soldiers.append(soldier)
	stand(12.0, -4.0, -36.6, -4.0, 2.2)
	face(barrel.global_position + Vector3.UP * 0.5)
	await hold(1.0)
	for soldier: CharacterBody3D in soldiers:
		wake(soldier)
	await hold(0.3)
	action()
	look_at_it(barrel.global_position + Vector3.UP * 0.5, 0.0, 10.0, 0.02)
	await hold(0.45)
	await fire(0.25)
	await hold(0.25)
	if not barrel.gone:
		barrel.explode()
	await hold(2.0)


## The shotgun in the pump house of the powerhouse: a soldier comes down the
## aisle at a run, and is met at a few metres; then the one behind him.
func take_shotgun() -> void:
	await level("powerhouse")
	arm("shotgun")
	var first := enemy("rusher", 34.6, 29.4, Vector3(37, 0, 25.2), "soldiers", 2.2)
	var second := enemy("grunt", 33.2, 32.0, Vector3(37, 0, 25.2), "soldiers", 2.2)
	# They come in with the butt of the rifle, as close as can be.
	for one in [first, second]:
		one.takes_cover = false
		one.heeds_danger = false
		one.melee = true
		one.preferred_range = 1.3
		one.attack_range = 1.9
	stand(37.0, 25.2, 30.0, 0.0, 2.2)
	face(first, 1.2)
	await hold(1.0)
	wake(first)
	wake(second)
	await hold(0.2)
	action()
	look_at_it(first, 1.15, 12.0)
	for i in 60:
		if first.dead or first.global_position.distance_to(player.global_position) < 3.2:
			break
		await tree.process_frame
	await fire()
	await hold(0.45)
	look_at_it(second, 1.15, 10.0)
	await hold(0.3)
	await fire()
	await hold(1.0)


## Six against six in the works, bots only. Both sides are stood across the
## yard from each other, and the eye rides behind one of them into the fight.
func take_match() -> void:
	Match.open({"mode": "tdm", "level": "works", "size": 6, "only_bots": true})
	await tree.scene_changed
	await _settle_in()
	while not Match.playing():
		await tree.process_frame
	await hold(0.5)
	var map: RID = game.get_world_3d().navigation_map
	var sides := [0, 0]
	for one: RefCounted in Match.entrants.values():
		if one.body == null:
			continue
		var row: int = sides[one.team]
		sides[one.team] += 1
		var spot := Vector3(19.0 if one.team == 0 else 50.0, 0.0, 24.0 + row * 3.0)
		one.body.global_position = NavigationServer3D.map_get_closest_point(map, spot)
		one.body.velocity = Vector3.ZERO
		one.body.rotation.y = -PI * 0.5 if one.team == 0 else PI * 0.5
	await hold(1.2)
	_rider = _pick_rider()
	_ride_at = Vector3.ZERO
	film(_ride, 65.0)
	await hold(0.2)
	action()
	await hold(3.5)


## Over the shoulder of the bot being ridden, following it a little late.
func _ride(_t: float) -> Transform3D:
	if not is_instance_valid(_rider):
		return eye.global_transform
	var basis := _rider.global_basis
	var want := _rider.global_position + basis.z * 2.6 + Vector3.UP * 1.9 + basis.x * 0.7
	_ride_at = want if _ride_at == Vector3.ZERO else _ride_at.lerp(want, 0.12)
	return Transform3D(Basis.looking_at(_rider.global_position + Vector3.UP * 1.3 - basis.z * 8.0 - _ride_at), _ride_at)


## The bot to ride behind: the one of the first side that is nearest to one
## of the other.
func _pick_rider() -> CharacterBody3D:
	var best: CharacterBody3D = null
	var gap := INF
	for one: RefCounted in Match.entrants.values():
		if one.team != 0 or one.body == null or one.out > 0.0:
			continue
		for other: RefCounted in Match.entrants.values():
			if other.team == 0 or other.body == null or other.out > 0.0:
				continue
			var distance: float = one.body.global_position.distance_to(other.body.global_position)
			if distance < gap:
				gap = distance
				best = one.body
	return best


## Every map, one after the other, each seen from where it looks its best.
func take_maps() -> void:
	await level("factory")
	film(drift(view("Overview"), Vector3(1.2, 0.0, -0.6), 1.2), 70.0)
	await hold(1.2)
	action("factory")
	await hold(1.0)
	await level("works")
	film(drift(pose(20.0, 3.0, 31.0, -90.0, -3.0), Vector3(0.0, 0.0, -1.5), 1.2), 70.0)
	await hold(1.2)
	action("works")
	await hold(1.0)
	await level("depot")
	film(drift(view("Overview"), Vector3(1.2, 0.0, -0.6), 1.2), 70.0)
	await hold(1.2)
	action("depot")
	await hold(1.0)
	await level("powerhouse")
	film(drift(view("TurbineHall"), Vector3(0.0, 0.0, -1.5), 1.2), 70.0)
	await hold(1.2)
	action("powerhouse")
	await hold(1.0)
	await level("dunes")
	film(drift(pose(255.0, 1.8, 121.0, -90.0, -2.0), Vector3(0.0, 0.0, -1.5), 1.2), 70.0)
	await hold(1.5)
	action("dunes")
	await hold(1.0)


## The name of the game over the dunes at the end.
func take_title() -> void:
	await level("dunes")
	var from := pose(232.0, 1.7, 122.0, -90.0, 3.0)
	film(drift(from, Vector3(0.0, 0.4, -3.0), 4.0), 60.0)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var name_label := Label.new()
	name_label.text = TITLE
	name_label.add_theme_font_size_override("font_size", 160)
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	name_label.add_theme_constant_override("shadow_offset_x", 0)
	name_label.add_theme_constant_override("shadow_offset_y", 6)
	name_label.add_theme_constant_override("shadow_outline_size", 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_label.modulate.a = 0.0
	layer.add_child(name_label)
	await hold(1.5)
	action()
	await hold(0.4)
	var tween := create_tween().set_parallel()
	tween.tween_property(shade, "color:a", 0.45, 0.5)
	tween.tween_property(name_label, "modulate:a", 1.0, 0.2)
	name_label.pivot_offset = Vector2(960, 540)
	name_label.scale = Vector2(1.15, 1.15)
	tween.tween_property(name_label, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await hold(3.0)
