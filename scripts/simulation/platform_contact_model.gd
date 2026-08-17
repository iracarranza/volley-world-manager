class_name PlatformContactModel
extends RefCounted

## One shared forearm-contact envelope and execution model.
##
## CATEGORY-3 GAME ABSTRACTION. The six calibration values below are authored
## openly for plausible volleyball behaviour. They are not measured biomechanics
## and must not be cited as such. The measurement protocol in
## `PLATFORM_PHYSICS_AUTHORITY_BOUNDARY.md` remains the route for replacing or
## validating them later.
##
## This class is production-inert while M4 slice 2 is in shadow. It consumes
## ground-truth ball/body facts and an already-compiled intent. It does not read
## event type, result labels, old apex/spoil bands, or team side.

const BallFlight := preload("res://scripts/simulation/ball_flight_model.gd")
const BallTrajectory := preload("res://scripts/models/ball_trajectory.gd")

## T1: available outgoing pace.
##
## A neutral platform can carry three tenths of the incoming contact speed into
## its available outgoing-speed ceiling. A stable body may add up to 6.5 m/s by
## driving through the contact; circumstance and the supplied stability ability
## scale only that active contribution. Positive body motion along the natural
## rebound direction contributes at its already-derived physical speed, 1:1.
const PACE_RETENTION: float = 0.30
const ACTIVE_GENERATION_MPS: float = 6.5

## T2: the shared reachable-redirection cone.
##
## The cone is centred on `-incoming_velocity`: the ball's natural rebound
## direction, derived from the ball rather than the intent. A fully available
## body may redirect 65 degrees from that line. Circumstance can remove at most
## 82% of that angular freedom, leaving a narrow but non-zero 11.7-degree cone at
## full stretch. The same transform applies to reception, dig and eventually
## coverage; no event family owns a band.
const PLANTED_REDIRECTION_HALF_ANGLE_DEGREES: float = 65.0
const MAX_CIRCUMSTANCE_NARROWING_SHARE: float = 0.82

## T3: one angular execution distribution.
##
## Technique maps monotonically between these endpoints. The realised direction
## is projected back into T2, so poor execution cannot manufacture a physically
## unreachable launch. The approximate 3.4-degree aggregate spread reported in
## the evidence review is only a plausibility cross-check; it does not derive
## either endpoint or their slope.
const WEAK_TECHNIQUE_SIGMA_DEGREES: float = 7.0
const ELITE_TECHNIQUE_SIGMA_DEGREES: float = 1.5

## Numerical resolution only. This does not describe a body or a ball and must
## never be tuned for outcomes. The selector searches a physically derived time
## interval and refines the earliest exact candidate after this coarse pass.
const SEARCH_SAMPLES: int = 241
const REFINE_STEPS: int = 18
const NUMERICAL_EPSILON: float = 0.00001


## The arriving velocity at the contact end of a published trajectory. This is
## derived, not calibrated. A resolver-owned launch vertical is advanced under
## gravity; otherwise both contact heights must be explicitly resolved. Default
## endpoint heights are not silently promoted into physical truth.
static func incoming_velocity_at_contact(
	trajectory_data: Dictionary, resolved_contact_height_meters: float = NAN
) -> Dictionary:
	return _trajectory_velocity(
		trajectory_data, true, resolved_contact_height_meters
	)


## The launch velocity at the first contact of a published trajectory. Used to
## compare the legacy outgoing ball with the shadow envelope; it does not make
## the legacy ball an input to the shadow.
static func outgoing_velocity_at_launch(trajectory_data: Dictionary) -> Dictionary:
	return _trajectory_velocity(trajectory_data, false, NAN)


