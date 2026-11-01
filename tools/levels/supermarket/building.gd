extends "res://tools/levels/supermarket/plan.gd"
## The shell: floor, walls, the roof with what hangs under it, and the lamps.

const SMALL := DETAIL | NO_COLLIDE
## How far apart the lamps of the shop are, on x and z, and how high they hang.
const LAMP_X := 18.0
const LAMP_Z := 19.0
const LAMP_Y := 4.9
const STRIP := Vector3(0.24, 0.08, 2.4)
## How far apart the rows of light fittings are, and the fittings in a row.
const FITTING_X := 3.25
const FITTING_Z := 3.6


func _describe() -> void:
	# The shell belongs to no zone: it alone keeps the sun out, and what stands
	# inside throws no shadow of the sun, see _no_sun_inside() in tools/kit/shop.gd.
	in_zone("")
	_walls()
	_roof()
	by_position()
	_floors()
	_inside_the_shell()
	_light_fittings()
	_shop_lamps()
	_daylight()
	_probes()


func _floors() -> void:
	box("shop_floor", Vector3((FRONT + BACK) * 0.5, -0.1, (NORTH_WALL + SOUTH_WALL) * 0.5), Vector3(BACK - FRONT, 0.2, SOUTH_WALL - NORTH_WALL), Vector3.ZERO, DETAIL)
	box("shop_concrete", Vector3((BACK + REAR) * 0.5, -0.1, (NORTH_WALL + SOUTH_WALL) * 0.5), Vector3(REAR - BACK, 0.2, SOUTH_WALL - NORTH_WALL), Vector3.ZERO, DETAIL)


func _walls() -> void:
	# The front: the two ways in and the long window between them.
	var openings: Array = [[WINDOW_NORTH, WINDOW_SOUTH, WINDOW_LOW, WINDOW_HIGH]]
	for z in ENTRANCES:
		openings.append([z - ENTRANCE_WIDE * 0.5, z + ENTRANCE_WIDE * 0.5, 0.0, ENTRANCE_HIGH])
	_lined(false, FRONT, 1.0, NORTH_WALL, SOUTH_WALL, 0.0, WALL_TOP, openings)
	_mullions(Vector3(FRONT, (WINDOW_LOW + WINDOW_HIGH) * 0.5, (WINDOW_NORTH + WINDOW_SOUTH) * 0.5), WINDOW_SOUTH - WINDOW_NORTH, WINDOW_HIGH - WINDOW_LOW, false, 3.0)
	# The sides and the back.
	_lined(true, NORTH_WALL, 1.0, FRONT, REAR, 0.0, WALL_TOP, [])
	_lined(true, SOUTH_WALL, -1.0, FRONT, REAR, 0.0, WALL_TOP, [])
	var dock: Array = []
	for z: float in DOCK_DOORS:
		dock.append([z - 1.8, z + 1.8, 0.0, 3.6])
	_lined(false, REAR, -1.0, NORTH_WALL, SOUTH_WALL, 0.0, WALL_TOP, dock)
	# Between the shop and the stockroom.
	var through: Array = []
	for z in BACK_DOORS:
		through.append([z - BACK_DOOR_WIDE * 0.5, z + BACK_DOOR_WIDE * 0.5, 0.0, BACK_DOOR_HIGH])
	wall("shop_white", false, BACK, 0.24, NORTH_WALL, SOUTH_WALL, 0.0, DECK, through)

## A wall with stucco on the outside and white paint on the inside, whose
## inside lies towards `inward` on the axis across it.
func _lined(along_x: bool, fixed: float, inward: float, a0: float, a1: float, y0: float, y1: float, openings: Array) -> void:
	wall("stucco", along_x, fixed, 0.3, a0, a1, y0, y1, openings)
	var keep := _wall_flags
	_wall_flags = SMALL
	wall("shop_white", along_x, fixed + inward * 0.16, 0.02, a0, a1, y0, minf(y1, DECK), openings)
	_wall_flags = keep


