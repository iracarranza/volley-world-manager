class_name AttackRolloutAudit
extends RefCounted


static func evaluate(
	shadow_summary: Dictionary,
	home_lineup: RotationLineup = null,
) -> Dictionary:
	var reasons: Array[String] = []
	var shadow: Dictionary = shadow_summary.get("shadow_attack", {})
	var assignment: Dictionary = shadow.get("selected_assignment", {})
	var response: Dictionary = shadow.get("hitter_response", {})
	var setter_observation: Dictionary = shadow.get("setter_observation", {})
	var hitter_observation: Dictionary = response.get("observation", {})
	var player_id := int(response.get("player_id", -1))
	var perceived_actions: Array = response.get("perceived_actions", [])
	var physical_actions: Array = response.get("physically_executable_actions", [])
	var selected_action := str(response.get("selected_action", ""))
	var set_trajectory: Dictionary = response.get("incoming_set_trajectory", {})
	var attack_trajectory: Dictionary = response.get(
		"outgoing_attack_trajectory", {}
	)

	if not bool(shadow.get("available", false)):
		reasons.append("shadow_attack_unavailable")
	if assignment.is_empty() or player_id != int(assignment.get("player_id", -2)):
		reasons.append("hitter_assignment_mismatch")
	if home_lineup != null and (
			home_lineup.slot_for_player(player_id) < 0 \
			or not home_lineup.is_attack_eligible(player_id)
	):
		reasons.append("hitter_not_legally_eligible")
	if setter_observation.is_empty() or _contains_truth(setter_observation):
		reasons.append("setter_observation_invalid")
	if hitter_observation.is_empty() or _contains_truth(hitter_observation):
		reasons.append("hitter_observation_invalid")
	if bool(response.get("decision_uses_authoritative_truth", true)):
		reasons.append("hitter_decision_uses_truth")
	if not bool(shadow.get("source_state_unchanged", false)):
		reasons.append("source_state_mutated")
	if not bool(response.get("true_reachable", false)):
		reasons.append("attack_contact_unreachable")
	if selected_action.is_empty() or selected_action not in perceived_actions \
			or selected_action not in physical_actions:
		reasons.append("selected_action_not_executable")
	if set_trajectory.is_empty():
		reasons.append("incoming_set_trajectory_missing")
	if attack_trajectory.is_empty():
		reasons.append("outgoing_attack_trajectory_missing")
	var contact_position := Vector2(response.get("contact_position", Vector2.ZERO))
	var contact_time := float(response.get("contact_time", -1.0))
	if not set_trajectory.is_empty():
		if not Vector2(set_trajectory.get(
			"end_position", Vector2.ONE
		)).is_equal_approx(contact_position):
			reasons.append("set_contact_position_mismatch")
		if not is_equal_approx(float(set_trajectory.get(
			"end_time", -2.0
		)), contact_time):
			reasons.append("set_contact_time_mismatch")
	if not attack_trajectory.is_empty():
		if not Vector2(attack_trajectory.get(
			"start_position", Vector2.ONE
		)).is_equal_approx(contact_position):
			reasons.append("attack_origin_mismatch")
		if not is_equal_approx(float(attack_trajectory.get(
			"start_time", -2.0
		)), contact_time):
			reasons.append("attack_start_time_mismatch")

	var candidate := {
		"actor_id": player_id,
		"actor_name": str(response.get("player_name", "Hitter")),
		"assignment": assignment.duplicate(true),
		"selected_action": selected_action,
		"source_position": Vector2(response.get("source_position", contact_position)),
		"center_position": Vector2(response.get(
			"resolved_center_position", contact_position
		)),
		"velocity_mps": Vector2(response.get(
			"resolved_velocity_mps", Vector2.ZERO
		)),
		"contact_position": contact_position,
		"contact_time": contact_time,
		"arrival_margin": float(response.get("true_arrival_margin", -9.0)),
		"arrival_balance": float(response.get("true_arrival_balance", 0.0)),
		"requires_jump": bool(response.get("requires_jump", false)),
		"maximum_contact_height_meters": float(response.get(
			"maximum_contact_height_meters", 0.0
		)),
		"vertical_margin_meters": float(response.get(
			"vertical_margin_meters", 0.0
		)),
		"transition_preparation": Dictionary(response.get(
			"transition_preparation", {}
		)).duplicate(true),
		"perceived_approach": Dictionary(response.get(
			"perceived_approach", {}
		)).duplicate(true),
		"resolved_approach": Dictionary(response.get(
			"resolved_approach", {}
		)).duplicate(true),
		"quality": float(response.get("quality", 0.0)),
		"target": Vector2(response.get("target", Vector2(0.5, 0.2))),
		"direction": str(response.get("direction", "line")),
		"target_reason": str(response.get("target_reason", "perceived gap")),
		"observation_fingerprint": str(response.get(
			"observation_fingerprint", ""
		)),
		"set_trajectory": set_trajectory.duplicate(true),
		"attack_trajectory": attack_trajectory.duplicate(true),
	}
	return {
		"eligible": reasons.is_empty(),
		"failure_reasons": reasons,
		"attack_candidate": candidate,
		"hitter_id": player_id,
		"fingerprint": fingerprint(candidate),
		"observation_boundary_valid": not setter_observation.is_empty() \
			and not hitter_observation.is_empty() \
			and not _contains_truth(setter_observation) \
			and not _contains_truth(hitter_observation) \
			and not bool(response.get("decision_uses_authoritative_truth", true)),
	}


static func fingerprint(candidate: Dictionary) -> String:
	return "%d|%s|%s|%.6f|%s|%s|%s" % [
		int(candidate.get("actor_id", -1)),
		str(candidate.get("selected_action", "")),
		str(candidate.get("contact_position", Vector2.ZERO)),
		float(candidate.get("contact_time", 0.0)),
		str(candidate.get("target", Vector2.ZERO)),
		str(candidate.get("center_position", Vector2.ZERO)),
		str(candidate.get("observation_fingerprint", "")),
	]


static func _contains_truth(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			var normalized := str(key).to_lower()
			if normalized.begins_with("true_") \
					or normalized.begins_with("authoritative_"):
				return true
			if _contains_truth(value[key]):
				return true
	elif value is Array:
		for item in value:
			if _contains_truth(item):
				return true
	return false
