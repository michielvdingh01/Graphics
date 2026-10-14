extends "res://tools/levels/dunes/plan.gd"
## What stands around the dunes: the wood that goes on beyond the land, the
## line the current comes in by, and the walls nobody sees that keep the
## player on the land. The ground it stands on is laid by vista.gd.


func _describe() -> void:
	in_zone("")
	# Scrub where no dune shuts the land in: along the wood in the west, on
	# either side of where the track comes out of it.
	thicket([Vector2(5.0, 161.0), Vector2(4.2, 178.0), Vector2(4.6, 195.5)])
	thicket([Vector2(5.2, 205.5), Vector2(4.4, 216.0), Vector2(5.0, 227.0)])
	# The wood beyond, on every side: north of the complex, west, behind the
	# dune in the south and behind the one in the east. It stands on the
	# ground that tools/levels/dunes/vista.gd laid there, and in the west
	# only where the player came out of it: north of that the coast is open.
	var vista: RefCounted = _files["vista"]
	var kept := Callable(vista, "wood_kept")
	tree_wall(Vector3(350, 3.0, -9), Vector3(-10, 3.0, -9), 24.0, kept)
	tree_wall(Vector3(-9, 3.0, -9), Vector3(-9, 3.0, 240), 24.0, kept)
	tree_wall(Vector3(-10, 10.0, 239), Vector3(350, 10.0, 239), 22.0, kept)
	tree_wall(Vector3(349, 9.0, 240), Vector3(349, 9.0, -9), 22.0, kept)
	# The line from the powerhouse: two pylons north of the wall.
	for pylon: Vector3 in [Vector3(173.2, 0.0, -44.0), Vector3(150.0, 0.0, -120.0)]:
		pylon.y = beyond_height(pylon.x, pylon.z) - 0.3
		lattice_mast(pylon, 24.0, 2.2)
		lattice_girder(pylon + Vector3(-4.4, 22.0, 0), pylon + Vector3(4.4, 22.0, 0), 0.5)
	for i in 3:
		wire(Vector3(172.0 + i * 1.2, beyond_height(173.2, -44.0) + 21.9, -44.0), Vector3(148.8 + i * 1.2, beyond_height(150.0, -120.0) + 21.9, -120.0), 5.0, 0.02)
	# Nobody leaves the land.
	shut_in()
	by_position()
