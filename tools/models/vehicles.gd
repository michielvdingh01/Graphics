extends "res://tools/model_builder.gd"
## What an army drives: a quarter-ton field car, a lorry with a tilt over its
## bed, and a tank, that one twice: with its gun ahead and with its turret
## traversed. Build with tools/build_model.sh vehicles; stand one in a level
## to look at it with
## tools/benchmark.sh --quick --spawn="res://scenes/models/tank.scn@4,0,0,30".
##
## A vehicle stands on the ground at the origin with its nose along -Z. It is
## parked: nothing of it moves. Its steel, its tyres and its tracks are one
## paint, shaders/field_paint.gdshader, that knows how high over the ground a
## spot lies and lays the sand on from below. What is stencilled on it is a
## mesh of its own, "Marks", that throws no shadow. A level stands a vehicle
## with vehicle() in tools/kit/field.gd, which knows what of it is in the way,
## and gives each its own number and its own load there.
##
## Every vehicle is built twice: "Body" is what is seen of it from close by,
## and "Far" the same vehicle from FAR_FROM metres on, put together from the
## same description with everything small left out of it and everything
## round made coarse: see _twice().
##
## What turns when it is driven is a part of its own, with its pivot where
## it turns: a wheel ("Wheel..."), an axle with the wheels on it ("Axle..."),
## the wheels a track runs over ("Road...", "Idler...", "Sprocket..."), the
## steering wheel, and a turret with its gun. Of those only the turret and
## the gun have a far model of their own, under the near one: from afar a
## wheel that does not turn is a wheel. A model says on its root what
## scripts/vehicle.gd has to know of it (see _layout): where its wheels touch
## the ground and which of them steer and drive, and where its seats are.

const ARMY := "army_green"
## Steel that was never painted, or not for long: a chassis, a track.
const IRON := "track"
const RUBBER := "tyre"
const CANVAS := "canvas"
const PANE := "field_glass"
## The glass of a headlamp: the silvered bowl shows through it, and it never burns.
const LENS := "field_lens"
const WOOD := "wood"
const MARKS := "field_marks"
## A side view drawn as (towards the back, up) and pushed out across the
## vehicle: the frame extrude() and slab() want for it.
const SIDE := Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT)
## The sheet of stencils, four squares by four: see _stencils() in
## tools/gen_foliage.gd.
const STAR := Rect2(0, 0, 0.25, 0.25)
const PLATE_5 := Rect2(0.25, 0, 0.25, 0.25)
const PLATE_12 := Rect2(0.5, 0, 0.25, 0.25)
const PLATE_50 := Rect2(0.75, 0, 0.25, 0.25)
const NUMBER_14 := Rect2(0, 0.25, 0.25, 0.25)
const NUMBER_23 := Rect2(0.25, 0.25, 0.25, 0.25)
const TACTICAL := Rect2(0.5, 0.25, 0.25, 0.25)
const ARROW := Rect2(0.75, 0.25, 0.25, 0.25)
const TYRE_PRESSURE := Rect2(0, 0.75, 0.5, 0.125)
const TOP_SPEED := Rect2(0.5, 0.75, 0.5, 0.125)
const NO_STEP := Rect2(0, 0.875, 0.5, 0.125)
const PETROL := Rect2(0.5, 0.875, 0.5, 0.125)

## What is added to the height over the ground written into every corner:
## see _tri().
const HEIGHT_MARK := 1000.0

## From how far off a vehicle is drawn as its far model, and how far apart
## the two distances are at which it changes one way and the other, in metres.
const FAR_FROM := 34.0
const FAR_MARGIN := 4.0
## What the far model leaves out: a piece that is shorter than this every
## way, or thinner than that two ways, or a slat; a bar thinner than this,
## and anything turned that is smaller across.
const FAR_SHORT := 0.34
const FAR_THIN := 0.032
const FAR_BAR := 0.07
const FAR_ROUND := 0.2
## How many sides something round has in the far model, at most.
const FAR_SIDES := 8
## The parts that have a far model of their own, which hangs under them.
const FAR_PARTS := {"Turret": "TurretFar", "Gun": "GunFar"}

## True while the far model of a vehicle is being built, and true if that
## one keeps its bare iron: a tank is half tracks, under a lorry nobody looks.
var _far := false
var _far_iron := false
## The surfaces that are canvas, and what their vertex colour tells
## shaders/canvas.gdshader of the cloth: how much of the ground has got into
## it, how far it has faded, how much light gets into its folds and how much
## of the sun comes through it.
var _cloths := {}
var _dye := Color(0.2, 0.5, 0.9, 0.0)
## What the vehicle being built says of itself on its root, once it is
## built: "wheels", each {part, at, radius, steers, drives, side}, where
## `at` is the middle of the wheel as it hangs and `side` is -1 on its left;
## and "seats", each {role, at, eye, out, exposed, turret}: the hips of who
## sits there, the eyes, where they get out, whether a shot reaches them,
## and whether the seat turns with the turret. A role is "driver" (who on a
## tank lays the gun as well) or "passenger" (who has their own weapons).
## And "hull": what of it is in the way, as boxes {at, size, part}, with the
## part they turn with if they do, "Turret" or "Gun", or as the corners of a
## shape that is not a box {points, part}.
var _layout := {}


func _describe() -> void:
	_twice(_jeep)
	_twice(_truck)
	_twice(_tank.bind("tank", 0.0), true)
	_twice(_tank.bind("tank_b", 38.0), true)
	_twice(_motorcycle)


## Builds a vehicle as `build` describes it, and then once more as its far
## model: the same description, with _far set. `iron` keeps the bare iron in
## that one.
func _twice(build: Callable, iron := false) -> void:
	_far = false
	_layout = {"wheels": [], "seats": [], "hull": []}
	build.call()
	for part_name: String in _parts:
		if not part_name.ends_with("Marks"):
			var near := _parts[part_name].node as MeshInstance3D
			near.visibility_range_end = FAR_FROM
			near.visibility_range_end_margin = FAR_MARGIN
	tag("wheels", _layout.wheels)
	tag("seats", _layout.seats)
	tag("hull", _layout.hull)
	part("Far")
	_far = true
	_far_iron = iron
	_m = Transform3D()
	build.call()
	for part_name: String in ["Far"] + FAR_PARTS.values():
		if _parts.has(part_name):
			var far := _parts[part_name].node as MeshInstance3D
			far.visibility_range_begin = FAR_FROM
			far.visibility_range_begin_margin = FAR_MARGIN
	_far = false
	_m = Transform3D()
	part("Body")


## The far model belongs to the vehicle that was just built.
func model(model_name: String) -> void:
	if not _far:
		super(model_name)


## Builds what follows into the part `part_name` of the near model, which
## turns from `pivot` (in the coordinates of the model) along with `parent`;
## of the far model into its far part if it has one, else into "Far".
func _on(part_name: String, pivot := Transform3D(), parent := "") -> void:
	if not _far:
		part(part_name, pivot, parent)
	elif FAR_PARTS.has(part_name):
		part(FAR_PARTS[part_name], pivot, part_name)
	else:
		part("Far")


## A wheel that touches the ground, for scripts/vehicle.gd: its middle `at`
## as it hangs, its radius, and the part that turns with it.
func _touches(part_name: String, at: Vector3, radius: float, steers: bool, drives := true) -> void:
	if not _far:
		_layout.wheels.append({"part": part_name, "at": at, "radius": radius, "steers": steers, "drives": drives, "side": signf(at.x)})


## A box of what is in the way, for scripts/vehicle.gd: see _layout.
func _solid(at: Vector3, size: Vector3, turns_with := "") -> void:
	if not _far:
		_layout.hull.append({"at": at, "size": size, "part": turns_with})


## What is in the way as the smallest shape round `points`: a hull with its
## ends sloped, as a box is not.
func _solid_round(points: PackedVector3Array, turns_with := "") -> void:
	if not _far:
		_layout.hull.append({"points": points, "part": turns_with})


## The corners of a box at `at` of `size` with its lower edge at one end
## cut away, `cut.x` along and `cut.y` up: the front (-Z) for `end` -1, the
## back for 1.
func _cut_box(at: Vector3, size: Vector3, cut: Vector2, end: float) -> PackedVector3Array:
	var low := at - size * 0.5
	var high := at + size * 0.5
	var near := high.z if end < 0.0 else low.z
	var far := low.z if end < 0.0 else high.z
	var points := PackedVector3Array()
	for x: float in [low.x, high.x]:
		for corner: Vector2 in [Vector2(near, low.y), Vector2(far - end * cut.x, low.y), Vector2(far, low.y + cut.y), Vector2(far, high.y), Vector2(near, high.y)]:
			points.append(Vector3(x, corner.y, corner.x))
	return points


## A seat, for scripts/vehicle.gd: see _layout.
func _sits(role: String, at: Vector3, eye: Vector3, out: Vector3, exposed: bool, on_turret := false) -> void:
	if not _far:
		_layout.seats.append({"role": role, "at": at, "eye": eye, "out": out, "exposed": exposed, "turret": on_turret})


func _tool(mat: String, flags: int, at: Vector3) -> SurfaceTool:
	if _far:
		# Fewer paints, and so fewer things to draw: no glass, boards the
		# colour of the steel, and bare iron only where it is most of what
		# shows. What is left out goes into a surface that is never kept.
		if mat == PANE or mat == LENS or (mat == IRON and not _far_iron):
			return _tool_named("|left out")
		if mat == WOOD:
			mat = ARMY
	var st := super(mat, flags, at)
	if mat == CANVAS:
		_cloths[st] = true
	return st


## True if a box of `size` is too small for the far model: see FAR_SHORT.
func _too_small(size: Vector3) -> bool:
	var sides: Array[float] = [absf(size.x), absf(size.y), absf(size.z)]
	sides.sort()
	return sides[2] < FAR_SHORT or sides[1] < FAR_THIN or (sides[0] < 0.02 and sides[1] < 0.15)


func _box(mat: String, xf: Transform3D, size: Vector3, flags: int) -> void:
	if _far and _too_small(size):
		return
	super(mat, xf, size, flags)


## In the far model nothing has rounded edges.
func _block(mat: String, center: Vector3, size: Vector3, radius := 0.02, rot_deg := Vector3.ZERO) -> void:
	if _far:
		_piece(mat, center, size, rot_deg)
	else:
		super(mat, center, size, radius, rot_deg)


func _plate(mat: String, center: Vector3, size: Vector3) -> void:
	if _far:
		_piece(mat, center, size)
	else:
		super(mat, center, size)


func _bar(mat: String, from: Vector3, to: Vector3, radius: float, segments := 12) -> void:
	if _far:
		if radius < FAR_BAR or maxf(from.distance_to(to), radius * 2.0) < FAR_SHORT:
			return
		segments = mini(segments, FAR_SIDES)
	else:
		segments = maxi(segments, _round_enough(radius))
	super(mat, from, to, radius, segments)


## How many sides something round of `radius` needs close by for nobody to
## count them: a gun, an exhaust, a tank of fuel.
func _round_enough(radius: float) -> int:
	if radius >= 0.25:
		return 28
	if radius >= 0.1:
		return 20
	if radius >= 0.05:
		return 14
	return 0


## In the far model something turned keeps its ends and where it is widest,
## and nothing of what lies between.
func _turned(mat: String, from: Vector3, axis: Vector3, profile: PackedVector2Array, segments := 24, smooth := false) -> void:
	if _far:
		var widest := 0.0
		for spot in profile:
			widest = maxf(widest, spot.x)
		if widest < FAR_ROUND:
			return
		var coarse := PackedVector2Array()
		for i in profile.size():
			if i == 0 or i == profile.size() - 1 or profile[i].x >= widest * 0.98:
				coarse.append(profile[i])
		profile = coarse
		segments = mini(segments, FAR_SIDES)
	else:
		var widest := 0.0
		for spot in profile:
			widest = maxf(widest, spot.x)
		segments = maxi(segments, _round_enough(widest))
	super(mat, from, axis, profile, segments, smooth)


