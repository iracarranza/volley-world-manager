class_name VolleyballAttributeProfileSystem
extends RefCounted

const UIPalette := preload("res://scripts/data/ui_palette.gd")

const PROFILE_NAMES: Array[String] = [
	"Player Profile", "Attacking", "Defensive", "Setting & Ball Control",
	"Physical", "Serving", "Mental & Tactical",
]

const PROFILE_TOOLTIPS := {
	"Attacking": "Power, accuracy, tooling, feinting, finesse, approach timing and shot variety.",
	"Defensive": "Reception technique, balance, pace resistance, physical range, touch control, block timing and dig placement.",
	"Setting / Control": "Set accuracy, balance, stability, tempo, disguise, hand control and unpredictability.",
	"Physical": "Acceleration, lateral and transition speed, explosiveness, jump capacity, sustained engine and reach.",
	"Serving": "Power, technique, placement, consistency, aggression, variation and repertoire.",
	"Mental / Tactical": "Court vision, anticipation, decisions, composure, discipline and creativity.",
}

## Player-facing descriptions for every raw ability shown in the roster profile.
## Keeping these beside `CATEGORY_ATTRIBUTES` makes tooltip coverage part of the
## same attribute contract as category membership instead of a screen-local list
## that can silently miss newly-added attributes.
const ATTRIBUTE_TOOLTIPS := {
	"acceleration": "How quickly the player reaches useful movement speed.",
	"lateral_speed": "Maximum side-to-side speed in blocking and floor defense.",
	"transition_speed": "Speed changing phases and moving into an attacking approach.",
	"jump_reach": "Leap capacity used with height and wingspan to determine contact reach.",
	"explosiveness": "How quickly the player can access their available jump and power.",
	"stamina": "Physical capacity to sustain repeated actions through a match.",
	"work_rate": "Willingness to repeatedly spend effort on pursuit, coverage, and transition.",
	"arm_speed": "How quickly the hitting arm reaches contact, especially on fast sets.",
	"serve_power": "The maximum pace the player can put on a serve.",
	"serve_technique": "Contact quality that converts available serve power into usable pace and spin.",
	"serve_placement": "How tightly and specifically the player can define a serve target.",
	"serve_consistency": "Ability to repeat one serve location and change targets without losing control.",
	"serve_aggression": "How readily the player attempts point-ending pace or line pressure instead of a containing serve.",
	"serve_variation": "How often and how credibly the player changes target, depth, pace, and serve shape.",
	"reception": "Platform technique and directional control on serve reception.",
	"reception_balance": "Maintaining reception quality while moving, reaching, or contacting off-center.",
	"reception_stability": "Resistance to platform breakdown against high incoming pace.",
	"set_accuracy": "Delivering the ball to the intended attacking contact window.",
	"set_balance": "Maintaining setting quality while moving or reaching.",
	"set_stability": "Maintaining a clean set against difficult incoming pace and spin.",
	"tempo_control": "Controlling release timing and the hitter's contact rhythm.",
	"set_disguise": "Hiding the intended target and release direction from the block.",
	"hand_control": "Fine manipulation of height, spin, and touch on overhead contacts.",
	"unpredictability": "Varying target and tempo across a match without becoming readable.",
	"attack_power": "Force transferred through the ball at attacking contact.",
	"attack_accuracy": "Precision hitting the intended target while keeping the ball in play.",
	"approach_timing": "Arriving balanced in the hitter's contact window relative to the set.",
	"tooling": "Deliberately using the blocker's hands to score or create a favorable deflection.",
	"feinting": "Selling a full attack before changing to a soft or redirected contact.",
	"finesse": "Technical control of attack placement, depth, angle, and touch.",
	"shot_variety": "Breadth of technically credible attack solutions available at contact.",
	"block_timing": "Matching jump and hand penetration to the attacker's contact.",
	"ball_control": "Cushioning a received or defended ball so it remains playable.",
	"dig_control": "Directing a successful floor-defense contact toward a useful target.",
	"court_vision": "Spatial awareness of teammates, opponents, and open court.",
	"anticipation": "Predicting a specific opponent action before contact.",
	"decision_making": "Choosing the right option under time pressure.",
	"composure": "Maintaining judgment and execution under pressure or after mistakes.",
	"tactical_discipline": "Following assignments and systems instead of abandoning them prematurely.",
	"improvisation": "Creating an effective solution when the planned action breaks down.",
	"adaptability": "Learning unfamiliar roles and adjusting technique to changing situations.",
}

