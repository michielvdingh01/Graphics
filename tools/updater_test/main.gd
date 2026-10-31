extends Node
## Writes where the updater ended up to the file --log= names, for
## tools/test_updater.sh, and stops.

const SETTLED: Array[int] = [Updater.State.IDLE, Updater.State.READY, Updater.State.FAILED]


func _ready() -> void:
	var told := OS.get_cmdline_user_args()
	await get_tree().create_timer(0.2).timeout
	while Updater.state not in SETTLED:
		await get_tree().create_timer(0.05).timeout
	var log_path := ""
	for arg in told:
		if arg.begins_with("--log="):
			log_path = arg.trim_prefix("--log=")
	var file := FileAccess.open(log_path, FileAccess.WRITE)
	file.store_line("build=%d state=%s" % [Updater.build, Updater.State.keys()[Updater.state]])
	file.close()
	if Updater.state == Updater.State.READY and "--restart" in told:
		Updater.restart()
	get_tree().quit()
