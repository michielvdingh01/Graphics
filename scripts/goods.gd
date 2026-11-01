extends StaticBody3D
## Everything on sale in a shop, and what becomes of it when it is shot.
##
## A shop holds tens of thousands of things, and each can go on its own. That
## is not tens of thousands of nodes: what stands on the shelves is drawn as
## MultiMeshes, a shape to a block of the floor, and only what has been hit
## becomes something that moves. This body is the one the shots land on: it
## has a box in front of every shelf and over every heap, on the layer that
## shots look for what breaks on, and scripts/weapons.gd and scripts/blast.gd
## find it by its take_damage() and take_blast() like any stack of crates.
##
## What a shot does to a thing depends on what the thing is made of, its
## `stuff`, see BREAKS. What it hit goes to pieces. What stood next to it falls
## off the shelf, whole, and hits the floor: a bottle of glass breaks there, a
## can rolls, a box stays lying. Whatever stood on what went comes down.
##
## What is on the floor stays there, up to a number: the pieces go round a
## ring (Pool), the oldest making way. The floor is level and nothing walks on
## what lies there. Bottles spill: scripts/fx.gd lays the puddle.
##
## Which things go is worked out from where the shot landed alone, so it comes
## out the same on every machine; how the pieces fly is each machine's own.

const CATALOG := preload("res://scripts/goods_catalog.gd")
const SHAPES := preload("res://scripts/goods_shapes.gd")
const DATA := preload("res://scripts/goods_data.gd")
const SHADER := preload("res://shaders/goods.gdshader")
const LABELS := "res://assets/goods/goods_atlas.jpg"

## The layer shots look for what breaks on, see scripts/breakables.gd.
const BREAKABLE := 32
## How large a block of the floor is that shares a mesh, in metres, and from
## how far off a block is drawn in the cheaper forms of its shapes.
const BLOCK := 6.0
const NEAR_UNTIL := 12.0
const NEAR_MARGIN := 1.0
## Numbers per thing in the buffer of a MultiMesh: its transform, its colour
## and its custom data.
const BUFFER_STRIDE := 20
## How large the cells are in which things are looked up by where they stand,
## in metres. Nothing on sale is larger than twice this.
const GRID := 0.5
## A shot takes what is this near where it landed, in metres, and shakes down
## what is SHAKEN times as near. It reaches this far into a shelf.
const SHOT_LEAST := 0.09
const SHOT_MOST := 0.26
const SHAKEN := 2.4
const SHOT_INTO := 0.2
## The damage of a shot that takes the most.
const SHOT_FULL := 90.0
## What a blast takes for every point of its damage, in metres, and the most.
const BLAST_REACH := 0.02
const BLAST_MOST := 3.2
## The most things that fall or burst at once from one shot or one blast: the
## rest go without a piece flying, in the dust of the others.
const MOST_AT_ONCE := 90
## How many pieces can fly at once.
const MOST_FLYING := 700
const GRAVITY := 9.8
## What is left of a piece's speed along the floor and upward after it bounces.
const BOUNCE_ALONG := 0.55
const BOUNCE_UP := 0.32
## Slower than this over the floor it stays where it is, in m/s.
const STILL := 0.6
const WHOLE_LEFT := 260
const LEFT := {"scrap": 1400, "chunk": 900, "shard": 900, "drop": 500}
## The cell of the sheet of labels that is plain white.
const WHITE_CELL := 255.0
const SHINY_GLASS := 0.95
const GLASS_TINT := Color(0.8, 0.9, 0.86)
## Sounds, by the name goods_<name>: not more of one than this often, in seconds.
const HEARD_EVERY := 0.05
## What a vehicle takes along: how often that is looked at, from what speed on
## in m/s, and what of the things round it, in its own coordinates.
const SCRAPE_EVERY := 0.1
const SCRAPES_FROM := 2.5
const SCRAPES := AABB(Vector3(-1.5, 0.0, -3.0), Vector3(3.0, 2.4, 6.0))

