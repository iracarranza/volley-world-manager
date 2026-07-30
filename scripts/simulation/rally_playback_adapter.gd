class_name RallyPlaybackAdapter
extends RefCounted

const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const BallTrajectoryModel := preload("res://scripts/models/ball_trajectory.gd")


## Builds RallyEvent-compatible playback evidence from the shadow pipeline.
## Returned events are detached resources and are never appended to RallyResult.
static func build_shadow_reception_events(
	summary: Dictionary,
	entries: Array,
) -> Dictionary:
	var outgoing: Dictionary = summary.get("outgoing_flight_candidate", {})
	var decision: Dictionary = summary.get("shadow_decision", {})
	var contact: Dictionary = decision.get("contact_result", {})
	var setter_response: Dictionary = summary.get("shadow_setter_response", {})
	if not bool(outgoing.get("available", false)) \
			or not bool(contact.get("success", false)):
		return {"available": false, "events": [], "reason": "no successful pass"}
	var flight: Dictionary = outgoing.get("flight", {})
	var signature: Dictionary = flight.get("signature", {})
	var trajectory := _trajectory_from_flight(flight)
	var receiver_id := int(contact.get("actor_id", -1))
	var receiver_entry := _entry_for(entries, receiver_id)
	var receiver := RallyEventModel.new() as RallyEvent
	receiver.sequence = 0
	receiver.event_type = RallyEventModel.EventType.RECEPTION
	receiver.actor_id = receiver_id
	receiver.actor_name = str(receiver_entry.get("player_name", "Receiver"))
	receiver.start_position = Vector2(flight.get("origin", Vector2.ZERO))
	receiver.end_position = Vector2(flight.get("destination", Vector2.ZERO))
	receiver.success = true
	receiver.quality = clampf(float(contact.get("quality", 0.0)), 0.0, 1.0)
	receiver.headline = "Shadow reception playback candidate"
	receiver.detail = "Developer-only adapter event; official rally is unchanged."
	receiver.metadata = {
		"shadow_only": true,
		"side": "home",
		"movement_start": Vector2(receiver_entry.get(
			"start_position", receiver.start_position
		)),
		"movement_duration": maxf(
			float(contact.get("contact_time", 0.0))
				- float(summary.get("flight_start_time", 0.0)),
			0.0,
		),
		"event_time": float(contact.get("contact_time", 0.0)),
		"contact_height_meters": float(flight.get(
			"contact_height_meters", 1.0
		)),
		"outgoing_trajectory": trajectory.to_dict(),
		"contact_signature": signature.duplicate(true),
	}

	var events: Array[RallyEvent] = [receiver]
	var setter_id := int(setter_response.get("selected_setter_id", -1))
	var setter_candidate := _setter_candidate_for(
		setter_response.get("candidates", []), setter_id
	)
	if setter_id >= 0 and not setter_candidate.is_empty():
		var setter := RallyEventModel.new() as RallyEvent
		setter.sequence = events.size()
		setter.event_type = RallyEventModel.EventType.SET_DECISION
		setter.actor_id = setter_id
		setter.actor_name = str(setter_candidate.get("player_name", "Setter"))
		setter.start_position = Vector2(setter_candidate.get(
			"prepared_position", flight.get("origin", Vector2.ZERO)
		))
		setter.end_position = Vector2(setter_candidate.get(
			"resolved_center_position", setter_candidate.get(
				"final_position", flight.get("destination", Vector2.ZERO)
			)
		))
		setter.success = int(setter_response.get("selected_action_count", 0)) > 0
		setter.quality = clampf(float(setter_response.get(
			"selected_confidence", 0.0
		)), 0.0, 1.0)
		setter.headline = "Shadow setter response"
		setter.detail = "Movement response to the calculated reception flight."
		setter.metadata = {
			"shadow_only": true,
			"side": "home",
			"expected_setter_id": int(setter_response.get(
				"expected_setter_id", -1
			)),
			"actual_setter_id": setter_id,
			"ownership_changed": bool(setter_response.get(
				"ownership_changed", false
			)),
			"handoff_reason": str(setter_response.get(
				"handoff_reason", "not evaluated"
			)),
			"expected_setter_target": setter_response.get(
				"expected_setter_target", Vector2(0.50, 0.60)
			),
			"movement_start": setter.start_position,
			"movement_duration": maxf(
				float(setter_candidate.get("resolved_contact_time", 0.0))
					- float(flight.get("start_time", 0.0)),
				0.0,
			),
			"event_time": float(setter_candidate.get(
				"resolved_contact_time", flight.get("arrival_time", 0.0)
			)),
			"contact_position": Vector2(setter_candidate.get(
				"resolved_contact_position", flight.get("destination", Vector2.ZERO)
			)),
			"contact_height_meters": float(setter_candidate.get(
				"contact_height_meters", flight.get("contact_height_meters", 1.0)
			)),
			"standing_reach_meters": float(setter_candidate.get(
				"standing_reach_meters", 0.0
			)),
			"maximum_contact_height_meters": float(setter_candidate.get(
				"maximum_contact_height_meters", 0.0
			)),
			"requires_jump": bool(setter_candidate.get("requires_jump", false)),
			"incoming_trajectory": trajectory.to_dict(),
			"set_options": Array(setter_response.get(
				"selected_actions", []
			)).duplicate(),
			"observation_only_decision": not bool(setter_candidate.get(
				"decision_uses_authoritative_truth", true
			)),
			"observation_fingerprint": str(setter_candidate.get(
				"observation_fingerprint", ""
			)),
		}
		events.append(setter)

	var event_dicts: Array[Dictionary] = []
	for event in events:
		event_dicts.append(event.to_dict())
	return {
		"available": true,
		"shadow_only": true,
		"events": event_dicts,
		"event_count": event_dicts.size(),
		"trajectory_contract_valid": _trajectory_contract_valid(
			Dictionary(receiver.metadata.outgoing_trajectory), flight
		),
		"official_events_mutated": false,
	}


