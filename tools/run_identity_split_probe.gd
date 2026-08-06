extends SceneTree

## What the identity calibration actually reports, per identity, at the sample
## size the suite gate uses. Written because the failing check compares four
## numbers and the failure message names none of them.
##
##   godot --headless --path . --script res://tools/run_identity_split_probe.gd

const KEYS := [
	"home_attack_error_rate", "home_kill_rate", "mean_attack_quality",
	"mean_set_quality", "mean_reception_quality", "rally_length",
	"serve_error_rate", "ace_rate", "mean_serve_quality",
]


func _initialize() -> void:
	var calibration := RallyReadinessReport.identity_calibration(48)
	var identities: Dictionary = calibration.get("identities", {})
	var names: Array = identities.keys()
	names.sort()
	print("identity                ", " ".join(KEYS.map(func(k: String) -> String:
		return "%18s" % k.substr(0, 18))))
	for identity_name in names:
		var mean: Dictionary = Dictionary(identities[identity_name]).get("mean", {})
		var cells := PackedStringArray()
		for key in KEYS:
			cells.append("%18.4f" % float(mean.get(key, 0.0)))
		print("%-24s%s" % [identity_name, " ".join(cells)])
	print("")
	var physical: Dictionary = Dictionary(identities.get("Physical", {})).get("mean", {})
	var defensive: Dictionary = Dictionary(identities.get("Defensive", {})).get("mean", {})
	for key in ["home_attack_error_rate", "home_kill_rate"]:
		var d := float(defensive.get(key, 0.0))
		var p := float(physical.get(key, 0.0))
		print("%-26s defensive %.4f  physical %.4f  delta %+.4f  %s" % [
			key, d, p, d - p, "OK (defensive lower)" if d < p else "FAILS",
		])
	quit(0)
