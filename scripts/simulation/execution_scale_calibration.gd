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

## Named points on the opportunity axes, taken from the quantiles a sweep over
## the generated population actually measured. `RallyReadinessReport` reports
## these as `situation_inputs`; when they move, these move.
##
## Reading them changed what "typical" means. The hitter is **late** at the
## median -- an arrival margin of -0.115 s -- and a quarter of all swings are
## more than half a second late. An earlier version of this table assumed the
## hitter arrived on time at the median, which is a rally nobody in this engine
## plays, and every constant sized against it came out wrong.
##
## `arrival_margin` is seconds of slack against the ball; negative means the
## hitter is still arriving as it comes down.
const SITUATIONS := {
	"ideal": {"set_quality": 0.945, "approach_fit": 0.736, "arrival_margin": 0.686},
	"good": {"set_quality": 0.771, "approach_fit": 0.667, "arrival_margin": -0.006},
	"typical": {"set_quality": 0.652, "approach_fit": 0.568, "arrival_margin": -0.115},
	"poor": {"set_quality": 0.495, "approach_fit": 0.412, "arrival_margin": -0.522},
	"scramble": {"set_quality": 0.285, "approach_fit": 0.213, "arrival_margin": -1.392},
}

## Close fractions to evaluate the block at: sealed, half-closed, beaten.
const CLOSE_FRACTIONS: Array[float] = [1.0, 0.6, 0.2]


## Gives a hand-authored roster a generated player's attributes, in place.
##
## `GameManager.seed_vertical_slice_data()` sets only the attributes each
## player's role cares about; every other one stays at `VolleyballPlayer`'s
## default of 50. Across the eight fixture players that leaves attack_accuracy
## at 0.50 for the median and block_timing at 0.50 for every quartile, so a
## sweep over that fixture measures a squad of near-identical average players.
## Standout impact cannot be observed in a population that contains no
## standouts, and a margin tuned there does not survive a real league.
##
## Ids, names, position codes, physique and every structural relationship --
## rotations, plays, defensive assignments -- are left exactly as they were.
## Only the ability attributes are replaced, drawn from `PlayerGenerator` and
## matched by position role so a middle still gets a middle's profile.
## The region is a parameter now.
##
## It was pinned to "Pāwa Hitō", so every calibration sweep in the engine drew
## its rosters from one tradition -- and a tradition is not cosmetic here:
## `REGION_SPECIALTY` grants a flat +8 on each region's named attributes, so a
## Blôc du Larg roster genuinely blocks better and a Landavol roster carries no
## bonus at all by design. Sweeping one region measures how much a *seed* moves
## an outcome; sweeping regions measures how much a known attribute delta moves
## it, which is the question worth asking.
## **Landavol, because a fixture must not carry an identity.**
##
## This defaulted to `Pāwa Hitō`, which is the most extreme rating profile in the
## game -- physical 4, technical 1, mental 1 -- and every calibration and gate
## that reaches for generated attributes was therefore measuring a physical
## region's squad and calling it "a generated roster". That was invisible while
## the three region ratings did nothing; the moment they were wired to attribute
## ceilings it showed up as a legality gate losing half its back-row sample,
## because back-row attacking is a `court_vision` and `decision_making` choice
## and the donor region is 2.6 short on both.
##
## Landavol is zero on every regional system there is -- no specialty, no physique
## bias, no ego bias, no ceiling penalty, 0.50 on all seven principles, 1.00 on
## both curves and 2/2/2 on the ratings. It is the only region that adds nothing
## to what it is asked to measure, which is precisely what a fixture needs and is
## the standing decision for what the symmetry fixtures should be.
static func apply_generated_attributes(
	players: Array,
	base_seed: int,
	region_name: String = "Landavol",
) -> void:
	var donors_by_role := {}
	var donors: Array[VolleyballPlayer] = PlayerGeneratorModel.generate_roster(
		region_name, "Club", base_seed
	)
	for donor in donors:
		var role := str(donor.position_role)
		if not donors_by_role.has(role):
			donors_by_role[role] = []
		donors_by_role[role].append(donor)
	var used_by_role := {}
	for player_resource in players:
		var player: VolleyballPlayer = player_resource as VolleyballPlayer
		if player == null:
			continue
		var role := str(player.position_role)
		var pool: Array = donors_by_role.get(role, donors)
		if pool.is_empty():
			continue
		var index := int(used_by_role.get(role, 0))
		used_by_role[role] = index + 1
		var donor: VolleyballPlayer = pool[index % pool.size()]
		for attribute in VolleyballPlayer.ABILITY_ATTRIBUTES:
			player.set(attribute, donor.get(attribute))
		player.potential = donor.potential


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


