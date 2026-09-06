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

## Two legs closer together than this are one journey continuing; further apart,
## the body had unpublished time in between and any distance it covered is
## legal travel rather than a discontinuity.
const ADJACENT_SECONDS: float = 0.10

## Centre-to-centre separations to report. 0.72 m is two of the only body
## dimension in the repo; the other two bracket it.
const CLEARANCES: Array[float] = [0.50, 0.72, 0.90]

## Which publisher produced each path, so a discontinuity can be attributed.
var _source_of: Dictionary = {}


func _initialize() -> void:
	## Sample size is an argument because the context census showed
	## ATTACK_COVERAGE occurring twice in 120 rallies, and the spec asks for more
	## exercise where a class is rare rather than a conclusion drawn from two.
	var rallies := SEED_COUNT
	for entry in OS.get_cmdline_user_args():
		var pair: PackedStringArray = str(entry).split("=", true, 1)
		if pair.size() == 2 and pair[0] == "rallies":
			rallies = maxi(int(pair[1]), 1)
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
	var by_action: Dictionary = {}
	## A2: does leg N+1 begin where leg N landed, and carrying what it carried?
	var context_census: Dictionary = {}
	var rally_lengths: Array[int] = []
	var gap_sources: Dictionary = {}
	## Per publisher pair, of the boundaries whose predecessor ended moving: how
	## many kept the momentum and how many dropped it.
	var drop_sources: Dictionary = {}
	var continuity := {
		"pairs": 0, "gap": 0.0, "worst_gap": 0.0, "worst_note": "", "big_gaps": 0,
		"adjacent_pairs": 0, "adjacent_big": 0, "worst_adjacent": 0.0,
		"worst_adjacent_note": "",
		"cold_starts": 0, "hot_ends": 0,
	}

	for seed_value in range(FIRST_SEED, FIRST_SEED + rallies):
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
		var timeline := _action_timeline(result)
		## Context census: which movement classes this sample actually exercises,
		## so "rare class insufficiently exercised" is a measurement rather than
		## an impression.
		var contacts := 0
		for event in result.events:
			if event == null:
				continue
			var name := str(RallyEventScript.EventType.keys()[
				int(event.event_type)
			])
			context_census[name] = int(context_census.get(name, 0)) + 1
			contacts += 1
		rally_lengths.append(contacts)
		var paths := _collect_paths(result, side_of)
		for player_id in side_of:
			if paths.has(player_id) and not Array(paths[player_id]).is_empty():
				players_with_path += 1
			else:
				players_without_path += 1
		if paths.is_empty():
			continue
		for player_id in paths:
			var legs: Array = Array(paths[player_id]).duplicate()
			legs.sort_custom(func(a, b):
				return (a as RallyMovementPath).start_time \
					< (b as RallyMovementPath).start_time
			)
			for index in range(legs.size() - 1):
				var first := legs[index] as RallyMovementPath
				var second := legs[index + 1] as RallyMovementPath
				## Only genuinely consecutive legs: an overlapping pair is two
				## publishers describing the same window, which A4 counts.
				if second.start_time < first.end_time() - 0.001:
					continue
				continuity["pairs"] = int(continuity.pairs) + 1
				var gap := RallyKinematics.court_distance_meters(
					first.landing_position(), second.start_position()
				)
				continuity["gap"] = float(continuity.gap) + gap
				var idle_seconds := second.start_time - first.end_time()
				if gap > float(continuity.worst_gap):
					continuity["worst_gap"] = gap
					## Named, because a worst case that cannot be reproduced is an
					## anecdote. C1 moved this tail and the total could not say why.
					continuity["worst_note"] = \
						"seed %d, player %d, %s -> %s, %.3f s apart" % [
							seed_value, int(player_id),
							str(_source_of.get(first, "?")),
							str(_source_of.get(second, "?")),
							idle_seconds,
						]
				## **Two different things were being called one number.**
				##
				## This loop skips only *overlapping* legs, so a pair separated by
				## seconds of rally clock still counts as consecutive -- and a body
				## with three seconds of unpublished interval between its legs walks
				## metres perfectly legally. That is a publication-coverage finding,
				## not a teleport, and it was dominating `gap_m_worst`: the worst
				## case sat 3.128 s apart.
				##
				## A discontinuity proper is leg N ending and leg N+1 beginning
				## somewhere else *at the same instant*. Only the adjacent figure
				## measures that.
				## NOTE the split, and why the tail moved -- EMBODIED_MOVEMENT_CONTINUITY.md C1.7
				if idle_seconds <= ADJACENT_SECONDS:
					continuity["adjacent_pairs"] = int(continuity.adjacent_pairs) + 1
					if gap > float(continuity.worst_adjacent):
						continuity["worst_adjacent"] = gap
						continuity["worst_adjacent_note"] = \
							"seed %d, player %d, %s -> %s, %.3f s apart" % [
								seed_value, int(player_id),
								str(_source_of.get(first, "?")),
								str(_source_of.get(second, "?")),
								idle_seconds,
							]
					if gap > 0.10:
						continuity["adjacent_big"] = int(continuity.adjacent_big) + 1
				if gap > 0.10:
					continuity["big_gaps"] = int(continuity.big_gaps) + 1
					var pair_key := "%s -> %s" % [
						str(_source_of.get(first, "?")),
						str(_source_of.get(second, "?")),
					]
					gap_sources[pair_key] = int(
						gap_sources.get(pair_key, 0)
					) + 1
				var ended_moving := first.exit_velocity.length() > 0.4
				var started_cold := second.velocities.size() > 0 \
					and Vector2(second.velocities[0]).length() <= 0.01
				if ended_moving:
					continuity["hot_ends"] = int(continuity.hot_ends) + 1
				if started_cold:
					continuity["cold_starts"] = int(continuity.cold_starts) + 1
				## The C1 gate's question: where a body *had* momentum, which
				## publisher pair kept it and which dropped it. The total says a
				## carry exists; only this says which boundary is still unwired.
				## NOTE classification, not a count -- EMBODIED_MOVEMENT_CONTINUITY.md C1.5
				if ended_moving:
					var carry_key := "%s -> %s" % [
						str(_source_of.get(first, "?")),
						str(_source_of.get(second, "?")),
					]
					var bucket: Dictionary = drop_sources.get(
						carry_key, {"dropped": 0, "kept": 0}
					)
					if started_cold:
						bucket["dropped"] = int(bucket.dropped) + 1
					else:
						bucket["kept"] = int(bucket.kept) + 1
					drop_sources[carry_key] = bucket
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
			## Separations first, clusters second. The previous version counted
			## adjacency inside the clearance loop, so `near_counts` accumulated
			## once per clearance a pair fell under and the `break` let only the
			## tightest clearance ever record -- which is why 0.72 m and 0.90 m
			## reported *fewer* clusters than 0.50 m, an impossibility that is
			## how the bug announced itself.
			var separations := {}
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
					separations["%d|%d" % [a, b]] = separation
					pair_min.append(separation)
					var key := "%d|%d|%d" % [seed_value, a, b]
					if not closest.has(key) or separation < float(closest[key]):
						closest[key] = separation
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
						var action := _action_at(timeline, t)
						var action_key := "%s|%s" % [
							action, str(side_of.get(a, "?"))
						]
						by_action[action_key] = int(
							by_action.get(action_key, 0)
						) + 1
			for clearance in CLEARANCES:
				var adjacency := {}
				for pair_key in separations:
					if float(separations[pair_key]) >= clearance:
						continue
					var parts: PackedStringArray = str(pair_key).split("|")
					var a := int(parts[0])
					var b := int(parts[1])
					adjacency[a] = int(adjacency.get(a, 0)) + 1
					adjacency[b] = int(adjacency.get(b, 0)) + 1
					var bucket: Dictionary = below[clearance]
					bucket["pairs"] = int(bucket.pairs) + 1
					bucket["seconds"] = float(bucket.seconds) + STEP_SECONDS
				## A cluster is three bodies each close to at least two others at
				## this instant, which is what "three in one another's way" means.
				var crowded := 0
				for player_id in adjacency:
					if int(adjacency[player_id]) >= 2:
						crowded += 1
				if crowded >= 3:
					var bucket2: Dictionary = below[clearance]
					bucket2["clusters"] = int(bucket2.clusters) + 1
			t += STEP_SECONDS

	pair_min.sort()
	print("=== A6 same-team separation, %d rallies, %.0f ms steps ===" % [
		rallies, STEP_SECONDS * 1000.0,
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
	print("--- pair-samples below 0.50 m, by the flight being drawn and side")
	var action_keys: Array = by_action.keys()
	action_keys.sort_custom(func(a, b): return int(by_action[a]) > int(by_action[b]))
	for index in range(mini(12, action_keys.size())):
		print("  %s|%d" % [str(action_keys[index]), int(by_action[action_keys[index]])])
	print("--- pair-samples below 0.50 m, by what the two bodies were doing")
	var kinds: Array = samples_by_action.keys()
	kinds.sort()
	for kind in kinds:
		print("  %s|%d" % [str(kind), int(samples_by_action[kind])])
	print("--- closest approach per rally-pair, worst 8")
	for index in range(mini(8, worst.size())):
		print("  %.3f m" % float(worst[index]))
	print("")
	print("=== context census: what these %d rallies exercised ===" % rallies)
	var census_keys: Array = context_census.keys()
	census_keys.sort_custom(func(a, b):
		return int(context_census[a]) > int(context_census[b])
	)
	for key in census_keys:
		print("  %s|%d" % [str(key), int(context_census[key])])
	rally_lengths.sort()
	if not rally_lengths.is_empty():
		print("  rally contacts min|%d" % rally_lengths[0])
		print("  rally contacts median|%d" % rally_lengths[rally_lengths.size() / 2])
		print("  rally contacts max|%d" % rally_lengths[rally_lengths.size() - 1])
		var long_rallies := rally_lengths.filter(func(n): return n >= 8).size()
		print("  rallies with 8+ contacts|%d of %d" % [
			long_rallies, rally_lengths.size(),
		])
	print("")
	print("=== A2 leg-to-leg continuity, from published paths ===")
	print("consecutive_leg_pairs|%d" % int(continuity.pairs))
	print("gap_m_mean|%.4f" % (
		float(continuity.gap) / maxf(float(continuity.pairs), 1.0)
	))
	print("gap_m_worst|%.4f|%s" % [
		float(continuity.worst_gap), str(continuity.worst_note),
	])
	print("pairs_with_gap_over_10cm|%d" % int(continuity.big_gaps))
	print("--- legs that actually adjoin (<= %.2f s apart): the real discontinuities"
		% ADJACENT_SECONDS)
	print("adjacent_pairs|%d of %d" % [
		int(continuity.adjacent_pairs), int(continuity.pairs),
	])
	print("adjacent_gap_over_10cm|%d" % int(continuity.adjacent_big))
	print("adjacent_gap_worst|%.4f|%s" % [
		float(continuity.worst_adjacent), str(continuity.worst_adjacent_note),
	])
	print("next_leg_starts_at_rest|%d of %d" % [
		int(continuity.cold_starts), int(continuity.pairs),
	])
	print("previous_leg_ended_moving|%d" % int(continuity.hot_ends))
	print("--- gaps over 10 cm, by which publishers the two legs came from")
	var gap_keys: Array = gap_sources.keys()
	gap_keys.sort_custom(func(a, b): return int(gap_sources[a]) > int(gap_sources[b]))
	for key in gap_keys:
		print("  %s|%d" % [str(key), int(gap_sources[key])])
	print("--- boundaries whose predecessor ended moving: kept vs dropped")
	var drop_keys: Array = drop_sources.keys()
	drop_keys.sort_custom(func(a, b):
		return int(Dictionary(drop_sources[a]).dropped) \
			> int(Dictionary(drop_sources[b]).dropped)
	)
	for key in drop_keys:
		var bucket: Dictionary = drop_sources[key]
		var kept := int(bucket.kept)
		var dropped := int(bucket.dropped)
		print("  %s|dropped %d|kept %d|%.0f%% carried" % [
			str(key), dropped, kept,
			100.0 * float(kept) / maxf(float(kept + dropped), 1.0),
		])
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


## Which contact the rally is between at a given instant, so a conflict can be
## attributed to the phase that produced it rather than reported as an average.
func _action_timeline(result: Resource) -> Array:
	var entries: Array = []
	for event in result.events:
		if event == null:
			continue
		entries.append({
			"time": float(event.metadata.get("physical_time", 0.0)),
			"action": str(RallyEventScript.EventType.keys()[
				int(event.event_type)
			]),
		})
	entries.sort_custom(func(a, b): return float(a.time) < float(b.time))
	return entries


func _action_at(timeline: Array, t: float) -> String:
	var current := "pre_serve"
	for entry in timeline:
		if float(entry.time) <= t:
			current = str(entry.action)
		else:
			break
	return current


## Every path any of the four publishers put on any event, per player.
func _collect_paths(result: Resource, side_of: Dictionary) -> Dictionary:
	var paths := {}
	for event in result.events:
		if event == null:
			continue
		var metadata: Dictionary = event.metadata
		var actor_id := int(event.actor_id)
		if actor_id >= 0 and metadata.get("movement_path", null) != null:
			_append(paths, actor_id, metadata["movement_path"], "movement_path")
		var staged := int(metadata.get("staged_next_actor_id", -1))
		if staged >= 0 and metadata.get("staged_next_path", null) != null:
			_append(paths, staged, metadata["staged_next_path"], "staged_next")
		for side in ["home", "opponent"]:
			var intents: Variant = metadata.get("%s_phase_intents" % side, {})
			if intents is Dictionary:
				for raw_id in Dictionary(intents):
					var entry: Variant = Dictionary(intents)[raw_id]
					if entry is Dictionary and entry.get("path", null) != null:
						_append(paths, int(raw_id), entry["path"], "phase_intent")
			var holds: Variant = metadata.get("%s_phase_hold_paths" % side, {})
			if holds is Dictionary:
				for raw_id in Dictionary(holds):
					if Dictionary(holds)[raw_id] != null:
						_append(paths, int(raw_id), Dictionary(holds)[raw_id], "phase_hold")
	return paths


func _append(
	paths: Dictionary, player_id: int, path: Variant, source: String = "?"
) -> void:
	var typed := path as RallyMovementPath
	if typed == null or not typed.is_valid():
		return
	if not paths.has(player_id):
		paths[player_id] = []
	Array(paths[player_id]).append(typed)
	_source_of[typed] = source


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
