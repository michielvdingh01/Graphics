extends Node
## A match: a second way to play a level, next to its route. Two sides, or
## everybody for themselves, fight until one has the points or the time is
## up, and whoever dies is back a moment later somewhere safe. It is opened
## from the title screen, or with --match=<kind>:<level>:<size> on the command
## line: tdm, ffa or ctf, the name of a level, and how many play a side, or in
## all where there are no sides; capture the flag takes :<prize> after that, a
## name from assets/prizes.json. --pack=<name> is what everybody carries, a
## pack from assets/packs.json. --only-bots leaves the player out of it, to
## look on.
##
## It takes the level over the way the sandbox does: the route is off, no
## robots stand in it and there is no way out. Everybody who plays is an
## entrant, a person or a bot, with a number, a name, a side and a score. A
## person keeps the number of their machine; a bot has a negative one, and is
## a puppet like that of somebody else's player (scripts/puppet.gd), moved by
## a brain on the host (scripts/bot.gd). Being hit, dying, coming back and the
## count go by the same code for both: harm() and what follows from it.
##
## The rules of a kind of match are a file in scripts/modes/, its numbers are
## in assets/match.json, and where to come back is up to scripts/arena.gd.
## What is decided, the host decides, and what there is to see of it are the
## _show_ functions, as everywhere (see net.gd). For now a match is played on
## one machine: over the wire it is not there yet.
##
## Nothing of it is saved: what the game had saved is set aside for as long
## as a match is open.

## The entrants or the score have changed.
signal changed
## Somebody went down: the numbers of who did it, 0 for nobody, and of who
## fell, what with (a weapon of the loadout, MELEE or BLAST) and whether it
## was a shot to the head.
signal felled(by: int, fallen: int, weapon: int, head: bool)
signal began
## It is over; `won` is a side or the number of an entrant, or mode.DRAW.
signal ended(won: int)
## Something happened that is worth a line: who took the prize, who scored.
signal said(text: String)

enum State { NONE, LOADING, PLAYING, OVER }

const ARENA := preload("res://scripts/arena.gd")
const ARMORY := preload("res://scripts/armory.gd")
const STASH := preload("res://scripts/stash.gd")
## Where a level says its weapons of the arena stand, if it does:
## {"<level>": {"specials": {"<weapon>": [x, y, z]}}}. Otherwise
## scripts/arena.gd finds them a spot.
const ARENAS := "res://assets/arenas.json"
## The weapons of the arena where a pack does not say: assets/packs.json.
const SPECIALS: Array[String] = ["minigun", "rocket_launcher"]
const PICKUP := preload("res://scripts/pickup.gd")
## What knows of the match in its turn is loaded once the game runs, not as
## this is read: the brain of a bot, its body and what is on screen.
const BOT := "res://scripts/bot.gd"
const HUD := "res://scripts/match_hud.gd"
const PUPPET := "res://scenes/puppet.tscn"
const MODES := {
	"tdm": preload("res://scripts/modes/tdm.gd"),
	"ffa": preload("res://scripts/modes/ffa.gd"),
	"ctf": preload("res://scripts/modes/ctf.gd"),
}
const THEMES := preload("res://scripts/enemy_themes.gd")
const FILE := "res://assets/match.json"
const BOTS := "res://assets/bots.json"
const SCENE := "res://scenes/%s.tscn"
## What somebody was hit with that is no weapon of the loadout.
const MELEE := -2
const BLAST := -3
## The physics layers of the two sides, 9 and 10: a shot is looked for on
## the layer of the other side, and so passes through one's own.
const SIDES: Array[int] = [1 << 8, 1 << 9]
const MAX_HEALTH := 100.0
## Health a bot gets back a second, once it has not been hit for a while:
## that of the player.
const MENDS := 20.0
## Seconds a hit goes on counting as the cause of a death.
const BLAME := 10.0
## Seconds after its last shot at a person that a bot still counts as one of
## those firing at them.
const LETS_UP := 1.0
## Seconds the can lies there that somebody who went down leaves.
const CAN_LIES := 30.0
## Where the ends of the arena are further apart than this many metres to
## walk, the bots carry what their pack gives them for far (assets/packs.json):
## in the standard pack the marksman's rifle comes first, and a second one
## before the shotgun.
const FAR := 300.0
## Which of the three figures of a theme the bots against the player are, in
## the order they join.
const FIGURES: Array[String] = ["grunt", "grunt", "rusher", "grunt", "heavy", "grunt"]
## What the bots are called: as many as there can be, so that no two have one
## name.
const NAMES: Array[String] = ["Alder", "Birch", "Cedar", "Dogwood", "Elm", "Fir", "Gorse", "Hazel", "Ivy", "Juniper", "Kapok", "Larch", "Maple", "Nettle",
	"Oak", "Poplar", "Quince", "Rowan", "Sorrel", "Thistle", "Umber", "Vetch", "Willow", "Yarrow", "Ash", "Beech", "Clover", "Dock", "Elder", "Fern",
	"Ginkgo", "Heather", "Iris", "Jasmine", "Laurel", "Moss", "Nutmeg", "Olive", "Pine", "Reed", "Sage", "Tansy", "Wattle", "Yew"]
