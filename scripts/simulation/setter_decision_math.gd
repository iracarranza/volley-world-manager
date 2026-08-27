class_name SetterDecisionMath
extends RefCounted

## Pure setter-option geometry. This is deliberately a behavior-preserving first
## extraction: RallySimulator remains orchestration authority while setter math
## gets a stable place to grow.

static func rescue_height_meters(
	travel_time: float, ordinary_flight_time: float
) -> float:
	return SetterDecisionMath.rescue_height_meters(travel_time, ordinary_flight_time)

static func set_height_difficulty(
	setter: VolleyballPlayer, rescue_height_meters: float
) -> float:
	return SetterDecisionMath.set_height_difficulty(setter, rescue_height_meters)
