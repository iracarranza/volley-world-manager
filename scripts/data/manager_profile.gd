class_name ManagerProfile
extends RefCounted

## Who the manager is.
##
## `docs/design/CHARACTER_CREATION.md`. A save began with a career name, a club
## name, a region, a seat and an identity — four of which describe the
## *organisation*. The manager was a text field.
##
## That is a missing addressee rather than a missing feature. Every screen here
## is an object on a desk: a journal somebody keeps, a clipboard somebody
## carries, a board somebody scrawled on minutes before a match. All of them
## imply a somebody, and the interface has been drawing that person's handwriting
## for months without ever saying who they are.
##
## ## Three questions, and none of them is a number
##
## **Not a stat block.** The moment a manager has attributes, decisions are being
## made *by* the numbers rather than by the person reading the screen.
##
## **Not a portrait editor.** The rig draws a *voli's* body; a second character
## pipeline for somebody who never steps on court is the most expensive possible
## way to answer "who am I".
##
## **Not a difficulty selector in a costume.** Every background below is a
## **redistribution** — none is strictly better than another, and each reads as a
## sentence about a person rather than as a modifier.
const Regions := preload("res://scripts/data/regions.gd")

## Every row is a **redistribution**, and that has to survive contact with a
## table. The first version of this had `played` beating `youth` on every column
## at once -- more funds, more standing, a better scout and no offsetting loss --
## which is a difficulty setting wearing a costume, and a gate caught it before
## it shipped.
##
## The fix was not to nerf a number. It was that `youth` was missing the axis it
## is *supposed* to win: the design doc says a youth coach "begins knowing their
## own roster unusually well and the world badly", and neither of those was
## encoded, so the row had upside nowhere.
##
## | background | wins at | pays in |
## |---|---|---|
## | played | one position, read deeply | every other position, read worse |
## | youth | your own squad, from day one | the world outside it, and money |
## | analyst | two readings rather than one confident one | neither of them is sharp |
## | backer | money, and lots of it | nobody has heard of you |
const BACKGROUNDS := {
	"played": {
		"label": "You played",
		## Deep in one place and shallow everywhere else, which is what a playing
		## career actually leaves you with.
		"scout_bonus": 0.0, "scout_count": 1,
		"own_position_confidence": 0.16, "other_position_confidence": -0.07,
		"own_roster_confidence": 0.0, "world_confidence": 0.0,
		"roster_age_bias": 0.0, "starting_funds": 1.0, "starting_reputation": 14,
	},
	"youth": {
		"label": "You coached youth",
		## You have watched these particular volis grow up and you have watched
		## nobody else at all.
		"scout_bonus": -0.10, "scout_count": 1,
		"own_position_confidence": 0.0, "other_position_confidence": 0.0,
		"own_roster_confidence": 0.22, "world_confidence": -0.12,
		"roster_age_bias": -3.0, "starting_funds": 0.9, "starting_reputation": 8,
	},
	"analyst": {
		"label": "You analysed",
		"scout_bonus": -0.12, "scout_count": 2,
		"own_position_confidence": 0.0, "other_position_confidence": 0.0,
		"own_roster_confidence": 0.0, "world_confidence": 0.06,
		"roster_age_bias": 0.0, "starting_funds": 0.95, "starting_reputation": 10,
	},
	"backer": {
		"label": "You paid for it",
		"scout_bonus": 0.0, "scout_count": 1,
		"own_position_confidence": 0.0, "other_position_confidence": 0.0,
		"own_roster_confidence": 0.0, "world_confidence": 0.0,
		"roster_age_bias": -1.0, "starting_funds": 1.6, "starting_reputation": 4,
	},
}

## The axes a background is compared on. Named so a gate can walk them, and so
## adding a fifth background is a decision about what it wins and loses rather
## than a row somebody tuned until it felt fine.
const COMPARED_AXES: Array[String] = [
	"scout_bonus", "scout_count", "own_position_confidence",
	"own_roster_confidence", "world_confidence", "starting_funds",
	"starting_reputation",
]


## Whether `first` beats `second` on every axis at once, which no row may.
static func dominates(first: String, second: String) -> bool:
	var a: Dictionary = BACKGROUNDS.get(first, {})
	var b: Dictionary = BACKGROUNDS.get(second, {})
	if a.is_empty() or b.is_empty():
		return false
	var strictly_better := false
	for axis in COMPARED_AXES:
		if float(a[axis]) < float(b[axis]):
			return false
		if float(a[axis]) > float(b[axis]):
			strictly_better = true
	return strictly_better


## What a manager from your own region reads slightly better.
##
## The one mechanical effect of question 1, and it is the per-region knowledge
## term `SCOUTING.md` already asks for on staff members — which makes the
## manager the *first staff member* rather than a separate concept.
##
## Small on purpose. It is a familiarity, not an advantage: you have watched
## these volis play since you were small, and you still have to sign them.
const HOME_REGION_CONFIDENCE: float = 0.08


static func background_ids() -> Array:
	return BACKGROUNDS.keys()


static func label_for(background: String) -> String:
	return str(Dictionary(BACKGROUNDS.get(background, {})).get("label", background))


## How much better this manager reads a voli from a given region.
##
## Zero for everybody except their own people, and it does not compound with a
## scout's own reading — it is added to confidence, which is already bounded.
static func region_confidence(manager_region: String, voli_region: String) -> float:
	if manager_region.is_empty() or manager_region != voli_region:
		return 0.0
	return HOME_REGION_CONFIDENCE


## A name from the manager's own region's naming tradition.
##
## Offered rather than imposed: the generated name is in the field when you
## arrive and you can type over it. `DEFINITIONS[region].names` already exists,
## so this invents nothing.
static func suggested_name(region: String, seed_value: int) -> String:
	var definition: Dictionary = Regions.definition(region)
	var names: Array = Array(definition.get("names", []))
	if names.is_empty():
		return "Manager"
	return str(names[posmod(seed_value, names.size())])


## The handedness the clipboard mirrors for.
##
## `BACKLOG`'s "Mirror the clipboard for a left-handed manager" has been waiting
## on a manager who has a hand. Not a preference buried in options: a fact about
## the person whose desk this is, chosen where the rest of them is.
const HANDS: Array[String] = ["right", "left"]


static func mirrors_clipboard(hand: String) -> bool:
	return hand == "left"
