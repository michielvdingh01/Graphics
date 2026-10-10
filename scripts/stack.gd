extends StaticBody3D
## A pile of things that can be shot to pieces one at a time: a stack of two
## or three wooden crates, a cardboard box, or several of those standing on
## each other. scripts/breakables.gd makes one when a level loads, around
## models the level builder put there, and moves their colliders into it out
## of the body of the level.
##
## Every crate or box in it has health of its own, and a shot hurts the one
## it lands on. One that breaks flies apart in boards, whatever stood on it
## comes down by its height, and the colliders are made to fit what is left.
## A blast hurts all of them at once.
##
## The model of what broke stays in the level, hidden: it has a patch of
## lightmap, which the lightmap finds by the path of its node, as
## explosive.gd explains. The body stays where it is as well when nothing is
## left of it, since scripts/net.gd finds it by its path.

enum Kind { CRATE, CARTON }

## Per kind: the damage one takes before it breaks, which for a crate is five
## rifle rounds or a load of shot from close by, what a cubic metre of its
## pieces weighs in kg, what it is made of to the effects, the sound of it
## breaking and how loud that is in dB, the sound of it landing on what is
## left under it, and the sound to play as long as there is no recording of
## either.
const TUNING := {
	Kind.CRATE: {"health": 110.0, "density": 400.0, "matter": "wood", "breaks": &"crate_break", "level": -1.0, "lands": &"crate_drop", "stand_in": &"impact_wood"},
	Kind.CARTON: {"health": 30.0, "density": 90.0, "matter": "soft", "breaks": &"box_break", "level": -5.0, "lands": &"impact_soft", "stand_in": &"impact_soft"},
}
const WORLD := 1
## How far outside a crate a hit may land and still be on it, in metres. One
## that lands where a crate has just gone hurts none of the others.
const GRAZE := 0.1
## Area in m² of the side of a model that one piece is cut from: a side of
## twice that makes two boards, and no side makes more than MOST_BOARDS.
const BOARD := 0.28
const MOST_BOARDS := 3
## The thinnest the box around a piece is, in metres.
const THIN := 0.03
## Speed in m/s the pieces are knocked along a shot at, and how many times
## the push of a blast they are thrown at.
const KNOCK := 3.0
const THROW := 2.4
## Seconds a piece lies about at most before it shrinks away, and how long
## that takes.
const PIECE_TIME := 6.0
const SHRINK_TIME := 0.6
## The most pieces that lie about in a level; the oldest make way.
const MAX_PIECES := 48
## How much quieter than breaking, in dB, landing on what is left is.
const LANDING := -4.0
const GRAVITY := 9.8


## One of the things in the pile.
class Member:
	var model: Node3D
	var kind := Kind.CRATE
	var health := 0.0
	var gone := false
	## Which of the colliders covers it, and which member it stands on: -1
	## for the floor.
	var collider := 0
	var under := -1
	## How high it is, and how high its underside is above the origin of the
	## body while the pile stands, both in metres.
	var height := 0.0
	var foot := 0.0
	## Where its model is in the level while the pile stands.
	var rest := Vector3.ZERO
	## How far it has to come down in all since what was under it went, how
	## far it has come and how fast it is falling.
	var sink := 0.0
	var sunk := 0.0
	var speed := 0.0


## Path of a model's scene -> the box around its meshes, in its own space.
static var _boxes := {}
## Path of a model's scene -> the pieces it flies apart in: {mesh, at, size}
## each, the middle of the piece and the size of the box around it in the
## space of the model.
static var _cut := {}
## Material of a model -> its copy that is drawn from both sides.
static var _opened := {}
static var _pieces: Array[RigidBody3D] = []

var _members: Array[Member] = []
var _colliders: Array[CollisionShape3D] = []


func _ready() -> void:
	add_to_group("breakable")
	set_process(false)


## Takes on a collider that is already a child of this body, with the models
## it stands for, from the lowest up. `on` is the collider of this body that
## they stand on, if they stand on one.
func cover(collider: CollisionShape3D, kind: Kind, models: Array[Node3D], on: CollisionShape3D = null) -> void:
	var size: Vector3 = (collider.shape as BoxShape3D).size
	var foot := collider.position.y - size.y * 0.5
	var under := -1
	if on:
		for i in _members.size():
			if _colliders[_members[i].collider] == on:
				under = i
	for model in models:
		var member := Member.new()
		member.model = model
		member.kind = kind
		member.health = TUNING[kind].health
		member.collider = _colliders.size()
		member.under = under
		member.height = box_of(model).size.y * model.global_basis.get_scale().y
		member.foot = foot
		member.rest = model.global_position
		foot += member.height
		under = _members.size()
		_members.append(member)
	_colliders.append(collider)