const AXIS_CONTRIBUTORS := {
	"Attacking": "attack_power; mass_kg; explosiveness; transition_speed; arm_speed; approach_timing; attack_accuracy; tooling; feinting; finesse; shot_variety",
	"Defensive": "reception; reception_balance; reception_stability; acceleration; lateral_speed; height_cm; wingspan_cm; stamina; work_rate; ball_control; block_timing; dig_control",
	"Setting / Control": "set_accuracy; set_balance; set_stability; tempo_control; set_disguise; hand_control; unpredictability",
	"Physical": "acceleration; lateral_speed; transition_speed; explosiveness; jump_reach; stamina; work_rate; height_cm; wingspan_cm",
	"Serving": "serve_power; serve_technique; serve_placement; serve_consistency; serve_aggression; serve_variation; serve-style proficiencies",
	"Mental / Tactical": "court_vision; anticipation; decision_making; composure; tactical_discipline; improvisation; adaptability",
	"Overall": "Attacking; Defensive; Setting / Control; Physical; Serving; Mental / Tactical",
	"Power": "attack_power; mass_kg; explosiveness; transition_speed; arm_speed; approach_timing",
	"Accuracy": "attack_accuracy",
	"Tooling": "tooling",
	"Feinting": "feinting",
	"Finesse": "finesse",
	"Approach Timing": "approach_timing",
	"Shot Variety": "shot_variety",
	"Reception Technique": "reception",
	"Reception Balance": "reception_balance",
	"Pace Resistance": "reception_stability",
	"Defensive Range": "acceleration; lateral_speed; height_cm; wingspan_cm; stamina; work_rate",
	"Touch Control": "ball_control",
	"Block Timing": "block_timing",
	"Dig Placement": "dig_control",
	"Set Accuracy": "set_accuracy",
	"Set Balance": "set_balance",
	"Set Stability": "set_stability",
	"Tempo Control": "tempo_control",
	"Set Disguise": "set_disguise",
	"Hand Control": "hand_control",
	"Unpredictability": "unpredictability",
	"Acceleration": "acceleration",
	"Lateral Speed": "lateral_speed",
	"Transition Speed": "transition_speed",
	"Explosiveness": "explosiveness",
	"Jump Capacity": "jump_reach",
	"Engine": "stamina; work_rate",
	"Reach": "height_cm; wingspan_cm",
	"Serve Power": "serve_power",
	"Serve Technique": "serve_technique",
	"Serve Placement": "serve_placement",
	"Serve Consistency": "serve_consistency",
	"Serve Aggression": "serve_aggression",
	"Serve Variation": "serve_variation",
	"Repertoire": "serve_power; serve_technique; serve_placement; serve_consistency; serve_aggression; serve_variation; hand_control; composure; decision_making; explosiveness; arm_speed; stamina; improvisation",
	"Court Vision": "court_vision",
	"Anticipation": "anticipation",
	"Decision Making": "decision_making",
	"Composure": "composure",
	"Tactical Discipline": "tactical_discipline",
	"Creativity": "improvisation; adaptability",
}

