extends RefCounted
## The rules of one kind of match: who is with whom, what a kill comes to and
## when it is over. scripts/match.gd plays by whichever of these was chosen
## and knows nothing of the kinds itself, so that one more kind is one more
## file here and a line in assets/match.json. What stands here is what two
## teams play by; a kind says where it differs.
##
## Somebody who plays is an entrant of match.gd: of those this reads `team`
## and `kills`. `tally` is the points of either side.

## Nobody has won yet, and nobody will: the time is up with the sides level.
const NOBODY := -100
const DRAW := -101

## The numbers of this kind, as assets/match.json has them: its title, the
## points it is played to, the minutes it lasts at most, the seconds somebody
## who died is out of it, and how many may play a side.
var numbers := {}


## True if it is played by two sides, false if by everybody for themselves.
func teams() -> bool:
	return true


## How many play in all when `size` is asked for.
func head_count(size: int) -> int:
	return size * 2


## The side of the entrant who is the `place`th to come in. The first is the
## player of the machine that hosts, who is on side 0 with every other one.
func side(place: int) -> int:
	return place % 2


func hostile(a: RefCounted, b: RefCounted) -> bool:
	return a != b and a.team != b.team


## Counts a kill; `killer` is null for somebody who died by nobody's hand.
func count(killer: RefCounted, fallen: RefCounted, tally: Array[int]) -> void:
	if killer and hostile(killer, fallen):
		tally[killer.team] += 1


## The points that count for `who`, and the most that anybody against has.
func points(who: RefCounted, _entrants: Array, tally: Array[int]) -> int:
	return tally[who.team]


func against(who: RefCounted, _entrants: Array, tally: Array[int]) -> int:
	return tally[1 - who.team]


## Who has won: a side, NOBODY while it is still being played, or DRAW.
## `over` once the time is up.
func winner(_entrants: Array, tally: Array[int], over: bool) -> int:
	var limit: int = numbers.limit
	if tally[0] >= limit or tally[1] >= limit or over:
		return DRAW if tally[0] == tally[1] else (0 if tally[0] > tally[1] else 1)
	return NOBODY


## True if `who` is among those that `won` names.
func is_winner(who: RefCounted, won: int) -> bool:
	return who.team == won
