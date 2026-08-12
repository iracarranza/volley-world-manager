class_name Accommodation
extends RefCounted

## Where the volis live, and what living there does to them.
##
## `docs/design/ACCOMMODATIONS_AND_CARE.md` §10–§17. Two rules carry the whole
## system and everything else is a consequence of them.
##
## **A dorm is still a dorm.** Even at base it is a room built for athletes to
## sleep in, and nobody rests badly because of where they live. Quality of bed is
## not an axis, which is what stops this becoming three dials against money. What
## reduces rest are *conditions* — homesickness, a table with nothing familiar on
## it, a room with too many people in it — and every one of those varies by who
## you signed rather than by what you paid.
##
## **Occupancy and equipment compete for the same floor.** A person takes floor
## and so does a rack of weights, which is why a bigger room does not mean better,
## it means you may choose differently.
const FoodSupply := preload("res://scripts/data/food_supply.gd")

## Floor, in the unit everything is spent against.
const FLOOR_PER_OCCUPANT: float = 2.0
const FLOOR_SMALL_ITEM: float = 1.0
const FLOOR_LARGE_ITEM: float = 3.0


## ## The structures
##
## They **specialise rather than climb**, and there is no top of this list. The
## Row is not above the Commons; it is *later*, and only for some sides — best
## rest in the game, most personal floor, and it builds no pairs at all.
##
## `region` is whose practice a structure is, per §12: what is easy to find and
## cheap to lease there, not a law about who may live in one. Clubs **rent**
## (§15), so a Landavol club can lease a Row; it will simply pay for a way of
## living that is unusual where it is.
const STRUCTURES := {
	"Bunkhouse": {
		"floor": 5.0, "rooms": 9, "region": "",
		"common": false, "rent": 1.0, "organization": "Founded",
		"why": "the universal starting point, which is why it is nobody's identity",
	},
	"Longhouse": {
		"floor": 3.0, "rooms": 14, "region": "Spëddigh",
		"common": true, "rent": 0.7, "organization": "Founded",
		"why": "close-knit and compact -- everybody knows everybody, nobody sleeps well",
	},
	"Commons": {
		"floor": 6.0, "rooms": 8, "region": "Taktikã",
		"common": true, "rent": 1.6, "organization": "Established",
		"why": "a shared room at the heart of it, and it is a working room",
	},
	"Farmhouse": {
		"floor": 6.0, "rooms": 6, "region": "Landavol",
		"common": true, "rent": 1.4, "organization": "Established",
		"why": "a kitchen and a garden; it houses a small squad and no more",
	},
	"Quarters": {
		"floor": 5.0, "rooms": 10, "region": "Pāwa Hitō",
		"common": false, "rent": 2.1, "organization": "Established",
		"why": "you live where you train, and nothing about living there is not volleyball",
	},
	"Block": {
		"floor": 6.0, "rooms": 20, "region": "Bloc du Larg",
		"common": true, "rent": 1.5, "organization": "Established",
		"why": "houses everyone including the youth, and they still never meet",
	},
	"Row": {
		"floor": 7.0, "rooms": 12, "region": "Xérvu",
		"common": false, "rent": 2.6, "organization": "Established",
		"why": "best rest, most floor, and it builds no pairs at all",
	},
}

## What a structure out of its region costs to lease, as a multiplier.
##
## §15: you can house your squad any way you like, and you will pay for the ways
## that are unusual here. A multiplier rather than a prohibition, because
## regional practice as an ownership rule is a cage — a club playing abroad would
## have nowhere to sleep.
const FOREIGN_RENT_MULTIPLIER: float = 1.55


static func rent_for(structure: String, club_region: String) -> float:
	var entry: Dictionary = STRUCTURES.get(structure, {})
	if entry.is_empty():
		return 0.0
	var base := float(entry["rent"])
	var home := str(entry["region"])
	if home.is_empty() or home == club_region:
		return base
	return base * FOREIGN_RENT_MULTIPLIER


## Which kind of club leases this, per §15 — the housing choice at save
## generation carries the information Established/Founded used to, and carries
## it concretely.
static func organization_for(structure: String) -> String:
	return str(Dictionary(STRUCTURES.get(structure, {})).get("organization", "Founded"))


## ## The equipment
##
## All of it **domestic**. §11's correction: every club has a gym and a film
## room, so putting them here made accommodation a second training facility,
## which is the one thing it is not. The volis *live* here.
##
## And each piece answers a **condition, not a role** (§8). The cookbook and the
## landline always did — a voli either is homesick or is not, and that changes.
## Generalising their shape is what keeps a room worth reopening: weights matter
## to a voli with growth left, a console to one whose morale is low.
const SMALL_EQUIPMENT := {
	"cookbook": {"answers": "aversion", "cost": ""},
	"letterbox": {"answers": "homesick_slow", "cost": ""},
	"landline": {"answers": "homesick", "cost": ""},
	## They wake up late. A cost against the *timetable* rather than against
	## another quantity, which is why it is the best small item on the list:
	## worth it after a flight, actively bad for somebody settled and training
	## every morning.
	"blackout_curtain": {"answers": "travel", "cost": "oversleeps"},
	"mattress_topper": {"answers": "", "cost": ""},
	"fan": {"answers": "climate", "cost": ""},
	"console": {"answers": "morale", "cost": "tactical"},
	"bookshelf": {"answers": "tactical", "cost": ""},
	"desk": {"answers": "tactical", "cost": "morale"},
	## The only small item that leaves the room: a weak tie to the next room,
	## paid for in the neighbours' rest.
	"record_player": {"answers": "morale", "cost": "neighbour_rest"},
	## Builds pairs with *visitors* rather than roommates -- nearly redundant in
	## a Bunkhouse, the only thing that works at all in the Row.
	"kettle": {"answers": "isolation", "cost": ""},
	## Spends floor to buy back occupancy, which is the floor rule paying off.
	"privacy_screen": {"answers": "crowding", "cost": ""},
	"houseplant": {"answers": "", "cost": ""},
	"drying_rack": {"answers": "", "cost": ""},
	"trunk": {"answers": "homesick_slow", "cost": ""},
}

