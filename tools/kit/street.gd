extends "res://tools/kit/field.gd"
## Eleventh drawer of the kit, see tools/kit.gd: the streets of a town of
## canals, by night. The paving of a street or a quay, the lanterns that
## light it, and what stands at the kerb: trees and parked cars. The water is
## in tools/kit/water.gd and the houses are in tools/kit/houses.gd, each a
## drawer of its own so that three can work on the town at once.
##
## The streets lie level, at height nought, as the floor of a room does. A
## level cuts such a town into zones as it does a building, one for each
## stretch of canal or street, and every piece is filed under the zone of
## the street it stands in or faces.
##
## What is in these three drawers is a greybox: every piece stands where it
## will stand and is as large as it will be, with the collider it will keep,
## and looks like nothing yet. A piece is dressed by rewriting what it draws
## and leaving alone what it is called, what it takes and what it collides
## with, so that a level laid out with the grey pieces is the same level
## when they are dressed. See "De grachten" in PLAN.md for the order that is
## done in.

## The lanterns of this town, by kind: how high the light hangs, how hard it
## shines and how far, and from how far off it still throws a shadow. Nothing
## of that has been tuned on a picture yet.
const LANTERNS := {
	"ritter": {"high": 3.5, "energy": 6.0, "reach": 16.0, "shadow": 45.0},
	"crown": {"high": 4.6, "energy": 7.5, "reach": 19.0, "shadow": 55.0},
	"wall": {"high": 3.2, "energy": 4.0, "reach": 11.0, "shadow": 35.0},
	"mast": {"high": 8.0, "energy": 14.0, "reach": 24.0, "shadow": 60.0},
}
## Sodium and candle are warm; the tall masts of a traffic street are whiter.
const LANTERN_WARM := Color(1.0, 0.72, 0.42)
const LANTERN_WHITE := Color(1.0, 0.86, 0.68)
## How far off a lantern is still a light at all, and over how many metres it
## goes out beyond that.
const LANTERN_SEEN := 110.0
const LANTERN_FADE := 30.0


## One face of a wall: a rectangle `size` wide and high, upright in the frame
## `xf` with its middle at the origin, looking along +Z. It has no back and
## no collider: nobody gets behind the front of a house, and a patch of
## lightmap for what is never seen is a patch wasted. A greybox house built
## as a box had seven times the lightmap its front needs.
func wall_face(mat: String, xf: Transform3D, size: Vector2, flags := 0) -> void:
	var st := _tool(mat, flags | NO_COLLIDE, xf.origin)
	var right := xf.basis.x
	var up := xf.basis.y
	var normal := xf.basis.z
	var points: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var point := xf.origin + right * corner.x * size.x * 0.5 + up * corner.y * size.y * 0.5
		points.append(point)
		# By where it lies in the town, so that brick runs on from house to house.
		uvs.append(Vector2(point.dot(right), -point.dot(up)))
	_quad(st, points, [normal, normal, normal, normal], uvs,
		[_edge(Vector2(0, 0), size), _edge(Vector2(1, 0), size), _edge(Vector2(1, 1), size), _edge(Vector2(0, 1), size)])


## The paving of a street or a quay over `area`, x and z, its top at height
## nought. Its top is all there is to see of it.
func street_paving(area: Rect2, mat := "floor") -> void:
	var middle := area.get_center()
	wall_face(mat, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(middle.x, 0, middle.y)), area.size)
	_collide_box(Transform3D(Basis(), Vector3(middle.x, -0.25, middle.y)), Vector3(area.size.x, 0.5, area.size.y), _surface(mat))


