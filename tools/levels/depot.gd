extends "res://tools/level_builder.gd"
## The depot: a walled container yard at dusk, with a covered loading dock
## along the north side and a gatehouse in the south-east corner.
## Build with: tools/build_level.sh depot

# Yard dimensions (interior faces).
const YX := 30.0
const YZ := 20.0
const WALL := 5.0
const DOCK_Y := 1.2
## Front edge of the loading dock.
const DOCK_Z := -14.0
const DOCK_X := 22.0
const CANOPY_Y := 5.6


func _level_name() -> String:
	return "depot"


func _describe() -> void:
	_detail_block = Vector3(30, 30, 20)
	_detail_inside = AABB(Vector3(-YX - 0.5, 0, -YZ - 0.5), Vector3(YX * 2.0 + 1.0, 12.0, YZ * 2.0 + 1.0))
	_yard()
	_dock()
	_containers()
	_gatehouse()
	_drains()
	_masts()
	_cover()
	_surroundings()
	_probes()
	_dirt()


func _yard() -> void:
	box("floor", Vector3(0, -0.25, 0), Vector3(YX * 2.0 + 1.0, 0.5, YZ * 2.0 + 1.0))
	wall("brick", true, YZ + 0.25, 0.5, -YX - 0.5, YX + 0.5, 0.0, WALL, [])
	wall("brick", false, -YX - 0.25, 0.5, -YZ, YZ, 0.0, WALL, [])
	# The dock backs onto the warehouse, whose wall is higher.
	wall("concrete", true, -YZ - 0.25, 0.5, -YX - 0.5, YX + 0.5, 0.0, 8.0, [])
	# East wall with the closed gate the player came in through.
	wall("brick", false, YX + 0.25, 0.5, -YZ, YZ, 0.0, WALL, [[-3.0, 3.0, 0.0, 4.0]])
	roller_door(Vector3(YX + 0.26, 1.79, 0.0), Vector3.LEFT, Vector2(6.0, 3.58))
	for z in [-3.1, 3.1]:
		box("steel", Vector3(YX + 0.05, 2.1, z), Vector3(0.2, 4.2, 0.2))
	box("steel", Vector3(YX + 0.05, 4.1, 0.0), Vector3(0.2, 0.25, 6.4))
	for z in [-4.4, 4.4]:
		bulb(Vector3(YX - 0.3, 3.6, z), false)
	# Coping stones.
	for z in [-YZ - 0.25, YZ + 0.25]:
		box("concrete", Vector3(0, (8.06 if z < 0.0 else WALL + 0.06), z), Vector3(YX * 2.0 + 1.2, 0.12, 0.7), Vector3.ZERO, NO_COLLIDE)
	for x in [-YX - 0.25, YX + 0.25]:
		box("concrete", Vector3(x, WALL + 0.06, 0), Vector3(0.7, 0.12, YZ * 2.0), Vector3.ZERO, NO_COLLIDE)
	# Buttresses break up the long walls.
	for x in [-20.0, -10.0, 0.0, 10.0, 20.0]:
		box("brick", Vector3(x, WALL * 0.5, YZ - 0.15), Vector3(0.7, WALL, 0.3))
	for z in [-10.0, 10.0]:
		box("brick", Vector3(-YX + 0.15, WALL * 0.5, z), Vector3(0.3, WALL, 0.7))
		box("brick", Vector3(YX - 0.15, WALL * 0.5, z), Vector3(0.3, WALL, 0.7))


