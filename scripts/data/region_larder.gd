class_name RegionLarder
extends RefCounted

## What each region makes.
##
## `docs/design/ACCOMMODATIONS_AND_CARE.md` §13: a club does not hold stock, it
## has a supply, and the supply is bounded by **where it is**. This is the table
## that makes that true — the thing that turns six taglines into six places that
## eat differently.
##
## ## A region makes *one* paste, and it is called after the region
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
## So a region produces **one paste and nothing else**, and it is named after the
## region: Landavolan paste, Spëddigh paste, Xérvyan paste. That is the second
## correction. The first pass gave each region two or three *ingredients* --
## `pale onion`, `sour cream`, `smoked groundnut` -- which is the grocery list
## again wearing a smaller hat. §2 is explicit that the authored names are a
## *sketch of an axis* and that "the point is coverage, not these exact names",
## so the axis stays as a property and the name comes off the map.
##
## Which is also the only naming that lets a chef say the sentence the whole
## staff correspondence is built on -- *"I improved my use of Landavolan paste"*
## -- without the manager having to remember that pale onion is a Landavol thing.
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
## What each region makes, and what kind of thing it is.
##
## `axis` is §2's coverage sketch -- a sharp ferment, a bitter herb, a heavy
## sweet, a fatty savoury, a sour citrus, a numbing spice, a smoky char, a clean
## umami. Eight axes across twelve larders, so some regions share one, which is
## correct: two places can both make something sharp without making the same
## thing. The axis is what a **body type** tolerates, per §2's rule that region
## supplies familiarity and body supplies tolerance and the two are allowed to
## disagree.
const LARDERS := {
	"Landavol": {"axis": "clean umami", "lean_seasons": ["winter"]},
	## Preserving is the whole point of this larder, so it is the one region with
	## no lean season. It costs them variety instead.
	"Spëddigh": {"axis": "sharp ferment", "lean_seasons": []},
	"Pāwa Hitō": {"axis": "fatty savoury", "lean_seasons": ["autumn"]},
	"Bloc du Larg": {"axis": "bitter herb", "lean_seasons": ["winter", "spring"]},
	"Xérvu": {"axis": "numbing spice", "lean_seasons": ["summer"]},
	"Taktikã": {"axis": "smoky char", "lean_seasons": ["spring"]},
	"Tu'ul ys Feynt": {"axis": "sour citrus", "lean_seasons": ["winter"]},
	"Lo-onğ Ralī": {"axis": "heavy sweet", "lean_seasons": ["summer"]},
	"Bompaşao": {"axis": "sharp ferment", "lean_seasons": ["autumn"]},
	"Rhen Tempaol": {"axis": "bitter herb", "lean_seasons": ["winter"]},
	"Kutré Lyn": {"axis": "numbing spice", "lean_seasons": ["spring"]},
	"Zaitgaist": {"axis": "clean umami", "lean_seasons": ["autumn"]},
}


## The two regions that make nothing, and it is the same fact about both.
##
## `regions.gd` already says Ispayk and A'ace are excluded from the development
## system because *"their identity comes from history and money, not
## geography"*. A paste is geography. So neither has one, and both eat imported
## -- which is not a penalty but a description: A'ace buys the best of
## everywhere, Ispayk imports on credit it earned decades ago.
const IMPORTING_REGIONS: Array[String] = ["Ispayk", "A'ace"]

const WEEKS_PER_SEASON: int = 13
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]


static func season_for_week(week: int) -> String:
	return SEASONS[posmod(int(floor(
		float(maxi(week, 1) - 1) / float(WEEKS_PER_SEASON)
	)), SEASONS.size())]


static func has_larder(region: String) -> bool:
	return LARDERS.has(Regions.canonical_name(region))


## What this region's paste is called.
##
## The demonym, which `DEMONYMS` already carries and the roster already obeys:
## you are *from* Xérvu and the flavour is *Xérvyan*.
static func paste_name(region: String) -> String:
	var canonical := Regions.canonical_name(region)
	return "%s paste" % str(Regions.DEMONYMS.get(canonical, canonical))


static func axis_of(region: String) -> String:
	return str(Dictionary(LARDERS.get(
		Regions.canonical_name(region), {}
	)).get("axis", ""))


