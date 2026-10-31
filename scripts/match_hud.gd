extends CanvasLayer
## What a match puts on screen, on top of the HUD of the game: the score and
## the clock, who brought whom down, who brought the player down and when
## they are back, the table of everybody under Tab, and how it ended.
## scripts/match.gd makes one; it shows only while a match is being played.

const WEAPONS := preload("res://scripts/weapons.gd")
## The player's side and the other: told apart by more than red and green.
const OURS := Color(0.35, 0.65, 1.0)
const THEIRS := Color(1.0, 0.62, 0.25)
## A kill of the player's on their own count: it jumps to this size and this
## colour, and is back in this many seconds.
const COUNTED_SIZE := 1.45
const COUNTED := Color(1.0, 0.82, 0.3)
const COUNTED_TIME := 1.0
## How many lines of who brought whom down there are at most, and the
## seconds one stays.
const LINES := 5
const LINE_TIME := 6.0
## The most of a side the table shows under each other, in one column.
const TALL := 10
## How high the table may be, in pixels of a screen 1080 high: from under the
## score and the lines under it to above what is written in the middle. A
## long one has smaller type.
const ROOM := 440.0

var _ours := Label.new()
var _theirs := Label.new()
var _middle := Label.new()
## The player's own kills: the score at the top is that of the side.
var _mine := Label.new()
var _counted: Tween
var _feed := Label.new()
var _centre := Label.new()
var _status := Label.new()
## The table under Tab: one column, or a side in each where they are big.
var _board := HBoxContainer.new()
var _columns: Array[Label] = [Label.new(), Label.new()]
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
	_mine.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_mine.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_mine.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mine.add_theme_font_size_override("font_size", 32)
	_mine.add_theme_constant_override("outline_size", 7)
	_mine.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_child(_mine)
	_feed.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_feed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_feed.add_theme_font_size_override("font_size", 18)
	_feed.add_theme_constant_override("outline_size", 5)
	_feed.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	# Under the player's own kills.
	_feed.position.y += 56
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
	# Under the score, down to no further than what stands in the middle.
	_board.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 124)
	_board.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_board.add_theme_constant_override("separation", 64)
	add_child(_board)
	for column in _columns:
		column.add_theme_font_size_override("font_size", 20)
		column.add_theme_constant_override("outline_size", 6)
		column.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_board.add_child(column)
	for control: Control in [top, _ours, _middle, _theirs, _mine, _feed, _centre, _board]:
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
	_mine.visible = me != null
	if me:
		_mine.text = "KILLS %d" % me.kills
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
		var table := _table()
		var lines := 0
		for column in table:
			lines = maxi(lines, column.count("\n") + 1)
		var font := clampi(int(ROOM / (lines * 1.4)), 13, 20)
		for i in _columns.size():
			_columns[i].text = table[i] if i < table.size() else ""
			_columns[i].visible = i < table.size()
			_columns[i].add_theme_font_size_override("font_size", font)


func _on_felled(by: int, fallen: int, weapon: int, head: bool) -> void:
	var who: RefCounted = Match.entrants.get(fallen)
	var killer: RefCounted = Match.entrants.get(by)
	if who == null:
		return
	var with := "explosion" if weapon == Match.BLAST else "melee" if weapon == Match.MELEE else "run over" if weapon == Match.RUN_OVER else ""
	if weapon >= 0 and weapon < WEAPONS.ARMORY.ALL.size():
		with = WEAPONS.ARMORY.ALL[weapon].display_name.to_lower()
	var text := "%s  ▸  %s" % [killer.title, who.title] if killer else "%s went down" % who.title
	if with and killer:
		text += "   (%s%s)" % [with, ", head" if head else ""]
	_say(text)
	if killer and killer == Match.me():
		_count_kill()
	if fallen == Net.id():
		_by = "%s, %s" % [killer.title, with] if killer and with else killer.title if killer else ""


## The player's count jumps, from its right edge, so that it is seen go up
## without being looked at.
func _count_kill() -> void:
	_mine.pivot_offset = Vector2(_mine.size.x, _mine.size.y * 0.5)
	_mine.scale = Vector2.ONE * COUNTED_SIZE
	_mine.modulate = COUNTED
	if _counted:
		_counted.kill()
	_counted = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_counted.tween_property(_mine, "scale", Vector2.ONE, COUNTED_TIME)
	_counted.tween_property(_mine, "modulate", Color.WHITE, COUNTED_TIME)


func _say(text: String) -> void:
	_lines.append([text, LINE_TIME])
	if _lines.size() > LINES:
		_lines.pop_front()


## Everybody who plays, the best first, a side at a time: the text of each
## column. Sides of more than TALL stand next to each other, or the table
## runs off the screen; so do the two halves of more than twice that who are
## each on their own.
func _table() -> PackedStringArray:
	var me: RefCounted = Match.me()
	var columns := PackedStringArray()
	var rows := PackedStringArray()
	var last := -1
	var list: Array = Match.ranking()
	var teams: bool = Match.mode.teams()
	if teams:
		# A side at a time, and in each the best first still.
		var place := {}
		for i in list.size():
			place[list[i]] = i
		list.sort_custom(func(a: RefCounted, b: RefCounted) -> bool: return a.team < b.team or (a.team == b.team and place[a] < place[b]))
	var apart := list.size() > TALL * 2
	for who: RefCounted in list:
		if apart and not teams and rows.size() == ceili(list.size() / 2.0):
			# Everybody for themselves: the better half on the left.
			columns.append("\n".join(rows))
			rows.clear()
		if teams and who.team != last:
			if apart and not rows.is_empty():
				columns.append("\n".join(rows))
				rows.clear()
			last = who.team
			var ours: bool = me != null and me.team == who.team
			rows.append("%s%s   %d" % ["" if rows.is_empty() else "\n", "YOUR SIDE" if ours else "THE OTHER SIDE" if me else "SIDE %d" % (who.team + 1), Match.tally[who.team]])
		rows.append("%s %-12s %3d kills  %3d deaths" % ["▸" if who == me else "  ", who.title, who.kills, who.deaths])
	columns.append("\n".join(rows))
	return columns
