extends SceneTree

## Why the opponent backs off 71% of its swings and the home side 2%.
##
## `attack_family_deficit` sums five shortfalls -- ratings, lateral control,
## run-up quality, arrival margin, and power access -- and publishes only the
## total, which `AttemptJudgment.backs_off()` then turns into a roll shot. The
## total cannot be acted on: the five terms live in different files and want
## entirely different fixes.
##
## This drives the same production approach profile both swings use, then reads
## the itemised terms rather than recomputing them.
##
## Run:
##   godot --headless --path . --script res://tools/run_backoff_terms_probe.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const ApproachMechanics := preload(
	"res://scripts/simulation/approach_mechanics_system.gd"
)

const RALLIES: int = 150
const TERMS: Array[String] = [
	"rating", "lateral_control", "runup_quality", "arrival_margin",
	"power_access",
]


func _initialize() -> void:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	ExecutionScale.apply_generated_attributes(manager.players, 900006)
	ExecutionScale.apply_generated_attributes(
		manager.opponent_team.players, 900006
	)
	var rows := {"home": [], "opponent": []}
	for serving_home in [true, false]:
		manager.match_state.serving_home = serving_home
		for seed_value in range(5000, 5000 + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			for raw in result.events:
				var event := raw as RallyEvent
				if event == null \
						or event.event_type != RallyEventScript.EventType.ATTACK:
					continue
				var side := str(event.metadata.get("side", ""))
				if not rows.has(side):
					continue
				var terms := Dictionary(
					event.metadata.get("swing_deficit_terms", {})
				)
				if terms.is_empty():
					continue
				rows[side].append({
					"terms": terms,
					"backed_off": bool(event.metadata.get("swing_downgraded", false)),
					"runup": float(event.metadata.get("swing_runup_quality", 0.0)),
					"margin": float(event.metadata.get("arrival_margin", 0.0)),
					"in_system": bool(event.metadata.get("swing_in_system", false)),
				})
	manager.free()

	print("Back-off terms -- %d rallies x 2 serving sides" % RALLIES)
	print("")
	print("Mean deficit contributed by each term, over swings that were asked")
	print("for a power family. A term reading 0.000 never fired at all.")
	print("")
	var header := "%-10s %6s" % ["side", "n"]
	for term in TERMS:
		header += " %15s" % term
	header += " %8s" % "total"
	print(header)
	for side in ["home", "opponent"]:
		var pool: Array = rows[side]
		if pool.is_empty():
			print("%-10s (none)" % side)
			continue
		var line := "%-10s %6d" % [side, pool.size()]
		var total := 0.0
		for term in TERMS:
			var sum := 0.0
			for row in pool:
				sum += float(Dictionary(row.terms).get(term, 0.0))
			var mean := sum / float(pool.size())
			total += mean
			line += " %15.4f" % mean
		line += " %8.4f" % total
		print(line)
	print("")
	print("Share of swings on which each term was non-zero")
	for side in ["home", "opponent"]:
		var pool: Array = rows[side]
		if pool.is_empty():
			continue
		var line := "  %-9s" % side
		for term in TERMS:
			var hits := 0
			for row in pool:
				if float(Dictionary(row.terms).get(term, 0.0)) > 0.0:
					hits += 1
			line += " %s=%.0f%%" % [
				term, float(hits) / float(pool.size()) * 100.0]
		print(line)
	print("")
	print("Inputs the terms are measured against")
	print("%-10s %6s %14s %14s %14s" % [
		"side", "n", "runup_quality", "arrival_margin", "in_system"])
	for side in ["home", "opponent"]:
		var pool: Array = rows[side]
		if pool.is_empty():
			continue
		var runup := 0.0
		var margin := 0.0
		var in_system := 0
		for row in pool:
			runup += float(row.runup)
			margin += float(row.margin)
			if bool(row.in_system):
				in_system += 1
		var n := float(pool.size())
		print("%-10s %6d %14.3f %14.3f %13.0f%%" % [
			side, pool.size(), runup / n, margin / n,
			float(in_system) / n * 100.0])
	print("")
	print("power access floors: in-system %.2f, out-of-system %.2f" % [
		ApproachMechanics.POWER_ACCESS_QUALITY_IN_SYSTEM,
		ApproachMechanics.POWER_ACCESS_QUALITY_OUT_OF_SYSTEM,
	])
	quit()
