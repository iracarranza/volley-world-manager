extends SceneTree

## The distribution `BLOCK_DEFLECTION_MIN_SECONDS` acts on.
##
##     godot --headless --path . --script res://tools/run_deflection_budget_probe.gd
##
## A floor dropped onto a distribution nobody measured is the recurring mistake
## `docs/FAILURE_MODES.md` §0 names. The gate found 97 of 109 digs with a
## movement budget longer than the window they are drawn in, and the budget is
## `max(deflection_flight_duration, BLOCK_DEFLECTION_MIN_SECONDS)` while the
## window is the deflection flight itself. So the question is not whether they
## disagree -- they must, wherever the floor binds -- but how often it binds and
## by how much, and what the defender is credited with as a result.
##
## Reads published metadata only: the block's own outgoing trajectory is the
## flight, and the dig's `movement_available_seconds` is what the resolver spent.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 61000
const SEED_COUNT: int = 200

const COURT_W: float = 9.0
const COURT_L: float = 18.0

## `rally_simulator.BLOCK_DEFLECTION_MIN_SECONDS`, duplicated so the probe can
## say where the floor sits without importing the resolver's whole surface.
const FLOOR_SECONDS: float = 0.22

## Bucket edges for the flight-duration histogram, in seconds.
const BUCKETS := [0.05, 0.10, 0.15, 0.22, 0.30, 0.45, 0.70, 1.00]


func _metres(from_position: Vector2, to_position: Vector2) -> float:
	var delta := to_position - from_position
	return Vector2(delta.x * COURT_W, delta.y * COURT_L).length()


func _bucket(seconds: float) -> String:
	for edge in BUCKETS:
		if seconds < float(edge):
			return "<%.2f" % float(edge)
	return ">=%.2f" % float(BUCKETS[BUCKETS.size() - 1])


