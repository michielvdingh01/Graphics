extends CanvasLayer

var _fps_label := Label.new()


func _ready() -> void:
	_fps_label.position = Vector2(12, 8)
	add_child(_fps_label)

	var crosshair := ColorRect.new()
	crosshair.size = Vector2(4, 4)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(crosshair)


func _process(_delta: float) -> void:
	_fps_label.text = "%d fps" % Engine.get_frames_per_second()
