extends "res://tools/kit/houses.gd"
## Fourteenth and last drawer of the kit, see tools/kit.gd: a level laid out as
## rooms.
##
## The plan of such a level names its rooms, each a rectangle on the ground
## with a kind and a height, the doorways between them and the way through:
##
##     room("store", "storage", Rect2(0, 6, 8, 9), 3.4)
##     room("hall", "hall", Rect2(11, 0, 27, 30), 8.0, {"roof": "sawtooth"})
##     room("corridor", "corridor", Rect2(8, 0, 3, 20), 3.0)
##     door("store", "corridor", 10.0)
##     window("store", WEST, 10.5, 3.0)
##     keep_clear("hall", Rect2(15, 2, 6, 4))
##     start_in("lobby")
##     fight("store", "the storeroom", {"store": ["grunt", "grunt"]}, "corridor")
##     exit_through("hall", EAST, 7.0, "Leave by the loading door")
##
## The rectangle is the room with its walls, so two rooms that share a wall
## have rectangles that touch. build_rooms() then makes every room: a zone of
## its own, closed by its own floor, walls and roof; its doorways and
## windows, with a panel that shuts each doorway while its lightmap is baked;
## lamps and a reflection probe. Unless the level is `_bare` it also hangs the
## doors with a sign over each, divides the walls, runs pipes and ducts under
## the ceiling, dirties the walls and the floor and stands about what a room
## of that kind has standing about: clear of its doors and of what the plan
## keeps clear.
##
## What a room is like follows from its kind, see ROOM_KINDS, and a plan can
## say otherwise for one room in the last argument of room(): another roof,
## another stock, what its sign says.
##
## The lamps follow a rule, see _room_lamps(): the dice leave some of them
## out, but never so that a part of the floor lies in the dark, and the first
## thing the plan keeps the floor clear for, which is what there is to see in
## the room, has a lamp over the side of it the player comes to.
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

## What a kind of room is made of and fitted with: the material of its walls,
## the form of its roof (none for one under the open sky, see roof() in
## tools/kit/structure.gd) and what a slab over it is made of, how thick its
## walls are, which lamps it has and how far apart, and what stands about in
## it (see _room_stock()).
const ROOM_KINDS := {
	"hall": {"wall": "brick", "roof": "trusses", "ceiling": "roof", "thick": 0.4, "lamp": "hanging", "every": 8.0, "stock": "works", "dust": true},
	"plant": {"wall": "brick", "roof": "slab", "ceiling": "concrete", "thick": 0.4, "lamp": "hanging", "every": 7.0, "stock": "plant", "dust": true},
	"corridor": {"wall": "plaster_dado", "roof": "flat", "ceiling": "concrete", "thick": 0.2, "lamp": "tube", "every": 5.0, "stock": "corridor", "dust": false},
	"office": {"wall": "plaster_dado", "roof": "flat", "ceiling": "concrete", "thick": 0.2, "lamp": "tube", "every": 4.5, "stock": "office", "dust": false},
	"canteen": {"wall": "plaster_dado", "roof": "flat", "ceiling": "concrete", "thick": 0.2, "lamp": "tube", "every": 4.5, "stock": "canteen", "dust": false},
	"kitchen": {"wall": "plaster_dado", "roof": "flat", "ceiling": "concrete", "thick": 0.2, "lamp": "tube", "every": 4.5, "stock": "kitchen", "dust": false},
	"changing": {"wall": "plaster_dado", "roof": "flat", "ceiling": "concrete", "thick": 0.2, "lamp": "tube", "every": 4.5, "stock": "changing", "dust": false},
	"control": {"wall": "plaster_dado", "roof": "flat", "ceiling": "concrete", "thick": 0.2, "lamp": "tube", "every": 4.0, "stock": "", "dust": false},
	"storage": {"wall": "plaster_dado", "roof": "flat", "ceiling": "concrete", "thick": 0.2, "lamp": "tube", "every": 5.0, "stock": "storage", "dust": false},
	"yard": {"wall": "brick", "roof": "", "ceiling": "", "thick": 0.4, "lamp": "mast", "every": 0.0, "stock": "yard", "dust": false},
}
## How near a robot may stand in view of where the player walks into its
## fight, starts or carries on. scripts/selftest.gd holds a level to the same.
const POST_DISTANCE := 14.0
## The light rule, by the kind of lamp: how far from a lamp that burns the
## floor of a room may lie, and what share of its lamps the dice leave out
## before that is looked at.
const LAMP_REACH := {"tube": 4.6, "hanging": 6.2}
## How much further from anything else something on the floor of a room
## stands than the two reach together: the way between them, which a robot
## needs a good metre of.
const WAY_BETWEEN := 0.6
const LAMPS_OUT := {"tube": 0.2, "hanging": 0.3}

## The rooms of the plan, by name: {kind, rect, height, fit, doors, windows,
## kept, features, stood, screens, posts, roof, piers, walled, entry}. A door
## is {side, along, width, height, to}; `to` is the room on the other side,
## or empty for the way out. `fit` is what the plan said of this room in
## particular. `stood` is what the builder has put down on the floor so far:
## x, z and how far it reaches. `walled` is what stands or hangs against the
## walls: the side, and from where to where along it. `features` is what the
## plan keeps the floor clear for, `roof` the roof as roof() made it, `piers`
## where a pier stands, and `entry` the door the player first comes in by.
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
## The room the player starts in.
var _start_room := ""


# --- The plan -----------------------------------------------------------------


## A room: `rect` is its place on the ground (x and z) with its walls, and
## `kind` one of ROOM_KINDS. It is a zone of that name from here on. `fit`
## says what this room has that its kind has not: any key of ROOM_KINDS, as
## in {"stock": "archive"}, whatever roof() takes, as in {"roof": "sawtooth",
## "glazed": WEST}, and "sign" for what the plates over its doors say.
func room(room_name: String, kind: String, rect: Rect2, height: float, fit := {}) -> void:
	if not ROOM_KINDS.has(kind):
		push_error("room: there is no kind of room called '%s'" % kind)
		return
	_floor_plan[room_name] = {
		"kind": kind, "rect": rect, "height": height, "fit": fit, "doors": [], "windows": [], "kept": [], "features": [],
		"stood": [], "screens": [], "posts": [], "roof": {}, "piers": [], "walled": [], "entry": {},
	}
	zone(room_name, [AABB(Vector3(rect.position.x, -1.0, rect.position.y), Vector3(rect.size.x, height + 1.5, rect.size.y))])
	# What it sounds like in there, for scripts/sfx.gd to pick its reverb by.
	var space := {"hall": &"hall", "plant": &"hall", "yard": &"yard"}
	(_zones[room_name].node as Node).set_meta(&"space", space.get(kind, &"room"))


## What a room has by its kind, or by what the plan said of it.
func _fit(room_name: String, key: String) -> Variant:
	var plan: Dictionary = _floor_plan[room_name]
	return plan.fit.get(key, ROOM_KINDS[plan.kind][key])


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
## whatever the builder would stand there: for what goes in by hand. The
## first of a room is taken for what there is to see in it, and gets a lamp
## that burns, see _room_lamps(); eye_catcher() says otherwise.
func keep_clear(room_name: String, area: Rect2) -> void:
	_floor_plan[room_name].kept.append(area)
	_floor_plan[room_name].features.append(area)


## Names what the player should see first in a room: the part of its floor
## (x and z in the level) that it stands on.
func eye_catcher(room_name: String, area: Rect2) -> void:
	_floor_plan[room_name].features.push_front(area)


## A spot in a room: `x` and `z` metres from its north-west corner, walls
## included, and `y` above its floor.
func spot_in(room_name: String, x: float, z: float, y := 0.0) -> Vector3:
	var rect: Rect2 = _floor_plan[room_name].rect
	return Vector3(rect.position.x + x, y, rect.position.y + z)


## Where the piers of a room stand along one of its walls: for what goes in
## by hand and wants to rest on them, the corbels of a crane say.
func piers_along(room_name: String, side: int) -> Array[float]:
	var found: Array[float] = []
	for stood: Dictionary in _floor_plan[room_name].piers:
		if stood.side == side:
			found.append(stood.along)
	found.sort()
	return found


## The outside of a wall of a room from `from_y` up, as it shows over a
## lower neighbour or over the wall of a yard while the room itself is not
## drawn: its brick up to the eaves, the gable if a pitched roof ends on
## that side, and the edge of its roof. For the file of a level that builds
## what is always drawn, see in_zone(); to be called once the rooms stand.
func wall_above(room_name: String, side: int, from_y: float) -> void:
	var plan: Dictionary = _floor_plan[room_name]
	var rect: Rect2 = plan.rect
	var high: float = plan.height
	var mat: String = ROOM_KINDS[plan.kind].wall
	var flags := DETAIL | NO_COLLIDE
	var out := -_normal_in(side)
	var across := Vector3(absf(out.z), 0, absf(out.x))
	var north_south := side == NORTH or side == SOUTH
	var long := rect.size.x if north_south else rect.size.y
	# The middle of the outer face of that wall, on the ground, a hand off it.
	var foot := Vector3(rect.get_center().x, 0, rect.get_center().y) + out * ((rect.size.y if north_south else rect.size.x) * 0.5 + 0.1)
	if high > from_y:
		box(mat, foot + Vector3.UP * (from_y + high) * 0.5, across * long + out.abs() * 0.2 + Vector3.UP * (high - from_y), Vector3.ZERO, flags)
	var over: Dictionary = plan.roof
	if over.get("form", "") == "trusses" and over.along_x != north_south:
		var rise: float = over.rise
		var half := long * 0.5
		extrude(mat, PackedVector2Array([Vector2(-half, 0), Vector2(half, 0), Vector2(0, rise)]), 0.2, Transform3D(Basis(across, Vector3.UP, across.cross(Vector3.UP)), foot + Vector3.UP * high), flags)
		for end: float in [-1.0, 1.0]:
			beam("roof", foot + across * end * (half + 0.1) + Vector3.UP * (high + 0.05), foot + Vector3.UP * (high + rise + 0.07), 0.5, flags, 0.14)
	else:
		box("roof", foot + Vector3.UP * (high + 0.36), across * (long + 0.3) + out.abs() * 0.5 + Vector3.UP * 0.12, Vector3.ZERO, flags)


