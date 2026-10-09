extends Node
## Checkpoint storage: the level and the place in it the player last reached,
## kept in user://save.cfg so both a death and a restart of the game resume
## there. A checkpoint is named by the id the level gives it; what was cleared
## on the way to it follows from where it lies on the route, so that is not
## stored. A benchmark or --snap run never reads or writes it, and a
## self-test run keeps a file of its own.

const PATH := "user://save.cfg"
const SELFTEST_PATH := "user://selftest_save.cfg"

## Empty when there is nothing to resume; otherwise {level, at, title, kills},
## with an empty `at` for the start of the level.
var checkpoint := {}

var _path := PATH
var _persistent := true


func _ready() -> void:
	_persistent = not Benchmark.active and not Benchmark.snapping
	if SelfTest.active:
		# Starts from nothing, whatever an earlier run left behind.
		_path = SELFTEST_PATH
		clear()
	reload()


## Reads the file again, as a restart of the game would.
func reload() -> void:
	checkpoint = {}
	var file := ConfigFile.new()
	if not _persistent or file.load(_path) != OK:
		return
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
	_write()


## The checkpoint for the given level scene, or an empty dictionary.
func resume_point(level: String) -> Dictionary:
	return checkpoint if checkpoint.get("level", "") == level else {}


func _write() -> void:
	if not _persistent:
		return
	var file := ConfigFile.new()
	for key: String in checkpoint:
		file.set_value("checkpoint", key, checkpoint[key])
	file.save(_path)