## Seconds between two reports of where the bots are, for the other machines.
const TICK := 0.05


## Somebody who plays.
class Entrant:
	var id := 0
	var title := ""
	var team := 0
	var bot := false
	var kills := 0
	var deaths := 0
	## Its body in the level: the player of this machine or a puppet.
	var body: CharacterBody3D
	## What thinks for it, if it is a bot and this is the host.
	var brain: Node
	## The weapon of the loadout a bot carries.
	var weapon := 0
	## A bot's health; a person's is kept by their player.
	var health := MAX_HEALTH
	## Seconds until it is back, 0 while it stands; seconds nothing can hurt
	## it yet after coming back; and seconds since it was last hit.
	var out := 0.0
	var safe := 0.0
	var unhurt := 0.0
	## Who hit it last: [number, weapon, head, the clock then].
	var blame: Array = []
	## The bots that are firing at it, a person: the clock at which each
	## last did, by its number. See may_fire().
	var fired_at := {}


## True while the game is a match.
var active := false
var state := State.NONE
## What is played: {mode, level, scene, size, only_bots}, and the kinds there
## are with their numbers.
var setup := {}
var kinds := {}
## The rules of the kind that is played.
var mode: RefCounted
## What Settings.rules() gives while a match is open: what a match has for
## the difficulty that is set. Besides what the game reads of it, that is how
## far health comes back by itself (`regen_to`) and after how long without a
## hit (`regen_after`), what is left of what a bot does to a person (`hurts`),
## how many bots fire at one person at a time (`focus`, 0 for as many as see
## them) and how good the bots are (`bots`).
var rules: Dictionary:
	get:
		return _rules[clampi(Settings.difficulty, 0, _rules.size() - 1)]
## How good a bot can be, by the name of its level: see assets/bots.json.
var levels := {}
## Everybody who plays, by number.
var entrants := {}
## The points of either side, and the seconds that are left.
var tally: Array[int] = [0, 0]
var left := 0.0
## Who won, once it is over.
var won := 0
var arena: RefCounted
## How often a bot got nowhere and had to think of something else, for the
## test to count.
var stuck := 0

var _game: Node3D
var _rules: Array[Dictionary] = []
## Where a cell that mends lies in the arena: {at, cell, due}, the cell that
## lies there now and the clock at which the next one does.
var _cells: Array[Dictionary] = []
var _cell_numbers := {}
## The stands of the weapons of the arena, by weapon, and when they are first
## there and how long after one is gone it is back: assets/match.json.
var _stands := {}
var _special_numbers := {"first": 60.0, "back": 90.0}
## What an arena that is big enough for more than a kind allows says of it,
## by the name of its level: how many may play a side there (`most`) and how
## many do when nothing else is asked for (`size`).
var _arenas := {}
## True once the navmesh of the level is baked, and the corner of it that is
## furthest from the middle of the world: the arena is read once the server
## that finds the ways knows that corner.
var _baked := false
var _corner := Vector3.ZERO
var _clock := 0.0
var _tick := 0.0
var _hud: CanvasLayer


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE)) if FileAccess.file_exists(FILE) else null
	if parsed is Dictionary and parsed.get("modes") is Dictionary:
		for kind: String in parsed.modes:
			if MODES.has(kind):
				kinds[kind] = parsed.modes[kind]
	# Whatever of the rules of the game a match does not have a say on is as
	# the middle difficulty has it.
	var shared: Dictionary = Settings.RULES[1].duplicate()
	if parsed is Dictionary and parsed.get("rules") is Dictionary:
		shared.merge(parsed.rules, true)
	var by_difficulty: Variant = parsed.get("difficulty") if parsed is Dictionary else null
	for i in Settings.RULES.size():
		var one := shared.duplicate()
		one.merge({"regen_to": 100.0, "hurts": 1.0, "focus": 0, "bots": "regular"})
		if by_difficulty is Array and i < by_difficulty.size() and by_difficulty[i] is Dictionary:
			one.merge(by_difficulty[i], true)
		_rules.append(one)
	if parsed is Dictionary and parsed.get("cells") is Dictionary:
		_cell_numbers = parsed.cells
	if parsed is Dictionary and parsed.get("specials") is Dictionary:
		_special_numbers.merge(parsed.specials, true)
	if parsed is Dictionary and parsed.get("arenas") is Dictionary:
		_arenas = parsed.arenas
	var bots: Variant = JSON.parse_string(FileAccess.get_file_as_string(BOTS)) if FileAccess.file_exists(BOTS) else null
	if bots is Dictionary and bots.get("levels") is Dictionary:
		levels = bots.levels
	_hud = (load(HUD) as GDScript).new()
	add_child(_hud)
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--match="):
			var asked := arg.get_slice("=", 1).split(":")
			var what := {"mode": asked[0], "only_bots": "--only-bots" in args}
			if asked.size() > 1:
				what.level = asked[1]
			if asked.size() > 2:
				what.size = asked[2].to_int()
			if asked.size() > 3:
				what.prize = asked[3]
			for other in args:
				if other.begins_with("--pack="):
					what.pack = other.get_slice("=", 1)
			open(what)


