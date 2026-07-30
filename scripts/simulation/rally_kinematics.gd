class_name RallyKinematics
extends RefCounted

## Shared unit conversions for calculated rally timing. This class does not
## simulate aerodynamics or mutate rally state.
const COURT_WIDTH_METERS: float = 9.0
const COURT_LENGTH_METERS: float = 18.0
const MIN_BALL_SPEED_MPS: float = 0.1
const MIN_FLIGHT_DURATION: float = 0.01
const DEFAULT_TIMING_TOLERANCE: float = 0.25


static func court_delta_meters(start: Vector2, end: Vector2) -> Vector2:
	return Vector2(
		(end.x - start.x) * COURT_WIDTH_METERS,
		(end.y - start.y) * COURT_LENGTH_METERS,
	)


static func court_distance_meters(start: Vector2, end: Vector2) -> float:
	return court_delta_meters(start, end).length()


## Converts a vertical launch angle into a simple path-length multiplier.
## This is geometric bookkeeping, not an aerodynamic trajectory model.
static func path_length_factor(vertical_angle_degrees: float) -> float:
	var horizontal_fraction := absf(cos(deg_to_rad(clampf(
		vertical_angle_degrees, -60.0, 60.0
	))))
	return clampf(1.0 / maxf(horizontal_fraction, 0.74), 1.0, 1.35)


static func flight_duration(
	distance_meters: float,
	speed_mps: float,
	path_factor: float = 1.0,
) -> float:
	return maxf(
		maxf(distance_meters, 0.0) * maxf(path_factor, 1.0)
			/ maxf(speed_mps, MIN_BALL_SPEED_MPS),
		MIN_FLIGHT_DURATION,
	)


static func effective_speed(
	distance_meters: float,
	duration_seconds: float,
	path_factor: float = 1.0,
) -> float:
	return maxf(distance_meters, 0.0) * maxf(path_factor, 1.0) \
		/ maxf(duration_seconds, MIN_FLIGHT_DURATION)


## Compares an existing recorded duration with the duration implied by the
## same distance and contact speed. It intentionally does not alter either.
static func timing_diagnostics(
	start: Vector2,
	end: Vector2,
	speed_mps: float,
	recorded_duration: float,
	vertical_angle_degrees: float = 0.0,
	tolerance: float = DEFAULT_TIMING_TOLERANCE,
) -> Dictionary:
	var distance := court_distance_meters(start, end)
	var factor := path_length_factor(vertical_angle_degrees)
	var implied := flight_duration(distance, speed_mps, factor)
	var safe_recorded := maxf(recorded_duration, MIN_FLIGHT_DURATION)
	var delta := safe_recorded - implied
	var relative_error := absf(delta) / maxf(implied, MIN_FLIGHT_DURATION)
	return {
		"distance_meters": distance,
		"signature_speed_mps": maxf(speed_mps, 0.0),
		"recorded_duration_seconds": safe_recorded,
		"path_length_factor": factor,
		"implied_duration_seconds": implied,
		"effective_recorded_speed_mps": effective_speed(
			distance, safe_recorded, factor
		),
		"duration_delta_seconds": delta,
		"relative_duration_error": relative_error,
		"tolerance": maxf(tolerance, 0.0),
		"within_tolerance": relative_error <= maxf(tolerance, 0.0),
	}
