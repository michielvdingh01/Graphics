extends "res://tools/levels/supermarket/plan.gd"
## The parking lot: all round the store, the most of it in front. Rows of
## stalls with a lane between them, a lamp post down every row, an island at
## each end with a tree on it, racks for the carts, a sign to be seen from the
## road, and the land and the trees beyond.

const SMALL := DETAIL | NO_COLLIDE
## The rows of the front lot: where the middle of each lies on z, and how far
## they run on x. A stall is this wide and this long.
const ROWS: Array[float] = [-76.0, -57.0, -38.0, -19.0, 0.0, 19.0, 38.0, 57.0, 76.0]
const ROW_X := Vector2(-112.0, -18.0)
const STALL := Vector2(2.8, 5.5)
## How far apart the lamp posts stand along a row.
const POST_EVERY := 27.0
const POST_HIGH := 11.0
## The side lots, on x.
const SIDE_ROW_X := Vector2(6.0, 92.0)
const SIDE_ROWS: Array[float] = [-72.0, 72.0]
## Where a rack for carts stands: the middle of it, and its length runs along
## z from there.
const RACKS: Array[Vector2] = [Vector2(-37.0, -28.5), Vector2(-37.0, 9.5), Vector2(-64.0, -9.5), Vector2(-64.0, 28.5), Vector2(-91.0, -47.5)]
const RACK_LONG := 8.0
const RACK_WIDE := 2.4
## Where the SUVs stand: x, z, and which way they face. Their colours go round.
const SUVS: Array[Vector3] = [
	Vector3(-29.0, -22.0, 180.0), Vector3(-46.0, 3.5, 0.0), Vector3(-52.0, -15.5, 180.0), Vector3(-80.0, 22.0, 180.0),
	Vector3(-23.0, 41.0, 180.0), Vector3(-34.0, 60.5, 0.0), Vector3(-71.0, -41.0, 0.0), Vector3(-98.0, -3.5, 0.0),
]
const SUV_KINDS: Array[String] = ["suv_white", "suv_red", "suv_black", "suv_blue"]
## Where carts were left: x, z, how far they turned.
const LEFT_CARTS: Array[Vector3] = [
	Vector3(-24.0, -6.5, 30.0), Vector3(-41.0, -13.0, 200.0), Vector3(-30.0, 13.0, 110.0), Vector3(-55.0, 6.0, 300.0),
	Vector3(-47.0, 26.0, 70.0), Vector3(-69.0, -24.0, 160.0), Vector3(-83.0, 12.0, 20.0), Vector3(-26.0, 28.0, 250.0),
	Vector3(-60.0, -33.0, 95.0), Vector3(-39.0, 46.0, 335.0), Vector3(-92.0, -28.0, 210.0), Vector3(-21.0, -45.0, 130.0),
]


func _describe() -> void:
	_land_and_trees()
	_paving()
	for z in ROWS:
		_row(z, ROW_X)
	for z in SIDE_ROWS:
		_row(z, SIDE_ROW_X)
	_store_front()
	_pylon()
	for rack in RACKS:
		_cart_rack(rack)
	for i in SUVS.size():
		var spot := SUVS[i]
		suv(SUV_KINDS[i % SUV_KINDS.size()], Vector2(spot.x, spot.y), spot.z)
	for spot in LEFT_CARTS:
		cart(Vector2(spot.x, spot.y), spot.z)
	_shut_the_lot()


func _land_and_trees() -> void:
	land(Rect2(LOT_WEST - 180.0, LOT_NORTH - 180.0, LOT_EAST - LOT_WEST + 360.0, LOT_SOUTH - LOT_NORTH + 360.0), -0.06, 4.0, 0.25)
	lay_ground("alpine_meadow")
	var out := 26.0
	var nw := Vector3(LOT_WEST - out, 0, LOT_NORTH - out)
	var ne := Vector3(LOT_EAST + out, 0, LOT_NORTH - out)
	var se := Vector3(LOT_EAST + out, 0, LOT_SOUTH + out)
	var sw := Vector3(LOT_WEST - out, 0, LOT_SOUTH + out)
	tree_wall(ne, nw, 14.0)
	tree_wall(se, ne, 14.0)
	tree_wall(sw, se, 14.0)
	tree_wall(nw, sw, 14.0)


