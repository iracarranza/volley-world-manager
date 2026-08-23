extends SceneTree

## What `AttemptJudgment` actually decides, before and after the recognition /
## response split.
##
##     godot --headless --path . --script res://tools/run_attempt_judgment_probe.gd
##
## Two measurements, deliberately separate, because they answer different
## questions and one of them has no sampling noise at all.
##
## **Part A -- the function, over the real player population.** `backs_off` is
## deterministic: a player's judgment is a constant and the threshold falls as the
## deficit grows, so for every voli there is one *flip deficit* -- the smallest
## overreach they would decline. That number is the whole behaviour of the model
## for that player, exactly, with no rally in the way. Reporting it per attribute
## tier says what the change does causally; reporting rates would only say what it
## did to one fixture.
##
## **Part B -- the live sites, in situ.** Five code sites reach this decision and
## three publish their verdict on an event. Isolated rallies, a fresh
## `GameManager` per seed, so one divergence cannot cascade into the next.
##
## The before figures are a diagnosis, not a target. See `PLATFORM_CONTACT.md`
## §14: the model being measured is semantically wrong, so reproducing its rates
## would be preserving the defect.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const AttemptJudgmentModel := preload(
	"res://scripts/simulation/attempt_judgment.gd"
)
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 41000
const SEED_COUNT: int = 400
## Enough volis that a tier holds a countable population; generated rather than
## hand-picked so the spread is the world's own.
const POPULATION_SEED: int = 41999


func _initialize() -> void:
	_part_a()
	_part_b()
	quit()


## The quantity `backs_off` actually compares against the threshold: recognition,
## moved by temperament's signed deviation from neutral. Mirrors the resolver
## exactly rather than re-deriving it, so the flip solve below stays exact.
func _effective(player: Object) -> float:
	return float(AttemptJudgmentModel.judgment(player)) - (
		float(0.5) - 0.5
	) * AttemptJudgmentModel.PERSISTENCE_SHARE


## The smallest overreach this player would decline, solved rather than searched.
##
## `backs_off` compares `_effective` against `lerp(0.85, 0.25, min(d/0.40, 1))`.
## The threshold is linear and falling, so inverting it is exact:
##
##     d* = 0.40 * (0.85 - effective) / (0.85 - 0.25)
##
## Below `d*` they attempt it; at or above it they take the safer option. A voli
## already above 0.85 declines any overreach at all (`d* = 0`); one below 0.25
## never declines (`d* = INF`, reported as `never`).
func _flip_deficit(player: Object) -> float:
	var judgment := _effective(player)
	if judgment >= AttemptJudgmentModel.CAUTIOUS_THRESHOLD:
		return 0.0
	if judgment < AttemptJudgmentModel.OBVIOUS_THRESHOLD:
		return INF
	return AttemptJudgmentModel.OBVIOUS_DEFICIT * (
		AttemptJudgmentModel.CAUTIOUS_THRESHOLD - judgment
	) / (
		AttemptJudgmentModel.CAUTIOUS_THRESHOLD
			- AttemptJudgmentModel.OBVIOUS_THRESHOLD
	)


## **One attribute at a time, everything else held at 50.**
##
## The first version of this tiered the real roster and could not attribute
## anything: the same two volis were the `weak` bucket of decision_making,
## tactical_discipline *and* composure, because generation correlates mental
## attributes, and all three tiers reported the identical 0.3420. A tier table
## over a correlated population measures the population, not the function.
##
## `backs_off` is deterministic, so a synthetic sweep is not an approximation of
## the truth here -- it *is* the truth, exactly, with each term isolated.
const SWEEP_ATTRIBUTES: Array[String] = [
	"decision_making", "tactical_discipline", "composure", "aggression",
]
const SWEEP_VALUES: Array[int] = [10, 30, 50, 70, 90]