func _initialize() -> void:
	var histogram := {}
	var totals := {
		"pairs": 0, "floor_binds": 0, "no_flight": 0,
		"bound_and_arrived": 0, "bound_and_short": 0,
		"free_and_arrived": 0, "free_and_short": 0,
	}
	var inflation := 0.0
	var window_total := 0.0
	var budget_total := 0.0
	var window_pairs := 0
	var over_window := 0
	var over_total := 0.0
	var pre_net_total := 0.0
	var pre_net_pairs := 0
	var attack_block_pairs := 0
	var attack_block_total := 0.0
	var attack_block_drawable := 0
	var worst_inflation := 0.0
	var credited_metres := 0.0
	for serving_home in [false, true]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			var events: Array = result.events
			for index in range(events.size() - 1):
				var block_event: Resource = events[index]
				var dig_event: Resource = events[index + 1]
				if block_event == null or dig_event == null:
					continue
				if int(block_event.event_type) != RallyEventScript.EventType.BLOCK:
					continue
				## The window the block closes, measured whether or not a dig
				## follows: it is the only place a dig's leg could be issued
				## early, and `match_screen` skips a window of zero length.
				if index > 0:
					var attack_event: Resource = events[index - 1]
					if attack_event != null and int(attack_event.event_type) \
							== RallyEventScript.EventType.ATTACK:
						var ab := float(block_event.metadata.get(
							"physical_time", 0.0
						)) - float(attack_event.metadata.get("physical_time", 0.0))
						attack_block_pairs += 1
						attack_block_total += ab
						if ab > 0.005:
							attack_block_drawable += 1
				if int(dig_event.event_type) != RallyEventScript.EventType.DIG:
					continue
				var meta: Dictionary = dig_event.metadata
				var budget := float(meta.get("movement_available_seconds", -1.0))
				if budget <= 0.0:
					continue
				var flight: Dictionary = block_event.metadata.get(
					"outgoing_trajectory", {}
				)
				totals["pairs"] = int(totals.pairs) + 1
				var window := float(meta.get("physical_time", 0.0)) \
					- float(block_event.metadata.get("physical_time", 0.0))
				var incoming: Dictionary = block_event.metadata.get(
					"incoming_trajectory", {}
				)
				var swing := float(incoming.get("duration", 0.0))
				if window > 0.0:
					window_total += window
					budget_total += budget
					window_pairs += 1
					if budget > window + 0.001:
						over_window += 1
						over_total += budget - window
						## The swing this defender was reading before the wall
						## touched it, or did not. If `budget - window` matches
						## the part of that flight spent before the net, the
						## defender is being credited with travel that starts in
						## the previous playback window rather than with travel
						## that does not exist.
						if swing > 0.0:
							pre_net_total += swing - window
							pre_net_pairs += 1
				if flight.is_empty():
					totals["no_flight"] = int(totals.no_flight) + 1
					continue
				var duration := float(flight.get("duration", 0.0))
				histogram[_bucket(duration)] = int(
					histogram.get(_bucket(duration), 0)
				) + 1
				var start := Vector2(meta.get("movement_start", Vector2.ZERO))
				var target := Vector2(meta.get("movement_target", start))
				var ball := Vector2(dig_event.start_position)
				var arrived := _metres(target, ball) <= 0.5
				if budget > duration + 0.0005:
					totals["floor_binds"] = int(totals.floor_binds) + 1
					var extra := budget - duration
					inflation += extra
					worst_inflation = maxf(worst_inflation, extra)
					## What the extra time is worth in ground: the resolver
					## charges travel against the budget, so an inflated budget
					## is a defender credited with metres the ball's flight does
					## not pay for.
					credited_metres += extra * _speed_for(result, dig_event)
					if arrived:
						totals["bound_and_arrived"] = int(
							totals.bound_and_arrived
						) + 1
					else:
						totals["bound_and_short"] = int(totals.bound_and_short) + 1
				elif arrived:
					totals["free_and_arrived"] = int(totals.free_and_arrived) + 1
				else:
					totals["free_and_short"] = int(totals.free_and_short) + 1
	print("--- deflection flight duration, %d rallies" % (SEED_COUNT * 2))
	var edges: Array = histogram.keys()
	edges.sort()
	for edge in edges:
		print("%s|%d" % [edge, int(histogram[edge])])
	print("--- floor at %.2f s" % FLOOR_SECONDS)
	var keys: Array = totals.keys()
	keys.sort()
	for key in keys:
		print("%s|%d" % [key, int(totals[key])])
	var bound := maxf(float(totals.floor_binds), 1.0)
	print("mean_inflation_s|%.4f" % (inflation / bound))
	print("worst_inflation_s|%.4f" % worst_inflation)
	print("mean_credited_metres|%.3f" % (credited_metres / bound))
	var wp := maxf(float(window_pairs), 1.0)
	print("--- budget against the window playback draws it in")
	print("pairs_with_window|%d" % window_pairs)
	print("mean_budget_s|%.4f" % (budget_total / wp))
	print("mean_window_s|%.4f" % (window_total / wp))
	print("budget_over_window|%d" % over_window)
	print("mean_overrun_s|%.4f" % (over_total / maxf(float(over_window), 1.0)))
	print("mean_swing_before_the_net_s|%.4f" % (
		pre_net_total / maxf(float(pre_net_pairs), 1.0)
	))
	print("--- the window the dig's leg would have to start in")
	print("attack_to_block_pairs|%d" % attack_block_pairs)
	print("mean_attack_to_block_window_s|%.4f" % (
		attack_block_total / maxf(float(attack_block_pairs), 1.0)
	))
	print("attack_to_block_windows_over_5ms|%d" % attack_block_drawable)
	quit()


## The digger's own published transition speed, so "what the extra time buys" is
## in the units a defender actually moves in rather than a nominal constant.
func _speed_for(result: Resource, dig_event: Resource) -> float:
	var profiles: Dictionary = result.player_physical_profiles
	var physical: Dictionary = profiles.get(int(dig_event.actor_id), {})
	return maxf(float(physical.get("transition_speed_mps", 7.0)), 0.01)