## The one place every raw ability attribute is assigned to a category. Every
## screen that needs to group `VolleyballPlayer.ABILITY_ATTRIBUTES` -- the
## wheel's detailed view and the raw attribute-profile text -- reads this
## rather than keeping its own list. Two independent copies used to exist
## (this file's wheel categories and `journal_screen.gd`'s `ATTRIBUTE_GROUPS`)
## with different category names and no attribute-accuracy in either, which is
## exactly the kind of thing that drifts silently: adding an attribute meant
## updating two lists by hand, and nothing enforced that both were updated.
##
## Membership matches the wheel's 6 categories, not a 7th "Reception" bucket:
## reception/reception_balance/reception_stability/ball_control belong to
## Defensive, since a libero's defensive game is one thing on this wheel.
##
## A regression check sums these against `VolleyballPlayer.ABILITY_ATTRIBUTES`
## in both directions, so an attribute added to the player model without being
## placed here fails loudly instead of silently missing from every screen that
## displays a category.
const CATEGORY_ATTRIBUTES := {
	"Attacking": [
		"attack_power", "attack_accuracy", "arm_speed", "approach_timing",
		"tooling", "feinting", "finesse", "shot_variety",
	],
	"Defensive": [
		"reception", "reception_balance", "reception_stability",
		"block_timing", "ball_control", "dig_control",
	],
	"Setting & Ball Control": [
		"set_accuracy", "set_balance", "set_stability", "tempo_control",
		"set_disguise", "hand_control", "unpredictability",
	],
	"Physical": [
		"acceleration", "lateral_speed", "transition_speed", "explosiveness",
		"jump_reach", "stamina", "work_rate",
	],
	"Serving": [
		"serve_power", "serve_technique", "serve_placement",
		"serve_consistency", "serve_aggression", "serve_variation",
	],
	"Mental & Tactical": [
		"court_vision", "anticipation", "decision_making", "composure",
		"tactical_discipline", "improvisation", "adaptability",
	],
}


## How far each axis of an aggregated team profile is pushed away from that
## profile's own mean. A plain average of six starters clusters every axis into
## a narrow band, so a squad with a genuine attacking identity draws almost the
## same hexagon as a balanced one. Multiplying each axis's *deviation from the
## team's own mean* stretches real differences into something readable while
## leaving a genuinely all-round squad round: a lineup whose axes already sit
## close together has small deviations, and a small deviation times 1.6 is
## still small. This exaggerates spread that exists; it never invents spread
## that doesn't -- which a min/max rescale to the full ring would.
const TEAM_WHEEL_AMPLIFICATION: float = 1.6
const GRADE_S_MIN: float = 96.0
const GRADE_A_MIN: float = 89.0
const GRADE_B_PLUS_MIN: float = 82.0
const GRADE_B_MIN: float = 74.0
const GRADE_B_MINUS_MIN: float = 66.0
const GRADE_C_PLUS_MIN: float = 61.0
const GRADE_C_MIN: float = 55.0
const GRADE_C_MINUS_MIN: float = 50.0
## Compatibility alias for callers that inspect the palette. Grade thresholds
## remain simulation-owned; their presentation colors live in UIPalette.
const GRADE_COLORS := UIPalette.GRADE_COLORS


## Shapes a team-level profile -- axis name to lineup-average score -- for the
## wheel, then rebuilds "Overall" from the amplified axes using the same
## `category_score()` weighting `summary_profile()` applies one level down.
## Overall is recomputed rather than averaged across the starters' own Overall
## figures: each of those already folds in a standout-strength bonus and
## weak-spot penalty, so averaging them double-counts both.
static func amplify_team_profile(averages: Dictionary) -> Dictionary:
	if averages.is_empty():
		return {}
	var mean := 0.0
	for axis_name in averages:
		mean += float(averages[axis_name])
	mean /= float(averages.size())
	var amplified := {}
	for axis_name in averages:
		amplified[axis_name] = clampi(roundi(
			mean + (float(averages[axis_name]) - mean) * TEAM_WHEEL_AMPLIFICATION), 1, 100)
	amplified["Overall"] = category_score(amplified)
	return amplified


static func grade(score: float) -> String:
	## These are deliberately nonlinear roster bands. B and C carry subdivisions
	## because most database players live there; S remains a true top-end outlier.
	if score >= GRADE_S_MIN:
		return "S"
	if score >= GRADE_A_MIN:
		return "A"
	if score >= GRADE_B_PLUS_MIN:
		return "B+"
	if score >= GRADE_B_MIN:
		return "B"
	if score >= GRADE_B_MINUS_MIN:
		return "B-"
	if score >= GRADE_C_PLUS_MIN:
		return "C+"
	if score >= GRADE_C_MIN:
		return "C"
	if score >= GRADE_C_MINUS_MIN:
		return "C-"
	return "D"


static func grade_tier(score: float) -> String:
	if score >= GRADE_S_MIN:
		return "S"
	if score >= GRADE_A_MIN:
		return "A"
	if score >= GRADE_B_MINUS_MIN:
		return "B"
	if score >= GRADE_C_MINUS_MIN:
		return "C"
	return "D"


