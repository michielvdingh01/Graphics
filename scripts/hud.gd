extends CanvasLayer

const MARGIN := 28


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


var _player: CharacterBody3D
var _root := Control.new()
var _fps_label := Label.new()
var _ammo_label := Label.new()
var _weapon_label := Label.new()
var _health_bar := ProgressBar.new()
var _score_label := Label.new()
var _banner := Label.new()
var _crosshair := Crosshair.new()
var _hitmarker := Hitmarker.new()
var _vignette := ColorRect.new()
var _vignette_mat := ShaderMaterial.new()
var _hurt := 0.0
var _health_ratio := 1.0
var _wave := 0
var _kills := 0


func _ready() -> void:
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_vignette_mat.shader = preload("res://shaders/damage_vignette.gdshader")
	_vignette.material = _vignette_mat
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_vignette, Control.PRESET_FULL_RECT, 0)

	_place(_fps_label, Control.PRESET_TOP_LEFT)
	_place(_score_label, Control.PRESET_TOP_RIGHT)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_ammo_label.add_theme_font_size_override("font_size", 40)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_ammo_label, Control.PRESET_BOTTOM_RIGHT)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_weapon_label, Control.PRESET_BOTTOM_RIGHT)
	_weapon_label.offset_bottom -= 56
	_weapon_label.offset_top -= 56

	_health_bar.custom_minimum_size = Vector2(260, 14)
	_health_bar.show_percentage = false
	_health_bar.max_value = 1.0
	_health_bar.value = 1.0
	_place(_health_bar, Control.PRESET_BOTTOM_LEFT)

	_banner.add_theme_font_size_override("font_size", 56)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_place(_banner, Control.PRESET_CENTER_TOP, 140)

	_place(_crosshair, Control.PRESET_CENTER, 0)
	_place(_hitmarker, Control.PRESET_CENTER, 0)
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
	var game := get_tree().get_first_node_in_group("game")
	game.wave_started.connect(_on_wave_started)
	game.kills_changed.connect(_on_kills_changed)
	_update_score()


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
	_health_ratio = health / max_health
	_health_bar.value = _health_ratio


func _on_ammo_changed(_weapon_name: String, mag: int, reserve: int) -> void:
	_ammo_label.text = "%d / %d" % [mag, reserve]
	_ammo_label.modulate = Color(1, 0.4, 0.3) if mag == 0 else Color.WHITE


func _on_hit_confirmed(headshot: bool, killed: bool) -> void:
	_hitmarker.strength = 1.0
	_hitmarker.color = Color(1, 0.25, 0.2) if killed else (Color(1, 0.85, 0.3) if headshot else Color.WHITE)
	_hitmarker.queue_redraw()


func _on_wave_started(wave: int) -> void:
	_wave = wave
	_update_score()
	_show_banner("WAVE %d" % wave, Color.WHITE, 1.5)


func _on_kills_changed(kills: int) -> void:
	_kills = kills
	_update_score()


func _update_score() -> void:
	_score_label.text = "Wave %d\nKills %d" % [_wave, _kills]


func _show_banner(text: String, color: Color, hold: float) -> void:
	_banner.text = text
	_banner.modulate = color
	var tween := create_tween()
	tween.tween_interval(hold)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.6)
