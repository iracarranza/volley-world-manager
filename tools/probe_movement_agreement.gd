extends SceneTree

## Prints the numbers the movement-agreement gate asserts on but never reports.
##
## The gate in `_test_movement_timing_and_locomotion_diagnostics` reads a
## 120-seed sweep, checks four per-phase bands and two overall bounds, and emits
## one boolean. When it fails there is no way to tell which of the six bounds
## went, or by how much -- so the first move is always to rebuild the sweep by
## hand. This does that once, on exactly the arguments the gate passes.

const RATIO := preload("res://scripts/simulation/movement_timing_ratio_calibration.gd")


func _initialize() -> void:
	var ratio: Dictionary = RATIO.run(120, 300000)
	print("fixture_valid      %s" % str(ratio.get("fixture_valid", false)))
	print("sample_count       %d" % int(ratio.get("sample_count", 0)))
	print("mean_ratio         %.4f   band 0.97 .. 1.04" % float(ratio.get("mean_ratio", -1.0)))
	print(
		"perceptible_rate   %.4f   ceiling 0.07"
		% float(ratio.get("perceptible_rate", -1.0))
	)
	print("")
	print("%-12s %8s %8s %8s %8s  %s" % ["phase", "samples", "mean", "lower", "upper", ""])
	var per_type: Dictionary = ratio.get("by_event_type", {})
	for type_name in per_type:
		var row := Dictionary(per_type[type_name])
		var mean_ratio := float(row.get("mean_ratio", -1.0))
		var upper := 1.12 if str(type_name) == "ATTACK" else 1.06
		var lower := 0.80 if str(type_name) == "SET" else 0.95
		var verdict := "ok" if mean_ratio > lower and mean_ratio < upper else "OUT"
		print(
			"%-12s %8d %8.4f %8.2f %8.2f  %s"
			% [
				str(type_name),
				int(row.get("sample_count", 0)),
				mean_ratio,
				lower,
				upper,
				verdict,
			]
		)
	quit(0)