## How many crates or boxes it was made of.
func size() -> int:
	return _members.size()


## How many of them still stand.
func standing() -> int:
	return _members.filter(func(member: Member) -> bool: return not member.gone).size()


func take_damage(amount: float, at: Vector3, direction: Vector3) -> bool:
	var index := _member_at(at)
	if index < 0:
		return false
	_members[index].health -= amount
	if _members[index].health <= 0.0:
		Net.show(self, &"_break", [1 << index, direction.normalized() * KNOCK])
	return false


## A blast is not a bullet: it reaches every one of them.
func take_blast(amount: float, _at: Vector3, push: Vector3) -> void:
	var broken := 0
	for i in _members.size():
		if _members[i].gone:
			continue
		_members[i].health -= amount
		if _members[i].health <= 0.0:
			broken |= 1 << i
	if broken:
		Net.show(self, &"_break", [broken, push * THROW])


## Which members are gone, as bits: all there is to tell somebody who comes
## into the level later. See net_snapshot() in game.gd.
func net_state() -> int:
	var state := 0
	for i in _members.size():
		if _members[i].gone:
			state |= 1 << i
	return state


## Becomes what net_state() said of it on the host, without a sound: what
## broke before somebody was there to see it is simply not there.
func net_restore(state: int) -> void:
	for i in _members.size():
		if state & (1 << i):
			_members[i].gone = true
			_members[i].model.visible = false
	_settle()
	for member in _members:
		member.sunk = member.sink
		member.speed = 0.0
		member.model.global_position = member.rest + Vector3.DOWN * member.sunk


## The members whose bits are set in `which` fly apart, their pieces thrown
## at `push` m/s, and what stood on them starts to fall.
func _break(which: int, push: Vector3) -> void:
	var loudest := {}
	for i in _members.size():
		var member := _members[i]
		if which & (1 << i) == 0 or member.gone:
			continue
		member.gone = true
		member.model.visible = false
		var tuning: Dictionary = TUNING[member.kind]
		var middle := member.model.global_transform * box_of(member.model).get_center()
		_scatter(member, push)
		Fx.smash(middle, push, tuning.matter, member.height)
		# Several at once make the sound of one, as loud as the loudest.
		if loudest.is_empty() or tuning.level > loudest.tuning.level:
			loudest = {"tuning": tuning, "at": middle}
	if loudest.is_empty():
		return
	_play(loudest.tuning.breaks, loudest.tuning.stand_in, loudest.at, loudest.tuning.level)
	_settle()
	set_process(true)


## Works out from what is gone how far every member has to come down, and
## fits the colliders to what is left: the pile is as it will stand at once,
## for whatever leans on it, while the models take a moment to fall.
func _settle() -> void:
	for member in _members:
		member.sink = 0.0
		var below := member.under
		while below >= 0:
			if _members[below].gone:
				member.sink += _members[below].height
			below = _members[below].under
	for i in _colliders.size():
		var bottom := INF
		var height := 0.0
		for member in _members:
			if member.collider == i and not member.gone:
				bottom = minf(bottom, member.foot - member.sink)
				height += member.height
		var collider := _colliders[i]
		var size: Vector3 = (collider.shape as BoxShape3D).size
		collider.disabled = height == 0.0
		if collider.disabled or (is_equal_approx(size.y, height) and is_equal_approx(collider.position.y, bottom + height * 0.5)):
			continue
		# The shape it had may be that of other stacks as well, so it gets one
		# of its own.
		var box := BoxShape3D.new()
		box.size = Vector3(size.x, height, size.z)
		collider.shape = box
		collider.position.y = bottom + height * 0.5
	if standing() == 0:
		collision_layer = 0


