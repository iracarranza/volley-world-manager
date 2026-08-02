class_name VolleyballSixnetLeague
extends RefCounted

## Background world-league engine for the Sixnet Championship: 8 slots (4
## upper bracket + 4 lower bracket) filled from the 6 core regions
## (`VolleyballRegions.CORE_REGIONS` -- Ispayk and A'ace are deliberately
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

## Where the two non-core regions enter the bracket at world generation.
## A'ace buys its way straight into the top table; Ispayk starts in the
## lower bracket it fell into. Neither is pinned there afterward -- both
## promote and relegate like any other participant.
const AACE_FIXED_SLOT: String = "upper_1"
const ISPAYK_FIXED_SLOT: String = "lower_1"

## Rating gap at which a 1-vs-1 match is ~88% decisive -- decisive but never
## a certainty, so an underdog region's slot-team can still upset.
const SIXNET_LOGISTIC_K: float = 0.08

const POWER_MIN: float = 10.0
const POWER_MAX: float = 95.0
## How much a single season's result pulls region_power toward that season's
## win-rate-implied target. Deliberately partial: one dominant season nudges
## power, it cannot swing it 30 points in a year.
const POWER_SEASON_PULL: float = 0.25

## Influence-drift thresholds and caps -- named consts, not buried magic
## numbers, since this mechanic (per the user's own uncertainty about it) is
## the piece most likely to need retuning after being observed over real
## synthetic seasons.
const DOMINANCE_THRESHOLD: float = 15.0
const ISOLATION_THRESHOLD: float = 40.0
const MAX_BLENDED_ATTRIBUTES: int = 2
const MAX_SPECIALTY_BONUS_DELTA: float = 6.0  ## base +8 specialty bonus can reach +14
const INTENSIFY_STEP: float = 2.0
const BLEND_BIAS_FRACTION: float = 0.15


## Idempotent: a no-op once `career.sixnet_slots` is populated. Called at the
## top of every `advance_week()` so a save from before this feature existed
## lazily backfills on first use instead of never getting a league at all.
static func ensure_bootstrapped(career: Resource) -> void:
	if not career.sixnet_slots.is_empty():
		return
	var initial_power := {}
	for region_name in Regions.SIXNET_PARTICIPANTS:
		initial_power[region_name] = bootstrap_rating(
			region_name, int(hash(str(career.career_name) + str(region_name)))
		)
	career.region_power = initial_power.duplicate(true)
	career.sixnet_slots = allocate_slots(initial_power)
	career.sixnet_season_start_week = career.absolute_week


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
## A'ace and Ispayk take a *fixed starting* slot that expresses their story
## rather than their measured strength: A'ace enters straight into the upper
## bracket (it bought its way to the top table without earning it), Ispayk
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
	var slots := {AACE_FIXED_SLOT: "A'ace", ISPAYK_FIXED_SLOT: "Ispayk"}
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


## Round-robin within each 4-team bracket (6 pairings x 2 brackets = 12
## matches), resolved synchronously in one batch -- cheap enough (12 RNG
## draws) that there's no need to spread this across the year's 48 weeks or
## add background threading. Never touches the player's own `career.fixtures`;
## this is a background league the player doesn't play in.
static func resolve_full_season(career: Resource) -> Dictionary:
	var standings := {}
	for slot_id in ALL_SLOT_IDS:
		standings[slot_id] = _empty_record()
	var match_seed_base := int(career.sixnet_season_start_week) * 7919 \
		+ int(hash(str(career.career_name)))
	var match_index := 0
	for slot_ids in [UPPER_SLOT_IDS, LOWER_SLOT_IDS]:
		for pairing in _round_robin_pairings(slot_ids):
			var slot_a: String = pairing[0]
			var slot_b: String = pairing[1]
			var region_a := str(career.sixnet_slots.get(slot_a, ""))
			var region_b := str(career.sixnet_slots.get(slot_b, ""))
			var rating_a := float(career.region_power.get(region_a, 50.0))
			var rating_b := float(career.region_power.get(region_b, 50.0))
			var result := resolve_match(rating_a, rating_b, match_seed_base + match_index)
			match_index += 1
			_record_result(standings, slot_a, slot_b, result)
	career.sixnet_standings = standings
	return {"standings": standings}


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
## Ispayk and A'ace play in the Sixnet and so their power moves with their
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
		var current := float(career.region_power.get(region_name, 50.0))
		career.region_power[region_name] = clampf(
			lerpf(current, target, POWER_SEASON_PULL), POWER_MIN, POWER_MAX
		)


## A pure 1-for-1 slot-occupant swap between the worst-ranked upper-bracket
## region and the best-ranked lower-bracket region -- never a slot
## removal/addition, preserving the fixed 8-slot invariant the whole system
## depends on.
static func apply_promotion_relegation(career: Resource) -> void:
	var upper_ranked := _rank_slots_by_wins(career, UPPER_SLOT_IDS)
	var lower_ranked := _rank_slots_by_wins(career, LOWER_SLOT_IDS)
	if upper_ranked.is_empty() or lower_ranked.is_empty():
		return
	var worst_upper_slot: String = upper_ranked[upper_ranked.size() - 1]
	var best_lower_slot: String = lower_ranked[0]
	var worst_upper_region := str(career.sixnet_slots[worst_upper_slot])
	var best_lower_region := str(career.sixnet_slots[best_lower_slot])
	if worst_upper_region == best_lower_region:
		return  ## same region already holds both slots -- nothing to swap
	career.sixnet_slots[worst_upper_slot] = best_lower_region
	career.sixnet_slots[best_lower_slot] = worst_upper_region


static func _rank_slots_by_wins(career: Resource, slot_ids: Array) -> Array:
	var ranked: Array = slot_ids.duplicate()
	var standings: Dictionary = career.sixnet_standings
	ranked.sort_custom(func(a, b):
		var record_a: Dictionary = standings.get(a, _empty_record())
		var record_b: Dictionary = standings.get(b, _empty_record())
		return int(record_a.get("wins", 0)) > int(record_b.get("wins", 0))
	)
	return ranked


## The two-branch influence mechanic: a region with a meaningfully stronger
## neighbor blends toward it (broadens what the region is good at, capped);
## a region with no dominant neighbor but genuinely low power instead
## intensifies its own existing specialty (narrows and deepens it, capped).
## One shared entry check, one overlay dict -- two legible, narratively
## distinct outcomes rather than two competing systems.
static func apply_influence_drift(career: Resource) -> void:
	for region_name in Regions.CORE_REGIONS:
		var neighbors: Array = Array(Regions.REGION_ADJACENCY.get(region_name, []))
		var own_power := float(career.region_power.get(region_name, 50.0))
		var strongest_neighbor := ""
		var strongest_gap := 0.0
		for neighbor in neighbors:
			var gap := float(career.region_power.get(neighbor, 50.0)) - own_power
			if gap > strongest_gap:
				strongest_gap = gap
				strongest_neighbor = str(neighbor)
		if strongest_gap > DOMINANCE_THRESHOLD and not strongest_neighbor.is_empty():
			_blend_specialty_toward(career, region_name, strongest_neighbor)
		elif own_power < ISOLATION_THRESHOLD:
			_intensify_own_specialty(career, region_name)


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
