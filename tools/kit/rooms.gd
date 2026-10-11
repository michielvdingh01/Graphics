extends "res://tools/kit/fittings.gd"
## Fifth drawer of the kit, see tools/kit.gd: a level laid out as rooms.
##
## The plan of such a level names its rooms, each a rectangle on the ground
## with a kind and a height, the doorways between them and the way through:
##
##     room("store", "storage", Rect2(0, 6, 8, 9), 3.4)
##     room("corridor", "corridor", Rect2(8, 0, 3, 20), 3.0)
##     door("store", "corridor", 10.0)
##     window("store", WEST, 10.5, 3.0)
##     keep_clear("store", Rect2(1, 7, 3, 3))
##     start_in("lobby")
##     fight("store", "the storeroom", {"store": ["grunt", "grunt"]}, "corridor")
##     exit_through("workshop", EAST, 7.0, "Leave by the loading door")
##
## The rectangle is the room with its walls, so two rooms that share a wall
## have rectangles that touch. build_rooms() then makes every room: a zone of
## its own, closed by its own floor, walls and ceiling; its doorways and
## windows, with a panel that shuts each doorway while its lightmap is baked;
## lamps and a reflection probe. Unless the level is `_bare` it also hangs the
## doors, dirties the walls and the floor and stands about what a room of
## that kind has standing about: clear of its doors and of what the plan
## keeps clear.
##
## The robots are posted last, when everything stands (see _garrison()): out
## of sight of where the player walks into their fight, starts or carries on,
## or else a good way off.
##
## What makes a room that room, a press or a boiler, goes in by hand
## afterwards, in a file of its own that the level has build its share. It
## finds its place with spot_in(): a spot in a room, counted from the room's
## north-west corner.
##
## A level is laid out and played bare first, then fitted out, then baked.

const NORTH := 0  # towards -Z
const SOUTH := 1
const WEST := 2  # towards -X
const EAST := 3

## What a kind of room is made of and fitted with: the material of its walls
## and its ceiling (none for one under the open sky), how thick its walls
## are, which lamps it has and how far apart, and what stands about in it
## (see _room_stock()).
const ROOM_KINDS := {
	"hall": {"wall": "brick", "ceiling": "roof", "thick": 0.4, "lamp": "hanging", "every": 8.0, "stock": "works", "dust": true},
	"plant": {"wall": "brick", "ceiling": "concrete", "thick": 0.4, "lamp": "hanging", "every": 7.0, "stock": "", "dust": true},
	"corridor": {"wall": "plaster_dado", "ceiling": "concrete", "thick": 0.2, "lamp": "tube", "every": 5.0, "stock": "corridor", "dust": false},
	"office": {"wall": "plaster_dado", "ceiling": "concrete", "thick": 0.2, "lamp": "tube", "every": 4.5, "stock": "office", "dust": false},
	"canteen": {"wall": "plaster_dado", "ceiling": "concrete", "thick": 0.2, "lamp": "tube", "every": 4.5, "stock": "canteen", "dust": false},
	"control": {"wall": "plaster_dado", "ceiling": "concrete", "thick": 0.2, "lamp": "tube", "every": 4.0, "stock": "", "dust": false},
	"storage": {"wall": "plaster_dado", "ceiling": "concrete", "thick": 0.2, "lamp": "tube", "every": 5.0, "stock": "storage", "dust": false},
	"yard": {"wall": "brick", "ceiling": "", "thick": 0.4, "lamp": "mast", "every": 0.0, "stock": "yard", "dust": false},
}
## How near a robot may stand in view of where the player walks into its
## fight, starts or carries on. scripts/selftest.gd holds a level to the same.
const POST_DISTANCE := 14.0

## The rooms of the plan, by name: {kind, rect, height, doors, windows, kept,
## stood, screens}. A door is {side, along, width, height, to}; `to` is the
## room on the other side, or empty for the way out. `stood` is what the
## builder has put down on the floor so far: x, z and how far it reaches.
## `screens` is where something tall has to stand for a robot to wait
## behind, {at, turn, along_x}, and `posts` where those robots were meant to
## wait when the room was planned.
var _floor_plan := {}
## The fights of the plan, in the order of the route: {id, posted, entry,
## steps_in}; `steps_in` is where the player can be on his first steps into
## it, over the whole width of the doorway.
var _fights: Array[Dictionary] = []
## Set for a level that is still being laid out: the rooms come without
## doors, dirt or anything standing about, to walk and fight through first.
var _bare := false


# --- The plan -----------------------------------------------------------------


## A room: `rect` is its place on the ground (x and z) with its walls, and
## `kind` one of ROOM_KINDS. It is a zone of that name from here on.
func room(room_name: String, kind: String, rect: Rect2, height: float) -> void:
	if not ROOM_KINDS.has(kind):
		push_error("room: there is no kind of room called '%s'" % kind)
		return
	_floor_plan[room_name] = {"kind": kind, "rect": rect, "height": height, "doors": [], "windows": [], "kept": [], "stood": [], "screens": [], "posts": []}
	zone(room_name, [AABB(Vector3(rect.position.x, -1.0, rect.position.y), Vector3(rect.size.x, height + 1.5, rect.size.y))])
	# What it sounds like in there, for scripts/sfx.gd to pick its reverb by.
	var space := {"hall": &"hall", "plant": &"hall", "yard": &"yard"}
	(_zones[room_name].node as Node).set_meta(&"space", space.get(kind, &"room"))


