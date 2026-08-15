extends SceneTree

## What does a letter grade have to mean, on a person and on a six?
##
##     godot --headless --path . --script res://tools/run_grade_band_probe.gd
##
## A grade is a threshold and a threshold outside its own distribution does
## nothing, silently. `AttributeProfiles.grade` is **one absolute scale**, used
## for a single voli on the roster page and for a six-mean on the lock-in board,
## across all six categories. Three claims are folded into that and none of them
## has been measured:
##
## 1. that a team mean and a person's score live on the same scale
## 2. that all six categories live on the same scale as each other
## 3. that the bands cut those distributions somewhere useful
##
## The whiteboard draft measured 1 and 2 against a generated world and 800
## **random** sixes, and flagged its own debt: a managed lineup is a *chosen*
## six and sits higher, so bands read off random sixes grade real teams
## generously. This measures the chosen six as well, which is the reading the
## board will actually print.
const Generator := preload("res://scripts/systems/player_generator.gd")
const Profiles := preload("res://scripts/systems/attribute_profile_system.gd")

const CATEGORIES: Array[String] = [
	"Attacking", "Defensive", "Setting / Control",
	"Physical", "Serving", "Mental / Tactical",
]
## Six on court. The chosen six is the top of a roster by Overall, which is what
## a manager picks when they are not being clever -- and the honest floor for
## "better than random".
const ON_COURT: int = 6


func _initialize() -> void:
	var solo := {}
	var random_six := {}
	var chosen_six := {}
	for category in CATEGORIES:
		solo[category] = [] as Array[float]
		random_six[category] = [] as Array[float]
		chosen_six[category] = [] as Array[float]

	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var regions: Array = VolleyballRegions.CORE_REGIONS
	var rosters: Array = []
	for index in range(240):
		var region := str(regions[index % regions.size()])
		var roster: Array = Generator.generate_roster(
			region, "established", 800000 + index
		)
		var profiled: Array = []
		for player in roster:
			var profile: Dictionary = Profiles.summary_profile(player)
			profiled.append(profile)
			for category in CATEGORIES:
				solo[category].append(float(profile[category]))
		rosters.append(profiled)

	for profiled in rosters:
		if profiled.size() < ON_COURT:
			continue
		## A random six, which is what the draft measured.
		var shuffled: Array = profiled.duplicate()
		for index in range(shuffled.size() - 1, 0, -1):
			var swap := rng.randi_range(0, index)
			var held = shuffled[index]
			shuffled[index] = shuffled[swap]
			shuffled[swap] = held
		_accumulate(random_six, shuffled.slice(0, ON_COURT))
		## And a chosen six -- the roster's best by Overall, which is what a
		## manager puts on court and therefore what the board prints.
		var ranked: Array = profiled.duplicate()
		ranked.sort_custom(func(a, b): return float(a["Overall"]) > float(b["Overall"]))
		_accumulate(chosen_six, ranked.slice(0, ON_COURT))

	print("%d volis, %d rosters\n" % [solo["Attacking"].size(), rosters.size()])
	_table("ONE VOLI", solo)
	print("")
	_table("RANDOM SIX", random_six)
	print("")
	_table("CHOSEN SIX", chosen_six)

	## **What the single scale actually returns**, which is the question that
	## matters: a band nobody lands in is a band that does not exist.
	print("\nGrades the current single scale hands out:")
	_grades("one voli", solo)
	_grades("chosen six", chosen_six)

	## **The bands, emitted ready to paste.**
	##
	## Cut at p10 / p30 / p75 / p95, which lands 10% D, 20% C, 45% B, 20% A and
	## 5% S. S stays a genuine outlier and D stays reachable -- against the
	## single scale's 0.0% S and 0.1% D on a chosen six, where two letters
	## carried 99.8% of everything the board could print.
	print("")
	_bands("VOLI_BANDS", solo)
	print("")
	_bands("TEAM_BANDS", chosen_six)

	## And the spread collapse, stated as a ratio, because it is the reason a
	## team cannot be graded on person bands.
	print("\nSpread (p90 - p10), and how much of it survives averaging six:")
	print("%-20s %8s %8s %8s" % ["category", "voli", "chosen", "ratio"])
	for category in CATEGORIES:
		var one := _percentile(solo[category], 0.90) - _percentile(solo[category], 0.10)
		var six := _percentile(chosen_six[category], 0.90) \
			- _percentile(chosen_six[category], 0.10)
		print("%-20s %8.1f %8.1f %8.2f" % [category, one, six, six / maxf(one, 0.001)])
	quit()


## The band table for one scale, in the form the constant is written in.
func _bands(name: String, table: Dictionary) -> void:
	print("const %s := {" % name)
	for category in CATEGORIES:
		var values: Array = table[category]
		print("\t\"%s\": [%.1f, %.1f, %.1f, %.1f]," % [
			category,
			_percentile(values, 0.10), _percentile(values, 0.30),
			_percentile(values, 0.75), _percentile(values, 0.95),
		])
	print("}")


func _accumulate(into: Dictionary, six: Array) -> void:
	for category in CATEGORIES:
		var total := 0.0
		for profile in six:
			total += float(profile[category])
		into[category].append(total / float(six.size()))


func _table(label: String, table: Dictionary) -> void:
	print("%-20s %8s %8s %8s %8s %8s" % [label, "p10", "p25", "p50", "p75", "p90"])
	for category in CATEGORIES:
		var values: Array = table[category]
		print("%-20s %8.1f %8.1f %8.1f %8.1f %8.1f" % [
			category,
			_percentile(values, 0.10), _percentile(values, 0.25),
			_percentile(values, 0.50), _percentile(values, 0.75),
			_percentile(values, 0.90),
		])


## Which letters the shipped scale hands out, and how often. A scale that
## returns one letter for 90% of what it sees is not grading anything.
func _grades(label: String, table: Dictionary) -> void:
	var counts := {}
	var total := 0
	for category in CATEGORIES:
		for value in Array(table[category]):
			var tier: String = Profiles.grade_tier(float(value))
			counts[tier] = int(counts.get(tier, 0)) + 1
			total += 1
	var line := ""
	for tier in ["S", "A", "B", "C", "D"]:
		line += "%s %.1f%%   " % [
			tier, float(counts.get(tier, 0)) / maxf(float(total), 1.0) * 100.0
		]
	print("  %-12s %s" % [label, line])


func _percentile(values: Array, share: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[clampi(
		int(float(sorted.size()) * share), 0, sorted.size() - 1
	)])