func _paving() -> void:
	var low := -0.15
	var slab := func(from: Vector2, to: Vector2, mat: String) -> void:
		box(mat, Vector3((from.x + to.x) * 0.5, low, (from.y + to.y) * 0.5), Vector3(to.x - from.x, 0.3, to.y - from.y), Vector3.ZERO, DETAIL)
	slab.call(Vector2(LOT_WEST, LOT_NORTH), Vector2(WALK, LOT_SOUTH), "asphalt")
	slab.call(Vector2(WALK, LOT_NORTH), Vector2(LOT_EAST, NORTH_WALL), "asphalt")
	slab.call(Vector2(WALK, SOUTH_WALL), Vector2(LOT_EAST, LOT_SOUTH), "asphalt")
	slab.call(Vector2(REAR, NORTH_WALL), Vector2(LOT_EAST, SOUTH_WALL), "asphalt")
	# The walk along the front of the store.
	box("concrete", Vector3((WALK + FRONT) * 0.5, -0.135, 0.0), Vector3(FRONT - WALK, 0.3, SOUTH_WALL - NORTH_WALL), Vector3.ZERO, DETAIL)
	lot_kerb(Vector2(WALK, NORTH_WALL), Vector2(WALK, SOUTH_WALL), 0.05, 0.14, "paint_yellow")
	# The fire lane in front of it, and the crossings to the lot.
	ground_line(Vector2(WALK - 7.5, LOT_NORTH + 4.0), Vector2(WALK - 7.5, LOT_SOUTH - 4.0), 0.15, "paint_yellow")
	for z in ENTRANCES:
		for i in 7:
			var stripe := z - 2.7 + i * 0.9
			ground_line(Vector2(WALK - 7.0, stripe), Vector2(WALK - 0.4, stripe), 0.45)


## A double row of stalls round the line z, with a divider down its middle and
## an island at each end.
func _row(z: float, ends: Vector2) -> void:
	var x := ends.x
	while x <= ends.y:
		ground_line(Vector2(x, z - STALL.y), Vector2(x, z + STALL.y))
		x += STALL.x
	ground_line(Vector2(ends.x, z), Vector2(ends.y, z), 0.12)
	x = ends.x + POST_EVERY * 0.5
	while x < ends.y:
		_lamp_post(Vector2(x, z))
		x += POST_EVERY
	for end: float in [ends.x - 2.2, ends.y + 2.2]:
		_island(Vector2(end, z))


## A kerbed strip of grass with a tree. The kerb is a bit of paint to a person
## on foot: a person here has no way to step up, see scripts/player.gd.
func _island(at: Vector2) -> void:
	var size := Vector2(3.6, STALL.y * 2.0 - 0.4)
	box("lawn", Vector3(at.x, 0.03, at.y), Vector3(size.x, 0.1, size.y), Vector3.ZERO, SMALL)
	for side: float in [-1.0, 1.0]:
		box("concrete", Vector3(at.x, 0.04, at.y + side * size.y * 0.5), Vector3(size.x + 0.2, 0.14, 0.2), Vector3.ZERO, SMALL)
		box("concrete", Vector3(at.x + side * size.x * 0.5, 0.04, at.y), Vector3(0.2, 0.14, size.y), Vector3.ZERO, SMALL)
	tree("maple", at, _prop_rng.randf_range(0.5, 0.68), _prop_rng.randf() * 360.0)


func _lamp_post(at: Vector2) -> void:
	cylinder("concrete", Vector3(at.x, 0, at.y), 0.32, 0.8, 0, Vector3.ZERO, -1.0, 10)
	cylinder("shop_steel", Vector3(at.x, 0.8, at.y), 0.09, POST_HIGH - 0.8, SMALL, Vector3.ZERO, 0.055, 8)
	_collide_cylinder(Transform3D(Basis(), Vector3(at.x, POST_HIGH * 0.5, at.y)), 0.12, POST_HIGH, "metal")
	for side: float in [-1.0, 1.0]:
		box("shop_steel", Vector3(at.x, POST_HIGH, at.y + side * 0.7), Vector3(0.1, 0.1, 1.4), Vector3.ZERO, SMALL)
		box("shop_dark", Vector3(at.x, POST_HIGH - 0.05, at.y + side * 1.4), Vector3(0.5, 0.14, 0.8), Vector3.ZERO, SMALL)