static func grade_color_hex(score: float, light_mode: bool = false) -> String:
	return UIPalette.grade_color_hex(grade_tier(score), light_mode)


static func axis_tooltip(axis_name: String, description: String = "") -> String:
	var contributors := str(AXIS_CONTRIBUTORS.get(axis_name, "Not documented"))
	var result := description.strip_edges()
	if not result.is_empty():
		result += "\n\n"
	return result + "Contributors: %s" % contributors


## One raw attribute or one derived composite, per category. Every category
## targets seven axes so no wheel reads as more or less detailed than any
## other -- Attacking and Mental & Tactical reach it by splitting an averaged
## pair back into two standalone axes (Tooling/Feinting, Court Vision/
## Anticipation: a player can specialize in either half of either pair
## independently, and averaging hid that), while Defensive, Physical and
## Serving reach it by surfacing data that was already tracked per player but
## never shown on any wheel (Ball Control, Reach, Repertoire). Composites that
## remain -- Power, Defensive Range -- combine several inputs into one
## physically-converged output (how hard the ball comes off the hand, how much
## court gets covered) rather than standing in for two alternative skills,
## which is why those stay merged. Setting & Ball Control reaches seven with
## Unpredictability, a genuinely new attribute rather than exposed existing
## data: every other category here reads as mostly physical or technical, and
## setting is arguably the most cognitively demanding position on the floor,
## so its wheel should reflect that. It is deliberately not folded into
## Set Disguise (a single-contact skill masking one release's mechanics):
## Unpredictability is a pattern read over many decisions across a match --
## varying tempo and target selection rather than falling into readable
## habits -- and ages like a Mental & Tactical attribute (grows with
## experience) rather than a technical one.
##
## `use_ceilings` reads this player's generated per-attribute ceilings
## (`VolleyballPlayer.attribute_ceilings`) instead of their current developed
## value, which is what a potential wheel is. It is the same category
## structure either way -- a potential axis is a claim about the same skill,
## not a different one -- so this is one function with a source flag rather
## than a second copy that would drift the moment a category changed. Where a
## player carries no ceiling data (hand-authored fixtures), the ceiling lookup
## falls back to the current value, so their potential wheel is identical to
## their current one rather than failing.
static func detailed_profile(
	player: VolleyballPlayer,
	profile_name: String,
	use_ceilings: bool = false,
) -> Dictionary:
	var source: Dictionary = player.attribute_ceilings if use_ceilings else {}
	var raw := func(attribute_name: String) -> int:
		return int(source.get(attribute_name, player.get(attribute_name)))
	match profile_name:
		"Defensive":
			## Ball Control used to only feed the Defensive Range composite.
			## Turning a hard-driven touch into a playable ball is a hands
			## skill, separate from the physical ability to get to the ball
			## in the first place -- a rangy defender with poor hands and a
			## slower defender with great hands are different players, and
			## blending the two hid that. It gets its own axis instead.
			return {"Reception Technique": raw.call("reception"),
				"Reception Balance": raw.call("reception_balance"),
				"Pace Resistance": raw.call("reception_stability"),
				"Defensive Range": player.baseline_defensive_range(source),
				"Touch Control": raw.call("ball_control"),
				"Block Timing": raw.call("block_timing"),
				"Dig Placement": raw.call("dig_control")}
		"Setting & Ball Control":
			return {"Set Accuracy": raw.call("set_accuracy"),
				"Set Balance": raw.call("set_balance"),
				"Set Stability": raw.call("set_stability"),
				"Tempo Control": raw.call("tempo_control"),
				"Set Disguise": raw.call("set_disguise"),
				"Hand Control": raw.call("hand_control"),
				"Unpredictability": raw.call("unpredictability")}
		"Physical":
			## Reach was never shown on this wheel even though it already
			## feeds Power and Defensive Range as a normalized rating -- a
			## tall, rangy player and a shorter, bouncier one are different
			## physical archetypes this wheel otherwise couldn't distinguish.
			return {"Acceleration": raw.call("acceleration"),
				"Lateral Speed": raw.call("lateral_speed"),
				"Transition Speed": raw.call("transition_speed"),
				"Explosiveness": raw.call("explosiveness"),
				"Jump Capacity": raw.call("jump_reach"),
				"Engine": _weighted(
					[raw.call("stamina"), raw.call("work_rate")], [0.65, 0.35]
				),
				"Reach": player.reach_rating()}
		"Serving":
			## Repertoire was already computed for every player at generation
			## (`serve_style_proficiencies`) and shown nowhere except which
			## single style is "primary" -- a specialist with one lethal serve
			## and an all-rounder competent in all five are different servers
			## the six raw attributes alone can't tell apart.
			var style_scores: Array = serve_style_proficiencies(player, source).values()
			var style_total := 0.0
			for score in style_scores:
				style_total += float(score)
			return {"Serve Power": raw.call("serve_power"),
				"Serve Technique": raw.call("serve_technique"),
				"Serve Placement": raw.call("serve_placement"),
				"Serve Consistency": raw.call("serve_consistency"),
				"Serve Aggression": raw.call("serve_aggression"),
				"Serve Variation": raw.call("serve_variation"),
				"Repertoire": clampi(roundi(style_total / float(style_scores.size())), 1, 100)}
		"Mental & Tactical":
			## Court Vision and Anticipation used to average into one "Reading"
			## axis. Both are game-sense attributes, but not the same skill:
			## court vision is spatial awareness of the whole floor, anticipation
			## is predicting one opponent's next action. A player can read the
			## floor well and still get sold on an attacker's shot, or vice
			## versa -- averaging them hid that a player could specialize in
			## either independently, so each gets its own axis.
			return {"Court Vision": raw.call("court_vision"),
				"Anticipation": raw.call("anticipation"),
				"Decision Making": raw.call("decision_making"),
				"Composure": raw.call("composure"),
				"Tactical Discipline": raw.call("tactical_discipline"),
				"Creativity": _weighted(
					[raw.call("improvisation"), raw.call("adaptability")], [0.50, 0.50]
				)}
		_:
			## "Power" replaces attack_power/arm_speed with the composite that
			## actually reflects usable hitting power -- several physical
			## inputs converging on one measurable output, not two alternative
			## skills, which is why it stays merged. Tooling and Feinting used
			## to average into one "Deception" axis; both are about
			## manipulating what the block reads before contact, but a highly
			## technical hitter can lean on one and rarely use the other --
			## averaging them hid that a player could specialize in either
			## independently, so each is its own axis again. Accuracy is a new
			## axis, not folded into anything -- it did not exist as an
			## attribute when this section was first built and was never added
			## afterward, leaving it invisible despite being a primary
			## attribute for three of the five positions.
			return {"Power": player.usable_attack_power(source),
				"Accuracy": raw.call("attack_accuracy"),
				"Tooling": raw.call("tooling"),
				"Feinting": raw.call("feinting"),
				"Finesse": raw.call("finesse"),
				"Approach Timing": raw.call("approach_timing"),
				"Shot Variety": raw.call("shot_variety")}


