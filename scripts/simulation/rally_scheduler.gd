class_name RallyScheduler
extends RefCounted

var pending: Array[RallyMoment] = []


func schedule(moment: RallyMoment) -> void:
	if moment == null:
		return
	pending.append(moment)
	pending.sort_custom(_moment_precedes)


func next() -> RallyMoment:
	return pending.pop_front() if not pending.is_empty() else null


func peek_time() -> float:
	return pending[0].time if not pending.is_empty() else INF


func clear() -> void:
	pending.clear()


func cancel_player_moments(
	side: StringName,
	player_id: int,
	after_time: float,
) -> void:
	var retained: Array[RallyMoment] = []
	for moment in pending:
		var should_cancel := moment.side == side \
			and moment.player_id == player_id \
			and moment.time >= after_time
		if not should_cancel:
			retained.append(moment)
	pending = retained


func schedule_ball_flight(state: RallyState) -> void:
	if state == null or state.ball.trajectory == null:
		return
	var trajectory := state.ball.trajectory
	schedule(RallyMoment.create(
		trajectory.start_time + 0.05,
		RallyMoment.Kind.PERCEPTION,
	))
	schedule(RallyMoment.create(
		trajectory.end_time,
		RallyMoment.Kind.BALL_CONTACT,
	))
	schedule(RallyMoment.create(
		trajectory.end_time + 0.01,
		RallyMoment.Kind.BALL_LANDING,
	))


static func _moment_precedes(a: RallyMoment, b: RallyMoment) -> bool:
	if is_equal_approx(a.time, b.time):
		return a.kind < b.kind
	return a.time < b.time
