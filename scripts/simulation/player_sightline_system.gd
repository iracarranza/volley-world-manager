class_name PlayerSightlineSystem
extends RefCounted

const BallFlightModel := preload("res://scripts/simulation/ball_flight_model.gd")

const COURT_WIDTH_METERS: float = 9.0
const DEFAULT_EYE_HEIGHT_METERS: float = 1.72
const DEFAULT_BLOCK_TOP_METERS: float = 2.72
const BLOCK_HALF_WIDTH_METERS: float = 0.48
const SAMPLE_COUNT: int = 32


## Returns the interval in which a particular defender's ray to the sampled
## ball crosses an occupied blocker silhouette. It is geometry, not a block-
## strategy bonus, and can therefore differ for two defenders behind one wall.
static func occlusion_window(
	observer_position: Vector2,
	trajectory: Dictionary,
	block_event: Resource,
	observer_profile: Dictionary = {},
) -> Dictionary:
	if trajectory.is_empty() or block_event == null:
		return {"occluded": false}
	var start_time := float(trajectory.get("start_time", 0.0))
	var duration := maxf(float(trajectory.get("duration", 0.0)), 0.01)
	var hidden_start := -1.0
	var hidden_end := -1.0
	var hidden_samples := 0
	for sample_index in range(SAMPLE_COUNT + 1):
		var progress := float(sample_index) / float(SAMPLE_COUNT)
		var ball_position := _trajectory_position(trajectory, progress)
		var hidden := _sample_is_hidden(
			observer_position, ball_position,
			_trajectory_height(trajectory, progress), block_event,
			float(observer_profile.get("eye_height_meters", DEFAULT_EYE_HEIGHT_METERS)),
		)
		var sample_time := start_time + duration * progress
		if hidden:
			hidden_samples += 1
			if hidden_start < 0.0:
				hidden_start = sample_time
			hidden_end = sample_time
	if hidden_start < 0.0:
		return {
			"occluded": false,
			"hidden_fraction": 0.0,
			"sample_count": SAMPLE_COUNT + 1,
		}
	var reacquired := minf(
		hidden_end + duration / float(SAMPLE_COUNT), start_time + duration
	)
	return {
		"occluded": true,
		"starts_at": hidden_start,
		"ends_at": reacquired,
		"reacquired_at": reacquired,
		"hidden_sample_count": hidden_samples,
		"sample_count": SAMPLE_COUNT + 1,
		## How much of the flight the wall actually took away.
		##
		## Published because the *degree* is the whole distinction between a
		## defender who briefly lost the ball behind an arm and one who never saw
		## it leave the hitter's hand, and the boolean above cannot express it.
		## Classified in perception, by `visibility_for`, so no renderer ever has
		## to decide what "partially" means.
		"hidden_fraction": float(hidden_samples) / float(SAMPLE_COUNT + 1),
	}


## What a defender's sightline reads as, from how much of the flight was taken.
##
## The two thresholds are the only numbers here and they are deliberately far
## apart: anything under a tenth of the flight is a flicker behind a hand and is
## not worth telling a viewer about, and over half the flight hidden is a
## defender playing the ball on sound and memory. The band between them is the
## real one -- the ball appears late out of a seam -- and it is where most
## occlusions land.
const BRIEF_OCCLUSION_SHARE: float = 0.10
const HEAVY_OCCLUSION_SHARE: float = 0.50


static func visibility_for(window: Dictionary) -> StringName:
	if not bool(window.get("occluded", false)):
		return &"visible"
	var share := float(window.get("hidden_fraction", 0.0))
	if share < BRIEF_OCCLUSION_SHARE:
		return &"visible"
	if share >= HEAVY_OCCLUSION_SHARE:
		return &"occluded"
	return &"partially_obscured"


static func _sample_is_hidden(
	observer: Vector2,
	ball: Vector2,
	ball_height: float,
	block_event: Resource,
	eye_height: float,
) -> bool:
	var net_y := 0.5
	var span := ball.y - observer.y
	if absf(span) < 0.0001:
		return false
	var ray_fraction := (net_y - observer.y) / span
	## The wall only obscures a ball on the far side of it.
	if ray_fraction <= 0.0 or ray_fraction >= 1.0:
		return false
	var ray_x := lerpf(observer.x, ball.x, ray_fraction)
	var ray_height := lerpf(eye_height, ball_height, ray_fraction)
	var blocker_top := maxf(
		float(block_event.metadata.get("contact_height_meters", DEFAULT_BLOCK_TOP_METERS)),
		DEFAULT_BLOCK_TOP_METERS,
	)
	if ray_height < 0.75 or ray_height > blocker_top:
		return false
	var blocker_specs: Array[Dictionary] = []
	blocker_specs.append({
		"position": Vector2(block_event.metadata.get(
			"primary_position", Vector2(block_event.start_position.x, net_y)
		)),
		"close": float(block_event.metadata.get("primary_close", 0.0)),
	})
	if int(block_event.metadata.get("assist_id", -1)) >= 0:
		blocker_specs.append({
			"position": Vector2(block_event.metadata.get(
				"assist_position", Vector2(block_event.start_position.x, net_y)
			)),
			"close": float(block_event.metadata.get("assist_close", 0.0)),
		})
	for spec in blocker_specs:
		var close := clampf(float(spec.close), 0.0, 1.0)
		if close < 0.20:
			continue
		var half_width := BLOCK_HALF_WIDTH_METERS / COURT_WIDTH_METERS \
			* lerpf(0.55, 1.15, close)
		if absf(ray_x - Vector2(spec.position).x) <= half_width:
			return true
	return false


static func _trajectory_position(trajectory: Dictionary, progress: float) -> Vector2:
	var start := Vector2(trajectory.get("start_position", Vector2.ZERO))
	var end := Vector2(trajectory.get("end_position", start))
	var control := Vector2(trajectory.get("control_position", start.lerp(end, 0.5)))
	var inverse := 1.0 - progress
	return inverse * inverse * start + 2.0 * inverse * progress * control \
		+ progress * progress * end


static func _trajectory_height(trajectory: Dictionary, progress: float) -> float:
	return BallFlightModel.height_between(
		float(trajectory.get("start_height_meters", 2.8)),
		float(trajectory.get("end_height_meters", 0.2)),
		maxf(float(trajectory.get("duration", 0.1)), 0.01),
		progress,
	)
