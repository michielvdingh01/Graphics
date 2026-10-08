extends SceneTree
## Generates the factory hall level. Run with: tools/build_level.sh
##
## The level is described in code below and written to scenes/levels/ as two
## merged meshes (lightmapped "static" and probe-lit "detail"), one static body
## and the lights and reflection probes that belong to the building. The scene
## that uses it (scenes/factory.tscn) holds everything that is tuned by hand:
## environment, sun, lightmap, spawns and benchmark views.

const OUT_DIR := "res://scenes/levels/"
const NAME := "factory"
## Lightmap texel size in metres.
const TEXEL := 0.08

## Box/cylinder flags.
const DETAIL := 1  # thin or far geometry: no lightmap, lit by probes instead
const NO_COLLIDE := 2

# Hall dimensions (interior faces).
const HX := 20.0
const HZ := 12.0
const EAVES := 8.0
const RIDGE := 10.6
const BAYS: Array[float] = [-16.0, -8.0, 0.0, 8.0, 16.0]
const TRUSSES: Array[float] = [-12.0, -4.0, 4.0, 12.0]
const DECK_Y := 3.2

var _tools := {}
var _shapes := {}
var _root: Node3D
var _body: StaticBody3D
var _lights: Node3D
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 7
	_root = Node3D.new()
	_root.name = "FactoryLevel"
	_body = StaticBody3D.new()
	_body.name = "Collision"
	_add(_body, _root)
	_lights = Node3D.new()
	_lights.name = "Lights"
	_add(_lights, _root)

	_shell()
	_roof()
	_mezzanine()
	_crane()
	_hall_props()
	_annex()
	_exterior()
	_probes()

	_commit("static", true)
	_commit("detail", false)
	var scene := PackedScene.new()
	scene.pack(_root)
	var err := ResourceSaver.save(scene, OUT_DIR + NAME + "_level.tscn")
	print("Saved level: ", error_string(err))
	quit()


# --- Level description -------------------------------------------------------


func _shell() -> void:
	box("floor", Vector3(5.2, -0.25, -0.1), Vector3(52.4, 0.5, 25.8))

	# South wall: tall windows the evening sun comes through.
	var south: Array = []
	for x in BAYS:
		south.append([x - 2.5, x + 2.5, 3.0, 7.0])
		box("concrete", Vector3(x, 2.94, HZ + 0.15), Vector3(5.3, 0.12, 0.7))
		_mullions(Vector3(x, 5.0, HZ + 0.25), 5.0, 4.0, true, 1.0)
	wall("brick", true, HZ + 0.25, 0.5, -HX - 0.5, HX + 0.5, 0.0, EAVES, south)

	# North wall: a strip of clerestory windows above the mezzanine.
	var north: Array = []
	for x in BAYS:
		north.append([x - 1.5, x + 1.5, 5.4, 7.0])
		_mullions(Vector3(x, 6.2, -HZ - 0.25), 3.0, 1.6, true, 1.0)
	wall("brick", true, -HZ - 0.25, 0.5, -HX - 0.5, HX + 0.5, 0.0, EAVES, north)

	# West wall with the closed loading door.
	wall("brick", false, -HX - 0.25, 0.5, -HZ, HZ, 0.0, EAVES, [[-2.5, 2.5, 0.0, 5.0]])
	box("roof", Vector3(-HX - 0.3, 2.5, 0.0), Vector3(0.08, 5.0, 5.0))
	for z in [-2.6, 2.6]:
		box("steel", Vector3(-HX - 0.05, 2.6, z), Vector3(0.2, 5.2, 0.2))
	box("steel", Vector3(-HX - 0.05, 5.1, 0.0), Vector3(0.2, 0.25, 5.4))
	for y in [0.9, 1.8, 2.7, 3.6, 4.5]:
		box("steel", Vector3(-HX - 0.24, y, 0.0), Vector3(0.04, 0.05, 5.0), Vector3.ZERO, DETAIL | NO_COLLIDE)

	# East wall: two doorways into the annex and windows above its roof.
	var east: Array = [[-10.0, -8.0, 0.0, 2.6], [-3.0, 0.0, 0.0, 3.0], [-9.5, -4.5, 5.2, 7.0], [4.5, 9.5, 3.0, 7.0]]
	wall("brick", false, HX + 0.25, 0.5, -HZ, HZ, 0.0, EAVES, east)
	_mullions(Vector3(HX + 0.25, 6.1, -7.0), 5.0, 1.8, false, 1.0)
	_mullions(Vector3(HX + 0.25, 5.0, 7.0), 5.0, 4.0, false, 1.0)
	box("concrete", Vector3(HX + 0.15, 2.94, 7.0), Vector3(0.7, 0.12, 5.3))
	box("steel", Vector3(HX + 0.25, 2.68, -9.0), Vector3(0.56, 0.16, 2.4))
	box("steel", Vector3(HX + 0.25, 3.08, -1.5), Vector3(0.56, 0.16, 3.4))

	# Gable ends.
	var gable := PackedVector2Array([Vector2(-HZ - 0.5, EAVES), Vector2(HZ + 0.5, EAVES), Vector2(0, RIDGE)])
	var side := Basis(Vector3(0, 0, -1), Vector3.UP, Vector3.RIGHT)
	for x in [-HX - 0.25, HX + 0.25]:
		extrude("brick", gable, 0.5, Transform3D(side, Vector3(x, 0, 0)))

	# Concrete plinth, pilasters and the corbels that carry the crane rails.
	for z in [-HZ, HZ]:
		var inward: float = -signf(z)
		box("concrete", Vector3(0, 0.5, z + inward * 0.04), Vector3(HX * 2.0, 1.0, 0.08), Vector3.ZERO, NO_COLLIDE)
		for x in TRUSSES:
			box("concrete", Vector3(x, EAVES * 0.5, z + inward * 0.2), Vector3(0.7, EAVES, 0.4))
			box("concrete", Vector3(x, 6.05, z + inward * 0.6), Vector3(0.5, 0.5, 0.4), Vector3.ZERO, NO_COLLIDE)
	for x in [-HX, HX]:
		var inward: float = -signf(x)
		for z in [-HZ + 0.35, HZ - 0.35]:
			box("concrete", Vector3(x + inward * 0.2, EAVES * 0.5, z), Vector3(0.4, EAVES, 0.7))