## Opens a match and goes to its level: {mode, level, size, only_bots, prize,
## pack}, of which all but the first may be left out. False if there is no such kind or
## no such level.
func open(what: Dictionary) -> bool:
	var kind := str(what.get("mode", "tdm"))
	var level := str(what.get("level", "works"))
	var scene := level if level.begins_with("res://") else SCENE % level
	if not kinds.has(kind) or not ResourceLoader.exists(scene):
		push_warning("No match of the kind '%s' in '%s'; the kinds are %s." % [kind, level, ", ".join(kinds.keys())])
		return false
	close()
	Sandbox.close()
	Net.leave()
	active = true
	state = State.LOADING
	mode = MODES[kind].new()
	mode.numbers = kinds[kind]
	mode.host = self
	var level_name := scene.get_file().get_basename()
	var size := int(what.get("size", 0))
	if size <= 0:
		size = usual(kind, level_name)
	size = clampi(size, int(mode.numbers.least), most(kind, level_name))
	if mode.numbers.get("grows", false) and size > int(mode.numbers.size):
		# More a side bring each other down that much more often, and play to
		# a limit that is that much higher, in tens: 170 for twenty a side.
		mode.numbers = mode.numbers.duplicate()
		mode.numbers.limit = ceili(float(mode.numbers.limit) * size / float(mode.numbers.size) / 10.0) * 10
	setup = {
		"mode": kind,
		"level": level_name,
		"scene": scene,
		"size": size,
		"only_bots": bool(what.get("only_bots", false)),
		"prize": str(what.get("prize", "flag")),
		"pack": str(what.get("pack", ARMORY.STANDARD)) if ARMORY.names().has(str(what.get("pack", ""))) else ARMORY.STANDARD,
	}
	Save.set_aside(true)
	# As the game starts its first level is still on its way in: that one
	# sends the player on if it is the wrong one, see arrive().
	var scene_now := get_tree().current_scene
	if scene_now and scene_now.is_node_ready():
		get_tree().change_scene_to_file(scene)
	return true


## Leaves the match: what was saved is back. Where the player goes from here
## is up to whoever closed it.
func close() -> void:
	if not active:
		return
	active = false
	state = State.NONE
	_forget()
	Save.set_aside(false)
	changed.emit()


## Plays it again, in a level that is as it was.
func again() -> void:
	if active and _game:
		state = State.LOADING
		_forget()
		get_tree().reload_current_scene()


## A level has loaded while a match is open: it becomes the arena, or the
## player is sent on to the level that is.
func arrive(game: Node3D) -> void:
	if game.scene_file_path != setup.scene:
		get_tree().change_scene_to_file.call_deferred(setup.scene)
		return
	_forget()
	_game = game
	state = State.LOADING
	# The route is done with, and there is no way on or out.
	for zone: RefCounted in game.zones:
		zone.started = true
		zone.cleared = true
	game.checkpoints.clear()
	game.exit = null
	game.player.died.connect(_on_player_died)
	game.baked.connect(_on_baked)
	if setup.only_bots:
		# The player looks on, and is in nobody's way.
		game.player.invulnerable = true
		game.player.collision_layer = 0