static func _trajectory_velocity(
	trajectory_data: Dictionary,
	at_end: bool,
	resolved_contact_height_meters: float,
) -> Dictionary:
	if trajectory_data.is_empty() \
			or float(trajectory_data.get("duration", 0.0)) <= 0.0:
		return {"available": false, "reason": "missing trajectory"}
	var trajectory: Resource = BallTrajectory.from_dict(trajectory_data)
	var normalized_ground: Vector2 = trajectory.velocity_at_progress(
		1.0 if at_end else 0.0
	)
	var ground := Vector2(
		normalized_ground.x * CourtConstants.COURT_WIDTH_METERS,
		normalized_ground.y * CourtConstants.COURT_LENGTH_METERS,
	)
	var duration := float(trajectory_data.get("duration", 0.0))
	var vertical := NAN
	var source := "missing"
	if trajectory_data.has("launch_vertical_mps"):
		vertical = float(trajectory_data.launch_vertical_mps)
		if at_end:
			vertical -= float(trajectory_data.get(
				"launch_gravity_mps2", BallFlight.DEFAULT_GRAVITY_MPS2
			)) * duration
		source = "resolver_launch"
	elif str(trajectory_data.get("height_source", "default")) == "resolved":
		vertical = BallFlight.rise_speed_between(
			float(trajectory_data.get("start_height_meters", 1.0)),
			float(trajectory_data.get("end_height_meters", 1.0)), duration,
		)
		if at_end:
			vertical -= BallFlight.DEFAULT_GRAVITY_MPS2 * duration
		source = "resolved_contact_heights"
	elif at_end and trajectory_data.has("launch_contact_height_meters") \
			and not is_nan(resolved_contact_height_meters) \
			and resolved_contact_height_meters > 0.0:
		## A playable block deflection deliberately does not stamp a floor-flight
		## launch component: its endpoint is another voli's arms. The block contact
		## owns its starting height, and this platform contact owns the ending
		## height, so together they derive the missing vertical without changing the
		## legacy trajectory or treating its 1 m display defaults as physical.
		vertical = BallFlight.rise_speed_between(
			float(trajectory_data.launch_contact_height_meters),
			resolved_contact_height_meters, duration,
		) - BallFlight.DEFAULT_GRAVITY_MPS2 * duration
		source = "adjacent_contact_heights"
	if is_nan(vertical):
		return {
			"available": false,
			"reason": "unowned vertical state",
			"horizontal_velocity_mps": ground,
		}
	var velocity := Vector3(ground.x, vertical, ground.y)
	return {
		"available": true,
		"velocity_mps": velocity,
		"speed_mps": velocity.length(),
		"source": source,
	}


