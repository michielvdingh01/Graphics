extends "res://tools/levels/supermarket/plan.gd"
## What is fresh, round the walls of the shop. Produce just inside the south
## doors, then the bakery and the deli along the south wall; the butcher and
## the dairy along the back wall; frozen food along the north wall, with beer
## in the cold next to it.

const SMALL := DETAIL | NO_COLLIDE
## Where the bins of produce stand on x and on z, and how large a bin is.
const BIN_X: Array[float] = [5.5, 10.0, 14.5, 19.0, 23.5, 28.0]
const BIN_Z: Array[float] = [33.0, 37.5]
const BIN := Vector2(3.0, 1.5)
const BIN_HIGH := 0.72
## What lies in the bins: a pair to a bin, one row after the other.
const BINS: Array = [
	["apple_red", "apple_green"], ["orange", "lemon"], ["tomato", "pepper_red"], ["potato", "onion"], ["pepper_yellow", "pepper_green"], ["peach", "avocado"],
	["cantaloupe", "lime"], ["corn", "carrot"], ["lettuce", "cabbage"], ["apple_green", "pepper_red"], ["orange", "banana"], ["broccoli", "cucumber"],
]
const WET_WALL: Array = [
	["strawberries", "mushrooms"],
	["lettuce", "cabbage", "broccoli"],
	["cucumber", "carrot", "lettuce"],
	["broccoli", "cabbage", "corn"],
]
const BREAD: Array = [
	["loaf_white", "loaf_wheat"], ["buns", "bagels"], ["loaf_wheat", "loaf_white"], ["muffins", "donuts"], ["bagels", "buns"],
]
const CHEESE: Array = [
	["cheddar_block", "wedge_swiss"], ["wedge_blue", "wedge_parm"], ["wheel_red", "brie"], ["wheel_gouda", "wheel_black"],
]
const MEAT_CASE: Array = [
	["ribeye", "ground"], ["chicken", "porkchop"], ["sausage", "salmon"], ["bacon", "hotdogs", "shrimp"],
]
const DAIRY: Array = [
	["milk_whole", "milk_two"], ["milk_skim", "milk_choc", "oj_carton"], ["eggs", "butter"],
	["yogurt_straw", "yogurt_peach", "yogurt_blue", "yogurt_plain"], ["sourcream", "shredded", "cheddar_block"],
]
const FROZEN: Array = [
	["pizza_a", "pizza_b"], ["icecream_vanilla", "icecream_choc", "icecream_straw", "icecream_mint"], ["fries", "frozen_peas"],
	["dinner", "waffles", "popsicle"], ["pizza_b", "pizza_a"],
]
const COLD_BEER: Array = [
	["hawk_six", "river_six"], ["peak_six", "stone_six"], ["hawk_bottle", "river_bottle"], ["peak_bottle", "stone_bottle"], ["volt_can", "fizz_can"],
]


func _describe() -> void:
	_produce()
	_bakery()
	_deli()
	_butcher()
	_dairy()
	_frozen()


func _produce() -> void:
	var wall := SOUTH_WALL - 0.2
	cold_case(Vector3(4.0, 0, wall), Vector3(32.0, 0, wall), Vector3.FORWARD, WET_WALL, 4)
	shop_board("produce", Vector3(18.0, 3.4, wall - 0.02), Vector3.FORWARD, 9.0, NAN, false)
	var which := 0
	for z in BIN_Z:
		for x in BIN_X:
			_bin(Vector2(x, z), BINS[which % BINS.size()])
			which += 1
	# Pumpkins and melons by the door, in the bins they came in.
	_crate(Vector2(3.5, 29.0), "pumpkin", 3)
	_crate(Vector2(7.0, 29.5), "melon", 2)
	_crate(Vector2(30.5, 29.6), "pumpkin", 2)


## A low table with a heap on each half of it.
func _bin(at: Vector2, pair: Array) -> void:
	var center := Vector3(at.x, BIN_HIGH * 0.5, at.y)
	box("shop_wood", center - Vector3.UP * 0.02, Vector3(BIN.x, BIN_HIGH - 0.04, BIN.y), Vector3.ZERO, SMALL)
	box("shop_dark", Vector3(at.x, 0.05, at.y), Vector3(BIN.x + 0.04, 0.1, BIN.y + 0.04), Vector3.ZERO, SMALL)
	_collide_box(Transform3D(Basis(), center), Vector3(BIN.x, BIN_HIGH, BIN.y), "wood")
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var patch := Rect2(at.x + (0.0 if i == 1 else -BIN.x * 0.5) + 0.03, at.y - BIN.y * 0.5 + 0.03, BIN.x * 0.5 - 0.06, BIN.y - 0.06)
		heap(patch, BIN_HIGH, pair[i], 0.26)
		box("shop_wood", Vector3(at.x + side * BIN.x * 0.25, BIN_HIGH + 0.05, at.y - BIN.y * 0.5), Vector3(BIN.x * 0.5, 0.1, 0.03), Vector3.ZERO, SMALL)
		box("shop_wood", Vector3(at.x + side * BIN.x * 0.25, BIN_HIGH + 0.05, at.y + BIN.y * 0.5), Vector3(BIN.x * 0.5, 0.1, 0.03), Vector3.ZERO, SMALL)
	box("shop_wood", Vector3(at.x, BIN_HIGH + 0.05, at.y), Vector3(0.03, 0.1, BIN.y), Vector3.ZERO, SMALL)
	goods_face(Vector3(at.x, BIN_HIGH + 0.2, at.y), Vector3(BIN.x, 0.5, BIN.y))


