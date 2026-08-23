extends SceneTree

## Is a reception a continuous outcome, or a coin flip dressed as one?
##
## Two worries, and they are different.
##
## **Binary-then-decorated.** If the simulator decides "in / out" or "playable /
## not" and then fills in a plausible-looking number, the quality distribution
## will pile up at the ends with little in between. If it is genuinely resolved
## from the contact, quality will spread across the range. A histogram settles
## it -- and deciles alone do not, which this project has already been burned by
## once: eleven percent of values in the middle left every decile reading 0.000
## or 1.000 and produced a confident wrong conclusion about a binary.
##
## **Two derivations that disagree.** `contact_recovery` says what the contact
## did to the passer -- platform, knee, fall, blown_away -- and drives the pose
## playback draws. `reception_quality` says how good the resulting pass was.
## They come from the same contact, so a defender drawn as blown away should not
## be producing a tidy pass. The cross-tabulation below is what says whether
## they agree, and by how much.
##
## Run:
##   godot --headless --path . --script res://tools/run_reception_agreement_probe.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const PAIRINGS: int = 1
const RALLIES: int = 90

const BUCKETS: int = 10


func _initialize() -> void:
	var quality: Array[float] = []
	var control: Array[float] = []
	var by_recovery := {}
	var by_control := {}
	for pairing in range(PAIRINGS):
		for serving_home in [true, false]:
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			for seed_value in range(7000, 7000 + RALLIES):
				var result: Resource = manager.resolve_active_rally(seed_value)
				if result == null:
					continue
				_collect(result, quality, control, by_recovery, by_control)
			manager.free()

	print("receptions sampled: %d" % quality.size())
	print("")
	_histogram("reception quality", quality)
	print("")
	_histogram("contact control", control)
	print("")
	print("=== does the pose agree with the pass? ===")
	print("%-12s %6s   %8s %8s %8s   %s"
		% ["recovery", "n", "min", "mean", "max", "share of passes over 0.60"])
	var order := ["platform", "knee", "fall", "blown_away"]
	for state in order:
		if not by_recovery.has(state):
			continue
		var values: Array = by_recovery[state]
		values.sort()
		var total := 0.0
		var tidy := 0
		for value in values:
			total += float(value)
			if float(value) > 0.60:
				tidy += 1
		print(
			"%-12s %6d   %8.3f %8.3f %8.3f   %d (%.0f%%)"
			% [
				state, values.size(), float(values[0]),
				total / float(values.size()), float(values[values.size() - 1]),
				tidy, 100.0 * float(tidy) / float(values.size()),
			]
		)
	print("")
	print("=== what CONTROL each pose was classified from ===")
	for state in order:
		if not by_control.has(state):
			continue
		var values: Array = by_control[state]
		var total := 0.0
		var high := 0
		for value in values:
			total += float(value)
			if float(value) > 0.50:
				high += 1
		print(
			"%-12s n=%d  mean control %.3f  %d (%.0f%%) had control over 0.50"
			% [
				state, values.size(), total / float(values.size()),
				high, 100.0 * float(high) / float(values.size()),
			]
		)
	print("")
	print("A severe pose with healthy control means the classification is")
	print("reading something other than what the contact actually did.")
	print("")
	print("A 'blown_away' row with a healthy mean and a large tidy share means")
	print("the pose and the pass are derived from different things.")
	quit()


func _collect(
	result: Resource,
	quality: Array[float],
	control: Array[float],
	by_recovery: Dictionary,
	by_control: Dictionary,
) -> void:
	for raw_event in result.events:
		var event: Resource = raw_event
		if int(event.event_type) not in [
			RallyEventScript.EventType.RECEPTION,
			RallyEventScript.EventType.DIG,
			RallyEventScript.EventType.ATTACK_COVERAGE,
		]:
			continue
		if not event.metadata.has("contact_recovery"):
			continue
		var value := float(event.quality)
		quality.append(value)
		control.append(float(event.metadata.get("contact_control", -1.0)))
		var state := str(event.metadata["contact_recovery"])
		if not by_recovery.has(state):
			by_recovery[state] = []
		(by_recovery[state] as Array).append(value)
		if not by_control.has(state):
			by_control[state] = []
		(by_control[state] as Array).append(
			float(event.metadata.get("contact_control", -1.0))
		)


## A histogram, not deciles. Deciles hide a thin middle; a histogram shows it.
func _histogram(label: String, values: Array[float]) -> void:
	if values.is_empty():
		print("%s: no samples" % label)
		return
	var counts := []
	counts.resize(BUCKETS)
	counts.fill(0)
	for value in values:
		var index := clampi(int(value * float(BUCKETS)), 0, BUCKETS - 1)
		counts[index] = int(counts[index]) + 1
	print("=== %s, n=%d ===" % [label, values.size()])
	for index in range(BUCKETS):
		var share := 100.0 * float(counts[index]) / float(values.size())
		print(
			"  %.1f-%.1f  %5d  %5.1f%%  %s"
			% [
				float(index) / float(BUCKETS), float(index + 1) / float(BUCKETS),
				counts[index], share, "#".repeat(int(share)),
			]
		)