func slab(mat: String, xf: Transform3D, outline: PackedVector2Array, thickness: float, bevel := 0.0, flags := 0) -> void:
	super(mat, xf, outline, thickness, 0.0 if _far else bevel, flags)


## Canvas is not worn along its edges as steel is: its vertex colour says
## what has happened to the cloth instead. Every corner also says how high
## over the ground it lies, in CUSTOM0: a wheel or a turret is a part of its
## own, whose own Y is not that, and shaders/field_paint.gdshader lays the
## sand on by it. It is put a thousand up, so that a mesh without it (one of
## a level) is told apart.
func _tri(st: SurfaceTool, p: Array, n: Array, uv: Array, edge: Array = []) -> void:
	if _cloths.has(st):
		edge = [_dye, _dye, _dye]
	st.set_custom_format(0, SurfaceTool.CUSTOM_R_FLOAT)
	for i: int in [0, 2, 1]:
		st.set_color(NO_EDGE if edge.is_empty() else edge[i])
		st.set_normal(_to_part.basis * n[i])
		st.set_uv(uv[i])
		st.set_custom(0, Color(HEIGHT_MARK + (p[i] as Vector3).y, 0.0, 0.0, 0.0))
		st.add_vertex(_to_part * p[i])


# --- What they are put together from -------------------------------------------------


## Something stencilled on: the square `mark` of the sheet, `size` wide and
## high, on a face that stands in the XY of `xf` and looks along its +Z.
func _stencil(mark: Rect2, xf: Transform3D, size: Vector2) -> void:
	if _far:
		return
	# What is painted on the turret turns with it.
	var back := _current
	var on := "TurretMarks" if back in ["Turret", "Gun"] else "Marks"
	part(on, _parts["Turret"].frame if on == "TurretMarks" else Transform3D(), "Turret" if on == "TurretMarks" else "")
	var marks := _parts[on].node as MeshInstance3D
	marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Nobody reads a number from further off than this.
	marks.visibility_range_end = 70.0
	marks.visibility_range_end_margin = 6.0
	var frame := _m * xf
	var half := size * 0.5
	var out := frame.basis.z
	_quad(_tool(MARKS, _part, frame.origin), [frame * Vector3(-half.x, -half.y, 0.003), frame * Vector3(half.x, -half.y, 0.003), frame * Vector3(half.x, half.y, 0.003), frame * Vector3(-half.x, half.y, 0.003)],
		[out, out, out, out], [Vector2(mark.position.x, mark.end.y), mark.end, Vector2(mark.end.x, mark.position.y), mark.position])
	part(back)


## The same on the side of a vehicle: at `at`, on the side `side` (-1 left,
## 1 right), reading the right way round from there.
func _stencil_side(mark: Rect2, at: Vector3, side: float, size: Vector2) -> void:
	_stencil(mark, Transform3D(Basis(Vector3.FORWARD * side, Vector3.UP, Vector3.RIGHT * side), at), size)


## A piece of plate or bar with square edges, turned `rot_deg`: whatever is
## too small for its edges to want rounding.
func _piece(mat: String, center: Vector3, size: Vector3, rot_deg := Vector3.ZERO) -> void:
	_box(mat, _m * Transform3D(Basis.from_euler(rot_deg * PI / 180.0), center), size, _part)


## A rail of tube bent through `points`: a grip, a bow, a guard.
func _rail(mat: String, points: Array, radius: float) -> void:
	if _far:
		return
	for i in points.size() - 1:
		_bar(mat, points[i], points[i + 1], radius, 4)


## A hoop of rod round `axis` at `center`: a steering wheel, an eye to tow by.
func _hoop(mat: String, center: Vector3, axis: Vector3, radius: float, thickness: float) -> void:
	if _far:
		return
	_turned(mat, center, axis, PackedVector2Array([
		Vector2(radius - thickness, 0), Vector2(radius, -thickness), Vector2(radius + thickness, 0), Vector2(radius, thickness), Vector2(radius - thickness, 0),
	]), 24, true)


## A wheel with its middle at `at`, on an axle that leaves the vehicle along
## `out`: a cross-country tyre on a pressed rim with its hub. `bars` is how
## many bars of tread go round each shoulder of the tyre; with none it is
## the tyre alone, for the inner one of a pair. `spoked` hangs it on wire
## spokes instead, as a motorcycle's is.
func _wheel(at: Vector3, radius: float, width: float, out: Vector3, bars := -1, spoked := false) -> void:
	var from := at - out * width * 0.5
	if bars < 0:
		# A bar of tread every hand's breadth or so round the tyre.
		bars = maxi(roundi(TAU * radius / 0.085 * 0.5) * 2, 12)
	_tyre(from, out, radius, width, spoked)
	if bars == 0:
		return
	# The tread: bars from either shoulder towards the middle, the one row
	# half a bar on from the other and slanted the other way, as a chevron.
	var frame := _up_along(out)
	for bar in (0 if _far else bars * 2):
		var shoulder := 1.0 if bar % 2 == 0 else -1.0
		var turn := TAU * (bar / 2 + (0.25 if shoulder > 0.0 else 0.75)) / bars
		var spoke := frame.x * cos(turn) + frame.z * sin(turn)
		var slant := Basis(spoke, 0.42 * shoulder)
		var lug := Vector3(width * 0.4, 0.024 * radius / 0.4, minf(TAU * radius / bars * 0.38, 0.06))
		_box(RUBBER, _m * Transform3D(slant * Basis(out, spoke, out.cross(spoke)), at + spoke * (radius + lug.y * 0.5 - 0.004) + out * width * 0.22 * shoulder), lug, _part)
	if spoked:
		# A narrow rim of steel, a drum for a hub, and two rows of spokes
		# from either flange of the drum, crossing on their way out.
		_turned(IRON, from, out, PackedVector2Array([
			Vector2(radius * 0.7, width * 0.12), Vector2(radius * 0.76, width * 0.2), Vector2(radius * 0.74, width * 0.5), Vector2(radius * 0.76, width * 0.8), Vector2(radius * 0.7, width * 0.88),
		]), 28)
		_turned(IRON, from, out, PackedVector2Array([
			Vector2(0, -width * 0.25), Vector2(radius * 0.32, -width * 0.25), Vector2(radius * 0.32, width * 0.4), Vector2(radius * 0.22, width * 0.45),
			Vector2(radius * 0.22, width * 0.85), Vector2(radius * 0.26, width * 0.9), Vector2(radius * 0.26, width * 1.05), Vector2(radius * 0.1, width * 1.15), Vector2(0, width * 1.15),
		]), 20)
		if _far:
			return
		var spokes := 32
		for i in spokes:
			var row := 1.0 if i % 2 == 0 else -1.0
			var turn := TAU * i / spokes
			var hub := frame.x * cos(turn) + frame.z * sin(turn)
			var rim_turn := turn + row * 0.5
			var rim := frame.x * cos(rim_turn) + frame.z * sin(rim_turn)
			_bar(IRON, at + out * width * (0.15 + 0.25 * row) + hub * radius * 0.24, at + out * width * 0.0 + rim * radius * 0.72, 0.0032, 3)
		return
	# The pressed rim: its flange inside the bead, the well, and the disc
	# dished out to the boss with the nuts on it, and a cap over the hub.
	_turned(ARMY, from, out, PackedVector2Array([
		Vector2(radius * 0.69, width * 0.86), Vector2(radius * 0.625, width * 0.74), Vector2(radius * 0.5, width * 0.6),
		Vector2(radius * 0.32, width * 0.7), Vector2(radius * 0.26, width * 0.85), Vector2(radius * 0.15, width * 0.88),
		Vector2(radius * 0.12, width * 0.99), Vector2(0, width * 1.0),
	]), 24)
	var nuts := 5 if radius < 0.42 else 8
	for nut in (0 if _far else nuts):
		var turn := TAU * (nut + 0.5) / nuts
		var spot := at - out * width * 0.5 + (frame.x * cos(turn) + frame.z * sin(turn)) * radius * 0.22 + out * width * 0.85
		_turned(IRON, spot, out, PackedVector2Array([Vector2(radius * 0.035, 0), Vector2(radius * 0.035, width * 0.13), Vector2(0, width * 0.15)]), 6)
	# The drum behind it.
	_turned(IRON, from, out, PackedVector2Array([Vector2(0, width * 0.2), Vector2(radius * 0.6, width * 0.2)]), 12)


## The tyre of a wheel, its inner face at `from`: sidewalls that bulge, a
## rib round each, and shoulders rounded into a flat crown.
func _tyre(from: Vector3, out: Vector3, radius: float, width: float, narrow := false) -> void:
	var r := radius
	var w := width
	var bead := 0.7 if narrow else 0.64
	_turned(RUBBER, from, out, PackedVector2Array([
		Vector2(r * bead, w * 0.08), Vector2(r * (bead + 0.07), -w * 0.02), Vector2(r * 0.84, -w * 0.06), Vector2(r * 0.875, -w * 0.035),
		Vector2(r * 0.95, w * 0.03), Vector2(r, w * 0.2), Vector2(r, w * 0.8), Vector2(r * 0.95, w * 0.97),
		Vector2(r * 0.875, w * 1.035), Vector2(r * 0.84, w * 1.06), Vector2(r * (bead + 0.07), w * 1.02), Vector2(r * bead, w * 0.92),
	]), 24 if radius < 0.42 else 28, true)


## A lamp that looks along `ahead` from `at`: a pressed bucket with a rim,
## and a lens in it, or the blind it is blacked out with.
func _lamp(at: Vector3, ahead: Vector3, radius: float, lens := true) -> void:
	if _far:
		return
	_turned(ARMY, at - ahead * radius * 1.3, ahead, PackedVector2Array([Vector2(0, 0), Vector2(radius * 0.85, radius * 0.4), Vector2(radius, radius * 1.3), Vector2(radius * 1.05, radius * 1.3), Vector2(radius * 1.05, radius * 1.45), Vector2(radius * 0.88, radius * 1.45), Vector2(radius * 0.86, radius * 1.2), Vector2(0, radius * 1.05)]), 20)
	if lens:
		_turned(LENS, at, ahead, PackedVector2Array([Vector2(radius * 0.88, 0.008), Vector2(radius * 0.6, 0.02), Vector2(0, 0.026)]), 20, true)


## A jerrycan standing at `at`, turned `yaw_deg`: pressed in two halves,
## with its three handles.
func _jerrycan(at: Vector3, yaw_deg: float) -> void:
	if _far:
		return
	var turn := Vector3(0, yaw_deg, 0)
	var frame := Transform3D(Basis.from_euler(turn * PI / 180.0), at)
	_block(ARMY, at + Vector3(0, 0.2, 0), Vector3(0.34, 0.4, 0.15), 0.035, turn)
	_piece(ARMY, at + Vector3(0, 0.2, 0), Vector3(0.345, 0.025, 0.155), turn)
	_piece(ARMY, frame * Vector3(-0.03, 0.42, 0), Vector3(0.24, 0.05, 0.12), turn)
	for z: float in [-0.04, 0.0, 0.04]:
		_bar(ARMY, frame * Vector3(-0.12, 0.455, z), frame * Vector3(0.06, 0.455, z), 0.009, 4)
	_bar(IRON, frame * Vector3(0.12, 0.41, 0), frame * Vector3(0.15, 0.46, 0), 0.022, 5)


