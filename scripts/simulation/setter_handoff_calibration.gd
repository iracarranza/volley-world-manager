class_name SetterHandoffCalibration
extends RefCounted

const GameManagerModel := preload("res://scripts/managers/game_manager.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")
const ServeStyleCalibrationModel := preload("res://scripts/simulation/serve_style_calibration.gd")

const FIXTURES: Array[String] = [
	"natural", "forced_setter_first_contact", "forced_late_intended_setter",
]


## Audits the complete second-contact ownership handoff over paired seeds.
## The forced fixture makes the active setter take first contact, so the
## tactical emergency-setter assignment must become the expected owner.
static func run(samples_per_style: int, start_seed: int) -> Dictionary:
	var safe_samples := maxi(samples_per_style, 1)
	var fixture_buckets := {}
	var overall := _new_bucket()
	var fixture_errors: Array[String] = []
	for fixture_name in FIXTURES:
		var bucket := _new_bucket()
		for serve_style in ServeStyleCalibrationModel.SERVE_STYLES:
			var manager := GameManagerModel.new()
			manager.seed_vertical_slice_data()
			_configure_controlled_reception(manager)
			if fixture_name == "forced_setter_first_contact":
				_configure_forced_setter_first_contact(manager)
			elif fixture_name == "forced_late_intended_setter":
				_configure_forced_late_intended_setter(manager)
			var server := _legal_opponent_server(manager)
			if server == null:
				fixture_errors.append("%s/%s: legal server missing" % [
					fixture_name, serve_style,
				])
				continue
			server.primary_serve_style = serve_style
			server.serve_style_proficiencies[serve_style] = \
				ServeStyleCalibrationModel.CONTROLLED_PROFICIENCY
			for offset in range(safe_samples):
				manager.match_state.serving_home = false
				var result: Resource = manager.resolve_active_rally(
					start_seed + offset
				)
				var trace: Dictionary = result.analysis.get(
					"shadow_reception", {}
				) if result != null and result.analysis is Dictionary else {}
				_add_trace(bucket, trace, fixture_name)
				_add_trace(overall, trace, fixture_name)
		fixture_buckets[fixture_name] = _summarize_bucket(bucket)
	var natural: Dictionary = fixture_buckets.get("natural", {})
	var forced: Dictionary = fixture_buckets.get(
		"forced_setter_first_contact", {}
	)
	var forced_late: Dictionary = fixture_buckets.get(
		"forced_late_intended_setter", {}
	)
	return {
		"gate": "setter_handoff_calibration_gate_21",
		"shadow_only": true,
		"fixture": {
			"fixtures": FIXTURES.duplicate(),
			"serve_styles": ServeStyleCalibrationModel.SERVE_STYLES.duplicate(),
			"samples_per_style": safe_samples,
			"paired_seed_start": start_seed,
			"fixture_errors": fixture_errors,
		},
		"overall": _summarize_bucket(overall),
		"by_fixture": fixture_buckets,
		"natural_handoff_rate": float(natural.get("handoff_rate", 0.0)),
		"forced_emergency_intent_rate": float(forced.get(
			"forced_emergency_intent_rate", 0.0
		)),
		"forced_handoff_valid_rate": float(forced.get(
			"handoff_valid_rate", 0.0
		)),
		"forced_late_handoff_rate": float(forced_late.get(
			"handoff_rate", 0.0
		)),
		"forced_late_handoff_valid_rate": float(forced_late.get(
			"handoff_valid_rate", 0.0
		)),
		"fixture_valid": fixture_errors.is_empty() \
			and int(Dictionary(_summarize_bucket(overall)).get("invalid", 0)) == 0,
	}


