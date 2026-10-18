extends CharacterBody3D
## Somebody who stands there to be hit, for tools/test_vehicles.gd.

var health := 100.0


func take_damage(amount: float, _at := Vector3.ZERO, _direction := Vector3.ZERO) -> bool:
	health -= amount
	return health <= 0.0
