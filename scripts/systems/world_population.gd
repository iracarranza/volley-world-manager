class_name VolleyballWorldPopulation
extends RefCounted

## The world's players, generated once and then kept.
##
## Generation used to be on-demand: every roster and every transfer market
## was rolled fresh at the moment something needed players, which meant the
## world had no shape of its own. Two academies could both be full of
## once-in-a-generation talents, because nothing was counting. A world where
## every age from 15 to 30 is stocked with wonderkids has no wonderkids in
## it -- scarcity is what makes a prospect worth finding.
##
## So talent here is an allocated budget, not a per-player dice roll: a small
## fixed headcount of generational and elite players exists *for the entire
## world*, and everyone else fills in below them.
##
## Three things fall out of that budget rather than being written by hand,
## and between them they are what give the world a history:
##
## 1. **Golden generations.** The scarce budget is apportioned across single
##    birth years rather than spread evenly, with deliberate spacing, so most
##    years produce nobody special and occasionally one produces a cluster.
##
## 2. **Origin is not destination.** Talent is *born* evenly across the world
##    and *accumulates* wherever the money is. Nowhere breeds champions;
##    rich programs collect them. A'ace fields stars it never raised, Ispayk
##    raises players it cannot keep, and aging stars filter back down to the
##    programs that will still have them.
##
## 3. **Current ability is never allocated.** It falls out of age through the
##    same development curve every generated player uses, so one potential
##    number plus an age yields either a raw prospect or a finished star.

const PlayerGeneratorModel := preload("res://scripts/systems/player_generator.gd")
const Regions := preload("res://scripts/data/regions.gd")

## Sized so each of the eight regions supports a real club scene rather than
## a single squad. At 1200 a region held ~150 players -- about one club plus
## an academy, which cannot carry the "dense web of regional orgs and clubs"
## the setting describes. At 4000 it is ~500, enough for a pipeline with
## depth beneath it. Costs measured at this size: ~1.2s to generate once at
## career creation, ~9MB on disk, ~1s to write -- and the world file is only
## rewritten when the population actually changes, which is once a season.
const DEFAULT_POPULATION_SIZE: int = 4000
const FIRST_POPULATION_ID: int = 100000

## Age bands and their share of the world. Deliberately a pyramid: far more
## teenagers exist than thirty-somethings, because most players never make it
## and drop out rather than aging into the top of the game.
const AGE_BANDS: Array[Dictionary] = [
	{"key": "youth", "min_age": 15, "max_age": 18, "share": 0.26},
	{"key": "emerging", "min_age": 19, "max_age": 22, "share": 0.24},
	{"key": "prime", "min_age": 23, "max_age": 27, "share": 0.27},
	{"key": "veteran", "min_age": 28, "max_age": 32, "share": 0.17},
	{"key": "twilight", "min_age": 33, "max_age": 38, "share": 0.06},
]

## Talent tiers by potential band.
##
## `world_total` is an absolute headcount **for the entire world at the
## default population size** -- not a probability. That is the whole
## mechanism: eight generational players exist across every age alive at
## once, so finding one is an event rather than a dice roll that a big
## enough world is guaranteed to pass. Tiers with a `world_total` of 0 take
## a share of whatever headcount is left over, split by `remainder_weight`.
##
## These totals are spread across single birth cohorts rather than broad age
## bands, which is what allows golden generations -- see `golden_cohorts()`.
## `scales_with_population` decides whether a tier's total grows when the
## world does. Generational talent deliberately does *not*: a larger world
## should contain more journeymen, not more once-in-a-generation players, or
## "generational" just means "rare in a small world". Elite and standout do
## scale -- they are "very good", and a world with twice the players
## plausibly has twice as many very good ones.
const TALENT_TIERS: Array[Dictionary] = [
	{"key": "generational", "pa_min": 92, "pa_max": 99, "world_total": 8,
		"scales_with_population": false, "remainder_weight": 0.0},
	{"key": "elite", "pa_min": 84, "pa_max": 91, "world_total": 24,
		"scales_with_population": true, "remainder_weight": 0.0},
	{"key": "standout", "pa_min": 76, "pa_max": 83, "world_total": 62,
		"scales_with_population": true, "remainder_weight": 0.0},
	{"key": "solid", "pa_min": 66, "pa_max": 75, "world_total": 0,
		"scales_with_population": true, "remainder_weight": 0.30},
	{"key": "squad", "pa_min": 54, "pa_max": 65, "world_total": 0,
		"scales_with_population": true, "remainder_weight": 0.44},
	{"key": "fringe", "pa_min": 38, "pa_max": 53, "world_total": 0,
		"scales_with_population": true, "remainder_weight": 0.26},
]


