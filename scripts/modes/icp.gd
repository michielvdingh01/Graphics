extends "res://scripts/modes/mode.gd"
## Win the ICP, the match of the Unmuted build: two sides, Unmuted and the
## Slop Soldiers, each with a base at its end of the arena, and between them
## the ICP (scripts/icp_body.gd), a client who walks slowly to whatever draws
## him most. A side scores by drawing him to its own base. Kills count for
## nobody's score.
##
## What draws him are the stickers that are stuck on the level
## (scripts/stickers.gd): each draws for its side, less as it ages and less the
## further off it is, and not at all beyond `sees` metres (he sees through
## walls). Every THINKS seconds he adds up what draws him for either side, and
## of the side that draws him most he goes to the sticker that draws hardest.
## A sticker he has come within `passes` metres of he has seen: it draws no
## more. So a trail of stickers leads him, and he stands still where nothing
## draws him. Once he is within `scores` metres of the door of a base, that
## side has won him over: every sticker is gone, and he is back in the middle
## `back` seconds later.
##
## The bots of a side share the work, by the order they joined in: some lure
## him, stuck their stickers next to him on the side of their base; some lay a
## trail ahead of him to their base; and some hunt, and cover the stickers of
## the other side with their own. Those who lure or lay a trail turn on an
## enemy only when it is near.

## What a bot is there for.
enum { LURE, TRAIL, HUNT }

const STICKERS := preload("res://scripts/stickers.gd")
const WAY := preload("res://scripts/way.gd")
const BODY := preload("res://scripts/icp_body.gd")
const CTF := preload("res://scripts/modes/ctf.gd")
const JOBS: Array[int] = [LURE, TRAIL, HUNT, LURE, TRAIL, HUNT]
## The people of Unmuted, in black with the logo (tools/unmuted/build_people.sh);
## the Slop Soldiers are the soldiers, women among them, whatever the enemies
## of the route are.
const PEOPLE := "res://assets/characters/unmuted_%02d/unmuted_%02d.glb"
const PEOPLE_COUNT := 8
## The sleeve of the arms in front of the camera (tools/models/hands.py), one
## material for every weapon: black for whoever plays for Unmuted, and back
## as it was once the match is over.
const SLEEVE := "res://materials/sleeve.tres"
const BLACK_SLEEVE := Color(0.035, 0.035, 0.038)
## Seconds between two times he makes up his mind.
const THINKS := 0.5
## How far from him those who lure stand, and how far ahead of him on the way
## to their base they stick, in metres.
const LURE_AT := 5.0
const LURE_AHEAD := 3.5
## How far ahead of him on the way to their base those who lay a trail stand,
## and how far from where they stand they stick.
const TRAIL_AHEAD := 16.0
const TRAIL_STICKS := 3.0
## How near a bot has to be for what it sticks, in metres.
const STICKS_FROM := 14.0
## How far a hunter looks about it for a sticker of the other side to cover.
const COVERS := 22.0
## The bases while they are grey blocks: how big, and how far behind the door
## they stand, in metres. Step 4 of PLAN.md has the buildings.
const BLOCK := Vector3(10.0, 9.0, 8.0)
const BLOCK_TINT: Array[Color] = [Color(0.72, 0.72, 0.74), Color(0.08, 0.08, 0.09)]
const BLOCK_NAMES: Array[String] = ["UNMUTED HQ", "DOOMSCROLL HELL"]

var icp: CharacterBody3D
## The door of the base of either side, and the middle, where he begins.
var bases: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var middle := Vector3.ZERO
## The side whose sticker he is going to, -1 while nothing draws him.
var heading := -1
## Seconds until he is back after a side won him over; 0 while he is there.
var away := 0.0

var _spots: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
var _halves: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
var _think := 0.0
## The sticker he is going to, and for how long he has been.
var _lure := Vector3.INF
var _lure_for := 0.0
## The way from him to the base of either side, over the navmesh, as it was
## when he last made up his mind.
var _ways: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array()]
## The colour of the sleeve before this match made it black.
var _sleeve: Variant = null


