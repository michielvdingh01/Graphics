extends "res://tools/levels/factory/plan.gd"
## The way from the storeroom of the annex to the boiler house: north out of
## the annex, then east. With the bend in it, nobody in the annex looks into
## the boiler house or the other way round, so only one of the two is ever
## drawn.


func _describe() -> void:
	var height := PASSAGE_H
	# Two legs, each 2.4 m wide: north from the storeroom, then east.
	box("floor", Vector3(24.7, -0.25, -15.5), Vector3(2.8, 0.5, 6.2))
	box("floor", Vector3(27.55, -0.25, -17.2), Vector3(2.9, 0.5, 2.8))
	box("concrete", Vector3(24.7, height + 0.125, -15.5), Vector3(2.8, 0.25, 6.2))
	box("concrete", Vector3(27.55, height + 0.125, -17.2), Vector3(2.9, 0.25, 2.8))
	wall(WALL, false, 23.4, 0.2, -18.6, -12.4, 0.0, height, [])
	wall(WALL, true, -18.5, 0.2, 23.5, 29.0, 0.0, height, [])
	wall(WALL, false, 26.0, 0.2, -15.8, -12.4, 0.0, height, [])
	wall(WALL, true, -15.9, 0.2, 25.9, 29.0, 0.0, height, [])
	# Shut at both ends while its lightmap is baked.
	bake_blocker(Vector3(24.7, 1.55, -12.41), Vector3(2.6, 3.1, 0.02))
	bake_blocker(Vector3(28.99, 1.55, -17.2), Vector3(0.02, 3.1, 2.6))

	tube(Vector3(24.7, height - 0.08, -14.2), false, true, true, 5.0)
	tube(Vector3(27.4, height - 0.08, -17.2), true, true, true, 4.5)
	# Conduit along the ceiling from one fitting to the next, and a pipe that
	# follows the passage round the corner above head height.
	var small := DETAIL | NO_COLLIDE
	hose("galvanised", PackedVector3Array([
		Vector3(24.3, height - 0.03, -12.5), Vector3(24.3, height - 0.03, -17.0), Vector3(24.45, height - 0.03, -17.6), Vector3(25.1, height - 0.03, -17.75), Vector3(28.9, height - 0.03, -17.75),
	]), 0.012, small, 6)
	hose("pipe", PackedVector3Array([
		Vector3(23.62, 2.45, -12.5), Vector3(23.62, 2.45, -17.7), Vector3(23.7, 2.45, -18.15), Vector3(24.2, 2.45, -18.28), Vector3(28.95, 2.45, -18.28),
	]), 0.05, NO_COLLIDE, 10)
	for at: Vector3 in [Vector3(23.62, 2.45, -13.6), Vector3(23.62, 2.45, -16.0), Vector3(25.8, 2.45, -18.28), Vector3(28.2, 2.45, -18.28)]:
		box("dark_steel", at + Vector3(0, 0.07, 0), Vector3(0.14, 0.03, 0.14), Vector3.ZERO, small)
	# Nothing stands in the way through: what there is, is in the far corner.
	place("korean_fire_extinguisher_01", Vector3(23.7, 0, -17.6), 90)
	place("cardboard_box_01", Vector3(24.0, 0, -18.1), 25)
	drop("plastic_broom", Vector3(25.8, 0, -13.4), -90)

	probe("Passage", Vector3(25.0, 1.5, -15.8), Vector3(3.4, 3.0, 5.2), Vector3(-0.3, 0, 1.0))
	wall_decal("grime", Vector3(23.52, 0.5, -15.4), Vector3.RIGHT, 5.8, 1.0)
	floor_decal("stain_2", Vector3(26.8, 0, -17.2), Vector2(3.0, 1.8), 5)
	# The way in from the boiler house goes round the bend.
	floor_arrow(Vector2(27.4, -17.2), Vector2.LEFT)
	floor_arrow(Vector2(24.7, -14.6), Vector2.DOWN)


func _route_through() -> void:
	route_checkpoint("passage", "Passage", Vector3(27.6, 0, -17.2), Vector3(24.0, 0, -17.2), AABB(Vector3(23.5, 0, -18.4), Vector3(5.5, PASSAGE_H, 6.0)))
