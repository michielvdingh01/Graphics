extends CanvasLayer
## Code-built HUD: dynamic crosshair, hit markers, health, ammo, damage direction and vignette.
## Everything is drawn with 2D primitives so it costs next to nothing next to the 3D pass.

const HEALTH_COLOR := Color(0.35, 0.9, 0.45)
const LOW_HEALTH_COLOR := Color(0.95, 0.25, 0.2)
const CROSSHAIR_COLOR := Color(1, 1, 1, 0.9)
const OUTLINE_COLOR := Color(0, 0, 0, 0.55)

var _player: Node3D
var _weapons: WeaponManager

var _fps_label := Label.new()
var _ammo_label := Label.new()
var _weapon_label := Label.new()
var _health_label := Label.new()
var _kills_label := Label.new()
var _center_label := Label.new()
var _quality_label := Label.new()
var _crosshair := Control.new()
var _hitmarker := Control.new()
var _indicator := Control.new()
var _vignette := ColorRect.new()
var _health_bar_bg := ColorRect.new()
var _health_bar := ColorRect.new()

var _health := 100.0
var _max_health := 100.0
var _hit_t := 0.0
var _hit_kind := "hit"
var _damage_t := 0.0
var _hit_directions: Array[Vector2] = []
var _mag := 0
var _mag_size := 30


func _ready() -> void:
	_build()
	_bind.call_deferred()


func _bind() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if not _player:
		return
	_weapons = _player.get_node("Head/Camera3D/WeaponManager") as WeaponManager
	_weapons.ammo_changed.connect(_on_ammo_changed)
	_weapons.hit_confirmed.connect(_on_hit_confirmed)
	_weapons.fired.connect(_crosshair.queue_redraw)
	_weapons.refresh()
	_player.health_changed.connect(_on_health_changed)
	_player.damaged.connect(_on_damaged)
	_player.died.connect(func() -> void: _center_label.text = "ELIMINATED")
	_player.respawned.connect(func() -> void: _center_label.text = "")
	var arena := get_tree().get_first_node_in_group("arena") as Arena
	if arena:
		arena.kills_changed.connect(func(k: int) -> void: _kills_label.text = "Kills  %d" % k)


func _process(delta: float) -> void:
	_fps_label.text = "%d fps" % Engine.get_frames_per_second()
	_quality_label.text = "Quality: %s (F2)" % Graphics.preset_name
	_hit_t = maxf(_hit_t - delta, 0.0)
	_damage_t = maxf(_damage_t - delta, 0.0)
	_crosshair.queue_redraw()
	_hitmarker.visible = _hit_t > 0.0
	if _hit_t > 0.0:
		_hitmarker.queue_redraw()
	_indicator.queue_redraw()
	_update_vignette()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_shader := Shader.new()
	vignette_shader.code = """
shader_type canvas_item;
uniform float intensity = 0.0;
uniform vec3 tint = vec3(0.8, 0.02, 0.02);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = smoothstep(0.35, 1.25, length(p * vec2(0.9, 1.0)));
	COLOR = vec4(tint, edge * intensity);
}
"""
	var vignette_mat := ShaderMaterial.new()
	vignette_mat.shader = vignette_shader
	_vignette.material = vignette_mat
	root.add_child(_vignette)

	for control: Control in [_crosshair, _hitmarker, _indicator]:
		control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(control)
	_crosshair.draw.connect(_draw_crosshair)
	_hitmarker.draw.connect(_draw_hitmarker)
	_indicator.draw.connect(_draw_indicator)

	_style(_fps_label, 16)
	_fps_label.position = Vector2(14, 8)
	root.add_child(_fps_label)
	_style(_quality_label, 14)
	_quality_label.position = Vector2(14, 30)
	_quality_label.modulate = Color(1, 1, 1, 0.6)
	root.add_child(_quality_label)

	_style(_kills_label, 22)
	_kills_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_kills_label.position.y = 14
	_kills_label.text = "Kills  0"
	root.add_child(_kills_label)

	_style(_center_label, 54)
	_center_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.custom_minimum_size = Vector2(800, 80)
	_center_label.position -= Vector2(400, 40)
	_center_label.modulate = LOW_HEALTH_COLOR
	root.add_child(_center_label)

	_health_bar_bg.color = Color(0, 0, 0, 0.45)
	_health_bar_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_health_bar_bg.position = Vector2(34, -64)
	_health_bar_bg.size = Vector2(300, 12)
	root.add_child(_health_bar_bg)
	_health_bar.color = HEALTH_COLOR
	_health_bar.size = _health_bar_bg.size
	_health_bar_bg.add_child(_health_bar)
	_style(_health_label, 20)
	_health_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_health_label.position = Vector2(34, -98)
	root.add_child(_health_label)

	_style(_ammo_label, 56)
	_ammo_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label.custom_minimum_size = Vector2(300, 64)
	_ammo_label.position = Vector2(-334, -108)
	root.add_child(_ammo_label)
	_style(_weapon_label, 20)
	_weapon_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon_label.custom_minimum_size = Vector2(300, 28)
	_weapon_label.position = Vector2(-334, -44)
	root.add_child(_weapon_label)


