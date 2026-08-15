extends SceneTree

## Why does one side's attack err two and a half times as often as the other's?
##
## `attack_error` is the largest surviving asymmetry (0.237) and it is *not*
## downstream of the dig gap, which was the standing hypothesis until the terms
## were measured. The evidence against it is already in hand: `attack_quality`
## is symmetric at 0.010. Both sides strike the ball equally well and one errs
## far more, so the difference is in how an error is decided rather than in the
## swing.
##
## Two mechanisms can end a swing in an error, and they are not wired the same:
##
##   geometric   `_geometric_attack_promotion` solves the actual shot and can
##               declare it out. Both sides consult it, and on both sides a
##               non-empty result *overrides* everything else.
##   stochastic  `_attack_missed()` rolls a logistic miss chance against attack
##               quality. Only the home path calls it.
##
## That wiring predicts the opponent should err *less*, not more, so one of the
## two is behaving differently per side. This counts which mechanism actually
## decided each error, and what the geometric solver said when it did.
##
## Run:
##   godot --headless --path . --script res://tools/run_attack_error_split.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const PAIRINGS: int = 4
const RALLIES: int = 90
const HOME_PLAYBOOK_TEMPO: int = 3


func _initialize() -> void:
	var sides := {"home": _empty(), "opponent": _empty()}
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
					_collect(result, sides)
			manager.free()
	print("Attack error mechanism by side -- %d pairings x %d rallies"
		% [PAIRINGS, RALLIES])
	print("")
	print("%-28s %10s %10s" % ["", "home", "opponent"])
	for row in [
		["attacks (n)", "count"], ["marked missed", "missed"],
		["geometric consulted", "geometric"],
		["geometric said out", "geometric_missed"],
	]:
		print("%-28s %10d %10d" % [
			str(row[0]), int(sides.home[str(row[1])]),
			int(sides.opponent[str(row[1])]),
		])
	print("")
	print("%-28s %10.4f %10.4f" % [
		"miss rate", _ratio(sides.home, "missed"), _ratio(sides.opponent, "missed"),
	])
	print("%-28s %10.4f %10.4f" % [
		"geometric coverage", _ratio(sides.home, "geometric"),
		_ratio(sides.opponent, "geometric"),
	])
	print("%-28s %10.4f %10.4f" % [
		"mean attack quality", _mean_quality(sides.home),
		_mean_quality(sides.opponent),
	])
	## `net` dominates the out reasons, and how far the contact is from the tape
	## is what decides whether a swing can clear it. If one side is contacting
	## consistently deeper, that is the whole mechanism.
	print("%-28s %10.4f %10.4f" % [
		"contact distance to net (m)",
		float(sides.home.net_distance) / maxf(float(sides.home.count), 1.0),
		float(sides.opponent.net_distance) / maxf(float(sides.opponent.count), 1.0),
	])
	print("%-28s %10d %10d" % [
		"contacts near front ideal", int(sides.home.front_like),
		int(sides.opponent.front_like),
	])
	print("%-28s %10d %10d" % [
		"contacts near back ideal", int(sides.home.back_like),
		int(sides.opponent.back_like),
	])
	for side in ["home", "opponent"]:
		var reasons: Dictionary = sides[side].reasons
		if reasons.is_empty():
			continue
		print("")
		print("%s out reasons:" % side)
		var keys := reasons.keys()
		keys.sort_custom(func(a, b): return int(reasons[a]) > int(reasons[b]))
		for key in keys:
			print("  %-24s %5d" % [str(key), int(reasons[key])])
	print("")
	print("If geometric coverage differs, the two sides are not being judged by")
	print("the same mechanism and the rate gap is that, not the hitters.")
	quit()


func _empty() -> Dictionary:
	return {
		"count": 0, "missed": 0, "geometric": 0, "geometric_missed": 0,
		"quality": 0.0, "net_distance": 0.0, "front_like": 0, "back_like": 0,
		"reasons": {},
	}


func _ratio(side: Dictionary, key: String) -> float:
	return float(side[key]) / maxf(float(side.count), 1.0)


func _mean_quality(side: Dictionary) -> float:
	return float(side.quality) / maxf(float(side.count), 1.0)


func _collect(result: Resource, sides: Dictionary) -> void:
	for raw_event in result.events:
		var event: Resource = raw_event
		if int(event.event_type) != RallyEventScript.EventType.ATTACK:
			continue
		var side := str(event.metadata.get("side", ""))
		if not sides.has(side):
			continue
		var bucket: Dictionary = sides[side]
		bucket.count += 1
		bucket.quality = float(bucket.quality) + float(event.quality)
		var to_net := absf(event.start_position.y - 0.5) * 18.0
		bucket.net_distance = float(bucket.net_distance) + to_net
		## Which nominal contact this swing sits nearest. The two ideals are 0.36
		## and 3.60 m for the opponent, 0.54 and 2.88 m for home, so a 2 m split
		## separates them cleanly on either side.
		if to_net < 2.0:
			bucket.front_like += 1
		else:
			bucket.back_like += 1
		if bool(event.metadata.get("attack_missed", false)):
			bucket.missed += 1
		var outcome := str(event.metadata.get("geometric_outcome", ""))
		if not outcome.is_empty():
			bucket.geometric += 1
		var reason := str(event.metadata.get("geometric_out_reason", ""))
		if not reason.is_empty():
			bucket.geometric_missed += 1
			var reasons: Dictionary = bucket.reasons
			reasons[reason] = int(reasons.get(reason, 0)) + 1
			bucket.reasons = reasons
		sides[side] = bucket