func _roof() -> void:
	var angle := atan2(RIDGE - EAVES, HZ + 0.5)
	var length := Vector2(HZ + 0.5, RIDGE - EAVES).length() + 0.5
	# Local +Z runs down the slope from the ridge; the slab hangs below local Y = 0.
	var slopes: Array[Transform3D] = [
		Transform3D(Basis(Vector3.RIGHT, angle), Vector3(0, RIDGE + 0.2, 0)),
		Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, angle), Vector3(0, RIDGE + 0.2, 0)),
	]
	var skylights: Array = [[-8.0, 8.0], [-16.0, 0.0, 16.0]]
	for i in 2:
		var xf := slopes[i]
		var half := HX + 0.9
		_local_box("roof", xf, Vector3(0, -0.06, 2.4), Vector3(half * 2.0, 0.12, 4.8))
		_local_box("roof", xf, Vector3(0, -0.06, (7.0 + length) * 0.5), Vector3(half * 2.0, 0.12, length - 7.0))
		# The strip in between is broken up by skylights.
		var edge := -half
		# The north slope is mirrored, so its local X runs the other way.
		var holes: Array = skylights[i].map(func(x: float) -> float: return x if i == 0 else -x)
		holes.sort()
		for x: float in holes:
			_local_box("roof", xf, Vector3((edge + x - 2.5) * 0.5, -0.06, 5.9), Vector3(x - 2.5 - edge, 0.12, 2.2))
			for bar in [-1.25, 0.0, 1.25]:
				_local_box("steel", xf, Vector3(x + bar, -0.06, 5.9), Vector3(0.06, 0.08, 2.2), DETAIL | NO_COLLIDE)
			edge = x + 2.5
		_local_box("roof", xf, Vector3((edge + half) * 0.5, -0.06, 5.9), Vector3(half - edge, 0.12, 2.2))

		for z in [0.6, 2.8, 4.75, 7.05, 9.3, 11.6]:
			_local_box("steel", xf, Vector3(0, -0.19, z), Vector3(HX * 2.0, 0.14, 0.1), DETAIL | NO_COLLIDE)
		for x in TRUSSES:
			_local_box("steel", xf, Vector3(x, -0.36, (length - 0.6) * 0.5), Vector3(0.16, 0.2, length - 0.6), DETAIL | NO_COLLIDE)

	for x in TRUSSES:
		box("steel", Vector3(x, EAVES - 0.1, 0), Vector3(0.16, 0.2, HZ * 2.0), Vector3.ZERO, DETAIL | NO_COLLIDE)
		var posts: Array[float] = [-8.0, -4.0, 0.0, 4.0, 8.0]
		for j in posts.size():
			var z := posts[j]
			var top := _roof_underside(z)
			beam("steel", Vector3(x, EAVES, z), Vector3(x, top, z), 0.1, DETAIL | NO_COLLIDE)
			if j > 0:
				var prev := posts[j - 1]
				# Diagonals rise towards the ridge.
				if z <= 0.0:
					beam("steel", Vector3(x, EAVES, prev), Vector3(x, top, z), 0.08, DETAIL | NO_COLLIDE)
				else:
					beam("steel", Vector3(x, _roof_underside(prev), prev), Vector3(x, EAVES, z), 0.08, DETAIL | NO_COLLIDE)

	# Hanging lamps: only a few still work.
	var lit := {Vector2(-8, 5): true, Vector2(8, -5): true, Vector2(0, -5): false, Vector2(-16, -5): false}
	for x in BAYS:
		for z in [-5.0, 5.0]:
			var key := Vector2(x, z)
			lamp(Vector3(x, 6.0, z), lit.has(key), lit.get(key, false))


func _roof_underside(z: float) -> float:
	return RIDGE - absf(z) * (RIDGE - EAVES) / (HZ + 0.5) - 0.3