## "Overall" is the seventh axis on the Player Profile wheel -- the same
## `category_score` weighting applied one level up, to the six category
## scores instead of six raw axes, rather than a new formula. It has to be
## computed after the other six exist, so this builds them first and folds
## the aggregate in afterward instead of returning one dictionary literal.
static func summary_profile(player: VolleyballPlayer, use_ceilings: bool = false) -> Dictionary:
	var categories := {
		"Attacking": category_score(detailed_profile(player, "Attacking", use_ceilings)),
		"Defensive": category_score(detailed_profile(player, "Defensive", use_ceilings)),
		"Setting / Control": category_score(
			detailed_profile(player, "Setting & Ball Control", use_ceilings)
		),
		"Physical": category_score(detailed_profile(player, "Physical", use_ceilings)),
		"Serving": category_score(detailed_profile(player, "Serving", use_ceilings)),
		"Mental / Tactical": category_score(
			detailed_profile(player, "Mental & Tactical", use_ceilings)
		),
	}
	categories["Overall"] = category_score(categories)
	return categories


## The same six categories are spelled two ways, and this is the bridge.
##
## `CATEGORY_ATTRIBUTES` keys them `"Setting & Ball Control"` and
## `"Mental & Tactical"`; `summary_profile`, the tooltips and the column titles
## use `"Setting / Control"` and `"Mental / Tactical"`. Both spellings are load
## bearing -- the first names a group of attributes, the second is what a reader
## sees -- and nothing had ever needed to cross between them, so nothing did.
##
## `ScoutingSystem.KNOWABILITY` was the first thing that needed to. It keyed its
## category entries off `CATEGORY_ATTRIBUTES` while its only caller passes
## `summary_profile` keys, so "Mental / Tactical" -- the one category
## deliberately made harder to observe -- silently fell through to the default
## and the whole entry did nothing. A gate asserted the *function* ordered its
## channels correctly and passed, because it passed the keys the table used
## rather than the keys the game does.
##
## One function, both directions, so a third spelling cannot appear without
## somebody having to add it here.
const CATEGORY_ALIASES := {
	"Setting / Control": "Setting & Ball Control",
	"Mental / Tactical": "Mental & Tactical",
}


