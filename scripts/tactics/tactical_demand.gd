class_name TacticalDemand
extends RefCounted


static func evaluate(
	player: VolleyballPlayer,
	assignment: HitterAssignment,
	setter: VolleyballPlayer,
) -> Dictionary:
	if player == null or setter == null:
		return {
			"technical": "Unknown", "physical": "Unknown",
			"mental": "Unknown", "synchronization": "Unknown",
			"risk": "Select a valid hitter and setter.",
		}
	var target := CourtConstants.lane_target(assignment.lane)
	var travel := assignment.start_position.distance_to(target)
	var tempo_pressure := float(3 - assignment.tempo) / 3.0
	var horizontal_distance := absf(target.x - CourtConstants.slot_position(
		setter_slot_hint(setter)
	).x)
	var technical_load := tempo_pressure * 0.55 + horizontal_distance * 0.45
	var physical_load := clampf(travel * 1.25, 0.0, 1.0)
	var mental_load := clampf(
		tempo_pressure * 0.45 + (1.0 - float(player.decision_making) / 100.0) * 0.55,
		0.0, 1.0,
	)
	var sync_load := clampf(
		tempo_pressure * 0.60
		+ (1.0 - float(player.approach_timing + setter.set_accuracy) / 200.0) * 0.40,
		0.0, 1.0,
	)
	var risks: Array[String] = []
	if setter.set_accuracy < 65 and technical_load > 0.55:
		risks.append("setter accuracy across distance")
	if player.approach_timing < 65 and assignment.tempo <= 1:
		risks.append("hitter timing at fast tempo")
	if player.transition_speed < 60 and travel > 0.32:
		risks.append("late arrival from the starting position")
	if risks.is_empty():
		risks.append("normal execution variance")
	return {
		"technical": _band(technical_load),
		"physical": _band(physical_load),
		"mental": _band(mental_load),
		"synchronization": _band(sync_load),
		"risk": ", ".join(risks).capitalize(),
	}


static func setter_slot_hint(_setter: VolleyballPlayer) -> int:
	## Demand preview uses the standard target release area. Rally simulation will
	## later use the setter's actual rotation slot and reception endpoint.
	return 2


static func _band(value: float) -> String:
	if value >= 0.72:
		return "High"
	if value >= 0.42:
		return "Moderate"
	return "Low"
