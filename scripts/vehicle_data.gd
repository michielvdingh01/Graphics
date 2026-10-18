class_name VehicleData
extends Resource
## All tuning for one kind of vehicle: what scripts/vehicle.gd drives by. The
## model (tools/models/vehicles.gd) is the other half and says where things
## are: its wheels, its seats, its turret. A new vehicle is a model and one of
## these, in vehicles/<kind>.tres.

@export var display_name := "Vehicle"
@export var model: PackedScene

@export_group("Body")
## Kilograms. The forces of the wheels are worked out for this, so a heavier
## vehicle is not slower, only harder to shove.
@export var mass := 1200.0
## Where its weight is, in the coordinates of the model: low keeps it on its
## wheels.
@export var center_of_mass := Vector3(0.0, 0.45, 0.0)
## What more than the world's gravity pulls it down while it is on the
## ground, as a share of its weight: a vehicle in a game that drives off the
## top of a dune should come down again, not sail.
@export var weight := 0.6
## Where the engine is, in the coordinates of the model: where it is heard
## from, and where it smokes and burns once it is hit.
@export var engine_at := Vector3(0.0, 1.0, -1.2)

@export_group("Wheels")
## On tracks: it turns by driving them apart, on the spot if it stands still.
@export var tracked := false
## How far the wheels go up from where they hang, and back, in metres.
@export var travel := 0.22
## How fast the springs bounce back, in Hz, and how much of that the dampers
## take out, 1 being no bounce at all.
@export var spring_hz := 1.6
@export var damping := 0.45
## How much of what the springs hold on one side the bar between them puts on
## the other: against rolling over in a bend.
@export var anti_roll := 0.5
## How hard the tyres hold on the ground, sideways and along, as a share of
## the weight on them: 1 is dry tarmac, sand is less.
@export var grip := 1.05
## The share of the sideways slip the tyres take out in one step: 1 grips
## like a rail, less lets it slide.
@export var bite := 0.35
## What is left of the grip of the back wheels with the hand brake on.
@export var drift_grip := 0.35
## The most the front wheels turn, in degrees, and the share of that which is
## left at top speed.
@export var steer_deg := 32.0
@export var steer_at_speed := 0.3
## How fast the wheels go from straight to full lock, in seconds.
@export var steer_time := 0.25
## On tracks: how fast it turns on the spot and at speed, in degrees a second.
@export var turn_rate := 50.0
@export var turn_at_speed := 28.0

@export_group("Engine")
@export var idle_rpm := 800.0
@export var max_rpm := 4200.0
## The most the engine turns the shaft with, in Nm, which it gives at
## `peak_rpm`; at idle and at the top it gives less.
@export var torque := 260.0
@export var peak_rpm := 2400.0
## How much of the power arrives at the wheels.
@export var efficiency := 0.85
## The ratios of the gears from first up, of reverse, and of the axle.
@export var gears: PackedFloat32Array = PackedFloat32Array([3.4, 2.1, 1.4, 1.0])
@export var reverse := 3.6
@export var final_drive := 5.0
## Seconds without drive while it shifts, and the shares of `max_rpm` at
## which it shifts up and down by itself.
@export var shift_time := 0.32
@export var shift_up := 0.86
@export var shift_down := 0.42
## It goes no faster than this in metres a second, and backwards no faster
## than `reverse_speed`.
@export var top_speed := 25.0
@export var reverse_speed := 6.0
## Seconds the engine takes to start.
@export var start_time := 1.1
## What slows it: the brakes, as a share of the grip they use; the air, in
## newtons per (m/s) squared; the ground under the wheels, as a share of the
## weight.
@export var brake := 0.9
@export var drag := 0.45
@export var rolling := 0.02

@export_group("Damage")
@export var health := 300.0
## What is left of a hit from a gun, and of a blast. A hit of `heavy_hit` or
## more in one go is a shell or a rocket and counts in full, whatever it is.
@export var bullet_share := 0.4
@export var blast_share := 1.0
@export var heavy_hit := 100.0
## Below this share of its health the engine is hit: it smokes, misfires and
## gives less. Below `burning` it is alight, and burns down by `burn_rate` a
## second until it goes up.
@export var damaged := 0.45
@export var burning := 0.15
@export var burn_rate := 0.035
## A change of speed of more than this in one bump, in m/s, is a crash that
## does harm: `crash_damage` for every m/s over it.
@export var crash_from := 7.0
@export var crash_damage := 10.0
## The blast when it goes up: reach in metres, damage at its heart, how big
## it looks next to a barrel.
@export var blast_radius := 7.0
@export var blast_damage := 160.0
@export var blast_size := 1.8
## Running somebody down: from this speed in m/s it hurts, and at
## `run_over_kills` it kills.
@export var run_over_from := 3.5
@export var run_over_kills := 9.0

@export_group("Gun")
## A turret that turns, and a gun in it that lifts: degrees a second, and
## how far down and up it goes.
@export var has_turret := false
@export var turret_rate := 40.0
@export var gun_rate := 20.0
@export var gun_depression := 8.0
@export var gun_elevation := 18.0
## The shell: metres a second out of the muzzle, what a hit square does, the
## blast it makes, and the seconds to load the next.
@export var shell_speed := 180.0
@export var shell_hit := 250.0
@export var shell_radius := 6.5
@export var shell_damage := 150.0
@export var shell_size := 1.7
@export var reload_time := 4.0

@export_group("View")
## Where the camera follows it from: metres behind and up of the middle of
## the vehicle, and what it looks at above that middle.
@export var camera_back := 6.5
@export var camera_up := 2.4
@export var camera_aim := 1.2

@export_group("Sound")
## Takes that go round while the engine runs, each recorded at the speed in
## `engine_rpms`: the one nearest the engine is heard, pitched to it, and
## the two either side fade over into one another.
@export var engine_loops: Array[StringName] = []
@export var engine_rpms: PackedFloat32Array = PackedFloat32Array()
## How loud the engine is at idle and under full load, in dB.
@export var engine_idle_db := -8.0
@export var engine_load_db := 0.0
@export var start_sound := &""
@export var stop_sound := &""
@export var shift_sound := &"vehicle_shift"
@export var brake_sound := &""
## In and out: a door, or a hatch.
@export var door_sound := &""
@export var crash_sound := &"vehicle_crash"
## Goes round while the engine is hit.
@export var damaged_sound := &"engine_damaged"
@export var explode_sound := &"vehicle_explode"
## Goes round as it rolls, louder with speed: tyres in sand, or tracks.
@export var roll_sound := &""
## Goes round while the turret turns; the gun firing, and loading.
@export var turret_sound := &""
@export var cannon_sound := &""
@export var load_sound := &""