## A big cardboard crate of something that does not fit a bin.
func _crate(at: Vector2, id: String, layers: int) -> void:
	var size := 1.1
	box("shop_cream", Vector3(at.x, 0.3, at.y), Vector3(size, 0.6, size), Vector3.ZERO, SMALL)
	_collide_box(Transform3D(Basis(), Vector3(at.x, 0.3, at.y)), Vector3(size, 0.6, size), "wood")
	heap(Rect2(at.x - size * 0.5, at.y - size * 0.5, size, size), 0.6, id, layers * 0.22)
	goods_face(Vector3(at.x, 0.9, at.y), Vector3(size, 0.6, size))


func _bakery() -> void:
	var wall := SOUTH_WALL - 0.2
	wall_shelves(Vector3(35.0, 0, wall), Vector3(50.0, 0, wall), Vector3.FORWARD, BREAD, 3)
	shop_board("bakery", Vector3(42.5, 3.4, wall - 0.02), Vector3.FORWARD, 8.0, NAN, false)
	# Tables with what came out of the oven today.
	for spot: Vector2 in [Vector2(38.0, 39.0), Vector2(43.0, 39.0), Vector2(48.0, 39.0)]:
		_table_of(spot, ["cake", "pie", "donuts"][int(spot.x) % 3])
	_basket(Vector2(36.0, 35.0))
	_basket(Vector2(46.0, 34.8))


func _table_of(at: Vector2, id: String) -> void:
	box("shop_wood", Vector3(at.x, 0.76, at.y), Vector3(2.0, 0.05, 1.2), Vector3.ZERO, SMALL)
	box("shop_steel", Vector3(at.x, 0.37, at.y), Vector3(1.6, 0.74, 0.9), Vector3.ZERO, SMALL)
	_collide_box(Transform3D(Basis(), Vector3(at.x, 0.4, at.y)), Vector3(2.0, 0.8, 1.2), "wood")
	var size: Vector3 = CATALOG.product(id).size
	var cols := int(1.9 / (size.x + 0.02))
	var rows := int(1.1 / (size.z + 0.02))
	for i in cols:
		for j in rows:
			var spot := Vector3(at.x - 0.95 + (i + 0.5) * 1.9 / cols, 0.785 + size.y * 0.5, at.y - 0.55 + (j + 0.5) * 1.1 / rows)
			var under := stock(id, spot, 0.0, 0, 1.0)
			if size.y < 0.1:
				stock(id, spot + Vector3.UP * size.y, 0.3, 0, 1.0, under)
	goods_face(Vector3(at.x, 0.98, at.y), Vector3(2.0, 0.36, 1.2))


## French loaves standing up in a basket.
func _basket(at: Vector2) -> void:
	cylinder("shop_wood", Vector3(at.x, 0, at.y), 0.42, 0.72, 0, Vector3.ZERO, 0.5, 10)
	for i in 9:
		var turn := i * 2.4
		var reach := 0.1 + 0.05 * i
		stock("baguette", Vector3(at.x + cos(turn) * reach, 0.86, at.y + sin(turn) * reach), turn, 0, 1.0)
	goods_face(Vector3(at.x, 1.0, at.y), Vector3(0.9, 0.7, 0.9))


