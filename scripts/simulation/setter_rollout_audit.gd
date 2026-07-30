class_name SetterRolloutAudit
extends RefCounted


static func evaluate(
	shadow_summary: Dictionary,
	home_lineup: RotationLineup = null,
) -> Dictionary:
	var reasons: Array[String] = []
	var response: Dictionary = shadow_summary.get("shadow_setter_response", {})
	var outgoing: Dictionary = shadow_summary.get("outgoing_flight_candidate", {})
	var flight: Dictionary = outgoing.get("flight", {})
	var setter_id := int(response.get("selected_setter_id", -1))
	var candidate := _candidate_for(
		response.get("candidates", []), setter_id
	)
	var observation: Dictionary = candidate.get("observation", {})
	var perceived_actions: Array = candidate.get("perceived_set_options", [])
	var physical_actions: Array = candidate.get(
		"physically_executable_set_options", []
	)
	var selected_action := _best_common_action(perceived_actions, physical_actions)

	if not bool(response.get("available", false)):
		reasons.append("setter_response_unavailable")
	if setter_id < 0 or candidate.is_empty():
		reasons.append("selected_setter_missing")
	if home_lineup != null and home_lineup.slot_for_player(setter_id) < 0:
		reasons.append("setter_not_in_lineup")
	if observation.is_empty():
		reasons.append("observation_missing")
	elif _contains_authoritative_truth(observation):
		reasons.append("observation_contains_authoritative_truth")
	if bool(candidate.get("decision_uses_authoritative_truth", true)):
		reasons.append("decision_uses_authoritative_truth")
	if not is_equal_approx(
		float(candidate.get("selection_score", -999.0)),
		float(observation.get("selection_score", -998.0))
	):
		reasons.append("selection_score_not_observation_derived")
	if not bool(candidate.get("true_reachable", false)):
		reasons.append("setter_contact_unreachable")
	if physical_actions.is_empty():
		reasons.append("no_physically_executable_action")
	if selected_action.is_empty():
		reasons.append("no_shared_perceived_and_physical_action")
	if not bool(response.get("source_state_unchanged", false)):
		reasons.append("source_state_mutated")
	if not bool(outgoing.get("available", false)) or flight.is_empty():
		reasons.append("incoming_flight_unavailable")

	var contact_position := Vector2(candidate.get(
		"resolved_contact_position", Vector2.ZERO
	))
	var contact_time := float(candidate.get("resolved_contact_time", -1.0))
	var flight_destination := Vector2(flight.get("destination", Vector2.ONE))
	var arrival_time := float(flight.get("arrival_time", -2.0))
	var deadline := float(candidate.get("contact_deadline", -3.0))
	if not contact_position.is_equal_approx(flight_destination):
		reasons.append("contact_position_mismatch")
	if contact_time < arrival_time or contact_time > deadline + 0.0001:
		reasons.append("contact_time_outside_window")

	var selected_candidate := {
		"actor_id": setter_id,
		"actor_name": str(candidate.get("player_name", "Setter")),
		"selected_action": selected_action,
		"contact_position": contact_position,
		"contact_time": contact_time,
		"center_position": Vector2(candidate.get(
			"resolved_center_position", contact_position
		)),
		"movement_start": Vector2(candidate.get(
			"source_position", contact_position
		)),
		"movement_duration": maxf(
			contact_time - float(flight.get("start_time", contact_time)), 0.0
		),
		"velocity_mps": Vector2(candidate.get(
			"resolved_velocity_mps", Vector2.ZERO
		)),
		"arrival_margin": float(candidate.get("true_arrival_margin", -9.0)),
		"arrival_balance": float(candidate.get("true_arrival_balance", 0.0)),
		"contact_height_meters": float(candidate.get(
			"contact_height_meters", flight.get("contact_height_meters", 1.0)
		)),
		"requires_jump": bool(candidate.get("requires_jump", false)),
		"perceived_actions": perceived_actions.duplicate(),
		"physically_executable_actions": physical_actions.duplicate(),
		"observation_fingerprint": str(candidate.get(
			"observation_fingerprint", ""
		)),
		"incoming_flight": flight.duplicate(true),
	}
	return {
		"eligible": reasons.is_empty(),
		"failure_reasons": reasons,
		"setter_id": setter_id,
		"selected_action": selected_action,
		"setter_candidate": selected_candidate,
		"fingerprint": fingerprint(selected_candidate),
		"observation_boundary_valid": not observation.is_empty() \
			and not _contains_authoritative_truth(observation) \
			and not bool(candidate.get("decision_uses_authoritative_truth", true)),
		"source_state_unchanged": bool(response.get(
			"source_state_unchanged", false
		)),
	}


static func fingerprint(candidate: Dictionary) -> String:
	return "%d|%s|%s|%.6f|%s|%s" % [
		int(candidate.get("actor_id", -1)),
		str(candidate.get("selected_action", "")),
		str(candidate.get("contact_position", Vector2.ZERO)),
		float(candidate.get("contact_time", 0.0)),
		str(candidate.get("center_position", Vector2.ZERO)),
		str(candidate.get("observation_fingerprint", "")),
	]


static func _candidate_for(candidates: Array, player_id: int) -> Dictionary:
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		if int(candidate.get("player_id", -1)) == player_id:
			return candidate
	return {}


static func _best_common_action(perceived: Array, physical: Array) -> String:
	for action in [
		"quick_tempo_set", "controlled_set", "jump_set",
		"standing_set", "emergency_bump_set",
	]:
		if action in perceived and action in physical:
			return action
	return ""


static func _contains_authoritative_truth(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			var normalized := str(key).to_lower()
			if normalized.begins_with("true_") \
					or normalized.begins_with("authoritative_"):
				return true
			if _contains_authoritative_truth(value[key]):
				return true
	elif value is Array:
		for item in value:
			if _contains_authoritative_truth(item):
				return true
	return false