## Evaluate one contact in shadow.
##
## Required inputs:
## - incoming_velocity_mps: Vector3, court x / vertical / court y at contact
## - contact_position: Vector2 normalized court coordinate
## - contact_height_meters: float
## - intent_target_anchor: Vector2
## - intent_height_anchor_meters: float
##
## Optional inputs:
## - body_velocity_mps: Vector2 in court metres/second
## - circumstance_severity: derived 0..1 body/contact constraint
## - stability_ability: 0..1, active-generation authority
## - technique_ability: 0..1, angular-execution authority
## - intent_arrival_floor_seconds: derived lower bound, default 0
## - seed: deterministic execution draw
static func evaluate(inputs: Dictionary) -> Dictionary:
	var incoming := Vector3(inputs.get("incoming_velocity_mps", Vector3.ZERO))
	var contact := Vector2(inputs.get("contact_position", Vector2.ZERO))
	var contact_height := maxf(float(inputs.get(
		"contact_height_meters", 0.0
	)), 0.0)
	if incoming.length() <= NUMERICAL_EPSILON or contact_height <= 0.0:
		return {"available": false, "reason": "missing physical contact state"}

	var severity := clampf(float(inputs.get("circumstance_severity", 0.0)), 0.0, 1.0)
	var stability := clampf(float(inputs.get("stability_ability", 0.5)), 0.0, 1.0)
	var technique := clampf(float(inputs.get("technique_ability", 0.5)), 0.0, 1.0)
	var natural := (-incoming).normalized()
	## A body loses drive progressively, not at the first step away from planted.
	## The square root is a parameter-free shape: zero and one stay exact, while
	## an ordinary moving contact retains useful active generation.
	var generation_freedom := sqrt(1.0 - severity)
	## Narrowing is likewise late-binding. Squaring a dimensionless reach
	## severity preserves the full authored cone at zero and the authored minimum
	## at one without adding a midpoint or posture table.
	var narrowing_severity := severity * severity
	var half_angle_degrees := PLANTED_REDIRECTION_HALF_ANGLE_DEGREES * (
		1.0 - MAX_CIRCUMSTANCE_NARROWING_SHARE * narrowing_severity
	)
	var body_velocity := Vector2(inputs.get("body_velocity_mps", Vector2.ZERO))
	var natural_horizontal := Vector2(natural.x, natural.z).normalized()
	var body_contribution := maxf(body_velocity.dot(natural_horizontal), 0.0) \
		if natural_horizontal.length_squared() > NUMERICAL_EPSILON else 0.0
	var retained_speed := incoming.length() * PACE_RETENTION
	var generated_speed := ACTIVE_GENERATION_MPS * stability * generation_freedom \
		+ body_contribution
	var speed_ceiling := maxf(
		retained_speed + generated_speed, BallFlight.MIN_SPEED_MPS
	)
	var envelope := {
		"available": true,
		"natural_direction": natural,
		"incoming_speed_mps": incoming.length(),
		"retained_speed_mps": retained_speed,
		"active_generated_speed_mps": generated_speed,
		"body_velocity_contribution_mps": body_contribution,
		"maximum_outgoing_speed_mps": speed_ceiling,
		"circumstance_severity": severity,
		"redirection_half_angle_degrees": half_angle_degrees,
		"technique_sigma_degrees": lerpf(
			WEAK_TECHNIQUE_SIGMA_DEGREES,
			ELITE_TECHNIQUE_SIGMA_DEGREES,
			technique,
		),
	}

	var target_value: Variant = inputs.get("intent_target_anchor", null)
	var height_value: Variant = inputs.get("intent_height_anchor_meters", null)
	if not target_value is Vector2 or not _is_number(height_value):
		envelope["selection_available"] = false
		envelope["reason"] = "intent underconstrained"
		return envelope
	var height_anchor := float(height_value)
	if height_anchor <= 0.0:
		envelope["selection_available"] = false
		envelope["reason"] = "intent underconstrained"
		return envelope

	var selection := _select_launch(
		contact, contact_height, target_value, height_anchor,
		maxf(float(inputs.get("intent_arrival_floor_seconds", 0.0)), 0.0),
		natural, half_angle_degrees, speed_ceiling,
	)
	for key in selection:
		envelope[key] = selection[key]
	if not bool(selection.get("selection_available", false)):
		return envelope

	var selected_velocity := Vector3(selection.selected_velocity_mps)
	var realised_direction := _execute_direction(
		selected_velocity.normalized(), natural, half_angle_degrees,
		float(envelope.technique_sigma_degrees), int(inputs.get("seed", 0)),
	)
	var realised_velocity := realised_direction * selected_velocity.length()
	var realised := _launch_record(
		contact, contact_height, realised_velocity,
		Vector2(target_value), height_anchor,
		maxf(float(inputs.get("intent_arrival_floor_seconds", 0.0)), 0.0),
	)
	envelope["realised_velocity_mps"] = realised_velocity
	envelope["realised_speed_mps"] = realised_velocity.length()
	envelope["realised_direction"] = realised_direction
	envelope["execution_error_degrees"] = rad_to_deg(
		selected_velocity.normalized().angle_to(realised_direction)
	)
	envelope["realised"] = realised
	return envelope


