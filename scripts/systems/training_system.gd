class_name VolleyballTrainingSystem
extends RefCounted

const AttributeProfiles := preload("res://scripts/systems/attribute_profile_system.gd")
const Familiarity := preload("res://scripts/systems/familiarity_system.gd")

const ACTIVITIES := {
	"Team Practice": {"attributes": ["tactical_discipline", "court_vision", "leadership"], "fatigue": 0.05, "satisfaction": 0.01, "familiarity": 0.035, "cohesion": 0.03,
		"description": "Build collective systems, tactical discipline and court vision."},
	"Serving": {"attributes": ["serve_power", "serve_technique", "serve_placement",
		"serve_consistency", "serve_aggression", "serve_variation"], "fatigue": 0.06,
		"satisfaction": 0.0, "familiarity": 0.01, "cohesion": 0.0,
		"description": "Develop serve power, contact, placement, reliability, risk and variation."},
	"Serve Receive": {"attributes": ["reception", "reception_balance", "reception_stability", "dig_control", "work_rate"], "fatigue": 0.055, "satisfaction": 0.005, "familiarity": 0.02, "cohesion": 0.01,
		"description": "Train platform control, movement balance and stability under pace."},
	"Attack & Transition": {"attributes": ["attack_power", "attack_accuracy", "approach_timing", "arm_speed", "tooling", "feinting", "finesse", "shot_variety", "transition_speed", "work_rate"], "fatigue": 0.08, "satisfaction": 0.005, "familiarity": 0.02, "cohesion": 0.005,
		"description": "Improve transition speed, approach timing and terminal attacking."},
	"Blocking & Defense": {"attributes": ["block_timing", "anticipation", "lateral_speed", "dig_control", "work_rate"], "fatigue": 0.07, "satisfaction": 0.0, "familiarity": 0.025, "cohesion": 0.01,
		"description": "Coordinate block reads, lateral closing and floor anticipation."},
	"Strength & Jump": {"attributes": ["explosiveness", "jump_reach", "stamina"], "fatigue": 0.09, "satisfaction": -0.005, "familiarity": 0.0, "cohesion": 0.0,
		"description": "Build explosive capacity and conditioning at a higher fatigue cost."},
	"Recovery": {"attributes": [], "fatigue": -0.20, "satisfaction": 0.03, "familiarity": -0.005, "cohesion": 0.005,
		"description": "Reduce fatigue and restore satisfaction; tactical familiarity may soften slightly."},
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
	var position_progress := 0.0
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
		player.satisfaction = clampf(
			player.satisfaction + float(activity.satisfaction), 0.0, 1.0
		)
		AttributeProfiles.assign_serve_style(player)
		position_progress += Familiarity.train_position(player)
	team.tactical_familiarity = clampf(
		float(team.tactical_familiarity) + float(activity.familiarity), 0.0, 1.0
	)
	team.cohesion = clampf(
		float(team.cohesion) + float(activity.cohesion), 0.0, 1.0
	)
	return {"activity": activity_name, "attribute_improvements": improved,
		"position_familiarity_progress": position_progress,
		"description": activity.description}
