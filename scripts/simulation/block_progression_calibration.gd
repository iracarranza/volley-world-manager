class_name BlockerProgressionCalibration
extends RefCounted

## Gates 44 and 46 calibration for the shadow block slice.
##
## Gate 44 established the perceptual half: with movement attributes pinned
## identical across tiers, a stronger reader must recognize a set earlier and
## be no faster on the floor. Gate 46 adds the outcome half: misread rate,
## hesitation rate, and coordinated-versus-solo closes, measured across set
## difficulties rather than a single convenient rally.
##
## Set difficulty matters because the ordinary vertical-slice fixture is easy:
## a stable, slow set to a pin is read correctly by nearly everyone, so it
## produces no misreads at any tier and proves nothing about progression. The
## scenarios below sweep from that readable set to a fast, unstable one whose
## novelty degrades every blocker's read, which is where tier separation
## actually becomes visible.

const GameManagerModel := preload("res://scripts/managers/game_manager.gd")
const RallyStateBuilderModel := preload(
	"res://scripts/simulation/rally_state_builder.gd"
)
const ShadowBlockSystemModel := preload(
	"res://scripts/simulation/shadow_block_system.gd"
)

const TIERS := {
	"developing": 30,
	"established": 60,
	"elite": 92,
}

## Held fixed across every tier so a reach, speed, or timing difference can only
## come from the read, never from an unrelated physical advantage.
const FIXED_MOVEMENT_RATING: int = 55

## Set difficulty sweep. `stability` and spin drive BallContactSignature
## novelty, which degrades every blocker's perceived destination; shorter
## durations additionally shrink the observation window.
##
## `boundary_seam` is the scenario that actually produces misreads. A set landing
## deep inside a zone survives a large perception error without changing which
## zone a blocker names, so no realistic error flips it. A set sitting a
## hair inside the middle/left boundary flips on a small error -- which is
## exactly where real blockers misread, and the only place a zone-named
## commitment can be wrong for an honest reason.
const SCENARIOS: Array[Dictionary] = [
	{
		"key": "readable_pin", "destination_x": 0.82,
		"stability": 0.92, "speed_mps": 7.0, "duration": 0.72,
		"topspin_rps": 0.0, "sidespin_rps": 0.0,
	},
	{
		"key": "quick_middle", "destination_x": 0.50,
		"stability": 0.55, "speed_mps": 12.0, "duration": 0.36,
		"topspin_rps": 4.0, "sidespin_rps": 2.0,
	},
	{
		"key": "deceptive_pin", "destination_x": 0.18,
		"stability": 0.22, "speed_mps": 15.0, "duration": 0.30,
		"topspin_rps": 9.0, "sidespin_rps": 7.0,
	},
	{
		"key": "boundary_seam", "destination_x": 0.36,
		"stability": 0.20, "speed_mps": 15.5, "duration": 0.30,
		"topspin_rps": 12.0, "sidespin_rps": 10.0,
	},
]

const SET_ORIGIN := Vector2(0.50, 0.60)
## FLAGGED, AND IT IS THE THIRD INSTANCE OF ONE DEFECT. A fixed contact height,
## used for every sample this calibration takes.
##
## Gate D pinned contact *depth* at a literal 0.36 m and drifted from the game
## because of it; `ExecutionScaleCalibration.contest_shares` projected a block mix
## from thresholds production no longer reads. This is the same shape: a
## calibration holding constant the very quantity whose variation decides the
## outcome it measures. Contact height is `standing_reach + leap - 0.10` and spans
## roughly 3.0-3.3 m across a real roster, so 2.55 m is not even a central value
## of the distribution it stands in for -- it is below all of it.
##
## Sweep it, the way `AttackGeometryCalibration.depth_sweep` now sweeps depth.
const CONTACT_HEIGHT_METERS: float = 2.55

