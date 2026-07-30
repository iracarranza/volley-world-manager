class_name RallyBallState
extends RefCounted

enum Status {
	DEAD,
	HELD_FOR_SERVE,
	IN_FLIGHT,
	CONTACT_WINDOW,
	LANDED,
	OUT,
}

var status: Status = Status.DEAD
var trajectory: BallTrajectory
var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var height_meters: float = 0.0

var predicted_landing: Vector2 = Vector2.ZERO
var predicted_landing_time: float = 0.0

var last_touch_side: StringName = &""
var last_touch_player_id: int = -1
var contact_count: int = 0


func launch(
	new_trajectory: BallTrajectory,
	touch_side: StringName,
	touch_player_id: int,
	new_contact_count: int,
) -> void:
	trajectory = new_trajectory
	status = Status.IN_FLIGHT
	last_touch_side = touch_side
	last_touch_player_id = touch_player_id
	contact_count = new_contact_count
	predicted_landing = trajectory.end_position
	predicted_landing_time = trajectory.end_time
	update_at(trajectory.start_time)


func update_at(simulation_time: float) -> void:
	if trajectory == null:
		return
	position = trajectory.position_at_time(simulation_time)
	velocity = trajectory.velocity_at_time(simulation_time)
	height_meters = trajectory.height_at_time(simulation_time)
	if simulation_time >= trajectory.end_time:
		position = trajectory.end_position
		height_meters = trajectory.end_height_meters
		status = Status.CONTACT_WINDOW


func clear() -> void:
	status = Status.DEAD
	trajectory = null
	velocity = Vector2.ZERO
	height_meters = 0.0
	contact_count = 0


func snapshot() -> RallyBallState:
	var copy := RallyBallState.new()
	copy.status = status
	copy.trajectory = trajectory
	copy.position = position
	copy.velocity = velocity
	copy.height_meters = height_meters
	copy.predicted_landing = predicted_landing
	copy.predicted_landing_time = predicted_landing_time
	copy.last_touch_side = last_touch_side
	copy.last_touch_player_id = last_touch_player_id
	copy.contact_count = contact_count
	return copy
