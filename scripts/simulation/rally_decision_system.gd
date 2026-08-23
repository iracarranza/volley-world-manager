class_name RallyDecisionSystem
extends RefCounted


## Shared first-contact action availability. These are the existing reception
## decision thresholds moved to the layer that owns decisions so an overpass
## and a serve receive do not grow separate physical/control bands.
##
## `opportunity` may be an ActionOpportunity or its public dictionary record.
## This returns contact forms, not event labels: an overhead release remains a
## first-team contact unless a later sequence layer honestly classifies it.
static func available_first_contact_actions(
	player: VolleyballPlayer,
	opportunity: Variant,
	confidence: float,
) -> Array[String]:
	var options: Array[String] = []
	var feasibility := float(_opportunity_value(
		opportunity, "physical_feasibility", 0.0
	))
	var reachable := bool(_opportunity_value(opportunity, "reachable", false))
	## Free-flight records contain only reachable opportunities and therefore do
	## not need to repeat that boolean.
	if opportunity is Dictionary and not opportunity.has("reachable"):
		reachable = true
	var balance := float(_opportunity_value(
		opportunity, "arrival_balance", 0.0
	))
	var margin := float(_opportunity_value(
		opportunity, "arrival_margin", -9.0
	))
	if feasibility >= 0.35:
		options.append("emergency_keep_alive")
	if reachable and balance >= 0.38:
		options.append("safe_center_pass")
	if reachable and margin >= 0.12 and balance >= 0.62 \
			and confidence >= 0.60 and player != null \
			and player.ball_control >= 65 and player.decision_making >= 60:
		options.append("quick_release_pass")
	return options


static func _opportunity_value(
	opportunity: Variant, key: String, fallback: Variant
) -> Variant:
	if opportunity is Dictionary:
		return opportunity.get(key, fallback)
	if opportunity != null:
		var value: Variant = opportunity.get(key)
		return fallback if value == null else value
	return fallback


## Selects among currently open perceived receive options, then grades the
## chosen action against authoritative ball truth. This is deterministic and
## returns evidence only; it does not create an official RallyEvent.
static func select_shadow_reception(
	entries: Array[Dictionary],
	true_destination: Vector2,
	true_arrival_time: float,
	preferred_pass_target: Vector2,
) -> RallyDecision:
	var decision := RallyDecision.new()
	decision.decision_type = &"shadow_reception"
	decision.time = _decision_time(entries, true_arrival_time)
	for entry in entries:
		var repeated: Dictionary = entry.get("repeated_read_candidate", {})
		if not _window_open_at(repeated, decision.time):
			continue
		var actions: Array = repeated.get("contact_options", [])
		if actions.is_empty():
			continue
		var quality_range := Vector2(
			repeated.get("expected_quality", Vector2.ZERO)
		)
		var quality_center := (quality_range.x + quality_range.y) * 0.5
		var confidence := float(repeated.get("confidence", 0.0))
		var priority := float(entry.get("tactical_priority", 0.0))
		var margin := float(repeated.get("arrival_margin", -9.0))
		var feasibility := float(repeated.get("physical_feasibility", 0.0))
		var score := quality_center * 0.30 + confidence * 0.22 \
			+ priority * 0.20 + feasibility * 0.16 \
			+ clampf(margin + 0.20, 0.0, 0.70) / 0.70 * 0.12
		decision.options.append({
			"player_id": int(entry.get("player_id", -1)),
			"player_name": str(entry.get("player_name", "Receiver")),
			"score": score,
			"confidence": confidence,
			"tactical_priority": priority,
			"arrival_margin": margin,
			"expected_quality": quality_range,
			"contact_options": actions.duplicate(),
			"perceived_destination": repeated.get(
				"perceived_destination", true_destination
			),
			"destination_error_meters": float(
				repeated.get("destination_error_meters", 0.0)
			),
			"true_reachable": bool(repeated.get("true_reachable", false)),
			"true_arrival_margin": float(
				repeated.get("true_arrival_margin", -9.0)
			),
			"true_arrival_balance": float(
				repeated.get("true_arrival_balance", 0.0)
			),
			"true_physical_feasibility": float(
				repeated.get("true_physical_feasibility", 0.0)
			),
		})
	decision.options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(float(a.score), float(b.score)):
			return int(a.player_id) < int(b.player_id)
		return float(a.score) > float(b.score)
	)
	if decision.options.is_empty():
		decision.reason = "No receive window remained open at the decision time."
		decision.contact_result = {
			"attempted": false, "success": false, "outcome": "no_action"
		}
		return decision

	var selected: Dictionary = decision.options[0]
	decision.selected_player_id = int(selected.player_id)
	var score_gap := 1.0
	if decision.options.size() > 1:
		score_gap = float(selected.score) - float(decision.options[1].score)
	decision.ambiguity = clampf(1.0 - score_gap / 0.16, 0.0, 1.0)
	decision.conflict = decision.options.size() > 1 and score_gap < 0.08 \
		and absf(float(selected.tactical_priority) \
			- float(decision.options[1].tactical_priority)) < 0.18
	decision.selected_action = _choose_contact_action(selected)
	decision.reason = _decision_reason(selected, decision.conflict)
	decision.contact_result = _resolve_contact(
		selected, decision.selected_action, decision.ambiguity,
		true_destination, true_arrival_time, preferred_pass_target,
	)
	return decision