## The scarce headcount for a tier at a given world size. Kept in one place
## because both initial generation and the annual intake have to agree on it
## exactly, or the world drifts away from its own budget over a career.
static func tier_world_total(tier: Dictionary, population_size: int) -> int:
	if int(tier.world_total) <= 0:
		return 0
	if not bool(tier.scales_with_population):
		return int(tier.world_total)
	var scale := float(population_size) / float(DEFAULT_POPULATION_SIZE)
	return maxi(roundi(float(tier.world_total) * scale), 1)

const MIN_AGE: int = 15
const MAX_AGE: int = 38

## Golden generations.
##
## Scarce talent is apportioned per single birth year, not spread evenly, so
## some years produce a genuine cluster and most produce nobody. A cohort
## marked golden pulls this multiple of its ordinary share of the scarce
## tiers; the world total is unchanged, so a golden generation is talent
## *concentrated*, never talent added.
##
## Spacing is the point. Purely random marking clumps two golden years back
## to back and then goes quiet for fifteen; a fixed cadence is predictable.
## So a golden year cannot occur within `GOLDEN_MIN_GAP` of the last one,
## and after that the chance climbs each year until one lands -- unpredictable
## year to year, reliably periodic across a career.
const GOLDEN_MULTIPLIER: float = 4.0
const GOLDEN_MIN_GAP: int = 4
const GOLDEN_BASE_CHANCE: float = 0.16
const GOLDEN_CHANCE_RAMP: float = 0.11

## Tiers that count as "a prospect worth scouting" when young. Every region
## is guaranteed at least one of these in each of the two youngest bands, so
## no save ever produces a region with nothing to discover.
const SCOUTABLE_TIERS: Array[String] = ["generational", "elite", "standout"]
const GUARANTEED_YOUNG_TIER: String = "standout"

## How prolific each region is at *raising* players. This is the only thing
## that biases where a player is born -- there is deliberately no talent or
## age weighting here.
##
## Nowhere breeds champions. A region cannot make a child more likely to be
## generational, and it cannot make one more likely to be born a veteran;
## every region turns out teenagers every year and they age like anyone
## else. Weighting birth by talent was a mistake in the first version of
## this system: it made A'ace *produce* stars, when the entire point of
## A'ace is that it produces almost nothing and buys the rest. All of that
## now lives in migration below, where it belongs.
##
## A'ace is low because it is a young program with no pipeline yet. Ispayk
## stays high: a fallen flagship still has its academies and its coaching,
## which is exactly why losing the players hurts.
const REGION_BIRTH_WEIGHTS := {
	"A'ace": 0.35,
	"Ispayk": 1.20,
}

## Where talent *ends up*.
##
## Pull is a region's ability to attract and keep players -- money,
## facilities, prestige. This is the mechanism that fills A'ace's squads
## with players it never raised, and empties Ispayk of the ones it did.
const REGION_PULL := {
	"A'ace": 3.40,
	"Pāwa Hitō": 1.35,
	"Bloc du Larg": 1.15,
	"Landavol": 1.00,
	"Xérvu": 0.90,
	"Spëddigh": 0.80,
	"Taktikã": 0.80,
	"Ispayk": 0.45,
}

## How likely a player is to have moved at all, by how good they are. Talent
## is what gets scouted; a fringe player mostly stays where they grew up.
const MIGRATION_CHANCE_BY_TIER := {
	"generational": 0.78, "elite": 0.68, "standout": 0.52,
	"solid": 0.30, "squad": 0.16, "fringe": 0.07,
}

## Moves accumulate with a career, so an established player is far more
## likely to be somewhere other than home than a sixteen-year-old still in
## their first academy.
const MIGRATION_CHANCE_BY_BAND := {
	"youth": 0.25, "emerging": 0.75, "prime": 1.15,
	"veteran": 1.45, "twilight": 1.55,
}