## ## A paste is not the same every season
##
## The event the design asks for: a paste can come in hardier or leaner, richer
## or thinner, and that is a reason to change what you feed a squad **against**
## your chef's proficiency and your volis' preferences. A club with a chef who
## knows Landavolan paste and a squad that likes it still has to decide what to
## do about a year when the Xérvyan is unusually nourishing.
##
## Derived from the region and the season rather than rolled, for the reason the
## whole world is derived: a fact about a place in a year is the same fact every
## time it is asked, and a roll would make the chef's report and the food screen
## disagree about the same paste.
const CONDITION_LEAN: String = "lean"
const CONDITION_USUAL: String = "usual"
const CONDITION_RICH: String = "rich"
## What each condition does to the nourishment a paste carries.
const CONDITION_NOURISHMENT := {
	CONDITION_LEAN: 0.82, CONDITION_USUAL: 1.0, CONDITION_RICH: 1.18,
}


static func condition(region: String, week: int = 1) -> String:
	var canonical := Regions.canonical_name(region)
	if not has_larder(canonical):
		return CONDITION_USUAL
	## A season, not a week: food does not change character on a Tuesday, and a
	## condition that moved weekly would be noise rather than news.
	var season := int(floor(float(maxi(week, 1) - 1) / float(WEEKS_PER_SEASON)))
	var roll := absi(hash("%s:%d" % [canonical, season])) % 100
	if roll < 18:
		return CONDITION_LEAN
	if roll < 34:
		return CONDITION_RICH
	return CONDITION_USUAL


static func nourishment_of(region: String, week: int = 1) -> float:
	return float(CONDITION_NOURISHMENT.get(condition(region, week), 1.0))


## What this region produces, this week.
##
## A lean *season* is a supply problem -- the paste is short, and a club running
## a line to it may not get what it paid for. A lean *condition* is a quality
## problem, and the two are deliberately different: one is about whether the
## paste arrives, the other about what is in it when it does.
static func produces(region: String, week: int = 1) -> Dictionary:
	var canonical := Regions.canonical_name(region)
	var larder: Dictionary = LARDERS.get(canonical, {})
	if larder.is_empty():
		return {"pastes": [], "lean": false, "condition": CONDITION_USUAL}
	var lean := Array(larder["lean_seasons"]).has(season_for_week(week))
	return {
		"pastes": [paste_name(canonical)],
		"lean": lean,
		"condition": condition(canonical, week),
	}


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


## ## What a paste looks like in the pot
##
## The block is painted with these, so a paste has to be a colour before it can be
## a share -- and the colour has to say *what it tastes of*, because that is the
## only property of a paste a cook can see. Two regions on the same axis are near
## neighbours here on purpose: a Bompaşaon ferment and a Spëddigh ferment are both
## pale and sour-looking, and telling them apart is the label's job, not the
## colour's.
##
## Deliberately not the region's map colour. A paste is not a flag; a heavy sweet
## is treacle-dark wherever it was made.
const AXIS_COLOURS := {
	"clean umami": Color("9a6f3c"),
	"sharp ferment": Color("c4b25c"),
	"fatty savoury": Color("8c3f2c"),
	"bitter herb": Color("55663a"),
	"numbing spice": Color("a83b34"),
	"smoky char": Color("4a423c"),
	"sour citrus": Color("bdc457"),
	"heavy sweet": Color("5c3a30"),
}
## The unknown paste, which should not be pretty. Nobody should be able to paint
## a nice-looking block out of a region that has no larder.
const UNKNOWN_COLOUR := Color("7a7168")

## How far two pastes on one axis are allowed to drift apart.
##
## Small: they are the same kind of thing. Large enough that a manager mixing two
## ferments can tell which half of the block is which, which is the whole reason
## this is not just `AXIS_COLOURS[axis]`.
const REGION_TINT_SPREAD: float = 0.12


static func paste_colour(region: String) -> Color:
	var canonical := Regions.canonical_name(region)
	var base: Color = AXIS_COLOURS.get(axis_of(canonical), UNKNOWN_COLOUR)
	if not has_larder(canonical):
		return UNKNOWN_COLOUR
	## Seeded from the region's own name, so a paste is the same colour every time
	## it is poured and no two are mixed by hand.
	var seed_value := int(canonical.hash() & 0x7FFFFFFF)
	var shade := (float(seed_value % 1000) / 1000.0 - 0.5) * REGION_TINT_SPREAD
	var warmth := (float((seed_value / 1000) % 1000) / 1000.0 - 0.5) \
		* REGION_TINT_SPREAD * 0.7
	return Color(
		clampf(base.r + shade + warmth, 0.0, 1.0),
		clampf(base.g + shade, 0.0, 1.0),
		clampf(base.b + shade - warmth, 0.0, 1.0),
	)
