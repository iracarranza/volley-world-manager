extends SceneTree

## Own-side delivery audit: how far a set lands from where the setter aimed,
## and what the terminal outcome mix looks like alongside it.
##
## Exists because the two questions are not separable during calibration. A
## change to where the ball is delivered moves the hitter's contact point, which
## moves approach timing, which moves the error rate -- so the displacement and
## the outcome shares have to be read from the same run.
##
## Run with:
##   godot --headless --path . --script res://tools/run_delivery_audit.gd

const GAME_MANAGER := preload("res://scripts/managers/game_manager.gd")
const RALLY_EVENT := preload("res://scripts/models/rally_event.gd")
const RallyKinematics := preload("res://scripts/simulation/rally_kinematics.gd")
const CourtConstants := preload("res://scripts/data/court_constants.gd")

var _done: bool = false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	var by_outcome := {}
	var total := 0
	var displacements: Array[float] = []
	var quality_low: Array[float] = []
	var quality_high: Array[float] = []

	for match_index in range(8):
		var manager := GAME_MANAGER.new()
		manager.seed_vertical_slice_data()
		var guard := 0
		while not manager.match_state.match_complete and guard < 400:
			guard += 1
			var result: Resource = manager.resolve_active_rally(
				match_index * 100003 + guard * 7919
			)
			if result == null:
				break
			manager.record_rally(result)
			total += 1
			var outcome := str(result.terminal_outcome)
			by_outcome[outcome] = int(by_outcome.get(outcome, 0)) + 1
			for raw_event in result.events:
				var event: Resource = raw_event
				if event == null:
					continue
				if int(event.event_type) != RALLY_EVENT.EventType.SET:
					continue
				if str(event.metadata.get("side", "")) != "home":
					continue
				## Displacement from where the setter actually aimed, read off
				## the event rather than re-derived from the headline -- the
				## transition set's headline carries no lane name.
				if not event.metadata.has("intended_target"):
					continue
				var aim: Vector2 = event.metadata["intended_target"]
				var moved := RallyKinematics.court_distance_meters(
					aim, event.end_position
				)
				displacements.append(moved)
				if float(event.quality) < 0.50:
					quality_low.append(moved)
				elif float(event.quality) > 0.65:
					quality_high.append(moved)

	print("rallies: %d" % total)
	print("\nterminal outcome shares:")
	var names: Array = by_outcome.keys()
	names.sort()
	for name in names:
		print("  %-16s %5.1f%%  (n=%d)" % [
			name, float(by_outcome[name]) / float(total) * 100.0, by_outcome[name],
		])

	if displacements.is_empty():
		print("\nno home set events sampled")
		quit()
		return true
	displacements.sort()
	var sum := 0.0
	for d in displacements:
		sum += d
	print("\nhome set displacement from its lane target, %d sets:" % displacements.size())
	print("  mean %.3f m   median %.3f m   p90 %.3f m   max %.3f m" % [
		sum / float(displacements.size()),
		displacements[displacements.size() / 2],
		displacements[int(float(displacements.size()) * 0.90)],
		displacements[displacements.size() - 1],
	])

	var low_sum := 0.0
	for d in quality_low:
		low_sum += d
	var high_sum := 0.0
	for d in quality_high:
		high_sum += d
	print("  set quality: %d of %d below 0.50, %d above 0.65" % [
		quality_low.size(), displacements.size(), quality_high.size(),
	])
	if not quality_low.is_empty() and not quality_high.is_empty():
		print("  poor sets (<0.50): %.3f m over %d" % [
			low_sum / float(quality_low.size()), quality_low.size(),
		])
		print("  good sets (>0.65): %.3f m over %d" % [
			high_sum / float(quality_high.size()), quality_high.size(),
		])

	quit()
	return true
