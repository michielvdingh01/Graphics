extends "res://tools/levels/supermarket/plan.gd"
## The front end: the checkouts, the service desk, the carts at the door and
## what stands between the doors and the aisles.

const SMALL := DETAIL | NO_COLLIDE
## The checkouts: how many, where the first is on z and how far apart they are,
## and how far from the front wall they begin and end.
const LANES := 8
const LANE_FIRST := -15.4
const LANE_PITCH := 4.4
const LANE_X := Vector2(7.0, 11.4)


func _describe() -> void:
	for i in LANES:
		_lane(i)
	_service_desk()
	_offers()
	for z: float in ENTRANCES:
		_mat(z)
		_carts_inside(z)
	# Where the checkouts are, for who comes out of the aisles.
	for z: float in [-12.0, 12.0]:
		shop_board("checkout", Vector3(13.5, 3.7, z), Vector3.RIGHT, 3.6, DECK)
	# Small things on the wall that every shop has.
	place("security_camera_01", Vector3(14.0, 5.2, 0.0), 90.0)
	place("fire_alarm", Vector3(0.3, 1.6, -21.0), 90.0)
	place("WetFloorSign_01", Vector3(4.0, 0, 22.0), 30.0)


func _lane(number: int) -> void:
	var z := LANE_FIRST + number * LANE_PITCH
	var middle := (LANE_X.x + LANE_X.y) * 0.5
	var long := LANE_X.y - LANE_X.x
	# The belt, with the bagging end and the till.
	box("shop_cream", Vector3(middle, 0.42, z), Vector3(long, 0.84, 0.8), Vector3.ZERO, DETAIL)
	box("shop_dark", Vector3(middle + 0.4, 0.87, z), Vector3(long - 1.4, 0.05, 0.56), Vector3.ZERO, SMALL)
	box("shop_steel", Vector3(LANE_X.x + 0.5, 0.86, z), Vector3(1.0, 0.03, 0.8), Vector3.ZERO, SMALL)
	# The till and its screen.
	box("shop_dark", Vector3(LANE_X.x + 1.2, 1.0, z + 0.25), Vector3(0.36, 0.26, 0.3), Vector3.ZERO, SMALL)
	box("shop_cool", Vector3(LANE_X.x + 1.2, 1.3, z + 0.25), Vector3(0.28, 0.2, 0.02), Vector3(-12, 0, 0), SMALL)
	# The stand with the lane's number over it, lit.
	cylinder("shop_steel", Vector3(LANE_X.y - 0.2, 0.84, z - 0.3), 0.03, 1.9, SMALL, Vector3.ZERO, -1.0, 8)
	box("shop_sign_red", Vector3(LANE_X.y - 0.2, 2.8, z - 0.3), Vector3(0.1, 0.34, 0.34), Vector3.ZERO, SMALL)
	# Sweets and magazines beside the lane, on the side the customer waits.
	var rack := Vector3(middle, 0.0, z + 1.1)
	box("shop_steel", rack + Vector3.UP * 0.7, Vector3(long - 1.0, 1.4, 0.3), Vector3.ZERO, DETAIL)
	for level in 3:
		var y := 0.5 + level * 0.32
		box("shop_rail", rack + Vector3(0, y - 0.01, -0.2), Vector3(long - 1.0, 0.02, 0.14), Vector3.ZERO, SMALL)
		shelf_line(rack + Vector3((long - 1.0) * 0.5, y, -0.27), rack + Vector3((1.0 - long) * 0.5, y, -0.27), Vector3.FORWARD, ["chocbar", "gummy", "volt_can"], 4, 0.14, 0.26)
	goods_face(rack + Vector3(0, 0.9, -0.2), Vector3(long - 1.0, 1.1, 0.12))
	if number < LANES - 1:
		shop_board("lane", Vector3(LANE_X.y - 0.2, 3.1, z - 0.3), Vector3.RIGHT, 0.8, 4.9)


func _service_desk() -> void:
	var desk := Vector3(5.0, 0, -36.0)
	box("shop_cream", desk + Vector3.UP * 0.55, Vector3(1.0, 1.1, 12.0), Vector3.ZERO, DETAIL)
	box("shop_rail", desk + Vector3.UP * 1.12, Vector3(1.2, 0.05, 12.2), Vector3.ZERO, SMALL)
	box("shop_dark", desk + Vector3(-0.1, 1.28, 2.0), Vector3(0.3, 0.26, 0.4), Vector3.ZERO, SMALL)
	box("shop_cool", desk + Vector3(-0.1, 1.42, -3.0), Vector3(0.02, 0.2, 0.28), Vector3.ZERO, SMALL)
	shop_board("service", Vector3(5.4, 3.5, -36.0), Vector3.RIGHT, 7.0, DECK)
	flashlight_at(desk + Vector3(-0.75, 1.3, -4.5))
	place("metal_stool_02", desk + Vector3(-1.3, 0, -2.0), 20.0)
	place("metal_stool_02", desk + Vector3(-1.3, 0, 3.0), 200.0)


## Stacks on offer between the checkouts and the aisles: soda and water by the
## pallet, and a bin of pumpkins for the season.
func _offers() -> void:
	pallet_of(Vector2(15.5, -11.0), 0.0, "fizz_12", 3, 3, 8)
	pallet_of(Vector2(15.5, -4.5), 90.0, "zap_12", 3, 3, 7)
	pallet_of(Vector2(15.5, 3.5), 0.0, "spring_case", 2, 3, 6)
	pallet_of(Vector2(15.5, 10.0), 0.0, "crunchers", 3, 6, 3)
	pallet_of(Vector2(15.5, 17.0), 90.0, "hawk_case", 2, 3, 6)
	pallet_of(Vector2(15.5, -18.0), 0.0, "charcoal", 2, 6, 3)
	pallet_of(Vector2(39.5, -9.0), 0.0, "shipper_fragile", 2, 2, 3)


## The carts that wait inside a door, nested in a row.
func _carts_inside(z: float) -> void:
	var line := z + 6.0 * signf(z)
	for i in 9:
		var at := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(1.5 + i * 0.3, 0.02, line))
		var node: Node3D = (load("res://scenes/models/cart.scn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		node.name = "CartWaiting"
		node.transform = at
		_add(node, _props)


## The mat inside a door.
func _mat(z: float) -> void:
	box("shop_dark", Vector3(2.4, 0.006, z), Vector3(4.0, 0.012, ENTRANCE_WIDE), Vector3.ZERO, SMALL)
