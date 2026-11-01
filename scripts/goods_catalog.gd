extends RefCounted
## What a supermarket sells: the table tools/gen_goods.py writes, for the game
## and for the level builder. A product has a shape (see
## scripts/goods_shapes.gd), a size in metres as it stands on a shelf, what it
## is made of (the `stuff`, which says how it breaks, see scripts/goods.gd), a
## cell of the sheet of labels, and what comes out of it, if anything.

const TABLE := "res://assets/goods/goods.json"

static var _products := {}
static var _ids: Array[String] = []
static var across := 16


static func _read() -> void:
	if not _ids.is_empty():
		return
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
	across = int(table.across)
	_products = table.products
	_ids.resize(_products.size())
	for id: String in _products:
		var product: Dictionary = _products[id]
		var size: Array = product.size
		product.size = Vector3(size[0], size[1], size[2])
		product.liquid = Color(product.liquid) if product.has("liquid") else Color.WHITE
		product.cell = int(product.cell)
		_ids[product.cell] = id


static func product(id: String) -> Dictionary:
	_read()
	if not _products.has(id):
		push_error("Nothing called %s is on sale" % id)
		return {}
	return _products[id]


## The number a product goes by in the list of what stands on the shelves.
static func index(id: String) -> int:
	return product(id).cell


static func at(index_of: int) -> Dictionary:
	_read()
	return _products[_ids[index_of]]


static func count() -> int:
	_read()
	return _ids.size()
