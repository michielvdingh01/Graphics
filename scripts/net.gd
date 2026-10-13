extends Node
## Playing together over the network.
##
## One machine hosts. Its player is a player like any other, and it runs the
## world: the enemies, whatever explodes and the route through the level. The
## others join it by its address. Each machine runs its own player, so moving
## and shooting are as direct as when playing alone: it tells the others where
## its player is and what it shot at, and asks the host to hurt what it hit.
## That takes every machine at its word, which is fine among friends and
## nothing to put on the open internet.
##
## Playing alone is the same thing with nobody else there: is_host() holds,
## show() runs here and that is all.
##
## Everything goes through this node, which is there on every machine whatever
## level is loaded, and is addressed to a node by its path. A level therefore
## has to give whatever it makes at run time the same name everywhere.

## Who is here, or who is in the level, has changed.
signal changed
## This machine is about to load a level on the host's word.
signal entering(scene: String)
## The game this machine was in is over for it; `reason` says why if it was
## not its own doing.
signal left(reason: String)
## A line for the HUD: who came and who went.
signal said(text: String)

## UDP port a host listens on, which is the one to forward to it on a router.
const PORT := 24565
const MAX_PLAYERS := 8
## Two machines play together only if they agree on this. Raise it with
## anything that changes what goes over the wire or how a level is built.
const VERSION := 9
## Seconds between two reports of where this machine's player is.
const TICK := 1.0 / 30.0
## Seconds to wait for a host to answer before giving up on it.
const JOIN_TIME := 8.0
const CONFIG := "user://net.cfg"
## What a guest may have the host do to a node, see ask().
const ASKS: Array[StringName] = [&"take_damage", &"explode"]
## What a machine may report its player did, see player_did().
const DEEDS: Array[StringName] = [&"fired", &"threw", &"hurt"]
const NOBODY := {"level": "", "at": "", "kills": 0, "theme": ""}

## Bits of what a player is doing, as they go over the wire.
enum { CROUCHED = 1, SPRINTING = 2, DEAD = 4 }

## True while hosting or joined.
var active := false
## Everybody in the game by id, the host being 1: {name}.
var players := {}
## The ids of those whose level is loaded, as a set.
var present := {}
## What is being played: the level, the checkpoint to carry on from after
## everybody has died, the kills that stood then and who the enemies are.
var session := NOBODY.duplicate()
## What this player is called, and the address last joined.
var player_name := "Player"
var address := "127.0.0.1"
## The port to host on and the address to listen at, "*" for all there are.
## The test of playing together listens to this machine only.
var port := PORT
var bind := "*"
## The level on this machine, once it is ready for the others.
var game: Node

var _joining := false
## Counts the times a game was looked for, to tell them apart.
var _attempt := 0
## Guests whose level was loaded before the host's own.
var _waiting: Array[int] = []
var _since_tick := 0.0
## The enemies this machine had chosen for itself, to go back to.
var _own_theme := ""


func _ready() -> void:
	# A menu that stops the game does not stop this.
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_end.bind("Nobody is hosting at that address"))
	multiplayer.server_disconnected.connect(_end.bind("The host has left"))
	var user := OS.get_environment("USER") if OS.has_environment("USER") else OS.get_environment("USERNAME")
	if user:
		player_name = user.capitalize()
	if Benchmark.active or SelfTest.active:
		return
	var file := ConfigFile.new()
	if file.load(CONFIG) == OK:
		player_name = str(file.get_value("net", "name", player_name))
		address = str(file.get_value("net", "address", address))


## True on the machine that runs the world: the host, or the only one there is.
func is_host() -> bool:
	return multiplayer.is_server()


## True on a machine that has joined somebody else's game.
func is_guest() -> bool:
	return active and not multiplayer.is_server()


func id() -> int:
	return multiplayer.get_unique_id()


## Where this machine's player comes in a row of everybody in the game, for
## standing them side by side.
func slot() -> int:
	var ids := players.keys()
	ids.sort()
	return maxi(ids.find(id()), 0)


## The body of a player on this machine: its own, or the puppet of another.
func body(player: int) -> CharacterBody3D:
	if game == null:
		return null
	return game.player if player == id() else game.puppets.get(player)


## The addresses of this machine on the networks it is on, for somebody on
## the same network to join by.
func local_addresses() -> Array[String]:
	var found: Array[String] = []
	for candidate in IP.get_local_addresses():
		if candidate.count(".") == 3 and not candidate.begins_with("127.") and not candidate.begins_with("169.254."):
			found.append(candidate)
	return found


# --- Hosting, joining and leaving ---------------------------------------------


## Opens a game on this machine for others to join. Playing starts with
## load_level().
func host_game() -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip(bind)
	var error := peer.create_server(port, MAX_PLAYERS - 1)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	active = true
	players = {1: {"name": player_name}}
	_remember()
	changed.emit()
	return OK