## How each stuff goes to pieces: what flies (`piece`), how many, how large
## next to the thing itself, how many drops of what is in it, how large a
## puddle it leaves in metres, and what is heard. `breaks` is for what does not
## survive falling either.
const BREAKS := {
	"pop": {"piece": "scrap", "pieces": 3, "large": 0.5, "drops": 9, "spill": 0.55, "sound": &"goods_plastic"},
	"glass": {"piece": "shard", "pieces": 9, "large": 0.42, "drops": 7, "spill": 0.42, "sound": &"goods_glass", "breaks": true},
	"can": {"piece": "scrap", "pieces": 2, "large": 0.4, "drops": 7, "spill": 0.3, "sound": &"goods_can"},
	"card": {"piece": "scrap", "pieces": 6, "large": 0.42, "drops": 7, "spill": 0.0, "sound": &"goods_card"},
	"bag": {"piece": "scrap", "pieces": 4, "large": 0.42, "drops": 12, "spill": 0.0, "sound": &"goods_bag"},
	"jug": {"piece": "scrap", "pieces": 3, "large": 0.5, "drops": 16, "spill": 0.85, "sound": &"goods_plastic"},
	"soft": {"piece": "scrap", "pieces": 6, "large": 0.4, "drops": 0, "spill": 0.0, "sound": &"goods_card"},
	"produce": {"piece": "chunk", "pieces": 5, "large": 0.42, "drops": 4, "spill": 0.14, "sound": &"goods_splat"},
	"meat": {"piece": "chunk", "pieces": 5, "large": 0.34, "drops": 3, "spill": 0.22, "sound": &"goods_splat"},
	"cheese": {"piece": "chunk", "pieces": 6, "large": 0.34, "drops": 0, "spill": 0.0, "sound": &"goods_splat"},
}
## What is not hit but falls, by stuff: heard when it lands.
const LANDS := {"can": &"goods_can", "pop": &"goods_plastic", "jug": &"goods_plastic"}


## Pieces of one shape that go round a ring: the oldest makes way.
class Pool:
	var multimesh := MultiMesh.new()
	var next := 0

	func take() -> int:
		var slot := next
		next = (next + 1) % multimesh.instance_count
		return slot

	func hide_piece(slot: int) -> void:
		multimesh.set_instance_transform(slot, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))


## Something that flies.
class Piece:
	var pool: Pool
	var slot := 0
	## Where its middle is, and how it stands.
	var at := Vector3.ZERO
	var turn := Basis()
	var size := Vector3.ONE
	var velocity := Vector3.ZERO
	var axis := Vector3.UP
	var rate := 0.0
	var bounces := 0
	## What it is when it lands: -1 for a piece of something else.
	var product := -1
	var fades := false
	var spills := 0.0
	var tint := Color.WHITE


## What stands in the level, see scripts/goods_data.gd.
@export var data: DATA

var _items := PackedFloat32Array()
## Per thing: how it is drawn, and whether it has gone.
var _mesh_of := PackedInt32Array()
var _slot_of := PackedInt32Array()
var _gone := PackedByteArray()
var _meshes: Array[MultiMesh] = []
## The cheaper form of each of those, or null.
var _far_meshes: Array[MultiMesh] = []
## What stands where, by the cell of the grid: the numbers of the things.
var _grid := {}
## What stands on a thing, by the number of that thing.
var _on := {}
var _pools := {}
var _whole := {}
var _flying: Array[Piece] = []
var _material: ShaderMaterial
var _heard := {}
var _count := 0
## How many have gone, and which, for those who join later.
var _taken := PackedInt32Array()
var _scrape := 0.0
## Where there is anything to scrape: around what is on sale.
var _shop := AABB()