func begin() -> void:
	var arena: RefCounted = host.arena
	var base := CTF.ground(arena.length())
	for side in 2:
		_spots[side] = arena.forward(side, base.x, base.y, CTF.FORWARD)
		_halves[side] = arena.forward(side, CTF.CLEAR, arena.length() * 0.5, -CTF.BEHIND)


## The two doors and the middle: the spot that is as far to walk from either.
func plan() -> Array:
	var arena: RefCounted = host.arena
	var best := 0
	var least := INF
	for spot in arena.spots.size():
		var a: float = arena.walks[0][spot]
		var b: float = arena.walks[1][spot]
		var off := absf(a - b) + absf(a + b - arena.length())
		if off < least:
			least = off
			best = spot
	return [arena.spots[arena.ends[0]], arena.spots[arena.ends[1]], arena.spots[best]]


func set_out(plan: Array) -> void:
	bases = [plan[0], plan[1]]
	middle = plan[2]
	STICKERS.clear()
	for side in 2:
		_block(side)
	icp = BODY.new()
	icp.name = "ICP"
	icp.pace = float(numbers.get("pace", 1.3))
	host.level().add_child(icp)
	icp.global_position = middle
	icp.rotation.y = _facing(middle, bases[0])
	# Drawn once now, rather than when the first banknote falls.
	Fx.rehearse(icp.looks())
	_dress_sleeve()
	if not host.changed.is_connected(_dress_sleeve):
		host.changed.connect(_dress_sleeve)


## The sleeve in front of the camera black while this machine's player plays
## for Unmuted, and as it was otherwise.
func _dress_sleeve() -> void:
	var sleeve := load(SLEEVE) as ShaderMaterial
	if sleeve == null:
		return
	if _sleeve == null:
		_sleeve = sleeve.get_shader_parameter(&"color")
	var own: RefCounted = host.me() if host.active else null
	sleeve.set_shader_parameter(&"color", BLACK_SLEEVE if own and own.team == 0 and host.mode == self else _sleeve)
	if (not host.active or host.mode != self) and host.changed.is_connected(_dress_sleeve):
		host.changed.disconnect(_dress_sleeve)


func sides_changed() -> void:
	_dress_sleeve()


## The base of `side` as a grey block for now, behind its door with its front
## to the middle, and its name on the front.
func _block(side: int) -> void:
	var out := middle - bases[side]
	out.y = 0.0
	out = out.normalized() if out.length_squared() > 0.01 else Vector3.FORWARD
	var body := StaticBody3D.new()
	body.name = "Base%d" % side
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = BLOCK
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = BLOCK
	var look := StandardMaterial3D.new()
	look.albedo_color = BLOCK_TINT[side]
	look.roughness = 0.8
	mesh.material_override = look
	body.add_child(mesh)
	var sign := Label3D.new()
	sign.text = BLOCK_NAMES[side]
	sign.font_size = 160
	sign.pixel_size = 0.006
	sign.outline_size = 0
	sign.modulate = Color(1.0, 0.2, 0.15) if side == 1 else Color(0.05, 0.05, 0.05)
	# On the front, its +Z, which a Label3D faces of itself.
	sign.position = Vector3(0.0, BLOCK.y * 0.25, BLOCK.z * 0.5 + 0.05)
	body.add_child(sign)
	host.level().add_child(body)
	# Sunk a little, for a floor that is not flat.
	body.global_position = bases[side] - out * (BLOCK.z * 0.5 + 2.0) + Vector3.UP * (BLOCK.y * 0.5 - 0.6)
	# Its back, -Z, away from the middle.
	body.rotation.y = _facing(bases[side], bases[side] - out)


## The turn about the vertical that has -Z of something at `from` look at `to`.
static func _facing(from: Vector3, to: Vector3) -> float:
	var way := to - from
	return atan2(-way.x, -way.z)


func watch() -> void:
	pass


func how_it_stands() -> Array:
	if not is_instance_valid(icp):
		return []
	return [icp.visible, icp.global_position, heading]


func stand_as(how: Array) -> void:
	if how.size() < 3 or not is_instance_valid(icp):
		return
	if how[0]:
		icp.appear(how[1])
	else:
		icp.vanish()
	heading = how[2]


