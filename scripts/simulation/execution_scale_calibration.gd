class_name ExecutionScaleCalibration
extends RefCounted

## Tuning the execution scales without resolving a rally.
##
## Every constant in the attack and block scales was previously judged by a
## 180-rally sweep: five minutes per answer, and the answer arrives mixed with
## every other effect in the engine. Nine sweeps were spent that way discovering
## something one arithmetic check would have shown -- that the capability
## weights had been sized against an assumed `_rating()` near 0.75, when it
## actually returns roughly 0.4 to 0.5 because it divides by 100 and then
## applies fatigue and form.
##
## This evaluates the same functions the resolver calls, over a roster and a
## grid of situations, in milliseconds. It is deliberately **not** a simulation:
## it cannot tell you the kill rate, and it is not the authority on whether the
## engine plays like volleyball -- `RallyReadinessReport` still is. What it can
## tell you, immediately, is what numbers the formulas produce and how the
## attack and block scales sit relative to each other, which is the entire
## question when setting a margin between them.
##
## Two things it is built to expose:
##
## 1. **Level** -- where each scale centres. A margin of 0.06 between two
##    quantities means nothing until you know they are the same size.
## 2. **Spread** -- how far apart the best and worst player land. If an elite
##    hitter and an average one score 0.45 and 0.40, no downstream formula can
##    make a standout feel like a standout, and the problem is in generation
##    rather than anywhere in the rally.

const RallySimulatorModel := preload("res://scripts/simulation/rally_simulator.gd")
const PlayerGeneratorModel := preload("res://scripts/systems/player_generator.gd")

## The attributes each scale is actually built from, so the report shows the
## inputs next to the outputs they produce.
const ATTACK_RATINGS: Array[String] = [
	"attack_accuracy", "attack_power", "decision_making",
]
const BLOCK_RATINGS: Array[String] = [
	"block_timing", "jump_reach", "anticipation", "explosiveness",
]

## Representative situations, from a swing that had everything to one that had
## nothing. These are named points on the opportunity axes, not a claim about
## how often each occurs -- frequency is the sweep's job.
##
## `set_quality` spans the range the last full sweep measured (median 0.55,
## quartiles 0.41 and 0.70). `arrival_margin` is seconds of slack against the
## ball; negative means the hitter is still arriving as it comes down.
const SITUATIONS := {
	"ideal": {"set_quality": 0.90, "approach_fit": 0.90, "arrival_margin": 0.25},
	"good": {"set_quality": 0.70, "approach_fit": 0.72, "arrival_margin": 0.10},
	"typical": {"set_quality": 0.55, "approach_fit": 0.58, "arrival_margin": 0.00},
	"poor": {"set_quality": 0.41, "approach_fit": 0.45, "arrival_margin": -0.20},
	"scramble": {"set_quality": 0.15, "approach_fit": 0.30, "arrival_margin": -0.45},
}

## Close fractions to evaluate the block at: sealed, half-closed, beaten.
const CLOSE_FRACTIONS: Array[float] = [1.0, 0.6, 0.2]