func _dock() -> void:
	var depth := YZ + DOCK_Z
	var mid_z := (DOCK_Z - YZ) * 0.5
	box("concrete", Vector3(0, DOCK_Y * 0.5, mid_z), Vector3(DOCK_X * 2.0, DOCK_Y, depth))
	box("steel_yellow", Vector3(0, DOCK_Y - 0.1, DOCK_Z + 0.03), Vector3(DOCK_X * 2.0, 0.2, 0.06), Vector3.ZERO, NO_COLLIDE)
	# A ramp at either end.
	var run := YX - DOCK_X - 2.0
	extrude("concrete", PackedVector2Array([Vector2(0, 0), Vector2(run, 0), Vector2(run, DOCK_Y)]), depth, Transform3D(Basis(), Vector3(-DOCK_X - run, 0, mid_z)))
	extrude("concrete", PackedVector2Array([Vector2(0, 0), Vector2(run, 0), Vector2(0, DOCK_Y)]), depth, Transform3D(Basis(), Vector3(DOCK_X, 0, mid_z)))
	for side in [-1.0, 1.0]:
		var top := Vector3(side * DOCK_X, DOCK_Y, DOCK_Z + 0.1)
		railing(top, Vector3(side * (DOCK_X + run), 0.0, DOCK_Z + 0.1))

	# Canopy on steel columns.
	box("roof", Vector3(0, CANOPY_Y, mid_z + 1.0), Vector3(DOCK_X * 2.0 + 4.0, 0.12, depth + 2.4), Vector3(4, 0, 0))
	box("steel", Vector3(0, CANOPY_Y - 0.25, DOCK_Z - 0.3), Vector3(DOCK_X * 2.0 + 4.0, 0.3, 0.2), Vector3.ZERO, DETAIL | NO_COLLIDE)
	for x in [-20.0, -12.0, -4.0, 4.0, 12.0, 20.0]:
		box("steel", Vector3(x, (DOCK_Y + CANOPY_Y - 0.4) * 0.5, DOCK_Z - 0.3), Vector3(0.25, CANOPY_Y - 0.4 - DOCK_Y, 0.25))
		beam("steel", Vector3(x, CANOPY_Y - 0.25, DOCK_Z - 0.3), Vector3(x, CANOPY_Y + 0.1, -YZ), 0.16, DETAIL | NO_COLLIDE)
		beam("steel", Vector3(x, CANOPY_Y - 1.4, DOCK_Z - 0.3), Vector3(x, CANOPY_Y - 0.2, DOCK_Z - 1.8), 0.08, DETAIL | NO_COLLIDE)

	# Roller doors in the warehouse wall, each with a number plate of light above.
	var lit := [-16.0, 0.0, 8.0]
	for x in [-16.0, -8.0, 0.0, 8.0, 16.0]:
		roller_door(Vector3(x, DOCK_Y + 1.7, -YZ + 0.06), Vector3.BACK, Vector2(4.0, 3.4))
		label(str(roundi(x / 8.0) + 3), Vector3(x - 2.9, DOCK_Y + 2.3, -YZ), Vector3.BACK, 0.7, Color(0.08, 0.12, 0.2))
		tube(Vector3(x, CANOPY_Y - 0.5, mid_z), true, x in lit, x == 0.0)

	crates(Vector3(-15.0, DOCK_Y, -18.0), 4)
	crates(Vector3(7.0, DOCK_Y, -17.6), 3)
	pallet(Vector3(-4.0, DOCK_Y, -18.6), 6.0, 4)
	bags(Vector3(19.0, DOCK_Y, -16.0), -12.0, 4, 2)
	shelf(Vector3(14.0, DOCK_Y, -19.6), 0, true)
	place("hand_truck", Vector3(-12.4, DOCK_Y, -17.0), 200, true)
	for p in [Vector3(2.5, DOCK_Y, -19.4), Vector3(2.95, DOCK_Y, -19.3)]:
		gas_bottle(p)
	place("korean_fire_extinguisher_01", Vector3(4.2, DOCK_Y, -YZ + 0.2), 0)
	mount("fire_alarm", Vector3(4.6, DOCK_Y + 1.4, -YZ), 0, true)
	place("metal_jerrycan", Vector3(-13.3, DOCK_Y, -18.9), 60)
	place("metal_jerrycan", Vector3(-13.75, DOCK_Y, -18.6), -20)
	drop("plastic_broom", Vector3(-21.5, DOCK_Y, -19.45), 0)
	for p in [Vector3(-20.5, DOCK_Y, -19.2), Vector3(-19.7, DOCK_Y, -19.3), Vector3(1.5, DOCK_Y, -19.3)]:
		barrel(p)


func _containers() -> void:
	# [x, z, along x, material, material of the one stacked on top or ""]
	var layout: Array = [
		[-17.0, -7.0, true, "container_red", ""],
		[-10.5, -7.0, true, "container_green", "container_grey"],
		[4.0, -7.0, true, "container_orange", ""],
		[11.0, -7.0, true, "container_blue", "container_green"],
		[-22.0, 1.5, true, "container_green", ""],
		[-7.0, 1.5, true, "container_red", "container_orange"],
		[-0.5, 1.5, true, "container_grey", ""],
		[14.0, 1.5, true, "container_blue", "container_red"],
		[-16.0, 10.0, true, "container_grey", "container_blue"],
		[-9.5, 10.0, true, "container_orange", ""],
		[9.0, 10.0, true, "container_red", ""],
		[1.5, 11.5, false, "container_green", ""],
		[20.0, -3.5, false, "container_blue", ""],
	]
	for c: Array in layout:
		var at := Vector3(c[0], 0, c[1])
		container(c[3], at, c[2])
		if c[4]:
			var shift := Vector3(_rng.randf_range(-0.3, 0.3), 2.6, 0) if c[2] else Vector3(0, 2.6, _rng.randf_range(-0.3, 0.3))
			container(c[4], at + shift, c[2])