## Minimal, weight-free selection from §4a: satisfy the arrival floor; minimise
## three-dimensional miss from the horizontal/height anchors; break ties toward
## the earlier ball. Horizontal and vertical miss share metres, so no conversion
## weight is introduced.
static func _select_launch(
	contact: Vector2,
	contact_height: float,
	target: Vector2,
	height_anchor: float,
	arrival_floor: float,
	natural: Vector3,
	half_angle_degrees: float,
	speed_ceiling: float,
) -> Dictionary:
	var delta := _court_delta(contact, target)
	var distance := delta.length()
	if distance <= NUMERICAL_EPSILON:
		return {"selection_available": false, "reason": "target at contact"}
	var shortest_time := maxf(
		arrival_floor, distance / maxf(speed_ceiling, BallFlight.MIN_SPEED_MPS)
	)
	var longest_time := maxf(
		shortest_time,
		float(BallFlight.solve_flight(
			speed_ceiling, BallFlight.MAX_LAUNCH_ANGLE_DEGREES, contact_height
		).duration_seconds),
	)
	var best := {}
	var first_exact := {}
	var previous_time := shortest_time
	var previous_exact := false
	for index in range(SEARCH_SAMPLES):
		var share := float(index) / float(maxi(SEARCH_SAMPLES - 1, 1))
		var duration := lerpf(shortest_time, longest_time, share)
		var candidate := _candidate_for_duration(
			contact, contact_height, target, height_anchor, arrival_floor,
			natural, half_angle_degrees, speed_ceiling, duration,
		)
		if candidate.is_empty():
			continue
		if bool(candidate.exact_intent):
			if not previous_exact and index > 0:
				candidate = _refine_first_exact(
					contact, contact_height, target, height_anchor, arrival_floor,
					natural, half_angle_degrees, speed_ceiling,
					previous_time, duration,
				)
			first_exact = candidate
			break
		if _prefer(candidate, best):
			best = candidate
		previous_time = duration
		previous_exact = bool(candidate.exact_intent)
	var selected := first_exact if not first_exact.is_empty() else best
	if selected.is_empty():
		return {"selection_available": false, "reason": "no forward launch"}
	selected["selection_available"] = true
	selected["intent_satisfiable"] = not first_exact.is_empty()
	selected["binding_constraint"] = "none" if not first_exact.is_empty() \
		else _binding_constraint(selected)
	return selected


static func _candidate_for_duration(
	contact: Vector2,
	contact_height: float,
	target: Vector2,
	height_anchor: float,
	arrival_floor: float,
	natural: Vector3,
	half_angle_degrees: float,
	speed_ceiling: float,
	duration: float,
) -> Dictionary:
	var safe_duration := maxf(duration, BallFlight.MIN_FLIGHT_DURATION)
	var delta := _court_delta(contact, target)
	var vertical := (
		height_anchor - contact_height
		+ 0.5 * BallFlight.DEFAULT_GRAVITY_MPS2 * safe_duration * safe_duration
	) / safe_duration
	var desired_velocity := Vector3(
		delta.x / safe_duration, vertical, delta.y / safe_duration
	)
	var desired_speed := desired_velocity.length()
	if desired_speed <= NUMERICAL_EPSILON:
		return {}
	var projected_direction := _project_feasible_direction(
		desired_velocity.normalized(), natural, half_angle_degrees
	)
	var selected_speed := minf(desired_speed, speed_ceiling)
	var selected_velocity := projected_direction * selected_speed
	var record := _launch_record(
		contact, contact_height, selected_velocity, target, height_anchor,
		arrival_floor,
	)
	var angular_demand := rad_to_deg(
		natural.angle_to(desired_velocity.normalized())
	)
	var angle_limited := angular_demand > half_angle_degrees + 0.0001
	var speed_limited := desired_speed > speed_ceiling + 0.0001
	var exact := not angle_limited and not speed_limited \
		and bool(record.forward) and bool(record.arrival_floor_satisfied)
	return {
		"selected_velocity_mps": selected_velocity,
		"selected_speed_mps": selected_speed,
		"selected_direction": projected_direction,
		"selected_duration_seconds": safe_duration,
		"desired_speed_mps": desired_speed,
		"angular_demand_degrees": angular_demand,
		"angle_limited": angle_limited,
		"speed_limited": speed_limited,
		"exact_intent": exact,
		"selected": record,
		"spatial_error_meters": float(record.spatial_error_meters),
		"arrival_shortfall_seconds": float(record.arrival_shortfall_seconds),
		"arrival_floor_satisfied": bool(record.arrival_floor_satisfied),
	}


static func _refine_first_exact(
	contact: Vector2,
	contact_height: float,
	target: Vector2,
	height_anchor: float,
	arrival_floor: float,
	natural: Vector3,
	half_angle_degrees: float,
	speed_ceiling: float,
	low_time: float,
	high_time: float,
) -> Dictionary:
	var low := low_time
	var high := high_time
	var candidate := {}
	for _step in range(REFINE_STEPS):
		var middle := (low + high) * 0.5
		var trial := _candidate_for_duration(
			contact, contact_height, target, height_anchor, arrival_floor,
			natural, half_angle_degrees, speed_ceiling, middle,
		)
		if not trial.is_empty() and bool(trial.exact_intent):
			candidate = trial
			high = middle
		else:
			low = middle
	return candidate if not candidate.is_empty() else _candidate_for_duration(
		contact, contact_height, target, height_anchor, arrival_floor,
		natural, half_angle_degrees, speed_ceiling, high,
	)


