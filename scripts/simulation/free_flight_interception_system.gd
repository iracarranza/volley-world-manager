class_name FreeFlightInterceptionSystem
extends RefCounted

const BallFlight := preload("res://scripts/simulation/ball_flight_model.gd")
const BallTrajectory := preload("res://scripts/models/ball_trajectory.gd")
const RallyMovement := preload("res://scripts/simulation/rally_movement_system.gd")
const ApproachMechanics := preload(
	"res://scripts/simulation/approach_mechanics_system.gd"
)

## Numerical resolution only. These values do not describe a ball or a body and
## must never be tuned against rally outcomes. The coarse scan finds the first
## reachable interval and bisection refines its physical boundary.
const SEARCH_SAMPLES: int = 241
const REFINE_STEPS: int = 18
const TIME_EPSILON_SECONDS: float = 0.00001


## Build the whole free flight from the launch that a contact resolved.
##
## The natural floor contact owns the endpoint. A later interceptor may realize
## a prefix of this record, but may not change its launch or its unconstrained
## endpoint. Horizontal motion is linear because the shared projectile model has
## no aerodynamic lateral term; the old display-only Bezier bend is deliberately
## absent from gameplay authority.
static func from_launch(
	kind: String,
	contact_position: Vector2,
	contact_height_meters: float,
	launch_velocity_mps: Vector3,
	start_time: float,
	flight_id: String,
	## **What this ball falls under, because not every ball falls the same.**
	##
	## `height_at_time` and `velocity_at_time` have always read
	## `launch_gravity_mps2` off the flight rather than assuming it, so the
	## evaluation half of this system was already able to fly a topspin ball. This
	## function was the half that could not state one: it dropped `solve_flight`'s
	## gravity argument and then stamped the default as though it were a fact.
	##
	## That was harmless while only platform contacts minted flights -- a passed
	## ball genuinely falls at 9.8, and the reception's own record checks out to
	## 0.000 m against its launch. It is not harmless for a serve, which flies at
	## 21.009 in this build. Defaulted, so every existing caller keeps the exact
	## number it was already getting.
	gravity_mps2: float = BallFlight.DEFAULT_GRAVITY_MPS2,
) -> Dictionary:
	var speed := launch_velocity_mps.length()
	if speed <= BallFlight.MIN_SPEED_MPS or contact_height_meters <= 0.0:
		return {}
	var horizontal := Vector2(launch_velocity_mps.x, launch_velocity_mps.z)
	if horizontal.length_squared() <= 0.0000001:
		return {}
	var angle := rad_to_deg(asin(clampf(
		launch_velocity_mps.y / speed, -1.0, 1.0
	)))
	var solved := BallFlight.solve_flight(
		speed, angle, contact_height_meters, gravity_mps2
	)
	var duration := float(solved.duration_seconds)
	var floor_position := _court_position(
		contact_position, horizontal * duration
	)
	var trajectory := BallTrajectory.create(
		kind,
		contact_position,
		contact_position.lerp(floor_position, 0.5),
		floor_position,
		start_time,
		duration,
		float(solved.apex_height_meters),
		contact_height_meters,
		0.0,
	).to_dict()
	trajectory["trajectory_role"] = "authoritative_free_flight"
	trajectory["authoritative_flight_id"] = flight_id
	trajectory["height_source"] = "resolved"
	trajectory["height_contract"] = "absolute_projectile"
	trajectory["apex_rise_meters"] = maxf(
		float(solved.apex_height_meters) - contact_height_meters, 0.0
	)
	trajectory["launch_source"] = "resolver"
	trajectory["launch_speed_mps"] = speed
	trajectory["launch_angle_degrees"] = angle
	trajectory["launch_horizontal_mps"] = horizontal.length()
	trajectory["launch_vertical_mps"] = launch_velocity_mps.y
	trajectory["launch_gravity_mps2"] = gravity_mps2
	trajectory["launch_velocity_mps"] = launch_velocity_mps
	trajectory["natural_end_position"] = floor_position
	trajectory["natural_end_time"] = start_time + duration
	trajectory["natural_end_reason"] = "floor"
	return trajectory


