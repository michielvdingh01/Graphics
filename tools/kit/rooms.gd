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
##     fight("store", "the storeroom", ["grunt", "grunt"], "corridor")
##     exit_through("workshop", EAST, 7.0, "Leave by the loading door")
##
## The rectangle is the room with its walls, so two rooms that share a wall
## have rectangles that touch. build_rooms() then makes every room: a zone of
## its own, closed by its own floor, walls and ceiling; its doorways and
## windows, with a panel that shuts each doorway while its lightmap is baked;
## lamps and a reflection probe. Unless the level is `_bare` it also hangs the
## doors, dirties the walls and the floor and stands about what a room of
## that kind has standing about: clear of its doors, of where its robots
## are posted and of what the plan keeps clear.
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
## and its ceiling, how thick its walls are, which lamps hang in it and how
## far apart, and what stands about in it (see _room_stock()).
const ROOM_KINDS := {
	"hall": {"wall": "brick", "ceiling": "roof", "thick": 0.4, "lamp": "hanging", "every": 8.0, "stock": "works", "dust": true},
	"plant": {"wall": "brick", "ceiling": "concrete", "thick": 0.4, "lamp": "hanging", "every": 7.0, "stock": "", "dust": true},
	"corridor": {"wall": "plaster_dado", "ceiling": "concrete", "thick": 0.2, "lamp": "tube", "every": 5.0, "stock": "corridor", "dust": false},
	"office": {"wall": "plaster_dado", "ceiling": "concrete", "thick": 0.2, "lamp": "tube", "every": 4.5, "stock": "office", "dust": false},
	"storage": {"wall": "plaster_dado", "ceiling": "concrete", "thick": 0.2, "lamp": "tube", "every": 5.0, "stock": "storage", "dust": false},
}

## The rooms of the plan, by name: {kind, rect, height, doors, windows, posts,
## kept}. A door is {side, along, width, height, to}; `to` is the room on the
## other side, or empty for the way out.
var _floor_plan := {}
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
	_floor_plan[room_name] = {"kind": kind, "rect": rect, "height": height, "doors": [], "windows": [], "posts": [], "kept": []}
	zone(room_name, [AABB(Vector3(rect.position.x, -1.0, rect.position.y), Vector3(rect.size.x, height + 1.5, rect.size.y))])


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
	if side < 0 or along - width * 0.5 < shared.x + 0.5 or along + width * 0.5 > shared.y - 0.5:
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
	route_start(Vector3(middle.x, 0, middle.y), Vector3(look.x, 0, look.y))


## Robots hold that room: one of each of `kinds`, posted as far as the room
## allows from the door to `entered_from`, the room the player comes out of.
## `title` is what the HUD calls the place, as in "Clear the storeroom". Has
## to come after the doors of the room and what it keeps clear.
func fight(room_name: String, title: String, kinds: Array, entered_from := "") -> void:
	var plan: Dictionary = _floor_plan[room_name]
	var entry := _room_middle(room_name)
	for way: Dictionary in plan.doors:
		if way.to == entered_from or entered_from == "":
			entry = _door_spot(room_name, way, 0.6)
			break
	var posts := _room_posts(room_name, kinds.size(), entry)
	if posts.size() < kinds.size():
		push_error("fight: '%s' has room for %d robots, not for %d" % [room_name, posts.size(), kinds.size()])
		return
	plan.posts.append_array(posts)
	var enemies: Array = []
	for i in kinds.size():
		enemies.append([kinds[i], Vector3(posts[i].x, 0, posts[i].y)])
	var inner := _room_inside(room_name)
	route_zone(room_name, title, AABB(Vector3(inner.position.x, 0, inner.position.y), Vector3(inner.size.x, minf(plan.height, 4.0), inner.size.y)), enemies)


