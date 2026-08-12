class_name FoodSupply
extends RefCounted

## A flow, not a stockpile.
##
## `ACCOMMODATIONS_AND_CARE.md` §13. A club holds no inventory: it has its own
## region's larder for nothing, plus whatever **supply lines** it chooses to run
## to other regions, priced by distance. Nobody counts sacks of anything. The
## manager picks lines; the chef turns what arrives into a week; and the manager
## hears about it only when a line breaks.
##
## ## The two things this makes true
##
## **Geography becomes a constraint rather than a label.** A Landavol club eats
## Landavol food without ever choosing to, and eating like Pāwa Hitō is a line
## you are running on purpose, at a cost, that a bad season two regions away can
## cut.
##
## **And an aversion stops being a personality quirk.** A voli is averse because
## the region they are in does not produce what they grew up eating — a fact
## about *two places*, derived rather than stored, so it stays true when they
## transfer and is predictable before you sign them.
const Larder := preload("res://scripts/data/region_larder.gd")

## What a line costs per week, by distance in adjacency steps, and how often it
## arrives intact.
##
## Sized as a shape rather than a calibration: the intent is that adjacent is
## something a modest club does without thinking, two steps is a decision, and
## three is a statement. No number here has been measured against a budget,
## because the club finances that would judge it are not in this model yet.
const LINE_COST := {0: 0.0, 1: 1.0, 2: 2.6, 3: 5.2}
const UNREACHABLE_COST: float = 9.0
## How often a line delivers everything it should. The far ones are the event
## system's material -- see §9. A line that never failed would be a purchase
## rather than a relationship with a place.
const LINE_RELIABILITY := {0: 1.0, 1: 0.97, 2: 0.90, 3: 0.78}
const UNREACHABLE_RELIABILITY: float = 0.60


static func line_cost(from_region: String, to_region: String) -> float:
	var steps := Larder.distance(from_region, to_region)
	if steps < 0:
		return UNREACHABLE_COST
	return float(LINE_COST.get(steps, UNREACHABLE_COST))


static func line_reliability(from_region: String, to_region: String) -> float:
	var steps := Larder.distance(from_region, to_region)
	if steps < 0:
		return UNREACHABLE_RELIABILITY
	return float(LINE_RELIABILITY.get(steps, UNREACHABLE_RELIABILITY))


## Everything on the table this week: the club's own larder plus its lines.
##
## `lines` is the list of regions the club sources from. Its own region is
## always included and is never charged, which is the whole point — you do not
## run a supply line to the field outside.
static func table(club_region: String, lines: Array, week: int = 1) -> Dictionary:
	var staples := {}
	var pastes := {}
	var sources: Array[String] = [club_region]
	for line in lines:
		if str(line) != club_region:
			sources.append(str(line))
	var lean_sources: Array[String] = []
	var weekly_cost := 0.0
	for source in sources:
		var produce: Dictionary = Larder.produces(source, week)
		if bool(produce.get("lean", false)):
			lean_sources.append(source)
		for item in Array(produce["staples"]):
			staples[str(item)] = source
		for item in Array(produce["pastes"]):
			pastes[str(item)] = source
		weekly_cost += line_cost(club_region, source)
	return {
		"staples": staples, "pastes": pastes,
		"sources": sources, "lean": lean_sources,
		"weekly_cost": weekly_cost,
	}


## How badly this voli is eating, from 0 (at home) to 1 (nothing familiar).
##
## The share of their home region's staples that are **not** on the table. Not a
## stored trait: two volis from the same region are equally averse at the same
## club, and both stop being averse the moment a line reaches home.
##
## Staples rather than pastes, deliberately. Missing a flavour you like is a
## disappointment; missing everything you have ever eaten is the thing that
## costs somebody their rest.
static func aversion(home_region: String, table_now: Dictionary) -> float:
	var home: Dictionary = Larder.produces(home_region, 1)
	var wanted: Array = Array(home["staples"])
	if wanted.is_empty():
		## A voli from an importing region grew up on everybody's food, so there
		## is nothing in particular for them to miss. See `IMPORTING_REGIONS`.
		return 0.0
	var present: Dictionary = table_now.get("staples", {})
	var missing := 0
	for item in wanted:
		if not present.has(str(item)):
			missing += 1
	return float(missing) / float(wanted.size())


## And the same distance measured the other way: how tired this voli is of what
## they have been eating.
##
## Aversion asks *is this what I eat*; palate asks *is this what I ate last
## week, and the week before*. One quantity, two inputs, which is what stops the
## table needing two systems.
const PALATE_REPEAT_GAIN: float = 0.14
const PALATE_ROTATE_RELIEF: float = 0.30
const PALATE_CEILING: float = 1.0


## Move one voli's palate for a week of eating `paste`.
##
## Relief is more than twice the gain on purpose. Palate should be a thing a
## manager *fixes by rotating*, not a clock they lose to -- §6 is explicit that
## it must not become a timer to be optimised against, so recovering from it is
## fast and drifting into it is slow.
static func advance_palate(
	palate: Dictionary, player_id: int, paste: String
) -> float:
	var key := str(player_id)
	var record: Dictionary = palate.get(key, {"paste": "", "value": 0.0})
	var value := float(record.get("value", 0.0))
	if str(record.get("paste", "")) == paste and not paste.is_empty():
		value = minf(value + PALATE_REPEAT_GAIN, PALATE_CEILING)
	else:
		value = maxf(value - PALATE_ROTATE_RELIEF, 0.0)
	palate[key] = {"paste": paste, "value": value}
	return value


static func palate_of(palate: Dictionary, player_id: int) -> float:
	return float(Dictionary(palate.get(str(player_id), {})).get("value", 0.0))


## How much of a voli's rest this week is spent on eating badly.
##
## The two terms added rather than multiplied: a voli can be both far from home
## *and* bored of the one thing that is available, and those are separate
## miseries. Capped, because there is a floor under how badly a professional
## athlete eats -- §11's rule that a dorm is still a dorm, applied to the table.
const AVERSION_WEIGHT: float = 0.65
const PALATE_WEIGHT: float = 0.35
const NOURISHMENT_FLOOR: float = 0.45


static func nourishment(aversion_now: float, palate_now: float) -> float:
	var lost := clampf(aversion_now, 0.0, 1.0) * AVERSION_WEIGHT \
		+ clampf(palate_now, 0.0, 1.0) * PALATE_WEIGHT
	return maxf(1.0 - lost, NOURISHMENT_FLOOR)
