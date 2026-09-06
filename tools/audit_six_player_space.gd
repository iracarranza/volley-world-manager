extends SceneTree

## A6/A7 — do six bodies share one court, in space *and* time?
##
##     godot --headless --path . --script res://tools/audit_six_player_space.gd
##
## Every published `RallyMovementPath` carries absolute rally-clock sample times,
## so all six bodies on a side can be put on one clock and asked where they were
## at the same instant. That is the whole point: two paths whose *lines* cross
## are not in conflict if the bodies were there at different times, and the
## spec is explicit that a conflict needs space and time together.
##
## Paths are read from the four publishers `tactical_court` reads, in its order:
## the contact actor's own `movement_path`, `<side>_phase_intents[id].path`,
## `<side>_phase_hold_paths[id]`, and `staged_next_path`. Nothing is integrated
## here -- a body that published no path simply is not sampled, and the count of
## those is reported rather than filled in.
##
## **The clearance threshold is an assumption and is labelled as one.** The repo
## has no simulation body width; the only figure anywhere is a 0.36 m torso
## half-width fallback in a *rendering* tool. Results are therefore reported at
## three separations rather than one.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 61000
const SEED_COUNT: int = 120
const STEP_SECONDS: float = 0.04

## Centre-to-centre separations to report. 0.72 m is two of the only body
## dimension in the repo; the other two bracket it.
const CLEARANCES: Array[float] = [0.50, 0.72, 0.90]


func _initialize() -> void:
	var pair_min: Array[float] = []
	var closest: Dictionary = {}
	var below: Dictionary = {}
	for clearance in CLEARANCES:
		below[clearance] = {"pairs": 0, "seconds": 0.0, "clusters": 0}
	var samples_taken := 0
	var pairs_examined := 0
	var players_without_path := 0
	var players_with_path := 0
	var out_of_bounds := {"x": 0, "y": 0, "worst_x": 0.0, "worst_y": 0.0}
	var wrong_side := {"count": 0, "worst_meters": 0.0, "example": ""}
	var samples_by_action: Dictionary = {}

	for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = (seed_value % 2) == 0
		var result: Resource = manager.resolve_active_rally(seed_value)
		if result == null:
			continue
		var side_of := {}
		for raw_id in Dictionary(result.get("initial_home_positions")):
			side_of[int(raw_id)] = "home"
		for raw_id in Dictionary(result.get("initial_opponent_positions")):
			side_of[int(raw_id)] = "opponent"
		var paths := _collect_paths(result, side_of)
		for player_id in side_of:
			if paths.has(player_id) and not Array(paths[player_id]).is_empty():
				players_with_path += 1
			else:
				players_without_path += 1
		if paths.is_empty():
			continue
		var window := _window(paths)
		var start_time := float(window.x)
		var end_time := float(window.y)
		if end_time <= start_time:
			continue
		var t := start_time
		while t <= end_time:
			var live := {}
			for player_id in paths:
				var sample := _sample(paths[player_id], t)
				if sample.is_empty():
					continue
				live[player_id] = sample
			samples_taken += 1
			## A7 first: the court itself, per body per sample.
			for player_id in live:
				var position: Vector2 = live[player_id]["position"]
				if position.x < 0.0 or position.x > 1.0:
					out_of_bounds["x"] = int(out_of_bounds.x) + 1
					out_of_bounds["worst_x"] = maxf(
						float(out_of_bounds.worst_x),
						maxf(-position.x, position.x - 1.0) * 9.0
					)
				if position.y < 0.0 or position.y > 1.0:
					out_of_bounds["y"] = int(out_of_bounds.y) + 1
					out_of_bounds["worst_y"] = maxf(
						float(out_of_bounds.worst_y),
						maxf(-position.y, position.y - 1.0) * 18.0
					)
				## Crossing the net plane is not legal pursuit -- it is a body
				## inside the other team's court.
				var side := str(side_of.get(player_id, ""))
				var over := 0.0
				if side == "home" and position.y < 0.5:
					over = (0.5 - position.y) * 18.0
				elif side == "opponent" and position.y > 0.5:
					over = (position.y - 0.5) * 18.0
				if over > 0.01:
					wrong_side["count"] = int(wrong_side.count) + 1
					if over > float(wrong_side.worst_meters):
						wrong_side["worst_meters"] = over
						wrong_side["example"] = "seed %d, player %d, %s, %.2f m" % [
							seed_value, player_id, side, over,
						]
			## A6: same-team pairs only, both live at this instant.
			var ids: Array = live.keys()
			ids.sort()
			var near_counts := {}
			for i in range(ids.size()):
				for j in range(i + 1, ids.size()):
					var a := int(ids[i])
					var b := int(ids[j])
					if str(side_of.get(a, "?")) != str(side_of.get(b, "?")):
						continue
					pairs_examined += 1
					var separation := RallyKinematics.court_distance_meters(
						live[a]["position"], live[b]["position"]
					)
					pair_min.append(separation)
					var key := "%d|%d|%d" % [seed_value, a, b]
					if not closest.has(key) or separation < float(closest[key]):
						closest[key] = separation
					## **Parked or converging?** Two bodies sharing a point
					## because two maps handed them the same standing position is
					## a positioning defect; two bodies running into each other is
					## a coordination one. They need different repairs, so they
					## are counted apart rather than together.
					if separation < 0.50:
						var speed_a := Vector2(live[a]["velocity"]).length()
						var speed_b := Vector2(live[b]["velocity"]).length()
						var kind := "both_parked"
						if speed_a > 0.4 and speed_b > 0.4:
							kind = "both_moving"
						elif speed_a > 0.4 or speed_b > 0.4:
							kind = "one_moving"
						samples_by_action[kind] = int(
							samples_by_action.get(kind, 0)
						) + 1
					for clearance in CLEARANCES:
						if separation < clearance:
							var bucket: Dictionary = below[clearance]
							bucket["pairs"] = int(bucket.pairs) + 1
							bucket["seconds"] = float(bucket.seconds) + STEP_SECONDS
							near_counts[a] = int(near_counts.get(a, 0)) + 1
							near_counts[b] = int(near_counts.get(b, 0)) + 1
			## Three or more mutually close bodies at one instant.
			for clearance in CLEARANCES:
				var crowded := 0
				for player_id in near_counts:
					if int(near_counts[player_id]) >= 2:
						crowded += 1
				if crowded >= 3:
					var bucket: Dictionary = below[clearance]
					bucket["clusters"] = int(bucket.clusters) + 1
					break
			t += STEP_SECONDS

	pair_min.sort()
	print("=== A6 same-team separation, %d rallies, %.0f ms steps ===" % [
		SEED_COUNT, STEP_SECONDS * 1000.0,
	])
	print("samples|%d" % samples_taken)
	print("pair_observations|%d" % pairs_examined)
	print("players_with_published_path|%d" % players_with_path)
	print("players_without_published_path|%d" % players_without_path)
	if not pair_min.is_empty():
		print("separation_m_min|%.3f" % pair_min[0])
		print("separation_m_p01|%.3f" % _percentile(pair_min, 0.01))
		print("separation_m_p05|%.3f" % _percentile(pair_min, 0.05))
		print("separation_m_p50|%.3f" % _percentile(pair_min, 0.50))
	print("clearance_m|pair_samples_below|seconds_below|instants_with_3plus")
	for clearance in CLEARANCES:
		var bucket: Dictionary = below[clearance]
		print("%.2f|%d|%.2f|%d" % [
			clearance, int(bucket.pairs), float(bucket.seconds),
			int(bucket.clusters),
		])
	var worst: Array = closest.values()
	worst.sort()
	print("--- pair-samples below 0.50 m, by what the two bodies were doing")
	var kinds: Array = samples_by_action.keys()
	kinds.sort()
	for kind in kinds:
		print("  %s|%d" % [str(kind), int(samples_by_action[kind])])
	print("--- closest approach per rally-pair, worst 8")
	for index in range(mini(8, worst.size())):
		print("  %.3f m" % float(worst[index]))
	print("")
	print("=== A7 court and environment ===")
	print("samples_outside_x_bounds|%d" % int(out_of_bounds.x))
	print("worst_x_excursion_m|%.2f" % float(out_of_bounds.worst_x))
	print("samples_outside_y_bounds|%d" % int(out_of_bounds.y))
	print("worst_y_excursion_m|%.2f" % float(out_of_bounds.worst_y))
	print("samples_past_the_net_plane|%d" % int(wrong_side.count))
	print("worst_net_incursion_m|%.2f" % float(wrong_side.worst_meters))
	print("worst_case|%s" % str(wrong_side.example))
	quit()


