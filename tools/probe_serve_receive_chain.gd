extends SceneTree

## Where the Q1 vignettes' serve and reception disagree with each other.
##
## The visual report was "the reception happens far above the ground and bumps
## *down* to the setter, and the serve flight is wrong". Three published numbers
## per flight decide all of that and they are not read together anywhere: the
## launch's vertical component, the apex rise, and the two end heights. This
## prints them side by side for the first three contacts of each Q1 answer, plus
## the height the *next* contact was actually taken at, so a discontinuity at a
## contact point shows as a gap between two lines rather than having to be
## inferred from a drawn frame.

const FACTORY := preload("res://scripts/simulation/volleyball_vignette_rally_factory.gd")
const SIM := preload("res://scripts/simulation/rally_simulator.gd")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const BallFlightModel := preload("res://scripts/simulation/ball_flight_model.gd")

const MODES: Array[String] = ["quick", "high", "back"]


func _init() -> void:
	for mode in MODES:
		var result: Resource = FACTORY.q1(mode)
		if result == null:
			print("%s: no rally" % mode)
			continue
		print("\n=== good_ball_%s ===" % mode)
		var shown := 0
		for raw in result.events:
			var event: RallyEvent = raw as RallyEvent
			if event == null:
				continue
			var out: Dictionary = event.metadata.get("outgoing_trajectory", {})
			if out.is_empty():
				continue
			_report(event, out)
			shown += 1
			if shown >= 3:
				break
	quit()


func _report(event: RallyEvent, out: Dictionary) -> void:
	var start_h := float(out.get("start_height_meters", NAN))
	var end_h := float(out.get("end_height_meters", NAN))
	var rise := float(out.get("apex_rise_meters", NAN))
	var duration := float(out.get("duration", 0.0))
	var physical := float(out.get("physical_duration_seconds", duration))
	var vertical: Variant = out.get("launch_vertical_mps", null)
	## The apex a launch of this vertical speed actually reaches, against the
	## apex the same record publishes. One flight cannot have two.
	var implied := NAN
	var derived_end := NAN
	if vertical != null:
		var v := float(vertical)
		implied = v * v / (2.0 * BallFlightModel.DEFAULT_GRAVITY_MPS2)
		derived_end = start_h + v * physical \
			- 0.5 * BallFlightModel.DEFAULT_GRAVITY_MPS2 * physical * physical
	print("%-10s actor=%-4d t=%.3f  source=%s" % [
		RallyEventModel.EventType.keys()[event.event_type],
		event.actor_id, float(out.get("start_time", 0.0)),
		str(out.get("height_source", "default")),
	])
	print("    published: %.2f m -> %.2f m over %.3f s (physical %.3f s), apex rise %.3f" % [
		start_h, end_h, duration, physical, rise,
	])
	if vertical == null:
		print("    launch:    no launch_vertical_mps published")
	else:
		print("    launch:    v=%.2f m/s -> apex rise %.3f, end %.2f m" % [
			float(vertical), implied, derived_end,
		])
		print("    ** apex disagreement %.3f m, end disagreement %.2f m **" % [
			absf(implied - rise), absf(derived_end - end_h),
		])
		var g_own := float(out.get("launch_gravity_mps2", 0.0))
		if g_own > 0.0:
			print("    own gravity: %.3f m/s2 (default %.3f) -> apex rise %.3f, end %.2f m" % [
				g_own, BallFlightModel.DEFAULT_GRAVITY_MPS2,
				float(vertical) * float(vertical) / (2.0 * g_own),
				start_h + float(vertical) * physical - 0.5 * g_own * physical * physical,
			])
	print("    realised end height read by the next contact: %.2f m" % [
		SIM.realised_flight_end_height(out),
	])
