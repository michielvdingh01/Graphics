extends "res://tools/level_builder.gd"
## First drawer of the kit, see tools/kit.gd: the parts that machines are put
## together from, and the materials they are made of. All of them build in
## the frame of the machine being built, `_m`, with the flags in `_part`.

# Materials of the machines.
const GREEN := "machine"
const BLUE := "machine_blue"
const BARE := "bare_steel"
const IRON := "dark_steel"
const RUST := "steel"
const YELLOW := "steel_yellow"
const RUBBER := "rubber"
const BRASS := "brass"
const RED := "enamel_red"


## Rolled I-section lying between two points, standing on them.
func _i_beam(mat: String, from: Vector3, to: Vector3, width: float, height: float) -> void:
	var flange := height * 0.08
	for y: float in [flange * 0.5, height - flange * 0.5]:
		beam(mat, _m * (from + Vector3(0, y, 0)), _m * (to + Vector3(0, y, 0)), width, _part, flange)
	var middle := Vector3(0, height * 0.5, 0)
	beam(mat, _m * (from + middle), _m * (to + middle), width * 0.08, _part, height - flange * 2.0)


## Bolted pair of flanges on a pipe of `radius` that runs along `axis` through `at`.
func _flange(mat: String, at: Vector3, axis: Vector3, radius: float) -> void:
	var along := axis.normalized()
	var rim := radius * 1.5 + 0.03
	_bar(mat, at - along * 0.03, at + along * 0.03, rim, 20)
	for side: float in [-1.0, 1.0]:
		_bolt_circle(at + along * side * 0.03, along * side, (radius + rim) * 0.5, 8)


## Unit vector `deg` degrees round from +Z towards +X.
func _round(deg: float) -> Vector3:
	return Basis(Vector3.UP, deg_to_rad(deg)) * Vector3.BACK


## Hexagonal bolt head sitting on `at`.
func _bolt(at: Vector3, out: Vector3, size := 0.022) -> void:
	_bar(IRON, at, at + out * size * 0.7, size, 6)


func _bolt_circle(center: Vector3, out: Vector3, radius: float, count: int) -> void:
	var plane := _up_along(out)
	for i in count:
		var angle := TAU * i / count
		_bolt(center + (plane.x * cos(angle) + plane.z * sin(angle)) * radius, out)


## Handwheel with three spokes and a crank handle; `center` is the middle of
## the rim and `axis` points at whoever turns it.
func _handwheel(center: Vector3, axis: Vector3, radius: float) -> void:
	var plane := _up_along(axis)
	var thickness := radius * 0.11
	_ring(BARE, center, axis, radius, thickness)
	_bar(BARE, center - plane.y * thickness * 2.0, center + plane.y * thickness * 1.2, radius * 0.22)
	for i in 3:
		var angle := TAU * i / 3.0
		_bar(BARE, center, center + (plane.x * cos(angle) + plane.z * sin(angle)) * radius, thickness * 0.7, 8)
	var grip := center + plane.x * radius
	_bar(RUBBER, grip, grip + plane.y * radius * 0.7, thickness * 1.1, 8)


## Lever with a ball knob on a boss; `at` lies on the surface it sits on,
## `out` is the normal of that surface and `toward` the way the lever points.
func _lever(at: Vector3, out: Vector3, toward: Vector3, length: float) -> void:
	_turned(IRON, at, out, PackedVector2Array([Vector2(0.04, 0), Vector2(0.04, 0.025), Vector2(0, 0.03)]), 12)
	var tip := at + out * 0.03 + toward.normalized() * length
	_bar(BARE, at + out * 0.02, tip, 0.009, 8)
	_ball(RUBBER, tip, 0.024)


