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


## The foot of a ritter, pairs of radius and height from the street up: a
## plinth of three mouldings, the drum the arms of the town are cast on, a
## cornice, and a neck that narrows into the shaft. The crown of a bridge
## stands on a heavier one.
const LANTERN_FOOT := [
	Vector2(0.2, 0.0), Vector2(0.2, 0.05), Vector2(0.185, 0.07), Vector2(0.16, 0.09), Vector2(0.15, 0.16),
	Vector2(0.13, 0.2), Vector2(0.124, 0.55), Vector2(0.145, 0.58), Vector2(0.145, 0.62), Vector2(0.11, 0.66),
	Vector2(0.085, 0.8), Vector2(0.07, 0.95), Vector2(0.08, 0.97), Vector2(0.08, 1.01), Vector2(0.062, 1.03),
]
const LANTERN_FOOT_CROWN := [
	Vector2(0.26, 0.0), Vector2(0.26, 0.07), Vector2(0.235, 0.1), Vector2(0.2, 0.13), Vector2(0.19, 0.25),
	Vector2(0.165, 0.3), Vector2(0.158, 0.85), Vector2(0.19, 0.89), Vector2(0.19, 0.95), Vector2(0.14, 1.0),
	Vector2(0.1, 1.25), Vector2(0.085, 1.45), Vector2(0.1, 1.48), Vector2(0.1, 1.53), Vector2(0.072, 1.56),
]


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
## nought, of clinker bricks after rain. Its top is all there is to see of it.
func street_paving(area: Rect2, mat := "klinkers") -> void:
	var middle := area.get_center()
	wall_face(mat, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(middle.x, 0, middle.y)), area.size)
	_collide_box(Transform3D(Basis(), Vector3(middle.x, -0.25, middle.y)), Vector3(area.size.x, 0.5, area.size.y), _surface(mat))


## A street lantern at `at`, lit. "ritter" is the lantern of the quays on its
## cast iron post, "crown" the taller one of the bridges, "mast" the lamp of
## a traffic street, and "wall" one on a bracket: `at` is then the spot on
## the wall under it, at the height of the street, and the wall faces
## `yaw_deg` (0 looks along +Z). A ritter or a crown is turned `yaw_deg` on
## its post: the bar of a ritter runs across that way.
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
	var turn := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	match kind:
		"wall":
			var out := turn * Vector3.BACK
			head += out * 0.7
			rod("lantern_iron", at + Vector3(0, high + 0.25, 0), head + Vector3(0, 0.25, 0), 0.025, small, 8)
			_lantern_head(head, 0.9, turn, "")
		"mast":
			cylinder("galvanised", at, 0.11, high, small, Vector3.ZERO, 0.07, 10)
			_collide_cylinder(Transform3D(Basis(), at + Vector3(0, 1.2, 0)), 0.14, 2.4, "metal")
			box("emissive_warm", head, Vector3(0.28, 0.36, 0.28), Vector3.ZERO, small)
			box("dark_steel", head + Vector3(0, 0.21, 0), Vector3(0.42, 0.08, 0.42), Vector3.ZERO, small)
		"crown":
			_lantern_post(at, high, LANTERN_FOOT_CROWN, 1.2)
			_lantern_head(head, 1.2, turn, "crown")
			_collide_cylinder(Transform3D(Basis(), at + Vector3(0, 1.2, 0)), 0.2, 2.4, "metal")
		_:
			_lantern_post(at, high, LANTERN_FOOT, 1.0)
			# The bar a lamplighter set his ladder against, with a knob at
			# either end. Its shadow under its own light would be a hard
			# line through the foot of the post, where the glass that the
			# light comes from blurs it away.
			var bar := at + Vector3(0, high - 0.915, 0)
			var across := turn * Vector3.RIGHT
			rod("lantern_iron", bar - across * 0.31, bar + across * 0.31, 0.014, small | NO_SHADOW, 8)
			for side: float in [-1.0, 1.0]:
				revolve("lantern_iron", Transform3D(Basis(), bar + across * side * 0.33 - Vector3(0, 0.026, 0)), _knob(0.026), small | NO_SHADOW, 10, true)
			_lantern_head(head, 1.0, turn, "")
			_collide_cylinder(Transform3D(Basis(), at + Vector3(0, 1.2, 0)), 0.16, 2.4, "metal")
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