## A doorway between two rooms that share a wall. `along` is where its
## middle is along that wall: its x for a wall that runs east to west, its z
## for one that runs north to south. One that is 1.6 m wide and 2.2 m high
## gets double steel doors; anything else is left open under a lintel.
func door(first: String, second: String, along: float, width := 1.6, height := 2.2) -> void:
	var a: Rect2 = _floor_plan[first].rect
	var b: Rect2 = _floor_plan[second].rect
	var side := -1
	var shared := Vector2.ZERO
	if is_equal_approx(a.end.x, b.position.x) or is_equal_approx(a.position.x, b.end.x):
		side = EAST if is_equal_approx(a.end.x, b.position.x) else WEST
		shared = Vector2(maxf(a.position.y, b.position.y), minf(a.end.y, b.end.y))
	elif is_equal_approx(a.end.y, b.position.y) or is_equal_approx(a.position.y, b.end.y):
		side = SOUTH if is_equal_approx(a.end.y, b.position.y) else NORTH
		shared = Vector2(maxf(a.position.x, b.position.x), minf(a.end.x, b.end.x))
	if side < 0 or along - width * 0.5 < shared.x + 0.45 or along + width * 0.5 > shared.y - 0.45:
		push_error("door: '%s' and '%s' share no wall at %s" % [first, second, along])
		return
	_floor_plan[first].doors.append({"side": side, "along": along, "width": width, "height": height, "to": second, "hangs": true})
	_floor_plan[second].doors.append({"side": side ^ 1, "along": along, "width": width, "height": height, "to": first, "hangs": false})


## A window in an outside wall of a room, `width` wide around `along`, from
## `sill` up to `head`.
func window(room_name: String, side: int, along: float, width: float, sill := 1.1, head := 2.6) -> void:
	_floor_plan[room_name].windows.append({"side": side, "along": along, "width": width, "sill": sill, "head": head})


## Keeps a part of the floor of a room (x and z in the level) free of
## whatever the builder would stand there: for what goes in by hand.
func keep_clear(room_name: String, area: Rect2) -> void:
	_floor_plan[room_name].kept.append(area)


## A spot in a room: `x` and `z` metres from its north-west corner, walls
## included, and `y` above its floor.
func spot_in(room_name: String, x: float, z: float, y := 0.0) -> Vector3:
	var rect: Rect2 = _floor_plan[room_name].rect
	return Vector3(rect.position.x + x, y, rect.position.y + z)


# --- The way through, in the order the player goes ------------------------------


## The player starts in the middle of that room, facing its first door.
func start_in(room_name: String) -> void:
	var middle := _room_middle(room_name)
	var doors: Array = _floor_plan[room_name].doors
	var look := _door_spot(room_name, doors[0], 0.0) if not doors.is_empty() else middle + Vector2.RIGHT
	keep_clear(room_name, Rect2(middle - Vector2.ONE, Vector2.ONE * 2.0))
	route_start(Vector3(middle.x, 0, middle.y), Vector3(look.x, 0, look.y))


## A fight: robots hold one room or several that lie together, such as a
## corridor and the rooms off it. `posted` names for each of those rooms the
## kinds of robot that stand in it, as in {"corridor": ["rusher"], "office":
## ["grunt", "grunt"]}. The fight begins when the player walks into the
## rectangle the rooms make together, which he does from the room
## `entered_from`; `title` is what the HUD calls the place, as in "Clear the
## offices". Has to come after the doors of those rooms. Without `screens`
## nothing is stood in the room the player walks into for its robots to wait
## behind: for a room where what goes in by hand hides them.
func fight(id: String, title: String, posted: Dictionary, entered_from := "", screens := true) -> void:
	var area := Rect2()
	var high := 0.0
	var entry := Vector2.INF
	var first := ""
	var steps_in: Array[Vector2] = []
	for room_name: String in posted:
		var plan: Dictionary = _floor_plan[room_name]
		area = plan.rect if area.size == Vector2.ZERO else area.merge(plan.rect)
		high = maxf(high, plan.height)
		for way: Dictionary in plan.doors:
			if entry == Vector2.INF and (way.to == entered_from or entered_from == ""):
				entry = _door_spot(room_name, way, 0.8)
				first = room_name
				# Anywhere a player fits through the doorway, not only down
				# its middle: from beside a jamb he looks past a screen.
				var aside: float = way.width * 0.5 - 0.4
				var across := ceili(aside / 0.4)
				for off: float in [0.3, 0.8, 1.6, 2.4]:
					for i in range(-across, across + 1):
						var spot := _wall_spot(room_name, way.side, way.along + aside * i / across, off)
						steps_in.append(Vector2(spot.x, spot.z))
	if entry == Vector2.INF:
		push_error("fight: no door leads from '%s' into '%s'" % [entered_from, id])
		return
	# The room the player walks into has nothing between the door and its
	# robots but what is put there: something tall for each to wait behind,
	# unless the room is deep enough to stand far off.
	if screens:
		_plan_screens(first, (posted[first] as Array).size(), entry)
	_fights.append({"id": id, "posted": posted, "entry": entry, "steps_in": steps_in})
	area = area.grow(-0.2)
	# The robots are posted when everything stands, see _garrison().
	route_zone(id, title, AABB(Vector3(area.position.x, 0, area.position.y), Vector3(area.size.x, minf(high, 4.0), area.size.y)), [])


## A place to carry on from, in the middle of that room, once everything
## before it is cleared. The room may not be fought over later on.
func checkpoint_in(room_name: String, title: String) -> void:
	var middle := _room_middle(room_name)
	var doors: Array = _floor_plan[room_name].doors
	var look := _door_spot(room_name, doors[-1], 0.0) if not doors.is_empty() else middle + Vector2.RIGHT
	var inner := _room_inside(room_name)
	keep_clear(room_name, Rect2(middle - Vector2.ONE, Vector2.ONE * 2.0))
	route_checkpoint(room_name, title, Vector3(middle.x, 0, middle.y), Vector3(look.x, 0, look.y), AABB(Vector3(inner.position.x, 0, inner.position.y), Vector3(inner.size.x, 3.0, inner.size.y)))


