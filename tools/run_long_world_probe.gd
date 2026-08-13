extends Node

## What the world looks like after a lifetime rather than after a season.
##
##     xvfb-run -a godot --path . res://tools/long_world_probe.tscn
##
## `_test_world_aging` runs twenty seasons and is, per CLAUDE.md, the one check
## that notices a generation change leaking talent. Twenty seasons is one
## career; the shapes that only appear after several -- a peak drifting up a
## point a decade, an age band slowly emptying, an intake that is quietly better
## than the cohort it replaces -- are invisible to it and are exactly the shapes
## that ruin a long save.
##
## This runs `SEASONS` seasons across `WORLDS` independently seeded worlds and
## prints the population every `SAMPLE_EVERY` seasons. It asserts nothing. It is
## a table to read, because nobody has seen this far out yet and inventing a
## threshold for a distribution nobody has looked at is the mistake this
## repository keeps a document about.
const WORLDS: int = 6
const SEASONS: int = 80
const SAMPLE_EVERY: int = 10
const POPULATION: int = 900

const WorldPopulation := preload("res://scripts/systems/world_population.gd")
const WorldAging := preload("res://scripts/systems/world_aging.gd")
const CareerState := preload("res://scripts/models/career_state.gd")


func _ready() -> void:
	await get_tree().process_frame
	_probe()
	get_tree().quit()


func _probe() -> void:
	print("=== long world probe: %d worlds x %d seasons, %d players each"
		% [WORLDS, SEASONS, POPULATION])
	print("")

	## Accumulated across worlds so a single unlucky seed does not read as a
	## trend, which is the whole reason this runs more than one.
	var pooled := {}

	for world_index in range(WORLDS):
		var world_seed := 4242 + world_index * 977
		var career: Resource = CareerState.new()
		career.career_name = "Long World %d" % world_index
		var population: Array[VolleyballPlayer] = WorldPopulation.generate(
			world_seed, POPULATION
		)
		career.world_population_size = population.size()
		for golden_age in WorldPopulation.golden_cohorts(world_seed):
			career.golden_birth_years.append(1 - int(golden_age))

		for season in range(1, SEASONS + 1):
			WorldAging.advance_year(population, career, season + 1, world_seed + season)
			if season % SAMPLE_EVERY != 0:
				continue
			var row := _measure(population)
			row["season"] = season
			row["world"] = world_index
			if not pooled.has(season):
				pooled[season] = []
			pooled[season].append(row)

	print("%-8s %8s %8s %8s %8s %8s %8s" % [
		"season", "size", "meanAge", "meanPeak", "p90Peak", "maxPeak", "elite",
	])
	var seasons: Array = pooled.keys()
	seasons.sort()
	for season in seasons:
		var rows: Array = pooled[season]
		print("%-8d %8.0f %8.2f %8.2f %8.2f %8.2f %8.2f" % [
			int(season),
			_mean(rows, "size"), _mean(rows, "mean_age"),
			_mean(rows, "mean_peak"), _mean(rows, "p90_peak"),
			_mean(rows, "max_peak"), _mean(rows, "elite"),
		])
	print("")
	print("size: world population. meanPeak/p90Peak/maxPeak: peak potential across")
	print("the living population. elite: how many are at or above 80 peak.")
	print("Each figure is the mean over %d independently seeded worlds." % WORLDS)


func _measure(population: Array) -> Dictionary:
	var peaks: Array[float] = []
	var ages := 0.0
	var elite := 0
	for raw in population:
		var player: VolleyballPlayer = raw
		if player == null:
			continue
		ages += float(player.age)
		## `potential`, not `peak_potential` -- there is no such field, and the
		## `in player` fallback that would have papered over that is the exact
		## shape of defensive access this repository treats as a defect.
		var peak := float(player.potential)
		peaks.append(peak)
		elite += int(peak >= 80.0)
	peaks.sort()
	var count := maxi(peaks.size(), 1)
	var total := 0.0
	for value in peaks:
		total += value
	return {
		"size": float(population.size()),
		"mean_age": ages / float(count),
		"mean_peak": total / float(count),
		"p90_peak": peaks[mini(int(count * 0.90), count - 1)] if peaks.size() > 0 else 0.0,
		"max_peak": peaks[count - 1] if peaks.size() > 0 else 0.0,
		"elite": float(elite),
	}


func _mean(rows: Array, key: String) -> float:
	if rows.is_empty():
		return 0.0
	var total := 0.0
	for row in rows:
		total += float(row[key])
	return total / float(rows.size())
