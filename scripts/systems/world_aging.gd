class_name VolleyballWorldAging
extends RefCounted

## Turns the world over, once per season.
##
## `WorldPopulation` builds a world with a shape. This keeps that shape true
## while time passes: everyone gets a year older and redevelops accordingly,
## the players who were never going to make it fall out, and a new intake of
## fifteen-year-olds arrives to replace them.
##
## The central decision here is that **attrition is derived from the age
## pyramid rather than invented alongside it**. `WorldPopulation` already
## states how many players of each age the world should contain; the survival
## rate from one age to the next is simply the ratio between consecutive
## cohorts. That means the pyramid cannot drift over a long career, and there
## is no second set of retirement numbers to keep in agreement with the
## first. Who specifically survives is decided by ability plus noise, so
## better players last longer without the shape of the world depending on it.
##
## Talent stays scarce the same way. The intake never simply rolls new
## prospects; it looks at how far the living world is below its own talent
## budget and fills toward it, with golden birth years taking most of the
## deficit at once and ordinary years a trickle. The golden cadence carries
## forward from world generation rather than restarting, so a career
## experiences the same rhythm the world was born with.

const PlayerGeneratorModel := preload("res://scripts/systems/player_generator.gd")
const WorldPopulationModel := preload("res://scripts/systems/world_population.gd")
const Regions := preload("res://scripts/data/regions.gd")

## Spread on the ability score used to rank who survives a cohort. Without
## it the same players would always be the ones to drop out, and a career
## could read the future off a roster; with it, being good is a strong
## advantage rather than a guarantee.
const SURVIVAL_NOISE: float = 14.0

## Share of the current shortfall in a scarce tier that a single intake
## takes. A golden year clears what the world is missing in one go -- that
## is what makes it a golden generation -- while ordinary years only trickle.
##
## The golden share has to be the *whole* deficit rather than most of it.
## At 0.7 the tiers drained permanently: each golden year left a residue
## that the next one inherited, and over twenty years the standout tier fell
## from nineteen alive to thirteen. Replenishment has to match attrition on
## average or the world quietly empties.
##
## The ordinary share is rounded rather than floored for the same reason.
## Flooring a fifteen-per-cent share means a shortfall of six still admits
## nobody, so ordinary years contributed exactly zero at every realistic
## deficit and the entire budget rested on golden years alone.
const GOLDEN_DEFICIT_SHARE: float = 1.0
const ORDINARY_DEFICIT_SHARE: float = 0.15

## Ages at which a fifteen-year-old intake enters, and the last age anyone
## plays. Mirrors `WorldPopulation`'s range so the two cannot disagree.
const INTAKE_AGE: int = WorldPopulationModel.MIN_AGE
const FINAL_AGE: int = WorldPopulationModel.MAX_AGE


