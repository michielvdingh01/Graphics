extends "res://tools/kit/alpine.gd"
## Sixteenth drawer of the kit, see tools/kit.gd: what stands in a supermarket.
## Gondolas, cold cases and bins, and everything on sale in them.
##
## What is on sale is not built into the level. The drawer writes down where
## each thing stands, stock() and the ways of filling a shelf that go through
## it, and the level saves that list as <level>_goods.res. scripts/goods.gd
## makes meshes of it when the level loads, since a MultiMesh cannot be built
## without a renderer, and takes the shots. Every shelf has a box in front of
## it, goods_face(), which is what a shot lands on.

const CATALOG := preload("res://scripts/goods_catalog.gd")
const GOODS_DATA := preload("res://scripts/goods_data.gd")

## How high a gondola stands, how deep it is on each side of its spine and how
## far apart its uprights are, in metres.
const GONDOLA_HIGH := 2.1
const GONDOLA_SIDE := 0.58
const GONDOLA_BAY := 1.22
## The shelves of a gondola: how high each one lies, from the deck up.
const GONDOLA_SHELVES: Array[float] = [0.16, 0.56, 0.96, 1.36, 1.74]
## How much room there is over a shelf for what stands on it.
const SHELF_CLEAR := 0.34
const SHELF_DEEP := 0.5
const SHELF_THICK := 0.025
## How much a thing leaves between itself and the next.
const GAP := 0.006
## How much of the light reaches the back row of a shelf, and the lowest shelf.
const BACK_LIGHT := 0.72
const LOW_LIGHT := 0.86

## The flags the walls of a level are built with: a level that bakes nothing
## says DETAIL, and wall() goes along.
var _wall_flags := 0
## The things on sale so far, see scripts/goods_data.gd.
var _goods := PackedFloat32Array()
## The body that shots land on, which scripts/goods.gd runs.
var _goods_body: StaticBody3D
## Where the carts that were left stand.
var _carts: Node3D


func _wall_piece(mat: String, along_x: bool, fixed: float, thickness: float, a0: float, a1: float, y0: float, y1: float) -> void:
	if a1 - a0 < 0.001 or y1 - y0 < 0.001:
		return
	var mid := (a0 + a1) * 0.5
	if along_x:
		box(mat, Vector3(mid, (y0 + y1) * 0.5, fixed), Vector3(a1 - a0, y1 - y0, thickness), Vector3.ZERO, _wall_flags)
	else:
		box(mat, Vector3(fixed, (y0 + y1) * 0.5, mid), Vector3(thickness, y1 - y0, a1 - a0), Vector3.ZERO, _wall_flags)


## Puts one thing on sale with its middle at `at`, facing `yaw_rad`, on top of
## the thing with number `on`. Gives its number.
func stock(product: String, at: Vector3, yaw_rad: float, pose := 0, light := 1.0, on := -1) -> int:
	var number := _goods.size() / GOODS_DATA.STRIDE
	_goods.append_array([at.x, at.y, at.z, yaw_rad, CATALOG.index(product), pose, clampf(light, 0.0, 1.0), on + 1])
	return number