## The way out of the level: a roller door in an outside wall of that room,
## which goes up when every fight is won. `next` names the level it leads to.
func exit_through(room_name: String, side: int, along: float, title: String, next := "", width := 4.0, height := 4.0) -> void:
	var plan: Dictionary = _floor_plan[room_name]
	if plan.height < height + 1.0:
		push_error("exit_through: '%s' is too low for a door of %s m with its roll above it" % [room_name, height])
		return
	var way := {"side": side, "along": along, "width": width, "height": height, "to": "", "hangs": true}
	plan.doors.append(way)
	var out := -_normal_in(side)
	var sideways := Vector3(absf(out.z), 0, absf(out.x))
	var outside := _wall_spot(room_name, side, along, -_thick(room_name) - 2.0)
	var size := out.abs() * 3.0 + sideways * (width + 3.0) + Vector3.UP * (height + 0.5)
	var lamp_at := _wall_spot(room_name, side, along, 0.0, height + 0.7)
	route_exit(title, AABB(outside - size * 0.5 + Vector3.UP * (size.y * 0.5 - 0.3), size), next, lamp_at, -out)


# --- Building -------------------------------------------------------------------


## Builds every room of the plan.
func build_rooms() -> void:
	for room_name: String in _floor_plan:
		build_room(room_name)


func build_room(room_name: String) -> void:
	# Dice of its own for every room: what changes in one leaves the lamps
	# and the crates of the next as they were, and its lightmap with them.
	_seed_dice("%s/%s" % [_level_name(), room_name])
	_room_shell(room_name)
	_room_lamps(room_name)
	if _bare:
		return
	_room_doors(room_name)
	_room_dirt(room_name)
	_room_stock(room_name)


## Floor, ceiling and four walls with the doorways and windows cut out, a
## panel in every doorway for the bake, glazing in the windows and a probe.
func _room_shell(room_name: String) -> void:
	var plan: Dictionary = _floor_plan[room_name]
	var kind: Dictionary = ROOM_KINDS[plan.kind]
	var rect: Rect2 = plan.rect
	var thick: float = kind.thick
	var high: float = plan.height
	var middle := rect.get_center()
	box("floor", Vector3(middle.x, -0.25, middle.y), Vector3(rect.size.x, 0.5, rect.size.y))
	if kind.ceiling != "":
		box(kind.ceiling, Vector3(middle.x, high + 0.15, middle.y), Vector3(rect.size.x, 0.3, rect.size.y))
	for side in 4:
		var openings: Array = []
		for way: Dictionary in plan.doors:
			if way.side == side:
				openings.append([way.along - way.width * 0.5, way.along + way.width * 0.5, 0.0, way.height])
		for pane: Dictionary in plan.windows:
			if pane.side == side:
				openings.append([pane.along - pane.width * 0.5, pane.along + pane.width * 0.5, pane.sill, pane.head])
		match side:
			NORTH:
				wall(kind.wall, true, rect.position.y + thick * 0.5, thick, rect.position.x, rect.end.x, 0.0, high, openings)
			SOUTH:
				wall(kind.wall, true, rect.end.y - thick * 0.5, thick, rect.position.x, rect.end.x, 0.0, high, openings)
			WEST:
				wall(kind.wall, false, rect.position.x + thick * 0.5, thick, rect.position.y + thick, rect.end.y - thick, 0.0, high, openings)
			EAST:
				wall(kind.wall, false, rect.end.x - thick * 0.5, thick, rect.position.y + thick, rect.end.y - thick, 0.0, high, openings)
		if kind.ceiling == "":
			# A wall under the open sky ends in coping stones.
			var along_x := side == NORTH or side == SOUTH
			var span := _wall_span(room_name, side)
			var top := _wall_spot(room_name, side, (span.x + span.y) * 0.5, -thick * 0.5, high + 0.06)
			box("concrete", top, Vector3(span.y - span.x + thick * 2.0, 0.12, thick + 0.2) if along_x else Vector3(thick + 0.2, 0.12, span.y - span.x + thick * 2.0), Vector3.ZERO, NO_COLLIDE)
	for way: Dictionary in plan.doors:
		var across := Vector3(absf(_normal_in(way.side).z), 0, absf(_normal_in(way.side).x))
		if way.to == "":
			_room_exit(room_name, way)
			continue
		# Shut for the bake right where the two rooms meet, on this side of it.
		var panel := _wall_spot(room_name, way.side, way.along, -thick + 0.01, way.height * 0.5 + 0.05)
		bake_blocker(panel, across * (way.width + 0.2) + Vector3.UP * (way.height + 0.1) + _normal_in(way.side).abs() * 0.02)
	for pane: Dictionary in plan.windows:
		var along_x: bool = pane.side == NORTH or pane.side == SOUTH
		var tall: float = pane.head - pane.sill
		var glazing := _wall_spot(room_name, pane.side, pane.along, -thick * 0.5, pane.sill + tall * 0.5)
		_mullions(glazing, pane.width, tall, along_x, 1.0)
		var ledge := Vector3(pane.width + 0.2, 0.08, thick + 0.2) if along_x else Vector3(thick + 0.2, 0.08, pane.width + 0.2)
		box("concrete", _wall_spot(room_name, pane.side, pane.along, -thick * 0.5 + 0.05, pane.sill - 0.04), ledge, Vector3.ZERO, NO_COLLIDE)
	var inner := _room_inside(room_name)
	probe(room_name.to_pascal_case(), Vector3(middle.x, high * 0.5, middle.y), Vector3(inner.size.x, high, inner.size.y), Vector3.ZERO)
	if kind.dust:
		dust(AABB(Vector3(inner.position.x, 0.2, inner.position.y), Vector3(inner.size.x, high - 0.6, inner.size.y)), int(inner.get_area() * 4.0))