func _store_front() -> void:
	shop_board("store", Vector3(FRONT - 0.42, 7.95, 0.0), Vector3.LEFT, 22.0, NAN, false)
	# The front is not one flat wall: brick to the height of a window sill, a
	# pier every so often, and a band along the top.
	var pieces: Array = [[NORTH_WALL, ENTRANCES[0] - ENTRANCE_WIDE * 0.5], [ENTRANCES[0] + ENTRANCE_WIDE * 0.5, WINDOW_NORTH], [WINDOW_SOUTH, ENTRANCES[1] - ENTRANCE_WIDE * 0.5], [ENTRANCES[1] + ENTRANCE_WIDE * 0.5, SOUTH_WALL]]
	for piece: Array in pieces:
		box("brick", Vector3(FRONT - 0.2, 1.4, (piece[0] + piece[1]) * 0.5), Vector3(0.12, 2.8, piece[1] - piece[0]), Vector3.ZERO, SMALL)
	box("brick", Vector3(FRONT - 0.2, WINDOW_LOW * 0.5, 0.0), Vector3(0.12, WINDOW_LOW, WINDOW_SOUTH - WINDOW_NORTH), Vector3.ZERO, SMALL)
	box("shop_cream", Vector3(FRONT - 0.24, WINDOW_HIGH + 0.25, 0.0), Vector3(0.2, 0.5, SOUTH_WALL - NORTH_WALL), Vector3.ZERO, SMALL)
	box("shop_red", Vector3(FRONT - 0.3, WALL_TOP - 0.3, 0.0), Vector3(0.1, 0.34, SOUTH_WALL - NORTH_WALL), Vector3.ZERO, SMALL)
	box("shop_cream", Vector3(FRONT - 0.3, PARAPET - 0.2, 0.0), Vector3(0.14, 0.26, 66.0), Vector3.ZERO, SMALL)
	var pier := NORTH_WALL + 6.0
	while pier < SOUTH_WALL:
		var clear := true
		for z in ENTRANCES:
			clear = clear and absf(pier - z) > 7.0
		if clear:
			box("stucco", Vector3(FRONT - 0.34, WALL_TOP * 0.5, pier), Vector3(0.36, WALL_TOP, 0.9), Vector3.ZERO, SMALL)
			box("shop_cream", Vector3(FRONT - 0.5, WALL_TOP - 0.5, pier), Vector3(0.1, 0.5, 1.1), Vector3.ZERO, SMALL)
		pier += 13.0
	shop_board("sale", Vector3(FRONT - 0.3, 4.75, -27.0), Vector3.LEFT, 6.0, NAN, false)
	shop_board("store_open", Vector3(FRONT - 0.3, 4.75, 27.0), Vector3.LEFT, 8.0, NAN, false)
	# What hangs in the window, seen from the lot and with the sun behind it.
	for z: float in [-13.0, -4.0, 6.0, 14.0]:
		shop_board("sale" if int(z) % 2 == 0 else "welcome", Vector3(FRONT + 0.3, 3.05, z), Vector3.LEFT, 3.2, DECK)
	for z in ENTRANCES:
		var roof_y := 3.9
		box("stucco", Vector3(-2.0, roof_y + 0.15, z), Vector3(4.6, 0.3, 10.0), Vector3.ZERO, DETAIL)
		box("shop_red", Vector3(-4.3, roof_y + 0.15, z), Vector3(0.06, 0.34, 10.0), Vector3.ZERO, SMALL)
		for side: float in [-1.0, 1.0]:
			cylinder("stucco", Vector3(-3.9, 0, z + side * 4.4), 0.2, roof_y, DETAIL, Vector3.ZERO, -1.0, 10)
		shop_board("welcome", Vector3(-4.36, roof_y + 0.6, z), Vector3.LEFT, 3.2, NAN, false)
		_doors(z)
		for side: float in [-1.0, 1.0]:
			for i in 4:
				var post := Vector2(WALK + 0.4, z + side * (ENTRANCE_WIDE * 0.5 + 1.5 + i * 1.6))
				_bollard(post)
	# What stands along the wall: ice, soda machines, a cage of gas bottles.
	_ice_chest(Vector2(-1.1, -15.0))
	_ice_chest(Vector2(-1.1, 15.0))
	_vending(Vector2(-0.9, -9.0), "shop_red")
	_vending(Vector2(-0.9, -7.6), "shop_blue")
	_vending(Vector2(-0.9, 9.0), "shop_green")
	for x_z: Vector2 in [Vector2(-1.2, -12.0), Vector2(-1.2, 12.0), Vector2(-1.2, -33.0), Vector2(-1.2, 33.0)]:
		place("metal_trash_can", Vector3(x_z.x, 0, x_z.y), 0.0)
	for i in 6:
		gas_bottle(Vector3(-1.2 + (i % 2) * 0.4, 0, -39.0 + i * 0.4))


