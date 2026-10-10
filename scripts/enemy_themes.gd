extends RefCounted
## Who the enemies are. The theme "robots" is the three robots built in code;
## any other theme casts a character for each of the three roles (grunt,
## rusher, heavy), which scripts/humanoid_rig.gd then shows.
##
## Themes come from two tables of the same shape:
## {"themes": {"zombies": {"grunt": {"characters": ["zombie_01"], "weapon": "",
## "moves": "zombie", "tuning": {"melee": true}}, "rusher": ..., "heavy": ...}}}.
## One is assets/characters/manifest.json, where the characters that are made
## for the game are listed. The other sits next to the animations and holds
## the theme that is always there: the mannequins the moves were made on.
##
## A role names the characters one is picked from for every enemy, the model
## in scenes/models/ it carries ("" for none), its set of moves, and the
## exported variables of enemy.gd that are different for it. A character is an
## id, for assets/characters/<id>/<id>.glb, or the path of a scene. A table may
## also give a role a "tint": material name -> colour for that material.
## Whatever is missing or cannot be loaded makes that enemy a robot.
##
## A theme may also be another one with something different about it:
## {"like": "clowns", "tuning": {"panics": true}} is the clowns, each role
## with that on top of its own tuning. The other has to be a theme with roles
## of its own.

const ROBOTS := "robots"
const TABLES: Array[String] = ["res://assets/animations/themes.json", "res://assets/characters/manifest.json"]
const CHARACTERS := "res://assets/characters/%s/%s.glb"

static var _themes := {}
static var _read := false


## Every theme there is, robots first.
static func names() -> Array[String]:
	var found: Array[String] = [ROBOTS]
	for theme: String in _all():
		if theme != ROBOTS:
			found.append(theme)
	return found


## What an enemy of `role` is in `theme`: {character, weapon, moves, tuning,
## tint}, with the character as a scene. Empty for a robot. The character is
## picked at random, unless `pick` is given: the same number picks the same
## one, which is how machines that play together see the same faces.
static func cast(theme: String, role: String, pick := -1) -> Dictionary:
	var part: Variant = (_all().get(theme, {}) as Dictionary).get(role)
	if not part is Dictionary:
		return {}
	var scenes: Array[String] = []
	var listed: Variant = part.get("characters")
	if listed is Array:
		for character: Variant in listed:
			var path := str(character)
			if not path.begins_with("res://"):
				path = CHARACTERS % [path, path]
			if ResourceLoader.exists(path, "PackedScene"):
				scenes.append(path)
	if scenes.is_empty():
		return {}
	var tuning: Variant = part.get("tuning")
	var tint: Variant = part.get("tint")
	return {
		"character": load(scenes.pick_random() if pick < 0 else scenes[pick % scenes.size()]),
		"weapon": str(part.get("weapon", "")),
		"moves": str(part.get("moves", "default")),
		"tuning": tuning if tuning is Dictionary else {},
		"tint": tint if tint is Dictionary else {},
	}


static func _all() -> Dictionary:
	if not _read:
		_read = true
		for table in TABLES:
			if not FileAccess.file_exists(table):
				continue
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(table))
			var themes: Variant = parsed.get("themes") if parsed is Dictionary else null
			if not themes is Dictionary:
				push_warning("%s lists no themes" % table)
				continue
			for theme: String in themes:
				if themes[theme] is Dictionary:
					_themes[theme] = themes[theme]
		for theme: String in _themes.keys():
			var other: Variant = _themes.get(_themes[theme].get("like", ""))
			if not other is Dictionary:
				continue
			var on_top: Variant = _themes[theme].get("tuning")
			var roles := {}
			for role: String in other:
				var part: Variant = other[role]
				if part is Dictionary:
					part = part.duplicate()
					var tuning: Variant = part.get("tuning")
					part["tuning"] = (tuning if tuning is Dictionary else {}).merged(on_top if on_top is Dictionary else {}, true)
					roles[role] = part
			_themes[theme] = roles
	return _themes