## Earliest physically reachable point on one authoritative flight, per actor.
## Selection between those opportunities belongs to the rally's existing
## responsibility/decision policy, not to this physical system.
static func opportunities(
	free_flight: Dictionary,
	actors: Array[RallyPlayerState],
	action_type: StringName = &"set",
	allow_jump: bool = true,
	excluded_actor_ids: Array[int] = [],
	preferred_position: Variant = null,
	preferred_height_meters: float = NAN,
	continue_after_legal_net_crossing: bool = false,
	earliest_search_time: float = NAN,
	derive_attack_approach: bool = false,
) -> Dictionary:
	if str(free_flight.get("trajectory_role", "")) \
			!= "authoritative_free_flight":
		return {"available": false, "reason": "not authoritative free flight"}
	var flight_start := float(free_flight.get("start_time", 0.0))
	var start_time := flight_start if is_nan(earliest_search_time) \
		else maxf(flight_start, earliest_search_time)
	var terminal := _first_uncontrolled_terminal(
		free_flight, not continue_after_legal_net_crossing
	)
	var end_time := float(terminal.get(
		"time", free_flight.get("end_time", start_time)
	))
	var by_actor := {}
	for actor in actors:
		if actor == null or actor.player == null \
				or actor.player_id in excluded_actor_ids:
			continue
		var found := _preferred_opportunity(
			free_flight, actor, action_type, allow_jump,
			start_time, end_time, preferred_position, preferred_height_meters,
			derive_attack_approach,
		)
		if not found.is_empty():
			by_actor[actor.player_id] = found
	return {
		"available": true,
		"authoritative_free_flight": free_flight,
		"terminal": terminal,
		"opportunities": by_actor,
	}


## The exact played segment, derived from the same launch and ending at the
## realized contact. The source flight is not mutated and the linkage is
## explicit, so a consumer can certify that this is a prefix rather than a
## replacement ball reconstructed from the recipient.
static func realised_prefix(
	free_flight: Dictionary,
	contact_time: float,
) -> Dictionary:
	if str(free_flight.get("trajectory_role", "")) \
			!= "authoritative_free_flight":
		return {}
	var start_time := float(free_flight.get("start_time", 0.0))
	var natural_end := float(free_flight.get("end_time", start_time))
	var end_time := clampf(contact_time, start_time, natural_end)
	var elapsed := maxf(end_time - start_time, BallFlight.MIN_FLIGHT_DURATION)
	var end_position := position_at_time(free_flight, end_time)
	var start_position := Vector2(free_flight.get(
		"start_position", Vector2.ZERO
	))
	var start_height := float(free_flight.get("start_height_meters", 0.0))
	var end_height := height_at_time(free_flight, end_time)
	var launch_vertical := float(free_flight.get("launch_vertical_mps", 0.0))
	var gravity := float(free_flight.get(
		"launch_gravity_mps2", BallFlight.DEFAULT_GRAVITY_MPS2
	))
	var apex_time := maxf(launch_vertical / maxf(gravity, 0.1), 0.0)
	var apex_elapsed := minf(apex_time, elapsed)
	var apex_height := start_height + launch_vertical * apex_elapsed \
		- 0.5 * gravity * apex_elapsed * apex_elapsed
	var segment := BallTrajectory.create(
		str(free_flight.get("trajectory_type", "ball")),
		start_position,
		start_position.lerp(end_position, 0.5),
		end_position,
		start_time,
		elapsed,
		maxf(apex_height, maxf(start_height, end_height)),
		start_height,
		end_height,
	).to_dict()
	segment["trajectory_role"] = "realised_segment"
	segment["authoritative_flight_id"] = str(free_flight.get(
		"authoritative_flight_id", ""
	))
	segment["height_source"] = "resolved"
	segment["height_contract"] = "absolute_projectile"
	segment["apex_rise_meters"] = maxf(
		float(segment.apex_height_meters) - start_height, 0.0
	)
	for key in [
		"launch_source", "launch_speed_mps", "launch_angle_degrees",
		"launch_horizontal_mps", "launch_vertical_mps",
		"launch_gravity_mps2", "launch_velocity_mps",
		## **The bearing was the one launch field that did not survive a slice.**
		## `from_launch` derives elevation from the velocity but has no court
		## sense to derive a bearing from, so a family that knows its own bearing
		## stamps it after minting -- and this list is what carries it onto the
		## played segment. Without it a consumer re-flying the record sends the
		## ball down the x axis, which is what a serve leg's landing check found
		## the moment the serve began publishing a prefix.
		"launch_bearing_degrees",
	]:
		if free_flight.has(key):
			segment[key] = free_flight[key]
	segment["natural_end_position"] = Vector2(free_flight.get(
		"natural_end_position", free_flight.get("end_position", end_position)
	))
	segment["natural_end_time"] = float(free_flight.get(
		"natural_end_time", natural_end
	))
	segment["natural_end_reason"] = str(free_flight.get(
		"natural_end_reason", "floor"
	))
	return segment


