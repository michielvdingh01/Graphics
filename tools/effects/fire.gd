extends RefCounted
## Fire that spreads: a stack of crates, a cardboard box and a pile of
## pallets catch from a fire beside them, each after its own while and not
## before, burn, and are gone or burnt after that; what is out of reach does
## not catch, no more burn at once than may, a guest lights nothing, and in
## the end nothing is left burning.
##
## It is timed in physics frames, which is the clock the fires run on, and
## the game runs a few times as fast as it is played for it, so that half a
## minute of burning is over in ten seconds.

## How many times as fast the game runs while this looks at it.
const HASTE := 3.0
## Seconds a catch or a burning out may come later than the time set for it:
## a tick of the fires, and a frame or two.
const LATE := 0.35
## Seconds the end of a fire may be off, which is seen a step after it came:
## two steps of the game as fast as it runs here.
const FRAMES := 0.1


func run(test: SceneTree) -> void:
	var game: Node = await test.level()
	var blast: Node = test.autoload("Blast")
	var fx: Node = test.autoload("Fx")
	var breakables: Node = game.get_node("Level/Breakables")
	var stack_script: GDScript = breakables.STACK
	var stacks: Array = breakables.get_children().filter(func(body: Node) -> bool: return body.has_method("cover"))
	var piles: Array = breakables.get_children().filter(func(body: Node) -> bool: return body.has_method("pallets"))
	var tinder: Array = stacks + piles

	# What there is to burn, and what is drawn of it for the first time.
	test.check(piles.size() == 5 and piles.all(func(pile: Node) -> bool: return pile.pallets() >= 1 and not pile.has_method("cover") and not pile.has_method("lens")),
		"the factory has five piles of pallets, which are neither stacks nor lamps")
	var named := true
	for i in piles.size():
		named = named and piles[i].name == "Pallets%d" % i
	test.check(named, "they are named in the order of the level")
	test.check(tinder.all(func(thing: Node) -> bool: return thing.is_in_group(blast.TINDER) and thing.girth > 0.0), "every stack and every pile can catch fire")
	var sooted: Array = stack_script._sooted.values()
	test.check(fx._bursts.has(fx._blaze) and breakables._looks.any(func(look: MeshInstance3D) -> bool: return sooted.has(look.get_surface_override_material(0))),
		"the flames on what burns and the charred boards are drawn once while the level loads")

	# How far a fire reaches, by the numbers.
	var patch := {"at": Vector3.ZERO, "flames": 0.5, "tall": 1.0}
	var crate := AABB(Vector3(-0.25, 0.0, -0.5), Vector3(0.5, 0.4, 1.0))
	var beside: float = blast.heat(patch, Transform3D(Basis(), Vector3(-0.7, 0.0, 0.0)), crate)
	var near_edge: float = blast.heat(patch, Transform3D(Basis(), Vector3(-0.75 - blast.REACH + 0.05, 0.0, 0.0)), crate)
	var past_edge: float = blast.heat(patch, Transform3D(Basis(), Vector3(-0.75 - blast.REACH - 0.05, 0.0, 0.0)), crate)
	var above: float = blast.heat(patch, Transform3D(Basis(), Vector3(-0.7, -0.5, 0.0)), crate)
	var over_top: float = blast.heat(patch, Transform3D(Basis(), Vector3(-0.7, -1.05, 0.0)), crate)
	var under: float = blast.heat(patch, Transform3D(Basis(), Vector3(0.0, 0.4, 0.0)), crate)
	var deep: float = blast.heat(patch, Transform3D(Basis(), Vector3(0.0, 0.4 + blast.DEPTH + 0.1, 0.0)), crate)
	print("    heat of a fire on a crate: %.2f against it, %.2f at the end of its reach, %.2f half-way up its flames, %.2f under it" % [beside, near_edge, above, under])
	test.check(is_equal_approx(beside, 1.0) and near_edge > 0.0 and near_edge < 0.5 and past_edge == 0.0, "a fire heats what it touches most, what is at the end of its reach a little and what is beyond it not at all")
	test.check(above < beside and above > 0.0 and over_top == 0.0 and under > 0.0 and under < above and deep == 0.0, "what stands higher gets less of it, what is above its flames or far under it nothing")

	# A guest lights nothing by itself: a fire beside a cardboard box, three
	# ticks of it, and nothing is hot. It burns when the host says so, and is
	# no patch there, since only the host hurts and spreads.
	var lone: Array = stacks.filter(func(stack: Node) -> bool: return stack.size() == 1 and stack._members[0].kind == stack.Kind.CARTON)
	var carton: Node = lone[0]
	var pile: Node3D = piles[0]
	for other: Node3D in piles:
		if other.pallets() > pile.pallets():
			pile = other
	var other_pile: Node3D = piles.filter(func(other: Node3D) -> bool: return other != pile)[0]
	var net: Node = test.autoload("Net")
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 1)
	test.get_multiplayer().multiplayer_peer = peer
	net.active = true
	var as_guest: bool = net.is_guest()
	blast.burn(_beside(carton, tinder, 0.3), 0.9, 5.0)
	for tick in 3:
		blast._tick = 0.0
		blast._physics_process(blast.BURN_TICK)
	var cold: bool = carton._members[0].heat == 0.0
	carton.warm({"at": carton.global_position, "flames": 1.0, "tall": 2.0}, 10.0)
	other_pile.warm({"at": other_pile.global_position, "flames": 1.0, "tall": 3.0}, 10.0)
	var untouched: bool = cold and carton.burning() == 0 and not other_pile.alight
	carton._catch(1)
	var told: bool = carton.burning() == 1 and is_instance_valid(carton._flames[0]) and blast.alight() == 0
	blast.clear()
	net.active = false
	peer.close()
	test.get_multiplayer().multiplayer_peer = OfflineMultiplayerPeer.new()
	test.check(as_guest and untouched, "a guest lights nothing by itself")
	test.check(told and not net.is_guest(), "and shows what the host says burns, without a patch of its own")

	# From here on the clock runs. A fire beside the lowest crate of a stack of
	# three, one beside the pile of pallets, one beside two cardboard boxes,
	# and one near another stack that is just out of reach of it.
	Engine.time_scale = HASTE
	var threes: Array = stacks.filter(func(body: Node) -> bool: return body.size() == 3 and body._colliders.size() == 1)
	threes.sort_custom(func(a: Node3D, b: Node3D) -> bool: return _neighbours(a, stacks) < _neighbours(b, stacks))
	var stack: Node3D = threes[0]
	var crates: Array = stack._members
	var apart: Node3D = threes.filter(func(other: Node3D) -> bool: return other != stack and _neighbours(other, [stack]) == 0)[0]
	var boxes: Node3D = stacks.filter(func(body: Node) -> bool: return body.size() == 2 and body._members[0].kind == body.Kind.CARTON and _neighbours(body, stacks) == 0)[0]
	var crate_time: Dictionary = stack.TUNING[stack.Kind.CRATE]
	var carton_time: Dictionary = stack.TUNING[stack.Kind.CARTON]
	var began := Engine.get_physics_frames()
	# When each of these was first so, in seconds since the fires were lit,
	# and the most fires there were at once. While `full` is set, the fires
	# that may burn are made up to as many as may with ones that light nothing.
	var watched := {
		"box": func() -> bool: return boxes._members[0].alight,
		"box gone": func() -> bool: return boxes._members[0].gone,
		"pile": func() -> bool: return pile.alight,
		"pile out": func() -> bool: return pile.burnt,
		"crate": func() -> bool: return crates[0].alight,
		"crate gone": func() -> bool: return crates[0].gone,
	}
	var seen := {}
	var most := [0]
	var full := [false]
	var fillers: Array[Dictionary] = []
	var watch := func() -> void:
		most[0] = maxi(most[0], blast.alight())
		while full[0] and blast.room():
			fillers.append(blast.kindle(Vector3(0.0, -50.0, 0.0), 0.3, 0.5, 30.0))
		for what: String in watched:
			if not seen.has(what) and (watched[what] as Callable).call():
				seen[what] = _seconds(began)
	test.physics_frame.connect(watch)
	blast.burn(_beside(stack, tinder, 0.5), 1.3, 2.2)
	blast.burn(_beside(pile, tinder, 0.5), 1.3, 2.2)
	blast.burn(_beside(boxes, tinder, 0.3), 0.9, 1.5)
	blast.burn(_beside(apart, tinder, 0.65 + blast.REACH + 0.3), 1.3, 1.0)

	await _until(test, func() -> bool: return seen.has("box"), 2.0)
	test.check(seen.get("box", -1.0) >= carton_time.catches and seen.get("box", 99.0) <= carton_time.catches + LATE, "cardboard catches at once (%.2f s)" % seen.get("box", -1.0))
	await _until(test, func() -> bool: return seen.has("pile"), 4.0)
	test.check(seen.get("pile", -1.0) >= pile.CATCHES and seen.get("pile", 99.0) <= pile.CATCHES + LATE, "a pile of pallets catches after %.1f s of fire beside it and not before (%.2f s)" % [pile.CATCHES, seen.get("pile", -1.0)])
	test.check(is_instance_valid(pile._flames) and pile.net_state() == 0 and blast.burning(pile.global_position), "it burns, and is a patch that Blast.burning() knows")

	await _until(test, func() -> bool: return seen.has("crate"), 4.0)
	test.check(seen.get("crate", -1.0) >= crate_time.catches and seen.get("crate", 99.0) <= crate_time.catches + LATE,
		"the nearest crate of a stack catches after %.1f s and not before (%.2f s)" % [crate_time.catches, seen.get("crate", -1.0)])
	test.check(not crates[1].alight and not crates[2].alight, "the crates on it do not burn yet")
	var flames: Node3D = stack._flames[0]
	var box: Vector3 = flames.get_instance_shader_parameter(&"box") if is_instance_valid(flames) else Vector3.ZERO
	test.check(is_equal_approx(box.y, crates[0].height) and is_equal_approx(box.x, stack._colliders[0].shape.size.x), "its flames are as large as the crate that burns")
	# The box the guest was told of burns without a patch, and is not counted.
	var burning := 0
	for body: Node in stacks:
		burning += body._patches.filter(func(fire: Dictionary) -> bool: return not fire.is_empty()).size()
	test.check(crates[0].charring.size() > 0 and blast.alight() == burning + 1 and burning >= 2, "it goes black in a material of its own, and every stack that burns is one fire in Blast's count")
	test.check(apart.burning() == 0 and apart._members.all(func(member: RefCounted) -> bool: return member.heat == 0.0), "a stack out of reach of a fire does not get hot")

	# The fuel is out; what burns now are the crate, the boxes and the pile.
	await _until(test, func() -> bool: return _seconds(began) > 2.4, 4.0)
	var middle: Vector3 = stack._colliders[0].global_position * Vector3(1, 0, 1) + Vector3.UP * stack.global_position.y
	test.check(blast.fires().all(func(fire: Dictionary) -> bool: return fire.has("tinder")) and blast.burning(middle) and not blast.burning(middle + Vector3(3.0, 0.0, 0.0)),
		"a burning crate is a patch that Blast.burning() knows, when the fuel beside it is out")

	# The cap: with as many fires as may burn, a crate that is hot enough
	# waits, and catches when there is room again.
	full[0] = true
	blast.burn(_beside(apart, tinder, 0.5), 1.3, 6.0)
	await test.wait(crate_time.catches + 1.0)
	test.check(blast.alight() == blast.MAX_ALIGHT and apart.burning() == 0 and apart._members[0].heat >= crate_time.catches,
		"with %d fires burning a crate that is hot enough does not catch" % blast.MAX_ALIGHT)
	full[0] = false
	for filler in fillers:
		filler.left = 0.0
	var turn: float = await _until(test, func() -> bool: return apart.burning() > 0, 2.0)
	test.check(turn >= 0.0 and turn <= LATE, "and catches when one of them is out (%.2f s)" % turn)
	var box_burnt: float = seen.get("box gone", -1.0) - seen.get("box", 0.0)
	test.check(absf(box_burnt - carton_time.burns) <= FRAMES and boxes.standing() == 0, "the cardboard has burnt away meanwhile, in %.1f s (%.2f s)" % [carton_time.burns, box_burnt])

	# The first crate burns through, and what stood on it comes down burning.
	await _until(test, func() -> bool: return seen.has("crate gone"), crate_time.burns + 3.0)
	var burnt_for: float = seen.get("crate gone", -1.0) - seen.get("crate", 0.0)
	test.check(absf(burnt_for - crate_time.burns) <= FRAMES, "the crate breaks when it has burnt for %.1f s (%.2f s)" % [crate_time.burns, burnt_for])
	await test.wait(0.6)
	test.check(not crates[0].model.visible and crates[1].alight and crates[2].alight and is_equal_approx(crates[1].sunk, crates[0].height) and is_equal_approx(crates[2].sunk, crates[0].height),
		"what stood on it comes down and burns on")
	flames = stack._flames[0]
	test.check(is_instance_valid(flames) and is_equal_approx(flames.global_position.y, stack.global_position.y) and stack.standing() == 2, "with its flames, on the floor now")
	var charred := false
	for piece: Variant in stack_script._pieces:
		if is_instance_valid(piece) and stack_script._sooted.values().has((piece.get_child(1) as MeshInstance3D).get_surface_override_material(0)):
			charred = true
	test.check(charred, "its boards are black")

	# The pile burns out, is burnt, and stays so. Another pile is told that
	# it burnt before anybody was there.
	await _until(test, func() -> bool: return seen.has("pile out"), pile.burns() + 4.0)
	var pile_burnt_for: float = seen.get("pile out", -1.0) - seen.get("pile", 0.0)
	test.check(pile.burnt and absf(pile_burnt_for - pile.burns()) <= FRAMES, "the pile of %d pallets burns for %.1f s (%.2f s)" % [pile.pallets(), pile.burns(), pile_burnt_for])
	await test.frames(3)
	test.check(not pile.alight and not is_instance_valid(pile._flames) and pile.net_state() == 1, "then it is out, and burnt")
	pile.warm({"at": pile.global_position, "flames": 1.0, "tall": 3.0}, 10.0)
	test.check(not pile.alight and pile.burnt, "and cannot catch again")
	var before: int = other_pile.net_state()
	other_pile.net_restore(1)
	other_pile.warm({"at": other_pile.global_position, "flames": 1.0, "tall": 3.0}, 10.0)
	test.check(before == 0 and other_pile.burnt and other_pile.net_state() == 1 and not other_pile.alight, "a pile that burnt before somebody came is burnt for them, and does not catch")

	# Nothing burns for ever.
	var out: float = await _until(test, func() -> bool: return blast.fires().is_empty() and _flames(game, fx) == 0, 60.0)
	print("    everything was out %.1f s after the first fire; at most %d things burnt at once" % [_seconds(began), most[0]])
	test.check(out >= 0.0 and tinder.all(func(thing: Node) -> bool: return (thing.burning() == 0) if thing.has_method("cover") else not thing.alight), "after a while nothing burns and no flame is left")
	test.check(most[0] > 0 and most[0] <= blast.MAX_ALIGHT, "there were never more than %d fires on crates, boxes and pallets" % blast.MAX_ALIGHT)
	test.physics_frame.disconnect(watch)

	# The fireball of an explosion lights what it leaves standing close by:
	# a pile of pallets two metres from it, and not one beyond its reach.
	# That one burns out like the other.
	var whole: Array = piles.filter(func(other: Node3D) -> bool: return not other.burnt)
	var close: Node3D = whole[0]
	var distant: Node3D = whole[1]
	blast.explode(_beside(close, tinder, 2.0) + Vector3.UP * 0.45, 6.5, 150.0)
	test.check(close.alight and not distant.alight and distant._heat == 0.0, "the fireball of an explosion lights a pile of pallets two metres away, and none out of its reach")
	out = await _until(test, func() -> bool: return blast.fires().is_empty() and _flames(game, fx) == 0, 30.0)
	test.check(out >= 0.0 and close.burnt, "and that burns out as well")

	# What Blast.burn() and Blast.burning() meant, they mean.
	var player: Node3D = test.get_first_node_in_group("player")
	var at: Vector3 = player.global_position
	var health: float = player.health
	blast.burn(at, 1.3, 1.0)
	var fuel: Array[Dictionary] = blast.fires()
	test.check(fuel.size() == 1 and fuel[0].at == at and is_equal_approx(fuel[0].radius, 1.1) and is_equal_approx(fuel[0].left, 1.0) and _flames(game, fx) == 1,
		"Blast.burn() is a patch as wide as the fuel and half a body more, and one fire to see")
	test.check(blast.burning(at) and blast.burning(at + Vector3(1.0, 0.0, 0.0)) and not blast.burning(at + Vector3(1.2, 0.0, 0.0)) and blast.burning(at + Vector3(2.0, 0.0, 0.0), 1.0)
		and not blast.burning(at + Vector3(2.2, 0.0, 0.0), 1.0) and not blast.burning(at + Vector3(0.0, 1.6, 0.0)), "Blast.burning() is true in it and within the margin of it, and nowhere else")
	await test.wait(1.3)
	var lost: float = health - player.health
	test.check(not blast.burning(at) and blast.fires().is_empty() and lost >= 6.0 and lost <= 15.0, "it burns the player who stands in it for as long as it lasts, and is gone (%.1f health)" % lost)
	Engine.time_scale = 1.0


