extends SceneTree

const Calibration := preload(
	"res://scripts/simulation/movement_timing_ratio_calibration.gd"
)


func _initialize() -> void:
	var report := Calibration.run(120, 300000)
	print(report)
	quit(0)
