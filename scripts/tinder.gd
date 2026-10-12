extends Node3D
## A pile of pallets, which can burn. scripts/breakables.gd makes one when a
## level loads, where the level builder put a pile: at the middle of its
## underside, turned as the pile is.
##
## Its boards are part of the mesh of the level itself, lightmapped with the
## floor they stand on, and cannot be taken away or changed. So a pile that
## has caught fire burns for a while, with flames up its sides and a light,
## and then goes out and is burnt: soot lies on it and on the floor around it,
## and it cannot catch again. Its collider stays in the body of the level: it
## is as much in the way burnt as it was.
##
## Fire that is near enough heats it, at the host's word: see `warm()` and
## Blast.heat(). While it burns it is a patch in Blast's list, which burns
## whoever stands by it and lights what stands next to it.

## How high one pallet is, in metres.
const PALLET := 0.15
## Seconds of fire next to it before a pile burns: slats with air between
## them, which catch sooner than the boards of a crate and later than
## cardboard.
const CATCHES := 1.0
## Seconds a pile burns before it goes out: this, and so much more for every
## pallet in it. One pallet burns for ten seconds, a pile of fourteen for
## sixteen.
const BURNS := 10.0
const BURNS_EACH := 0.4
## How much of the heat it took without catching it loses again, in seconds
## of fire a second. It gets no hotter than twice what it takes to catch.
const COOLING := 0.5
## How far above the pile its flames light something, in metres.
const CROWN := 0.3

## The box around the pile, in metres, which stands on the origin of this.
var size := Vector3.ZERO
## How far from the origin of this the pile reaches sideways, in metres.
var girth := 0.0
var alight := false
## It has burnt out, and cannot catch again.
var burnt := false

## Seconds of fire it has taken without catching, and when it last took any,
## on the clock of the effects.
var _heat := 0.0
var _heated := 0.0
## Seconds it has left to burn.
var _left := 0.0
var _flames: Node3D
## Its patch in Blast's list, on the host.
var _patch := {}


func _ready() -> void:
	add_to_group(Blast.TINDER)
	set_physics_process(false)


## Becomes the pile whose box is `around` metres large.
func pile(around: Vector3) -> void:
	size = around
	girth = Vector2(around.x, around.z).length() * 0.5


## How many pallets lie on each other in it.
func pallets() -> int:
	return roundi(size.y / PALLET)


## How long it burns, in seconds.
func burns() -> float:
	return BURNS + BURNS_EACH * pallets()


## A fire has burnt near it for `seconds`: `fire` is its patch in Blast's
## list. Only the host is told so, and what catches does so at its word.
func warm(fire: Dictionary, seconds: float) -> void:
	if alight or burnt:
		return
	var rate: float = Blast.heat(fire, global_transform.affine_inverse(), AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size))
	if rate <= 0.0:
		return
	# What it took before has cooled since.
	var idle: float = Fx.time - _heated - seconds
	_heat = minf(maxf(_heat - maxf(idle, 0.0) * COOLING, 0.0) + rate * seconds, CATCHES * 2.0)
	_heated = Fx.time
	if _heat >= CATCHES and Blast.room():
		Net.show(self, &"_catch")


## Whether it is burnt, as a number: all there is to tell somebody who comes
## into the level later. A pile that burns at that moment is whole to them
## until it goes out. See net_snapshot() in game.gd.
func net_state() -> int:
	return int(burnt)


## Is burnt as it burnt out before whoever looks at it now was there.
func net_restore(state: int) -> void:
	if state and not burnt:
		burnt = true
		Fx.soot(global_transform, size)


## It burns from here on, until it has burnt out.
func _catch() -> void:
	if alight or burnt:
		return
	alight = true
	_left = burns()
	_flames = Fx.blaze(global_transform, size, _left)
	if not Net.is_guest():
		_patch = Blast.kindle(global_position, (size.x + size.z) * 0.25, size.y + CROWN, _left)
	set_physics_process(true)


## When it has burnt out is for the host to say.
func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0 and not Net.is_guest():
		Net.show(self, &"_burn_out")


## The fire is out and the pile is burnt: black, and of no use to a fire.
func _burn_out() -> void:
	if burnt:
		return
	alight = false
	burnt = true
	set_physics_process(false)
	if is_instance_valid(_flames):
		_flames.queue_free()
	if not _patch.is_empty():
		# It goes from Blast's list at the next step.
		_patch.left = 0.0
		_patch = {}
	Fx.soot(global_transform, size)
