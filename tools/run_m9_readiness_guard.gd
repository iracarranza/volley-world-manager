extends SceneTree

const ReadinessReport := preload("res://scripts/simulation/rally_readiness_report.gd")


func _initialize() -> void:
	var report: Dictionary = ReadinessReport.outcome_calibration(40, 900006)
	print(JSON.stringify({
		"rally_count": report.get("rally_count", 0),
		"attack_attempts": report.get("attack_attempts", 0),
		"terminal_attacks": report.get("terminal_attacks", 0),
		"measured": report.get("measured", {}),
	}))
	var passed := int(report.get("attack_attempts", 0)) \
		>= int(report.get("terminal_attacks", 0)) \
		and int(report.get("terminal_attacks", 0)) > 0
	if passed:
		print("PASS: readiness attack denominator")
	else:
		push_error("FAIL: readiness attack denominator")
	quit(0 if passed else 1)