static func _prefer(candidate: Dictionary, incumbent: Dictionary) -> bool:
	if incumbent.is_empty():
		return true
	var candidate_floor := bool(candidate.arrival_floor_satisfied)
	var incumbent_floor := bool(incumbent.arrival_floor_satisfied)
	if candidate_floor != incumbent_floor:
		return candidate_floor
	if not candidate_floor:
		var candidate_short := float(candidate.arrival_shortfall_seconds)
		var incumbent_short := float(incumbent.arrival_shortfall_seconds)
		if not is_equal_approx(candidate_short, incumbent_short):
			return candidate_short < incumbent_short
	var candidate_error := float(candidate.spatial_error_meters)
	var incumbent_error := float(incumbent.spatial_error_meters)
	if not is_equal_approx(candidate_error, incumbent_error):
		return candidate_error < incumbent_error
	return float(candidate.selected_duration_seconds) \
		< float(incumbent.selected_duration_seconds)


static func _binding_constraint(candidate: Dictionary) -> String:
	if not bool(candidate.arrival_floor_satisfied):
		return "arrival_floor"
	if bool(candidate.angle_limited) and bool(candidate.speed_limited):
		return "redirection_and_pace"
	if bool(candidate.angle_limited):
		return "redirection"
	if bool(candidate.speed_limited):
		return "pace"
	return "anchor_geometry"


## State of one launch when it reaches the plane nearest the horizontal target,
## plus the full free-flight-to-floor result. The target-plane state is a shadow
## diagnostic, not an interception claim; M5 still owns who actually contacts it.
static func _launch_record(
	contact: Vector2,
	contact_height: float,
	velocity: Vector3,
	target: Vector2,
	height_anchor: float,
	arrival_floor: float,
) -> Dictionary:
	var horizontal := Vector2(velocity.x, velocity.z)
	var target_delta := _court_delta(contact, target)
	var horizontal_squared := horizontal.length_squared()
	if horizontal_squared <= NUMERICAL_EPSILON:
		return {
			"forward": false,
			"spatial_error_meters": INF,
			"arrival_shortfall_seconds": arrival_floor,
			"arrival_floor_satisfied": arrival_floor <= 0.0,
		}
	var arrival := target_delta.dot(horizontal) / horizontal_squared
	var angle := rad_to_deg(asin(clampf(
		velocity.y / maxf(velocity.length(), BallFlight.MIN_SPEED_MPS), -1.0, 1.0
	)))
	var full_flight := BallFlight.solve_flight(
		velocity.length(), angle, contact_height
	)
	var bearing := horizontal.normalized()
	## If circumstance makes every reachable launch travel away from the anchor,
	## there is still a physical ball to choose. The minimal preference compares
	## that ball's floor endpoint with the anchors; it does not manufacture a
	## target-facing direction or declare that the contact produced nothing.
	var forward := arrival > 0.0
	## A target plane after the ball is down is not a place the flight reaches.
	## Compare the floor contact with the anchor instead of extending the
	## parabola through the floor to an arbitrarily large negative height.
	var reaches_target_plane := forward \
		and arrival <= float(full_flight.duration_seconds) \
		+ NUMERICAL_EPSILON
	var evaluation_time := arrival if reaches_target_plane \
		else float(full_flight.duration_seconds)
	var reached_delta := horizontal * evaluation_time
	var horizontal_error := reached_delta.distance_to(target_delta)
	var reached_height := contact_height + velocity.y * evaluation_time \
		- 0.5 * BallFlight.DEFAULT_GRAVITY_MPS2 * evaluation_time * evaluation_time
	if not reaches_target_plane:
		reached_height = 0.0
	var height_error := absf(reached_height - height_anchor)
	var floor_shortfall := maxf(arrival_floor - evaluation_time, 0.0)
	return {
		"forward": forward,
		"reaches_target_plane": reaches_target_plane,
		"target_plane_time_seconds": evaluation_time,
		"target_plane_position": _court_position(contact, reached_delta),
		"target_plane_height_meters": reached_height,
		"horizontal_error_meters": horizontal_error,
		"height_error_meters": height_error,
		"spatial_error_meters": sqrt(
			horizontal_error * horizontal_error + height_error * height_error
		),
		"arrival_shortfall_seconds": floor_shortfall,
		"arrival_floor_satisfied": floor_shortfall <= NUMERICAL_EPSILON,
		"launch_angle_degrees": angle,
		"launch_bearing": bearing,
		"floor_duration_seconds": float(full_flight.duration_seconds),
		"floor_range_meters": float(full_flight.range_meters),
		"floor_destination": _court_position(
			contact, bearing * float(full_flight.range_meters)
		),
		"apex_height_meters": float(full_flight.apex_height_meters),
	}


