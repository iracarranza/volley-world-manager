extends SceneTree

## The two distributions the block's outcome bands cut.
##
## Under `ENABLE_GEOMETRIC_ATTACK` the outcome is not a margin comparison any
## more. `AttackResolutionModel._block_contact` sorts a contacted ball three
## ways:
##
##   edge_gap  < TOOL_EDGE_MARGIN_METERS   -> tool   (the hitter's point)
##   depth     > STUFF_DEPTH_METERS        -> stuff  (the block's point)
##   otherwise                             -> touch  (the rally continues)
##
## Both quantities were computed inside that function and consumed there, so
## neither band had ever been checked against the spread it divides -- the defect
## this repository has now found six times, and the only one that produces a
## band that silently never fires.
##
## Run with the offence flags both ways: a wall calibrated against a side that
## only hit pins is being asked to solve first-tempo balls once
## `ENABLE_HOME_MIDDLE_OFFENSE` is on, and that is the whole reason the intent
## gates started failing.
##
## Run:
##   godot --headless --path . --script res://tools/run_block_geometry_bands.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const AttackResolution := preload(
	"res://scripts/simulation/attack_resolution_model.gd"
)

const RALLIES: int = 150


func _initialize() -> void:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	ExecutionScale.apply_generated_attributes(manager.players, 900006)
	ExecutionScale.apply_generated_attributes(
		manager.opponent_team.players, 900006
	)
	var depths := {"home": [], "opponent": []}
	var gaps := {"home": [], "opponent": []}
	var kinds := {"home": {}, "opponent": {}}
	var swings := {"home": 0, "opponent": 0}
	var misses := {"home": {}, "opponent": {}}
	var walls := {"home": {}, "opponent": {}}
	for serving_home in [true, false]:
		manager.match_state.serving_home = serving_home
		for seed_value in range(5000, 5000 + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			for raw in result.events:
				var event := raw as RallyEvent
				if event == null \
						or event.event_type != RallyEventScript.EventType.ATTACK:
					continue
				var side := str(event.metadata.get("side", ""))
				if not depths.has(side):
					continue
				swings[side] = int(swings[side]) + 1
				var wall_size := int(event.metadata.get("wall_size", -1))
				walls[side][wall_size] = int(walls[side].get(wall_size, 0)) + 1
				var reason := str(event.metadata.get("block_miss_reason", ""))
				var kind := str(event.metadata.get("block_contact_kind", ""))
				if kind.is_empty():
					## Why the wall was not touched. A band cannot be tuned against
					## a sample of six, and the reason the sample is six is not a
					## property of the bands.
					misses[side][reason] = int(misses[side].get(reason, 0)) + 1
					continue
				kinds[side][kind] = int(kinds[side].get(kind, 0)) + 1
				if event.metadata.get("block_depth_below_reach_meters", null) != null:
					depths[side].append(float(
						event.metadata.block_depth_below_reach_meters
					))
				if event.metadata.get("block_edge_gap_meters", null) != null:
					gaps[side].append(float(event.metadata.block_edge_gap_meters))
	manager.free()

	print("Block geometry bands -- %d rallies x 2 serving sides" % RALLIES)
	print("")
	print("stuff depth  %.3f m      tool edge margin  %.3f m" % [
		AttackResolution.STUFF_DEPTH_METERS,
		AttackResolution.TOOL_EDGE_MARGIN_METERS,
	])
	print("")
	print("Outcomes per side. `blocker` is the wall that contested the swing, so")
	print("the home row is the *opponent's* wall against home attacks.")
	print("")
	print("%-10s %8s %9s %8s %8s %8s" % [
		"attacked", "swings", "contacted", "stuff", "touch", "tool"])
	for side in ["home", "opponent"]:
		var contacted := 0
		for key in kinds[side]:
			contacted += int(kinds[side][key])
		print("%-10s %8d %9d %8d %8d %8d" % [
			side, int(swings[side]), contacted,
			int(kinds[side].get("stuff", 0)),
			int(kinds[side].get("touch", 0)),
			int(kinds[side].get("tool", 0)),
		])
	print("")
	print("how many blockers were in the wall at all")
	for side in ["home", "opponent"]:
		var keys: Array = walls[side].keys()
		keys.sort()
		var line := "  %-9s" % side
		var total := 0
		for key in keys:
			total += int(walls[side][key])
		for key in keys:
			line += " %d=%d (%.0f%%)" % [
				int(key), int(walls[side][key]),
				float(walls[side][key]) / maxf(float(total), 1.0) * 100.0,
			]
		print(line)
	print("")
	print("why the wall was missed")
	for side in ["home", "opponent"]:
		var keys: Array = misses[side].keys()
		keys.sort()
		var line := "  %-9s" % side
		for key in keys:
			line += " %s=%d" % [
				str(key) if not str(key).is_empty() else "(none)",
				int(misses[side][key]),
			]
		print(line)
	print("")
	print("Depth below the hands, for every contacted ball. STUFF_DEPTH_METERS")
	print("cuts this -- a band above the p90 makes stuffs impossible, one below")
	print("the p10 makes touches impossible.")
	print("")
	_report(depths, AttackResolution.STUFF_DEPTH_METERS)
	print("")
	print("Edge gap. TOOL_EDGE_MARGIN_METERS cuts this.")
	print("")
	_report(gaps, AttackResolution.TOOL_EDGE_MARGIN_METERS)
	print("")
	print("A band inside the spread divides it. A band outside it is a constant")
	print("answer wearing a threshold's name.")
	quit()


func _report(pools: Dictionary, band: float) -> void:
	print("%-10s %6s %8s %8s %8s %8s %8s %10s" % [
		"attacked", "n", "p10", "p25", "p50", "p75", "p90", "above band"])
	for side in ["home", "opponent"]:
		var pool: Array = pools[side]
		if pool.is_empty():
			print("%-10s (none)" % side)
			continue
		pool.sort()
		var above := 0
		for value in pool:
			if float(value) > band:
				above += 1
		print("%-10s %6d %8.3f %8.3f %8.3f %8.3f %8.3f %9.0f%%" % [
			side, pool.size(), _p(pool, 0.10), _p(pool, 0.25), _p(pool, 0.50),
			_p(pool, 0.75), _p(pool, 0.90),
			float(above) / float(pool.size()) * 100.0])


func _p(sorted_values: Array, fraction: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	return float(sorted_values[clampi(
		int(round(fraction * float(sorted_values.size() - 1))),
		0, sorted_values.size() - 1)])
