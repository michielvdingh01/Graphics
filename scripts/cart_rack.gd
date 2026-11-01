extends Area3D
## A rack for shopping carts in a parking lot. A cart that is pushed into it
## rolls to the end of the line and stays there, nested in the one before: see
## scripts/cart.gd. The first cart goes to the far end. Each that comes home is
## counted, and the HUD says so. The host decides: a cart that a guest pushes
## in goes when the host sees it there.

## How long it is, in metres, and how much room a nested cart takes.
@export var long := 8.0
const NESTED := 0.3
const TINT := Color(1.0, 0.85, 0.4)

## How many carts are home, in all the racks of a level.
static var home := 0

var _filled := 0


func _ready() -> void:
	home = 0
	add_to_group(&"cart_rack")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if Net.is_guest() or not body.has_method("go_home") or body.home:
		return
	Net.show(self, &"_take", [get_path_to(body)])


func _take(path: NodePath) -> void:
	var cart := get_node_or_null(path)
	if cart == null or cart.home:
		return
	var spot := global_position + Vector3(0, -0.47, long * 0.5 - 0.6 - NESTED * _filled)
	_filled += 1
	home += 1
	cart.go_home(spot, PI)
	var carts := get_tree().get_nodes_in_group(&"cart").size()
	var game := get_tree().get_first_node_in_group(&"game")
	if game:
		game.picked_up.emit("CART RETURNED  %d / %d" % [home, carts] if home < carts else "ALL CARTS RETURNED  -  EMPLOYEE OF THE MONTH", TINT)
