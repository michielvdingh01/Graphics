extends SceneTree
## How each kind of vehicle gets over the two long dunes of the dunes level,
## without a window and without the GPU. Every STEP metres along each dune
## a vehicle starts RUN_UP metres before its crest and drives at it flat out:
## north up the steep face (the slip face, 45 to 59 degrees over five to
## seven metres) or with DIR=south up the long back and down the face. It
## says at how many places it got over, and where not and how high it got.
## Where it never got to the dune at all, something stood in its way: that
## place is left out of the count and said apart.
##
##   tools/vehicle_ridges.sh                      north, every 12 m, all kinds
##   DIR=south KINDS=tank STEP=24 tools/vehicle_ridges.sh

const KINDS := ["jeep", "truck", "tank"]
## The two long dunes: their crest lies between these z.
const RIDGES := [[140.0, 170.0], [85.0, 110.0]]
const RUN_UP := 22.0
## Seconds it has to get over.
const TIME := 25.0

var space: PhysicsDirectSpaceState3D
var fx: Node


func _initialize() -> void:
	_run.call_deferred()


func _ground(x: float, z: float) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 80, z), Vector3(x, -20, z), 1))


func _run() -> void:
	await process_frame
	change_scene_to_file("res://scenes/dunes.tscn")
	await scene_changed
	for node in get_nodes_in_group("enemy") + get_nodes_in_group("vehicle"):
		node.queue_free()
	for i in 10:
		await physics_frame
	space = (current_scene as Node3D).get_world_3d().direct_space_state
	fx = root.get_node("Fx")
	var only := OS.get_environment("KINDS")
	var kinds: Array = KINDS if only == "" else Array(only.split(","))
	var step := OS.get_environment("STEP").to_float() if OS.get_environment("STEP") != "" else 12.0
	var south := OS.get_environment("DIR") == "south"
	for kind: String in kinds:
		var tried := 0
		var over := 0
		var failed: Array[String] = []
		var blocked: Array[String] = []
		for ridge: Array in RIDGES:
			var x := 4.0
			while x < 334.0:
				# Where the crest is, and how steep the face below it: where
				# it is not all sand, something stands on it.
				var crest := -1.0
				var top := -INF
				var z: float = ridge[0]
				while z <= ridge[1]:
					var hit := _ground(x, z)
					if hit and hit.position.y > top:
						top = hit.position.y
						crest = z
					z += 0.5
				var steepest := 0.0
				var sandy := true
				z = crest
				while z < crest + 10.0:
					var a := _ground(x, z)
					var b := _ground(x, z + 1.0)
					if a and b:
						steepest = maxf(steepest, rad_to_deg(atan(a.position.y - b.position.y)))
						sandy = sandy and fx.surface_of(a) == "sand"
					z += 0.5
				var start := _ground(x, crest + (-RUN_UP if south else RUN_UP))
				if steepest >= 30.0 and sandy and start:
					var got := await _drive(kind, start.position + Vector3.UP * 0.3, crest, south)
					if got.over:
						over += 1
						tried += 1
					elif got.reached:
						tried += 1
						failed.append("x %d: %.0f degrees, up to %.1f m of %.1f" % [x, steepest, got.high, top - start.position.y])
					else:
						blocked.append("x %d" % x)
				x += step
		print("%s: over %d of %d dunes" % [kind, over, tried])
		for line in failed:
			print("    not over at ", line)
		if not blocked.is_empty():
			print("    never got to the dune at ", ", ".join(blocked))
	quit(0)


## A vehicle of `kind` at `at`, facing north or south, flat out for TIME
## seconds or until it is four metres past `crest`.
func _drive(kind: String, at: Vector3, crest: float, south: bool) -> Dictionary:
	var vehicle := RigidBody3D.new()
	vehicle.set_script(load("res://scripts/vehicle.gd"))
	vehicle.set("kind", kind)
	vehicle.transform = Transform3D(Basis(Vector3.UP, PI) if south else Basis(), at)
	current_scene.add_child(vehicle)
	await physics_frame
	vehicle.wake()
	vehicle.autopilot = true
	vehicle.hand_brake = false
	vehicle.engine_on = true
	vehicle.ask_forward = 1.0
	var time := 0.0
	var over := false
	var highest := at.y
	while time < TIME and not over:
		for i in 12:
			await physics_frame
		time += 12.0 / Engine.physics_ticks_per_second
		over = vehicle.global_position.z > crest + 4.0 if south else vehicle.global_position.z < crest - 4.0
		highest = maxf(highest, vehicle.global_position.y)
	vehicle.queue_free()
	await physics_frame
	return {"over": over, "high": highest - at.y, "reached": highest > at.y + 1.5}