## What has lost its footing falls, and is heard when it lands.
func _process(delta: float) -> void:
	var falling := false
	var landed: Member = null
	for member in _members:
		if member.gone or member.sunk >= member.sink:
			continue
		member.speed += GRAVITY * delta
		member.sunk = minf(member.sunk + member.speed * delta, member.sink)
		member.model.global_position = member.rest + Vector3.DOWN * member.sunk
		if member.sunk < member.sink:
			falling = true
		else:
			member.speed = 0.0
			if landed == null:
				landed = member
	if landed:
		var tuning: Dictionary = TUNING[landed.kind]
		_play(tuning.lands, tuning.stand_in, landed.model.global_position, tuning.level + LANDING)
	set_process(falling)


## The member a shot that landed at `at` has hit: the one whose box, as it
## stands now, that point is in or nearest to. None, -1, if it is not within
## GRAZE of any.
func _member_at(at: Vector3) -> int:
	var found := -1
	var nearest := GRAZE * GRAZE
	for i in _members.size():
		var member := _members[i]
		if member.gone:
			continue
		var collider := _colliders[member.collider]
		var size: Vector3 = (collider.shape as BoxShape3D).size
		var offset := collider.global_transform.affine_inverse() * at
		var low := global_position.y + member.foot - member.sink
		var away := Vector3(maxf(absf(offset.x) - size.x * 0.5, 0.0), maxf(maxf(low - at.y, at.y - low - member.height), 0.0), maxf(absf(offset.z) - size.z * 0.5, 0.0))
		if away.length_squared() < nearest:
			nearest = away.length_squared()
			found = i
	return found


## Throws the pieces of one member about from where it stands. They lie on
## the level and are in nobody's way, and go through what is left of the
## pile, which has already come down to where they are.
func _scatter(member: Member, push: Vector3) -> void:
	var placed := member.model.global_transform
	var scale := placed.basis.get_scale()
	var turn := placed.basis.orthonormalized()
	var middle := placed * box_of(member.model).get_center()
	var density: float = TUNING[member.kind].density
	_pieces = _pieces.filter(is_instance_valid)
	for cut: Dictionary in pieces_of(member.model):
		var piece := RigidBody3D.new()
		piece.collision_layer = 0
		piece.collision_mask = WORLD
		var shape := BoxShape3D.new()
		shape.size = ((cut.size as Vector3) * scale).max(Vector3.ONE * THIN)
		piece.mass = maxf(shape.size.x * shape.size.y * shape.size.z * density, 0.2)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		piece.add_child(collider)
		# Lit by the probes wherever it ends up, as the hulk of a barrel is.
		var looks := MeshInstance3D.new()
		looks.mesh = cut.mesh
		looks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		looks.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		looks.transform = Transform3D(Basis.from_scale(scale), -(cut.at as Vector3) * scale)
		piece.add_child(looks)
		piece.add_collision_exception_with(self)
		get_tree().current_scene.add_child(piece)
		var at := placed * (cut.at as Vector3)
		piece.global_transform = Transform3D(turn, at)
		var out := (at - middle).normalized()
		piece.linear_velocity = push * randf_range(0.5, 1.2) + out * randf_range(0.6, 2.4) + Vector3.UP * randf_range(0.4, 2.2)
		piece.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
		var tween := piece.create_tween()
		tween.tween_interval(PIECE_TIME - 1.0 + randf())
		tween.tween_property(looks, "scale", scale * 0.01, SHRINK_TIME)
		tween.parallel().tween_property(looks, "position", looks.position * 0.01, SHRINK_TIME)
		tween.tween_callback(piece.queue_free)
		_pieces.append(piece)
	while _pieces.size() > MAX_PIECES:
		_pieces.pop_front().queue_free()


## Plays a sound where it happens, or its stand-in as long as there is no
## recording of it.
func _play(sound: StringName, stand_in: StringName, at: Vector3, db: float) -> void:
	Sfx.play_at(sound if Sfx.has(sound) else stand_in, at, db)


## How many pieces lie about at the moment.
static func pieces() -> int:
	_pieces = _pieces.filter(func(piece: RigidBody3D) -> bool: return is_instance_valid(piece) and not piece.is_queued_for_deletion())
	return _pieces.size()


## The box around the meshes of a model, in the space of the model.
static func box_of(model: Node3D) -> AABB:
	var key := model.scene_file_path
	if not _boxes.has(key):
		var boxes: Array[AABB] = []
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			boxes.append(_within(model, mesh) * mesh.get_aabb())
		_boxes[key] = boxes.reduce(func(sum: AABB, box: AABB) -> AABB: return sum.merge(box)) if boxes else AABB()
	return _boxes[key]


