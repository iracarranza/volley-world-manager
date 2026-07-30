class_name SetterProgressionCalibration
extends RefCounted

const GameManagerModel := preload("res://scripts/managers/game_manager.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")
const ServeStyleCalibrationModel := preload("res://scripts/simulation/serve_style_calibration.gd")

const SETTER_TIERS := {
	"developing": 40,
	"established": 65,
	"elite": 90,
}


## Paired fixtures hold the serve, receiver, pass target, formation, bodies,
## and fatigue fixed. Only attributes used to perceive, reach, and control
## second contact change between tiers.
static func run(samples_per_style: int, start_seed: int) -> Dictionary:
	var safe_samples := maxi(samples_per_style, 1)
	var tier_buckets := {}
	var fixture_errors: Array[String] = []
	var paired_flights := {}
	var paired_flight_mismatches := 0
	for tier_name in SETTER_TIERS:
		var bucket := _new_bucket()
		for serve_style in ServeStyleCalibrationModel.SERVE_STYLES:
			var manager := GameManagerModel.new()
			manager.seed_vertical_slice_data()
			var receiver_id := _configure_fixed_receiver(manager)
			_apply_setter_tier(manager, receiver_id, int(SETTER_TIERS[tier_name]))
			var server := _legal_opponent_server(manager)
			if server == null:
				fixture_errors.append("%s/%s: legal server missing" % [
					tier_name, serve_style,
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
				_add_trace(bucket, trace)
				var pair_key := "%s:%d" % [serve_style, offset]
				var fingerprint := _outgoing_fingerprint(trace)
				if tier_name == "developing":
					paired_flights[pair_key] = fingerprint
				elif paired_flights.has(pair_key) \
						and paired_flights[pair_key] != fingerprint:
					paired_flight_mismatches += 1
		tier_buckets[tier_name] = _summarize_bucket(bucket)
	var developing: Dictionary = tier_buckets.get("developing", {})
	var established: Dictionary = tier_buckets.get("established", {})
	var elite: Dictionary = tier_buckets.get("elite", {})
	return {
		"gate": "setter_progression_calibration_gate_22",
		"shadow_only": true,
		"fixture": {
			"setter_tiers": SETTER_TIERS.duplicate(true),
			"serve_styles": ServeStyleCalibrationModel.SERVE_STYLES.duplicate(),
			"samples_per_style": safe_samples,
			"paired_seed_start": start_seed,
			"fixture_errors": fixture_errors,
			"paired_outgoing_flight_mismatches": paired_flight_mismatches,
		},
		"by_setter_tier": tier_buckets,
		"progression": {
			"confidence_monotonic": _nondecreasing(
				developing, established, elite, "confidence_mean"
			),
			"reachable_rate_monotonic": _nondecreasing(
				developing, established, elite, "reachable_rate"
			),
			"action_count_monotonic": _nondecreasing(
				developing, established, elite, "action_count_mean"
			),
			"controlled_set_rate_monotonic": _nondecreasing(
				developing, established, elite, "controlled_set_rate"
			),
			"quick_tempo_rate_monotonic": _nondecreasing(
				developing, established, elite, "quick_tempo_set_rate"
			),
			"jump_set_rate_monotonic": _nondecreasing(
				developing, established, elite, "jump_set_rate"
			),
			"elite_has_more_options_than_developing": float(elite.get(
				"action_count_mean", 0.0
			)) > float(developing.get("action_count_mean", 0.0)),
		},
		"fixture_valid": fixture_errors.is_empty() \
			and paired_flight_mismatches == 0 \
			and int(developing.get("invalid", 0)) == 0 \
			and int(established.get("invalid", 0)) == 0 \
			and int(elite.get("invalid", 0)) == 0,
	}


static func _configure_fixed_receiver(manager: Node) -> int:
	manager.opponent_team.tendencies["serve_target"] = "Zone 5"
	var lineup: RotationLineup = manager.current_lineup()
	var plan: Resource = manager.current_defensive_plan()
	if lineup == null or plan == null:
		return -1
	var setter_id := lineup.active_setter_id()
	var receiver_id := lineup.player_at_slot(5)
	if receiver_id == setter_id:
		receiver_id = lineup.player_at_slot(6)
	for player in manager.players:
		player.fatigue = 0.0
		player.situation_experience.clear()
		if player.id == receiver_id:
			player.reception = 92
			player.ball_control = 90
			player.reception_balance = 90
			player.reception_stability = 90
			player.anticipation = 82
			player.court_vision = 82
			player.decision_making = 82
			player.composure = 86
			player.acceleration = 82
			player.lateral_speed = 82
			player.transition_speed = 82
	for slot in range(1, 7):
		var player_id := lineup.player_at_slot(slot)
		var zone: Resource = plan.zone_for(
			player_id, DefensiveZoneModel.ZoneType.SERVE_RECEIVE
		)
		if zone != null:
			zone.enabled = player_id == receiver_id
			zone.center = Vector2(0.20, 0.84)
			zone.radius_meters = 6.0
			zone.priority = 3 if player_id == receiver_id else 0
	return receiver_id


static func _apply_setter_tier(
	manager: Node,
	receiver_id: int,
	rating: int,
) -> void:
	var bounded := clampi(rating, 1, 100)
	for player in manager.players:
		if player.id == receiver_id:
			continue
		player.anticipation = bounded
		player.court_vision = bounded
		player.decision_making = bounded
		player.composure = bounded
		player.acceleration = bounded
		player.transition_speed = bounded
		player.jump_reach = bounded
		player.explosiveness = bounded
		player.set_accuracy = bounded
		player.set_balance = bounded
		player.set_stability = bounded
		player.hand_control = bounded
		player.ball_control = bounded
		player.tempo_control = bounded
		player.tactical_discipline = bounded


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
		"reachable": 0, "controlled_sets": 0, "quick_sets": 0,
		"standing_sets": 0, "jump_sets": 0,
		"emergency_sets": 0, "handoffs": 0,
		"confidence_total": 0.0, "action_count_total": 0.0,
		"window_duration_total": 0.0, "arrival_margin_total": 0.0,
	}


static func _add_trace(bucket: Dictionary, trace: Dictionary) -> void:
	bucket["requested"] += 1
	var summary: Dictionary = trace.get("summary", {})
	var response: Dictionary = summary.get("shadow_setter_response", {})
	if not bool(response.get("available", false)):
		bucket["skipped"] += 1
		return
	var actions: Array = response.get("selected_actions", [])
	if int(response.get("selected_setter_id", -1)) < 0 \
			or int(response.get("candidate_count", 0)) <= 0:
		bucket["invalid"] += 1
		return
	bucket["available"] += 1
	bucket["reachable"] += 1 if bool(response.get("selected_reachable", false)) else 0
	bucket["controlled_sets"] += 1 if "controlled_set" in actions else 0
	bucket["quick_sets"] += 1 if "quick_tempo_set" in actions else 0
	bucket["standing_sets"] += 1 if "standing_set" in actions else 0
	bucket["jump_sets"] += 1 if "jump_set" in actions else 0
	bucket["emergency_sets"] += 1 if "emergency_bump_set" in actions else 0
	bucket["handoffs"] += 1 if bool(response.get("ownership_changed", false)) else 0
	bucket["confidence_total"] += float(response.get("selected_confidence", 0.0))
	bucket["action_count_total"] += float(response.get("selected_action_count", 0))
	bucket["window_duration_total"] += float(response.get(
		"selected_window_duration_seconds", 0.0
	))
	bucket["arrival_margin_total"] += float(response.get(
		"selected_true_arrival_margin", -9.0
	))


static func _outgoing_fingerprint(trace: Dictionary) -> String:
	var summary: Dictionary = trace.get("summary", {})
	var outgoing: Dictionary = summary.get("outgoing_flight_candidate", {})
	if not bool(outgoing.get("available", false)):
		return "unavailable"
	var flight: Dictionary = outgoing.get("flight", {})
	return "%s|%s|%.6f|%.6f" % [
		str(flight.get("origin", Vector2.ZERO)),
		str(flight.get("destination", Vector2.ZERO)),
		float(flight.get("start_time", 0.0)),
		float(flight.get("duration", 0.0)),
	]


static func _summarize_bucket(bucket: Dictionary) -> Dictionary:
	var available := maxf(float(bucket.get("available", 0)), 1.0)
	return {
		"requested": int(bucket.get("requested", 0)),
		"available": int(bucket.get("available", 0)),
		"skipped": int(bucket.get("skipped", 0)),
		"invalid": int(bucket.get("invalid", 0)),
		"reachable_rate": float(bucket.get("reachable", 0)) / available,
		"controlled_set_rate": float(bucket.get("controlled_sets", 0)) / available,
		"quick_tempo_set_rate": float(bucket.get("quick_sets", 0)) / available,
		"standing_set_rate": float(bucket.get("standing_sets", 0)) / available,
		"jump_set_rate": float(bucket.get("jump_sets", 0)) / available,
		"emergency_bump_set_rate": float(bucket.get("emergency_sets", 0)) / available,
		"handoff_rate": float(bucket.get("handoffs", 0)) / available,
		"confidence_mean": float(bucket.get("confidence_total", 0.0)) / available,
		"action_count_mean": float(bucket.get("action_count_total", 0.0)) / available,
		"window_duration_mean_seconds": float(bucket.get(
			"window_duration_total", 0.0
		)) / available,
		"arrival_margin_mean_seconds": float(bucket.get(
			"arrival_margin_total", 0.0
		)) / available,
	}


static func _nondecreasing(
	low: Dictionary,
	middle: Dictionary,
	high: Dictionary,
	key: String,
) -> bool:
	return float(low.get(key, 0.0)) <= float(middle.get(key, 0.0)) \
		and float(middle.get(key, 0.0)) <= float(high.get(key, 0.0))