func _roof() -> void:
	var middle := Vector3((FRONT + REAR) * 0.5, 0, (NORTH_WALL + SOUTH_WALL) * 0.5)
	var wide := REAR - FRONT
	var deep := SOUTH_WALL - NORTH_WALL
	# From the outside a flat roof behind its walls, higher over the front.
	box("roof", middle + Vector3.UP * (DECK + 0.5), Vector3(wide, 0.5, deep), Vector3.ZERO, DETAIL)
	box("stucco", Vector3(FRONT, (WALL_TOP + PARAPET) * 0.5, 0), Vector3(0.3, PARAPET - WALL_TOP, 66.0), Vector3.ZERO, DETAIL)


func _inside_the_shell() -> void:
	# A band of colour round the shop over the cold cases, and a kick along the
	# foot of the walls.
	var inside := FRONT + 0.2
	for wall_z: float in [NORTH_WALL + 0.19, SOUTH_WALL - 0.19]:
		box("shop_cream", Vector3((inside + BACK) * 0.5, 3.0, wall_z), Vector3(BACK - inside, 2.0, 0.02), Vector3.ZERO, SMALL)
		box("shop_red", Vector3((inside + BACK) * 0.5, 4.08, wall_z), Vector3(BACK - inside, 0.14, 0.02), Vector3.ZERO, SMALL)
	box("shop_cream", Vector3(BACK - 0.14, 3.0, 0.0), Vector3(0.02, 2.0, SOUTH_WALL - NORTH_WALL), Vector3.ZERO, SMALL)
	box("shop_red", Vector3(BACK - 0.14, 4.08, 0.0), Vector3(0.02, 0.14, SOUTH_WALL - NORTH_WALL), Vector3.ZERO, SMALL)
	# What holds up the roof.
	for x: float in [13.0, 26.0, 39.5, 52.5]:
		for z in range(-36, 37, 18):
			if x > 16.0 and x < 62.0 and absf(float(z)) < 30.0 and fmod(absf(z), 18.0) == 0.0 and x != 39.5:
				continue
			box("shop_white", Vector3(x, DECK * 0.5, z), Vector3(0.4, DECK, 0.4), Vector3.ZERO, DETAIL)
			box("shop_dark", Vector3(x, 0.15, z), Vector3(0.44, 0.3, 0.44), Vector3.ZERO, SMALL)
	var middle := Vector3((FRONT + REAR) * 0.5, 0, (NORTH_WALL + SOUTH_WALL) * 0.5)
	var wide := REAR - FRONT
	var deep := SOUTH_WALL - NORTH_WALL
	# From the inside a white deck on open joists.
	box("shop_white", middle + Vector3.UP * (DECK + 0.1), Vector3(wide, 0.2, deep), Vector3.ZERO, SMALL)
	var x := FRONT + 4.0
	while x < REAR:
		box("shop_white", Vector3(x, DECK - 0.3, 0), Vector3(0.12, 0.6, deep), Vector3.ZERO, SMALL)
		x += 6.0
	var z := NORTH_WALL + 3.0
	while z < SOUTH_WALL:
		box("shop_white", Vector3((FRONT + REAR) * 0.5, DECK - 0.12, z), Vector3(wide, 0.05, 0.05), Vector3.ZERO, SMALL)
		z += 3.0
	var duct_y := DECK - 0.75
	for z_at: float in [-30.0, 0.0, 30.0]:
		round_duct(Vector3(6.0, duct_y, z_at), Vector3(60.0, duct_y, z_at), DECK, 0.42, 7)
	for line in 5:
		sprinkler_line(Vector3(4.0, DECK - 0.8, -34.0 + line * 17.0), Vector3(62.0, DECK - 0.8, -34.0 + line * 17.0), DECK, 3.0)


