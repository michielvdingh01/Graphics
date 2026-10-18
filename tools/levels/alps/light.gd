extends RefCounted
## What the sun and the sky do to land of kilometres, worked out once when the
## level is built: where the sun does not come, and how much of the sky a spot
## sees. The game draws the sun's shadow itself only close by; further off the
## ground and what grows on it read these maps (shaders/alps_ground.gdshader).
##
## A grid is a row after row of heights (north to south), `cell` metres apart.

## Half the width of the sun as a slope: the edge of a shadow is as soft as the
## distance to what throws it times twice this.
const SUN_RADIUS := 0.0047


## How much of the sun reaches each spot of the grid, 0 to 1, with the sun
## that way (`to_sun`, from the ground). What stands in its way is
## `occluders` where given, a grid of the same size as high as the ground or
## higher (the crown of a tree, a roof), and the ground itself where not.
##
## The grid is gone through from the side of the sun, so that the spot two
## cells nearer the sun than any other has been done before it. For each spot
## the line from it to the sun lies under the horizon of the spot nearer the
## sun, lowered by the slope of the sun over the two cells between: whatever
## blocks the sun there, blocks it here, or not, and a crest there is a new
## horizon. How far off what throws the shadow lies is carried along the same
## way, for the softness of its edge.
static func sun(heights: PackedFloat32Array, across: int, down: int, cell: float, to_sun: Vector3, occluders := PackedFloat32Array()) -> PackedFloat32Array:
	var blockers := occluders if occluders.size() == heights.size() else heights
	var flat := Vector2(to_sun.x, to_sun.z).normalized()
	var rise := to_sun.y / Vector2(to_sun.x, to_sun.z).length()
	var step := 2.0 * cell
	var back := flat * 2.0
	var count := across * down
	var horizon := PackedFloat32Array()
	horizon.resize(count)
	horizon.fill(-1e9)
	var reach := PackedFloat32Array()
	reach.resize(count)
	reach.fill(1e6)
	var lit := PackedFloat32Array()
	lit.resize(count)
	var columns := range(across) if flat.x < 0.0 else range(across - 1, -1, -1)
	var rows := range(down) if flat.y < 0.0 else range(down - 1, -1, -1)
	for row: int in rows:
		for column: int in columns:
			var i := row * across + column
			var q := Vector2(column, row) + back
			var h := -1e9
			var d := 1e6
			if q.x >= 0.0 and q.y >= 0.0 and q.x <= across - 1 and q.y <= down - 1:
				var c0 := mini(int(q.x), across - 2)
				var r0 := mini(int(q.y), down - 2)
				var u := q.x - c0
				var v := q.y - r0
				var a := r0 * across + c0
				var block := lerpf(lerpf(blockers[a], blockers[a + 1], u), lerpf(blockers[a + across], blockers[a + across + 1], u), v)
				var beyond := lerpf(lerpf(horizon[a], horizon[a + 1], u), lerpf(horizon[a + across], horizon[a + across + 1], u), v)
				var far := lerpf(lerpf(reach[a], reach[a + 1], u), lerpf(reach[a + across], reach[a + across + 1], u), v)
				if block >= beyond:
					h = block
					d = step
				else:
					h = beyond
					d = far + step
			h -= step * rise
			horizon[i] = h
			reach[i] = d
			var soft := maxf(cell * 0.5, d * SUN_RADIUS)
			lit[i] = smoothstep(-soft, soft, heights[i] + 0.3 - h)
	return lit


## How much of the sky each spot sees, about: one where it lies level with
## all round it, less the deeper it lies below what is around it, at three
## sizes of round.
static func open_sky(heights: PackedFloat32Array, across: int, down: int, cell: float) -> PackedFloat32Array:
	var open := PackedFloat32Array()
	open.resize(heights.size())
	open.fill(1.0)
	for reach_m: float in [12.0, 60.0, 300.0]:
		var reach := maxi(1, roundi(reach_m / cell))
		var around := evened(heights, across, down, reach)
		for i in heights.size():
			var deep := maxf(0.0, around[i] - heights[i]) / (reach * cell)
			open[i] *= 1.0 - clampf(deep * 1.6, 0.0, 0.6)
	return open


## The grid with each value the mean of those within `reach` cells of it, as
## a box: a pass along the rows and one down the columns, each a running sum.
static func evened(values: PackedFloat32Array, across: int, down: int, reach: int) -> PackedFloat32Array:
	var rows := PackedFloat32Array()
	rows.resize(values.size())
	for row in down:
		var sum := 0.0
		var n := 0
		var first := row * across
		for column in range(-reach, across + reach):
			if column + reach < across:
				sum += values[first + column + reach]
				n += 1
			if column - reach - 1 >= 0:
				sum -= values[first + column - reach - 1]
				n -= 1
			if column >= 0 and column < across:
				rows[first + column] = sum / n
	var both := PackedFloat32Array()
	both.resize(values.size())
	for column in across:
		var sum := 0.0
		var n := 0
		for row in range(-reach, down + reach):
			if row + reach < down:
				sum += rows[(row + reach) * across + column]
				n += 1
			if row - reach - 1 >= 0:
				sum -= rows[(row - reach - 1) * across + column]
				n -= 1
			if row >= 0 and row < down:
				both[row * across + column] = sum / n
	return both
