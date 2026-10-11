extends SceneTree
## Says what a level costs to load and to hold in memory, for knowing what a
## larger one will cost before it is built.
##   tools/level_cost.sh [level]        the factory, when none is named
## It loads scenes/levels/<level>_level.tscn into an empty scene and reports
## how long that took and what it added to the memory in use. It needs the
## GPU, since most of what a level holds is on the video card. The times are
## those of a file the system has read before; the first time after a restart
## takes longer.
##
## What to read off it: the textures are those of the materials and the
## models, which every level shares, so they do not grow with the level. What
## does grow is its own file, its meshes and its lightmaps, which are listed
## one by one.

## Bytes a texel of a lightmap takes, by image format.
const TEXEL_BYTES := {Image.FORMAT_BPTC_RGBF: 1.0, Image.FORMAT_BPTC_RGBFU: 1.0, Image.FORMAT_RGBAH: 8.0, Image.FORMAT_RGBH: 6.0, Image.FORMAT_RGBE9995: 4.0}


func _initialize() -> void:
	# Whatever goes wrong in there, Godot is not left running.
	await _measure()
	quit()


func _measure() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var level_name := args[0] if args.size() > 0 else "factory"
	var path := "res://scenes/levels/%s_level.tscn" % level_name
	if not ResourceLoader.exists(path):
		push_error("There is no level called %s in scenes/levels/." % level_name)
		return
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.7, 0)
	root.add_child(camera)
	camera.make_current()
	for i in 10:
		await process_frame
	var before := _memory()
	var began := Time.get_ticks_msec()
	var packed: PackedScene = load(path)
	var everything := Time.get_ticks_msec() - began
	# Once more, with all it refers to in memory: the file of the level alone.
	began = Time.get_ticks_msec()
	ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var file := Time.get_ticks_msec() - began
	began = Time.get_ticks_msec()
	var level := packed.instantiate()
	var built := Time.get_ticks_msec() - began
	began = Time.get_ticks_msec()
	root.add_child(level)
	await process_frame
	var first := Time.get_ticks_msec() - began
	for i in 60:
		await process_frame
	var after := _memory()
	var zones := level.get_children().filter(func(node: Node) -> bool: return node.is_in_group("level_zone")).size()
	print("%s: %d nodes, %d zones, a file of %.2f MB" % [level_name, level.find_children("*", "", true, false).size(), zones, FileAccess.get_file_as_bytes(path).size() / 1e6])
	print("  loading: %d ms, of which %d ms the file of the level itself; %d ms to make the nodes, %d ms to the first frame" % [everything, file, built, first])
	print("  memory over an empty scene: %.0f MB of textures, %.0f MB of meshes and other buffers, %.0f MB on the video card in all, %.0f MB of the engine's own" % [after[0] - before[0], after[1] - before[1], after[2] - before[2], after[3] - before[3]])
	var seen := {}
	var total := 0.0
	var baked: Array[LightmapGIData] = []
	for lightmap: LightmapGI in level.find_children("*", "LightmapGI", true, false):
		baked.append(lightmap.light_data)
	# A level that is not cut into zones has its one lightmap in the scene
	# that is played.
	var whole := "res://scenes/%s.lmbake" % level_name
	if baked.is_empty() and ResourceLoader.exists(whole):
		baked.append(load(whole))
	for data in baked:
		if data == null or seen.has(data):
			continue
		seen[data] = true
		for texture: TextureLayered in data.lightmap_textures:
			var size := texture.get_width() * texture.get_height() * texture.get_layers() * float(TEXEL_BYTES.get(texture.get_format(), 4.0)) / 1048576.0
			total += size
			print("  lightmap %s: %d x %d in %d layers, %.0f MB" % [data.resource_path.get_file().get_basename(), texture.get_width(), texture.get_height(), texture.get_layers(), size])
	print("  lightmaps in all: %.0f MB of those textures" % total)


func _memory() -> Array[float]:
	return [
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
	]
