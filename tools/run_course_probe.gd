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
	print("natural swing line, read off the run-up geometry")
	for lane in ["Left Pin", "Front Quick", "Pipe", "Right Quick", "Right Pin"]:
		var cx: float = CourtConstants.LANE_X[lane]
		var contact := Vector2(cx, 0.53)
		## Mirrors _approach_start_position(): pins start offset toward their own
		## sideline and behind, middles start straight behind.
		var pin_distance: float = absf(cx - 0.50)
		var depth: float = 0.135 * lerpf(0.88, 1.12, clampf(pin_distance / 0.34, 0.0, 1.0))
		var outward := 0.0
		if cx < 0.35:
			outward = -0.055
		elif cx > 0.65:
			outward = 0.055
		var start := Vector2(clampf(cx + outward, 0.06, 0.94), clampf(contact.y + depth, 0.56, 0.94))
		var natural: float = AttackCourseModel.natural_bearing_from_approach(start, contact, true)
		## Line hugs whichever sideline the hitter is already nearest.
		var own_sideline: float = 0.09 if cx < 0.5 else 0.91
		var to_line: float = AttackCourseModel.bearing_to_point(
			contact, Vector2(own_sideline, 0.14), true)
		var to_cross: float = AttackCourseModel.bearing_to_point(
			contact, Vector2(0.80 if cx < 0.5 else 0.20, 0.14), true)
		print("  %-13s natural %+7.2f   line %+7.2f (off %5.1f)   cross %+7.2f (off %5.1f)" % [
			lane, natural, to_line, absf(to_line - natural), to_cross, absf(to_cross - natural),
		])
	print("")
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
