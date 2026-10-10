extends CanvasLayer
## Title screen, pause menu, settings and the screen the game ends on, built
## in code like the HUD.
##
## The title screen sits on top of the loaded level, which stays paused and
## inert behind it as a backdrop. Pass --play to skip straight into the game.

enum Screen { NONE, TITLE, LEVELS, PAUSE, SETTINGS, END }

const LEVELS: Array[Dictionary] = [
	{"name": "Factory", "scene": "res://scenes/factory.tscn"},
	{"name": "Depot", "scene": "res://scenes/depot.tscn"},
]
const ACCENT := Color(1.0, 0.62, 0.25)
const COLUMN_WIDTH := 520

var _screen := Screen.NONE
## The screen the settings were opened from.
var _settings_parent := Screen.TITLE
var _enabled := false
var _root := Control.new()
var _shade := ColorRect.new()
var _column := VBoxContainer.new()
var _title_camera: Camera3D
var _time := 0.0
## What the end screen has to say about the run that just finished.
var _end_kills := 0
var _end_run := {}


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_enabled = not Benchmark.active and not SelfTest.active
	_build()
	if not _enabled:
		return
	get_tree().scene_changed.connect(_on_scene_changed)
	if "--play" in OS.get_cmdline_user_args():
		_show(Screen.NONE)
	else:
		# Set before the level's own _ready runs, so it knows to stay inert.
		_show(Screen.TITLE)
		await get_tree().process_frame
		_on_scene_changed()


func is_open() -> bool:
	return _screen != Screen.NONE


## The player has walked out of the last level: the game stops on a screen
## that says so. `kills` is the number of robots destroyed on the way and
## `run` what else the run came to, see Save.stats.
func show_end(kills: int, run := {}) -> void:
	if not _enabled:
		return
	_end_kills = kills
	_end_run = run
	_show(Screen.END)


## What a run came to, as the lines the end screen shows.
func run_summary(run: Dictionary) -> PackedStringArray:
	var seconds := int(run.get("seconds", 0.0))
	var shots: float = run.get("shots", 0.0)
	var lines := PackedStringArray()
	@warning_ignore("integer_division")
	var minutes := seconds / 60
	lines.append("Time  %d:%02d   ·   Deaths  %d   ·   %s" % [minutes, seconds % 60, int(run.get("deaths", 0.0)), Settings.DIFFICULTY_NAMES[Settings.difficulty]])
	if shots > 0.0:
		lines.append("Accuracy  %d%%   ·   Headshots  %d" % [roundi(100.0 * run.get("hits", 0.0) / shots), int(run.get("headshots", 0.0))])
	return lines


