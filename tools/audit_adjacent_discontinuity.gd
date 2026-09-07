extends SceneTree

## The 217, classified.
##
## `audit_six_player_space.gd` counts adjacent discontinuities and names only the
## worst. That is enough to know the defect exists and not enough to fix it: the
## spec asks for every one traced to its earliest responsible layer, and for
## legitimate volleyball discontinuity to be told apart from simulation
## contradiction.
##
## A discontinuity here is leg N ending and leg N+1 beginning **somewhere else at
## the same instant** -- within `ADJACENT_SECONDS` -- with the endpoints more than
## 10 cm apart. The implied speed is what makes it a contradiction: a body cannot
## cross 5 m in 65 ms, so one of the two legs is lying about where the body is.
##
## Run:
##   godot --headless --path . --script res://tools/audit_adjacent_discontinuity.gd -- rallies=600

const GM := preload("res://scripts/managers/game_manager.gd")
const RallyKinematics := preload("res://scripts/simulation/rally_kinematics.gd")

const ADJACENT_SECONDS := 0.10
const BIG_METERS := 0.10
## Above this the join is not a fast body, it is two publishers disagreeing.
const IMPOSSIBLE_MPS := 12.0

var _source_of := {}
var _cue_of := {}
var _event_of := {}


func _initialize() -> void:
	var rallies := 600
	var base_seed := 61000
	for argument in OS.get_cmdline_user_args():
		var text := str(argument)
		if text.begins_with("rallies="):
			rallies = int(text.substr(8))
		elif text.begins_with("seed="):
			base_seed = int(text.substr(5))

	var manager: Object = GM.new()
	manager.seed_vertical_slice_data()

	var adjoining := 0
	var big := 0
	var by_pair := {}
	var by_cue_pair := {}
	var by_action := {}
	var by_side := {}
	var speeds := []
	var worst := 0.0
	var worst_note := ""
	var impossible := 0
	var plausible := 0
	var exact_zero_interval := 0

	for offset in rallies:
		var seed_value := base_seed + offset
		manager.match_state.serving_home = offset % 2 == 0
		var result: Variant = manager.resolve_active_rally(seed_value)
		if result == null:
			continue
		var side_of := _sides(manager)
		var paths := _collect_paths(result, side_of)
		for player_id in paths:
			var legs: Array = Array(paths[player_id]).duplicate()
			legs.sort_custom(func(a, b):
				return (a as RallyMovementPath).start_time \
					< (b as RallyMovementPath).start_time
			)
			for index in range(legs.size() - 1):
				var first := legs[index] as RallyMovementPath
				var second := legs[index + 1] as RallyMovementPath
				if second.start_time < first.end_time() - 0.001:
					continue
				var idle: float = second.start_time - first.end_time()
				if idle > ADJACENT_SECONDS:
					continue
				adjoining += 1
				var gap: float = RallyKinematics.court_distance_meters(
					first.landing_position(), second.start_position()
				)
				if gap <= BIG_METERS:
					continue
				big += 1
				if idle <= 0.0001:
					exact_zero_interval += 1
				var implied: float = gap / maxf(idle, 0.001)
				speeds.append(implied)
				if implied >= IMPOSSIBLE_MPS:
					impossible += 1
				else:
					plausible += 1
				var pair := "%s -> %s" % [
					str(_source_of.get(first, "?")), str(_source_of.get(second, "?")),
				]
				var cue_pair := "%s[%s] -> %s[%s]" % [
					str(_source_of.get(first, "?")), str(_cue_of.get(first, "-")),
					str(_source_of.get(second, "?")), str(_cue_of.get(second, "-")),
				]
				var action := "%s -> %s" % [
					str(_event_of.get(first, "?")), str(_event_of.get(second, "?")),
				]
				by_pair[pair] = int(by_pair.get(pair, 0)) + 1
				by_cue_pair[cue_pair] = int(by_cue_pair.get(cue_pair, 0)) + 1
				by_action[action] = int(by_action.get(action, 0)) + 1
				var side := str(side_of.get(int(player_id), "?"))
				by_side[side] = int(by_side.get(side, 0)) + 1
				if gap > worst:
					worst = gap
					worst_note = "seed %d, player %d, %s, %.4f s apart, %.1f m/s" % [
						seed_value, int(player_id), cue_pair, idle, implied,
					]

	print("=== adjacent discontinuity audit: %d rallies from seed %d ===" % [
		rallies, base_seed,
	])
	print("adjoining boundaries      %d" % adjoining)
	print("over %.2f m               %d (%.1f%% of adjoining)" % [
		BIG_METERS, big, 100.0 * float(big) / maxf(float(adjoining), 1.0),
	])
	print("  implying >= %.0f m/s     %d  <- contradiction, no body does this" % [
		IMPOSSIBLE_MPS, impossible,
	])
	print("  implying <  %.0f m/s     %d  <- fast, but a body could" % [
		IMPOSSIBLE_MPS, plausible,
	])
	print("  at exactly zero interval %d" % exact_zero_interval)
	print("worst %.3f m -- %s" % [worst, worst_note])
	speeds.sort()
	if not speeds.is_empty():
		print("implied speed p50 %.1f  p90 %.1f  max %.1f m/s" % [
			speeds[speeds.size() / 2], speeds[int(float(speeds.size()) * 0.9)],
			speeds[speeds.size() - 1],
		])
	_dump("by publisher pair", by_pair)
	_dump("by cue pair", by_cue_pair)
	_dump("by action pair", by_action)
	_dump("by side", by_side)
	quit()


