extends Node
## Headless test of the Unmuted match. Run with: tools/test_unmuted.sh
##
## The stickers: one fired at a wall sticks there as a decal; one of the other
## side that lands on it takes its place, one of the same side next to it does
## not; there are never more than Stickers.MOST; a sticker draws less as it
## ages and nothing once it is PULL seconds old or the ICP has seen it; one
## that meets the ICP is gone; one that meets somebody hurts them by the
## damage of the Branding Gun and stays on them.
##
## The ICP match (scripts/modes/icp.gd), in the factory: there are two bases
## and the ICP stands in the middle; nothing draws him while there are no
## stickers; he goes to those of the side whose stickers draw him most, and
## a sticker he has come to draws no more; once he is at a base that side
## scores, every sticker is gone and he is back in the middle a moment later.
## Then the bots play: both sides stick, and one side alone wins him over.

const STICKERS := preload("res://scripts/stickers.gd")
const STICKER := preload("res://scenes/sticker.tscn")
const LEVEL := "res://scenes/factory.tscn"
const ARMORY := preload("res://scripts/armory.gd")

## True for a run of this test.
var active := false

var _failures := 0
var _checks := 0


func _ready() -> void:
	active = "--unmutedtest" in OS.get_cmdline_user_args()
	if active:
		SelfTest.active = true
		_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	tree.create_timer(300.0, true, true, true).timeout.connect(
		func() -> void:
			print("UNMUTED TEST FAILED (timed out)")
			tree.quit(1)
	)
	await _wait(0.3)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--soak="):
			await _soak(arg.get_slice("=", 1).to_float())
			tree.quit(0)
			return
	tree.change_scene_to_file(LEVEL)
	await _wait(1.0)
	var player: CharacterBody3D = tree.current_scene.player
	player.force_control = true
	player.health = 1e7
	await _stickers(player)
	await _icp()
	print("%d checks, %d failed" % [_checks, _failures])
	print("UNMUTED TEST PASSED" if _failures == 0 else "UNMUTED TEST FAILED")
	tree.quit(0 if _failures == 0 else 1)