## The level that is the arena, and whether the match is being played: for
## the rules of a kind, see scripts/modes/mode.gd.
func level() -> Node3D:
	return _game


func playing() -> bool:
	return state == State.PLAYING


## Runs `method` of the rules on every machine: for what a kind of match has
## to show that the others do not, such as a prize that is taken.
func show_mode(method: StringName, args: Array) -> void:
	Net.show(self, &"_show_mode", [method, args])


func _show_mode(method: StringName, args: Array) -> void:
	if mode and mode.has_method(method):
		mode.callv(method, args)
	changed.emit()


## A line for the HUD, and a sound with it if `sound` names one.
func say(text: String, sound := &"") -> void:
	said.emit(text)
	if sound:
		Sfx.play(sound, -6.0)


## Ends the match if the rules say somebody has won.
func judge() -> void:
	if state == State.PLAYING and not Net.is_guest():
		var winner: int = mode.winner(entrants.values(), tally, false)
		if winner != mode.NOBODY:
			Net.show(self, &"_show_end", [winner])


## How many may play a side in a match of the kind `kind` in the level named
## `level`, or how many in all in a kind without sides: what the kind allows,
## or more in an arena that is big enough for it.
func most(kind: String, level: String) -> int:
	var numbers: Dictionary = kinds.get(kind, {})
	var arena: Dictionary = _arenas.get(level, {})
	return maxi(int(numbers.get("most", 1)), int(arena.get("most", 0)) * _share(kind))


## How many play a side there, or in all, when nothing else is asked for.
func usual(kind: String, level: String) -> int:
	var numbers: Dictionary = kinds.get(kind, {})
	var arena: Dictionary = _arenas.get(level, {})
	if arena.has("size"):
		return clampi(int(arena.size) * _share(kind), int(numbers.get("least", 1)), most(kind, level))
	return int(numbers.get("size", 1))


## What the numbers of an arena, which are a side's, come to in a kind: as
## they are where there are sides, twice that where everybody is on their own.
func _share(kind: String) -> int:
	return 1 if not MODES.has(kind) or (MODES[kind].new() as RefCounted).teams() else 2


## What the match is called, for a heading: "Team deathmatch".
func title() -> String:
	return str(mode.numbers.title) if active else ""


## How good the bots are at the difficulty that is set: {reaction, wander,
## aim_time, fov}, see scripts/bot.gd.
func bot_level() -> Dictionary:
	return levels.get(rules.bots, {})


## The entrant of this machine's player; null if that one only looks on.
func me() -> Entrant:
	return entrants.get(Net.id())


## True if `body` is that of somebody who plays.
func plays(body: Object) -> bool:
	return body is Node and (body as Node).has_meta(&"entrant")


## The number of whoever `body` is the body of, 0 for anybody else.
func number(body: Object) -> int:
	return (body as Node).get_meta(&"entrant", 0) if body is Node else 0


## The layers on which a shot of `body` looks for somebody to hit.
func foes_of(body: Object) -> int:
	var who: Entrant = entrants.get(number(body))
	return _foes(who) if who else 0


## Everybody who plays, the best first.
func ranking() -> Array:
	var list := entrants.values()
	list.sort_custom(func(a: Entrant, b: Entrant) -> bool:
		return a.kills > b.kills or (a.kills == b.kills and (a.deaths < b.deaths or (a.deaths == b.deaths and a.id > b.id))))
	return list


## The points that count for this machine's player and the most that anybody
## against has; for somebody who looks on, those of the two sides or of the
## two best.
func score() -> Vector2i:
	var list := ranking()
	var who := me()
	if who:
		return Vector2i(mode.points(who, list, tally), mode.against(who, list, tally))
	if mode.teams():
		return Vector2i(tally[0], tally[1])
	return Vector2i(list[0].kills if list.size() > 0 else 0, list[1].kills if list.size() > 1 else 0)


# --- Hitting and being hit ----------------------------------------------------


## A shot or a blow of `by`, a body, has landed on `target`. True if that
## killed it, as far as this machine can tell.
func hit(by: Node, target: Object, amount: float, at: Vector3, direction: Vector3, weapon := -1, head := false) -> bool:
	if plays(target):
		return harm(number(target), amount, at, direction, number(by), weapon, head)
	return Net.damage(target, amount, at, direction)