func _gatehouse() -> void:
	var x0 := 22.9
	var z0 := 13.9
	var height := 3.0
	wall("plaster", false, x0, 0.2, z0, YZ, 0.0, height, [[15.8, 17.4, 0.0, 2.2]])
	wall("plaster", true, z0, 0.2, x0 - 0.1, YX, 0.0, height, [[25.0, 28.0, 1.0, 2.2]])
	_mullions(Vector3(26.5, 1.6, z0), 3.0, 1.2, true, 1.0)
	box("concrete", Vector3(26.5, 0.96, z0 - 0.05), Vector3(3.2, 0.08, 0.4))
	box("concrete", Vector3((x0 + YX) * 0.5 - 0.1, height + 0.15, (z0 + YZ) * 0.5 - 0.1), Vector3(YX - x0 + 0.5, 0.3, YZ - z0 + 0.5))
	# Plaster lining over the brick of the yard wall.
	wall("plaster", false, YX - 0.03, 0.06, z0, YZ, 0.0, height, [])
	wall("plaster", true, YZ - 0.03, 0.06, x0, YX, 0.0, height, [])
	tube(Vector3(26.5, height - 0.08, 17.0), true, true)
	place(DESK, Vector3(26.5, 0, 14.55), 0)
	lockers("machine_blue", Vector3(29.6, 0, 15.9), -90, 5, {1: 25.0})
	place("plastic_monobloc_chair_01", Vector3(26.4, 0, 15.4), 195)
	var box: Vector3 = _model("cardboard_box_01").box.size
	place("cardboard_box_01", Vector3(23.6, 0, 19.3), 10)
	place("cardboard_box_01", Vector3(23.62, box.y, 19.28), -20)
	place("korean_fire_extinguisher_01", Vector3(23.3, 0, 14.25), 0)
	# The bin was full long ago.
	place("trashbag", Vector3(22.35, 0, 18.4), 0)
	place("trashbag", Vector3(22.2, 0, 19.1), 100)
	shelf(Vector3(26.0, 0, 19.55), 180, true)
	# A lamp over the door.
	bulb(Vector3(x0 - 0.4, 2.7, 16.6), false)


## Drains in the lane between the rows, their frames flush with the ground.
func _drains() -> void:
	for x: float in [-3.0, 12.5]:
		prop("water_manhole_cover", Transform3D(Basis(), Vector3(x, -0.055, 5.9)))


func _masts() -> void:
	for at: Vector3 in [Vector3(-25, 0, -11), Vector3(14, 0, -11.5), Vector3(-10, 0, 17), Vector3(17, 0, 17)]:
		mast(at, Vector3(at.x * 0.35, 0.0, at.z * 0.2))


## Floodlight mast aimed at a point on the ground.
func mast(at: Vector3, target: Vector3) -> void:
	var height := 10.0
	box("concrete", at + Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.9))
	box("steel", at + Vector3(0, height * 0.5, 0), Vector3(0.22, height, 0.22))
	var head := at + Vector3(0, height, 0)
	var aim := _along(target - head)
	_box("steel", Transform3D(aim, head), Vector3(1.6, 0.12, 0.12), DETAIL | NO_COLLIDE)
	for side in [-0.55, 0.55]:
		var lamp_xf := Transform3D(aim, head) * Transform3D(Basis(), Vector3(side, 0, -0.2))
		_box("machine", lamp_xf, Vector3(0.5, 0.4, 0.3), DETAIL | NO_COLLIDE)
		_box("emissive_warm", lamp_xf * Transform3D(Basis(), Vector3(0, 0, -0.16)), Vector3(0.42, 0.32, 0.02), DETAIL | NO_COLLIDE)
	var light := SpotLight3D.new()
	light.name = "Floodlight"
	light.transform = Transform3D(aim, head) * Transform3D(Basis(), Vector3(0, 0, -0.45))
	light.light_color = Color(1.0, 0.66, 0.34)
	light.light_energy = 60.0
	light.light_volumetric_fog_energy = 1.2
	light.spot_range = 38.0
	light.spot_angle = 50.0
	light.spot_angle_attenuation = 0.7
	light.spot_attenuation = 1.1
	light.shadow_enabled = true
	light.light_bake_mode = Light3D.BAKE_DYNAMIC
	_add(light, _lights)