## A shovel and an axe, strapped along the side of a vehicle on the side
## `side`, from `at` backwards.
func _pioneer_tools(at: Vector3, side: float) -> void:
	if _far:
		return
	_bar(ARMY, at, at + Vector3(0, 0, 0.62), 0.016, 6)
	_piece(IRON, at + Vector3(side * 0.004, -0.015, -0.11), Vector3(0.012, 0.2, 0.24))
	_bar(ARMY, at + Vector3(0, -0.13, 0.05), at + Vector3(0, -0.13, 0.6), 0.015, 6)
	_piece(IRON, at + Vector3(side * 0.004, -0.13, 0.0), Vector3(0.022, 0.16, 0.09))
	for z: float in [0.16, 0.48]:
		_plate(CANVAS, at + Vector3(side * 0.012, -0.065, z), Vector3(0.01, 0.2, 0.03))


## A seat: a cushion of canvas on a frame of tube, and a back that leans.
func _seat(at: Vector3, wide: float) -> void:
	_block(CANVAS, at + Vector3(0, 0.05, 0), Vector3(wide, 0.1, 0.42), 0.035)
	_block(CANVAS, at + Vector3(0, 0.3, 0.25), Vector3(wide, 0.42, 0.07), 0.03, Vector3(10, 0, 0))
	for x: float in [-wide * 0.5, wide * 0.5]:
		_bar(ARMY, at + Vector3(x, -0.2, -0.18), at + Vector3(x, 0.0, -0.18), 0.012, 5)
		_bar(ARMY, at + Vector3(x, -0.2, 0.2), at + Vector3(x, 0.5, 0.29), 0.012, 5)


## A steering wheel on its column, the wheel at `at`.
## The wheel turns on its column, as a part of its own called "Steering",
## about its own Y.
func _steering(at: Vector3, radius: float) -> void:
	if _far:
		return
	var axis := Vector3(0, 0.62, 0.78)
	_bar(IRON, at - axis * 0.45, at, 0.016, 6)
	var frame := _up_along(axis)
	_on("Steering", Transform3D(frame, at))
	_hoop(IRON, at, axis, radius, 0.012)
	for spoke in 3:
		var turn := TAU * spoke / 3.0
		_bar(IRON, at, at + (frame.x * cos(turn) + frame.z * sin(turn)) * radius, 0.008, 4)
	_on("Body")


# --- The field car -------------------------------------------------------------------


## A quarter-ton field car: a flat bonnet between flat wings, a pressed
## grille with the lamps in it, a screen that folds, the body cut away where
## a door would be, the spare and a jerrycan on the back and its tools along
## the side.
func _jeep() -> void:
	model("jeep")
	_solid(Vector3(0, 0.78, 0.0), Vector3(1.48, 0.62, 3.5))
	_dye = Color(0.25, 0.5, 0.85, 0.0)
	var r := 0.37
	for x: float in [-0.63, 0.63]:
		for z: float in [-1.02, 1.01]:
			# The front wheels steer each on its own; the back two turn
			# together on their axle.
			var turns := ("WheelFL" if x < 0.0 else "WheelFR") if z < 0.0 else "AxleR"
			_on(turns, Transform3D(Basis(), Vector3(x, r, z) if z < 0.0 else Vector3(0, r, z)))
			_wheel(Vector3(x, r, z), r, 0.16, Vector3(signf(x), 0, 0))
			_touches(turns, Vector3(x, r, z), r, z < 0.0)
			_on("Body")
			# The spring the axle hangs in.
			_piece(IRON, Vector3(x * 0.72, 0.4, z), Vector3(0.05, 0.05, 0.9))
		_plate(IRON, Vector3(x * 0.58, 0.5, -0.05), Vector3(0.06, 0.1, 3.2))
	for z: float in [-1.02, 1.01]:
		_bar(IRON, Vector3(-0.56, r, z), Vector3(0.56, r, z), 0.04, 8)
		_bar(IRON, Vector3(0.14, r, z - 0.11), Vector3(0.14, r, z + 0.11), 0.11, 8)
	_bar(IRON, Vector3(0.14, 0.42, -0.9), Vector3(0.14, 0.42, 0.9), 0.025, 6)
	_block(IRON, Vector3(0.05, 0.45, -0.1), Vector3(0.3, 0.2, 0.5), 0.05)
	_piece(ARMY, Vector3(0, 0.5, -1.74), Vector3(1.42, 0.1, 0.055))
	for x: float in [-0.5, 0.5]:
		_piece(ARMY, Vector3(x, 0.5, 1.6), Vector3(0.16, 0.1, 0.07))

	# The body: a floor, two sides cut away at the doors and over the back
	# wheels, a panel behind, and the housings of those wheels inside.
	var side := PackedVector2Array([
		Vector2(-0.66, 0.56), Vector2(0.6, 0.56), Vector2(0.66, 0.7), Vector2(0.8, 0.8), Vector2(1.22, 0.8), Vector2(1.36, 0.7), Vector2(1.42, 0.56), Vector2(1.52, 0.56),
		Vector2(1.52, 1.02), Vector2(0.34, 1.02), Vector2(0.28, 0.92), Vector2(0.2, 0.8), Vector2(-0.3, 0.8), Vector2(-0.42, 0.9), Vector2(-0.46, 1.02), Vector2(-0.66, 1.02),
	])
	for x: float in [-0.71, 0.71]:
		slab(ARMY, Transform3D(SIDE, Vector3(x, 0, 0)), side, 0.03, 0.008, _part)
		_block(ARMY, Vector3(x * 0.8, 0.7, 1.01), Vector3(0.3, 0.26, 0.8), 0.03)
		# The rail round the top of the body, and a grip on its side.
		_bar(ARMY, Vector3(x * 1.01, 1.03, 0.34), Vector3(x * 1.01, 1.03, 1.52), 0.014, 6)
		_rail(ARMY, [Vector3(x * 1.02, 0.94, 0.4), Vector3(x * 1.07, 0.96, 0.43), Vector3(x * 1.07, 0.96, 0.57), Vector3(x * 1.02, 0.94, 0.6)], 0.008)
	_plate(ARMY, Vector3(0, 0.575, 0.48), Vector3(1.4, 0.03, 2.1))
	_piece(ARMY, Vector3(0, 0.79, 1.52), Vector3(1.44, 0.48, 0.03))
	# The scuttle with the dash under it, the bonnet, the wings and the
	# grille: nine slots, and a lamp in either corner of it.
	_block(ARMY, Vector3(0, 0.84, -0.6), Vector3(1.44, 0.5, 0.14), 0.03)
	_piece(ARMY, Vector3(0, 0.95, -0.5), Vector3(1.3, 0.2, 0.05), Vector3(-12, 0, 0))
	_block(ARMY, Vector3(0, 0.92, -1.15), Vector3(0.92, 0.34, 0.98), 0.07)
	_bar(ARMY, Vector3(0, 1.092, -1.62), Vector3(0, 1.092, -0.68), 0.008, 4)
	for x: float in [-1.0, 1.0]:
		_piece(ARMY, Vector3(x * 0.61, 0.84, -1.12), Vector3(0.3, 0.03, 0.98))
		_piece(ARMY, Vector3(x * 0.61, 0.74, -1.67), Vector3(0.3, 0.24, 0.03), Vector3(-28, 0, 0))
		_piece(ARMY, Vector3(x * 0.47, 0.72, -1.12), Vector3(0.025, 0.24, 0.96))
		_piece(ARMY, Vector3(x * 0.5, 0.85, -1.645), Vector3(0.05, 0.46, 0.03))
		_piece(ARMY, Vector3(x * 0.39, 0.74, -1.645), Vector3(0.18, 0.24, 0.03))
		_lamp(Vector3(x * 0.39, 0.965, -1.65), Vector3.FORWARD, 0.075)
		_lamp(Vector3(x * 0.6, 0.9, -1.56), Vector3.FORWARD, 0.03)
		# The catch that holds the bonnet down.
		_piece(IRON, Vector3(x * 0.47, 0.98, -1.3), Vector3(0.02, 0.07, 0.03))
	_plate(RUBBER, Vector3(0, 0.85, -1.62), Vector3(0.98, 0.42, 0.02))
	_piece(ARMY, Vector3(0, 0.63, -1.645), Vector3(1.04, 0.06, 0.03))
	_piece(ARMY, Vector3(0, 1.07, -1.645), Vector3(1.04, 0.05, 0.03))
	for i in 10:
		_piece(ARMY, Vector3((i - 4.5) * 0.058, 0.85, -1.65), Vector3(0.026, 0.4, 0.022))

	# The screen: a frame with two panes, standing, a wiper and a mirror.
	var lean := Vector3(-8, 0, 0)
	_piece(ARMY, Vector3(0, 1.57, -0.6), Vector3(1.4, 0.035, 0.035), lean)
	_piece(ARMY, Vector3(0, 1.13, -0.54), Vector3(1.4, 0.05, 0.035), lean)
	for x: float in [-0.69, 0.0, 0.69]:
		_piece(ARMY, Vector3(x, 1.35, -0.57), Vector3(0.035, 0.44, 0.035), lean)
	_piece(PANE, Vector3(0, 1.35, -0.57), Vector3(1.36, 0.4, 0.008), lean)
	_bar(IRON, Vector3(-0.36, 1.54, -0.615), Vector3(-0.2, 1.3, -0.585), 0.005, 4)
	_plate(PANE, Vector3(-0.78, 1.34, -0.6), Vector3(0.1, 0.07, 0.008))
	_bar(IRON, Vector3(-0.7, 1.3, -0.57), Vector3(-0.78, 1.34, -0.6), 0.006, 4)

	# Where they sit, what they drive it with, and what hangs on the back.
	for x: float in [-0.36, 0.36]:
		_seat(Vector3(x, 0.8, -0.02), 0.44)
	# The driver on the left, behind the wheel; one beside him, two on the
	# bench behind. Nothing keeps a shot off any of them.
	# The eyes a little over the top of the screen, which would otherwise
	# cut the view in two.
	_sits("driver", Vector3(-0.36, 0.92, 0.02), Vector3(-0.36, 1.74, 0.02), Vector3(-1.45, 0.0, -0.1), true)
	_sits("passenger", Vector3(0.36, 0.92, 0.02), Vector3(0.36, 1.74, 0.02), Vector3(1.45, 0.0, -0.1), true)
	for x: float in [-0.3, 0.3]:
		_sits("passenger", Vector3(x, 0.95, 1.06), Vector3(x, 1.66, 1.05), Vector3(signf(x) * 1.45, 0.0, 1.1), true)
	_block(CANVAS, Vector3(0, 0.88, 1.02), Vector3(1.06, 0.1, 0.4), 0.035)
	_block(CANVAS, Vector3(0, 1.1, 1.38), Vector3(1.06, 0.36, 0.07), 0.03, Vector3(6, 0, 0))
	_steering(Vector3(-0.36, 1.15, -0.26), 0.19)
	for lever: Vector3 in [Vector3(0.02, 0.92, -0.3), Vector3(0.1, 0.84, -0.22), Vector3(0.16, 0.82, -0.2)]:
		_bar(IRON, Vector3(lever.x, 0.59, lever.z + 0.1), lever, 0.008, 4)
		_piece(IRON, lever, Vector3(0.03, 0.03, 0.03))
	_wheel(Vector3(0.32, 0.92, 1.61), r, 0.16, Vector3.BACK)
	_jerrycan(Vector3(-0.4, 0.62, 1.63), 0.0)
	_piece(IRON, Vector3(-0.4, 0.8, 1.72), Vector3(0.38, 0.03, 0.02))
	_plate(ARMY, Vector3(-0.4, 0.6, 1.63), Vector3(0.38, 0.03, 0.18))
	_pioneer_tools(Vector3(-0.735, 0.71, -0.34), -1.0)
	# The bows of the top, folded down round the back, with the top itself
	# rolled up on them.
	for lift: float in [1.06, 1.1]:
		_rail(ARMY, [Vector3(-0.73, lift, 0.45), Vector3(-0.73, lift, 1.5), Vector3(-0.6, lift, 1.6), Vector3(0.6, lift, 1.6), Vector3(0.73, lift, 1.5), Vector3(0.73, lift, 0.45)], 0.011)
	_dye = Color(0.15, 0.6, 0.75, 0.0)
	_bar(CANVAS, Vector3(-0.6, 1.17, 1.5), Vector3(0.6, 1.17, 1.5), 0.075, 8)
	_dye = Color(0.05, 0.85, 0.9, 0.0)
	for x: float in [-0.4, 0.4]:
		_bar(CANVAS, Vector3(x - 0.015, 1.17, 1.5), Vector3(x + 0.015, 1.17, 1.5), 0.08, 8)
	_dye = Color(0.25, 0.5, 0.85, 0.0)
	# The aerial of its set.
	_piece(IRON, Vector3(-0.74, 1.0, 1.42), Vector3(0.05, 0.1, 0.05))
	_bar(IRON, Vector3(-0.74, 1.05, 1.42), Vector3(-0.78, 2.9, 1.5), 0.005, 4)

	_stencil(STAR, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 1.092, -1.14)), Vector2(0.52, 0.52))
	_stencil(PLATE_5, Transform3D(Basis(Vector3.UP, PI), Vector3(0.39, 0.74, -1.662)), Vector2(0.11, 0.11))
	for x: float in [-1.0, 1.0]:
		_stencil_side(STAR, Vector3(x * 0.727, 0.915, 1.01), x, Vector2(0.18, 0.18))
		_stencil_side(TYRE_PRESSURE, Vector3(x * 0.727, 0.99, -0.56), x, Vector2(0.16, 0.04))