## The cast iron post of a ritter or a crown from the street up to the cup
## its lantern sits in, `high` being where the light hangs: `foot` as
## LANTERN_FOOT has it, a shaft that narrows as it goes up, a collar for the
## bar of a ritter, and a socket. `size` is how large the lantern is, see
## _lantern_head().
func _lantern_post(at: Vector3, high: float, foot: Array, size: float) -> void:
	var cup := high - 0.34 * size
	var profile := PackedVector2Array(foot)
	profile.append_array(PackedVector2Array([
		Vector2(0.05, cup - 0.62), Vector2(0.062, cup - 0.6), Vector2(0.062, cup - 0.55), Vector2(0.046, cup - 0.53),
		Vector2(0.04, cup - 0.07), Vector2(0.056, cup - 0.03), Vector2(0.05, cup), Vector2(0.0, cup),
	]))
	revolve("lantern_iron", Transform3D(Basis(), at), profile, DETAIL | NO_COLLIDE, 14)


## The lantern itself, with the light at `head`: four panes that widen as
## they go up, in a frame, under a hipped cap with a knob on it, or with
## `top` "crown" the crown of the arms of the town. `size` is how large it
## is; a ritter's is 1.
##
## The cap throws a shadow, and keeps the light of the lantern off the sky and
## off the fronts high up. The rest throws none: so near the light, whose
## glass is a hand wide, the shadow of a bar of the frame is blurred to
## nothing on the street, and a lantern that is not drawn into its own
## shadow costs that much less.
func _lantern_head(head: Vector3, size: float, turn: Basis, top: String) -> void:
	var small := DETAIL | NO_COLLIDE | NO_SHADOW
	var frame := Transform3D(turn, head)
	var low := -0.24 * size
	var high := 0.2 * size
	var narrow := 0.1 * size
	var wide := 0.16 * size
	# The cup it sits in, and the panes, the bottom one too.
	_square_frustum("lantern_iron", frame * Transform3D(Basis(), Vector3(0, low - 0.1 * size, 0)), 0.03 * size, narrow * 0.55, 0.1 * size, small)
	_square_frustum("lantern_glass", frame * Transform3D(Basis(), Vector3(0, low, 0)), narrow, wide, high - low, small, true)
	# The frame: a ring round the foot of the panes and one round their head,
	# and the four bars between.
	var bar := 0.011 * size
	for ring: Vector2 in [Vector2(low, narrow), Vector2(high, wide)]:
		for side in 4:
			var along := Basis(Vector3.UP, side * PI * 0.5)
			_box("lantern_iron", frame * Transform3D(along, along * Vector3(0, ring.x, ring.y)), Vector3(ring.y * 2.0 + bar * 2.0, bar * 2.0, bar * 2.0), small)
	for corner in 4:
		var out := Basis(Vector3.UP, corner * PI * 0.5 + PI * 0.25) * Vector3(0, 0, sqrt(2.0))
		rod("lantern_iron", frame * (out * narrow + Vector3(0, low, 0)), frame * (out * wide + Vector3(0, high, 0)), bar, small, 6)
	# The cap: a rim that stands out over the panes, a hipped roof, and a vent.
	var rim := 0.2 * size
	_square_frustum("lantern_iron", frame * Transform3D(Basis(), Vector3(0, high, 0)), rim, rim, 0.03 * size, DETAIL | NO_COLLIDE, true)
	_square_frustum("lantern_iron", frame * Transform3D(Basis(), Vector3(0, high + 0.03 * size, 0)), rim * 0.94, 0.055 * size, 0.15 * size, small)
	_square_frustum("lantern_iron", frame * Transform3D(Basis(), Vector3(0, high + 0.18 * size, 0)), 0.055 * size, 0.035 * size, 0.04 * size, small, true)
	var crest := head + Vector3(0, high + 0.22 * size, 0)
	if top == "crown":
		_crown(crest, 0.11 * size)
		return
	revolve("lantern_iron", Transform3D(Basis(), crest), PackedVector2Array([
		Vector2(0.02, 0.0) * size, Vector2(0.03, 0.03) * size, Vector2(0.02, 0.06) * size, Vector2(0.008, 0.075) * size,
		Vector2(0.004, 0.16) * size, Vector2(0.0, 0.17) * size,
	]), small, 8, true)


