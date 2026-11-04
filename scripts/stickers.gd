extends RefCounted
## The stickers that have been stuck on the level in the Unmuted match, from
## the Branding Gun and the slop gun (see scripts/sticker.gd, which flies them
## and calls place() where one lands). Each is a decal, and a line here: where
## it is, which side stuck it and when. The ICP (scripts/modes/icp.gd) asks
## lures() what draws him.
##
## A sticker draws for PULL seconds and then stays on as a mark until it is
## the oldest of MOST. One that lands on a sticker of the other side, within
## OVER metres of its middle, takes its place: that one is gone.

## The pictures, by name, in assets/unmuted/stickers/<name>.png, and how wide
## each is laid on in metres; how high follows from the picture.
const PICTURES := "res://assets/unmuted/stickers/%s.png"
## Seconds a sticker draws.
const PULL := 20.0
## The most stickers there are at once; the oldest makes way.
const MOST := 300
## How near a sticker has to land to one of the other side to cover it.
const OVER := 0.25
## How deep a decal reaches into what it lies on, to find a floor that is not
## flat under it: the dunes.
const DEPTH := 0.3
## A sticker shows to this distance and fades out over the next FADE metres.
const SHOWN := 70.0
const FADE := 20.0

## One line per sticker: [decal, side, the time it landed, its position].
static var _all: Array = []
static var _textures := {}


## The picture `picture` as a texture, loaded once.
static func texture(picture: String) -> Texture2D:
	if not _textures.has(picture):
		_textures[picture] = load(PICTURES % picture)
	return _textures[picture]


## Seconds since the game started, the clock the stickers keep.
static func now() -> float:
	return Time.get_ticks_msec() * 0.001


## Lays a sticker `picture` on what was hit at `at`, which faces `normal`,
## `width` metres wide, for `side` (-1 outside a match); `incoming` is the way
## it flew, which says which way is up on a floor. A sticker of the other
## side under it goes. Returns the decal.
static func place(tree: SceneTree, picture: String, at: Vector3, normal: Vector3, incoming: Vector3, width: float, side: int) -> Decal:
	_forget()
	var image := texture(picture)
	var height := width * float(image.get_height()) / float(image.get_width())
	for line: Array in _all.duplicate():
		if line[1] != side and (line[3] as Vector3).distance_to(at) < OVER:
			_drop(line)
	var decal := Decal.new()
	decal.texture_albedo = image
	decal.size = Vector3(width, DEPTH, height)
	decal.transform = Transform3D(frame(normal, incoming), at)
	decal.upper_fade = 0.05
	decal.lower_fade = 0.05
	decal.normal_fade = 0.3
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = SHOWN
	decal.distance_fade_length = FADE
	# On every layer, as a bullet hole is: the level lies on the layers of its
	# zones and the figures on layer 1 with whatever else the game makes, so
	# there is no leaving those out. Who walks through one wears it a moment.
	tree.current_scene.add_child(decal)
	_all.append([decal, side, now(), at])
	while _all.size() > MOST:
		_drop(_all[0])
	return decal


## How a sticker lies on a face that looks along `normal`: its Y out of the
## face, and the top of the picture (its -Z) up on a wall, and away from
## whoever shot it on a floor or a ceiling.
static func frame(normal: Vector3, incoming: Vector3) -> Basis:
	var y := normal.normalized()
	var top := Vector3.UP if absf(y.y) < 0.7 else Vector3(incoming.x, 0.0, incoming.z)
	if top.length_squared() < 0.0001:
		top = Vector3.FORWARD
	top = (top - y * top.dot(y)).normalized()
	var z := -top
	var x := y.cross(z).normalized()
	return Basis(x, y, z)


## What draws the ICP: for every sticker that still does, [its position, its
## side, how much it still draws, from 1 when it landed to 0 after PULL].
static func lures() -> Array:
	_forget()
	var found := []
	var time := now()
	for line: Array in _all:
		var left := 1.0 - (time - float(line[2])) / PULL
		if left > 0.0:
			found.append([line[3], line[1], left])
	return found


## The stickers there are, for a test: [position, side] each.
static func stuck() -> Array:
	_forget()
	return _all.map(func(line: Array) -> Array: return [line[3], line[1]])


## Takes every sticker off: a match is over, or begins again.
static func clear() -> void:
	for line: Array in _all:
		if is_instance_valid(line[0]):
			(line[0] as Node).queue_free()
	_all.clear()


## Has the ICP seen the sticker nearest to `at` within `reach` metres, so that
## it no longer draws him: it stays, but as a mark.
static func seen(at: Vector3, reach: float) -> void:
	for line: Array in _all:
		if (line[3] as Vector3).distance_to(at) < reach:
			line[2] = -PULL


## Makes every sticker `seconds` older, for a test.
static func older(seconds: float) -> void:
	for line: Array in _all:
		line[2] = float(line[2]) - seconds


static func _drop(line: Array) -> void:
	if is_instance_valid(line[0]):
		(line[0] as Node).queue_free()
	_all.erase(line)


## Forgets the stickers whose decal is gone with the level they were on.
static func _forget() -> void:
	_all = _all.filter(func(line: Array) -> bool: return is_instance_valid(line[0]) and not (line[0] as Node).is_queued_for_deletion())