static func _configure_controlled_reception(manager: Node) -> void:
	manager.opponent_team.tendencies["serve_target"] = "Zone 5"
	for player in manager.players:
		player.reception = 88
		player.ball_control = 86
		player.reception_balance = 86
		player.reception_stability = 86
		player.anticipation = 75
		player.court_vision = 75
		player.decision_making = 75
		player.composure = 80
		player.acceleration = 78
		player.lateral_speed = 78
		player.transition_speed = 78
		player.fatigue = 0.0
		player.situation_experience.clear()


static func _configure_forced_setter_first_contact(manager: Node) -> void:
	var lineup: RotationLineup = manager.current_lineup()
	var plan: Resource = manager.current_defensive_plan()
	if lineup == null or plan == null:
		return
	var setter_id := lineup.active_setter_id()
	var emergency_id := -1
	for slot in [2, 1, 6, 5, 4, 3]:
		var candidate_id := lineup.player_at_slot(slot)
		if candidate_id != setter_id:
			emergency_id = candidate_id
			break
	for slot in range(1, 7):
		var player_id := lineup.player_at_slot(slot)
		var zone: Resource = plan.zone_for(
			player_id, DefensiveZoneModel.ZoneType.SERVE_RECEIVE
		)
		if zone != null:
			zone.enabled = player_id == setter_id
			zone.center = Vector2(0.20, 0.84)
			zone.radius_meters = 6.0
			zone.priority = 3 if player_id == setter_id else 0
		var assignment: Resource = plan.assignment_for(player_id)
		if assignment != null and player_id != setter_id:
			assignment.second_contact_responsibility = \
				"Primary emergency setter" if player_id == emergency_id \
				else "No second-contact duty"
	if emergency_id >= 0:
		plan.set_setter_release_target(emergency_id, Vector2(0.62, 0.64))


static func _configure_forced_late_intended_setter(manager: Node) -> void:
	var lineup: RotationLineup = manager.current_lineup()
	var plan: Resource = manager.current_defensive_plan()
	if lineup == null or plan == null:
		return
	var setter_id := lineup.active_setter_id()
	var receiver_id := lineup.player_at_slot(5)
	if receiver_id == setter_id:
		receiver_id = lineup.player_at_slot(6)
	var alternate_id := -1
	for slot in [2, 1, 6, 5, 4, 3]:
		var candidate_id := lineup.player_at_slot(slot)
		if candidate_id not in [setter_id, receiver_id]:
			alternate_id = candidate_id
			break
	for player in manager.players:
		if player.id == setter_id:
			player.anticipation = 20
			player.court_vision = 20
			player.decision_making = 20
			player.composure = 20
			player.acceleration = 10
			player.transition_speed = 10
			player.set_accuracy = 30
			player.ball_control = 30
			player.tempo_control = 30
		elif player.id == alternate_id:
			player.anticipation = 95
			player.court_vision = 95
			player.decision_making = 95
			player.composure = 95
			player.acceleration = 95
			player.transition_speed = 95
			player.set_accuracy = 95
			player.ball_control = 95
			player.tempo_control = 95
	for slot in range(1, 7):
		var player_id := lineup.player_at_slot(slot)
		var zone: Resource = plan.zone_for(
			player_id, DefensiveZoneModel.ZoneType.SERVE_RECEIVE
		)
		if zone != null:
			zone.enabled = player_id in [receiver_id, alternate_id]
			zone.center = Vector2(0.20, 0.84) if player_id == receiver_id \
				else Vector2(0.86, 0.60)
			zone.radius_meters = 6.0 if player_id == receiver_id else 0.5
			zone.priority = 3 if player_id == receiver_id else 0
		var assignment: Resource = plan.assignment_for(player_id)
		if assignment != null and player_id != setter_id:
			assignment.second_contact_responsibility = \
				"Primary emergency setter" if player_id == alternate_id \
				else "No second-contact duty"
	plan.set_setter_release_target(setter_id, Vector2(0.88, 0.52))


