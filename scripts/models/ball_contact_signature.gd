class_name BallContactSignature
extends Resource

## A calculated description of a ball contact. These values inform player
## recognition and contact difficulty; they do not drive aerodynamic physics.
@export var action_type: StringName = &"ball"
@export var speed_mps: float = 0.0
@export var horizontal_angle_degrees: float = 0.0
@export var vertical_angle_degrees: float = 0.0
@export var topspin_rps: float = 0.0
@export var sidespin_rps: float = 0.0
@export_range(0.0, 1.0) var flight_stability: float = 1.0


static func create(
	kind: StringName,
	speed: float,
	horizontal_angle: float,
	vertical_angle: float,
	topspin: float,
	sidespin: float,
	stability: float,
) -> BallContactSignature:
	var signature := BallContactSignature.new()
	signature.action_type = kind
	signature.speed_mps = maxf(speed, 0.0)
	signature.horizontal_angle_degrees = clampf(horizontal_angle, -90.0, 90.0)
	signature.vertical_angle_degrees = clampf(vertical_angle, -90.0, 90.0)
	signature.topspin_rps = clampf(topspin, -30.0, 30.0)
	signature.sidespin_rps = clampf(sidespin, -30.0, 30.0)
	signature.flight_stability = clampf(stability, 0.0, 1.0)
	return signature


## Temporary baseline novelty used until learned signature clusters are added.
## Every component is normalized before weighting so no unit dominates merely
## because its raw numbers are larger.
func baseline_novelty() -> float:
	var pace_novelty := clampf(absf(speed_mps - 16.0) / 18.0, 0.0, 1.0)
	var horizontal_novelty := clampf(absf(horizontal_angle_degrees) / 60.0, 0.0, 1.0)
	var vertical_novelty := clampf(absf(vertical_angle_degrees) / 55.0, 0.0, 1.0)
	var topspin_novelty := clampf(absf(topspin_rps) / 18.0, 0.0, 1.0)
	var sidespin_novelty := clampf(absf(sidespin_rps) / 14.0, 0.0, 1.0)
	var instability_novelty := 1.0 - flight_stability
	return clampf(
		pace_novelty * 0.19
		+ horizontal_novelty * 0.16
		+ vertical_novelty * 0.14
		+ topspin_novelty * 0.17
		+ sidespin_novelty * 0.18
		+ instability_novelty * 0.16,
		0.0,
		1.0,
	)


func is_float_contact() -> bool:
	return action_type in [&"float_serve", &"jump_float"] \
		and absf(topspin_rps) <= 0.75 \
		and absf(sidespin_rps) <= 0.75


func to_dict() -> Dictionary:
	return {
		"action_type": String(action_type),
		"speed_mps": speed_mps,
		"horizontal_angle_degrees": horizontal_angle_degrees,
		"vertical_angle_degrees": vertical_angle_degrees,
		"topspin_rps": topspin_rps,
		"sidespin_rps": sidespin_rps,
		"flight_stability": flight_stability,
	}


## Inverse of `to_dict()`. `defaults` supplies the caller's context fallbacks
## -- `action_type` and `flight_stability` -- because what a missing signature
## should be taken to mean depends on whether a set or a pass was expected.
static func from_dict(data: Dictionary, defaults: Dictionary = {}) -> BallContactSignature:
	return BallContactSignature.create(
		StringName(str(data.get("action_type", defaults.get("action_type", "pass")))),
		float(data.get("speed_mps", 0.0)),
		float(data.get("horizontal_angle_degrees", 0.0)),
		float(data.get("vertical_angle_degrees", 0.0)),
		float(data.get("topspin_rps", 0.0)),
		float(data.get("sidespin_rps", 0.0)),
		float(data.get("flight_stability", defaults.get("flight_stability", 1.0))),
	)
