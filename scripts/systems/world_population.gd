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
## So talent here is an allocated budget, not a per-player dice roll. Each
## age band gets a fixed, small headcount of generational and elite players
## *for the entire world*; everyone else fills in below them. Region, age and
## potential are apportioned deliberately, which is also what lets the world
## carry history: A'ace's stars are disproportionately old and imported
## because it buys them rather than raising them, and Ispayk is thick with
## veterans because a fallen program keeps its old guard.
##
## Current ability is never allocated directly -- it falls out of age through
## the same development curve every generated player uses. One potential
## number plus an age produces either a raw prospect or a finished star.

const PlayerGeneratorModel := preload("res://scripts/systems/player_generator.gd")
const Regions := preload("res://scripts/data/regions.gd")

const DEFAULT_POPULATION_SIZE: int = 1200
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
## `per_band` is an absolute headcount **for the entire world**, listed per
## age band -- not a probability. That is the whole mechanism: eight
## generational players exist across every age alive at once, regardless of
## how large the population is, so finding one is an event rather than a
## dice roll that a big enough world is guaranteed to pass.
##
## The counts taper with age rather than staying flat, for two reasons. A
## flat count would make the smallest band the most talent-dense (two
## generational players among seventy 33-38-year-olds reads as absurd), and
## a mild taper is also true to the sport: the players still going at
## thirty-five are disproportionately the ones who were good, because the
## rest wash out. An empty entry means the tier is absent from that band.
##
## Tiers with no `per_band` entry at all take a share of whatever headcount
## is left over, split by `remainder_weight`.
const TALENT_TIERS: Array[Dictionary] = [
	{"key": "generational", "pa_min": 92, "pa_max": 99, "remainder_weight": 0.0,
		"per_band": {"youth": 2, "emerging": 2, "prime": 2, "veteran": 1, "twilight": 1}},
	{"key": "elite", "pa_min": 84, "pa_max": 91, "remainder_weight": 0.0,
		"per_band": {"youth": 6, "emerging": 6, "prime": 6, "veteran": 4, "twilight": 2}},
	{"key": "standout", "pa_min": 76, "pa_max": 83, "remainder_weight": 0.0,
		"per_band": {"youth": 16, "emerging": 16, "prime": 16, "veteran": 10, "twilight": 4}},
	{"key": "solid", "pa_min": 66, "pa_max": 75, "remainder_weight": 0.30, "per_band": {}},
	{"key": "squad", "pa_min": 54, "pa_max": 65, "remainder_weight": 0.44, "per_band": {}},
	{"key": "fringe", "pa_min": 38, "pa_max": 53, "remainder_weight": 0.26, "per_band": {}},
]

## Tiers that count as "a prospect worth scouting" when young. Every region
## is guaranteed at least one of these in each of the two youngest bands, so
## no save ever produces a region with nothing to discover.
const SCOUTABLE_TIERS: Array[String] = ["generational", "elite", "standout"]
const GUARANTEED_YOUNG_TIER: String = "standout"

## Multiplicative region weights on top of an even split. 1.0 is the
## baseline; regions absent from a table sit at 1.0 everywhere.
##
## A'ace barely produces its own teenagers and is heavy with imported prime
## and veteran talent -- that gap between "no youth pipeline" and "a squad
## full of established stars" is the story of a program that bought its way
## up. Ispayk skews old across every tier: a proud, cash-strapped academy
## keeps the players it already has.
const REGION_AGE_WEIGHTS := {
	"A'ace": {"youth": 0.30, "emerging": 0.65, "prime": 1.35, "veteran": 1.70, "twilight": 1.55},
	"Ispayk": {"youth": 0.95, "emerging": 1.00, "prime": 1.00, "veteran": 1.75, "twilight": 2.10},
}

