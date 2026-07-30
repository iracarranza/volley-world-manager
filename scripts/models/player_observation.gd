class_name PlayerObservation
extends RefCounted

## A decision-safe view of one rally moment. Authoritative flight and contact
## facts deliberately do not belong here; they remain with the resolver.
var observer_id: int = -1
var side: StringName = &""
var observed_at: float = 0.0
var recognition_time: float = 0.0
var perceived_ball_destination: Vector2 = Vector2.ZERO
var perceived_ball_arrival_time: float = 0.0
var perceived_contact_height_meters: float = 0.0
var confidence: float = 0.0
var responsibility: String = ""
var responsibility_priority: float = 0.0
var perceived_action: StringName = &""
var perceived_reachable: bool = false
var perceived_arrival_margin: float = -INF
var perceived_physical_feasibility: float = 0.0
var perceived_expected_quality: Vector2 = Vector2.ZERO
var perceived_actions: Array[String] = []
var perceived_teammates: Array[Dictionary] = []
var perceived_opponents: Array[Dictionary] = []
var tactical_context: Dictionary = {}
var perceived_target: Vector2 = Vector2.ZERO


static func create_setter_observation(
	player_id: int,
	estimate: BallFlightEstimate,
	opportunity: ActionOpportunity,
	duty: String,
	duty_priority: float,
	actions: Array[String],
) -> PlayerObservation:
	var observation := PlayerObservation.new()
	observation.observer_id = player_id
	observation.side = &"home"
	observation.responsibility = duty
	observation.responsibility_priority = clampf(duty_priority, 0.0, 1.0)
	observation.perceived_action = &"set"
	observation.perceived_actions = actions.duplicate()
	if estimate != null:
		observation.observed_at = estimate.observed_at
		observation.recognition_time = estimate.recognition_time
		observation.perceived_ball_destination = estimate.perceived_destination
		observation.perceived_ball_arrival_time = estimate.perceived_arrival_time
		observation.perceived_contact_height_meters = \
			estimate.perceived_contact_height_meters
		observation.confidence = estimate.confidence
	if opportunity != null:
		observation.perceived_reachable = opportunity.reachable
		observation.perceived_arrival_margin = opportunity.arrival_margin
		observation.perceived_physical_feasibility = opportunity.physical_feasibility
		observation.perceived_expected_quality = opportunity.expected_quality
	return observation


static func create_attack_observation(
	player_id: int,
	estimate: BallFlightEstimate,
	opportunity: ActionOpportunity,
	actions: Array[String],
	opponents: Array[Dictionary],
	target: Vector2,
	context: Dictionary,
) -> PlayerObservation:
	var observation := PlayerObservation.new()
	observation.observer_id = player_id
	observation.side = &"home"
	observation.perceived_action = &"attack"
	observation.perceived_actions = actions.duplicate()
	observation.perceived_opponents = opponents.duplicate(true)
	observation.perceived_target = target
	observation.tactical_context = context.duplicate(true)
	if estimate != null:
		observation.observed_at = estimate.observed_at
		observation.recognition_time = estimate.recognition_time
		observation.perceived_ball_destination = estimate.perceived_destination
		observation.perceived_ball_arrival_time = estimate.perceived_arrival_time
		observation.perceived_contact_height_meters = \
			estimate.perceived_contact_height_meters
		observation.confidence = estimate.confidence
	if opportunity != null:
		observation.perceived_reachable = opportunity.reachable
		observation.perceived_arrival_margin = opportunity.arrival_margin
		observation.perceived_physical_feasibility = opportunity.physical_feasibility
		observation.perceived_expected_quality = opportunity.expected_quality
	return observation


func selection_score() -> float:
	return score_from_dict(to_decision_dict())


static func score_from_dict(observation: Dictionary) -> float:
	var expected_quality := Vector2(observation.get(
		"perceived_expected_quality", Vector2.ZERO
	))
	var quality_center := (
		expected_quality.x + expected_quality.y
	) * 0.5
	var perceived_margin_score := clampf(
		float(observation.get("perceived_arrival_margin", -INF)) + 0.25,
		0.0, 0.75
	) / 0.75
	return quality_center * 0.34 \
		+ float(observation.get("confidence", 0.0)) * 0.22 \
		+ float(observation.get("responsibility_priority", 0.0)) * 0.24 \
		+ perceived_margin_score * 0.20


func to_decision_dict() -> Dictionary:
	return {
		"perceived_expected_quality": perceived_expected_quality,
		"perceived_arrival_margin": perceived_arrival_margin,
		"confidence": confidence,
		"responsibility_priority": responsibility_priority,
	}


func decision_fingerprint() -> String:
	return "%d|%s|%.6f|%.6f|%s|%.6f|%.6f|%.6f|%s|%s|%s|%s" % [
		observer_id,
		str(perceived_ball_destination),
		perceived_ball_arrival_time,
		confidence,
		str(perceived_reachable),
		perceived_arrival_margin,
		perceived_physical_feasibility,
		selection_score(),
		",".join(perceived_actions),
		str(perceived_teammates),
		str(perceived_opponents),
		str(perceived_target),
	]


func to_dict() -> Dictionary:
	return {
		"observer_id": observer_id,
		"side": str(side),
		"observed_at": observed_at,
		"recognition_time": recognition_time,
		"perceived_ball_destination": perceived_ball_destination,
		"perceived_ball_arrival_time": perceived_ball_arrival_time,
		"perceived_contact_height_meters": perceived_contact_height_meters,
		"confidence": confidence,
		"responsibility": responsibility,
		"responsibility_priority": responsibility_priority,
		"perceived_action": str(perceived_action),
		"perceived_reachable": perceived_reachable,
		"perceived_arrival_margin": perceived_arrival_margin,
		"perceived_physical_feasibility": perceived_physical_feasibility,
		"perceived_expected_quality": perceived_expected_quality,
		"perceived_actions": perceived_actions.duplicate(),
		"perceived_teammates": perceived_teammates.duplicate(true),
		"perceived_opponents": perceived_opponents.duplicate(true),
		"tactical_context": tactical_context.duplicate(true),
		"perceived_target": perceived_target,
		"selection_score": selection_score(),
		"decision_fingerprint": decision_fingerprint(),
	}