func _ready() -> void:
	add_to_group(&"goods")
	collision_layer = BREAKABLE
	collision_mask = 0
	if data == null:
		push_warning("Goods: nothing on sale")
		set_process(false)
		return
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter(&"labels", load(LABELS))
	_material.set_shader_parameter(&"across", float(CATALOG.across))
	_items = data.items
	_count = _items.size() / DATA.STRIDE
	_mesh_of.resize(_count)
	_slot_of.resize(_count)
	_gone.resize(_count)
	_gone.fill(0)
	_lay_out()
	_make_pools()
	set_process(false)


## How many things are left on the shelves.
func left() -> int:
	return _count - _taken.size()


func count() -> int:
	return _count


## Whether a thing has gone.
func gone(index: int) -> bool:
	return _gone[index] != 0


## The number of the first thing still there of `product`, or -1.
func first_of(product: String) -> int:
	var wanted := CATALOG.index(product)
	for i in _count:
		if not _gone[i] and int(_items[i * DATA.STRIDE + 4]) == wanted:
			return i
	return -1


## Where the middle of a thing is.
func middle_of(index: int) -> Vector3:
	var at := index * DATA.STRIDE
	return Vector3(_items[at], _items[at + 1], _items[at + 2])


func take_damage(amount: float, at: Vector3, direction: Vector3) -> bool:
	Net.show(self, &"_shot", [at, direction.normalized(), amount])
	return false


func take_blast(amount: float, at: Vector3, push: Vector3) -> void:
	Net.show(self, &"_blown", [at, push, amount])


## A way for a vehicle to go through a shelf: everything inside `box`, which is
## turned by `frame`, comes down, thrown along `push`.
func brush(frame: Transform3D, box: AABB, push: Vector3) -> void:
	Net.show(self, &"_brushed", [frame, box, push])


## What was taken, for someone who comes into the level later.
func net_taken() -> PackedInt32Array:
	return _taken


func net_take(taken: PackedInt32Array) -> void:
	for i in taken:
		_take(i)


func _shot(at: Vector3, direction: Vector3, amount: float) -> void:
	var reach := remap(clampf(amount, 0.0, SHOT_FULL), 0.0, SHOT_FULL, SHOT_LEAST, SHOT_MOST)
	var middle := at + direction * SHOT_INTO
	var hit := _near(middle, reach)
	if hit.is_empty():
		# Nothing there any more: it goes on to the back of the shelf.
		Fx.strike(at + direction * 0.3, -direction, direction, "metal", true)
		return
	var done := 0
	for i in hit:
		_burst(i, direction, done < 4)
		done += 1
	for i in _near(middle, reach * SHAKEN):
		if not _gone[i]:
			_fall(i, direction * 1.2 + _away(middle, i) * 0.8)


func _blown(at: Vector3, push: Vector3, amount: float) -> void:
	var reach := minf(amount * BLAST_REACH, BLAST_MOST)
	var out := _near(at, reach)
	var flown := 0
	for i in out:
		var from := _away(at, i)
		var near: float = at.distance_to(middle_of(i)) / reach
		if flown >= MOST_AT_ONCE:
			_take(i)
		elif near < 0.55:
			_burst(i, from, flown < 6)
		else:
			_fall(i, from * 4.0 * (1.0 - near) + push * 0.2)
		flown += 1


func _brushed(frame: Transform3D, box: AABB, push: Vector3) -> void:
	var back := frame.affine_inverse()
	var middle := frame * box.get_center()
	var flown := 0
	for i in _near(middle, box.size.length() * 0.5):
		if box.has_point(back * middle_of(i)):
			if flown < MOST_AT_ONCE:
				_fall(i, push * randf_range(0.3, 0.8) + Vector3.UP * randf_range(0.2, 1.5))
			else:
				_take(i)
			flown += 1


