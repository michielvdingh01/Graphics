extends "res://tools/levels/alps/plan.gd"
## What lies round the land, where nobody comes: the rest of the basin, and
## the mountains round it out to where the haze takes them, the Zugspitze and
## the Wetterstein in the east, the Mieminger chain in the south-east, the
## Lechtal Alps in the south-west and the Daniel and the Ammergau Alps in the
## north-west. Their heights are the real ones, as the land's are.
##
## It is three rings round the land, each of squares four times as large as
## the one inside it, and each ring is laid in blocks with a skirt, as the
## land is. Every ring's inside edge is the outside edge of the one before,
## and lies on the squares of both.

## The rings: how large their squares are, in metres, and how far beyond the
## land each reaches. Every ring reaches a whole number of the squares of the
## next one beyond the land.
const RINGS := [[8.0, 1152.0], [32.0, 5120.0], [128.0, 11520.0]]
## How many squares go into a block of a ring.
const RING_BLOCK := 32
## How large a dot of the far map is, in metres: see _far_map().
const FAR_CELL := 24.0


func _describe() -> void:
	in_zone("")
	_far_map()
	var mat := ground_look()
	var inside := LAND
	for ring: Array in RINGS:
		var cell: float = ring[0]
		var outside := LAND.grow(ring[1])
		var columns := int(outside.size.x / cell) + 1
		var rows := int(outside.size.y / cell) + 1
		var heights := PackedFloat32Array()
		heights.resize(columns * rows)
		for row in rows:
			for column in columns:
				heights[row * columns + column] = altitude(outside.position.x + column * cell, outside.position.y + row * cell)
		var grid: RefCounted = GROUND.new(heights, columns, rows, cell, outside.position)
		var laid := 0
		for r0 in range(0, rows - 1, RING_BLOCK):
			for c0 in range(0, columns - 1, RING_BLOCK):
				var box := Rect2(outside.position + Vector2(c0, r0) * cell, Vector2.ONE * RING_BLOCK * cell)
				if inside.encloses(box):
					continue
				var mesh: ArrayMesh = grid.block(c0, r0, RING_BLOCK, 1, inside)
				if mesh:
					lay_mesh(mesh, mat)
					laid += 1
		print("Ring of %d m squares out to %d m: %d blocks" % [int(cell), int(ring[1]), laid])
		inside = outside


## The far map: what the ground material is told of every 24 metres of the
## land and of all that lies round it, worked out from the heights at that
## size. Two images, each RGBA:
##   the first: how much sun reaches the spot, how much of the sky it sees,
##   how much of it is wood, how much snow lies on it;
##   the second: which way it faces (x and z of its normal), how much of it is
##   rock, how much scree.
## The land itself has a finer map of its own: see _land_map() in plan.gd.
func _far_map() -> void:
	var began := Time.get_ticks_msec()
	var area: Rect2 = LAND.grow(RINGS[-1][1])
	var across := int(area.size.x / FAR_CELL) + 1
	var down := int(area.size.y / FAR_CELL) + 1
	var heights := PackedFloat32Array()
	heights.resize(across * down)
	for row in down:
		for column in across:
			heights[row * across + column] = altitude(area.position.x + column * FAR_CELL, area.position.y + row * FAR_CELL)
	var lit: PackedFloat32Array = LIGHT.sun(heights, across, down, FAR_CELL, _sunward)
	var open: PackedFloat32Array = LIGHT.open_sky(heights, across, down, FAR_CELL)
	var steep_round := PackedFloat32Array()
	steep_round.resize(heights.size())
	var normals := PackedVector3Array()
	normals.resize(heights.size())
	for row in down:
		for column in across:
			var i := row * across + column
			var west := heights[row * across + maxi(column - 1, 0)]
			var east := heights[row * across + mini(column + 1, across - 1)]
			var north := heights[maxi(row - 1, 0) * across + column]
			var south := heights[mini(row + 1, down - 1) * across + column]
			normals[i] = Vector3(west - east, 2.0 * FAR_CELL, north - south).normalized()
			steep_round[i] = 1.0 - smoothstep(0.62, 0.78, normals[i].y)
	# Scree lies below rock: rock within a few hundred metres uphill.
	var rock_near: PackedFloat32Array = LIGHT.evened(steep_round, across, down, 5)
	var first := Image.create(across, down, false, Image.FORMAT_RGBA8)
	var second := Image.create(across, down, false, Image.FORMAT_RGBA8)
	for row in down:
		for column in across:
			var i := row * across + column
			var at := area.position + Vector2(column, row) * FAR_CELL
			var cover := lie_of(at, heights[i] + SEA, normals[i])
			var scree: float = rock_near[i] * (1.0 - cover.rock) * smoothstep(0.7, 0.85, normals[i].y) * (1.0 - cover.forest) * smoothstep(SEA + 600.0, SEA + 900.0, heights[i] + SEA - 300.0)
			first.set_pixel(column, row, Color(lit[i], open[i], cover.forest, cover.snow))
			second.set_pixel(column, row, Color(normals[i].x * 0.5 + 0.5, normals[i].z * 0.5 + 0.5, cover.rock, clampf(scree * 1.5, 0.0, 1.0)))
	first.generate_mipmaps()
	second.generate_mipmaps()
	_far_maps = [ImageTexture.create_from_image(first), ImageTexture.create_from_image(second)]
	_far_rect = Vector4(area.position.x, area.position.y, 1.0 / (across * FAR_CELL), 1.0 / (down * FAR_CELL))
	print("Far map: %d x %d dots of %d m, in %.1f s" % [across, down, int(FAR_CELL), (Time.get_ticks_msec() - began) / 1000.0])
