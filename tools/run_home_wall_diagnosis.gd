extends SceneTree

## Why does the home wall fail to form on roughly a quarter of opponent swings,
## when the opponent's wall never does?
##
##     godot --headless --path . --script res://tools/run_home_wall_diagnosis.gd
##
## `docs/BACKLOG.md` records the figure and names this as the next step:
##
##   > why the wall was missed (opponent swings, 120)
##   >   (none)=39   around=30   no wall=31   over=14   contacted=6
##   >
##   > The home wall does not form at all on 31 of 120 opponent swings, and is
##   > beaten around on 30 more. The equivalent row for the opponent's wall
##   > carries no "no wall" at all. That is the defect, and it sits upstream of
##   > every band.
##
## Three flags and tasks #62-#64 are held behind it, on the reasoning that the
## block's outcome bands cannot be separated while one wall barely participates.
##
## `"no wall"` is produced by `AttackResolutionModel` when the blockers array is
## empty, and `GeometricAttackPromotion.block_wall` drops any blocker whose close
## fraction is below `WALL_JOIN_CLOSE` (0.34). So for the home side it means one
## of exactly two things, and they want opposite fixes:
##
##   A. **nobody was assigned** -- `front_blockers` was empty, which for the home
##      former can happen because the defensive plan's `block_participation` can
##      exclude a front-row player. The opponent former has no such filter.
##
##   B. **nobody arrived** -- a primary existed and closed under 0.34.
##
## This probe separates them, and then asks what drove B.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)

## **The same population `tools/run_block_band_probe.gd` measures**, and that is
## deliberate: the first draft of this probe ran the raw vertical slice and found
## *zero* "no wall" rows, which contradicted the recorded 31-of-120 and would
## have been reported as "already fixed". The band probe applies generated
## attributes to both rosters and sets a block intent per rotation, and it reads
## the **BLOCK** event rather than the ATTACK event. Two different populations
## and two different event streams; only one of them is the one the figure came
## from. Matching it is not optional.
const ROSTER_SEEDS: Array[int] = [900006, 901006, 902006, 903006]
const RALLIES: int = 150


func _initialize() -> void:
	_diagnose()
	_asymmetry()
	quit()


func _percentiles(values: Array, label: String) -> void:
	if values.is_empty():
		print("  %-26s (no sample)" % label)
		return
	var sorted := values.duplicate()
	sorted.sort()
	var picks := []
	for fraction in [0.10, 0.25, 0.50, 0.75, 0.90]:
		var index := clampi(
			int(round(float(fraction) * (sorted.size() - 1))), 0, sorted.size() - 1
		)
		picks.append("%.3f" % float(sorted[index]))
	print("  %-26s n=%-5d p10 %s  p25 %s  p50 %s  p75 %s  p90 %s" % [
		label, sorted.size(), picks[0], picks[1], picks[2], picks[3], picks[4],
	])