# --- The way through, in the order the player goes ------------------------------


## The player starts in the middle of that room, facing its first door.
func start_in(room_name: String) -> void:
	var middle := _room_middle(room_name)
	var doors: Array = _floor_plan[room_name].doors
	var look := _door_spot(room_name, doors[0], 0.0) if not doors.is_empty() else middle + Vector2.RIGHT
	_floor_plan[room_name].kept.append(Rect2(middle - Vector2.ONE, Vector2.ONE * 2.0))
	_start_room = room_name
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
	_floor_plan[room_name].kept.append(Rect2(middle - Vector2.ONE, Vector2.ONE * 2.0))
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
	_find_entries()
	for room_name: String in _floor_plan:
		build_room(room_name)


func build_room(room_name: String) -> void:
	# Dice of its own for every room: what changes in one leaves the lamps
	# and the crates of the next as they were, and its lightmap with them.
	_seed_dice("%s/%s" % [_level_name(), room_name])
	# Whatever a room builds is its own, also what rises over its eaves.
	in_zone(room_name)
	_room_shell(room_name)
	_room_lamps(room_name)
	if not _bare:
		_room_doors(room_name)
		_room_structure(room_name)
		_room_stock(room_name)
		_room_fittings(room_name)
		_room_services(room_name)
		_room_dirt(room_name)
	by_position()


## Finds for every room the door the player first comes in by: the one on
## the shortest way from where he starts.
func _find_entries() -> void:
	if _start_room == "":
		return
	var reached := {_start_room: true}
	var todo: Array[String] = [_start_room]
	while not todo.is_empty():
		var from: String = todo.pop_front()
		for way: Dictionary in _floor_plan[from].doors:
			if way.to == "" or reached.has(way.to):
				continue
			reached[way.to] = true
			# The same doorway, as the room beyond has it.
			for back: Dictionary in _floor_plan[way.to].doors:
				if back.to == from and is_equal_approx(back.along, way.along):
					_floor_plan[way.to].entry = back
			todo.append(way.to)


## Floor, roof and four walls with the doorways and windows cut out, a panel
## in every doorway for the bake, glazing in the windows and a probe.
func _room_shell(room_name: String) -> void:
	var plan: Dictionary = _floor_plan[room_name]
	var kind: Dictionary = ROOM_KINDS[plan.kind]
	var rect: Rect2 = plan.rect
	var thick: float = kind.thick
	var high: float = plan.height
	var middle := rect.get_center()
	box("floor", Vector3(middle.x, -0.25, middle.y), Vector3(rect.size.x, 0.5, rect.size.y))
	var form: String = _fit(room_name, "roof")
	if form != "":
		var fit: Dictionary = (plan.fit as Dictionary).duplicate()
		fit["ceiling"] = _fit(room_name, "ceiling")
		fit["wall"] = kind.wall
		plan.roof = roof(form, rect, thick, high, fit)
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
		if form == "":
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
	# The probe takes in the space under a pitched roof, and looks from the
	# middle of what lies under the eaves.
	var rise: float = plan.roof.get("rise", 0.0)
	probe(room_name.to_pascal_case(), Vector3(middle.x, (high + rise) * 0.5, middle.y), Vector3(inner.size.x, high + rise, inner.size.y), Vector3(0, -rise * 0.5, 0))
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


## The lamps of a room: tubes under a low ceiling, hall lamps under a high
## one, floodlights on masts under the open sky, about as far apart as the
## kind of room says. The dice leave some of them out, and then the rule:
##
##   - no part of the floor lies further from a lamp that burns than its
##     light carries (LAMP_REACH): a lamp that was out comes on for it;
##   - what there is to see in the room, see keep_clear(), has a lamp a
##     step in front of the side of it the player comes to, and that one
##     always burns;
##   - that lamp and the one nearest to the door the player comes in by are
##     the two that cast a shadow.
func _room_lamps(room_name: String) -> void:
	var plan: Dictionary = _floor_plan[room_name]
	var kind: Dictionary = ROOM_KINDS[plan.kind]
	var inner := _room_inside(room_name)
	var high: float = plan.height
	var entry := _entry_spot(room_name, 1.5)
	var sight := _eye_catcher(room_name)
	if kind.lamp == "mast":
		# One in each of two corners, across the yard from each other. The
		# one nearer to what there is to see lights that.
		var middle := Vector3(inner.get_center().x, 0, inner.get_center().y)
		var corners: Array[Vector2] = [inner.position + Vector2.ONE * 1.2, inner.end - Vector2.ONE * 1.2]
		var nearer := 0 if sight == Vector2.INF or corners[0].distance_to(sight) <= corners[1].distance_to(sight) else 1
		for i in 2:
			var foot := Vector3(corners[i].x, 0, corners[i].y)
			var target := foot.lerp(middle, 0.7)
			if sight != Vector2.INF and i == nearer:
				target = Vector3(sight.x, 1.0, sight.y)
			floodlight(foot, target)
			_stand(room_name, corners[i], 0.8)
		return
	var hanging: bool = kind.lamp == "hanging"
	var every: float = _fit(room_name, "every")
	var along_x := inner.size.x >= inner.size.y
	var across := maxi(1, roundi(inner.size.x / every))
	var down := maxi(1, roundi(inner.size.y / every))
	if not hanging:
		# A row of tubes lights a strip to either side of it: rows lie
		# further apart than the tubes of one row, but never so far that
		# the walls on either side are out of their reach.
		if along_x:
			down = maxi(1, ceili((inner.size.y - 1.0) / (every * 1.5)))
		else:
			across = maxi(1, ceili((inner.size.x - 1.0) / (every * 1.5)))
	var lamps: Array[Dictionary] = []
	for i in across:
		for j in down:
			var spot := inner.position + inner.size * Vector2(i + 0.5, j + 0.5) / Vector2(across, down)
			lamps.append({"at": spot, "on": _rng.randf() >= LAMPS_OUT[kind.lamp], "shadows": false})
	# What there is to see: a lamp of the grid that hangs near enough moves
	# to a good step in front of the side of it the player comes to, so that
	# its face is lit and not only its top, or else one is hung there.
	if sight != Vector2.INF:
		var area: Rect2 = plan.features[0]
		var towards := (entry - sight).normalized()
		var edge := minf(area.size.x * 0.5 / maxf(absf(towards.x), 0.01), area.size.y * 0.5 / maxf(absf(towards.y), 0.01))
		var over := sight + towards * minf(entry.distance_to(sight), edge + (1.6 if hanging else 0.8))
		over = over.clamp(inner.position + Vector2.ONE * 0.8, inner.end - Vector2.ONE * 0.8)
		var nearest := _nearest_lamp(lamps, over, false)
		if (lamps[nearest].at as Vector2).distance_to(over) < (3.0 if hanging else 2.2):
			lamps[nearest].at = over
		else:
			lamps.append({"at": over, "on": true, "shadows": true})
			nearest = lamps.size() - 1
		lamps[nearest].on = true
		lamps[nearest].shadows = true
	# The floor, a spot every metre and a half: none of it in the dark.
	var reach: float = LAMP_REACH[kind.lamp] * (maxf(1.0, (high - 0.9) / 5.0) if hanging else 1.0)
	var floor_spots: Array[Vector2] = []
	var x := inner.position.x + 0.75
	while x < inner.end.x:
		var z := inner.position.y + 0.75
		while z < inner.end.y:
			floor_spots.append(Vector2(x, z))
			z += 1.5
		x += 1.5
	while true:
		var dark := floor_spots.filter(func(spot: Vector2) -> bool:
			return not lamps.any(func(lit: Dictionary) -> bool: return lit.on and (lit.at as Vector2).distance_to(spot) <= reach))
		var best := -1
		var most := 0
		for k in lamps.size():
			if lamps[k].on:
				continue
			var lights := dark.filter(func(spot: Vector2) -> bool: return (lamps[k].at as Vector2).distance_to(spot) <= reach).size()
			if lights > most:
				most = lights
				best = k
		if best < 0:
			break
		lamps[best].on = true
	var first := _nearest_lamp(lamps, entry, true)
	if first < 0:
		first = _nearest_lamp(lamps, entry, false)
		lamps[first].on = true
	lamps[first].shadows = true
	for lit: Dictionary in lamps:
		var spot: Vector2 = lit.at
		if hanging:
			# Up between the trusses of a pitched roof, where a crane passes
			# underneath; a little under a flat one.
			var under := roof_height(plan.roof, spot.x, spot.y)
			var hangs := maxf(high - 0.9, minf(under - 0.7, high + 0.3))
			lamp(Vector3(spot.x, hangs, spot.y), under - 0.03, lit.on, lit.shadows)
		else:
			tube(Vector3(spot.x, high - 0.08, spot.y), along_x, lit.on, lit.shadows, 6.5)