## A street lantern at `at`, lit. "ritter" is the lantern of the quays on its
## cast iron post, "crown" the taller one of the bridges, "mast" the lamp of
## a traffic street, and "wall" one on a bracket: `at` is then the spot on
## the wall under it, at the height of the street, and the wall faces
## `yaw_deg` (0 looks along +Z).
##
## The light is the game's to reckon, with a shadow for whoever walks by
## under it, and only what it throws back off the street is baked. From far
## off it throws no shadow, and from farther it is not a light at all: see
## LANTERNS.
func lantern(at: Vector3, kind := "ritter", yaw_deg := 0.0) -> void:
	var make: Dictionary = LANTERNS[kind]
	var high: float = make.high
	var small := DETAIL | NO_COLLIDE
	var head := at + Vector3(0, high, 0)
	match kind:
		"wall":
			var out := Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3.BACK
			head += out * 0.7
			rod("dark_steel", at + Vector3(0, high + 0.25, 0), head + Vector3(0, 0.25, 0), 0.025, small, 8)
		"mast":
			cylinder("galvanised", at, 0.11, high, small, Vector3.ZERO, 0.07, 10)
			_collide_cylinder(Transform3D(Basis(), at + Vector3(0, 1.2, 0)), 0.14, 2.4, "metal")
		_:
			cylinder("dark_steel", at, 0.16, 0.9, small, Vector3.ZERO, 0.1, 10)
			cylinder("dark_steel", at + Vector3(0, 0.9, 0), 0.07, high - 1.25, small, Vector3.ZERO, 0.05, 10)
			_collide_cylinder(Transform3D(Basis(), at + Vector3(0, 1.2, 0)), 0.16, 2.4, "metal")
	# The lantern itself: four panes that glow under a cap.
	var glass := 0.34 if kind == "crown" else 0.28
	box("emissive_warm", head, Vector3(glass, glass * 1.3, glass), Vector3.ZERO, small)
	box("dark_steel", head + Vector3(0, glass * 0.75, 0), Vector3(glass + 0.14, 0.08, glass + 0.14), Vector3.ZERO, small)
	if kind == "crown":
		cylinder("dark_steel", head + Vector3(0, glass * 0.8, 0), 0.12, 0.3, small, Vector3.ZERO, 0.03, 8)
	var light := OmniLight3D.new()
	light.name = "Lantern"
	light.position = head
	light.light_color = LANTERN_WHITE if kind == "mast" else LANTERN_WARM
	light.light_energy = make.energy
	light.light_volumetric_fog_energy = 1.4
	light.omni_range = make.reach
	light.omni_attenuation = 1.15
	light.shadow_enabled = true
	light.distance_fade_enabled = true
	light.distance_fade_begin = LANTERN_SEEN
	light.distance_fade_length = LANTERN_FADE
	light.distance_fade_shadow = make.shadow
	light.light_bake_mode = Light3D.BAKE_DYNAMIC
	light.set_meta(&"lantern", kind)
	_add(light, _group("Lights", head))


## Lanterns along the line from `from` to `to`, about `apart` from one to the
## next and none at either end.
func lanterns(from: Vector3, to: Vector3, apart := 22.0, kind := "ritter") -> void:
	var count := maxi(1, roundi(from.distance_to(to) / apart))
	for i in count:
		lantern(from.lerp(to, (i + 0.5) / count), kind)


## A tree at the kerb: an elm, as the canals have them. Nothing but its
## trunk yet.
func elm(at: Vector3) -> void:
	var girth := _prop_rng.randf_range(0.22, 0.34)
	cylinder("bark", at, girth, 6.5, NO_COLLIDE, Vector3.ZERO, girth * 0.7, 10)
	_collide_cylinder(Transform3D(Basis(), at + Vector3(0, 1.5, 0)), girth, 3.0, "wood")


## Elms along the line from `from` to `to`, about `apart` from one to the
## next, each a step out of line.
func elms(from: Vector3, to: Vector3, apart := 11.0) -> void:
	var count := maxi(1, roundi(from.distance_to(to) / apart))
	for i in count:
		elm(from.lerp(to, (i + 0.5) / count) + Vector3(_prop_rng.randf_range(-0.2, 0.2), 0, _prop_rng.randf_range(-0.2, 0.2)))


## A car parked at `at`, the middle of where it stands, its nose the way
## `yaw_deg` looks (0 looks along +Z). Something to crouch behind.
func parked_car(at: Vector3, yaw_deg: float) -> void:
	var frame := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	var long := _prop_rng.randf_range(3.9, 4.6)
	_local_box("machine_grey", frame, Vector3(0, 0.55, 0), Vector3(1.75, 0.75, long), NO_COLLIDE)
	_local_box("dark_steel", frame, Vector3(0, 1.15, -0.2), Vector3(1.55, 0.5, long * 0.5), NO_COLLIDE)
	_collide_box(frame * Transform3D(Basis(), Vector3(0, 0.7, 0)), Vector3(1.75, 1.4, long), "metal")


## Cars parked nose to tail along the line from `from` to `to`, with a gap
## now and then where one has driven off: `filled` is the share of the places
## that are taken.
func parked_cars(from: Vector3, to: Vector3, filled := 0.7) -> void:
	var along := to - from
	var yaw := rad_to_deg(atan2(along.x, along.z))
	var places := floori(along.length() / 5.4)
	for i in places:
		if _prop_rng.randf() < filled:
			parked_car(from + along.normalized() * (i + 0.5) * 5.4, yaw)


## What stands along the kerb of a quay, on the line from `from` to `to`: a
## lantern and an elm turn and turn about, some eleven metres apart, and
## between one and the next two places to park, of which `filled` are taken.
func kerb_line(from: Vector3, to: Vector3, kind := "ritter", filled := 0.6) -> void:
	var length := from.distance_to(to)
	var step := (to - from) / length
	var yaw := rad_to_deg(atan2(step.x, step.z))
	var posts := maxi(1, roundi(length / 11.0))
	var pitch := length / posts
	for i in posts:
		var at := from + step * pitch * (i + 0.5)
		if i % 2 == 0:
			lantern(at, kind)
		else:
			elm(at)
		if i == posts - 1:
			break
		for place: float in [0.27, 0.73]:
			if _prop_rng.randf() < filled:
				parked_car(at + step * pitch * place, yaw)