## Players raised somewhere with little money leave more readily than
## players who are already at a program that can keep them. Applied as the
## origin region's pull raised to this (negative) exponent, so a poor region
## bleeds its own graduates while a rich one holds on to them.
##
## Without this the veteran story only half worked: aging players did filter
## down to Ispayk, but Ispayk's own large home-grown intake stayed put at
## every age and diluted the effect back toward the world average -- on some
## seeds below it. A fallen program does not just take in old players, it
## also loses its young ones, and it needs to do both for the shape to read.
const ORIGIN_RETENTION_EXPONENT: float = -0.50

## How strongly pull decides the destination, by age. Rich programs compete
## hardest for players entering their peak, so pull dominates there.
##
## The exponent goes *negative* once players are past it, inverting the
## ordering: clubs that can buy anyone stop buying thirty-year-olds, and the
## aging stars filter down to programs glad to have them. This is what fills
## Ispayk with veterans -- not a birth quirk, but a fallen flagship taking in
## players on the way back down.
##
## The turn has to come at the veteran band rather than only at the very
## end. With it starting only at 33-38 the effect was real but far too
## small to see: that band is six per cent of the world, so Ispayk's veteran
## share landed inside the noise of a region with no lean at all.
const PULL_EXPONENT_BY_BAND := {
	"youth": 0.85, "emerging": 1.20, "prime": 1.20,
	"veteran": -1.00, "twilight": -1.50,
}

## Roster-shaped position mix, so the world can actually field teams.
const POSITION_MIX: Array[Dictionary] = [
	{"role": "Setter", "code": "S", "weight": 0.16},
	{"role": "Outside Hitter", "code": "OH", "weight": 0.30},
	{"role": "Middle Blocker", "code": "M", "weight": 0.24},
	{"role": "Opposite", "code": "OP", "weight": 0.16},
	{"role": "Libero", "code": "L", "weight": 0.14},
]


static func band_for_age(age: int) -> String:
	for band in AGE_BANDS:
		if age >= int(band.min_age) and age <= int(band.max_age):
			return str(band.key)
	return str(AGE_BANDS[AGE_BANDS.size() - 1].key)


static func tier_for_potential(potential: int) -> String:
	for tier in TALENT_TIERS:
		if potential >= int(tier.pa_min) and potential <= int(tier.pa_max):
			return str(tier.key)
	return str(TALENT_TIERS[TALENT_TIERS.size() - 1].key)


## Headcount for every single-year cohort, summing to exactly
## `population_size`.
##
## Rounding each cohort independently drifts -- twenty-four
## independently-rounded shares landed a world of 1200 on 1202 -- so the
## fractions are settled by largest remainder instead. A caller asking for a
## population of n gets n.
static func cohort_sizes(population_size: int) -> Dictionary:
	var exact := {}
	var sizes := {}
	var assigned := 0
	for band in AGE_BANDS:
		var years := int(band.max_age) - int(band.min_age) + 1
		var per_year := float(population_size) * float(band.share) / float(years)
		for age in range(int(band.min_age), int(band.max_age) + 1):
			exact[age] = per_year
			sizes[age] = maxi(floori(per_year), 1)
			assigned += int(sizes[age])
	var remainders := []
	for age in sizes:
		remainders.append({"age": age, "fraction": float(exact[age]) - floorf(float(exact[age]))})
	remainders.sort_custom(func(a, b): return float(a.fraction) > float(b.fraction))
	var leftover := population_size - assigned
	var index := 0
	while leftover > 0 and not remainders.is_empty():
		var age := int(remainders[index % remainders.size()].age)
		sizes[age] = int(sizes[age]) + 1
		leftover -= 1
		index += 1
	return sizes


