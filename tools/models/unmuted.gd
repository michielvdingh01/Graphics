extends "res://tools/model_builder.gd"
## The two bases of the Unmuted match (scripts/modes/icp.gd), as models that
## the match stands in the level where the stands of capture the flag are:
## no level is built again for them and nothing is baked. Built with
## tools/build_model.sh unmuted.
##
## unmuted_hq: the head office of Unmuted, a canal house of Amsterdam: four
## storeys of brick with white sash windows, a stoop up to a dark green door
## under a fanlight, a white cornice, and over it a neck gable with scrolled
## shoulders, a pediment and a hoisting beam. In the gable hangs the sticker
## of Unmuted, the logo on a black pill, three metres wide.
##
## doomscroll_hell: a black block with DOOMSCROLL and HELL in red that glows
## over its front, four phone screens with a feed on them either side of a
## door that glows red, and red neon along its edges.
##
## Both look along +Z with their front on z = 0 and the middle of their door
## at the origin, on the ground, and reach down into it for a floor that is
## not flat. What stops somebody is on the model as "collide": [the middle,
## the size] of every box, which the match makes a body of. The letters and
## pictures come from tools/unmuted/signs.py and tools/unmuted/stickers.py.

const BRICK := "brick"
const FRAME := "unmuted_frame"
const WINDOW := "unmuted_window"
const ROOF := "unmuted_roof"
const DOOR := "unmuted_door"
const STONE := "concrete"
const STICKER := "unmuted_sticker"
const BLACK := "doomscroll_black"
const GLOW := "doomscroll_glow"
const FEED := "doomscroll_feed"
## How far down into the ground a building goes.
const SUNK := 2.5

var _boxes: Array = []


func _describe() -> void:
	_canal_house()
	_doomscroll_hell()
	_ring_light_stand()


## The ring light of the TikTok Dance as it stands, set down by whoever
## dances (scripts/dancer.gd): a ring of light 46 cm across with a phone in
## its middle, on a pole on three legs, its light along +Z, 1.6 m up.
func _ring_light_stand() -> void:
	model("ring_light")
	var top := Vector3(0, 1.6, 0)
	for i in 3:
		var turn := TAU * float(i) / 3.0 + 0.4
		beam(BLACK, Vector3(0, 0.75, 0), Vector3(cos(turn) * 0.42, 0.0, sin(turn) * 0.42), 0.025, NO_COLLIDE)
	_bar(BLACK, Vector3(0, 0.7, 0), top - Vector3(0, 0.23, 0), 0.016, 10)
	_ring("ring_glow", top, Vector3.BACK, 0.23, 0.025)
	_ring(BLACK, top + Vector3.FORWARD * 0.015, Vector3.BACK, 0.23, 0.03)
	_part_box(BLACK, top, Vector3(0.08, 0.16, 0.012))
	_part_box("ring_glow", top + Vector3.BACK * 0.007, Vector3(0.07, 0.145, 0.002))


