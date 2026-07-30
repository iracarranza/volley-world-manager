class_name ReceptionProgressionCalibration
extends RefCounted

const GameManagerModel := preload("res://scripts/managers/game_manager.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")
const ServeStyleCalibrationModel := preload("res://scripts/simulation/serve_style_calibration.gd")

const READER_TIERS := {
	"weak": 40,
	"average": 65,
	"elite": 90,
}
const FORMATIONS := {
	"standard": {
		1: Vector2(0.80, 0.86), 5: Vector2(0.20, 0.86),
		6: Vector2(0.50, 0.86),
	},
	"compressed_middle": {
		1: Vector2(0.68, 0.84), 5: Vector2(0.32, 0.84),
		6: Vector2(0.50, 0.74),
	},
	"split_deep": {
		1: Vector2(0.86, 0.92), 5: Vector2(0.14, 0.92),
		6: Vector2(0.50, 0.90),
	},
}


## Paired fixtures isolate information attributes and starting formation while
## keeping reception technique, movement, serve proficiency, and seeds fixed.
static func run(samples_per_style: int, start_seed: int) -> Dictionary:
	var safe_samples := maxi(samples_per_style, 1)
	var cells := {}
	var tier_buckets := {}
	var formation_buckets := {}
	var overall := _new_bucket()
	var fixture_errors: Array[String] = []
	var styles_seen := {}
	for tier_name in READER_TIERS:
		cells[tier_name] = {}
		tier_buckets[tier_name] = _new_bucket()
		for formation_name in FORMATIONS:
			var cell := _new_bucket()
			if not formation_buckets.has(formation_name):
				formation_buckets[formation_name] = _new_bucket()
			for serve_style in ServeStyleCalibrationModel.SERVE_STYLES:
				var manager := GameManagerModel.new()
				manager.seed_vertical_slice_data()
				_apply_reader_tier(manager, int(READER_TIERS[tier_name]))
				_apply_formation(manager, formation_name)
				var server := _legal_opponent_server(manager)
				if server == null:
					fixture_errors.append(
						"%s/%s/%s: legal server missing" % [
							tier_name, formation_name, serve_style,
						]
					)
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
					var action_type := str(Dictionary(
						Dictionary(trace.get("summary", {})).get("signature", {})
					).get("action_type", ""))
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
	var weak: Dictionary = tiers.get("weak", {})
	var average: Dictionary = tiers.get("average", {})
	var elite: Dictionary = tiers.get("elite", {})
	var error_monotonic := (
		float(elite.get("destination_error_mean_meters", 99.0))
			< float(average.get("destination_error_mean_meters", 99.0))
		and float(average.get("destination_error_mean_meters", 99.0))
			< float(weak.get("destination_error_mean_meters", 99.0))
	)
	var recognition_monotonic := (
		float(elite.get("recognition_delay_mean_seconds", 99.0))
			< float(average.get("recognition_delay_mean_seconds", 99.0))
		and float(average.get("recognition_delay_mean_seconds", 99.0))
			< float(weak.get("recognition_delay_mean_seconds", 99.0))
	)
	var formation_reachability: Array[float] = []
	for formation_name in formations:
		formation_reachability.append(float(
			formations[formation_name].get("reachable_rate", 0.0)
		))
	formation_reachability.sort()
	var formation_spread := 0.0
	if formation_reachability.size() >= 2:
		formation_spread = formation_reachability[-1] - formation_reachability[0]
	return {
		"gate": "reader_formation_calibration_gate_4",
		"shadow_only": true,
		"fixture": {
			"reader_tiers": READER_TIERS.duplicate(true),
			"formations": FORMATIONS.keys(),
			"serve_styles": ServeStyleCalibrationModel.SERVE_STYLES.duplicate(),
			"samples_per_style": safe_samples,
			"paired_seed_start": start_seed,
			"fixture_errors": fixture_errors,
		},
		"overall": _summarize_bucket(overall),
		"by_reader_tier": tiers,
		"by_formation": formations,
		"matrix": cells,
		"style_coverage_complete": styles_seen.size()
			== ServeStyleCalibrationModel.SERVE_STYLES.size(),
		"reader_progression": {
			"destination_error_monotonic": error_monotonic,
			"recognition_delay_monotonic": recognition_monotonic,
		},
		"formation_reachability_spread": formation_spread,
		"fixture_valid": fixture_errors.is_empty()
			and int(overall.get("invalid", 0)) == 0,
	}


static func _apply_reader_tier(manager: Node, rating: int) -> void:
	var bounded := clampi(rating, 1, 100)
	for player in manager.players:
		player.anticipation = bounded
		player.court_vision = bounded
		player.decision_making = bounded
		player.composure = bounded
		player.fatigue = 0.0
		player.situation_experience.clear()


static func _apply_formation(manager: Node, formation_name: String) -> void:
	var positions: Dictionary = FORMATIONS.get(formation_name, {})
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
		"reachable": 0, "official_agreements": 0,
		"destination_error_total": 0.0,
		"recognition_delay_total": 0.0,
		"confidence_total": 0.0, "novelty_total": 0.0,
	}


static func _add_trace(bucket: Dictionary, trace: Dictionary) -> void:
	bucket["requested"] += 1
	var summary: Dictionary = trace.get("summary", {})
	if trace.is_empty() or not bool(summary.get("available", false)):
		bucket["skipped"] += 1
		return
	var selected := _derived_selected_entry(trace.get("entries", []))
	var derived: Dictionary = selected.get("derived_speed_candidate", {})
	if selected.is_empty() or derived.is_empty():
		bucket["invalid"] += 1
		return
	bucket["available"] += 1
	bucket["reachable"] += 1 if bool(derived.get("reachable", false)) else 0
	bucket["official_agreements"] += 1 if int(selected.get("player_id", -1)) \
		== int(summary.get("legacy_claimant_id", -2)) else 0
	bucket["destination_error_total"] += float(
		derived.get("destination_error_meters", 0.0)
	)
	bucket["recognition_delay_total"] += float(
		derived.get("recognition_time", 0.0)
	) - float(summary.get("flight_start_time", 0.0))
	bucket["confidence_total"] += float(derived.get("confidence", 0.0))
	bucket["novelty_total"] += float(derived.get("novelty", 0.0))


static func _derived_selected_entry(entries: Array) -> Dictionary:
	for raw_entry in entries:
		var entry: Dictionary = raw_entry
		if bool(entry.get("derived_speed_selected", false)):
			return entry
	return {}


static func _summarize_bucket(bucket: Dictionary) -> Dictionary:
	var count := maxf(float(bucket.get("available", 0)), 1.0)
	return {
		"requested": int(bucket.get("requested", 0)),
		"available": int(bucket.get("available", 0)),
		"skipped": int(bucket.get("skipped", 0)),
		"invalid": int(bucket.get("invalid", 0)),
		"reachable_rate": float(bucket.get("reachable", 0)) / count,
		"official_claimant_agreement_rate": float(
			bucket.get("official_agreements", 0)
		) / count,
		"destination_error_mean_meters": float(
			bucket.get("destination_error_total", 0.0)
		) / count,
		"recognition_delay_mean_seconds": float(
			bucket.get("recognition_delay_total", 0.0)
		) / count,
		"confidence_mean": float(bucket.get("confidence_total", 0.0)) / count,
		"novelty_mean": float(bucket.get("novelty_total", 0.0)) / count,
	}
