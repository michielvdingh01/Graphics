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
## The most that is carried in reserve. A level starts with less than this,
## see weapons.gd.
@export var reserve_ammo := 120
## Never runs out of reserve: what is always there to fall back on.
@export var bottomless := false
@export var reload_time := 1.8
## Loaded one round at a time, each taking `reload_time / mag_size`, instead
## of by the magazine; a shot interrupts it.
@export var loads_singly := false
## Loaded by a clip that goes in with the rounds and stays in, as in the M1
## Garand: a new one goes in only once the last round is fired, and that shot
## throws the empty clip out with a ping (its sound <weapon>_ping, see
## _handling() in scripts/weapons.gd). The action stays open until then.
@export var en_bloc := false

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
## The field of view of a second stage of the sight that brings things
## closer still, 0 for a sight with one. A weapon that has it is not aimed by
## holding the key but by tapping it: once to ads_fov, again to far_fov, a
## third time back to the hip.
@export var far_fov := 0.0

@export_group("Muzzle")
## Length of the flash in metres, and the number of tongues the muzzle device
## splits it into: 0 for a bare muzzle, 2 for a brake that blows to the sides.
@export var flash_size := 0.34
@export var flash_prongs := 4
## How much quieter its shot is played than the sound is in its file, in dB.
## Every shot is cut to the same peak; one with a silencer has lost its bang
## and is played lower. How far it is heard by a guard or a bot is
## flash_size: a flash that small goes with a shot that quiet.
@export var shot_db := 0.0
## The weapon whose sounds of handling it has (its magazine, its bolt), by
## the name of its shot without "_shot"; empty for its own. A weapon with a
## silencer is handled as the one without.
@export var handled_as := &""

@export_group("Viewmodel")
@export var hip_offset := Vector3(0.2, -0.2, -0.4)
@export var ads_offset := Vector3(0.0, -0.06, -0.3)
## How the weapon is turned at the hip, in degrees: muzzle up, to the left, and rolled.
@export var hip_rotation_deg := Vector3.ZERO

@export_group("Bots")
## How far a bot with it in its hands sees, in metres: through a telescopic
## sight a long way.
@export var bot_sight := 50.0
## The distance a bot fights at with it, in metres: nearer it stops closing in.
@export var bot_range := 10.0

@export_group("Carrying")
## How fast whoever carries it walks and runs, next to how fast without it.
@export var move_scale := 1.0
## Too heavy to run with.
@export var no_sprint := false
## Seconds to put the weapon in hand away and bring this one up: the longer
## of the two weapons' times.
@export var switch_time := 0.3

@export_group("Spinning barrels")
## Seconds the barrels take to come up to speed from standing still, and
## before that nothing is fired; and to run down once let go. 0 for a weapon
## with no barrels to spin.
@export var spin_up := 0.0
@export var spin_down := 1.0
## Rounds a minute at the first shot, which come up to rounds_per_minute over
## spin_ramp seconds of firing, with ramp_spread_deg more spread until then.
@export var rounds_per_minute_start := 1200.0
@export var spin_ramp := 0.5
@export var ramp_spread_deg := 0.6
## Holding the aim spins the barrels instead of aiming down sights, and its
## carrier then walks at spun_move_scale of the speed it has with it.
@export var aim_spins := false
@export var spun_move_scale := 0.5

@export_group("Heat")
## Seconds of fire that overheat it, 0 for never; the seconds it then cannot
## fire, while the heat goes out of it; and the share of its heat it loses a
## second while it is not fired.
@export var overheat_after := 0.0
@export var overheat_time := 3.0
@export var cooling := 0.25

@export_group("Special")
## In no pack: it lies in the arena (scripts/stash.gd) and is carried on a
## key of its own, with what it held when it was found and nothing more. Once
## it is empty it is thrown away.
@export var special := false
## What it fires instead of bullets, a scene with scripts/rocket.gd or
## scripts/banana.gd, and how
## fast that leaves the muzzle in m/s.
@export var projectile: PackedScene
@export var projectile_speed := 45.0
## What it fires goes off at what it meets: a bot aims it at the feet and keeps
## it away from walls and from whoever is close. Not so for what only sticks.
@export var blasts := true
## How many of what it fires in one thing set each other off, whatever that
## has left to lose: tools/weapon_sheet.py counts no more shots than that. 0
## for what does not.
@export var bunch := 0
