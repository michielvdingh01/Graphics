extends StaticBody3D
## A window that can be shot out pane by pane: the glass that hangs together
## in one opening of a wall, in the leaf of a door or in the roof.
## scripts/breakables.gd makes one for each when a level loads, out of the
## panes the level builder put there.
##
## A pane stops nothing. A shot goes through it and it breaks, and a blast
## breaks every pane within its reach. The glass comes down in shards, the
## pane is gone from the picture, and jagged teeth of it stay along the
## glazing bars: the same teeth for the same pane every time, so that
## everybody who plays sees the same window.
##
## It is in nobody's way: its panes are on a layer of their own, which no
## shot, no look and no walker finds. Every shot that is fired asks
## afterwards which panes it went through, see Fx.tracer(), and a blast asks
## every window what is within its reach, see Blast.explode().
##
## All the glass of a zone is one mesh, which the windows of that zone share:
## see Glazing.

## What the level builder makes one pane of: a box of twelve triangles, each
## of its six sides with four points of its own.
const CORNERS := 36
const POINTS := 24
## What a point of the glass carries: the arrays of a surface that the mesh
## of the builder has, and no others.
const CARRIED: Array[int] = [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]
## The thickest a pane is, in metres. The builder makes them 8 and 12 mm.
const THICKEST := 0.03
## How far a point of a pane may lie from where the corner of its box is, in
## metres.
const EXACT := 0.001
## How far the collider of a pane reaches to either side of the glass, in
## metres. The leaf of a door is a collider too and thicker than its pane: a
## shot that stops on it has to have got to the glass.
const PAD := 0.03
## The most panes one window has. Which of them are gone is told to whoever
## comes into the level later as the bits of a whole number, and
## net_snapshot() in game.gd keeps 32 of those: an opening with more panes
## becomes more than one window.
const MOST := 31
## A pane of at least this many m² is one of a window; a smaller one sits in
## the leaf of a door. The sound of each breaking and how loud that is in dB:
## as much glass as a hall lamp has, and as much as a bulb, see TUNING in
## scripts/lamp.gd.
const LARGE := 0.25
const BREAKS := &"lamp_break"
const BREAKS_LEVEL := -3.0
const TINKLES := &"bulb_break"
const TINKLES_LEVEL := -6.0
## The teeth that stay along the edges of a pane a metre across: how wide
## one is at most and how far it reaches into the opening at most, in metres,
## and the share of the edge that is left bare. A smaller or a larger pane
## has teeth to match, of no less than SMALLEST and no more than LARGEST
## times that size, and none reaches the middle of its pane.
const TOOTH := 0.32
const DEEP := 0.3
const BARE := 0.35
const SMALLEST := 0.4
const LARGEST := 1.5
## The corners of a pane, going round it, from its middle.
const AROUND: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]


