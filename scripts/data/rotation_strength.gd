class_name RotationStrength
extends RefCounted

## A six is not one team. It is six teams, and you play all of them.
##
## The lock-in board grades the starting six by averaging every starter into
## every category, and that average is a fiction the sport does not contain.
## **Three of your six are at the net and three are behind the ten-foot line, and
## which three changes every time you win a point.** A wall of your two best
## blockers plus your setter is a different object from a wall of your setter
## plus two outsides, and the team mean cannot tell them apart because it has
## already added them together.
##
## So strength is computed **per rotation**, from the players who are actually in
## a position to supply it:
##
## | axis | comes from | why |
## |---|---|---|
## | Attacking | the front three, minus the setter | a back-row attack exists but the front row carries it |
## | Defensive (net) | the front three | blocking is the front row's whole job |
## | Defensive (floor) | the back three | digging and receiving happen behind the line |
## | Setting / Control | the active setter, plus the back three | a setter out of system is bailed out by the floor |
## | Physical | the front three | the axis is reach and jump, which the net wants |
## | Serving | all six | everybody serves, once each, over a cycle |
## | Mental / Tactical | all six | reading the game is not a position |
##
## ## And the number the whole thing is for: **spread**
##
## A team whose block swings from excellent in rotation 1 to poor in rotation 4
## is not the same team as one that is merely good in all six, even when their
## means are identical -- because the opponent gets to *choose*. They serve to
## reach your weak rotation and stay there. A mean hides exactly the thing an
## opponent is looking for.
##
## `spread` is that: the gap between a lineup's best and worst rotation on an
## axis. It is a real property of a lineup, it moves when you reorder the six,
## and it is the first figure on this board that rewards thinking about the
## rotation *order* rather than the roster.
const AttributeProfiles := preload("res://scripts/systems/attribute_profile_system.gd")

## Which of the six categories each rotation position supplies.
##
## Weights rather than a hard split, because none of these is absolute: a
## back-row hitter still attacks, and a front-row setter still sets. The weights
## say where the *majority* of an axis comes from, which is what makes a wall of
## two middles read differently from a wall with the setter in it.
const AXIS_SOURCES := {
	"Attacking": {"front": 0.80, "back": 0.20},
	"Setting / Control": {"front": 0.25, "back": 0.75},
	"Physical": {"front": 0.70, "back": 0.30},
	"Serving": {"front": 0.50, "back": 0.50},
	"Mental / Tactical": {"front": 0.50, "back": 0.50},
	## **Defensive splits, and it has to.**
	##
	## The first version weighted it 0.50 / 0.50 like serving, and measured over
	## a deliberately lopsided six -- three tallest against three shortest -- it
	## produced a spread of **exactly 0.0** on every rotation. That is not a
	## squad that happens to be even; it is arithmetic. Under a cyclic rotation
	## every voli spends the same three rotations in front as behind, so a 50/50
	## axis is rotation-invariant *by construction* and can never say anything.
	##
	## Serving and Mental / Tactical read 0.0 for the same reason and are right
	## to: everybody serves once a cycle and reading the game is not a position.
	## Defence is not like that. Blocking is the front row's whole job and
	## digging happens behind the ten-foot line, and folding them into one number
	## guarantees the one question this panel exists to answer -- how does
	## rotation one's block compare to rotation six -- can never be asked.
	##
	## So the axis is drawn twice, from the same category score, through the two
	## halves of the court that actually supply it. This is the functional-axis
	## idea `docs/design/TEAM_ATTRIBUTE_WHEEL.md` specifies, arriving where it
	## was needed first rather than all at once.
	"Defensive": {"front": 0.50, "back": 0.50},
	"Block": {"front": 1.00, "back": 0.00, "from": "Defensive"},
	"Floor": {"front": 0.00, "back": 1.00, "from": "Defensive"},
}

## The axes a rotation is read on: the six categories, plus the two halves
## `Defensive` splits into. `Defensive` itself stays for the team mean, where
## adding a wall to a floor is a fair summary of a squad.
const ROTATION_AXES: Array[String] = [
	"Attacking", "Block", "Floor", "Setting / Control",
	"Physical", "Serving", "Mental / Tactical",
]