func _mezzanine() -> void:
	var x0 := -HX
	var x1 := -2.0
	var z1 := -6.5
	box("deck", Vector3((x0 + x1) * 0.5, DECK_Y - 0.04, (-HZ + z1) * 0.5), Vector3(x1 - x0, 0.08, z1 + HZ))
	for z in [z1 - 0.1, -9.25, -HZ + 0.1]:
		box("steel", Vector3((x0 + x1) * 0.5, DECK_Y - 0.23, z), Vector3(x1 - x0, 0.3, 0.16), Vector3.ZERO, NO_COLLIDE)
	for x in [-18.0, -14.0, -10.0, -6.0, -2.1]:
		box("steel", Vector3(x, (DECK_Y - 0.38) * 0.5, z1 - 0.1), Vector3(0.2, DECK_Y - 0.38, 0.2))
		box("steel", Vector3(x, DECK_Y - 0.2, (-HZ + z1) * 0.5), Vector3(0.1, 0.24, z1 + HZ), Vector3.ZERO, DETAIL | NO_COLLIDE)
	railing(Vector3(x0, DECK_Y, z1 - 0.05), Vector3(x1, DECK_Y, z1 - 0.05))
	railing(Vector3(x1 - 0.05, DECK_Y, z1), Vector3(x1 - 0.05, DECK_Y, -10.4))

	# Stairs down along the north wall; a ramp collider keeps movement smooth.
	var steps := 16
	var rise := DECK_Y / steps
	var run := 0.3
	for i in range(1, steps):
		var y := DECK_Y - rise * i
		box("deck", Vector3(x1 + run * (i - 0.5), y - 0.02, -11.2), Vector3(run, 0.04, 1.5), Vector3.ZERO, NO_COLLIDE)
	var foot := Vector3(x1 + run * steps, 0.0, 0.0)
	for z in [-10.42, -11.96]:
		beam("steel", Vector3(x1, DECK_Y - 0.14, z), Vector3(foot.x, -0.14, z), 0.07, NO_COLLIDE, 0.25)
	var slope := Vector3(foot.x - x1, -DECK_Y, 0.0)
	var ramp := Transform3D(Basis(Vector3.BACK, atan2(slope.y, slope.x)), Vector3(x1, DECK_Y, -11.2) + slope * 0.5)
	_collide_box(ramp * Transform3D(Basis(), Vector3(0, -0.1, 0)), Vector3(slope.length(), 0.2, 1.5))
	railing(Vector3(x1, DECK_Y, -10.42), Vector3(foot.x, 0.0, -10.42))

	# Storage underneath.
	shelf(Vector3(-17.5, 0, -11.4), 3.0, false)
	shelf(Vector3(-13.5, 0, -11.4), 3.0, false)
	shelf(Vector3(-9.5, 0, -11.4), 3.0, false)
	crates(Vector3(-16.5, 0, -8.6), 4)
	crates(Vector3(-6.0, 0, -10.6), 3)
	bulb(Vector3(-15.0, DECK_Y - 0.5, -9.2), true)
	bulb(Vector3(-7.0, DECK_Y - 0.5, -9.2), false)
	# And a few things on top.
	crates(Vector3(-17.0, DECK_Y, -10.0), 3)
	box("machine", Vector3(-11.0, DECK_Y + 0.95, -11.6), Vector3(3.0, 1.9, 0.6))


func _crane() -> void:
	var rail_y := 6.4
	for z in [-HZ + 0.6, HZ - 0.6]:
		box("steel", Vector3(0, rail_y, z), Vector3(HX * 2.0, 0.3, 0.25), Vector3.ZERO, DETAIL | NO_COLLIDE)
	var x := 6.0
	for dx in [-0.6, 0.6]:
		box("steel_yellow", Vector3(x + dx, rail_y + 0.55, 0), Vector3(0.35, 0.8, HZ * 2.0 - 0.9), Vector3.ZERO, DETAIL | NO_COLLIDE)
	for z in [-HZ + 0.6, HZ - 0.6]:
		box("steel_yellow", Vector3(x, rail_y + 0.4, z), Vector3(2.2, 0.5, 0.4), Vector3.ZERO, DETAIL | NO_COLLIDE)
	var trolley := Vector3(x, rail_y + 1.05, 3.0)
	box("machine", trolley, Vector3(1.5, 0.5, 1.2), Vector3.ZERO, DETAIL | NO_COLLIDE)
	for dz in [-0.12, 0.12]:
		beam("steel", trolley + Vector3(0, 0, dz), Vector3(x, 3.9, 3.0 + dz), 0.02, DETAIL | NO_COLLIDE)
	box("steel_yellow", Vector3(x, 3.65, 3.0), Vector3(0.35, 0.5, 0.45), Vector3.ZERO, DETAIL)
	box("steel", Vector3(x, 3.3, 3.0), Vector3(0.08, 0.3, 0.08), Vector3.ZERO, DETAIL | NO_COLLIDE)


func _hall_props() -> void:
	# Press.
	box("machine", Vector3(-6.0, 0.5, 3.5), Vector3(3.2, 1.0, 2.2))
	box("machine", Vector3(-6.0, 2.3, 3.9), Vector3(2.4, 2.6, 1.2))
	box("steel", Vector3(-6.0, 1.15, 3.1), Vector3(1.6, 0.3, 1.0))
	cylinder("steel", Vector3(-6.0, 1.3, 3.1), 0.22, 1.2)
	cylinder("pipe", Vector3(-6.9, 3.6, 3.9), 0.35, 0.9)

	# Long machine bed.
	box("machine", Vector3(2.0, 0.55, 7.8), Vector3(6.0, 1.1, 1.5))
	box("machine", Vector3(-0.2, 1.6, 7.9), Vector3(1.4, 1.0, 1.2))
	box("steel", Vector3(2.6, 1.16, 7.8), Vector3(4.0, 0.12, 0.9))
	cylinder("steel", Vector3(0.5, 1.55, 7.8), 0.3, 3.2, 0, Vector3(0, 0, -90))
	box("machine", Vector3(4.6, 1.5, 7.8), Vector3(0.6, 0.8, 0.9))

	# Control cabinets.
	for i in 3:
		box("machine", Vector3(-13.0 + i * 0.95, 1.0, 3.0), Vector3(0.9, 2.0, 0.6))

	# Tanks and pipework against the north wall.
	for x in [11.5, 15.0]:
		cylinder("pipe", Vector3(x, 0.0, -9.6), 1.25, 4.6, 0, Vector3.ZERO, -1.0, 28)
		cylinder("concrete", Vector3(x, 0.0, -9.6), 1.4, 0.25)
		cylinder("steel", Vector3(x, 4.6, -9.6), 0.14, 0.9, NO_COLLIDE)
		cylinder("steel", Vector3(x, 5.36, -9.6), 0.14, 2.3, NO_COLLIDE, Vector3(-90, 0, 0))
	cylinder("steel", Vector3(-1.0, 5.36, -11.75), 0.14, 21.0, NO_COLLIDE, Vector3(0, 0, -90))
	cylinder("pipe", Vector3(-1.0, 4.9, -11.8), 0.08, 21.0, NO_COLLIDE, Vector3(0, 0, -90))
	for x in [0.0, 4.0, 8.0, 18.0]:
		box("steel", Vector3(x, 5.1, -11.85), Vector3(0.06, 0.7, 0.3), Vector3.ZERO, DETAIL | NO_COLLIDE)

	# Containers.
	container("pipe", Vector3(-11.5, 0, 9.6), true)
	container("machine", Vector3(9.5, 0, -2.5), false)

	# Concrete barriers.
	box("concrete", Vector3(-2.0, 0.55, -1.5), Vector3(3.0, 1.1, 0.45), Vector3(0, 12, 0))
	box("concrete", Vector3(13.5, 0.55, 2.3), Vector3(3.0, 1.1, 0.45), Vector3(0, 80, 0))
	box("concrete", Vector3(-15.5, 0.55, -1.0), Vector3(3.0, 1.1, 0.45), Vector3(0, -30, 0))

	crates(Vector3(3.5, 0, -4.5), 5)
	crates(Vector3(-9.5, 0, -2.5), 4)
	crates(Vector3(16.5, 0, 9.5), 5)
	crates(Vector3(-17.5, 0, 6.0), 4)
	crates(Vector3(5.0, 0, 2.0), 2)
	pallet(Vector3(12.5, 0, 9.0), 20.0, 3)
	pallet(Vector3(-3.0, 0, 10.5), -8.0, 5)
	pallet(Vector3(17.5, 0, -3.5), 4.0, 1)
	for p in [Vector3(18.6, 0, -5.4), Vector3(17.9, 0, -5.9), Vector3(18.8, 0, -6.3), Vector3(-19.2, 0, 3.6), Vector3(-19.1, 0, 4.4)]:
		barrel(p)