# --- The motorcycle with its sidecar -------------------------------------------------


## A heavy army motorcycle with a sidecar on its right, of the kind that went
## to war in 1940: a flat twin whose cylinders stand out either side under
## the tank, a sprung saddle and a pillion behind it, a girder of tubes out
## to the sidecar and its wheel, which drives as well, and the sidecar a
## boat of pressed steel with a seat, a spare wheel on its back and a mount
## for a gun on its nose. Three ride: the driver, one on the pillion and one
## in the sidecar, who has their own weapons and the mount to rest them on.
## Nothing keeps a shot off any of them.
func _motorcycle() -> void:
	model("motorcycle")
	_solid(Vector3(0, 0.62, -0.02), Vector3(0.62, 0.86, 2.15))
	_solid(Vector3(1.06, 0.62, -0.06), Vector3(0.7, 0.5, 1.72))
	_solid(Vector3(0.55, 0.4, 0.3), Vector3(0.5, 0.12, 0.6))
	_dye = Color(0.25, 0.5, 0.85, 0.0)
	var r := 0.33
	var front := Vector3(0, r, -0.76)
	var back := Vector3(0, r, 0.68)
	var side := Vector3(1.12, r, 0.5)
	# The wheels: the front one steers, the back one and the sidecar's drive.
	_on("WheelF", Transform3D(Basis(), front))
	_wheel(front, r, 0.11, Vector3.RIGHT, -1, true)
	_touches("WheelF", front, r, true, false)
	_on("WheelR", Transform3D(Basis(), back))
	_wheel(back, r, 0.11, Vector3.RIGHT, -1, true)
	_touches("WheelR", back, r, false)
	_on("WheelS", Transform3D(Basis(), side))
	_wheel(side, r, 0.11, Vector3.RIGHT, -1, true)
	_touches("WheelS", side, r, false)
	_on("Body")

	# The frame: two tubes from the head down round the engine to the back
	# wheel, and the stays of the back wheel.
	var head := Vector3(0, 0.95, -0.5)
	for x: float in [-0.07, 0.07]:
		_rail(IRON, [head + Vector3(x, 0, 0), Vector3(x, 0.78, -0.2), Vector3(x * 1.4, 0.72, 0.3), Vector3(x * 1.3, 0.55, 0.62), back + Vector3(x * 1.2, 0, 0)], 0.016)
		_rail(IRON, [head + Vector3(x, -0.08, 0.02), Vector3(x * 1.3, 0.35, -0.32), Vector3(x * 1.3, 0.24, 0.05), Vector3(x * 1.3, 0.26, 0.4), back + Vector3(x * 1.2, 0, 0)], 0.016)
	_bar(IRON, head + Vector3(0, -0.1, 0.0), head + Vector3(0, 0.08, 0.04), 0.035, 8)
	# The engine: a crankcase and, either side under the tank, a cylinder
	# with its fins and its head, and the gearbox behind.
	_block(IRON, Vector3(0, 0.38, -0.08), Vector3(0.26, 0.26, 0.42), 0.06)
	_block(ARMY, Vector3(0, 0.42, 0.2), Vector3(0.22, 0.22, 0.24), 0.04)
	for x: float in [-1.0, 1.0]:
		var from := Vector3(x * 0.12, 0.45, -0.16)
		var out := Vector3(x, 0.06, 0).normalized()
		var fins := PackedVector2Array([Vector2(0, 0)])
		for i in 7:
			fins.append(Vector2(0.06, i * 0.026))
			fins.append(Vector2(0.085, i * 0.026 + 0.004))
			fins.append(Vector2(0.085, i * 0.026 + 0.012))
			fins.append(Vector2(0.06, i * 0.026 + 0.016))
		fins.append(Vector2(0.075, 0.19))
		fins.append(Vector2(0.075, 0.25))
		fins.append(Vector2(0, 0.26))
		_turned(IRON, from, out, fins, 10)
		# The exhaust from the head, down and back to the silencer on the left.
		_rail(IRON, [from + out * 0.2 + Vector3(0, -0.04, 0.04), Vector3(x * 0.26, 0.28, -0.1), Vector3(-0.2, 0.26, 0.2)], 0.022)
	_bar(IRON, Vector3(-0.2, 0.28, 0.2), Vector3(-0.22, 0.34, 0.86), 0.045, 8)
	_bar(IRON, Vector3(-0.22, 0.34, 0.86), Vector3(-0.22, 0.35, 0.95), 0.02, 6)
	# The tank, with its pads for the knees, and the toolbox let into it.
	_block(ARMY, Vector3(0, 0.88, -0.2), Vector3(0.26, 0.2, 0.52), 0.07)
	_piece(ARMY, Vector3(0, 0.985, -0.2), Vector3(0.1, 0.01, 0.2))
	for x: float in [-0.135, 0.135]:
		_plate(RUBBER, Vector3(x, 0.82, -0.12), Vector3(0.01, 0.1, 0.16))
	# The saddle on its springs, and the pillion behind it.
	_block(CANVAS, Vector3(0, 0.88, 0.14), Vector3(0.24, 0.07, 0.3), 0.03)
	for x: float in [-0.08, 0.08]:
		_turned(IRON, Vector3(x, 0.74, 0.22), Vector3.UP, PackedVector2Array([Vector2(0.02, 0), Vector2(0.02, 0.1)]), 6)
	_block(CANVAS, Vector3(0, 0.84, 0.52), Vector3(0.22, 0.06, 0.24), 0.025)
	_rail(IRON, [Vector3(-0.12, 0.86, 0.38), Vector3(-0.14, 0.92, 0.42), Vector3(-0.14, 0.92, 0.5)], 0.012)
	# The mudguards over the two wheels of the motorcycle, and the stand
	# and the carrier at the back.
	var arc := PackedVector3Array()
	for i in 7:
		var a := lerpf(-0.3, 2.2, i / 6.0)
		arc.append(Vector3(0, r + sin(a) * (r + 0.07), back.z - cos(a) * (r + 0.07)))
	for i in arc.size() - 1:
		_piece(ARMY, (arc[i] + arc[i + 1]) * 0.5, Vector3(0.15, 0.012, arc[i].distance_to(arc[i + 1]) + 0.01), Vector3(rad_to_deg(atan2(arc[i + 1].y - arc[i].y, -(arc[i + 1].z - arc[i].z))), 0, 0))
	_piece(IRON, Vector3(0, 0.9, 0.86), Vector3(0.2, 0.02, 0.24))
	_lamp(Vector3(0, 0.66, 1.02), Vector3.BACK, 0.035)
	# The pedals, the footrests and the kick start.
	for x: float in [-1.0, 1.0]:
		_piece(RUBBER, Vector3(x * 0.24, 0.3, -0.02), Vector3(0.14, 0.03, 0.08))
		_piece(RUBBER, Vector3(x * 0.2, 0.42, 0.48), Vector3(0.1, 0.025, 0.06))
	_bar(IRON, Vector3(0.16, 0.42, 0.14), Vector3(0.24, 0.28, 0.3), 0.012, 4)

	# The fork, the handlebars and the lamp turn with the front wheel: a part
	# of their own, "Steering", that turns about the head.
	_on("Steering", Transform3D(Basis(), head))
	for x: float in [-0.085, 0.085]:
		_bar(ARMY, head + Vector3(x, 0.05, 0.0), front + Vector3(x, 0, 0), 0.022, 6)
	_piece(ARMY, head + Vector3(0, 0.02, -0.02), Vector3(0.22, 0.05, 0.08))
	var arc_front := PackedVector3Array()
	for i in 6:
		var a := lerpf(0.5, 2.6, i / 5.0)
		arc_front.append(Vector3(0, r + sin(a) * (r + 0.06), front.z + cos(a) * (r + 0.06)))
	for i in arc_front.size() - 1:
		_piece(ARMY, (arc_front[i] + arc_front[i + 1]) * 0.5, Vector3(0.14, 0.012, arc_front[i].distance_to(arc_front[i + 1]) + 0.01), Vector3(rad_to_deg(atan2(arc_front[i + 1].y - arc_front[i].y, -(arc_front[i + 1].z - arc_front[i].z))), 0, 0))
	_rail(IRON, [head + Vector3(-0.34, 0.16, 0.12), head + Vector3(-0.2, 0.12, 0.06), head + Vector3(0, 0.1, 0.02), head + Vector3(0.2, 0.12, 0.06), head + Vector3(0.34, 0.16, 0.12)], 0.013)
	for x: float in [-1.0, 1.0]:
		_bar(RUBBER, head + Vector3(x * 0.26, 0.15, 0.1), head + Vector3(x * 0.36, 0.165, 0.125), 0.02, 6)
		_bar(IRON, head + Vector3(x * 0.25, 0.155, 0.08), head + Vector3(x * 0.3, 0.13, -0.02), 0.006, 4)
	_lamp(head + Vector3(0, -0.02, -0.16), Vector3.FORWARD, 0.09)
	_on("Body")

	# The sidecar: the girder out to its wheel, its mudguard, and the boat.
	_rail(IRON, [Vector3(0.1, 0.32, -0.3), Vector3(0.8, 0.36, -0.3), Vector3(1.05, 0.4, -0.2)], 0.02)
	_rail(IRON, [Vector3(0.1, 0.34, 0.5), Vector3(0.8, 0.36, 0.5), side + Vector3(-0.08, 0, 0)], 0.02)
	_bar(IRON, Vector3(0.1, 0.72, 0.3), Vector3(0.8, 0.6, 0.35), 0.016, 5)
	var tub := Vector3(1.06, 0.5, -0.08)
	_block(ARMY, tub + Vector3(0, 0.1, 0.18), Vector3(0.6, 0.42, 1.04), 0.12)
	_block(ARMY, tub + Vector3(0, 0.1, -0.52), Vector3(0.5, 0.36, 0.44), 0.14, Vector3(-8, 0, 0))
	_block(ARMY, tub + Vector3(0, 0.06, -0.82), Vector3(0.32, 0.24, 0.3), 0.12, Vector3(-18, 0, 0))
	# The cockpit: a dark well with the seat and its back in it, and a rim.
	_piece(RUBBER, tub + Vector3(0, 0.31, 0.2), Vector3(0.46, 0.02, 0.62))
	_rail(IRON, [tub + Vector3(-0.24, 0.32, -0.1), tub + Vector3(-0.26, 0.32, 0.2), tub + Vector3(-0.24, 0.32, 0.52), tub + Vector3(0, 0.33, 0.56), tub + Vector3(0.24, 0.32, 0.52), tub + Vector3(0.26, 0.32, 0.2), tub + Vector3(0.24, 0.32, -0.1), tub + Vector3(0, 0.33, -0.14), tub + Vector3(-0.24, 0.32, -0.1)], 0.014)
	_block(CANVAS, tub + Vector3(0, 0.36, 0.42), Vector3(0.4, 0.3, 0.08), 0.03, Vector3(-12, 0, 0))
	# Its mudguard and the spare wheel on its back.
	var arc_side := PackedVector3Array()
	for i in 6:
		var a := lerpf(0.2, 2.4, i / 5.0)
		arc_side.append(Vector3(side.x, r + sin(a) * (r + 0.06), side.z - cos(a) * (r + 0.06)))
	for i in arc_side.size() - 1:
		_piece(ARMY, (arc_side[i] + arc_side[i + 1]) * 0.5 + Vector3(0.12, 0, 0), Vector3(0.15, 0.012, arc_side[i].distance_to(arc_side[i + 1]) + 0.01), Vector3(rad_to_deg(atan2(arc_side[i + 1].y - arc_side[i].y, -(arc_side[i + 1].z - arc_side[i].z))), 0, 0))
	_wheel(tub + Vector3(0, 0.18, 0.74), r, 0.11, Vector3.BACK, -1, true)
	# The mount on its nose, a pin a gun is laid in, and a grip for whoever
	# rides there.
	_bar(IRON, tub + Vector3(0, 0.3, -0.42), tub + Vector3(0, 0.52, -0.46), 0.018, 6)
	_piece(IRON, tub + Vector3(0, 0.54, -0.46), Vector3(0.06, 0.05, 0.12))
	_rail(IRON, [tub + Vector3(-0.2, 0.32, -0.08), tub + Vector3(-0.22, 0.42, -0.1), tub + Vector3(-0.24, 0.42, 0.06)], 0.012)

	# Where they sit. The driver astride the saddle, the eyes over the bars;
	# one on the pillion behind; one in the sidecar, low in its well. Each
	# gets off on their own side.
	_sits("driver", Vector3(0, 0.92, 0.12), Vector3(0, 1.66, 0.02), Vector3(-1.0, 0.0, 0.1), true)
	_sits("passenger", Vector3(1.06, 0.6, 0.08), Vector3(1.06, 1.26, -0.02), Vector3(1.85, 0.0, 0.1), true)
	_sits("passenger", Vector3(0, 0.88, 0.52), Vector3(0, 1.64, 0.48), Vector3(-1.0, 0.0, 0.62), true)

	_stencil_side(TACTICAL, tub + Vector3(0.302, 0.12, -0.2), 1.0, Vector2(0.16, 0.16))
	_stencil_side(NUMBER_14, tub + Vector3(0.302, 0.12, 0.3), 1.0, Vector2(0.14, 0.14))


