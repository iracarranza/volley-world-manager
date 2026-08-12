class_name ClubEvents
extends RefCounted

## What the club tells you, and why it is the only thing that makes the rooms
## worth reopening.
##
## `ACCOMMODATIONS_AND_CARE.md` §9. The equipment in a room has real two-sided
## costs — weights buy growth and cost recovery, a console buys morale and costs
## tactical work — and the objection that survived review was not that the costs
## were missing. It was that **a standing −X% on a number nobody watches is a
## downside on paper.**
##
## So the events are not a separate system that happens to touch this one. They
## are how a room's downside becomes knowable:
##
## | event | is really |
## |---|---|
## | a voli hurt their arm doing extra | *the weights room, reporting* |
## | a coach on a room behind on tactical work | *the console, reporting* |
## | a voli who has stopped getting on with their roommate | *the crowding trade, reporting, early enough to act* |
## | the chef, short after a bad season | *the supply line, reporting* |
##
## The effects stay constant and legible, which is right — a manager should be
## able to reason about them. What varies is **whether you have been told yet.**
## A room becomes a question because somebody knocked on the door, not because a
## multiplier moved.
##
## ## Two voices, and they are not the same text
##
## Inherited from `InboxEvents` and kept: the *report* names the mechanic and the
## cost of each option, because that is the decision being asked for. The
## *utterance* is what a voli actually said, and it is vaguer, softer and
## shorter. A voli does not know their roommate is costing them 0.11 of a rest
## multiplier; they know the room has been difficult.
##
## ## Indifference, not antagonism
##
## §9's lean, and it governs what may be authored here. A world can be full of
## friction that costs you something without containing anybody who is against
## you — snowfall ruined a harvest, a permit is behind a bridge repair, the hall
## is booked for a wedding. The world has its own business and volleyball is not
## the centre of it, which is a *warmer* fiction than a frictionless one, not a
## colder one. Nothing in this file may have a villain.
const Accommodation := preload("res://scripts/data/accommodation.gd")
const FoodSupply := preload("res://scripts/data/food_supply.gd")

## How loud a thing has to be before somebody mentions it.
##
## Deliberately not zero for any of them. A club where every small fluctuation
## produces a card is a club nobody reads the inbox of, and the whole value of
## the event system is that an arriving card means something.
const CROWDING_MENTIONED: float = 0.5
const PALATE_MENTIONED: float = 0.55
const DISCOMFORT_MENTIONED: float = 0.35
const FATIGUE_MENTIONED: float = 0.45

## What the noticeboard buys, in weeks.
##
## It does not change what happens. It changes **when you are told**, which is
## the event system's whole currency — and it is the only shared installation
## whose effect is entirely about information.
const NOTICEBOARD_LEAD_WEEKS: int = 1


