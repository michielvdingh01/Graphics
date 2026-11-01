extends "res://tools/models/vehicles.gd"
## What the customers of a supermarket drive: a big American SUV with room for
## five, in four colours. Build with tools/build_model.sh suv. It stands as
## the vehicles of tools/models/vehicles.gd do, nose along -Z, and
## scripts/vehicle.gd drives it by vehicles/<colour>.tres.

const COLOURS: Array[String] = ["white", "red", "black", "blue"]
const TRIM := "shop_dark"
const CHROME := "car_chrome"
const TAIL := "car_tail"
const LAMP_GLASS := "car_lamp"
const CAR_AMBER := "car_amber"
## How wide its body is and where its wheels are.
const WIDE := 1.96
const WHEEL_X := 0.84
const WHEEL_Z := 1.5
const WHEEL_R := 0.4
## How high the sill, the top of the doors and the roof are.
const SILL := 0.42
const BELT := 1.17
const ROOF := 1.82

var _body_paint := ""


func _describe() -> void:
	for colour in COLOURS:
		_body_paint = "car_" + colour
		_twice(_suv.bind("suv_" + colour))


func _suv(model_name: String) -> void:
	model(model_name)
	_solid(Vector3(0, 0.85, 0), Vector3(WIDE, 0.86, 4.86))
	_solid(Vector3(0, 1.5, 0.45), Vector3(WIDE - 0.16, 0.62, 3.5))
	for x: float in [-WHEEL_X, WHEEL_X]:
		for z: float in [-WHEEL_Z, WHEEL_Z]:
			var turns := ("WheelFL" if x < 0.0 else "WheelFR") if z < 0.0 else ("WheelBL" if x < 0.0 else "WheelBR")
			_on(turns, Transform3D(Basis(), Vector3(x, WHEEL_R, z)))
			_wheel(Vector3(x, WHEEL_R, z), WHEEL_R, 0.26, Vector3(signf(x), 0, 0), 6)
			_touches(turns, Vector3(x, WHEEL_R, z), WHEEL_R, z < 0.0)
			_on("Body")
	_body_side()
	_cabin()
	_front()
	_back()
	_inside()


## The body seen from the side, cut out round the wheels, across its width.
func _body_side() -> void:
	var outline := PackedVector2Array()
	var nose := -2.42
	var tail := 2.42
	outline.append_array([Vector2(nose + 0.06, 0.48), Vector2(nose, 0.72), Vector2(nose + 0.02, 0.95), Vector2(nose + 0.16, 1.08), Vector2(-1.28, BELT - 0.03), Vector2(-1.05, BELT)])
	outline.append_array([Vector2(tail - 0.06, BELT + 0.03), Vector2(tail, 1.04), Vector2(tail, 0.62), Vector2(tail - 0.08, 0.48)])
	# Back along the underside, round the arch of each wheel.
	var bottom := PackedVector2Array()
	for z: float in [WHEEL_Z, -WHEEL_Z]:
		var r := WHEEL_R + 0.1
		for i in 9:
			var angle := PI * float(i) / 8.0
			bottom.append(Vector2(z + cos(angle) * r, WHEEL_R + sin(angle) * r))
	outline.append_array(bottom)
	# The outline runs from the nose over the top to the tail and back under;
	# slab() wants it the other way round, as seen from the left.
	var reversed := PackedVector2Array()
	for i in range(outline.size() - 1, -1, -1):
		reversed.append(outline[i])
	slab(_body_paint, Transform3D(SIDE, Vector3.ZERO), reversed, WIDE, 0.05, _part)
	# The doors and what goes along the sides.
	for x: float in [-1.0, 1.0]:
		var skin := x * (WIDE * 0.5 + 0.002)
		for z: float in [-0.92, 0.28, 1.34]:
			_plate(TRIM, Vector3(skin, 0.8, z), Vector3(0.006, 0.72, 0.012))
		_plate(TRIM, Vector3(skin, 0.52, 0.2), Vector3(0.03, 0.14, 2.3))
		for z: float in [-0.45, 0.8]:
			_piece(CHROME, Vector3(skin + x * 0.012, 1.02, z), Vector3(0.024, 0.03, 0.16))
		_block(_body_paint, Vector3(x * (WIDE * 0.5 + 0.09), 1.26, -0.76), Vector3(0.16, 0.12, 0.08), 0.02)
		# The rails on the roof.
		_bar(TRIM, Vector3(x * 0.72, ROOF + 0.05, -0.2), Vector3(x * 0.72, ROOF + 0.05, 1.9), 0.016, 6)
		_rail(TRIM, [Vector3(x * 0.72, ROOF, -0.2), Vector3(x * 0.72, ROOF + 0.05, -0.15)], 0.014)
		_rail(TRIM, [Vector3(x * 0.72, ROOF, 1.9), Vector3(x * 0.72, ROOF + 0.05, 1.85)], 0.014)


