class_name VolleyballTrainingSystem
extends RefCounted

const ACTIVITIES := {
	"Team Practice": {"attributes": ["tactical_discipline", "court_vision"], "fatigue": 0.05, "morale": 0.01, "familiarity": 0.035,
		"description": "Build collective systems, tactical discipline and court vision."},
	"Serving": {"attributes": ["serve_power", "serve_accuracy"], "fatigue": 0.06, "morale": 0.0, "familiarity": 0.01,
		"description": "Develop serve pressure and placement."},
	"Serve Receive": {"attributes": ["reception", "reception_balance", "reception_stability", "dig_control"], "fatigue": 0.055, "morale": 0.005, "familiarity": 0.02,
		"description": "Train platform control, movement balance and stability under pace."},
	"Attack & Transition": {"attributes": ["attack_power", "attack_accuracy", "approach_timing", "arm_speed", "tooling", "feinting", "finesse", "shot_variety", "transition_speed"], "fatigue": 0.08, "morale": 0.005, "familiarity": 0.02,
		"description": "Improve transition speed, approach timing and terminal attacking."},
	"Blocking & Defense": {"attributes": ["block_timing", "anticipation", "lateral_speed", "dig_control"], "fatigue": 0.07, "morale": 0.0, "familiarity": 0.025,
		"description": "Coordinate block reads, lateral closing and floor anticipation."},
	"Strength & Jump": {"attributes": ["explosiveness", "jump_reach", "stamina"], "fatigue": 0.09, "morale": -0.005, "familiarity": 0.0,
		"description": "Build explosive capacity and conditioning at a higher fatigue cost."},
	"Recovery": {"attributes": [], "fatigue": -0.20, "morale": 0.03, "familiarity": -0.005,
		"description": "Reduce fatigue and restore morale; tactical familiarity may soften slightly."},
}


static func activity_names() -> Array[String]:
	var result: Array[String] = []
	for activity_name in ACTIVITIES:
		result.append(str(activity_name))
	return result


static func description(activity_name: String) -> Dictionary:
	return Dictionary(ACTIVITIES.get(activity_name, ACTIVITIES["Team Practice"]))


static func apply_week(
	activity_name: String,
	players: Array[VolleyballPlayer],
	team: Resource,
) -> Dictionary:
	var activity := description(activity_name)
	var improved := 0
	for player in players:
		if player.availability in ["Injured", "Suspended"]:
			continue
		for attribute_name in activity.attributes:
			var current := int(player.get(str(attribute_name)))
			var ceiling := maxi(player.potential, current)
			if current < ceiling:
				player.set(str(attribute_name), mini(current + 1, ceiling))
				improved += 1
		player.fatigue = clampf(player.fatigue + float(activity.fatigue), 0.0, 1.0)
		player.morale = clampf(player.morale + float(activity.morale), 0.0, 1.0)
	team.tactical_familiarity = clampf(
		float(team.tactical_familiarity) + float(activity.familiarity), 0.0, 1.0
	)
	return {"activity": activity_name, "attribute_improvements": improved,
		"description": activity.description}
