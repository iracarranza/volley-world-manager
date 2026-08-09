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
@export var start_height_meters: float = 1.0
@export var end_height_meters: float = 1.0


func duration() -> float:
	return maxf(end_time - start_time, 0.01)


func position_at(progress: float) -> Vector2:
	var t := clampf(progress, 0.0, 1.0)
	var inverse := 1.0 - t
	return inverse * inverse * start_position \
		+ 2.0 * inverse * t * control_position \
		+ t * t * end_position


func progress_at_time(simulation_time: float) -> float:
	return clampf(
		(simulation_time - start_time) / duration(),
		0.0,
		1.0,
	)


func position_at_time(simulation_time: float) -> Vector2:
	return position_at(progress_at_time(simulation_time))


func velocity_at_progress(progress: float) -> Vector2:
	var t := clampf(progress, 0.0, 1.0)
	var derivative := 2.0 * (1.0 - t) * (
		control_position - start_position
	) + 2.0 * t * (
		end_position - control_position
	)
	return derivative / duration()


func velocity_at_time(simulation_time: float) -> Vector2:
	return velocity_at_progress(progress_at_time(simulation_time))


## Where the ball is vertically, from gravity and the two contacts it is between.
##
## `apex_height_meters` is deliberately not read here any more. It used to be the
## input that set the shape of a symmetric hump; it is now a *reported* figure
## that presentation and calibration can inspect, and the drawn curve is the one
## parabola the two contact heights and the flight time already determine. The
## reasoning, and the measurement that forced it, are in
## `BallFlightModel.height_between`.
func height_at_progress(progress: float) -> float:
	return BallFlightModel.height_between(
		start_height_meters, end_height_meters, duration(), progress
	)


func height_at_time(simulation_time: float) -> float:
	return height_at_progress(progress_at_time(simulation_time))


func is_active_at(simulation_time: float) -> bool:
	return simulation_time >= start_time and simulation_time <= end_time


func time_remaining(simulation_time: float) -> float:
	return maxf(end_time - simulation_time, 0.0)


func earliest_contact_time(
	from_time: float,
	minimum_height: float,
	maximum_height: float,
	sample_count: int = 24,
	descending_only: bool = true,
) -> float:
	var first_time := maxf(from_time, start_time)
	var safe_samples := maxi(sample_count, 1)
	for index in range(safe_samples + 1):
		var ratio := float(index) / float(safe_samples)
		var candidate_time := lerpf(first_time, end_time, ratio)
		var progress := progress_at_time(candidate_time)
		if descending_only and progress < 0.5:
			continue
		var height := height_at_progress(progress)
		if height >= minimum_height and height <= maximum_height:
			return candidate_time
	return -1.0


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
		"start_height_meters": start_height_meters,
		"end_height_meters": end_height_meters,
	}


static func create(
	kind: String,
	start: Vector2,
	control: Vector2,
	end: Vector2,
	start_timestamp: float,
	flight_time: float,
	apex_height: float = 1.0,
	start_height: float = 1.0,
	end_height: float = 1.0,
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
	trajectory.start_height_meters = start_height
	trajectory.end_height_meters = end_height
	return trajectory
