class_name RegionLarder
extends RefCounted

## What each region makes.
##
## `docs/design/ACCOMMODATIONS_AND_CARE.md` §13: a club does not hold stock, it
## has a supply, and the supply is bounded by **where it is**. This is the table
## that makes that true — the thing that turns six taglines into six places that
## eat differently.
##
## ## A region makes pastes. It does not have a grocery list.
##
## **The staples layer is gone, and it was the mistake.** Every region used to
## carry three of them -- barley, rice, sorghum -- alongside its pastes, and that
## quietly built a *second* food system beside the one §1 and §2 already
## describe: blocks are manufactured, universal and bought; pastes are what a
## place makes and what carries its identity. Giving each region a list of
## foodstuffs put culture back in the base of the meal, which is precisely the
## regional-dish reading §1 rejects in writing -- and it made the block layer
## decorative, because if the bulk of the plate already tastes of somewhere, the
## carrier under it has nothing left to do.
##
## So a region produces **pastes and nothing else**. What a voli grew up eating
## is a set of pastes; what a club runs a line for is pastes; what a lean season
## takes away is a paste. The base of the week comes off a shelf and is the same
## shelf everywhere, which is what makes the paste worth caring about.
##
## ## Every entry is authored from the region's own tagline
##
## Not invented alongside it. `VolleyballRegions.DEFINITIONS` already says what
## each region is like, and a larder that disagreed with it would be a second,
## quieter description of the same place — which is how a world stops being one
## world. The `why` column below is the tagline doing the work.
const Regions := preload("res://scripts/data/regions.gd")

## | region | why this larder |
## |---|---|
## | Landavol | *"intentionally broad… specialize into anything"* — a generalist table; a bit of everything, nothing extreme |
## | Spëddigh | *"close-knit and compact"* — preserved, cured, stored; food that keeps through a shared winter |
## | Pāwa Hitō | *"conditioning halls mold the Hitōue"* — a table organised around fuelling work |
## | Bloc du Larg | *"methodical… complete control"* — technique food; things that take a method |
## | Xérvu | *"ancient and new rhythms… individualism"* — heat, and two traditions on one plate |
## | Taktikã | *"strip the game down to its roots"* — the three that grow together and need nothing else |
## Three each, not two.
##
## With the staples gone the paste list *is* the region's whole table, and two
## items made every comparison binary -- a club running one foreign line sat at
## exactly half its own food, which put a share-based comfort band on a knife
## edge with nothing between comfortable and not. Three is the smallest number
## that gives §17's band somewhere to sit.
const LARDERS := {
	"Landavol": {
		"pastes": ["green herb", "sour cream", "pale onion"],
		"lean_seasons": ["winter"],
	},
	"Spëddigh": {
		"pastes": ["smoked roe", "dill and caraway", "brined juniper"],
		## Preserving is the whole point of this larder, so it is the one region
		## with no lean season. It costs them variety instead.
		"lean_seasons": [],
	},
	"Pāwa Hitō": {
		"pastes": ["fermented bean", "citrus salt", "toasted sesame"],
		"lean_seasons": ["autumn"],
	},
	"Bloc du Larg": {
		"pastes": ["shallot and wine", "walnut", "herb butter"],
		"lean_seasons": ["winter", "spring"],
	},
	"Xérvu": {
		"pastes": ["red pepper", "smoked groundnut", "tamarind"],
		"lean_seasons": ["summer"],
	},
	"Taktikã": {
		"pastes": ["ash and lime", "burnt chilli", "pumpkin seed"],
		"lean_seasons": ["spring"],
	},
}

## The two regions that grow nothing, and it is the same fact about both.
##
## `regions.gd` already says Ispayk and A'ace are excluded from the development
## system because *"their identity comes from history and money, not
## geography"*. A larder is geography. So neither has one, and both eat
## imported — which is not a penalty but a description: A'ace buys the best of
## everywhere, Ispayk imports on credit it earned decades ago.
const IMPORTING_REGIONS: Array[String] = ["Ispayk", "A'ace"]

## Four seasons over a season's weeks, so a year has a shape. Weeks are the
## career's own unit; the offset puts week one in spring, which is where a
## volleyball season starts.
const WEEKS_PER_SEASON: int = 13
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]


static func season_for_week(week: int) -> String:
	return SEASONS[posmod(int(floor(float(maxi(week, 1) - 1) / float(WEEKS_PER_SEASON))), SEASONS.size())]


static func has_larder(region: String) -> bool:
	return LARDERS.has(Regions.canonical_name(region))


## What this region produces, this week.
##
## A lean season removes the *last* paste rather than all of them: a region does
## not stop making food in winter, it stops making some of it. Which is what
## makes a lean season a supply problem instead of a famine.
static func produces(region: String, week: int = 1) -> Dictionary:
	var canonical := Regions.canonical_name(region)
	var larder: Dictionary = LARDERS.get(canonical, {})
	if larder.is_empty():
		return {"pastes": [], "lean": false}
	var pastes: Array = Array(larder["pastes"]).duplicate()
	var lean := Array(larder["lean_seasons"]).has(season_for_week(week))
	## Never down to nothing. A region with one paste left is a region having a
	## bad year; a region with none has stopped existing, and no season should do
	## that to a place the map still has volis coming out of.
	if lean and pastes.size() > 1:
		pastes.pop_back()
	return {"pastes": pastes, "lean": lean}


## How far one region is from another, in adjacency steps.
##
## Read off `REGION_ADJACENCY` rather than from a new distance table, because a
## second distance would be a second geography and the two would drift. Returns
## `-1` for regions the graph cannot connect, which is not the same as far --
## it means *no route*, and a caller has to decide what that costs.
static func distance(from_region: String, to_region: String) -> int:
	var start := Regions.canonical_name(from_region)
	var goal := Regions.canonical_name(to_region)
	if start == goal:
		return 0
	var seen := {start: true}
	var frontier: Array[String] = [start]
	var steps := 0
	while not frontier.is_empty() and steps < 12:
		steps += 1
		var next: Array[String] = []
		for here in frontier:
			for neighbour in Array(Regions.REGION_ADJACENCY.get(here, [])):
				var name := str(neighbour)
				if name == goal:
					return steps
				if seen.has(name):
					continue
				seen[name] = true
				next.append(name)
		frontier = next
	return -1
