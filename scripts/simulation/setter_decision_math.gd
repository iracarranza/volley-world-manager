class_name SetterDecisionMath
extends RefCounted

## Pure setter-option geometry. This is deliberately a behavior-preserving first
## extraction: RallySimulator remains orchestration authority while setter math
## gets a stable place to grow.

static func rescue_height_meters(
	travel_time: float, ordinary_flight_time: float
) -> float:
	return clampf(maxf(travel_time - ordinary_flight_time, 0.0) * 1.35, 0.0, 1.80)

static func set_height_difficulty(
	setter: VolleyballPlayer, rescue_height_meters: float
) -> float:
	if setter == null:
		return rescue_height_meters * 0.08
	var height_control := (
		float(setter.set_accuracy) * 0.45
			+ float(setter.hand_control) * 0.35
			+ float(setter.tempo_control) * 0.20
	) / 100.0
	return rescue_height_meters * lerpf(0.11, 0.045, height_control)