## Time from set release to hitter contact. A block needs a realistic window:
## the closing burst plus the takeoff ContactEnvelopeSystem requires. Too short
## a window makes every close physically impossible and the sweep measures
## nothing but unreachability.
const CONTACT_DELAY_SECONDS: float = 0.95


static func run(sample_count: int, start_seed: int) -> Dictionary:
	var safe_samples := maxi(sample_count, 1)
	var by_tier := {}
	var by_scenario := {}
	for tier_name in TIERS:
		var bucket := _new_bucket()
		var scenario_buckets := {}
		for scenario in SCENARIOS:
			scenario_buckets[str(scenario["key"])] = _new_bucket()
		for offset in range(safe_samples):
			var manager := GameManagerModel.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = false
			_apply_tier(manager, int(TIERS[tier_name]))
			var lineup: RotationLineup = manager.current_lineup()
			var seed_value := start_seed + offset
			var state := RallyStateBuilderModel.build(
				manager.players, lineup, manager.current_defensive_plan(),
				manager.opponent_team, manager.called_play(), false, seed_value,
			)
			for scenario in SCENARIOS:
				var shadow_attack := _synthetic_attack(
					lineup.active_setter_id(), scenario,
				)
				var shadow_block := ShadowBlockSystemModel.evaluate(
					state, shadow_attack, seed_value + 1900007,
				)
				_add(bucket, shadow_block)
				_add(scenario_buckets[str(scenario["key"])], shadow_block)
		by_tier[tier_name] = _summarize(bucket)
		var scenario_summary := {}
		for scenario_key in scenario_buckets:
			scenario_summary[scenario_key] = _summarize(scenario_buckets[scenario_key])
		by_scenario[tier_name] = scenario_summary
	var developing: Dictionary = by_tier.get("developing", {})
	var established: Dictionary = by_tier.get("established", {})
	var elite: Dictionary = by_tier.get("elite", {})
	return {
		"gate": "block_observation_progression_gates_44_and_46",
		"shadow_only": true,
		"sample_count_per_tier": safe_samples,
		"scenario_count": SCENARIOS.size(),
		"start_seed": start_seed,
		"by_tier": by_tier,
		"by_scenario": by_scenario,
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
			## Gate 46: a stronger reader must misread less often.
			"wrong_read_monotonic": _nonincreasing(
				developing, established, elite, "wrong_read_rate"
			),
			## Gate 46: and must fail to pull the trigger on a good read less
			## often.
			"hesitation_monotonic": _nonincreasing(
				developing, established, elite, "hesitation_rate"
			),
		},
		## Gate 46: the sweep must actually contain misreads, coordinated
		## closes, and solo closes, or the rates above are measuring nothing.
		"coverage": {
			"wrong_reads_observed": float(developing.get("wrong_read_rate", 0.0)) > 0.0,
			## Guards against the hesitation metric silently becoming
			## unreachable, which it was until the bar was moved off the
			## blocker's own threshold.
			"hesitation_observed": float(developing.get("hesitation_rate", 0.0)) > 0.0,
			"coordinated_closes_observed": float(
				developing.get("coordinated_assist_rate", 0.0)
			) > 0.0 or float(elite.get("coordinated_assist_rate", 0.0)) > 0.0,
			"solo_closes_observed": float(developing.get("solo_close_rate", 0.0)) > 0.0 \
				or float(elite.get("solo_close_rate", 0.0)) > 0.0,
			"coordination_revisions_observed": float(
				developing.get("coordination_change_mean", 0.0)
			) > 0.0 or float(elite.get("coordination_change_mean", 0.0)) > 0.0,
		},
		"fixture_valid": int(developing.get("invalid", 1)) == 0 \
			and int(established.get("invalid", 1)) == 0 \
			and int(elite.get("invalid", 1)) == 0,
	}


