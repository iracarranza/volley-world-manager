class_name RallyMovementPath
extends Resource

## One traversal, solved once, in the form every consumer reads.
##
## The engine used to derive a single leg's motion three times: the resolver
## priced a duration, playback re-integrated a path to fill that duration, and
## the actor re-derived speed from successive drawn positions. Each layer
## reconstructed what the layer above already knew, and the middle one had to
## pre-align facing so its answer would land on the endpoint the first one had
## already committed to.
##
## This is the one answer. The resolver solves the leg, publishes this, and
## nothing downstream re-solves. Interpolating between samples is fine;
## re-integrating is not.
##
## NOTE stepped integration reproduces the analytical projection to 0.18 mm
## worst over 768 samples -- AUTHORITATIVE_MOVEMENT_EXECUTION.md P0.4

## Rally-clock time of the first sample. Samples are absolute, not leg-relative,
## so a consumer never has to know which leg it is looking at to place it.
@export var start_time: float = 0.0
@export var sample_times: PackedFloat32Array = PackedFloat32Array()
@export var positions: PackedVector2Array = PackedVector2Array()
@export var velocities: PackedVector2Array = PackedVector2Array()
@export var facings: PackedVector2Array = PackedVector2Array()

## What the next leg begins with. The whole momentum question in one field:
## before this existed, exit speed was computed on every leg and thrown away by
## every caller, so 14,991 of 14,991 traversals began from a dead stop.
@export var exit_velocity: Vector2 = Vector2.ZERO
@export var reached_target: bool = false


static func from_integration(
	integration: Dictionary, leg_start_time: float
) -> RallyMovementPath:
	if not bool(integration.get("available", false)):
		return null
	var path := RallyMovementPath.new()
	path.start_time = leg_start_time
	var times: Array = integration.get("sample_times", [])
	var trail: Array = integration.get("trail", [])
	var vels: Array = integration.get("velocities", [])
	var faces: Array = integration.get("facings", [])
	if trail.size() < 2 or times.size() != trail.size():
		return null
	for index in trail.size():
		path.sample_times.append(leg_start_time + float(times[index]))
		path.positions.append(Vector2(trail[index]))
		path.velocities.append(
			Vector2(vels[index]) if index < vels.size() else Vector2.ZERO
		)
		path.facings.append(
			Vector2(faces[index]) if index < faces.size() else Vector2.ZERO
		)
	path.exit_velocity = path.velocities[path.velocities.size() - 1]
	path.reached_target = bool(integration.get("reached_target", false))
	return path


func is_valid() -> bool:
	return positions.size() >= 2 and sample_times.size() == positions.size()


func end_time() -> float:
	return sample_times[sample_times.size() - 1] if is_valid() else start_time


func duration() -> float:
	return end_time() - start_time


func start_position() -> Vector2:
	return positions[0] if is_valid() else Vector2.ZERO


func landing_position() -> Vector2:
	return positions[positions.size() - 1] if is_valid() else Vector2.ZERO


## Where this body is, how fast, and which way it faces, at a rally-clock time.
##
## Clamped at both ends on purpose: before the leg the body is at its start, and
## after it the body is at its landing. A consumer asking outside the window is
## not an error, it is a consumer drawing a frame while some other leg runs.
func sample(rally_time: float) -> Dictionary:
	if not is_valid():
		return {
			"position": Vector2.ZERO, "velocity": Vector2.ZERO,
			"facing": Vector2.ZERO,
		}
	if rally_time <= sample_times[0]:
		return _sample_at(0)
	var last := positions.size() - 1
	if rally_time >= sample_times[last]:
		return _sample_at(last)
	var high := 1
	while high < last and sample_times[high] < rally_time:
		high += 1
	var low := high - 1
	var span := sample_times[high] - sample_times[low]
	var t := 0.0 if span <= 0.0 else (rally_time - sample_times[low]) / span
	return {
		"position": positions[low].lerp(positions[high], t),
		"velocity": velocities[low].lerp(velocities[high], t),
		## Directions are interpolated as vectors and renormalised rather than
		## by angle: a zero facing has no angle to slerp from, and the first
		## sample of a leg from rest is exactly that case.
		"facing": _blend_direction(facings[low], facings[high], t),
	}


func _sample_at(index: int) -> Dictionary:
	return {
		"position": positions[index],
		"velocity": velocities[index],
		"facing": facings[index],
	}


static func _blend_direction(from: Vector2, to: Vector2, t: float) -> Vector2:
	var blended := from.lerp(to, t)
	if blended.length_squared() <= 0.000001:
		return to if to.length_squared() > 0.000001 else from
	return blended.normalized()
