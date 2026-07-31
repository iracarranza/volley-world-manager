class_name MovementContinuityDraft
extends RefCounted

## DRAFT -- not wired into the live rally or playback path.
##
## Replaces the piecewise-linear waypoint tween that currently drives player
## motion during playback (`TacticalCourt._set_playback_progress`). That tween
## has three defects this module removes:
##
## 1. It interpolates `start.lerp(target, t)`, so a player leaves rest at full
##    speed and arrives at full speed, then stops dead.
## 2. With an approach waypoint it splits the phase at a fixed 0.46 share
##    regardless of geometry, so a waypoint 90% of the way along is crawled to
##    and then sprinted from.
## 3. Direction changes instantly at the waypoint -- a velocity discontinuity
##    no real player produces.
##
## The replacement keeps the same inputs (start, optional waypoint, target,
## duration) and adds two: the speed the player is already carrying, and the
## speed they should still carry at the end. Motion is then a single smooth
## traversal whose timing follows arc length rather than a fixed constant.
##
## It is deliberately pure: no RallyState, no mutation, no RNG. It converts a
## geometric intent plus timing into sampled position and velocity, so it can be
## used by playback first (visual only) and by the resolver later, without the
## two disagreeing.

## Corner rounding as a fraction of the shorter leg. Higher looks floatier;
## above ~0.5 the rounded corner starts cutting inside the waypoint enough that
## the approach no longer reads as touching it.
const CORNER_BLEND: float = 0.35
## Cubic Hermite stays monotonic while endpoint speeds sit under 3L/T. Beyond
## that the player would visibly reverse mid-phase to satisfy the endpoints.
const MONOTONIC_SPEED_LIMIT: float = 3.0
const ARC_SAMPLES: int = 24


## Builds a traversable path. `entry_speed` and `exit_speed` are in court units
## per second, matching `RallyPlayerState.velocity`.
static func build_path(
	start: Vector2,
	target: Vector2,
	duration: float,
	waypoint: Variant = null,
	entry_speed: float = 0.0,
	exit_speed: float = 0.0,
) -> Dictionary:
	var safe_duration := maxf(duration, 0.001)
	var points := _polyline(start, target, waypoint)
	var table := _arc_table(points)
	var length := float(table[-1]["distance"])
	## With nowhere to go, endpoint speeds are meaningless; hold position.
	if length <= 0.0001:
		return {
			"points": points, "table": table, "length": 0.0,
			"duration": safe_duration, "entry_speed": 0.0, "exit_speed": 0.0,
		}
	var limit := MONOTONIC_SPEED_LIMIT * length / safe_duration
	return {
		"points": points,
		"table": table,
		"length": length,
		"duration": safe_duration,
		"entry_speed": clampf(entry_speed, 0.0, limit),
		"exit_speed": clampf(exit_speed, 0.0, limit),
	}


## Samples the path at `elapsed` seconds. Returns position, velocity, speed, and
## the fraction of the path covered.
static func sample(path: Dictionary, elapsed: float) -> Dictionary:
	var duration := float(path.get("duration", 1.0))
	var length := float(path.get("length", 0.0))
	var points: Array = path.get("points", [])
	if length <= 0.0001 or points.is_empty():
		var held: Vector2 = points[-1] if not points.is_empty() else Vector2.ZERO
		return {
			"position": held, "velocity": Vector2.ZERO,
			"speed": 0.0, "distance_fraction": 1.0,
		}
	var u := clampf(elapsed / duration, 0.0, 1.0)
	var entry_speed := float(path.get("entry_speed", 0.0))
	var exit_speed := float(path.get("exit_speed", 0.0))
	## Cubic Hermite on distance: s(0)=0, s(1)=L, s'(0)=v_in*T, s'(1)=v_out*T.
	## Endpoint speeds are matched exactly, so a phase can hand its velocity to
	## the next one instead of both starting and ending at rest.
	var m0 := entry_speed * duration
	var m1 := exit_speed * duration
	var u2 := u * u
	var u3 := u2 * u
	var distance := (u3 * 2.0 - u2 * 3.0 + 1.0) * 0.0 \
		+ (u3 - u2 * 2.0 + u) * m0 \
		+ (u2 * 3.0 - u3 * 2.0) * length \
		+ (u3 - u2) * m1
	distance = clampf(distance, 0.0, length)
	var rate := (u2 * 6.0 - u * 6.0) * 0.0 \
		+ (u2 * 3.0 - u * 4.0 + 1.0) * m0 \
		+ (u * 6.0 - u2 * 6.0) * length \
		+ (u2 * 3.0 - u * 2.0) * m1
	var speed := maxf(rate / duration, 0.0)
	var placement := _at_distance(path, distance)
	return {
		"position": Vector2(placement["position"]),
		"velocity": Vector2(placement["tangent"]) * speed,
		"speed": speed,
		"distance_fraction": distance / length,
	}


## Convenience for playback, which drives a 0..1 progress value rather than a
## clock. Identical maths; only the input differs.
static func sample_progress(path: Dictionary, progress: float) -> Dictionary:
	return sample(path, clampf(progress, 0.0, 1.0) * float(path.get("duration", 1.0)))


## The polyline, with the waypoint corner rounded so direction is continuous.
static func _polyline(start: Vector2, target: Vector2, waypoint: Variant) -> Array:
	if waypoint == null:
		return [start, target]
	var corner := Vector2(waypoint)
	var first := corner - start
	var second := target - corner
	if first.length() <= 0.0001 or second.length() <= 0.0001:
		return [start, corner, target]
	var radius := CORNER_BLEND * minf(first.length(), second.length())
	var enter := corner - first.normalized() * radius
	var leave := corner + second.normalized() * radius
	var points: Array = [start, enter]
	## Quadratic Bezier through the corner: the player passes near the waypoint
	## on a curve rather than pivoting on it. Tangent is read per segment, so the
	## corner needs enough segments that the residual per-segment direction step
	## stays below what reads as a kink -- roughly two degrees at ARC_SAMPLES.
	for index in range(1, ARC_SAMPLES):
		var t := float(index) / float(ARC_SAMPLES)
		var inverse := 1.0 - t
		points.append(
			inverse * inverse * enter + 2.0 * inverse * t * corner + t * t * leave
		)
	points.append(leave)
	points.append(target)
	return points


static func _arc_table(points: Array) -> Array:
	var table: Array = [{"distance": 0.0, "index": 0}]
	var running := 0.0
	for index in range(1, points.size()):
		running += Vector2(points[index]).distance_to(Vector2(points[index - 1]))
		table.append({"distance": running, "index": index})
	return table


static func _at_distance(path: Dictionary, distance: float) -> Dictionary:
	var points: Array = path.get("points", [])
	var table: Array = path.get("table", [])
	for index in range(1, table.size()):
		var span_end := float(table[index]["distance"])
		if distance <= span_end or index == table.size() - 1:
			var span_start := float(table[index - 1]["distance"])
			var span := maxf(span_end - span_start, 0.0001)
			var local := clampf((distance - span_start) / span, 0.0, 1.0)
			var from := Vector2(points[index - 1])
			var to := Vector2(points[index])
			var tangent := (to - from)
			return {
				"position": from.lerp(to, local),
				"tangent": tangent.normalized() if tangent.length() > 0.0001 \
					else Vector2.ZERO,
			}
	return {"position": Vector2(points[-1]), "tangent": Vector2.ZERO}
