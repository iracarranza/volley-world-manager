class_name RallyKinematics
extends RefCounted

## Shared unit conversions for calculated rally timing. This class does not
## simulate aerodynamics or mutate rally state.
## Court geometry belongs to `CourtConstants`, which is where every other
## consumer reads it. Re-declaring the numbers here meant a court that changed
## size would silently change it in one place and not the other.
const BallFlightModel := preload("res://scripts/simulation/ball_flight_model.gd")
const COURT_WIDTH_METERS: float = CourtConstants.COURT_WIDTH_METERS
const COURT_LENGTH_METERS: float = CourtConstants.COURT_LENGTH_METERS
const MIN_BALL_SPEED_MPS: float = 0.1
const MIN_FLIGHT_DURATION: float = 0.01
const DEFAULT_TIMING_TOLERANCE: float = 0.25
## Read from the physics module rather than redeclared. It was 9.8 here, 9.8 in
## `BallFlightModel`, 9.81 in `BlockJumpModel` and a fourth private copy inside
## the ball-flight test -- one physical constant, four declarations, two values.
const DEFAULT_GRAVITY_MPS2: float = BallFlightModel.DEFAULT_GRAVITY_MPS2
## Deliberately tighter than `BallFlightModel.MAX_LAUNCH_ANGLE_DEGREES`, which
## allows 85. That module resolves a launch from three metres up and reads the
## outcome off where the ball lands; this one solves a drawn ground-to-ground arc,
## where the apex is the thing that has to stay believable. Two bounds, two
## purposes -- said out loud here because neither file previously acknowledged the
## other, and a reader of one would have taken it for the bound.
##
## Below this, a shot is flat enough that tan(theta) collapses toward zero and
## the required speed toward the distance/duration floor; above the max, apex
## height blows up implausibly at real court distances (an unclamped 80 degree
## shot over 9m implies a ~12.8m apex). Both bounds keep every derived value
## finite and keep the shape of the arc inside what a volleyball rally
## actually produces.
const MIN_LAUNCH_ANGLE_DEGREES: float = 2.0
const MAX_LAUNCH_ANGLE_DEGREES: float = 75.0


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


## Solves standard projectile motion (launched and landing at equal height, no
## drag) for the flight duration and apex height a shot needs to cover the
## given distance at the given launch angle. The launch angle is the only free
## "shot shape" input; the resulting speed is always exactly what the geometry
## requires to land on the known target -- that is what makes this force
## derived rather than a chosen duration. Distance and angle are cleared and
## clamped so no combination this is called with can produce NaN or Inf.
##
## v = sqrt(R*g / sin(2*theta))
## T = sqrt(2*R*tan(theta) / g)
## h = (R/4) * tan(theta)
static func solve_launch_arc(
	distance_meters: float,
	launch_angle_degrees: float,
	gravity_mps2: float = DEFAULT_GRAVITY_MPS2,
) -> Dictionary:
	var distance := maxf(distance_meters, 0.0)
	var gravity := maxf(gravity_mps2, 0.1)
	var angle := clampf(
		launch_angle_degrees, MIN_LAUNCH_ANGLE_DEGREES, MAX_LAUNCH_ANGLE_DEGREES
	)
	if distance <= 0.0001:
		return {
			"duration_seconds": MIN_FLIGHT_DURATION,
			"apex_height_meters": 0.0,
			"required_speed_mps": MIN_BALL_SPEED_MPS,
			"launch_angle_degrees": angle,
		}
	var radians := deg_to_rad(angle)
	var tangent := tan(radians)
	var duration := sqrt(2.0 * distance * tangent / gravity)
	var apex := (distance / 4.0) * tangent
	var speed := sqrt(distance * gravity / sin(2.0 * radians))
	return {
		"duration_seconds": maxf(duration, MIN_FLIGHT_DURATION),
		"apex_height_meters": maxf(apex, 0.0),
		"required_speed_mps": maxf(speed, MIN_BALL_SPEED_MPS),
		"launch_angle_degrees": angle,
	}


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