func _stickers(player: CharacterBody3D) -> void:
	var gun := ARMORY.named("branding_gun")
	_check("the Branding Gun is in the armory", gun != null and gun.projectile == STICKER)
	_check("the pack Unmuted carries it", ARMORY.weapons("unmuted") == [gun])
	_check("four stickers put somebody of 100 down", gun.damage * 4.0 >= 100.0 and gun.damage * 3.0 < 100.0)
	STICKERS.clear()
	# A wall in front of the player, found the way a shot finds it.
	var eye := player.global_position + Vector3.UP * 1.5
	var space := player.get_world_3d().direct_space_state
	var wall := {}
	for turn in 16:
		var way := Vector3.FORWARD.rotated(Vector3.UP, TAU * turn / 16.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + way * 30.0, 1))
		if hit and absf((hit.normal as Vector3).y) < 0.3 and eye.distance_to(hit.position) > 3.0:
			wall = hit
			break
	_check("there is a wall to stick on", not wall.is_empty())
	if wall.is_empty():
		return
	var at: Vector3 = wall.position
	_fire(eye, at, gun)
	await _until(func() -> bool: return STICKERS.stuck().size() == 1, 3.0)
	var stuck := STICKERS.stuck()
	_check("a sticker fired at a wall sticks on it", stuck.size() == 1 and (stuck[0][0] as Vector3).distance_to(at) < 0.6)
	var decals := get_tree().current_scene.find_children("*", "Decal", false, false).size()
	_check("as a decal", decals >= 1)

	# The slop gun: a meme, half as big again.
	var slop := ARMORY.named("slop_gun")
	_check("the slop gun is in the armory, in the pack Slop, as strong as the Branding Gun", slop != null and slop.projectile == STICKER and ARMORY.weapons("slop") == [slop] and slop.damage == gun.damage)
	STICKERS.clear()
	_fire(eye, at, slop)
	await _until(func() -> bool: return STICKERS.stuck().size() == 1, 3.0)
	var slopped: Array = get_tree().current_scene.find_children("*", "Decal", false, false).filter(func(decal: Decal) -> bool: return not decal.is_queued_for_deletion())
	var picture: String = (slopped[-1] as Decal).texture_albedo.resource_path.get_file().get_basename() if not slopped.is_empty() else ""
	_check("it sticks one of the three memes, half as big again as the sticker of Unmuted", ["ballerina", "tung", "bombardiro"].has(picture)
		and absf((slopped[-1] as Decal).size.x - 0.55 * 1.5) < 0.001)

	# Covering: by the other side, and not by one's own.
	STICKERS.clear()
	var normal: Vector3 = wall.normal
	STICKERS.place(get_tree(), "unmuted", at, normal, -normal, 0.4, 0)
	STICKERS.place(get_tree(), "unmuted", at + Vector3.UP * 0.1, normal, -normal, 0.4, 0)
	_check("a sticker of one's own side next to another leaves both", STICKERS.stuck().size() == 2)
	STICKERS.place(get_tree(), "unmuted", at + Vector3.UP * 0.05, normal, -normal, 0.4, 1)
	stuck = STICKERS.stuck()
	_check("one of the other side on them takes their place", stuck.size() == 1 and stuck[0][1] == 1)
	var far := at + Vector3.UP * 1.0
	STICKERS.place(get_tree(), "unmuted", far, normal, -normal, 0.4, 0)
	_check("and leaves alone what is further off", STICKERS.stuck().size() == 2)

	# What draws.
	var lures := STICKERS.lures()
	_check("a sticker that has just landed draws fully", lures.size() == 2 and lures.all(func(lure: Array) -> bool: return lure[2] > 0.95))
	STICKERS.older(STICKERS.PULL * 0.5)
	lures = STICKERS.lures()
	_check("half as much at half its time", lures.size() == 2 and absf(lures[0][2] - 0.5) < 0.05)
	STICKERS.seen(far, 0.5)
	_check("nothing once the ICP has seen it", STICKERS.lures().size() == 1)
	STICKERS.older(STICKERS.PULL)
	_check("and nothing after its time", STICKERS.lures().is_empty())
	_check("but it stays on as a mark", STICKERS.stuck().size() == 2)

	# No more than MOST.
	for i in STICKERS.MOST + 12:
		STICKERS.place(get_tree(), "unmuted", at + Vector3.UP * (0.3 * (i % 10)) + normal.cross(Vector3.UP) * (0.5 * (i / 10)), normal, -normal, 0.4, 0)
	_check("there are never more than %d" % STICKERS.MOST, STICKERS.stuck().size() == STICKERS.MOST)
	await _wait(0.1)
	_check("and the decals that made way are gone", get_tree().current_scene.find_children("*", "Decal", false, false).size() <= STICKERS.MOST + 4)
	STICKERS.clear()

	# The ICP wears none.
	var icp := _box(eye + (at - eye).normalized() * 2.0)
	icp.add_to_group(&"icp")
	_fire(eye, icp.global_position, gun)
	await _wait(0.6)
	_check("a sticker that meets the ICP is gone", STICKERS.stuck().is_empty() and get_tree().get_nodes_in_group(&"sticker").is_empty())
	icp.queue_free()
	await _wait(0.1)

	# Somebody: hurt, and wearing it.
	var dummy := _box(eye + (at - eye).normalized() * 2.0, true)
	_fire(eye, dummy.global_position, gun)
	await _wait(0.6)
	_check("a sticker that meets somebody hurts them by %.0f" % gun.damage, is_equal_approx(dummy.get_meta(&"hurt", 0.0), gun.damage))
	_check("and stays on them", dummy.find_children("*", "MeshInstance3D", false, false).size() == 1)
	_check("without sticking on the level", STICKERS.stuck().is_empty())
	dummy.queue_free()


