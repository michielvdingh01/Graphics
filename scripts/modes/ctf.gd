extends "res://scripts/modes/mode.gd"
## Capture the flag: each side has a prize on a stand at its own end (see
## scripts/prize.gd: a flag, a football, a banana), and scores by bringing
## the other side's prize to its own stand while its own prize stands there.
## Walking into the other side's prize takes it. Whoever carries it drops it
## when they go down; the side it belongs to brings it home by touching it,
## and after a while it goes home by itself. Kills count for nobody's score,
## and whoever comes back does so on the ground of their own base.
##
## The bots of a side share the work, by the order they joined in: some go
## and fetch, some keep to their own stand, one goes where the fight is.
## Whoever has the prize runs home with it and does not stop to fight; if
## their own prize lies somewhere, the nearest of them goes and gets it; and
## if somebody is running off with it, those who are not fetching go after
## that one. This is the first cut of it: nobody takes cover or waits for the
## others, and what the player does changes nothing about who does what.

## Where a prize is, as scripts/prize.gd numbers it.
enum { HOME, CARRIED, DOWN }
## What a bot is there for.
enum { FETCH, GUARD, ROAM }

const PRIZE := "res://scenes/prize.tscn"
## The side of this machine's player and the other, as the HUD has them.
const OURS := Color(0.1, 0.34, 0.85)
const THEIRS := Color(0.95, 0.42, 0.06)
## The same two for what is written over a prize: lighter, to be read against
## a wall or a window.
const MARK_OURS := Color(0.45, 0.72, 1.0, 0.9)
const MARK_THEIRS := Color(1.0, 0.66, 0.3, 0.9)
## Who does what, in the order the bots of a side joined.
const JOBS: Array[int] = [FETCH, GUARD, FETCH, ROAM, FETCH, GUARD]
## How far from its own stand somebody comes back, in metres to walk: no
## nearer than the one, no further than the other.
const BASE := Vector2(6.0, 25.0)
## How far from the stand a guard keeps, in metres to walk.
const POST := Vector2(4.0, 12.0)
## How near somebody has to stand to a prize or a stand to touch it, in
## metres over the floor and in height. A prize says who is in reach of it,
## but goes on saying so for a moment of somebody who was put elsewhere: of
## the player, who went down next to it and has just come back at their base.
const NEAR := Vector2(1.7, 2.5)

## The prize of either side; the node is its stand.
var prizes: Array[Node3D] = [null, null]

var _spots: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
var _posts: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
var _labels: Array[Label3D] = [null, null]


func begin() -> void:
	var arena: RefCounted = host.arena
	for side in 2:
		_spots[side] = arena.around(side, BASE.x, BASE.y)
		_posts[side] = arena.around(side, POST.x, POST.y)


## Where the two stands are.
func plan() -> Array:
	var arena: RefCounted = host.arena
	return [arena.spots[arena.ends[0]], arena.spots[arena.ends[1]]]


func set_out(stands: Array) -> void:
	var mine: int = host.me().team if host.me() else 0
	for side in 2:
		var prize: Node3D = (load(PRIZE) as PackedScene).instantiate()
		prize.kind = str(host.setup.get("prize", "flag"))
		# One made on the host, that never reached this machine.
		if prize.spec(prize.kind).is_empty():
			prize.kind = "flag"
		prize.team = side
		prize.tint = OURS if side == mine else THEIRS
		prize.name = "Prize%d" % side
		prize.position = stands[side]
		host.level().add_child(prize)
		prizes[side] = prize
		# Where it is can be read through walls, in the colour of its side.
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = 0.0006
		label.font_size = 40
		label.outline_size = 10
		prize.add_child(label)
		_labels[side] = label
		_mark(side, mine)


## Says over the prize of `side` whose it is, to this machine's player.
func _mark(side: int, mine: int) -> void:
	var label := _labels[side]
	label.text = "YOURS" if side == mine and host.me() else "THEIRS" if host.me() else "SIDE %d" % (side + 1)
	label.modulate = MARK_OURS if side == mine else MARK_THEIRS


func sides_changed() -> void:
	var mine: int = host.me().team if host.me() else 0
	for side in 2:
		if is_instance_valid(prizes[side]):
			prizes[side].dress(side, OURS if side == mine else THEIRS)
			_mark(side, mine)


func watch() -> void:
	for side in 2:
		if is_instance_valid(prizes[side]):
			_labels[side].global_position = prizes[side].where() + Vector3.UP * 2.3


## For either side where its prize is, who has it and how long it has lain.
func how_it_stands() -> Array:
	var how := []
	for side in 2:
		var prize := prizes[side]
		if is_instance_valid(prize):
			how.append([prize.state, host.number(prize.carrier), prize.where(), prize.down_for])
	return how


func stand_as(how: Array) -> void:
	for side in mini(how.size(), 2):
		var prize := prizes[side]
		var line: Array = how[side]
		if line[0] == DOWN:
			prize.lie_at(line[2], line[3])
		elif line[0] == CARRIED:
			var who: RefCounted = host.entrants.get(line[1])
			if who and is_instance_valid(who.body):
				prize.take(who.body)


func tick(_delta: float) -> void:
	for side in 2:
		var prize := prizes[side]
		if not is_instance_valid(prize):
			continue
		if prize.state == DOWN and prize.down_for > float(numbers.get("returns", 20.0)):
			host.show_mode(&"_show_prize", [side, "home", 0])
		# Whoever stands on it or at the stand is asked again each time: what
		# they came for may only now be possible.
		for body: Node3D in prize.within_reach():
			_touch(side, body)
		for body: Node3D in prize.at_stand():
			_reach(side, body)


## Nobody scores by a kill.
func count(_killer: RefCounted, _fallen: RefCounted, _tally: Array[int]) -> void:
	pass


