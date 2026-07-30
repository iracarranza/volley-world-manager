class_name RallyContactSystem
extends RefCounted

const RallyKinematicsModel := preload("res://scripts/simulation/rally_kinematics.gd")

## Gate 11 fixture ranges. They are game-balance inputs, not claims about
## real-world ball physics. A successful contact selects a descriptor profile;
## duration is then calculated from court distance, speed, and geometric arc.
const ACTION_PROFILES: Dictionary = {
	"emergency_keep_alive": {
		"speed_range": Vector2(3.8, 5.2), "vertical_angle": 42.0,
		"topspin_range": Vector2(1.8, 0.5),
		"stability_range": Vector2(0.34, 0.70),
		"contact_height_range": Vector2(1.35, 1.90),
	},
	"safe_center_pass": {
		"speed_range": Vector2(4.6, 6.4), "vertical_angle": 34.0,
		"topspin_range": Vector2(1.3, 0.2),
		"stability_range": Vector2(0.52, 0.90),
		"contact_height_range": Vector2(2.05, 2.38),
	},
	"quick_release_pass": {
		"speed_range": Vector2(6.2, 8.4), "vertical_angle": 25.0,
		"topspin_range": Vector2(1.0, 0.1),
		"stability_range": Vector2(0.46, 0.86),
		"contact_height_range": Vector2(2.20, 2.58),
	},
}


## Converts a graded shadow reception into an outgoing calculated flight.
## It returns evidence only and never mutates RallyState or official events.
static func resolve_shadow_reception(contact_result: Dictionary) -> Dictionary:
	if not bool(contact_result.get("attempted", false)):
		return {"available": false, "reason": "no contact attempted"}
	if not bool(contact_result.get("success", false)):
		return {"available": false, "reason": "contact did not succeed"}

	var action := str(contact_result.get("action", "emergency_keep_alive"))
	var profile: Dictionary = ACTION_PROFILES.get(
		action, ACTION_PROFILES["emergency_keep_alive"]
	)
	var quality := clampf(float(contact_result.get("quality", 0.0)), 0.0, 1.0)
	var origin := Vector2(contact_result.get("contact_position", Vector2.ZERO))
	var destination := Vector2(contact_result.get("outgoing_target", origin))
	var contact_time := float(contact_result.get("contact_time", 0.0))
	var delta_meters := RallyKinematicsModel.court_delta_meters(origin, destination)
	var horizontal_angle := rad_to_deg(atan2(delta_meters.x, absf(delta_meters.y)))
	var vertical_angle := float(profile.get("vertical_angle", 34.0))
	var speed_range := Vector2(profile.get("speed_range", Vector2(5.2, 7.2)))
	var speed := lerpf(speed_range.x, speed_range.y, quality)
	var spin_range := Vector2(profile.get("topspin_range", Vector2(1.8, 0.5)))
	var topspin := lerpf(spin_range.x, spin_range.y, quality)
	var lateral_sign := signf(delta_meters.x)
	var sidespin := lateral_sign * (1.0 - quality) \
		* minf(absf(horizontal_angle) / 18.0, 1.0) * 1.8
	var stability_range := Vector2(profile.get(
		"stability_range", Vector2(0.34, 0.70)
	))
	var stability := lerpf(stability_range.x, stability_range.y, quality)
	var contact_height_range := Vector2(profile.get(
		"contact_height_range", Vector2(1.60, 2.20)
	))
	var destination_contact_height := lerpf(
		contact_height_range.x, contact_height_range.y, quality
	)
	var signature := BallContactSignature.create(
		StringName(action), speed, horizontal_angle, vertical_angle,
		topspin, sidespin, stability,
	)
	var distance := RallyKinematicsModel.court_distance_meters(origin, destination)
	var path_factor := RallyKinematicsModel.path_length_factor(vertical_angle)
	var duration := RallyKinematicsModel.flight_duration(
		distance, signature.speed_mps, path_factor
	)
	var flight := BallFlight.create(
		origin, destination, contact_time, duration, signature,
		destination_contact_height,
	)
	var timing := RallyKinematicsModel.timing_diagnostics(
		origin, destination, signature.speed_mps, flight.duration(),
		signature.vertical_angle_degrees, 0.001,
	)
	var continuity := {
		"origin_error": flight.origin.distance_to(origin),
		"start_time_error": absf(flight.start_time - contact_time),
		"destination_error": flight.destination.distance_to(destination),
		"speed_duration_relative_error": float(timing.get(
			"relative_duration_error", INF
		)),
	}
	continuity["valid"] = (
		float(continuity.origin_error) <= 0.0001
		and float(continuity.start_time_error) <= 0.0001
		and float(continuity.destination_error) <= 0.0001
		and float(continuity.speed_duration_relative_error) <= 0.001
		and flight.duration() > 0.0
	)
	return {
		"available": true,
		"shadow_only": true,
		"action": action,
		"contact_quality": quality,
		"flight": flight.to_dict(),
		"continuity": continuity,
	}
