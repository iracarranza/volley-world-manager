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
## Every entry carries a **price**, and a `detail` that is the tooltip rather
## than the label.
##
## The first build listed each item as `console  morale · tactical`, which is two
## words standing in for a trade and reads as neither. What a console does is
## keep a room in it and keep that room a week behind on the week's tactical
## work; that is a sentence, it belongs in a tooltip, and the list itself should
## carry a name and a price and nothing else.
##
## `price` is per room, not per club. A club with nine occupied rooms fitting
## every one with a fan is buying nine fans, and the arithmetic that makes a
## small item cheap at one room and a real outlay at nine is the reason the
## building's size belongs on the same page.
const SMALL_EQUIPMENT := {
	"cookbook": {"answers": "aversion", "cost": "", "price": 340,
		"detail": "Somebody in the room cooks. It answers one voli who cannot"
			+ " eat what is on the table, and only that room."},
	"letterbox": {"answers": "homesick_slow", "cost": "", "price": 120,
		"detail": "Letters, which are slow. It works on somebody a long way from"
			+ " home and takes weeks to do it."},
	"landline": {"answers": "homesick", "cost": "", "price": 480,
		"detail": "They can call home. The fastest answer to homesickness and"
			+ " the one that stops working the week it is taken out."},
	"blackout_curtain": {"answers": "travel", "cost": "oversleeps", "price": 160,
		"detail": "Dark at any hour. Worth it after a flight across the map;"
			+ " actively bad for somebody settled, who will sleep through the"
			+ " morning session."},
	"mattress_topper": {"answers": "", "cost": "", "price": 260,
		"detail": "A better bed. It is a comfort and it changes no number --"
			+ " a dorm is still a dorm, and rest was never about the mattress."},
	"fan": {"answers": "climate", "cost": "", "price": 140,
		"detail": "For a room that is too warm for whoever grew up somewhere"
			+ " colder."},
	"console": {"answers": "morale", "cost": "tactical", "price": 620,
		"detail": "They stay in and play it together. Morale up and the room"
			+ " arrives behind on the week's tactical work, which your assistant"
			+ " will mention before you notice it."},
	"bookshelf": {"answers": "tactical", "cost": "", "price": 220,
		"detail": "Reading, and some of it is about volleyball."},
	"desk": {"answers": "tactical", "cost": "morale", "price": 300,
		"detail": "Somewhere to work. The room studies and the room is duller"
			+ " for it."},
	"record_player": {"answers": "morale", "cost": "neighbour_rest", "price": 540,
		"detail": "The only small thing that leaves the room. It builds a weak"
			+ " tie to the room next door and costs those neighbours some sleep."},
	"kettle": {"answers": "isolation", "cost": "", "price": 90,
		"detail": "People come by for one. Nearly pointless in a Bunkhouse where"
			+ " everybody already shares, and the only thing that works at all"
			+ " in a Row."},
	"privacy_screen": {"answers": "crowding", "cost": "", "price": 210,
		"detail": "Partitions the room. Spends a floor to buy back an occupant's"
			+ " worth of it, which is the one item that trades the two against"
			+ " each other."},
	"houseplant": {"answers": "", "cost": "", "price": 40,
		"detail": "A plant. Somebody has to remember it."},
	"drying_rack": {"answers": "", "cost": "", "price": 70,
		"detail": "Kit dries indoors instead of on a radiator."},
	"trunk": {"answers": "homesick_slow", "cost": "", "price": 180,
		"detail": "Things from home, in a box at the end of the bed."},
}

