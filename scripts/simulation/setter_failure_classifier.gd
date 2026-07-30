class_name SetterFailureClassifier
extends RefCounted

## Converts second-contact reach evidence into one primary cause and a stable
## set of contributing causes. Classification is diagnostic only.
static func classify(candidate: Dictionary) -> Dictionary:
	if candidate.is_empty():
		return {
			"status": "unavailable",
			"primary_cause": "missing_candidate",
			"contributing_causes": [],
			"reachable": false,
		}
	if bool(candidate.get("true_reachable", false)):
		return {
			"status": "reachable",
			"primary_cause": "none",
			"contributing_causes": [],
			"reachable": true,
		}

	var causes: Array[String] = []
	var perceived_reachable := bool(candidate.get("perceived_reachable", false))
	var vertical_margin := float(candidate.get("vertical_margin_meters", 0.0))
	var contact_height := float(candidate.get("contact_height_meters", 0.0))
	var standing_reach := float(candidate.get("standing_reach_meters", 0.0))
	var required_takeoff := float(candidate.get(
		"required_takeoff_time_seconds", 0.0
	))
	var available_time := float(candidate.get("final_available_time_seconds", 0.0))
	var readiness := float(candidate.get("final_readiness", 1.0))
	var balance := float(candidate.get("final_balance", 1.0))
	var first_delay := float(candidate.get("first_decision_delay_seconds", 0.0))
	var time_after_read := float(candidate.get(
		"time_remaining_after_first_decision_seconds", 0.0
	))
	var center_deficit := float(candidate.get(
		"final_center_distance_deficit_meters", 0.0
	))
	var contact_reach := float(candidate.get("contact_reach_meters", 0.0))
	if perceived_reachable:
		causes.append("perception_error")
	if vertical_margin < -0.001:
		causes.append("vertical_access")
	elif contact_height > standing_reach + 0.001 \
			and required_takeoff > available_time + 0.001:
		causes.append("takeoff_timing")
	if readiness < 0.45 or balance < 0.38:
		causes.append("body_state")
	if first_delay >= 0.22 and first_delay > time_after_read * 0.42:
		causes.append("recognition_delay")
	if center_deficit > 0.001:
		if center_deficit <= maxf(contact_reach * 0.40, 0.16):
			causes.append("horizontal_access")
		else:
			causes.append("insufficient_movement_time")
	if causes.is_empty():
		causes.append("technical_action_unavailable")

	var precedence: Array[String] = [
		"perception_error",
		"vertical_access",
		"takeoff_timing",
		"body_state",
		"recognition_delay",
		"horizontal_access",
		"insufficient_movement_time",
		"technical_action_unavailable",
	]
	var primary := causes[0]
	for cause in precedence:
		if cause in causes:
			primary = cause
			break
	return {
		"status": "failed",
		"primary_cause": primary,
		"contributing_causes": causes,
		"reachable": false,
		"evidence": {
			"first_decision_delay_seconds": first_delay,
			"time_remaining_after_first_decision_seconds": time_after_read,
			"available_time_seconds": available_time,
			"center_distance_deficit_meters": center_deficit,
			"contact_reach_meters": contact_reach,
			"contact_height_meters": contact_height,
			"standing_reach_meters": standing_reach,
			"vertical_margin_meters": vertical_margin,
			"required_takeoff_time_seconds": required_takeoff,
			"readiness": readiness,
			"balance": balance,
		},
	}
