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
## They burn as well. Fire that is near enough heats each of them, at the
## host's word (see `warm()` and Blast.heat()), and after a while that
## depends on what it is made of it catches: it goes black under flames that
## lick up its sides, and when it has burnt through it falls apart like one
## that was shot to pieces, its boards charred. What stood on it comes down
## and burns on. While any of it burns, the pile is a patch in Blast's list,
## which burns whoever stands by it and lights what stands next to it.
##
## The model of what broke stays in the level, hidden: it has a patch of
## lightmap, which the lightmap finds by the path of its node, as
## explosive.gd explains. The body stays where it is as well when nothing is
## left of it, since scripts/net.gd finds it by its path.

enum Kind { CRATE, CARTON }

## Per kind: the damage one takes before it breaks, which for a crate is five
## rifle rounds or a load of shot from close by, what a cubic metre of its
## pieces weighs in kg, what it is made of to the effects, the sound of it
## breaking and how loud that is in dB, and the sound of it landing on what
## is left under it. The levels are where these recordings were measured to
## sit between a shot landing on wood and a barrel going off. Then fire: the
## seconds of it next to one before it catches, which for cardboard is at
## once and for the boards of a crate long enough to see it coming, and the
## seconds it burns before it falls apart.
const TUNING := {
	Kind.CRATE: {"health": 110.0, "density": 400.0, "matter": "wood", "breaks": &"crate_break", "level": -4.0, "lands": &"crate_drop", "catches": 1.5, "burns": 6.0},
	Kind.CARTON: {"health": 30.0, "density": 90.0, "matter": "soft", "breaks": &"box_break", "level": -6.0, "lands": &"impact_soft", "catches": 0.25, "burns": 2.5},
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
## The most pieces there are in a level at any moment; the oldest make way.
const MAX_PIECES := 48
## How much quieter than breaking, in dB, landing on what is left is.
const LANDING := -2.0
const GRAVITY := 9.8
## What a burning crate or box goes to: the black of charred wood, which it
## is when this share of its time to burn is over. From then on its boards
## are black as well when it breaks.
const CHAR := Color(0.07, 0.065, 0.06)
const CHARRED := 0.6
## What glows in it as it goes black, and how brightly once it is.
const EMBERS := Color(1.0, 0.45, 0.12)
const GLOW := 0.3
## Speed in m/s the boards of one that has burnt through fall apart at: it
## gives way, it is not knocked over.
const COLLAPSE := Vector3(0.0, 0.6, 0.0)


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
	## Seconds of fire it has taken without catching, and when it last took
	## any, on the clock of the effects.
	var heat := 0.0
	var heated := 0.0
	## Whether it burns, and for how many seconds it has.
	var alight := false
	var burnt := 0.0
	## What its meshes are drawn with while it burns, which goes black: a
	## copy of its own of each of their materials.
	var charring: Array[BaseMaterial3D] = []


## Path of a model's scene -> the box around its meshes, in its own space.
static var _boxes := {}
## Path of a model's scene -> the pieces it flies apart in: {mesh, at, size}
## each, the middle of the piece and the size of the box around it in the
## space of the model.
static var _cut := {}
## Material of a model -> its copy that is drawn from both sides.
static var _opened := {}
## Material of a piece -> its copy that is charred.
static var _sooted := {}
static var _pieces: Array[RigidBody3D] = []
## What broke in the frame that is going on and has not flown apart yet: the
## pile, the member and the push of each. See _throw().
static var _due: Array[Array] = []

## How far from the origin of this body the pile reaches sideways, in metres.
var girth := 0.0

var _members: Array[Member] = []
var _colliders: Array[CollisionShape3D] = []
## For each collider: where it stands in the level, upright, on the height
## of the origin of this body; the flames on those of its members that burn,
## if any do; and its patch in Blast's list, on the host.
var _frames: Array[Transform3D] = []
var _flames: Array[Node3D] = []
var _patches: Array[Dictionary] = []
## What rehearse_burning() has put the look of burning on, [mesh, surface]
## each, and for how many frames more.
var _worn: Array[Array] = []
var _wearing := 0


func _ready() -> void:
	add_to_group("breakable")
	add_to_group(Blast.TINDER)
	set_process(false)
	set_physics_process(false)


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
	var beside := collider.global_position - global_position
	girth = maxf(girth, Vector2(beside.x, beside.z).length() + Vector2(size.x, size.z).length() * 0.5)
	_frames.append(Transform3D(collider.global_basis.orthonormalized(), global_position + Vector3(beside.x, 0.0, beside.z)))
	_flames.append(null)
	_patches.append({})


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


## A fire has burnt near it for `seconds`: `fire` is its patch in Blast's
## list. Every crate and box the fire reaches gets hot, and one that has been
## hot for long enough catches, if there may be one more fire: that is, if
## its own stack burns already or Blast.room() says so. Only the host is told
## of a fire, and what catches does so at its word.
func warm(fire: Dictionary, seconds: float) -> void:
	for i in _members.size():
		var member := _members[i]
		if member.gone or member.alight:
			continue
		var size: Vector3 = (_colliders[member.collider].shape as BoxShape3D).size
		var box := AABB(Vector3(-size.x * 0.5, member.foot - member.sunk, -size.z * 0.5), Vector3(size.x, member.height, size.z))
		var rate: float = Blast.heat(fire, _frames[member.collider].affine_inverse(), box)
		if rate <= 0.0:
			continue
		# What it took before has cooled since, and it gets no hotter than
		# twice what it takes to catch, however long it has to wait.
		var catches: float = TUNING[member.kind].catches
		var idle: float = Fx.time - member.heated - seconds
		member.heat = minf(maxf(member.heat - maxf(idle, 0.0) * Blast.COOLING, 0.0) + rate * seconds, catches * 2.0)
		member.heated = Fx.time
		if member.heat >= catches and (is_instance_valid(_flames[member.collider]) or Blast.room()):
			Net.show(self, &"_catch", [1 << i])


## What it is made of: the kind of the lowest thing in it.
func kind() -> Kind:
	return _members[0].kind


## How many of its crates and boxes burn.
func burning() -> int:
	return _members.filter(func(member: Member) -> bool: return member.alight and not member.gone).size()


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
		# Its pieces fly when the frame is over, with those of whatever else
		# broke in it.
		if _due.is_empty():
			_throw.call_deferred()
		_due.append([self, member, push])
		if _charred(member):
			Fx.crumble(middle, member.height)
		else:
			Fx.smash(middle, push, tuning.matter, member.height)
		_quench(member)
		# Several at once make the sound of one, as loud as the loudest.
		if loudest.is_empty() or tuning.level > loudest.tuning.level:
			loudest = {"tuning": tuning, "at": middle}
	if loudest.is_empty():
		return
	Sfx.play_at(loudest.tuning.breaks, loudest.at, loudest.tuning.level)
	_settle()
	# What burns of it burns on where it comes down, and no longer where
	# something has gone.
	for column in _colliders.size():
		_stoke(column)
	# What came to rest on the pile is asleep, and nothing wakes it when the
	# pile changes shape under it: it would hang in the air. Pieces, hulks
	# and whatever else lies about are all children of the scene.
	for body in get_tree().current_scene.get_children():
		if body is RigidBody3D:
			body.sleeping = false
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


## What has lost its footing falls, and is heard when it lands. The flames
## on what burns come down with it.
func _process(delta: float) -> void:
	var falling := false
	var moved := false
	var landed: Member = null
	for member in _members:
		if member.gone or member.sunk >= member.sink:
			continue
		member.speed += GRAVITY * delta
		member.sunk = minf(member.sunk + member.speed * delta, member.sink)
		member.model.global_position = member.rest + Vector3.DOWN * member.sunk
		moved = true
		if member.sunk < member.sink:
			falling = true
		else:
			member.speed = 0.0
			if landed == null:
				landed = member
	if landed:
		var tuning: Dictionary = TUNING[landed.kind]
		Sfx.play_at(tuning.lands, landed.model.global_position, tuning.level + LANDING)
	if moved:
		for column in _colliders.size():
			if is_instance_valid(_flames[column]):
				_stoke(column)
	set_process(falling)


## The members whose bits are set in `which` burn from here on. Each gets a
## copy of its own of what it is drawn with, to go black in, and the flames
## on its stack are made to reach it.
func _catch(which: int) -> void:
	var columns := {}
	for i in _members.size():
		var member := _members[i]
		if which & (1 << i) == 0 or member.gone or member.alight:
			continue
		member.alight = true
		for mesh: MeshInstance3D in member.model.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(surface) as BaseMaterial3D
				if material:
					var copy := _kindled(material)
					mesh.set_surface_override_material(surface, copy)
					member.charring.append(copy)
		columns[member.collider] = true
	for column: int in columns:
		_stoke(column)
	if not columns.is_empty():
		set_physics_process(true)


## What burns gets blacker, and when it has burnt through it falls apart:
## that at the host's word. It runs on the clock of the fires in Blast's
## list, for as long as anything of the pile burns.
func _physics_process(delta: float) -> void:
	var through := 0
	var alight := false
	for i in _members.size():
		var member := _members[i]
		if member.gone or not member.alight:
			continue
		var burns: float = TUNING[member.kind].burns
		member.burnt += delta
		var black := smoothstep(0.0, CHARRED, member.burnt / burns)
		var glow := GLOW * black * (0.8 + 0.2 * sin(Fx.time * 9.0 + i * 2.4))
		for material in member.charring:
			material.albedo_color = (material.get_meta(&"fresh") as Color).lerp(CHAR, black)
			material.emission_energy_multiplier = glow
		alight = true
		if member.burnt >= burns:
			through |= 1 << i
	set_physics_process(alight)
	if through and not Net.is_guest():
		Net.show(self, &"_break", [through, COLLAPSE])


## Fits the flames on one of the colliders, and its patch in Blast's list, to
## those of its members that burn, where they are drawn at this moment. With
## none of them burning the fire is out, and where the last of the stack has
## burnt away a burn mark is left.
func _stoke(column: int) -> void:
	var low := INF
	var high := -INF
	var left := 0.0
	var standing := false
	# How high the top of the highest member that does not burn is, and how
	# high the underside of the stack was when it was whole.
	var top := -INF
	var base := INF
	for member in _members:
		if member.collider != column:
			continue
		base = minf(base, member.foot - member.sink)
		if member.gone:
			continue
		standing = true
		if member.alight:
			low = minf(low, member.foot - member.sunk)
			high = maxf(high, member.foot - member.sunk + member.height)
			left = maxf(left, TUNING[member.kind].burns - member.burnt)
		else:
			top = maxf(top, member.foot - member.sunk + member.height)
	var size: Vector3 = (_colliders[column].shape as BoxShape3D).size
	if high < low:
		if is_instance_valid(_flames[column]):
			_flames[column].queue_free()
			if not standing:
				Fx.soot(_frames[column].translated(Vector3.UP * base), Vector3(size.x, 0.0, size.z))
		_flames[column] = null
		if not _patches[column].is_empty():
			# It goes from Blast's list at the next step.
			_patches[column].left = 0.0
			_patches[column] = {}
		return
	var at := _frames[column].translated(Vector3.UP * low)
	var box := Vector3(size.x, high - low, size.z)
	# Fx ends the flames on a clock of its own, which can be ahead of the one
	# a crate burns on: flames that are over are made anew for what catches
	# after that.
	if is_instance_valid(_flames[column]) and not Fx.feed(_flames[column], at, box, left, top > high):
		_flames[column].queue_free()
		_flames[column] = null
	if not is_instance_valid(_flames[column]):
		_flames[column] = Fx.blaze(at, box, left)
		if not Net.is_guest() and _patches[column].is_empty():
			_patches[column] = Blast.kindle(at.origin, (size.x + size.z) * 0.25, box.y + Blast.CROWN, left)
		Fx.feed(_flames[column], at, box, left, top > high)
	if not _patches[column].is_empty():
		_patches[column].at = at.origin
		_patches[column].tall = box.y + Blast.CROWN
		_patches[column].left = left


## A copy of a material for something that burns to go black in: what it
## was, to begin with, and able to glow where its wood is light.
static func _kindled(material: BaseMaterial3D) -> BaseMaterial3D:
	var copy: BaseMaterial3D = material.duplicate()
	copy.set_meta(&"fresh", material.albedo_color)
	copy.emission_enabled = true
	copy.emission = EMBERS
	copy.emission_energy_multiplier = 0.0
	copy.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	copy.emission_texture = material.albedo_texture
	return copy


## What a crate or a box of this pile looks like while it burns, as meshes
## of their own: for Fx.rehearse(), which draws them once before anything
## burns.
func burning_looks() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in _members[0].model.find_children("*", "MeshInstance3D", true, false):
		var looks := MeshInstance3D.new()
		looks.mesh = mesh.mesh
		looks.cast_shadow = mesh.cast_shadow
		looks.gi_mode = mesh.gi_mode
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as BaseMaterial3D
			if material:
				looks.set_surface_override_material(surface, _kindled(material))
		found.append(looks)
	return found


## Has its lowest crate or box wear the look of one that burns for as long
## as Fx.rehearse() draws. A mesh of its own, as burning_looks() gives, has
## no patch of lightmap, and the renderer draws a material on something that
## has one in another way, which it has to make ready for as well. It does
## not glow yet and is no blacker, so there is nothing to see of it.
func rehearse_burning() -> void:
	if not _worn.is_empty():
		return
	for mesh: MeshInstance3D in _members[0].model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as BaseMaterial3D
			if material and mesh.get_surface_override_material(surface) == null:
				mesh.set_surface_override_material(surface, _kindled(material))
				_worn.append([mesh, surface])
	if _worn.is_empty():
		return
	_wearing = Fx.REHEARSAL + 1
	get_tree().process_frame.connect(_wear)


## A frame of the rehearsal is over. After the last of them the crate is
## drawn with its own material again, unless it has caught or broken
## meanwhile and has seen to that itself.
func _wear() -> void:
	_wearing -= 1
	if _wearing > 0:
		return
	get_tree().process_frame.disconnect(_wear)
	if not _members[0].alight and not _members[0].gone:
		for pair in _worn:
			(pair[0] as MeshInstance3D).set_surface_override_material(pair[1], null)
	_worn.clear()


## One that breaks burns no longer, whatever it was drawn with.
func _quench(member: Member) -> void:
	member.alight = false
	if member.charring.is_empty():
		return
	member.charring.clear()
	for mesh: MeshInstance3D in member.model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(surface, null)


## The fire is put out before it has burnt anything through: what burnt is
## as it was, and can catch again. See Blast.douse().
func douse() -> void:
	var burnt := false
	for member in _members:
		member.heat = 0.0
		if member.alight and not member.gone:
			_quench(member)
			member.burnt = 0.0
			burnt = true
	if not burnt:
		return
	for column in _colliders.size():
		_stoke(column)
	set_physics_process(false)


## True if a member has burnt for long enough to be black.
func _charred(member: Member) -> bool:
	return member.burnt >= TUNING[member.kind].burns * CHARRED


## The member a shot that landed at `at` has hit: the one whose box that
## point is in or nearest to, where it is drawn at this moment. One that is
## still coming down is not yet where its collider is, so a hit where the
## crate under it has just gone is not a hit on it. None, -1, if the point is
## not within GRAZE of any.
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
		var low := global_position.y + member.foot - member.sunk
		var away := Vector3(maxf(absf(offset.x) - size.x * 0.5, 0.0), maxf(maxf(low - at.y, at.y - low - member.height), 0.0), maxf(absf(offset.z) - size.z * 0.5, 0.0))
		if away.length_squared() < nearest:
			nearest = away.length_squared()
			found = i
	return found


## Throws about the pieces of everything that broke in the frame that is
## over. That waits for the end of the frame because a blast breaks many
## crates in one, and only then is it known how many pieces each of them may
## leave: MAX_PIECES together, so every crate leaves fewer boards rather than
## some of them none. What lay about already makes way first, the oldest
## first, and is gone before the new ones are made, so that there are never
## more than that.
static func _throw() -> void:
	var due := _due.filter(func(broken: Array) -> bool: return is_instance_valid(broken[0]) and (broken[0] as Node).is_inside_tree())
	_due.clear()
	due.resize(mini(due.size(), MAX_PIECES))
	if due.is_empty():
		return
	@warning_ignore("integer_division")
	var most := MAX_PIECES / due.size()
	var coming := 0
	for broken: Array in due:
		coming += mini(pieces_of((broken[1] as Member).model).size(), most)
	_pieces = _pieces.filter(is_instance_valid)
	while _pieces.size() + coming > MAX_PIECES:
		_pieces.pop_front().free()
	for broken: Array in due:
		broken[0]._scatter(broken[1], broken[2], most)


## Throws the pieces of one member about from where it stood, `most` of them
## at most: if it has more, every so-manyth of them. They lie on the level
## and are in nobody's way, and go through what is left of the pile, which
## has already come down to where they are.
func _scatter(member: Member, push: Vector3, most: int) -> void:
	var placed := member.model.global_transform
	var scale := placed.basis.get_scale()
	var turn := placed.basis.orthonormalized()
	var middle := placed * box_of(member.model).get_center()
	var density: float = TUNING[member.kind].density
	var charred := _charred(member)
	var cuts := pieces_of(member.model)
	var count := mini(cuts.size(), most)
	for i in count:
		@warning_ignore("integer_division")
		var cut: Dictionary = cuts[i * cuts.size() / count]
		var piece := RigidBody3D.new()
		piece.collision_layer = 0
		piece.collision_mask = WORLD
		var shape := BoxShape3D.new()
		shape.size = ((cut.size as Vector3) * scale).max(Vector3.ONE * THIN)
		piece.mass = maxf(shape.size.x * shape.size.y * shape.size.z * density, 0.2)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		piece.add_child(collider)
		var looks := _looks(cut.mesh)
		if charred:
			_blacken(looks)
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


## What is drawn of a piece: lit by the probes wherever it ends up, as the
## hulk of a barrel is, and too small to cast a shadow worth its cost.
static func _looks(mesh: Mesh) -> MeshInstance3D:
	var looks := MeshInstance3D.new()
	looks.mesh = mesh
	looks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	looks.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	return looks


## A piece of every model that has been cut so far, one for each material it
## is made of, as it will lie about: for Fx.rehearse(), which draws them once
## before the first crate breaks.
static func first_pieces() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	var seen := {}
	for key: String in _cut:
		for cut: Dictionary in _cut[key]:
			var mesh: Mesh = cut.mesh
			var fresh := false
			for surface in mesh.get_surface_count():
				fresh = fresh or not seen.has(mesh.surface_get_material(surface))
				seen[mesh.surface_get_material(surface)] = true
			if fresh:
				found.append(_looks(mesh))
	return found


## The same pieces as they lie about when what they come from has burnt: for
## Fx.rehearse(), which draws them once before the first crate burns.
static func charred_pieces() -> Array[MeshInstance3D]:
	var found := first_pieces()
	for looks in found:
		_blacken(looks)
	return found


## Has a piece drawn charred: with a copy of each of its materials that is
## covered in soot, as explosive.gd makes one for the hulk of a barrel.
static func _blacken(looks: MeshInstance3D) -> void:
	for surface in looks.mesh.get_surface_count():
		var material := looks.mesh.surface_get_material(surface)
		if material == null:
			continue
		if not _sooted.has(material):
			var black := material.duplicate()
			if black is BaseMaterial3D:
				black.albedo_color = CHAR
				black.metallic = 0.0
				black.roughness = 1.0
			_sooted[material] = black
		looks.set_surface_override_material(surface, _sooted[material])


## How many pieces lie about at the moment. One that has been cleared away
## is no RigidBody3D any more, so what the list holds is looked at untyped.
static func pieces() -> int:
	_pieces = _pieces.filter(func(piece: Variant) -> bool: return is_instance_valid(piece) and not piece.is_queued_for_deletion())
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
