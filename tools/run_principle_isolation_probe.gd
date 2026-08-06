extends SceneTree

## One principle at a time, everything else pinned at 0.50.
##
## The identity presets co-vary -- Physical is high on all seven principles and
## Defensive is low on all seven -- so a kill-rate ranking taken across them
## cannot say *which* principle produced the difference. This holds six constant
## and sweeps the seventh, which is the only way to read a price.
##
##   godot --headless --path . --script res://tools/run_principle_isolation_probe.gd

const PRINCIPLES := [
	"decisiveness", "pin_focus", "tempo_variation", "serve_aggression",
	"transition_commitment", "block_commitment",
]
const LEVELS := [0.15, 0.50, 0.85]
const SAMPLES := 32
const CAREER_SEEDS := [
	"North Window", "Glass Harbor", "Second Tempo",
	"Quiet Hands", "Golden Rotation", "Long Road Home",
]
const KEYS := [
	"home_kill_rate", "home_attack_error_rate", "stuff_rate",
	"block_touch_rate", "mean_home_attack_effectiveness", "mean_contacts",
]


func _initialize() -> void:
	print("principle              level  %s" % " ".join(
		KEYS.map(func(k: String) -> String: return "%28s" % k)
	))
	for principle_name in PRINCIPLES:
		for level in LEVELS:
			var overrides := {}
			for other in PRINCIPLES:
				overrides[other] = 0.50
			overrides[principle_name] = level
			var totals := {}
			for career_name in CAREER_SEEDS:
				var seed_value := absi(hash("%s|identity-calibration" % career_name))
				var report := RallyReadinessReport.outcome_calibration(
					SAMPLES, seed_value, &"generated", "Balanced", overrides
				)
				var measured: Dictionary = report.get("measured", {})
				for key in KEYS:
					totals[key] = float(totals.get(key, 0.0)) \
						+ float(measured.get(key, 0.0))
			var cells := PackedStringArray()
			for key in KEYS:
				cells.append("%28.4f" % (
					float(totals[key]) / float(CAREER_SEEDS.size())
				))
			print("%-22s %.2f  %s" % [principle_name, level, " ".join(cells)])
		print("")
	quit(0)