## The roller door of the way out, in its doorway, with a steel frame.
func _room_exit(room_name: String, way: Dictionary) -> void:
	var thick := _thick(room_name)
	var inwards := _normal_in(way.side)
	var across := Vector3(absf(inwards.z), 0, absf(inwards.x))
	var tall: float = way.height - 0.42
	roller_door(_wall_spot(room_name, way.side, way.along, -thick * 0.5 - 0.01, tall * 0.5), inwards, Vector2(way.width, tall), true)
	for edge: float in [-1.0, 1.0]:
		box("steel", _wall_spot(room_name, way.side, way.along, 0.1, (way.height + 0.2) * 0.5) + across * edge * (way.width * 0.5 + 0.1), across * 0.2 + inwards.abs() * 0.2 + Vector3.UP * (way.height + 0.2))
	box("steel", _wall_spot(room_name, way.side, way.along, 0.1, way.height + 0.1), across * (way.width + 0.4) + inwards.abs() * 0.2 + Vector3.UP * 0.25)


## Tubes under a low ceiling, hall lamps under a high one, floodlights on
## masts under the open sky: about as far apart as the kind of room says,
## most of them still working.
func _room_lamps(room_name: String) -> void:
	var plan: Dictionary = _floor_plan[room_name]
	var kind: Dictionary = ROOM_KINDS[plan.kind]
	var inner := _room_inside(room_name)
	var high: float = plan.height
	var lit := 0
	if kind.lamp == "mast":
		# One in each of two corners, across the yard from each other.
		var middle := Vector3(inner.get_center().x, 0, inner.get_center().y)
		for corner: Vector2 in [inner.position + Vector2.ONE * 1.2, inner.end - Vector2.ONE * 1.2]:
			var foot := Vector3(corner.x, 0, corner.y)
			floodlight(foot, foot.lerp(middle, 0.7))
			plan.stood.append(Vector3(corner.x, corner.y, 0.8))
		return
	if kind.lamp == "tube":
		var along_x := inner.size.x >= inner.size.y
		var length := inner.size.x if along_x else inner.size.y
		var count := maxi(1, roundi(length / kind.every))
		for i in count:
			var on := i == 0 or _rng.randf() < 0.75
			var spot := inner.get_center()
			if along_x:
				spot.x = inner.position.x + length * (i + 0.5) / count
			else:
				spot.y = inner.position.y + length * (i + 0.5) / count
			tube(Vector3(spot.x, high - 0.08, spot.y), along_x, on, lit < 2)
			lit += int(on)
		return
	var across := maxi(1, roundi(inner.size.x / kind.every))
	var down := maxi(1, roundi(inner.size.y / kind.every))
	for i in across:
		for j in down:
			var on := lit == 0 or _rng.randf() < 0.6
			var spot := inner.position + inner.size * Vector2(i + 0.5, j + 0.5) / Vector2(across, down)
			lamp(Vector3(spot.x, high - 0.9, spot.y), high, on, on and lit < 2)
			lit += int(on)


## Floodlight mast aimed at a point on the ground.
func floodlight(foot: Vector3, target: Vector3) -> void:
	var height := 10.0
	box("concrete", foot + Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.9))
	box("steel", foot + Vector3(0, height * 0.5, 0), Vector3(0.22, height, 0.22))
	var head := foot + Vector3(0, height, 0)
	var aim := _along(target - head)
	_box("steel", Transform3D(aim, head), Vector3(1.6, 0.12, 0.12), DETAIL | NO_COLLIDE)
	for offset: float in [-0.55, 0.55]:
		var housing := Transform3D(aim, head) * Transform3D(Basis(), Vector3(offset, 0, -0.2))
		_box("machine", housing, Vector3(0.5, 0.4, 0.3), DETAIL | NO_COLLIDE)
		_box("emissive_warm", housing * Transform3D(Basis(), Vector3(0, 0, -0.16)), Vector3(0.42, 0.32, 0.02), DETAIL | NO_COLLIDE)
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
	_add(light, _group("Lights", foot + Vector3.UP))


## Hangs the doors: double steel doors where the doorway has their measure,
## and a steel lintel over any other. Each doorway is hung once, by the room
## it was named first for.
func _room_doors(room_name: String) -> void:
	for way: Dictionary in _floor_plan[room_name].doors:
		if not way.hangs or way.to == "":
			continue
		var mine := _thick(room_name)
		var theirs := _thick(way.to)
		var out := -_normal_in(way.side)
		# The middle of the two walls that stand back to back here.
		var spot := _wall_spot(room_name, way.side, way.along, -mine) + out * (theirs - mine) * 0.5
		if is_equal_approx(way.width, 1.6) and is_equal_approx(way.height, 2.2):
			# The leaves swing into the room on the far side.
			var turn := {EAST: 0.0, WEST: PI, SOUTH: -PI * 0.5, NORTH: PI * 0.5}
			doorway(Transform3D(Basis(Vector3.UP, turn[way.side]), spot), mine + theirs, _rng.randf_range(85.0, 110.0), _rng.randf_range(150.0, 170.0))
		else:
			var across := Vector3(absf(out.z), 0, absf(out.x))
			box("steel", spot + Vector3.UP * (way.height + 0.08), across * (way.width + 0.4) + out.abs() * (mine + theirs + 0.06) + Vector3.UP * 0.16, Vector3.ZERO, NO_COLLIDE)