## The glass of one mesh of the level, which is every pane of a zone. The
## mesh the builder saved is shared and is never changed: the MeshInstance3D
## draws one of its own from the moment the level loads, and that is made
## anew whenever panes have gone, with the triangles of every pane that still
## stands and, as a surface of their own, the teeth of those that do not.
class Glazing:
	extends RefCounted

	var mesh := ArrayMesh.new()
	## What the panes are drawn with, and the teeth they leave.
	var material: Material
	var broken: Material
	## The surface of the panes as the builder made it, and the corners of
	## its triangles, CORNERS for each pane.
	var arrays: Array = []
	var corners := PackedInt32Array()
	## The teeth, three points for each: where they are, where in the film of
	## dirt on the panes, and how far from each of the two edges the tooth
	## broke along, in metres. And the way they face.
	var teeth := PackedVector3Array()
	var dirt := PackedVector2Array()
	var edges := PackedVector2Array()
	var facing := PackedVector3Array()
	## For each pane, 1 once it has gone.
	var gone := PackedByteArray()
	## True from the moment a pane goes until the mesh is made anew.
	var stale := false
	var _random := RandomNumberGenerator.new()


	## The pane with this number goes from the picture and leaves its teeth.
	## `frame` stands in the middle of it, in the space of the mesh, with its
	## X and Z along the sides, which are `size` metres. The mesh is made anew
	## when the frame is over: once, however many panes go in it.
	func lose(pane: int, frame: Transform3D, size: Vector2) -> void:
		if gone[pane]:
			return
		gone[pane] = 1
		_leave_teeth(pane, frame, size)
		if not stale:
			stale = true
			remake.call_deferred()


	## Makes the mesh out of what is left of the glass.
	func remake() -> void:
		stale = false
		var left := PackedInt32Array()
		# The panes that still stand, a run of them at a time.
		var from := 0
		for pane in gone.size() + 1:
			if pane == gone.size() or gone[pane]:
				if pane > from:
					left.append_array(corners.slice(from * CORNERS, pane * CORNERS))
				from = pane + 1
		mesh.clear_surfaces()
		if not left.is_empty():
			arrays[Mesh.ARRAY_INDEX] = left
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(0, material)
		if not teeth.is_empty():
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_of(teeth, facing, dirt, edges))
			mesh.surface_set_material(mesh.get_surface_count() - 1, broken)


	## Adds the teeth of a pane: triangles in the middle of its thickness
	## that stand on its edges and point into the opening, with stretches of
	## bare edge between them. The dirt on them is the dirt that was on the
	## pane there. What they look like follows from the number of the pane
	## alone.
	func _leave_teeth(pane: int, frame: Transform3D, size: Vector2) -> void:
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		# The side of the box that faces along the Y of the frame.
		var side := pane * POINTS
		for other in range(side, side + POINTS, 4):
			if normals[other].dot(frame.basis.y) > normals[side].dot(frame.basis.y):
				side = other
		# Where the film of dirt is in the middle of the pane, and how far it
		# runs for every metre along the X and the Z of the frame.
		var middle := Vector2.ZERO
		var along := Vector2.ZERO
		var up := Vector2.ZERO
		for point in range(side, side + 4):
			var offset := vertices[point] - frame.origin
			middle += uvs[point] / 4.0
			along += uvs[point] * signf(offset.dot(frame.basis.x)) / (2.0 * size.x)
			up += uvs[point] * signf(offset.dot(frame.basis.z)) / (2.0 * size.y)

		_random.seed = hash(Vector2i(pane, gone.size()))
		var reach := clampf(minf(size.x, size.y), SMALLEST, LARGEST)
		var first := teeth.size()
		for edge in 4:
			var from := AROUND[edge] * size * 0.5
			var to := AROUND[(edge + 1) % 4] * size * 0.5
			var length := from.distance_to(to)
			var way := (to - from) / length
			var inward := Vector2(-way.y, way.x)
			var done := 0.0
			while done < length - EXACT:
				var wide := minf(_random.randf_range(0.25, 1.0) * TOOTH * reach, length - done)
				var deep := minf(_random.randf_range(0.2, 1.0) * DEEP * reach, absf(inward.dot(size)) * 0.45)
				var lean := _random.randf_range(-0.3, 1.3)
				# The last one of all is there if no other is.
				if _random.randf() >= BARE or (teeth.size() == first and edge == 3 and done + wide >= length - EXACT):
					var foot := from + way * done
					var heel := foot + way * wide
					var tip := from + way * clampf(done + wide * lean, 0.0, length) + inward * deep
					# Twice what the tooth measures, which over the length of
					# an edge is how far the corner across from it is.
					var twice := wide * deep
					for corner: Array in [[foot, Vector2(0.0, twice / heel.distance_to(tip))], [heel, Vector2(twice / foot.distance_to(tip), 0.0)], [tip, Vector2.ZERO]]:
						var spot: Vector2 = corner[0]
						teeth.append(frame * Vector3(spot.x, 0.0, spot.y))
						dirt.append(middle + along * spot.x + up * spot.y)
						edges.append(corner[1])
						facing.append(normals[side])
				done += wide


	## The arrays of a surface of teeth.
	static func surface_of(points: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, distances: PackedVector2Array) -> Array:
		var surface := []
		surface.resize(Mesh.ARRAY_MAX)
		surface[Mesh.ARRAY_VERTEX] = points
		surface[Mesh.ARRAY_NORMAL] = normals
		surface[Mesh.ARRAY_TEX_UV] = uvs
		surface[Mesh.ARRAY_TEX_UV2] = distances
		return surface


