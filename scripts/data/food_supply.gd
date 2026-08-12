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
		for item in Array(produce["pastes"]):
			pastes[str(item)] = source
		weekly_cost += line_cost(club_region, source)
	return {
		"pastes": pastes,
		"sources": sources, "lean": lean_sources,
		"weekly_cost": weekly_cost,
	}


## ## Comfort is a band, not a target
##
## The first version of this was `aversion`: count a voli's home pastes, count
## how many are absent, divide. A binary dressed as a fraction, and wrong twice.
##
## **Nobody needs all of it.** A voli wants *enough* of what they know, not every
## paste — a share-missing model calls a Pāwa Hitō voli with fermented bean and
## citrus salt but no toasted sesame a third unhappy, which is not how eating
## works.
##
## **And most weeks should be fine.** A threshold a manager has to *hit* is
## fiddly; a window they stay *inside* is forgiving, which is the register this
## game is in. A club broadly feeding its squad correctly should never think
## about food at all — only when somebody falls out of their band.
##
## ## And the band widens
##
## A voli is comfortable with a **set of regions**, not one. It starts as where
## they grew up and grows when they spend a season somewhere, or when they room
## long enough with somebody from there. The second is the good one: a
## foreign-born voli teaches their roommate to enjoy their food, which gives
## `PairFamiliarity` a use with nothing to do with volleyball.
##
## The set's size sets the band. One region is a narrow, high-floored palate —
## they need most of the table to be theirs. Four regions is a wide, forgiving
## one, and a voli who is easy to feed anywhere is worth something at signing
## that has nothing to do with their attributes.

## The floor for a voli who knows only where they grew up, and for one who has
## lived everywhere. Both are shares of the week's table.
const COMFORT_FLOOR_NARROW: float = 0.55
const COMFORT_FLOOR_WIDE: float = 0.20
## How many regions a palate has to reach before it stops widening usefully.
const PALATE_BREADTH_FULL: int = 4
## And the ceiling, which is not about misery.
##
## A voli eating only what they have always eaten is not adapting. Sitting above
## this does not hurt them; it stops the set growing, which is the cost. A squad
## fed entirely on one larder is a squad that will struggle the week it travels.
const COMFORT_CEILING: float = 0.92


## The floor and ceiling of this voli's comfortable range.
static func band_for(palate_regions: Array) -> Dictionary:
	var breadth := clampf(
		float(maxi(palate_regions.size(), 1) - 1) / float(PALATE_BREADTH_FULL - 1),
		0.0, 1.0,
	)
	return {
		"floor": lerpf(COMFORT_FLOOR_NARROW, COMFORT_FLOOR_WIDE, breadth),
		"ceiling": COMFORT_CEILING,
	}


## What share of this week's table this voli is comfortable with.
##
## Read off where each paste came from, which `table()` already records, so a
## voli is comfortable with a Pāwa Hitō paste whether it was made at home or
## arrived down a supply line. The food does not know how far it travelled.
static func comfort_share(palate_regions: Array, table_now: Dictionary) -> float:
	var pastes: Dictionary = table_now.get("pastes", {})
	if pastes.is_empty():
		return 0.0
	var known := {}
	for region in palate_regions:
		known[str(region)] = true
	var comfortable := 0
	for item in pastes:
		if known.has(str(pastes[item])):
			comfortable += 1
	return float(comfortable) / float(pastes.size())


## How far outside their band they are, as a positive number, or zero inside it.
##
## Only the floor is a shortfall. Being above the ceiling is not a discomfort —
## it is a missed opportunity, and `widens_palate` below is where that lands.
static func discomfort(palate_regions: Array, table_now: Dictionary) -> float:
	var band := band_for(palate_regions)
	var share := comfort_share(palate_regions, table_now)
	if share >= float(band["floor"]):
		return 0.0
	return (float(band["floor"]) - share) / maxf(float(band["floor"]), 0.001)


## Whether a week of this table gives a voli anything new to get used to.
##
## Below the ceiling there is enough unfamiliar food on the table to be learning
## from. Above it they are eating at home, which is comfortable and teaches them
## nothing.
static func widens_palate(palate_regions: Array, table_now: Dictionary) -> bool:
	return comfort_share(palate_regions, table_now) < COMFORT_CEILING


## Add a region to a voli's palate, if it is not already there.
static func learn_region(palate_regions: Array, region: String) -> bool:
	if region.is_empty() or palate_regions.has(region):
		return false
	palate_regions.append(region)
	return true


## How familiar two volis have to be before one's food becomes the other's.
##
## Read against `PairFamiliarity`'s own 0-100 scale. High on purpose: this is
## two seasons of sharing a room, not a friendly conversation, and it should
## feel like something a manager arranged rather than something that happens.
const PALATE_SHARING_THRESHOLD: float = 72.0


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
