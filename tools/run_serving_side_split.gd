extends SceneTree

## Splits the symmetry rates by which side served.
##
## Written to discriminate one specific claim: that advancing `rally_clock` on
## the home-serve path removed an advantage the opponent had been getting for
## free. `opponent_state.simulation_time` is derived from `rally_clock`, and on
## home-served rallies that clock never started, so the opponent's approach and
## live-integrator gating ran against a clock stuck at zero.
##
## If that is what happened, the opponent's rates fall on home-served rallies
## and are unchanged on opponent-served ones, because only the former had the
## broken clock. If they fall on both, the mechanism is something else and the
## claim is wrong -- which is the point of splitting rather than asserting.
##
## Run:
##   godot --headless --path . --script res://tools/run_serving_side_split.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const PAIRINGS: int = 4
const RALLIES: int = 90
const HOME_PLAYBOOK_TEMPO: int = 3


func _initialize() -> void:
	print("Serving-side split -- %d pairings x %d rallies" % [PAIRINGS, RALLIES])
	print("")
	print("%-18s %10s %10s %10s %10s" % [
		"rate", "home-srv", "opp-srv", "home-srv", "opp-srv",
	])
	print("%-18s %10s %10s %10s %10s" % ["", "(home)", "(home)", "(opp)", "(opp)"])
	var buckets := {}
	for serving_home in [true, false]:
		buckets[serving_home] = {
			"home": _empty_side(), "opponent": _empty_side(),
		}
	for pairing_index in range(PAIRINGS):
		var roster_seed := 900006 + pairing_index * 1000
		for serving_home in [true, false]:
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			ExecutionScale.apply_generated_attributes(manager.players, roster_seed)
			ExecutionScale.apply_generated_attributes(
				manager.opponent_team.players, roster_seed
			)
			manager.opponent_team.tendencies["tempo"] = HOME_PLAYBOOK_TEMPO
			manager.match_state.serving_home = serving_home
			for seed_value in range(5000, 5000 + RALLIES):
				var result: Resource = manager.resolve_active_rally(seed_value)
				if result != null:
					_collect(result, buckets[serving_home])
			manager.free()
	for rate in ["kill", "attack_quality", "set_quality", "dig"]:
		print("%-18s %10.3f %10.3f %10.3f %10.3f" % [
			rate,
			_rate(buckets[true], "home", rate), _rate(buckets[false], "home", rate),
			_rate(buckets[true], "opponent", rate),
			_rate(buckets[false], "opponent", rate),
		])
	## Denominators, on the same page as the rates.
	##
	## Without these this tool reported a 42% swing in the home side's attack
	## quality on home-served rallies and it was computed over eight attacks --
	## home serves, so the opponent receives and swings first, and most of those
	## rallies end before the home side ever gets one. A rate printed without its
	## sample size invites exactly that reading, so it is no longer printed
	## without one.
	print("")
	print("%-18s %10d %10d %10d %10d" % [
		"attacks (n)",
		int(buckets[true]["home"].attacks), int(buckets[false]["home"].attacks),
		int(buckets[true]["opponent"].attacks),
		int(buckets[false]["opponent"].attacks),
	])
	print("%-18s %10d %10d %10d %10d" % [
		"dig attempts (n)",
		int(buckets[true]["home"].dig_attempts),
		int(buckets[false]["home"].dig_attempts),
		int(buckets[true]["opponent"].dig_attempts),
		int(buckets[false]["opponent"].dig_attempts),
	])
	print("")
	print("Columns 3 and 4 are the opponent. If the home-serve clock was")
	print("propping them up, column 3 is the one that moved -- but read the")
	print("counts first; some of these cells are far too small to carry a rate.")


func _empty_side() -> Dictionary:
	return {
		"attacks": 0, "kills": 0, "sets": 0, "dig_attempts": 0, "digs": 0,
		"set_quality": 0.0, "attack_quality": 0.0,
	}


func _rate(bucket: Dictionary, side: String, rate: String) -> float:
	var totals: Dictionary = bucket[side]
	var attempts := maxf(float(totals.attacks), 1.0)
	match rate:
		"kill":
			return float(totals.kills) / attempts
		"attack_quality":
			return float(totals.attack_quality) / attempts
		"set_quality":
			return float(totals.set_quality) / maxf(float(totals.sets), 1.0)
		"dig":
			return float(totals.digs) / maxf(float(totals.dig_attempts), 1.0)
	return 0.0


func _collect(result: Resource, bucket: Dictionary) -> void:
	for raw_event in result.events:
		var event: Resource = raw_event
		var side := str(event.metadata.get("side", ""))
		if side != "home" and side != "opponent":
			continue
		var totals: Dictionary = bucket[side]
		match event.event_type:
			RallyEventScript.EventType.SET:
				totals.sets += 1
				totals.set_quality += float(event.quality)
			RallyEventScript.EventType.ATTACK:
				totals.attacks += 1
				totals.attack_quality += float(event.quality)
			RallyEventScript.EventType.DIG:
				totals.dig_attempts += 1
				if event.success:
					totals.digs += 1
		bucket[side] = totals
	match str(result.terminal_outcome):
		"kill", "kill_default":
			bucket["home"].kills += 1
		"opponent_kill", "kill_opponent":
			bucket["opponent"].kills += 1