func _style(label: Label, size: int) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("outline_size", maxi(size / 8, 2))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_ammo_changed(mag: int, reserve: int, weapon_name: String) -> void:
	_mag = mag
	_mag_size = _weapons.current.mag_size
	_ammo_label.text = "%d / %d" % [mag, reserve]
	_weapon_label.text = weapon_name
	var low := mag <= maxi(_mag_size / 4, 1)
	_ammo_label.modulate = LOW_HEALTH_COLOR if low else Color.WHITE


func _on_hit_confirmed(kind: String) -> void:
	_hit_kind = kind
	_hit_t = 0.28 if kind == "kill" else 0.16
	Sfx.play("kill" if kind == "kill" else ("hit_head" if kind == "head" else "hit"), -6.0)


func _on_health_changed(health: float, max_health: float) -> void:
	_health = health
	_max_health = max_health
	_health_label.text = "%d" % ceili(health)
	_health_bar.size.x = _health_bar_bg.size.x * health / max_health
	_health_bar.color = HEALTH_COLOR.lerp(LOW_HEALTH_COLOR, 1.0 - clampf(health / (max_health * 0.5), 0.0, 1.0))


func _on_damaged(direction: Vector3) -> void:
	_damage_t = 0.6
	# Convert the world direction into an angle on screen relative to where the player looks.
	var forward := -_player.global_basis.z
	var right := _player.global_basis.x
	_hit_directions.append(Vector2(direction.dot(right), -direction.dot(forward)))
	if _hit_directions.size() > 4:
		_hit_directions.pop_front()
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if not _hit_directions.is_empty():
			_hit_directions.pop_front()
	)


func _update_vignette() -> void:
	var low := 1.0 - clampf(_health / (_max_health * 0.4), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	var intensity := maxf(_damage_t / 0.6 * 0.55, low * (0.35 + 0.2 * pulse))
	(_vignette.material as ShaderMaterial).set_shader_parameter("intensity", intensity)


func _draw_crosshair() -> void:
	if not _weapons:
		return
	var center := _crosshair.size * 0.5
	var fov: float = _player.get_node("Head/Camera3D").fov
	var pixels_per_degree := _crosshair.size.y / fov
	var gap := 5.0 + _weapons.spread_deg * pixels_per_degree
	var alpha := 1.0 - 0.8 * smoothstep(0.0, 1.0, _weapons.ads_t)
	var color := Color(CROSSHAIR_COLOR, CROSSHAIR_COLOR.a * alpha)
	var shade := Color(OUTLINE_COLOR, OUTLINE_COLOR.a * alpha)
	var length := 9.0
	for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var a := center + dir * gap
		var b := center + dir * (gap + length)
		_crosshair.draw_line(a, b, shade, 4.0)
		_crosshair.draw_line(a, b, color, 2.0)
	_crosshair.draw_circle(center, 1.6, color)


func _draw_hitmarker() -> void:
	var center := _hitmarker.size * 0.5
	var color := Color.WHITE
	var size := 7.0
	var width := 2.5
	match _hit_kind:
		"head":
			color = Color(1.0, 0.8, 0.2)
			size = 9.0
		"kill":
			color = Color(1.0, 0.2, 0.15)
			size = 12.0
			width = 3.5
	var life := _hit_t / (0.28 if _hit_kind == "kill" else 0.16)
	var pop := 1.0 + (1.0 - life) * 0.35
	for dir: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var a := center + dir * 6.0 * pop
		var b := center + dir * (6.0 + size) * pop
		_hitmarker.draw_line(a, b, Color(0, 0, 0, 0.5 * life), width + 2.0)
		_hitmarker.draw_line(a, b, Color(color, life), width)


func _draw_indicator() -> void:
	var center := _indicator.size * 0.5
	for dir in _hit_directions:
		if dir.length() < 0.01:
			continue
		var angle := dir.angle()
		var alpha := clampf(_damage_t / 0.6 + 0.35, 0.0, 1.0)
		_indicator.draw_arc(center, 150.0, angle - 0.35, angle + 0.35, 16, Color(1.0, 0.15, 0.1, alpha), 8.0, true)
