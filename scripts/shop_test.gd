extends Node
## Headless test of the supermarket. Run with: tools/test_supermarket.sh
##
## It goes into the level and tries what the level promises. A shot takes what
## it hits and shakes down what stood next to it; what stood on it comes down;
## a blast takes more; pieces come to rest. The mains can be shot, and then the
## lamps, what glows and most of the ambient light go, and the doors stay open.
## A flashlight goes on the weapon of whoever walks up to it and stays when the
## weapon changes. A cart can be taken, pushed and put back in a rack. The SUVs
## can be got into and they drive. And the light is back after a reload.

const CATALOG := preload("res://scripts/goods_catalog.gd")
const LEVEL := "res://scenes/supermarket.tscn"

## True for a run of this test.
var active := false

var _failures := 0
var _checks := 0


func _ready() -> void:
	active = "--shoptest" in OS.get_cmdline_user_args()
	if active:
		SelfTest.active = true
		_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	tree.create_timer(150.0, true, true).timeout.connect(
		func() -> void:
			print("SHOP TEST FAILED (timed out)")
			tree.quit(1)
	)
	await _wait(0.3)
	var started := Time.get_ticks_msec()
	tree.change_scene_to_file(LEVEL)
	await _wait(1.0)
	print("The level was there after %d ms" % (Time.get_ticks_msec() - started))
	var game := tree.current_scene
	var player: CharacterBody3D = game.player
	player.force_control = true
	# Whoever guards the level does not get a say in this.
	player.health = 1e7
	await _goods(game)
	await _flashlight(game, player)
	await _mains(game)
	await _cart(game, player)
	await _suv(game, player)
	# The light comes back with the level: materials outlive a scene.
	tree.reload_current_scene()
	await _wait(1.0)
	var lamp: StandardMaterial3D = load("res://materials/shop_lamp.tres")
	_check("the lamps burn again after a reload", lamp.emission_energy_multiplier > 1.0)
	print("%d checks, %d failed" % [_checks, _failures])
	print("SHOP TEST PASSED" if _failures == 0 else "SHOP TEST FAILED")
	tree.quit(0 if _failures == 0 else 1)


func _goods(_game: Node) -> void:
	var goods: Node = get_tree().get_first_node_in_group(&"goods")
	_check("the shop holds goods", goods != null)
	if goods == null:
		return
	var whole: int = goods.count()
	print("%d things on sale" % whole)
	_check("tens of thousands of things are on sale", whole > 30000)
	for id: String in ["fizz_2l", "red_wine", "milk_whole", "apple_red", "ribeye", "wheel_gouda", "frosty", "loaf_white", "pizza_a", "lettuce", "soup_tomato", "tp"]:
		_check("%s is on sale" % id, goods.first_of(id) >= 0)
	# A bottle of soda.
	var bottle: int = goods.first_of("fizz_2l")
	var at: Vector3 = goods.middle_of(bottle) - Vector3.BACK * goods.SHOT_INTO
	goods.take_damage(30.0, at, Vector3.BACK)
	_check("a shot takes what it hits", goods.gone(bottle))
	var after_one: int = goods.left()
	_check("and only what is around it", whole - after_one < 40 and whole - after_one >= 1)
	var wine: int = goods.first_of("red_wine")
	goods.take_damage(50.0, goods.middle_of(wine) - Vector3.BACK * goods.SHOT_INTO, Vector3.BACK)
	_check("a bottle of wine goes as well", goods.gone(wine))
	await _wait(2.5)
	_check("what flew has come to rest", goods._flying.is_empty())
	# Something stacked: what stood on it comes down.
	var low := _stacked(goods)
	_check("a pallet has something that stands on something", low >= 0)
	if low >= 0:
		var above: PackedInt32Array = goods._on[low]
		goods.take_damage(90.0, goods.middle_of(low) - Vector3.BACK * goods.SHOT_INTO, Vector3.BACK)
		_check("what stood on what went comes down", above.size() > 0 and goods.gone(above[0]))
	# As a real shot gets there: from the middle of an aisle, on the layers a
	# weapon looks on.
	var eye := Vector3(30.0, 1.1, -0.04)
	var ray := PhysicsRayQueryParameters3D.create(eye, eye + Vector3(0, 0, -5), 0b100101)
	var hit: Dictionary = goods.get_world_3d().direct_space_state.intersect_ray(ray)
	_check("a shot along an aisle lands on what is on the shelf", not hit.is_empty() and hit.collider == goods)
	if hit:
		var shelf: int = goods.left()
		goods.take_damage(30.0, hit.position, Vector3.FORWARD)
		_check("and takes something off it", goods.left() < shelf)
	var before: int = goods.left()
	var in_aisle: Vector3 = goods.middle_of(goods.first_of("frosty"))
	goods.take_blast(120.0, in_aisle, Vector3.UP)
	_check("a blast takes a lot at once", before - goods.left() > 30)
	await _wait(3.0)
	_check("and that comes to rest too", goods._flying.is_empty())


## Something that stands on the floor of a pallet with something on it.
func _stacked(goods: Node) -> int:
	for low: int in goods._on:
		if not goods.gone(low):
			return low
	return -1