static func _trajectory_from_flight(flight: Dictionary) -> BallTrajectory:
	var start := Vector2(flight.get("origin", Vector2.ZERO))
	var end := Vector2(flight.get("destination", Vector2.ZERO))
	var signature: Dictionary = flight.get("signature", {})
	var angle := absf(float(signature.get("vertical_angle_degrees", 30.0)))
	var apex := lerpf(1.2, 2.8, clampf(angle / 45.0, 0.0, 1.0))
	var direction := end - start
	var perpendicular := Vector2(-direction.y, direction.x).normalized()
	var sidespin := float(signature.get("sidespin_rps", 0.0))
	var control := start.lerp(end, 0.5) \
		+ perpendicular * clampf(sidespin * 0.006, -0.025, 0.025)
	return BallTrajectoryModel.create(
		"shadow_%s" % str(signature.get("action_type", "pass")),
		start, control, end,
		float(flight.get("start_time", 0.0)),
		float(flight.get("duration", 0.01)), apex, 1.0,
		float(flight.get("contact_height_meters", 1.0)),
	)


static func _trajectory_contract_valid(
	trajectory: Dictionary,
	flight: Dictionary,
) -> bool:
	return Vector2(trajectory.get("start_position", Vector2.ZERO)).is_equal_approx(
		Vector2(flight.get("origin", Vector2.ONE))
	) and Vector2(trajectory.get("end_position", Vector2.ZERO)).is_equal_approx(
		Vector2(flight.get("destination", Vector2.ONE))
	) and is_equal_approx(
		float(trajectory.get("duration", 0.0)),
		float(flight.get("duration", -1.0)),
	) and float(trajectory.get("apex_height_meters", 0.0)) > 0.0


static func _entry_for(entries: Array, player_id: int) -> Dictionary:
	for raw_entry in entries:
		var entry: Dictionary = raw_entry
		if int(entry.get("player_id", -1)) == player_id:
			return entry
	return {}


static func _setter_candidate_for(candidates: Array, player_id: int) -> Dictionary:
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		if int(candidate.get("player_id", -1)) == player_id:
			return candidate
	return {}
