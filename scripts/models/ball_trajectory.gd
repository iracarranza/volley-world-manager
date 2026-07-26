class_name BallTrajectory
extends Resource

@export var trajectory_type: String = "ball"
@export var start_position: Vector2 = Vector2.ZERO
@export var control_position: Vector2 = Vector2(0.5, 0.5)
@export var end_position: Vector2 = Vector2.ONE
@export var start_time: float = 0.0
@export var end_time: float = 0.5
@export var outgoing_velocity: Vector2 = Vector2.ZERO
@export var apex_height_meters: float = 1.0


func duration() -> float:
	return maxf(end_time - start_time, 0.01)


func position_at(progress: float) -> Vector2:
	var t := clampf(progress, 0.0, 1.0)
	var inverse := 1.0 - t
	return inverse * inverse * start_position \
		+ 2.0 * inverse * t * control_position \
		+ t * t * end_position


func to_dict() -> Dictionary:
	return {
		"trajectory_type": trajectory_type,
		"start_position": start_position,
		"control_position": control_position,
		"end_position": end_position,
		"start_time": start_time,
		"end_time": end_time,
		"duration": duration(),
		"outgoing_velocity": outgoing_velocity,
		"apex_height_meters": apex_height_meters,
	}


static func create(
	kind: String,
	start: Vector2,
	control: Vector2,
	end: Vector2,
	start_timestamp: float,
	flight_time: float,
	apex_height: float = 1.0,
) -> BallTrajectory:
	var trajectory := BallTrajectory.new()
	trajectory.trajectory_type = kind
	trajectory.start_position = start
	trajectory.control_position = control
	trajectory.end_position = end
	trajectory.start_time = start_timestamp
	trajectory.end_time = start_timestamp + maxf(flight_time, 0.01)
	trajectory.outgoing_velocity = (end - control) / maxf(flight_time * 0.5, 0.01)
	trajectory.apex_height_meters = apex_height
	return trajectory
