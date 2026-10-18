extends Control
## What the screen says of vehicles: near one, which key gets in and where;
## in one, how fast it goes, in which gear, how it is holding up, and which
## keys do what. In a tank also where the gun points now, which the turret is
## still turning towards, and whether it is loaded. Made by scripts/hud.gd.

const MARGIN := 28.0
const BAR := Vector2(260, 10)
## The colours of a vehicle that is sound, hit and alight.
const SOUND := Color(0.85, 0.9, 0.8)
const HIT := Color(1.0, 0.7, 0.25)
const ALIGHT := Color(1.0, 0.3, 0.2)
## How far along the gun the point is that is shown as where it points.
const GUN_REACH := 150.0

var player: Node3D

var _prompt := Label.new()
var _name := Label.new()
var _gauges := Label.new()
var _state := Label.new()
var _keys := Label.new()
var _vehicle: Node3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for label: Label in [_prompt, _name, _gauges, _state, _keys]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 150)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_name.add_theme_font_size_override("font_size", 20)
	_gauges.add_theme_font_size_override("font_size", 34)
	_state.add_theme_font_size_override("font_size", 20)
	_keys.add_theme_font_size_override("font_size", 16)
	_keys.modulate.a = 0.6
	for label: Label in [_name, _gauges, _state, _keys]:
		label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN)
		label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_keys.offset_top -= 44
	_keys.offset_bottom -= 44
	_state.offset_top -= 70
	_state.offset_bottom -= 70
	_gauges.offset_top -= 116
	_gauges.offset_bottom -= 116
	_name.offset_top -= 160
	_name.offset_bottom -= 160


func _process(_delta: float) -> void:
	if player == null:
		return
	_vehicle = player.riding
	var near: Dictionary = {} if _vehicle else player.vehicle_in_reach()
	_prompt.visible = not near.is_empty() and player.has_control()
	if _prompt.visible:
		var data: VehicleData = near.vehicle.data
		_prompt.text = "[E]  %s  %s" % ["Drive" if near.seat == 0 else "Get in", data.display_name.to_upper()]
	var riding := _vehicle != null
	for label: Label in [_name, _gauges, _state, _keys]:
		label.visible = riding
	if riding:
		_show_riding()
	queue_redraw()


func _show_riding() -> void:
	var data: VehicleData = _vehicle.data
	var drives: bool = player.seat == 0
	_name.text = "%s  ·  %s" % [data.display_name.to_upper(), "DRIVER" if drives else "SEAT %d" % (player.seat + 1)]
	var gear := "R" if _vehicle.gear < 0 else str(_vehicle.gear)
	if not _vehicle.engine_on:
		gear = "-"
	_gauges.text = "%d km/h   %s" % [roundi(absf(_vehicle.speed) * 3.6), gear]
	_gauges.visible = drives
	match _vehicle.condition:
		_vehicle.Condition.DAMAGED:
			_state.text = "ENGINE HIT"
			_state.modulate = HIT
		_vehicle.Condition.BURNING:
			_state.text = "ON FIRE  -  GET OUT"
			_state.modulate = ALIGHT
		_:
			_state.text = "STARTING" if _vehicle.starting() else ""
			_state.modulate = SOUND
	var keys := "[E] get out   [Q] next seat"
	if drives:
		keys += "   [C] view   [Space] hand brake"
		if data.has_turret:
			keys += "   [mouse] gun"
	_keys.text = keys


func _draw() -> void:
	if _vehicle == null or not is_instance_valid(_vehicle):
		return
	var data: VehicleData = _vehicle.data
	var view := get_viewport().get_visible_rect().size
	# How it holds up, over its name.
	var share := clampf(_vehicle.health / data.health, 0.0, 1.0)
	var at := Vector2(MARGIN, view.y - MARGIN - 196)
	draw_rect(Rect2(at, BAR), Color(0, 0, 0, 0.45))
	var tint := SOUND if share >= data.damaged else (HIT if share >= data.burning else ALIGHT)
	draw_rect(Rect2(at, Vector2(BAR.x * share, BAR.y)), tint)
	if player.seat != 0 or not data.has_turret:
		return
	# The gun: where it points now, a ring; and whether it is loaded, round it.
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var muzzle: Transform3D = _vehicle.muzzle()
	var point := muzzle.origin - muzzle.basis.z.normalized() * GUN_REACH
	if camera.is_position_behind(point):
		return
	var spot := camera.unproject_position(point)
	var radius := view.y * 0.022
	draw_arc(spot, radius, 0.0, TAU, 40, Color(1, 1, 1, 0.8), 2.0, true)
	draw_arc(spot, radius + 5.0, -PI * 0.5, -PI * 0.5 + TAU * _vehicle.loaded, 40, Color(1, 1, 1, 0.9) if _vehicle.loaded >= 1.0 else HIT, 3.0, true)
	draw_circle(view * 0.5, 2.5, Color(1, 1, 1, 0.9))