## The lamp of `lamps` nearest to a spot on the floor, of those that burn if
## `lit`; -1 if there is none.
func _nearest_lamp(lamps: Array[Dictionary], spot: Vector2, lit: bool) -> int:
	var nearest := -1
	for k in lamps.size():
		if lit and not lamps[k].on:
			continue
		if nearest < 0 or (lamps[k].at as Vector2).distance_to(spot) < (lamps[nearest].at as Vector2).distance_to(spot):
			nearest = k
	return nearest


## Where the player stands when he has come `off` into a room by its door,
## or in its middle if he starts there (x and z).
func _entry_spot(room_name: String, off: float) -> Vector2:
	var way: Dictionary = _floor_plan[room_name].entry
	return _room_middle(room_name) if way.is_empty() else _door_spot(room_name, way, off)


## The middle of what there is to see in a room (x and z), or Vector2.INF.
func _eye_catcher(room_name: String) -> Vector2:
	var features: Array = _floor_plan[room_name].features
	return Vector2.INF if features.is_empty() else (features[0] as Rect2).get_center()


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
## it was named first for. Over every doorway, on this side of it, a plate
## says what lies beyond.
func _room_doors(room_name: String) -> void:
	var plan: Dictionary = _floor_plan[room_name]
	for way: Dictionary in plan.doors:
		var text := "EXIT" if way.to == "" else _sign(way.to)
		var over: float = way.height + (0.3 if is_equal_approx(way.height, 2.2) else 0.44)
		if text != "" and over + 0.16 < plan.height:
			sign_plate(_wall_spot(room_name, way.side, way.along, 0.0, over), _normal_in(way.side), text)
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


## What the plate over a door into a room says: its name, unless the plan
## said otherwise. A corridor has none.
func _sign(room_name: String) -> String:
	var plan: Dictionary = _floor_plan[room_name]
	if plan.fit.has("sign"):
		return plan.fit.sign
	return "" if plan.kind == "corridor" else room_name.replace("_", " ").to_upper()


## What divides the walls of a room: a pier under whatever its roof rests
## on, or a corbel where a door or a window is in the way of one; a plinth
## of concrete along the foot of brick and a kerb along plaster; and
## buttresses against the walls of a yard.
func _room_structure(room_name: String) -> void:
	var plan: Dictionary = _floor_plan[room_name]
	var brick: bool = ROOM_KINDS[plan.kind].wall == "brick"
	for bearing: Dictionary in plan.roof.get("bearings", []):
		var side := _side_of(bearing.inwards)
		var along: float = bearing.at.x if side == NORTH or side == SOUTH else bearing.at.z
		if brick and _wall_clear(room_name, side, along, 0.45):
			pier(Vector3(bearing.at.x, 0, bearing.at.z), bearing.inwards, bearing.at.y)
			plan.piers.append({"side": side, "along": along})
		else:
			corbel(bearing.at, bearing.inwards, 0.1, "concrete" if brick else "plaster")
	if plan.roof.is_empty():
		for side in 4:
			for span: Vector2 in _free_spans(room_name, side, 1.4, false):
				var count := int((span.y - span.x) / 6.5)
				for i in count:
					var along := span.x + (span.y - span.x) * (i + 0.5) / count
					var foot := _wall_spot(room_name, side, along, 0.0)
					var front := _wall_spot(room_name, side, along, 0.4)
					if _wall_clear(room_name, side, along, 0.6) and _room_free(room_name, Vector2(front.x, front.z), 0.5):
						buttress(foot, _normal_in(side), plan.height)
						plan.piers.append({"side": side, "along": along})
						_stand(room_name, Vector2(front.x, front.z), 0.6)
	for side in 4:
		for span: Vector2 in _free_spans(room_name, side, 0.04, false, 1.05 if brick else 0.2):
			var from := _wall_spot(room_name, side, span.x, 0.0)
			var to := _wall_spot(room_name, side, span.y, 0.0)
			if brick:
				plinth(from, to, _normal_in(side), 1.0, 0.08)
			else:
				plinth(from, to, _normal_in(side), 0.15, 0.03)


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


# --- What stands about ----------------------------------------------------------


## What a robot can wait behind, by the stock of the room it stands in: see
## _room_screens(). A room has them in turn, so that two in one room differ.
const SCREENS := {
	"works": ["cases", "screens", "pallets", "plates", "drums"],
	"paint": ["booth", "screens", "cases"],
	"bay": ["cases", "pallets", "drums"],
	"plant": ["cases", "drums"],
	"storage": ["cases", "pallets", "shelving"],
	"tools": ["shelving", "cases"],
	"despatch": ["cases", "pallets"],
	"archive": ["shelving"],
	"office": ["cupboard", "shelving"],
	"lodge": ["cupboard", "shelving"],
	"canteen": ["cupboard"],
	"kitchen": ["cupboard"],
	"changing": ["lockers"],
	"yard": ["container"],
}