## The things within `reach` of `at`.
func _near(at: Vector3, reach: float) -> PackedInt32Array:
	var found := PackedInt32Array()
	var lowest := Vector3i(((at - Vector3.ONE * (reach + GRID)) / GRID).floor())
	var highest := Vector3i(((at + Vector3.ONE * (reach + GRID)) / GRID).floor())
	var within := reach * reach
	for x in range(lowest.x, highest.x + 1):
		for y in range(lowest.y, highest.y + 1):
			for z in range(lowest.z, highest.z + 1):
				var cell: Variant = _grid.get(Vector3i(x, y, z))
				if cell == null:
					continue
				for i: int in cell:
					if _gone[i]:
						continue
					var base := i * DATA.STRIDE
					var dx := _items[base] - at.x
					var dy := _items[base + 1] - at.y
					var dz := _items[base + 2] - at.z
					if dx * dx + dy * dy + dz * dz <= within + _radius(i):
						found.append(i)
	return found


## How far a thing reaches from its middle, squared, for what is large.
func _radius(index: int) -> float:
	var size: Vector3 = CATALOG.at(int(_items[index * DATA.STRIDE + 4])).size
	return minf(minf(size.x, size.z), size.y) ** 2 * 0.25


func _away(from: Vector3, index: int) -> Vector3:
	return (middle_of(index) - from).normalized()


## Takes a thing off its shelf: it is no longer drawn there, and what stood
## on it comes down.
func _take(index: int) -> void:
	if _gone[index]:
		return
	_gone[index] = 1
	_taken.append(index)
	var nothing := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	_meshes[_mesh_of[index]].set_instance_transform(_slot_of[index], nothing)
	if _far_meshes[_mesh_of[index]]:
		_far_meshes[_mesh_of[index]].set_instance_transform(_slot_of[index], nothing)
	var above: Variant = _on.get(index)
	if above != null:
		for i: int in above:
			_fall(i, Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4)))


## A thing goes to pieces where it stands, or in the air: `aimed` is the way
## it was hit from.
func _burst(index: int, aimed: Vector3, loud: bool) -> void:
	var product := CATALOG.at(int(_items[index * DATA.STRIDE + 4]))
	var at := middle_of(index)
	_take(index)
	_shatter(at, product, aimed)
	if loud:
		_hear(BREAKS[product.stuff].sound, at)
	# What was in it runs down the shelf to the floor.
	var spill: float = BREAKS[product.stuff].spill
	if spill > 0.0 and loud:
		_spill(at, product.liquid, spill)


## Throws out the pieces of something at `at`.
func _shatter(at: Vector3, product: Dictionary, aimed: Vector3) -> void:
	var how: Dictionary = BREAKS[product.stuff]
	var size: Vector3 = product.size
	var across := pow(size.x * size.y * size.z, 1.0 / 3.0)
	var shape: String = how.piece
	var cell: float = WHITE_CELL if shape == "shard" else float(product.cell)
	var tint: Color = GLASS_TINT if shape == "shard" else Color.WHITE
	var shiny: float = SHINY_GLASS if shape == "shard" else product.shiny
	for i in int(how.pieces):
		_throw(shape, at, Vector3.ONE * across * float(how.large) * randf_range(0.7, 1.3), _spray(aimed, 2.4), cell, shiny, tint, false)
	var drop: Color = product.liquid
	for i in int(how.drops):
		_throw("drop", at, Vector3.ONE * randf_range(0.012, 0.03), _spray(aimed, 3.6), WHITE_CELL, 0.8, drop, true)


## A way out from what was hit, with something of the way it was hit in it.
func _spray(aimed: Vector3, speed: float) -> Vector3:
	var out := Vector3(randf_range(-1.0, 1.0), randf_range(-0.2, 1.0), randf_range(-1.0, 1.0))
	return (aimed * 1.1 + out).normalized() * speed * randf_range(0.4, 1.0)


func _throw(shape: String, at: Vector3, size: Vector3, velocity: Vector3, cell: float, shiny: float, tint: Color, fades: bool) -> void:
	if _flying.size() >= MOST_FLYING:
		return
	var pool: Pool = _pools[shape]
	var piece := Piece.new()
	piece.pool = pool
	piece.slot = pool.take()
	piece.at = at
	piece.size = size
	piece.turn = Basis(Vector3(randf(), randf(), randf()).normalized(), randf() * TAU)
	piece.velocity = velocity
	piece.axis = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
	piece.rate = randf_range(4.0, 18.0)
	piece.fades = fades
	pool.multimesh.set_instance_custom_data(piece.slot, Color(cell, 1.0, shiny, 0.0))
	pool.multimesh.set_instance_color(piece.slot, tint)
	_flying.append(piece)
	set_process(true)