## A place to carry on from, in the middle of that room, once everything
## before it is cleared. The room may not be fought over later on.
func checkpoint_in(room_name: String, title: String) -> void:
	var middle := _room_middle(room_name)
	var doors: Array = _floor_plan[room_name].doors
	var look := _door_spot(room_name, doors[-1], 0.0) if not doors.is_empty() else middle + Vector2.RIGHT
	var inner := _room_inside(room_name)
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
	var lamp := _wall_spot(room_name, side, along, 0.0, height + 0.7)
	route_exit(title, AABB(outside - size * 0.5 + Vector3.UP * (size.y * 0.5 - 0.3), size), next, lamp, -out)


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


## Tubes under a low ceiling, hall lamps under a high one: about as far apart
## as the kind of room says, most of them still working.
func _room_lamps(room_name: String) -> void:
	var plan: Dictionary = _floor_plan[room_name]
	var kind: Dictionary = ROOM_KINDS[plan.kind]
	var inner := _room_inside(room_name)
	var high: float = plan.height
	var lit := 0
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
	match ROOM_KINDS[plan.kind].stock:
		"storage":
			# Racks along the walls, and what would not fit on them in between.
			var racks := 0
			for side in 4:
				for span: Vector2 in _free_spans(room_name, side, 1.0, true):
					var count := int((span.y - span.x) / 3.3)
					for i in count:
						var spot := _wall_spot(room_name, side, span.x + (span.y - span.x) * (i + 0.5) / count, 0.45)
						if racks < 8 and _room_free(room_name, Vector2(spot.x, spot.z), 0.4):
							shelf(spot, _yaw_in(side), _rng.randf() < 0.6)
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
	var floor_left := _room_inside(room_name).grow(-2.2)
	if floor_left.size.x <= 0.0 or floor_left.size.y <= 0.0:
		return
	# Every spot a metre and a half from the next is tried, in an order the
	# dice decide, and taken if nothing was put down within a pitch of it.
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
	var taken: Array[Vector2] = []
	for spot in spots:
		if taken.any(func(island: Vector2) -> bool: return island.distance_to(spot) < pitch) or not _room_free(room_name, spot, 1.3):
			continue
		taken.append(spot)
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
## a robot is posted, not where the plan keeps the floor clear.
func _room_free(room_name: String, spot: Vector2, reach: float) -> bool:
	var plan: Dictionary = _floor_plan[room_name]
	for area: Rect2 in plan.kept:
		if area.grow(reach * 0.5).has_point(spot):
			return false
	for post: Vector2 in plan.posts:
		if post.distance_to(spot) < reach + 0.6:
			return false
	# The first steps in from every door. What stands further in stands far
	# enough apart to walk around, and the builder checks that every robot
	# can be walked to.
	for way: Dictionary in plan.doors:
		var nearest := Geometry2D.get_closest_point_to_segment(spot, _door_spot(room_name, way, 0.4), _door_spot(room_name, way, 3.0))
		if nearest.distance_to(spot) < reach + 0.9:
			return false
	return true


## Where to post `count` robots in a room: as far from `entry` as the floor
## allows, a few steps apart, and not where the plan keeps the floor clear.
func _room_posts(room_name: String, count: int, entry: Vector2) -> Array[Vector2]:
	var plan: Dictionary = _floor_plan[room_name]
	var floor_left := _room_inside(room_name).grow(-1.3)
	var spots: Array[Vector2] = []
	var x := floor_left.position.x
	while x <= floor_left.end.x + 0.01:
		var z := floor_left.position.y
		while z <= floor_left.end.y + 0.01:
			var spot := Vector2(x, z)
			if not plan.kept.any(func(area: Rect2) -> bool: return area.grow(0.8).has_point(spot)):
				spots.append(spot)
			z += 1.0
		x += 1.0
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(entry) > b.distance_to(entry))
	var posts: Array[Vector2] = []
	for apart: float in [2.6, 1.6]:
		for spot in spots:
			if posts.size() < count and not posts.any(func(post: Vector2) -> bool: return post.distance_to(spot) < apart) and not plan.posts.any(func(post: Vector2) -> bool: return post.distance_to(spot) < apart):
				posts.append(spot)
	return posts
