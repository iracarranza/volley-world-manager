class_name VolleyballSixnetLeague
extends RefCounted

## Background world-league engine for the Sixnet Championship: 8 slots (4
## upper bracket + 4 lower bracket) filled from the 6 core regions
## (`VolleyballRegions.CORE_REGIONS` -- Ĭspayk and A'ace are deliberately
## excluded, see `docs/world/STYLE_AND_SETTING.md`). Everything here is a
## lightweight, abstracted resolver on purpose: it produces a scalar rating
## per region and a sets-won/lost result per match, nothing set-by-set or
## point-by-point. Simulating 8 teams through a full season every year with
## `RallySimulator` (a 4500+ line rally-by-rally engine built for one live
## match at a time) would be both the wrong tool and a second, competing
## simulation engine -- resist adding serve/rotation/momentum detail here.

const PlayerGeneratorModel := preload("res://scripts/systems/player_generator.gd")
const Regions := preload("res://scripts/data/regions.gd")

const UPPER_SLOT_IDS: Array[String] = ["upper_1", "upper_2", "upper_3", "upper_4"]
const LOWER_SLOT_IDS: Array[String] = ["lower_1", "lower_2", "lower_3", "lower_4"]
const ALL_SLOT_IDS: Array[String] = [
	"upper_1", "upper_2", "upper_3", "upper_4",
	"lower_1", "lower_2", "lower_3", "lower_4",
]

## Where the two non-core regions enter at world generation, both at the
## *bottom* of their bracket. A'ace bought a seat at the top table and is
## the least established team sitting at it; Ĭspayk is rock bottom of
## everything. Neither is pinned there afterward -- both promote and
## relegate like any other participant.
const AACE_FIXED_SLOT: String = "upper_4"
const ISPAYK_FIXED_SLOT: String = "lower_4"

## How many lower-bracket teams survive the qualifier and join the
## championship proper. Four auto-qualified plus these two is what makes the
## Sixnet six.
const QUALIFIER_ADVANCE_COUNT: int = 2

## Rating gap at which a 1-vs-1 match is ~88% decisive -- decisive but never
## a certainty, so an underdog region's slot-team can still upset.
const SIXNET_LOGISTIC_K: float = 0.08

const POWER_MIN: float = 10.0
const POWER_MAX: float = 95.0
## How much a single season's result pulls Sixnet form toward that season's
## win-rate-implied target. Deliberately partial: one dominant season nudges
## power, it cannot swing it 30 points in a year.
const POWER_SEASON_PULL: float = 0.25

## Influence-drift thresholds and caps -- named consts, not buried magic
## numbers, since this mechanic (per the user's own uncertainty about it) is
## the piece most likely to need retuning after being observed over real
## synthetic seasons.
## Real-population prime/depth strength measures about 70-82 across six test
## worlds. Four points is a visible regional gap on that scale; 74 marks a
## genuinely weak production year without classifying half the world as poor.
const DOMINANCE_THRESHOLD: float = 4.0

## The one region that ignores geography. See `_adopt_zeitgeist()`.
const ZEITGEIST_REGION: String = "Zaitgaist"
const ISOLATION_THRESHOLD: float = 74.0
const MAX_BLENDED_ATTRIBUTES: int = 2
const MAX_SPECIALTY_BONUS_DELTA: float = 6.0  ## base +8 specialty bonus can reach +14
const INTENSIFY_STEP: float = 2.0
const BLEND_BIAS_FRACTION: float = 0.15
const PRIME_WEIGHT: float = 0.65
const PRIME_MEAN_WEIGHT: float = 0.70
const PRIME_BEST_WEIGHT: float = 0.15
const PRIME_WEAK_WEIGHT: float = 0.15
const REGIONAL_BEST_SEVEN := {
	"Setter": 1,
	"Outside Hitter": 2,
	"Middle Blocker": 2,
	"Opposite": 1,
	"Libero": 1,
}