## A thing is knocked off where it stands and falls, whole.
func _fall(index: int, push: Vector3) -> void:
	if _gone[index]:
		return
	var base := index * DATA.STRIDE
	var number := int(_items[base + 4])
	var product := CATALOG.at(number)
	var at := middle_of(index)
	var turn := _turn_of(base)
	_take(index)
	if _flying.size() >= MOST_FLYING:
		return
	var pool: Pool = _whole[product.shape]
	var piece := Piece.new()
	piece.pool = pool
	piece.slot = pool.take()
	piece.at = at
	piece.turn = turn
	piece.size = product.size
	piece.velocity = push + Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.6), randf_range(-0.3, 0.3))
	piece.axis = Vector3(randf_range(-1, 1), randf_range(-0.2, 0.2), randf_range(-1, 1)).normalized()
	piece.rate = randf_range(3.0, 9.0)
	piece.product = number
	piece.tint = Color(1, 1, 1)
	pool.multimesh.set_instance_custom_data(piece.slot, Color(float(product.cell), _items[base + 6], product.shiny, 0.0))
	pool.multimesh.set_instance_color(piece.slot, _tint_of(index, product))
	_flying.append(piece)
	set_process(true)


## Whatever drives through a shop takes what it scrapes past with it.
func _physics_process(delta: float) -> void:
	_scrape -= delta
	if _scrape > 0.0 or Net.is_guest():
		return
	_scrape = SCRAPE_EVERY
	for vehicle: Node in get_tree().get_nodes_in_group(&"vehicle"):
		var body := vehicle as RigidBody3D
		if body == null or body.linear_velocity.length() < SCRAPES_FROM:
			continue
		var at := body.global_position
		if not _shop.has_point(at):
			continue
		brush(body.global_transform, SCRAPES, body.linear_velocity)


func _process(delta: float) -> void:
	var i := 0
	while i < _flying.size():
		var piece := _flying[i]
		piece.velocity.y -= GRAVITY * delta
		piece.at += piece.velocity * delta
		if piece.rate > 0.0:
			piece.turn = Basis(piece.axis, piece.rate * delta) * piece.turn
		# How high its middle stands when it touches the floor, as it is turned.
		var stands := absf(piece.turn.x.y) * piece.size.x + absf(piece.turn.y.y) * piece.size.y + absf(piece.turn.z.y) * piece.size.z
		stands *= 0.5
		if piece.at.y - stands <= global_position.y and piece.velocity.y < 0.0 and _landed(piece, stands):
			_flying.remove_at(i)
			continue
		_place(piece)
		i += 1
	if _flying.is_empty():
		set_process(false)


