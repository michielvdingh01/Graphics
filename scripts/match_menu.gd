extends RefCounted
## The screen of a match, opened with "Multiplayer" on the title screen: what
## kind it is, where it is played and how many play, and a button to start.
## It is put together out of the widgets of scripts/menu.gd, which shows it.
## Bots fill every place that is not the player's. How many there can be is
## the arena's to say: in the dunes twenty a side, and that many unless fewer
## are chosen. Opened to the network, friends can come in: on either side or
## all on one against the bots, and with bots between them or without.

## The levels there are to play in: the name of each as Match.open() takes it.
const ARENAS: Array[String] = ["works", "powerhouse", "factory", "depot", "dunes", "dunes_night", "alps"]
## How big each arena is, by the floor somebody can walk to: small is under
## 1 000 m², large over 2 000 m². Measured on 15 October 2026, see PLAN.md
## under "Een tweede nummer, en hoe groot een arena is". The Alps are huge:
## three kilometres end to end, which nobody crosses on foot.
const SIZES := {"works": "large", "powerhouse": "medium", "factory": "small", "depot": "medium", "dunes": "large", "dunes_night": "large", "alps": "huge"}
## Themes of scripts/enemy_themes.gd that are not on offer as who to play
## against: the second uniform, which soldiers wear anyway, and those that
## look like another.
const NOT_OFFERED: Array[String] = ["soldiers_desert", "panic_clowns", "mannequin_zombie"]
const PRIZE := preload("res://scripts/prize.gd")
const ARMORY := preload("res://scripts/armory.gd")
## How many a side, or in all, the button goes through above twelve, as far as
## the arena takes them: one by one would be too many presses.
const BIG: Array[int] = [16, 20, 24, 30, 40]

## What was chosen last, for as long as the game runs. The prize and the pack
## are kept after that: they are settings, see Settings.prize and Settings.pack.
static var chosen := {"mode": "tdm", "level": "works", "size": 0, "prize": "flag", "pack": "standard", "open": false, "bots": true, "apart": true}
## What went wrong the last time the match was to start.
static var trouble := ""
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
	var packs := ARMORY.names()
	chosen.pack = Settings.pack if packs.has(Settings.pack) else ARMORY.STANDARD
	var kinds: Array = Match.kinds.keys()
	if not kinds.has(chosen.mode):
		chosen.mode = kinds[0]
	menu._heading("Multiplayer", 44)
	menu._note("A match against bots, with bots on your side, and with friends\non your network if you open it to them. Nothing here is saved.")
	if trouble:
		menu._note(trouble)
	menu._list()
	var kind: Button = menu._button("", func() -> void: pass)
	var arena: Button = menu._button("", func() -> void: pass)
	var size: Button = menu._button("", func() -> void: pass)
	var prize: Button = menu._button("", func() -> void: pass)
	var pack: Button = menu._button("", func() -> void: pass)
	var enemies: Button = menu._button("", func() -> void: pass)
	var difficulty: Button = menu._button("", func() -> void: pass)
	var open: Button = menu._button("", func() -> void: pass)
	var people: Button = menu._button("", func() -> void: pass)
	var bots: Button = menu._button("", func() -> void: pass)
	var title: Control = menu._field("Your name", Net.player_name, func(text: String) -> void: Net.player_name = text)
	# Who there is to play against: the robots, and every theme that has
	# people in it.
	var themes: Array[String] = ["soldiers"]
	for theme: String in Settings.enemy_themes:
		if not themes.has(theme) and not NOT_OFFERED.has(theme) and (theme == Match.THEMES.ROBOTS or not Match.THEMES.cast(theme, "grunt", 0).is_empty()):
			themes.append(theme)
	var refresh := func() -> void:
		var numbers: Dictionary = Match.kinds[chosen.mode]
		var teams: bool = (Match.MODES[chosen.mode].new() as RefCounted).teams()
		if chosen.size < int(numbers.least) or chosen.size > Match.most(chosen.mode, chosen.level):
			chosen.size = Match.usual(chosen.mode, chosen.level)
		kind.text = "Kind  ·  %s" % numbers.title
		arena.text = "Arena  ·  %s (%s)" % [(chosen.level as String).capitalize(), SIZES.get(chosen.level, "?")]
		size.text = ("Players a side  ·  %d" if teams else "Players  ·  %d") % chosen.size
		prize.visible = chosen.mode == "ctf" and not prizes.is_empty()
		prize.text = "Prize  ·  %s" % str(PRIZE.spec(chosen.prize).get("name", chosen.prize))
		pack.text = "Weapons  ·  %s" % ARMORY.title(chosen.pack)
		pack.tooltip_text = str(ARMORY.spec(chosen.pack).get("about", ""))
		enemies.text = "Against  ·  %s" % themes[maxi(themes.find(Settings.enemy_theme), 0)].capitalize()
		difficulty.text = "Difficulty  ·  %s" % Settings.DIFFICULTY_NAMES[clampi(Settings.difficulty, 0, Settings.DIFFICULTY_NAMES.size() - 1)]
		open.text = "Friends on your network  ·  %s" % ("Can join" if chosen.open else "No")
		title.visible = chosen.open
		bots.visible = chosen.open
		bots.text = "Bots  ·  %s" % ("Fill the empty places" if chosen.bots else "None")
		people.visible = chosen.open and teams and chosen.bots
		people.text = "Friends play  ·  %s" % ("Against each other" if chosen.apart else "Together against the bots")
	kind.pressed.connect(func() -> void:
		chosen.mode = kinds[(kinds.find(chosen.mode) + 1) % kinds.size()]
		chosen.size = 0
		refresh.call())
	arena.pressed.connect(func() -> void:
		chosen.level = ARENAS[(ARENAS.find(chosen.level) + 1) % ARENAS.size()]
		# As many as usually play there: twenty a side in the dunes, six in a hall.
		chosen.size = 0
		refresh.call())
	size.pressed.connect(func() -> void:
		var sizes := _sizes(int(Match.kinds[chosen.mode].least), Match.most(chosen.mode, chosen.level))
		var next := sizes.find(chosen.size) + 1
		chosen.size = sizes[next % sizes.size()]
		refresh.call())
	prize.pressed.connect(func() -> void:
		picking = true
		menu._show(menu.Screen.MATCH))
	pack.pressed.connect(func() -> void:
		chosen.pack = packs[(maxi(packs.find(chosen.pack), 0) + 1) % packs.size()]
		Settings.put("pack", chosen.pack)
		refresh.call())
	enemies.pressed.connect(func() -> void:
		# The setting of the game itself, so that it is one choice everywhere.
		Settings.put("enemy_theme", themes[(maxi(themes.find(Settings.enemy_theme), 0) + 1) % themes.size()])
		refresh.call())
	difficulty.pressed.connect(func() -> void:
		Settings.put("difficulty", (Settings.difficulty + 1) % Settings.DIFFICULTY_NAMES.size())
		refresh.call())
	open.pressed.connect(func() -> void:
		chosen.open = not chosen.open
		refresh.call())
	people.pressed.connect(func() -> void:
		chosen.apart = not chosen.apart
		refresh.call())
	bots.pressed.connect(func() -> void:
		chosen.bots = not chosen.bots
		refresh.call())
	refresh.call()
	menu._into = menu._column
	menu._button("Start", func() -> void:
		trouble = ""
		menu._show(menu.Screen.NONE)
		if not Match.open(chosen):
			trouble = "Port %d is taken. Is a game being hosted on this computer already?" % Net.port
			menu._show(menu.Screen.MATCH))
	menu._button("Join a game on your network", menu._show.bind(menu.Screen.TOGETHER))
	menu._button("Back", menu._show.bind(menu.Screen.TITLE))
	if _picked_one:
		_picked_one = false
		_focus(menu, prize)


