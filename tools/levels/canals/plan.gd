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
## How wide a canal, a quay and a street are is as it is in the town,
## measured on the map (the BGT of 14 October 2026, between the two axes);
## how deep a block is and how far the axes lie apart has been brought down
## to two thirds. Every measure is here, so that a map changes this file
## alone. Where the town is not as the plan has it: the canals bend at the
## Nieuwe Spiegelstraat and run straight here; the Nieuwe Spiegelstraat
## crosses them at 74 degrees and not square; the Lijnbaansgracht runs
## askew to the south-east; and the Weteringbuurt has three cross streets
## and the Weteringstraat where this has one.
## Every file of the level extends this one, and each builds one stretch:
## its paving, its water, the fronts that look out on it and what stands in
## it. See "De grachten" in PLAN.md.

## The level from west to east and from north to south.
const WEST_END := 0.0
const EAST_END := 216.0
const SOUTH_END := 470.6
## A canal from north to south: the fronts on its north side, the two edges
## of its water, and the fronts on its south side. On the map the
## Herengracht has 24.6 m of water between quays of 10.6 and 10.2 m, the
## Keizersgracht 27.4 m between 10.9 and 11.3 m, the Prinsengracht 24.5 m
## between 10.1 and 10.1 m.
const HEREN: Array[float] = [0.0, 10.6, 35.2, 45.4]
const KEIZERS: Array[float] = [118.4, 129.3, 156.7, 168.0]
const PRINSEN: Array[float] = [266.1, 276.2, 300.7, 310.8]
## The Lijnbaansgracht: a quay of 8 m on its north side, 22 m of water, and
## on its south side the Weteringschans, as far as the level goes.
const LIJNBAAN: Array[float] = [416.6, 424.6, 446.6, SOUTH_END]
## The two streets that cut across from one axis to the other, each from its
## north fronts to its south fronts: the Kerkstraat is 10.7 m, the Tweede
## Weteringdwarsstraat 8.6 m.
const KERK: Array[float] = [211.7, 222.4]
const DWARS: Array[float] = [359.4, 368.0]
## The Nieuwe Spiegelstraat from its west fronts to its east fronts (10 to
## 12.6 m on the map), and the Spiegelgracht it runs on as: fronts, water,
## water, fronts (36 m, of which 15.3 m water).
const SPIEGEL_X := 40.0
const SPIEGELSTRAAT: Array[float] = [34.5, 45.5]
const SPIEGELGRACHT: Array[float] = [22.0, 32.35, 47.65, 58.0]
## The Vijzelstraat (23 to 25 m), and the Vijzelgracht it runs on as (35.6 m).
const VIJZEL_X := 180.0
const VIJZELSTRAAT: Array[float] = [168.0, 192.0]
const VIJZELGRACHT: Array[float] = [162.2, 197.8]
## Where the axes cross each great canal: x, how wide the bridge is along
## the canal, and how far its crown rises over the quays. High enough that
## whoever wades through the canal walks upright under it: see bridge(). The
## Nieuwe Spiegelstraat ends on the quay of the Herengracht: no bridge goes
## over it there. Those of the Vijzelstraat are 26 m wide on the map, and
## the one into the Vijzelgracht 38 m.
const HEREN_CROSSINGS: Array[Array] = [[VIJZEL_X, 26.0, 1.2]]
const KEIZERS_CROSSINGS: Array[Array] = [[SPIEGEL_X, 9.0, 1.5], [VIJZEL_X, 26.0, 1.2]]
const PRINSEN_CROSSINGS: Array[Array] = [[SPIEGEL_X, 9.0, 1.5], [VIJZEL_X, 36.0, 1.2]]
## How deep a house is from front to back: on a canal, and on a side street.
const DEEP := 12.0
const DEEP_STREET := 10.0
## How far from the edge of the water the line of trees, lanterns and parked
## cars runs: on the map the lanterns and the elms stand 2 to 3 m from it.
const KERB := 2.3
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
	"a_west": Rect2(WEST_END, HEREN[3], SPIEGELSTRAAT[0] - WEST_END, KEIZERS[0] - HEREN[3]),
	"a_mid": Rect2(SPIEGELSTRAAT[1], HEREN[3], VIJZELSTRAAT[0] - SPIEGELSTRAAT[1], KEIZERS[0] - HEREN[3]),
	"a_east": Rect2(VIJZELSTRAAT[1], HEREN[3], EAST_END - VIJZELSTRAAT[1], KEIZERS[0] - HEREN[3]),
	"b_west": Rect2(WEST_END, KEIZERS[3], SPIEGELSTRAAT[0] - WEST_END, PRINSEN[0] - KEIZERS[3]),
	"b_mid": Rect2(SPIEGELSTRAAT[1], KEIZERS[3], VIJZELSTRAAT[0] - SPIEGELSTRAAT[1], KERK[0] - KEIZERS[3]),
	"c_mid": Rect2(SPIEGELSTRAAT[1], KERK[1], VIJZELSTRAAT[0] - SPIEGELSTRAAT[1], PRINSEN[0] - KERK[1]),
	"b_east": Rect2(VIJZELSTRAAT[1], KEIZERS[3], EAST_END - VIJZELSTRAAT[1], PRINSEN[0] - KEIZERS[3]),
	"d_west": Rect2(WEST_END, PRINSEN[3], SPIEGELGRACHT[0] - WEST_END, LIJNBAAN[0] - PRINSEN[3]),
	"d_mid": Rect2(SPIEGELGRACHT[3], PRINSEN[3], VIJZELGRACHT[0] - SPIEGELGRACHT[3], DWARS[0] - PRINSEN[3]),
	"e_mid": Rect2(SPIEGELGRACHT[3], DWARS[1], VIJZELGRACHT[0] - SPIEGELGRACHT[3], LIJNBAAN[0] - DWARS[1]),
	"d_east": Rect2(VIJZELGRACHT[1], PRINSEN[3], EAST_END - VIJZELGRACHT[1], LIJNBAAN[0] - PRINSEN[3]),
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
func great_canal(lines: Array[float], crossings: Array[Array], mouths: Array = []) -> void:
	long_canal(lines, mouths)
	for crossing: Array in crossings:
		var from := Vector3(crossing[0], 0, lines[2] + 1.0)
		var to := Vector3(crossing[0], 0, lines[1] - 1.0)
		bridge(from, to, crossing[1], crossing[2])
		bridge_lanterns(from, to, crossing[1])
	# Steps down to the water, for whoever falls in: in every stretch of it
	# between two bridges, or between a bridge and the end of the level, one
	# on either quay. Where they come up, nothing stands at the kerb.
	var steps := PackedVector3Array()
	var ends: Array[float] = [WEST_END]
	for crossing: Array in crossings:
		ends.append_array([crossing[0] - crossing[1] * 0.5, crossing[0] + crossing[1] * 0.5])
	ends.append(EAST_END)
	for i in range(0, ends.size(), 2):
		# The water lies south of the north quay and north of the south one.
		var north := Vector3(lerpf(ends[i], ends[i + 1], 0.35), 0, lines[1])
		var south := Vector3(lerpf(ends[i], ends[i + 1], 0.65), 0, lines[2])
		water_steps(north, 0.0)
		water_steps(south, 180.0)
		steps.append_array([north, south])
	# The kerb stops short of every bridge, for the lanterns on its corners.
	var stops: Array = []
	for crossing: Array in crossings:
		stops.append([crossing[0] - crossing[1] * 0.5 - 3.0, crossing[0] + crossing[1] * 0.5 + 3.0])
	stops.append([EAST_END - 3.0, EAST_END])
	for z: float in [lines[1] - KERB, lines[2] + KERB]:
		var x := WEST_END + 3.0
		for stop: Array in stops:
			var until: float = stop[0]
			# A quay stops at the mouth of a canal that runs into it.
			for mouth: Array in mouths:
				if z > lines[2] and mouth[0] < until and mouth[1] > x:
					until = minf(until, mouth[0] - 1.0)
			if until - x > 8.0:
				kerb_line(Vector3(x, 0, z), Vector3(until, 0, z), "ritter", 0.6, steps)
			x = stop[1]
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