## Hurts whoever has the number `victim`, on the host's word. `by` is the
## number of who did it, 0 for nobody: a fire, a barrel. Nothing comes of it
## if they are on one side, or if the victim has only just come back. True if
## it killed.
func harm(victim: int, amount: float, at: Vector3, direction: Vector3, by := 0, weapon := -1, head := false) -> bool:
	if Net.is_guest():
		Net.ask(self, &"harm", [victim, amount, at, direction, by, weapon, head])
		return false
	var who: Entrant = entrants.get(victim)
	if who == null or state != State.PLAYING or who.out > 0.0 or who.safe > 0.0:
		return false
	var from: Entrant = entrants.get(by)
	if from and from != who and not mode.hostile(from, who):
		return false
	if from:
		who.blame = [by, weapon, head, _clock]
		if who.brain:
			who.brain.hit_by(from)
		if from.bot and not who.bot:
			# How hard a bot hits a person is a matter of the difficulty.
			amount *= float(rules.hurts)
	who.unhurt = 0.0
	if who.bot:
		who.health -= amount
		Net.show(who.body, &"hurt", [amount, at, direction])
		if who.health <= 0.0:
			_fell(who, direction)
		return who.health <= 0.0
	if victim == Net.id():
		return _game.player.take_damage(amount, at, direction)
	Net.hurt(victim, amount, at, direction)
	return false


## True if `bot` may fire at `whom` now. At a bot, always. At a person no
## more of them fire at a time than the difficulty has it: the others keep
## their weapon on that person and wait for one of those to let up. Asking
## counts as firing.
func may_fire(bot: Entrant, whom: Entrant) -> bool:
	var most := int(rules.focus)
	if whom.bot or most <= 0:
		return true
	for id: int in whom.fired_at.keys():
		var other: Entrant = entrants.get(id)
		if _clock - float(whom.fired_at[id]) > LETS_UP or other == null or other.out > 0.0:
			whom.fired_at.erase(id)
	if whom.fired_at.has(bot.id) or whom.fired_at.size() < most:
		whom.fired_at[bot.id] = _clock
		return true
	return false


## A bot has seen `whom` at `at`: those on its side know as much.
func seen(by: Entrant, whom: Entrant, at: Vector3) -> void:
	if not mode.teams():
		return
	for other: Entrant in entrants.values():
		if other.brain and other != by and other.team == by.team and other.out <= 0.0:
			other.brain.heard(whom, at)


## `body` has fired from `at`, which is heard `reach` metres off: nothing
## shields somebody who shoots, and the bots against it know where it is.
func fired(body: Node, at: Vector3, reach: float) -> void:
	var who: Entrant = entrants.get(number(body))
	if who == null or Net.is_guest():
		return
	who.safe = 0.0
	for other: Entrant in entrants.values():
		if other.brain and other.out <= 0.0 and mode.hostile(who, other) and other.body.global_position.distance_to(at) < reach:
			other.brain.heard(who, at)


func _on_player_died() -> void:
	var who := me()
	if who and who.out <= 0.0 and not Net.is_guest():
		_fell(who, Vector3.ZERO)


## Somebody is down: whose doing it was, and when they are back.
func _fell(who: Entrant, push: Vector3) -> void:
	var by := 0
	var weapon := -1
	var head := false
	if not who.blame.is_empty() and _clock - float(who.blame[3]) < BLAME:
		by = who.blame[0]
		weapon = who.blame[1]
		head = who.blame[2]
	who.blame = []
	mode.fell(who)
	who.out = float(mode.numbers.respawn)
	Net.show(self, &"_show_fall", [by, who.id, weapon, head, push])
	judge()


func _show_fall(by: int, fallen: int, weapon: int, head: bool, push: Vector3) -> void:
	var who: Entrant = entrants.get(fallen)
	if who == null:
		return
	var killer: Entrant = entrants.get(by)
	if killer == who:
		killer = null
	who.deaths += 1
	if killer:
		killer.kills += 1
	mode.count(killer, who, tally)
	if who.bot:
		who.body.fall(push * 3.0)
	if _game and killer and killer.body == _game.player:
		# What the HUD of the route counts is the player's own.
		_game.kills = killer.kills
		_game.kills_changed.emit(killer.kills)
	if _game:
		# Whoever goes down leaves a can of ammunition, for a while, and the
		# weapon of the arena if they had it.
		var can: Node3D = _game.leave(PICKUP.Kind.AMMO, who.body.global_position + Vector3.UP * 0.9)
		get_tree().create_timer(CAN_LIES, false).timeout.connect(can.queue_free)
		if who.body == _game.player:
			_lay_down(_game.player.weapons.drop_special(), who.body.global_position)
	felled.emit(by if killer else 0, fallen, weapon, head)
	changed.emit()