## Goes looking for a game at `where`, an address with or without a port
## after a colon. What comes of it is told by `entering` or by `left`.
func join_game(where: String) -> Error:
	leave()
	var host := where.strip_edges()
	var at_port := PORT
	if host.count(":") == 1:
		at_port = int(host.get_slice(":", 1))
		host = host.get_slice(":", 0)
	if host == "" or host.contains(" ") or at_port <= 0:
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(host, at_port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	_joining = true
	address = where.strip_edges()
	_remember()
	_attempt += 1
	get_tree().create_timer(JOIN_TIME, true).timeout.connect(_give_up.bind(_attempt))
	return OK


func _give_up(attempt: int) -> void:
	if _joining and attempt == _attempt:
		_end("Nobody is hosting at that address")


func is_joining() -> bool:
	return _joining


## Back to playing alone. A host takes its game with it.
func leave() -> void:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if _own_theme:
		Settings.enemy_theme = _own_theme
		_own_theme = ""
	var was := active
	active = false
	_joining = false
	players = {}
	present = {}
	_waiting.clear()
	session = NOBODY.duplicate()
	if was:
		changed.emit()


## Takes everybody to a level: to its start, or to the checkpoint `at`.
func load_level(scene: String, at := "", kills := 0) -> void:
	if not active or not multiplayer.is_server():
		return
	session = {"level": scene, "at": at, "kills": kills, "theme": Settings.enemy_theme}
	present = {}
	_waiting.clear()
	game = null
	_tell_roster()
	for guest: int in players:
		if guest != 1:
			_enter.rpc_id(guest, session)
	entering.emit(scene)
	get_tree().change_scene_to_file(scene)


## The level on this machine is loaded and ready for the others.
func arrive(level: Node) -> void:
	game = level
	if not active:
		return
	if multiplayer.is_server():
		present[1] = true
		for guest in _waiting:
			_admit(guest)
		_waiting.clear()
		_tell_roster()
	else:
		_arrived.rpc_id(1, session.level)


## The level on this machine is being taken down.
func depart(level: Node) -> void:
	if game == level:
		game = null


func _on_connected() -> void:
	_hello.rpc_id(1, VERSION, player_name)


@rpc("any_peer", "call_remote", "reliable")
func _hello(version: int, title: String) -> void:
	var guest := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server():
		return
	if version != VERSION:
		_refuse.rpc_id(guest, "The host plays another version of the game")
		return
	players[guest] = {"name": title.left(24) if title else "Player"}
	said.emit("%s joined" % players[guest].name)
	_tell_roster()
	if session.level:
		_enter.rpc_id(guest, session)


@rpc("authority", "call_remote", "reliable")
func _refuse(reason: String) -> void:
	_end(reason)


func _on_peer_disconnected(peer: int) -> void:
	if not active or not multiplayer.is_server() or not players.has(peer):
		return
	said.emit("%s left" % players[peer].name)
	players.erase(peer)
	present.erase(peer)
	_waiting.erase(peer)
	_tell_roster()


func _tell_roster() -> void:
	for guest: int in players:
		if guest != 1:
			_roster.rpc_id(guest, players, present.keys())
	changed.emit()


@rpc("authority", "call_remote", "reliable")
func _roster(everybody: Dictionary, here: Array) -> void:
	if not active and not _joining:
		return
	for peer: int in everybody:
		if active and not players.has(peer):
			said.emit("%s joined" % everybody[peer].name)
	for peer: int in players:
		if not everybody.has(peer):
			said.emit("%s left" % players[peer].name)
	active = true
	_joining = false
	players = everybody
	present = {}
	for peer: int in here:
		present[peer] = true
	changed.emit()


@rpc("authority", "call_remote", "reliable")
func _enter(what: Dictionary) -> void:
	if not active:
		return
	session = what
	game = null
	if _own_theme == "":
		_own_theme = Settings.enemy_theme
	Settings.enemy_theme = session.theme
	entering.emit(session.level)
	get_tree().change_scene_to_file(session.level)


@rpc("any_peer", "call_remote", "reliable")
func _arrived(level: String) -> void:
	var guest := multiplayer.get_remote_sender_id()
	# One that was still on its way to the level before this one.
	if not multiplayer.is_server() or not players.has(guest) or level != session.level:
		return
	if game == null:
		_waiting.append(guest)
		return
	_admit(guest)
	_tell_roster()


## Tells a guest how the level stands; from here on it hears what happens.
func _admit(guest: int) -> void:
	_restore.rpc_id(guest, game.net_snapshot())
	present[guest] = true


@rpc("authority", "call_remote", "reliable")
func _restore(state: Dictionary) -> void:
	if game:
		game.net_restore(state)


func _end(reason: String) -> void:
	leave()
	left.emit(reason)


func _remember() -> void:
	if Benchmark.active or SelfTest.active:
		return
	var file := ConfigFile.new()
	file.set_value("net", "name", player_name)
	file.set_value("net", "address", address)
	file.save(CONFIG)


# --- The world: the host's word ------------------------------------------------


## Runs `method` of `node` here and on the machine of everybody else in the
## level: for what the host has decided and all are to see. On a guest it
## does nothing, since the host's word is on its way. `sure` off is for what
## is told again a moment later anyway and may get lost.
func show(node: Node, method: StringName, args := [], sure := true) -> void:
	if is_guest():
		return
	node.callv(method, args)
	tell(node, method, args, sure)


## The same, on the other machines only.
func tell(node: Node, method: StringName, args := [], sure := true) -> void:
	if not active or not multiplayer.is_server() or present.size() < 2:
		return
	var path := node.get_path()
	for guest: int in present:
		if guest != 1:
			callv("rpc_id", [guest, &"_do" if sure else &"_do_fast", path, method, args])


@rpc("authority", "call_remote", "reliable")
func _do(path: NodePath, method: StringName, args: Array) -> void:
	var node := get_node_or_null(path)
	if game and node:
		node.callv(method, args)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _do_fast(path: NodePath, method: StringName, args: Array) -> void:
	_do(path, method, args)


## Has the host run `method` of `node`, one of ASKS: for what this machine's
## player does to the world.
func ask(node: Node, method: StringName, args := []) -> void:
	if is_guest():
		_ask.rpc_id(1, node.get_path(), method, args)
	else:
		node.callv(method, args)


@rpc("any_peer", "call_remote", "reliable")
func _ask(path: NodePath, method: StringName, args: Array) -> void:
	if not multiplayer.is_server() or not present.has(multiplayer.get_remote_sender_id()) or not ASKS.has(method):
		return
	var node := get_node_or_null(path)
	if game and node and node.has_method(method):
		node.callv(method, args)


## Hurts `target` with a shot of this machine's player. True if that killed
## it, which on a guest is a guess from how it stood: the host decides.
func damage(target: Object, amount: float, at: Vector3, direction: Vector3) -> bool:
	if not is_guest():
		return target.take_damage(amount, at, direction)
	ask(target, &"take_damage", [amount, at, direction])
	if target.get(&"dead") != false:
		return false
	# Counted off here too, so that the next shot knows where it stands
	# before the host has answered.
	target.health -= amount
	return target.health <= 0.0


# --- The players: each machine's own word --------------------------------------


func _physics_process(delta: float) -> void:
	if not active or game == null or not present.has(id()):
		return
	_since_tick += delta
	if _since_tick < TICK:
		return
	_since_tick = 0.0
	var player: CharacterBody3D = game.player
	var doing := 0
	if player.is_crouched():
		doing |= CROUCHED
	if player.is_sprinting():
		doing |= SPRINTING
	if player.dead:
		doing |= DEAD
	_state.rpc(player.global_position, player.rotation.y, player.head.rotation.x, player.velocity, doing, player.weapons.LOADOUT.find(player.weapons.current()))


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _state(at: Vector3, yaw: float, pitch: float, speed: Vector3, doing: int, weapon: int) -> void:
	var puppet := _puppet()
	if puppet:
		puppet.net_state(at, yaw, pitch, speed, doing, weapon)


## Tells the others what this machine's player did, one of DEEDS, which their
## puppet of it then shows.
func player_did(what: StringName, args := []) -> void:
	if active and game:
		_did.rpc(what, args)


@rpc("any_peer", "call_remote", "reliable", 2)
func _did(what: StringName, args: Array) -> void:
	var puppet := _puppet()
	if puppet and DEEDS.has(what):
		puppet.callv(what, args)


## The puppet here of whoever this message is from.
func _puppet() -> Node:
	return game.puppets.get(multiplayer.get_remote_sender_id()) if game else null


## Passes on what the host's world does to somebody else's player: each
## machine keeps the health of its own.
func hurt(player: int, amount: float, at: Vector3, direction: Vector3) -> void:
	if is_host() and present.has(player):
		_hurt.rpc_id(player, amount, at, direction)


@rpc("authority", "call_remote", "reliable", 2)
func _hurt(amount: float, at: Vector3, direction: Vector3) -> void:
	if game:
		game.player.take_damage(amount, at, direction)


## The same for being thrown about by a blast.
func shove(player: int, push: Vector3) -> void:
	if is_host() and present.has(player):
		_shove.rpc_id(player, push)


@rpc("authority", "call_remote", "reliable", 2)
func _shove(push: Vector3) -> void:
	if game and not game.player.dead:
		game.player.velocity += push