func _canal_house() -> void:
	model("unmuted_hq")
	_boxes = []
	var wide := 8.0
	var deep := 11.0
	var storey := 3.2
	var floor0 := 0.9
	var eaves := floor0 + storey * 4.0
	# The house, and the stone of its foot along the front.
	_solid(BRICK, Vector3(0, (eaves - SUNK) * 0.5, -deep * 0.5), Vector3(wide, eaves + SUNK, deep))
	_part_box(STONE, Vector3(0, (floor0 - SUNK) * 0.5, 0.06), Vector3(wide + 0.1, floor0 + SUNK, 0.14))
	# The windows: three a storey, two beside the door below.
	for level in 4:
		var sill := floor0 + storey * level + (0.75 if level > 0 else 0.6)
		var high := 2.2 if level < 2 else 1.9
		for x: float in [-2.6, 0.0, 2.6]:
			if level == 0 and x == 0.0:
				continue
			_sash(Vector3(x, sill, 0.0), Vector2(1.3, high))
	# The door under its fanlight, up a stoop of four steps.
	_part_box(DOOR, Vector3(0, floor0 + 1.3, 0.03), Vector3(1.3, 2.6, 0.06))
	_frame(Vector3(0, floor0, 0.0), Vector2(1.3, 2.6), 0.14)
	_part_box(WINDOW, Vector3(0, floor0 + 2.95, 0.03), Vector3(1.3, 0.5, 0.04))
	_frame(Vector3(0, floor0 + 2.7, 0.0), Vector2(1.3, 0.5), 0.1)
	_part_box(FRAME, Vector3(0.0, floor0 + 1.25, 0.08), Vector3(0.06, 0.06, 0.04))
	for step in 4:
		var top := floor0 * float(4 - step) / 4.0
		_part_box(STONE, Vector3(0, (top - 0.3) * 0.5, 0.35 + step * 0.32), Vector3(2.4, top + 0.3, 0.7 + step * 0.0))
	for side: float in [-1.0, 1.0]:
		_part_box(BLACK, Vector3(side * 1.15, floor0 + 0.45, 0.85), Vector3(0.05, 0.9, 1.3))
	_boxes.append([Vector3(0, floor0 * 0.5 - 0.2, 0.9), Vector3(2.4, floor0 + 0.4, 1.4)])
	# Bands of stone between the storeys, and the cornice.
	for level in range(1, 4):
		_part_box(FRAME, Vector3(0, floor0 + storey * level, 0.04), Vector3(wide, 0.12, 0.1))
	_part_box(FRAME, Vector3(0, eaves + 0.2, 0.15), Vector3(wide + 0.3, 0.4, 0.3))
	_part_box(FRAME, Vector3(0, eaves - 0.08, 0.08), Vector3(wide + 0.1, 0.16, 0.16))

	# The neck gable: a neck of brick, scrolls on its shoulders, a pediment.
	var neck := 1.9
	var top := eaves + 4.2
	_slab(BRICK, [Vector2(-neck, eaves), Vector2(neck, eaves), Vector2(neck, top), Vector2(-neck, top)], -0.45, 0.0)
	for side: float in [-1.0, 1.0]:
		var shoulder: Array[Vector2] = [Vector2(side * neck, eaves)]
		for i in range(7):
			var turn := float(i) / 6.0 * PI * 0.5
			shoulder.append(Vector2(side * (neck + 1.6 * cos(turn)), eaves + 0.4 + 1.5 * sin(turn)))
		shoulder.append(Vector2(side * neck, eaves + 1.9))
		_slab(FRAME, shoulder, -0.4, 0.05)
		_part_box(FRAME, Vector3(side * (neck + 0.08), (eaves + top) * 0.5, 0.06), Vector3(0.16, top - eaves, 0.12))
	_slab(FRAME, [Vector2(-neck - 0.3, top), Vector2(neck + 0.3, top), Vector2(0.0, top + 1.1)], -0.45, 0.1)
	_part_box(FRAME, Vector3(0, top + 0.06, 0.12), Vector3(neck * 2.0 + 0.6, 0.12, 0.25))
	# The sticker of Unmuted in the gable, and over it the hoisting beam.
	_label(STICKER, Vector3(0, eaves + 1.85, 0.07), Vector3.BACK, Vector3.RIGHT, 3.2, 1.6)
	_part_box(BLACK, Vector3(0, top - 0.55, 0.45), Vector3(0.22, 0.22, 1.1))
	_part_box(BLACK, Vector3(0, top - 0.85, 0.92), Vector3(0.04, 0.5, 0.04))
	_boxes.append([Vector3(0, (eaves + top) * 0.5, -0.2), Vector3(neck * 2.0 + 3.2, top - eaves, 0.5)])

	# The roof behind the gable, its ridge front to back, and the back of it.
	var ridge := eaves + 4.0
	for side: float in [-1.0, 1.0]:
		var st := _tool(ROOF, 0, Vector3.ZERO)
		var a := Vector3(side * (wide * 0.5 + 0.2), eaves, 0.0)
		var b := Vector3(0.0, ridge, 0.0)
		var normal := Vector3(side * 4.0, wide * 0.5, 0.0).normalized()
		_quad_face(st, [a + Vector3(0, 0, -deep - 0.2), a + Vector3(0, 0, -0.3), b + Vector3(0, 0, -0.3), b + Vector3(0, 0, -deep - 0.2)], normal)
	_slab(BRICK, [Vector2(-wide * 0.5, eaves), Vector2(wide * 0.5, eaves), Vector2(0.0, ridge)], -deep, -deep + 0.3)
	_slab(BRICK, [Vector2(-wide * 0.5, eaves), Vector2(wide * 0.5, eaves), Vector2(0.0, ridge)], -1.2, -0.45)
	tag("collide", _boxes)
	tag("door", Vector3(0, 0, 1.5))


func _doomscroll_hell() -> void:
	model("doomscroll_hell")
	_boxes = []
	var wide := 14.0
	var high := 11.5
	var deep := 12.0
	_solid(BLACK, Vector3(0, (high - SUNK) * 0.5, -deep * 0.5), Vector3(wide, high + SUNK, deep))
	# A parapet that stands proud of the front.
	_part_box(BLACK, Vector3(0, high + 0.3, 0.1), Vector3(wide + 0.4, 0.6, 0.6))
	# The words, glowing red.
	_label("doomscroll_sign", Vector3(0, 9.25, 0.04), Vector3.BACK, Vector3.RIGHT, 12.4, 12.4 * 330.0 / 2048.0)
	_label("doomscroll_hell", Vector3(0, 6.6, 0.04), Vector3.BACK, Vector3.RIGHT, 6.6, 6.6 * 420.0 / 1024.0)
	# The door, glowing, in a black frame that stands out of the wall.
	_part_box(GLOW, Vector3(0, 1.65, 0.02), Vector3(2.4, 3.3, 0.04))
	for side: float in [-1.0, 1.0]:
		_part_box(BLACK, Vector3(side * 1.35, 1.75, 0.15), Vector3(0.3, 3.5, 0.3))
	_part_box(BLACK, Vector3(0, 3.55, 0.15), Vector3(3.0, 0.3, 0.3))
	# Four phones, a feed on each, in a bezel.
	for x: float in [-5.6, -3.4, 3.4, 5.6]:
		var at := Vector3(x, 2.5, 0.0)
		_label("doomscroll_feed", at + Vector3(0, 0, 0.09), Vector3.BACK, Vector3.RIGHT, 1.3, 2.6)
		_frame(at - Vector3(0, 1.3, 0), Vector2(1.3, 2.6), 0.12, BLACK)
	# Red neon along the edges of the front and under the parapet.
	_part_box(GLOW, Vector3(0, high - 0.05, 0.42), Vector3(wide + 0.3, 0.07, 0.07))
	for side: float in [-1.0, 1.0]:
		_part_box(GLOW, Vector3(side * (wide * 0.5 + 0.02), high * 0.5, 0.02), Vector3(0.07, high, 0.07))
	_part_box(GLOW, Vector3(0, 4.4, 0.03), Vector3(wide - 1.0, 0.06, 0.06))
	tag("collide", _boxes)
	tag("door", Vector3(0, 0, 1.5))