func _icp() -> void:
	_check("the ICP match is there in this build, with its own sides and pack", Match.kinds.has("icp") and Match.kinds.icp.limit == 3 and Match.kinds.icp.minutes == 10)
	_check("it opens", Match.open({"mode": "icp", "level": "factory", "size": 3, "only_bots": true}) and Match.setup.pack == "unmuted")
	await _until(func() -> bool: return Match.state == Match.State.PLAYING, 30.0)
	_check("and is played", Match.state == Match.State.PLAYING and Match.side_name(0) == "Unmuted" and Match.side_name(1) == "Slop Soldiers")
	if Match.state != Match.State.PLAYING:
		return
	var mode: RefCounted = Match.mode
	var icp: CharacterBody3D = mode.icp
	var arena: RefCounted = Match.arena
	_check("the ICP is in the level, with ICP over his head", is_instance_valid(icp) and icp.is_in_group(&"icp") and icp.visible and (icp.get_node(^"Mark") as Label3D).text == "ICP")
	var walks := [arena.walk(mode.bases[0], icp.global_position), arena.walk(mode.bases[1], icp.global_position)]
	print("  the bases %.0f m apart to walk, the ICP %.0f and %.0f m from them" % [arena.length(), walks[0], walks[1]])
	_check("in the middle, as far to walk from either base", absf(walks[0] - walks[1]) < maxf(arena.length() * 0.15, 6.0))
	_check("and the two bases stand at the ends", get_tree().current_scene.has_node(^"Base0") and get_tree().current_scene.has_node(^"Base1"))
	var buildings: Array = [get_tree().current_scene.get_node_or_null(^"Base0"), get_tree().current_scene.get_node_or_null(^"Base1")]
	_check("the canal house of Unmuted and Doomscroll Hell, each in the way", buildings.all(func(base: Node) -> bool: return base != null and base.find_children("*", "CollisionShape3D", false, false).size() >= 1)
		and str(buildings[0].get_child(-1).scene_file_path).ends_with("unmuted_hq.scn") and str(buildings[1].get_child(-1).scene_file_path).ends_with("doomscroll_hell.scn"))
	_check("with their fronts to the middle, behind their doors", buildings.all(func(base: Node3D) -> bool:
		var to_middle: Vector3 = mode.middle - base.global_position
		var door: Vector3 = mode.bases[buildings.find(base)]
		return base.global_basis.z.dot(to_middle.normalized()) > 0.5 and Vector2(door.x - base.global_position.x, door.z - base.global_position.z).length() < 6.0))
	var guns := Match.entrants.values().map(func(who: RefCounted) -> String: return "%d %s" % [who.team, ARMORY.at(who.weapon).resource_path.get_file().get_basename()])
	_check("Unmuted carry the Branding Gun, the Slop Soldiers the slop gun", guns.all(func(line: String) -> bool: return line == "0 branding_gun" or line == "1 slop_gun") and guns.has("1 slop_gun") and guns.has("0 branding_gun"))
	var model: Node = icp.get_node_or_null(^"Model")
	_check("he is the man in the suit, a size up", model != null and model.find_children("*", "Skeleton3D", true, false).size() == 1 and absf(model.get_child(0).scale.y - icp.SIZE) < 0.01
		and ResourceLoader.exists(icp.LOOK) and icp.LOOK.contains("icp_01"))
	var unmuted := 0
	var soldiers := 0
	for who: RefCounted in Match.entrants.values():
		var look: Variant = mode.look(who)
		if who.team == 0 and look is Dictionary and look.has("character") and (look.character as PackedScene).resource_path.contains("/unmuted_"):
			unmuted += 1
		elif who.team == 1 and look is Dictionary and look.is_empty():
			soldiers += 1
	_check("Unmuted are the people in black, the Slop Soldiers soldiers, whatever the enemies of the route are", unmuted == 3 and soldiers == 3)
	var dressed: Array = Match.entrants.values().filter(func(who: RefCounted) -> bool: return who.team == 0)
	_check("and so they look in the level", dressed.all(func(who: RefCounted) -> bool:
		var rig: Node = who.body.get_node_or_null(^"Model")
		return rig != null and rig.get_child_count() > 0 and str(rig.get_child(0).scene_file_path).contains("/unmuted_")))

	# Without the bots, which stand still.
	for who: RefCounted in Match.entrants.values():
		if is_instance_valid(who.body):
			who.body.propagate_call(&"set_physics_process", [false])
	STICKERS.clear()
	await _wait(1.2)
	_check("nothing draws him while there are no stickers: he stands", mode.heading == -1 and icp.goal == Vector3.INF)
	var start := icp.global_position
	var near := _spot_from(start, 8.0, 14.0)
	STICKERS.place(get_tree(), "unmuted", near, Vector3.UP, Vector3.FORWARD, 0.55, 1)
	await _wait(1.2)
	_check("a sticker of the Slop Soldiers near him draws him to it", mode.heading == 1 and icp.goal.distance_to(near) < 0.1)
	Engine.time_scale = 4.0
	await _until(func() -> bool: return STICKERS.lures().is_empty(), 20.0)
	Engine.time_scale = 1.0
	_check("he walks there, and once he is there it draws no more", STICKERS.lures().is_empty() and icp.global_position.distance_to(near) < 4.0 and STICKERS.stuck().size() == 1)
	var money: Node = get_tree().current_scene.get_node_or_null(^"Money")
	var notes := money.get_child_count() if money else 0
	_check("and drops a banknote every few steps", icp.looks()[0].material_override.albedo_texture != null and notes >= floori(start.distance_to(icp.global_position) / icp.BILL_EVERY) - 1 and notes >= 1)
	await _wait(1.2)
	_check("then he stands again", mode.heading == -1)

	var at := icp.global_position
	var two := [_spot_from(at, 10.0, 20.0), _spot_from(at, 10.0, 20.0)]
	STICKERS.place(get_tree(), "unmuted", two[0], Vector3.UP, Vector3.FORWARD, 0.55, 0)
	for i in 3:
		STICKERS.place(get_tree(), "unmuted", two[1] + Vector3(i * 0.5, 0.0, 0.0), Vector3.UP, Vector3.FORWARD, 0.55, 1)
	await _wait(1.2)
	_check("of two sides he goes to that of more stickers", mode.heading == 1)
	for i in 5:
		STICKERS.place(get_tree(), "unmuted", two[0] + Vector3(0.0, 0.0, i * 0.5), Vector3.UP, Vector3.FORWARD, 0.55, 0)
	await _wait(1.2)
	_check("and changes his mind when the other side sticks more", mode.heading == 0)
	var far := _spot_from(at, 60.0, 400.0)
	STICKERS.clear()
	if far != Vector3.INF:
		STICKERS.place(get_tree(), "unmuted", far, Vector3.UP, Vector3.FORWARD, 0.55, 0)
	await _wait(1.2)
	_check("a sticker further off than he sees draws nothing", far == Vector3.INF or mode.heading == -1)
	STICKERS.clear()

	# Won over.
	STICKERS.place(get_tree(), "unmuted", at + Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, 0.55, 1)
	icp.global_position = mode.bases[0] + Vector3(1.0, 0.3, 0.0)
	await _wait(0.3)
	_check("at the base of Unmuted he is won over: a point for Unmuted", Match.tally[0] == 1 and Match.tally[1] == 0)
	_check("he is gone a moment, and so is every sticker", not icp.visible and STICKERS.stuck().is_empty())
	_check("in a shower of banknotes", money != null and money.get_child_count() >= icp.RAIN)
	await _wait(float(Match.mode.numbers.back) + 0.5)
	_check("then he is back in the middle", icp.visible and icp.global_position.distance_to(mode.middle) < 1.5)

	# The bots play: both sides stick.
	for who: RefCounted in Match.entrants.values():
		if is_instance_valid(who.body):
			who.body.propagate_call(&"set_physics_process", [true])
	Engine.time_scale = 4.0
	var sides := {}
	var played := 0.0
	while played < 40.0:
		await _wait(1.0)
		played += 4.0
		for line: Array in STICKERS.stuck():
			sides[line[1]] = true
	_check("the bots of both sides stick", sides.has(0) and sides.has(1))
	# And a side that plays alone wins him over: the Slop Soldiers stand still.
	for who: RefCounted in Match.entrants.values():
		if who.team == 1 and is_instance_valid(who.body):
			who.body.propagate_call(&"set_physics_process", [false])
	var began := Match.tally.duplicate()
	played = 0.0
	while played < 240.0 and Match.state == Match.State.PLAYING and Match.tally == began:
		await _wait(1.0)
		played += 4.0
		if int(played) % 16 == 0:
			print("    %3.0f s: the ICP %.0f / %.0f m from the bases, heading %d, %d stuck" % [played, icp.global_position.distance_to(mode.bases[0]), icp.global_position.distance_to(mode.bases[1]), mode.heading, Match.stuck])
	Engine.time_scale = 1.0
	print("  Unmuted played alone %.0f s: the score %s" % [played, str(Match.tally)])
	_check("Unmuted alone draws him to its base", Match.tally[0] == began[0] + 1)
	Match.close()

	# Whoever plays for the Slop Soldiers has the slop gun in their hands.
	Match.picked[Net.id()] = 1
	Match.open({"mode": "icp", "level": "factory", "size": 2})
	await _until(func() -> bool: return Match.state == Match.State.PLAYING, 30.0)
	var player: CharacterBody3D = get_tree().current_scene.player
	_check("whoever plays for the Slop Soldiers carries the slop gun", Match.me() != null and Match.me().team == 1
		and player.weapons.loadout == [ARMORY.named("slop_gun")])
	Match.picked.erase(Net.id())
	Match.close()