## The pieces a model flies apart in, cut the first time they are asked for:
## see _cut. Every triangle goes to the side of the box around the model that
## it lies nearest, and a large side is cut into boards along its length,
## straight through the triangles that lie across the cut. Between two sides
## nothing is cut, which leaves the boards with a jagged edge here and there,
## as wood that has splintered has.
static func pieces_of(model: Node3D) -> Array:
	var key := model.scene_file_path
	if _cut.has(key):
		return _cut[key]
	var box := box_of(model)
	var low := box.position
	var high := box.end
	# For each side of the box: the axis its boards are cut across, which is
	# the shorter one of the side, and how many boards it makes.
	var across := PackedInt32Array()
	var boards := PackedInt32Array()
	for side in 6:
		@warning_ignore("integer_division")
		var one := (side / 2 + 1) % 3
		@warning_ignore("integer_division")
		var other := (side / 2 + 2) % 3
		across.append(one if box.size[one] < box.size[other] else other)
		boards.append(clampi(roundi(box.size[one] * box.size[other] / BOARD), 1, MOST_BOARDS))
	# Piece -> material -> what goes into the surface of that material:
	# [vertices, normals, tangents, uvs, indices].
	var parts := {}
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var placed := _within(model, mesh)
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] else PackedFloat32Array()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] else PackedInt32Array(range(vertices.size()))
			# Per piece: the triangles that go to it whole, as their corners
			# in the surface three by three, and the parts of those that were
			# cut, each a polygon of loose corners.
			var whole := {}
			var cut := {}
			for corner in range(0, indices.size(), 3):
				var middle := placed * ((vertices[indices[corner]] + vertices[indices[corner + 1]] + vertices[indices[corner + 2]]) / 3.0)
				var side := 0
				var least := middle.x - low.x
				if high.x - middle.x < least:
					side = 1
					least = high.x - middle.x
				if middle.y - low.y < least:
					side = 2
					least = middle.y - low.y
				if high.y - middle.y < least:
					side = 3
					least = high.y - middle.y
				if middle.z - low.z < least:
					side = 4
					least = middle.z - low.z
				if high.z - middle.z < least:
					side = 5
				var first := 0
				var last := 0
				var axis := across[side]
				var width := box.size[axis] / boards[side]
				if boards[side] > 1:
					# The boards its three corners are in.
					first = boards[side]
					for i in 3:
						var board := clampi(int(((placed * vertices[indices[corner + i]])[axis] - low[axis]) / width), 0, boards[side] - 1)
						first = mini(first, board)
						last = maxi(last, board)
				if first == last:
					var piece := side * MOST_BOARDS + first
					if not whole.has(piece):
						whole[piece] = PackedInt32Array()
					var corners: PackedInt32Array = whole[piece]
					for i in 3:
						corners.append(indices[corner + i])
					whole[piece] = corners
					continue
				var triangle := []
				for i in 3:
					var index := indices[corner + i]
					var tangent := Vector4(tangents[index * 4], tangents[index * 4 + 1], tangents[index * 4 + 2], tangents[index * 4 + 3]) if not tangents.is_empty() else Vector4()
					triangle.append([placed * vertices[index], placed.basis * normals[index], tangent, uvs[index]])
				for board in range(first, last + 1):
					var from := low[axis] + width * board
					var part := _clipped(_clipped(triangle, axis, from, true), axis, from + width, false)
					if part.size() >= 3:
						var piece := side * MOST_BOARDS + board
						if not cut.has(piece):
							cut[piece] = []
						cut[piece].append(part)
			var material := mesh.mesh.surface_get_material(surface)
			var touched := whole.keys()
			for piece: int in cut:
				if not whole.has(piece):
					touched.append(piece)
			for piece: int in touched:
				if not parts.has(piece):
					parts[piece] = {}
				if not (parts[piece] as Dictionary).has(material):
					parts[piece][material] = [PackedVector3Array(), PackedVector3Array(), PackedFloat32Array(), PackedVector2Array(), PackedInt32Array()]
				var part: Array = parts[piece][material]
				var to_vertices: PackedVector3Array = part[0]
				var to_normals: PackedVector3Array = part[1]
				var to_tangents: PackedFloat32Array = part[2]
				var to_uvs: PackedVector2Array = part[3]
				var to_indices: PackedInt32Array = part[4]
				# Where each vertex of the surface ends up in the piece.
				var moved := PackedInt32Array()
				moved.resize(vertices.size())
				moved.fill(-1)
				for index: int in whole.get(piece, PackedInt32Array()):
					var to := moved[index]
					if to < 0:
						to = to_vertices.size()
						moved[index] = to
						to_vertices.append(placed * vertices[index])
						to_normals.append(placed.basis * normals[index])
						to_uvs.append(uvs[index])
						if not tangents.is_empty():
							var tangent := placed.basis * Vector3(tangents[index * 4], tangents[index * 4 + 1], tangents[index * 4 + 2])
							to_tangents.append(tangent.x)
							to_tangents.append(tangent.y)
							to_tangents.append(tangent.z)
							to_tangents.append(tangents[index * 4 + 3])
					to_indices.append(to)
				for polygon: Array in cut.get(piece, []):
					var base := to_vertices.size()
					for corner: Array in polygon:
						to_vertices.append(corner[0])
						to_normals.append(corner[1])
						to_uvs.append(corner[3])
						if not tangents.is_empty():
							var tangent: Vector4 = corner[2]
							var turned := placed.basis * Vector3(tangent.x, tangent.y, tangent.z)
							to_tangents.append(turned.x)
							to_tangents.append(turned.y)
							to_tangents.append(turned.z)
							to_tangents.append(tangent.w)
					for i in range(1, polygon.size() - 1):
						to_indices.append(base)
						to_indices.append(base + i)
						to_indices.append(base + i + 1)
				parts[piece][material] = [to_vertices, to_normals, to_tangents, to_uvs, to_indices]
	var pieces: Array[Dictionary] = []
	var order := parts.keys()
	order.sort()
	for piece: int in order:
		var mesh := ArrayMesh.new()
		for material: Material in parts[piece]:
			var part: Array = parts[piece][material]
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = part[0]
			arrays[Mesh.ARRAY_NORMAL] = part[1]
			if not (part[2] as PackedFloat32Array).is_empty():
				arrays[Mesh.ARRAY_TANGENT] = part[2]
			arrays[Mesh.ARRAY_TEX_UV] = part[3]
			arrays[Mesh.ARRAY_INDEX] = part[4]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, _open(material))
		var around := mesh.get_aabb()
		pieces.append({"mesh": mesh, "at": around.get_center(), "size": around.size})
	_cut[key] = pieces
	return pieces