func _annex() -> void:
	var x0 := HX + 0.5
	var x1 := 30.5
	var z0 := -HZ
	var z1 := 2.0
	var height := 3.4
	wall("plaster", true, z0 - 0.2, 0.4, x0, x1 + 0.4, 0.0, height, [])
	wall("plaster", false, x1 + 0.2, 0.4, z0, z1, 0.0, height, [])
	wall("plaster", true, z1 + 0.2, 0.4, x0, x1 + 0.4, 0.0, height, [[25.5, 29.0, 1.1, 2.6]])
	_mullions(Vector3(27.25, 1.85, z1 + 0.2), 3.5, 1.5, true, 0.875)
	box("concrete", Vector3(27.25, 1.06, z1 + 0.1), Vector3(3.7, 0.08, 0.6))
	box("concrete", Vector3((x0 + x1 + 0.4) * 0.5, height + 0.15, (z0 + z1) * 0.5), Vector3(x1 + 0.4 - x0, 0.3, z1 - z0 + 0.8))
	# The hall side of the annex is brick; give it a plaster lining.
	wall("plaster", false, x0 + 0.03, 0.06, z0, z1, 0.0, height, [[-10.0, -8.0, 0.0, 2.6], [-3.0, 0.0, 0.0, 3.0]])
	# Corridor partition and the wall between the two rooms.
	wall("plaster", false, 23.6, 0.2, z0, z1, 0.0, height, [[-9.6, -8.4, 0.0, 2.2], [-2.6, -1.4, 0.0, 2.2]])
	wall("plaster", true, -5.2, 0.2, 23.7, x1, 0.0, height, [])

	for z in [-10.0, -5.0, 0.0]:
		tube(Vector3(22.0, height - 0.08, z), false, z != -5.0)
	tube(Vector3(27.0, height - 0.08, -8.6), true, true)
	tube(Vector3(27.0, height - 0.08, -1.6), true, false)

	# Corridor: pipes under the ceiling and a few barrels.
	cylinder("pipe", Vector3(20.9, 3.0, z0), 0.09, z1 - z0, NO_COLLIDE, Vector3(90, 0, 0))
	cylinder("steel", Vector3(21.15, 3.1, z0), 0.05, z1 - z0, NO_COLLIDE, Vector3(90, 0, 0))
	barrel(Vector3(23.1, 0, -11.4))
	barrel(Vector3(22.4, 0, -11.5))
	box("machine", Vector3(23.3, 0.9, -5.5), Vector3(0.35, 1.8, 1.2))

	# Room A: storage.
	shelf(Vector3(27.0, 0, -11.6), 3.0, false)
	shelf(Vector3(30.1, 0, -8.5), 3.0, true)
	crates(Vector3(25.5, 0, -6.6), 4)
	pallet(Vector3(28.6, 0, -6.4), 10.0, 2)

	# Room B: lockers, desk and the window.
	for i in 5:
		box("machine", Vector3(30.2, 0.95, -4.6 + i * 0.52), Vector3(0.5, 1.9, 0.5))
	box("wood", Vector3(27.2, 0.76, 1.4), Vector3(2.2, 0.06, 0.9))
	for dx in [-1.0, 1.0]:
		box("steel", Vector3(27.2 + dx, 0.365, 1.4), Vector3(0.06, 0.73, 0.8))
	crates(Vector3(24.6, 0, -4.2), 2)