## When this flight comes down through a given height, and where it is then.
##
## **The question a serve receive has to ask and had no way to.** A passer meets
## a descending ball at their platform, which happens strictly before the ball
## reaches the floor -- so a contact stamped at the flight's end is a contact at
## ground level, and reading that end under the wrong gravity was the only thing
## making it look like a height at all. See
## `docs/review/SERVE_RECEPTION_HEIGHT_SEAM.md`.
##
## This is not a second interception authority. `opportunities` answers "who can
## get there", which is a question about bodies; this answers "when is the ball
## at this height", which is a question about one flight and is evaluated by that
## flight's own `height_at_time`. Bisection on the descending branch, because the
## height is monotonic after the apex and the apex is on the record.
##
## Empty when the flight never reaches the height on the way down -- a ball that
## is already below it at launch, or one whose whole arc stays above it.
static func descent_to_height(
	free_flight: Dictionary,
	height_meters: float,
) -> Dictionary:
	if str(free_flight.get("trajectory_role", "")) \
			!= "authoritative_free_flight":
		return {}
	var start_time := float(free_flight.get("start_time", 0.0))
	var duration := float(free_flight.get("duration", 0.0))
	var launch_vertical := float(free_flight.get("launch_vertical_mps", 0.0))
	var gravity := maxf(float(free_flight.get(
		"launch_gravity_mps2", BallFlight.DEFAULT_GRAVITY_MPS2
	)), 0.1)
	## The apex bounds the descending branch. A launch already falling has its
	## apex at the contact, which makes the whole flight the descending branch.
	var apex_elapsed := clampf(launch_vertical / gravity, 0.0, duration)
	if height_at_time(free_flight, start_time + apex_elapsed) < height_meters:
		return {}
	if height_at_time(free_flight, start_time + duration) > height_meters:
		return {}
	var low := apex_elapsed
	var high := duration
	for _step in range(REFINE_STEPS):
		var mid := (low + high) * 0.5
		if height_at_time(free_flight, start_time + mid) > height_meters:
			low = mid
		else:
			high = mid
	var elapsed := (low + high) * 0.5
	var at_time := start_time + elapsed
	return {
		"available": true,
		"contact_time": at_time,
		"contact_position": position_at_time(free_flight, at_time),
		"contact_height_meters": height_at_time(free_flight, at_time),
		"incoming_velocity_mps": velocity_at_time(free_flight, at_time),
		## How much of the flight is being given up by meeting it here rather
		## than letting it land, which is what a caller needs to know it moved
		## the contact rather than left it where it was.
		"seconds_before_floor": maxf(duration - elapsed, 0.0),
	}


static func position_at_time(free_flight: Dictionary, at_time: float) -> Vector2:
	var start_time := float(free_flight.get("start_time", 0.0))
	var elapsed := clampf(
		at_time - start_time, 0.0,
		float(free_flight.get("duration", 0.0)),
	)
	var velocity := Vector3(free_flight.get(
		"launch_velocity_mps", Vector3.ZERO
	))
	return _court_position(
		Vector2(free_flight.get("start_position", Vector2.ZERO)),
		Vector2(velocity.x, velocity.z) * elapsed,
	)


static func height_at_time(free_flight: Dictionary, at_time: float) -> float:
	var start_time := float(free_flight.get("start_time", 0.0))
	var elapsed := clampf(
		at_time - start_time, 0.0,
		float(free_flight.get("duration", 0.0)),
	)
	var launch_vertical := float(free_flight.get("launch_vertical_mps", 0.0))
	var gravity := float(free_flight.get(
		"launch_gravity_mps2", BallFlight.DEFAULT_GRAVITY_MPS2
	))
	return maxf(
		float(free_flight.get("start_height_meters", 0.0))
			+ launch_vertical * elapsed - 0.5 * gravity * elapsed * elapsed,
		0.0,
	)


## The complete velocity of the same authoritative launch at one instant.
## Horizontal velocity is invariant; vertical velocity advances under the
## flight's own gravity. A later contact consumes this rather than reconstructing
## an incoming ball from two endpoints.
static func velocity_at_time(free_flight: Dictionary, at_time: float) -> Vector3:
	var start_time := float(free_flight.get("start_time", 0.0))
	var elapsed := clampf(
		at_time - start_time, 0.0,
		float(free_flight.get("duration", 0.0)),
	)
	var launch := Vector3(free_flight.get(
		"launch_velocity_mps", Vector3.ZERO
	))
	var gravity := float(free_flight.get(
		"launch_gravity_mps2", BallFlight.DEFAULT_GRAVITY_MPS2
	))
	return Vector3(launch.x, launch.y - gravity * elapsed, launch.z)


