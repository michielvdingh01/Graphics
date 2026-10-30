extends "res://tools/model_builder.gd"
## Small things that are thrown about or picked up. Build with
## tools/build_model.sh props; look at one with
## tools/benchmark.sh --quick --spawn="res://scenes/models/grenade.scn@2,1,0,0,8".


func _describe() -> void:
	_grenade()
	_stick_grenade()
	_smoke_grenade()
	_cell()
	_ammo_can()


## What mends the player: a canister a hand long with a window down its side
## that glows green. The part Glow is the window, for whoever wants to light it.
func _cell() -> void:
	model("cell")
	_bar("gun_bare", Vector3(0, -0.07, 0), Vector3(0, 0.07, 0), 0.036, 20)
	for end: float in [-1.0, 1.0]:
		_bar("robot_frame", Vector3(0, end * 0.07, 0), Vector3(0, end * 0.1, 0), 0.043, 20)
		_ring("rubber", Vector3(0, end * 0.085, 0), Vector3.UP, 0.044, 0.004)
	_bar("robot_frame", Vector3(0, 0.1, 0), Vector3(0, 0.116, 0), 0.02, 12)
	_bar("gun_bare", Vector3(-0.022, 0.123, 0), Vector3(0.022, 0.123, 0), 0.006, 8)
	part("Glow")
	_bar("tritium", Vector3(0, -0.058, 0), Vector3(0, 0.058, 0), 0.0375, 20)
	part("Body")
	# Four ribs over the window, so that it is a window and not a lamp.
	for i in 4:
		var out := Vector3(cos(TAU * i / 4.0), 0, sin(TAU * i / 4.0)) * 0.038
		_bar("robot_frame", out + Vector3(0, -0.07, 0), out + Vector3(0, 0.07, 0), 0.006, 6)


## What fills the player's pockets: a steel ammunition can with its lid
## thrown back and a belt of brass showing.
func _ammo_can() -> void:
	model("ammo_can")
	_block("robot_olive", Vector3(0, 0.07, 0), Vector3(0.26, 0.14, 0.12), 0.008)
	_block("robot_frame", Vector3(0, 0.145, 0), Vector3(0.27, 0.012, 0.13), 0.004)
	_block("steel_yellow", Vector3(0, 0.08, 0.0605), Vector3(0.2, 0.03, 0.002), 0.0005)
	_block("steel_yellow", Vector3(0, 0.08, -0.0605), Vector3(0.2, 0.03, 0.002), 0.0005)
	# The lid, open on its hinge, and the handle on top of it.
	_block("robot_olive", Vector3(0, 0.2, -0.085), Vector3(0.26, 0.012, 0.12), 0.004, Vector3(-68, 0, 0))
	_line("gun_bare", [Vector3(-0.06, 0.2, -0.094), Vector3(-0.06, 0.2, -0.118), Vector3(0.06, 0.2, -0.118), Vector3(0.06, 0.2, -0.094)], 0.004)
	for end: float in [-1.0, 1.0]:
		_block("gun_bare", Vector3(end * 0.134, 0.1, 0), Vector3(0.006, 0.05, 0.03), 0.002)
	# A row of cartridges, points up.
	for i in 9:
		var x := -0.1 + i * 0.025
		_bar("brass", Vector3(x, 0.14, 0.01), Vector3(x, 0.172, 0.01), 0.0085, 8)
		_turned("gun_bare", Vector3(x, 0.172, 0.01), Vector3.UP, [Vector2(0.0075, 0), Vector2(0.006, 0.012), Vector2(0, 0.022)], 8)


