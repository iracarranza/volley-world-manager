extends SceneTree

## What builds the reach margin, per side.
##
## `reach_margin_meters` is the sole input to the dig's `timing` factor -- the
## dig model contains no time at all, only this distance -- and it reads 1.058 m
## for the home defence against 0.242 m for the opponent's. That 0.816 m gap is
## the whole dig asymmetry, and it survived an eightfold change in the shot mix
## it defends, which rules out the attack as its cause.
##
## `reach_margin = physical_reach - distance`, and `physical_reach = base_reach +
## movement_speed * available_time * acceleration_factor`, where
## `available_time = ball_time_seconds - reaction_delay`. Six terms. The total
## cannot be acted on; the terms want fixes in different files.
##
## Reads what the DEFENSE events actually carry rather than recomputing any of
## it, per FAILURE_MODES.md 14 -- three attempts on the attack side went wrong by
## starting at the source.
##
## Run:
##   godot --headless --path . --script res://tools/run_reach_margin_probe.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const RALLIES: int = 150

const TERMS: Array[String] = [
	"ball_time_seconds", "reaction_delay", "available_time",
	"movement_speed_mps", "acceleration_factor", "travel_distance_meters",
	"base_reach_meters", "physical_reach_meters", "distance_meters",
	"reach_margin_meters",
]


func _initialize() -> void:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	ExecutionScale.apply_generated_attributes(manager.players, 900006)
	ExecutionScale.apply_generated_attributes(
		manager.opponent_team.players, 900006
	)
	var rows := {"home": [], "opponent": []}
	var empty := {"home": 0, "opponent": 0}
	var seen := {"home": 0, "opponent": 0}
	for serving_home in [true, false]:
		manager.match_state.serving_home = serving_home
		for seed_value in range(5000, 5000 + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			var last_attack_type := "?"
			var last_block_outcome := "none"
			for raw in result.events:
				var event := raw as RallyEvent
				if event == null:
					continue
				## Carried forward from the swing that caused this dig. Whether the
				## 0.30 s gap in `ball_time_seconds` is the shot mix or the code is
				## the whole question, and it cannot be answered from a figure
				## averaged across both shot types.
				if event.event_type == RallyEventScript.EventType.ATTACK:
					last_attack_type = str(event.metadata.get("attack_type", "?"))
				elif event.event_type == RallyEventScript.EventType.BLOCK:
					last_block_outcome = str(event.metadata.get("outcome", "none"))
				if event.event_type != RallyEventScript.EventType.DEFENSE:
					continue
				var side := str(event.metadata.get("side", ""))
				if not rows.has(side):
					continue
				seen[side] = int(seen[side]) + 1
				var arrival := Dictionary(event.metadata.get("arrival", {}))
				## An arrival with no terms in it is a defender who never claimed
				## the ball through the coverage model at all, and whose margin is
				## therefore a fallback rather than a measurement. Counted
				## separately: averaging the two together is the denominator
				## mismatch this file has already been bitten by twice.
				if not arrival.has("physical_reach_meters"):
					empty[side] = int(empty[side]) + 1
					continue
				var paired := arrival.duplicate()
				paired["attack_type"] = last_attack_type
				paired["block_outcome"] = last_block_outcome
				rows[side].append(paired)
	manager.free()

	print("Reach margin decomposition -- %d rallies x 2 serving sides" % RALLIES)
	print("")
	for side in ["home", "opponent"]:
		print("  %-9s %d defence events, %d with no arrival terms (%.0f%%)" % [
			side, int(seen[side]), int(empty[side]),
			float(empty[side]) / maxf(float(seen[side]), 1.0) * 100.0,
		])
	print("")
	print("Means over the rows that carry terms")
	print("")
	var header := "%-24s %10s %10s %10s" % ["term", "home", "opponent", "gap"]
	print(header)
	for term in TERMS:
		var home_mean := _mean(rows["home"], term)
		var opponent_mean := _mean(rows["opponent"], term)
		print("%-24s %10.3f %10.3f %+10.3f" % [
			term, home_mean, opponent_mean, home_mean - opponent_mean,
		])
	print("")
	print("Medians, because a mean has been the wrong reading twice in this file")
	print("")
	print("%-24s %10s %10s" % ["term", "home", "opponent"])
	for term in ["ball_time_seconds", "distance_meters", "reach_margin_meters"]:
		print("%-24s %10.3f %10.3f" % [
			term, _median(rows["home"], term), _median(rows["opponent"], term),
		])
	print("")
	print("ball_time_seconds and distance_meters, split by the swing that caused")
	print("the dig. If the two sides agree within a shot type, the gap is the mix")
	print("and not the code.")
	print("")
	print("%-9s %-16s %6s %14s %14s %14s" % [
		"side", "attack", "n", "ball_time", "distance", "reach_margin"])
	for side in ["home", "opponent"]:
		var kinds := {}
		for row in rows[side]:
			var kind := str(Dictionary(row).get("attack_type", "?"))
			if not kinds.has(kind):
				kinds[kind] = []
			kinds[kind].append(row)
		var keys: Array = kinds.keys()
		keys.sort()
		for kind in keys:
			var pool: Array = kinds[kind]
			if pool.size() < 3:
				continue
			print("%-9s %-16s %6d %14.3f %14.3f %14.3f" % [
				side, str(kind), pool.size(),
				_mean(pool, "ball_time_seconds"),
				_mean(pool, "distance_meters"),
				_mean(pool, "reach_margin_meters"),
			])
	print("")
	print("physical_reach - distance = reach_margin. Read down for the term whose")
	print("gap accounts for the margin's, and check it against the medians before")
	print("believing it.")
	quit()


func _mean(pool: Array, key: String) -> float:
	if pool.is_empty():
		return 0.0
	var total := 0.0
	for row in pool:
		total += float(Dictionary(row).get(key, 0.0))
	return total / float(pool.size())


func _median(pool: Array, key: String) -> float:
	if pool.is_empty():
		return 0.0
	var values: Array = []
	for row in pool:
		values.append(float(Dictionary(row).get(key, 0.0)))
	values.sort()
	return float(values[int(values.size() / 2)])