## A piece has reached the floor. True if it has come to rest there, or is no
## more.
func _landed(piece: Piece, stands: float) -> bool:
	if piece.fades:
		piece.pool.hide_piece(piece.slot)
		return true
	if piece.product >= 0:
		var product := CATALOG.at(piece.product)
		if BREAKS[product.stuff].get("breaks", false) or piece.velocity.y < -3.2 and product.stuff == "jug":
			piece.pool.hide_piece(piece.slot)
			var at := Vector3(piece.at.x, global_position.y + 0.05, piece.at.z)
			_shatter(at, product, Vector3.UP)
			_hear(BREAKS[product.stuff].sound, at)
			if BREAKS[product.stuff].spill > 0.0:
				_spill(at, product.liquid, BREAKS[product.stuff].spill)
			return true
		if piece.bounces == 0 and LANDS.has(product.stuff):
			_hear(LANDS[product.stuff], piece.at)
	piece.bounces += 1
	piece.velocity.y *= -BOUNCE_UP
	piece.velocity.x *= BOUNCE_ALONG
	piece.velocity.z *= BOUNCE_ALONG
	piece.rate *= 0.5
	piece.at.y = global_position.y + stands
	if piece.bounces < 3 and Vector3(piece.velocity.x, 0.0, piece.velocity.z).length() + piece.velocity.y > STILL:
		return false
	# It comes to lie on its largest side, turned as far as that takes.
	var low := 0
	for axis in 3:
		if piece.size[axis] < piece.size[low]:
			low = axis
	var side: Vector3 = piece.turn[low].normalized()
	if side.y < 0.0:
		side = -side
	if not side.is_equal_approx(Vector3.UP):
		var across := side.cross(Vector3.UP).normalized()
		piece.turn = Basis(across, side.signed_angle_to(Vector3.UP, across)) * piece.turn
	piece.at.y = global_position.y + piece.size[low] * 0.5
	_place(piece)
	return true


func _place(piece: Piece) -> void:
	var basis := Basis(piece.turn.x * piece.size.x, piece.turn.y * piece.size.y, piece.turn.z * piece.size.z)
	piece.pool.multimesh.set_instance_transform(piece.slot, Transform3D(basis, piece.at - piece.turn.y * piece.size.y * 0.5))


func _spill(at: Vector3, colour: Color, across: float) -> void:
	Fx.spill(Vector3(at.x, global_position.y, at.z), colour, across)


func _hear(sound: StringName, at: Vector3) -> void:
	if Fx.time - _heard.get(sound, -1.0) < HEARD_EVERY:
		return
	_heard[sound] = Fx.time
	Sfx.play_at(sound, at, -2.0)


## Makes the meshes of everything on the shelves, a shape to a block of the
## floor, and the grid that things are looked up in.
func _lay_out() -> void:
	var groups := {}
	for i in _count:
		var base := i * DATA.STRIDE
		var shape: String = CATALOG.at(int(_items[base + 4])).shape
		var at := Vector3(_items[base], _items[base + 1], _items[base + 2])
		_shop = AABB(at, Vector3.ZERO) if i == 0 else _shop.expand(at)
		var key := "%s %d %d" % [shape, floori(at.x / BLOCK), floori(at.z / BLOCK)]
		var group: PackedInt32Array = groups.get(key, PackedInt32Array())
		group.append(i)
		groups[key] = group
		var cell := Vector3i((at / GRID).floor())
		var bucket: PackedInt32Array = _grid.get(cell, PackedInt32Array())
		bucket.append(i)
		_grid[cell] = bucket
		var under := int(_items[base + 7]) - 1
		if under >= 0:
			var above: PackedInt32Array = _on.get(under, PackedInt32Array())
			above.append(i)
			_on[under] = above
	for key: String in groups:
		var group: PackedInt32Array = groups[key]
		var shape := key.get_slice(" ", 0)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.use_custom_data = true
		multimesh.mesh = SHAPES.mesh(shape)
		multimesh.instance_count = group.size()
		var buffer := PackedFloat32Array()
		buffer.resize(group.size() * BUFFER_STRIDE)
		var box := AABB()
		var slot := 0
		for i in group:
			var base := i * DATA.STRIDE
			var product := CATALOG.at(int(_items[base + 4]))
			var turn := _turn_of(base)
			var size: Vector3 = product.size
			var at := Vector3(_items[base], _items[base + 1], _items[base + 2])
			var x := turn.x * size.x
			var y := turn.y * size.y
			var z := turn.z * size.z
			var origin := at - y * 0.5
			var tint := _tint_of(i, product)
			var row := slot * BUFFER_STRIDE
			buffer[row] = x.x
			buffer[row + 1] = y.x
			buffer[row + 2] = z.x
			buffer[row + 3] = origin.x
			buffer[row + 4] = x.y
			buffer[row + 5] = y.y
			buffer[row + 6] = z.y
			buffer[row + 7] = origin.y
			buffer[row + 8] = x.z
			buffer[row + 9] = y.z
			buffer[row + 10] = z.z
			buffer[row + 11] = origin.z
			buffer[row + 12] = tint.r
			buffer[row + 13] = tint.g
			buffer[row + 14] = tint.b
			buffer[row + 15] = 1.0
			buffer[row + 16] = float(product.cell)
			buffer[row + 17] = _items[base + 6]
			buffer[row + 18] = product.shiny
			buffer[row + 19] = 0.0
			_mesh_of[i] = _meshes.size()
			_slot_of[i] = slot
			var reach := Vector3.ONE * size.length()
			var around := AABB(at - reach * 0.5, reach)
			box = around if slot == 0 else box.merge(around)
			slot += 1
		multimesh.buffer = buffer
		_meshes.append(multimesh)
		var instance := _instance(multimesh)
		instance.name = key.replace(" ", "_")
		instance.custom_aabb = box
		add_child(instance)
		var far: MultiMesh = null
		if SHAPES.has_far(shape):
			far = MultiMesh.new()
			far.transform_format = MultiMesh.TRANSFORM_3D
			far.use_colors = true
			far.use_custom_data = true
			far.mesh = SHAPES.far(shape)
			far.instance_count = group.size()
			far.buffer = buffer
			var farther := _instance(far)
			farther.name = instance.name + "_far"
			farther.custom_aabb = box
			farther.visibility_range_begin = NEAR_UNTIL
			farther.visibility_range_begin_margin = NEAR_MARGIN
			instance.visibility_range_end = NEAR_UNTIL
			instance.visibility_range_end_margin = NEAR_MARGIN
			add_child(farther)
		_far_meshes.append(far)