func _bollard(at: Vector2) -> void:
	cylinder("paint_red", Vector3(at.x, 0, at.y), 0.1, 0.95, 0, Vector3.ZERO, -1.0, 8)


func _ice_chest(at: Vector2) -> void:
	box("shop_white", Vector3(at.x, 0.95, at.y), Vector3(1.0, 1.9, 2.4), Vector3.ZERO, DETAIL)
	box("shop_blue", Vector3(at.x - 0.51, 1.5, at.y), Vector3(0.02, 0.5, 2.2), Vector3.ZERO, SMALL)


func _vending(at: Vector2, mat: String) -> void:
	box(mat, Vector3(at.x, 0.95, at.y), Vector3(0.9, 1.9, 1.2), Vector3.ZERO, DETAIL)
	box("shop_cool", Vector3(at.x - 0.46, 1.1, at.y + 0.2), Vector3(0.02, 1.3, 0.6), Vector3.ZERO, SMALL)


## The sliding doors of a way in: a frame, and two leaves that scripts/shop_door.gd
## moves apart while somebody is near and there is power.
func _doors(z: float) -> void:
	box("shop_dark", Vector3(FRONT, ENTRANCE_HIGH - 0.1, z), Vector3(0.36, 0.2, ENTRANCE_WIDE), Vector3.ZERO, SMALL)
	for side: float in [-1.0, 1.0]:
		box("shop_dark", Vector3(FRONT, ENTRANCE_HIGH * 0.5, z + side * (ENTRANCE_WIDE * 0.5 - 0.05)), Vector3(0.36, ENTRANCE_HIGH, 0.1), Vector3.ZERO, SMALL)
		var leaf := _mover("Door%s" % ("N" if z < 0.0 else "S") + ("L" if side < 0.0 else "R"), Vector3(FRONT, 0, z + side * ENTRANCE_WIDE * 0.25))
		leaf.set_script(load("res://scripts/shop_door.gd"))
		leaf.set("slides", Vector3(0, 0, side * (ENTRANCE_WIDE * 0.5 - 0.15)))
		_build_into(leaf)
		var at := Vector3(FRONT, ENTRANCE_HIGH * 0.5 - 0.1, z + side * ENTRANCE_WIDE * 0.25)
		for frame: float in [-1.0, 1.0]:
			box("shop_dark", at + Vector3(0, 0, frame * (ENTRANCE_WIDE * 0.25 - 0.08)), Vector3(0.06, ENTRANCE_HIGH - 0.2, 0.06), Vector3.ZERO, SMALL)
		box("shop_dark", at + Vector3(0, ENTRANCE_HIGH * 0.5 - 0.18, 0), Vector3(0.06, 0.08, ENTRANCE_WIDE * 0.5 - 0.1), Vector3.ZERO, SMALL)
		box("shop_dark", at - Vector3(0, ENTRANCE_HIGH * 0.5 - 0.18, 0), Vector3(0.06, 0.08, ENTRANCE_WIDE * 0.5 - 0.1), Vector3.ZERO, SMALL)
		box("glass", at, Vector3(0.012, ENTRANCE_HIGH - 0.34, ENTRANCE_WIDE * 0.5 - 0.2), Vector3.ZERO, NO_COLLIDE | GLASS)
		_collide_box(Transform3D(Basis(), at), Vector3(0.1, ENTRANCE_HIGH, ENTRANCE_WIDE * 0.5), "metal")
		_build_into(null)


