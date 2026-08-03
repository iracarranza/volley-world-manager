extends SceneTree

const ReadinessReport := preload("res://scripts/simulation/rally_readiness_report.gd")


func _initialize() -> void:
	var sample_count := 40
	var full_report := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--samples="):
			sample_count = maxi(int(argument.trim_prefix("--samples=")), 1)
		elif argument == "--full":
			full_report = true
	var report := ReadinessReport.identity_calibration(sample_count)
	if not full_report:
		var means := {}
		for identity_name in Dictionary(report.identities):
			means[identity_name] = report.identities[identity_name].mean
		report = {
			"sample_count_per_serving_side": report.sample_count_per_serving_side,
			"career_count": report.career_count,
			"identity_means": means,
		}
	print(JSON.stringify(report, "\t"))
	quit(0)
