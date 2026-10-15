extends CanvasLayer
## What a match puts on screen, on top of the HUD of the game: the score and
## the clock, who brought whom down, who brought the player down and when
## they are back, the table of everybody under Tab, and how it ended.
## scripts/match.gd makes one; it shows only while a match is being played.

const WEAPONS := preload("res://scripts/weapons.gd")
## The player's side and the other: told apart by more than red and green.
const OURS := Color(0.35, 0.65, 1.0)
const THEIRS := Color(1.0, 0.62, 0.25)
## How many lines of who brought whom down there are at most, and the
## seconds one stays.
const LINES := 5
const LINE_TIME := 6.0

var _ours := Label.new()
var _theirs := Label.new()
var _middle := Label.new()
var _feed := Label.new()
var _centre := Label.new()
var _status := Label.new()
var _board := Label.new()
## What the feed has to say: [text, seconds left].
var _lines: Array[Array] = []
## Who brought this machine's player down last.
var _by := ""


func _ready() -> void:
	layer = 3
	visible = false
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 20)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.add_theme_constant_override("separation", 18)
	add_child(top)
	for label: Label in [_ours, _middle, _theirs]:
		label.add_theme_font_size_override("font_size", 30 if label != _middle else 20)
		label.add_theme_constant_override("outline_size", 6)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		top.add_child(label)
	_ours.modulate = OURS
	_theirs.modulate = THEIRS
	_feed.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_feed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_feed.add_theme_font_size_override("font_size", 18)
	_feed.add_theme_constant_override("outline_size", 5)
	_feed.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	# Under where the HUD of the game counts the player's kills.
	_feed.position.y += 80
	add_child(_feed)
	_centre.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_centre.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_centre.grow_vertical = Control.GROW_DIRECTION_BOTH
	_centre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_centre.add_theme_font_size_override("font_size", 26)
	_centre.add_theme_constant_override("outline_size", 6)
	_centre.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_centre.position.y += 90
	add_child(_centre)
	_status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 20)
	_status.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 17)
	_status.add_theme_constant_override("outline_size", 5)
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_status.position.y += 46
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status)
	_board.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_board.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_board.grow_vertical = Control.GROW_DIRECTION_BOTH
	_board.add_theme_font_size_override("font_size", 20)
	_board.add_theme_constant_override("outline_size", 6)
	_board.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_board.position.y -= 120
	add_child(_board)
	for control: Control in [top, _ours, _middle, _theirs, _feed, _centre, _board]:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Match.felled.connect(_on_felled)
	Match.said.connect(_say)
	Match.began.connect(func() -> void:
		_lines.clear()
		_by = "")


func _process(delta: float) -> void:
	visible = Match.active and Match.state >= Match.State.PLAYING and not Menu.at_title()
	if not visible:
		return
	var score: Vector2i = Match.score()
	_ours.text = str(score.x)
	_theirs.text = str(score.y)
	var seconds := ceili(Match.left)
	@warning_ignore("integer_division")
	_middle.text = "%s   ·   to %d   ·   %d:%02d" % [Match.title().to_upper(), int(Match.mode.numbers.limit), seconds / 60, seconds % 60]
	for i in range(_lines.size() - 1, -1, -1):
		_lines[i][1] -= delta
		if _lines[i][1] <= 0.0:
			_lines.remove_at(i)
	_feed.text = "\n".join(_lines.map(func(line: Array) -> String: return line[0]))

	var me: RefCounted = Match.me()
	var over: bool = Match.state == Match.State.OVER
	_status.text = Match.mode.status(me)
	var text := ""
	if over:
		if Match.won == Match.mode.DRAW:
			text = "DRAW"
		elif me:
			text = "VICTORY" if Match.mode.is_winner(me, Match.won) else "DEFEAT"
		else:
			text = "OVER"
		text += "\n\nEnter  again      Esc  menu"
	elif me and me.out > 0.0:
		text = "%sBack in %d" % ["Brought down by %s\n" % _by if _by else "", ceili(me.out)]
	_centre.text = text
	_board.visible = over or Input.is_action_pressed("scoreboard")
	if _board.visible:
		_board.text = _table()


func _on_felled(by: int, fallen: int, weapon: int, head: bool) -> void:
	var who: RefCounted = Match.entrants.get(fallen)
	var killer: RefCounted = Match.entrants.get(by)
	if who == null:
		return
	var with := "explosion" if weapon == Match.BLAST else "melee" if weapon == Match.MELEE else ""
	if weapon >= 0 and weapon < WEAPONS.ARMORY.ALL.size():
		with = WEAPONS.ARMORY.ALL[weapon].display_name.to_lower()
	var text := "%s  ▸  %s" % [killer.title, who.title] if killer else "%s went down" % who.title
	if with and killer:
		text += "   (%s%s)" % [with, ", head" if head else ""]
	_say(text)
	if fallen == Net.id():
		_by = "%s, %s" % [killer.title, with] if killer and with else killer.title if killer else ""


func _say(text: String) -> void:
	_lines.append([text, LINE_TIME])
	if _lines.size() > LINES:
		_lines.pop_front()


## Everybody who plays, the best first, a side at a time.
func _table() -> String:
	var me: RefCounted = Match.me()
	var rows := PackedStringArray()
	var last := -1
	var list: Array = Match.ranking()
	if Match.mode.teams():
		list.sort_custom(func(a: RefCounted, b: RefCounted) -> bool: return a.team < b.team)
	for who: RefCounted in list:
		if Match.mode.teams() and who.team != last:
			last = who.team
			var ours: bool = me != null and me.team == who.team
			rows.append("%s%s   %d" % ["" if rows.is_empty() else "\n", "YOUR SIDE" if ours else "THE OTHER SIDE" if me else "SIDE %d" % (who.team + 1), Match.tally[who.team]])
		rows.append("%s %-12s %3d kills  %3d deaths" % ["▸" if who == me else "  ", who.title, who.kills, who.deaths])
	return "\n".join(rows)
