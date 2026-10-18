extends Node3D
## What the player sees who drives a vehicle: the vehicle from behind and
## above it, turned about with the mouse, or the road from the seat; C goes
## from the one to the other. Driving with the mouse at rest, the view swings
## back behind the vehicle by itself.
##
## In a tank the view is where the gun is to go: the turret turns after it as
## fast as it can, and the button fires. From the seat that is the gunner's
## sight, which turns with the gun, so that the view comes round with the
## turret and no faster.

## Seconds after the mouse has been let go that the view swings back behind
## the vehicle, and how fast it does, per second.
const BACK_AFTER := 1.2
const SWING := 2.2
## How far the view looks down and up, in radians, from behind and from the
## seat; and from the seat how far to either side.
const PITCH := Vector2(-1.0, 0.45)
const SEAT_PITCH := Vector2(-0.9, 0.7)
const SEAT_YAW := 1.9
## How much nearer the gunner's sight brings what is in it.
const SIGHT_ZOOM := 2.0
## How far a shot of the gun is looked for along the view, in metres.
const SIGHT := 600.0
## How far the camera keeps off what is behind it, in metres.
const CLEAR := 0.3
const WORLD := 1

var vehicle: Node3D
var player: Node3D
var camera: Camera3D
var first_person := false
## Where the view looks: from behind, the way in the world; from the seat of
## a car, the way from the seat.
var yaw := 0.0
var pitch := -0.18
var seat_yaw := 0.0
var _idle := 0.0


func setup(driven: Node3D, driver: Node3D) -> void:
	vehicle = driven
	player = driver
	top_level = true
	camera = Camera3D.new()
	camera.fov = Settings.fov
	camera.near = 0.05
	camera.far = (player.camera as Camera3D).far
	add_child(camera)
	camera.make_current()
	yaw = vehicle.global_rotation.y
	if vehicle.data.has_turret:
		var gun: Vector3 = vehicle.aim
		yaw = atan2(-gun.x, -gun.z)
	_place(0.0)


## Hands the view back to the player and goes.
func close() -> void:
	if is_instance_valid(player):
		(player.camera as Camera3D).make_current()
	queue_free()


## Turns the view by the mouse or the stick, as the player's own view turns.
func look(amount: Vector2) -> void:
	_idle = 0.0
	if first_person and not vehicle.data.has_turret:
		seat_yaw = clampf(seat_yaw - amount.x, -SEAT_YAW, SEAT_YAW)
		pitch = clampf(pitch - amount.y, SEAT_PITCH.x, SEAT_PITCH.y)
	else:
		yaw = wrapf(yaw - amount.x, -PI, PI)
		pitch = clampf(pitch - amount.y, PITCH.x if not first_person else -deg_to_rad(vehicle.data.gun_depression) - 0.1, PITCH.y)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("vehicle_view") and player.has_control():
		first_person = not first_person
		if not first_person:
			pitch = clampf(pitch, PITCH.x, PITCH.y)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_instance_valid(vehicle):
		return
	_idle += delta
	_place(delta)
	var data: VehicleData = vehicle.data
	if data.has_turret:
		vehicle.aim = _aim()
		if player.has_control() and Input.is_action_pressed("fire"):
			vehicle.fire()
	var fov: float = Settings.fov
	if first_person and data.has_turret:
		fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(fov) * 0.5) / SIGHT_ZOOM))
	camera.fov = fov


func _place(delta: float) -> void:
	var data: VehicleData = vehicle.data
	var heading: float = vehicle.global_rotation.y
	if first_person:
		if data.has_turret:
			camera.global_transform = vehicle.sight()
		else:
			if _idle > BACK_AFTER:
				seat_yaw = lerpf(seat_yaw, 0.0, 1.0 - exp(-SWING * delta))
			var eye: Transform3D = vehicle.eye_frame(0)
			camera.global_transform = Transform3D(eye.basis.orthonormalized() * Basis(Vector3.UP, seat_yaw) * Basis(Vector3.RIGHT, pitch), eye.origin)
		return
	# From behind: back along the view from a point over the middle of the
	# vehicle, and no further than what is behind it lets the camera go.
	if not data.has_turret and _idle > BACK_AFTER and absf(vehicle.speed) > 2.0:
		var behind := heading if vehicle.speed > 0.0 else heading + PI
		yaw = lerp_angle(yaw, behind, 1.0 - exp(-SWING * delta))
	var view := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var pivot: Vector3 = vehicle.global_transform * (vehicle.middle() + Vector3.UP * data.camera_aim)
	var want := pivot + view.z * data.camera_back + Vector3.UP * (data.camera_up - data.camera_aim)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(pivot, want, WORLD, [vehicle.get_rid()])
	var hit := space.intersect_ray(query)
	if hit:
		want = hit.position + (pivot - want).normalized() * CLEAR
	camera.global_transform = Transform3D(view, want)


## The way the gun is to point: at whatever is in the middle of the view.
func _aim() -> Vector3:
	var from := camera.global_position
	var ahead := -camera.global_basis.z
	if first_person:
		ahead = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Vector3.FORWARD
	var query := PhysicsRayQueryParameters3D.create(from, from + ahead * SIGHT, WORLD | 4 | 32, [vehicle.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target: Vector3 = hit.position if hit else from + ahead * SIGHT
	var muzzle: Vector3 = vehicle.muzzle().origin
	var way := target - muzzle
	# Something nearer than the muzzle is not where to aim at.
	return way.normalized() if way.length() > 4.0 and way.dot(ahead) > 0.0 else ahead
