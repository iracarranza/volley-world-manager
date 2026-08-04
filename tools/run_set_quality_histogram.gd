extends SceneTree

## Which set path is producing the bad balls?
##
## `outcome_calibration` reports one pooled `set_quality` summary, and it came
## back bimodal: min 0.08, p25 0.105, median 0.467, p75 0.731. A pooled
## statistic cannot say whose sets those are, and 0.08 is exactly the floor of
## the opponent transition set's own clamp -- so the shape of the pool is the
## question, not the answer. This splits it.
##
## Four set paths exist: a first ball and a transition on each side of the net.
## Splitting them this way is what makes the comparison that matters possible --
## home transition against opponent transition, the two that are the same phase.
## Rosters are identical on both sides for the same reason the symmetry gate
## uses them, so anything that differs between those two columns is the
## implementation and not the draw.
##
## Run:
##   godot --headless --path . --script res://tools/run_set_quality_histogram.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const PAIRINGS: int = 4
const RALLIES: int = 90
const BUCKETS: int = 10

## The terms `_set_terms` decomposes a set into. Reported as means per path so a
## gap between the two transition columns names its own cause instead of being
## argued about -- the same reason the defence gate got `_defense_terms`.
const TERMS: Array[String] = [
	"capability", "usable", "pass", "tempo_demand", "capability_penalty",
	"geometry_difficulty", "arrival", "familiarity",
]

## The engine now labels each set event with the path that produced it. The
## first cut of this instrument inferred the path from the presence of
## `setter_capability` metadata, which was wrong in two ways: it pooled the
## opponent's first ball and its transition into one column -- so the one
## phase-matched comparison this tool exists for was never actually being made
## -- and it broke the moment the transition set started emitting capability
## like every other path. A path is a fact about the code, so the code says it.
const PATHS: Array[String] = [
	"home_first_ball", "home_transition",
	"opponent_first_ball", "opponent_transition",
]


func _initialize() -> void:
	var samples := {}
	var terms := {}
	var attacks := {}
	for path in PATHS:
		samples[path] = PackedFloat32Array()
		terms[path] = {}
		attacks[path] = {"attempts": 0, "kills": 0, "errors": 0, "stuffed": 0}
	_sweep(samples, terms, attacks)

	print("Set quality by path -- identical rosters, %d pairings x %d rallies x 2 serves" % [
		PAIRINGS, RALLIES,
	])
	print("")
	_print_distributions(samples)
	print("")
	_print_histogram(samples)
	print("")
	_print_terms(terms)
	print("")
	_print_attacks(attacks)
	quit()


func _sweep(samples: Dictionary, terms: Dictionary, attacks: Dictionary) -> void:
	for pairing_index in range(PAIRINGS):
		var roster_seed := 900006 + pairing_index * 1000
		for serving_home in [true, false]:
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			ExecutionScale.apply_generated_attributes(manager.players, roster_seed)
			ExecutionScale.apply_generated_attributes(
				manager.opponent_team.players, roster_seed
			)
			manager.match_state.serving_home = serving_home
			for seed_value in range(5000, 5000 + RALLIES):
				var result: Resource = manager.resolve_active_rally(seed_value)
				if result == null:
					continue
				_collect(result, samples, terms, attacks)
			manager.free()