## The glass and what holds the roof up.
func _cabin() -> void:
	var glass := PackedVector2Array([
		Vector2(-1.05, BELT - 0.02), Vector2(2.36, BELT - 0.02), Vector2(1.95, ROOF - 0.04), Vector2(-0.3, ROOF - 0.03),
	])
	var inset := WIDE - 0.14
	slab(PANE, Transform3D(SIDE, Vector3.ZERO), glass, inset, 0.03, _part)
	# The roof, a shade wider than the glass.
	var top := PackedVector2Array([Vector2(-0.34, ROOF - 0.05), Vector2(2.04, ROOF - 0.07), Vector2(1.96, ROOF - 0.01), Vector2(-0.3, ROOF)])
	slab(_body_paint, Transform3D(SIDE, Vector3.ZERO), top, inset + 0.04, 0.02, _part)
	for x: float in [-1.0, 1.0]:
		var side := x * (inset * 0.5 + 0.006)
		_bar(_body_paint, Vector3(side, BELT, -1.04), Vector3(side, ROOF - 0.03, -0.3), 0.038, 6)
		_bar(TRIM, Vector3(side, BELT, 0.28), Vector3(side, ROOF - 0.03, 0.28), 0.04, 6)
		_bar(TRIM, Vector3(side, BELT, 1.36), Vector3(side, ROOF - 0.03, 1.36), 0.04, 6)
		_bar(_body_paint, Vector3(side, BELT, 2.34), Vector3(side, ROOF - 0.04, 1.95), 0.07, 6)


func _front() -> void:
	# The grille and the lamps either side of it.
	_block(CHROME, Vector3(0, 0.82, -2.42), Vector3(1.0, 0.3, 0.05), 0.02)
	for i in 4:
		_plate(TRIM, Vector3(0, 0.72 + i * 0.066, -2.446), Vector3(0.94, 0.03, 0.008))
	for x: float in [-1.0, 1.0]:
		_block(LAMP_GLASS, Vector3(x * 0.72, 0.86, -2.4), Vector3(0.36, 0.17, 0.08), 0.03)
		_piece(CAR_AMBER, Vector3(x * 0.72, 0.76, -2.39), Vector3(0.3, 0.05, 0.05))
	_block(TRIM, Vector3(0, 0.54, -2.42), Vector3(WIDE - 0.1, 0.22, 0.2), 0.05)
	_plate("paper", Vector3(0, 0.54, -2.53), Vector3(0.3, 0.15, 0.006))


func _back() -> void:
	for x: float in [-1.0, 1.0]:
		_block(TAIL, Vector3(x * 0.78, 1.0, 2.42), Vector3(0.28, 0.32, 0.06), 0.02)
	_piece(CHROME, Vector3(0, 0.92, 2.44), Vector3(0.9, 0.05, 0.01))
	_block(TRIM, Vector3(0, 0.54, 2.42), Vector3(WIDE - 0.1, 0.2, 0.2), 0.05)
	_plate("paper", Vector3(0, 0.76, 2.435), Vector3(0.3, 0.15, 0.006))
	_block(CHROME, Vector3(-0.6, 0.42, 2.4), Vector3(0.1, 0.1, 0.2), 0.02)


## What is seen through the glass, and where they sit.
func _inside() -> void:
	for x: float in [-0.42, 0.42]:
		_seat(Vector3(x, 0.72, -0.2), 0.48)
	_block(TRIM, Vector3(0, 0.84, 0.86), Vector3(1.5, 0.3, 0.5), 0.05)
	_block(TRIM, Vector3(0, 1.14, 1.08), Vector3(1.5, 0.5, 0.1), 0.05)
	_block(TRIM, Vector3(0, 1.0, -0.86), Vector3(1.66, 0.3, 0.42), 0.05)
	_steering(Vector3(-0.42, 1.14, -0.66), 0.19)
	_sits("driver", Vector3(-0.42, 0.86, -0.15), Vector3(-0.42, 1.56, -0.12), Vector3(-1.6, 0.0, -0.1), false)
	_sits("passenger", Vector3(0.42, 0.86, -0.15), Vector3(0.42, 1.56, -0.12), Vector3(1.6, 0.0, -0.1), false)
	for x: float in [-0.45, 0.45]:
		_sits("passenger", Vector3(x, 0.92, 0.9), Vector3(x, 1.6, 0.92), Vector3(signf(x) * 1.6, 0.0, 0.9), false)
