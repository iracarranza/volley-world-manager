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
const Block := preload("res://scripts/data/food_block.gd")
const Ratio := preload("res://scripts/data/paste_ratio.gd")

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


## ## What is actually on the block this week
##
## **The fix for a real defect the accommodation page exposed.** Comfort was a
## share of everything the club could reach, so a Landavol club running one line
## to Xérvu took its Landavol volis from 1.00 to 0.50 and straight through their
## band's floor. Running a supply line made a settled squad worse off, which
## meant the optimal food strategy for a homogeneous squad was to run no lines at
## all -- and a system whose best play is *do not use the system* is not a
## decision.
##
## The mistake was measuring the larder instead of the meal. A chef does not
## serve nine pastes; §1 says a block holds **two to four** and the chef's rating
## sets which. So the week's comfort is measured against what is on the block,
## and more lines give the chef more to choose from rather than diluting the
## plate. The line is still a cost and a risk; it is no longer a penalty.
##
## Rotated by week rather than chosen, because the chef rotating is `advance_palate`'s
## own rule that repetition is what tires a palate and rotation is the fix. A
## club with three pastes and three slots serves all three every week and nobody
## gets bored; a club with nine and three slots is rotating properly without the
## manager touching anything.
## Returns a **table-shaped** dictionary, not a bare paste map. Everything
## downstream -- `comfort_share`, `discomfort`, `widens_palate` -- reads
## `table_now["pastes"]`, and the first version of this handed back the flat map
## instead: every comfort reading in the game came out `0.00`, including for a
## squad being served its own region's pastes. Caught by a probe printing the
## served set beside the share it produced, which disagreed on their face.
static func served(
	table_now: Dictionary, slots: int, week: int = 1,
	preset: Dictionary = {}, chef_rating: int = 50, familiarity: float = 28.0
) -> Dictionary:
	var pastes: Dictionary = table_now.get("pastes", {})
	if pastes.is_empty():
		return {"pastes": {}, "ratio": {}, "sources": [], "lean": [], "weekly_cost": 0.0}

	## **A target, if the manager set one; otherwise the chef's own rotation.**
	##
	## A preset is convenience bought with precision: the chef approximates it,
	## and how closely is their rating and their familiarity with what is in it.
	## Only a manager standing in the kitchen gets the mix exactly, which is what
	## keeps a preset from being a solve-once button.
	var target: Dictionary = {}
	if not preset.is_empty():
		## Anything the club can no longer reach drops out, so a preset written
		## when a line was running does not keep asking for a paste that stopped
		## arriving.
		for paste in preset:
			if pastes.has(str(paste)):
				target[str(paste)] = float(preset[paste])
		target = Ratio.normalised(target)
	if target.is_empty():
		target = Ratio.even(_rotated(pastes, slots, week))
	var ratio := Ratio.approximated(target, chef_rating, familiarity, week)

	var on_block := {}
	for paste in ratio:
		on_block[str(paste)] = pastes[str(paste)]
	return {
		"pastes": on_block,
		"ratio": ratio,
		"sources": table_now.get("sources", []),
		"lean": table_now.get("lean", []),
		"weekly_cost": float(table_now.get("weekly_cost", 0.0)) + Ratio.cost(ratio),
	}


