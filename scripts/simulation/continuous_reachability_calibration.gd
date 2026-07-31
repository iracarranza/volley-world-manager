class_name ContinuousReachabilityCalibration
extends RefCounted

## Gate 50: measures how much the discrete perception-read model of
## `ActionOpportunityWindow` disagrees with continuously sampling the same
## traversal via `RallyMoment.Kind.MOVEMENT_UPDATE`.
##
## Reachability today is only evaluated at Gate 6's scheduled reads plus the
## contact deadline -- nothing between them. This sweep answers the question
## that was left open: how much timing error does that discreteness carry,
## and does it ever change whether a window opens at all? It changes no
## outcome; `RallyOpportunitySystem.evaluate_reception_timeline()` itself is
## unmodified in its discrete return values, this only reads the additional
## continuous fields it now also reports.
##
## Read moments are built the same way `ShadowReceptionSystem` builds them --
## carrying a projected actor forward through `RallyMovementSystem.
## project_toward()` between reads and scoring reachability with
## `evaluate_opportunity()` -- so the discrete side of this comparison is the
## real production formula, not a synthetic stand-in.

const StateBuilderModel := preload("res://scripts/simulation/rally_state_builder.gd")
const RallyOpportunityModel := preload("res://scripts/simulation/rally_opportunity_system.gd")

## Gate 6's three-read shape: an early, mid, and late in-flight glance.
const READ_PROGRESS: Array[float] = [0.12, 0.32, 0.52]
## Tight, moderate, and generous windows between the first read and contact,
## so the sweep contains traversals that finish comfortably and traversals
## that run out of time -- a sweep of only one kind proves nothing about the
## other.
const AVAILABLE_DURATIONS: Array[float] = [0.55, 0.85, 1.25]
## Corrections spanning a small in-system adjustment to a real scramble, all
## relative to the actor's harvested starting position.
const TARGET_OFFSETS: Array[Vector2] = [
	Vector2(0.03, -0.04),
	Vector2(-0.10, 0.08),
	Vector2(0.22, -0.16),
	Vector2(-0.28, -0.22),
]


static func run(seed_count: int = 8, base_seed: int = 750000) -> Dictionary:
	var manager_script := load("res://scripts/managers/game_manager.gd")
	var samples: Array[Dictionary] = []
	for index in range(maxi(seed_count, 1)):
		var seed_value := base_seed + index * 41
		var manager = manager_script.new()
		manager.seed_vertical_slice_data()
		var state: RallyState = StateBuilderModel.build(
			manager.players, manager.current_lineup(),
			manager.current_defensive_plan(), manager.opponent_team,
			manager.called_play(), false, seed_value,
		)
		if state == null:
			continue
		for raw_player_id in state.home_players:
			var player_id := int(raw_player_id)
			var actor := state.player_state(&"home", player_id)
			if actor == null or actor.player == null:
				continue
			for offset in TARGET_OFFSETS:
				for available_duration in AVAILABLE_DURATIONS:
					var target := Vector2(
						clampf(actor.position.x + offset.x, 0.0, 1.0),
						clampf(actor.position.y + offset.y, 0.0, 1.0),
					)
					var sample := _compare(state, actor, target, available_duration)
					if not sample.is_empty():
						samples.append(sample)
	return _summarize(samples)


static func _compare(
	state: RallyState,
	actor: RallyPlayerState,
	target: Vector2,
	available_duration: float,
) -> Dictionary:
	var start_time := state.simulation_time
	var contact_time := start_time + available_duration
	var read_moments := _build_read_moments(actor, target, start_time, contact_time)
	if read_moments.is_empty():
		return {}
	var result: Dictionary = RallyOpportunityModel.evaluate_reception_timeline(
		state, actor.player_id, read_moments, contact_time, 0.0,
	)
	if not bool(result.get("available", false)):
		return {}
	var discrete_ever_reachable := bool(result.get("ever_reachable", false))
	var continuous_ever_reachable := bool(result.get("continuous_ever_reachable", false))
	var open_delta: Variant = result.get("discrete_vs_continuous_open_delta")
	var close_delta: Variant = result.get("discrete_vs_continuous_close_delta")
	return {
		"ever_reachable_agrees": discrete_ever_reachable == continuous_ever_reachable,
		"discrete_ever_reachable": discrete_ever_reachable,
		"continuous_ever_reachable": continuous_ever_reachable,
		"has_open_delta": open_delta != null,
		"open_delta_seconds": float(open_delta) if open_delta != null else 0.0,
		"has_close_delta": close_delta != null,
		"close_delta_seconds": float(close_delta) if close_delta != null else 0.0,
		"continuous_sample_count": Array(result.get("continuous_samples", [])).size(),
		"source_state_unchanged": bool(result.get("source_state_unchanged", false)),
	}