## Every path any of the four publishers put on any event, per player.
func _collect_paths(result: Resource, side_of: Dictionary) -> Dictionary:
	var paths := {}
	for event in result.events:
		if event == null:
			continue
		var metadata: Dictionary = event.metadata
		var actor_id := int(event.actor_id)
		if actor_id >= 0 and metadata.get("movement_path", null) != null:
			_append(paths, actor_id, metadata["movement_path"])
		var staged := int(metadata.get("staged_next_actor_id", -1))
		if staged >= 0 and metadata.get("staged_next_path", null) != null:
			_append(paths, staged, metadata["staged_next_path"])
		for side in ["home", "opponent"]:
			var intents: Variant = metadata.get("%s_phase_intents" % side, {})
			if intents is Dictionary:
				for raw_id in Dictionary(intents):
					var entry: Variant = Dictionary(intents)[raw_id]
					if entry is Dictionary and entry.get("path", null) != null:
						_append(paths, int(raw_id), entry["path"])
			var holds: Variant = metadata.get("%s_phase_hold_paths" % side, {})
			if holds is Dictionary:
				for raw_id in Dictionary(holds):
					if Dictionary(holds)[raw_id] != null:
						_append(paths, int(raw_id), Dictionary(holds)[raw_id])
	return paths


func _append(paths: Dictionary, player_id: int, path: Variant) -> void:
	var typed := path as RallyMovementPath
	if typed == null or not typed.is_valid():
		return
	if not paths.has(player_id):
		paths[player_id] = []
	Array(paths[player_id]).append(typed)


func _window(paths: Dictionary) -> Vector2:
	var lowest := INF
	var highest := -INF
	for player_id in paths:
		for path in Array(paths[player_id]):
			var typed := path as RallyMovementPath
			lowest = minf(lowest, typed.start_time)
			highest = maxf(highest, typed.end_time())
	return Vector2(lowest, highest)


## Where this body is at `t`, or nothing if no leg of its own covers that
## instant. A body between legs is deliberately not interpolated: inventing a
## position is exactly what this audit exists to detect.
func _sample(legs: Variant, t: float) -> Dictionary:
	for path in Array(legs):
		var typed := path as RallyMovementPath
		if typed == null:
			continue
		if t >= typed.start_time and t <= typed.end_time():
			return typed.sample(t)
	return {}


func _percentile(sorted_values: Array, fraction: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index := int(clampf(
		round(fraction * float(sorted_values.size() - 1)),
		0.0, float(sorted_values.size() - 1),
	))
	return float(sorted_values[index])
