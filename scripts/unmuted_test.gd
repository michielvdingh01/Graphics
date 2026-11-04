extends Node
## Headless test of the Unmuted match. Run with: tools/test_unmuted.sh
##
## The stickers: one fired at a wall sticks there as a decal; one of the other
## side that lands on it takes its place, one of the same side next to it does
## not; there are never more than Stickers.MOST; a sticker draws less as it
## ages and nothing once it is PULL seconds old or the ICP has seen it; one
## that meets the ICP is gone; one that meets somebody hurts them by the
## damage of the Branding Gun and stays on them.

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
	tree.create_timer(150.0, true, true).timeout.connect(
		func() -> void:
			print("UNMUTED TEST FAILED (timed out)")
			tree.quit(1)
	)
	await _wait(0.3)
	tree.change_scene_to_file(LEVEL)
	await _wait(1.0)
	var player: CharacterBody3D = tree.current_scene.player
	player.force_control = true
	player.health = 1e7
	await _stickers(player)
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