## A spot on the floor `away` metres from the side of something that can
## catch fire, on the side where nothing else that can stands near.
func _beside(thing: Node3D, tinder: Array, away: float) -> Vector3:
	var size: Vector3 = thing._colliders[0].shape.size if thing.has_method("cover") else thing.size
	var frame: Transform3D = thing._frames[0] if thing.has_method("cover") else thing.global_transform
	var best := Vector3.ZERO
	var clear := -1.0
	for side: float in [-1.0, 1.0]:
		var spot := frame * Vector3(side * (size.x * 0.5 + away), 0.0, 0.0)
		var room := INF
		for other: Node3D in tinder:
			if other != thing:
				room = minf(room, other.global_position.distance_to(spot))
		if room > clear:
			clear = room
			best = spot
	return best


## How many other stacks stand within 3 m of one.
func _neighbours(thing: Node3D, stacks: Array) -> int:
	return stacks.filter(func(other: Node3D) -> bool: return other != thing and other.global_position.distance_to(thing.global_position) < 3.0).size()


## How many fires are being drawn.
func _flames(game: Node, fx: Node) -> int:
	return game.get_children().filter(func(node: Node) -> bool: return node is MeshInstance3D and not node.is_queued_for_deletion() and (node.mesh == fx._flames or node.mesh == fx._blaze)).size()


## Seconds of the game since the physics frame `began`: a game that runs
## faster takes as many steps a second, and longer ones.
func _seconds(began: int) -> float:
	return float(Engine.get_physics_frames() - began) / Engine.physics_ticks_per_second * Engine.time_scale


## Waits until `condition` holds, for `limit` seconds of the game at most, and
## says how many it took: -1 if it never held.
func _until(test: SceneTree, condition: Callable, limit: float) -> float:
	var began := Engine.get_physics_frames()
	while not condition.call():
		if _seconds(began) > limit:
			return -1.0
		await test.physics_frame
	return _seconds(began)