## What stands about in a room, by its stock.
func _room_stock(room_name: String) -> void:
	var plan: Dictionary = _floor_plan[room_name]
	var high: float = plan.height
	var inner := _room_inside(room_name)
	var along_x := inner.size.x >= inner.size.y
	_room_screens(room_name)
	match _fit(room_name, "stock"):
		"storage":
			# Racks along the walls, and what would not fit on them in between.
			_line_walls(room_name, [
				[3.0, 3.0, 0.75, func(at: Vector3, yaw: float) -> void: shelf(at, yaw, true)],
				[3.0, 3.0, 0.65, func(at: Vector3, yaw: float) -> void: shelf(at, yaw, false)],
				[2.0, 2.0, 0.45, func(at: Vector3, yaw: float) -> void: shelving(at, yaw, 2.0, 2.1, true)],
				[1.5, 1.3, 0.65, func(at: Vector3, yaw: float) -> void: _piles("industrial_pastic_container", at, yaw, 2)],
				[1.2, 1.9, 1.0, func(at: Vector3, yaw: float) -> void: place("old_military_crate", at, yaw)],
			], 10, 0.75)
			_room_islands(room_name, 3.8, ["crates", "crates", "pallet", "bags", "totes", "plastic", "case", "drum"], 2, 4)
		"archive":
			# Rows of shelves down the room, and cabinets along its walls.
			_room_rows(room_name, 2.0, func(at: Vector3, yaw: float) -> void: _shelving_pair(at, yaw, 2.0))
			_line_walls(room_name, [
				[3.0, 1.4, 0.62, func(at: Vector3, yaw: float) -> void: filing_cabinets(at, yaw, 3)],
				[2.0, 2.0, 0.45, func(at: Vector3, yaw: float) -> void: shelving(at, yaw, 2.0, 2.1, true)],
				[1.0, 1.4, 0.6, func(at: Vector3, yaw: float) -> void: place("wooden_bookshelf_worn", at, yaw)],
				[1.0, 0.9, 0.6, func(at: Vector3, yaw: float) -> void: _boxes(at, yaw)],
			], 8, 0.6)
		"tools":
			_line_walls(room_name, [
				[3.0, 3.0, 0.65, func(at: Vector3, yaw: float) -> void: shelf(at, yaw, false)],
				[2.0, 2.3, 0.8, func(at: Vector3, yaw: float) -> void: bench(at, yaw)],
				[2.0, 1.0, 0.6, func(at: Vector3, yaw: float) -> void: cupboard("machine", at, yaw, Vector3(0.98, 1.9, 0.6))],
				[1.5, 2.0, 0.45, func(at: Vector3, yaw: float) -> void: shelving(at, yaw, 2.0, 2.1, true)],
				[1.0, 0.75, 0.45, func(at: Vector3, yaw: float) -> void: place("metal_tool_chest", at, yaw)],
				[1.0, 1.3, 0.8, func(at: Vector3, yaw: float) -> void: place("tool_cart", at, yaw)],
				[1.0, 0.8, 0.4, func(at: Vector3, yaw: float) -> void: _cans(at, yaw)],
			], 8, 0.75)
			_room_islands(room_name, 4.0, ["crates", "cart", "case", "plastic"], 2, 3)
		"despatch":
			_line_walls(room_name, [
				[3.0, 3.0, 0.75, func(at: Vector3, yaw: float) -> void: shelf(at, yaw, true)],
				[2.0, 2.0, 0.45, func(at: Vector3, yaw: float) -> void: shelving(at, yaw, 2.0, 2.1, true)],
				[2.0, 1.9, 0.82, func(at: Vector3, yaw: float) -> void: _table_with(at, yaw, ["clipboard", "office_notepads"])],
				[1.5, 1.9, 0.65, func(at: Vector3, yaw: float) -> void: _piles("industrial_pastic_container", at, yaw, 3)],
			], 8, 0.6)
			_room_islands(room_name, 3.8, ["pallet", "totes", "case", "bags", "cart", "plastic", "pallet"], 2, 4)
		"works":
			# Something against a wall every few metres, and cover on the floor.
			_line_walls(room_name, [
				[2.0, 3.0, 0.75, func(at: Vector3, yaw: float) -> void: shelf(at, yaw, true)],
				[1.0, 3.0, 0.65, func(at: Vector3, yaw: float) -> void: shelf(at, yaw, false)],
				[2.0, 3.0, 0.9, func(at: Vector3, yaw: float) -> void: cabinets(at, yaw)],
				[2.0, 2.3, 0.8, func(at: Vector3, yaw: float) -> void: bench(at, yaw)],
				[1.5, 2.4, 1.0, func(at: Vector3, yaw: float) -> void: _barrel_row(at, yaw)],
				[1.5, 1.0, 0.9, func(at: Vector3, yaw: float) -> void: tyres(at, _rng.randi_range(2, 4))],
				[1.5, 1.0, 0.6, func(at: Vector3, yaw: float) -> void: cupboard("machine", at, yaw, Vector3(0.98, 1.9, 0.6))],
				[1.0, 2.0, 0.45, func(at: Vector3, yaw: float) -> void: shelving(at, yaw, 2.0, 2.1, true)],
			], 99, 0.45)
			_room_big(room_name, ["plates"], 1)
			_room_islands(room_name, 4.0, ["crates", "crates", "barrier", "barrier", "pallet", "bags", "barrels", "case", "drum", "cart", "generator"], 3, 5)
		"paint":
			# The booth stands where robots wait in it, see _room_screens(), or
			# against a wall when nobody does. Then what is waiting to be
			# sprayed, or to dry.
			if (plan.screens as Array).is_empty():
				_line_walls(room_name, [[1.0, 3.6, 2.2, func(at: Vector3, yaw: float) -> void: spray_booth(at, yaw, high)]], 1, 1.0)
			_line_walls(room_name, [
				[2.0, 2.0, 0.45, func(at: Vector3, yaw: float) -> void: shelving(at, yaw, 2.0, 2.1, true)],
				[2.0, 1.9, 0.82, func(at: Vector3, yaw: float) -> void: _table_with(at, yaw, ["spray_paint_bottles", "spray_paint_bottles", "cleaner_tin_01", "spray_paint_bottles"])],
				[1.5, 2.4, 1.0, func(at: Vector3, yaw: float) -> void: _barrel_row(at, yaw)],
				[1.0, 1.0, 0.6, func(at: Vector3, yaw: float) -> void: cupboard("machine", at, yaw, Vector3(0.98, 1.9, 0.6))],
				[1.0, 0.8, 0.4, func(at: Vector3, yaw: float) -> void: _cans(at, yaw)],
			], 6, 0.5)
			_room_islands(room_name, 4.0, ["panels", "pallet", "barrels", "case", "panels"], 2, 3)
		"bay":
			# What came in or goes out: a car under a sheet, and goods on pallets.
			_room_big(room_name, ["car"], 1)
			_line_walls(room_name, [
				[2.0, 3.0, 0.75, func(at: Vector3, yaw: float) -> void: shelf(at, yaw, true)],
				[1.5, 2.4, 1.0, func(at: Vector3, yaw: float) -> void: _barrel_row(at, yaw)],
				[1.5, 1.0, 0.9, func(at: Vector3, yaw: float) -> void: tyres(at, _rng.randi_range(2, 4))],
				[1.0, 2.3, 0.8, func(at: Vector3, yaw: float) -> void: bench(at, yaw)],
			], 99, 0.4)
			_room_islands(room_name, 4.0, ["pallet", "totes", "case", "barrier", "cart", "crates", "drum", "bags"], 3, 5)
		"yard":
			# Containers first, one or two high, then smaller things between them.
			var colours: Array[String] = ["container_red", "container_green", "container_blue", "container_orange", "container_grey"]
			for spot in _room_spread(room_name, 3.2, 9.0, 3.6):
				var lengthwise := _rng.randf() < 0.5
				var on_ground := Vector3(spot.x, 0, spot.y)
				container(colours[_rng.randi_range(0, colours.size() - 1)], on_ground, lengthwise)
				if _rng.randf() < 0.4:
					var nudge := Vector3(_rng.randf_range(-0.3, 0.3), 2.6, 0) if lengthwise else Vector3(0, 2.6, _rng.randf_range(-0.3, 0.3))
					container(colours[_rng.randi_range(0, colours.size() - 1)], on_ground + nudge, lengthwise)
			_room_big(room_name, ["car"], 1)
			_room_islands(room_name, 4.5, ["crates", "barrier", "barrier", "pallet", "barrels", "bags", "drum", "case", "generator", "stove", "bins"], 3, 5)
		"office", "lodge":
			_stock_office(room_name)
		"changing":
			_line_walls(room_name, [
				[3.0, 2.6, 0.5, func(at: Vector3, yaw: float) -> void: lockers("machine_blue", at, yaw, 7, _ajar(7))],
				[2.0, 1.9, 0.5, func(at: Vector3, yaw: float) -> void: lockers("machine", at, yaw, 5, _ajar(5))],
				[1.5, 1.9, 0.5, func(at: Vector3, yaw: float) -> void: wash_trough(at, yaw, 1.8)],
				[1.5, 1.8, 0.36, func(at: Vector3, yaw: float) -> void: slat_bench(at, yaw, 1.8, true)],
				[0.8, 0.8, 0.4, func(at: Vector3, yaw: float) -> void: _cans(at, yaw)],
			], 9, 0.85)
			for spot in _room_spread(room_name, 1.7, 3.2, 1.1):
				slat_bench(Vector3(spot.x, 0, spot.y), 0.0 if along_x else 90.0, 1.8)
		"kitchen":
			# The range first and the cupboard with the oven on it, then
			# worktops and sinks, and a table in the middle.
			_line_walls(room_name, [[1.0, 2.1, 0.9, func(at: Vector3, yaw: float) -> void: kitchen_range(at, yaw, high)]], 1, 1.0)
			_line_walls(room_name, [[1.0, 1.25, 0.62, func(at: Vector3, yaw: float) -> void: _cabinet_with(at, yaw, "vintage_microwave", 0.55)]], 1, 1.0)
			_line_walls(room_name, [
				[3.0, 2.4, 0.7, func(at: Vector3, yaw: float) -> void: counter(at, yaw, 2.4, "galvanised")],
				[2.0, 1.9, 0.5, func(at: Vector3, yaw: float) -> void: wash_trough(at, yaw, 1.8)],
				[1.0, 1.15, 0.5, func(at: Vector3, yaw: float) -> void: place("steel_frame_shelves_01", at, yaw, true, 0.1)],
				[1.5, 1.2, 0.45, func(at: Vector3, yaw: float) -> void: _piles("plastic_crate_02", at, yaw, 2)],
				[1.0, 0.8, 0.4, func(at: Vector3, yaw: float) -> void: _cans(at, yaw)],
			], 8, 0.8)
			_room_islands(room_name, 3.6, ["table", "plastic", "table", "bins"], 2, 3)
		"canteen":
			# Tables in rows with chairs at them, the hatch and a trolley by the walls.
			var tables: Array[String] = ["WoodenTable_03", "dining_table", "WoodenTable_03"]
			var chairs: Array[String] = ["plastic_monobloc_chair_01", "SchoolChair_01"]
			for spot in _room_spread(room_name, 1.8, 3.4, 1.5):
				var model := tables[_rng.randi_range(0, tables.size() - 1)]
				var size: Vector3 = _model(model).box.size
				var turn := 90.0 if _rng.randf() < 0.5 else 0.0
				var facing := Basis(Vector3.UP, deg_to_rad(turn))
				place(model, Vector3(spot.x, 0, spot.y), turn)
				var seats := 2 if size.x > 1.8 else 1
				for seat: float in [-1.0, 1.0]:
					for k in seats:
						if _rng.randf() < 0.8:
							var aside := (k - (seats - 1) * 0.5) * 0.9 + _rng.randf_range(-0.15, 0.15)
							place(chairs[_rng.randi_range(0, chairs.size() - 1)], Vector3(spot.x, 0, spot.y) + facing * Vector3(aside, 0, seat * (size.z * 0.5 + 0.45)), turn + (180.0 if seat > 0.0 else 0.0) + _rng.randf_range(-20.0, 20.0))
			_line_walls(room_name, [[1.0, 3.2, 0.7, func(at: Vector3, yaw: float) -> void: counter(at, yaw, 3.0, "wood", "machine_grey", 1.05)]], 1, 1.0)
			_line_walls(room_name, [[1.0, 2.3, 1.1, func(at: Vector3, yaw: float) -> void: place("CoffeeCart_01", at, yaw)]], 1, 1.0)
			_line_walls(room_name, [
				[2.0, 1.25, 0.62, func(at: Vector3, yaw: float) -> void: _cabinet_with(at, yaw, "Television_01", 1.0)],
				[2.0, 1.2, 0.5, func(at: Vector3, yaw: float) -> void: place("painted_wooden_bench", at, yaw)],
				[1.0, 1.0, 0.6, func(at: Vector3, yaw: float) -> void: cupboard("machine", at, yaw, Vector3(0.98, 1.9, 0.6))],
			], 5, 0.3)
		"corridor":
			# A fire point by every other door, and now and then a bench or a
			# cupboard along the wall.
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
				_wall(room_name, way.side, beside - 0.3, beside + 0.6)
			_line_walls(room_name, [
				[2.0, 1.8, 0.36, func(at: Vector3, yaw: float) -> void: slat_bench(at, yaw, 1.8)],
				[2.0, 1.2, 0.5, func(at: Vector3, yaw: float) -> void: place("painted_wooden_bench", at, yaw)],
				[1.0, 1.0, 0.45, func(at: Vector3, yaw: float) -> void: cupboard("machine_grey", at, yaw, Vector3(0.98, 1.9, 0.42))],
				[1.0, 1.4, 0.62, func(at: Vector3, yaw: float) -> void: filing_cabinets(at, yaw, 3)],
			], maxi(1, int(maxf(inner.size.x, inner.size.y) / 9.0)), 0.05)