func tick(delta: float) -> void:
	if not is_instance_valid(icp):
		return
	STICKERS.advance(delta)
	if away > 0.0:
		away -= delta
		if away <= 0.0:
			host.show_mode(&"_show_back", [middle])
		return
	_think -= delta
	if _think <= 0.0:
		_think = THINKS
		_decide()
		var map := icp.get_world_3d().navigation_map
		for side in 2:
			_ways[side] = WAY.between(map, icp.global_position, bases[side])
	for side in 2:
		var gap := icp.global_position - bases[side]
		if Vector2(gap.x, gap.z).length() < float(numbers.get("scores", 8.0)) and absf(gap.y) < 4.0:
			host.show_mode(&"_show_won", [side])
			break


## What draws him, every sticker and every dance that does: [where, the side,
## how much], as Stickers.lures() has it.
func pulls() -> Array:
	return STICKERS.lures()


## Makes up his mind where to go, see the top of this file.
func _decide() -> void:
	var at := icp.global_position
	var sees := float(numbers.get("sees", 40.0))
	var passes := float(numbers.get("passes", 2.0))
	STICKERS.seen(at, passes)
	var sums := [0.0, 0.0]
	var best: Array = [Vector3.INF, Vector3.INF]
	var hardest := [0.0, 0.0]
	for lure: Array in pulls():
		var side: int = lure[1]
		if side < 0 or side > 1:
			continue
		var far := at.distance_to(lure[0])
		if far > sees:
			continue
		var draw: float = float(lure[2]) * (1.0 - 0.5 * far / sees)
		sums[side] += draw
		if draw > hardest[side]:
			hardest[side] = draw
			best[side] = lure[0]
	var side := -1
	if sums[0] > 0.0 or sums[1] > 0.0:
		side = 0 if sums[0] > sums[1] else 1 if sums[1] > sums[0] else maxi(heading, 0)
	if side != heading:
		host.show_mode(&"_show_heading", [side])
	if side < 0:
		icp.goal = Vector3.INF
		_lure = Vector3.INF
		return
	var target: Vector3 = best[side]
	if target != _lure:
		_lure = target
		_lure_for = 0.0
	_lure_for += THINKS
	var gap := target - at
	# Once he is there, or as near as the floor lets him, he has seen it; and
	# one he does not get to, he gives up on.
	if Vector2(gap.x, gap.z).length() < passes + 0.5 or (icp.arrived() and _lure_for > 1.0) or _lure_for > float(numbers.get("gives_up", 15.0)):
		STICKERS.seen(target, passes)
	icp.goal = target


func _show_heading(side: int) -> void:
	heading = side


## `side` has won him over, on every machine.
func _show_won(side: int) -> void:
	host.tally[side] += 1
	host.say("%s won the ICP over" % host.side_name(side), &"checkpoint")
	STICKERS.clear()
	heading = -1
	_lure = Vector3.INF
	if is_instance_valid(icp):
		icp.vanish()
	away = float(numbers.get("back", 5.0))
	host.judge()


## He is back, standing at `at`.
func _show_back(at: Vector3) -> void:
	away = 0.0
	STICKERS.clear()
	if is_instance_valid(icp):
		icp.appear(at)
	host.say("The ICP is back in the middle", &"pickup_ammo")


func look(who: RefCounted) -> Variant:
	if who.team != 0:
		return {}
	var number: int = absi(who.id) % PEOPLE_COUNT + 1
	var path := PEOPLE % [number, number]
	return {"character": load(path)} if ResourceLoader.exists(path) else {}


## Nobody scores by a kill.
func count(_killer: RefCounted, _fallen: RefCounted, _tally: Array[int]) -> void:
	pass


func come_back(who: RefCounted, foes: PackedVector3Array, friends: PackedVector3Array, watchers: PackedVector3Array) -> Transform3D:
	return host.arena.pick(foes, friends, _spots[who.team], watchers, _halves[who.team])


