class_name LiveReceptionIntegrator
extends RefCounted

const BallTrajectoryModel := preload("res://scripts/models/ball_trajectory.gd")


## Applies one audited reception contact to persistent state. It deliberately
## stops at the outgoing pass; setter response remains outside this boundary.
static func apply(
	state: RallyState,
	shadow_summary: Dictionary,
	selected_reception: Dictionary,
) -> Dictionary:
	if state == null or selected_reception.is_empty():
		return {"applied": false, "reason": "missing state or reception"}
	var receiver_id := int(selected_reception.get("actor_id", -1))
	var receiver := state.player_state(&"home", receiver_id)
	if receiver == null:
		return {"applied": false, "reason": "receiver missing from state"}
	var decision: Dictionary = shadow_summary.get("shadow_decision", {})
	var contact: Dictionary = decision.get("contact_result", {})
	var metadata: Dictionary = selected_reception.get("metadata", {})
	var trajectory_data: Dictionary = metadata.get("outgoing_trajectory", {})
	if trajectory_data.is_empty():
		return {"applied": false, "reason": "missing outgoing trajectory"}
	var selected_entry := _entry_for(
		shadow_summary.get("entries", []), receiver_id
	)
	## Entries normally live on RallyTrace rather than summary. The simulator
	## supplies them under rollout_entries only at the promotion boundary.
	if selected_entry.is_empty():
		selected_entry = _entry_for(
			shadow_summary.get("rollout_entries", []), receiver_id
		)
	var repeated: Dictionary = selected_entry.get(
		"repeated_read_candidate", {}
	)
	var center_position := Vector2(repeated.get(
		"projected_position", contact.get("contact_position", receiver.position)
	))
	var velocity := Vector2(repeated.get(
		"projected_velocity_mps", Vector2.ZERO
	))
	receiver.apply_position(center_position, velocity)
	var action := str(contact.get("action", "emergency_keep_alive"))
	receiver.body_state = RallyPlayerState.BodyState.DIVING \
		if action == "emergency_keep_alive" \
		else RallyPlayerState.BodyState.REACHING
	receiver.balance = clampf(float(repeated.get(
		"true_arrival_balance", 0.45
	)), 0.0, 1.0)
	var contact_time := float(contact.get("contact_time", 0.0))
	var recovery_duration := 0.34 if action == "emergency_keep_alive" else 0.16
	receiver.last_contact_time = contact_time
	receiver.recovery_until = contact_time + recovery_duration
	receiver.committed_until = receiver.recovery_until
	receiver.intent = &"recover"
	receiver.intent_target = center_position
	receiver.movement_mode = RallyPlayerState.MovementMode.RECOVERY

	var trajectory := _trajectory_from_dict(trajectory_data)
	state.advance_to(contact_time)
	state.register_contact(&"home", receiver_id)
	state.ball.launch(trajectory, &"home", receiver_id, 1)
	return {
		"applied": true,
		"receiver_id": receiver_id,
		"receiver_center_position": receiver.position,
		"receiver_contact_position": Vector2(contact.get(
			"contact_position", trajectory.start_position
		)),
		"receiver_velocity_mps": receiver.velocity,
		"receiver_body_state": RallyPlayerState.BodyState.keys()[receiver.body_state],
		"receiver_balance": receiver.balance,
		"receiver_recovery_until": receiver.recovery_until,
		"simulation_time": state.simulation_time,
		"ball_status": RallyBallState.Status.keys()[state.ball.status],
		"ball_origin": trajectory.start_position,
		"ball_destination": trajectory.end_position,
		"ball_start_time": trajectory.start_time,
		"ball_end_time": trajectory.end_time,
		"arrival": {
			"arrival_margin": float(repeated.get("true_arrival_margin", 0.0)),
			"travel_time": float(repeated.get("travel_time", 0.0)),
			"physical_feasibility": float(repeated.get(
				"true_physical_feasibility", 0.0
			)),
		},
	}


static func _trajectory_from_dict(data: Dictionary) -> BallTrajectory:
	return BallTrajectoryModel.create(
		str(data.get("trajectory_type", "continuous_reception")),
		Vector2(data.get("start_position", Vector2.ZERO)),
		Vector2(data.get("control_position", Vector2(0.5, 0.5))),
		Vector2(data.get("end_position", Vector2.ONE)),
		float(data.get("start_time", 0.0)),
		float(data.get("duration", 0.01)),
		float(data.get("apex_height_meters", 1.0)),
		float(data.get("start_height_meters", 1.0)),
		float(data.get("end_height_meters", 1.0)),
	)


static func _entry_for(entries: Array, player_id: int) -> Dictionary:
	for raw_entry in entries:
		var entry: Dictionary = raw_entry
		if int(entry.get("player_id", -1)) == player_id:
			return entry
	return {}