func _dump(title: String, table: Dictionary) -> void:
	print("\n-- %s" % title)
	var keys: Array = table.keys()
	keys.sort_custom(func(a, b): return int(table[a]) > int(table[b]))
	var shown := 0
	for key in keys:
		print("   %-64s %d" % [key, table[key]])
		shown += 1
		if shown >= 18:
			print("   ... %d more" % (keys.size() - shown))
			break


func _sides(manager: Object) -> Dictionary:
	var side_of := {}
	for raw in manager.players:
		var player := raw as VolleyballPlayer
		if player != null:
			side_of[player.id] = "home"
	if manager.opponent_team != null:
		for raw in manager.opponent_team.on_court_players():
			var player := raw as VolleyballPlayer
			if player != null:
				side_of[player.id] = "opponent"
	return side_of


func _collect_paths(result: Resource, _side_of: Dictionary) -> Dictionary:
	var paths := {}
	for event in result.events:
		if event == null:
			continue
		var metadata: Dictionary = event.metadata
		var action := str(RallyEvent.EventType.keys()[event.event_type])
		var actor_id := int(event.actor_id)
		if actor_id >= 0 and metadata.get("movement_path", null) != null:
			_append(paths, actor_id, metadata["movement_path"], "movement_path", action)
		var staged := int(metadata.get("staged_next_actor_id", -1))
		if staged >= 0 and metadata.get("staged_next_path", null) != null:
			_append(paths, staged, metadata["staged_next_path"], "staged_next", action)
		for side in ["home", "opponent"]:
			var intents: Variant = metadata.get("%s_phase_intents" % side, {})
			if intents is Dictionary:
				for raw_id in Dictionary(intents):
					var entry: Variant = Dictionary(intents)[raw_id]
					if entry is Dictionary and entry.get("path", null) != null:
						_append(
							paths, int(raw_id), entry["path"], "phase_intent", action
						)
						_cue_of[entry["path"]] = str(entry.get("intent", "?"))
			var holds: Variant = metadata.get("%s_phase_hold_paths" % side, {})
			if holds is Dictionary:
				for raw_id in Dictionary(holds):
					if Dictionary(holds)[raw_id] != null:
						_append(
							paths, int(raw_id), Dictionary(holds)[raw_id],
							"phase_hold", action,
						)
	return paths


func _append(
	paths: Dictionary, player_id: int, path: Variant, source: String, action: String
) -> void:
	var typed := path as RallyMovementPath
	if typed == null or not typed.is_valid():
		return
	if not paths.has(player_id):
		paths[player_id] = []
	Array(paths[player_id]).append(typed)
	_source_of[typed] = source
	_event_of[typed] = action
