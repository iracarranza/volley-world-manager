class_name PairFamiliarity
extends RefCounted

## What two volis know about each other.
##
## Everything the game tracks about knowing your job is between a voli and a
## *slot*: `position_familiarity` says how well somebody plays middle back.
## Nothing is between two volis, and the sport's most important relationship is:
## a setter and a hitter who have run the same quick two hundred times are a
## different weapon from the same two people meeting in week one.
##
## ## Symmetric, and one number
##
## Setting is directional and the *relationship* is not. A setter learns where a
## hitter likes the ball and the hitter learns what this setter's hands do; both
## halves grow at the same time and neither survives the other leaving. So the
## table is keyed on the unordered pair.
##
## ## Grows by playing, decays by not
##
## `position_familiarity` is 0-100 and this matches it -- same range, same
## reading, so a manager who has learned one has learned both. It is a rate, not
## an event: a pair does not become familiar because of one good match, and does
## not forget in one bad one.
const FLOOR: float = 0.0
const CEILING: float = 100.0

## Where a pair who have never played starts.
##
## Not zero. Two professionals on the same roster have trained together all
## preseason, and starting at zero would say a debut pairing is *worse* than
## strangers rather than merely unpractised.
const BASELINE: float = 24.0

## What one match together is worth, before the diminishing term.
##
## Small on purpose. The point of the quantity is that it is slow -- a
## relationship you can build over a season and lose over a transfer window. A
## rate that reached the ceiling in five matches would be a loading bar with a
## person's name on it.
const MATCH_GAIN: float = 3.4
## And what a match apart costs. Lower than the gain, so a rotation a manager
## uses two weeks in three still creeps upward.
const MATCH_DECAY: float = 0.9


## The key for a pair, in an order neither of them owns.
static func key(first_id: int, second_id: int) -> String:
	return "%d:%d" % [mini(first_id, second_id), maxi(first_id, second_id)]


static func of(table: Dictionary, first_id: int, second_id: int) -> float:
	if first_id == second_id:
		return CEILING
	return float(table.get(key(first_id, second_id), BASELINE))


## Record a match: everyone who played together grows, everyone else slips.
##
## `played_ids` is who was on court. The decay runs over pairs the table already
## knows about rather than over the whole roster, so a squad of thirty does not
## carry four hundred entries describing people who have never met.
static func record_match(table: Dictionary, played_ids: Array) -> void:
	var together := {}
	for first in played_ids:
		for second in played_ids:
			if int(first) >= int(second):
				continue
			var pair := key(int(first), int(second))
			together[pair] = true
			var current: float = float(table.get(pair, BASELINE))
			## Diminishing, so the last ten points cost what the first thirty
			## did. Two volis who have played four seasons together are not
			## learning much more about each other, and a linear rate would say
			## they were.
			var gain := MATCH_GAIN * (1.0 - current / (CEILING * 1.15))
			table[pair] = clampf(current + gain, FLOOR, CEILING)
	for pair in table.keys():
		if together.has(pair):
			continue
		table[pair] = clampf(float(table[pair]) - MATCH_DECAY, FLOOR, CEILING)


## How well this rotation's setter knows the hitters they can actually set.
##
## The figure the connection lines will draw, and the one the set decision
## should weigh: not *is my roster familiar* but *can this setter, in this
## rotation, reach somebody they know*. A setter with two trusted hitters behind
## them and a stranger at the pin is a different setter every third rotation.
static func setter_reach(
	table: Dictionary, setter_id: int, hitter_ids: Array
) -> float:
	if setter_id < 0 or hitter_ids.is_empty():
		return BASELINE
	var total := 0.0
	var count := 0
	for hitter in hitter_ids:
		if int(hitter) == setter_id:
			continue
		total += of(table, setter_id, int(hitter))
		count += 1
	if count == 0:
		return BASELINE
	return total / float(count)


## The weakest link on court, and who it is with.
##
## Returned alongside the mean because the mean hides it, which is the same
## argument the rotation spread is built on: a setter averaging 60 across three
## hitters is fine, unless one of those three is at 20 and is the one the play
## is called for.
static func weakest_pair(table: Dictionary, on_court_ids: Array) -> Dictionary:
	var worst := CEILING + 1.0
	var pair: Array[int] = []
	for first in on_court_ids:
		for second in on_court_ids:
			if int(first) >= int(second):
				continue
			var value := of(table, int(first), int(second))
			if value < worst:
				worst = value
				pair = [int(first), int(second)]
	if pair.is_empty():
		return {}
	return {"ids": pair, "value": worst}
