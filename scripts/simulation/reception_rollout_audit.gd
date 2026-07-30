class_name ReceptionRolloutAudit
extends RefCounted

const RallyEventModel := preload("res://scripts/models/rally_event.gd")


static func evaluate(
	shadow_summary: Dictionary,
	home_lineup: RotationLineup = null,
) -> Dictionary:
	var reasons: Array[String] = []
	var playback: Dictionary = shadow_summary.get("shadow_playback_candidate", {})
	var decision: Dictionary = shadow_summary.get("shadow_decision", {})
	var contact: Dictionary = decision.get("contact_result", {})
	var outgoing: Dictionary = shadow_summary.get("outgoing_flight_candidate", {})
	var setter_response: Dictionary = shadow_summary.get("shadow_setter_response", {})
	var events: Array = playback.get("events", [])
	var reception: Dictionary = events[0] if not events.is_empty() else {}
	var metadata: Dictionary = reception.get("metadata", {})
	var trajectory: Dictionary = metadata.get("outgoing_trajectory", {})
	var actor_id := int(reception.get("actor_id", -1))

	if not bool(playback.get("available", false)):
		reasons.append("playback_candidate_unavailable")
	if events.is_empty():
		reasons.append("missing_reception_event")
	if not bool(contact.get("success", false)):
		reasons.append("contact_unsuccessful")
	if actor_id < 0 or actor_id != int(contact.get("actor_id", -2)):
		reasons.append("receiver_identity_mismatch")
	if home_lineup != null and home_lineup.slot_for_player(actor_id) < 0:
		reasons.append("receiver_not_in_lineup")
	if int(reception.get("event_type", -1)) \
			!= RallyEventModel.EventType.RECEPTION:
		reasons.append("wrong_event_type")
	if str(metadata.get("side", "")) != "home":
		reasons.append("wrong_event_side")
	if not bool(reception.get("success", false)):
		reasons.append("adapter_event_unsuccessful")
	var quality := float(reception.get("quality", -1.0))
	if quality < 0.0 or quality > 1.0:
		reasons.append("quality_out_of_bounds")
	if not bool(playback.get("trajectory_contract_valid", false)):
		reasons.append("trajectory_contract_invalid")
	if not bool(outgoing.get("available", false)):
		reasons.append("outgoing_flight_unavailable")
	if not bool(Dictionary(outgoing.get("continuity", {})).get("valid", false)):
		reasons.append("outgoing_flight_discontinuous")
	if bool(playback.get("official_events_mutated", true)):
		reasons.append("official_events_mutated")
	if not bool(setter_response.get("source_state_unchanged", false)):
		reasons.append("source_state_mutated")
	if trajectory.is_empty():
		reasons.append("missing_outgoing_trajectory")
	else:
		var contact_time := float(contact.get("contact_time", -1.0))
		if not is_equal_approx(
			float(metadata.get("event_time", -2.0)), contact_time
		):
			reasons.append("contact_time_mismatch")
		if not is_equal_approx(
			float(trajectory.get("start_time", -3.0)), contact_time
		):
			reasons.append("trajectory_start_time_mismatch")
		if not Vector2(trajectory.get(
			"start_position", Vector2.ZERO
		)).is_equal_approx(Vector2(contact.get(
			"contact_position", Vector2.ONE
		))):
			reasons.append("contact_position_mismatch")

	return {
		"eligible": reasons.is_empty(),
		"failure_reasons": reasons,
		"receiver_id": actor_id,
		"reception_event": reception.duplicate(true),
		"fingerprint": fingerprint(reception),
		"official_events_mutated": bool(playback.get(
			"official_events_mutated", true
		)),
		"source_state_unchanged": bool(setter_response.get(
			"source_state_unchanged", false
		)),
	}


static func fingerprint(reception_event: Dictionary) -> String:
	var metadata: Dictionary = reception_event.get("metadata", {})
	var trajectory: Dictionary = metadata.get("outgoing_trajectory", {})
	return "%d|%.6f|%s|%s|%.6f|%.6f" % [
		int(reception_event.get("actor_id", -1)),
		float(reception_event.get("quality", 0.0)),
		str(trajectory.get("start_position", Vector2.ZERO)),
		str(trajectory.get("end_position", Vector2.ZERO)),
		float(trajectory.get("start_time", 0.0)),
		float(trajectory.get("duration", 0.0)),
	]
