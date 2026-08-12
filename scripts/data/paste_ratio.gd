class_name PasteRatio
extends RefCounted

## How much of each paste goes on the block.
##
## §2: *"Pastes are mixed into a base meal at a chosen ratio."* Not a set — a
## **mix**. The first build treated the week as a list of two to four pastes and
## that lost the decision: half Landavolan and a trace of Xérvyan is a different
## week from an even split of the two, and the difference is most of what the
## table is for.
##
## A ratio is `{paste_name: share}` with the shares summing to one.
##
## ## Three rules, all of them §2's
##
## **Ratio costs non-linearly.** A trace is cheap and a heavy mix costs
## disproportionately, so a squad-wide indulgence is a real budget decision while
## targeting one voli's preference stays affordable.
##
## **Palate fatigue decays on the specific ratio, not the paste.** That is the
## rule the first build got wrong: it tired a voli of *smoked roe* rather than of
## *this mix*, which made varying the blend worthless and rotating pastes the
## only answer. §2 wants both to work, with rotation the stronger one.
##
## **Two to four, and the chef sets how many.** The ceiling is `FoodBlock`'s and
## it is hard: the best chef alive cannot hold five.
const Larder := preload("res://scripts/data/region_larder.gd")

## What a share of the mix costs, relative to its share.
##
## Superlinear, so doubling a paste's share more than doubles its cost. The
## exponent is the shape §2 asks for rather than a measured number, and it is
## marked as such: there is no club budget to measure a food bill against yet.
const COST_EXPONENT: float = 1.6
## Below this a paste is a trace rather than an ingredient, and the chef stops
## counting it against their ceiling. It is what makes "a hint of Xérvyan"
## affordable for one voli without spending a slot.
const TRACE_SHARE: float = 0.08


## An even split across these pastes.
##
## The default a chef falls to when nobody has said otherwise, and the thing a
## preset is measured against.
static func even(pastes: Array) -> Dictionary:
	var out := {}
	if pastes.is_empty():
		return out
	var share := 1.0 / float(pastes.size())
	for paste in pastes:
		out[str(paste)] = share
	return out


## Rescale so the shares sum to one, dropping anything at zero.
static func normalised(ratio: Dictionary) -> Dictionary:
	var total := 0.0
	for paste in ratio:
		total += maxf(float(ratio[paste]), 0.0)
	if total <= 0.0:
		return {}
	var out := {}
	for paste in ratio:
		var share := maxf(float(ratio[paste]), 0.0) / total
		if share > 0.0:
			out[str(paste)] = share
	return out


## What this week's mix costs, in the same abstract unit a supply line uses.
static func cost(ratio: Dictionary) -> float:
	var total := 0.0
	for paste in ratio:
		total += pow(clampf(float(ratio[paste]), 0.0, 1.0), COST_EXPONENT)
	return total


## How many of these count against the chef's ceiling.
##
## Traces do not. A chef holding three pastes and a whisper of a fourth is
## holding three, which is what stops the trace rule being a way to smuggle a
## fifth flavour past the ceiling §2 calls hard.
static func slots_used(ratio: Dictionary) -> int:
	var count := 0
	for paste in ratio:
		if float(ratio[paste]) >= TRACE_SHARE:
			count += 1
	return count


## A stable name for a mix, so palate fatigue can accumulate on **the ratio**.
##
## Rounded to a tenth before it is keyed, which is the whole reason this function
## exists rather than the dictionary being used directly: a ratio that drifts by
## a thousandth is the same meal, and a key that noticed would give a manager a
## fresh palate every week for doing nothing.
const KEY_STEPS: float = 10.0


static func key(ratio: Dictionary) -> String:
	var parts: Array[String] = []
	var names: Array = ratio.keys()
	names.sort()
	for paste in names:
		var step := roundi(float(ratio[paste]) * KEY_STEPS)
		if step > 0:
			parts.append("%s@%d" % [str(paste), step])
	return "|".join(parts)


## ## What the chef actually cooks
##
## A preset is a **target**, not an instruction. §2's chef has a ceiling on how
## many pastes they can hold; this is the other half of the same idea -- how
## closely they can hold a mix they have been asked for.
##
## Only a manager standing in the kitchen gets the ratio exactly. A chef told to
## follow a preset approximates it, and how well is their rating and their
## familiarity with the pastes in it. That is the trade the whole feature is
## for: a preset is convenience bought with precision, and a manager who wants
## the exact mix has to spend the week's attention on it.
const DRIFT_AT_WORST: float = 0.14
const DRIFT_AT_BEST: float = 0.02


## How far a chef of this quality wanders from a target, as a share.
static func drift_for(chef_rating: int, familiarity: float) -> float:
	## Rating and familiarity both pull it down, and neither alone reaches the
	## floor: a brilliant chef who has never met a paste still fumbles the
	## proportions, and a chef who knows it inside out is still only as steady as
	## they are.
	var skill := clampf(float(chef_rating) / 100.0, 0.0, 1.0)
	var known := clampf(familiarity / 100.0, 0.0, 1.0)
	return lerpf(DRIFT_AT_WORST, DRIFT_AT_BEST, (skill * 0.6) + (known * 0.4))


## The mix that actually reached the plate.
##
## Deterministic in the week, so the food screen and the chef's own report never
## disagree about what was served -- and so a manager who reloads a save is not
## rerolling their dinner.
static func approximated(
	target: Dictionary, chef_rating: int, familiarity: float, week: int
) -> Dictionary:
	var drift := drift_for(chef_rating, familiarity)
	if drift <= 0.0001 or target.is_empty():
		return normalised(target)
	var out := {}
	var names: Array = target.keys()
	names.sort()
	for index in range(names.size()):
		var paste := str(names[index])
		## A signed wobble per paste, from the week and the paste's own name, so
		## one is a little heavy and another a little light rather than all of
		## them drifting the same way.
		var swing := float(absi(hash("%s:%d" % [paste, week])) % 2000 - 1000) / 1000.0
		out[paste] = maxf(float(target[paste]) + swing * drift, 0.0)
	return normalised(out)


## Whether what was served is close enough to be called the preset.
##
## The tolerance a report is written against: a chef who lands inside it says
## they cooked what you asked for, and one who does not says so.
const HELD_TOLERANCE: float = 0.06


static func held(target: Dictionary, served_now: Dictionary) -> bool:
	for paste in target:
		var want := float(target[paste])
		var got := float(served_now.get(paste, 0.0))
		if absf(want - got) > HELD_TOLERANCE:
			return false
	return true


## How much nourishment this week's mix carries, given what each paste is like
## this season.
##
## The trade the condition mechanic exists to create: a paste that came in rich
## is worth feeding even if the chef barely knows it and the squad did not grow
## up on it, and a manager who chases that every season is a manager whose chef
## never gets good at anything.
static func nourishment(ratio: Dictionary, region_of: Dictionary, week: int) -> float:
	if ratio.is_empty():
		return 1.0
	var total := 0.0
	for paste in ratio:
		var region := str(region_of.get(paste, ""))
		total += float(ratio[paste]) * Larder.nourishment_of(region, week)
	return total
