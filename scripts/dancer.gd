extends Node3D
## Somebody of Unmuted dancing the TikTok Dance: their figure doing the dance
## of assets/animations/moves.res where they stand, and their ring light
## (scenes/models/ring_light.scn) set down in front of them, its light on
## them. The player of this machine gets one from scripts/dance.gd, a figure
## of somebody else from scripts/puppet.gd while what they do says DANCING.
##
## Everybody who dances is in `dancing`, by the side they dance for: the
## ICP (scripts/modes/icp.gd) is drawn to them as to stickers, and harder.

const MOVES: AnimationLibrary = preload("res://assets/animations/moves.res")
const LIGHT := "res://scenes/models/ring_light.scn"
## How far in front of the dancer the ring light stands, in metres.
const LIGHT_AHEAD := 1.7

## Who dances where, by the dancer: [where, the side].
static var dancing := {}
static var _library: AnimationLibrary

var side := -1
var _figure: Node3D
var _light: Node3D


## Dances as `character` (a scene of assets/characters/) for `side`, facing
## along -Z as an enemy does. False if the character has no skeleton.
func setup(character: PackedScene, for_side: int) -> bool:
	side = for_side
	_figure = character.instantiate() as Node3D
	var skeleton := _figure.find_child("GeneralSkeleton", true, false) as Skeleton3D
	if skeleton == null:
		var found := _figure.find_children("*", "Skeleton3D", true, false)
		skeleton = found[0] if found else null
	if skeleton == null:
		_figure.free()
		return false
	for player: Node in _figure.find_children("*", "AnimationPlayer", true, false):
		player.free()
	# A character looks along +Z, an enemy along -Z.
	_figure.rotation.y = PI
	add_child(_figure)
	for mesh: MeshInstance3D in _figure.find_children("*", "MeshInstance3D", true, false):
		mesh.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	var moves := AnimationPlayer.new()
	moves.add_animation_library(&"", library())
	_figure.add_child(moves)
	moves.root_node = moves.get_path_to(skeleton)
	moves.play(&"dance")
	# Not everybody in step.
	moves.seek(randf() * moves.current_animation_length, true)
	_light = (load(LIGHT) as PackedScene).instantiate()
	_light.position = Vector3(0, 0, -LIGHT_AHEAD)
	add_child(_light)
	return true


## The dance alone, looping.
static func library() -> AnimationLibrary:
	if _library == null:
		_library = AnimationLibrary.new()
		var dance: Animation = MOVES.get_animation(&"dance").duplicate()
		dance.loop_mode = Animation.LOOP_LINEAR
		_library.add_animation(&"dance", dance)
	return _library


func _enter_tree() -> void:
	dancing[self] = [global_position if is_inside_tree() else Vector3.ZERO, side]


## The ring light stands on the ground in front, whatever the ground does there.
func _ready() -> void:
	if _light == null:
		return
	var at := _light.global_position
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.2, at + Vector3.DOWN * 3.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		_light.global_position = hit.position


func _exit_tree() -> void:
	dancing.erase(self)


func _process(_delta: float) -> void:
	dancing[self] = [global_position, side]


## Every dance that is on: [where, the side], for the ICP.
static func dances() -> Array:
	return dancing.values().filter(func(line: Array) -> bool: return line[1] >= 0)
