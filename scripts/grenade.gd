extends RigidBody3D
## A hand grenade on its way: it bounces, rolls and goes off when its fuse has
## burnt down, wherever it is by then. scripts/weapons.gd throws it.

const FUSE := 2.2
const RADIUS := 6.5
const DAMAGE := 160.0

## True for the copy another machine shows of a grenade its player threw:
## that one goes off where the thrower's own does, and this only disappears.
var echo := false
## Who threw it, as scripts/match.gd numbers those who play; 0 for nobody.
var thrower := 0

var _fuse := FUSE


func _ready() -> void:
	body_entered.connect(_on_bounce)
	add_to_group("hazard")


## What whoever stands near it has to fear: see Squad.threat().
func danger() -> Dictionary:
	return {"at": global_position, "radius": RADIUS, "left": _fuse}


func _physics_process(delta: float) -> void:
	_fuse -= delta
	if _fuse <= 0.0:
		# A little above the floor it lies on, so that the floor is not in the way.
		if not echo:
			Blast.explode(global_position + Vector3.UP * 0.12, RADIUS, DAMAGE, 1.0, self, thrower)
		queue_free()


func _on_bounce(_other: Node) -> void:
	# The harder it comes down, the louder; once it only rolls it is quiet.
	var speed := linear_velocity.length()
	if speed > 1.0:
		Sfx.play_at(&"bounce", global_position, clampf(remap(speed, 1.0, 10.0, -16.0, -2.0), -16.0, -2.0))