## The stick grenade of 1944 as it flies, its cap off and its cord pulled: a
## can of sheet steel 70 mm across on a handle of wood, 365 mm in all, with a
## collar of steel where the two meet, a clip on the can to hang it from a
## belt, and out of the hollow end of the handle the cord with its porcelain
## bead. Along +Y, the can up; the origin is about where it balances, which is
## where it turns about as it flies end over end.
func _stick_grenade() -> void:
	model("stick_grenade")
	# The can: a little domed, its top rolled over, a seam round either end.
	_turned("robot_olive", Vector3(0, 0.07, 0), Vector3.UP, [
		Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.035, 0.005), Vector2(0.035, 0.089), Vector2(0.0335, 0.094),
		Vector2(0.026, 0.097), Vector2(0.0, 0.099),
	], 28)
	for at: float in [0.075, 0.157]:
		_ring("robot_olive", Vector3(0, at, 0), Vector3.UP, 0.035, 0.0013)
	# The clip for a belt, riveted on at its foot.
	_block("gun_steel", Vector3(0, 0.12, 0.0365), Vector3(0.011, 0.064, 0.0025), 0.0008)
	_block("gun_steel", Vector3(0, 0.088, 0.0375), Vector3(0.013, 0.008, 0.005), 0.001)
	_bar("gun_bare", Vector3(0, 0.088, 0.039), Vector3(0, 0.088, 0.041), 0.0022, 8)
	# The collar the handle screws into, flared where it meets the can.
	_turned("gun_steel", Vector3(0, 0.044, 0), Vector3.UP, [
		Vector2(0.0, 0.0), Vector2(0.0165, 0.0), Vector2(0.0175, 0.003), Vector2(0.0175, 0.019), Vector2(0.024, 0.024), Vector2(0.03, 0.026), Vector2(0.0, 0.026),
	], 20)
	# The handle, a little fuller towards the can, with the threaded band of
	# its cap at the hollow end.
	_turned("gun_walnut", Vector3(0, -0.2, 0), Vector3.UP, [
		Vector2(0.0085, 0.0), Vector2(0.0145, 0.0), Vector2(0.015, 0.004), Vector2(0.0162, 0.244), Vector2(0.0, 0.244),
	], 16)
	_turned("gun_bare", Vector3(0, -0.2, 0), Vector3.UP, [Vector2(0.0158, -0.001), Vector2(0.0158, 0.014), Vector2(0.0148, 0.016)], 16)
	# The cord out of the end, and its bead.
	_line("cord", [Vector3(0, -0.19, 0), Vector3(0, -0.203, 0), Vector3(0.005, -0.218, 0.002), Vector3(0.011, -0.233, -0.002), Vector3(0.013, -0.245, 0.0)], 0.0012, 6)
	_ball("porcelain", Vector3(0.013, -0.254, 0.0), 0.0085)


## A smoke grenade as it flies, pin pulled and lever gone: a tin of sheet steel
## 64 mm across and 115 mm high, its seams rolled over, a yellow band for what
## is in it and the holes in its lid that the smoke comes out of, with the
## fuze of the fragmentation grenade screwed into the middle. Along +Y, the
## origin in its middle.
func _smoke_grenade() -> void:
	model("smoke_grenade")
	_turned("robot_olive", Vector3(0, -0.0575, 0), Vector3.UP, [
		Vector2(0.0, 0.0), Vector2(0.0295, 0.0), Vector2(0.032, 0.0025), Vector2(0.032, 0.1125), Vector2(0.0295, 0.115), Vector2(0.0, 0.115),
	], 24)
	for at: float in [-0.054, 0.054]:
		_ring("robot_olive", Vector3(0, at, 0), Vector3.UP, 0.032, 0.0014)
	_ring("steel_yellow", Vector3(0, 0.012, 0), Vector3.UP, 0.0322, 0.0045)
	for i in 6:
		var out := Vector3(cos(TAU * i / 6.0), 0, sin(TAU * i / 6.0)) * 0.021
		_bar("gun_bare", out + Vector3(0, 0.0568, 0), out + Vector3(0, 0.0578, 0), 0.0035, 8)
	_turned("gun_steel", Vector3(0, 0.0575, 0), Vector3.UP, [
		Vector2(0.0125, 0), Vector2(0.0125, 0.006), Vector2(0.009, 0.008), Vector2(0.009, 0.02), Vector2(0.0075, 0.022), Vector2(0, 0.022),
	], 16)


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
