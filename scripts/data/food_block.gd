class_name FoodBlock
extends RefCounted

## The base of the week, which is manufactured and the same everywhere.
##
## `ACCOMMODATIONS_AND_CARE.md` §1. Four products, and the whole reason they are
## products rather than cuisines is that **culture lives in the paste**. §19
## deleted the per-region staples list for putting culture back into the base of
## the meal; this is the layer that was supposed to be there instead, and it has
## been authored in the design document and absent from the code the entire time.
##
## ## Four axes that deliberately do not move together
##
## | block | nutrition | morale | cost | takes paste |
## |---|---|---|---|---|
## | Supergruel | high | very low | very low | resists it |
## | Chutum Üch | moderate | low | low | **takes it best** |
## | Blan'deral | moderate | moderate | moderate | exactly as advertised |
## | Vollyslommy | low | very high | very high | wasted on it |
##
## The two ends are both bad taken alone, and both correct sometimes: Supergruel
## holds condition together through fixture congestion and grinds morale down;
## Vollyslommy rescues a room after a cup exit and does not feed an athlete. The
## system rewards reading the season rather than finding the best row.
##
## ## `takes_paste` is the axis that stops this being a ladder
##
## Four rows differing on nutrition, morale and cost is a price list, and a price
## list is solved once. What makes the two layers *interact* is that a paste mix
## is worth different amounts depending on what is under it — so neither table
## can be read alone, and the cheap-block-plus-heavy-mix strategy is not
## dominant, because the cheapest block is the one that fights flavour hardest.
##
## **§1 marks the multiplier's shape untested and it still is.** It is applied
## here as a scale on what the paste layer returns, rather than as a cap on the
## ratio the chef may apply. That is the simpler of the two options §1 names and
## it is a choice, not a finding: the risk §1 records — that the interaction
## reads as an arbitrary penalty rather than as a property of the food — is not
## answered by anything measured yet.

## Blan'deral is the reset block, per §0 of the same document: engineered to be
## forgettable, and the one thing palate fatigue does not accumulate on. It is
## the week a manager spends to make the next paste land again.
const BLOCKS := {
	"Supergruel": {
		"nutrition": 0.95, "morale": 0.08, "cost": 0.4, "takes_paste": 0.30,
		"resets_palate": false,
		"why": "engineered nutrition; you cannot paste your way out of it",
	},
	"Chutum Üch": {
		"nutrition": 0.62, "morale": 0.26, "cost": 1.0, "takes_paste": 1.35,
		"resets_palate": false,
		"why": "chew too much, and it is milled to be finished at the table",
	},
	"Blan'deral": {
		"nutrition": 0.68, "morale": 0.52, "cost": 1.9, "takes_paste": 1.00,
		"resets_palate": true,
		"why": "engineered to be forgettable, which is what makes it the reset",
	},
	"Vollyslommy": {
		"nutrition": 0.34, "morale": 0.94, "cost": 4.3, "takes_paste": 0.18,
		"resets_palate": false,
		"why": "arrives already flavoured; paste on it is wasted at best",
	},
}

const DEFAULT_BLOCK: String = "Blan'deral"


static func names() -> Array:
	return BLOCKS.keys()


static func of(block: String) -> Dictionary:
	return Dictionary(BLOCKS.get(block, BLOCKS[DEFAULT_BLOCK]))


static func takes_paste(block: String) -> float:
	return float(of(block).get("takes_paste", 1.0))


static func resets_palate(block: String) -> bool:
	return bool(of(block).get("resets_palate", false))


## ## How many pastes the chef can hold, which is the chef's first job
##
## §1: *"The chef sets how many pastes a block can hold (two to four); the block
## sets how much of each it can take."* Two limiters from two places, and they do
## not substitute for one another.
##
## This is the first thing `VolleyballStaffMember.rating` has ever been read for
## outside the scout — which matters, because until this week no career had any
## staff at all and the chef's rating was a number nobody could reach.
const CHEF_THREE: int = 46
const CHEF_FOUR: int = 72
const SLOTS_MIN: int = 2
const SLOTS_MAX: int = 4


static func paste_slots(chef_rating: int) -> int:
	if chef_rating >= CHEF_FOUR:
		return SLOTS_MAX
	if chef_rating >= CHEF_THREE:
		return 3
	return SLOTS_MIN