## A box in front of something on sale, that shots land on: its middle and its
## size. It is in nobody's way. Leaves no mark: the things do.
func goods_face(center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var node := CollisionShape3D.new()
	node.shape = shape
	node.position = center
	node.set_meta(&"surface", "air")
	_add(node, _body_of_goods())


func _body_of_goods() -> StaticBody3D:
	if _goods_body == null:
		_goods_body = StaticBody3D.new()
		_goods_body.name = "Goods"
		_goods_body.set_script(load("res://scripts/goods.gd"))
		_add(_goods_body, _zones.shop.contents if _zones.has("shop") else _root)
	return _goods_body


## Writes down what is on sale, once the builder has cleared last time's files.
func _finish_zones() -> void:
	super()
	if _goods_body == null:
		return
	var data: Resource = GOODS_DATA.new()
	data.items = _goods
	var path := "%s%s_goods.res" % [OUT_DIR, _level_name()]
	ResourceSaver.save(data, path, ResourceSaver.FLAG_COMPRESS)
	data.take_over_path(path)
	_goods_body.set("data", data)
	print("On sale: %d things in %d boxes" % [_goods.size() / GOODS_DATA.STRIDE, _goods_body.get_child_count()])
	_no_sun_inside()


## What stands under a roof throws no shadow of the sun that anybody sees, and
## drawing it into the maps of the sun is half of what a frame of a shop costs.
## The shell belongs to no zone and casts on.
func _no_sun_inside() -> void:
	for zone_name: String in ["shop", "stock"]:
		if _zones.has(zone_name):
			for mesh: MeshInstance3D in (_zones[zone_name].contents as Node).find_children("*", "MeshInstance3D", false, false):
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Fills a stretch of shelf with what is in `mix`, one product after the other,
## `facings` of each side by side and as many deep and high as there is room
## for: `from` and `to` are the ends of its front edge, on top of the shelf,
## `out` the way it faces, `deep` how deep it is and `clear` how much room it
## has above it. `rows` is the most that stand behind each other.
func shelf_line(from: Vector3, to: Vector3, out: Vector3, mix: Array, facings := 3, deep := SHELF_DEEP, clear := SHELF_CLEAR, rows := 1, light := 1.0) -> void:
	var along := (to - from).normalized()
	var length := from.distance_to(to)
	var yaw := atan2(out.x, out.z)
	var run := 0.0
	var which := 0
	while true:
		var id: String = mix[which % mix.size()]
		var size: Vector3 = CATALOG.product(id).size
		var fits := false
		for i in facings:
			if run + size.x > length:
				break
			fits = true
			var mid := from + along * (run + size.x * 0.5) - out * (size.z * 0.5 + 0.015)
			_column(id, mid, out, yaw, deep, clear, rows, light)
			run += size.x + GAP
		which += 1
		if not fits:
			break
		# Now and then there is a gap where somebody took the last.
		if _clutter_rng.randf() < 0.03:
			run += size.x


## One column of a product, from the front of the shelf back, stacked as high
## as it goes.
func _column(id: String, front: Vector3, out: Vector3, yaw: float, deep: float, clear: float, rows: int, light: float) -> void:
	var product := CATALOG.product(id)
	var size: Vector3 = product.size
	if product.shape == "long":
		var pile := mini(int(clear / size.x), 3)
		for level in pile:
			stock(id, front + Vector3.UP * (size.x * (level + 0.5)) - out * size.y * 0.5, yaw, 1, light)
		return
	var behind := mini(rows, int(deep / size.z))
	var high := int(clear / size.y) if product.shape in ["box", "can", "tub", "jar", "tray"] else 1
	high = mini(maxi(high, 1), 2)
	for row in maxi(behind, 1):
		# Somebody has been at the front of the shelf.
		if row == 0 and _clutter_rng.randf() < 0.05:
			continue
		var under := -1
		var at := front - out * (size.z + GAP) * row
		for level in high:
			var spot := at + Vector3.UP * (size.y * (level + 0.5))
			spot += Vector3(_clutter_rng.randf_range(-0.004, 0.004), 0, _clutter_rng.randf_range(-0.004, 0.004))
			var turned := yaw + _clutter_rng.randf_range(-0.05, 0.05)
			var lit := light * lerpf(1.0, BACK_LIGHT, float(row) / maxf(behind - 1, 1))
			under = stock(id, spot, turned, 0, lit, under)


## A gondola from `from` to `to`, as a run of shelves on both sides of a spine.
## `left` and `right` say what is on sale on each side as you go from `from`
## to `to`: a list per shelf from the bottom up, each a list of products, or
## one list that goes for every shelf. `facings` is how many of a kind stand
## side by side. Its way along has to be along an axis.
func gondola(from: Vector2, to: Vector2, left: Array, right: Array, facings := 3) -> void:
	var a := Vector3(from.x, 0, from.y)
	var b := Vector3(to.x, 0, to.y)
	var length := a.distance_to(b)
	var along := (b - a).normalized()
	var mid := (a + b) * 0.5
	var side := along.cross(Vector3.UP).normalized()
	var flags := DETAIL | NO_COLLIDE
	var turned := Basis(Vector3.UP, atan2(along.x, along.z))
	var frame := Transform3D(turned, mid)
	# What stops a person and a shot.
	_collide_box(frame * Transform3D(Basis(), Vector3(0, GONDOLA_HIGH * 0.5, 0)), Vector3(GONDOLA_SIDE * 2.0, GONDOLA_HIGH, length), "metal")
	# The spine: a back of perforated steel with a cap along the top.
	_local_box("shop_rail", frame, Vector3(0, GONDOLA_HIGH * 0.5, 0), Vector3(0.05, GONDOLA_HIGH, length), flags)
	_local_box("shop_steel", frame, Vector3(0, GONDOLA_HIGH + 0.02, 0), Vector3(0.12, 0.04, length), flags)
	_hides(frame, Vector3(0.1, GONDOLA_HIGH, length))
	var bays := roundi(length / GONDOLA_BAY)
	for i in bays + 1:
		var z := -length * 0.5 + length * float(i) / bays
		_local_box("shop_steel", frame, Vector3(0, GONDOLA_HIGH * 0.5, z), Vector3(0.09, GONDOLA_HIGH, 0.03), flags)
	for s: float in [-1.0, 1.0]:
		var stock_of: Array = left if s > 0.0 else right
		var out := turned * Vector3(s, 0, 0)
		# The deck, with a kick plate in front of it.
		_local_box("shop_steel", frame, Vector3(s * GONDOLA_SIDE * 0.5, 0.075, 0), Vector3(GONDOLA_SIDE, 0.15, length), flags)
		_local_box("shop_dark", frame, Vector3(s * (GONDOLA_SIDE + 0.004), 0.07, 0), Vector3(0.012, 0.14, length), flags)
		for level in GONDOLA_SHELVES.size():
			var y := GONDOLA_SHELVES[level]
			if level > 0:
				_local_box("shop_steel", frame, Vector3(s * GONDOLA_SIDE * 0.5, y - SHELF_THICK * 0.5, 0), Vector3(GONDOLA_SIDE - 0.02, SHELF_THICK, length), flags)
			# The strip along the front that the prices sit in.
			_local_box("shop_rail", frame, Vector3(s * (GONDOLA_SIDE - 0.003), y - 0.012, 0), Vector3(0.012, 0.05, length), flags)
			var line: Array = stock_of[level] if stock_of[0] is Array else stock_of
			var light := LOW_LIGHT if level == 0 else 1.0
			var edge := Vector3(s * (GONDOLA_SIDE - 0.02), y, 0)
			var near := frame * (edge + Vector3(0, 0, -length * 0.5 + 0.03) * s)
			var far := frame * (edge + Vector3(0, 0, length * 0.5 - 0.03) * s)
			shelf_line(near, far, out, line, facings, SHELF_DEEP, SHELF_CLEAR, 1, light)
			_price_tags(frame, s, y, length)
		# The box that shots land on, the whole height of this side.
		goods_face(frame * Vector3(s * (GONDOLA_SIDE + 0.02), GONDOLA_HIGH * 0.5, 0), (turned * Vector3(0.08, GONDOLA_HIGH, length - 0.1)).abs())


## What stands behind a gondola is not drawn: its spine is an occluder for the
## renderer.
func _hides(frame: Transform3D, size: Vector3) -> void:
	var occluder := OccluderInstance3D.new()
	occluder.name = "Hides"
	var shape := BoxOccluder3D.new()
	shape.size = size
	occluder.occluder = shape
	occluder.transform = frame * Transform3D(Basis(), Vector3(0, size.y * 0.5, 0))
	_add(occluder, _root)


## The little labels along a shelf.
func _price_tags(frame: Transform3D, s: float, y: float, length: float) -> void:
	var step := 0.66
	var count := int(length / step)
	for i in count:
		var z := -length * 0.5 + (i + 0.5) * step + _clutter_rng.randf_range(-0.03, 0.03)
		_local_box("paper", frame, Vector3(s * GONDOLA_SIDE + s * 0.002, y - 0.012, z), Vector3(0.004, 0.032, 0.05), DETAIL | NO_COLLIDE)


## Shelves against a wall, from `from` to `to`, facing `out`, the height of a
## gondola and with a list per shelf as gondola() has.
func wall_shelves(from: Vector3, to: Vector3, out: Vector3, mix: Array, facings := 3) -> void:
	var length := from.distance_to(to)
	var along := (to - from).normalized()
	var flags := DETAIL | NO_COLLIDE
	var mid := (from + to) * 0.5
	var sized := func(size: Vector3) -> Vector3: return (along * size.x + out * size.z).abs() + Vector3(0, size.y, 0)
	_collide_box(Transform3D(Basis(), mid + out * GONDOLA_SIDE * 0.5 + Vector3.UP * GONDOLA_HIGH * 0.5), sized.call(Vector3(length, GONDOLA_HIGH, GONDOLA_SIDE)), "metal")
	box("shop_rail", mid + Vector3.UP * GONDOLA_HIGH * 0.5, sized.call(Vector3(length, GONDOLA_HIGH, 0.04)), Vector3.ZERO, flags)
	box("shop_steel", mid + out * GONDOLA_SIDE * 0.5 + Vector3.UP * 0.075, sized.call(Vector3(length, 0.15, GONDOLA_SIDE)), Vector3.ZERO, flags)
	box("shop_dark", mid + out * (GONDOLA_SIDE + 0.004) + Vector3.UP * 0.07, sized.call(Vector3(length, 0.14, 0.012)), Vector3.ZERO, flags)
	for level in GONDOLA_SHELVES.size():
		var y := GONDOLA_SHELVES[level]
		if level > 0:
			box("shop_steel", mid + out * GONDOLA_SIDE * 0.5 + Vector3.UP * (y - SHELF_THICK * 0.5), sized.call(Vector3(length, SHELF_THICK, GONDOLA_SIDE - 0.02)), Vector3.ZERO, flags)
		box("shop_rail", mid + out * (GONDOLA_SIDE - 0.003) + Vector3.UP * (y - 0.012), sized.call(Vector3(length, 0.05, 0.012)), Vector3.ZERO, flags)
		var line: Array = mix[level % mix.size()] if mix[0] is Array else mix
		shelf_line(from + out * (GONDOLA_SIDE - 0.02) + Vector3.UP * y, to + out * (GONDOLA_SIDE - 0.02) + Vector3.UP * y, out, line, facings, SHELF_DEEP, SHELF_CLEAR, 1)
	goods_face(mid + out * (GONDOLA_SIDE + 0.02) + Vector3.UP * GONDOLA_HIGH * 0.5, sized.call(Vector3(length - 0.1, GONDOLA_HIGH, 0.08)))


## An SUV that can be driven: `kind` is one of the models of
## tools/models/suv.gd, `at` where it stands, its nose towards `yaw_deg`.
func suv(kind: String, at: Vector2, yaw_deg: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg + 180.0)), Vector3(at.x, 0.02, at.y))
	if _vehicles == null:
		_vehicles = Node3D.new()
		_vehicles.name = "Vehicles"
		_add(_vehicles, _root)
	var body := RigidBody3D.new()
	body.name = "Suv"
	body.transform = xf
	body.set_script(load("res://scripts/vehicle.gd"))
	body.set("kind", kind)
	_add(body, _vehicles)
	var node: Node3D = (load("res://scenes/models/%s.scn" % kind) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.name = "Model"
	_add(node, body)


## A flashlight where it can be found: see scripts/flashlight.gd.
func flashlight_at(at: Vector3) -> void:
	var node := Node3D.new()
	node.name = "Flashlight"
	node.position = at
	node.set_script(load("res://scripts/flashlight.gd"))
	_add(node, _root)


## A cart somebody left at `at`, turned `yaw_deg`: see scripts/cart.gd.
func cart(at: Vector2, yaw_deg: float) -> void:
	if _carts == null:
		_carts = Node3D.new()
		_carts.name = "Carts"
		_add(_carts, _root)
	var body := RigidBody3D.new()
	body.name = "Cart"
	body.position = Vector3(at.x, 0.03, at.y)
	body.rotation.y = deg_to_rad(yaw_deg)
	body.set_script(load("res://scripts/cart.gd"))
	_add(body, _carts)
	var node: Node3D = (load("res://scenes/models/cart.scn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.name = "Model"
	_add(node, body)


## The place where carts go back: `at` is its middle, and a cart is pushed in
## from the north end. See scripts/cart_rack.gd.
func cart_rack(at: Vector2, wide: float, long: float) -> void:
	var rack := Area3D.new()
	rack.name = "CartRack"
	rack.position = Vector3(at.x, 0.5, at.y)
	rack.set_script(load("res://scripts/cart_rack.gd"))
	rack.set("long", long)
	_add(rack, _root)
	var shape := CollisionShape3D.new()
	var size := BoxShape3D.new()
	size.size = Vector3(wide, 1.0, long)
	shape.shape = size
	_add(shape, rack)


## The end of a gondola, with a stack of something on offer: `at` is the middle
## of the end, `out` the way it faces.
func end_cap(at: Vector3, out: Vector3, mix: Array, width := 1.2) -> void:
	var yaw := atan2(out.x, out.z)
	var flags := DETAIL | NO_COLLIDE
	var frame := Transform3D(Basis(Vector3.UP, yaw), at)
	_collide_box(frame * Transform3D(Basis(), Vector3(0, GONDOLA_HIGH * 0.5, 0.31)), Vector3(width, GONDOLA_HIGH, 0.62), "metal")
	_local_box("shop_rail", frame, Vector3(0, GONDOLA_HIGH * 0.5, 0.0), Vector3(width, GONDOLA_HIGH, 0.04), flags)
	_local_box("shop_steel", frame, Vector3(0, 0.075, 0.31), Vector3(width, 0.15, 0.62), flags)
	_local_box("shop_dark", frame, Vector3(0, 0.07, 0.625), Vector3(width, 0.14, 0.012), flags)
	var levels: Array[float] = [0.16, 0.76, 1.36]
	for i in levels.size():
		var y := levels[i]
		if i > 0:
			_local_box("shop_steel", frame, Vector3(0, y - SHELF_THICK * 0.5, 0.3), Vector3(width - 0.04, SHELF_THICK, 0.58), flags)
		_local_box("shop_rail", frame, Vector3(0, y - 0.012, 0.61), Vector3(width, 0.05, 0.012), flags)
		var edge_l := frame * Vector3(-width * 0.5 + 0.03, y, 0.6)
		var edge_r := frame * Vector3(width * 0.5 - 0.03, y, 0.6)
		shelf_line(edge_l, edge_r, out, [mix[i % mix.size()]], 12, 0.55, 0.56, 3)
	goods_face(frame * Vector3(0, GONDOLA_HIGH * 0.5, 0.64), (Basis(Vector3.UP, yaw) * Vector3(width, GONDOLA_HIGH, 0.08)).abs())


## A heap of something in a bin: `area` is the floor of the bin on x and z at
## height `y`, and the heap rises `high` towards the back, `back` being the way
## it rises towards. What lies on top rests on what lies under it, and comes
## down with it.
func heap(area: Rect2, y: float, id: String, high: float, back := Vector2.ZERO, face_up := false) -> void:
	var product := CATALOG.product(id)
	var size: Vector3 = product.size
	var across := maxf(size.x, size.z) * 0.92
	var tall := minf(size.y, across) * 0.78
	var layers := maxi(int(high / tall), 1)
	var below := {}
	for layer in layers:
		var here := {}
		var inset := across * 0.5 * (layer * 0.25 + 0.5)
		var cols := int((area.size.x - inset * 2.0) / across)
		var rows := int((area.size.y - inset * 2.0) / across)
		for i in cols + 1:
			for j in rows + 1:
				var u := float(i) / maxi(cols, 1)
				var v := float(j) / maxi(rows, 1)
				# How much of the heap goes as high as this layer.
				var rise := 1.0 if back == Vector2.ZERO else clampf(0.5 + 0.5 * (back.x * (u * 2.0 - 1.0) + back.y * (v * 2.0 - 1.0)), 0.0, 1.0)
				if back == Vector2.ZERO:
					rise = 1.0 - maxf(absf(u * 2.0 - 1.0), absf(v * 2.0 - 1.0)) * 0.7
				if float(layer) / layers > rise + 0.02:
					continue
				# Nobody sees into a heap: of its lower layers only the edge is
				# there, and what lies on top rests on air until it is shot.
				var edge := i == 0 or j == 0 or i == cols or j == rows
				if layer < rise * layers - 2.0 and not edge:
					continue
				var shift := across * 0.5 * (layer % 2)
				var x := area.position.x + inset + i * across + shift + _clutter_rng.randf_range(-0.012, 0.012)
				var z := area.position.y + inset + j * across + _clutter_rng.randf_range(-0.012, 0.012)
				if x > area.end.x - across * 0.4:
					continue
				var at := Vector3(x, y + tall * (layer + 0.5), z)
				var key := Vector2i(i, j)
				var on: int = below.get(key, -1)
				here[key] = stock(id, at, _clutter_rng.randf() * TAU, 0 if face_up else 2, 1.0 - 0.18 * float(layers - layer) / layers, on)
		below = here


## A pallet with cases of `id` stacked on it, `wide` by `deep` and `layers`
## high, facing `yaw_deg`. Colliders for the whole of it, and a box for shots.
func pallet_of(at: Vector2, yaw_deg: float, id: String, wide := 3, deep := 2, layers := 4, collide := true) -> void:
	var yaw := deg_to_rad(yaw_deg)
	var size: Vector3 = CATALOG.product(id).size
	var turned := Basis(Vector3.UP, yaw)
	var floor_y := 0.15
	var frame := Transform3D(turned, Vector3(at.x, 0, at.y))
	_local_box("shop_wood", frame, Vector3(0, 0.075, 0), Vector3(1.2, 0.15, 1.0), DETAIL | NO_COLLIDE)
	var unders := {}
	for layer in layers:
		for i in wide:
			for j in deep:
				var local := Vector3((i - (wide - 1) * 0.5) * (size.x + 0.008), floor_y + size.y * (layer + 0.5), (j - (deep - 1) * 0.5) * (size.z + 0.008))
				var key := Vector2i(i, j)
				unders[key] = stock(id, frame * local, yaw, 0, 0.9 + 0.1 * float(layer + 1) / layers, unders.get(key, -1))
	var box_size := Vector3(size.x * wide, size.y * layers, size.z * deep)
	var center := frame * Vector3(0, floor_y + box_size.y * 0.5, 0)
	if collide:
		_collide_box(Transform3D(turned, center), box_size + Vector3(0, floor_y * 2.0, 0), "soft")
	goods_face(center, (turned * (box_size + Vector3(0.1, 0.1, 0.1))).abs())


## A wall of cold doors: a case along the wall from `wall_from` to `wall_to`,
## with glass doors in front, facing `out`, with its shelves full of `mix`, a list
## per shelf from the bottom up. Lit from inside.
func cold_doors(wall_from: Vector3, wall_to: Vector3, out: Vector3, mix: Array, facings := 4) -> void:
	var high := 2.2
	var deep := 0.9
	var from := wall_from + out * deep
	var to := wall_to + out * deep
	var length := from.distance_to(to)
	var along := (to - from).normalized()
	var mid := (from + to) * 0.5 - out * deep * 0.5 + Vector3.UP * high * 0.5
	var flags := DETAIL | NO_COLLIDE
	var turned := Basis(along, Vector3.UP, along.cross(Vector3.UP).normalized())
	# The case round it: a floor, a top, a back and ends.
	_collide_box(Transform3D(turned.orthonormalized(), mid - out * 0.15), (Basis(Vector3.UP, atan2(out.x, out.z)) * Vector3(length, high, deep - 0.3)).abs(), "metal")
	box("shop_steel", mid - Vector3.UP * (high * 0.5 - 0.1), (along * length + out * deep).abs() + Vector3(0, 0.2, 0), Vector3.ZERO, flags)
	box("shop_steel", mid + Vector3.UP * (high * 0.5 + 0.15), (along * length + out * deep).abs() + Vector3(0, 0.3, 0), Vector3.ZERO, flags)
	box("shop_cool", mid + Vector3.UP * (high * 0.5 - 0.02) + out * 0.2, (along * length + out * 0.08).abs() + Vector3(0, 0.03, 0), Vector3.ZERO, flags)
	box("shop_rail", mid - out * (deep * 0.5 - 0.02), (along * length).abs() + out.abs() * 0.04 + Vector3(0, high, 0), Vector3.ZERO, flags)
	var doors := maxi(roundi(length / 0.76), 1)
	var levels: Array[float] = [0.24, 0.62, 1.0, 1.38, 1.76]
	for level in levels.size():
		var y := levels[level]
		if level > 0:
			box("shop_steel", from - out * deep * 0.5 + along * length * 0.5 + Vector3.UP * (y - 0.012), (along * length + out * (deep - 0.2)).abs() + Vector3(0, 0.02, 0), Vector3.ZERO, flags)
		var line: Array = mix[level % mix.size()] if mix[0] is Array else mix
		var start := from - out * 0.1 + along * 0.03 + Vector3.UP * y
		var end := to - out * 0.1 - along * 0.03 + Vector3.UP * y
		shelf_line(start, end, out, line, facings, 0.5, 0.34, 2, 1.0)
	for i in doors + 1:
		var at := from + along * (length * float(i) / doors)
		box("shop_dark", at + Vector3.UP * (high * 0.5 + 0.04) + out * 0.01, (along * 0.05 + out * 0.05).abs() + Vector3(0, high - 0.1, 0), Vector3.ZERO, flags)
	# The glass, a pane to a door.
	for i in doors:
		var at := from + along * (length * (i + 0.5) / doors) + Vector3.UP * (high * 0.5 + 0.04) + out * 0.01
		var pane := (along * (length / doors - 0.06) + out * 0.012).abs() + Vector3(0, high - 0.14, 0)
		box("glass", at, pane, Vector3.ZERO, GLASS | NO_COLLIDE)
	box("shop_dark", from + along * length * 0.5 + Vector3.UP * 0.2, (along * length + out * 0.05).abs() + Vector3(0, 0.05, 0), Vector3.ZERO, flags)
	box("shop_dark", from + along * length * 0.5 + Vector3.UP * (high + 0.0), (along * length + out * 0.05).abs() + Vector3(0, 0.05, 0), Vector3.ZERO, flags)
	goods_face(mid + out * (deep * 0.5 - 0.22), (along * (length - 0.1) + out * 0.2).abs() + Vector3(0, high - 0.2, 0))


## An open cold case along a wall, from `wall_from` to `wall_to`: stepped
## shelves that lean back, with a strip of light above, full of `mix`, a list
## per step from the front up.
func cold_case(wall_from: Vector3, wall_to: Vector3, out: Vector3, mix: Array, facings := 3) -> void:
	var deep := 1.1
	var high := 2.0
	var from := wall_from + out * deep
	var to := wall_to + out * deep
	var length := from.distance_to(to)
	var along := (to - from).normalized()
	var flags := DETAIL | NO_COLLIDE
	var mid := (from + to) * 0.5
	var yaw_box := func(size: Vector3) -> Vector3: return (along * size.x + out * size.z).abs() + Vector3(0, size.y, 0)
	_collide_box(Transform3D(Basis(), mid - out * (deep * 0.5 + 0.2) + Vector3.UP * high * 0.5), yaw_box.call(Vector3(length, high, deep - 0.4)), "metal")
	_collide_box(Transform3D(Basis(), mid - out * 0.12 + Vector3.UP * 0.45), yaw_box.call(Vector3(length, 0.9, 0.3)), "metal")
	box("shop_steel", mid - out * 0.02 + Vector3.UP * 0.4, yaw_box.call(Vector3(length, 0.8, 0.05)), Vector3.ZERO, flags)
	box("shop_dark", mid + Vector3.UP * 0.07 + out * 0.006, yaw_box.call(Vector3(length, 0.14, 0.012)), Vector3.ZERO, flags)
	box("shop_steel", mid - out * deep + Vector3.UP * (high * 0.5), yaw_box.call(Vector3(length, high, 0.06)), Vector3.ZERO, flags)
	box("shop_steel", mid - out * (deep * 0.72) + Vector3.UP * (high + 0.03), yaw_box.call(Vector3(length, 0.06, deep * 0.6)), Vector3.ZERO, flags)
	box("shop_cool", mid - out * (deep * 0.5) + Vector3.UP * (high - 0.01), yaw_box.call(Vector3(length - 0.1, 0.03, 0.1)), Vector3.ZERO, flags)
	for step in mix.size():
		var y := 0.82 + step * 0.26
		var back := 0.1 + step * 0.26
		box("shop_rail", mid - out * (back + 0.16) + Vector3.UP * (y - 0.02), yaw_box.call(Vector3(length, 0.03, 0.34)), Vector3.ZERO, flags)
		var a := from - out * back + along * 0.03 + Vector3.UP * y
		var b := to - out * back - along * 0.03 + Vector3.UP * y
		shelf_line(a, b, out, mix[step], facings, 0.3, 0.26, 2)
	goods_face(mid - out * 0.3 + Vector3.UP * 1.25, yaw_box.call(Vector3(length - 0.1, 1.0, 0.25)))


## A board with a drawn sign on it (see SIGNS in tools/gen_goods.py) on both
## sides, as wide as `width`, facing along `normal`. It hangs from `ceiling`
## if that is given.
func shop_board(sign_id: String, center: Vector3, normal: Vector3, width: float, ceiling := NAN, both := true) -> void:
	var cell: Array = _sign_cell(sign_id)
	var high: float = width / cell[4]
	var across := normal.cross(Vector3.UP).normalized()
	box("shop_steel", center, (across * (width + 0.02) + normal * 0.03).abs() + Vector3(0, high + 0.02, 0), Vector3.ZERO, DETAIL | NO_COLLIDE)
	for side: float in ([1.0, -1.0] if both else [1.0]):
		var out := normal * side
		var right := Vector3.UP.cross(out).normalized()
		var mid := center + out * 0.018
		var up := Vector3.UP * high * 0.5
		var wide := right * width * 0.5
		var st := _tool("shop_signs", DETAIL, center)
		var uv := Rect2(cell[0], cell[1], cell[2], cell[3])
		_quad(st, [mid - wide - up, mid + wide - up, mid + wide + up, mid - wide + up], [out, out, out, out],
			[uv.position + Vector2(0, uv.size.y), uv.end, uv.position + Vector2(uv.size.x, 0), uv.position])
	if not is_nan(ceiling):
		for s: float in [-0.42, 0.42]:
			cylinder("shop_steel", center + across * width * s + Vector3.UP * high * 0.5, 0.007, ceiling - center.y - high * 0.5, DETAIL | NO_COLLIDE, Vector3.ZERO, -1.0, 6)


## The sign over an aisle, reading from both ends of it.
func aisle_sign(sign_id: String, at: Vector3, width: float, y: float, ceiling: float) -> void:
	shop_board(sign_id, Vector3(at.x, y, at.z), Vector3.RIGHT, width, ceiling)


static var _signs := {}


func _sign_cell(sign_id: String) -> Array:
	if _signs.is_empty():
		_signs = JSON.parse_string(FileAccess.get_file_as_string("res://assets/goods/signs.json"))
	if not _signs.has(sign_id):
		push_error("No sign called %s: see SIGNS in tools/gen_goods.py" % sign_id)
		return [0.0, 0.0, 0.1, 0.1, 4.0]
	return _signs[sign_id]


## A thin strip painted on the ground from `from` to `to`.
func ground_line(from: Vector2, to: Vector2, width := 0.12, mat := "paint_white") -> void:
	var a := Vector3(from.x, 0.012, from.y)
	var b := Vector3(to.x, 0.012, to.y)
	var mid := (a + b) * 0.5
	var along := (b - a)
	var flat := Transform3D(Basis(Vector3.UP, atan2(along.x, along.z)), mid)
	_box(mat, flat, Vector3(width, 0.004, along.length()), DETAIL | NO_COLLIDE)


## A kerb from `from` to `to` that nobody drives over without noticing.
func lot_kerb(from: Vector2, to: Vector2, high := 0.15, wide := 0.2, mat := "concrete") -> void:
	var a := Vector3(from.x, high * 0.5, from.y)
	var b := Vector3(to.x, high * 0.5, to.y)
	var along := b - a
	_box(mat, Transform3D(Basis(Vector3.UP, atan2(along.x, along.z)), (a + b) * 0.5), Vector3(wide, high, along.length()), DETAIL)