## What the teeth of panes of `material` are drawn with: the same film of
## dirt, by shaders/glass_teeth.gdshader.
static func _broken_of(material: Material) -> ShaderMaterial:
	if not _broken.has(material):
		var teeth := ShaderMaterial.new()
		teeth.shader = preload("res://shaders/glass_teeth.gdshader")
		var glass := material as BaseMaterial3D
		if glass:
			teeth.set_shader_parameter(&"film", glass.albedo_texture)
			teeth.set_shader_parameter(&"film_scale", Vector2(glass.uv1_scale.x, glass.uv1_scale.y))
			teeth.set_shader_parameter(&"roughness", glass.roughness)
			teeth.set_shader_parameter(&"specular", glass.metallic_specular)
		_broken[material] = teeth
	return _broken[material]


## One tooth of every kind of glass that has been taken apart so far: for
## Fx.rehearse(), which draws them once before the first pane breaks.
static func first_teeth() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for material: Material in _broken:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, Glazing.surface_of(
			PackedVector3Array([Vector3.ZERO, Vector3.RIGHT * TOOTH, Vector3.UP * DEEP]),
			PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK]),
			PackedVector2Array([Vector2.ZERO, Vector2.RIGHT * TOOTH, Vector2.UP * DEEP]),
			PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])))
		mesh.surface_set_material(0, _broken[material])
		var tooth := MeshInstance3D.new()
		tooth.mesh = mesh
		tooth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tooth.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		found.append(tooth)
	return found


## Material of panes -> what the teeth they leave are drawn with.
static var _broken := {}
## The process frame in which a pane was last heard to break.
static var _heard := -1

var _glazing: Glazing
## The number each of its panes has in the glazing. Its shape owners are
## numbered as its panes are, from 0, and a pane that is gone is one whose
## shape is disabled.
var _panes := PackedInt32Array()
## The box around the middles of its panes, in its own space.
var _around := AABB()
## The shape of the pane it took on last, which the next is likely to share.
var _box: BoxShape3D


func _ready() -> void:
	add_to_group("window")