## Those who lure him or lay his trail turn only on an enemy that is near.
func hurries(who: RefCounted) -> bool:
	return _job(who) != HUNT and _here()


func wish(who: RefCounted) -> Variant:
	if not _here():
		return middle if _job(who) != HUNT else null
	var at := icp.global_position
	match _job(who):
		LURE:
			return along(who.team, LURE_AT) + _aside(who) * 1.5
		TRAIL:
			return _trail_spot(who)
		HUNT:
			var cover: Variant = _theirs_near(who.team, at, float(numbers.get("sees", 40.0)))
			return cover if cover != null else at
	return null


## Where a bot of `who` should stick a sticker now, if anywhere, for
## scripts/bot.gd: next to him, along his trail, or on a sticker of the other
## side.
func plaster(who: RefCounted) -> Variant:
	if not _here() or not is_instance_valid(who.body):
		return null
	var me: Vector3 = who.body.global_position
	var at := icp.global_position
	match _job(who):
		LURE:
			if me.distance_to(at) < STICKS_FROM:
				return along(who.team, LURE_AHEAD) + _aside(who) * randf_range(-1.0, 1.0) + Vector3.UP * 0.1
		TRAIL:
			var spot := _trail_spot(who)
			if me.distance_to(spot) < 6.0:
				return along(who.team, TRAIL_AHEAD - TRAIL_STICKS) + _aside(who) * randf_range(-1.0, 1.0) + Vector3.UP * 0.1
		HUNT:
			return _theirs_near(who.team, me, COVERS)
	return null


## True while he is in the arena.
func _here() -> bool:
	return is_instance_valid(icp) and away <= 0.0 and icp.visible


## The spot `metres` along his way to the base of `side`, or the base if
## that is nearer.
func along(side: int, metres: float) -> Vector3:
	var way := _ways[side]
	if way.size() < 2:
		return bases[side]
	var left := metres
	for i in way.size() - 1:
		var step := way[i].distance_to(way[i + 1])
		if step >= left:
			return way[i].lerp(way[i + 1], left / step)
		left -= step
	return way[-1]


## A way to the side that is the same for a bot every time, and differs
## between bots: they do not all stand in one place.
func _aside(who: RefCounted) -> Vector3:
	var turn := float(absi(who.id) % 7) / 7.0 * TAU
	return Vector3(cos(turn), 0.0, sin(turn))


## Where `who` lays his trail: ahead of him, on his way to its base.
func _trail_spot(who: RefCounted) -> Vector3:
	return along(who.team, TRAIL_AHEAD) + _aside(who) * 1.5


## The sticker of the other side of `side` that draws hardest within `reach`
## of `at`, or null.
func _theirs_near(side: int, at: Vector3, reach: float) -> Variant:
	var best: Variant = null
	var most := 0.0
	for lure: Array in STICKERS.lures():
		if lure[1] != side and lure[1] >= 0 and at.distance_to(lure[0]) < reach and float(lure[2]) > most:
			most = lure[2]
			best = lure[0]
	return best


## What `who` is there for: its place among the bots of its side says.
func _job(who: RefCounted) -> int:
	var place := 0
	for other: RefCounted in host.entrants.values():
		if other.bot and other.team == who.team and other.id > who.id:
			place += 1
	return JOBS[place % JOBS.size()]


func status(me: RefCounted) -> String:
	if not is_instance_valid(icp):
		return ""
	if away > 0.0:
		return "THE ICP   ·   back in the middle in %d" % ceili(away)
	var how := "standing: nothing draws him"
	if heading >= 0:
		how = "drawn to your stickers" if me and heading == me.team else "drawn to the stickers of %s" % host.side_name(heading)
	var lines := PackedStringArray(["THE ICP   ·   %s" % how])
	var sides: Array = [me.team, 1 - me.team] if me else [0, 1]
	var far := PackedStringArray()
	for side: int in sides:
		var gap := icp.global_position.distance_to(bases[side])
		far.append("%s %d m" % ["YOUR BASE" if me and side == me.team else BLOCK_NAMES[side], roundi(gap)])
	lines.append("   ·   ".join(far))
	return "\n".join(lines)