## Grime where the walls meet the floor, rain under the windows and stains on
## the floor.
func _room_dirt(room_name: String) -> void:
	var plan: Dictionary = _floor_plan[room_name]
	var inner := _room_inside(room_name)
	for side in 4:
		for span: Vector2 in _free_spans(room_name, side, 0.2, false):
			var pieces := ceili((span.y - span.x) / 10.0)
			for i in pieces:
				var length := (span.y - span.x) / pieces
				wall_decal("grime", _wall_spot(room_name, side, span.x + length * (i + 0.5), 0.1, 0.6), _normal_in(side), length, 1.2)
	for pane: Dictionary in plan.windows:
		var tall := minf(2.8, pane.sill + 0.5)
		var at_wall := _wall_spot(room_name, pane.side, pane.along + _decal_rng.randf_range(-0.3, 0.3) * pane.width, 0.04, pane.sill + 0.2 - tall * 0.5)
		wall_decal(_pick("leak"), at_wall, _normal_in(pane.side), minf(1.6, pane.width), tall)
	for i in int(inner.get_area() / 30.0):
		var spot := inner.position + Vector2(_decal_rng.randf_range(1.0, maxf(1.0, inner.size.x - 1.0)), _decal_rng.randf_range(1.0, maxf(1.0, inner.size.y - 1.0)))
		var size := _decal_rng.randf_range(1.5, 3.2)
		floor_decal(_pick("stain"), Vector3(spot.x, 0, spot.y), Vector2(size, size * _decal_rng.randf_range(0.7, 1.3)), _decal_rng.randf_range(0, 360))


## What stands about in a room of its kind.
func _room_stock(room_name: String) -> void:
	var plan: Dictionary = _floor_plan[room_name]
	_room_screens(room_name)
	match ROOM_KINDS[plan.kind].stock:
		"storage":
			# Racks along the walls, and what would not fit on them in between.
			var racks := 0
			for side in 4:
				for span: Vector2 in _free_spans(room_name, side, 1.0, true):
					var count := int((span.y - span.x) / 3.3)
					for i in count:
						var spot := _wall_spot(room_name, side, span.x + (span.y - span.x) * (i + 0.5) / count, 0.45)
						if racks < 10 and _room_free(room_name, Vector2(spot.x, spot.z), 0.4):
							shelf(spot, _yaw_in(side), _rng.randf() < 0.6)
							plan.stood.append(Vector3(spot.x, spot.z, 1.5))
							racks += 1
			_room_islands(room_name, 3.8, ["crates", "crates", "pallet", "bags"], 2, 4)
		"works":
			# Something against a wall every few metres, and cover on the floor.
			for side in 4:
				for span: Vector2 in _free_spans(room_name, side, 1.2, true):
					var count := int((span.y - span.x) / 4.5) if span.y - span.x >= 4.5 else int(span.y - span.x >= 3.2)
					for i in count:
						var along := span.x + (span.y - span.x) * (i + 0.5) / count
						var spot := _wall_spot(room_name, side, along, 0.5)
						if not _room_free(room_name, Vector2(spot.x, spot.z), 1.0):
							continue
						plan.stood.append(Vector3(spot.x, spot.z, 1.5))
						match _rng.randi_range(0, 4):
							0, 1:
								shelf(_wall_spot(room_name, side, along, 0.45), _yaw_in(side), true)
							2:
								cabinets(_wall_spot(room_name, side, along, 0.5), _yaw_in(side))
							3:
								tyres(_wall_spot(room_name, side, along, 0.6), _rng.randi_range(2, 4))
							4:
								for k in 3:
									barrel(_wall_spot(room_name, side, along + (k - 1) * 0.75, 0.55 + (k % 2) * 0.35))
			_room_islands(room_name, 4.0, ["crates", "crates", "barrier", "barrier", "pallet", "bags", "barrels"], 3, 5)
		"yard":
			# Containers first, one or two high, then smaller things between them.
			var colours: Array[String] = ["container_red", "container_green", "container_blue", "container_orange", "container_grey"]
			for spot in _room_spread(room_name, 3.2, 9.0, 3.6):
				var along_x := _rng.randf() < 0.5
				var on_ground := Vector3(spot.x, 0, spot.y)
				container(colours[_rng.randi_range(0, colours.size() - 1)], on_ground, along_x)
				if _rng.randf() < 0.4:
					var nudge := Vector3(_rng.randf_range(-0.3, 0.3), 2.6, 0) if along_x else Vector3(0, 2.6, _rng.randf_range(-0.3, 0.3))
					container(colours[_rng.randi_range(0, colours.size() - 1)], on_ground + nudge, along_x)
			_room_islands(room_name, 4.5, ["crates", "barrier", "barrier", "pallet", "barrels", "bags"], 3, 5)
		"office":
			var doors: Array = plan.doors
			var facing: int = (doors[0].side ^ 1) if not doors.is_empty() else NORTH
			var longest := _longest(_free_spans(room_name, facing, 0.8, false))
			if longest.y - longest.x >= 2.0:
				var along := (longest.x + longest.y) * 0.5
				place(DESK, _wall_spot(room_name, facing, along, 0.5), _yaw_in(facing))
				place("plastic_monobloc_chair_01", _wall_spot(room_name, facing, along + 0.2, 1.4), _yaw_in(facing) + 180.0 + _rng.randf_range(-25.0, 25.0))
			var beside := [WEST, EAST] if facing == NORTH or facing == SOUTH else [NORTH, SOUTH]
			for side: int in beside:
				var span := _longest(_free_spans(room_name, side, 0.8, true))
				if span.y - span.x < 1.6:
					continue
				cupboard("machine", _wall_spot(room_name, side, span.x + 0.8, 0.33), _yaw_in(side), Vector3(0.98, 1.9, 0.6))
				if span.y - span.x >= 3.2:
					var size: Vector3 = _model("cardboard_box_01").box.size
					var corner := _wall_spot(room_name, side, span.y - 0.6, 0.45)
					place("cardboard_box_01", corner, _yaw_in(side) + 8.0)
					place("cardboard_box_01", corner + Vector3(0.02, size.y, 0.02), _yaw_in(side) - 14.0)
		"canteen":
			# Tables in rows with chairs at them, and a cupboard against a wall.
			var table: Vector3 = _model("WoodenTable_03").box.size
			for spot in _room_spread(room_name, 1.8, 3.4, 1.5):
				var turn := 90.0 if _rng.randf() < 0.5 else 0.0
				var facing := Basis(Vector3.UP, deg_to_rad(turn))
				place("WoodenTable_03", Vector3(spot.x, 0, spot.y), turn)
				for seat: float in [-1.0, 1.0]:
					if _rng.randf() < 0.8:
						place("plastic_monobloc_chair_01", Vector3(spot.x, 0, spot.y) + facing * Vector3(_rng.randf_range(-0.3, 0.3), 0, seat * (table.z * 0.5 + 0.45)), turn + (180.0 if seat > 0.0 else 0.0) + _rng.randf_range(-20.0, 20.0))
			for side in 4:
				var span := _longest(_free_spans(room_name, side, 0.8, true))
				if span.y - span.x >= 2.0:
					cupboard("machine", _wall_spot(room_name, side, span.x + 0.8, 0.33), _yaw_in(side), Vector3(0.98, 1.9, 0.6))
					break
		"corridor":
			# A fire point by every other door, and pipes under the ceiling.
			var count := 0
			for way: Dictionary in plan.doors:
				count += 1
				if count % 2 == 0:
					continue
				var beside: float = way.along + way.width * 0.5 + 0.7
				var span := _wall_span(room_name, way.side)
				if beside > span.y - 0.3:
					beside = way.along - way.width * 0.5 - 0.7
				place("korean_fire_extinguisher_01", _wall_spot(room_name, way.side, beside, 0.2), _yaw_in(way.side))
				mount("fire_alarm", _wall_spot(room_name, way.side, beside + 0.35, 0.0, 1.4), _yaw_in(way.side), true)
			var inner := _room_inside(room_name)
			var high: float = plan.height
			if inner.size.x >= inner.size.y:
				cylinder("pipe", Vector3(inner.position.x, high - 0.4, inner.position.y + 0.3), 0.09, inner.size.x, NO_COLLIDE, Vector3(0, 0, -90))
				cylinder("steel", Vector3(inner.position.x, high - 0.3, inner.position.y + 0.55), 0.05, inner.size.x, NO_COLLIDE, Vector3(0, 0, -90))
			else:
				cylinder("pipe", Vector3(inner.position.x + 0.3, high - 0.4, inner.position.y), 0.09, inner.size.y, NO_COLLIDE, Vector3(90, 0, 0))
				cylinder("steel", Vector3(inner.position.x + 0.55, high - 0.3, inner.position.y), 0.05, inner.size.y, NO_COLLIDE, Vector3(90, 0, 0))