## A whole match of bots in the dunes, at most `minutes` long and four times
## as fast as the clock, with how it stands every half minute: to weigh the
## numbers by. Run with: tools/test_unmuted.sh --soak=10
func _soak(minutes: float) -> void:
	Match.open({"mode": "icp", "level": "dunes", "size": int(_told("--size=", "6")), "only_bots": true})
	await _until(func() -> bool: return Match.state == Match.State.PLAYING, 120.0)
	var mode: RefCounted = Match.mode
	Engine.time_scale = 4.0
	var played := 0.0
	while played < minutes * 60.0 and Match.state == Match.State.PLAYING:
		await _wait(1.0)
		played += 4.0
		if int(played) % 32 == 0:
			var counts := [0, 0]
			for lure: Array in STICKERS.lures():
				counts[lure[1]] += 1
			var icp: Node3D = mode.icp
			print("  %3.0f s: %s, the ICP %.0f / %.0f m from the bases, heading %d, drawn by %d / %d, %d stuck" % [played, str(Match.tally), icp.global_position.distance_to(mode.bases[0]), icp.global_position.distance_to(mode.bases[1]), mode.heading, counts[0], counts[1], Match.stuck])
	Engine.time_scale = 1.0
	print("SOAK %.0f s: the score %s, %s" % [played, str(Match.tally), "over" if Match.state == Match.State.OVER else "still on"])


