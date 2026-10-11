extends "res://tools/levels/factory/plan.gd"
## What makes the factory look as if people worked here until yesterday: fire
## points, fuel and oil by the machines, rubbish, boxes and chairs. One round
## of the hall and the annex, made after both are built.
##
## It is not divided over the files of those zones, because that would change
## the order in which the colliders of the level are filed, and with it, by a
## hair, where every ray of the physics engine lands. How a fight goes hangs
## on less than that: see "Grotere levels bouwen" in PLAN.md. What is added to
## a zone from now on can go in the file of that zone.


func _describe() -> void:
	var fire_points: Array = [
		[Vector3(-4.75, 0, HZ - 0.2), 180], [Vector3(4.75, 0, -HZ + 0.2), 0], [Vector3(HX - 0.2, 0, 0.7), -90],
		[Vector3(20.76, 0, -6.5), 90], [Vector3(-4.0, DECK_Y, -HZ + 0.22), 0],
	]
	for point: Array in fire_points:
		place("korean_fire_extinguisher_01", point[0], point[1])
	mount("fire_alarm", Vector3(-HX, 1.4, 3.1), 90, true)
	mount("fire_alarm", Vector3(HX, 1.4, 0.4), -90, true)
	mount("fire_alarm", Vector3(20.56, 1.4, -7.4), 90, true)
	# The corridor floor is wet, and somebody did put out a sign.
	prop("WetFloorSign_01", Transform3D(Basis(Vector3.UP, 0.3), Vector3(21.9, 0, -2.6)))

	place("metal_jerrycan", Vector3(11.9, 0, -7.1), 20)
	place("metal_jerrycan", Vector3(11.7, 0, -7.6), -75)
	place("metal_jerrycan", Vector3(-9.1, 0, 5.2), 100)
	drop("oil_tin", Vector3(-0.75, 0, 6.8), 40)
	drop("oil_tin", Vector3(-7.2, 0, 2.3), 150)

	place("trashbag", Vector3(19.3, 0, 11.3), 20)
	place("trashbag", Vector3(19.35, 0, 10.55), 140)
	place("trashbag", Vector3(20.95, 0, -11.4), 0)
	place("trashbag", Vector3(21.5, 0, -11.5), 60)
	drop("plastic_broom", Vector3(22.93, 0, -6.7), -90)

	var box: Vector3 = _model("cardboard_box_01").box.size
	place("cardboard_box_01", Vector3(29.6, 0, -11.5), 5)
	place("cardboard_box_01", Vector3(29.62, box.y, -11.48), -12)
	place("cardboard_box_01", Vector3(28.95, 0, -11.6), 80)
	place("cardboard_box_01", Vector3(25.3, 0, 1.6), 0)
	place("cardboard_box_01", Vector3(25.32, box.y, 1.58), 15)
	place("plastic_monobloc_chair_01", Vector3(27.3, 0, 0.55), 15)
	place("plastic_monobloc_chair_01", Vector3(28.9, 0, -1.9), -70)

	# Drains along the middle of the hall, their frames flush with the floor.
	for x: float in [-8.5, 4.9]:
		prop("water_manhole_cover", Transform3D(Basis(), Vector3(x, -0.055, 0)))
