class_name BallFlightEstimate
extends Resource

## One player's perception of a true BallFlight at a specific observation time.
@export var player_id: int = -1
@export var observed_at: float = 0.0
@export var true_destination: Vector2 = Vector2.ZERO
@export var perceived_destination: Vector2 = Vector2.ZERO
@export var true_arrival_time: float = 0.0
@export var perceived_arrival_time: float = 0.0
@export var true_contact_height_meters: float = 1.0
@export var perceived_contact_height_meters: float = 1.0
@export var recognition_time: float = 0.0
@export_range(0.0, 1.0) var confidence: float = 0.0
@export_range(0.0, 1.0) var novelty: float = 0.0


func destination_error_meters() -> float:
	var delta := perceived_destination - true_destination
	return Vector2(delta.x * 9.0, delta.y * 18.0).length()


func arrival_time_error() -> float:
	return absf(perceived_arrival_time - true_arrival_time)


func contact_height_error_meters() -> float:
	return absf(perceived_contact_height_meters - true_contact_height_meters)


func has_recognized() -> bool:
	return observed_at >= recognition_time
