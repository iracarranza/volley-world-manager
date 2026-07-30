class_name RallyOpportunitySystem
extends RefCounted


## Replays projected perception samples through a copied RallyState. The
## resulting windows describe when an action is available; they never select an
## official actor or mutate the source state.
static func evaluate_reception_timeline(
	source_state: RallyState,
	player_id: int,
	read_moments: Array[Dictionary],
	contact_time: float,
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
		scheduler.schedule(RallyMoment.create(
			float(sample.get("decision_time", state.simulation_time)),
			RallyMoment.Kind.PERCEPTION,
			&"home",
			player_id,
			{"read_index": index, "sample": sample},
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
		elif moment.kind == RallyMoment.Kind.INTENT_DEADLINE:
			if active_window != null:
				active_window.close(moment.time, &"ball_arrival")
				active_window = null
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
		"source_state_unchanged": is_equal_approx(
			source_state.simulation_time, source_time
		) and source_state.player_state(&"home", player_id).position.is_equal_approx(
			source_position
		) and source_state.player_state(&"home", player_id).velocity.is_equal_approx(
			source_velocity
		),
	}