## Takes the glass of `instance` apart into windows: bodies on `layer` that
## are yet to be put in the tree, at the place of `instance`, in the order
## their first panes come in its mesh. Panes that touch are one window. From
## then on `instance` draws a mesh of its own, see Glazing. Returns nothing,
## and leaves `instance` as it is, if its mesh is not what the level builder
## makes of glass: one surface of triangles, and a thin box for every pane.
static func glaze(instance: MeshInstance3D, layer: int) -> Array[StaticBody3D]:
	var windows: Array[StaticBody3D] = []
	var saved := instance.mesh
	if saved == null or saved.get_surface_count() != 1 or saved.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
		return windows
	var arrays := saved.surface_get_arrays(0)
	for kind in Mesh.ARRAY_MAX:
		if (arrays[kind] != null) != CARRIED.has(kind):
			return windows
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	@warning_ignore("integer_division")
	var count := vertices.size() / POINTS
	if count == 0 or vertices.size() != count * POINTS or indices.size() != count * CORNERS:
		return windows

	var frames: Array[Transform3D] = []
	var sizes := PackedVector3Array()
	# Which window a pane is in: the pane it names, and so on until one names
	# itself. Panes that have a corner at the same place are in the same one.
	var group := PackedInt32Array()
	var places := {}
	for pane in count:
		var first := pane * POINTS
		var used := Array(indices.slice(pane * CORNERS, (pane + 1) * CORNERS))
		if used.min() != first or used.max() != first + POINTS - 1:
			return windows
		# The four points of each side of the box, added up: of the sides
		# that face right and left, up and down, and front and back.
		var sides: Array[Vector3] = []
		for side in range(first, first + POINTS, 4):
			sides.append(vertices[side] + vertices[side + 1] + vertices[side + 2] + vertices[side + 3])
		var centre := (sides[0] + sides[1]) / 8.0
		# From one side to the one across, eight times over.
		var spans: Array[Vector3] = [sides[0] - sides[1], sides[2] - sides[3], sides[4] - sides[5]]
		var thin := Vector3(spans[0].length_squared(), spans[1].length_squared(), spans[2].length_squared()).min_axis_index()
		# Its X and Z along the sides and its Y through the glass. A pane is
		# too thin for the points across it to say which way that is.
		var x := spans[(thin + 2) % 3].normalized()
		var z := spans[(thin + 1) % 3].normalized()
		var frame := Transform3D(Basis(x, z.cross(x), z), centre)
		var half := Vector3(spans[(thin + 2) % 3].dot(x), absf(spans[thin].dot(frame.basis.y)), spans[(thin + 1) % 3].dot(z)) / 8.0
		if half.y <= 0.0 or half.y * 2.0 > THICKEST or half.x * 2.0 <= THICKEST or half.z * 2.0 <= THICKEST or absf(x.dot(z)) > EXACT:
			return windows
		# The sides that face right and left have all eight corners.
		for corner in range(first, first + 8):
			if (((vertices[corner] - centre) * frame.basis).abs() - half).length_squared() > EXACT * EXACT:
				return windows
		frames.append(frame)
		sizes.append(half * 2.0)
		# The corners of the side that faces through the glass, the same way
		# for every pane in a wall: to the millimetre, as the builder saved
		# them, which is the same on every machine.
		var faces := spans[thin]
		var face := first + (thin * 2 + (0 if faces[faces.abs().max_axis_index()] > 0.0 else 1)) * 4
		group.append(pane)
		for corner in range(face, face + 4):
			var place := Vector3i((vertices[corner] * 1000.0).round())
			if places.has(place):
				var one := _first_of(group, places[place])
				var other := _first_of(group, pane)
				group[maxi(one, other)] = mini(one, other)
			else:
				places[place] = pane

	var glazing := Glazing.new()
	glazing.arrays = arrays
	glazing.corners = indices
	glazing.material = saved.surface_get_material(0)
	glazing.broken = _broken_of(glazing.material)
	glazing.gone.resize(count)
	glazing.remake()
	instance.mesh = glazing.mesh
	var found := {}
	for pane in count:
		var first := _first_of(group, pane)
		var window: StaticBody3D = found.get(first)
		if window == null or window.size() == MOST:
			window = new()
			window.collision_layer = layer
			window.collision_mask = 0
			window._glazing = glazing
			found[first] = window
			windows.append(window)
		window._glaze(pane, frames[pane], sizes[pane])
	return windows


## How many panes it was made of.
func size() -> int:
	return _panes.size()


## How many of them still stand.
func standing() -> int:
	var count := 0
	for pane in _panes.size():
		if not is_shape_owner_disabled(pane):
			count += 1
	return count


## The middle of one of its panes, in the level.
func middle(pane: int) -> Vector3:
	return global_transform * shape_owner_get_transform(pane).origin


## The way one of its panes faces, in the level: through the glass, either way.
func facing(pane: int) -> Vector3:
	return global_basis * shape_owner_get_transform(pane).basis.y


## The sides of one of its panes in metres: along the X and the Z of the
## frame that stands in the middle of it.
func measures(pane: int) -> Vector2:
	var box := (shape_owner_get_shape(pane, 0) as BoxShape3D).size
	return Vector2(box.x, box.z)


