extends RefCounted
## Every weapon there is, and the packs they are carried in.
##
## A weapon is known everywhere by its place in ALL: that is what goes over
## the wire, what a bot carries and what the line of who downed whom says it
## was done with. Weapons are only ever added at the end, so that a place
## never changes. Its name is that of its file in weapons/, which is also the
## name of the models built for it (scenes/models/<name>.scn and
## <name>_held.scn).
##
## A pack is a line in assets/packs.json: the weapons on 1 and on, what bots
## carry, and the grenades. Everybody in a match carries the pack of the
## match; the route and the sandbox carry STANDARD. A pack that names a weapon
## that is not in ALL yet is not on offer.

const ALL: Array[WeaponData] = [
	preload("res://weapons/rifle.tres"),
	preload("res://weapons/pistol.tres"),
	preload("res://weapons/shotgun.tres"),
	preload("res://weapons/smg.tres"),
	preload("res://weapons/marksman.tres"),
	preload("res://weapons/minigun.tres"),
	preload("res://weapons/rocket_launcher.tres"),
	preload("res://weapons/revolver.tres"),
	preload("res://weapons/double_barrel.tres"),
	preload("res://weapons/machine_pistol.tres"),
	preload("res://weapons/bolt_rifle.tres"),
	preload("res://weapons/battle_rifle.tres"),
	preload("res://weapons/lmg.tres"),
	preload("res://weapons/ppsh.tres"),
	preload("res://weapons/mosin.tres"),
	preload("res://weapons/trench_gun.tres"),
	preload("res://weapons/colt.tres"),
]
const FILE := "res://assets/packs.json"
const STANDARD := "standard"
## The most weapons a pack has: one for each of the keys 1 to 5.
const MOST := 5

static var _packs := {}


## The place of `data` in ALL, -1 if it is none of them.
static func index(data: WeaponData) -> int:
	return ALL.find(data)


## The weapon at `place` in ALL, the first one if there is none there.
static func at(place: int) -> WeaponData:
	return ALL[place] if place >= 0 and place < ALL.size() else ALL[0]


## The weapon with this name, null if there is none.
static func named(weapon_name: String) -> WeaponData:
	for data in ALL:
		if data.resource_path.get_file().get_basename() == weapon_name:
			return data
	return null


## The packs on offer, in the order of the file.
static func names() -> PackedStringArray:
	var offered := PackedStringArray()
	for pack: String in _all():
		if not weapons(pack).is_empty():
			offered.append(pack)
	return offered


## What the file says of a pack, or of STANDARD if there is no such pack.
static func spec(pack: String) -> Dictionary:
	var packs := _all()
	return packs.get(pack, packs.get(STANDARD, {}))


static func title(pack: String) -> String:
	return str(spec(pack).get("title", pack.capitalize()))


## The weapons of a pack on 1 and on: none if one of them is not built yet.
static func weapons(pack: String) -> Array[WeaponData]:
	var list: Array[WeaponData] = []
	for weapon_name: Variant in spec(pack).get("weapons", []):
		var data := named(str(weapon_name))
		if data == null:
			return []
		if list.size() < MOST:
			list.append(data)
	return list


## What bots of a side carry, in the order they join it, as places in ALL.
## `far` for an arena where it is a long way between the ends.
static func bots(pack: String, far := false) -> Array[int]:
	var line: Dictionary = spec(pack)
	var listed: Array = line.get("far", []) if far and line.has("far") else line.get("bots", line.get("weapons", []))
	var places: Array[int] = []
	for weapon_name: Variant in listed:
		var place := index(named(str(weapon_name)))
		if place >= 0:
			places.append(place)
	if places.is_empty():
		places.append(0)
	return places


## The grenades a pack starts with and the most it carries.
static func grenades(pack: String) -> Vector2i:
	var start := int(spec(pack).get("grenades", 2))
	return Vector2i(start, maxi(start, 3))


static func _all() -> Dictionary:
	if _packs.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE)) if FileAccess.file_exists(FILE) else null
		if parsed is Dictionary and parsed.get("packs") is Dictionary:
			_packs = parsed.packs
		else:
			_packs = {STANDARD: {"title": "Standard", "weapons": ["rifle", "pistol", "shotgun", "smg", "marksman"]}}
	return _packs