func _part_a() -> void:
	print("=".repeat(78))
	print("PART A -- the function itself, one attribute at a time")
	print("=".repeat(78))
	print("  Everything else pinned at 50. `backs_off` is deterministic, so")
	print("  these are exact, not sampled.")
	print("  flip deficit = smallest overreach this voli declines.")
	print("  lower = backs off more readily.  OBVIOUS_DEFICIT is %.2f, so a"
		% AttemptJudgmentModel.OBVIOUS_DEFICIT)
	print("  flip at or above it is unreachable in play.\n")

	for name in SWEEP_ATTRIBUTES:
		print("  %s" % name)
		for value in SWEEP_VALUES:
			var player := _pinned_player(name, value)
			var flip := _flip_deficit(player)
			print("      %3d   recognition %.4f  persistence %.4f  effective %.4f  flip %s" % [
				value, float(AttemptJudgmentModel.judgment(player)),
				float(AttemptJudgmentModel.persistence(player)), _effective(player),
				"never" if is_inf(flip) else ("%.4f" % flip),
			])
		print("")

	## The real roster as a secondary line only -- a distribution to sanity-check
	## the sweep against, never the attribution.
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	ExecutionScale.apply_generated_attributes(manager.players, POPULATION_SEED)
	ExecutionScale.apply_generated_attributes(
		manager.opponent_team.players, POPULATION_SEED
	)
	var judgments: Array[float] = []
	var flips: Array[float] = []
	var never := 0
	for entry in manager.players + manager.opponent_team.players:
		if entry == null:
			continue
		judgments.append(_effective(entry))
		var flip := _flip_deficit(entry)
		if is_inf(flip):
			never += 1
		else:
			flips.append(flip)
	print("  live roster, %d volis: effective mean %.4f (%.4f-%.4f), flip mean %.4f, never %d"
		% [judgments.size(), _mean(judgments), judgments.min(), judgments.max(),
			_mean(flips), never])
	manager.free()


func _pinned_player(attribute: String, value: int) -> VolleyballPlayer:
	var player := VolleyballPlayer.new()
	for name in SWEEP_ATTRIBUTES:
		player.set(name, 50)
	player.set(attribute, value)
	return player