## An office: a desk with its chair at the wall across from the door, with
## what lay on it, cabinets and shelves along the other walls, and in a
## large one a table to sit round. A lodge has a counter and a set besides.
func _stock_office(room_name: String) -> void:
	var plan: Dictionary = _floor_plan[room_name]
	var doors: Array = plan.doors
	var facing: int = (doors[0].side ^ 1) if not doors.is_empty() else NORTH
	var longest := _longest(_free_spans(room_name, facing, 0.8, false))
	if longest.y - longest.x >= 2.4:
		var along := (longest.x + longest.y) * 0.5
		var at := _wall_spot(room_name, facing, along, 0.62)
		if _room_free(room_name, Vector2(at.x, at.z), 0.6):
			_desk(at, _yaw_in(facing))
			_stand(room_name, Vector2(at.x, at.z), 1.3)
			_wall(room_name, facing, along - 1.1, along + 1.1)
	if _fit(room_name, "stock") == "lodge":
		_line_walls(room_name, [[1.0, 2.6, 0.7, func(at: Vector3, yaw: float) -> void: counter(at, yaw, 2.4, "wood", "machine", 1.05)]], 1, 1.0)
		_line_walls(room_name, [[1.0, 1.25, 0.62, func(at: Vector3, yaw: float) -> void: _cabinet_with(at, yaw, "Television_01", 1.0)]], 1, 1.0)
		_line_walls(room_name, [[1.0, 1.2, 0.5, func(at: Vector3, yaw: float) -> void: place("painted_wooden_bench", at, yaw)]], 1, 1.0)
	_line_walls(room_name, [
		[3.0, 1.4, 0.62, func(at: Vector3, yaw: float) -> void: filing_cabinets(at, yaw, 3)],
		[1.5, 0.95, 0.62, func(at: Vector3, yaw: float) -> void: filing_cabinets(at, yaw, 2, "machine")],
		[2.0, 1.4, 0.6, func(at: Vector3, yaw: float) -> void: place("wooden_bookshelf_worn", at, yaw)],
		[2.0, 1.15, 0.5, func(at: Vector3, yaw: float) -> void: place("steel_frame_shelves_01", at, yaw, true, 0.1)],
		[1.5, 1.0, 0.28, func(at: Vector3, yaw: float) -> void: place("Shelf_01", at, yaw)],
		[1.5, 1.0, 0.6, func(at: Vector3, yaw: float) -> void: cupboard("machine", at, yaw, Vector3(0.98, 1.9, 0.6))],
		[1.0, 2.0, 0.45, func(at: Vector3, yaw: float) -> void: shelving(at, yaw, 2.0, 2.1, true)],
		[1.0, 0.9, 0.6, func(at: Vector3, yaw: float) -> void: _boxes(at, yaw)],
	], 6, 0.4)
	# Room left on the floor: a table to sit round.
	for spot in _room_spread(room_name, 2.2, 6.0, 1.7, 1):
		var turn := 90.0 if _rng.randf() < 0.5 else 0.0
		var top := Basis(Vector3.UP, deg_to_rad(turn))
		table(Vector3(spot.x, 0, spot.y), turn, Vector3(1.8, 0.76, 0.9))
		for seat: float in [-1.0, 1.0]:
			place("SchoolChair_01", Vector3(spot.x, 0, spot.y) + top * Vector3(_rng.randf_range(-0.4, 0.4), 0, seat * 0.95), turn + (180.0 if seat > 0.0 else 0.0) + _rng.randf_range(-25.0, 25.0))


## A desk with its back to a wall and what was left on it, and a chair
## pushed back from it. `at` is its middle on the floor.
func _desk(at: Vector3, yaw: float) -> void:
	var turn := Basis(Vector3.UP, deg_to_rad(yaw))
	var top: float = _model(DESK).box.size.y
	place(DESK, at, yaw)
	place("plastic_monobloc_chair_01" if _rng.randf() < 0.5 else "SchoolChair_01", at + turn * Vector3(0.2, 0, 0.95), yaw + 180.0 + _rng.randf_range(-25.0, 25.0))
	drop("office_notepads", at + turn * Vector3(-0.3, top, 0.05), yaw + _clutter_rng.randf_range(-15.0, 15.0))
	if _clutter_rng.randf() < 0.6:
		drop("clipboard", at + turn * Vector3(0.6, top, 0.1), yaw + _clutter_rng.randf_range(-40.0, 40.0))
	if _clutter_rng.randf() < 0.35:
		drop("boombox", at + turn * Vector3(0.65, top, -0.25), yaw + _clutter_rng.randf_range(-15.0, 15.0))


## A table against a wall with a few small things on it.
func _table_with(at: Vector3, yaw: float, things: Array) -> void:
	var turn := Basis(Vector3.UP, deg_to_rad(yaw))
	table(at, yaw, Vector3(1.8, 0.8, 0.75))
	for i in things.size():
		var where := at + turn * Vector3(-0.65 + 1.3 * i / maxf(1.0, things.size() - 1.0) + _clutter_rng.randf_range(-0.08, 0.08), 0.8, _clutter_rng.randf_range(-0.2, 0.2))
		drop(things[i], where, yaw + _clutter_rng.randf_range(0.0, 360.0))


## A kitchen cupboard with something standing on it.
func _cabinet_with(at: Vector3, yaw: float, model: String, scale: float) -> void:
	var turn := Basis(Vector3.UP, deg_to_rad(yaw))
	place("painted_wooden_cabinet", at, yaw)
	prop(model, Transform3D(turn * Basis(Vector3.UP, deg_to_rad(_clutter_rng.randf_range(-12.0, 12.0))), at + Vector3(0, _model("painted_wooden_cabinet").box.size.y, 0)), scale)


## Cans of cleaner put down against a wall, and a broom leaning by them.
func _cans(at: Vector3, yaw: float) -> void:
	var turn := Basis(Vector3.UP, deg_to_rad(yaw))
	for i in _clutter_rng.randi_range(2, 3):
		place("multi_cleaner_5_litre", at + turn * Vector3(-0.25 + i * 0.26, 0, _clutter_rng.randf_range(-0.12, 0.05)), yaw + _clutter_rng.randf_range(-30.0, 30.0))
	if _clutter_rng.randf() < 0.6:
		drop("plastic_broom", at + turn * Vector3(0.45, 0, -0.1), yaw)


## Two cardboard boxes, one on the other.
func _boxes(at: Vector3, yaw: float) -> void:
	var size: Vector3 = _model("cardboard_box_01").box.size
	place("cardboard_box_01", at, yaw + 8.0)
	place("cardboard_box_01", at + Vector3(0.02, size.y, 0.02), yaw - 14.0)


## Three barrels in a row against a wall, one of them a little forward.
func _barrel_row(at: Vector3, yaw: float) -> void:
	var turn := Basis(Vector3.UP, deg_to_rad(yaw))
	for k in 3:
		barrel(at + turn * Vector3((k - 1) * 0.75, 0, (k % 2) * 0.35 - 0.15))


## A few piles of the same crate or tote, side by side.
func _piles(model: String, at: Vector3, yaw: float, count: int) -> void:
	var turn := Basis(Vector3.UP, deg_to_rad(yaw))
	var wide: float = _model(model).box.size.x + 0.08
	for i in count:
		pile(model, at + turn * Vector3((i - (count - 1) * 0.5) * wide, 0, _prop_rng.randf_range(-0.04, 0.04)), yaw + _prop_rng.randf_range(-6.0, 6.0), _prop_rng.randi_range(2, 4))


## Two runs of shelving back to back.
func _shelving_pair(at: Vector3, yaw: float, length: float) -> void:
	var turn := Basis(Vector3.UP, deg_to_rad(yaw))
	shelving(at + turn * Vector3(0, 0, 0.24), yaw, length)
	shelving(at - turn * Vector3(0, 0, 0.24), yaw + 180.0, length)


## Which lockers of a row stand ajar, and by how many degrees.
func _ajar(count: int) -> Dictionary:
	var open := {}
	for i in _prop_rng.randi_range(1, 2):
		open[_prop_rng.randi_range(0, count - 1)] = _prop_rng.randf_range(8.0, 70.0)
	return open


## Stands things against the walls of a room, where nothing opens in them.
## Each of `things` is [how likely it is, how wide, how deep, what builds
## it]; the last is called with its middle on the floor and the turn that
## makes it face the room. No more than `most` in all, and the higher
## `crowd` (0 to 1) the closer together. Returns how many were stood.
func _line_walls(room_name: String, things: Array, most := 99, crowd := 0.5) -> int:
	var total := 0.0
	var narrowest: Array = things[0]
	for thing: Array in things:
		total += thing[0]
		if thing[1] < narrowest[1]:
			narrowest = thing
	var stood := 0
	# Begin with another wall every time, or the first would get the best.
	var first := _rng.randi_range(0, 3)
	for turn in 4:
		var side := (first + turn) % 4
		for span: Vector2 in _free_spans(room_name, side, 0.9, true):
			var at := span.x + _rng.randf_range(0.1, 0.5 + (1.0 - crowd) * 1.5)
			while stood < most:
				var pick := _rng.randf() * total
				var thing: Array = things[0]
				for candidate: Array in things:
					pick -= candidate[0]
					if pick <= 0.0:
						thing = candidate
						break
				if at + thing[1] > span.y - 0.1:
					thing = narrowest
				var wide: float = thing[1]
				var deep: float = thing[2]
				if at + wide > span.y - 0.1:
					break
				var middle := _wall_spot(room_name, side, at + wide * 0.5, deep * 0.5 + 0.03)
				if _room_free(room_name, Vector2(middle.x, middle.z), maxf(deep * 0.5, 0.3) + 0.15 + WAY_BETWEEN):
					(thing[3] as Callable).call(middle, _yaw_in(side))
					_stand(room_name, Vector2(middle.x, middle.z), maxf(wide, deep) * 0.5)
					_wall(room_name, side, at, at + wide)
					stood += 1
				at += wide + lerpf(2.6, 0.15, crowd) * _rng.randf_range(0.6, 1.4)
	return stood