func _exterior() -> void:
	box("floor", Vector3(5, -0.55, 0), Vector3(160, 1.0, 160), Vector3.ZERO, DETAIL)
	# Yard wall and a skyline so the windows do not look out on nothing.
	box("brick", Vector3(5, 1.6, 34), Vector3(110, 3.2, 0.5), Vector3.ZERO, DETAIL)
	box("brick", Vector3(-50, 1.6, 0), Vector3(0.5, 3.2, 68), Vector3.ZERO, DETAIL)
	box("brick", Vector3(60, 1.6, 0), Vector3(0.5, 3.2, 68), Vector3.ZERO, DETAIL)
	box("brick", Vector3(5, 1.6, -34), Vector3(110, 3.2, 0.5), Vector3.ZERO, DETAIL)
	box("brick", Vector3(34, 5, 52), Vector3(26, 10, 16), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("roof", Vector3(-30, 4, 56), Vector3(30, 8, 18), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("concrete", Vector3(52, 7, 14), Vector3(14, 14, 20), Vector3.ZERO, DETAIL | NO_COLLIDE)
	cylinder("brick", Vector3(42, 0, 50), 2.2, 38.0, DETAIL | NO_COLLIDE, Vector3.ZERO, 1.4, 20)
	container("pipe", Vector3(38, 0, 9), false, DETAIL)


func _probes() -> void:
	probe("Hall", Vector3(0, 4.6, 0), Vector3(HX * 2.0, 9.4, HZ * 2.0), Vector3(2.0, -2.2, 1.0))
	probe("Corridor", Vector3(22.0, 1.7, -5.0), Vector3(3.0, 3.4, 14.0), Vector3.ZERO)
	probe("RoomA", Vector3(27.1, 1.7, -8.65), Vector3(6.8, 3.4, 6.7), Vector3(0, 0, 0.8))
	probe("RoomB", Vector3(27.1, 1.7, -1.55), Vector3(6.8, 3.4, 7.1), Vector3.ZERO)


# --- Prefabs -----------------------------------------------------------------


## Wall along X (or Z) at a fixed position on the other axis. Openings are
## [from, to, bottom, top] along the wall.
func wall(mat: String, along_x: bool, fixed: float, thickness: float, a0: float, a1: float, y0: float, y1: float, openings: Array) -> void:
	var sorted := openings.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var cursor := a0
	for o: Array in sorted:
		_wall_piece(mat, along_x, fixed, thickness, cursor, o[0], y0, y1)
		_wall_piece(mat, along_x, fixed, thickness, o[0], o[1], y0, o[2])
		_wall_piece(mat, along_x, fixed, thickness, o[0], o[1], o[3], y1)
		cursor = o[1]
	_wall_piece(mat, along_x, fixed, thickness, cursor, a1, y0, y1)


func _wall_piece(mat: String, along_x: bool, fixed: float, thickness: float, a0: float, a1: float, y0: float, y1: float) -> void:
	if a1 - a0 < 0.001 or y1 - y0 < 0.001:
		return
	var mid := (a0 + a1) * 0.5
	if along_x:
		box(mat, Vector3(mid, (y0 + y1) * 0.5, fixed), Vector3(a1 - a0, y1 - y0, thickness))
	else:
		box(mat, Vector3(fixed, (y0 + y1) * 0.5, mid), Vector3(thickness, y1 - y0, a1 - a0))


## Steel glazing bars in a window opening.
func _mullions(center: Vector3, width: float, height: float, along_x: bool, spacing: float) -> void:
	var flags := DETAIL | NO_COLLIDE
	var across := Vector3.RIGHT if along_x else Vector3.BACK
	var n := roundi(width / spacing)
	for i in range(1, n):
		var offset := -width * 0.5 + width * i / n
		box("steel", center + across * offset, Vector3(0.05, height, 0.05), Vector3.ZERO, flags)
	for i in range(1, roundi(height)):
		var y := -height * 0.5 + height * i / roundi(height)
		var size := Vector3(width, 0.05, 0.05) if along_x else Vector3(0.05, 0.05, width)
		box("steel", center + Vector3(0, y, 0), size, Vector3.ZERO, flags)


## Yellow tube railing between two points, with one collider for the whole run.
func railing(from: Vector3, to: Vector3) -> void:
	var flags := DETAIL | NO_COLLIDE
	var up := Vector3(0, 1.05, 0)
	beam("steel_yellow", from + up, to + up, 0.05, flags)
	beam("steel_yellow", from + up * 0.5, to + up * 0.5, 0.035, flags)
	var posts := maxi(1, roundi(Vector2(to.x - from.x, to.z - from.z).length() / 1.5))
	for i in posts + 1:
		var p := from.lerp(to, float(i) / posts)
		box("steel_yellow", p + up * 0.5, Vector3(0.05, 1.05, 0.05), Vector3.ZERO, flags)
	var mid := (from + to) * 0.5 + up * 0.5
	var length := from.distance_to(to)
	_collide_box(Transform3D(_along(to - from), mid), Vector3(0.06, 1.05 + absf(to.y - from.y) * 0.0, length))


func crates(at: Vector3, count: int) -> void:
	# Ground slots are far enough apart that turned crates never intersect;
	# whatever does not fit on the ground is stacked on top.
	var slots: Array[Vector2] = [Vector2(-0.8, -0.4), Vector2(0.8, -0.3), Vector2(0.1, 1.3), Vector2(-1.6, 1.2)]
	var turn := Basis(Vector3.UP, _rng.randi_range(0, 3) * PI * 0.5)
	var on_ground := count if count <= 2 else mini(count - count / 3, slots.size())
	var ground: Array[Vector3] = []
	for i in count:
		var size := _rng.randf_range(0.85, 1.25)
		var yaw := _rng.randf_range(-15, 15)
		var pos: Vector3
		if i < on_ground:
			pos = at + turn * Vector3(slots[i].x, size * 0.5, slots[i].y)
			ground.append(pos + Vector3(0, size * 0.5, 0))
		else:
			var below := ground[(i - on_ground) % ground.size()]
			size = minf(size, 0.95)
			pos = below + Vector3(_rng.randf_range(-0.08, 0.08), size * 0.5, _rng.randf_range(-0.08, 0.08))
		crate(pos, size, yaw)


## Wooden crate with a frame of boards along its edges.
func crate(center: Vector3, size: float, yaw: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), center)
	_box("wood", xf, Vector3.ONE * size, 0)
	var edge := size * 0.5 - 0.03
	for axis in 3:
		var board := Vector3.ONE * 0.1
		board[axis] = size + 0.04
		for a: float in [-edge, edge]:
			for b: float in [-edge, edge]:
				var offset := Vector3.ZERO
				offset[(axis + 1) % 3] = a
				offset[(axis + 2) % 3] = b
				_local_box("wood", xf, offset, board, NO_COLLIDE)


## Shipping container with ribbed sides; `along_x` is the direction of its length.
func container(mat: String, at: Vector3, along_x: bool, flags := 0) -> void:
	var xf := Transform3D(Basis() if along_x else Basis(Vector3.UP, PI * 0.5), at + Vector3(0, 1.3, 0))
	var length := 6.0
	var width := 2.4
	var height := 2.6
	_box(mat, xf, Vector3(length - 0.1, height - 0.2, width - 0.1), flags)
	var trim := flags | NO_COLLIDE
	for y: float in [-height * 0.5 + 0.08, height * 0.5 - 0.08]:
		_local_box(mat, xf, Vector3(0, y, 0), Vector3(length, 0.16, width), trim)
	for x: float in [-length * 0.5 + 0.06, length * 0.5 - 0.06]:
		for z: float in [-width * 0.5 + 0.06, width * 0.5 - 0.06]:
			_local_box(mat, xf, Vector3(x, 0, z), Vector3(0.12, height, 0.12), trim)
	var ribs := 19
	for i in ribs:
		var x := -length * 0.5 + length * (i + 1) / (ribs + 1)
		_local_box(mat, xf, Vector3(x, 0, 0), Vector3(0.1, height - 0.3, width - 0.02), trim)
	# Door bars on one end.
	for z: float in [-0.75, -0.25, 0.25, 0.75]:
		_local_box("steel", xf, Vector3(length * 0.5 - 0.03, 0, z), Vector3(0.05, height - 0.3, 0.04), trim)
	_local_box(mat, xf, Vector3(length * 0.5 - 0.04, 0, 0), Vector3(0.04, height - 0.3, 0.04), trim)


func pallet(at: Vector3, yaw: float, stack: int) -> void:
	for i in stack:
		var rot := Vector3(0, yaw + _rng.randf_range(-4, 4), 0)
		var base := at + Vector3(0, i * 0.15, 0)
		box("wood", base + Vector3(0, 0.125, 0), Vector3(1.2, 0.03, 1.0), rot, NO_COLLIDE if i > 0 else 0)
		box("wood", base + Vector3(0, 0.055, 0), Vector3(1.2, 0.11, 0.8), rot, NO_COLLIDE)
	_collide_box(Transform3D(Basis(), at + Vector3(0, stack * 0.075, 0)), Vector3(1.2, stack * 0.15, 1.0))


func barrel(at: Vector3) -> void:
	cylinder("pipe" if _rng.randf() < 0.5 else "machine", at, 0.3, 0.9, 0, Vector3.ZERO, -1.0, 16)


## Steel rack with wooden boards, against a wall along X (or Z when turned).
func shelf(at: Vector3, width: float, turned: bool) -> void:
	var across := Vector3.BACK if turned else Vector3.RIGHT
	var depth_axis := Vector3.RIGHT if turned else Vector3.BACK
	for side in [-1.0, 1.0]:
		for d in [-0.25, 0.25]:
			var p: Vector3 = at + across * side * width * 0.5 + depth_axis * d
			box("steel", p + Vector3(0, 1.1, 0), Vector3(0.05, 2.2, 0.05), Vector3.ZERO, DETAIL | NO_COLLIDE)
	for y in [0.4, 1.1, 1.8]:
		var size := Vector3(0.6, 0.04, width) if turned else Vector3(width, 0.04, 0.6)
		box("wood", at + Vector3(0, y, 0), size, Vector3.ZERO, NO_COLLIDE)
		for i in 3:
			if _rng.randf() < 0.7:
				var s := _rng.randf_range(0.3, 0.55)
				var p: Vector3 = at + across * (i - 1) * width * 0.3 + Vector3(0, y + 0.02 + s * 0.5, 0)
				box("wood" if _rng.randf() < 0.6 else "machine", p, Vector3(s, s, s), Vector3(0, _rng.randf_range(-10, 10), 0), NO_COLLIDE)
	var size := Vector3(0.6, 2.2, width) if turned else Vector3(width, 2.2, 0.6)
	_collide_box(Transform3D(Basis(), at + Vector3(0, 1.1, 0)), size)


## Hanging hall lamp; the bulb sits at `at`.
func lamp(at: Vector3, on: bool, shadows: bool) -> void:
	beam("steel", at + Vector3(0, 0.3, 0), Vector3(at.x, _roof_underside(at.z) - 0.2, at.z), 0.02, DETAIL | NO_COLLIDE)
	cylinder("machine", at, 0.42, 0.3, DETAIL | NO_COLLIDE, Vector3.ZERO, 0.08, 16)
	cylinder("emissive_warm" if on else "steel", at + Vector3(0, -0.02, 0), 0.16, 0.04, DETAIL | NO_COLLIDE, Vector3.ZERO, -1.0, 12)
	if not on:
		return
	var light := SpotLight3D.new()
	light.name = "HallLamp"
	light.position = at + Vector3(0, -0.05, 0)
	light.rotation_degrees = Vector3(-90, 0, 0)
	light.light_color = Color(1.0, 0.74, 0.46)
	light.light_energy = 26.0
	light.light_volumetric_fog_energy = 1.6
	light.spot_range = 11.0
	light.spot_angle = 52.0
	light.spot_angle_attenuation = 0.6
	light.spot_attenuation = 1.2
	light.shadow_enabled = shadows
	light.light_bake_mode = Light3D.BAKE_DYNAMIC
	_add(light, _lights)


## Bare bulb in a cage under the mezzanine.
func bulb(at: Vector3, shadows: bool) -> void:
	cylinder("steel", at + Vector3(0, 0.1, 0), 0.05, 0.25, DETAIL | NO_COLLIDE, Vector3.ZERO, -1.0, 8)
	cylinder("emissive_warm", at, 0.05, 0.1, DETAIL | NO_COLLIDE, Vector3.ZERO, -1.0, 8)
	var light := OmniLight3D.new()
	light.name = "Bulb"
	light.position = at + Vector3(0, -0.1, 0)
	light.light_color = Color(1.0, 0.7, 0.42)
	light.light_energy = 4.0
	light.omni_range = 7.0
	light.omni_attenuation = 1.3
	light.shadow_enabled = shadows
	light.light_bake_mode = Light3D.BAKE_DYNAMIC
	_add(light, _lights)


## Fluorescent ceiling fixture.
func tube(at: Vector3, along_x: bool, on: bool) -> void:
	var long := Vector3(1.3, 0, 0) if along_x else Vector3(0, 0, 1.3)
	var cross := Vector3(0, 0, 0.16) if along_x else Vector3(0.16, 0, 0)
	box("steel", at + Vector3(0, 0.03, 0), long + cross + Vector3(0, 0.06, 0), Vector3.ZERO, NO_COLLIDE)
	box("emissive_cool" if on else "plaster", at + Vector3(0, -0.03, 0), long * 0.92 + cross * 0.3 + Vector3(0, 0.04, 0), Vector3.ZERO, DETAIL | NO_COLLIDE)
	if not on:
		return
	var light := OmniLight3D.new()
	light.name = "Tube"
	light.position = at + Vector3(0, -0.25, 0)
	light.light_color = Color(0.82, 0.93, 1.0)
	light.light_energy = 3.0
	light.omni_range = 7.5
	light.omni_attenuation = 1.4
	light.shadow_enabled = true
	light.light_bake_mode = Light3D.BAKE_DYNAMIC
	_add(light, _lights)


func probe(probe_name: String, center: Vector3, size: Vector3, origin: Vector3) -> void:
	var node := ReflectionProbe.new()
	node.name = "Probe" + probe_name
	node.position = center
	node.size = size
	node.origin_offset = origin
	node.box_projection = true
	node.enable_shadows = true
	node.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	node.max_distance = 60.0
	_add(node, _root)


# --- Geometry builders -------------------------------------------------------


func box(mat: String, center: Vector3, size: Vector3, rot_deg := Vector3.ZERO, flags := 0) -> void:
	_box(mat, Transform3D(Basis.from_euler(rot_deg * PI / 180.0), center), size, flags)


func _local_box(mat: String, frame: Transform3D, center: Vector3, size: Vector3, flags := 0) -> void:
	_box(mat, frame * Transform3D(Basis(), center), size, flags)


## Square-section member between two points.
func beam(mat: String, from: Vector3, to: Vector3, width: float, flags := 0, height := -1.0) -> void:
	var size := Vector3(width, width if height < 0.0 else height, from.distance_to(to))
	_box(mat, Transform3D(_along(to - from), (from + to) * 0.5), size, flags)


func _box(mat: String, xf: Transform3D, size: Vector3, flags: int) -> void:
	var st := _tool(mat, flags)
	var half := size * 0.5
	for n: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var up := Vector3.FORWARD if absf(n.y) > 0.5 else Vector3.UP
		var right := up.cross(n)
		var c := n * absf(n.dot(half))
		var r := right * absf(right.dot(half))
		var u := up * absf(up.dot(half))
		var corners: Array[Vector3] = [c - r - u, c + r - u, c + r + u, c - r + u]
		var normal := xf.basis * n
		var points: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for p in corners:
			# Unrotated offset keeps the texture continuous across abutting boxes.
			var q := p + xf.origin
			points.append(xf * p)
			uvs.append(Vector2(q.dot(right), -q.dot(up)))
		_quad(st, points, [normal, normal, normal, normal], uvs)
	if not flags & NO_COLLIDE:
		_collide_box(xf, size)


## Cylinder or cone standing on `base`; rot_deg tilts its axis.
func cylinder(mat: String, base: Vector3, radius: float, height: float, flags := 0, rot_deg := Vector3.ZERO, top_radius := -1.0, segments := 20) -> void:
	var st := _tool(mat, flags)
	var xf := Transform3D(Basis.from_euler(rot_deg * PI / 180.0), base)
	var r_top := radius if top_radius < 0.0 else top_radius
	var top := Vector3(0, height, 0)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		# Counter-clockwise seen from outside means going towards -angle around +Y.
		var d0 := Vector3(cos(a1), 0, sin(a1))
		var d1 := Vector3(cos(a0), 0, sin(a0))
		var u0 := -a1 * radius
		var u1 := -a0 * radius
		_quad(
			st,
			[xf * (d0 * radius), xf * (d1 * radius), xf * (d1 * r_top + top), xf * (d0 * r_top + top)],
			[xf.basis * d0, xf.basis * d1, xf.basis * d1, xf.basis * d0],
			[Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, -height), Vector2(u0, -height)]
		)
		var up := xf.basis * Vector3.UP
		_tri(st, [xf * top, xf * (d0 * r_top + top), xf * (d1 * r_top + top)], [up, up, up],
			[Vector2.ZERO, Vector2(d0.x, d0.z) * r_top, Vector2(d1.x, d1.z) * r_top])
		_tri(st, [xf * Vector3.ZERO, xf * (d1 * radius), xf * (d0 * radius)], [-up, -up, -up],
			[Vector2.ZERO, Vector2(d1.x, d1.z) * radius, Vector2(d0.x, d0.z) * radius])
	if not flags & NO_COLLIDE:
		var key := "cyl %s %s" % [maxf(radius, r_top), height]
		if not _shapes.has(key):
			var shape := CylinderShape3D.new()
			shape.radius = maxf(radius, r_top)
			shape.height = height
			_shapes[key] = shape
		_collide(_shapes[key], xf * Transform3D(Basis(), top * 0.5))