# --- The lorry -----------------------------------------------------------------------


## A cargo lorry of two and a half tons: a bonnet behind a guard of bars,
## an open cab under a canvas top, and a bed with a tilt over its hoops,
## open at the back. Ten wheels, the rear eight two by two on two axles.
func _truck() -> void:
	model("truck")
	# The bonnet and the cab, and the bed, their lower edges cut away in
	# front of the front wheels and behind the back ones: up the face of a
	# dune the tyres meet the sand before the body does.
	_solid_round(_cut_box(Vector3(0, 1.5, -2.1), Vector3(2.2, 1.7, 2.5), Vector2(0.6, 0.65), -1.0))
	_solid_round(_cut_box(Vector3(0, 1.95, 1.55), Vector3(2.4, 2.5, 4.0), Vector2(0.6, 0.6), 1.0))
	_dye = Color(0.25, 0.5, 0.85, 0.0)
	var r := 0.5
	for x: float in [-1.0, 1.0]:
		var front := "WheelFL" if x < 0.0 else "WheelFR"
		_on(front, Transform3D(Basis(), Vector3(x * 0.94, r, -2.25)))
		_wheel(Vector3(x * 0.94, r, -2.25), r, 0.24, Vector3(x, 0, 0))
		_touches(front, Vector3(x * 0.94, r, -2.25), r, true)
		# The pairs at the back turn together on their axles.
		for z: float in [1.15, 2.3]:
			var axle := "AxleR1" if z < 2.0 else "AxleR2"
			_on(axle, Transform3D(Basis(), Vector3(0, r, z)))
			_wheel(Vector3(x * 1.0, r, z), r, 0.22, Vector3(x, 0, 0))
			_wheel(Vector3(x * 0.73, r, z), r, 0.22, Vector3(x, 0, 0), 0)
			_touches(axle, Vector3(x * 0.865, r, z), r, false)
		_on("Body")
		# The frame, the springs of the bogie, and a flap behind its wheels.
		_plate(IRON, Vector3(x * 0.42, 0.84, 0.1), Vector3(0.08, 0.2, 6.6))
		_piece(IRON, Vector3(x * 0.6, 0.62, 1.72), Vector3(0.09, 0.12, 1.5))
		_plate(RUBBER, Vector3(x * 0.87, 0.72, 2.92), Vector3(0.52, 0.56, 0.015))
		# Wings over the front wheels, a step under the door.
		_piece(ARMY, Vector3(x * 0.96, 1.16, -2.25), Vector3(0.52, 0.04, 0.9))
		_piece(ARMY, Vector3(x * 0.96, 1.02, -2.94), Vector3(0.52, 0.04, 0.62), Vector3(-30, 0, 0))
		_piece(ARMY, Vector3(x * 0.96, 0.98, -1.62), Vector3(0.52, 0.04, 0.52), Vector3(42, 0, 0))
		_piece(ARMY, Vector3(x * 1.05, 0.74, -1.02), Vector3(0.3, 0.035, 0.84))
		_lamp(Vector3(x * 0.74, 1.36, -3.12), Vector3.FORWARD, 0.1)
		_lamp(Vector3(x * 1.02, 1.3, -3.02), Vector3.FORWARD, 0.035)
	for z: float in [-2.25, 1.15, 2.3]:
		_bar(IRON, Vector3(-0.84, r, z), Vector3(0.84, r, z), 0.06, 8)
		_bar(IRON, Vector3(0.12 if z < 0.0 else 0.0, r, z - 0.18), Vector3(0.12 if z < 0.0 else 0.0, r, z + 0.18), 0.18, 8)
	_bar(IRON, Vector3(0.0, 0.62, -2.1), Vector3(0.0, 0.62, 2.3), 0.04, 6)
	_plate(IRON, Vector3(0, 0.72, 1.72), Vector3(1.3, 0.12, 0.12))
	_piece(ARMY, Vector3(0, 0.86, -3.4), Vector3(2.24, 0.2, 0.09))
	for x: float in [-0.6, 0.6]:
		_rail(IRON, [Vector3(x, 0.9, -3.44), Vector3(x, 0.95, -3.54), Vector3(x + 0.08, 0.9, -3.54), Vector3(x + 0.08, 0.84, -3.44)], 0.016)

	# The bonnet, with its louvres, behind the guard of the radiator.
	_block(ARMY, Vector3(0, 1.5, -2.52), Vector3(1.22, 0.74, 1.5), 0.13)
	_piece(ARMY, Vector3(0, 1.35, -3.24), Vector3(1.1, 0.86, 0.06))
	_plate(RUBBER, Vector3(0, 1.4, -3.275), Vector3(0.9, 0.66, 0.012))
	_bar(ARMY, Vector3(0, 1.875, -3.2), Vector3(0, 1.875, -1.8), 0.012, 4)
	for x: float in [-1.0, 1.0]:
		for i in 7:
			_plate(IRON, Vector3(x * 0.613, 1.5, -2.9 + i * 0.14), Vector3(0.008, 0.22, 0.035))
		_piece(IRON, Vector3(x * 0.62, 1.2, -2.4), Vector3(0.02, 0.07, 0.035))
	for i in 9:
		_piece(ARMY, Vector3((i - 4) * 0.21, 1.42, -3.32), Vector3(0.03, 0.9, 0.025))
	for y: float in [0.98, 1.4, 1.86]:
		_piece(ARMY, Vector3(0, y, -3.33), Vector3(1.76, 0.035, 0.03))
	_piece(ARMY, Vector3(0.7, 1.4, -3.34), Vector3(0.24, 0.24, 0.01))

	# The cab: steel to the waist with a door in it, a screen in two panes
	# that opens, a seat for three, and canvas over and behind them.
	_block(ARMY, Vector3(0, 1.44, -1.72), Vector3(2.0, 0.84, 0.1), 0.03)
	_piece(ARMY, Vector3(0, 1.44, -0.54), Vector3(2.0, 0.84, 0.05))
	_plate(ARMY, Vector3(0, 1.04, -1.13), Vector3(2.0, 0.04, 1.2))
	for x: float in [-1.0, 1.0]:
		_piece(ARMY, Vector3(x * 0.99, 1.44, -1.13), Vector3(0.04, 0.84, 1.16))
		_piece(ARMY, Vector3(x * 1.012, 1.46, -1.1), Vector3(0.012, 0.72, 0.86))
		_piece(IRON, Vector3(x * 1.025, 1.6, -0.76), Vector3(0.02, 0.03, 0.1))
		# Its half of the screen: a frame, and the pane in it.
		_piece(ARMY, Vector3(x * 0.98, 2.14, -1.76), Vector3(0.045, 0.6, 0.045), Vector3(-6, 0, 0))
		_piece(ARMY, Vector3(x * 0.04, 2.14, -1.76), Vector3(0.045, 0.6, 0.045), Vector3(-6, 0, 0))
		_piece(PANE, Vector3(x * 0.51, 2.14, -1.762), Vector3(0.9, 0.52, 0.012), Vector3(-6, 0, 0))
		_piece(PANE, Vector3(x * 1.2, 2.0, -1.74), Vector3(0.14, 0.2, 0.012))
		_bar(IRON, Vector3(x * 1.0, 1.9, -1.72), Vector3(x * 1.2, 2.0, -1.73), 0.008, 4)
	_piece(ARMY, Vector3(0, 2.43, -1.79), Vector3(2.0, 0.045, 0.045))
	_piece(ARMY, Vector3(0, 1.87, -1.73), Vector3(2.0, 0.045, 0.045))
	_block(CANVAS, Vector3(0, 1.3, -0.92), Vector3(1.8, 0.14, 0.5), 0.04)
	_block(CANVAS, Vector3(0, 1.62, -0.62), Vector3(1.8, 0.5, 0.09), 0.03, Vector3(6, 0, 0))
	_steering(Vector3(-0.52, 1.72, -1.24), 0.23)
	# The driver and one beside him in the cab, steel to their waists; two
	# on the bed under the tilt, who look out at the back.
	_sits("driver", Vector3(-0.52, 1.42, -0.88), Vector3(-0.52, 2.12, -0.95), Vector3(-1.75, 0.0, -1.1), true)
	_sits("passenger", Vector3(0.5, 1.42, -0.88), Vector3(0.5, 2.12, -0.95), Vector3(1.75, 0.0, -1.1), true)
	for x: float in [-0.55, 0.55]:
		_sits("passenger", Vector3(x, 1.32, 2.6), Vector3(x, 2.25, 2.7), Vector3(x, 0.0, 4.6), false)
	_dye = Color(0.12, 0.62, 0.9, 0.6)
	var top := _tool(CANVAS, _part, Vector3(0, 2.5, -1.1))
	for i in 4:
		var z0 := -1.82 + i * 0.335
		var z1 := z0 + 0.335
		var sag0 := 0.05 * sin(PI * i / 4.0)
		var sag1 := 0.05 * sin(PI * (i + 1) / 4.0)
		_quad(top, [Vector3(-1.02, 2.47 - sag0, z0), Vector3(-1.02, 2.47 - sag1, z1), Vector3(1.02, 2.47 - sag1, z1), Vector3(1.02, 2.47 - sag0, z0)],
			[Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP], [Vector2(-1.02, z0), Vector2(-1.02, z1), Vector2(1.02, z1), Vector2(1.02, z0)])
	_quad(top, [Vector3(-1.02, 1.86, -0.5), Vector3(1.02, 1.86, -0.5), Vector3(1.02, 2.47, -0.48), Vector3(-1.02, 2.47, -0.48)],
		[Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK], [Vector2(-1.02, 0), Vector2(1.02, 0), Vector2(1.02, -0.61), Vector2(-1.02, -0.61)])
	_quad(top, [Vector3(1.02, 2.3, -0.48), Vector3(1.02, 2.3, -1.8), Vector3(1.02, 2.47, -1.8), Vector3(1.02, 2.47, -0.48)],
		[Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT], [Vector2(0.48, 0), Vector2(1.8, 0), Vector2(1.8, -0.17), Vector2(0.48, -0.17)])
	_quad(top, [Vector3(-1.02, 2.3, -1.8), Vector3(-1.02, 2.3, -0.48), Vector3(-1.02, 2.47, -0.48), Vector3(-1.02, 2.47, -1.8)],
		[Vector3.LEFT, Vector3.LEFT, Vector3.LEFT, Vector3.LEFT], [Vector2(-1.8, 0), Vector2(-0.48, 0), Vector2(-0.48, -0.17), Vector2(-1.8, -0.17)])
	_dye = Color(0.25, 0.5, 0.85, 0.0)

	# Under and behind the cab: the tank with its straps, the spare, cans.
	_bar(ARMY, Vector3(-1.0, 0.95, -0.36), Vector3(-1.0, 0.95, 0.56), 0.25, 12)
	for z: float in [-0.18, 0.38]:
		_bar(IRON, Vector3(-1.0, 0.95, z - 0.02), Vector3(-1.0, 0.95, z + 0.02), 0.256, 12)
	_bar(IRON, Vector3(-1.06, 1.18, 0.1), Vector3(-1.1, 1.26, 0.1), 0.04, 6)
	_wheel(Vector3(0.98, 1.56, -0.12), r, 0.24, Vector3.RIGHT)
	_plate(IRON, Vector3(0.8, 1.56, -0.12), Vector3(0.06, 0.9, 0.08))
	_jerrycan(Vector3(1.05, 0.76, -1.0), 90.0)
	_jerrycan(Vector3(1.05, 0.76, -0.82), 90.0)

	# The bed: boards on bearers, a low steel side with its stakes, and the
	# tailboard hanging down.
	_plate(WOOD, Vector3(0, 1.26, 1.6), Vector3(2.3, 0.07, 3.86))
	for z: float in [-0.2, 0.7, 1.6, 2.5, 3.4]:
		_plate(ARMY, Vector3(0, 1.17, z), Vector3(2.3, 0.11, 0.07))
	for x: float in [-1.0, 1.0]:
		_piece(ARMY, Vector3(x * 1.15, 1.54, 1.6), Vector3(0.035, 0.5, 3.88))
		_piece(ARMY, Vector3(x * 1.17, 1.8, 1.6), Vector3(0.06, 0.04, 3.9))
		for i in 6:
			_piece(ARMY, Vector3(x * 1.175, 1.52, -0.2 + i * 0.72), Vector3(0.03, 0.54, 0.07))
		# The racks the tilt lies against, seen from behind.
		for y: float in [2.0, 2.25, 2.5]:
			_plate(WOOD, Vector3(x * 1.13, y, 1.6), Vector3(0.022, 0.1, 3.8))
		_lamp(Vector3(x * 0.98, 1.05, 3.5), Vector3.BACK, 0.04)
		_piece(ARMY, Vector3(x * 0.7, 0.9, 3.5), Vector3(0.2, 0.16, 0.1))
	_piece(ARMY, Vector3(0, 1.54, -0.33), Vector3(2.3, 0.5, 0.035))
	_piece(ARMY, Vector3(0, 1.04, 3.57), Vector3(2.28, 0.46, 0.035))
	for x: float in [-0.76, 0.0, 0.76]:
		_piece(ARMY, Vector3(x, 1.04, 3.592), Vector3(0.06, 0.46, 0.02))
	_piece(IRON, Vector3(0, 0.86, 3.5), Vector3(0.14, 0.14, 0.2))
	_hoop(IRON, Vector3(0, 0.86, 3.64), Vector3.UP, 0.05, 0.014)
	# What it carries is not the same for two lorries: the level loads it.
	_tilt()

	_stencil(STAR, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 1.872, -2.5)), Vector2(0.62, 0.62))
	_stencil(PLATE_12, Transform3D(Basis(Vector3.UP, PI), Vector3(0.7, 1.4, -3.347)), Vector2(0.2, 0.2))
	_stencil(TACTICAL, Transform3D(Basis(Vector3.UP, PI), Vector3(-0.84, 0.86, -3.447)), Vector2(0.17, 0.17))
	_stencil(TACTICAL, Transform3D(Basis(), Vector3(-0.38, 1.04, 3.605)), Vector2(0.2, 0.2))
	_stencil(TOP_SPEED, Transform3D(Basis(), Vector3(0.38, 1.04, 3.605)), Vector2(0.44, 0.11))
	_stencil_side(PETROL, Vector3(-1.013, 1.12, -0.74), -1.0, Vector2(0.3, 0.075))
	for x: float in [-1.0, 1.0]:
		_stencil_side(STAR, Vector3(x * 1.021, 1.46, -1.1), x, Vector2(0.42, 0.42))