## Things to take cover behind, on the floor of a room away from its walls:
## as many as fit about `pitch` metres apart where the floor is free. `kinds`
## is what to draw from, and crates come `fewest` to `most` to a stack.
func _room_islands(room_name: String, pitch: float, kinds: Array, fewest: int, most: int) -> void:
	for spot in _room_spread(room_name, 2.2, pitch, 1.3):
		var on_floor := Vector3(spot.x, 0, spot.y)
		var turn := _rng.randf_range(0.0, 360.0)
		match kinds[_rng.randi_range(0, kinds.size() - 1)]:
			"crates":
				crates(on_floor, _rng.randi_range(fewest, most))
			"pallet":
				pallet(on_floor, turn, _rng.randi_range(2, 4))
			"bags":
				bags(on_floor, turn, _rng.randi_range(3, 5), _rng.randi_range(1, 2))
			"barrier":
				barrier(on_floor, turn)
			"barrels":
				for k in 3:
					var beside := on_floor + Vector3(cos(k * 2.1), 0, sin(k * 2.1)) * 0.5
					if k == 0 and _rng.randf() < 0.4:
						fuel(beside)
					else:
						barrel(beside)


## Spots on the floor of a room for things that reach `reach` around them:
## `inset` from its walls, `pitch` apart, where the floor is free. Every spot
## a metre and a half from the next is tried, in an order the dice decide.
## What is returned counts as stood on from then on.
func _room_spread(room_name: String, inset: float, pitch: float, reach: float) -> Array[Vector2]:
	var plan: Dictionary = _floor_plan[room_name]
	var floor_left := _room_inside(room_name).grow(-inset)
	var taken: Array[Vector2] = []
	if floor_left.size.x <= 0.0 or floor_left.size.y <= 0.0:
		return taken
	var spots: Array[Vector2] = []
	var x := floor_left.position.x
	while x <= floor_left.end.x + 0.01:
		var z := floor_left.position.y
		while z <= floor_left.end.y + 0.01:
			spots.append(Vector2(x, z) + Vector2(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.4, 0.4)))
			z += 1.5
		x += 1.5
	for i in range(spots.size() - 1, 0, -1):
		var other := _rng.randi_range(0, i)
		var held := spots[i]
		spots[i] = spots[other]
		spots[other] = held
	for spot in spots:
		if taken.any(func(island: Vector2) -> bool: return island.distance_to(spot) < pitch) or not _room_free(room_name, spot, reach):
			continue
		taken.append(spot)
		plan.stood.append(Vector3(spot.x, spot.y, reach))
	return taken


# --- The robots -----------------------------------------------------------------