## One swing per player in a named situation, and one solo wall per player at a
## given close. Everything that needs these values calls these functions.
##
## They exist because the driver tool kept its own copy of the wall formula, and
## the moment `_block_wall_quality()` replaced `skill * 0.78` the tool went on
## reporting contest shares from the retired expression -- three different block
## scales produced byte-identical output. That is the same duplicated-formula
## defect this harness was built to find, reproduced inside the harness.
static func attack_values(
	players: Array,
	situation_name: String,
) -> Array[float]:
	var simulator := RallySimulatorModel.new()
	var situation: Dictionary = SITUATIONS.get(situation_name, {})
	var values: Array[float] = []
	for player_resource in players:
		var player: VolleyballPlayer = player_resource as VolleyballPlayer
		if player == null:
			continue
		values.append(simulator._attack_execution(
			player,
			float(situation.get("set_quality", 0.5)),
			float(situation.get("approach_fit", 0.5)),
			float(situation.get("arrival_margin", 0.0)),
			0.0, 0.0,
		))
	return values


## One dig per player, at a given arrival margin. Zero read bonus and no
## posture penalty: this is the defender's own contribution, which is what a
## contest constant has to be sized against.
static func defense_values(
	players: Array,
	arrival_margin: float,
) -> Array[float]:
	var simulator := RallySimulatorModel.new()
	var values: Array[float] = []
	for player_resource in players:
		var player: VolleyballPlayer = player_resource as VolleyballPlayer
		if player == null:
			continue
		values.append(simulator._defense_execution(
			player, arrival_margin, 0.0, 0.0, 0
		))
	return values


## Share of swings that get dug, given a swing scale and a dig scale. The number
## that sets `DIG_ATTACKER_ADVANTAGE`, and it costs microseconds.
static func dig_share(
	attack_values_in: Array,
	defense_values_in: Array,
	sample_count: int = 20000,
	base_seed: int = 20250802,
) -> float:
	if attack_values_in.is_empty() or defense_values_in.is_empty():
		return 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = base_seed
	var dug := 0
	for index in range(maxi(sample_count, 1)):
		var attack := float(attack_values_in[rng.randi() % attack_values_in.size()])
		var defense := float(defense_values_in[rng.randi() % defense_values_in.size()])
		if defense + rng.randf_range(
			-RallySimulatorModel.DIG_EXECUTION_NOISE,
			RallySimulatorModel.DIG_EXECUTION_NOISE,
		) > attack + RallySimulatorModel.DIG_ATTACKER_ADVANTAGE:
			dug += 1
	return float(dug) / float(maxi(sample_count, 1))


## `assist_close` of zero is a solo wall. It was the only thing this modelled,
## and once blockers began reading the pass a second blocker reached the lane
## often enough that the solo figure under-predicted the engine's block touch
## rate by three times -- 0.133 against a measured 0.428. A predictor that far
## out is worse than none, because a constant gets tuned against it.
static func block_values(
	players: Array,
	close_fraction: float,
	assist_close: float = 0.0,
) -> Array[float]:
	var simulator := RallySimulatorModel.new()
	var values: Array[float] = []
	for index in range(players.size()):
		var player: VolleyballPlayer = players[index] as VolleyballPlayer
		if player == null:
			continue
		var assist_skill := 0.0
		if assist_close > 0.0:
			## The assist is whoever else is on the court, not a second copy of
			## the primary.
			var partner: VolleyballPlayer = players[
				(index + 1) % players.size()
			] as VolleyballPlayer
			assist_skill = simulator._block_contact_skill(partner, assist_close)
		## Sealed positions, because this harness is measuring what the *skill*
		## terms are worth. A seam is a separate quantity with its own scale, and
		## letting it vary here would fold two answers into one column.
		values.append(simulator._block_wall_quality(
			simulator._block_contact_skill(player, close_fraction), assist_skill,
			0.5, 0.5,
		))
	return values


## Attack quality for every player in every named situation.
##
## No block pressure and no overreach: this is the swing the execution model
## produces before anything is taken off it, which is what the capability
## weights have to be sized against.
static func attack_scale(players: Array[VolleyballPlayer]) -> Dictionary:
	var rows := {}
	for situation_name in SITUATIONS:
		rows[situation_name] = summarise(attack_values(players, str(situation_name)))
	return rows


## Block quality at each close fraction, through the same wall formula the
## resolver uses for a solo block.
static func block_scale(players: Array[VolleyballPlayer]) -> Dictionary:
	var rows := {}
	for close in CLOSE_FRACTIONS:
		rows["close_%.1f" % close] = summarise(block_values(players, close))
	return rows


## `contest_shares` lived here and has been deleted.
##
## It paired a random swing with a random block, applied `BLOCK_STUFF_MARGIN` and
## its two siblings, and reported the resulting mix as what the block does. That
## stopped being true when `ENABLE_GEOMETRIC_ATTACK` opened: the geometric path
## overwrites the outcome and those three thresholds decide nothing. So it
## projected a branch production does not take -- and it had no callers, so it was
## a wrong answer nobody was even asking for.
##
## Recorded rather than silently removed because this is the second instance of
## the same defect in as many days. Gate D's harness had also fallen behind the
## resolver it was meant to calibrate, and for the same reason: nothing ran it, so
## nothing noticed.


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