## Stands rows of something down the length of a room, an aisle apart, as
## the shelves of an archive: `build` is called for every piece of a row,
## `length` long, with its middle on the floor and its turn.
func _room_rows(room_name: String, length: float, build: Callable) -> void:
	var floor_left := _room_inside(room_name).grow(-2.3)
	if floor_left.size.x < length or floor_left.size.y < length:
		return
	var along_x := floor_left.size.x >= floor_left.size.y
	var long := floor_left.size.x if along_x else floor_left.size.y
	var wide := floor_left.size.y if along_x else floor_left.size.x
	var rows := int(wide / 2.7) + 1
	var pieces := maxi(1, int(long / (length + 0.05)))
	for r in rows:
		for k in pieces:
			var down := (k + 0.5) * long / pieces
			var over := wide * (r + 0.5) / rows
			var spot := floor_left.position + (Vector2(down, over) if along_x else Vector2(over, down))
			if not _room_free(room_name, spot, length * 0.5):
				continue
			build.call(Vector3(spot.x, 0, spot.y), 0.0 if along_x else 90.0)
			_stand(room_name, spot, length * 0.5)


## Things to take cover behind, on the floor of a room away from its walls:
## as many as fit about `pitch` metres apart where the floor is free. `kinds`
## is what to draw from, and crates come `fewest` to `most` to a stack.
func _room_islands(room_name: String, pitch: float, kinds: Array, fewest: int, most: int) -> void:
	for spot in _room_spread(room_name, 2.2, pitch, 1.3):
		var on_floor := Vector3(spot.x, 0, spot.y)
		var turn := _rng.randf_range(0.0, 360.0)
		var facing := Basis(Vector3.UP, deg_to_rad(turn))
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
			"case":
				case(on_floor, turn, Vector3(_prop_rng.randf_range(1.2, 1.9), _prop_rng.randf_range(0.9, 1.5), _prop_rng.randf_range(0.9, 1.2)))
				if _prop_rng.randf() < 0.5:
					case(on_floor + facing * Vector3(0.2, 0, 1.25), turn + _prop_rng.randf_range(-20.0, 20.0), Vector3(1.1, 0.8, 0.9))
			"drum":
				cable_drum(on_floor, turn, _prop_rng.randf_range(1.5, 2.0), 1.0)
			"totes":
				_piles("industrial_pastic_container", on_floor, turn, 2)
			"plastic":
				_piles("plastic_crate_02", on_floor, turn, _prop_rng.randi_range(2, 3))
			"cart":
				place(["tool_cart", "industrial_storage_cart", "hand_truck"][_prop_rng.randi_range(0, 2)], on_floor, turn)
			"generator":
				place("portable_generator", on_floor, turn)
				place("metal_toolbox", on_floor + facing * Vector3(0.75, 0, 0.2), turn + 40.0)
			"stove":
				place("barrel_stove", on_floor, turn)
				floor_decal("scorch_1", on_floor, Vector2(2.2, 2.2), turn)
				place("trashbag", on_floor + facing * Vector3(0.8, 0, 0.3), turn)
			"bins":
				place("metal_trash_can", on_floor, turn)
				place("trashbag", on_floor + facing * Vector3(0.2, 0, 0.75), turn + 70.0)
			"panels":
				screens(on_floor, turn, 2, "container_grey")
			"table":
				place("painted_wooden_table", on_floor, turn)
				if _rng.randf() < 0.7:
					place("metal_stool_03", on_floor + facing * Vector3(0.4, 0, 0.95), turn + 180.0)


## One or two of the large things a room has room for: a car under a sheet,
## a rack of steel plate.
func _room_big(room_name: String, kinds: Array, most: int) -> void:
	for spot in _room_spread(room_name, 3.4, 9.0, 2.6, most):
		var on_floor := Vector3(spot.x, 0, spot.y)
		var turn := _rng.randf_range(0.0, 360.0)
		match kinds[_rng.randi_range(0, kinds.size() - 1)]:
			"car":
				place("covered_car", on_floor, turn)
			"plates":
				plate_rack(on_floor, turn)


## Spots on the floor of a room for things that reach `reach` around them:
## `inset` from its walls, `pitch` apart, where the floor is free, and no
## more than `most` of them. Every spot a metre and a half from the next is
## tried, in an order the dice decide. What is returned counts as stood on
## from then on.
func _room_spread(room_name: String, inset: float, pitch: float, reach: float, most := 999) -> Array[Vector2]:
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
		if taken.size() >= most:
			break
		# A good step more than it reaches itself: what stands on the floor
		# leaves room to walk between it and the next thing.
		if taken.any(func(island: Vector2) -> bool: return island.distance_to(spot) < pitch) or not _room_free(room_name, spot, reach + WAY_BETWEEN):
			continue
		taken.append(spot)
		_stand(room_name, spot, reach)
	return taken


# --- On the walls and under the ceiling -----------------------------------------


## What hangs on the walls of a room once everything stands: a radiator
## under a window, a switch by the door, and what a room of its stock has on
## its walls: a clock, a board, a first-aid box, a warning.
func _room_fittings(room_name: String) -> void:
	var plan: Dictionary = _floor_plan[room_name]
	var high: float = plan.height
	var stock: String = _fit(room_name, "stock")
	var brick: bool = ROOM_KINDS[plan.kind].wall == "brick"
	var open_air: bool = plan.roof.is_empty()
	if not brick:
		for pane: Dictionary in plan.windows:
			var front := _wall_spot(room_name, pane.side, pane.along, 0.3)
			if pane.sill >= 0.85 and pane.width >= 1.4 and _room_free(room_name, Vector2(front.x, front.z), 0.25):
				radiator(_wall_spot(room_name, pane.side, pane.along, 0.0), _normal_in(pane.side), clampi(int(pane.width * 8.0), 8, 20))
				_stand(room_name, Vector2(front.x, front.z), 0.7)
		# Conduit down to a switch beside the door one comes in by.
		var way: Dictionary = plan.entry
		if not way.is_empty():
			for aside: float in [1.0, -1.0]:
				var along: float = way.along + aside * (way.width * 0.5 + 0.32)
				var span := _wall_span(room_name, way.side)
				if along > span.x + 0.2 and along < span.y - 0.2 and _wall_free(room_name, way.side, along, 0.12):
					switch_drop(_wall_spot(room_name, way.side, along, 0.0, high - 0.02), _normal_in(way.side))
					_wall(room_name, way.side, along - 0.12, along + 0.12)
					break
	if brick:
		# A lamp over every door of a yard or a plant room, where there is
		# no daylight to find the way out by; in a plant room one every few
		# metres along the walls as well, or what stands behind its
		# machines stands in the dark; and a number on every pier.
		if open_air or plan.kind == "plant":
			for way: Dictionary in plan.doors:
				if way.to != "" and way.height + 1.0 < high:
					wall_lamp(_wall_spot(room_name, way.side, way.along, 0.0, way.height + 0.85), _normal_in(way.side), true, 6.0, 3.0)
		if plan.kind == "plant":
			for side in 4:
				for span: Vector2 in _free_spans(room_name, side, 1.6, true):
					var count := roundi((span.y - span.x) / 5.5)
					for i in count:
						var along := span.x + (span.y - span.x) * (i + 0.5) / count
						if _wall_free(room_name, side, along, 0.3):
							wall_lamp(_wall_spot(room_name, side, along, 0.0, 2.45), _normal_in(side), true, 6.5, 3.0)
							_wall(room_name, side, along - 0.3, along + 0.3)
		var numbers: Array[String] = ["1", "2", "3", "4", "5"]
		var count := 0
		for stood: Dictionary in plan.piers:
			if open_air or count >= numbers.size() or stood.side == EAST or stood.side == WEST:
				continue
			if stood.side == NORTH:
				label(numbers[count], _wall_spot(room_name, stood.side, stood.along, 0.3, 3.1), _normal_in(stood.side), 0.34, Color(0.07, 0.07, 0.07), 0.04)
				count += 1
	var pose_flat := Basis(Vector3.RIGHT, PI * 0.5)
	match stock:
		"office", "lodge", "archive":
			_hang(room_name, 0.4, func(at: Vector3, inwards: Vector3) -> void: hang("wall_clock", at + Vector3.UP * 2.25, inwards))
			_hang(room_name, 1.3, func(at: Vector3, inwards: Vector3) -> void: pin_board(at + Vector3.UP * 1.6, inwards))
			_hang(room_name, 0.4, func(at: Vector3, inwards: Vector3) -> void: hang("clipboard", at + Vector3.UP * 1.5, inwards, pose_flat))
			if stock == "lodge":
				_hang(room_name, 0.7, func(at: Vector3, inwards: Vector3) -> void: hang("medical_box", at + Vector3.UP * 1.6, inwards, pose_flat))
				_hang(room_name, 0.8, func(at: Vector3, inwards: Vector3) -> void: pin_board(at + Vector3.UP * 1.55, inwards, 0.7))
		"canteen":
			_hang(room_name, 0.4, func(at: Vector3, inwards: Vector3) -> void: hang("wall_clock", at + Vector3.UP * 2.3, inwards))
			_hang(room_name, 0.7, func(at: Vector3, inwards: Vector3) -> void: hang("dartboard", at + Vector3.UP * 1.73, inwards))
			_hang(room_name, 1.6, func(at: Vector3, inwards: Vector3) -> void: pin_board(at + Vector3.UP * 1.6, inwards, 1.5))
			_hang(room_name, 1.2, func(at: Vector3, inwards: Vector3) -> void: sign_plate(at + Vector3.UP * 2.1, inwards, "NO SMOKING", 0.24, "enamel_red"))
		"kitchen", "changing":
			_hang(room_name, 0.4, func(at: Vector3, inwards: Vector3) -> void: hang("wall_clock", at + Vector3.UP * 2.25, inwards))
			_hang(room_name, 1.3, func(at: Vector3, inwards: Vector3) -> void: pin_board(at + Vector3.UP * 1.6, inwards))
		"corridor":
			var long := maxf(_room_inside(room_name).size.x, _room_inside(room_name).size.y)
			for i in maxi(1, int(long / 14.0)):
				_hang(room_name, 1.3, func(at: Vector3, inwards: Vector3) -> void: pin_board(at + Vector3.UP * 1.6, inwards))
			if long > 12.0:
				_hang(room_name, 0.4, func(at: Vector3, inwards: Vector3) -> void: hang("wall_clock", at + Vector3.UP * 2.3, inwards))
				_hang(room_name, 0.7, func(at: Vector3, inwards: Vector3) -> void: hang("medical_box", at + Vector3.UP * 1.6, inwards, pose_flat))
				_hang(room_name, 0.5, func(at: Vector3, inwards: Vector3) -> void: hang("security_camera_01", at + Vector3.UP * 2.45, inwards))
		"storage", "tools", "despatch":
			_hang(room_name, 1.2, func(at: Vector3, inwards: Vector3) -> void: sign_plate(at + Vector3.UP * 2.2, inwards, "NO SMOKING", 0.24, "enamel_red"))
			_hang(room_name, 0.4, func(at: Vector3, inwards: Vector3) -> void: hang("clipboard", at + Vector3.UP * 1.5, inwards, pose_flat))
			if stock == "despatch":
				_hang(room_name, 0.7, func(at: Vector3, inwards: Vector3) -> void: hang("medical_box", at + Vector3.UP * 1.6, inwards, pose_flat))
		"works", "paint", "bay":
			_hang(room_name, 0.5, func(at: Vector3, inwards: Vector3) -> void: hang("wall_clock", at + Vector3.UP * 2.6, inwards, Basis(), 1.6))
			_hang(room_name, 0.7, func(at: Vector3, inwards: Vector3) -> void: hang("medical_box", at + Vector3.UP * 1.6, inwards, pose_flat))
			_hang(room_name, 1.4, func(at: Vector3, inwards: Vector3) -> void: sign_plate(at + Vector3.UP * 2.4, inwards, "NO SMOKING" if stock == "paint" else "KEEP CLEAR", 0.3, "enamel_red"))
			_hang(room_name, 1.3, func(at: Vector3, inwards: Vector3) -> void: pin_board(at + Vector3.UP * 1.6, inwards))
		"plant":
			for i in 2:
				_hang(room_name, 1.2, func(at: Vector3, inwards: Vector3) -> void: _warning(at, inwards))
		"yard":
			_hang(room_name, 0.5, func(at: Vector3, inwards: Vector3) -> void: hang("security_camera_01", at + Vector3.UP * 3.4, inwards))
			_hang(room_name, 1.4, func(at: Vector3, inwards: Vector3) -> void: sign_plate(at + Vector3.UP * 2.6, inwards, "KEEP CLEAR", 0.3, "enamel_red"))
			for i in 3:
				_hang(room_name, 0.5, func(at: Vector3, inwards: Vector3) -> void: downpipe(at, inwards, high))