func _flashlight(_game: Node, player: CharacterBody3D) -> void:
	var stands := get_tree().get_nodes_in_group(&"flashlight")
	_check("there are flashlights to be found", stands.size() >= 3)
	var weapons: Node = player.weapons
	_check("nobody starts with one", not weapons.has_torch)
	player.global_position = (stands[0] as Node3D).global_position - Vector3(0, 0.9, 0)
	await _wait(0.6)
	_check("walking up to one mounts it", weapons.has_torch and weapons.torch_on)
	var beam: Light3D = weapons._torch_beam
	_check("it shines", beam != null and beam.visible)
	await _wait(0.1)
	_check("it sits on the weapon in hand", weapons._torch.get_parent() == weapons._models[weapons._index].root)


func _mains(_game: Node) -> void:
	var mains := get_tree().get_first_node_in_group(&"mains")
	var lamps := get_tree().get_nodes_in_group(&"mains").filter(func(node: Node) -> bool: return node is Light3D)
	mains = get_tree().get_nodes_in_group(&"mains").filter(func(node: Node) -> bool: return node.has_method("powered"))[0]
	_check("there are lamps on the mains", lamps.size() > 10 and lamps.all(func(lamp: Light3D) -> bool: return lamp.visible))
	var probe: ReflectionProbe = get_tree().get_first_node_in_group(&"shop_probe")
	var ambient := probe.ambient_color_energy
	mains.take_damage(100.0, mains.global_position, Vector3.BACK)
	_check("the mains take more than one shot", mains.powered())
	mains.take_damage(1000.0, mains.global_position, Vector3.BACK)
	_check("enough of them and the power is gone", not mains.powered())
	await _wait(4.0)
	_check("the lamps have gone out", lamps.all(func(lamp: Light3D) -> bool: return not lamp.visible))
	var material: StandardMaterial3D = load("res://materials/shop_lamp.tres")
	_check("what glows has gone out", material.emission_energy_multiplier < 0.01)
	_check("most of the ambient light has gone", probe.ambient_color_energy < ambient * 0.6)
	var doors := get_tree().get_nodes_in_group(&"shop_door")
	_check("the doors stand open", doors.size() == 4 and doors.all(func(door: Node) -> bool: return door._open > 0.9))


func _cart(_game: Node, player: CharacterBody3D) -> void:
	var carts := get_tree().get_nodes_in_group(&"cart")
	_check("carts were left in the lot", carts.size() >= 10)
	var racks := get_tree().get_nodes_in_group(&"cart_rack")
	_check("and there are racks for them", racks.size() >= 3)
	var cart: RigidBody3D = carts[0]
	player.global_position = cart.global_position + Vector3(1.0, 0.05, 0)
	await _wait(0.3)
	_check("a cart is in reach", player.cart_in_reach() == cart)
	cart.use_by(player)
	var from := cart.global_position
	for i in 40:
		player.global_position += Vector3(-0.15, 0, 0)
		await get_tree().physics_frame
	await _wait(0.2)
	print("The cart stands %.1f m on, going %.1f m/s, frozen %s, asleep %s, pushed by %s" % [cart.global_position.distance_to(from), cart.linear_velocity.length(), cart.freeze, cart.sleeping, cart.pusher])
	_check("it goes along with who pushes it", cart.global_position.distance_to(from) > 2.0)
	cart.use_by(player)
	_check("and it can be let go", cart.pusher == null)
	var rack: Area3D = racks[0]
	var home_before: int = rack.home
	cart.global_position = rack.global_position + Vector3(0, -0.45, -rack.long * 0.5 + 0.2)
	cart.linear_velocity = Vector3(0, 0, 1.5)
	await _wait(1.2)
	_check("put in a rack it stays there", cart.home)
	_check("and it is counted", rack.home == home_before + 1)
	_check("it is out of the way of what comes next", cart.collision_layer == 0)


func _suv(_game: Node, player: CharacterBody3D) -> void:
	var cars := get_tree().get_nodes_in_group(&"vehicle").filter(func(car: Node) -> bool: return String(car.kind).begins_with("suv"))
	_check("there are SUVs in the lot", cars.size() >= 4)
	if cars.is_empty():
		return
	var car: RigidBody3D = cars[0]
	player.global_position = car.global_position + car.global_basis.x * -1.8 + Vector3.UP * 0.1
	await _wait(0.4)
	var near: Dictionary = player.vehicle_in_reach()
	_check("one can be got into", not near.is_empty() and near.vehicle == car)
	if near.is_empty():
		return
	car.request_seat(player, near.seat)
	await _wait(0.4)
	_check("whoever gets in drives it", player.riding == car and player.seat == 0)
	Input.action_press(&"move_forward")
	var from := car.global_position
	await _wait(4.5)
	Input.action_release(&"move_forward")
	print("An SUV goes %.1f m in 3 s, up to %.1f m/s" % [car.global_position.distance_to(from), car.linear_velocity.length()])
	_check("and it goes", car.global_position.distance_to(from) > 3.0)
	car.bail(player)
	await _wait(0.5)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func _check(what: String, passed: bool) -> void:
	_checks += 1
	if not passed:
		_failures += 1
	print("%s  %s" % ["ok    " if passed else "FAILED", what])
