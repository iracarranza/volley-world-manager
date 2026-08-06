extends SceneTree

## Where the two sides' dig quality actually diverges.
##
## Home diggers succeed 62% and opponent diggers 25%, and neither the claimant
## search nor `_dig_contest` differs between them -- both sides run the same
## code, and the home path is stricter for also demanding `defender_arrived`. So
## the gap is entirely in the five inputs `_defense_terms` is handed, and this
## reports each of them per side rather than guessing which one carries it.
##
## `quality = capability * opportunity * DIG_SOLO_SHARE`, and
## `opportunity = timing x posture x support x recovery`, so a divergence in any
## single factor shows up here against the others holding steady.
##
## Run:
##   godot --headless --path . --script res://tools/run_dig_terms_probe.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const RALLIES: int = 150
const TERMS: Array[String] = [
	"quality", "capability", "timing", "posture", "support", "opportunity",
	"read_bonus", "reach_margin_meters", "recovery", "contested_against",
]


func _initialize() -> void:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	ExecutionScale.apply_generated_attributes(manager.players, 900006)
	ExecutionScale.apply_generated_attributes(
		manager.opponent_team.players, 900006
	)
	var samples := {"home": {}, "opponent": {}}
	for side in samples:
		for term in TERMS:
			samples[side][term] = []
	for serving_home in [true, false]:
		manager.match_state.serving_home = serving_home
		for seed_value in range(5000, 5000 + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			for raw in result.events:
				var event := raw as RallyEvent
				if event == null \
						or event.event_type != RallyEventScript.EventType.DEFENSE:
					continue
				var side := str(event.metadata.get("side", ""))
				if not samples.has(side):
					continue
				var terms: Dictionary = event.metadata.get("dig_terms", {})
				if terms.is_empty():
					continue
				for term in TERMS:
					if terms.has(term):
						samples[side][term].append(float(terms[term]))
	manager.free()

	print("Dig terms -- %d rallies x 2 serving sides, identically seeded squads"
		% RALLIES)
	print("")
	print("%-22s %9s %9s %9s   %s" % ["term", "home", "opponent", "gap", "n"])
	for term in TERMS:
		var home: Array = samples["home"][term]
		var opponent: Array = samples["opponent"][term]
		if home.is_empty() and opponent.is_empty():
			print("%-22s (not stamped)" % term)
			continue
		var h := _mean(home)
		var o := _mean(opponent)
		print("%-22s %9.3f %9.3f %+9.3f   %d/%d" % [
			term, h, o, h - o, home.size(), opponent.size()])
	print("")
	print("`quality` is `capability * opportunity * DIG_SOLO_SHARE`, and")
	print("`opportunity` is timing x posture x support x recovery. Read down for")
	print("the factor whose gap is large where the others are not -- that is the")
	print("one carrying it, and the only one worth changing.")
	quit()


func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())
