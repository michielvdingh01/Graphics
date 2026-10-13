extends "res://tools/kit.gd"
## The plan of the canals: the middle of Amsterdam by night, between the
## Herengracht in the north and the Lijnbaansgracht in the south, and between
## two streets that cross every canal on the way: the Nieuwe Spiegelstraat,
## which runs on south as the Spiegelgracht, and the Vijzelstraat, which runs
## on as the Vijzelgracht, a canal filled in long ago.
##
##        0   35 45                     169  191  216
##      0 +-----------------------------------+-----+   north is up
##        |  ===== Herengracht: the Golden Bend ====|
##     47 +----+  +---------------------+    +------+
##        |    |Sp|                     | Vi |      |
##    113 +----+  +---------------------+    +------+
##        |  ============= Keizersgracht ===========|
##    162 +----+  +---------------------+    +------+
##        |    |ie|---- Kerkstraat -----| jz |      |
##    244 +----+  +---------------------+    +------+
##        |  ============= Prinsengracht ===========|
##    287 +--+      +-----------------+        +----+
##        |  |Spieg.|- Weteringdwars -| Vijzel |    |
##        |  |gracht|                 | gracht |    |
##    396 +--+      +-----------------+ [metro]+----+
##        |  ===== Lijnbaansgracht =====            |
##    440 +--------- start ---------- Weteringschans+
##
## The player comes from the museum in the south, over the Lijnbaansgracht,
## and goes round by the west: up the Spiegelgracht and the Nieuwe
## Spiegelstraat to the Herengracht, east along the Golden Bend, and back
## south down the Vijzelstraat to the metro on the Vijzelgracht, which is the
## way out. The Kerkstraat and the Weteringdwarsstraat cut across.
##
## How wide a canal and its quays are is as it is in the town, as near as
## that is known without a map; how long a block is has been brought down to
## two thirds. Every measure is here, so that a map changes this file alone.
## Every file of the level extends this one, and each builds one stretch:
## its paving, its water, the fronts that look out on it and what stands in
## it. See "De grachten" in PLAN.md.

## The level from west to east and from north to south.
const WEST_END := 0.0
const EAST_END := 216.0
const SOUTH_END := 440.0
## A canal from north to south: the fronts on its north side, the two edges
## of its water, and the fronts on its south side.
const HEREN: Array[float] = [0.0, 10.5, 36.5, 47.0]
const KEIZERS: Array[float] = [113.0, 123.5, 151.5, 162.0]
const PRINSEN: Array[float] = [244.0, 253.5, 277.5, 287.0]
## The Lijnbaansgracht, a narrow one: its south side is the Weteringschans,
## as far as the level goes.
const LIJNBAAN: Array[float] = [396.0, 404.0, 416.0, SOUTH_END]
## The two streets that cut across from one axis to the other, each from its
## north fronts to its south fronts.
const KERK: Array[float] = [200.0, 208.0]
const DWARS: Array[float] = [335.0, 342.0]
## The Nieuwe Spiegelstraat from its west fronts to its east fronts, and the
## Spiegelgracht it runs on as: fronts, water, water, fronts.
const SPIEGEL_X := 40.0
const SPIEGELSTRAAT: Array[float] = [35.0, 45.0]
const SPIEGELGRACHT: Array[float] = [25.5, 34.0, 46.0, 54.5]
## The Vijzelstraat, and the Vijzelgracht it runs on as.
const VIJZEL_X := 180.0
const VIJZELSTRAAT: Array[float] = [169.0, 191.0]
const VIJZELGRACHT: Array[float] = [162.0, 198.0]
## How deep a house is from front to back: on a canal, and on a side street.
const DEEP := 12.0
const DEEP_STREET := 10.0
## How far from the edge of the water the line of trees, lanterns and parked
## cars runs.
const KERB := 1.4
## From how far under the street to how far over it a zone reaches: over the
## lanterns, and under the roofs, so that no zone is seen over a row of
## houses by a builder that looks for lines of sight.
const ZONE_FROM := -4.0
const ZONE_HIGH := 16.0
## How large a texel of lightmap is here, in metres: twice that of a level
## by day. What is sharp by night is the light of a lantern, and that is not
## baked; what is baked is what the street throws back and the glow of the
## windows, and both are soft.
const TEXEL_NIGHT := 0.16
## How far anything shows by night, in the mist the town lies in: a zone
## farther off than this is not drawn. The streets run straight from the
## Herengracht to the museum, and without this every zone would see every
## other one.
const SIGHT := 130.0
## The blocks of houses between the streets, x and z, from north to south
## and from west to east.
const BLOCKS := {
	"a_west": Rect2(0, 47, 35, 66), "a_mid": Rect2(45, 47, 124, 66), "a_east": Rect2(191, 47, 25, 66),
	"b_west": Rect2(0, 162, 35, 82), "b_mid": Rect2(45, 162, 124, 38), "c_mid": Rect2(45, 208, 124, 36), "b_east": Rect2(191, 162, 25, 82),
	"d_west": Rect2(0, 287, 25.5, 109), "d_mid": Rect2(54.5, 287, 107.5, 48), "e_mid": Rect2(54.5, 342, 107.5, 54), "d_east": Rect2(198, 287, 18, 109),
}


