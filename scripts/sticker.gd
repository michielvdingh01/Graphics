extends Node3D
## A sticker from the Branding Gun or the slop gun on its way: it flies flat
## and spinning, in a low arc, and sticks where it lands. On the level it
## becomes one of scripts/stickers.gd, a decal that draws the ICP for a while;
## on somebody it hurts them and stays on them a few seconds; on the ICP
## himself it is gone at once. scripts/weapons.gd, scripts/bot.gd and
## scripts/puppet.gd fire it, as they fire a banana or a rocket.

## What a gun fires, by the name of its file in weapons/: the pictures it
## picks from at random (see scripts/stickers.gd), how wide they are, in
## metres, and the sound of one sticking.
const GUNS := {
	"branding_gun": {"pictures": ["unmuted"], "width": 0.55, "sticks": &"sticker_stick"},
	"slop_gun": {"pictures": ["ballerina", "tung", "bombardiro"], "width": 0.825, "sticks": &"slop_stick"},
}
const OTHER := "branding_gun"
## Seconds in the air before it falls away unseen.
const LIFE := 3.0
## How hard it falls, in m/s²: less than a stone, as a card sails.
const FALLS := 4.0
## Radians a second it spins about its face.
const SPIN := 14.0
## Seconds it stays on somebody it hit, and how big it is there next to on a
## wall: they would wear it like a bib.
const ON_BODY := 6.0
const BODY_SHARE := 0.6
const HIT_MASK := 0b100101  # world + enemy + breakable
const ARMORY := "res://scripts/armory.gd"

static var _quad: QuadMesh
static var _looks := {}

var velocity := Vector3.ZERO
## What a hit does.
var direct := 25.0
## True for the copy another machine shows: it flies and sticks the same but
## hurts nobody.
var echo := false
## Who fired it, as scripts/match.gd numbers those who play, and their body.
var thrower := 0
var shooter: CollisionObject3D
## The weapon it came from, as a place in scripts/armory.gd.
var weapon := -1
var passes := RID()

var _age := 0.0
var _picture := ""
var _width := 0.4
var _sticks := &"sticker_stick"
var _card: MeshInstance3D


func _ready() -> void:
	var gun: Dictionary = GUNS.get(_gun_name(), GUNS[OTHER])
	_picture = str((gun.pictures as Array).pick_random())
	_width = float(gun.width)
	_sticks = gun.sticks
	_card = card(_picture, _width)
	add_child(_card)
	_face()


## The name of the file in weapons/ of the gun that fired it.
func _gun_name() -> String:
	var data: WeaponData = load(ARMORY).at(weapon) if weapon >= 0 else null
	return data.resource_path.get_file().get_basename() if data else OTHER


## The picture `picture` on a card `width` wide, both sides, lying in its own X
## and Z as a decal does, its top towards -Z.
static func card(picture: String, width: float) -> MeshInstance3D:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.orientation = PlaneMesh.FACE_Y
	if not _looks.has(picture):
		var look := StandardMaterial3D.new()
		look.albedo_texture = load("res://scripts/stickers.gd").texture(picture)
		look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		look.alpha_scissor_threshold = 0.5
		look.cull_mode = BaseMaterial3D.CULL_DISABLED
		look.roughness = 0.42
		_looks[picture] = look
	var image: Texture2D = (_looks[picture] as StandardMaterial3D).albedo_texture
	var node := MeshInstance3D.new()
	node.mesh = _quad
	node.material_override = _looks[picture]
	node.scale = Vector3(width, 1.0, width * float(image.get_height()) / float(image.get_width()))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## What it is drawn with, for Fx.rehearse().
func looks() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for gun: Dictionary in GUNS.values():
		for picture: String in gun.pictures:
			found.append(card(picture, gun.width))
	return found


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	velocity += Vector3.DOWN * FALLS * delta
	var from := global_position
	var to := from + velocity * delta
	var skip: Array[RID] = []
	if shooter:
		skip.append(shooter.get_rid())
	if passes.is_valid():
		skip.append(passes)
	var mask := HIT_MASK | (Match.foes_of(shooter) if Match.active and shooter else 0)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, mask, skip))
	if hit:
		_land(hit)
		return
	global_position = to
	_face()
	_card.rotate_object_local(Vector3.UP, SPIN * delta)


## Flat to the way it flies, as a card thrown edge first sails.
func _face() -> void:
	var way := velocity.normalized()
	if way.length_squared() < 0.0001:
		return
	var side := way.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	var up := side.normalized().cross(way).normalized()
	# Lying in its X and Z with its face up: tilted a little towards whoever
	# looks after it, so that it is seen in the air and not only its edge.
	global_basis = Basis(side.normalized(), up, -way).rotated(side.normalized(), -0.5)


## Which side it was stuck for, -1 outside a match.
func _side() -> int:
	if not Match.active or shooter == null:
		return -1
	var who: RefCounted = Match.entrants.get(Match.number(shooter))
	return who.team if who else -1


func _land(hit: Dictionary) -> void:
	var struck: Object = hit.collider
	var way := velocity.normalized()
	var at: Vector3 = hit.position
	if struck is Node and (struck as Node).is_in_group(&"icp"):
		# The ICP wears nobody's sticker: it is gone as it touches him.
		Fx.strike(at, hit.normal, way, "soft", true)
		queue_free()
		return
	Sfx.play_at(_sticks, at)
	if not struck.has_method("take_damage"):
		load("res://scripts/stickers.gd").place(get_tree(), _picture, at, hit.normal, way, _width, _side())
		queue_free()
		return
	_wear(struck as Node3D, at, hit.normal)
	if echo:
		queue_free()
		return
	var killed: bool
	if Match.active:
		killed = Match.hit(shooter, struck, direct, at, way, weapon)
	else:
		killed = Net.damage(struck, direct, at, way)
	var weapons: Variant = shooter.get(&"weapons") if shooter else null
	if weapons and struck is CharacterBody3D:
		weapons.hit_confirmed.emit(false, killed)
	queue_free()


## A smaller copy of it stuck on `body` where it was hit, for ON_BODY seconds.
func _wear(body: Node3D, at: Vector3, normal: Vector3) -> void:
	var worn := card(_picture, _width * BODY_SHARE)
	body.add_child(worn)
	var flat := Vector3(normal.x, 0.0, normal.z)
	var out := flat.normalized() if flat.length_squared() > 0.0001 else -velocity.normalized()
	var frame := load("res://scripts/stickers.gd").frame(out, velocity) as Basis
	var size := worn.scale
	worn.global_transform = Transform3D(frame * Basis.from_scale(size), at + out * 0.03)
	# The timer goes with the sticker if the body goes first.
	var timer := Timer.new()
	timer.wait_time = ON_BODY
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(worn.queue_free)
	worn.add_child(timer)
