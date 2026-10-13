extends RefCounted
## The screen of a match, opened with "Multiplayer" on the title screen: what
## kind it is, where it is played and how many play, and a button to start.
## It is put together out of the widgets of scripts/menu.gd, which shows it.
## Bots fill every place that is not the player's.

## The levels there are to play in: the name of each as Match.open() takes it.
## The dunes are not among them: twelve are lost on that much land, and it
## has no part yet that is closed off for a match.
const ARENAS: Array[String] = ["works", "powerhouse", "factory", "depot"]

## What was chosen last, for as long as the game runs.
static var chosen := {"mode": "tdm", "level": "works", "size": 0}


static func build(menu: Node) -> void:
	var kinds: Array = Match.kinds.keys()
	if not kinds.has(chosen.mode):
		chosen.mode = kinds[0]
	menu._heading("Multiplayer", 44)
	menu._note("A match against bots, with bots on your side.\nNothing here is saved.")
	var kind: Button = menu._button("", func() -> void: pass)
	var arena: Button = menu._button("", func() -> void: pass)
	var size: Button = menu._button("", func() -> void: pass)
	var refresh := func() -> void:
		var numbers: Dictionary = Match.kinds[chosen.mode]
		var teams: bool = (Match.MODES[chosen.mode].new() as RefCounted).teams()
		if chosen.size < int(numbers.least) or chosen.size > int(numbers.most):
			chosen.size = int(numbers.size)
		kind.text = "Kind  ·  %s" % numbers.title
		arena.text = "Arena  ·  %s" % (chosen.level as String).capitalize()
		size.text = ("Players a side  ·  %d" if teams else "Players  ·  %d") % chosen.size
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
	refresh.call()
	menu._button("Start", func() -> void:
		menu._show(menu.Screen.NONE)
		Match.open(chosen))
	menu._button("Back", menu._show.bind(menu.Screen.TITLE))