## Walk one rally, attributing each set to its path and each attack to the set
## that fed it. Attacks are attributed by the most recent set on the same side,
## which is what "the ball this swing was hit off" means in an event stream.
func _collect(
	result: Resource, samples: Dictionary, terms: Dictionary, attacks: Dictionary
) -> void:
	var last_set_path := {"home": "", "opponent": ""}
	for raw_event in result.events:
		var event: Resource = raw_event
		var side := str(event.metadata.get("side", ""))
		if side != "home" and side != "opponent":
			continue
		if event.event_type == RallyEventScript.EventType.SET:
			var path := _path_for(event, side)
			if not samples.has(path):
				continue
			last_set_path[side] = path
			var array: PackedFloat32Array = samples[path]
			array.append(float(event.quality))
			samples[path] = array
			var event_terms: Dictionary = event.metadata.get("set_terms", {})
			if not event_terms.is_empty():
				var accumulated: Dictionary = terms[path]
				for term in TERMS:
					accumulated[term] = float(accumulated.get(term, 0.0)) \
						+ float(event_terms.get(term, 0.0))
				accumulated["count"] = float(accumulated.get("count", 0.0)) + 1.0
				terms[path] = accumulated
			continue
		if event.event_type != RallyEventScript.EventType.ATTACK:
			continue
		var attack_path := str(last_set_path[side])
		if attack_path == "":
			continue
		var tally: Dictionary = attacks[attack_path]
		tally.attempts += 1
		attacks[attack_path] = tally
	## Outcomes come from the rally's terminal verdict rather than the ATTACK
	## event's `success` flag: the flag records whether the swing was struck,
	## not whether it won the point, and the two differ on exactly the balls
	## this instrument is about.
	var terminal := str(result.terminal_outcome)
	var terminal_side := "opponent" if terminal.begins_with("opponent") \
		or terminal == "counter_block" else "home"
	var terminal_path := str(last_set_path[terminal_side])
	if terminal_path == "":
		return
	var terminal_tally: Dictionary = attacks[terminal_path]
	match terminal:
		"kill", "opponent_kill":
			terminal_tally.kills += 1
		"attack_error", "opponent_attack_error":
			terminal_tally.errors += 1
		"blocked", "counter_block":
			terminal_tally.stuffed += 1
	attacks[terminal_path] = terminal_tally


func _path_for(event: Resource, side: String) -> String:
	return str(event.metadata.get("set_path", ""))


func _print_distributions(samples: Dictionary) -> void:
	print("%-21s %5s %6s %6s %6s %6s %6s %6s" % [
		"path", "n", "min", "p25", "med", "p75", "max", "mean",
	])
	for path in PATHS:
		var values: PackedFloat32Array = samples[path]
		if values.is_empty():
			print("%-21s %5d  (no samples)" % [path, 0])
			continue
		var sorted := Array(values)
		sorted.sort()
		var total := 0.0
		for value in sorted:
			total += float(value)
		print("%-21s %5d %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f" % [
			path, sorted.size(), float(sorted[0]),
			_quantile(sorted, 0.25), _quantile(sorted, 0.50),
			_quantile(sorted, 0.75), float(sorted[-1]),
			total / float(sorted.size()),
		])


func _print_histogram(samples: Dictionary) -> void:
	print("Share of sets per decile (the pooled figure's bimodality, split)")
	var header := "%-21s" % "path"
	for bucket in range(BUCKETS):
		header += " %5s" % ("%.1f" % (float(bucket) / float(BUCKETS)))
	print(header)
	for path in PATHS:
		var values: PackedFloat32Array = samples[path]
		if values.is_empty():
			continue
		var counts := PackedInt32Array()
		counts.resize(BUCKETS)
		for value in values:
			counts[clampi(int(float(value) * float(BUCKETS)), 0, BUCKETS - 1)] += 1
		var row := "%-21s" % path
		for bucket in range(BUCKETS):
			row += " %5.2f" % (float(counts[bucket]) / float(values.size()))
		print(row)


func _print_terms(terms: Dictionary) -> void:
	print("Mean of each term (blank where the path does not emit a decomposition)")
	var header := "%-21s" % "path"
	for term in TERMS:
		header += " %9s" % term.substr(0, 9)
	print(header)
	for path in PATHS:
		var accumulated: Dictionary = terms[path]
		var count := float(accumulated.get("count", 0.0))
		if count <= 0.0:
			print("%-21s  (no set_terms on this path)" % path)
			continue
		var row := "%-21s" % path
		for term in TERMS:
			row += " %9.3f" % (float(accumulated.get(term, 0.0)) / count)
		print(row)


func _print_attacks(attacks: Dictionary) -> void:
	print("What each path's sets produce when they are swung at")
	print("%-21s %8s %8s %8s %8s" % [
		"path", "attempts", "kill", "error", "stuffed",
	])
	for path in PATHS:
		var tally: Dictionary = attacks[path]
		var attempts := float(tally.attempts)
		if attempts <= 0.0:
			print("%-21s %8d" % [path, 0])
			continue
		print("%-21s %8d %8.3f %8.3f %8.3f" % [
			path, tally.attempts, float(tally.kills) / attempts,
			float(tally.errors) / attempts, float(tally.stuffed) / attempts,
		])


func _quantile(sorted: Array, fraction: float) -> float:
	if sorted.is_empty():
		return 0.0
	var index := clampi(
		int(round(fraction * float(sorted.size() - 1))), 0, sorted.size() - 1
	)
	return float(sorted[index])
