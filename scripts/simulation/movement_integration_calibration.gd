class_name MovementIntegrationCalibration
extends RefCounted

## Measures whether stepped integration reproduces the projection the engine
## already trusts.
##
## This is the question that has to be answered before movement trails could
## ever become authoritative. `RallyMovementSystem.project_toward()` is what
## every reachability, arrival-margin, and opportunity decision in the engine is
## built on. If `ShadowMovementSystem` steps to a different place than that
## function projects, then adopting trails would silently move every one of
## those decisions. If it lands in the same place, trails are a refinement
## rather than a replacement, and the existing calibration record survives.
##
## The sweep is deliberately run over actors harvested from real seeded rally
## states, so the ratings, masses, fatigue levels, and court geometry are the
## ones the game actually produces rather than synthetic values chosen to pass.

const StateBuilderModel := preload("res://scripts/simulation/rally_state_builder.gd")
const ShadowMovementModel := preload("res://scripts/simulation/shadow_movement_system.gd")
const KinematicsModel := preload("res://scripts/simulation/rally_kinematics.gd")

## Realistic traversal windows: a short defensive adjustment through a full
## transition. Each is run against every harvested actor and target.
const DURATIONS: Array[float] = [0.35, 0.60, 0.90, 1.30]
## Targets spanning near adjustments and cross-court sprints, so the sweep
## contains both traversals that finish early and traversals that run out of
## time. A sweep of only one kind would prove nothing about the other.
const TARGETS: Array[Vector2] = [
	Vector2(0.20, 0.62),
	Vector2(0.50, 0.72),
	Vector2(0.82, 0.60),
	Vector2(0.50, 0.94),
]
const AGREEMENT_TOLERANCE_METERS: float = 0.12


static func run(
	seed_count: int = 8,
	base_seed: int = 610000,
	step_seconds: float = ShadowMovementModel.DEFAULT_STEP_SECONDS,
) -> Dictionary:
	var manager_script := load("res://scripts/managers/game_manager.gd")
	var samples: Array[Dictionary] = []
	for index in range(maxi(seed_count, 1)):
		var seed_value := base_seed + index * 37
		var manager = manager_script.new()
		manager.seed_vertical_slice_data()
		var state: RallyState = StateBuilderModel.build(
			manager.players, manager.current_lineup(),
			manager.current_defensive_plan(), manager.opponent_team,
			manager.called_play(), false, seed_value,
		)
		if state == null:
			continue
		for value in state.home_players.values():
			var actor := value as RallyPlayerState
			if actor == null or actor.player == null:
				continue
			for target in TARGETS:
				for duration in DURATIONS:
					var sample := _compare(actor, target, duration, step_seconds)
					if not sample.is_empty():
						samples.append(sample)
	return _summarize(samples, step_seconds)


static func _compare(
	actor: RallyPlayerState,
	target: Vector2,
	duration: float,
	step_seconds: float,
) -> Dictionary:
	var mode := RallyPlayerState.MovementMode.LATERAL
	var stepped: Dictionary = ShadowMovementModel.integrate(
		actor, target, duration, mode, step_seconds
	)
	if not bool(stepped.get("available", false)):
		return {}
	var reference: Dictionary = ShadowMovementModel.reference_projection(
		actor, target, duration, mode
	)
	var disagreement := KinematicsModel.court_delta_meters(
		Vector2(stepped.get("landing_position", Vector2.ZERO)),
		Vector2(reference.get("landing_position", Vector2.ZERO)),
	).length()
	return {
		"disagreement_meters": disagreement,
		"stepped_reached": bool(stepped.get("reached_target", false)),
		"reference_reached": bool(reference.get("reached_target", false)),
		"stepped_speed": float(stepped.get("final_speed_mps", 0.0)),
		"reference_speed": float(reference.get("final_speed_mps", 0.0)),
		"trail_samples": int(stepped.get("step_count", 0)) + 1,
		"path_length_meters": float(stepped.get("path_length_meters", 0.0)),
		"source_state_unchanged": bool(stepped.get("source_state_unchanged", false)),
	}


static func _summarize(
	samples: Array[Dictionary], step_seconds: float
) -> Dictionary:
	if samples.is_empty():
		return {"fixture_valid": false, "sample_count": 0}
	var total := 0.0
	var worst := 0.0
	var within := 0
	var reach_agreements := 0
	var reached_any := 0
	var fell_short_any := 0
	var immutable := 0
	var smallest_trail := 9999
	for sample in samples:
		var disagreement := float(sample["disagreement_meters"])
		total += disagreement
		worst = maxf(worst, disagreement)
		if disagreement <= AGREEMENT_TOLERANCE_METERS:
			within += 1
		if bool(sample["stepped_reached"]) == bool(sample["reference_reached"]):
			reach_agreements += 1
		if bool(sample["reference_reached"]):
			reached_any += 1
		else:
			fell_short_any += 1
		if bool(sample["source_state_unchanged"]):
			immutable += 1
		smallest_trail = mini(smallest_trail, int(sample["trail_samples"]))
	var count := float(samples.size())
	return {
		"fixture_valid": true,
		"sample_count": samples.size(),
		"step_seconds": step_seconds,
		"mean_disagreement_meters": total / count,
		"worst_disagreement_meters": worst,
		"within_tolerance_rate": float(within) / count,
		"reach_agreement_rate": float(reach_agreements) / count,
		"source_immutable_rate": float(immutable) / count,
		"minimum_trail_samples": smallest_trail,
		## A sweep containing only traversals that finished, or only traversals
		## that ran out of time, would say nothing about the other half.
		"coverage": {
			"completed_traversals_observed": reached_any > 0,
			"incomplete_traversals_observed": fell_short_any > 0,
			"trail_is_sampled": smallest_trail >= 3,
		},
	}