func _diagnose() -> void:
	print("=".repeat(78))
	print("HOME WALL -- why it is not there")
	print("=".repeat(78))
	var swings := 0
	var miss_reasons := {}
	var no_wall_unassigned := 0
	var no_wall_no_arrival := 0
	var no_wall_other := 0
	var primary_close_all: Array = []
	var primary_close_no_wall: Array = []
	var distance_no_wall: Array = []
	var distance_walled: Array = []
	var required_no_wall: Array = []
	var usable_no_wall: Array = []
	var deficit_no_wall: Array = []
	var displaced_no_wall: Array = []
	var displaced_walled: Array = []
	var preset_no_wall: Array = []
	var preset_walled: Array = []
	var flight_no_wall: Array = []
	var flight_walled: Array = []
	var required_walled: Array = []
	var usable_walled: Array = []
	var front_counts := {}
	var wall_sizes := {}
	for roster_seed in ROSTER_SEEDS:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		ExecutionScale.apply_generated_attributes(manager.players, roster_seed)
		ExecutionScale.apply_generated_attributes(
			manager.opponent_team.players, roster_seed
		)
		for serving_home in [true, false]:
			manager.match_state.serving_home = serving_home
			for seed_value in range(5000, 5000 + RALLIES):
				var rally: Resource = manager.resolve_active_rally(seed_value)
				if rally == null:
					continue
				## The miss reason lives on the home BLOCK event and the formation
				## terms on the ATTACK event that produced it, so the two are
				## joined per rally rather than read from one stream.
				var terms := {}
				var wall_size := 0
				for event in rally.events:
					var typed := event as RallyEvent
					if typed == null:
						continue
					if typed.event_type == RallyEventScript.EventType.ATTACK \
							and typed.metadata.has("home_block_terms"):
						terms = Dictionary(typed.metadata["home_block_terms"])
						wall_size = int(typed.metadata.get("wall_size", 0))
						continue
					if typed.event_type != RallyEventScript.EventType.BLOCK \
							or str(typed.metadata.get("side", "")) != "home":
						continue
					swings += 1
					var reason := ""
					if str(typed.metadata.get("outcome", "miss")) == "miss":
						reason = str(typed.metadata.get(
							"block_miss_reason", "unknown"
						))
					var key := reason if reason != "" else "(contacted)"
					miss_reasons[key] = int(miss_reasons.get(key, 0)) + 1
					if terms.is_empty():
						## The BLOCK event exists but no ATTACK carried the terms.
						## Counted rather than skipped -- a swing this probe cannot
						## attribute is a fact about the publication, not a gap to
						## quietly drop.
						miss_reasons["(no terms published)"] = int(
							miss_reasons.get("(no terms published)", 0)
						) + 1
						continue
					var front := int(terms.get("front_blockers", 0))
					front_counts[front] = int(front_counts.get(front, 0)) + 1
					wall_sizes[wall_size] = int(wall_sizes.get(wall_size, 0)) + 1
					var close := float(terms.get("primary_close", 0.0))
					var close_terms: Dictionary = terms.get("primary_close_terms", {})
					primary_close_all.append(close)
					if reason == "no wall":
						primary_close_no_wall.append(close)
						if front == 0:
							no_wall_unassigned += 1
						elif close < 0.34:
							no_wall_no_arrival += 1
						else:
							no_wall_other += 1
						distance_no_wall.append(float(close_terms.get(
							"footwork_meters", 0.0
						)))
						required_no_wall.append(float(close_terms.get(
							"required_seconds", 0.0
						)))
						usable_no_wall.append(float(close_terms.get(
							"usable_time", 0.0
						)))
						deficit_no_wall.append(float(close_terms.get(
							"deficit_seconds", 0.0
						)))
						displaced_no_wall.append(absf(
							float(close_terms.get("start_x", 0.0))
							- float(close_terms.get("slot_x", 0.0))
						) * 9.0)
						preset_no_wall.append(float(terms.get(
							"preset_window_seconds", 0.0
						)))
						flight_no_wall.append(float(terms.get(
							"set_flight_seconds", 0.0
						)))
					elif wall_size > 0:
						distance_walled.append(float(close_terms.get(
							"footwork_meters", 0.0
						)))
						required_walled.append(float(close_terms.get(
							"required_seconds", 0.0
						)))
						usable_walled.append(float(close_terms.get(
							"usable_time", 0.0
						)))
						displaced_walled.append(absf(
							float(close_terms.get("start_x", 0.0))
							- float(close_terms.get("slot_x", 0.0))
						) * 9.0)
						preset_walled.append(float(terms.get(
							"preset_window_seconds", 0.0
						)))
						flight_walled.append(float(terms.get(
							"set_flight_seconds", 0.0
						)))
		manager.free()
	print("  home BLOCK events observed: %d\n" % swings)
	print("  %-26s %s" % ["block_miss_reason", "count"])
	var reason_keys := miss_reasons.keys()
	reason_keys.sort()
	for key in reason_keys:
		print("  %-26s %d" % [str(key), int(miss_reasons[key])])

	print("\n  %-42s %d" % ["\"no wall\" -- nobody assigned (front=0)", no_wall_unassigned])
	print("  %-42s %d" % ["\"no wall\" -- nobody arrived (close<0.34)", no_wall_no_arrival])
	print("  %-42s %d" % ["\"no wall\" -- neither (unexplained)", no_wall_other])

	print("\n  front-row blockers offered to the wall:")
	var front_keys := front_counts.keys()
	front_keys.sort()
	for key in front_keys:
		print("    %d blockers   %d swings" % [int(key), int(front_counts[key])])
	print("  wall size the swing actually met:")
	var size_keys := wall_sizes.keys()
	size_keys.sort()
	for key in size_keys:
		print("    %d in wall    %d swings" % [int(key), int(wall_sizes[key])])

	print("\n  distributions:")
	_percentiles(primary_close_all, "primary_close, all")
	_percentiles(primary_close_no_wall, "primary_close, no wall")
	print("")
	_percentiles(distance_walled, "footwork m, wall formed")
	_percentiles(distance_no_wall, "footwork m, no wall")
	_percentiles(required_walled, "required s, wall formed")
	_percentiles(required_no_wall, "required s, no wall")
	_percentiles(usable_walled, "usable s, wall formed")
	_percentiles(usable_no_wall, "usable s, no wall")
	_percentiles(deficit_no_wall, "deficit s, no wall")
	print("")
	## The two candidate drivers, separated: was the blocker standing somewhere
	## else, or was there simply less time?
	_percentiles(displaced_walled, "displaced m, wall formed")
	_percentiles(displaced_no_wall, "displaced m, no wall")
	_percentiles(preset_walled, "preset window s, formed")
	_percentiles(preset_no_wall, "preset window s, no wall")
	_percentiles(flight_walled, "set flight s, formed")
	_percentiles(flight_no_wall, "set flight s, no wall")


## And the structural difference between the two formers, read off the source
## rather than inferred from the counts.
func _asymmetry() -> void:
	print("\n" + "=".repeat(78))
	print("THE TWO FORMERS, SIDE BY SIDE")
	print("=".repeat(78))
	print("  %-30s %-22s %-22s" % ["", "_form_home_block", "_form_opponent_block"])
	for row in [
		["front-row filter", "block_participation", "none"],
		["blocker start position", "live_positions", "slot_position"],
		["primary chosen on", "slot_position.x", "slot_position.x"],
		["closes from", "live_positions", "slot fallback"],
	]:
		print("  %-30s %-22s %-22s" % [str(row[0]), str(row[1]), str(row[2])])
	print("")
	print("  Two candidate causes, and the counts above say which is live:")
	print("")
	print("  1. The home former drops a front-row player when the defensive")
	print("     plan's `block_participation` is false. The opponent former has")
	print("     no such filter -- every front-row body blocks, always.")
	print("")
	print("  2. The home wall closes from `live_positions`; the opponent's")
	print("     closes from the rotation slot. `_blocker_close_terms` looks its")
	print("     start up in `live_positions`, which is the *home* dictionary --")
	print("     an opponent id misses it and falls back to the slot. So one wall")
	print("     pays for where its bodies actually are and the other never does.")