## The tilt of the lorry: canvas drawn over five hoops and strapped down
## along the sides of the bed, hanging between one hoop and the next. Shut
## at the front, open at the back with its curtain rolled up under the last
## hoop.
func _tilt() -> void:
	# Half the hoop, from the hem up to the middle: across the lorry, up.
	var hoop: Array[Vector2] = [Vector2(1.2, 1.7), Vector2(1.2, 2.05), Vector2(1.195, 2.4), Vector2(1.15, 2.68), Vector2(1.0, 2.9), Vector2(0.72, 3.03), Vector2(0.36, 3.075), Vector2(0.0, 3.085)]
	var round: Array[Vector2] = []
	for i in hoop.size():
		round.append(hoop[i])
	for i in range(hoop.size() - 2, -1, -1):
		round.append(Vector2(-hoop[i].x, hoop[i].y))
	var front := -0.36
	var back := 3.56
	var steps := 16
	# From afar the canvas is taut: a span from hoop to hoop, and half the
	# corners round a hoop.
	var every := 4 if _far else 1
	var round_every := 2 if _far else 1
	var st := _tool(CANVAS, _part, Vector3(0, 2.4, 1.6))
	var spots: Array = []
	var tones: Array = []
	for step in steps + 1:
		var z := lerpf(front, back, float(step) / steps)
		var slack := pow(sin(PI * fposmod(step / 4.0, 1.0)), 2.0)
		var row: Array[Vector3] = []
		var tone: Array[Color] = []
		for i in round.size():
			# The flatter the canvas lies, the deeper it hangs.
			var flat := clampf(1.0 - absf(round[i].x) / 1.2, 0.0, 1.0)
			var hem := 0.02 * pow(sin(PI * fposmod(step / 2.0, 1.0)), 2.0) if i == 0 or i == round.size() - 1 else 0.0
			row.append(Vector3(round[i].x * (1.0 - 0.022 * slack * (1.0 - flat)), round[i].y - 0.06 * slack * flat * flat + hem, z))
			tone.append(Color(0.35 * clampf(1.0 - (round[i].y - 1.7) / 0.7, 0.0, 1.0), 0.5 + 0.14 * flat, 1.0 - 0.12 * slack * flat, 0.75))
		spots.append(row)
		tones.append(tone)
	# The vertex colours here are the cloth's own, corner by corner.
	_cloths.erase(st)
	for step in range(0, steps, every):
		for i in range(0, round.size() - 1, round_every):
			var a: Vector3 = spots[step][i]
			var b: Vector3 = spots[step][i + round_every]
			var c: Vector3 = spots[step + every][i + round_every]
			var d: Vector3 = spots[step + every][i]
			var out := (b - a).cross(d - a).normalized()
			_quad(st, [a, b, c, d], [out, out, out, out], [Vector2(a.z, i * 0.36), Vector2(b.z, (i + round_every) * 0.36), Vector2(c.z, (i + round_every) * 0.36), Vector2(d.z, i * 0.36)],
				[tones[step][i], tones[step][i + round_every], tones[step + every][i + round_every], tones[step + every][i]])
	# The front, shut: a fan from its middle to the hoop.
	var hub := Vector3(0, 2.35, front - 0.03)
	var faces := [Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD]
	for i in range(0, round.size() - 1, round_every):
		var a := Vector3(round[i].x, round[i].y, front)
		var b := Vector3(round[i + round_every].x, round[i + round_every].y, front)
		_tri(st, [hub, b, a], faces, [Vector2(0, 2.35), Vector2(b.x, b.y), Vector2(a.x, a.y)], [Color(0.1, 0.45, 0.85, 0.75), Color(0.1, 0.5, 1.0, 0.75), Color(0.1, 0.5, 1.0, 0.75)])
	_tri(st, [hub, Vector3(round[0].x, round[0].y, front), Vector3(-round[0].x, round[0].y, front)], faces,
		[Vector2(0, 2.35), Vector2(1.2, 1.7), Vector2(-1.2, 1.7)], [Color(0.1, 0.45, 0.85, 0.75), Color(0.3, 0.5, 1.0, 0.75), Color(0.3, 0.5, 1.0, 0.75)])
	_cloths[st] = true
	# The hoops, as far as they show under it, and the curtain of the back,
	# rolled up and strapped.
	for step in range(0, steps + 1, 8):
		var z := lerpf(front, back, float(step) / steps) + (0.03 if step == 0 else (-0.03 if step == steps else 0.0))
		for i in range(2, round.size() - 3):
			_bar(ARMY, Vector3(round[i].x * 0.985, round[i].y - 0.02, z), Vector3(round[i + 1].x * 0.985, round[i + 1].y - 0.02, z), 0.017, 4)
	_dye = Color(0.1, 0.55, 0.7, 0.0)
	_bar(CANVAS, Vector3(-0.95, 2.86, back - 0.04), Vector3(0.95, 2.86, back - 0.04), 0.08, 8)
	_dye = Color(0.05, 0.85, 0.9, 0.0)
	for x: float in [-0.6, 0.0, 0.6]:
		_bar(CANVAS, Vector3(x - 0.02, 2.86, back - 0.04), Vector3(x + 0.02, 2.86, back - 0.04), 0.086, 8)
	# The straps that hold its hem to the hooks of the bed.
	for side: float in [-1.0, 1.0]:
		for i in 6:
			_plate(CANVAS, Vector3(side * 1.205, 1.6, 0.1 + i * 0.6), Vector3(0.006, 0.3, 0.035))
	_dye = Color(0.25, 0.5, 0.85, 0.0)