## Spoked flywheel on a shaft along X; the face of its rim is worn bright by the belt.
func _flywheel(center: Vector3, radius: float, width: float) -> void:
	var inner := radius * 0.84
	var hub := radius * 0.2
	var half := width * 0.5
	var edge := 0.015
	_turned(GREEN, center, Vector3.RIGHT, PackedVector2Array([
		Vector2(radius - edge, half), Vector2(inner, half), Vector2(inner, -half), Vector2(radius - edge, -half),
	]), 40)
	_turned(BARE, center, Vector3.RIGHT, PackedVector2Array([
		Vector2(radius - edge, -half), Vector2(radius, -half + edge), Vector2(radius, half - edge), Vector2(radius - edge, half),
	]), 40)
	_turned(GREEN, center - Vector3(width * 0.7, 0, 0), Vector3.RIGHT, PackedVector2Array([
		Vector2(0, 0), Vector2(hub, 0), Vector2(hub, width * 1.4), Vector2(0, width * 1.4),
	]))
	for i in 6:
		var turn := 60.0 * i + 15.0
		var out := Basis(Vector3.RIGHT, deg_to_rad(turn)) * Vector3.UP
		_block(GREEN, center + out * (hub + inner) * 0.5, Vector3(width * 0.45, inner - hub + 0.04, 0.11), 0.02, Vector3(turn, 0, 0))


## Electric motor with cooling fins. It starts at `start` and runs along
## `axis`, with the shaft at the far end; one that lies down stands on `feet`.
func _motor(mat: String, start: Vector3, axis: Vector3, radius: float, length: float, feet := true) -> void:
	var end := radius * 0.5
	_turned(mat, start, axis, PackedVector2Array([
		Vector2(0, 0), Vector2(radius * 0.55, end * 0.1), Vector2(radius * 0.92, end * 0.5), Vector2(radius, end),
		Vector2(radius, length - end), Vector2(radius * 0.92, length - end * 0.5), Vector2(radius * 0.55, length - end * 0.1), Vector2(0, length),
	]), 24, true)
	var fins := int((length - end * 2.4) / 0.035)
	for i in fins:
		var along := end * 1.2 + (length - end * 2.4) * (i + 0.5) / fins
		_bar(mat, start + axis * (along - 0.006), start + axis * (along + 0.006), radius * 1.09, 20)
	_bar(BARE, start + axis * (length - 0.02), start + axis * (length + radius * 0.5), radius * 0.16)
	# The terminal box sits on top of a motor that lies down.
	var plane := _up_along(axis)
	var middle := start + axis * length * 0.5
	rounded_box(mat, _m * Transform3D(plane, middle - plane.z * (radius + 0.03)), Vector3(radius * 0.6, radius * 0.7, 0.08), 0.015, _part)
	if feet:
		rounded_box(mat, _m * Transform3D(plane, middle + plane.z * (radius + 0.01)), Vector3(radius * 1.8, length * 0.6, 0.04), 0.008, _part)


## Sheet-metal door with ventilation slots; `at` is its middle on the surface
## it closes and `out` the normal of that surface.
func _louvred_door(mat: String, at: Vector3, out: Vector3, size: Vector2) -> void:
	var across := Vector3.UP.cross(out)
	var plate := Vector3(size.x, size.y, 0.03)
	var slot := Vector3(size.x * 0.65, 0.025, 0.012)
	if absf(out.x) > 0.5:
		plate = Vector3(0.03, size.y, size.x)
		slot = Vector3(0.012, 0.025, size.x * 0.65)
	_block(mat, at + out * 0.005, plate, 0.012)
	for i in 5:
		_block(IRON, at + out * 0.022 + Vector3(0, (i - 2) * 0.06 - size.y * 0.12, 0), slot, 0.004)
	_bar(IRON, at + out * 0.02 + across * size.x * 0.4 + Vector3(0, 0.12, 0), at + out * 0.05 + across * size.x * 0.4 + Vector3(0, 0.12, 0), 0.018, 8)


## Pressure gauge: a brass case with a white dial and a hand. `at` lies on the
## surface it sits on and `out` is the normal of that surface.
func _gauge(at: Vector3, out: Vector3, radius: float) -> void:
	_turned(BRASS, at, out, PackedVector2Array([
		Vector2(radius, 0), Vector2(radius, 0.04), Vector2(radius * 0.88, 0.045), Vector2(radius * 0.88, 0.03),
	]), 20)
	var part := _part
	_part = DETAIL | NO_COLLIDE
	_turned("paper", at, out, PackedVector2Array([Vector2(radius * 0.88, 0.03), Vector2(0, 0.03)]), 20)
	var plane := _up_along(out)
	var hand := (plane.x * 0.6 + plane.z * 0.8) * radius * 0.6
	_bar(IRON, at + out * 0.034 - hand * 0.2, at + out * 0.034 + hand, radius * 0.035, 4)
	_bar(IRON, at + out * 0.03, at + out * 0.04, radius * 0.1, 8)
	_part = part