## The net-plane fact exposed without deciding what the other team does with
## it. `reason` is `net` below the tape and `crossed_net_unresolved` above it.
static func net_crossing(free_flight: Dictionary) -> Dictionary:
	var terminal := _first_uncontrolled_terminal(free_flight, true)
	if str(terminal.get("reason", "")) not in ["net", "crossed_net_unresolved"]:
		return {}
	return terminal


static func _preferred_opportunity(
	free_flight: Dictionary,
	actor: RallyPlayerState,
	action_type: StringName,
	allow_jump: bool,
	start_time: float,
	end_time: float,
	preferred_position: Variant,
	preferred_height_meters: float,
	derive_attack_approach: bool,
) -> Dictionary:
	if end_time <= start_time + TIME_EPSILON_SECONDS:
		return {}
	var previous_time := start_time
	var best := {}
	var best_error := INF
	for index in range(1, SEARCH_SAMPLES + 1):
		var share := float(index) / float(SEARCH_SAMPLES)
		var candidate_time := lerpf(start_time, end_time, share)
		var candidate := _opportunity_at(
			free_flight, actor, action_type, allow_jump, candidate_time,
			derive_attack_approach,
		)
		if candidate.reachable:
			## With no intent this is a pure physical query, so return the exact
			## beginning of the reachable interval. A rally contact supplies its
			## existing target/height anchors and searches the whole feasible window
			## for the point closest to that tactical intent.
			if not preferred_position is Vector2 \
					or is_nan(preferred_height_meters):
				var low := previous_time
				var high := candidate_time
				var refined := candidate
				for _step in range(REFINE_STEPS):
					var middle := (low + high) * 0.5
					var trial := _opportunity_at(
						free_flight, actor, action_type, allow_jump, middle,
						derive_attack_approach,
					)
					if trial.reachable:
						refined = trial
						high = middle
					else:
						low = middle
				return _opportunity_record(refined, actor)
			var error := _intent_error_squared(
				candidate, Vector2(preferred_position), preferred_height_meters
			)
			if error < best_error:
				best_error = error
				best = _opportunity_record(candidate, actor)
				best["intent_spatial_error_meters"] = sqrt(error)
		previous_time = candidate_time
	return best


static func _opportunity_at(
	free_flight: Dictionary,
	actor: RallyPlayerState,
	action_type: StringName,
	allow_jump: bool,
	at_time: float,
	derive_attack_approach: bool,
) -> ActionOpportunity:
	## A body still committed to recovery cannot make a contact merely because
	## its standing reach overlaps the ball. Movement time may be zero while the
	## action remains physically unavailable; availability is a separate fact.
	if actor == null or not actor.is_available(at_time):
		return ActionOpportunity.new()
	var approach := {}
	if action_type == &"attack" and derive_attack_approach:
		approach = ApproachMechanics.evaluate_takeoff(
			actor, position_at_time(free_flight, at_time),
			maxf(at_time - float(free_flight.get("start_time", at_time)), 0.0),
		)
	return RallyMovement.evaluate_opportunity(
		actor,
		action_type,
		position_at_time(free_flight, at_time),
		at_time,
		float(free_flight.get("start_time", 0.0)),
		0.0,
		height_at_time(free_flight, at_time),
		allow_jump,
		approach,
	)