## Idempotent: a no-op once `career.sixnet_slots` is populated. Called at the
## top of every `advance_week()` so a save from before this feature existed
## lazily backfills on first use instead of never getting a league at all.
static func ensure_bootstrapped(career: Resource, population: Array = []) -> void:
	if not population.is_empty():
		career.region_strength = calculate_region_strengths(population)
	if not career.sixnet_slots.is_empty():
		return
	var initial_strength: Dictionary = career.region_strength.duplicate(true)
	var initial_form: Dictionary = {}
	for region_name in Regions.SIXNET_PARTICIPANTS:
		if not initial_strength.has(region_name):
			initial_strength[region_name] = bootstrap_rating(
				region_name, int(hash(str(career.career_name) + str(region_name)))
			)
		initial_form[region_name] = float(initial_strength[region_name])
	career.region_strength = initial_strength
	career.sixnet_form = initial_form
	career.sixnet_slots = allocate_slots(initial_strength)
	career.sixnet_season_start_week = career.absolute_week


static func calculate_region_strengths(population: Array) -> Dictionary:
	var result := {}
	for region_name in Regions.DEFINITIONS:
		var regional_players: Array[VolleyballPlayer] = []
		for player_resource in population:
			var player := player_resource as VolleyballPlayer
			if player != null and str(player.home_region) == str(region_name):
				regional_players.append(player)
		if not regional_players.is_empty():
			result[str(region_name)] = region_strength(regional_players)
	return result


static func region_strength(players: Array[VolleyballPlayer]) -> float:
	var selected: Array[VolleyballPlayer] = []
	var selected_ids := {}
	for role_name in REGIONAL_BEST_SEVEN:
		var candidates: Array[VolleyballPlayer] = []
		for player in players:
			if player.position_role == str(role_name):
				candidates.append(player)
		candidates.sort_custom(func(a, b):
			return a.current_ability_score() > b.current_ability_score()
		)
		for index in range(mini(int(REGIONAL_BEST_SEVEN[role_name]), candidates.size())):
			selected.append(candidates[index])
			selected_ids[candidates[index].id] = true
	if selected.is_empty():
		return 50.0
	var prime_values: Array[float] = []
	for player in selected:
		prime_values.append(float(player.current_ability_score()))
	var prime: float = _mean(prime_values) * PRIME_MEAN_WEIGHT \
		+ prime_values.max() * PRIME_BEST_WEIGHT \
		+ prime_values.min() * PRIME_WEAK_WEIGHT
	var reserves: Array[VolleyballPlayer] = []
	for player in players:
		if not selected_ids.has(player.id):
			reserves.append(player)
	reserves.sort_custom(func(a, b):
		return a.current_ability_score() > b.current_ability_score()
	)
	var depth_values: Array[float] = []
	for index in range(mini(7, reserves.size())):
		depth_values.append(float(reserves[index].current_ability_score()))
	var depth: float = _mean(depth_values) if not depth_values.is_empty() else prime
	return prime * PRIME_WEIGHT + depth * (1.0 - PRIME_WEIGHT)


