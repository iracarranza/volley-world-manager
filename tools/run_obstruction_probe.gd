extends Node

## Does anybody ever actually get in the way?
##
##     xvfb-run -a godot --path . res://tools/obstruction_probe.tscn
##
## `_navigation_waypoint` bends a second contact's run round a body standing in
## it. A route model that never fires is worse than no route model, because it
## reads as modelled and behaves as absent -- the §0 failure this repository
## keeps making. So the first question is the rate, not the effect: how many
## second contacts are obstructed at all, and by how far off the straight line.
##
## The claim gap comes out of the same pass because it has never been measured
## either. `SECOND_CONTACT_SEAM_MARGIN` is 0.10 and was picked with no
## distribution under it; this prints the one it acts on.
const RALLIES: int = 1500


func _ready() -> void:
	await get_tree().process_frame
	_probe()
	get_tree().quit()


func _probe() -> void:
	var career_manager: Node = get_node("/root/CareerManager")
	var game_manager: Node = get_node("/root/GameManager")
	var error: String = career_manager.create_career(
		"Obstruction Probe", "Probe VC", "Landavol", "Established", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		return

	var sets := 0
	var obstructed := 0
	var detours: Array[float] = []
	var claim_gaps: Array[float] = []
	var seams := 0
	var contested := 0
	var uncontested := 0
	var reach_margins: Array[float] = []
	for index in range(RALLIES):
		var result: Resource = game_manager.resolve_active_rally(
			hash("obstruction|%d" % index)
		)
		if result == null or result.events.is_empty():
			continue
		for raw in result.events:
			var event: Resource = raw
			if event == null \
					or int(event.event_type) != RallyEvent.EventType.SET:
				continue
			sets += 1
			if event.metadata.has("claim_margin"):
				claim_gaps.append(float(event.metadata["claim_margin"]))
				contested += 1
			elif event.metadata.has("claimant_count"):
				uncontested += 1
			if bool(event.metadata.get("seam_conflict", false)):
				seams += 1
			if event.metadata.has("reach_margin_meters"):
				reach_margins.append(float(event.metadata["reach_margin_meters"]))
			if not event.metadata.has("navigation_waypoint"):
				continue
			obstructed += 1
			## How far the corner sits off the line it replaced, in metres. This
			## is the whole of the obstruction: the shortfall the mover had to
			## make up sideways to clear a body.
			var start := Vector2(event.metadata.get(
				"movement_start", event.start_position
			))
			var corner := Vector2(event.metadata["navigation_waypoint"])
			var straight := Geometry2D.get_closest_point_to_segment(
				corner, start, event.start_position
			)
			detours.append(
				RallyKinematics.court_delta_meters(corner, straight).length()
			)

	print("=== obstruction probe: %d rallies, %d second contacts" % [RALLIES, sets])
	print("obstructed second contacts: %d (%.2f%%)"
		% [obstructed, 100.0 * float(obstructed) / maxf(float(sets), 1.0)])
	_report("detour off the straight line (m)", detours)
	print("--- the claim")
	print("second contacts with a rival claimant: %d; uncontested: %d"
		% [contested, uncontested])
	print("seam conflicts (claim gap < 0.10): %d of %d contested (%.2f%%)"
		% [seams, contested, 100.0 * float(seams) / maxf(float(contested), 1.0)])
	_report("claim gap between the top two claimants", claim_gaps)
	_report("reach margin of the chosen setter (m)", reach_margins)


func _report(label: String, samples: Array[float]) -> void:
	if samples.is_empty():
		print("%s: no samples" % label)
		return
	samples.sort()
	var total := 0.0
	for value in samples:
		total += value
	print("%s: n=%d  p05 %.3f  median %.3f  mean %.3f  p95 %.3f  max %.3f" % [
		label, samples.size(),
		samples[int(floor(float(samples.size() - 1) * 0.05))],
		samples[samples.size() / 2],
		total / float(samples.size()),
		samples[int(floor(float(samples.size() - 1) * 0.95))],
		samples[-1],
	])