## Which birth cohorts are golden, walked oldest to youngest so spacing can
## be enforced. Deterministic from the world seed.
##
## Returns the set of ages (at world generation) that carry a concentrated
## share of the scarce tiers. Walking by age is equivalent to walking by
## birth year here since the world starts at one moment in time; a future
## aging pass that adds new intakes should continue the same walk forward
## rather than re-rolling, so the cadence stays unbroken across a career.
static func golden_cohorts(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var golden := {}
	var since_last := GOLDEN_MIN_GAP
	for age in range(MAX_AGE, MIN_AGE - 1, -1):
		if since_last < GOLDEN_MIN_GAP:
			since_last += 1
			continue
		var chance := GOLDEN_BASE_CHANCE \
			+ GOLDEN_CHANCE_RAMP * float(since_last - GOLDEN_MIN_GAP)
		if rng.randf() < chance:
			golden[age] = true
			since_last = 0
		else:
			since_last += 1
	return golden


## Spreads each scarce tier's world total across cohorts, weighted by cohort
## size and golden status, using largest-remainder apportionment so the world
## total is hit exactly rather than approximately. A golden cohort takes a
## bigger slice of the same fixed budget -- concentration, never inflation.
static func _scarce_allotment(
	tier_total: int, ages: Array, sizes: Dictionary, golden: Dictionary,
) -> Dictionary:
	var weights := {}
	var weight_total := 0.0
	for age in ages:
		var weight := float(sizes[age]) \
			* (GOLDEN_MULTIPLIER if golden.has(age) else 1.0)
		weights[age] = weight
		weight_total += weight
	var counts := {}
	var remainders := []
	var assigned := 0
	for age in ages:
		var exact := float(tier_total) * float(weights[age]) / maxf(weight_total, 0.0001)
		var whole := floori(exact)
		counts[age] = whole
		assigned += whole
		remainders.append({"age": age, "fraction": exact - float(whole)})
	remainders.sort_custom(func(a, b): return float(a.fraction) > float(b.fraction))
	var leftover := tier_total - assigned
	for index in range(mini(leftover, remainders.size())):
		counts[int(remainders[index].age)] = int(counts[int(remainders[index].age)]) + 1
	return counts


## Where a player is born. Weighted only by how prolific each region is --
## never by how good the player is or how old they are.
static func birth_region(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for region_name in Regions.SIXNET_PARTICIPANTS:
		total += float(REGION_BIRTH_WEIGHTS.get(region_name, 1.0))
	var roll := rng.randf() * total
	var cumulative := 0.0
	for region_name in Regions.SIXNET_PARTICIPANTS:
		cumulative += float(REGION_BIRTH_WEIGHTS.get(region_name, 1.0))
		if roll <= cumulative:
			return str(region_name)
	return str(Regions.SIXNET_PARTICIPANTS[Regions.SIXNET_PARTICIPANTS.size() - 1])


## Decides where a player actually plays. Better players move more often,
## careers accumulate moves with age, and the destination is drawn against
## regional pull raised to an age-dependent exponent -- so prospects flow
## toward money and thirty-somethings flow away from it.
static func assign_club_region(player: VolleyballPlayer, rng: RandomNumberGenerator) -> void:
	var home := str(player.home_region)
	player.club_region = home
	var tier := tier_for_potential(int(player.potential))
	var band := band_for_age(int(player.age))
	var chance := float(MIGRATION_CHANCE_BY_TIER.get(tier, 0.1)) \
		* float(MIGRATION_CHANCE_BY_BAND.get(band, 1.0)) \
		* pow(float(REGION_PULL.get(home, 1.0)), ORIGIN_RETENTION_EXPONENT)
	if rng.randf() >= clampf(chance, 0.0, 0.95):
		return
	var exponent := float(PULL_EXPONENT_BY_BAND.get(band, 1.0))
	var total := 0.0
	var weights := {}
	for region_name in Regions.SIXNET_PARTICIPANTS:
		if str(region_name) == home:
			continue
		var weight := pow(float(REGION_PULL.get(region_name, 1.0)), exponent)
		weights[region_name] = weight
		total += weight
	var roll := rng.randf() * total
	var cumulative := 0.0
	for region_name in weights:
		cumulative += float(weights[region_name])
		if roll <= cumulative:
			player.club_region = str(region_name)
			return


static func weighted_position(rng: RandomNumberGenerator) -> Dictionary:
	var roll := rng.randf()
	var cumulative := 0.0
	for entry in POSITION_MIX:
		cumulative += float(entry.weight)
		if roll <= cumulative:
			return entry
	return POSITION_MIX[POSITION_MIX.size() - 1]


static func display_name_for(region_name: String, rng: RandomNumberGenerator) -> String:
	var names: Array = Regions.definition(region_name).names
	var first := str(names[rng.randi_range(0, names.size() - 1)])
	var second := str(names[rng.randi_range(0, names.size() - 1)])
	return "%s %s" % [first, second]


## Builds the whole world. `overlay_by_region` is the career's influence-drift
## state (`CareerState.region_overlay`), so a world generated later in a
## career reflects how regional development traditions have shifted.
static func generate(
	seed_value: int,
	population_size: int = DEFAULT_POPULATION_SIZE,
	overlay_by_region: Dictionary = {},
) -> Array[VolleyballPlayer]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ages: Array = []
	for age in range(MIN_AGE, MAX_AGE + 1):
		ages.append(age)
	var sizes := cohort_sizes(population_size)
	var golden := golden_cohorts(seed_value)

	## Scarce talent is apportioned across birth cohorts first, so a golden
	## generation is decided before anybody is built rather than emerging by
	## accident.
	var scarce_by_age := {}
	for tier in TALENT_TIERS:
		if int(tier.world_total) <= 0:
			continue
		scarce_by_age[str(tier.key)] = _scarce_allotment(
			tier_world_total(tier, population_size), ages, sizes, golden
		)

	## Every region is guaranteed a scoutable prospect in each of the two
	## youngest bands, so no save produces a region with nothing worth
	## finding. Talent is scarce, not absent.
	##
	## One per region, claimed across ages 15-22 rather than per band.
	## Golden cohorts deliberately hoard the scarce tiers, so the guarantee
	## has to ask for as little as possible: demanding one per region in each
	## young band wanted sixteen of the nineteen standouts a small world
	## contains, and simply could not be met. Eight, spread over eight
	## cohorts, leaves the golden mechanic intact.
	var guaranteed_pending: Array[String] = []
	for region_name in Regions.SIXNET_PARTICIPANTS:
		guaranteed_pending.append(str(region_name))

	var result: Array[VolleyballPlayer] = []
	var next_id := FIRST_POPULATION_ID
	for age in ages:
		var band_key := band_for_age(age)
		var cohort_total := int(sizes[age])
		var counts := {}
		var scarce_used := 0
		for tier in TALENT_TIERS:
			if int(tier.world_total) <= 0:
				continue
			var allotted := int(Dictionary(scarce_by_age[str(tier.key)]).get(age, 0))
			counts[str(tier.key)] = allotted
			scarce_used += allotted
		var remainder := maxi(cohort_total - scarce_used, 0)
		var assigned := 0
		var widest_tier := ""
		var widest_weight := -1.0
		for tier in TALENT_TIERS:
			if int(tier.world_total) > 0:
				continue
			var share := roundi(float(remainder) * float(tier.remainder_weight))
			counts[str(tier.key)] = share
			assigned += share
			if float(tier.remainder_weight) > widest_weight:
				widest_weight = float(tier.remainder_weight)
				widest_tier = str(tier.key)
		if not widest_tier.is_empty():
			counts[widest_tier] = maxi(int(counts[widest_tier]) + remainder - assigned, 0)

		for tier in TALENT_TIERS:
			var tier_key := str(tier.key)
			for _index in range(int(counts.get(tier_key, 0))):
				var region := ""
				var young_band := band_key == "youth" or band_key == "emerging"
				if young_band and tier_key == GUARANTEED_YOUNG_TIER \
						and not guaranteed_pending.is_empty():
					region = guaranteed_pending.pop_front()
				else:
					region = birth_region(rng)
				var position := weighted_position(rng)
				var player := PlayerGeneratorModel.generate_prospect(
					region,
					str(position.role),
					str(position.code),
					age,
					rng.randi_range(int(tier.pa_min), int(tier.pa_max)),
					next_id,
					display_name_for(region, rng),
					int(hash("%d|%s|%d" % [age, tier_key, next_id])),
					Dictionary(overlay_by_region.get(region, {})),
				)
				if player == null:
					continue
				## Where they were raised is settled; where they play is not.
				assign_club_region(player, rng)
				result.append(player)
				next_id += 1
	return result


## Counts by region, age band and talent tier -- the shape of the world in
## one dictionary. Used by the regression tests to assert the allotments
## actually held, and the natural data source for a future world-overview
## screen.
static func summarize(players: Array) -> Dictionary:
	var by_region := {}
	var by_band := {}
	var by_tier := {}
	var by_region_tier := {}
	var by_region_band := {}
	var by_club := {}
	var by_club_tier := {}
	var by_club_band := {}
	var by_cohort_scarce := {}
	for player_resource in players:
		var player: VolleyballPlayer = player_resource as VolleyballPlayer
		if player == null:
			continue
		var region := str(player.home_region)
		var club := str(player.club_region)
		var band := band_for_age(int(player.age))
		var tier := tier_for_potential(int(player.potential))
		by_region[region] = int(by_region.get(region, 0)) + 1
		by_club[club] = int(by_club.get(club, 0)) + 1
		by_band[band] = int(by_band.get(band, 0)) + 1
		by_tier[tier] = int(by_tier.get(tier, 0)) + 1
		var region_tier_key := "%s|%s" % [region, tier]
		by_region_tier[region_tier_key] = int(by_region_tier.get(region_tier_key, 0)) + 1
		var region_band_key := "%s|%s" % [region, band]
		by_region_band[region_band_key] = int(by_region_band.get(region_band_key, 0)) + 1
		var club_tier_key := "%s|%s" % [club, tier]
		by_club_tier[club_tier_key] = int(by_club_tier.get(club_tier_key, 0)) + 1
		var club_band_key := "%s|%s" % [club, band]
		by_club_band[club_band_key] = int(by_club_band.get(club_band_key, 0)) + 1
		if tier in SCOUTABLE_TIERS:
			by_cohort_scarce[int(player.age)] = int(by_cohort_scarce.get(int(player.age), 0)) + 1
	return {
		"total": players.size(), "by_region": by_region, "by_band": by_band,
		"by_tier": by_tier, "by_region_tier": by_region_tier,
		"by_region_band": by_region_band, "by_club": by_club,
		"by_club_tier": by_club_tier, "by_club_band": by_club_band,
		"by_cohort_scarce": by_cohort_scarce,
	}


## Young, high-ceiling, and a long way from that ceiling today -- the players
## a scouting system should eventually be hiding behind uncertainty.
static func wonderkids(players: Array, max_age: int = 21) -> Array[VolleyballPlayer]:
	var result: Array[VolleyballPlayer] = []
	for player_resource in players:
		var player: VolleyballPlayer = player_resource as VolleyballPlayer
		if player == null or int(player.age) > max_age:
			continue
		if tier_for_potential(int(player.potential)) in SCOUTABLE_TIERS \
				and int(player.potential) - int(player.current_ability_score()) >= 10:
			result.append(player)
	return result


static func by_club_region(players: Array, region_name: String) -> Array[VolleyballPlayer]:
	var result: Array[VolleyballPlayer] = []
	for player_resource in players:
		var player: VolleyballPlayer = player_resource as VolleyballPlayer
		if player != null and str(player.club_region) == region_name:
			result.append(player)
	return result


## Pulls a transfer market out of the world, removing the drawn players from
## `players` so the population stays the single owner of every person in the
## world -- nobody is ever duplicated between the market and the database.
##
## Weighted toward players young enough to still be worth developing, and
## away from the handful of genuinely generational talents, who should be
## found rather than listed on an open market.
static func draw_market(
	players: Array, count: int, seed_value: int,
) -> Array[VolleyballPlayer]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var weighted: Array = []
	for index in range(players.size()):
		var player: VolleyballPlayer = players[index] as VolleyballPlayer
		if player == null:
			continue
		var tier := tier_for_potential(int(player.potential))
		if tier == "generational":
			continue
		var band := band_for_age(int(player.age))
		var weight := 1.0
		match band:
			"youth": weight = 1.5
			"emerging": weight = 1.6
			"prime": weight = 1.0
			"veteran": weight = 0.5
			"twilight": weight = 0.2
		weighted.append({"index": index, "score": rng.randf() / maxf(weight, 0.0001)})
	weighted.sort_custom(func(a, b): return float(a.score) < float(b.score))
	var chosen_indices: Array[int] = []
	for entry in weighted.slice(0, mini(count, weighted.size())):
		chosen_indices.append(int(entry.index))
	chosen_indices.sort()
	chosen_indices.reverse()
	var drawn: Array[VolleyballPlayer] = []
	for index in chosen_indices:
		drawn.append(players[index] as VolleyballPlayer)
		players.remove_at(index)
	drawn.reverse()
	return drawn


static func to_dict_array(players: Array) -> Array:
	var result: Array = []
	for player_resource in players:
		var player: VolleyballPlayer = player_resource as VolleyballPlayer
		if player != null:
			result.append(player.to_dict())
	return result


static func from_dict_array(data: Array) -> Array[VolleyballPlayer]:
	var result: Array[VolleyballPlayer] = []
	for entry in data:
		result.append(VolleyballPlayer.from_dict(entry))
	return result
