extends CanvasLayer

const MARGIN := 28
## Seconds a level takes to come up out of black.
const FADE_IN := 0.7


class Crosshair:
	extends Control
	var gap := 6.0
	var opacity := 1.0

	func _draw() -> void:
		var color := Color(1, 1, 1, 0.9 * opacity)
		draw_rect(Rect2(-1, -1, 2, 2), Color(1, 1, 1, 0.9))
		for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(direction * gap, direction * (gap + 9.0), color, 2.0)


class Hitmarker:
	extends Control
	var color := Color.WHITE
	var strength := 0.0

	func _draw() -> void:
		if strength <= 0.0:
			return
		var inner := 7.0 + 4.0 * strength
		var tint := Color(color, strength)
		for direction: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(direction * inner, direction * (inner + 9.0), tint, 2.5)


class Grenades:
	extends Control
	var count := 0

	## One pip for every grenade carried, right to left: a ball with its fuze.
	func _draw() -> void:
		for i in count:
			var at := Vector2(-11.0 - i * 24.0, -12.0)
			draw_circle(at, 8.0, Color(1, 1, 1, 0.9))
			draw_rect(Rect2(at.x - 3.0, at.y - 13.0, 6.0, 6.0), Color(1, 1, 1, 0.9))


var _player: CharacterBody3D
var _root := Control.new()
var _fps_label := Label.new()
var _ammo_label := Label.new()
var _weapon_label := Label.new()
var _grenades := Grenades.new()
var _health_bar := ProgressBar.new()
## A mark on the health bar at what comes back by itself, the health as a
## number, and a line for what was just picked up.
var _regen_mark := ColorRect.new()
var _health_label := Label.new()
var _pickup_label := Label.new()
var _objective_label := Label.new()
var _kills_label := Label.new()
var _banner := Label.new()
var _crosshair := Crosshair.new()
var _hitmarker := Hitmarker.new()
var _vignette := ColorRect.new()
var _vignette_mat := ShaderMaterial.new()
var _scope := ColorRect.new()
var _scope_mat := ShaderMaterial.new()
## Over everything else: black while a level comes in or goes out.
var _curtain := ColorRect.new()
var _hurt := 0.0
var _health_ratio := 1.0


func _ready() -> void:
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Under everything else: what is seen through a telescopic sight.
	_scope_mat.shader = preload("res://shaders/scope.gdshader")
	_scope.material = _scope_mat
	_scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope.visible = false
	_place(_scope, Control.PRESET_FULL_RECT, 0)

	_vignette_mat.shader = preload("res://shaders/damage_vignette.gdshader")
	_vignette.material = _vignette_mat
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_vignette, Control.PRESET_FULL_RECT, 0)

	_place(_fps_label, Control.PRESET_TOP_LEFT)
	# What there is to do, where the wave number used to be.
	_objective_label.add_theme_font_size_override("font_size", 26)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_objective_label, Control.PRESET_TOP_RIGHT)
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_kills_label.modulate.a = 0.75
	_place(_kills_label, Control.PRESET_TOP_RIGHT)
	_kills_label.offset_top += 38
	_kills_label.offset_bottom += 38

	_ammo_label.add_theme_font_size_override("font_size", 40)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_ammo_label, Control.PRESET_BOTTOM_RIGHT)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_weapon_label, Control.PRESET_BOTTOM_RIGHT)
	_weapon_label.offset_bottom -= 56
	_weapon_label.offset_top -= 56
	_place(_grenades, Control.PRESET_BOTTOM_RIGHT)
	_grenades.offset_bottom -= 88
	_grenades.offset_top -= 88

	_health_bar.custom_minimum_size = Vector2(260, 14)
	_health_bar.show_percentage = false
	_health_bar.max_value = 1.0
	_health_bar.value = 1.0
	_place(_health_bar, Control.PRESET_BOTTOM_LEFT)
	_regen_mark.color = Color(1, 1, 1, 0.85)
	_regen_mark.size = Vector2(2, 20)
	_regen_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar.add_child(_regen_mark)
	_health_label.add_theme_font_size_override("font_size", 26)
	_place(_health_label, Control.PRESET_BOTTOM_LEFT)
	_health_label.offset_left += 272
	_health_label.offset_right += 272
	_health_label.offset_top += 8
	_health_label.offset_bottom += 8
	_pickup_label.add_theme_font_size_override("font_size", 24)
	_pickup_label.modulate.a = 0.0
	_place(_pickup_label, Control.PRESET_BOTTOM_LEFT)
	_pickup_label.offset_top -= 30
	_pickup_label.offset_bottom -= 30

	_banner.add_theme_font_size_override("font_size", 56)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_place(_banner, Control.PRESET_CENTER_TOP, 140)

	_place(_crosshair, Control.PRESET_CENTER, 0)
	_place(_hitmarker, Control.PRESET_CENTER, 0)

	_curtain.color = Color.BLACK
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_curtain, Control.PRESET_FULL_RECT, 0)
	create_tween().tween_property(_curtain, "modulate:a", 0.0, FADE_IN)
	_bind.call_deferred()


