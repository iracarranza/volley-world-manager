extends SceneTree

## The serve-to-reception height seam, both sides, over a fixed population.
##
## One number per rally: the gap between where the serve's drawn leg ends and
## where the reception's outgoing leg starts. §5 says those are the same point
## (`incoming.end ≡ C ≡ outgoing.start`), so the whole distribution should be
## zero. It was not -- the serve was the one family that never published a
## flight anything could evaluate at a time, so the reception was stamped at the
## serve's *landing* and read its height by integrating the launch under the
## wrong gravity.
##
## Reported by side, because the two receptions are separate code paths and the
## repair had to be made twice. A number that is clean on one side and not the
## other is the asymmetry this engine keeps producing.

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const RALLIES: int = 300


func _initialize() -> void:
	var rows := {"home": [], "opponent": []}
	var contact_heights := {"home": [], "opponent": []}
	var rises := {"home": 0, "opponent": 0}
	var missing := 0
	for index in range(RALLIES):
		var manager = MANAGER.new()
		manager.seed_vertical_slice_data()
		## Both sides serve, because the two receptions are separate code paths.
		manager.match_state.serving_home = index % 2 == 0
		var result: Resource = manager.resolve_active_rally(20000 + index)
		if result == null:
			continue
		var serve_out := {}
		for raw in result.events:
			var event: RallyEvent = raw as RallyEvent
			if event == null:
				continue
			if event.event_type == RallyEventModel.EventType.SERVE:
				serve_out = event.metadata.get("outgoing_trajectory", {})
				continue
			if event.event_type != RallyEventModel.EventType.RECEPTION:
				continue
			if serve_out.is_empty():
				missing += 1
				break
			var incoming_end := float(serve_out.get("end_height_meters", NAN))
			var pass_out: Dictionary = event.metadata.get(
				"outgoing_trajectory", {}
			)
			if pass_out.is_empty() or is_nan(incoming_end):
				missing += 1
				break
			var side := str(event.metadata.get("side", "home"))
			var start_h := float(pass_out.get("start_height_meters", NAN))
			rows[side].append(absf(start_h - incoming_end))
			contact_heights[side].append(start_h)
			## A pass to a setter goes up. One that goes down is a ball being
			## played from above the setter's hands, which is not a serve receive.
			if float(pass_out.get("end_height_meters", 0.0)) > start_h:
				rises[side] += 1
			break
	print("%d rallies, %d without a measurable serve->reception pair" % [
		RALLIES, missing,
	])
	for side in ["home", "opponent"]:
		_report(side, rows[side], contact_heights[side], rises[side])
	quit()


func _report(
	side: String, gaps: Array, heights: Array, rising: int
) -> void:
	if gaps.is_empty():
		print("%-9s no samples" % side)
		return
	var worst := 0.0
	var total := 0.0
	var broken := 0
	for gap in gaps:
		worst = maxf(worst, float(gap))
		total += float(gap)
		if float(gap) > 0.01:
			broken += 1
	var height_total := 0.0
	var height_low := 99.0
	var height_high := 0.0
	for height in heights:
		height_total += float(height)
		height_low = minf(height_low, float(height))
		height_high = maxf(height_high, float(height))
	print("%-9s n=%-4d seam mean %.4f worst %.4f | %d breaking (>0.01 m)" % [
		side, gaps.size(), total / gaps.size(), worst, broken,
	])
	print("%-9s contact height mean %.2f m, range %.2f-%.2f | %d of %d passes rise" % [
		"", height_total / heights.size(), height_low, height_high,
		rising, gaps.size(),
	])
