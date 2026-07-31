class_name BlockerProgressionCalibration
extends RefCounted

## Gate 44 calibration: paired multi-seed evidence that a stronger reader
## recognizes cues earlier and more accurately than a developing reader,
## without ever gaining unexplained movement speed. Every sample in every
## tier reuses the exact same seed and the exact same movement attributes
## (lateral_speed, acceleration, mass_kg); only the reading attributes
## (anticipation, court_vision, decision_making, tactical_discipline,
## composure) differ between tiers. If reach or timing still moved with
## the tier, it would prove movement leaked into what should be a purely
## perceptual advantage.

const GameManagerModel := preload("res://scripts/managers/game_manager.gd")
const RallyStateBuilderModel := preload(
	"res://scripts/simulation/rally_state_builder.gd"
)
const ShadowAttackSystemModel := preload(
	"res://scripts/simulation/shadow_attack_system.gd"
)
const ShadowBlockSystemModel := preload(
	"res://scripts/simulation/shadow_block_system.gd"
)

const TIERS := {
	"developing": 30,
	"established": 60,
	"elite": 92,
}

## Held fixed across every tier so a reach or speed difference can only come
## from the read, never from an unrelated physical advantage.
const FIXED_MOVEMENT_RATING: int = 55


static func run(sample_count: int, start_seed: int) -> Dictionary:
	var safe_samples := maxi(sample_count, 1)
	var by_tier := {}
	for tier_name in TIERS:
		var bucket := _new_bucket()
		for offset in range(safe_samples):
			var manager := GameManagerModel.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = false
			_apply_tier(manager, int(TIERS[tier_name]))
			var lineup: RotationLineup = manager.current_lineup()
			var setter_id := lineup.active_setter_id()
			var seed_value := start_seed + offset
			var state := RallyStateBuilderModel.build(
				manager.players, lineup, manager.current_defensive_plan(),
				manager.opponent_team, manager.called_play(), false, seed_value,
			)
			var response := {
				"selected_setter_id": setter_id,
				"candidates": [{
					"player_id": setter_id,
					"resolved_contact_position": Vector2(0.50, 0.60),
					"resolved_contact_time": 1.0,
				}],
			}
			var shadow_attack := ShadowAttackSystemModel.evaluate(
				state, response, -1, seed_value + 370000,
			)
			var shadow_block := ShadowBlockSystemModel.evaluate(
				state, shadow_attack, seed_value + 1900007,
			)
			_add(bucket, shadow_block)
		by_tier[tier_name] = _summarize(bucket)
	var developing: Dictionary = by_tier.get("developing", {})
	var established: Dictionary = by_tier.get("established", {})
	var elite: Dictionary = by_tier.get("elite", {})
	return {
		"gate": "block_observation_progression_gate_44",
		"shadow_only": true,
		"sample_count_per_tier": safe_samples,
		"start_seed": start_seed,
		"by_tier": by_tier,
		"progression": {
			"confidence_monotonic": _nondecreasing(
				developing, established, elite, "confidence_late_mean"
			),
			## Recognition delay is measured from when the set leaves the
			## setter's hands, independent of which sample was taken -- lower
			## is earlier. A stronger reader must recognize no later.
			"earlier_recognition_monotonic": _nonincreasing(
				developing, established, elite, "recognition_delay_mean"
			),
			## Held fixed by _apply_tier; any drift here would mean reading
			## attributes are leaking into movement capability.
			"movement_speed_tier_independent": _within_tolerance(
				developing, established, elite, "maximum_speed_mps_mean", 0.001
			),
		},
		"fixture_valid": int(developing.get("invalid", 1)) == 0 \
			and int(established.get("invalid", 1)) == 0 \
			and int(elite.get("invalid", 1)) == 0,
	}


static func _apply_tier(manager: Node, rating: int) -> void:
	var bounded := clampi(rating, 1, 100)
	var opponent_team: Resource = manager.opponent_team
	if opponent_team == null:
		return
	for raw_player in opponent_team.players:
		var player: VolleyballPlayer = raw_player
		if player == null:
			continue
		player.anticipation = bounded
		player.court_vision = bounded
		player.decision_making = bounded
		player.tactical_discipline = bounded
		player.composure = bounded
		## Held fixed intentionally -- see FIXED_MOVEMENT_RATING.
		player.lateral_speed = FIXED_MOVEMENT_RATING
		player.acceleration = FIXED_MOVEMENT_RATING
		player.transition_speed = FIXED_MOVEMENT_RATING


static func _new_bucket() -> Dictionary:
	return {
		"requested": 0, "available": 0, "invalid": 0,
		"confidence_late_total": 0.0, "recognition_delay_total": 0.0,
		"maximum_speed_total": 0.0, "blocker_samples": 0,
	}


static func _add(bucket: Dictionary, shadow_block: Dictionary) -> void:
	bucket["requested"] += 1
	if not bool(shadow_block.get("available", false)):
		bucket["invalid"] += 1
		return
	var blockers: Array = shadow_block.get("blockers", [])
	if blockers.is_empty():
		bucket["invalid"] += 1
		return
	bucket["available"] += 1
	for raw_blocker in blockers:
		var blocker: Dictionary = raw_blocker
		var observation: Dictionary = blocker.get("observation", {})
		bucket["confidence_late_total"] += float(observation.get("confidence_late", 0.0))
		bucket["recognition_delay_total"] += float(observation.get(
			"recognition_delay_seconds", 0.0
		))
		bucket["maximum_speed_total"] += float(blocker.get("maximum_speed_mps", 0.0))
		bucket["blocker_samples"] += 1


static func _summarize(bucket: Dictionary) -> Dictionary:
	var samples := maxf(float(bucket.get("blocker_samples", 0)), 1.0)
	return {
		"requested": int(bucket.get("requested", 0)),
		"available": int(bucket.get("available", 0)),
		"invalid": int(bucket.get("invalid", 0)),
		"blocker_samples": int(bucket.get("blocker_samples", 0)),
		"confidence_late_mean": float(bucket.get("confidence_late_total", 0.0)) / samples,
		"recognition_delay_mean": float(bucket.get(
			"recognition_delay_total", 0.0
		)) / samples,
		"maximum_speed_mps_mean": float(bucket.get("maximum_speed_total", 0.0)) / samples,
	}


static func _nondecreasing(
	low: Dictionary,
	middle: Dictionary,
	high: Dictionary,
	key: String,
) -> bool:
	return float(low.get(key, 0.0)) <= float(middle.get(key, 0.0)) \
		and float(middle.get(key, 0.0)) <= float(high.get(key, 0.0))


static func _nonincreasing(
	low: Dictionary,
	middle: Dictionary,
	high: Dictionary,
	key: String,
) -> bool:
	return float(low.get(key, 0.0)) >= float(middle.get(key, 0.0)) \
		and float(middle.get(key, 0.0)) >= float(high.get(key, 0.0))


static func _within_tolerance(
	low: Dictionary,
	middle: Dictionary,
	high: Dictionary,
	key: String,
	tolerance: float,
) -> bool:
	var low_value := float(low.get(key, 0.0))
	var middle_value := float(middle.get(key, 0.0))
	var high_value := float(high.get(key, 0.0))
	return absf(low_value - middle_value) <= tolerance \
		and absf(middle_value - high_value) <= tolerance
