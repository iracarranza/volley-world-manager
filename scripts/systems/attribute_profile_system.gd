class_name VolleyballAttributeProfileSystem
extends RefCounted

const PROFILE_NAMES: Array[String] = [
	"Player Profile", "Attacking", "Defensive", "Setting & Ball Control",
	"Physical", "Serving", "Mental & Tactical",
]

const PROFILE_TOOLTIPS := {
	"Attacking": "Power, tooling, feinting, finesse, approach timing and shot variety.",
	"Defensive": "Reception technique, balance, stability, range, block timing and dig control.",
	"Setting / Control": "Set accuracy, balance, stability, tempo, disguise and hand control.",
	"Physical": "Acceleration, lateral and transition speed, explosiveness, jump capacity and stamina.",
	"Serving": "Power, technique, placement, consistency, aggression and variation.",
	"Mental / Tactical": "Court vision, anticipation, decisions, composure, discipline and improvisation.",
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


static func detailed_profile(player: VolleyballPlayer, profile_name: String) -> Dictionary:
	match profile_name:
		"Defensive":
			return {"Reception Technique": player.reception,
				"Reception Balance": player.reception_balance,
				"Reception Stability": player.reception_stability,
				"Defensive Range": player.baseline_defensive_range(),
				"Block Timing": player.block_timing, "Dig Control": player.dig_control}
		"Setting & Ball Control":
			return {"Set Accuracy": player.set_accuracy, "Set Balance": player.set_balance,
				"Set Stability": player.set_stability, "Tempo Control": player.tempo_control,
				"Set Disguise": player.set_disguise, "Hand Control": player.hand_control}
		"Physical":
			return {"Acceleration": player.acceleration, "Lateral Speed": player.lateral_speed,
				"Transition Speed": player.transition_speed, "Explosiveness": player.explosiveness,
				"Jump Capacity": player.jump_reach, "Stamina": player.stamina}
		"Serving":
			return {"Serve Power": player.serve_power, "Serve Technique": player.serve_technique,
				"Serve Placement": player.serve_placement, "Serve Consistency": player.serve_consistency,
				"Serve Aggression": player.serve_aggression, "Serve Variation": player.serve_variation}
		"Mental & Tactical":
			return {"Court Vision": player.court_vision, "Anticipation": player.anticipation,
				"Decision Making": player.decision_making, "Composure": player.composure,
				"Tactical Discipline": player.tactical_discipline, "Improvisation": player.improvisation}
		_:
			return {"Power": player.usable_attack_power(), "Tooling": player.tooling,
				"Feinting": player.feinting, "Finesse": player.finesse,
				"Approach Timing": player.approach_timing, "Shot Variety": player.shot_variety}


static func summary_profile(player: VolleyballPlayer) -> Dictionary:
	return {
		"Attacking": category_score(detailed_profile(player, "Attacking")),
		"Defensive": category_score(detailed_profile(player, "Defensive")),
		"Setting / Control": category_score(detailed_profile(player, "Setting & Ball Control")),
		"Physical": category_score(detailed_profile(player, "Physical")),
		"Serving": category_score(detailed_profile(player, "Serving")),
		"Mental / Tactical": category_score(detailed_profile(player, "Mental & Tactical")),
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