## A shot went through the pane that has the shape `shape`, the way of
## `along`. The pane breaks, if it was still there.
func shot(shape: int, along: Vector3) -> void:
	var pane := shape_find_owner(shape)
	if not is_shape_owner_disabled(pane):
		Net.show(self, &"_shatter", [1 << pane, along])


## A blast of `radius` metres goes off at `at`: it breaks every pane within
## its reach. A wall in between does not save the glass.
func blast(at: Vector3, radius: float) -> void:
	if not (global_transform * _around).grow(radius).has_point(at):
		return
	var broken := 0
	for pane in _panes.size():
		if not is_shape_owner_disabled(pane) and middle(pane).distance_to(at) < radius:
			broken |= 1 << pane
	if broken:
		Net.show(self, &"_blow_out", [broken, at, radius])


## Which panes are gone, as bits: all there is to tell somebody who comes
## into the level later. See net_snapshot() in game.gd.
func net_state() -> int:
	var state := 0
	for pane in _panes.size():
		if is_shape_owner_disabled(pane):
			state |= 1 << pane
	return state


## Becomes what net_state() said of it on the host, without a sound: the
## glass that broke before somebody was there to see it is simply gone.
func net_restore(state: int) -> void:
	for pane in _panes.size():
		if state & (1 << pane):
			_lose(pane)


## Takes on a pane: its number in the glazing, the frame in the middle of
## it, in the space of the mesh, and how large it is along the X, the Y and
## the Z of that frame. Its collider is the pane and a little to either side
## of it.
func _glaze(pane: int, frame: Transform3D, across: Vector3) -> void:
	var wanted := across + Vector3(0.0, PAD * 2.0, 0.0)
	if _box == null or not _box.size.is_equal_approx(wanted):
		_box = BoxShape3D.new()
		_box.size = wanted
	var shape := create_shape_owner(self)
	shape_owner_set_transform(shape, frame)
	shape_owner_add_shape(shape, _box)
	_around = _around.expand(frame.origin) if _panes.size() else AABB(frame.origin, Vector3.ZERO)
	_panes.append(pane)


## The panes whose bits are set in `which` break, and their glass leaves the
## way of `along`: what a shot through them does.
func _shatter(which: int, along: Vector3) -> void:
	for pane in _panes.size():
		if which & (1 << pane) and _lose(pane):
			_fall(pane, along, 0.0)


## The panes whose bits are set in `which` are blown out by a blast of
## `radius` metres at `from`: each of them away from it, and the nearer it is
## the harder.
func _blow_out(which: int, from: Vector3, radius: float) -> void:
	for pane in _panes.size():
		if which & (1 << pane) and _lose(pane):
			var offset := middle(pane) - from
			_fall(pane, offset, clampf(1.0 - (offset.length() - radius * Blast.CORE) / (radius * (1.0 - Blast.CORE)), 0.0, 1.0))


## A pane is gone from here on: nothing for a shot to go through, and
## nothing to see but its teeth. False if it was gone already.
func _lose(pane: int) -> bool:
	if is_shape_owner_disabled(pane):
		return false
	shape_owner_set_disabled(pane, true)
	_glazing.lose(_panes[pane], shape_owner_get_transform(pane), measures(pane))
	return true


## The glass of a pane that has just gone comes down, the way of `out` and
## as hard as `force` says: see Fx.pane(). Panes that break in the same
## frame make the sound of one.
func _fall(pane: int, out: Vector3, force: float) -> void:
	var across := measures(pane)
	var frame := global_transform * shape_owner_get_transform(pane)
	Fx.pane(frame, across, out, force)
	if _heard != Engine.get_process_frames():
		_heard = Engine.get_process_frames()
		var large := across.x * across.y >= LARGE
		Sfx.play_at(BREAKS if large else TINKLES, frame.origin, BREAKS_LEVEL if large else TINKLES_LEVEL)


## The pane that stands for the window that pane `index` is in.
static func _first_of(group: PackedInt32Array, index: int) -> int:
	while group[index] != index:
		index = group[index]
	return index