## A warning on a wall: the triangle, and under it what it warns of.
func _warning(at: Vector3, inwards: Vector3) -> void:
	wall_decal("warning_1", at + Vector3.UP * 2.3 + inwards * 0.02, inwards, 0.6, 0.6, Color.WHITE, 0.2)
	sign_plate(at + Vector3.UP * 1.8, inwards, "DANGER", 0.22, "enamel_red")


## Hangs something `wide` on a wall of a room where the wall is free: `build`
## is called with the spot at the foot of the wall under its middle and the
## way the wall faces. False if no wall has room for it.
func _hang(room_name: String, wide: float, build: Callable) -> bool:
	var first := _decal_rng.randi_range(0, 3)
	for turn in 4:
		var side := (first + turn) % 4
		var spans := _free_spans(room_name, side, 0.5, true)
		for k in spans.size():
			var span: Vector2 = spans[(k + first) % spans.size()]
			var room_for := span.y - span.x - wide
			if room_for < 0.2:
				continue
			# A few tries along the span, from a spot the dice pick.
			for attempt in 6:
				var along := span.x + wide * 0.5 + room_for * fposmod(_decal_rng.randf() + attempt / 6.0, 1.0)
				if _wall_free(room_name, side, along, wide * 0.5):
					build.call(_wall_spot(room_name, side, along, 0.0), _normal_in(side))
					_wall(room_name, side, along - wide * 0.5, along + wide * 0.5)
					return true
	return false


## What runs under the ceiling of a room, by its kind and its roof: a duct
## and a cable ladder down a corridor, a duct along the wall of an office,
## sprinklers over a store, a round duct under the trusses of a hall and an
## air main along its walls, and steam and water mains through a plant room.
func _room_services(room_name: String) -> void:
	var plan: Dictionary = _floor_plan[room_name]
	if plan.roof.is_empty():
		return
	var high: float = plan.height
	var inner := _room_inside(room_name)
	var along_x := inner.size.x >= inner.size.y
	var long := inner.size.x if along_x else inner.size.y
	var wide := inner.size.y if along_x else inner.size.x
	# A spot under the ceiling: `down` the length of the room from its
	# north-west corner, `over` across it, at height `y`.
	var under := func(down: float, over: float, y: float) -> Vector3:
		return Vector3(inner.position.x + (down if along_x else over), y, inner.position.y + (over if along_x else down))
	match plan.kind:
		"corridor":
			duct_run(under.call(0.01, 0.5, high - 0.2), under.call(long - 0.01, 0.5, high - 0.2), high, Vector2(0.4, 0.28), maxi(1, int(long / 5.0)))
			cable_ladder(under.call(0.02, wide - 0.45, high - 0.3), under.call(long - 0.02, wide - 0.45, high - 0.3), high, 4, 0.3)
			pipe_run([under.call(0.0, wide - 0.95, high - 0.35), under.call(long, wide - 0.95, high - 0.35)], 0.05, "pipe", high)
		"office", "canteen", "control", "kitchen", "changing":
			# Along the long wall that has the fewest windows in it.
			var sides: Array[int] = [NORTH, SOUTH]
			if not along_x:
				sides = [WEST, EAST]
			var near := 0 if (plan.windows as Array).filter(func(pane: Dictionary) -> bool: return pane.side == sides[0]).size() <= (plan.windows as Array).filter(func(pane: Dictionary) -> bool: return pane.side == sides[1]).size() else 1
			var over := 0.42 if near == 0 else wide - 0.42
			duct_run(under.call(0.01, over, high - 0.22), under.call(long - 0.01, over, high - 0.22), high, Vector2(0.45, 0.3), maxi(1, int(long / 4.0)))
		"storage":
			var lines := maxi(1, roundi(wide / 3.6))
			for i in lines:
				var over := wide * (i + 0.5) / lines + 0.35
				sprinkler_line(under.call(0.6, over, high - 0.22), under.call(long - 0.05, over, high - 0.22), high)
			# The main they branch from, and the riser that feeds it.
			pipe_run([under.call(0.6, 0.12, 0.0), under.call(0.6, 0.12, high - 0.22), under.call(0.6, wide - 0.2, high - 0.22)], 0.04, RED)
			pipe_valve(under.call(0.6, 0.12, 1.2), Vector3.UP, (under.call(1.6, 0.12, 1.2) as Vector3) - (under.call(0.6, 0.12, 1.2) as Vector3), 0.04)
		"hall":
			if plan.roof.form == "trusses":
				# Under the ties, a quarter of the way across.
				var from: Vector3 = under.call(0.6, wide * 0.27, high - 0.5)
				var to: Vector3 = under.call(long - 0.6, wide * 0.27, high - 0.5)
				round_duct(from, to, high - 0.2, 0.26, maxi(2, int(long / 5.0)))
			# The air main along the two long walls, over the heads of the
			# doors and under the sills of the windows, with a drop to a valve
			# at every other pier.
			var level := minf(2.95, high - 1.6)
			for pane: Dictionary in plan.windows:
				level = minf(level, pane.sill - 0.25)
			var long_walls: Array[int] = [NORTH, SOUTH]
			if not along_x:
				long_walls = [WEST, EAST]
			for side in long_walls:
				var span := _wall_span(room_name, side)
				wall_pipe(_wall_spot(room_name, side, span.x + 0.05, 0.3, level), _wall_spot(room_name, side, span.y - 0.05, 0.3, level), _normal_in(side), 0.04, "pipe")
				var piers := piers_along(room_name, side)
				for k in range(0, piers.size(), 2):
					var top := _wall_spot(room_name, side, piers[k] + 0.42, 0.3, level) + _normal_in(side) * 0.11
					pipe_run([top, Vector3(top.x, 1.25, top.z)], 0.022, "pipe")
					pipe_valve(Vector3(top.x, 1.45, top.z), Vector3.UP, _normal_in(side), 0.022)
		"plant":
			# Two mains down the length of the room under the slab, one lagged,
			# and a cable tray along the wall across from them.
			# A plan says {"mains": false} for a room that has pipes enough of
			# its own up there.
			var over := wide * 0.24
			if plan.fit.get("mains", true):
				pipe_run([under.call(0.0, over, high - 0.95), under.call(long, over, high - 0.95)], 0.13, "tank", high)
				pipe_run([under.call(0.0, over + 0.42, high - 0.9), under.call(long, over + 0.42, high - 0.9)], 0.07, "pipe", high)
				pipe_valve(under.call(long * 0.5 + 0.9, over + 0.42, high - 0.9), (under.call(1.0, 0.0, 0.0) as Vector3) - (under.call(0.0, 0.0, 0.0) as Vector3), Vector3.DOWN, 0.07)
			var side: int = SOUTH if along_x else EAST
			var span := _wall_span(room_name, side)
			var level := minf(3.0, high - 1.2)
			if (plan.windows as Array).all(func(pane: Dictionary) -> bool: return pane.side != side or pane.sill > level + 0.4 or pane.head < level - 0.4):
				cable_tray(_wall_spot(room_name, side, span.x + 0.1, 0.0, level), _wall_spot(room_name, side, span.y - 0.1, 0.0, level), _normal_in(side), 5, 0.3)


