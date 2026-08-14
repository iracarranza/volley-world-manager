class_name RecruitOffer
extends RefCounted

## What joining this club would actually be like, computed rather than authored.
##
## ## Why this exists
##
## `sign_transfer` moved a voli onto the roster in one click: no fee, no
## conversation, no consent, and **no check that there was a bed.** A club in
## this game is not merely where a voli trains -- it is where they sleep, eat and
## live -- so a transaction that asks only *can we afford them* is asking a
## fraction of the question.
##
## Everything here is read off tables that already exist. `Accommodation` knows
## what a room holds and what crowds it; `FoodSupply` knows what is on the block
## and what this voli grew up eating. Nothing is stored and no preference
## attribute is invented -- inventing a "sharing preference" and then guessing
## its bands is `FAILURE_MODES.md` §0 in its most tempting form, a knob that
## reads plausibly and can be checked against nothing.
##
## ## Two kinds of thing, shown two ways
##
## A **physical fact about a room** is countable and shows as a number: floor,
## occupants, what is left. A manager can add those up themselves and being coy
## about them is just hiding arithmetic.
##
## A **judgment about a person** is not, and shows as a word. What a voli makes
## of the food is not 0.43; it is *nothing here is theirs*. The share exists and
## drives the simulation, and the manager gets the sentence.
##
## ## And it is deliberately a function, not a record
##
## No offer object is stored. The terms are recomputed from the club whenever
## they are asked for, so an offer cannot go stale against a squad that grew or a
## supply line that stopped -- and nothing has to migrate when the interview
## arrives to sit in front of this.

const Accommodation := preload("res://scripts/data/accommodation.gd")
const FoodSupply := preload("res://scripts/data/food_supply.gd")
const Larder := preload("res://scripts/data/region_larder.gd")


## The room this voli would be put in, and what is left of it once they are.
##
## Rooms fill in roster order, `per_room` at a time, so the newcomer takes seat
## `squad_size % per_room` of room `squad_size / per_room`. That is the same rule
## `rooms_occupied` counts by, stated as a position rather than a total -- and it
## has to be the same rule, or the housing folder and this sheet would disagree
## about how many rooms are in use.
##
## `capacity` is per room, not per building: `STRUCTURES` gives a Bunkhouse floor
## 5.0 across 9 rooms, and 5.0 is what one room holds.
static func proposed_room(
	structure: String, per_room: int, squad_size: int,
	small: Array = [], large: Array = []
) -> Dictionary:
	var seats := maxi(per_room, 1)
	var index := maxi(squad_size, 0)
	var room := index / seats
	var seat := index % seats
	var occupants := seat + 1
	var capacity := float(
		Dictionary(Accommodation.STRUCTURES.get(structure, {})).get("floor", 5.0)
	)
	var used := Accommodation.floor_used(occupants, small, large)
	return {
		"room": room + 1,
		"seat": seat + 1,
		"sharing_with": seat,
		"fresh": seat == 0,
		"occupants": occupants,
		"capacity": capacity,
		"used": used,
		## Signed on purpose. A negative remainder is the interesting case -- the
		## room they would go into does not fit them -- and clamping it to zero
		## would report a full room and an overfull one as the same room.
		"left": capacity - used,
		"crowds": Accommodation.crowding(structure, occupants, small, large),
	}


## Who is already in there.
##
## The same ordering `proposed_room` positions by, so the names returned are the
## people whose room this is rather than the first few volis on the list.
static func room_mates(players: Array, per_room: int, squad_size: int) -> Array:
	var seats := maxi(per_room, 1)
	var first := (maxi(squad_size, 0) / seats) * seats
	var mates: Array[String] = []
	for index in range(first, mini(maxi(squad_size, 0), players.size())):
		var player = players[index]
		if player != null:
			mates.append(str(player.display_name))
	return mates


## Where the club's own paste sits against what this voli was raised on.
##
## The bands are `FoodSupply`'s own -- their band floor and the ceiling -- rather
## than three numbers chosen here, so the sentence a recruit is given and the
## discomfort their recovery is charged cannot drift apart. That is the whole
## reason this reads the band instead of picking thresholds: a word that
## disagrees with the simulation behind it is worse than no word.
static func table_word(palate_regions: Array, service: Dictionary) -> String:
	if Dictionary(service.get("pastes", {})).is_empty():
		return "nobody has said what the club eats"
	var share := FoodSupply.comfort_share(palate_regions, service)
	var floor_now := float(FoodSupply.band_for(palate_regions)["floor"])
	if share >= FoodSupply.COMFORT_CEILING:
		return "they would be eating at home"
	if share >= floor_now:
		return "enough of it is theirs"
	if share > 0.0:
		return "some of it is theirs, and not enough"
	return "nothing on the block is theirs"


## What this voli would actually raise, derived from real misfit.
##
## Deliberately only the things that are *true of this club and this person*. A
## list that always has four items on it is a form; a list that is usually empty
## and occasionally says something specific is a conversation. A recruit with no
## entry here has nothing to ask about, and the sheet should say so rather than
## inventing a concern to fill the panel.
static func concerns(
	prospect, structure: String, room: Dictionary,
	service: Dictionary, club_region: String
) -> Array[String]:
	var raised: Array[String] = []

	if float(room.get("left", 0.0)) < 0.0:
		raised.append("\"Where would I actually put anything?\"")
	elif float(room.get("crowds", 0.0)) > 0.0:
		raised.append("\"How many of us are in there?\"")
	elif bool(room.get("fresh", false)):
		raised.append("\"I'd have the room to myself, then?\"")

	## The structure says something before anybody describes it. These are the
	## `STRUCTURES` entries' own characters -- a Row rests well and builds
	## nothing, a Longhouse is the reverse -- so a recruit reacts to the building
	## the club actually leases.
	if structure == "Row":
		raised.append("\"Does anyone see each other, living like that?\"")
	elif structure == "Longhouse":
		raised.append("\"Is it ever quiet?\"")

	var palate: Array = []
	if "palate_regions" in prospect:
		palate = Array(prospect.palate_regions)
	if not palate.is_empty():
		var share := FoodSupply.comfort_share(palate, service)
		if share <= 0.0:
			raised.append("\"What is it you eat here?\"")
		elif share < float(FoodSupply.band_for(palate)["floor"]):
			raised.append("\"Is there ever %s?\"" % Larder.paste_name(str(palate[0])))

	## Homesickness is derived from two places rather than stored (§16), so this
	## asks the same question `Accommodation.homesick` does and gets the same
	## answer the recovery model will get after they sign.
	if "home_region" in prospect \
			and Accommodation.homesick(str(prospect.home_region), club_region):
		raised.append("\"How far is it back?\"")

	return raised