func _level_name() -> String:
	return "canals"


## Lays the plan down before anything is built: the zones, one for every
## stretch of canal or street. A canal is one zone from end to end, with both
## its quays and the bridges over it; a street is one from canal to canal.
func _plan() -> void:
	_sight_reach = SIGHT
	# What has no lightmap is lit by the lanterns as they are; one sample of
	# what the street throws back will do for a block of it.
	_detail_block = Vector3(36, 400, 36)
	_texel = TEXEL_NIGHT
	_zone("heren", Rect2(WEST_END, HEREN[0], EAST_END - WEST_END, HEREN[3] - HEREN[0]))
	_zone("spiegelstraat_north", Rect2(SPIEGELSTRAAT[0], HEREN[3], SPIEGELSTRAAT[1] - SPIEGELSTRAAT[0], KEIZERS[0] - HEREN[3]))
	_zone("vijzelstraat_north", Rect2(VIJZELSTRAAT[0], HEREN[3], VIJZELSTRAAT[1] - VIJZELSTRAAT[0], KEIZERS[0] - HEREN[3]))
	_zone("keizers", Rect2(WEST_END, KEIZERS[0], EAST_END - WEST_END, KEIZERS[3] - KEIZERS[0]))
	_zone("spiegelstraat_south", Rect2(SPIEGELSTRAAT[0], KEIZERS[3], SPIEGELSTRAAT[1] - SPIEGELSTRAAT[0], PRINSEN[0] - KEIZERS[3]))
	_zone("kerkstraat", Rect2(SPIEGELSTRAAT[1], KERK[0], VIJZELSTRAAT[0] - SPIEGELSTRAAT[1], KERK[1] - KERK[0]))
	_zone("vijzelstraat_south", Rect2(VIJZELSTRAAT[0], KEIZERS[3], VIJZELSTRAAT[1] - VIJZELSTRAAT[0], PRINSEN[0] - KEIZERS[3]))
	_zone("prinsen", Rect2(WEST_END, PRINSEN[0], EAST_END - WEST_END, PRINSEN[3] - PRINSEN[0]))
	_zone("spiegelgracht", Rect2(SPIEGELGRACHT[0], PRINSEN[3], SPIEGELGRACHT[3] - SPIEGELGRACHT[0], LIJNBAAN[0] - PRINSEN[3]))
	_zone("weteringdwars", Rect2(SPIEGELGRACHT[3], DWARS[0], VIJZELGRACHT[0] - SPIEGELGRACHT[3], DWARS[1] - DWARS[0]))
	_zone("vijzelgracht", Rect2(VIJZELGRACHT[0], PRINSEN[3], VIJZELGRACHT[1] - VIJZELGRACHT[0], LIJNBAAN[0] - PRINSEN[3]))
	_zone("lijnbaan", Rect2(WEST_END, LIJNBAAN[0], EAST_END - WEST_END, LIJNBAAN[3] - LIJNBAAN[0]))


func _zone(zone_name: String, area: Rect2) -> void:
	zone(zone_name, [AABB(Vector3(area.position.x, ZONE_FROM, area.position.y), Vector3(area.size.x, ZONE_HIGH - ZONE_FROM, area.size.y))])


## The row of houses on one side of a block: "n", "s", "w" or "e". A row on
## a canal, to the north or the south, runs from corner to corner; one on a
## street between two canals begins `from_corner` in from the north corner
## and ends `to_corner` short of the south one, where the rows on the canals
## end and show the street their side walls.
func front(block: String, side: String, kind: String, fit := {}, from_corner := DEEP, to_corner := DEEP) -> void:
	var rect: Rect2 = BLOCKS[block]
	var deep := DEEP_STREET if kind == "street" else DEEP
	match side:
		"n":
			terrace(Vector2(rect.end.x, rect.position.y), rect.position, kind, deep, fit)
		"s":
			terrace(Vector2(rect.position.x, rect.end.y), rect.end, kind, deep, fit)
		"w":
			terrace(Vector2(rect.position.x, rect.position.y + from_corner), Vector2(rect.position.x, rect.end.y - to_corner), kind, deep, fit)
		"e":
			terrace(Vector2(rect.end.x, rect.end.y - to_corner), Vector2(rect.end.x, rect.position.y + from_corner), kind, deep, fit)