# --- The tank ------------------------------------------------------------------------


## The track of one side of the tank: a link every hand's breadth along the
## way it runs, flat on the ground under the road wheels, up round the
## sprocket behind, hanging between the rollers that carry it back, and down
## round the idler in front. `x` is where it runs across the tank.
func _track(x: float) -> void:
	# The way it runs, seen from the side: towards the back, up.
	var run := PackedVector2Array([Vector2(-2.12, 0.045), Vector2(2.02, 0.045)])
	for i in 9:
		var turn := -PI / 3.0 + PI * 5.0 / 6.0 * i / 8.0
		run.append(Vector2(2.74, 0.64) + Vector2(cos(turn), sin(turn)) * 0.38)
	var rollers: Array[float] = [2.74, 1.85, 0.75, -0.4, -1.55, -2.82]
	for i in rollers.size() - 1:
		for step in range(1, 6 if i < rollers.size() - 2 else 5):
			var t := step / 5.0
			run.append(Vector2(lerpf(rollers[i], rollers[i + 1], t), 1.01 - 0.075 * sin(PI * t) * (0.6 if i == 0 or i == rollers.size() - 2 else 1.0)))
	for i in 9:
		var turn := PI * 0.5 + PI * 5.0 / 6.0 * i / 8.0
		run.append(Vector2(-2.82, 0.64) + Vector2(cos(turn), sin(turn)) * 0.36)
	run.append(run[0])
	if _far:
		# From afar it is a band: a plate for every third stretch of its run.
		var band := PackedVector2Array()
		for i in range(0, run.size() - 1, 3):
			band.append(run[i])
		band.append(run[0])
		for i in band.size() - 1:
			var length := band[i].distance_to(band[i + 1])
			var along := (band[i + 1] - band[i]) / length
			var middle := (band[i] + band[i + 1]) * 0.5
			super._box(IRON, _m * Transform3D(Basis(Vector3.RIGHT, Vector3(0, along.x, -along.y), Vector3(0, along.y, along.x)), Vector3(x, middle.y, middle.x)), Vector3(0.56, 0.045, length + 0.02), _part)
		return
	var pitch := 0.155
	var left := 0.0
	for i in run.size() - 1:
		var length := run[i].distance_to(run[i + 1])
		var along := (run[i + 1] - run[i]) / length
		while left < length:
			var at := run[i] + along * left
			# A link lies along the track.
			var frame := Transform3D(Basis(Vector3.RIGHT, Vector3(0, along.x, -along.y), Vector3(0, along.y, along.x)), Vector3(x, at.y, at.x))
			_box(IRON, _m * frame, Vector3(0.56, 0.03, pitch - 0.018), _part)
			# The cleat across it that bites the ground, and the horn in its
			# middle that runs between the halves of the road wheels.
			_box(IRON, _m * frame * Transform3D(Basis(), Vector3(0, -0.022, 0.02)), Vector3(0.53, 0.022, 0.032), _part)
			_box(IRON, _m * frame * Transform3D(Basis(), Vector3(0, 0.045, 0)), Vector3(0.045, 0.065, 0.075), _part)
			left += pitch
		left -= length


## A road wheel of the tank, its inner face at `from`, its outer side along
## `out`: two discs of pressed steel, each with a tyre of solid rubber, with
## the gap between them that the guide horns of the track run in, and the
## hub with its nuts on the outer one.
func _road_wheel(from: Vector3, out: Vector3) -> void:
	if _far:
		# From afar one band of rubber and the disc in it.
		_turned(RUBBER, from, out, PackedVector2Array([Vector2(0.27, 0.0), Vector2(0.345, 0.02), Vector2(0.345, 0.43), Vector2(0.27, 0.45)]), 8)
		_turned(ARMY, from, out, PackedVector2Array([Vector2(0.28, 0.44), Vector2(0.12, 0.48), Vector2(0, 0.55)]), 8)
		return
	for half: float in [0.0, 0.25]:
		_turned(RUBBER, from + out * half, out, PackedVector2Array([
			Vector2(0.285, 0.0), Vector2(0.34, 0.01), Vector2(0.345, 0.1), Vector2(0.34, 0.19), Vector2(0.285, 0.2),
		]), 20, true)
	_turned(IRON, from, out, PackedVector2Array([Vector2(0.27, 0.2), Vector2(0.27, 0.25)]), 16)
	_turned(ARMY, from, out, PackedVector2Array([
		Vector2(0.29, 0.44), Vector2(0.24, 0.41), Vector2(0.15, 0.43), Vector2(0.12, 0.48),
		Vector2(0.08, 0.53), Vector2(0, 0.55),
	]), 20)
	var frame := _up_along(out)
	for nut in 8:
		var turn := TAU * nut / 8.0
		_turned(IRON, from + (frame.x * cos(turn) + frame.z * sin(turn)) * 0.105 + out * 0.48, out, PackedVector2Array([Vector2(0.013, 0), Vector2(0.013, 0.022), Vector2(0, 0.026)]), 5)


