class_name LiveSetterIntegrator
extends RefCounted

const BallTrajectoryModel := preload("res://scripts/models/ball_trajectory.gd")


static func apply(state: RallyState, setter_candidate: Dictionary) -> Dictionary:
	if state == null or setter_candidate.is_empty():
		return {"applied": false, "reason": "missing state or setter candidate"}
	var setter_id := int(setter_candidate.get("actor_id", -1))
	var setter := state.player_state(&"home", setter_id)
	if setter == null:
		return {"applied": false, "reason": "setter missing from state"}
	if state.ball.contact_count != 1 or state.ball.last_touch_side != &"home":
		return {"applied": false, "reason": "reception state not established"}
	var contact_time := float(setter_candidate.get("contact_time", -1.0))
	if contact_time < state.simulation_time:
		return {"applied": false, "reason": "setter contact precedes live state"}
	var center_position := Vector2(setter_candidate.get(
		"center_position", setter.position
	))
	var velocity := Vector2(setter_candidate.get("velocity_mps", Vector2.ZERO))
	## A setter releasing to the ball is an opened-up run, and
	## `ShadowSetterResponseSystem` already resolves every leg of that release in
	## TRANSITION. Carrying that classification here is what makes the arrival
	## orientation the route they actually ran rather than the stance they left.
	## Only the movement establishes it -- squaring to the intended target is a
	## contact mechanic and is not claimed here.
	setter.movement_mode = RallyPlayerState.MovementMode.TRANSITION
	setter.apply_position(center_position, velocity)
	setter.body_state = RallyPlayerState.BodyState.AIRBORNE \
		if bool(setter_candidate.get("requires_jump", false)) \
		else RallyPlayerState.BodyState.REACHING
	setter.balance = clampf(float(setter_candidate.get(
		"arrival_balance", 0.5
	)), 0.0, 1.0)
	setter.last_contact_time = contact_time
	setter.recovery_until = contact_time + (
		0.24 if setter.body_state == RallyPlayerState.BodyState.AIRBORNE else 0.12
	)
	setter.committed_until = setter.recovery_until
	setter.intent = &"recover"
	setter.intent_target = center_position
	setter.movement_mode = RallyPlayerState.MovementMode.RECOVERY
	state.advance_to(contact_time)
	state.register_contact(&"home", setter_id)
	return {
		"applied": true,
		"setter_id": setter_id,
		"selected_action": str(setter_candidate.get("selected_action", "")),
		"setter_center_position": setter.position,
		"setter_contact_position": Vector2(setter_candidate.get(
			"contact_position", state.ball.position
		)),
		"setter_velocity_mps": setter.velocity,
		"setter_body_state": RallyPlayerState.BodyState.keys()[setter.body_state],
		"setter_balance": setter.balance,
		"setter_recovery_until": setter.recovery_until,
		"simulation_time": state.simulation_time,
		"contact_number": state.contact_number,
		"ball_status_at_contact": RallyBallState.Status.keys()[state.ball.status],
		"observation_fingerprint": str(setter_candidate.get(
			"observation_fingerprint", ""
		)),
	}


static func launch_set(
	state: RallyState,
	trajectory_data: Dictionary,
	setter_id: int,
) -> Dictionary:
	if state == null or trajectory_data.is_empty() or state.contact_number != 2:
		return {"applied": false, "reason": "second contact not established"}
	var trajectory := BallTrajectoryModel.create(
		str(trajectory_data.get("trajectory_type", "continuous_set")),
		Vector2(trajectory_data.get("start_position", Vector2.ZERO)),
		Vector2(trajectory_data.get("control_position", Vector2(0.5, 0.5))),
		Vector2(trajectory_data.get("end_position", Vector2.ONE)),
		float(trajectory_data.get("start_time", state.simulation_time)),
		float(trajectory_data.get("duration", 0.01)),
		float(trajectory_data.get("apex_height_meters", 1.0)),
		float(trajectory_data.get("start_height_meters", 1.0)),
		float(trajectory_data.get("end_height_meters", 1.0)),
	)
	state.ball.launch(trajectory, &"home", setter_id, 2)
	return {
		"applied": true,
		"ball_status": RallyBallState.Status.keys()[state.ball.status],
		"ball_origin": trajectory.start_position,
		"ball_destination": trajectory.end_position,
		"ball_start_time": trajectory.start_time,
		"ball_end_time": trajectory.end_time,
		"contact_number": state.contact_number,
	}