## Builds a shadow-attack payload with a chosen set difficulty. The hitter
## contact and the set destination share one x so a blocker's perceived zone can
## be graded against a meaningful truth.
static func _synthetic_attack(
	setter_id: int,
	scenario: Dictionary,
) -> Dictionary:
	var destination_x := float(scenario["destination_x"])
	var duration := float(scenario["duration"])
	var destination := Vector2(destination_x, 0.53)
	var signature := BallContactSignature.create(
		&"set", float(scenario["speed_mps"]), 0.0, 0.0,
		float(scenario.get("topspin_rps", 0.0)),
		float(scenario.get("sidespin_rps", 0.0)),
		float(scenario["stability"]),
	)
	var flight := BallFlight.create(
		SET_ORIGIN, destination, 0.0, duration, signature, CONTACT_HEIGHT_METERS,
	)
	return {
		"available": true,
		"setter_id": setter_id,
		"set_flight": flight.to_dict(),
		"hitter_response": {
			"available": true,
			"player_id": -1,
			"contact_position": Vector2(destination_x, 0.62),
			"contact_time": duration + CONTACT_DELAY_SECONDS,
			"resolved_approach": {"runup_quality": 0.70},
		},
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
		## block_timing feeds the block_engagement_distance SystemFitProfile;
		## pinning it keeps the engagement band tier-independent so the
		## commitment threshold varies only with reading.
		player.block_timing = FIXED_MOVEMENT_RATING
		player.refresh_system_fit_profiles()


static func _new_bucket() -> Dictionary:
	return {
		"requested": 0, "available": 0, "invalid": 0,
		"confidence_late_total": 0.0, "recognition_delay_total": 0.0,
		"maximum_speed_total": 0.0, "blocker_samples": 0,
		"wrong_reads": 0, "off_target": 0, "hesitations": 0,
		"committed": 0, "engagement_in_system": 0,
		"solo_closes": 0, "coordinated_closes": 0,
		"coordination_changes": 0,
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
	bucket["coordination_changes"] += int(shadow_block.get("coordination_changes", 0))
	if bool(shadow_block.get("solo_close", false)):
		bucket["solo_closes"] += 1
	if bool(shadow_block.get("coordinated_assist", false)):
		bucket["coordinated_closes"] += 1
	for raw_blocker in blockers:
		var blocker: Dictionary = raw_blocker
		var observation: Dictionary = blocker.get("observation", {})
		bucket["confidence_late_total"] += float(observation.get("confidence_late", 0.0))
		bucket["recognition_delay_total"] += float(observation.get(
			"recognition_delay_seconds", 0.0
		))
		bucket["maximum_speed_total"] += float(blocker.get("maximum_speed_mps", 0.0))
		bucket["blocker_samples"] += 1
		if str(blocker.get("commitment", "")) in ShadowBlockSystemModel.CLOSING_COMMITMENTS:
			bucket["committed"] += 1
		if bool(blocker.get("wrong_read", false)):
			bucket["wrong_reads"] += 1
		if bool(blocker.get("commitment_off_target", false)):
			bucket["off_target"] += 1
		if bool(blocker.get("hesitated", false)):
			bucket["hesitations"] += 1
		if bool(blocker.get("block_engagement_in_system", false)):
			bucket["engagement_in_system"] += 1


static func _summarize(bucket: Dictionary) -> Dictionary:
	var samples := maxf(float(bucket.get("blocker_samples", 0)), 1.0)
	var rallies := maxf(float(bucket.get("available", 0)), 1.0)
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
		"commit_rate": float(bucket.get("committed", 0)) / samples,
		"wrong_read_rate": float(bucket.get("wrong_reads", 0)) / samples,
		"off_target_rate": float(bucket.get("off_target", 0)) / samples,
		"hesitation_rate": float(bucket.get("hesitations", 0)) / samples,
		"engagement_in_system_rate": float(
			bucket.get("engagement_in_system", 0)
		) / samples,
		"solo_close_rate": float(bucket.get("solo_closes", 0)) / rallies,
		"coordinated_assist_rate": float(bucket.get("coordinated_closes", 0)) / rallies,
		"coordination_change_mean": float(bucket.get("coordination_changes", 0)) / rallies,
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
