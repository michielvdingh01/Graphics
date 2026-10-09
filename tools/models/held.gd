extends "res://tools/models/weapons.gd"
## The same weapons as somebody else carries them: without the hands of the
## player, and in one piece, since nothing on them moves. Build with
## tools/build_model.sh held; they are written next to the others as
## scenes/models/<weapon>_held.scn.
##
## Where the hands were, the markers HandR and HandL say how to hold the
## weapon: each sits at the wrist, with -Z along the back of the hand to the
## knuckles and +Y out of the back of the hand. ElbowR and ElbowL are where
## the forearms came from. scripts/humanoid_rig.gd closes the hands of a
## character around them.

## "R" or "L" while the part being built is a hand.
var _side_of_hand := ""


func model(model_name: String) -> void:
	super(model_name + "_held")


func part(part_name: String, _pivot := Transform3D(), _parent := "") -> void:
	_side_of_hand = part_name.trim_prefix("Arm") if part_name.begins_with("Arm") else ""
	super("Body")


func marker(marker_name: String, at: Transform3D, _parent := "") -> void:
	super(marker_name, at)


func _hand(frame: Transform3D, radii: Vector2, palm_deg: float, _curl: float, wrist: Vector3, elbow: Vector3, _thumb: Array, _index: Array = []) -> void:
	# The knuckles of the index and the little finger, as the glove has them.
	var start := deg_to_rad(palm_deg)
	var first := _around(frame, radii, start, 0.011, 1.5 * 0.0205)
	var last := _around(frame, radii, start, 0.011, -1.5 * 0.0205)
	var middle := (first + last) * 0.5
	var back := (wrist - middle).normalized()
	var out := back.cross(first - last).normalized()
	if out.dot(middle - frame.origin) < 0.0:
		out = -out
	marker("Hand" + _side_of_hand, _m * Transform3D(Basis(out.cross(back), out, back), wrist))
	marker("Elbow" + _side_of_hand, _m * Transform3D(Basis(), elbow))
