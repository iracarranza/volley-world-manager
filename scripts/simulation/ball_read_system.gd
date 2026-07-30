class_name BallReadSystem
extends RefCounted

const MIN_RECOGNITION_DELAY: float = 0.04
const MAX_RECOGNITION_DELAY: float = 0.52


## Produces a deterministic player-specific estimate of an authoritative
## flight. Familiarity is a temporary normalized input until experience
## clusters are implemented.
static func estimate(
	flight: BallFlight,
	player: VolleyballPlayer,
	familiarity: float,
	observation_time: float,
	seed_value: int,
) -> BallFlightEstimate:
	var result := BallFlightEstimate.new()
	if flight == null or flight.signature == null or player == null:
		return result

	var safe_familiarity := clampf(familiarity, 0.0, 1.0)
	var reading := _reading_ability(player)
	var signature_novelty := flight.signature.baseline_novelty()
	var novelty := clampf(
		signature_novelty * lerpf(1.0, 0.24, safe_familiarity),
		0.0,
		1.0,
	)
	var observation_progress := flight.observation_progress(observation_time)
	var recognition_delay := clampf(
		lerpf(0.34, 0.07, reading)
		+ novelty * 0.18
		- observation_progress * 0.05,
		MIN_RECOGNITION_DELAY,
		MAX_RECOGNITION_DELAY,
	)
	var information_quality := clampf(
		reading * 0.56
		+ safe_familiarity * 0.24
		+ observation_progress * 0.20
		- novelty * 0.24,
		0.0,
		1.0,
	)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var spatial_error_meters := lerpf(1.75, 0.08, information_quality) \
		* lerpf(0.75, 1.35, novelty)
	var error_angle := rng.randf_range(-PI, PI)
	var error_scale := rng.randf_range(0.35, 1.0)
	var error_direction := Vector2(cos(error_angle), sin(error_angle))
	var court_error := Vector2(
		error_direction.x * spatial_error_meters / 9.0,
		error_direction.y * spatial_error_meters / 18.0,
	) * error_scale
	var timing_error_limit := lerpf(0.32, 0.015, information_quality) \
		* lerpf(0.75, 1.30, novelty)
	var timing_error := rng.randf_range(-timing_error_limit, timing_error_limit)
	var height_error_limit := lerpf(0.42, 0.025, information_quality) \
		* lerpf(0.80, 1.25, novelty)
	var height_error := rng.randf_range(-height_error_limit, height_error_limit)

	result.player_id = player.id
	result.observed_at = observation_time
	result.true_destination = flight.destination
	result.perceived_destination = Vector2(
		clampf(flight.destination.x + court_error.x, 0.0, 1.0),
		clampf(flight.destination.y + court_error.y, 0.0, 1.0),
	)
	result.true_arrival_time = flight.arrival_time
	result.perceived_arrival_time = maxf(
		flight.arrival_time + timing_error,
		observation_time,
	)
	result.true_contact_height_meters = flight.contact_height_meters
	result.perceived_contact_height_meters = maxf(
		flight.contact_height_meters + height_error, 0.05
	)
	result.recognition_time = flight.start_time + recognition_delay
	result.novelty = novelty
	var spatial_accuracy := 1.0 - clampf(
		result.destination_error_meters() / 2.0, 0.0, 1.0
	)
	var timing_accuracy := 1.0 - clampf(
		result.arrival_time_error() / 0.4, 0.0, 1.0
	)
	result.confidence = clampf(
		information_quality * 0.55
		+ spatial_accuracy * 0.30
		+ timing_accuracy * 0.15,
		0.0,
		1.0,
	)
	return result


## Samples the same authoritative flight at ordered observation points. The
## shared seed intentionally preserves the player's underlying misread
## direction while accumulating information reduces its magnitude. This is a
## read-only perception sequence; it never moves the player or changes flight.
static func estimate_sequence(
	flight: BallFlight,
	player: VolleyballPlayer,
	familiarity: float,
	observation_progresses: Array[float],
	seed_value: int,
) -> Array[BallFlightEstimate]:
	var result: Array[BallFlightEstimate] = []
	if flight == null or player == null:
		return result
	var ordered_progresses: Array[float] = []
	for raw_progress in observation_progresses:
		var progress := clampf(raw_progress, 0.0, 0.95)
		if progress not in ordered_progresses:
			ordered_progresses.append(progress)
	ordered_progresses.sort()
	for progress in ordered_progresses:
		result.append(estimate(
			flight,
			player,
			familiarity,
			lerpf(flight.start_time, flight.arrival_time, progress),
			seed_value,
		))
	return result


static func _reading_ability(player: VolleyballPlayer) -> float:
	if player == null:
		return 0.0
	var base := (
		float(player.anticipation) * 0.42
		+ float(player.court_vision) * 0.26
		+ float(player.decision_making) * 0.20
		+ float(player.composure) * 0.12
	) / 100.0
	return clampf(base * (1.0 - player.fatigue * 0.22), 0.0, 1.0)