# --- The robots -----------------------------------------------------------------


## Plans where `count` robots can wait in a room out of sight of `entry`,
## the spot the player comes in at: two by two, as far from it as the floor
## allows and well apart, each pair behind something tall that _room_stock()
## will stand between it and the door. A pair that stands far enough off
## needs nothing.
func _plan_screens(room_name: String, count: int, entry: Vector2) -> void:
	var plan: Dictionary = _floor_plan[room_name]
	if _fit(room_name, "stock") == "corridor":
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
		# And the way round either end of it, or whatever is stood against
		# a wall nearby shuts the robots in behind their screen.
		for side: float in [-1.0, 1.0]:
			var round_end := stands + across * side * (4.2 if open_air else 2.7)
			plan.stood.append(Vector3(round_end.x, round_end.y, 0.9))


## Stands something tall where a robot is to wait behind it, 3.7 m wide and
## 2 m high or more: what a room of that stock would have standing there,
## see SCREENS, and the next of them for the next screen of the room.
func _room_screens(room_name: String) -> void:
	var plan: Dictionary = _floor_plan[room_name]
	var forms: Array = SCREENS.get(_fit(room_name, "stock"), ["pallets"])
	# The spray booth of a paint shop comes first: there is one.
	var first := 0 if forms[0] == "booth" else _rng.randi_range(0, forms.size() - 1)
	for i in plan.screens.size():
		var screen: Dictionary = plan.screens[i]
		var on_floor := Vector3(screen.at.x, 0, screen.at.y)
		var sideways := Basis(Vector3.UP, deg_to_rad(screen.turn)) * Vector3.RIGHT
		match forms[(first + i) % forms.size()]:
			"container":
				container(["container_red", "container_green", "container_blue", "container_grey"][_rng.randi_range(0, 3)], on_floor, screen.along_x)
			"cupboard":
				cupboard("machine", on_floor, screen.turn, Vector3(2.4, 1.9, 0.5))
			"lockers":
				lockers("machine_blue", on_floor, screen.turn, 9, _ajar(9))
			"shelving":
				for side: float in [-1.0, 1.0]:
					shelving(on_floor + sideways * side * 0.925, screen.turn, 1.85, 2.1, true)
			"cases":
				cases(on_floor, screen.turn, 3.7)
			"booth":
				# With its back to the door: whoever waits, waits inside it.
				var inside := on_floor + Basis(Vector3.UP, deg_to_rad(screen.turn)) * Vector3(0, 0, 1.1)
				spray_booth(inside, screen.turn, plan.height, false)
				_stand(room_name, Vector2(inside.x, inside.z), 2.3)
			"screens":
				screens(on_floor, screen.turn, 3)
			"plates":
				plate_rack(on_floor, screen.turn)
			"drums":
				# Two of them, one a step behind the other, so that nothing
				# shows between their rims.
				var ahead := Basis(Vector3.UP, deg_to_rad(screen.turn)) * Vector3.BACK
				for side: float in [-1.0, 1.0]:
					cable_drum(on_floor + sideways * side * 0.86 + ahead * side * 0.6, screen.turn, 2.0, 1.1)
			_:
				# Three stacks of pallets side by side, of unequal height.
				for along: float in [-1.25, 0.0, 1.25]:
					pallet(on_floor + sideways * along, screen.turn + _rng.randf_range(-4.0, 4.0), _rng.randi_range(12, 14))


## Posts the robots of every fight, now that everything stands. A robot goes
## where it can be walked to and where it is out of sight of the door the
## player comes in by, of where he starts and of every checkpoint, or else
## POST_DISTANCE from them; as far from that door as the room allows, and a
## few steps from the next robot. Called by the builder from _survey().
func _garrison(space: PhysicsDirectSpaceState3D, ray: PhysicsRayQueryParameters3D, navmesh: NavigationMesh, walked: Dictionary) -> void:
	super(space, ray, navmesh, walked)
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



# --- Where to look from ---------------------------------------------------------


## The first view of a room: what the player sees when he has come a step
## in by its door, turned a little towards what there is to see in it, or
## towards its middle; of the room he starts in, what he sees as the level
## begins. The builder puts it before the views it picks itself.
func _own_views(zone_name: String) -> PackedFloat32Array:
	var views := PackedFloat32Array()
	if not _floor_plan.has(zone_name):
		return views
	var way: Dictionary = _floor_plan[zone_name].entry
	var eye := _room_middle(zone_name)
	var towards := Vector2.RIGHT
	if not way.is_empty():
		eye = _door_spot(zone_name, way, 0.9)
		var straight := _normal_in(way.side)
		var goal := _eye_catcher(zone_name)
		if goal == Vector2.INF:
			goal = _room_middle(zone_name)
		towards = Vector2(straight.x, straight.z)
		towards = towards.rotated(clampf(towards.angle_to(goal - eye), deg_to_rad(-32.0), deg_to_rad(32.0)))
	elif zone_name == _start_room and not (_floor_plan[zone_name].doors as Array).is_empty():
		# Where the level begins: what the player sees first of all.
		towards = _door_spot(zone_name, _floor_plan[zone_name].doors[0], 0.0) - eye
	else:
		return views
	views.append_array([snappedf(eye.x, 0.01), 1.6, snappedf(eye.y, 0.01), snappedf(rad_to_deg(atan2(-towards.x, -towards.y)), 0.1), -3.0])
	return views


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


## The wall of a room that faces that way: the other way round.
func _side_of(inwards: Vector3) -> int:
	if absf(inwards.z) > absf(inwards.x):
		return NORTH if inwards.z > 0.0 else SOUTH
	return WEST if inwards.x > 0.0 else EAST


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
## keeping `clear` of every doorway. With `low` they also keep clear of what
## something standing against the wall would stand in front of or against:
## a window that begins under head height, and a pier. A window whose sill
## lies under `under` counts as an opening whatever else.
func _free_spans(room_name: String, side: int, clear: float, low: bool, under := 0.0) -> Array[Vector2]:
	var plan: Dictionary = _floor_plan[room_name]
	var taken: Array[Vector2] = []
	for way: Dictionary in plan.doors:
		if way.side == side:
			taken.append(Vector2(way.along - way.width * 0.5 - clear, way.along + way.width * 0.5 + clear))
	for pane: Dictionary in plan.windows:
		if pane.side == side and ((low and pane.sill < 2.3) or pane.sill < under):
			taken.append(Vector2(pane.along - pane.width * 0.5 - 0.2, pane.along + pane.width * 0.5 + 0.2))
	if low:
		for stood: Dictionary in plan.piers:
			if stood.side == side:
				taken.append(Vector2(stood.along - 0.45, stood.along + 0.45))
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


## Whether a wall of a room is clear, `half` to either side of `along`, of
## its doorways and windows and of what the plan keeps the floor clear for:
## for a pier to stand there.
func _wall_clear(room_name: String, side: int, along: float, half: float) -> bool:
	var plan: Dictionary = _floor_plan[room_name]
	for way: Dictionary in plan.doors:
		if way.side == side and absf(way.along - along) < way.width * 0.5 + half + 0.25:
			return false
	for pane: Dictionary in plan.windows:
		if pane.side == side and absf(pane.along - along) < pane.width * 0.5 + half + 0.15:
			return false
	var spot := _wall_spot(room_name, side, along, 0.3)
	for area: Rect2 in plan.kept:
		if area.grow(half).has_point(Vector2(spot.x, spot.z)):
			return false
	return true


## Whether nothing stands or hangs against a wall of a room yet, `half` to
## either side of `along`.
func _wall_free(room_name: String, side: int, along: float, half: float) -> bool:
	for used: Vector3 in _floor_plan[room_name].walled:
		if int(used.x) == side and along + half > used.y - 0.12 and along - half < used.z + 0.12:
			return false
	var spot := _wall_spot(room_name, side, along, 0.3)
	for area: Rect2 in _floor_plan[room_name].kept:
		if area.grow(half).has_point(Vector2(spot.x, spot.z)):
			return false
	return true


## Notes that something stands or hangs against a wall of a room, from
## `from` to `to` along it.
func _wall(room_name: String, side: int, from: float, to: float) -> void:
	_floor_plan[room_name].walled.append(Vector3(side, from, to))


## Notes that something stands on the floor of a room at `spot` (x and z)
## and reaches `reach` around it.
func _stand(room_name: String, spot: Vector2, reach: float) -> void:
	_floor_plan[room_name].stood.append(Vector3(spot.x, spot.y, reach))


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
