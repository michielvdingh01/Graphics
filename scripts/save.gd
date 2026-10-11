extends Node
## Checkpoint storage: the level and the place in it the player last reached,
## kept in user://save.cfg so both a death and a restart of the game resume
## there. A checkpoint is named by the id the level gives it; what was cleared
## on the way to it follows from where it lies on the route, so that is not
## stored. A benchmark or --snap run never reads or writes it, and a
## self-test run keeps a file of its own, one for every checkout of the
## project (see SelfTest.own_file). A level that is not in the game's
## list of levels, one that is being tried out, keeps its checkpoints for as
## long as it runs and leaves the file as it found it.

const PATH := "user://save.cfg"

## What a run is measured by, see `stats`.
const STATS: Array[String] = ["seconds", "shots", "hits", "headshots", "deaths"]

## Empty when there is nothing to resume; otherwise {level, at, title, kills},
## with an empty `at` for the start of the level.
var checkpoint := {}
## What the run has come to since "New game": seconds played, shots fired,
## shots that hit, headshots and deaths. It goes into the file with every
## checkpoint and with every death, and clear() starts it again.
var stats := {}

var _path := PATH
var _persistent := true
## What was saved and whether it was written, while it is set aside.
var _aside := {}


func _ready() -> void:
	_persistent = not Benchmark.active and not Benchmark.snapping
	if SelfTest.active:
		# Starts from nothing, whatever an earlier run left behind.
		_path = SelfTest.own_file("save.cfg")
		clear()
	reload()


## Reads the file again, as a restart of the game would.
func reload() -> void:
	checkpoint = {}
	_reset_stats()
	var file := ConfigFile.new()
	if not _persistent or file.load(_path) != OK:
		return
	for key in STATS:
		stats[key] = float(file.get_value("stats", key, 0.0))
	var level: String = file.get_value("checkpoint", "level", "")
	if ResourceLoader.exists(level):
		checkpoint = {
			"level": level,
			"at": str(file.get_value("checkpoint", "at", "")),
			"title": str(file.get_value("checkpoint", "title", "")),
			"kills": int(file.get_value("checkpoint", "kills", 0)),
		}


func store(level: String, at: String, title: String, kills: int) -> void:
	checkpoint = {"level": level, "at": at, "title": title, "kills": kills}
	_write()


func clear() -> void:
	checkpoint = {}
	_reset_stats()
	_write()


## Adds to one of the things a run is measured by.
func tally(what: String, by := 1.0) -> void:
	stats[what] = stats.get(what, 0.0) + by


## Writes what there is to the file now, instead of at the next checkpoint.
func flush() -> void:
	_write()


## Sets what is saved aside while something is played that is not the game,
## and puts it back afterwards as it was. In between nothing is written,
## whatever is stored or tallied.
func set_aside(on: bool) -> void:
	if on == not _aside.is_empty():
		return
	if on:
		_aside = {"checkpoint": checkpoint, "stats": stats, "persistent": _persistent}
		checkpoint = {}
		_persistent = false
		_reset_stats()
	else:
		checkpoint = _aside.checkpoint
		stats = _aside.stats
		_persistent = _aside.persistent
		_aside = {}


func _reset_stats() -> void:
	stats = {}
	for key in STATS:
		stats[key] = 0.0


## True while the scene that is played is not one of the game's levels.
func _trying_out() -> bool:
	var scene := get_tree().current_scene
	return scene != null and not Menu.LEVELS.any(func(level: Dictionary) -> bool: return level.scene == scene.scene_file_path)


## The checkpoint for the given level scene, or an empty dictionary.
func resume_point(level: String) -> Dictionary:
	return checkpoint if checkpoint.get("level", "") == level else {}


func _write() -> void:
	if not _persistent or _trying_out():
		return
	var file := ConfigFile.new()
	for key: String in checkpoint:
		file.set_value("checkpoint", key, checkpoint[key])
	for key: String in stats:
		file.set_value("stats", key, stats[key])
	file.save(_path)