## Convex polygon (counter-clockwise in local XY) extruded along local Z.
func extrude(mat: String, polygon: PackedVector2Array, depth: float, xf: Transform3D, flags := 0) -> void:
	var st := _tool(mat, flags)
	var front := Vector3(0, 0, depth * 0.5)
	var count := polygon.size()
	var hull := PackedVector3Array()
	for i in count:
		var a := polygon[i]
		var b := polygon[(i + 1) % count]
		var a3 := Vector3(a.x, a.y, 0)
		var b3 := Vector3(b.x, b.y, 0)
		hull.append(xf * (a3 + front))
		hull.append(xf * (a3 - front))
		var n := xf.basis * Vector3(b.y - a.y, a.x - b.x, 0).normalized()
		var run := a.distance_to(b)
		_quad(st, [xf * (a3 - front), xf * (b3 - front), xf * (b3 + front), xf * (a3 + front)], [n, n, n, n],
			[Vector2(0, depth), Vector2(run, depth), Vector2(run, 0), Vector2(0, 0)])
		if i >= 2:
			var o := polygon[0]
			var o3 := Vector3(o.x, o.y, 0)
			var p := polygon[i - 1]
			var p3 := Vector3(p.x, p.y, 0)
			var nf := xf.basis * Vector3.BACK
			_tri(st, [xf * (o3 + front), xf * (p3 + front), xf * (a3 + front)], [nf, nf, nf],
				[Vector2(o.x, -o.y), Vector2(p.x, -p.y), Vector2(a.x, -a.y)])
			_tri(st, [xf * (o3 - front), xf * (a3 - front), xf * (p3 - front)], [-nf, -nf, -nf],
				[Vector2(-o.x, -o.y), Vector2(-a.x, -a.y), Vector2(-p.x, -p.y)])
	if not flags & NO_COLLIDE:
		var shape := ConvexPolygonShape3D.new()
		shape.points = hull
		_collide(shape, Transform3D())


