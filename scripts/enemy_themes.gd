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
## tint}, with the character as a scene. Empty for a robot.
static func cast(theme: String, role: String) -> Dictionary:
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
		"character": load(scenes.pick_random()),
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
	return _themes