static func _legal_opponent_server(manager: Node) -> VolleyballPlayer:
	var lineup: RotationLineup = manager.opponent_team.current_lineup() \
		if manager != null and manager.opponent_team != null else null
	if lineup == null:
		return null
	return manager.opponent_team.player_by_id(
		lineup.player_at_slot(1)
	) as VolleyballPlayer


static func _new_bucket() -> Dictionary:
	return {
		"requested": 0, "available": 0, "skipped": 0, "invalid": 0,
		"handoffs": 0, "valid_handoffs": 0, "forced_emergency_intents": 0,
		"expected_reachable": 0, "selected_reachable": 0,
		"reasons": {},
	}


static func _add_trace(
	bucket: Dictionary,
	trace: Dictionary,
	fixture_name: String,
) -> void:
	bucket["requested"] += 1
	var summary: Dictionary = trace.get("summary", {})
	var response: Dictionary = summary.get("shadow_setter_response", {})
	if not bool(response.get("available", false)):
		bucket["skipped"] += 1
		return
	bucket["available"] += 1
	var expected_id := int(response.get("expected_setter_id", -1))
	var selected_id := int(response.get("selected_setter_id", -1))
	var first_contact_id := int(response.get("first_contact_player_id", -1))
	var candidates: Array = response.get("candidates", [])
	var expected_candidate := _candidate_for(candidates, expected_id)
	var selected_candidate := _candidate_for(candidates, selected_id)
	var ownership_changed := bool(response.get("ownership_changed", false))
	var reason := str(response.get("handoff_reason", ""))
	var valid := expected_id >= 0 and expected_id != first_contact_id \
		and selected_id >= 0 and not selected_candidate.is_empty() \
		and not reason.is_empty()
	if ownership_changed:
		valid = valid and selected_id != expected_id \
			and (expected_candidate.is_empty() or float(selected_candidate.get(
				"selection_score", -INF
			)) >= float(expected_candidate.get("selection_score", INF)))
		bucket["handoffs"] += 1
		bucket["valid_handoffs"] += 1 if valid else 0
	else:
		valid = valid and selected_id == expected_id
	if fixture_name == "forced_setter_first_contact":
		var preferred_id := int(response.get("preferred_setter_id", -1))
		bucket["forced_emergency_intents"] += 1 \
			if first_contact_id == preferred_id and expected_id != preferred_id else 0
	bucket["expected_reachable"] += 1 if bool(response.get(
		"expected_candidate_reachable", false
	)) else 0
	bucket["selected_reachable"] += 1 if bool(response.get(
		"selected_reachable", false
	)) else 0
	var reasons: Dictionary = bucket.get("reasons", {})
	reasons[reason] = int(reasons.get(reason, 0)) + 1
	bucket["reasons"] = reasons
	if not valid:
		bucket["invalid"] += 1


static func _candidate_for(candidates: Array, player_id: int) -> Dictionary:
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		if int(candidate.get("player_id", -1)) == player_id:
			return candidate
	return {}


static func _summarize_bucket(bucket: Dictionary) -> Dictionary:
	var available := maxf(float(bucket.get("available", 0)), 1.0)
	var handoffs := maxf(float(bucket.get("handoffs", 0)), 1.0)
	return {
		"requested": int(bucket.get("requested", 0)),
		"available": int(bucket.get("available", 0)),
		"skipped": int(bucket.get("skipped", 0)),
		"invalid": int(bucket.get("invalid", 0)),
		"handoff_rate": float(bucket.get("handoffs", 0)) / available,
		"handoff_valid_rate": float(bucket.get("valid_handoffs", 0)) / handoffs,
		"forced_emergency_intent_rate": float(bucket.get(
			"forced_emergency_intents", 0
		)) / available,
		"expected_reachable_rate": float(bucket.get(
			"expected_reachable", 0
		)) / available,
		"selected_reachable_rate": float(bucket.get(
			"selected_reachable", 0
		)) / available,
		"handoff_reasons": Dictionary(bucket.get("reasons", {})).duplicate(true),
	}