func _part_b() -> void:
	print("\n" + "=".repeat(78))
	print("PART B -- the live sites, in situ, %d isolated rallies per side"
		% SEED_COUNT)
	print("=".repeat(78))
	## Keyed by the site the verdict belongs to rather than by event type, since
	## two of the three attack sites publish under the same event.
	var counts := {
		"attack_swings": 0, "attack_downgraded": 0,
		"blocks": 0, "block_soft": 0, "block_kill": 0, "block_neutral": 0,
		"sets": 0, "set_tempo_total": 0,
		"rallies": 0, "events": 0,
		"home_points": 0, "rally_lengths": 0,
	}
	## Rally outcomes, because a decision that changes what a voli attempts has
	## to be checked for whether it changed who won. Counted by outcome string
	## rather than by a chosen subset, so a shift into a category nobody expected
	## is still visible.
	var outcomes := {}
	var by_side := {
		"home": {"swings": 0, "downgraded": 0},
		"opponent": {"swings": 0, "downgraded": 0},
	}
	for serving_home in [false, true]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(seed_value)
			counts["rallies"] = int(counts.rallies) + 1
			if rally != null:
				_read_rally(rally, counts, by_side)
				var outcome := str(rally.terminal_outcome)
				outcomes[outcome] = int(outcomes.get(outcome, 0)) + 1
				counts["rally_lengths"] = int(counts.rally_lengths) \
					+ rally.events.size()
				if bool(rally.home_team_won):
					counts["home_points"] = int(counts.home_points) + 1
			manager.free()

	print("  rallies %d, events %d" % [int(counts.rallies), int(counts.events)])
	print("\n  ATTACK swing downgrade  (rally_simulator 2534 / 4809 / 6306)")
	print("      swings %d, downgraded %d, rate %.4f" % [
		int(counts.attack_swings), int(counts.attack_downgraded),
		float(counts.attack_downgraded) / maxf(float(counts.attack_swings), 1.0),
	])
	for side in ["home", "opponent"]:
		var cell: Dictionary = by_side[side]
		print("      %-9s swings %-5d downgraded %-5d rate %.4f" % [
			side, int(cell.swings), int(cell.downgraded),
			float(cell.downgraded) / maxf(float(cell.swings), 1.0),
		])
	print("\n  BLOCK hands  (rally_simulator 493, via _block_hands_intent)")
	print("      blocks %d, soft %d, kill %d, neutral %d, soft rate %.4f" % [
		int(counts.blocks), int(counts.block_soft), int(counts.block_kill),
		int(counts.block_neutral),
		float(counts.block_soft) / maxf(float(counts.blocks), 1.0),
	])
	print("\n  SETTER tempo  (setter_capability_system 198, both sides)")
	print("      sets %d, downgraded %d, rate %.4f, mean resolved tempo %.4f" % [
		int(counts.sets), int(counts.get("set_downgraded", 0)),
		float(counts.get("set_downgraded", 0)) / maxf(float(counts.sets), 1.0),
		float(counts.set_tempo_total) / maxf(float(counts.sets), 1.0),
	])
	print("      Lower tempo is quicker. A setter backing off resolves slower,")
	print("      so this mean rises when back-offs become more common.")
	print("\n  RALLY OUTCOMES")
	print("      home points %d of %d (%.4f), mean rally events %.4f" % [
		int(counts.home_points), int(counts.rallies),
		float(counts.home_points) / maxf(float(counts.rallies), 1.0),
		float(counts.rally_lengths) / maxf(float(counts.rallies), 1.0),
	])
	var names: Array = outcomes.keys()
	names.sort()
	for name in names:
		print("      %-28s %-5d %.4f" % [
			name, int(outcomes[name]),
			float(outcomes[name]) / maxf(float(counts.rallies), 1.0),
		])


func _read_rally(
	rally: Resource, counts: Dictionary, by_side: Dictionary
) -> void:
	for event in rally.events:
		counts["events"] = int(counts.events) + 1
		var metadata: Dictionary = event.metadata
		var kind := int(event.event_type)
		if kind == RallyEventScript.EventType.ATTACK:
			counts["attack_swings"] = int(counts.attack_swings) + 1
			var side := str(metadata.get("side", "home"))
			var cell: Dictionary = by_side.get(side, by_side["home"])
			cell["swings"] = int(cell.swings) + 1
			if bool(metadata.get("swing_downgraded", false)):
				counts["attack_downgraded"] = int(counts.attack_downgraded) + 1
				cell["downgraded"] = int(cell.downgraded) + 1
		elif kind == RallyEventScript.EventType.BLOCK:
			counts["blocks"] = int(counts.blocks) + 1
			match str(metadata.get("block_hands", "neutral")):
				"soft": counts["block_soft"] = int(counts.block_soft) + 1
				"kill": counts["block_kill"] = int(counts.block_kill) + 1
				_: counts["block_neutral"] = int(counts.block_neutral) + 1
		elif kind == RallyEventScript.EventType.SET:
			## The whole capability verdict is published on the set, so this site
			## is directly observable rather than inferred from the tempo that
			## came out. The first version read `metadata.tempo`, which the set
			## event does not carry, and reported zero sets.
			var capability: Dictionary = metadata.get("setter_capability", {})
			if capability.is_empty():
				continue
			counts["sets"] = int(counts.sets) + 1
			counts["set_tempo_total"] = int(counts.set_tempo_total) \
				+ int(capability.get("resolved_tempo", 3))
			if bool(capability.get("tempo_downgraded", false)):
				counts["set_downgraded"] = int(counts.get("set_downgraded", 0)) + 1


func _tier(rating: int) -> String:
	if rating >= 75:
		return "elite"
	if rating >= 60:
		return "strong"
	if rating >= 45:
		return "average"
	return "weak"


func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())
