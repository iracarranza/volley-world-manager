class_name VolleyballAttributeProfileSystem
extends RefCounted

const PROFILE_NAMES: Array[String] = [
	"Player Profile", "Attacking", "Defensive", "Setting & Ball Control",
	"Physical", "Serving", "Mental & Tactical",
]

const PROFILE_TOOLTIPS := {
	"Attacking": "Power, accuracy, tooling, feinting, finesse, approach timing and shot variety.",
	"Defensive": "Reception technique, balance, stability, range, block timing and dig control.",
	"Setting / Control": "Set accuracy, balance, stability, tempo, disguise and hand control.",
	"Physical": "Acceleration, lateral and transition speed, explosiveness, jump capacity and stamina.",
	"Serving": "Power, technique, placement, consistency, aggression and variation.",
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
		"set_disguise", "hand_control",
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


## One raw attribute or one derived composite, per category. Six axes per
## category is the default, not a rule enforced here: an axis only exists to
## let a player be compared at a glance, and that only works if each axis
## names one independently-variable skill. Attacking and Mental & Tactical
## carry seven because splitting Tooling/Feinting and Court Vision/Anticipation
## back into standalone axes takes priority over a uniform axis count --
## averaging either pair hides a real specialization choice (a player can be
## a highly technical hitter who tools well but rarely feints, or vice versa;
## the same holds for reading the whole floor versus predicting one attacker's
## next swing). Composites that remain -- Power, Defensive Range -- combine
## several inputs into one physically-converged output (how hard the ball
## comes off the hand, how much court gets covered and kept in play) rather
## than standing in for two alternative skills, which is why those stay merged.
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
			return {"Reception Technique": raw.call("reception"),
				"Reception Balance": raw.call("reception_balance"),
				"Reception Stability": raw.call("reception_stability"),
				"Defensive Range": player.baseline_defensive_range(source),
				"Block Timing": raw.call("block_timing"),
				"Dig Control": raw.call("dig_control")}
		"Setting & Ball Control":
			return {"Set Accuracy": raw.call("set_accuracy"),
				"Set Balance": raw.call("set_balance"),
				"Set Stability": raw.call("set_stability"),
				"Tempo Control": raw.call("tempo_control"),
				"Set Disguise": raw.call("set_disguise"),
				"Hand Control": raw.call("hand_control")}
		"Physical":
			return {"Acceleration": raw.call("acceleration"),
				"Lateral Speed": raw.call("lateral_speed"),
				"Transition Speed": raw.call("transition_speed"),
				"Explosiveness": raw.call("explosiveness"),
				"Jump Capacity": raw.call("jump_reach"), "Stamina": raw.call("stamina")}
		"Serving":
			return {"Serve Power": raw.call("serve_power"),
				"Serve Technique": raw.call("serve_technique"),
				"Serve Placement": raw.call("serve_placement"),
				"Serve Consistency": raw.call("serve_consistency"),
				"Serve Aggression": raw.call("serve_aggression"),
				"Serve Variation": raw.call("serve_variation")}
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


static func summary_profile(player: VolleyballPlayer, use_ceilings: bool = false) -> Dictionary:
	return {
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


static func serve_style_proficiencies(player: VolleyballPlayer) -> Dictionary:
	return {
		"Standing": _weighted([player.serve_technique, player.serve_placement,
			player.serve_consistency, player.composure], [0.25, 0.25, 0.35, 0.15]),
		"Jump Topspin": _weighted([player.serve_power, player.serve_technique,
			player.serve_aggression, player.explosiveness, player.arm_speed, player.stamina],
			[0.25, 0.25, 0.15, 0.15, 0.10, 0.10]),
		"Jump Float": _weighted([player.serve_technique, player.serve_placement,
			player.serve_consistency, player.hand_control, player.composure],
			[0.30, 0.25, 0.20, 0.10, 0.15]),
		"Hybrid": _weighted([player.serve_technique, player.serve_variation,
			player.serve_power, player.serve_placement, player.decision_making,
			player.serve_consistency], [0.25, 0.25, 0.15, 0.15, 0.10, 0.10]),
		"Sky Ball": _weighted([player.serve_technique, player.serve_placement,
			player.serve_variation, player.improvisation, player.serve_aggression],
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