## The strips of light over the shop, in long rows. They are what is seen; what
## lights the shop are the lamps of _shop_lamps().
func _light_fittings() -> void:
	var x := FRONT + 3.0
	while x < BACK - 1.0:
		var z := NORTH_WALL + 2.0
		while z < SOUTH_WALL - 1.0:
			box("shop_lamp", Vector3(x, LAMP_Y, z), STRIP, Vector3.ZERO, SMALL)
			box("shop_steel", Vector3(x, LAMP_Y + 0.06, z), STRIP + Vector3(0.04, 0.0, 0.04), Vector3.ZERO, SMALL)
			for s: float in [-1.0, 1.0]:
				cylinder("shop_steel", Vector3(x, LAMP_Y + 0.08, z + s), 0.006, DECK - LAMP_Y - 0.4, SMALL, Vector3.ZERO, -1.0, 5)
			z += FITTING_Z
		x += FITTING_X


## What lights the shop while there is power. None of them throws a shadow but
## the few nearest where people meet: the rest of the light is even, as it is
## in a shop.
func _shop_lamps() -> void:
	var x := FRONT + 8.0
	while x < BACK:
		var z := NORTH_WALL + 7.0
		while z < SOUTH_WALL:
			var lamp := OmniLight3D.new()
			lamp.name = "Mains%d" % _lights.get_child_count()
			lamp.position = Vector3(x, LAMP_Y - 0.3, z)
			lamp.light_color = Color(1.0, 0.97, 0.92)
			lamp.light_energy = 2.0
			lamp.omni_range = 21.0
			lamp.omni_attenuation = 0.9
			lamp.light_bake_mode = Light3D.BAKE_DISABLED
			lamp.light_specular = 0.6
			lamp.shadow_enabled = false
			lamp.add_to_group(&"mains", true)
			_add(lamp, _lights)
			z += LAMP_Z
		x += LAMP_X


## A reflection probe holds the ambient light of the shop: the sky has no
## business under this roof, and once the mains go, this is what is left. Its
## box reaches well over and under the building, since a probe gives way to the
## sky over the last `blend_distance` of its box.
func _probes() -> void:
	var middle := Vector3((FRONT + BACK) * 0.5, DECK * 0.5, (NORTH_WALL + SOUTH_WALL) * 0.5)
	_shop_probe("Shop", middle, Vector3(BACK - FRONT + 0.6, DECK + 16.0, SOUTH_WALL - NORTH_WALL + 0.6), 0)
	var back := Vector3((BACK + REAR) * 0.5, DECK * 0.5, (NORTH_WALL + SOUTH_WALL) * 0.5)
	_shop_probe("Stock", back, Vector3(REAR - BACK + 0.6, DECK + 16.0, SOUTH_WALL - NORTH_WALL + 0.6), 1)


func _shop_probe(probe_name: String, center: Vector3, size: Vector3, slice: int) -> void:
	var node := ReflectionProbe.new()
	node.name = "Probe" + probe_name
	node.position = center
	node.size = size
	node.origin_offset = Vector3(0, -1.0, 0)
	node.box_projection = true
	node.interior = true
	node.enable_shadows = false
	node.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	node.ambient_color = Color(0.88, 0.89, 0.86)
	node.ambient_color_energy = 0.34
	node.blend_distance = 0.3
	node.max_distance = 120.0
	node.set_meta(&"slice", slice)
	node.add_to_group(&"shop_probe", true)
	_add(node, _root)


## What comes in through the glass, which the walls keep from the back of the
## store: no shadows, a long reach, falling off fast. It burns with or without
## power, and is what is left to see by when the power goes.
func _daylight() -> void:
	var spots: Array[Vector3] = [Vector3(2.0, 2.4, -25.0), Vector3(2.0, 2.8, -7.0), Vector3(2.0, 2.8, 7.0), Vector3(2.0, 2.4, 25.0)]
	for i in spots.size():
		var light := OmniLight3D.new()
		light.name = "Daylight%d" % i
		light.position = spots[i]
		light.light_color = Color(0.92, 0.82, 0.74)
		light.light_energy = 0.8
		light.omni_range = 52.0
		light.omni_attenuation = 1.7
		light.light_specular = 0.25
		light.light_bake_mode = Light3D.BAKE_DISABLED
		_add(light, _lights)
