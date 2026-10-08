class_name WeaponData
extends Resource
## All tuning for one weapon. Gameplay reads only this; the viewmodel scene is
## the swappable graphics half and just needs a Marker3D called "Muzzle".

@export var display_name := "Weapon"
@export var viewmodel: PackedScene
@export var shot_sound := &"rifle_shot"

@export_group("Fire")
@export var damage := 20.0
@export var headshot_multiplier := 2.0
@export var rounds_per_minute := 600.0
@export var automatic := true
@export var pellets := 1
@export var max_range := 200.0
## Damage scales linearly down to min_damage_scale between these distances.
@export var falloff_start := 30.0
@export var falloff_end := 60.0
@export var min_damage_scale := 0.5

@export_group("Ammo")
@export var mag_size := 30
@export var reserve_ammo := 120
@export var reload_time := 1.8
## Loaded one round at a time, each taking `reload_time / mag_size`, instead
## of by the magazine; a shot interrupts it.
@export var loads_singly := false

@export_group("Accuracy")
@export var hip_spread_deg := 1.5
@export var ads_spread_deg := 0.15
## Extra spread at full sprint speed, mostly removed while aiming.
@export var move_spread_deg := 2.0
@export var bloom_per_shot_deg := 0.35
@export var bloom_max_deg := 3.0
@export var bloom_recovery_deg := 6.0

@export_group("Recoil")
@export var recoil_pitch_deg := 1.2
@export var recoil_yaw_deg := 0.5
@export var ads_recoil_scale := 0.7
## Viewmodel kick: metres back and radians up per shot.
@export var kick_back := 0.04
@export var kick_rotation := 0.06

@export_group("Aim down sights")
@export var ads_fov := 55.0
@export var ads_time := 0.18
@export var ads_move_scale := 0.6
## Aimed through a telescopic sight: the HUD shows the picture through it and
## the weapon itself goes out of view.
@export var scoped := false

@export_group("Viewmodel")
@export var hip_offset := Vector3(0.2, -0.2, -0.4)
@export var ads_offset := Vector3(0.0, -0.06, -0.3)
## How the weapon is turned at the hip, in degrees: muzzle up, to the left, and rolled.
@export var hip_rotation_deg := Vector3.ZERO
