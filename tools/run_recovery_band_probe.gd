extends SceneTree

## Where should "went to the floor" begin?
##
## `_contact_recovery_state` decides which of four poses a contact leaves the
## passer in, and the cross-tab says it is deciding wrong: `fall` and
## `blown_away` are drawn on contacts whose control is barely below average, and
## `blown_away` -- nominally the worst thing that can happen to a defender --
## produces *better* passes than `knee`.
##
## The bands are not broken branches. They are thresholds sitting in the middle
## of the distribution they cut, which is this project's signature defect
## arriving from a new direction. `RECOVERY_POOR_SHARE` is 0.18, so a contact is
## "poor" below 82% of its posture's own norm -- and off-axis's norm is 0.61, so
## anything under 0.500 qualifies while the average contact scores 0.475.
##
## What is missing is the distribution to set them against. This prints it: for
## every contact, how far short of its own posture's expectation it fell, as a
## fraction of that expectation. Bands set at percentiles of *that* are ordered
## by construction and have frequencies somebody chose.
##
## Run:
##   godot --headless --path . --script res://tools/run_recovery_band_probe.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const RallySimulatorScript := preload("res://scripts/simulation/rally_simulator.gd")

const PAIRINGS: int = 1
const RALLIES: int = 90


func _initialize() -> void:
	var shortfalls: Array[float] = []
	var by_posture := {}
	var forces: Array[float] = []
	for pairing in range(PAIRINGS):
		for serving_home in [true, false]:
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			for seed_value in range(7000, 7000 + RALLIES):
				var result: Resource = manager.resolve_active_rally(seed_value)
				if result == null:
					continue
				_collect(result, shortfalls, by_posture, forces)
			manager.free()

	print("contacts sampled: %d" % shortfalls.size())
	print("")
	print("=== posture census, and how each one scores against its own norm ===")
	for posture in by_posture:
		var values: Array = by_posture[posture]
		values.sort()
		var total := 0.0
		for value in values:
			total += float(value)
		print(
			"%-14s n=%4d  expected %.3f  control mean %.3f  p10 %.3f  p90 %.3f"
			% [
				posture, values.size(),
				float(RallySimulatorScript.POSTURE_EXPECTED_CONTROL.get(posture, 0.54)),
				total / float(values.size()),
				float(values[int(values.size() * 0.1)]),
				float(values[int(values.size() * 0.9)]),
			]
		)
	print("")
	_percentiles("shortfall against posture norm (1 - control/expected)", shortfalls)
	print("")
	_percentiles("incoming force", forces)
	print("")
	print("Bands set at percentiles of the shortfall are monotone by")
	print("construction: a worse contact cannot land in a gentler pose.")
	quit()


func _collect(
	result: Resource,
	shortfalls: Array[float],
	by_posture: Dictionary,
	forces: Array[float],
) -> void:
	for raw_event in result.events:
		var event: Resource = raw_event
		if int(event.event_type) not in [
			RallyEventScript.EventType.RECEPTION,
			RallyEventScript.EventType.DEFENSE,
		]:
			continue
		if not event.metadata.has("contact_recovery"):
			continue
		var posture := str(event.metadata.get("contact_posture", "planted"))
		var control := float(event.metadata.get("contact_control", -1.0))
		if control < 0.0:
			continue
		var expected := float(
			RallySimulatorScript.POSTURE_EXPECTED_CONTROL.get(posture, 0.54)
		)
		if not by_posture.has(posture):
			by_posture[posture] = []
		(by_posture[posture] as Array).append(control)
		shortfalls.append(1.0 - control / maxf(expected, 0.001))
		forces.append(float(event.metadata.get("incoming_force", 0.0)))


func _percentiles(label: String, values: Array[float]) -> void:
	if values.is_empty():
		print("%s: no samples" % label)
		return
	values.sort()
	print("=== %s, n=%d ===" % [label, values.size()])
	for percentile in [5, 25, 50, 60, 70, 75, 80, 85, 90, 95, 97, 99]:
		var index := clampi(
			int(float(values.size()) * float(percentile) / 100.0),
			0, values.size() - 1
		)
		print("  p%-3d %8.3f" % [percentile, values[index]])
