extends SceneTree

## The legal bearing cone each lane can swing into, and the deepest shot
## available along it. Exists because the asymmetry is the whole reason courses
## are bearings rather than named zones, and it is easier to check than to
## reason about.
##
## Run with:
##   godot --headless --path . --script res://tools/run_course_probe.gd

const AttackCourseModel := preload("res://scripts/simulation/attack_course_model.gd")
const CourtConstants := preload("res://scripts/data/court_constants.gd")

var _done: bool = false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	print("legal bearing cone by lane (contact at y=0.52, attacking -y)")
	for lane in ["Left Pin", "Front Quick", "Pipe", "Right Quick", "Right Pin"]:
		var contact := Vector2(CourtConstants.LANE_X[lane], 0.52)
		var lowest := 999.0
		var highest := -999.0
		var widest := 0.0
		var widest_bearing := 0.0
		for step in range(-1800, 1801):
			var bearing := float(step) * 0.05
			var span: Dictionary = AttackCourseModel.court_span_for_bearing(
				contact, bearing, true
			)
			if not bool(span.reaches_court):
				continue
			lowest = minf(lowest, bearing)
			highest = maxf(highest, bearing)
			if float(span.span_meters) > widest:
				widest = float(span.span_meters)
				widest_bearing = bearing
		print("  %-13s cone %7.2f deg .. %7.2f deg   width %6.2f   deepest %5.2f m at %6.2f deg" % [
			lane, lowest, highest, highest - lowest, widest, widest_bearing,
		])
	quit()
	return true