static func _execute_direction(
	selected: Vector3,
	natural: Vector3,
	half_angle_degrees: float,
	sigma_degrees: float,
	seed_value: int,
) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var error := deg_to_rad(rng.randfn(0.0, maxf(sigma_degrees, 0.0)))
	var azimuth := rng.randf_range(0.0, TAU)
	var basis_a := selected.cross(Vector3.UP)
	if basis_a.length_squared() <= NUMERICAL_EPSILON:
		basis_a = selected.cross(Vector3.RIGHT)
	basis_a = basis_a.normalized()
	var basis_b := selected.cross(basis_a).normalized()
	var tangent := basis_a * cos(azimuth) + basis_b * sin(azimuth)
	var realised := (selected * cos(error) + tangent * sin(error)).normalized()
	return _project_feasible_direction(realised, natural, half_angle_degrees)


## T2 is not permission to leave the shared projectile solver's domain. The
## redirection cone and BallFlight's signed elevation range are both physical
## constraints, so alternating projection finds their common feasible member.
## This adds no authored contact parameter; the elevation endpoints already
## belong to the authoritative flight model.
static func _project_feasible_direction(
	direction: Vector3,
	natural: Vector3,
	half_angle_degrees: float,
) -> Vector3:
	var feasible := direction.normalized()
	for _step in range(4):
		feasible = _project_to_cone(feasible, natural, half_angle_degrees)
		feasible = _clamp_launch_elevation(feasible)
	return feasible.normalized()


static func _clamp_launch_elevation(direction: Vector3) -> Vector3:
	var wanted := direction.normalized()
	var horizontal := Vector2(wanted.x, wanted.z)
	var bearing := horizontal.normalized()
	if bearing.length_squared() <= NUMERICAL_EPSILON:
		bearing = Vector2.RIGHT
	var elevation := clampf(
		rad_to_deg(atan2(wanted.y, horizontal.length())),
		BallFlight.MIN_LAUNCH_ANGLE_DEGREES,
		BallFlight.MAX_LAUNCH_ANGLE_DEGREES,
	)
	var radians := deg_to_rad(elevation)
	return Vector3(
		bearing.x * cos(radians), sin(radians), bearing.y * cos(radians)
	).normalized()


static func _project_to_cone(
	direction: Vector3,
	centre: Vector3,
	half_angle_degrees: float,
) -> Vector3:
	var wanted := direction.normalized()
	var anchor := centre.normalized()
	var limit := deg_to_rad(maxf(half_angle_degrees, 0.0))
	var angle := anchor.angle_to(wanted)
	if angle <= limit + NUMERICAL_EPSILON:
		return wanted
	var axis := anchor.cross(wanted)
	if axis.length_squared() <= NUMERICAL_EPSILON:
		axis = anchor.cross(Vector3.UP)
		if axis.length_squared() <= NUMERICAL_EPSILON:
			axis = anchor.cross(Vector3.RIGHT)
	return anchor.rotated(axis.normalized(), limit).normalized()


static func _court_delta(start: Vector2, end: Vector2) -> Vector2:
	return Vector2(
		(end.x - start.x) * CourtConstants.COURT_WIDTH_METERS,
		(end.y - start.y) * CourtConstants.COURT_LENGTH_METERS,
	)


static func _court_position(start: Vector2, delta_meters: Vector2) -> Vector2:
	return start + Vector2(
		delta_meters.x / CourtConstants.COURT_WIDTH_METERS,
		delta_meters.y / CourtConstants.COURT_LENGTH_METERS,
	)


static func _is_number(value: Variant) -> bool:
	return value is float or value is int
