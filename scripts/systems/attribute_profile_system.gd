class_name VolleyballAttributeProfileSystem
extends RefCounted

const PROFILE_NAMES: Array[String] = [
	"Player Profile", "Attacking", "Defensive", "Setting & Ball Control",
	"Physical", "Serving", "Mental & Tactical",
]

const PROFILE_TOOLTIPS := {
	"Attacking": "Power, accuracy, tooling, feinting, finesse, approach timing and shot variety.",
	"Defensive": "Reception technique, balance, stability, range, ball control, block timing and dig control.",
	"Setting / Control": "Set accuracy, balance, stability, tempo, disguise, hand control and unpredictability.",
	"Physical": "Acceleration, lateral and transition speed, explosiveness, jump capacity, stamina and reach.",
	"Serving": "Power, technique, placement, consistency, aggression, variation and repertoire.",
	"Mental / Tactical": "Court vision, anticipation, decision making, composure, discipline, improvisation and adaptability.",
}

## The one place every raw ability attribute is assigned to a category. Every
## screen that needs to group `VolleyballPlayer.ABILITY_ATTRIBUTES` -- the
## wheel's detailed view and the raw attribute-profile text -- reads this
## rather than keeping its own list. Two independent copies used to exist
## (this file's wheel categories and `career_dashboard.gd`'s `ATTRIBUTE_GROUPS`)
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
		"jump_reach", "stamina",
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


static func grade(score: float) -> String:
	if score >= 85.0:
		return "S"
	if score >= 70.0:
		return "A"
	if score >= 55.0:
		return "B"
	if score >= 40.0:
		return "C"
	return "D"


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
				"Reception Stability": raw.call("reception_stability"),
				"Defensive Range": player.baseline_defensive_range(source),
				"Ball Control": raw.call("ball_control"),
				"Block Timing": raw.call("block_timing"),
				"Dig Control": raw.call("dig_control")}
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
				"Jump Capacity": raw.call("jump_reach"), "Stamina": raw.call("stamina"),
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
				"Improvisation": raw.call("improvisation"),
				"Adaptability": raw.call("adaptability")}
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
