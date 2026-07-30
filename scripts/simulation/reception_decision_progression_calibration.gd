class_name ReceptionDecisionProgressionCalibration
extends RefCounted

const GameManagerModel := preload("res://scripts/managers/game_manager.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")
const ServeStyleCalibrationModel := preload("res://scripts/simulation/serve_style_calibration.gd")
const ReaderFixtureModel := preload("res://scripts/simulation/reception_progression_calibration.gd")

const PLAYER_TIERS := {
	"developing": 40,
	"established": 65,
	"elite": 90,
}


## Paired fixtures vary the complete reception decision profile while holding
## serve seeds, serve proficiency, formations, fatigue, and player bodies fixed.
static func run(samples_per_style: int, start_seed: int) -> Dictionary:
	var safe_samples := maxi(samples_per_style, 1)
	var tier_buckets := {}
	var formation_buckets := {}
	var cells := {}
	var overall := _new_bucket()
	var fixture_errors: Array[String] = []
	var styles_seen := {}
	for tier_name in PLAYER_TIERS:
		tier_buckets[tier_name] = _new_bucket()
		cells[tier_name] = {}
		for formation_name in ReaderFixtureModel.FORMATIONS:
			var cell := _new_bucket()
			if not formation_buckets.has(formation_name):
				formation_buckets[formation_name] = _new_bucket()
			for serve_style in ServeStyleCalibrationModel.SERVE_STYLES:
				var manager := GameManagerModel.new()
				manager.seed_vertical_slice_data()
				_apply_player_tier(manager, int(PLAYER_TIERS[tier_name]))
				_apply_formation(manager, formation_name)
				var server := _legal_opponent_server(manager)
				if server == null:
					fixture_errors.append("%s/%s/%s: legal server missing" % [
						tier_name, formation_name, serve_style,
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
					_add_trace(cell, trace)
					_add_trace(tier_buckets[tier_name], trace)
					_add_trace(formation_buckets[formation_name], trace)
					_add_trace(overall, trace)
					var action_type := str(Dictionary(Dictionary(
						trace.get("summary", {})
					).get("signature", {})).get("action_type", ""))
					if not action_type.is_empty():
						styles_seen[action_type] = true
			cells[tier_name][formation_name] = _summarize_bucket(cell)

	var tiers := {}
	for tier_name in tier_buckets:
		tiers[tier_name] = _summarize_bucket(tier_buckets[tier_name])
	var formations := {}
	for formation_name in formation_buckets:
		formations[formation_name] = _summarize_bucket(
			formation_buckets[formation_name]
		)
	var developing: Dictionary = tiers.get("developing", {})
	var established: Dictionary = tiers.get("established", {})
	var elite: Dictionary = tiers.get("elite", {})
	return {
		"gate": "reception_decision_progression_gate_10",
		"shadow_only": true,
		"fixture": {
			"player_tiers": PLAYER_TIERS.duplicate(true),
			"formations": ReaderFixtureModel.FORMATIONS.keys(),
			"serve_styles": ServeStyleCalibrationModel.SERVE_STYLES.duplicate(),
			"samples_per_style": safe_samples,
			"paired_seed_start": start_seed,
			"fixture_errors": fixture_errors,
		},
		"overall": _summarize_bucket(overall),
		"by_player_tier": tiers,
		"by_formation": formations,
		"matrix": cells,
		"progression": {
			"decision_rate_monotonic": _strictly_increases(
				developing, established, elite, "decision_rate"
			),
			"contact_success_monotonic": _strictly_increases(
				developing, established, elite, "contact_success_rate"
			),
			"window_duration_monotonic": _strictly_increases(
				developing, established, elite, "open_duration_mean_seconds"
			),
			"contact_choices_monotonic": _strictly_increases(
				developing, established, elite, "contact_choices_mean"
			),
			"elite_quick_release_rate": float(elite.get(
				"quick_release_available_rate", 0.0
			)),
			"developing_quick_release_rate": float(developing.get(
				"quick_release_available_rate", 0.0
			)),
		},
		"style_coverage_complete": styles_seen.size() \
			== ServeStyleCalibrationModel.SERVE_STYLES.size(),
		"fixture_valid": fixture_errors.is_empty() \
			and int(overall.get("invalid", 0)) == 0,
	}


static func _apply_player_tier(manager: Node, rating: int) -> void:
	var bounded := clampi(rating, 1, 100)
	for player in manager.players:
		player.anticipation = bounded
		player.court_vision = bounded
		player.decision_making = bounded
		player.composure = bounded
		player.acceleration = bounded
		player.lateral_speed = bounded
		player.transition_speed = bounded
		player.reception = bounded
		player.ball_control = bounded
		player.reception_balance = bounded
		player.reception_stability = bounded
		player.fatigue = 0.0
		player.situation_experience.clear()


static func _apply_formation(manager: Node, formation_name: String) -> void:
	var positions: Dictionary = ReaderFixtureModel.FORMATIONS.get(
		formation_name, {}
	)
	var lineup: RotationLineup = manager.current_lineup()
	var plan: Resource = manager.current_defensive_plan()
	if lineup == null or plan == null:
		return
	for slot in range(1, 7):
		var player_id := lineup.player_at_slot(slot)
		var zone: Resource = plan.zone_for(
			player_id, DefensiveZoneModel.ZoneType.SERVE_RECEIVE
		)
		if zone == null:
			continue
		zone.enabled = slot in [1, 5, 6]
		zone.center = positions.get(slot, CourtConstants.slot_position(slot))
		zone.radius_meters = 3.2
		zone.priority = 3 if slot == 6 else 2


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
		"windows_opened": 0, "decisions": 0, "contact_successes": 0,
		"quick_release_available": 0, "quick_release_selected": 0,
		"destination_error_total": 0.0, "confidence_total": 0.0,
		"open_duration_total": 0.0, "contact_choices_total": 0.0,
		"contact_quality_total": 0.0, "decision_contact_choices_total": 0.0,
	}


static func _add_trace(bucket: Dictionary, trace: Dictionary) -> void:
	bucket["requested"] += 1
	var summary: Dictionary = trace.get("summary", {})
	if trace.is_empty() or not bool(summary.get("available", false)):
		bucket["skipped"] += 1
		return
	var decision: Dictionary = summary.get("shadow_decision", {})
	var perception: Dictionary = summary.get("perception_candidates", {})
	var repeated: Dictionary = perception.get("repeated_read", {})
	var selected := _selected_repeated_entry(trace.get("entries", []), decision)
	var selected_repeated: Dictionary = selected.get("repeated_read_candidate", {})
	if decision.is_empty() or repeated.is_empty():
		bucket["invalid"] += 1
		return
	bucket["available"] += 1
	bucket["windows_opened"] += 1 \
		if bool(repeated.get("scheduled_ever_reachable", false)) else 0
	bucket["open_duration_total"] += float(
		repeated.get("opportunity_open_duration_seconds", 0.0)
	)
	var decision_made := int(decision.get("selected_player_id", -1)) >= 0
	bucket["decisions"] += 1 if decision_made else 0
	var contact: Dictionary = decision.get("contact_result", {})
	bucket["contact_successes"] += 1 \
		if bool(contact.get("success", false)) else 0
	bucket["contact_quality_total"] += float(contact.get("quality", 0.0))
	var selected_options: Array = selected_repeated.get("contact_options", [])
	bucket["contact_choices_total"] += float(selected_options.size())
	if decision_made:
		bucket["decision_contact_choices_total"] += float(selected_options.size())
	if "quick_release_pass" in selected_options:
		bucket["quick_release_available"] += 1
	if str(decision.get("selected_action", "")) == "quick_release_pass":
		bucket["quick_release_selected"] += 1
	if not selected_repeated.is_empty():
		bucket["destination_error_total"] += float(
			selected_repeated.get("destination_error_meters", 0.0)
		)
		bucket["confidence_total"] += float(
			selected_repeated.get("confidence", 0.0)
		)


static func _selected_repeated_entry(
	entries: Array,
	decision: Dictionary,
) -> Dictionary:
	var selected_id := int(decision.get("selected_player_id", -1))
	if selected_id >= 0:
		for raw_entry in entries:
			var entry: Dictionary = raw_entry
			if int(entry.get("player_id", -2)) == selected_id:
				return entry
	for raw_entry in entries:
		var entry: Dictionary = raw_entry
		if bool(entry.get("repeated_read_selected", false)):
			return entry
	return {}


static func _summarize_bucket(bucket: Dictionary) -> Dictionary:
	var available := maxf(float(bucket.get("available", 0)), 1.0)
	var decisions := maxf(float(bucket.get("decisions", 0)), 1.0)
	return {
		"requested": int(bucket.get("requested", 0)),
		"available": int(bucket.get("available", 0)),
		"skipped": int(bucket.get("skipped", 0)),
		"invalid": int(bucket.get("invalid", 0)),
		"window_open_rate": float(bucket.get("windows_opened", 0)) / available,
		"decision_rate": float(bucket.get("decisions", 0)) / available,
		"contact_success_rate": float(
			bucket.get("contact_successes", 0)
		) / available,
		"contact_success_given_decision_rate": float(
			bucket.get("contact_successes", 0)
		) / decisions,
		"destination_error_mean_meters": float(
			bucket.get("destination_error_total", 0.0)
		) / available,
		"confidence_mean": float(bucket.get("confidence_total", 0.0)) / available,
		"open_duration_mean_seconds": float(
			bucket.get("open_duration_total", 0.0)
		) / available,
		"contact_choices_mean": float(
			bucket.get("contact_choices_total", 0.0)
		) / available,
		"contact_choices_given_decision_mean": float(
			bucket.get("decision_contact_choices_total", 0.0)
		) / decisions,
		"quick_release_available_rate": float(
			bucket.get("quick_release_available", 0)
		) / available,
		"quick_release_selected_rate": float(
			bucket.get("quick_release_selected", 0)
		) / available,
		"contact_quality_mean": float(
			bucket.get("contact_quality_total", 0.0)
		) / available,
	}


static func _strictly_increases(
	low: Dictionary,
	middle: Dictionary,
	high: Dictionary,
	key: String,
) -> bool:
	return float(low.get(key, 0.0)) < float(middle.get(key, 0.0)) \
		and float(middle.get(key, 0.0)) < float(high.get(key, 0.0))
