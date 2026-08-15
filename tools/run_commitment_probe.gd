extends SceneTree

## What does the bench's decisiveness instruction actually move?
##
##     godot --headless --path . --script res://tools/run_commitment_probe.gd
##
## `_test_team_identity_directional_outcomes` asserts that a Defensive attack
## makes fewer errors *and* fewer kills than a Physical one. The kill half holds;
## the error half is inverted -- measured, Defensive 0.0868 against Physical
## 0.0642, so the game currently says swinging harder is *safer*.
##
## That is not a threshold to nudge. Decisiveness reaches the swing through
## exactly one channel -- `AttackPowerModel.aggression_from` biases
## `chosen_fraction`, which becomes the ball's speed -- and speed only helps a
## ball stay in: a faster swing is flatter, clears the tape more easily and
## reaches the target without lofting. Nothing anywhere charges a hitter for
## swinging near the top of their range.
##
## So the question this answers is the one §0 insists on asking first: **what
## range does `chosen_fraction` actually occupy, and how far apart do the two
## identities sit inside it?** A cost applied outside that range does nothing,
## and does nothing silently.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const RALLIES: int = 260
const FIRST_SEED: int = 91000
const IDENTITIES: Array[String] = ["Physical", "Defensive", "Balanced"]


func _initialize() -> void:
	print("%-12s %6s %8s %8s %8s %8s %8s" % [
		"identity", "n", "p10", "p50", "p90", "max", "mean",
	])
	var samples := {}
	for identity in IDENTITIES:
		var values: Array = []
		for serving_home in [true, false]:
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.team.apply_identity(identity)
			manager.match_state.serving_home = serving_home
			for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES):
				var result: Resource = manager.resolve_active_rally(seed_value)
				if result == null:
					continue
				for raw_event in result.events:
					var event: Resource = raw_event
					if int(event.event_type) != RallyEventScript.EventType.ATTACK:
						continue
					if str(event.metadata.get("side", "")) != "home":
						continue
					var fraction := float(event.metadata.get(
						"chosen_power_fraction", -1.0
					))
					if fraction >= 0.0:
						values.append(fraction)
			manager.free()
		samples[identity] = values
		if values.is_empty():
			print("%-12s %6d   -- nothing published --" % [identity, 0])
			continue
		values.sort()
		var total := 0.0
		for value in values:
			total += float(value)
		print("%-12s %6d %8.3f %8.3f %8.3f %8.3f %8.3f" % [
			identity, values.size(), _at(values, 0.10), _at(values, 0.50),
			_at(values, 0.90), values[values.size() - 1],
			total / float(values.size()),
		])

	## The gap is the whole question. A cost on commitment can only separate two
	## identities by as much as their commitment separates them in the first
	## place, so this number bounds anything built on top of it.
	var physical: Array = samples.get("Physical", [])
	var defensive: Array = samples.get("Defensive", [])
	if not physical.is_empty() and not defensive.is_empty():
		print("")
		print("Physical swings at %.3f of ceiling, Defensive at %.3f: a gap of" % [
			_mean(physical), _mean(defensive),
		])
		print("%.4f, which is what any commitment cost has to work inside." % (
			_mean(physical) - _mean(defensive)
		))
	quit()


func _mean(values: Array) -> float:
	var total := 0.0
	for value in values:
		total += float(value)
	return total / maxf(float(values.size()), 1.0)


func _at(sorted_values: Array, quantile: float) -> float:
	return float(sorted_values[clampi(
		int(floor(quantile * float(sorted_values.size() - 1))),
		0, sorted_values.size() - 1,
	)])