const LARGE_EQUIPMENT := {
	## The only athletic object left, and it survives because volis genuinely
	## keep weights in their rooms and genuinely hurt themselves doing extra.
	"free_weights": {"answers": "growth", "cost": "recovery"},
	## A bath, not an ice bath. Recovery equipment belongs to the medical staff;
	## a bath is domestic, is comfort, and happens to help.
	"bath": {"answers": "recovery", "cost": ""},
	"kitchenette": {"answers": "aversion", "cost": "morale"},
	"lounge_corner": {"answers": "isolation", "cost": "quiet"},
	"study_nook": {"answers": "tactical", "cost": "morale"},
	"instrument": {"answers": "morale", "cost": "neighbour_rest"},
}

## Installations that need a shared room, which is what the Commons buys and
## what the Row gives up. All living-room rather than facility.
const SHARED_INSTALLATIONS := {
	"long_table": {"answers": "isolation_squad", "cost": ""},
	"hearth": {"answers": "morale_squad", "cost": ""},
	"big_kitchen": {"answers": "aversion_squad", "cost": ""},
	"washing_room": {"answers": "", "cost": ""},
	"porch": {"answers": "morale_squad", "cost": ""},
	## Does not change what happens, changes **when you are told**, which is the
	## event system's whole currency.
	"noticeboard": {"answers": "warning", "cost": ""},
}


static func floor_used(occupants: int, small: Array, large: Array) -> float:
	return float(occupants) * FLOOR_PER_OCCUPANT \
		+ float(small.size()) * FLOOR_SMALL_ITEM \
		+ float(large.size()) * FLOOR_LARGE_ITEM


## How far over its floor a room is, in occupants.
##
## **Crowding is a play, not a failure.** You crowd a room when you want two
## volis to know each other by the qualifier: rest drops, pair familiarity climbs
## faster, and the relationship crash becomes reachable. A privacy screen buys
## one occupant of it back, which is the one item that spends floor on occupancy.
static func crowding(
	structure: String, occupants: int, small: Array, large: Array
) -> float:
	var capacity := float(Dictionary(STRUCTURES.get(structure, {})).get("floor", 5.0))
	var over := floor_used(occupants, small, large) - capacity
	if over <= 0.0:
		return 0.0
	var relieved := over
	if small.has("privacy_screen"):
		relieved -= FLOOR_PER_OCCUPANT
	return maxf(relieved, 0.0) / FLOOR_PER_OCCUPANT


## What a week of living here does to one voli's rest, as a multiplier.
##
## **Never below `REST_FLOOR`.** A dorm is still a dorm: nobody rests badly
## because of where they live, only because of what is happening to them. The
## terms are conditions -- crowded, homesick, eating among strangers -- and each
## is answerable by something a manager can install or arrange.
const REST_FLOOR: float = 0.55
const CROWDING_COST: float = 0.11
const HOMESICK_COST: float = 0.09
const FOOD_COST: float = 0.14


static func rest_multiplier(
	crowding_now: float, homesick: bool, discomfort_now: float,
	small: Array = []
) -> float:
	var lost := crowding_now * CROWDING_COST + discomfort_now * FOOD_COST
	if homesick and not (small.has("landline") or small.has("letterbox") \
			or small.has("trunk")):
		lost += HOMESICK_COST
	return maxf(1.0 - lost, REST_FLOOR)


## Whether this voli is homesick here.
##
## Derived (§16), not stored: they are far from where they grew up and the club
## is not there. Nothing per-voli is authored, and it stops being true the moment
## they transfer home.
static func homesick(home_region: String, club_region: String) -> bool:
	return home_region != club_region and not home_region.is_empty()


## How much of a week's recovery this voli actually banks.
##
## The single number accommodation contributes, applied to
## `CareerManager.WEEKLY_FATIGUE_RECOVERY`. Food and housing multiply rather than
## add, because a voli sleeping badly *and* eating among strangers is worse than
## either alone, and neither can rescue the other.
static func weekly_recovery_share(
	crowding_now: float, homesick_now: bool, discomfort_now: float,
	palate_now: float, small: Array = []
) -> float:
	return rest_multiplier(crowding_now, homesick_now, discomfort_now, small) \
		* FoodSupply.nourishment(discomfort_now, palate_now)
