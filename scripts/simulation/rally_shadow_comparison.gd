class_name RallyShadowComparison
extends RefCounted

const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const RallyKinematicsModel := preload("res://scripts/simulation/rally_kinematics.gd")


## Compares the completed official first-contact path with detached shadow
## evidence. It reads both and mutates neither.
static func compare_serve_to_set(
	official_events: Array[Resource],
	shadow_summary: Dictionary,
) -> Dictionary:
	var playback: Dictionary = shadow_summary.get("shadow_playback_candidate", {})
	if not bool(playback.get("available", false)):
		return {"available": false, "reason": "no shadow playback path"}
	var official_reception := _official_event(
		official_events, RallyEventModel.EventType.RECEPTION, "home"
	)
	var official_set := _official_event(
		official_events, RallyEventModel.EventType.SET, "home"
	)
	var shadow_events: Array = playback.get("events", [])
	var shadow_reception: Dictionary = shadow_events[0] \
		if not shadow_events.is_empty() else {}
	var setter_response: Dictionary = shadow_summary.get(
		"shadow_setter_response", {}
	)
	var official_pass: Dictionary = official_reception.metadata.get(
		"outgoing_trajectory", {}
	) if official_reception != null else {}
	var shadow_pass: Dictionary = Dictionary(shadow_reception.get(
		"metadata", {}
	)).get("outgoing_trajectory", {})
	var destination_delta := -1.0
	var duration_delta := 0.0
	if not official_pass.is_empty() and not shadow_pass.is_empty():
		destination_delta = RallyKinematicsModel.court_distance_meters(
			Vector2(official_pass.get("end_position", Vector2.ZERO)),
			Vector2(shadow_pass.get("end_position", Vector2.ZERO)),
		)
		duration_delta = float(shadow_pass.get("duration", 0.0)) \
			- float(official_pass.get("duration", 0.0))
	var official_receiver_id := official_reception.actor_id \
		if official_reception != null else -1
	var official_setter_id := official_set.actor_id if official_set != null else -1
	var shadow_receiver_id := int(shadow_reception.get("actor_id", -1))
	var shadow_setter_id := int(setter_response.get("selected_setter_id", -1))
	return {
		"available": true,
		"shadow_only": true,
		"official_path_complete": official_reception != null and official_set != null,
		"official_receiver_id": official_receiver_id,
		"shadow_receiver_id": shadow_receiver_id,
		"receiver_agreement": official_receiver_id == shadow_receiver_id,
		"official_setter_id": official_setter_id,
		"shadow_setter_id": shadow_setter_id,
		"setter_agreement": official_setter_id >= 0 \
			and official_setter_id == shadow_setter_id,
		"pass_destination_delta_meters": destination_delta,
		"pass_duration_delta_seconds": duration_delta,
		"shadow_set_action_count": int(setter_response.get(
			"selected_action_count", 0
		)),
		"official_events_mutated": false,
	}


static func _official_event(
	events: Array[Resource],
	event_type: int,
	side: String,
) -> RallyEvent:
	for raw_event in events:
		var event := raw_event as RallyEvent
		if event != null and int(event.event_type) == event_type \
				and str(event.metadata.get("side", "")) == side:
			return event
	return null
