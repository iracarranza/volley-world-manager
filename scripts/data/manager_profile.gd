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
## ~~**Not a portrait editor.**~~ Retracted; see the section below.
##
## **Not a difficulty selector in a costume.** Every background below is a
## **redistribution** — none is strictly better than another, and each reads as a
## sentence about a person rather than as a modifier.
##
## ## What changed, and why the third bullet above is now wrong
##
## "Not a portrait editor" was true when it was written and is not any more, and
## the reason is the argument it made: a second character pipeline was expensive.
## There is no second pipeline. `PlayerActor3D` draws six body types, five Vegi
## varieties, a colourway table, five coats and nine faces, all of them already
## authored, and every one of those axes was a hash of a player id -- which is
## exactly right for the forty volis the world generates and exactly wrong for
## the one the player *is*. Letting the player name what the hash was already
## choosing costs a dictionary and an option list.
##
## What the original bullet was protecting against still holds: the manager is
## still not a stat block. A body here is **what you look like, not what you are
## good at**. Height, arm length and leg length are drawn and nothing else reads
## them; they do not reach the simulator, because the manager never steps on
## court.
const Regions := preload("res://scripts/data/regions.gd")
const BodyTypes := preload("res://scripts/data/body_type_models.gd")
const Faces := preload("res://scripts/data/face_expressions.gd")

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


## ## The body
##
## The bounds a chosen body has to stay inside, and the defaults it starts at.
##
## Every range here is the range the *rig* already enforces -- `height_cm` is
## clamped to 150-220 in `_apply_physical_profile`, `wingspan_cm` to 150-235,
## `stride_length_m` to 0.55-1.15 -- restated as the slider's ends so the two
## cannot drift apart. A creator offering a value the rig silently clamps is the
## §0 failure mode in its cheapest form: a knob that cannot reach its own stated
## range.
##
## Arm and leg length are offered as **proportions rather than measurements**,
## because that is what the rig actually reads. `arm_length_scale` comes from
## wingspan over height against a reference ratio, and `leg_length_scale` from
## stride against what this height would ordinarily produce -- so a player
## dragging "arm length" is choosing long-armed *for their size*, and their arms
## keep that character when they change their height. Storing centimetres would
## make the two sliders fight.
const HEIGHT_CM := Vector2(150.0, 220.0)
const DEFAULT_HEIGHT_CM: float = 186.0
## Wingspan as a share of height. The rig's own reference is 1.0246 (198/193.3)
## and its scale clamps at 0.78 to 1.24 of that, which is where these ends come
## from rather than from a guess about arms.
const ARM_RATIO := Vector2(0.80, 1.26)
const DEFAULT_ARM_RATIO: float = 1.0246
## Stride as a share of what this height would ordinarily give, which is
## `height_m * 0.43`. The rig clamps the resulting scale to 0.86-1.16.
const LEG_RATIO := Vector2(0.86, 1.16)
const DEFAULT_LEG_RATIO: float = 1.0

const DEFAULT_APPEARANCE := {
	"body_type": "Vegi",
	"produce": "Tomato",
	"palette_index": 0,
	"marking": "none",
	"expression": "neutral",
	"height_cm": DEFAULT_HEIGHT_CM,
	"arm_ratio": DEFAULT_ARM_RATIO,
	"leg_ratio": DEFAULT_LEG_RATIO,
	"hand": "right",
}


## A stored body, bounded and made whole.
##
## Runs on the way in from a save as well as on the way out of the creator, so a
## save written by an older build -- or by a build that offered a produce this
## one has since dropped -- opens as a valid body rather than as a crash or a
## default one. Anything unrecognised falls back to the default *for that axis
## only*, so one stale field does not discard the rest of the face.
static func sanitise_appearance(raw: Dictionary) -> Dictionary:
	var out := DEFAULT_APPEARANCE.duplicate(true)
	var body := str(raw.get("body_type", out.body_type))
	out["body_type"] = body if BodyTypes.is_modelled(body) else BodyTypes.FALLBACK_TYPE
	var produce := str(raw.get("produce", out.produce))
	out["produce"] = produce if produce in BodyTypes.PRODUCE else BodyTypes.PRODUCE[0]
	var key := BodyTypes.palette_key(str(out.body_type), str(out.produce))
	out["palette_index"] = clampi(
		int(raw.get("palette_index", 0)), 0,
		maxi(BodyTypes.palette_count(key) - 1, 0),
	)
	var marking := str(raw.get("marking", out.marking))
	out["marking"] = marking if marking in BodyTypes.marking_options(
		str(out.body_type)
	) else "none"
	var face := str(raw.get("expression", out.expression))
	out["expression"] = face if Faces.has(face) else Faces.NEUTRAL
	out["height_cm"] = clampf(
		float(raw.get("height_cm", DEFAULT_HEIGHT_CM)), HEIGHT_CM.x, HEIGHT_CM.y
	)
	out["arm_ratio"] = clampf(
		float(raw.get("arm_ratio", DEFAULT_ARM_RATIO)), ARM_RATIO.x, ARM_RATIO.y
	)
	out["leg_ratio"] = clampf(
		float(raw.get("leg_ratio", DEFAULT_LEG_RATIO)), LEG_RATIO.x, LEG_RATIO.y
	)
	out["hand"] = "left" if str(raw.get("hand", "right")) == "left" else "right"
	return out


## The same body, in the shape `PlayerActor3D.configure` takes.
##
## The translation from proportions to the measurements the rig reads happens
## here and only here. `wingspan_cm` and `stride_length_m` are *derived* from the
## ratios and the height rather than stored beside them, because storing both
## would mean two facts that can disagree, and the one that would win is
## whichever the rig happened to read first.
static func appearance_profile(appearance: Dictionary) -> Dictionary:
	var body := sanitise_appearance(appearance)
	var height := float(body.height_cm)
	return {
		"body_type": str(body.body_type),
		"height_cm": height,
		"wingspan_cm": height * float(body.arm_ratio),
		## `_apply_physical_profile` compares this against `height_m * 0.43`, so
		## multiplying that same expectation by the ratio is what makes the
		## slider mean "long-legged for your size".
		"stride_length_m": clampf(
			height / 100.0 * 0.43 * float(body.leg_ratio), 0.55, 1.15
		),
		"expression": str(body.expression),
		"appearance": {
			"produce": str(body.produce),
			"palette_index": int(body.palette_index),
			"marking": str(body.marking),
		},
	}


## The hand `PlayerActor3D.configure` takes, which is capitalised where the
## clipboard's is not. Two conventions for one fact, and this is the seam.
static func actor_hand(appearance: Dictionary) -> String:
	return "Left" if str(appearance.get("hand", "right")) == "left" else "Right"