## Corners are bottom-left, bottom-right, top-right, top-left seen from outside.
func _quad(st: SurfaceTool, p: Array, n: Array, uv: Array) -> void:
	_tri(st, [p[0], p[1], p[2]], [n[0], n[1], n[2]], [uv[0], uv[1], uv[2]])
	_tri(st, [p[0], p[2], p[3]], [n[0], n[2], n[3]], [uv[0], uv[2], uv[3]])


## Takes counter-clockwise corners and emits Godot's clockwise winding.
func _tri(st: SurfaceTool, p: Array, n: Array, uv: Array) -> void:
	for i: int in [0, 2, 1]:
		st.set_normal(n[i])
		st.set_uv(uv[i])
		st.add_vertex(p[i])


func _along(direction: Vector3) -> Basis:
	var up := Vector3.RIGHT if absf(direction.normalized().y) > 0.99 else Vector3.UP
	return Basis.looking_at(direction, up)


func _tool(mat: String, flags: int) -> SurfaceTool:
	var key := ("detail/" if flags & DETAIL else "static/") + mat
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = st
	return _tools[key]


func _collide_box(xf: Transform3D, size: Vector3) -> void:
	var key := "box %s" % size.snappedf(0.001)
	if not _shapes.has(key):
		var shape := BoxShape3D.new()
		shape.size = size
		_shapes[key] = shape
	_collide(_shapes[key], xf)