## True while the loaded level is only a backdrop for the title screen.
func at_title() -> bool:
	return _screen == Screen.TITLE or _screen == Screen.LEVELS or (
		_screen == Screen.SETTINGS and _settings_parent == Screen.TITLE
	)


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled or not (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		return
	match _screen:
		Screen.NONE:
			_show(Screen.PAUSE)
		Screen.PAUSE:
			_show(Screen.NONE)
		Screen.LEVELS:
			_show(Screen.TITLE)
		Screen.SETTINGS:
			_show(_settings_parent)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _title_camera:
		# A slow drift keeps the backdrop from looking like a still image.
		_time += delta
		_title_camera.rotation.y = _title_camera.get_meta(&"yaw") + sin(_time * 0.12) * 0.12


# --- Screens -----------------------------------------------------------------


func _show(screen: Screen) -> void:
	if screen == Screen.SETTINGS:
		_settings_parent = _screen
	_screen = screen
	for child in _column.get_children():
		child.queue_free()
	_root.visible = screen != Screen.NONE
	get_tree().paused = screen != Screen.NONE
	_shade.color.a = 0.45 if screen == Screen.PAUSE or not at_title() else 0.0
	if screen == Screen.END:
		# The level went dark as the player left it.
		_shade.color.a = 1.0
	if screen == Screen.NONE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	match screen:
		Screen.TITLE:
			_heading(ProjectSettings.get_setting("application/config/name").to_upper(), 64)
			var checkpoint := Save.checkpoint
			if checkpoint:
				var text := "Continue  ·  %s" % _level_name(checkpoint.level)
				if checkpoint.title:
					text += ", %s" % (checkpoint.title as String).to_lower()
				_button(text, _play.bind(checkpoint.level, false))
			_button("New game", _show.bind(Screen.LEVELS))
			_button("Settings", _show.bind(Screen.SETTINGS))
			_button("Quit", get_tree().quit)
		Screen.LEVELS:
			_heading("New game", 44)
			for level in LEVELS:
				_button(level.name, _play.bind(level.scene, true))
			_button("Back", _show.bind(Screen.TITLE))
		Screen.PAUSE:
			_heading("Paused", 44)
			_button("Resume", _show.bind(Screen.NONE))
			_button("Restart from checkpoint", _play.bind(get_tree().current_scene.scene_file_path, false))
			_button("Settings", _show.bind(Screen.SETTINGS))
			_button("Quit to title", _quit_to_title)
		Screen.SETTINGS:
			_heading("Settings", 44)
			_choice("Difficulty", "difficulty", Settings.DIFFICULTY_NAMES)
			_choice("Quality", "quality", Settings.QUALITY_NAMES)
			# MetalFX only exists on Apple hardware.
			var upscalers := Settings.UPSCALER_NAMES if OS.get_name() == "macOS" else Settings.UPSCALER_NAMES.slice(0, 3)
			_choice("Upscaler", "upscaler", upscalers)
			_choice("Enemies", "enemies", Settings.enemy_names)
			_slider("Render scale", "render_scale", 0.5, 1.0, 0.05, "%.0f%%", 100.0)
			_toggle("V-Sync", "vsync")
			_toggle("Fullscreen", "fullscreen")
			_toggle("Show fps", "show_fps")
			_slider("Field of view", "fov", 60.0, 110.0, 1.0, "%.0f°")
			_slider("Mouse sensitivity", "mouse_sensitivity", 0.2, 3.0, 0.05, "%.2f")
			_slider("Stick sensitivity", "stick_sensitivity", 0.2, 3.0, 0.05, "%.2f")
			_toggle("Invert Y", "invert_y")
			_slider("Volume", "volume", 0.0, 1.0, 0.05, "%.0f%%", 100.0)
			_button("Back", _show.bind(_settings_parent))
		Screen.END:
			_heading("You made it out", 56)
			_note("%d robots lie in pieces between here and the factory." % _end_kills)
			for line in run_summary(_end_run):
				_note(line)
			_button("Play again", _play.bind(LEVELS[0].scene, true))
			_button("Quit to title", _quit_to_title)
	_focus_first.call_deferred()


func _play(scene: String, fresh: bool) -> void:
	if fresh:
		Save.clear()
	_show(Screen.NONE)
	get_tree().change_scene_to_file(scene)


func _quit_to_title() -> void:
	_show(Screen.TITLE)
	get_tree().reload_current_scene()


func _on_scene_changed() -> void:
	if _title_camera:
		_title_camera.queue_free()
		_title_camera = null
	if not at_title():
		return
	# Player._ready captured the mouse again.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tree := get_tree()
	for hud in tree.get_nodes_in_group("hud"):
		hud.visible = false
	for player in tree.get_nodes_in_group("player"):
		player.visible = false
	var view: Node3D = tree.get_first_node_in_group("benchmark_view")
	if view:
		_title_camera = Camera3D.new()
		_title_camera.fov = 65.0
		add_child(_title_camera)
		_title_camera.global_transform = view.global_transform
		_title_camera.set_meta(&"yaw", _title_camera.rotation.y)
		_title_camera.make_current()


func _level_name(scene: String) -> String:
	for level in LEVELS:
		if level.scene == scene:
			return level.name
	return scene.get_file().get_basename().capitalize()


# --- Widgets -----------------------------------------------------------------


func _build() -> void:
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = _theme()
	_root.visible = false
	add_child(_root)

	_shade.color = Color(0, 0, 0, 0)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_shade)

	# Darkens the left side so the menu stays readable over any backdrop.
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0.88), Color(0, 0, 0, 0)])
	var fade := GradientTexture2D.new()
	fade.gradient = gradient
	var backing := TextureRect.new()
	backing.texture = fade
	backing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backing.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	backing.custom_minimum_size.x = COLUMN_WIDTH * 2.2
	_root.add_child(backing)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	margin.add_theme_constant_override("margin_left", 96)
	_root.add_child(margin)
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.custom_minimum_size.x = COLUMN_WIDTH
	_column.add_theme_constant_override("separation", 8)
	margin.add_child(_column)