## What is left of a polygon on one side of the plane where the coordinate
## `axis` is `at`: the side above it, or the one below. A corner is its
## place, its normal, its tangent and its uv, and a new corner on the plane
## gets what lies between those of the two it was cut between.
static func _clipped(polygon: Array, axis: int, at: float, above: bool) -> Array:
	var kept := []
	for i in polygon.size():
		var from: Array = polygon[i]
		var to: Array = polygon[(i + 1) % polygon.size()]
		var here: float = ((from[0] as Vector3)[axis] - at) * (1.0 if above else -1.0)
		var there: float = ((to[0] as Vector3)[axis] - at) * (1.0 if above else -1.0)
		if here >= 0.0:
			kept.append(from)
		if (here >= 0.0) != (there >= 0.0):
			var share := here / (here - there)
			kept.append([(from[0] as Vector3).lerp(to[0], share), (from[1] as Vector3).lerp(to[1], share), (from[2] as Vector4).lerp(to[2], share), (from[3] as Vector2).lerp(to[3], share)])
	return kept


## A material as it has to be for a piece: drawn from both sides, since a
## crate is hollow and a board of it has no back.
static func _open(material: Material) -> Material:
	var base := material as BaseMaterial3D
	if base == null or base.cull_mode == BaseMaterial3D.CULL_DISABLED:
		return material
	if not _opened.has(material):
		var open: BaseMaterial3D = base.duplicate()
		open.cull_mode = BaseMaterial3D.CULL_DISABLED
		_opened[material] = open
	return _opened[material]


## Where a mesh of a model is in the space of that model.
static func _within(model: Node3D, mesh: Node3D) -> Transform3D:
	var placed := Transform3D()
	var at := mesh
	while at != model:
		placed = at.transform * placed
		at = at.get_parent()
	return placed
