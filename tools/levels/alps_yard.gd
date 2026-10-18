extends "res://tools/kit.gd"
## The yard of the Alps: what tools/kit/alpine.gd builds, a few of each, on a
## flat meadow under the light of scenes/alps.tscn, to be looked at from
## every side without building the valley. Build with
## tools/build_level.sh alps_yard, then look with
## tools/benchmark.sh --quick --scene=res://scenes/alps_yard.tscn --res=1920x1080 --at="8,+1.7,24,-150,-4"
##
## The meadow is a strip from west to east. In its west end, north of the
## middle, stand the barns in the sun: the three sizes of log barn in a row
## facing south, and behind them, facing north, the three sizes of board
## barn; east of them one on the side of a mound. South of the barns the
## farmhouse, the chapel and the small things. A wall that throws a shadow
## and is not seen (in the scene, not here) keeps the sun off a second row in
## the south-west corner: a barn of each kind and the rest once more. And a
## barn of logs stands 300 m and one 1500 m east of the first, for the
## distances a valley is looked across.

## Where the row in the shade begins.
const SHADE := Vector2(-40, -150)


func _level_name() -> String:
	return "alps_yard"


func _describe() -> void:
	land(Rect2(-160, -220, 1860, 420), 100.0, 2.0, 0.5)
	sun_at(230.0, 11.5)
	mound(Vector2(80, 60), 22.0, 3.5)
	dig([Vector2(70, 33.5), Vector2(112, 33.5)], 1.2, 3.5)
	lay_ground("alpine_meadow")
	_alp_tally = true

	# The barns in the sun.
	hay_barn(Vector2(0, 0), 0.0, "small", "logs", "boards", "stones")
	hay_barn(Vector2(15, 0), 0.0, "middle", "logs", "shingles", "stones")
	hay_barn(Vector2(32, 0), 0.0, "large", "logs", "tin", "stones")
	hay_barn(Vector2(0, -22), 180.0, "small", "boards", "tin", "blocks")
	hay_barn(Vector2(15, -22), 180.0, "middle", "boards", "boards", "blocks")
	hay_barn(Vector2(32, -22), 180.0, "large", "boards", "shingles", "stones")
	hay_barn(Vector2(74, 56), 35.0, "middle", "logs", "boards", "stones")

	# The farmhouse, the chapel and what stands by the way.
	farmhouse(Vector2(15, 48), 0.0)
	chapel(Vector2(56, 18), 15.0)
	wayside_cross(Vector2(44, 32), 0.0)
	marterl(Vector2(48, 31), -20.0)
	hunting_stand(Vector2(-28, 30), 0.0)
	slant_fence([Vector2(-45, 66), Vector2(-10, 72), Vector2(30, 70)])
	rail_fence([Vector2(-45, 80), Vector2(0, 84), Vector2(30, 82)])
	for i in 5:
		hay_pole(Vector2(58 + i * 3.2, 44 + (i % 2) * 0.8))
	woodpile(Vector2(42, 48), 0.0)
	footbridge(Vector2(92, 29), Vector2(92, 38))
	trough(Vector2(48, 55), 10.0)
	pole_line([Vector2(-120, -60), Vector2(-76, -61), Vector2(-32, -63), Vector2(12, -61), Vector2(56, -58), Vector2(100, -57)])

	# The same in the shade.
	hay_barn(SHADE + Vector2(0, 0), 0.0, "middle", "logs", "shingles", "stones")
	hay_barn(SHADE + Vector2(16, 0), 0.0, "large", "boards", "tin", "blocks")
	chapel(SHADE + Vector2(36, 0), 0.0)
	farmhouse(SHADE + Vector2(70, -25), 0.0)
	hunting_stand(SHADE + Vector2(-20, -10), 0.0)
	wayside_cross(SHADE + Vector2(0, -16), 0.0)
	marterl(SHADE + Vector2(4, -16), 0.0)
	woodpile(SHADE + Vector2(10, -18), 0.0)
	trough(SHADE + Vector2(18, -18), 0.0)
	hay_pole(SHADE + Vector2(26, -18))

	# Afar.
	hay_barn(Vector2(15 + 300, 0), -90.0, "middle", "logs", "shingles", "stones")
	hay_barn(Vector2(15 + 1500, -40), -90.0, "middle", "logs", "tin", "stones")