## The same idea against talent rather than age. Multiplied with the age
## weight above, so A'ace's pull on generational talent is strongest exactly
## where its age weighting is strongest -- older generational players read as
## scouted and imported, which is the intended impression.
const REGION_TIER_WEIGHTS := {
	"A'ace": {
		"generational": 2.60, "elite": 2.10, "standout": 1.55,
		"solid": 1.00, "squad": 0.70, "fringe": 0.45,
	},
	"Ispayk": {
		"generational": 0.75, "elite": 0.85, "standout": 1.00,
		"solid": 1.15, "squad": 1.20, "fringe": 1.15,
	},
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


## Headcount per tier for one age band. Allotted tiers take their fixed
## count off the top; whatever is left is split across the remainder tiers by
## weight, with any rounding drift absorbed by the largest of them so the
## counts always sum exactly to `band_total`.
static func tier_counts_for_band(band_key: String, band_total: int) -> Dictionary:
	var counts := {}
	var fixed_total := 0
	for tier in TALENT_TIERS:
		var per_band: Dictionary = tier.per_band
		if per_band.is_empty():
			continue
		var allotment := mini(int(per_band.get(band_key, 0)), maxi(band_total - fixed_total, 0))
		counts[str(tier.key)] = allotment
		fixed_total += allotment
	var remainder := maxi(band_total - fixed_total, 0)
	var assigned := 0
	var widest_tier := ""
	var widest_weight := -1.0
	for tier in TALENT_TIERS:
		if not Dictionary(tier.per_band).is_empty():
			continue
		var share := roundi(float(remainder) * float(tier.remainder_weight))
		counts[str(tier.key)] = share
		assigned += share
		if float(tier.remainder_weight) > widest_weight:
			widest_weight = float(tier.remainder_weight)
			widest_tier = str(tier.key)
	if not widest_tier.is_empty():
		counts[widest_tier] = maxi(int(counts[widest_tier]) + remainder - assigned, 0)
	return counts


static func _region_weight(region_name: String, band_key: String, tier_key: String) -> float:
	var age_weight := float(
		Dictionary(REGION_AGE_WEIGHTS.get(region_name, {})).get(band_key, 1.0)
	)
	var tier_weight := float(
		Dictionary(REGION_TIER_WEIGHTS.get(region_name, {})).get(tier_key, 1.0)
	)
	return maxf(age_weight * tier_weight, 0.0001)


static func _weighted_region(
	band_key: String, tier_key: String, rng: RandomNumberGenerator,
) -> String:
	var total := 0.0
	for region_name in Regions.SIXNET_PARTICIPANTS:
		total += _region_weight(region_name, band_key, tier_key)
	var roll := rng.randf() * total
	var cumulative := 0.0
	for region_name in Regions.SIXNET_PARTICIPANTS:
		cumulative += _region_weight(region_name, band_key, tier_key)
		if roll <= cumulative:
			return str(region_name)
	return str(Regions.SIXNET_PARTICIPANTS[Regions.SIXNET_PARTICIPANTS.size() - 1])


static func _weighted_position(rng: RandomNumberGenerator) -> Dictionary:
	var roll := rng.randf()
	var cumulative := 0.0
	for entry in POSITION_MIX:
		cumulative += float(entry.weight)
		if roll <= cumulative:
			return entry
	return POSITION_MIX[POSITION_MIX.size() - 1]


static func _display_name(region_name: String, rng: RandomNumberGenerator) -> String:
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
	var result: Array[VolleyballPlayer] = []
	var next_id := FIRST_POPULATION_ID
	for band in AGE_BANDS:
		var band_key := str(band.key)
		var band_total := roundi(float(population_size) * float(band.share))
		var counts := tier_counts_for_band(band_key, band_total)
		var young_band := band_key == "youth" or band_key == "emerging"
		for tier in TALENT_TIERS:
			var tier_key := str(tier.key)
			var slots := int(counts.get(tier_key, 0))
			if slots <= 0:
				continue
			## Every region is guaranteed one scoutable prospect per young
			## band before weighting decides the rest, so no save can produce
			## a region with nothing worth discovering in it.
			var guaranteed: Array[String] = []
			if young_band and tier_key == GUARANTEED_YOUNG_TIER:
				for region_name in Regions.SIXNET_PARTICIPANTS:
					if guaranteed.size() < slots:
						guaranteed.append(str(region_name))
			for index in range(slots):
				var region := guaranteed[index] if index < guaranteed.size() \
					else _weighted_region(band_key, tier_key, rng)
				var position := _weighted_position(rng)
				var player := PlayerGeneratorModel.generate_prospect(
					region,
					str(position.role),
					str(position.code),
					rng.randi_range(int(band.min_age), int(band.max_age)),
					rng.randi_range(int(tier.pa_min), int(tier.pa_max)),
					next_id,
					_display_name(region, rng),
					int(hash("%s|%s|%d" % [band_key, tier_key, next_id])),
					Dictionary(overlay_by_region.get(region, {})),
				)
				if player != null:
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
	for player_resource in players:
		var player: VolleyballPlayer = player_resource as VolleyballPlayer
		if player == null:
			continue
		var region := str(player.home_region)
		var band := band_for_age(int(player.age))
		var tier := tier_for_potential(int(player.potential))
		by_region[region] = int(by_region.get(region, 0)) + 1
		by_band[band] = int(by_band.get(band, 0)) + 1
		by_tier[tier] = int(by_tier.get(tier, 0)) + 1
		var region_tier_key := "%s|%s" % [region, tier]
		by_region_tier[region_tier_key] = int(by_region_tier.get(region_tier_key, 0)) + 1
		var region_band_key := "%s|%s" % [region, band]
		by_region_band[region_band_key] = int(by_region_band.get(region_band_key, 0)) + 1
	return {
		"total": players.size(), "by_region": by_region, "by_band": by_band,
		"by_tier": by_tier, "by_region_tier": by_region_tier,
		"by_region_band": by_region_band,
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


static func by_region(players: Array, region_name: String) -> Array[VolleyballPlayer]:
	var result: Array[VolleyballPlayer] = []
	for player_resource in players:
		var player: VolleyballPlayer = player_resource as VolleyballPlayer
		if player != null and str(player.home_region) == region_name:
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