const FRONT_SLOTS: Array[int] = [2, 3, 4]
const BACK_SLOTS: Array[int] = [1, 5, 6]


## One rotation's strength in every category.
##
## `players_by_id` is `{id: VolleyballPlayer}`. Returns the six category names
## `summary_profile` uses, so anything already grading a category -- the bands,
## the board's marks -- reads this without a translation table.
static func of_rotation(
	lineup: Resource, players_by_id: Dictionary
) -> Dictionary:
	var front := _mean_profile(lineup, FRONT_SLOTS, players_by_id)
	var back := _mean_profile(lineup, BACK_SLOTS, players_by_id)
	var out := {}
	for axis in ROTATION_AXES:
		var weights: Dictionary = AXIS_SOURCES.get(axis, {"front": 0.5, "back": 0.5})
		## Which category score this axis reads. `Block` and `Floor` are two
		## views of `Defensive`, not two new numbers.
		var source := str(weights.get("from", axis))
		## A half-empty rotation weights what it has rather than counting the
		## missing half as zero -- a lineup mid-edit should read as incomplete,
		## not as catastrophic.
		var front_share := float(weights["front"]) if front.has(source) else 0.0
		var back_share := float(weights["back"]) if back.has(source) else 0.0
		var total := front_share + back_share
		if total <= 0.0:
			continue
		out[axis] = (
			float(front.get(source, 0.0)) * front_share
			+ float(back.get(source, 0.0)) * back_share
		) / total
	return out


## Every rotation, and what varies across them.
##
## Returns `{"rotations": {n: {axis: score}}, "mean": {axis: score},
## "spread": {axis: best - worst}, "weakest": {axis: n}}`.
static func across(rotations: Dictionary, players_by_id: Dictionary) -> Dictionary:
	var per_rotation := {}
	var numbers: Array = rotations.keys()
	numbers.sort()
	for number in numbers:
		per_rotation[number] = of_rotation(rotations[number], players_by_id)
	var mean := {}
	var spread := {}
	var weakest := {}
	for axis in ROTATION_AXES:
		var total := 0.0
		var count := 0
		var low := INF
		var high := -INF
		var low_at := -1
		for number in numbers:
			var row: Dictionary = per_rotation[number]
			if not row.has(axis):
				continue
			var score := float(row[axis])
			total += score
			count += 1
			if score < low:
				low = score
				low_at = int(number)
			high = maxf(high, score)
		if count == 0:
			continue
		mean[axis] = total / float(count)
		spread[axis] = high - low
		weakest[axis] = low_at
	return {
		"rotations": per_rotation, "mean": mean,
		"spread": spread, "weakest": weakest,
	}


## The one figure that says *how exposed this lineup is*.
##
## The mean of the per-axis spreads. A lineup that is even across all six
## rotations scores near zero; one with a hole somewhere scores high, and the
## opponent's serve is what finds it.
static func exposure(summary: Dictionary) -> float:
	var spread: Dictionary = summary.get("spread", {})
	if spread.is_empty():
		return 0.0
	var total := 0.0
	for axis in spread:
		total += float(spread[axis])
	return total / float(spread.size())


static func _mean_profile(
	lineup: Resource, slots: Array, players_by_id: Dictionary
) -> Dictionary:
	var totals := {}
	var count := 0
	for slot in slots:
		var player_id := int(lineup.player_at_slot(int(slot)))
		if not players_by_id.has(player_id):
			continue
		var profile: Dictionary = AttributeProfiles.summary_profile(
			players_by_id[player_id]
		)
		count += 1
		for axis in AttributeProfiles.GRADE_BAND_CATEGORIES:
			totals[axis] = float(totals.get(axis, 0.0)) + float(profile.get(axis, 0.0))
	if count == 0:
		return {}
	for axis in totals:
		totals[axis] = float(totals[axis]) / float(count)
	return totals