func _deli() -> void:
	var wall := SOUTH_WALL - 0.2
	cold_case(Vector3(52.0, 0, wall), Vector3(65.0, 0, wall), Vector3.FORWARD, CHEESE, 4)
	shop_board("deli", Vector3(58.5, 3.4, wall - 0.02), Vector3.FORWARD, 8.0, NAN, false)
	# The counter, with sausages hanging on a rail over it.
	var counter := Vector3(58.5, 0, 38.0)
	box("shop_dark", counter + Vector3.UP * 0.5, Vector3(11.0, 1.0, 0.8), Vector3.ZERO, DETAIL)
	box("shop_rail", counter + Vector3.UP * 1.02, Vector3(11.2, 0.05, 0.9), Vector3.ZERO, SMALL)
	box("glass", counter + Vector3(0, 1.28, -0.2), Vector3(10.6, 0.5, 0.012), Vector3.ZERO, GLASS | NO_COLLIDE)
	box("shop_cool", counter + Vector3(0, 1.5, 0.2), Vector3(10.6, 0.03, 0.08), Vector3.ZERO, SMALL)
	for x_at: float in [54.0, 56.0, 58.0, 60.0, 62.0]:
		cylinder("shop_steel", Vector3(x_at, 1.04, 38.0), 0.012, 1.2, SMALL, Vector3.ZERO, -1.0, 6)
	box("shop_steel", Vector3(58.5, 2.24, 38.0), Vector3(10.0, 0.03, 0.03), Vector3.ZERO, SMALL)
	shelf_line(Vector3(53.5, 1.045, 38.1), Vector3(63.5, 1.045, 38.1), Vector3.FORWARD, ["wheel_gouda", "wheel_red", "wedge_swiss", "ham", "wedge_blue"], 2, 0.3, 0.2)
	for i in 34:
		var x_at := 53.6 + i * 0.29
		var length := 0.24 + 0.1 * float(i % 3)
		stock("salami", Vector3(x_at, 2.2 - length * 0.5, 38.0 + 0.03 * ((i % 2) * 2 - 1)), i * 1.1, 0, 0.9)
	goods_face(Vector3(58.5, 1.9, 38.0), Vector3(10.4, 0.8, 0.3))
	goods_face(Vector3(58.5, 1.2, 38.0), Vector3(10.4, 0.34, 0.6))


func _butcher() -> void:
	var wall := BACK - 0.14
	cold_case(Vector3(wall, 0, 8.0), Vector3(wall, 0, 32.0), Vector3.LEFT, MEAT_CASE, 3)
	shop_board("meat", Vector3(wall - 0.02, 3.6, 20.0), Vector3.LEFT, 9.0, NAN, false)
	# On a table in front of it, the bird for the holiday.
	box("shop_steel", Vector3(61.0, 0.42, 20.0), Vector3(1.4, 0.84, 2.6), Vector3.ZERO, SMALL)
	_collide_box(Transform3D(Basis(), Vector3(61.0, 0.45, 20.0)), Vector3(1.4, 0.9, 2.6), "metal")
	for i in 5:
		for j in 2:
			stock("turkey", Vector3(60.7 + j * 0.6, 0.95, 19.0 + i * 0.5), PI * 0.5, 0, 1.0)
	goods_face(Vector3(61.0, 1.0, 20.0), Vector3(1.4, 0.4, 2.6))


func _dairy() -> void:
	var wall := BACK - 0.14
	cold_doors(Vector3(wall, 0, -32.0), Vector3(wall, 0, 0.5), Vector3.LEFT, DAIRY, 4)
	shop_board("dairy", Vector3(wall - 0.02, 3.6, -16.0), Vector3.LEFT, 8.0, NAN, false)
	pallet_of(Vector2(62.0, -28.0), 90.0, "spring_case", 2, 2, 5)


func _frozen() -> void:
	var wall := NORTH_WALL + 0.2
	cold_doors(Vector3(22.0, 0, wall), Vector3(62.0, 0, wall), Vector3.BACK, FROZEN, 3)
	cold_doors(Vector3(9.0, 0, wall), Vector3(21.0, 0, wall), Vector3.BACK, COLD_BEER, 3)
	shop_board("frozen", Vector3(42.0, 3.5, wall + 0.02), Vector3.BACK, 9.0, NAN, false)
	shop_board("aisle_1", Vector3(15.0, 3.5, wall + 0.02), Vector3.BACK, 4.0, NAN, false)
	for x: float in [28.0, 41.0, 54.0]:
		_chest(Vector2(x, -36.5), ["pizza_a", "dinner", "icecream_vanilla", "fries", "pizza_b"], int(x))


## A chest freezer you look down into, ten metres of it.
func _chest(at: Vector2, mix: Array, seed_at: int) -> void:
	var size := Vector3(10.0, 0.88, 1.5)
	var center := Vector3(at.x, size.y * 0.5, at.y)
	_collide_box(Transform3D(Basis(), center), size, "metal")
	box("shop_white", center, size, Vector3.ZERO, SMALL)
	box("shop_dark", Vector3(at.x, 0.05, at.y), size * Vector3(1.0, 0.0, 1.0) + Vector3(0.02, 0.1, 0.02), Vector3.ZERO, SMALL)
	box("shop_cool", center + Vector3.UP * (size.y * 0.5 + 0.004), Vector3(size.x - 0.1, 0.01, size.z - 0.1), Vector3.ZERO, SMALL)
	var z := at.y - 0.55
	var row := 0
	while z < at.y + 0.6:
		shelf_line(Vector3(at.x - 4.9, size.y + 0.01, z + 0.26), Vector3(at.x + 4.9, size.y + 0.01, z + 0.26), Vector3.BACK, [mix[(row + seed_at) % mix.size()], mix[(row + seed_at + 2) % mix.size()]], 5, 0.4, 0.14)
		z += 0.5
		row += 1
	goods_face(Vector3(at.x, size.y + 0.12, at.y), Vector3(size.x, 0.26, size.z))
