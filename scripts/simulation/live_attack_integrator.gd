class_name LiveAttackIntegrator
extends RefCounted

const BallTrajectoryModel := preload("res://scripts/models/ball_trajectory.gd")


static func apply(state: RallyState, candidate: Dictionary) -> Dictionary:
	var validation := validate(state, candidate)
	if not bool(validation.get("valid", false)):
		return {"applied": false, "reason": str(validation.get(
			"reason", "invalid attack candidate"
		))}
	var hitter_id := int(candidate.get("actor_id", -1))
	var hitter := state.player_state(&"home", hitter_id)
	var contact_time := float(candidate.get("contact_time", -1.0))
	var center := Vector2(candidate.get("center_position", hitter.position))
	hitter.apply_position(center, Vector2(candidate.get(
		"velocity_mps", Vector2.ZERO
	)))
	hitter.body_state = RallyPlayerState.BodyState.AIRBORNE \
		if bool(candidate.get("requires_jump", false)) \
		else RallyPlayerState.BodyState.REACHING
	hitter.balance = clampf(float(candidate.get("arrival_balance", 0.5)), 0.0, 1.0)
	hitter.last_contact_time = contact_time
	hitter.recovery_until = contact_time + (0.34 \
		if hitter.body_state == RallyPlayerState.BodyState.AIRBORNE else 0.18)
	hitter.committed_until = hitter.recovery_until
	hitter.intent = &"recover"
	hitter.intent_target = center
	hitter.movement_mode = RallyPlayerState.MovementMode.RECOVERY
	state.advance_to(contact_time)
	state.register_contact(&"home", hitter_id)
	var trajectory_data: Dictionary = candidate.get("attack_trajectory", {})
	var trajectory := BallTrajectoryModel.create(
		str(trajectory_data.get("trajectory_type", "continuous_attack")),
		Vector2(trajectory_data.get("start_position", Vector2.ZERO)),
		Vector2(trajectory_data.get("control_position", Vector2(0.5, 0.5))),
		Vector2(trajectory_data.get("end_position", Vector2.ONE)),
		float(trajectory_data.get("start_time", contact_time)),
		float(trajectory_data.get("duration", 0.01)),
		float(trajectory_data.get("apex_height_meters", 0.65)),
		float(trajectory_data.get("start_height_meters", 2.55)),
		float(trajectory_data.get("end_height_meters", 0.25)),
	)
	state.ball.launch(trajectory, &"home", hitter_id, 3)
	return {
		"applied": true,
		"hitter_id": hitter_id,
		"selected_action": str(candidate.get("selected_action", "")),
		"hitter_center_position": hitter.position,
		"hitter_contact_position": Vector2(candidate.get(
			"contact_position", trajectory.start_position
		)),
		"hitter_body_state": RallyPlayerState.BodyState.keys()[hitter.body_state],
		"hitter_balance": hitter.balance,
		"hitter_recovery_until": hitter.recovery_until,
		"simulation_time": state.simulation_time,
		"contact_number": state.contact_number,
		"ball_status": RallyBallState.Status.keys()[state.ball.status],
		"ball_origin": trajectory.start_position,
		"ball_destination": trajectory.end_position,
		"ball_start_time": trajectory.start_time,
		"ball_end_time": trajectory.end_time,
		"observation_fingerprint": str(candidate.get(
			"observation_fingerprint", ""
		)),
	}


static func validate(state: RallyState, candidate: Dictionary) -> Dictionary:
	if state == null or candidate.is_empty():
		return {"valid": false, "reason": "missing state or attack candidate"}
	if state.contact_number != 2 or state.ball.last_touch_side != &"home":
		return {"valid": false, "reason": "setter state not established"}
	var hitter_id := int(candidate.get("actor_id", -1))
	if state.player_state(&"home", hitter_id) == null:
		return {"valid": false, "reason": "hitter missing from state"}
	if float(candidate.get("contact_time", -1.0)) < state.simulation_time:
		return {"valid": false, "reason": "attack precedes setter contact"}
	if Dictionary(candidate.get("attack_trajectory", {})).is_empty():
		return {"valid": false, "reason": "attack trajectory missing"}
	return {"valid": true, "reason": ""}