## A box that is in the way as well: it goes into "collide".
func _solid(mat: String, center: Vector3, size: Vector3) -> void:
	_part_box(mat, center, size)
	_boxes.append([center, size])


func _part_box(mat: String, center: Vector3, size: Vector3) -> void:
	_box(mat, Transform3D(Basis(), center), size, NO_COLLIDE)


## A sash window of the house: dark glass, a white frame round it, a bar
## down the middle and one across where the sashes meet, and a sill.
func _sash(foot: Vector3, size: Vector2) -> void:
	_part_box(WINDOW, foot + Vector3(0, size.y * 0.5, 0.025), Vector3(size.x, size.y, 0.03))
	_frame(foot, size, 0.12)
	_part_box(FRAME, foot + Vector3(0, size.y * 0.55, 0.07), Vector3(size.x, 0.07, 0.05))
	_part_box(FRAME, foot + Vector3(0, size.y * 0.5, 0.06), Vector3(0.05, size.y, 0.04))
	_part_box(FRAME, foot + Vector3(0, -0.06, 0.1), Vector3(size.x + 0.3, 0.1, 0.2))


## A frame `bar` wide round an opening `size` big that stands on `foot`.
func _frame(foot: Vector3, size: Vector2, bar: float, mat := FRAME) -> void:
	var middle := foot + Vector3(0, size.y * 0.5, 0.06)
	for side: float in [-1.0, 1.0]:
		_part_box(mat, middle + Vector3(side * (size.x + bar) * 0.5, 0, 0), Vector3(bar, size.y + bar * 2.0, 0.1))
		_part_box(mat, middle + Vector3(0, side * (size.y + bar) * 0.5, 0), Vector3(size.x, bar, 0.1))


## A flat piece cut to the outline `outline` (x, y; convex) from z0 to z1.
func _slab(mat: String, outline: Array, z0: float, z1: float) -> void:
	var st := _tool(mat, 0, Vector3.ZERO)
	var count := outline.size()
	var middle := Vector2.ZERO
	for p: Vector2 in outline:
		middle += p / float(count)
	for i in count:
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % count]
		for z: float in [z0, z1]:
			var n := Vector3.BACK if z == z1 else Vector3.FORWARD
			var pts := [Vector3(middle.x, middle.y, z), Vector3(a.x, a.y, z), Vector3(b.x, b.y, z)]
			_face(st, pts, [n, n, n], [Vector2(middle.x, -middle.y), Vector2(a.x, -a.y), Vector2(b.x, -b.y)])
		var along := b - a
		var out := Vector2(along.y, -along.x).normalized()
		if out.dot(a - middle) < 0.0:
			out = -out
		var n3 := Vector3(out.x, out.y, 0.0)
		_quad_face(st, [Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1)], n3)


## Two triangles over four corners in order, facing along `normal`; the
## texture laid on in metres.
func _quad_face(st: SurfaceTool, p: Array, normal: Vector3) -> void:
	var u := (p[1] - p[0] as Vector3).normalized()
	var v := normal.cross(u)
	var uv := p.map(func(q: Vector3) -> Vector2: return Vector2(q.dot(u), -q.dot(v)))
	var n := [normal, normal, normal]
	_face(st, [p[0], p[1], p[2]], n, [uv[0], uv[1], uv[2]])
	_face(st, [p[0], p[2], p[3]], n, [uv[0], uv[2], uv[3]])


## A picture of the material `mat` on a quad `width` by `height`, facing
## along `normal` with its top up, as in tools/models/weapons.gd.
func _label(mat: String, center: Vector3, normal: Vector3, along: Vector3, width: float, height: float) -> void:
	var up := normal.cross(along).normalized()
	if up.dot(Vector3.UP) < 0.0:
		up = -up
	var a := along * width * 0.5
	var b := up * height * 0.5
	var st := _tool(mat, 0, center)
	var n := [normal, normal, normal]
	_face(st, [center - a - b, center + a - b, center + a + b], n, [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)])
	_face(st, [center - a - b, center + a + b, center - a + b], n, [Vector2(0, 1), Vector2(1, 0), Vector2(0, 0)])