## The week a manager spread themselves, served as it was spread.
##
## No rotation, no approximation, no ceiling check -- all three of those are
## decisions about what the chef would do with an instruction, and this is the
## case where the manager did it instead. §1's paste ceiling still holds because
## `PastePaint.paint` enforces it at the point paste goes on the block, which is
## the only place it can be enforced against a save file as well as against a
## click.
##
## `coverage` rides along rather than being folded into the ratio. A block that
## is entirely Xérvyan across a third of its surface is a thin meal that tastes
## of one thing; a ratio alone cannot say that, and quietly scaling the shares
## down to sum to a third would have every downstream reader treating a thin week
## as a *mixed* one.
static func served_exactly(
	table_now: Dictionary, painted: Dictionary, _week: int = 1,
	coverage: float = 1.0
) -> Dictionary:
	var pastes: Dictionary = table_now.get("pastes", {})
	var ratio := {}
	var on_block := {}
	for paste in painted:
		var name := str(paste)
		## Painted with something the club can no longer reach. Kept out of the
		## meal rather than silently sourced from nowhere -- a cancelled supply
		## line should cost you the paste on the block, and the coverage figure is
		## where that shows up.
		if not pastes.has(name):
			continue
		ratio[name] = float(painted[paste])
		on_block[name] = pastes[name]
	ratio = Ratio.normalised(ratio)
	return {
		"pastes": on_block,
		"ratio": ratio,
		"sources": table_now.get("sources", []),
		"lean": table_now.get("lean", []),
		"coverage": clampf(coverage, 0.0, 1.0),
		"weekly_cost": float(table_now.get("weekly_cost", 0.0)) + Ratio.cost(ratio),
	}


## Which pastes the chef reaches for when nobody has said otherwise.
##
## Grouped by where they came from and dealt round-robin, so a club with a home
## larder and an import gets both. The first version rotated a flat sorted list
## by index, which let a Landavol club running one Xérvu line be served nothing
## it knew for a whole week -- comfort `0.00` for a squad eating at home, which
## is worse than the dilution the whole function was written to fix.
static func _rotated(pastes: Dictionary, slots: int, week: int) -> Array:
	var by_source := {}
	var order: Array[String] = []
	var names: Array = pastes.keys()
	names.sort()
	for name in names:
		var source := str(pastes[name])
		if not by_source.has(source):
			by_source[source] = []
			order.append(source)
		Array(by_source[source]).append(str(name))
	var taken: Array[String] = []
	var count := clampi(slots, 1, names.size())
	var round_index := 0
	while taken.size() < count and round_index < names.size():
		for source in order:
			if taken.size() >= count:
				break
			var available: Array = Array(by_source[source])
			if available.size() <= round_index:
				continue
			var pick := str(available[posmod(week + round_index, available.size())])
			if not taken.has(pick):
				taken.append(pick)
		round_index += 1
	return taken


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
## §2: palate fatigue decays on the **specific ratio, not the paste**, so
## varying the mix is a real answer and rotating pastes entirely is a stronger
## one. The first build tired a voli of `smoked roe` rather than of *this mix*,
## which made varying the blend worthless.
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


static func nourishment(
	aversion_now: float, palate_now: float, block: String = ""
) -> float:
	var lost := clampf(aversion_now, 0.0, 1.0) * AVERSION_WEIGHT \
		+ clampf(palate_now, 0.0, 1.0) * PALATE_WEIGHT
	## And the block itself, which is the layer §1 authored and the code never
	## had. A squad living on Vollyslommy is happy and slowly getting worse;
	## Supergruel holds them together and grinds the mood down. The nutrition
	## figure is what recovery reads, and the morale figure is not this function's
	## business -- one number per consequence.
	var fed := 1.0
	if not block.is_empty():
		fed = lerpf(BLOCK_FLOOR, 1.0, float(Block.of(block).get("nutrition", 0.7)))
	return maxf((1.0 - lost) * fed, NOURISHMENT_FLOOR)


## What the worst-nourishing block leaves of a week's recovery.
##
## Not zero, and not close to it: §11's rule that a dorm is still a dorm applied
## to the table. A professional squad eating badly is eating badly, not starving,
## and the interesting range is the top of this rather than the bottom.
const BLOCK_FLOOR: float = 0.78


## How much a paste mix is worth on this block, per §1's `takes_paste`.
##
## The multiplier's shape is marked untested in the design and remains so -- it
## scales what the paste layer returns rather than capping the ratio the chef may
## apply, which is the simpler of the two options §1 names.
static func paste_return(block: String, palate_now: float) -> float:
	return (1.0 - clampf(palate_now, 0.0, 1.0)) * Block.takes_paste(block)
