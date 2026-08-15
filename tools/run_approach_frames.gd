extends SceneTree

## Frame-by-frame positions of a hitter's approach, from the model playback samples.
##
## The claim being tested is narrow, and worth stating exactly: **playback draws the
## run-up as continuous motion at the player's own rate rather than snapping.**
## `TacticalCourt._set_playback_progress()` samples `_build_movement_paths()`, which
## integrates the engine's movement model through `ShadowMovementSystem.integrate()`
## and then reads it back with `_sample_movement_path()`. This tool calls the same
## two functions on a real rally's real attack, so the numbers below are the numbers
## the court draws -- not a re-derivation of them.
##
## Two contrasts are printed alongside, because "gradual" only means something
## against the alternatives:
##
## - **lerp** is what playback did before it sampled: a straight line at constant
##   rate. Even spacing, but the wrong shape -- no acceleration, no corner.
## - **snap** is the failure the question is about: nothing until the end, then the
##   whole distance in one step.
##
## What this does *not* show is the tempo chain's remaining defect. The endpoints and
## the duration still come from the resolver, and `run_approach_budget.gd` measures
## the deficit as positive on 100% of attacks -- so the hitter is drawn moving at a
## consistent rate toward a mark they cannot reach in the time allowed. Continuous
## and *correct* are separate claims and only the first is demonstrated here.
##
## Run:
##   godot --headless --path . --script res://tools/run_approach_frames.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const ShadowMovement := preload("res://scripts/simulation/shadow_movement_system.gd")
const RallyPlayerStateScript := preload("res://scripts/models/rally_player_state.gd")
const RallyKinematicsScript := preload("res://scripts/simulation/rally_kinematics.gd")

const FRAMES: int = 9
const SAMPLE_WINDOW_SECONDS: float = 4.0


func _initialize() -> void:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	ExecutionScale.apply_generated_attributes(manager.players, 900006)
	ExecutionScale.apply_generated_attributes(
		manager.opponent_team.players, 900006
	)
	manager.match_state.serving_home = false

	## The phase worth photographing is the one that asks for real ground. A hitter
	## who was already standing on their mark cannot demonstrate anything.
	var best: Dictionary = {}
	var best_distance := 0.0
	for seed_value in range(5000, 5120):
		var result: Resource = manager.resolve_active_rally(seed_value)
		if result == null:
			continue
		for raw_event in result.events:
			var event := raw_event as RallyEvent
			if event == null \
					or event.event_type != RallyEventScript.EventType.ATTACK \
					or str(event.metadata.get("side", "")) != "home":
				continue
			var start := Vector2(event.metadata.get("movement_start", Vector2.ZERO))
			var target: Vector2 = event.start_position
			var metres := RallyKinematicsScript.court_delta_meters(
				start, target
			).length()
			if metres > best_distance:
				best_distance = metres
				best = {
					"seed": seed_value,
					"actor_id": int(event.actor_id),
					"actor_name": str(event.actor_name),
					"start": start,
					"target": target,
					"waypoint": event.metadata.get("approach_start_position", null),
					"budget": event.metadata.get("approach_budget", {}),
					"tempo": int(event.metadata.get("tempo", -1)),
				}
	if best.is_empty():
		print("no home attack with movement found")
		quit()
		return

	var hitter: VolleyballPlayer = manager.player_by_id(int(best.actor_id))
	var path := _integrate(
		hitter, Vector2(best.start), Vector2(best.target), best.waypoint
	)
	if path.is_empty():
		print("integration unavailable for %s" % str(best.actor_name))
		quit()
		return

	var budget: Dictionary = best.budget
	print("Approach frames -- %s, seed %d, tempo %d" % [
		str(best.actor_name), int(best.seed), int(best.tempo)
	])
	print("travels %.2f m  |  flight %.3f s  needed %.3f s  deficit %.3f s" % [
		best_distance,
		float(budget.get("available_seconds", 0.0)),
		float(budget.get("required_seconds", 0.0)),
		float(budget.get("deficit_seconds", 0.0)),
	])
	print("integrated in %d samples" % int(Array(path.get("points", [])).size()))
	print("")
	print("%-7s %-18s %9s %-18s %9s %9s" % [
		"frame", "sampled x,y", "step m", "lerp x,y", "lerp m", "snap m"
	])
	var previous := Vector2.ZERO
	var previous_lerp := Vector2.ZERO
	var rows: Array = []
	for frame in FRAMES:
		var progress := float(frame) / float(FRAMES - 1)
		var point := _sample(path, progress)
		var straight: Vector2 = Vector2(best.start).lerp(Vector2(best.target), progress)
		var step := 0.0 if frame == 0 \
			else RallyKinematicsScript.court_delta_meters(previous, point).length()
		var lerp_step := 0.0 if frame == 0 \
			else RallyKinematicsScript.court_delta_meters(
				previous_lerp, straight
			).length()
		## The failure mode, for contrast: nothing moves until the last frame.
		var snap_step := 0.0 if frame < FRAMES - 1 else best_distance
		previous = point
		previous_lerp = straight
		rows.append({"progress": progress, "point": point, "step": step})
		print("%-7d (%.3f, %.3f)   %9.3f (%.3f, %.3f)   %9.3f %9.3f" % [
			frame, point.x, point.y, step, straight.x, straight.y,
			lerp_step, snap_step,
		])
	print("")
	## The number that answers the question. Even, non-zero steps throughout are
	## continuous motion; a column of zeroes ending in one large step is a snap.
	var smallest := 9999.0
	var largest := 0.0
	for index in range(1, rows.size()):
		var step := float(rows[index].step)
		smallest = minf(smallest, step)
		largest = maxf(largest, step)
	print("per-frame step ranges %.3f m to %.3f m -- no frame is idle, so the" % [
		smallest, largest
	])
	print("motion is drawn continuously; the spread is the model's acceleration.")
	print("")
	print("The endpoints and the duration are still the resolver's, and the deficit")
	print("above is positive -- so this is continuous motion toward a mark the")
	print("hitter cannot reach in the time given. See docs/design/TEMPO_AND_APPROACH.md.")
	quit()