func _instance(multimesh: MultiMesh) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = _material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	return instance


## How a thing stands: 0 upright, 1 lying with its length along the way it
## faces, 2 any way at all, which is how things lie in a heap.
func _turn_of(base: int) -> Basis:
	var facing := Basis(Vector3.UP, _items[base + 3])
	match int(_items[base + 5]):
		1:
			return facing * Basis(Vector3.RIGHT, PI * 0.5)
		2:
			var dice := fmod(_items[base] * 12.9898 + _items[base + 1] * 78.233 + _items[base + 2] * 37.719, 1.0)
			return facing * Basis(Vector3(dice, 1.0 - dice, 0.4 + dice * 0.3).normalized(), dice * TAU * 7.0)
	return facing


## What sets one thing apart from the next of its kind.
func _tint_of(index: int, product: Dictionary) -> Color:
	var dice := float(((index * 2654435761) >> 8) & 0xFF) / 255.0
	var dice2 := float(((index * 40503) >> 4) & 0xFF) / 255.0
	if product.stuff == "produce":
		var value := 0.82 + dice * 0.36
		return Color(value * (0.94 + dice2 * 0.12), value, value * (1.04 - dice2 * 0.12))
	var grey := 0.93 + dice * 0.1
	return Color(grey, grey, grey)


## Makes what pieces are drawn with once they have left the shelf.
func _make_pools() -> void:
	var around := AABB(global_position - Vector3(400, 10, 400), Vector3(800, 40, 800))
	for shape: String in LEFT:
		_pools[shape] = _pool(shape, LEFT[shape], around)
	for i in CATALOG.count():
		var shape: String = CATALOG.at(i).shape
		if not _whole.has(shape):
			_whole[shape] = _pool(shape, WHOLE_LEFT, around)


func _pool(shape: String, size: int, around: AABB) -> Pool:
	var pool := Pool.new()
	pool.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	pool.multimesh.use_colors = true
	pool.multimesh.use_custom_data = true
	pool.multimesh.mesh = SHAPES.mesh(shape)
	pool.multimesh.instance_count = size
	var instance := _instance(pool.multimesh)
	instance.name = "Pieces_" + shape
	instance.custom_aabb = around
	add_child(instance)
	return pool