func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 24
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.05)
	normal.set_content_margin_all(12)
	normal.content_margin_left = 20
	var focus: StyleBoxFlat = normal.duplicate()
	focus.bg_color = Color(ACCENT, 0.92)
	for type in ["Button", "CheckButton"]:
		for state in ["normal", "pressed", "hover"]:
			theme.set_stylebox(state, type, normal)
		theme.set_stylebox("focus", type, focus)
		theme.set_color("font_focus_color", type, Color(0.06, 0.05, 0.04))
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_hover_pressed_color", type, Color.WHITE)
	return theme


func _heading(text: String, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	_column.add_child(label)
	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	_column.add_child(gap)


## A line of plain text between a heading and the buttons under it.
func _note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.modulate.a = 0.8
	_column.add_child(label)
	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	_column.add_child(gap)


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(action)
	_focusable(button)
	_column.add_child(button)
	return button


## A button that steps through the named options of an integer setting.
func _choice(label: String, key: String, names: Array[String]) -> void:
	var button := _button("", func() -> void: Settings.put(key, (int(Settings.get(key)) + 1) % names.size()))
	var refresh := func() -> void:
		button.text = "%s  ·  %s" % [label, names[mini(Settings.get(key), names.size() - 1)]]
	button.pressed.connect(refresh)
	refresh.call()


func _toggle(label: String, key: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = label
	toggle.button_pressed = Settings.get(key)
	toggle.toggled.connect(func(on: bool) -> void: Settings.put(key, on))
	_focusable(toggle)
	_column.add_child(toggle)


## `display_scale` turns the stored value into the number shown, e.g. 0.8 into 80.
func _slider(label: String, key: String, from: float, to: float, step: float, format: String, display_scale := 1.0) -> void:
	var row := HBoxContainer.new()
	var caption := Label.new()
	caption.text = label
	caption.custom_minimum_size.x = 240
	row.add_child(caption)
	var slider := HSlider.new()
	slider.min_value = from
	slider.max_value = to
	slider.step = step
	slider.value = Settings.get(key)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var readout := Label.new()
	readout.custom_minimum_size.x = 80
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.text = format % (slider.value * display_scale)
	row.add_child(readout)
	slider.value_changed.connect(
		func(value: float) -> void:
			Settings.put(key, value)
			readout.text = format % (value * display_scale)
	)
	slider.focus_entered.connect(func() -> void: caption.modulate = ACCENT)
	slider.focus_exited.connect(func() -> void: caption.modulate = Color.WHITE)
	_column.add_child(row)


## Makes hovering with the mouse and stepping with a controller the same thing.
func _focusable(control: Control) -> void:
	control.mouse_entered.connect(control.grab_focus)


func _focus_first() -> void:
	for control in _column.find_children("*", "Control", true, false):
		if control.focus_mode == Control.FOCUS_ALL and not control.is_queued_for_deletion():
			control.grab_focus()
			return