## The crown of the arms of Amsterdam, gilt, `wide` across and standing on
## `at`: a band, four arches from it that meet over the middle, and on them
## an orb with a cross.
func _crown(at: Vector3, wide: float) -> void:
	var small := DETAIL | NO_COLLIDE | NO_SHADOW
	var r := wide * 0.5
	revolve("brass", Transform3D(Basis(), at), PackedVector2Array([
		Vector2(r * 0.55, 0.0), Vector2(r * 0.95, r * 0.08), Vector2(r, r * 0.45), Vector2(r * 0.9, r * 0.5),
		Vector2(r * 0.85, r * 0.2), Vector2(0.0, r * 0.2),
	]), small, 16)
	var peak := at + Vector3(0, r * 1.25, 0)
	for arch in 4:
		var out := Basis(Vector3.UP, arch * PI * 0.5) * Vector3(r * 0.92, 0, 0)
		var points := PackedVector3Array()
		for i in 7:
			var t := i / 6.0
			# Up from the band, out a little, and in over the top.
			points.append(at + out * cos(t * PI * 0.5) * (1.0 + 0.25 * sin(t * PI)) + Vector3(0, r * 0.45 + sin(t * PI * 0.5) * r * 0.8, 0))
		hose("brass", points, r * 0.09, small, 6)
	revolve("brass", Transform3D(Basis(), peak - Vector3(0, r * 0.1, 0)), _knob(r * 0.24), small, 10, true)
	_box("brass", Transform3D(Basis(), peak + Vector3(0, r * 0.62, 0)), Vector3(r * 0.08, r * 0.5, r * 0.08), small)
	_box("brass", Transform3D(Basis(), peak + Vector3(0, r * 0.7, 0)), Vector3(r * 0.3, r * 0.08, r * 0.08), small)


## The profile of a knob `radius` round, standing on its foot.
func _knob(radius: float) -> PackedVector2Array:
	var profile := PackedVector2Array([Vector2(0.0, 0.0)])
	for i in range(1, 8):
		var angle := PI * (i / 8.0 - 0.5)
		profile.append(Vector2(cos(angle), 1.0 + sin(angle)) * radius)
	profile.append(Vector2(0.0, radius * 2.0))
	return profile


## A square frustum in the frame `xf`: its foot `foot` from the middle to a
## side in the XZ plane of `xf`, its head `head` and `high` higher up. With
## `caps` it is closed at both ends.
func _square_frustum(mat: String, xf: Transform3D, foot: float, head: float, high: float, flags := 0, caps := false) -> void:
	var st := _tool(mat, flags, xf * Vector3(0, high * 0.5, 0))
	var slope := Vector2(high, foot - head).normalized()
	var side_size := Vector2(maxf(foot, head) * 2.0, Vector2(high, foot - head).length())
	for side in 4:
		var turn := Basis(Vector3.UP, side * PI * 0.5)
		var normal := xf.basis * (turn * Vector3(0, slope.y, slope.x))
		var points: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for corner: Vector3 in [Vector3(-foot, 0, foot), Vector3(foot, 0, foot), Vector3(head, high, head), Vector3(-head, high, head)]:
			points.append(xf * (turn * corner))
			uvs.append(Vector2(corner.x + xf.origin.x + xf.origin.z, -corner.y - xf.origin.y))
		_quad(st, points, [normal, normal, normal, normal], uvs,
			[_edge(Vector2(0, 0), side_size), _edge(Vector2(1, 0), side_size), _edge(Vector2(1, 1), side_size), _edge(Vector2(0, 1), side_size)])
	if not caps:
		return
	for end: Vector2 in [Vector2(0.0, foot), Vector2(high, head)]:
		var h := end.y
		var up := end.x > 0.0
		var normal := xf.basis * (Vector3.UP if up else Vector3.DOWN)
		# Counter-clockwise seen from outside, as _quad() takes them.
		var corners: Array[Vector3] = [Vector3(-h, end.x, h), Vector3(h, end.x, h), Vector3(h, end.x, -h), Vector3(-h, end.x, -h)]
		if not up:
			corners = [Vector3(-h, end.x, -h), Vector3(h, end.x, -h), Vector3(h, end.x, h), Vector3(-h, end.x, h)]
		var points: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for corner in corners:
			points.append(xf * corner)
			uvs.append(Vector2(corner.x, corner.z))
		var size := Vector2(h, h) * 2.0
		_quad(st, points, [normal, normal, normal, normal], uvs,
			[_edge(Vector2(0, 0), size), _edge(Vector2(1, 0), size), _edge(Vector2(1, 1), size), _edge(Vector2(0, 1), size)])