## Advances the whole world one season. Returns a report of what happened,
## which is the raw material for a future news feed ("Ĭspayk's captain
## retires", "a golden generation enters the academies").
static func advance_year(
	players: Array, career: Resource, world_year: int, seed_value: int,
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var population_size := maxi(int(career.world_population_size), players.size())

	var retired := _age_and_retire(players, population_size, rng)
	var intake := _generate_intake(players, career, world_year, population_size, rng)
	players.append_array(intake)

	return {
		"retired": retired.size(), "retired_players": retired,
		"intake": intake.size(), "intake_players": intake,
		"golden": bool(career.golden_birth_years.has(world_year - INTAKE_AGE)),
		"population": players.size(),
	}


## Everyone ages a year and is redeveloped at that age; whoever the pyramid
## has no room for leaves the game. Walked oldest-first so a cohort is sized
## against the target for the age it is arriving at.
static func _age_and_retire(
	players: Array, population_size: int, rng: RandomNumberGenerator,
) -> Array[VolleyballPlayer]:
	var sizes := WorldPopulationModel.cohort_sizes(population_size)
	var by_age := {}
	for player_resource in players:
		var player: VolleyballPlayer = player_resource as VolleyballPlayer
		if player == null:
			continue
		var age := int(player.age)
		if not by_age.has(age):
			by_age[age] = []
		by_age[age].append(player)

	var survivors: Array[VolleyballPlayer] = []
	var retired: Array[VolleyballPlayer] = []
	for age in range(FINAL_AGE, WorldPopulationModel.MIN_AGE - 1, -1):
		var cohort: Array = by_age.get(age, [])
		if cohort.is_empty():
			continue
		var next_age := age + 1
		## Nobody plays past the final age, so that cohort retires entire.
		var room := 0 if next_age > FINAL_AGE else int(sizes.get(next_age, 0))
		if room <= 0:
			retired.append_array(cohort)
			continue
		## Ability decides who stays, with enough noise that it is a strong
		## tendency rather than a ranking anyone could predict.
		##
		## The score is drawn once per player and then sorted on, rather than
		## rolled inside the comparator: a comparator that re-rolls does not
		## define a consistent ordering, and Godot's sort rejects it outright.
		var scored: Array = []
		for player_resource in cohort:
			var player: VolleyballPlayer = player_resource as VolleyballPlayer
			scored.append({
				"player": player,
				"score": float(player.current_ability_score())
					+ rng.randf_range(0.0, SURVIVAL_NOISE),
			})
		scored.sort_custom(func(a, b): return float(a.score) > float(b.score))
		for index in range(scored.size()):
			var player: VolleyballPlayer = scored[index].player
			if index < room:
				PlayerGeneratorModel.redevelop_to_age(player, next_age, int(player.id))
				survivors.append(player)
			else:
				retired.append(player)

	players.clear()
	players.append_array(survivors)
	return retired


## A new intake of fifteen-year-olds, sized to the cohort the pyramid wants
## and shaped by how far the world has fallen below its talent budget.
static func _generate_intake(
	players: Array, career: Resource, world_year: int,
	population_size: int, rng: RandomNumberGenerator,
) -> Array[VolleyballPlayer]:
	var birth_year := world_year - INTAKE_AGE
	var is_golden := _extend_golden_cadence(career, birth_year)
	var sizes := WorldPopulationModel.cohort_sizes(population_size)
	var intake_size := int(sizes.get(INTAKE_AGE, 0))
	if intake_size <= 0:
		return [] as Array[VolleyballPlayer]

	var alive_by_tier := {}
	for player_resource in players:
		var player: VolleyballPlayer = player_resource as VolleyballPlayer
		if player == null:
			continue
		var tier := WorldPopulationModel.tier_for_potential(int(player.potential))
		alive_by_tier[tier] = int(alive_by_tier.get(tier, 0)) + 1

	## Scarce places first: only ever enough to move back toward the budget,
	## never enough to exceed it.
	var counts := {}
	var scarce_used := 0
	for tier in WorldPopulationModel.TALENT_TIERS:
		var target := WorldPopulationModel.tier_world_total(tier, population_size)
		if target <= 0:
			continue
		var deficit := maxi(target - int(alive_by_tier.get(str(tier.key), 0)), 0)
		var share := GOLDEN_DEFICIT_SHARE if is_golden else ORDINARY_DEFICIT_SHARE
		if str(tier.key) == "generational" and not is_golden:
			share = 0.0
		var wanted := mini(roundi(float(deficit) * share), deficit)
		wanted = mini(wanted, maxi(intake_size - scarce_used, 0))
		counts[str(tier.key)] = wanted
		scarce_used += wanted

	var remainder := maxi(intake_size - scarce_used, 0)
	var assigned := 0
	var widest_tier := ""
	var widest_weight := -1.0
	for tier in WorldPopulationModel.TALENT_TIERS:
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

	var next_id := _next_free_id(players)
	var intake: Array[VolleyballPlayer] = []
	for tier in WorldPopulationModel.TALENT_TIERS:
		var tier_key := str(tier.key)
		for _index in range(int(counts.get(tier_key, 0))):
			var region := WorldPopulationModel.birth_region(rng, tier_key)
			var position := WorldPopulationModel.weighted_position(rng, region)
			var player := PlayerGeneratorModel.generate_prospect(
				region,
				str(position.role),
				str(position.code),
				INTAKE_AGE,
				rng.randi_range(int(tier.pa_min), int(tier.pa_max)),
				next_id,
				WorldPopulationModel.display_name_for(region, rng),
				int(hash("intake|%d|%s|%d" % [birth_year, tier_key, next_id])),
				Dictionary(career.region_overlay.get(region, {})),
			)
			if player == null:
				continue
			WorldPopulationModel.assign_club_region(player, rng)
			intake.append(player)
			next_id += 1
	return intake


## Continues the golden cadence forward from world generation rather than
## re-rolling it, so a career keeps the rhythm the world was born with. The
## spacing rule is the same one `WorldPopulation.golden_cohorts()` applies:
## never within the minimum gap of the last golden year, then rising odds
## until one lands.
static func _extend_golden_cadence(career: Resource, birth_year: int) -> bool:
	if career.golden_birth_years.has(birth_year):
		return true
	var last_golden := -9999
	for year in career.golden_birth_years:
		last_golden = maxi(last_golden, int(year))
	var gap := birth_year - last_golden
	if gap < WorldPopulationModel.GOLDEN_MIN_GAP:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash("golden|%s|%d" % [str(career.career_name), birth_year]))
	var chance := WorldPopulationModel.GOLDEN_BASE_CHANCE \
		+ WorldPopulationModel.GOLDEN_CHANCE_RAMP \
			* float(gap - WorldPopulationModel.GOLDEN_MIN_GAP)
	if rng.randf() >= chance:
		return false
	career.golden_birth_years.append(birth_year)
	return true


static func _next_free_id(players: Array) -> int:
	var highest := WorldPopulationModel.FIRST_POPULATION_ID
	for player_resource in players:
		var player: VolleyballPlayer = player_resource as VolleyballPlayer
		if player != null:
			highest = maxi(highest, int(player.id))
	return highest + 1