const LARGE_EQUIPMENT := {
	"free_weights": {"answers": "growth", "cost": "recovery", "price": 1900,
		"detail": "The only athletic object left in here, and it survives"
			+ " because volis genuinely keep weights in their rooms. More room"
			+ " to grow physically, less recovered each week, and eventually"
			+ " somebody hurts a shoulder doing extra."},
	"bath": {"answers": "recovery", "cost": "", "price": 2400,
		"detail": "A bath, not an ice bath -- recovery equipment belongs to the"
			+ " medical staff. This is comfort that happens to help."},
	"kitchenette": {"answers": "aversion", "cost": "morale", "price": 3100,
		"detail": "The room cooks for itself. It answers the table for everybody"
			+ " in it and they stop eating with the rest of the squad."},
	"lounge_corner": {"answers": "isolation", "cost": "quiet", "price": 1500,
		"detail": "Somewhere to sit that is not a bed. The room fills up with"
			+ " other people's rooms."},
	"study_nook": {"answers": "tactical", "cost": "morale", "price": 1300,
		"detail": "A desk with walls round it. Serious, and nobody is having"
			+ " a good time."},
	"instrument": {"answers": "morale", "cost": "neighbour_rest", "price": 1700,
		"detail": "Somebody plays. Whether the neighbours enjoy it is not"
			+ " modelled and they still sleep worse."},
}

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


## ## What a change costs
##
## **Priced, not charged.** Nothing here deducts from `career.finances`, because
## the club economy that would judge these numbers does not exist yet -- there is
## no income, no other outgoing and no bankruptcy path, and a game where the
## right answer is always the cheapest lease is worse than one where the price is
## a comparison. See `BACKLOG`.
##
## What the price is *for* is the interface. An arrangement you change by
## ticking a box is an arrangement the game has told you is free, and none of
## these are: fitting nine rooms with a console is nine consoles, and moving a
## squad into a Row is a lease, a deposit and a fortnight of nobody knowing where
## anything is.
##
## A move is priced off the lease rather than given its own table, so a structure
## that is dear to rent is dear to move into and the foreign multiplier carries
## through without being applied twice.
const MOVE_COST_PER_RENT: float = 9000.0
## And how long a squad takes to settle, which is the cost that is not money.
## §16: moving hurts, and it hurts about *what it says* rather than about the
## beds.
const SETTLING_WEEKS: int = 2
## What a settling squad banks of a week's recovery. Recovered linearly across
## the settling period rather than switching back on, because a squad does not
## finish unpacking on a Tuesday.
const SETTLING_REST: float = 0.82


static func move_cost(structure: String, club_region: String) -> int:
	return int(roundf(rent_for(structure, club_region) * MOVE_COST_PER_RENT))


## What fitting every occupied room with this costs.
##
## Per room, which is what makes the building's size a term in the decision
## rather than a label on it: the same fan is 140 in a Farmhouse's six rooms and
## a different question in a Block's twenty.
static func fitting_cost(item: String, rooms: int) -> int:
	var entry: Dictionary = SMALL_EQUIPMENT.get(item, LARGE_EQUIPMENT.get(item, {}))
	return int(entry.get("price", 0)) * maxi(rooms, 1)


static func detail_for(item: String) -> String:
	var entry: Dictionary = SMALL_EQUIPMENT.get(item, LARGE_EQUIPMENT.get(item, {}))
	return str(entry.get("detail", ""))


## How many rooms this squad actually occupies.
##
## Derived rather than stored, and capped by the building: a squad larger than
## the structure holds is sleeping somewhere, and that somewhere is these rooms
## with more people in them.
static func rooms_occupied(structure: String, squad: int, per_room: int) -> int:
	var rooms := int(Dictionary(STRUCTURES.get(structure, {})).get("rooms", 9))
	if squad <= 0:
		return 0
	return clampi(ceili(float(squad) / float(maxi(per_room, 1))), 1, rooms)


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
	palate_now: float, small: Array = [], settling_weeks: int = 0
) -> float:
	var share := rest_multiplier(crowding_now, homesick_now, discomfort_now, small) \
		* FoodSupply.nourishment(discomfort_now, palate_now)
	## A squad that has just moved banks less of the week, and it is the same
	## number whatever they moved into -- §16 is explicit that the hit is about
	## what the move says rather than about the quality of the beds.
	if settling_weeks > 0:
		share *= SETTLING_REST
	return share
