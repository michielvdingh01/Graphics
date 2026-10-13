extends "res://scripts/modes/mode.gd"
## Free for all: everybody for themselves, a point for every kill, and
## whoever is first to the limit wins, or leads when the time is up. An
## entrant's `team` is a side of its own here, and the tally is not used.


func teams() -> bool:
	return false


func head_count(size: int) -> int:
	return size


func side(place: int) -> int:
	return place


func hostile(a: RefCounted, b: RefCounted) -> bool:
	return a != b


func count(_killer: RefCounted, _fallen: RefCounted, _tally: Array[int]) -> void:
	# Whose kill it was is kept with the entrant, and that is the score.
	pass


func points(who: RefCounted, _entrants: Array, _tally: Array[int]) -> int:
	return who.kills


func against(who: RefCounted, entrants: Array, _tally: Array[int]) -> int:
	var most := 0
	for other: RefCounted in entrants:
		if other != who:
			most = maxi(most, other.kills)
	return most


func winner(entrants: Array, _tally: Array[int], over: bool) -> int:
	var best: RefCounted = null
	var level := false
	for one: RefCounted in entrants:
		if best == null or one.kills > best.kills:
			best = one
			level = false
		elif one.kills == best.kills:
			level = true
	if best == null:
		return DRAW if over else NOBODY
	if best.kills >= int(numbers.limit) or over:
		return DRAW if level and over else best.team
	return NOBODY
