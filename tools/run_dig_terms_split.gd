extends SceneTree

## Which term of the dig differs between the sides?
##
## `dig` is one of the two rows still failing the symmetry gate (0.200 against a
## 0.03 band), and the standing hypothesis is that it is a *claim* gap rather
## than a dig gap: that opponent defenders fail to claim the ball far more often
## than home ones, so they dig less and the home attack converts more, which
## would make `attack_error` partly downstream of this rather than independent.
##
## That hypothesis is worth killing before two rows get chased as two problems.
## `_defense_terms` is shared by both sides and returns every component of the
## contest separately, so the gap can be attributed instead of guessed at:
##
##   capability   what the defender is worth, from their attributes
##   timing       whether they got there, from the reach margin
##   posture      what their body cost them on arrival
##   support      whether anyone was covering with them
##   opportunity  the combined chance the contest allowed
##   read_bonus   scouting, familiarity and responsibility fit
##
## If `timing` carries the gap, it is a claim/arrival problem and the two rows
## are one defect. If `capability` carries it, the rosters are not being read
## evenly. If `read_bonus` carries it, one side is scouting and the other is not.
## Each of those is a different fix, and the terms say which.
##
## Run:
##   godot --headless --path . --script res://tools/run_dig_terms_split.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const PAIRINGS: int = 4
const RALLIES: int = 90
const HOME_PLAYBOOK_TEMPO: int = 3

const TERMS: Array[String] = [
	"quality", "capability", "timing", "posture", "support",
	"opportunity", "read_bonus", "reach_margin_meters",
]


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
			## Identical rosters are not identical teams unless tempo is pinned.
			manager.opponent_team.tendencies["tempo"] = HOME_PLAYBOOK_TEMPO
			manager.match_state.serving_home = serving_home
			for seed_value in range(5000, 5000 + RALLIES):
				var result: Resource = manager.resolve_active_rally(seed_value)
				if result != null:
					_collect(result, sides)
			manager.free()
	print("Dig terms by side -- %d pairings x %d rallies, identical rosters"
		% [PAIRINGS, RALLIES])
	print("")
	print("%-24s %10s %10s %10s" % ["term", "home", "opponent", "gap"])
	for term in TERMS:
		var home_value := _mean(sides.home, term)
		var opponent_value := _mean(sides.opponent, term)
		print("%-24s %10.4f %10.4f %10.4f" % [
			term, home_value, opponent_value, absf(home_value - opponent_value),
		])
	print("")
	var home_digs := float(sides.home.successes) / maxf(float(sides.home.count), 1.0)
	var opponent_digs := float(sides.opponent.successes) \
		/ maxf(float(sides.opponent.count), 1.0)
	print("%-24s %10.4f %10.4f %10.4f" % [
		"dig success", home_digs, opponent_digs, absf(home_digs - opponent_digs),
	])
	## The claim itself, separately from what the claimant then did. A defender
	## who never arrived is a different failure from one who arrived and lost the
	## contest, and pooling them is what makes a claim gap look like a dig gap.
	var home_missed := float(sides.home.unreached) / maxf(float(sides.home.count), 1.0)
	var opponent_missed := float(sides.opponent.unreached) \
		/ maxf(float(sides.opponent.count), 1.0)
	print("%-24s %10.4f %10.4f %10.4f" % [
		"never reached it", home_missed, opponent_missed,
		absf(home_missed - opponent_missed),
	])
	print("%-24s %10d %10d" % [
		"digs sampled (n)", int(sides.home.count), int(sides.opponent.count),
	])
	print("")
	print("A gap concentrated in `timing` or `never reached it` is a claim")
	print("problem, and `attack_error` is then partly downstream of it.")
	quit()


func _empty() -> Dictionary:
	return {"count": 0, "successes": 0, "unreached": 0, "sums": {}}


func _mean(side: Dictionary, term: String) -> float:
	var sums: Dictionary = side.sums
	if not sums.has(term):
		return 0.0
	return float(sums[term]) / maxf(float(side.count), 1.0)


func _collect(result: Resource, sides: Dictionary) -> void:
	for raw_event in result.events:
		var event: Resource = raw_event
		if int(event.event_type) != RallyEventScript.EventType.DEFENSE:
			continue
		var side := str(event.metadata.get("side", ""))
		if not sides.has(side):
			continue
		var terms: Dictionary = Dictionary(event.metadata.get("dig_terms", {}))
		if terms.is_empty():
			continue
		var bucket: Dictionary = sides[side]
		bucket.count += 1
		if bool(event.success):
			bucket.successes += 1
		if float(terms.get("reach_margin_meters", 0.0)) < 0.0:
			bucket.unreached += 1
		var sums: Dictionary = bucket.sums
		for term in TERMS:
			sums[term] = float(sums.get(term, 0.0)) + float(terms.get(term, 0.0))
		bucket.sums = sums
		sides[side] = bucket
