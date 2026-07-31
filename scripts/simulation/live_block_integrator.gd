class_name LiveBlockIntegrator
extends RefCounted

## Gate 49: promotes one audited opponent block contact into live rally state.
##
## Mirrors LiveAttackIntegrator, with three differences that come from the
## rules of the sport rather than from the architecture:
##
## 1. The blockers are opponents, so every state lookup uses the opponent side.
## 2. A block touch does not consume one of the blocking team's three contacts.
##    `apply()` therefore resets the contact counter after registering the touch
##    instead of incrementing into it.
## 3. The audit already certified that the primary reaches the ball, so a
##    promoted block can never be a "miss". Outcome is narrowed to a terminal
##    stuff or a deflection the attacking side must play.
##
## Outcome is derived only from the audited candidate's own physical facts --
## closer count, arrival margin, and whether the close required a jump. No RNG,
## no authoritative attack truth, and no perceived blocker state.

const BallTrajectoryModel := preload("res://scripts/models/ball_trajectory.gd")

## A block that both bodies reached, with time to spare and real penetration,
## is the only shape allowed to terminate the rally.
const STUFF_MARGIN_SECONDS: float = 0.06
const NET_Y: float = 0.50


static func apply(state: RallyState, candidate: Dictionary) -> Dictionary:
	var validation := validate(state, candidate)
	if not bool(validation.get("valid", false)):
		return {"applied": false, "reason": str(validation.get(
			"reason", "invalid block candidate"
		))}
	var primary_id := int(candidate.get("primary_id", -1))
	var assist_id := int(candidate.get("assist_id", -1))
	var contact_time := float(candidate.get("contact_time", state.simulation_time))
	var primary_target_x := clampf(float(candidate.get("primary_target_x", 0.5)), 0.0, 1.0)

	var primary := state.player_state(&"opponent", primary_id)
	_seal_blocker(
		primary, primary_target_x, contact_time,
		bool(candidate.get("primary_requires_jump", false)),
	)
	var assist_target_x := primary_target_x
	if assist_id >= 0:
		var assist := state.player_state(&"opponent", assist_id)
		if assist != null:
			assist_target_x = clampf(
				float(candidate.get("assist_target_x", primary_target_x)), 0.0, 1.0
			)
			_seal_blocker(assist, assist_target_x, contact_time, true)

	var outcome := _outcome(candidate)
	state.advance_to(contact_time)
	state.register_contact(&"opponent", primary_id)
	## Rule 14.4.1: a block touch is not counted as one of the team's contacts.
	## register_contact() flipped possession to the blocking side and set the
	## counter to 1; a blocking team still gets three contacts afterwards, so the
	## touch itself must leave the counter at zero.
	state.contact_number = 0
	state.ball.contact_count = 0

	var net_contact := Vector2(primary_target_x, NET_Y)
	var destination := _destination(outcome, primary_target_x)
	var trajectory := BallTrajectoryModel.create(
		"continuous_block",
		net_contact,
		net_contact.lerp(destination, 0.5),
		destination,
		contact_time,
		0.22 if outcome == "stuff" else 0.30,
		0.18 if outcome == "stuff" else 0.38,
		float(candidate.get("contact_height_meters", 2.55)),
		0.25,
	)
	state.ball.launch(trajectory, &"opponent", primary_id, 0)
	return {
		"applied": true,
		"primary_id": primary_id,
		"assist_id": assist_id,
		"closer_count": int(candidate.get("closer_count", 0)),
		"outcome": outcome,
		"terminal": outcome == "stuff",
		"primary_target_x": primary_target_x,
		"assist_target_x": assist_target_x,
		"primary_body_state": RallyPlayerState.BodyState.keys()[primary.body_state],
		"contact_height_meters": float(candidate.get("contact_height_meters", 0.0)),
		"contact_number": state.contact_number,
		"simulation_time": state.simulation_time,
		"ball_status": RallyBallState.Status.keys()[state.ball.status],
		"ball_origin": trajectory.start_position,
		"ball_destination": trajectory.end_position,
		"ball_start_time": trajectory.start_time,
		"ball_end_time": trajectory.end_time,
		"deflection_target": destination,
	}


static func validate(state: RallyState, candidate: Dictionary) -> Dictionary:
	if state == null or candidate.is_empty():
		return {"valid": false, "reason": "missing state or block candidate"}
	## A block only exists in response to a third-contact attack from the other
	## side. Anything else means the chain above this gate did not hold.
	if state.ball.last_touch_side != &"home" or state.contact_number != 3:
		return {"valid": false, "reason": "no home attack to block"}
	var primary_id := int(candidate.get("primary_id", -1))
	if primary_id < 0:
		return {"valid": false, "reason": "no primary blocker resolved"}
	if state.player_state(&"opponent", primary_id) == null:
		return {"valid": false, "reason": "primary blocker missing from state"}
	var assist_id := int(candidate.get("assist_id", -1))
	if assist_id >= 0 and state.player_state(&"opponent", assist_id) == null:
		return {"valid": false, "reason": "assist blocker missing from state"}
	if float(candidate.get("contact_time", -1.0)) < state.simulation_time:
		return {"valid": false, "reason": "block precedes the attack contact"}
	if float(candidate.get("contact_height_meters", 0.0)) <= 0.0:
		return {"valid": false, "reason": "block contact height missing"}
	return {"valid": true, "reason": ""}


## Terminal only when both bodies got there with time to spare over the net.
## Everything else is a touch the attacking side must dig.
static func _outcome(candidate: Dictionary) -> String:
	var sealed := int(candidate.get("closer_count", 0)) >= 2 \
		and bool(candidate.get("primary_requires_jump", false)) \
		and float(candidate.get("primary_arrival_margin", -1.0)) >= STUFF_MARGIN_SECONDS \
		and float(candidate.get("assist_arrival_margin", -1.0)) >= 0.0
	return "stuff" if sealed else "recycle"


static func _destination(outcome: String, target_x: float) -> Vector2:
	## A stuff lands on the attacking side's floor; a deflection drops into the
	## attacking side's coverage where their own players must play it.
	return Vector2(target_x, 0.62) if outcome == "stuff" \
		else Vector2(clampf(target_x, 0.12, 0.88), 0.72)


static func _seal_blocker(
	blocker: RallyPlayerState,
	target_x: float,
	contact_time: float,
	airborne: bool,
) -> void:
	if blocker == null:
		return
	var sealed_position := Vector2(target_x, NET_Y - 0.04)
	blocker.apply_position(sealed_position, Vector2.ZERO)
	blocker.body_state = RallyPlayerState.BodyState.AIRBORNE if airborne \
		else RallyPlayerState.BodyState.REACHING
	blocker.last_contact_time = contact_time
	## Landing from a block is the most expensive recovery a front-row player
	## makes; they cannot transition to attack until they are back on balance.
	blocker.recovery_until = contact_time + (0.36 if airborne else 0.20)
	blocker.committed_until = blocker.recovery_until
	blocker.intent = &"recover"
	blocker.intent_target = sealed_position
	blocker.movement_mode = RallyPlayerState.MovementMode.BLOCK_CLOSE
