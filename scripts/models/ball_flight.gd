class_name BallFlight
extends Resource

## Authoritative calculated facts about one flight. BallTrajectory remains the
## sampled path used by persistent state and playback adapters.
@export var origin: Vector2 = Vector2.ZERO
@export var destination: Vector2 = Vector2.ZERO
@export var start_time: float = 0.0
@export var arrival_time: float = 0.0
## Gameplay contact height at destination. This is simulation truth and must
## not be inferred from playback-only arc or apex values.
@export var contact_height_meters: float = 1.0
@export var signature: BallContactSignature


static func create(
	start: Vector2,
	end: Vector2,
	departure_time: float,
	flight_duration: float,
	contact_signature: BallContactSignature,
	destination_contact_height_meters: float = 1.0,
) -> BallFlight:
	var flight := BallFlight.new()
	flight.origin = start
	flight.destination = end
	flight.start_time = departure_time
	flight.arrival_time = departure_time + maxf(flight_duration, 0.01)
	flight.contact_height_meters = maxf(destination_contact_height_meters, 0.05)
	flight.signature = contact_signature
	return flight


static func from_trajectory(
	trajectory: BallTrajectory,
	contact_signature: BallContactSignature,
) -> BallFlight:
	if trajectory == null:
		return null
	var flight := BallFlight.new()
	flight.origin = trajectory.start_position
	flight.destination = trajectory.end_position
	flight.start_time = trajectory.start_time
	flight.arrival_time = trajectory.end_time
	flight.contact_height_meters = maxf(trajectory.end_height_meters, 0.05)
	flight.signature = contact_signature
	return flight


func duration() -> float:
	return maxf(arrival_time - start_time, 0.01)


func observation_progress(observation_time: float) -> float:
	return clampf((observation_time - start_time) / duration(), 0.0, 1.0)


func to_dict() -> Dictionary:
	return {
		"origin": origin,
		"destination": destination,
		"start_time": start_time,
		"arrival_time": arrival_time,
		"duration": duration(),
		"contact_height_meters": contact_height_meters,
		"signature": signature.to_dict() if signature != null else {},
	}


## Rebuilds a flight from `to_dict()` output.
##
## The shadow systems each carried their own copy of this -- one in
## `ShadowBlockSystem`, another in `ShadowSetterResponseSystem` -- reading the
## same keys through the same constructor. Only the fallbacks differed,
## because a missing *set* and a missing *pass* should not default to the same
## flight. So `defaults` carries those context values and the reconstruction
## itself lives once, next to the `to_dict()` it has to stay in step with:
## adding a field to this model now breaks one place instead of silently
## being forgotten in a second.
##
## Recognised `defaults` keys: origin, destination, duration,
## contact_height_meters, action_type, flight_stability.
static func from_dict(data: Dictionary, defaults: Dictionary = {}) -> BallFlight:
	if data.is_empty():
		return null
	return BallFlight.create(
		Vector2(data.get("origin", defaults.get("origin", Vector2.ZERO))),
		Vector2(data.get("destination", defaults.get("destination", Vector2.ZERO))),
		float(data.get("start_time", 0.0)),
		float(data.get("duration", defaults.get("duration", 0.01))),
		BallContactSignature.from_dict(
			Dictionary(data.get("signature", {})), defaults
		),
		float(data.get(
			"contact_height_meters", defaults.get("contact_height_meters", 1.0)
		)),
	)