## Plans where `count` robots can wait in a room out of sight of `entry`,
## the spot the player comes in at: two by two, as far from it as the floor
## allows and well apart, each pair behind something tall that _room_stock()
## will stand between it and the door. A pair that stands far enough off
## needs nothing.
func _plan_screens(room_name: String, count: int, entry: Vector2) -> void:
	var plan: Dictionary = _floor_plan[room_name]
	if ROOM_KINDS[plan.kind].stock == "corridor":
		return
	var floor_left := _room_inside(room_name).grow(-2.2)
	var spots: Array[Vector2] = []
	var x := floor_left.position.x
	while x <= floor_left.end.x + 0.01:
		var z := floor_left.position.y
		while z <= floor_left.end.y + 0.01:
			if _room_free(room_name, Vector2(x, z), 1.6) and entry.distance_to(Vector2(x, z)) > 5.0:
				spots.append(Vector2(x, z))
			z += 1.0
		x += 1.0
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(entry) > b.distance_to(entry))
	var pairs: Array[Vector2] = []
	for apart: float in [5.5, 4.4]:
		for spot in spots:
			if pairs.size() * 2 < count and not pairs.any(func(pair: Vector2) -> bool: return pair.distance_to(spot) < apart):
				pairs.append(spot)
	var open_air: bool = plan.kind == "yard"
	for pair in pairs:
		var towards := (entry - pair).normalized()
		var across := Vector2(-towards.y, towards.x)
		for side: float in [-0.9, 0.9]:
			plan.posts.append(pair + across * side)
			# Room to stand in, and to step out from behind the stacks.
			plan.stood.append(Vector3(pair.x + across.x * side, pair.y + across.y * side, 1.0))
		if pair.distance_to(entry) > POST_DISTANCE + 3.0:
			continue
		var stands := pair + towards * (2.4 if open_air else 1.5)
		plan.screens.append({"at": stands, "turn": rad_to_deg(atan2(-across.y, across.x)), "along_x": absf(across.x) > absf(across.y)})
		plan.stood.append(Vector3(stands.x, stands.y, 3.4 if open_air else 2.2))


## Stands something tall where a robot is to wait behind it: a container in
## a yard, a cupboard in an office, a high stack of pallets anywhere else.
func _room_screens(room_name: String) -> void:
	var plan: Dictionary = _floor_plan[room_name]
	for screen: Dictionary in plan.screens:
		var on_floor := Vector3(screen.at.x, 0, screen.at.y)
		match ROOM_KINDS[plan.kind].stock:
			"yard":
				container(["container_red", "container_green", "container_blue", "container_grey"][_rng.randi_range(0, 3)], on_floor, screen.along_x)
			"office", "canteen":
				cupboard("machine", on_floor, screen.turn, Vector3(2.4, 1.9, 0.5))
			_:
				# Three stacks side by side, of unequal height.
				var sideways := Basis(Vector3.UP, deg_to_rad(screen.turn)) * Vector3.RIGHT
				for along: float in [-1.25, 0.0, 1.25]:
					pallet(on_floor + sideways * along, screen.turn + _rng.randf_range(-4.0, 4.0), _rng.randi_range(12, 14))


## Posts the robots of every fight, now that everything stands. A robot goes
## where it can be walked to and where it is out of sight of the door the
## player comes in by, of where he starts and of every checkpoint, or else
## POST_DISTANCE from them; as far from that door as the room allows, and a
## few steps from the next robot. Called by the builder from _survey().
func _garrison(space: PhysicsDirectSpaceState3D, ray: PhysicsRayQueryParameters3D, navmesh: NavigationMesh, walked: Dictionary) -> void:
	if _fights.is_empty() or _route == null:
		return
	# The floor that can be walked on, polygon by polygon.
	var corners := navmesh.get_vertices()
	var floors: Array[Dictionary] = []
	for p in navmesh.get_polygon_count():
		if not walked.has(corners.size() + p):
			continue
		var outline := PackedVector2Array()
		var around := Rect2()
		var height := 0.0
		var polygon := navmesh.get_polygon(p)
		for corner in polygon:
			var flat := Vector2(corners[corner].x, corners[corner].z)
			outline.append(flat)
			around = Rect2(flat, Vector2.ZERO) if outline.size() == 1 else around.expand(flat)
			height += corners[corner].y / polygon.size()
		floors.append({"outline": outline, "around": around, "height": height})
	for battle in _fights:
		var area: Area3D = null
		for step in _route.get_children():
			if step.is_in_group("route_zone") and step.get_meta(&"id") == battle.id:
				area = step
		# Where the player comes in, and where he appears without having
		# fought his way there: at the start and at every checkpoint that
		# comes before this fight.
		var watched: Array[Vector3] = []
		for step_in: Vector2 in battle.steps_in:
			watched.append(Vector3(step_in.x, 1.6, step_in.y))
		for step: Node3D in _route.get_children():
			if step.get_index() > area.get_index():
				continue
			if step.name == &"Start":
				watched.append(step.position + Vector3.UP * 1.6)
			elif step.has_node("Respawn"):
				watched.append(step.transform * (step.get_node("Respawn") as Node3D).position + Vector3.UP * 1.6)
		var exposed := 0
		for room_name: String in battle.posted:
			var kinds: Array = battle.posted[room_name]
			var floor_left := _room_inside(room_name).grow(-0.9)
			var hidden: Array[Vector2] = []
			var shown: Array[Vector2] = []
			# Where the plan meant them to wait, and every other spot a
			# metre from the next.
			var tried: Array[Vector2] = []
			tried.assign(_floor_plan[room_name].posts)
			var x := floor_left.position.x
			while x <= floor_left.end.x + 0.01:
				var z := floor_left.position.y
				while z <= floor_left.end.y + 0.01:
					tried.append(Vector2(x, z))
					z += 1.0
				x += 1.0
			for spot in tried:
				if not floors.any(func(piece: Dictionary) -> bool: return absf(piece.height) < 1.0 and piece.around.has_point(spot) and Geometry2D.is_point_in_polygon(spot, piece.outline)):
					continue
				var seen := false
				for eye in watched:
					# A good two steps more than the selftest asks: it looks from
					# where its own way into the fight happens to lead.
					if seen or eye.distance_to(Vector3(spot.x, 1.6, spot.y)) >= POST_DISTANCE + 2.0:
						continue
					ray.from = eye
					for up: float in [1.5, 0.8]:
						ray.to = Vector3(spot.x, up, spot.y)
						seen = seen or space.intersect_ray(ray).is_empty()
				(shown if seen else hidden).append(spot)
			# Out of sight if there is room for it, and in sight only for
			# whoever is left. The first stands furthest from the door, and
			# each next one as far as can be from the door and from those
			# that stand already: spread over the room, not in a row.
			var posts: Array[Vector2] = []
			for among: Array[Vector2] in [hidden, shown]:
				while posts.size() < kinds.size():
					var best := Vector2.INF
					var reach := 1.3
					for spot in among:
						var room_to := spot.distance_to(battle.entry) * 0.5
						for post in posts:
							room_to = minf(room_to, post.distance_to(spot))
						if room_to > reach:
							reach = room_to
							best = spot
					if best == Vector2.INF:
						break
					posts.append(best)
					exposed += int(among == shown and not shown.is_empty() and best in shown and best not in hidden)
			if posts.size() < kinds.size():
				push_error("Route: '%s' has room for %d robots, not for %d" % [room_name, posts.size(), kinds.size()])
			for i in posts.size():
				var spawn := Marker3D.new()
				spawn.name = (kinds[i] as String).capitalize()
				spawn.position = Vector3(posts[i].x, 0, posts[i].y) - area.position
				spawn.set_meta(&"kind", kinds[i])
				spawn.add_to_group("enemy_spawn", true)
				_add(spawn, area)
		if exposed:
			print("Route: %d of the robots of '%s' stand in view of where the player comes in" % [exposed, battle.id])