## Lanterns along the line from `from` to `to`, about `apart` from one to the
## next and none at either end.
func lanterns(from: Vector3, to: Vector3, apart := 22.0, kind := "ritter") -> void:
	var count := maxi(1, roundi(from.distance_to(to) / apart))
	for i in count:
		lantern(from.lerp(to, (i + 0.5) / count), kind)


## A tree at the kerb: an elm, as the canals have them. Nothing but its
## trunk yet, which throws its own shadow under the lanterns.
func elm(at: Vector3) -> void:
	var girth := _prop_rng.randf_range(0.22, 0.34)
	cylinder("bark", at, girth, 6.5, DETAIL | NO_COLLIDE, Vector3.ZERO, girth * 0.7, 10)
	_collide_cylinder(Transform3D(Basis(), at + Vector3(0, 1.5, 0)), girth, 3.0, "wood")


## Elms along the line from `from` to `to`, about `apart` from one to the
## next, each a step out of line.
func elms(from: Vector3, to: Vector3, apart := 11.0) -> void:
	var count := maxi(1, roundi(from.distance_to(to) / apart))
	for i in count:
		elm(from.lerp(to, (i + 0.5) / count) + Vector3(_prop_rng.randf_range(-0.2, 0.2), 0, _prop_rng.randf_range(-0.2, 0.2)))


## A car parked at `at`, the middle of where it stands, its nose the way
## `yaw_deg` looks (0 looks along +Z). Something to crouch behind, and that
## throws its own shadow.
func parked_car(at: Vector3, yaw_deg: float) -> void:
	var frame := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)
	var long := _prop_rng.randf_range(3.9, 4.6)
	_local_box("machine_grey", frame, Vector3(0, 0.55, 0), Vector3(1.75, 0.75, long), DETAIL | NO_COLLIDE)
	_local_box("dark_steel", frame, Vector3(0, 1.15, -0.2), Vector3(1.55, 0.5, long * 0.5), DETAIL | NO_COLLIDE)
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


## What stands along the kerb of a quay, on the line from `from` to `to`, as
## it does on the canals: one row a couple of metres from the water, with an
## elm every ten metres or so and a lantern between every second pair, and
## between one and the next a car parked nose to tail, `filled` of the places
## taken. On the map the lanterns stand 18 to 23 m apart and the elms 9 to
## 14. Nothing stands within three metres of a spot in `clear`: where the
## steps out of the water come up, say.
func kerb_line(from: Vector3, to: Vector3, kind := "ritter", filled := 0.6, clear := PackedVector3Array()) -> void:
	var length := from.distance_to(to)
	var step := (to - from) / length
	var yaw := rad_to_deg(atan2(step.x, step.z))
	var posts := maxi(1, roundi(length / 7.0))
	var pitch := length / posts
	for i in posts:
		var at := from + step * pitch * (i + 0.5)
		if _kerb_free(at, clear):
			if i % 3 == 1:
				lantern(at, kind, yaw + 90.0)
			else:
				elm(at)
		if i == posts - 1:
			break
		if _prop_rng.randf() < filled and _kerb_free(at + step * pitch * 0.5, clear):
			parked_car(at + step * pitch * 0.5, yaw)


## Whether `spot` is three metres or more from every spot in `clear`, seen
## from above.
func _kerb_free(spot: Vector3, clear: PackedVector3Array) -> bool:
	for kept in clear:
		if Vector2(spot.x - kept.x, spot.z - kept.z).length() < 3.0:
			return false
	return true
