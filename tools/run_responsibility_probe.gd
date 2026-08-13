extends Node

## Does reachability create responsibility, or only decide whether it succeeds?
##
##     xvfb-run -a godot --path . res://tools/responsibility_probe.tscn
##
## The whole responsibility handoff turns on one countable question, and until
## now nothing counted it: when a ball is claimed, is the claimant the voli
## nearest to it, or somebody who beat them on a score?
##
## `choose_claimant` builds `claim_score` from five terms and the largest single
## one is `reach_margin` at 0.34, against zone priority at 0.24. That *permits*
## a faster voli to take a ball out of a closer teammate's space. Whether it
## happens, and how far the winner had to come to do it, is what this prints.
##
## The overtake distance is the number to watch. A winner half a metre further
## out than the nearest body is two volis in the same place and the score
## breaking the tie; a winner four metres further out is a libero crossing the
## court through somebody who was already standing there.
const RALLIES: int = 1200


func _ready() -> void:
	await get_tree().process_frame
	_probe()
	get_tree().quit()


func _probe() -> void:
	var career_manager: Node = get_node("/root/CareerManager")
	var game_manager: Node = get_node("/root/GameManager")
	var error: String = career_manager.create_career(
		"Responsibility Probe", "Probe VC", "Landavol", "Established", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		return

	var by_kind := {}
	for index in range(RALLIES):
		var result: Resource = game_manager.resolve_active_rally(
			hash("responsibility|%d" % index)
		)
		if result == null:
			continue
		for raw in result.events:
			var event: Resource = raw
			if event == null or not event.metadata.has("nearest_id"):
				continue
			var kind := "RECEPTION" \
				if int(event.event_type) == RallyEvent.EventType.RECEPTION \
				else "DEFENSE"
			var bucket: Dictionary = by_kind.get(kind, {
				"claims": 0, "overtaken": 0, "contested": 0, "locked": 0,
				"locked_multi": 0,
				"overtake_meters": [], "winner_meters": [],
			})
			bucket.claims += 1
			## Only a claim with more than one reachable body could have gone
			## either way. A voli taking a ball nobody else could reach is not
			## the score overriding anything.
			if int(event.metadata.get("reachable_count", 0)) > 1:
				bucket.contested += 1
			if bool(event.metadata.get("immediate_lock", false)):
				bucket.locked += 1
				if int(event.metadata.get("immediate_owner_count", 0)) > 1:
					bucket.locked_multi += 1
			var nearest_id := int(event.metadata["nearest_id"])
			var winner := float(event.metadata.get("winner_distance_meters", -1.0))
			var nearest := float(event.metadata.get("nearest_distance_meters", -1.0))
			if winner >= 0.0:
				var winners: Array = bucket.winner_meters
				winners.append(winner)
				bucket.winner_meters = winners
			if nearest_id >= 0 and nearest_id != int(event.actor_id) \
					and winner >= 0.0 and nearest >= 0.0:
				bucket.overtaken += 1
				var gaps: Array = bucket.overtake_meters
				gaps.append(winner - nearest)
				bucket.overtake_meters = gaps
			by_kind[kind] = bucket

	print("=== responsibility: %d rallies" % RALLIES)
	var kinds: Array = by_kind.keys()
	kinds.sort()
	for kind in kinds:
		var bucket: Dictionary = by_kind[kind]
		print("--- %s" % kind)
		print("  claims %d, of which %d had a second reachable body"
			% [int(bucket.claims), int(bucket.contested)])
		print("  the ball was already inside somebody's reach: %d (%.2f%%), shared by more than one: %d" % [
			int(bucket.locked),
			100.0 * float(bucket.locked) / maxf(float(bucket.claims), 1.0),
			int(bucket.locked_multi),
		])
		print("  the nearest voli did NOT take it: %d (%.2f%% of claims, %.2f%% of contested)" % [
			int(bucket.overtaken),
			100.0 * float(bucket.overtaken) / maxf(float(bucket.claims), 1.0),
			100.0 * float(bucket.overtaken) / maxf(float(bucket.contested), 1.0),
		])
		_report("  how much further the winner was (m)", bucket.overtake_meters)
		_report("  the winner's own distance to the ball (m)", bucket.winner_meters)


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
	print("%s: n=%d  p05 %.2f  median %.2f  mean %.2f  p95 %.2f  max %.2f" % [
		label, values.size(),
		values[int(floor(float(values.size() - 1) * 0.05))],
		values[values.size() / 2],
		total / float(values.size()),
		values[int(floor(float(values.size() - 1) * 0.95))],
		values[-1],
	])