static func _mean(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / maxf(float(values.size()), 1.0)


## A region's rating is generated, not invented: one sample Academy-tier
## roster from the existing generator, averaged by
## `VolleyballPlayer.current_ability_score()`. The roster itself is discarded
## immediately -- only the scalar is ever kept. Re-invoked whenever a slot's
## region-occupant changes (promotion/relegation), since rating belongs to
## the region, never to the slot.
static func bootstrap_rating(region_name: String, seed_value: int) -> float:
	var roster: Array[VolleyballPlayer] = PlayerGeneratorModel.generate_roster(
		region_name, "Academy", seed_value
	)
	var total := 0.0
	for player in roster:
		total += float(player.current_ability_score())
	return total / maxf(float(roster.size()), 1.0)


## Eight regions, eight slots, exactly one each -- no region ever holds two.
##
## A'ace and Ĭspayk take a *fixed starting* slot that expresses their story
## rather than their measured strength: A'ace enters straight into the upper
## bracket (it bought its way to the top table without earning it), Ĭspayk
## into the lower (a fallen flagship clawing back). Both are ordinary
## competitors from that point on -- promotion and relegation move them like
## anyone else, so "always starts" is a starting condition, not a permanent
## pin.
##
## The six core regions fill what's left strictly by power: the strongest
## three take the remaining upper slots, the other three the remaining lower
## slots.
static func allocate_slots(initial_power: Dictionary, _seed_value: int = 0) -> Dictionary:
	var ranked: Array = Regions.CORE_REGIONS.duplicate()
	ranked.sort_custom(func(a, b):
		return float(initial_power.get(a, 50.0)) > float(initial_power.get(b, 50.0))
	)
	var slots := {AACE_FIXED_SLOT: "A'ace", ISPAYK_FIXED_SLOT: "Ĭspayk"}
	var open_upper: Array[String] = []
	for slot_id in UPPER_SLOT_IDS:
		if not slots.has(slot_id):
			open_upper.append(slot_id)
	var open_lower: Array[String] = []
	for slot_id in LOWER_SLOT_IDS:
		if not slots.has(slot_id):
			open_lower.append(slot_id)
	for index in range(open_upper.size()):
		slots[open_upper[index]] = ranked[index]
	for index in range(open_lower.size()):
		slots[open_lower[index]] = ranked[open_upper.size() + index]
	return slots


static func win_probability(rating_a: float, rating_b: float) -> float:
	return 1.0 / (1.0 + exp(-SIXNET_LOGISTIC_K * (rating_a - rating_b)))


## Best-of-5 sets, each an independent seeded Bernoulli draw at
## `win_probability`, first to 3 wins the match. Deliberately stops here --
## no point margins, no per-set momentum. Sets won/lost is enough resolution
## for standings and flavor without a second simulation engine.
static func resolve_match(rating_a: float, rating_b: float, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var probability := win_probability(rating_a, rating_b)
	var sets_a := 0
	var sets_b := 0
	while sets_a < 3 and sets_b < 3:
		if rng.randf() < probability:
			sets_a += 1
		else:
			sets_b += 1
	return {"sets_a": sets_a, "sets_b": sets_b}


static func _round_robin_pairings(slot_ids: Array) -> Array:
	var pairings := []
	for i in range(slot_ids.size()):
		for j in range(i + 1, slot_ids.size()):
			pairings.append([slot_ids[i], slot_ids[j]])
	return pairings


static func _empty_record() -> Dictionary:
	return {"wins": 0, "losses": 0, "sets_won": 0, "sets_lost": 0}


## A season in two stages, which is what makes the name honest again.
##
## The four lower-bracket teams play a qualifying round robin first (6
## matches). The best two survive and join the four auto-qualified upper
## teams for the championship proper -- six teams, fifteen matches. That is
## the Sixnet: the tournament has always been six, and the eight-team field
## added earlier quietly made the name a lie until this stage existed.
##
## Both stages are recorded, separately as well as combined, because they
## answer different questions: the qualifier decides who comes up, the
## championship decides who is champion, and a team's power should move on
## everything it played. Twenty-one matches resolve in one synchronous
## batch; this never touches the player's own `career.fixtures`.
static func resolve_full_season(career: Resource) -> Dictionary:
	var standings := {}
	for slot_id in ALL_SLOT_IDS:
		standings[slot_id] = _empty_record()
	var qualifier_standings := {}
	for slot_id in LOWER_SLOT_IDS:
		qualifier_standings[slot_id] = _empty_record()
	var match_seed_base := int(career.sixnet_season_start_week) * 7919 \
		+ int(hash(str(career.career_name)))
	var match_index := 0

	## Stage one: the lower bracket plays for the two open championship places.
	for pairing in _round_robin_pairings(LOWER_SLOT_IDS):
		var result := _resolve_slot_pairing(
			career, pairing[0], pairing[1], match_seed_base + match_index
		)
		match_index += 1
		_record_result(standings, pairing[0], pairing[1], result)
		_record_result(qualifier_standings, pairing[0], pairing[1], result)

	## Stage two: the four seeded teams plus whoever came through.
	var qualified: Array[String] = []
	for slot_id in _rank_slots(qualifier_standings, LOWER_SLOT_IDS):
		if qualified.size() < QUALIFIER_ADVANCE_COUNT:
			qualified.append(slot_id)
	var championship_slots: Array[String] = []
	championship_slots.append_array(UPPER_SLOT_IDS)
	championship_slots.append_array(qualified)
	var championship_standings := {}
	for slot_id in championship_slots:
		championship_standings[slot_id] = _empty_record()
	for pairing in _round_robin_pairings(championship_slots):
		var result := _resolve_slot_pairing(
			career, pairing[0], pairing[1], match_seed_base + match_index
		)
		match_index += 1
		_record_result(standings, pairing[0], pairing[1], result)
		_record_result(championship_standings, pairing[0], pairing[1], result)

	var champion_slots := _rank_slots(championship_standings, championship_slots)
	career.sixnet_standings = standings
	career.sixnet_qualifier_standings = qualifier_standings
	career.sixnet_championship_standings = championship_standings
	career.sixnet_qualified_slots.assign(qualified)
	career.sixnet_champion_region = str(
		career.sixnet_slots.get(champion_slots[0], "")
	) if not champion_slots.is_empty() else ""
	return {
		"standings": standings, "qualifier": qualifier_standings,
		"championship": championship_standings, "qualified": qualified,
		"champion": career.sixnet_champion_region,
	}


static func _resolve_slot_pairing(
	career: Resource, slot_a: String, slot_b: String, seed_value: int,
) -> Dictionary:
	var region_a := str(career.sixnet_slots.get(slot_a, ""))
	var region_b := str(career.sixnet_slots.get(slot_b, ""))
	return resolve_match(
		float(career.sixnet_form.get(region_a, 50.0)),
		float(career.sixnet_form.get(region_b, 50.0)),
		seed_value,
	)


## Orders slots best-first on wins, then set difference as the tiebreak, so
## a qualifier that ends level does not resolve on dictionary order.
static func _rank_slots(standings: Dictionary, slot_ids: Array) -> Array[String]:
	var ranked: Array[String] = []
	ranked.assign(slot_ids)
	ranked.sort_custom(func(a, b):
		var record_a: Dictionary = standings.get(a, _empty_record())
		var record_b: Dictionary = standings.get(b, _empty_record())
		var wins_a := int(record_a.get("wins", 0))
		var wins_b := int(record_b.get("wins", 0))
		if wins_a != wins_b:
			return wins_a > wins_b
		var diff_a := int(record_a.get("sets_won", 0)) - int(record_a.get("sets_lost", 0))
		var diff_b := int(record_b.get("sets_won", 0)) - int(record_b.get("sets_lost", 0))
		return diff_a > diff_b
	)
	return ranked


static func _record_result(
	standings: Dictionary, slot_a: String, slot_b: String, result: Dictionary,
) -> void:
	var sets_a := int(result.get("sets_a", 0))
	var sets_b := int(result.get("sets_b", 0))
	var record_a: Dictionary = standings[slot_a]
	var record_b: Dictionary = standings[slot_b]
	record_a["sets_won"] = int(record_a.get("sets_won", 0)) + sets_a
	record_a["sets_lost"] = int(record_a.get("sets_lost", 0)) + sets_b
	record_b["sets_won"] = int(record_b.get("sets_won", 0)) + sets_b
	record_b["sets_lost"] = int(record_b.get("sets_lost", 0)) + sets_a
	if sets_a > sets_b:
		record_a["wins"] = int(record_a.get("wins", 0)) + 1
		record_b["losses"] = int(record_b.get("losses", 0)) + 1
	else:
		record_b["wins"] = int(record_b.get("wins", 0)) + 1
		record_a["losses"] = int(record_a.get("losses", 0)) + 1


static func _combined_record(career: Resource, region_name: String) -> Dictionary:
	var combined := _empty_record()
	for slot_id in career.sixnet_slots:
		if str(career.sixnet_slots[slot_id]) != region_name:
			continue
		var record: Dictionary = career.sixnet_standings.get(slot_id, _empty_record())
		combined["wins"] = int(combined["wins"]) + int(record.get("wins", 0))
		combined["losses"] = int(combined["losses"]) + int(record.get("losses", 0))
		combined["sets_won"] = int(combined["sets_won"]) + int(record.get("sets_won", 0))
		combined["sets_lost"] = int(combined["sets_lost"]) + int(record.get("sets_lost", 0))
	return combined


## Smoothed toward this season's result, not snapped to it (see
## `POWER_SEASON_PULL`), and clamped to `[POWER_MIN, POWER_MAX]` so no region
## is ever permanently unbeatable or permanently dead across a long career.
## Covers all eight bracket participants, not just the six core regions:
## Ĭspayk and A'ace play in the Sixnet and so their form moves with their
## results too. (Influence *drift* below stays core-only -- that mechanic is
## about geography, which those two deliberately sit outside of.)
static func apply_power_update(career: Resource) -> void:
	for region_name in Regions.SIXNET_PARTICIPANTS:
		var record := _combined_record(career, region_name)
		var games := int(record.get("wins", 0)) + int(record.get("losses", 0))
		if games == 0:
			continue
		var win_rate := float(record.get("wins", 0)) / float(games)
		var target := lerpf(30.0, 90.0, win_rate)
		var current := float(career.sixnet_form.get(region_name, 50.0))
		career.sixnet_form[region_name] = clampf(
			lerpf(current, target, POWER_SEASON_PULL), POWER_MIN, POWER_MAX
		)


## A pure 1-for-1 slot-occupant swap -- never a slot removal or addition,
## preserving the fixed 8-slot invariant the whole system depends on.
##
## Each stage judges its own teams: the relegated side is whoever finished
## last *in the championship* among the seeded four, and the promoted side is
## whoever won *the qualifier*. Judging both off one combined table would
## punish an upper team for a stage it never played and reward a lower team
## for beating opponents the upper teams never faced.
static func apply_promotion_relegation(career: Resource) -> void:
	var championship: Dictionary = career.sixnet_championship_standings
	var qualifier: Dictionary = career.sixnet_qualifier_standings
	if championship.is_empty() or qualifier.is_empty():
		return
	var seeded_ranked := _rank_slots(championship, UPPER_SLOT_IDS)
	var qualifier_ranked := _rank_slots(qualifier, LOWER_SLOT_IDS)
	if seeded_ranked.is_empty() or qualifier_ranked.is_empty():
		return
	var worst_upper_slot: String = seeded_ranked[seeded_ranked.size() - 1]
	var best_lower_slot: String = qualifier_ranked[0]
	var worst_upper_region := str(career.sixnet_slots[worst_upper_slot])
	var best_lower_region := str(career.sixnet_slots[best_lower_slot])
	if worst_upper_region == best_lower_region:
		return
	career.sixnet_slots[worst_upper_slot] = best_lower_region
	career.sixnet_slots[best_lower_slot] = worst_upper_region


## The two-branch influence mechanic: a region with a meaningfully stronger
## neighbor blends toward it (broadens what the region is good at, capped);
## a region with no dominant neighbor but genuinely low power instead
## intensifies its own existing specialty (narrows and deepens it, capped).
## One shared entry check, one overlay dict -- two legible, narratively
## distinct outcomes rather than two competing systems.
## Scoped to `DEVELOPMENT_REGIONS` -- core plus minor -- rather than
## `CORE_REGIONS`. Ĭspayk and A'ace stay out: their identities come from
## history and money, not from a local tradition that could spread.
static func apply_influence_drift(career: Resource) -> void:
	for region_name in Regions.DEVELOPMENT_REGIONS:
		## Zaitgaist has no tradition to defend and no neighbor it listens to.
		## Each season it simply becomes whatever just won the Sixnet, so it
		## skips the dominance and isolation branches entirely. Everything else
		## in this system is geographic; this is the one rule that is not.
		if region_name == ZEITGEIST_REGION:
			_adopt_zeitgeist(career)
			continue
		var neighbors: Array = Array(Regions.REGION_ADJACENCY.get(region_name, []))
		var own_power := float(career.region_strength.get(region_name, 50.0))
		var strongest_neighbor := ""
		var strongest_gap := 0.0
		for neighbor in neighbors:
			var gap := float(career.region_strength.get(neighbor, 50.0)) - own_power
			if gap > strongest_gap:
				strongest_gap = gap
				strongest_neighbor = str(neighbor)
		## A minor region is by design far weaker than any major neighbor, so
		## without resistance the gap would clear the threshold every season:
		## minor traditions would blend every year, never intensify, and lose
		## the specialization that is the entire reason the tier exists.
		var threshold := DOMINANCE_THRESHOLD \
			* (1.0 + Regions.tradition_resistance(region_name))
		if strongest_gap > threshold and not strongest_neighbor.is_empty():
			_blend_specialty_toward(career, region_name, strongest_neighbor)
		elif own_power < ISOLATION_THRESHOLD:
			_intensify_own_specialty(career, region_name)


## Zaitgaist adopts the reigning champion's specialty wholesale -- the champion
## rather than the strongest region, so it copies what *won* rather than what
## was objectively best. That builds in a one-season lag: it is permanently
## playing last year's winning style, which is the joke, the mechanic, and the
## reason it can never lead.
static func _adopt_zeitgeist(career: Resource) -> void:
	var champion := str(career.sixnet_champion_region)
	if champion.is_empty() or champion == ZEITGEIST_REGION:
		return
	var overlay: Dictionary = _region_overlay_entry(career, ZEITGEIST_REGION)
	var champion_specialty: Array = Array(
		PlayerGeneratorModel.REGION_SPECIALTY.get(champion, [])
	)
	overlay["specialty_add"] = champion_specialty.duplicate()
	overlay["zeitgeist_source"] = champion
	## Never accumulates. Zaitgaist replaces its borrowed identity outright
	## each time rather than layering one champion's tradition on the last --
	## it has no tradition of its own for them to layer onto.
	overlay.erase("specialty_bonus_delta")


static func _region_overlay_entry(career: Resource, region_name: String) -> Dictionary:
	if not career.region_overlay.has(region_name):
		career.region_overlay[region_name] = {}
	return career.region_overlay[region_name]


static func _blend_specialty_toward(
	career: Resource, region_name: String, neighbor_name: String,
) -> void:
	var overlay: Dictionary = _region_overlay_entry(career, region_name)
	var specialty_add: Array = Array(overlay.get("specialty_add", []))
	if specialty_add.size() < MAX_BLENDED_ATTRIBUTES:
		var neighbor_specialty: Array = Array(
			PlayerGeneratorModel.REGION_SPECIALTY.get(neighbor_name, [])
		)
		var own_specialty: Array = Array(PlayerGeneratorModel.REGION_SPECIALTY.get(region_name, []))
		for attribute_name in neighbor_specialty:
			if attribute_name in own_specialty or attribute_name in specialty_add:
				continue
			specialty_add.append(attribute_name)
			break
	overlay["specialty_add"] = specialty_add
	overlay["height_bias_delta"] = _blended_bias_delta(
		overlay, "height_bias_delta", PlayerGeneratorModel.REGION_HEIGHT_BIAS,
		region_name, neighbor_name,
	)
	overlay["mass_bias_delta"] = _blended_bias_delta(
		overlay, "mass_bias_delta", PlayerGeneratorModel.REGION_MASS_BIAS,
		region_name, neighbor_name,
	)
	overlay["wingspan_bias_delta"] = _blended_bias_delta(
		overlay, "wingspan_bias_delta", PlayerGeneratorModel.REGION_WINGSPAN_BIAS,
		region_name, neighbor_name,
	)
	career.region_overlay[region_name] = overlay


static func _blended_bias_delta(
	overlay: Dictionary, delta_key: String, bias_const: Dictionary,
	region_name: String, neighbor_name: String,
) -> float:
	var region_bias := float(bias_const.get(region_name, 0.0))
	var neighbor_bias := float(bias_const.get(neighbor_name, 0.0))
	return lerpf(float(overlay.get(delta_key, 0.0)), neighbor_bias - region_bias, BLEND_BIAS_FRACTION)


static func _intensify_own_specialty(career: Resource, region_name: String) -> void:
	var overlay: Dictionary = _region_overlay_entry(career, region_name)
	overlay["specialty_bonus_delta"] = clampf(
		float(overlay.get("specialty_bonus_delta", 0.0)) + INTENSIFY_STEP,
		0.0, MAX_SPECIALTY_BONUS_DELTA,
	)
	career.region_overlay[region_name] = overlay


## Bundles the full season-boundary sequence in the order it must run:
## resolve the season's matches, update power from that season's results,
## swap the contested slot, then let the new power levels drive this
## season's influence drift. Called once per year from
## `CareerManager.advance_week()`.
static func resolve_season_boundary(career: Resource) -> void:
	resolve_full_season(career)
	apply_power_update(career)
	apply_promotion_relegation(career)
	apply_influence_drift(career)
	career.sixnet_season_start_week = career.absolute_week
