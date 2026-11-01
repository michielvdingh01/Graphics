extends StaticBody3D
## The mains of a shop: a row of cabinets that can be shot to pieces, and with
## them all the light in the building. What is left is the daylight that comes
## in through the glass, which is less the further from it, and the green of
## the exit signs. Whoever wants to see more looks for a flashlight, see
## scripts/flashlight.gd.
##
## The lamps do not go all at once: they die in a wave from the cabinets out,
## with a flicker, and the hum of the cold cases goes with them. The light of
## the shop is three things: the lamps in the group `mains`, what glows
## (MATERIALS, which all that glows shares, so it goes out as one) and the
## ambient light that the reflection probes in the group `shop_probe` hold.
## A level bakes none of it, so nothing has to be swapped.

## What it takes.
@export var health := 260.0
## What is left of the ambient light of the shop and of the stockroom, in the
## order of their `slice`, and of what they reflect.
const DARK_AMBIENT: Array[float] = [0.08, 0.04]
const DARK_REFLECTION := 0.2
## Blue-grey: what comes in from the sky.
const DARK_COLOUR := Color(0.62, 0.68, 0.82)
## What glows, and how much of it is left: the exit signs keep their battery.
const MATERIALS := {
	"res://materials/shop_lamp.tres": 0.0,
	"res://materials/shop_cool.tres": 0.0,
	"res://materials/shop_sign.tres": 0.0,
	"res://materials/shop_sign_red.tres": 0.0,
}
## Over how many seconds the lamps go, from the nearest to the furthest.
const WAVE := 2.2
const FLICKERS := 4
const FLICKER := 0.07
const AMBIENT_FADE := 2.6
## How much it shakes with a heavy hit.
const SPARK_ON_HIT := 0.5

signal went_out

var out := false
var _brightness := {}


func _ready() -> void:
	add_to_group(&"mains")
	# Materials outlive a level: they have to come back on with it.
	for path: String in MATERIALS:
		var material: StandardMaterial3D = load(path)
		if not _brightness.has(path):
			_brightness[path] = material.emission_energy_multiplier if not material.has_meta(&"lit") else material.get_meta(&"lit")
		material.set_meta(&"lit", _brightness[path])
		material.emission_energy_multiplier = _brightness[path]


func take_damage(amount: float, at: Vector3, direction: Vector3) -> bool:
	if out:
		Fx.strike(at, -direction, direction, "metal", true)
		return false
	health -= amount
	Fx.strike(at, -direction, direction, "metal")
	if randf() < SPARK_ON_HIT:
		Fx.spit(at, -direction)
	if health <= 0.0:
		Net.show(self, &"_blow", [])
	return false


func take_blast(amount: float, at: Vector3, _push: Vector3) -> void:
	take_damage(amount, at, Vector3.DOWN)


func net_state() -> int:
	return 1 if out else 0


func net_restore(state: int) -> void:
	if state and not out:
		_blow(true)


## Whether there is power: for what runs on it.
func powered() -> bool:
	return not out


func _blow(quietly := false) -> void:
	if out:
		return
	out = true
	went_out.emit()
	if not quietly:
		Fx.explosion(global_position + Vector3(0, 0.6, 0), 0.5)
		Fx.flash(global_position, Color(0.6, 0.8, 1.0), 6.0, 12.0, 0.25)
		Sfx.play_at(&"power_blow", global_position, 2.0)
		Sfx.play(&"power_down", -4.0)
	Sfx.change_bed("shop", &"room")
	for door: Node in get_tree().get_nodes_in_group(&"shop_door"):
		door.lose_power()
	var lamps := get_tree().get_nodes_in_group(&"mains").filter(func(node: Node) -> bool: return node is Light3D)
	lamps.sort_custom(func(a: Light3D, b: Light3D) -> bool: return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
	var furthest := 1.0
	for lamp: Light3D in lamps:
		furthest = maxf(furthest, lamp.global_position.distance_to(global_position))
	for lamp: Light3D in lamps:
		if quietly:
			lamp.visible = false
		else:
			_die(lamp, WAVE * lamp.global_position.distance_to(global_position) / furthest)
	# Those that can be shot out are out with the rest, glass and all.
	for body: Node in get_tree().get_nodes_in_group(&"breakable"):
		if body.get("light") and body.light.is_in_group(&"mains") and not body.out:
			body.out = true
			body.call_deferred(&"_go_dark")
	var fade := 0.0 if quietly else AMBIENT_FADE
	for path: String in MATERIALS:
		var material: StandardMaterial3D = load(path)
		_set_or_tween(material, ^"emission_energy_multiplier", _brightness[path] * MATERIALS[path], fade)
	for probe: ReflectionProbe in get_tree().get_nodes_in_group(&"shop_probe"):
		var slice: int = probe.get_meta(&"slice", 0)
		_set_or_tween(probe, ^"ambient_color_energy", DARK_AMBIENT[mini(slice, DARK_AMBIENT.size() - 1)], fade)
		_set_or_tween(probe, ^"ambient_color", DARK_COLOUR, fade)
		_set_or_tween(probe, ^"intensity", DARK_REFLECTION, fade)


func _set_or_tween(target: Object, property: NodePath, value: Variant, seconds: float) -> void:
	if seconds <= 0.0:
		target.set_indexed(property, value)
	else:
		create_tween().tween_property(target, property, value, seconds)


## A lamp goes out with a stutter, `after` seconds from now.
func _die(lamp: Light3D, after: float) -> void:
	var tween := create_tween()
	tween.tween_interval(after)
	for i in FLICKERS:
		tween.tween_callback(func() -> void: lamp.visible = i % 2 == 1)
		tween.tween_interval(FLICKER * randf_range(0.5, 1.5))
	tween.tween_callback(func() -> void: lamp.visible = false)