## Puts somebody who was out back in the level, where it is safe.
func _bring_back(who: Entrant) -> void:
	var foes := PackedVector3Array()
	var friends := PackedVector3Array()
	for other: Entrant in entrants.values():
		if other == who or other.out > 0.0:
			continue
		if mode.hostile(who, other):
			foes.append(other.body.global_position)
		else:
			friends.append(other.body.global_position)
	Net.show(self, &"_show_back", [who.id, mode.come_back(who, foes, friends)])


func _show_back(id: int, pose: Transform3D) -> void:
	var who: Entrant = entrants.get(id)
	if who == null:
		return
	who.out = 0.0
	who.safe = float(rules.safe)
	who.health = MAX_HEALTH
	who.unhurt = 0.0
	if who.bot:
		who.body.rise(pose)
		if who.brain:
			who.brain.begin()
	elif id == Net.id() and _game:
		_game.player.revive(pose)
		_game.player.weapons.restock()
	changed.emit()


func _show_end(winner: int) -> void:
	state = State.OVER
	won = winner
	ended.emit(winner)
	changed.emit()


# --- Setting it up and keeping it going ---------------------------------------


func _physics_process(delta: float) -> void:
	if not active or _game == null or Net.is_guest():
		return
	if state == State.LOADING:
		# The navmesh is baked a moment after the level loads, and the arena
		# is read from it once the ways over it can be asked for. A level may
		# come with a navmesh from when it was built: that is not the one.
		# The server takes a frame or more to take a navmesh over, and may
		# still have that of the level before. Before its first turn it
		# cannot be asked anything.
		var map := _game.get_world_3d().navigation_map
		if _baked and NavigationServer3D.map_get_iteration_id(map) > 0 and NavigationServer3D.map_get_closest_point(map, _corner).distance_to(_corner) < 0.5:
			_begin()
		return
	if state != State.PLAYING:
		return
	_clock += delta
	left -= delta
	for who: Entrant in entrants.values():
		who.safe = maxf(who.safe - delta, 0.0)
		who.unhurt += delta
		if who.out > 0.0:
			who.out -= delta
			if who.out <= 0.0:
				_bring_back(who)
		elif who.bot and who.unhurt > float(rules.regen_after) and who.health < float(rules.regen_to):
			# As far as a person's does, and no further.
			who.health = minf(who.health + MENDS * delta, float(rules.regen_to))
	_tend_cells()
	mode.tick(delta)
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_tell_bots()
	if left <= 0.0:
		left = 0.0
		Net.show(self, &"_show_end", [mode.winner(entrants.values(), tally, true)])


func _on_baked() -> void:
	var region: NavigationRegion3D = _game.nav_region
	for corner in region.navigation_mesh.get_vertices():
		var at := region.global_transform * corner
		if not _baked or at.length_squared() > _corner.length_squared():
			_corner = at
			_baked = true


## The match begins: everybody who plays is in the level, at their own end.
func _begin() -> void:
	arena = ARENA.new()
	if not arena.survey(_game):
		push_warning("%s has no floor to play a match on" % setup.scene)
		state = State.OVER
		return
	var roster := []
	var count: int = mode.head_count(setup.size)
	var named := 0
	for place in count:
		var side: int = mode.side(place)
		if place == 0 and not setup.only_bots:
			roster.append([Net.id(), Net.player_name, side, -1])
		else:
			# A bot has the number of its place, below nought.
			var arms := ARMORY.bots(setup.pack, arena.length() > FAR)
			@warning_ignore("integer_division")
			var arm: int = arms[(place / (2 if mode.teams() else 1)) % arms.size()]
			roster.append([-(place + 1), NAMES[named % NAMES.size()], side, arm])
			named += 1
	Net.show(self, &"_show_roster", [roster])
	mode.begin()
	# Where they start: a side at its end, or everybody as far apart as can be.
	var lines := {}
	for who: Entrant in entrants.values():
		var side := who.team if mode.teams() else -1
		if not lines.has(side):
			var members := entrants.values().filter(func(other: Entrant) -> bool: return not mode.teams() or other.team == who.team)
			lines[side] = arena.line_up(side, members.size())
		Net.show(self, &"_show_back", [who.id, (lines[side] as Array).pop_back()])
		who.safe = 0.0
	left = float(mode.numbers.minutes) * 60.0
	_clock = 0.0
	_cells.clear()
	var cells := clampi(roundi(float(arena.spots.size()) / float(_cell_numbers.get("spots_for_one", 250))), 1, int(_cell_numbers.get("most", 4)))
	for at: Vector3 in arena.caches(cells):
		_cells.append({"at": at, "cell": null, "due": 0.0})
	_set_out_specials()
	state = State.PLAYING
	began.emit()
	changed.emit()


