extends Node

## How close to the net is a swing actually drawn from?
##
##     xvfb-run -a godot --path . res://tools/net_encroachment_probe.tscn
##
## A hitter is drawn standing at the attack's `start_position`, which is the
## point where the *ball* is struck -- above and in front of the body, not
## between its feet. If the two are treated as one point, a tight set puts the
## rig inside the net, which is what an opposite spiking through the tape looks
## like.
##
## So the question is not whether contacts are legal. It is how many of them sit
## closer to the net than a body is deep, because that is the population that
## cannot be drawn where it was computed.
const RALLIES: int = 1200
## Half a torso, front to back. `OBSTRUCTION_CLEARANCE_M` is the same body
## measured across the shoulders and is the wider figure; a voli standing this
## close to the net is touching it.
const BODY_HALF_DEPTH_METERS: float = 0.22


func _ready() -> void:
	await get_tree().process_frame
	_probe()
	get_tree().quit()


func _probe() -> void:
	var career_manager: Node = get_node("/root/CareerManager")
	var game_manager: Node = get_node("/root/GameManager")
	var error: String = career_manager.create_career(
		"Net Probe", "Probe VC", "Landavol", "Established", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		return

	var off_net: Array[float] = []
	var by_lane := {}
	var inside_body := 0
	var over_the_net := 0
	for index in range(RALLIES):
		var result: Resource = game_manager.resolve_active_rally(
			hash("netprobe|%d" % index)
		)
		if result == null:
			continue
		for raw in result.events:
			var event: Resource = raw
			if event == null \
					or int(event.event_type) != RallyEvent.EventType.ATTACK:
				continue
			## Both halves, measured the same way: how far the strike point sits
			## from the net plane, on whichever side the hitter is.
			var y := float(event.start_position.y)
			var metres := absf(y - CourtConstants.NET_Y) \
				* CourtConstants.COURT_LENGTH_METERS
			var home := str(event.metadata.get("side", "home")) == "home"
			if (home and y < CourtConstants.NET_Y) \
					or (not home and y > CourtConstants.NET_Y):
				over_the_net += 1
			off_net.append(metres)
			if metres < BODY_HALF_DEPTH_METERS:
				inside_body += 1
			var lane := str(event.metadata.get("lane", "?"))
			var bucket: Array = by_lane.get(lane, [])
			bucket.append(metres)
			by_lane[lane] = bucket

	print("=== net encroachment: %d attacks over %d rallies"
		% [off_net.size(), RALLIES])
	print("struck from the wrong side of the net: %d" % over_the_net)
	print("closer to the net than half a torso (%.2f m): %d (%.2f%%)" % [
		BODY_HALF_DEPTH_METERS, inside_body,
		100.0 * float(inside_body) / maxf(float(off_net.size()), 1.0),
	])
	_report("distance off the net (m)", off_net)
	var lanes: Array = by_lane.keys()
	lanes.sort()
	for lane in lanes:
		_report("  %s" % lane, by_lane[lane])


func _report(label: String, samples: Array) -> void:
	if samples.is_empty():
		print("%s: no samples" % label)
		return
	var values: Array[float] = []
	for value in samples:
		values.append(float(value))
	values.sort()
	var total := 0.0
	for value in values:
		total += value
	print("%s: n=%d  min %.3f  p05 %.3f  median %.3f  mean %.3f  p95 %.3f" % [
		label, values.size(), values[0],
		values[int(floor(float(values.size() - 1) * 0.05))],
		values[values.size() / 2],
		total / float(values.size()),
		values[int(floor(float(values.size() - 1) * 0.95))],
	])