## Every event this club's own state produces this week.
##
## Derived rather than rolled: a card appears because something is true, which is
## what makes the inbox a readout rather than a slot machine. Randomness belongs
## to the world's own business — a harvest, a permit — and those arrive from
## elsewhere.
static func weekly(state: Dictionary) -> Array:
	var out: Array = []
	var small: Array = Array(state.get("small_equipment", []))
	var large: Array = Array(state.get("large_equipment", []))
	var shared: Array = Array(state.get("shared_installations", []))
	var early := shared.has("noticeboard")

	## **The weights, reporting.** The exception §11 allows in the domestic
	## register, and the one that hurts somebody.
	if large.has("free_weights"):
		for voli in Array(state.get("volis", [])):
			if float(voli.get("fatigue", 0.0)) < FATIGUE_MENTIONED:
				continue
			out.append(_event(
				"extra_training", "Care", int(voli.get("id", -1)),
				"%s has been doing extra in the room and their arm is sore."
					% str(voli.get("name", "A voli")),
				"my shoulder's been tight since the weekend",
				[
					{"label": "Rest them a week",
						"cost": "They lose the week's training and keep the arm."},
					{"label": "Take the weights out",
						"cost": "The room stops building and starts recovering."},
					{"label": "Leave it",
						"cost": "It is probably nothing. It is sometimes not."},
				], early,
			))
			break

	## **The console, reporting.** Not a voli — a coach, because the cost is
	## something the voli would not notice about themselves.
	if small.has("console"):
		out.append(_event(
			"room_behind", "Training", -1,
			"Your assistant says the room with the console keeps arriving behind"
				+ " on the week's tactical work.",
			"", [
				{"label": "Swap it for a desk",
					"cost": "Fixes the tactical lag and costs the room its morale."},
				{"label": "Leave it",
					"cost": "They are happy. They are also a week behind."},
			], early,
		))

	## **The crowding trade, reporting** — and early enough to act, which is the
	## §8 requirement that a relationship crash must never be silent.
	if float(state.get("crowding", 0.0)) >= CROWDING_MENTIONED:
		var strained: Array = Array(state.get("strained_pair", []))
		out.append(_event(
			"roommate_strain", "Squad",
			int(strained[0]) if strained.size() > 0 else -1,
			"A room is over capacity and it has started to show between the two"
				+ " volis sharing it.",
			"we're on top of each other in there",
			[
				{"label": "Split them up",
					"cost": "Costs the pair it was building. It was building one."},
				{"label": "Fit a privacy screen",
					"cost": "A floor slot, and it buys back most of the friction."},
				{"label": "Leave it a week",
					"cost": "It may settle. It may be the week it does not."},
			], early,
		))

	## **The supply line, reporting.** The chef's card, and the clearest case of
	## indifference rather than antagonism: nobody did this to you.
	for line in Array(state.get("interrupted_lines", [])):
		out.append(_event(
			"supply_short", "Table", -1,
			"The chef is short this week -- the %s line did not arrive in full."
				% str(line),
			"", [
				{"label": "Cook around it",
					"cost": "Nobody eats badly. Everybody eats the same thing."},
				{"label": "Buy in locally",
					"cost": "Costs money you had not planned to spend."},
			], early,
		))

	## The table itself, in the two ways §17 says it can be wrong.
	for voli in Array(state.get("volis", [])):
		if float(voli.get("palate", 0.0)) >= PALATE_MENTIONED:
			out.append(_event(
				"palate_tired", "Table", int(voli.get("id", -1)),
				"%s has had the same paste for weeks and it has stopped landing."
					% str(voli.get("name", "A voli")),
				"could we have something else for a bit",
				[
					{"label": "Rotate the pastes",
						"cost": "Nothing, if you have another. That is the catch."},
					{"label": "Run a new line",
						"cost": "A weekly outgoing, and a wider table forever."},
				], early,
			))
			break
	for voli in Array(state.get("volis", [])):
		if float(voli.get("discomfort", 0.0)) >= DISCOMFORT_MENTIONED:
			out.append(_event(
				"eating_among_strangers", "Table", int(voli.get("id", -1)),
				"%s is not eating well here -- nothing on the table is food they"
					% str(voli.get("name", "A voli"))
					+ " grew up on.",
				"i miss proper food, honestly",
				[
					{"label": "Fit a cookbook in their room",
						"cost": "A floor slot, and it answers this voli only."},
					{"label": "Run a line to their region",
						"cost": "Answers the whole squad, at a weekly cost."},
					{"label": "Give it time",
						"cost": "Palates widen. Slowly, and not always."},
				], early,
			))
			break

	return out


## One card, in the shape the inbox already reads.
##
## `early` is the noticeboard: the card is identical, it simply arrives a week
## sooner, which is the only thing that installation does and the reason it is
## worth its floor.
static func _event(
	id: String, category: String, speaker_id: int,
	report: String, utterance: String, options: Array, early: bool
) -> Dictionary:
	return {
		"id": id,
		"category": category,
		"speaker_id": speaker_id,
		"report": report,
		"utterance": utterance,
		"options": options,
		"lead_weeks": NOTICEBOARD_LEAD_WEEKS if early else 0,
	}


## The state one week of a club produces, gathered from what already exists.
##
## A gathering function rather than a new store: everything here is read off the
## team, the roster and `FoodSupply`, so the inbox cannot drift out of step with
## what the rest of the game believes.
static func gather(
	team: Resource, players: Array, palate_clock: Dictionary,
	club_region: String, week: int
) -> Dictionary:
	if team == null:
		return {}
	var table: Dictionary = FoodSupply.table(club_region, team.supply_lines, week)
	var volis: Array = []
	for player in players:
		volis.append({
			"id": int(player.id),
			"name": str(player.display_name),
			"fatigue": float(player.fatigue),
			"palate": FoodSupply.palate_of(palate_clock, int(player.id)),
			"discomfort": FoodSupply.discomfort(player.palate_regions, table),
		})
	return {
		"small_equipment": team.housing_small_equipment,
		"large_equipment": team.housing_large_equipment,
		"shared_installations": [],
		"crowding": Accommodation.crowding(
			str(team.housing_structure), int(team.housing_occupants_per_room),
			team.housing_small_equipment, team.housing_large_equipment,
		),
		"interrupted_lines": Array(table.get("lean", [])),
		"volis": volis,
	}