## A canal that runs from the west edge of the level to the east edge:
## `lines` are its fronts and the edges of its water, as HEREN has them. Its
## quays are paved and its water lies between them; at either end of the
## level a hoarding shuts the quays and the water. `mouths` are stretches of
## one quay, from x to x, where another canal runs into this one, and
## `mouth_side` is the quay they are in, "n" or "s": the quay and its wall
## stop there, for a bridge to carry the quay over.
func long_canal(lines: Array[float], mouths: Array = [], mouth_side := "s") -> void:
	canal(Rect2(WEST_END, lines[1], EAST_END - WEST_END, lines[2] - lines[1]), "wens")
	_quay(lines[0], lines[1], lines[1], mouths if mouth_side == "n" else [])
	_quay(lines[2], lines[3], lines[2], mouths if mouth_side == "s" else [])
	for edge: float in [WEST_END, EAST_END]:
		shut(Vector2(edge, lines[0]), Vector2(edge, lines[3]))


## One quay of such a canal, from `z0` to `z1`, and the wall it stands on
## along the water at `edge`, which is `z0` or `z1`, but for the `mouths`.
func _quay(z0: float, z1: float, edge: float, mouths: Array) -> void:
	var stops: Array = mouths.duplicate()
	stops.append([EAST_END, EAST_END])
	var x := WEST_END
	for mouth: Array in stops:
		if mouth[0] - x > 0.01:
			street_paving(Rect2(x, z0, mouth[0] - x, z1 - z0))
			if edge == z1:
				quay_wall(Vector2(x, edge), Vector2(mouth[0], edge))
			else:
				quay_wall(Vector2(mouth[0], edge), Vector2(x, edge))
		x = mouth[1]


## One of the three great canals with what each of them has: the water and
## the quays, a bridge where the Spiegel axis crosses it and a wider one
## where the Vijzel axis does, lanterns on the corners of both, and along
## the water on either quay the trees, the lanterns and the parked cars.
func great_canal(lines: Array[float], mouths: Array = []) -> void:
	long_canal(lines, mouths)
	var crossings := [[SPIEGEL_X, 9.0, 0.9], [VIJZEL_X, 20.0, 0.6]]
	for crossing: Array in crossings:
		var from := Vector3(crossing[0], 0, lines[2] + 1.0)
		var to := Vector3(crossing[0], 0, lines[1] - 1.0)
		bridge(from, to, crossing[1], crossing[2])
		bridge_lanterns(from, to, crossing[1])
	for z: float in [lines[1] - KERB, lines[2] + KERB]:
		var x := WEST_END + 3.0
		for stop: Array in [[SPIEGEL_X - 7.5, SPIEGEL_X + 7.5], [VIJZEL_X - 13.0, VIJZEL_X + 13.0], [EAST_END - 3.0, EAST_END]]:
			var until: float = stop[0]
			# A quay stops at the mouth of a canal that runs into it.
			for mouth: Array in mouths:
				if z > lines[2] and mouth[0] < until and mouth[1] > x:
					until = minf(until, mouth[0] - 1.0)
			if until - x > 8.0:
				kerb_line(Vector3(x, 0, z), Vector3(until, 0, z))
			x = stop[1]
	# Steps down to the water, for whoever falls in: two to a quay.
	for x: float in [WEST_END + 70.0, EAST_END - 70.0]:
		water_steps(Vector3(x, 0, lines[1]), 0.0)
		water_steps(Vector3(x + 20.0, 0, lines[2]), 180.0)
	# What the wet street mirrors, in three lengths.
	var third := (EAST_END - WEST_END) / 3.0
	for i in 3:
		var middle := Vector3(WEST_END + third * (i + 0.5), 7.0, (lines[0] + lines[3]) * 0.5)
		probe("%s%d" % [_zone_forced, i], middle, Vector3(third, 14.0 + 4.0, lines[3] - lines[0]), Vector3(0, -5.0, 0))


## Shuts the level off from `from` to `to`, x and z, across a quay or across
## water: a hoarding nobody looks or climbs over, from the bed of the canal
## up. What the town looks like beyond it is for later.
func shut(from: Vector2, to: Vector2) -> void:
	var middle := (from + to) * 0.5
	var size := (to - from).abs() + Vector2(0.4, 0.4)
	box("roof", Vector3(middle.x, 2.0 - CANAL_BED * 0.5, middle.y), Vector3(size.x, 4.0 + CANAL_BED, size.y))


## The four lanterns of a bridge, one at each corner: `from` and `to` as the
## bridge was given them, and its width.
func bridge_lanterns(from: Vector3, to: Vector3, width: float) -> void:
	var along := (to - from).normalized()
	var across := along.cross(Vector3.UP)
	for end: Vector3 in [from + along * 0.4, to - along * 0.4]:
		for side: float in [-1.0, 1.0]:
			lantern(Vector3(end.x, 0, end.z) + across * side * (width * 0.5 + 0.5), "crown")