## What the pause screen has to offer in a match that others play in: the
## other side for whoever is on one, and for the host what is played once the
## match starts again.
static func together(menu: Node) -> void:
	if Match.mode.teams() and Match.me():
		menu._button("Change sides", menu._then_resume.bind(Match.change_my_side))
	if not Net.is_host():
		return
	var kinds: Array = Match.kinds.keys()
	var kind: Button = menu._button("", func() -> void: pass)
	var arena: Button = menu._button("", func() -> void: pass)
	var refresh := func() -> void:
		var next: String = Match.upcoming.get("mode", Match.setup.mode)
		var where: String = Match.upcoming.get("level", Match.setup.level)
		var later := "  (once the match starts again)"
		kind.text = "Kind  ·  %s%s" % [Match.kinds[next].title, "" if next == Match.setup.mode else later]
		arena.text = "Arena  ·  %s%s" % [where.capitalize(), "" if where == Match.setup.level else later]
	kind.pressed.connect(func() -> void:
		Match.upcoming.mode = kinds[(kinds.find(Match.upcoming.get("mode", Match.setup.mode)) + 1) % kinds.size()]
		refresh.call())
	arena.pressed.connect(func() -> void:
		Match.upcoming.level = ARENAS[(ARENAS.find(Match.upcoming.get("level", Match.setup.level)) + 1) % ARENAS.size()]
		refresh.call())
	refresh.call()


## How many a side, or in all, there is to choose from between `least` and
## `most`: one by one up to twelve, then in the steps of BIG.
static func _sizes(least: int, most: int) -> Array[int]:
	var sizes: Array[int] = []
	for size in range(least, mini(most, 12) + 1):
		sizes.append(size)
	for size in BIG:
		if size > 12 and size < most:
			sizes.append(size)
	if most > 12:
		sizes.append(most)
	return sizes


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
