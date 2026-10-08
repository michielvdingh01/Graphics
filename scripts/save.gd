extends Node
## Checkpoint storage: the level and wave the player last reached, kept in
## user://save.cfg so both a death and a restart of the game resume there.
## Benchmark and self-test runs never read or write it.

const PATH := "user://save.cfg"

## Empty when there is nothing to resume; otherwise {level, wave, kills}.
var checkpoint := {}

var _persistent := true


func _ready() -> void:
	_persistent = not Benchmark.active and not SelfTest.active
	if not _persistent:
		return
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	var level: String = file.get_value("checkpoint", "level", "")
	if ResourceLoader.exists(level):
		checkpoint = {
			"level": level,
			"wave": int(file.get_value("checkpoint", "wave", 1)),
			"kills": int(file.get_value("checkpoint", "kills", 0)),
		}


func store(level: String, wave: int, kills: int) -> void:
	checkpoint = {"level": level, "wave": wave, "kills": kills}
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
	file.save(PATH)