## A medium tank: a hull with a sloped front between its tracks, bins on
## the guards over them and skirts hung before them, some of which it has
## lost; and a slab-sided turret with a long gun, turned `traverse_deg` to
## its right. Its number is its own, and the level paints it on.
func _tank(tank: String, traverse_deg: float) -> void:
	model(tank)
	# The hull, its belly between the tracks and its ends sloped as the
	# tracks rise to the idler and the sprocket: it rides up out of a pit
	# instead of digging its corners into the side of it.
	var hull := PackedVector3Array()
	for x: float in [-1.5, 1.5]:
		for corner: Vector2 in [Vector2(-2.2, 0.35), Vector2(2.1, 0.35), Vector2(-3.0, 0.85), Vector2(-3.0, 1.25), Vector2(-2.05, 1.55), Vector2(3.0, 0.8), Vector2(3.0, 1.25), Vector2(2.55, 1.55)]:
			hull.append(Vector3(x, corner.y, corner.x))
	_solid_round(hull)
	# The turret is in the way, the gun is not: it would dig into the face of
	# a dune ahead and hold the tank there, or knock against a gate as the
	# turret turns.
	_solid(Vector3(0, 2.0, 0.1), Vector3(2.0, 0.85, 3.0), "Turret")
	_dye = Color(0.3, 0.55, 0.8, 0.0)
	for side: float in [-1.0, 1.0]:
		var x := side * 1.22
		_track(x)
		# The road wheels on their arms, the idler in front, the sprocket
		# behind and the rollers the track comes back over. Each wheel turns
		# on its own; the track runs flat under the road wheels, a little
		# under their rims.
		var lr := "L" if side < 0.0 else "R"
		for i in 6:
			var z := -2.12 + i * 0.83
			_on("Road%s%d" % [lr, i], Transform3D(Basis(), Vector3(x, 0.43, z)))
			_road_wheel(Vector3(x - side * 0.2, 0.43, z), Vector3(side, 0, 0))
			_touches("Road%s%d" % [lr, i], Vector3(x, 0.43, z), 0.41, false)
		_on("Idler" + lr, Transform3D(Basis(), Vector3(x, 0.64, -2.82)))
		# The idler and the sprocket hang clear of flat ground, but the face
		# of a dune meets the track where it goes round them first.
		_touches("Idler" + lr, Vector3(x, 0.64, -2.82), 0.31, false, false)
		_touches("Sprocket" + lr, Vector3(x, 0.64, 2.74), 0.3, false, false)
		_turned(ARMY, Vector3(x - side * 0.22, 0.64, -2.82), Vector3(side, 0, 0), PackedVector2Array([Vector2(0.27, 0.0), Vector2(0.31, 0.03), Vector2(0.31, 0.18), Vector2(0.26, 0.21), Vector2(0.26, 0.25), Vector2(0.31, 0.28), Vector2(0.31, 0.43), Vector2(0.27, 0.46), Vector2(0.22, 0.4), Vector2(0.12, 0.42), Vector2(0.09, 0.5), Vector2(0, 0.5)]), 24)
		_on("Sprocket" + lr, Transform3D(Basis(), Vector3(x, 0.64, 2.74)))
		_turned(IRON, Vector3(x - side * 0.2, 0.64, 2.74), Vector3(side, 0, 0), PackedVector2Array([Vector2(0.27, 0.0), Vector2(0.3, 0.03), Vector2(0.3, 0.12), Vector2(0.2, 0.15), Vector2(0.2, 0.3), Vector2(0.3, 0.33), Vector2(0.3, 0.42), Vector2(0.18, 0.42), Vector2(0.14, 0.5), Vector2(0.08, 0.52), Vector2(0, 0.52)]), 24)
		for tooth in 13:
			var turn := TAU * tooth / 13.0
			for rim: float in [0.125, 0.335]:
				_box(IRON, _m * Transform3D(Basis(Vector3.RIGHT, turn), Vector3(x - side * (0.2 - rim), 0.64, 2.74)) * Transform3D(Basis(), Vector3(0, 0.31, 0)), Vector3(0.05, 0.08, 0.07), _part)
		_on("Body")
		for z: float in [1.85, 0.75, -0.4, -1.55]:
			_bar(IRON, Vector3(x - side * 0.15, 0.87, z), Vector3(x + side * 0.2, 0.87, z), 0.1, 10)
		# The guard over the track, bent down in front and behind.
		_piece(ARMY, Vector3(x, 1.14, -0.05), Vector3(0.6, 0.025, 5.3))
		_piece(ARMY, Vector3(x, 1.02, -2.9), Vector3(0.6, 0.025, 0.55), Vector3(-38, 0, 0))
		_piece(ARMY, Vector3(x, 0.98, 2.84), Vector3(0.6, 0.025, 0.6), Vector3(44, 0, 0))
		# Its skirts: three plates a side, of which one is gone.
		for plate in 3:
			if plate == (0 if side < 0.0 else 2):
				continue
			_piece(ARMY, Vector3(x + side * 0.3, 0.86, -1.72 + plate * 1.68), Vector3(0.022, 0.5, 1.64))
			for hook: float in [-0.6, 0.6]:
				_piece(ARMY, Vector3(x + side * 0.31, 1.1, -1.72 + plate * 1.68 + hook), Vector3(0.03, 0.08, 0.1))
		# The bins on the guards, each with its lid and its catches.
		for bin: Vector2 in [Vector2(-1.25, 1.2), Vector2(0.15, 1.3), Vector2(1.55, 1.1)]:
			_piece(ARMY, Vector3(x + side * 0.03, 1.31, bin.x), Vector3(0.46, 0.3, bin.y))
			_piece(ARMY, Vector3(x + side * 0.03, 1.465, bin.x), Vector3(0.48, 0.02, bin.y + 0.02))
			for catch: float in [-0.3, 0.3]:
				_piece(IRON, Vector3(x + side * 0.27, 1.42, bin.x + catch * bin.y), Vector3(0.015, 0.07, 0.04))
		_bar(IRON, Vector3(x, 1.26, 2.5), Vector3(x, 1.3, 3.05), 0.07, 8)
		_bar(IRON, Vector3(x, 1.3, 3.05), Vector3(x + side * 0.12, 1.3, 3.15), 0.075, 8)
		# A lamp behind its guard on the front plate, and a hook to tow by.
		_lamp(Vector3(side * 0.62, 1.36, -2.42), Vector3.FORWARD, 0.075, false)
		_rail(IRON, [Vector3(side * 0.5, 1.26, -2.55), Vector3(side * 0.5, 1.46, -2.5), Vector3(side * 0.74, 1.46, -2.5), Vector3(side * 0.74, 1.26, -2.55)], 0.008)
		_piece(IRON, Vector3(side * 0.7, 0.72, -2.94), Vector3(0.08, 0.16, 0.14))
		_piece(IRON, Vector3(side * 0.7, 0.72, 2.95), Vector3(0.08, 0.16, 0.14))

	# The hull between the tracks: a tub, and on it the box with its sloped
	# front plate. On that plate spare links, and a board against the mud.
	_plate(ARMY, Vector3(0, 0.6, 0), Vector3(1.9, 0.72, 5.5))
	_block(ARMY, Vector3(0, 0.66, -2.78), Vector3(1.9, 0.62, 0.3), 0.04, Vector3(32, 0, 0))
	extrude(ARMY, PackedVector2Array([Vector2(-2.95, 0.95), Vector2(2.92, 0.95), Vector2(2.92, 1.22), Vector2(2.55, 1.53), Vector2(-2.05, 1.53)]), 2.0, Transform3D(SIDE, Vector3.ZERO), _part)
	for i in 6:
		_piece(IRON, Vector3(-0.42 + i * 0.165, 1.3, -2.47), Vector3(0.145, 0.045, 0.5), Vector3(32.8, 0, 0))
	_piece(ARMY, Vector3(0, 1.1, -2.84), Vector3(1.9, 0.02, 0.2), Vector3(-50, 0, 0))
	# The driver's hatch and what he looks through, the engine's louvres,
	# and the cable it is towed by along its side.
	_turned(ARMY, Vector3(0.48, 1.53, -1.55), Vector3.UP, PackedVector2Array([Vector2(0.3, 0), Vector2(0.3, 0.04), Vector2(0.27, 0.06), Vector2(0, 0.06)]), 12)
	for x: float in [0.3, 0.66]:
		_piece(ARMY, Vector3(x, 1.58, -1.9), Vector3(0.16, 0.08, 0.1))
	for x: float in [-0.5, 0.5]:
		_plate(IRON, Vector3(x, 1.535, 1.75), Vector3(0.86, 0.012, 1.5))
		for i in 9:
			_piece(ARMY, Vector3(x, 1.555, 1.1 + i * 0.165), Vector3(0.86, 0.014, 0.1), Vector3(18, 0, 0))
		_piece(ARMY, Vector3(x * 1.9, 1.56, 1.75), Vector3(0.04, 0.05, 1.56))
	_piece(ARMY, Vector3(0, 1.56, 1.75), Vector3(0.06, 0.05, 1.56))
	_rail(IRON, [Vector3(-0.93, 1.56, -1.6), Vector3(-0.96, 1.56, -0.2), Vector3(-0.93, 1.56, 0.9), Vector3(-0.8, 1.57, 2.3)], 0.016)
	_hoop(IRON, Vector3(-0.93, 1.56, -1.68), Vector3.UP, 0.07, 0.016)
	# Behind: the box of the telephone, and cans in a rack.
	_piece(ARMY, Vector3(-0.55, 1.2, 2.96), Vector3(0.3, 0.26, 0.14))
	_jerrycan(Vector3(0.3, 1.0, 3.0), 0.0)
	_jerrycan(Vector3(0.68, 1.0, 3.0), 0.0)
	_plate(ARMY, Vector3(0.49, 0.99, 3.0), Vector3(0.8, 0.03, 0.2))
	_piece(IRON, Vector3(0.49, 1.25, 3.09), Vector3(0.8, 0.03, 0.015))

	# The turret, on its ring: a part that turns about its Y, and the gun a
	# part in it that lifts about its X.
	_bar(ARMY, Vector3(0, 1.5, -0.2), Vector3(0, 1.62, -0.2), 0.98, 20)
	_m = Transform3D(Basis(Vector3.UP, -deg_to_rad(traverse_deg)), Vector3(0, 0, -0.2))
	_on("Turret", Transform3D(Basis(), Vector3(0, 1.62, -0.2)))
	_block(ARMY, Vector3(0, 1.98, 0.25), Vector3(1.9, 0.74, 2.3), 0.2)
	_block(ARMY, Vector3(0, 1.96, -1.0), Vector3(1.46, 0.66, 0.84), 0.2)
	# The gun: its mantlet under a cover of canvas, the barrel with the
	# sleeve that draws its fumes off, and on the one that is laid up a bag
	# over its muzzle.
	_on("Gun", Transform3D(_m.basis, _m * Vector3(0, 1.965, -1.43)), "Turret")
	_dye = Color(0.3, 0.6, 0.85, 0.0)
	_block(CANVAS, Vector3(0, 1.96, -1.43), Vector3(1.0, 0.62, 0.36), 0.17)
	_turned(CANVAS, Vector3(0, 1.965, -1.52), Vector3.FORWARD, PackedVector2Array([Vector2(0.27, 0.0), Vector2(0.2, 0.16), Vector2(0.13, 0.3), Vector2(0.105, 0.42)]), 12, true)
	_bar(ARMY, Vector3(0, 1.965, -1.9), Vector3(0, 1.975, -3.2), 0.085, 12)
	_bar(ARMY, Vector3(0, 1.975, -3.2), Vector3(0, 1.98, -3.82), 0.118, 12)
	_bar(ARMY, Vector3(0, 1.98, -3.82), Vector3(0, 1.99, -5.0), 0.076, 12)
	if traverse_deg != 0.0:
		_dye = Color(0.45, 0.62, 0.85, 0.0)
		_turned(CANVAS, Vector3(0, 1.99, -4.86), Vector3.FORWARD, PackedVector2Array([Vector2(0.088, 0.0), Vector2(0.095, 0.05), Vector2(0.095, 0.3), Vector2(0.07, 0.38), Vector2(0, 0.39)]), 10, true)
	elif not _far:
		marker("Muzzle", _m * Transform3D(Basis(), Vector3(0, 1.99, -5.05)), "Gun")
	_dye = Color(0.3, 0.55, 0.8, 0.0)
	_bar(IRON, Vector3(0.3, 1.92, -1.5), Vector3(0.3, 1.92, -1.95), 0.022, 6)
	_on("Turret")
	# On its roof: the commander's cupola with its sights and its gun, the
	# loader's hatch, a lamp, two aerials.
	_turned(ARMY, Vector3(0.45, 2.34, 0.3), Vector3.UP, PackedVector2Array([Vector2(0.34, 0), Vector2(0.34, 0.15), Vector2(0.27, 0.21), Vector2(0, 0.21)]), 14)
	for sight in 6:
		var turn := TAU * (sight + 0.5) / 6.0
		_piece(ARMY, Vector3(0.45 + cos(turn) * 0.3, 2.52, 0.3 + sin(turn) * 0.3), Vector3(0.13, 0.07, 0.07), Vector3(0, -rad_to_deg(turn) + 90.0, 0))
	_bar(ARMY, Vector3(-0.45, 2.34, 0.25), Vector3(-0.45, 2.37, 0.25), 0.3, 12)
	_plate(IRON, Vector3(-0.45, 2.375, 0.25), Vector3(0.6, 0.004, 0.012))
	_bar(IRON, Vector3(0.45, 2.55, 0.3), Vector3(0.45, 2.7, 0.2), 0.03, 6)
	_bar(IRON, Vector3(0.45, 2.7, 0.5), Vector3(0.45, 2.73, -0.6), 0.022, 6)
	_piece(IRON, Vector3(0.45, 2.7, 0.3), Vector3(0.08, 0.1, 0.3))
	_piece(ARMY, Vector3(0.6, 2.62, 0.3), Vector3(0.14, 0.14, 0.2))
	_lamp(Vector3(-0.05, 2.5, -0.55), Vector3.FORWARD, 0.11, false)
	_bar(IRON, Vector3(-0.05, 2.34, -0.5), Vector3(-0.05, 2.42, -0.5), 0.02, 5)
	for x: float in [-0.7, 0.75]:
		_bar(IRON, Vector3(x, 2.34, 1.15), Vector3(x, 2.46, 1.15), 0.03, 6)
		_bar(IRON, Vector3(x, 2.46, 1.15), Vector3(x * 1.03, 4.7, 1.3), 0.006, 4)
	# On its sides: bins, the dischargers that lay its smoke, an eye to
	# lift it by. Behind: a basket with what the crew sleeps under.
	for x: float in [-1.0, 1.0]:
		for bin: Vector2 in [Vector2(-0.1, 0.62), Vector2(0.6, 0.62)]:
			_piece(ARMY, Vector3(x * 1.0, 1.98, bin.x), Vector3(0.16, 0.46, bin.y))
			_piece(IRON, Vector3(x * 1.085, 2.1, bin.x), Vector3(0.012, 0.06, 0.04))
		for i in 3:
			for j in 2:
				_bar(ARMY, Vector3(x * (0.82 + j * 0.1), 2.04 + i * 0.1, -0.82), Vector3(x * (0.9 + j * 0.1), 2.1 + i * 0.1, -1.1), 0.04, 6)
		_hoop(IRON, Vector3(x * 0.6, 2.35, 1.0), Vector3(x, 0, 0), 0.035, 0.01)
	for z: float in [1.42, 1.9]:
		_rail(IRON, [Vector3(-0.8, 1.72, 1.4), Vector3(-0.8, 1.72 if z < 1.5 else 2.1, z), Vector3(0.8, 1.72 if z < 1.5 else 2.1, z), Vector3(0.8, 1.72, 1.4)], 0.012)
	_plate(IRON, Vector3(0, 1.72, 1.66), Vector3(1.6, 0.012, 0.5))
	_dye = Color(0.25, 0.42, 0.75, 0.0)
	_bar(CANVAS, Vector3(-0.72, 1.87, 1.62), Vector3(0.72, 1.87, 1.62), 0.14, 8)
	_dye = Color(0.3, 0.62, 0.8, 0.0)
	_bar(CANVAS, Vector3(-0.6, 2.06, 1.58), Vector3(0.5, 2.06, 1.58), 0.09, 8)
	_dye = Color(0.05, 0.85, 0.9, 0.0)
	for x: float in [-0.4, 0.35]:
		_bar(CANVAS, Vector3(x - 0.02, 1.87, 1.62), Vector3(x + 0.02, 1.87, 1.62), 0.146, 8)
	for x: float in [-1.0, 1.0]:
		_stencil_side(STAR, Vector3(x * 1.083, 1.98, -0.1), x, Vector2(0.36, 0.36))
	_m = Transform3D()
	_on("Body")
	# Who drives it lays the gun as well, from inside the hull; the one in
	# the cupola stands with his top half out of it, and turns with the
	# turret.
	_sits("driver", Vector3(0.45, 0.95, -1.55), Vector3(-0.4, 2.2, -1.2), Vector3(2.4, 0.0, -1.2), false)
	_sits("passenger", Vector3(0.45, 1.75, 0.1), Vector3(0.45, 2.95, 0.15), Vector3(-2.4, 0.0, 0.4), true, true)
	_stencil(PLATE_50, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(57.2)) * Basis(Vector3.UP, PI), Vector3(-0.86, 1.292, -2.42)), Vector2(0.22, 0.22))
	_stencil(ARROW, Transform3D(Basis(), Vector3(-0.2, 1.3, 2.925)), Vector2(0.2, 0.2))
	_stencil(NO_STEP, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.5, 1.572, 1.0)), Vector2(0.36, 0.09))
