extends RefCounted
## Keeps what stands in the shade out of the sun's shadow.
##
## The sun of a level casts its shadow as far as 70 m, in four maps, and into
## each of them goes whatever stands within its reach in a zone that is
## drawn. Indoors nearly all of that stands under a roof, where the sun never
## comes: a crate in a store without windows casts no shadow of the sun that
## anyone gets to see. From the door of the stores of the works those maps
## took 1500 draw calls and 3.7 million triangles a frame.
##
## So when a level starts, every model the builder placed is looked at from
## where the sun is. If walls and roofs stand between the sun and every
## corner of it, it goes to a layer of its own, which the sun leaves out of
## its shadow. The lamps cast its shadow as before, and everything else sees
## it as before: a camera, a lamp, a decal and a reflection probe look at
## every layer unless told otherwise.

## The render layers of what stands in the shade are those of
## scripts/zones.gd, which gives every zone layers of its own: layer 3 for
## what belongs to no zone, and one for every colour a zone can have.
const ZONES := preload("res://scripts/zones.gd")
## What stops the sun: the colliders of the level.
const WORLD := 1
## How far towards the sun is looked for something in the way.
const REACH := 120.0


## Sorts the models of `level`, a level as the builder made it, for the suns
## of `scene`. Waits for the colliders of the level first, which are in the
## world a frame after the level is in the tree. Returns how many models
## went into the shade.
static func sort(scene: Node, level: Node) -> int:
	var suns := scene.find_children("*", "DirectionalLight3D", false, false).filter(func(sun: DirectionalLight3D) -> bool: return sun.shadow_enabled)
	if level == null or suns.is_empty():
		return 0
	await scene.get_tree().physics_frame
	await scene.get_tree().physics_frame
	if not is_instance_valid(level) or not level.is_inside_tree():
		return 0
	var space := (level as Node3D).get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, WORLD)
	# What can be shot to pieces does not stop the sun: a crate that stands in
	# the shade of nothing but a stack of crates is in the sun once that stack
	# has gone. See scripts/breakables.gd, which has made its bodies by now.
	var passing: Array[RID] = []
	for body in scene.get_tree().get_nodes_in_group("breakable"):
		if body is CollisionObject3D and scene.is_ancestor_of(body):
			passing.append(body.get_rid())
	ray.exclude = passing
	var shaded := 0
	for group: Node in level.find_children("Props", "Node3D", true, false):
		for model: Node in group.get_children():
			var meshes := model.find_children("*", "GeometryInstance3D", true, false)
			if model is GeometryInstance3D:
				meshes.append(model)
			if meshes.is_empty():
				continue
			var box := AABB()
			for i in meshes.size():
				var mesh: GeometryInstance3D = meshes[i]
				var around := mesh.global_transform * mesh.get_aabb()
				box = around if i == 0 else box.merge(around)
			# Its corners, the middle of each side and its own middle.
			var spots: Array[Vector3] = [box.get_center()]
			for i in 8:
				spots.append(box.get_endpoint(i))
			for axis in 3:
				for side: float in [0.0, 1.0]:
					var spot := box.get_center()
					spot[axis] = box.position[axis] + box.size[axis] * side
					spots.append(spot)
			var in_shade := true
			for sun: DirectionalLight3D in suns:
				for spot in spots:
					ray.from = spot
					ray.to = spot + sun.global_basis.z * REACH
					if space.intersect_ray(ray).is_empty():
						in_shade = false
						break
				if not in_shade:
					break
			if in_shade:
				shaded += 1
				for mesh: GeometryInstance3D in meshes:
					mesh.layers = ZONES.shaded(mesh.layers)
	for sun: DirectionalLight3D in suns:
		sun.shadow_caster_mask &= ~ZONES.SHADE_MASK
	return shaded