## Mirrors ShadowReceptionSystem's carried-projection read loop: each read
## advances a copied actor toward the previous read's target via
## `project_toward()`, then scores reachability at the new position. This is
## the real production shape of a discrete read, not a synthetic stand-in.
static func _build_read_moments(
	actor: RallyPlayerState,
	target: Vector2,
	start_time: float,
	contact_time: float,
) -> Array[Dictionary]:
	var moments: Array[Dictionary] = []
	var projected_actor := actor
	var previous_time := start_time
	for progress in READ_PROGRESS:
		var decision_time := start_time + (contact_time - start_time) * progress
		if decision_time >= contact_time:
			continue
		var projection: Dictionary = RallyMovementSystem.project_toward(
			projected_actor, target, decision_time - previous_time,
			RallyPlayerState.MovementMode.LATERAL,
		)
		var advanced := projection.get("actor") as RallyPlayerState
		if advanced == null:
			continue
		projected_actor = advanced
		var opportunity := RallyMovementSystem.evaluate_opportunity(
			projected_actor, &"receive", target, contact_time, decision_time,
		)
		moments.append({
			"decision_time": decision_time,
			"perceived_destination": target,
			## Stated rather than left to the fallback: this fixture models a
			## receiver whose read of the arrival time is correct, so the
			## comparison isolates discreteness from perception error.
			"perceived_arrival_time": contact_time,
			"projected_position": projected_actor.position,
			"projected_velocity_mps": projected_actor.velocity,
			"reachable": opportunity.reachable,
		})
		previous_time = decision_time
	return moments


static func _summarize(samples: Array[Dictionary]) -> Dictionary:
	if samples.is_empty():
		return {"fixture_valid": false, "sample_count": 0}
	var agreements := 0
	var immutable := 0
	var with_open_delta := 0
	var open_delta_total := 0.0
	var open_delta_worst := 0.0
	var with_close_delta := 0
	var close_delta_total := 0.0
	var close_delta_worst := 0.0
	var discrete_reachable_any := 0
	var discrete_unreachable_any := 0
	for sample in samples:
		if bool(sample["ever_reachable_agrees"]):
			agreements += 1
		if bool(sample["source_state_unchanged"]):
			immutable += 1
		if bool(sample["discrete_ever_reachable"]):
			discrete_reachable_any += 1
		else:
			discrete_unreachable_any += 1
		if bool(sample["has_open_delta"]):
			with_open_delta += 1
			var open_delta := absf(float(sample["open_delta_seconds"]))
			open_delta_total += open_delta
			open_delta_worst = maxf(open_delta_worst, open_delta)
		if bool(sample["has_close_delta"]):
			with_close_delta += 1
			var close_delta := absf(float(sample["close_delta_seconds"]))
			close_delta_total += close_delta
			close_delta_worst = maxf(close_delta_worst, close_delta)
	var count := float(samples.size())
	return {
		"fixture_valid": true,
		"sample_count": samples.size(),
		"ever_reachable_agreement_rate": float(agreements) / count,
		"source_immutable_rate": float(immutable) / count,
		"mean_open_delta_seconds": (
			open_delta_total / float(with_open_delta) if with_open_delta > 0 else 0.0
		),
		"worst_open_delta_seconds": open_delta_worst,
		"mean_close_delta_seconds": (
			close_delta_total / float(with_close_delta) if with_close_delta > 0 else 0.0
		),
		"worst_close_delta_seconds": close_delta_worst,
		"windows_with_open_delta": with_open_delta,
		"windows_with_close_delta": with_close_delta,
		## A sweep that only ever finds the actor reachable, or only ever
		## finds them unreachable, would say nothing about the other case.
		"coverage": {
			"reachable_cases_observed": discrete_reachable_any > 0,
			"unreachable_cases_observed": discrete_unreachable_any > 0,
			"open_delta_cases_observed": with_open_delta > 0,
		},
	}