func fell(who: RefCounted) -> void:
	var side := carried_by(who)
	if side >= 0:
		host.show_mode(&"_show_prize", [side, "drop", who.id, who.body.global_position])


func come_back(who: RefCounted, foes: PackedVector3Array, friends: PackedVector3Array, watchers: PackedVector3Array) -> Transform3D:
	return host.arena.pick(foes, friends, _spots[who.team], watchers)


## The side whose prize `who` carries, -1 for none.
func carried_by(who: RefCounted) -> int:
	for side in 2:
		if is_instance_valid(prizes[side]) and prizes[side].state == CARRIED and prizes[side].carrier == who.body:
			return side
	return -1


func hurries(who: RefCounted) -> bool:
	return carried_by(who) >= 0


func wish(who: RefCounted) -> Variant:
	var own := prizes[who.team]
	var theirs := prizes[1 - who.team]
	if not is_instance_valid(own) or not is_instance_valid(theirs):
		return null
	if theirs.state == CARRIED and theirs.carrier == who.body:
		return own.global_position
	if own.state == DOWN and _nearest(who.team, own.where()) == who:
		return own.where()
	var job := _job(who)
	if own.state == CARRIED and job != FETCH:
		return own.where()
	match job:
		FETCH:
			# To where it stands or lies, or along with whoever has it.
			return theirs.where()
		GUARD:
			var posts := _posts[who.team]
			return host.arena.spots[posts[absi(who.id) % posts.size()]] if not posts.is_empty() else own.global_position
	return null


func status(me: RefCounted) -> String:
	var lines := PackedStringArray()
	var sides: Array = [1 - me.team, me.team] if me else [0, 1]
	for side: int in sides:
		var prize := prizes[side]
		if not is_instance_valid(prize):
			continue
		var whose := ("YOUR %s" if side == me.team else "THEIR %s") if me else "SIDE %d'S %%s" % (side + 1)
		var how := "at home"
		if prize.state == CARRIED:
			var carrier: RefCounted = host.entrants.get(host.number(prize.carrier))
			how = "with you: bring it home" if carrier == me and me else "with %s" % (carrier.title if carrier else "somebody")
		elif prize.state == DOWN:
			how = "on the ground, going home in %d" % ceili(float(numbers.get("returns", 20.0)) - prize.down_for)
		var far := ""
		if me and is_instance_valid(me.body):
			far = "   ·   %d m" % roundi(me.body.global_position.distance_to(prize.where()))
		lines.append("%s   ·   %s%s" % [whose % prize.title().to_upper(), how, far])
	return "\n".join(lines)


## Somebody is within reach of the prize of `side`: one of the other side
## takes it, one of its own brings it home if it lies somewhere.
func _touch(side: int, body: Node3D) -> void:
	var who: RefCounted = host.entrants.get(host.number(body))
	var prize := prizes[side]
	if who == null or who.out > 0.0 or not host.playing() or prize.state == CARRIED or not _near(body, prize.where()):
		return
	if who.team != side:
		host.show_mode(&"_show_prize", [side, "take", who.id])
	elif prize.state == DOWN:
		host.show_mode(&"_show_prize", [side, "home", who.id])


## Somebody is at the stand of `side`: one of that side who has the other
## prize scores with it, if their own stands there.
func _reach(side: int, body: Node3D) -> void:
	var who: RefCounted = host.entrants.get(host.number(body))
	if who == null or who.team != side or who.out > 0.0 or not host.playing() or not _near(body, prizes[side].global_position):
		return
	var other := prizes[1 - side]
	if other.state == CARRIED and other.carrier == body and prizes[side].state == HOME:
		host.show_mode(&"_show_prize", [1 - side, "capture", who.id])


## What happens to the prize of `side`, on every machine: `who` takes it,
## drops it at `at`, brings it home (0 if it went by itself) or scores with it.
func _show_prize(side: int, what: String, id: int, at := Vector3.INF) -> void:
	var prize := prizes[side]
	var who: RefCounted = host.entrants.get(id)
	if not is_instance_valid(prize):
		return
	var name: String = who.title if who else ""
	match what:
		"take":
			if who and is_instance_valid(who.body):
				prize.take(who.body)
				host.say("%s has %s" % [name, prize.the()], &"pickup_grenade")
		"drop":
			prize.drop(at)
			host.say("%s dropped %s" % [name, prize.the()], &"")
		"home":
			prize.send_home()
			var the: String = prize.the()
			host.say("%s brought %s home" % [name, the] if who else "%s%s is back home" % [the.left(1).to_upper(), the.substr(1)], &"pickup_ammo")
		"capture":
			prize.send_home()
			if who:
				host.tally[who.team] += 1
				host.say("%s scored with %s" % [name, prize.the()], &"checkpoint")
			host.judge()


## True if `body` really stands at `at`.
func _near(body: Node3D, at: Vector3) -> bool:
	var gap := body.global_position - at
	return Vector2(gap.x, gap.z).length() < NEAR.x and absf(gap.y) < NEAR.y


## The bot of `side` that is nearest to `at` and standing.
func _nearest(side: int, at: Vector3) -> RefCounted:
	var best: RefCounted = null
	for who: RefCounted in host.entrants.values():
		if who.team == side and who.bot and who.out <= 0.0 and (best == null or who.body.global_position.distance_to(at) < best.body.global_position.distance_to(at)):
			best = who
	return best


## What `who` is there for: its place among the bots of its side says.
func _job(who: RefCounted) -> int:
	var place := 0
	for other: RefCounted in host.entrants.values():
		if other.bot and other.team == who.team and other.id > who.id:
			place += 1
	return JOBS[place % JOBS.size()]