## Sets out the weapons of the arena of the pack on their stands, each on a
## spot of another kind of out of the way (Arena.hideouts()), or where the
## level says in ARENAS. They are there a while after the start.
func _set_out_specials() -> void:
	var weapons: Array[WeaponData] = []
	for weapon_name: Variant in ARMORY.spec(setup.pack).get("specials", SPECIALS):
		var data := ARMORY.named(str(weapon_name))
		if data and data.special:
			weapons.append(data)
	if weapons.is_empty():
		return
	var kinds := [ARENA.Hideout.OFF_THE_WAY, ARENA.Hideout.UP, ARENA.Hideout.IN_THE_OPEN]
	var spots: PackedVector3Array = arena.hideouts(kinds.slice(0, weapons.size()))
	var said: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARENAS)) if FileAccess.file_exists(ARENAS) else null
	var placed: Dictionary = said.get(setup.level, {}).get("specials", {}) if said is Dictionary else {}
	for i in mini(weapons.size(), spots.size()):
		var data := weapons[i]
		var stand: Node3D = STASH.new()
		stand.weapon = data
		stand.back = float(_special_numbers.back)
		_game.add_child(stand)
		var at: Variant = placed.get(data.resource_path.get_file().get_basename())
		stand.global_position = Vector3(at[0], at[1], at[2]) if at is Array and at.size() == 3 else spots[i]
		stand.come_in(float(_special_numbers.first))
		stand.taken.connect(_on_special_taken.bind(stand))
		stand.arrived.connect(func() -> void: say("%s is up" % data.display_name, &"pickup_grenade"))
		_stands[data] = stand
	var weapons_in_hand: Node3D = _game.player.weapons
	if not weapons_in_hand.special_spent.is_connected(_on_special_spent):
		weapons_in_hand.special_spent.connect(_on_special_spent)


## Somebody took a weapon of the arena up, from its stand or from where it
## was dropped, and let go of the one they had, if they had one.
func _on_special_taken(by: Node3D, dropped: Array, from: Node3D) -> void:
	var who := _entrant_of(by)
	if who:
		say("%s has the %s" % [who.title, (from.weapon as WeaponData).display_name.to_lower()])
	_lay_down(dropped, by.global_position)


## A weapon of the arena was fired empty: its stand has it back in a while.
func _on_special_spent(data: WeaponData) -> void:
	var stand: Node3D = _stands.get(data)
	if is_instance_valid(stand):
		stand.release(float(_special_numbers.back))


## Leaves what drop_special() gave where somebody let go of it, with what was
## left in it, for a while; then its stand has it back in a while.
func _lay_down(dropped: Array, at: Vector3) -> void:
	if dropped.is_empty() or _game == null:
		return
	var data: WeaponData = dropped[0]
	var stand: Node3D = _stands.get(data)
	if int(dropped[1]) <= 0:
		if is_instance_valid(stand):
			stand.release(float(_special_numbers.back))
		return
	var lying: Node3D = STASH.new()
	lying.weapon = data
	lying.rounds = int(dropped[1])
	lying.dropped = true
	lying.stand = stand
	lying.back = float(_special_numbers.back)
	_game.add_child(lying)
	lying.global_position = Vector3(at.x, Fx.floor_below(at + Vector3.UP * 0.5), at.z)
	lying.taken.connect(_on_special_taken.bind(lying))


func _entrant_of(body: Node3D) -> Entrant:
	for who: Entrant in entrants.values():
		if who.body == body:
			return who
	return null