static func canonical_category(name: String) -> String:
	return str(CATEGORY_ALIASES.get(name, name))


## And the display spelling, for anything writing a heading.
static func display_category(name: String) -> String:
	for shown in CATEGORY_ALIASES:
		if str(CATEGORY_ALIASES[shown]) == name:
			return str(shown)
	return name


static func category_score(profile: Dictionary) -> int:
	if profile.is_empty():
		return 0
	var total := 0.0
	var weakest := 100.0
	var strongest := 0.0
	for value in profile.values():
		var score := float(value)
		total += score
		weakest = minf(weakest, score)
		strongest = maxf(strongest, score)
	var average := total / float(profile.size())
	return clampi(roundi(average * 0.70 + strongest * 0.20 + weakest * 0.10), 1, 100)


## `overrides` lets a caller substitute individual attributes -- ceilings, for
## a potential-repertoire reading -- the same way `usable_attack_power` and
## `baseline_defensive_range` do, without a second copy of these weights.
static func serve_style_proficiencies(
	player: VolleyballPlayer, overrides: Dictionary = {},
) -> Dictionary:
	var v := func(attribute_name: String) -> float:
		return float(overrides.get(attribute_name, player.get(attribute_name)))
	return {
		"Standing": _weighted([v.call("serve_technique"), v.call("serve_placement"),
			v.call("serve_consistency"), v.call("composure")], [0.25, 0.25, 0.35, 0.15]),
		"Jump Topspin": _weighted([v.call("serve_power"), v.call("serve_technique"),
			v.call("serve_aggression"), v.call("explosiveness"), v.call("arm_speed"),
			v.call("stamina")], [0.25, 0.25, 0.15, 0.15, 0.10, 0.10]),
		"Jump Float": _weighted([v.call("serve_technique"), v.call("serve_placement"),
			v.call("serve_consistency"), v.call("hand_control"), v.call("composure")],
			[0.30, 0.25, 0.20, 0.10, 0.15]),
		"Hybrid": _weighted([v.call("serve_technique"), v.call("serve_variation"),
			v.call("serve_power"), v.call("serve_placement"), v.call("decision_making"),
			v.call("serve_consistency")], [0.25, 0.25, 0.15, 0.15, 0.10, 0.10]),
		"Sky Ball": _weighted([v.call("serve_technique"), v.call("serve_placement"),
			v.call("serve_variation"), v.call("improvisation"), v.call("serve_aggression")],
			[0.20, 0.20, 0.25, 0.20, 0.15]),
	}


static func assign_serve_style(player: VolleyballPlayer) -> void:
	player.serve_style_proficiencies = serve_style_proficiencies(player)
	var best_style := "Standing"
	var best_score := -1
	for style_name in player.serve_style_proficiencies:
		var score := int(player.serve_style_proficiencies[style_name])
		if score > best_score:
			best_score = score
			best_style = str(style_name)
	player.primary_serve_style = best_style


static func _weighted(values: Array, weights: Array) -> int:
	var total := 0.0
	for index in range(mini(values.size(), weights.size())):
		total += float(values[index]) * float(weights[index])
	return clampi(roundi(total), 1, 100)