func _place(control: Control, preset: Control.LayoutPreset, margin := MARGIN) -> void:
	_root.add_child(control)
	control.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, margin)
	# Keep right- and bottom-anchored labels on screen when their text grows.
	if control.anchor_left == 1.0:
		control.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	elif control.anchor_left == 0.5:
		control.grow_horizontal = Control.GROW_DIRECTION_BOTH
	if control.anchor_top == 1.0:
		control.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _bind() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_player.health_changed.connect(_on_health_changed)
	_player.damaged.connect(func(amount: float) -> void: _hurt = minf(_hurt + amount / 25.0, 1.0))
	_player.died.connect(_show_banner.bind("YOU DIED", Color(1, 0.3, 0.25), 10.0))
	_player.weapons.ammo_changed.connect(_on_ammo_changed)
	_player.weapons.hit_confirmed.connect(_on_hit_confirmed)
	_player.weapons.grenades_changed.connect(_on_grenades_changed)
	_on_grenades_changed(_player.weapons.grenades)
	var game := get_tree().get_first_node_in_group("game")
	game.objective_changed.connect(_on_objective_changed)
	game.kills_changed.connect(_on_kills_changed)
	game.checkpoint_reached.connect(func(_title: String) -> void: _show_banner("CHECKPOINT", Color.WHITE, 1.2))
	game.finished.connect(_on_finished.bind(game.EXIT_FADE))
	game.picked_up.connect(_on_picked_up)
	_on_health_changed(_player.health, _player.MAX_HEALTH)
	_on_objective_changed(game.objective, 0)
	_on_kills_changed(game.kills)


func _process(delta: float) -> void:
	_fps_label.visible = Settings.show_fps
	_fps_label.text = "%d fps" % Engine.get_frames_per_second()
	if _player == null:
		return
	var weapons: Node3D = _player.weapons

	# Crosshair gap matches the real spread cone at the current field of view.
	var half_height := get_viewport().get_visible_rect().size.y * 0.5
	var spread := tan(deg_to_rad(weapons.current_spread_deg()))
	_crosshair.gap = 3.0 + spread / tan(deg_to_rad(_player.camera.fov * 0.5)) * half_height
	_crosshair.opacity = 1.0 - weapons.ads_blend
	_crosshair.visible = not _player.dead
	_crosshair.queue_redraw()

	# Aiming a scoped weapon, the view goes black and opens again as a circle.
	var scope: float = weapons.scope_blend()
	_scope.visible = scope > 0.0
	if scope > 0.0:
		var view := get_viewport().get_visible_rect().size
		_scope_mat.set_shader_parameter("cover", smoothstep(0.0, 0.5, scope))
		_scope_mat.set_shader_parameter("open", smoothstep(0.5, 1.0, scope))
		_scope_mat.set_shader_parameter("aspect", view.x / view.y)

	if _hitmarker.strength > 0.0:
		_hitmarker.strength = maxf(_hitmarker.strength - delta * 4.0, 0.0)
		_hitmarker.queue_redraw()

	_hurt = maxf(_hurt - delta * 1.5, 0.0)
	var low_health := clampf(1.0 - _health_ratio / 0.5, 0.0, 1.0) * 0.6
	_vignette_mat.set_shader_parameter("strength", maxf(_hurt, low_health))

	var reloading: float = weapons.reload_fraction()
	if reloading > 0.0:
		_weapon_label.text = "RELOADING %d%%" % (reloading * 100.0)
	else:
		_weapon_label.text = weapons.current().display_name


func _on_health_changed(health: float, max_health: float) -> void:
	_health_ratio = clampf(health / max_health, 0.0, 1.0)
	_health_bar.value = _health_ratio
	_health_label.text = "%d" % ceili(_health_ratio * max_health)
	# What is under the mark comes back by itself; the rest has to be found.
	var regen_to: float = Settings.rules().regen_to / max_health
	_regen_mark.position = Vector2(_health_bar.custom_minimum_size.x * regen_to - 1.0, -3.0)
	_health_label.modulate = Color(1, 0.45, 0.35) if _health_ratio <= regen_to else Color.WHITE


## The reserve is -1 for a weapon that never runs out.
func _on_ammo_changed(_weapon_name: String, mag: int, reserve: int) -> void:
	_ammo_label.text = "%d / %s" % [mag, "∞" if reserve < 0 else str(reserve)]
	_ammo_label.modulate = Color(1, 0.4, 0.3) if mag == 0 else (Color(1, 0.8, 0.4) if reserve == 0 else Color.WHITE)


func _on_picked_up(text: String, tint: Color) -> void:
	_pickup_label.text = text
	_pickup_label.modulate = tint
	var tween := create_tween()
	tween.tween_interval(1.1)
	tween.tween_property(_pickup_label, "modulate:a", 0.0, 0.5)


func _on_grenades_changed(count: int) -> void:
	_grenades.count = count
	_grenades.queue_redraw()


func _on_hit_confirmed(headshot: bool, killed: bool) -> void:
	_hitmarker.strength = 1.0
	_hitmarker.color = Color(1, 0.25, 0.2) if killed else (Color(1, 0.85, 0.3) if headshot else Color.WHITE)
	_hitmarker.queue_redraw()


func _on_objective_changed(text: String, hostiles: int) -> void:
	_objective_label.text = text if hostiles == 0 else "%s  ·  %d left" % [text, hostiles]


func _on_kills_changed(kills: int) -> void:
	_kills_label.text = "Kills %d" % kills


## The screen goes dark as the player walks out of the level.
func _on_finished(_next: String, fade: float) -> void:
	create_tween().tween_property(_curtain, "modulate:a", 1.0, fade)


func _show_banner(text: String, color: Color, hold: float) -> void:
	_banner.text = text
	_banner.modulate = color
	var tween := create_tween()
	tween.tween_interval(hold)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.6)