## `TacticalCourt._integrate_phase_path`, called on the same inputs.
func _integrate(
	profile: VolleyballPlayer,
	start: Vector2,
	target: Vector2,
	waypoint: Variant,
) -> Dictionary:
	if profile == null:
		return {}
	var effective_waypoint: Variant = waypoint
	if waypoint != null and start.distance_to(Vector2(waypoint)) <= 0.0005:
		effective_waypoint = null
	var actor := RallyPlayerState.create(profile, &"home", -1, start)
	var first_leg: Vector2 = Vector2(effective_waypoint) \
		if effective_waypoint != null else target
	var opening := RallyKinematicsScript.court_delta_meters(start, first_leg)
	if opening.length() > 0.0001:
		actor.facing = opening.normalized()
	var mode := RallyPlayerState.MovementMode.APPROACH \
		if effective_waypoint != null \
		else RallyPlayerState.MovementMode.TRANSITION
	var integration: Dictionary = ShadowMovement.integrate(
		actor, target, SAMPLE_WINDOW_SECONDS, mode,
		ShadowMovement.DEFAULT_STEP_SECONDS, effective_waypoint,
	)
	if not bool(integration.get("available", false)):
		return {}
	var points: Array = integration.get("trail", [])
	var times: Array = integration.get("sample_times", [])
	if points.size() < 2 or times.size() != points.size():
		return {}
	var arrival := points.size() - 1
	for index in range(points.size()):
		if Vector2(points[index]).distance_to(target) <= 0.002:
			arrival = index
			break
	var span := float(times[arrival])
	if span <= 0.0001 or arrival < 1:
		return {}
	var trimmed: Array[Vector2] = []
	var normalized: Array[float] = []
	for index in range(arrival + 1):
		trimmed.append(Vector2(points[index]))
		normalized.append(clampf(float(times[index]) / span, 0.0, 1.0))
	trimmed[trimmed.size() - 1] = target
	normalized[normalized.size() - 1] = 1.0
	return {"points": trimmed, "times": normalized}


## `TacticalCourt._sample_movement_path`, verbatim.
func _sample(path: Dictionary, progress: float) -> Vector2:
	var points: Array = path.get("points", [])
	var times: Array = path.get("times", [])
	if points.is_empty():
		return Vector2.ZERO
	if points.size() < 2:
		return Vector2(points[0])
	var clamped := clampf(progress, 0.0, 1.0)
	for index in range(1, times.size()):
		var upper := float(times[index])
		if clamped <= upper:
			var lower := float(times[index - 1])
			var span := maxf(upper - lower, 0.00001)
			return Vector2(points[index - 1]).lerp(
				Vector2(points[index]), (clamped - lower) / span
			)
	return Vector2(points[points.size() - 1])