func _collide(shape: Shape3D, xf: Transform3D) -> void:
	var node := CollisionShape3D.new()
	node.shape = shape
	node.transform = xf
	_add(node, _body)


func _add(node: Node, parent: Node) -> void:
	parent.add_child(node, true)
	if node != _root:
		node.owner = _root


## Merges every surface of one kind into a single mesh instance.
func _commit(kind: String, lightmapped: bool) -> void:
	var mesh := ArrayMesh.new()
	var keys := _tools.keys().filter(func(key: String) -> bool: return key.begins_with(kind + "/"))
	keys.sort()
	var triangles := 0
	for key: String in keys:
		var st: SurfaceTool = _tools[key]
		st.index()
		st.generate_tangents()
		st.set_material(load("res://materials/%s.tres" % key.get_slice("/", 1)))
		st.commit(mesh)
		triangles += mesh.surface_get_array_index_len(mesh.get_surface_count() - 1) / 3
	if lightmapped:
		var err := mesh.lightmap_unwrap(Transform3D(), TEXEL)
		print("Lightmap unwrap: ", error_string(err), ", size hint ", mesh.lightmap_size_hint)
	var path := "%s%s_%s.res" % [OUT_DIR, NAME, kind]
	ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	mesh.take_over_path(path)
	var instance := MeshInstance3D.new()
	instance.name = kind.capitalize()
	instance.mesh = mesh
	instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC if lightmapped else GeometryInstance3D.GI_MODE_DYNAMIC
	_add(instance, _root)
	_root.move_child(instance, 0)
	print("%s: %d surfaces, %d triangles" % [kind, mesh.get_surface_count(), triangles])