# --- Where things are in a room -------------------------------------------------


func _thick(room_name: String) -> float:
	return ROOM_KINDS[_floor_plan[room_name].kind].thick


func _room_middle(room_name: String) -> Vector2:
	return (_floor_plan[room_name].rect as Rect2).get_center()


## The floor of a room between its walls.
func _room_inside(room_name: String) -> Rect2:
	return (_floor_plan[room_name].rect as Rect2).grow(-_thick(room_name))


## The way from a wall of a room into the room.
func _normal_in(side: int) -> Vector3:
	return [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT][side]


## The turn that makes something with its back to that wall face the room.
func _yaw_in(side: int) -> float:
	return [0.0, 180.0, 90.0, -90.0][side]


## From where to where the inside of a wall of a room runs, along the wall.
func _wall_span(room_name: String, side: int) -> Vector2:
	var inner := _room_inside(room_name)
	if side == NORTH or side == SOUTH:
		return Vector2(inner.position.x, inner.end.x)
	return Vector2(inner.position.y, inner.end.y)


## A spot by a wall of a room: `along` the wall, `off` its inner face into
## the room (or into the wall, below zero) and `y` above the floor.
func _wall_spot(room_name: String, side: int, along: float, off: float, y := 0.0) -> Vector3:
	var inner := _room_inside(room_name)
	match side:
		NORTH:
			return Vector3(along, y, inner.position.y + off)
		SOUTH:
			return Vector3(along, y, inner.end.y - off)
		WEST:
			return Vector3(inner.position.x + off, y, along)
	return Vector3(inner.end.x - off, y, along)


## The spot on the floor (x and z) that lies `off` into a room from the
## middle of one of its doorways.
func _door_spot(room_name: String, way: Dictionary, off: float) -> Vector2:
	var spot := _wall_spot(room_name, way.side, way.along, off)
	return Vector2(spot.x, spot.z)


## The stretches of a wall that nothing opens in: [from, to] along the wall,
## keeping `clear` of every doorway and, with `low`, of every window that
## something standing against the wall would stand in front of.
func _free_spans(room_name: String, side: int, clear: float, low: bool) -> Array[Vector2]:
	var plan: Dictionary = _floor_plan[room_name]
	var taken: Array[Vector2] = []
	for way: Dictionary in plan.doors:
		if way.side == side:
			taken.append(Vector2(way.along - way.width * 0.5 - clear, way.along + way.width * 0.5 + clear))
	for pane: Dictionary in plan.windows:
		if pane.side == side and low and pane.sill < 2.3:
			taken.append(Vector2(pane.along - pane.width * 0.5 - 0.2, pane.along + pane.width * 0.5 + 0.2))
	taken.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var span := _wall_span(room_name, side)
	var free: Array[Vector2] = []
	var from := span.x
	for gap in taken:
		if gap.x - from > 0.5:
			free.append(Vector2(from, minf(gap.x, span.y)))
		from = maxf(from, gap.y)
	if span.y - from > 0.5:
		free.append(Vector2(from, span.y))
	return free


func _longest(spans: Array[Vector2]) -> Vector2:
	var longest := Vector2.ZERO
	for span in spans:
		if span.y - span.x > longest.y - longest.x:
			longest = span
	return longest


## Whether a spot on the floor of a room (x and z) is free for something to
## stand on that reaches `reach` around it: not in front of a door, not where
## something stands already, not where the plan keeps the floor clear.
func _room_free(room_name: String, spot: Vector2, reach: float) -> bool:
	var plan: Dictionary = _floor_plan[room_name]
	for area: Rect2 in plan.kept:
		if area.grow(reach * 0.5).has_point(spot):
			return false
	for there: Vector3 in plan.stood:
		if Vector2(there.x, there.y).distance_to(spot) < reach + there.z:
			return false
	# The first steps in from every door. What stands further in stands far
	# enough apart to walk around, and the builder checks that every robot
	# can be walked to.
	for way: Dictionary in plan.doors:
		var nearest := Geometry2D.get_closest_point_to_segment(spot, _door_spot(room_name, way, 0.4), _door_spot(room_name, way, 3.0))
		if nearest.distance_to(spot) < reach + 0.9:
			return false
	return true
