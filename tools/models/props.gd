extends "res://tools/model_builder.gd"
## Small things that are thrown about. Build with tools/build_model.sh props;
## look at one with
## tools/benchmark.sh --quick --spawn="res://scenes/models/grenade.scn@2,1,0,0,8".


func _describe() -> void:
	_grenade()


## Fragmentation grenade as it flies, pin pulled and lever gone: a steel ball
## 64 mm across with a seam around its middle and the fuze screwed into the top.
func _grenade() -> void:
	model("grenade")
	var body := PackedVector2Array()
	for i in 13:
		var angle := PI * (i / 12.0 - 0.5)
		body.append(Vector2(cos(angle), sin(angle)) * 0.032)
	_turned("robot_olive", Vector3.ZERO, Vector3.UP, body, 24, true)
	_ring("robot_olive", Vector3.ZERO, Vector3.UP, 0.0316, 0.0014)
	_turned("gun_steel", Vector3(0, 0.029, 0), Vector3.UP, [
		Vector2(0.0125, 0), Vector2(0.0125, 0.008), Vector2(0.009, 0.01), Vector2(0.009, 0.024), Vector2(0.0075, 0.026), Vector2(0, 0.026),
	], 16)
	# The ears the lever hinged on, and the striker between them.
	for side: float in [-1.0, 1.0]:
		_block("gun_steel", Vector3(side * 0.006, 0.057, 0.003), Vector3(0.0025, 0.008, 0.012), 0.001)
	_bar("gun_bare", Vector3(-0.006, 0.058, 0.005), Vector3(0.006, 0.058, 0.005), 0.0016, 8)
