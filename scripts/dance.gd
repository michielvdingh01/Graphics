extends Node
## The TikTok Dance of the player of this machine: with the ring light in hand
## (a weapon whose WeaponData.dances is set), holding fire sets it down and
## dances. The view goes to a camera behind and above, to one side, so that
## the player sees themselves dance with the light on them, and their figure
## does the dance (scripts/dancer.gd). They stand still. Letting go, or being
## hit, ends it: back in their own eyes with the ring light in hand. After a
## hit it takes letting go of fire before they can dance again.
##
## scripts/weapons.gd makes one and tells it every frame whether fire is held.

const DANCER := preload("res://scripts/dancer.gd")
## Where the camera is while dancing: how far back and up from the feet,
## and how far round to one side, in radians; and where it looks, how high.
const BACK := 3.6
const UP := 2.3
const ROUND := 0.6
const LOOK_AT := 1.1
## Whose figure the player has when the match says nothing: the first of
## Unmuted.
const OWN := "res://assets/characters/unmuted_01/unmuted_01.glb"

var player: CharacterBody3D
## True while dancing.
var on := false

var _camera: Camera3D
var _dancer: Node3D
var _spoilt := false


func _ready() -> void:
	player.damaged.connect(_on_damaged)


## Fire is held (`held`) or not, with the ring light in hand.
func hold(held: bool) -> void:
	if not held:
		_spoilt = false
	var wants: bool = held and not _spoilt and not player.dead and player.riding == null and player.is_on_floor()
	if wants and not on:
		_start()
	elif not wants and on:
		stop()


func _start() -> void:
	var character := _character()
	if character == null:
		return
	var dancer: Node3D = DANCER.new()
	if not dancer.setup(character, _side()):
		dancer.free()
		return
	_dancer = dancer
	player.add_child(_dancer)
	on = true
	player.dancing = true
	player.weapons.visible = false
	_camera = Camera3D.new()
	_camera.fov = player.camera.fov
	player.add_child(_camera)
	_place_camera()
	_camera.make_current()


## Back in the player's own eyes, with the ring light in hand.
func stop() -> void:
	if not on:
		return
	on = false
	player.dancing = false
	player.weapons.visible = true
	if is_instance_valid(_dancer):
		_dancer.queue_free()
	if is_instance_valid(_camera):
		_camera.queue_free()
	if not player.dead and player.riding == null:
		player.camera.make_current()


func _process(_delta: float) -> void:
	if on:
		_place_camera()


func _place_camera() -> void:
	var feet := player.global_position
	var away := (player.global_basis.z).rotated(Vector3.UP, ROUND)
	var head := feet + Vector3.UP * LOOK_AT
	var there := feet + away * BACK + Vector3.UP * UP
	# Not through a wall: in front of whatever is between.
	var query := PhysicsRayQueryParameters3D.create(head, there, 1, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		there = head + (hit.position - head) * 0.85
	_camera.global_position = there
	_camera.look_at(head, Vector3.UP)


func _on_damaged(_amount: float) -> void:
	if on:
		_spoilt = true
		stop()


## The figure of the player: as the match dresses them, else the first of
## Unmuted.
func _character() -> PackedScene:
	if Match.active and Match.me():
		var look: Variant = Match.mode.look(Match.me())
		if look is Dictionary and (look as Dictionary).has("character"):
			return look.character
	return load(OWN) if ResourceLoader.exists(OWN) else null


func _side() -> int:
	return Match.me().team if Match.active and Match.me() else -1