## A big sign on a pole by the road.
func _pylon() -> void:
	var at := Vector3(-104.0, 0, 0.0)
	var high := 16.0
	for side: float in [-1.2, 1.2]:
		cylinder("shop_steel", at + Vector3(0, 0, side), 0.2, high, 0, Vector3.ZERO, -1.0, 10)
	shop_board("store", at + Vector3(0, high - 1.6, 0), Vector3.LEFT, 10.0)
	shop_board("store_open", at + Vector3(0, high - 3.4, 0), Vector3.LEFT, 8.0)
	box("concrete", at + Vector3(0, 0.3, 0), Vector3(1.6, 0.6, 4.0), Vector3.ZERO, DETAIL)


## A rack for carts in the middle of three stalls: two rails with a hoop at the
## end. scripts/cart_rack.gd takes what is pushed in at the open end.
func _cart_rack(at: Vector2) -> void:
	var y := 0.95
	for side: float in [-1.0, 1.0]:
		var x := at.x + side * RACK_WIDE * 0.5
		rod("shop_steel", Vector3(x, y, at.y - RACK_LONG * 0.5), Vector3(x, y, at.y + RACK_LONG * 0.5), 0.03, DETAIL | NO_COLLIDE, 8)
		rod("shop_steel", Vector3(x, 0.5, at.y - RACK_LONG * 0.5), Vector3(x, 0.5, at.y + RACK_LONG * 0.5), 0.02, DETAIL | NO_COLLIDE, 8)
		_collide_box(Transform3D(Basis(), Vector3(x, 0.5, at.y)), Vector3(0.1, 1.0, RACK_LONG), "metal")
		var post := at.y - RACK_LONG * 0.5
		while post <= at.y + RACK_LONG * 0.5 + 0.01:
			rod("shop_steel", Vector3(x, 0, post), Vector3(x, y, post), 0.03, DETAIL | NO_COLLIDE, 8)
			post += RACK_LONG * 0.5
	rod("shop_steel", Vector3(at.x - RACK_WIDE * 0.5, y, at.y + RACK_LONG * 0.5), Vector3(at.x + RACK_WIDE * 0.5, y, at.y + RACK_LONG * 0.5), 0.03, DETAIL | NO_COLLIDE, 8)
	_collide_box(Transform3D(Basis(), Vector3(at.x, 0.5, at.y + RACK_LONG * 0.5)), Vector3(RACK_WIDE, 1.0, 0.1), "metal")
	shop_board("cart_back", Vector3(at.x, 2.2, at.y + RACK_LONG * 0.5 - 0.05), Vector3.FORWARD, 2.4)
	cylinder("shop_steel", Vector3(at.x, 0, at.y + RACK_LONG * 0.5), 0.03, 2.05, SMALL, Vector3.ZERO, -1.0, 6)
	shop_board("carts", Vector3(at.x, 2.5, at.y - RACK_LONG * 0.5 - 0.0), Vector3.FORWARD, 2.0)
	cylinder("shop_steel", Vector3(at.x, 0, at.y - RACK_LONG * 0.5), 0.03, 2.3, SMALL, Vector3.ZERO, -1.0, 6)
	cart_rack(at, RACK_WIDE, RACK_LONG)


## Walls nobody sees round the lot.
func _shut_the_lot() -> void:
	var high := 60.0
	var mid := Vector2((LOT_WEST + LOT_EAST) * 0.5, (LOT_NORTH + LOT_SOUTH) * 0.5)
	var wide := LOT_EAST - LOT_WEST + 2.0
	var deep := LOT_SOUTH - LOT_NORTH + 2.0
	for wall: Array in [
		[Vector3(mid.x, 20.0, LOT_NORTH - 0.5), Vector3(wide, high, 1.0)], [Vector3(mid.x, 20.0, LOT_SOUTH + 0.5), Vector3(wide, high, 1.0)],
		[Vector3(LOT_WEST - 0.5, 20.0, mid.y), Vector3(1.0, high, deep)], [Vector3(LOT_EAST + 0.5, 20.0, mid.y), Vector3(1.0, high, deep)],
	]:
		_collide_box(Transform3D(Basis(), wall[0]), wall[1], "air")
		_unseen.append(AABB(wall[0] - wall[1] * 0.5, wall[1]))