static func _opportunity_record(
	opportunity: ActionOpportunity,
	actor: RallyPlayerState,
) -> Dictionary:
	var to_ball := Vector2(
		(opportunity.contact_position.x - actor.position.x)
			* CourtConstants.COURT_WIDTH_METERS,
		(opportunity.contact_position.y - actor.position.y)
			* CourtConstants.COURT_LENGTH_METERS,
	)
	var body_travel := maxf(
		to_ball.length() - opportunity.contact_reach_meters, 0.0
	)
	var body_contact_position := actor.position
	if to_ball.length_squared() > 0.0000001:
		var body_delta := to_ball.normalized() * body_travel
		body_contact_position += Vector2(
			body_delta.x / CourtConstants.COURT_WIDTH_METERS,
			body_delta.y / CourtConstants.COURT_LENGTH_METERS,
		)
	return {
		"player": actor.player,
		"player_id": actor.player_id,
		"start": actor.position,
		"entry_velocity_mps": actor.velocity,
		"entry_facing": actor.facing,
		"body_state": actor.body_state,
		"contact_position": opportunity.contact_position,
		"body_contact_position": body_contact_position,
		"contact_time": opportunity.contact_time,
		"contact_height_meters": opportunity.contact_height_meters,
		"travel_time": opportunity.travel_time,
		"contact_reach_meters": opportunity.contact_reach_meters,
		"available_time": opportunity.available_time,
		"arrival_margin": opportunity.arrival_margin,
		"reach_margin_meters": -opportunity.center_distance_deficit_meters,
		"vertical_margin_meters": opportunity.vertical_margin_meters,
		"requires_jump": opportunity.requires_jump,
		"standing_reachable": opportunity.standing_reachable,
		"jump_reachable": opportunity.jump_reachable,
		"used_reaching_extension": opportunity.used_reaching_extension,
		"physical_feasibility": opportunity.physical_feasibility,
		"arrival_balance": opportunity.arrival_balance,
		"expected_quality": opportunity.expected_quality,
		"technical_difficulty": opportunity.technical_difficulty,
		"approach_profile": {
			"approach_speed_mps": opportunity.approach_speed_mps,
			"runup_quality": opportunity.approach_quality,
			"approach_alignment": opportunity.approach_alignment,
			"lateral_control": opportunity.lateral_control,
			"jump_multiplier": opportunity.jump_multiplier,
		},
	}


static func _intent_error_squared(
	opportunity: ActionOpportunity,
	preferred_position: Vector2,
	preferred_height_meters: float,
) -> float:
	var horizontal := Vector2(
		(opportunity.contact_position.x - preferred_position.x)
			* CourtConstants.COURT_WIDTH_METERS,
		(opportunity.contact_position.y - preferred_position.y)
			* CourtConstants.COURT_LENGTH_METERS,
	)
	var vertical := opportunity.contact_height_meters - preferred_height_meters
	return horizontal.length_squared() + vertical * vertical


## First non-player event along the flight. Crossing the net above its height is
## reported explicitly rather than silently converted into a point: resolving an
## overpass against the other side is a materially different volleyball action
## and belongs to the next policy layer.
static func _first_uncontrolled_terminal(
	free_flight: Dictionary,
	stop_at_legal_net_crossing: bool = true,
) -> Dictionary:
	var start_time := float(free_flight.get("start_time", 0.0))
	var floor_time := float(free_flight.get("end_time", start_time))
	var start := Vector2(free_flight.get("start_position", Vector2.ZERO))
	var velocity := Vector3(free_flight.get(
		"launch_velocity_mps", Vector3.ZERO
	))
	var normalized_velocity := Vector2(
		velocity.x / CourtConstants.COURT_WIDTH_METERS,
		velocity.z / CourtConstants.COURT_LENGTH_METERS,
	)
	var terminal_time := floor_time
	var terminal_reason := "floor"
	for axis in range(2):
		var component := normalized_velocity[axis]
		if absf(component) <= 0.0000001:
			continue
		var boundary := 1.0 if component > 0.0 else 0.0
		var crossing := start_time + (boundary - start[axis]) / component
		if crossing > start_time + TIME_EPSILON_SECONDS \
				and crossing < terminal_time:
			terminal_time = crossing
			terminal_reason = "out"
	if absf(normalized_velocity.y) > 0.0000001:
		var net_time := start_time \
			+ (CourtConstants.NET_Y - start.y) / normalized_velocity.y
		if net_time > start_time + TIME_EPSILON_SECONDS \
				and net_time < terminal_time:
			var below_tape := height_at_time(free_flight, net_time) \
				<= CourtConstants.NET_HEIGHT_METERS
			if below_tape or stop_at_legal_net_crossing:
				terminal_time = net_time
				terminal_reason = "net" if below_tape \
					else "crossed_net_unresolved"
	return {
		"reason": terminal_reason,
		"time": terminal_time,
		"position": position_at_time(free_flight, terminal_time),
		"height_meters": height_at_time(free_flight, terminal_time),
	}


static func _court_position(start: Vector2, delta_meters: Vector2) -> Vector2:
	return start + Vector2(
		delta_meters.x / CourtConstants.COURT_WIDTH_METERS,
		delta_meters.y / CourtConstants.COURT_LENGTH_METERS,
	)