func _cover() -> void:
	barrier(Vector3(23.0, 0, 4.5), 75)
	barrier(Vector3(-3.0, 0, -3.0), 10)
	barrier(Vector3(8.5, 0, 5.6), -20)
	barrier(Vector3(-14.0, 0, -2.5), 35)
	barrier(Vector3(-24.0, 0, 12.0), 90)
	crates(Vector3(-4.0, 0, -11.5), 4)
	crates(Vector3(-21.0, 0, 8.5), 4)
	crates(Vector3(6.0, 0, -2.5), 3)
	crates(Vector3(21.5, 0, -11.0), 5)
	crates(Vector3(-3.5, 0, 16.5), 3)
	pallet(Vector3(18.0, 0, 12.0), 15.0, 4)
	pallet(Vector3(-27.5, 0, 2.0), -5.0, 3)
	bags(Vector3(10.0, 0, 16.5), 40.0, 5, 2)
	tyres(Vector3(28.9, 0, -7.0), 4)
	tyres(Vector3(28.2, 0, -7.4), 2)
	tyres(Vector3(-28.9, 0, 17.2), 3)
	for p in [Vector3(28.8, 0, -5.0), Vector3(28.9, 0, -5.8), Vector3(28.2, 0, -5.5), Vector3(-28.8, 0, 18.6), Vector3(-28.0, 0, 18.9), Vector3(5.5, 0, 18.9)]:
		barrel(p)


func _surroundings() -> void:
	box("floor", Vector3(0, -0.55, 0), Vector3(220, 1.0, 220), Vector3.ZERO, DETAIL)
	# The warehouse behind the dock and a skyline beyond the other walls.
	box("concrete", Vector3(0, 6.0, -31), Vector3(72, 12, 21), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("roof", Vector3(0, 12.6, -31), Vector3(74, 1.2, 23), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("brick", Vector3(-22, 6.5, 38), Vector3(30, 13, 16), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("concrete", Vector3(26, 9, 44), Vector3(22, 18, 18), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("brick", Vector3(-48, 8, -6), Vector3(18, 16, 34), Vector3.ZERO, DETAIL | NO_COLLIDE)
	box("concrete", Vector3(50, 7, 14), Vector3(20, 14, 26), Vector3.ZERO, DETAIL | NO_COLLIDE)
	cylinder("brick", Vector3(-40, 0, 30), 2.2, 40.0, DETAIL | NO_COLLIDE, Vector3.ZERO, 1.4, 20)
	for i in 3:
		container(["container_red", "container_green", "container_grey"][i], Vector3(44, i * 2.6, -14), false, DETAIL | NO_COLLIDE)


func _probes() -> void:
	probe("Yard", Vector3(0, 4.5, 3.0), Vector3(YX * 2.0, 9.0, 34.0), Vector3(0, -2.5, 0))
	probe("Dock", Vector3(0, 3.3, -17.0), Vector3(DOCK_X * 2.0 + 16.0, 4.6, 6.0), Vector3.ZERO)
	probe("Gatehouse", Vector3(26.4, 1.5, 16.9), Vector3(6.8, 3.0, 5.8), Vector3.ZERO)


func _dirt() -> void:
	for x in [-26.0, -15.0, -5.0, 5.0, 15.0]:
		wall_decal(_pick("leak"), Vector3(x + _decal_rng.randf_range(-2.0, 2.0), 3.0, YZ - 0.04), Vector3.FORWARD, 2.2, 4.0)
		wall_decal("grime", Vector3(x, 0.8, YZ - 0.1), Vector3.FORWARD, 11.0, 1.6)
	for z in [-9.0, 3.0, 13.0]:
		wall_decal(_pick("leak"), Vector3(-YX + 0.04, 3.0, z + _decal_rng.randf_range(-2.0, 2.0)), Vector3.RIGHT, 2.2, 4.0)
		wall_decal("grime", Vector3(-YX + 0.1, 0.8, z), Vector3.RIGHT, 12.0, 1.6)
	for z in [-12.0, 8.0]:
		wall_decal(_pick("leak"), Vector3(YX - 0.04, 3.0, z), Vector3.LEFT, 2.2, 4.0)
		wall_decal("grime", Vector3(YX - 0.1, 0.8, z), Vector3.LEFT, 12.0, 1.6)
	# Streaks down the warehouse wall above the doors and along the dock face.
	for x in [-12.0, -4.0, 4.0, 12.0, 20.0]:
		wall_decal(_pick("leak"), Vector3(x, 5.6, -YZ + 0.04), Vector3.BACK, 2.4, 4.6)
		wall_decal("grime", Vector3(x - 4.0, 0.6, DOCK_Z + 0.1), Vector3.BACK, 9.0, 1.2)
	for i in 14:
		var at := Vector3(_decal_rng.randf_range(-27.0, 27.0), 0, _decal_rng.randf_range(-12.0, 18.0))
		var size := _decal_rng.randf_range(2.0, 5.0)
		floor_decal(_pick("stain"), at, Vector2(size, size * _decal_rng.randf_range(0.7, 1.3)), _decal_rng.randf_range(0, 360))
	for x in [-16.0, 0.0, 16.0]:
		floor_decal(_pick("stain"), Vector3(x, DOCK_Y, -16.0), Vector2(3.0, 2.4), _decal_rng.randf_range(0, 360))
