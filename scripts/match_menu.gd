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

## What was chosen last, for as long as the game runs.
static var chosen := {"mode": "tdm", "level": "works", "size": 0, "prize": "flag"}


static func build(menu: Node) -> void:
	var kinds: Array = Match.kinds.keys()
	if not kinds.has(chosen.mode):
		chosen.mode = kinds[0]
	menu._heading("Multiplayer", 44)
	menu._note("A match against bots, with bots on your side.\nNothing here is saved.")
	var kind: Button = menu._button("", func() -> void: pass)
	var arena: Button = menu._button("", func() -> void: pass)
	var size: Button = menu._button("", func() -> void: pass)
	# What is fought over, where that is something: any prize the table has.
	var prize: Button = menu._button("", func() -> void: pass)
	var prizes: PackedStringArray = (load("res://scripts/prize.gd") as GDScript).kinds()
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
		prize.text = "Prize  ·  %s" % str((load("res://scripts/prize.gd") as GDScript).spec(chosen.prize).get("name", chosen.prize))
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
		chosen.prize = prizes[(maxi(prizes.find(chosen.prize), 0) + 1) % prizes.size()]
		refresh.call())
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