func _told(prefix: String, otherwise: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return otherwise


## A spot to stand on between `least` and `most` metres from `at`, INF if
## there is none.
func _spot_from(at: Vector3, least: float, most: float) -> Vector3:
	var spots: Array = Array(Match.arena.spots)
	spots.shuffle()
	for spot: Vector3 in spots:
		var gap := spot.distance_to(at)
		if gap > least and gap < most and Match.arena.walk(at, spot) < most * 1.6:
			return spot
	return Vector3.INF


## A sticker of `gun` fired from `from` at `at`, by nobody.
func _fire(from: Vector3, at: Vector3, gun: WeaponData) -> void:
	var sticker: Node3D = STICKER.instantiate()
	sticker.velocity = (at - from).normalized() * gun.projectile_speed
	sticker.direct = gun.damage
	sticker.weapon = ARMORY.index(gun)
	get_tree().current_scene.add_child(sticker)
	sticker.global_position = from


## A box to shoot at, standing in for the ICP or, `alive`, for somebody: that
## one counts what hurts it in its meta "hurt".
func _box(at: Vector3, alive := false) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.collision_layer = 0b100
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(0.8, 0.8, 0.8)
	body.add_child(shape)
	if alive:
		var script := GDScript.new()
		script.source_code = "extends CharacterBody3D\nfunc take_damage(amount: float, _at := Vector3.ZERO, _way := Vector3.ZERO) -> bool:\n\tset_meta(&\"hurt\", get_meta(&\"hurt\", 0.0) + amount)\n\treturn false\n"
		script.reload()
		body.set_script(script)
	get_tree().current_scene.add_child(body)
	body.global_position = at
	return body


func _check(what: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("  %s %s" % ["ok  " if ok else "FAIL", what])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _until(done: Callable, seconds: float) -> void:
	var waited := 0.0
	while not done.call() and waited < seconds:
		await _wait(0.05)
		waited += 0.05
