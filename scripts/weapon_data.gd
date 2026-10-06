class_name WeaponData
extends Resource
## Pure gameplay numbers for one weapon. Looks live elsewhere: set `viewmodel_scene` to swap in a
## generated asset, otherwise the placeholder built from `placeholder_style` is used.

@export var id := "rifle"
@export var display_name := "Rifle"
@export_group("Damage")
@export var damage := 22.0
@export var headshot_multiplier := 2.0
@export var pellets := 1
@export var max_range := 120.0
@export_group("Fire")
@export var rpm := 700.0
@export var automatic := true
@export var mag_size := 30
@export var reserve_ammo := 120
@export var reload_time := 1.9
@export_group("Accuracy")
## Cone half-angle in degrees.
@export var spread_hip := 1.6
@export var spread_ads := 0.12
@export var spread_move := 1.4
@export var bloom_per_shot := 0.35
@export var bloom_max := 2.5
@export var bloom_recovery := 5.0
@export_group("Recoil")
@export var recoil_pitch := 0.9
@export var recoil_yaw := 0.35
@export var recoil_recovery := 9.0
@export var ads_recoil_scale := 0.65
@export_group("Handling")
@export var ads_fov := 55.0
@export var ads_time := 0.16
@export var equip_time := 0.28
@export var hip_offset := Vector3(0.2, -0.2, -0.38)
@export var ads_offset := Vector3(0.0, -0.1, -0.3)
@export var kick_back := 0.035
@export var kick_rotation := 2.2
@export_group("Presentation")
@export var viewmodel_scene: PackedScene
@export var placeholder_style := "rifle"
@export var tracer_color := Color(1.0, 0.78, 0.35)
@export var shot_pitch := 1.0
@export var shot_length := 0.28
@export var muzzle_energy := 4.0


func shot_interval() -> float:
	return 60.0 / rpm
