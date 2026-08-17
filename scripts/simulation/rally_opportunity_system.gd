class_name RallyOpportunitySystem
extends RefCounted


## Replays projected perception samples through a copied RallyState. The
## resulting windows describe when an action is available; they never select an
## official actor or mutate the source state.
##
## Gate 50 adds one MOVEMENT_UPDATE per inter-read gap. Reachability used to be
## defined only at the discrete perception reads -- nothing was evaluated
## between them. MOVEMENT_UPDATE consumes ShadowMovementSystem's already-proven
## stepper to continuously sample the actor's real traversal across each gap
## and evaluate reachability throughout it, then reports where that continuous
## read disagrees with the discrete one. It reads only what the preceding
## PERCEPTION moment set from perceived data -- the intent target and that
## read's perceived arrival time -- so it never consults ball truth, and it
## never mutates `actor`, leaving the discrete computation this function
## already performed unaffected.
static func evaluate_reception_timeline(
	source_state: RallyState,
	player_id: int,
	read_moments: Array[Dictionary],
	contact_time: float,
	tactical_priority: float = 0.0,
) -> Dictionary:
	if source_state == null:
		return {"available": false, "reason": "missing_state"}
	var source_time := source_state.simulation_time
	var source_actor := source_state.player_state(&"home", player_id)
	var source_position := source_actor.position if source_actor != null else Vector2.ZERO
	var source_velocity := source_actor.velocity if source_actor != null else Vector2.ZERO
	var state := source_state.snapshot()
	var actor := state.player_state(&"home", player_id)
	if actor == null:
		return {"available": false, "reason": "missing_actor"}
	var scheduler := RallyScheduler.new()
	for index in range(read_moments.size()):
		var sample: Dictionary = read_moments[index]
		var read_time := float(sample.get("decision_time", state.simulation_time))
		scheduler.schedule(RallyMoment.create(
			read_time,
			RallyMoment.Kind.PERCEPTION,
			&"home",
			player_id,
			{"read_index": index, "sample": sample},
		))
		var gap_end := contact_time
		if index + 1 < read_moments.size():
			gap_end = float(read_moments[index + 1].get("decision_time", contact_time))
		## Scheduled at the same instant as the read that opens the gap, so it
		## always dequeues immediately after: PERCEPTION (Kind 0) sorts before
		## MOVEMENT_UPDATE (Kind 1) at equal times.
		scheduler.schedule(RallyMoment.create(
			read_time,
			RallyMoment.Kind.MOVEMENT_UPDATE,
			&"home",
			player_id,
			{"gap_end": gap_end},
		))
	scheduler.schedule(RallyMoment.create(
		contact_time,
		RallyMoment.Kind.INTENT_DEADLINE,
		&"home",
		player_id,
		{"action_type": "receive"},
	))

	var windows: Array[ActionOpportunityWindow] = []
	var active_window: ActionOpportunityWindow = null
	var timeline: Array[Dictionary] = []
	var intent_changes := 0
	var previous_target := actor.intent_target
	var has_intent := false
	var continuous_samples: Array[Dictionary] = []
	var continuous_opened_at := -1.0
	var continuous_closed_at := -1.0
	## The deadline the continuous read judges against. It must be the
	## receiver's *perceived* arrival time -- the same value the discrete read
	## in `ShadowReceptionSystem` uses -- not `contact_time`, which is the
	## authoritative flight arrival. A player deciding whether they can still
	## get there reasons from when they think the ball lands.
	var perceived_deadline := contact_time
	while true:
		var moment := scheduler.next()
		if moment == null:
			break
		state.advance_to(moment.time)
		if moment.kind == RallyMoment.Kind.PERCEPTION:
			var sample: Dictionary = moment.data.get("sample", {})
			var target := Vector2(sample.get(
				"perceived_destination", actor.position
			))
			## Ready footwork, stated before the step rather than by the
			## `set_intent` below it. The first perception moment would otherwise
			## apply movement while the actor still carried the state builder's
			## IDLE, and a defender pursuing a ball behind them must stay square
			## because of what this movement *is*, not because of which default
			## happened to be in the field.
			actor.movement_mode = RallyPlayerState.MovementMode.LATERAL
			actor.apply_position(
				Vector2(sample.get("projected_position", actor.position)),
				Vector2(sample.get("projected_velocity_mps", actor.velocity)),
			)
			if has_intent and not target.is_equal_approx(previous_target):
				intent_changes += 1
			actor.set_intent(
				&"receive", target, contact_time,
				RallyPlayerState.MovementMode.LATERAL,
			)
			previous_target = target
			has_intent = true
			perceived_deadline = float(sample.get(
				"perceived_arrival_time", contact_time
			))
			var reachable := bool(sample.get("reachable", false))
			var transition := "sample"
			if reachable and active_window == null:
				active_window = ActionOpportunityWindow.create(
					&"receive", &"home", player_id, moment.time,
					contact_time, &"projected_reachable",
				)
				windows.append(active_window)
				transition = "opened"
			elif not reachable and active_window != null:
				active_window.close(moment.time, &"projected_late")
				active_window = null
				transition = "closed"
			if active_window != null:
				active_window.record_sample(sample)
			state.decision_log.append({
				"time": moment.time,
				"player_id": player_id,
				"intent": "receive",
				"target": target,
				"reachable": reachable,
				"transition": transition,
			})
			timeline.append({
				"time": moment.time,
				"kind": "perception",
				"read_index": int(moment.data.get("read_index", -1)),
				"position": actor.position,
				"velocity_mps": actor.velocity,
				"intent_target": actor.intent_target,
				"reachable": reachable,
				"window_transition": transition,
			})
		elif moment.kind == RallyMoment.Kind.MOVEMENT_UPDATE:
			var gap_end := float(moment.data.get("gap_end", moment.time))
			## Never sample past the instant the receiver believes the ball
			## arrives. Beyond it there is no action left to be reachable for, and
			## an actor who has coasted onto their target would otherwise report
			## "reachable" purely because the remaining distance is zero -- the
			## same have-you-already-arrived degradation the commitment reset
			## above avoids, arriving by a different route.
			gap_end = minf(gap_end, perceived_deadline)
			var gap_length := maxf(gap_end - moment.time, 0.0)
			if gap_length > 0.0001 and has_intent:
				var integration: Dictionary = ShadowMovementSystem.integrate(
					actor, actor.intent_target, gap_length,
					RallyPlayerState.MovementMode.LATERAL,
				)
				if bool(integration.get("available", false)):
					var trail: Array = integration.get("trail", [])
					var sample_times: Array = integration.get("sample_times", [])
					for sample_index in range(1, trail.size()):
						var sample_time := moment.time + float(sample_times[sample_index])
						var step_seconds := float(sample_times[sample_index]) \
							- float(sample_times[sample_index - 1])
						var sample_velocity := actor.velocity
						if step_seconds > 0.0001:
							sample_velocity = RallyKinematics.court_delta_meters(
								Vector2(trail[sample_index - 1]),
								Vector2(trail[sample_index]),
							) / step_seconds
						var sample_actor := actor.snapshot()
						sample_actor.apply_position(Vector2(trail[sample_index]), sample_velocity)
						## `set_intent` above committed this actor to receiving until
						## the deadline, and `evaluate_opportunity` charges
						## `committed_until` against the time still available. That is
						## right when asking whether a player could take up some *other*
						## action, and wrong here: being committed to receiving must not
						## be what makes them unable to receive. Left in place it zeroes
						## available time on every sample and the read silently degrades
						## into "have you already arrived" rather than "can you still
						## get there".
						sample_actor.committed_until = 0.0
						var opportunity := RallyMovementSystem.evaluate_opportunity(
							sample_actor, &"receive", actor.intent_target,
							perceived_deadline, sample_time, tactical_priority,
						)
						continuous_samples.append({
							"time": sample_time,
							"position": sample_actor.position,
							"reachable": opportunity.reachable,
							"arrival_margin": opportunity.arrival_margin,
						})
						if opportunity.reachable and continuous_opened_at < 0.0:
							continuous_opened_at = sample_time
						elif not opportunity.reachable and continuous_opened_at >= 0.0 \
								and continuous_closed_at < 0.0:
							continuous_closed_at = sample_time
			timeline.append({
				"time": moment.time,
				"kind": "movement_update",
				"gap_end": gap_end,
				"continuous_sample_count": continuous_samples.size(),
			})
		elif moment.kind == RallyMoment.Kind.INTENT_DEADLINE:
			if active_window != null:
				active_window.close(moment.time, &"ball_arrival")
				active_window = null
			if continuous_opened_at >= 0.0 and continuous_closed_at < 0.0:
				continuous_closed_at = moment.time
			timeline.append({
				"time": moment.time,
				"kind": "intent_deadline",
				"position": actor.position,
			})

	var window_dicts: Array[Dictionary] = []
	var total_open_duration := 0.0
	for window in windows:
		window_dicts.append(window.to_dict())
		total_open_duration += window.duration()
	var discrete_window: Dictionary = window_dicts[0] if not window_dicts.is_empty() else {}
	return {
		"available": true,
		"player_id": player_id,
		"windows": window_dicts,
		"timeline": timeline,
		"ever_reachable": not windows.is_empty(),
		"window_count": windows.size(),
		"total_open_duration": total_open_duration,
		"intent_change_count": intent_changes,
		"final_position": actor.position,
		"final_velocity_mps": actor.velocity,
		"decision_log": state.decision_log.duplicate(true),
		## Gate 50: the same reachability question, answered by continuously
		## sampling the real traversal across each inter-read gap instead of
		## only at the discrete reads. Compare against `windows` above to see
		## how much timing error the discrete-read-only model carries.
		"continuous_samples": continuous_samples,
		"continuous_ever_reachable": continuous_opened_at >= 0.0,
		"continuous_opened_at": continuous_opened_at,
		"continuous_closed_at": continuous_closed_at,
		"discrete_vs_continuous_open_delta": (
			continuous_opened_at - float(discrete_window.get("opened_at", 0.0))
		) if continuous_opened_at >= 0.0 and not discrete_window.is_empty() else null,
		"discrete_vs_continuous_close_delta": (
			continuous_closed_at - float(discrete_window.get("closed_at", 0.0))
		) if continuous_closed_at >= 0.0 and not discrete_window.is_empty() \
			and float(discrete_window.get("closed_at", -1.0)) >= 0.0 else null,
		"source_state_unchanged": is_equal_approx(
			source_state.simulation_time, source_time
		) and source_state.player_state(&"home", player_id).position.is_equal_approx(
			source_position
		) and source_state.player_state(&"home", player_id).velocity.is_equal_approx(
			source_velocity
		),
	}