## Who plays: [number, name, side, weapon] for each, the weapon of a bot or
## -1 for a person. The bots get their bodies here, on every machine.
func _show_roster(roster: Array) -> void:
	entrants.clear()
	tally = [0, 0]
	stuck = 0
	for line: Array in roster:
		var who := Entrant.new()
		who.id = line[0]
		who.title = line[1]
		who.team = line[2]
		who.bot = who.id < 0
		who.weapon = maxi(line[3], 0)
		entrants[who.id] = who
	var own := me()
	var cast := 0
	for who: Entrant in entrants.values():
		if who.bot:
			var puppet: CharacterBody3D = (load(PUPPET) as PackedScene).instantiate()
			puppet.id = who.id
			puppet.title = who.title
			puppet.name = "Bot%d" % -who.id
			puppet.driven = not Net.is_guest()
			_game.add_child(puppet)
			# Whoever is against the player is who the enemies were chosen to
			# be; with nobody playing, that is the second side.
			var look := {}
			if (mode.hostile(own, who) if own else who.team == 1 or not mode.teams()):
				look = _look(cast)
				cast += 1
			puppet.enlist(who.team if mode.teams() else absi(who.id) % 2, _layers(who), _foes(who), own != null and not mode.hostile(own, who), who.weapon, look)
			who.body = puppet
			if puppet.driven:
				who.brain = (load(BOT) as GDScript).new()
				who.brain.me = who
				puppet.add_child(who.brain)
		elif who.id == Net.id():
			who.body = _game.player
			_game.player.team = who.team
			_game.player.collision_layer |= _layers(who)
			_game.player.collision_mask |= _foes(who)
		else:
			who.body = _game.puppets.get(who.id)
		if who.body:
			who.body.set_meta(&"entrant", who.id)
	changed.emit()


## What the `place`th of those against the player looks and sounds like, as
## the enemies that were chosen in the settings: {character, voice, tint}, or
## {robot} with the kind of robot of scripts/puppet.gd. Empty for soldiers,
## who are the second side as it is. Whatever they are, they carry a weapon
## of the loadout and move as everybody does: a robot fires it from its arm,
## and the one that fights with blades on the route is a grunt here.
func _look(place: int) -> Dictionary:
	var theme: String = Settings.enemy_theme
	if theme == "soldiers" or theme == "soldiers_desert":
		return {}
	if theme == THEMES.ROBOTS:
		return {"robot": "heavy" if FIGURES[place % FIGURES.size()] == "heavy" else "grunt"}
	var found: Dictionary = THEMES.cast(theme, FIGURES[place % FIGURES.size()], place)
	return {"character": found.character, "voice": found.voice, "tint": found.tint} if found else {}


## Health that mends lies in a few places in the arena, and is back a while
## after somebody took it: sparingly, or nobody would ever be short of it.
func _tend_cells() -> void:
	for cell in _cells:
		if is_instance_valid(cell.cell):
			continue
		if cell.cell != null:
			# It was taken.
			cell.cell = null
			cell.due = _clock + float(_cell_numbers.get("back", 45.0))
		elif _clock >= float(cell.due):
			var made: Node3D = _game.leave(PICKUP.Kind.HEALTH, (cell.at as Vector3) + Vector3.UP * 0.9)
			made.stays = true
			cell.cell = made


## The layers an entrant is on, and those of who is against it. Without
## sides everybody is on the one layer, and a shot leaves out whoever fired.
func _layers(who: Entrant) -> int:
	return SIDES[who.team] if mode.teams() else SIDES[0]


func _foes(who: Entrant) -> int:
	return SIDES[1 - who.team] if mode.teams() else SIDES[0]


## Where the bots are, for the other machines to show.
func _tell_bots() -> void:
	if not Net.active or Net.present.size() < 2:
		return
	var states := []
	for who: Entrant in entrants.values():
		if who.brain:
			states.append(who.id)
			states.append_array(who.brain.net_state())
	Net.tell(self, &"_move_bots", [states], false)


func _move_bots(states: Array) -> void:
	for i in range(0, states.size(), 7):
		var who: Entrant = entrants.get(states[i])
		if who and is_instance_valid(who.body):
			who.body.net_state(states[i + 1], states[i + 2], states[i + 3], states[i + 4], states[i + 5], states[i + 6])


## Lets go of the level and of everybody in it.
func _forget() -> void:
	entrants.clear()
	tally = [0, 0]
	arena = null
	_game = null
	_cells.clear()
	_stands.clear()
	_baked = false
	left = 0.0


func _unhandled_input(event: InputEvent) -> void:
	# Enter, and not whatever accepts in a menu: the space bar does, and jumps.
	var key := event as InputEventKey
	if state == State.OVER and key and key.pressed and not key.echo and (key.physical_keycode == KEY_ENTER or key.physical_keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		again()