static func _decision_time(entries: Array[Dictionary], fallback: float) -> float:
	var result := -INF
	for entry in entries:
		var repeated: Dictionary = entry.get("repeated_read_candidate", {})
		var moments: Array = repeated.get("moments", [])
		if not moments.is_empty():
			result = maxf(result, float(Dictionary(moments[-1]).get(
				"decision_time", -INF
			)))
	return fallback if not is_finite(result) else result


static func _window_open_at(repeated: Dictionary, at_time: float) -> bool:
	var timeline: Dictionary = repeated.get("opportunity_timeline", {})
	for raw_window in timeline.get("windows", []):
		var window: Dictionary = raw_window
		var opened := float(window.get("opened_at", INF))
		var closed := float(window.get("closed_at", -1.0))
		if opened <= at_time and (closed < 0.0 or at_time < closed - 0.0001):
			return true
	return false


static func _choose_contact_action(option: Dictionary) -> StringName:
	var actions: Array = option.get("contact_options", [])
	if "quick_release_pass" in actions:
		return &"quick_release_pass"
	if "safe_center_pass" in actions:
		return &"safe_center_pass"
	return &"emergency_keep_alive"


static func _decision_reason(option: Dictionary, conflict: bool) -> String:
	return "%s owns the strongest open window%s." % [
		str(option.get("player_name", "Receiver")),
		" despite overlapping teammate responsibility" if conflict else "",
	]


static func _resolve_contact(
	option: Dictionary,
	action: StringName,
	ambiguity: float,
	true_destination: Vector2,
	true_arrival_time: float,
	preferred_pass_target: Vector2,
) -> Dictionary:
	var quality_range := Vector2(option.get("expected_quality", Vector2.ZERO))
	var expected_center := (quality_range.x + quality_range.y) * 0.5
	var true_feasibility := float(option.get("true_physical_feasibility", 0.0))
	var true_balance := float(option.get("true_arrival_balance", 0.0))
	var error_penalty := clampf(
		float(option.get("destination_error_meters", 0.0)) / 1.5, 0.0, 1.0
	)
	var quality := clampf(
		expected_center * 0.44
		+ float(option.get("confidence", 0.0)) * 0.14
		+ true_feasibility * 0.24
		+ true_balance * 0.18
		- error_penalty * 0.20
		- ambiguity * 0.08,
		0.0, 1.0,
	)
	if action == &"quick_release_pass":
		quality = clampf(quality - 0.04, 0.0, 1.0)
	elif action == &"emergency_keep_alive":
		quality = minf(quality, 0.48)
	var success := bool(option.get("true_reachable", false)) and quality >= 0.18
	var outcome := "miss"
	if success:
		outcome = "controlled" if quality >= 0.52 else "kept_alive"
	var outgoing_target := pass_target_for_action(
		preferred_pass_target, action
	)
	return {
		"attempted": true,
		"success": success,
		"outcome": outcome,
		"quality": quality,
		"actor_id": int(option.get("player_id", -1)),
		"action": String(action),
		"available_actions": Array(option.get("contact_options", [])).duplicate(),
		"contact_position": true_destination,
		"contact_time": true_arrival_time,
		"outgoing_target": outgoing_target,
		"true_arrival_margin": float(option.get("true_arrival_margin", -9.0)),
		"perception_error_meters": float(
			option.get("destination_error_meters", 0.0)
		),
	}


## Safety actions add depth to the intended setter path without discarding its
## lateral component. The receiver still passes toward the expected owner.
static func pass_target_for_action(
	preferred_pass_target: Vector2,
	action: StringName,
) -> Vector2:
	if action == &"safe_center_pass":
		return Vector2(
			preferred_pass_target.x, maxf(preferred_pass_target.y, 0.67)
		)
	if action == &"emergency_keep_alive":
		return Vector2(
			preferred_pass_target.x, maxf(preferred_pass_target.y, 0.78)
		)
	return preferred_pass_target
