extends RefCounted
## The screen of a match, opened with "Multiplayer" on the title screen: what
## kind it is, where it is played and how many play, and a button to start.
## It is put together out of the widgets of scripts/menu.gd, which shows it.
## Bots fill every place that is not the player's.

## The levels there are to play in: the name of each as Match.open() takes it.
const ARENAS: Array[String] = ["works", "powerhouse", "factory", "depot", "dunes"]
## Themes of scripts/enemy_themes.gd that are not on offer as who to play
## against: the second uniform, which soldiers wear anyway, and those that
## look like another.
const NOT_OFFERED: Array[String] = ["soldiers_desert", "panic_clowns", "mannequin_zombie"]
const PRIZE := preload("res://scripts/prize.gd")

## What was chosen last, for as long as the game runs. The prize is the one
## thing of it that is kept after that: it is a setting, see Settings.prize.
static var chosen := {"mode": "tdm", "level": "works", "size": 0, "prize": "flag"}
## Whether the screen is the list of prizes to choose from, and whether it
## was that a moment ago, so that the focus goes back to where it was.
static var picking := false
static var _picked_one := false


static func build(menu: Node) -> void:
	# What is fought over, where that is something: any prize the table has,
	# and any made on this machine, also since the game started.
	PRIZE.reread()
	var prizes := PRIZE.kinds()
	if picking:
		_pick(menu, prizes)
		return
	chosen.prize = Settings.prize if prizes.has(Settings.prize) or prizes.is_empty() else prizes[0]
	var kinds: Array = Match.kinds.keys()
	if not kinds.has(chosen.mode):
		chosen.mode = kinds[0]
	menu._heading("Multiplayer", 44)
	menu._note("A match against bots, with bots on your side.\nNothing here is saved.")
	var kind: Button = menu._button("", func() -> void: pass)
	var arena: Button = menu._button("", func() -> void: pass)
	var size: Button = menu._button("", func() -> void: pass)
	var prize: Button = menu._button("", func() -> void: pass)
	var enemies: Button = menu._button("", func() -> void: pass)
	var difficulty: Button = menu._button("", func() -> void: pass)
	# Who there is to play against: every theme that has people in it. Robots
	# cannot carry what a player carries, and are soldiers here.
	var themes: Array[String] = ["soldiers"]
	for theme: String in Settings.enemy_themes:
		if not themes.has(theme) and not NOT_OFFERED.has(theme) and not Match.THEMES.cast(theme, "grunt", 0).is_empty():
			themes.append(theme)
	var refresh := func() -> void:
		var numbers: Dictionary = Match.kinds[chosen.mode]
		var teams: bool = (Match.MODES[chosen.mode].new() as RefCounted).teams()
		if chosen.size < int(numbers.least) or chosen.size > int(numbers.most):
			chosen.size = int(numbers.size)
		kind.text = "Kind  ·  %s" % numbers.title
		arena.text = "Arena  ·  %s" % (chosen.level as String).capitalize()
		size.text = ("Players a side  ·  %d" if teams else "Players  ·  %d") % chosen.size
		prize.visible = chosen.mode == "ctf" and not prizes.is_empty()
		prize.text = "Prize  ·  %s" % str(PRIZE.spec(chosen.prize).get("name", chosen.prize))
		enemies.text = "Against  ·  %s" % themes[maxi(themes.find(Settings.enemy_theme), 0)].capitalize()
		difficulty.text = "Difficulty  ·  %s" % Settings.DIFFICULTY_NAMES[clampi(Settings.difficulty, 0, Settings.DIFFICULTY_NAMES.size() - 1)]
	kind.pressed.connect(func() -> void:
		chosen.mode = kinds[(kinds.find(chosen.mode) + 1) % kinds.size()]
		chosen.size = 0
		refresh.call())
	arena.pressed.connect(func() -> void:
		chosen.level = ARENAS[(ARENAS.find(chosen.level) + 1) % ARENAS.size()]
		refresh.call())
	size.pressed.connect(func() -> void:
		var numbers: Dictionary = Match.kinds[chosen.mode]
		chosen.size = chosen.size + 1 if chosen.size < int(numbers.most) else int(numbers.least)
		refresh.call())
	prize.pressed.connect(func() -> void:
		picking = true
		menu._show(menu.Screen.MATCH))
	enemies.pressed.connect(func() -> void:
		# The setting of the game itself, so that it is one choice everywhere.
		Settings.put("enemy_theme", themes[(maxi(themes.find(Settings.enemy_theme), 0) + 1) % themes.size()])
		refresh.call())
	difficulty.pressed.connect(func() -> void:
		Settings.put("difficulty", (Settings.difficulty + 1) % Settings.DIFFICULTY_NAMES.size())
		refresh.call())
	refresh.call()
	menu._button("Start", func() -> void:
		menu._show(menu.Screen.NONE)
		Match.open(chosen))
	menu._button("Back", menu._show.bind(menu.Screen.TITLE))
	if _picked_one:
		_picked_one = false
		_focus(menu, prize)


## Every prize there is, one under the other: choosing one goes back to the
## screen of the match with it.
static func _pick(menu: Node, prizes: PackedStringArray) -> void:
	menu._heading("Prize", 44)
	menu._note("What the two sides fight over. \"Made here\" is a prize\nmade on this machine; one made while the game runs is here too.")
	menu._list()
	var current: Button
	for prize_name in prizes:
		var title := str(PRIZE.spec(prize_name).get("name", prize_name))
		var button: Button = menu._button(title + ("  ·  made here" if PRIZE.made(prize_name) else ""), _picked.bind(menu, prize_name))
		if prize_name == chosen.prize:
			current = button
	menu._into = menu._column
	menu._button("Back", _picked.bind(menu, ""))
	if current:
		_focus(menu, current)


## Back from the list, with `prize_name` chosen if it names one.
static func _picked(menu: Node, prize_name: String) -> void:
	picking = false
	_picked_one = true
	if prize_name:
		chosen.prize = prize_name
		Settings.put("prize", prize_name)
	menu._show(menu.Screen.MATCH)


## Gives `button` the focus once the screen has given it to its first line,
## which it does at the end of the frame it was put together in.
static func _focus(menu: Node, button: Button) -> void:
	# By its number: the screen can be gone by then, and its buttons with it.
	var id := button.get_instance_id()
	var give := func() -> void:
		var still := instance_from_id(id) as Button
		if still and still.is_visible_in_tree():
			still.grab_focus()
	menu.get_tree().process_frame.connect(give, CONNECT_ONE_SHOT)
