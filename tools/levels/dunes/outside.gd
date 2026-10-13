extends "res://tools/levels/dunes/plan.gd"
## What lies around the dunes: the wood that goes on beyond the land, as a
## wall of it; sand out to where nobody looks; the line the current comes in
## by; and the walls nobody sees that keep the player on the land.


func _describe() -> void:
	in_zone("")
	# Scrub where no dune shuts the land in: along the wood in the west, on
	# either side of where the track comes out of it.
	thicket([Vector2(5.0, 161.0), Vector2(4.2, 178.0), Vector2(4.6, 195.5)])
	thicket([Vector2(5.2, 205.5), Vector2(4.4, 216.0), Vector2(5.0, 227.0)])
	# The wood beyond, on every side: north of the complex, west, behind the
	# dune in the south and behind the one in the east.
	tree_wall(Vector3(350, 3.0, -9), Vector3(-10, 3.0, -9), 24.0)
	tree_wall(Vector3(-9, 3.0, -9), Vector3(-9, 3.0, 240), 24.0)
	tree_wall(Vector3(-10, 10.0, 239), Vector3(350, 10.0, 239), 22.0)
	tree_wall(Vector3(349, 9.0, 240), Vector3(349, 9.0, -9), 22.0)
	# Sand beyond the land, lower than its edge.
	for apron: Array in [[Vector3(170, 2.0, -150), Vector3(940, 1.0, 300)], [Vector3(170, 2.0, 380), Vector3(940, 1.0, 300)], [Vector3(-150, 2.0, 115), Vector3(300, 1.0, 230)], [Vector3(490, 2.0, 115), Vector3(300, 1.0, 230)]]:
		box("dune_ground", apron[0], apron[1], Vector3.ZERO, SLIGHT)
	# The line from the powerhouse: two pylons north of the wall.
	for pylon: Vector3 in [Vector3(173.2, 3.0, -44.0), Vector3(150.0, 3.0, -120.0)]:
		lattice_mast(pylon, 24.0, 2.2)
		lattice_girder(pylon + Vector3(-4.4, 22.0, 0), pylon + Vector3(4.4, 22.0, 0), 0.5)
	for i in 3:
		wire(Vector3(172.0 + i * 1.2, YARD_Y + 19.0, -44.0), Vector3(148.8 + i * 1.2, 25.0, -120.0), 5.0, 0.02)
	# Nobody leaves the land.
	shut_in()
	by_position()