## Quantiles of a sample, plus the spread that decides whether a standout can
## register at all.
static func summarise(values: Array) -> Dictionary:
	if values.is_empty():
		return {"count": 0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += float(value)
	var last := sorted.size() - 1
	return {
		"count": sorted.size(),
		"min": float(sorted[0]),
		"p25": float(sorted[clampi(int(0.25 * last), 0, last)]),
		"median": float(sorted[clampi(int(0.50 * last), 0, last)]),
		"p75": float(sorted[clampi(int(0.75 * last), 0, last)]),
		"max": float(sorted[last]),
		"mean": total / float(sorted.size()),
		## Best minus worst. The number that decides whether player quality can
		## be felt through this formula at all.
		"spread": float(sorted[last]) - float(sorted[0]),
	}


## A roster to measure. `generated` draws from `PlayerGenerator`, which is the
## population a real league is built from; the hand-authored vertical slice is a
## fixture and its spread reflects whoever typed it.
static func generated_population(
	roster_count: int = 12,
	base_seed: int = 700000,
) -> Array[VolleyballPlayer]:
	var players: Array[VolleyballPlayer] = []
	var regions: Array[String] = ["Pāwa Hitō", "Landavol"]
	for index in range(maxi(roster_count, 1)):
		var region := regions[index % regions.size()]
		var organization := "Academy" if index % 4 == 3 else "Club"
		for player in PlayerGeneratorModel.generate_roster(
			region, organization, base_seed + index
		):
			players.append(player)
	return players


## What the resolver actually sees when it asks for a rating.
##
## Raw attributes are not the answer: `_rating()` divides by 100 and then
## applies fatigue and form, so the number a formula is weighted against is not
## the number on the player card.
static func rating_spread(players: Array[VolleyballPlayer]) -> Dictionary:
	var simulator := RallySimulatorModel.new()
	var rows := {}
	for attribute in ATTACK_RATINGS + BLOCK_RATINGS:
		var raw: Array[float] = []
		var effective: Array[float] = []
		for player in players:
			raw.append(float(player.get(attribute)) / 100.0)
			effective.append(float(simulator._rating(player, attribute)))
		rows[attribute] = {
			"raw": summarise(raw),
			"effective": summarise(effective),
		}
	## `attack_power` is the one attribute the swing reads through
	## `_power_rating()`, which adds mass and reads usable rather than rated
	## power, so it needs measuring separately from its own `_rating()`.
	var power: Array[float] = []
	for player in players:
		power.append(float(simulator._power_rating(player, "attack_power")))
	rows["attack_power_effective"] = {"effective": summarise(power)}
	return rows


## Attack quality for every player in every named situation.
##
## No block pressure and no overreach: this is the swing the execution model
## produces before anything is taken off it, which is what the capability
## weights have to be sized against.
static func attack_scale(players: Array[VolleyballPlayer]) -> Dictionary:
	var simulator := RallySimulatorModel.new()
	var rows := {}
	for situation_name in SITUATIONS:
		var situation: Dictionary = SITUATIONS[situation_name]
		var values: Array[float] = []
		for player in players:
			values.append(simulator._attack_execution(
				player,
				float(situation["set_quality"]),
				float(situation["approach_fit"]),
				float(situation["arrival_margin"]),
				0.0, 0.0,
			))
		rows[situation_name] = summarise(values)
	return rows


## Block quality at each close fraction, through the same wall formula the
## resolver uses for a solo block.
static func block_scale(players: Array[VolleyballPlayer]) -> Dictionary:
	var simulator := RallySimulatorModel.new()
	var rows := {}
	for close in CLOSE_FRACTIONS:
		var values: Array[float] = []
		for player in players:
			values.append(clampf(
				simulator._block_contact_skill(player, close) * 0.78, 0.05, 0.98
			))
		rows["close_%.1f" % close] = summarise(values)
	return rows


## What the contest margins would produce, given two scales.
##
## Pairs a random swing with a random block and applies the resolver's own
## thresholds. This is the number that decides a margin, and it costs
## microseconds instead of a five-minute sweep.
static func contest_shares(
	attack_values: Array,
	block_values: Array,
	sample_count: int = 20000,
	base_seed: int = 20250801,
) -> Dictionary:
	if attack_values.is_empty() or block_values.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = base_seed
	var counts := {"stuff": 0, "touch": 0, "funnel": 0, "miss": 0}
	for index in range(maxi(sample_count, 1)):
		var attack := float(attack_values[rng.randi() % attack_values.size()])
		var block := float(block_values[rng.randi() % block_values.size()])
		var contest := block + rng.randf_range(-0.14, 0.12)
		var outcome := "miss"
		if contest > attack + RallySimulatorModel.BLOCK_STUFF_MARGIN:
			outcome = "stuff"
		elif contest > attack + RallySimulatorModel.BLOCK_TOUCH_MARGIN:
			outcome = "touch"
		elif contest > attack + RallySimulatorModel.BLOCK_FUNNEL_MARGIN:
			outcome = "funnel"
		counts[outcome] = int(counts[outcome]) + 1
	var shares := {}
	for key in counts:
		shares[key] = float(counts[key]) / float(maxi(sample_count, 1))
	## The stuff share here is an upper bound: the resolver additionally
	## requires the primary to have sealed the lane, which this does not model.
	shares["touched"] = 1.0 - float(shares["miss"])
	return shares


## Share of swings the error threshold would reject, per situation.
static func error_shares(attack_rows: Dictionary) -> Dictionary:
	var shares := {}
	for situation_name in attack_rows:
		var row: Dictionary = attack_rows[situation_name]
		if int(row.get("count", 0)) == 0:
			continue
		## Quantile-free: the summary carries the quartiles, so this reports
		## which of them sit under the threshold rather than inventing a rate.
		var threshold := RallySimulatorModel.ATTACK_ERROR_THRESHOLD
		shares[situation_name] = {
			"median_above_threshold": float(row["median"]) > threshold,
			"p25_above_threshold": float(row["p25"]) > threshold,
			"min_above_threshold": float(row["min"]) > threshold,
			"threshold": threshold,
		}
	return shares
